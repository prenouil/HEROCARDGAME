-- Écran "Choisis un boss" (2026-09-25, extrait de l'ex-monolithe view.lua --
-- voir src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Enemies = require("src.data.enemies")
local Encounter = require("src.rules.encounter")

return function(View, UI)
  -- Écran "Choisis un boss" (2026-09-02, demande explicite -- "Tester un boss"
  -- passe désormais par la sélection d'équipe normale, PUIS ce choix) : une
  -- carte par boss jouable (Encounter.BOSS_BY_BIOME, toujours 4 -- un par
  -- biome) -- voir Controller:select_boss/adjust_boss_level/launch_boss_fight.
  -- Toutes les constantes/locaux de ce bloc restent DANS le `do...end`
  -- d'origine (limite des 200 locaux par chunk, aujourd'hui non pertinente
  -- puisque ce fichier a son propre budget) : gardé tel quel par cohérence.
  View.boss_select_buttons = {}
  View.BOSS_SELECT_PORTRAIT = 120
  do
    local card_w, card_h, card_gap, y0 = 260, 220, 20, 170
    local portrait = View.BOSS_SELECT_PORTRAIT
    local total_w = 4 * card_w + 3 * card_gap
    local x0 = UI.W / 2 - total_w / 2
    for i, biome in ipairs(Enemies.ALL_BIOMES) do
      local boss = Enemies.by_id(Encounter.BOSS_BY_BIOME[biome])
      local cx, cy = x0 + (i - 1) * (card_w + card_gap), y0
      View.boss_select_buttons[i] = {
        biome = biome, boss_id = boss.id, boss_icon = boss.icon, boss_label = boss.label,
        name = boss.name, biome_name = Enemies.BIOME_NAMES[biome],
        x = cx, y = cy, w = card_w, h = card_h,
        portrait_x = cx + (card_w - portrait) / 2, portrait_y = cy + 18, portrait_size = portrait,
      }
    end
    local last = View.boss_select_buttons[#View.boss_select_buttons]
    local row_y = last.y + last.h + 34
    View.boss_select_combat_button = { x = last.x + last.w - 200, y = row_y, w = 200, h = 60, label = "Combattre" }
    View.boss_select_back_button = { x = x0, y = row_y, w = 180, h = 60, label = "Retour" }
    View.boss_select_level_text_rect = { x = UI.W / 2 - 70, y = row_y, w = 140, h = 24 }
    View.boss_select_level_minus = { x = UI.W / 2 - 60, y = row_y + 28, w = 40, h = 32 }
    View.boss_select_level_plus = { x = UI.W / 2 + 20, y = row_y + 28, w = 40, h = 32 }
  end

  -- Petit bouton carré "-"/"+" (2026-09-02) : même style que
  -- draw_menu_style_button mais sans label multi-mot, juste le symbole --
  -- factorisé pour les 2 boutons de chaque carte boss ci-dessous.
  local function draw_boss_step_button(r, symbol)
    UI.set(Theme.panel_light)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    UI.set(Theme.muted); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setLineWidth(1)
    UI.text(symbol, r.x, r.y + r.h / 2 - 8, r.w, 16, Theme.text, "center")
  end

  local function draw_boss_select(controller)
    Background.draw(nil, UI.W, UI.H)
    UI.text("Choisis un boss", 0, 70, UI.W, 24, Theme.text)
    UI.text("Clique un boss pour le sélectionner, règle le niveau (1-9), puis Combattre.", 0, 102, UI.W, 12, Theme.muted)
    local bs = controller.boss_select
    local level = bs and (bs.level or 1) or 1
    for _, b in ipairs(View.boss_select_buttons) do
      local selected = bs and bs.selected_biome == b.biome
      UI.set(selected and Theme.heal or Theme.panel_light)
      love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 12, 12)
      UI.set(selected and Theme.accent or Theme.muted); love.graphics.setLineWidth(selected and 3 or 2)
      love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 12, 12)
      love.graphics.setLineWidth(1)

      UI.draw_enemy_icon(b.boss_id, b.boss_icon, b.boss_label, b.portrait_x, b.portrait_y, b.portrait_size, b.portrait_size, Theme.text)
      local name_y = b.portrait_y + b.portrait_size + 10
      UI.text(b.name, b.x, name_y, b.w, 14, selected and Theme.bg or Theme.text, "center")
      UI.text(b.biome_name, b.x, name_y + 18, b.w, 11, selected and Theme.bg or Theme.muted, "center")

      -- "?" d'infobulle (2026-09-02, demande explicite) : coin bas-droit de la
      -- carte, valeurs de l'infobulle dépendantes du niveau réglé (voir
      -- tooltip_lines, h.kind == "boss_preview").
      love.graphics.push()
      love.graphics.translate(b.x, b.y)
      UI.draw_tooltip_hint(b.w, b.h, selected and Theme.bg or Theme.text)
      love.graphics.pop()
    end

    -- Réglage de niveau UNIQUE (2026-09-02, demande explicite) : s'applique au
    -- boss qui sera lancé, quel qu'il soit -- voir Controller:adjust_boss_level.
    local lt = View.boss_select_level_text_rect
    UI.text("Niveau " .. level, lt.x, lt.y, lt.w, 20, Theme.text, "center")
    draw_boss_step_button(View.boss_select_level_minus, "-")
    draw_boss_step_button(View.boss_select_level_plus, "+")

    local ready = bs and bs.selected_biome ~= nil
    local cb = View.boss_select_combat_button
    if ready then
      local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
      UI.set(Theme.accent, 0.35 + 0.35 * pulse)
      love.graphics.rectangle("fill", cb.x - 5, cb.y - 5, cb.w + 10, cb.h + 10, 12, 12)
    end
    UI.set(ready and Theme.heal or Theme.panel_light)
    love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 10, 10)
    UI.set(ready and Theme.accent or Theme.muted); love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 10, 10)
    love.graphics.setLineWidth(1)
    UI.text(cb.label, cb.x, cb.y + cb.h / 2 - 12, cb.w, 24, ready and Theme.bg or Theme.muted, "center")

    UI.draw_menu_style_button(View.boss_select_back_button)
  end
  View.draw_boss_select = draw_boss_select
end
