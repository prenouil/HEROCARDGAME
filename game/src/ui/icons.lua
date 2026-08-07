-- Icônes vectorielles dessinées à la main (love.graphics, aucun fichier externe).
-- Alternative aux emoji : LÖVE ne rasterise pas correctement les polices emoji
-- couleur (voir src/ui/fonts.lua) et la police par défaut n'a pas ces glyphes
-- du tout. Ce sont des silhouettes simples, pas de l'art final — un repère
-- visuel en attendant de vraies illustrations (voir README du dossier game/).

local Sprites = require("src.ui.sprites")

local Icons = {}

-- En dessous de ce rayon, l'illustration générée par IA (voir src/ui/sprites.lua)
-- est trop petite pour être lisible (icône de coin de carte, badge de statut) --
-- on garde la silhouette vectorielle. Au-dessus, on préfère la vraie illustration
-- quand elle existe (portrait de héros/ennemi).
local SPRITE_MIN_RADIUS = 15

local function set(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

--- Épée pointant vers le haut : lame + garde + pommeau.
local function draw_sword(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx, cy - r, cx - r * 0.14, cy + r * 0.35, cx + r * 0.14, cy + r * 0.35)
  love.graphics.setLineWidth(math.max(1, r * 0.14))
  love.graphics.line(cx - r * 0.45, cy + r * 0.35, cx + r * 0.45, cy + r * 0.35)
  love.graphics.line(cx, cy + r * 0.35, cx, cy + r * 0.7)
  love.graphics.circle("line", cx, cy + r * 0.82, r * 0.12)
  love.graphics.setLineWidth(1)
end

--- Bouclier : silhouette à 5 points (plat en haut, pointe en bas).
local function draw_shield(cx, cy, r, color)
  set(color)
  local hw, hh = r * 0.65, r * 0.85
  love.graphics.polygon("fill",
    cx - hw, cy - hh,
    cx + hw, cy - hh,
    cx + hw, cy - hh * 0.15,
    cx, cy + hh,
    cx - hw, cy - hh * 0.15
  )
  set({ 1, 1, 1 }, 0.18)
  love.graphics.polygon("line",
    cx - hw, cy - hh,
    cx + hw, cy - hh,
    cx + hw, cy - hh * 0.15,
    cx, cy + hh,
    cx - hw, cy - hh * 0.15
  )
end

--- Orbe (Mage) : cercle plein + reflet.
local function draw_orb(cx, cy, r, color)
  set(color)
  love.graphics.circle("fill", cx, cy, r * 0.7)
  set({ 1, 1, 1 }, 0.55)
  love.graphics.circle("fill", cx - r * 0.22, cy - r * 0.24, r * 0.18)
end

--- Dague (Assassin) : lame courte pointant vers le bas + garde + pommeau.
local function draw_dagger(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx, cy + r * 0.75, cx - r * 0.12, cy - r * 0.15, cx + r * 0.12, cy - r * 0.15)
  love.graphics.setLineWidth(math.max(1, r * 0.12))
  love.graphics.line(cx - r * 0.38, cy - r * 0.15, cx + r * 0.38, cy - r * 0.15)
  love.graphics.line(cx, cy - r * 0.15, cx, cy - r * 0.45)
  love.graphics.circle("line", cx, cy - r * 0.55, r * 0.1)
  love.graphics.setLineWidth(1)
end

--- Cercle simple, pour les cartes génériques (pas de classe).
local function draw_generic(cx, cy, r, color)
  set(color)
  love.graphics.circle("line", cx, cy, r * 0.6)
  love.graphics.setLineWidth(math.max(1, r * 0.1))
  love.graphics.circle("line", cx, cy, r * 0.6)
  love.graphics.setLineWidth(1)
end

local DRAW_BY_CLASS = {
  guerrier = draw_sword,
  paladin = draw_shield,
  mage = draw_orb,
  assassin = draw_dagger,
  generic = draw_generic,
}

--- Dessine l'icône de classe centrée en (cx, cy) avec un rayon approximatif r.
-- Retourne false si class_id n'est pas reconnu (rien dessiné, l'appelant
-- garde son repli texte).
function Icons.draw_class(class_id, cx, cy, r, color)
  if r >= SPRITE_MIN_RADIUS then
    local img = Sprites.hero(class_id)
    if img then
      love.graphics.setColor(1, 1, 1, 1)
      Sprites.draw_centered(img, cx, cy, r)
      return true
    end
  end
  local fn = DRAW_BY_CLASS[class_id]
  if not fn then return false end
  fn(cx, cy, r, color)
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

