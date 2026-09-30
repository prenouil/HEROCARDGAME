-- Les 24 cartes du deck MVP (2026-08-24, rééquilibrage complet -- tableur de
-- Zgrubulu, colonnes Coût en énergie/Mana/Mots clés/Texte/Texte amélioré) :
-- "Coup direct"/"Encaisser" ne sont plus des cartes génériques communes --
-- chaque classe a sa propre copie, avec un `code` distinct mais le même nom
-- affiché (sauf le Mage, voir plus bas).
--
-- Chaque carte porte un champ `upgrade` optionnel (2026-08-10, écran "La
-- Forge") : {desc, effect} de la version "+" -- voir Cards.upgraded_def.
--
-- Cartes regroupées par classe : chaque classe a 3 cartes "depart" (sa
-- "Coup direct" + son "Encaisser" + 1 carte propre) et 3 cartes "avance" --
-- 1 exemplaire de chaque carte "depart" des 4 classes sélectionnées à
-- l'écran de choix d'équipe forme le deck de départ (2026-08-29, voir
-- Deck.build_starting_deck/Deck.starting_cards_for_class). Le Guerrier a échangé ses cartes
-- "depart"/"avance" (2026-08-24) : "Coup de taille" est désormais "depart"
-- (dégâts réduits 2->3) et "Coup d'estoc" "avance" -- l'inverse d'avant.
--
-- Encaisser (Guerrier/Paladin/Assassin) et Barrière (Mage, l'équivalent du
-- Mage) ciblent désormais un ALLIÉ (2026-08-24, confirmé explicitement par le
-- porteur de projet) -- ne se donnent plus de bouclier à soi-même.
--
-- Mage : "Coup direct"/"Encaisser" sont renommés "Main de feu"/"Barrière"
-- (codes "flameche"/"barriere", pas "coup-direct-mage"/"encaisser-mage") --
-- les seules cartes de départ dont le nom diffère des 3 autres classes, en
-- plus d'accorder 1 mana à chaque jeu (voir hero.mana, ressource propre au
-- Mage). "Main de feu" (ex-"Flamèche", renommée une 2ᵉ fois 2026-08-24 --
-- voir sa def plus bas) est un vrai coup de feu, magique, tag "feu".
-- Missile magique/Image miroir/Tornade de feu/Boule de feu ont désormais un
-- `mana_cost` en plus de `cost` (voir Combat.can_play). Main de feu/Barrière
-- portent aussi `mana_cost = 0` (2026-08-24, ajouté par le porteur de projet
-- par souci de cohérence visuelle -- la pastille de mana s'affiche sur les 6
-- cartes du Mage, pas seulement les 4 qui en dépensent réellement).
--
-- Assassin : refonte complète des 6 cartes (2026-08-28, tableur fourni) --
-- voir le bloc de cartes plus bas pour le détail. Toutes tagguées "Furtif"
-- (glossary.lua) : ne fait pas perdre Discrétion/Camouflé en la jouant
-- (Game.on_card_played), rapporte 2 Discrétion si défaussée sans avoir été
-- jouée (Game.grant_furtif_discard_discretion). Les 3 "depart" ont aussi
-- changé de nom, à l'instar du Mage avant elles (plus de "Coup direct"/
-- "Encaisser" génériques) : "Plan d'attaque"/"Se cacher"/"Repli stratégique".

local Combat = require("src.rules.combat")
local Deck -- required en différé pour casser le cycle cards -> deck -> cards.
local Game -- required en différé, même raison : cards -> game -> deck -> cards.

local Cards = {}

local function living_enemies(ctx) return Combat.living_enemies(ctx.state) end
local function living_heroes(ctx) return Combat.living_heroes(ctx.state) end

