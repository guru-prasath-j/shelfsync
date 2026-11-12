const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'shelfsync-'));
for (const f of ['home.json', 'products.json']) fs.copyFileSync(path.join(__dirname, 'content', f), path.join(tmp, f));
process.env.CONTENT_DIR = tmp;
const { createServer } = require('./server');

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
  const grid = body.blocks.find((b) => b.type === 'product_grid');
  assert.strictEqual(grid.data.products.length, 4);
  assert.strictEqual(grid.data.products[0].id, 'p1');
});

test('If-None-Match with current ETag returns 304', async () => {
  const first = await fetch(`${base}/api/layout/home`);
  const etag = first.headers.get('etag');
  assert.ok(etag);
  const second = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': etag } });
  assert.strictEqual(second.status, 304);
});

test('publishing a layout changes the ETag', async () => {
  const before = (await fetch(`${base}/api/layout/home`)).headers.get('etag');
  const layout = JSON.parse(fs.readFileSync(path.join(tmp, 'home.json'), 'utf8'));
  layout.blocks[0].data.text = 'Changed from the CMS';
  const put = await fetch(`${base}/api/admin/layout/home`, { method: 'PUT', body: JSON.stringify(layout) });
  assert.strictEqual(put.status, 200);
  const res = await fetch(`${base}/api/layout/home`, { headers: { 'If-None-Match': before } });
  assert.strictEqual(res.status, 200);
  assert.notStrictEqual(res.headers.get('etag'), before);
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
