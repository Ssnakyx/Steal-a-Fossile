# Chimères de la fusion hybride

Les chimères n'ont pas de fichier Blender : `src/shared/HybridBuilder.luau` (brief 8) les assemble en jeu à partir des
modules `src/shared/DinoModels/` de leurs deux parents. Ce dossier sert au brief 9 pour les vérifier et corriger les
raccords. Règles générales : `models/BRIEF.md` section 7 ; recettes : `src/server/ServerConfig/Fusion.luau` ; API et
règles de jeu : `docs/FUSION.md`.

## Rendus (brief 9)

```
python models/hybrids/render.py                  les 12 chimères : rendu de contrôle + planche des états
python models/hybrids/render.py Ptero            seulement celles dont le nom contient « Ptero »
python models/hybrids/render.py --stills         seulement les rendus de contrôle (face, trois-quarts, profil, dos)
python models/hybrids/render.py --levels         Normal, Golden et Diamond de chaque espèce et chimère (une planche)
python models/hybrids/render.py --index          pose d'Index de chaque espèce et chimère (une planche)
```

Le vrai code du jeu assemble chaque chimère et la peint (`HybridBuilder`, `DinoBuilder.Build`) dans l'interpréteur Luau
de `tools/luau_tests` (`python3 tools/setup_tools.py` une fois), lit ses animations (`DinoBuilder.Sample`), puis Blender
(headless, comme `models/build.py`) rend chaque pose à côté de l'avatar de 5 studs. Pas de vidéo : quelques instants de
chaque état. Sorties dans `models/previews/hybrids/` : `<Nom>_controle.jpg`, `<Nom>_planche.jpg` (Idle, Walk, Happy,
Roar, Fusion, Index...), `_chimeres.jpg` (les 12 côte à côte), `_niveaux.jpg`, `_index.jpg`.

Contrôle rapide sans Blender (projection orthographique avec Pillow, pas de lumière) :

```
python3 models/hybrids/preview.py                  les 12 recettes (<Nom>.png et _toutes.png)
python3 models/hybrids/preview.py --json DOSSIER   écrit aussi chaque chimère assemblée (os, boîtes, poses) en JSON
```

## Assemblage

A donne la tête, B le corps. Toutes les positions sont celles des modèles à l'échelle 1 (Normal), en studs, avec
l'avant vers -Z et le sol à Y = 0.

1. **Os gardés de B** : tous sauf son groupe `Head` et ce qui pend dessous. La racine reste celle de B (`Hips`). Si A
   donne des ailes à un bipède, B perd aussi ses bras (groupe `Arms`) : les ailes les remplacent (brief 9 : repliées,
   elles les couvraient, et Ptero-Rex repasse sous le budget).
2. **Os greffés de A** : son groupe `Head`, ses ailes (`Wings`) si B n'a ni ailes ni nageoires, sinon ses nageoires
   (`Fins`) dans le même cas, et les os sans groupe qui pendent sous ces os. Un os greffé qui porte le nom d'un os gardé
   de B prend le suffixe `A` (`ChestA`).
3. **Tête** : la racine de la tête de A (`Neck1`) est accrochée au même os que celle de B (le `Chest`), son pivot posé
   sur le pivot `Neck1` de B. Toute la tête est mise à l'échelle largeur du cou de B / largeur du cou de A (boîtes de
   `Neck1`, sinon de toute la tête), bornée entre 0,6 et 1,6. Si une boîte de la tête passe sous Y = 0,1 au repos, la
   tête remonte d'autant.
4. **Ailes greffées** (corps qui marche) : `Wing1L` et `Wing1R` sur le `Chest`, en haut des flancs au niveau des
   épaules (pivot des bras de B, sinon entre le `Chest` et le cou). Envergure : 1,2 fois la longueur de B (bornée
   entre 0,3 et 3 fois celle de A). Au repos elles sont repliées le long des flancs (rotation ajoutée au repos de chaque
   segment, en miroir à droite) : le bras part vers l'arrière, la membrane pend le long du flanc, et l'avant-bras et le
   doigt-aile se replient en accordéon autour de l'axe de la membrane (brief 9 : repliés dans son plan, ils se
   dressaient au-dessus des épaules comme une capuche). Elles se déplient et battent seulement dans les états Happy,
   Roar, Fusion et Index, en montant plus qu'elles ne descendent (jamais sous le sol).
