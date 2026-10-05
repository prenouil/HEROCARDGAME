-- Écran de fin de combat (Run Infini) : choix d'1 carte parmi 3 à ajouter au deck.
-- Port fidèle de pickDraftCards. Règles : pool = cartes des classes présentes ;
-- probabilité de doublon par slot 100% / 25% / 50% ; jamais deux fois la même carte
-- parmi les 3 propositions ; si le pool de cartes inédites est épuisé, retombe
-- silencieusement sur un doublon. Au plus 1 carte de tier "Départ" parmi les 3
-- (2026-08-27, demande explicite -- "quelles que soient les autres contraintes"),
-- prioritaire sur toutes les règles ci-dessus.

local Cards = require("src.data.cards")

local Draft = {}

Draft.DUP_CHANCES = { 1, 0.25, 0.5 }

local function contains(set, v) return set[v] == true end

-- `state.rng.draft` (2026-08-10, demande explicite -- tirages reproductibles à
-- l'identique pour un run donné) : jamais math.random directement, voir Game.reset_run.
function Draft.pick_cards(state)
  local rng = state.rng.draft
  -- Classes RÉELLEMENT présentes dans CETTE run (2026-08-29, écran de
  -- sélection d'équipe -- avant, `Heroes.defs` listait directement les 4
  -- classes fixes de toute run, ça ne tient plus puisque `Heroes.defs` est
  -- désormais le catalogue des 6 débloqués) : state.heroes reflète toujours
  -- l'équipe réellement choisie, jamais le catalogue complet.
  -- `h.hp == nil or h.hp > 0` (2026-09-28, demande explicite -- pilier du
  -- sacrifice, "les drafts ne doivent pas proposer de cartes d'aventurier
  -- mort") : un héros mort ne rend plus sa classe éligible -- sans cette
  -- garde, un run où un aventurier tombe pouvait continuer à proposer des
  -- cartes toutes neuves de SA classe, injouables dès leur pioche puisque
  -- personne ne reste pour les payer (`Combat.effective_cost`/
  -- `owner_defeated`), et qui ne bénéficieront jamais de la conversion en
  -- Écho (réservée aux cartes déjà possédées AU MOMENT de la mort, voir la
  -- mécanique Écho -- une carte piochée APRÈS coup n'y a jamais droit).
  -- `h.hp == nil` : les fixtures de spec/draft_spec.lua ne posent pas ce
  -- champ (non pertinent pour ce qu'elles testent) -- jamais interprété comme
  -- "mort" faute de valeur, seulement `hp <= 0` explicite l'exclut.
  local present_classes = {}
  for _, h in ipairs(state.heroes) do
    if h.hp == nil or h.hp > 0 then present_classes[h.class_id] = true end
  end

  -- `not def.not_draftable` (2026-09-28, pilier du sacrifice) : les cartes
  -- Legs/Héritage/Écho ne sont JAMAIS proposées au draft -- elles n'existent
  -- qu'en étant déposées directement dans la défausse à la mort d'un héros
  -- (voir Game.process_hero_deaths) ou en convertissant ses cartes restantes.
  -- La carte "Mise à mort" reste, elle, normalement draftable, MAIS jamais
  -- deux fois dans le même run (2026-10-01, demande explicite -- "les cartes
  -- de mise à mort ne peuvent pas apparaître au draft si le joueur en a déjà
  -- sélectionnée une avant pour son deck, même s'il l'a déjà jouée") : une
  -- fois prise, son code rejoint state.run.drafted_mise_a_mort pour de bon
  -- (voir Controller:choose_draft_card) -- même après épuisement (jouée, donc
  -- disparue de toute pile), contrairement à `is_owned` plus bas (qui ne
  -- regarde QUE ce qui est encore possédé maintenant, jamais l'historique).
  local drafted_mise_a_mort = (state.run and state.run.drafted_mise_a_mort) or {}
  -- Statut bloqué/débloqué (2026-10-05, demande explicite -- voir le
  -- commentaire de Cards.is_unlocked_by_default) : une carte "avance"
  -- verrouillée ne doit jamais sortir au draft. La carte "Mise à mort" est
  -- exemptée de cette condition (`def.code:match(...)` ci-dessous) -- elle
  -- reste verrouillée dans la base de données (voir cards.lua), mais sa
  -- propre règle "jamais 2 fois dans le run" juste au-dessus la limite déjà
  -- suffisamment ; ce n'est pas elle que ce nouveau système doit gater.
  local eligible = {}
  for _, def in ipairs(Cards.list) do
    if present_classes[def.class_id] and not def.not_draftable and not drafted_mise_a_mort[def.code]
      and (Cards.is_unlocked_by_default(def) or def.code:match("^mise%-a%-mort%-")) then
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

  -- Chance qu'UNE proposition soit sa version AMÉLIORÉE (2026-09-30, demande
  -- explicite) : 0% au tout premier draft du run (aucun combat encore passé),
  -- +10% par combat déjà passé, SANS plafond (au-delà de 100%, la carte
  -- améliorée est simplement toujours tirée -- `rng:random() < chance` sature
  -- naturellement). `combat_index` n'a pas encore avancé au moment du draft
  -- (voir Controller:advance_to_next_combat, appelé APRÈS -- draft_picks est
  -- déjà posé) : il désigne encore le combat qui vient d'être gagné, donc
  -- `combat_index - 1` = les combats gagnés AVANT celui-ci, exactement ce qui
  -- doit valoir 0 pour le tout premier draft.
  local combats_passed = math.max(0, (state.run and state.run.combat_index or 1) - 1)
  local upgrade_chance = 0.10 * combats_passed

  local used_codes = {}
  local picks = {}
  -- Au plus 1 carte "Départ" parmi les 3 propositions, quelles que soient les
  -- autres contraintes (2026-08-27, demande explicite) : dès qu'une carte
  -- Départ est tirée pour un slot, elle est exclue du pool de TOUS les slots
  -- suivants -- avant même le filtre doublon/inédit ci-dessous, qui ne
  -- s'applique donc plus qu'au sous-ensemble restant.
  local depart_picked = false
  -- Cartes AMÉLIORÉES déjà tirées dans CE draft (2026-09-30, demande explicite
  -- -- "-100% s'il y a déjà une carte améliorée dans le draft") : "-100%",
  -- littéralement -- une VRAIE soustraction de 100 points de pourcentage à la
  -- chance de base, PAS un plafond figé à 1 seule par draft. Avec beaucoup de
  -- combats passés (chance de base > 100%), la chance du slot suivant reste
  -- donc positive après une 1ʳᵉ soustraction -- "il peut donc y avoir
  -- plusieurs cartes améliorées... s'il y a plus de 10 ou même 20 combats"
  -- (confirmé explicitement) : 2 garanties à 20 combats passés (200% - 100% =
  -- 100% restant pour le 2ᵉ slot), 3 à 30. N'affecte jamais le POOL lui-même
  -- (contrairement à Départ) : un slot suivant reste libre de proposer la
  -- MÊME carte en version de base.
  local upgrades_picked = 0

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
    -- Carte améliorée (2026-09-30, demande explicite) : chance de CE slot =
    -- chance de base MOINS 100 points de pourcentage par carte améliorée déjà
    -- tirée plus tôt dans CE MÊME draft (voir upgrades_picked ci-dessus) --
    -- jamais tentée sur une carte non améliorable (`chosen.upgrade` absent --
    -- ex. les cartes du pilier du sacrifice, voir cards.lua) : `Cards.
    -- upgraded_def` planterait sinon (assert). Préserve `code` (voir son
    -- commentaire) : la règle "jamais 2 fois le même code parmi les 3"
    -- ci-dessus reste valable inchangée sur `used_codes` juste en dessous.
    local this_slot_chance = upgrade_chance - upgrades_picked * 1.0
    if chosen.upgrade and this_slot_chance > 0 and rng:random() < this_slot_chance then
      chosen = Cards.upgraded_def(chosen)
      upgrades_picked = upgrades_picked + 1
    end
    picks[#picks + 1] = chosen
    used_codes[chosen.code] = true
    if chosen.tier == "depart" then depart_picked = true end
  end

  return picks
end

return Draft
