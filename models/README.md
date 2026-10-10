# models : les dinos de Steal a Fossil (Blender -> données studs)

Chaque dino est un modèle voxel découpé en os, animé dans Blender, puis exporté en **données Luau**
(`src/shared/DinoModels/<Espece>.luau`). En jeu, `DinoBuilder` le reconstruit en vraies briques Roblox et
`DinoAnimController` le fait bouger. Rien n'est uploadé : pas de mesh, pas de file de modération.

## Lancer

Il faut Blender 5.2 (`C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`, ou la variable `BLENDER`) et,
dans le Python du système, Pillow et imageio-ffmpeg.

```
python models/build.py Velociraptor              # tout : contrôle, animations, export Luau, planche + vidéo
python models/build.py Velociraptor --stills     # seulement les rendus de contrôle (face, trois-quarts, profil, dos)
python models/build.py Velociraptor --bake       # animations + export Luau, sans rendu (rapide)
python models/build.py Velociraptor --clips Walk,Run    # aperçu de quelques animations seulement
python models/tests/run.py                       # test hors Studio (luau) : données, lecture, même pose que les aperçus
```

Sorties :
- `src/shared/DinoModels/<Espece>.luau` : modèle + animations (généré, ne pas modifier à la main) ;
- `models/previews/<Espece>/` : `_controle.jpg` (repos, avec un avatar de 5 studs), `_planche.jpg` (6 instants par état),
  `_animations.mp4` (tous les états à la suite, vue trois-quarts + profil, nom de l'état à l'écran) ;
- `models/species/blend/<Espece>.blend` : la scène Blender (armature + une Action par état), ignorée par git.

## Comment ça marche

1. `species/<Espece>.py` décrit le modèle avec `lib/vox.py` : os (pivots aux articulations), formes (ellipsoïdes,
   segments effilés, boîtes, plaques), peinture, yeux avec paupières, symétrie gauche/droite, points (pieds, mains...).
   Il donne aussi `FAMILY` et `PERSONALITY` (cadence, poids, foulée, régime, style de joie et d'attaque).
2. `lib/vox.py` fusionne les voxels en boîtes (une pièce par boîte) : les voxels cachés servent de jokers, une pièce peut
   les traverser quelle que soit leur couleur. Budget : **450 pièces au plus** par modèle.
3. La famille (`lib/fam_biped.py`, `fam_quadruped.py`, `fam_flyer.py`, `fam_swimmer.py`) écrit tous les états avec
   `lib/anim.py` (clés + courbes d'arrivée, couches additives) et `lib/motion.py` (souffle, clignements, regard, ondulation
   de queue, marche). Les pattes sont en **IK** (`rig.py`) : les pieds restent posés au sol quand le corps bouge.
   Les ailes du volant sont posées par orientation et ses mains par une IK en 3D.
4. `lib/blender_job.py` (dans Blender) construit l'armature (un os Blender par os du modèle, axes Roblox) et le maillage,
   écrit **une Action par état** (clés à 60 images/s), relit les courbes, réduit les clés, exporte le Luau et rend les
   images ; `lib/post.py` assemble la planche et la vidéo.

Repère : X droite, Y haut, le dino regarde vers **-Z**, pieds à Y = 0. Rotations en degrés dans l'ordre de
`CFrame.Angles` (Rx * Ry * Rz) : `rx > 0` lève le nez, `ry > 0` tourne la tête vers la gauche (-X). Os gauches en `L`
(côté -X), droits en `R`.

## Format des données (`src/shared/DinoModels/<Espece>.luau`)

- `Bones` : `{ Name, Parent, Pivot, Rest? }` (pivot en studs, `Rest` = rotation de repos en degrés, ex. collerette).
- `Paints` + `Boxes` : boîtes en coordonnées voxel entières `{ os, x0, y0, z0, x1, y1, z1, peinture }` ;
  centre en studs = `((x0 + x1 + 1) / 2 - Origin.X) * Voxel`, taille = `(x1 - x0 + 1) * Voxel`.
- `Groups` : os par groupe (`Head`, `Body`, `Tail`, `Legs`, `Arms`, `Wings`, `Fins`) pour les hybrides.
- `Points` : `{ os, position }` (ToeL/R, FrontToeL/R, HandL/R, WingTipL/R).
- `Anims[Etat]` : `Length`, `Loop`, `Next` (état joué ensuite), `Speed` (studs/s de la marche à l'échelle 1),
  `Events` (`{ t, "Step", "FootL" }`, `"Roar"`, `"Hit"`, `"Splash"`), `Tracks = { { os, canal, { image, valeur, ... } } }`
  avec image = t x 60, canaux 1-3 rotations (degrés), 4-6 déplacements (studs). Lecture : cubique monotone (pchip),
  identique en Python (`anim.game_sample`) et en Luau (`DinoBuilder.Sample`).

## États

Communs : Idle (+ variantes IdleSniff, IdleScratch, IdleStretch, IdleShake, IdleYawn jouées au hasard), Walk, Run, Happy,
Roar, Eat, Sleep, Spawn, Wake, Catch (événement `Hit`), Search, BackToSleep, Fusion, Index. Gardiens : Sleep, Wake, Roar,
Run, Catch, Search, Return (= Walk), BackToSleep. Volants en plus : TakeOff, Fly, Glide, Land. Nageurs en plus : Dive, Jump.

## En jeu

```lua
local DinoBuilder = require(ReplicatedStorage.Shared.DinoBuilder)
-- serveur : un modèle léger (pièce Root invisible + attributs), le client construit et anime les briques
local dino = DinoBuilder.CreateProxy("Velociraptor", { Size = "Big", Mutation = "Amber" })
dino:PivotTo(cf) ; dino.Parent = workspace
dino:SetAttribute("State", "Walk") ; dino:SetAttribute("StateAt", workspace:GetServerTimeNow())
dino:SetAttribute("Speed", 6)      -- la marche se cale sur la vitesse : pas de pieds qui glissent
```

`DinoAnimController` (client) anime tout modèle tagué `Dino` : fondus de 0,2 s, variantes d'Idle au hasard, cadence plus
lente pour les gros, animation complète près de la caméra, cadence réduite au loin, figée hors de vue ou très loin.
`DinoAnimController.Event` signale les pas, rugissements et impacts des dinos proches (effets du brief vfx).
Pour un ViewportFrame (Index) : `DinoBuilder.Build(...)`, attribut `AlwaysAnimate = true`, `DinoAnimController.Register`.
Tailles (`DinoBuilder.Sizes`) : Small 0,75, Normal 1, Big 1,5, Huge 2,5 ; option `Scale` en plus (gardiens x1,5 à x3).
Mutations Amber, Crystal, Lava et niveaux Golden, Diamond : couleurs et matières dans `DinoBuilder` (première version,
le brief blocs-hybrides affine Golden et Diamond).

Ajouter une espèce : voir `models/BRIEF.md`.
