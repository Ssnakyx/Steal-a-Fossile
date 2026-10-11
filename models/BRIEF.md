# Recette des modèles (briefs 5, 6, 9 et 17)

À suivre à la lettre pour chaque nouvelle espèce. Les 4 pilotes validés par Snaky servent d'exemples :
`species/Velociraptor.py` (bipède), `Triceratops.py` (quadrupède), `Pteranodon.py` (volant), `Mosasaurus.py` (nageur).
Ne pas modifier `models/lib/` sans passer par le coordinateur (toutes les espèces en dépendent).

## 1. Le script de l'espèce : `models/species/<Espece>.py`

- Copier le pilote de la même famille, garder sa structure : `FAMILY`, `VOXEL`, couleurs, `PERSONALITY`, `build()`.
- Le nom du fichier = le nom du module (`Model` dans `src/shared/Config/Species.luau`, ex. `TRex` pour « T-Rex »).
- **Taille** : modéliser en voxels (unités entières), puis régler `VOXEL` pour tomber sur la taille de base de
  `Config/Species.luau` (BaseSize = plus grande dimension en studs à la taille Normal). Repère : ~45 voxels sur la
  longueur donnent un bon niveau de détail.
- **Os : noms obligatoires** (le jeu, les hybrides et les familles d'animation en dépendent) :
  - tous : `Hips` (racine), `Chest` (parent Hips), `Neck1..N` (parent Chest), `Head`, `Jaw`, `LidL`/`LidR`
    (paupières, posées par `d.eye(...)`), `Tail1..N` (parent Hips, 4 à 6 segments) ;
  - pattes arrière : `Thigh`, `Shin`, `Foot` L/R (parent Hips) + points `ToeL`/`ToeR` (bout du pied, au sol) ;
  - bipèdes : bras `Arm`, `Forearm` L/R (parent Chest) ;
  - quadrupèdes : pattes avant `Arm`, `Forearm`, `Hand` L/R + points `FrontToeL`/`FrontToeR` ;
  - volants : `Wing1`, `Wing2`, `Wing3` L/R (bras, avant-bras + main, doigt-aile) + points `HandL`/`R`, `WingTipL`/`R`,
    modélisés **ailes déployées** (membrane en plaque horizontale) ;
  - nageurs : `FinF1`, `FinF2`, `FinB1`, `FinB2` L/R (nageoires en plaques), la dernière vertèbre porte la nageoire de queue ;
  - décor qui bouge : `Frill` (collerette, plaques), `Crest`.
- **Articulations pliées au repos** (genou devant, coude derrière) : l'IK a besoin de marge. Distance hanche-cheville au
  repos ≈ 80 à 90 % de cuisse + jambe, sinon la patte se tend et le pied flotte.
- Modéliser le côté gauche (`where=left`, x <= 0) puis `d.mirror()`. Rien sous le sol : `d.remove(lambda x, y, z: y < 0)`.
- **Plaque inclinée** (collerette, voile) : la modéliser droite (alignée sur la grille, très peu de pièces) et l'incliner
  avec la rotation de repos de son os (`d.bone("Frill", pivot, "Head", rest=(30, 0, 0))`).
- Peinture : couleurs franches, peu de teintes côte à côte. Ventre et dos **coupés à plat** (seuil en y par os) plutôt que
  des taches : chaque frontière de couleur coûte des pièces. Yeux : `d.eye(os, paupière, y, z, iris, pupille, h, w)`.

## 2. Tailles (validées avec les pilotes)

La taille de base (`BaseSize` dans `src/shared/Config/Species.luau`) est la **plus grande dimension du modèle à la taille
Normal**, en studs : la longueur pour la plupart, l'envergure pour les volants, la hauteur pour le Brachiosaure. L'avatar
gris du rendu de contrôle mesure 5 studs : vérifier la taille à côté de lui. Référence validée par Snaky : le Velociraptor
(14 de long, 7 de haut) pour les moyens.

| Classe | Espèces (BaseSize en studs) |
|---|---|
| Petits | Compy 4, Oviraptor 5 |
| Moyens | Pachycephalosaurus 8, Gallimimus 9, Parasaurolophus 12, Iguanodon 12, Baryonyx 13, Velociraptor 14, Golden Raptor 14 |
| Grands | Stegosaurus 14, Ankylosaurus 15, Cryolophosaurus 15, Pteranodon 16 (envergure), Therizinosaurus 16, Carnotaurus 16, Sarcosuchus 16, Plesiosaurus 18, Triceratops 19, T-Rex 20, Spinosaurus 20, Giganotosaurus 22, Crystal Rex 22 |
| Géants | Megalodon 24, Quetzalcoatlus 26 (envergure), Mosasaurus 30, Brachiosaurus 32 (hauteur), Lava Titan 32 |

- Régler `VOXEL` pour tomber sur BaseSize (± 1 stud) : environ 0,1 à 0,15 pour les petits, 0,26 à 0,44 pour les moyens et
  grands, 0,5 à 0,6 pour les géants (autour de 45 à 60 voxels sur la plus grande dimension).
- En jeu, la taille tirée à la réanimation multiplie BaseSize : Small x0,75, Normal x1, Big x1,5, Huge x2,5
  (`DinoBuilder.Sizes`). Gardiens : x1,5 à x3 (option `Scale`). Exemple : un T-Rex Huge fait 50 studs.
- Les écarts doivent se voir : un Compy est plus petit que l'avatar, un Brachiosaure le dépasse de six fois.

## 3. Règles de style et de modération

- Tout en studs : cubes, formes rondes en escalier, couleurs plates. Plastic (studs sur les dessus d'au moins 1 x 1 stud),
  `Smooth` pour les petits détails (yeux, griffes, dents, bouche).
- **450 pièces au plus** (affiché par `--stills`). Si c'est trop : moins de frontières de couleur, formes plus carrées
  (`power=2.9` sur les ellipsoïdes du corps), voxel un peu plus gros, plaques droites + rotation de repos.
- Modération : cous, queues et os en **segments épais empilés** ; jamais de « tube + boule », jamais de sphères par paires.
  Regarder chaque rendu de contrôle (face et profil) avant d'exporter et refuser toute forme ambiguë.
- Personnalité (`PERSONALITY`) : `tempo` (1 = normal, 1,4 nerveux, 0,75 lourd), `weight`, `stride`, `bob`, `headBob`
  (tête d'oiseau), `tail`, `diet` (`meat`, `plants`, `fish`), `happy`, `catch`. Exemple : Compy tempo 1,4, T-Rex 0,75.

## 4. Fabriquer et vérifier

1. `python models/build.py <Espece> --stills` jusqu'à ce que le modèle soit beau (lire `models/previews/<Espece>/<Espece>_controle.jpg`).
2. `python models/build.py <Espece>` : toutes les animations, l'export Luau, la planche et la vidéo.
3. Regarder la planche **et** des images de la vidéo (pieds qui ne glissent pas sur le damier qui défile, pas de patte
   retournée, boucles sans saut, impact au bon moment). Corriger la personnalité ou, si un état ne va pas pour l'espèce,
   le signaler au coordinateur (les familles sont partagées).
4. `python models/tests/run.py` doit finir par `@@ dino: N OK / 0 FAIL`.
5. Ajouter l'espèce si besoin dans `src/shared/Config/Species.luau` (demander au coordinateur : fichier du brief 2).

## 5. Gardiens

Un gardien = la même espèce construite plus grande (`DinoBuilder.Build(espece, { Scale = 2 })`, x1,5 à x3). Ses états
(Sleep, Wake, Roar, Run, Catch, Search, Return, BackToSleep) sont déjà dans chaque famille.

## 6. Livrer à Snaky

Par lots de 4 espèces : la planche et la vidéo de chaque espèce (`models/previews/<Espece>/`), envoyées dans le thread, avec
une phrase par espèce (taille, nombre de pièces, ce qui est particulier). Commits : `models/species/<Espece>.py`,
`models/previews/<Espece>/*.jpg` et `src/shared/DinoModels/<Espece>.luau`, ajoutés par leur nom.

## 7. Chimères (fusion hybride : briefs 8 et 9)

Une chimère est assemblée en jeu à partir des données de ses deux parents (aucun modèle Blender en plus) :
`HybridBuilder` (brief 8) fabrique une `Data` et l'enregistre avec `DinoBuilder.Register(cle, data)` ; elle se construit
et s'anime ensuite comme une espèce (`DinoBuilder.Build(cle, ...)`, `DinoAnimController`).

- **Assemblage** (GDD) : la tête (groupe `Head` : `Neck1..N`, `Head`, `Jaw`, `Lid`, `Frill`, `Crest`) vient de A ; le corps,
  les pattes, les bras et la queue (`Body`, `Legs`, `Arms`, `Tail`) viennent de B ; les ailes (`Wings`) ou nageoires
  (`Fins`) viennent de celui qui en a (de B si les deux en ont).
- **Greffe de la tête** : `Neck1` de A est rattaché au `Chest` de B, son pivot posé sur le pivot `Neck1` de B, et toute la
  tête est mise à l'échelle `largeur du cou de B / largeur du cou de A` (bornée entre 0,6 et 1,6) pour que le cou raccorde.
  Les ailes : `Wing1` rattaché au `Chest` de B, au niveau des épaules de B, à l'échelle de B. Les nageoires : `FinF` sur le
  `Chest`, `FinB` sur les `Hips` de B.
- **Ce que chaque espèce doit garantir pour que ça marche** : les noms d'os standard ci-dessus, un `Neck1` présent (même
  court) placé à l'avant et en haut du `Chest`, tout ce qui bouge avec la tête sous `Neck1`, la queue sous `Hips`.
  `models/tests/run.py` vérifie que chaque os appartient à un seul groupe.
- **Taille** (validée par Snaky le 2026-10-11) : la chimère prend la BaseSize de B (le corps donne la silhouette) ;
  à la fusion elle garde la meilleure taille tirée des deux parents (Small, Normal, Big, Huge) et la meilleure mutation,
  comme la fusion Upgrade.
- **Animations** : pour chaque état, les os du corps jouent l'animation de B (famille de B), ceux de la tête et des
  ailes ou nageoires jouent l'animation de A du même nom (GDD : « la tête et les ailes gardent leurs propres animations »).
  Des ailes greffées sur un corps qui marche ne prennent pas la marche du volant (mains au sol) : elles restent repliées
  sur le dos et battent seulement en Happy, Roar, Fusion et Index.
- **Budget** : viser 450 pièces. Le brief 9 a rendu les 12 chimères (face, profil, chaque état) et corrigé les raccords
  (`models/hybrids/README.md`) ; Tricera-Stego reste à 493 pièces en attendant l'avis de Snaky.

## 8. Blocs fossiles (brief 9) et miniatures (brief 17)

- Blocs fossiles : même bibliothèque `lib/vox.py`, un modèle sans animation par rareté et un décor par biome, exportés
  dans `src/shared/BlockModels.luau` (`models/blocks/README.md`).
- Miniatures : la scène Blender `models/species/blend/<Espece>.blend` contient l'armature et une Action par état.
