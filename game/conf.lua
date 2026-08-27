function love.conf(t)
  local SCALE = require("src.ui.layout_scale")
  t.title = "Hero Card Game — Run Infini (port LÖVE)"
  t.window.width = 960 * SCALE
  -- 660, pas 700 (2026-08-24) : DOIT rester synchronisé avec `local W, H = 960, 660`
  -- dans src/ui/view.lua -- ce fichier s'exécute trop tôt pour le require directement.
  t.window.height = 660 * SCALE
  t.window.resizable = false
  t.console = false
end
