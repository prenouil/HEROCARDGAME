// Génère tous les assets listés dans asset-manifest.js, séquentiellement (respect du quota gratuit).
// Usage : node tools/generate-batch.js [--retry]   (--retry : ne régénère que les fichiers absents/échoués)
const path = require('path');
const fs = require('fs');
const { generateOne } = require('./lib/gen-core');
const manifest = require('./asset-manifest');

async function main() {
  const retryOnly = process.argv.includes('--retry');
  const root = path.join(__dirname, '..');
  const results = { ok: [], failed: [] };

  for (const item of manifest) {
    const outPath = path.join(root, item.out);
    if (retryOnly && fs.existsSync(outPath)) {
      console.log('SKIP (déjà présent) ->', item.out);
      continue;
    }
    process.stdout.write(`GEN ${item.id} (${item.grid}) -> ${item.out} ... `);
    try {
      await generateOne(item.subject, outPath, item.grid);
      console.log('OK');
      results.ok.push(item.id);
    } catch (e) {
      console.log('FAILED:', e.message.slice(0, 200));
      results.failed.push({ id: item.id, error: e.message });
    }
  }

  console.log('\n=== Résumé ===');
  console.log('Réussis :', results.ok.length, '/', manifest.length);
  if (results.failed.length) {
    console.log('Échoués :', results.failed.map(f => f.id).join(', '));
  }
}

main().catch((e) => { console.error('BATCH FAILED:', e.message); process.exit(1); });
