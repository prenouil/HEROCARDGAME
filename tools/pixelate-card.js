// Post-traitement pixel-art pour les illustrations de carte générées "à la main"
// via un outil externe (Gemini, etc.) -- ce script ne génère rien lui-même, il ne
// fait que forcer une vraie grille de pixels sur une image déjà produite ailleurs.
// Usage : node tools/pixelate-card.js chemin/vers/image-source.png <code-carte>
// Écrit dans game/assets/cards/<code-carte>.png (voir Sprites.card, sprites.lua --
// le jeu charge l'illustration par CE code, pas par le nom affiché de la carte).
//
// Archive AUSSI la source brute (2026-09-22, demande explicite -- garder trace de
// l'image Gemini telle que fournie, avant tout traitement) dans
// archive/gemini-sources/cards/<code-carte>.png -- hors de game/, jamais empaqueté
// dans le jeu. Écrase une archive précédente du même code (une regénération remplace
// l'ancienne source, comme pour l'asset final lui-même).
//
// Les générateurs généralistes (Gemini compris) ne produisent jamais du vrai pixel
// art malgré le prompt : "pixel art style" en texte seul reste une peinture
// numérique avec un filtre -- dégradés doux, anti-aliasing, grille non alignée.
// Comme pour tous les autres assets du jeu (héros/ennemis/icônes, voir
// tools/lib/gen-core.js), le pixel art "dur" vient toujours d'un downscale vers
// une petite grille PUIS d'un agrandissement en "plus proche voisin" (jamais
// l'inverse) qui écrase les dégradés en blocs nets -- jamais du modèle seul.
//
// Pas de détourage transparent ici (contrairement à stripBackground dans
// gen-core.js, utilisé pour les héros/ennemis/icônes qui flottent sur un autre
// fond) : l'illustration de carte remplit tout son cadre sur la carte
// (Sprites.draw_cover, voir game/src/ui/sprites.lua), un fond opaque est donc
// normal et voulu, pas à retirer.
//
// Si la source est une CAPTURE D'ÉCRAN de l'outil de génération (boutons/pagination
// visibles autour de l'image, pas un export propre) : recadrer d'abord pour ne
// garder que l'image elle-même, ce script ne le fait pas à sa place.

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { GRID_PRESETS, FINAL_SIZE } = require('./lib/gen-core');

async function main() {
  const [, , inPath, code] = process.argv;
  if (!inPath || !code) {
    console.error('Usage: node tools/pixelate-card.js chemin/vers/image-source.png <code-carte>');
    process.exit(1);
  }
  if (!fs.existsSync(inPath)) {
    console.error('Fichier introuvable :', inPath);
    process.exit(1);
  }

  const gridSize = GRID_PRESETS.card;
  const outPath = path.join(__dirname, '..', 'game', 'assets', 'cards', `${code}.png`);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const archivePath = path.join(__dirname, '..', 'archive', 'gemini-sources', 'cards', `${code}.png`);
  fs.mkdirSync(path.dirname(archivePath), { recursive: true });
  fs.copyFileSync(inPath, archivePath);

  const small = await sharp(inPath).resize(gridSize, gridSize, { fit: 'cover', kernel: 'nearest' }).toBuffer();
  await sharp(small).resize(FINAL_SIZE, FINAL_SIZE, { kernel: 'nearest' }).toFile(outPath);

  console.log('OK ->', outPath, `(grille ${gridSize}x${gridSize})`);
  console.log('   archive source ->', archivePath);
}

main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
