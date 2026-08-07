-- Palette reprise des custom properties CSS du prototype (proto-cartes-completes),
-- convertie en RGB 0..1 pour love.graphics.setColor.

local function hex(h)
  h = h:gsub("#", "")
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local Theme = {
  bg = hex("1b1420"),
  panel = hex("2a1f33"),
  panel_light = hex("3a2a48"),
  accent = hex("e8b93f"),
  hp = hex("d9455f"),
  heal = hex("4caf7d"),
  energy = hex("3fb6e8"),
  text = hex("f1e9f7"),
  muted = hex("a996b3"),
  def = hex("7f9ccf"),
  status = hex("c47fe8"),
  black = { 0, 0, 0 },
  white = { 1, 1, 1 },
}

function Theme.with_alpha(c, a)
  return { c[1], c[2], c[3], a }
end

return Theme
