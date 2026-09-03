// Génération d'images IA via Stability AI (payant, pas de quota journalier) --
// variante DE TEST de ./gen-core.js (Cloudflare Workers AI, gratuit/limité) :
// même signature generateOne(subject, outPath, gridArg)/mêmes conventions de
// sortie (grille 32x32 "icon"/64x64 "character", upscale nearest à 512,
// détourage du fond blanc), pour comparer les résultats côte à côte avant de
// basculer définitivement -- voir tools/generate-image-stability.js.
//
// Nécessite dans .env (racine du projet, jamais commité) :
//   STABILITY_API_KEY=...   (créé sur platform.stability.ai -> API Keys)
//
// Différence clé avec Cloudflare : Stable Image Core expose un style_preset
// "pixel-art" NATIF -- plus besoin de simuler le pixel art par un downscale/
// upscale forcé sur un modèle généraliste, on demande directement ce rendu
// au modèle. Le détourage du fond (stripBackground) reste réutilisé tel
// quel : ce style_preset ne garantit pas un fond transparent, juste un style.

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { loadEnv, stripBackground } = require('./gen-core');

const STYLE_SUFFIX = ', 16-bit retro video game sprite, limited color palette, flat shading, white background, no text, single object, nothing else in the image';
// Mêmes 2 formules verrouillées que gen-core.js (voir son commentaire pour
// l'historique/la justification) -- reprises à l'identique pour comparer à
// prompt égal, seul le backend change.
const CHARACTER_STYLE_SUFFIX = ', Super Nintendo RPG character sprite in the style of Final Fantasy VI, chibi proportions with a slightly oversized head, simplified shapes, minimal ornamentation, big expressive face, arms symmetrical, character facing forward toward the viewer, static portrait pose like a JRPG character select screen, equipment held visibly';
const ICON_STYLE_SUFFIX = ', bold simple flat icon, thick black outline, high contrast, instantly recognizable clean silhouette, centered, no fine detail, no border, no frame, no vignette';

const GRID_PRESETS = { icon: 32, character: 64 };
const FINAL_SIZE = 512;
const ENDPOINT = 'https://api.stability.ai/v2beta/stable-image/generate/core';

async function generateOne(subject, outPath, gridArg) {
  const gridSize = !gridArg ? GRID_PRESETS.icon : (GRID_PRESETS[gridArg] || parseInt(gridArg, 10));
  const env = loadEnv();
  const apiKey = env.STABILITY_API_KEY;
  if (!apiKey) throw new Error('STABILITY_API_KEY manquant dans .env');

  const prompt = subject + STYLE_SUFFIX
    + (gridSize === GRID_PRESETS.character ? CHARACTER_STYLE_SUFFIX : '')
    + (gridSize === GRID_PRESETS.icon ? ICON_STYLE_SUFFIX : '');

  const form = new FormData();
  form.append('prompt', prompt);
  form.append('output_format', 'png');
  form.append('style_preset', 'pixel-art');
  // 1:1 par défaut déjà ce qu'il nous faut (icônes/portraits carrés) --
  // aspect_ratio omis volontairement.

  const res = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, Accept: 'image/*' },
    body: form,
  });
  if (res.status !== 200) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text.slice(0, 500)}`);
  }
  const rawBuf = Buffer.from(await res.arrayBuffer());

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const gridBuf = await sharp(rawBuf).resize(gridSize, gridSize, { fit: 'cover', kernel: 'nearest' }).toBuffer();
  const transparentGridBuf = await stripBackground(gridBuf, gridSize, gridSize);
  await sharp(transparentGridBuf).resize(FINAL_SIZE, FINAL_SIZE, { kernel: 'nearest' }).toFile(outPath);
  return { gridSize };
}

module.exports = { generateOne };
