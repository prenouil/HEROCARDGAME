-- Palette reprise des custom properties CSS du prototype (proto-cartes-completes),
-- convertie en RGB 0..1 pour love.graphics.setColor.

local function hex(h)
  h = h:gsub("#", "")
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local Theme = {
  bg = hex("1b1420"),
  panel = hex("2a1f33"),
  panel_light = hex("3a2a48"),
  accent = hex("e8b93f"),
  hp = hex("d9455f"),
  heal = hex("4caf7d"),
  energy = hex("3fb6e8"),
  -- Ressource propre au Mage (2026-08-20) : même teinte que le liseré de ses
  -- cartes (Theme.card_class.mage.border) pour que "mana" se lise comme SON
  -- indigo, jamais confondu avec Theme.energy (la réserve globale, cyan,
  -- partagée par tout le groupe).
  mana = hex("8a7bd8"),
  -- Ressource propre à l'Assassin (2026-08-24) : même principe que Theme.mana
  -- -- teinte reprise du liseré de ses cartes (Theme.card_class.assassin.border).
  discretion = hex("5cae6e"),
  text = hex("f1e9f7"),
  muted = hex("a996b3"),
  def = hex("7f9ccf"),
  status = hex("c47fe8"),
  black = { 0, 0, 0 },
  white = { 1, 1, 1 },
}

function Theme.with_alpha(c, a)
  return { c[1], c[2], c[3], a }
end

-- Identité visuelle des cartes par classe (2026-08-10, demande explicite -- rendre
-- les cartes "plus attractives") : mêmes familles de teintes que les portraits de
-- héros déjà verrouillés (acier/rouge Guerrier, or/blanc/bleu Paladin, indigo Mage,
-- vert sombre Assassin), pour qu'une carte se reconnaisse par sa couleur avant même
-- de lire son nom. `bg` teinte le fond du panneau, `border` est le liseré intérieur
-- clair du double contour (voir draw_hand dans view.lua) -- jamais `Theme.accent`
-- (l'or reste réservé au signal "carte sélectionnée", pour ne jamais confondre les
-- deux). "generic" gardé comme repli défensif (aucune carte n'a plus ce class_id
-- depuis 2026-08-11, mais Theme.card_class[def.class_id] or Theme.card_class.generic
-- reste utilisé ailleurs en filet de sécurité).
Theme.card_class = {
  generic  = { bg = hex("3a2a48"), border = hex("6a5a78") },
  guerrier = { bg = hex("3a2424"), border = hex("c26a52") },
  paladin  = { bg = hex("22283a"), border = hex("6fa8dc") },
  mage     = { bg = hex("241f3a"), border = hex("8a7bd8") },
  assassin = { bg = hex("1c2a20"), border = hex("5cae6e") },
}


return Theme
