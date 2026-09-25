-- Écrans de victoire (draft de carte inclus)/défaite/victoire de boss
-- (2026-09-25, extrait de l'ex-monolithe view.lua -- voir src/ui/view/init.lua
-- pour le contexte du découpage). `draw_victory_overlay`/`draw_defeat_overlay`
-- sont appelés par la scène de combat (view/combat.lua) -- c'est la seule
-- vraie extraction de logique de ce découpage (avant : inline dans
-- View.draw), nécessaire puisque le grand aiguillage par écran migre lui-même
-- dans view/init.lua.
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Fonts = require("src.ui.fonts")
local Sprites = require("src.ui.sprites")
local RichText = require("src.ui.richtext")
local Heroes = require("src.data.heroes")

return function(View, UI)
  local function combats_won_text(controller)
    return tostring(math.max(0, controller.state.run.combat_index - 1))
  end

  -- Écran de défaite (2026-09-02, demande explicite -- "l'option est
  -- simplement de rejouer", remplacé par 2 choix) : même gabarit empilé que le
  -- menu pause. "Rejouer avec la même équipe" reconduit déjà
  -- self.last_selected_ids/self.run_mode SANS rien de neuf à câbler.
  View.overlay_restart_button = { x = UI.W / 2 - 130, y = UI.H / 2 + 40, w = 260, h = 40, label = "Rejouer avec la même équipe" }
  View.overlay_menu_button = { x = UI.W / 2 - 130, y = UI.H / 2 + 88, w = 260, h = 40, label = "Retourner au menu" }

  --- Écran de défaite : voile noir + titre + bouton rejouer/menu.
  function View.draw_defeat_overlay(controller)
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.text("Défaite…", 0, UI.H / 2 - 40, UI.W, 26, Theme.text)
    -- Toujours au pluriel, jamais "(s)" (2026-08-21, demande explicite -- "je
    -- déteste ça... il faut toujours choisir la version pluriel, quitte à
    -- écrire des erreurs comme '1 chevaux'") : accepte l'accord fautif à 1
    -- combat plutôt que la parenthèse.
    UI.text("Le run s'arrête après " .. combats_won_text(controller) .. " combats remportés.", 0, UI.H / 2, UI.W, 12, Theme.muted)
    UI.draw_menu_style_button(View.overlay_restart_button)
    UI.draw_menu_style_button(View.overlay_menu_button)
  end

  -- Rendu des cartes de draft (écran de victoire), REGROUPÉ (2026-09-02) sous
  -- une seule locale de chunk `DraftFx` -- héritage de la limite des 200
  -- locales de l'ex-monolithe (non pertinente dans ce fichier séparé, gardé
  -- par cohérence). `DraftFx.front(def)` : extrait du rendu jusque-là inline
  -- de l'écran de victoire, réutilisé par `.fading` (cartes non choisies,
  -- "disparaissent doucement") ET `.flight` (carte choisie, "rejoint la
  -- pioche dans un mouvement ample").
  local DraftFx
  do
    local W, H = 130, 190
    local fade_canvas

    local function front(def)
      local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
      UI.panel(0, 0, W, H, palette.bg)
      UI.set(def.tier == "avance" and Theme.accent or Theme.black)
      love.graphics.setLineWidth(def.tier == "avance" and 3 or 2)
      love.graphics.rectangle("line", 0, 0, W, H, 10, 10)
      UI.set(palette.border)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", 3, 3, W - 6, H - 6, 8, 8)
      love.graphics.setLineWidth(1)
      UI.set(Theme.energy); love.graphics.circle("fill", 16, 14, 10)
      UI.set(Theme.bg); love.graphics.setFont(Fonts.get(12)); love.graphics.printf(tostring(def.cost), 6, 7, 20, "center")
      if def.mana_cost then
        UI.set(Theme.mana); love.graphics.circle("fill", 38, 14, 9)
        UI.set(Theme.bg); love.graphics.setFont(Fonts.get(11))
        love.graphics.printf(tostring(def.mana_cost), 30, 9, 16, "center")
      end
      if def.corruption_cost_cap then
        UI.set(Theme.corruption); love.graphics.ellipse("fill", 46, 14, 20, 10)
        UI.set(Theme.bg); love.graphics.setFont(Fonts.get(10))
        love.graphics.printf("X(0-" .. def.corruption_cost_cap .. ")", 26, 9, 40, "center")
      end
      UI.name_badge(def.name, 4, 26, W - 8, 16, palette.border, Theme.bg, 2, 2)
      RichText.draw(def.desc, 4, 50, W - 8, 11, Theme.muted)
      local hero_name = Heroes.class_name[def.class_id]
      if hero_name then
        UI.set(Theme.black, 0.55)
        love.graphics.rectangle("fill", 0, H - 20, W, 16)
        UI.text(hero_name, 0, H - 18, W, 12, palette.border, "center")
      end
    end

    -- Fondu d'une carte NON choisie (2026-09-02, demande explicite) : rendue
    -- sur un canvas dédié pour appliquer le fondu d'un coup, canvas séparé de
    -- UI.card_flight_canvas (taille différente, W/H plutôt que CARD_W/CARD_H).
    local function fading(def, r, alpha)
      if alpha <= 0 then return end
      fade_canvas = fade_canvas or love.graphics.newCanvas(W, H)
      love.graphics.push()
      love.graphics.origin()
      local prev_canvas = love.graphics.getCanvas()
      love.graphics.setCanvas(fade_canvas)
      love.graphics.clear(0, 0, 0, 0)
      front(def)
      love.graphics.setCanvas(prev_canvas)
      love.graphics.pop()
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(fade_canvas, r.x, r.y, 0, r.w / W, r.h / H)
      love.graphics.setColor(1, 1, 1, 1)
    end

    -- Vol "ample" de la carte CHOISIE vers la pioche (2026-09-02, demande
    -- explicite) : arc de Bézier quadratique -- point de contrôle remonté
    -- nettement au-dessus du segment départ->arrivée pour un vrai arc
    -- "ample". Rétrécit en même temps jusqu'à la taille de la pioche
    -- (View.deck_pile_rect, combat.lua) -- alpha JAMAIS réduit (contrairement
    -- à `fading` ci-dessus) : elle REJOINT la pioche, elle ne s'efface pas.
    local ARC_HEIGHT = 140
    local function flight(def, from, anim)
      local p = math.min(1, anim.t / anim.duration)
      local ease = 1 - (1 - p) * (1 - p) -- easeOutQuad
      local to = View.deck_pile_rect
      local x0, y0 = from.x + from.w / 2, from.y + from.h / 2
      local x1, y1 = to.x + to.w / 2, to.y + to.h / 2
      local cx = (x0 + x1) / 2
      local cy = math.min(y0, y1) - ARC_HEIGHT
      local mt = 1 - ease
      local x = mt * mt * x0 + 2 * mt * ease * cx + ease * ease * x1
      local y = mt * mt * y0 + 2 * mt * ease * cy + ease * ease * y1
      local w = from.w + (to.w - from.w) * ease
      local h = from.h + (to.h - from.h) * ease
      love.graphics.push()
      love.graphics.translate(x, y)
      love.graphics.scale(w / W, h / H)
      love.graphics.translate(-W / 2, -H / 2)
      front(def)
      love.graphics.pop()
    end

    DraftFx = { w = W, h = H, front = front, fading = fading, flight = flight }
  end

  -- Pièces d'or de l'écran de victoire (2026-09-02, demande explicite) : même
  -- idiome que draw_card_flights (combat.lua) -- interpolation pure, aucune
  -- logique de jeu ici (controller.coin_anims peuplé par
  -- Controller:click_victory_gold).
  local function draw_coin_flights(controller)
    local icon = Sprites.keyword("or")
    if not icon then return end
    for _, a in ipairs(controller.coin_anims) do
      if a.elapsed >= a.delay then
        local p = math.min(1, (a.elapsed - a.delay) / a.duration)
        local ease = 1 - (1 - p) ^ 2 -- easeOutQuad, même famille que le vol de carte
        local fx, fy = a.from.x + a.from.w / 2, a.from.y + a.from.h / 2
        local tx, ty = a.to.x + a.to.w / 2, a.to.y + a.to.h / 2
        local x = fx + (tx - fx) * ease
        local y = fy + (ty - fy) * ease
        love.graphics.setColor(1, 1, 1, 1)
        Sprites.draw_centered(icon, x, y, 12)
      end
    end
  end
  View.draw_coin_flights = draw_coin_flights

  -- Bourse rejouée PAR-DESSUS le voile noir de l'écran de victoire (2026-09-02,
  -- demande explicite) : draw_gold_display (combat.lua, dessinée sous le
  -- voile) reste TELLE QUELLE -- ceci est un second rendu, indépendant, au
  -- MÊME endroit (View.gold_display_rect), déclenché par
  -- controller.gold_purse_overlay.
  local function draw_gold_purse_overlay(controller)
    local a = controller.gold_purse_overlay
    if not a then return end
    local r = View.gold_display_rect
    local pop_p = math.min(1, a.pop_t / a.pop_duration)
    local scale = 1 + 0.4 * (1 - pop_p)
    local alpha = a.fade_t and math.max(0, 1 - a.fade_t / a.fade_duration) or 1
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2

    UI.set(Theme.gold, 0.3 * alpha)
    love.graphics.circle("fill", r.x + 7, cy, 20 * scale)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)
    local icon = Sprites.keyword("or")
    if icon then
      love.graphics.setColor(1, 1, 1, alpha)
      Sprites.draw_centered(icon, r.x + 7, r.y + 7, 7)
    end
    love.graphics.setFont(Fonts.get(9))
    UI.set(Theme.gold, alpha)
    love.graphics.printf(tostring(controller.state.gold), r.x + 18, r.y, r.w - 18, "left")
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
  end
  View.draw_gold_purse_overlay = draw_gold_purse_overlay

  -- y=160->320 (2026-09-02, demande explicite -- écran de victoire à gains
  -- détachés) : la rangée de 3 cartes du draft n'apparaît qu'APRÈS un clic
  -- explicite sur le gain "carte".
  function View.draft_rects(controller)
    if not controller.draft_picks or not controller.draft_cards_shown then return {} end
    return UI.centered_row(#controller.draft_picks, DraftFx.w, DraftFx.h, 320, 24)
  end

  -- "Ne rien prendre" (2026-08-30, demande explicite) : sous la rangée de
  -- cartes -- position fixe, ne dépend pas du nombre de cartes proposées.
  View.draft_skip_button = { x = UI.W / 2 - 100, y = 530, w = 200, h = 44, label = "Ne rien prendre" }

  -- Écran de victoire à gains détachés (2026-09-02, demande explicite) : les 2
  -- gains (PO/carte) forment une paire fixe, l'un à côté de l'autre, QUEL QUE
  -- SOIT l'état de collecte de chacun.
  local victory_gain_rects = UI.centered_row(2, 180, 160, 130, 40)
  View.victory_gold_rect = victory_gain_rects[1]
  View.victory_card_rect = victory_gain_rects[2]

  -- "Continuer" (2026-09-02, demande explicite) : sous la rangée de cartes/le
  -- bouton "Ne rien prendre".
  View.victory_continue_button = { x = UI.W / 2 - 100, y = 610, w = 200, h = 44, label = "Continuer" }

  --- Écran de victoire (combat normal, PAS boss -- voir draw_boss_victory
  -- plus bas pour ce cas) : titre en zoom + bump, gains PO/carte détachés
  -- (cliquables indépendamment), puis la rangée de draft une fois le gain
  -- "carte" cliqué.
  function View.draw_victory_overlay(controller)
    local state = controller.state
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)

    -- Titre "Victoire !" en zoom + bump (2026-08-08) : seul élément affiché au
    -- tout début de l'écran, avant même que les gains n'existent visuellement.
    local va = controller.victory_anim
    local title_scale = va and UI.ease_out_back(va.t, controller.victory_title_duration) or 1
    love.graphics.push()
    love.graphics.translate(UI.W / 2, 72)
    love.graphics.scale(title_scale, title_scale)
    love.graphics.translate(-UI.W / 2, -72)
    UI.text("Victoire !", 0, 60, UI.W, 24, Theme.text)
    love.graphics.pop()

    if controller.victory_gains_shown then
      UI.text("Combat " .. (state.run.combat_index) .. " remporté ! Récupère tes gains.", 0, 92, UI.W, 12, Theme.muted)

      -- Gain "PO" (2026-09-02, demande explicite) : cliquable tant que non
      -- collecté -- voir Controller:click_victory_gold pour le vol de pièces.
      local gr = View.victory_gold_rect
      UI.panel(gr.x, gr.y, gr.w, gr.h, Theme.panel_light)
      UI.set(controller.victory_gold_collected and Theme.muted or Theme.gold)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", gr.x, gr.y, gr.w, gr.h, 10, 10)
      love.graphics.setLineWidth(1)
      if controller.victory_gold_collected then
        UI.text("Récupéré", gr.x, gr.y + gr.h / 2 - 6, gr.w, 12, Theme.muted, "center")
      else
        local coin_icon = Sprites.keyword("or")
        if coin_icon then
          love.graphics.setColor(1, 1, 1, 1)
          Sprites.draw_centered(coin_icon, gr.x + gr.w / 2, gr.y + 46, 28)
        end
        UI.text("+" .. controller.victory_gold_reward .. " PO", gr.x, gr.y + 92, gr.w, 16, Theme.gold, "center")
      end

      -- Gain "carte" (2026-09-02, demande explicite) : icône de carte avec un
      -- "?", clic lance le draft existant -- voir Controller:click_victory_card.
      local cr = View.victory_card_rect
      UI.panel(cr.x, cr.y, cr.w, cr.h, Theme.panel_light)
      UI.set(controller.victory_card_collected and Theme.muted or Theme.accent)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", cr.x, cr.y, cr.w, cr.h, 10, 10)
      love.graphics.setLineWidth(1)
      if controller.victory_card_collected then
        UI.text("Récupérée", cr.x, cr.y + cr.h / 2 - 6, cr.w, 12, Theme.muted, "center")
      elseif controller.draft_picks then
        UI.text("Choisis une carte\nci-dessous…", cr.x, cr.y + cr.h / 2 - 14, cr.w, 22, Theme.muted, "center")
      else
        UI.text("?", cr.x, cr.y + cr.h / 2 - 22, cr.w, 32, Theme.text, "center")
        UI.text("Nouvelle carte", cr.x, cr.y + cr.h - 26, cr.w, 12, Theme.muted, "center")
      end
    end

    if controller.draft_picks and controller.draft_cards_shown then
      local rects = View.draft_rects(controller)
      local choice_anim = controller.draft_choice_anim
      for i, def in ipairs(controller.draft_picks) do
        local r = rects[i]
        if choice_anim and choice_anim.chosen_index == i then
          -- Carte choisie (2026-09-02, demande explicite) : dessinée à part,
          -- voir DraftFx.flight -- ni le retournement ni le fondu ci-dessous
          -- ne s'appliquent à elle.
          DraftFx.flight(def, r, choice_anim)
        elseif choice_anim then
          -- Cartes NON choisies (2026-09-02, demande explicite) : fondu, voir
          -- DraftFx.fading -- restent immobiles à leur rect de repos, seule
          -- leur opacité change.
          local fp = math.min(1, choice_anim.t / choice_anim.other_fade_duration)
          DraftFx.fading(def, r, 1 - fp)
        else
          -- Retournement carte par carte (2026-08-08) : sans anim
          -- (draft_flip[i] absent), la carte reste face cachée -- une fois
          -- démarrée, on l'aplatit horizontalement et on bascule le contenu
          -- dos/face exactement à mi-course (la carte "sur la tranche").
          local f = controller.draft_flip[i]
          local sx = f and UI.flip_scale_x(f.t, controller.draft_flip_duration) or 1
          local show_front = f and (f.t / controller.draft_flip_duration) >= 0.5
          love.graphics.push()
          love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
          love.graphics.scale(sx, 1)
          love.graphics.translate(-r.w / 2, -r.h / 2)
          if show_front then
            DraftFx.front(def)
          else
            UI.panel(0, 0, r.w, r.h, Theme.panel_light)
            UI.text("?", 0, r.h / 2 - 12, r.w, 26, Theme.muted)
          end
          love.graphics.pop()
        end
      end

      -- "Ne rien prendre" (2026-08-30, demande explicite) : sous la rangée de
      -- cartes. Masqué pendant le vol de la carte choisie (2026-09-02).
      if not choice_anim then
        local sb = View.draft_skip_button
        UI.set(Theme.panel_light); love.graphics.rectangle("fill", sb.x, sb.y, sb.w, sb.h, 8, 8)
        UI.set(Theme.muted); love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sb.x, sb.y, sb.w, sb.h, 8, 8)
        love.graphics.setLineWidth(1)
        UI.text(sb.label, sb.x, sb.y + 14, sb.w, 14, Theme.text, "center")
      end
    end

    -- "Continuer" (2026-09-02, demande explicite -- "un bouton continuer
    -- grisé non clicable" jusqu'à récupération des 2 gains) : SIBLING du bloc
    -- draft_picks ci-dessus, PAS nichée dedans -- doit rester visible/actif
    -- que draft_picks soit peuplé ou non, tant que victory_gains_shown est vrai.
    if controller.victory_gains_shown then
      local cb = View.victory_continue_button
      local can_continue = controller.victory_gold_collected and controller.victory_card_collected
      UI.set(can_continue and Theme.accent or Theme.panel_light)
      love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
      UI.set(Theme.muted); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
      love.graphics.setLineWidth(1)
      UI.text(cb.label, cb.x, cb.y + 14, cb.w, 14, can_continue and Theme.bg or Theme.muted, "center")
    end
  end

  -- Victoire sur le boss (2026-08-21, demande explicite -- "il faut enlever le
  -- draft de carte et le feu de camp après le boss") : ni draft ni feu de camp
  -- après ce combat-là, juste ce bref titre avant le retour automatique au
  -- menu (Controller:enter_boss_victory).
  local function draw_boss_victory(controller)
    Background.draw(nil, UI.W, UI.H)
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    local va = controller.victory_anim
    local title_scale = va and UI.ease_out_back(va.t, controller.victory_title_duration) or 1
    love.graphics.push()
    love.graphics.translate(UI.W / 2, UI.H / 2 - 20)
    love.graphics.scale(title_scale, title_scale)
    love.graphics.translate(-UI.W / 2, -(UI.H / 2 - 20))
    UI.text("Victoire !", 0, UI.H / 2 - 32, UI.W, 24, Theme.text)
    love.graphics.pop()
    -- "Run Solo" (2026-09-02, demande explicite) : partage cet écran avec
    -- "Tester un boss" -- sous-titre adapté au mode, jamais "Boss" pour un
    -- simple combat aléatoire à 1 aventurier.
    local subtitle = controller.run_mode == "solo_test" and "Combat remporté !" or "Le Boss est vaincu !"
    UI.text(subtitle, 0, UI.H / 2 + 10, UI.W, 14, Theme.muted)
  end
  View.draw_boss_victory = draw_boss_victory
end
