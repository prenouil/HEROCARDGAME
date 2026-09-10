-- Cycle de vie d'une carte / fin de tour (game/src/rules/game.lua) --
-- 2026-09-10, suite de la couverture Busted : décroissance des statuts,
-- saignement/brûlure, routage de fin de carte (Amnésie/coût 0/retour en
-- main-ou-dessus du deck), victoire, effets de bord de "jouer une carte"
-- (Furtif/Discrétion), boucliers/dégâts programmés.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")

local function make_state(heroes, enemies)
  return {
    heroes = heroes or {}, enemies = enemies or {}, log = {},
    hand = {}, discard = {}, exhausted = {}, deck = {}, pending = nil,
  }
end

describe("Game.decay_end_of_turn_statuses", function()
  it("Incapacité/Vulnérabilité/Puissance descendent de 1, jamais sous 0, héros ET ennemis (symétrique)", function()
    local hero = { incapacite = 1, vulnerabilite = 0, puissance = 3 }
    local enemy = { incapacite = 2, vulnerabilite = 1, puissance = 0 }
    local state = make_state({ hero }, { enemy })
    Game.decay_end_of_turn_statuses(state)
    assert.are.equal(0, hero.incapacite)
    assert.are.equal(0, hero.vulnerabilite) -- déjà à 0, reste à 0
    assert.are.equal(2, hero.puissance)
    assert.are.equal(1, enemy.incapacite)
    assert.are.equal(0, enemy.vulnerabilite)
    assert.are.equal(0, enemy.puissance)
  end)

  it("Inspiration : -1 automatique, SAUF si protégée par Dernier rappel (inspiration_shielded_turns)", function()
    local hero = { inspiration = 3 }
    local shielded = { inspiration = 3, inspiration_shielded_turns = 2 }
    local state = make_state({ hero, shielded }, {})
    Game.decay_end_of_turn_statuses(state)
    assert.are.equal(2, hero.inspiration)
    assert.are.equal(3, shielded.inspiration) -- protégée, ne descend pas
    assert.are.equal(1, shielded.inspiration_shielded_turns)
  end)

  it("Encore (encore_extra_plays) ne se perd JAMAIS en fin de tour", function()
    local hero = { encore_extra_plays = 1 }
    local state = make_state({ hero }, {})
    Game.decay_end_of_turn_statuses(state)
    assert.are.equal(1, hero.encore_extra_plays)
  end)
end)

describe("Game.tick_bleed", function()
  it("inflige les PV de Saignement puis décrémente, héros et ennemis", function()
    local hero = { hp = 10, saignements = 3, name = "Héros" }
    local enemy = { hp = 10, saignements = 2, name = "Ennemi" }
    local state = make_state({ hero }, { enemy })
    Game.tick_bleed(state)
    assert.are.equal(7, hero.hp)
    assert.are.equal(2, hero.saignements)
    assert.are.equal(8, enemy.hp)
    assert.are.equal(1, enemy.saignements)
  end)

  it("La Renaissante protège aussi contre une mort par Saignement", function()
    local hero = { hp = 2, saignements = 5, death_ward = true, name = "Héros" }
    local state = make_state({ hero }, {})
    Game.tick_bleed(state)
    assert.are.equal(1, hero.hp)
    assert.is_false(hero.death_ward)
  end)
end)

describe("Game.tick_burn", function()
  it("inflige les PV de Brûlure SANS jamais décrémenter (contrairement au Saignement)", function()
    local hero = { hp = 10, brulure = 3, name = "Héros" }
    local state = make_state({ hero }, {})
    Game.tick_burn(state)
    assert.are.equal(7, hero.hp)
    assert.are.equal(3, hero.brulure) -- inchangée
  end)
end)

describe("Game.check_victory", function()
  it("déclare la victoire une seule fois, quand plus aucun ennemi n'est vivant", function()
    local state = make_state({}, { { hp = 0 } })
    assert.is_true(Game.check_victory(state))
    assert.is_true(state.over)
    assert.is_false(Game.check_victory(state)) -- déjà déclenchée, pas 2 fois
  end)

  it("ne déclare rien tant qu'un ennemi est vivant", function()
    local state = make_state({}, { { hp = 5 } })
    assert.is_false(Game.check_victory(state))
    assert.is_nil(state.over)
  end)
end)

