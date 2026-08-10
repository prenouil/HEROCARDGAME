-- Cards.upgraded_def (écran "feuDeCamp", 2026-08-10) : vérifie le contrat
-- générique (nom suffixé, def/effect remplacés, uid jamais concerné puisque
-- c'est le module appelant qui le porte) + quelques valeurs ponctuelles
-- tirées du tableur de Zgrubulu, pour attraper une régression si les
-- montants d'un `upgrade` divergent un jour du texte affiché.

local Cards = require("src.data.cards")

describe("Cards.upgraded_def", function()
  it("suffixe le nom de ' +' et marque is_upgraded", function()
    local base = Cards.by_code("coup-direct")
    local up = Cards.upgraded_def(base)
    assert.equal("Coup direct +", up.name)
    assert.is_true(up.is_upgraded)
  end)

  it("garde le même code, class_id, tier et cost que la carte de base", function()
    local base = Cards.by_code("blessure-ouverte")
    local up = Cards.upgraded_def(base)
    assert.equal(base.code, up.code)
    assert.equal(base.class_id, up.class_id)
    assert.equal(base.tier, up.tier)
    assert.equal(base.cost, up.cost)
  end)

  it("échoue explicitement sur une carte sans champ upgrade", function()
    local fake = { code = "inexistante", name = "Inexistante" }
    assert.has_error(function() Cards.upgraded_def(fake) end)
  end)

  it("Rempart améliore le soi/allié de façon asymétrique (4->5 / 4->6, tableur de Zgrubulu)", function()
    local up = Cards.upgraded_def(Cards.by_code("rempart"))
    local state = { log = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0, class_id = "guerrier" }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, defense = 0, class_id = "guerrier" }
    up.effect({ state = state, hero = hero, target = ally, card_def = up })
    assert.equal(5, hero.defense)
    assert.equal(6, ally.defense)
  end)

  it("Assassinat non-Camouflé double bien Camouflé/Puissance à l'amélioration (1/1 -> 2/2)", function()
    local up = Cards.upgraded_def(Cards.by_code("assassinat"))
    local state = { log = {} }
    -- class_id "guerrier" (pas "assassin") : isole la valeur imprimée sur la
    -- carte améliorée du doublement de Transcendance Assassin (déjà couvert
    -- ailleurs), qui s'appliquerait par-dessus sinon.
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "guerrier", camoufle = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    up.effect({ state = state, hero = hero, target = target, card_def = up })
    assert.equal(2, hero.camoufle)
    assert.equal(2, hero.puissance)
  end)
end)
