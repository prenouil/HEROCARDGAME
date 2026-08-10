-- Fond de l'écran de combat : dégradé procédural + vignette légère, teinté selon
-- la catégorie d'ennemis affrontée (2026-08-10, décision party mode). Volontairement
-- sans asset image -- même logique que le son chiptune procédural du projet (voir
-- game/README.md) : gratuit, jamais flou, jamais raté par une génération IA.

local Theme = require("src.ui.theme")

local Background = {}

local STRIPES = 64        -- bandes horizontales du dégradé
local VIGNETTE_SIZE = 140 -- px, profondeur du fondu sur chaque bord
local VIGNETTE_STEPS = 10
local VIGNETTE_MAX_ALPHA = 0.45

-- Catégorie de biome par ennemi -- lecture purement visuelle (game/src/data/enemies.lua
-- ne porte pas cette info et n'en a pas besoin, aucune règle n'en dépend).
local ENEMY_BIOME = {
  gobelin = "foret", gobelourd = "foret", troll = "foret", loup = "foret", araignee = "foret",
  squelette = "donjon", golem = "donjon", necromancien = "donjon",
  bandit = "repaire", chaman = "repaire",
}

local BIOMES = {
  foret   = { top = { 0.24, 0.38, 0.24 }, bottom = { 0.02, 0.03, 0.02 } },
  donjon  = { top = { 0.22, 0.26, 0.36 }, bottom = { 0.02, 0.03, 0.05 } },
  repaire = { top = { 0.36, 0.24, 0.12 }, bottom = { 0.04, 0.03, 0.02 } },
  defaut  = { top = Theme.panel_light, bottom = Theme.bg },
}

--- Biome dominant d'un combat : celui du premier ennemi vivant trouvé -- un mélange
-- pondéré n'apporterait rien de lisible en plus pour une simple teinte d'ambiance.
local function biome_for(enemies)
  for _, e in ipairs(enemies or {}) do
    if e.hp > 0 then
      local biome = ENEMY_BIOME[e.template_id]
      if biome then return BIOMES[biome] end
    end
  end
  return BIOMES.defaut
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Bandes contiguës par bornes entières (jamais de chevauchement) -- avec l'alpha
-- blending de la vignette ci-dessous, un chevauchement même d'1px additionne deux
-- fois la transparence à la jointure et dessine une grille visible (bug corrigé
-- le 2026-08-10, signalé par le porteur de projet).
local function band_bounds(i, count, total)
  local from = math.floor(total * (i - 1) / count)
  local to = math.floor(total * i / count)
  return from, to - from
end

function Background.draw(enemies, w, h)
  local pal = biome_for(enemies)
  for i = 1, STRIPES do
    local t = (i - 1) / (STRIPES - 1)
    local y, band_h = band_bounds(i, STRIPES, h)
    love.graphics.setColor(lerp(pal.top[1], pal.bottom[1], t), lerp(pal.top[2], pal.bottom[2], t), lerp(pal.top[3], pal.bottom[3], t), 1)
    love.graphics.rectangle("fill", 0, y, w, band_h)
  end

  for i = 1, VIGNETTE_STEPS do
    local a = (1 - (i - 1) / VIGNETTE_STEPS) * VIGNETTE_MAX_ALPHA
    local y, seg_h = band_bounds(i, VIGNETTE_STEPS, VIGNETTE_SIZE)
    local x, seg_w = y, seg_h
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle("fill", 0, y, w, seg_h)                  -- haut
    love.graphics.rectangle("fill", 0, h - y - seg_h, w, seg_h)      -- bas
    love.graphics.rectangle("fill", x, 0, seg_w, h)                  -- gauche
    love.graphics.rectangle("fill", w - x - seg_w, 0, seg_w, h)      -- droite
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Background
