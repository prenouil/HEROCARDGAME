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
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
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

    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
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
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
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
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "assassin", camoufle = 1, discretion = 10, puissance = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(8, target.hp) -- 20 - 12
    assert.equal(1, hero.camoufle) -- ne le retire plus lui-même (contrairement à avant 2026-08-28)
  end)

  it("En traître : sans Camouflé, ne fait STRICTEMENT rien -- dégâts/saignement/Discrétion tous conditionnels (2026-08-28, corrigé)", function()
    local base = Cards.by_code("en-traitre")
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
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

describe("Cartes Paladin (2026-08-28, refonte)", function()
  it("Provocateur donne le bouclier à la CIBLE mais la Provocation au LANCEUR", function()
    local base = Cards.by_code("provocateur")
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0, provocation = 0 }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, defense = 0, provocation = 0 }
    base.effect({ state = state, hero = hero, target = ally, card_def = base })
    assert.equal(4, ally.defense)
    assert.equal(0, ally.provocation) -- pas l'allié
    assert.equal(2, hero.provocation) -- le lanceur
    assert.equal(0, hero.defense) -- le lanceur ne reçoit pas de bouclier ici
  end)

  it("Infranchissable amélioré programme 2 boucliers distincts (voir Game.schedule_shield)", function()
    local up = Cards.upgraded_def(Cards.by_code("infranchissable"))
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0, provocation = 0, scheduled_shields = {} }
    up.effect({ state = state, hero = hero, target = hero, card_def = up })
    assert.equal(15, hero.defense) -- gain immédiat
    assert.equal(3, hero.provocation)
    assert.equal(2, #hero.scheduled_shields)
    assert.equal(1, hero.scheduled_shields[1].turns_left)
    assert.equal(2, hero.scheduled_shields[2].turns_left)
  end)

  it("Raillerie redirige l'ennemi ciblé vers le Paladin (renommée depuis 'Provocation', même effet)", function()
    local base = Cards.by_code("raillerie")
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0 }
    local enemy = { id = "e1", name = "e1", hp = 20, max_hp = 20, next_move = { kind = "dmg" }, target_hero_id = "autre" }
    base.effect({ state = state, hero = hero, target = enemy, card_def = base })
    assert.equal(8, hero.defense)
    assert.equal("h1", enemy.target_hero_id)
  end)

  it("Clairvoyance et Lumière divine sont taguées 'amnesie'", function()
    for _, code in ipairs({ "clairvoyance", "lumiere-divine" }) do
      local def = Cards.by_code(code)
      local has_amnesie = false
      for _, cat in ipairs(def.cats) do if cat == "amnesie" then has_amnesie = true end end
      assert.is_true(has_amnesie, code .. " devrait porter 'amnesie' dans cats")
    end
  end)
end)

