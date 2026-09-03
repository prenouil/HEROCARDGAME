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
-- Gratuite (2026-09-02, statut GÉNÉRIQUE -- "Bis" du Barde, hero.gratuite) :
-- tant que > 0, le coût réel tombe à 0 pour TOUTE carte de ce héros (avant
-- même card_cost_delta, qui n'a alors plus d'effet visible) -- décompté de 1
-- à chaque carte jouée par Game.on_card_played, jamais en fin de tour.
function Combat.effective_cost(hero, def)
  if hero and (hero.gratuite or 0) > 0 then return 0 end
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
    -- "Tournée finale" (2026-09-03, Enchantement du Barde -- hero.tournee_finale) :
    -- CHAQUE fois qu'un allié consomme une charge d'Inspiration (pas
    -- seulement la dernière) il gagne du bouclier -- cherche le Barde parmi
    -- l'équipe via `ctx.state` (1 seul par équipe, peut être `ctx.hero`
    -- lui-même si le Barde consomme SA PROPRE Inspiration -- aucun cas
    -- particulier nécessaire, la boucle le retrouve comme n'importe quel
    -- autre porteur). `ctx.state` absent (gain de bouclier/soin/dégâts hors
    -- carte) : l'effet ne se déclenche simplement pas.
    if ctx.state then
      for _, h in ipairs(ctx.state.heroes) do
        if h.tournee_finale and h.hp > 0 then
          Combat.grant_defense(ctx.hero, h.tournee_finale, ctx)
          Combat.log(ctx.state, ctx.hero.name .. " (Tournée finale) gagne " .. h.tournee_finale .. " bouclier.", "you")
          break
        end
      end
    end
    return amount + 6
  end
  return amount
end

--- Incandescence (2026-09-02, revirement explicite -- "plutôt que +25% de
-- dégâts, donne +X aux dégâts, X étant la valeur d'Incandescence actuelle...
-- les bonus flat comme incandescence s'additionnent avant tout
-- multiplicateur") : additif comme Inspiration ci-dessus (même étage du
-- calcul, voir Combat.deal_damage), PAS multiplicatif comme Puissance (donc
-- SORTIE de Combat.damage_multiplier, où elle vivait avant ce correctif).
-- Contrairement à consume_inspiration, jamais consommée -- elle ne redescend
-- jamais (voir Game.decay_end_of_turn_statuses) -- donc pure, pas de `ctx` :
-- réutilisable telle quelle par Combat.deal_damage ET par l'aperçu au survol
-- (view.lua), sans le détour que nécessite Inspiration (effet de bord).
function Combat.incandescence_flat(source_unit, dmg_type)
  if dmg_type == "physique" and source_unit and (source_unit.incandescence or 0) > 0 then
    return source_unit.incandescence
  end
  return 0
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
-- "Vol" de l'Aigle Géant (2026-08-30, demande explicite -- "Vol : les dégâts
-- de Type 'épée' sont réduits à 0"). "Type épée" == `dmg_type == "physique"`
-- (2026-08-30) : le glossaire n'a aucune notion mécanique distincte entre
-- épée/dague/etc, le mot-clé "epee" affiché sur les cartes est purement
-- cosmétique -- Guerrier ET Assassin l'utilisent tous les deux pour leurs
-- dégâts "physique" -- voir cards.lua. La magie (Mage/Nécromancien) reste
-- pleinement efficace pendant que l'Aigle vole. Prédicat partagé (au lieu
-- d'un court-circuit isolé dans damage_multiplier) pour que Combat.deal_damage
-- puisse aussi l'appliquer en toute fin de calcul (2026-08-30, préférence
-- explicite -- "quelles que soient les calculs intermédiaires, le résultat
-- sera 0", pour nullifier même une addition future qui interviendrait après
-- le multiplicateur).
function Combat.is_immune_physical(target_unit, dmg_type)
  return target_unit ~= nil and (target_unit.vol or 0) > 0 and dmg_type == "physique"
end

