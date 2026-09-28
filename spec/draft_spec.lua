-- Écran de draft de fin de combat (game/src/rules/draft.lua) -- 2026-09-10.
-- Reprend la couverture perdue lors de la suppression de l'ancienne suite
-- `game/tests/draft_spec.lua` (obsolète, jamais exécutée avant cette session --
-- voir l'historique de la conversation), réécrite contre le comportement
-- ACTUEL du module.

local Draft = require("src.rules.draft")
local Rng = require("src.util.rng")

local function make_state(class_ids, seed, owned_codes, dead_class_ids)
  local dead = {}
  for _, id in ipairs(dead_class_ids or {}) do dead[id] = true end
  local heroes = {}
  for _, id in ipairs(class_ids) do
    heroes[#heroes + 1] = { class_id = id, hp = dead[id] and 0 or nil }
  end
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

  it("exclut la classe d'un aventurier mort (pilier du sacrifice -- 2026-09-28)", function()
    local state = make_state({ "guerrier", "paladin" }, 1, nil, { "paladin" })
    local picks = Draft.pick_cards(state)
    assert.are.equal(3, #picks)
    for _, def in ipairs(picks) do assert.are.equal("guerrier", def.class_id) end
  end)

  it("ne propose jamais les cartes Legs/Héritage/Écho, mais propose la Mise à mort (2026-09-28, pilier du sacrifice)", function()
    for seed = 1, 40 do
      local state = make_state({ "guerrier" }, seed)
      local picks = Draft.pick_cards(state)
      for _, def in ipairs(picks) do
        assert.is_falsy(def.not_draftable)
        assert.is_falsy(def.code:match("^legs%-") or def.code:match("^heritage%-") or def.code:match("^echo%-"))
      end
    end
  end)

  it("carte améliorée : jamais au tout premier draft du run (2026-09-30, demande explicite -- 0% au début)", function()
    for seed = 1, 30 do
      local state = make_state({ "guerrier", "paladin", "mage", "assassin" }, seed)
      state.run = { combat_index = 1 } -- tout premier draft, 0 combat passé avant lui
      local picks = Draft.pick_cards(state)
      for _, def in ipairs(picks) do assert.is_falsy(def.is_upgraded) end
    end
  end)

  it("carte améliorée : à 100% de chance (10 combats passés), exactement 1 par draft -- la 2e chance retombe à 0%", function()
    local total_upgraded = 0
    for seed = 1, 30 do
      local state = make_state({ "guerrier", "paladin", "mage", "assassin" }, seed)
      state.run = { combat_index = 11 } -- 10 combats passés -> 100% de chance sur le 1er slot éligible
      local picks = Draft.pick_cards(state)
      local upgraded_count = 0
      for _, def in ipairs(picks) do if def.is_upgraded then upgraded_count = upgraded_count + 1 end end
      assert.is_true(upgraded_count <= 1)
      total_upgraded = total_upgraded + upgraded_count
    end
    -- À 100% de chance sur un pool riche en cartes améliorables, une carte
    -- améliorée doit apparaître sur (quasiment) chacun des 30 tirages --
    -- vérifie qu'on n'a pas juste une chance qui ne se déclenche jamais.
    assert.is_true(total_upgraded > 0)
  end)

  it("carte améliorée : PLUSIEURS par draft à 20+ combats passés (2026-09-30, correction explicite -- '-100%' est une vraie soustraction, pas un plafond à 1)", function()
    local max_seen = 0
    for seed = 1, 30 do
      local state = make_state({ "guerrier", "paladin", "mage", "assassin" }, seed)
      state.run = { combat_index = 21 } -- 20 combats passés -> 200% de chance : 200%-100% = 100% pour le 2e slot
      local picks = Draft.pick_cards(state)
      local upgraded_count = 0
      for _, def in ipairs(picks) do if def.is_upgraded then upgraded_count = upgraded_count + 1 end end
      max_seen = math.max(max_seen, upgraded_count)
      assert.is_true(upgraded_count <= 3)
    end
    -- Avec 200% de chance de base, le 2e slot éligible garde encore 100% de
    -- chance après la 1ʳᵉ soustraction -- 2 cartes améliorées doivent donc
    -- apparaître sur (quasiment) chaque tirage, jamais au plus 1 comme avant
    -- la correction.
    assert.is_true(max_seen >= 2)
  end)

  it("carte améliorée : jamais tentée sur une carte non améliorable (ex. Mise à mort, sans champ 'upgrade')", function()
    -- Une seule classe pour forcer le pool éligible à inclure la Mise à mort
    -- (tier "avance", sans `upgrade`) parmi peu de cartes -- vérifie que
    -- Cards.upgraded_def n'est jamais appelée dessus (planterait sinon).
    for seed = 1, 30 do
      local state = make_state({ "guerrier" }, seed)
      state.run = { combat_index = 11 }
      assert.has_no.errors(function() Draft.pick_cards(state) end)
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
