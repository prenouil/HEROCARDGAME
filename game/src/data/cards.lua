-- Les 24 cartes du deck MVP (2026-08-24, rééquilibrage complet -- tableur de
-- Zgrubulu, colonnes Coût en énergie/Mana/Mots clés/Texte/Texte amélioré) :
-- "Coup direct"/"Encaisser" ne sont plus des cartes génériques communes --
-- chaque classe a sa propre copie, avec un `code` distinct mais le même nom
-- affiché (sauf le Mage, voir plus bas).
--
-- Chaque carte porte un champ `upgrade` optionnel (2026-08-10, écran
-- "feuDeCamp") : {desc, effect} de la version "+" -- voir Cards.upgraded_def.
--
-- Cartes regroupées par classe : chaque classe a 3 cartes "depart" (sa
-- "Coup direct" + son "Encaisser" + 1 carte propre) et 3 cartes "avance",
-- pour un deck de départ à 12 cartes (voir Deck.STARTING_DECK_CODES) -- 1
-- exemplaire de chaque carte "depart". Le Guerrier a échangé ses cartes
-- "depart"/"avance" (2026-08-24) : "Coup de taille" est désormais "depart"
-- (dégâts réduits 2->3) et "Coup d'estoc" "avance" -- l'inverse d'avant.
--
-- Encaisser (Guerrier/Paladin/Assassin) et Barrière (Mage, l'équivalent du
-- Mage) ciblent désormais un ALLIÉ (2026-08-24, confirmé explicitement par le
-- porteur de projet) -- ne se donnent plus de bouclier à soi-même.
--
-- Mage : "Coup direct"/"Encaisser" sont renommés "Flamèche"/"Barrière" (codes
-- "flameche"/"barriere", pas "coup-direct-mage"/"encaisser-mage") -- les
-- seules cartes de départ dont le nom diffère des 3 autres classes, en plus
-- d'accorder 1 mana à chaque jeu (voir hero.mana, ressource propre au Mage).
-- Missile magique/Image miroir/Tornade de feu/Boule de feu ont désormais un
-- `mana_cost` en plus de `cost` (voir Combat.can_play). Flamèche/Barrière
-- portent aussi `mana_cost = 0` (2026-08-24, ajouté par le porteur de projet
-- par souci de cohérence visuelle -- la pastille de mana s'affiche sur les 6
-- cartes du Mage, pas seulement les 4 qui en dépensent réellement).
--
-- Assassin : Assassinat/Dans les ombres accordent désormais de la
-- "Discrétion" (Game.gain_discretion, ressource propre à l'Assassin, séparée
-- de Camouflé -- voir game.lua) au lieu de Camouflé directement. Blessure
-- ouverte n'inflige plus le Saignement que si l'Assassin qui la joue est
-- actuellement Camouflé (avant : inconditionnel).

local Combat = require("src.rules.combat")
local Deck -- required en différé pour casser le cycle cards -> deck -> cards.
local Game -- required en différé, même raison : cards -> game -> deck -> cards.

local Cards = {}

local function living_enemies(ctx) return Combat.living_enemies(ctx.state) end
local function living_heroes(ctx) return Combat.living_heroes(ctx.state) end

