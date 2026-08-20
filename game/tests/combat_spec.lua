local Combat = require("src.rules.combat")

-- `energy` (2026-08-11) : réserve globale, pas un champ par héros -- voir
-- Combat.can_play.
local function make_state(overrides)
  local s = { heroes = {}, enemies = {}, log = {}, energy = 0 }
  for k, v in pairs(overrides or {}) do s[k] = v end
  return s
end

local function make_hero(id, overrides)
  local h = { id = id, name = id, class_id = "guerrier", hp = 20, max_hp = 20, defense = 0 }
  for k, v in pairs(overrides or {}) do h[k] = v end
  return h
end

local function make_enemy(id, overrides)
  local e = { id = id, name = id, hp = 20, max_hp = 20, defense = 0 }
  for k, v in pairs(overrides or {}) do e[k] = v end
  return e
end

describe("Combat.deal_damage", function()
  it("inflige les dégâts de base sans modificateur", function()
    local state = make_state()
    local target = make_enemy("e1")
    Combat.deal_damage(state, nil, target, 10, "physique", nil)
    assert.equal(10, target.hp)
  end)

  it("absorbe les dégâts avec la Défense avant de toucher les PV", function()
    local state = make_state()
    local target = make_enemy("e1", { defense = 6 })
    Combat.deal_damage(state, nil, target, 10, "physique", nil)
    assert.equal(0, target.defense)
    assert.equal(16, target.hp) -- 20 - (10 - 6)
  end)

  it("les dégâts bruts ignorent la Défense", function()
    local state = make_state()
    local target = make_enemy("e1", { defense = 6 })
    Combat.deal_damage(state, nil, target, 10, "physique", nil, { brut = true })
    assert.equal(6, target.defense) -- inchangée
    assert.equal(10, target.hp)
  end)

  it("Vulnérabilité augmente les dégâts reçus de 25%", function()
    local state = make_state()
    local target = make_enemy("e1", { vulnerabilite = 1 })
    Combat.deal_damage(state, nil, target, 4, "physique", nil)
    assert.equal(15, target.hp) -- 20 - round(4*1.25=5)
  end)

  it("Incapacité côté source réduit les dégâts infligés de 25%", function()
    local state = make_state()
    local hero = make_hero("h1", { incapacite = 1 })
    local target = make_enemy("e1")
    Combat.deal_damage(state, hero, target, 4, "physique", nil)
    assert.equal(17, target.hp) -- 20 - round(4*0.75=3)
  end)
end)

describe("Combat.grant_defense / grant_heal", function()
  it("grant_defense ajoute le montant donné, sans aucun modificateur de classe", function()
    local target = make_hero("h1", { defense = 0 })
    local amount = Combat.grant_defense(target, 4)
    assert.equal(4, amount)
    assert.equal(4, target.defense)
  end)

  it("le soin ne dépasse jamais max_hp", function()
    local target = make_hero("h1", { hp = 19, max_hp = 20 })
    Combat.grant_heal(target, 10)
    assert.equal(20, target.hp)
  end)
end)

describe("Combat.apply_status", function()
  it("ajoute le montant donné au champ de statut, sans aucun modificateur de classe", function()
    local unit = make_hero("h1", { camoufle = 0 })
    local applied = Combat.apply_status(unit, "camoufle", 1)
    assert.equal(1, applied)
    assert.equal(1, unit.camoufle)
  end)
end)

describe("Combat.can_play", function()
  it("refuse si la réserve d'énergie globale (state.energy) est sous le coût de la carte", function()
    local state = make_state({ energy = 2 })
    local hero = make_hero("h1")
    local pending = { def = { cost = 3, requires_camouflage = false } }
    assert.is_false(Combat.can_play(state, hero, pending))
  end)

  it("autorise si la réserve globale couvre le coût, peu importe l'énergie -- il n'y en a plus par héros", function()
    local state = make_state({ energy = 3 })
    local hero = make_hero("h1")
    local pending = { def = { cost = 3, requires_camouflage = false } }
    assert.is_true(Combat.can_play(state, hero, pending))
  end)

  it("refuse un héros mort, même avec assez d'énergie", function()
    local state = make_state({ energy = 3 })
    local pending = { def = { cost = 0, requires_camouflage = false } }
    assert.is_false(Combat.can_play(state, make_hero("h1", { hp = 0 }), pending))
  end)

  it("autorise un héros ayant déjà joué une carte ce tour (2026-08-20, plus de notion de \"a déjà agi\")", function()
    local state = make_state({ energy = 3 })
    local hero = make_hero("h1")
    local pending = { def = { cost = 0, requires_camouflage = false } }
    assert.is_true(Combat.can_play(state, hero, pending))
  end)

  it("refuse une carte 'requires_camouflage' si le héros n'est pas Camouflé", function()
    local state = make_state({ energy = 3 })
    local hero = make_hero("h1", { camoufle = 0 })
    local pending = { def = { cost = 0, requires_camouflage = true } }
    assert.is_false(Combat.can_play(state, hero, pending))
  end)

  it("refuse une carte 'mana_cost' si la mana du héros (propre au Mage) est insuffisante, même avec assez d'énergie", function()
    local state = make_state({ energy = 3 })
    local hero = make_hero("h1", { class_id = "mage", mana = 1 })
    local pending = { def = { cost = 0, mana_cost = 2 } }
    assert.is_false(Combat.can_play(state, hero, pending))
  end)

  it("autorise une carte 'mana_cost' si énergie ET mana couvrent tous les deux le coût", function()
    local state = make_state({ energy = 3 })
    local hero = make_hero("h1", { class_id = "mage", mana = 2 })
    local pending = { def = { cost = 0, mana_cost = 2 } }
    assert.is_true(Combat.can_play(state, hero, pending))
  end)

  it("refuse une carte 'mana_cost' pour un héros sans mana (mana == nil, pas le Mage)", function()
    local state = make_state({ energy = 3 })
    local hero = make_hero("h1") -- class_id = "guerrier" par défaut, pas de champ mana
    local pending = { def = { cost = 0, mana_cost = 1 } }
    assert.is_false(Combat.can_play(state, hero, pending))
  end)
end)

describe("Combat.enemy_targeting", function()
  it("retrouve l'ennemi dont l'action télégraphiée cible ce héros", function()
    local state = make_state()
    local hero = make_hero("h1")
    local enemy = make_enemy("e1", { hp = 10, next_move = { kind = "dmg" }, target_hero_id = "h1" })
    state.enemies = { enemy }
    assert.equal(enemy, Combat.enemy_targeting(state, hero))
  end)

  it("ignore les ennemis morts ou dont l'action n'est pas ciblable (heal-self)", function()
    local state = make_state()
    local hero = make_hero("h1")
    state.enemies = {
      make_enemy("e1", { hp = 0, next_move = { kind = "dmg" }, target_hero_id = "h1" }),
      make_enemy("e2", { hp = 10, next_move = { kind = "heal-self" }, target_hero_id = "h1" }),
    }
    assert.is_nil(Combat.enemy_targeting(state, hero))
  end)
end)
