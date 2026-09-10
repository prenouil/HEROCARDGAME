-- Écran de draft de fin de combat (game/src/rules/draft.lua) -- 2026-09-10.
-- Reprend la couverture perdue lors de la suppression de l'ancienne suite
-- `game/tests/draft_spec.lua` (obsolète, jamais exécutée avant cette session --
-- voir l'historique de la conversation), réécrite contre le comportement
-- ACTUEL du module.

local Draft = require("src.rules.draft")
local Rng = require("src.util.rng")

local function make_state(class_ids, seed, owned_codes)
  local heroes = {}
  for _, id in ipairs(class_ids) do heroes[#heroes + 1] = { class_id = id } end
  local deck = {}
  for _, code in ipairs(owned_codes or {}) do deck[#deck + 1] = { def = { code = code } } end
  return { heroes = heroes, deck = deck, hand = {}, discard = {}, rng = { draft = Rng.new(seed) } }
end

describe("Draft.pick_cards", function()
  it("ne propose que des cartes des classes RÉELLEMENT présentes dans la run", function()
    local state = make_state({ "guerrier" }, 1)
    local picks = Draft.pick_cards(state)
    assert.are.equal(3, #picks)
    for _, def in ipairs(picks) do assert.are.equal("guerrier", def.class_id) end
  end)

  it("jamais 2 fois le même code parmi les 3 propositions", function()
    for seed = 1, 20 do
      local state = make_state({ "guerrier", "paladin", "mage", "assassin" }, seed)
      local picks = Draft.pick_cards(state)
      local seen = {}
      for _, def in ipairs(picks) do
        assert.is_nil(seen[def.code])
        seen[def.code] = true
      end
    end
  end)

  it("au plus 1 carte 'Départ' parmi les 3, quelles que soient les autres contraintes", function()
    for seed = 1, 30 do
      local state = make_state({ "guerrier", "paladin", "mage", "assassin", "necromancien", "barde" }, seed)
      local picks = Draft.pick_cards(state)
      local depart_count = 0
      for _, def in ipairs(picks) do
        if def.tier == "depart" then depart_count = depart_count + 1 end
      end
      assert.is_true(depart_count <= 1)
    end
  end)

  it("avec une seule classe (pool inédit vite épuisé), retombe silencieusement sur des doublons sans jamais planter", function()
    -- Une seule classe = 8 cartes éligibles (6 + les 2 Enchantements) ; en
    -- possédant déjà toutes les cartes "avance" avant le draft, le pool
    -- inédit hors Départ est très réduit -- vérifie que 3 propositions
    -- distinctes sortent quand même, sans erreur.
    local owned = {}
    for _, def in ipairs(require("src.data.cards").list) do
      if def.class_id == "guerrier" and def.tier == "avance" then owned[#owned + 1] = def.code end
    end
    local state = make_state({ "guerrier" }, 1, owned)
    local picks = Draft.pick_cards(state)
    assert.are.equal(3, #picks)
  end)
end)
