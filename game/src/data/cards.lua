-- Les 18 cartes du deck MVP ("Run Infini", 2026-08-06, Coup Brutal retiré).
-- Port fidèle de CARDS depuis proto-cartes-completes/index.html — copié tel quel,
-- PAS depuis gdd.md. Le code source et le GDD ont divergé sur plusieurs points
-- (Coup mortel inflige 4 ici, pas 3 ; Provocation est "avance" ici, pas "depart" ;
-- Assassinat n'est pas "brut" ici) — signalé à Zgrubulu, non corrigé dans ce port :
-- ce module reflète fidèlement le prototype tel qu'il tourne aujourd'hui.
--
-- Chaque carte porte un champ `upgrade` optionnel (2026-08-10, écran
-- "feuDeCamp" -- valeurs alignées sur le tableur de Zgrubulu, colonne "Texte
-- amélioré") : {desc, effect} de la version "+" -- voir Cards.upgraded_def.

local Combat = require("src.rules.combat")
local Deck -- required en différé pour casser le cycle cards -> deck -> (rien) ; deck ne dépend pas de cards.

local Cards = {}

local function living_enemies(ctx) return Combat.living_enemies(ctx.state) end
local function living_heroes(ctx) return Combat.living_heroes(ctx.state) end

Cards.list = {
  {
    code = "coup-direct", name = "Coup direct", class_id = "generic", tier = "depart", cost = 0,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx) end,
    upgrade = {
      desc = 'Inflige 6 "epee".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx) end,
    },
  },
  {
    code = "encaisser", name = "Encaisser", class_id = "generic", tier = "depart", cost = 0,
    cats = { "defense" }, dmg_type = nil, target = "self",
    desc = 'Gagne 4 "bouclier".',
    effect = function(ctx) Combat.grant_defense(ctx.hero, 4, ctx) end,
    upgrade = {
      desc = 'Gagne 6 "bouclier".',
      effect = function(ctx) Combat.grant_defense(ctx.hero, 6, ctx) end,
    },
  },
  {
    code = "coup-estoc", name = "Coup d'estoc", class_id = "guerrier", tier = "depart", cost = 0,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee". Inflige 4 "epee" de plus si l\'ennemi a du "bouclier".',
    effect = function(ctx)
      local bonus = (ctx.target.defense or 0) > 0 and 4 or 0
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4 + bonus, "physique", ctx)
    end,
    upgrade = {
      desc = 'Inflige 6 "epee". Inflige 6 "epee" de plus si l\'ennemi a du "bouclier".',
      effect = function(ctx)
        local bonus = (ctx.target.defense or 0) > 0 and 6 or 0
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6 + bonus, "physique", ctx)
      end,
    },
  },
  {
    code = "coup-taille", name = "Coup de taille", class_id = "guerrier", tier = "avance", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "all-enemies",
    desc = 'Inflige 4 "epee" à tous les ennemis.',
    effect = function(ctx)
      for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 4, "physique", ctx) end
    end,
    upgrade = {
      desc = 'Inflige 6 "epee" à tous les ennemis.',
      effect = function(ctx)
        for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 6, "physique", ctx) end
      end,
    },
  },
  {
    code = "coup-mortel", name = "Coup mortel", class_id = "guerrier", tier = "avance", cost = 0,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee". Si cette attaque tue sa cible, peut agir à nouveau et Coup mortel revient dans la main du joueur.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx)
      if ctx.target.hp <= 0 then
        ctx.hero.has_acted = false
        ctx.return_to_hand = true
        Combat.log(ctx.state, ctx.hero.name .. " achève " .. ctx.target.name .. " — peut agir à nouveau, Coup mortel revient en main.", "power")
      end
    end,
    upgrade = {
      desc = 'Inflige 6 "epee". Si cette attaque tue sa cible, peut agir à nouveau et Coup mortel revient dans la main du joueur.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        if ctx.target.hp <= 0 then
          ctx.hero.has_acted = false
          ctx.return_to_hand = true
          Combat.log(ctx.state, ctx.hero.name .. " achève " .. ctx.target.name .. " — peut agir à nouveau, Coup mortel revient en main.", "power")
        end
      end,
    },
  },
  {
    code = "riposte", name = "Riposte", class_id = "guerrier", tier = "avance", cost = 3,
    cats = { "melee", "degats", "defense" }, dmg_type = "physique", target = "self",
    desc = 'Si "cibleennemi", annule l\'attaque et inflige 4 "epee".',
    effect = function(ctx)
      local attacker = Combat.enemy_targeting(ctx.state, ctx.hero)
      if not attacker then
        Combat.log(ctx.state, "Riposte : " .. ctx.hero.name .. " n'est visé par personne, la carte ne fait rien.", "sys")
        return
      end
      attacker.next_move = nil
      attacker.target_hero_id = nil
      Combat.deal_damage(ctx.state, ctx.hero, attacker, 4, "physique", ctx)
      Combat.log(ctx.state, "Riposte contre " .. attacker.name .. " !", "you")
    end,
    upgrade = {
      desc = 'Si "cibleennemi", annule l\'attaque et inflige 6 "epee".',
      effect = function(ctx)
        local attacker = Combat.enemy_targeting(ctx.state, ctx.hero)
        if not attacker then
          Combat.log(ctx.state, "Riposte : " .. ctx.hero.name .. " n'est visé par personne, la carte ne fait rien.", "sys")
          return
        end
        attacker.next_move = nil
        attacker.target_hero_id = nil
        Combat.deal_damage(ctx.state, ctx.hero, attacker, 6, "physique", ctx)
        Combat.log(ctx.state, "Riposte contre " .. attacker.name .. " !", "you")
      end,
    },
  },
  {
    code = "rempart", name = "Rempart", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    desc = 'Gagne 4 "bouclier". Un allié gagne 4 "bouclier" (+50% sur les deux si joué par le Paladin).',
    effect = function(ctx)
      Combat.grant_defense(ctx.hero, 4, ctx)
      Combat.grant_defense(ctx.target, 4, ctx)
    end,
    upgrade = {
      desc = 'Gagne 6 "bouclier". Un allié gagne 6 "bouclier" (+50% sur les deux si joué par le Paladin).',
      effect = function(ctx)
        Combat.grant_defense(ctx.hero, 6, ctx)
        Combat.grant_defense(ctx.target, 6, ctx)
      end,
    },
  },
  {
    code = "provocation", name = "Provocation", class_id = "paladin", tier = "avance", cost = 0,
    cats = { "defense" }, dmg_type = nil, target = "enemy",
    desc = 'Gagne 6 "bouclier". Devient "cibleennemi" d\'un ennemi.',
    effect = function(ctx)
      Combat.grant_defense(ctx.hero, 6, ctx)
      if ctx.target.next_move and Combat.TARGETABLE_MOVE_KINDS[ctx.target.next_move.kind] then
        ctx.target.target_hero_id = ctx.hero.id
      end
    end,
    upgrade = {
      desc = 'Gagne 9 "bouclier". Devient "cibleennemi" d\'un ennemi.',
      effect = function(ctx)
        Combat.grant_defense(ctx.hero, 9, ctx)
        if ctx.target.next_move and Combat.TARGETABLE_MOVE_KINDS[ctx.target.next_move.kind] then
          ctx.target.target_hero_id = ctx.hero.id
        end
      end,
    },
  },
  {
    code = "clairvoyance", name = "Clairvoyance", class_id = "paladin", tier = "avance", cost = 0,
    cats = { "sort" }, dmg_type = nil, target = "ally",
    desc = '"Pioche" 1. "alliecible" se "concentre". Peut agir à nouveau ce tour.',
    effect = function(ctx)
      Deck = Deck or require("src.rules.deck")
      Deck.draw_cards(ctx.state, 1)
      ctx.target.energy = ctx.target.energy + 1
      Combat.log(ctx.state, ctx.target.name .. " se concentre grâce à Clairvoyance.", "you")
      ctx.hero.has_acted = false
      Combat.log(ctx.state, ctx.hero.name .. " peut encore agir ce tour.", "power")
    end,
    upgrade = {
      desc = '"Pioche" 2. "alliecible" se "concentre". Peut agir à nouveau ce tour.',
      effect = function(ctx)
        Deck = Deck or require("src.rules.deck")
        Deck.draw_cards(ctx.state, 2)
        ctx.target.energy = ctx.target.energy + 1
        Combat.log(ctx.state, ctx.target.name .. " se concentre grâce à Clairvoyance.", "you")
        ctx.hero.has_acted = false
        Combat.log(ctx.state, ctx.hero.name .. " peut encore agir ce tour.", "power")
      end,
    },
  },
  {
    code = "lumiere-divine", name = "Lumière divine", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "defense", "soin", "sort" }, dmg_type = nil, target = "self",
    desc = 'Tous les alliés gagnent 4 "bouclier". "soin" 4 à tous les alliés (+50% pour le bouclier ET le soin si joué par le Paladin).',
    effect = function(ctx)
      for _, h in ipairs(living_heroes(ctx)) do
        Combat.grant_defense(h, 4, ctx)
        Combat.grant_heal(h, 4, ctx)
      end
    end,
    upgrade = {
      desc = 'Tous les alliés gagnent 6 "bouclier". "soin" 6 à tous les alliés (+50% pour le bouclier ET le soin si joué par le Paladin).',
      effect = function(ctx)
        for _, h in ipairs(living_heroes(ctx)) do
          Combat.grant_defense(h, 6, ctx)
          Combat.grant_heal(h, 6, ctx)
        end
      end,
    },
  },
  {
    code = "missile-magique", name = "Missile magique", class_id = "mage", tier = "depart", cost = 3,
    cats = { "sort", "distance", "degats" }, dmg_type = "magique", target = "enemy",
    desc = 'Inflige 8 "etincelle".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 8, "magique", ctx) end,
    upgrade = {
      desc = 'Inflige 12 "etincelle".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 12, "magique", ctx) end,
    },
  },
  {
    code = "image-miroir", name = "Image miroir", class_id = "mage", tier = "avance", cost = 3,
    cats = { "sort", "defense" }, dmg_type = "magique", target = "self",
    desc = 'Gagne "Esquive" 2.',
    effect = function(ctx) Combat.apply_status(ctx, ctx.hero, "esquive", 2) end,
    upgrade = {
      desc = 'Gagne "Esquive" 3.',
      effect = function(ctx) Combat.apply_status(ctx, ctx.hero, "esquive", 3) end,
    },
  },
  {
    code = "tornade-feu", name = "Tornade de feu", class_id = "mage", tier = "avance", cost = 6,
    cats = { "sort", "distance", "degats", "feu" }, dmg_type = "magique", target = "all-enemies",
    desc = 'Inflige 8 "fireball" à tous les ennemis.',
    effect = function(ctx)
      for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 8, "magique", ctx) end
    end,
    upgrade = {
      desc = 'Inflige 12 "fireball" à tous les ennemis.',
      effect = function(ctx)
        for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 12, "magique", ctx) end
      end,
    },
  },
  {
    code = "boule-feu", name = "Boule de feu", class_id = "mage", tier = "avance", cost = 8,
    cats = { "sort", "distance", "degats", "feu" }, dmg_type = "magique", target = "enemy",
    desc = 'Inflige 20 "fireball".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 20, "magique", ctx) end,
    upgrade = {
      desc = 'Inflige 30 "fireball".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 30, "magique", ctx) end,
    },
  },
  {
    code = "strategie", name = "Stratégie", class_id = "assassin", tier = "depart", cost = 0,
    cats = { "melee", "degats", "defense" }, dmg_type = "physique", target = "conditional",
    desc = 'Si "cibleennemi", gagne 4 "bouclier", sinon inflige 4 "epee".',
    effect = function(ctx)
      if Combat.enemy_targeting(ctx.state, ctx.hero) then
        Combat.grant_defense(ctx.hero, 4, ctx)
        Combat.log(ctx.state, ctx.hero.name .. " est visé : Stratégie lui donne 4 défense.", "you")
      else
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx)
      end
    end,
    upgrade = {
      desc = 'Si "cibleennemi", gagne 6 "bouclier", sinon inflige 6 "epee".',
      effect = function(ctx)
        if Combat.enemy_targeting(ctx.state, ctx.hero) then
          Combat.grant_defense(ctx.hero, 6, ctx)
          Combat.log(ctx.state, ctx.hero.name .. " est visé : Stratégie lui donne 6 défense.", "you")
        else
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        end
      end,
    },
  },
  {
    code = "blessure-ouverte", name = "Blessure ouverte", class_id = "assassin", tier = "avance", cost = 2,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 6 "epee" et "Saignements" 3.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
      Combat.apply_status(ctx, ctx.target, "saignements", 3)
    end,
    upgrade = {
      desc = 'Inflige 9 "epee" et "Saignements" 4.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 9, "physique", ctx)
        Combat.apply_status(ctx, ctx.target, "saignements", 4)
      end,
    },
  },
  {
    code = "assassinat", name = "Assassinat", class_id = "assassin", tier = "avance", cost = 4,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Si Camouflé, inflige 12 "epee", sinon gagne Camouflé 1, Puissance 1 et Assassinat va sur le dessus du deck.',
    effect = function(ctx)
      if (ctx.hero.camoufle or 0) > 0 then
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 12, "physique", ctx)
        ctx.hero.camoufle = 0
      else
        Combat.apply_status(ctx, ctx.hero, "camoufle", 1)
        Combat.apply_status(ctx, ctx.hero, "puissance", 1)
        ctx.return_to_deck_top = true
        Combat.log(ctx.state, ctx.hero.name .. " n'est pas Camouflé : Assassinat le rend Camouflé et Puissant, puis retourne au sommet du deck.", "you")
      end
    end,
    upgrade = {
      desc = 'Si Camouflé, inflige 18 "epee", sinon gagne Camouflé 2, Puissance 2 et Assassinat va sur le dessus du deck.',
      effect = function(ctx)
        if (ctx.hero.camoufle or 0) > 0 then
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 18, "physique", ctx)
          ctx.hero.camoufle = 0
        else
          Combat.apply_status(ctx, ctx.hero, "camoufle", 2)
          Combat.apply_status(ctx, ctx.hero, "puissance", 2)
          ctx.return_to_deck_top = true
          Combat.log(ctx.state, ctx.hero.name .. " n'est pas Camouflé : Assassinat le rend Camouflé et Puissant, puis retourne au sommet du deck.", "you")
        end
      end,
    },
  },
  {
    code = "dans-les-ombres", name = "Dans les ombres", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "self",
    desc = 'Gagne 4 "bouclier", 1 "energie" et gagne Camouflé 1.',
    effect = function(ctx)
      Combat.grant_defense(ctx.hero, 4, ctx)
      ctx.hero.energy = ctx.hero.energy + 1
      Combat.apply_status(ctx, ctx.hero, "camoufle", 1)
    end,
    upgrade = {
      desc = 'Gagne 6 "bouclier", 2 "energie" et gagne Camouflé 2.',
      effect = function(ctx)
        Combat.grant_defense(ctx.hero, 6, ctx)
        ctx.hero.energy = ctx.hero.energy + 2
        Combat.apply_status(ctx, ctx.hero, "camoufle", 2)
      end,
    },
  },
}

function Cards.by_code(code)
  for _, c in ipairs(Cards.list) do
    if c.code == code then return c end
  end
  return nil
end

--- Version améliorée d'un def de base (écran "feuDeCamp", 2026-08-10, demande
-- explicite -- une seule amélioration possible par carte, jamais de palier
-- au-delà). Conserve `code` (les recherches Cards.by_code/le glossaire
-- continuent de fonctionner sur l'identité de base), change juste name/desc/
-- effect et marque `is_upgraded` -- c'est ce flag qui exclut la carte du
-- pool de tirage (voir src/rules/feu_de_camp.lua), PAS l'absence de `upgrade`
-- (gardé tel quel, inutilisé, pour ne pas perdre l'info "était améliorable").
function Cards.upgraded_def(def)
  assert(def.upgrade, "carte non améliorable : " .. tostring(def.code))
  local up = {}
  for k, v in pairs(def) do up[k] = v end
  up.name = def.name .. " +"
  up.desc = def.upgrade.desc
  up.effect = def.upgrade.effect
  up.is_upgraded = true
  return up
end

return Cards
