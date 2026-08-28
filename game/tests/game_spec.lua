-- Tests d'intégration du flux de partie. Ces specs pilotent Game directement
-- (pas Controller/Sequencer) : elles jouent le rôle du "mode instantané" — la
-- UI LÖVE ajoute juste le rythme (pauses, animations) par-dessus ces mêmes
-- fonctions, jamais une logique différente.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")
local Enemies = require("src.data.enemies")
local Encounter = require("src.rules.encounter")
local Rng = require("src.util.rng")

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

describe("Game.start_turn : énergie globale", function()
  it("remet l'énergie à Game.TURN_START_ENERGY pile, en partant d'en dessous", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1)
    assert.equal(0, state.energy)
    Game.start_turn(state)
    assert.equal(Game.TURN_START_ENERGY, state.energy)
  end)

  it("remet aussi l'énergie à Game.TURN_START_ENERGY pile si elle était plus haute (pas un plancher)", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1)
    state.energy = Game.TURN_START_ENERGY + 4 -- ex. gagnée via une carte le tour précédent
    Game.start_turn(state)
    assert.equal(Game.TURN_START_ENERGY, state.energy) -- ne survit pas au changement de tour
  end)
end)

describe("Game.gain_energy", function()
  it("ajoute le montant donné sans jamais plafonner", function()
    local state = Game.new_state()
    state.energy = Game.TURN_START_ENERGY
    Game.gain_energy(state, 5)
    assert.equal(Game.TURN_START_ENERGY + 5, state.energy)
  end)
end)

describe("Game : mana du Mage (2026-08-20, ressource propre au Mage)", function()
  it("Game.reset_run donne 2 mana de départ au Mage, aucune mana (nil) aux 3 autres classes", function()
    local state = Game.new_state()
    Game.reset_run(state)
    for _, h in ipairs(state.heroes) do
      if h.class_id == "mage" then
        assert.equal(2, h.mana)
      else
        assert.is_nil(h.mana)
      end
    end
  end)

  it("Game.resolve_pending dépense la mana ET l'énergie d'une carte 'mana_cost'", function()
    local state = Game.new_state()
    local mage = {
      id = "mage", class_id = "mage", name = "Mage", icon = "", hp = 10, max_hp = 10,
      defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0, mana = 2,
    }
    state.heroes = { mage }
    state.energy = 3
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end, Rng.new(1))
    enemy.hp = 100; enemy.max_hp = 100
    state.enemies = { enemy }

    local def = {
      code = "test-sort-mana", name = "Sort de test", class_id = "mage", tier = "avance", cost = 1, mana_cost = 2,
      cats = {}, dmg_type = "magique", target = "enemy",
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 5, "magique", ctx) end,
    }
    state.hand = { { uid = 1, def = def } }

    -- Game.select_card assigne directement le Mage (propriétaire de la
    -- carte, def.class_id == "mage") -- plus de Game.assign_hero manuel
    -- (2026-08-20, voir describe ci-dessous).
    Game.select_card(state, 1)
    Game.resolve_pending(state, "enemy", enemy.id)

    assert.equal(95, enemy.hp) -- 100 - 5
    assert.equal(2, state.energy) -- 3 - 1 (cost)
    assert.equal(0, mage.mana) -- 2 - 2 (mana_cost)
  end)

  it("Game.select_card refuse une carte 'mana_cost' si la mana du Mage est insuffisante", function()
    local state = Game.new_state()
    local mage = {
      id = "mage", class_id = "mage", name = "Mage", icon = "", hp = 10, max_hp = 10,
      defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0, mana = 1,
    }
    state.heroes = { mage }
    state.energy = 3
    local def = {
      code = "test-sort-mana", name = "Sort de test", class_id = "mage", tier = "avance", cost = 0, mana_cost = 2,
      target = "self", effect = function() end,
    }
    state.hand = { { uid = 1, def = def } }

    Game.select_card(state, 1)

    assert.is_nil(state.pending)
    assert.equal(1, mage.mana) -- inchangée : la carte n'a jamais été jouée
  end)
end)

