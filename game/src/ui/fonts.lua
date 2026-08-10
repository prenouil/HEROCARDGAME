-- Petit cache de polices LÖVE par taille, pour éviter de recréer des Font
-- objects à chaque frame (coûteux) tout en gardant plusieurs tailles de texte.
--
-- Police de corps : m5x7 (Daniel "Managore" Linssen), verrouillée le 2026-08-10
-- pour la lisibilité (demande explicite -- charset Latin étendu, accents
-- français couverts) sur tout le texte de jeu (cartes, dégâts, tooltips).
-- Filtre "nearest" (comme les sprites, voir sprites.lua) pour rester nette,
-- une police pixel lissée perdant tout son intérêt. Repli sur la police par
-- défaut de LÖVE si le fichier est absent (pcall, jamais de crash).
--
-- BODY_FONT_NATIVE_SIZE = 16 : mesuré dans les tables TrueType du fichier
-- (unitsPerEm 1024, majuscules à 448 unités, x-height à 320 -- 64 unités =
-- 1 pixel natif, d'où le nom "m5x7" : 448/64=7, 320/64=5). m5x7 n'est nette
-- QU'À des multiples exacts de cette taille -- en dessous, aucun hinting ne
-- la sauve (essayé "mono" -- glyphes écrasés -- puis "none" -- toujours
-- flou -- les deux confirment que c'est une taille trop petite, pas un
-- réglage de rendu). Tout le texte du jeu est actuellement demandé entre 9
-- et 14 : sous le seuil. Fonts.get retombe donc sur la police par défaut de
-- LÖVE (hintée pour rester lisible en petit) en dessous de 16, et n'utilise
-- m5x7 qu'à 16 ou plus -- priorité donnée à la lisibilité demandée par le
-- porteur de projet plutôt qu'à afficher m5x7 partout coûte que coûte.
--
-- Fonts.icon(size) tente en plus de charger une police système capable
-- d'afficher les emoji utilisés comme icônes ailleurs dans le code (voir
-- src/data/*.lua, champ `icon`). love.filesystem est un système de fichiers
-- virtuel qui ne voit par défaut que le dossier du jeu : on doit "monter"
-- (love.filesystem.mount) le dossier des polices Windows avant de pouvoir y
-- charger une police, en pcall — si ça échoue (hors Windows, police absente,
-- version de LÖVE qui ne sait pas rasteriser une police couleur), on renvoie
-- nil et l'appelant retombe sur le texte (`label`). Jamais de crash.

local BODY_FONT_PATH = "assets/fonts/m5x7.ttf"
local BODY_FONT_NATIVE_SIZE = 16

-- m3x6 (même auteur, ajoutée le 2026-08-10 dans l'idée de couvrir le texte compact
-- sous 16px) mesure à l'identique : unitsPerEm 1024, même grille 64 unités/pixel,
-- mêmes métriques hhea (ascender 682, descender -128, lineGap 92) que m5x7 -- donc
-- LA MÊME taille native 16 et LA MÊME hauteur de ligne, contrairement à l'hypothèse
-- de départ. Son seul vrai gain : des glyphes plus étroits à cette même taille
-- (chiffre "0" en 3px de large contre 5px pour m5x7, d'où son nom "m3x6") -- utile
-- pour des colonnes serrées en largeur, pas pour un texte plus bas en hauteur.
local COMPACT_FONT_PATH = "assets/fonts/m3x6.ttf"

local Fonts = { cache = {}, compact_cache = {}, icon_cache = {}, icon_path_tried = false, icon_path = nil }

local function snapped_font(path, size)
  local snapped = math.ceil(size / BODY_FONT_NATIVE_SIZE) * BODY_FONT_NATIVE_SIZE
  local ok, loaded = pcall(love.graphics.newFont, path, snapped, "none")
  local f = ok and loaded or love.graphics.newFont(size)
  f:setFilter("nearest", "nearest")
  return f
end

function Fonts.get(size)
  local f = Fonts.cache[size]
  if not f then
    if size >= BODY_FONT_NATIVE_SIZE then
      f = snapped_font(BODY_FONT_PATH, size)
    else
      f = love.graphics.newFont(size)
      f:setFilter("nearest", "nearest")
    end
    Fonts.cache[size] = f
  end
  return f
end

--- Variante étroite de Fonts.get (police m3x6) -- même seuil de netteté (16) que
-- Fonts.get, mais glyphes plus compacts en largeur. À utiliser sur les colonnes
-- serrées (badges, coûts) plutôt que du texte bas en hauteur, qui n'en tire rien.
function Fonts.compact(size)
  local f = Fonts.compact_cache[size]
  if not f then
    f = (size >= BODY_FONT_NATIVE_SIZE) and snapped_font(COMPACT_FONT_PATH, size) or love.graphics.newFont(size)
    if size < BODY_FONT_NATIVE_SIZE then f:setFilter("nearest", "nearest") end
    Fonts.compact_cache[size] = f
  end
  return f
end

local ICON_FONT_MOUNT = "sysfonts"
local ICON_FONT_CANDIDATES = {
  ICON_FONT_MOUNT .. "/seguiemj.ttf", -- Segoe UI Emoji (couleur, Windows 10/11)
  ICON_FONT_MOUNT .. "/seguisym.ttf", -- Segoe UI Symbol (monochrome, repli)
}

--- Renvoie le chemin virtuel (après montage) de la première police-icône
-- utilisable, ou nil. Ne teste qu'une fois par lancement.
local function resolve_icon_path()
  if Fonts.icon_path_tried then return Fonts.icon_path end
  Fonts.icon_path_tried = true

  if love.system.getOS() == "Windows" then
    pcall(love.filesystem.mount, "C:/Windows/Fonts", ICON_FONT_MOUNT)
  end

  for _, path in ipairs(ICON_FONT_CANDIDATES) do
    local ok = pcall(function() return love.graphics.newFont(path, 12) end)
    if ok then
      Fonts.icon_path = path
      return path
    end
  end
  return nil
end

--- Police pour dessiner des icônes emoji à la taille donnée, ou nil si aucune
-- police-icône n'a pu être chargée (l'appelant doit alors utiliser `label`).
function Fonts.icon(size)
  local cached = Fonts.icon_cache[size]
  if cached ~= nil then
    if cached == false then return nil end
    return cached
  end
  local path = resolve_icon_path()
  if not path then
    Fonts.icon_cache[size] = false
    return nil
  end
  local ok, f = pcall(love.graphics.newFont, path, size)
  if ok then
    Fonts.icon_cache[size] = f
    return f
  end
  Fonts.icon_cache[size] = false
  return nil
end

return Fonts
