-- Résolution de l'action ennemie télégraphiée (game/src/rules/game.lua,
-- Game.resolve_enemy_action) -- 2026-09-10, suite de la couverture Busted.
-- Concentré sur les branches signalées "bug corrigé" dans les commentaires du
-- code (Esquive qui doit bloquer TOUS les effets négatifs, pas seulement les
-- dégâts) et les cas spéciaux par template (Golem, Troll).

local Game = require("src.rules.game")

local function make_state(heroes, enemies)
  return { heroes = heroes or {}, enemies = enemies or {}, log = {} }
end

local function make_hero(hp, extra)
  local h = { hp = hp, max_hp = hp, id = "h1", name = "Héros" }
  if extra then for k, v in pairs(extra) do h[k] = v end end
  return h
end

local function make_enemy(hp, extra)
  local e = { hp = hp, max_hp = hp, id = "e1", name = "Ennemi", template_id = "generique" }
  if extra then for k, v in pairs(extra) do e[k] = v end end
  return e
end

describe("Game.resolve_enemy_action", function()
  it("ne fait rien : ennemi mort, ou sans action prévue", function()
    local state = make_state()
    local dead = make_enemy(0, { next_move = { kind = "dmg", amount = 5, name = "Coup" } })
    Game.resolve_enemy_action(state, dead)
    assert.are.equal(0, #state.log) -- aucun effet, aucun log

    local idle = make_enemy(10, { next_move = nil })
    Game.resolve_enemy_action(state, idle)
    assert.are.equal(0, #state.log)
  end)

  describe("kind = dmg", function()
    it("touche normalement, applique les bolt-ons bleed/burn", function()
      local hero = make_hero(20)
      local enemy = make_enemy(10, {
        target_hero_id = hero.id,
        next_move = { kind = "dmg", amount = 5, name = "Griffe", bleed = 2, burn = 1 },
      })
      Game.resolve_enemy_action(make_state({ hero }, { enemy }), enemy)
      assert.are.equal(15, hero.hp)
      assert.are.equal(2, hero.saignements)
      assert.are.equal(1, hero.brulure)
    end)

    it("Esquive bloque le coup ET ses bolt-ons bleed/burn (bug corrigé -- avant, seuls les dégâts étaient bloqués)", function()
      local hero = make_hero(20, { esquive = 1 })
      local enemy = make_enemy(10, {
        target_hero_id = hero.id,
        next_move = { kind = "dmg", amount = 5, name = "Griffe", bleed = 2, burn = 1 },
      })
      Game.resolve_enemy_action(make_state({ hero }, { enemy }), enemy)
      assert.are.equal(20, hero.hp) -- intact
      assert.is_nil(hero.saignements) -- bolt-on jamais appliqué
      assert.is_nil(hero.brulure)
      assert.are.equal(0, hero.esquive) -- consommée quand même
    end)

    it("'lands' (Charge en Piqué) retire Vol que le coup ait touché ou non", function()
      local hero = make_hero(20, { esquive = 1 })
      local enemy = make_enemy(10, {
        target_hero_id = hero.id, vol = 1,
        next_move = { kind = "dmg", amount = 5, name = "Charge", lands = true },
      })
      Game.resolve_enemy_action(make_state({ hero }, { enemy }), enemy)
      assert.are.equal(0, enemy.vol) -- retiré même si le coup a été esquivé
    end)
  end)

  it("kind = debuff : Esquive le bloque aussi (même bug corrigé que dmg), sinon pose le(s) statut(s)", function()
    local hero = make_hero(20)
    local enemy = make_enemy(10, {
      target_hero_id = hero.id,
      next_move = { kind = "debuff", name = "Malédiction", status_key = "vulnerabilite", amount = 3,
        status_key2 = "incapacite", amount2 = 2 },
    })
    Game.resolve_enemy_action(make_state({ hero }, { enemy }), enemy)
    assert.are.equal(3, hero.vulnerabilite)
    assert.are.equal(2, hero.incapacite)

    local dodging_hero = make_hero(20, { esquive = 1 })
    local enemy2 = make_enemy(10, {
      target_hero_id = dodging_hero.id,
      next_move = { kind = "debuff", name = "Malédiction", status_key = "vulnerabilite", amount = 3 },
    })
    Game.resolve_enemy_action(make_state({ dodging_hero }, { enemy2 }), enemy2)
    assert.is_nil(dodging_hero.vulnerabilite)
    assert.are.equal(0, dodging_hero.esquive)
  end)

  it("kind = dmg-all : touche tous les héros vivants, épargne les morts", function()
    local h1, h2, h3 = make_hero(20), make_hero(20), make_hero(0)
    local enemy = make_enemy(10, { next_move = { kind = "dmg-all", amount = 4, name = "Onde" } })
    Game.resolve_enemy_action(make_state({ h1, h2, h3 }, { enemy }), enemy)
    assert.are.equal(16, h1.hp)
    assert.are.equal(16, h2.hp)
    assert.are.equal(0, h3.hp) -- déjà mort, jamais retouché en négatif
  end)

  it("kind = heal-self : se régénère, plafonné à max_hp", function()
    local enemy = make_enemy(10, { max_hp = 10, next_move = { kind = "heal-self", amount = 15 } })
    Game.resolve_enemy_action(make_state({}, { enemy }), enemy)
    assert.are.equal(10, enemy.hp)
  end)

  it("Troll : heal-self échoue s'il a pris du feu ce tour", function()
    local enemy = make_enemy(4, {
      max_hp = 10, template_id = "troll", took_fire_damage_this_turn = true,
      next_move = { kind = "heal-self", amount = 5 },
    })
    Game.resolve_enemy_action(make_state({}, { enemy }), enemy)
    assert.are.equal(4, enemy.hp) -- la régénération échoue
  end)

  it("kind = heal-ally : soigne un allié vivant, ignore un allié déjà mort", function()
    local ally = make_enemy(5, { id = "ally", max_hp = 10 })
    local dead_ally = make_enemy(0, { id = "dead-ally", max_hp = 10 })
    local healer = make_enemy(10, { id = "healer" })
    healer.next_move = { kind = "heal-ally", amount = 4, heal_target_id = "ally" }
    Game.resolve_enemy_action(make_state({}, { ally, dead_ally, healer }), healer)
    assert.are.equal(9, ally.hp)

    healer.next_move = { kind = "heal-ally", amount = 4, heal_target_id = "dead-ally" }
    Game.resolve_enemy_action(make_state({}, { ally, dead_ally, healer }), healer)
    assert.are.equal(0, dead_ally.hp) -- pas ressuscité par un simple soin
  end)

  it("kind = revive : ressuscite à PV pleins uniquement les templates listés, déjà morts", function()
    local pousse1 = make_enemy(0, { id = "p1", template_id = "pousse", max_hp = 5 })
    local pousse2 = make_enemy(3, { id = "p2", template_id = "pousse", max_hp = 5 }) -- déjà vivante, pas concernée
    local other = make_enemy(0, { id = "o1", template_id = "gobelin", max_hp = 8 })
    local reviver = make_enemy(10, {
      id = "arbre",
      next_move = { kind = "revive", name = "Rappel", revive_template_ids = { "pousse" } },
    })
    Game.resolve_enemy_action(make_state({}, { pousse1, pousse2, other, reviver }), reviver)
    assert.are.equal(5, pousse1.hp) -- ressuscitée à PV pleins
    assert.are.equal(3, pousse2.hp) -- inchangée
    assert.are.equal(0, other.hp) -- template non listé, reste mort
  end)

  it("kind = buff-self : pose le statut sur soi, applique dmg_all_amount en bonus s'il est présent", function()
    local h1 = make_hero(20)
    local enemy = make_enemy(10, {
      next_move = { kind = "buff-self", status_key = "vol", amount = 1, dmg_all_amount = 3, log_text = "prend son envol" },
    })
    Game.resolve_enemy_action(make_state({ h1 }, { enemy }), enemy)
    assert.are.equal(1, enemy.vol)
    assert.are.equal(17, h1.hp)
  end)

  it("Golem : n'attaque QUE s'il a été touché ce tour, reste immobile sinon", function()
    local hero = make_hero(20)
    local passive = make_enemy(10, {
      template_id = "golem", target_hero_id = hero.id, took_damage_this_turn = false,
      next_move = { kind = "dmg", amount = 5, name = "Poing de Pierre" },
    })
    Game.resolve_enemy_action(make_state({ hero }, { passive }), passive)
    assert.are.equal(20, hero.hp) -- reste immobile

    local angered = make_enemy(10, {
      template_id = "golem", target_hero_id = hero.id, took_damage_this_turn = true,
      next_move = { kind = "dmg", amount = 5, name = "Poing de Pierre" },
    })
    Game.resolve_enemy_action(make_state({ hero }, { angered }), angered)
    assert.are.equal(15, hero.hp) -- attaque bien cette fois
  end)
end)
