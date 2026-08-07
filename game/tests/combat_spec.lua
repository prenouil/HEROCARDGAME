local Combat = require("src.rules.combat")

local function make_state()
  return { heroes = {}, enemies = {}, log = {} }
end

local function make_hero(id, overrides)
  local h = { id = id, name = id, class_id = "guerrier", hp = 20, max_hp = 20, defense = 0, energy = 0 }
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

  it("Transcendance Guerrier : +50% sur une carte 'epee' jouée par le Guerrier", function()
    local state = make_state()
    local hero = make_hero("h1", { class_id = "guerrier" })
    local target = make_enemy("e1")
    local ctx = { card_def = { desc = 'Inflige 4 "epee".' } }
    Combat.deal_damage(state, hero, target, 4, "physique", ctx)
    assert.equal(14, target.hp) -- 20 - round(4*1.5=6)
  end)

  it("pas de bonus Transcendance si le Guerrier joue une carte sans le mot-clé epee", function()
    local state = make_state()
    local hero = make_hero("h1", { class_id = "guerrier" })
    local target = make_enemy("e1")
    local ctx = { card_def = { desc = 'Gagne "Esquive" 2.' } }
    Combat.deal_damage(state, hero, target, 4, "physique", ctx)
    assert.equal(16, target.hp)
  end)

  it("le coup gratuit du Pouvoir de Classe (ctx=nil) ne reçoit pas la Transcendance", function()
    local state = make_state()
    local hero = make_hero("h1", { class_id = "guerrier" })
    local target = make_enemy("e1")
    Combat.deal_damage(state, hero, target, 2, "physique", nil)
    assert.equal(18, target.hp) -- pas de x1.5, ctx est nil
  end)

  it("Transcendance Assassin : une carte 'epee' jouée par l'Assassin inflige Incapacité 1 + Vulnérabilité 1", function()
    local state = make_state()
    local hero = make_hero("h1", { class_id = "assassin" })
    local target = make_enemy("e1")
    local ctx = { card_def = { desc = 'Inflige 6 "epee".' } }
    Combat.deal_damage(state, hero, target, 6, "physique", ctx)
    assert.equal(1, target.incapacite)
    assert.equal(1, target.vulnerabilite)
  end)
end)

describe("Combat.grant_defense / grant_heal", function()
  it("Transcendance Paladin : +50% sur le bouclier d'une carte 'bouclier' jouée par le Paladin", function()
    local hero = make_hero("h1", { class_id = "paladin" })
    local target = make_hero("h1", { defense = 0 })
    local ctx = { hero = hero, card_def = { desc = 'Gagne 4 "bouclier".' } }
    local amount = Combat.grant_defense(target, 4, ctx)
    assert.equal(6, amount)
    assert.equal(6, target.defense)
  end)

  it("pas de bonus Paladin si la carte n'a pas le mot-clé bouclier", function()
    local hero = make_hero("h1", { class_id = "paladin" })
    local target = make_hero("h1", { defense = 0 })
    local ctx = { hero = hero, card_def = { desc = 'Gagne "Esquive" 2.' } }
    local amount = Combat.grant_defense(target, 4, ctx)
    assert.equal(4, amount)
  end)

  it("le soin ne dépasse jamais max_hp", function()
    local target = make_hero("h1", { hp = 19, max_hp = 20 })
    Combat.grant_heal(target, 10, nil)
    assert.equal(20, target.hp)
  end)
end)

describe("Combat.effective_cost / required_cost", function()
  it("Transcendance Mage : -2 sur tout sort joué par le Mage", function()
    local hero = make_hero("h1", { class_id = "mage" })
    local def = { cost = 8, cats = { "sort", "distance", "degats" } }
    assert.equal(6, Combat.effective_cost(hero, def))
  end)

  it("le coût ne descend jamais sous 0", function()
    local hero = make_hero("h1", { class_id = "mage" })
    local def = { cost = 1, cats = { "sort" } }
    assert.equal(0, Combat.effective_cost(hero, def))
  end)

  it("se concentrer ne coûte jamais rien, quel que soit le coût imprimé", function()
    local hero = make_hero("h1", { class_id = "guerrier" })
    local pending = { mode = "concentrate", def = { cost = 8, cats = {} } }
    assert.equal(0, Combat.required_cost(hero, pending))
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
