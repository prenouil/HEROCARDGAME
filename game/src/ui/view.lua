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
local Heroes = require("src.data.heroes")
local Enemies = require("src.data.enemies")
local Combat = require("src.rules.combat")

local View = {}

local function combats_won_text(controller)
  return tostring(math.max(0, controller.state.run.combat_index - 1))
end

local W, H = 960, 700
View.W, View.H = W, H

local UNIT_W, UNIT_H = 150, 156 -- +28 (2026-08-08) pour l'affichage d'énergie agrandi ci-dessous
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

local HERO_ROW_Y = 238 -- espace troupe/ennemis agrandi (2026-08-08) : 56px de marge sous les cartes ennemies (54+128=182), au lieu de 0 avant

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

-- Boutons "Jouer"/"Se concentrer" par héros (2026-08-08) : un clic choisit à
-- la fois le mode ET le héros en un seul geste, ancré au bas de chaque
-- encart. Coords locales (relatives au coin haut-gauche de la carte) --
-- réutilisées telles quelles par draw_hero (espace déjà translaté) et
-- décalées de r.x/r.y ici pour le hit-testing (input.lua).
local HERO_BTN_H, HERO_BTN_GAP = 15, 3

local function hero_action_local_rects(r)
  local w = r.w - 12
  local by = r.h - (HERO_BTN_H * 2 + HERO_BTN_GAP) - 6
  return {
    play = { x = 6, y = by, w = w, h = HERO_BTN_H },
    concentrate = { x = 6, y = by + HERO_BTN_H + HERO_BTN_GAP, w = w, h = HERO_BTN_H },
  }
end
View.hero_action_local_rects = hero_action_local_rects

function View.hero_action_rects(state)
  local rects = View.hero_rects(state)
  local out = {}
  for _, h in ipairs(state.heroes) do
    local r = rects[h.id]
    if r then
      local lr = hero_action_local_rects(r)
      out[h.id] = {
        play = { x = r.x + lr.play.x, y = r.y + lr.play.y, w = lr.play.w, h = lr.play.h },
        concentrate = { x = r.x + lr.concentrate.x, y = r.y + lr.concentrate.y, w = lr.concentrate.w, h = lr.concentrate.h },
      }
    end
  end
  return out
end

-- Mode "flèche" (2026-08-09, spike) : chaque encart héros porte deux zones de
-- clic à la place des boutons -- 3/4 haut = jouer la carte, 1/4 bas = se
-- concentrer, tel que spécifié par le porteur de projet. Layout et
-- hit-testing partagent la même fonction, même discipline que hero_action_rects.
local HERO_ZONE_SPLIT = 0.75

local function hero_zone_local_rects(r)
  local action_h = r.h * HERO_ZONE_SPLIT
  return {
    play = { x = 0, y = 0, w = r.w, h = action_h },
    concentrate = { x = 0, y = action_h, w = r.w, h = r.h - action_h },
  }
end
View.hero_zone_local_rects = hero_zone_local_rects

function View.hero_zone_rects(state)
  local rects = View.hero_rects(state)
  local out = {}
  for _, h in ipairs(state.heroes) do
    local r = rects[h.id]
    if r then
      local lr = hero_zone_local_rects(r)
      out[h.id] = {
        play = { x = r.x + lr.play.x, y = r.y + lr.play.y, w = lr.play.w, h = lr.play.h },
        concentrate = { x = r.x + lr.concentrate.x, y = r.y + lr.concentrate.y, w = lr.concentrate.w, h = lr.concentrate.h },
      }
    end
  end
  return out
end

-- Calcule les rects de la main à partir d'une LISTE de cartes explicite plutôt
-- que de `state.hand` directement -- permet de rejouer la mise en page d'une
-- main passée (avant une défausse, par ex.) même après que `state.hand` a déjà
-- changé, pour les animations de vol de carte (voir controller.lua).
function View.hand_rects_for(cards)
  local rects = centered_row(#cards, CARD_W, CARD_H, 404)
  local out = {}
  for i, c in ipairs(cards) do out[c.uid] = rects[i] end
  return out
end

function View.hand_rects(state)
  return View.hand_rects_for(state.hand)
end

View.deck_pile_rect = { x = 20, y = 404, w = 64, h = CARD_H }
View.discard_pile_rect = { x = W - 84, y = 404, w = 64, h = CARD_H }

-- "Jouer"/"Se concentrer" ont migré sur chaque encart héros (2026-08-08, voir
-- hero_action_local_rects ci-dessus) ; il ne reste ici que l'annulation de la
-- sélection de carte en cours.
View.cancel_button = { x = W / 2 - 50, y = 560, w = 100, h = 32, label = "Annuler" }
View.end_turn_button = { x = W / 2 - 150, y = 600, w = 140, h = 32, label = "Fin de tour" }
-- Outil de test discret (2026-08-08) : termine le combat en cours par une
-- victoire immédiate, sans passer par la résolution réelle des ennemis. Prend
-- l'ancien emplacement de restart_button (2026-08-10, voir ci-dessous).
View.instant_victory_button = { x = View.end_turn_button.x + View.end_turn_button.w + 10, y = 604, w = 140, h = 24, label = "victoire instantanée" }
-- Recommencer le combat : déplacé (2026-08-10, demande explicite) sur l'ancien
-- emplacement de la bascule 3-clics/flèche, retirée -- le mode flèche est le canon
-- depuis longtemps (voir decision-log.md, 2026-08-09), le bouton n'avait plus lieu
-- d'être. Recommencer le TOUR juste au-dessus (voir Game.snapshot_turn/
-- restore_turn_snapshot) : granularité plus fine, sans perdre le combat entier.
View.restart_button = { x = View.instant_victory_button.x + View.instant_victory_button.w + 10, y = 600, w = 180, h = 32, label = "Recommencer le combat" }
View.restart_turn_button = { x = View.restart_button.x, y = View.restart_button.y - 32 - 6, w = 180, h = 32, label = "Recommencer ce tour" }
View.overlay_restart_button = { x = W / 2 - 70, y = H / 2 + 40, w = 140, h = 34, label = "Rejouer" }

