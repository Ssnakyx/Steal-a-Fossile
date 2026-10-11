# Blocs de fossiles (brief 9)

Le serveur pose toujours un simple cube de la couleur de la rareté (`FossilBlock` sur un gisement, `DroppedFossil` au
sol, `CarriedFossil` sur le dos, `TankBlock` dans une cuve). Chaque client l'habille avec un bloc de roche en briques :
`src/client/Controllers/FossilBlockController.luau` construit le modèle de `src/shared/BlockModels.luau` près de la
caméra et cache le cube (au loin, le cube reste). Le bloc montre seulement sa rareté (GDD : l'espèce est une surprise)
et, en plus, le biome où il a été trouvé (demande de Snaky).

## Fabriquer

```
python models/blocks/build.py              export Luau + rendus de contrôle (Blender)
python models/blocks/build.py --export     seulement l'export Luau (sans Blender)
python models/blocks/build.py --stills     seulement les rendus de contrôle
```

`blocks.py` décrit les blocs en voxels (`models/lib/vox.py`, grille de 17 cases pour 3 studs). L'export écrit la section
générée de `BlockModels.luau` (entre les lignes `>>>` et `<<<`) ; le reste du module (apparences, construction) est écrit
à la main. Rendus : `models/previews/blocks/<Rareté>.jpg` (face, trois-quarts, dos, dessus), `_blocs.jpg` (les 7
raretés à leur taille en jeu à côté de l'avatar de 5 studs), `_biomes.jpg` (le décor de chaque biome). Pas de vidéo.

## Un bloc

Le même squelette en relief pour toutes les raretés : crâne devant (-Z), côtes à droite, queue à gauche ; le décor du
biome derrière et sur la moitié arrière du dessus ; les cristaux de la rareté sur la moitié avant du dessus. Os en
segments carrés épais, vertèbres en blocs (formes sûres pour la modération). La roche est un cube biseauté de 4 boîtes :
45 à 78 pièces par rareté, 9 à 27 de décor, 110 au plus par bloc (vérifié par les tests et `FossilDebug blocks`).

| Rareté | Roche | Os | Cristaux | Lumière | Taille |
|---|---|---|---|---|---|
| Common | grise | blancs | aucun | non | x1 |
| Uncommon | verte | blancs | 2 pousses vertes | non | x1,06 |
| Rare | bleue | blancs | 3 cristaux de verre bleu | non | x1,14 |
| Epic | violette | blancs | 6 cristaux de verre violet | non | x1,24 |
| Legendary | orange | en or (Foil) | 7 cristaux Neon jaunes qui battent | oui, bat | x1,38 |
| Mythic | rouge, base de lave Neon | blancs | 7 cristaux Neon orange qui battent | oui, bat | x1,55 |
| Secret | couches arc-en-ciel qui tournent | nacrés (Foil) | 9 cristaux Neon arc-en-ciel | arc-en-ciel | x1,8 |

Les tailles et lumières sont dans `BlockModels.Looks` (`SCALES` vient de `blocks.py`). Un bloc plus gros que le cube du
serveur grandit vers le haut (il reste posé au sol) et vers l'arrière sur le dos d'un joueur ; dans une cuve, il est
limité à x1,6 (`BlockModels.TankScale`). Réglés dans Studio : lumières faibles (plus fortes, le sol autour virait au
blanc avec le Bloom du jeu) ; os du Secret en Foil nacré (en Neon blanc, le halo effaçait le crâne).

## Décor des biomes

| Zone | Décor |
|---|---|
| Beach | sable autour, étoile de mer orange au dos, galets |
| Fern Forest | mousse sur le dessus, fronde de fougère, trois feuilles |
| Swamp | boue, coulures, liane, nénuphar et fleur rose |
| Canyon | corniches de terre cuite, strate, galets |
| Glacier | calotte de glace, stalactites, neige au pied |
| Volcano | basalte au pied, croûte, braises Neon, cendre |
| Ocean Trench | sable, balanes, algues, coraux |
| Meteor Crater | sol sombre, météorite, trois éclats violets Neon, étoiles Neon |

Le décor vient de l'attribut `Zone` de la pièce du serveur (nom de `Config.Zones`) : posé par `DigSiteService`, et
depuis le brief 9 par `CarryService` (bloc porté) et `ReviveService` (bloc dans une cuve). Sans `Zone`, pas de décor.

## En jeu

```lua
BlockModels.Build(rarity, size?, zone?) -> Model?     -- pièce invisible Root au centre (PrimaryPart, porte la lumière)
BlockModels.SideOf(rarity, side, kind?) -> number     -- côté en jeu (taille de la rareté, limite des cuves)
BlockModels.Count(rarity, zone?) -> number            -- pièces, décor et Root compris
BlockModels.Looks[rarity]                             -- Scale, Light, Range, LightColor, Pulse, Rainbow
FossilBlockController.SetAura(function(model, info) ... return cleanup end)
```

`SetAura` est le point d'accroche du thread des auras : la fonction est appelée pour chaque bloc construit (et ceux
déjà construits), avec `info = { Rarity, Zone?, Kind, Size, Part, Own }` ; la fonction qu'elle renvoie est appelée quand
le bloc est défait. Ce module ne fait pas d'aura lui-même.

Modèle construit à moins de 170 studs de la caméra, défait au-delà de 210 ; battement et arc-en-ciel à moins de
140 studs. StreamingEnabled : une pièce qui repart est oubliée, une pièce qui revient est rhabillée. Le dossier
`Workspace.FossilBlockModels` porte les attributs `Tracked` et `Built` (et `Error` si la boucle échoue).

Tests : `python3 tools/luau_tests/run.py blocks` (modèles, habillage chez le client, commande de debug). Dans Studio :
`game.ServerScriptService.FossilDebug:Invoke("blocks")`.
