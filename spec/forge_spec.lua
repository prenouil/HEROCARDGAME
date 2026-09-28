-- Écran "La Forge" (game/src/rules/forge.lua) -- 2026-09-28, couverture ajoutée
-- avec le pilier du sacrifice : garde-fou anti-crash sur les cartes Mise à
-- mort/Legs/Héritage/Écho, qui n'ont pas de champ `upgrade` (voir
-- Cards.upgraded_def, qui plante avec assert() si on l'appelle sans).

local Forge = require("src.rules.forge")

local function make_state(pile)
  return { deck = pile or {}, hand = {}, discard = {} }
end

describe("Forge.upgradable_instances", function()
  it("exclut les instances déjà améliorées (comportement existant)", function()
    local state = make_state({ { uid = 1, def = { is_upgraded = true } }, { uid = 2, def = {} } })
    local out = Forge.upgradable_instances(state)
    assert.are.equal(1, #out)
    assert.are.equal(2, out[1].uid)
  end)

  it("exclut aussi les cartes def.no_forge_upgrade (2026-09-28, pilier du sacrifice -- Mise à mort/Legs/Héritage/Écho, sans champ 'upgrade')", function()
    local state = make_state({
      { uid = 1, def = { no_forge_upgrade = true } },
      { uid = 2, def = {} },
    })
    local out = Forge.upgradable_instances(state)
    assert.are.equal(1, #out)
    assert.are.equal(2, out[1].uid)
  end)

  it("les 30 cartes réelles du pilier du sacrifice (cards.lua) sont bien toutes marquées no_forge_upgrade", function()
    local Cards = require("src.data.cards")
    local prefixes = { "mise%-a%-mort%-", "legs%-", "heritage%-", "echo%-" }
    local checked = 0
    for _, def in ipairs(Cards.list) do
      for _, p in ipairs(prefixes) do
        if def.code:match("^" .. p) then
          checked = checked + 1
          assert.is_true(def.no_forge_upgrade, def.code .. " devrait porter no_forge_upgrade")
        end
      end
    end
    assert.are.equal(30, checked)
  end)
end)
