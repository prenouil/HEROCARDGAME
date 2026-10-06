-- Écran "Félicitations" (2026-10-06, demande explicite -- "Après la défaite
-- du Boss, la carte / classe débloquée est mise en évidence. Message
-- 'Félicitations <carte> / <classe> est désormais disponible pour les
-- prochains runs.' avec l'image de la carte / classe") : affiché juste après
-- "bossVictory" quand la victoire vient de rapporter une récompense de quête
-- -- voir Controller:enter_quest_reward_screen/resolve_adventure_quest. Un
-- seul bouton "Continuer" (voir son commentaire côté contrôleur).
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Sprites = require("src.ui.sprites")
local Heroes = require("src.data.heroes")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  View.quest_reward_continue_button = { x = UI.W / 2 - 110, y = UI.H - 90, w = 220, h = 48, label = "Continuer" }

  -- Même technique que View.power_well_center_rect/draw_card_at (power_well.lua,
  -- "carte à une taille arbitraire") : simple push/translate/scale, pas besoin
  -- du détour par canvas (toujours pleine opacité, jamais de fondu ici).
  local CARD_SCALE = 1.5
  local function draw_reward_card(def, cx, cy)
    local w, h = UI.CARD_W * CARD_SCALE, UI.CARD_H * CARD_SCALE
    love.graphics.push()
    love.graphics.translate(cx - w / 2, cy - h / 2)
    love.graphics.scale(CARD_SCALE, CARD_SCALE)
    CardUI.draw_card_face(def, UI.CARD_W, UI.CARD_H, tostring(def.cost or 0), def.desc, Theme.muted, false, false, false, false)
    love.graphics.pop()
  end

  local function draw_quest_reward(controller)
    Background.draw(nil, UI.W, UI.H)
    local reward = controller.quest_reward
    if not reward then return end
    UI.text("Félicitations !", 0, 70, UI.W, 28, Theme.text)

    local name
    if reward.kind == "card" then
      name = reward.def.name
      draw_reward_card(reward.def, UI.W / 2, 280)
    else -- "companion" : plus de silhouette, le compagnon est enfin révélé.
      name = Heroes.class_name[reward.class_id] or reward.class_id
      love.graphics.setColor(1, 1, 1, 1)
      local sprite = Sprites.hero(reward.class_id)
      if sprite then Sprites.draw_centered(sprite, UI.W / 2, 280, 100) end
    end

    UI.text(name .. " est désormais disponible pour les prochains runs.", 0, 480, UI.W, 20, Theme.text, "center")
    UI.draw_menu_style_button(View.quest_reward_continue_button)
  end
  View.draw_quest_reward = draw_quest_reward
end
