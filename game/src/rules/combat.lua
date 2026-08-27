-- Moteur de combat pur : dégâts, défense/soin, ciblage. Ne dépend d'aucune API
-- LÖVE — testable seul via busted. Port fidèle de dealDamage/grantDefense/
-- grantHeal/enemyTargeting depuis proto-cartes-completes/index.html. `state`
-- est toujours passé explicitement (pas de globale mutable), pour rester
-- testable en isolation.

local Combat = {}

Combat.TARGETABLE_MOVE_KINDS = { dmg = true, debuff = true, ["conditional-retaliate"] = true }

local function round(x) return math.floor(x + 0.5) end
Combat.round = round

function Combat.living_heroes(state)
  local out = {}
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 then out[#out + 1] = h end
  end
  return out
end

function Combat.living_enemies(state)
  local out = {}
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 then out[#out + 1] = e end
  end
  return out
end

function Combat.hero_by_id(state, id)
  for _, h in ipairs(state.heroes) do
    if h.id == id then return h end
  end
  return nil
end

function Combat.enemy_by_id(state, id)
  for _, e in ipairs(state.enemies) do
    if e.id == id then return e end
  end
  return nil
end

-- L'ennemi (s'il y en a un) dont l'action télégraphiée cible ce héros, parmi les
-- moves "ciblables" (dmg/debuff/conditional-retaliate).
function Combat.enemy_targeting(state, hero)
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 and e.next_move and Combat.TARGETABLE_MOVE_KINDS[e.next_move.kind] and e.target_hero_id == hero.id then
      return e
    end
  end
  return nil
end

-- log est une table simple {text=, cls=} accumulée dans state.log ; la UI la lit,
-- les règles ne touchent jamais l'affichage directement.
function Combat.log(state, text, cls)
  state.log[#state.log + 1] = { text = text, cls = cls }
end

--- Multiplicateur total de dégâts pour un coup donné : Puissance/Incapacité de
-- l'unité qui frappe, Vulnérabilité de l'unité qui encaisse. TOUS les
-- pourcentages sont additionnés D'ABORD puis appliqués une seule fois --
-- jamais composés en chaîne (8 dégâts +50% et +25% => +75% => 14, PAS
-- 8×1.5×1.25=15 -- règle explicite du porteur de projet, 2026-08-09). Pure,
-- aucun effet de bord -- réutilisée telle quelle par Combat.deal_damage
-- (résolution réelle) et par l'aperçu au survol (voir view.lua), pour que les
-- deux ne puissent jamais diverger.
-- `source_unit` : hero OU enemy table (les deux partagent puissance/incapacite) --
-- PAS forcément le `source_hero` passé à deal_damage, voir opts.source_unit
-- ci-dessous (une attaque ennemie n'a pas de source_hero, mais l'ennemi qui
-- frappe doit quand même voir SA PROPRE Incapacité réduire SES dégâts).
-- `is_fire` (optionnel, 2026-08-24, demande explicite) : vrai si LE COUP porte
-- le tag "feu" (carte dont `cats` contient "feu", voir deal_damage) -- pas le
-- même signal que `dmg_type` (une carte "feu" peut être dmg_type "magique" OU
-- "physique", voir Main de feu côté cards.lua). Seule cible connue à ce jour :
-- l'Homme Arbre, identifié par template_id (même convention que la Régénération
-- du Troll un peu plus bas dans game.lua).
function Combat.damage_multiplier(source_unit, target_unit, dmg_type, is_fire)
  local pct = 0
  if source_unit and (source_unit.puissance or 0) > 0 and dmg_type == "physique" then
    pct = pct + 0.25 * source_unit.puissance -- Puissance (Assassin, via Assassinat/Dans les ombres) : par stack
  end
  if source_unit and (source_unit.incapacite or 0) > 0 then
    pct = pct - 0.25 -- Incapacité : -25% flat, peu importe le nombre de stacks (comme Vulnérabilité)
  end
  if target_unit and (target_unit.vulnerabilite or 0) > 0 then
    pct = pct + 0.25 -- Vulnérabilité : +25% flat
  end
  if is_fire and target_unit and target_unit.template_id == "homme-arbre" then
    pct = pct + 0.5 -- Sensibilité au feu de l'Homme Arbre (2026-08-24, demande explicite) : +50% flat
  end
  return 1 + pct
end

--- Inflige des dégâts, avec tous les modificateurs de statuts.
-- source_hero: hero table ou nil (attaque ennemie / dégâts sans source) --
-- conditionne aussi le texte/la couleur du log, ne PAS renommer en "source_unit"
-- partout pour autant (voir opts.source_unit).
-- target_unit: hero ou enemy table (les deux partagent hp/defense/incapacite/vulnerabilite).
-- ctx: {state, hero, target, card_def} ou nil — sert à détecter les dégâts de
-- feu (`card_def.cats` contient "feu") : marque la cible pour la Régénération
-- du Troll (voir plus bas) ET alimente la sensibilité au feu de l'Homme Arbre
-- via Combat.damage_multiplier ci-dessus (2026-08-24).
-- opts: { brut = bool, source_unit = unit } — brut ignore la Défense ; source_unit
-- (optionnel) précise QUI porte Puissance/Incapacité pour le calcul du multiplicateur
-- quand ce n'est pas source_hero (une attaque ennemie passe l'ennemi qui frappe ici,
-- sans changer source_hero=nil et donc sans changer le texte/la couleur du log).
function Combat.deal_damage(state, source_hero, target_unit, base, dmg_type, ctx, opts)
  opts = opts or {}
  local source_unit = opts.source_unit or source_hero
  local is_fire = false
  if ctx and ctx.card_def and ctx.card_def.cats then
    for _, cat in ipairs(ctx.card_def.cats) do
      if cat == "feu" then is_fire = true break end
    end
  end
  local amount = round(base * Combat.damage_multiplier(source_unit, target_unit, dmg_type, is_fire))

  local absorbed = 0
  if not opts.brut then
    absorbed = math.min(target_unit.defense or 0, amount)
    if absorbed > 0 then target_unit.defense = target_unit.defense - absorbed end
  end
  local to_hp = amount - absorbed
  target_unit.hp = target_unit.hp - to_hp

  Combat.log(state,
    (source_hero and source_hero.name or "Un ennemi") .. " inflige " .. amount .. " dégâts"
      .. (opts.brut and " brut" or "") .. (absorbed > 0 and (" (" .. absorbed .. " absorbés)") or "")
      .. " à " .. target_unit.name .. ".",
    source_hero and "you" or "foe")

  local shook = to_hp > 0

  -- Run Infini : marque l'ennemi comme touché ce tour (Golem) / touché par du feu ce tour (Troll).
  local is_enemy_target = false
  for _, e in ipairs(state.enemies) do
    if e == target_unit then is_enemy_target = true break end
  end
  if source_hero and is_enemy_target then
    target_unit.took_damage_this_turn = true
    if is_fire then target_unit.took_fire_damage_this_turn = true end
  end

  return shook