-- ---------- bestiaire (10 silhouettes) ----------

local function draw_goblin(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx - r * 0.5, cy - r * 0.05, cx - r * 0.15, cy - r * 0.6, cx - r * 0.05, cy - r * 0.1)
  love.graphics.polygon("fill", cx + r * 0.5, cy - r * 0.05, cx + r * 0.15, cy - r * 0.6, cx + r * 0.05, cy - r * 0.1)
  love.graphics.circle("fill", cx, cy + r * 0.05, r * 0.55)
end

local function draw_skull(cx, cy, r, color)
  set(color)
  love.graphics.circle("fill", cx, cy - r * 0.1, r * 0.6)
  love.graphics.rectangle("fill", cx - r * 0.35, cy + r * 0.25, r * 0.7, r * 0.3, r * 0.08)
  set({ 0, 0, 0 }, 0.55)
  love.graphics.circle("fill", cx - r * 0.22, cy - r * 0.12, r * 0.13)
  love.graphics.circle("fill", cx + r * 0.22, cy - r * 0.12, r * 0.13)
end

local function draw_troll(cx, cy, r, color)
  set(color)
  love.graphics.circle("fill", cx, cy, r * 0.72)
  love.graphics.polygon("fill", cx - r * 0.28, cy + r * 0.35, cx - r * 0.15, cy + r * 0.05, cx - r * 0.02, cy + r * 0.35)
  love.graphics.polygon("fill", cx + r * 0.28, cy + r * 0.35, cx + r * 0.15, cy + r * 0.05, cx + r * 0.02, cy + r * 0.35)
end

local function draw_gobelourd(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill",
    cx - r * 0.6, cy - r * 0.1, cx - r * 0.35, cy - r * 0.55, cx + r * 0.15, cy - r * 0.6,
    cx + r * 0.6, cy - r * 0.15, cx + r * 0.5, cy + r * 0.4, cx - r * 0.1, cy + r * 0.6, cx - r * 0.55, cy + r * 0.25)
end

local function draw_wolf(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx - r * 0.4, cy - r * 0.5, cx - r * 0.15, cy - r * 0.1, cx - r * 0.5, cy - r * 0.05)
  love.graphics.polygon("fill", cx + r * 0.4, cy - r * 0.5, cx + r * 0.15, cy - r * 0.1, cx + r * 0.5, cy - r * 0.05)
  love.graphics.polygon("fill", cx, cy - r * 0.15, cx - r * 0.5, cy + r * 0.15, cx - r * 0.35, cy + r * 0.55, cx + r * 0.35, cy + r * 0.55, cx + r * 0.5, cy + r * 0.15)
end

local function draw_spider(cx, cy, r, color)
  set(color)
  love.graphics.setLineWidth(math.max(1, r * 0.12))
  for _, side in ipairs({ -1, 1 }) do
    for i = -1, 2 do
      love.graphics.line(cx, cy, cx + side * r * 0.85, cy - r * 0.35 + i * r * 0.28)
    end
  end
  love.graphics.setLineWidth(1)
  love.graphics.circle("fill", cx, cy, r * 0.42)
end

local function draw_necromancer(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx, cy - r * 0.15, cx - r * 0.55, cy + r * 0.65, cx + r * 0.55, cy + r * 0.65)
  love.graphics.circle("fill", cx, cy - r * 0.35, r * 0.35)
end

local function draw_golem(cx, cy, r, color)
  set(color)
  love.graphics.rectangle("fill", cx - r * 0.6, cy - r * 0.6, r * 1.2, r * 1.2, r * 0.15)
  set({ 0, 0, 0 }, 0.5)
  love.graphics.circle("fill", cx - r * 0.22, cy - r * 0.05, r * 0.1)
  love.graphics.circle("fill", cx + r * 0.22, cy - r * 0.05, r * 0.1)
end

local function draw_bandit(cx, cy, r, color)
  set(color)
  love.graphics.circle("fill", cx, cy, r * 0.62)
  set(Icons.mask_color or { 0.1, 0.08, 0.12 })
  love.graphics.rectangle("fill", cx - r * 0.62, cy - r * 0.22, r * 1.24, r * 0.32)
end