function Combat.damage_multiplier(source_unit, target_unit, dmg_type, is_fire)
  if Combat.is_immune_physical(target_unit, dmg_type) then
    return 0
  end
  local pct = 0
  if source_unit and (source_unit.puissance or 0) > 0 and dmg_type == "physique" then
    pct = pct + 0.25 * source_unit.puissance -- Puissance (Assassin, via Assassinat/En traître) : par stack
  end
  -- Frénésie (2026-09-03, Enchantement du Guerrier) : `frenesie_bonus_pct` est
  -- déjà le pourcentage total résolu (0.5/0.75 par carte Offensive déjà jouée
  -- CE TOUR, voir Game.on_card_played/Game.start_turn) -- pas un compteur de
  -- stacks à multiplier ici comme Puissance ci-dessus, le pas peut différer
  -- entre base (0.5) et amélioré (0.75).
  if source_unit and (source_unit.frenesie_bonus_pct or 0) > 0 and dmg_type == "physique" then
    pct = pct + source_unit.frenesie_bonus_pct
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
  -- Additif AVANT multiplicatif (2026-08-30, demande explicite -- "les bonus
  -- en addition, comme l'inspiration, doivent être appliqués AVANT les bonus
  -- en multiplication, comme la vulnérabilité") : Inspiration (+6 flat) et
  -- Incandescence (+X flat, 2026-09-02, même règle réaffirmée explicitement)
  -- grossissent d'abord `base`, la Vulnérabilité/Puissance/Incapacité (toutes
  -- multiplicatives, voir Combat.damage_multiplier) s'appliquent ENSUITE sur
  -- ce total -- l'ordre inverse (avant ce correctif) laissait le bonus flat
  -- d'Inspiration hors de portée du multiplicateur. Même ordre repris côté
  -- aperçu (voir preview_desc, view.lua), pour ne jamais diverger.
  local amount = consume_inspiration(base, ctx) + Combat.incandescence_flat(source_unit, dmg_type)
  amount = round(amount * Combat.damage_multiplier(source_unit, target_unit, dmg_type, is_fire))
  -- Filet de sécurité final pour "Vol" (2026-08-30) : la mise à 0 vit déjà
  -- dans Combat.damage_multiplier (pour que l'aperçu de dégâts affiche 0 lui
  -- aussi, voir preview_desc dans view.lua), mais on la réaffirme ici en dur
  -- sur `amount`, tout calcul intermédiaire fait, pour garantir qu'aucun
  -- bonus additif ne puisse jamais survivre au blocage de "Vol".
  if Combat.is_immune_physical(target_unit, dmg_type) then
    amount = 0
  end

  local absorbed = 0
  if not opts.brut then
    absorbed = math.min(target_unit.defense or 0, amount)
    if absorbed > 0 then target_unit.defense = target_unit.defense - absorbed end
  end
  local to_hp = amount - absorbed
  target_unit.hp = target_unit.hp - to_hp

  -- "Bouclier de pointes" (2026-09-03, Enchantement du Paladin -- hero.shield_thorns) :
  -- réagit au bouclier ABSORBÉ (`absorbed` ci-dessus), PAS aux PV perdus comme
  -- "Le Rancunier"/hero.thorns plus bas -- condition quasi inverse (thorns
  -- réagit à ce qui PASSE le bouclier), donc un champ jumeau distinct plutôt
  -- que de réutiliser thorns, les 2 pouvant coexister sur un même héros.
  -- `source_unit ~= target_unit` : jamais de retour sur soi-même (même garde
  -- que thorns), même si aucun effet du jeu ne fait aujourd'hui encaisser au
  -- Paladin un coup dont IL serait la source.
  if absorbed > 0 and target_unit.shield_thorns and source_unit and source_unit ~= target_unit and source_unit.hp > 0 then
    local retaliation = absorbed * target_unit.shield_thorns
    Combat.deal_damage(state, nil, source_unit, retaliation, nil, nil, { brut = true, source_unit = target_unit })
    Combat.log(state, target_unit.name .. " (Bouclier de pointes) renvoie " .. retaliation .. " dégâts à " .. source_unit.name .. ".", "you")
  end

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

  -- "Pacte de Survie" (2026-09-03, Enchantement du Nécromancien --
  -- hero.pacte_survie) : gagne 1/2 bouclier PAR PV perdu à CE déclenchement,
  -- quelle qu'en soit la source (dégâts ennemis OU auto-sacrifice de ses
  -- propres cartes, même geste générique que Corruption juste au-dessus).
  -- Sans plafond -- choix assumé par le porteur de projet (2026-09-03), pas
  -- un oubli : combiné à Pacte funeste (auto-sacrifice la moitié/le tiers de
  -- ses PV), un seul déclenchement peut donner un gros pic de bouclier -- à
  -- surveiller en playtest plutôt qu'un plafond arbitraire deviné ici.
  if to_hp > 0 and target_unit.pacte_survie and target_unit.hp > 0 then
    local shield = Combat.grant_defense(target_unit, to_hp * target_unit.pacte_survie)
    Combat.log(state, target_unit.name .. " (Pacte de Survie) gagne " .. shield .. " bouclier.", "you")
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
    if is_fire then
      target_unit.took_fire_damage_this_turn = true
      -- Troll des Marais (2026-09-01, demande explicite) : contrairement à
      -- took_fire_damage_this_turn ci-dessus (remis à zéro chaque tour, voir
      -- Encounter.roll_telegraphs), ce flag n'est JAMAIS réinitialisé -- exclut
      -- Régénération du tirage pour le reste du combat dès la première brûlure.
      target_unit.fire_touched_ever = true
    end
  end

  -- "Instinct du Chasseur" (2026-09-03, Enchantement du Guerrier --
  -- hero.instinct_chasseur) : CHAQUE coup porté par une carte du Guerrier sur
  -- un ennemi (pas seulement un kill -- tranché explicitement par le porteur
  -- de projet, plus large que la 1ʳᵉ mouture proposée) -- `amount > 0` : le
  -- coup a réellement porté quelque chose, même entièrement absorbé par du
  -- bouclier, pas juste "visé".
  if amount > 0 and is_enemy_target and source_hero and source_hero.instinct_chasseur then
    Combat.grant_defense(source_hero, source_hero.instinct_chasseur)
    Combat.log(state, source_hero.name .. " (Instinct du Chasseur) gagne " .. source_hero.instinct_chasseur .. " bouclier.", "you")
  end

  -- "Combustion différée" (2026-09-03, Enchantement du Mage --
  -- hero.combustion_differee) : chaque dégât "feu" du Mage qui touche un
  -- ennemi (même détection `is_fire` que la sensibilité au feu de l'Homme
  -- Arbre plus haut) lui applique Brûlure en plus.
  if amount > 0 and is_enemy_target and is_fire and source_hero and source_hero.combustion_differee then
    Combat.apply_status(target_unit, "brulure", source_hero.combustion_differee)
    Combat.log(state, target_unit.name .. " prend feu (Combustion différée).", "you")
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
  -- "Bouclier vivant" (2026-09-03, Enchantement du Paladin --
  -- hero.bouclier_vivant_ratio) : CHAQUE fois que le Paladin lui-même gagne
  -- du bouclier, quelle qu'en soit la source (ses propres cartes, un
  -- bouclier programmé/de début de tour posé par Game.start_turn, etc. --
  -- cette fonction est LE point de passage unique pour tout gain de
  -- bouclier, voir son commentaire au-dessus) -- l'AUTRE allié vivant le
  -- plus bas en PV (jamais le Paladin lui-même, sinon un 2ᵉ octroi le
  -- reciblerait et boucle à l'infini) en gagne la moitié/la totalité.
  -- `ctx.state` requis pour retrouver le reste de l'équipe -- absent pour un
  -- gain hors carte sans état accessible, l'effet ne fait alors simplement
  -- rien plutôt que planter (voir Game.start_turn, qui passe désormais
  -- `{state=state}` pour turn_start_shield/scheduled_shields, justement pour
  -- que ce cas reste couvert).
  if amount > 0 and target_unit.bouclier_vivant_ratio and ctx and ctx.state then
    local best = nil
    for _, h in ipairs(ctx.state.heroes) do
      if h ~= target_unit and h.hp > 0 and (not best or h.hp < best.hp) then best = h end
    end
    if best then
      local shared = round(amount * target_unit.bouclier_vivant_ratio)
      if shared > 0 then
        best.defense = (best.defense or 0) + shared
        Combat.log(ctx.state, best.name .. " reçoit " .. shared .. " bouclier (Bouclier vivant).", "you")
      end
    end
  end
  return amount
end

--- `ctx` (optionnel) : même convention que Combat.grant_defense ci-dessus.
-- Renvoie le montant RÉELLEMENT appliqué, pas la demande brute (2026-08-30,
-- bug signalé -- "j'ai l'impression que la barre de vie est pleine" au
-- Refuge : un héros déjà à PV pleins affichait quand même "+7 PV" -- l'ancien
-- code renvoyait `amount` avant plafonnement, jamais le vrai delta). La
-- plupart des appelants (cartes, voir cards.lua) ignorent cette valeur de
-- retour ; seuls Controller:choose_campfire_hero/choose_refuge_rest s'en
-- servent pour l'affichage "+X PV" -- les deux veulent le montant réel.
function Combat.grant_heal(target_unit, base, ctx)
  local amount = round(consume_inspiration(base, ctx))
  local applied = math.min(target_unit.max_hp, target_unit.hp + amount) - target_unit.hp
  target_unit.hp = target_unit.hp + applied
  return applied
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
