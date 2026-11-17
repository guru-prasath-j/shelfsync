// Razorpay checkout for the ShelfSync CMS (use test-mode keys for now).
//
// Flow: the app sends its cart lines -> POST /api/checkout/orders prices them
// from products.json (never trusting client totals) and creates a Razorpay
// order -> the app opens /pay/<id>, a small page that runs Razorpay Checkout
// -> on success the page posts the payment to /api/checkout/verify, which
// checks Razorpay's HMAC signature with the key secret -> the app polls
// GET /api/checkout/orders/<id> until it reads "paid".
//
// Keys come only from the environment (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET).
// Without them every checkout call answers 503 "not set up yet".
// Orders live in memory: fine for a demo, lost on restart.

const crypto = require('node:crypto');

const MAX_QTY = 50;

function razorpayConfig() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) return null;
  const api = (process.env.RAZORPAY_API || 'https://api.razorpay.com/v1').replace(/\/$/, '');
  return { keyId, keySecret, api };
}

function signatureFor(keySecret, razorpayOrderId, paymentId) {
  return crypto.createHmac('sha256', keySecret).update(`${razorpayOrderId}|${paymentId}`).digest('hex');
}

function sameHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
}

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

// JSON that is safe to drop inside a <script> tag.
const scriptJson = (v) => JSON.stringify(v).replace(/</g, '\\u003c');

const rupees = (paise) => `₹${(paise / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;

function createPayments({ readJson, sendJson, readJsonBody }) {
  const orders = new Map(); // our id -> order

  const publicOrder = (o) => ({
    orderId: o.id,
    status: o.status,
    amount: o.amount,
    currency: o.currency,
    items: o.items,
    paymentId: o.paymentId || null,
  });

  async function createOrder(req, res, origin) {
    const cfg = razorpayConfig();
    if (!cfg) return sendJson(req, res, 503, { error: 'Online payment is not set up yet' });

    const { lines } = await readJsonBody(req);
    if (!Array.isArray(lines) || lines.length === 0) return sendJson(req, res, 400, { error: 'Your cart is empty' });

    const products = new Map(readJson('products.json').map((p) => [p.id, p]));
    const items = [];
    const seen = new Set();
    let totalRupees = 0;
    for (const line of lines) {
      const product = line && products.get(line.productId);
      if (!product) return sendJson(req, res, 400, { error: `Unknown product ${line && line.productId}` });
      if (seen.has(product.id)) return sendJson(req, res, 400, { error: `${product.name} is listed twice` });
      seen.add(product.id);
      if (!Number.isInteger(line.qty) || line.qty < 1 || line.qty > MAX_QTY) {
        return sendJson(req, res, 400, { error: `Quantity for ${product.name} must be 1 to ${MAX_QTY}` });
      }
      if (product.inStock === false) return sendJson(req, res, 409, { error: `${product.name} is out of stock` });
      items.push({ productId: product.id, name: product.name, unit: product.unit, qty: line.qty, price: product.price });
      totalRupees += product.price * line.qty;
    }

    const id = crypto.randomBytes(12).toString('hex');
    const amount = Math.round(totalRupees * 100); // Razorpay wants paise
    let razorpayOrder;
    try {
      const r = await fetch(`${cfg.api}/orders`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Basic ' + Buffer.from(`${cfg.keyId}:${cfg.keySecret}`).toString('base64'),
        },
        body: JSON.stringify({ amount, currency: 'INR', receipt: id, notes: { source: 'shelfsync' } }),
      });
      razorpayOrder = await r.json().catch(() => ({}));
      if (!r.ok || !razorpayOrder.id) {
        throw new Error((razorpayOrder.error && razorpayOrder.error.description) || `Razorpay answered ${r.status}`);
      }
    } catch (err) {
      return sendJson(req, res, 502, { error: `Couldn't start the payment: ${err.message}` });
    }

    const order = {
      id,
      razorpayOrderId: razorpayOrder.id,
      amount,
      currency: 'INR',
      items,
      status: 'created',
      createdAt: new Date().toISOString(),
    };
    orders.set(id, order);
    return sendJson(req, res, 200, { ...publicOrder(order), payUrl: `${origin}/pay/${id}` });
  }

  async function verify(req, res) {
    const cfg = razorpayConfig();
    if (!cfg) return sendJson(req, res, 503, { error: 'Online payment is not set up yet' });
    const body = await readJsonBody(req);
    const order = orders.get(body.orderId);
    if (!order) return sendJson(req, res, 404, { error: 'Order not found' });
    if (order.status === 'paid') return sendJson(req, res, 200, publicOrder(order));

    const expected = signatureFor(cfg.keySecret, order.razorpayOrderId, body.razorpay_payment_id);
    if (body.razorpay_order_id !== order.razorpayOrderId || !sameHex(body.razorpay_signature, expected)) {
      return sendJson(req, res, 400, { error: 'Payment could not be verified' });
    }
    order.status = 'paid';
    order.paymentId = body.razorpay_payment_id;
    order.paidAt = new Date().toISOString();
    return sendJson(req, res, 200, publicOrder(order));
  }

  function payPage(res, id) {
    const cfg = razorpayConfig();
    const order = orders.get(id);
    const html = (body, status = 200) => {
      res.writeHead(status, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(page(body));
    };
    if (!order) return html('<h1>Order not found</h1><p>Start checkout again from the ShelfSync app.</p>', 404);
    if (!cfg) return html('<h1>Payments are not set up</h1><p>Online payment isn\'t available yet.</p>', 503);

    const items = order.items
      .map((i) => `<li><span>${i.qty} × ${escapeHtml(i.name)} <small>${escapeHtml(i.unit)}</small></span><span>${rupees(i.price * i.qty * 100)}</span></li>`)
      .join('');
    const testNote = cfg.keyId.startsWith('rzp_test_')
      ? '<p class="note">Test mode: no real money moves. Use UPI <b>success@razorpay</b> or a Razorpay test card.</p>'
      : '';
    const data = scriptJson({
      id: order.id,
      key: cfg.keyId,
      amount: order.amount,
      razorpayOrderId: order.razorpayOrderId,
      status: order.status,
    });
    html(`
      <h1>ShelfSync</h1>
      <p class="muted">Order ${escapeHtml(order.id.slice(0, 8).toUpperCase())}</p>
      <ul>${items}</ul>
      <p class="total"><span>To pay</span><span>${rupees(order.amount)}</span></p>
      <button id="pay" type="button">Pay ${rupees(order.amount)}</button>
      <p id="msg" role="status"></p>
      ${testNote}
      <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
      <script>
        const ORDER = ${data};
        const msg = document.getElementById('msg');
        const btn = document.getElementById('pay');
        function done() {
          btn.hidden = true;
          msg.className = 'ok';
          msg.textContent = 'Payment successful. You can go back to the ShelfSync app.';
        }
        function open() {
          if (typeof Razorpay === 'undefined') { msg.textContent = 'Couldn\\'t load Razorpay. Check your connection and reload.'; return; }
          msg.className = ''; msg.textContent = '';
          const rzp = new Razorpay({
            key: ORDER.key, amount: ORDER.amount, currency: 'INR', order_id: ORDER.razorpayOrderId,
            name: 'ShelfSync', description: 'Grocery order', theme: { color: '#1F6F43' },
            handler: async (r) => {
              msg.textContent = 'Confirming your payment…'; btn.disabled = true;
              const res = await fetch('/api/checkout/verify', {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ orderId: ORDER.id, ...r }),
              }).catch(() => null);
              btn.disabled = false;
              if (res && res.ok) done();
              else { msg.className = 'err'; msg.textContent = 'We couldn\\'t confirm this payment. If money was taken, it will be refunded by Razorpay.'; }
            },
            modal: { ondismiss: () => { if (!msg.textContent) msg.textContent = 'Payment not completed. Tap Pay to try again.'; } },
          });
          rzp.on('payment.failed', (e) => { msg.className = 'err'; msg.textContent = 'Payment failed: ' + e.error.description; });
          rzp.open();
        }
        btn.addEventListener('click', open);
        if (ORDER.status === 'paid') done(); else open();
      </script>`);
  }

  /// Returns a promise when it handled the request, otherwise undefined.
  function handle(req, res, p, origin) {
    if (req.method === 'POST' && p === '/api/checkout/orders') return createOrder(req, res, origin);
    if (req.method === 'POST' && p === '/api/checkout/verify') return verify(req, res);
    const status = p.match(/^\/api\/checkout\/orders\/([a-f0-9]{24})$/);
    if (req.method === 'GET' && status) {
      const order = orders.get(status[1]);
      return Promise.resolve(order ? sendJson(req, res, 200, publicOrder(order)) : sendJson(req, res, 404, { error: 'Order not found' }));
    }
    const pay = p.match(/^\/pay\/([a-f0-9]{24})$/);
    if (req.method === 'GET' && pay) return Promise.resolve(payPage(res, pay[1]));
    return undefined;
  }

  return { handle };
}