describe("Cartes Guerrier (2026-08-28, refonte)", function()
  it("Coup direct coûte désormais 0", function()
    assert.equal(0, Cards.by_code("coup-direct-guerrier").cost)
  end)

  it("Coup appuyé inflige des dégâts ET applique Vulnérabilité (remplace Encaisser)", function()
    local base = Cards.by_code("coup-appuye")
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0, vulnerabilite = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(14, target.hp) -- 20 - 6
    assert.equal(2, target.vulnerabilite)
  end)

  it("Coup d'estoc : le bonus se déclenche sur Bouclier OU Vulnérabilité (2026-08-28, avant : Bouclier seul)", function()
    local base = Cards.by_code("coup-estoc")
    local state = { log = {}, enemies = {} } -- Combat.deal_damage lit state.enemies (marquage Golem/Troll), même à vide
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20 }
    local vulnerable_only = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0, vulnerabilite = 1 }
    base.effect({ state = state, hero = hero, target = vulnerable_only, card_def = base })
    assert.equal(12, vulnerable_only.hp) -- 20 - 8 (bonus déclenché par Vulnérabilité seule)
  end)

  it("Avalanche de coups rend son coût à 0 en JOUANT SEULEMENT CETTE INSTANCE (jamais le def partagé)", function()
    local base = Cards.by_code("avalanche-coups")
    local original_cost = base.cost
    local state = { log = {}, enemies = {}, hand = {}, discard = {}, exhausted = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    local ctx = { state = state, hero = hero, target = target, card_def = base }
    base.effect(ctx)
    assert.is_true(ctx.zero_cost)
    assert.equal(16, target.hp) -- 20 - 4

    local Game = require("src.rules.game")
    local card = { uid = 1, def = base }
    state.hand = { card }
    Game.finish_card(state, { uid = 1 }, ctx)
    assert.equal(0, state.discard[1].def.cost) -- cette instance précise est maintenant gratuite
    assert.equal(original_cost, base.cost) -- le def partagé (Cards.list) n'a JAMAIS bougé
    assert.equal("avalanche-coups", state.discard[1].def.code) -- Cards.by_code reste utilisable
  end)

  it("Avalanche de coups revient en main (pas en défausse) si l'attaque tue sa cible, ET reste à coût 0", function()
    local base = Cards.by_code("avalanche-coups")
    local Game = require("src.rules.game")
    local state = { log = {}, enemies = {}, hand = {}, discard = {}, exhausted = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20 }
    local target = { id = "e1", name = "e1", hp = 3, max_hp = 20, defense = 0 } -- meurt sous 4 dégâts
    local ctx = { state = state, hero = hero, target = target, card_def = base }
    base.effect(ctx)
    assert.is_true(ctx.return_to_hand)
    local card = { uid = 1, def = base }
    state.hand = { card }
    Game.finish_card(state, { uid = 1 }, ctx)
    assert.equal(1, #state.hand)
    assert.equal(0, #state.discard)
    assert.equal(0, state.hand[1].def.cost)
  end)

  it("Riposte inflige la moitié (base) / la totalité (amélioré) des dégâts télégraphiés, pas un montant fixe", function()
    local base = Cards.by_code("riposte")
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0 }
    local attacker = {
      id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0,
      next_move = { kind = "dmg", amount = 10 }, target_hero_id = "h1",
    }
    -- `state.enemies` doit contenir le VRAI attaquant (pas juste être non-nil) :
    -- Combat.enemy_targeting le cherche dedans par target_hero_id.
    local state = { log = {}, enemies = { attacker } }
    base.effect({ state = state, hero = hero, target = hero, card_def = base })
    assert.equal(15, attacker.hp) -- 20 - (10 * 0.5)
    assert.is_nil(attacker.next_move) -- l'attaque est bien annulée

    local up = Cards.upgraded_def(base)
    local attacker2 = {
      id = "e2", name = "e2", hp = 20, max_hp = 20, defense = 0,
      next_move = { kind = "dmg", amount = 10 }, target_hero_id = "h1",
    }
    local state2 = { log = {}, enemies = { attacker2 } }
    up.effect({ state = state2, hero = hero, target = hero, card_def = up })
    assert.equal(10, attacker2.hp) -- 20 - 10 (totalité)
  end)

  it("Riposte ne fait rien contre un débuff (pas de 'dégâts' à annuler) -- toujours 'cibleennemi', pas un type précis avant", function()
    local base = Cards.by_code("riposte")
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0 }
    local attacker = {
      id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0,
      next_move = { kind = "debuff", amount = 10 }, target_hero_id = "h1",
    }
    local state = { log = {}, enemies = { attacker } }
    base.effect({ state = state, hero = hero, target = hero, card_def = base })
    assert.equal(20, attacker.hp) -- rien ne se passe
    assert.is_not_nil(attacker.next_move) -- l'attaque n'est PAS annulée
  end)
end)