describe("Game.select_card : assignation automatique au propriétaire (2026-08-20)", function()
  local function make_state_with_heroes()
    local state = Game.new_state()
    state.heroes = {
      { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
        defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
        puissance = 0, saignements = 0 },
      { id = "mage", class_id = "mage", name = "Mage", icon = "", hp = 10, max_hp = 10,
        defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
        puissance = 0, saignements = 0, mana = 2 },
    }
    state.energy = 3
    state.enemies = {}
    return state
  end

  it("assigne directement le héros dont def.class_id correspond", function()
    local state = make_state_with_heroes()
    state.hand = { { uid = 1, def = Cards.by_code("coup-direct-guerrier") } }
    local result = Game.select_card(state, 1)
    assert.equal("assigned", result) -- cible ennemie : en attente, pas encore résolue
    assert.is_not_nil(state.pending)
    assert.equal("guerrier", state.pending.hero_id)
  end)

  it("refuse la sélection si le propriétaire est mort", function()
    local state = make_state_with_heroes()
    Combat.hero_by_id(state, "guerrier").hp = 0
    state.hand = { { uid = 1, def = Cards.by_code("coup-direct-guerrier") } }
    local result = Game.select_card(state, 1)
    assert.equal("refused", result)
    assert.is_nil(state.pending)
  end)

  it("changer de sélection pendant l'attente d'une cible remplace le pending sans rien devoir relâcher côté héros", function()
    local state = make_state_with_heroes()
    state.hand = {
      { uid = 1, def = Cards.by_code("coup-direct-guerrier") }, -- cible ennemie, reste en attente
      { uid = 2, def = Cards.by_code("flameche") },
    }
    Game.select_card(state, 1)
    assert.equal(1, state.pending.uid)

    Game.select_card(state, 2) -- change de sélection sans avoir résolu la 1ère

    assert.equal(2, state.pending.uid)
    assert.equal("mage", state.pending.hero_id)
  end)

  it("recliquer la carte déjà sélectionnée l'annule", function()
    local state = make_state_with_heroes()
    state.hand = { { uid = 1, def = Cards.by_code("coup-direct-guerrier") } }
    Game.select_card(state, 1)
    local result = Game.select_card(state, 1)
    assert.equal("deselected", result)
    assert.is_nil(state.pending)
  end)
end)

describe("Un héros peut agir plusieurs fois par tour (2026-08-20, demande explicite)", function()
  it("le même héros joue 2 cartes de suite dans le même tour, sans passer par une fin de tour", function()
    local state = Game.new_state()
    local hero = {
      id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
      defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0,
    }
    state.heroes = { hero }
    state.energy = 3
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end, Rng.new(1))
    enemy.hp = 100; enemy.max_hp = 100
    state.enemies = { enemy }

    local coup_direct = Cards.by_code("coup-direct-guerrier") -- coût 0, 4 dégâts
    state.hand = { { uid = 1, def = coup_direct }, { uid = 2, def = coup_direct } }

    Game.select_card(state, 1)
    Game.resolve_pending(state, "enemy", enemy.id)
    assert.equal(96, enemy.hp) -- 100 - 4

    -- Deuxième carte, MÊME héros, MÊME tour : plus aucune notion de "a déjà
    -- agi" ne doit bloquer la sélection.
    local result = Game.select_card(state, 2)
    assert.equal("assigned", result)
    assert.equal("guerrier", state.pending.hero_id)
    Game.resolve_pending(state, "enemy", enemy.id)
    assert.equal(92, enemy.hp) -- 96 - 4
    assert.equal(2, #state.discard)
  end)
end)

