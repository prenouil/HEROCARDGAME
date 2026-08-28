-- Cards.upgraded_def (écran "La Forge", 2026-08-10) : vérifie le contrat
-- générique (nom suffixé, def/effect remplacés, uid jamais concerné puisque
-- c'est le module appelant qui le porte) + quelques valeurs ponctuelles
-- tirées du tableur de Zgrubulu, pour attraper une régression si les
-- montants d'un `upgrade` divergent un jour du texte affiché.

local Cards = require("src.data.cards")

describe("Cards.upgraded_def", function()
  it("suffixe le nom de ' +' et marque is_upgraded", function()
    local base = Cards.by_code("coup-direct-guerrier")
    local up = Cards.upgraded_def(base)
    assert.equal("Coup direct +", up.name)
    assert.is_true(up.is_upgraded)
  end)

  it("garde le même code, class_id, tier et cost que la carte de base", function()
    local base = Cards.by_code("en-traitre")
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

  it("Rempart améliore le soi/allié de façon SYMÉTRIQUE (4/4 -> 6/6, corrigé 2026-08-24)", function()
    local up = Cards.upgraded_def(Cards.by_code("rempart"))
    local state = { log = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0, class_id = "guerrier" }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, defense = 0, class_id = "guerrier" }
    up.effect({ state = state, hero = hero, target = ally, card_def = up })
    assert.equal(6, hero.defense)
    assert.equal(6, ally.defense)
  end)

  it("Main de feu (ex-Flamèche, code 'flameche') est un coup de feu magique 2/3 dégâts (2026-08-24)", function()
    local base = Cards.by_code("flameche")
    assert.equal("Main de feu", base.name)
    assert.equal("magique", base.dmg_type)
    local has_feu = false
    for _, cat in ipairs(base.cats) do if cat == "feu" then has_feu = true end end
    assert.is_true(has_feu)

    local state = { log = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "mage", mana = 2 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(18, target.hp) -- 20 - 2
    assert.equal(3, hero.mana) -- +1 mana

    local up = Cards.upgraded_def(base)
    local hero2 = { id = "h2", name = "h2", hp = 20, max_hp = 20, class_id = "mage", mana = 2 }
    local target2 = { id = "e2", name = "e2", hp = 20, max_hp = 20, defense = 0 }
    up.effect({ state = state, hero = hero2, target = target2, card_def = up })
    assert.equal(17, target2.hp) -- 20 - 3
  end)

  it("Assassinat non-Camouflé donne Discrétion/Puissance 2/2 en base, 3/3 amélioré (2026-08-24, plus de Camouflé direct)", function()
    local base = Cards.by_code("assassinat")
    local state = { log = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "assassin", camoufle = 0, discretion = 0, puissance = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(2, hero.discretion)
    assert.equal(2, hero.puissance)
    assert.equal(0, hero.camoufle) -- toujours pas Camouflé : Assassinat n'en donne plus directement

    local up = Cards.upgraded_def(base)
    local hero2 = { id = "h2", name = "h2", hp = 20, max_hp = 20, class_id = "assassin", camoufle = 0, discretion = 0, puissance = 0 }
    up.effect({ state = state, hero = hero2, target = target, card_def = up })
    assert.equal(3, hero2.discretion)
    assert.equal(3, hero2.puissance)
  end)

  it("Assassinat Camouflé inflige les dégâts et NE retire plus Camouflé (2026-08-28, \"et perd Camouflé\" disparu du texte -- Furtif)", function()
    local base = Cards.by_code("assassinat")
    local state = { log = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "assassin", camoufle = 1, discretion = 10, puissance = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(8, target.hp) -- 20 - 12
    assert.equal(1, hero.camoufle) -- ne le retire plus lui-même (contrairement à avant 2026-08-28)
  end)

  it("En traître : sans Camouflé, ne fait STRICTEMENT rien -- dégâts/saignement/Discrétion tous conditionnels (2026-08-28, corrigé)", function()
    local base = Cards.by_code("en-traitre")
    local state = { log = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "assassin", camoufle = 0, discretion = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0, saignements = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(20, target.hp) -- pas Camouflé : aucun dégât
    assert.equal(0, target.saignements)
    assert.equal(0, hero.discretion) -- pas Camouflé : pas de Discrétion non plus

    local hero2 = { id = "h2", name = "h2", hp = 20, max_hp = 20, class_id = "assassin", camoufle = 1, discretion = 0 }
    local target2 = { id = "e2", name = "e2", hp = 20, max_hp = 20, defense = 0, saignements = 0 }
    base.effect({ state = state, hero = hero2, target = target2, card_def = base })
    assert.equal(12, target2.hp) -- Camouflé : 20 - 8
    assert.equal(3, target2.saignements)
    assert.equal(4, hero2.discretion)
  end)

  it("cartes Assassin taguées 'furtif' dans cats (2026-08-28)", function()
    for _, code in ipairs({ "plan-attaque", "se-cacher", "repli-strategique", "en-traitre", "assassinat", "preparation" }) do
      local def = Cards.by_code(code)
      local has_furtif = false
      for _, cat in ipairs(def.cats) do if cat == "furtif" then has_furtif = true end end
      assert.is_true(has_furtif, code .. " devrait porter 'furtif' dans cats")
    end
  end)
end)
