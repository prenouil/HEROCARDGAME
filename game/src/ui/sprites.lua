-- Chargement paresseux des illustrations générées par IA (voir tools/asset-manifest.js
-- et gdd.md -> Art Style). Filtre "nearest" obligatoire : sans lui LÖVE lisse le pixel
-- art à l'affichage et tout l'effort de grille nette (tools/lib/gen-core.js) est perdu
-- à l'écran. Si un fichier est absent, l'appelant (src/ui/icons.lua) retombe sur la
-- silhouette vectorielle dessinée à la main -- jamais d'erreur, jamais de trou visuel.

local Sprites = {}

local cache = {}

-- Boîte englobante des pixels non-transparents (coordonnées dans l'image source).
-- Nécessaire car le fond détouré (voir tools/lib/gen-core.js) laisse une marge
-- transparente variable selon le sujet (une épée en diagonale ne remplit pas son
-- cadre carré comme un cœur rond le fait) -- sans ça, le texte inline (richtext.lua)
-- réserverait toujours la largeur du cadre entier et laisserait un vide visible
-- avant le mot suivant.
local function compute_bbox(image_data)
  local w, h = image_data:getDimensions()
  local min_x, min_y, max_x, max_y = w, h, -1, -1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = image_data:getPixel(x, y)
      if a > 0.05 then
        if x < min_x then min_x = x end
        if x > max_x then max_x = x end
        if y < min_y then min_y = y end
        if y > max_y then max_y = y end
      end
    end
  end
  if max_x < 0 then return { x = 0, y = 0, w = w, h = h } end -- image entièrement transparente : filet de sécurité
  return { x = min_x, y = min_y, w = max_x - min_x + 1, h = max_y - min_y + 1 }
end

local function load(path)
  if cache[path] ~= nil then
    if cache[path] == false then return nil end
    return cache[path]
  end
  local ok, image_data = pcall(love.image.newImageData, "assets/" .. path)
  if not ok then
    cache[path] = false
    return nil
  end
  local img = love.graphics.newImage(image_data)
  img:setFilter("nearest", "nearest")
  local entry = { image = img, bbox = compute_bbox(image_data) }
  cache[path] = entry
  return entry
end

local HERO_PATH = {
  guerrier = "characters/heroes/guerrier.png",
  paladin = "characters/heroes/paladin.png",
  mage = "characters/heroes/mage.png",
  assassin = "characters/heroes/assassin.png",
}

-- Clé Lua des statuts (src/ui/icons.lua DRAW_BY_STATUS) -> chemin d'asset. "defense"
-- réutilise l'icône du mot-clé "bouclier" (même symbole, pas de doublon généré) ;
-- "saignements" (pluriel côté code) pointe vers l'asset "saignement" (singulier,
-- convention du glossaire).
local STATUS_PATH = {
  defense = "icons/keywords/bouclier.png",
  esquive = "icons/status/esquive.png",
  camoufle = "icons/status/camoufle.png",
  puissance = "icons/status/puissance.png",
  saignements = "icons/status/saignement.png",
  incapacite = "icons/status/incapacite.png",
  vulnerabilite = "icons/status/vulnerabilite.png",
}

function Sprites.hero(class_id)
  local path = HERO_PATH[class_id]
  return path and load(path)
end

function Sprites.enemy(template_id)
  return load("characters/enemies/" .. template_id .. ".png")
end

function Sprites.status(status_key)
  local path = STATUS_PATH[status_key]
  return path and load(path)
end

function Sprites.keyword(key)
  return load("icons/keywords/" .. key .. ".png")
end

--- Dessine `entry` (retour de Sprites.hero/enemy/status/keyword) centrée en
-- (cx, cy), mise à l'échelle pour tenir dans un diamètre 2*r sans déformation
-- (ratio conservé, l'image source est carrée de toute façon -- 512x512 --
-- mais on ne présume rien).
function Sprites.draw_centered(entry, cx, cy, r)
  local img = entry.image
  local iw, ih = img:getDimensions()
  local scale = (2 * r) / math.max(iw, ih)
  love.graphics.draw(img, cx, cy, 0, scale, scale, iw / 2, ih / 2)
end

--- Dimensions (largeur, hauteur) occupées par le contenu RÉEL de `entry` (sa
-- boîte englobante, pas le cadre transparent complet) une fois mis à l'échelle
-- pour tenir dans un carré `box` x `box` -- utile pour un alignement de texte
-- qui ne laisse pas de vide devant/derrière l'icône (voir richtext.lua).
function Sprites.visual_size(entry, box)
  local iw, ih = entry.image:getDimensions()
  local scale = box / math.max(iw, ih)
  return entry.bbox.w * scale, entry.bbox.h * scale
end

return Sprites
