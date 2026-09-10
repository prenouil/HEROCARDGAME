-- Couverture du moteur de combat pur (game/src/rules/combat.lua) -- 2026-09-10,
-- suite du premier lot (Enchantements, voir spec/enchantements_spec.lua). Teste
-- le module ISOLÉMENT (fixtures minimales, pas Game.reset_run) : combat.lua ne
-- dépend que d'un `state` portant `.log`/`.enemies`/`.heroes` et d'unités
-- (héros/ennemis) qui sont de simples tables -- voir son commentaire d'en-tête,
-- "testable seul via busted" était l'intention dès l'origine.
--
-- Les mécaniques déjà couvertes par les Enchantements (thorns/shield_thorns/
-- bouclier_vivant/pacte_survie/instinct_chasseur/combustion_differee via leurs
-- propres hooks) ne sont PAS redupliquées ici -- ce fichier couvre le
-- comportement DE BASE du moteur : arrondi, coût effectif, multiplicateur de
-- dégâts (Puissance/Incapacité/Vulnérabilité/Vol, règle additive-avant-
-- multiplicative), absorption par bouclier, Discrétion/Corruption/Le Rancunier/
-- La Renaissante/Le Blessé, Inspiration, soin plafonné, statuts génériques.

local Combat = require("src.rules.combat")

local function make_state(enemies, heroes)
  return { log = {}, enemies = enemies or {}, heroes = heroes or {} }
end

local function make_unit(hp, extra)
  -- `name` : Combat.deal_damage logge toujours "X inflige Y dégâts... à
  -- <name>." (voir son commentaire) -- nécessaire même dans une fixture
  -- minimale, sinon la concaténation plante sur `nil`.
  local u = { hp = hp, max_hp = hp, defense = 0, name = "Cible" }
  if extra then for k, v in pairs(extra) do u[k] = v end end
  return u
end

describe("Combat.round", function()
  it("arrondit au plus proche, .5 vers le haut (floor(x+0.5))", function()
    assert.are.equal(2, Combat.round(2.4))
    assert.are.equal(3, Combat.round(2.5))
    assert.are.equal(-2, Combat.round(-2.5))
  end)
end)

describe("Combat.effective_cost", function()
  it("sans héros : coût brut de la carte", function()
    assert.are.equal(2, Combat.effective_cost(nil, { cost = 2 }))
  end)

  it("card_cost_delta (malédiction Le Corrompu) s'ajoute au coût", function()
    local hero = { card_cost_delta = 1 }
    assert.are.equal(3, Combat.effective_cost(hero, { cost = 2 }))
  end)

  it("Gratuite > 0 force le coût à 0, même avec card_cost_delta actif", function()
    local hero = { gratuite = 1, card_cost_delta = 1 }
    assert.are.equal(0, Combat.effective_cost(hero, { cost = 2 }))
  end)
end)

describe("Combat.can_play", function()
  local state
  before_each(function() state = make_state(); state.energy = 3 end)

  it("refuse sans pending, ou un héros mort", function()
    assert.is_false(Combat.can_play(state, { hp = 10 }, nil))
    assert.is_false(Combat.can_play(state, { hp = 0 }, { def = { cost = 1 } }))
  end)

  it("refuse si l'énergie globale est insuffisante, accepte sinon", function()
    local hero = { hp = 10 }
    assert.is_false(Combat.can_play(state, hero, { def = { cost = 4 } }))
    assert.is_true(Combat.can_play(state, hero, { def = { cost = 3 } }))
  end)

  it("mana_cost : refuse si la mana du héros ne suffit pas", function()
    local hero = { hp = 10, mana = 1 }
    assert.is_false(Combat.can_play(state, hero, { def = { cost = 1, mana_cost = 2 } }))
    hero.mana = 2
    assert.is_true(Combat.can_play(state, hero, { def = { cost = 1, mana_cost = 2 } }))
  end)

  it("requires_camouflage : refuse sans Camouflé, accepte avec", function()
    local hero = { hp = 10, camoufle = 0 }
    assert.is_false(Combat.can_play(state, hero, { def = { cost = 1, requires_camouflage = true } }))
    hero.camoufle = 1
    assert.is_true(Combat.can_play(state, hero, { def = { cost = 1, requires_camouflage = true } }))
  end)
end)

