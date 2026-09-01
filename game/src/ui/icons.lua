-- Icônes vectorielles dessinées à la main (love.graphics, aucun fichier externe).
-- Alternative aux emoji : LÖVE ne rasterise pas correctement les polices emoji
-- couleur (voir src/ui/fonts.lua) et la police par défaut n'a pas ces glyphes
-- du tout. Ce sont des silhouettes simples, pas de l'art final — un repère
-- visuel en attendant de vraies illustrations (voir README du dossier game/).

local Sprites = require("src.ui.sprites")
-- Theme (2026-08-27) : uniquement pour draw_status_bonus/malus ci-dessous,
-- dont la couleur est fixe (vert/rouge, porte le sens du symbole) plutôt que
-- choisie par l'appelant comme les autres icônes de ce module.
local Theme = require("src.ui.theme")

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

--- Bouclier : silhouette à 5 points (plat en haut, pointe en bas). `alpha`
-- (optionnel, 2026-08-27, demande explicite -- le VFX de gain de Défense doit
-- réutiliser cette MÊME icône plutôt qu'une silhouette dupliquée, voir
-- draw_shield_fx dans view.lua) : sans ça, le fondu entrant/sortant du VFX
-- serait impossible (alpha figé à 1 sinon) -- multiplie aussi le liseré blanc
-- de reflet, pour qu'il s'estompe avec le reste plutôt que de rester fixe.
local function draw_shield(cx, cy, r, color, alpha)
  set(color, alpha)
  local hw, hh = r * 0.65, r * 0.85
  love.graphics.polygon("fill",
    cx - hw, cy - hh,
    cx + hw, cy - hh,
    cx + hw, cy - hh * 0.15,
    cx, cy + hh,
    cx - hw, cy - hh * 0.15
  )
  set({ 1, 1, 1 }, 0.18 * (alpha or 1))
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

--- Crâne (Nécromancien, 2026-08-29 -- écran de choix d'équipe) : même
-- silhouette que draw_skull plus bas dans ce fichier (bestiaire, ennemi
-- "squelette"), dupliquée ICI volontairement plutôt que réordonner le
-- fichier pour une seule référence -- DRAW_BY_CLASS doit rester déclarée
-- avant la section bestiaire, pas l'inverse. Bug corrigé au passage
-- (2026-08-29) : sans entrée ici, Icons.draw_class renvoyait false et le
-- repli texte (icon_text, view.lua) essayait d'afficher le label ("NEC")
-- avec `size` (un rayon de portrait, ~58px) traité comme une TAILLE DE
-- POLICE -- chaque lettre finissait alors sur sa propre ligne, géante.
local function draw_class_skull(cx, cy, r, color)
  set(color)
  love.graphics.circle("fill", cx, cy - r * 0.1, r * 0.6)
  love.graphics.rectangle("fill", cx - r * 0.35, cy + r * 0.25, r * 0.7, r * 0.3, r * 0.08)
  set({ 0, 0, 0 }, 0.55)
  love.graphics.circle("fill", cx - r * 0.22, cy - r * 0.12, r * 0.13)
  love.graphics.circle("fill", cx + r * 0.22, cy - r * 0.12, r * 0.13)
end

--- Note de musique (Barde, 2026-08-29) : tête ovale + hampe + crochet --
-- même correctif que ci-dessus (sans elle, même bug de repli texte géant).
local function draw_class_note(cx, cy, r, color)
  set(color)
  love.graphics.ellipse("fill", cx - r * 0.15, cy + r * 0.55, r * 0.34, r * 0.24)
  love.graphics.setLineWidth(math.max(1, r * 0.14))
  love.graphics.line(cx + r * 0.18, cy + r * 0.55, cx + r * 0.18, cy - r * 0.75)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("fill", cx + r * 0.18, cy - r * 0.75, cx + r * 0.58, cy - r * 0.4, cx + r * 0.18, cy - r * 0.1)
end

local DRAW_BY_CLASS = {
  guerrier = draw_sword,
  paladin = draw_shield,
  mage = draw_orb,
  assassin = draw_dagger,
  necromancien = draw_class_skull,
  barde = draw_class_note,
  generic = draw_generic,
}

--- Dessine l'icône de classe centrée en (cx, cy) avec un rayon approximatif r.
-- Retourne false si class_id n'est pas reconnu (rien dessiné, l'appelant
-- garde son repli texte).
-- `alpha` (optionnel, 2026-08-30, Temple -- fondu des aventuriers non
-- choisis, voir draw_temple) : par défaut 1 -- sans lui, un portrait réel
-- (les 6 héros en ont désormais un, voir game/assets/characters/heroes/)
-- s'affichait TOUJOURS en pleine opacité quel que soit le fondu demandé par
-- l'appelant, puisque cette branche fixait la couleur en dur avant de
-- dessiner le sprite.
function Icons.draw_class(class_id, cx, cy, r, color, alpha)
  if r >= SPRITE_MIN_RADIUS then
    local img = Sprites.hero(class_id)
    if img then
      love.graphics.setColor(1, 1, 1, alpha or 1)
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