describe("Discrétion de l'Assassin (2026-08-24, ressource propre, distincte de Camouflé)", function()
  local function make_state_with_assassin(extra_heroes)
    local state = Game.new_state()
    local assassin = {
      id = "assassin", class_id = "assassin", name = "Assassin", icon = "", hp = 12, max_hp = 12,
      defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0, played_card_this_turn = false, discretion = 0,
    }
    state.heroes = { assassin }
    for _, h in ipairs(extra_heroes or {}) do state.heroes[#state.heroes + 1] = h end
    return state, assassin
  end

  it("Game.gain_discretion plafonne à 10 et accorde Camouflé une fois atteint, si un allié non-Camouflé couvre l'Assassin", function()
    local guerrier = { id = "guerrier", class_id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, camoufle = 0 }
    local state, assassin = make_state_with_assassin({ guerrier })
    Game.gain_discretion(state, assassin, 7)
    assert.equal(7, assassin.discretion)
    assert.equal(0, assassin.camoufle)
    Game.gain_discretion(state, assassin, 7) -- 14 -> plafonné à 10
    assert.equal(10, assassin.discretion)
    assert.equal(1, assassin.camoufle)
  end)

  it("un Assassin seul en vie (aucun allié pour le couvrir) ne reste jamais Camouflé, même à 10 Discrétion", function()
    local state, assassin = make_state_with_assassin() -- seul dans state.heroes
    Game.gain_discretion(state, assassin, 10)
    assert.equal(10, assassin.discretion)
    assert.equal(0, assassin.camoufle) -- Game.sync_camoufle_visibility le retire aussitôt : personne à couvrir
  end)

  it("Game.on_card_played donne +1 Discrétion à l'Assassin quand un AUTRE héros joue une carte", function()
    local guerrier = { id = "guerrier", class_id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, camoufle = 0 }
    local state, assassin = make_state_with_assassin({ guerrier })
    Game.on_card_played(state, guerrier)
    assert.equal(1, assassin.discretion)
    assert.is_true(guerrier.played_card_this_turn)
  end)

  it("Game.on_card_played remet la Discrétion de l'Assassin à 0 quand IL joue une carte (pas +1)", function()
    local state, assassin = make_state_with_assassin()
    assassin.discretion = 6
    Game.on_card_played(state, assassin)
    assert.equal(0, assassin.discretion)
  end)

  it("jouer une carte retire Camouflé au héros qui la joue, quel que soit l'effet de la carte", function()
    local guerrier = { id = "guerrier", class_id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, camoufle = 1 }
    local state = Game.new_state()
    state.heroes = { guerrier }
    Game.on_card_played(state, guerrier)
    assert.equal(0, guerrier.camoufle)
  end)

  it("Game.tick_discretion_end_of_turn donne +5 UNIQUEMENT si l'Assassin lui-même n'a joué aucune carte ce tour (2026-08-24, corrigé -- pas par allié inactif)", function()
    local guerrier = { id = "guerrier", class_id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, camoufle = 0, played_card_this_turn = false }
    local state, assassin = make_state_with_assassin({ guerrier })
    assassin.played_card_this_turn = false
    Game.tick_discretion_end_of_turn(state)
    assert.equal(5, assassin.discretion) -- l'inaction du Guerrier n'y est pour rien
  end)

  it("Game.tick_discretion_end_of_turn ne donne rien si l'Assassin A joué une carte ce tour, même si un allié n'a rien fait", function()
    local guerrier = { id = "guerrier", class_id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, camoufle = 0, played_card_this_turn = false }
    local state, assassin = make_state_with_assassin({ guerrier })
    assassin.played_card_this_turn = true
    Game.tick_discretion_end_of_turn(state)
    assert.equal(0, assassin.discretion)
  end)

  -- "Furtif" (2026-08-28, clarification explicite du mot-clé) : une carte
  -- taguée `cats = {"furtif"}` ne fait PAS perdre Discrétion/Camouflé à
  -- l'Assassin qui la joue -- toutes ses 6 cartes le sont désormais (voir
  -- cards.lua), mais Game.on_card_played reste générique sur `def.cats`,
  -- jamais un `if hero.class_id == "assassin"` en dur.
  it("Game.on_card_played ne retire NI Discrétion NI Camouflé sur une carte 'furtif'", function()
    local state, assassin = make_state_with_assassin()
    assassin.discretion = 10
    assassin.camoufle = 1
    Game.on_card_played(state, assassin, { cats = { "furtif" } })
    assert.equal(10, assassin.discretion)
    assert.equal(1, assassin.camoufle)
    assert.is_true(assassin.played_card_this_turn) -- compte quand même comme "avoir agi"
  end)

  it("Game.on_card_played retire bien Discrétion/Camouflé sur une carte SANS 'furtif'", function()
    local state, assassin = make_state_with_assassin()
    assassin.discretion = 10
    assassin.camoufle = 1
    Game.on_card_played(state, assassin, { cats = { "melee", "degats" } })
    assert.equal(0, assassin.discretion)
    assert.equal(0, assassin.camoufle)
  end)

  it("Game.grant_furtif_discard_discretion donne 2 Discrétion par carte 'furtif' restée en main, rien pour les autres", function()
    local state, assassin = make_state_with_assassin()
    local furtif_def = { class_id = "assassin", cats = { "furtif" } }
    local autre_def = { class_id = "assassin", cats = { "melee" } }
    local hand = {
      { uid = 1, def = furtif_def }, { uid = 2, def = furtif_def }, { uid = 3, def = autre_def },
    }
    Game.grant_furtif_discard_discretion(state, hand)
    assert.equal(4, assassin.discretion) -- 2 cartes furtif x 2
  end)
end)

