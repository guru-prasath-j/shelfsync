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

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const p = url.pathname;
    try {
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
      if (req.method === 'PUT' && p === '/api/admin/layout/home') {
        const raw = await readBody(req);
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed.blocks)) return sendJson(req, res, 400, { error: 'Layout needs a blocks array' });
        fs.writeFileSync(path.join(CONTENT_DIR, 'home.json'), JSON.stringify(parsed, null, 2));
        return sendJson(req, res, 200, { published: true });
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
}

module.exports = { createServer, etagFor, resolveLayout };

if (require.main === module) {
  const port = Number(process.env.PORT || 4000);
  createServer().listen(port, () => {
    console.log(`ShelfSync CMS on http://localhost:${port}  (admin: /admin)`);
  });
}
