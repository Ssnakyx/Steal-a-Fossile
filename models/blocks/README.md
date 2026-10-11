# Blocs de fossiles (brief 9)

Le serveur pose toujours un simple cube de la couleur de la rareté (`FossilBlock` sur un gisement, `DroppedFossil` au
sol, `CarriedFossil` sur le dos, `TankBlock` dans une cuve). Chaque client l'habille avec un bloc en briques :
`src/client/Controllers/FossilBlockController.luau` construit le modèle de `src/shared/BlockModels` près de la caméra
et cache le cube (au loin, le cube reste). Le bloc montre sa rareté par sa couleur (GDD : l'espèce est une surprise)
et son biome par sa forme. Demande de Snaky : aucun bloc ne doit ressembler à un autre.

## Fabriquer

```
python models/blocks/build.py                  export Luau + rendus de contrôle (Blender)
python models/blocks/build.py --export         seulement l'export Luau (sans Blender)
python models/blocks/build.py --stills         seulement les rendus de contrôle
python models/blocks/build.py --stills Beach   rendus d'une seule zone
```

`blocks.py` décrit les blocs en voxels (`models/lib/vox.py`, grille de 17 cases pour 3 studs). L'export écrit
`src/shared/BlockModels/Data.luau` (généré, ne pas modifier à la main) ; `BlockModels/init.luau` (écrit à la main)
assemble les modèles et donne les apparences. Rendus, tous à la même échelle (pas de vidéo) :
`models/previews/blocks/_formes.jpg` (les 56 blocs de trois-quarts avant, une ligne par biome, une colonne par
rareté, et les cubes sans biome), `_formes_dos.jpg` (les mêmes de dos), `<Zone>.jpg` (les 7 raretés d'une zone à leur
taille en jeu à côté de l'avatar de 5 studs, puis de face et de dos).

## Une forme par biome

| Zone | Forme | Fossile en relief | Décor |
|---|---|---|---|
| Beach | ammonite dressée sur la tranche | spirale de la coquille | à moitié dans le sable, étoile de mer au dos, galets |
| Fern Forest | souche pétrifiée, bord déchiqueté, racines | fronde de fougère | cernes, mousse, pousse de fougère |
| Swamp | butte de boue basse en terrasses | mâchoire de crocodile | nénuphar et fleur, deux massettes, coulures, liane |
| Canyon | cheminée de fée (colonne étroite, chapeau large) | colonne de vertèbres | strates, cactus, cailloux |
| Glacier | grappe de cristaux de glace à pointe | crâne pris dans la glace | trois cristaux penchés, neige |
| Volcano | volcan en terrasses à cratère | griffe à trois serres | lave dans le cratère et coulée au dos, basalte, braises |
| Ocean Trench | coquille Saint-Jacques dressée | côtes qui rayonnent et dentellent le bord | sable, bernacles, algues, corail |
| Meteor Crater | météorite bosselée | cage thoracique | bord du cratère d'impact, éclats violets, étoiles |

Sans biome connu (vieille sauvegarde, zone vide), le bloc est un cube biseauté avec un crâne, des côtes et une queue.

## Ce que change la rareté

| Rareté | Couleur | Signe en plus | Cristaux | Lumière | Taille |
|---|---|---|---|---|---|
| Common | grise | aucun | aucun | non | x1 |
| Uncommon | verte | deux pousses | 2 | non | x1,06 |
| Rare | bleue | cristaux de verre | 3 | non | x1,14 |
| Epic | violette | fendu en V, coeur violet qui brille au fond | 4 en verre | non | x1,24 |
| Legendary | orange | os en or, posé sur un socle d'or | 5 Neon | oui, bat | x1,38 |
| Mythic | rouge | fissures de lave, trois morceaux qui flottent au-dessus | 5 Neon | oui, bat | x1,55 |
| Secret | couches arc-en-ciel qui tournent | os nacrés, en lévitation au-dessus de pierres, quatre éclats qui tournent autour | 6 Neon arc-en-ciel | arc-en-ciel | x1,8 |

Les cristaux se placent seuls sur le haut de chaque forme (étalés, penchés vers l'extérieur). Les tailles et lumières
sont dans `BlockModels.Looks`. Un bloc plus gros que le cube du serveur grandit vers le haut (il reste posé au sol) et
vers l'arrière sur le dos d'un joueur ; dans une cuve, il est limité à x1,6 (`BlockModels.TankScale`). Réglés dans
Studio : lumières faibles (plus fortes, le sol autour virait au blanc avec le Bloom du jeu) ; os du Secret en Foil
nacré (en Neon blanc, le halo effaçait le fossile).

Peu de pièces : formes en terrasses aux coins coupés (5 briques par étage), pièces penchées d'une seule brique
(côtes de la coquille, cristaux de glace, bosses de la météorite, feuilles, roseaux). Entre 35 et 101 briques par
bloc, 115 au plus (`build.py` refuse d'exporter au-delà).

## En jeu

```lua
BlockModels.Build(rarity, size?, zone?) -> Model?     -- pièce invisible Root au centre (PrimaryPart, porte la lumière)
BlockModels.Get(rarity, zone?) -> Data?               -- briques du bloc ; zone inconnue : cube sans biome
BlockModels.Biome(zone) -> string?                    -- forme du biome (Ammonite, Stump, Mound...)
BlockModels.SideOf(rarity, side, kind?) -> number     -- côté en jeu (taille de la rareté, limite des cuves)
BlockModels.Count(rarity, zone?) -> number            -- briques, Root comprise
BlockModels.Looks[rarity]                             -- Scale, Light, Range, LightColor, Pulse, Rainbow
FossilBlockController.SetAura(function(model, info) ... return cleanup end)
```

Les briques portent leur rôle dans leur nom : `Rock`, `Fossil`, `Glow` (coeur, lave), `Rainbow`, `Base` (socle,
pierres), `Biome`, `Ember`, `Gem`, `Deco`, `Float`, `Orbit` ; les quatre derniers ont leur numéro en attribut du même
nom. Le modèle porte les attributs `Rarity`, `Zone`, `Form`, `Scale`.

Près de la caméra et à l'écran, le contrôleur fait battre la lave, le coeur, les cristaux Neon et la lumière, tourner
les couleurs du Secret, monter et descendre doucement les morceaux qui flottent et tourner les éclats du Secret autour
du bloc. `SetAura` est le point d'accroche du thread des auras : la fonction est appelée pour chaque bloc construit (et
ceux déjà construits), avec `info = { Rarity, Zone?, Kind, Size, Part, Own }` ; la fonction qu'elle renvoie est appelée
quand le bloc est défait. Ce module ne fait pas d'aura lui-même.

Le décor vient de l'attribut `Zone` de la pièce du serveur (nom de `Config.Zones`) : posé par `DigSiteService`,
`DroppedBlockService`, `CarryService` (bloc porté) et `ReviveService` (bloc dans une cuve).

Modèle construit à moins de 170 studs de la caméra, défait au-delà de 210 ; mouvements à moins de 140 studs.
StreamingEnabled : une pièce qui repart est oubliée, une pièce qui revient est rhabillée. Le dossier
`Workspace.FossilBlockModels` porte les attributs `Tracked` et `Built` (et `Error` si la boucle échoue).

Tests : `python3 tools/luau_tests/run.py blocks` (les 63 modèles : au sol, au budget, de la couleur de la rareté, tous
différents ; habillage chez le client, mouvements ; commande de debug). Dans Studio :
`game.ServerScriptService.FossilDebug:Invoke("blocks")`.
