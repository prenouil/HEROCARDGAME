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
  -- "Traînée" de PV tout juste perdus (2026-08-30, demande explicite --
  -- barre de vie "à 2 niveaux" : le rouge chute d'un coup, un jaune se vide
  -- ensuite lentement pour le rattraper, voir hp_bar/Controller.hp_trail
  -- dans view.lua/controller.lua) -- jaune franc, distinct de Theme.accent
  -- (or, réservé à "sélectionné"/"choisi") et de Theme.energy (cyan).
  hp_trail = hex("e8c93f"),
  heal = hex("4caf7d"),
  energy = hex("3fb6e8"),
  -- Ressource propre au Mage (2026-08-20) : même teinte que le liseré de ses
  -- cartes (Theme.card_class.mage.border) pour que "mana" se lise comme SON
  -- indigo, jamais confondu avec Theme.energy (la réserve globale, cyan,
  -- partagée par tout le groupe).
  mana = hex("8a7bd8"),
  -- "PO" (or, 2026-09-02) : ressource persistante d'équipe, jamais
  -- Theme.accent (déjà réservé au signal "sélectionné/choisi", voir son
  -- commentaire plus haut -- "jamais confondu") -- ambre plus chaud/orangé,
  -- même famille "or" mais visuellement distinct au premier coup d'œil.
  gold = hex("e0932e"),
  -- Ressource propre à l'Assassin (2026-08-24) : même principe que Theme.mana
  -- -- teinte reprise du liseré de ses cartes (Theme.card_class.assassin.border).
  discretion = hex("5cae6e"),
  -- Ressource propre au Nécromancien (2026-08-29) : même principe que
  -- Theme.mana/Theme.discretion -- teinte reprise du liseré de ses cartes
  -- (Theme.card_class.necromancien.border, vert maladif -- décomposition).
  corruption = hex("8fae6a"),
  -- Cendres d'une carte "Amnésie" qui se disperse (2026-08-28) : gris chaud
  -- neutre, jamais utilisé ailleurs (Theme.muted est un lavande éteint, pas un
  -- vrai gris) -- doit se lire comme "matière consumée", pas comme un statut.
  ash = hex("8a8378"),
  text = hex("f1e9f7"),
  muted = hex("a996b3"),
  def = hex("7f9ccf"),
  status = hex("c47fe8"),
  black = { 0, 0, 0 },
  white = { 1, 1, 1 },
  -- Type de carte (2026-09-03, demande explicite -- cellule "Offensive"/
  -- "Support" sur chaque carte) : rouge/bleu francs, jamais Theme.hp (déjà
  -- réservé aux PV perdus) ni Theme.card_class.paladin.border (bleu proche
  -- mais réservé à l'identité visuelle de classe) -- ces 2 teintes doivent se
  -- reconnaître sur N'IMPORTE quelle carte, indépendamment de sa classe.
  offensive = hex("c23b3b"),
  support = hex("3b7ec2"),
  -- Enchantement (2026-09-03, 3ᵉ type de carte -- ne cible personne, pose un
  -- pouvoir passif) : violet, distinct du rouge/bleu ci-dessus ET de
  -- Theme.mana (indigo, réservé à la ressource du Mage) -- 3ᵉ teinte
  -- primaire facilement reconnaissable au premier coup d'œil.
  enchantment = hex("8e44ad"),
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
  -- Nécromancien/Barde (2026-08-29, sélectionnables à l'écran de choix
  -- d'équipe -- voir heroes.lua) : vert maladif/décomposition pour l'un,
  -- ambre chaleureux/musical pour l'autre -- distincts de l'or de
  -- Theme.accent (réservé au signal "carte sélectionnée") malgré la parenté
  -- de teinte avec le Barde.
  necromancien = { bg = hex("1e2418"), border = hex("8fae6a") },
  barde = { bg = hex("332012"), border = hex("e0955c") },
}


return Theme