local function draw_shaman(cx, cy, r, color)
  set(color)
  love.graphics.setLineWidth(math.max(1, r * 0.14))
  love.graphics.line(cx, cy - r * 0.75, cx, cy + r * 0.75)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", cx, cy - r * 0.8, r * 0.22)
  love.graphics.polygon("fill", cx - r * 0.18, cy + r * 0.55, cx + r * 0.18, cy + r * 0.55, cx, cy + r * 0.85)
end

local DRAW_BY_ENEMY = {
  gobelin = draw_goblin,
  squelette = draw_skull,
  troll = draw_troll,
  gobelourd = draw_gobelourd,
  loup = draw_wolf,
  araignee = draw_spider,
  necromancien = draw_necromancer,
  golem = draw_golem,
  bandit = draw_bandit,
  chaman = draw_shaman,
}

--- Dessine la silhouette de l'ennemi (template_id, ex. "gobelin") centrée en
-- (cx, cy). Retourne false si non reconnu (repli texte côté appelant).
function Icons.draw_enemy(template_id, cx, cy, r, color)
  if r >= SPRITE_MIN_RADIUS then
    local img = Sprites.enemy(template_id)
    if img then
      love.graphics.setColor(1, 1, 1, 1)
      Sprites.draw_centered(img, cx, cy, r)
      return true
    end
  end
  local fn = DRAW_BY_ENEMY[template_id]
  if not fn then return false end
  fn(cx, cy, r, color)
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

-- ---------- statuts (badges) ----------

local function draw_status_defense(cx, cy, r, color) draw_shield(cx, cy, r, color) end

local function draw_status_esquive(cx, cy, r, color)
  set(color)
  love.graphics.setLineWidth(math.max(1, r * 0.16))
  love.graphics.line(cx - r * 0.6, cy - r * 0.25, cx + r * 0.15, cy - r * 0.25)
  love.graphics.line(cx - r * 0.6, cy + r * 0.25, cx + r * 0.15, cy + r * 0.25)
  love.graphics.polygon("fill", cx + r * 0.15, cy - r * 0.5, cx + r * 0.65, cy, cx + r * 0.15, cy + r * 0.5)
  love.graphics.setLineWidth(1)
end

local function draw_status_camouflage(cx, cy, r, color)
  set(color)
  love.graphics.ellipse("line", cx, cy, r * 0.7, r * 0.4)
  love.graphics.circle("fill", cx, cy, r * 0.18)
  love.graphics.setLineWidth(math.max(1, r * 0.14))
  love.graphics.line(cx - r * 0.75, cy - r * 0.55, cx + r * 0.75, cy + r * 0.55)
  love.graphics.setLineWidth(1)
end

local function draw_status_puissance(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx, cy - r * 0.75, cx - r * 0.55, cy + r * 0.35, cx + r * 0.55, cy + r * 0.35)
end

local function draw_status_saignements(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx, cy - r * 0.75, cx - r * 0.45, cy + r * 0.2, cx, cy + r * 0.55, cx + r * 0.45, cy + r * 0.2)
end

local function draw_status_incapacite(cx, cy, r, color)
  set(color)
  love.graphics.polygon("fill", cx, cy + r * 0.75, cx - r * 0.55, cy - r * 0.35, cx + r * 0.55, cy - r * 0.35)
end

local function draw_status_vulnerabilite(cx, cy, r, color)
  set(color)
  love.graphics.setLineWidth(math.max(1, r * 0.12))
  love.graphics.circle("line", cx, cy, r * 0.7)
  love.graphics.circle("line", cx, cy, r * 0.32)
  love.graphics.line(cx, cy - r * 0.85, cx, cy + r * 0.85)
  love.graphics.line(cx - r * 0.85, cy, cx + r * 0.85, cy)
  love.graphics.setLineWidth(1)
end

local DRAW_BY_STATUS = {
  defense = draw_status_defense,
  esquive = draw_status_esquive,
  camoufle = draw_status_camouflage,
  puissance = draw_status_puissance,
  saignements = draw_status_saignements,
  incapacite = draw_status_incapacite,
  vulnerabilite = draw_status_vulnerabilite,
}

--- Dessine l'icône d'un statut (clé Lua, ex. "defense", "esquive"...) centrée
-- en (cx, cy). Retourne false si non reconnu.
function Icons.draw_status(status_key, cx, cy, r, color)
  local img = Sprites.status(status_key)
  if img then
    love.graphics.setColor(1, 1, 1, 1)
    Sprites.draw_centered(img, cx, cy, r)
    return true
  end
  local fn = DRAW_BY_STATUS[status_key]
  if not fn then return false end
  fn(cx, cy, r, color)
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

return Icons
