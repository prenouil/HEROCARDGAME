-- Rendu "texte + icônes inline" pour le corps des cartes (ex. "Inflige 4 [icône
-- épée] à tous les ennemis"). LÖVE n'a pas de moteur de texte riche natif
-- (love.graphics.printf ne sait pas mélanger glyphes et images) : on retokenise
-- le texte brut de la carte (mots-clés encore entre guillemets, avant
-- Glossary.render_card_text) en une suite de mots/icônes, on les regroupe en
-- lignes par largeur disponible (comme un word-wrap classique, l'icône comptant
-- comme un mot de la hauteur d'une ligne), puis on dessine chaque ligne centrée
-- pour rester cohérent avec le reste de l'UI carte (voir text() dans view.lua).

local Fonts = require("src.ui.fonts")
local Glossary = require("src.data.glossary")
local Sprites = require("src.ui.sprites")

local RichText = {}

local function tokenize(raw_text)
  local atoms = {}
  local pos, len = 1, #raw_text
  while pos <= len do
    local qstart, qend, inner = raw_text:find('"([^"]+)"', pos)
    local before = qstart and raw_text:sub(pos, qstart - 1) or raw_text:sub(pos)
    for word in before:gmatch("%S+") do
      atoms[#atoms + 1] = { kind = "text", value = word }
    end
    if not qstart then break end
    local g = Glossary.find_term(inner)
    local atom
    if g and g.has_icon then
      atom = { kind = "icon", key = g.key }
    else
      atom = { kind = "text", value = (g and (g.label or g.key)) or inner }
    end
    pos = qend + 1
    -- Ponctuation collée juste après le mot-clé (ex. epee".) : rattachée à l'atome
    -- comme suffixe, sans espace avant, plutôt que de devenir un "mot" isolé.
    local punct = raw_text:sub(pos, pos)
    if punct:match("^%p$") then
      atom.suffix = punct
      pos = pos + 1
    end
    atoms[#atoms + 1] = atom
  end
  return atoms
end

--- Dessine `raw_text` (texte de carte AVANT render_card_text, mots-clés encore
-- entre guillemets) dans la zone (x, y, w), icônes de mots-clés inline, lignes
-- centrées. Retourne la hauteur totale dessinée (pour empiler d'autres éléments
-- derrière si besoin).
function RichText.draw(raw_text, x, y, w, size, color)
  local font = Fonts.get(size)
  love.graphics.setFont(font)
  local space_w = font:getWidth(" ")
  local line_h = font:getHeight() * 1.15
  local icon_w = font:getHeight()

  local function icon_visual_width(atom)
    local entry = Sprites.keyword(atom.key)
    if not entry then return font:getWidth(atom.key) end
    local vw = Sprites.visual_size(entry, icon_w)
    return vw
  end

  local function atom_width(atom)
    local base = atom.kind == "icon" and icon_visual_width(atom) or font:getWidth(atom.value)
    return base + (atom.suffix and font:getWidth(atom.suffix) or 0)
  end

  local atoms = tokenize(raw_text)
  local lines, current, current_w = {}, {}, 0
  for _, atom in ipairs(atoms) do
    local aw = atom_width(atom)
    local needed = (#current == 0) and aw or (current_w + space_w + aw)
    if needed > w and #current > 0 then
      lines[#lines + 1] = current
      current, current_w = { atom }, aw
    else
      current[#current + 1] = atom
      current_w = needed
    end
  end
  if #current > 0 then lines[#lines + 1] = current end

  local cr, cg, cb = color[1], color[2], color[3]
  local ly = y
  for _, line in ipairs(lines) do
    local line_w = 0
    for i, atom in ipairs(line) do
      line_w = line_w + atom_width(atom) + (i > 1 and space_w or 0)
    end
    local lx = x + (w - line_w) / 2
    for _, atom in ipairs(line) do
      local aw = atom_width(atom)
      local suffix_w = atom.suffix and font:getWidth(atom.suffix) or 0
      local content_w = aw - suffix_w
      local icon_img = atom.kind == "icon" and Sprites.keyword(atom.key)
      if icon_img then
        love.graphics.setColor(1, 1, 1, 1)
        Sprites.draw_centered(icon_img, lx + content_w / 2, ly + line_h / 2, icon_w / 2)
      else
        love.graphics.setColor(cr, cg, cb, 1)
        love.graphics.print(atom.kind == "icon" and atom.key or atom.value, lx, ly)
      end
      if atom.suffix then
        love.graphics.setColor(cr, cg, cb, 1)
        love.graphics.print(atom.suffix, lx + content_w, ly)
      end
      lx = lx + aw + space_w
    end
    ly = ly + line_h
  end
  love.graphics.setColor(1, 1, 1, 1)
  return ly - y
end

return RichText
