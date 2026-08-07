-- Petit cache de polices LÖVE par taille, pour éviter de recréer des Font
-- objects à chaque frame (coûteux) tout en gardant plusieurs tailles de texte.
--
-- Fonts.icon(size) tente en plus de charger une police système capable
-- d'afficher les emoji utilisés comme icônes ailleurs dans le code (voir
-- src/data/*.lua, champ `icon`). love.filesystem est un système de fichiers
-- virtuel qui ne voit par défaut que le dossier du jeu : on doit "monter"
-- (love.filesystem.mount) le dossier des polices Windows avant de pouvoir y
-- charger une police, en pcall — si ça échoue (hors Windows, police absente,
-- version de LÖVE qui ne sait pas rasteriser une police couleur), on renvoie
-- nil et l'appelant retombe sur le texte (`label`). Jamais de crash.

local Fonts = { cache = {}, icon_cache = {}, icon_path_tried = false, icon_path = nil }

function Fonts.get(size)
  local f = Fonts.cache[size]
  if not f then
    f = love.graphics.newFont(size)
    Fonts.cache[size] = f
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
