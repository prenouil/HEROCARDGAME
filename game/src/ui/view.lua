-- Rendu et calcul de rectangles (layout + hit-testing partagent les mêmes
-- fonctions, pour ne jamais dessiner un bouton ailleurs qu'où on le clique).
-- Port "spirituel" (pas pixel pour pixel) de l'arène HTML/CSS du prototype :
-- même structure d'écran, rendu simplifié en rectangles/texte — les VFX/
-- animations détaillées sont un chantier volontairement différé (voir party
-- du 2026-08-06 : moteur d'abord, feedback visuel ensuite).

local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Fonts = require("src.ui.fonts")
local Icons = require("src.ui.icons")
local Sprites = require("src.ui.sprites")
local RichText = require("src.ui.richtext")
local Glossary = require("src.data.glossary")
local SCALE = require("src.ui.layout_scale")
local Enemies = require("src.data.enemies")
local Heroes = require("src.data.heroes")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")
local Temple = require("src.rules.temple")
local Game = require("src.rules.game")
local Deck = require("src.rules.deck")

local View = {}

-- Couleurs des statues du Temple (2026-08-29, demande explicite -- une par
-- effet, voir Temple.effects dans temple.lua) : purement décoratives,
-- utilisées à la fois par les badges sur le cadre des héros (draw_hero) et
-- par l'écran du Temple lui-même (draw_temple) -- une seule table partagée,
-- jamais 2 palettes qui pourraient diverger.
local TEMPLE_STATUE_COLORS = {
  vert = { 0.35, 0.72, 0.42 }, bleu = { 0.35, 0.55, 0.85 }, rouge = { 0.82, 0.32, 0.32 },
  blanc = { 0.92, 0.92, 0.92 }, violet = { 0.62, 0.42, 0.82 }, noir = { 0.38, 0.35, 0.42 },
  orange = { 0.88, 0.58, 0.24 }, gris = { 0.62, 0.62, 0.65 },
}

local function combats_won_text(controller)
  return tostring(math.max(0, controller.state.run.combat_index - 1))
end

-- H réduit de 700 à 660 (2026-08-24, demande explicite -- fenêtre trop haute,
-- ~60px inutilisés sous le dernier élément réel, hint_text à y=632) : garder
-- IMPÉRATIVEMENT ce chiffre synchronisé avec `t.window.height = 660 * SCALE`
-- dans conf.lua -- ce module ne peut pas lire cette constante-ci (conf.lua
-- s'exécute avant le chargement du reste), d'où la duplication manuelle,
-- même schéma que SCALE (voir layout_scale.lua) partagé entre les deux.
local W, H = 960, 660
View.W, View.H = W, H

-- +12 (2026-08-27, demande explicite -- portraits plus gros partout, voir
-- HERO_PORTRAIT_SIZE plus bas) : la carte grandit un peu pour absorber le
-- portrait agrandi sans tasser le reste (badges, nom en bas côté héros).
local UNIT_W, UNIT_H = 150, 168
local CARD_W, CARD_H = 92, 138
local ROW_GAP = 12

-- ---------- rects ----------

local function centered_row(count, item_w, item_h, y, gap)
  gap = gap or ROW_GAP
  local total = count * item_w + math.max(0, count - 1) * gap
  local x0 = (W - total) / 2
  local rects = {}
  for i = 1, count do
    rects[i] = { x = x0 + (i - 1) * (item_w + gap), y = y, w = item_w, h = item_h }
  end
  return rects
end

function View.enemy_rects(state)
  local rects = centered_row(#state.enemies, UNIT_W, UNIT_H, 54)
  local out = {}
  for i, e in ipairs(state.enemies) do out[e.id] = rects[i] end
  return out
end

local HERO_ROW_Y = 250 -- 238->250 (2026-08-27, demande explicite -- "descendre un peu les aventuriers")

function View.hero_rects(state)
  local rects = centered_row(#state.heroes, UNIT_W, UNIT_H, HERO_ROW_Y)
  local out = {}
  for i, h in ipairs(state.heroes) do out[h.id] = rects[i] end
  return out
end

-- Point d'ancrage unique héros-ou-ennemi (2026-08-09) : utilisé par les VFX
-- qui n'ont besoin que "où est cette unité à l'écran" (nombre flottant, burst
-- d'impact), sans savoir de quel côté elle est.
function View.unit_rect(state, unit_id)
  return View.hero_rects(state)[unit_id] or View.enemy_rects(state)[unit_id]
end

-- Éventail façon Slay the Spire (2026-08-21, demande explicite -- "présentées
-- en arc de cercle") : x reste la grille régulière de centered_row (pas une
-- vraie interpolation sur cercle -- changement de code minimal pour l'effet
-- recherché), `y` descend selon l'écart au centre de la main, et un
-- `fan_angle` (radians, champ EN PLUS sur le rect) s'ajoute pour la rotation
-- visuelle. La descente est baked dans le rect lui-même : le hit-test
-- (Input.mousemoved) et le vol de cartes (Controller:animate_draw/
-- animate_discard_snapshot, qui lisent ces mêmes rects) suivent donc
-- l'éventail sans code séparé, aucun des deux ne connaît `fan_angle` et
-- l'ignore simplement (rects passés à View.point_in/aux animations de vol,
-- qui ne lisent que x/y/w/h) -- seule la rotation reste un pur habillage
-- visuel, appliqué uniquement à la carte immobile en main (voir draw_one),
-- jamais en vol (draw_card_flights, non concerné, ni pendant le survol
-- agrandi -- la carte "spéciale" se redresse, comme dans Slay the Spire).
local HAND_FAN_ANGLE_STEP = 0.05 -- radians par carte d'écart au centre (~3°)
local HAND_FAN_DROP = 7 -- px de descente par carte d'écart au centre
-- Léger chevauchement (2026-08-27, demande explicite -- "en se chevauchant
-- légèrement") : gap négatif passé à centered_row, qui gère déjà x0/l'espacement
-- entre items -- pas besoin de recalculer x à la main. -CARD_W*0.22 ~ 20px de
-- recouvrement entre deux cartes voisines, modéré pour rester lisible malgré
-- l'éventail (rotation + descente) déjà en place.
local HAND_OVERLAP_GAP = -CARD_W * 0.22

-- Redescendue, beaucoup plus bas cette fois (2026-08-27, demande explicite --
-- "beaucoup plus bas", après un premier +15px jugé insuffisant) : 419->450.
-- Butée par le budget vertical du bas d'écran (H=660, voir plus haut) : pour
-- y arriver sans déborder, "Fin de tour" a dû rétrécir un peu (88x74->88x64,
-- voir END_TURN_BTN_W/H plus bas) -- pas redemandé, mais nécessaire pour que
-- tout tienne encore à l'écran.
local HAND_Y = 450

local function hand_row_fan(count, y)
  local rects = centered_row(count, CARD_W, CARD_H, y, HAND_OVERLAP_GAP)
  local mid = (count + 1) / 2
  for i, r in ipairs(rects) do
    local d = i - mid
    r.y = r.y + math.abs(d) * HAND_FAN_DROP
    r.fan_angle = d * HAND_FAN_ANGLE_STEP
  end
  return rects
end

-- Calcule les rects de la main à partir d'une LISTE de cartes explicite plutôt
-- que de `state.hand` directement -- permet de rejouer la mise en page d'une
-- main passée (avant une défausse, par ex.) même après que `state.hand` a déjà
-- changé, pour les animations de vol de carte (voir controller.lua).
function View.hand_rects_for(cards)
  local rects = hand_row_fan(#cards, HAND_Y)
  local out = {}
  for i, c in ipairs(cards) do out[c.uid] = rects[i] end
  return out
end

function View.hand_rects(state)
  return View.hand_rects_for(state.hand)
end

--- Hit-test dédié à la main (2026-08-27, nécessaire depuis le chevauchement
-- ci-dessus, voir HAND_OVERLAP_GAP) : contrairement à `find_rect` (input.lua,
-- qui itère une table indexée par id dans un ordre non garanti), teste dans
-- l'ordre INVERSE d'affichage -- la main est dessinée dans l'ordre de
-- `state.hand` (voir draw_hand), donc la dernière carte de la liste est
-- dessinée en dernier, par-dessus ses voisines. Sans ça, un clic dans la zone
-- de recouvrement pouvait sélectionner la carte du dessous. Appelle
-- `View.point_in`, pas le `point_in` local (défini plus bas dans ce fichier --
-- la portée lexicale d'un `local function` ne remonte pas avant sa
-- déclaration) : sans risque, cette fonction n'est appelée qu'au clic/survol
-- réel, bien après le chargement complet du module.
function View.hand_hit(state, x, y)
  local rects = View.hand_rects(state)
  for i = #state.hand, 1, -1 do
    local c = state.hand[i]
    if View.point_in(rects[c.uid], x, y) then return c.uid end
  end
  return nil
end

-- Réduites de 50% (2026-08-27, demande explicite) : la pioche/défausse
-- n'ont plus besoin d'être au gabarit d'une carte pour se lire comme une
-- pile -- l'effet d'épaisseur (draw_pile) et le texte "PIOCHE : X"/
-- "DEFAUSSE : X" suffisent. CARD_W/CARD_H restent la taille des cartes
-- elles-mêmes (main, vol pioche<->main), inchangée.
local PILE_W, PILE_H = CARD_W * 0.5, CARD_H * 0.5
View.deck_pile_rect = { x = 20, y = HAND_Y, w = PILE_W, h = PILE_H }
View.discard_pile_rect = { x = W - 20 - PILE_W, y = HAND_Y, w = PILE_W, h = PILE_H }

-- Énergie globale (2026-08-11, remplace l'énergie individuelle par héros) :
-- déplacée à droite de la pioche (2026-08-27, demande explicite -- avant,
-- au-dessus). Cadre agrandi (2026-08-27, deuxième retour explicite -- "trop
-- petit") : 64x[hauteur de la pioche] -> 90x90, indépendant de la taille de
-- la pioche désormais (icône/texte agrandis en conséquence, voir
-- draw_energy_display).
local ENERGY_GAP = 8
View.energy_display_rect = {
  x = View.deck_pile_rect.x + View.deck_pile_rect.w + ENERGY_GAP, y = View.deck_pile_rect.y,
  w = 90, h = 90,
}

-- Rangée de boutons du bas ancrée sur la MAIN (2026-08-27) -- HAND_Y + CARD_H,
-- PAS sur la pioche/défausse, qui ont été réduites de 50% : sans ce
-- découplage, les boutons auraient suivi les piles vers le haut et laissé un
-- grand vide entre eux et la main. Suit automatiquement HAND_Y (voir
-- ci-dessus) si la main redescend encore. Marge resserrée à 4px (était 8) --
-- HAND_Y étant descendue beaucoup plus bas, chaque pixel du budget vertical
-- restant compte pour que "Fin de tour" tienne encore à l'écran (H=660).
local BOTTOM_ROW_Y = HAND_Y + CARD_H + 4

-- "Recommencer ce tour"/"Recommencer le combat" (repositionnés/rapetissés au
-- fil de plusieurs playtests, voir l'historique) : ancrés à gauche sous la
-- pioche. "Victoire instantanée" (2026-08-27, demande explicite) rejoint
-- désormais cette même colonne, sous "Recommencer le combat", plutôt que
-- d'être centré seul plus bas -- même gabarit que ses 2 voisins pour former
-- une colonne cohérente (avant : 140x26, plus large que tout le reste).
local RESTART_BTN_W, RESTART_BTN_H, RESTART_BTN_GAP = 96, 18, 3
View.restart_turn_button = {
  x = View.deck_pile_rect.x, y = BOTTOM_ROW_Y, w = RESTART_BTN_W, h = RESTART_BTN_H, label = "Recommencer ce tour",
}
View.restart_button = {
  x = View.deck_pile_rect.x, y = BOTTOM_ROW_Y + RESTART_BTN_H + RESTART_BTN_GAP, w = RESTART_BTN_W, h = RESTART_BTN_H,
  label = "Recommencer le combat",
}
-- Outil de test discret (2026-08-08) : termine le combat en cours par une
-- victoire immédiate, sans passer par la résolution réelle des ennemis.
View.instant_victory_button = {
  x = View.deck_pile_rect.x, y = View.restart_button.y + RESTART_BTN_H + RESTART_BTN_GAP, w = RESTART_BTN_W, h = RESTART_BTN_H,
  label = "victoire instantanée",
}

-- Agrandi (2026-08-24, demande explicite -- "un peu plus gros") : 76x64 -> 88x74.
-- Rerapetissé un peu (2026-08-27, 74->64) : contrainte de budget vertical,
-- pas une demande -- HAND_Y a été descendue beaucoup plus bas pour "la main
-- doit être beaucoup plus bas", et le bouton ne tenait plus sous elle sans
-- déborder de l'écran (H=660) autrement. Reste nettement plus carré que le
-- tout premier gabarit (140x26).
-- Toujours centré sur la pioche/défausse même réduites (2026-08-27) : plus
-- large que la pile elle-même désormais, déborde symétriquement de part et
-- d'autre -- purement cosmétique, n'affecte pas la zone cliquable de la pile.
local END_TURN_BTN_W, END_TURN_BTN_H = 88, 64
View.end_turn_button = {
  x = View.discard_pile_rect.x + View.discard_pile_rect.w / 2 - END_TURN_BTN_W / 2,
  y = BOTTOM_ROW_Y,
  w = END_TURN_BTN_W, h = END_TURN_BTN_H, label = "Fin de tour",
}

View.overlay_restart_button = { x = W / 2 - 70, y = H / 2 + 40, w = 140, h = 34, label = "Rejouer" }

-- Menu principal (2026-08-21, demande explicite) : 5 boutons empilés,
-- centrés -- même geste que les autres écrans à bouton unique (Rejouer,
-- Forge/Temple) : un id sur chaque rect, lu par Input.mousepressed pour savoir
-- quelle action déclencher, jamais une deuxième liste dupliquée côté input.lua.
local MENU_BTN_W, MENU_BTN_H, MENU_BTN_GAP = 300, 48, 18
local MENU_BTN_Y0 = 220
View.menu_buttons = {}
do
  local defs = {
    { id = "boss", label = "Tester le boss" },
    { id = "run", label = "Jouer un run" },
    { id = "infini", label = "Mode infini" },
    { id = "options", label = "Options" },
    { id = "quit", label = "Quitter" },
  }
  for i, d in ipairs(defs) do
    View.menu_buttons[i] = {
      id = d.id, label = d.label,
      x = W / 2 - MENU_BTN_W / 2, y = MENU_BTN_Y0 + (i - 1) * (MENU_BTN_H + MENU_BTN_GAP),
      w = MENU_BTN_W, h = MENU_BTN_H,
    }
  end
end

-- Écran "Options" (2026-08-21, demande explicite) : bouton "Retour" vers le
-- menu. Servait aussi à l'écran "En travaux" du boss/fin de run borné, retiré
-- depuis que l'Homme Arbre existe pour de vrai (voir Game.start_boss_test/
-- start_boss_combat) -- gardé nommé génériquement au cas où un futur écran
-- à bouton unique en ait de nouveau besoin.
View.back_button = { x = W / 2 - 90, y = H / 2 + 40, w = 180, h = 40, label = "Retour" }

-- Écran "La Forge" (2026-08-28, demande explicite -- remplace l'ancien
-- panneau "Forge" de feuDeCamp, voir Controller:enter_forge_screen) : jusqu'à
-- Forge.CHOICE_COUNT (4) cartes en rangée, chacune déjà affichée dans sa
-- version améliorée (voir draw_forge) -- le nombre de rects dépend du nombre
-- RÉEL de choix proposés (0 à 4, moins si le deck n'a pas assez de cartes
-- améliorables), donc calculé à la demande depuis controller.forge plutôt
-- qu'une position fixe.
local FORGE_CARD_Y = 260
local FORGE_CARD_GAP = 30
function View.forge_card_rects(controller)
  local f = controller.forge
  if not f then return {} end
  return centered_row(#f.choices, CARD_W, CARD_H, FORGE_CARD_Y, FORGE_CARD_GAP)
end
View.forge_skip_button = { x = W / 2 - 100, y = FORGE_CARD_Y + CARD_H + 40, w = 200, h = 44, label = "Passer" }

-- Écran "Le Temple" (2026-08-29, refonte complète -- demande explicite) :
-- jusqu'à 3 statues d'effet EN LIGNE au-dessus des 4 aventuriers (toujours
-- les 4, jamais recalculé selon l'éligibilité -- un aventurier mort ou déjà
-- porteur reste affiché, juste grisé/non cliquable, voir draw_temple/
-- Controller:choose_temple_hero). Aucun "Passer" sur cet écran (choix
-- obligatoire) -- un bouton "Confirmer" à la place, actif seulement quand
-- aventurier ET effet sont choisis (voir Controller:confirm_temple_choice).
local TEMPLE_EFFECT_W, TEMPLE_EFFECT_H = 140, 150
local TEMPLE_EFFECT_Y = 108
local TEMPLE_EFFECT_GAP = 30
function View.temple_effect_rects(controller)
  local t = controller.temple
  if not t then return {} end
  return centered_row(#t.choices, TEMPLE_EFFECT_W, TEMPLE_EFFECT_H, TEMPLE_EFFECT_Y, TEMPLE_EFFECT_GAP)
end

local TEMPLE_HERO_W, TEMPLE_HERO_H = 130, 136
local TEMPLE_HERO_Y = 300
function View.temple_hero_rects(controller)
  local rects = centered_row(#controller.state.heroes, TEMPLE_HERO_W, TEMPLE_HERO_H, TEMPLE_HERO_Y)
  local out = {}
  for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
  return out
end
View.temple_confirm_button = {
  x = W / 2 - 100, y = TEMPLE_HERO_Y + TEMPLE_HERO_H + 20, w = 200, h = 44, label = "Confirmer",
}

local function point_in(r, x, y)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end
View.point_in = point_in

-- ---------- petites aides de dessin ----------

local function set(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function panel(x, y, w, h, color)
  set(color or Theme.panel)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
end

local function text(str, x, y, w, size, color, align)
  love.graphics.setFont(Fonts.get(size or 14))
  set(color or Theme.text)
  love.graphics.printf(str, x, y, w, align or "center")
end

--- Comme `text`, mais centrée VERTICALEMENT dans une hauteur `h` donnée
-- (2026-08-27, demande explicite -- "les PV numériques doivent être centrés
-- en hauteur") plutôt qu'un décalage `y` choisi à l'œil : lit la vraie
-- hauteur de ligne de la police (Font:getHeight(), pas une valeur supposée
-- égale à `size`) pour un centrage exact quelle que soit la police chargée.
-- `bar_y`/`bar_h` = le rectangle dans lequel centrer (ex. une barre de PV),
-- pas forcément toute la zone où `str` pourrait s'afficher.
local function text_v_centered(str, x, bar_y, w, bar_h, size, color)
  local font = Fonts.get(size or 14)
  love.graphics.setFont(font)
  set(color or Theme.text)
  love.graphics.printf(str, x, bar_y + (bar_h - font:getHeight()) / 2, w, "center")
end

--- Nom mis en valeur dans un cadre arrondi de couleur distincte, contour noir compris
-- (2026-08-10, demande explicite) -- aventuriers, ennemis, cartes. `pad` ajoute de la
-- marge verticale autour du texte (le cadre grandit, le texte reste à `size` mais se
-- recentre dedans) -- l'appelant doit alors décaler les éléments qui suivent en
-- conséquence, ces emplacements étant calés au pixel près (voir fonts.lua --
-- BODY_FONT_NATIVE_SIZE).
local function name_badge(str, x, y, w, size, bg, text_color, inset, pad)
  inset = inset or 4
  pad = pad or 0
  local bx, bw, bh = x + inset, w - inset * 2, size + pad * 2
  set(bg)
  love.graphics.rectangle("fill", bx, y, bw, bh, 4, 4)
  set(Theme.black)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, y, bw, bh, 4, 4)
  love.graphics.setLineWidth(1)
  text(str, x, y + pad, w, size, text_color, "center")
end

--- Dessine `icon` (un emoji) si une police-icône capable de le rendre a pu
-- être chargée, sinon replie sur `label` (texte simple, toujours lisible).
-- Voir src/ui/fonts.lua — jamais de glyphe manquant/tofu à l'écran.
local function icon_text(icon, label, x, y, w, size, color)
  local font = icon and Fonts.icon(size)
  if font then
    local ok, has = pcall(function() return font:hasGlyphs(icon) end)
    if ok and has then
      love.graphics.setFont(font)
      set(color or Theme.text)
      love.graphics.printf(icon, x, y, w, "center")
      return
    end
  end
  text(label or icon or "?", x, y, w, size, color)
end

--- Icône de classe (épée/bouclier/orbe/dague, voir src/ui/icons.lua) centrée
-- dans la zone (x, y, w, size) ; repli sur icon_text si la classe est inconnue.
local function draw_class_icon(class_id, icon, label, x, y, w, size, color)
  local drawn = Icons.draw_class(class_id, x + w / 2, y + size / 2, size / 2, color or Theme.text)
  if not drawn then icon_text(icon, label, x, y, w, size, color) end
end

--- Silhouette de l'ennemi (voir src/ui/icons.lua) ; repli sur icon_text/label
-- si le template n'a pas d'icône dessinée (ne devrait pas arriver, les 10
-- types du bestiaire Run Infini sont tous couverts).
local function draw_enemy_icon(template_id, icon, label, x, y, w, size, color)
  local drawn = Icons.draw_enemy(template_id, x + w / 2, y + size / 2, size / 2, color or Theme.text)
  if not drawn then icon_text(icon, label, x, y, w, size, color) end
end

-- Rémanence sur l'arrivée d'un badge (2026-08-28, demande explicite --
-- "gros puis scale vers le point d'arrivée avec un effet de rémanence
-- pendant quelques courts instants") : 2 échos fantômes dessinés à une
-- échelle plus grande que l'icône réelle, alpha dégressif, seulement pendant
-- le premier ECHO_WINDOW du pop -- juste assez pour donner une impression de
-- traînée lumineuse qui se resserre, PAS un vrai système de particules (même
-- esprit que draw_particles dans ce fichier : simple, à la main).
local STATUS_POP_ECHO_WINDOW = 0.6 -- fraction de pop_duration pendant laquelle les échos existent
local STATUS_POP_ECHO_COUNT = 2

--- Icône de statut (voir src/ui/icons.lua) avec sa valeur numérique à côté
-- (value peut être nil, ex. Camouflage qui n'a pas de compteur) ; repli texte
-- "ABBR valeur" si la clé n'a pas d'icône dessinée. `pop_t`/`pop_duration`
-- (2026-08-09, optionnels) : le badge part agrandi et retombe à sa taille
-- normale pendant `pop_duration` -- signale visuellement qu'il vient d'être
-- appliqué, sans rien changer quand ils sont absents (statut déjà présent).
local function status_badge(status_key, abbr, value, x, y, w, size, color, pop_t, pop_duration)
  local cx, cy = x + size * 0.55, y + size / 2
  local scale = 1
  local p = nil
  if pop_t and pop_duration then
    p = math.min(1, pop_t / pop_duration)
    scale = 1 + 0.5 * (1 - p)
  end
  -- Échos AVANT l'icône réelle (derrière, alpha faible) : sinon ils la
  -- recouvriraient et casseraient sa lisibilité pendant le pop.
  if p and p < STATUS_POP_ECHO_WINDOW then
    local echo_life = 1 - p / STATUS_POP_ECHO_WINDOW -- 1 -> 0 sur la fenêtre
    for i = 1, STATUS_POP_ECHO_COUNT do
      local echo_alpha = echo_life * 0.3 / i
      local echo_scale = scale * (1 + 0.22 * i)
      love.graphics.push()
      love.graphics.translate(cx, cy)
      love.graphics.scale(echo_scale, echo_scale)
      love.graphics.translate(-cx, -cy)
      Icons.draw_status(status_key, cx, cy, size * 0.42, color or Theme.status, echo_alpha)
      love.graphics.pop()
    end
  end
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)
  local drawn = Icons.draw_status(status_key, cx, cy, size * 0.42, color or Theme.status)
  if drawn then
    if value then text(tostring(value), x + size * 0.85, y + size * 0.18, w - size * 0.85, size * 0.72, color, "left") end
  else
    text(abbr .. (value and (" " .. value) or ""), x, y, w, size, color)
  end
  love.graphics.pop()
end

--- Une ligne de badges de statut, chacun avec son icône dessinée + valeur (ou
-- son repli texte), répartis à parts égales sur la largeur donnée. `items` :
-- liste de { key = "defense", abbr = "DEF", value = 3 } (value optionnelle).
-- `pop_lookup` (optionnel) : table [status_key] = elapsed, voir Controller.status_pop.
local function draw_badge_row(items, x, y, w, size, color, pop_lookup, pop_duration)
  if #items == 0 then return end
  local slot = w / #items
  for i, it in ipairs(items) do
    local pop_t = pop_lookup and pop_lookup[it.key]
    status_badge(it.key, it.abbr, it.value, x + (i - 1) * slot, y, slot, size, color, pop_t, pop_duration)
  end
end

local function bar(x, y, w, h, pct, color)
  set({ 0, 0, 0 }, 0.35)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  set(color)
  love.graphics.rectangle("fill", x, y, w * math.max(0, math.min(1, pct)), h, 4, 4)
  -- Contour noir (2026-08-10, demande explicite) : accentue l'importance de la barre,
  -- même traitement que name_badge.
  set(Theme.black)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  love.graphics.setLineWidth(1)
end

local function unit_anim_transform(controller, id)
  local a = controller.anim[id]
  if not a then return 0, 0, 1 end
  if a.kind == "pulse-up" then
    local t = a.t / 0.38
    return 0, -10 * (1 - (1 - t) ^ 2), 1 + 0.05 * (1 - t)
  elseif a.kind == "pulse-down" then
    local t = a.t / 0.38
    return 0, 10 * (1 - (1 - t) ^ 2), 1 + 0.05 * (1 - t)
  elseif a.kind == "shake" then
    local t = a.t
    return math.sin(t * 60) * 6 * math.max(0, 1 - t), 0, 1
  end
  return 0, 0, 1
end

--- Courbe "ease-out-back" classique : va de 0 à 1 en dépassant légèrement 1
-- (le "bump") avant de s'y stabiliser. Utilisée pour le zoom du titre
-- "Victoire !" (2026-08-08) -- `duration` vient de `controller.victory_title_duration`,
-- seule source de vérité pour ce timing (voir controller.lua).
local function ease_out_back(t, duration)
  local p = math.min(1, math.max(0, t / duration))
  local c1, c3 = 1.70158, 2.70158
  return 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
end

--- Facteur d'échelle horizontale simulant un retournement de carte (face
-- cachée -> face visible) : 1 -> 0 (tranche) -> 1, jamais négatif (donc jamais
-- de miroir). Le contenu affiché doit basculer face/dos exactement à p=0.5.
local function flip_scale_x(t, duration)
  local p = math.min(1, math.max(0, t / duration))
  return math.abs(math.cos(p * math.pi))
end

--- Gros bouclier en fondu (2026-08-09, retour du porteur de projet) sur un
-- gain de Défense : 1s, fondu entrant/sortant, `r` = rect LOCAL de la carte
-- (déjà dans l'espace translaté de draw_hero/draw_enemy).
-- Réutilise désormais Icons.draw_status("defense", ...) (2026-08-27, demande
-- explicite -- même icône que le badge persistant, voir draw_defense_badge_big)
-- au lieu d'une silhouette dupliquée (l'ancien draw_big_shield, retiré) : ce
-- module a été rendu capable de forwarder un alpha (voir icons.lua), ce qui le
-- bloquait auparavant pour un usage en fondu.
local function draw_shield_fx(controller, unit_id, r)
  local s = controller.shield_fx[unit_id]
  if not s then return end
  local dur = controller.shield_fx_duration
  local t = s.t
  local alpha
  if t < dur * 0.2 then
    alpha = t / (dur * 0.2)
  elseif t > dur * 0.7 then
    alpha = 1 - (t - dur * 0.7) / (dur * 0.3)
  else
    alpha = 1
  end
  -- Theme.def existe dans la palette mais n'était utilisé nulle part -- couleur
  -- dédiée à la Défense plutôt que de recycler Theme.energy (déjà pris par
  -- l'affichage d'énergie et le ciblage en mode flèche).
  Icons.draw_status("defense", r.w / 2, r.h / 2, r.w * 0.4, Theme.def, alpha * 0.9)
  -- Montant absorbé (2026-08-24, demande explicite) : affiché seulement quand
  -- ce fondu vient d'intercepter un coup (Controller:react_to_diff pose
  -- `s.amount` dans ce cas précis) -- absent sur un simple gain de Défense.
  if s.amount then
    set(Theme.text, alpha)
    love.graphics.setFont(Fonts.get(14))
    love.graphics.printf("-" .. tostring(s.amount), 0, r.h / 2 - 8, r.w, "center")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Indicateur de Défense PERSISTANT (2026-08-27, demande explicite -- "doivent
-- apparaître beaucoup plus gros et centrés, difficile à voir actuellement") :
-- avant, la Défense courante n'apparaissait que comme un petit badge de statut
-- (16px, mélangé à Esquive/Puissance/etc. dans draw_badge_row) -- draw_shield_fx
-- ci-dessus ne flashe qu'un court instant au GAIN de Défense, rien n'indique
-- qu'un bouclier est encore actif après coup. Ce badge-ci reste affiché tant
-- que unit.defense > 0, à part de la rangée de statuts partagée (retiré de
-- `badges` dans draw_hero/draw_enemy).
-- Encore agrandi et déplacé en bas au milieu du cadre (2026-08-27, deuxième
-- retour explicite -- toujours pas assez visible en haut à droite) : 16->24px
-- de rayon, chiffre centré SUR l'icône comme avant.
-- `cy` (optionnel, 2026-08-27, troisième retour explicite) : par défaut ancré
-- près du bas du cadre (`r.h - DEFENSE_BADGE_R - 4`, héros -- rien d'autre à
-- cet endroit), mais draw_enemy passe désormais une position plus haute pour
-- ne pas recouvrir l'annonce d'attaque télégraphiée (voir draw_telegraph_body),
-- elle aussi poussée en bas du cadre -- les deux se disputaient la même zone.
local DEFENSE_BADGE_R = 24
local function draw_defense_badge_big(unit, r, cy)
  local val = unit.defense or 0
  if val <= 0 then return end
  local cx = r.w / 2
  cy = cy or (r.h - DEFENSE_BADGE_R - 4)
  local drawn = Icons.draw_status("defense", cx, cy, DEFENSE_BADGE_R, Theme.def)
  if drawn then
    set(Theme.text)
    love.graphics.setFont(Fonts.get(14))
    love.graphics.printf(tostring(val), cx - DEFENSE_BADGE_R, cy - 7, DEFENSE_BADGE_R * 2, "center")
  else
    text("DEF " .. val, 0, cy - 7, r.w, 14, Theme.def, "center")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Indice discret d'infobulle (2026-08-21, demande explicite -- tuto onboarding) :
-- petit "?" en bas à droite de tout élément qui porte une infobulle (allié,
-- ennemi, carte), à très léger alpha pour ne jamais dominer visuellement --
-- PUREMENT décoratif, ne change ni la zone de survol ni le délai d'apparition
-- de l'infobulle elle-même (voir Controller.hover_ready/HOVER_DELAY). Espace
-- local [0,0]..[w,h] de l'appelant, comme draw_card_face.
-- Rond blanc autour du "?" (2026-08-21, demande explicite -- "pour qu'on
-- puisse mieux le voir") : contour seul (pas rempli, resterait discret),
-- alpha légèrement plus marqué que le glyphe lui-même puisque son seul rôle
-- est d'aider l'œil à repérer le point d'interrogation, pas d'attirer
-- l'attention pour lui-même.
local TOOLTIP_HINT_ALPHA = 0.35
local TOOLTIP_HINT_RING_ALPHA = 0.45
-- `color` (optionnel, 2026-08-28, demande explicite -- même indice sur le
-- bouton "Fin de tour") : le blanc/Theme.text par défaut suppose un fond
-- sombre (panneau) -- sur un bouton à fond clair (Theme.accent, doré), un "?"
-- clair se lirait mal, d'où cette dérogation plutôt qu'une variante dupliquée.
local function draw_tooltip_hint(w, h, color)
  local cx, cy = w - 10, h - 9
  set(color or Theme.white, TOOLTIP_HINT_RING_ALPHA)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", cx, cy, 8)
  love.graphics.setFont(Fonts.get(11))
  set(color or Theme.text, TOOLTIP_HINT_ALPHA)
  love.graphics.printf("?", cx - 6, cy - 6, 12, "center")
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------- unités (héros/ennemis) ----------

local function draw_hero(controller, h, r)
  local dead = h.hp <= 0
  local hero_palette = Theme.card_class[h.class_id] or Theme.card_class.generic

  local pending = controller.state.pending
  local eligible_target = pending and pending.hero_id and pending.def.target == "ally" and not dead and h.id ~= pending.hero_id
  -- Chaque carte a désormais un propriétaire fixe (def.class_id, voir
  -- Heroes.class_name) : la sélectionner l'assigne DIRECTEMENT à ce héros
  -- (Game.select_card/Game.assign_hero, plus de choix manuel -- voir
  -- Controller:select_card) -- `awaiting_own_target` couvre donc toute la
  -- fenêtre entre la sélection et la résolution réelle (clic de cible pour
  -- une carte ennemie/alliée). Déclenche l'anticipation (grossit + pulse en
  -- boucle) ci-dessous.
  local awaiting_own_target = pending and pending.hero_id == h.id
  -- Un héros peut agir plusieurs fois par tour (2026-08-20, demande explicite
  -- -- plus de notion de "a déjà agi") : cadre vert tant qu'il est vivant,
  -- indicateur permanent, jamais de voile gris de fin de tour.
  local ready = not dead

  -- Cadre bleu = cible possible pour la carte en attente (allié) ; doré =
  -- propriétaire de la carte sélectionnée, en attente de sa résolution ;
  -- priorité sur la couleur de classe (2026-08-24, demande explicite -- avant,
  -- un vert générique "prêt à agir", devenu peu informatif depuis que tout
  -- héros vivant peut toujours agir, voir `ready` ci-dessus) -- un héros peut
  -- être plusieurs choses à la fois, mais l'invite la plus spécifique à
  -- l'instant l'emporte. Même teinte que ses propres cartes (Theme.card_class,
  -- voir draw_card_face) : le cadre du héros se reconnaît d'un coup d'œil
  -- comme "sa" couleur.
  local border, border_w = Theme.panel_light, 1
  if eligible_target then
    border, border_w = Theme.energy, 3
  elseif awaiting_own_target then
    border, border_w = Theme.accent, 3
  elseif ready then
    border, border_w = hero_palette.border, 3
  end

  local arrow_mode = controller.input_mode == "arrow"
  local dx, dy, scale = unit_anim_transform(controller, h.id)
  -- Petit rebond continu au survol d'une cible alliée valide (carte à cible
  -- alliée, ex. Rempart) -- cohérent avec le pulse ajouté côté ennemis
  -- (draw_enemy). Calculé sur le rect ABSOLU, avant toute translation
  -- d'animation -- doit rester en phase avec le hit-test réel d'input.lua,
  -- qui lit le même View.hero_rects.
  local hovering_as_ally_target = false
  if arrow_mode and eligible_target then
    local mx, my = love.mouse.getPosition()
    mx, my = mx / SCALE, my / SCALE
    hovering_as_ally_target = point_in(r, mx, my)
  end
  if hovering_as_ally_target then
    scale = scale * (1 + 0.035 * math.sin(love.timer.getTime() * 8))
  end
  -- "Anticipation" (2026-08-20, demande explicite) : le propriétaire d'une
  -- carte sélectionnée grossit et pulse EN BOUCLE (pas un one-shot expirant
  -- comme unit_anim_transform ci-dessus) tant que sa carte attend une cible --
  -- dérivé directement de `awaiting_own_target`/state.pending, jamais un
  -- second état à synchroniser à la main.
  if awaiting_own_target then
    scale = scale * (1.12 + 0.045 * math.sin(love.timer.getTime() * 5))
  end

  love.graphics.push()
  love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-r.w / 2, -r.h / 2)

  set(Theme.panel, dead and 0.5 or 1)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  -- Fond de plus en plus rouge sombre sous 50% de PV (2026-08-27, demande
  -- explicite), proportionnel aux PV perdus au-delà de ce seuil -- "montrer
  -- qu'il est de plus en plus blessé et proche de la mort". Simple surcouche
  -- semi-transparente (Theme.hp, le rouge déjà utilisé pour les dégâts/la
  -- barre de PV -- pas une nouvelle teinte) plutôt qu'un vrai mélange RGB :
  -- alpha 0 pile à 50% de PV, jusqu'à 0.6 à 0 PV. Un héros déjà vaincu (voile
  -- gris via l'alpha du panneau ci-dessus) n'a plus besoin de cet indice.
  if not dead then
    local hp_pct = h.hp / h.max_hp
    if hp_pct < 0.5 then
      local wound_t = math.min(1, (0.5 - hp_pct) / 0.5)
      set(Theme.hp, wound_t * 0.6)
      love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
    end
  end
  set(border); love.graphics.setLineWidth(border_w)
  love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

  -- Portrait agrandi (2026-08-27, demande explicite -- "toutes les images des
  -- aventuriers et des ennemis doivent être plus gros") : 46->54. Nom déplacé
  -- EN BAS du cadre (2026-08-27, demande explicite) : l'ordre devient portrait
  -- -> barre de PV -> mana/discrétion -> statuts -> nom, au lieu de portrait
  -- -> nom -> barre -> ... avant. Le badge de Défense s'ancre désormais au-dessus
  -- du nom (voir cy passé à draw_defense_badge_big), pas près du bas par défaut.
  set(Theme.text, dead and 0.45 or 1)
  local HERO_PORTRAIT_SIZE = 54
  draw_class_icon(h.class_id, h.icon, h.label, 0, 4, r.w, HERO_PORTRAIT_SIZE, Theme.text)
  -- Badges de bénédiction/malédiction du Temple (2026-08-28/29, demande
  -- explicite -- "représenté par une icone de statue de la bonne couleur, 1
  -- pour les bénédictions, l'autre pour les malédictions") : coin haut-droit
  -- pour la bénédiction, haut-gauche pour la malédiction -- les 2 seules
  -- zones encore libres du cadre (portrait au centre, PV/mana/statuts en
  -- dessous, nom tout en bas). Un aventurier peut porter les DEUX à la fois
  -- (2 champs indépendants, voir temple.lua) -- jamais un seul badge qui
  -- devrait choisir lequel montrer. `h.blessing`/`h.curse` ne portent que
  -- l'id -- couleur/texte d'infobulle viennent de Temple.by_id, jamais
  -- dupliqués ici.
  if not dead and h.blessing then
    local blessing = Temple.by_id(h.blessing)
    if blessing then
      local color = TEMPLE_STATUE_COLORS[blessing.color] or Theme.heal
      set(color); love.graphics.circle("fill", r.w - 14, 14, 11)
      set(Theme.black); love.graphics.setLineWidth(2)
      love.graphics.circle("line", r.w - 14, 14, 11)
      love.graphics.setLineWidth(1)
      Icons.draw_status("temple_blessing", r.w - 14, 14, 8, Theme.bg)
    end
  end
  if not dead and h.curse then
    local curse = Temple.by_id(h.curse)
    if curse then
      local color = TEMPLE_STATUE_COLORS[curse.color] or Theme.hp
      set(color); love.graphics.circle("fill", 14, 14, 11)
      set(Theme.black); love.graphics.setLineWidth(2)
      love.graphics.circle("line", 14, 14, 11)
      love.graphics.setLineWidth(1)
      Icons.draw_status("temple_curse", 14, 14, 8, Theme.bg)
    end
  end
  local name_y = r.h - 24
  draw_defense_badge_big(h, r, name_y - 24)
  -- Barre de PV épaissie, valeur DEDANS plutôt qu'en dessous (2026-08-27,
  -- demande explicite) : texte superposé plutôt qu'une ligne à part.
  bar(8, 62, r.w - 16, 16, h.hp / h.max_hp, Theme.hp)
  text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", 0, 62, r.w, 16, 10, Theme.text)

  -- Mana (2026-08-20, ressource propre au Mage, voir hero.mana dans game.lua) :
  -- dans son propre cadre, juste sous sa jauge de PV -- seul le Mage a ce
  -- champ non-nil, les 3 autres classes ne dessinent jamais cette ligne.
  if h.mana ~= nil then
    text("MANA " .. tostring(h.mana), 0, 81, r.w, 9, Theme.mana)
  end
  -- Discrétion (2026-08-24, ressource propre à l'Assassin, voir hero.discretion
  -- dans game.lua) : même traitement que MANA ci-dessus -- un seul des deux
  -- champs est jamais non-nil pour un héros donné, pas de collision possible.
  if h.discretion ~= nil then
    text("DISCR " .. tostring(h.discretion), 0, 81, r.w, 9, Theme.discretion)
  end

  -- Plus de bouton "Jouer" (2026-08-20) : sélectionner une carte assigne
  -- directement son propriétaire (voir Game.select_card), l'encart n'a donc
  -- plus qu'un seul contenu possible ici, quel que soit l'état de `pending`.
  -- Défense retirée de cette rangée (2026-08-27) : affichée à part, en plus
  -- gros, voir draw_defense_badge_big appelé plus haut près du portrait.
  local badges = {}
  if (h.esquive or 0) > 0 then badges[#badges + 1] = { key = "esquive", abbr = "ESQ", value = h.esquive } end
  -- Pas de valeur affichée (2026-08-24, demande explicite) : Camouflé est un
  -- ÉTAT (présent/absent, voir Game.gain_discretion -- il ne s'accumule plus
  -- en compteur depuis que la Discrétion l'a remplacé comme ressource
  -- graduelle), plus un statut à empiler -- "CAM" seul, jamais "CAM N".
  if (h.camoufle or 0) > 0 then badges[#badges + 1] = { key = "camoufle", abbr = "CAM" } end
  if (h.puissance or 0) > 0 then badges[#badges + 1] = { key = "puissance", abbr = "PUI", value = h.puissance } end
  if (h.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = h.saignements } end
  -- Incapacité/Vulnérabilité (bug signalé, 2026-08-24) : oubliées ici alors que
  -- draw_enemy les affichait déjà -- un héros PEUT porter ces deux statuts
  -- (ex. Malédiction du Nécromancien Novice pose Vulnérabilité), le
  -- multiplicateur de dégâts en tenait déjà compte (Combat.damage_multiplier),
  -- seul le badge manquait -- le statut était donc invisible côté joueur.
  if (h.incapacite or 0) > 0 then badges[#badges + 1] = { key = "incapacite", abbr = "INC", value = h.incapacite } end
  if (h.vulnerabilite or 0) > 0 then badges[#badges + 1] = { key = "vulnerabilite", abbr = "VUL", value = h.vulnerabilite } end
  -- Provocation (2026-08-28, statut du Paladin) : uniquement côté héros, aucun
  -- ennemi ne le porte -- pas de branche équivalente dans draw_enemy.
  if (h.provocation or 0) > 0 then badges[#badges + 1] = { key = "provocation", abbr = "PROV", value = h.provocation } end
  -- Bouclier programmé (2026-08-28, demande explicite -- "icone dédiée",
  -- Infranchissable) : pas un vrai statut numérique (hero.scheduled_shields
  -- est un TABLEAU d'entrées {amount, turns_left}, jamais un champ dans
  -- STATUS_KEYS) -- valeur affichée = somme des montants encore en attente,
  -- recalculée à chaque frame directement depuis les données, jamais
  -- dupliquée dans un champ à part.
  if h.scheduled_shields and #h.scheduled_shields > 0 then
    local pending_total = 0
    for _, entry in ipairs(h.scheduled_shields) do pending_total = pending_total + entry.amount end
    badges[#badges + 1] = { key = "shield_pending", abbr = "PROG", value = pending_total }
  end
  draw_badge_row(badges, 0, 93, r.w, 16, Theme.status, controller.status_pop[h.id], controller.status_pop_duration)

  -- Nom en bas du cadre (2026-08-27, demande explicite) : voir name_y calculé
  -- plus haut, juste après le portrait -- réutilisé aussi par draw_defense_badge_big
  -- pour s'ancrer juste au-dessus.
  name_badge(h.name, 0, name_y, r.w, 16, hero_palette.border, Theme.bg, 4, 2)

  draw_shield_fx(controller, h.id, r)
  draw_tooltip_hint(r.w, r.h)

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- Présentation en 3 lignes distinctes (2026-08-24, demande explicite -- avant,
-- un seul bloc de texte compact "Titre — montant\nvise Cible") : `title` seul
-- (le nom du coup), `body` (montant/effet), `target` (nom de la cible, SANS
-- le mot "vise" -- juste le nom, la flèche visuelle de draw_enemy_target_arrows
-- suffit déjà à indiquer "cible"). `target` utilise `target.name` (nom
-- affiché, ex. "Guerrier"), pas `e.target_hero_id` (id brut en minuscules,
-- ex. "guerrier" -- bug de présentation corrigé au passage). `target_class`
-- (2026-08-24, demande explicite) : class_id de la cible, pour que
-- draw_enemy/draw_enemy_target_arrows puissent colorer la bande/flèche à sa
-- couleur de classe (Theme.card_class) plutôt qu'une teinte fixe. `body`/
-- `target`/`target_class` peuvent être nil (ex. Vaincu., heal-self/heal-ally
-- sans cible) -- à l'appelant (draw_enemy) de ne dessiner que ce qui existe.
-- Icône de dégâts + mot "dégâts" retiré (2026-08-27, demande explicite) :
-- `body` ne contient plus jamais ce mot, `icon_source`/`icon_key` indiquent à
-- draw_telegraph_body (ci-dessous) quelle icône préfixer -- "keyword" pour un
-- mot-clé du glossaire (épée/arbalète/étincelle/soin, mêmes icônes que sur les
-- cartes des aventuriers, voir Sprites.keyword), "status" pour une icône de
-- statut (Icons.draw_status). Le type mêlée/distance/magie vient de
-- `move.dmg_type` (voir enemies.lua, assigné par attaque) -- jamais deviné
-- depuis le nom.
-- Bonus/malus génériques, sans valeur chiffrée (2026-08-27, deuxième demande
-- explicite) : `body` est alors absent -- un débuff (kind == "debuff") pose
-- toujours icon_key = "malus" (jamais le statut précis, ex. "vulnerabilite" --
-- le détail reste dans l'infobulle) ; un soin à soi/un allié ou une
-- résurrection posent icon_key = "bonus". Ces deux clés sont des icônes
-- neutres dédiées (voir DRAW_BY_STATUS dans icons.lua), pas de vraies statuts
-- de jeu.
local DMG_TYPE_ICON = { melee = "epee", ranged = "arc", magic = "etincelle" }
local function enemy_telegraph_parts(state, e)
  if e.hp <= 0 then return { title = "Vaincu." } end
  local move = e.next_move
  if not move then return nil end
  -- Montant réellement ajusté (2026-08-09, demande explicite) : la propre
  -- Incapacité de l'ennemi ET la Vulnérabilité de sa cible (déjà fixée pour
  -- tout le tour, pas besoin de survol) -- même calcul que la résolution
  -- réelle (Combat.deal_damage, via resolve_enemy_attack), jamais une
  -- deuxième formule dupliquée ici.
  local target = e.target_hero_id and Combat.hero_by_id(state, e.target_hero_id)
  local target_name = target and target.name or nil
  local target_class = target and target.class_id or nil
  local function adjusted(amount)
    return Combat.round(amount * Combat.damage_multiplier(e, target, "physique"))
  end
  if move.kind == "dmg" then
    return {
      title = move.name, body = tostring(adjusted(move.amount)),
      icon_source = "keyword", icon_key = DMG_TYPE_ICON[move.dmg_type] or "epee",
      target = target_name, target_class = target_class,
    }
  elseif move.kind == "debuff" then
    -- Malus générique, jamais de valeur chiffrée (2026-08-27, demande
    -- explicite) : icône "malus" neutre quel que soit le statut réellement
    -- appliqué (Vulnérabilité, Incapacité...) -- le détail (lequel, combien)
    -- reste dans l'infobulle ("Action en cours" + moves_info, voir
    -- tooltip_lines), jamais recopié ici.
    return { title = move.name, icon_source = "status", icon_key = "malus", target = target_name, target_class = target_class }
  elseif move.kind == "heal-self" or move.kind == "heal-ally" or move.kind == "revive" then
    -- Bonus générique, jamais de valeur chiffrée (2026-08-27, demande
    -- explicite -- même principe que le malus ci-dessus) : soin à soi, soin à
    -- un allié et résurrection sont les 3 façons dont un ennemi s'avantage
    -- lui-même ou un autre ennemi -- une seule icône "bonus" neutre pour les
    -- 3, le détail reste dans l'infobulle.
    return { title = move.name, icon_source = "status", icon_key = "bonus" }
  elseif move.kind == "conditional-retaliate" then
    -- Bug signalé (2026-08-09) : contrairement à dmg/debuff juste au-dessus,
    -- cette branche n'affichait jamais la cible (`e.target_hero_id`, pourtant
    -- déjà tirée par Encounter.roll_telegraphs -- voir Combat.TARGETABLE_MOVE_KINDS)
    -- ni le fait que le Golem VA riposter une fois qu'il a déjà encaissé un coup
    -- ce tour (`e.took_damage_this_turn`, lu par Game.resolve_enemy_action).
    local icon_source, icon_key = "keyword", DMG_TYPE_ICON[move.dmg_type] or "epee"
    if e.took_damage_this_turn then
      return {
        title = "Riposte (touché)", body = tostring(adjusted(move.amount)), icon_source = icon_source, icon_key = icon_key,
        target = target_name, target_class = target_class,
      }
    end
    return {
      title = move.name, body = adjusted(move.amount) .. " si touché", icon_source = icon_source, icon_key = icon_key,
      target = target_name, target_class = target_class,
    }
  elseif move.kind == "dmg-all" then
    -- Homme Arbre, "Onde Sylvestre" (2026-08-21) : pas de cible unique --
    -- l'ajustement ne tient donc compte que des modificateurs côté attaquant
    -- (Puissance/Incapacité), jamais de la Vulnérabilité d'un héros précis
    -- (chacun peut différer), comme heal-self/heal-ally juste au-dessus.
    return {
      title = move.name, body = Combat.round(move.amount * Combat.damage_multiplier(e, nil, "physique")) .. " à tous",
      icon_source = "keyword", icon_key = DMG_TYPE_ICON[move.dmg_type] or "etincelle",
    }
  end
  return nil
end

--- Dessine `parts.body` précédé de son icône (parts.icon_source/icon_key,
-- voir enemy_telegraph_parts ci-dessus), centré comme une seule unité dans la
-- largeur `w` -- "keyword" pour un mot-clé du glossaire (Sprites.keyword),
-- "status" pour un statut (Icons.draw_status). Simple texte centré si aucune
-- icône n'est renseignée (ne devrait pas arriver pour un coup réel, garde-fou).
-- `parts.body` peut être absent (2026-08-27, demande explicite -- bonus/malus
-- génériques, voir enemy_telegraph_parts) : l'icône seule est alors centrée,
-- sans aucune valeur chiffrée à côté.
-- Icône/texte agrandis (2026-08-27, deuxième demande explicite -- "les
-- textes/icônes indiquant les attaques des ennemis doivent être plus gros") :
-- icône 14->22px, police 9->14. Le centrage vertical de l'icône se déduit
-- désormais de icon_size/2 (au lieu d'un décalage fixe "+5" calé sur l'ancien
-- 14px) pour rester correct quelle que soit sa taille.
local function draw_telegraph_body(parts, y, w)
  if not parts.icon_key and not parts.body then return end
  if not parts.icon_key then
    text(parts.body, 0, y, w, 14, Theme.accent)
    return
  end
  local icon_size = 22
  local icon_cy = y + icon_size / 2
  if not parts.body then
    local cx = w / 2
    if parts.icon_source == "status" then
      Icons.draw_status(parts.icon_key, cx, icon_cy, icon_size / 2, Theme.accent)
    else
      local icon = Sprites.keyword(parts.icon_key)
      if icon then
        love.graphics.setColor(1, 1, 1, 1)
        Sprites.draw_centered(icon, cx, icon_cy, icon_size / 2)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return
  end
  local font = Fonts.get(14)
  local text_w = font:getWidth(parts.body)
  local gap = 4
  local start_x = (w - (icon_size + gap + text_w)) / 2
  if parts.icon_source == "status" then
    Icons.draw_status(parts.icon_key, start_x + icon_size / 2, icon_cy, icon_size / 2, Theme.accent)
  else
    local icon = Sprites.keyword(parts.icon_key)
    if icon then
      love.graphics.setColor(1, 1, 1, 1)
      Sprites.draw_centered(icon, start_x + icon_size / 2, icon_cy, icon_size / 2)
    end
  end
  set(Theme.accent)
  love.graphics.setFont(font)
  love.graphics.print(parts.body, start_x + icon_size + gap, y)
  love.graphics.setColor(1, 1, 1, 1)
end

local function draw_enemy(controller, e, r)
  local dead = e.hp <= 0

  local pending = controller.state.pending
  local hero = pending and pending.hero_id and Combat.hero_by_id(controller.state, pending.hero_id)
  local awaiting_enemy_target = pending and pending.hero_id and not dead
    and (pending.def.target == "enemy" or (pending.def.target == "conditional" and hero and not Combat.enemy_targeting(controller.state, hero)))

  -- Même rebond que côté héros (2026-08-09, mode "flèche") quand cet ennemi
  -- précis est une cible valide ET survolé par la souris -- calculé sur le
  -- rect ABSOLU, avant toute translation d'animation.
  local dx, dy, scale = unit_anim_transform(controller, e.id)
  if controller.input_mode == "arrow" and awaiting_enemy_target then
    local mx, my = love.mouse.getPosition()
    mx, my = mx / SCALE, my / SCALE
    if point_in(r, mx, my) then
      scale = scale * (1 + 0.035 * math.sin(love.timer.getTime() * 8))
    end
  end

  love.graphics.push()
  love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-r.w / 2, -r.h / 2)

  -- Cadre bleu = cible possible pour la carte en attente de résolution
  -- (2026-08-08) -- même couleur que côté héros (voir eligible_target dans
  -- draw_hero), pour que "bleu" signifie systématiquement "cible cliquable".
  set(Theme.panel, dead and 0.5 or 1)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  set(awaiting_enemy_target and Theme.energy or Theme.panel_light)
  love.graphics.setLineWidth(awaiting_enemy_target and 3 or 1)
  love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

  -- Barre de PV au-dessus du portrait, pas en dessous (2026-08-27, demande
  -- explicite) : bar 4->20, épaissie (10->16) avec la valeur DEDANS plutôt
  -- qu'une ligne à part (même traitement que draw_hero) ; portrait décalé de
  -- 4 à 26 pour lui laisser la place. Nom/niveau restent hors du cadre
  -- (2026-08-27, voir tooltip_lines) : rien ne les remplace ici.
  set(Theme.text, dead and 0.45 or 1)
  if not dead then
    bar(8, 4, r.w - 16, 16, e.hp / e.max_hp, Theme.hp)
    text_v_centered(math.max(0, e.hp) .. "/" .. e.max_hp .. " PV", 0, 4, r.w, 16, 10, Theme.text)
  end
  -- Portrait agrandi (2026-08-27, demande explicite -- "toutes les images des
  -- aventuriers et des ennemis doivent être plus gros") : 46->54.
  draw_enemy_icon(e.template_id, e.icon, e.label, 0, 24, r.w, 54, Theme.text)
  -- Position du corps du télégraphe (voir plus bas) calculée en premier :
  -- le badge de bouclier (2026-08-27, troisième retour explicite -- "ne pas
  -- cacher l'annonce d'attaque, remonter le bouclier pour qu'il soit juste
  -- au-dessus") s'ancre dessus, pas l'inverse -- une seule source de vérité
  -- pour "où commence le télégraphe", jamais deux nombres à resynchroniser à
  -- la main. `- 24` ≈ le rayon visuel du bouclier (DEFENSE_BADGE_R * 0.85)
  -- plus une petite marge, pour que son bord bas touche presque le texte.
  -- `- 38` (était -30) : le corps du télégraphe est plus gros maintenant
  -- (icône/texte agrandis, voir draw_telegraph_body), lui laisse plus de
  -- hauteur avant la bande de cible tout en bas.
  local telegraph_y = r.h - 38
  draw_defense_badge_big(e, r, telegraph_y - 24)
  local parts = enemy_telegraph_parts(controller.state, e)
  if not dead then
    local badges = {}
    -- Sensibilité au feu (2026-08-24, demande explicite) : pas un statut
    -- temporaire (pas de valeur, jamais retiré) -- toujours en tête de rangée
    -- tant que l'Homme Arbre est vivant, voir tooltip_lines pour le texte
    -- complet et Combat.damage_multiplier pour le bonus réel.
    -- Défense retirée de cette rangée (2026-08-27) : affichée à part, en plus
    -- gros, voir draw_defense_badge_big appelé plus haut près du portrait.
    if e.template_id == "homme-arbre" then badges[#badges + 1] = { key = "fireweak", abbr = "FEU" } end
    if (e.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = e.saignements } end
    if (e.incapacite or 0) > 0 then badges[#badges + 1] = { key = "incapacite", abbr = "INC", value = e.incapacite } end
    if (e.vulnerabilite or 0) > 0 then badges[#badges + 1] = { key = "vulnerabilite", abbr = "VUL", value = e.vulnerabilite } end
    draw_badge_row(badges, 0, 82, r.w, 16, Theme.status, controller.status_pop[e.id], controller.status_pop_duration)
    -- Coup télégraphié (2026-08-27, demande explicite -- "retirer le nom de
    -- l'action... seuls les dégâts ou l'effet sont présents" ; nom déplacé
    -- dans l'infobulle, voir tooltip_lines "Action en cours") : plus de titre
    -- ici, seulement le corps (icône de type de dégâts + montant, voir
    -- draw_telegraph_body) -- poussé le plus bas possible, juste au-dessus de
    -- la bande de cible tout en bas (r.h - 12).
    if parts then draw_telegraph_body(parts, telegraph_y, r.w) end
  elseif parts then
    -- Ennemi vaincu : occupe l'espace libéré par la barre de PV absente.
    text(parts.title, 0, 4, r.w, 14, Theme.accent)
  end

  -- Cible télégraphiée (2026-08-24, demande explicite) : tout en bas du
  -- cadre, même traitement que le nom de l'aventurier-propriétaire sur les
  -- cartes (voir draw_card_face) -- fond noir translucide pour rester lisible
  -- même par-dessus les badges de statut juste au-dessus. Couleur de classe de
  -- LA CIBLE (2026-08-24, demande explicite -- avant, rouge fixe Theme.hp),
  -- gardée distincte de la flèche (redevenue rouge fixe, voir
  -- draw_enemy_target_arrows -- risque de confusion avec une action
  -- d'aventurier signalé explicitement).
  if parts and parts.target then
    local target_palette = Theme.card_class[parts.target_class] or Theme.card_class.generic
    set(Theme.black, 0.55)
    love.graphics.rectangle("fill", 0, r.h - 12, r.w, 12)
    text(parts.target, 0, r.h - 11, r.w, 10, target_palette.border)
  end

  draw_shield_fx(controller, e.id, r)
  draw_tooltip_hint(r.w, r.h)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- ---------- main ----------

-- Aperçu dynamique des dégâts (2026-08-09, demande explicite ; réduit au
-- retrait de la Transcendance le 2026-08-11 -- ne reflète plus que
-- Puissance/Incapacité/Vulnérabilité, jamais une classe de héros) : au survol
-- d'un héros pendant qu'une carte est sélectionnée, ses dégâts affichent ce
-- qu'ils VONT valoir si CE héros la joue sur CETTE cible -- ex. Coup direct
-- affiche 5 au lieu de 4 sur une cible Vulnérable. Dérivé des mêmes règles
-- que Combat.deal_damage (Combat.damage_multiplier) : jamais une deuxième
-- copie de la logique de jeu, seule la substitution dans le texte affiché est
-- propre à la vue.
local function scale_near_keyword(text, keyword, factor)
  local out = text
  -- nombre AVANT le mot-clé, ex. `4 "epee"` (Coup direct)
  out = out:gsub('(%d+)(%s+"' .. keyword .. '")', function(num, rest)
    return tostring(Combat.round(tonumber(num) * factor)) .. rest
  end)
  -- nombre APRÈS le mot-clé, ex. `"soin" 2` (Lumière divine)
  out = out:gsub('("' .. keyword .. '"%s+)(%d+)', function(pre, num)
    return pre .. tostring(Combat.round(tonumber(num) * factor))
  end)
  return out
end

-- Mots-clés qui portent un montant de DÉGÂTS (par opposition à "bouclier"/
-- "soin", qui n'entrent jamais dans Combat.damage_multiplier -- rien ne les
-- fait varier avec Puissance/Incapacité/Vulnérabilité).
local DAMAGE_KEYWORDS = { epee = true, etincelle = true, fireball = true }

--- Aperçu du texte d'une carte si `hero` la joue (et, une fois la cible
-- choisie/survolée, `target`) -- réutilise Combat.damage_multiplier (voir
-- combat.lua : Puissance/Incapacité de l'attaquant + Vulnérabilité de la
-- cible additionnés AVANT d'être appliqués, jamais composés en chaîne) pour
-- que l'aperçu et la résolution réelle ne puissent jamais donner un nombre
-- différent. `target` peut être nil (héros pas encore assigné à une cible) --
-- la Vulnérabilité n'entre alors simplement pas encore en compte.
-- `is_fire` : même détection que Combat.deal_damage (def.cats contient "feu"),
-- nécessaire pour que l'aperçu montre déjà le bonus de l'Homme Arbre (2026-08-24)
-- sans attendre la résolution réelle.
local function card_is_fire(def)
  if not def.cats then return false end
  for _, cat in ipairs(def.cats) do
    if cat == "feu" then return true end
  end
  return false
end

local function preview_desc(def, hero, target)
  local text = def.desc
  local dmg_mult = Combat.damage_multiplier(hero, target, def.dmg_type, card_is_fire(def))
  if dmg_mult ~= 1 then
    for kw in pairs(DAMAGE_KEYWORDS) do
      if Glossary.has_keyword(def.desc, kw) then text = scale_near_keyword(text, kw, dmg_mult) end
    end
  end
  return text
end

--- Dessine le contenu plein d'une carte (fond teinté par classe, double contour,
-- pastille de coût, nom en cadre, description) dans l'espace local [0,0]..[w,h] --
-- l'appelant gère push/translate/scale/pop. Partagé entre la main (draw_one
-- ci-dessous) et le vol de cartes pioche/défausse (draw_card_flights) : une carte
-- en plein vol doit avoir exactement le même visage qu'immobile en main, jamais un
-- second rendu qui diverge (voir Theme.card_class).
-- `cost_insufficient`/`mana_insufficient` (2026-08-24, demande explicite,
-- optionnels -- seul l'appel depuis la main, draw_one ci-dessous, les
-- renseigne) : pastille d'énergie/mana en rouge (Theme.hp) au lieu de sa
-- couleur normale quand la réserve globale/la mana du propriétaire ne
-- couvrent plus le coût -- pur retour visuel, ne change rien à la règle déjà
-- appliquée par Combat.can_play/Game.select_card (qui refusent de toute façon
-- la sélection, voir plus bas). La pastille de mana n'existe QUE si
-- `def.mana_cost` est renseigné (cartes du Mage avec un coût de mana, voir
-- cards.lua) -- inexistante sinon, jamais un "0" affiché à tort.
-- `owner_defeated` (2026-08-24, demande explicite, optionnel, même
-- provenance) : voile gris sur TOUTE la carte quand le héros propriétaire est
-- vaincu -- contrairement au rouge ci-dessus (manque temporaire, résoluble au
-- prochain tour), une carte dont le propriétaire est mort ne redeviendra
-- jamais jouable ce combat-ci -- même principe visuel que le voile gris qui
-- couvrait autrefois un héros "a déjà agi" dans draw_hero (retiré 2026-08-20).
local function draw_card_face(def, w, h, cost_text, desc_text, desc_color, highlight, cost_insufficient, mana_insufficient, owner_defeated)
  local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
  panel(0, 0, w, h, palette.bg)
  set(highlight and Theme.accent or Theme.black)
  love.graphics.setLineWidth(highlight and 3 or 2)
  love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
  set(palette.border)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 3, 3, w - 6, h - 6, 8, 8)
  love.graphics.setLineWidth(1)

  set(cost_insufficient and Theme.hp or Theme.energy); love.graphics.circle("fill", 14, 12, 9)
  set(Theme.bg or { 0.05, 0.1, 0.1 })
  love.graphics.setFont(Fonts.get(11)); love.graphics.printf(tostring(cost_text), 4, 6, 20, "center")

  if def.mana_cost then
    set(mana_insufficient and Theme.hp or Theme.mana); love.graphics.circle("fill", 32, 12, 7)
    set(Theme.bg or { 0.05, 0.1, 0.1 })
    love.graphics.setFont(Fonts.get(9))
    love.graphics.printf(tostring(def.mana_cost), 26, 8, 12, "center")
  end

  name_badge(def.name, 2, 22, w - 4, 16, palette.border, Theme.bg, 2, 1)
  RichText.draw(desc_text, 3, 42, w - 6, 10, desc_color or Theme.muted)

  -- Origine de la carte (2026-08-20, demande explicite) : nom de l'aventurier
  -- qui l'a fournie -- lu depuis def.class_id (une classe = un seul héros,
  -- voir Heroes.class_name), pas un champ propre à chaque carte. Fond noir
  -- translucide dessous (même principe que la pastille de coût) pour rester
  -- lisible même si la description déborde jusqu'en bas de la carte. Centré,
  -- police agrandie (2026-08-24, demande explicite -- avant, aligné à droite
  -- en tout petit, 8px). Remonté de 4px (2026-08-24, bug signalé -- flush
  -- avec le bas mangeait le liseré arrondi du cadre) : marge visible sous la
  -- bande pour laisser le contour se voir.
  local hero_name = Heroes.class_name[def.class_id]
  if hero_name then
    set(Theme.black, 0.55)
    love.graphics.rectangle("fill", 0, h - 16, w, 12)
    text(hero_name, 0, h - 15, w, 10, palette.border, "center")
  end

  draw_tooltip_hint(w, h)

  -- Voile gris par-dessus tout le contenu déjà dessiné (cadre compris) quand
  -- le propriétaire est vaincu -- chaque élément ci-dessus fixe sa propre
  -- couleur, un voile en overlay évite de les reprendre un par un (même
  -- traitement que l'ancien "a déjà agi" de draw_hero).
  if owner_defeated then
    set(Theme.black, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h, 10, 10)
  end
end

--- Réserve d'énergie globale (2026-08-11) -- icône du glossaire (même sprite
-- que partout ailleurs où "energie" apparaît, voir Sprites.keyword) + la
-- valeur au format "actuelle / Game.TURN_START_ENERGY" (2026-08-27, demande
-- explicite -- "3/3 au début du premier tour" ; remplace l'affichage sans
-- maximum d'avant -- la réserve peut dépasser ce nombre en cours de tour via
-- certaines cartes, le "/3" reste alors affiché tel quel, comme un repère
-- plutôt qu'un plafond strict). Déplacée à droite de la pioche (2026-08-27,
-- avant : au-dessus). Cadre et contenu agrandis (2026-08-27, deuxième retour
-- explicite -- "trop petit") : icône 11->18px de rayon, texte 16->24px,
-- contour plus épais (2->3) pour rester proportionné au cadre 90x90 (voir
-- View.energy_display_rect).
local function draw_energy_display(state)
  local r = View.energy_display_rect
  panel(r.x, r.y, r.w, r.h, Theme.panel_light)
  set(Theme.energy); love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
  love.graphics.setLineWidth(1)
  local icon = Sprites.keyword("energie")
  if icon then
    love.graphics.setColor(1, 1, 1, 1)
    Sprites.draw_centered(icon, r.x + r.w / 2, r.y + 24, 18)
  end
  text(state.energy .. " / " .. Game.TURN_START_ENERGY, r.x, r.y + 52, r.w, 24, Theme.energy)
end

-- Gros chiffre d'énergie qui CHUTE sur sa pastille en début de tour
-- (2026-08-21, redemandé explicitement -- la version précédente grossissait
-- sur place, jugée pas assez marquante) : apparaît en très grand, tout en
-- haut de la zone de jeu, puis descend et rétrécit jusqu'à se stabiliser
-- exactement sur sa pastille -- une seule courbe (ease_out_back, même que le
-- titre "Victoire !") pilote À LA FOIS l'échelle ET la position verticale,
-- pour que la chute et le rétrécissement restent parfaitement synchronisés et
-- "atterrissent" ensemble (le léger dépassement de la courbe fait rebondir le
-- chiffre juste sous sa place avant de remonter s'y stabiliser -- l'impact
-- attendu d'une chute, pas un bug). Voir Controller:spawn_energy_turn_anim
-- pour le "Woosh" qui accompagne le début de la chute.
local ENERGY_TURN_ANIM_START_SCALE = 8.0
local ENERGY_TURN_ANIM_FALL_HEIGHT = 260 -- px au-dessus de la pastille, départ de la chute
local function draw_energy_turn_anim(controller)
  local a = controller.energy_turn_anim
  if not a then return end
  local r = View.energy_display_rect
  local duration = controller.energy_turn_anim_duration
  local settle = ease_out_back(a.t, duration) -- 0 -> dépasse ~1 -> 1
  local scale = 1 + (ENERGY_TURN_ANIM_START_SCALE - 1) * (1 - settle)
  local cx = r.x + r.w / 2
  local landing_y = r.y + 52 + 12 -- même position que le texte statique de draw_energy_display ci-dessus
  local cy = landing_y - ENERGY_TURN_ANIM_FALL_HEIGHT * (1 - settle)

  local glow_p = math.min(1, a.t / duration)
  set(Theme.energy, 0.35 * (1 - glow_p))
  love.graphics.circle("fill", cx, landing_y, 14 + 46 * glow_p)

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)
  -- Format "actuelle / max" et taille de police (2026-08-27), cohérents avec
  -- draw_energy_display ci-dessus.
  text(a.value .. " / " .. Game.TURN_START_ENERGY, r.x, cy - 10, r.w, 24, Theme.energy)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

--- Pioche/défausse -- effet d'épaisseur quand `count` > 1 : 1 à 2 rectangles
-- décalés en bas-à-droite AVANT le panneau principal, pour suggérer une
-- vraie pile plutôt qu'une case plate. Purement cosmétique : la zone
-- cliquable/hit-test reste `rect` seul, jamais agrandie par les couches
-- décalées (aucun de ces piles n'est d'ailleurs cliquable aujourd'hui, mais
-- le rect sert aussi de référence de position à l'animation de vol des
-- cartes -- voir Controller:animate_draw).
-- Réduite de 50% (2026-08-27, voir PILE_W/PILE_H) : décalage d'épaisseur
-- réduit en proportion (3px -> 2px).
-- Nombre de cartes en texte "LABEL : X" plutôt qu'en pastille colorée
-- (2026-08-27, demande explicite -- la pastille bleue pleine, même teinte
-- que celle du coût en énergie sur les cartes, se lisait à tort comme un
-- coût plutôt qu'un compte de cartes).
local function draw_pile(rect, icon, label, count)
  local layers = math.min(2, math.max(0, count - 1))
  for i = layers, 1, -1 do
    panel(rect.x + i * 2, rect.y + i * 2, rect.w, rect.h, Theme.panel)
  end
  panel(rect.x, rect.y, rect.w, rect.h, Theme.panel_light)
  icon_text(icon, "", rect.x, rect.y + 4, rect.w, 16, Theme.muted)
  -- Nom puis nombre sur 2 lignes, sans ":" (2026-08-27, demande explicite) --
  -- le nombre est le repère le plus lu, mis en évidence par sa propre ligne.
  text(label, rect.x, rect.y + 24, rect.w, 8, Theme.muted)
  text(tostring(count), rect.x, rect.y + 34, rect.w, 13, Theme.text)
  -- Infobulle pioche/défausse (2026-08-21, demande explicite) : le rect reste
  -- non-cliquable (voir note ci-dessus), mais devient survolable pour
  -- l'infobulle -- voir Input.mousemoved et tooltip_lines. draw_tooltip_hint
  -- travaille en espace local [0,0]..[w,h], d'où le push/translate ici (seul
  -- appelant de cette fonction à ne pas déjà être dans ce repère).
  love.graphics.push()
  love.graphics.translate(rect.x, rect.y)
  draw_tooltip_hint(rect.w, rect.h)
  love.graphics.pop()
end

local function draw_hand(controller)
  local state = controller.state
  local rects = View.hand_rects(state)
  draw_energy_display(state)
  draw_energy_turn_anim(controller)
  draw_pile(View.deck_pile_rect, "\u{1F0A0}", "PIOCHE", #state.deck)
  draw_pile(View.discard_pile_rect, "\u{1F5D1}\u{FE0F}", "DEFAUSSE", #state.discard)

  -- Mode "flèche" (2026-08-09) : la carte sélectionnée reste posée en avant
  -- tant qu'elle est en attente, et la carte survolée grossit immédiatement
  -- (pas de délai -- contrairement au tooltip) -- inspiré de Slay the Spire.
  -- Dessinée en deux passes pour que la carte "spéciale" reste au-dessus de
  -- ses voisines une fois agrandie.
  local arrow_mode = controller.input_mode == "arrow"
  local special_uid = arrow_mode and ((state.pending and state.pending.uid) or controller.arrow_hand_hover_uid) or nil

  -- Le fantôme de vol pioche->main est un fondu qui part de rien ; s'il
  -- survole une carte déjà dessinée à pleine opacité à sa position d'arrivée,
  -- on voit la carte "déjà là" pendant que le fantôme la rejoint. Le vrai
  -- rendu de la carte reste donc masqué tant que SON vol d'arrivée n'est pas
  -- terminé (voir Controller:animate_draw, qui pose `uid` sur ces entrées).
  local hiding_uids = {}
  for _, a in ipairs(controller.card_anims) do
    if a.fade_in and a.uid then hiding_uids[a.uid] = true end
  end
  -- Cartes déjà dans state.hand mais dont le vol pioche -> main n'a pas
  -- encore démarré (2026-08-21, bug signalé -- pendant l'attente de l'anim
  -- d'énergie ou d'un remélange défausse -> pioche en cours de pioche) : sans
  -- ça, elles s'affichaient "déjà là" en pleine opacité avant de disparaître
  -- puis revoler depuis la pioche au moment où leur vol démarrait vraiment.
  -- Voir Controller.pending_draw_uids.
  for uid in pairs(controller.pending_draw_uids) do hiding_uids[uid] = true end

  local function draw_one(c, popped)
    local r = rects[c.uid]
    local def = c.def
    local is_pending = state.pending and state.pending.uid == c.uid
    -- Aperçu de dégâts (voir preview_desc ci-dessus) : seulement sur LA carte
    -- sélectionnée. Deux étapes : héros pas encore assigné -> on prévisualise
    -- celui survolé (pas de cible connue, la Vulnérabilité n'entre pas encore
    -- en compte) ; héros déjà assigné et en attente d'une cible -> le héros
    -- est fixé (pending.hero_id), et survoler l'ennemi visé complète l'aperçu
    -- avec SA Vulnérabilité.
    local previewing_hero, previewing_target = nil, nil
    if is_pending and state.pending then
      if state.pending.hero_id then
        previewing_hero = Combat.hero_by_id(state, state.pending.hero_id)
        if controller.hover.kind == "enemy" then previewing_target = Combat.enemy_by_id(state, controller.hover.target) end
      elseif controller.hover.kind == "hero" then
        previewing_hero = Combat.hero_by_id(state, controller.hover.target)
      end
    end
    local desc_text, has_bonus = def.desc, false
    if previewing_hero then
      desc_text = preview_desc(def, previewing_hero, previewing_target)
      has_bonus = desc_text ~= def.desc
    end
    local owner = Combat.hero_by_id(state, def.class_id)
    -- Coût EFFECTIF (2026-08-29, malédiction "Le Corrompu" -- owner.card_cost_delta) :
    -- jamais def.cost brut dès qu'un propriétaire est en jeu -- voir
    -- Combat.effective_cost, seule source de vérité, déjà utilisée par
    -- Combat.can_play/Game.resolve_pending pour la vraie vérification/déduction.
    local cost_text = tostring(Combat.effective_cost(owner, def))
    -- Coût en rouge quand la réserve globale (ou, pour les sorts du Mage, sa
    -- mana) ne couvre plus le coût (2026-08-24, demande explicite) : pur
    -- retour visuel, ne duplique pas la règle -- Combat.can_play/
    -- Game.select_card (voir game.lua) refusent déjà la sélection dans ce cas.
    local cost_insufficient = state.energy < Combat.effective_cost(owner, def)
    local mana_insufficient = def.mana_cost and (not owner or (owner.mana or 0) < def.mana_cost)
    -- Voile gris (2026-08-24, demande explicite) : le propriétaire est vaincu,
    -- cette carte ne redeviendra jouable à aucun prix ce combat-ci -- signal
    -- distinct du rouge ci-dessus (manque temporaire de ressource).
    local owner_defeated = not owner or owner.hp <= 0
    local scale, lift = 1, 0
    if popped then
      -- Grossies (2026-08-27, demande explicite -- "un peu plus grosse au
      -- survol", la carte sélectionnée doit suivre pour rester la plus
      -- grande des deux) : survol 1.1->1.18, sélection 1.16->1.28.
      if is_pending then scale, lift = 1.28, 22 else scale, lift = 1.18, 14 end
    end
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2 - lift)
    love.graphics.scale(scale, scale)
    -- La carte "spéciale" (survolée/sélectionnée) se redresse, comme dans
    -- Slay the Spire -- l'éventail ne concerne que les cartes au repos.
    if not popped and r.fan_angle then love.graphics.rotate(r.fan_angle) end
    love.graphics.translate(-r.w / 2, -r.h / 2)

    -- La sélection (`is_pending`) reste exclusivement signalée par l'or de
    -- Theme.accent sur le contour extérieur, jamais mélangée à la couleur de classe.
    -- Pas de vert "bonus" sur le nom (collision de lisibilité avec l'Assassin, déjà
    -- vert) -- le vert reste porté par la description, qui suffit à signaler
    -- l'aperçu de dégâts.
    draw_card_face(def, r.w, r.h, cost_text, desc_text, has_bonus and Theme.heal or Theme.muted, is_pending, cost_insufficient, mana_insufficient, owner_defeated)
    love.graphics.pop()
  end

  for _, c in ipairs(state.hand) do
    if c.uid ~= special_uid and not hiding_uids[c.uid] then draw_one(c, false) end
  end
  if special_uid and not hiding_uids[special_uid] then
    for _, c in ipairs(state.hand) do
      if c.uid == special_uid then draw_one(c, true); break end
    end
  end
  return rects
end

local function draw_bottom_controls(controller)
  local b1, b2, b4 = View.end_turn_button, View.restart_button, View.restart_turn_button
  -- Bouton carré agrandi (2026-08-24, demande explicite -- "un peu plus gros",
  -- voir END_TURN_BTN_W/H) : centrage vertical approximatif pour un libellé
  -- qui peut retomber sur 2 lignes ("Fin de" / "tour") dans une largeur étroite.
  set(Theme.accent); love.graphics.rectangle("fill", b1.x, b1.y, b1.w, b1.h, 8, 8)
  set(Theme.bg); love.graphics.setFont(Fonts.get(13)); love.graphics.printf(b1.label, b1.x, b1.y + b1.h / 2 - 10, b1.w, "center")
  -- "?" d'infobulle (2026-08-28, demande explicite -- même indice que sur les
  -- autres éléments à infobulle) : Theme.bg (sombre) plutôt que le blanc par
  -- défaut, pour rester lisible sur ce fond doré (voir draw_tooltip_hint).
  love.graphics.push()
  love.graphics.translate(b1.x, b1.y)
  draw_tooltip_hint(b1.w, b1.h, Theme.bg)
  love.graphics.pop()
  -- Boutons rerapetissés (2026-08-24, demande explicite -- encore trop gros) :
  -- police 9 -> 7, centrage vertical ajusté sur la hauteur réduite (voir
  -- RESTART_BTN_W/H).
  set(Theme.muted); love.graphics.rectangle("line", b2.x, b2.y, b2.w, b2.h, 8, 8)
  text(b2.label, b2.x, b2.y + b2.h / 2 - 4, b2.w, 7, Theme.text)
  set(Theme.muted); love.graphics.rectangle("line", b4.x, b4.y, b4.w, b4.h, 8, 8)
  text(b4.label, b4.x, b4.y + b4.h / 2 - 4, b4.w, 7, Theme.text)

  -- Discret à dessein : pas de cadre, texte petit et sombre -- un outil de
  -- test, pas une action de jeu normale. Rejoint la colonne de gauche
  -- (2026-08-27) : même centrage vertical que ses 2 voisins juste au-dessus.
  local b3 = View.instant_victory_button
  text(b3.label, b3.x, b3.y + b3.h / 2 - 4, b3.w, 7, Theme.muted)
end

-- Sélectionner une carte l'assigne directement à son propriétaire (2026-08-20,
-- voir Game.select_card) : plus de phase "choisis l'aventurier" à décrire ici,
-- seulement l'attente d'une cible (pour les cartes qui en ont besoin).
local function hint_text(controller)
  local state = controller.state
  local pending = state.pending
  -- Message par défaut retiré (2026-08-27, demande explicite) : plus rien
  -- affiché tant qu'aucune carte n'est sélectionnée.
  if not pending then return "" end
  -- Carte "sans cible" en attente de confirmation (2026-08-27, voir
  -- Game.assign_hero/Controller:confirm_pending) : un second clic n'importe
  -- où valide, une autre carte de la main échange la sélection.
  if pending.awaiting_confirm_kind then
    return pending.def.name .. " — clique n'importe où pour valider (ou une autre carte pour changer)."
  end
  if controller.input_mode == "arrow" then return pending.def.name .. " — vise la cible." end
  return pending.def.name .. " — choisis la cible."
end

-- ---------- infobulle au survol (1s de délai, comme le prototype) ----------

-- Statuts actifs à lister dans l'infobulle héros/ennemi (2026-08-09, demande
-- explicite : "ajouter l'explication des statuts"). Mêmes champs que les
-- badges déjà affichés (draw_badge_row) -- réutilise les explications déjà
-- écrites dans le glossaire plutôt que d'en dupliquer le texte ; `defense`
-- n'a pas d'entrée dédiée dans le glossaire (seulement le mot-clé de carte
-- "bouclier"), d'où l'explication propre ci-dessous.
-- `hide_value` (2026-08-24, demande explicite -- Camouflé n'est plus un
-- compteur, juste un état présent/absent depuis que la Discrétion l'a
-- remplacé comme ressource graduelle, voir Game.gain_discretion) : n'affecte
-- QUE le texte affiché ("Camouflé" au lieu de "Camouflé 1") -- jamais la
-- détection d'activité elle-même, qui reste `value > 0` pour tous les champs
-- (numériques ici, camoufle compris -- un ancien flag `spec.boolean` faisait
-- ce mélange et aurait affiché la ligne même à camoufle == 0, puisque 0 est
-- "truthy" en Lua -- jamais réellement utilisé, retiré).
local STATUS_TOOLTIP_FIELDS = {
  { field = "defense", glossary_key = "bouclier", label = "Bouclier", explain = "Absorbe les prochains dégâts avant les PV." },
  { field = "esquive", glossary_key = "esquive" },
  { field = "camoufle", glossary_key = "camoufle", hide_value = true },
  { field = "puissance", glossary_key = "puissance" },
  { field = "saignements", glossary_key = "saignement" },
  { field = "incapacite", glossary_key = "incapacite" },
  { field = "vulnerabilite", glossary_key = "vulnerabilite" },
  { field = "provocation", glossary_key = "provocation" },
}

local function active_status_lines(unit)
  local lines = {}
  for _, spec in ipairs(STATUS_TOOLTIP_FIELDS) do
    local value = unit[spec.field]
    local active = type(value) == "number" and value > 0
    if active then
      local g = Glossary.find_term(spec.glossary_key)
      local label = spec.label or (g and (g.label or g.icon)) or spec.field
      local explain = spec.explain or (g and g.explain ~= "" and g.explain) or ""
      local line_text = label .. (spec.hide_value and "" or (" " .. value)) .. (explain ~= "" and (" — " .. explain) or "")
      -- Sprites.status (pas Sprites.keyword/le has_icon du glossaire, qui ne
      -- couvre que le texte de carte) -- ce sont les mêmes icônes déjà visibles
      -- sur les badges de statut de l'encart, pas de nouvel asset à générer.
      local icon = Sprites.status(spec.field)
      lines[#lines + 1] = icon and { text = line_text, icon = icon } or line_text
    end
  end
  return lines
end

local function tooltip_lines(controller)
  local h = controller.hover
  if h.kind == "hero" then
    local hero = Combat.hero_by_id(controller.state, h.target)
    if not hero then return nil end
    -- Description de classe (2026-08-24, demande explicite) : en tête de
    -- l'infobulle, avant les statuts actifs -- voir Heroes.class_description.
    local lines = {}
    local desc = Heroes.class_description[hero.class_id]
    if desc then lines[#lines + 1] = desc end
    -- Bénédiction/malédiction du Temple (2026-08-28/29, demande explicite) :
    -- juste après la description de classe, avant les statuts de combat --
    -- ce sont des effets permanents du run, pas des statuts temporaires (voir
    -- active_status_lines). "Le descriptif s'ajoute à l'infobulle de
    -- l'aventurier" (2026-08-29) : ni l'un ni l'autre n'a de badge cliquable
    -- séparé, cette ligne EST leur seule explication en jeu (voir aussi le
    -- badge sur le cadre, draw_hero, qui pointe ici).
    if hero.blessing then
      local blessing = Temple.by_id(hero.blessing)
      if blessing then lines[#lines + 1] = blessing.name .. " — " .. blessing.desc end
    end
    if hero.curse then
      local curse = Temple.by_id(hero.curse)
      if curse then lines[#lines + 1] = curse.name .. " — " .. curse.desc end
    end
    for _, l in ipairs(active_status_lines(hero)) do lines[#lines + 1] = l end
    return hero.name, lines
  elseif h.kind == "enemy" then
    local e = Combat.enemy_by_id(controller.state, h.target)
    if not e then return nil end
    local template = Enemies.by_id(e.template_id)
    local lines = {}
    -- Nom + niveau (2026-08-27, demande explicite -- retirés du cadre, voir
    -- draw_enemy) : désormais dans le TITRE de l'infobulle (retourné plus bas),
    -- plus dans une ligne "Niveau X" séparée en fin de liste.
    -- "Action en cours" (2026-08-27, demande explicite) : juste sous le
    -- titre nom/niveau -- le nom du coup déjà télégraphié sur le cadre
    -- (draw_enemy/enemy_telegraph_parts), répété ici en toutes lettres.
    if e.next_move then
      lines[#lines + 1] = "Action en cours : " .. e.next_move.name
    end
    -- Sensibilité au feu de l'Homme Arbre (2026-08-24, demande explicite --
    -- "c'est indiqué dans sa description et par une icone dans son cadre") :
    -- avant les coups, même esprit que la description de classe côté héros
    -- (Heroes.class_description) -- voir aussi le badge ajouté dans draw_enemy
    -- et le bonus réel dans Combat.damage_multiplier.
    if e.template_id == "homme-arbre" then
      lines[#lines + 1] = "Sensible au feu : les dégâts de feu infligent +50%."
    end
    for _, m in ipairs(template.moves_info(e.level)) do
      lines[#lines + 1] = m.name .. " — " .. m.text
    end
    for _, l in ipairs(active_status_lines(e)) do lines[#lines + 1] = l end
    lines[#lines + 1] = "PV max " .. e.max_hp
    return e.name .. " Nv." .. e.level, lines
  elseif h.kind == "card" then
    local def = h.target
    local terms = Glossary.keywords_present(def.desc)
    if #terms == 0 then return def.name, { "Aucun mot-clé de glossaire sur cette carte." } end
    local lines = {}
    for _, g in ipairs(terms) do
      local label = g.has_icon and ((g.label or g.key) .. " (" .. g.key .. ")") or g.key
      local related = g.related ~= "" and (" — " .. g.related) or ""
      local line_text = label .. related .. (g.explain ~= "" and (" : " .. g.explain) or "")
      -- table plutôt que string brute quand une icône existe : permet à draw_tooltip
      -- de la dessiner en préfixe de la ligne (voir Sprites.keyword).
      lines[#lines + 1] = g.has_icon and { text = line_text, icon = Sprites.keyword(g.key) } or line_text
    end
    return def.name .. " — mots-clés", lines
  elseif h.kind == "deck" then
    -- Le nombre de cartes est déjà marqué directement sur la pioche elle-même
    -- (2026-08-21, revirement explicite -- pas la peine de le répéter ici) :
    -- l'infobulle ne porte plus que la règle, voir draw_pile.
    return "Pioche", { "Cartes piochées par tour : " .. Deck.HAND_SIZE .. "." }
  elseif h.kind == "discard" then
    return "Défausse", { "Quand la pioche est vide, les cartes de la défausse sont remélangées dans la pioche." }
  elseif h.kind == "end_turn" then
    -- 2026-08-27, demande explicite.
    return "Fin de tour", { "Les cartes restantes en main seront défaussées et cela passe au tour des ennemis." }
  elseif h.kind == "temple_effect" then
    -- Écran "Le Temple" (2026-08-29, demande explicite -- "seul le titre
    -- apparait sous chaque statue... il faut donc ajouter le '?'
    -- conventionnel") : le descriptif complet vit UNIQUEMENT ici.
    local effect = h.target
    return effect.name, { effect.desc }
  end
  return nil
end

-- Nombre de lignes VISUELLES (après retour à la ligne automatique de printf)
-- qu'occupera `str` dans une largeur `avail_w` -- indispensable pour ne pas
-- superposer deux entrées du tooltip quand l'une d'elles est longue et wrap.
local function wrapped_line_count(str, avail_w, size)
  local _, wrapped = Fonts.get(size):getWrap(str, avail_w)
  return math.max(1, #wrapped)
end

-- Canvas réutilisé pour toutes les cartes en vol, à toutes les frames -- créé à la
-- volée (lazy) une seule fois, jamais une allocation de Canvas par carte par frame.
local card_flight_canvas

-- Cartes qui volent de la pioche vers la main (arrivée) ou de la main vers la
-- défausse (départ) -- port de flyGhost()/animateDrawnCards()/animateDiscardedCards()
-- depuis proto-cartes-completes/index.html. Chaque entrée de `controller.card_anims`
-- (voir controller.lua) porte son rect de départ/arrivée déjà calculés -- cette
-- fonction ne fait qu'interpoler et dessiner, jamais de logique de jeu.
-- Affiche désormais la vraie carte (2026-08-10, demande explicite -- "fluidité de
-- l'expérience") via draw_card_face, rendue sur un canvas pour appliquer le fondu
-- d'opacité uniformément (set() ne peut pas multiplier un alpha global sur tous
-- les tracés du dessin de carte) -- plus un simple rectangle-fantôme avec le nom.
local function draw_card_flights(controller)
  for _, a in ipairs(controller.card_anims) do
    if a.elapsed >= a.delay then
      local p = math.min(1, (a.elapsed - a.delay) / a.duration)
      -- "Amnésie" (2026-08-28, demande explicite -- "se disperse en cendre") :
      -- la carte ne VOLE nulle part (`a.dissolve`, voir Controller:
      -- play_amnesie_vanish) -- elle ne rejoint jamais la défausse (voir
      -- state.exhausted dans game.lua), donc pas de destination à animer,
      -- juste un rétrécissement + fondu ACCÉLÉRÉ sur place, synchronisé avec
      -- le burst de cendres (Controller:spawn_ash) dessiné par-dessus.
      if a.dissolve then
        local ease = p * p -- easeInQuad : démarre lentement, s'effondre vers la fin
        local scale = 1 - 0.35 * ease
        local alpha = 1 - ease
        local cx, cy = a.from.x + a.from.w / 2, a.from.y + a.from.h / 2
        local w, h = a.from.w * scale, a.from.h * scale
        if a.def then
          card_flight_canvas = card_flight_canvas or love.graphics.newCanvas(CARD_W, CARD_H)
          love.graphics.setCanvas(card_flight_canvas)
          love.graphics.clear(0, 0, 0, 0)
          draw_card_face(a.def, CARD_W, CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
          love.graphics.setCanvas()
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.draw(card_flight_canvas, cx - w / 2, cy - h / 2, 0, w / CARD_W, h / CARD_H)
        end
        goto continue
      end
      -- Petit rebond d'arrivée sur la pioche (2026-08-21, demande explicite) :
      -- ease_out_back (même courbe que le titre "Victoire !") dépasse
      -- légèrement 1 avant de s'y stabiliser -- la carte "atterrit" dans la
      -- main plutôt que de simplement s'arrêter. La défausse garde l'ancienne
      -- décélération simple (easeOutQuad), moins de raison d'y mettre du jeu.
      local ease = a.fade_in and ease_out_back(a.elapsed - a.delay, a.duration)
        or (1 - (1 - p) ^ 2) -- easeOutQuad, approxime le cubic-bezier CSS du prototype
      local x = a.from.x + (a.to.x - a.from.x) * ease
      local y = a.from.y + (a.to.y - a.from.y) * ease
      local w = a.from.w + (a.to.w - a.from.w) * ease
      local h = a.from.h + (a.to.h - a.from.h) * ease
      local alpha = a.fade_in and math.min(1, p * 1.6) or (1 - p * 0.8)
      if a.def then
        card_flight_canvas = card_flight_canvas or love.graphics.newCanvas(CARD_W, CARD_H)
        love.graphics.setCanvas(card_flight_canvas)
        love.graphics.clear(0, 0, 0, 0)
        draw_card_face(a.def, CARD_W, CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
        love.graphics.setCanvas()
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(card_flight_canvas, x, y, 0, w / CARD_W, h / CARD_H)
      else
        -- Silhouette simple sans face précise (2026-08-21, cas volontaire
        -- désormais -- voir Controller:animate_reshuffle : les "fantômes" du
        -- remélange défausse -> pioche sont des cartes anonymes, en montrer
        -- une face précise serait trompeur pour un tas qui repart mélangé).
        set(Theme.panel_light, alpha)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
      end
      ::continue::
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- Nombre de dégâts/soin flottant (2026-08-09, party "amélioration des
-- visuels") : monte et s'estompe depuis Controller:spawn_floater, couleur
-- selon le sens (dégâts/soin) -- pas de logique de jeu ici, juste l'interpolation.
local FLOATER_RISE = 34
-- "discretion" (2026-08-28, demande explicite) : même famille visuelle que
-- "heal" (traitement par défaut, voir draw_floaters plus bas), juste une
-- teinte propre (Theme.discretion, déjà celle du texte "DISCR N" sous le
-- portrait) pour qu'un flottant de Discrétion ne se confonde jamais avec un
-- vrai soin.
local FLOATER_COLOR = { damage = "hp", heal = "heal", discretion = "discretion" }
-- Retour du porteur de projet (2026-08-09) : les dégâts doivent taper plus
-- fort visuellement -- police nettement plus grosse + un zoom qui dépasse puis
-- se stabilise (ease_out_back, déjà utilisé pour le titre "Victoire !", pas
-- une nouvelle courbe).
-- Agrandi 15 -> 22 (2026-08-28, demande explicite -- soin de la bénédiction du
-- Temple, "un FX en vert, assez gros, qui remonte en fade") : même flottant
-- que tout autre soin (Controller:spawn_floater ne distingue pas la source),
-- jamais un second mécanisme dédié à ce seul cas -- profite donc à toute
-- récupération de PV affichée en combat, pas seulement celle du Temple.
local DAMAGE_FLOATER_SIZE = 26
local HEAL_FLOATER_SIZE = 22
local DAMAGE_ZOOM_DURATION = 0.22

local function draw_floaters(controller)
  for _, f in ipairs(controller.floaters) do
    local p = math.min(1, f.t / controller.floater_duration)
    local ease = 1 - (1 - p) ^ 2
    local y = f.y - ease * FLOATER_RISE
    local alpha = 1 - p * p
    set(Theme[FLOATER_COLOR[f.kind]] or Theme.text, alpha)
    if f.kind == "damage" then
      local zoom = ease_out_back(f.t, DAMAGE_ZOOM_DURATION)
      love.graphics.setFont(Fonts.get(DAMAGE_FLOATER_SIZE))
      love.graphics.push()
      love.graphics.translate(f.x, y)
      love.graphics.scale(zoom, zoom)
      love.graphics.printf(f.text, -40, -DAMAGE_FLOATER_SIZE / 2, 80, "center")
      love.graphics.pop()
    else
      love.graphics.setFont(Fonts.get(HEAL_FLOATER_SIZE))
      love.graphics.printf(f.text, f.x - 40, y, 80, "center")
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Petit burst de pixels à l'impact (2026-08-09) : quelques carrés qui giclent
-- et retombent légèrement avant de s'estomper -- volontairement fait à la
-- main (pas de love.graphics.ParticleSystem, pas de nouvel asset), pour
-- rester dans l'esprit pixel art plutôt que d'y superposer un vrai système de
-- particules (garde-fou explicite : rester simple, ne pas noyer le style).
-- `pt.color`/`pt.gravity` (optionnels, 2026-08-28, demande explicite -- même
-- liste/mêmes champs réutilisés pour les cendres d'"Amnésie", voir
-- Controller:spawn_ash) : replis sur le burst d'impact rouge d'origine
-- (Theme.hp, gravité qui fait retomber) quand absents, jamais un 2ᵉ système
-- de particules parallèle pour un simple changement de couleur/trajectoire.
local PARTICLE_GRAVITY = 160

local function draw_particles(controller)
  for _, pt in ipairs(controller.particles) do
    local p = math.min(1, pt.t / controller.particle_duration)
    local gravity = pt.gravity or PARTICLE_GRAVITY
    local x = pt.x + pt.vx * pt.t
    local y = pt.y + pt.vy * pt.t + 0.5 * gravity * pt.t * pt.t
    set(pt.color or Theme.hp, 1 - p)
    love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function draw_tooltip(controller)
  -- Retour du porteur de projet (2026-08-09) : la fenêtre d'infobulle gâchait
  -- la lecture du combat pendant le ciblage -- une carte sélectionnée (choix de
  -- l'aventurier ou de la cible en cours) suspend l'infobulle entièrement,
  -- quel que soit le mode d'entrée (tap ou flèche).
  if controller.state.pending then return end
  if not controller:hover_ready() then return end
  local title, lines = tooltip_lines(controller)
  if not title then return end
  local mx, my = love.mouse.getPosition()
  mx, my = mx / SCALE, my / SCALE
  local w = 240
  local line_h = 14

  local wrapped_counts = {}
  for i, line in ipairs(lines) do
    local str, avail_w
    if type(line) == "table" then
      str, avail_w = line.text, w - (line.icon and 24 or 8) - 8
    else
      str, avail_w = line, w - 16
    end
    wrapped_counts[i] = wrapped_line_count(str, avail_w, 9)
  end
  local total_lines = 0
  for _, c in ipairs(wrapped_counts) do total_lines = total_lines + c end

  local h = 20 + line_h * total_lines
  local x = math.min(mx + 14, W - w - 8)
  local y = math.max(8, my - h - 10)
  panel(x, y, w, h, Theme.panel_light)
  set(Theme.status); love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, 8, 8)
  text(title, x + 8, y + 6, w - 16, 10, Theme.status, "left")
  local ly = y + 20
  for i, line in ipairs(lines) do
    if type(line) == "table" then
      local text_x = x + 8
      if line.icon then
        love.graphics.setColor(1, 1, 1, 1)
        Sprites.draw_centered(line.icon, x + 14, ly + 5, 7)
        text_x = x + 24
      end
      text(line.text, text_x, ly, w - (text_x - x) - 8, 9, Theme.text, "left")
    else
      text(line, x + 8, ly, w - 16, 9, Theme.text, "left")
    end
    ly = ly + line_h * wrapped_counts[i]
  end
end


-- Flèche dynamique (mode "flèche", 2026-08-09 ; simplifiée 2026-08-20 -- la
-- carte assigne directement son propriétaire, plus de choix de héros à
-- l'arc) : du propriétaire vers la cible finale, si la carte en a besoin --
-- couleur dérivée des mêmes conditions d'éligibilité que les cadres verts/
-- bleus déjà en place (cible vivante), jamais une logique de validité dupliquée.
local function quad_bezier(t, x0, y0, cx, cy, x1, y1)
  local mt = 1 - t
  return mt * mt * x0 + 2 * mt * t * cx + t * t * x1,
    mt * mt * y0 + 2 * mt * t * cy + t * t * y1
end

local function quad_bezier_tangent(t, x0, y0, cx, cy, x1, y1)
  local mt = 1 - t
  return 2 * mt * (cx - x0) + 2 * t * (x1 - cx),
    2 * mt * (cy - y0) + 2 * t * (y1 - cy)
end

--- Chaîne courbe de petits maillons plutôt qu'un trait droit (2026-08-09,
-- retour esthétique du porteur de projet, référence visuelle façon Slay the
-- Spire) : courbe de Bézier quadratique (cambrure + léger balancement dans le
-- temps pour un effet "vivant"), maillons = petits rectangles arrondis
-- orientés sur la tangente locale de la courbe, pointe à l'arrivée orientée
-- pareil (pas sur le segment droit origine->souris).
-- `tip_angle` (optionnel, radians) : impose l'orientation de la pointe (et donc du
-- point de base sur lequel se cale la chaîne) au lieu de la déduire de la tangente
-- d'arrivée -- utile quand la direction réelle est connue d'avance et fixe (2026-08-10,
-- flèche de télégraphe ennemi : les ennemis sont toujours au-dessus des aventuriers
-- dans la mise en page, "vers le bas" est donc toujours correct, indépendamment de la
-- cambrure de la courbe qui peut faire dévier l'angle tangent calculé).
-- `bow_up` (optionnel, 2026-08-24, demande explicite -- flèche ennemi->cible
-- pas belle en courbure vers le bas) : force la cambrure du côté du HAUT de
-- l'écran (y plus petit), quel que soit le signe de dx -- sans ça, la
-- perpendiculaire naturelle (-dy, dx) bascule de côté selon que la cible est
-- à gauche ou à droite de l'origine (dy restant petit -- rangées ennemis/
-- héros proches -- c'est dx qui domine la direction du segment, donc de la
-- cambrure), ce qui donnait tantôt une courbe vers le haut tantôt vers le bas
-- selon la disposition. Seul draw_enemy_target_arrows l'active ; la flèche de
-- ciblage du joueur (mousepressed/draw_targeting_arrow) garde son
-- comportement naturel, jamais concernée.
-- `bow_bias` (optionnel, px, 2026-08-27, demande explicite -- "que les
-- flèches se chevauchent le moins possible") : ajouté tel quel à la cambrure
-- calculée, pour qu'un appelant qui dessine PLUSIEURS flèches dans la même
-- zone (voir draw_enemy_target_arrows) puisse les décaler légèrement les
-- unes des autres plutôt que de toutes suivre exactement la même courbe.
local function draw_arrow(x1, y1, x2, y2, color, tip_angle, bow_up, bow_bias)
  local dx, dy = x2 - x1, y2 - y1
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then return end

  local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
  local nx, ny = -dy / dist, dx / dist
  if bow_up and ny > 0 then nx, ny = -nx, -ny end
  local bow = math.min(dist * 0.22, 70) + math.sin(love.timer.getTime() * 3) * math.min(dist * 0.03, 8) + (bow_bias or 0)
  local cx, cy = mx + nx * bow, my + ny * bow

  -- Recul de la chaîne (2026-08-10, signalé par le porteur de projet -- deux essais
  -- précédents ratés : un `t_end` en ligne droite qui ne suit pas fidèlement la
  -- cambrure, puis un filtre par distance dont la zone d'exclusion circulaire autour
  -- de la pointe n'est pas alignée avec l'axe du triangle sur une courbe qui s'incurve
  -- -- le dernier maillon survivant pouvait se retrouver décalé sur le côté au lieu de
  -- viser franchement la base). Solution correcte : calculer l'angle d'arrivée puis LE
  -- POINT DE LA BASE du triangle (reculé de `arrow_reach` le long de cet axe) AVANT de
  -- dessiner les maillons, et faire terminer la courbe de la chaîne pile sur ce point
  -- (pas sur la pointe x2,y2) -- son dernier maillon (t=1) tombe alors exactement sur
  -- la base, tangente comprise, quelle que soit la cambrure. `arrow_size` = même valeur
  -- que le triangle dessiné plus bas (une seule source).
  local etx, ety = quad_bezier_tangent(1, x1, y1, cx, cy, x2, y2)
  local end_angle = tip_angle or math.atan(ety, etx)
  local arrow_size = 12
  local arrow_reach = arrow_size * math.cos(math.rad(30))
  local bx = x2 - arrow_reach * math.cos(end_angle)
  local by = y2 - arrow_reach * math.sin(end_angle)

  set(color)
  local link_size = 9
  local steps = math.max(4, math.floor(dist / 16))
  for i = 0, steps do
    local t = i / steps
    local px, py = quad_bezier(t, x1, y1, cx, cy, bx, by)
    local tx, ty = quad_bezier_tangent(t, x1, y1, cx, cy, bx, by)
    local scale = 0.55 + 0.45 * t -- maillons plus petits près de l'origine, comme une queue
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.rotate(math.atan(ty, tx))
    love.graphics.rectangle("fill", -link_size * scale / 2, -link_size * scale * 0.35, link_size * scale, link_size * scale * 0.7, 3, 3)
    love.graphics.pop()
  end

  local a1, a2 = end_angle + math.rad(150), end_angle - math.rad(150)
  love.graphics.polygon("fill",
    x2, y2,
    x2 + arrow_size * math.cos(a1), y2 + arrow_size * math.sin(a1),
    x2 + arrow_size * math.cos(a2), y2 + arrow_size * math.sin(a2))
end

--- Flèche du télégraphe ennemi (2026-08-10, demande explicite) : indique quel
-- aventurier une attaque ennemie va toucher, avec le même style "chaîne animée" que
-- draw_arrow ci-dessus (réutilisée telle quelle -- jamais un second dessin de flèche
-- qui diverge). Rouge fixe (Theme.hp, 2026-08-24 -- revenu en arrière après un essai
-- en couleur de classe de la cible : trop proche des couleurs d'action d'un
-- aventurier, risque de confusion "ceci vient d'un aventurier" -- signalé
-- explicitement) : le rouge dit sans ambiguïté "menace ennemie", jamais une
-- couleur de classe. La bande de nom en bas du cadre ennemi (voir draw_enemy),
-- elle, reste en couleur de classe de la cible -- pas concernée par cette
-- correction, jamais signalée comme un problème. Rien si l'ennemi est mort,
-- n'a pas de coup télégraphié, si son coup ne cible personne (kind hors
-- Combat.TARGETABLE_MOVE_KINDS -- soin, buff...), ou si la cible n'est plus
-- vivante -- jamais vers un autre ennemi, le ciblage ennemi ne vise que des
-- aventuriers (`target_hero_id`, voir encounter.lua).
-- Points d'arrivée décalés + cambrures variées (2026-08-27, demande explicite
-- -- "ne pas se superposer"/"se chevaucher le moins possible") : avant,
-- toutes les flèches visant le même aventurier atterrissaient exactement au
-- même pixel (centre du cadre) et suivaient exactement la même courbe.
-- Corrigé en 2 temps :
-- 1. Regroupées par cible, décalées en éventail sur l'axe X du point
--    d'arrivée -- ordonnées par la position X de l'ennemi SOURCE (le plus à
--    gauche atterrit le plus à gauche) pour ne pas ajouter de croisement
--    entre flèches qui partagent déjà la même cible.
-- 2. Chaque flèche reçoit en plus un léger biais de cambrure (bow_bias, voir
--    draw_arrow), dérivé de son rang global parmi toutes les flèches
--    affichées -- réduit aussi le chevauchement entre flèches de cibles
--    DIFFÉRENTES, qui ne partagent aucun point commun mais pouvaient
--    auparavant suivre des courbes quasi identiques si leurs origines/
--    destinations étaient proches.
local function draw_enemy_target_arrows(controller)
  local state = controller.state
  local enemy_rects = View.enemy_rects(state)
  local hero_rects = View.hero_rects(state)

  local targeting = {}
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 and e.next_move and Combat.TARGETABLE_MOVE_KINDS[e.next_move.kind] and e.target_hero_id then
      local target = Combat.hero_by_id(state, e.target_hero_id)
      if target and target.hp > 0 and enemy_rects[e.id] and hero_rects[target.id] then
        targeting[#targeting + 1] = { enemy = e, target = target }
      end
    end
  end
  if #targeting == 0 then return end

  local by_target = {}
  for _, t in ipairs(targeting) do
    local list = by_target[t.target.id]
    if not list then list = {}; by_target[t.target.id] = list end
    list[#list + 1] = t
  end
  for _, list in pairs(by_target) do
    table.sort(list, function(a, b) return enemy_rects[a.enemy.id].x < enemy_rects[b.enemy.id].x end)
  end

  local ARRIVAL_SPACING = 14
  local BOW_BIAS_STEP = 7
  for i, t in ipairs(targeting) do
    local e, target = t.enemy, t.target
    local er, hr = enemy_rects[e.id], hero_rects[target.id]
    local list = by_target[target.id]
    local idx = 1
    for j, item in ipairs(list) do if item.enemy.id == e.id then idx = j end end
    local arrival_offset = (idx - (#list + 1) / 2) * ARRIVAL_SPACING
    local bow_bias = (i - (#targeting + 1) / 2) * BOW_BIAS_STEP
    draw_arrow(
      er.x + er.w / 2, er.y + er.h, hr.x + hr.w / 2 + arrival_offset, hr.y,
      Theme.hp, math.pi / 2, true, bow_bias
    )
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Sélectionner une carte l'assigne DIRECTEMENT à son propriétaire (2026-08-20,
-- voir Game.select_card) : `pending` n'existe donc jamais sans `pending.hero_id`
-- déjà fixé -- plus de "flèche main -> aventurier" pendant un choix de héros,
-- seulement la flèche aventurier -> cible finale (ennemi/allié) ci-dessous.
local function draw_targeting_arrow(controller)
  if controller.input_mode ~= "arrow" or controller.screen ~= "playing" then return end
  local state = controller.state
  local pending = state.pending
  if not pending or not pending.hero_id then return end
  if pending.def.target ~= "enemy" and pending.def.target ~= "ally" and pending.def.target ~= "conditional" then return end

  local mx, my = love.mouse.getPosition()
  mx, my = mx / SCALE, my / SCALE

  local origin = View.hero_rects(state)[pending.hero_id]
  if not origin then return end
  local ox, oy = origin.x + origin.w / 2, origin.y + origin.h / 2
  local valid = false
  if pending.def.target == "enemy" or pending.def.target == "conditional" then
    for _, e in ipairs(state.enemies) do
      local r = View.enemy_rects(state)[e.id]
      if r and e.hp > 0 and point_in(r, mx, my) then valid = true end
    end
  end
  if pending.def.target == "ally" then
    for _, h in ipairs(state.heroes) do
      if h.id ~= pending.hero_id then
        local r = View.hero_rects(state)[h.id]
        if r and h.hp > 0 and point_in(r, mx, my) then valid = true end
      end
    end
  end
  draw_arrow(ox, oy, mx, my, valid and Theme.heal or Theme.energy)
end

-- ---------- forge / temple (post-combat) ----------

--- Carte pleine face en fondu à une opacité donnée (2026-08-11, animation de
-- choix d'amélioration, voir draw_forge) : `set(color, alpha)` ne peut PAS
-- porter un fondu uniforme sur les multiples tracés de draw_card_face
-- (panneau, contour, badge, texte...), donc même détour par canvas que
-- draw_card_flights ci-dessus (réutilise le même `card_flight_canvas`, jamais
-- deux canvas pour le même usage). `desc_color`/`highlight` (optionnels,
-- 2026-08-28 -- avant, cette fonction ne servait qu'à faire disparaître la
-- carte de BASE en Theme.muted/non mise en avant ; la Forge à 4 cartes fait
-- maintenant disparaître des cartes déjà "+"/mises en avant, donc le style
-- doit pouvoir suivre) : mêmes défauts qu'avant si omis.
local function draw_faded_card(def, x, y, alpha, desc_color, highlight)
  card_flight_canvas = card_flight_canvas or love.graphics.newCanvas(CARD_W, CARD_H)
  love.graphics.setCanvas(card_flight_canvas)
  love.graphics.clear(0, 0, 0, 0)
  draw_card_face(def, CARD_W, CARD_H, def.cost, def.desc, desc_color or Theme.muted, highlight or false)
  love.graphics.setCanvas()
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(card_flight_canvas, x, y)
  love.graphics.setColor(1, 1, 1, 1)
end

--- Version "+" à afficher pour `def` -- protège contre un double-suffixe
-- (2026-08-28) : la carte CHOISIE a déjà son `instance.def` remplacé par
-- Forge.apply_upgrade au moment où ce module la dessine encore une fois pour
-- l'anim de fondu des autres (voir draw_forge) -- Cards.upgraded_def sur un
-- def déjà "+" (is_upgraded) doublerait le suffixe " +", donc on renvoie le
-- def tel quel dans ce cas plutôt que de le repasser par Cards.upgraded_def.
local function forge_preview_def(def)
  return def.is_upgraded and def or Cards.upgraded_def(def)
end

--- Écran "La Forge" (2026-08-28, demande explicite -- remplace l'ancien
-- panneau "Forge" de feuDeCamp, voir Controller:enter_forge_screen pour le
-- tirage, fait une seule fois à l'entrée sur l'écran) : jusqu'à 4 cartes en
-- rangée, chacune DÉJÀ montrée dans sa version améliorée -- contrairement à
-- l'ancien panneau à 2 cartes (base -> flèche -> "+"), comparer base et
-- améliorée pour 4 cartes à la fois ne tient plus sur la largeur de l'écran ;
-- seule "ce que la carte va devenir" reste affichée. Clic sur une carte : les
-- 3 autres s'effacent en fondu (voir Controller:choose_forge_card/
-- forge_upgrade_anim), celle choisie reste affichée seule, sans déplacement
-- (contrairement à l'ancien panneau qui recentrait la carte choisie -- plus
-- la place pour ça à 4 cartes).
local function draw_forge(controller)
  local f = controller.forge
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  text("La Forge", 0, 60, W, 24, Theme.text)

  if #f.choices == 0 then
    text("Toutes vos cartes sont déjà améliorées.", 0, 92, W, 12, Theme.muted)
    local b = View.forge_skip_button
    set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    set(Theme.bg); text(b.label, b.x, b.y + 14, b.w, 14, Theme.bg)
    return
  end

  text("Choisis une carte à améliorer.", 0, 92, W, 12, Theme.muted)
  local rects = View.forge_card_rects(controller)
  local anim = controller.forge_upgrade_anim
  for i, instance in ipairs(f.choices) do
    local r = rects[i]
    local preview_def = forge_preview_def(instance.def)
    if anim and anim.chosen_index ~= i then
      local p = math.min(1, anim.t / (controller.forge_upgrade_anim_duration or 1))
      local alpha = 1 - p
      if alpha > 0 then draw_faded_card(preview_def, r.x, r.y, alpha, Theme.text, true) end
    else
      love.graphics.push()
      love.graphics.translate(r.x, r.y)
      draw_card_face(preview_def, CARD_W, CARD_H, preview_def.cost, preview_def.desc, Theme.text, true)
      love.graphics.pop()
    end
  end
end

--- Écran "Le Temple" (2026-08-29, refonte complète -- demande explicite,
-- remplace la statue unique "pot difforme + fleur" par une statue PAR EFFET
-- proposé -- voir Icons.draw_status("temple_blessing"/"temple_curse")) :
-- jusqu'à 3 statues d'effet (toujours du même type, bénédiction OU
-- malédiction -- tiré une fois à l'entrée sur l'écran, voir
-- Controller:enter_temple_screen) en ligne au-dessus des 4 aventuriers.
-- Choix obligatoire ("il ne peut pas ne pas choisir") : aucun "Passer" sur
-- cet écran -- le joueur clique 1 statue ET 1 aventurier, dans l'ordre qu'il
-- veut, puis confirme (voir Controller:choose_temple_effect/
-- choose_temple_hero/confirm_temple_choice). Seul le TITRE de chaque effet
-- apparaît sous sa statue (2026-08-29, demande explicite) : le descriptif
-- complet est dans l'infobulle au survol (le "?" conventionnel).
local function draw_temple(controller)
  local t = controller.temple
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  local type_label = t.type == "blessing" and "bénédiction" or "malédiction"
  local icon_key = t.type == "blessing" and "temple_blessing" or "temple_curse"
  text("Le Temple", 0, 26, W, 20, Theme.text)

  local anim = controller.temple_choice_anim
  local effect_rects = View.temple_effect_rects(controller)
  for i, effect in ipairs(t.choices) do
    local r = effect_rects[i]
    local color = TEMPLE_STATUE_COLORS[effect.color] or Theme.accent
    local selected = t.chosen_effect_index == i
    local alpha = 1
    if anim and anim.chosen_index ~= i then
      local p = math.min(1, anim.t / (controller.temple_choice_anim_duration or 1))
      alpha = 1 - p
    end
    if alpha > 0 then
      set(Theme.panel_light, alpha)
      love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
      set(selected and Theme.accent or color, alpha)
      love.graphics.setLineWidth(selected and 4 or 2)
      love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
      love.graphics.setLineWidth(1)
      Icons.draw_status(icon_key, r.x + r.w / 2, r.y + 55, 38, color, alpha)
      set(Theme.text, alpha)
      text(effect.name, r.x + 4, r.y + r.h - 28, r.w - 8, 12, Theme.text)
      if not anim then
        love.graphics.push()
        love.graphics.translate(r.x, r.y)
        draw_tooltip_hint(r.w, r.h, Theme.text)
        love.graphics.pop()
      end
    end
  end

  if anim then
    local hero
    for _, h in ipairs(t.eligible) do if h.id == t.chosen_hero_id then hero = h end end
    text("Bonne chance, " .. (hero and hero.name or "?") .. " !", 0, TEMPLE_EFFECT_Y + TEMPLE_EFFECT_H + 14, W, 13, Theme.accent)
  else
    text("Choisis l'élu de cette " .. type_label .. " !", 0, TEMPLE_EFFECT_Y + TEMPLE_EFFECT_H + 14, W, 12, Theme.muted)
  end

  local hero_rects = View.temple_hero_rects(controller)
  for _, h in ipairs(controller.state.heroes) do
    local r = hero_rects[h.id]
    local eligible = false
    for _, e in ipairs(t.eligible) do if e.id == h.id then eligible = true end end
    local selected = t.chosen_hero_id == h.id
    panel(r.x, r.y, r.w, r.h, eligible and Theme.panel_light or Theme.panel)
    set(selected and Theme.accent or (eligible and Theme.accent or Theme.muted))
    love.graphics.setLineWidth(selected and 4 or 2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    local portrait_size = 70
    draw_class_icon(h.class_id, h.icon, h.label,
      r.x + (r.w - portrait_size) / 2, r.y + 14, portrait_size, portrait_size,
      eligible and Theme.text or Theme.muted)
    local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
    name_badge(h.name, r.x + 8, r.y + 90, r.w - 16, 12, palette.border, Theme.bg, 2, 3)
    if h.hp <= 0 then
      text("Mort", r.x, r.y + 112, r.w, 11, Theme.muted)
    elseif not eligible then
      text(t.type == "blessing" and "Déjà béni" or "Déjà maudit", r.x, r.y + 112, r.w, 11, Theme.muted)
    end
  end

  if not anim then
    local b = View.temple_confirm_button
    local can_confirm = t.chosen_effect_index and t.chosen_hero_id
    set(can_confirm and Theme.accent or Theme.panel_light)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    text(b.label, b.x, b.y + 14, b.w, 14, can_confirm and Theme.bg or Theme.muted)
  end
end

-- Bouton plein, contour doré, texte centré (2026-08-21, demande explicite --
-- menu/en travaux/options) : même style pour les 3 écrans, jamais un rendu
-- dupliqué par écran.
local function draw_menu_style_button(b)
  set(Theme.panel_light)
  love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 10, 10)
  set(Theme.accent); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 10, 10)
  love.graphics.setLineWidth(1)
  text(b.label, b.x, b.y + b.h / 2 - 8, b.w, 16, Theme.text, "center")
end

-- Menu principal (2026-08-21, demande explicite) : pas de fond dédié pour
-- l'instant ("il y aura un background mais pas pour l'instant") -- même
-- dégradé procédural par défaut que le combat (voir Background.draw,
-- `enemies = nil` retombe sur BIOMES.defaut), pas un écran vide.
local function draw_menu(controller)
  Background.draw(nil, W, H)
  text("Hero Card Game", 0, 90, W, 30, Theme.text)
  text("Run Infini", 0, 130, W, 14, Theme.muted)
  for _, b in ipairs(View.menu_buttons) do draw_menu_style_button(b) end
end

local function draw_options(controller)
  Background.draw(nil, W, H)
  text("Pas d'options pour le moment", 0, H / 2 - 60, W, 20, Theme.text)
  draw_menu_style_button(View.back_button)
end

-- Victoire sur le boss (2026-08-21, demande explicite -- "il faut enlever le
-- draft de carte et le feu de camp après le boss") : ni draft ni feu de camp
-- après ce combat-là, juste ce bref titre (même zoom que "Victoire !" côté
-- draft, voir controller.victory_anim/victory_title_duration) avant le retour
-- automatique au menu (Controller:enter_boss_victory).
local function draw_boss_victory(controller)
  Background.draw(nil, W, H)
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  local va = controller.victory_anim
  local title_scale = va and ease_out_back(va.t, controller.victory_title_duration) or 1
  love.graphics.push()
  love.graphics.translate(W / 2, H / 2 - 20)
  love.graphics.scale(title_scale, title_scale)
  love.graphics.translate(-W / 2, -(H / 2 - 20))
  text("Victoire !", 0, H / 2 - 32, W, 24, Theme.text)
  love.graphics.pop()
  text("Le Boss est vaincu !", 0, H / 2 + 10, W, 14, Theme.muted)
end

function View.draw(controller)
  if controller.screen == "menu" then draw_menu(controller); return end
  if controller.screen == "options" then draw_options(controller); return end
  if controller.screen == "bossVictory" then draw_boss_victory(controller); return end

  local state = controller.state
  Background.draw(state.enemies, W, H)

  -- Titre "Hero Card Game — Run Infini" retiré (2026-08-27, demande explicite) :
  -- redondant en plein combat, déjà affiché sur l'écran de menu (draw_menu).
  text("Combat " .. state.run.combat_index .. " — Tour " .. state.turn, 0, 30, W, 11, Theme.muted)

  text("Ennemis", 20, 40, 200, 10, Theme.muted, "left")
  for _, e in ipairs(state.enemies) do draw_enemy(controller, e, View.enemy_rects(state)[e.id]) end

  text("Ta troupe", 20, HERO_ROW_Y - 14, 200, 10, Theme.muted, "left")
  for _, h in ipairs(state.heroes) do draw_hero(controller, h, View.hero_rects(state)[h.id]) end

  draw_enemy_target_arrows(controller)

  -- Fenêtre de log retirée pour l'instant (2026-08-08, demande explicite -- l'espace
  -- gagné sert à séparer visuellement la troupe des ennemis, voir HERO_ROW_Y ci-dessus).
  -- `state.log` continue d'être alimenté côté règles, juste plus affiché ici.

  draw_hand(controller)
  draw_bottom_controls(controller)
  text(hint_text(controller), 0, 632, W, 10, Theme.muted)

  if controller.screen == "defeat" then
    set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
    text("Défaite…", 0, H / 2 - 40, W, 26, Theme.text)
    -- Toujours au pluriel, jamais "(s)" (2026-08-21, demande explicite -- "je
    -- déteste ça... il faut toujours choisir la version pluriel, quitte à
    -- écrire des erreurs comme '1 chevaux'") : accepte l'accord fautif à 1
    -- combat plutôt que la parenthèse.
    text("Le run s'arrête après " .. combats_won_text(controller) .. " combats remportés.", 0, H / 2, W, 12, Theme.muted)
    local b = View.overlay_restart_button
    set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    set(Theme.bg); text(b.label, b.x, b.y + 9, b.w, 12, Theme.bg)
  elseif controller.screen == "draft" and controller.draft_picks then
    set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)

    -- Titre "Victoire !" en zoom + bump (2026-08-08) : seul élément affiché
    -- au tout début de l'écran de draft, avant même que les cartes existent
    -- visuellement -- voir Controller:enter_draft_screen pour le séquencement.
    local va = controller.victory_anim
    local title_scale = va and ease_out_back(va.t, controller.victory_title_duration) or 1
    love.graphics.push()
    love.graphics.translate(W / 2, 72)
    love.graphics.scale(title_scale, title_scale)
    love.graphics.translate(-W / 2, -72)
    text("Victoire !", 0, 60, W, 24, Theme.text)
    love.graphics.pop()

    if controller.draft_cards_shown then
      text("Combat " .. (state.run.combat_index) .. " remporté ! Choisis une carte à ajouter à ton deck.", 0, 92, W, 12, Theme.muted)
      local rects = centered_row(#controller.draft_picks, 130, 190, 140, 24)
      for i, def in ipairs(controller.draft_picks) do
        local r = rects[i]
        -- Retournement carte par carte (2026-08-08) : sans anim (draft_flip[i]
        -- absent), la carte reste face cachée, identique à l'ancien affichage
        -- statique -- une fois démarrée, on l'aplatit horizontalement (jamais
        -- de facteur négatif, donc jamais de miroir) et on bascule le contenu
        -- dos/face exactement à mi-course (la carte "sur la tranche").
        local f = controller.draft_flip[i]
        local sx = f and flip_scale_x(f.t, controller.draft_flip_duration) or 1
        local show_front = f and (f.t / controller.draft_flip_duration) >= 0.5
        love.graphics.push()
        love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
        love.graphics.scale(sx, 1)
        love.graphics.translate(-r.w / 2, -r.h / 2)
        if show_front then
          -- Même identité de classe que la main (2026-08-10, voir Theme.card_class) --
          -- bordure dorée sur les cartes "Avancé" (2026-08-09) conservée sur le contour
          -- extérieur, exactement comme le contour "sélectionné" de la main.
          local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
          panel(0, 0, r.w, r.h, palette.bg)
          set(def.tier == "avance" and Theme.accent or Theme.black)
          love.graphics.setLineWidth(def.tier == "avance" and 3 or 2)
          love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)
          set(palette.border)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle("line", 3, 3, r.w - 6, r.h - 6, 8, 8)
          love.graphics.setLineWidth(1)
          set(Theme.energy); love.graphics.circle("fill", 16, 14, 10)
          set(Theme.bg); love.graphics.setFont(Fonts.get(12)); love.graphics.printf(tostring(def.cost), 6, 7, 20, "center")
          name_badge(def.name, 4, 26, r.w - 8, 16, palette.border, Theme.bg, 2, 2)
          RichText.draw(def.desc, 4, 50, r.w - 8, 11, Theme.muted)
          -- Même origine que draw_card_face (voir plus haut, y compris le
          -- centrage/agrandissement 2026-08-24 et le remontage anti-liseré-
          -- mangé) : ce bloc dessine les cartes de draft à une taille
          -- différente (130x190, pas CARD_W/CARD_H), donc dupliqué ici plutôt
          -- que réutilisé.
          local hero_name = Heroes.class_name[def.class_id]
          if hero_name then
            set(Theme.black, 0.55)
            love.graphics.rectangle("fill", 0, r.h - 20, r.w, 16)
            text(hero_name, 0, r.h - 18, r.w, 12, palette.border, "center")
          end
        else
          panel(0, 0, r.w, r.h, Theme.panel_light)
          text("?", 0, r.h / 2 - 12, r.w, 26, Theme.muted)
        end
        love.graphics.pop()
      end
    end
  elseif controller.screen == "forge" and controller.forge then
    draw_forge(controller)
  elseif controller.screen == "temple" and controller.temple then
    draw_temple(controller)
  end

  draw_targeting_arrow(controller)
  draw_card_flights(controller)
  draw_particles(controller)
  draw_floaters(controller)
  if controller.screen == "playing" or controller.screen == "draft" or controller.screen == "forge" or controller.screen == "temple" then
    draw_tooltip(controller)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function View.draft_rects(controller)
  if not controller.draft_picks or not controller.draft_cards_shown then return {} end
  return centered_row(#controller.draft_picks, 130, 190, 140, 24)
end

return View
