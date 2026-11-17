// Rebuilds the Flutter web app and copies it into cms/web, which the CMS
// serves at "/". Run from cms/: `npm run build-web` (needs Flutter installed).
// CanvasKit is left out on purpose: the app loads it from Google's CDN, and
// the local copy would add ~30 MB to the repo.
const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const appDir = path.join(__dirname, '..', 'app');
const built = path.join(appDir, 'build', 'web');
const out = path.join(__dirname, 'web');

execSync('flutter build web --release', { cwd: appDir, stdio: 'inherit', shell: true });

const required = ['index.html', 'main.dart.js', 'assets/fonts/MaterialIcons-Regular.otf'];
const missing = required.filter((f) => !fs.existsSync(path.join(built, f)));
if (missing.length) {
  console.error(`Build output is incomplete (missing ${missing.join(', ')}). Run it again.`);
  process.exit(1);
}

fs.mkdirSync(out, { recursive: true });
for (const entry of fs.readdirSync(out)) fs.rmSync(path.join(out, entry), { recursive: true, force: true });
fs.cpSync(built, out, {
  recursive: true,
  filter: (src) => !/[\\/](canvaskit|\.last_build_id)$/.test(src),
});
console.log(`Copied web app to ${out}`);
