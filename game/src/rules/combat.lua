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

--- Multiplicateur total de dégâts pour un coup donné : Puissance/Incapacité de
-- l'unité qui frappe, Vulnérabilité de l'unité qui encaisse, et le bonus de
-- Transcendance Guerrier le cas échéant. TOUS les pourcentages sont additionnés
-- D'ABORD puis appliqués une seule fois -- jamais composés en chaîne (8 dégâts
-- +50% et +25% => +75% => 14, PAS 8×1.5×1.25=15 -- règle explicite du porteur
-- de projet, 2026-08-09). Pure, aucun effet de bord -- réutilisée telle quelle
-- par Combat.deal_damage (résolution réelle) et par l'aperçu au survol
-- (voir view.lua), pour que les deux ne puissent jamais diverger.
-- `source_unit` : hero OU enemy table (les deux partagent puissance/incapacite) --
-- PAS forcément le `source_hero` passé à deal_damage, voir opts.source_unit
-- ci-dessous (une attaque ennemie n'a pas de source_hero, mais l'ennemi qui
-- frappe doit quand même voir SA PROPRE Incapacité réduire SES dégâts).
function Combat.damage_multiplier(source_unit, target_unit, dmg_type, guerrier_epee_bonus)
  local pct = 0
  if guerrier_epee_bonus then pct = pct + 0.5 end
  if source_unit and (source_unit.puissance or 0) > 0 and dmg_type == "physique" then
    pct = pct + 0.25 * source_unit.puissance -- Puissance (Assassin, via Concentration) : par stack
  end
  if source_unit and (source_unit.incapacite or 0) > 0 then
    pct = pct - 0.25 -- Incapacité : -25% flat, peu importe le nombre de stacks (comme Vulnérabilité)
  end
  if target_unit and (target_unit.vulnerabilite or 0) > 0 then
    pct = pct + 0.25 -- Vulnérabilité : +25% flat
  end
  return 1 + pct
end

--- Inflige des dégâts, avec tous les modificateurs de Transcendance/statuts.
-- source_hero: hero table ou nil (attaque ennemie / dégâts sans source) --
-- conditionne aussi le texte/la couleur du log, ne PAS renommer en "source_unit"
-- partout pour autant (voir opts.source_unit).
-- target_unit: hero ou enemy table (les deux partagent hp/defense/incapacite/vulnerabilite).
-- ctx: {state, hero, target, card_def} ou nil — nécessaire pour les bonus liés au texte de la carte jouée.
-- opts: { brut = bool, source_unit = unit } — brut ignore la Défense ; source_unit
-- (optionnel) précise QUI porte Puissance/Incapacité pour le calcul du multiplicateur
-- quand ce n'est pas source_hero (une attaque ennemie passe l'ennemi qui frappe ici,
-- sans changer source_hero=nil et donc sans changer le texte/la couleur du log).
function Combat.deal_damage(state, source_hero, target_unit, base, dmg_type, ctx, opts)
  opts = opts or {}
  local source_unit = opts.source_unit or source_hero

  -- Transcendance Guerrier : +50% sur toute carte "epee" jouée PAR le Guerrier,
  -- quelle que soit sa classe d'origine (Coup direct générique, Blessure ouverte
  -- de l'Assassin, etc.) — pas seulement les cartes de la classe Guerrier.
  local guerrier_epee_bonus = ctx and source_hero and source_hero.class_id == "guerrier" and Glossary.has_keyword(ctx.card_def.desc, "epee")
  local amount = round(base * Combat.damage_multiplier(source_unit, target_unit, dmg_type, guerrier_epee_bonus))

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

-- Transcendance Assassin : double la quantité de tout statut empilable (esquive,
-- saignements, incapacite, vulnerabilite, camoufle, puissance) qu'il applique --
-- à lui-même ou à sa cible, quelle que soit la classe d'origine de la carte
-- jouée -- même principe que Guerrier/Paladin/Mage ci-dessus. Seule porte
-- d'entrée pour poser un statut depuis un effet de carte : ne jamais écrire
-- `unit.champ = (unit.champ or 0) + n` directement dans cards.lua.
function Combat.apply_status(ctx, unit, field, amount)
  local mult = (ctx and ctx.hero and ctx.hero.class_id == "assassin") and 2 or 1
  local applied = amount * mult
  unit[field] = (unit[field] or 0) + applied
  return applied
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
  if pending.def.requires_camouflage and (hero.camoufle or 0) <= 0 then return false end
  return true
end

-- Éligibilité "Se concentrer" : jamais de coût, seule la condition d'avoir
-- déjà agi ce tour (ou être mort) désactive le bouton.
function Combat.can_concentrate(hero)
  return hero.hp > 0 and not hero.has_acted
end

return Combat
