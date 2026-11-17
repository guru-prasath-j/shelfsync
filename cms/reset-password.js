// Forgot the admin password? Run `npm run reset-password` on the PC that runs
// the CMS. It deletes the stored hash; the next admin login (from this PC or a
// USB-connected phone) asks for a new password. Restart the CMS afterwards so
// old logins are dropped.
const fs = require('node:fs');
const path = require('node:path');

const file = path.join(process.env.DATA_DIR || path.join(__dirname, 'data'), 'admin.json');
if (fs.existsSync(file)) {
  fs.unlinkSync(file);
  console.log('Admin password removed. Restart the CMS, then set a new one from the app or /admin.');
} else {
  console.log('No admin password is set.');
}
