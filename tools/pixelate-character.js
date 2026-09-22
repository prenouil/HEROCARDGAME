// Post-traitement pixel-art pour les portraits d'aventurier générés "à la main"
// via un outil externe (Gemini, etc.) -- ce script ne génère rien lui-même, il ne
// fait que forcer une vraie grille de pixels sur une image déjà produite ailleurs,
// PUIS détoure son fond (contrairement à tools/pixelate-card.js, qui ne détoure
// jamais -- voir son commentaire).
// Usage : node tools/pixelate-character.js chemin/vers/image-source.png <class_id>
// Écrit dans game/assets/characters/heroes/<class_id>.png (voir Sprites.hero,
// sprites.lua -- le jeu charge le portrait par cet id de classe, ex. "guerrier",
// "paladin"...).
//
// Même principe que pixelate-card.js (downscale vers une petite grille PUIS
// agrandissement en "plus proche voisin" pour écraser les dégradés en blocs
// nets) mais grille "character" (64x64, voir GRID_PRESETS dans lib/gen-core.js)
// et détourage par composantes connexes (stripBackground, même fonction que
// pour les héros/ennemis/icônes générés via le pipeline Cloudflare) : ces
// portraits flottent sur d'autres fonds dans l'UI (icônes, écran d'équipe,
// Forge -- voir Sprites.hero), un fond opaque n'est donc PAS voulu ici,
// contrairement aux illustrations de carte.
//
// Prérequis important : l'image source doit avoir un fond BLANC ou quasi-blanc
// (le prompt Gemini doit le demander explicitement) -- stripBackground ne sait
// détourer que du quasi-blanc, jamais une autre couleur de fond.
//
// Si la source est une CAPTURE D'ÉCRAN de l'outil de génération (boutons/pagination
// visibles autour de l'image, pas un export propre) : recadrer d'abord pour ne
// garder que l'image elle-même, ce script ne le fait pas à sa place.
//
// Archive AUSSI la source brute (2026-09-22, demande explicite -- garder trace de
// l'image Gemini telle que fournie, avant tout traitement) dans
// archive/gemini-sources/heroes/<class_id>.png -- hors de game/, jamais empaqueté
// dans le jeu. Écrase une archive précédente du même id (une regénération remplace
// l'ancienne source, comme pour l'asset final lui-même).

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { GRID_PRESETS, FINAL_SIZE, stripBackground } = require('./lib/gen-core');

async function main() {
  const [, , inPath, classId] = process.argv;
  if (!inPath || !classId) {
    console.error('Usage: node tools/pixelate-character.js chemin/vers/image-source.png <class_id>');
    process.exit(1);
  }
  if (!fs.existsSync(inPath)) {
    console.error('Fichier introuvable :', inPath);
    process.exit(1);
  }

  const gridSize = GRID_PRESETS.character;
  const outPath = path.join(__dirname, '..', 'game', 'assets', 'characters', 'heroes', `${classId}.png`);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const archivePath = path.join(__dirname, '..', 'archive', 'gemini-sources', 'heroes', `${classId}.png`);
  fs.mkdirSync(path.dirname(archivePath), { recursive: true });
  fs.copyFileSync(inPath, archivePath);

  const small = await sharp(inPath).resize(gridSize, gridSize, { fit: 'cover', kernel: 'nearest' }).toBuffer();
  const transparent = await stripBackground(small, gridSize, gridSize);
  await sharp(transparent).resize(FINAL_SIZE, FINAL_SIZE, { kernel: 'nearest' }).toFile(outPath);

  console.log('OK ->', outPath, `(grille ${gridSize}x${gridSize}, détourée)`);
  console.log('   archive source ->', archivePath);
}

main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
