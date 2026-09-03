# Mémoire — agent_content

Index des entrées. Chaque ligne pointe vers un fichier détaillé dans ce dossier.

- [Intention de design du run](project_run-infini-design-intent.md) — pourquoi les PV ont doublé et la courbe de difficulté a été aplatie.
- [Transmission de contenu](feedback_contenu-handoff.md) — relayer fidèlement le contenu déjà finalisé (tableur), mais signaler les incohérences au lieu de les reproduire.
- [Cartes Départ flexibles](feedback_depart-cards-flexibles.md) — la répartition "1 attaque / 1 défense / 1 perso" n'est pas une règle, on peut s'en affranchir.
- [Ressource dépensée dès le Départ](reference_ressource-carte-depart.md) — la règle "1 carte Départ dépense la ressource" ne s'applique qu'aux ressources-monnaie (Mana/Corruption), pas aux ressources-seuil (Discrétion → Camouflé).
- [Cartes liées à la mécanique](feedback_cartes-liees-mecanique.md) — même une carte simple/de remplissage doit toucher à la mécanique propre de sa classe, pas juste porter un nom thématique sur un effet générique.
- [Reset des ressources par combat](reference_reset-ressource-par-combat.md) — toute ressource propre repart à sa valeur de base à chaque nouveau combat (intention voulue ; le code actuel a un décalage sur Mana/Discrétion, à faire corriger).
- [Synergie inter-classes](feedback_synergie-inter-classes.md) — "synergie" sur une classe support désigne par défaut jouer une carte de cette classe PUIS une carte d'une autre classe dans le même tour, pas empiler plusieurs cartes de la même classe.
- [Coût variable en ressource propre](reference_cout-variable-ressource.md) — format "X (a-b)", pastille ovale pour le distinguer d'un coût fixe, et pas de mélange fixe/variable dans un même kit une fois ce format adopté.
- [Mécanique de biome par comportement](reference_biome-mecanique-par-comportement.md) — un biome d'ennemis doit porter une mécanique de gameplay lisible dans le comportement des ennemis (pas une simple teinte visuelle), et réutiliser le bestiaire existant avant d'en créer un parallèle.
- [Mécanique Élite des ennemis](reference_ennemis-elite-mecanique.md) — variante transversale (PV/dégâts augmentés, jamais plus cher en budget de rencontre) applicable à n'importe quel ennemi ; "élite" est réservé à cette mécanique, plus un adjectif de fiche.
- [Vérifier le code avant de conclure une divergence numérique](feedback_verifier-code-divergence-numerique.md) — quand le porteur de projet énonce un changement de structure chiffré, lire le code réel avant de trancher si c'est une vraie divergence ou une simple confirmation.
- [Retrait du mode Infini](project_mode-infini-retrait.md) — le mode "Infini" (illimité, sans Boss) va bientôt disparaître : ne plus concevoir de contenu/cadence pensés spécifiquement pour lui, seulement pour le mode "bounded".
- [Mécanique du type "Enchantement"](reference_enchantement-mecanique.md) — carte sans cible, sans effet immédiat, qui attache un pouvoir passif permanent pour le combat ; points d'ancrage moteur réutilisables (deal_damage, grant_defense, gain_discretion, consume_inspiration, start_turn) et palier par défaut "Avancé".
- [Enchantements : déclencheurs répétés préférés](feedback_enchantements-declencheurs-repetes.md) — les propositions à seuil de PV bas franchi une fois par combat ont toutes été rejetées ; privilégier un déclencheur qui revient souvent (chaque coup/tour/gain de ressource).
