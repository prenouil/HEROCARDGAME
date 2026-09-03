// Test de la génération via Stability AI, en parallèle du pipeline Cloudflare
// existant (tools/generate-image.js) -- voir tools/lib/gen-core-stability.js.
// Usage : node tools/generate-image-stability.js "sujet a dessiner" chemin/de/sortie.png [icon|character|<tailleGrille>]
//
// Nécessite dans .env : STABILITY_API_KEY=...

const { generateOne } = require('./lib/gen-core-stability');

async function main() {
  const [, , subject, outPath, gridArg] = process.argv;
  if (!subject || !outPath) {
    console.error('Usage: node tools/generate-image-stability.js "sujet a dessiner" chemin/de/sortie.png [icon|character|<tailleGrille>]');
    process.exit(1);
  }
  const { gridSize } = await generateOne(subject, outPath, gridArg);
  console.log('OK ->', outPath, `(grille ${gridSize}x${gridSize})`);
}

main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
