# Steal a Fossil : GDD v2

Mis à jour le 2026-10-10 après le brainstorm avec Snaky. Remplace la v1. Textes en jeu en anglais. Style studs/voxel comme les autres jeux de Snaky. Les chiffres (vitesses, prix, probas, durées) sont des valeurs de départ à équilibrer.

## Pitch
Cours le long d'une route préhistorique, arrache des blocs de fossiles gardés par des dinos vivants, ramène-les chez toi sans te les faire voler en chemin, réanime-les en dinos qui rapportent de l'argent, et fusionne-les pour créer des hybrides que personne n'a encore vus.

## Inspiration
Même map et même boucle que **Steal an Egg** (pas Steal a Brainrot) : bases alignées au départ, longue route de biomes vers l'extérieur gardée par des créatures, vitesse comme stat principale, incubation avec minuteur, treadmill, fusion.

## Décisions prises avec Snaky
- Map et boucle calquées sur Steal an Egg.
- Un fossile ramené dans son parc ne peut **jamais** être volé. Le parc est une zone sûre. Le vol se fait uniquement sur la route.
- Un bloc lâché ne peut pas être repris par celui qui l'a perdu pendant 3 s.
- Le bloc montre sa rareté (couleur), l'espèce est une surprise à la réanimation.
- Deux modes de fusion : « Upgrade » (3 identiques) et « Hybride » (2 espèces différentes).
- 8 zones dès le lancement.
- Pas de Rebirth.
- Treadmill obligatoire : déblocage à $1K en argent du jeu (comme Steal an Egg), puis améliorations en argent dont le prix monte à chaque niveau ; chaque niveau peut aussi s'acheter en Robux pour aller plus vite.

