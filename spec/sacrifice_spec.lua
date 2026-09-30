-- Pilier du sacrifice (2026-09-28) : Mise à mort / Legs / Héritage / Écho --
-- couverture d'intégration bout-en-bout (vrai Game.reset_run, comme
-- cards_spec.lua) en complément des tests unitaires ciblés déjà présents dans
-- game_turn_spec.lua (Game.kill_hero/process_hero_deaths/finish_card) et
-- combat_spec.lua (Combat.effective_owner/can_play).

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")

describe("Pilier du sacrifice -- intégration bout-en-bout", function()
  local state, guerrier, mage, paladin, barde, assassin, necromancien

  before_each(function()
    state = Game.new_state()
    -- Les 6 classes (2026-10-02, "necromancien" ajouté pour couvrir ses
    -- propres cartes) : rien dans Game.reset_run/Heroes n'impose exactement 4
    -- -- l'équipe réelle du joueur (voir l'écran de choix d'équipe) en a
    -- toujours 4, mais ces tests d'intégration n'ont besoin que d'un état de
    -- jeu valide, pas d'une VRAIE composition de run.
    Game.reset_run(state, 12345, { "guerrier", "mage", "barde", "paladin", "assassin", "necromancien" }, nil)
    state.energy = 99
    guerrier = Combat.hero_by_id(state, "guerrier")
    mage = Combat.hero_by_id(state, "mage")
    paladin = Combat.hero_by_id(state, "paladin")
    barde = Combat.hero_by_id(state, "barde")
    assassin = Combat.hero_by_id(state, "assassin")
    necromancien = Combat.hero_by_id(state, "necromancien")
  end)

  local function play(code, uid, kind, target_id)
    local def = Cards.by_code(code)
    state.hand[#state.hand + 1] = { uid = uid, def = def }
    local result = Game.select_card(state, uid)
    if result == "assigned" then Game.resolve_pending(state, kind, target_id) end
    return result
  end

  it("Mise à mort : tue son lanceur, dépose un Héritage (pas un Legs), convertit ses cartes en Écho", function()
    -- "Baroud d'Honneur" (2026-09-30) : condition de jouabilité (PV < 30% PV
    -- max, voir cards.lua) -- jamais jouable à pleine vie, contrairement à
    -- l'ancien placeholder générique.
    guerrier.hp = 10
    assert.are.equal("assigned", play("mise-a-mort-guerrier", "u1", "self"))
    assert.are.equal(0, guerrier.hp)
    assert.is_true(guerrier.died_voluntarily)

    local has_heritage, has_legs = false, false
    for _, c in ipairs(state.discard) do
      if c.def.code == "heritage-guerrier" then has_heritage = true end
      if c.def.code == "legs-guerrier" then has_legs = true end
    end
    assert.is_true(has_heritage)
    assert.is_false(has_legs)

    -- Le deck de départ du Guerrier (3 cartes) a été mélangé dans state.deck
    -- par Game.reset_run puis partiellement pioché en main -- où qu'elles
    -- soient, toutes doivent désormais être des Écho du Guerrier.
    local function all_guerrier_cards_are_echo(pile)
      for _, c in ipairs(pile) do
        -- Exclut la carte "Mise à mort" jouée (uid "u1") et le "Héritage du
        -- Guerrier" qui vient d'être déposé -- ce sont de NOUVELLES cartes,
        -- pas des "cartes restantes" du défunt à convertir.
        if c.def.class_id == "guerrier" and c.uid ~= "u1" and c.def.code ~= "heritage-guerrier" then
          if c.def.code ~= "echo-guerrier" and c.def.code ~= "echo-guerrier-ameliore" then return false end
        end
      end
      return true
    end
    assert.is_true(all_guerrier_cards_are_echo(state.deck))
    assert.is_true(all_guerrier_cards_are_echo(state.hand))
    assert.is_true(all_guerrier_cards_are_echo(state.discard))
  end)

  it("Legs posthume : jouable par le défunt lui-même (2026-10-03, même dynamique que l'Écho), pas par un autre héros", function()
    guerrier.hp = 0 -- mort subie, pas de died_voluntarily -> Legs
    Game.process_hero_deaths(state)
    local legs_card
    for _, c in ipairs(state.discard) do
      if c.def.code == "legs-guerrier" then legs_card = c end
    end
    assert.is_not_nil(legs_card)
    state.discard = {}
    state.hand[#state.hand + 1] = legs_card
    assert.are.equal("assigned", Game.select_card(state, legs_card.uid))
    -- Le lanceur assigné EST le Guerrier mort lui-même -- "c'est le
    -- propriétaire qui joue Legs/Héritage sur un allié ciblé, la même
    -- dynamique que pour l'écho" (correction explicite du 2026-10-03).
    assert.are.equal(guerrier.id, state.pending.hero_id)
    Game.resolve_pending(state, "ally", mage.id)
    assert.is_nil(mage.heritage_count) -- Legs (pas Héritage) : jamais de heritage_count posé
  end)

  it("Écho posthume : reste jouable par son propriétaire mort lui-même", function()
    guerrier.hp = 0
    guerrier.died_voluntarily = true
    Game.process_hero_deaths(state)
    -- Une carte Écho existe déjà dans le deck/main du Guerrier après conversion.
    local echo_uid
    for _, c in ipairs(state.hand) do
      if c.def.code == "echo-guerrier" or c.def.code == "echo-guerrier-ameliore" then echo_uid = c.uid end
    end
    if not echo_uid then
      -- Repli : injecte-en une directement si aucune n'était en main (dépend
      -- du tirage initial) -- le point testé est le même : jouabilité par un
      -- propriétaire mort, pas la présence garantie en main après reset_run.
      echo_uid = "echo-test"
      state.hand[#state.hand + 1] = { uid = echo_uid, def = Cards.by_code("echo-guerrier") }
    end
    assert.are.equal("assigned", Game.select_card(state, echo_uid))
    -- Ici, au contraire du test précédent : le lanceur assigné EST le
    -- Guerrier mort lui-même -- "l'esprit du défunt", demande explicite.
    assert.are.equal(guerrier.id, state.pending.hero_id)
  end)

  it("Héritage sur un allié vivant : incrémente heritage_count (marqueur visuel)", function()
    guerrier.hp = 0
    guerrier.died_voluntarily = true
    Game.process_hero_deaths(state)
    local heritage_card
    for _, c in ipairs(state.discard) do
      if c.def.code == "heritage-guerrier" then heritage_card = c end
    end
    state.hand[#state.hand + 1] = heritage_card
    assert.are.equal("assigned", Game.select_card(state, heritage_card.uid))
    Game.resolve_pending(state, "ally", mage.id)
    assert.are.equal(1, mage.heritage_count)
  end)

  -- "Baroud d'Honneur"/"Technique du Maître"/"Puissance Ancestrale"/"Écho du
  -- Guerrier" (2026-09-30, 1ʳᵉ classe designée carte par carte ; Legs renommé
  -- le 2026-10-03 -- "Les 2 cartes Legs et Héritage ne doivent pas avoir le
  -- même nom") : couverture des 4 cartes réelles du Guerrier, au-delà du seul
  -- moteur générique déjà testé ci-dessus et dans combat_spec.lua
  -- (Combat.deal_random_split_damage/permanent_epee_bonus).
  describe("Baroud d'Honneur (Mise à mort du Guerrier)", function()
    it("injouable au-dessus de 30% PV (grisée), jouable en dessous", function()
      guerrier.hp = guerrier.max_hp
      assert.are.equal("refused", play("mise-a-mort-guerrier", "u-cond-1", "self"))
      assert.are.equal(guerrier.max_hp, guerrier.hp) -- n'a pas tenté de tuer -- refusée AVANT tout effet

      -- 30% de 36 PV max = 10.8 : 11 PV est encore AU-DESSUS du seuil (condition
      -- stricte "<"), doit rester injouable -- seule une valeur strictement
      -- inférieure à 10.8 (10 PV et moins) passe la condition.
      guerrier.hp = 11
      state.hand = {}
      assert.are.equal("refused", play("mise-a-mort-guerrier", "u-cond-2", "self"))

      guerrier.hp = 1
      state.hand = {}
      assert.are.equal("assigned", play("mise-a-mort-guerrier", "u-cond-3", "self"))
      assert.are.equal(0, guerrier.hp)
    end)

    it("répartit 50 dégâts sur les ennemis vivants avant de mourir", function()
      guerrier.hp = 1
      local total_before = 0
      for _, e in ipairs(state.enemies) do total_before = total_before + e.hp end
      play("mise-a-mort-guerrier", "u-dmg", "self")
      local total_after = 0
      for _, e in ipairs(state.enemies) do total_after = total_after + math.max(0, e.hp) end
      assert.is_true(total_after < total_before) -- au moins une partie des 50 a bien été infligée
    end)
  end)

  describe("Technique du Maître / Puissance Ancestrale (Legs/Héritage du Guerrier)", function()
    it("Legs : accorde un buff permanent (+2 epee) SANS Puissance", function()
      guerrier.hp = 0 -- mort subie -> Legs
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-guerrier" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(1, #mage.permanent_buffs)
      assert.are.equal(2, mage.permanent_buffs[1].epee_bonus)
      assert.is_nil(mage.permanent_buffs[1].combat_start_status)
      assert.are.equal(0, mage.puissance) -- Legs seul ne donne jamais de Puissance
    end)

    it("Héritage : même buff +2 epee, PLUS Puissance +4 IMMÉDIATE (pas seulement au prochain combat)", function()
      guerrier.hp = 0
      guerrier.died_voluntarily = true
      Game.process_hero_deaths(state)
      local heritage_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-guerrier" then heritage_card = c end
      end
      state.hand[#state.hand + 1] = heritage_card
      Game.select_card(state, heritage_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(1, #mage.permanent_buffs)
      assert.are.equal(2, mage.permanent_buffs[1].epee_bonus)
      assert.are.equal(4, mage.puissance) -- appliqué tout de suite, pas seulement au prochain combat
    end)

    it("le buff +2 epee du Legs/Héritage augmente réellement les dégâts physiques du porteur", function()
      guerrier.hp = 0
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-guerrier" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", mage.id)

      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      Combat.deal_damage(state, mage, enemy, 4, "physique", nil)
      assert.are.equal(hp_before - 6, enemy.hp) -- 4 de base + 2 du buff permanent
    end)
  end)

  describe("Écho du Guerrier", function()
    it("inflige 3 degats de base, 5 amélioré", function()
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      state.hand[#state.hand + 1] = { uid = "echo-base", def = Cards.by_code("echo-guerrier") }
      Game.select_card(state, "echo-base")
      Game.resolve_pending(state, "enemy", enemy.id)
      assert.are.equal(hp_before - 3, enemy.hp)

      local hp_before2 = enemy.hp
      state.hand[#state.hand + 1] = { uid = "echo-ameliore", def = Cards.by_code("echo-guerrier-ameliore") }
      Game.select_card(state, "echo-ameliore")
      Game.resolve_pending(state, "enemy", enemy.id)
      assert.are.equal(hp_before2 - 5, enemy.hp)
    end)
  end)

  -- "Ultime Rédemption"/"Bouclier Spirituel"/"Pouvoir de l'amitié"/"Écho du
  -- Paladin" (2026-10-01, 2ᵉ classe designée carte par carte).
  describe("Ultime Rédemption (Mise à mort du Paladin)", function()
    local function set_enemy_move(enemy, kind, target_hero_id)
      enemy.next_move = { kind = kind, amount = 5 }
      enemy.target_hero_id = target_hero_id
    end

    it("injouable si aucun ennemi ne vise un ALLIÉ (jamais le Paladin lui-même)", function()
      for _, e in ipairs(state.enemies) do e.next_move = nil; e.target_hero_id = nil end
      assert.are.equal("refused", play("mise-a-mort-paladin", "u-red-1", "self"))

      -- Un ennemi vise le Paladin LUI-MÊME : ne compte pas comme "un allié"
      -- (confirmé explicitement -- la carte sert à sauver un AUTRE héros).
      set_enemy_move(state.enemies[1], "dmg", paladin.id)
      state.hand = {}
      assert.are.equal("refused", play("mise-a-mort-paladin", "u-red-2", "self"))
    end)

    it("jouable dès qu'un ennemi vise un coéquipier avec une action de dégâts", function()
      set_enemy_move(state.enemies[1], "dmg", mage.id)
      assert.are.equal("assigned", play("mise-a-mort-paladin", "u-red-3", "self"))
      assert.are.equal(0, paladin.hp)
    end)

    it("une action non-dégâts (buff/debuff) sur un allié ne suffit PAS -- condition = \"va faire des dégâts\"", function()
      for _, e in ipairs(state.enemies) do e.next_move = nil; e.target_hero_id = nil end
      set_enemy_move(state.enemies[1], "buff", mage.id)
      assert.are.equal("refused", play("mise-a-mort-paladin", "u-red-4", "self"))
    end)

    it("annule TOUTES les actions ennemies (pas seulement celle qui visait l'allié), puis meurt", function()
      set_enemy_move(state.enemies[1], "dmg", mage.id)
      if state.enemies[2] then set_enemy_move(state.enemies[2], "dmg", paladin.id) end
      play("mise-a-mort-paladin", "u-red-5", "self")
      for _, e in ipairs(state.enemies) do
        assert.is_nil(e.next_move)
        assert.is_nil(e.target_hero_id)
      end
      assert.are.equal(0, paladin.hp)
      assert.is_true(paladin.died_voluntarily)
    end)
  end)

  describe("Bouclier Spirituel / Pouvoir de l'amitié (Legs/Héritage du Paladin)", function()
    it("Legs : Bouclier 3 immédiat, réappliqué à chaque TOUR (turn_start_status, pas combat_start_status)", function()
      paladin.hp = 0 -- mort subie -> Legs
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-paladin" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(3, mage.defense) -- immédiat
      assert.are.equal(1, #mage.permanent_buffs)
      assert.are.equal(3, mage.permanent_buffs[1].turn_start_status.defense)
      assert.is_nil(mage.permanent_buffs[1].combat_start_status)

      -- 2026-10-01, correction explicite -- "à chaque début de TOUR, pas de
      -- chaque combat" : la Défense repart à 0 en tout début de tour
      -- (Game.start_turn), le buff doit la reposer à 3 CHAQUE tour, pas
      -- seulement à l'entrée en combat.
      mage.defense = 0
      Game.start_turn(state)
      assert.are.equal(3, mage.defense)
      mage.defense = 0
      Game.start_turn(state)
      assert.are.equal(3, mage.defense) -- encore vrai au tour SUIVANT, pas juste le premier
    end)

    it("Héritage : Bouclier 6 (par TOUR) ET Provocation 3 (par COMBAT), immédiats et sur des rythmes différents", function()
      paladin.hp = 0
      paladin.died_voluntarily = true
      Game.process_hero_deaths(state)
      local heritage_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-paladin" then heritage_card = c end
      end
      state.hand[#state.hand + 1] = heritage_card
      Game.select_card(state, heritage_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(6, mage.defense)
      assert.are.equal(3, mage.provocation)

      -- Bouclier repart CHAQUE tour (turn_start_status)...
      mage.defense = 0
      Game.start_turn(state)
      assert.are.equal(6, mage.defense)
      -- ... mais Provocation ne se réapplique QU'À L'ENTRÉE EN COMBAT
      -- (combat_start_status, voir apply_combat_start_temple_effects/
      -- carried_hero) -- Game.start_turn seul ne doit jamais la reposer.
      mage.provocation = 0
      Game.start_turn(state)
      assert.are.equal(0, mage.provocation)
    end)
  end)

  describe("Écho du Paladin", function()
    it("donne 2 bouclier de base, 4 amélioré, à l'allié ciblé", function()
      state.hand[#state.hand + 1] = { uid = "echo-pal-base", def = Cards.by_code("echo-paladin") }
      Game.select_card(state, "echo-pal-base")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(2, mage.defense)

      state.hand[#state.hand + 1] = { uid = "echo-pal-ameliore", def = Cards.by_code("echo-paladin-ameliore") }
      Game.select_card(state, "echo-pal-ameliore")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(6, mage.defense) -- 2 (deja pose) + 4
    end)
  end)

  -- "Célébration Finale"/"Chant du Cygne"/"Requiem"/"Écho du Barde"
  -- (2026-10-01, 3ᵉ classe designée carte par carte) + le nouveau mot-clé
  -- "Survie" (Combat.deal_damage/Game.tick_bleed/tick_burn).
  describe("Célébration Finale (Mise à mort du Barde)", function()
    it("injouable sans Inspiration, jouable dès que le Barde est inspiré", function()
      barde.inspiration = 0
      assert.are.equal("refused", play("mise-a-mort-barde", "u-cel-1", "ally", mage.id))
      barde.inspiration = 1
      state.hand = {}
      assert.are.equal("assigned", play("mise-a-mort-barde", "u-cel-2", "ally", mage.id))
    end)

    it("donne \"Survie\" à l'ALLIÉ CIBLÉ (pas forcément le Barde), puis meurt", function()
      barde.inspiration = 3
      play("mise-a-mort-barde", "u-cel-3", "ally", mage.id)
      assert.is_true(mage.survie)
      assert.is_nil(barde.survie) -- ciblé sur le Mage, pas sur lui-même
      assert.are.equal(0, barde.hp)
      assert.is_true(barde.died_voluntarily)
    end)

    -- 2026-10-01, REVIREMENT explicite -- "le barde cible un allié différent
    -- de lui-même" : remplace le test précédent, qui validait l'inverse.
    -- `Game.select_card` (donc `play()`) renvoie encore "assigned" -- la
    -- condition de jouabilité (Discrétion) est remplie, seul le CIBLAGE est
    -- refusé, une étape plus tard (Game.resolve_pending) -- même contrat
    -- qu'une cible ennemie/alliée invalide ailleurs dans ce fichier (return
    -- silencieux, `state.pending` reste posé, rien ne se résout).
    it("refuse de se cibler lui-même (exclude_self_target) -- la carte reste en attente, rien ne se résout", function()
      barde.inspiration = 3
      assert.are.equal("assigned", play("mise-a-mort-barde", "u-cel-4", "ally", barde.id))
      assert.is_nil(barde.survie)
      assert.are.equal(barde.max_hp, barde.hp) -- pas mort -- la carte n'a pas du tout été résolue
      assert.is_not_nil(state.pending) -- toujours en attente d'une cible VALIDE
    end)
  end)

  describe("\"Survie\" (mot-clé)", function()
    it("évite UNE mort par dégâts normaux, revient à 10% des PV max, puis se consomme", function()
      mage.survie = true
      local lethal = mage.hp + 999
      Combat.deal_damage(state, nil, mage, lethal, "physique", nil, { brut = true })
      local expected_hp = math.max(1, math.ceil(mage.max_hp * 0.1))
      assert.are.equal(expected_hp, mage.hp)
      assert.is_false(mage.survie)

      -- Un 2ᵉ coup fatal, sans Survie restante, tue pour de bon.
      Combat.deal_damage(state, nil, mage, 999, "physique", nil, { brut = true })
      assert.is_true(mage.hp <= 0)
    end)

    it("n'empêche PAS une carte \"Mise à mort\" -- rien n'y échappe (exception explicite du mot-clé)", function()
      guerrier.survie = true
      guerrier.hp = 1 -- sous 30% -> Baroud d'Honneur jouable
      play("mise-a-mort-guerrier", "u-surv-1", "self")
      assert.are.equal(0, guerrier.hp) -- Survie ne sauve pas d'une Mise à mort
    end)

    it("fonctionne aussi contre le saignement et la brûlure", function()
      mage.survie = true
      mage.saignements = mage.hp + 50
      Game.tick_bleed(state)
      assert.is_true(mage.hp > 0)
      assert.is_false(mage.survie)

      paladin.survie = true
      paladin.brulure = paladin.hp + 50
      Game.tick_burn(state)
      assert.is_true(paladin.hp > 0)
      assert.is_false(paladin.survie)
    end)

    -- 2026-10-01/02, demande explicite -- "il faut harmoniser La Renaissante
    -- pour qu'elle donne Survie à l'aventurier" PUIS correction le 02 --
    -- "la bénédiction la recharge à chaque entrée en combat JUSQU'À LA LIMITE
    -- DE 1 UTILISATION. Quand le personnage est sauvé 1 fois par la
    -- bénédiction, Survie ne réapparaît plus du fait de la bénédiction" :
    -- MÊME champ hero.survie, 2 comportements différents selon la source --
    -- la bénédiction la recharge à CHAQUE combat, mais UNE SEULE FOIS AU
    -- TOTAL pour tout le run (jamais une 2ᵉ fois après avoir sauvé une
    -- première fois, même des combats plus tard) ; une carte NE LA RECHARGE
    -- JAMAIS TOUTE SEULE (charge unique, comme avant).
    it("harmonisation : La Renaissante recharge Survie À CHAQUE COMBAT jusqu'à sa 1ère vraie utilisation, plus jamais ensuite", function()
      local Temple = require("src.rules.temple")
      Temple.assign(mage, Temple.by_id("renaissante"))
      -- Temple.assign ne fait que poser mage.blessing="renaissante" -- c'est
      -- Game.apply_combat_start_temple_effects (via carried_hero, DONC une
      -- vraie entrée en combat) qui retranscrit ça en mage.survie=true. 1er
      -- appel = applique la bénédiction pour la première fois.
      -- `Game.start_next_combat` RECONSTRUIT `state.heroes` (carried_hero,
      -- shallow_copy) -- les variables locales `mage`/`paladin` capturées en
      -- before_each deviendraient orphelines sans les re-résoudre après
      -- CHAQUE appel via Combat.hero_by_id, jamais la même référence de table.
      Game.start_next_combat(state)
      mage = Combat.hero_by_id(state, "mage")
      assert.is_true(mage.survie)
      -- 1er combat SANS jamais déclencher Survie : reste posée (rien ne l'a
      -- consommée), la bénédiction n'a encore RIEN "dépensé".
      Game.start_next_combat(state)
      mage = Combat.hero_by_id(state, "mage")
      assert.is_true(mage.survie) -- toujours là, jamais consommée
      assert.is_nil(mage.renaissante_used)

      -- CETTE FOIS, elle sauve vraiment le Mage.
      Combat.deal_damage(state, nil, mage, 999, "physique", nil, { brut = true })
      assert.is_false(mage.survie)
      assert.is_true(mage.renaissante_used)

      -- Un nouveau combat NE LA RECHARGE PLUS -- "1 fois par run" consommée.
      Game.start_next_combat(state)
      mage = Combat.hero_by_id(state, "mage")
      assert.is_false(mage.survie)
      -- Même à un combat ENCORE plus tard : toujours pas.
      Game.start_next_combat(state)
      mage = Combat.hero_by_id(state, "mage")
      assert.is_false(mage.survie)
    end)

    it("une charge accordée par une carte (pas la bénédiction) ne se recharge JAMAIS toute seule, quel que soit le nombre de combats", function()
      paladin.survie = true -- simule une charge accordée par une carte
      Combat.deal_damage(state, nil, paladin, 999, "physique", nil, { brut = true })
      assert.is_false(paladin.survie)

      Game.start_next_combat(state)
      paladin = Combat.hero_by_id(state, "paladin")
      assert.is_false(paladin.survie) -- pas de bénédiction -> jamais rechargée toute seule
    end)
  end)

  describe("Chant du Cygne / Requiem (Legs/Héritage du Barde)", function()
    it("Legs : Inspiration 2 immédiate, réappliquée par COMBAT (pas par tour)", function()
      barde.hp = 0 -- mort subie -> Legs
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-barde" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(2, mage.inspiration) -- immédiat

      -- Un simple Game.start_turn ne doit RIEN ajouter (combat_start_status,
      -- pas turn_start_status) -- seule une vraie entrée en combat le ferait.
      mage.inspiration = 0
      Game.start_turn(state)
      assert.are.equal(0, mage.inspiration)
    end)

    it("Héritage : Inspiration 2 immédiate, réappliquée CHAQUE TOUR", function()
      barde.hp = 0
      barde.died_voluntarily = true
      Game.process_hero_deaths(state)
      local heritage_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-barde" then heritage_card = c end
      end
      state.hand[#state.hand + 1] = heritage_card
      Game.select_card(state, heritage_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(2, mage.inspiration)

      mage.inspiration = 0
      Game.start_turn(state)
      assert.are.equal(2, mage.inspiration)
      mage.inspiration = 0
      Game.start_turn(state)
      assert.are.equal(2, mage.inspiration) -- encore vrai au tour suivant
    end)
  end)

  describe("Écho du Barde", function()
    it("donne 2 Inspiration de base, 3 amélioré, à l'allié ciblé", function()
      state.hand[#state.hand + 1] = { uid = "echo-barde-base", def = Cards.by_code("echo-barde") }
      Game.select_card(state, "echo-barde-base")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(2, mage.inspiration)

      state.hand[#state.hand + 1] = { uid = "echo-barde-ameliore", def = Cards.by_code("echo-barde-ameliore") }
      Game.select_card(state, "echo-barde-ameliore")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(5, mage.inspiration) -- 2 (déjà posé) + 3
    end)
  end)

  -- "Trahison Planifiée"/"Voile de Brume"/"Requiem"/"Écho de l'Assassin"
  -- (2026-10-01, 5ᵉ classe designée carte par carte).
  describe("Trahison Planifiée (Mise à mort de l'Assassin)", function()
    -- Condition corrigée le 2026-10-03 ("Seulement 2 aventuriers vivants",
    -- pas "au moins 2") : `#living_heroes == 2`, jamais `>= 2`. Ne laisse que
    -- l'Assassin et le Mage en vie avant chaque test qui doit réellement
    -- pouvoir jouer la carte -- sinon le décompte par défaut (6 héros vivants
    -- posés par le before_each du fichier) la rendrait injouable.
    before_each(function()
      for _, h in ipairs(state.heroes) do
        if h.id ~= "assassin" and h.id ~= "mage" then h.hp = 0 end
      end
    end)

    it("injouable à moins de 2 aventuriers vivants", function()
      mage.hp = 0 -- ne laisse que l'Assassin en vie -- 1 seul aventurier vivant.
      assert.are.equal("refused", play("mise-a-mort-assassin", "u-trah-1", "ally", mage.id))
    end)

    it("injouable à plus de 2 aventuriers vivants (\"Seulement 2\", pas \"au moins 2\")", function()
      paladin.hp = paladin.max_hp -- 3 aventuriers vivants : Assassin, Mage, Paladin.
      assert.are.equal("refused", play("mise-a-mort-assassin", "u-trah-1b", "ally", mage.id))
    end)

    it("refuse de cibler l'Assassin lui-même (exclude_self_target)", function()
      assert.are.equal("assigned", play("mise-a-mort-assassin", "u-trah-2", "ally", assassin.id))
      assert.are.equal(assassin.max_hp, assassin.hp) -- rien résolu, toujours vivant
      assert.is_not_nil(state.pending)
    end)

    -- 2026-10-02, REVIREMENT explicite -- "Trahison planifiée tue un allié
    -- et déclenche son Héritage, pas le Legs" : remplace le test précédent,
    -- qui validait l'inverse (Legs).
    it("tue l'ALLIÉ ciblé (pas l'Assassin), dépose un HÉRITAGE (pas un Legs -- \"Mise à mort\" l'impose)", function()
      play("mise-a-mort-assassin", "u-trah-3", "ally", mage.id)
      assert.are.equal(0, mage.hp)
      assert.is_true(mage.died_voluntarily)
      assert.are.equal(assassin.max_hp, assassin.hp) -- l'Assassin survit

      local has_legs, has_heritage = false, false
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-mage" then has_legs = true end
        if c.def.code == "heritage-mage" then has_heritage = true end
      end
      assert.is_false(has_legs)
      assert.is_true(has_heritage)
    end)

    it("l'Assassin devient Camouflé et gagne Puissance 6, gain INSTANTANÉ (pas de buff permanent)", function()
      play("mise-a-mort-assassin", "u-trah-4", "ally", mage.id)
      assert.are.equal(1, assassin.camoufle)
      assert.are.equal(6, assassin.puissance)
      assert.are.equal(0, #assassin.permanent_buffs) -- 2026-10-03 : plus de Game.grant_permanent_buff

      assassin.camoufle, assassin.puissance = 0, 0
      Game.start_next_combat(state)
      assassin = Combat.hero_by_id(state, "assassin")
      assert.are.equal(0, assassin.camoufle) -- ne se réapplique plus au combat suivant
      assert.are.equal(0, assassin.puissance)
    end)

    it("Camouflage immédiat annule une attaque déjà télégraphiée contre l'Assassin", function()
      local enemy = state.enemies[1]
      enemy.next_move = { kind = "dmg", amount = 5 }
      enemy.target_hero_id = assassin.id
      play("mise-a-mort-assassin", "u-trah-5", "ally", mage.id)
      assert.is_nil(enemy.next_move)
    end)
  end)

  describe("Voile de Brume / Requiem (Legs/Héritage de l'Assassin)", function()
    it("Legs \"Voile de Brume\" : gain INSTANTANÉ d'Esquive 2, PAS un buff permanent", function()
      assassin.hp = 0 -- mort subie -> Legs
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-assassin" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(2, mage.esquive)
      assert.are.equal(0, #mage.permanent_buffs) -- pas de Game.grant_permanent_buff pour ce Legs
    end)

    it("Héritage \"Requiem\" : Camouflage + Esquive 2 immédiats, PERMANENTS (réappliqués chaque combat)", function()
      assassin.hp = 0
      assassin.died_voluntarily = true
      Game.process_hero_deaths(state)
      local heritage_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-assassin" then heritage_card = c end
      end
      state.hand[#state.hand + 1] = heritage_card
      Game.select_card(state, heritage_card.uid)
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(1, mage.camoufle)
      assert.are.equal(2, mage.esquive)

      mage.camoufle, mage.esquive = 0, 0
      Game.start_next_combat(state)
      mage = Combat.hero_by_id(state, "mage")
      assert.are.equal(1, mage.camoufle)
      assert.are.equal(2, mage.esquive)
    end)
  end)

  describe("Écho de l'Assassin", function()
    it("donne \"Esquive\" 1 de base, 2 amélioré, à l'allié ciblé", function()
      state.hand[#state.hand + 1] = { uid = "echo-ass-base", def = Cards.by_code("echo-assassin") }
      Game.select_card(state, "echo-ass-base")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(1, mage.esquive)

      state.hand[#state.hand + 1] = { uid = "echo-ass-ameliore", def = Cards.by_code("echo-assassin-ameliore") }
      Game.select_card(state, "echo-ass-ameliore")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(3, mage.esquive) -- 1 (déjà posé) + 2
    end)
  end)

  -- "Transfert Interdit"/"Étincelle de magie"/"Arcane Oublié"/"Écho du Mage"
  -- (2026-10-02, 6ᵉ classe designée carte par carte).
  describe("Transfert Interdit (Mise à mort du Mage)", function()
    it("injouable si le Mage a du mana, jouable à 0 mana", function()
      mage.mana = 1
      assert.are.equal("refused", play("mise-a-mort-mage", "u-trans-1", "ally", guerrier.id))
      mage.mana = 0
      state.hand = {}
      assert.are.equal("assigned", play("mise-a-mort-mage", "u-trans-2", "ally", guerrier.id))
    end)

    it("refuse de cibler le Mage lui-même (exclude_self_target)", function()
      mage.mana = 0
      assert.are.equal("assigned", play("mise-a-mort-mage", "u-trans-3", "ally", mage.id))
      assert.are.equal(mage.max_hp, mage.hp)
      assert.is_not_nil(state.pending)
    end)

    it("tue l'allié ciblé (Héritage, pas Legs), le Mage gagne 10 mana/Exaltation 5/PV max", function()
      mage.mana = 0
      mage.hp = 1 -- pour verifier le "regagne tous ses PV"
      play("mise-a-mort-mage", "u-trans-4", "ally", guerrier.id)
      assert.are.equal(0, guerrier.hp)
      assert.is_true(guerrier.died_voluntarily)
      assert.are.equal(10, mage.mana)
      assert.are.equal(5, mage.exaltation)
      assert.are.equal(mage.max_hp, mage.hp)

      local has_legs, has_heritage = false, false
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-guerrier" then has_legs = true end
        if c.def.code == "heritage-guerrier" then has_heritage = true end
      end
      assert.is_false(has_legs)
      assert.is_true(has_heritage)
    end)
  end)

  describe("Étincelle de magie / Arcane Oublié (Legs/Héritage du Mage)", function()
    it("Legs : +2 etincelle immédiat, permanent (combat_start_status vide -- pas de champ de statut, juste le bonus flat)", function()
      mage.hp = 0
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-mage" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", guerrier.id)
      assert.are.equal(1, #guerrier.permanent_buffs)
      assert.are.equal(2, guerrier.permanent_buffs[1].etincelle_bonus)
    end)

    it("le bonus etincelle augmente réellement les dégâts magiques du porteur", function()
      mage.hp = 0
      mage.died_voluntarily = true -- pour obtenir l'Héritage (Arcane Oublié), pas le Legs
      Game.process_hero_deaths(state)
      local heritage_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-mage" then heritage_card = c end
      end
      state.hand[#state.hand + 1] = heritage_card
      Game.select_card(state, heritage_card.uid)
      Game.resolve_pending(state, "ally", guerrier.id)

      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      Combat.deal_damage(state, guerrier, enemy, 4, "magique", nil)
      assert.are.equal(hp_before - 9, enemy.hp) -- 4 de base + 5 du buff Héritage
      -- Vérifie aussi que le bonus ne s'applique JAMAIS aux dégâts physiques.
      local hp_before2 = enemy.hp
      Combat.deal_damage(state, guerrier, enemy, 4, "physique", nil)
      assert.are.equal(hp_before2 - 4, enemy.hp)
    end)
  end)

  describe("Écho du Mage", function()
    it("inflige 3 degats magiques de base, 5 amélioré", function()
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      state.hand[#state.hand + 1] = { uid = "echo-mage-base", def = Cards.by_code("echo-mage") }
      Game.select_card(state, "echo-mage-base")
      Game.resolve_pending(state, "enemy", enemy.id)
      assert.are.equal(hp_before - 3, enemy.hp)

      local hp_before2 = enemy.hp
      state.hand[#state.hand + 1] = { uid = "echo-mage-ameliore", def = Cards.by_code("echo-mage-ameliore") }
      Game.select_card(state, "echo-mage-ameliore")
      Game.resolve_pending(state, "enemy", enemy.id)
      assert.are.equal(hp_before2 - 5, enemy.hp)
    end)
  end)

  -- "Pacte de sang"/"Siphon de vie"/"Mangeur d'âme"/"Écho du Nécromancien"
  -- (2026-10-02, 7ᵉ classe designée carte par carte) + le mot-clé "Vol de
  -- Vie" (Combat.deal_damage/Game.decay_end_of_turn_statuses).
  describe("Pacte de sang (Mise à mort du Nécromancien)", function()
    it("injouable sans Corruption, jouable dès qu'il en a", function()
      necromancien.corruption = 0
      assert.are.equal("refused", play("mise-a-mort-necromancien", "u-pacte-1", "ally", guerrier.id))
      necromancien.corruption = 1
      state.hand = {}
      assert.are.equal("assigned", play("mise-a-mort-necromancien", "u-pacte-2", "ally", guerrier.id))
    end)

    it("refuse de se cibler lui-même (exclude_self_target)", function()
      necromancien.corruption = 1
      assert.are.equal("assigned", play("mise-a-mort-necromancien", "u-pacte-3", "ally", necromancien.id))
      assert.are.equal(necromancien.max_hp, necromancien.hp)
      assert.is_not_nil(state.pending)
    end)

    it("tue l'allié ciblé (Héritage), le Nécromancien gagne X PV max/PV/Corruption (X = PV actuels de la cible)", function()
      necromancien.corruption = 1
      local base_max_hp, base_hp, base_corruption = necromancien.max_hp, necromancien.hp, necromancien.corruption
      local target_hp = guerrier.hp -- capturé AVANT la mort (Game.kill_hero met hp a 0)
      play("mise-a-mort-necromancien", "u-pacte-4", "ally", guerrier.id)
      assert.are.equal(0, guerrier.hp)
      assert.is_true(guerrier.died_voluntarily)
      assert.are.equal(base_max_hp + target_hp, necromancien.max_hp)
      assert.are.equal(base_hp + target_hp, necromancien.hp)
      assert.are.equal(base_corruption + target_hp, necromancien.corruption)

      local has_heritage = false
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-guerrier" then has_heritage = true end
      end
      assert.is_true(has_heritage)
    end)
  end)

  describe("Siphon de vie / Mangeur d'âme (Legs/Héritage du Nécromancien)", function()
    it("Legs : Vol de Vie 3 instantané, PAS un buff permanent", function()
      necromancien.hp = 0
      Game.process_hero_deaths(state)
      local legs_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "legs-necromancien" then legs_card = c end
      end
      state.hand[#state.hand + 1] = legs_card
      Game.select_card(state, legs_card.uid)
      Game.resolve_pending(state, "ally", guerrier.id)
      assert.are.equal(3, guerrier.vol_de_vie)
      assert.are.equal(0, #guerrier.permanent_buffs)
    end)

    it("Héritage : Vol de Vie 3 immédiat, PERMANENT (réappliqué à chaque combat)", function()
      necromancien.hp = 0
      necromancien.died_voluntarily = true
      Game.process_hero_deaths(state)
      local heritage_card
      for _, c in ipairs(state.discard) do
        if c.def.code == "heritage-necromancien" then heritage_card = c end
      end
      state.hand[#state.hand + 1] = heritage_card
      Game.select_card(state, heritage_card.uid)
      Game.resolve_pending(state, "ally", guerrier.id)
      assert.are.equal(3, guerrier.vol_de_vie)

      guerrier.vol_de_vie = 0
      Game.start_next_combat(state)
      guerrier = Combat.hero_by_id(state, "guerrier")
      assert.are.equal(3, guerrier.vol_de_vie)
    end)
  end)

  describe("Écho du Nécromancien", function()
    it("coûte 2 PV et donne 4 bouclier de base, 10 amélioré", function()
      local hp_before = mage.hp
      state.hand[#state.hand + 1] = { uid = "echo-necro-base", def = Cards.by_code("echo-necromancien") }
      Game.select_card(state, "echo-necro-base")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(hp_before - 2, mage.hp)
      assert.are.equal(4, mage.defense)

      local hp_before2 = mage.hp
      state.hand[#state.hand + 1] = { uid = "echo-necro-ameliore", def = Cards.by_code("echo-necromancien-ameliore") }
      Game.select_card(state, "echo-necro-ameliore")
      Game.resolve_pending(state, "ally", mage.id)
      assert.are.equal(hp_before2 - 2, mage.hp)
      assert.are.equal(14, mage.defense) -- 4 (deja pose) + 10
    end)
  end)
end)