Cards.list = {
  -- ---------- Guerrier ----------
  -- Refonte (2026-08-28, demande explicite -- tableur fourni) : "Encaisser"/
  -- "Coup mortel" remplacées par "Coup appuyé"/"Avalanche de coups" (le
  -- Guerrier n'a donc plus de carte de bouclier "depart" propre -- seul le
  -- générique Encaisser d'une autre classe... non, en fait plus AUCUNE, cette
  -- case du kit devient un 2ᵉ coup offensif). Coup direct passe à coût 0
  -- (confirmé par le tableur, pas une coquille). Riposte entièrement
  -- retravaillée : la riposte est maintenant proportionnelle aux dégâts
  -- annulés (moitié/totalité) plutôt qu'un montant fixe.
  {
    -- Remplace "Coup direct" (2026-09-02, demande explicite -- devient une
    -- vraie carte à choix de cible : un ennemi (dégâts) OU un allié
    -- (bouclier), jamais les deux à la fois). `target = "enemy-or-ally"`
    -- (nouveau mode, voir Game.resolve_pending/input.lua/view.lua -- mêmes
    -- points de branchement que "conditional") : le joueur clique librement
    -- un ennemi ou un allié, `ctx.target` est résolu avant l'effet comme pour
    -- "enemy"/"ally" -- l'effet distingue les deux via Combat.hero_by_id
    -- (present côté héros seulement, jamais côté ennemi).
    -- Renommée "Combat aguerri" (2026-09-12, demande explicite -- nom trop
    -- long pour tenir sur 1 ligne dans le nouveau cartouche de carte, voir
    -- draw_card_face dans view.lua) : code interne inchangé.
    code = "coup-direct-guerrier", name = "Combat aguerri", class_id = "guerrier", tier = "depart", cost = 0,
    cats = { "melee", "degats", "defense" }, dmg_type = "physique", target = "enemy-or-ally",
    -- Type (2026-09-03, demande explicite) : "cible un ennemi (dégâts) OU un
    -- allié (bouclier)" -- les 2 branches sont un choix explicite du joueur,
    -- comparables en poids -- dual dès le tableur, pas une exception.
    types = { "offensive", "support" },
    desc = 'Inflige 4 "epee" à un ennemi OU 4 "bouclier" à un allié.',
    effect = function(ctx)
      if Combat.hero_by_id(ctx.state, ctx.target.id) then
        Combat.grant_defense(ctx.target, 4, ctx)
      else
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx)
      end
    end,
    upgrade = {
      desc = 'Inflige 6 "epee" à un ennemi OU 6 "bouclier" à un allié.',
      effect = function(ctx)
        if Combat.hero_by_id(ctx.state, ctx.target.id) then
          Combat.grant_defense(ctx.target, 6, ctx)
        else
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        end
      end,
    },
  },
  {
    -- Remplace "Encaisser" (2026-08-28) : un 2ᵉ coup offensif, plus de
    -- bouclier propre au Guerrier en "depart" -- "Vulnerabilite" (pas
    -- "Vulnérable", le mot du tableur -- même clé de glossaire que partout
    -- ailleurs dans le jeu, voir glossary.lua).
    code = "coup-appuye", name = "Coup appuyé", class_id = "guerrier", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    desc = 'Inflige 6 "epee" et "Vulnerabilite" 2 à un ennemi.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
      Combat.apply_status(ctx.target, "vulnerabilite", 2)
    end,
    upgrade = {
      desc = 'Inflige 9 "epee" et "Vulnerabilite" 3 à un ennemi.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 9, "physique", ctx)
        Combat.apply_status(ctx.target, "vulnerabilite", 3)
      end,
    },
  },
  {
    code = "coup-taille", name = "Coup de taille", class_id = "guerrier", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "all-enemies",
    types = { "offensive" },
    desc = 'Inflige 3 "epee" à tous les ennemis.',
    effect = function(ctx)
      for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 3, "physique", ctx) end
    end,
    -- 2026-09-02, demande explicite : amélioration = coût 0 (au lieu de 1),
    -- sans changer les dégâts (Cards.upgraded_def lit `cost` ici).
    upgrade = {
      desc = 'Coût 0. Inflige 3 "epee" à tous les ennemis.',
      cost = 0,
      effect = function(ctx)
        for _, e in ipairs(living_enemies(ctx)) do Combat.deal_damage(ctx.state, ctx.hero, e, 3, "physique", ctx) end
      end,
    },
  },
  {
    -- Condition étendue au Bouclier OU à Vulnérabilité (2026-08-28, avant :
    -- Bouclier seul).
    code = "coup-estoc", name = "Coup Contandant", class_id = "guerrier", tier = "avance", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    desc = 'Inflige 4 "epee". Inflige 4 "epee" de plus si l\'ennemi a du "bouclier" ou "Vulnerabilite".',
    effect = function(ctx)
      local vulnerable = (ctx.target.defense or 0) > 0 or (ctx.target.vulnerabilite or 0) > 0
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, vulnerable and 8 or 4, "physique", ctx)
    end,
    upgrade = {
      desc = 'Inflige 6 "epee". Inflige 6 "epee" de plus si l\'ennemi a du "bouclier" ou "Vulnerabilite".',
      effect = function(ctx)
        local vulnerable = (ctx.target.defense or 0) > 0 or (ctx.target.vulnerabilite or 0) > 0
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, vulnerable and 12 or 6, "physique", ctx)
      end,
    },
  },
  {
    -- Remplace "Coup mortel" (2026-08-28) : garde son "revient en main si la
    -- cible meurt", ajoute "et son coût devient 0" -- PERMANENT sur CETTE
    -- copie de carte précise (voir Game.finish_card/ctx.zero_cost), jamais un
    -- coût gratuit ponctuel pour ce seul lancer. Base/amélioré identiques
    -- dans le tableur fourni (probable oubli, comme "Se cacher" avant) --
    -- dégâts relevés 4->6 pour rester cohérent avec le reste du jeu, à
    -- confirmer si 4 était réellement voulu.
    code = "avalanche-coups", name = "Avalanche de coups", class_id = "guerrier", tier = "avance", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    desc = 'Inflige 4 "epee", son coût devient 0 jusqu\'à la fin du combat. S\'il tue la cible, revient en main.',
    effect = function(ctx)
      ctx.zero_cost = true
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 4, "physique", ctx)
      if ctx.target.hp <= 0 then
        ctx.return_to_hand = true
        Combat.log(ctx.state, ctx.hero.name .. " achève " .. ctx.target.name .. " — Avalanche de coups revient en main.", "power")
      end
    end,
    upgrade = {
      desc = 'Inflige 6 "epee", son coût devient 0 jusqu\'à la fin du combat. S\'il tue la cible, revient en main.',
      effect = function(ctx)
        ctx.zero_cost = true
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        if ctx.target.hp <= 0 then
          ctx.return_to_hand = true
          Combat.log(ctx.state, ctx.hero.name .. " achève " .. ctx.target.name .. " — Avalanche de coups revient en main.", "power")
        end
      end,
    },
  },
  {
    -- Retravaillée (2026-08-28) : la riposte est désormais proportionnelle
    -- aux dégâts annulés (moitié en base, totalité amélioré) plutôt qu'un
    -- montant fixe (4/6 avant). `attacker.next_move.amount` = le montant déjà
    -- télégraphié au joueur sur le cadre de l'ennemi -- seule source de
    -- vérité sur "les dégâts" de l'attaque annulée, jamais recalculé
    -- indépendamment. Ne se déclenche que contre une attaque de dégâts
    -- (next_move.kind == "dmg") -- "la moitié/totalité DES DÉGÂTS" n'a pas de
    -- sens contre un débuff (ex. Malédiction) qui n'inflige rien à annuler ;
    -- Riposte ne fait alors rien, comme quand personne ne vise le Guerrier.
    -- Rewrite multi-ennemis (2026-09-02, demande explicite -- "si plusieurs
    -- ennemis ciblent le Guerrier, TOUTES les attaques sont annulées et
    -- chaque ennemi reçoit les dégâts qu'il devait infliger") : boucle sur
    -- TOUS les ennemis dont l'action télégraphiée vise le Guerrier (même
    -- geste que Repli stratégique côté Assassin, voir plus haut) au lieu de
    -- s'arrêter au premier trouvé (Combat.enemy_targeting) -- chacun annule
    -- SA PROPRE attaque et reçoit SES PROPRES dégâts en retour (moitié/
    -- totalité), jamais un montant partagé/mutualisé entre eux.
    code = "riposte", name = "Riposte", class_id = "guerrier", tier = "avance", cost = 2,
    cats = { "melee", "degats", "defense" }, dmg_type = "physique", target = "self",
    -- Type (2026-09-03) : dual comme le tag "defense" du dessus le suggère
    -- déjà -- annule l'attaque (protège le Guerrier, Support) ET inflige les
    -- dégâts en retour à l'ennemi (Offensive), les 2 dans le MÊME geste.
    types = { "offensive", "support" },
    -- Raccourcie (2026-09-12, redesign de la carte -- zone de texte réduite) :
    -- même effet (toutes les attaques annulées, un par un ennemi), texte
    -- resserré pour tenir dans le nouveau gabarit (débordait sous la carte
    -- au rendu -- c'était la description la plus longue du jeu).
    desc = 'Annule chaque attaque de "cibleennemi", renvoie la moitié des dégâts.',
    effect = function(ctx)
      local count = 0
      for _, e in ipairs(ctx.state.enemies) do
        if e.hp > 0 and e.next_move and e.next_move.kind == "dmg" and e.target_hero_id == ctx.hero.id then
          local retaliation = e.next_move.amount * 0.5
          e.next_move = nil
          e.target_hero_id = nil
          Combat.deal_damage(ctx.state, ctx.hero, e, retaliation, "physique", ctx)
          count = count + 1
        end
      end
      if count > 0 then
        Combat.log(ctx.state, "Riposte contre " .. count .. " ennemi(s) !", "you")
      else
        Combat.log(ctx.state, "Riposte : " .. ctx.hero.name .. " n'est visé par aucune attaque de dégâts, la carte ne fait rien.", "sys")
      end
    end,
    upgrade = {
      desc = 'Annule chaque attaque de "cibleennemi", renvoie la totalité des dégâts.',
      effect = function(ctx)
        local count = 0
        for _, e in ipairs(ctx.state.enemies) do
          if e.hp > 0 and e.next_move and e.next_move.kind == "dmg" and e.target_hero_id == ctx.hero.id then
            local retaliation = e.next_move.amount
            e.next_move = nil
            e.target_hero_id = nil
            Combat.deal_damage(ctx.state, ctx.hero, e, retaliation, "physique", ctx)
            count = count + 1
          end
        end
        if count > 0 then
          Combat.log(ctx.state, "Riposte contre " .. count .. " ennemi(s) !", "you")
        else
          Combat.log(ctx.state, "Riposte : " .. ctx.hero.name .. " n'est visé par aucune attaque de dégâts, la carte ne fait rien.", "sys")
        end
      end,
    },
  },

  -- Enchantements (2026-09-03, demande explicite -- "type" de carte à part,
  -- ni Offensive ni Support : ne cible personne, ne fait rien sur le moment,
  -- pose juste un pouvoir passif permanent (pour le combat en cours) sur
  -- l'aventurier qui la joue, qui réagit ensuite à un évènement de jeu précis.
  -- Toujours "avance" (jamais "depart", demande explicite), `target = "self"`
  -- comme toute carte sans choix de cible (le joueur clique juste pour
  -- confirmer) -- `effect` ne fait QUE poser le champ sur `ctx.hero`, tout le
  -- reste du pouvoir vit dans les hooks des règles (voir combat.lua/game.lua,
  -- champs hero.instinct_chasseur/frenesie_step/etc.). Conçues avec
  -- agent_content (voir content/memory/reference_enchantement-mecanique.md).
  {
    code = "instinct-chasseur", name = "Instinct du Chasseur", class_id = "guerrier", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Gagne 4 "bouclier" à chaque coup porté à un ennemi.',
    effect = function(ctx) ctx.hero.instinct_chasseur = 4 end,
    upgrade = {
      desc = 'Gagne 6 "bouclier" à chaque coup porté à un ennemi.',
      effect = function(ctx) ctx.hero.instinct_chasseur = 6 end,
    },
  },
  {
    -- `frenesie_bonus_pct` (déjà à 0 par défaut, voir fresh_hero/carried_hero
    -- dans game.lua) : posé explicitement ici aussi pour rester correct même
    -- si un futur champ par défaut changeait -- ne fait jamais de mal de le
    -- réaffirmer à 0 au moment où Frénésie s'active.
    code = "frenesie", name = "Frénésie", class_id = "guerrier", tier = "avance", cost = 2,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = '+50% de dégâts par carte Offensive déjà jouée ce tour.',
    effect = function(ctx) ctx.hero.frenesie_step = 0.5; ctx.hero.frenesie_bonus_pct = ctx.hero.frenesie_bonus_pct or 0 end,
    upgrade = {
      desc = '+75% de dégâts par carte Offensive déjà jouée ce tour.',
      effect = function(ctx) ctx.hero.frenesie_step = 0.75; ctx.hero.frenesie_bonus_pct = ctx.hero.frenesie_bonus_pct or 0 end,
    },
  },

  -- ---------- Paladin ----------
  -- Refonte des 3 cartes "depart" restantes + Provocation/Clairvoyance/Lumière
  -- divine (2026-08-28, demande explicite -- tableur fourni) : "Coup direct"/
  -- "Encaisser" disparaissent complètement (remplacées par Provocateur/
  -- Infranchissable, en plus de Rempart déjà propre au Paladin) -- le Paladin
  -- n'a donc plus AUCUNE carte de dégâts, devient un pur tank/support. Nouveau
  -- statut "Provocation" (+50% de chances d'être ciblé par les ennemis, -1 par
  -- tour -- voir Encounter.pick_hero_target/Game.start_turn) distinct de
  -- l'ancienne carte "Provocation" (renommée "Raillerie" pour éviter la
  -- confusion des noms, effet inchangé : redirection immédiate d'UN ennemi).
  {
    code = "rempart", name = "Rempart", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    types = { "support" },
    desc = 'L\'allié ciblé gagne 4 "bouclier". Gagne 4 "bouclier".',
    effect = function(ctx)
      Combat.grant_defense(ctx.target, 4, ctx)
      Combat.grant_defense(ctx.hero, 4, ctx)
    end,
    upgrade = {
      -- Amélioration désormais SYMÉTRIQUE (2026-08-24, corrigé sur le tableur --
      -- avant, 5 pour soi / 6 pour l'allié).
      desc = 'L\'allié ciblé gagne 6 "bouclier". Gagne 6 "bouclier".',
      effect = function(ctx)
        Combat.grant_defense(ctx.target, 6, ctx)
        Combat.grant_defense(ctx.hero, 6, ctx)
      end,
    },
  },
  {
    -- Provocation accordée au LANCEUR (le Paladin), pas à l'allié qui reçoit le
    -- bouclier (2026-08-28, lecture retenue -- "je protège mon allié ET
    -- j'attire l'attention sur moi" ; cohérent avec Infranchissable ci-dessous,
    -- où tout s'applique à soi). Coût confirmé explicitement à 1 (vide dans le
    -- tableur fourni).
    code = "provocateur", name = "Provocateur", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    types = { "support" },
    desc = 'L\'allié ciblé gagne 4 "bouclier". Gagne "Provocation" 2.',
    effect = function(ctx)
      Combat.grant_defense(ctx.target, 4, ctx)
      Combat.apply_status(ctx.hero, "provocation", 2)
    end,
    upgrade = {
      desc = 'L\'allié ciblé gagne 6 "bouclier". Gagne "Provocation" 3.',
      effect = function(ctx)
        Combat.grant_defense(ctx.target, 6, ctx)
        Combat.apply_status(ctx.hero, "provocation", 3)
      end,
    },
  },
  {
    -- Bouclier "programmé" (2026-08-28, voir Game.schedule_shield) : la
    -- version améliorée programme 2 gains DISTINCTS (au début du tour+1 ET du
    -- tour+2), pas un seul gain doublé plus tard.
    code = "infranchissable", name = "Infranchissable", class_id = "paladin", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Gagne 10 "bouclier". Gagne 10 "bouclier" au début du prochain tour. Gagne "Provocation" 2.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Combat.grant_defense(ctx.hero, 10, ctx)
      Game.schedule_shield(ctx.hero, 10, 1)
      Combat.apply_status(ctx.hero, "provocation", 2)
    end,
    upgrade = {
      desc = 'Gagne 15 "bouclier". Gagne 15 "bouclier" au début des 2 prochains tours. Gagne "Provocation" 3.',
      effect = function(ctx)
        Game = Game or require("src.rules.game")
        Combat.grant_defense(ctx.hero, 15, ctx)
        Game.schedule_shield(ctx.hero, 15, 1)
        Game.schedule_shield(ctx.hero, 15, 2)
        Combat.apply_status(ctx.hero, "provocation", 3)
      end,
    },
  },
  {
    -- Renommée "Raillerie" (2026-08-28, remplace "Provocation" -- ce nom
    -- désigne désormais le nouveau statut, voir plus haut) : effet identique à
    -- avant (redirection immédiate d'UN ennemi vers le Paladin, sans passer
    -- par le statut Provocation), juste rééquilibrée 6/9 -> 8/12.
    code = "raillerie", name = "Raillerie", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "defense" }, dmg_type = nil, target = "enemy",
    -- Type (2026-09-03) : Support malgré `target = "enemy"` -- ne touche à
    -- AUCUN moment les PV/statuts de la cible, ne fait que rediriger son
    -- attaque tout en se blindant soi-même. Aucun dégât, jamais Offensive.
    types = { "support" },
    desc = 'L\'ennemi ciblé cible le Paladin. Gagne 8 "bouclier".',
    effect = function(ctx)
      Combat.grant_defense(ctx.hero, 8, ctx)
      if ctx.target.next_move and Combat.TARGETABLE_MOVE_KINDS[ctx.target.next_move.kind] then
        ctx.target.target_hero_id = ctx.hero.id
      end
    end,
    upgrade = {
      desc = 'L\'ennemi ciblé cible le Paladin. Gagne 12 "bouclier".',
      effect = function(ctx)
        Combat.grant_defense(ctx.hero, 12, ctx)
        if ctx.target.next_move and Combat.TARGETABLE_MOVE_KINDS[ctx.target.next_move.kind] then
          ctx.target.target_hero_id = ctx.hero.id
        end
      end,
    },
  },
  {
    -- +soin à soi et tag "Amnésie" ajoutés (2026-08-28) : voir Game.finish_card/
    -- state.exhausted -- cette carte disparaît de la rotation du combat en
    -- cours après avoir été jouée, revient au combat suivant.
    code = "clairvoyance", name = "Clairvoyance", class_id = "paladin", tier = "avance", cost = 0,
    cats = { "sort", "amnesie" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = '"Pioche" 1. Gagne 1 "energie". "soin" 4. "Amnesie"',
    effect = function(ctx)
      Deck = Deck or require("src.rules.deck")
      Game = Game or require("src.rules.game")
      local drawn = Deck.draw_cards(ctx.state, 1)
      -- "Le Maladroit" (2026-08-29) : cette pioche EN COURS DE TOUR passe aussi
      -- par le filtre, même si elle ne vient pas de Game.fill_hand_with_bonus_draws
      -- (seul le début de tour y passe automatiquement).
      ctx.state.last_drawn_uids = Game.apply_maladroit_discards(ctx.state, drawn)
      Game.gain_energy(ctx.state, 1)
      Combat.grant_heal(ctx.hero, 4, ctx)
      Combat.log(ctx.state, ctx.hero.name .. " active Clairvoyance : pioche, +1 énergie, +4 PV.", "power")
    end,
    upgrade = {
      desc = '"Pioche" 2. Gagne 1 "energie". "soin" 6. "Amnesie"',
      effect = function(ctx)
        Deck = Deck or require("src.rules.deck")
        Game = Game or require("src.rules.game")
        local drawn = Deck.draw_cards(ctx.state, 2)
        ctx.state.last_drawn_uids = Game.apply_maladroit_discards(ctx.state, drawn)
        Game.gain_energy(ctx.state, 1)
        Combat.grant_heal(ctx.hero, 6, ctx)
        Combat.log(ctx.state, ctx.hero.name .. " active Clairvoyance : pioche, +1 énergie, +6 PV.", "power")
      end,
    },
  },
  {
    -- Bouclier relevé 4/6 -> 6/9 et tag "Amnésie" ajouté (2026-08-28) : soin
    -- inchangé (4/6).
    code = "lumiere-divine", name = "Lumière divine", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "defense", "soin", "sort", "amnesie" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Tous les alliés gagnent 6 "bouclier". "soin" 4 à tous les alliés. "Amnesie"',
    effect = function(ctx)
      for _, h in ipairs(living_heroes(ctx)) do
        Combat.grant_defense(h, 6, ctx)
        Combat.grant_heal(h, 4, ctx)
      end
    end,
    upgrade = {
      desc = 'Tous les alliés gagnent 9 "bouclier". "soin" 6 à tous les alliés. "Amnesie"',
      effect = function(ctx)
        for _, h in ipairs(living_heroes(ctx)) do
          Combat.grant_defense(h, 9, ctx)
          Combat.grant_heal(h, 6, ctx)
        end
      end,
    },
  },

  -- Enchantements (2026-09-03, voir le commentaire au-dessus des 2 premiers,
  -- côté Guerrier, pour le principe général).
  {
    code = "bouclier-vivant", name = "Bouclier vivant", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'La moitié de son "bouclier" gagné va aussi à l\'autre allié le plus bas en PV.',
    effect = function(ctx) ctx.hero.bouclier_vivant_ratio = 0.5 end,
    upgrade = {
      desc = 'Tout son "bouclier" gagné va aussi à l\'autre allié le plus bas en PV.',
      effect = function(ctx) ctx.hero.bouclier_vivant_ratio = 1.0 end,
    },
  },
  {
    code = "bouclier-pointes", name = "Bouclier de pointes", class_id = "paladin", tier = "avance", cost = 2,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Chaque "bouclier" absorbé inflige 1 dégât brut à l\'attaquant.',
    effect = function(ctx) ctx.hero.shield_thorns = 1 end,
    upgrade = {
      desc = 'Chaque "bouclier" absorbé inflige 2 dégâts brut à l\'attaquant.',
      effect = function(ctx) ctx.hero.shield_thorns = 2 end,
    },
  },

  -- ---------- Mage ----------
  -- "Main de feu"/Barrière (2026-08-24, remplacent "Coup direct"/"Encaisser" --
  -- seule classe dont les 2 cartes "de base" ont un nom propre). Renommée
  -- une 2ᵉ fois (2026-08-24, revirement explicite -- "Flamèche est un dégâts
  -- de feu et se renomme 'Main de feu'") : d'abord gardée physique/mêlée
  -- malgré son nom "feu" (voir git log), maintenant un VRAI coup de feu --
  -- magique, tag "feu" (déclenche la sensibilité au feu de l'Homme Arbre, voir
  -- Combat.damage_multiplier, ET la Régénération bloquée du Troll, déjà
  -- existante) -- code interne "flameche" conservé (Deck.starting_cards_for_class le retrouve par class_id+tier, pas par ce code).
  {
    code = "flameche", name = "Main de feu", class_id = "mage", tier = "depart", cost = 1, mana_cost = 0,
    cats = { "melee", "degats", "feu" }, dmg_type = "magique", target = "enemy",
    -- Type (2026-09-03) : le gain de mana à soi reste incidental (ressource
    -- pour plus tard, pas un bénéfice immédiat comparable à un dégât/soin/
    -- bouclier) -- Offensive seule, comme le reste des cartes de dégâts qui
    -- accordent aussi une ressource mineure en passant (voir Barrière
    -- ci-dessous pour l'équivalent symétrique côté Support).
    types = { "offensive" },
    desc = 'Inflige 2 "etincelle" à un ennemi. Gagne 1 "mana".',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 2, "magique", ctx)
      Combat.apply_status(ctx.hero, "mana", 1)
    end,
    -- Gagne 2 mana en version améliorée (2026-08-30, demande explicite --
    -- avant, 1 mana comme la version de base, seuls les dégâts montaient) :
    -- donne enfin à l'amélioration un intérêt sur SA ressource propre, pas
    -- seulement sur les dégâts infligés.
    upgrade = {
      desc = 'Inflige 3 "etincelle" à un ennemi. Gagne 2 "mana".',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 3, "magique", ctx)
        Combat.apply_status(ctx.hero, "mana", 2)
      end,
    },
  },
  {
    code = "barriere", name = "Barrière", class_id = "mage", tier = "depart", cost = 1, mana_cost = 0,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    types = { "support" },
    desc = 'L\'allié gagne 2 "bouclier". Gagne 1 "mana".',
    effect = function(ctx)
      Combat.grant_defense(ctx.target, 2, ctx)
      Combat.apply_status(ctx.hero, "mana", 1)
    end,
    -- Gagne 2 mana en version améliorée (2026-08-30, demande explicite --
    -- même correctif que "Main de feu" ci-dessus, voir son commentaire).
    upgrade = {
      desc = 'L\'allié gagne 3 "bouclier". Gagne 2 "mana".',
      effect = function(ctx)
        Combat.grant_defense(ctx.target, 3, ctx)
        Combat.apply_status(ctx.hero, "mana", 2)
      end,
    },
  },
  {
    code = "missile-magique", name = "Missile magique", class_id = "mage", tier = "depart", cost = 1, mana_cost = 1,
    cats = { "sort", "distance", "degats" }, dmg_type = "magique", target = "enemy",
    types = { "offensive" },
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
    types = { "support" },
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
    types = { "offensive" },
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
    types = { "offensive" },
    desc = 'Inflige 20 "fireball".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 20, "magique", ctx) end,
    upgrade = {
      desc = 'Inflige 30 "fireball".',
      effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 30, "magique", ctx) end,
    },
  },

  -- Enchantements (2026-09-03, voir le commentaire au-dessus des 2 premiers,
  -- côté Guerrier, pour le principe général).
  {
    code = "combustion-differee", name = "Combustion différée", class_id = "mage", tier = "avance", cost = 2,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Ses dégâts "feu" appliquent "Brulure" 1 à la cible.',
    effect = function(ctx) ctx.hero.combustion_differee = 1 end,
    upgrade = {
      desc = 'Ses dégâts "feu" appliquent "Brulure" 2 à la cible.',
      effect = function(ctx) ctx.hero.combustion_differee = 2 end,
    },
  },
  {
    code = "second-souffle", name = "Second Souffle", class_id = "mage", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Regagne 2 mana à chaque fois qu\'il tombe à 0.',
    effect = function(ctx) ctx.hero.second_souffle = 2 end,
    upgrade = {
      desc = 'Regagne 3 mana à chaque fois qu\'il tombe à 0.',
      effect = function(ctx) ctx.hero.second_souffle = 3 end,
    },
  },

  -- ---------- Assassin ----------
  -- Refonte complète (2026-08-28, demande explicite -- tableur fourni,
  -- remplace intégralement les 6 cartes précédentes) : toutes tagguées
  -- "Furtif" (cats + mot-clé affiché, voir glossary.lua) -- ne fait PAS
  -- perdre Discrétion/Camouflé en la jouant (Game.on_card_played), et
  -- rapporte 2 Discrétion si elle finit défaussée sans avoir été jouée
  -- (Game.grant_furtif_discard_discretion). Les 3 "depart" changent aussi de
  -- nom (comme le Mage avant elles, voir Flamèche/Barrière) : ne portent
  -- plus les noms génériques "Coup direct"/"Encaisser".
  {
    code = "plan-attaque", name = "Plan d'attaque", class_id = "assassin", tier = "depart", cost = 1,
    cats = { "melee", "degats", "furtif" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    desc = 'Si Camouflé, inflige 8 "epee", sinon inflige 4 "epee". "Furtif"',
    effect = function(ctx)
      local amount = (ctx.hero.camoufle or 0) > 0 and 8 or 4
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, amount, "physique", ctx)
    end,
    upgrade = {
      desc = 'Si Camouflé, inflige 12 "epee", sinon inflige 6 "epee". "Furtif"',
      effect = function(ctx)
        local amount = (ctx.hero.camoufle or 0) > 0 and 12 or 6
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, amount, "physique", ctx)
      end,
    },
  },
  {
    -- Redevient un auto-bouclier (2026-09-02, demande explicite -- "L'Assassin
    -- gagne 8 bouclier", plus un allié ciblé) : `target` passe de "ally" à
    -- "self", plus de sélection de cible. Amélioré non précisé par le porteur
    -- de projet -- inféré à 12 (même ratio ×1.5 que l'ancien palier 4->6), à
    -- confirmer.
    code = "se-cacher", name = "Se cacher", class_id = "assassin", tier = "depart", cost = 1,
    cats = { "defense", "furtif" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'L\'Assassin gagne 8 "bouclier". "Furtif"',
    effect = function(ctx) Combat.grant_defense(ctx.hero, 8, ctx) end,
    upgrade = {
      desc = 'L\'Assassin gagne 12 "bouclier". "Furtif"',
      effect = function(ctx) Combat.grant_defense(ctx.hero, 12, ctx) end,
    },
  },
  {
    -- Rewrite multi-ennemis (2026-09-02, demande explicite -- "ces ennemis"
    -- au pluriel, plus une redirection unique) : boucle sur TOUS les ennemis
    -- dont l'action télégraphiée vise l'Assassin (même prédicat que
    -- Combat.enemy_targeting -- TARGETABLE_MOVE_KINDS + target_hero_id --
    -- mais sans s'arrêter au premier trouvé), les redirige tous vers l'allié
    -- ciblé, qui gagne 6 bouclier PAR ennemi redirigé (0 si aucun, plus de
    -- bouclier plancher inconditionnel comme avant). Amélioré non précisé par
    -- le porteur de projet -- inféré à 9/ennemi (même ratio ×1.5 que l'ancien
    -- palier 4->6), à confirmer.
    code = "repli-strategique", name = "Repli stratégique", class_id = "assassin", tier = "depart", cost = 1,
    cats = { "defense", "furtif" }, dmg_type = nil, target = "ally",
    -- Type (2026-09-03) : Support -- redirige des ennemis (les fait changer
    -- de cible) mais ne leur inflige jamais rien ; l'action utile pour le
    -- joueur est le bouclier accordé à l'allié qui prend le relais.
    types = { "support" },
    desc = 'Si "cibleennemi", ces ennemis changent de cible pour l\'allié ciblé, qui gagne 6 "bouclier" par ennemi. "Furtif"',
    effect = function(ctx)
      local count = 0
      for _, e in ipairs(ctx.state.enemies) do
        if e.hp > 0 and e.next_move and Combat.TARGETABLE_MOVE_KINDS[e.next_move.kind] and e.target_hero_id == ctx.hero.id then
          e.target_hero_id = ctx.target.id
          count = count + 1
        end
      end
      if count > 0 then
        Combat.grant_defense(ctx.target, 6 * count, ctx)
        Combat.log(ctx.state, ctx.hero.name .. " est visé : Repli stratégique redirige " .. count .. " ennemi(s) vers " .. ctx.target.name .. ".", "you")
      end
    end,
    upgrade = {
      desc = 'Si "cibleennemi", ces ennemis changent de cible pour l\'allié ciblé, qui gagne 9 "bouclier" par ennemi. "Furtif"',
      effect = function(ctx)
        local count = 0
        for _, e in ipairs(ctx.state.enemies) do
          if e.hp > 0 and e.next_move and Combat.TARGETABLE_MOVE_KINDS[e.next_move.kind] and e.target_hero_id == ctx.hero.id then
            e.target_hero_id = ctx.target.id
            count = count + 1
          end
        end
        if count > 0 then
          Combat.grant_defense(ctx.target, 9 * count, ctx)
          Combat.log(ctx.state, ctx.hero.name .. " est visé : Repli stratégique redirige " .. count .. " ennemi(s) vers " .. ctx.target.name .. ".", "you")
        end
      end,
    },
  },
  {
    -- Remplace "Blessure ouverte" (2026-08-28, corrigé après clarification
    -- explicite -- un premier jet rendait la Discrétion inconditionnelle,
    -- faux) : dégâts, saignement ET Discrétion sont TOUS LES TROIS
    -- conditionnels à Camouflé -- sans Camouflé, cette carte ne fait
    -- STRICTEMENT rien (coût payé pour rien, même geste que Riposte quand
    -- personne ne vise le lanceur -- voir plus haut) : contrairement à
    -- Assassinat, aucun lot de consolation ici.
    -- 2026-09-02, demande explicite : coût 2->1, dégâts nerfés (8->6/12->8),
    -- plus de gain de Discrétion (retiré) -- "reste Camouflé" ajouté au texte
    -- par clarté seulement, déjà garanti par le tag "Furtif" (Game.on_card_played
    -- ne retire Camouflé/Discrétion que pour une carte NON-Furtif), aucun code
    -- supplémentaire nécessaire.
    code = "en-traitre", name = "En traître", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "melee", "degats", "furtif" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    desc = 'Si Camouflé, inflige 6 "epee" et "Saignements" 3, reste Camouflé. "Furtif"',
    effect = function(ctx)
      if (ctx.hero.camoufle or 0) > 0 then
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "physique", ctx)
        Combat.apply_status(ctx.target, "saignements", 3)
      else
        Combat.log(ctx.state, "En traître : " .. ctx.hero.name .. " n'est pas Camouflé, la carte ne fait rien.", "sys")
      end
    end,
    upgrade = {
      desc = 'Si Camouflé, inflige 8 "epee" et "Saignements" 4, reste Camouflé. "Furtif"',
      effect = function(ctx)
        if (ctx.hero.camoufle or 0) > 0 then
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 8, "physique", ctx)
          Combat.apply_status(ctx.target, "saignements", 4)
        else
          Combat.log(ctx.state, "En traître : " .. ctx.hero.name .. " n'est pas Camouflé, la carte ne fait rien.", "sys")
        end
      end,
    },
  },
  {
    -- "et perd Camouflé" retiré (2026-08-28) : disparu du texte fourni, et
    -- désormais tagguée "Furtif" comme les 5 autres -- la jouer ne fait plus
    -- perdre Discrétion/Camouflé du tout (voir Game.on_card_played), qu'elle
    -- vienne de frapper en Camouflé ou non. Changement de comportement notable
    -- vs avant (perdait Camouflé après avoir frappé) : signalé explicitement.
    -- 2026-09-02, demande explicite : le lot de consolation (branche "pas
    -- Camouflé") monte 2->5 en Discrétion base et 3->10 amélioré, tandis que
    -- la Puissance reste "2" aux DEUX paliers (avant : 2/3 -- désormais
    -- unifiée, plus de palier sur ce champ précis).
    code = "assassinat", name = "Assassinat", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "melee", "degats", "furtif" }, dmg_type = "physique", target = "enemy",
    -- Type (2026-09-03) : dual -- si Camouflé, dégâts purs (Offensive) ;
    -- sinon, la branche "lot de consolation" ne fait AUCUN dégât et n'accorde
    -- que de la Discrétion/Puissance à soi (Support), pas juste un à-côté
    -- mineur comme le mana de Main de feu -- une des 2 branches EST le
    -- Support, comparable en poids à l'autre.
    types = { "offensive", "support" },
    -- Raccourcie (2026-09-12, redesign de la carte -- illustration + zone de
    -- texte réduite) : même effet, texte resserré pour tenir dans le nouveau
    -- gabarit (c'était la description la plus longue du jeu, débordait
    -- visiblement de la carte au rendu).
    desc = 'Camouflé : 12 "epee". Sinon : "Discrétion" 5, "Puissance" 2, remonte sur le deck. "Furtif"',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      if (ctx.hero.camoufle or 0) > 0 then
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 12, "physique", ctx)
      else
        Game.gain_discretion(ctx.state, ctx.hero, 5)
        Combat.apply_status(ctx.hero, "puissance", 2)
        ctx.return_to_deck_top = true
        Combat.log(ctx.state, ctx.hero.name .. " n'est pas Camouflé : Assassinat lui donne de la Discrétion et de la Puissance, puis retourne au sommet du deck.", "you")
      end
    end,
    upgrade = {
      desc = 'Camouflé : 18 "epee". Sinon : "Discrétion" 10, "Puissance" 2, remonte sur le deck. "Furtif"',
      effect = function(ctx)
        Game = Game or require("src.rules.game")
        if (ctx.hero.camoufle or 0) > 0 then
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 18, "physique", ctx)
        else
          Game.gain_discretion(ctx.state, ctx.hero, 10)
          Combat.apply_status(ctx.hero, "puissance", 2)
          ctx.return_to_deck_top = true
          Combat.log(ctx.state, ctx.hero.name .. " n'est pas Camouflé : Assassinat lui donne de la Discrétion et de la Puissance, puis retourne au sommet du deck.", "you")
        end
      end,
    },
  },
  {
    -- Renommée "Préparation" (2026-08-28, remplace "Dans les ombres") : même
    -- effet, juste tagguée "Furtif" en plus.
    code = "preparation", name = "Préparation", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "defense", "furtif" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Gagne 4 "bouclier", 1 "energie" et "Discrétion" 3. "Furtif"',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Combat.grant_defense(ctx.hero, 4, ctx)
      Game.gain_energy(ctx.state, 1)
      Game.gain_discretion(ctx.state, ctx.hero, 3)
    end,
    upgrade = {
      desc = 'Gagne 6 "bouclier", 2 "energie" et "Discrétion" 5. "Furtif"',
      effect = function(ctx)
        Game = Game or require("src.rules.game")
        Combat.grant_defense(ctx.hero, 6, ctx)
        Game.gain_energy(ctx.state, 2)
        Game.gain_discretion(ctx.state, ctx.hero, 5)
      end,
    },
  },

  -- Enchantements (2026-09-03, voir le commentaire au-dessus des 2 premiers,
  -- côté Guerrier, pour le principe général).
  {
    code = "ombre-patiente", name = "Ombre Patiente", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Devenir Camouflé donne "Puissance" 1.',
    effect = function(ctx) ctx.hero.ombre_patiente = 1 end,
    upgrade = {
      desc = 'Devenir Camouflé donne "Puissance" 2.',
      effect = function(ctx) ctx.hero.ombre_patiente = 2 end,
    },
  },
  {
    code = "imperceptible", name = "Imperceptible", class_id = "assassin", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Tous ses gains de "Discrétion" sont augmentés de 2.',
    effect = function(ctx) ctx.hero.imperceptible = 2 end,
    upgrade = {
      desc = 'Tous ses gains de "Discrétion" sont augmentés de 4.',
      effect = function(ctx) ctx.hero.imperceptible = 4 end,
    },
  },

  -- ---------- Nécromancien ----------
  -- Conçues avec agent_content (2026-08-29, voir content/memory/) --
  -- sélectionnable à l'écran de choix d'équipe (2026-08-29, voir
  -- Heroes.defs/Controller:enter_team_select). `corruption_cost_cap`
  -- (nouveau champ, 2026-08-29) : coût variable "1 (+X, 0-N Corruption)" --
  -- X = tout ce que le lanceur peut fournir jusqu'à ce plafond, calculé et
  -- déduit par Game.resolve_pending (jamais un choix du joueur), exposé aux
  -- effets via `ctx.corruption_spent` -- voir son commentaire dans game.lua.
  {
    code = "rite-mineur", name = "Rite mineur", class_id = "necromancien", tier = "depart", cost = 1,
    corruption_cost_cap = 3, heal_per_corruption = 2,
    cats = { "sort", "degats", "soin" }, dmg_type = "necrose", target = "enemy",
    -- Type (2026-09-03) : dual -- dégâts à l'ennemi (Offensive) ET soin à
    -- soi proportionnel à la Corruption dépensée (Support), substantiel
    -- (2-3 PV par point, pas un à-côté), contrairement au mana incidental de
    -- Main de feu -- comparable à Combat aguerri/Assassinat.
    types = { "offensive", "support" },
    desc = 'Inflige 6 "necrose" à un ennemi. Se soigne de 2*X.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 6, "necrose", ctx)
      if ctx.corruption_spent > 0 then Combat.grant_heal(ctx.hero, 2 * ctx.corruption_spent, ctx) end
    end,
    upgrade = {
      desc = 'Inflige 9 "necrose" à un ennemi. Se soigne de 3*X.',
      heal_per_corruption = 3,
      effect = function(ctx)
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 9, "necrose", ctx)
        if ctx.corruption_spent > 0 then Combat.grant_heal(ctx.hero, 3 * ctx.corruption_spent, ctx) end
      end,
    },
  },
  {
    -- Auto-inflige sa perte de PV via Combat.deal_damage (source_hero=nil,
    -- brut=true, ctx=nil) plutôt qu'une mutation directe de `hp` -- même
    -- idiome que "Le Blessé" (voir combat.lua) -- pour que le gain de
    -- Corruption générique (déclenché DANS deal_damage sur toute vraie perte
    -- de PV) s'applique automatiquement, sans le recalculer ici.
    code = "sceau-faiblesse", name = "Sceau de faiblesse", class_id = "necromancien", tier = "depart", cost = 0,
    cats = { "sort", "debuff" }, dmg_type = nil, target = "enemy",
    -- Type (2026-09-03) : Offensive seule -- la perte de PV est un COÛT payé
    -- par le lanceur (comme les autres cartes à auto-sacrifice du
    -- Nécromancien), pas un bénéfice accordé à un allié ; seul le débuff
    -- posé sur l'ennemi compte pour la classification.
    types = { "offensive" },
    desc = 'Perd 2 "PV". Applique "Vulnerabilite" 3 à un ennemi.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, nil, ctx.hero, 2, nil, nil, { brut = true })
      Combat.log(ctx.state, ctx.hero.name .. " s'entaille pour son rituel (Sceau de faiblesse).", "foe")
      Combat.apply_status(ctx.target, "vulnerabilite", 3)
    end,
    upgrade = {
      desc = 'Perd 2 "PV". Applique "Vulnerabilite" 4 à un ennemi.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, nil, ctx.hero, 2, nil, nil, { brut = true })
        Combat.log(ctx.state, ctx.hero.name .. " s'entaille pour son rituel (Sceau de faiblesse).", "foe")
        Combat.apply_status(ctx.target, "vulnerabilite", 4)
      end,
    },
  },
  {
    -- Rééquilibrée (2026-09-02, demande explicite -- l'ancien bouclier fixe
    -- +bouclier-au-Nécromancien-lui-même devient un auto-sacrifice qui
    -- profite entièrement à l'allié ciblé) : auto-inflige sa perte de PV via
    -- Combat.deal_damage (source_hero=nil, brut=true, ctx=nil) comme Sceau de
    -- faiblesse/Pacte funeste -- le gain de Corruption ("+1 par PV perdu",
    -- générique, voir Combat.deal_damage) s'applique automatiquement AVANT la
    -- lecture de `ctx.hero.corruption` juste en dessous, donc le bouclier de
    -- l'allié compte bien la Corruption fraîchement gagnée par ce sacrifice.
    code = "voile-ossements", name = "Voile d'ossements", class_id = "necromancien", tier = "depart", cost = 1,
    cats = { "defense" }, dmg_type = nil, target = "ally",
    types = { "support" },
    desc = 'Perd 2 "PV" : l\'allié ciblé gagne 1 "bouclier" par Corruption.',
    effect = function(ctx)
      Combat.deal_damage(ctx.state, nil, ctx.hero, 2, nil, nil, { brut = true })
      Combat.log(ctx.state, ctx.hero.name .. " s'entaille pour son rituel (Voile d'ossements).", "foe")
      Combat.grant_defense(ctx.target, (ctx.hero.corruption or 0) * 1, ctx)
    end,
    upgrade = {
      desc = 'Perd 3 "PV" : l\'allié ciblé gagne 2 "bouclier" par Corruption.',
      effect = function(ctx)
        Combat.deal_damage(ctx.state, nil, ctx.hero, 3, nil, nil, { brut = true })
        Combat.log(ctx.state, ctx.hero.name .. " s'entaille pour son rituel (Voile d'ossements).", "foe")
        Combat.grant_defense(ctx.target, (ctx.hero.corruption or 0) * 2, ctx)
      end,
    },
  },
  {
    -- "Perd la moitié/le tiers de ses PV" (arrondi au supérieur) : passe par
    -- Combat.deal_damage (source_hero=nil, brut, ctx=nil) comme Sceau de
    -- faiblesse ci-dessus -- le gain de Corruption ("autant que de PV
    -- perdus") en découle automatiquement, jamais ajouté une 2ᵉ fois ici.
    code = "pacte-funeste", name = "Pacte funeste", class_id = "necromancien", tier = "avance", cost = 1,
    cats = { "sort", "degats" }, dmg_type = "necrose", target = "enemy",
    types = { "offensive" },
    desc = 'Perd la moitié de ses "PV" actuels. Inflige 2 "necrose" par PV perdu à un ennemi.',
    effect = function(ctx)
      local lost = math.ceil(ctx.hero.hp / 2)
      Combat.deal_damage(ctx.state, nil, ctx.hero, lost, nil, nil, { brut = true })
      Combat.log(ctx.state, ctx.hero.name .. " se sacrifie pour son pacte (Pacte funeste).", "foe")
      if ctx.hero.hp > 0 then
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, lost * 2, "necrose", ctx)
      end
    end,
    upgrade = {
      -- 2026-09-02, demande explicite : le multiplicateur de dégâts par PV
      -- perdu passe aussi à 3 (avant : hérité tel quel de la base, 2).
      desc = 'Perd le tiers de ses "PV" actuels. Inflige 3 "necrose" par PV perdu à un ennemi.',
      effect = function(ctx)
        local lost = math.ceil(ctx.hero.hp / 3)
        Combat.deal_damage(ctx.state, nil, ctx.hero, lost, nil, nil, { brut = true })
        Combat.log(ctx.state, ctx.hero.name .. " se sacrifie pour son pacte (Pacte funeste).", "foe")
        if ctx.hero.hp > 0 then
          Combat.deal_damage(ctx.state, ctx.hero, ctx.target, lost * 3, "necrose", ctx)
        end
      end,
    },
  },
  {
    -- "X 'brut' à un ennemi ALÉATOIRE, au début des 3 prochains tours" --
    -- 3 entrées DISTINCTES programmées via Game.schedule_damage (même principe
    -- que Game.schedule_shield/"Infranchissable"), chacune tire sa propre
    -- cible au moment où elle se déclenche (pas fixée au moment où la carte
    -- est jouée) -- voir Game.start_turn. Aucun effet garanti à X=0 (2026-08-29,
    -- confirmé explicite -- VOULU, pas un oubli) : rien n'est programmé.
    code = "servant-os", name = "Servant d'os", class_id = "necromancien", tier = "avance", cost = 2,
    corruption_cost_cap = 4,
    cats = { "sort", "degats" }, dmg_type = nil, target = "self",
    types = { "offensive" },
    desc = 'Inflige X "brut" à un ennemi aléatoire, au début des 3 prochains tours.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      local x = ctx.corruption_spent
      if x > 0 then
        Game.schedule_damage(ctx.hero, x, 1)
        Game.schedule_damage(ctx.hero, x, 2)
        Game.schedule_damage(ctx.hero, x, 3)
        Combat.log(ctx.state, ctx.hero.name .. " invoque un Servant d'os (" .. x .. " brut, 3 tours).", "power")
      end
    end,
    upgrade = {
      desc = 'Inflige X "brut" à un ennemi aléatoire, au début des 4 prochains tours.',
      effect = function(ctx)
        Game = Game or require("src.rules.game")
        local x = ctx.corruption_spent
        if x > 0 then
          Game.schedule_damage(ctx.hero, x, 1)
          Game.schedule_damage(ctx.hero, x, 2)
          Game.schedule_damage(ctx.hero, x, 3)
          Game.schedule_damage(ctx.hero, x, 4)
          Combat.log(ctx.state, ctx.hero.name .. " invoque un Servant d'os (" .. x .. " brut, 4 tours).", "power")
        end
      end,
    },
  },
  {
    -- Renommée "Lien morbide" (2026-09-12, demande explicite -- nom trop
    -- long pour tenir sur 1 ligne dans le nouveau cartouche de carte, voir
    -- draw_card_face dans view.lua) : code interne inchangé.
    code = "communion-morts", name = "Lien morbide", class_id = "necromancien", tier = "avance", cost = 1,
    corruption_cost_cap = 6, heal_per_corruption = 2,
    cats = { "sort", "soin" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Se soigne de 2*X.',
    effect = function(ctx)
      if ctx.corruption_spent > 0 then Combat.grant_heal(ctx.hero, 2 * ctx.corruption_spent, ctx) end
    end,
    upgrade = {
      desc = 'Se soigne de 3*X.',
      heal_per_corruption = 3,
      effect = function(ctx)
        if ctx.corruption_spent > 0 then Combat.grant_heal(ctx.hero, 3 * ctx.corruption_spent, ctx) end
      end,
    },
  },

  -- Enchantements (2026-09-03, voir le commentaire au-dessus des 2 premiers,
  -- côté Guerrier, pour le principe général).
  {
    code = "rite-chair", name = "Rite de la Chair", class_id = "necromancien", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Gagne "Corruption" 2 à chaque début de tour.',
    effect = function(ctx) ctx.hero.rite_de_la_chair = 2 end,
    upgrade = {
      desc = 'Gagne "Corruption" 3 à chaque début de tour.',
      effect = function(ctx) ctx.hero.rite_de_la_chair = 3 end,
    },
  },
  {
    code = "pacte-survie", name = "Pacte de Survie", class_id = "necromancien", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Gagne 1 "bouclier" par PV perdu.',
    effect = function(ctx) ctx.hero.pacte_survie = 1 end,
    upgrade = {
      desc = 'Gagne 2 "bouclier" par PV perdu.',
      effect = function(ctx) ctx.hero.pacte_survie = 2 end,
    },
  },

  -- ---------- Barde ----------
  -- Conçues avec agent_content (2026-08-29, voir content/memory/) --
  -- sélectionnable à l'écran de choix d'équipe comme n'importe quelle autre
  -- classe (2026-08-30, correction -- l'ancien commentaire ici affirmait à
  -- tort "pas encore jouable", contredit par Heroes.defs/
  -- Controller:enter_team_select ET par le commentaire du Nécromancien
  -- juste au-dessus, déjà correct -- confirmé explicitement par le porteur
  -- de projet : Barde et Nécromancien sont tous deux pleinement jouables).
  -- "Inspiration" est un statut GÉNÉRIQUE (voir hero.inspiration, game.lua/
  -- combat.lua) : n'importe quel héros peut le porter, c'est le coeur de la
  -- synergie INTER-classes du Barde (jouer une carte Barde PUIS une carte
  -- d'une AUTRE classe dans le même tour, pas empiler plusieurs cartes Barde).
  {
    -- Lecture PASSIVE de l'Inspiration cumulée de tous les alliés (comme
    -- Voile d'ossements côté Nécromancien) -- distincte du mécanisme
    -- générique "+6 flat, consommé" (consume_inspiration dans combat.lua) :
    -- les deux peuvent s'appliquer sur LE MÊME coup si le Barde porte
    -- lui-même de l'Inspiration.
    code = "air-belliqueux", name = "Air belliqueux", class_id = "barde", tier = "depart", cost = 1,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    desc = 'Inflige 3 "epee" à un ennemi. +2 par charge d\'Inspiration sur les alliés.',
    effect = function(ctx)
      local total = 0
      for _, h in ipairs(living_heroes(ctx)) do total = total + (h.inspiration or 0) end
      Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 3 + 2 * total, "physique", ctx)
    end,
    upgrade = {
      desc = 'Inflige 5 "epee" à un ennemi. +3 par charge d\'Inspiration sur les alliés.',
      effect = function(ctx)
        local total = 0
        for _, h in ipairs(living_heroes(ctx)) do total = total + (h.inspiration or 0) end
        Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 5 + 3 * total, "physique", ctx)
      end,
    },
  },
  {
    code = "choeur-bataille", name = "Chœur de bataille", class_id = "barde", tier = "depart", cost = 1,
    cats = { "sort" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Tous les alliés gagnent "Inspiration" 2.',
    effect = function(ctx)
      for _, h in ipairs(living_heroes(ctx)) do Combat.apply_status(h, "inspiration", 2) end
    end,
    upgrade = {
      desc = 'Tous les alliés gagnent "Inspiration" 3.',
      effect = function(ctx)
        for _, h in ipairs(living_heroes(ctx)) do Combat.apply_status(h, "inspiration", 3) end
      end,
    },
  },
  {
    code = "improvisation", name = "Improvisation", class_id = "barde", tier = "depart", cost = 0,
    cats = { "sort" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Gagne "Inspiration" 2. "Pioche" 1.',
    effect = function(ctx)
      Deck = Deck or require("src.rules.deck")
      Game = Game or require("src.rules.game")
      Combat.apply_status(ctx.hero, "inspiration", 2)
      local drawn = Deck.draw_cards(ctx.state, 1)
      ctx.state.last_drawn_uids = Game.apply_maladroit_discards(ctx.state, drawn)
    end,
    upgrade = {
      desc = 'Gagne "Inspiration" 3. "Pioche" 1.',
      effect = function(ctx)
        Deck = Deck or require("src.rules.deck")
        Game = Game or require("src.rules.game")
        Combat.apply_status(ctx.hero, "inspiration", 3)
        local drawn = Deck.draw_cards(ctx.state, 1)
        ctx.state.last_drawn_uids = Game.apply_maladroit_discards(ctx.state, drawn)
      end,
    },
  },
  {
    -- `inspiration_shielded_turns` (2026-08-29, nouveau champ) : bloque
    -- UNIQUEMENT la décroissance AUTOMATIQUE de fin de tour
    -- (Game.decay_end_of_turn_statuses), jamais la consommation à l'usage
    -- (consume_inspiration) -- les deux restent indépendantes, comme demandé
    -- explicitement ("-1 charge à l'usage ET -1 automatique en fin de tour").
    code = "dernier-rappel", name = "Dernier rappel", class_id = "barde", tier = "avance", cost = 1,
    cats = { "sort" }, dmg_type = nil, target = "ally",
    types = { "support" },
    desc = 'L\'allié ciblé ne perd pas d\'Inspiration à la fin de ce tour et gagne "Inspiration" 3.',
    effect = function(ctx)
      ctx.target.inspiration_shielded_turns = math.max(ctx.target.inspiration_shielded_turns or 0, 1)
      Combat.apply_status(ctx.target, "inspiration", 3)
    end,
    upgrade = {
      desc = 'L\'allié ciblé ne perd pas d\'Inspiration à la fin des 2 prochains tours et gagne "Inspiration" 5.',
      effect = function(ctx)
        ctx.target.inspiration_shielded_turns = math.max(ctx.target.inspiration_shielded_turns or 0, 2)
        Combat.apply_status(ctx.target, "inspiration", 5)
      end,
    },
  },
  {
    -- Texte repris mot pour mot (2026-08-29, demande explicite -- "on enlève
    -- le 'sinon'") : le log "ne fait rien" reste interne (même vein que
    -- Riposte/En traître quand leur condition échoue), jamais affiché dans le
    -- texte de la carte. `encore_extra_plays` : consommé par le PROCHAIN
    -- effet de carte joué par la cible, quelle que soit sa classe -- voir
    -- Game.resolve_pending. `gratuite` (2026-09-02, ajout explicite) : même
    -- prochaine carte, coût énergie forcé à 0 -- voir Combat.effective_cost.
    code = "bis", name = "Bis", class_id = "barde", tier = "avance", cost = 1,
    cats = { "sort" }, dmg_type = nil, target = "ally",
    types = { "support" },
    desc = 'Si l\'allié a de l\'"Inspiration", elle est retirée et sa prochaine carte est "Gratuite" et jouée 2 fois. "Encore"',
    effect = function(ctx)
      if (ctx.target.inspiration or 0) > 0 then
        ctx.target.inspiration = 0
        ctx.target.encore_extra_plays = 1
        ctx.target.gratuite = (ctx.target.gratuite or 0) + 1
        Combat.log(ctx.state, ctx.target.name .. " gagne Encore : sa prochaine carte est Gratuite et se déclenche 2 fois.", "power")
      else
        Combat.log(ctx.state, "Bis : " .. ctx.target.name .. " n'a pas d'Inspiration, la carte ne fait rien.", "sys")
      end
    end,
    upgrade = {
      desc = 'Si l\'allié a de l\'"Inspiration", elle est retirée et sa prochaine carte est "Gratuite" et jouée 3 fois. "Encore"',
      effect = function(ctx)
        if (ctx.target.inspiration or 0) > 0 then
          ctx.target.inspiration = 0
          ctx.target.encore_extra_plays = 2
          ctx.target.gratuite = (ctx.target.gratuite or 0) + 1
          Combat.log(ctx.state, ctx.target.name .. " gagne Encore : sa prochaine carte est Gratuite et se déclenche 3 fois.", "power")
        else
          Combat.log(ctx.state, "Bis : " .. ctx.target.name .. " n'a pas d'Inspiration, la carte ne fait rien.", "sys")
        end
      end,
    },
  },
  {
    -- Remplace intégralement "Grand final" (2026-08-29, jugée trop compliquée
    -- à mettre en place -- demande explicite d'une proposition différente) :
    -- effet plat, inconditionnel, sur tous les alliés -- aucun calcul par charge.
    code = "rappel-triomphal", name = "Rappel triomphal", class_id = "barde", tier = "avance", cost = 2,
    cats = { "sort", "defense" }, dmg_type = nil, target = "self",
    types = { "support" },
    desc = 'Tous les alliés gagnent "Inspiration" 2 et 6 "bouclier".',
    effect = function(ctx)
      for _, h in ipairs(living_heroes(ctx)) do
        Combat.apply_status(h, "inspiration", 2)
        Combat.grant_defense(h, 6, ctx)
      end
    end,
    upgrade = {
      desc = 'Tous les alliés gagnent "Inspiration" 3 et 9 "bouclier".',
      effect = function(ctx)
        for _, h in ipairs(living_heroes(ctx)) do
          Combat.apply_status(h, "inspiration", 3)
          Combat.grant_defense(h, 9, ctx)
        end
      end,
    },
  },

  -- Enchantements (2026-09-03, voir le commentaire au-dessus des 2 premiers,
  -- côté Guerrier, pour le principe général).
  {
    -- Coût qui BAISSE à l'amélioration (2026-09-03, demande explicite --
    -- 2 -> 1, même mécanisme que "Coup de taille" du Guerrier, voir
    -- Cards.upgraded_def/def.upgrade.cost) : seul le coût change, l'effet est
    -- identique aux 2 paliers.
    code = "memoire-melodique", name = "Mémoire mélodique", class_id = "barde", tier = "avance", cost = 2,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = "Chaque carte jouée rend une autre carte de la main gratuite ce tour.",
    effect = function(ctx) ctx.hero.memoire_melodique = true end,
    upgrade = {
      desc = "Coût 1. Chaque carte jouée rend une autre carte de la main gratuite ce tour.",
      cost = 1,
      effect = function(ctx) ctx.hero.memoire_melodique = true end,
    },
  },
  {
    code = "tournee-finale", name = "Tournée finale", class_id = "barde", tier = "avance", cost = 1,
    cats = { "enchantement" }, dmg_type = nil, target = "self", types = { "enchantment" },
    desc = 'Un allié qui consomme une charge d\'"Inspiration" gagne 4 "bouclier".',
    effect = function(ctx) ctx.hero.tournee_finale = 4 end,
    upgrade = {
      desc = 'Un allié qui consomme une charge d\'"Inspiration" gagne 6 "bouclier".',
      effect = function(ctx) ctx.hero.tournee_finale = 6 end,
    },
  },

  -- ---------- Pilier du sacrifice (2026-09-28) ----------
  -- Première passe MÉCANIQUE seulement, textes volontairement génériques
  -- (demande explicite de Zgrubulu -- "on code toutes les mécaniques, mais
  -- pas les textes des cartes elles-mêmes", les vrais noms/effets par classe
  -- viendront plus tard sans toucher au moteur). 4 familles, 1 jeu de règles
  -- communes :
  -- - "Mise à mort de <Classe>" : `target = "self"`, tue son propre lanceur
  --   (voir Game.kill_hero) -- jamais dans les decks de départ (`tier =
  --   "avance"`, voir Deck.starting_cards_for_class), débloquée en cours de
  --   run via le draft de victoire comme n'importe quelle carte "avance".
  -- - "Legs du <Classe>"/"Héritage du <Classe>" : jamais draftées
  --   (`not_draftable`, voir Draft.pick_cards) -- déposées directement dans la
  --   défausse par Game.process_hero_deaths à la mort d'un héros de cette
  --   classe (Legs si subie, Héritage si volontaire). `target = "ally"` : ne
  --   fait rien sur la cible pour l'instant, oblige quand même à en choisir
  --   une pour tester le flux complet. Héritage incrémente
  --   `ctx.target.heritage_count` (2026-09-28, marqueur visuel -- voir
  --   draw_hero, combat.lua) : seul effet réel de cette passe, tout le reste
  --   du texte reste un vrai no-op.
  -- - "Écho du <Classe>" (base + amélioré) : jamais draftée (`not_draftable`)
  --   -- remplace automatiquement toute carte restante d'un héros mort (voir
  --   convert_remaining_cards_to_echo, game.lua). Coût 0, aucun effet pour
  --   l'instant.
  -- Toutes les 4 familles : `epuisement = true` (retirées du deck pour de bon
  -- après avoir été jouées, voir Game.finish_card) et `no_forge_upgrade =
  -- true` (pas de champ `upgrade` -- la Forge planterait sinon, voir
  -- Forge.upgradable_instances).
  {
    -- "Baroud d'Honneur" (2026-09-30, 1ʳᵉ carte de mise à mort réellement
    -- designée -- remplace le placeholder générique "Mise à mort de Guerrier").
    -- Condition de jouabilité (mot-clé "Mise à mort") : grisée/injouable tant
    -- que le Guerrier n'est pas sous 30% de ses PV max (voir Combat.can_play/
    -- playable_condition, et le rendu rouge/vert côté carte -- view/cards.lua).
    code = "mise-a-mort-guerrier", name = "Baroud d'Honneur", class_id = "guerrier", tier = "avance", cost = 2,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "self",
    types = { "offensive" },
    epuisement = true, no_forge_upgrade = true,
    condition_text = "PV < 30% PV max",
    playable_condition = function(state, hero) return hero.hp < hero.max_hp * 0.3 end,
    desc = 'Inflige 50 "epee" aux ennemis, répartis aléatoirement. "meurt". "Mise à mort".',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Combat.deal_random_split_damage(ctx.state, ctx.hero, 50, "physique", ctx.state.rng.sacrifice, ctx)
      Game.kill_hero(ctx.state, ctx.hero, true)
    end,
  },
  {
    -- "Ultime Rédemption" (2026-10-01, 2ᵉ classe designée carte par carte).
    -- Condition de jouabilité : un ennemi vivant doit avoir télégraphié une
    -- action de dégâts (`next_move.kind == "dmg"`) visant un COÉQUIPIER du
    -- Paladin -- explicitement JAMAIS le Paladin lui-même (confirmé --
    -- "la carte sert à sauver un autre héros, pas à se protéger soi-même") :
    -- thème de la rédemption, se sacrifier POUR UN AUTRE, pas pour soi.
    code = "mise-a-mort-paladin", name = "Ultime Rédemption", class_id = "paladin", tier = "avance", cost = 2,
    cats = {}, dmg_type = nil, target = "self",
    types = { "support" },
    epuisement = true, no_forge_upgrade = true,
    condition_text = "Un ennemi vise un allié",
    playable_condition = function(state, hero)
      for _, e in ipairs(Combat.living_enemies(state)) do
        if e.next_move and e.next_move.kind == "dmg" and e.target_hero_id and e.target_hero_id ~= hero.id then
          local target = Combat.hero_by_id(state, e.target_hero_id)
          if target and target.hp > 0 then return true end
        end
      end
      return false
    end,
    desc = '"Mise à mort". Annule toutes les actions ennemis, puis "meurt".',
    -- Annule TOUTES les actions ennemies (2026-10-01, pas seulement celles qui
    -- visaient un allié -- "annule toutes les actions ennemis", plus large que
    -- la condition qui ne fait que déclencher la carte) : même geste que
    -- "Riposte" (Guerrier, voir plus haut) pour annuler `next_move`/
    -- `target_hero_id`, mais SANS renvoyer de dégâts (Ultime Rédemption
    -- protège, elle ne contre-attaque pas) et sur TOUS les ennemis vivants,
    -- quelle que soit leur cible télégraphiée ou le type d'action.
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      local count = 0
      for _, e in ipairs(Combat.living_enemies(ctx.state)) do
        if e.next_move then
          e.next_move = nil
          e.target_hero_id = nil
          count = count + 1
        end
      end
      if count > 0 then
        Combat.log(ctx.state, "Ultime Rédemption annule l'action de " .. count .. " ennemi(s).", "you")
      end
      Game.kill_hero(ctx.state, ctx.hero, true)
    end,
  },
  {
    -- "Transfert Interdit" (2026-10-02, 6ᵉ classe designée carte par carte) --
    -- même structure que "Trahison Planifiée" (Assassin) : le Mage survit et
    -- profite, un ALLIÉ ciblé meurt à sa place -- `exclude_self_target = true`
    -- (le Mage doit survivre pour encaisser mana/Exaltation/soin).
    -- "Mise à mort" impose l'Héritage à la cible (confirmé -- voir "Trahison
    -- Planifiée").
    code = "mise-a-mort-mage", name = "Transfert Interdit", class_id = "mage", tier = "avance", cost = 2,
    cats = {}, dmg_type = nil, target = "ally", exclude_self_target = true,
    types = { "support" },
    epuisement = true, no_forge_upgrade = true,
    condition_text = "Le Mage a 0 mana",
    playable_condition = function(state, hero) return (hero.mana or 0) == 0 end,
    desc = '"Mise à mort". L\'allié ciblé "meurt". Le Mage gagne 10 "mana", "Exaltation" 5, et regagne tous ses PV.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Game.kill_hero(ctx.state, ctx.target, true)
      ctx.hero.mana = (ctx.hero.mana or 0) + 10
      Combat.apply_status(ctx.hero, "exaltation", 5)
      ctx.hero.hp = ctx.hero.max_hp
    end,
  },
  {
    -- "Trahison Planifiée" (2026-10-01, 4ᵉ classe designée carte par carte) --
    -- UNIQUE parmi les 6 : l'Assassin ne meurt PAS lui-même, il tue un allié
    -- ciblé pour en profiter -- `target = "ally"` (celui qui meurt),
    -- `exclude_self_target = true` (on ne peut pas "se trahir" soi-même --
    -- l'Assassin doit survivre pour profiter du Camouflage/de la Puissance).
    -- La mort de la CIBLE déclenche son Héritage, PAS son Legs (2026-10-02,
    -- correction explicite -- REVIREMENT sur la 1ʳᵉ version de cette carte,
    -- qui utilisait Legs) : `Game.kill_hero(..., true)` -- "Mise à mort"
    -- impose donc bien l'Héritage systématiquement pour qui meurt, quel que
    -- soit qui joue la carte -- confirmé, pas seulement pour l'auto-sacrifice.
    -- `cats = { "furtif" }` (2026-10-01, ajout nécessaire, pas dans le texte
    -- donné -- bug rencontré en testant) : SANS ce tag, Game.on_card_played
    -- (règle générique -- "jouer une carte non-Furtif termine Camouflage")
    -- effaçait le Camouflage tout juste accordé PAR CETTE CARTE elle-même,
    -- dans la MÊME résolution -- jamais l'effet voulu. Cohérent avec le thème
    -- (élimination discrète) ; à confirmer.
    -- Puissance 3->6, gain INSTANTANÉ (2026-10-03, correction explicite --
    -- "on supprime 'maintenant et à chaque début de combat'") : REVIREMENT,
    -- ce n'est plus un buff permanent (`Game.grant_permanent_buff`) mais un
    -- simple `Combat.apply_status`, comme "Voile de Brume" -- ne se
    -- réapplique plus aux combats suivants.
    code = "mise-a-mort-assassin", name = "Trahison Planifiée", class_id = "assassin", tier = "avance", cost = 2,
    cats = { "furtif" }, dmg_type = nil, target = "ally", exclude_self_target = true,
    types = { "support" },
    epuisement = true, no_forge_upgrade = true,
    condition_text = "Seulement 2 aventuriers vivants",
    playable_condition = function(state, hero) return #Combat.living_heroes(state) == 2 end,
    desc = '"Mise à mort". L\'allié ciblé (≠ l\'Assassin) "meurt". Devient "Camouflage" et "Puissance" 6. "Furtif".',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Game.kill_hero(ctx.state, ctx.target, true)
      Game.grant_camouflage(ctx.state, ctx.hero)
      Combat.apply_status(ctx.hero, "puissance", 6)
    end,
  },
  {
    -- "Pacte de sang" (2026-10-02, 7ᵉ classe designée carte par carte) --
    -- même structure que "Trahison Planifiée"/"Transfert Interdit" : le
    -- Nécromancien survit et profite, un ALLIÉ ciblé meurt à sa place --
    -- `exclude_self_target = true`. X = les PV ACTUELS de la cible, capturés
    -- AVANT sa mort (Game.kill_hero les mettrait à 0). "Mise à mort" impose
    -- l'Héritage à la cible (confirmé). "Gagne X PV max" interprété comme
    -- une VRAIE augmentation (max_hp ET hp actuels +X, pas seulement un
    -- plafond relevé sans gain immédiat) -- à confirmer si ce n'est pas
    -- l'intention.
    code = "mise-a-mort-necromancien", name = "Pacte de sang", class_id = "necromancien", tier = "avance", cost = 2,
    cats = {}, dmg_type = nil, target = "ally", exclude_self_target = true,
    types = { "support" },
    epuisement = true, no_forge_upgrade = true,
    condition_text = "Le Nécromancien est corrompu",
    playable_condition = function(state, hero) return (hero.corruption or 0) > 0 end,
    desc = '"Mise à mort". Gagne X PV max et X "Corruption" (X = PV actuels de l\'allié ciblé). L\'allié ciblé "meurt".',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      local x = ctx.target.hp
      ctx.hero.max_hp = ctx.hero.max_hp + x
      ctx.hero.hp = ctx.hero.hp + x
      ctx.hero.corruption = (ctx.hero.corruption or 0) + x
      Game.kill_hero(ctx.state, ctx.target, true)
    end,
  },
  {
    -- "Célébration Finale" (2026-10-01, 3ᵉ classe designée carte par carte).
    -- `target = "ally"` (PAS "self" comme les autres Mise à mort jusqu'ici) :
    -- le Barde choisit QUI reçoit "Survie". `exclude_self_target = true`
    -- (2026-10-01, correction explicite -- "le barde cible un allié
    -- différent de lui-même") : REVIREMENT sur la 1ʳᵉ version de cette carte,
    -- qui l'autorisait -- voir Game.resolve_pending, seul lecteur.
    code = "mise-a-mort-barde", name = "Célébration Finale", class_id = "barde", tier = "avance", cost = 2,
    cats = {}, dmg_type = nil, target = "ally", exclude_self_target = true,
    types = { "support" },
    epuisement = true, no_forge_upgrade = true,
    condition_text = "Le Barde est inspiré",
    playable_condition = function(state, hero) return (hero.inspiration or 0) > 0 end,
    desc = '"Mise à mort". Donne "Survie" à l\'allié ciblé, puis "meurt".',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.survie = true
      Game.kill_hero(ctx.state, ctx.hero, true)
    end,
  },

  {
    -- "Technique du Maître" (2026-09-30, 1ʳᵉ carte Legs réellement designée ;
    -- renommée le 2026-10-03 -- REVIREMENT explicite : "Les 2 cartes Legs et
    -- Héritage ne doivent pas avoir le même nom", correction d'une exception
    -- involontaire -- toutes les 5 autres classes avaient déjà 2 noms
    -- distincts pour leur Legs/Héritage, seul le Guerrier partageait "Puissance
    -- Ancestrale" entre les deux) : accorde un buff PERMANENT (mot-clé
    -- "Permanent") à l'allié ciblé -- voir Game.grant_permanent_buff/
    -- Combat.permanent_epee_bonus. Même effet de jeu qu'avant, seul le nom
    -- affiché change -- la version Héritage ci-dessous garde "Puissance
    -- Ancestrale" comme sa version renforcée, +4 "Puissance" en plus.
    code = "legs-guerrier", name = "Technique du Maître", class_id = "guerrier", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". Les cartes ciblant un ennemi infligent 2 "epee" de plus.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Game.grant_permanent_buff(ctx.target, {
        name = "Technique du Maître",
        desc = 'Les cartes ciblant un ennemi infligent 2 "epee" de plus.',
        epee_bonus = 2,
      })
    end,
  },
  {
    -- "Bouclier Spirituel" (2026-10-01, correction explicite -- "donne +3
    -- bouclier à chaque début de TOUR, pas de chaque combat, pas besoin de le
    -- préciser sur la carte") : `turn_start_status`, PAS `combat_start_status`
    -- comme "Puissance Ancestrale" du Guerrier -- voir Game.start_turn, pas
    -- apply_combat_start_temple_effects. Aucune mention de rythme dans le
    -- texte affiché (Bouclier se recharge chaque tour par convention
    -- implicite du jeu, contrairement à Provocation -- voir Héritage
    -- ci-dessous, qui doit lui le préciser).
    code = "legs-paladin", name = "Bouclier Spirituel", class_id = "paladin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". "Bouclier" 3.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Game.grant_permanent_buff(ctx.target, {
        name = "Bouclier Spirituel",
        desc = '"Bouclier" 3 à chaque début de tour.',
        turn_start_status = { defense = 3 },
      })
    end,
  },
  {
    -- "Étincelle de magie" (2026-10-02) : buff permanent, même mécanisme que
    -- "Puissance Ancestrale" du Guerrier mais côté magique -- `etincelle_bonus`
    -- (voir Combat.permanent_magic_bonus), pas `epee_bonus`.
    code = "legs-mage", name = "Étincelle de magie", class_id = "mage", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". Les cartes de dégâts de l\'aventurier gagnent 2 "étincelle" de plus.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Game.grant_permanent_buff(ctx.target, {
        name = "Étincelle de magie",
        desc = 'Les cartes de dégâts de l\'aventurier gagnent 2 "étincelle" de plus.',
        etincelle_bonus = 2,
      })
    end,
  },
  {
    -- "Voile de Brume" (2026-10-01) : contrairement aux Legs des 3 classes
    -- précédentes (toujours "Permanent"), celui-ci est un simple gain
    -- INSTANTANÉ, une seule fois -- pas de mot-clé "Permanent" dans le texte
    -- donné, aucun Game.grant_permanent_buff -- à confirmer que c'est bien
    -- volontaire (différencier Legs/Héritage sur la NATURE de l'effet, pas
    -- seulement sa force, pour cette classe) plutôt qu'un oubli.
    code = "legs-assassin", name = "Voile de Brume", class_id = "assassin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'L\'allié ciblé gagne "Esquive" 2.',
    effect = function(ctx) Combat.apply_status(ctx.target, "esquive", 2) end,
  },
  {
    -- "Siphon de vie" (2026-10-02) : gain INSTANTANÉ, une seule fois -- comme
    -- "Voile de Brume" de l'Assassin, pas de mot-clé "Permanent" dans le texte
    -- donné, aucun Game.grant_permanent_buff.
    code = "legs-necromancien", name = "Siphon de vie", class_id = "necromancien", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'L\'allié gagne "Vol de Vie" 3.',
    effect = function(ctx) Combat.apply_status(ctx.target, "vol_de_vie", 3) end,
  },
  {
    -- "Chant du Cygne" (2026-10-01) : buff permanent -- "Inspiration" 2
    -- réappliquée à CHAQUE COMBAT (combat_start_status, pas turn_start_status
    -- comme le Bouclier du Paladin -- confirmé "au début de chaque combat").
    code = "legs-barde", name = "Chant du Cygne", class_id = "barde", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". "Inspiration" 2 à chaque début de combat.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      Game.grant_permanent_buff(ctx.target, {
        name = "Chant du Cygne",
        desc = '"Inspiration" 2 à chaque début de combat.',
        combat_start_status = { inspiration = 2 },
      })
    end,
  },

  -- Héritage : seule différence mécanique réelle de cette passe -- incrémente
  -- `heritage_count` sur la cible (marqueur visuel, voir draw_hero) -- le
  -- reste du texte affiché ("Ne fait rien...") reste vrai quant au véritable
  -- effet de jeu, qui viendra plus tard.
  {
    -- "Puissance Ancestrale" (2026-09-30, version Héritage -- mort VOLONTAIRE,
    -- voir le mot-clé "Héritage"/hero.died_voluntarily) : même buff permanent
    -- que la version Legs ci-dessus, EN PLUS d'un "Puissance" 4 réappliqué à
    -- chaque début de combat (voir combat_start_status, appliqué par
    -- Game.grant_permanent_buff MAINTENANT et par apply_combat_start_temple_
    -- effects à chaque combat suivant). `heritage_count` conservé (marqueur
    -- de l'axe "l'Élu", pour plus tard -- voir draw_hero) en plus du VRAI
    -- effet de jeu, désormais réel.
    code = "heritage-guerrier", name = "Puissance Ancestrale", class_id = "guerrier", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". "Puissance" 4. Les cartes ciblant un ennemi infligent 2 "epee" de plus.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.heritage_count = (ctx.target.heritage_count or 0) + 1
      Game.grant_permanent_buff(ctx.target, {
        name = "Puissance Ancestrale",
        desc = '"Puissance" 4 à chaque début de combat. Les cartes ciblant un ennemi infligent 2 "epee" de plus.',
        epee_bonus = 2,
        combat_start_status = { puissance = 4 },
      })
    end,
  },
  {
    -- "Pouvoir de l'amitié" (2026-10-01, correction explicite) : version
    -- Héritage de "Bouclier Spirituel" -- Bouclier 6 (au lieu de 3) réappliqué
    -- PAR TOUR comme Legs (`turn_start_status`, jamais précisé sur la carte),
    -- MAIS Provocation 3 réappliquée PAR COMBAT (`combat_start_status`, voir
    -- Temple.effects/apply_combat_start_temple_effects) -- rythme DIFFÉRENT
    -- du Bouclier, donc explicitement précisé sur la carte cette fois
    -- ("bien +3 provocation au début de chaque combat -- à préciser").
    code = "heritage-paladin", name = "Pouvoir de l'amitié", class_id = "paladin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". "Bouclier" 6. "Provocation" 3 à chaque début de combat.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.heritage_count = (ctx.target.heritage_count or 0) + 1
      Game.grant_permanent_buff(ctx.target, {
        name = "Pouvoir de l'amitié",
        desc = '"Bouclier" 6 à chaque début de tour. "Provocation" 3 à chaque début de combat.',
        turn_start_status = { defense = 6 },
        combat_start_status = { provocation = 3 },
      })
    end,
  },
  {
    -- "Arcane Oublié" (2026-10-02) : version Héritage d'"Étincelle de magie" --
    -- même buff, +5 au lieu de +2.
    code = "heritage-mage", name = "Arcane Oublié", class_id = "mage", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". Les cartes de dégâts de l\'aventurier gagnent 5 "étincelle" de plus.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.heritage_count = (ctx.target.heritage_count or 0) + 1
      Game.grant_permanent_buff(ctx.target, {
        name = "Arcane Oublié",
        desc = 'Les cartes de dégâts de l\'aventurier gagnent 5 "étincelle" de plus.',
        etincelle_bonus = 5,
      })
    end,
  },
  {
    -- "Prédateur" (2026-10-02, correction explicite -- "Requiem de
    -- l'assassin est une erreur. C'est 'Prédateur' le bon nom" -- règle du
    -- coup l'ancienne collision de nom avec "Requiem" du Barde). Contrairement
    -- au Legs "Voile de Brume" ci-dessus (instantané), celui-ci EST bien
    -- "Permanent" -- accorde Camouflage tout de suite (Game.grant_camouflage,
    -- avec ses effets de bord -- Ombre patiente, annulation d'une attaque déjà
    -- télégraphiée) PUIS réapplique Camouflage + Esquive 2 à chaque futur
    -- début de combat (combat_start_status).
    code = "heritage-assassin", name = "Prédateur", class_id = "assassin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". Gagne "Camouflage" et "Esquive" 2 à chaque début de combat.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.heritage_count = (ctx.target.heritage_count or 0) + 1
      Game.grant_camouflage(ctx.state, ctx.target)
      Game.grant_permanent_buff(ctx.target, {
        name = "Prédateur",
        desc = 'Redevient "Camouflage" et gagne "Esquive" 2 à chaque début de combat.',
        combat_start_status = { camoufle = 1, esquive = 2 },
      })
    end,
  },
  {
    -- "Mangeur d'âme" (2026-10-02) : version Héritage de "Siphon de vie" --
    -- contrairement à ce dernier (instantané), celui-ci EST "Permanent".
    code = "heritage-necromancien", name = "Mangeur d'âme", class_id = "necromancien", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". L\'allié gagne "Vol de Vie" 3 au début de chaque combat.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.heritage_count = (ctx.target.heritage_count or 0) + 1
      Game.grant_permanent_buff(ctx.target, {
        name = "Mangeur d'âme",
        desc = '"Vol de Vie" 3 à chaque début de combat.',
        combat_start_status = { vol_de_vie = 3 },
      })
    end,
  },
  {
    -- "Requiem" (2026-10-01) : version Héritage de "Chant du Cygne" --
    -- MÊME valeur (Inspiration 2) mais réappliquée PAR TOUR (turn_start_status,
    -- voir Game.start_turn) au lieu de par combat -- nettement plus fort en
    -- pratique malgré le même chiffre, cohérent avec Legs/Héritage plus haut.
    code = "heritage-barde", name = "Requiem", class_id = "barde", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = '"Permanent". "Inspiration" 2 à chaque début de tour.',
    effect = function(ctx)
      Game = Game or require("src.rules.game")
      ctx.target.heritage_count = (ctx.target.heritage_count or 0) + 1
      Game.grant_permanent_buff(ctx.target, {
        name = "Requiem",
        desc = '"Inspiration" 2 à chaque début de tour.',
        turn_start_status = { inspiration = 2 },
      })
    end,
  },

  {
    -- Écho du Guerrier (2026-09-30, 1ʳᵉ carte Écho réellement designée) :
    -- simple attaque, en écho affaibli de ce que le Guerrier savait faire.
    -- `target = "enemy"` (pas "self" comme le placeholder -- il faut bien
    -- désigner une cible pour infliger des dégâts), `owner_can_be_dead`
    -- (2026-09-28, "l'esprit du défunt revient donner un petit boost à son
    -- équipe... le SEUL cas d'une carte jouée par un mort") : voir
    -- Combat.effective_owner/can_play, inchangé.
    code = "echo-guerrier", name = "Écho du Guerrier", class_id = "guerrier", tier = "avance", cost = 0,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'Inflige 3 "epee".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 3, "physique", ctx) end,
  },
  {
    code = "echo-guerrier-ameliore", name = "Écho du Guerrier", class_id = "guerrier", tier = "avance", cost = 0,
    cats = { "melee", "degats" }, dmg_type = "physique", target = "enemy",
    types = { "offensive" },
    epuisement = true, no_forge_upgrade = true, not_draftable = true, is_upgraded = true, owner_can_be_dead = true,
    desc = 'Inflige 5 "epee".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 5, "physique", ctx) end,
  },
  {
    -- Écho du Paladin (2026-10-01) : `target = "ally"` (pas "self" comme le
    -- placeholder -- il faut désigner l'allié qui reçoit le Bouclier).
    -- `owner_can_be_dead` (2026-09-28, "l'esprit du défunt revient donner un
    -- petit boost à son équipe... le SEUL cas d'une carte jouée par un mort") :
    -- voir Combat.effective_owner/can_play, inchangé -- ce flag concerne QUI
    -- joue la carte, indépendant de QUI elle cible. Épuisement confirmé sur
    -- les 2 versions (2026-10-01, question posée explicitement -- toutes les
    -- cartes Écho sont à usage unique, comme celles du Guerrier).
    code = "echo-paladin", name = "Écho du Paladin", class_id = "paladin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'Un allié gagne 2 "bouclier".',
    effect = function(ctx) Combat.grant_defense(ctx.target, 2, ctx) end,
  },
  {
    code = "echo-paladin-ameliore", name = "Écho du Paladin", class_id = "paladin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, is_upgraded = true, owner_can_be_dead = true,
    desc = 'Un allié gagne 4 "bouclier".',
    effect = function(ctx) Combat.grant_defense(ctx.target, 4, ctx) end,
  },
  {
    -- Écho du Mage (2026-10-02) : `target = "enemy"` (pas "self" -- inflige
    -- des dégâts, comme Écho du Guerrier). `owner_can_be_dead` (2026-09-28,
    -- "l'esprit du défunt revient donner un petit boost à son équipe... le
    -- SEUL cas d'une carte jouée par un mort") : inchangé.
    code = "echo-mage", name = "Écho du Mage", class_id = "mage", tier = "avance", cost = 0,
    cats = { "sort", "degats" }, dmg_type = "magique", target = "enemy",
    types = { "offensive" },
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'Inflige 3 "etincelle".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 3, "magique", ctx) end,
  },
  {
    code = "echo-mage-ameliore", name = "Écho du Mage", class_id = "mage", tier = "avance", cost = 0,
    cats = { "sort", "degats" }, dmg_type = "magique", target = "enemy",
    types = { "offensive" },
    epuisement = true, no_forge_upgrade = true, not_draftable = true, is_upgraded = true, owner_can_be_dead = true,
    desc = 'Inflige 5 "etincelle".',
    effect = function(ctx) Combat.deal_damage(ctx.state, ctx.hero, ctx.target, 5, "magique", ctx) end,
  },
  {
    -- Écho de l'Assassin (2026-10-01) : `target = "ally"` (pas "self" -- il
    -- faut désigner l'allié qui reçoit l'Esquive). `owner_can_be_dead`
    -- (2026-09-28, "l'esprit du défunt revient donner un petit boost à son
    -- équipe... le SEUL cas d'une carte jouée par un mort") : inchangé.
    code = "echo-assassin", name = "Écho de l'Assassin", class_id = "assassin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'Un allié gagne "Esquive" 1.',
    effect = function(ctx) Combat.apply_status(ctx.target, "esquive", 1) end,
  },
  {
    code = "echo-assassin-ameliore", name = "Écho de l'Assassin", class_id = "assassin", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, is_upgraded = true, owner_can_be_dead = true,
    desc = 'Un allié gagne "Esquive" 2.',
    effect = function(ctx) Combat.apply_status(ctx.target, "esquive", 2) end,
  },
  {
    -- Écho du Nécromancien (2026-10-02) : `target = "ally"` (pas "self" --
    -- il faut désigner l'allié qui paie le coût de PV et reçoit le bouclier,
    -- très thématique -- un sacrifice de vie contre de la protection).
    -- Perte de PV directe (PAS Combat.deal_damage -- ce n'est pas un coup
    -- reçu, pas de source/dégâts à parer, juste un coût -- même famille que
    -- Rite de la Chair/Pacte funeste, qui dépensent des PV/de la Corruption
    -- directement). `owner_can_be_dead` (2026-09-28) : inchangé.
    code = "echo-necromancien", name = "Écho du Nécromancien", class_id = "necromancien", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'L\'allié ciblé perd 2 "PV" et gagne 4 "bouclier".',
    effect = function(ctx)
      ctx.target.hp = math.max(0, ctx.target.hp - 2)
      Combat.grant_defense(ctx.target, 4, ctx)
    end,
  },
  {
    code = "echo-necromancien-ameliore", name = "Écho du Nécromancien", class_id = "necromancien", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, is_upgraded = true, owner_can_be_dead = true,
    desc = 'L\'allié ciblé perd 2 "PV" et gagne 10 "bouclier".',
    effect = function(ctx)
      ctx.target.hp = math.max(0, ctx.target.hp - 2)
      Combat.grant_defense(ctx.target, 10, ctx)
    end,
  },
  {
    -- Écho du Barde (2026-10-01) : `target = "ally"` (pas "self" -- il faut
    -- désigner l'allié qui reçoit l'Inspiration). `owner_can_be_dead`
    -- (2026-09-28, "l'esprit du défunt revient donner un petit boost à son
    -- équipe... le SEUL cas d'une carte jouée par un mort") : voir
    -- Combat.effective_owner/can_play, inchangé.
    code = "echo-barde", name = "Écho du Barde", class_id = "barde", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, owner_can_be_dead = true,
    desc = 'Un allié gagne 2 "inspiration".',
    effect = function(ctx) ctx.target.inspiration = (ctx.target.inspiration or 0) + 2 end,
  },
  {
    code = "echo-barde-ameliore", name = "Écho du Barde", class_id = "barde", tier = "avance", cost = 0,
    cats = {}, dmg_type = nil, target = "ally",
    epuisement = true, no_forge_upgrade = true, not_draftable = true, is_upgraded = true, owner_can_be_dead = true,
    desc = 'Un allié gagne 3 "inspiration".',
    effect = function(ctx) ctx.target.inspiration = (ctx.target.inspiration or 0) + 3 end,
  },
}

function Cards.by_code(code)
  for _, c in ipairs(Cards.list) do
    if c.code == code then return c end
  end
  return nil
end

--- Version améliorée d'un def de base (écran "La Forge", 2026-08-10, demande
-- explicite -- une seule amélioration possible par carte, jamais de palier
-- au-delà). Conserve `code` (les recherches Cards.by_code/le glossaire
-- continuent de fonctionner sur l'identité de base), change juste name/desc/
-- effect et marque `is_upgraded` -- c'est ce flag qui exclut la carte du
-- pool de tirage (voir src/rules/forge.lua), PAS l'absence de `upgrade`
-- (gardé tel quel, inutilisé, pour ne pas perdre l'info "était améliorable").
function Cards.upgraded_def(def)
  assert(def.upgrade, "carte non améliorable : " .. tostring(def.code))
  local up = {}
  for k, v in pairs(def) do up[k] = v end
  -- Nom SANS "+" (2026-09-12, demande explicite -- remplace le système de
  -- "+ Nom +" adopté le 2026-09-02) : le nom reste identique à la base,
  -- `is_upgraded` (déjà posé plus bas) est désormais le seul signal --
  -- draw_card_face (view.lua) l'affiche en gras et dans une teinte grise
  -- distincte plutôt que d'ajouter des symboles autour du texte.
  up.name = def.name
  up.desc = def.upgrade.desc
  up.effect = def.upgrade.effect
  up.is_upgraded = true
  -- Overrides optionnels (2026-09-02, "Coup de taille" -- coût réduit à
  -- l'amélioration sans changer les dégâts) : nil dans `def.upgrade` = hérite
  -- de la valeur de base comme avant, rétrocompatible avec toute carte qui ne
  -- les définit pas.
  if def.upgrade.cost ~= nil then up.cost = def.upgrade.cost end
  if def.upgrade.heal_per_corruption ~= nil then up.heal_per_corruption = def.upgrade.heal_per_corruption end
  return up
end

return Cards
