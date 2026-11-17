// Hosted mode (e.g. Render): first password from ADMIN_PASSWORD, client
// address from X-Forwarded-For. Separate file = separate process, clean env.
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'shelfsync-env-'));
for (const f of ['home.json', 'products.json']) fs.copyFileSync(path.join(__dirname, 'content', f), path.join(tmp, f));
process.env.CONTENT_DIR = tmp;
process.env.DATA_DIR = path.join(tmp, 'data');
process.env.ADMIN_PASSWORD = 'from-env-secret';
process.env.TRUST_PROXY = '1';
process.env.WEB_DIR = path.join(tmp, 'no-web-build'); // root falls back to /admin
const { createServer } = require('./server');

let server, base;
before(async () => {
  server = createServer();
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const login = (password, ip) =>
  fetch(`${base}/api/admin/login`, {
    method: 'POST',
    body: JSON.stringify({ password }),
    headers: { 'X-Forwarded-For': ip },
  });

test('ADMIN_PASSWORD works as the first password; setup is closed', async () => {
  const status = await (await fetch(`${base}/api/admin/status`)).json();
  assert.strictEqual(status.passwordSet, true);
  assert.strictEqual(status.canSetup, false);
  assert.strictEqual((await login('from-env-secret', '1.1.1.1')).status, 200);
  assert.ok(!fs.existsSync(path.join(tmp, 'data', 'admin.json')), 'env password is not written to disk');
});

test('lockout is per forwarded client, so one guesser does not lock others out', async () => {
  for (let i = 0; i < 5; i++) assert.strictEqual((await login('wrong-' + i, '6.6.6.6')).status, 401);
  assert.strictEqual((await login('from-env-secret', '6.6.6.6')).status, 429);
  assert.strictEqual((await login('from-env-secret', '7.7.7.7')).status, 200);
});

test('a global cap still limits guessing with rotating fake addresses', async () => {
  // 5 failures already counted above; 15 more reach the cap of 20.
  for (let i = 0; i < 15; i++) assert.strictEqual((await login('nope-' + i, `10.0.0.${i}`)).status, 401);
  assert.strictEqual((await login('from-env-secret', '8.8.8.8')).status, 429);
});

test('root redirects to the admin page', async () => {
  const res = await fetch(`${base}/`, { redirect: 'manual' });
  assert.strictEqual(res.status, 302);
  assert.strictEqual(res.headers.get('location'), '/admin');
});
