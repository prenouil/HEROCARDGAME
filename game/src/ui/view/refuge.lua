-- Écran "Le Refuge" (2026-09-25, extrait de l'ex-monolithe view.lua -- voir
-- src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Combat = require("src.rules.combat")

return function(View, UI)
  -- Écran "Le Refuge" (2026-08-30, nouvel évènement -- "pas de choix, tous les
  -- persos vont regagner 30% de leurs PV") : même rangée de 4 que le feu de
  -- camp. "Se reposer", pas "Continuer" (2026-08-30, bug signalé -- "il faut
  -- quand même une action joueur, au moins 1 clic, pour déclencher le soin") :
  -- ce bouton déclenche maintenant le soin lui-même (voir Controller:
  -- choose_refuge_rest), pas de clic sur un aventurier individuel (toute
  -- l'équipe est soignée d'un coup, "pas de choix").
  -- 150x170 -> 170x240 (2026-09-22, portraits agrandis -- portrait_size 70->140,
  -- voir draw_refuge) : REFUGE_HERO_Y inchangé, View.refuge_rest_button suit
  -- automatiquement (formule relative à REFUGE_HERO_H), encore ~156px de marge
  -- avant le bas d'écran.
  local REFUGE_HERO_W, REFUGE_HERO_H = 170, 240
  local REFUGE_HERO_Y = 260 -- 240->260 (2026-08-31, passage 1280x720)

  function View.refuge_hero_rects(controller)
    local rects = UI.centered_row(#controller.state.heroes, REFUGE_HERO_W, REFUGE_HERO_H, REFUGE_HERO_Y)
    local out = {}
    for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
    return out
  end
  View.refuge_rest_button = {
    x = UI.W / 2 - 100, y = REFUGE_HERO_Y + REFUGE_HERO_H + 20, w = 200, h = 44, label = "Se reposer",
  }

  --- Écran "Le Refuge" (2026-08-30, nouvel évènement -- demande explicite :
  -- "pas de choix, tous les persos vont regagner 30% de leurs PV") : le soin
  -- n'a PLUS lieu à l'entrée sur l'écran (2026-08-30, bug signalé -- "il faut
  -- quand même une action joueur, au moins 1 clic" -- voir Controller:
  -- choose_refuge_rest) -- avant le clic sur "Se reposer", affiche donc une
  -- PRÉVISION (même formule que draw_campfire, PV réels pas encore modifiés) ;
  -- une fois `rf.resolved` vrai, affiche le montant RÉELLEMENT reçu
  -- (self.refuge.healed, posé par choose_refuge_rest). Aucun aventurier
  -- cliquable individuellement -- "pas de choix", toute l'équipe à la fois.
  local function draw_refuge(controller)
    local rf = controller.refuge
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.draw_camp_entrance(controller, "Le Refuge", 60, function()
    UI.text("Toute l'équipe va se reposer (30% des PV max).", 0, 92, UI.W, 12, Theme.muted)

    local rects = View.refuge_hero_rects(controller)
    for _, h in ipairs(controller.state.heroes) do
      local r = rects[h.id]
      local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
      UI.panel(r.x, r.y, r.w, r.h, Theme.panel_light)
      -- Couleur personnelle (2026-08-30, même correctif que draw_campfire) --
      -- voir son commentaire.
      UI.set(palette.border); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
      love.graphics.setLineWidth(1)
      -- 70->140 (2026-09-22, même correctif que draw_campfire) : tout ce qui
      -- suit décalé de +70.
      local portrait_size = 140
      UI.draw_class_icon(h.class_id, h.icon, h.label, r.x + (r.w - portrait_size) / 2, r.y + 14, portrait_size, portrait_size, Theme.text)
      UI.name_badge(h.name, r.x + 8, r.y + 160, r.w - 16, 12, palette.border, Theme.bg, 2, 3)
      -- Barre de PV normale, comme en combat (2026-08-30, même correctif que
      -- draw_campfire) : voir son commentaire.
      UI.hp_bar(r.x + 8, r.y + 176, r.w - 16, 16, h.hp / h.max_hp, (controller.hp_trail[h.id] or h.hp) / h.max_hp, Theme.hp)
      UI.text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", r.x, r.y + 176, r.w, 16, 10, Theme.text)
      local healed
      if rf.resolved then
        healed = rf.healed[h.id] or 0
      else
        healed = math.min(h.max_hp, h.hp + Combat.round(h.max_hp * 0.30)) - h.hp
      end
      UI.text("+" .. healed .. " PV", r.x, r.y + 198, r.w, 13, Theme.heal, "center")
    end

    local b = View.refuge_rest_button
    UI.set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    UI.set(Theme.bg); UI.text(b.label, b.x, b.y + 14, b.w, 14, Theme.bg, "center")
    end)
  end
  View.draw_refuge = draw_refuge
end