5. **Nageoires greffées** : `FinF` sur les flancs du `Chest` (au niveau des épaules), `FinB` sur les flancs des `Hips`
   (au niveau des cuisses), au tiers bas, à l'échelle longueur de B / longueur de A (0,5 à 1,6).
6. **Animations** : chaque état de B est gardé (durée, boucle, suite, événements). Les os de B jouent l'animation de
   B ; ceux de la tête (et des nageoires greffées) jouent l'animation de A du même nom (ou la plus proche, comme
   `DinoAnimController`), étirée à la durée de celle de B ; les translations sont mises à l'échelle de la greffe.
7. **Données** : famille, voxel et taille de base de B ; `LidDrop` de A à l'échelle de la tête ; `Size` et `Height`
   recalculés sur la pose de repos (ailes repliées comprises).

## Corriger un raccord (brief 9)

Chaque recette peut avoir un champ `Tweak` dans `src/server/ServerConfig/Fusion.luau` :

| Champ | Effet | Bornes |
|---|---|---|
| `HeadScale` | échelle de la tête (remplace le calcul automatique) | 0,2 à 4 |
| `HeadOffset` | décalage de la tête en studs, `Vector3` (repère de B) | ±40 par axe |
| `HeadPitch` | rotation de repos du cou en plus, en degrés (+ relève la tête) | ±90 |
| `LimbScale` | échelle des ailes ou nageoires greffées | 0,2 à 4 |
| `LimbOffset` | décalage des ailes ou nageoires greffées (côté gauche, en miroir à droite) | ±40 par axe |
| `LimbTurn` | rotation de repos en plus des ailes ou nageoires greffées, degrés XYZ (côté gauche, en miroir) | ±180 par axe |

```lua
{ Name = "Ptero-Rex", Head = "Pteranodon", Body = "T-Rex", Hint = "...", Tweak = { HeadScale = 1.2, HeadPitch = 10 } },
```

`HeadPitch` compte dans la remontée de la tête : une tête relevée ne passe jamais sous le sol.

Les réglages sont écrits dans la clé de la chimère (`"Pteranodon+TRex;HeadScale=1.2;HeadPitch=10"`), que le serveur
pose sur le modèle : le client la lit et assemble la même chimère. Changer un réglage change la clé, rien d'autre (les
dinos sauvegardés gardent le nom de l'hybride). Relancer `preview.py` et `python3 tools/luau_tests/run.py fusion`
(sol, os, animations de chaque recette) après chaque correction, puis `render.py <Nom>`.

Corrections faites au brief 9 (après les rendus des 12 chimères) :

| Chimère | Réglage | Pourquoi |
|---|---|---|
| Tricera-Stego | `HeadPitch = 8`, `HeadOffset = (0, 0.3, 0)` | la tête pendait trop bas devant les plaques |
| Shark-Raptor | `LimbTurn = (0, 25, 35)` | les nageoires sortaient à plat comme des planches : penchées vers le bas et l'arrière comme des pectorales de requin |
| Quetza-Carno | `HeadScale = 1.15` | le bec géant écrasait le corps |
| Plesio-Shark | `HeadPitch = 30` | la tête reposait presque au sol : le long cou se dresse devant le requin |

Les 8 autres chimères n'ont pas de réglage : leurs raccords sont bons dans les rendus.

## Budget

450 pièces visées (`models/BRIEF.md`). Après le brief 9 : Ptero-Rex 433 (ses bras remplacés par les ailes), les autres
entre 203 et 439, sauf Tricera-Stego à 493. Pour elle, rien n'est caché ni fusionnable sans perte (toutes les boîtes se
voient) : l'alléger demande d'enlever des détails visibles (taches de la collerette, plaques du dos) ; elle est restée
telle quelle en attendant l'avis de Snaky.
