-- Évènement "Prédiction de la Mort" (game/src/rules/prediction.lua) --
-- 2026-10-03. Couverture ciblée sur Prediction.eligible_cards/viable --
-- l'écran lui-même (choix/animation) vit dans controller.lua/view/prediction.lua,
-- hors périmètre de Busted (dépendance LÖVE).

local Prediction = require("src.rules.prediction")
local Game = require("src.rules.game")
local Combat = require("src.rules.combat")

describe("Prediction.eligible_cards / Prediction.viable", function()
  local state

  before_each(function()
    state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "mage", "paladin", "assassin" }, nil)
  end)

  it("1 carte Mise à mort éligible par héros vivant, aucune pour un héros mort", function()
    local eligible = Prediction.eligible_cards(state)
    assert.are.equal("mise-a-mort-guerrier", eligible.guerrier.code)
    assert.are.equal("mise-a-mort-mage", eligible.mage.code)
    assert.are.equal("mise-a-mort-paladin", eligible.paladin.code)
    assert.are.equal("mise-a-mort-assassin", eligible.assassin.code)

    Combat.hero_by_id(state, "mage").hp = 0
    local eligible2 = Prediction.eligible_cards(state)
    assert.is_nil(eligible2.mage)
    assert.is_not_nil(eligible2.guerrier)
  end)

  it("exclut une carte Mise à mort déjà dans state.run.drafted_mise_a_mort (même bookkeeping que le draft)", function()
    state.run.drafted_mise_a_mort["mise-a-mort-guerrier"] = true
    local eligible = Prediction.eligible_cards(state)
    assert.is_nil(eligible.guerrier)
    assert.is_not_nil(eligible.mage)
  end)

  it("viable avec >= 2 vivants et au moins 1 carte éligible", function()
    assert.is_true(Prediction.viable(state))
  end)

  it("non viable s'il ne reste qu'1 seul aventurier vivant", function()
    Combat.hero_by_id(state, "mage").hp = 0
    Combat.hero_by_id(state, "paladin").hp = 0
    Combat.hero_by_id(state, "assassin").hp = 0
    assert.is_true(Combat.hero_by_id(state, "guerrier").hp > 0)
    assert.is_false(Prediction.viable(state))
  end)

  it("non viable si toutes les cartes Mise à mort restantes sont déjà prises", function()
    for _, id in ipairs({ "guerrier", "mage", "paladin", "assassin" }) do
      state.run.drafted_mise_a_mort["mise-a-mort-" .. id] = true
    end
    assert.is_false(Prediction.viable(state))
  end)
end)
