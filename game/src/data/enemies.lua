-- Bestiaire (10 ennemis, "Run Infini", 2026-08-06) et aides de scaling par niveau.
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

Enemies.status_labels = { vulnerabilite = "Vulnérabilité", incapacite = "Incapacité" }

Enemies.templates = {
  {
    id = "gobelin", name = "Gobelin Maraudeur", icon = "\u{1F47A}", label = "GOB", hp_base = 15, cost = 8, target_mode = "random",
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
    id = "squelette", name = "Squelette Archer", icon = "\u{1F480}", label = "SQE", hp_base = 12, cost = 6, target_mode = "random",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Tir à l'Arc", icon = "\u{1F3F9}", dmg_type = "ranged", amount = roll_scaled(4, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F3F9}", name = "Tir à l'Arc", text = range_text(4, level) .. " dégâts (toujours)" } }
    end,
  },
  {
    id = "troll", name = "Troll des Marais", icon = "\u{1F9CC}", label = "TRL", hp_base = 28, cost = 14, target_mode = "random",
    -- Bug signalé (2026-08-24) : Régénération pouvait être télégraphiée/jouée
    -- même à PV pleins (e.hp >= e.max_hp), pour un soin plafonné à 0 -- tour
    -- gâché sans que rien ne se passe à l'écran. `e.hp < e.max_hp` exclut
    -- Régénération du tirage dans ce cas, jamais Coup de Massue à la place --
    -- distinct de l'annulation par les flammes (Game.resolve_enemy_action),
    -- qui s'applique APRÈS coup, une fois déjà télégraphiée.
    choose_move = function(e, all, rng)
      if e.hp < e.max_hp and rng:random() < 1 / 3 then
        return { kind = "heal-self", name = "Régénération", icon = "\u{1F49A}", amount = roll_scaled(15, e.level, rng) }
      end
      return { kind = "dmg", name = "Coup de Massue", icon = "\u{1F528}", dmg_type = "melee", amount = roll_scaled(8, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F528}", name = "Coup de Massue", text = range_text(8, level) .. " dégâts (fréquent)" },
        { icon = "\u{1F49A}", name = "Régénération", text = "+" .. range_text(15, level) .. ' "PV" (rare) — annulée si le Troll a subi des dégâts "feu" pendant la phase joueur de ce tour' },
      }
    end,
  },
  {
    id = "gobelourd", name = "Gobelourd", icon = "\u{1F5FF}", label = "GBD", hp_base = 20, cost = 10, shield_base = 1, target_mode = "random",
    choose_move = function(e, all, rng)
      e.defend_cycle = not e.defend_cycle
      local defending = e.defend_cycle
      e.defending = defending
      local amount = defending and roll_scaled(3, e.level, rng) or roll_scaled(8, e.level, rng)
      local defense_bonus = defending and roll_scaled(3, e.level, rng) or 0
      return { kind = "dmg", name = "Coup de Gourdin", icon = "\u{1F528}", dmg_type = "melee", amount = amount, defense_bonus_this_turn = defense_bonus }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F528}", name = "Coup de Gourdin", text = range_text(8, level) .. ' dégâts hors défense / ' .. range_text(3, level) .. ' en défense (+ "bouclier"), un tour sur deux chacun — attaque toujours' },
        { icon = "\u{1F6E1}\u{FE0F}", name = "Bouclier passif", text = range_text(1, level) .. ' "bouclier" en permanence' },
      }
    end,
  },
  {
    id = "loup", name = "Loup Enragé", icon = "\u{1F43A}", label = "LUP", hp_base = 10, cost = 9, target_mode = "random",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Morsure", icon = "\u{1F43E}", dmg_type = "melee", amount = roll_scaled(9, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F43E}", name = "Morsure", text = range_text(9, level) .. ' dégâts (toujours) — peu de "PV"' } }
    end,
  },
  {
    id = "araignee", name = "Araignée Venimeuse", icon = "\u{1F577}\u{FE0F}", label = "ARA", hp_base = 12, cost = 7, target_mode = "random",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Piqûre", icon = "\u{2620}\u{FE0F}", dmg_type = "melee", amount = roll_scaled(2, e.level, rng), brut = true, bleed = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{2620}\u{FE0F}", name = "Piqûre", text = range_text(2, level) .. ' dégâts "brut" + "Saignement" ' .. range_text(3, level) .. " (toujours)" } }
    end,
  },
  {
    id = "necromancien", name = "Nécromancien Novice", icon = "\u{1F9D9}", label = "NEC", hp_base = 10, cost = 8, target_mode = "random",
    -- Deux attaques désormais (2026-08-21, demande explicite -- avant,
    -- Malédiction inconditionnelle) : Malédiction 2/3 du temps, Toucher
    -- Nécrotique (dégâts) 1/3 du temps. La règle tacite "si aucun ennemi ne
    -- fait de dégâts ce tour, force le Nécromancien sur son attaque à
    -- dégâts" vit à part, dans Encounter.roll_telegraphs -- jamais ici, et
    -- jamais dans moves_info ci-dessous (règle volontairement invisible pour
    -- le joueur, ne doit apparaître dans aucun texte affiché).
    choose_move = function(e, all, rng)
      if rng:random() < 1 / 3 then
        return { kind = "dmg", name = "Toucher Nécrotique", icon = "\u{1F480}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
      end
      return { kind = "debuff", name = "Malédiction", icon = "\u{1F52E}", status_key = "vulnerabilite", amount = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1F52E}", name = "Malédiction", text = '"Vulnérabilité" ' .. range_text(3, level) .. ", pas de dégât direct (fréquent)" },
        { icon = "\u{1F480}", name = "Toucher Nécrotique", text = range_text(3, level) .. " dégâts (rare)" },
      }
    end,
  },
  {
    id = "golem", name = "Golem de Pierre", icon = "\u{1FAA8}", label = "GOL", hp_base = 35, cost = 16, shield_base = 3, target_mode = "random",
    choose_move = function(e, all, rng)
      return { kind = "conditional-retaliate", name = "Repos (sauf si touché)", icon = "\u{1FAA8}", dmg_type = "melee", amount = roll_scaled(7, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1FAA8}", name = "Poing de Pierre", text = range_text(7, level) .. " dégâts, seulement s'il subit des dégâts pendant la phase joueur ; sinon ne fait rien" },
        { icon = "\u{1F6E1}\u{FE0F}", name = "Bouclier passif", text = range_text(3, level) .. ' "bouclier" en permanence — très gros "PV"' },
      }
    end,
  },
  {
    id = "bandit", name = "Bandit Fourbe", icon = "\u{1F52A}", label = "BAN", hp_base = 14, cost = 9, target_mode = "lowest-hp",
    choose_move = function(e, all, rng)
      return { kind = "dmg", name = "Coup Sournois", icon = "\u{1F52A}", dmg_type = "melee", amount = roll_scaled(6, e.level, rng) }
    end,
    moves_info = function(level)
      return { { icon = "\u{1F52A}", name = "Coup Sournois", text = range_text(6, level) .. ' dégâts, cible toujours le héros au moins de "PV" (toujours)' } }
    end,
  },
  {
    id = "chaman", name = "Chaman Gobelin", icon = "\u{1FA84}", label = "CHA", hp_base = 12, cost = 8, target_mode = "random",
    choose_move = function(e, all, rng)
      local wounded = {}
      for _, o in ipairs(all) do
        if o.id ~= e.id and o.hp > 0 and o.hp < o.max_hp then wounded[#wounded + 1] = o end
      end
      if #wounded > 0 then
        local target = wounded[rng:random(#wounded)]
        return { kind = "heal-ally", name = "Chant Rituel", icon = "\u{1FA84}", amount = roll_scaled(5, e.level, rng), heal_target_id = target.id }
      end
      return { kind = "dmg", name = "Chant Rituel (repli)", icon = "\u{2734}\u{FE0F}", dmg_type = "magic", amount = roll_scaled(3, e.level, rng) }
    end,
    moves_info = function(level)
      return {
        { icon = "\u{1FA84}", name = "Chant Rituel", text = "Soigne un allié blessé de " .. range_text(5, level) .. ' "PV" s\'il y en a un' },
        { icon = "\u{2734}\u{FE0F}", name = "Chant Rituel (repli)", text = "Sinon, attaque pour " .. range_text(3, level) .. " dégâts" },
      }
    end,
  },

  -- ---------- Boss (2026-08-21, demande explicite) ----------
  -- `boss_only = true` (les 2 templates ci-dessous) : jamais tirés par le
  -- budget aléatoire du mode Infini -- voir Encounter.generate_encounter, qui
  -- filtre ce champ hors de son pool. Rencontre fixe assemblée à part par
  -- Encounter.boss_encounter (1 Homme Arbre + 4 Pousses d'Arbre), déclenchée
  -- depuis "Tester le boss" au menu ou en fin d'un run borné à 5 combats --
  -- jamais mêlée à la génération normale.
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
        return { kind = "revive", name = "Renaissance Sylvestre", icon = "\u{1F331}" }
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
}

function Enemies.by_id(id)
  for _, t in ipairs(Enemies.templates) do
    if t.id == id then return t end
  end
  return nil
end

return Enemies