describe("Combat.damage_multiplier", function()
  it("1 (neutre) sans aucun statut", function()
    assert.are.equal(1, Combat.damage_multiplier(nil, nil, "physique", false))
  end)

  it("Puissance : +25% par charge, seulement en physique", function()
    local source = { puissance = 2 }
    assert.are.equal(1.5, Combat.damage_multiplier(source, nil, "physique", false))
    assert.are.equal(1, Combat.damage_multiplier(source, nil, "magique", false))
  end)

  it("Incapacité : -25% flat, quel que soit le type de dégâts", function()
    local source = { incapacite = 1 }
    assert.are.equal(0.75, Combat.damage_multiplier(source, nil, "physique", false))
    assert.are.equal(0.75, Combat.damage_multiplier(source, nil, "magique", false))
  end)

  it("Vulnérabilité : +25% flat sur la cible, quel que soit le type de dégâts", function()
    local target = { vulnerabilite = 1 }
    assert.are.equal(1.25, Combat.damage_multiplier(nil, target, "physique", false))
  end)

  it("sensibilité au feu de l'Homme Arbre : +50% flat si is_fire", function()
    local target = { template_id = "homme-arbre" }
    assert.are.equal(1.5, Combat.damage_multiplier(nil, target, "magique", true))
    assert.are.equal(1, Combat.damage_multiplier(nil, target, "magique", false))
  end)

  it("plusieurs pourcentages s'additionnent AVANT d'être appliqués, jamais composés en chaîne", function()
    local source = { puissance = 2 } -- +50%
    local target = { vulnerabilite = 1 } -- +25%
    -- Additif : 1 + 0.5 + 0.25 = 1.75, PAS 1.5 * 1.25 = 1.875.
    assert.are.equal(1.75, Combat.damage_multiplier(source, target, "physique", false))
  end)

  it("Vol : réduit les dégâts physique à 0, même avec Vulnérabilité active, mais épargne la magie", function()
    local target = { vol = 1, vulnerabilite = 1 }
    assert.are.equal(0, Combat.damage_multiplier(nil, target, "physique", false))
    assert.are.equal(1.25, Combat.damage_multiplier(nil, target, "magique", false))
  end)
end)

describe("Combat.deal_damage", function()
  it("sans bouclier : tous les dégâts vont aux PV, renvoie shook=true", function()
    local state = make_state()
    local target = make_unit(10)
    local shook = Combat.deal_damage(state, nil, target, 4, "physique", nil)
    assert.are.equal(6, target.hp)
    assert.is_true(shook)
  end)

  it("bouclier partiel : absorbe ce qu'il peut, le reste passe aux PV", function()
    local state = make_state()
    local target = make_unit(10, { defense = 2 })
    Combat.deal_damage(state, nil, target, 5, "physique", nil)
    assert.are.equal(0, target.defense)
    assert.are.equal(7, target.hp) -- 10 - (5-2)
  end)

  it("bouclier total : PV intacts, shook=false", function()
    local state = make_state()
    local target = make_unit(10, { defense = 5 })
    local shook = Combat.deal_damage(state, nil, target, 3, "physique", nil)
    assert.are.equal(2, target.defense)
    assert.are.equal(10, target.hp)
    assert.is_false(shook)
  end)

  it("opts.brut ignore complètement le bouclier", function()
    local state = make_state()
    local target = make_unit(10, { defense = 5 })
    Combat.deal_damage(state, nil, target, 3, "physique", nil, { brut = true })
    assert.are.equal(5, target.defense) -- intact
    assert.are.equal(7, target.hp) -- perd bien les 3, pas absorbé
  end)

  it("Discrétion/Camouflé perdus seulement sur une VRAIE perte de PV, jamais sur un coup totalement paré", function()
    local state = make_state()
    local target = make_unit(10, { defense = 0, discretion = 5, camoufle = 1 })
    Combat.deal_damage(state, nil, target, 3, "physique", nil)
    assert.are.equal(0, target.discretion)
    assert.are.equal(0, target.camoufle)

    local target2 = make_unit(10, { defense = 5, discretion = 5, camoufle = 1 })
    Combat.deal_damage(state, nil, target2, 3, "physique", nil)
    assert.are.equal(5, target2.discretion) -- coup entièrement absorbé : intact
  end)

  it("Corruption : +1 par VRAIE perte de PV, rien si entièrement absorbé", function()
    local state = make_state()
    local target = make_unit(10, { corruption = 0 })
    Combat.deal_damage(state, nil, target, 4, "physique", nil)
    assert.are.equal(4, target.corruption)

    local target2 = make_unit(10, { defense = 10, corruption = 0 })
    Combat.deal_damage(state, nil, target2, 4, "physique", nil)
    assert.are.equal(0, target2.corruption)
  end)

  it("Le Rancunier (thorns) : renvoie le montant à l'attaquant, jamais sur soi-même", function()
    local state = make_state()
    local attacker = make_unit(20)
    local target = make_unit(10, { thorns = 3 })
    Combat.deal_damage(state, nil, target, 2, "physique", nil, { source_unit = attacker })
    assert.are.equal(17, attacker.hp) -- 20 - 3

    -- Riposte-like : source_unit == target_unit (auto-dégât) -> pas de retour sur soi.
    local self_hit = make_unit(10, { thorns = 3 })
    Combat.deal_damage(state, nil, self_hit, 2, "physique", nil, { source_unit = self_hit })
    assert.are.equal(8, self_hit.hp) -- 10 - 2, aucun rebond supplémentaire
  end)

  it("La Renaissante (death_ward) : reste à 1 PV au lieu de mourir, consommée une seule fois", function()
    local state = make_state()
    local target = make_unit(5, { death_ward = true })
    Combat.deal_damage(state, nil, target, 20, "physique", nil, { brut = true })
    assert.are.equal(1, target.hp)
    assert.is_false(target.death_ward)
  end)

  it("Le Blessé (self_damage_on_hit) : se blesse en touchant réellement un ennemi, jamais sur un allié", function()
    local state = make_state()
    local enemy = make_unit(10)
    state.enemies = { enemy }
    local source_hero = make_unit(20, { self_damage_on_hit = 2 })
    Combat.deal_damage(state, source_hero, enemy, 3, "physique", nil)
    assert.are.equal(18, source_hero.hp) -- 20 - 2

    local ally = make_unit(10) -- pas dans state.enemies
    local source_hero2 = make_unit(20, { self_damage_on_hit = 2 })
    Combat.deal_damage(state, source_hero2, ally, 3, "physique", nil)
    assert.are.equal(20, source_hero2.hp) -- pas de rebond sur un allié touché
  end)
end)