function page(body) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pay · ShelfSync</title>
<style>
  :root { color-scheme: light dark; --leaf: #1F6F43; --ink: #1B1F1A; --muted: #5E6B60; --line: #D5DED7; --bg: #F6F7F5; --card: #FFFFFF; --err: #C8402A; }
  @media (prefers-color-scheme: dark) { :root { --ink: #E8EEE9; --muted: #A3B0A6; --line: #2F3A32; --bg: #101411; --card: #171C18; --err: #FF8A75; --leaf: #2E8B57; } }
  body { margin: 0; font: 16px/1.5 system-ui, sans-serif; color: var(--ink); background: var(--bg); }
  main { max-width: 440px; margin: 24px auto; padding: 20px 16px; background: var(--card); border: 1px solid var(--line); border-radius: 16px; }
  h1 { margin: 0; font-size: 22px; color: var(--leaf); }
  .muted, small { color: var(--muted); }
  ul { list-style: none; padding: 0; margin: 16px 0; border-top: 1px solid var(--line); }
  li, .total { display: flex; justify-content: space-between; gap: 12px; padding: 10px 0; border-bottom: 1px solid var(--line); }
  .total { font-weight: 700; font-size: 18px; border: 0; }
  button { width: 100%; padding: 14px; border: 0; border-radius: 10px; background: var(--leaf); color: #fff; font: 600 16px system-ui, sans-serif; cursor: pointer; }
  button:disabled { opacity: .6; }
  button:focus-visible { outline: 3px solid var(--leaf); outline-offset: 2px; }
  #msg { min-height: 1.5em; } #msg.ok { color: var(--leaf); font-weight: 600; } #msg.err { color: var(--err); }
  .note { font-size: 13px; color: var(--muted); }
</style></head>
<body><main>${body}</main></body></html>`;
}

module.exports = { createPayments, signatureFor };
