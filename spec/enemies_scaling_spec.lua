-- Mise à l'échelle des ennemis par niveau (game/src/data/enemies.lua) --
-- 2026-09-10, dernier lot de cette manche Busted : la formule dont dépend
-- TOUT le système de budget/difficulté (Encounter.budget_for_combat compare
-- son résultat à Enemies.cost_at_level, voir encounter.lua) -- une régression
-- ici déséquilibrerait le jeu en silence, sans jamais planter.

local Enemies = require("src.data.enemies")
local Rng = require("src.util.rng")

describe("Enemies.value_range", function()
  it("±VALUE_VARIANCE (20%) autour de la valeur de base, arrondi", function()
    local lo, hi = Enemies.value_range(100)
    assert.are.equal(80, lo)
    assert.are.equal(120, hi)
  end)
end)

describe("Enemies.roll_value", function()
  it("tire toujours dans l'intervalle ±20%, jamais en dehors, quel que soit le seed", function()
    for seed = 1, 30 do
      local v = Enemies.roll_value(50, Rng.new(seed))
      assert.is_true(v >= 40 and v <= 60)
    end
  end)
end)

describe("Enemies.scaled_base", function()
  it("niveau 1 : valeur de base inchangée", function()
    assert.are.equal(10, Enemies.scaled_base(10, 1))
  end)

  it("+LEVEL_GROWTH (20%) par niveau au-dessus de 1, linéaire", function()
    assert.are.equal(12, Enemies.scaled_base(10, 2)) -- +20%
    assert.are.equal(14, Enemies.scaled_base(10, 3)) -- +40%
  end)
end)

describe("Enemies.roll_scaled", function()
  it("tire dans l'intervalle ±20% de la valeur DÉJÀ mise à l'échelle pour ce niveau", function()
    for seed = 1, 30 do
      local v = Enemies.roll_scaled(10, 3, Rng.new(seed)) -- scaled_base(10,3) = 14
      assert.is_true(v >= Enemies.round(14 * 0.8) and v <= Enemies.round(14 * 1.2))
    end
  end)
end)

describe("Enemies.cost_at_level", function()
  it("coût mis à l'échelle comme n'importe quelle autre valeur de base, arrondi", function()
    local template = { cost = 8 }
    assert.are.equal(8, Enemies.cost_at_level(template, 1))
    assert.are.equal(Enemies.round(8 * 1.2), Enemies.cost_at_level(template, 2))
  end)

  it("croissance monotone : jamais moins cher à un niveau supérieur", function()
    local template = { cost = 8 }
    local prev = Enemies.cost_at_level(template, 1)
    for level = 2, 10 do
      local cur = Enemies.cost_at_level(template, level)
      assert.is_true(cur >= prev)
      prev = cur
    end
  end)
end)

describe("Enemies.by_id", function()
  it("retrouve un template connu, nil sinon", function()
    assert.are.equal("Squelette Archer", Enemies.by_id("squelette").name)
    assert.is_nil(Enemies.by_id("inexistant"))
  end)
end)
