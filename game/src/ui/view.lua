-- Rendu et calcul de rectangles (layout + hit-testing partagent les mêmes
-- fonctions, pour ne jamais dessiner un bouton ailleurs qu'où on le clique).
-- Port "spirituel" (pas pixel pour pixel) de l'arène HTML/CSS du prototype :
-- même structure d'écran, rendu simplifié en rectangles/texte — les VFX/
-- animations détaillées sont un chantier volontairement différé (voir party
-- du 2026-08-06 : moteur d'abord, feedback visuel ensuite).

local Theme = require("src.ui.theme")
local Fonts = require("src.ui.fonts")
local Icons = require("src.ui.icons")
local Glossary = require("src.data.glossary")
local Heroes = require("src.data.heroes")
local Enemies = require("src.data.enemies")
local Combat = require("src.rules.combat")

local View = {}

local function combats_won_text(controller)
  return tostring(math.max(0, controller.state.run.combat_index - 1))
end

local W, H = 960, 700
View.W, View.H = W, H

local UNIT_W, UNIT_H = 150, 128
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

function View.hero_rects(state)
  local rects = centered_row(#state.heroes, UNIT_W, UNIT_H, 182)
  local out = {}
  for i, h in ipairs(state.heroes) do out[h.id] = rects[i] end
  return out
end

function View.hand_rects(state)
  local rects = centered_row(#state.hand, CARD_W, CARD_H, 404)
  local out = {}
  for i, c in ipairs(state.hand) do out[c.uid] = rects[i] end
  return out
end

View.deck_pile_rect = { x = 20, y = 404, w = 64, h = CARD_H }
View.discard_pile_rect = { x = W - 84, y = 404, w = 64, h = CARD_H }

View.mode_buttons = {
  play = { x = W / 2 - 220, y = 560, w = 140, h = 32, label = "Jouer" },
  concentrate = { x = W / 2 - 70, y = 560, w = 180, h = 32, label = "Se concentrer (+1 énergie)" },
  cancel = { x = W / 2 + 120, y = 560, w = 100, h = 32, label = "Annuler" },
}
View.end_turn_button = { x = W / 2 - 150, y = 600, w = 140, h = 32, label = "Fin de tour" }
View.restart_button = { x = W / 2 + 10, y = 600, w = 180, h = 32, label = "Recommencer le combat" }
View.overlay_restart_button = { x = W / 2 - 70, y = H / 2 + 40, w = 140, h = 34, label = "Rejouer" }
View.mage_discard_all_button = { x = W / 2 + 150, y = 396, w = 110, h = 22, label = "tout défausser" }

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
-- "ABBR valeur" si la clé n'a pas d'icône dessinée.
local function status_badge(status_key, abbr, value, x, y, w, size, color)
  local drawn = Icons.draw_status(status_key, x + size * 0.55, y + size / 2, size * 0.42, color or Theme.status)
  if drawn then
    if value then text(tostring(value), x + size * 0.85, y + size * 0.18, w - size * 0.85, size * 0.72, color, "left") end
  else
    text(abbr .. (value and (" " .. value) or ""), x, y, w, size, color)
  end
end

--- Une ligne de badges de statut, chacun avec son icône dessinée + valeur (ou
-- son repli texte), répartis à parts égales sur la largeur donnée. `items` :
-- liste de { key = "defense", abbr = "DEF", value = 3 } (value optionnelle).
local function draw_badge_row(items, x, y, w, size, color)
  if #items == 0 then return end
  local slot = w / #items
  for i, it in ipairs(items) do
    status_badge(it.key, it.abbr, it.value, x + (i - 1) * slot, y, slot, size, color)
  end
end

local function bar(x, y, w, h, pct, color)
  set({ 0, 0, 0 }, 0.35)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  set(color)
  love.graphics.rectangle("fill", x, y, w * math.max(0, math.min(1, pct)), h, 4, 4)
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

-- ---------- unités (héros/ennemis) ----------

local function draw_hero(controller, h, r)
  local dead = h.hp <= 0
  local dx, dy, scale = unit_anim_transform(controller, h.id)
  love.graphics.push()
  love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-r.w / 2, -r.h / 2)

  local border = Theme.panel_light
  local pending = controller.state.pending
  local eligible_hero = pending and not pending.hero_id and not dead and h.energy >= Combat.required_cost(h, pending)
    and not h.has_acted and not (pending.def.requires_camouflage and not h.camoufle)
  local eligible_target = pending and pending.hero_id and pending.def.target == "ally" and not dead and h.id ~= pending.hero_id
  if eligible_hero then border = Theme.energy elseif eligible_target then border = Theme.heal end

  set(Theme.panel, dead and 0.5 or 1)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  set(border); love.graphics.setLineWidth((eligible_hero or eligible_target) and 3 or 1)
  love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

  set(Theme.text, dead and 0.45 or 1)
  draw_class_icon(h.class_id, h.icon, h.label, 0, 4, r.w, 20, Theme.text)
  text(h.name, 0, 24, r.w, 12)
  bar(8, 46, r.w - 16, 7, h.hp / h.max_hp, Theme.hp)
  text(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV — " .. h.energy .. " NRJ", 0, 55, r.w, 9, Theme.muted)

  local badges = {}
  if h.defense > 0 then badges[#badges + 1] = { key = "defense", abbr = "DEF", value = h.defense } end
  if (h.esquive or 0) > 0 then badges[#badges + 1] = { key = "esquive", abbr = "ESQ", value = h.esquive } end
  if h.camoufle then badges[#badges + 1] = { key = "camoufle", abbr = "CAM" } end
  if (h.puissance or 0) > 0 then badges[#badges + 1] = { key = "puissance", abbr = "PUI", value = h.puissance } end
  if (h.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = h.saignements } end
  draw_badge_row(badges, 0, 68, r.w, 16, Theme.status)

  local pip_row = ""
  for i = 1, math.max(h.energy, 6) do pip_row = pip_row .. (i <= h.energy and "*" or "-") end
  text(pip_row, 0, 82, r.w, 11, Theme.energy)

  if not dead and h.has_acted then text("a agi ce tour", 0, 98, r.w, 8, Theme.muted) end
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

local function enemy_telegraph_text(e)
  if e.hp <= 0 then return "Vaincu." end
  local move = e.next_move
  if not move then return "" end
  if move.kind == "dmg" or move.kind == "debuff" then
    local amount_text
    if move.kind == "dmg" then
      amount_text = move.amount .. " dégâts" .. (move.brut and " brut" or "")
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
    return move.name .. " — riposte si touché (" .. move.amount .. ")"
  end
  return ""
end

local function draw_enemy(controller, e, r)
  local dead = e.hp <= 0
  local dx, dy, scale = unit_anim_transform(controller, e.id)
  love.graphics.push()
  love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-r.w / 2, -r.h / 2)

  local pending = controller.state.pending
  local hero = pending and pending.hero_id and Combat.hero_by_id(controller.state, pending.hero_id)
  local awaiting_enemy_target = pending and pending.hero_id and not dead
    and (pending.def.target == "enemy" or (pending.def.target == "conditional" and hero and not Combat.enemy_targeting(controller.state, hero)))

  set(Theme.panel, dead and 0.5 or 1)
  love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
  set(awaiting_enemy_target and Theme.heal or Theme.panel_light)
  love.graphics.setLineWidth(awaiting_enemy_target and 3 or 1)
  love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

  set(Theme.text, dead and 0.45 or 1)
  draw_enemy_icon(e.template_id, e.icon, e.label, 0, 4, r.w, 20, Theme.text)
  text(e.name .. " Nv." .. e.level, 0, 24, r.w, 9)
  if not dead then
    bar(8, 46, r.w - 16, 7, e.hp / e.max_hp, Theme.hp)
    text(math.max(0, e.hp) .. "/" .. e.max_hp .. " PV", 0, 55, r.w, 9, Theme.muted)
    local badges = {}
    if e.defense > 0 then badges[#badges + 1] = { key = "defense", abbr = "DEF", value = e.defense } end
    if (e.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = e.saignements } end
    if (e.incapacite or 0) > 0 then badges[#badges + 1] = { key = "incapacite", abbr = "INC", value = e.incapacite } end
    if (e.vulnerabilite or 0) > 0 then badges[#badges + 1] = { key = "vulnerabilite", abbr = "VUL", value = e.vulnerabilite } end
    draw_badge_row(badges, 0, 68, r.w, 16, Theme.status)
  end
  text(enemy_telegraph_text(e), 0, 84, r.w, 8, Theme.accent)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

-- ---------- main ----------

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

  for _, c in ipairs(state.hand) do
    local r = rects[c.uid]
    local def = c.def
    local is_pending = state.pending and state.pending.uid == c.uid
    panel(r.x, r.y, r.w, r.h, Theme.panel_light)
    set(is_pending and Theme.accent or Theme.panel_light)
    love.graphics.setLineWidth(is_pending and 3 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)

    set(Theme.energy); love.graphics.circle("fill", r.x + 14, r.y + 12, 9)
    set(Theme.bg or { 0.05, 0.1, 0.1 })
    love.graphics.setFont(Fonts.get(11)); love.graphics.printf(tostring(def.cost), r.x + 4, r.y + 6, 20, "center")

    text(def.tier == "avance" and "Av." or "Dép.", r.x, r.y + 2, r.w - 4, 8, Theme.muted, "right")
    draw_class_icon(def.class_id, Heroes.class_icon[def.class_id], Heroes.class_label[def.class_id] or "?", r.x, r.y + 18, r.w, 16, Theme.text)
    text(def.name, r.x + 2, r.y + 42, r.w - 4, 9, Theme.text)
    text(Glossary.render_card_text(def.desc), r.x + 3, r.y + 60, r.w - 6, 8, Theme.muted)
  end
  return rects
end

local function draw_mode_buttons(controller)
  local pending = controller.state.pending
  if not pending or pending.mode then return end
  for key, b in pairs(View.mode_buttons) do
    set(key == "concentrate" and Theme.status or (key == "cancel" and Theme.muted or Theme.accent))
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    set(Theme.bg); love.graphics.setFont(Fonts.get(12))
    love.graphics.printf(b.label, b.x, b.y + 8, b.w, "center")
  end
end

local function draw_bottom_controls(controller)
  local b1, b2 = View.end_turn_button, View.restart_button
  set(Theme.accent); love.graphics.rectangle("fill", b1.x, b1.y, b1.w, b1.h, 8, 8)
  set(Theme.bg); love.graphics.setFont(Fonts.get(12)); love.graphics.printf(b1.label, b1.x, b1.y + 8, b1.w, "center")
  set(Theme.muted); love.graphics.rectangle("line", b2.x, b2.y, b2.w, b2.h, 8, 8)
  text(b2.label, b2.x, b2.y + 8, b2.w, 12, Theme.text)
end

local function hint_text(controller)
  local state = controller.state
  local pending = state.pending
  if state.mage_keep_pending then return "Fin de tour : clique la carte que le Mage garde, ou \"tout défausser\"." end
  if not pending then return "Clique une carte de ta main pour commencer." end
  if not pending.mode then return pending.def.name .. " sélectionnée — Jouer normalement, ou se concentrer ?" end
  if not pending.hero_id then return pending.def.name .. " — choisis quel aventurier." end
  return pending.def.name .. " — choisis la cible."
end

-- ---------- infobulle au survol (1s de délai, comme le prototype) ----------

local function tooltip_lines(controller)
  local h = controller.hover
  if h.kind == "hero" then
    local hero = Combat.hero_by_id(controller.state, h.target)
    if not hero then return nil end
    local p = Heroes.class_powers[hero.class_id]
    return hero.name, { p.pouvoir, p.transcendance }
  elseif h.kind == "enemy" then
    local e = Combat.enemy_by_id(controller.state, h.target)
    if not e then return nil end
    local template = Enemies.by_id(e.template_id)
    local lines = {}
    for _, m in ipairs(template.moves_info(e.level)) do
      lines[#lines + 1] = m.name .. " — " .. m.text
    end
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
      lines[#lines + 1] = label .. related .. (g.explain ~= "" and (" : " .. g.explain) or "")
    end
    return def.name .. " — mots-clés", lines
  end
  return nil
end

local function draw_tooltip(controller)
  if not controller:hover_ready() then return end
  local title, lines = tooltip_lines(controller)
  if not title then return end
  local mx, my = love.mouse.getPosition()
  local w = 240
  local h = 20 + 14 * #lines
  local x = math.min(mx + 14, W - w - 8)
  local y = math.max(8, my - h - 10)
  panel(x, y, w, h, Theme.panel_light)
  set(Theme.status); love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, 8, 8)
  text(title, x + 8, y + 6, w - 16, 10, Theme.status, "left")
  local ly = y + 20
  for _, line in ipairs(lines) do
    text(line, x + 8, ly, w - 16, 9, Theme.text, "left")
    ly = ly + 14
  end
end

function View.draw(controller)
  local state = controller.state
  set(Theme.bg); love.graphics.rectangle("fill", 0, 0, W, H)

  text("Hero Card Game — Run Infini", 0, 8, W, 20, Theme.text)
  text("Combat " .. state.run.combat_index .. " — Tour " .. state.turn, 0, 30, W, 11, Theme.muted)

  text("Ennemis", 20, 40, 200, 10, Theme.muted, "left")
  for _, e in ipairs(state.enemies) do draw_enemy(controller, e, View.enemy_rects(state)[e.id]) end

  text("Ta troupe", 20, 168, 200, 10, Theme.muted, "left")
  for _, h in ipairs(state.heroes) do draw_hero(controller, h, View.hero_rects(state)[h.id]) end

  -- journal (5 dernières lignes)
  panel(20, 322, W - 40, 70, { 0, 0, 0 })
  local log = state.log
  local n = #log
  local first = math.max(1, n - 5)
  local y = 326
  for i = first, n do
    local entry = log[i]
    local color = Theme.muted
    if entry.cls == "you" then color = Theme.energy
    elseif entry.cls == "foe" then color = Theme.hp
    elseif entry.cls == "sys" then color = Theme.accent
    elseif entry.cls == "heal" then color = Theme.heal
    elseif entry.cls == "power" then color = Theme.status end
    text(entry.text, 26, y, W - 52, 10, color, "left")
    y = y + 12
  end

  draw_hand(controller)
  draw_mode_buttons(controller)
  draw_bottom_controls(controller)
  text(hint_text(controller), 0, 632, W, 10, Theme.muted)

  if state.mage_keep_pending then
    panel(W / 2 - 300, 394, 600, 26, Theme.panel_light)
    text("Pouvoir de Classe du Mage : clique une carte à GARDER.", W / 2 - 300, 400, 480, 10, Theme.status)
    local b = View.mage_discard_all_button
    set(Theme.muted); love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    text(b.label, b.x, b.y + 5, b.w, 9, Theme.text)
  end

  if controller.screen == "defeat" then
    set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
    text("Défaite…", 0, H / 2 - 40, W, 26, Theme.text)
    text("Le run s'arrête après " .. combats_won_text(controller) .. " combat(s) remporté(s).", 0, H / 2, W, 12, Theme.muted)
    local b = View.overlay_restart_button
    set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    set(Theme.bg); text(b.label, b.x, b.y + 9, b.w, 12, Theme.bg)
  elseif controller.screen == "draft" and controller.draft_picks then
    set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, W, H)
    text("Victoire !", 0, 60, W, 24, Theme.text)
    text("Combat " .. (state.run.combat_index) .. " remporté ! Choisis une carte à ajouter à ton deck.", 0, 92, W, 12, Theme.muted)
    local rects = centered_row(#controller.draft_picks, 130, 190, 140, 24)
    for i, def in ipairs(controller.draft_picks) do
      local r = rects[i]
      if controller.draft_revealed[i] then
        panel(r.x, r.y, r.w, r.h, Theme.panel_light)
        set(Theme.energy); love.graphics.circle("fill", r.x + 16, r.y + 14, 10)
        set(Theme.bg); love.graphics.setFont(Fonts.get(12)); love.graphics.printf(tostring(def.cost), r.x + 6, r.y + 7, 20, "center")
        draw_class_icon(def.class_id, Heroes.class_icon[def.class_id], Heroes.class_label[def.class_id] or "?", r.x, r.y + 22, r.w, 18, Theme.text)
        text(def.name, r.x + 4, r.y + 50, r.w - 8, 11, Theme.text)
        text(Glossary.render_card_text(def.desc), r.x + 4, r.y + 72, r.w - 8, 9, Theme.muted)
      else
        panel(r.x, r.y, r.w, r.h, Theme.panel_light)
        text("?", r.x, r.y + r.h / 2 - 12, r.w, 26, Theme.muted)
      end
    end
  end

  if controller.screen == "playing" then draw_tooltip(controller) end

  love.graphics.setColor(1, 1, 1, 1)
end

function View.draft_rects(controller)
  if not controller.draft_picks then return {} end
  return centered_row(#controller.draft_picks, 130, 190, 140, 24)
end

return View