-- Nécromancien/Barde (2026-08-29, conçues avec agent_content, sélectionnables
-- à l'écran de choix d'équipe -- voir heroes.lua) : `corruption_spent` est
-- normalement calculé par Game.resolve_pending (voir game_spec.lua pour ce
-- calcul), donc renseigné à la main ici -- ces tests appellent def.effect
-- directement, comme tout le reste de ce fichier.
describe("Cartes Nécromancien (2026-08-29)", function()
  it("Rite mineur : inflige 6 necrose, se soigne de 2*X (ctx.corruption_spent)", function()
    local base = Cards.by_code("rite-mineur")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 10, max_hp = 20, class_id = "necromancien", corruption = 5 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base, corruption_spent = 3 })
    assert.equal(14, target.hp) -- 20 - 6
    assert.equal(16, hero.hp) -- 10 + 2*3
  end)

  it("Rite mineur à X=0 reste jouable : dégâts garantis, pas de soin (voulu, pas un oubli)", function()
    local base = Cards.by_code("rite-mineur")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 10, max_hp = 20, class_id = "necromancien", corruption = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base, corruption_spent = 0 })
    assert.equal(14, target.hp)
    assert.equal(10, hero.hp) -- aucun soin
  end)

  it("Sceau de faiblesse : auto-inflige 2 PV via Combat.deal_damage, gagne donc 2 Corruption automatiquement", function()
    local base = Cards.by_code("sceau-faiblesse")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 10, max_hp = 20, class_id = "necromancien", corruption = 0 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0, vulnerabilite = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(8, hero.hp) -- 10 - 2
    assert.equal(2, hero.corruption) -- gagnée par le hook générique de Combat.deal_damage, pas ajoutée par la carte
    assert.equal(3, target.vulnerabilite)
  end)

  it("Voile d'ossements (corrigée 2026-08-29) : 4 bouclier à l'allié, 1 (2 amélioré) par Corruption pour le Nécromancien -- ne DÉPENSE jamais la Corruption", function()
    local base = Cards.by_code("voile-ossements")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0, class_id = "necromancien", corruption = 5 }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = ally, card_def = base })
    assert.equal(4, ally.defense)
    assert.equal(5, hero.defense) -- 1 * 5 Corruption
    assert.equal(5, hero.corruption) -- pas dépensée

    local up = Cards.upgraded_def(base)
    local hero2 = { id = "h3", name = "h3", hp = 20, max_hp = 20, defense = 0, class_id = "necromancien", corruption = 5 }
    local ally2 = { id = "h4", name = "h4", hp = 20, max_hp = 20, defense = 0 }
    up.effect({ state = state, hero = hero2, target = ally2, card_def = up })
    assert.equal(6, ally2.defense)
    assert.equal(10, hero2.defense) -- 2 * 5 Corruption
  end)

  it("Pacte funeste : perd la moitié de ses PV (arrondi sup), inflige 2 necrose par PV perdu, gagne autant de Corruption (via le hook générique)", function()
    local base = Cards.by_code("pacte-funeste")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 7, max_hp = 20, class_id = "necromancien", corruption = 0 } -- ceil(7/2) = 4
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(3, hero.hp) -- 7 - 4
    assert.equal(4, hero.corruption) -- autant que de PV perdus
    assert.equal(12, target.hp) -- 20 - (4 * 2)
  end)

  it("Servant d'os : programme X dégâts brut sur 3 (4 amélioré) tours via Game.schedule_damage, rien à X=0", function()
    local base = Cards.by_code("servant-os")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "necromancien", scheduled_damages = {} }
    base.effect({ state = state, hero = hero, target = hero, card_def = base, corruption_spent = 3 })
    assert.equal(3, #hero.scheduled_damages)
    assert.equal(3, hero.scheduled_damages[1].amount)

    local hero0 = { id = "h2", name = "h2", hp = 20, max_hp = 20, class_id = "necromancien", scheduled_damages = {} }
    base.effect({ state = state, hero = hero0, target = hero0, card_def = base, corruption_spent = 0 })
    assert.equal(0, #hero0.scheduled_damages) -- aucun effet garanti à X=0, voulu

    local up = Cards.upgraded_def(base)
    local hero2 = { id = "h3", name = "h3", hp = 20, max_hp = 20, class_id = "necromancien", scheduled_damages = {} }
    up.effect({ state = state, hero = hero2, target = hero2, card_def = up, corruption_spent = 2 })
    assert.equal(4, #hero2.scheduled_damages)
  end)

  it("Communion des morts : se soigne de 2*X (3*X amélioré)", function()
    local base = Cards.by_code("communion-morts")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 5, max_hp = 30, class_id = "necromancien" }
    base.effect({ state = state, hero = hero, target = hero, card_def = base, corruption_spent = 4 })
    assert.equal(13, hero.hp) -- 5 + 2*4
  end)
end)

