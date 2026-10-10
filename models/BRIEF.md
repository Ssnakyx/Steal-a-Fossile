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

## 2. Règles de style et de modération

- Tout en studs : cubes, formes rondes en escalier, couleurs plates. Plastic (studs sur les dessus d'au moins 1 x 1 stud),
  `Smooth` pour les petits détails (yeux, griffes, dents, bouche).
- **450 pièces au plus** (affiché par `--stills`). Si c'est trop : moins de frontières de couleur, formes plus carrées
  (`power=2.9` sur les ellipsoïdes du corps), voxel un peu plus gros, plaques droites + rotation de repos.
- Modération : cous, queues et os en **segments épais empilés** ; jamais de « tube + boule », jamais de sphères par paires.
  Regarder chaque rendu de contrôle (face et profil) avant d'exporter et refuser toute forme ambiguë.
- Personnalité (`PERSONALITY`) : `tempo` (1 = normal, 1,4 nerveux, 0,75 lourd), `weight`, `stride`, `bob`, `headBob`
  (tête d'oiseau), `tail`, `diet` (`meat`, `plants`, `fish`), `happy`, `catch`. Exemple : Compy tempo 1,4, T-Rex 0,75.

## 3. Fabriquer et vérifier

1. `python models/build.py <Espece> --stills` jusqu'à ce que le modèle soit beau (lire `models/previews/<Espece>/<Espece>_controle.jpg`).
2. `python models/build.py <Espece>` : toutes les animations, l'export Luau, la planche et la vidéo.
3. Regarder la planche **et** des images de la vidéo (pieds qui ne glissent pas sur le damier qui défile, pas de patte
   retournée, boucles sans saut, impact au bon moment). Corriger la personnalité ou, si un état ne va pas pour l'espèce,
   le signaler au coordinateur (les familles sont partagées).
4. `python models/tests/run.py` doit finir par `@@ dino: N OK / 0 FAIL`.
5. Ajouter l'espèce si besoin dans `src/shared/Config/Species.luau` (demander au coordinateur : fichier du brief 2).

## 4. Gardiens

Un gardien = la même espèce construite plus grande (`DinoBuilder.Build(espece, { Scale = 2 })`, x1,5 à x3). Ses états
(Sleep, Wake, Roar, Run, Catch, Search, Return, BackToSleep) sont déjà dans chaque famille.

## 5. Livrer à Snaky

Par lots de 4 espèces : la planche et la vidéo de chaque espèce (`models/previews/<Espece>/`), envoyées dans le thread, avec
une phrase par espèce (taille, nombre de pièces, ce qui est particulier). Commits : `models/species/<Espece>.py`,
`models/previews/<Espece>/*.jpg` et `src/shared/DinoModels/<Espece>.luau`, ajoutés par leur nom.

## 6. Briefs 9 (blocs, hybrides) et 17 (miniatures)

- Blocs fossiles : même bibliothèque `lib/vox.py`, un modèle sans animation (pas besoin d'os sauf `Hips`).
- Hybrides : `DinoBuilder.Decode` / `DinoBuilder.Register(cle, data)` ; une donnée assemblée prend la tête (groupe `Head`)
  de A et le corps (`Body`, `Legs`, `Arms`, `Tail`) de B, les ailes (`Wings`) ou nageoires (`Fins`) de celui qui en a ;
  les pistes d'animation se prennent par groupe (corps de B, tête de A).
- Miniatures : la scène Blender `models/species/blend/<Espece>.blend` contient l'armature et une Action par état.
