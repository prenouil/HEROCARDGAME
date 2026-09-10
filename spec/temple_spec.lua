-- Le Temple : bénédictions/malédictions (game/src/rules/temple.lua) --
-- 2026-09-10, suite de la couverture Busted.

local Temple = require("src.rules.temple")
local Rng = require("src.util.rng")

describe("Temple.by_id / Temple.by_type", function()
  it("by_id retrouve un effet connu, nil sinon", function()
    assert.are.equal("La Guérisseuse", Temple.by_id("guerisseuse").name)
    assert.is_nil(Temple.by_id("inexistant"))
  end)

  it("8 bénédictions et 8 malédictions, jamais mélangées", function()
    local blessings, curses = Temple.by_type("blessing"), Temple.by_type("curse")
    assert.are.equal(8, #blessings)
    assert.are.equal(8, #curses)
    for _, e in ipairs(blessings) do assert.are.equal("blessing", e.type) end
    for _, e in ipairs(curses) do assert.are.equal("curse", e.type) end
  end)
end)

describe("Temple.eligible_heroes", function()
  it("exclut les héros morts et ceux qui portent déjà CE type d'effet", function()
    local dead = { hp = 0 }
    local already_blessed = { hp = 10, blessing = "guerisseuse" }
    local free = { hp = 10 }
    local state = { heroes = { dead, already_blessed, free } }
    local eligible = Temple.eligible_heroes(state, "blessing")
    assert.are.equal(1, #eligible)
    assert.are.equal(free, eligible[1])
  end)

  it("bénédiction et malédiction sont INDÉPENDANTES : porter l'une n'exclut pas l'autre", function()
    local cursed = { hp = 10, curse = "maudit" }
    local state = { heroes = { cursed } }
    assert.are.equal(1, #Temple.eligible_heroes(state, "blessing"))
    assert.are.equal(0, #Temple.eligible_heroes(state, "curse"))
  end)
end)

describe("Temple.roll_type / Temple.any_type_viable", function()
  it("si un seul type est viable, c'est toujours lui qui sort", function()
    -- Tous les héros ont déjà une bénédiction : seul "curse" reste viable.
    local state = { heroes = { { hp = 10, blessing = "guerisseuse" } } }
    assert.are.equal("curse", Temple.roll_type(state, Rng.new(1)))
    assert.is_true(Temple.any_type_viable(state))
  end)

  it("renvoie nil (et any_type_viable=false) si personne n'est éligible à rien", function()
    local state = { heroes = { { hp = 10, blessing = "guerisseuse", curse = "maudit" } } }
    assert.is_nil(Temple.roll_type(state, Rng.new(1)))
    assert.is_false(Temple.any_type_viable(state))
  end)

  it("les deux viables : le tirage ne renvoie jamais autre chose que blessing/curse", function()
    local state = { heroes = { { hp = 10 } } }
    local t = Temple.roll_type(state, Rng.new(5))
    assert.is_true(t == "blessing" or t == "curse")
  end)
end)

describe("Temple.pick_choices", function()
  it("tire jusqu'à CHOICE_COUNT effets DISTINCTS du bon type, sans jamais de doublon", function()
    local chosen = Temple.pick_choices("curse", Rng.new(1))
    assert.are.equal(Temple.CHOICE_COUNT, #chosen)
    local seen = {}
    for _, e in ipairs(chosen) do
      assert.are.equal("curse", e.type)
      assert.is_nil(seen[e.id])
      seen[e.id] = true
    end
  end)
end)

describe("Temple.assign", function()
  it("pose l'id de l'effet sur le champ correspondant à son type, sans toucher l'autre", function()
    local hero = {}
    Temple.assign(hero, Temple.by_id("guerisseuse"))
    assert.are.equal("guerisseuse", hero.blessing)
    assert.is_nil(hero.curse)

    Temple.assign(hero, Temple.by_id("maudit"))
    assert.are.equal("maudit", hero.curse)
    assert.are.equal("guerisseuse", hero.blessing) -- inchangée, les 2 coexistent
  end)
end)
