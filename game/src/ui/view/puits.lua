-- Écran "Le Puit de l'Oubli" (2026-10-03, nouvel évènement, demande
-- explicite) : simple écran d'intro -- texte explicatif + bouton "Choisir une
-- carte" qui ouvre la fenêtre PARTAGÉE view/power_well.lua (voir
-- Controller:puits_open_picker). Le choix/la destruction réelle de la carte
-- vivent entièrement dans cette fenêtre, jamais ici.
local Theme = require("src.ui.theme")

return function(View, UI)
  View.puits_choose_button = {
    x = UI.W / 2 - 120, y = UI.H / 2 + 10, w = 240, h = 44, label = "Choisir une carte",
  }

  local function draw_puits(controller)
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.draw_camp_entrance(controller, "Le Puit de l'Oubli", 60, function()
    UI.text("Choisis un pouvoir que tu désires oublier à jamais.", 0, UI.H / 2 - 30, UI.W, 14, Theme.muted)

    local b = View.puits_choose_button
    UI.set(Theme.accent); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
    UI.text(b.label, b.x, b.y + 15, b.w, 14, Theme.bg, "center")
    end)
  end
  View.draw_puits = draw_puits
end
