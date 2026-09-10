-- Premier lot de tests Busted du projet (2026-09-10, demande explicite --
-- "on commence petit à petit, par les Enchantements") : couvre les 12 cartes
-- "Enchantement" ajoutées le 2026-09-03 -- données (types/palier/cible/valeurs
-- base+amélioré) ET intégration complète des 12 mécaniques réactives sur un
-- état de combat à 6 héros. Reprend telles quelles les assertions déjà
-- validées à la main via le harnais LÖVE ad-hoc de cette session (aucune
-- nouvelle hypothèse introduite ici, juste une conversion vers un vrai
-- framework de tests). Modules purs, sans dépendance LÖVE (voir leurs propres
-- commentaires d'en-tête) -- tournent tels quels sous Busted/Lua 5.4.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")

describe("Cartes Enchantement", function()
  local function check_field(code, field, base_val, up_val)
    local def = Cards.by_code(code)

    it(code .. " existe, type Enchantement seul, palier Avancé, cible self", function()
      assert.is_not_nil(def)
      assert.is_not_nil(def.types)
      assert.are.equal(1, #def.types)
      assert.are.equal("enchantment", def.types[1])
      assert.are.equal("avance", def.tier)
      assert.are.equal("self", def.target)
    end)

    it(code .. " pose " .. field .. " = " .. tostring(base_val) .. " (base) / " .. tostring(up_val) .. " (amélioré)", function()
      local h1 = {}
      def.effect({ hero = h1 })
      assert.are.equal(base_val, h1[field])

      local up = Cards.upgraded_def(def)
      local h2 = {}
      up.effect({ hero = h2 })
      assert.are.equal(up_val, h2[field])
    end)
  end

  check_field("instinct-chasseur", "instinct_chasseur", 4, 6)
  check_field("frenesie", "frenesie_step", 0.5, 0.75)
  check_field("bouclier-vivant", "bouclier_vivant_ratio", 0.5, 1.0)
  check_field("bouclier-pointes", "shield_thorns", 1, 2)
  check_field("combustion-differee", "combustion_differee", 1, 2)
  check_field("second-souffle", "second_souffle", 2, 3)
  check_field("ombre-patiente", "ombre_patiente", 1, 2)
  check_field("imperceptible", "imperceptible", 2, 4)
  check_field("rite-chair", "rite_de_la_chair", 2, 3)
  check_field("pacte-survie", "pacte_survie", 1, 2)
  check_field("tournee-finale", "tournee_finale", 4, 6)

  describe("Mémoire mélodique (coût qui baisse à l'amélioration, comme Coup de taille)", function()
    local def = Cards.by_code("memoire-melodique")

    it("coûte 2 en base, 1 amélioré", function()
      assert.are.equal(2, def.cost)
      assert.are.equal(1, Cards.upgraded_def(def).cost)
    end)

    it("pose memoire_melodique = true (base et amélioré)", function()
      local h = {}
      def.effect({ hero = h })
      assert.is_true(h.memoire_melodique)
    end)
  end)
end)

describe("Mécaniques réactives des Enchantements (intégration, 6 classes)", function()
  local state, guerrier, paladin, mage, assassin, necro, barde, enemy1

  local function hero(id) return Combat.hero_by_id(state, id) end

  local function inject_into_hand(code)
    local def = Cards.by_code(code)
    local uid = "test-" .. code .. "-" .. tostring(math.random(1, 1e9))
    state.hand[#state.hand + 1] = { uid = uid, def = def }
    return uid
  end

  local function play_targeting_enemy(code, target)
    local uid = inject_into_hand(code)
    assert.are.equal("assigned", Game.select_card(state, uid))
    Game.resolve_pending(state, "enemy", target.id)
  end

  local function play_self(code)
    local uid = inject_into_hand(code)
    assert.are.equal("assigned", Game.select_card(state, uid))
    Game.resolve_pending(state, "self", nil)
  end

  before_each(function()
    state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "paladin", "mage", "assassin", "necromancien", "barde" }, nil)
    state.energy = 99
    guerrier, paladin, mage, assassin, necro, barde =
      hero("guerrier"), hero("paladin"), hero("mage"), hero("assassin"), hero("necromancien"), hero("barde")
    for _, e in ipairs(state.enemies) do e.hp = 999; e.max_hp = 999 end
    enemy1 = state.enemies[1]
  end)

  describe("Guerrier", function()
    it("Instinct du Chasseur : bouclier à chaque coup porté, répétable", function()
      guerrier.instinct_chasseur = 4
      Combat.deal_damage(state, guerrier, enemy1, 5, "physique", nil)
      assert.are.equal(4, guerrier.defense)
      Combat.deal_damage(state, guerrier, enemy1, 5, "physique", nil)
      assert.are.equal(8, guerrier.defense)
    end)

    it("Frénésie : +50% par carte Offensive déjà jouée ce tour, compte 1x/carte (pas 1x/ennemi touché)", function()
      guerrier.frenesie_step = 0.5
      guerrier.frenesie_bonus_pct = 0
      local hp1 = enemy1.hp
      play_self("coup-taille") -- all-enemies, pas de statut secondaire (Vulnerabilite) qui fausserait le calcul
      assert.are.equal(3, hp1 - enemy1.hp) -- 1ère carte : tarif normal
      local hp2 = enemy1.hp
      play_self("coup-taille")
      assert.are.equal(5, hp2 - enemy1.hp) -- 2ème carte : 3 * 1.5 = 4.5 -> arrondi 5
    end)

    it("Frénésie : le bonus repart à 0 au tour suivant", function()
      guerrier.frenesie_step = 0.5
      guerrier.frenesie_bonus_pct = 0.5
      Game.start_turn(state)
      assert.are.equal(0, guerrier.frenesie_bonus_pct)
    end)
  end)

  describe("Paladin", function()
    it("Bouclier vivant : l'autre allié le plus bas en PV reçoit la moitié, jamais le Paladin lui-même", function()
      paladin.bouclier_vivant_ratio = 0.5
      mage.hp = 5 -- le plus bas en PV parmi le reste de l'équipe
      Combat.grant_defense(paladin, 10, { state = state })
      assert.are.equal(10, paladin.defense)
      assert.are.equal(5, mage.defense)
    end)

    it("Bouclier de pointes : renvoie des dégâts bruts proportionnels au bouclier absorbé", function()
      paladin.shield_thorns = 1
      paladin.defense = 5
      local enemy_hp_before = enemy1.hp
      Combat.deal_damage(state, nil, paladin, 3, "physique", nil, { source_unit = enemy1 })
      assert.are.equal(2, paladin.defense) -- 5 - 3 absorbés
      assert.are.equal(enemy_hp_before - 3, enemy1.hp) -- 1 dégât brut par point absorbé
    end)
  end)

  describe("Mage", function()
    it("Combustion différée : applique Brûlure sur chaque dégât feu", function()
      mage.combustion_differee = 1
      Combat.deal_damage(state, mage, enemy1, 3, "magique", { card_def = { cats = { "feu" } } })
      assert.are.equal(1, enemy1.brulure)
    end)

    it("Second Souffle : régénère du mana à chaque retour à 0, répétable", function()
      mage.second_souffle = 2
      mage.mana = 1
      play_targeting_enemy("missile-magique", enemy1) -- mana_cost 1 : 1 -> 0 -> Second Souffle -> 2
      assert.are.equal(2, mage.mana)
      mage.mana = 1
      play_targeting_enemy("missile-magique", enemy1)
      assert.are.equal(2, mage.mana)
    end)
  end)

  describe("Assassin", function()
    it("Imperceptible : +2 sur chaque gain de Discrétion, quelle qu'en soit la source", function()
      assassin.imperceptible = 2
      assassin.discretion = 0
      Game.gain_discretion(state, assassin, 5)
      assert.are.equal(7, assassin.discretion)
    end)

    it("Ombre Patiente : Puissance à chaque entrée en Camouflé, répétable sans plafond", function()
      assassin.ombre_patiente = 1
      assassin.discretion, assassin.camoufle, assassin.puissance = 0, 0, 0
      Game.gain_discretion(state, assassin, 5)
      assert.are.equal(0, assassin.puissance) -- pas encore Camouflé
      Game.gain_discretion(state, assassin, 5) -- 5+5=10 -> Camouflé
      assert.are.equal(10, assassin.discretion)
      assert.are.equal(1, assassin.puissance)
      assassin.discretion, assassin.camoufle = 0, 0
      Game.gain_discretion(state, assassin, 10) -- redevient Camouflé une 2ème fois
      assert.are.equal(2, assassin.puissance)
    end)
  end)

  describe("Nécromancien", function()
    it("Pacte de Survie : bouclier proportionnel à chaque perte de PV", function()
      necro.pacte_survie = 1
      Combat.deal_damage(state, nil, necro, 6, nil, nil, { brut = true })
      assert.are.equal(6, necro.defense)
    end)

    it("Rite de la Chair : Corruption automatique et inconditionnelle à chaque début de tour", function()
      necro.rite_de_la_chair = 2
      necro.corruption = 0
      Game.start_turn(state)
      assert.are.equal(2, necro.corruption)
    end)
  end)

  describe("Barde", function()
    it("Mémoire mélodique : rend une autre carte de la main gratuite ce tour, jamais la carte tout juste jouée", function()
      barde.memoire_melodique = true
      state.hand = {}
      local barde_uid = inject_into_hand("choeur-bataille") -- target=self, carte Barde
      local other1 = inject_into_hand("coup-appuye") -- coût 1 de base
      local other2 = inject_into_hand("bouclier-pointes") -- coût 2 de base
      local original_cost = { [other1] = 1, [other2] = 2 }

      assert.are.equal("assigned", Game.select_card(state, barde_uid))
      Game.resolve_pending(state, "self", nil)

      local free_uid
      for uid in pairs(state.turn_free_uids) do free_uid = uid end
      assert.is_not_nil(free_uid)
      assert.are_not.equal(barde_uid, free_uid)

      local freed_cost
      for _, c in ipairs(state.hand) do
        if c.uid == free_uid then freed_cost = c.def.cost end
      end
      assert.are.equal(0, freed_cost)

      -- Revient à son coût normal au tour SUIVANT (pas au combat suivant,
      -- contrairement au "coût 0" permanent d'Avalanche de coups).
      Game.start_turn(state)
      local still_free
      for _, c in ipairs(state.hand) do
        if c.uid == free_uid then still_free = c.def.cost end
      end
      assert.are.equal(original_cost[free_uid], still_free)
    end)

    it("Tournée finale : bouclier à l'allié qui consomme une charge d'Inspiration (pas seulement la dernière)", function()
      barde.tournee_finale = 4
      mage.inspiration = 1
      mage.mana = 2
      play_targeting_enemy("missile-magique", enemy1)
      assert.are.equal(4, mage.defense)
      assert.are.equal(0, mage.inspiration)
    end)
  end)
end)