describe("Game.sync_camoufle_visibility (2026-08-24, Camouflé s'enlève dès qu'il ne reste plus d'allié non-Camouflé vivant)", function()
  it("ne touche à rien tant qu'au moins un allié non-Camouflé est vivant", function()
    local assassin = { id = "assassin", name = "Assassin", hp = 12, max_hp = 12, camoufle = 1 }
    local guerrier = { id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, camoufle = 0 }
    local state = { heroes = { assassin, guerrier } }
    Game.sync_camoufle_visibility(state)
    assert.equal(1, assassin.camoufle)
  end)

  it("retire Camouflé à TOUS les héros Camouflés dès que le dernier allié non-Camouflé meurt", function()
    local assassin = { id = "assassin", name = "Assassin", hp = 12, max_hp = 12, camoufle = 1 }
    local guerrier = { id = "guerrier", name = "Guerrier", hp = 0, max_hp = 18, camoufle = 0 } -- vient de mourir
    local state = { heroes = { assassin, guerrier } }
    Game.sync_camoufle_visibility(state)
    assert.equal(0, assassin.camoufle)
  end)

  it("ignore les héros morts, Camouflés ou non, pour la vérification", function()
    local assassin = { id = "assassin", name = "Assassin", hp = 12, max_hp = 12, camoufle = 1 }
    local mort = { id = "h2", name = "h2", hp = 0, max_hp = 18, camoufle = 0 }
    local vivant = { id = "h3", name = "h3", hp = 5, max_hp = 18, camoufle = 0 }
    local state = { heroes = { assassin, mort, vivant } }
    Game.sync_camoufle_visibility(state)
    assert.equal(1, assassin.camoufle) -- "vivant" couvre toujours l'Assassin
  end)
end)

describe("Game.decay_end_of_turn_statuses (bug signalé 2026-08-24 : Vulnérabilité ne décroissait jamais côté héros)", function()
  it("décroît Incapacité ET Vulnérabilité côté héros, pas seulement côté ennemis", function()
    local state = Game.new_state()
    state.heroes = {
      { id = "guerrier", name = "Guerrier", hp = 18, max_hp = 18, incapacite = 1, vulnerabilite = 1 },
    }
    state.enemies = {
      { id = "e1", name = "e1", hp = 10, max_hp = 10, incapacite = 1, vulnerabilite = 1 },
    }
    Game.decay_end_of_turn_statuses(state)
    local hero, enemy = state.heroes[1], state.enemies[1]
    assert.equal(0, hero.incapacite)
    assert.equal(0, hero.vulnerabilite) -- avant ce correctif, restait à 1 indéfiniment
    assert.equal(0, enemy.incapacite)
    assert.equal(0, enemy.vulnerabilite)
  end)
end)

