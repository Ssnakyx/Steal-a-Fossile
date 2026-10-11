# La map (brief 10)

La map est construite par code au démarrage du serveur, en studs (pièces Plastic, studs sur le dessus, formes rondes en
escalier), toujours identique (graine `Config.Map.Seed`). Rien n'est enregistré dans la place : tout est dans git.

## Fichiers

```
src/shared/Config/Map.luau        mesures (parcs, place, route, longueur des zones), gisements, budgets
src/server/Services/MapService.luau  construit Workspace.Map (Priority -30, avant PlotService et ZoneService)
src/server/Map/
  MapBuilder.luau                 assemble tout : 5 parcs, place, 8 zones, murs invisibles, falaise de fin, lumière
  Kit.luau                        briques : pièces, décor inerte, disques/dômes/cônes en escalier, raycast, grille, lumières
  Props.luau                      décor : palmiers, fougères, sapins, rochers, coraux, cristaux, outils, lampes...
  Plots.luau                      un parc (palissade, portail et enseigne, cuves, enclos, treadmill, labo)
  Plaza.luau                      place du spawn, haies, lampadaires, tableau de la route, camp, forêt du fond
  ZoneBase.luau                   squelette commun d'une zone (sol, chemin, falaises, arche, gisements, nid, décor)
  Zones/<Nom>.luau                thème de chaque zone (couleurs, bords, lieu marquant, décor à éparpiller)
src/server/DebugTests/Map.luau    FossilDebug « map »
tools/luau_tests/t_map_build.luau test hors Studio
```

Si `Workspace.Map` existe déjà au démarrage (map enregistrée dans la place, ou faite à la main par un test), MapService
la garde telle quelle.

## Disposition

- Sol à `Y = 1`. Les 5 parcs (serveurs de 5 joueurs, `Config.Map.Plots.Count`) sont côte à côte sur X (Plot1 à
  gauche), entrée au bord `Z = 0`, fond à `Z = -120`. Le parc du milieu (Plot3) est en face de la route. La place fait
  la largeur des parcs + 26 studs de chaque côté.
- La place du spawn va de `Z = 0` à `Z = 70`. La route part du milieu de la place vers +Z.
- Zones bout à bout : Beach 220, Fern Forest 240, Swamp 250, Canyon 260, Glacier 270, Volcano 280, Ocean Trench 290,
  Meteor Crater 300 studs (`Config.Map.Zones`). Fin de la route à `Z = 2180`, falaise de fin derrière.
- Couloir jouable de 180 studs, chemin central de 24 studs, falaises de 36 studs de chaque côté puis un plateau. Murs
  invisibles (`Barrier`) au bord du couloir, autour de la place et au bout de la route.
- Dans chaque zone : arche à l'entrée (nom et vitesse conseillée), 3 gisements de 4 places (`Config.Map.Sites`), clairière
  du gardien au milieu du chemin (60 % de la longueur, rayon 30), lieu marquant, décor.

## Points d'ancrage (docs/BOUCLE.md)

| Où | Nom | Ce que c'est |
|---|---|---|
| `Map.Plots.PlotN` | `Floor` | sol du parc (80 x 120), zone sûre |
| | `Spawn` | point d'apparition, tourné vers la route |
| | `Entrance` | tapis à la couleur du parc, dans l'entrée |
| | `Sign` | enseigne du portail : `Label` (face extérieure, écrite par PlotService) et `LabelInside` (recopiée par MapService) |
| | `Tank1`..`Tank6` | verre des cuves (bloc au centre) |
| | `Enclosure` | herbe de l'enclos (70 x 67), les dinos regardent vers +Z |
| | `Treadmill` | tapis du treadmill, tagué « Treadmill » |
| | `Lab` | console du labo de fusion |
| `Map.Zones.<Zone>` | `Area` | étendue de la zone (couloir + falaises), invisible |
| | `Arch` | enseigne de l'arche : `Label` (face vers le spawn) et `LabelBack`, avec `Title` et `Speed` |
| | `DigSites/SiteN` | terre du gisement, `Slot1`..`Slot4` (Attachments) |
| | `Guardian` | centre du nid, tourné vers le spawn |

Chaque parc a aussi une couleur (portail, drapeaux, tapis d'entrée) pour qu'on reconnaisse le sien de loin.

## Règles du décor

- Tout ce qui est dans un dossier `Decor` est inerte : `CanCollide`, `CanQuery`, `CanTouch`, `CastShadow` à false
  (vérifié par les tests). Les volumes solides (falaises, piliers de l'arche naturelle, blocs de glace, tronc creux,
  météorite) sont dans le dossier `Ground` de la zone : le décor se pose dessus par raycast.
- Le décor est posé par raycast sur le sol de la zone, en évitant une grille de places réservées (chemin, gisements et
  leurs embranchements, clairière du gardien, arche, lieux marquants, décor déjà posé).
- Budgets : 6 lumières par zone, 2 par parc, 10 sur la place ; 2200 pièces par zone au plus (environ 15 400 pièces en
  tout). Les modèles de décor sont en `ModelStreamingMode = Atomic` (StreamingEnabled est activé).
- Lumière du jour, brume légère et bloom modéré : `MapBuilder.Lighting()` (ne remplace pas un effet déjà présent).

## Voir la map dans Studio sans lancer le jeu

Barre de commande (mode édition) :

```lua
local MapBuilder = require(game.ServerScriptService.Server.Map.MapBuilder)
local map, stats = MapBuilder.Build(workspace, { Yield = true }) ; MapBuilder.Lighting() ; print(stats.Parts)
```

Supprimer ce `Workspace.Map` avant de lancer Play (sinon MapService le garde tel quel, sans les derniers changements).
Pendant un Play : `game.ServerScriptService.FossilDebug:Invoke("map")`.

## Changer une zone

Les couleurs, le décor éparpillé (`Scatter` : modèle, nombre, rayon réservé, bande de X, échelle), les bords spéciaux
(mer de la Beach, murs d'eau de l'Ocean Trench) et le lieu marquant sont dans `src/server/Map/Zones/<Nom>.luau`. Les
mesures communes sont dans `Config/Map.luau`. Après un changement : `python tools/luau_tests/run.py map` (budgets,
ancrages, décor inerte) puis un coup d'œil dans Studio.