describe("Combat.grant_defense", function()
  it("ajoute le montant demandé et renvoie ce montant", function()
    local target = make_unit(10)
    local amount = Combat.grant_defense(target, 4, nil)
    assert.are.equal(4, target.defense)
    assert.are.equal(4, amount)
  end)

  it("Inspiration : +6 flat, consommée une seule fois par ctx", function()
    local hero = { inspiration = 1 }
    local target = make_unit(10)
    local ctx = { hero = hero }
    Combat.grant_defense(target, 4, ctx)
    assert.are.equal(10, target.defense) -- 4 + 6
    assert.are.equal(0, hero.inspiration)

    -- Un 2ème appel avec le MÊME ctx ne consomme plus rien.
    Combat.grant_defense(target, 4, ctx)
    assert.are.equal(14, target.defense) -- +4 seulement
  end)
end)

describe("Combat.grant_heal", function()
  it("plafonne à max_hp et renvoie le delta RÉELLEMENT appliqué", function()
    local target = make_unit(10)
    target.hp = 8
    local applied = Combat.grant_heal(target, 5, nil)
    assert.are.equal(10, target.hp)
    assert.are.equal(2, applied) -- pas 5, seulement ce qui manquait
  end)

  it("Inspiration s'applique aussi au soin (+6 flat)", function()
    local hero = { inspiration = 1 }
    local target = make_unit(20)
    target.hp = 5
    Combat.grant_heal(target, 2, { hero = hero })
    assert.are.equal(13, target.hp) -- 5 + (2+6)
  end)
end)

describe("Combat.apply_status", function()
  it("part de 0 (nil) et s'accumule à chaque appel", function()
    local unit = {}
    Combat.apply_status(unit, "vulnerabilite", 2)
    assert.are.equal(2, unit.vulnerabilite)
    Combat.apply_status(unit, "vulnerabilite", 1)
    assert.are.equal(3, unit.vulnerabilite)
  end)
end)

describe("Combat.enemy_targeting", function()
  it("trouve le premier ennemi vivant dont l'action télégraphiée cible ce héros", function()
    local hero = { id = "guerrier" }
    local e1 = { hp = 10, next_move = { kind = "dmg" }, target_hero_id = "mage" }
    local e2 = { hp = 10, next_move = { kind = "dmg" }, target_hero_id = "guerrier" }
    local state = make_state({ e1, e2 })
    assert.are.equal(e2, Combat.enemy_targeting(state, hero))
  end)

  it("ignore un ennemi mort ou un move non ciblable, renvoie nil si personne ne vise", function()
    local hero = { id = "guerrier" }
    local dead = { hp = 0, next_move = { kind = "dmg" }, target_hero_id = "guerrier" }
    local buff_move = { hp = 10, next_move = { kind = "buff" }, target_hero_id = "guerrier" }
    local state = make_state({ dead, buff_move })
    assert.is_nil(Combat.enemy_targeting(state, hero))
  end)
end)
