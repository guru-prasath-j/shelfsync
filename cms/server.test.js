const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'shelfsync-'));
for (const f of ['home.json', 'products.json']) fs.copyFileSync(path.join(__dirname, 'content', f), path.join(tmp, f));
fs.cpSync(path.join(__dirname, 'content', 'images'), path.join(tmp, 'images'), { recursive: true });
process.env.CONTENT_DIR = tmp;
process.env.DATA_DIR = path.join(tmp, 'data');
const web = path.join(tmp, 'web');
fs.mkdirSync(path.join(web, 'assets'), { recursive: true });
fs.writeFileSync(path.join(web, 'index.html'), '<!doctype html><title>ShelfSync app</title>');
fs.writeFileSync(path.join(web, 'main.dart.js'), 'console.log(1)');
fs.writeFileSync(path.join(web, 'assets', 'logo.png'), 'png');
fs.writeFileSync(path.join(tmp, 'secret.txt'), 'outside web dir');
process.env.WEB_DIR = web;
const { createServer } = require('./server');

const json = (body) => ({ method: 'POST', body: JSON.stringify(body) });
const bearer = (token) => ({ Authorization: `Bearer ${token}` });
let adminToken;

let server, base;
before(async () => {
  server = createServer();
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test('layout embeds products for product_grid blocks', async () => {
  const res = await fetch(`${base}/api/layout/home`);
  const body = await res.json();
  const known = new Set(JSON.parse(fs.readFileSync(path.join(tmp, 'products.json'), 'utf8')).map((p) => p.id));
  const grids = body.blocks.filter((b) => b.type === 'product_grid');
  assert.ok(grids.length > 0);
  // Independent of what the store has published: every grid gets its
  // products embedded, in productIds order, skipping unknown ids.
  for (const grid of grids) {
    const expected = grid.data.productIds.filter((id) => known.has(id));
    assert.deepStrictEqual(grid.data.products.map((p) => p.id), expected);
    assert.ok(grid.data.products.every((p) => typeof p.price === 'number'));
  }
});

test('local product images are served and returned as absolute URLs', async () => {
  const products = await (await fetch(`${base}/api/products`)).json();
  for (const p of products) {
    assert.match(p.imageUrl, new RegExp(`^${base}/images/[\\w.-]+\\.jpg$`), p.name);
    const img = await fetch(p.imageUrl);
    assert.strictEqual(img.status, 200, p.imageUrl);
    assert.strictEqual(img.headers.get('content-type'), 'image/jpeg');
  }
  const layout = await (await fetch(`${base}/api/layout/home`)).json();
  const banner = layout.blocks.find((b) => b.type === 'banner' && b.data.imageUrl);
  assert.ok(banner.data.imageUrl.startsWith(`${base}/images/`));
  assert.strictEqual((await fetch(`${base}/images/nope.jpg`)).status, 404);
  assert.strictEqual((await fetch(`${base}/images/..%2fhome.json`)).status, 404);
  // Every image in content has a credit line.
  const credits = fs.readFileSync(path.join(__dirname, 'content', 'images', 'CREDITS.md'), 'utf8');
  for (const f of fs.readdirSync(path.join(__dirname, 'content', 'images')).filter((f) => f.endsWith('.jpg'))) {
    assert.ok(credits.includes(`\`${f}\``), `credit for ${f}`);
  }
});

test('If-None-Match with current ETag returns 304', async () => {
  const first = await fetch(`${base}/api/layout/home`);
  const etag = first.headers.get('etag');
  assert.ok(etag);
  const second = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': etag } });
  assert.strictEqual(second.status, 304);
});

test('admin setup: short password rejected, then set once', async () => {
  let status = await (await fetch(`${base}/api/admin/status`)).json();
  assert.deepStrictEqual(status, { passwordSet: false, canSetup: true, loggedIn: false });

  const short = await fetch(`${base}/api/admin/setup`, json({ password: 'abc' }));
  assert.strictEqual(short.status, 400);

  const ok = await fetch(`${base}/api/admin/setup`, json({ password: 'kadai-2026' }));
  assert.strictEqual(ok.status, 200);
  adminToken = (await ok.json()).token;
  assert.match(adminToken, /^[a-f0-9]{64}$/);

  const again = await fetch(`${base}/api/admin/setup`, json({ password: 'someone-else' }));
  assert.strictEqual(again.status, 409);

  status = await (await fetch(`${base}/api/admin/status`, { headers: bearer(adminToken) })).json();
  assert.deepStrictEqual(status, { passwordSet: true, canSetup: false, loggedIn: true });
  // Stored as a salted hash, never the password itself.
  const stored = fs.readFileSync(path.join(tmp, 'data', 'admin.json'), 'utf8');
  assert.ok(!stored.includes('kadai-2026'));
});

test('admin routes need a valid session', async () => {
  const layout = fs.readFileSync(path.join(tmp, 'home.json'), 'utf8');
  const noAuth = await fetch(`${base}/api/admin/layout/home`, { method: 'PUT', body: layout });
  assert.strictEqual(noAuth.status, 401);
  const fake = await fetch(`${base}/api/admin/layout/home`, { headers: bearer('f'.repeat(64)) });
  assert.strictEqual(fake.status, 401);
  const raw = await fetch(`${base}/api/admin/layout/home`, { headers: bearer(adminToken) });
  assert.strictEqual(raw.status, 200);
  const grid = (await raw.json()).blocks.find((b) => b.type === 'product_grid');
  assert.ok(grid.data.productIds && !grid.data.products, 'raw layout keeps ids, not embedded products');
});

test('login: wrong password is rejected, right one returns a token', async () => {
  const wrong = await fetch(`${base}/api/admin/login`, json({ password: 'nope-nope' }));
  assert.strictEqual(wrong.status, 401);
  const right = await fetch(`${base}/api/admin/login`, json({ password: 'kadai-2026' }));
  assert.strictEqual(right.status, 200);
  assert.match((await right.json()).token, /^[a-f0-9]{64}$/);
});

test('changing the password signs out old sessions', async () => {
  const old = adminToken;
  const bad = await fetch(`${base}/api/admin/password`, {
    ...json({ current: 'wrong-one', next: 'new-pass-99' }),
    headers: bearer(old),
  });
  assert.strictEqual(bad.status, 401);
  const res = await fetch(`${base}/api/admin/password`, {
    ...json({ current: 'kadai-2026', next: 'new-pass-99' }),
    headers: bearer(old),
  });
  assert.strictEqual(res.status, 200);
  adminToken = (await res.json()).token;
  const stale = await fetch(`${base}/api/admin/layout/home`, { headers: bearer(old) });
  assert.strictEqual(stale.status, 401);
  const login = await fetch(`${base}/api/admin/login`, json({ password: 'new-pass-99' }));
  assert.strictEqual(login.status, 200);
});

test('If-None-Match accepts the weak W/ form a CDN sends back', async () => {
  const etag = (await fetch(`${base}/api/layout/home`)).headers.get('etag');
  const weak = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': `W/${etag}` } });
  assert.strictEqual(weak.status, 304);
  const list = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': `"other", W/${etag}` } });
  assert.strictEqual(list.status, 304);
  const other = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': 'W/"nope"' } });
  assert.strictEqual(other.status, 200);
});

test('publishing a layout changes the ETag', async () => {
  const before = (await fetch(`${base}/api/layout/home`)).headers.get('etag');
  const layout = JSON.parse(fs.readFileSync(path.join(tmp, 'home.json'), 'utf8'));
  layout.blocks[0].data.text = 'Changed from the CMS';
  const put = await fetch(`${base}/api/admin/layout/home`, {
    method: 'PUT',
    body: JSON.stringify(layout),
    headers: bearer(adminToken),
  });
  assert.strictEqual(put.status, 200);
  const res = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': before } });
  assert.strictEqual(res.status, 200);
  assert.notStrictEqual(res.headers.get('etag'), before);
});

test('five wrong passwords lock login for a minute', async () => {
  for (let i = 0; i < 5; i++) {
    const r = await fetch(`${base}/api/admin/login`, json({ password: 'guess-' + i }));
    assert.strictEqual(r.status, 401);
  }
  const locked = await fetch(`${base}/api/admin/login`, json({ password: 'new-pass-99' }));
  assert.strictEqual(locked.status, 429);
});

test('serves the web app at / with app-route fallback, and stays inside WEB_DIR', async () => {
  const root = await fetch(`${base}/`);
  assert.strictEqual(root.status, 200);
  assert.match(root.headers.get('content-type'), /text\/html/);
  assert.match(await root.text(), /ShelfSync app/);

  const js = await fetch(`${base}/main.dart.js`);
  assert.strictEqual(js.status, 200);
  assert.match(js.headers.get('content-type'), /javascript/);
  assert.strictEqual(js.headers.get('cache-control'), 'no-cache', 'a new deploy is picked up');
  const again = await fetch(`${base}/main.dart.js`, { headers: { 'If-Modified-Since': js.headers.get('last-modified') } });
  assert.strictEqual(again.status, 304, 'unchanged file revalidates cheaply');

  assert.strictEqual((await fetch(`${base}/assets/logo.png`)).headers.get('content-type'), 'image/png');
  assert.match(await (await fetch(`${base}/cart`)).text(), /ShelfSync app/, 'app route falls back to index.html');
  assert.strictEqual((await fetch(`${base}/missing.js`)).status, 404);
  assert.strictEqual((await fetch(`${base}/api/nope`)).status, 404, 'unknown API stays JSON 404');
  assert.notStrictEqual((await fetch(`${base}/%2e%2e/secret.txt`)).status, 200, 'no path traversal');
  assert.strictEqual((await fetch(`${base}/admin`)).status, 200, 'admin page still served');
});

test('cart ops are idempotent and last-write-wins', async () => {
  const post = (ops) => fetch(`${base}/api/cart/ops`, { method: 'POST', body: JSON.stringify({ ops }) }).then((r) => r.json());
  await post([{ opId: 'a', type: 'set', productId: 'p1', qty: 2, at: 200 }]);
  const retry = await post([{ opId: 'a', type: 'set', productId: 'p1', qty: 2, at: 200 }]);
  assert.deepStrictEqual(retry.applied, ['a']);
  const stale = await post([{ opId: 'b', type: 'set', productId: 'p1', qty: 9, at: 100 }]);
  assert.strictEqual(stale.cart.p1, 2);
  const removed = await post([{ opId: 'c', type: 'set', productId: 'p1', qty: 0, at: 300 }]);
  assert.strictEqual(removed.cart.p1, undefined);
});
