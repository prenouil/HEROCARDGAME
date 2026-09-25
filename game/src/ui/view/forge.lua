-- Écran "La Forge" (2026-09-25, extrait de l'ex-monolithe view.lua -- voir
-- src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Cards = require("src.data.cards")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  local FORGE_CARD_Y = 190
  local FORGE_ARROW_H = 40
  local FORGE_CARD_GAP = 30
  function View.forge_card_rects(controller)
    local f = controller.forge
    if not f then return {} end
    return UI.centered_row(#f.choices, UI.CARD_W, UI.CARD_H, FORGE_CARD_Y, FORGE_CARD_GAP)
  end

  --- Rects de la version AMÉLIORÉE, même colonnes que View.forge_card_rects,
  -- juste en dessous (2026-08-30, voir son commentaire ci-dessus).
  function View.forge_upgraded_card_rects(controller)
    local f = controller.forge
    if not f then return {} end
    return UI.centered_row(#f.choices, UI.CARD_W, UI.CARD_H, FORGE_CARD_Y + UI.CARD_H + FORGE_ARROW_H, FORGE_CARD_GAP)
  end

  View.forge_skip_button = {
    x = UI.W / 2 - 100, y = FORGE_CARD_Y + UI.CARD_H + FORGE_ARROW_H + UI.CARD_H + 30, w = 200, h = 44, label = "Passer",
  }

  --- Version améliorée à afficher pour `def` -- protège contre un double-appel
  -- (2026-08-28) : la carte CHOISIE a déjà son `instance.def` remplacé par
  -- Forge.apply_upgrade au moment où ce module la dessine encore une fois pour
  -- l'anim de fondu des autres (voir draw_forge) -- `Cards.upgraded_def` fait
  -- `assert(def.upgrade, ...)` et un def déjà amélioré (`is_upgraded`) ne porte
  -- plus ce champ, donc un second appel planterait -- on renvoie le def tel
  -- quel dans ce cas plutôt que de le repasser par Cards.upgraded_def.
  local function forge_preview_def(def)
    return def.is_upgraded and def or Cards.upgraded_def(def)
  end

  --- Flèche simple pointant vers le bas (2026-08-30, Forge -- "chacune des 4
  -- cartes au choix doit présenter sa version améliorée, reliée par une
  -- flèche") : relie la carte de base à sa version améliorée juste en dessous.
  local function draw_forge_arrow(cx, cy, alpha)
    UI.set(Theme.accent, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.line(cx, cy - 12, cx, cy + 6)
    love.graphics.polygon("fill", cx - 8, cy, cx + 8, cy, cx, cy + 14)
    love.graphics.setLineWidth(1)
  end

  --- Écran "La Forge" (2026-08-28, demande explicite -- remplace l'ancien
  -- panneau "Forge" de feuDeCamp) : jusqu'à 4 cartes en rangée, chacune DÉJÀ
  -- montrée dans sa version améliorée -- comparer base et améliorée pour 4
  -- cartes à la fois ne tient plus sur la largeur de l'écran ; seule "ce que
  -- la carte va devenir" reste affichée. Clic sur une carte : les 3 autres
  -- s'effacent en fondu (voir Controller:choose_forge_card/
  -- forge_upgrade_anim), celle choisie reste affichée seule, sans déplacement.
  local function draw_forge(controller)
    local f = controller.forge
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.draw_camp_entrance(controller, "La Forge", 60, function()
    if #f.choices == 0 then
      UI.text("Toutes vos cartes sont déjà améliorées.", 0, 92, UI.W, 12, Theme.muted)
      local b = View.forge_skip_button
      UI.set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
      UI.set(Theme.bg); UI.text(b.label, b.x, b.y + 14, b.w, 14, Theme.bg)
      return
    end

    UI.text("Choisis une carte à améliorer.", 0, 92, UI.W, 12, Theme.muted)
    local base_rects = View.forge_card_rects(controller)
    local up_rects = View.forge_upgraded_card_rects(controller)
    local anim = controller.forge_upgrade_anim
    for i, instance in ipairs(f.choices) do
      local br, ur = base_rects[i], up_rects[i]
      local preview_def = forge_preview_def(instance.def)
      if anim and anim.chosen_index ~= i then
        -- Choix déjà fait, mais PAS celui-ci (2026-08-30, étendu aux 2 cartes
        -- de la colonne) : base ET améliorée s'effacent ENSEMBLE, même fondu.
        local p = math.min(1, anim.t / (controller.forge_upgrade_anim_duration or 1))
        local alpha = 1 - p
        if alpha > 0 then
          CardUI.draw_faded_card(instance.def, br.x, br.y, alpha, Theme.muted, false)
          draw_forge_arrow(br.x + UI.CARD_W / 2, br.y + UI.CARD_H + FORGE_ARROW_H / 2, alpha)
          CardUI.draw_faded_card(preview_def, ur.x, ur.y, alpha, Theme.text, true)
        end
      elseif anim then
        -- La colonne CHOISIE (2026-08-30, demande explicite -- "la version non
        -- améliorée de la carte choisie descend et vient fade sur
        -- l'amélioration, comme une sorte de fusion, plus la carte améliorée
        -- réagit avec un VFX") : l'améliorée reste affichée EN CONTINU à SA
        -- position (`ur`), la base descend depuis SA position (`br`) en
        -- s'estompant, comme si elle "tombait dedans".
        local p = math.min(1, anim.t / (controller.forge_upgrade_anim_duration or 1))
        local ease = 1 - (1 - p) ^ 2 -- easeOutQuad : la base ralentit en approchant
        local base_y = br.y + (ur.y - br.y) * ease
        local base_alpha = 1 - p

        -- Pulsation + flash au moment de l'"impact" (2026-08-30) : fenêtre
        -- sur les 40% finaux de l'anim seulement.
        local impact_p = math.max(0, (p - 0.6) / 0.4)
        local impact_wave = math.sin(impact_p * math.pi) -- monte puis retombe, 0 aux 2 bouts
        local card_scale = 1 + 0.12 * impact_wave

        if impact_wave > 0 then
          UI.set(Theme.accent, impact_wave * 0.5)
          love.graphics.rectangle("fill", ur.x - 6, ur.y - 6, UI.CARD_W + 12, UI.CARD_H + 12, 14, 14)
        end

        love.graphics.push()
        love.graphics.translate(ur.x + UI.CARD_W / 2, ur.y + UI.CARD_H / 2)
        love.graphics.scale(card_scale, card_scale)
        love.graphics.translate(-UI.CARD_W / 2, -UI.CARD_H / 2)
        CardUI.draw_card_face(preview_def, UI.CARD_W, UI.CARD_H, preview_def.cost, preview_def.desc, Theme.text, true)
        love.graphics.pop()

        if base_alpha > 0 then
          CardUI.draw_faded_card(instance.def, br.x, base_y, base_alpha, Theme.muted, false)
        end
      else
        love.graphics.push()
        love.graphics.translate(br.x, br.y)
        CardUI.draw_card_face(instance.def, UI.CARD_W, UI.CARD_H, instance.def.cost, instance.def.desc, Theme.muted, false)
        love.graphics.pop()
        draw_forge_arrow(br.x + UI.CARD_W / 2, br.y + UI.CARD_H + FORGE_ARROW_H / 2, 1)
        love.graphics.push()
        love.graphics.translate(ur.x, ur.y)
        CardUI.draw_card_face(preview_def, UI.CARD_W, UI.CARD_H, preview_def.cost, preview_def.desc, Theme.text, true)
        love.graphics.pop()
      end
    end
    end)
  end
  View.draw_forge = draw_forge
end