describe("Game.finish_card", function()
  local function make_card_state(pending_def, extra_hand)
    local state = make_state()
    state.hand = { { uid = "u1", def = pending_def } }
    for _, c in ipairs(extra_hand or {}) do state.hand[#state.hand + 1] = c end
    return state
  end

  it("par défaut : va à la défausse", function()
    local state = make_card_state({ code = "x" })
    Game.finish_card(state, { uid = "u1" }, nil)
    assert.are.equal(1, #state.discard)
    assert.are.equal(0, #state.hand)
    assert.is_nil(state.pending)
  end)

  it("carte taguée 'amnesie' : part dans state.exhausted, jamais la défausse", function()
    local def = { code = "x", cats = { "amnesie" } }
    local state = make_card_state(def)
    Game.finish_card(state, { uid = "u1" }, { card_def = def })
    assert.are.equal(1, #state.exhausted)
    assert.are.equal(0, #state.discard)
  end)

  it("ctx.return_to_hand : revient dans la main (Avalanche de coups qui achève sa cible)", function()
    local state = make_card_state({ code = "x" })
    Game.finish_card(state, { uid = "u1" }, { return_to_hand = true })
    assert.are.equal(1, #state.hand)
    assert.are.equal(0, #state.discard)
  end)

  it("ctx.return_to_deck_top : va sur le dessus du deck (Assassinat non-Camouflé)", function()
    local state = make_card_state({ code = "x" })
    Game.finish_card(state, { uid = "u1" }, { return_to_deck_top = true })
    assert.are.equal(1, #state.deck)
    assert.are.equal(0, #state.discard)
  end)

  it("ctx.zero_cost : la copie qui part en défausse a désormais un coût de 0, sans affecter le def canonique", function()
    local canonical = Cards.by_code("avalanche-coups")
    local state = make_card_state(canonical)
    Game.finish_card(state, { uid = "u1" }, { zero_cost = true })
    assert.are.equal(0, state.discard[1].def.cost)
    assert.are.equal(1, canonical.cost) -- le def partagé dans Cards.list reste intact
  end)
end)

describe("Game.on_card_played", function()
  it("marque played_card_this_turn et décrémente Gratuite", function()
    local hero = { gratuite = 1 }
    local state = make_state({ hero }, {})
    Game.on_card_played(state, hero, { code = "x" })
    assert.is_true(hero.played_card_this_turn)
    assert.are.equal(0, hero.gratuite)
  end)

  it("une carte NON-Furtif d'un Assassin lui retire Discrétion/Camouflé", function()
    local assassin = { discretion = 8, camoufle = 1, hp = 10 }
    local state = make_state({ assassin }, {})
    Game.on_card_played(state, assassin, { code = "x" })
    assert.are.equal(0, assassin.discretion)
    assert.are.equal(0, assassin.camoufle)
  end)

  it("une carte 'Furtif' NE fait PAS perdre Discrétion/Camouflé à l'Assassin", function()
    local assassin = { discretion = 8, camoufle = 1, hp = 10 }
    local state = make_state({ assassin }, {})
    Game.on_card_played(state, assassin, { code = "x", cats = { "furtif" } })
    assert.are.equal(8, assassin.discretion)
    assert.are.equal(1, assassin.camoufle)
  end)

  it("quand un AUTRE héros joue, l'Assassin gagne +1 Discrétion (jamais sur sa propre carte)", function()
    local assassin = { discretion = 0, hp = 10 }
    local other = { hp = 10 }
    local state = make_state({ assassin, other }, {})
    Game.on_card_played(state, other, { code = "x" })
    assert.are.equal(1, assassin.discretion)
  end)
end)

describe("Game.tick_discretion_end_of_turn", function()
  it("+5 Discrétion si l'Assassin termine le tour SANS avoir joué de carte lui-même", function()
    local assassin = { discretion = 0, played_card_this_turn = false, hp = 10 }
    local state = make_state({ assassin }, {})
    Game.tick_discretion_end_of_turn(state)
    assert.are.equal(5, assassin.discretion)
  end)

  it("rien s'il a joué au moins une carte ce tour", function()
    local assassin = { discretion = 0, played_card_this_turn = true, hp = 10 }
    local state = make_state({ assassin }, {})
    Game.tick_discretion_end_of_turn(state)
    assert.are.equal(0, assassin.discretion)
  end)
end)

-- Game.start_turn fait bien plus que consommer ces 2 files (télégraphie
-- ennemie, pioche, PO...) -- besoin d'un état COMPLET (Game.reset_run), pas
-- d'une fixture minimale, pour ne pas planter sur une dépendance sans rapport
-- avec ce qu'on teste ici (même approche que spec/riposte_spec.lua).
describe("Boucliers/dégâts programmés (Game.schedule_shield/schedule_damage, consommés par Game.start_turn)", function()
  local state, necro

  before_each(function()
    state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "necromancien" }, nil)
    necro = Combat.hero_by_id(state, "necromancien")
  end)

  it("un bouclier programmé se déclenche pile au bon tour, pas avant", function()
    necro.scheduled_shields = {}
    Game.schedule_shield(necro, 10, 2)
    local before = necro.defense or 0
    Game.start_turn(state) -- tour +1 : encore 1 tour à attendre
    assert.are.equal(before, necro.defense)
    Game.start_turn(state) -- tour +2 : se déclenche
    assert.are.equal(before + 10, necro.defense)
  end)

  it("un dégât programmé (Servant d'os) touche un ennemi vivant tiré au hasard, au bon tour", function()
    necro.scheduled_damages = {}
    Game.schedule_damage(necro, 7, 1)
    local total_hp_before = 0
    for _, e in ipairs(state.enemies) do total_hp_before = total_hp_before + e.hp end
    Game.start_turn(state)
    local total_hp_after = 0
    for _, e in ipairs(state.enemies) do total_hp_after = total_hp_after + e.hp end
    assert.are.equal(total_hp_before - 7, total_hp_after)
  end)
end)
