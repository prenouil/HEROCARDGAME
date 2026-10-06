-- Difficulté des quêtes branchée sur le budget de rencontre réel (2026-10-07,
-- demande explicite -- "il faut les brancher sur le budget de rencontre réel") :
-- vérifie que Game.reset_run/start_next_combat/start_boss_combat décalent
-- bien la courbe de budget/le niveau du boss d'après `difficulty`, et que
-- l'omettre (tous les appelants historiques) reproduit EXACTEMENT le budget
-- d'avant cette fonctionnalité.

local Game = require("src.rules.game")
local Encounter = require("src.rules.encounter")

local function budget_from_log(state)
  for _, entry in ipairs(state.log) do
    local n = entry.text and entry.text:match("budget (%d+)")
    if n then return tonumber(n) end
  end
  return nil
end

describe("Game.reset_run difficulté (budget du 1er combat)", function()
  it("difficulté omise (nil) : budget identique à avant, Encounter.budget_for_combat(1)", function()
    local state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "paladin", "mage", "assassin" }, "bounded")
    assert.are.equal(Encounter.budget_for_combat(1), budget_from_log(state))
    assert.are.equal(1, state.run.difficulty)
  end)

  it("difficulté 3 : budget décalé de +2 combats sur la courbe (Encounter.budget_for_combat(3))", function()
    local state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "paladin", "mage", "assassin" }, "bounded", 3)
    assert.are.equal(Encounter.budget_for_combat(3), budget_from_log(state))
    assert.are.equal(3, state.run.difficulty)
  end)
end)

describe("Game.start_next_combat difficulté (budget des combats suivants)", function()
  it("difficulté 3 : combat 2 utilise Encounter.budget_for_combat(4) (2 + difficulté - 1)", function()
    local state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "paladin", "mage", "assassin" }, "bounded", 3)
    Game.start_next_combat(state)
    assert.are.equal(Encounter.budget_for_combat(4), budget_from_log(state))
  end)
end)

describe("Game.start_boss_combat difficulté (niveau du boss)", function()
  it("difficulté omise (nil) : niveau 1, comme avant", function()
    local state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "paladin", "mage", "assassin" }, "bounded")
    state.run.combat_index = 8 -- juste avant le boss
    Game.start_boss_combat(state)
    assert.are.equal(1, state.enemies[1].level)
  end)

  it("difficulté 4 : le boss (et ses sbires) sont niveau 4", function()
    local state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "paladin", "mage", "assassin" }, "bounded", 4)
    state.run.combat_index = 8
    Game.start_boss_combat(state)
    for _, e in ipairs(state.enemies) do
      assert.are.equal(4, e.level)
    end
  end)
end)
