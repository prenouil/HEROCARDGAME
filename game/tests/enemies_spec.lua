local Enemies = require("src.data.enemies")
local Rng = require("src.util.rng")

describe("Troll des Marais : Régénération jamais choisie à PV pleins (2026-08-24, bug signalé)", function()
  it("choisit toujours Coup de Massue quand hp >= max_hp, quel que soit le tirage", function()
    local troll = Enemies.by_id("troll")
    local e = { hp = 28, max_hp = 28, level = 1 }
    for seed = 1, 30 do
      local move = troll.choose_move(e, {}, Rng.new(seed))
      assert.equal("dmg", move.kind)
    end
  end)

  it("peut encore choisir Régénération quand hp < max_hp", function()
    local troll = Enemies.by_id("troll")
    local e = { hp = 1, max_hp = 28, level = 1 }
    local saw_heal = false
    for seed = 1, 50 do
      local move = troll.choose_move(e, {}, Rng.new(seed))
      if move.kind == "heal-self" then
        saw_heal = true
        break
      end
    end
    assert.is_true(saw_heal)
  end)
end)
