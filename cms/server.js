// ShelfSync mock CMS. Zero dependencies (node:http only).
// - Content lives in ./content/*.json and is re-read on every request,
//   so editing a file (or using /admin) is a "publish" with no app release.
// - Every GET sends a strong ETag; If-None-Match returns 304 with no body.
// - Cart ops are idempotent: each op carries an opId and is applied once.

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const CONTENT_DIR = process.env.CONTENT_DIR || path.join(__dirname, 'content');
// Admin password hash lives outside content/ and is git-ignored.
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const AUTH_FILE = () => path.join(DATA_DIR, 'admin.json');

const SESSION_TTL_MS = 8 * 60 * 60 * 1000; // stay logged in for a working day
const MAX_FAILURES = 5;
const LOCKOUT_MS = 60 * 1000;
const MIN_PASSWORD_LENGTH = 8;

const MAX_GLOBAL_FAILURES = 20; // per minute, across all clients

// --- Admin password: scrypt hash + salt, never stored in plain text. ---
// On a hosted server (Render) nobody can reach the loopback-only setup, so the
// first password comes from the ADMIN_PASSWORD env var (set as a secret in the
// host's dashboard, never committed). A password changed in the app is saved
// to DATA_DIR and wins over the env var until that file is lost.
let envAuth = null; // { source, salt, hash } for the current ADMIN_PASSWORD
function readAuth() {
  try {
    return JSON.parse(fs.readFileSync(AUTH_FILE(), 'utf8'));
  } catch {
    const pw = process.env.ADMIN_PASSWORD;
    if (!pw) return null;
    if (!envAuth || envAuth.source !== pw) {
      const salt = crypto.randomBytes(16).toString('hex');
      envAuth = { source: pw, salt, hash: crypto.scryptSync(pw, salt, 64).toString('hex') };
    }
    return envAuth;
  }
}

// Behind a host's proxy every request arrives from the proxy, so with
// TRUST_PROXY=1 the per-client lockout keys on the forwarded client address.
// That header can be faked, so a global cap still bounds guessing overall.
function clientKey(req) {
  const fwd = process.env.TRUST_PROXY === '1' && req.headers['x-forwarded-for'];
  if (fwd) return String(fwd).split(',')[0].trim();
  return req.socket.remoteAddress || 'unknown';
}

function writeAuth(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(AUTH_FILE(), JSON.stringify({ salt, hash, updatedAt: new Date().toISOString() }));
}

function passwordMatches(password, auth) {
  if (!auth || typeof password !== 'string') return false;
  const actual = crypto.scryptSync(password, auth.salt, 64);
  return crypto.timingSafeEqual(actual, Buffer.from(auth.hash, 'hex'));
}

function passwordProblem(password) {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH) {
    return `Password must be at least ${MIN_PASSWORD_LENGTH} characters`;
  }
  return null;
}

// First-time setup is only allowed from this PC (or a phone over USB via
// `adb reverse`, which also arrives as loopback), so nobody else on the
// Wi-Fi can claim the admin password first.
function isLoopback(req) {
  const a = req.socket.remoteAddress || '';
  return a === '127.0.0.1' || a === '::1' || a === '::ffff:127.0.0.1';
}

async function readJsonBody(req) {
  const raw = await readBody(req);
  return raw ? JSON.parse(raw) : {};
}

function readJson(name) {
  return JSON.parse(fs.readFileSync(path.join(CONTENT_DIR, name), 'utf8'));
}

function etagFor(body) {
  return '"' + crypto.createHash('sha1').update(body).digest('hex').slice(0, 16) + '"';
}

function sendJson(req, res, status, value) {
  const body = JSON.stringify(value);
  if (req.method === 'GET' && status === 200) {
    const etag = etagFor(body);
    res.setHeader('ETag', etag);
    res.setHeader('Cache-Control', 'no-cache');
    if (req.headers['if-none-match'] === etag) {
      res.writeHead(304);
      return res.end();
    }
  }
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => (data += c));
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

