-- Deck : mélange déterministe, pioche, composition du deck de départ
-- (game/src/rules/deck.lua) -- 2026-09-10, suite de la couverture Busted.
-- Module pur (aucune dépendance LÖVE), déjà conçu pour être appelé isolément.

local Deck = require("src.rules.deck")
local Rng = require("src.util.rng")
local Combat = require("src.rules.combat")

describe("Deck.starting_cards_for_class", function()
  it("renvoie exactement les 3 cartes 'depart' de la classe demandée", function()
    local cards = Deck.starting_cards_for_class("guerrier")
    assert.are.equal(3, #cards)
    for _, def in ipairs(cards) do
      assert.are.equal("guerrier", def.class_id)
      assert.are.equal("depart", def.tier)
    end
  end)

  it("une classe qui n'existe pas renvoie une liste vide, jamais une erreur", function()
    assert.are.same({}, Deck.starting_cards_for_class("inexistante"))
  end)
end)

describe("Deck.shuffle", function()
  it("est une pure permutation : même longueur, mêmes éléments, jamais de perte/duplication", function()
    local arr = { "a", "b", "c", "d", "e" }
    local shuffled = Deck.shuffle(arr, Rng.new(1))
    assert.are.equal(#arr, #shuffled)
    local counts = {}
    for _, v in ipairs(shuffled) do counts[v] = (counts[v] or 0) + 1 end
    for _, v in ipairs(arr) do assert.are.equal(1, counts[v]) end
  end)

  it("ne mute jamais le tableau d'origine", function()
    local arr = { "a", "b", "c" }
    Deck.shuffle(arr, Rng.new(1))
    assert.are.same({ "a", "b", "c" }, arr)
  end)

  it("même seed => même ordre, à chaque fois (reproductibilité d'un run)", function()
    local arr = { "a", "b", "c", "d", "e", "f", "g", "h" }
    local s1 = Deck.shuffle(arr, Rng.new(42))
    local s2 = Deck.shuffle(arr, Rng.new(42))
    assert.are.same(s1, s2)
  end)
end)

describe("Deck.build_starting_deck", function()
  it("réunit 1 exemplaire de chaque carte 'depart' de chaque classe listée, mélangés", function()
    local uid = 0
    local function next_uid() uid = uid + 1; return uid end
    local deck = Deck.build_starting_deck({ "guerrier", "mage" }, next_uid, Rng.new(1))
    assert.are.equal(6, #deck) -- 3 + 3
    local class_counts = {}
    for _, c in ipairs(deck) do
      class_counts[c.def.class_id] = (class_counts[c.def.class_id] or 0) + 1
      assert.is_not_nil(c.uid)
    end
    assert.are.equal(3, class_counts.guerrier)
    assert.are.equal(3, class_counts.mage)
  end)
end)

describe("Deck.draw_cards", function()
  local function make_state(deck_size, discard_size)
    local state = { deck = {}, hand = {}, discard = {}, log = {}, rng = { deck = Rng.new(1) } }
    for i = 1, deck_size do state.deck[i] = { uid = "deck" .. i, def = {} } end
    for i = 1, discard_size do state.discard[i] = { uid = "discard" .. i, def = {} } end
    return state
  end

  it("pioche depuis le DESSUS du deck (fin du tableau), déplace vers la main", function()
    local state = make_state(3, 0)
    local top_uid = state.deck[#state.deck].uid
    local drawn = Deck.draw_cards(state, 1)
    assert.are.equal(1, #drawn)
    assert.are.equal(top_uid, drawn[1])
    assert.are.equal(2, #state.deck)
    assert.are.equal(1, #state.hand)
    assert.are.equal(top_uid, state.hand[1].uid)
  end)

  it("remélange la défausse dans le deck quand celui-ci est vide, en logge l'évènement", function()
    local state = make_state(0, 3)
    local drawn = Deck.draw_cards(state, 2)
    assert.are.equal(2, #drawn)
    assert.are.equal(0, #state.discard) -- vidée dans le deck
    assert.are.equal(1, #state.deck) -- 3 remélangées - 2 piochées
    assert.are.equal("sys", state.log[#state.log].cls)
  end)

  it("s'arrête sans erreur si deck ET défausse sont vides", function()
    local state = make_state(0, 0)
    local drawn = Deck.draw_cards(state, 3)
    assert.are.equal(0, #drawn)
  end)

  it("n == HAND_SIZE et main déjà pleine : s'arrête immédiatement (cas pioche de début de tour)", function()
    local state = make_state(5, 0)
    for i = 1, Deck.HAND_SIZE do state.hand[i] = { uid = "hand" .. i, def = {} } end
    local drawn = Deck.draw_cards(state, Deck.HAND_SIZE)
    assert.are.equal(0, #drawn)
    assert.are.equal(5, #state.deck) -- rien pioché
  end)

  it("expose last_drawn_uids/last_draw_reshuffled_at pour l'animation de la UI", function()
    local state = make_state(1, 2)
    local drawn = Deck.draw_cards(state, 2) -- 1 avant remélange, puis remélange, puis 1 après
    assert.are.equal(2, #drawn)
    assert.are.same(drawn, state.last_drawn_uids)
    assert.are.equal(1, state.last_draw_reshuffled_at) -- 1 carte piochée AVANT le remélange
  end)
end)

describe("Deck.fill_hand", function()
  it("pioche jusqu'à HAND_SIZE exactement", function()
    local state = { deck = {}, hand = {}, discard = {}, log = {}, rng = { deck = Rng.new(1) } }
    for i = 1, 10 do state.deck[i] = { uid = "deck" .. i, def = {} } end
    Deck.fill_hand(state)
    assert.are.equal(Deck.HAND_SIZE, #state.hand)
    assert.are.equal(10 - Deck.HAND_SIZE, #state.deck)
  end)

  it("s'arrête sous HAND_SIZE si plus rien à piocher nulle part", function()
    local state = { deck = {}, hand = {}, discard = {}, log = {}, rng = { deck = Rng.new(1) } }
    state.deck = { { uid = "d1", def = {} } }
    Deck.fill_hand(state)
    assert.are.equal(1, #state.hand)
  end)
end)