## Carte (serveur de 8)
- **Spawn** : une rangée de 5 parcs (un par joueur, serveurs de 5 joueurs) face à la route. Chaque parc contient : cuves de réanimation (2 au départ, achetables jusqu'à 6), enclos à dinos (slots, agrandissable), treadmill, labo de fusion.
- **Route** : 8 zones en ligne, de plus en plus loin du spawn. Chaque zone a une vitesse conseillée (pas un mur : on peut y aller, mais le gardien nous rattrape).

| # | Zone | Vitesse conseillée |
|---|------|--------------------|
| 1 | Beach | aucune |
| 2 | Fern Forest | 1 K |
| 3 | Swamp | 10 K |
| 4 | Canyon | 50 K |
| 5 | Glacier | 200 K |
| 6 | Volcano | 1 M |
| 7 | Ocean Trench | 5 M |
| 8 | Meteor Crater | 25 M |

- **Gisements (Dig Sites)** : plusieurs par zone, chacun avec des blocs fossiles. Ils se remplissent toutes les 5 min (compte à rebours affiché). Un bloc Secret est annoncé dans le chat du serveur.
- **Gardiens** : dans chaque zone, un dino vivant dort près des gisements. Quand on arrache un bloc, il se réveille (« RUN!! ») et poursuit le joueur sur toute la route, jusqu'au bord de la Beach. Plus la zone est loin, plus il est rapide : trop lent pour la zone, on est rattrapé avant d'être rentré. S'il attrape le joueur : ragdoll cartoon, le bloc est lâché et retourne au gisement.

## Boucle principale
1. Courir vers une zone adaptée à sa vitesse.
2. Arracher un bloc (maintenir E 1 s). Le bloc se porte sur le dos, visible par tous, couleur = rareté.
3. Fuir le gardien. Porter ralentit : -10 % (Common) à -40 % (Secret).
4. Rentrer au parc : dès que le bloc passe l'entrée, il est à toi pour de bon.
5. Poser le bloc dans une cuve de réanimation : minuteur selon la rareté.
6. Révélation : espèce + taille + mutation éventuelle. Le dino va dans l'enclos.
7. Le dino rapporte $/s.
8. Dépenser : trails, cuves, slots d'enclos, pièges, fusion.

## Vol (PvP)
- Uniquement sur la route. Rien n'est volable dans un parc (blocs, cuves, dinos).
- **Pelle (Shovel)**, outil de départ : un coup (bonk) fait lâcher le bloc au porteur. Recharge 2 s. Pas de dégâts, ragdoll cartoon.
- **Bear Trap** : posé au sol, immobilise 3 s celui qui marche dessus (joueur ou gardien) et lui fait lâcher son bloc.
- Bloc au sol : n'importe qui peut le ramasser, sauf celui qui l'a lâché pendant 3 s. Non ramassé en 30 s, il retourne à son gisement.
- **Protection débutant** : impossible d'être bonké ou piégé pendant les 10 premières minutes.

## Raretés
| Rareté | Couleur du bloc | Proba de base | Réanimation |
|--------|-----------------|---------------|-------------|
| Common | gris | 55 % | 30 s |
| Uncommon | vert | 25 % | 1 min |
| Rare | bleu | 12 % | 3 min |
| Epic | violet | 5 % | 10 min |
| Legendary | orange | 2.4 % | 30 min |
| Mythic | rouge | 0.5 % | 1 h |
| Secret | arc-en-ciel | 0.1 % | 3 h |

Les zones lointaines ont de meilleures probas. La couleur du bloc fixe la rareté, l'espèce est tirée parmi les espèces de cette rareté dans la zone.

## Espèces (8 par zone ; raretés dans Config/Rarity, nouvelles espèces : docs/MUTATIONS.md)
- Beach : Compy, Oviraptor, Pteranodon, Protoceratops, Psittacosaurus, Dimorphodon, Archelon, Tanystropheus
- Fern Forest : Gallimimus, Parasaurolophus, Stegosaurus, Hypsilophodon, Microraptor, Kentrosaurus, Styracosaurus, Dilophosaurus
- Swamp : Iguanodon, Baryonyx, Sarcosuchus, Diplocaulus, Dimetrodon, Deinonychus, Corythosaurus, Basilisk
- Canyon : Pachycephalosaurus, Velociraptor, Triceratops, Coelophysis, Edmontonia, Allosaurus, Amargasaurus, Thunder Raptor
- Glacier : Ankylosaurus, Therizinosaurus, Cryolophosaurus, Troodon, Smilodon, Yutyrannus, Woolly Mammoth, Frost Wyvern
- Volcano : Carnotaurus, Brachiosaurus, Spinosaurus, Dracorex, Ceratosaurus, Acrocanthosaurus, Magma Behemoth, Phoenix
- Ocean Trench : Plesiosaurus, Megalodon, Mosasaurus, Ichthyosaurus, Dunkleosteus, Helicoprion, Liopleurodon, Abyssal Leviathan
- Meteor Crater : Quetzalcoatlus, Giganotosaurus, T-Rex, Kosmoceratops, Deinocheirus, Argentinosaurus, Celestial Serpent, Star Dragon
- Secret (zones lointaines surtout) : Golden Raptor, Crystal Rex, Lava Titan

## Taille et mutations (à la réanimation)
- Taille : Small x0.8, Normal x1, Big x1.5, Huge x3 (Huge rare).
- Mutations : Amber 8 % (x1.5), Crystal 3 % (x2), Lava 1 % (x3), Rainbow 0.05 % (x10) dans toutes les zones, plus
  une mutation par biome qui ne sort que de ses fossiles : Pearl (Beach) et Bloom (Fern Forest) 2 % (x2), Toxic
  (Swamp), Ruby (Canyon) et Frost (Glacier) 1.5 % (x2.5), Obsidian (Volcano) 1 % (x3), Abyssal (Ocean Trench) 0.75 %
  (x4), Galaxy (Meteor Crater) 0.5 % (x5). Les mutations de 1 % ou moins sont annoncées à tout le serveur. Détails :
  `docs/MUTATIONS.md`.
- Revenu d'un dino = base de l'espèce x taille x mutation.

## Fusion (labo dans le parc)
**Mode 1 : Upgrade**
- 3 dinos identiques (même espèce, même niveau) donnent 1 dino de niveau supérieur : Normal, puis Golden, puis Diamond.
- Le résultat rapporte plus que les 3 réunis (ex. Golden = x4 la base). Il garde la meilleure taille et la meilleure mutation des trois.
- Sert à recycler les doublons.

**Mode 2 : Hybride**
- 2 dinos d'espèces différentes donnent une nouvelle créature qui mélange les deux (ex. T-Rex + Pteranodon = Ptero-Rex, Triceratops + Stegosaurus = Tricera-Stego).
- Recettes secrètes. Si la combinaison n'existe pas : « Unknown recipe », les dinos sont rendus (on ne perd rien à tester).
- Revenu d'un hybride = (A + B) x1.5.
- Lancement : environ 12 recettes, 2 à 3 nouvelles à chaque mise à jour.
- Page « Hybrids » dans l'Index avec des silhouettes « ??? » et un indice par recette.
- Modèles hybrides en voxel générés par code : tête de A, corps et queue de B, ailes ou nageoires de celui qui en a.

## Vitesse et treadmill
- La vitesse est la stat principale : elle ouvre les zones lointaines et permet d'échapper aux gardiens et aux voleurs.
- **Treadmill** dans le parc : courir dessus (ou rester AFK dessus) donne de la vitesse chaque seconde. Rien à regarder pendant (pas de fil de vidéos, c'est ce qui avait fait retirer Steal an Egg).
- **Achat** : pas cher en Robux (25 R$).
- **Améliorations en Robux** : chaque niveau augmente la vitesse gagnée par seconde, et le prix monte à chaque achat.

| Niveau | Prix | Gain (valeur de départ) |
|--------|------|-------------------------|
| 1 (achat) | 25 R$ | x1 |
| 2 | 39 R$ | x1.5 |
| 3 | 59 R$ | x2 |
| 4 | 89 R$ | x3 |
| 5 | 129 R$ | x4 |
| 6 | 179 R$ | x6 |
| 7 | 249 R$ | x8 |
| 8 | 349 R$ | x11 |
| 9 | 499 R$ | x15 |
| 10 | 699 R$ | x20 |

- Technique : sur Roblox un produit a un prix fixe, donc un produit développeur par niveau. Le serveur ne propose que le niveau suivant du joueur et l'enregistre dans ses données.
- **Vitesse gratuite** (pour que les joueurs qui ne paient pas avancent aussi, plus lentement) : trails achetées avec l'argent du jeu (10, de Common à Divine), récompenses des quêtes, récompense like + favori + groupe.

## Monétisation
- Passes : x2 Money, x2 Treadmill, Fast Revive (cuves 2x plus rapides), VIP (tag + petite chance en plus).
- Produits : niveaux du Treadmill (raccourci Robux, ils s'achètent aussi en argent), Bear Traps x5, Server Luck x2 pendant 15 min, Instant Revive.
- Jamais de dino ni de bloc vendu directement en Robux. Toute chance payante affiche ses probas.
- Ids = 0 jusqu'à création dans le Creator Hub par Snaky.

## Rétention et événements
- Mise à jour chaque samedi à la même heure, avec compte à rebours en jeu (nouvelles recettes d'hybrides, espèces, events).
- **Pluie de météorites** toutes les 20 min : alerte 30 s, des blocs Epic+ tombent sur la route pendant 60 s, tout le serveur court.
- Récompense quotidienne (14 jours) et 3 quêtes par jour.
- Bonus ami : +10 % de gains par ami sur le serveur, max 3.
- Index des espèces et des hybrides avec récompense par page complétée.
- Revenu hors ligne plafonné à 8 h.
- Tutoriel : premier dino garanti en moins de 2 min (bloc Common à la Beach, gardien lent).
- Admin abuse à chaque grosse mise à jour.

## Direction artistique et production (demande de Snaky)
**Outils** : tout est fait avec **Blender (via MCP)** et **Roblox Studio (via le Studio MCP)**. Les deux tournent sur le PC de Snaky : la fabrication se fait dans une session Claude Code sur son PC (le Studio MCP n'est pas visible depuis les threads cloud). Blender peut aussi tourner dans le cloud pour les rendus de contrôle.

**Style** : tout en studs. Cubes sur une grille de 1 à 2 studs, couleurs plates, `SurfaceType.Studs` sur le dessus, formes rondes en escalier.

**Modèles (dinos, gardiens, hybrides, blocs fossiles, décor)**
- **Décidé avec Snaky : données studs.** Modélisés et voxelisés dans Blender, exportés en données voxel Luau (même pipeline que les boss de Pet Fusion Lab), reconstruits en jeu avec de vraies briques Roblox. Pas d'upload de mesh, donc pas de file de modération (des os en mesh, tube + boule, risquent d'être retirés et de mettre un avertissement sur le compte). Environ 450 briques max par modèle.
- Rendus de contrôle face et profil de chaque modèle avant intégration.

## Animations (demande de Snaky : détaillées, plusieurs états, corps entier et membres)
**Squelette** : chaque animal est découpé en os, chaque groupe de briques suit son os. Pas de modèle rigide qui glisse : tout bouge.
- Tête, mâchoire (s'ouvre), yeux (clignent, briques de paupière), cou en 2 à 3 segments.
- Torse avant et arrière (respiration, torsion du corps).
- Queue en 4 à 6 segments (balancement en vague, suit le mouvement avec retard).
- Pattes en 3 parties (cuisse, jambe, pied) ; bras en 2 à 3 parties pour les bipèdes.
- Ailes en 2 à 3 segments (volants), nageoires (nageurs), collerette, plaques ou épines quand l'espèce en a.

**Familles de mouvement** (une base commune, puis réglée espèce par espèce) :
- Bipèdes (T-Rex, raptors, Compy, Carnotaurus…) : marche lourde ou sautillante selon l'espèce, tête qui équilibre la queue.
- Quadrupèdes (Stegosaurus, Triceratops, Ankylosaurus, Brachiosaurus…) : démarche à 4 temps, cou et tête qui balancent.
- Volants (Pteranodon, Quetzalcoatlus) : décollage, vol battu, plané, atterrissage, marche sur les ailes repliées.
- Nageurs (Mosasaurus, Plesiosaurus, Megalodon) : nage en ondulation, plongée, saut hors de l'eau (bassin dans l'enclos).

**États des dinos du parc**
- Idle : respiration, queue qui balance, clignements, tête qui regarde autour.
- Idles variés joués au hasard : renifler le sol, se gratter, s'étirer, secouer la tête, bâiller.
- Walk : se promène dans l'enclos.
- Happy : petit saut ou danse quand le joueur récupère l'argent ou s'approche.
- Roar : au moment de la révélation.
- Eat : mange (feuilles ou viande selon l'espèce).
- Sleep : couché, ventre qui monte et descend, de temps en temps.
- Spawn : sort de la cuve, s'ébroue, regarde le joueur.

**États des gardiens**
- Sleep : ronfle, ventre qui monte, queue qui bouge un peu.
- Wake : sursaut, se relève, secoue la tête.
- Roar : rugissement vers le joueur, déclenche « RUN!! ».
- Run : course poursuite (plus rapide et plus amplifiée que Walk).
- Catch : charge ou coup de tête cartoon qui fait tomber le joueur (pas de morsure).
- Search : a perdu le joueur, renifle, regarde à gauche et à droite.
- Return : revient à son gisement en marchant.
- Back to sleep : tourne sur lui-même et se recouche.

**Autres états** : Fusion (aspiré dans le tourbillon, puis l'hybride apparaît et rugit), Index (pose de présentation qui tourne).

**Règles**
- Transitions en fondu (environ 0.2 s) entre les états, jamais de saut d'une pose à l'autre.
- Personnalité par espèce : le Compy est nerveux et rapide, le T-Rex lourd avec le sol qui tremble, le Brachiosaurus lent et majestueux.
- La taille change le rythme : un Huge marche plus lentement et plus lourdement qu'un Small.
- Hybrides : le corps suit la famille de mouvement du dino qui donne le corps, la tête et les ailes gardent leurs propres animations.
- Effets liés aux animations : poussière à chaque pas des gros dinos, tremblement de caméra pour le rugissement d'un gardien proche, bulles pour les nageurs.

**Production**
- Animations faites dans Blender (squelette + images clés), puis enregistrées dans les données Luau de chaque modèle (pipeline anim de Pet Fusion Lab) et jouées en jeu par un lecteur d'animation.
- Pour chaque espèce, une planche d'images et une vidéo MP4 de chaque état pour que Snaky valide.
- Performance : animation complète près du joueur, cadence réduite au loin, figée hors de vue.

**Tailles**
- Taille de base différente par espèce : petits 3 à 5 studs (Compy, Oviraptor), moyens 6 à 10 (Raptor, Pachy), grands 12 à 20 (Triceratops, T-Rex, Spinosaurus), géants 25 à 35 (Brachiosaurus, Mosasaurus, Lava Titan).
- Taille tirée à la réanimation, visible sur le modèle : Small x0.75, Normal x1, Big x1.5, Huge x2.5.
- Gardiens : version x1.5 à x3 de l'espèce de leur zone, pour qu'ils fassent peur de loin.

**Map détaillée** (une identité forte par zone, une arche d'entrée avec le nom et la vitesse conseillée)
- Spawn : 5 parcs clôturés (serveurs de 5 joueurs), enseigne au nom du joueur, cuves, enclos, treadmill, labo de fusion.
- Beach : sable, palmiers, rochers, coquillages fossiles, mer.
- Fern Forest : fougères géantes, troncs couchés, brume légère.
- Swamp : eau verte, racines, nénuphars, brouillard.
- Canyon : falaises rouges en strates, ponts de bois, arches de pierre.
- Glacier : glace bleue, neige, dinos figés dans la glace en décor.
- Volcano : rivières de lave, roche noire, fumée, braises.
- Ocean Trench : fonds marins, coraux géants, bulles, lumière bleue.
- Meteor Crater : grand cratère, cristaux violets, ciel étoilé.
- Gisements : fouilles avec cordes, pioches, lampes, piles de terre.
- Budget lumière et Neon par zone (leçon de Pet Fusion Lab : peu de lights, bloom modéré, densité de décor contrôlée vue de haut). StreamingEnabled pour la longue route.

**VFX des fossiles (par rareté)**
- Common : aucun. Uncommon : quelques particules vertes. Rare : lueur bleue.
- Epic : aura et particules violettes. Legendary : rayons orange et étincelles.
- Mythic : flammes rouges et pulsation. Secret : arc-en-ciel qui tourne, rayon vers le ciel visible de loin, son spécial.
- Mutations sur les dinos : Amber (gouttes dorées translucides), Crystal (éclats brillants), Lava (fissures lumineuses et braises), et les mutations des biomes et Rainbow (faites : couleurs dans `DinoBuilder`, effets animés dans `MutationController`, voir `docs/MUTATIONS.md`).

**VFX de gameplay**
- Arrachage : poussière et débris. Réveil du gardien : rugissement, onde de choc, « RUN!! » à l'écran.
- Bonk : étoiles cartoon. Bloc lâché : rebond et compte à rebours de 3 s au-dessus.
- Réanimation : cuve qui bouillonne, éclairs, flash à la couleur de la rareté à la révélation.
- Fusion : les deux dinos aspirés dans un tourbillon, flash, carte de révélation.
- Météorites : traînée de feu, impact, cratère lumineux. Treadmill : traînée de vitesse.

**UI/UX**
- HUD de Snaky (bloc de boutons à gauche, compteurs en bas à gauche), adapté au mobile.
- Vitesse actuelle comparée à la vitesse conseillée de la zone (vert ou rouge).
- Pendant le transport : flèche vers son parc, distance, alerte quand le gardien approche.
- Minuteurs des cuves visibles dans le parc et dans un menu.
- Labo de fusion : 2 ou 3 emplacements, aperçu « ??? » et indice de recette.
- Index avec silhouettes des espèces et hybrides non découverts.
- Shop du treadmill qui montre le niveau suivant, son gain et son prix réel lu sur Roblox.
- Tutoriel guidé par flèches jusqu'au premier dino.

## Modération / vérification
- Contenu visé : Minimal/Mild. Vol cartoon (bonk, ragdoll, pas de dégâts), pas de sang.
- Dinos, os et blocs faits dans Blender puis exportés en données voxel : pas d'upload de mesh, pas de file de modération.
- Pas de récompense pour regarder un fil de vidéos. Pas d'assets d'autres jeux.

## Technique
- Rojo, même structure que Steal a Snack (src/server, src/client, src/shared/Config.luau).
- Copier depuis Steal a Snack (copie seulement, ne jamais modifier l'original) : DataService (session lock), PlotService, ProcessReceipt, RateLimit, Remotes, Format, UIKit, tests hors Studio (tools/luau_tests).
- Serveur autoritaire : tirage des blocs, durée minimale d'arrachage, distance au gisement, vitesse et malus de port, bonk (portée, recharge), règle des 3 s, zone sûre du parc, minuteurs des cuves, recettes de fusion (jamais envoyées au client avant découverte), niveaux de treadmill achetés.

## Jalons
1. Squelette du projet, parcs, route et zones, arracher / porter / rentrer / cuve / dino / revenus, tests hors Studio.
2. Gardiens et vol sur la route (bonk, pièges, règle des 3 s, protection débutant).
3. Treadmill, vitesse, trails, shop.
4. Fusion (Upgrade et Hybride).
5. Modèles Blender (dinos, gardiens, hybrides, blocs) avec tailles et animations, map détaillée des 8 zones dans Studio, VFX, UI (HUD, Index, quotidien, quêtes), pluie de météorites.
6. Passes et produits, analytics, miniature et icône.

## Retiré depuis la v1
Socles à 4 morceaux, porte laser, vol dans les parcs, carrière centrale et parcs en cercle, Rebirth et ères.
