-- Le Temple (2026-08-29, refonte complète) : Temple.roll_type/pick_choices/
-- eligible_heroes/assign -- la mécanique de sélection dans Controller/view.lua
-- n'est pas testée ici (dépend de LÖVE), seule la couche pure src/rules l'est.

local Temple = require("src.rules.temple")
local Rng = require("src.util.rng")

local function make_hero(id, overrides)
  local h = { id = id, name = id, hp = 20, max_hp = 20 }
  for k, v in pairs(overrides or {}) do h[k] = v end
  return h
end

describe("Temple.effects : contenu déclaratif (2026-08-29, liste fournie)", function()
  it("contient 8 bénédictions et 8 malédictions", function()
    local counts = { blessing = 0, curse = 0 }
    for _, e in ipairs(Temple.effects) do counts[e.type] = counts[e.type] + 1 end
    assert.equal(8, counts.blessing)
    assert.equal(8, counts.curse)
  end)

  it("chaque effet a un id unique", function()
    local seen = {}
    for _, e in ipairs(Temple.effects) do
      assert.is_nil(seen[e.id], "id dupliqué : " .. tostring(e.id))
      seen[e.id] = true
    end
  end)
end)

describe("Temple.eligible_heroes : bénédiction et malédiction sont 2 champs INDÉPENDANTS", function()
  it("un héros déjà béni reste éligible aux malédictions, et vice-versa", function()
    local state = { heroes = {
      make_hero("h1", { blessing = "guerisseuse" }),
      make_hero("h2", { curse = "maudit" }),
    } }
    local blessing_eligible = Temple.eligible_heroes(state, "blessing")
    local curse_eligible = Temple.eligible_heroes(state, "curse")
    assert.equal(1, #blessing_eligible) -- h2 seulement (h1 déjà béni)
    assert.equal("h2", blessing_eligible[1].id)
    assert.equal(1, #curse_eligible) -- h1 seulement (h2 déjà maudit)
    assert.equal("h1", curse_eligible[1].id)
  end)

  it("exclut les héros morts, quel que soit le type", function()
    local state = { heroes = { make_hero("h1", { hp = 0 }) } }
    assert.equal(0, #Temple.eligible_heroes(state, "blessing"))
    assert.equal(0, #Temple.eligible_heroes(state, "curse"))
  end)
end)

describe("Temple.roll_type : ne tire jamais un type sans effet/aventurier éligible (2026-08-29)", function()
  it("renvoie nil si tous les héros ont déjà les deux types", function()
    local state = { heroes = {
      make_hero("h1", { blessing = "guerisseuse", curse = "maudit" }),
    } }
    assert.is_nil(Temple.roll_type(state, Rng.new(1)))
  end)

  it("renvoie forcément 'curse' si seule la malédiction a un héros éligible", function()
    local state = { heroes = {
      make_hero("h1", { blessing = "guerisseuse" }), -- éligible curse seulement
    } }
    for seed = 1, 10 do
      assert.equal("curse", Temple.roll_type(state, Rng.new(seed)))
    end
  end)

  it("tire les deux types au fil du temps quand les deux sont viables", function()
    local state = { heroes = { make_hero("h1") } }
    local seen = { blessing = false, curse = false }
    for seed = 1, 30 do
      seen[Temple.roll_type(state, Rng.new(seed))] = true
    end
    assert.is_true(seen.blessing)
    assert.is_true(seen.curse)
  end)
end)

describe("Temple.pick_choices : jusqu'à CHOICE_COUNT effets distincts, sans remise", function()
  it("tire 3 effets distincts du bon type", function()
    local chosen = Temple.pick_choices("blessing", Rng.new(1))
    assert.equal(3, #chosen)
    local seen = {}
    for _, e in ipairs(chosen) do
      assert.equal("blessing", e.type)
      assert.is_nil(seen[e.id])
      seen[e.id] = true
    end
  end)
end)

describe("Temple.assign : pose sur le bon champ selon le type", function()
  it("une bénédiction va sur hero.blessing, une malédiction sur hero.curse", function()
    local hero = make_hero("h1")
    Temple.assign(hero, Temple.by_id("guerisseuse"))
    assert.equal("guerisseuse", hero.blessing)
    assert.is_nil(hero.curse)
    Temple.assign(hero, Temple.by_id("maudit"))
    assert.equal("maudit", hero.curse)
    assert.equal("guerisseuse", hero.blessing) -- inchangée, coexistent
  end)
end)
