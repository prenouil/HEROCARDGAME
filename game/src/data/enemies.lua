-- Bestiaire (20 ennemis communs, "Run Infini", 2026-08-06 puis extension biomes
-- 2026-09-01) et aides de scaling par niveau. Chaque ennemi commun (pas les
-- boss) porte désormais un champ `biome` ("foret"|"catacombes"|"canyon"|
-- "volcan") qui confine la génération de rencontre à un seul biome par combat
-- (voir Encounter.generate_encounter) -- avant, purement visuel (ENEMY_BIOME
-- dans background.lua), maintenant une vraie donnée de jeu.
-- Port fidèle de ENEMY_TEMPLATES / VALUE_VARIANCE / LEVEL_GROWTH / roll*/scaled*
-- depuis proto-cartes-completes/index.html. Seules les VALEURS scalent avec le
-- niveau ; le comportement de chaque ennemi (chooseMove) est fixe.
-- NOTE : ce système "Run Infini" (bestiaire à 10, scaling de niveau, budget de
-- rencontre) n'est pour l'instant documenté nulle part dans gdd.md/epics.md —
-- signalé, pas corrigé ici (hors scope de ce port).
-- `icon` = vraie donnée de design (emoji) ; `label` = repli texte utilisé par la
-- UI LÖVE, dont la police par défaut ne contient pas ces glyphes.
-- `dmg_type` (2026-08-27, demande explicite -- chaque coup de dégâts doit
-- afficher une icône selon sa NATURE, pas un texte "dégâts") : "melee" (icône
-- épée), "ranged" (icône arbalète) ou "magic" (icône étincelle), voir
-- DMG_TYPE_ICON dans src/ui/view.lua. Assigné à chaque coup individuellement
-- selon sa description (ex. "Griffure" = melee, "Tir à l'Arc" = ranged,
-- "Toucher Nécrotique" = magic), pas par ennemi -- un même ennemi peut avoir
-- des coups de nature différente (aucun cas actuel, mais le champ est par
-- coup pour rester correct si ça arrive). Les coups sans dégâts propres
-- (kind == "debuff"/"heal-self"/"heal-ally"/"revive") n'en ont pas besoin --
-- leur icône de télégraphe est dérivée autrement (voir enemy_telegraph_parts).

local Enemies = {}

Enemies.VALUE_VARIANCE = 0.20
Enemies.LEVEL_GROWTH = 0.20 -- +20%/niveau, valeur de départ à tester (placeholder assumé)

local function round(x) return math.floor(x + 0.5) end
Enemies.round = round

local function value_range(v)
  return round(v * (1 - Enemies.VALUE_VARIANCE)), round(v * (1 + Enemies.VALUE_VARIANCE))
end
Enemies.value_range = value_range

-- `rng` (2026-08-10, demande explicite -- tirages reproductibles à l'identique pour
-- un run donné) : instance de src/util/rng.lua, jamais math.random directement --
-- voir Game.reset_run pour la création des flux et Encounter.roll_telegraphs pour
-- celui utilisé ici (state.rng.enemy_turn).
local function roll_value(v, rng)
  local lo, hi = value_range(v)
  return lo + rng:random(0, hi - lo)
end
Enemies.roll_value = roll_value

local function scaled_base(base, level)
  return base * (1 + Enemies.LEVEL_GROWTH * (level - 1))
end
Enemies.scaled_base = scaled_base

local function roll_scaled(base, level, rng)
  return roll_value(scaled_base(base, level), rng)
end
Enemies.roll_scaled = roll_scaled

local function scaled_range(base, level)
  return value_range(scaled_base(base, level))
end
Enemies.scaled_range = scaled_range

local function cost_at_level(template, level)
  return round(scaled_base(template.cost, level))
end
Enemies.cost_at_level = cost_at_level

local function range_text(base, level)
  local lo, hi = scaled_range(base, level)
  return lo .. "-" .. hi
end

Enemies.status_labels = { vulnerabilite = "Vulnérabilité", incapacite = "Incapacité", brulure = "Brûlure" }

-- Noms d'affichage des 4 biomes (2026-09-01) -- utilisés par l'écran
-- d'annonce de biome et le fond de combat (voir background.lua), jamais par
-- la génération de rencontre elle-même (qui ne lit que la clé, `t.biome`).
Enemies.BIOME_NAMES = {
  foret = "Forêt Sauvage", catacombes = "Catacombes", canyon = "Canyon des Brigands", volcan = "Volcan",
}
Enemies.ALL_BIOMES = { "foret", "catacombes", "canyon", "volcan" }