-- Écran "feuDeCamp" (2026-08-10, demande explicite) : deux panneaux fixes
-- côte à côte (soin/résurrection, amélioration de carte) -- leur position ne
-- dépend jamais de ce qu'ils affichent, seul leur contenu/contour change
-- selon la disponibilité (voir View.draw). "Passer" n'est dessiné/cliquable
-- que quand les deux sont grisés (voir Controller:choose_feu_de_camp_skip).
local FEU_DE_CAMP_PANEL_W, FEU_DE_CAMP_PANEL_H, FEU_DE_CAMP_PANEL_GAP = 380, 320, 40
local FEU_DE_CAMP_PANEL_X0 = (W - (FEU_DE_CAMP_PANEL_W * 2 + FEU_DE_CAMP_PANEL_GAP)) / 2
View.feu_de_camp_heal_rect = { x = FEU_DE_CAMP_PANEL_X0, y = 150, w = FEU_DE_CAMP_PANEL_W, h = FEU_DE_CAMP_PANEL_H }
View.feu_de_camp_upgrade_rect = {
  x = FEU_DE_CAMP_PANEL_X0 + FEU_DE_CAMP_PANEL_W + FEU_DE_CAMP_PANEL_GAP, y = 150,
  w = FEU_DE_CAMP_PANEL_W, h = FEU_DE_CAMP_PANEL_H,
}
View.feu_de_camp_skip_button = { x = W / 2 - 100, y = 500, w = 200, h = 44, label = "Passer" }

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

