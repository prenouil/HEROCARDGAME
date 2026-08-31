function love.conf(t)
  local SCALE = require("src.ui.layout_scale")
  local SIZE = require("src.ui.logical_size")
  t.title = "Hero Card Game — Run Infini (port LÖVE)"
  t.window.width = SIZE.W * SCALE
  t.window.height = SIZE.H * SCALE
  t.window.resizable = false
  t.console = false
end
