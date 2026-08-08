-- Deck, main et défausse : mélange, pioche, remélange à vide.
-- Port fidèle de shuffle/buildStartingDeck/drawCards/fillHand.

local Cards = require("src.data.cards")
local Combat = require("src.rules.combat")

local Deck = {}

Deck.HAND_SIZE = 5

-- Run Infini : deck de départ à 10 cartes (3 Coup direct, 3 Encaisser, 1 carte
-- Départ par classe).
Deck.STARTING_DECK_CODES = {
  { "coup-direct", 3 }, { "encaisser", 3 }, { "coup-estoc", 1 }, { "rempart", 1 }, { "missile-magique", 1 }, { "strategie", 1 },
}

function Deck.shuffle(arr)
  local a = {}
  for i, v in ipairs(arr) do a[i] = v end
  for i = #a, 2, -1 do
    local j = math.random(i)
    a[i], a[j] = a[j], a[i]
  end
  return a
end

function Deck.build_starting_deck(uid_gen)
  local cards = {}
  for _, entry in ipairs(Deck.STARTING_DECK_CODES) do
    local code, n = entry[1], entry[2]
    local def = Cards.by_code(code)
    for _ = 1, n do
      cards[#cards + 1] = { uid = uid_gen(), def = def }
    end
  end
  return Deck.shuffle(cards)
end

-- Pioche jusqu'à n cartes (ou jusqu'à HAND_SIZE si la main est pleine, cf. n == HAND_SIZE
-- dans l'original) ; remélange la défausse dans le deck s'il est vide et qu'il reste des
-- cartes à défausser. Retourne la liste des uids piochés, dans l'ordre.
function Deck.draw_cards(state, n)
  local drawn = {}
  for _ = 1, n do
    if #state.hand >= Deck.HAND_SIZE and n == Deck.HAND_SIZE then break end
    if #state.deck == 0 then
      if #state.discard == 0 then break end
      state.deck = Deck.shuffle(state.discard)
      state.discard = {}
      Combat.log(state, "Le deck est vide : la défausse est remélangée.", "sys")
    end
    local c = table.remove(state.deck) -- .pop() : la fin du tableau est le dessus du deck
    state.hand[#state.hand + 1] = c
    drawn[#drawn + 1] = c.uid
  end
  -- Rangé sur `state` (pas seulement retourné) : Clairvoyance appelle draw_cards
  -- directement depuis un effet de carte (src/data/cards.lua) sans relayer la
  -- valeur de retour -- la UI (controller.lua) lit ce champ après coup pour
  -- savoir quoi animer, quel que soit le chemin d'appel.
  state.last_drawn_uids = drawn
  return drawn
end

function Deck.fill_hand(state)
  local drawn = {}
  while #state.hand < Deck.HAND_SIZE do
    if #state.deck == 0 then
      if #state.discard == 0 then break end
      state.deck = Deck.shuffle(state.discard)
      state.discard = {}
      Combat.log(state, "Le deck est vide : la défausse est remélangée.", "sys")
    end
    local c = table.remove(state.deck)
    state.hand[#state.hand + 1] = c
    drawn[#drawn + 1] = c.uid
  end
  state.last_drawn_uids = drawn
  return drawn
end

return Deck
