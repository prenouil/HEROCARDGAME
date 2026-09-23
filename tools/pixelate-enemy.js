// Post-traitement pixel-art pour les sprites d'ennemi générés "à la main" via un
// outil externe (Gemini, etc.) -- même principe que tools/pixelate-character.js
// (downscale PUIS agrandissement en "plus proche voisin", détourage du fond
// quasi-blanc) mais écrit dans game/assets/characters/enemies/<template_id>.png
// (voir Sprites.enemy, sprites.lua).
//
// Grille "enemy" (96x96), PAS "character" (64x64, réservée aux 6 aventuriers) --
// 2026-09-23, demande explicite : les silhouettes de bestiaire ont souvent une
// arme/des ornements fins (arc, plumes, fissures de golem) qui se perdent à 64.
// Voir GRID_PRESETS dans lib/gen-core.js.
//
// Usage : node tools/pixelate-enemy.js chemin/vers/image-source.png <template_id>
// `template_id` = l'id de l'ennemi dans game/src/data/enemies.lua (ex. "gobelin",
// "aigle-vol" pour la variante en vol de l'Aigle Géant).
//
// Prérequis important : l'image source doit avoir un fond BLANC ou quasi-blanc
// (le prompt Gemini doit le demander explicitement) -- stripBackground ne sait
// détourer que du quasi-blanc, jamais une autre couleur de fond.
//
// Archive AUSSI la source brute (2026-09-22, demande explicite -- garder trace de
// l'image Gemini telle que fournie, avant tout traitement) dans
// archive/gemini-sources/enemies/<template_id>.png -- hors de game/, jamais
// empaqueté dans le jeu. Écrase une archive précédente du même id (une
// regénération remplace l'ancienne source, comme pour l'asset final lui-même).

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { GRID_PRESETS, FINAL_SIZE, stripBackground } = require('./lib/gen-core');

async function main() {
  const [, , inPath, templateId] = process.argv;
  if (!inPath || !templateId) {
    console.error('Usage: node tools/pixelate-enemy.js chemin/vers/image-source.png <template_id>');
    process.exit(1);
  }
  if (!fs.existsSync(inPath)) {
    console.error('Fichier introuvable :', inPath);
    process.exit(1);
  }

  const gridSize = GRID_PRESETS.enemy;
  const outPath = path.join(__dirname, '..', 'game', 'assets', 'characters', 'enemies', `${templateId}.png`);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const archivePath = path.join(__dirname, '..', 'archive', 'gemini-sources', 'enemies', `${templateId}.png`);
  fs.mkdirSync(path.dirname(archivePath), { recursive: true });
  fs.copyFileSync(inPath, archivePath);

  const small = await sharp(inPath).resize(gridSize, gridSize, { fit: 'cover', kernel: 'nearest' }).toBuffer();
  const transparent = await stripBackground(small, gridSize, gridSize);
  await sharp(transparent).resize(FINAL_SIZE, FINAL_SIZE, { kernel: 'nearest' }).toFile(outPath);

  console.log('OK ->', outPath, `(grille ${gridSize}x${gridSize}, détourée)`);
  console.log('   archive source ->', archivePath);
}

main().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
