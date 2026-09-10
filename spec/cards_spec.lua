-- Contenu carte-par-carte (game/src/data/cards.lua) -- 2026-09-10, suite de
-- la couverture Busted. Pas exhaustif sur les 48 cartes (beaucoup ne sont que
-- des dégâts/soins/boucliers plats, déjà couverts en creux par
-- Combat.deal_damage/grant_defense/grant_heal, voir spec/combat_spec.lua) --
-- concentré sur les cartes à VRAIE logique conditionnelle/à branches, là où
-- une régression peut se cacher : conditions sur Camouflé, plafonnement de
-- Corruption, redirections multi-ennemis, boucliers programmés.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")

describe("Cartes à logique conditionnelle", function()
  local state, paladin, assassin, necro, barde

  before_each(function()
    state = Game.new_state()
    Game.reset_run(state, 12345, { "paladin", "assassin", "necromancien", "barde" }, nil)
    state.energy = 99
    paladin = Combat.hero_by_id(state, "paladin")
    assassin = Combat.hero_by_id(state, "assassin")
    necro = Combat.hero_by_id(state, "necromancien")
    barde = Combat.hero_by_id(state, "barde")
    for _, e in ipairs(state.enemies) do e.hp = 999; e.max_hp = 999 end
  end)

  local function play(code, kind, target_id)
    local def = Cards.by_code(code)
    local uid = "test-" .. code
    state.hand[#state.hand + 1] = { uid = uid, def = def }
    assert.are.equal("assigned", Game.select_card(state, uid))
    Game.resolve_pending(state, kind, target_id)
  end

  local function play_upgraded(code, kind, target_id)
    local def = Cards.upgraded_def(Cards.by_code(code))
    local uid = "test-" .. code .. "-up"
    state.hand[#state.hand + 1] = { uid = uid, def = def }
    assert.are.equal("assigned", Game.select_card(state, uid))
    Game.resolve_pending(state, kind, target_id)
  end

  describe("En traître (Assassin) : entièrement conditionnelle à Camouflé", function()
    it("sans Camouflé : ne fait STRICTEMENT rien (le coût est payé pour rien)", function()
      assassin.camoufle = 0
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play("en-traitre", "enemy", enemy.id)
      assert.are.equal(hp_before, enemy.hp)
      assert.are.equal(0, enemy.saignements) -- déjà initialisé à 0 par Encounter.instantiate_enemy, jamais touché
    end)

    it("Camouflé : dégâts + Saignements", function()
      assassin.camoufle = 1
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play("en-traitre", "enemy", enemy.id)
      assert.are.equal(hp_before - 6, enemy.hp)
      assert.are.equal(3, enemy.saignements)
    end)
  end)

  describe("Assassinat (Assassin) : branche dégâts VS branche consolation", function()
    it("Camouflé : dégâts purs, rien d'autre", function()
      assassin.camoufle = 1
      assassin.discretion, assassin.puissance = 0, 0
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play("assassinat", "enemy", enemy.id)
      assert.are.equal(hp_before - 12, enemy.hp)
      assert.are.equal(0, assassin.discretion)
      assert.are.equal(0, assassin.puissance)
    end)

    it("pas Camouflé : lot de consolation (Discrétion + Puissance), AUCUN dégât, retourne sur le dessus du deck", function()
      assassin.camoufle = 0
      assassin.discretion, assassin.puissance = 0, 0
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      -- Game.reset_run a déjà pioché la main d'ouverture : on compare un
      -- AVANT/APRÈS plutôt qu'un compte absolu du deck.
      local deck_before, discard_before = #state.deck, #state.discard
      play("assassinat", "enemy", enemy.id)
      assert.are.equal(hp_before, enemy.hp) -- aucun dégât
      assert.are.equal(5, assassin.discretion)
      assert.are.equal(2, assassin.puissance)
      assert.are.equal(deck_before + 1, #state.deck) -- revenue sur le dessus du deck
      assert.are.equal(discard_before, #state.discard) -- jamais en défausse
    end)
  end)

  describe("Repli stratégique (Assassin) : redirige TOUS les ennemis qui visent l'Assassin", function()
    it("redirige chaque ennemi qui le visait vers l'allié ciblé, qui gagne du bouclier par ennemi redirigé", function()
      -- Garantit 3 ennemis distincts pour un scénario déterministe, quel que
      -- soit ce que le tirage RNG a réellement généré pour ce seed.
      while #state.enemies < 3 do
        local clone = {}
        for k, v in pairs(state.enemies[1]) do clone[k] = v end
        clone.id = state.enemies[1].id .. "-clone" .. #state.enemies
        state.enemies[#state.enemies + 1] = clone
      end
      local e1, e2, e3 = state.enemies[1], state.enemies[2], state.enemies[3]
      e1.next_move, e1.target_hero_id = { kind = "dmg" }, assassin.id
      e2.next_move, e2.target_hero_id = { kind = "dmg" }, assassin.id
      e3.next_move, e3.target_hero_id = { kind = "dmg" }, barde.id -- ne vise pas l'Assassin

      local barde_def_before = barde.defense or 0
      play("repli-strategique", "ally", barde.id)

      assert.are.equal(barde.id, e1.target_hero_id)
      assert.are.equal(barde.id, e2.target_hero_id)
      assert.are.equal(barde.id, e3.target_hero_id) -- déjà sur le Barde, inchangé
      assert.are.equal(barde_def_before + 12, barde.defense) -- 6 * 2 ennemis redirigés
    end)

    it("aucun ennemi ne vise l'Assassin : 0 bouclier, personne de redirigé", function()
      state.enemies[1].next_move, state.enemies[1].target_hero_id = { kind = "dmg" }, barde.id
      local barde_def_before = barde.defense or 0
      play("repli-strategique", "ally", barde.id)
      assert.are.equal(barde_def_before, barde.defense)
    end)
  end)

  describe("Rite mineur (Nécromancien) : dépense la Corruption utile SEULEMENT, jamais plus que nécessaire", function()
    it("plafonne la dépense au soin réellement nécessaire pour revenir à PV max", function()
      necro.corruption = 3 -- plafond de la carte
      necro.hp = necro.max_hp - 2 -- ne lui manque que 2 PV (soin_per_corruption=2 -> 1 seul point suffit)
      local enemy = state.enemies[1]
      play("rite-mineur", "enemy", enemy.id)
      assert.are.equal(necro.max_hp, necro.hp) -- remonté à PV max, jamais au-delà
      assert.are.equal(2, necro.corruption) -- seulement 1 point dépensé sur les 3 disponibles
    end)

    it("dépense tout ce qui est disponible si le besoin dépasse le plafond de la carte", function()
      necro.corruption = 3
      necro.hp = 1 -- besoin énorme, largement au-dessus de ce que 3 Corruption peuvent rendre
      local enemy = state.enemies[1]
      play("rite-mineur", "enemy", enemy.id)
      assert.are.equal(0, necro.corruption) -- tout dépensé, plafond de la carte atteint
      assert.are.equal(1 + 2 * 3, necro.hp) -- 1 + 2 PV par Corruption dépensée
    end)
  end)

  describe("Pacte funeste (Nécromancien) : auto-sacrifice proportionnel à ses PV ACTUELS", function()
    it("perd la moitié de ses PV actuels (arrondi au supérieur), inflige le double en necrose", function()
      necro.hp = 15 -- moitié = 7.5 -> arrondi à 8 PV perdus
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play("pacte-funeste", "enemy", enemy.id)
      assert.are.equal(7, necro.hp) -- 15 - 8
      assert.are.equal(hp_before - 16, enemy.hp) -- 8 * 2
    end)

    it("version améliorée : perd le TIERS de ses PV actuels, inflige le triple", function()
      necro.hp = 9 -- tiers = 3 pile
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play_upgraded("pacte-funeste", "enemy", enemy.id)
      assert.are.equal(6, necro.hp) -- 9 - 3
      assert.are.equal(hp_before - 9, enemy.hp) -- 3 * 3
    end)
  end)

  describe("Servant d'os (Nécromancien) : rien de programmé à Corruption 0 (volontaire, pas un oubli)", function()
    it("Corruption 0 : aucun dégât programmé, aucune erreur", function()
      necro.corruption = 0
      necro.scheduled_damages = {}
      play("servant-os", "self", nil)
      assert.are.equal(0, #necro.scheduled_damages)
    end)

    it("Corruption > 0 : programme 3 dégâts distincts (4 amélioré)", function()
      necro.corruption = 4
      necro.scheduled_damages = {}
      play("servant-os", "self", nil)
      assert.are.equal(3, #necro.scheduled_damages)

      necro.corruption = 4
      necro.scheduled_damages = {}
      play_upgraded("servant-os", "self", nil)
      assert.are.equal(4, #necro.scheduled_damages)
    end)
  end)

  describe("Provocateur (Paladin) : bouclier à l'allié, Provocation sur SOI (pas sur l'allié)", function()
    it("l'allié ciblé gagne du bouclier, le Paladin gagne la Provocation", function()
      local barde_def_before = barde.defense or 0
      paladin.provocation = 0
      play("provocateur", "ally", barde.id)
      assert.are.equal(barde_def_before + 4, barde.defense)
      assert.are.equal(2, paladin.provocation)
      assert.are.equal(0, barde.provocation or 0) -- jamais sur l'allié
    end)
  end)

  describe("Infranchissable (Paladin) : bouclier immédiat + programmé, Provocation", function()
    it("base : 1 bouclier immédiat + 1 SEUL bouclier programmé (tour+1)", function()
      paladin.scheduled_shields = {}
      local def_before = paladin.defense or 0
      play("infranchissable", "self", nil)
      assert.are.equal(def_before + 10, paladin.defense)
      assert.are.equal(1, #paladin.scheduled_shields)
      assert.are.equal(2, paladin.provocation)
    end)

    it("amélioré : 2 boucliers programmés DISTINCTS (tour+1 ET tour+2), pas un seul doublé", function()
      paladin.scheduled_shields = {}
      play_upgraded("infranchissable", "self", nil)
      assert.are.equal(2, #paladin.scheduled_shields)
    end)
  end)

  describe("Raillerie (Paladin) : redirige l'ennemi ciblé SEULEMENT s'il a une action ciblable", function()
    it("redirige un ennemi dont l'action est ciblable (dmg), gagne du bouclier dans tous les cas", function()
      local enemy = state.enemies[1]
      enemy.next_move, enemy.target_hero_id = { kind = "dmg" }, barde.id
      local def_before = paladin.defense or 0
      play("raillerie", "enemy", enemy.id)
      assert.are.equal(paladin.id, enemy.target_hero_id)
      assert.are.equal(def_before + 8, paladin.defense)
    end)

    it("un ennemi dont l'action n'est pas ciblable (ex. buff-self) n'est jamais redirigé", function()
      local enemy = state.enemies[1]
      enemy.next_move, enemy.target_hero_id = { kind = "buff-self" }, nil
      play("raillerie", "enemy", enemy.id)
      assert.is_nil(enemy.target_hero_id) -- toujours rien, pas redirigé vers le Paladin
    end)
  end)

  describe("Bis (Barde) : consomme l'Inspiration de la cible, sinon ne fait rien", function()
    it("l'allié a de l'Inspiration : elle est retirée, gagne Encore + Gratuite", function()
      assassin.inspiration = 3
      assassin.encore_extra_plays, assassin.gratuite = nil, nil
      play("bis", "ally", assassin.id)
      assert.are.equal(0, assassin.inspiration)
      assert.are.equal(1, assassin.encore_extra_plays)
      assert.are.equal(1, assassin.gratuite)
    end)

    it("l'allié n'a pas d'Inspiration : ne fait rien", function()
      assassin.inspiration = 0
      assassin.encore_extra_plays, assassin.gratuite = nil, nil
      play("bis", "ally", assassin.id)
      assert.is_nil(assassin.encore_extra_plays)
      assert.is_nil(assassin.gratuite)
    end)
  end)

  describe("Air belliqueux (Barde) : dégâts de base + bonus par charge d'Inspiration sur TOUS les alliés", function()
    it("aucune Inspiration sur personne : dégâts de base seuls", function()
      for _, h in ipairs(state.heroes) do h.inspiration = 0 end
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play("air-belliqueux", "enemy", enemy.id)
      assert.are.equal(hp_before - 3, enemy.hp)
    end)

    it("cumule l'Inspiration de TOUS les alliés vivants, pas seulement celle du Barde", function()
      paladin.inspiration, assassin.inspiration, necro.inspiration, barde.inspiration = 1, 2, 0, 0
      local enemy = state.enemies[1]
      local hp_before = enemy.hp
      play("air-belliqueux", "enemy", enemy.id)
      assert.are.equal(hp_before - (3 + 2 * 3), enemy.hp) -- 3 total d'Inspiration cumulée
    end)
  end)
end)
