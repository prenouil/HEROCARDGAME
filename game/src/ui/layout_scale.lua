-- Facteur d'agrandissement global de l'interface : texte/icônes/portraits jugés
-- trop petits en playtest (2026-08-08). Un seul facteur, utilisé à la fois pour
-- la taille de fenêtre (conf.lua) et le love.graphics.scale() qui l'affiche
-- (main.lua), pour ne jamais désynchroniser la fenêtre réelle de l'espace de
-- coordonnées logique 960x700 sur lequel tout le layout de view.lua est écrit.
return 1.4
