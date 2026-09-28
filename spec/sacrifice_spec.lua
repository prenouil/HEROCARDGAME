-- Pilier du sacrifice (2026-09-28) : Mise à mort / Legs / Héritage / Écho --
-- couverture d'intégration bout-en-bout (vrai Game.reset_run, comme
-- cards_spec.lua) en complément des tests unitaires ciblés déjà présents dans
-- game_turn_spec.lua (Game.kill_hero/process_hero_deaths/finish_card) et
-- combat_spec.lua (Combat.effective_owner/can_play).

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")

describe("Pilier du sacrifice -- intégration bout-en-bout", function()
  local state, guerrier, mage

  before_each(function()
    state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "mage", "assassin", "paladin" }, nil)
    state.energy = 99
    guerrier = Combat.hero_by_id(state, "guerrier")
    mage = Combat.hero_by_id(state, "mage")
  end)

  local function play(code, uid, kind, target_id)
    local def = Cards.by_code(code)
    state.hand[#state.hand + 1] = { uid = uid, def = def }
    local result = Game.select_card(state, uid)
    if result == "assigned" then Game.resolve_pending(state, kind, target_id) end
    return result
  end

  it("Mise à mort : tue son lanceur, dépose un Héritage (pas un Legs), convertit ses cartes en Écho", function()
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

  it("Legs/Héritage posthumes : jouables via un AUTRE héros vivant (Combat.effective_owner), jamais le défunt", function()
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
    -- Le lanceur assigné n'est JAMAIS le Guerrier mort -- un autre vivant de
    -- l'équipe (le premier de state.heroes encore en vie).
    assert.are_not.equal(guerrier.id, state.pending.hero_id)
    local assigned = Combat.hero_by_id(state, state.pending.hero_id)
    assert.is_true(assigned.hp > 0)
    Game.resolve_pending(state, "ally", mage.id)
    assert.is_nil(mage.heritage_count) -- Legs (pas Héritage) : jamais de heritage_count posé
  end)

  it("Écho posthume : SEULE exception -- reste jouable par son propriétaire mort lui-même", function()
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
end)