--- Icône de statut (voir src/ui/icons.lua) avec sa valeur numérique à côté
-- (value peut être nil, ex. Camouflage qui n'a pas de compteur) ; repli texte
-- "ABBR valeur" si la clé n'a pas d'icône dessinée. `pop_t`/`pop_duration`
-- (2026-08-09, optionnels) : le badge part agrandi et retombe à sa taille
-- normale pendant `pop_duration` -- signale visuellement qu'il vient d'être
-- appliqué, sans rien changer quand ils sont absents (statut déjà présent).
local function status_badge(status_key, abbr, value, x, y, w, size, color, pop_t, pop_duration)
  local cx, cy = x + size * 0.55, y + size / 2
  local scale = 1
  if pop_t and pop_duration then
    scale = 1 + 0.5 * (1 - math.min(1, pop_t / pop_duration))
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

--- Silhouette de bouclier indépendante de celle d'Icons.draw_shield -- celle-ci
-- ignore l'alpha qu'on lui passe (`set(color)` interne y fixe toujours 1, pensé
-- pour des badges toujours à pleine opacité) ; ici il faut un vrai fondu, d'où
-- cette petite copie plutôt qu'un module partagé à retoucher pour un seul usage.
local function draw_big_shield(cx, cy, r, color, alpha)
  set(color, alpha)
  local hw, hh = r * 0.65, r * 0.85
  love.graphics.polygon("fill",
    cx - hw, cy - hh, cx + hw, cy - hh, cx + hw, cy - hh * 0.15,
    cx, cy + hh, cx - hw, cy - hh * 0.15)
end

--- Gros bouclier en fondu (2026-08-09, retour du porteur de projet) sur un
-- gain de Défense : 1s, fondu entrant/sortant, `r` = rect LOCAL de la carte
-- (déjà dans l'espace translaté de draw_hero/draw_enemy).
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
  draw_big_shield(r.w / 2, r.h / 2, r.w * 0.4, Theme.def, alpha * 0.9)
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------- unités (héros/ennemis) ----------

local function draw_hero(controller, h, r)
  local dead = h.hp <= 0

  local pending = controller.state.pending
  -- Fenêtre de décision "quel héros, quel mode" (2026-08-08) : les boutons
  -- Jouer/Se concentrer s'affichent directement sur l'encart, au lieu d'une
  -- rangée globale -- un clic choisit héros + mode en un seul geste.
  local showing_action_buttons = pending and not pending.mode and not dead
  local can_play = showing_action_buttons and Combat.can_play(h, pending)
  local can_concentrate = showing_action_buttons and Combat.can_concentrate(h)
  local eligible_target = pending and pending.hero_id and pending.def.target == "ally" and not dead and h.id ~= pending.hero_id
  -- `Game.assign_hero` fixe `has_acted = true` dès l'assignation, avant même
  -- la résolution de la cible (enemy/ally/conditional en attente d'un clic) --
  -- le héros ne doit pourtant apparaître grisé qu'une fois son action
  -- pleinement résolue, pas pendant qu'on choisit encore la cible de SA carte.
  local awaiting_own_target = pending and pending.hero_id == h.id
  -- État persistant de l'encart (2026-08-08, remplace la mention texte "a agi
  -- ce tour") : cadre vert tant que le héros peut agir (pas seulement pendant
  -- la sélection d'une carte -- indicateur permanent), voile gris dès qu'il a
  -- agi ce tour.
  local ready = not dead and not h.has_acted
  local greyed_out = not dead and h.has_acted and not eligible_target and not awaiting_own_target

  -- Cadre bleu = cible possible pour la carte en attente (allié) ; priorité
  -- sur le vert "prêt à agir" -- un héros peut être les deux à la fois (pas
  -- encore agi ce tour ET ciblable), mais l'invite de ciblage est l'info
  -- pertinente dans l'instant.
  local border, border_w = Theme.panel_light, 1
  if eligible_target then
    border, border_w = Theme.energy, 3
  elseif ready then
    border, border_w = Theme.heal, 3
  elseif greyed_out then
    border, border_w = Theme.muted, 1
  end

  -- Survol des deux zones (mode "flèche", 2026-08-09) : calculé sur le rect
  -- ABSOLU, avant toute translation d'animation -- doit rester en phase avec
  -- le hit-test réel d'input.lua, qui lit le même View.hero_zone_rects.
  local arrow_mode = controller.input_mode == "arrow"
  local hovering_play, hovering_concentrate = false, false
  if arrow_mode and showing_action_buttons then
    local mx, my = love.mouse.getPosition()
    mx, my = mx / SCALE, my / SCALE
    local z = hero_zone_local_rects(r)
    hovering_play = point_in({ x = r.x + z.play.x, y = r.y + z.play.y, w = z.play.w, h = z.play.h }, mx, my)
    hovering_concentrate = not hovering_play
      and point_in({ x = r.x + z.concentrate.x, y = r.y + z.concentrate.y, w = z.concentrate.w, h = z.concentrate.h }, mx, my)
  end

  local dx, dy, scale = unit_anim_transform(controller, h.id)
  -- Petit rebond continu quand la zone survolée est valide : le "VFX clair" +
  -- "anim simple" demandés pour distinguer Jouer/Concentrer au survol. Même
  -- rebond quand ce héros est la cible finale survolée (carte à cible alliée,
  -- ex. Rempart) -- cohérent avec le pulse ajouté côté ennemis (draw_enemy).
  local hovering_as_ally_target = false
  if arrow_mode and eligible_target then
    local mx, my = love.mouse.getPosition()
    mx, my = mx / SCALE, my / SCALE
    hovering_as_ally_target = point_in(r, mx, my)
  end
  if (hovering_play and can_play) or (hovering_concentrate and can_concentrate) or hovering_as_ally_target then
    scale = scale * (1 + 0.035 * math.sin(love.timer.getTime() * 8))
  end

  love.graphics.push()
  love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-r.w / 2, -r.h / 2)

  set(Theme.panel, dead and 0.5 or 1)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  set(border); love.graphics.setLineWidth(border_w)
  love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

  set(Theme.text, dead and 0.45 or 1)
  draw_class_icon(h.class_id, h.icon, h.label, 0, 4, r.w, 40, Theme.text)
  local hero_palette = Theme.card_class[h.class_id] or Theme.card_class.generic
  name_badge(h.name, 0, 44, r.w, 16, hero_palette.border, Theme.bg, 4, 2)
  bar(8, 62, r.w - 16, 7, h.hp / h.max_hp, Theme.hp)
  text(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", 0, 71, r.w, 9, Theme.muted)

  -- Énergie : nombre précis + icône, en gros (2026-08-08, doublement de taille sur
  -- retour du porteur de projet) plutôt que 6 pastilles -- réutilise RichText comme
  -- pour le texte de carte, juste avec un `size` bien plus grand.
  RichText.draw(h.energy .. ' "energie"', 0, 84, r.w, 24, Theme.energy)

  if showing_action_buttons and arrow_mode then
    -- Mode "flèche" : pas de boutons texte -- un halo coloré + libellé
    -- apparaît uniquement sous le curseur, sur la zone survolée (rouge/`Theme.hp`
    -- si cette zone précise n'est pas jouable, jamais un bouton grisé permanent).
    local z = hero_zone_local_rects(r)
    local function zone_vfx(zone, enabled, hovering, label, base_color)
      if not hovering then return end
      local tint = enabled and base_color or Theme.hp
      set(tint, 0.28)
      love.graphics.rectangle("fill", zone.x, zone.y, zone.w, zone.h, 8, 8)
      set(tint); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", zone.x, zone.y, zone.w, zone.h, 8, 8)
      love.graphics.setLineWidth(1)
      set(Theme.text)
      love.graphics.setFont(Fonts.get(9))
      love.graphics.printf(label, zone.x, zone.y + zone.h / 2 - 5, zone.w, "center")
    end
    zone_vfx(z.play, can_play, hovering_play, "Jouer", Theme.heal)
    zone_vfx(z.concentrate, can_concentrate, hovering_concentrate, "Concentrer", Theme.energy)
  elseif showing_action_buttons then
    local ar = hero_action_local_rects(r)
    local function action_button(rect, label, enabled, base_color)
      set(enabled and base_color or Theme.muted, enabled and 1 or 0.35)
      love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 5, 5)
      set(Theme.bg, enabled and 1 or 0.6)
      love.graphics.setFont(Fonts.get(9))
      love.graphics.printf(label, rect.x, rect.y + 3, rect.w, "center")
    end
    action_button(ar.play, "Jouer", can_play, Theme.accent)
    action_button(ar.concentrate, "Concentrer", can_concentrate, Theme.status)
  else
    local badges = {}
    if h.defense > 0 then badges[#badges + 1] = { key = "defense", abbr = "DEF", value = h.defense } end
    if (h.esquive or 0) > 0 then badges[#badges + 1] = { key = "esquive", abbr = "ESQ", value = h.esquive } end
    if (h.camoufle or 0) > 0 then badges[#badges + 1] = { key = "camoufle", abbr = "CAM", value = h.camoufle } end
    if (h.puissance or 0) > 0 then badges[#badges + 1] = { key = "puissance", abbr = "PUI", value = h.puissance } end
    if (h.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = h.saignements } end
    draw_badge_row(badges, 0, 112, r.w, 16, Theme.status, controller.status_pop[h.id], controller.status_pop_duration)
  end

  -- Voile gris par-dessus tout le contenu déjà dessiné (cadre compris) quand
  -- le héros a déjà agi -- chaque élément ci-dessus fixe sa propre couleur,
  -- un voile en overlay évite de les reprendre un par un.
  if greyed_out then
    set(Theme.black, 0.55)
    love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  end

  draw_shield_fx(controller, h.id, r)

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

local function enemy_telegraph_text(state, e)
  if e.hp <= 0 then return "Vaincu." end
  local move = e.next_move
  if not move then return "" end
  -- Montant réellement ajusté (2026-08-09, demande explicite) : la propre
  -- Incapacité de l'ennemi ET la Vulnérabilité de sa cible (déjà fixée pour
  -- tout le tour, pas besoin de survol) -- même calcul que la résolution
  -- réelle (Combat.deal_damage, via resolve_enemy_attack), jamais une
  -- deuxième formule dupliquée ici.
  local target = e.target_hero_id and Combat.hero_by_id(state, e.target_hero_id)
  local function adjusted(amount)
    return Combat.round(amount * Combat.damage_multiplier(e, target, "physique", false))
  end
  if move.kind == "dmg" or move.kind == "debuff" then
    local amount_text
    if move.kind == "dmg" then
      amount_text = adjusted(move.amount) .. " dégâts" .. (move.brut and " brut" or "")
    else
      amount_text = (Enemies.status_labels[move.status_key] or move.status_key) .. " " .. move.amount
    end
    local vise = e.target_hero_id and ("\nvise " .. e.target_hero_id) or ""
    return move.name .. " — " .. amount_text .. vise
  elseif move.kind == "heal-self" then
    return move.name .. " — soigne " .. move.amount .. " PV"
  elseif move.kind == "heal-ally" then
    return move.name .. " — soigne un allié de " .. move.amount .. " PV"
  elseif move.kind == "conditional-retaliate" then
    -- Bug signalé (2026-08-09) : contrairement à dmg/debuff juste au-dessus,
    -- cette branche n'affichait jamais la cible (`e.target_hero_id`, pourtant
    -- déjà tirée par Encounter.roll_telegraphs -- voir Combat.TARGETABLE_MOVE_KINDS)
    -- ni le fait que le Golem VA riposter une fois qu'il a déjà encaissé un coup
    -- ce tour (`e.took_damage_this_turn`, lu par Game.resolve_enemy_action).
    local vise = e.target_hero_id and ("\nvise " .. e.target_hero_id) or ""
    if e.took_damage_this_turn then
      return "Riposte (touché) — " .. adjusted(move.amount) .. " dégâts" .. vise
    end
    return move.name .. " — " .. adjusted(move.amount) .. " si touché" .. vise
  end
  return ""
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

  set(Theme.text, dead and 0.45 or 1)
  draw_enemy_icon(e.template_id, e.icon, e.label, 0, 4, r.w, 40, Theme.text)
  name_badge(e.name .. " Nv." .. e.level, 0, 44, r.w, 16, Theme.enemy_nameplate, Theme.text, 4, 3)
  if not dead then
    bar(8, 72, r.w - 16, 7, e.hp / e.max_hp, Theme.hp)
    text(math.max(0, e.hp) .. "/" .. e.max_hp .. " PV", 0, 81, r.w, 9, Theme.muted)
    local badges = {}
    if e.defense > 0 then badges[#badges + 1] = { key = "defense", abbr = "DEF", value = e.defense } end
    if (e.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = e.saignements } end
    if (e.incapacite or 0) > 0 then badges[#badges + 1] = { key = "incapacite", abbr = "INC", value = e.incapacite } end
    if (e.vulnerabilite or 0) > 0 then badges[#badges + 1] = { key = "vulnerabilite", abbr = "VUL", value = e.vulnerabilite } end
    draw_badge_row(badges, 0, 94, r.w, 16, Theme.status, controller.status_pop[e.id], controller.status_pop_duration)
  end
  text(enemy_telegraph_text(controller.state, e), 0, 110, r.w, 8, Theme.accent)
  draw_shield_fx(controller, e.id, r)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- ---------- main ----------

-- Aperçu dynamique de Transcendance (2026-08-09, demande explicite) : au
-- survol d'un héros pendant qu'une carte est sélectionnée, ses valeurs
-- affichent ce qu'elles VONT valoir si CE héros la joue -- ex. Coup direct
-- affiche 6 au lieu de 4 en survolant le Guerrier. Dérivé des mêmes règles
-- que Combat.deal_damage/grant_defense/grant_heal/effective_cost (classe du
-- héros + mot-clé de la carte) : jamais une deuxième copie de la logique de
-- jeu, seule la substitution dans le texte affiché est propre à la vue.
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
-- "soin", qui suivent une règle de Transcendance à part -- Paladin +50%
-- uniquement, jamais de cumul Puissance/Incapacité/Vulnérabilité dessus).
local DAMAGE_KEYWORDS = { epee = true, etincelle = true, fireball = true }

--- Aperçu du texte d'une carte si `hero` la joue (et, une fois la cible
-- choisie/survolée, `target`) -- réutilise Combat.damage_multiplier (voir
-- combat.lua : Puissance/Incapacité de l'attaquant + Vulnérabilité de la
-- cible additionnés AVANT d'être appliqués, jamais composés en chaîne) pour
-- que l'aperçu et la résolution réelle ne puissent jamais donner un nombre
-- différent. `target` peut être nil (héros pas encore assigné à une cible) --
-- la Vulnérabilité n'entre alors simplement pas encore en compte.
local function preview_desc(def, hero, target)
  local text = def.desc
  local guerrier_epee_bonus = hero.class_id == "guerrier" and Glossary.has_keyword(def.desc, "epee")
  local dmg_mult = Combat.damage_multiplier(hero, target, def.dmg_type, guerrier_epee_bonus)
  if dmg_mult ~= 1 then
    for kw in pairs(DAMAGE_KEYWORDS) do
      if Glossary.has_keyword(def.desc, kw) then text = scale_near_keyword(text, kw, dmg_mult) end
    end
  end
  if hero.class_id == "paladin" then
    if Glossary.has_keyword(def.desc, "bouclier") then text = scale_near_keyword(text, "bouclier", 1.5) end
    if Glossary.has_keyword(def.desc, "soin") then text = scale_near_keyword(text, "soin", 1.5) end
  elseif hero.class_id == "assassin" and Glossary.has_keyword(def.desc, "epee") then
    -- Pas un nombre existant à l'échelle -- la Transcendance Assassin AJOUTE
    -- un effet absent du texte de base, donc une phrase en plus plutôt qu'une
    -- substitution.
    text = text .. " (Transcendance : Incapacité 1, Vulnérabilité 1.)"
  end
  return text
end

-- Coût effectif : réutilise directement Combat.effective_cost (le -2 Mage sur
-- "sort"), jamais recalculé séparément ici.
local function preview_cost(def, hero)
  return Combat.effective_cost(hero, def)
end

--- Dessine le contenu plein d'une carte (fond teinté par classe, double contour,
-- pastille de coût, nom en cadre, description) dans l'espace local [0,0]..[w,h] --
-- l'appelant gère push/translate/scale/pop. Partagé entre la main (draw_one
-- ci-dessous) et le vol de cartes pioche/défausse (draw_card_flights) : une carte
-- en plein vol doit avoir exactement le même visage qu'immobile en main, jamais un
-- second rendu qui diverge (voir Theme.card_class).
local function draw_card_face(def, w, h, cost_text, desc_text, desc_color, highlight)
  local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
  panel(0, 0, w, h, palette.bg)
  set(highlight and Theme.accent or Theme.black)
  love.graphics.setLineWidth(highlight and 3 or 2)
  love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
  set(palette.border)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 3, 3, w - 6, h - 6, 8, 8)
  love.graphics.setLineWidth(1)

  set(Theme.energy); love.graphics.circle("fill", 14, 12, 9)
  set(Theme.bg or { 0.05, 0.1, 0.1 })
  love.graphics.setFont(Fonts.get(11)); love.graphics.printf(tostring(cost_text), 4, 6, 20, "center")

  name_badge(def.name, 2, 22, w - 4, 16, palette.border, Theme.bg, 2, 1)
  RichText.draw(desc_text, 3, 42, w - 6, 10, desc_color or Theme.muted)
end

local function draw_hand(controller)
  local state = controller.state
  local rects = View.hand_rects(state)
  panel(View.deck_pile_rect.x, View.deck_pile_rect.y, View.deck_pile_rect.w, View.deck_pile_rect.h, Theme.panel_light)
  icon_text("\u{1F0A0}", "", View.deck_pile_rect.x, View.deck_pile_rect.y + 20, View.deck_pile_rect.w, 22, Theme.muted)
  text("PIOCHE", View.deck_pile_rect.x, View.deck_pile_rect.y + 54, View.deck_pile_rect.w, 9, Theme.muted)
  text(tostring(#state.deck), View.deck_pile_rect.x, View.deck_pile_rect.y + View.deck_pile_rect.h + 4, View.deck_pile_rect.w, 12, Theme.text)

  panel(View.discard_pile_rect.x, View.discard_pile_rect.y, View.discard_pile_rect.w, View.discard_pile_rect.h, Theme.panel_light)
  icon_text("\u{1F5D1}\u{FE0F}", "", View.discard_pile_rect.x, View.discard_pile_rect.y + 20, View.discard_pile_rect.w, 22, Theme.muted)
  text("DEFAUSSE", View.discard_pile_rect.x, View.discard_pile_rect.y + 54, View.discard_pile_rect.w, 9, Theme.muted)
  text(tostring(#state.discard), View.discard_pile_rect.x, View.discard_pile_rect.y + View.discard_pile_rect.h + 4, View.discard_pile_rect.w, 12, Theme.text)

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

  local function draw_one(c, popped)
    local r = rects[c.uid]
    local def = c.def
    local is_pending = state.pending and state.pending.uid == c.uid
    -- Aperçu de Transcendance (voir preview_desc/preview_cost ci-dessus) :
    -- seulement sur LA carte sélectionnée. Deux étapes : héros pas encore
    -- assigné -> on prévisualise celui survolé (pas de cible connue, la
    -- Vulnérabilité n'entre pas encore en compte) ; héros déjà assigné et en
    -- attente d'une cible -> le héros est fixé (pending.hero_id), et survoler
    -- l'ennemi visé complète l'aperçu avec SA Vulnérabilité.
    local previewing_hero, previewing_target = nil, nil
    if is_pending and state.pending then
      if state.pending.hero_id then
        previewing_hero = Combat.hero_by_id(state, state.pending.hero_id)
        if controller.hover.kind == "enemy" then previewing_target = Combat.enemy_by_id(state, controller.hover.target) end
      elseif controller.hover.kind == "hero" then
        previewing_hero = Combat.hero_by_id(state, controller.hover.target)
      end
    end
    local desc_text, cost_text, has_bonus = def.desc, def.cost, false
    if previewing_hero then
      desc_text, cost_text = preview_desc(def, previewing_hero, previewing_target), preview_cost(def, previewing_hero)
      has_bonus = desc_text ~= def.desc or cost_text ~= def.cost
    end
    cost_text = tostring(cost_text)
    local scale, lift = 1, 0
    if popped then
      if is_pending then scale, lift = 1.16, 18 else scale, lift = 1.1, 10 end
    end
    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2 - lift)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-r.w / 2, -r.h / 2)

    -- La sélection (`is_pending`) reste exclusivement signalée par l'or de
    -- Theme.accent sur le contour extérieur, jamais mélangée à la couleur de classe.
    -- Pas de vert "bonus" sur le nom (collision de lisibilité avec l'Assassin, déjà
    -- vert) -- le vert reste porté par la description, qui suffit à signaler
    -- l'aperçu de Transcendance.
    draw_card_face(def, r.w, r.h, cost_text, desc_text, has_bonus and Theme.heal or Theme.muted, is_pending)
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

local function draw_cancel_button(controller)
  local pending = controller.state.pending
  if not pending or pending.mode then return end
  local b = View.cancel_button
  set(Theme.muted)
  love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
  set(Theme.bg); love.graphics.setFont(Fonts.get(12))
  love.graphics.printf(b.label, b.x, b.y + 8, b.w, "center")
end

local function draw_bottom_controls(controller)
  local b1, b2, b4 = View.end_turn_button, View.restart_button, View.restart_turn_button
  set(Theme.accent); love.graphics.rectangle("fill", b1.x, b1.y, b1.w, b1.h, 8, 8)
  set(Theme.bg); love.graphics.setFont(Fonts.get(12)); love.graphics.printf(b1.label, b1.x, b1.y + 8, b1.w, "center")
  set(Theme.muted); love.graphics.rectangle("line", b2.x, b2.y, b2.w, b2.h, 8, 8)
  text(b2.label, b2.x, b2.y + 8, b2.w, 12, Theme.text)
  set(Theme.muted); love.graphics.rectangle("line", b4.x, b4.y, b4.w, b4.h, 8, 8)
  text(b4.label, b4.x, b4.y + 8, b4.w, 12, Theme.text)

  -- Discret à dessein : pas de cadre, texte petit et sombre -- un outil de
  -- test, pas une action de jeu normale.
  local b3 = View.instant_victory_button
  text(b3.label, b3.x, b3.y + 7, b3.w, 8, Theme.muted)
end

local function hint_text(controller)
  local state = controller.state
  local pending = state.pending
  local arrow_mode = controller.input_mode == "arrow"
  if not pending then return "Clique une carte de ta main pour commencer." end
  if not pending.mode then
    if arrow_mode then return pending.def.name .. " sélectionnée — vise le haut (Jouer) ou le bas (Concentrer) d'un aventurier." end
    return pending.def.name .. " sélectionnée — clique \"Jouer\" ou \"Concentrer\" sur l'aventurier de ton choix."
  end
  if not pending.hero_id then return pending.def.name .. " — choisis quel aventurier." end
  if arrow_mode then return pending.def.name .. " — vise la cible." end
  return pending.def.name .. " — choisis la cible."
end

-- ---------- infobulle au survol (1s de délai, comme le prototype) ----------

-- Statuts actifs à lister dans l'infobulle héros/ennemi (2026-08-09, demande
-- explicite : "ajouter l'explication des statuts"). Mêmes champs que les
-- badges déjà affichés (draw_badge_row) -- réutilise les explications déjà
-- écrites dans le glossaire plutôt que d'en dupliquer le texte ; `defense`
-- n'a pas d'entrée dédiée dans le glossaire (seulement le mot-clé de carte
-- "bouclier"), d'où l'explication propre ci-dessous.
local STATUS_TOOLTIP_FIELDS = {
  { field = "defense", glossary_key = "bouclier", label = "Bouclier", explain = "Absorbe les prochains dégâts avant les PV." },
  { field = "esquive", glossary_key = "esquive" },
  { field = "camoufle", glossary_key = "camoufle" },
  { field = "puissance", glossary_key = "puissance" },
  { field = "saignements", glossary_key = "saignement" },
  { field = "incapacite", glossary_key = "incapacite" },
  { field = "vulnerabilite", glossary_key = "vulnerabilite" },
}

local function active_status_lines(unit)
  local lines = {}
  for _, spec in ipairs(STATUS_TOOLTIP_FIELDS) do
    local value = unit[spec.field]
    local active = spec.boolean and value or (type(value) == "number" and value > 0)
    if active then
      local g = Glossary.find_term(spec.glossary_key)
      local label = spec.label or (g and (g.label or g.icon)) or spec.field
      local explain = spec.explain or (g and g.explain ~= "" and g.explain) or ""
      local line_text = label .. (spec.boolean and "" or (" " .. value)) .. (explain ~= "" and (" — " .. explain) or "")
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
    local p = Heroes.class_powers[hero.class_id]
    local lines = { p.transcendance }
    for _, l in ipairs(active_status_lines(hero)) do lines[#lines + 1] = l end
    return hero.name, lines
  elseif h.kind == "enemy" then
    local e = Combat.enemy_by_id(controller.state, h.target)
    if not e then return nil end
    local template = Enemies.by_id(e.template_id)
    local lines = {}
    for _, m in ipairs(template.moves_info(e.level)) do
      lines[#lines + 1] = m.name .. " — " .. m.text
    end
    for _, l in ipairs(active_status_lines(e)) do lines[#lines + 1] = l end
    lines[#lines + 1] = "Niveau " .. e.level .. " · PV max " .. e.max_hp
    return e.name, lines
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
      local ease = 1 - (1 - p) ^ 2 -- easeOutQuad, approxime le cubic-bezier CSS du prototype
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
        -- Repli (garde-fou -- ne devrait plus arriver, toutes les entrées portent `def`).
        set(Theme.panel_light, alpha)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- Nombre de dégâts/soin flottant (2026-08-09, party "amélioration des
-- visuels") : monte et s'estompe depuis Controller:spawn_floater, couleur
-- selon le sens (dégâts/soin) -- pas de logique de jeu ici, juste l'interpolation.
local FLOATER_RISE = 34
local FLOATER_COLOR = { damage = "hp", heal = "heal" }
-- Retour du porteur de projet (2026-08-09) : les dégâts doivent taper plus
-- fort visuellement -- police nettement plus grosse + un zoom qui dépasse puis
-- se stabilise (ease_out_back, déjà utilisé pour le titre "Victoire !", pas
-- une nouvelle courbe). Le soin garde le traitement d'origine, plus discret.
local DAMAGE_FLOATER_SIZE = 26
local HEAL_FLOATER_SIZE = 15
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
local PARTICLE_GRAVITY = 160

local function draw_particles(controller)
  for _, pt in ipairs(controller.particles) do
    local p = math.min(1, pt.t / controller.particle_duration)
    local x = pt.x + pt.vx * pt.t
    local y = pt.y + pt.vy * pt.t + 0.5 * PARTICLE_GRAVITY * pt.t * pt.t
    set(Theme.hp, 1 - p)
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


-- Flèche dynamique (mode "flèche", 2026-08-09) : de la souris vers le héros
-- pendant le choix de l'aventurier, puis du héros vers la cible finale si la
-- carte en a besoin -- couleur dérivée des mêmes conditions d'éligibilité que
-- les cadres verts/bleus déjà en place (Combat.can_play/can_concentrate, cible
-- vivante), jamais une logique de validité dupliquée.
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
local function draw_arrow(x1, y1, x2, y2, color, tip_angle)
  local dx, dy = x2 - x1, y2 - y1
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then return end

  local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
  local nx, ny = -dy / dist, dx / dist
  local bow = math.min(dist * 0.22, 70) + math.sin(love.timer.getTime() * 3) * math.min(dist * 0.03, 8)
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
-- qui diverge). Rouge (Theme.hp) pour ne jamais se confondre avec le vert/bleu du
-- ciblage actif du joueur -- deux flèches, deux sens différents. Rien si l'ennemi
-- est mort, n'a pas de coup télégraphié, si son coup ne cible personne (kind hors
-- Combat.TARGETABLE_MOVE_KINDS -- soin, buff...), ou si la cible n'est plus vivante
-- -- jamais vers un autre ennemi, le ciblage ennemi ne vise que des aventuriers
-- (`target_hero_id`, voir encounter.lua).
local function draw_enemy_target_arrows(controller)
  local state = controller.state
  local enemy_rects = View.enemy_rects(state)
  local hero_rects = View.hero_rects(state)
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 and e.next_move and Combat.TARGETABLE_MOVE_KINDS[e.next_move.kind] and e.target_hero_id then
      local target = Combat.hero_by_id(state, e.target_hero_id)
      if target and target.hp > 0 then
        local er, hr = enemy_rects[e.id], hero_rects[target.id]
        if er and hr then
          draw_arrow(er.x + er.w / 2, er.y + er.h, hr.x + hr.w / 2, hr.y, Theme.hp, math.pi / 2)
        end
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function draw_targeting_arrow(controller)
  if controller.input_mode ~= "arrow" or controller.screen ~= "playing" then return end
  local state = controller.state
  local pending = state.pending
  if not pending then return end

  local mx, my = love.mouse.getPosition()
  mx, my = mx / SCALE, my / SCALE

  if not pending.mode then
    local origin = View.hand_rects(state)[pending.uid]
    if not origin then return end
    local ox, oy = origin.x + origin.w / 2, origin.y
    local color = Theme.energy
    local zones = View.hero_zone_rects(state)
    for _, h in ipairs(state.heroes) do
      local z = zones[h.id]
      if z then
        if point_in(z.play, mx, my) then
          color = Combat.can_play(h, pending) and Theme.heal or Theme.hp
        elseif point_in(z.concentrate, mx, my) then
          color = Combat.can_concentrate(h) and Theme.heal or Theme.hp
        end
      end
    end
    draw_arrow(ox, oy, mx, my, color)
  elseif pending.hero_id and (pending.def.target == "enemy" or pending.def.target == "ally" or pending.def.target == "conditional") then
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
end

-- ---------- feu de camp ----------

--- Petit triangle plein pointant vers le bas, centré en (cx, cy) -- PAS un
-- glyphe "↓" (2026-08-10, hors du charset Latin étendu de m5x7/m3x6, voir
-- fonts.lua : rien ne garantit qu'il existe dans la police chargée, contrairement
-- à un vecteur dessiné à la main comme draw_big_shield/draw_arrow ci-dessus).
local function draw_down_arrow(cx, cy, size, color)
  set(color)
  love.graphics.polygon("fill", cx - size, cy - size * 0.5, cx + size, cy - size * 0.5, cx, cy + size * 0.5)
end

--- Bandes de survol des 2 cartes proposées à l'amélioration -- position FIXE
-- dérivée de View.feu_de_camp_upgrade_rect, jamais du contenu (même principe
-- que les panneaux eux-mêmes, voir leur commentaire) -- réutilisée telle
-- quelle par draw_feu_de_camp (dessin) et input.lua (hover/tooltip).
function View.feu_de_camp_upgrade_card_rects()
  local r = View.feu_de_camp_upgrade_rect
  return {
    { x = r.x, y = r.y + 46, w = r.w, h = 100 },
    { x = r.x, y = r.y + 156, w = r.w, h = 100 },
  }
end

--- Écran "feuDeCamp" (2026-08-10, demande explicite) : entre le draft de fin de
-- combat et le combat suivant. Panneau "Repos" (soin/résurrection à 100% des PV
-- de l'aventurier le plus blessé, ou grisé si personne n'est blessé) et panneau
-- "Forge" (2 cartes tirées au hasard, chacune montrée base -> "+", ou grisé si
-- moins de 2 cartes améliorables) -- voir Controller:enter_feu_de_camp_screen
-- pour le tirage (fait une seule fois, à l'entrée sur l'écran).
local function draw_feu_de_camp(controller)
  local fdc = controller.feu_de_camp
  set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
  text("Feu de camp", 0, 60, W, 24, Theme.text)
  text("Choisis comment préparer le prochain combat.", 0, 92, W, 12, Theme.muted)

  local heal_r, up_r = View.feu_de_camp_heal_rect, View.feu_de_camp_upgrade_rect
  local heal_available = fdc.heal_target ~= nil
  local upgrade_available = fdc.upgrade_targets ~= nil

  panel(heal_r.x, heal_r.y, heal_r.w, heal_r.h, heal_available and Theme.panel_light or Theme.panel)
  set(heal_available and Theme.heal or Theme.muted)
  love.graphics.setLineWidth(heal_available and 3 or 2)
  love.graphics.rectangle("line", heal_r.x, heal_r.y, heal_r.w, heal_r.h, 10, 10)
  love.graphics.setLineWidth(1)
  text("Repos", heal_r.x, heal_r.y + 16, heal_r.w, 16, Theme.text)
  if heal_available then
    local hero = fdc.heal_target
    local palette = Theme.card_class[hero.class_id] or Theme.card_class.generic
    name_badge(hero.name, heal_r.x + 20, heal_r.y + 56, heal_r.w - 40, 14, palette.border, Theme.bg, 2, 4)
    text(hero.hp <= 0 and "Ramené à la vie, PV pleins." or "Soigné à 100% de ses PV.",
      heal_r.x + 20, heal_r.y + 100, heal_r.w - 40, 12, Theme.muted)
    bar(heal_r.x + 20, heal_r.y + 130, heal_r.w - 40, 14, hero.hp / hero.max_hp, Theme.hp)
    draw_down_arrow(heal_r.x + heal_r.w / 2, heal_r.y + 158, 8, Theme.heal)
    bar(heal_r.x + 20, heal_r.y + 172, heal_r.w - 40, 14, 1, Theme.heal)
  else
    text("Personne n'est blessé.", heal_r.x + 20, heal_r.y + heal_r.h / 2 - 8, heal_r.w - 40, 12, Theme.muted)
  end

  panel(up_r.x, up_r.y, up_r.w, up_r.h, upgrade_available and Theme.panel_light or Theme.panel)
  set(upgrade_available and Theme.accent or Theme.muted)
  love.graphics.setLineWidth(upgrade_available and 3 or 2)
  love.graphics.rectangle("line", up_r.x, up_r.y, up_r.w, up_r.h, 10, 10)
  love.graphics.setLineWidth(1)
  text("Forge", up_r.x, up_r.y + 16, up_r.w, 16, Theme.text)
  if upgrade_available then
    local card_rows = View.feu_de_camp_upgrade_card_rects()
    for i, instance in ipairs(fdc.upgrade_targets) do
      local def = instance.def
      local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
      local row_y = card_rows[i].y + 10
      name_badge(def.name, up_r.x + 20, row_y, up_r.w - 40, 13, palette.border, Theme.bg, 2, 3)
      draw_down_arrow(up_r.x + up_r.w / 2, row_y + 30, 7, Theme.accent)
      name_badge(def.name .. " +", up_r.x + 20, row_y + 46, up_r.w - 40, 13, Theme.accent, Theme.bg, 2, 3)
    end
  else
    text("Pas assez de cartes à améliorer.", up_r.x + 20, up_r.y + up_r.h / 2 - 8, up_r.w - 40, 12, Theme.muted)
  end

  if not heal_available and not upgrade_available then
    local b = View.feu_de_camp_skip_button
    set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    set(Theme.bg); text(b.label, b.x, b.y + 14, b.w, 14, Theme.bg)
  end
end

function View.draw(controller)
  local state = controller.state
  Background.draw(state.enemies, W, H)

  text("Hero Card Game — Run Infini", 0, 8, W, 20, Theme.text)
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
  draw_cancel_button(controller)
  draw_bottom_controls(controller)
  text(hint_text(controller), 0, 632, W, 10, Theme.muted)

  if controller.screen == "defeat" then
    set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
    text("Défaite…", 0, H / 2 - 40, W, 26, Theme.text)
    text("Le run s'arrête après " .. combats_won_text(controller) .. " combat(s) remporté(s).", 0, H / 2, W, 12, Theme.muted)
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
        else
          panel(0, 0, r.w, r.h, Theme.panel_light)
          text("?", 0, r.h / 2 - 12, r.w, 26, Theme.muted)
        end
        love.graphics.pop()
      end
    end
  elseif controller.screen == "feuDeCamp" and controller.feu_de_camp then
    draw_feu_de_camp(controller)
  end

  draw_targeting_arrow(controller)
  draw_card_flights(controller)
  draw_particles(controller)
  draw_floaters(controller)
  if controller.screen == "playing" or controller.screen == "draft" or controller.screen == "feuDeCamp" then
    draw_tooltip(controller)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function View.draft_rects(controller)
  if not controller.draft_picks or not controller.draft_cards_shown then return {} end
  return centered_row(#controller.draft_picks, 130, 190, 140, 24)
end

return View
