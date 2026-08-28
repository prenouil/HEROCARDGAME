-- Écran de fin de combat (Run Infini) : choix d'1 carte parmi 3 à ajouter au deck.
-- Port fidèle de pickDraftCards. Règles : pool = cartes des classes présentes ;
-- probabilité de doublon par slot 100% / 25% / 50% ; jamais deux fois la même carte
-- parmi les 3 propositions ; si le pool de cartes inédites est épuisé, retombe
-- silencieusement sur un doublon. Au plus 1 carte de tier "Départ" parmi les 3
-- (2026-08-27, demande explicite -- "quelles que soient les autres contraintes"),
-- prioritaire sur toutes les règles ci-dessus.

local Cards = require("src.data.cards")
local Heroes = require("src.data.heroes")

local Draft = {}

Draft.DUP_CHANCES = { 1, 0.25, 0.5 }

local function contains(set, v) return set[v] == true end

-- `state.rng.draft` (2026-08-10, demande explicite -- tirages reproductibles à
-- l'identique pour un run donné) : jamais math.random directement, voir Game.reset_run.
function Draft.pick_cards(state)
  local rng = state.rng.draft
  local present_classes = {}
  for _, h in ipairs(Heroes.defs) do present_classes[h.class_id] = true end

  local eligible = {}
  for _, def in ipairs(Cards.list) do
    if present_classes[def.class_id] then
      eligible[#eligible + 1] = def
    end
  end

  local owned_codes = {}
  local function mark_owned(pile)
    for _, c in ipairs(pile) do owned_codes[c.def.code] = true end
  end
  mark_owned(state.deck)
  mark_owned(state.hand)
  mark_owned(state.discard)

  local function is_owned(def) return contains(owned_codes, def.code) end

  local used_codes = {}
  local picks = {}
  -- Au plus 1 carte "Départ" parmi les 3 propositions, quelles que soient les
  -- autres contraintes (2026-08-27, demande explicite) : dès qu'une carte
  -- Départ est tirée pour un slot, elle est exclue du pool de TOUS les slots
  -- suivants -- avant même le filtre doublon/inédit ci-dessous, qui ne
  -- s'applique donc plus qu'au sous-ensemble restant.
  local depart_picked = false

  for _, chance in ipairs(Draft.DUP_CHANCES) do
    local function depart_ok(d) return not (depart_picked and d.tier == "depart") end

    local pool = {}
    for _, d in ipairs(eligible) do
      if not contains(used_codes, d.code) and depart_ok(d) then pool[#pool + 1] = d end
    end
    if #pool == 0 then
      -- Filet de sécurité si le pool éligible (moins les cartes déjà tirées
      -- pour ce draft) est vide : retombe sur tout l'éligible -- mais la
      -- règle "au plus 1 carte Départ" reste inviolable ("quelles que soient
      -- les autres contraintes"), seul le filtre doublon/inédit cède ici.
      for _, d in ipairs(eligible) do
        if depart_ok(d) then pool[#pool + 1] = d end
      end
    end
    if #pool == 0 then
      -- Dernier recours absolu (ne devrait jamais arriver avec le pool de
      -- cartes actuel) : même la règle Départ cède plutôt que de ne proposer
      -- aucune carte pour ce slot.
      pool = eligible
    end

    local dup_pool, new_pool = {}, {}
    for _, d in ipairs(pool) do
      if is_owned(d) then dup_pool[#dup_pool + 1] = d else new_pool[#new_pool + 1] = d end
    end

    local chosen
    if rng:random() < chance and #dup_pool > 0 then
      chosen = dup_pool[rng:random(#dup_pool)]
    elseif #new_pool > 0 then
      chosen = new_pool[rng:random(#new_pool)]
    elseif #dup_pool > 0 then
      chosen = dup_pool[rng:random(#dup_pool)]
    else
      chosen = pool[rng:random(#pool)]
    end
    picks[#picks + 1] = chosen
    used_codes[chosen.code] = true
    if chosen.tier == "depart" then depart_picked = true end
  end

  return picks
end

return Draft
