-- Écran "Le Temple" (2026-09-25, extrait de l'ex-monolithe view.lua -- voir
-- src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Icons = require("src.ui.icons")
local Temple = require("src.rules.temple")

return function(View, UI)
  -- Écran "Le Temple" (2026-08-29, refonte complète -- demande explicite) :
  -- jusqu'à 3 statues d'effet EN LIGNE au-dessus des 4 aventuriers (toujours
  -- les 4, jamais recalculé selon l'éligibilité -- un aventurier mort ou déjà
  -- porteur reste affiché, juste grisé/non cliquable, voir draw_temple/
  -- Controller:choose_temple_hero). Aucun "Passer" sur cet écran (choix
  -- obligatoire) -- un bouton "Confirmer" à la place, actif seulement quand
  -- aventurier ET effet sont choisis (voir Controller:confirm_temple_choice).
  local TEMPLE_EFFECT_W, TEMPLE_EFFECT_H = 140, 150
  local TEMPLE_EFFECT_Y = 120 -- 108->120 (2026-08-31, passage 1280x720)
  local TEMPLE_EFFECT_GAP = 30
  function View.temple_effect_rects(controller)
    local t = controller.temple
    if not t then return {} end
    return UI.centered_row(#t.choices, TEMPLE_EFFECT_W, TEMPLE_EFFECT_H, TEMPLE_EFFECT_Y, TEMPLE_EFFECT_GAP)
  end

  -- 136->144 (2026-09-02, bug signalé -- "les PV des aventuriers ne sont pas
  -- indiqués du tout, il faut tout montrer") : la carte n'affichait ni PV ni le
  -- NOM de la bénédiction/malédiction déjà portée (seulement une pastille de
  -- couleur, jamais lisible sans survoler) -- portrait réduit (70->58) pour
  -- faire de la place à une barre de PV (même idiome que draw_hero) et jusqu'à
  -- 2 lignes de statut (bénédiction/malédiction déjà portées), voir draw_temple.
  -- 130x144 -> 150x198 (2026-09-22, portraits agrandis -- portrait_size
  -- 58->112, voir draw_temple) : TEMPLE_HERO_Y inchangé, marge suffisante des
  -- 2 côtés (rangée de statues d'effet au-dessus s'arrête bien avant,
  -- View.temple_confirm_button suit automatiquement en dessous).
  local TEMPLE_HERO_W, TEMPLE_HERO_H = 150, 198
  local TEMPLE_HERO_Y = 320 -- 300->320 (2026-08-31, passage 1280x720)
  function View.temple_hero_rects(controller)
    local rects = UI.centered_row(#controller.state.heroes, TEMPLE_HERO_W, TEMPLE_HERO_H, TEMPLE_HERO_Y)
    local out = {}
    for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
    return out
  end
  View.temple_confirm_button = {
    x = UI.W / 2 - 100, y = TEMPLE_HERO_Y + TEMPLE_HERO_H + 20, w = 200, h = 44, label = "Confirmer",
  }

  local function draw_temple(controller)
    local t = controller.temple
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    local type_label = t.type == "blessing" and "bénédiction" or "malédiction"
    local icon_key = t.type == "blessing" and "temple_blessing" or "temple_curse"
    UI.draw_camp_entrance(controller, "Le Temple", 26, function()

    local anim = controller.temple_choice_anim
    local effect_rects = View.temple_effect_rects(controller)
    for i, effect in ipairs(t.choices) do
      local r = effect_rects[i]
      local color = UI.TEMPLE_STATUE_COLORS[effect.color] or Theme.accent
      local selected = t.chosen_effect_index == i
      local alpha = 1
      if anim and anim.chosen_index ~= i then
        local p = math.min(1, anim.t / (controller.temple_choice_anim_duration or 1))
        alpha = 1 - p
      end
      if alpha > 0 then
        UI.set(Theme.panel_light, alpha)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
        UI.set(selected and Theme.accent or color, alpha)
        love.graphics.setLineWidth(selected and 4 or 2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
        love.graphics.setLineWidth(1)
        Icons.draw_status(icon_key, r.x + r.w / 2, r.y + 55, 38, color, alpha)
        UI.set(Theme.text, alpha)
        UI.text(effect.name, r.x + 4, r.y + r.h - 28, r.w - 8, 12, Theme.text)
        if not anim then
          love.graphics.push()
          love.graphics.translate(r.x, r.y)
          UI.draw_tooltip_hint(r.w, r.h, Theme.text)
          love.graphics.pop()
        end
      end
    end

    if anim then
      local hero
      for _, h in ipairs(t.eligible) do if h.id == t.chosen_hero_id then hero = h end end
      UI.text("Bonne chance, " .. (hero and hero.name or "?") .. " !", 0, TEMPLE_EFFECT_Y + TEMPLE_EFFECT_H + 14, UI.W, 13, Theme.accent)
    else
      UI.text("Choisis l'élu de cette " .. type_label .. " !", 0, TEMPLE_EFFECT_Y + TEMPLE_EFFECT_H + 14, UI.W, 12, Theme.muted)
    end

    local hero_rects = View.temple_hero_rects(controller)
    for _, h in ipairs(controller.state.heroes) do
      local r = hero_rects[h.id]
      local eligible = false
      for _, e in ipairs(t.eligible) do if e.id == h.id then eligible = true end end
      local selected = t.chosen_hero_id == h.id
      -- Aventuriers NON choisis s'effacent aussi (2026-08-30, demande explicite
      -- -- avant, seules les statues non choisies s'effaçaient) : même fondu
      -- que les statues, sur la même durée -- l'aventurier choisi, lui, reste
      -- pleinement visible (c'est lui qui reçoit l'effet).
      local hero_alpha = 1
      if anim and t.chosen_hero_id ~= h.id then
        hero_alpha = 1 - math.min(1, anim.t / (controller.temple_choice_anim_duration or 1))
      end
      if hero_alpha > 0 then
        local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
        UI.panel(r.x, r.y, r.w, r.h, eligible and Theme.panel_light or Theme.panel, hero_alpha)
        -- Couleur personnelle avant sélection (2026-08-30, bug signalé -- même
        -- correctif que draw_campfire/draw_refuge) : un aventurier ÉLIGIBLE
        -- mais pas encore choisi gardait quand même le contour or de
        -- Theme.accent (identique pour les 4), au lieu de sa propre couleur de
        -- classe -- l'or reste réservé à celui réellement sélectionné, pour que
        -- "or" continue de signifier "choisi", sans plus rien retirer aux
        -- autres.
        UI.set(selected and Theme.accent or (eligible and palette.border or Theme.muted), hero_alpha)
        love.graphics.setLineWidth(selected and 4 or 2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
        love.graphics.setLineWidth(1)
        -- 58->112 (2026-09-22, demande explicite -- "les aventuriers doivent
        -- être plus gros, presque le double") : tout ce qui suit décalé de
        -- +54, voir TEMPLE_HERO_H ci-dessus (panneau agrandi d'autant).
        local portrait_size = 112
        UI.draw_class_icon(h.class_id, h.icon, h.label,
          r.x + (r.w - portrait_size) / 2, r.y + 8, portrait_size, portrait_size,
          eligible and Theme.text or Theme.muted, hero_alpha)
        -- PV (2026-09-02, bug signalé -- "les PV des aventuriers ne sont pas
        -- indiqués du tout, il faut tout montrer") : absent jusqu'ici de cet
        -- écran -- même idiome que draw_hero (barre + valeur dedans), juste
        -- sous le portrait rétréci (70->58 pour lui faire de la place).
        UI.hp_bar(r.x + 6, r.y + 122, r.w - 12, 14, h.hp / h.max_hp, h.hp / h.max_hp, Theme.hp)
        UI.text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp, r.x, r.y + 122, r.w, 14, 9, Theme.text)
        UI.name_badge(h.name, r.x + 8, r.y + 140, r.w - 16, 12, palette.border, Theme.bg, 2, 3)
        -- Bénédiction/malédiction déjà portées, EN TOUTES LETTRES (2026-09-02,
        -- demande explicite -- "les bénédictions/malédictions, et tout autre
        -- statut que le joueur doit connaitre pour faire son choix") : avant,
        -- rien ne le montrait sur cet écran (aucun badge, aucun nom) -- seul un
        -- texte vague "Déjà béni/maudit" apparaissait, et seulement quand ça
        -- rendait le héros inéligible pour CE tirage. Affiche désormais le NOM
        -- de chacun dans TOUS les cas (un aventurier déjà béni reste un choix
        -- valide pour une malédiction, et inversement -- le joueur doit pouvoir
        -- le voir même quand ça ne le rend pas inéligible), coloré comme la
        -- statue correspondante (TEMPLE_STATUE_COLORS, même code couleur que
        -- draw_hero) -- description complète toujours réservée à l'infobulle
        -- (tooltip_lines), pas dupliquée ici.
        if h.hp <= 0 then
          UI.text("Mort", r.x, r.y + 154, r.w, 11, Theme.muted)
        else
          local status_y = r.y + 154
          if h.blessing then
            local blessing = Temple.by_id(h.blessing)
            if blessing then
              UI.text(blessing.name, r.x + 2, status_y, r.w - 4, 11, UI.TEMPLE_STATUE_COLORS[blessing.color] or Theme.heal)
              status_y = status_y + 13
            end
          end
          if h.curse then
            local curse = Temple.by_id(h.curse)
            if curse then
              UI.text(curse.name, r.x + 2, status_y, r.w - 4, 11, UI.TEMPLE_STATUE_COLORS[curse.color] or Theme.hp)
            end
          end
        end
        -- "?" manquant (2026-08-30, bug signalé -- "pour les aventuriers, il
        -- n'y a pas le '?' ni les info bulles") : la rangée de statues juste
        -- au-dessus en a un (voir plus haut, draw_tooltip_hint), jamais posé
        -- ici -- Input.mousemoved fait pourtant déjà de chaque portrait une
        -- vraie cible de survol (kind "hero", voir son commentaire), seul le
        -- rendu du hint manquait. Même garde `not anim` que les statues :
        -- plus de survol/tooltip une fois la fusion lancée.
        if not anim then
          love.graphics.push()
          love.graphics.translate(r.x, r.y)
          UI.draw_tooltip_hint(r.w, r.h, Theme.text)
          love.graphics.pop()
        end
      end
    end

    -- Fusion (2026-08-30, demande explicite -- "les 2 choix s'alignent puis
    -- fusionnent, pour montrer que l'aventurier a reçu la bénédiction/
    -- malédiction") : une COPIE de l'icône de l'effet choisi voyage de sa
    -- statue jusqu'au portrait de l'aventurier choisi, en rétrécissant, PUIS
    -- une brève lueur de la couleur de l'effet marque l'"impact" une fois
    -- arrivée -- la statue/le panneau d'origine restent statiques et lisibles
    -- (on garde "quel effet a été choisi" affiché), seule cette copie bouge.
    if anim then
      local chosen_effect = t.choices[anim.chosen_index]
      local statue_r = effect_rects[anim.chosen_index]
      local hero_r = hero_rects[t.chosen_hero_id]
      if chosen_effect and statue_r and hero_r then
        local duration = controller.temple_choice_anim_duration or 1
        local p = math.min(1, anim.t / duration)
        local color = UI.TEMPLE_STATUE_COLORS[chosen_effect.color] or Theme.accent
        if p < 1 then
          local ease = p * p -- accélère vers la fusion (easeInQuad -- "aspiré" par l'aventurier)
          local from_cx, from_cy = statue_r.x + statue_r.w / 2, statue_r.y + 55
          local to_cx, to_cy = hero_r.x + hero_r.w / 2, hero_r.y + hero_r.h / 2
          local cx = from_cx + (to_cx - from_cx) * ease
          local cy = from_cy + (to_cy - from_cy) * ease
          local scale = 1 - 0.7 * ease
          -- Ne commence à s'estomper que sur le dernier tiers du trajet
          -- (absorption progressive à l'arrivée, pas un simple fondu linéaire
          -- sur tout le vol).
          local travel_alpha = p < 0.7 and 1 or (1 - (p - 0.7) / 0.3)
          Icons.draw_status(icon_key, cx, cy, 38 * math.max(0.1, scale), color, travel_alpha)
        else
          -- Lueur d'impact (2026-08-30) : brève, indépendante de la durée
          -- totale de la pause -- juste de quoi marquer "c'est arrivé", pas
          -- besoin qu'elle dure tout le temps où "Bonne chance" reste affiché.
          local GLOW_DURATION = 0.4
          local glow_t = anim.t - duration
          if glow_t < GLOW_DURATION then
            local glow_alpha = 1 - glow_t / GLOW_DURATION
            local to_cx, to_cy = hero_r.x + hero_r.w / 2, hero_r.y + hero_r.h / 2
            UI.set(color, glow_alpha * 0.6)
            love.graphics.circle("fill", to_cx, to_cy, hero_r.w * 0.6 * (1 + 0.3 * (1 - glow_alpha)))
          end
        end
      end
    end

    if not anim then
      local b = View.temple_confirm_button
      local can_confirm = t.chosen_effect_index and t.chosen_hero_id
      UI.set(can_confirm and Theme.accent or Theme.panel_light)
      love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
      UI.text(b.label, b.x, b.y + 14, b.w, 14, can_confirm and Theme.bg or Theme.muted)
    end
    end)
  end
  View.draw_temple = draw_temple
end
