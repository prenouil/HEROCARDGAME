-- Moteur de combat pur : dégâts, défense/soin, ciblage, éligibilité de coût.
-- Ne dépend d'aucune API LÖVE — testable seul via busted.
-- Port fidèle de dealDamage/grantDefense/grantHeal/enemyTargeting/effectiveCost/
-- requiredCost depuis proto-cartes-completes/index.html. `state` est toujours
-- passé explicitement (pas de globale mutable), pour rester testable en isolation.

local Glossary = require("src.data.glossary")

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

--- Inflige des dégâts, avec tous les modificateurs de Transcendance/statuts.
-- source_hero: hero table ou nil (attaque ennemie / dégâts sans source).
-- target_unit: hero ou enemy table (les deux partagent hp/defense/incapacite/vulnerabilite).
-- ctx: {state, hero, target, card_def} ou nil — nécessaire pour les bonus liés au texte de la carte jouée.
-- opts: { brut = bool } — brut ignore la Défense.
function Combat.deal_damage(state, source_hero, target_unit, base, dmg_type, ctx, opts)
  opts = opts or {}
  local amount = base

  -- Transcendance Guerrier : +50% sur toute carte "epee" jouée PAR le Guerrier,
  -- quelle que soit sa classe d'origine (Coup direct générique, Blessure ouverte
  -- de l'Assassin, etc.) — pas seulement les cartes de la classe Guerrier.
  if ctx and source_hero and source_hero.class_id == "guerrier" and Glossary.has_keyword(ctx.card_def.desc, "epee") then
    amount = amount * 1.5
  end
  if source_hero and (source_hero.puissance or 0) > 0 and dmg_type == "physique" then
    amount = amount * (1 + 0.25 * source_hero.puissance) -- Puissance (Assassin, via Concentration)
  end
  if (target_unit.incapacite or 0) > 0 and not source_hero then
    amount = amount * 0.75 -- Incapacité n'est jamais posée que sur des ennemis dans ce jeu de cartes
  end
  if source_hero and (source_hero.incapacite or 0) > 0 then
    amount = amount * 0.75
  end
  if (target_unit.vulnerabilite or 0) > 0 then
    amount = amount * 1.25
  end
  amount = round(amount)

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
    if ctx and ctx.card_def and ctx.card_def.cats then
      for _, cat in ipairs(ctx.card_def.cats) do
        if cat == "feu" then target_unit.took_fire_damage_this_turn = true end
      end
    end
  end

  -- Transcendance Assassin : toute carte "epee" jouée PAR l'Assassin inflige
  -- Incapacité 1 + Vulnérabilité 1, même principe que le Guerrier ci-dessus.
  if ctx and source_hero and source_hero.class_id == "assassin" and Glossary.has_keyword(ctx.card_def.desc, "epee") and target_unit.hp > 0 then
    target_unit.incapacite = (target_unit.incapacite or 0) + 1
    target_unit.vulnerabilite = (target_unit.vulnerabilite or 0) + 1
    Combat.log(state, "Transcendance de l'Assassin : Incapacité 1 et Vulnérabilité 1 sur " .. target_unit.name .. ".", "power")
  end

  return shook
end

-- Transcendance Paladin : +50% sur toute carte "bouclier"/"soin" jouée PAR le
-- Paladin, quelle que soit sa classe d'origine (Encaisser générique, Stratégie
-- de l'Assassin, etc.) — même principe que Guerrier/Assassin ci-dessus.
function Combat.grant_defense(target_unit, base, ctx)
  local amount = base
  if ctx and ctx.hero.class_id == "paladin" and Glossary.has_keyword(ctx.card_def.desc, "bouclier") then
    amount = amount * 1.5
  end
  amount = round(amount)
  target_unit.defense = (target_unit.defense or 0) + amount
  return amount
end

function Combat.grant_heal(target_unit, base, ctx)
  local amount = base
  if ctx and ctx.hero.class_id == "paladin" and Glossary.has_keyword(ctx.card_def.desc, "soin") then
    amount = amount * 1.5
  end
  amount = round(amount)
  target_unit.hp = math.min(target_unit.max_hp, target_unit.hp + amount)
  return amount
end

-- Transcendance Mage : -2 sur tout sort joué PAR le Mage, quelle que soit sa
-- classe d'origine (pas seulement les sorts de la classe Mage).
function Combat.effective_cost(hero, def)
  local cost = def.cost
  if hero.class_id == "mage" then
    for _, cat in ipairs(def.cats) do
      if cat == "sort" then cost = math.max(0, cost - 2) break end
    end
  end
  return cost
end

-- La Concentration ne paie jamais le coût imprimé : c'est l'action de secours
-- quand on n'a pas assez d'énergie pour jouer la carte normalement.
function Combat.required_cost(hero, pending)
  if not pending then return 0 end
  if pending.mode == "concentrate" then return 0 end
  return Combat.effective_cost(hero, pending.def)
end

-- Éligibilité "Jouer" pour un héros donné, avant même que `pending.mode` ne
-- soit choisi -- utilisé par les boutons d'action par héros (2026-08-08).
function Combat.can_play(hero, pending)
  if not pending or hero.hp <= 0 or hero.has_acted then return false end
  if hero.energy < Combat.effective_cost(hero, pending.def) then return false end
  if pending.def.requires_camouflage and not hero.camoufle then return false end
  return true
end

-- Éligibilité "Se concentrer" : jamais de coût, seule la condition d'avoir
-- déjà agi ce tour (ou être mort) désactive le bouton.
function Combat.can_concentrate(hero)
  return hero.hp > 0 and not hero.has_acted
end

return Combat
