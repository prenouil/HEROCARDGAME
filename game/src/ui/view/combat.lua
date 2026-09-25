-- Scène de combat principale (2026-09-25, extrait de l'ex-monolithe view.lua --
-- voir src/ui/view/init.lua pour le contexte du découpage) : géométrie de la
-- rangée d'ennemis/de héros/de la main, rendu des unités (héros/ennemis),
-- pioche/défausse, main, boutons du bas, vols de carte, flottants/particules,
-- flèches de ciblage -- exposé comme View.draw_combat(controller), appelé
-- depuis view/init.lua pour l'écran "playing"/"defeat"/"victory".
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Fonts = require("src.ui.fonts")
local Icons = require("src.ui.icons")
local Sprites = require("src.ui.sprites")
local Glossary = require("src.data.glossary")
local SCALE = require("src.ui.layout_scale")
local Combat = require("src.rules.combat")
local Temple = require("src.rules.temple")
local Game = require("src.rules.game")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  -- +12 (2026-08-27, demande explicite -- portraits plus gros partout, voir
  -- HERO_PORTRAIT_SIZE plus bas) : la carte grandit un peu pour absorber le
  -- portrait agrandi sans tasser le reste (badges, nom en bas côté héros).
  -- HÉROS UNIQUEMENT depuis 2026-09-22 (demande explicite -- "les aventuriers
  -- doivent être plus gros, presque le double") : +46 de haut pour absorber
  -- HERO_PORTRAIT_SIZE 54->100 -- voir draw_hero pour le détail des éléments
  -- repoussés d'autant sous le portrait. View.enemy_rects code désormais ses
  -- propres 150x168 en dur, pour ne plus dépendre de cette valeur.
  local UNIT_W, UNIT_H = 150, 214

  function View.enemy_rects(state)
    -- 150, 168 en dur (2026-09-22) : UNIT_W/UNIT_H ci-dessus a grandi pour les
    -- héros seulement (portraits agrandis) -- l'ennemi garde sa taille de
    -- panneau d'origine, jamais concerné par cette demande.
    local rects = UI.centered_row(#state.enemies, 150, 168, 54)
    local out = {}
    for i, e in ipairs(state.enemies) do out[e.id] = rects[i] end
    return out
  end

  -- 250->270 (2026-08-31, passage 1280x720) -> 270->284 (2026-09-02, HUD "PO")
  -- -> 284->258 (2026-09-22, portraits de héros agrandis) : voir HERO_UNIT_H.
  local HERO_ROW_Y = 258

  function View.hero_rects(state)
    local rects = UI.centered_row(#state.heroes, UNIT_W, UNIT_H, HERO_ROW_Y)
    local out = {}
    for i, h in ipairs(state.heroes) do out[h.id] = rects[i] end
    return out
  end

  -- Point d'ancrage unique héros-ou-ennemi (2026-08-09) : utilisé par les VFX
  -- qui n'ont besoin que "où est cette unité à l'écran" (nombre flottant, burst
  -- d'impact), sans savoir de quel côté elle est.
  function View.unit_rect(state, unit_id)
    return View.hero_rects(state)[unit_id] or View.enemy_rects(state)[unit_id]
  end

  -- Éventail façon Slay the Spire (2026-08-21) : x reste la grille régulière de
  -- centered_row, `y` descend selon l'écart au centre de la main, et un
  -- `fan_angle` s'ajoute pour la rotation visuelle -- baked dans le rect
  -- lui-même : le hit-test (Input.mousemoved) et le vol de cartes suivent donc
  -- l'éventail sans code séparé.
  local HAND_FAN_ANGLE_STEP = 0.05 -- radians par carte d'écart au centre (~3°)
  local HAND_FAN_DROP = 7 -- px de descente par carte d'écart au centre
  -- Léger chevauchement (2026-08-27) : gap négatif passé à centered_row.
  local HAND_OVERLAP_GAP = -UI.CARD_W * 0.22

  -- 419->450->480 (2026-08-31)->505 (2026-09-12, la main affiche CARD_H=184).
  local HAND_Y = 505

  local function hand_row_fan(count, y)
    local rects = UI.centered_row(count, UI.CARD_W, UI.CARD_H, y, HAND_OVERLAP_GAP)
    local mid = (count + 1) / 2
    for i, r in ipairs(rects) do
      local d = i - mid
      r.y = r.y + math.abs(d) * HAND_FAN_DROP
      r.fan_angle = d * HAND_FAN_ANGLE_STEP
    end
    return rects
  end

  -- Calcule les rects de la main à partir d'une LISTE de cartes explicite
  -- plutôt que de `state.hand` directement -- permet de rejouer la mise en
  -- page d'une main passée (avant une défausse, par ex.) même après que
  -- `state.hand` a déjà changé, pour les animations de vol de carte.
  function View.hand_rects_for(cards)
    local rects = hand_row_fan(#cards, HAND_Y)
    local out = {}
    for i, c in ipairs(cards) do out[c.uid] = rects[i] end
    return out
  end

  function View.hand_rects(state)
    return View.hand_rects_for(state.hand)
  end

  --- Hit-test dédié à la main (2026-08-27, nécessaire depuis le chevauchement
  -- ci-dessus) : contrairement à `find_rect` (input.lua), teste dans l'ordre
  -- INVERSE d'affichage -- la dernière carte de state.hand est dessinée en
  -- dernier, par-dessus ses voisines.
  -- `hiding_uids` (optionnel, 2026-08-30) : même ensemble que draw_hand (voir
  -- View.hand_hiding_uids, seule source de vérité pour "cette carte est-elle
  -- vraiment là pour de vrai").
  function View.hand_hit(state, x, y, hiding_uids)
    local rects = View.hand_rects(state)
    for i = #state.hand, 1, -1 do
      local c = state.hand[i]
      if not (hiding_uids and hiding_uids[c.uid]) and UI.point_in(rects[c.uid], x, y) then return c.uid end
    end
    return nil
  end

  --- Uids de state.hand encore "cachés" (vol pioche -> main pas terminé) --
  -- calculé UNE FOIS ici, utilisé à la fois par draw_hand (rendu) et
  -- View.hand_hit (hit-test, via Input.lua).
  function View.hand_hiding_uids(controller)
    local hiding_uids = {}
    for _, a in ipairs(controller.card_anims) do
      if a.fade_in and a.uid then hiding_uids[a.uid] = true end
    end
    for uid in pairs(controller.pending_draw_uids) do hiding_uids[uid] = true end
    return hiding_uids
  end

  -- Réduites de 50% (2026-08-27) : la pioche/défausse n'ont plus besoin d'être
  -- au gabarit d'une carte pour se lire comme une pile.
  local PILE_W, PILE_H = UI.CARD_W * 0.5, UI.CARD_H * 0.5
  View.deck_pile_rect = { x = 20, y = HAND_Y, w = PILE_W, h = PILE_H }
  View.discard_pile_rect = { x = UI.W - 20 - PILE_W, y = HAND_Y, w = PILE_W, h = PILE_H }

  -- "Voir le deck" (2026-08-30) : juste sous la pioche.
  View.deck_view_button = {
    x = View.deck_pile_rect.x, y = View.deck_pile_rect.y + View.deck_pile_rect.h + 5,
    w = PILE_W, h = 24, label = "Deck",
  }

  -- Énergie globale (2026-08-11) : cadre 90x90 à droite de la pioche.
  local ENERGY_GAP = 8
  View.energy_display_rect = {
    x = View.deck_pile_rect.x + View.deck_pile_rect.w + ENERGY_GAP, y = View.deck_pile_rect.y,
    w = 90, h = 90,
  }

  -- "PO" (or, 2026-09-02) : ligne compacte, coincée entre le label "Ta troupe"
  -- (HERO_ROW_Y-28) et la rangée de héros (HERO_ROW_Y).
  View.gold_display_rect = { x = 20, y = HERO_ROW_Y - 14, w = 120, h = 14 }

  -- Découplées de la MAIN (2026-09-12) : ancrées chacune sur SA pile.
  local RESTART_BTN_W, RESTART_BTN_H, RESTART_BTN_GAP = 96, 20, 4
  View.restart_turn_button = {
    x = View.deck_pile_rect.x, y = View.deck_view_button.y + View.deck_view_button.h + 6,
    w = RESTART_BTN_W, h = RESTART_BTN_H, label = "Recommencer ce tour",
  }
  View.restart_button = {
    x = View.deck_pile_rect.x, y = View.restart_turn_button.y + RESTART_BTN_H + RESTART_BTN_GAP, w = RESTART_BTN_W, h = RESTART_BTN_H,
    label = "Recommencer le combat",
  }
  -- Outil de test discret (2026-08-08) : termine le combat en cours par une
  -- victoire immédiate, sans passer par la résolution réelle des ennemis.
  View.instant_victory_button = {
    x = View.deck_pile_rect.x, y = View.restart_button.y + RESTART_BTN_H + RESTART_BTN_GAP, w = RESTART_BTN_W, h = RESTART_BTN_H,
    label = "victoire instantanée",
  }

  -- Carré (2026-09-12) : W=H=88, centré sur la défausse, déborde symétriquement.
  local END_TURN_BTN_W, END_TURN_BTN_H = 88, 88
  View.end_turn_button = {
    x = View.discard_pile_rect.x + View.discard_pile_rect.w / 2 - END_TURN_BTN_W / 2,
    y = View.discard_pile_rect.y + View.discard_pile_rect.h + 8,
    w = END_TURN_BTN_W, h = END_TURN_BTN_H, label = "Fin de tour",
  }

  -- ---------- unités (héros/ennemis) ----------

  local function unit_anim_transform(controller, id)
    local a = controller.anim[id]
    if not a then return 0, 0, 1 end
    -- `a.t < 0` (2026-09-02, séquencement dégâts-après-bouclier) : pas encore
    -- "son tour", même garde que draw_shield_fx/status_badge.
    if a.t < 0 then return 0, 0, 1 end
    if a.kind == "pulse-up" then
      local t = a.t / 0.38
      return 0, -10 * (1 - (1 - t) ^ 2), 1 + 0.05 * (1 - t)
    elseif a.kind == "pulse-down" then
      local t = a.t / 0.38
      return 0, 10 * (1 - (1 - t) ^ 2), 1 + 0.05 * (1 - t)
    elseif a.kind == "shake" then
      local t = a.t
      return math.sin(t * 60) * 6 * math.max(0, 1 - t), 0, 1
    end
    return 0, 0, 1
  end

  --- Gros bouclier en fondu (2026-08-09) sur un gain de Défense : 1s, fondu
  -- entrant/sortant, `r` = rect LOCAL de la carte (déjà dans l'espace
  -- translaté de draw_hero/draw_enemy). Réutilise Icons.draw_status("defense",
  -- ...) (2026-08-27, même icône que le badge persistant).
  local function draw_shield_fx(controller, unit_id, r)
    local s = controller.shield_fx[unit_id]
    if not s then return end
    -- `s.t < 0` (2026-08-30, décalage multi-cibles) : pas encore "son tour".
    if s.t < 0 then return end
    local dur = controller.shield_fx_duration
    local t = s.t
    local alpha
    if t < dur * 0.2 then
      alpha = t / (dur * 0.2)
    elseif t > dur * 0.7 then
      alpha = 1 - (t - dur * 0.7) / (dur * 0.3)
    else
      alpha = 1
    end
    -- Gain vs absorption, 2 visuels distincts (2026-09-02) : `s.amount`
    -- pilote laquelle des deux offsets s'applique.
    local offset_x, offset_y = 0, 0
    if s.amount then
      -- Tremblement (impact) : amorti sur TOUTE la durée du fondu.
      offset_x = math.sin(t * 50) * 4 * math.max(0, 1 - t / dur)
    else
      -- Montée légère (gain) : remonte à sa place au fil du fondu entrant.
      local rise_p = math.min(1, t / (dur * 0.35))
      offset_y = -(1 - rise_p) * 10
    end
    Icons.draw_status("defense", r.w / 2 + offset_x, r.h / 2 + offset_y, r.w * 0.4, Theme.def, alpha * 0.9)
    -- Montant absorbé (2026-08-24) : affiché seulement quand ce fondu vient
    -- d'intercepter un coup (Controller:react_to_diff pose `s.amount`).
    if s.amount then
      UI.set(Theme.text, alpha)
      love.graphics.setFont(Fonts.get(14))
      love.graphics.printf("-" .. tostring(s.amount), offset_x, r.h / 2 - 8, r.w, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Indicateur de Défense PERSISTANT (2026-08-27) : reste affiché tant que
  -- unit.defense > 0, à part de la rangée de statuts partagée.
  -- `cy` (optionnel, 2026-08-27, 3ᵉ retour explicite) : par défaut ancré près
  -- du bas du cadre, mais draw_enemy passe une position plus haute pour ne pas
  -- recouvrir l'annonce d'attaque télégraphiée.
  local DEFENSE_BADGE_R = 24
  local function draw_defense_badge_big(unit, r, cy)
    local val = unit.defense or 0
    if val <= 0 then return end
    local cx = r.w / 2
    cy = cy or (r.h - DEFENSE_BADGE_R - 4)
    local drawn = Icons.draw_status("defense", cx, cy, DEFENSE_BADGE_R, Theme.def)
    if drawn then
      UI.set(Theme.text)
      love.graphics.setFont(Fonts.get(14))
      love.graphics.printf(tostring(val), cx - DEFENSE_BADGE_R, cy - 7, DEFENSE_BADGE_R * 2, "center")
    else
      UI.text("DEF " .. val, 0, cy - 7, r.w, 14, Theme.def, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function draw_hero(controller, h, r)
    local dead = h.hp <= 0
    local hero_palette = Theme.card_class[h.class_id] or Theme.card_class.generic

    -- "S'éteint" doucement à la mort (2026-08-30) : `fade_p` (0 = encore
    -- pleinement "vivant" à l'écran, 1 = état "mort" final atteint) remplace un
    -- simple bascule instantanée sur les alphas/couleurs ci-dessous.
    local fade = controller.hero_death_fade[h.id]
    local fade_p = fade and math.min(1, fade.t / fade.duration) or 0

    local pending = controller.state.pending
    local eligible_target = pending and pending.hero_id and (pending.def.target == "ally" or pending.def.target == "enemy-or-ally") and not dead and h.id ~= pending.hero_id
    -- Chaque carte a un propriétaire fixe (def.class_id) : la sélectionner
    -- l'assigne DIRECTEMENT à ce héros -- `awaiting_own_target` couvre la
    -- fenêtre entre la sélection et la résolution réelle.
    local awaiting_own_target = pending and pending.hero_id == h.id
    -- Un héros peut agir plusieurs fois par tour (2026-08-20) : cadre vert
    -- tant qu'il est vivant, indicateur permanent, jamais de voile gris de fin
    -- de tour.
    local ready = not dead

    -- Cadre bleu = cible possible pour la carte en attente (allié) ; doré =
    -- propriétaire de la carte sélectionnée, en attente de sa résolution ;
    -- priorité sur la couleur de classe.
    local border, border_w = Theme.panel_light, 1
    if eligible_target then
      border, border_w = Theme.energy, 3
    elseif awaiting_own_target then
      border, border_w = Theme.accent, 3
    elseif ready or fade_p < 1 then
      -- Glisse vers le contour terne au lieu d'y basculer d'un coup (2026-08-30).
      border, border_w = UI.lerp_color(hero_palette.border, Theme.panel_light, fade_p), 3 - 2 * fade_p
    end

    local arrow_mode = controller.input_mode == "arrow"
    local dx, dy, scale = unit_anim_transform(controller, h.id)
    -- Petit rebond continu au survol d'une cible alliée valide -- calculé sur
    -- le rect ABSOLU, avant toute translation d'animation.
    local hovering_as_ally_target = false
    if arrow_mode and eligible_target then
      local mx, my = love.mouse.getPosition()
      mx, my = mx / SCALE, my / SCALE
      hovering_as_ally_target = UI.point_in(r, mx, my)
    end
    if hovering_as_ally_target then
      scale = scale * (1 + 0.035 * math.sin(love.timer.getTime() * 8))
    end
    -- "Anticipation" (2026-08-20) : le propriétaire d'une carte sélectionnée
    -- grossit et pulse EN BOUCLE tant que sa carte attend une cible.
    if awaiting_own_target then
      scale = scale * (1.12 + 0.045 * math.sin(love.timer.getTime() * 5))
    end

    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-r.w / 2, -r.h / 2)

    UI.set(Theme.panel, 1 - 0.5 * fade_p)
    love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
    -- Fond de plus en plus rouge sombre sous 50% de PV (2026-08-27),
    -- proportionnel aux PV perdus au-delà de ce seuil.
    local hp_pct = math.max(0, h.hp) / h.max_hp
    if hp_pct < 0.5 then
      local wound_t = math.min(1, (0.5 - hp_pct) / 0.5)
      UI.set(Theme.hp, wound_t * 0.6 * (1 - fade_p))
      love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
    end
    UI.set(border); love.graphics.setLineWidth(border_w)
    love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)

    -- Portrait agrandi (2026-08-27). Nom déplacé EN BAS du cadre (2026-08-27) :
    -- l'ordre devient portrait -> barre de PV -> mana/discrétion -> statuts ->
    -- nom. `alpha` (dernier argument, 2026-08-30) : le portrait est un vrai
    -- sprite pour tous les héros, qui gère SON PROPRE alpha.
    UI.set(Theme.text, 1 - 0.55 * fade_p)
    -- 54->100 (2026-09-22) : voir HERO_ROW_Y plus haut pour comment le panneau
    -- a été agrandi/repositionné pour absorber ce +46 sans repousser HAND_Y.
    local HERO_PORTRAIT_SIZE = 100
    UI.draw_class_icon(h.class_id, h.icon, h.label, 0, 4, r.w, HERO_PORTRAIT_SIZE, Theme.text, 1 - 0.55 * fade_p)
    -- Badges de bénédiction/malédiction du Temple (2026-08-28/29) : coin
    -- haut-droit pour la bénédiction, haut-gauche pour la malédiction -- les
    -- 2 seules zones encore libres du cadre. Un aventurier peut porter les
    -- DEUX à la fois.
    if not dead and h.blessing then
      local blessing = Temple.by_id(h.blessing)
      if blessing then
        local color = UI.TEMPLE_STATUE_COLORS[blessing.color] or Theme.heal
        UI.set(color); love.graphics.circle("fill", r.w - 14, 14, 11)
        UI.set(Theme.black); love.graphics.setLineWidth(2)
        love.graphics.circle("line", r.w - 14, 14, 11)
        love.graphics.setLineWidth(1)
        Icons.draw_status("temple_blessing", r.w - 14, 14, 8, Theme.bg)
      end
    end
    if not dead and h.curse then
      local curse = Temple.by_id(h.curse)
      if curse then
        local color = UI.TEMPLE_STATUE_COLORS[curse.color] or Theme.hp
        UI.set(color); love.graphics.circle("fill", 14, 14, 11)
        UI.set(Theme.black); love.graphics.setLineWidth(2)
        love.graphics.circle("line", 14, 14, 11)
        love.graphics.setLineWidth(1)
        Icons.draw_status("temple_curse", 14, 14, 8, Theme.bg)
      end
    end
    local name_y = r.h - 24
    draw_defense_badge_big(h, r, name_y - 24)
    -- Barre de PV épaissie, valeur DEDANS plutôt qu'en dessous (2026-08-27).
    UI.hp_bar(8, 108, r.w - 16, 16, h.hp / h.max_hp, (controller.hp_trail[h.id] or h.hp) / h.max_hp, Theme.hp)
    UI.text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", 0, 108, r.w, 16, 10, Theme.text)

    -- Mana (2026-08-20, ressource propre au Mage) : dans son propre cadre,
    -- juste sous sa jauge de PV -- seul le Mage a ce champ non-nil.
    if h.mana ~= nil then
      local mana_icon = Sprites.keyword("mana")
      if mana_icon then
        love.graphics.setColor(1, 1, 1, 1)
        Sprites.draw_centered(mana_icon, r.w / 2 - 8, 131, 7)
        UI.text(tostring(h.mana), r.w / 2 + 2, 126, r.w / 2 - 2, 11, Theme.mana, "left")
      else
        UI.text("MANA " .. tostring(h.mana), 0, 127, r.w, 9, Theme.mana)
      end
    end
    -- Discrétion (2026-08-24, ressource propre à l'Assassin) : même traitement
    -- que MANA ci-dessus. "CAMOUFLÉ" en toutes lettres (2026-08-30) remplace le
    -- compteur une fois au plafond.
    if h.discretion ~= nil then
      if (h.camoufle or 0) > 0 then
        UI.text("CAMOUFLÉ", 0, 127, r.w, 9, Theme.discretion)
      else
        UI.text("DISCRÉTION " .. tostring(h.discretion), 0, 127, r.w, 9, Theme.discretion)
      end
    end
    -- Corruption (2026-08-29, ressource propre au Nécromancien) : même
    -- traitement que MANA/DISCR ci-dessus.
    if h.corruption ~= nil then
      UI.text("CORR " .. tostring(h.corruption), 0, 127, r.w, 9, Theme.corruption)
    end

    -- Plus de bouton "Jouer" (2026-08-20) : sélectionner une carte assigne
    -- directement son propriétaire, l'encart n'a donc plus qu'un seul contenu
    -- possible ici. Défense retirée de cette rangée (2026-08-27, voir
    -- draw_defense_badge_big appelé plus haut).
    local badges = {}
    if (h.esquive or 0) > 0 then badges[#badges + 1] = { key = "esquive", abbr = "ESQ", value = h.esquive } end
    -- Pas de valeur affichée (2026-08-24) : Camouflé est un ÉTAT, plus un
    -- statut à empiler -- "CAM" seul, jamais "CAM N".
    if (h.camoufle or 0) > 0 then badges[#badges + 1] = { key = "camoufle", abbr = "CAM" } end
    if (h.puissance or 0) > 0 then badges[#badges + 1] = { key = "puissance", abbr = "PUI", value = h.puissance } end
    -- Incandescence (2026-09-02, statut Volcan) : même traitement que
    -- Puissance ci-dessus, abréviation distincte (PUI est déjà pris).
    if (h.incandescence or 0) > 0 then badges[#badges + 1] = { key = "incandescence", abbr = "INCA", value = h.incandescence } end
    if (h.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = h.saignements } end
    if (h.brulure or 0) > 0 then badges[#badges + 1] = { key = "brulure", abbr = "BRU", value = h.brulure } end
    -- Incapacité/Vulnérabilité (bug signalé, 2026-08-24) : un héros PEUT porter
    -- ces deux statuts, le multiplicateur de dégâts en tenait déjà compte,
    -- seul le badge manquait.
    if (h.incapacite or 0) > 0 then badges[#badges + 1] = { key = "incapacite", abbr = "INC", value = h.incapacite } end
    if (h.vulnerabilite or 0) > 0 then badges[#badges + 1] = { key = "vulnerabilite", abbr = "VUL", value = h.vulnerabilite } end
    -- Provocation (2026-08-28, statut du Paladin) : uniquement côté héros.
    if (h.provocation or 0) > 0 then badges[#badges + 1] = { key = "provocation", abbr = "PROV", value = h.provocation } end
    -- Inspiration/Encore (2026-08-29, statuts GÉNÉRIQUES du Barde) : N'IMPORTE
    -- QUEL héros peut les porter, jamais conditionnés à class_id == "barde".
    if (h.inspiration or 0) > 0 then badges[#badges + 1] = { key = "inspiration", abbr = "INSP", value = h.inspiration } end
    if (h.encore_extra_plays or 0) > 0 then badges[#badges + 1] = { key = "encore", abbr = "ENC", value = h.encore_extra_plays } end
    -- Bouclier programmé (2026-08-28, Infranchissable) : pas un vrai statut
    -- numérique -- valeur affichée = somme des montants encore en attente,
    -- recalculée à chaque frame directement depuis les données.
    if h.scheduled_shields and #h.scheduled_shields > 0 then
      local pending_total = 0
      for _, entry in ipairs(h.scheduled_shields) do pending_total = pending_total + entry.amount end
      badges[#badges + 1] = { key = "shield_pending", abbr = "PROG", value = pending_total }
    end
    UI.draw_badge_row(badges, 0, 139, r.w, 16, Theme.status, controller.status_pop[h.id], controller.status_pop_duration)

    -- Nom en bas du cadre (2026-08-27) : voir name_y calculé plus haut, juste
    -- après le portrait -- réutilisé aussi par draw_defense_badge_big.
    UI.name_badge(h.name, 0, name_y, r.w, 16, hero_palette.border, Theme.bg, 4, 2)

    draw_shield_fx(controller, h.id, r)
    UI.draw_tooltip_hint(r.w, r.h)

    -- Voile de Camouflage (2026-08-30) : PAR-DESSUS tout ce qui vient d'être
    -- dessiné -- c'est tout le cadre qui doit se lire "cet aventurier est caché".
    if not dead and (h.camoufle or 0) > 0 then
      UI.set(Theme.black, 0.5)
      love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
  end

  -- Présentation en 3 lignes distinctes (2026-08-24) : `title` seul (le nom du
  -- coup), `body` (montant/effet), `target` (nom de la cible, SANS le mot
  -- "vise" -- la flèche visuelle de draw_enemy_target_arrows suffit déjà).
  -- `target_class` (2026-08-24) : class_id de la cible, pour colorer la
  -- bande/flèche à sa couleur de classe. `body`/`target`/`target_class`
  -- peuvent être nil -- à l'appelant (draw_enemy) de ne dessiner que ce qui
  -- existe. Icône de dégâts + mot "dégâts" retiré (2026-08-27) : `icon_source`/
  -- `icon_key` indiquent à draw_telegraph_body quelle icône préfixer --
  -- "keyword" pour un mot-clé du glossaire, "status" pour une icône de statut.
  -- Bonus/malus génériques, sans valeur chiffrée (2026-08-27) : `body` est
  -- alors absent -- un débuff pose toujours icon_key = "malus" (jamais le
  -- statut précis, le détail reste dans l'infobulle) ; un soin à soi/un allié
  -- ou une résurrection posent icon_key = "bonus".
  local DMG_TYPE_ICON = { melee = "epee", ranged = "arc", magic = "etincelle" }
  local function enemy_telegraph_parts(state, e)
    if e.hp <= 0 then return { title = "Vaincu." } end
    local move = e.next_move
    if not move then return nil end
    -- Montant réellement ajusté : la propre Incapacité de l'ennemi ET la
    -- Vulnérabilité de sa cible -- même calcul que la résolution réelle
    -- (Combat.deal_damage, via resolve_enemy_attack), jamais une deuxième
    -- formule dupliquée ici.
    local target = e.target_hero_id and Combat.hero_by_id(state, e.target_hero_id)
    local target_name = target and target.name or nil
    local target_class = target and target.class_id or nil
    -- Incandescence (2026-09-02, additive, voir Combat.incandescence_flat --
    -- même règle qu'Inspiration côté héros : appliquée AVANT le multiplicateur).
    local function adjusted(amount)
      return Combat.round((amount + Combat.incandescence_flat(e, "physique")) * Combat.damage_multiplier(e, target, "physique"))
    end
    if move.kind == "dmg" then
      return {
        title = move.name, body = tostring(adjusted(move.amount)),
        icon_source = "keyword", icon_key = DMG_TYPE_ICON[move.dmg_type] or "epee",
        target = target_name, target_class = target_class,
      }
    elseif move.kind == "debuff" then
      -- Malus générique, jamais de valeur chiffrée (2026-08-27) : icône
      -- "malus" neutre quel que soit le statut réellement appliqué.
      return { title = move.name, icon_source = "status", icon_key = "malus", target = target_name, target_class = target_class }
    elseif move.kind == "heal-self" or move.kind == "heal-ally" or move.kind == "revive" then
      -- Bonus générique, jamais de valeur chiffrée (2026-08-27) : soin à soi,
      -- soin à un allié et résurrection sont les 3 façons dont un ennemi
      -- s'avantage lui-même ou un autre ennemi.
      return { title = move.name, icon_source = "status", icon_key = "bonus" }
    elseif move.kind == "buff-self" then
      -- "Envol" de l'Aigle Géant (2026-08-30) : icône du statut posé lui-même
      -- plutôt que le "bonus" générique. `body` (2026-08-30) : montre les
      -- dégâts secondaires quand `move.dmg_all_amount` existe -- ajustés côté
      -- attaquant seulement, jamais une Vulnérabilité par héros.
      local body = move.dmg_all_amount and (Combat.round((move.dmg_all_amount + Combat.incandescence_flat(e, "physique")) * Combat.damage_multiplier(e, nil, "physique")) .. " à tous") or nil
      return { title = move.name, body = body, icon_source = "status", icon_key = move.status_key or "bonus" }
    elseif move.kind == "conditional-retaliate" then
      -- Affiche la cible ET le fait que le Golem VA riposter une fois qu'il a
      -- déjà encaissé un coup ce tour (`e.took_damage_this_turn`).
      local icon_source, icon_key = "keyword", DMG_TYPE_ICON[move.dmg_type] or "epee"
      if e.took_damage_this_turn then
        return {
          title = "Riposte (touché)", body = tostring(adjusted(move.amount)), icon_source = icon_source, icon_key = icon_key,
          target = target_name, target_class = target_class,
        }
      end
      return {
        title = move.name, body = adjusted(move.amount) .. " si touché", icon_source = icon_source, icon_key = icon_key,
        target = target_name, target_class = target_class,
      }
    elseif move.kind == "dmg-all" then
      -- Homme Arbre, "Onde Sylvestre" (2026-08-21) : l'ajustement ne tient
      -- compte que des modificateurs côté attaquant, jamais de la
      -- Vulnérabilité d'un héros précis (chacun peut différer).
      return {
        title = move.name, body = Combat.round((move.amount + Combat.incandescence_flat(e, "physique")) * Combat.damage_multiplier(e, nil, "physique")) .. " à tous",
        icon_source = "keyword", icon_key = DMG_TYPE_ICON[move.dmg_type] or "etincelle",
      }
    end
    return nil
  end

  --- Dessine `parts.body` précédé de son icône, centré comme une seule unité
  -- dans la largeur `w` -- "keyword" pour un mot-clé du glossaire, "status"
  -- pour un statut. Simple texte centré si aucune icône n'est renseignée.
  -- `parts.body` peut être absent (2026-08-27, bonus/malus génériques) :
  -- l'icône seule est alors centrée, sans aucune valeur chiffrée à côté.
  -- Icône/texte agrandis (2026-08-27, 2ᵉ demande explicite) : icône 14->22px,
  -- police 9->14.
  local function draw_telegraph_body(parts, y, w)
    if not parts.icon_key and not parts.body then return end
    if not parts.icon_key then
      UI.text(parts.body, 0, y, w, 14, Theme.accent)
      return
    end
    local icon_size = 22
    local icon_cy = y + icon_size / 2
    if not parts.body then
      local cx = w / 2
      if parts.icon_source == "status" then
        Icons.draw_status(parts.icon_key, cx, icon_cy, icon_size / 2, Theme.accent)
      else
        local icon = Sprites.keyword(parts.icon_key)
        if icon then
          love.graphics.setColor(1, 1, 1, 1)
          Sprites.draw_centered(icon, cx, icon_cy, icon_size / 2)
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    local font = Fonts.get(14)
    local text_w = font:getWidth(parts.body)
    local gap = 4
    local start_x = (w - (icon_size + gap + text_w)) / 2
    if parts.icon_source == "status" then
      Icons.draw_status(parts.icon_key, start_x + icon_size / 2, icon_cy, icon_size / 2, Theme.accent)
    else
      local icon = Sprites.keyword(parts.icon_key)
      if icon then
        love.graphics.setColor(1, 1, 1, 1)
        Sprites.draw_centered(icon, start_x + icon_size / 2, icon_cy, icon_size / 2)
      end
    end
    UI.set(Theme.accent)
    love.graphics.setFont(font)
    love.graphics.print(parts.body, start_x + icon_size + gap, y)
    love.graphics.setColor(1, 1, 1, 1)
  end

  --- Lignes de fissure qui gagnent en netteté à l'approche de l'explosion
  -- (2026-08-30) : motif FIXE par segment (dérivé de l'index seul, jamais de
  -- math.random appelé à chaque frame) -- seuls l'opacité ET le nombre de
  -- segments déjà "apparus" suivent `crack_p` (0 -> 1).
  local ENEMY_CRACK_LINES = 5
  local function draw_enemy_crack(r, crack_p)
    if crack_p <= 0 then return end
    UI.set(Theme.hp, math.min(1, crack_p * 1.3))
    love.graphics.setLineWidth(2)
    local cx, cy = r.w / 2, r.h / 2
    for i = 1, ENEMY_CRACK_LINES do
      if crack_p * ENEMY_CRACK_LINES >= i - 1 then
        local seed = i * 37.13
        local angle = (i / ENEMY_CRACK_LINES) * math.pi * 2 + math.sin(seed) * 0.6
        local len = r.w * 0.4 + (i % 3) * 6
        local mx = cx + math.cos(angle) * len * 0.5 + math.sin(seed * 2) * 6
        local my = cy + math.sin(angle) * len * 0.5 + math.cos(seed * 2) * 6
        local ex = cx + math.cos(angle) * len
        local ey = cy + math.sin(angle) * len
        love.graphics.line(cx, cy, mx, my, ex, ey)
      end
    end
    love.graphics.setLineWidth(1)
  end

  local function draw_enemy(controller, e, r)
    local dead = e.hp <= 0
    -- Séquence de mort (2026-08-30) : une fois `death.exploded` vrai, plus
    -- RIEN n'est dessiné pour cet ennemi -- même la trame/le cadre -- les
    -- particules déjà semées continuent seules de s'éteindre.
    local death = controller.enemy_death[e.id]
    if death and death.exploded then return end
    -- Traînée de PV (2026-08-30) : tant qu'elle n'a pas fini de rattraper 0,
    -- l'ennemi reste affiché "en vie" même si `e.hp` est déjà <= 0 -- seul
    -- `trail_dead` déclenche l'apparence "vaincu" ci-dessous.
    local trail = controller.hp_trail[e.id] or e.hp
    local trail_dead = dead and trail <= 0

    local pending = controller.state.pending
    local hero = pending and pending.hero_id and Combat.hero_by_id(controller.state, pending.hero_id)
    local awaiting_enemy_target = pending and pending.hero_id and not dead
      and (pending.def.target == "enemy" or pending.def.target == "enemy-or-ally"
        or (pending.def.target == "conditional" and hero and not Combat.enemy_targeting(controller.state, hero)))

    -- Même rebond que côté héros (mode "flèche") quand cet ennemi précis est
    -- une cible valide ET survolé par la souris -- calculé sur le rect ABSOLU,
    -- avant toute translation d'animation.
    local dx, dy, scale = unit_anim_transform(controller, e.id)
    if controller.input_mode == "arrow" and awaiting_enemy_target then
      local mx, my = love.mouse.getPosition()
      mx, my = mx / SCALE, my / SCALE
      if UI.point_in(r, mx, my) then
        scale = scale * (1 + 0.035 * math.sin(love.timer.getTime() * 8))
      end
    end
    -- Élite (2026-09-01) : ~18% plus grand qu'un ennemi normal, un pur
    -- agrandissement de RENDU (jamais r.w/r.h eux-mêmes, qui restent la grille
    -- uniforme de centered_row/le hit-test réel d'Input.lua).
    if e.elite then scale = scale * 1.18 end

    -- Fissure (2026-08-30) : secousse de plus en plus forte à l'approche de
    -- l'explosion. `crack_p` réutilisé plus bas par draw_enemy_crack.
    local crack_p = 0
    if death and not death.exploded then
      crack_p = math.min(1, death.t / (death.crack_duration or 0.45))
      dx = dx + math.sin(death.t * 60) * 3 * crack_p
      dy = dy + math.cos(death.t * 47) * 2 * crack_p
    end

    love.graphics.push()
    love.graphics.translate(r.x + r.w / 2 + dx, r.y + r.h / 2 + dy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-r.w / 2, -r.h / 2)

    -- Cadre bleu = cible possible pour la carte en attente de résolution
    -- (2026-08-08). Fond quasi imperceptible (2026-08-30) : un très léger
    -- voile suffit déjà, le contour et les éléments dessinés par-dessus
    -- délimitent la zone. Élite : PLUS de cadre doré/halo scintillant
    -- (2026-09-02, revirement explicite) : cadre strictement identique à un
    -- ennemi normal -- le signal se déplace sur la barre de PV (voir hp_color).
    UI.set(Theme.panel, trail_dead and 0.06 or 0.12)
    love.graphics.rectangle("fill", 0, 0, r.w, r.h, 10, 10)
    if awaiting_enemy_target then
      UI.set(Theme.energy)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", 0, 0, r.w, r.h, 10, 10)
    end

    -- Barre de PV au-dessus du portrait (2026-08-27) : bar 4->20, épaissie
    -- (10->16) avec la valeur DEDANS. `trail_dead`, pas `dead` (2026-08-30) :
    -- la barre reste affichée tant que la traînée n'a pas fini de rattraper 0.
    UI.set(Theme.text, trail_dead and 0.45 or 1)
    if not trail_dead then
      -- Élite : la barre de PV elle-même est dorée et scintillante (2026-09-02,
      -- remplace l'ancien cadre doré retiré plus haut).
      local hp_color = Theme.hp
      if e.elite then
        local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
        hp_color = {
          Theme.accent[1] + (1 - Theme.accent[1]) * pulse * 0.5,
          Theme.accent[2] + (1 - Theme.accent[2]) * pulse * 0.5,
          Theme.accent[3] + (1 - Theme.accent[3]) * pulse * 0.5,
        }
      end
      UI.hp_bar(8, 4, r.w - 16, 16, e.hp / e.max_hp, trail / e.max_hp, hp_color)
      UI.text_v_centered(math.max(0, e.hp) .. "/" .. e.max_hp .. " PV", 0, 4, r.w, 16, 10, Theme.text)
    end
    -- Portrait agrandi (2026-08-27, 46->54 ; 2026-08-30, 54->62, remonté de 24
    -- à 20 pour garder exactement le même bas). Image au sol/en vol (2026-08-30,
    -- Aigle Géant) : clé dérivée de `e.vol` plutôt que `e.template_id` seul.
    -- Sans effet sur tout autre ennemi (e.vol vaut 0 pour eux tous).
    local enemy_icon_key = (e.vol or 0) > 0 and (e.template_id .. "-vol") or e.template_id
    UI.draw_enemy_icon(enemy_icon_key, e.icon, e.label, 0, 20, r.w, 62, Theme.text)
    -- Position du corps du télégraphe calculée en premier : le badge de
    -- bouclier (2026-08-27, 3ᵉ retour explicite) s'ancre dessus, pas
    -- l'inverse. `- 24` ≈ le rayon visuel du bouclier plus une petite marge.
    -- `- 38` (était -30) : le corps du télégraphe est plus gros maintenant.
    local telegraph_y = r.h - 38
    draw_defense_badge_big(e, r, telegraph_y - 24)
    local parts = enemy_telegraph_parts(controller.state, e)
    if not trail_dead then
      local badges = {}
      -- Sensibilité au feu (2026-08-24) : pas un statut temporaire -- toujours
      -- en tête de rangée tant que l'Homme Arbre est vivant. Défense retirée
      -- de cette rangée (2026-08-27, voir draw_defense_badge_big plus haut).
      if e.template_id == "homme-arbre" then badges[#badges + 1] = { key = "fireweak", abbr = "FEU" } end
      if (e.vol or 0) > 0 then badges[#badges + 1] = { key = "vol", abbr = "VOL" } end
      -- Puissance/Incandescence (2026-09-02, bug signalé -- absentes de cette
      -- rangée jusqu'ici) : même traitement que côté héros (draw_hero ci-dessus).
      if (e.puissance or 0) > 0 then badges[#badges + 1] = { key = "puissance", abbr = "PUI", value = e.puissance } end
      if (e.incandescence or 0) > 0 then badges[#badges + 1] = { key = "incandescence", abbr = "INCA", value = e.incandescence } end
      if (e.saignements or 0) > 0 then badges[#badges + 1] = { key = "saignements", abbr = "SAI", value = e.saignements } end
      if (e.brulure or 0) > 0 then badges[#badges + 1] = { key = "brulure", abbr = "BRU", value = e.brulure } end
      if (e.incapacite or 0) > 0 then badges[#badges + 1] = { key = "incapacite", abbr = "INC", value = e.incapacite } end
      if (e.vulnerabilite or 0) > 0 then badges[#badges + 1] = { key = "vulnerabilite", abbr = "VUL", value = e.vulnerabilite } end
      UI.draw_badge_row(badges, 0, 82, r.w, 16, Theme.status, controller.status_pop[e.id], controller.status_pop_duration)
      -- Coup télégraphié (2026-08-27) : plus de titre ici, seulement le corps
      -- (icône de type de dégâts + montant) -- poussé le plus bas possible.
      if parts then draw_telegraph_body(parts, telegraph_y, r.w) end
    elseif parts then
      -- Ennemi vaincu : occupe l'espace libéré par la barre de PV absente.
      UI.text(parts.title, 0, 4, r.w, 14, Theme.accent)
    end

    -- Étiquette de cible retirée (2026-08-30) : voir draw_enemy_target_arrows,
    -- seul indicateur de cible restant.

    draw_enemy_crack(r, crack_p)
    draw_shield_fx(controller, e.id, r)
    UI.draw_tooltip_hint(r.w, r.h)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
  end

  -- ---------- main ----------

  -- Aperçu dynamique des dégâts (2026-08-09 ; réduit au retrait de la
  -- Transcendance le 2026-08-11 -- ne reflète plus que Puissance/Incapacité/
  -- Vulnérabilité, jamais une classe de héros) : au survol d'un héros pendant
  -- qu'une carte est sélectionnée, ses dégâts affichent ce qu'ils VONT valoir
  -- si CE héros la joue sur CETTE cible. Dérivé des mêmes règles que
  -- Combat.deal_damage, jamais une deuxième copie de la logique de jeu.
  local function scale_near_keyword(text, keyword, factor)
    local out = text
    -- nombre AVANT le mot-clé, ex. `4 "epee"` (Coup direct)
    out = out:gsub('(%d+)(%s+"' .. keyword .. '")', function(num, rest)
      return tostring(Combat.round(tonumber(num) * factor)) .. rest
    end)
    -- nombre APRÈS le mot-clé, ex. `"soin" 2` (Lumière divine)
    out = out:gsub('("' .. keyword .. '"%s+)(%d+)', function(pre, num)
      return pre .. tostring(Combat.round(tonumber(num) * factor))
    end)
    return out
  end

  -- Mots-clés qui portent un montant de DÉGÂTS (par opposition à "bouclier"/
  -- "soin", qui n'entrent jamais dans Combat.damage_multiplier). "necrose"
  -- (2026-08-29, Nécromancien) : se comporte exactement comme "etincelle"
  -- pour ce calcul (Vulnérabilité s'applique, Puissance non).
  local DAMAGE_KEYWORDS = { epee = true, etincelle = true, fireball = true, necrose = true }

  --- Même principe que scale_near_keyword ci-dessus, mais ADDITIF plutôt que
  -- multiplicatif (2026-08-29, Inspiration -- "+6 flat", pas un pourcentage) :
  -- voir consume_inspiration dans combat.lua, seule source de vérité sur le
  -- montant réel -- cette fonction ne fait que prévisualiser le MÊME calcul.
  local function add_near_keyword(text, keyword, amount)
    local out = text
    out = out:gsub('(%d+)(%s+"' .. keyword .. '")', function(num, rest)
      return tostring(tonumber(num) + amount) .. rest
    end)
    out = out:gsub('("' .. keyword .. '"%s+)(%d+)', function(pre, num)
      return pre .. tostring(tonumber(num) + amount)
    end)
    return out
  end

  -- Mots-clés qui portent un montant de dégâts/soin/bouclier (2026-08-29,
  -- Inspiration -- "+6 flat au PREMIER effet de dégâts/soin/bouclier
  -- déclenché") : ordre FIXE (pas `pairs`) -- une carte qui porte PLUSIEURS de
  -- ces mots-clés n'applique le bonus qu'à UN SEUL, toujours le même.
  local INSPIRATION_KEYWORDS_ORDERED = { "epee", "etincelle", "fireball", "necrose", "soin", "bouclier" }

  --- `is_fire` : même détection que Combat.deal_damage (def.cats contient
  -- "feu"), nécessaire pour que l'aperçu montre déjà le bonus de l'Homme
  -- Arbre (2026-08-24) sans attendre la résolution réelle.
  local function card_is_fire(def)
    if not def.cats then return false end
    for _, cat in ipairs(def.cats) do
      if cat == "feu" then return true end
    end
    return false
  end

  --- Aperçu du texte d'une carte si `hero` la joue (et, une fois la cible
  -- choisie/survolée, `target`). `target` peut être nil (héros pas encore
  -- assigné à une cible) -- la Vulnérabilité n'entre alors pas encore en compte.
  local function preview_desc(def, hero, target)
    local text = def.desc
    -- Additif (Inspiration) AVANT multiplicatif (Puissance/Incapacité/
    -- Vulnérabilité) -- 2026-08-30, même ordre que Combat.deal_damage :
    -- l'aperçu doit rester IDENTIQUE à la résolution réelle.
    if hero and (hero.inspiration or 0) > 0 then
      for _, kw in ipairs(INSPIRATION_KEYWORDS_ORDERED) do
        if Glossary.has_keyword(def.desc, kw) then text = add_near_keyword(text, kw, 6) break end
      end
    end
    local dmg_mult = Combat.damage_multiplier(hero, target, def.dmg_type, card_is_fire(def))
    if dmg_mult ~= 1 then
      for kw in pairs(DAMAGE_KEYWORDS) do
        if Glossary.has_keyword(def.desc, kw) then text = scale_near_keyword(text, kw, dmg_mult) end
      end
    end
    return text
  end

  local function draw_energy_display(state)
    local r = View.energy_display_rect
    UI.panel(r.x, r.y, r.w, r.h, Theme.panel_light)
    UI.set(Theme.energy); love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    local icon = Sprites.keyword("energie")
    if icon then
      love.graphics.setColor(1, 1, 1, 1)
      -- Icône agrandie (2026-08-30) : 18->24 de rayon, recentrée un peu plus
      -- bas pour garder une marge avant le texte "X / Y" juste en dessous.
      Sprites.draw_centered(icon, r.x + r.w / 2, r.y + 26, 24)
    end
    UI.text(state.energy .. " / " .. Game.TURN_START_ENERGY, r.x, r.y + 52, r.w, 24, Theme.energy)
  end

  -- "PO" (or, 2026-09-02) : même esprit que draw_energy_display (icône +
  -- texte coloré) mais réduit à une ligne compacte de 14px. Cible d'arrivée
  -- des pièces animées de l'écran de victoire (draw_coin_flights, victory.lua).
  local function draw_gold_display(state)
    local r = View.gold_display_rect
    local icon = Sprites.keyword("or")
    if icon then
      love.graphics.setColor(1, 1, 1, 1)
      Sprites.draw_centered(icon, r.x + 7, r.y + 7, 7)
    end
    UI.text(tostring(state.gold), r.x + 18, r.y, r.w - 18, r.h, Theme.gold, "left")
  end

  -- Gros chiffre d'énergie qui CHUTE sur sa pastille en début de tour
  -- (2026-08-21) : apparaît en très grand, tout en haut de la zone de jeu,
  -- puis descend et rétrécit jusqu'à se stabiliser exactement sur sa pastille
  -- -- une seule courbe (ease_out_back) pilote À LA FOIS l'échelle ET la
  -- position verticale.
  local ENERGY_TURN_ANIM_START_SCALE = 8.0
  local ENERGY_TURN_ANIM_FALL_HEIGHT = 260 -- px au-dessus de la pastille, départ de la chute
  local function draw_energy_turn_anim(controller)
    local a = controller.energy_turn_anim
    if not a then return end
    local r = View.energy_display_rect
    local duration = controller.energy_turn_anim_duration
    local settle = UI.ease_out_back(a.t, duration) -- 0 -> dépasse ~1 -> 1
    local scale = 1 + (ENERGY_TURN_ANIM_START_SCALE - 1) * (1 - settle)
    local cx = r.x + r.w / 2
    local landing_y = r.y + 52 + 12 -- même position que le texte statique de draw_energy_display ci-dessus
    local cy = landing_y - ENERGY_TURN_ANIM_FALL_HEIGHT * (1 - settle)

    local glow_p = math.min(1, a.t / duration)
    UI.set(Theme.energy, 0.35 * (1 - glow_p))
    love.graphics.circle("fill", cx, landing_y, 14 + 46 * glow_p)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)
    UI.text(a.value .. " / " .. Game.TURN_START_ENERGY, r.x, cy - 10, r.w, 24, Theme.energy)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
  end

  --- Pioche/défausse -- effet d'épaisseur quand `count` > 1 : 1 à 2 rectangles
  -- décalés en bas-à-droite AVANT le panneau principal, pour suggérer une
  -- vraie pile plutôt qu'une case plate. Purement cosmétique : la zone
  -- cliquable/hit-test reste `rect` seul, jamais agrandie par les couches
  -- décalées. Nombre de cartes en texte "LABEL : X" plutôt qu'en pastille
  -- colorée (2026-08-27, la pastille bleue pleine se lisait à tort comme un
  -- coût plutôt qu'un compte de cartes).
  local function draw_pile(rect, icon, label, count)
    local layers = math.min(2, math.max(0, count - 1))
    for i = layers, 1, -1 do
      UI.panel(rect.x + i * 2, rect.y + i * 2, rect.w, rect.h, Theme.panel)
    end
    UI.panel(rect.x, rect.y, rect.w, rect.h, Theme.panel_light)
    UI.icon_text(icon, "", rect.x, rect.y + 4, rect.w, 16, Theme.muted)
    -- Nom puis nombre sur 2 lignes, sans ":" (2026-08-27) : le nombre est le
    -- repère le plus lu, mis en évidence par sa propre ligne.
    UI.text(label, rect.x, rect.y + 24, rect.w, 8, Theme.muted)
    UI.text(tostring(count), rect.x, rect.y + 34, rect.w, 13, Theme.text)
    -- Infobulle pioche/défausse (2026-08-21) : le rect reste non-cliquable,
    -- mais devient survolable pour l'infobulle.
    love.graphics.push()
    love.graphics.translate(rect.x, rect.y)
    UI.draw_tooltip_hint(rect.w, rect.h)
    love.graphics.pop()
  end

  -- Grossissement survol/sélection de la main -- valeurs partagées entre
  -- draw_one (ci-dessous, carte encore en main) et draw_card_flights
  -- (2026-09-12 -- doit reprendre EXACTEMENT le même grossissement pour
  -- redescendre progressivement depuis là).
  View._hand_pop = { hover_scale = 1.35, hover_lift = 18, selected_scale = 1.55, selected_lift = 28 }

  local function draw_hand(controller)
    local state = controller.state
    local rects = View.hand_rects(state)
    draw_energy_display(state)
    draw_energy_turn_anim(controller)
    draw_pile(View.deck_pile_rect, "\u{1F0A0}", "PIOCHE", #state.deck)
    draw_pile(View.discard_pile_rect, "\u{1F5D1}\u{FE0F}", "DEFAUSSE", #state.discard)
    -- "Voir le deck" (2026-08-30) : seulement en combat (screen == "playing") --
    -- pendant un évènement "camp", ce coin de l'écran est de toute façon
    -- recouvert par le voile sombre de l'écran en question.
    if controller.screen == "playing" then
      local db = View.deck_view_button
      UI.panel(db.x, db.y, db.w, db.h, Theme.panel_light)
      UI.set(Theme.muted); love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", db.x, db.y, db.w, db.h, 6, 6)
      UI.text(db.label, db.x, db.y + db.h / 2 - 5, db.w, 11, Theme.text, "center")
    end

    -- Mode "flèche" (2026-08-09) : la carte sélectionnée reste posée en avant
    -- tant qu'elle est en attente, et la carte survolée grossit -- 2026-09-12,
    -- ANIMÉ (position + taille). Dessinée en deux passes pour que toute carte
    -- EN COURS DE TRANSITION reste au-dessus de ses voisines.

    -- Le fantôme de vol pioche->main est un fondu qui part de rien ; le vrai
    -- rendu de la carte reste donc masqué tant que SON vol d'arrivée n'est pas
    -- terminé. Cartes déjà dans state.hand mais dont le vol pioche -> main n'a
    -- pas encore démarré (2026-08-21) : sans ça, elles s'affichaient "déjà là"
    -- avant de disparaître puis revoler depuis la pioche. Calcul partagé avec
    -- View.hand_hit (2026-08-30, voir View.hand_hiding_uids).
    local hiding_uids = View.hand_hiding_uids(controller)

    local function draw_one(c)
      local r = rects[c.uid]
      local def = c.def
      local is_pending = state.pending and state.pending.uid == c.uid
      local pop = controller.hand_pop_amount[c.uid] or 0
      -- Aperçu de dégâts (voir preview_desc ci-dessus) : seulement sur LA
      -- carte sélectionnée. Deux étapes : héros pas encore assigné -> on
      -- prévisualise celui survolé ; héros déjà assigné et en attente d'une
      -- cible -> le héros est fixé, survoler l'ennemi visé complète l'aperçu.
      local previewing_hero, previewing_target = nil, nil
      if is_pending and state.pending then
        if state.pending.hero_id then
          previewing_hero = Combat.hero_by_id(state, state.pending.hero_id)
          if controller.hover.kind == "enemy" then previewing_target = Combat.enemy_by_id(state, controller.hover.target) end
        elseif controller.hover.kind == "hero" then
          previewing_hero = Combat.hero_by_id(state, controller.hover.target)
        end
      end
      local owner = Combat.hero_by_id(state, def.class_id)
      local desc_text, has_bonus = def.desc, false
      if previewing_hero then
        desc_text = preview_desc(def, previewing_hero, previewing_target)
        has_bonus = desc_text ~= def.desc
      end
      -- Coût variable en Corruption (2026-08-29, Nécromancien) : contrairement
      -- au bonus d'Inspiration ci-dessus, celui-ci s'applique à TOUTE carte en
      -- main -- substitution du littéral "X" par min(corruption actuelle,
      -- plafond), recalculée CHAQUE frame. `owner` peut être nil -- (owner or
      -- {}) retombe alors sur 0, jamais une erreur.
      if def.corruption_cost_cap then
        local x = math.min((owner or {}).corruption or 0, def.corruption_cost_cap)
        desc_text = desc_text:gsub("X", tostring(x))
      end
      -- Coût EFFECTIF (2026-08-29, malédiction "Le Corrompu") : jamais
      -- def.cost brut dès qu'un propriétaire est en jeu -- voir
      -- Combat.effective_cost, seule source de vérité.
      local cost_text = tostring(Combat.effective_cost(owner, def))
      -- Coût en rouge quand la réserve globale (ou la mana du Mage) ne couvre
      -- plus le coût (2026-08-24) : pur retour visuel, ne duplique pas la règle.
      local cost_insufficient = state.energy < Combat.effective_cost(owner, def)
      local mana_insufficient = def.mana_cost and (not owner or (owner.mana or 0) < def.mana_cost)
      -- Voile gris (2026-08-24) : le propriétaire est vaincu, cette carte ne
      -- redeviendra jouable à aucun prix ce combat-ci.
      local owner_defeated = not owner or owner.hp <= 0
      -- Grossies (2026-08-27) puis réaugmenté (2026-09-12, 5ᵉ demande
      -- explicite) : survol 1.18->1.35, sélection 1.28->1.55. `pop` (0..1)
      -- interpole en continu vers cette cible plutôt que d'y sauter.
      local target_scale, target_lift = View._hand_pop.hover_scale, View._hand_pop.hover_lift
      if is_pending then target_scale, target_lift = View._hand_pop.selected_scale, View._hand_pop.selected_lift end
      local scale = 1 + (target_scale - 1) * pop
      local lift = target_lift * pop
      love.graphics.push()
      love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2 - lift)
      love.graphics.scale(scale, scale)
      -- La carte "spéciale" (survolée/sélectionnée) se redresse, comme dans
      -- Slay the Spire -- l'éventail ne concerne que les cartes au repos.
      -- Angle interpolé vers 0 avec `pop`, jamais un bascule net.
      if r.fan_angle then love.graphics.rotate(r.fan_angle * (1 - pop)) end
      love.graphics.translate(-r.w / 2, -r.h / 2)

      -- La sélection (`is_pending`) reste exclusivement signalée par l'or de
      -- Theme.accent sur le contour extérieur, jamais mélangée à la couleur de
      -- classe. Pas de vert "bonus" sur le nom (collision avec l'Assassin,
      -- déjà vert) -- le vert reste porté par la description.
      CardUI.draw_card_face(def, r.w, r.h, cost_text, desc_text, has_bonus and Theme.heal or Theme.muted, is_pending, cost_insufficient, mana_insufficient, owner_defeated)
      love.graphics.pop()
    end

    for _, c in ipairs(state.hand) do
      if (controller.hand_pop_amount[c.uid] or 0) <= 0 and not hiding_uids[c.uid] then draw_one(c) end
    end
    for _, c in ipairs(state.hand) do
      if (controller.hand_pop_amount[c.uid] or 0) > 0 and not hiding_uids[c.uid] then draw_one(c) end
    end
    return rects
  end

  local function draw_bottom_controls(controller)
    local b1, b2, b4 = View.end_turn_button, View.restart_button, View.restart_turn_button
    -- Retour visuel du clic (2026-09-12 -- "le bouton réagit avec un feedback
    -- visuel... (0.5s), puis les cartes se défaussent") : `end_turn_feedback_t`/
    -- `end_turn_feedback_duration` pilotent un "punch" d'échelle -- part de 1,
    -- culmine à mi-fenêtre, revient à 1 pile à la fin -- ET un flash de couleur
    -- sur toute la fenêtre.
    local feedback_p = controller.end_turn_feedback_t
      and math.min(1, controller.end_turn_feedback_t / controller.end_turn_feedback_duration)
    local punch_scale = feedback_p and (1 + 0.14 * math.sin(math.pi * feedback_p)) or 1
    local fill_color = feedback_p and UI.lerp_color(Theme.white, Theme.accent, feedback_p) or Theme.accent
    -- Bouton carré agrandi (2026-08-24) : centrage vertical approximatif pour
    -- un libellé qui peut retomber sur 2 lignes ("Fin de" / "tour").
    love.graphics.push()
    love.graphics.translate(b1.x + b1.w / 2, b1.y + b1.h / 2)
    love.graphics.scale(punch_scale, punch_scale)
    love.graphics.translate(-b1.w / 2, -b1.h / 2)
    UI.set(fill_color); love.graphics.rectangle("fill", 0, 0, b1.w, b1.h, 8, 8)
    UI.set(Theme.bg); love.graphics.setFont(Fonts.get(13)); love.graphics.printf(b1.label, 0, b1.h / 2 - 10, b1.w, "center")
    -- "?" d'infobulle (2026-08-28) : Theme.bg (sombre) plutôt que le blanc par
    -- défaut, pour rester lisible sur ce fond doré.
    UI.draw_tooltip_hint(b1.w, b1.h, Theme.bg)
    love.graphics.pop()
    -- Boutons rerapetissés (2026-08-24) : police 9 -> 7.
    UI.set(Theme.muted); love.graphics.rectangle("line", b2.x, b2.y, b2.w, b2.h, 8, 8)
    UI.text(b2.label, b2.x, b2.y + b2.h / 2 - 4, b2.w, 7, Theme.text)
    UI.set(Theme.muted); love.graphics.rectangle("line", b4.x, b4.y, b4.w, b4.h, 8, 8)
    UI.text(b4.label, b4.x, b4.y + b4.h / 2 - 4, b4.w, 7, Theme.text)

    -- Discret à dessein : pas de cadre, texte petit et sombre -- un outil de
    -- test, pas une action de jeu normale. Rejoint la colonne de gauche
    -- (2026-08-27) : même centrage vertical que ses 2 voisins juste au-dessus.
    local b3 = View.instant_victory_button
    UI.text(b3.label, b3.x, b3.y + b3.h / 2 - 4, b3.w, 7, Theme.muted)
  end

  -- Sélectionner une carte l'assigne directement à son propriétaire
  -- (2026-08-20) : plus de phase "choisis l'aventurier" à décrire ici,
  -- seulement l'attente d'une cible.
  local function hint_text(controller)
    local state = controller.state
    local pending = state.pending
    -- Message par défaut retiré (2026-08-27) : plus rien affiché tant
    -- qu'aucune carte n'est sélectionnée.
    if not pending then return "" end
    -- Carte "sans cible" en attente de confirmation (2026-08-27) : un second
    -- clic n'importe où valide, une autre carte de la main échange la sélection.
    if pending.awaiting_confirm_kind then
      return pending.def.name .. " — clique n'importe où pour valider (ou une autre carte pour changer)."
    end
    if controller.input_mode == "arrow" then return pending.def.name .. " — vise la cible." end
    return pending.def.name .. " — choisis la cible."
  end

  local function draw_card_flights(controller)
    for _, a in ipairs(controller.card_anims) do
      -- Immobile à SA position d'origine tant que son tour n'est pas venu
      -- (2026-09-12) : `a.hold_visible` distingue ce cas d'un délai de
      -- pioche/remélange ordinaire -- une carte jouée existe déjà pleinement
      -- et doit rester visible à sa place le temps que les animations de son
      -- effet jouent.
      if a.elapsed < a.delay and a.hold_visible and a.def then
        -- Reste GROSSE tout le temps de l'attente, jamais un retour à la
        -- taille normale (2026-09-12) -- la carte jouée est forcément
        -- sélectionnée (is_pending) au moment du clic, elle GARDE cette
        -- taille pendant tout le hold. Seul ajout : un petit "saut" de zoom
        -- rapide juste au moment de la validation.
        local VALIDATE_PUNCH_DURATION = 0.15
        local VALIDATE_PUNCH_BUMP = 0.15
        local punch_p = math.min(1, a.elapsed / VALIDATE_PUNCH_DURATION)
        local punch_extra = VALIDATE_PUNCH_BUMP * math.sin(math.pi * punch_p)
        local scale = View._hand_pop.selected_scale + punch_extra
        local lift = View._hand_pop.selected_lift
        UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
        love.graphics.push()
        love.graphics.origin()
        local prev_canvas = love.graphics.getCanvas()
        love.graphics.setCanvas(UI.card_flight_canvas)
        love.graphics.clear(0, 0, 0, 0)
        CardUI.draw_card_face(a.def, UI.CARD_W, UI.CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
        love.graphics.setCanvas(prev_canvas)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        local cx, cy = a.from.x + a.from.w / 2, a.from.y + a.from.h / 2 - lift
        local w, h = a.from.w * scale, a.from.h * scale
        love.graphics.draw(UI.card_flight_canvas, cx - w / 2, cy - h / 2, 0, w / UI.CARD_W, h / UI.CARD_H)
      elseif a.elapsed >= a.delay then
        local p = math.min(1, (a.elapsed - a.delay) / a.duration)
        -- Point de départ du vol/de la dissolution = la taille "validée"
        -- (grossie) plutôt que la taille normale de `a.from`, pour les entrées
        -- qui viennent de tenir en main ainsi (2026-09-12) -- sans ça, la
        -- carte rapetissait d'un coup à cet instant même si elle restait
        -- grosse pendant tout le hold. Les entrées SANS hold_visible (pioche,
        -- remélange...) gardent `a.from` tel quel.
        local from = a.from
        if a.hold_visible then
          local scale = View._hand_pop.selected_scale
          local lift = View._hand_pop.selected_lift
          local w, h = a.from.w * scale, a.from.h * scale
          local cx, cy = a.from.x + a.from.w / 2, a.from.y + a.from.h / 2 - lift
          from = { x = cx - w / 2, y = cy - h / 2, w = w, h = h }
        end
        -- "Amnésie" (2026-08-28) : la carte ne VOLE nulle part (`a.dissolve`) --
        -- elle ne rejoint jamais la défausse, donc pas de destination à
        -- animer, juste un rétrécissement + fondu ACCÉLÉRÉ sur place,
        -- synchronisé avec le burst de cendres dessiné par-dessus.
        if a.dissolve then
          local ease = p * p -- easeInQuad : démarre lentement, s'effondre vers la fin
          local scale = 1 - 0.35 * ease
          local alpha = 1 - ease
          local cx, cy = from.x + from.w / 2, from.y + from.h / 2
          local w, h = from.w * scale, from.h * scale
          if a.def then
            UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
            -- push/origin()/pop (2026-08-30) : le canvas fait exactement
            -- CARD_W x CARD_H en pixels PHYSIQUES, mais l'échelle globale
            -- (love.graphics.scale(SCALE,SCALE), voir main.lua) restait active
            -- PENDANT le rendu dedans -- neutralisée le temps du rendu DANS le
            -- canvas ; restaurée avant de le ressortir. Restaure le canvas
            -- PRÉCÉDENT plutôt qu'un `setCanvas()` sans argument (2026-08-30,
            -- bug évité) : ce dernier vise toujours l'écran, casserait tout
            -- rendu appelé depuis L'INTÉRIEUR d'un autre canvas déjà actif.
            love.graphics.push()
            love.graphics.origin()
            local prev_canvas = love.graphics.getCanvas()
            love.graphics.setCanvas(UI.card_flight_canvas)
            love.graphics.clear(0, 0, 0, 0)
            CardUI.draw_card_face(a.def, UI.CARD_W, UI.CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
            love.graphics.setCanvas(prev_canvas)
            love.graphics.pop()
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(UI.card_flight_canvas, cx - w / 2, cy - h / 2, 0, w / UI.CARD_W, h / UI.CARD_H)
          end
          goto continue
        end
        -- Petit rebond d'arrivée sur la pioche (2026-08-21) : ease_out_back
        -- dépasse légèrement 1 avant de s'y stabiliser -- la carte "atterrit"
        -- dans la main. La défausse garde l'ancienne décélération simple.
        local ease = a.fade_in and UI.ease_out_back(a.elapsed - a.delay, a.duration)
          or (1 - (1 - p) ^ 2) -- easeOutQuad, approxime le cubic-bezier CSS du prototype
        local x = from.x + (a.to.x - from.x) * ease
        local y = from.y + (a.to.y - from.y) * ease
        local w = from.w + (a.to.w - from.w) * ease
        local h = from.h + (a.to.h - from.h) * ease
        local alpha = a.fade_in and math.min(1, p * 1.6) or (1 - p * 0.8)
        if a.def then
          UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
          -- Même correctif que ci-dessus (goto continue).
          love.graphics.push()
          love.graphics.origin()
          local prev_canvas = love.graphics.getCanvas()
          love.graphics.setCanvas(UI.card_flight_canvas)
          love.graphics.clear(0, 0, 0, 0)
          CardUI.draw_card_face(a.def, UI.CARD_W, UI.CARD_H, a.def.cost, a.def.desc, Theme.muted, false)
          love.graphics.setCanvas(prev_canvas)
          love.graphics.pop()
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.draw(UI.card_flight_canvas, x, y, 0, w / UI.CARD_W, h / UI.CARD_H)
        else
          -- Silhouette simple sans face précise (2026-08-21, cas volontaire --
          -- les "fantômes" du remélange défausse -> pioche sont des cartes
          -- anonymes, en montrer une face précise serait trompeur).
          UI.set(Theme.panel_light, alpha)
          love.graphics.rectangle("fill", x, y, w, h, 8, 8)
        end
        ::continue::
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
  end
  View.draw_card_flights = draw_card_flights

  local FLOATER_RISE = 34
  -- "discretion" (2026-08-28) : même famille visuelle que "heal", juste une
  -- teinte propre pour qu'un flottant de Discrétion ne se confonde jamais
  -- avec un vrai soin. "decay" (2026-08-30, décroissance de fin de tour) :
  -- teinte neutre/éteinte, jamais une couleur de statut précise.
  local FLOATER_COLOR = { damage = "hp", heal = "heal", discretion = "discretion", decay = "muted" }
  -- Retour du porteur de projet (2026-08-09) : les dégâts doivent taper plus
  -- fort visuellement -- police nettement plus grosse + un zoom qui dépasse
  -- puis se stabilise. Agrandi 15 -> 22 (2026-08-28, soin de la bénédiction du
  -- Temple) : profite donc à toute récupération de PV affichée en combat.
  local DAMAGE_FLOATER_SIZE = 26
  local HEAL_FLOATER_SIZE = 22
  local DAMAGE_ZOOM_DURATION = 0.22

  local function draw_floaters(controller)
    for _, f in ipairs(controller.floaters) do
      -- `f.t < 0` (2026-09-02, séquencement dégâts-après-bouclier) : pas
      -- encore "son tour", même garde que draw_shield_fx/unit_anim_transform.
      if f.t >= 0 then
        local p = math.min(1, f.t / controller.floater_duration)
        local ease = 1 - (1 - p) ^ 2
        -- "decay" DESCEND, tous les autres montent (2026-08-30) : signe
        -- inversé sur FLOATER_RISE plutôt qu'une 2ᵉ constante.
        local y = f.kind == "decay" and (f.y + ease * FLOATER_RISE) or (f.y - ease * FLOATER_RISE)
        local alpha = 1 - p * p
        UI.set(Theme[FLOATER_COLOR[f.kind]] or Theme.text, alpha)
        if f.kind == "damage" then
          local zoom = UI.ease_out_back(f.t, DAMAGE_ZOOM_DURATION)
          love.graphics.setFont(Fonts.get(DAMAGE_FLOATER_SIZE))
          love.graphics.push()
          love.graphics.translate(f.x, y)
          love.graphics.scale(zoom, zoom)
          love.graphics.printf(f.text, -40, -DAMAGE_FLOATER_SIZE / 2, 80, "center")
          love.graphics.pop()
        else
          love.graphics.setFont(Fonts.get(HEAL_FLOATER_SIZE))
          love.graphics.printf(f.text, f.x - 40, y, 80, "center")
        end
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Petit burst de pixels à l'impact (2026-08-09) : quelques carrés qui
  -- giclent et retombent légèrement avant de s'estomper -- volontairement
  -- fait à la main, pour rester dans l'esprit pixel art. `pt.color`/
  -- `pt.gravity` (optionnels, 2026-08-28, cendres d'"Amnésie") : replis sur le
  -- burst d'impact rouge d'origine quand absents. `pt.canvas`/`pt.quad`/
  -- `pt.tile` (optionnels, 2026-08-30, mort d'un ennemi) : une tuile
  -- DÉCOUPÉE DANS L'IMAGE RÉELLE de l'ennemi plutôt qu'un simple carré de
  -- couleur, avec en plus une légère rotation propre pour l'effet "débris".
  local PARTICLE_GRAVITY = 160

  local function draw_particles(controller)
    for _, pt in ipairs(controller.particles) do
      -- `pt.t < 0` (2026-09-02, séquencement dégâts-après-bouclier) : pas
      -- encore "son tour" -- sans cette garde, la trajectoire se dessinerait
      -- déjà, à l'envers, avant l'éclosion réelle.
      if pt.t >= 0 then
        local p = math.min(1, pt.t / (pt.duration or controller.particle_duration))
        local gravity = pt.gravity or PARTICLE_GRAVITY
        local x = pt.x + pt.vx * pt.t
        local y = pt.y + pt.vy * pt.t + 0.5 * gravity * pt.t * pt.t
        if pt.canvas and pt.quad then
          love.graphics.setColor(1, 1, 1, 1 - p)
          local rot = (pt.rot0 or 0) + (pt.vrot or 0) * pt.t
          love.graphics.draw(pt.canvas, pt.quad, x, y, rot, 1, 1, pt.tile / 2, pt.tile / 2)
        else
          UI.set(pt.color or Theme.hp, 1 - p)
          love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
        end
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  --- Rend l'icône (sprite réel si dispo, sinon silhouette vectorielle) d'un
  -- ennemi dans un nouveau canvas carré de `size` px, puis le découpe en
  -- `grid` x `grid` Quads (2026-08-30, "que ce soit l'image de l'ennemi
  -- elle-même qui soit découpée en petits carrés qui partent dans toutes les
  -- directions") : appelée UNE SEULE FOIS par Controller:spawn_enemy_shatter
  -- au moment de l'explosion (jamais à chaque frame) -- le canvas et les
  -- Quads résultants sont ensuite portés par chaque particule pour toute leur
  -- durée de vie (voir pt.canvas/pt.quad, draw_particles ci-dessus).
  function View.capture_enemy_shatter(template_id, size, grid)
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.push()
    love.graphics.origin()
    local prev_canvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    Icons.draw_enemy(template_id, size / 2, size / 2, size / 2, Theme.text)
    love.graphics.setCanvas(prev_canvas)
    love.graphics.pop()
    local tile = size / grid
    local quads = {}
    for gy = 0, grid - 1 do
      for gx = 0, grid - 1 do
        quads[#quads + 1] = { quad = love.graphics.newQuad(gx * tile, gy * tile, tile, tile, size, size), gx = gx, gy = gy }
      end
    end
    return canvas, quads, tile
  end

  local function quad_bezier(t, x0, y0, cx, cy, x1, y1)
    local mt = 1 - t
    return mt * mt * x0 + 2 * mt * t * cx + t * t * x1,
      mt * mt * y0 + 2 * mt * t * cy + t * t * y1
  end

  local function quad_bezier_tangent(t, x0, y0, cx, cy, x1, y1)
    local mt = 1 - t
    return 2 * mt * (cx - x0) + 2 * t * (x1 - cx),
      2 * mt * (cy - y0) + 2 * t * (y1 - cy)
  end

  --- Chaîne courbe de petits maillons plutôt qu'un trait droit (2026-08-09,
  -- référence visuelle façon Slay the Spire) : courbe de Bézier quadratique
  -- (cambrure + léger balancement dans le temps), maillons = petits
  -- rectangles arrondis orientés sur la tangente locale de la courbe, pointe
  -- à l'arrivée orientée pareil.
  -- `tip_angle` (optionnel, radians) : impose l'orientation de la pointe au
  -- lieu de la déduire de la tangente d'arrivée -- utile quand la direction
  -- réelle est connue d'avance et fixe (flèche de télégraphe ennemi : les
  -- ennemis sont toujours au-dessus des aventuriers, "vers le bas" est donc
  -- toujours correct).
  -- `bow_up` (optionnel, 2026-08-24) : force la cambrure du côté du HAUT de
  -- l'écran, quel que soit le signe de dx. Seul draw_enemy_target_arrows
  -- l'active ; la flèche de ciblage du joueur garde son comportement naturel.
  -- `bow_bias` (optionnel, px, 2026-08-27, "que les flèches se chevauchent le
  -- moins possible") : ajouté tel quel à la cambrure calculée.
  local function draw_arrow(x1, y1, x2, y2, color, tip_angle, bow_up, bow_bias)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end

    local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    local nx, ny = -dy / dist, dx / dist
    if bow_up and ny > 0 then nx, ny = -nx, -ny end
    local bow = math.min(dist * 0.22, 70) + math.sin(love.timer.getTime() * 3) * math.min(dist * 0.03, 8) + (bow_bias or 0)
    local cx, cy = mx + nx * bow, my + ny * bow

    -- Recul de la chaîne (2026-08-10) : calculer l'angle d'arrivée puis LE
    -- POINT DE LA BASE du triangle (reculé de `arrow_reach` le long de cet
    -- axe) AVANT de dessiner les maillons, et faire terminer la courbe de la
    -- chaîne pile sur ce point (pas sur la pointe x2,y2) -- son dernier
    -- maillon (t=1) tombe alors exactement sur la base, tangente comprise,
    -- quelle que soit la cambrure. `arrow_size` = même valeur que le triangle
    -- dessiné plus bas (une seule source).
    local etx, ety = quad_bezier_tangent(1, x1, y1, cx, cy, x2, y2)
    local end_angle = tip_angle or math.atan(ety, etx)
    local arrow_size = 12
    local arrow_reach = arrow_size * math.cos(math.rad(30))
    local bx = x2 - arrow_reach * math.cos(end_angle)
    local by = y2 - arrow_reach * math.sin(end_angle)

    UI.set(color)
    local link_size = 9
    local steps = math.max(4, math.floor(dist / 16))
    for i = 0, steps do
      local t = i / steps
      local px, py = quad_bezier(t, x1, y1, cx, cy, bx, by)
      local tx, ty = quad_bezier_tangent(t, x1, y1, cx, cy, bx, by)
      local scale = 0.55 + 0.45 * t -- maillons plus petits près de l'origine, comme une queue
      love.graphics.push()
      love.graphics.translate(px, py)
      love.graphics.rotate(math.atan(ty, tx))
      love.graphics.rectangle("fill", -link_size * scale / 2, -link_size * scale * 0.35, link_size * scale, link_size * scale * 0.7, 3, 3)
      love.graphics.pop()
    end

    local a1, a2 = end_angle + math.rad(150), end_angle - math.rad(150)
    love.graphics.polygon("fill",
      x2, y2,
      x2 + arrow_size * math.cos(a1), y2 + arrow_size * math.sin(a1),
      x2 + arrow_size * math.cos(a2), y2 + arrow_size * math.sin(a2))
  end

  --- Flèche du télégraphe ennemi (2026-08-10) : indique quel aventurier une
  -- attaque ennemie va toucher, avec le même style "chaîne animée" que
  -- draw_arrow ci-dessus. Rouge fixe (Theme.hp, 2026-08-24) : le rouge dit
  -- sans ambiguïté "menace ennemie", jamais une couleur de classe. Rien si
  -- l'ennemi est mort, n'a pas de coup télégraphié, si son coup ne cible
  -- personne, ou si la cible n'est plus vivante.
  -- Points d'arrivée décalés + cambrures variées (2026-08-27, "ne pas se
  -- superposer") : regroupées par cible, décalées en éventail sur l'axe X du
  -- point d'arrivée -- ordonnées par la position X de l'ennemi SOURCE ; chaque
  -- flèche reçoit en plus un léger biais de cambrure, dérivé de son rang
  -- global parmi toutes les flèches affichées.
  local function draw_enemy_target_arrows(controller)
    local state = controller.state
    local enemy_rects = View.enemy_rects(state)
    local hero_rects = View.hero_rects(state)

    local targeting = {}
    for _, e in ipairs(state.enemies) do
      if e.hp > 0 and e.next_move and Combat.TARGETABLE_MOVE_KINDS[e.next_move.kind] and e.target_hero_id then
        local target = Combat.hero_by_id(state, e.target_hero_id)
        if target and target.hp > 0 and enemy_rects[e.id] and hero_rects[target.id] then
          targeting[#targeting + 1] = { enemy = e, target = target }
        end
      end
    end
    if #targeting == 0 then return end

    local by_target = {}
    for _, t in ipairs(targeting) do
      local list = by_target[t.target.id]
      if not list then list = {}; by_target[t.target.id] = list end
      list[#list + 1] = t
    end
    for _, list in pairs(by_target) do
      table.sort(list, function(a, b) return enemy_rects[a.enemy.id].x < enemy_rects[b.enemy.id].x end)
    end

    local ARRIVAL_SPACING = 14
    local BOW_BIAS_STEP = 7
    for i, t in ipairs(targeting) do
      local e, target = t.enemy, t.target
      local er, hr = enemy_rects[e.id], hero_rects[target.id]
      local list = by_target[target.id]
      local idx = 1
      for j, item in ipairs(list) do if item.enemy.id == e.id then idx = j end end
      local arrival_offset = (idx - (#list + 1) / 2) * ARRIVAL_SPACING
      local bow_bias = (i - (#targeting + 1) / 2) * BOW_BIAS_STEP
      -- Départ aux PIEDS de l'ennemi (2026-08-30) : même y que le bas du
      -- portrait (voir draw_enemy_icon dans draw_enemy, y=20 taille 62 -> bas
      -- à 82), à resynchroniser à la main si ces chiffres bougent.
      draw_arrow(
        er.x + er.w / 2, er.y + 82, hr.x + hr.w / 2 + arrival_offset, hr.y,
        Theme.hp, math.pi / 2, true, bow_bias
      )
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Sélectionner une carte l'assigne DIRECTEMENT à son propriétaire
  -- (2026-08-20) : `pending` n'existe donc jamais sans `pending.hero_id` déjà
  -- fixé -- plus de "flèche main -> aventurier" pendant un choix de héros,
  -- seulement la flèche aventurier -> cible finale (ennemi/allié) ci-dessous.
  local function draw_targeting_arrow(controller)
    if controller.input_mode ~= "arrow" or controller.screen ~= "playing" then return end
    local state = controller.state
    local pending = state.pending
    if not pending or not pending.hero_id then return end
    if pending.def.target ~= "enemy" and pending.def.target ~= "ally" and pending.def.target ~= "conditional" and pending.def.target ~= "enemy-or-ally" then return end

    local mx, my = love.mouse.getPosition()
    mx, my = mx / SCALE, my / SCALE

    local origin = View.hero_rects(state)[pending.hero_id]
    if not origin then return end
    local ox, oy = origin.x + origin.w / 2, origin.y + origin.h / 2
    local valid = false
    if pending.def.target == "enemy" or pending.def.target == "conditional" or pending.def.target == "enemy-or-ally" then
      for _, e in ipairs(state.enemies) do
        local r = View.enemy_rects(state)[e.id]
        if r and e.hp > 0 and UI.point_in(r, mx, my) then valid = true end
      end
    end
    if pending.def.target == "ally" or pending.def.target == "enemy-or-ally" then
      for _, h in ipairs(state.heroes) do
        if h.id ~= pending.hero_id then
          local r = View.hero_rects(state)[h.id]
          if r and h.hp > 0 and UI.point_in(r, mx, my) then valid = true end
        end
      end
    end
    draw_arrow(ox, oy, mx, my, valid and Theme.heal or Theme.energy)
  end

  -- Dupliqué depuis controller.lua (2026-08-30, compteur "X/9 avant le Boss") :
  -- controller.lua requiert déjà view.lua/view.init, un require dans l'autre
  -- sens créerait un cycle. 9->8 (2026-09-01, 2 biomes de 4 combats chacun
  -- avant le Boss) : voir Game.current_biome dans game.lua.
  local BOUNDED_COMBAT_COUNT = 8

  --- Scène de combat principale (menu/options/boss_select/deck_builder/
  -- bossVictory/biome_intro/team_select/campfire/forge/temple/refuge sont
  -- dispatchés à part par view/init.lua, jamais atteints ici) : titre, rangée
  -- d'ennemis (avec entrée animée), "Ta troupe"/HUD or/rangée de héros,
  -- flèches de télégraphe, main, boutons du bas, indice de ciblage, puis
  -- l'overlay de défaite/victoire (delegated to victory.lua) et enfin les VFX
  -- communs (flèche de ciblage joueur, vols de carte/pièces, particules,
  -- flottants, infobulle, "voir le deck", menu pause).
  function View.draw_combat(controller)
    local state = controller.state
    Background.draw(state.enemies, UI.W, UI.H)

    -- Titre "Hero Card Game — Run Infini" retiré (2026-08-27) : redondant en
    -- plein combat, déjà affiché sur l'écran de menu. Compteur "X/9 avant le
    -- Boss" (2026-08-30, run "bounded" uniquement) : une fois DANS le combat
    -- de boss lui-même, plus de "sur 9" à afficher.
    local combat_title
    if state.run.is_boss then
      combat_title = "Combat contre le Boss — Tour " .. state.turn
    elseif controller.run_mode == "bounded" then
      combat_title = "Combat " .. state.run.combat_index .. "/" .. BOUNDED_COMBAT_COUNT .. " avant le Boss — Tour " .. state.turn
    else
      combat_title = "Combat " .. state.run.combat_index .. " — Tour " .. state.turn
    end
    UI.text(combat_title, 0, 30, UI.W, 11, Theme.muted)

    UI.text("Ennemis", 20, 40, 200, 10, Theme.muted, "left")
    -- Descente des ennemis à l'entrée en combat (2026-08-30) : tant que son
    -- délai n'est pas écoulé, l'ennemi n'est pas encore dessiné DU TOUT --
    -- une fois le délai passé, le rect qu'on lui passe se contente d'avoir un
    -- y interpolé depuis le haut de l'écran, jamais draw_enemy lui-même modifié.
    local enemy_rects_now = View.enemy_rects(state)
    for _, e in ipairs(state.enemies) do
      local r = enemy_rects_now[e.id]
      local entrance = controller.enemy_entrance[e.id]
      if not entrance then
        draw_enemy(controller, e, r)
      elseif entrance.elapsed >= entrance.delay then
        local ease = UI.ease_out_back(entrance.elapsed - entrance.delay, entrance.duration)
        local from_y = -r.h - 40
        draw_enemy(controller, e, { x = r.x, y = from_y + (r.y - from_y) * ease, w = r.w, h = r.h })
      end
    end

    -- Recalé de HERO_ROW_Y-14 à HERO_ROW_Y-28 (2026-09-02) : libère la ligne
    -- HERO_ROW_Y-14 pour le HUD "PO" juste en dessous.
    UI.text("Ta troupe", 20, HERO_ROW_Y - 28, 200, 10, Theme.muted, "left")
    draw_gold_display(state)
    for _, h in ipairs(state.heroes) do draw_hero(controller, h, View.hero_rects(state)[h.id]) end

    draw_enemy_target_arrows(controller)

    -- Fenêtre de log retirée pour l'instant (2026-08-08) : l'espace gagné sert
    -- à séparer visuellement la troupe des ennemis. `state.log` continue
    -- d'être alimenté côté règles, juste plus affiché ici.

    draw_hand(controller)
    draw_bottom_controls(controller)
    -- 662 -> 462 (2026-09-12, la main affiche maintenant CARD_H en entier) :
    -- remonté dans l'espace resté libre entre la rangée de héros et la main,
    -- seul endroit où cet indice ne risque plus de se faire recouvrir.
    UI.text(hint_text(controller), 0, 462, UI.W, 10, Theme.muted)

    if controller.screen == "defeat" then
      View.draw_defeat_overlay(controller)
    elseif controller.screen == "victory" then
      View.draw_victory_overlay(controller)
    end
    -- campfire/refuge/forge/temple : dispatchés à part par view/init.lua,
    -- jamais atteints ici.

    draw_targeting_arrow(controller)
    draw_card_flights(controller)
    View.draw_coin_flights(controller)
    View.draw_gold_purse_overlay(controller)
    draw_particles(controller)
    draw_floaters(controller)
    if controller.screen == "playing" or controller.screen == "victory" then
      View.draw_tooltip(controller)
    end

    View.draw_deck_view(controller)
    View.draw_pause_menu(controller)

    love.graphics.setColor(1, 1, 1, 1)
  end
end