end

function Combat.grant_defense(target_unit, base)
  local amount = round(base)
  target_unit.defense = (target_unit.defense or 0) + amount
  return amount
end

function Combat.grant_heal(target_unit, base)
  local amount = round(base)
  target_unit.hp = math.min(target_unit.max_hp, target_unit.hp + amount)
  return amount
end

-- Seule porte d'entrée pour poser un statut depuis un effet de carte : ne
-- jamais écrire `unit.champ = (unit.champ or 0) + n` directement dans cards.lua.
function Combat.apply_status(unit, field, amount)
  unit[field] = (unit[field] or 0) + amount
  return amount
end

-- Éligibilité "Jouer" pour un héros donné -- utilisé par Game.select_card
-- (2026-08-08 ; un héros peut désormais agir plusieurs fois par tour,
-- 2026-08-20, demande explicite -- plus de check "a déjà agi"). Le coût se
-- paie sur la réserve d'énergie GLOBALE (2026-08-11, remplace l'énergie
-- individuelle par héros) -- d'où `state` en premier paramètre, même
-- convention que le reste du module. `mana_cost` (2026-08-20, optionnel,
-- ressource propre au Mage -- voir hero.mana dans game.lua) se vérifie EN
-- PLUS de l'énergie, jamais à sa place : une carte peut demander énergie ET
-- mana. Les héros hors Mage ont `mana == nil`, donc `(hero.mana or 0)` vaut 0
-- et toute carte avec un mana_cost > 0 leur est automatiquement inaccessible,
-- sans case spéciale par classe ici.
function Combat.can_play(state, hero, pending)
  if not pending or hero.hp <= 0 then return false end
  if state.energy < pending.def.cost then return false end
  if pending.def.mana_cost and (hero.mana or 0) < pending.def.mana_cost then return false end
  if pending.def.requires_camouflage and (hero.camoufle or 0) <= 0 then return false end
  return true
end

return Combat
