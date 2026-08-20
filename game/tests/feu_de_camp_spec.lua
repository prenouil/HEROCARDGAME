-- Écran "feuDeCamp" (Run Infini, entre le draft de fin de combat et le combat
-- suivant, 2026-08-10). Ces specs pilotent src/rules/feu_de_camp.lua directement
-- (pas Controller) -- même principe que game_spec.lua/combat_spec.lua.

local FeuDeCamp = require("src.rules.feu_de_camp")
local Cards = require("src.data.cards")
local Rng = require("src.util.rng")

local function make_hero(id, overrides)
  local h = { id = id, name = id, class_id = "guerrier", hp = 20, max_hp = 20 }
  for k, v in pairs(overrides or {}) do h[k] = v end
  return h
end

local function make_state(heroes, deck, hand, discard)
  return { heroes = heroes or {}, deck = deck or {}, hand = hand or {}, discard = discard or {} }
end

local function card_instance(uid, code)
  return { uid = uid, def = Cards.by_code(code) }
end

describe("FeuDeCamp.most_wounded_hero", function()
  it("retourne nil quand personne n'est blessé", function()
    local state = make_state({ make_hero("h1"), make_hero("h2") })
    assert.is_nil(FeuDeCamp.most_wounded_hero(state, Rng.new(1)))
  end)

  it("retourne le héros le plus blessé en pourcentage de PV", function()
    local h1 = make_hero("h1", { hp = 10, max_hp = 20 }) -- 50% blessé
    local h2 = make_hero("h2", { hp = 18, max_hp = 20 }) -- 10% blessé
    local state = make_state({ h1, h2 })
    assert.equal(h1, FeuDeCamp.most_wounded_hero(state, Rng.new(1)))
  end)

  it("un mort (100% blessé) est toujours prioritaire, même sur un vivant à 1 PV", function()
    local dead = make_hero("h1", { hp = 0, max_hp = 20 })
    local almost_dead = make_hero("h2", { hp = 1, max_hp = 20 }) -- 95% blessé, mais vivant
    local state = make_state({ dead, almost_dead })
    assert.equal(dead, FeuDeCamp.most_wounded_hero(state, Rng.new(1)))
  end)

  it("un héros à PV négatifs (dégâts non plafonnés) compte comme mort, pas au-delà de 100%", function()
    local very_dead = make_hero("h1", { hp = -15, max_hp = 20 })
    local wounded = make_hero("h2", { hp = 5, max_hp = 20 }) -- 75% blessé
    local state = make_state({ very_dead, wounded })
    assert.equal(very_dead, FeuDeCamp.most_wounded_hero(state, Rng.new(1)))
  end)

  it("départage une égalité via le rng dédié, de façon déterministe pour une seed donnée", function()
    local h1 = make_hero("h1", { hp = 10, max_hp = 20 })
    local h2 = make_hero("h2", { hp = 10, max_hp = 20 })
    local state = make_state({ h1, h2 })
    local first_pick = FeuDeCamp.most_wounded_hero(state, Rng.new(42))
    local second_pick = FeuDeCamp.most_wounded_hero(state, Rng.new(42))
    assert.is_true(first_pick == h1 or first_pick == h2)
    assert.equal(first_pick, second_pick)
  end)
end)

describe("FeuDeCamp.heal_hero", function()
  it("ne rend que 20% des PV max (jamais un plein soin)", function()
    local h = make_hero("h1", { hp = 5, max_hp = 20 }) -- +4 (20% de 20)
    FeuDeCamp.heal_hero(h)
    assert.equal(9, h.hp)
  end)

  it("ressuscite un héros mort (PV négatifs compris) avec seulement 20% de ses PV max, jamais plus", function()
    local h = make_hero("h1", { hp = -8, max_hp = 20 })
    FeuDeCamp.heal_hero(h)
    assert.equal(4, h.hp) -- plancher à 0 avant d'ajouter, PAS -8 + 4
  end)

  it("un mort très profondément négatif revient quand même à la vie", function()
    local h = make_hero("h1", { hp = -100, max_hp = 20 })
    FeuDeCamp.heal_hero(h)
    assert.equal(4, h.hp)
  end)

  it("ne dépasse jamais les PV max", function()
    local h = make_hero("h1", { hp = 19, max_hp = 20 }) -- +4 dépasserait 20
    FeuDeCamp.heal_hero(h)
    assert.equal(20, h.hp)
  end)
end)

describe("FeuDeCamp.upgradable_instances", function()
  it("balaie le deck, la main et la défausse", function()
    local state = make_state({}, { card_instance(1, "coup-direct") }, { card_instance(2, "encaisser") }, { card_instance(3, "rempart") })
    assert.equal(3, #FeuDeCamp.upgradable_instances(state))
  end)

  it("exclut toute instance déjà améliorée", function()
    local upgraded = card_instance(1, "coup-direct")
    upgraded.def = Cards.upgraded_def(upgraded.def)
    local plain = card_instance(2, "encaisser")
    local state = make_state({}, { upgraded, plain })
    local out = FeuDeCamp.upgradable_instances(state)
    assert.equal(1, #out)
    assert.equal(plain, out[1])
  end)
end)

describe("FeuDeCamp.pick_upgrade_targets", function()
  it("retourne nil quand moins de 2 cartes sont améliorables", function()
    local state = make_state({}, { card_instance(1, "coup-direct") })
    assert.is_nil(FeuDeCamp.pick_upgrade_targets(state, Rng.new(1)))
  end)

  it("retourne 2 instances distinctes (jamais deux fois la même carte physique)", function()
    local a, b, c = card_instance(1, "coup-direct"), card_instance(2, "coup-direct"), card_instance(3, "encaisser")
    local state = make_state({}, { a, b, c })
    local picks = FeuDeCamp.pick_upgrade_targets(state, Rng.new(7))
    assert.equal(2, #picks)
    assert.is_true(picks[1].uid ~= picks[2].uid)
  end)

  it("ne tire jamais parmi les instances déjà améliorées", function()
    local upgraded = card_instance(1, "coup-direct")
    upgraded.def = Cards.upgraded_def(upgraded.def)
    local only_plain = card_instance(2, "encaisser")
    local state = make_state({}, { upgraded, only_plain })
    -- un seul candidat éligible (only_plain) -- pas assez pour un pick de 2.
    assert.is_nil(FeuDeCamp.pick_upgrade_targets(state, Rng.new(1)))
  end)
end)

describe("FeuDeCamp.apply_upgrades", function()
  it("remplace le def de chaque instance par sa version améliorée, sans changer l'uid", function()
    local a = card_instance(1, "coup-direct")
    local original_def = a.def
    FeuDeCamp.apply_upgrades({ a })
    assert.equal(1, a.uid)
    assert.is_false(a.def == original_def)
    assert.equal("Coup direct +", a.def.name)
    assert.is_true(a.def.is_upgraded)
  end)

  it("le nouvel effet applique bien les valeurs améliorées (Coup direct : 4 -> 6 dégâts)", function()
    local a = card_instance(1, "coup-direct")
    FeuDeCamp.apply_upgrades({ a })
    local state = { heroes = {}, enemies = {}, log = {} }
    -- class_id "mage" (pas "guerrier") : isole la valeur améliorée de la
    -- Transcendance Guerrier (+50% "epee"), déjà couverte par combat_spec.lua --
    -- pas l'objet de ce test.
    local hero = make_hero("h1", { class_id = "mage" })
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    a.def.effect({ state = state, hero = hero, target = target, card_def = a.def })
    assert.equal(14, target.hp) -- 20 - 6
  end)
end)
