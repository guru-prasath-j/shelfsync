// Razorpay checkout against a fake Razorpay API (no network, no real keys).
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'shelfsync-pay-'));
for (const f of ['home.json', 'products.json']) fs.copyFileSync(path.join(__dirname, 'content', f), path.join(tmp, f));
// Make one product out of stock for the test, whatever the real catalogue says.
const products = JSON.parse(fs.readFileSync(path.join(tmp, 'products.json'), 'utf8'));
products.find((p) => p.id === 'p5').inStock = false;
fs.writeFileSync(path.join(tmp, 'products.json'), JSON.stringify(products));
const price = (id) => products.find((p) => p.id === id).price;

process.env.CONTENT_DIR = tmp;
process.env.DATA_DIR = path.join(tmp, 'data');
process.env.WEB_DIR = path.join(tmp, 'no-web');
process.env.RAZORPAY_KEY_ID = 'rzp_test_FAKEKEY123';
process.env.RAZORPAY_KEY_SECRET = 'fake_secret_for_tests';
const { createServer } = require('./server');
const { signatureFor } = require('./payments');

let server, base, razorpay;
const razorpayCalls = [];
before(async () => {
  razorpay = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c)).on('end', () => {
      razorpayCalls.push({ url: req.url, auth: req.headers.authorization, body: JSON.parse(body) });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: `order_FAKE${razorpayCalls.length}`, amount: JSON.parse(body).amount, currency: 'INR' }));
    });
  });
  await new Promise((r) => razorpay.listen(0, r));
  process.env.RAZORPAY_API = `http://127.0.0.1:${razorpay.address().port}/v1`;
  server = createServer();
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => {
  server.close();
  razorpay.close();
});

const post = (p, body) =>
  fetch(`${base}${p}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

test('order is priced on the server and created on Razorpay with the key', async () => {
  const res = await post('/api/checkout/orders', { lines: [{ productId: 'p1', qty: 2, price: 1 }, { productId: 'p2', qty: 1 }] });
  assert.strictEqual(res.status, 200);
  const order = await res.json();
  const expected = (price('p1') * 2 + price('p2')) * 100;
  assert.strictEqual(order.amount, expected, 'client "price" field is ignored');
  assert.strictEqual(order.status, 'created');
  assert.strictEqual(order.payUrl, `${base}/pay/${order.orderId}`);

  const call = razorpayCalls.at(-1);
  assert.strictEqual(call.url, '/v1/orders');
  assert.strictEqual(call.auth, 'Basic ' + Buffer.from('rzp_test_FAKEKEY123:fake_secret_for_tests').toString('base64'));
  assert.deepStrictEqual(call.body, { amount: expected, currency: 'INR', receipt: order.orderId, notes: { source: 'shelfsync' } });
});

test('bad carts are rejected before reaching Razorpay', async () => {
  const before = razorpayCalls.length;
  assert.strictEqual((await post('/api/checkout/orders', { lines: [] })).status, 400);
  assert.strictEqual((await post('/api/checkout/orders', { lines: [{ productId: 'nope', qty: 1 }] })).status, 400);
  assert.strictEqual((await post('/api/checkout/orders', { lines: [{ productId: 'p1', qty: 0 }] })).status, 400);
  assert.strictEqual((await post('/api/checkout/orders', { lines: [{ productId: 'p1', qty: 1.5 }] })).status, 400);
  assert.strictEqual((await post('/api/checkout/orders', { lines: [{ productId: 'p1', qty: 1 }, { productId: 'p1', qty: 1 }] })).status, 400);
  const oos = await post('/api/checkout/orders', { lines: [{ productId: 'p5', qty: 1 }] });
  assert.strictEqual(oos.status, 409);
  assert.match((await oos.json()).error, /out of stock/);
  assert.strictEqual(razorpayCalls.length, before);
});

test('pay page runs Razorpay Checkout for that order without leaking the secret', async () => {
  const order = await (await post('/api/checkout/orders', { lines: [{ productId: 'p4', qty: 3 }] })).json();
  const res = await fetch(order.payUrl);
  assert.strictEqual(res.status, 200);
  const html = await res.text();
  assert.match(html, /checkout\.razorpay\.com\/v1\/checkout\.js/);
  assert.match(html, /rzp_test_FAKEKEY123/);
  assert.match(html, /order_FAKE\d+/);
  assert.match(html, /Test mode/);
  assert.ok(!html.includes('fake_secret_for_tests'), 'secret never reaches the browser');
  assert.strictEqual((await fetch(`${base}/pay/${'0'.repeat(24)}`)).status, 404);
});

test('only a correctly signed payment marks the order paid', async () => {
  const order = await (await post('/api/checkout/orders', { lines: [{ productId: 'p6', qty: 1 }] })).json();
  const rzOrder = razorpayCalls.length ? `order_FAKE${razorpayCalls.length}` : '';
  const status = () => fetch(`${base}/api/checkout/orders/${order.orderId}`).then((r) => r.json());

  const forged = await post('/api/checkout/verify', {
    orderId: order.orderId, razorpay_order_id: rzOrder, razorpay_payment_id: 'pay_X', razorpay_signature: 'f'.repeat(64),
  });
  assert.strictEqual(forged.status, 400);
  const wrongOrder = await post('/api/checkout/verify', {
    orderId: order.orderId, razorpay_order_id: 'order_OTHER', razorpay_payment_id: 'pay_X',
    razorpay_signature: signatureFor('fake_secret_for_tests', 'order_OTHER', 'pay_X'),
  });
  assert.strictEqual(wrongOrder.status, 400);
  assert.strictEqual((await status()).status, 'created');

  const ok = await post('/api/checkout/verify', {
    orderId: order.orderId, razorpay_order_id: rzOrder, razorpay_payment_id: 'pay_OK1',
    razorpay_signature: signatureFor('fake_secret_for_tests', rzOrder, 'pay_OK1'),
  });
  assert.strictEqual(ok.status, 200);
  assert.deepStrictEqual(await status(), {
    orderId: order.orderId, status: 'paid', amount: price('p6') * 100, currency: 'INR',
    items: [{ productId: 'p6', name: products.find((p) => p.id === 'p6').name, unit: '1 kg', qty: 1, price: price('p6') }],
    paymentId: 'pay_OK1',
  });
});

test('without keys checkout says it is not set up', async () => {
  const id = process.env.RAZORPAY_KEY_ID;
  delete process.env.RAZORPAY_KEY_ID;
  try {
    const res = await post('/api/checkout/orders', { lines: [{ productId: 'p1', qty: 1 }] });
    assert.strictEqual(res.status, 503);
    assert.match((await res.json()).error, /not set up/);
  } finally {
    process.env.RAZORPAY_KEY_ID = id;
  }
});
