# Mémoire de agent_doc

Index des conventions de rédaction, retours et repères pour la maintenance des documents de design (`docs/design/`, qui remplacent progressivement le Google Doc et le GDD BMAD, tous deux obsolètes). Chaque ligne pointe vers un fichier détaillé dans ce dossier.

- [Avancement de la reconstruction](project_avancement-reconstruction.md) — quels documents de `docs/design/` sont reconstruits (dont `modes.md`, nouveau le 2026-09-03), URL de l'Artifact combiné "tableur" (7 onglets), ce qui reste à faire (document de règles).
- [Où lire le code](reference_sources-code-a-lire.md) — les règles de déclenchement des évènements post-combat vivent dans `game/src/ui/controller.lua`, pas dans `src/rules/` seul.
- [Pas de règle uniforme supposée](feedback_pas-de-regle-uniforme-supposee.md) — vérifier chaque ressource/mécanique individuellement dans le code (ex. Mana ≠ Discrétion/Corruption sur le reset entre combats), jamais généraliser depuis un champ voisin.
- [Vérifier le chemin de rendu réel](feedback_verifier-chemin-de-rendu-reel.md) — un champ de données (ex. `icon` de `glossary.lua`) peut n'être jamais consommé par le vrai code de rendu UI ; toujours vérifier ce qui s'affiche réellement avant de le documenter (ex. les vraies icônes du jeu sont des PNG dans `assets/icons/keywords/`, pas le champ `icon`). Mise à jour 2026-08-30 : "mana" a désormais son PNG, plus aucune exception parmi les 17 termes "à icône".
- [upload_asset indisponible sur ce compte](reference_upload-asset-indisponible.md) — `Artifact action:"upload_asset"` échoue systématiquement (`unavailable_to_account`), impossible d'embarquer de vraies images dans un Artifact tant que ce n'est pas activé ; pas d'outil shell non plus pour un contournement en `data:` URI.
