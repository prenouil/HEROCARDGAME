-- Écran "feuDeCamp" (Run Infini, entre le draft de fin de combat et le combat
-- suivant, 2026-08-10, demande explicite du porteur de projet) : le joueur
-- choisit soit de soigner/ressusciter l'aventurier le plus blessé (100% des PV,
-- quel que soit l'état de départ), soit d'améliorer 2 cartes tirées au hasard
-- dans tout son deck. Ne fait jamais avancer le budget de difficulté -- s'intercale
-- de façon transparente entre le draft et Game.start_next_combat, voir
-- src/ui/controller.lua pour le séquencement/l'animation (jamais ici, module pur,
-- aucune dépendance LÖVE).

local Cards = require("src.data.cards")

local FeuDeCamp = {}

-- Le soin ne rend qu'une fraction des PV max (2026-08-11, revu à la baisse --
-- ne rendait que 100% jusqu'ici, changement explicite du porteur de projet),
-- y compris pour ressusciter un mort : jamais un plein soin.
FeuDeCamp.HEAL_FRACTION = 0.5

local function round(x) return math.floor(x + 0.5) end

--- Pourcentage de "blessure" d'un héros -- 1 (100%) pour un mort, toujours
-- prioritaire sur un vivant amoché (confirmé par Zgrubulu, 2026-08-10) -- 0
-- pour un héros à pleine vie.
local function wounded_pct(h)
  if h.hp <= 0 then return 1 end
  return 1 - (h.hp / h.max_hp)
end

--- Héros le plus blessé (mort = 100%, toujours prioritaire), ou nil si
-- personne n'est blessé -- l'option "soin" est alors grisée côté UI. Égalité
-- départagée par `rng` (state.rng.feu_de_camp).
function FeuDeCamp.most_wounded_hero(state, rng)
  local best_pct, candidates = 0, {}
  for _, h in ipairs(state.heroes) do
    local pct = wounded_pct(h)
    if pct > 0 then
      if pct > best_pct then
        best_pct = pct
        candidates = { h }
      elseif pct == best_pct then
        candidates[#candidates + 1] = h
      end
    end
  end
  if #candidates == 0 then return nil end
  if #candidates == 1 then return candidates[1] end
  return candidates[rng:random(#candidates)]
end

--- Montant rendu par le soin : HEAL_FRACTION des PV max, arrondi -- jamais un
-- plein soin (confirmé par Zgrubulu, 2026-08-11).
function FeuDeCamp.heal_amount(hero)
  return round(hero.max_hp * FeuDeCamp.HEAL_FRACTION)
end

--- Soigne/ressuscite `hero` de HEAL_FRACTION de ses PV max, quel que soit son
-- état de départ -- un mort (PV négatifs compris) revient toujours à la vie
-- avec ce même montant, jamais plus (confirmé par Zgrubulu, 2026-08-11 :
-- "même quand il ressuscite"). `math.max(0, hero.hp)` avant d'ajouter :
-- repart d'un plancher à 0, pas d'un négatif profond, sinon un mort à -15 PV
-- pourrait ne pas repasser au-dessus de 0 avec un soin partiel. Plafonné à
-- max_hp comme n'importe quel soin. PAS Combat.grant_heal (bonus Transcendance
-- Paladin compris) : ce n'est pas l'effet d'une carte jouée en combat.
function FeuDeCamp.heal_hero(hero)
  hero.hp = math.min(hero.max_hp, math.max(0, hero.hp) + FeuDeCamp.heal_amount(hero))
end

--- Toutes les instances de carte encore améliorables (deck + main + défausse --
-- vides entre deux combats en pratique, balayés par précaution/testabilité) :
-- exclut toute instance déjà "+" (Cards.upgraded_def) -- jamais une deuxième
-- amélioration (confirmé par Zgrubulu, 2026-08-10).
function FeuDeCamp.upgradable_instances(state)
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

--- Tire 2 instances DISTINCTES à améliorer parmi tout le deck (doublons d'une
-- même carte compris), sans remise -- ou nil si moins de 2 sont disponibles
-- (l'option "amélioration" est alors grisée côté UI).
function FeuDeCamp.pick_upgrade_targets(state, rng)
  local pool = FeuDeCamp.upgradable_instances(state)
  if #pool < 2 then return nil end
  local first = table.remove(pool, rng:random(#pool))
  local second = pool[rng:random(#pool)]
  return { first, second }
end

--- Remplace le def de chaque instance donnée par sa version améliorée --
-- l'uid ne change pas (voir Cards.upgraded_def) : la carte reste la MÊME
-- instance dans le deck, juste passée à sa version "+".
function FeuDeCamp.apply_upgrades(targets)
  for _, instance in ipairs(targets) do
    instance.def = Cards.upgraded_def(instance.def)
  end
end

return FeuDeCamp
