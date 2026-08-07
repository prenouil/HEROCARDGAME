-- Tests d'intégration du flux de partie. Ces specs pilotent Game directement
-- (pas Controller/Sequencer) : elles jouent le rôle du "mode instantané" — la
-- UI LÖVE ajoute juste le rythme (pauses, animations) par-dessus ces mêmes
-- fonctions, jamais une logique différente.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")
local Enemies = require("src.data.enemies")
local Encounter = require("src.rules.encounter")

describe("Game.reset_run", function()
  it("démarre une run avec 4 héros vivants, une main de 5 et un deck de 5", function()
    local state = Game.new_state()
    Game.reset_run(state)
    assert.equal(4, #state.heroes)
    for _, h in ipairs(state.heroes) do assert.is_true(h.hp > 0) end
    assert.equal(5, #state.hand) -- Deck.HAND_SIZE
    assert.equal(5, #state.deck) -- 10 de départ - 5 en main
    assert.equal(1, state.turn)
    assert.equal(1, state.run.combat_index)
    assert.is_false(state.over)
  end)
end)

describe("Game.start_turn — Pouvoir de Classe du Guerrier", function()
  it("inflige 2 dégâts gratuits par carte 'epee' en main, sur un ennemi vivant", function()
    local state = Game.new_state()
    state.heroes = {
      { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
        energy = 0, defense = 0, esquive = 0, camoufle = false, incapacite = 0, vulnerabilite = 0,
        puissance = 0, saignements = 0, has_acted = false },
    }
    local coup_estoc = Cards.by_code("coup-estoc") -- carte "epee"
    state.deck = {}
    for i = 1, 5 do state.deck[i] = { uid = i, def = coup_estoc } end
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end)
    enemy.hp = 100; enemy.max_hp = 100
    state.enemies = { enemy }

    Game.start_turn(state)

    assert.equal(5, #state.hand) -- les 5 cartes "epee" piochées
    assert.equal(80, enemy.hp) -- 100 - 5*2 (GUERRIER_FREE_HIT_DMG)
  end)
end)

describe("Flux de jeu : jouer une carte", function()
  it("dépense l'énergie, applique l'effet, et défausse la carte", function()
    local state = Game.new_state()
    local hero = {
      id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
      energy = 1, defense = 0, esquive = 0, camoufle = false, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0, has_acted = false,
    }
    state.heroes = { hero }
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end)
    enemy.hp = 100; enemy.max_hp = 100
    state.enemies = { enemy }

    local coup_direct = Cards.by_code("coup-direct") -- coût 0, 4 dégâts
    state.hand = { { uid = 1, def = coup_direct } }

    Game.select_card(state, 1)
    assert.is_not_nil(state.pending)
    Game.set_pending_mode(state, "play")
    Game.assign_hero(state, "guerrier")
    Game.resolve_pending(state, "enemy", enemy.id)

    assert.equal(94, enemy.hp) -- 100 - round(4 * 1.5 Transcendance Guerrier "epee") = 100 - 6
    assert.equal(0, #state.hand)
    assert.equal(1, #state.discard)
    assert.is_nil(state.pending)
    assert.is_true(hero.has_acted)
  end)

  it("la Concentration ne résout pas l'effet et rapporte +1 énergie", function()
    local state = Game.new_state()
    local hero = {
      id = "mage", class_id = "mage", name = "Mage", icon = "", hp = 10, max_hp = 10,
      energy = 0, defense = 0, esquive = 0, camoufle = false, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0, has_acted = false,
    }
    state.heroes = { hero }
    state.enemies = {}
    local boule_feu = Cards.by_code("boule-feu") -- coût 8, hors de portée sans concentration
    state.hand = { { uid = 1, def = boule_feu } }

    Game.select_card(state, 1)
    Game.set_pending_mode(state, "concentrate")
    Game.assign_hero(state, "mage")

    assert.equal(1, hero.energy)
    assert.equal(0, #state.hand) -- la carte a bien quitté la main...
    assert.equal(1, #state.discard) -- ...vers la défausse (pas d'effet résolu)
  end)
end)

describe("Flux de jeu : fin de tour et résolution ennemie", function()
  it("défausse la main, applique les saignements, résout les ennemis, puis avance le tour", function()
    local state = Game.new_state()
    state.heroes = {
      { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
        energy = 0, defense = 0, esquive = 0, camoufle = false, incapacite = 0, vulnerabilite = 0,
        puissance = 0, saignements = 0, has_acted = true },
    }
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end)
    enemy.hp = 100; enemy.max_hp = 100
    enemy.incapacite = 1; enemy.vulnerabilite = 1 -- pour vérifier leur décroissance en fin de tour
    enemy.next_move = { kind = "dmg", name = "Griffure", icon = "", amount = 5 }
    enemy.target_hero_id = "guerrier"
    state.enemies = { enemy }
    state.hand = { { uid = 1, def = Cards.by_code("coup-direct") } }
    state.deck = {}

    local result = Game.end_turn_requested(state)
    assert.equal("discarded", result)
    assert.equal(0, #state.hand)
    assert.equal(1, #state.discard)

    Game.tick_bleed(state)
    assert.is_false(Game.check_defeat(state))
    assert.is_false(Game.check_victory(state))
    Game.resolve_enemy_action(state, enemy)
    Game.decay_end_of_turn_statuses(state)
    assert.is_false(Game.check_defeat(state))

    local hero = state.heroes[1]
    assert.equal(13, hero.hp) -- 18 - 5 (Griffure)
    assert.equal(0, enemy.incapacite) -- décru de 1 à 0 en fin de tour
    assert.equal(0, enemy.vulnerabilite)

    state.turn = state.turn + 1
    Game.start_turn(state)
    assert.equal(2, state.turn)
    assert.is_false(hero.has_acted) -- réinitialisé en début de tour
  end)
end)