--- Aigle Géant AU SOL, ailes repliées (2026-08-30, second boss -- "il
-- possède 2 images : 1 à terre, et 1 en vol") : corps ovale compact + tête +
-- bec + ailes plaquées le long du corps -- volontairement TRÈS différente de
-- draw_eagle_flying juste en dessous (silhouette large, ailes déployées),
-- pour que le changement d'état (e.vol, voir enemies.lua/game.lua) se voie
-- d'un coup d'œil, pas seulement via le badge "Vol" (voir draw_status_vol
-- plus bas).
local function draw_eagle(cx, cy, r, color)
  set(color)
  love.graphics.ellipse("fill", cx, cy + r * 0.15, r * 0.5, r * 0.7)
  love.graphics.circle("fill", cx, cy - r * 0.6, r * 0.3)
  love.graphics.polygon("fill", cx + r * 0.26, cy - r * 0.65, cx + r * 0.68, cy - r * 0.55, cx + r * 0.26, cy - r * 0.45)
  love.graphics.polygon("fill", cx - r * 0.45, cy - r * 0.05, cx - r * 0.85, cy + r * 0.3, cx - r * 0.3, cy + r * 0.5)
  love.graphics.polygon("fill", cx + r * 0.45, cy - r * 0.05, cx + r * 0.85, cy + r * 0.3, cx + r * 0.3, cy + r * 0.5)
end

--- Aigle Géant EN VOL, ailes déployées (2026-08-30) : silhouette large en
-- rapace vu de face, tête + bec + grandes ailes en éventail de chaque côté --
-- voir draw_eagle ci-dessus pour le contraste recherché.
local function draw_eagle_flying(cx, cy, r, color)
  set(color)
  love.graphics.circle("fill", cx, cy - r * 0.15, r * 0.28)
  love.graphics.polygon("fill", cx + r * 0.2, cy - r * 0.2, cx + r * 0.55, cy - r * 0.3, cx + r * 0.2, cy - r * 0.08)
  love.graphics.polygon("fill",
    cx, cy - r * 0.15,
    cx - r * 0.95, cy - r * 0.55,
    cx - r * 0.55, cy + r * 0.05,
    cx - r * 0.15, cy - r * 0.1,
    cx, cy + r * 0.75,
    cx + r * 0.15, cy - r * 0.1,
    cx + r * 0.55, cy + r * 0.05,
    cx + r * 0.95, cy - r * 0.55)
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
  aigle = draw_eagle,
  ["aigle-vol"] = draw_eagle_flying,
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

local function draw_status_defense(cx, cy, r, color, alpha) draw_shield(cx, cy, r, color, alpha) end

-- `alpha` (optionnel, 2026-08-28, demande explicite -- effet de rémanence sur
-- l'arrivée de tout badge de statut, voir status_badge dans view.lua) : sans
-- ça, l'écho fantôme dessiné par-dessus/derrière l'icône réelle serait
-- toujours à alpha 1 (set(color) l'écraserait), rendant le fondu impossible --
-- même raison d'être que sur draw_shield ci-dessus, étendue à TOUTES les
-- icônes de statut vectorielles de ce fichier.
local function draw_status_esquive(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.setLineWidth(math.max(1, r * 0.16))
  love.graphics.line(cx - r * 0.6, cy - r * 0.25, cx + r * 0.15, cy - r * 0.25)
  love.graphics.line(cx - r * 0.6, cy + r * 0.25, cx + r * 0.15, cy + r * 0.25)
  love.graphics.polygon("fill", cx + r * 0.15, cy - r * 0.5, cx + r * 0.65, cy, cx + r * 0.15, cy + r * 0.5)
  love.graphics.setLineWidth(1)
end

local function draw_status_camouflage(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.ellipse("line", cx, cy, r * 0.7, r * 0.4)
  love.graphics.circle("fill", cx, cy, r * 0.18)
  love.graphics.setLineWidth(math.max(1, r * 0.14))
  love.graphics.line(cx - r * 0.75, cy - r * 0.55, cx + r * 0.75, cy + r * 0.55)
  love.graphics.setLineWidth(1)
end

local function draw_status_puissance(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill", cx, cy - r * 0.75, cx - r * 0.55, cy + r * 0.35, cx + r * 0.55, cy + r * 0.35)
end

local function draw_status_saignements(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill", cx, cy - r * 0.75, cx - r * 0.45, cy + r * 0.2, cx, cy + r * 0.55, cx + r * 0.45, cy + r * 0.2)
end

local function draw_status_incapacite(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill", cx, cy + r * 0.75, cx - r * 0.55, cy - r * 0.35, cx + r * 0.55, cy - r * 0.35)
end

local function draw_status_vulnerabilite(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.setLineWidth(math.max(1, r * 0.12))
  love.graphics.circle("line", cx, cy, r * 0.7)
  love.graphics.circle("line", cx, cy, r * 0.32)
  love.graphics.line(cx, cy - r * 0.85, cx, cy + r * 0.85)
  love.graphics.line(cx - r * 0.85, cy, cx + r * 0.85, cy)
  love.graphics.setLineWidth(1)
end

--- Flamme simple (2026-08-24, sensibilité au feu de l'Homme Arbre) : repli
-- vectoriel si Sprites.status("fireweak") (icônes/keywords/fireball.png) est
-- absent, même principe que les autres statuts ci-dessus.
local function draw_status_fireweak(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill",
    cx, cy - r * 0.85,
    cx + r * 0.5, cy + r * 0.1,
    cx + r * 0.15, cy - r * 0.05,
    cx + r * 0.3, cy + r * 0.55,
    cx, cy + r * 0.8,
    cx - r * 0.3, cy + r * 0.55,
    cx - r * 0.15, cy - r * 0.05,
    cx - r * 0.5, cy + r * 0.1)
end

-- "Brûlure" (2026-09-01, nouveau statut, Volcan) : même silhouette de flamme
-- que draw_status_fireweak juste au-dessus -- concept visuel déjà établi pour
-- "feu" dans ce fichier, pas besoin d'en inventer un second.
local function draw_status_brulure(cx, cy, r, color, alpha)
  draw_status_fireweak(cx, cy, r, color, alpha)
end

--- Sablier simple (2026-08-28, demande explicite -- "icone dédiée" pour le
-- bouclier programmé d'Infranchissable, voir hero.scheduled_shields dans
-- game.lua) : 2 triangles opposés, symbole générique "à venir/en attente" --
-- distinct du bouclier plein (draw_shield) déjà utilisé pour la Défense
-- ACTIVE, pour ne jamais confondre "j'ai du bouclier maintenant" et "j'en
-- aurai bientôt".
local function draw_status_scheduled_shield(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill", cx - r * 0.55, cy - r * 0.75, cx + r * 0.55, cy - r * 0.75, cx, cy)
  love.graphics.polygon("fill", cx - r * 0.55, cy + r * 0.75, cx + r * 0.55, cy + r * 0.75, cx, cy)
end

--- Flèche vers le haut, légèrement inclinée -- jamais parfaitement verticale
-- (2026-08-27, demande explicite -- remplace un "+" jugé peu lisible) :
-- télégraphe ennemi d'un soin à soi/un allié ou d'une résurrection, "une
-- flèche verte vers le haut" -- volontairement neutre, ne représente aucune
-- mécanique précise (contrairement à Puissance ci-dessus, un triangle) --
-- juste "quelque chose de positif va se passer", le détail restant dans
-- l'infobulle (voir enemy_telegraph_parts dans view.lua). Couleur FIXE
-- (Theme.heal, vert) plutôt que le paramètre `color` de l'appelant -- ici la
-- couleur porte le sens du symbole, pas un choix laissé à l'appelant.
local function draw_status_bonus(cx, cy, r)
  set(Theme.heal)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(math.rad(-18))
  love.graphics.setLineWidth(math.max(1, r * 0.22))
  love.graphics.line(0, r * 0.8, 0, -r * 0.5)
  love.graphics.polygon("fill", 0, -r * 0.9, -r * 0.4, -r * 0.25, r * 0.4, -r * 0.25)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

--- Flèche vers le bas, même principe que draw_status_bonus juste au-dessus
-- mais pour un malus (2026-08-27, demande explicite -- ex. Malédiction du
-- Nécromancien) : rouge (Theme.hp), inclinée dans l'autre sens (pas un simple
-- miroir vertical de l'icône bonus). Distincte des icônes de statut précises
-- déjà existantes (Vulnérabilité, Incapacité...), qui restent utilisées
-- ailleurs (badges de statuts ACTIFS sur une unité) -- seul le télégraphe
-- d'une attaque À VENIR les remplace par ce symbole générique.
local function draw_status_malus(cx, cy, r)
  set(Theme.hp)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(math.rad(18))
  love.graphics.setLineWidth(math.max(1, r * 0.22))
  love.graphics.line(0, -r * 0.8, 0, r * 0.5)
  love.graphics.polygon("fill", 0, r * 0.9, -r * 0.4, r * 0.25, r * 0.4, r * 0.25)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

--- Point d'exclamation simple (2026-08-28, statut Provocation du Paladin) :
-- barre + point, symbole générique d'alerte/menace -- distinct du motif
-- cercle+croix de Vulnérabilité juste au-dessus, pas de confusion possible.
local function draw_status_provocation(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.setLineWidth(math.max(1, r * 0.28))
  love.graphics.line(cx, cy - r * 0.75, cx, cy + r * 0.15)
  love.graphics.setLineWidth(1)
  love.graphics.circle("fill", cx, cy + r * 0.55, r * 0.14)
end

--- Silhouette de statue "bénie" (2026-08-29, demande explicite -- "une icone
-- de statue de la bonne couleur, 1 pour les bénédictions, l'autre pour les
-- malédictions") : tête/halo rond + robe évasée, silhouette douce -- même
-- forme pour LES 8 bénédictions, seule la couleur change (voir
-- TEMPLE_STATUE_COLORS dans view.lua, appliquée par l'appelant via `color`).
local function draw_status_temple_blessing(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.circle("fill", cx, cy - r * 0.55, r * 0.28)
  love.graphics.polygon("fill",
    cx - r * 0.5, cy + r * 0.75, cx - r * 0.32, cy - r * 0.05,
    cx + r * 0.32, cy - r * 0.05, cx + r * 0.5, cy + r * 0.75)
end

--- Silhouette de statue "maudite" (2026-08-29, corrigée 2026-08-30 -- bug
-- signalé : l'ancienne silhouette avait sa seule pointe EN HAUT, ce qui se
-- lisait comme une flèche vers le haut malgré les "cornes" -- donnait une
-- impression positive alors que c'est une malédiction). Couronne d'épines à
-- 3 pointes en haut, resserrée vers UNE SEULE pointe en bas -- silhouette
-- qui "tombe"/"transperce vers le bas", sans ambiguïté avec un symbole
-- positif, distincte au premier coup d'œil du dôme arrondi de la bénédiction
-- même en silhouette pure, sans dépendre de la couleur.
local function draw_status_temple_curse(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill",
    cx - r * 0.55, cy - r * 0.75, cx - r * 0.2, cy - r * 0.4, cx, cy - r * 0.7,
    cx + r * 0.2, cy - r * 0.4, cx + r * 0.55, cy - r * 0.75,
    cx + r * 0.35, cy + r * 0.15, cx, cy + r * 0.85, cx - r * 0.35, cy + r * 0.15)
end

--- Étincelle d'Inspiration (Barde, 2026-08-29) : losange à 4 pointes (2 axes
-- perpendiculaires, l'un plus large que l'autre) -- distinct de la
-- Puissance (triangle plein) et de Provocation (point d'exclamation).
local function draw_status_inspiration(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill",
    cx, cy - r * 0.85, cx + r * 0.22, cy - r * 0.22, cx + r * 0.85, cy, cx + r * 0.22, cy + r * 0.22,
    cx, cy + r * 0.85, cx - r * 0.22, cy + r * 0.22, cx - r * 0.85, cy, cx - r * 0.22, cy - r * 0.22)
end

--- "Encore" (carte "Bis" du Barde, 2026-08-29) : arc + flèche, symbole
-- générique de répétition -- suggestion d'origine 🔁, voir glossary.lua.
local function draw_status_encore(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.setLineWidth(math.max(1, r * 0.18))
  love.graphics.arc("line", "open", cx, cy, r * 0.6, math.rad(30), math.rad(300))
  love.graphics.setLineWidth(1)
  local ax, ay = cx + r * 0.6 * math.cos(math.rad(300)), cy + r * 0.6 * math.sin(math.rad(300))
  love.graphics.polygon("fill", ax, ay, ax - r * 0.28, ay - r * 0.05, ax - r * 0.05, ay + r * 0.28)
end

--- Ailes déployées (2026-08-30, statut "Vol" de l'Aigle Géant -- voir
-- Combat.damage_multiplier) : chevron élargi façon ailes + corps, distinct de
-- toutes les autres silhouettes de statut ci-dessus (aucune n'évoque le vol).
local function draw_status_vol(cx, cy, r, color, alpha)
  set(color, alpha)
  love.graphics.polygon("fill",
    cx, cy - r * 0.15,
    cx - r * 0.9, cy - r * 0.7,
    cx - r * 0.5, cy - r * 0.05,
    cx - r * 0.15, cy - r * 0.15,
    cx, cy + r * 0.75,
    cx + r * 0.15, cy - r * 0.15,
    cx + r * 0.5, cy - r * 0.05,
    cx + r * 0.9, cy - r * 0.7)
end

local DRAW_BY_STATUS = {
  defense = draw_status_defense,
  esquive = draw_status_esquive,
  camoufle = draw_status_camouflage,
  puissance = draw_status_puissance,
  saignements = draw_status_saignements,
  incapacite = draw_status_incapacite,
  vulnerabilite = draw_status_vulnerabilite,
  provocation = draw_status_provocation,
  shield_pending = draw_status_scheduled_shield,
  temple_blessing = draw_status_temple_blessing,
  temple_curse = draw_status_temple_curse,
  fireweak = draw_status_fireweak,
  brulure = draw_status_brulure,
  bonus = draw_status_bonus,
  malus = draw_status_malus,
  inspiration = draw_status_inspiration,
  encore = draw_status_encore,
  vol = draw_status_vol,
}

--- Dessine l'icône d'un statut (clé Lua, ex. "defense", "esquive"...) centrée
-- en (cx, cy). Retourne false si non reconnu. `alpha` (optionnel, 2026-08-27,
-- voir draw_shield ci-dessus) : forwardé aux deux chemins (sprite réel ET
-- repli vectoriel) pour que les appelants qui ont besoin d'un fondu (ex.
-- draw_shield_fx dans view.lua) n'aient pas à se soucier de savoir laquelle
-- des deux voies "defense" emprunte réellement.
function Icons.draw_status(status_key, cx, cy, r, color, alpha)
  local img = Sprites.status(status_key)
  if img then
    love.graphics.setColor(1, 1, 1, alpha or 1)
    Sprites.draw_centered(img, cx, cy, r)
    return true
  end
  local fn = DRAW_BY_STATUS[status_key]
  if not fn then return false end
  fn(cx, cy, r, color, alpha)
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

return Icons
