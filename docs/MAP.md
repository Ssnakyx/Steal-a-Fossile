# La map (brief 10)

La map est construite par code au démarrage du serveur, en studs (pièces Plastic, studs sur le dessus, formes rondes en
escalier), toujours identique (graine `Config.Map.Seed`). Rien n'est enregistré dans la place : tout est dans git.

## Fichiers

```
src/shared/Config/Map.luau        mesures (parcs, place, route, longueur des zones), gisements, budgets
src/shared/Config/Ambience.luau   ambiance de la place et de chaque zone (ciel, lumière, brume, particules, ciel animé)
src/server/Services/MapService.luau  construit Workspace.Map (Priority -30, avant PlotService et ZoneService)
src/server/Map/
  MapBuilder.luau                 assemble tout : 5 parcs, place, 8 zones, murs invisibles, falaise de fin, lumière
  Kit.luau                        briques : pièces, décor inerte, disques/dômes/cônes en escalier, raycast, grille, lumières
  Props.luau                      décor : palmiers, fougères, sapins, rochers, coraux, cristaux, outils, lampes, et les
                                  objets propres à chaque zone (nids d'œufs, cactus, geysers de lave, coffres...)
  Plots.luau                      un parc (palissade, portail et enseigne, cuves, enclos, treadmill, labo)
  Plaza.luau                      place du spawn, haies, lampadaires, tableau de la route, camp, forêt du fond
  ZoneBase.luau                   squelette commun d'une zone (sol, chemin, falaises, arche, gisements, nid, décor)
  Zones/<Nom>.luau                thème de chaque zone (couleurs, bords, lieu marquant, décor à éparpiller)
src/client/Controllers/AmbienceController.luau  ambiance chez chaque joueur selon l'endroit où il est
src/server/DebugTests/Map.luau    FossilDebug « map » et « ambience »
tools/luau_tests/t_map_build.luau    test hors Studio de la map
tools/luau_tests/t_map_ambience.luau test hors Studio des ambiances et du décor lumineux
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
  météorite, igloos, coque de l'épave) sont dans le dossier `Ground` de la zone : le décor se pose dessus par raycast.
- Le décor est posé par raycast sur le sol de la zone, en évitant une grille de places réservées (chemin, gisements et
  leurs embranchements, clairière du gardien, arche, lieux marquants, décor déjà posé).
- Budgets : 6 lumières par zone, 2 par parc, 10 sur la place ; 2200 pièces par zone au plus (environ 16 500 pièces en
  tout, la plus chargée est la Fern Forest avec environ 2 000). Les modèles de décor sont en
  `ModelStreamingMode = Atomic` (StreamingEnabled est activé).
- Le décor lumineux brille par le Neon et le bloom, sans PointLight en plus (les 6 lumières par zone sont déjà prises).
- `Theme.Wall` : décor qui sort des parois des falaises (cristaux), trouvé par un raycast horizontal depuis le couloir
  (rien n'est posé si la paroi est trop en retrait, par exemple au bord de la mer).
- `ZoneBase.Spot` : trouve une place libre pour un lieu marquant (hors du chemin, des gisements et du nid du gardien).
- Dans une liste `Scatter`, ce qui vient d'abord a la place : le décor lumineux est juste après les grands arbres et
  rochers, avant le petit décor de remplissage (fougères, buissons, herbes).
- Ambiance de la place au démarrage : `MapBuilder.Lighting()` (règle les effets déjà présents plutôt que les doubler).

## Ambiances (ciel, lumière, particules)

Chaque zone a son ambiance, appliquée chez chaque joueur seulement (`AmbienceController`, côté client) selon le Z de
son personnage (la caméra s'il n'en a pas) : fondu sur 70 studs autour de chaque frontière, et en douceur (environ 2 s)
après une téléportation. Toutes les valeurs sont dans `src/shared/Config/Ambience.luau` : heure du jour, luminosité,
lumière ambiante, teinte du soleil, brume (`Atmosphere`), nuages du Terrain, étoiles, taille du soleil et de la lune,
couleurs (`ColorCorrectionEffect` « AmbienceGrade »), bloom, rayons du soleil, particules, aurores, planète, étoiles
filantes, ptérosaures.

| Zone | Ambiance | Vivant |
|---|---|---|
| Place et parcs | après-midi ensoleillé | |
| Beach | midi tropical, ciel clair | ptérosaures |
| Fern Forest | matin doré, brume légère | lucioles, spores, ptérosaures |
| Swamp | fin d'après-midi, brume verte | beaucoup de lucioles |
| Canyon | heure dorée, ciel orangé | poussière, ptérosaures |
| Glacier | aube rose | neige, aurores |
| Volcano | crépuscule rouge, nuages de cendre | braises, cendres |
| Ocean Trench | bleu profond | bulles, plancton, rayons du soleil |
| Meteor Crater | nuit étoilée violette | poussière d'étoiles, aurores, planète à anneau, étoiles filantes |

- Particules : petits cubes (style studs, aucune texture), 64 au plus autour du joueur, recyclés.
- Ciel animé : aurores en rubans, planète, étoiles filantes et ptérosaures suivent la caméra, très loin (260 studs).
- Toutes ces pièces sont dans un dossier `Ambience` de la caméra : chez le joueur seulement, sans collision ni requêtes.
- Lighting n'est écrit que pendant un fondu (20 fois par seconde au plus), plus du tout quand l'ambiance est atteinte.
- Les effets de couleur des autres systèmes (StressController...) s'ajoutent à « AmbienceGrade ».
- Décor flottant : les modèles tagués `AmbientFloat` (feux follets, méduses, éclats de cristal, rochers flottants, jets
  de lave, vapeur, bulles ; `Kit.float`) montent, descendent et tournent chez le joueur, dans un rayon de 220 studs.
  Réglages : attributs `FloatHeight`, `FloatSpeed`, `FloatSpin` ; la pièce centrale est le `PrimaryPart`. Un modèle
  flottant peut être dans un autre (le jet d'une fontaine de lave) : seul le jet bouge.
- Décor lumineux (`Props`) : `glowCrystal` (grappe de cristaux, jusqu'à 4 couleurs : `Crystal`..`Crystal4`),
  `glowShroom`, `geode`, `wisp`, `jellyfish`, `anemone`, `floatShard`, `lavaPool`, et les fossiles `ribcage` et `skull`.
- Objets propres à chaque zone (on ne les voit nulle part ailleurs, vérifié par le test) :

| Zone | Objets |
|---|---|
| Beach | nids d'œufs (un bébé dino sort de sa coquille), barques échouées, flaques de marée qui luisent, cristaux vert d'eau |
| Fern Forest | fleurs géantes lumineuses (rose, bleu, jaune), traces de pas de dino, champignons lumineux |
| Swamp | plantes carnivores, mares de vase qui luisent, feux follets, champignons lumineux |
| Canyon | cactus, virevoltants, géodes, cristaux |
| Glacier | bonshommes de neige, camp polaire (2 igloos solides, feu de camp, traîneau), bosquet de cristaux |
| Volcano | mares et fontaines de lave, fumerolles qui crachent de la vapeur, cristaux couleur braise |
| Ocean Trench | épave de navire (coque solide, hublots qui luisent, voile déchirée), coffres au trésor, bouches à bulles, méduses, anémones |
| Meteor Crater | morceaux de météorite fendus de vert, rochers qui flottent, camp des chercheurs (tente, télescope, tableau de calculs) |

- Lieux marquants : squelette sur la plage, cercle de pierres moussues (Fern Forest), pont de cordes et squelette
  dégagé par les fouilles (Canyon), squelette pris dans la glace, bosquet de cristaux et camp polaire (Glacier), panache
  de fumée du volcan, ammonite géante et épave (Ocean Trench), éclats flottants au-dessus du grand cratère, flèche de
  cristaux géants et camp des chercheurs (Meteor Crater).

Régler une ambiance : changer les valeurs dans `Config/Ambience.luau`, lancer Play et aller dans la zone (commande
d'admin `tpzone 1` à `tpzone 8`, `tpzone 0` pour rentrer). Les valeurs se mélangent pendant les fondus : pas besoin
qu'elles se ressemblent d'une zone à l'autre. Pendant un Play : `game.ServerScriptService.FossilDebug:Invoke("ambience")`.

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
