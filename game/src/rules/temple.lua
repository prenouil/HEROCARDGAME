-- Écran "Le Temple" (Run Infini, 2026-08-28, demande explicite) : après un
-- combat, le joueur peut bénir UN de ses aventuriers avec un effet passif tiré
-- au hasard dans Temple.blessings. La bénédiction s'ajoute au cadre de
-- l'aventurier en combat (badge dédié, voir view.lua) et persiste pour le
-- reste du run (`hero.blessing`, propagé automatiquement par le copy-through
-- de Game.carried_hero -- voir game.lua, qui applique aussi l'effet lui-même
-- à chaque entrée en combat). Un aventurier ne porte jamais plus d'une
-- bénédiction à la fois -- pas de cumul, voir Temple.pick_target.

local Temple = {}

-- Liste volontairement courte pour l'instant (2026-08-28, demande explicite --
-- "pour l'instant, la liste ne contient qu'un élément") : conçue pour grandir,
-- Temple.pick_blessing tire déjà au hasard dedans plutôt que de supposer une
-- seule entrée. `combat_start_heal` : montant appliqué par Game.carried_hero à
-- chaque entrée en combat (PAS ici, ce module ne fait que le choix/l'attribution) ;
-- `icon`/`name`/`desc` : données d'affichage (badge en combat, écran du Temple).
Temple.blessings = {
  {
    id = "heal_5",
    name = "Régénération",
    desc = "L'aventurier béni regagne 5 PV au début de chaque combat.",
    icon = "\u{1F33A}",
    combat_start_heal = 5,
  },
}

function Temple.by_id(id)
  for _, b in ipairs(Temple.blessings) do
    if b.id == id then return b end
  end
  return nil
end

--- Aventurier vivant et pas déjà béni -- nil si tous les aventuriers vivants
-- portent déjà une bénédiction (écran affiché grisé/passable côté UI, même
-- principe que Forge quand plus aucune carte n'est améliorable). Le CHOIX de
-- la cible revient au joueur (clic sur un des 4 aventuriers affichés, voir
-- input.lua) -- cette fonction ne fait que lister qui est éligible.
function Temple.eligible_heroes(state)
  local out = {}
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and not h.blessing then out[#out + 1] = h end
  end
  return out
end

--- Bénédiction tirée au hasard dans Temple.blessings (une seule entrée pour
-- l'instant, mais tire quand même au hasard plutôt que de supposer #list == 1
-- -- la liste est faite pour grandir sans qu'il faille retoucher cet appel).
function Temple.pick_blessing(rng)
  return Temple.blessings[rng:random(#Temple.blessings)]
end

--- Attribue `blessing` à `hero` -- remplace toute bénédiction précédente si
-- jamais appelé deux fois sur le même aventurier (ne devrait pas arriver, voir
-- Temple.eligible_heroes, mais pas de raison de refuser plutôt que remplacer).
function Temple.bless(hero, blessing)
  hero.blessing = blessing.id
end

return Temple