Cards.list = {
  -- ---------- Guerrier ----------
  {
    code = "coup-direct-guerrier", name = "Coup direct", class_id = "guerrier", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx) end,
    upgrade = {
      desc = 'Inflige 6 "epee".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx) end,
    },
  },
  {
    code = "encaisser-guerrier", name = "Encaisser", class_id = "guerrier", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    desc = 'L\'allié gagne 4 "bouclier".',
    effect = function(ctx) Combat.grant_defense(ctx.target, 4) end,
    upgrade = {
      desc = 'L\'allié gagne 6 "bouclier".',
      effect = function(ctx) Combat.grant_defense(ctx.target, 6) end,
    },
  },
  {
    code = "coup-taille", name = "Coup de taille", class_id = "guerrier", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "all-enemies",
    desc = 'Inflige 2 "epee" à tous les ennemis.',
    effect = function(ctx)
      for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 2, "physique", ctx) end
    end,
    upgrade = {
      desc = 'Inflige 3 "epee" à tous les ennemis.',
      effect = function(ctx)
        for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 3, "physique", ctx) end
      end,
    },
  },
  {
    code = "coup-estoc", name = "Coup d'estoc", class_id = "guerrier", tier = "avance", cost = 1,
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
    code = "coup-mortel", name = "Coup mortel", class_id = "guerrier", tier = "avance", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee". Si cette attaque tue sa cible, Coup mortel revient dans la main du joueur.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx)
      if ctx.target.hp <= 0 then
        ctx.return_to_hand = true
        Combat.log(ctx.state, ctx.hero.name .. " achève " .. ctx.target.name .. " — Coup mortel revient en main.", "power")
      end
    end,
    upgrade = {
      desc = 'Inflige 6 "epee". Si cette attaque tue sa cible, Coup mortel revient dans la main du joueur.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        if ctx.target.hp <= 0 then
          ctx.return_to_hand = true
          Combat.log(ctx.state, ctx.hero.name .. " achève " .. ctx.target.name .. " — Coup mortel revient en main.", "power")
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

  -- ---------- Paladin ----------
  {
    code = "coup-direct-paladin", name = "Coup direct", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx) end,
    upgrade = {
      desc = 'Inflige 6 "epee".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx) end,
    },
  },
  {
    code = "encaisser-paladin", name = "Encaisser", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    desc = 'L\'allié gagne 4 "bouclier".',
    effect = function(ctx) Combat.grant_defense(ctx.target, 4) end,
    upgrade = {
      desc = 'L\'allié gagne 6 "bouclier".',
      effect = function(ctx) Combat.grant_defense(ctx.target, 6) end,
    },
  },
  {
    code = "rempart", name = "Rempart", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    desc = 'L\'allié ciblé gagne 4 "bouclier". Gagne 4 "bouclier".',
    effect = function(ctx)
      Combat.grant_defense(ctx.target, 4)
      Combat.grant_defense(ctx.hero, 4)
    end,
    upgrade = {
      -- Amélioration désormais SYMÉTRIQUE (2026-08-24, corrigé sur le tableur --
      -- avant, 5 pour soi / 6 pour l'allié).
      desc = 'L\'allié ciblé gagne 6 "bouclier". Gagne 6 "bouclier".',
      effect = function(ctx)
        Combat.grant_defense(ctx.target, 6)
        Combat.grant_defense(ctx.hero, 6)
      end,
    },
  },
  {
    code = "provocation", name = "Provocation", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "defense" }, dmg_type = nil, target = "enemy",
    desc = 'L\'ennemi ciblé cible le Paladin. Gagne 6 "bouclier".',
    effect = function(ctx)
      Combat.grant_defense(ctx.hero, 6)
      if ctx.target.next_move and Combat.TARGETABLE_MOVE_KINDS[ctx.target.next_move.kind] then
        ctx.target.target_hero_id = ctx.hero.id
      end
    end,
    upgrade = {
      desc = 'L\'ennemi ciblé cible le Paladin. Gagne 9 "bouclier".',
      effect = function(ctx)
        Combat.grant_defense(ctx.hero, 9)
        if ctx.target.next_move and Combat.TARGETABLE_MOVE_KINDS[ctx.target.next_move.kind] then
          ctx.target.target_hero_id = ctx.hero.id
        end
      end,
    },
  },
  {
    code = "clairvoyance", name = "Clairvoyance", class_id = "paladin", tier = "avance", cost = 0,
    cats = { "sort" }, dmg_type = nil, target = "self",
    desc = '"Pioche" 1. Gagne 1 "energie".',
    effect = function(ctx)
      Deck = Deck or require("src.rules.deck")
      Game = Game or require("src.rules.game")
      Deck.draw_cards(ctx.state, 1)
      Game.gain_energy(ctx.state, 1)
      Combat.log(ctx.state, ctx.hero.name .. " active Clairvoyance : pioche, +1 énergie.", "power")
    end,
    upgrade = {
      desc = '"Pioche" 2. Gagne 1 "energie".',
      effect = function(ctx)
        Deck = Deck or require("src.rules.deck")
        Game = Game or require("src.rules.game")
        Deck.draw_cards(ctx.state, 2)
        Game.gain_energy(ctx.state, 1)
        Combat.log(ctx.state, ctx.hero.name .. " active Clairvoyance : pioche, +1 énergie.", "power")
      end,
    },
  },
  {
    code = "lumiere-divine", name = "Lumière divine", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "defense", "soin", "sort" }, dmg_type = nil, target = "self",
    desc = 'Tous les alliés gagnent 4 "bouclier". "soin" 4 à tous les alliés.',
    effect = function(ctx)
      for _, h in ipairs(living_heroes(ctx)) do
        Combat.grant_defense(h, 4)
        Combat.grant_heal(h, 4)
      end
    end,
    upgrade = {
      desc = 'Tous les alliés gagnent 6 "bouclier". "soin" 6 à tous les alliés.',
      effect = function(ctx)
        for _, h in ipairs(living_heroes(ctx)) do
          Combat.grant_defense(h, 6)
          Combat.grant_heal(h, 6)
        end
      end,
    },
  },

  -- ---------- Mage ----------
  -- Flamèche/Barrière (2026-08-24, remplacent "Coup direct"/"Encaisser" --
  -- seule classe dont les 2 cartes "de base" ont un nom propre) : mêmes mots-
  -- clés/type de dégâts que Coup direct (physique/mêlée, confirmé explicitement,
  -- pas une coquille malgré le thème "feu" du nom) -- la seule vraie différence
  -- est le bonus "Gagne 1 mana" à chaque jeu.
  {
    code = "flameche", name = "Flamèche", class_id = "mage", tier = "depart", cost = 1, mana_cost = 0,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 2 "epee" à un ennemi. Gagne 1 mana.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 2, "physique", ctx)
      Combat.apply_status(ctx.hero, "mana", 1)
    end,
    upgrade = {
      desc = 'Inflige 3 "epee" à un ennemi. Gagne 1 mana.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 3, "physique", ctx)
        Combat.apply_status(ctx.hero, "mana", 1)
      end,
    },
  },
  {
    code = "barriere", name = "Barrière", class_id = "mage", tier = "depart", cost = 1, mana_cost = 0,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    desc = 'L\'allié gagne 2 "bouclier". Gagne 1 mana.',
    effect = function(ctx)
      Combat.grant_defense(ctx.target, 2)
      Combat.apply_status(ctx.hero, "mana", 1)
    end,
    upgrade = {
      desc = 'L\'allié gagne 3 "bouclier". Gagne 1 mana.',
      effect = function(ctx)
        Combat.grant_defense(ctx.target, 3)
        Combat.apply_status(ctx.hero, "mana", 1)
      end,
    },
  },
  {
    code = "missile-magique", name = "Missile magique", class_id = "mage", tier = "depart", cost = 1, mana_cost = 1,
    cats = { "sort", "distance", "degats" }, dmg_type = "magique", target = "enemy",
    desc = 'Inflige 8 "etincelle".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 8, "magique", ctx) end,
    upgrade = {
      desc = 'Inflige 12 "etincelle".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 12, "magique", ctx) end,
    },
  },
  {
    code = "image-miroir", name = "Image miroir", class_id = "mage", tier = "avance", cost = 1, mana_cost = 1,
    cats = { "sort", "defense" }, dmg_type = "magique", target = "self",
    desc = 'Gagne "Esquive" 2.',
    effect = function(ctx) Combat.apply_status(ctx.hero, "esquive", 2) end,
    upgrade = {
      desc = 'Gagne "Esquive" 3.',
      effect = function(ctx) Combat.apply_status(ctx.hero, "esquive", 3) end,
    },
  },
  {
    code = "tornade-feu", name = "Tornade de feu", class_id = "mage", tier = "avance", cost = 1, mana_cost = 2,
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
    code = "boule-feu", name = "Boule de feu", class_id = "mage", tier = "avance", cost = 2, mana_cost = 3,
    cats = { "sort", "distance", "degats", "feu" }, dmg_type = "magique", target = "enemy",
    desc = 'Inflige 20 "fireball".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 20, "magique", ctx) end,
    upgrade = {
      desc = 'Inflige 30 "fireball".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 30, "magique", ctx) end,
    },
  },

  -- ---------- Assassin ----------
  {
    code = "coup-direct-assassin", name = "Coup direct", class_id = "assassin", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 4 "epee".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx) end,
    upgrade = {
      desc = 'Inflige 6 "epee".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx) end,
    },
  },
  {
    code = "encaisser-assassin", name = "Encaisser", class_id = "assassin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    desc = 'L\'allié gagne 4 "bouclier".',
    effect = function(ctx) Combat.grant_defense(ctx.target, 4) end,
    upgrade = {
      desc = 'L\'allié gagne 6 "bouclier".',
      effect = function(ctx) Combat.grant_defense(ctx.target, 6) end,
    },
  },
  {
    code = "strategie", name = "Stratégie", class_id = "assassin", tier = "depart", cost = 0,
    cats = { "melee", "degats", "defense" }, dmg_type = "physique", target = "conditional",
    desc = 'Si "cibleennemi", gagne 4 "bouclier", sinon inflige 4 "epee".',
    effect = function(ctx)
      if Combat.enemy_targeting(ctx.state, ctx.hero) then
        Combat.grant_defense(ctx.hero, 4)
        Combat.log(ctx.state, ctx.hero.name .. " est visé : Stratégie lui donne 4 défense.", "you")
      else
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx)
      end
    end,
    upgrade = {
      desc = 'Si "cibleennemi", gagne 6 "bouclier", sinon inflige 6 "epee".',
      effect = function(ctx)
        if Combat.enemy_targeting(ctx.state, ctx.hero) then
          Combat.grant_defense(ctx.hero, 6)
          Combat.log(ctx.state, ctx.hero.name .. " est visé : Stratégie lui donne 6 défense.", "you")
        else
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        end
      end,
    },
  },
  {
    -- Saignement désormais CONDITIONNEL (2026-08-24, confirmé explicitement --
    -- avant, inconditionnel) : "Camouflé" ici désigne l'état de l'Assassin qui
    -- joue la carte (hero.camoufle > 0), pas la cible.
    code = "blessure-ouverte", name = "Blessure ouverte", class_id = "assassin", tier = "avance", cost = 2,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Inflige 6 "epee". Si Camouflé, inflige "Saignements" 3.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
      if (ctx.hero.camoufle or 0) > 0 then
        Combat.apply_status(ctx.target, "saignements", 3)
      end
    end,
    upgrade = {
      desc = 'Inflige 9 "epee". Si Camouflé, inflige "Saignements" 4.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 9, "physique", ctx)
        if (ctx.hero.camoufle or 0) > 0 then
          Combat.apply_status(ctx.target, "saignements", 4)
        end
      end,
    },
  },
  {
    -- Discrétion (2026-08-24, remplace Camouflé comme récompense directe --
    -- statut DISTINCT de Camouflé, voir Game.gain_discretion/hero.discretion
    -- dans game.lua) : le seul chemin vers Camouflé est désormais d'atteindre
    -- 10 Discrétion, jamais un octroi direct par une carte.
    code = "assassinat", name = "Assassinat", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    desc = 'Si Camouflé, inflige 12 "epee", et perd Camouflé, sinon gagne "Discrétion" 2, "Puissance" 2 et Assassinat va sur le dessus du deck.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      if (ctx.hero.camoufle or 0) > 0 then
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 12, "physique", ctx)
        ctx.hero.camoufle = 0
      else
        Game.gain_discretion(ctx.state, ctx.hero, 2)
        Combat.apply_status(ctx.hero, "puissance", 2)
        ctx.return_to_deck_top = true
        Combat.log(ctx.state, ctx.hero.name .. " n'est pas Camouflé : Assassinat lui donne de la Discrétion et de la Puissance, puis retourne au sommet du deck.", "you")
      end
    end,
    upgrade = {
      desc = 'Si Camouflé, inflige 18 "epee", et perd Camouflé, sinon gagne "Discrétion" 3, "Puissance" 3 et Assassinat va sur le dessus du deck.',
      effect = function(ctx)
        Game = Game or require("src.rules.game")
        if (ctx.hero.camoufle or 0) > 0 then
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 18, "physique", ctx)
          ctx.hero.camoufle = 0
        else
          Game.gain_discretion(ctx.state, ctx.hero, 3)
          Combat.apply_status(ctx.hero, "puissance", 3)
          ctx.return_to_deck_top = true
          Combat.log(ctx.state, ctx.hero.name .. " n'est pas Camouflé : Assassinat lui donne de la Discrétion et de la Puissance, puis retourne au sommet du deck.", "you")
        end
      end,
    },
  },
  {
    code = "dans-les-ombres", name = "Dans les ombres", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "self",
    desc = 'Gagne 4 "bouclier", 1 "energie" et 3 "Discrétion".',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Combat.grant_defense(ctx.hero, 4)
      Game.gain_energy(ctx.state, 1)
      Game.gain_discretion(ctx.state, ctx.hero, 3)
    end,
    upgrade = {
      desc = 'Gagne 6 "bouclier", 2 "energie" et 5 "Discrétion".',
      effect = function(ctx)
        Game = Game or require("src.rules.game")
        Combat.grant_defense(ctx.hero, 6)
        Game.gain_energy(ctx.state, 2)
        Game.gain_discretion(ctx.state, ctx.hero, 5)
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
