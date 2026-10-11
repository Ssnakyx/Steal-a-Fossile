# Chimères de la fusion hybride

Les chimères n'ont pas de fichier Blender : `src/shared/HybridBuilder.luau` (brief 8) les assemble en jeu à partir des
modules `src/shared/DinoModels/` de leurs deux parents. Ce dossier sert au brief 9 pour les vérifier et corriger les
raccords. Règles générales : `models/BRIEF.md` section 7 ; recettes : `src/server/ServerConfig/Fusion.luau` ; API et
règles de jeu : `docs/FUSION.md`.

## Aperçus

```
python3 models/hybrids/preview.py                  les 12 recettes
python3 models/hybrids/preview.py Ptero            seulement celles dont le nom contient « Ptero »
python3 models/hybrids/preview.py --json DOSSIER   écrit aussi chaque chimère assemblée (os, boîtes, poses) en JSON
python3 models/hybrids/preview.py --out DOSSIER    images ailleurs que dans models/previews/hybrids/
```

Le vrai code du jeu assemble chaque chimère (interpréteur Luau et faux Roblox de `tools/luau_tests`, il faut avoir lancé
`python3 tools/setup_tools.py` une fois), puis le script dessine ses boîtes en projection orthographique avec Pillow :
profil, face et dessus au repos, puis trois quarts pour Idle, Walk, Happy et Index. La silhouette grise est l'avatar
(5 studs). Sortie : `models/previews/hybrids/<Nom>.png` et la planche `_toutes.png`. Le titre de chaque image donne la
clé, la famille, le nombre de pièces et l'encombrement en studs.

Ce n'est qu'un contrôle rapide (pas de lumière, pas d'effets) : le brief 9 refait les rendus dans Blender (face, profil,
chaque état) avec `--json` comme source, ou en important les modules des deux parents.

## Assemblage

A donne la tête, B le corps. Toutes les positions sont celles des modèles à l'échelle 1 (Normal), en studs, avec
l'avant vers -Z et le sol à Y = 0.

1. **Os gardés de B** : tous sauf son groupe `Head` et ce qui pend dessous. La racine reste celle de B (`Hips`).
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
   segment, en miroir à droite) ; elles se déplient et battent seulement dans les états Happy, Roar, Fusion et Index,
   en montant plus qu'elles ne descendent (jamais sous le sol).
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

```lua
{ Name = "Ptero-Rex", Head = "Pteranodon", Body = "T-Rex", Hint = "...", Tweak = { HeadScale = 1.2, HeadPitch = 10 } },
```

Les réglages sont écrits dans la clé de la chimère (`"Pteranodon+TRex;HeadScale=1.2;HeadPitch=10"`), que le serveur
pose sur le modèle : le client la lit et assemble la même chimère. Changer un réglage change la clé, rien d'autre (les
dinos sauvegardés gardent le nom de l'hybride). Relancer `preview.py` et `python3 tools/luau_tests/run.py fusion`
(sol, os, animations de chaque recette) après chaque correction.

## Budget

450 pièces visées (`models/BRIEF.md`). Au lancement : Tricera-Stego 493 et Ptero-Rex 451 dépassent ; les autres sont
entre 203 et 439. Pour alléger, simplifier les boîtes de la tête ou du corps dans les modèles des parents, ou réduire
la tête (`HeadScale`).
