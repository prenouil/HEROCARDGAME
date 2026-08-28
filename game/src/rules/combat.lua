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

--- Coût réel en énergie de `def` pour CE héros précis (2026-08-29, malédiction
-- "Le Corrompu" -- hero.card_cost_delta, un champ simple copié depuis
-- Temple.effects par Game.apply_combat_start_temple_effects, jamais une
-- connaissance directe de Temple ici, même principe que hero.discretion
-- ailleurs) : def.cost + l'éventuel surcoût. Seule source de vérité sur
-- "combien ça coûte VRAIMENT" -- Combat.can_play, Game.resolve_pending
-- (déduction) et l'affichage en main (draw_hand, view.lua) doivent tous
-- passer par elle, jamais lire def.cost brut pour un coût vérifié/affiché.
function Combat.effective_cost(hero, def)
  return def.cost + ((hero and hero.card_cost_delta) or 0)
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

--- Inspiration (2026-08-29, statut GÉNÉRIQUE du Barde -- hero.inspiration,
-- n'importe quel héros peut le porter, voir game.lua) : +6 FLAT au premier
-- effet de dégâts/soin/bouclier que `ctx.hero` déclenche en jouant SA carte,
-- consommé une seule fois par carte jouée (jamais par coup si la carte touche
-- plusieurs cibles, ex. "Coup de taille") -- le garde-fou est `ctx` lui-même :
-- la MÊME table est partagée par tous les appels à Combat.deal_damage/
-- grant_heal/grant_defense au sein d'un seul def.effect(ctx), donc marquer
-- `ctx.inspiration_consumed` dessus bloque tout appel suivant. `ctx` vaut nil
-- pour les dégâts qui NE viennent PAS d'une carte jouée (attaque ennemie,
-- épines, saignement...) -- Inspiration ne s'applique alors jamais, par
-- construction plutôt que par un check explicite en plus.
local function consume_inspiration(amount, ctx)
  if ctx and ctx.hero and (ctx.hero.inspiration or 0) > 0 and not ctx.inspiration_consumed then
    ctx.inspiration_consumed = true
    ctx.hero.inspiration = ctx.hero.inspiration - 1
    return amount + 6
  end
  return amount
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
    pct = pct + 0.25 * source_unit.puissance -- Puissance (Assassin, via Assassinat/En traître) : par stack
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
  amount = consume_inspiration(amount, ctx)

  local absorbed = 0
  if not opts.brut then
    absorbed = math.min(target_unit.defense or 0, amount)
    if absorbed > 0 then target_unit.defense = target_unit.defense - absorbed end
  end
  local to_hp = amount - absorbed
  target_unit.hp = target_unit.hp - to_hp

  -- "La Renaissante" (2026-08-29, bénédiction -- hero.death_ward, un simple
  -- booléen copié depuis Temple.effects par
  -- Game.apply_combat_start_temple_effects, jamais une connaissance directe
  -- de Temple ici) : au lieu de mourir, reste debout à 1 PV -- consommé
  -- (remis à false) au premier déclenchement, jamais réutilisable dans le
  -- même combat. Game.tick_bleed a son propre appel équivalent (le
  -- saignement ne passe pas par cette fonction) -- même logique dupliquée là,
  -- volontairement, plutôt qu'un détour par ce module pour 3 lignes.
  if target_unit.hp <= 0 and target_unit.death_ward then
    target_unit.hp = 1
    target_unit.death_ward = false
    Combat.log(state, target_unit.name .. " aurait dû mourir, mais reste debout à 1 PV !", "power")
  end

  Combat.log(state,
    (source_hero and source_hero.name or "Un ennemi") .. " inflige " .. amount .. " dégâts"
      .. (opts.brut and " brut" or "") .. (absorbed > 0 and (" (" .. absorbed .. " absorbés)") or "")
      .. " à " .. target_unit.name .. ".",
    source_hero and "you" or "foe")

  local shook = to_hp > 0

  -- Discrétion perdue en encaissant des dégâts (2026-08-28, demande explicite --
  -- s'ajoute aux 2 autres resets déjà en place, jouer une carte et fin de tour
  -- sans agir, voir Game.on_card_played/Game.tick_discretion_end_of_turn dans
  -- game.lua) : générique sur `target_unit.discretion` plutôt que sur
  -- class_id == "assassin" (même idiome que ces deux fonctions -- seul
  -- l'Assassin porte ce champ, voir Game.fresh_hero) pour ne pas coupler ce
  -- module générique de dégâts à une classe précise. Ne se déclenche que sur
  -- une VRAIE perte de PV (to_hp > 0, pas juste "touché" -- un coup entièrement
  -- absorbé par le Bouclier ne compromet pas la discrétion) et seulement s'il y
  -- avait quelque chose à perdre, pour ne jamais spammer le log en pure perte.
  if to_hp > 0 and target_unit.discretion ~= nil
      and ((target_unit.discretion or 0) > 0 or (target_unit.camoufle or 0) > 0) then
    target_unit.discretion = 0
    target_unit.camoufle = 0
    Combat.log(state, target_unit.name .. " perd sa Discrétion en encaissant des dégâts.", "foe")
  end

  -- Corruption (2026-08-29, ressource propre au Nécromancien -- hero.corruption) :
  -- +1 par VRAIE perte de PV (to_hp > 0), quelle qu'en soit la source --
  -- dégâts ennemis OU auto-infligés par ses propres cartes (Sceau de
  -- faiblesse/Pacte funeste, voir cards.lua, toutes deux réutilisent CETTE
  -- fonction pour leur propre coût en PV plutôt qu'une mutation directe de
  -- `hp`) -- même idiome générique que la perte de Discrétion juste au-dessus.
  if to_hp > 0 and target_unit.corruption ~= nil then
    target_unit.corruption = target_unit.corruption + to_hp
  end

  -- "Le Rancunier" (2026-08-29, bénédiction -- hero.thorns) : renvoie ce
  -- montant à l'attaquant à chaque VRAIE perte de PV -- `source_unit` porte le
  -- VRAI frappeur même pour une attaque ennemie (voir sa doc plus haut, jamais
  -- `source_hero` seul, toujours nil côté ennemi). `brut = true` : les épines
  -- transpercent, jamais absorbées par un bouclier. Garde `source_unit ~=
  -- target_unit` : jamais de retour sur soi-même (ex. Riposte, qui frappe déjà
  -- l'attaquant directement -- source_unit y est nil, cette carte reste hors
  -- de portée du garde-fou par construction).
  if to_hp > 0 and target_unit.thorns and source_unit and source_unit ~= target_unit and source_unit.hp > 0 then
    Combat.deal_damage(state, nil, source_unit, target_unit.thorns, nil, nil, { brut = true, source_unit = target_unit })
    Combat.log(state, target_unit.name .. " renvoie " .. target_unit.thorns .. " dégâts à " .. source_unit.name .. ".", "you")
  end

  -- Run Infini : marque l'ennemi comme touché ce tour (Golem) / touché par du feu ce tour (Troll).
  local is_enemy_target = false
  for _, e in ipairs(state.enemies) do
    if e == target_unit then is_enemy_target = true break end
  end
  if source_hero and is_enemy_target then
    target_unit.took_damage_this_turn = true
    if is_fire then target_unit.took_fire_damage_this_turn = true end
  end

  -- "Le Blessé" (2026-08-29, malédiction -- hero.self_damage_on_hit) :
  -- l'aventurier maudit se blesse lui-même à chaque attaque qui inflige
  -- RÉELLEMENT des dégâts à un ennemi (jamais sur un allié touché par erreur,
  -- jamais sur un coup entièrement paré). `source_hero` (pas source_unit) :
  -- seul un héros qui joue une carte peut porter cette malédiction.
  if to_hp > 0 and is_enemy_target and source_hero and source_hero.self_damage_on_hit and source_hero.hp > 0 then
    Combat.deal_damage(state, nil, source_hero, source_hero.self_damage_on_hit, nil, nil, { brut = true })
    Combat.log(state, source_hero.name .. " se blesse en attaquant (Le Blessé).", "foe")
  end

  return shook
end

--- `ctx` (optionnel, 2026-08-29, Inspiration -- voir consume_inspiration
-- ci-dessus) : à passer par TOUT effet de carte qui accorde du bouclier,
-- pour que l'Inspiration du lanceur (`ctx.hero`) puisse s'y appliquer -- même
-- convention que le `ctx` déjà passé à Combat.deal_damage. Omis (nil), comme
-- pour tout gain de bouclier hors carte (bouclier programmé, début de tour...) :
-- aucun bonus, jamais d'erreur.
function Combat.grant_defense(target_unit, base, ctx)
  local amount = round(consume_inspiration(base, ctx))
  target_unit.defense = (target_unit.defense or 0) + amount
  return amount
end

--- `ctx` (optionnel) : même convention que Combat.grant_defense ci-dessus.
function Combat.grant_heal(target_unit, base, ctx)
  local amount = round(consume_inspiration(base, ctx))
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
  if state.energy < Combat.effective_cost(hero, pending.def) then return false end
  if pending.def.mana_cost and (hero.mana or 0) < pending.def.mana_cost then return false end
  if pending.def.requires_camouflage and (hero.camoufle or 0) <= 0 then return false end
  return true
end

return Combat