describe("Cartes Barde (2026-08-29)", function()
  it("Air belliqueux : lit passivement l'Inspiration cumulée de TOUS les alliés (jamais dépensée)", function()
    local base = Cards.by_code("air-belliqueux")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "barde", inspiration = 0 }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, inspiration = 3 }
    local target = { id = "e1", name = "e1", hp = 20, max_hp = 20, defense = 0 }
    state.heroes = { hero, ally } -- living_heroes(ctx) lit ctx.state.heroes
    base.effect({ state = state, hero = hero, target = target, card_def = base })
    assert.equal(20 - (5 + 2 * 3), target.hp) -- 5 base + 2*3 (Inspiration cumulée des alliés) = 11 dégâts
    assert.equal(3, ally.inspiration) -- jamais dépensée par une lecture passive
  end)

  it("Chœur de bataille : Inspiration 2 (3 amélioré) à TOUS les alliés vivants", function()
    local base = Cards.by_code("choeur-bataille")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "barde", inspiration = 0 }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, inspiration = 0 }
    local dead = { id = "h3", name = "h3", hp = 0, max_hp = 20, inspiration = 0 }
    state.heroes = { hero, ally, dead }
    base.effect({ state = state, hero = hero, target = hero, card_def = base })
    assert.equal(2, hero.inspiration)
    assert.equal(2, ally.inspiration)
    assert.equal(0, dead.inspiration) -- mort, exclu
  end)

  it("Bis : consomme l'Inspiration de la cible et pose Encore (2 déclenchements base, 3 amélioré) -- rien si pas d'Inspiration", function()
    local base = Cards.by_code("bis")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, class_id = "barde" }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, inspiration = 4 }
    base.effect({ state = state, hero = hero, target = ally, card_def = base })
    assert.equal(0, ally.inspiration)
    assert.equal(1, ally.encore_extra_plays) -- "jouée 2 fois" = 1 déclenchement EN PLUS

    local ally_no_insp = { id = "h3", name = "h3", hp = 20, max_hp = 20, inspiration = 0 }
    base.effect({ state = state, hero = hero, target = ally_no_insp, card_def = base })
    assert.is_nil(ally_no_insp.encore_extra_plays) -- pas d'Inspiration : ne fait rien

    local up = Cards.upgraded_def(base)
    local ally2 = { id = "h4", name = "h4", hp = 20, max_hp = 20, inspiration = 2 }
    up.effect({ state = state, hero = hero, target = ally2, card_def = up })
    assert.equal(2, ally2.encore_extra_plays) -- "jouée 3 fois" = 2 déclenchements EN PLUS
  end)

  it("Rappel triomphal : Inspiration 2 + 6 bouclier (3 + 9 amélioré) à tous les alliés", function()
    local base = Cards.by_code("rappel-triomphal")
    local state = { log = {}, enemies = {} }
    local hero = { id = "h1", name = "h1", hp = 20, max_hp = 20, defense = 0, class_id = "barde", inspiration = 0 }
    local ally = { id = "h2", name = "h2", hp = 20, max_hp = 20, defense = 0, inspiration = 0 }
    state.heroes = { hero, ally }
    base.effect({ state = state, hero = hero, target = hero, card_def = base })
    assert.equal(2, hero.inspiration)
    assert.equal(6, hero.defense)
    assert.equal(2, ally.inspiration)
    assert.equal(6, ally.defense)
  end)
end)
