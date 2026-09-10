-- Génération de rencontre (game/src/rules/encounter.lua) -- 2026-09-10, suite
-- de la couverture Busted : croissance du budget, tirage d'ennemis normaux
-- (jamais de boss_only mélangé), promotion Élite, rencontres de boss fixes
-- par biome.

local Encounter = require("src.rules.encounter")
local Enemies = require("src.data.enemies")
local Rng = require("src.util.rng")

describe("Encounter.budget_for_combat", function()
  it("combat 1 = BUDGET_BASE exactement", function()
    assert.are.equal(Encounter.BUDGET_BASE, Encounter.budget_for_combat(1))
  end)

  it("croît de façon exponentielle (BUDGET_GROWTH), toujours strictement croissant", function()
    local b1, b2, b10 = Encounter.budget_for_combat(1), Encounter.budget_for_combat(2), Encounter.budget_for_combat(10)
    assert.are.equal(Enemies.round(Encounter.BUDGET_BASE * (1 + Encounter.BUDGET_GROWTH)), b2)
    assert.is_true(b2 > b1)
    assert.is_true(b10 > b2)
  end)
end)

describe("Encounter.generate_encounter", function()
  it("tire entre 1 et MAX_ENEMIES_PER_COMBAT ennemis, jamais un template boss_only", function()
    local instances = Encounter.generate_encounter(Encounter.budget_for_combat(1), Rng.new(1), nil)
    assert.is_true(#instances >= 1 and #instances <= Encounter.MAX_ENEMIES_PER_COMBAT)
    for _, inst in ipairs(instances) do
      assert.is_falsy(inst.template.boss_only)
      assert.is_true(inst.level >= 1)
    end
  end)

  it("avec un biome donné, ne tire que des templates de ce biome", function()
    local instances = Encounter.generate_encounter(Encounter.budget_for_combat(4), Rng.new(7), "foret")
    assert.is_true(#instances >= 1)
    for _, inst in ipairs(instances) do
      assert.are.equal("foret", inst.template.biome)
    end
  end)

  it("même seed => même rencontre (reproductibilité)", function()
    local a = Encounter.generate_encounter(50, Rng.new(99), nil)
    local b = Encounter.generate_encounter(50, Rng.new(99), nil)
    assert.are.equal(#a, #b)
    for i = 1, #a do
      assert.are.equal(a[i].template.id, b[i].template.id)
      assert.are.equal(a[i].level, b[i].level)
    end
  end)
end)

describe("Encounter.instantiate_enemy", function()
  it("PV pleins, niveau posé, tous les statuts à 0, jamais Élite par défaut", function()
    local template = Enemies.by_id("squelette")
    local e = Encounter.instantiate_enemy(template, 3, function() return 42 end, Rng.new(1))
    assert.are.equal(e.max_hp, e.hp)
    assert.are.equal(3, e.level)
    assert.are.equal(0, e.defense)
    assert.are.equal(0, e.saignements)
    assert.are.equal(0, e.brulure)
    assert.is_false(e.elite)
    assert.are.equal("squelette-42", e.id)
  end)
end)

describe("Encounter.promote_to_elite", function()
  it("PV/bouclier ×1.6, marque Élite, ne touche JAMAIS le niveau (l'Élite ne coûte pas plus cher)", function()
    local template = Enemies.by_id("squelette")
    local e = Encounter.instantiate_enemy(template, 2, function() return 1 end, Rng.new(1))
    local hp_before, level_before = e.max_hp, e.level
    Encounter.promote_to_elite(e)
    assert.is_true(e.elite)
    assert.are.equal(Enemies.round(hp_before * 1.6), e.max_hp)
    assert.are.equal(e.max_hp, e.hp) -- remonté aux nouveaux PV max
    assert.are.equal(level_before, e.level)
  end)
end)

-- `Encounter.boss_encounter` (et ses 4 variantes par biome) renvoient
-- directement des instances déjà créées par `Encounter.instantiate_enemy`
-- (`.template_id`/`.level`), PAS des paires `{template=, level=}` comme
-- `Encounter.generate_encounter` -- les 2 fonctions ont des contrats de
-- retour différents, jamais confondus ici.
describe("Encounter.boss_encounter", function()
  it("choisit le bon boss pour chaque biome, avec le niveau demandé appliqué uniformément", function()
    for biome, boss_id in pairs(Encounter.BOSS_BY_BIOME) do
      local instances = Encounter.boss_encounter(function() return 1 end, Rng.new(1), biome, 5)
      local found_boss = false
      for _, inst in ipairs(instances) do
        assert.are.equal(5, inst.level) -- le boss ET ses sbires, uniformément
        if inst.template_id == boss_id then found_boss = true end
      end
      assert.is_true(found_boss)
    end
  end)

  it("niveau par défaut = 1 si omis", function()
    local instances = Encounter.boss_encounter(function() return 1 end, Rng.new(1), "canyon", nil)
    assert.are.equal(1, instances[1].level)
  end)

  it("sans biome : tire un des 4 boss au hasard, jamais un template hors de cette liste", function()
    local valid_ids = {}
    for _, id in pairs(Encounter.BOSS_BY_BIOME) do valid_ids[id] = true end
    local instances = Encounter.boss_encounter(function() return 1 end, Rng.new(3), nil, 1)
    local has_a_boss = false
    for _, inst in ipairs(instances) do
      if valid_ids[inst.template_id] then has_a_boss = true end
    end
    assert.is_true(has_a_boss)
  end)

  it("Homme Arbre : 1 boss + 4 Pousses d'Arbre", function()
    local instances = Encounter.boss_encounter(function() return 1 end, Rng.new(1), "foret", 1)
    assert.are.equal(5, #instances)
    local counts = {}
    for _, inst in ipairs(instances) do counts[inst.template_id] = (counts[inst.template_id] or 0) + 1 end
    assert.are.equal(1, counts["homme-arbre"])
    assert.are.equal(4, counts["pousse"])
  end)

  it("Aigle Géant et Élémentaire de Feu : seuls, sans sbires", function()
    assert.are.equal(1, #Encounter.boss_encounter(function() return 1 end, Rng.new(1), "canyon", 1))
    assert.are.equal(1, #Encounter.boss_encounter(function() return 1 end, Rng.new(1), "volcan", 1))
  end)
end)

describe("Encounter.pick_hero_target", function()
  it("mode lowest-hp : cible toujours le héros vivant avec le moins de PV", function()
    local state = { heroes = {
      { id = "a", hp = 10 }, { id = "b", hp = 3 }, { id = "c", hp = 0 },
    } }
    local t = Encounter.pick_hero_target(state, "lowest-hp", Rng.new(1))
    assert.are.equal("b", t.id)
  end)

  it("un héros Camouflé n'est jamais ciblé tant qu'un allié visible est vivant", function()
    local state = { heroes = { { id = "cache", hp = 10, camoufle = 1 }, { id = "visible", hp = 10 } } }
    for seed = 1, 20 do
      local t = Encounter.pick_hero_target(state, "random", Rng.new(seed))
      assert.are.equal("visible", t.id)
    end
  end)

  it("si TOUT le monde est Camouflé, retombe sur le pool complet plutôt que nil", function()
    local state = { heroes = { { id = "a", hp = 10, camoufle = 1 } } }
    assert.are.equal("a", Encounter.pick_hero_target(state, "lowest-hp", Rng.new(1)).id)
  end)

  it("Discrétion réduit le poids relatif, jamais sous 0 (mode random)", function()
    -- Un héros à 10 Discrétion a un poids nul (1 - 0.1*10 = 0) : jamais choisi
    -- tant qu'un autre a le moindre poids positif.
    local state = { heroes = { { id = "furtif", hp = 10, discretion = 10 }, { id = "visible", hp = 10 } } }
    for seed = 1, 20 do
      local t = Encounter.pick_hero_target(state, "random", Rng.new(seed))
      assert.are.equal("visible", t.id)
    end
  end)

  it("nil si personne n'est vivant", function()
    assert.is_nil(Encounter.pick_hero_target({ heroes = { { id = "a", hp = 0 } } }, "lowest-hp", Rng.new(1)))
  end)
end)
