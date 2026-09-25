-- Écran "Feu de camp" (2026-09-25, extrait de l'ex-monolithe view.lua --
-- voir src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Combat = require("src.rules.combat")

return function(View, UI)
  local CAMPFIRE_HERO_W, CAMPFIRE_HERO_H = 170, 240
  local CAMPFIRE_HERO_Y = 260 -- 240->260 (2026-08-31, passage 1280x720)

  function View.campfire_hero_rects(controller)
    local rects = UI.centered_row(#controller.state.heroes, CAMPFIRE_HERO_W, CAMPFIRE_HERO_H, CAMPFIRE_HERO_Y)
    local out = {}
    for i, h in ipairs(controller.state.heroes) do out[h.id] = rects[i] end
    return out
  end

  --- Écran "Feu de camp" (2026-08-30, remis en place, refonte -- demande
  -- explicite : "pas d'options autre que le soin, le joueur choisit parmi ses
  -- 4 aventuriers lequel va se faire soigner de 30% de ses PV max") : une
  -- rangée de 4 cadres cliquables, chacun affiche le montant EXACT qu'il
  -- recevrait (déjà plafonné à max_hp, même calcul que Controller:
  -- choose_campfire_hero -- ne peuvent jamais diverger) -- cliquer résout
  -- directement, pas de bouton "Confirmer" séparé.
  local function draw_campfire(controller)
    local cf = controller.campfire
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.draw_camp_entrance(controller, "Feu de camp", 60, function()
    UI.text("Choisis l'aventurier à soigner (30% de ses PV max).", 0, 92, UI.W, 12, Theme.muted)

    local rects = View.campfire_hero_rects(controller)
    for _, h in ipairs(controller.state.heroes) do
      local r = rects[h.id]
      local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
      -- Mort définitive (2026-09-25, pilier du sacrifice -- "les personnages
      -- morts... doivent rester morts", voir Controller:choose_campfire_hero --
      -- la résurrection ici n'était pas un bug, c'est un ancien comportement
      -- voulu devenu obsolète) : un aventurier mort n'est plus une cible valide
      -- ici -- cadre grisé
      -- (Theme.muted/Theme.panel, même convention que Temple.eligible_heroes/
      -- draw_temple) plutôt que sa couleur de classe, et "Mort" au lieu d'une
      -- prévision de soin qui ne se produira jamais.
      local dead = h.hp <= 0
      UI.panel(r.x, r.y, r.w, r.h, dead and Theme.panel or Theme.panel_light)
      -- Couleur personnelle de l'aventurier (2026-08-30, bug signalé -- "les
      -- contours des aventuriers sont tous de la même couleur avant sélection,
      -- il faut qu'ils gardent leur couleur personnelle") : avant, Theme.heal
      -- fixe pour les 4 -- remplacé par palette.border (même couleur que sur sa
      -- carte/son nom, voir Theme.card_class), qui les distingue à nouveau.
      UI.set(dead and Theme.muted or palette.border); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
      love.graphics.setLineWidth(1)
      -- 70->140 (2026-09-22, demande explicite -- "les aventuriers doivent
      -- être plus gros, presque le double") : tout ce qui suit décalé de +70,
      -- voir CAMPFIRE_HERO_H ci-dessus (panneau agrandi d'autant).
      local portrait_size = 140
      UI.draw_class_icon(h.class_id, h.icon, h.label, r.x + (r.w - portrait_size) / 2, r.y + 14, portrait_size, portrait_size, dead and Theme.muted or Theme.text)
      UI.name_badge(h.name, r.x + 8, r.y + 160, r.w - 16, 12, dead and Theme.muted or palette.border, Theme.bg, 2, 3)
      -- Barre de PV normale, comme en combat (2026-08-30, bug signalé --
      -- "il faut ajouter les barres de vie normale") : remplace le simple
      -- texte "X/Y PV" -- même hp_bar/traînée qu'en combat (voir
      -- Controller:advance_trail), donc le soin (Combat.grant_heal, appelé au
      -- clic -- voir Controller:choose_campfire_hero) se voit désormais monter
      -- doucement ici aussi, gratuitement (même mécanisme partagé).
      UI.hp_bar(r.x + 8, r.y + 176, r.w - 16, 16, h.hp / h.max_hp, (controller.hp_trail[h.id] or h.hp) / h.max_hp, Theme.hp)
      UI.text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp .. " PV", r.x, r.y + 176, r.w, 16, 10, Theme.text)
      if dead then
        UI.text("Mort", r.x, r.y + 198, r.w, 13, Theme.muted, "center")
      else
        local healed = math.min(h.max_hp, h.hp + Combat.round(h.max_hp * 0.30)) - h.hp
        UI.text("+" .. healed .. " PV", r.x, r.y + 198, r.w, 13, Theme.heal, "center")
      end
    end
    end)
  end
  View.draw_campfire = draw_campfire
end
