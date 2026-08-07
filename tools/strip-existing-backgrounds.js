// Applique le détourage (flood-fill transparence) aux 37 assets déjà générés, sans les regénérer
// (économise le quota gratuit). Usage : node tools/strip-existing-backgrounds.js
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { stripBackground } = require('./lib/gen-core');
const manifest = require('./asset-manifest');

async function main() {
  const root = path.join(__dirname, '..');
  let done = 0;
  for (const item of manifest) {
    const outPath = path.join(root, item.out);
    if (!fs.existsSync(outPath)) { console.log('SKIP (absent) ->', item.out); continue; }
    const buf = fs.readFileSync(outPath);
    const meta = await sharp(buf).metadata();
    const transparentBuf = await stripBackground(buf, meta.width, meta.height);
    fs.writeFileSync(outPath, transparentBuf);
    console.log('OK ->', item.out);
    done++;
  }
  console.log(`\n${done}/${manifest.length} fichiers détourés.`);
}

main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
