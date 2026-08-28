-- Deck, main et défausse : mélange, pioche, remélange à vide.
-- Port fidèle de shuffle/buildStartingDeck/drawCards/fillHand.

local Cards = require("src.data.cards")
local Combat = require("src.rules.combat")

local Deck = {}

Deck.HAND_SIZE = 5

-- Run Infini : deck de départ à 12 cartes (2026-08-11, plus de cartes
-- génériques -- les 3 cartes "depart" de chaque classe, 1 exemplaire chacune :
-- son "Coup direct", son "Encaisser", et sa carte "depart" propre). Guerrier :
-- "coup-taille" (pas "coup-estoc", devenu "avance", 2026-08-24 -- voir
-- cards.lua). Mage : "flameche"/"barriere" (renommées, pas
-- "coup-direct-mage"/"encaisser-mage"). Assassin (2026-08-28, refonte
-- complète) : "plan-attaque"/"se-cacher"/"repli-strategique" (renommées,
-- pas "coup-direct-assassin"/"encaisser-assassin"/"strategie").
Deck.STARTING_DECK_CODES = {
  { "coup-direct-guerrier", 1 }, { "encaisser-guerrier", 1 }, { "coup-taille", 1 },
  { "coup-direct-paladin", 1 }, { "encaisser-paladin", 1 }, { "rempart", 1 },
  { "flameche", 1 }, { "barriere", 1 }, { "missile-magique", 1 },
  { "plan-attaque", 1 }, { "se-cacher", 1 }, { "repli-strategique", 1 },
}

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

function Deck.build_starting_deck(uid_gen, rng)
  local cards = {}
  for _, entry in ipairs(Deck.STARTING_DECK_CODES) do
    local code, n = entry[1], entry[2]
    local def = Cards.by_code(code)
    for _ = 1, n do
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
