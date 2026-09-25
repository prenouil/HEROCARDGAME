-- Écran "Choisis ton équipe" (2026-09-25, extrait de l'ex-monolithe view.lua
-- -- voir src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Heroes = require("src.data.heroes")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  -- Écran "Choisis ton équipe" (2026-08-29, avant chaque run -- 4 aventuriers
  -- parmi les 6 `Heroes.defs`) : rangée du haut = disponibles (pas encore dans
  -- l'équipe), rangée du bas = équipe confirmée -- 2 listes MUTUELLEMENT
  -- EXCLUSIVES (voir Controller:team_select_confirm, qui bascule un id de
  -- l'une à l'autre) -- jamais le même héros affiché aux deux endroits à la fois.
  local TEAM_HERO_W, TEAM_HERO_H = 108, 120
  local TEAM_HERO_GAP = 18
  local TEAM_AVAILABLE_Y = 66
  -- Rangée "équipe confirmée" ET bouton "Partir à l'aventure" ancrés sur LA
  -- MÊME valeur (2026-08-30, demande explicite) : les 2 partagent désormais
  -- TEAM_BOTTOM_Y. Rangée ANCRÉE À GAUCHE (pas centrée, contrairement à la
  -- rangée du haut) -- une rangée centrée à 4 aventuriers déborderait sur le
  -- bouton "Partir à l'aventure".
  -- 590 (2026-09-12, CARD_H canonique agrandi -- +20% explicite) : 590+
  -- TEAM_HERO_H=710, 10px de marge sous 720. Vérifié au rendu.
  local TEAM_BOTTOM_Y = 590
  local TEAM_PARTY_LEFT = 170

  -- Emplacements FIXES, un par héros du roster complet (2026-08-30, bug signalé
  -- -- "quand un aventurier est sélectionné, les autres se recalent vers le
  -- centre, je préfère que chacun reste à sa place") : la rangée est calculée
  -- UNE FOIS sur `#Heroes.defs` (toujours 6, ne bouge jamais), chaque héros
  -- reçoit la case correspondant à SA position dans le roster complet, qu'il
  -- soit actuellement disponible ou déjà dans l'équipe.
  local TEAM_ALL_SLOTS_RECTS
  local function team_select_all_slots()
    TEAM_ALL_SLOTS_RECTS = TEAM_ALL_SLOTS_RECTS
      or UI.centered_row(#Heroes.defs, TEAM_HERO_W, TEAM_HERO_H, TEAM_AVAILABLE_Y, TEAM_HERO_GAP)
    return TEAM_ALL_SLOTS_RECTS
  end

  function View.team_select_available_rects(controller)
    local ts = controller.team_select
    if not ts then return {} end
    local slots = team_select_all_slots()
    local still_available = {}
    for _, id in ipairs(ts.available_ids) do still_available[id] = true end
    local out = {}
    for i, def in ipairs(Heroes.defs) do
      if still_available[def.id] then out[def.id] = slots[i] end
    end
    return out
  end

  function View.team_select_party_rects(controller)
    local ts = controller.team_select
    if not ts then return {} end
    local out = {}
    for i, id in ipairs(ts.selected_ids) do
      out[id] = {
        x = TEAM_PARTY_LEFT + (i - 1) * (TEAM_HERO_W + TEAM_HERO_GAP), y = TEAM_BOTTOM_Y,
        w = TEAM_HERO_W, h = TEAM_HERO_H,
      }
    end
    return out
  end

  -- "Projecteur" (2026-08-29) : emplacement fixe où le héros survolé/
  -- sélectionné SE DÉPLACE réellement, plus grand que sa case d'origine.
  -- Reste ENTIÈREMENT sous la rangée du haut (qui s'arrête à
  -- TEAM_AVAILABLE_Y + TEAM_HERO_H = 186).
  local TEAM_SPOTLIGHT_W, TEAM_SPOTLIGHT_H = 260, 280
  local TEAM_SPOTLIGHT_X = 40
  View.team_select_spotlight_rect = {
    x = TEAM_SPOTLIGHT_X, y = 200, w = TEAM_SPOTLIGHT_W, h = TEAM_SPOTLIGHT_H,
  }

  -- Sous le projecteur désormais, pas à côté (2026-08-30, demande explicite).
  local TEAM_ACTION_BTN_W, TEAM_ACTION_BTN_H = 90, 40
  local TEAM_ACTION_BTN_X = TEAM_SPOTLIGHT_X + (TEAM_SPOTLIGHT_W - TEAM_ACTION_BTN_W) / 2
  View.team_select_cancel_button = {
    x = TEAM_ACTION_BTN_X, y = View.team_select_spotlight_rect.y + TEAM_SPOTLIGHT_H + 10,
    w = TEAM_ACTION_BTN_W, h = TEAM_ACTION_BTN_H, label = "Annuler",
  }
  View.team_select_confirm_button = {
    x = TEAM_ACTION_BTN_X, y = View.team_select_cancel_button.y + TEAM_ACTION_BTN_H + 8,
    w = TEAM_ACTION_BTN_W, h = TEAM_ACTION_BTN_H, label = "Valider",
  }

  -- Cartes du héros mis en avant (2026-08-29/30) : jusqu'à 3 par rangée,
  -- centrées sur TOUTE la largeur.
  local TEAM_CARD_Y = 190
  local TEAM_CARD_ROW_GAP = 8
  local TEAM_CARD_ROW1_MAX = 3
  function View.team_select_card_rects(count)
    local rects = {}
    local row1_count = math.min(count, TEAM_CARD_ROW1_MAX)
    local row1 = UI.centered_row(row1_count, UI.CARD_W, UI.CARD_H, TEAM_CARD_Y)
    for i = 1, row1_count do rects[i] = row1[i] end
    if count > TEAM_CARD_ROW1_MAX then
      local row2_count = count - TEAM_CARD_ROW1_MAX
      local row2 = UI.centered_row(row2_count, UI.CARD_W, UI.CARD_H, TEAM_CARD_Y + UI.CARD_H + TEAM_CARD_ROW_GAP)
      for i = 1, row2_count do rects[TEAM_CARD_ROW1_MAX + i] = row2[i] end
    end
    return rects
  end

  --- Rectangle hors-écran de même taille que `to`, positionné sur le bord
  -- `side` ("left"/"right"/"top"/"bottom") -- origine OU destination d'un vol
  -- de carte sur l'écran de choix d'équipe (2026-08-29). Purement cosmétique,
  -- aucun lien avec une règle de jeu.
  function View.team_select_offscreen_rect(to, side)
    local margin = 60
    if side == "left" then return { x = -to.w - margin, y = to.y, w = to.w, h = to.h } end
    if side == "right" then return { x = UI.W + margin, y = to.y, w = to.w, h = to.h } end
    if side == "top" then return { x = to.x, y = -to.h - margin, w = to.w, h = to.h } end
    return { x = to.x, y = UI.H + margin, w = to.w, h = to.h }
  end

  -- Ancré sur TEAM_BOTTOM_Y, comme la rangée "équipe" juste à gauche
  -- (2026-08-29, demande explicite -- "au même niveau que Partir à
  -- l'aventure").
  local TEAM_LAUNCH_W, TEAM_LAUNCH_H = 170, 110
  View.team_select_launch_button = {
    x = UI.W - TEAM_LAUNCH_W - 30, y = TEAM_BOTTOM_Y, w = TEAM_LAUNCH_W, h = TEAM_LAUNCH_H,
    label = "Partir à\nl'aventure",
  }

  -- "Auto-fill" (2026-09-02, demande explicite) : juste au-dessus de "Partir
  -- à l'aventure", même largeur/même colonne -- toujours cliquable.
  local TEAM_AUTOFILL_W, TEAM_AUTOFILL_H, TEAM_AUTOFILL_GAP = TEAM_LAUNCH_W, 36, 10
  View.team_select_autofill_button = {
    x = UI.W - TEAM_LAUNCH_W - 30, y = TEAM_BOTTOM_Y - TEAM_AUTOFILL_H - TEAM_AUTOFILL_GAP,
    w = TEAM_AUTOFILL_W, h = TEAM_AUTOFILL_H, label = "Auto-fill",
  }

  -- "Deck" de l'écran de choix d'équipe (2026-08-30, demande explicite --
  -- "ses cartes se regroupent pour aller rejoindre le deck situé en bas à
  -- gauche, ce deck grossit à chaque nouvel aventurier") : PURE mise en scène.
  -- Ancré par son coin bas-gauche, sur le même bord bas que la rangée
  -- "équipe"/le bouton.
  local TEAM_DECK_LEFT = 20
  local TEAM_DECK_BOTTOM = TEAM_BOTTOM_Y + TEAM_HERO_H
  local TEAM_DECK_BASE_W, TEAM_DECK_BASE_H = 70, 90
  local TEAM_DECK_GROWTH = 12 -- px par aventurier validé
  function View.team_select_deck_rect(hero_count)
    local w = TEAM_DECK_BASE_W + TEAM_DECK_GROWTH * hero_count
    local h = TEAM_DECK_BASE_H + TEAM_DECK_GROWTH * hero_count
    return { x = TEAM_DECK_LEFT, y = TEAM_DECK_BOTTOM - h, w = w, h = h }
  end

  -- Durée du rebond d'agrandissement au survol (2026-08-30, demande explicite) :
  -- pilotée par controller.hover.t.
  local TEAM_HOVER_BOUNCE_DURATION = 0.28
  local TEAM_HOVER_BOUNCE_SCALE = 0.16

  --- Un cadre d'aventurier de l'écran de choix d'équipe (2026-08-29) --
  -- portrait + nom, contour or si mis en avant, pastille verte si déjà dans
  -- l'équipe confirmée. `hover_t` (2026-08-30, nil ou 0 si pas survolé) :
  -- TOUT le cadre grandit avec un effet de rebond au survol.
  local function draw_team_hero_slot(r, def, hover_t, focused, in_party)
    local scale = 1
    if hover_t and hover_t > 0 then
      scale = 1 + TEAM_HOVER_BOUNCE_SCALE * UI.ease_out_back(hover_t, TEAM_HOVER_BOUNCE_DURATION)
    end
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)

    local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
    UI.panel(r.x, r.y, r.w, r.h, Theme.panel_light)
    -- Couleur personnelle systématique (2026-08-30, bug signalé) : l'emphase
    -- "mis en avant"/survolé reste marquée par l'ÉPAISSEUR du contour, pas sa
    -- couleur.
    UI.set(hover_t and hover_t > 0 and Theme.text or palette.border)
    love.graphics.setLineWidth(focused and 4 or 2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    -- 130/58 -> 220/72 (2026-09-22, demande explicite -- "les aventuriers
    -- doivent être plus gros, presque le double") : le projecteur grandit
    -- avec sa case (TEAM_SPOTLIGHT_W/H ci-dessus) ; les 2 rangées gardent
    -- TEAM_HERO_W/H inchangées -- la marge déjà libre entre le bas du
    -- portrait et le name_badge ancré au bas de la case (26px) absorbe ce
    -- +14 sans rien déplacer d'autre.
    local portrait_size = focused and 220 or 72
    UI.draw_class_icon(def.class_id, def.icon, def.label,
      r.x + (r.w - portrait_size) / 2, r.y + 10, portrait_size, portrait_size, Theme.text)
    UI.name_badge(def.name, r.x + 6, r.y + r.h - 26, r.w - 12, 12, palette.border, Theme.bg, 2, 2)
    if in_party then
      UI.set(Theme.heal); love.graphics.circle("fill", r.x + r.w - 12, r.y + 12, 7)
    end
    love.graphics.push()
    love.graphics.translate(r.x, r.y)
    UI.draw_tooltip_hint(r.w, r.h)
    love.graphics.pop()

    love.graphics.pop()
  end

  --- Anim de déplacement d'UN portrait de héros (2026-08-30) : ease_out_back,
  -- même courbe que le vol des cartes -- le héros "atterrit" avec un léger
  -- rebond plutôt que de simplement s'arrêter.
  local function team_select_hero_anim_rect(a)
    local ease = UI.ease_out_back(a.elapsed, a.duration)
    return {
      x = a.from.x + (a.to.x - a.from.x) * ease,
      y = a.from.y + (a.to.y - a.from.y) * ease,
      w = a.to.w, h = a.to.h,
    }
  end

  local function team_select_find_hero_anim(ts, id)
    for _, a in ipairs(ts.hero_anims) do if a.id == id then return a end end
    return nil
  end

  --- "Deck" de mise en scène de l'écran de choix d'équipe (2026-08-30) : pile
  -- à étages dont le RECTANGLE lui-même grossit avec le nombre d'aventuriers
  -- confirmés, pas seulement l'effet d'épaisseur.
  local function draw_team_deck(rect, card_count)
    -- /3 pas /6 (2026-08-30) : garde la même progression d'épaisseur
    -- (0/1/2/2 étages pour 1/2/3/4 aventuriers).
    local layers = math.min(2, math.max(0, math.floor(card_count / 3) - 1))
    for i = layers, 1, -1 do
      UI.panel(rect.x + i * 3, rect.y - i * 3, rect.w, rect.h, Theme.panel)
    end
    UI.panel(rect.x, rect.y, rect.w, rect.h, Theme.panel_light)
    UI.set(Theme.accent); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setLineWidth(1)
    UI.text("DECK", rect.x, rect.y + 8, rect.w, 9, Theme.muted, "center")
    UI.text(tostring(card_count), rect.x, rect.y + rect.h / 2 - 4, rect.w, 16, Theme.text, "center")
  end

  local function draw_team_select(controller)
    local ts = controller.team_select
    Background.draw(nil, UI.W, UI.H)
    -- "Run Solo" (2026-09-02, demande explicite -- ts.max_team_size == 1) :
    -- titre/compteur adaptés, tout le reste de l'écran reste identique, juste
    -- borné à 1 au lieu de 4.
    UI.text(ts.max_team_size == 1 and "Choisis ton aventurier" or "Choisis ton équipe", 0, 18, UI.W, 22, Theme.text)
    UI.text(#ts.selected_ids .. " / " .. ts.max_team_size .. " aventurier" .. (ts.max_team_size > 1 and "s" or ""), 0, 44, UI.W, 12, Theme.muted)

    -- Héros "en transit" entre 2 emplacements (2026-08-30) : masqués de leur
    -- rangée d'origine ET de destination tant que l'anim n'est pas finie.
    local moving_ids = {}
    for _, a in ipairs(ts.hero_anims) do moving_ids[a.id] = true end

    local function hover_t_for(id)
      if controller.hover.kind == "team_hero" and controller.hover.target == id then
        return controller.hover.t
      end
      return nil
    end

    local available_rects = View.team_select_available_rects(controller)
    for _, id in ipairs(ts.available_ids) do
      if id ~= ts.focused_id and not moving_ids[id] then
        draw_team_hero_slot(available_rects[id], Heroes.by_id(id), hover_t_for(id), false, false)
      end
    end

    -- Cartes en vol : "in" se fige à sa position cible une fois l'animation
    -- finie. `a.delay` (2026-08-30) : reste VISIBLE, immobile à son point de
    -- départ, tant que son tour n'est pas venu.
    for _, a in ipairs(ts.card_anims) do
      local delay = a.delay or 0
      if a.elapsed < delay then
        if a.is_back then CardUI.draw_faded_card_back(a.class_id, a.count, a.from.x, a.from.y, 1)
        else CardUI.draw_faded_card(a.def, a.from.x, a.from.y, 1) end
      else
        local elapsed_since_start = a.elapsed - delay
        local p = math.min(1, elapsed_since_start / a.duration)
        local ease = a.mode == "in" and UI.ease_out_back(elapsed_since_start, a.duration) or (1 - (1 - p) ^ 2)
        local x = a.from.x + (a.to.x - a.from.x) * ease
        local y = a.from.y + (a.to.y - a.from.y) * ease
        local alpha = a.mode == "in" and math.min(1, p * 1.6) or (1 - p)
        if alpha > 0 then
          if a.is_back then CardUI.draw_faded_card_back(a.class_id, a.count, x, y, alpha)
          else CardUI.draw_faded_card(a.def, x, y, alpha) end
        end
      end
    end

    if ts.focused_id then
      local cb = View.team_select_cancel_button
      UI.set(Theme.panel_light); love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
      UI.set(Theme.accent); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
      love.graphics.setLineWidth(1)
      UI.text(cb.label, cb.x, cb.y + 14, cb.w, 14, Theme.text, "center")

      local already_in = false
      for _, sid in ipairs(ts.selected_ids) do if sid == ts.focused_id then already_in = true end end
      local vb = View.team_select_confirm_button
      local blocked = (not already_in) and #ts.selected_ids >= ts.max_team_size
      UI.set(blocked and Theme.panel or Theme.accent)
      love.graphics.rectangle("fill", vb.x, vb.y, vb.w, vb.h, 8, 8)
      UI.text(already_in and "Retirer" or "Valider", vb.x, vb.y + 14, vb.w, 14, blocked and Theme.muted or Theme.bg, "center")

      -- Projecteur (2026-08-30) : le héros mis en avant SE DÉPLACE réellement
      -- ici (interpolé tant que l'anim d'arrivée n'est pas finie, sinon posé
      -- pile sur View.team_select_spotlight_rect).
      local anim = team_select_find_hero_anim(ts, ts.focused_id)
      local r = anim and team_select_hero_anim_rect(anim) or View.team_select_spotlight_rect
      draw_team_hero_slot(r, Heroes.by_id(ts.focused_id), hover_t_for(ts.focused_id), true, false)
    end

    local party_rects = View.team_select_party_rects(controller)
    UI.text("Ton équipe", TEAM_PARTY_LEFT, TEAM_BOTTOM_Y - 16, 200, 10, Theme.muted, "left")
    for _, id in ipairs(ts.selected_ids) do
      if id ~= ts.focused_id and not moving_ids[id] then
        draw_team_hero_slot(party_rects[id], Heroes.by_id(id), hover_t_for(id), false, true)
      end
    end

    -- Héros en transit (2026-08-30) : ni dans une rangée, ni dans le
    -- projecteur (il vient de le quitter) -- dessiné à sa position interpolée.
    for _, a in ipairs(ts.hero_anims) do
      if a.id ~= ts.focused_id then
        local in_party = false
        for _, sid in ipairs(ts.selected_ids) do if sid == a.id then in_party = true end end
        draw_team_hero_slot(team_select_hero_anim_rect(a), Heroes.by_id(a.id), hover_t_for(a.id), false, in_party)
      end
    end

    -- 3 cartes "depart" par aventurier confirmé, pas 6 (2026-08-30, bug
    -- signalé) : ce chiffre doit rester cohérent avec
    -- Controller:team_select_spawn_cards.
    draw_team_deck(View.team_select_deck_rect(#ts.selected_ids), #ts.selected_ids * 3)

    local lb = View.team_select_launch_button
    local ready = #ts.selected_ids == ts.max_team_size
    if ready then
      local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
      UI.set(Theme.accent, 0.35 + 0.35 * pulse)
      love.graphics.rectangle("fill", lb.x - 5, lb.y - 5, lb.w + 10, lb.h + 10, 12, 12)
    end
    UI.set(ready and Theme.heal or Theme.panel_light)
    love.graphics.rectangle("fill", lb.x, lb.y, lb.w, lb.h, 10, 10)
    UI.set(ready and Theme.accent or Theme.muted); love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", lb.x, lb.y, lb.w, lb.h, 10, 10)
    love.graphics.setLineWidth(1)
    -- Label "Affronter le boss"/"Construire son deck" en mode "boss_test"/
    -- "solo" (2026-09-02, demande explicite) -- lb.label reste "Partir à
    -- l'aventure", la valeur par défaut pour "infini"/"bounded".
    local launch_label = lb.label
    if ts.mode == "boss_test" then launch_label = "Affronter\nle boss"
    elseif ts.mode == "solo" then launch_label = "Construire\nson deck"
    end
    UI.text(launch_label, lb.x, lb.y + lb.h / 2 - 24, lb.w, 24, ready and Theme.bg or Theme.muted, "center")

    -- "Auto-fill" (2026-09-02) : style plus discret que "Partir à l'aventure"
    -- (toujours actif, pas de pulse "prêt") -- juste au-dessus.
    local ab = View.team_select_autofill_button
    UI.set(Theme.panel_light)
    love.graphics.rectangle("fill", ab.x, ab.y, ab.w, ab.h, 8, 8)
    UI.set(Theme.muted); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ab.x, ab.y, ab.w, ab.h, 8, 8)
    love.graphics.setLineWidth(1)
    UI.text(ab.label, ab.x, ab.y + ab.h / 2 - 7, ab.w, 14, Theme.text, "center")

    -- Infobulles (2026-08-30, bug signalé -- "il faut que les info bulles
    -- marchent sur les aventuriers... pareil pour les cartes") : View.draw_tooltip
    -- lit déjà controller.hover -- "team_select" étant un retour anticipé de
    -- View.draw, jamais atteint par l'appel générique en fin de fonction.
    View.draw_tooltip(controller)
  end
  View.draw_team_select = draw_team_select
end
