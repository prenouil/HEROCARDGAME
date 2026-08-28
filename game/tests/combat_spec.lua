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

  -- Discrétion perdue en encaissant des dégâts (2026-08-28, demande explicite,
  -- complète le mécanisme de l'Assassin -- voir game_spec.lua pour les 2
  -- autres resets, "joue une carte non-Furtif" et "fin de tour").
  it("une VRAIE perte de PV (to_hp > 0) remet Discrétion et Camouflé de la cible à 0", function()
    local state = make_state()
    local target = make_hero("h1", { class_id = "assassin", discretion = 7, camoufle = 1 })
    Combat.deal_damage(state, nil, target, 4, "physique", nil)
    assert.equal(0, target.discretion)
    assert.equal(0, target.camoufle)
  end)

  it("un coup entièrement absorbé par le Bouclier (to_hp == 0) ne touche pas la Discrétion", function()
    local state = make_state()
    local target = make_hero("h1", { class_id = "assassin", discretion = 7, camoufle = 1, defense = 10 })
    Combat.deal_damage(state, nil, target, 4, "physique", nil)
    assert.equal(7, target.discretion)
    assert.equal(1, target.camoufle)
  end)

  it("ne touche jamais un héros sans Discrétion (discretion == nil, pas l'Assassin)", function()
    local state = make_state()
    local target = make_hero("h1", { class_id = "guerrier" })
    Combat.deal_damage(state, nil, target, 4, "physique", nil)
    assert.is_nil(target.discretion)
  end)

  -- "La Renaissante" (2026-08-29, bénédiction du Temple -- hero.death_ward,
  -- "1 seule fois" par combat).
  it("death_ward sauve la cible à 1 PV puis se consomme (jamais 2 fois)", function()
    local state = make_state()
    local target = make_hero("h1", { hp = 5, death_ward = true })
    Combat.deal_damage(state, nil, target, 20, "physique", nil, { brut = true })
    assert.equal(1, target.hp)
    assert.is_false(target.death_ward)
    Combat.deal_damage(state, nil, target, 20, "physique", nil, { brut = true })
    assert.is_true(target.hp <= 0) -- 2e mort : plus de garde-fou disponible
  end)

  -- "Le Rancunier" (2026-08-29, bénédiction -- hero.thorns) : renvoie à
  -- l'attaquant, jamais à soi-même.
  it("thorns renvoie le montant déclaré à l'attaquant (opts.source_unit)", function()
    local state = make_state()
    local target = make_hero("h1", { thorns = 2 })
    local attacker = make_enemy("e1")
    Combat.deal_damage(state, nil, target, 4, "physique", nil, { source_unit = attacker })
    assert.equal(18, attacker.hp) -- 20 - 2, ignore la défense (brut)
  end)

  it("thorns ne se déclenche pas sur un coup entièrement absorbé (to_hp == 0)", function()
    local state = make_state()
    local target = make_hero("h1", { thorns = 2, defense = 10 })
    local attacker = make_enemy("e1")
    Combat.deal_damage(state, nil, target, 4, "physique", nil, { source_unit = attacker })
    assert.equal(20, attacker.hp) -- inchangé
  end)

  -- "Le Blessé" (2026-08-29, malédiction -- hero.self_damage_on_hit) : se
  -- blesse en attaquant un ENNEMI, jamais sur un allié ou un coup manqué.
  it("self_damage_on_hit blesse le héros quand il inflige de vrais dégâts à un ennemi", function()
    local state = make_state()
    local hero = make_hero("h1", { self_damage_on_hit = 1 })
    local enemy = make_enemy("e1")
    state.enemies = { enemy }
    Combat.deal_damage(state, hero, enemy, 4, "physique", nil)
    assert.equal(19, hero.hp) -- 20 - 1
  end)
end)

