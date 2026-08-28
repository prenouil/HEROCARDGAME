-- Deck, main et défausse : mélange, pioche, remélange à vide.
-- Port fidèle de shuffle/buildStartingDeck/drawCards/fillHand.

local Cards = require("src.data.cards")
local Combat = require("src.rules.combat")

local Deck = {}

Deck.HAND_SIZE = 5

--- Les 3 cartes "depart" d'une classe donnée (2026-08-29, remplace la table
-- figée `Deck.STARTING_DECK_CODES` -- écran de sélection d'équipe : la
-- composition d'une run varie désormais selon les 4 héros choisis parmi les
-- 6 `Heroes.defs`, un deck de départ figé à 4 classes fixes n'a plus de sens).
-- Dérivée directement de `Cards.list` (class_id + tier == "depart") -- chaque
-- classe en a toujours exactement 3 (convention établie, voir le commentaire
-- en tête de src/data/cards.lua), jamais une 2ᵉ source de vérité à tenir
-- synchronisée avec les cartes elles-mêmes.
function Deck.starting_cards_for_class(class_id)
  local out = {}
  for _, def in ipairs(Cards.list) do
    if def.class_id == class_id and def.tier == "depart" then out[#out + 1] = def end
  end
  return out
end

-- `rng` (2026-08-10, demande explicite -- ordre du deck reproductible à l'identique
-- pour un run donné) : instance de src/util/rng.lua, jamais math.random directement
-- -- voir Game.reset_run pour la création du flux (state.rng.deck).
function Deck.shuffle(arr, rng)
  local a = {}
  for i, v in ipairs(arr) do a[i] = v end
  for i = #a, 2, -1 do
    local j = rng:random(i)
    a[i], a[j] = a[j], a[i]
  end
  return a
end

--- `class_ids` (2026-08-29, liste des class_id des héros sélectionnés pour
-- cette run, ex. {"guerrier","mage","necromancien","barde"}) : 1 exemplaire
-- de chacune des 3 cartes "depart" de CHAQUE classe listée -- remplace
-- l'ancienne liste figée à 4 classes (voir Deck.starting_cards_for_class).
function Deck.build_starting_deck(class_ids, uid_gen, rng)
  local cards = {}
  for _, class_id in ipairs(class_ids) do
    for _, def in ipairs(Deck.starting_cards_for_class(class_id)) do
      cards[#cards + 1] = { uid = uid_gen(), def = def }
    end
  end
  return Deck.shuffle(cards, rng)
end

-- Pioche jusqu'à n cartes (ou jusqu'à HAND_SIZE si la main est pleine, cf. n == HAND_SIZE
-- dans l'original) ; remélange la défausse dans le deck s'il est vide et qu'il reste des
-- cartes à défausser. Retourne la liste des uids piochés, dans l'ordre.
function Deck.draw_cards(state, n)
  local drawn = {}
  local reshuffled_at = nil
  for _ = 1, n do
    if #state.hand >= Deck.HAND_SIZE and n == Deck.HAND_SIZE then break end
    if #state.deck == 0 then
      if #state.discard == 0 then break end
      state.deck = Deck.shuffle(state.discard, state.rng.deck)
      state.discard = {}
      -- `#drawn` cartes déjà piochées AVANT ce remélange (2026-08-21, demande
      -- explicite) : la UI (Controller:consume_drawn_animation) en a besoin pour
      -- couper l'animation de vol en 2 -- avant/après -- avec le remélange
      -- défausse -> pioche joué entre les deux, plutôt qu'un seul vol qui
      -- ferait apparaître les cartes d'après-remélange comme si elles
      -- venaient d'un deck resté plein. Un seul point de coupure retenu (le
      -- premier) : avec 12-24 cartes au total dans ce jeu, un deuxième
      -- remélange au sein d'une même pioche n'arrive jamais en pratique.
      reshuffled_at = reshuffled_at or #drawn
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
  state.last_draw_reshuffled_at = reshuffled_at
  return drawn
end

function Deck.fill_hand(state)
  local drawn = {}
  local reshuffled_at = nil
  while #state.hand < Deck.HAND_SIZE do
    if #state.deck == 0 then
      if #state.discard == 0 then break end
      state.deck = Deck.shuffle(state.discard, state.rng.deck)
      state.discard = {}
      reshuffled_at = reshuffled_at or #drawn -- voir le commentaire équivalent dans Deck.draw_cards
      Combat.log(state, "Le deck est vide : la défausse est remélangée.", "sys")
    end
    local c = table.remove(state.deck)
    state.hand[#state.hand + 1] = c
    drawn[#drawn + 1] = c.uid
  end
  state.last_drawn_uids = drawn
  state.last_draw_reshuffled_at = reshuffled_at
  return drawn
end

return Deck