Enemies.templates = {
  {
    id = "gobelin", name = "Gobelin Maraudeur", icon = "\u{1F47A}", label = "GOB", hp_base = 15, cost = 8, target_mode = "random", biome = "foret",
    choose_move = function(e, all, rng)
      if rng:random() < 2 / 3 then
        return { kind = "dmg", name = "Griffure", icon = "\u{1FA78}", dmg_type = "melee", amount = roll_scaled(4, e.level, rng) }
      end
      return { kind = "dmg", name = "Charge Brutale", icon = "\u{1F4A5}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1FA78}", name = "Griffure", text = range_text(4, level) .. " dégâts (fréquent)" },
        { icon = "\u{1F4A5}", name = "Charge Brutale", text = range_text(7, level) .. " dégâts (rare)" },
      }
    end,
  },
  {
    id = "squelette", name = "Squelette Archer", icon = "\u{1F480}", label = "SQE", hp_base = 12, cost = 6, target_mode = "random", biome = "catacombes",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Tir à l'Arc", icon = "\u{1F3F9}", dmg_type = "ranged", amount = roll_scaled(4, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F3F9}", name = "Tir à l'Arc", text = range_text(4, level) .. " dégâts (toujours)" } }
    end,
  },
  {
    id = "troll", name = "Troll des Marais", icon = "\u{1F9CC}", label = "TRL", hp_base = 28, cost = 14, target_mode = "random", biome = "foret",
    -- Bug signalé (2026-08-24) : Régénération pouvait être télégraphiée/jouée
    -- même à PV pleins (e.hp >= e.max_hp), pour un soin plafonné à 0 -- tour
    -- gâché sans que rien ne se passe à l'écran. `e.hp < e.max_hp` exclut
    -- Régénération du tirage dans ce cas, jamais Coup de Massue à la place --
    -- distinct de l'annulation par les flammes (Game.resolve_enemy_action),
    -- qui s'applique APRÈS coup, une fois déjà télégraphiée.
    -- `e.fire_touched_ever` (2026-09-01, demande explicite -- "ne peut plus
    -- lancer régénération du combat si a été touché par du feu") : posé une
    -- fois pour toutes dans Combat.deal_damage, jamais réinitialisé -- exclut
    -- DÉFINITIVEMENT Régénération du tirage dès la première brûlure, tout le
    -- reste du combat. Distinct de `took_fire_damage_this_turn` (annulation
    -- À LA RÉSOLUTION, toujours utile pour le cas où le Troll brûle APRÈS
    -- avoir déjà télégraphié Régénération ce même tour, avant que
    -- `fire_touched_ever` n'ait eu la chance d'exclure le tirage suivant).
    choose_move = function(e, all, rng)
      if e.hp < e.max_hp and not e.fire_touched_ever and rng:random() < 1 / 3 then
        return { kind = "heal-self", name = "Régénération", icon = "\u{1F49A}", amount = roll_scaled(15, e.level, rng) }
      end
      return { kind = "dmg", name = "Coup de Massue", icon = "\u{1F528}", dmg_type = "melee", amount = roll_scaled(8, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F528}", name = "Coup de Massue", text = range_text(8, level) .. " dégâts (fréquent)" },
        { icon = "\u{1F49A}", name = "Régénération", text = "+" .. range_text(15, level) .. ' "PV" (rare) — définitivement indisponible dès que le Troll a subi des dégâts "feu" une seule fois ce combat' },
      }
    end,
  },
  {
    -- Bouclier passif 1->3, coût 10->12 (2026-09-01, demande explicite) : un
    -- bouclier permanent de 3 mitige un coup faible presque en entier chaque
    -- tour, valeur défensive nettement supérieure à l'ancien 1 quasi
    -- anecdotique. Coup "agressif" gagne aussi "Saignement" 1 (nouveau) --
    -- l'autre tour sur deux ("défensif") reste inchangé, juste +3 bouclier
    -- supplémentaire qui s'ajoute au passif (soit 6 "bouclier" ce tour-là).
    id = "gobelourd", name = "Gobelourd", icon = "\u{1F5FF}", label = "GBD", hp_base = 20, cost = 12, shield_base = 3, target_mode = "random", biome = "foret",
    choose_move = function(e, all, rng)
      e.defend_cycle = not e.defend_cycle
      local defending = e.defend_cycle
      e.defending = defending
      if defending then
        return {
          kind = "dmg", name = "Coup de Gourdin", icon = "\u{1F528}", dmg_type = "melee",
          amount = roll_scaled(3, e.level, rng), defense_bonus_this_turn = roll_scaled(3, e.level, rng),
        }
      end
      return {
        kind = "dmg", name = "Coup de Gourdin", icon = "\u{1F528}", dmg_type = "melee",
        amount = roll_scaled(8, e.level, rng), bleed = roll_scaled(1, e.level, rng),
      }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F528}", name = "Coup de Gourdin", text = range_text(8, level) .. ' dégâts + "Saignement" ' .. range_text(1, level) .. ' hors défense / ' .. range_text(3, level) .. ' dégâts (+ "bouclier") en défense, un tour sur deux chacun — attaque toujours' },
        { icon = "\u{1F6E1}\u{FE0F}", name = "Bouclier passif", text = range_text(3, level) .. ' "bouclier" en permanence' },
      }
    end,
  },
  {
    -- Dégâts directs 9->7 + "Saignement" 2 (nouveau) (2026-09-01, demande
    -- explicite -- retouche confirmée telle quelle) : le dégât baisse pour
    -- compenser l'ajout du Saignement, pas un pur nerf.
    id = "loup", name = "Loup Enragé", icon = "\u{1F43A}", label = "LUP", hp_base = 10, cost = 9, target_mode = "random", biome = "foret",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Morsure", icon = "\u{1F43E}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng), bleed = roll_scaled(2, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F43E}", name = "Morsure", text = range_text(7, level) .. ' dégâts + "Saignement" ' .. range_text(2, level) .. ' (toujours) — peu de "PV"' } }
    end,
  },
  {
    id = "araignee", name = "Araignée Venimeuse", icon = "\u{1F577}\u{FE0F}", label = "ARA", hp_base = 12, cost = 7, target_mode = "random", biome = "foret",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Piqûre", icon = "\u{2620}\u{FE0F}", dmg_type = "melee", amount = roll_scaled(2, e.level, rng), brut = true, bleed = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{2620}\u{FE0F}", name = "Piqûre", text = range_text(2, level) .. ' dégâts "brut" + "Saignement" ' .. range_text(3, level) .. " (toujours)" } }
    end,
  },
  {
    id = "necromancien", name = "Nécromancien Novice", icon = "\u{1F9D9}", label = "NEC", hp_base = 10, cost = 9, target_mode = "random", biome = "catacombes",
    -- Deux attaques désormais (2026-08-21, demande explicite -- avant,
    -- Malédiction inconditionnelle) : Malédiction 2/3 du temps, Toucher
    -- Nécrotique (dégâts) 1/3 du temps. La règle tacite "si aucun ennemi ne
    -- fait de dégâts ce tour, force le Nécromancien sur son attaque à
    -- dégâts" vit à part, dans Encounter.roll_telegraphs -- jamais ici, et
    -- jamais dans moves_info ci-dessous (règle volontairement invisible pour
    -- le joueur, ne doit apparaître dans aucun texte affiché).
    -- Malédiction pose désormais Vulnérabilité ET Incapacité (2026-09-01,
    -- demande explicite) via status_key2/amount2 (voir la branche "debuff"
    -- généralisée dans Game.resolve_enemy_action).
    choose_move = function(e, all, rng)
      if rng:random() < 1 / 3 then
        return { kind = "dmg", name = "Toucher Nécrotique", icon = "\u{1F480}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
      end
      return {
        kind = "debuff", name = "Malédiction", icon = "\u{1F52E}",
        status_key = "vulnerabilite", amount = roll_scaled(3, e.level, rng),
        status_key2 = "incapacite", amount2 = roll_scaled(3, e.level, rng),
      }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F52E}", name = "Malédiction", text = '"Vulnérabilité" ' .. range_text(3, level) .. ' ET "Incapacité" ' .. range_text(3, level) .. ", pas de dégât direct (fréquent)" },
        { icon = "\u{1F480}", name = "Toucher Nécrotique", text = range_text(3, level) .. " dégâts (rare)" },
      }
    end,
  },
  {
    -- Coût 16->20 (2026-09-01, demande explicite -- nouvelle capacité
    -- "Protection", voir Game.start_turn) : Protection est une EXCEPTION au
    -- fonctionnement habituel du moteur -- elle ne vit PAS dans choose_move/
    -- ce fichier (contrairement à toutes les autres capacités), elle se
    -- déclenche inconditionnellement en tout DÉBUT de tour, avant même la
    -- phase joueur, indépendamment du move télégraphié ci-dessous (qui reste
    -- uniquement Poing de Pierre).
    id = "golem", name = "Golem de Pierre", icon = "\u{1FAA8}", label = "GOL", hp_base = 35, cost = 20, shield_base = 3, target_mode = "random", biome = "catacombes",
    choose_move = function(e, all, rng)
      return { kind = "conditional-retaliate", name = "Repos (sauf si touché)", icon = "\u{1FAA8}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F6E1}\u{FE0F}", name = "Protection", text = 'Donne 2 "bouclier" à tous les autres ennemis vivants, au tout début de chaque tour (avant que vous ne jouiez) — inconditionnel' },
        { icon = "\u{1FAA8}", name = "Poing de Pierre", text = range_text(7, level) .. " dégâts, seulement s'il subit des dégâts pendant la phase joueur ; sinon ne fait rien" },
        { icon = "\u{1F6E1}\u{FE0F}", name = "Bouclier passif", text = range_text(3, level) .. ' "bouclier" en permanence — très gros "PV"' },
      }
    end,
  },
  {
    id = "bandit", name = "Bandit Fourbe", icon = "\u{1F52A}", label = "BAN", hp_base = 14, cost = 9, target_mode = "lowest-hp", biome = "canyon",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Coup Sournois", icon = "\u{1F52A}", dmg_type = "melee", amount = roll_scaled(6, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F52A}", name = "Coup Sournois", text = range_text(6, level) .. ' dégâts, cible toujours le héros au moins de "PV" (toujours)' } }
    end,
  },
  {
    -- Soin 5->10, coût 8->9 (2026-09-01, demande explicite) : soin doublé.
    id = "chaman", name = "Chaman Gobelin", icon = "\u{1FA84}", label = "CHA", hp_base = 12, cost = 9, target_mode = "random", biome = "canyon",
    choose_move = function(e, all, rng)
      local wounded = {}
      for _, o in ipairs(all) do
        if o.id ~= e.id and o.hp > 0 and o.hp < o.max_hp then wounded[#wounded + 1] = o end
      end
      if #wounded > 0 then
        local target = wounded[rng:random(#wounded)]
        return { kind = "heal-ally", name = "Chant Rituel", icon = "\u{1FA84}", amount = roll_scaled(10, e.level, rng), heal_target_id = target.id }
      end
      return { kind = "dmg", name = "Chant Rituel (repli)", icon = "\u{2734}\u{FE0F}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1FA84}", name = "Chant Rituel", text = "Soigne un allié blessé de " .. range_text(10, level) .. ' "PV" s\'il y en a un' },
        { icon = "\u{2734}\u{FE0F}", name = "Chant Rituel (repli)", text = "Sinon, attaque pour " .. range_text(3, level) .. " dégâts" },
      }
    end,
  },

  -- ---------- Nouveaux ennemis, extension biomes (2026-09-01) ----------
  {
    id = "garde-ossements", name = "Garde-Ossements", icon = "\u{1F480}", label = "GOS", hp_base = 18, cost = 10, shield_base = 2, target_mode = "random", biome = "catacombes",
    choose_move = function(e, all, rng)
      if rng:random() < 2 / 3 then
        return { kind = "dmg", name = "Coup de Bouclier", icon = "\u{1F6E1}\u{FE0F}", dmg_type = "melee", amount = roll_scaled(5, e.level, rng) }
      end
      return { kind = "debuff", name = "Brise-Volonté", icon = "\u{1F4A2}", status_key = "incapacite", amount = roll_scaled(2, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F6E1}\u{FE0F}", name = "Coup de Bouclier", text = range_text(5, level) .. " dégâts (fréquent)" },
        { icon = "\u{1F4A2}", name = "Brise-Volonté", text = '"Incapacité" ' .. range_text(2, level) .. ", pas de dégât direct (rare)" },
      }
    end,
  },
  -- Ancre de la mécanique des Catacombes ("les morts ne restent pas morts") :
  -- relève les Squelette Archer/Garde-Ossements tombés -- réutilise le kind
  -- "revive" généralisé (voir Game.resolve_enemy_action, move.revive_template_ids),
  -- plus jamais câblé en dur sur "pousse" comme avant.
  {
    id = "pretre-dechu", name = "Prêtre Déchu", icon = "\u{1F9DF}", label = "PRE", hp_base = 16, cost = 13, target_mode = "random", biome = "catacombes",
    choose_move = function(e, all, rng)
      local any_dead = false
      for _, o in ipairs(all) do
        if o.id ~= e.id and (o.template_id == "squelette" or o.template_id == "garde-ossements") and o.hp <= 0 then
          any_dead = true
          break
        end
      end
      if any_dead and rng:random() < 2 / 5 then
        return { kind = "revive", name = "Rituel de Rappel", icon = "\u{1F480}", revive_template_ids = { "squelette", "garde-ossements" } }
      end
      return { kind = "dmg", name = "Toucher Flétrissant", icon = "\u{1F480}", dmg_type = "magic", amount = roll_scaled(4, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F480}", name = "Rituel de Rappel", text = "Relève tous les Squelette Archer/Garde-Ossements vaincus, s'il y en a" },
        { icon = "\u{1F480}", name = "Toucher Flétrissant", text = range_text(4, level) .. " dégâts (sinon)" },
      }
    end,
  },
  {
    id = "eclaireuse", name = "Éclaireuse des Sables", icon = "\u{1F3F9}", label = "ECL", hp_base = 13, cost = 10, target_mode = "lowest-hp", biome = "canyon",
    choose_move = function(e, all, rng)
      if rng:random() < 2 / 3 then
        return { kind = "dmg", name = "Flèche Barbelée", icon = "\u{1F3F9}", dmg_type = "ranged", amount = roll_scaled(4, e.level, rng) }
      end
      return { kind = "dmg", name = "Tir Perçant", icon = "\u{1F3F9}", dmg_type = "ranged", amount = roll_scaled(7, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F3F9}", name = "Flèche Barbelée", text = range_text(4, level) .. ' dégâts, cible toujours le héros au moins de "PV" (fréquent)' },
        { icon = "\u{1F3F9}", name = "Tir Perçant", text = range_text(7, level) .. ' dégâts, cible toujours le héros au moins de "PV" (rare)' },
      }
    end,
  },
  -- "Charge de groupe" recalculée à CHAQUE tirage (pas figée à l'instanciation) :
  -- le nombre d'ennemis vivants change en cours de combat, +2 par autre ennemi
  -- vivant (flat, pas mis à l'échelle du niveau) -- ex. seul = 7, avec 3
  -- autres ennemis vivants = 13.
  {
    id = "chef-de-bande", name = "Chef de Bande", icon = "\u{1F452}", label = "CHF", hp_base = 22, cost = 14, shield_base = 1, target_mode = "lowest-hp", biome = "canyon",
    choose_move = function(e, all, rng)
      local others = 0
      for _, o in ipairs(all) do
        if o.id ~= e.id and o.hp > 0 then others = others + 1 end
      end
      return { kind = "dmg", name = "Charge de groupe", icon = "\u{2694}\u{FE0F}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng) + 2 * others }
    end,
    moves_info = function(level)
      return { { icon = "\u{2694}\u{FE0F}", name = "Charge de groupe", text = range_text(7, level) .. " dégâts + 2 par autre ennemi vivant sur le champ de bataille (toujours)" } }
    end,
  },
  {
    id = "tireuse", name = "Tireuse Embusquée", icon = "\u{1F3F9}", label = "TIR", hp_base = 11, cost = 7, target_mode = "lowest-hp", biome = "canyon",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Tir Ajusté", icon = "\u{1F3F9}", dmg_type = "ranged", amount = roll_scaled(5, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F3F9}", name = "Tir Ajusté", text = range_text(5, level) .. ' dégâts, cible toujours le héros au moins de "PV" (toujours)' } }
    end,
  },
  {
    id = "salamandre", name = "Salamandre de Lave", icon = "\u{1F98E}", label = "SAL", hp_base = 14, cost = 10, target_mode = "random", biome = "volcan",
    choose_move = function(e, all, rng)
      if rng:random() < 2 / 3 then
        return { kind = "dmg", name = "Griffure Ardente", icon = "\u{1F525}", dmg_type = "melee", amount = roll_scaled(5, e.level, rng) }
      end
      return { kind = "buff-self", name = "Surchauffe", icon = "\u{1F525}", status_key = "puissance", amount = 2, log_text = "surchauffe et gagne en puissance" }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F525}", name = "Griffure Ardente", text = range_text(5, level) .. " dégâts (fréquent)" },
        { icon = "\u{1F525}", name = "Surchauffe", text = 'Gagne "Puissance" 2, pas de dégât ce tour-là (rare) — ne redescend jamais seule' },
      }
    end,
  },
  {
    id = "cracheur", name = "Cracheur de Braise", icon = "\u{1F32B}\u{FE0F}", label = "CRA", hp_base = 12, cost = 8, target_mode = "random", biome = "volcan",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Jet de Braise", icon = "\u{1F525}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng), burn = roll_scaled(1, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F525}", name = "Jet de Braise", text = range_text(3, level) .. ' dégâts + "Brûlure" ' .. range_text(1, level) .. " (toujours) — la Brûlure ne décroît jamais seule" } }
    end,
  },
  {
    id = "elementaire-cendre", name = "Élémentaire de Cendre", icon = "\u{1F32B}\u{FE0F}", label = "ELC", hp_base = 11, cost = 8, target_mode = "random", biome = "volcan",
    choose_move = function(e, all, rng)
      if rng:random() < 1 / 2 then
        return {
          kind = "debuff", name = "Souffle Étouffant", icon = "\u{1F32B}\u{FE0F}",
          status_key = "vulnerabilite", amount = roll_scaled(2, e.level, rng),
          status_key2 = "brulure", amount2 = roll_scaled(1, e.level, rng),
        }
      end
      return { kind = "dmg", name = "Éclat Brûlant", icon = "\u{1F525}", dmg_type = "magic", amount = roll_scaled(4, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F32B}\u{FE0F}", name = "Souffle Étouffant", text = '"Vulnérabilité" ' .. range_text(2, level) .. ' + "Brûlure" ' .. range_text(1, level) .. ", pas de dégât direct (1/2)" },
        { icon = "\u{1F525}", name = "Éclat Brûlant", text = range_text(4, level) .. " dégâts (1/2)" },
      }
    end,
  },
  {
    id = "golem-magma", name = "Golem de Magma", icon = "\u{1FAA8}", label = "GOM", hp_base = 32, cost = 15, shield_base = 2, target_mode = "random", biome = "volcan",
    choose_move = function(e, all, rng)
      if rng:random() < 2 / 3 then
        return { kind = "dmg", name = "Poing Incandescent", icon = "\u{1F525}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng) }
      end
      return { kind = "buff-self", name = "Cœur en Fusion", icon = "\u{1F525}", status_key = "puissance", amount = 2, log_text = "voit son cœur de magma s'embraser" }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F525}", name = "Poing Incandescent", text = range_text(7, level) .. " dégâts (fréquent)" },
        { icon = "\u{1F525}", name = "Cœur en Fusion", text = 'Gagne "Puissance" 2, pas de dégât ce tour-là (rare) — ne redescend jamais seule' },
      }
    end,
  },
  -- Ancre de la mécanique du Volcan ("Surchauffe" -- Puissance qui ne
  -- redescend jamais seule) : Puissance garantie tous les 3 tours (pas
  -- aléatoire, pour rester lisible sur cet ennemi) -- `e.vouivre_turn`,
  -- compteur posé/incrémenté directement sur l'instance depuis choose_move,
  -- même idiome que `e.defend_cycle` du Gobelourd.
  {
    id = "vouivre", name = "Vouivre des Cendres", icon = "\u{1F409}", label = "VOU", hp_base = 20, cost = 17, target_mode = "random", biome = "volcan",
    choose_move = function(e, all, rng)
      e.vouivre_turn = (e.vouivre_turn or 0) + 1
      if e.vouivre_turn % 3 == 0 then
        return { kind = "buff-self", name = "Montée en Cendres", icon = "\u{1F525}", status_key = "puissance", amount = 2, log_text = "monte en cendres" }
      end
      return { kind = "dmg", name = "Griffure de Braise", icon = "\u{1F525}", dmg_type = "melee", amount = roll_scaled(6, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F525}", name = "Griffure de Braise", text = range_text(6, level) .. " dégâts (2 tours sur 3)" },
        { icon = "\u{1F525}", name = "Montée en Cendres", text = 'Gagne "Puissance" 2, automatique et garanti tous les 3 tours — ne redescend jamais seule' },
      }
    end,
  },

  -- ---------- Boss (2026-08-21, demande explicite) ----------
  -- `boss_only = true` (tous les templates de cette section) : jamais tirés
  -- par le budget aléatoire du mode Infini -- voir Encounter.generate_encounter,
  -- qui filtre ce champ hors de son pool. Rencontre fixe assemblée à part par
  -- Encounter.boss_encounter, déclenchée depuis "Tester le boss" au menu (tirage
  -- aléatoire parmi les 4) ou en fin d'un run borné (2026-09-01, demande
  -- explicite -- CHOISI par le dernier biome traversé, plus un simple 50/50) :
  -- foret -> Homme Arbre, canyon -> Aigle Géant, catacombes -> Roi Squelette,
  -- volcan -> Élémentaire de Feu. Voir la table de correspondance dans
  -- Encounter.boss_encounter (encounter.lua).
  {
    id = "pousse", name = "Pousse d'Arbre", icon = "\u{1F331}", label = "POU", hp_base = 3, cost = 3, target_mode = "random", boss_only = true,
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Griffure de Ronce", icon = "\u{1F33F}", dmg_type = "melee", amount = roll_scaled(2, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F33F}", name = "Griffure de Ronce", text = range_text(2, level) .. " dégâts (toujours)" } }
    end,
  },
  {
    -- 3 coups (2026-08-21, demande explicite) : tape fort sur un aventurier
    -- (1/2 du "reste" une fois l'invocation écartée) / attaque tous les
    -- aventuriers plus faiblement (l'autre 1/2) / ramène les Pousses d'Arbre
    -- vaincues à la vie -- PAS une invocation de nouvelles pousses (revirement
    -- explicite du porteur de projet, 2026-08-21) : les 4 Pousses existent dès
    -- le début du combat (voir Encounter.boss_encounter), ce 3ᵉ coup se
    -- contente de repasser `hp` à `max_hp` sur celles tombées à 0 (voir
    -- Game.resolve_enemy_action, kind == "revive") -- jamais de nouvelle
    -- instance créée en cours de combat. Coup indisponible tant qu'aucune
    -- Pousse n'est vaincue (rien à ranimer) -- même logique que le Troll qui
    -- ne régénère jamais à PV pleins.
    -- PV remontés à 80 (2026-08-24, demande explicite -- "peuvent être à
    -- nouveau très élevés") après un premier ajustement à 50 : compensé
    -- désormais par une vraie faiblesse exploitable (sensible au feu, +50%
    -- dégâts de feu, voir Combat.damage_multiplier) plutôt que par un simple
    -- plafond de PV bas -- les dégâts qu'il inflige restent réduits (8/3).
    id = "homme-arbre", name = "Homme Arbre", icon = "\u{1F333}", label = "ARB", hp_base = 80, cost = 60, target_mode = "random", boss_only = true,
    choose_move = function(e, all, rng)
      local any_dead_pousse = false
      for _, o in ipairs(all) do
        if o.id ~= e.id and o.template_id == "pousse" and o.hp <= 0 then
          any_dead_pousse = true
          break
        end
      end
      if any_dead_pousse and rng:random() < 1 / 3 then
        return { kind = "revive", name = "Renaissance Sylvestre", icon = "\u{1F331}", revive_template_ids = { "pousse" } }
      end
      if rng:random() < 1 / 2 then
        return { kind = "dmg", name = "Coup de Branche", icon = "\u{1F9B4}", dmg_type = "melee", amount = roll_scaled(8, e.level, rng) }
      end
      return { kind = "dmg-all", name = "Onde Sylvestre", icon = "\u{1F343}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F9B4}", name = "Coup de Branche", text = range_text(8, level) .. " dégâts à un aventurier" },
        { icon = "\u{1F343}", name = "Onde Sylvestre", text = range_text(3, level) .. " dégâts à tous les aventuriers" },
        { icon = "\u{1F331}", name = "Renaissance Sylvestre", text = "Ramène les Pousses d'Arbre vaincues à pleine vie, s'il y en a" },
      }
    end,
  },
  -- Deuxième boss (2026-08-30, demande explicite -- "il faudrait un deuxième
  -- boss : un aigle géant. Il possède 2 images : 1 à terre, et 1 en vol") :
  -- seul (aucun sbire, contrairement à l'Homme Arbre -- voir
  -- Encounter.aigle_encounter), `hp_base` relevé en conséquence. Cycle à 2
  -- temps : au sol, peut choisir "Envol" (kind == "buff-self", pose `vol = 1`
  -- sur lui-même -- voir Game.resolve_enemy_action) plutôt qu'attaquer ; une
  -- fois en vol (`e.vol > 0`), forcé sur "Charge en Piqué" (`move.lands =
  -- true`, le fait redescendre -- `e.vol` remis à 0 à la résolution), sa
  -- seule attaque disponible tant qu'il vole. "Vol" réduit à 0 les dégâts de
  -- TYPE "épée" (voir Combat.damage_multiplier) -- contraint le joueur à
  -- garder une source de dégâts magique/nécrotique sous la main pour ne pas
  -- perdre un tour complet de DPS à chaque envol. L'image (au sol/en vol) suit
  -- directement `e.vol`, voir draw_enemy_icon dans view.lua.
  {
    id = "aigle", name = "Aigle Géant", icon = "\u{1F985}", label = "AIG", hp_base = 95, cost = 65, target_mode = "random", boss_only = true,
    choose_move = function(e, all, rng)
      if (e.vol or 0) > 0 then
        return { kind = "dmg", name = "Charge en Piqué", icon = "\u{1F985}", dmg_type = "melee", amount = roll_scaled(14, e.level, rng), lands = true }
      end
      if rng:random() < 0.35 then
        -- Dégâts faibles à toute l'équipe (2026-08-30, demande explicite --
        -- "Envol doit faire des dégâts faibles sur tous les aventuriers") :
        -- `dmg_all_amount`, EN PLUS de poser "Vol" -- voir Game.resolve_enemy_action,
        -- qui résout les 2 effets à la suite pour ce même move. Volontairement
        -- plus bas que "Onde Sylvestre" de l'Homme Arbre (3) : Envol accorde
        -- déjà un vrai avantage défensif (Vol), les dégâts ne sont qu'un bonus
        -- secondaire ("un vent tranchant" au décollage), pas son intérêt principal.
        return {
          kind = "buff-self", name = "Envol", icon = "\u{1FA76}", status_key = "vol", amount = 1,
          log_text = "prend son envol dans un tourbillon tranchant", dmg_all_amount = roll_scaled(2, e.level, rng),
        }
      end
      if rng:random() < 0.5 then
        return { kind = "dmg", name = "Coup de Bec", icon = "\u{1F985}", dmg_type = "melee", amount = roll_scaled(6, e.level, rng) }
      end
      return { kind = "dmg", name = "Serres Tranchantes", icon = "\u{1F985}", dmg_type = "melee", amount = roll_scaled(9, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F985}", name = "Coup de Bec", text = range_text(6, level) .. " dégâts à un aventurier" },
        { icon = "\u{1F985}", name = "Serres Tranchantes", text = range_text(9, level) .. " dégâts à un aventurier" },
        { icon = "\u{1FA76}", name = "Envol", text = 'Prend son envol : gagne "Vol" + ' .. range_text(2, level) .. ' dégâts à tous les aventuriers -- sa prochaine attaque devient obligatoirement Charge en Piqué' },
        { icon = "\u{1F985}", name = "Charge en Piqué", text = range_text(14, level) .. ' dégâts à un aventurier -- le ramène au sol (perd "Vol")' },
      }
    end,
  },
  -- Boss des Catacombes (2026-09-01, demande explicite -- "un boss choisi en
  -- rapport avec le dernier biome rencontré... pour les catacombes : roi
  -- squelette") : reprend la mécanique du biome à l'échelle du boss --
  -- comme le Prêtre Déchu (voir plus haut) relève Squelette Archer/Garde-
  -- Ossements, le Roi Squelette relève ses propres Squelette Archer tombés
  -- (mêmes instances que le template commun, PAS un nouveau minion dédié --
  -- voir Encounter.roi_squelette_encounter, même structure "1 boss + sbires
  -- déjà existants" que Homme Arbre + Pousses d'Arbre). `revive_template_ids`
  -- réutilise le kind "revive" généralisé (voir Game.resolve_enemy_action).
  {
    id = "roi-squelette", name = "Roi Squelette", icon = "\u{1F480}", label = "ROI", hp_base = 75, cost = 58, target_mode = "random", boss_only = true,
    choose_move = function(e, all, rng)
      local any_dead_squelette = false
      for _, o in ipairs(all) do
        if o.id ~= e.id and o.template_id == "squelette" and o.hp <= 0 then
          any_dead_squelette = true
          break
        end
      end
      if any_dead_squelette and rng:random() < 1 / 3 then
        return { kind = "revive", name = "Rituel de Réveil", icon = "\u{1F480}", revive_template_ids = { "squelette" } }
      end
      if rng:random() < 1 / 2 then
        return { kind = "dmg", name = "Coup Royal", icon = "\u{2694}\u{FE0F}", dmg_type = "melee", amount = roll_scaled(9, e.level, rng) }
      end
      return { kind = "dmg-all", name = "Décret Funeste", icon = "\u{1F480}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{2694}\u{FE0F}", name = "Coup Royal", text = range_text(9, level) .. " dégâts à un aventurier" },
        { icon = "\u{1F480}", name = "Décret Funeste", text = range_text(3, level) .. " dégâts à tous les aventuriers" },
        { icon = "\u{1F480}", name = "Rituel de Réveil", text = "Relève tous les Squelette Archer vaincus, s'il y en a" },
      }
    end,
  },
  -- Boss du Volcan (2026-09-01, demande explicite -- "élémentaire de feu") :
  -- même mécanique "Surchauffe" que le reste du biome (Puissance qui ne
  -- redescend jamais seule, voir combat.lua/game.lua) portée à l'échelle du
  -- boss -- "Montée en Puissance" ci-dessous, ET "Souffle Incandescent" pose
  -- "Brûlure" (nouveau statut du biome, lui non plus jamais décroissant),
  -- les 2 mécaniques du Volcan réunies sur ce seul boss. Seul (aucun sbire,
  -- comme l'Aigle Géant -- voir Encounter.elementaire_feu_encounter).
  {
    id = "elementaire-feu", name = "Élémentaire de Feu", icon = "\u{1F525}", label = "ELF", hp_base = 95, cost = 66, target_mode = "random", boss_only = true,
    choose_move = function(e, all, rng)
      if rng:random() < 0.25 then
        return { kind = "buff-self", name = "Montée en Puissance", icon = "\u{1F525}", status_key = "puissance", amount = 2, log_text = "s'embrase et gagne en puissance" }
      end
      if rng:random() < 0.25 then
        return { kind = "dmg-all", name = "Éruption", icon = "\u{1F30B}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
      end
      if rng:random() < 0.5 then
        return { kind = "dmg", name = "Griffe Ardente", icon = "\u{1F525}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng) }
      end
      return { kind = "dmg", name = "Souffle Incandescent", icon = "\u{1F525}", dmg_type = "magic", amount = roll_scaled(5, e.level, rng), burn = roll_scaled(2, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F525}", name = "Griffe Ardente", text = range_text(7, level) .. " dégâts à un aventurier" },
        { icon = "\u{1F525}", name = "Souffle Incandescent", text = range_text(5, level) .. ' dégâts + "Brûlure" ' .. range_text(2, level) .. " à un aventurier" },
        { icon = "\u{1F30B}", name = "Éruption", text = range_text(3, level) .. " dégâts à tous les aventuriers" },
        { icon = "\u{1F525}", name = "Montée en Puissance", text = 'Gagne "Puissance" 2, pas de dégât ce tour-là -- ne redescend jamais seule' },
      }
    end,
  },
}

function Enemies.by_id(id)
  for _, t in ipairs(Enemies.templates) do
    if t.id == id then return t end
  end
  return nil
end

return Enemies