// Server-side join: product_grid blocks reference productIds; the app
// receives embedded products so a cached layout renders fully offline.
function resolveLayout(layout, products) {
  const byId = new Map(products.map((p) => [p.id, p]));
  return {
    ...layout,
    blocks: layout.blocks.map((b) => {
      if (b.type !== 'product_grid') return b;
      const ids = (b.data && b.data.productIds) || [];
      return { ...b, data: { ...b.data, products: ids.map((id) => byId.get(id)).filter(Boolean) } };
    }),
  };
}

function createServer() {
  const appliedOps = new Set();
  const cart = new Map(); // productId -> { qty, at }
  const sessions = new Map(); // token -> expiresAt (ms)
  const failures = new Map(); // client address -> { count, lockedUntil }
  let globalFailures = { count: 0, windowStart: 0 };

  function newSession() {
    const token = crypto.randomBytes(32).toString('hex');
    sessions.set(token, Date.now() + SESSION_TTL_MS);
    return token;
  }

  function sessionToken(req) {
    const m = /^Bearer ([a-f0-9]{64})$/.exec(req.headers.authorization || '');
    if (!m) return null;
    const expires = sessions.get(m[1]);
    if (!expires || expires < Date.now()) {
      sessions.delete(m[1]);
      return null;
    }
    return m[1];
  }

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const p = url.pathname;
    try {
      if (p.startsWith('/api/admin/')) return await handleAdmin(req, res, p);
      if (req.method === 'GET' && p === '/api/layout/home') {
        return sendJson(req, res, 200, resolveLayout(readJson('home.json'), readJson('products.json')));
      }
      if (req.method === 'GET' && p === '/api/products') {
        return sendJson(req, res, 200, readJson('products.json'));
      }
      const productMatch = p.match(/^\/api\/products\/([\w-]+)$/);
      if (req.method === 'GET' && productMatch) {
        const product = readJson('products.json').find((x) => x.id === productMatch[1]);
        return product ? sendJson(req, res, 200, product) : sendJson(req, res, 404, { error: 'Product not found' });
      }
      if (req.method === 'POST' && p === '/api/cart/ops') {
        const { ops } = JSON.parse((await readBody(req)) || '{}');
        if (!Array.isArray(ops)) return sendJson(req, res, 400, { error: 'Body must be { ops: [...] }' });
        const applied = [];
        for (const op of ops) {
          if (!op || !op.opId || op.type !== 'set' || !op.productId || !Number.isInteger(op.qty)) continue;
          if (!appliedOps.has(op.opId)) {
            appliedOps.add(op.opId);
            const current = cart.get(op.productId);
            // Last-write-wins on the client timestamp, so a late retry of an
            // old op can't overwrite a newer quantity.
            if (!current || op.at >= current.at) {
              if (op.qty <= 0) cart.delete(op.productId);
              else cart.set(op.productId, { qty: op.qty, at: op.at });
            }
          }
          applied.push(op.opId); // already-applied ops are acknowledged too
        }
        return sendJson(req, res, 200, { applied, cart: Object.fromEntries([...cart].map(([k, v]) => [k, v.qty])) });
      }
      if (req.method === 'GET' && p === '/api/cart') {
        return sendJson(req, res, 200, Object.fromEntries([...cart].map(([k, v]) => [k, v.qty])));
      }
      if (req.method === 'GET' && p === '/') {
        res.writeHead(302, { Location: '/admin' });
        return res.end();
      }
      if (req.method === 'GET' && p === '/admin') {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        return res.end(fs.readFileSync(path.join(__dirname, 'admin.html')));
      }
      return sendJson(req, res, 404, { error: 'Not found' });
    } catch (err) {
      return sendJson(req, res, err instanceof SyntaxError ? 400 : 500, { error: err.message });
    }
  });

  async function handleAdmin(req, res, p) {
    const client = clientKey(req);

    if (req.method === 'GET' && p === '/api/admin/status') {
      const passwordSet = readAuth() !== null;
      return sendJson(req, res, 200, {
        passwordSet,
        canSetup: !passwordSet && isLoopback(req),
        loggedIn: sessionToken(req) !== null,
      });
    }

    if (req.method === 'POST' && p === '/api/admin/setup') {
      if (readAuth()) return sendJson(req, res, 409, { error: 'Admin password is already set. Log in instead.' });
      if (!isLoopback(req)) {
        return sendJson(req, res, 403, { error: 'Set the first admin password from the PC or a USB-connected phone.' });
      }
      const { password } = await readJsonBody(req);
      const problem = passwordProblem(password);
      if (problem) return sendJson(req, res, 400, { error: problem });
      writeAuth(password);
      return sendJson(req, res, 200, { token: newSession() });
    }

    if (req.method === 'POST' && p === '/api/admin/login') {
      const now = Date.now();
      const f = failures.get(client);
      if (f && f.lockedUntil > now) {
        const secs = Math.ceil((f.lockedUntil - now) / 1000);
        return sendJson(req, res, 429, { error: `Too many wrong attempts. Try again in ${secs}s.` });
      }
      if (now - globalFailures.windowStart > LOCKOUT_MS) globalFailures = { count: 0, windowStart: now };
      if (globalFailures.count >= MAX_GLOBAL_FAILURES) {
        return sendJson(req, res, 429, { error: 'Too many wrong attempts. Try again in a minute.' });
      }
      const auth = readAuth();
      if (!auth) return sendJson(req, res, 409, { error: 'No admin password yet. Set one up first.' });
      const { password } = await readJsonBody(req);
      if (!passwordMatches(password, auth)) {
        globalFailures.count += 1;
        // A finished lockout starts the count again from zero.
        const count = (f && f.count < MAX_FAILURES ? f.count : 0) + 1;
        failures.set(client, { count, lockedUntil: count >= MAX_FAILURES ? now + LOCKOUT_MS : 0 });
        return sendJson(req, res, 401, { error: 'Wrong password' });
      }
      failures.delete(client);
      return sendJson(req, res, 200, { token: newSession() });
    }

    // Everything below needs a valid session.
    const token = sessionToken(req);
    if (!token) return sendJson(req, res, 401, { error: 'Please log in again' });

    if (req.method === 'POST' && p === '/api/admin/logout') {
      sessions.delete(token);
      return sendJson(req, res, 200, { loggedOut: true });
    }

    if (req.method === 'POST' && p === '/api/admin/password') {
      const { current, next } = await readJsonBody(req);
      if (!passwordMatches(current, readAuth())) return sendJson(req, res, 401, { error: 'Current password is wrong' });
      const problem = passwordProblem(next);
      if (problem) return sendJson(req, res, 400, { error: problem });
      writeAuth(next);
      sessions.clear(); // sign out every other device
      return sendJson(req, res, 200, { token: newSession() });
    }

    if (req.method === 'GET' && p === '/api/admin/layout/home') {
      // Raw source: product grids keep productIds, expired and unknown blocks included.
      return sendJson(req, res, 200, readJson('home.json'));
    }

    if (req.method === 'PUT' && p === '/api/admin/layout/home') {
      const parsed = await readJsonBody(req);
      if (!Array.isArray(parsed.blocks)) return sendJson(req, res, 400, { error: 'Layout needs a blocks array' });
      const bad = parsed.blocks.find((b) => !b || typeof b.id !== 'string' || typeof b.type !== 'string');
      if (bad) return sendJson(req, res, 400, { error: 'Every block needs a string id and type' });
      const ids = parsed.blocks.map((b) => b.id);
      if (new Set(ids).size !== ids.length) return sendJson(req, res, 400, { error: 'Block ids must be unique' });
      fs.writeFileSync(path.join(CONTENT_DIR, 'home.json'), JSON.stringify(parsed, null, 2));
      return sendJson(req, res, 200, { published: true });
    }

    return sendJson(req, res, 404, { error: 'Not found' });
  }
}

module.exports = { createServer, etagFor, resolveLayout };

if (require.main === module) {
  const port = Number(process.env.PORT || 4000);
  createServer().listen(port, () => {
    console.log(`ShelfSync CMS on http://localhost:${port}  (admin: /admin)`);
  });
}
