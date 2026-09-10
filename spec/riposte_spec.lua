-- "Riposte" (Guerrier) -- retravaillée le 2026-09-02 pour toucher TOUS les
-- ennemis dont l'attaque télégraphiée vise le Guerrier (pas seulement le
-- premier trouvé) -- jamais couverte par un vrai test automatisé jusqu'ici
-- (signalé explicitement par Cloud Dragonborn en party mode). Reprend le
-- scénario déjà validé à la main plus tôt dans le projet.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Cards = require("src.data.cards")

describe("Riposte", function()
  local state, guerrier

  before_each(function()
    state = Game.new_state()
    Game.reset_run(state, 12345, { "guerrier", "assassin", "necromancien", "barde" }, nil)
    state.energy = 99
    guerrier = Combat.hero_by_id(state, "guerrier")
    -- Garantit au moins 3 ennemis pour un scénario déterministe, quel que
    -- soit ce que le tirage RNG a réellement généré pour ce seed.
    while #state.enemies < 3 do
      local proto = state.enemies[1]
      local clone = {}
      for k, v in pairs(proto) do clone[k] = v end
      clone.id = proto.id .. "-clone" .. #state.enemies
      state.enemies[#state.enemies + 1] = clone
    end
  end)

  local function play_riposte(code)
    local def = Cards.by_code(code)
    local uid = "test-riposte"
    state.hand[#state.hand + 1] = { uid = uid, def = def }
    assert.are.equal("assigned", Game.select_card(state, uid))
    Game.resolve_pending(state, "self", nil)
  end

  it("annule TOUTES les attaques qui visent le Guerrier et inflige la moitié des dégâts à CHACUNE (base)", function()
    local e1, e2, e3 = state.enemies[1], state.enemies[2], state.enemies[3]
    e1.next_move, e1.target_hero_id = { kind = "dmg", amount = 10, name = "Coup 1" }, guerrier.id
    e2.next_move, e2.target_hero_id = { kind = "dmg", amount = 6, name = "Coup 2" }, guerrier.id
    e3.next_move, e3.target_hero_id = { kind = "dmg", amount = 20, name = "Coup 3" }, state.heroes[2].id -- vise un autre héros
    local e1_hp, e2_hp, e3_hp = e1.hp, e2.hp, e3.hp

    play_riposte("riposte")

    assert.is_nil(e1.next_move)
    assert.is_nil(e1.target_hero_id)
    assert.is_nil(e2.next_move)
    assert.is_nil(e2.target_hero_id)
    assert.are.equal(e1_hp - 5, e1.hp) -- moitié de 10
    assert.are.equal(e2_hp - 3, e2.hp) -- moitié de 6

    -- L'ennemi qui ne visait pas le Guerrier reste totalement intact.
    assert.is_not_nil(e3.next_move)
    assert.are.equal(state.heroes[2].id, e3.target_hero_id)
    assert.are.equal(e3_hp, e3.hp)
  end)

  it("version améliorée : inflige la TOTALITÉ des dégâts à chaque ennemi visant le Guerrier", function()
    local e1, e2 = state.enemies[1], state.enemies[2]
    e1.next_move, e1.target_hero_id = { kind = "dmg", amount = 8, name = "Coup A" }, guerrier.id
    e2.next_move, e2.target_hero_id = { kind = "dmg", amount = 12, name = "Coup B" }, guerrier.id
    local e1_hp, e2_hp = e1.hp, e2.hp

    -- Cards.upgraded_def garde le même `code` (voir son commentaire dans
    -- cards.lua) -- on ne peut donc pas la sélectionner via Cards.by_code,
    -- on injecte directement l'instance améliorée dans la main.
    local upgraded = Cards.upgraded_def(Cards.by_code("riposte"))
    local uid = "test-riposte-upgraded"
    state.hand[#state.hand + 1] = { uid = uid, def = upgraded }
    assert.are.equal("assigned", Game.select_card(state, uid))
    Game.resolve_pending(state, "self", nil)

    assert.are.equal(e1_hp - 8, e1.hp) -- totalité, pas la moitié
    assert.are.equal(e2_hp - 12, e2.hp)
  end)

  it("ne fait rien si personne ne vise le Guerrier avec une attaque de dégâts", function()
    local e1 = state.enemies[1]
    e1.next_move, e1.target_hero_id = { kind = "debuff", amount = 3, name = "Malédiction" }, guerrier.id
    local e1_hp = e1.hp

    play_riposte("riposte")

    assert.is_not_nil(e1.next_move) -- une Malédiction n'est pas annulée par Riposte
    assert.are.equal(e1_hp, e1.hp)
  end)
end)