-- Provocation (2026-08-28, statut du Paladin) : décroît via Game.start_turn,
-- pas Game.decay_end_of_turn_statuses (voir son commentaire -- le tirage de
-- cible doit voir la valeur pleine avant la décroissance).
describe("Provocation : décroissance via Game.start_turn (2026-08-28)", function()
  it("décroît de 1 par tour, jamais sous 0", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1)
    state.heroes = { { id = "h1", name = "h1", hp = 18, max_hp = 18, provocation = 2 } }
    state.enemies = {}
    Game.start_turn(state)
    assert.equal(1, state.heroes[1].provocation)
    Game.start_turn(state)
    assert.equal(0, state.heroes[1].provocation)
    Game.start_turn(state)
    assert.equal(0, state.heroes[1].provocation) -- jamais négatif
  end)

  it("ne touche pas un héros mort", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1)
    state.heroes = { { id = "h1", name = "h1", hp = 0, max_hp = 18, provocation = 2 } }
    state.enemies = {}
    Game.start_turn(state)
    assert.equal(2, state.heroes[1].provocation)
  end)
end)

-- Boucliers programmés (2026-08-28, carte "Infranchissable") : voir
-- Game.schedule_shield, consommé par Game.start_turn.
describe("Game.schedule_shield / Game.start_turn : boucliers programmés", function()
  it("accorde le bouclier au bon début de tour, pas avant", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1)
    local hero = { id = "h1", name = "h1", hp = 18, max_hp = 18, defense = 0, scheduled_shields = {} }
    state.heroes = { hero }
    state.enemies = {}
    Game.schedule_shield(hero, 10, 1)
    Game.start_turn(state) -- turns_left 1 -> 0 : accordé CE tour
    assert.equal(10, hero.defense)
    assert.equal(0, #hero.scheduled_shields)
  end)

  it("2 tours programmés (Infranchissable amélioré) : un gain distinct à chaque début de tour", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1)
    local hero = { id = "h1", name = "h1", hp = 18, max_hp = 18, defense = 0, scheduled_shields = {} }
    state.heroes = { hero }
    state.enemies = {}
    Game.schedule_shield(hero, 15, 1)
    Game.schedule_shield(hero, 15, 2)
    Game.start_turn(state) -- 1er programmé accordé, defense reset à 0 juste avant
    assert.equal(15, hero.defense)
    assert.equal(1, #hero.scheduled_shields)
    Game.start_turn(state) -- 2e programmé accordé (defense re-remise à 0 entre-temps)
    assert.equal(15, hero.defense)
    assert.equal(0, #hero.scheduled_shields)
  end)
end)

-- "Amnésie" (2026-08-28, carte Clairvoyance du Paladin) : voir
-- Game.finish_card (routage) et Game.start_next_combat (retour au combat suivant).
describe("Amnésie : Game.finish_card route vers state.exhausted, jamais la défausse", function()
  it("une carte 'amnesie' va dans state.exhausted, pas state.discard", function()
    local state = Game.new_state()
    local amnesie_def = { code = "test-amnesie", cats = { "amnesie" } }
    state.hand = { { uid = 1, def = amnesie_def } }
    state.pending = { uid = 1 }
    Game.finish_card(state, state.pending, { card_def = amnesie_def })
    assert.equal(0, #state.hand)
    assert.equal(0, #state.discard)
    assert.equal(1, #state.exhausted)
    assert.equal("test-amnesie", state.exhausted[1].def.code)
  end)

  it("une carte SANS 'amnesie' va bien en défausse, comme avant", function()
    local state = Game.new_state()
    local normal_def = { code = "test-normal", cats = { "melee" } }
    state.hand = { { uid = 1, def = normal_def } }
    state.pending = { uid = 1 }
    Game.finish_card(state, state.pending, { card_def = normal_def })
    assert.equal(1, #state.discard)
    assert.equal(0, #state.exhausted)
  end)
end)

describe("Flux de jeu : jouer une carte", function()
  it("dépense l'énergie, applique l'effet, et défausse la carte", function()
    local state = Game.new_state()
    local hero = {
      id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
      defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0,
    }
    state.heroes = { hero }
    state.energy = 3 -- réserve globale (2026-08-11) -- assez pour Coup direct (coût 0)
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end, Rng.new(1))
    enemy.hp = 100; enemy.max_hp = 100
    state.enemies = { enemy }

    local coup_direct = Cards.by_code("coup-direct-guerrier") -- coût 0, 4 dégâts
    state.hand = { { uid = 1, def = coup_direct } }

    Game.select_card(state, 1) -- assigne directement le Guerrier (propriétaire de la carte)
    assert.is_not_nil(state.pending)
    assert.equal("guerrier", state.pending.hero_id)
    Game.resolve_pending(state, "enemy", enemy.id)

    assert.equal(96, enemy.hp) -- 100 - 4 (Coup direct, aucun modificateur de classe)
    assert.equal(0, #state.hand)
    assert.equal(1, #state.discard)
    assert.is_nil(state.pending)
  end)
end)

describe("Flux de jeu : fin de tour et résolution ennemie", function()
  it("défausse la main, applique les saignements, résout les ennemis, puis avance le tour", function()
    local state = Game.new_state()
    state.rng = Game.new_rng_streams(1) -- Game.start_turn (plus bas) tire du flux enemy_turn
    state.heroes = {
      { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "", hp = 18, max_hp = 18,
        defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
        puissance = 0, saignements = 0 },
    }
    local enemy = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 1 end, Rng.new(1))
    enemy.hp = 100; enemy.max_hp = 100
    enemy.incapacite = 1; enemy.vulnerabilite = 1 -- pour vérifier leur décroissance en fin de tour
    enemy.next_move = { kind = "dmg", name = "Griffure", icon = "", amount = 5 }
    enemy.target_hero_id = "guerrier"
    state.enemies = { enemy }
    state.hand = { { uid = 1, def = Cards.by_code("coup-direct-guerrier") } }
    state.deck = {}

    local result = Game.end_turn_requested(state)
    assert.is_true(result)
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
  end)
end)

-- Homme Arbre (boss, 2026-08-21, demande explicite) : 3 coups -- tape fort sur
-- un aventurier ("dmg"), attaque tous les aventuriers plus faiblement
-- ("dmg-all", nouveau kind), ramène les Pousses d'Arbre vaincues à la vie
-- ("revive", nouveau kind aussi -- PAS une invocation, revirement explicite du
-- porteur de projet : les 4 Pousses existent dès le début du combat).
describe("Homme Arbre : Onde Sylvestre (dmg-all) touche tous les héros vivants", function()
  local function make_hero(id, hp)
    return {
      id = id, class_id = "guerrier", name = id, icon = "", hp = hp, max_hp = 20,
      defense = 0, esquive = 0, camoufle = 0, incapacite = 0, vulnerabilite = 0,
      puissance = 0, saignements = 0,
    }
  end

  it("inflige le même montant à chaque héros vivant, jamais à un héros déjà mort", function()
    local state = Game.new_state()
    state.heroes = { make_hero("h1", 20), make_hero("h2", 20), make_hero("h3", 0) }
    local boss = Encounter.instantiate_enemy(Enemies.by_id("homme-arbre"), 1, function() return 1 end, Rng.new(1))
    boss.next_move = { kind = "dmg-all", name = "Onde Sylvestre", icon = "", amount = 6 }
    state.enemies = { boss }
    Game.resolve_enemy_action(state, boss)
    assert.equal(14, state.heroes[1].hp)
    assert.equal(14, state.heroes[2].hp)
    assert.equal(0, state.heroes[3].hp)
  end)
end)

describe("Homme Arbre : Renaissance Sylvestre (revive) ramène les Pousses d'Arbre vaincues à la vie", function()
  it("ressuscite à pleine vie chaque Pousse tombée à 0, sans toucher les Pousses vivantes ni les autres ennemis", function()
    local state = Game.new_state()
    state.heroes = {}
    local boss = Encounter.instantiate_enemy(Enemies.by_id("homme-arbre"), 1, function() return 1 end, Rng.new(1))
    local pousse_dead = Encounter.instantiate_enemy(Enemies.by_id("pousse"), 1, function() return 2 end, Rng.new(1))
    pousse_dead.hp = 0
    local pousse_alive = Encounter.instantiate_enemy(Enemies.by_id("pousse"), 1, function() return 3 end, Rng.new(1))
    pousse_alive.hp = 1
    local other_dead = Encounter.instantiate_enemy(Enemies.by_id("gobelin"), 1, function() return 4 end, Rng.new(1))
    other_dead.hp = 0
    boss.next_move = { kind = "revive", name = "Renaissance Sylvestre", icon = "" }
    state.enemies = { boss, pousse_dead, pousse_alive, other_dead }
    Game.resolve_enemy_action(state, boss)
    assert.equal(pousse_dead.max_hp, pousse_dead.hp)
    assert.equal(1, pousse_alive.hp) -- déjà vivante, jamais "soignée" au-delà de son hp actuel
    assert.equal(0, other_dead.hp) -- un autre ennemi mort n'est jamais concerné
  end)

  it("ne fait rien si aucune Pousse n'est vaincue", function()
    local state = Game.new_state()
    state.heroes = {}
    local boss = Encounter.instantiate_enemy(Enemies.by_id("homme-arbre"), 1, function() return 1 end, Rng.new(1))
    local pousse_alive = Encounter.instantiate_enemy(Enemies.by_id("pousse"), 1, function() return 2 end, Rng.new(1))
    boss.next_move = { kind = "revive", name = "Renaissance Sylvestre", icon = "" }
    state.enemies = { boss, pousse_alive }
    Game.resolve_enemy_action(state, boss)
    assert.equal(pousse_alive.max_hp, pousse_alive.hp)
  end)
end)

describe("Homme Arbre : choose_move n'offre Renaissance Sylvestre que si une Pousse est vaincue", function()
  it("ne choisit jamais 'revive' quand toutes les Pousses sont vivantes", function()
    local homme_arbre = Enemies.by_id("homme-arbre")
    local e = { id = "boss", hp = 100, max_hp = 100, level = 1 }
    local all = { e }
    for i = 1, 4 do all[#all + 1] = { id = "pousse" .. i, template_id = "pousse", hp = 6, max_hp = 6 } end
    for seed = 1, 40 do
      local move = homme_arbre.choose_move(e, all, Rng.new(seed))
      assert.is_false(move.kind == "revive")
    end
  end)

  it("peut choisir 'revive' quand au moins une Pousse est vaincue", function()
    local homme_arbre = Enemies.by_id("homme-arbre")
    local e = { id = "boss", hp = 100, max_hp = 100, level = 1 }
    local all = { e, { id = "pousse1", template_id = "pousse", hp = 0, max_hp = 6 } }
    local saw_revive = false
    for seed = 1, 40 do
      local move = homme_arbre.choose_move(e, all, Rng.new(seed))
      if move.kind == "revive" then saw_revive = true break end
    end
    assert.is_true(saw_revive)
  end)
end)

describe("Encounter.boss_encounter : rencontre fixe du boss (2026-08-21)", function()
  it("assemble exactement 1 Homme Arbre + 4 Pousses d'Arbre, tous niveau 1, pleine vie", function()
    local uid = 0
    local instances = Encounter.boss_encounter(function() uid = uid + 1 return uid end, Rng.new(1))
    assert.equal(5, #instances)
    -- Ordre [pousse, pousse, homme-arbre, pousse, pousse] (2026-08-21) : place
    -- l'Homme Arbre au centre de la rangée d'ennemis (View.enemy_rects).
    assert.equal("homme-arbre", instances[3].template_id)
    local pousse_count = 0
    for i, inst in ipairs(instances) do
      if i ~= 3 then
        assert.equal("pousse", inst.template_id)
        pousse_count = pousse_count + 1
      end
    end
    assert.equal(4, pousse_count)
    for _, inst in ipairs(instances) do
      assert.equal(1, inst.level)
      assert.equal(inst.max_hp, inst.hp)
    end
  end)
end)

describe("Encounter.generate_encounter : ne tire jamais le boss (2026-08-21)", function()
  it("aucune rencontre aléatoire ne contient l'Homme Arbre ou une Pousse d'Arbre", function()
    for seed = 1, 30 do
      local instances = Encounter.generate_encounter(Encounter.budget_for_combat(seed), Rng.new(seed))
      for _, inst in ipairs(instances) do
        assert.is_false(inst.template.boss_only == true)
      end
    end
  end)
end)
