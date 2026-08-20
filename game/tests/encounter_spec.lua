local Encounter = require("src.rules.encounter")
local Rng = require("src.util.rng")

local function make_hero(id, overrides)
  local h = { id = id, name = id, hp = 20, max_hp = 20, camoufle = 0 }
  for k, v in pairs(overrides or {}) do h[k] = v end
  return h
end

-- Camouflé (2026-08-24, demande explicite -- jamais câblé jusqu'ici, voir
-- glossary.lua : "ne peut pas être ciblé par un ennemi").
describe("Encounter.pick_hero_target : immunité de ciblage Camouflé (2026-08-24)", function()
  it("exclut un héros Camouflé du pool tant qu'un autre héros vivant ne l'est pas", function()
    local h1 = make_hero("h1", { camoufle = 1 })
    local h2 = make_hero("h2")
    local state = { heroes = { h1, h2 } }
    local t = Encounter.pick_hero_target(state, "random", Rng.new(1))
    assert.equal(h2, t)
  end)

  it("retombe sur le pool complet si tous les héros vivants sont Camouflés (jamais aucune cible possible)", function()
    local h1 = make_hero("h1", { camoufle = 1 })
    local state = { heroes = { h1 } }
    local t = Encounter.pick_hero_target(state, "random", Rng.new(1))
    assert.equal(h1, t)
  end)

  it("le mode 'lowest-hp' respecte aussi l'exclusion des héros Camouflés", function()
    local h1 = make_hero("h1", { camoufle = 1, hp = 1 }) -- serait la cible évidente sans Camouflé
    local h2 = make_hero("h2", { hp = 15 })
    local state = { heroes = { h1, h2 } }
    local t = Encounter.pick_hero_target(state, "lowest-hp", Rng.new(1))
    assert.equal(h2, t)
  end)

  it("un héros mort n'entre jamais dans le pool, Camouflé ou non", function()
    local h1 = make_hero("h1", { hp = 0 })
    local h2 = make_hero("h2", { camoufle = 1 })
    local h3 = make_hero("h3")
    local state = { heroes = { h1, h2, h3 } }
    local t = Encounter.pick_hero_target(state, "random", Rng.new(1))
    assert.equal(h3, t)
  end)
end)

-- Discrétion (2026-08-24, demande explicite) : -10% de chance RELATIVE
-- d'être ciblé par point de Discrétion, en mode "random" seulement.
describe("Encounter.pick_hero_target : pondération par Discrétion (2026-08-24)", function()
  it("un candidat avec de la Discrétion est statistiquement moins souvent ciblé (-10%/point)", function()
    local low = make_hero("low") -- pas de Discrétion -> poids 1
    local high = make_hero("high", { discretion = 9 }) -- poids 0.1
    local state = { heroes = { low, high } }
    local rng = Rng.new(1)
    local counts = { low = 0, high = 0 }
    for _ = 1, 500 do
      local t = Encounter.pick_hero_target(state, "random", rng)
      counts[t.id] = counts[t.id] + 1
    end
    -- Poids 1 vs 0.1 -> ~90.9%/~9.1% attendu ; marge large pour la variance.
    assert.is_true(counts.low > counts.high * 5)
  end)

  it("deux candidats sans Discrétion restent ciblés à parts à peu près égales", function()
    local a = make_hero("a")
    local b = make_hero("b")
    local state = { heroes = { a, b } }
    local rng = Rng.new(1)
    local counts = { a = 0, b = 0 }
    for _ = 1, 500 do
      local t = Encounter.pick_hero_target(state, "random", rng)
      counts[t.id] = counts[t.id] + 1
    end
    assert.is_true(counts.a > 150 and counts.b > 150)
  end)
end)
