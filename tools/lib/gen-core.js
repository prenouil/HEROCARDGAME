// Coeur partagé de génération d'images (utilisé par generate-image.js et generate-batch.js).
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const STYLE_SUFFIX = ', pixel art style, 16-bit retro video game sprite, limited color palette, blocky pixels, hard edges, no anti-aliasing, no gradient, no blur, flat shading, white background, no text, single object, nothing else in the image';
// Style verrouillé le 2026-08-10 (référence : planche de portraits Final Fantasy VI fournie
// par le porteur de projet) : uniquement pour la grille "character" (les icônes -- armes,
// mots-clés -- n'ont ni tête ni posture). Formule retenue après comparaison de 10 essais sur
// le Guerrier (variante "D", validée explicitement par le porteur de projet) : portrait
// statique façon écran de sélection JRPG, formes simplifiées, peu d'ornementation, grand
// visage expressif -- contrairement à la planche de référence brute, l'équipement (arme/
// bouclier/etc.) reste visible en main (décision explicite -- lecture de classe immédiate
// en combat).
const CHARACTER_STYLE_SUFFIX = ', Super Nintendo RPG character sprite in the style of Final Fantasy VI, chibi proportions with a slightly oversized head, simplified shapes, minimal ornamentation, big expressive face, arms symmetrical, character facing forward toward the viewer, static portrait pose like a JRPG character select screen, equipment held visibly';
// Style verrouillé le 2026-08-10 : à 32x32, la marge d'erreur est minime -- sans ces contraintes
// le premier essai (23 icônes) est ressorti majoritairement illisible (silhouettes floues,
// texturées, parfois une bordure/vignette parasite que le détourage quasi-blanc ne peut pas
// nettoyer puisqu'elle n'est pas blanche). Uniquement pour la grille "icon".
const ICON_STYLE_SUFFIX = ', bold simple flat icon, thick black outline, high contrast, instantly recognizable clean silhouette, centered, no fine detail, no border, no frame, no vignette';
const MODEL = '@cf/black-forest-labs/flux-1-schnell';
const GRID_PRESETS = { icon: 32, character: 64 };
const FINAL_SIZE = 512;
const WHITE_THRESHOLD = 230; // par canal
const SMALL_ISLAND_MAX = 2; // taille max (en pixels de grille) d'une zone quasi-blanche protégée (probable reflet)

// Détourage par composantes connexes : toute zone quasi-blanche connectée de taille > SMALL_ISLAND_MAX
// devient transparente, qu'elle touche le bord ou non (corrige le cas d'un interstice clair entre les
// jambes d'un personnage, isolé du bord par les pieds, mais qui est bien du fond et pas un reflet).
// Seules les toutes petites taches (1-2 px) restent opaques, sur l'hypothèse que c'est un reflet/détail.
function stripNearWhiteComponents(data, width, height, channels) {
  const isNearWhite = (px) => {
    const idx = px * channels;
    return data[idx] >= WHITE_THRESHOLD && data[idx + 1] >= WHITE_THRESHOLD && data[idx + 2] >= WHITE_THRESHOLD;
  };
  const visited = new Uint8Array(width * height);
  for (let sy = 0; sy < height; sy++) {
    for (let sx = 0; sx < width; sx++) {
      const startPx = sy * width + sx;
      if (visited[startPx] || !isNearWhite(startPx)) continue;
      const component = [startPx];
      visited[startPx] = 1;
      let head = 0;
      while (head < component.length) {
        const px = component[head++];
        const x = px % width, y = Math.floor(px / width);
        const neighbors = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]];
        for (const [nx, ny] of neighbors) {
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          const npx = ny * width + nx;
          if (visited[npx] || !isNearWhite(npx)) continue;
          visited[npx] = 1;
          component.push(npx);
        }
      }
      if (component.length > SMALL_ISLAND_MAX) {
        for (const px of component) data[px * channels + 3] = 0;
      }
    }
  }
}

async function stripBackground(buf, width, height) {
  const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  stripNearWhiteComponents(data, info.width, info.height, info.channels);
  return sharp(data, { raw: { width: info.width, height: info.height, channels: info.channels } }).png().toBuffer();
}

function loadEnv() {
  const envPath = path.join(__dirname, '..', '..', '.env');
  const env = {};
  if (fs.existsSync(envPath)) {
    fs.readFileSync(envPath, 'utf8').split('\n').forEach((line) => {
      const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
      if (m) env[m[1]] = m[2].trim();
    });
  }
  return env;
}

async function generateOne(subject, outPath, gridArg) {
  const gridSize = !gridArg ? GRID_PRESETS.icon : (GRID_PRESETS[gridArg] || parseInt(gridArg, 10));
  const env = loadEnv();
  const accountId = env.CLOUDFLARE_ACCOUNT_ID;
  const token = env.CLOUDFLARE_API_TOKEN;
  if (!accountId || !token) throw new Error('CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN manquants dans .env');

  const prompt = subject + STYLE_SUFFIX
    + (gridSize === GRID_PRESETS.character ? CHARACTER_STYLE_SUFFIX : '')
    + (gridSize === GRID_PRESETS.icon ? ICON_STYLE_SUFFIX : '');
  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${MODEL}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt }),
  });
  const text = await res.text();
  if (res.status !== 200) throw new Error(`HTTP ${res.status}: ${text.slice(0, 500)}`);
  const data = JSON.parse(text);
  if (!data.result || !data.result.image) throw new Error(`Pas d'image dans la réponse: ${text.slice(0, 500)}`);
  const rawBuf = Buffer.from(data.result.image, 'base64');

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const gridBuf = await sharp(rawBuf).resize(gridSize, gridSize, { fit: 'cover', kernel: 'nearest' }).toBuffer();
  const transparentGridBuf = await stripBackground(gridBuf, gridSize, gridSize);
  await sharp(transparentGridBuf).resize(FINAL_SIZE, FINAL_SIZE, { kernel: 'nearest' }).toFile(outPath);
  return { gridSize };
}

module.exports = { generateOne, loadEnv, stripBackground };
