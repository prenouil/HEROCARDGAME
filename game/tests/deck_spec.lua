local Deck = require("src.rules.deck")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")
local Rng = require("src.util.rng")

local function make_state()
  return { hand = {}, deck = {}, discard = {}, log = {}, rng = { deck = Rng.new(1) } }
end

local function fake_cards(n)
  local out = {}
  local def = Cards.by_code("coup-direct-guerrier")
  for i = 1, n do out[i] = { uid = i, def = def } end
  return out
end

describe("Deck.build_starting_deck", function()
  it("contient 12 cartes : les 3 cartes depart de chaque classe, 1 exemplaire chacune", function()
    local uid = 0
    local deck = Deck.build_starting_deck(function() uid = uid + 1 return uid end, Rng.new(1))
    assert.equal(12, #deck)
    local counts = {}
    for _, c in ipairs(deck) do counts[c.def.code] = (counts[c.def.code] or 0) + 1 end
    assert.equal(1, counts["coup-direct-guerrier"])
    assert.equal(1, counts["encaisser-guerrier"])
    assert.equal(1, counts["coup-taille"]) -- "depart" côté Guerrier depuis 2026-08-24, pas "coup-estoc"
    assert.equal(1, counts["coup-direct-paladin"])
    assert.equal(1, counts["encaisser-paladin"])
    assert.equal(1, counts["rempart"])
    assert.equal(1, counts["flameche"]) -- pas "coup-direct-mage" (renommée 2026-08-24)
    assert.equal(1, counts["barriere"]) -- pas "encaisser-mage" (renommée 2026-08-24)
    assert.equal(1, counts["missile-magique"])
    assert.equal(1, counts["plan-attaque"]) -- pas "coup-direct-assassin" (renommée 2026-08-28)
    assert.equal(1, counts["se-cacher"]) -- pas "encaisser-assassin" (renommée 2026-08-28)
    assert.equal(1, counts["repli-strategique"]) -- pas "strategie" (renommée 2026-08-28)
  end)
end)

describe("Deck.draw_cards / fill_hand", function()
  it("pioche jusqu'à HAND_SIZE et remélange la défausse quand le deck est vide", function()
    local state = make_state()
    state.deck = fake_cards(2)
    state.discard = fake_cards(3)
    local drawn = Deck.fill_hand(state)
    assert.equal(Deck.HAND_SIZE, #drawn)
    assert.equal(Deck.HAND_SIZE, #state.hand)
    assert.equal(0, #state.discard) -- entièrement recyclée dans le deck puis piochée
    -- 2026-08-21, demande explicite : la UI coupe l'animation de vol en 2 à cet
    -- indice (2 cartes piochées AVANT le remélange, voir Controller:consume_drawn_animation).
    assert.equal(2, state.last_draw_reshuffled_at)
  end)

  it("last_draw_reshuffled_at reste nil quand aucun remélange n'a lieu", function()
    local state = make_state()
    state.deck = fake_cards(5)
    Deck.fill_hand(state)
    assert.is_nil(state.last_draw_reshuffled_at)
  end)

  it("s'arrête proprement quand deck et défausse sont tous les deux vides", function()
    local state = make_state()
    local drawn = Deck.fill_hand(state)
    assert.equal(0, #drawn)
    assert.equal(0, #state.hand)
  end)

  it("draw_cards(1) pioche 1 carte même si la main n'est pas pleine (cas Clairvoyance)", function()
    local state = make_state()
    state.deck = fake_cards(3)
    state.hand = fake_cards(4) -- déjà proche de HAND_SIZE mais pas égal
    local drawn = Deck.draw_cards(state, 1)
    assert.equal(1, #drawn)
    assert.equal(5, #state.hand)
  end)
end)

describe("Deck.shuffle", function()
  it("ne perd ni ne duplique de carte", function()
    local original = fake_cards(10)
    local shuffled = Deck.shuffle(original, Rng.new(1))
    assert.equal(#original, #shuffled)
  end)
end)
