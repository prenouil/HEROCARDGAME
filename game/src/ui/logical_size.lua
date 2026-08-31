-- Résolution logique du jeu (espace de coordonnées sur lequel tout le layout
-- de view.lua est écrit), partagée avec conf.lua pour la taille de fenêtre --
-- même schéma que layout_scale.lua (SCALE), pour ne plus dupliquer W/H à la
-- main entre les deux fichiers (2026-08-31, passage à un vrai 16:9, demande
-- explicite -- avant : `local W, H = 960, 660` recopié séparément dans
-- conf.lua avec un commentaire "DOIT rester synchronisé" comme seule garantie).
return { W = 1280, H = 720 }