describe("Combat.damage_multiplier : sensibilité au feu de l'Homme Arbre (2026-08-24)", function()
  it("une carte taguée 'feu' inflige +50% à l'Homme Arbre", function()
    local state = make_state()
    local hero = make_hero("h1")
    local target = make_enemy("boss", { template_id = "homme-arbre", hp = 80, max_hp = 80 })
    local ctx = { card_def = { cats = { "melee", "degats", "feu" } } }
    Combat.deal_damage(state, hero, target, 8, "magique", ctx)
    assert.equal(68, target.hp) -- 80 - round(8*1.5=12)
  end)

  it("une carte non-feu n'a aucun bonus contre l'Homme Arbre", function()
    local state = make_state()
    local hero = make_hero("h1")
    local target = make_enemy("boss", { template_id = "homme-arbre", hp = 80, max_hp = 80 })
    local ctx = { card_def = { cats = { "melee", "degats" } } }
    Combat.deal_damage(state, hero, target, 8, "physique", ctx)
    assert.equal(72, target.hp) -- 80 - 8, aucun bonus
  end)

  it("une carte 'feu' n'a aucun bonus contre un ennemi qui n'est pas l'Homme Arbre", function()
    local state = make_state()
    local hero = make_hero("h1")
    local target = make_enemy("e1", { template_id = "gobelin" })
    local ctx = { card_def = { cats = { "sort", "feu" } } }
    Combat.deal_damage(state, hero, target, 8, "magique", ctx)
    assert.equal(12, target.hp) -- 20 - 8, aucun bonus
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

-- "Le Corrompu" (2026-08-29, malédiction -- hero.card_cost_delta).
describe("Combat.effective_cost", function()
  it("ajoute card_cost_delta au coût de base", function()
    local hero = make_hero("h1", { card_cost_delta = 1 })
    assert.equal(3, Combat.effective_cost(hero, { cost = 2 }))
  end)

  it("ne change rien pour un héros non maudit (card_cost_delta == nil)", function()
    local hero = make_hero("h1")
    assert.equal(2, Combat.effective_cost(hero, { cost = 2 }))
  end)

  it("gère un hero nil sans erreur (def.cost brut)", function()
    assert.equal(2, Combat.effective_cost(nil, { cost = 2 }))
  end)
end)

describe("Combat.can_play", function()
  it("refuse le coût EFFECTIF (Le Corrompu, +1) même si le coût de base serait payable", function()
    local state = make_state({ energy = 2 })
    local hero = make_hero("h1", { card_cost_delta = 1 })
    local pending = { def = { cost = 2, requires_camouflage = false } }
    assert.is_false(Combat.can_play(state, hero, pending))
  end)

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

-- Inspiration (2026-08-29, statut GÉNÉRIQUE du Barde -- hero.inspiration, voir
-- game.lua/cards.lua) : +6 flat au PREMIER effet de dégâts/soin/bouclier
-- déclenché en jouant une carte, consommé une seule fois par carte (garde-fou
-- porté par `ctx`, partagé entre tous les appels au sein d'un même effect()).
describe("Inspiration (consume_inspiration, combat.lua)", function()
  it("Combat.deal_damage ajoute +6 flat si ctx.hero a de l'Inspiration, et consomme 1 charge", function()
    local state = make_state()
    local hero = make_hero("h1", { inspiration = 2 })
    local target = make_enemy("e1")
    local ctx = { state = state, hero = hero, target = target }
    Combat.deal_damage(state, hero, target, 5, "physique", ctx)
    assert.equal(20 - (5 + 6), target.hp)
    assert.equal(1, hero.inspiration) -- 1 charge consommée
  end)

  it("ne s'applique qu'UNE fois par carte, même si plusieurs cibles/effets dans le même ctx", function()
    local state = make_state()
    local hero = make_hero("h1", { inspiration = 1 })
    local target1, target2 = make_enemy("e1"), make_enemy("e2")
    local ctx = { state = state, hero = hero }
    Combat.deal_damage(state, hero, target1, 5, "physique", ctx)
    Combat.deal_damage(state, hero, target2, 5, "physique", ctx)
    assert.equal(20 - (5 + 6), target1.hp) -- le 1er appel prend le bonus
    assert.equal(20 - 5, target2.hp) -- le 2e n'a plus rien à consommer
    assert.equal(0, hero.inspiration)
  end)

  it("ne s'applique jamais sans ctx (attaque ennemie, épines, dégâts hors carte)", function()
    local state = make_state()
    local target = make_hero("h1", { inspiration = 3 })
    Combat.deal_damage(state, nil, target, 5, "physique", nil)
    assert.equal(15, target.hp) -- 20 - 5, aucun bonus
    assert.equal(3, target.inspiration) -- rien consommé
  end)

  it("Combat.grant_heal/grant_defense appliquent aussi le bonus via ctx (synergie inter-classes)", function()
    local state = make_state()
    local hero = make_hero("h1", { inspiration = 1 })
    local ctx = { state = state, hero = hero }
    local ally = make_hero("h2")
    Combat.grant_heal(ally, 4, ctx)
    assert.equal(20, ally.hp) -- déjà au max, mais le calcul interne est 4+6=10 (plafonné)
    assert.equal(0, hero.inspiration)

    local hero2 = make_hero("h3", { inspiration = 1 })
    local ctx2 = { state = state, hero = hero2 }
    local target = make_hero("h4", { defense = 0 })
    Combat.grant_defense(target, 4, ctx2)
    assert.equal(10, target.defense) -- 4 + 6
    assert.equal(0, hero2.inspiration)
  end)
end)

-- Corruption (2026-08-29, ressource propre au Nécromancien -- hero.corruption,
-- voir game.lua) : +1 par VRAIE perte de PV, dégâts ennemis OU auto-infligés
-- (les 2 passent par Combat.deal_damage, voir cards.lua -- Sceau de
-- faiblesse/Pacte funeste).
describe("Corruption (gain automatique dans Combat.deal_damage)", function()
  it("gagne 1 Corruption par PV réellement perdu", function()
    local state = make_state()
    local target = make_hero("h1", { corruption = 0, defense = 0 })
    Combat.deal_damage(state, nil, target, 7, "physique", nil)
    assert.equal(7, target.corruption)
  end)

  it("ne gagne rien si les dégâts sont entièrement absorbés par le Bouclier", function()
    local state = make_state()
    local target = make_hero("h1", { corruption = 0, defense = 10 })
    Combat.deal_damage(state, nil, target, 7, "physique", nil)
    assert.equal(0, target.corruption)
  end)

  it("n'affecte jamais une unité sans champ corruption (toute autre classe)", function()
    local state = make_state()
    local target = make_hero("h1") -- pas de champ corruption
    Combat.deal_damage(state, nil, target, 7, "physique", nil)
    assert.is_nil(target.corruption)
  end)
end)
