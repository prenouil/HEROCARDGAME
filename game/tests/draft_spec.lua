-- Draft.pick_cards (2026-08-29, écran de choix d'équipe -- le pool de cartes
-- proposées doit refléter les classes RÉELLEMENT présentes dans CETTE run,
-- state.heroes, plus le catalogue complet Heroes.defs qui liste désormais
-- les 6 aventuriers débloqués).

local Draft = require("src.rules.draft")
local Rng = require("src.util.rng")

local function make_state(class_ids)
  local heroes = {}
  for i, cid in ipairs(class_ids) do
    heroes[i] = { id = cid, class_id = cid, name = cid, hp = 20, max_hp = 20 }
  end
  return {
    heroes = heroes, deck = {}, hand = {}, discard = {},
    rng = { draft = Rng.new(1) },
  }
end

describe("Draft.pick_cards : pool limité aux classes de LA RUN EN COURS", function()
  it("ne propose que des cartes des classes présentes dans state.heroes", function()
    local state = make_state({ "necromancien", "barde" })
    local picks = Draft.pick_cards(state)
    assert.equal(3, #picks)
    for _, def in ipairs(picks) do
      assert.is_true(def.class_id == "necromancien" or def.class_id == "barde",
        "carte inattendue : " .. def.class_id)
    end
  end)

  it("exclut une classe du catalogue qui n'est PAS dans cette run (ex. Mage absent)", function()
    local state = make_state({ "guerrier", "paladin", "assassin" })
    local picks = Draft.pick_cards(state)
    for _, def in ipairs(picks) do
      assert.is_not.equal("mage", def.class_id)
    end
  end)
end)
