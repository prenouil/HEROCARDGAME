local Quests = require("src.rules.quests")

describe("Quests.unlocked_class_set", function()
  it("contient les 4 classes débloquées de base sans unlocked_classes", function()
    local set = Quests.unlocked_class_set({})
    assert.is_true(set.guerrier)
    assert.is_true(set.paladin)
    assert.is_true(set.mage)
    assert.is_true(set.assassin)
    assert.is_falsy(set.necromancien)
    assert.is_falsy(set.barde)
  end)

  it("ajoute les classes débloquées par la save", function()
    local set = Quests.unlocked_class_set({ unlocked_classes = { barde = true } })
    assert.is_true(set.barde)
    assert.is_falsy(set.necromancien)
  end)
end)

describe("Quests.locked_cards_for_class", function()
  it("renvoie les cartes 'avance' du guerrier non débloquées de base", function()
    local codes = {}
    for _, def in ipairs(Quests.locked_cards_for_class("guerrier", {})) do codes[def.code] = true end
    assert.is_true(codes["avalanche-coups"])
    assert.is_true(codes["riposte"])
    assert.is_true(codes["frenesie"])
    assert.is_falsy(codes["coup-taille"]) -- débloquée de base
  end)

  it("exclut Legs/Héritage/Écho/Mise à mort, même verrouillées", function()
    for _, def in ipairs(Quests.locked_cards_for_class("guerrier", {})) do
      assert.is_falsy(def.code:match("^legs%-"))
      assert.is_falsy(def.code:match("^heritage%-"))
      assert.is_falsy(def.code:match("^echo%-"))
      assert.is_falsy(def.code:match("^mise%-a%-mort%-"))
    end
  end)

  it("exclut une carte déjà débloquée par la save", function()
    local save_data = { unlocked_cards = { ["avalanche-coups"] = true, ["riposte"] = true, ["frenesie"] = true } }
    assert.are.equal(0, #Quests.locked_cards_for_class("guerrier", save_data))
  end)
end)

describe("Quests.eligible_class_quest_classes", function()
  it("inclut une classe débloquée de base avec des cartes encore verrouillées", function()
    local eligible = {}
    for _, id in ipairs(Quests.eligible_class_quest_classes({})) do eligible[id] = true end
    assert.is_true(eligible.guerrier)
  end)

  it("exclut une classe non débloquée (barde/nécromancien)", function()
    local eligible = {}
    for _, id in ipairs(Quests.eligible_class_quest_classes({})) do eligible[id] = true end
    assert.is_falsy(eligible.barde)
    assert.is_falsy(eligible.necromancien)
  end)

  it("exclut une classe débloquée dont toutes les cartes 'avance' sont déjà débloquées", function()
    local save_data = { unlocked_cards = { ["avalanche-coups"] = true, ["riposte"] = true, ["frenesie"] = true } }
    local eligible = {}
    for _, id in ipairs(Quests.eligible_class_quest_classes(save_data)) do eligible[id] = true end
    assert.is_falsy(eligible.guerrier)
    assert.is_true(eligible.paladin) -- toujours des cartes verrouillées
  end)
end)

describe("Quests.reroll_class_quests", function()
  it("choisit 2 classes distinctes parmi les éligibles", function()
    local save_data = {}
    Quests.reroll_class_quests(save_data)
    assert.are.equal(2, #save_data.class_quest_ids)
    assert.are_not.equal(save_data.class_quest_ids[1], save_data.class_quest_ids[2])
  end)

  it("renvoie moins de 2 classes si l'éligible en a moins", function()
    -- Déverrouille tout sauf le Guerrier -- seul lui reste éligible.
    local save_data = { unlocked_cards = {} }
    for _, def in ipairs(require("src.data.cards").list) do
      if def.class_id ~= "guerrier" and def.tier == "avance"
        and not def.code:match("^legs%-") and not def.code:match("^heritage%-")
        and not def.code:match("^echo%-") and not def.code:match("^mise%-a%-mort%-") then
        save_data.unlocked_cards[def.code] = true
      end
    end
    Quests.reroll_class_quests(save_data)
    assert.are.equal(1, #save_data.class_quest_ids)
    assert.are.equal("guerrier", save_data.class_quest_ids[1])
  end)

  it("renvoie 0 classe si tout le contenu débloquable est débloqué", function()
    local save_data = { unlocked_cards = {} }
    for _, def in ipairs(require("src.data.cards").list) do
      if def.tier == "avance" and not def.code:match("^legs%-") and not def.code:match("^heritage%-")
        and not def.code:match("^echo%-") and not def.code:match("^mise%-a%-mort%-") then
        save_data.unlocked_cards[def.code] = true
      end
    end
    Quests.reroll_class_quests(save_data)
    assert.are.equal(0, #save_data.class_quest_ids)
  end)
end)

describe("Quests.eligible_companion_classes / ensure_companion_quest", function()
  it("liste les classes non débloquées", function()
    local eligible = {}
    for _, id in ipairs(Quests.eligible_companion_classes({})) do eligible[id] = true end
    assert.is_true(eligible.necromancien)
    assert.is_true(eligible.barde)
    assert.is_falsy(eligible.guerrier)
  end)

  it("assigne une cible quand il n'y en a pas", function()
    local save_data = {}
    Quests.ensure_companion_quest(save_data)
    assert.is_true(save_data.companion_quest_class_id == "necromancien" or save_data.companion_quest_class_id == "barde")
  end)

  it("ne change jamais une cible déjà assignée", function()
    local save_data = { companion_quest_class_id = "barde" }
    Quests.ensure_companion_quest(save_data)
    assert.are.equal("barde", save_data.companion_quest_class_id)
  end)

  it("n'assigne rien si tous les aventuriers sont débloqués", function()
    local save_data = { unlocked_classes = { necromancien = true, barde = true } }
    Quests.ensure_companion_quest(save_data)
    assert.is_nil(save_data.companion_quest_class_id)
  end)
end)

describe("Quests.class_quest_difficulty", function()
  it("débute à 3 sans carte débloquée pour cette classe", function()
    assert.are.equal(3, Quests.class_quest_difficulty("guerrier", {}))
  end)

  it("augmente de 1 par carte débloquée POUR CETTE CLASSE SEULEMENT", function()
    -- "avalanche-coups" (Guerrier) compte, "bouclier-vivant" (Paladin) non.
    local save_data = { unlocked_cards = { ["bouclier-vivant"] = true, ["avalanche-coups"] = true } }
    assert.are.equal(4, Quests.class_quest_difficulty("guerrier", save_data))
  end)

  it("2 classes progressent indépendamment", function()
    local save_data = { unlocked_cards = { ["avalanche-coups"] = true, ["riposte"] = true } }
    assert.are.equal(5, Quests.class_quest_difficulty("guerrier", save_data)) -- 2 cartes guerrier débloquées
    assert.are.equal(3, Quests.class_quest_difficulty("paladin", save_data)) -- aucune carte paladin débloquée
  end)
end)

describe("Quests.companion_quest_difficulty", function()
  it("débute à 5 sans compagnon débloqué", function()
    assert.are.equal(5, Quests.companion_quest_difficulty({}))
  end)

  it("augmente de 3 par compagnon débloqué", function()
    local save_data = { unlocked_classes = { necromancien = true } }
    assert.are.equal(8, Quests.companion_quest_difficulty(save_data))
  end)

  it("augmente de 3 par compagnon, pas de base (Heroes.DEFAULT_UNLOCKED_CLASS_IDS ignoré)", function()
    local save_data = { unlocked_classes = { necromancien = true, barde = true } }
    assert.are.equal(11, Quests.companion_quest_difficulty(save_data))
  end)
end)
