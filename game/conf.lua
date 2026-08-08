function love.conf(t)
  local SCALE = require("src.ui.layout_scale")
  t.title = "Hero Card Game — Run Infini (port LÖVE)"
  t.window.width = 960 * SCALE
  t.window.height = 700 * SCALE
  t.window.resizable = false
  t.console = false
end
