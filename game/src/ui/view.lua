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

-- 1280x720, vrai 16:9 (2026-08-31, demande explicite -- avant : 960x660,
-- ratio 1.4545:1). W/H viennent désormais de logical_size.lua, partagé avec
-- conf.lua (même schéma que SCALE/layout_scale.lua) -- plus de duplication
-- manuelle des littéraux entre les deux fichiers.
local SIZE = require("src.ui.logical_size")
local W, H = SIZE.W, SIZE.H
View.W, View.H = W, H

-- Dupliqué depuis controller.lua (2026-08-30, compteur "X/9 avant le Boss") :
-- même raison que la duplication SCALE/H ci-dessus -- controller.lua requiert
-- déjà view.lua, un require dans l'autre sens créerait un cycle.
-- 9->8 (2026-09-01, demande explicite -- 2 biomes de 4 combats chacun avant
-- le Boss, au lieu de 9 combats classiques) : voir Game.current_biome dans
-- game.lua pour comment combat_index se répartit entre les 2 biomes.
local BOUNDED_COMBAT_COUNT = 8

-- +12 (2026-08-27, demande explicite -- portraits plus gros partout, voir
-- HERO_PORTRAIT_SIZE plus bas) : la carte grandit un peu pour absorber le
-- portrait agrandi sans tasser le reste (badges, nom en bas côté héros).
local UNIT_W, UNIT_H = 150, 168
local CARD_W, CARD_H = 92, 138
-- Taille/rendu des cartes de draft (écran de victoire) : voir DraftFx,
-- regroupé sous UNE SEULE locale de chunk (au lieu d'une poignée éparses --
-- W/H, canvas de fondu, fonctions front/fading/flight) -- ce fichier flirtait
-- déjà avec la limite dure de Lua (200 locales par chunk, voir LUAI_MAXVARS)
-- avant même ces ajouts du 2026-09-02 ("Syntax error: main function has more
-- than 200 local variables" à l'ajout séparé) ; les regrouper en table est le
-- seul moyen d'ajouter ces 3 fonctions sans dépasser la limite.
-- 12->16 (2026-08-31, passage 1280x720) : léger surplus d'air horizontal entre
-- portraits/cartes en rangée, sans forcer UNIT_W/CARD_W à grandir eux-mêmes
-- (le fond animé -- voir Background.draw, déjà paramétrique sur W/H -- occupe
-- naturellement les marges latérales plus généreuses à 1280 de large).
local ROW_GAP = 16

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

-- 250->270 (2026-08-31, passage 1280x720) : profite des 60px de hauteur en
-- plus pour redonner un peu d'air entre la rangée d'ennemis et celle des
-- aventuriers, plutôt que de garder le tassement forcé par l'ancien H=660.
-- 270->284 (2026-09-02, demande explicite -- affichage des PO "sous Ta
-- troupe") : +14 pour loger une 2ᵉ ligne (le HUD or) entre le label "Ta
-- troupe" et la rangée de héros, voir draw_gold_display plus bas.
local HERO_ROW_Y = 284

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
-- 450->480 (2026-08-31, passage 1280x720) : les 60px de hauteur en plus
-- permettent de redonner de l'air ici ET de restaurer "Fin de tour" à sa
-- taille 88x74 d'avant le tassement forcé par l'ancien H=660 (voir
-- END_TURN_BTN_W/H plus bas).
local HAND_Y = 480

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
-- `hiding_uids` (optionnel, 2026-08-30, bug signalé -- "au début du combat,
-- avant la pioche des cartes, je peux déjà avoir accès aux info bulles des
-- cartes, alors qu'elles ne sont pas encore dans ma main") : state.hand est
-- rempli de façon SYNCHRONE avant même que l'animation de vol ne démarre
-- (voir Controller:play_turn_start_sequence) -- sans ce filtre, une carte
-- pouvait être survolée/cliquée à SA position finale avant même d'y être
-- visuellement arrivée. Même ensemble que draw_hand (voir View.hand_hiding_uids,
-- désormais la SEULE source de vérité pour "cette carte est-elle vraiment là
-- pour de vrai" -- jamais un 2ᵉ calcul qui pourrait diverger).
function View.hand_hit(state, x, y, hiding_uids)
  local rects = View.hand_rects(state)
  for i = #state.hand, 1, -1 do
    local c = state.hand[i]
    if not (hiding_uids and hiding_uids[c.uid]) and View.point_in(rects[c.uid], x, y) then return c.uid end
  end
  return nil
end

--- Uids de state.hand encore "cachés" (vol pioche -> main pas terminé, voir
-- Controller:animate_draw/pending_draw_uids) -- calculé UNE FOIS ici, utilisé
-- à la fois par draw_hand (rendu, ci-dessous) et View.hand_hit (hit-test,
-- ci-dessus, via Input.lua) : les deux doivent toujours s'accorder, "visible"
-- et "cliquable/survolable" ne doivent jamais diverger.
function View.hand_hiding_uids(controller)
  local hiding_uids = {}
  for _, a in ipairs(controller.card_anims) do
    if a.fade_in and a.uid then hiding_uids[a.uid] = true end
  end
  for uid in pairs(controller.pending_draw_uids) do hiding_uids[uid] = true end
  return hiding_uids
end

-- Réduites de 50% (2026-08-27, demande explicite) : la pioche/défausse
-- n'ont plus besoin d'être au gabarit d'une carte pour se lire comme une
-- pile -- l'effet d'épaisseur (draw_pile) et le texte "PIOCHE : X"/
-- "DEFAUSSE : X" suffisent. CARD_W/CARD_H restent la taille des cartes
-- elles-mêmes (main, vol pioche<->main), inchangée.
local PILE_W, PILE_H = CARD_W * 0.5, CARD_H * 0.5
View.deck_pile_rect = { x = 20, y = HAND_Y, w = PILE_W, h = PILE_H }
View.discard_pile_rect = { x = W - 20 - PILE_W, y = HAND_Y, w = PILE_W, h = PILE_H }

-- "Voir le deck" (2026-08-30, demande explicite -- une fenêtre listant TOUTES
-- les cartes possédées, ouvrable aussi bien en cliquant la pioche/la défausse
-- elles-mêmes -- voir Input.mousepressed_tap/arrow -- que ce bouton dédié) :
-- casé dans l'espace resté libre entre le bas de la pioche (519) et la
-- rangée "Recommencer..."/"victoire instantanée" (BOTTOM_ROW_Y, 592) --
-- jamais chevauché, voir draw_deck_view/View.deck_view_cards pour le contenu.
-- Moins large, plus haut, sur 2 lignes (2026-08-30, demande explicite) :
-- 96x20 -> 64x40, texte "Voir le\ndeck" plutôt qu'une seule ligne large.
-- Rebaptisé "Deck", 1 seule ligne, largeur alignée sur la pioche (2026-09-02,
-- demande explicite) : `w = PILE_W` (au lieu de 64 fixe) -- tient sur 1
-- ligne à cette largeur, hauteur réduite en conséquence (40 -> 24, plus
-- besoin de place pour une 2ᵉ ligne).
View.deck_view_button = {
  x = View.deck_pile_rect.x, y = View.deck_pile_rect.y + View.deck_pile_rect.h + 5,
  w = PILE_W, h = 24, label = "Deck",
}

-- Fenêtre "voir le deck" elle-même (2026-08-30) : grand panneau centré,
-- au-dessus de N'IMPORTE quel écran (voir Controller.deck_view_open) --
-- volontairement à taille fixe plutôt que collée à une pile précise, puisque
-- ce même panneau s'ouvre aussi bien depuis la pioche/défausse en combat que
-- depuis le deck de l'écran de choix d'équipe.
View.deck_view_panel_rect = { x = 40, y = 40, w = W - 80, h = H - 80 }
View.deck_view_close_button = {
  x = View.deck_view_panel_rect.x + View.deck_view_panel_rect.w - 90,
  y = View.deck_view_panel_rect.y + 10, w = 80, h = 26, label = "Fermer",
}

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

-- "PO" (or, 2026-09-02, demande explicite -- "indiquée au dessous 'Ta
-- troupe'") : ligne compacte (icône + texte), PAS un cadre 90x90 comme
-- View.energy_display_rect -- coincée entre le label "Ta troupe"
-- (HERO_ROW_Y-28) et la rangée de héros (HERO_ROW_Y), 14px de haut seulement.
View.gold_display_rect = { x = 20, y = HERO_ROW_Y - 14, w = 120, h = 14 }

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
-- 18/3 -> 20/4 (2026-08-31, passage 1280x720) : un peu plus de respiration,
-- le budget vertical n'est plus aussi serré qu'avec l'ancien H=660.
local RESTART_BTN_W, RESTART_BTN_H, RESTART_BTN_GAP = 96, 20, 4
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
-- Restauré à 88x74 (2026-08-31, passage 1280x720) : c'était sa taille avant
-- le rétrécissement forcé (88x74->88x64, 2026-08-27) par manque de budget
-- vertical sous l'ancien H=660 -- HAND_Y descendue à 480 laisse maintenant
-- assez de place pour revenir à la taille d'origine.
local END_TURN_BTN_W, END_TURN_BTN_H = 88, 74
View.end_turn_button = {
  x = View.discard_pile_rect.x + View.discard_pile_rect.w / 2 - END_TURN_BTN_W / 2,
  y = BOTTOM_ROW_Y,
  w = END_TURN_BTN_W, h = END_TURN_BTN_H, label = "Fin de tour",
}

View.overlay_restart_button = { x = W / 2 - 70, y = H / 2 + 40, w = 140, h = 34, label = "Rejouer" }

-- Menu pause (2026-09-02, demande explicite -- ESC) : 2 options empilées,
-- centrées -- même gabarit que View.back_button/l'écran Options.
View.pause_menu_continue_button = { x = W / 2 - 100, y = H / 2 - 4, w = 200, h = 44, label = "Continuer" }
View.pause_menu_return_button = { x = W / 2 - 100, y = H / 2 + 50, w = 200, h = 44, label = "Revenir au menu" }

-- Menu principal (2026-08-21, demande explicite) : 5 boutons empilés,
-- centrés -- même geste que les autres écrans à bouton unique (Rejouer,
-- Forge/Temple) : un id sur chaque rect, lu par Input.mousepressed pour savoir
-- quelle action déclencher, jamais une deuxième liste dupliquée côté input.lua.
local MENU_BTN_W, MENU_BTN_H, MENU_BTN_GAP = 300, 48, 18
-- 220 -> 250 (2026-08-30, bug signalé -- "descendre tous les boutons qui sont
-- trop près du titre") : laisse un peu plus d'air sous la bannière des 6
-- aventuriers (MENU_HERO_ROW_Y + MENU_HERO_R, voir draw_menu_flourish),
-- ajoutée juste avant ce même écran.
local MENU_BTN_Y0 = 270 -- 250->270 (2026-08-31, passage 1280x720)
View.menu_buttons = {}
do
  -- Ordre demandé explicitement (2026-08-30) : Jouer un run -> Mode infini ->
  -- Tester le boss -> Options -> Quitter (avant : boss en premier).
  -- "Mode infini" retiré du menu (2026-09-02, demande explicite -- annoncé
  -- comme "bientôt retiré" par le porteur de projet, voir
  -- content/memory/project_mode-infini-retrait.md) : le code du mode
  -- "infini" (Controller.run_mode == "infini", pool d'ennemis non filtré par
  -- biome, etc.) reste intact, juste devenu inaccessible depuis l'UI --
  -- retrait complet hors scope de cette demande.
  local defs = {
    { id = "run", label = "Jouer un run" },
    { id = "boss", label = "Tester le boss" },
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
-- Forge.CHOICE_COUNT (4) cartes en rangée -- le nombre de rects dépend du
-- nombre RÉEL de choix proposés (0 à 4, moins si le deck n'a pas assez de
-- cartes améliorables), donc calculé à la demande depuis controller.forge
-- plutôt qu'une position fixe. Chaque colonne montre sa carte de BASE (ces
-- rects-ci) PUIS, en dessous d'une flèche, sa version améliorée (voir
-- View.forge_upgraded_card_rects -- 2026-08-30, demande explicite : "chacune
-- des 4 cartes au choix doit présenter sa version améliorée, reliée par une
-- flèche" -- avant, seule la version améliorée était montrée, empilement
-- VERTICAL plutôt qu'un 2ᵉ jeu de 4 cartes à côté, qui ne tiendrait pas sur
-- la largeur de l'écran, voir l'historique de ce commentaire).
-- 170->190 (2026-08-31, passage 1280x720) : un peu plus d'air sous le titre,
-- toujours largement dans le budget vertical (marge encore confortable avant
-- View.forge_skip_button, tout en bas de cette colonne).
local FORGE_CARD_Y = 190
local FORGE_ARROW_H = 40
local FORGE_CARD_GAP = 30
function View.forge_card_rects(controller)
  local f = controller.forge
  if not f then return {} end
  return centered_row(#f.choices, CARD_W, CARD_H, FORGE_CARD_Y, FORGE_CARD_GAP)
end

--- Rects de la version AMÉLIORÉE, même colonnes que View.forge_card_rects,
-- juste en dessous (2026-08-30, voir son commentaire ci-dessus).
function View.forge_upgraded_card_rects(controller)
  local f = controller.forge
  if not f then return {} end
  return centered_row(#f.choices, CARD_W, CARD_H, FORGE_CARD_Y + CARD_H + FORGE_ARROW_H, FORGE_CARD_GAP)
end

View.forge_skip_button = {
  x = W / 2 - 100, y = FORGE_CARD_Y + CARD_H + FORGE_ARROW_H + CARD_H + 30, w = 200, h = 44, label = "Passer",
}

-- Écran "Le Temple" (2026-08-29, refonte complète -- demande explicite) :
-- jusqu'à 3 statues d'effet EN LIGNE au-dessus des 4 aventuriers (toujours
-- les 4, jamais recalculé selon l'éligibilité -- un aventurier mort ou déjà
-- porteur reste affiché, juste grisé/non cliquable, voir draw_temple/
-- Controller:choose_temple_hero). Aucun "Passer" sur cet écran (choix
-- obligatoire) -- un bouton "Confirmer" à la place, actif seulement quand
-- aventurier ET effet sont choisis (voir Controller:confirm_temple_choice).
local TEMPLE_EFFECT_W, TEMPLE_EFFECT_H = 140, 150
local TEMPLE_EFFECT_Y = 120 -- 108->120 (2026-08-31, passage 1280x720)
local TEMPLE_EFFECT_GAP = 30
function View.temple_effect_rects(controller)
  local t = controller.temple
  if not t then return {} end
  return centered_row(#t.choices, TEMPLE_EFFECT_W, TEMPLE_EFFECT_H, TEMPLE_EFFECT_Y, TEMPLE_EFFECT_GAP)
end

local TEMPLE_HERO_W, TEMPLE_HERO_H = 130, 136
local TEMPLE_HERO_Y = 320 -- 300->320 (2026-08-31, passage 1280x720)
function View.temple_hero_rects(controller)
  local rects = centered_row(#controller.state.heroes, TEMPLE_HERO_W, TEMPLE_HERO_H, TEMPLE_HERO_Y)
  local out = {}
  for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
  return out
end
View.temple_confirm_button = {
  x = W / 2 - 100, y = TEMPLE_HERO_Y + TEMPLE_HERO_H + 20, w = 200, h = 44, label = "Confirmer",
}

-- Écran "Feu de camp" (2026-08-30, remis en place, refonte -- "pas d'options
-- autre que le soin, le joueur choisit parmi ses 4 aventuriers lequel va se
-- faire soigner de 30% de ses PV max") : une seule rangée de 4, cliquer
-- résout directement (pas de bouton "Confirmer" séparé, contrairement au
-- Temple qui combine 2 choix) -- mêmes dimensions que la rangée du Temple,
-- juste plus haute à l'écran (rien au-dessus, pas de statues).
local CAMPFIRE_HERO_W, CAMPFIRE_HERO_H = 150, 170
local CAMPFIRE_HERO_Y = 260 -- 240->260 (2026-08-31, passage 1280x720)
function View.campfire_hero_rects(controller)
  local rects = centered_row(#controller.state.heroes, CAMPFIRE_HERO_W, CAMPFIRE_HERO_H, CAMPFIRE_HERO_Y)
  local out = {}
  for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
  return out
end

-- Écran "Le Refuge" (2026-08-30, nouvel évènement -- "pas de choix, tous les
-- persos vont regagner 30% de leurs PV") : même rangée de 4 que le feu de
-- camp. "Se reposer", pas "Continuer" (2026-08-30, bug signalé -- "il faut
-- quand même une action joueur, au moins 1 clic, pour déclencher le soin") :
-- ce bouton déclenche maintenant le soin lui-même (voir Controller:
-- choose_refuge_rest), pas de clic sur un aventurier individuel (toute
-- l'équipe est soignée d'un coup, "pas de choix").
local REFUGE_HERO_W, REFUGE_HERO_H = 150, 170
local REFUGE_HERO_Y = 260 -- 240->260 (2026-08-31, passage 1280x720)
function View.refuge_hero_rects(controller)
  local rects = centered_row(#controller.state.heroes, REFUGE_HERO_W, REFUGE_HERO_H, REFUGE_HERO_Y)
  local out = {}
  for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
  return out
end
View.refuge_rest_button = {
  x = W / 2 - 100, y = REFUGE_HERO_Y + REFUGE_HERO_H + 20, w = 200, h = 44, label = "Se reposer",
}

-- Écran "Choisis ton équipe" (2026-08-29, avant chaque run -- 4 aventuriers
-- parmi les 6 `Heroes.defs`) : rangée du haut = disponibles (pas encore dans
-- l'équipe), rangée du bas = équipe confirmée -- 2 listes MUTUELLEMENT
-- EXCLUSIVES (voir Controller:team_select_confirm, qui bascule un id de
-- l'une à l'autre) -- jamais le même héros affiché aux deux endroits à la fois.
local TEAM_HERO_W, TEAM_HERO_H = 108, 120
local TEAM_HERO_GAP = 18
local TEAM_AVAILABLE_Y = 66
-- Rangée "équipe confirmée" ET bouton "Partir à l'aventure" ancrés sur LA
-- MÊME valeur (2026-08-30, demande explicite -- "les aventuriers sélectionnés
-- doivent être situés tout en bas de l'écran, au même niveau que Partir à
-- l'aventure") : les 2 partagent désormais TEAM_BOTTOM_Y, plutôt que l'un
-- calculé à partir de l'autre (ancien schéma, qui les gardait séparés
-- verticalement). Rangée ANCRÉE À GAUCHE (pas centrée, contrairement à la
-- rangée du haut) -- demande explicite ci-dessus + bug signalé (une rangée
-- centrée à 4 aventuriers déborde jusqu'à x~723, en plein sur le bouton, qui
-- commence à x=670) : décalée pour ne jamais pouvoir le recouvrir, quel que
-- soit le nombre d'aventuriers déjà confirmés.
-- 520->560 (2026-08-31, passage 1280x720) : un peu plus d'air entre la 2ᵉ
-- rangée de cartes (TEAM_CARD_Y) et cette rangée, avec les 60px de hauteur
-- en plus -- tout le reste de la colonne (projecteur/boutons Annuler-Valider)
-- se termine bien avant (y=488), aucun risque de chevauchement.
local TEAM_BOTTOM_Y = 560
local TEAM_PARTY_LEFT = 170

-- Emplacements FIXES, un par héros du roster complet (2026-08-30, bug signalé
-- -- "quand un aventurier est sélectionné, les autres se recalent vers le
-- centre, je préfère que chacun reste à sa place") : `centered_row` recalculée
-- sur `#ts.available_ids` (qui RÉTRÉCIT à chaque validation, un id en sortant)
-- redistribuait TOUS les héros restants sur une rangée plus étroite -- ici, la
-- rangée est calculée UNE FOIS sur `#Heroes.defs` (toujours 6, ne bouge
-- jamais), chaque héros reçoit la case correspondant à SA position dans le
-- roster complet, qu'il soit actuellement disponible ou déjà dans l'équipe --
-- un id qui sort de `ts.available_ids` libère silencieusement sa case (plus
-- personne n'y est dessiné), sans jamais faire bouger les autres.
local TEAM_ALL_SLOTS_RECTS
local function team_select_all_slots()
  TEAM_ALL_SLOTS_RECTS = TEAM_ALL_SLOTS_RECTS
    or centered_row(#Heroes.defs, TEAM_HERO_W, TEAM_HERO_H, TEAM_AVAILABLE_Y, TEAM_HERO_GAP)
  return TEAM_ALL_SLOTS_RECTS
end

function View.team_select_available_rects(controller)
  local ts = controller.team_select
  if not ts then return {} end
  local slots = team_select_all_slots()
  local still_available = {}
  for _, id in ipairs(ts.available_ids) do still_available[id] = true end
  local out = {}
  for i, def in ipairs(Heroes.defs) do
    if still_available[def.id] then out[def.id] = slots[i] end
  end
  return out
end

function View.team_select_party_rects(controller)
  local ts = controller.team_select
  if not ts then return {} end
  local out = {}
  for i, id in ipairs(ts.selected_ids) do
    out[id] = {
      x = TEAM_PARTY_LEFT + (i - 1) * (TEAM_HERO_W + TEAM_HERO_GAP), y = TEAM_BOTTOM_Y,
      w = TEAM_HERO_W, h = TEAM_HERO_H,
    }
  end
  return out
end

-- "Projecteur" (2026-08-29, "quand je sélectionne un aventurier, le
-- déplacement est visible" ; déplacé à GAUCHE le 2026-08-30, demande
-- explicite -- "je préfère que l'aventurier en cours de sélection soit
-- placé sur la gauche plutôt que sur la droite") : emplacement fixe où le
-- héros survolé/sélectionné SE DÉPLACE réellement (voir Controller:
-- team_select_move_hero), plus grand que sa case d'origine pour bien
-- marquer "c'est celui-ci qu'on regarde en ce moment". Reste ENTIÈREMENT
-- sous la rangée du haut (qui s'arrête à TEAM_AVAILABLE_Y + TEAM_HERO_H =
-- 186), quelle que soit la largeur de cette rangée.
local TEAM_SPOTLIGHT_W, TEAM_SPOTLIGHT_H = 170, 190
local TEAM_SPOTLIGHT_X = 40
View.team_select_spotlight_rect = {
  x = TEAM_SPOTLIGHT_X, y = 200, w = TEAM_SPOTLIGHT_W, h = TEAM_SPOTLIGHT_H,
}

-- Sous le projecteur désormais, pas à côté (2026-08-30, demande explicite --
-- "les boutons Annuler doivent être descendus pour être en dessous de
-- l'aventurier en cours de sélection"), et plus étroits qu'avant (110->90,
-- 2ᵉ demande explicite du même message) -- centrés sous la colonne du
-- projecteur.
local TEAM_ACTION_BTN_W, TEAM_ACTION_BTN_H = 90, 40
local TEAM_ACTION_BTN_X = TEAM_SPOTLIGHT_X + (TEAM_SPOTLIGHT_W - TEAM_ACTION_BTN_W) / 2
View.team_select_cancel_button = {
  x = TEAM_ACTION_BTN_X, y = View.team_select_spotlight_rect.y + TEAM_SPOTLIGHT_H + 10,
  w = TEAM_ACTION_BTN_W, h = TEAM_ACTION_BTN_H, label = "Annuler",
}
View.team_select_confirm_button = {
  x = TEAM_ACTION_BTN_X, y = View.team_select_cancel_button.y + TEAM_ACTION_BTN_H + 8,
  w = TEAM_ACTION_BTN_W, h = TEAM_ACTION_BTN_H, label = "Valider",
}

-- Cartes du héros mis en avant (2026-08-29 -- "les cartes doivent être plus
-- bas" ; simplifiées à 4 items le même jour -- "3 cartes de départ + 1 dos
-- avec leur nombre" ; puis remises sur 2 rangées le 2026-08-30, demande
-- explicite -- "le tas de cartes avancées doit se situer sur la deuxième
-- ligne en dessous des cartes de départ") : jusqu'à 3 par rangée, centrées
-- sur TOUTE la largeur -- avec le projecteur maintenant à gauche (x=40-210)
-- et plus rien à droite, ce centrage reste largement à l'écart des deux
-- côtés (vérifié -- rangée de 3 : x330-630 ; la 4ᵉ carte seule, rangée 2 :
-- x434-526).
local TEAM_CARD_Y = 210
local TEAM_CARD_ROW_GAP = 16
local TEAM_CARD_ROW1_MAX = 3
function View.team_select_card_rects(count)
  local rects = {}
  local row1_count = math.min(count, TEAM_CARD_ROW1_MAX)
  local row1 = centered_row(row1_count, CARD_W, CARD_H, TEAM_CARD_Y)
  for i = 1, row1_count do rects[i] = row1[i] end
  if count > TEAM_CARD_ROW1_MAX then
    local row2_count = count - TEAM_CARD_ROW1_MAX
    local row2 = centered_row(row2_count, CARD_W, CARD_H, TEAM_CARD_Y + CARD_H + TEAM_CARD_ROW_GAP)
    for i = 1, row2_count do rects[TEAM_CARD_ROW1_MAX + i] = row2[i] end
  end
  return rects
end

--- Rectangle hors-écran de même taille que `to`, positionné sur le bord
-- `side` ("left"/"right"/"top"/"bottom") -- origine OU destination d'un vol
-- de carte sur l'écran de choix d'équipe (2026-08-29). Purement cosmétique,
-- aucun lien avec une règle de jeu.
function View.team_select_offscreen_rect(to, side)
  local margin = 60
  if side == "left" then return { x = -to.w - margin, y = to.y, w = to.w, h = to.h } end
  if side == "right" then return { x = W + margin, y = to.y, w = to.w, h = to.h } end
  if side == "top" then return { x = to.x, y = -to.h - margin, w = to.w, h = to.h } end
  return { x = to.x, y = H + margin, w = to.w, h = to.h }
end

-- Ancré sur TEAM_BOTTOM_Y, comme la rangée "équipe" juste à gauche (2026-08-29,
-- demande explicite -- "au même niveau que Partir à l'aventure") : les deux
-- partagent la même origine verticale. Plus carré, texte sur 2 lignes
-- (2026-08-30, demande explicite -- 260x64 était très large/plat) --
-- toujours ancré à droite, largement à l'écart de la rangée "équipe" (qui
-- s'arrête à x656 pour 4 membres, voir TEAM_PARTY_LEFT).
local TEAM_LAUNCH_W, TEAM_LAUNCH_H = 170, 110
View.team_select_launch_button = {
  x = W - TEAM_LAUNCH_W - 30, y = TEAM_BOTTOM_Y, w = TEAM_LAUNCH_W, h = TEAM_LAUNCH_H,
  label = "Partir à\nl'aventure",
}

-- "Auto-fill" (2026-09-02, demande explicite -- "choisit immédiatement et
-- aléatoirement 4 aventuriers et lance l'aventure") : juste au-dessus de
-- "Partir à l'aventure", même largeur/même colonne -- toujours cliquable,
-- contrairement au lancement normal qui exige 4 aventuriers déjà confirmés
-- (voir Controller:team_select_autofill, qui ignore la sélection en cours).
local TEAM_AUTOFILL_W, TEAM_AUTOFILL_H, TEAM_AUTOFILL_GAP = TEAM_LAUNCH_W, 36, 10
View.team_select_autofill_button = {
  x = W - TEAM_LAUNCH_W - 30, y = TEAM_BOTTOM_Y - TEAM_AUTOFILL_H - TEAM_AUTOFILL_GAP,
  w = TEAM_AUTOFILL_W, h = TEAM_AUTOFILL_H, label = "Auto-fill",
}

-- "Deck" de l'écran de choix d'équipe (2026-08-30, demande explicite --
-- "ses cartes se regroupent pour aller rejoindre le deck situé en bas à
-- gauche, ce deck grossit à chaque nouvel aventurier") : PURE mise en scène,
-- aucun lien avec Deck.build_starting_deck (qui ne prendra que les 3 cartes
-- "depart" par héros -- ici on anime les 6 cartes déjà montrées à l'écran,
-- une convention visuelle propre à cet écran, pas une prévisualisation
-- littérale du deck de départ réel). Ancré par son coin bas-gauche, sur le
-- même bord bas que la rangée "équipe"/le bouton (TEAM_BOTTOM_Y +
-- TEAM_HERO_H) -- grossit vers le haut, jamais vers la rangée "équipe" à sa
-- droite (colonne x=20-138 max, largement sous TEAM_PARTY_LEFT=170).
local TEAM_DECK_LEFT = 20
local TEAM_DECK_BOTTOM = TEAM_BOTTOM_Y + TEAM_HERO_H
local TEAM_DECK_BASE_W, TEAM_DECK_BASE_H = 70, 90
local TEAM_DECK_GROWTH = 12 -- px par aventurier validé
function View.team_select_deck_rect(hero_count)
  local w = TEAM_DECK_BASE_W + TEAM_DECK_GROWTH * hero_count
  local h = TEAM_DECK_BASE_H + TEAM_DECK_GROWTH * hero_count
  return { x = TEAM_DECK_LEFT, y = TEAM_DECK_BOTTOM - h, w = w, h = h }
end

local function point_in(r, x, y)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end
View.point_in = point_in

-- ---------- petites aides de dessin ----------

local function set(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

--- Interpole RGB entre 2 couleurs (2026-08-30, mort d'un héros -- voir
-- draw_hero/self.hero_death_fade) : `t` = 0 -> `a`, `t` = 1 -> `b`.
local function lerp_color(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- `alpha` (optionnel, 2026-08-30, Temple -- fondu des aventuriers non
-- choisis) : par défaut 1, tous les appels existants restent inchangés.
local function panel(x, y, w, h, color, alpha)
  set(color or Theme.panel, alpha)
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
-- `alpha` (optionnel, 2026-08-30 -- voir Icons.draw_class) : par défaut 1.
local function draw_class_icon(class_id, icon, label, x, y, w, size, color, alpha)
  local drawn = Icons.draw_class(class_id, x + w / 2, y + size / 2, size / 2, color or Theme.text, alpha)
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
  -- `pop_t < 0` (2026-08-30, demande explicite -- décalage entre plusieurs
  -- cibles touchées d'un coup, voir Controller:pop_status/react_to_diff) :
  -- l'icône n'a pas encore "son tour", rendue normalement (aucun pop/écho)
  -- jusqu'à ce que `pop_t` atteigne 0 -- jamais un `p` négatif, qui ferait
  -- grossir le badge sans limite au lieu de simplement ne rien animer.
  if pop_t and pop_t >= 0 and pop_duration then
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

--- Barre de PV "à 2 niveaux", perte ET gain (2026-08-30, demande explicite,
-- étendue le même jour aux soins -- voir Controller:update/advance_trail) :
-- `trail_pct` (fraction de PV tenue par self.hp_trail) rejoint toujours
-- `pct` (la vraie valeur ACTUELLE, immédiate) progressivement, dans les deux
-- sens -- cette fonction se contente d'afficher le plus grand des deux en
-- accent (EN DESSOUS), le plus petit par-dessus dans `color` (le rouge
-- "normal") :
-- - PERTE : `pct` (rouge, la vraie valeur) chute tout de suite, plus petit
--   -- `trail_pct` reste au-dessus, encore à l'ancienne valeur, affiché en
--   JAUNE en dessous -- "la barre rouge perd la vie de suite, la jaune se
--   vide lentement pour la rejoindre".
-- - GAIN : `pct` (la vraie valeur, déjà soignée) bondit tout de suite, plus
--   grand -- affiché en VERT en dessous -- `trail_pct`, encore à l'ancienne
--   valeur plus basse, reste au-dessus dans `color` (rouge) et grossit
--   progressivement pour le rejoindre -- "une première barre verte qui
--   monte instantanément, puis la barre normale qui la rejoint doucement".
-- `pct == trail_pct` (aucun changement récent, traînée déjà rattrapée)
-- retombe visuellement sur un simple rendu à 1 niveau.
local function hp_bar(x, y, w, h, pct, trail_pct, color)
  set({ 0, 0, 0 }, 0.35)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  local clamped_pct = math.max(0, math.min(1, pct))
  local clamped_trail = trail_pct and math.max(0, math.min(1, trail_pct)) or clamped_pct
  local wide, narrow = math.max(clamped_trail, clamped_pct), math.min(clamped_trail, clamped_pct)
  -- Garde `> 0` sur les 2 rectangles (2026-08-30, bug signalé -- "il reste
  -- du rouge sur le bord de la barre de vie" -- un héros mort, à 0 PV) :
  -- love.graphics.rectangle("fill", ..., 0, h, 4, 4) (largeur nulle) laisse
  -- quand même un liseré visible à cause du rayon d'arrondi fixe (4px), qui
  -- ne se réduit pas avec la largeur -- jamais dessiné en dessous de 1px,
  -- plutôt qu'un rectangle dégénéré.
  if wide > narrow and wide * w > 1 then
    set(clamped_trail > clamped_pct and Theme.hp_trail or Theme.heal)
    love.graphics.rectangle("fill", x, y, w * wide, h, 4, 4)
  end
  if narrow * w > 1 then
    set(color)
    love.graphics.rectangle("fill", x, y, w * narrow, h, 4, 4)
  end
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
  -- `s.t < 0` (2026-08-30, décalage multi-cibles, voir Controller:
  -- spawn_shield_fx/react_to_diff) : pas encore "son tour", rien à dessiner.
  if s.t < 0 then return end
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

  -- "S'éteint" doucement à la mort (2026-08-30, demande explicite -- "que le
  -- héros s'éteigne doucement pour atteindre l'état actuel") : `fade_p`
  -- (0 = encore pleinement "vivant" à l'écran, 1 = état "mort" final atteint)
  -- remplace un simple bascule instantanée `dead and X or Y` sur les alphas/
  -- couleurs ci-dessous -- voir self.hero_death_fade (Controller:update, seul
  -- écrivain, + le son "hero_death" joué une fois au moment où hp tombe à 0).
  -- Reste à 0 tant que le héros est vivant (fade == nil).
  local fade = controller.hero_death_fade[h.id]
  local fade_p = fade and math.min(1, fade.t / fade.duration) or 0

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
  elseif ready or fade_p < 1 then
    -- Glisse vers le contour terne au lieu d'y basculer d'un coup
    -- (2026-08-30) : couleur de classe pleine tant que fade_p vaut 0 (héros
    -- vivant -- rendu identique à avant ce correctif), mélangée
    -- progressivement vers Theme.panel_light (le contour "mort") au fil de
    -- fade_p -- épaisseur du contour suit le même mouvement (3 -> 1).
    border, border_w = lerp_color(hero_palette.border, Theme.panel_light, fade_p), 3 - 2 * fade_p
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

  set(Theme.panel, 1 - 0.5 * fade_p)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  -- Fond de plus en plus rouge sombre sous 50% de PV (2026-08-27, demande
  -- explicite), proportionnel aux PV perdus au-delà de ce seuil -- "montrer
  -- qu'il est de plus en plus blessé et proche de la mort". Simple surcouche
  -- semi-transparente (Theme.hp, le rouge déjà utilisé pour les dégâts/la
  -- barre de PV -- pas une nouvelle teinte) plutôt qu'un vrai mélange RGB :
  -- alpha 0 pile à 50% de PV, jusqu'à 0.6 à 0 PV -- puis, une fois mort,
  -- s'estompe avec le reste du fondu (2026-08-30, `* (1 - fade_p)`) au lieu
  -- de disparaître d'un coup (voile gris du panneau ci-dessus déjà en train
  -- de monter en parallèle, aucun besoin de le garder à plein une fois le
  -- fondu terminé).
  local hp_pct = math.max(0, h.hp) / h.max_hp
  if hp_pct < 0.5 then
    local wound_t = math.min(1, (0.5 - hp_pct) / 0.5)
    set(Theme.hp, wound_t * 0.6 * (1 - fade_p))
    love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  end
  set(border); love.graphics.setLineWidth(border_w)
  love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

  -- Portrait agrandi (2026-08-27, demande explicite -- "toutes les images des
  -- aventuriers et des ennemis doivent être plus gros") : 46->54. Nom déplacé
  -- EN BAS du cadre (2026-08-27, demande explicite) : l'ordre devient portrait
  -- -> barre de PV -> mana/discrétion -> statuts -> nom, au lieu de portrait
  -- -> nom -> barre -> ... avant. Le badge de Défense s'ancre désormais au-dessus
  -- du nom (voir cy passé à draw_defense_badge_big), pas près du bas par défaut.
  -- `alpha` (dernier argument, 2026-08-30) : le portrait est un vrai sprite
  -- pour tous les héros (Icons.draw_class -- radius 27 > SPRITE_MIN_RADIUS),
  -- qui gère SON PROPRE alpha via ce paramètre explicite plutôt que l'état
  -- ambiant `set()` (toujours remis à plein par Icons.draw_class juste avant
  -- de dessiner) -- sans ce paramètre, le portrait ne se serait PAS
  -- réellement estompé, seuls le panneau/le contour l'auraient fait.
  set(Theme.text, 1 - 0.55 * fade_p)
  local HERO_PORTRAIT_SIZE = 54
  draw_class_icon(h.class_id, h.icon, h.label, 0, 4, r.w, HERO_PORTRAIT_SIZE, Theme.text, 1 - 0.55 * fade_p)
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
  hp_bar(8, 62, r.w - 16, 16, h.hp / h.max_hp, (controller.hp_trail[h.id] or h.hp) / h.max_hp, Theme.hp)
  text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", 0, 62, r.w, 16, 10, Theme.text)

  -- Mana (2026-08-20, ressource propre au Mage, voir hero.mana dans game.lua) :
  -- dans son propre cadre, juste sous sa jauge de PV -- seul le Mage a ce
  -- champ non-nil, les 3 autres classes ne dessinent jamais cette ligne.
  -- Icône plutôt que le mot en toutes lettres (2026-09-02, bug signalé --
  -- "le mana est indiqué en toute lettre... au lieu d'indiquer l'icone") :
  -- même icône que le glossaire/le HUD "PO" (Sprites.keyword("mana"), voir
  -- draw_gold_display) -- repli texte gardé si jamais l'icône manquait
  -- (silencieux, voir Sprites.keyword) plutôt qu'une ligne vide.
  if h.mana ~= nil then
    local mana_icon = Sprites.keyword("mana")
    if mana_icon then
      love.graphics.setColor(1, 1, 1, 1)
      Sprites.draw_centered(mana_icon, r.w / 2 - 8, 85, 7)
      text(tostring(h.mana), r.w / 2 + 2, 80, r.w / 2 - 2, 11, Theme.mana, "left")
    else
      text("MANA " .. tostring(h.mana), 0, 81, r.w, 9, Theme.mana)
    end
  end
  -- Discrétion (2026-08-24, ressource propre à l'Assassin, voir hero.discretion
  -- dans game.lua) : même traitement que MANA ci-dessus -- un seul des deux
  -- champs est jamais non-nil pour un héros donné, pas de collision possible.
  -- "CAMOUFLÉ" en toutes lettres à la place de "DISCR 10" (2026-08-30, demande
  -- explicite -- "L'état de Camouflage de l'Assassin est très important...
  -- il faut indiqué en toute lettre 'CAMOUFLE' juste en dessous") : remplace
  -- le compteur plutôt que de s'y ajouter, puisqu'à 10/10 le compteur lui-même
  -- n'apporte plus rien (déjà au plafond) -- voir aussi le voile plus bas.
  -- "DISCR" -> "DISCRÉTION" en toutes lettres (2026-09-02, demande explicite) :
  -- même mot que "CAMOUFLÉ" ci-dessus, jamais abrégé -- juste le préfixe qui
  -- change, contrairement à MANA qui est passé à une icône (Discrétion n'a
  -- pas d'icône dédiée en jeu, contrairement à Mana/PO).
  if h.discretion ~= nil then
    if (h.camoufle or 0) > 0 then
      text("CAMOUFLÉ", 0, 81, r.w, 9, Theme.discretion)
    else
      text("DISCRÉTION " .. tostring(h.discretion), 0, 81, r.w, 9, Theme.discretion)
    end
  end
  -- Corruption (2026-08-29, ressource propre au Nécromancien, voir
  -- hero.corruption dans game.lua) : même traitement que MANA/DISCR
  -- ci-dessus -- un seul des trois champs est jamais non-nil pour un héros
  -- donné, pas de collision possible.
  if h.corruption ~= nil then
    text("CORR " .. tostring(h.corruption), 0, 81, r.w, 9, Theme.corruption)
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
  -- Incandescence (2026-09-02, statut Volcan, "marche comme la Puissance sauf
  -- qu'elle ne descend pas" -- voir combat.lua/game.lua) : même traitement
  -- que Puissance ci-dessus, abréviation distincte (PUI est déjà pris).
  if (h.incandescence or 0) > 0 then badges[#badges + 1] = { key = "incandescence", abbr = "INCA", value = h.incandescence } end
  if (h.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = h.saignements } end
  if (h.brulure or 0) > 0 then badges[#badges + 1] = { key = "brulure", abbr = "BRU", value = h.brulure } end
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
  -- Inspiration/Encore (2026-08-29, statuts GÉNÉRIQUES du Barde -- voir
  -- hero.inspiration/hero.encore_extra_plays dans game.lua) : N'IMPORTE QUEL
  -- héros peut les porter (accordés par une carte Barde à un allié d'une
  -- AUTRE classe) -- badges génériques comme Puissance/Provocation ci-dessus,
  -- jamais conditionnés à class_id == "barde".
  if (h.inspiration or 0) > 0 then badges[#badges + 1] = { key = "inspiration", abbr = "INSP", value = h.inspiration } end
  if (h.encore_extra_plays or 0) > 0 then badges[#badges + 1] = { key = "encore", abbr = "ENC", value = h.encore_extra_plays } end
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

  -- Voile de Camouflage (2026-08-30, demande explicite -- "ajouter un effet
  -- sur l'ensemble du cadre pour indiquer qu'il est camouflé, par exemple un
  -- voile noir 50% alpha par dessus") : PAR-DESSUS tout ce qui vient d'être
  -- dessiné (portrait, PV, badges, nom), pas juste un badge de plus au milieu
  -- des autres -- c'est tout le cadre qui doit se lire "cet aventurier est
  -- caché", cohérent avec "l'état de Camouflage... est très important".
  if not dead and (h.camoufle or 0) > 0 then
    set(Theme.black, 0.5)
    love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  end

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
  -- Incandescence (2026-09-02, additive, voir Combat.incandescence_flat --
  -- même règle qu'Inspiration côté héros : appliquée AVANT le multiplicateur,
  -- jamais dedans, pour ne jamais diverger de Combat.deal_damage) : ajoutée
  -- ICI, pas dans Combat.damage_multiplier, sur les 3 usages de ce module
  -- (adjusted ci-dessous + les 2 usages inline plus bas, "dmg-all"/"buff-self").
  local function adjusted(amount)
    return Combat.round((amount + Combat.incandescence_flat(e, "physique")) * Combat.damage_multiplier(e, target, "physique"))
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
  elseif move.kind == "buff-self" then
    -- "Envol" de l'Aigle Géant (2026-08-30) : icône du statut posé lui-même
    -- (ex. "vol", voir DRAW_BY_STATUS dans icons.lua) plutôt que le "bonus"
    -- générique ci-dessus -- le joueur voit directement CE QUI arrive
    -- (l'icône de Vol), pas juste "quelque chose de positif", puisqu'il n'y a
    -- ici qu'une seule variante possible par ennemi (pas 3 comme soin/
    -- résurrection à distinguer). `body` (2026-08-30, demande explicite --
    -- "Envol doit faire des dégâts faibles sur tous les aventuriers") :
    -- montre ces dégâts secondaires quand `move.dmg_all_amount` existe, même
    -- format "X à tous" que le kind "dmg-all" plus bas -- ajustés côté
    -- attaquant seulement (Puissance/Incapacité de l'Aigle), jamais une
    -- Vulnérabilité par héros (héros multiples, comme dmg-all).
    local body = move.dmg_all_amount and (Combat.round((move.dmg_all_amount + Combat.incandescence_flat(e, "physique")) * Combat.damage_multiplier(e, nil, "physique")) .. " à tous") or nil
    return { title = move.name, body = body, icon_source = "status", icon_key = move.status_key or "bonus" }
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
      title = move.name, body = Combat.round((move.amount + Combat.incandescence_flat(e, "physique")) * Combat.damage_multiplier(e, nil, "physique")) .. " à tous",
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

--- Lignes de fissure qui gagnent en netteté à l'approche de l'explosion
-- (2026-08-30, demande explicite -- "il se fissure puis explose", voir
-- Controller:update/self.enemy_death) : motif FIXE par segment (dérivé de
-- l'index seul, jamais de math.random appelé à chaque frame -- sinon les
-- lignes grouilleraient au lieu de se figer/s'accumuler) -- seuls l'opacité
-- ET le nombre de segments déjà "apparus" suivent `crack_p` (0 -> 1).
local ENEMY_CRACK_LINES = 5
local function draw_enemy_crack(r, crack_p)
  if crack_p <= 0 then return end
  set(Theme.hp, math.min(1, crack_p * 1.3))
  love.graphics.setLineWidth(2)
  local cx, cy = r.w / 2, r.h / 2
  for i = 1, ENEMY_CRACK_LINES do
    if crack_p * ENEMY_CRACK_LINES >= i - 1 then
      local seed = i * 37.13
      local angle = (i / ENEMY_CRACK_LINES) * math.pi * 2 + math.sin(seed) * 0.6
      local len = r.w * 0.4 + (i % 3) * 6
      local mx = cx + math.cos(angle) * len * 0.5 + math.sin(seed * 2) * 6
      local my = cy + math.sin(angle) * len * 0.5 + math.cos(seed * 2) * 6
      local ex = cx + math.cos(angle) * len
      local ey = cy + math.sin(angle) * len
      love.graphics.line(cx, cy, mx, my, ex, ey)
    end
  end
  love.graphics.setLineWidth(1)
end

local function draw_enemy(controller, e, r)
  local dead = e.hp <= 0
  -- Séquence de mort (2026-08-30, demande explicite -- "il se fissure puis
  -- explose en particules qui vanish ... il ne reste plus rien de lui") :
  -- une fois `death.exploded` vrai (voir Controller:update), plus RIEN n'est
  -- dessiné pour cet ennemi -- même la trame/le cadre -- les particules déjà
  -- semées (self.particles, indépendantes de cette table) continuent seules
  -- de s'éteindre, voir draw_particles.
  local death = controller.enemy_death[e.id]
  if death and death.exploded then return end
  -- Traînée de PV (2026-08-30, voir hp_bar/Controller.hp_trail) : tant
  -- qu'elle n'a pas fini de rattraper 0, l'ennemi reste affiché "en vie"
  -- (barre, badges, télégraphe) même si `e.hp` est déjà <= 0 -- seul
  -- `trail_dead` (traînée ELLE-MÊME à 0) déclenche l'apparence "vaincu"
  -- ci-dessous, remplace `dead` sur tous les éléments concernés par ce délai.
  local trail = controller.hp_trail[e.id] or e.hp
  local trail_dead = dead and trail <= 0

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
  -- Élite (2026-09-01, demande explicite -- "ils sont plus gros") : ~18% plus
  -- grand qu'un ennemi normal, un pur agrandissement de RENDU (jamais r.w/r.h
  -- eux-mêmes, qui restent la grille uniforme de centered_row/le hit-test
  -- réel d'Input.lua) -- même compromis déjà accepté par le pulse au survol
  -- juste au-dessus (visuel plus grand, zone cliquable inchangée).
  if e.elite then scale = scale * 1.18 end

  -- Fissure (2026-08-30) : secousse de plus en plus forte à l'approche de
  -- l'explosion -- fenêtre `death` active tant que `not death.exploded`
  -- (voir Controller:update, ENEMY_DEATH_CRACK_DURATION). `crack_p` réutilisé
  -- plus bas par draw_enemy_crack pour les lignes de fissure elles-mêmes.
  local crack_p = 0
  if death and not death.exploded then
    crack_p = math.min(1, death.t / (death.crack_duration or 0.45))
    dx = dx + math.sin(death.t * 60) * 3 * crack_p
    dy = dy + math.cos(death.t * 47) * 2 * crack_p
  end

  love.graphics.push()
  love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-r.w / 2, -r.h / 2)

  -- Cadre bleu = cible possible pour la carte en attente de résolution
  -- (2026-08-08) -- même couleur que côté héros (voir eligible_target dans
  -- draw_hero), pour que "bleu" signifie systématiquement "cible cliquable".
  -- Fond quasi imperceptible (2026-08-30, demande explicite -- "le fond de
  -- cadre des ennemis peut être beaucoup plus discret") : servait avant de
  -- plaque opaque plein Theme.panel, masquant le décor derrière chaque
  -- ennemi -- ne reste plus qu'un très léger voile, le contour (ligne
  -- ci-dessous) et les éléments dessinés par-dessus (barre de PV, portrait,
  -- badges) suffisent déjà à délimiter la zone.
  -- Élite : PLUS de cadre doré/halo scintillant (2026-09-02, revirement
  -- explicite -- "le cadre doré et scintillant que j'ai demandé n'est pas
  -- bon... il ne faut pas mettre de cadre, comme pour un ennemi normal") :
  -- cadre strictement identique à un ennemi normal désormais -- le signal
  -- "doré et scintillant" se déplace sur la barre de PV elle-même (voir plus
  -- bas, hp_color) ; le halo/contour dorés d'origine sont retirés d'ici.
  set(Theme.panel, trail_dead and 0.06 or 0.12)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  if awaiting_enemy_target then
    set(Theme.energy)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)
  end

  -- Barre de PV au-dessus du portrait, pas en dessous (2026-08-27, demande
  -- explicite) : bar 4->20, épaissie (10->16) avec la valeur DEDANS plutôt
  -- qu'une ligne à part (même traitement que draw_hero) ; portrait décalé de
  -- 4 à 26 pour lui laisser la place. Nom/niveau restent hors du cadre
  -- (2026-08-27, voir tooltip_lines) : rien ne les remplace ici.
  -- `trail_dead`, pas `dead` (2026-08-30) : la barre (et sa traînée jaune,
  -- voir hp_bar) reste affichée tant que la traînée n'a pas fini de
  -- rattraper 0, même si `e.hp` est déjà tombé à 0/négatif.
  set(Theme.text, trail_dead and 0.45 or 1)
  if not trail_dead then
    -- Élite : la barre de PV elle-même est dorée et scintillante (2026-09-02,
    -- demande explicite, remplace l'ancien cadre doré retiré plus haut) --
    -- oscille entre Theme.accent et un or plus clair (jamais un simple flat
    -- Theme.accent, sinon "scintillant" ne se lirait pas).
    local hp_color = Theme.hp
    if e.elite then
      local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
      hp_color = {
        Theme.accent[1] + (1 - Theme.accent[1]) * pulse * 0.5,
        Theme.accent[2] + (1 - Theme.accent[2]) * pulse * 0.5,
        Theme.accent[3] + (1 - Theme.accent[3]) * pulse * 0.5,
      }
    end
    hp_bar(8, 4, r.w - 16, 16, e.hp / e.max_hp, trail / e.max_hp, hp_color)
    text_v_centered(math.max(0, e.hp) .. "/" .. e.max_hp .. " PV", 0, 4, r.w, 16, 10, Theme.text)
  end
  -- Portrait agrandi (2026-08-27, demande explicite -- "toutes les images des
  -- aventuriers et des ennemis doivent être plus gros") : 46->54.
  -- Regrandi (2026-08-30, redemandé explicitement) : 54->62, remonté de 24 à
  -- 20 pour garder exactement le même bas (contact avec la barre de PV
  -- au-dessus à y=20, contact avec la rangée de badges en dessous à y=82) --
  -- aucun autre élément du cadre n'a besoin de bouger.
  -- Image au sol/en vol (2026-08-30, second boss -- l'Aigle Géant, "il
  -- possède 2 images : 1 à terre, et 1 en vol") : clé dérivée de `e.vol`
  -- plutôt que `e.template_id` seul -- voir Sprites.enemy/DRAW_BY_ENEMY
  -- ("aigle-vol"), qui suivent le même schéma de chemin générique que
  -- n'importe quel autre template_id, aucun code spécifique ajouté là-bas.
  -- Sans effet sur tout autre ennemi (e.vol vaut 0 pour eux tous, voir
  -- Encounter.instantiate_enemy).
  local enemy_icon_key = (e.vol or 0) > 0 and (e.template_id .. "-vol") or e.template_id
  draw_enemy_icon(enemy_icon_key, e.icon, e.label, 0, 20, r.w, 62, Theme.text)
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
  if not trail_dead then
    local badges = {}
    -- Sensibilité au feu (2026-08-24, demande explicite) : pas un statut
    -- temporaire (pas de valeur, jamais retiré) -- toujours en tête de rangée
    -- tant que l'Homme Arbre est vivant, voir tooltip_lines pour le texte
    -- complet et Combat.damage_multiplier pour le bonus réel.
    -- Défense retirée de cette rangée (2026-08-27) : affichée à part, en plus
    -- gros, voir draw_defense_badge_big appelé plus haut près du portrait.
    if e.template_id == "homme-arbre" then badges[#badges + 1] = { key = "fireweak", abbr = "FEU" } end
    if (e.vol or 0) > 0 then badges[#badges + 1] = { key = "vol", abbr = "VOL" } end
    -- Puissance/Incandescence (2026-09-02, bug signalé -- absentes de cette
    -- rangée jusqu'ici : un ennemi qui en gagnait n'affichait AUCUN badge sur
    -- son propre cadre, contrairement à un héros -- seule l'infobulle le
    -- révélait) : même traitement que côté héros (draw_hero ci-dessus).
    if (e.puissance or 0) > 0 then badges[#badges + 1] = { key = "puissance", abbr = "PUI", value = e.puissance } end
    if (e.incandescence or 0) > 0 then badges[#badges + 1] = { key = "incandescence", abbr = "INCA", value = e.incandescence } end
    if (e.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = e.saignements } end
    if (e.brulure or 0) > 0 then badges[#badges + 1] = { key = "brulure", abbr = "BRU", value = e.brulure } end
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

  -- Étiquette de cible retirée (2026-08-30, demande explicite -- "il n'est
  -- plus nécessaire d'indiquer la cible d'un ennemi à l'aide de l'étiquette
  -- comportant son nom, la flèche est suffisante") : voir
  -- draw_enemy_target_arrows, seul indicateur de cible restant.

  draw_enemy_crack(r, crack_p)
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
-- fait varier avec Puissance/Incapacité/Vulnérabilité). "necrose" (2026-08-29,
-- Nécromancien) : se comporte exactement comme "etincelle" pour ce calcul
-- (Vulnérabilité s'applique, Puissance non -- réservée à "physique").
local DAMAGE_KEYWORDS = { epee = true, etincelle = true, fireball = true, necrose = true }

--- Même principe que scale_near_keyword ci-dessus, mais ADDITIF plutôt que
-- multiplicatif (2026-08-29, Inspiration -- "+6 flat", pas un pourcentage) :
-- voir consume_inspiration dans combat.lua, seule source de vérité sur le
-- montant réel -- cette fonction ne fait que prévisualiser le MÊME calcul
-- dans le texte affiché.
local function add_near_keyword(text, keyword, amount)
  local out = text
  out = out:gsub('(%d+)(%s+"' .. keyword .. '")', function(num, rest)
    return tostring(tonumber(num) + amount) .. rest
  end)
  out = out:gsub('("' .. keyword .. '"%s+)(%d+)', function(pre, num)
    return pre .. tostring(tonumber(num) + amount)
  end)
  return out
end

-- Mots-clés qui portent un montant de dégâts/soin/bouclier (2026-08-29,
-- Inspiration -- "+6 flat au PREMIER effet de dégâts/soin/bouclier
-- déclenché", voir consume_inspiration dans combat.lua) : ordre FIXE (pas
-- `pairs`, dont l'itération n'est pas déterministe) -- une carte qui porte
-- PLUSIEURS de ces mots-clés (ex. Rite mineur : "necrose" ET "soin") ne doit
-- appliquer le bonus qu'à UN SEUL, toujours le même d'une frame à l'autre ;
-- les dégâts priment sur soin/bouclier, choix arbitraire mais cohérent.
local INSPIRATION_KEYWORDS_ORDERED = { "epee", "etincelle", "fireball", "necrose", "soin", "bouclier" }

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
  -- Additif (Inspiration) AVANT multiplicatif (Puissance/Incapacité/
  -- Vulnérabilité) -- 2026-08-30, demande explicite, même ordre que
  -- Combat.deal_damage (voir son commentaire) : l'aperçu doit rester
  -- IDENTIQUE à la résolution réelle, jamais un calcul divergent.
  if hero and (hero.inspiration or 0) > 0 then
    for _, kw in ipairs(INSPIRATION_KEYWORDS_ORDERED) do
      if Glossary.has_keyword(def.desc, kw) then text = add_near_keyword(text, kw, 6) break end
    end
  end
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

  -- Coût variable en Corruption (2026-08-29, Nécromancien -- "1 (+X, 0-N
  -- Corruption)") : pastille OVALE (jamais ronde comme énergie/mana, demande
  -- explicite -- doit se distinguer d'un coup d'œil d'un coût FIXE) --
  -- affiche le PLAFOND en dur ("X(0-3)"), jamais la valeur actuellement
  -- disponible -- c'est le TEXTE de la carte (desc_text, substitué par
  -- l'appelant, voir draw_hand) qui porte le X recalculé en temps réel,
  -- jamais cette pastille.
  if def.corruption_cost_cap then
    set(Theme.corruption); love.graphics.ellipse("fill", 40, 12, 16, 8)
    set(Theme.bg or { 0.05, 0.1, 0.1 })
    love.graphics.setFont(Fonts.get(8))
    love.graphics.printf("X(0-" .. def.corruption_cost_cap .. ")", 24, 8, 32, "center")
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
    -- Icône agrandie (2026-08-30, demande explicite -- "seulement l'icône") :
    -- 18->24 de rayon, recentrée un peu plus bas pour garder une marge avant
    -- le texte "X / Y" juste en dessous (r.y + 52), lui-même inchangé.
    Sprites.draw_centered(icon, r.x + r.w / 2, r.y + 26, 24)
  end
  text(state.energy .. " / " .. Game.TURN_START_ENERGY, r.x, r.y + 52, r.w, 24, Theme.energy)
end

-- "PO" (or, 2026-09-02, demande explicite) : même esprit que
-- draw_energy_display (icône + texte coloré) mais réduit à une ligne
-- compacte de 14px -- voir View.gold_display_rect. Cible d'arrivée des
-- pièces animées de l'écran de victoire (draw_coin_flights).
local function draw_gold_display(state)
  local r = View.gold_display_rect
  local icon = Sprites.keyword("or")
  if icon then
    love.graphics.setColor(1, 1, 1, 1)
    Sprites.draw_centered(icon, r.x + 7, r.y + 7, 7)
  end
  text(tostring(state.gold), r.x + 18, r.y, r.w - 18, r.h, Theme.gold, "left")
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
  -- "Voir le deck" (2026-08-30, demande explicite) : seulement en combat
  -- (screen == "playing") -- pendant un évènement "camp", ce coin de l'écran
  -- est de toute façon recouvert par le voile sombre de l'écran en question,
  -- voir View.deck_view_button.
  if controller.screen == "playing" then
    local db = View.deck_view_button
    panel(db.x, db.y, db.w, db.h, Theme.panel_light)
    set(Theme.muted); love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", db.x, db.y, db.w, db.h, 6, 6)
    text(db.label, db.x, db.y + db.h / 2 - 5, db.w, 11, Theme.text, "center")
  end

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
  -- Cartes déjà dans state.hand mais dont le vol pioche -> main n'a pas
  -- encore démarré (2026-08-21, bug signalé -- pendant l'attente de l'anim
  -- d'énergie ou d'un remélange défausse -> pioche en cours de pioche) : sans
  -- ça, elles s'affichaient "déjà là" en pleine opacité avant de disparaître
  -- puis revoler depuis la pioche au moment où leur vol démarrait vraiment.
  -- Calcul partagé avec View.hand_hit (2026-08-30, voir View.hand_hiding_uids) --
  -- jamais 2 calculs séparés qui pourraient diverger.
  local hiding_uids = View.hand_hiding_uids(controller)

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
    local owner = Combat.hero_by_id(state, def.class_id)
    local desc_text, has_bonus = def.desc, false
    if previewing_hero then
      desc_text = preview_desc(def, previewing_hero, previewing_target)
      has_bonus = desc_text ~= def.desc
    end
    -- Coût variable en Corruption (2026-08-29, Nécromancien -- "la valeur du
    -- X est bien mise à jour en temps réel dans le texte de la carte", demande
    -- explicite) : contrairement au bonus d'Inspiration ci-dessus (limité à
    -- la carte SÉLECTIONNÉE, "dès que le joueur sélectionne la carte"), celui-ci
    -- s'applique à TOUTE carte en main, sélectionnée ou non -- substitution du
    -- littéral "X" par min(corruption actuelle, plafond), recalculée CHAQUE
    -- frame puisque draw_hand tourne à chaque frame (aucun état à mettre à jour
    -- à part). `owner` peut être nil (carte orpheline improbable) -- (owner or {})
    -- retombe alors sur 0, jamais une erreur.
    if def.corruption_cost_cap then
      local x = math.min((owner or {}).corruption or 0, def.corruption_cost_cap)
      desc_text = desc_text:gsub("X", tostring(x))
    end
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
  -- Incandescence (2026-09-02, statut Volcan) : même mécanisme que Puissance
  -- ci-dessus, sa propre entrée de glossaire (voir glossary.lua).
  { field = "incandescence", glossary_key = "incandescence", label = "Incandescence" },
  { field = "saignements", glossary_key = "saignement" },
  { field = "brulure", glossary_key = "brulure", label = "Brûlure" },
  { field = "incapacite", glossary_key = "incapacite" },
  { field = "vulnerabilite", glossary_key = "vulnerabilite" },
  { field = "provocation", glossary_key = "provocation" },
  -- "Vol" (2026-08-30, second boss -- Aigle Géant) : `hide_value` (toujours
  -- 1, jamais un compteur qui empile -- même traitement que Camouflé).
  { field = "vol", glossary_key = "vol", label = "Vol", hide_value = true },
  -- Inspiration/Encore (2026-08-29, Barde -- voir badges dans draw_hero) :
  -- même mécanisme générique, glossary_key pointe vers les entrées ajoutées
  -- dans glossary.lua.
  { field = "inspiration", glossary_key = "inspiration" },
  { field = "encore_extra_plays", glossary_key = "encore", label = "Encore" },
}

-- `seen` (optionnel, 2026-08-30, demande explicite -- "Tous les mots clés
-- présents dans l'info bulle doivent être expliqués au moins 1 fois DANS
-- CETTE MÊME INFOBULLE") : table PARTAGÉE avec le reste de tooltip_lines
-- (clé = g.key), déjà marquée par toute ligne de description libre affichée
-- AVANT ce statut (voir add_described_line plus bas) -- si ce mot-clé est
-- déjà expliqué ailleurs dans la MÊME infobulle, cette ligne garde son nom +
-- sa valeur mais N'Y RÉPÈTE PAS l'explication (déjà lue juste au-dessus).
-- Absent (autres appelants existants, ex. draw_hero pour un badge isolé hors
-- infobulle) : comportement inchangé, explication toujours incluse.
local function active_status_lines(unit, seen)
  local lines = {}
  for _, spec in ipairs(STATUS_TOOLTIP_FIELDS) do
    local value = unit[spec.field]
    local active = type(value) == "number" and value > 0
    if active then
      local g = Glossary.find_term(spec.glossary_key)
      local label = spec.label or (g and (g.label or g.icon)) or spec.field
      local explain = spec.explain or (g and g.explain ~= "" and g.explain) or ""
      local already_explained = seen and g and seen[g.key]
      if seen and g then seen[g.key] = true end
      local line_text = label .. (spec.hide_value and "" or (" " .. value))
        .. ((explain ~= "" and not already_explained) and (" — " .. explain) or "")
      -- Sprites.status (pas Sprites.keyword/le has_icon du glossaire, qui ne
      -- couvre que le texte de carte) -- ce sont les mêmes icônes déjà visibles
      -- sur les badges de statut de l'encart, pas de nouvel asset à générer.
      local icon = Sprites.status(spec.field)
      lines[#lines + 1] = icon and { text = line_text, icon = icon } or line_text
    end
  end
  return lines
end

--- Ligne d'explication pour UN terme du glossaire -- même format que le cas
-- "card" de tooltip_lines ci-dessous (icône en préfixe si has_icon, label +
-- related + explain) : une seule façon de présenter un mot-clé dans toute
-- l'UI, jamais un texte ad hoc différent par écran.
local function keyword_explanation_line(g)
  local label = g.has_icon and ((g.label or g.key) .. " (" .. g.key .. ")") or g.key
  local related = g.related ~= "" and (" — " .. g.related) or ""
  local line_text = label .. related .. (g.explain ~= "" and (" : " .. g.explain) or "")
  return g.has_icon and { text = line_text, icon = Sprites.keyword(g.key) } or line_text
end

--- Ajoute à `lines` la version affichable de `raw_text` (guillemets des
-- mots-clés retirés, voir Glossary.render_card_text) précédée de `prefix`
-- (optionnel, ex. "Le Puissant — "), PUIS l'explication de chaque mot-clé
-- qu'elle cite entre guillemets mais qui n'a pas déjà été expliqué DANS CETTE
-- INFOBULLE (2026-08-30, demande explicite -- voir son commentaire complet
-- sur active_status_lines ci-dessus ; exemple concret signalé : la
-- malédiction "L'Amnésique" mentionne "Amnésie" sans jamais dire ce que ça
-- fait). `seen` : table PARTAGÉE par tout l'appel à tooltip_lines -- si un
-- même mot-clé revient dans une autre ligne de la même infobulle (ex.
-- "Puissance" à la fois dans la description d'une bénédiction ET comme statut
-- actif), son explication ne s'affiche qu'une seule fois au total.
local function add_described_line(lines, raw_text, seen, prefix)
  lines[#lines + 1] = (prefix or "") .. Glossary.render_card_text(raw_text)
  for _, g in ipairs(Glossary.keywords_present(raw_text)) do
    if not seen[g.key] then
      seen[g.key] = true
      lines[#lines + 1] = keyword_explanation_line(g)
    end
  end
end

local function tooltip_lines(controller)
  local h = controller.hover
  if h.kind == "hero" then
    local hero = Combat.hero_by_id(controller.state, h.target)
    if not hero then return nil end
    -- Description de classe (2026-08-24, demande explicite) : en tête de
    -- l'infobulle, avant les statuts actifs -- voir Heroes.class_description.
    -- `seen` (2026-08-30, demande explicite -- voir son commentaire complet
    -- sur active_status_lines) : partagée par TOUTE cette infobulle, pour
    -- qu'un mot-clé cité 2 fois (ex. classe + bénédiction, ou bénédiction +
    -- statut actif) ne soit expliqué qu'une seule fois au total.
    local lines = {}
    local seen = {}
    local desc = Heroes.class_description[hero.class_id]
    if desc then add_described_line(lines, desc, seen) end
    -- Bénédiction/malédiction du Temple (2026-08-28/29, demande explicite) :
    -- juste après la description de classe, avant les statuts de combat --
    -- ce sont des effets permanents du run, pas des statuts temporaires (voir
    -- active_status_lines). "Le descriptif s'ajoute à l'infobulle de
    -- l'aventurier" (2026-08-29) : ni l'un ni l'autre n'a de badge cliquable
    -- séparé, cette ligne EST leur seule explication en jeu (voir aussi le
    -- badge sur le cadre, draw_hero, qui pointe ici).
    if hero.blessing then
      local blessing = Temple.by_id(hero.blessing)
      if blessing then add_described_line(lines, blessing.desc, seen, blessing.name .. " — ") end
    end
    if hero.curse then
      local curse = Temple.by_id(hero.curse)
      if curse then add_described_line(lines, curse.desc, seen, curse.name .. " — ") end
    end
    for _, l in ipairs(active_status_lines(hero, seen)) do lines[#lines + 1] = l end
    return hero.name, lines
  elseif h.kind == "enemy" then
    local e = Combat.enemy_by_id(controller.state, h.target)
    if not e then return nil end
    local template = Enemies.by_id(e.template_id)
    local lines = {}
    local seen = {}
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
      add_described_line(lines, m.text, seen, m.name .. " — ")
    end
    for _, l in ipairs(active_status_lines(e, seen)) do lines[#lines + 1] = l end
    lines[#lines + 1] = "PV max " .. e.max_hp
    -- Élite (2026-09-01, demande explicite -- "nom entouré de 2 étoiles") :
    -- les ennemis n'ont pas de plaque-nom permanente sur leur cadre (voir
    -- draw_enemy) -- confirmé au survol via ce titre de tooltip. Plus de
    -- caractère "\u{2605}" inséré dans le texte (2026-09-02, bug signalé --
    -- ne s'affichait jamais, la police custom de ce jeu ne contient pas ce
    -- glyphe) : draw_tooltip dessine désormais une vraie icône vectorielle
    -- (Icons.draw_status("elite", ...)) de part et d'autre du titre.
    return e.name .. " Nv." .. e.level, lines
  elseif h.kind == "card" then
    local def = h.target
    local terms = Glossary.keywords_present(def.desc)
    if #terms == 0 then return def.name, { "Aucun mot-clé de glossaire sur cette carte." } end
    local lines = {}
    for _, g in ipairs(terms) do lines[#lines + 1] = keyword_explanation_line(g) end
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
    -- conventionnel") : le descriptif complet vit UNIQUEMENT ici. Mots-clés
    -- expliqués à la suite (2026-08-30, demande explicite, exemple donné --
    -- "L'Amnésique stipule que les cartes gagnent Amnésie, mais rien
    -- n'explique son fonctionnement à cet endroit") : voir add_described_line.
    local effect = h.target
    local lines = {}
    add_described_line(lines, effect.desc, {})
    return effect.name, lines
  elseif h.kind == "team_hero" then
    -- Écran "Choisis ton équipe" (2026-08-29) : contrairement au cas "hero"
    -- ci-dessus, aucun héros réel n'existe encore dans controller.state à ce
    -- stade (avant Game.reset_run) -- `h.target` porte directement l'ID du
    -- def (Heroes.by_id), pas un héros de state.heroes.
    local def = Heroes.by_id(h.target)
    if not def then return nil end
    local desc = Heroes.class_description[def.class_id]
    if not desc then return def.name, {} end
    local lines = {}
    add_described_line(lines, desc, {})
    return def.name, lines
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
          -- push/origin()/pop (2026-08-30, bug signalé -- "les cartes ne sont
          -- pas entières, elles sont découpées et incomplètes") : le canvas
          -- fait exactement CARD_W x CARD_H en pixels PHYSIQUES, mais
          -- l'échelle globale (love.graphics.scale(SCALE,SCALE), voir
          -- main.lua) restait active PENDANT le rendu dedans -- le contenu se
          -- dessinait ~15% trop grand pour son propre canvas et se faisait
          -- rogner sur les bords droit/bas. Neutralisée le temps du rendu
          -- DANS le canvas ; restaurée avant de le ressortir (love.graphics.
          -- draw juste en dessous), qui doit lui bien suivre l'échelle ambiante.
          love.graphics.push()
          love.graphics.origin()
          -- Restaure le canvas PRÉCÉDENT plutôt qu'un `setCanvas()` sans
          -- argument (2026-08-30, bug évité -- ce dernier vise toujours
          -- l'écran, jamais "ce qui était actif avant" : casserait tout
          -- rendu qui appellerait cette fonction depuis L'INTÉRIEUR d'un
          -- autre canvas déjà actif, ex. la fenêtre "camp" qui fond en
          -- entrée, voir draw_camp_entrance) -- même correctif appliqué à
          -- tous les usages de card_flight_canvas dans ce fichier.
          local prev_canvas = love.graphics.getCanvas()
          love.graphics.setCanvas(card_flight_canvas)
          love.graphics.clear(0, 0, 0, 0)
          draw_card_face(a.def, CARD_W, CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
          love.graphics.setCanvas(prev_canvas)
          love.graphics.pop()
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
        -- Même correctif que ci-dessus (goto continue) -- voir son commentaire.
        love.graphics.push()
        love.graphics.origin()
        local prev_canvas = love.graphics.getCanvas()
        love.graphics.setCanvas(card_flight_canvas)
        love.graphics.clear(0, 0, 0, 0)
        draw_card_face(a.def, CARD_W, CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
        love.graphics.setCanvas(prev_canvas)
        love.graphics.pop()
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

-- Rendu des cartes de draft (écran de victoire), REGROUPÉ (2026-09-02) sous
-- une seule locale de chunk `DraftFx` -- voir le commentaire sur la limite
-- des 200 locales près de CARD_W/CARD_H plus haut. `DraftFx.front(def)` :
-- extrait du rendu jusque-là inline de l'écran de victoire, réutilisé par
-- `.fading` (cartes non choisies, "disparaissent doucement") ET `.flight`
-- (carte choisie, "rejoint la pioche dans un mouvement ample") -- toutes
-- deux ont besoin de dessiner CETTE face à un endroit/une échelle/une
-- opacité qui ne sont plus ceux de la grille de repos (voir View.draw). Même
-- origine que draw_card_face (centrage/agrandissement 2026-08-24, remontage
-- anti-liseré-mangé) : taille différente (W/H ci-dessous, pas CARD_W/CARD_H),
-- donc dupliqué plutôt que réutilisé.
local DraftFx
do
  local W, H = 130, 190
  local fade_canvas

  local function front(def)
    local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
    panel(0, 0, W, H, palette.bg)
    set(def.tier == "avance" and Theme.accent or Theme.black)
    love.graphics.setLineWidth(def.tier == "avance" and 3 or 2)
    love.graphics.rectangle("line", 0, 0, W, H, 10, 10)
    set(palette.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 3, 3, W - 6, H - 6, 8, 8)
    love.graphics.setLineWidth(1)
    set(Theme.energy); love.graphics.circle("fill", 16, 14, 10)
    set(Theme.bg); love.graphics.setFont(Fonts.get(12)); love.graphics.printf(tostring(def.cost), 6, 7, 20, "center")
    if def.mana_cost then
      set(Theme.mana); love.graphics.circle("fill", 38, 14, 9)
      set(Theme.bg); love.graphics.setFont(Fonts.get(11))
      love.graphics.printf(tostring(def.mana_cost), 30, 9, 16, "center")
    end
    if def.corruption_cost_cap then
      set(Theme.corruption); love.graphics.ellipse("fill", 46, 14, 20, 10)
      set(Theme.bg); love.graphics.setFont(Fonts.get(10))
      love.graphics.printf("X(0-" .. def.corruption_cost_cap .. ")", 26, 9, 40, "center")
    end
    name_badge(def.name, 4, 26, W - 8, 16, palette.border, Theme.bg, 2, 2)
    RichText.draw(def.desc, 4, 50, W - 8, 11, Theme.muted)
    local hero_name = Heroes.class_name[def.class_id]
    if hero_name then
      set(Theme.black, 0.55)
      love.graphics.rectangle("fill", 0, H - 20, W, 16)
      text(hero_name, 0, H - 18, W, 12, palette.border, "center")
    end
  end

  -- Fondu d'une carte NON choisie (2026-09-02, demande explicite -- "les
  -- autres disparaissent doucement") : même contrainte que draw_card_flights
  -- (set() ne peut pas multiplier un alpha global sur tous les tracés de
  -- `front`) -- rendue sur un canvas dédié pour appliquer le fondu d'un coup,
  -- canvas séparé de card_flight_canvas (taille différente, W/H plutôt que
  -- CARD_W/CARD_H).
  local function fading(def, r, alpha)
    if alpha <= 0 then return end
    fade_canvas = fade_canvas or love.graphics.newCanvas(W, H)
    love.graphics.push()
    love.graphics.origin()
    local prev_canvas = love.graphics.getCanvas()
    love.graphics.setCanvas(fade_canvas)
    love.graphics.clear(0, 0, 0, 0)
    front(def)
    love.graphics.setCanvas(prev_canvas)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(fade_canvas, r.x, r.y, 0, r.w / W, r.h / H)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Vol "ample" de la carte CHOISIE vers la pioche (2026-09-02, demande
  -- explicite -- "la carte choisie rejoint la pioche dans un mouvement
  -- ample") : arc de Bézier quadratique (maths reprises telles quelles de
  -- quad_bezier plus bas dans ce fichier -- inlinées ici plutôt qu'appelées,
  -- ce bloc `do` doit rester utilisable AVANT que ce chunk atteigne sa
  -- déclaration) plutôt qu'une ligne droite -- point de contrôle remonté
  -- nettement au-dessus du segment départ->arrivée pour un vrai arc "ample",
  -- pas un simple glissement. Rétrécit en même temps jusqu'à la taille de la
  -- pioche (View.deck_pile_rect) -- alpha JAMAIS réduit (contrairement à
  -- `fading` ci-dessus) : elle reste pleinement visible tout le vol, elle
  -- REJOINT la pioche, elle ne s'efface pas.
  local ARC_HEIGHT = 140
  local function flight(def, from, anim)
    local p = math.min(1, anim.t / anim.duration)
    local ease = 1 - (1 - p) * (1 - p) -- easeOutQuad
    local to = View.deck_pile_rect
    local x0, y0 = from.x + from.w / 2, from.y + from.h / 2
    local x1, y1 = to.x + to.w / 2, to.y + to.h / 2
    local cx = (x0 + x1) / 2
    local cy = math.min(y0, y1) - ARC_HEIGHT
    local mt = 1 - ease
    local x = mt * mt * x0 + 2 * mt * ease * cx + ease * ease * x1
    local y = mt * mt * y0 + 2 * mt * ease * cy + ease * ease * y1
    local w = from.w + (to.w - from.w) * ease
    local h = from.h + (to.h - from.h) * ease
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(w / W, h / H)
    love.graphics.translate(-W / 2, -H / 2)
    front(def)
    love.graphics.pop()
  end

  DraftFx = { w = W, h = H, front = front, fading = fading, flight = flight }
end

-- Pièces d'or de l'écran de victoire (2026-09-02, demande explicite --
-- "elles volent depuis cette indication jusqu'à la bourse de l'équipe") :
-- même idiome que draw_card_flights ci-dessus (interpolation pure, aucune
-- logique de jeu ici -- controller.coin_anims est peuplé par
-- Controller:click_victory_gold), mais pas besoin de canvas -- une icône
-- "or" simple (Sprites.draw_centered), pas une face de carte complète.
local function draw_coin_flights(controller)
  local icon = Sprites.keyword("or")
  if not icon then return end
  for _, a in ipairs(controller.coin_anims) do
    if a.elapsed >= a.delay then
      local p = math.min(1, (a.elapsed - a.delay) / a.duration)
      local ease = 1 - (1 - p) ^ 2 -- easeOutQuad, même famille que le vol de carte
      local fx, fy = a.from.x + a.from.w / 2, a.from.y + a.from.h / 2
      local tx, ty = a.to.x + a.to.w / 2, a.to.y + a.to.h / 2
      local x = fx + (tx - fx) * ease
      local y = fy + (ty - fy) * ease
      love.graphics.setColor(1, 1, 1, 1)
      Sprites.draw_centered(icon, x, y, 12)
    end
  end
end

-- Bourse rejouée PAR-DESSUS le voile noir de l'écran de victoire (2026-09-02,
-- demande explicite -- "la bourse est actuellement dessous le voile noir (et
-- c'est normal). Pourtant, quand les pièces volent... j'aimerais que la
-- bourse apparaisse AUSSI par dessus et saute à chaque pièce qui arrive
-- dedans, puis fade quand c'est fini") : draw_gold_display (dessinée plus
-- haut, sous le voile) reste TELLE QUELLE -- ceci est un second rendu,
-- indépendant, au MÊME endroit (View.gold_display_rect), déclenché par
-- controller.gold_purse_overlay (voir Controller:click_victory_gold/
-- Controller:update). `pop_t` (remis à 0 à chaque arrivée de pièce) pilote un
-- bond d'échelle qui se calme (même famille de courbe que status_badge) ;
-- `fade_t` (posé seulement après la DERNIÈRE pièce) pilote le fondu final.
local function draw_gold_purse_overlay(controller)
  local a = controller.gold_purse_overlay
  if not a then return end
  local r = View.gold_display_rect
  local pop_p = math.min(1, a.pop_t / a.pop_duration)
  local scale = 1 + 0.4 * (1 - pop_p)
  local alpha = a.fade_t and math.max(0, 1 - a.fade_t / a.fade_duration) or 1
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2

  set(Theme.gold, 0.3 * alpha)
  love.graphics.circle("fill", r.x + 7, cy, 20 * scale)

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)
  local icon = Sprites.keyword("or")
  if icon then
    love.graphics.setColor(1, 1, 1, alpha)
    Sprites.draw_centered(icon, r.x + 7, r.y + 7, 7)
  end
  love.graphics.setFont(Fonts.get(9))
  set(Theme.gold, alpha)
  love.graphics.printf(tostring(controller.state.gold), r.x + 18, r.y, r.w - 18, "left")
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

-- Nombre de dégâts/soin flottant (2026-08-09, party "amélioration des
-- visuels") : monte et s'estompe depuis Controller:spawn_floater, couleur
-- selon le sens (dégâts/soin) -- pas de logique de jeu ici, juste l'interpolation.
local FLOATER_RISE = 34
-- "discretion" (2026-08-28, demande explicite) : même famille visuelle que
-- "heal" (traitement par défaut, voir draw_floaters plus bas), juste une
-- teinte propre (Theme.discretion, déjà celle du texte "DISCRÉTION N" sous le
-- portrait) pour qu'un flottant de Discrétion ne se confonde jamais avec un
-- vrai soin.
-- "decay" (2026-08-30, demande explicite -- décroissance de fin de tour,
-- Incapacité/Vulnérabilité -- voir Controller:react_to_status_decay) : teinte
-- neutre/éteinte (Theme.muted), jamais une couleur de statut précise -- ce
-- flottant marque juste "un effet perd 1 point", pas lequel.
local FLOATER_COLOR = { damage = "hp", heal = "heal", discretion = "discretion", decay = "muted" }
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
    -- "decay" DESCEND, tous les autres montent (2026-08-30, demande
    -- explicite -- "un -1 qui descend doucement en fade") : signe inversé
    -- sur FLOATER_RISE plutôt qu'une 2ᵉ constante, même vitesse/même courbe
    -- dans les 2 sens.
    local y = f.kind == "decay" and (f.y + ease * FLOATER_RISE) or (f.y - ease * FLOATER_RISE)
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
-- `pt.canvas`/`pt.quad`/`pt.tile` (optionnels, 2026-08-30, mort d'un ennemi --
-- voir Controller:spawn_enemy_shatter/View.capture_enemy_shatter) : une tuile
-- DÉCOUPÉE DANS L'IMAGE RÉELLE de l'ennemi plutôt qu'un simple carré de
-- couleur -- même trajectoire/fondu que les autres particules, juste un
-- rendu différent (texture au lieu d'un rectangle plein), avec en plus une
-- légère rotation propre (pt.rot0/pt.vrot) pour l'effet "débris".
local PARTICLE_GRAVITY = 160

local function draw_particles(controller)
  for _, pt in ipairs(controller.particles) do
    local p = math.min(1, pt.t / (pt.duration or controller.particle_duration))
    local gravity = pt.gravity or PARTICLE_GRAVITY
    local x = pt.x + pt.vx * pt.t
    local y = pt.y + pt.vy * pt.t + 0.5 * gravity * pt.t * pt.t
    if pt.canvas and pt.quad then
      love.graphics.setColor(1, 1, 1, 1 - p)
      local rot = (pt.rot0 or 0) + (pt.vrot or 0) * pt.t
      love.graphics.draw(pt.canvas, pt.quad, x, y, rot, 1, 1, pt.tile / 2, pt.tile / 2)
    else
      set(pt.color or Theme.hp, 1 - p)
      love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

--- Rend l'icône (sprite réel si dispo, sinon silhouette vectorielle -- voir
-- Icons.draw_enemy, même appel que draw_enemy_icon ci-dessus) d'un ennemi
-- dans un nouveau canvas carré de `size` px, puis le découpe en `grid` x
-- `grid` Quads (2026-08-30, demande explicite -- "que ce soit l'image de
-- l'ennemi elle-même qui soit découpée en petits carrés qui partent dans
-- toutes les directions", remplace un burst de particules grises génériques) :
-- appelée UNE SEULE FOIS par Controller:spawn_enemy_shatter au moment de
-- l'explosion (jamais à chaque frame) -- le canvas et les Quads résultants
-- sont ensuite portés par chaque particule pour toute leur durée de vie
-- (voir pt.canvas/pt.quad, draw_particles ci-dessus), jusqu'à disparition.
function View.capture_enemy_shatter(template_id, size, grid)
  local canvas = love.graphics.newCanvas(size, size)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  Icons.draw_enemy(template_id, size / 2, size / 2, size / 2, Theme.text)
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
  local tile = size / grid
  local quads = {}
  for gy = 0, grid - 1 do
    for gx = 0, grid - 1 do
      quads[#quads + 1] = { quad = love.graphics.newQuad(gx * tile, gy * tile, tile, tile, size, size), gx = gx, gy = gy }
    end
  end
  return canvas, quads, tile
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
  -- Position figée dès l'apparition (2026-08-30, demande explicite -- "elles
  -- ne suivent plus la souris, elles restent toujours à la même place
  -- jusqu'à disparition") : capturée une seule fois ici, à la toute première
  -- frame où hover_ready() est vrai (Controller:set_hover les remet à nil
  -- dès que kind/target change, donc une nouvelle cible recapture bien une
  -- nouvelle position).
  local hover = controller.hover
  if not hover.frozen_x then
    local raw_x, raw_y = love.mouse.getPosition()
    hover.frozen_x, hover.frozen_y = raw_x / SCALE, raw_y / SCALE
  end
  local mx, my = hover.frozen_x, hover.frozen_y
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
  -- Élite (2026-09-02, correctif -- voir Icons.draw_status("elite",...) et
  -- son commentaire pour le pourquoi) : étoiles vectorielles de part et
  -- d'autre du titre, remplace le "\u{2605}" texte qui ne s'affichait jamais.
  local hover_enemy = hover.kind == "enemy" and Combat.enemy_by_id(controller.state, hover.target)
  if hover_enemy and hover_enemy.elite then
    love.graphics.setColor(1, 1, 1, 1)
    Icons.draw_status("elite", x + 14, y + 11, 7, Theme.accent)
    Icons.draw_status("elite", x + w - 14, y + 11, 7, Theme.accent)
    text(title, x + 22, y + 6, w - 44, 10, Theme.status, "center")
  else
    text(title, x + 8, y + 6, w - 16, 10, Theme.status, "left")
  end
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
    -- Départ aux PIEDS de l'ennemi (2026-08-30, demande explicite -- "un
    -- essai, il est possible que je change d'avis" -- plutôt que le bas du
    -- CADRE, `er.y + er.h`, bien plus bas que le personnage lui-même une
    -- fois la barre de PV/les badges/le télégraphe comptés) : même y que le
    -- bas du portrait (voir draw_enemy_icon dans draw_enemy, y=20 taille 62
    -- -> bas à 82), à resynchroniser à la main si ces chiffres bougent, pas
    -- de constante partagée pour un simple point de départ visuel.
    draw_arrow(
      er.x + er.w / 2, er.y + 82, hr.x + hr.w / 2 + arrival_offset, hr.y,
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
-- push/origin()/pop autour du rendu DANS le canvas (2026-08-30, bug signalé --
-- voir le commentaire équivalent sur draw_card_flights plus haut) : sans ça,
-- l'échelle globale (love.graphics.scale(SCALE,SCALE), main.lua) reste active
-- pendant ce rendu et le contenu déborde du canvas (taille physique fixe),
-- se faisant rogner sur les bords droit/bas.
local function draw_faded_card(def, x, y, alpha, desc_color, highlight)
  card_flight_canvas = card_flight_canvas or love.graphics.newCanvas(CARD_W, CARD_H)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(card_flight_canvas)
  love.graphics.clear(0, 0, 0, 0)
  draw_card_face(def, CARD_W, CARD_H, def.cost, def.desc, desc_color or Theme.muted, highlight or false)
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(card_flight_canvas, x, y)
  love.graphics.setColor(1, 1, 1, 1)
end

--- Dos de carte représentant TOUTES les cartes Avancées d'une classe d'un
-- coup (2026-08-30, écran de choix d'équipe, demande explicite -- "à la
-- place de montrer les cartes avancées, on montre 1 seule carte de dos avec
-- le nombre de cartes avancées actuellement débloquées pour ce personnage") :
-- même identité de classe (couleur) que les vraies cartes, mais face cachée
-- (motif croisé, pas de nom/texte/coût) -- seul le NOMBRE change d'une
-- classe à l'autre (dérivé de Cards.list, jamais codé en dur -- voir
-- Controller:team_select_spawn_cards).
local function draw_card_back_face(w, h, class_id, count)
  local palette = Theme.card_class[class_id] or Theme.card_class.generic
  panel(0, 0, w, h, palette.bg)
  set(Theme.black); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
  set(palette.border); love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 3, 3, w - 6, h - 6, 8, 8)
  set(palette.border, 0.4)
  love.graphics.setLineWidth(1)
  for i = -3, 3 do
    love.graphics.line(w / 2 + i * 12, 8, w / 2 + i * 12 + 26, h - 8)
    love.graphics.line(w / 2 + i * 12 + 26, 8, w / 2 + i * 12, h - 8)
  end
  love.graphics.setLineWidth(1)
  set(Theme.text)
  love.graphics.setFont(Fonts.get(30))
  love.graphics.printf(tostring(count), 0, h / 2 - 34, w, "center")
  text("cartes avancées\ndébloquées", 3, h / 2 + 2, w - 6, 9, Theme.muted, "center")
end

--- Même détour par canvas que draw_faded_card ci-dessus (fondu uniforme +
-- push/origin()/pop, même correctif).
local function draw_faded_card_back(class_id, count, x, y, alpha)
  card_flight_canvas = card_flight_canvas or love.graphics.newCanvas(CARD_W, CARD_H)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(card_flight_canvas)
  love.graphics.clear(0, 0, 0, 0)
  draw_card_back_face(CARD_W, CARD_H, class_id, count)
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
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

--- Transition d'entrée commune aux 4 écrans "camp" (2026-08-30, demande
-- explicite -- "une transition douce entre le draft et l'évènement... le
-- titre qui descend doucement depuis le haut de l'écran jusqu'à sa place...
-- puis les différents éléments apparaissent en fade in") : le TITRE descend
-- (position seule, pas de fondu -- toujours pleinement visible, juste pas
-- encore arrivé) pendant que TOUT LE RESTE (`draw_content`, une closure)
-- reste invisible, puis apparaît en fondu une fois le titre bien entamé.
-- `draw_content` est rendue dans un canvas plein écran réutilisé (même
-- technique que draw_faded_card, à l'échelle de l'écran entier) pour
-- pouvoir lui appliquer un SEUL fondu uniforme, plutôt que de faire porter
-- un paramètre alpha à chaque fonction de dessin individuelle -- voir aussi
-- le correctif "restaure le canvas précédent" appliqué à draw_faded_card/
-- draw_card_flights/capture_enemy_shatter, indispensable puisque
-- draw_content (l'écran Forge notamment) peut lui-même ouvrir un canvas
-- imbriqué. `controller.camp_entrance` (voir Controller:
-- enter_post_combat_sequence, seul écrivain) : nil seulement si cet écran a
-- été atteint par un chemin qui l'aurait sauté (ne devrait pas arriver) --
-- se comporte alors comme un fondu déjà terminé, jamais une erreur.
local camp_entrance_canvas
local function draw_camp_entrance(controller, title, title_y, draw_content)
  local entrance = controller.camp_entrance
  local title_duration = controller.camp_entrance_title_duration or 0.55
  local title_t = entrance and entrance.t or title_duration
  local ease = ease_out_back(title_t, title_duration)
  local from_y = -40
  text(title, 0, from_y + (title_y - from_y) * ease, W, 24, Theme.text)

  local content_alpha = 1
  if entrance then
    local delay = controller.camp_entrance_fade_delay or 0
    local duration = controller.camp_entrance_fade_duration or 0.4
    content_alpha = math.max(0, math.min(1, (entrance.t - delay) / duration))
  end

  camp_entrance_canvas = camp_entrance_canvas or love.graphics.newCanvas(W, H)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(camp_entrance_canvas)
  love.graphics.clear(0, 0, 0, 0)
  draw_content()
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, content_alpha)
  love.graphics.draw(camp_entrance_canvas)
  love.graphics.setColor(1, 1, 1, 1)
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
--- Flèche simple pointant vers le bas (2026-08-30, Forge -- "chacune des 4
-- cartes au choix doit présenter sa version améliorée, reliée par une
-- flèche") : relie la carte de base à sa version améliorée juste en dessous,
-- silhouette neutre (ni bonus ni malus, contrairement à Icons.draw_status_
-- bonus/malus) -- une amélioration n'est ni "positive" ni "négative" en soi
-- ici, juste "ce que cette carte va devenir".
local function draw_forge_arrow(cx, cy, alpha)
  set(Theme.accent, alpha)
  love.graphics.setLineWidth(3)
  love.graphics.line(cx, cy - 12, cx, cy + 6)
  love.graphics.polygon("fill", cx - 8, cy, cx + 8, cy, cx, cy + 14)
  love.graphics.setLineWidth(1)
end

local function draw_forge(controller)
  local f = controller.forge
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  draw_camp_entrance(controller, "La Forge", 60, function()
  if #f.choices == 0 then
    text("Toutes vos cartes sont déjà améliorées.", 0, 92, W, 12, Theme.muted)
    local b = View.forge_skip_button
    set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    set(Theme.bg); text(b.label, b.x, b.y + 14, b.w, 14, Theme.bg)
    return
  end

  text("Choisis une carte à améliorer.", 0, 92, W, 12, Theme.muted)
  local base_rects = View.forge_card_rects(controller)
  local up_rects = View.forge_upgraded_card_rects(controller)
  local anim = controller.forge_upgrade_anim
  for i, instance in ipairs(f.choices) do
    local br, ur = base_rects[i], up_rects[i]
    local preview_def = forge_preview_def(instance.def)
    if anim and anim.chosen_index ~= i then
      -- Choix déjà fait, mais PAS celui-ci (2026-08-30, étendu aux 2 cartes
      -- de la colonne -- avant, seule la version améliorée existait ici) :
      -- base ET améliorée s'effacent ENSEMBLE, même fondu.
      local p = math.min(1, anim.t / (controller.forge_upgrade_anim_duration or 1))
      local alpha = 1 - p
      if alpha > 0 then
        draw_faded_card(instance.def, br.x, br.y, alpha, Theme.muted, false)
        draw_forge_arrow(br.x + CARD_W / 2, br.y + CARD_H + FORGE_ARROW_H / 2, alpha)
        draw_faded_card(preview_def, ur.x, ur.y, alpha, Theme.text, true)
      end
    elseif anim then
      -- La colonne CHOISIE (2026-08-30, demande explicite -- "la version non
      -- améliorée de la carte choisie descend et vient fade sur
      -- l'amélioration, comme une sorte de fusion, plus la carte améliorée
      -- réagit avec un VFX") : l'améliorée reste affichée EN CONTINU à SA
      -- position (`ur`, déjà celle de l'aperçu avant le choix -- aucun saut),
      -- la base descend depuis SA position (`br`) en s'estompant, comme si
      -- elle "tombait dedans" -- p=1 (fin d'anim) = totalement fondue, jamais
      -- une disparition instantanée comme avant ce correctif.
      local p = math.min(1, anim.t / (controller.forge_upgrade_anim_duration or 1))
      local ease = 1 - (1 - p) ^ 2 -- easeOutQuad : la base ralentit en approchant, ne tombe pas d'un bloc
      local base_y = br.y + (ur.y - br.y) * ease
      local base_alpha = 1 - p

      -- Pulsation + flash au moment de l'"impact" (2026-08-30) : réagit à
      -- l'arrivée de la base plutôt qu'un simple fondu passif -- fenêtre sur
      -- les 40% finaux de l'anim seulement, pour laisser l'oeil suivre la
      -- descente d'abord.
      local impact_p = math.max(0, (p - 0.6) / 0.4)
      local impact_wave = math.sin(impact_p * math.pi) -- monte puis retombe, 0 aux 2 bouts
      local card_scale = 1 + 0.12 * impact_wave

      if impact_wave > 0 then
        set(Theme.accent, impact_wave * 0.5)
        love.graphics.rectangle("fill", ur.x - 6, ur.y - 6, CARD_W + 12, CARD_H + 12, 14, 14)
      end

      love.graphics.push()
      love.graphics.translate(ur.x + CARD_W / 2, ur.y + CARD_H / 2)
      love.graphics.scale(card_scale, card_scale)
      love.graphics.translate(-CARD_W / 2, -CARD_H / 2)
      draw_card_face(preview_def, CARD_W, CARD_H, preview_def.cost, preview_def.desc, Theme.text, true)
      love.graphics.pop()

      if base_alpha > 0 then
        draw_faded_card(instance.def, br.x, base_y, base_alpha, Theme.muted, false)
      end
    else
      love.graphics.push()
      love.graphics.translate(br.x, br.y)
      draw_card_face(instance.def, CARD_W, CARD_H, instance.def.cost, instance.def.desc, Theme.muted, false)
      love.graphics.pop()
      draw_forge_arrow(br.x + CARD_W / 2, br.y + CARD_H + FORGE_ARROW_H / 2, 1)
      love.graphics.push()
      love.graphics.translate(ur.x, ur.y)
      draw_card_face(preview_def, CARD_W, CARD_H, preview_def.cost, preview_def.desc, Theme.text, true)
      love.graphics.pop()
    end
  end
  end)
end

--- Écran "Feu de camp" (2026-08-30, remis en place, refonte -- demande
-- explicite : "pas d'options autre que le soin, le joueur choisit parmi ses
-- 4 aventuriers lequel va se faire soigner de 30% de ses PV max") : une
-- rangée de 4 cadres cliquables, chacun affiche le montant EXACT qu'il
-- recevrait (déjà plafonné à max_hp, même calcul que Controller:
-- choose_campfire_hero -- ne peuvent jamais diverger) -- cliquer résout
-- directement, pas de bouton "Confirmer" séparé.
local function draw_campfire(controller)
  local cf = controller.campfire
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  draw_camp_entrance(controller, "Feu de camp", 60, function()
  text("Choisis l'aventurier à soigner (30% de ses PV max).", 0, 92, W, 12, Theme.muted)

  local rects = View.campfire_hero_rects(controller)
  for _, h in ipairs(controller.state.heroes) do
    local r = rects[h.id]
    local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
    panel(r.x, r.y, r.w, r.h, Theme.panel_light)
    -- Couleur personnelle de l'aventurier (2026-08-30, bug signalé -- "les
    -- contours des aventuriers sont tous de la même couleur avant sélection,
    -- il faut qu'ils gardent leur couleur personnelle") : avant, Theme.heal
    -- fixe pour les 4 -- remplacé par palette.border (même couleur que sur sa
    -- carte/son nom, voir Theme.card_class), qui les distingue à nouveau.
    set(palette.border); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    local portrait_size = 70
    draw_class_icon(h.class_id, h.icon, h.label, r.x + (r.w - portrait_size) / 2, r.y + 14, portrait_size, portrait_size, Theme.text)
    name_badge(h.name, r.x + 8, r.y + 90, r.w - 16, 12, palette.border, Theme.bg, 2, 3)
    -- Barre de PV normale, comme en combat (2026-08-30, bug signalé --
    -- "il faut ajouter les barres de vie normale") : remplace le simple
    -- texte "X/Y PV" -- même hp_bar/traînée qu'en combat (voir
    -- Controller:advance_trail), donc le soin (Combat.grant_heal, appelé au
    -- clic -- voir Controller:choose_campfire_hero) se voit désormais monter
    -- doucement ici aussi, gratuitement (même mécanisme partagé).
    hp_bar(r.x + 8, r.y + 106, r.w - 16, 16, h.hp / h.max_hp, (controller.hp_trail[h.id] or h.hp) / h.max_hp, Theme.hp)
    text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", r.x, r.y + 106, r.w, 16, 10, Theme.text)
    local healed = math.min(h.max_hp, h.hp + Combat.round(h.max_hp * 0.30)) - h.hp
    text("+" .. healed .. " PV", r.x, r.y + 128, r.w, 13, Theme.heal, "center")
  end
  end)
end

--- Écran "Le Refuge" (2026-08-30, nouvel évènement -- demande explicite :
-- "pas de choix, tous les persos vont regagner 30% de leurs PV") : le soin
-- n'a PLUS lieu à l'entrée sur l'écran (2026-08-30, bug signalé -- "il faut
-- quand même une action joueur, au moins 1 clic" -- voir Controller:
-- choose_refuge_rest) -- avant le clic sur "Se reposer", affiche donc une
-- PRÉVISION (même formule que draw_campfire ci-dessus, PV réels pas encore
-- modifiés) ; une fois `rf.resolved` vrai, affiche le montant RÉELLEMENT
-- reçu (self.refuge.healed, posé par choose_refuge_rest). Aucun aventurier
-- cliquable individuellement -- "pas de choix", toute l'équipe à la fois.
local function draw_refuge(controller)
  local rf = controller.refuge
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  draw_camp_entrance(controller, "Le Refuge", 60, function()
  text("Toute l'équipe va se reposer (30% des PV max).", 0, 92, W, 12, Theme.muted)

  local rects = View.refuge_hero_rects(controller)
  for _, h in ipairs(controller.state.heroes) do
    local r = rects[h.id]
    local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
    panel(r.x, r.y, r.w, r.h, Theme.panel_light)
    -- Couleur personnelle (2026-08-30, même correctif que draw_campfire ci-dessus) --
    -- voir son commentaire.
    set(palette.border); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    local portrait_size = 70
    draw_class_icon(h.class_id, h.icon, h.label, r.x + (r.w - portrait_size) / 2, r.y + 14, portrait_size, portrait_size, Theme.text)
    name_badge(h.name, r.x + 8, r.y + 90, r.w - 16, 12, palette.border, Theme.bg, 2, 3)
    -- Barre de PV normale, comme en combat (2026-08-30, même correctif que
    -- draw_campfire ci-dessus) : voir son commentaire.
    hp_bar(r.x + 8, r.y + 106, r.w - 16, 16, h.hp / h.max_hp, (controller.hp_trail[h.id] or h.hp) / h.max_hp, Theme.hp)
    text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", r.x, r.y + 106, r.w, 16, 10, Theme.text)
    local healed
    if rf.resolved then
      healed = rf.healed[h.id] or 0
    else
      healed = math.min(h.max_hp, h.hp + Combat.round(h.max_hp * 0.30)) - h.hp
    end
    text("+" .. healed .. " PV", r.x, r.y + 128, r.w, 13, Theme.heal, "center")
  end

  local b = View.refuge_rest_button
  set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
  set(Theme.bg); text(b.label, b.x, b.y + 14, b.w, 14, Theme.bg, "center")
  end)
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
  draw_camp_entrance(controller, "Le Temple", 26, function()

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
    -- Aventuriers NON choisis s'effacent aussi (2026-08-30, demande explicite
    -- -- avant, seules les statues non choisies s'effaçaient) : même fondu
    -- que les statues, sur la même durée -- l'aventurier choisi, lui, reste
    -- pleinement visible (c'est lui qui reçoit l'effet).
    local hero_alpha = 1
    if anim and t.chosen_hero_id ~= h.id then
      hero_alpha = 1 - math.min(1, anim.t / (controller.temple_choice_anim_duration or 1))
    end
    if hero_alpha > 0 then
      local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
      panel(r.x, r.y, r.w, r.h, eligible and Theme.panel_light or Theme.panel, hero_alpha)
      -- Couleur personnelle avant sélection (2026-08-30, bug signalé -- même
      -- correctif que draw_campfire/draw_refuge) : un aventurier ÉLIGIBLE
      -- mais pas encore choisi gardait quand même le contour or de
      -- Theme.accent (identique pour les 4), au lieu de sa propre couleur de
      -- classe -- l'or reste réservé à celui réellement sélectionné, pour que
      -- "or" continue de signifier "choisi", sans plus rien retirer aux
      -- autres.
      set(selected and Theme.accent or (eligible and palette.border or Theme.muted), hero_alpha)
      love.graphics.setLineWidth(selected and 4 or 2)
      love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
      love.graphics.setLineWidth(1)
      local portrait_size = 70
      draw_class_icon(h.class_id, h.icon, h.label,
        r.x + (r.w - portrait_size) / 2, r.y + 14, portrait_size, portrait_size,
        eligible and Theme.text or Theme.muted, hero_alpha)
      name_badge(h.name, r.x + 8, r.y + 90, r.w - 16, 12, palette.border, Theme.bg, 2, 3)
      if h.hp <= 0 then
        text("Mort", r.x, r.y + 112, r.w, 11, Theme.muted)
      elseif not eligible then
        text(t.type == "blessing" and "Déjà béni" or "Déjà maudit", r.x, r.y + 112, r.w, 11, Theme.muted)
      end
      -- "?" manquant (2026-08-30, bug signalé -- "pour les aventuriers, il
      -- n'y a pas le '?' ni les info bulles") : la rangée de statues juste
      -- au-dessus en a un (voir plus haut, draw_tooltip_hint), jamais posé
      -- ici -- Input.mousemoved fait pourtant déjà de chaque portrait une
      -- vraie cible de survol (kind "hero", voir son commentaire), seul le
      -- rendu du hint manquait. Même garde `not anim` que les statues :
      -- plus de survol/tooltip une fois la fusion lancée.
      if not anim then
        love.graphics.push()
        love.graphics.translate(r.x, r.y)
        draw_tooltip_hint(r.w, r.h, Theme.text)
        love.graphics.pop()
      end
    end
  end

  -- Fusion (2026-08-30, demande explicite -- "les 2 choix s'alignent puis
  -- fusionnent, pour montrer que l'aventurier a reçu la bénédiction/
  -- malédiction") : une COPIE de l'icône de l'effet choisi voyage de sa
  -- statue jusqu'au portrait de l'aventurier choisi, en rétrécissant, PUIS
  -- une brève lueur de la couleur de l'effet marque l'"impact" une fois
  -- arrivée -- la statue/le panneau d'origine restent statiques et lisibles
  -- (on garde "quel effet a été choisi" affiché), seule cette copie bouge.
  if anim then
    local chosen_effect = t.choices[anim.chosen_index]
    local statue_r = effect_rects[anim.chosen_index]
    local hero_r = hero_rects[t.chosen_hero_id]
    if chosen_effect and statue_r and hero_r then
      local duration = controller.temple_choice_anim_duration or 1
      local p = math.min(1, anim.t / duration)
      local color = TEMPLE_STATUE_COLORS[chosen_effect.color] or Theme.accent
      if p < 1 then
        local ease = p * p -- accélère vers la fusion (easeInQuad -- "aspiré" par l'aventurier)
        local from_cx, from_cy = statue_r.x + statue_r.w / 2, statue_r.y + 55
        local to_cx, to_cy = hero_r.x + hero_r.w / 2, hero_r.y + hero_r.h / 2
        local cx = from_cx + (to_cx - from_cx) * ease
        local cy = from_cy + (to_cy - from_cy) * ease
        local scale = 1 - 0.7 * ease
        -- Ne commence à s'estomper que sur le dernier tiers du trajet
        -- (absorption progressive à l'arrivée, pas un simple fondu linéaire
        -- sur tout le vol).
        local travel_alpha = p < 0.7 and 1 or (1 - (p - 0.7) / 0.3)
        Icons.draw_status(icon_key, cx, cy, 38 * math.max(0.1, scale), color, travel_alpha)
      else
        -- Lueur d'impact (2026-08-30) : brève, indépendante de la durée
        -- totale de la pause -- juste de quoi marquer "c'est arrivé", pas
        -- besoin qu'elle dure tout le temps où "Bonne chance" reste affiché.
        local GLOW_DURATION = 0.4
        local glow_t = anim.t - duration
        if glow_t < GLOW_DURATION then
          local glow_alpha = 1 - glow_t / GLOW_DURATION
          local to_cx, to_cy = hero_r.x + hero_r.w / 2, hero_r.y + hero_r.h / 2
          set(color, glow_alpha * 0.6)
          love.graphics.circle("fill", to_cx, to_cy, hero_r.w * 0.6 * (1 + 0.3 * (1 - glow_alpha)))
        end
      end
    end
  end

  if not anim then
    local b = View.temple_confirm_button
    local can_confirm = t.chosen_effect_index and t.chosen_hero_id
    set(can_confirm and Theme.accent or Theme.panel_light)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    text(b.label, b.x, b.y + 14, b.w, 14, can_confirm and Theme.bg or Theme.muted)
  end
  end)
end

-- Durée du rebond d'agrandissement au survol (2026-08-30, demande explicite
-- -- "tout le cadre doit réagir et grandir avec un effet de rebond") :
-- pilotée par controller.hover.t (déjà le temps depuis que CE survol précis
-- a commencé, remis à 0 par Controller:set_hover dès que la cible change --
-- voir son commentaire dans controller.lua) -- aucun état d'animation à part
-- à tenir ici, juste relire ce compteur déjà tenu à jour.
local TEAM_HOVER_BOUNCE_DURATION = 0.28
local TEAM_HOVER_BOUNCE_SCALE = 0.16

--- Un cadre d'aventurier de l'écran de choix d'équipe (2026-08-29) --
-- portrait + nom, contour or si mis en avant, pastille verte si déjà dans
-- l'équipe confirmée. `hover_t` (2026-08-30, nil ou 0 si pas survolé) :
-- TOUT le cadre grandit avec un effet de rebond au survol (ease_out_back,
-- même courbe que le titre "Victoire !"), plus seulement le portrait qui
-- montait de quelques pixels avant.
local function draw_team_hero_slot(r, def, hover_t, focused, in_party)
  local scale = 1
  if hover_t and hover_t > 0 then
    scale = 1 + TEAM_HOVER_BOUNCE_SCALE * ease_out_back(hover_t, TEAM_HOVER_BOUNCE_DURATION)
  end
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)

  local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
  panel(r.x, r.y, r.w, r.h, Theme.panel_light)
  -- Couleur personnelle systématique (2026-08-30, bug signalé -- "tous les
  -- aventuriers doivent avoir leur contour de la bonne couleur") : avant,
  -- Theme.accent (or, "mis en avant")/Theme.muted (gris, au repos) --
  -- jamais la couleur de classe, contrairement aux autres écrans déjà
  -- corrigés ce jour-là (campfire/refuge/temple). L'emphase "mis en avant"/
  -- survolé reste marquée par l'ÉPAISSEUR du contour, pas sa couleur.
  set(hover_t and hover_t > 0 and Theme.text or palette.border)
  love.graphics.setLineWidth(focused and 4 or 2)
  love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
  love.graphics.setLineWidth(1)
  -- Portrait bien plus grand dans le projecteur (2026-08-30, demande
  -- explicite) : la case elle-même y est déjà nettement plus grande
  -- (TEAM_SPOTLIGHT_W/H, 170x190) que les cases des 2 rangées (TEAM_HERO_W/H,
  -- 108x120) -- `focused` distingue déjà les deux cas, pas besoin d'un
  -- paramètre supplémentaire.
  local portrait_size = focused and 130 or 58
  draw_class_icon(def.class_id, def.icon, def.label,
    r.x + (r.w - portrait_size) / 2, r.y + 10, portrait_size, portrait_size, Theme.text)
  name_badge(def.name, r.x + 6, r.y + r.h - 26, r.w - 12, 12, palette.border, Theme.bg, 2, 2)
  if in_party then
    set(Theme.heal); love.graphics.circle("fill", r.x + r.w - 12, r.y + 12, 7)
  end
  love.graphics.push()
  love.graphics.translate(r.x, r.y)
  draw_tooltip_hint(r.w, r.h)
  love.graphics.pop()

  love.graphics.pop()
end

--- Écran "Choisis ton équipe" (2026-08-29, demande explicite -- avant chaque
-- run, choisir 4 des 6 aventuriers débloqués) : cliquer un aventurier
-- disponible (rangée du haut) le met en avant et fait voler SES cartes
-- (Départ + Avancé) depuis un bord aléatoire jusqu'au centre -- voir
-- Controller:team_select_focus/team_select_spawn_cards, `controller.
-- team_select.card_anims` porte à la fois le vol entrant du héros mis en
-- avant ET le vol sortant de l'ancien (les deux coexistent le temps du
-- croisement, voir Controller:update pour leur avancement). "Annuler" les
-- renvoie sans rien changer ; "Valider" bascule l'aventurier vers la rangée
-- du bas (équipe confirmée) -- ou l'en RETIRE s'il y était déjà ("resélectionné
-- normalement pour être sorti du groupe", le bouton se relabellise "Retirer"
-- dans ce cas). Le gros bouton "Partir à l'aventure" ne s'active (et ne
-- clignote) qu'à 4 aventuriers confirmés.
--- Anim de déplacement d'UN portrait de héros (2026-08-30, voir
-- Controller:team_select_move_hero/ts.hero_anims) : `ease_out_back`, même
-- courbe que le vol des cartes -- le héros "atterrit" avec un léger rebond
-- plutôt que de simplement s'arrêter.
local function team_select_hero_anim_rect(a)
  local ease = ease_out_back(a.elapsed, a.duration)
  return {
    x = a.from.x + (a.to.x - a.from.x) * ease,
    y = a.from.y + (a.to.y - a.from.y) * ease,
    w = a.to.w, h = a.to.h,
  }
end

local function team_select_find_hero_anim(ts, id)
  for _, a in ipairs(ts.hero_anims) do if a.id == id then return a end end
  return nil
end

--- "Deck" de mise en scène de l'écran de choix d'équipe (2026-08-30) : pile
-- à étages (même esprit que draw_pile en combat, voir plus haut dans ce
-- fichier) dont le RECTANGLE lui-même grossit avec le nombre d'aventuriers
-- confirmés (voir View.team_select_deck_rect), pas seulement l'effet
-- d'épaisseur -- "ce deck grossit à chaque nouvel aventurier", demande
-- explicite.
local function draw_team_deck(rect, card_count)
  -- /3 pas /6 (2026-08-30, même correction que son appelant -- card_count
  -- vaut désormais 3 par aventurier, pas 6) : garde la même progression
  -- d'épaisseur (0/1/2/2 étages pour 1/2/3/4 aventuriers) qu'avant le fix.
  local layers = math.min(2, math.max(0, math.floor(card_count / 3) - 1))
  for i = layers, 1, -1 do
    panel(rect.x + i * 3, rect.y - i * 3, rect.w, rect.h, Theme.panel)
  end
  panel(rect.x, rect.y, rect.w, rect.h, Theme.panel_light)
  set(Theme.accent); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
  text("DECK", rect.x, rect.y + 8, rect.w, 9, Theme.muted, "center")
  text(tostring(card_count), rect.x, rect.y + rect.h / 2 - 4, rect.w, 16, Theme.text, "center")
end

local function draw_team_select(controller)
  local ts = controller.team_select
  Background.draw(nil, W, H)
  text("Choisis ton équipe", 0, 18, W, 22, Theme.text)
  text(#ts.selected_ids .. " / 4 aventuriers", 0, 44, W, 12, Theme.muted)

  -- Héros "en transit" entre 2 emplacements (2026-08-30, voir
  -- Controller:team_select_move_hero) : masqués de leur rangée d'origine ET
  -- de destination tant que l'anim n'est pas finie, dessinés uniquement via
  -- team_select_hero_anim_rect plus bas -- jamais les deux à la fois.
  local moving_ids = {}
  for _, a in ipairs(ts.hero_anims) do moving_ids[a.id] = true end

  local function hover_t_for(id)
    if controller.hover.kind == "team_hero" and controller.hover.target == id then
      return controller.hover.t
    end
    return nil
  end

  local available_rects = View.team_select_available_rects(controller)
  for _, id in ipairs(ts.available_ids) do
    if id ~= ts.focused_id and not moving_ids[id] then
      draw_team_hero_slot(available_rects[id], Heroes.by_id(id), hover_t_for(id), false, false)
    end
  end

  -- Cartes en vol (voir le commentaire de fonction) : "in" se fige à sa
  -- position cible une fois l'animation finie (elapsed clampé à duration =>
  -- p=1, plus aucun mouvement) -- pas besoin d'un 2ᵉ système pour "les cartes
  -- au repos", cette même liste EST l'état affiché tant qu'un focus est actif.
  -- `a.delay` (2026-08-30, rassemblement vers le deck décalé carte par
  -- carte -- voir Controller:team_select_fly_out_current) : reste VISIBLE,
  -- immobile à son point de départ, tant que son tour n'est pas venu (bug
  -- signalé, 2026-08-30 -- "les cartes disparaissent avant de faire le
  -- mouvement" : avant ce correctif, une carte dont `elapsed < delay`
  -- n'était pas dessinée DU TOUT, jamais juste figée -- même principe que
  -- draw_card_flights (combat) pour la pioche en rafale, qui ne fait
  -- disparaître aucune carte en attente non plus).
  for _, a in ipairs(ts.card_anims) do
    local delay = a.delay or 0
    -- Carte de dos "cartes Avancées" (2026-08-30, voir
    -- Controller:team_select_spawn_cards -- `a.is_back`, pas de `a.def`) :
    -- même vol/fondu que n'importe quelle autre carte de cette liste, juste
    -- un rendu différent.
    if a.elapsed < delay then
      if a.is_back then draw_faded_card_back(a.class_id, a.count, a.from.x, a.from.y, 1)
      else draw_faded_card(a.def, a.from.x, a.from.y, 1) end
    else
      local elapsed_since_start = a.elapsed - delay
      local p = math.min(1, elapsed_since_start / a.duration)
      local ease = a.mode == "in" and ease_out_back(elapsed_since_start, a.duration) or (1 - (1 - p) ^ 2)
      local x = a.from.x + (a.to.x - a.from.x) * ease
      local y = a.from.y + (a.to.y - a.from.y) * ease
      local alpha = a.mode == "in" and math.min(1, p * 1.6) or (1 - p)
      if alpha > 0 then
        if a.is_back then draw_faded_card_back(a.class_id, a.count, x, y, alpha)
        else draw_faded_card(a.def, x, y, alpha) end
      end
    end
  end

  if ts.focused_id then
    local cb = View.team_select_cancel_button
    set(Theme.panel_light); love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
    set(Theme.accent); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
    love.graphics.setLineWidth(1)
    text(cb.label, cb.x, cb.y + 14, cb.w, 14, Theme.text, "center")

    local already_in = false
    for _, sid in ipairs(ts.selected_ids) do if sid == ts.focused_id then already_in = true end end
    local vb = View.team_select_confirm_button
    local blocked = (not already_in) and #ts.selected_ids >= 4
    set(blocked and Theme.panel or Theme.accent)
    love.graphics.rectangle("fill", vb.x, vb.y, vb.w, vb.h, 8, 8)
    text(already_in and "Retirer" or "Valider", vb.x, vb.y + 14, vb.w, 14, blocked and Theme.muted or Theme.bg, "center")

    -- Projecteur (2026-08-30) : le héros mis en avant SE DÉPLACE réellement
    -- ici (interpolé tant que l'anim d'arrivée n'est pas finie, sinon posé
    -- pile sur View.team_select_spotlight_rect -- même valeur au repos).
    local anim = team_select_find_hero_anim(ts, ts.focused_id)
    local r = anim and team_select_hero_anim_rect(anim) or View.team_select_spotlight_rect
    draw_team_hero_slot(r, Heroes.by_id(ts.focused_id), hover_t_for(ts.focused_id), true, false)
  end

  local party_rects = View.team_select_party_rects(controller)
  text("Ton équipe", TEAM_PARTY_LEFT, TEAM_BOTTOM_Y - 16, 200, 10, Theme.muted, "left")
  for _, id in ipairs(ts.selected_ids) do
    if id ~= ts.focused_id and not moving_ids[id] then
      draw_team_hero_slot(party_rects[id], Heroes.by_id(id), hover_t_for(id), false, true)
    end
  end

  -- Héros en transit (2026-08-30) : ni dans une rangée, ni dans le
  -- projecteur (il vient de le quitter) -- dessiné à sa position interpolée.
  for _, a in ipairs(ts.hero_anims) do
    if a.id ~= ts.focused_id then
      local in_party = false
      for _, sid in ipairs(ts.selected_ids) do if sid == a.id then in_party = true end end
      draw_team_hero_slot(team_select_hero_anim_rect(a), Heroes.by_id(a.id), hover_t_for(a.id), false, in_party)
    end
  end

  -- 3 cartes "depart" par aventurier confirmé, pas 6 (2026-08-30, bug
  -- signalé -- "le deck indique 24 cartes... or il n'y a en fait que les
  -- cartes de départ, donc 12 cartes") : ce chiffre doit rester cohérent
  -- avec Controller:team_select_spawn_cards, qui n'affiche/n'anime QUE les
  -- cartes de tier "depart" (jamais les avancées, résumées par la carte de
  -- dos) -- voir aussi depart_cards_and_advance_count, controller.lua.
  draw_team_deck(View.team_select_deck_rect(#ts.selected_ids), #ts.selected_ids * 3)

  local lb = View.team_select_launch_button
  local ready = #ts.selected_ids == 4
  if ready then
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
    set(Theme.accent, 0.35 + 0.35 * pulse)
    love.graphics.rectangle("fill", lb.x - 5, lb.y - 5, lb.w + 10, lb.h + 10, 12, 12)
  end
  set(ready and Theme.heal or Theme.panel_light)
  love.graphics.rectangle("fill", lb.x, lb.y, lb.w, lb.h, 10, 10)
  set(ready and Theme.accent or Theme.muted); love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", lb.x, lb.y, lb.w, lb.h, 10, 10)
  love.graphics.setLineWidth(1)
  -- 2 lignes (2026-08-30, voir lb.label ci-dessus) : `text()` ne centre pas
  -- verticalement un bloc multi-lignes tout seul (LÖVE ne fait qu'empiler
  -- les lignes vers le bas depuis `y`) -- décalage de départ approximant le
  -- milieu du bloc de 2 lignes à cette taille de police, pas la taille de
  -- police elle-même (paramètre suivant -- confondre les 2 affichait une
  -- police énorme avant le tout premier correctif). Taille 16 -> 24
  -- (2026-08-30, demande explicite -- "doit être écrit beaucoup plus gros") :
  -- décalage remis à l'échelle dans la même proportion (16 -> 24).
  text(lb.label, lb.x, lb.y + lb.h / 2 - 24, lb.w, 24, ready and Theme.bg or Theme.muted, "center")

  -- "Auto-fill" (2026-09-02) : style plus discret que "Partir à l'aventure"
  -- (toujours actif, pas de pulse "prêt") -- juste au-dessus.
  local ab = View.team_select_autofill_button
  set(Theme.panel_light)
  love.graphics.rectangle("fill", ab.x, ab.y, ab.w, ab.h, 8, 8)
  set(Theme.muted); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", ab.x, ab.y, ab.w, ab.h, 8, 8)
  love.graphics.setLineWidth(1)
  text(ab.label, ab.x, ab.y + ab.h / 2 - 7, ab.w, 14, Theme.text, "center")

  -- Infobulles (2026-08-30, bug signalé -- "il faut que les info bulles
  -- marchent sur les aventuriers... pareil pour les cartes") : draw_tooltip
  -- lit déjà controller.hover (mis à jour par Input.mousemoved, voir ses
  -- branches "team_hero"/"card" pour cet écran) et tooltip_lines gère déjà
  -- les 2 cas -- il ne manquait QUE cet appel, "team_select" étant un
  -- retour anticipé de View.draw (voir son tout début), jamais atteint par
  -- l'appel générique en fin de fonction qui dessine l'infobulle pour
  -- "playing"/"forge"/"temple"/etc.
  draw_tooltip(controller)
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

-- Écran d'accueil stylé (2026-08-30, demande explicite -- "une image
-- d'accueil, avec le titre actuel du jeu et quelques éléments graphiques
-- stylés") : fond PROCÉDURAL (gratuit, cohérent avec Background.draw/le son
-- chiptune du projet -- voir game/README.md) plutôt qu'une illustration
-- générée par IA -- choix explicite fait face au coût réel d'une génération
-- (même pipeline que les portraits de héros). Halo doré + diamants +
-- bannière des 6 aventuriers, purement décoratifs (aucun n'est cliquable).
local MENU_HERO_ROW_Y = 188
local MENU_HERO_R = 22

local function draw_menu_diamond(x, y, size, alpha)
  set(Theme.accent, alpha)
  love.graphics.polygon("fill", x, y - size, x + size, y, x, y + size, x - size, y)
end

local function draw_menu_flourish()
  -- Halo doré derrière le titre : cercles concentriques à alpha décroissante --
  -- LÖVE n'offre pas de flou/shader ici, cette accumulation de formes
  -- semi-transparentes en simule un à moindre coût (même idée que les glows
  -- déjà utilisés ailleurs, ex. la fusion du Temple).
  local cx, cy = W / 2, 100
  for i = 4, 1, -1 do
    set(Theme.accent, 0.05 * i)
    love.graphics.ellipse("fill", cx, cy, 60 + i * 40, 30 + i * 14)
  end

  -- Diamants encadrant "Rogue Adventure" + ligne de séparation, diamant central --
  -- vocabulaire visuel déjà utilisé par le cadre doré des boutons/cartes
  -- sélectionnées (Theme.accent), jamais une nouvelle teinte.
  draw_menu_diamond(W / 2 - 100, 137, 5, 0.8)
  draw_menu_diamond(W / 2 + 100, 137, 5, 0.8)
  set(Theme.accent, 0.5); love.graphics.setLineWidth(1)
  love.graphics.line(W / 2 - 170, 155, W / 2 - 14, 155)
  love.graphics.line(W / 2 + 14, 155, W / 2 + 170, 155)
  draw_menu_diamond(W / 2, 155, 6, 0.8)

  -- Bannière des 6 aventuriers (2026-08-30) : silhouettes semi-transparentes,
  -- teintées de leur couleur de classe -- pure ambiance "constitue ton
  -- équipe", jamais interactif (contrairement à l'écran de choix d'équipe,
  -- dont le layout n'est pas dupliqué ici).
  local n = #Heroes.defs
  local spacing = 70
  local x0 = W / 2 - (n - 1) * spacing / 2
  for i, def in ipairs(Heroes.defs) do
    local x = x0 + (i - 1) * spacing
    local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
    set(palette.border, 0.25)
    love.graphics.circle("fill", x, MENU_HERO_ROW_Y, MENU_HERO_R + 4)
    local sprite = Sprites.hero(def.class_id)
    if sprite then
      love.graphics.setColor(1, 1, 1, 0.55)
      Sprites.draw_centered(sprite, x, MENU_HERO_ROW_Y, MENU_HERO_R)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- Menu principal (2026-08-21, demande explicite) : pas de fond dédié pour
-- l'instant ("il y aura un background mais pas pour l'instant") -- même
-- dégradé procédural par défaut que le combat (voir Background.draw,
-- `enemies = nil` retombe sur BIOMES.defaut), pas un écran vide.
local function draw_menu(controller)
  Background.draw(nil, W, H)
  draw_menu_flourish()
  text("Hero Card Game", 0, 90, W, 30, Theme.text)
  -- "Run Infini" retiré (2026-08-30, demande explicite -- "n'a rien à faire
  -- ici", à ne pas confondre avec le vrai mode de jeu "Mode infini" du menu
  -- ci-dessous, sans rapport) : remplacé par "Rogue Adventure".
  text("Rogue Adventure", 0, 130, W, 14, Theme.muted)
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
-- Écran d'annonce de biome (2026-09-01, demande explicite) : "petite fenêtre
-- intermédiaire pour annoncer le lieu" avant le début/la reprise des combats
-- dans ce biome -- réutilise draw_camp_entrance (même animation de titre que
-- les 4 écrans "camp") et Background.draw avec un biome explicite (pas encore
-- de state.enemies à ce stade, voir son 4ᵉ paramètre dans background.lua).
local function draw_biome_intro(controller)
  local bi = controller.biome_intro
  if not bi then return end
  Background.draw(nil, W, H, bi.biome)
  local name = Enemies.BIOME_NAMES[bi.biome] or bi.biome
  draw_camp_entrance(controller, name, H / 2 - 20, function()
    text("Nouvelle zone…", 0, H / 2 + 14, W, 14, Theme.muted)
  end)
end

-- Menu pause (2026-09-02, demande explicite) : overlay par-dessus l'écran
-- courant (jamais dessiné en dessous n'est effacé) -- réutilise
-- draw_menu_style_button tel quel (même style que les boutons du menu
-- principal/"Retour" de l'écran Options), ne fait rien si l'overlay n'est
-- pas ouvert (voir Controller.pause_menu_open).
local function draw_pause_menu(controller)
  if not controller.pause_menu_open then return end
  set(Theme.black, 0.75)
  love.graphics.rectangle("fill", 0, 0, W, H)
  text("Pause", 0, H / 2 - 60, W, 24, Theme.text)
  draw_menu_style_button(View.pause_menu_continue_button)
  draw_menu_style_button(View.pause_menu_return_button)
end

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

--- Liste agrégée des cartes à afficher dans la fenêtre "voir le deck"
-- (2026-08-30, demande explicite) : `controller.deck_view_source` (voir
-- Controller:open_deck_view) distingue désormais 3 contenus -- "deck" (la
-- pioche SEULE, cliquer la pioche), "discard" (la défausse SEULE, cliquer la
-- défausse), ou "all"/nil (deck + main + défausse -- tout ce que le joueur
-- possède actuellement, bouton dédié) -- jamais le même contenu peu importe
-- l'entrée, contrairement à avant. SAUF sur l'écran de choix d'équipe, où
-- rien de tout cela n'existe encore : reconstitue alors la liste directement
-- depuis les héros déjà confirmés (ts.selected_ids), 3 cartes "départ" par
-- classe -- exactement ce que Deck.build_starting_deck posera au lancement
-- (voir Deck.starting_cards_for_class, même source) -- ignore `deck_view_source`
-- dans ce cas (aucune pioche/défausse réelle n'existe encore).
-- PAS de regroupement par doublon (2026-08-30, demande explicite -- "pour
-- l'instant, il n'y a pas beaucoup de cartes dans un deck, je préfère ne pas
-- regrouper et lister toutes les cartes même identiques") : une entrée par
-- exemplaire réellement possédé, jamais un badge "×N" -- triée par classe
-- puis nom pour un ordre stable d'un appel à l'autre (jamais l'ordre
-- d'arrivée dans le deck, qui changerait à chaque mélange) ; l'ordre entre 2
-- exemplaires IDENTIQUES n'a pas d'importance (ce sont la même carte).
function View.deck_view_cards(controller)
  local defs = {}
  if controller.screen == "team_select" then
    local ts = controller.team_select
    if ts then
      for _, class_id in ipairs(ts.selected_ids) do
        for _, def in ipairs(Deck.starting_cards_for_class(class_id)) do defs[#defs + 1] = def end
      end
    end
  else
    local state = controller.state
    local source = controller.deck_view_source or "all"
    if state then
      if source == "deck" then
        for _, c in ipairs(state.deck) do defs[#defs + 1] = c.def end
      elseif source == "discard" then
        for _, c in ipairs(state.discard) do defs[#defs + 1] = c.def end
      else
        for _, c in ipairs(state.deck) do defs[#defs + 1] = c.def end
        for _, c in ipairs(state.hand) do defs[#defs + 1] = c.def end
        for _, c in ipairs(state.discard) do defs[#defs + 1] = c.def end
      end
    end
  end
  table.sort(defs, function(a, b)
    if a.class_id ~= b.class_id then return a.class_id < b.class_id end
    if a.name ~= b.name then return a.name < b.name end
    return false
  end)
  local out = {}
  for _, def in ipairs(defs) do out[#out + 1] = { def = def } end
  return out
end

local function deck_view_title(controller)
  local cards = View.deck_view_cards(controller)
  local source = controller.deck_view_source or "all"
  local label
  if controller.screen ~= "team_select" and source == "deck" then label = "Pioche"
  elseif controller.screen ~= "team_select" and source == "discard" then label = "Défausse"
  else label = "Toutes les cartes" end
  return label .. " (" .. #cards .. ")"
end

-- Taille de carte FIXE, colonnes adaptées à la largeur, DÉFILEMENT vertical
-- si le contenu déborde en hauteur (2026-08-30, demande explicite -- "prévoir
-- un ascenseur s'il y a trop de cartes") : remplace le rapetissement sans fin
-- d'avant (les cartes restaient lisibles mais pouvaient devenir minuscules à
-- beaucoup de cartes) -- ici, la carte garde TOUJOURS sa taille de référence,
-- seul le nombre de lignes visibles change, le reste se découvre en
-- défilant (molette, voir Controller:scroll_deck_view/Input.wheelmoved).
-- Pure calcul, sans rien dessiner -- appelée à la fois par draw_deck_view
-- (rendu) et Controller:scroll_deck_view (bornes de défilement), pour ne
-- jamais avoir 2 formules de mise en page qui pourraient diverger.
local DECK_VIEW_GAP = 10
local DECK_VIEW_LABEL_H = 14
local DECK_VIEW_CARD_W = 78
local DECK_VIEW_SCROLLBAR_W = 10
function View.deck_view_layout(controller)
  local cards = View.deck_view_cards(controller)
  local p = View.deck_view_panel_rect
  local area_x, area_y = p.x + 20, p.y + 56
  local area_w, area_h = p.w - 40, p.h - 76

  local aspect = CARD_H / CARD_W
  local card_w = DECK_VIEW_CARD_W
  local card_h = card_w * aspect
  local cell_w, cell_h = card_w + DECK_VIEW_GAP, card_h + DECK_VIEW_LABEL_H + DECK_VIEW_GAP

  local function compute(usable_w)
    local cols = math.max(1, math.floor(usable_w / cell_w))
    local rows = #cards > 0 and math.ceil(#cards / cols) or 0
    return cols, rows, rows * cell_h
  end

  local cols, rows, content_h = compute(area_w)
  local max_scroll = math.max(0, content_h - area_h)
  -- Une fois qu'on sait qu'un ascenseur sera affiché, sa largeur est retirée
  -- de la zone utile aux cartes -- recalcule cols/rows avec cette largeur
  -- réduite (jamais de chevauchement carte/ascenseur).
  if max_scroll > 0 then
    cols, rows, content_h = compute(area_w - DECK_VIEW_SCROLLBAR_W - 6)
    max_scroll = math.max(0, content_h - area_h)
  end

  local grid_w = cols * cell_w
  local ox = area_x + (area_w - (max_scroll > 0 and DECK_VIEW_SCROLLBAR_W + 6 or 0) - grid_w) / 2

  return {
    cards = cards, cols = cols, rows = rows, card_w = card_w, card_h = card_h,
    cell_w = cell_w, cell_h = cell_h, area_x = area_x, area_y = area_y,
    area_w = area_w, area_h = area_h, ox = ox, content_h = content_h, max_scroll = max_scroll,
  }
end

--- Fenêtre "voir le deck" (2026-08-30, demande explicite -- accessible depuis
-- la pioche, la défausse, le deck de l'écran de choix d'équipe, et un bouton
-- dédié, voir Controller:open_deck_view/View.deck_view_button ci-dessus) :
-- panneau fixe (View.deck_view_panel_rect) par-dessus l'écran courant, grille
-- de cartes recalculée à chaque frame (View.deck_view_cards/deck_view_layout).
local function draw_deck_view(controller)
  if not controller.deck_view_open then return end
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)

  local p = View.deck_view_panel_rect
  panel(p.x, p.y, p.w, p.h, Theme.panel)
  set(Theme.accent); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10, 10)
  love.graphics.setLineWidth(1)

  text(deck_view_title(controller), p.x + 20, p.y + 16, p.w - 130, 18, Theme.text, "left")

  local cb = View.deck_view_close_button
  set(Theme.panel_light); love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
  set(Theme.muted); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
  love.graphics.setLineWidth(1)
  text(cb.label, cb.x, cb.y + 6, cb.w, 14, Theme.text, "center")

  local layout = View.deck_view_layout(controller)
  local cards = layout.cards
  if #cards == 0 then
    text("Aucune carte pour l'instant.", layout.area_x, layout.area_y + layout.area_h / 2 - 10, layout.area_w, 14, Theme.muted)
    return
  end

  local scroll = math.max(0, math.min(layout.max_scroll, controller.deck_view_scroll or 0))
  local oy = layout.area_y - scroll

  -- Défilement (2026-08-30) : recadre le rendu à la zone de contenu (bornes
  -- en pixels ÉCRAN, voir SCALE -- love.graphics.setScissor ignore les
  -- transformations ambiantes, contrairement à tout le reste de ce fichier)
  -- -- sans ça, les cartes qui débordent en haut/bas de `area_h` resteraient
  -- visibles par-dessus le titre/le bouton "Fermer".
  -- Le rect est désactivé PENDANT le rendu de chaque carte dans le canvas
  -- réutilisé ci-dessous, PUIS réactivé pour la recomposer à l'écran
  -- (2026-08-30, bug signalé -- "les cartes s'affichent minuscules, dans le
  -- coin") : le scissor est un état GLOBAL, pas affecté par push/origin/
  -- setCanvas -- resté actif pendant `draw_card_face` dans le petit canvas
  -- 92x138, ses coordonnées écran (pensées pour la zone de la fenêtre,
  -- ailleurs à l'écran) rognaient presque tout le contenu du canvas lui-même.
  local scissor_x, scissor_y = layout.area_x * SCALE, layout.area_y * SCALE
  local scissor_w, scissor_h = layout.area_w * SCALE, layout.area_h * SCALE
  love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)

  card_flight_canvas = card_flight_canvas or love.graphics.newCanvas(CARD_W, CARD_H)
  for i, entry in ipairs(cards) do
    local col = (i - 1) % layout.cols
    local row = math.floor((i - 1) / layout.cols)
    local cx = layout.ox + col * layout.cell_w
    local cy = oy + row * layout.cell_h

    love.graphics.setScissor()
    love.graphics.push()
    love.graphics.origin()
    local prev_canvas = love.graphics.getCanvas()
    love.graphics.setCanvas(card_flight_canvas)
    love.graphics.clear(0, 0, 0, 0)
    draw_card_face(entry.def, CARD_W, CARD_H, tostring(entry.def.cost or 0), entry.def.desc, Theme.muted, false, false, false, false)
    love.graphics.setCanvas(prev_canvas)
    love.graphics.pop()
    love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(card_flight_canvas, cx, cy, 0, layout.card_w / CARD_W, layout.card_h / CARD_H)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setScissor()

  -- Ascenseur (2026-08-30, demande explicite -- "prévoir un ascenseur s'il y
  -- a trop de cartes") : simple indicateur (molette pour défiler, voir
  -- Input.wheelmoved) -- track + curseur proportionné à la part visible du
  -- contenu total, jamais affiché quand tout tient déjà à l'écran.
  if layout.max_scroll > 0 then
    local track_x = layout.area_x + layout.area_w - DECK_VIEW_SCROLLBAR_W
    set(Theme.panel_light)
    love.graphics.rectangle("fill", track_x, layout.area_y, DECK_VIEW_SCROLLBAR_W, layout.area_h, 4, 4)
    local thumb_h = math.max(24, layout.area_h * layout.area_h / layout.content_h)
    local thumb_y = layout.area_y + (layout.area_h - thumb_h) * (scroll / layout.max_scroll)
    set(Theme.accent)
    love.graphics.rectangle("fill", track_x, thumb_y, DECK_VIEW_SCROLLBAR_W, thumb_h, 4, 4)
  end
end

function View.draw(controller)
  -- Menu pause (2026-09-02, demande explicite -- ESC depuis N'IMPORTE quel
  -- écran, voir Controller:handle_escape) : `draw_pause_menu` vérifie
  -- elle-même `controller.pause_menu_open` et ne fait rien sinon -- appelée à
  -- chaque point de sortie de cette fonction, même schéma déjà en place pour
  -- draw_deck_view (3 sites) juste en dessous, plutôt qu'une restructuration
  -- de toute la fonction pour un seul appel final commun.
  if controller.screen == "menu" then draw_menu(controller); draw_pause_menu(controller); return end
  if controller.screen == "options" then draw_options(controller); draw_pause_menu(controller); return end
  if controller.screen == "bossVictory" then draw_boss_victory(controller); draw_pause_menu(controller); return end
  if controller.screen == "biome_intro" then draw_biome_intro(controller); draw_pause_menu(controller); return end
  if controller.screen == "team_select" then draw_team_select(controller); draw_deck_view(controller); draw_pause_menu(controller); return end

  -- Écrans "camp" (2026-08-30, bug signalé -- "pendant le draft on voit
  -- encore les restes du combat, c'est une bonne chose. Par contre, quand on
  -- passe sur un évènement, c'est un changement de contexte, il ne faut
  -- montrer que l'évènement") : dispatchés à PART, comme team_select
  -- ci-dessus -- AUCUN élément de la scène de combat (ennemis, troupe, main,
  -- boutons du bas, particules/flottants résiduels) n'est dessiné en
  -- dessous, contrairement au draft (voir plus bas, qui continue de tomber
  -- dans le flux normal ci-dessous -- délibérément inchangé, "c'est une
  -- bonne chose"). Le décor d'ambiance (Background.draw) reste affiché --
  -- ce n'est pas "un reste du combat", juste la toile de fond du donjon.
  if controller.screen == "campfire" or controller.screen == "forge"
    or controller.screen == "temple" or controller.screen == "refuge" then
    Background.draw(controller.state.enemies, W, H)
    if controller.screen == "campfire" and controller.campfire then draw_campfire(controller)
    elseif controller.screen == "forge" and controller.forge then draw_forge(controller)
    elseif controller.screen == "temple" and controller.temple then draw_temple(controller)
    elseif controller.screen == "refuge" and controller.refuge then draw_refuge(controller)
    end
    -- Infobulles (2026-08-30, bug signalé -- "dans le Temple, il n'y a pas
    -- d'info bulle sur les statues, pourtant le '?' est bien présent") :
    -- régression du découpage de View.draw ci-dessus (2026-08-30, même
    -- jour) -- l'appel à draw_tooltip vivait plus bas dans cette fonction,
    -- gardé par une condition qui incluait "forge"/"temple" -- en dispatchant
    -- ces 2 écrans à part, tôt, avec un retour anticipé, ce bas de fonction
    -- (jamais modifié lui) est devenu inatteignable pour eux : le "?" (dessiné
    -- DANS draw_forge/draw_temple) restait visible, mais plus aucun appel ne
    -- venait jamais lire controller.hover pour composer le contenu de la
    -- bulle elle-même. Campfire/Refuge n'ont jamais eu de tooltip (aucune
    -- régression à corriger là).
    if controller.screen == "forge" or controller.screen == "temple" then
      draw_tooltip(controller)
    end
    draw_deck_view(controller)
    draw_pause_menu(controller)
    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  local state = controller.state
  Background.draw(state.enemies, W, H)

  -- Titre "Hero Card Game — Run Infini" retiré (2026-08-27, demande explicite) :
  -- redondant en plein combat, déjà affiché sur l'écran de menu (draw_menu).
  -- Compteur "X/9 avant le Boss" (2026-08-30, demande explicite -- run
  -- "bounded" uniquement -- "infini" n'a pas de Boss à annoncer, "boss_test"
  -- est déjà EN plein combat de boss dès le départ) : une fois DANS le combat
  -- de boss lui-même (state.run.is_boss), plus de "sur 9" à afficher.
  local combat_title
  if state.run.is_boss then
    combat_title = "Combat contre le Boss — Tour " .. state.turn
  elseif controller.run_mode == "bounded" then
    combat_title = "Combat " .. state.run.combat_index .. "/" .. BOUNDED_COMBAT_COUNT .. " avant le Boss — Tour " .. state.turn
  else
    combat_title = "Combat " .. state.run.combat_index .. " — Tour " .. state.turn
  end
  text(combat_title, 0, 30, W, 11, Theme.muted)

  text("Ennemis", 20, 40, 200, 10, Theme.muted, "left")
  -- Descente des ennemis à l'entrée en combat (2026-08-30, demande explicite --
  -- voir Controller:play_enemy_entrance_sequence, seul endroit qui peuple
  -- controller.enemy_entrance) : tant que son délai n'est pas écoulé, l'ennemi
  -- n'est pas encore dessiné DU TOUT (encore hors-écran, rien à montrer) --
  -- une fois le délai passé, le rect qu'on lui passe se contente d'avoir un y
  -- interpolé depuis le haut de l'écran, jamais draw_enemy lui-même modifié :
  -- x/w/h restent ceux de repos (View.enemy_rects), même rebond d'atterrissage
  -- (ease_out_back) que la pioche de carte, cohérence visuelle voulue.
  local enemy_rects_now = View.enemy_rects(state)
  for _, e in ipairs(state.enemies) do
    local r = enemy_rects_now[e.id]
    local entrance = controller.enemy_entrance[e.id]
    if not entrance then
      draw_enemy(controller, e, r)
    elseif entrance.elapsed >= entrance.delay then
      local ease = ease_out_back(entrance.elapsed - entrance.delay, entrance.duration)
      local from_y = -r.h - 40
      draw_enemy(controller, e, { x = r.x, y = from_y + (r.y - from_y) * ease, w = r.w, h = r.h })
    end
  end

  -- Recalé de HERO_ROW_Y-14 à HERO_ROW_Y-28 (2026-09-02) : libère la ligne
  -- HERO_ROW_Y-14 pour le HUD "PO" juste en dessous, voir draw_gold_display.
  text("Ta troupe", 20, HERO_ROW_Y - 28, 200, 10, Theme.muted, "left")
  draw_gold_display(state)
  for _, h in ipairs(state.heroes) do draw_hero(controller, h, View.hero_rects(state)[h.id]) end

  draw_enemy_target_arrows(controller)

  -- Fenêtre de log retirée pour l'instant (2026-08-08, demande explicite -- l'espace
  -- gagné sert à séparer visuellement la troupe des ennemis, voir HERO_ROW_Y ci-dessus).
  -- `state.log` continue d'être alimenté côté règles, juste plus affiché ici.

  draw_hand(controller)
  draw_bottom_controls(controller)
  -- 632->662 (2026-08-31, passage 1280x720) : suit le même décalage que la
  -- rangée de boutons du bas (HAND_Y/BOTTOM_ROW_Y), pour rester à la même
  -- hauteur relative entre la colonne de boutons et "Fin de tour".
  text(hint_text(controller), 0, 662, W, 10, Theme.muted)

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
  elseif controller.screen == "victory" then
    set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)

    -- Titre "Victoire !" en zoom + bump (2026-08-08) : seul élément affiché
    -- au tout début de l'écran, avant même que les gains n'existent
    -- visuellement -- voir Controller:enter_victory_screen pour le séquencement.
    local va = controller.victory_anim
    local title_scale = va and ease_out_back(va.t, controller.victory_title_duration) or 1
    love.graphics.push()
    love.graphics.translate(W / 2, 72)
    love.graphics.scale(title_scale, title_scale)
    love.graphics.translate(-W / 2, -72)
    text("Victoire !", 0, 60, W, 24, Theme.text)
    love.graphics.pop()

    if controller.victory_gains_shown then
      text("Combat " .. (state.run.combat_index) .. " remporté ! Récupère tes gains.", 0, 92, W, 12, Theme.muted)

      -- Gain "PO" (2026-09-02, demande explicite) : cliquable tant que non
      -- collecté -- voir Controller:click_victory_gold pour le vol de pièces
      -- vers le HUD (draw_coin_flights, plus bas dans View.draw) et le
      -- "fluf"/"cling" associés.
      local gr = View.victory_gold_rect
      panel(gr.x, gr.y, gr.w, gr.h, Theme.panel_light)
      set(controller.victory_gold_collected and Theme.muted or Theme.gold)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", gr.x, gr.y, gr.w, gr.h, 10, 10)
      love.graphics.setLineWidth(1)
      if controller.victory_gold_collected then
        text("Récupéré", gr.x, gr.y + gr.h / 2 - 6, gr.w, 12, Theme.muted, "center")
      else
        local coin_icon = Sprites.keyword("or")
        if coin_icon then
          love.graphics.setColor(1, 1, 1, 1)
          Sprites.draw_centered(coin_icon, gr.x + gr.w / 2, gr.y + 46, 28)
        end
        text("+" .. controller.victory_gold_reward .. " PO", gr.x, gr.y + 92, gr.w, 16, Theme.gold, "center")
      end

      -- Gain "carte" (2026-09-02, demande explicite) : icône de carte avec un
      -- "?", clic lance le draft existant -- voir Controller:click_victory_card.
      local cr = View.victory_card_rect
      panel(cr.x, cr.y, cr.w, cr.h, Theme.panel_light)
      set(controller.victory_card_collected and Theme.muted or Theme.accent)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", cr.x, cr.y, cr.w, cr.h, 10, 10)
      love.graphics.setLineWidth(1)
      if controller.victory_card_collected then
        text("Récupérée", cr.x, cr.y + cr.h / 2 - 6, cr.w, 12, Theme.muted, "center")
      elseif controller.draft_picks then
        text("Choisis une carte\nci-dessous…", cr.x, cr.y + cr.h / 2 - 14, cr.w, 22, Theme.muted, "center")
      else
        text("?", cr.x, cr.y + cr.h / 2 - 22, cr.w, 32, Theme.text, "center")
        text("Nouvelle carte", cr.x, cr.y + cr.h - 26, cr.w, 12, Theme.muted, "center")
      end
    end

    if controller.draft_picks and controller.draft_cards_shown then
      local rects = View.draft_rects(controller)
      local choice_anim = controller.draft_choice_anim
      for i, def in ipairs(controller.draft_picks) do
        local r = rects[i]
        if choice_anim and choice_anim.chosen_index == i then
          -- Carte choisie (2026-09-02, demande explicite -- "la carte
          -- choisie rejoint la pioche dans un mouvement ample") : dessinée à
          -- part, voir DraftFx.flight -- ni le retournement ni le fondu
          -- ci-dessous ne s'appliquent à elle.
          DraftFx.flight(def, r, choice_anim)
        elseif choice_anim then
          -- Cartes NON choisies (2026-09-02, demande explicite -- "les
          -- autres disparaissent doucement") : fondu, voir DraftFx.fading --
          -- restent immobiles à leur rect de repos, seule leur opacité change.
          local fp = math.min(1, choice_anim.t / choice_anim.other_fade_duration)
          DraftFx.fading(def, r, 1 - fp)
        else
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
            DraftFx.front(def)
          else
            panel(0, 0, r.w, r.h, Theme.panel_light)
            text("?", 0, r.h / 2 - 12, r.w, 26, Theme.muted)
          end
          love.graphics.pop()
        end
      end

      -- "Ne rien prendre" (2026-08-30, demande explicite -- "si le joueur ne
      -- veut gagner aucune des cartes proposées, il peut cliquer sur le
      -- bouton... à la place de cliquer sur une carte") : sous la rangée de
      -- cartes, voir View.draft_skip_button/Controller:skip_draft. Masqué
      -- pendant le vol de la carte choisie (2026-09-02) : un choix est déjà
      -- fait, "Ne rien prendre" n'a plus de sens tant que l'animation joue.
      if not choice_anim then
        local sb = View.draft_skip_button
        set(Theme.panel_light); love.graphics.rectangle("fill", sb.x, sb.y, sb.w, sb.h, 8, 8)
        set(Theme.muted); love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sb.x, sb.y, sb.w, sb.h, 8, 8)
        love.graphics.setLineWidth(1)
        text(sb.label, sb.x, sb.y + 14, sb.w, 14, Theme.text, "center")
      end
    end

    -- "Continuer" (2026-09-02, demande explicite -- "un bouton continuer
    -- grisé non clicable" jusqu'à récupération des 2 gains) : SIBLING du bloc
    -- draft_picks ci-dessus, PAS nichée dedans (bug signalé -- "le bouton
    -- Continuer disparaît une fois la carte choisie récupérée" : une fois
    -- l'animation de choix finie, Controller:update vide draft_picks, ce qui
    -- rendait tout ce bloc -- Continuer compris -- inatteignable) : doit
    -- rester visible/actif que draft_picks soit peuplé ou non, tant que
    -- victory_gains_shown est vrai. Style actif identique aux autres boutons
    -- pleins (Theme.accent, voir le bouton de redémarrage de l'écran
    -- "Défaite" plus haut) une fois les 2 flags vrais, sinon grisé
    -- (Theme.panel_light) -- voir Controller:victory_continue, déjà lui-même
    -- un no-op tant que les 2 gains ne sont pas faits (défense en profondeur,
    -- même si ce bouton grisé ne devrait jamais être cliqué).
    if controller.victory_gains_shown then
      local cb = View.victory_continue_button
      local can_continue = controller.victory_gold_collected and controller.victory_card_collected
      set(can_continue and Theme.accent or Theme.panel_light)
      love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
      set(Theme.muted); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
      love.graphics.setLineWidth(1)
      text(cb.label, cb.x, cb.y + 14, cb.w, 14, can_continue and Theme.bg or Theme.muted, "center")
    end
  end
  -- campfire/refuge/forge/temple : dispatchés à part, tout en haut de cette
  -- fonction (return anticipé) -- jamais atteints ici.

  draw_targeting_arrow(controller)
  draw_card_flights(controller)
  draw_coin_flights(controller)
  draw_gold_purse_overlay(controller)
  draw_particles(controller)
  draw_floaters(controller)
  if controller.screen == "playing" or controller.screen == "victory" then
    draw_tooltip(controller)
  end

  draw_deck_view(controller)
  draw_pause_menu(controller)

  love.graphics.setColor(1, 1, 1, 1)
end

-- y=160->320 (2026-09-02, demande explicite -- écran de victoire à gains
-- détachés) : la rangée de 3 cartes du draft n'apparaît plus qu'APRÈS un
-- clic explicite sur le gain "carte" (voir Controller:click_victory_card),
-- sous la rangée des 2 gains (PO/carte, voir View.victory_gold_rect/
-- View.victory_card_rect ci-dessous, y=130-290) -- décalée pour ne pas la
-- recouvrir.
function View.draft_rects(controller)
  if not controller.draft_picks or not controller.draft_cards_shown then return {} end
  return centered_row(#controller.draft_picks, DraftFx.w, DraftFx.h, 320, 24)
end

-- "Ne rien prendre" (2026-08-30, demande explicite) : sous la rangée de
-- cartes (voir View.draft_rects ci-dessus) -- position fixe, ne dépend pas du
-- nombre de cartes proposées (toujours centrée).
-- y=370->530 (2026-09-02, suit le décalage de View.draft_rects ci-dessus).
View.draft_skip_button = { x = W / 2 - 100, y = 530, w = 200, h = 44, label = "Ne rien prendre" }

-- Écran de victoire à gains détachés (2026-09-02, demande explicite) : les 2
-- gains (PO/carte) forment une paire fixe, l'un à côté de l'autre, QUEL QUE
-- SOIT l'état de collecte de chacun (pas de réagencement au clic -- seul le
-- CONTENU de chaque case change, voir le bloc screen == "victory" de
-- View.draw) -- la case "carte" n'est qu'un "?" avant clic, la vraie rangée
-- de 3 cartes du draft apparaît PLUS BAS (View.draft_rects, y=320).
local victory_gain_rects = centered_row(2, 180, 160, 130, 40)
View.victory_gold_rect = victory_gain_rects[1]
View.victory_card_rect = victory_gain_rects[2]

-- "Continuer" (2026-09-02, demande explicite -- "un bouton continuer grisé
-- non clicable" jusqu'à ce que les 2 gains soient faits) : sous la rangée de
-- cartes/le bouton "Ne rien prendre" (y<=574), avec de la marge -- voir le
-- style grisé/actif dans le bloc screen == "victory" de View.draw.
View.victory_continue_button = { x = W / 2 - 100, y = 610, w = 200, h = 44, label = "Continuer" }

return View
