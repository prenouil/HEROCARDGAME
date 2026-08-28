-- Écran "La Forge" (Run Infini, 2026-08-28, demande explicite -- remplace
-- l'ancien écran "feuDeCamp" qui mélangeait soin et amélioration, voir
-- src/ui/controller.lua pour le nouveau séquencement Forge/Temple). Le joueur
-- améliore 1 carte de son choix parmi 4 tirées au hasard dans tout son deck
-- (jamais une carte déjà améliorée) -- s'intercale entre le draft et le combat
-- suivant, sans jamais avancer le budget de difficulté. Ne fait aucune
-- dépendance LÖVE (module pur, comme feu_de_camp.lua avant lui) -- voir
-- src/ui/controller.lua pour le séquencement/l'animation.

local Cards = require("src.data.cards")

local Forge = {}

-- Jusqu'à 4 choix proposés (2026-08-28, demande explicite) : moins si le deck
-- n'a pas assez de cartes encore améliorables, jusqu'à 0 -- l'écran affiche
-- alors "Toutes vos cartes sont déjà améliorées." côté UI (voir view.lua).
Forge.CHOICE_COUNT = 4

--- Toutes les instances de carte encore améliorables (deck + main + défausse --
-- vides entre deux combats en pratique, balayés par précaution/testabilité) :
-- exclut toute instance déjà "+" (Cards.upgraded_def) -- jamais une deuxième
-- amélioration.
function Forge.upgradable_instances(state)
  local out = {}
  local function scan(pile)
    for _, c in ipairs(pile) do
      if not c.def.is_upgraded then out[#out + 1] = c end
    end
  end
  scan(state.deck)
  scan(state.hand)
  scan(state.discard)
  return out
end

--- Tire jusqu'à Forge.CHOICE_COUNT instances DISTINCTES à proposer, sans remise
-- -- une liste plus courte (jusqu'à vide) si le deck n'a pas assez de cartes
-- améliorables ; jamais un filet de sécurité qui retomberait sur une carte déjà
-- vue ou déjà améliorée (contrairement à l'ancien Draft.pick_cards, cet écran
-- n'a pas besoin de remplir coûte que coûte 4 cases).
function Forge.pick_choices(state, rng)
  local pool = Forge.upgradable_instances(state)
  local n = math.min(Forge.CHOICE_COUNT, #pool)
  local chosen = {}
  for _ = 1, n do
    local idx = rng:random(#pool)
    chosen[#chosen + 1] = table.remove(pool, idx)
  end
  return chosen
end

--- Remplace le def de l'instance choisie par sa version améliorée -- l'uid ne
-- change pas (voir Cards.upgraded_def) : la carte reste la MÊME instance dans
-- le deck, juste passée à sa version "+".
function Forge.apply_upgrade(instance)
  instance.def = Cards.upgraded_def(instance.def)
end

return Forge
