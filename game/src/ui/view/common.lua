-- Primitives d'affichage génériques, sans aucun état d'écran particulier --
-- partagées par tous les fichiers de src/ui/view/ (2026-09-25, découpage de
-- l'ex-monolithe view.lua -- voir le commentaire en tête de
-- src/ui/view/init.lua pour le contexte complet). Un seul chargement réel
-- (Lua met les modules en cache), donc `UI.card_flight_canvas` est un vrai
-- état PARTAGÉ entre tous les écrans qui le lisent/l'écrivent (combat, forge,
-- choix de boss, "Voir le deck"), exactement comme avant le découpage.

local Theme = require("src.ui.theme")
local Fonts = require("src.ui.fonts")
local Icons = require("src.ui.icons")
local SIZE = require("src.ui.logical_size")

local UI = {}

UI.W, UI.H = SIZE.W, SIZE.H

-- 92x138 -> 102x153 -> 122x184 (2026-09-12, demande explicite -- faire de la
-- place à une illustration par carte, "la chose la plus claire et la plus
-- importante à voir" sans nuire à la lisibilité du texte). Puis +20% explicite
-- (même session, 2ᵉ demande) : 102*1.2=122.4, 153*1.2=183.6, arrondis -- même
-- ratio que toujours (2/3). La main utilise directement CARD_W/CARD_H comme
-- tout le reste (voir HAND_Y dans view/combat.lua).
UI.CARD_W, UI.CARD_H = 122, 184

-- Canvas réutilisé pour toutes les cartes dessinées à une taille différente de
-- leur taille canonique (CARD_W/CARD_H) -- vol de carte, pile pioche/défausse,
-- deck-view, grille du deck-builder : dessiné une fois à CARD_W/CARD_H
-- (police/proportions inchangées), puis reposé à l'échelle voulue via
-- `love.graphics.draw(canvas, x, y, 0, w/CARD_W, h/CARD_H)`. Champ de UI
-- (plutôt qu'une locale de fichier) : plusieurs fichiers d'écran se le
-- partagent et doivent voir la même instance une fois créée par le premier
-- appelant.
UI.card_flight_canvas = nil

-- 12->16 (2026-08-31, passage 1280x720) : léger surplus d'air horizontal entre
-- portraits/cartes en rangée, sans forcer UNIT_W/CARD_W à grandir eux-mêmes
-- (le fond animé -- voir Background.draw, déjà paramétrique sur W/H -- occupe
-- naturellement les marges latérales plus généreuses à 1280 de large).
UI.ROW_GAP = 16

--- Rangée centrée horizontalement de `count` items `item_w`x`item_h`, à `y`,
-- espacés de `gap` (par défaut UI.ROW_GAP). Utilisée par le calcul de rects de
-- quasiment tous les écrans (ennemis/héros, main, Forge, Temple, feu de camp/
-- refuge, choix d'équipe, draft, victoire).
function UI.centered_row(count, item_w, item_h, y, gap)
  gap = gap or UI.ROW_GAP
  local total = count * item_w + math.max(0, count - 1) * gap
  local x0 = (UI.W - total) / 2
  local rects = {}
  for i = 1, count do
    rects[i] = { x = x0 + (i - 1) * (item_w + gap), y = y, w = item_w, h = item_h }
  end
  return rects
end

function UI.point_in(r, x, y)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- ---------- petites aides de dessin ----------

function UI.set(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

--- Interpole RGB entre 2 couleurs (2026-08-30, mort d'un héros -- voir
-- draw_hero/self.hero_death_fade) : `t` = 0 -> `a`, `t` = 1 -> `b`.
function UI.lerp_color(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- `alpha` (optionnel, 2026-08-30, Temple -- fondu des aventuriers non
-- choisis) : par défaut 1, tous les appels existants restent inchangés.
function UI.panel(x, y, w, h, color, alpha)
  UI.set(color or Theme.panel, alpha)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
end

function UI.text(str, x, y, w, size, color, align)
  love.graphics.setFont(Fonts.get(size or 14))
  UI.set(color or Theme.text)
  love.graphics.printf(str, x, y, w, align or "center")
end

--- Comme `text`, mais centrée VERTICALEMENT dans une hauteur `h` donnée
-- (2026-08-27, demande explicite -- "les PV numériques doivent être centrés
-- en hauteur") plutôt qu'un décalage `y` choisi à l'œil : lit la vraie
-- hauteur de ligne de la police (Font:getHeight(), pas une valeur supposée
-- égale à `size`) pour un centrage exact quelle que soit la police chargée.
-- `bar_y`/`bar_h` = le rectangle dans lequel centrer (ex. une barre de PV),
-- pas forcément toute la zone où `str` pourrait s'afficher.
function UI.text_v_centered(str, x, bar_y, w, bar_h, size, color)
  local font = Fonts.get(size or 14)
  love.graphics.setFont(font)
  UI.set(color or Theme.text)
  love.graphics.printf(str, x, bar_y + (bar_h - font:getHeight()) / 2, w, "center")
end

--- Nom mis en valeur dans un cadre arrondi de couleur distincte, contour noir compris
-- (2026-08-10, demande explicite) -- aventuriers, ennemis, cartes. `pad` ajoute de la
-- marge verticale autour du texte (le cadre grandit, le texte reste à `size` mais se
-- recentre dedans) -- l'appelant doit alors décaler les éléments qui suivent en
-- conséquence, ces emplacements étant calés au pixel près (voir fonts.lua --
-- BODY_FONT_NATIVE_SIZE).
function UI.name_badge(str, x, y, w, size, bg, text_color, inset, pad)
  inset = inset or 4
  pad = pad or 0
  local bx, bw, bh = x + inset, w - inset * 2, size + pad * 2
  UI.set(bg)
  love.graphics.rectangle("fill", bx, y, bw, bh, 4, 4)
  UI.set(Theme.black)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, y, bw, bh, 4, 4)
  love.graphics.setLineWidth(1)
  UI.text(str, x, y + pad, w, size, text_color, "center")
end

--- Dessine `icon` (un emoji) si une police-icône capable de le rendre a pu
-- être chargée, sinon replie sur `label` (texte simple, toujours lisible).
-- Voir src/ui/fonts.lua — jamais de glyphe manquant/tofu à l'écran.
function UI.icon_text(icon, label, x, y, w, size, color)
  local font = icon and Fonts.icon(size)
  if font then
    local ok, has = pcall(function() return font:hasGlyphs(icon) end)
    if ok and has then
      love.graphics.setFont(font)
      UI.set(color or Theme.text)
      love.graphics.printf(icon, x, y, w, "center")
      return
    end
  end
  UI.text(label or icon or "?", x, y, w, size, color)
end

--- Icône de classe (épée/bouclier/orbe/dague, voir src/ui/icons.lua) centrée
-- dans la zone (x, y, w, size) ; repli sur icon_text si la classe est inconnue.
-- `alpha` (optionnel, 2026-08-30 -- voir Icons.draw_class) : par défaut 1.
function UI.draw_class_icon(class_id, icon, label, x, y, w, size, color, alpha)
  local drawn = Icons.draw_class(class_id, x + w / 2, y + size / 2, size / 2, color or Theme.text, alpha)
  if not drawn then UI.icon_text(icon, label, x, y, w, size, color) end
end

--- Silhouette de l'ennemi (voir src/ui/icons.lua) ; repli sur icon_text/label
-- si le template n'a pas d'icône dessinée (ne devrait pas arriver, les 10
-- types du bestiaire Run Infini sont tous couverts).
function UI.draw_enemy_icon(template_id, icon, label, x, y, w, size, color)
  local drawn = Icons.draw_enemy(template_id, x + w / 2, y + size / 2, size / 2, color or Theme.text)
  if not drawn then UI.icon_text(icon, label, x, y, w, size, color) end
end

-- Rémanence sur l'arrivée d'un badge (2026-08-28, demande explicite --
-- "gros puis scale vers le point d'arrivée avec un effet de rémanence
-- pendant quelques courts instants") : 2 échos fantômes dessinés à une
-- échelle plus grande que l'icône réelle, alpha dégressif, seulement pendant
-- le premier ECHO_WINDOW du pop -- juste assez pour donner une impression de
-- traînée lumineuse qui se resserre, PAS un vrai système de particules (même
-- esprit que draw_particles dans view/combat.lua : simple, à la main).
local STATUS_POP_ECHO_WINDOW = 0.6 -- fraction de pop_duration pendant laquelle les échos existent
local STATUS_POP_ECHO_COUNT = 2

--- Icône de statut (voir src/ui/icons.lua) avec sa valeur numérique à côté
-- (value peut être nil, ex. Camouflage qui n'a pas de compteur) ; repli texte
-- "ABBR valeur" si la clé n'a pas d'icône dessinée. `pop_t`/`pop_duration`
-- (2026-08-09, optionnels) : le badge part agrandi et retombe à sa taille
-- normale pendant `pop_duration` -- signale visuellement qu'il vient d'être
-- appliqué, sans rien changer quand ils sont absents (statut déjà présent).
local function status_badge(status_key, abbr, value, x, y, w, size, color, pop_t, pop_duration)
  local cx, cy = x + size * 0.55, y + size / 2
  local scale = 1
  local p = nil
  -- `pop_t < 0` (2026-08-30, demande explicite -- décalage entre plusieurs
  -- cibles touchées d'un coup, voir Controller:pop_status/react_to_diff) :
  -- l'icône n'a pas encore "son tour", rendue normalement (aucun pop/écho)
  -- jusqu'à ce que `pop_t` atteigne 0 -- jamais un `p` négatif, qui ferait
  -- grossir le badge sans limite au lieu de simplement ne rien animer.
  if pop_t and pop_t >= 0 and pop_duration then
    p = math.min(1, pop_t / pop_duration)
    scale = 1 + 0.5 * (1 - p)
  end
  -- Échos AVANT l'icône réelle (derrière, alpha faible) : sinon ils la
  -- recouvriraient et casseraient sa lisibilité pendant le pop.
  if p and p < STATUS_POP_ECHO_WINDOW then
    local echo_life = 1 - p / STATUS_POP_ECHO_WINDOW -- 1 -> 0 sur la fenêtre
    for i = 1, STATUS_POP_ECHO_COUNT do
      local echo_alpha = echo_life * 0.3 / i
      local echo_scale = scale * (1 + 0.22 * i)
      love.graphics.push()
      love.graphics.translate(cx, cy)
      love.graphics.scale(echo_scale, echo_scale)
      love.graphics.translate(-cx, -cy)
      Icons.draw_status(status_key, cx, cy, size * 0.42, color or Theme.status, echo_alpha)
      love.graphics.pop()
    end
  end
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)
  local drawn = Icons.draw_status(status_key, cx, cy, size * 0.42, color or Theme.status)
  if drawn then
    if value then UI.text(tostring(value), x + size * 0.85, y + size * 0.18, w - size * 0.85, size * 0.72, color, "left") end
  else
    UI.text(abbr .. (value and (" " .. value) or ""), x, y, w, size, color)
  end
  love.graphics.pop()
end

--- Une ligne de badges de statut, chacun avec son icône dessinée + valeur (ou
-- son repli texte), répartis à parts égales sur la largeur donnée. `items` :
-- liste de { key = "defense", abbr = "DEF", value = 3 } (value optionnelle).
-- `pop_lookup` (optionnel) : table [status_key] = elapsed, voir Controller.status_pop.
function UI.draw_badge_row(items, x, y, w, size, color, pop_lookup, pop_duration)
  if #items == 0 then return end
  local slot = w / #items
  for i, it in ipairs(items) do
    local pop_t = pop_lookup and pop_lookup[it.key]
    status_badge(it.key, it.abbr, it.value, x + (i - 1) * slot, y, slot, size, color, pop_t, pop_duration)
  end
end

--- Barre de PV "à 2 niveaux", perte ET gain (2026-08-30, demande explicite,
-- étendue le même jour aux soins -- voir Controller:update/advance_trail) :
-- `trail_pct` (fraction de PV tenue par self.hp_trail) rejoint toujours
-- `pct` (la vraie valeur ACTUELLE, immédiate) progressivement, dans les deux
-- sens -- cette fonction se contente d'afficher le plus grand des deux en
-- accent (EN DESSOUS), le plus petit par-dessus dans `color` (le rouge
-- "normal").
function UI.hp_bar(x, y, w, h, pct, trail_pct, color)
  UI.set({ 0, 0, 0 }, 0.35)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  local clamped_pct = math.max(0, math.min(1, pct))
  local clamped_trail = trail_pct and math.max(0, math.min(1, trail_pct)) or clamped_pct
  local wide, narrow = math.max(clamped_trail, clamped_pct), math.min(clamped_trail, clamped_pct)
  -- Garde `> 0` sur les 2 rectangles (2026-08-30, bug signalé -- "il reste
  -- du rouge sur le bord de la barre de vie" -- un héros mort, à 0 PV) :
  -- love.graphics.rectangle("fill", ..., 0, h, 4, 4) (largeur nulle) laisse
  -- quand même un liseré visible à cause du rayon d'arrondi fixe (4px), qui
  -- ne se réduit pas avec la largeur -- jamais dessiné en dessous de 1px,
  -- plutôt qu'un rectangle dégénéré.
  if wide > narrow and wide * w > 1 then
    UI.set(clamped_trail > clamped_pct and Theme.hp_trail or Theme.heal)
    love.graphics.rectangle("fill", x, y, w * wide, h, 4, 4)
  end
  if narrow * w > 1 then
    UI.set(color)
    love.graphics.rectangle("fill", x, y, w * narrow, h, 4, 4)
  end
  UI.set(Theme.black)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  love.graphics.setLineWidth(1)
end

--- Courbe "ease-out-back" classique : va de 0 à 1 en dépassant légèrement 1
-- (le "bump") avant de s'y stabiliser. Utilisée pour le zoom du titre
-- "Victoire !" (2026-08-08) -- `duration` vient de `controller.victory_title_duration`,
-- seule source de vérité pour ce timing (voir controller.lua).
function UI.ease_out_back(t, duration)
  local p = math.min(1, math.max(0, t / duration))
  local c1, c3 = 1.70158, 2.70158
  return 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
end

--- Facteur d'échelle horizontale simulant un retournement de carte (face
-- cachée -> face visible) : 1 -> 0 (tranche) -> 1, jamais négatif (donc jamais
-- de miroir). Le contenu affiché doit basculer face/dos exactement à p=0.5.
function UI.flip_scale_x(t, duration)
  local p = math.min(1, math.max(0, t / duration))
  return math.abs(math.cos(p * math.pi))
end

-- Indice discret d'infobulle (2026-08-21, demande explicite -- tuto onboarding) :
-- petit "?" en bas à droite de tout élément qui porte une infobulle (allié,
-- ennemi, carte), à très léger alpha pour ne jamais dominer visuellement --
-- PUREMENT décoratif, ne change ni la zone de survol ni le délai d'apparition
-- de l'infobulle elle-même (voir Controller.hover_ready/HOVER_DELAY).
local TOOLTIP_HINT_ALPHA = 0.35
local TOOLTIP_HINT_RING_ALPHA = 0.45
-- `color` (optionnel, 2026-08-28, demande explicite -- même indice sur le
-- bouton "Fin de tour") : le blanc/Theme.text par défaut suppose un fond
-- sombre (panneau) -- sur un bouton à fond clair (Theme.accent, doré), un "?"
-- clair se lirait mal, d'où cette dérogation plutôt qu'une variante dupliquée.
function UI.draw_tooltip_hint(w, h, color)
  local cx, cy = w - 10, h - 9
  UI.set(color or Theme.white, TOOLTIP_HINT_RING_ALPHA)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", cx, cy, 8)
  love.graphics.setFont(Fonts.get(11))
  UI.set(color or Theme.text, TOOLTIP_HINT_ALPHA)
  love.graphics.printf("?", cx - 6, cy - 6, 12, "center")
  love.graphics.setColor(1, 1, 1, 1)
end

--- Bouton générique du "kit" menu (fond panneau clair, contour doré, libellé
-- centré) : malgré son nom, réutilisé bien au-delà du menu principal --
-- options, retour Choix de boss/deck-builder, menu pause, boutons de l'écran
-- de victoire/défaite. `b` = { x, y, w, h, label }.
function UI.draw_menu_style_button(b)
  UI.set(Theme.panel_light)
  love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 10, 10)
  UI.set(Theme.accent); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 10, 10)
  love.graphics.setLineWidth(1)
  UI.text(b.label, b.x, b.y + b.h / 2 - 8, b.w, 16, Theme.text, "center")
end

-- Couleurs des statues du Temple (2026-08-29, demande explicite -- une par
-- effet, voir Temple.effects dans temple.lua) : purement décoratives,
-- utilisées à la fois par les badges sur le cadre des héros (view/combat.lua,
-- draw_hero) et par l'écran du Temple lui-même (view/temple.lua) -- une seule
-- table partagée, jamais 2 palettes qui pourraient diverger.
UI.TEMPLE_STATUE_COLORS = {
  vert = { 0.35, 0.72, 0.42 }, bleu = { 0.35, 0.55, 0.85 }, rouge = { 0.82, 0.32, 0.32 },
  blanc = { 0.92, 0.92, 0.92 }, violet = { 0.62, 0.42, 0.82 }, noir = { 0.38, 0.35, 0.42 },
  orange = { 0.88, 0.58, 0.24 }, gris = { 0.62, 0.62, 0.65 },
}

-- Canvas + fondu partagés par les 4 écrans "camp" (Forge/feu de camp/Refuge/
-- Temple) : capture tout le contenu de l'écran dans un canvas pour pouvoir lui
-- appliquer un SEUL fondu uniforme à l'entrée, plutôt que de faire porter un
-- paramètre alpha à chaque fonction de dessin individuelle. `controller.
-- camp_entrance` (voir Controller:enter_post_combat_sequence, seul écrivain) :
-- nil seulement si cet écran a été atteint par un chemin qui l'aurait sauté
-- (ne devrait pas arriver) -- se comporte alors comme un fondu déjà terminé,
-- jamais une erreur.
local camp_entrance_canvas
function UI.draw_camp_entrance(controller, title, title_y, draw_content)
  local entrance = controller.camp_entrance
  local title_duration = controller.camp_entrance_title_duration or 0.55
  local title_t = entrance and entrance.t or title_duration
  local ease = UI.ease_out_back(title_t, title_duration)
  local from_y = -40
  UI.text(title, 0, from_y + (title_y - from_y) * ease, UI.W, 24, Theme.text)

  local content_alpha = 1
  if entrance then
    local delay = controller.camp_entrance_fade_delay or 0
    local duration = controller.camp_entrance_fade_duration or 0.4
    content_alpha = math.max(0, math.min(1, (entrance.t - delay) / duration))
  end

  camp_entrance_canvas = camp_entrance_canvas or love.graphics.newCanvas(UI.W, UI.H)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(camp_entrance_canvas)
  love.graphics.clear(0, 0, 0, 0)
  draw_content()
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, content_alpha)
  love.graphics.draw(camp_entrance_canvas)
  love.graphics.setColor(1, 1, 1, 1)
end

return UI
