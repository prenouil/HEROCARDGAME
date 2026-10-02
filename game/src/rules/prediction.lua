-- Évènement "Prédiction de la Mort" (Run Infini, 2026-10-03, demande
-- explicite) : présente les 4 aventuriers comme Le Temple, mais au lieu de
-- statues d'effet, la carte "Mise à mort" de chaque aventurier VIVANT
-- (grisée/non interactive si déjà prise au draft -- même règle que
-- Draft.pick_cards, voir son commentaire sur state.run.drafted_mise_a_mort).
-- Rien pour un aventurier déjà mort. Le joueur choisit UNE carte pour
-- l'ajouter à son deck -- ou "Sacrifier un pouvoir à la place" (ouvre la même
-- fenêtre/le même mécanisme que "Le Puit de l'Oubli", voir game.lua/
-- Controller:open_power_well_picker).

local Cards = require("src.data.cards")

local Prediction = {}

--- La carte "Mise à mort" de `class_id`, s'il en existe une -- même recherche
-- que other_advance_cards_for_class (controller.lua), dupliquée ici pour
-- rester un module pur sans dépendance vers l'UI.
local function mise_a_mort_for_class(class_id)
  for _, def in ipairs(Cards.list) do
    if def.class_id == class_id and def.code:match("^mise%-a%-mort%-") then return def end
  end
end

--- Carte éligible par héros VIVANT (2026-10-03) : `out[hero.id] = def` --
-- absent (pas `out[hero.id] = nil`, littéralement pas de clé) pour un héros
-- mort OU dont la carte "Mise à mort" est déjà dans
-- `state.run.drafted_mise_a_mort` (prise au draft normal OU ici-même, voir
-- Controller:choose_prediction_card -- même bookkeeping que le draft, jamais
-- une 2ᵉ source de vérité).
function Prediction.eligible_cards(state)
  local drafted = (state.run and state.run.drafted_mise_a_mort) or {}
  local out = {}
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 then
      local def = mise_a_mort_for_class(h.class_id)
      if def and not drafted[def.code] then out[h.id] = def end
    end
  end
  return out
end

--- Viable seulement s'il reste AU MOINS 2 aventuriers vivants ET qu'au moins
-- 1 carte "Mise à mort" est éligible, "même règle que pour le draft"
-- (2026-10-03, demande explicite) -- sous 2 vivants, ou si toutes les cartes
-- "Mise à mort" restantes sont déjà prises, cet évènement ne doit jamais
-- apparaître (voir Controller:enter_post_combat_camp_choice, qui appelle
-- cette fonction avant de le compter parmi les candidats).
function Prediction.viable(state)
  local living = 0
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 then living = living + 1 end
  end
  if living < 2 then return false end
  return next(Prediction.eligible_cards(state)) ~= nil
end

return Prediction
