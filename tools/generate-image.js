// Génération d'images IA via Cloudflare Workers AI (gratuit, quota quotidien).
// Usage : node tools/generate-image.js "sujet a dessiner" chemin/de/sortie.png [icon|character|<tailleGrille>]
//
// Nécessite dans .env (racine du projet, jamais commité) :
//   CLOUDFLARE_ACCOUNT_ID=...
//   CLOUDFLARE_API_TOKEN=...   (créé avec le modèle de permission "Workers AI")
//
// Style verrouillé le 2026-08-07 (voir game/assets/style-reference/) : pixel art, 2 paliers de grille —
//   "icon"     = 32x32 (armes, boucliers, mots-clés, objets simples)
//   "character" = 64x64 (aventuriers, ennemis, portraits)
// La génération directe à basse résolution ne fonctionne pas (le modèle sort une image quasi blanche/du
// bruit en dessous de ~128px, non conçu pour ça) : on génère donc en pleine résolution avec un prompt
// pixel art, puis on downscale/upscale nous-mêmes (sharp) pour forcer une vraie grille de pixels nette.

const { generateOne } = require('./lib/gen-core');

async function main() {
  const [, , subject, outPath, gridArg] = process.argv;
  if (!subject || !outPath) {
    console.error('Usage: node tools/generate-image.js "sujet a dessiner" chemin/de/sortie.png [icon|character|<tailleGrille>]');
    process.exit(1);
  }
  const { gridSize } = await generateOne(subject, outPath, gridArg);
  console.log('OK ->', outPath, `(grille ${gridSize}x${gridSize})`);
}

main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
