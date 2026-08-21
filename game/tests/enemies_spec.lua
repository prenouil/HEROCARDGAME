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

-- Nécromancien Novice : 2 attaques (2026-08-21, demande explicite -- avant,
-- Malédiction inconditionnelle) -- Malédiction ~2/3 du temps, Toucher
-- Nécrotique (dégâts) ~1/3 du temps. La règle tacite "force Toucher
-- Nécrotique si aucun ennemi ne fait de dégâts ce tour" vit dans
-- Encounter.roll_telegraphs, testée séparément dans encounter_spec.lua --
-- choose_move seul, seed par seed, ne la connaît pas.
describe("Nécromancien Novice : 2 attaques, Malédiction ~2/3, Toucher Nécrotique ~1/3 (2026-08-21)", function()
  it("les deux natures de coup apparaissent sur un échantillon de seeds", function()
    local necro = Enemies.by_id("necromancien")
    local e = { hp = 10, max_hp = 10, level = 1 }
    local counts = { dmg = 0, debuff = 0 }
    for seed = 1, 60 do
      local move = necro.choose_move(e, {}, Rng.new(seed))
      counts[move.kind] = counts[move.kind] + 1
    end
    assert.is_true(counts.dmg > 0)
    assert.is_true(counts.debuff > 0)
    -- Répartition ~1/3 vs ~2/3 sur 60 tirages : marge large pour la variance.
    assert.is_true(counts.dmg < counts.debuff)
  end)

  it("Toucher Nécrotique inflige 2-4 dégâts au niveau 1", function()
    local necro = Enemies.by_id("necromancien")
    local e = { hp = 10, max_hp = 10, level = 1 }
    for seed = 1, 60 do
      local move = necro.choose_move(e, {}, Rng.new(seed))
      if move.kind == "dmg" then
        assert.is_true(move.amount >= 2 and move.amount <= 4)
      end
    end
  end)
end)
