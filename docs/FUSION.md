# Fusion (brief 8)

Ce que le brief 8 met en place et ce que les autres briefs peuvent utiliser : les deux modes de fusion, les chimères
assemblées en jeu, les API, les signaux, la clé replica de l'Index des hybrides et les textes renvoyés au client.
Règles et prix : `src/shared/Config/Fusion.luau` (partagé). Recettes : `src/server/ServerConfig/Fusion.luau` (serveur
seulement, jamais envoyé à un client).

## La fusion en bref

Le joueur utilise le labo de son parc (`ProximityPrompt` « Fuse » sur la pièce `Lab` du parc) et choisit ses dinos.

- **Upgrade** : 3 dinos de la même espèce et du même niveau donnent 1 dino du niveau suivant (Normal, Golden, Diamond),
  avec la meilleure taille et la meilleure mutation des trois. Diamond est le maximum.
- **Hybride** : 2 dinos d'espèces différentes. Si la paire est une recette (dans les deux sens), ils donnent la chimère
  de la recette, avec la meilleure taille et la meilleure mutation des deux, au plus petit de leurs niveaux. Revenu de
  base de l'hybride : (A + B) x 1,5. Sinon : « Unknown recipe! Your dinos are safe. Try another pair. », rien ne bouge
  et rien n'est payé.
- **Coût** d'une fusion réussie : 60 s (Upgrade) ou 120 s (Hybride) du revenu des dinos utilisés, au moins $50.
- **Où** : seulement dans son propre parc (le serveur vérifie la position du personnage).
- Le dino obtenu arrive dans l'enclos en rugissant (état `Roar`). Un hybride fusionné pour la première fois est
  « découvert » : `data.Index.Hybrids[nom] = true`, sa fiche apparaît dans l'Index.

Secret des recettes : un aperçu d'hybride pas encore découvert renvoie toujours « ??? », que la recette existe ou non.
La clé replica `Hybrids` ne donne que les indices avant la découverte. Le nom, la clé de la chimère et les parents
n'arrivent chez le client qu'une fois l'hybride découvert.

## Recettes (12 au lancement)

| # | Hybride | Tête (A) | Corps (B) | Indice (Index) |
|---|---|---|---|---|
| 1 | Ovi-Ptero | Oviraptor | Pteranodon | Two beach neighbors: one steals eggs, one rules the sky. |
| 2 | Para-Mimus | Parasaurolophus | Gallimimus | A trumpet crest on the fastest legs of the forest. |
| 3 | Tricera-Stego | Triceratops | Stegosaurus | Three horns on a back full of plates. |
| 4 | Croco-Don | Sarcosuchus | Iguanodon | A swamp jaw on a gentle plant eater. |
| 5 | Pachy-Anky | Pachycephalosaurus | Ankylosaurus | A hard head on an armored back. |
| 6 | Shark-Raptor | Megalodon | Velociraptor | The jaws of the deep on a canyon hunter. |
| 7 | Brachio-Tops | Brachiosaurus | Triceratops | The longest neck on three-horned legs. |
| 8 | Quetza-Carno | Quetzalcoatlus | Carnotaurus | A giant sky beak on a horned runner. |
| 9 | Spino-Mosa | Spinosaurus | Mosasaurus | A river hunter's head on a sea monster. |
| 10 | Plesio-Shark | Plesiosaurus | Megalodon | A long neck rises from the biggest shark. |
| 11 | Ptero-Rex | Pteranodon | T-Rex | The king of the crater grows wings. |
| 12 | Crystal Dragon | Crystal Rex | Quetzalcoatlus | A shining secret king takes to the sky. |

Rareté d'un hybride : la plus haute des deux parents. Taille de base : celle du corps. Ajouter une recette : à la fin de
la liste (l'ordre est celui de l'Index) ; ne jamais renommer un hybride publié (`data.Dinos[id].Species` et
`data.Index.Hybrids` gardent son nom). Une recette invalide (espèce inconnue, paire déjà prise, nom déjà pris, sans
indice) est ignorée avec un warn au démarrage.

## Chimères (HybridBuilder)

Une chimère n'a pas de modèle Blender : `src/shared/HybridBuilder.luau` assemble ses données à partir des modèles
`DinoModels` de ses deux parents (règles : `models/BRIEF.md` section 7, détails et outil d'aperçu :
`models/hybrids/README.md`). Sa clé dit tout ce qu'il faut pour la reconstruire :

```
"TRex+Pteranodon"                                   modules DinoModels de la tête (A) et du corps (B)
"Pteranodon+TRex;HeadScale=1.2;HeadOffset=0,0.5,0"  avec des réglages (brief 9)
```

Le serveur pose le modèle de l'enclos avec l'attribut `Species` = la clé et `Rarity` = la rareté de l'hybride. Côté
client, `FusionController` assemble et enregistre la chimère dans `DinoBuilder` dès que le modèle tagué `Dino` arrive,
avant que `DinoAnimController` construise ses briques et l'anime (effets de rareté compris). Si un parent n'a pas
encore de modèle, l'enclos pose un dino provisoire.

```lua
HybridBuilder.Key(head, body, tweak?) -> clé
HybridBuilder.Parse(clé) -> (head?, body?, tweak?)   -- nil si mal formée (réglages bornés, inconnus ignorés)
HybridBuilder.IsHybrid(valeur) / CanBuild(clé)
HybridBuilder.Ensure(clé) -> Data?                   -- assemble une fois et DinoBuilder.Register(clé, data)
HybridBuilder.Assemble(head: Data, body: Data, clé, tweak?) -> Data   -- pur, rien n'est enregistré
```

## API des services

```lua
-- FusionService
FusionService.Preview(player, ids) -> (true, infos) | (false, texte)
FusionService.Fuse(player, ids, options?) -> (ok, texte, infos?)   -- options (admin) : { Free?, Anywhere? }
FusionService.Hybrids() -> { Hybrid }      -- { Id, Name, Head, Body, Hint, Key, Rarity, Income, BaseSize } (serveur)
FusionService.Get(nom) / FindRecipe(espèceA, espèceB) / IsHybrid(espèce)
FusionService.IsDiscovered(player, nom) / Discover(player, nom) -> nouveau?
FusionService.Publish(player)              -- renvoie la clé replica Hybrids (après un changement fait à la main)

-- EnclosureService (ajouté par le brief 8)
EnclosureService.RegisterSpecies(espèce, { Model, BaseSize, HasModel, Rarity? })   -- espèce sans fiche Config.Species
```

`ids` : liste de 2 ou 3 identifiants de dinos du joueur (textes, comme les clés de `data.Dinos`). Le serveur refuse
tout le reste (doublons, ids d'un autre joueur, nombres, tables à trous, plus de 3).

`infos` (aperçu et fusion) : `{ Mode = "Upgrade" | "Hybrid", Known, Species, Cost }`, plus, quand le résultat est
connu : `Key` (clé de la chimère, hybrides), `Size`, `Mutation`, `Level` (0 à 2), `LevelName`, `Income` ($/s),
`Rarity`. Une fusion réussie ajoute `Id` (le nouveau dino), `Inputs` (espèces utilisées) et `New` (hybride découvert à
l'instant).

Textes d'erreur (anglais, à afficher tels quels) : « Please wait... » (données pas encore chargées), « Pick dinos to
fuse. », « Pick 2 or 3 dinos. », « Pick 2 or 3 different dinos. »,
« This dino is not in your park. », « Pick 2 dinos for a hybrid or 3 identical dinos to upgrade. »,
« Upgrade needs 3 dinos of the same species. », « Upgrade needs 3 dinos of the same level. »,
« This dino is already at max level! », « A hybrid needs 2 different species. Use 3 to upgrade! »,
« Go to the lab in your park to fuse! », « Not enough money! Fusion costs $X. », « Unknown recipe! Your dinos are
safe. Try another pair. », « Slow down! » (limite de fréquence).

## Signaux (Lib/Signals)

| Signal | Arguments |
|---|---|
| DinosFused | player, mode ("Upgrade" ou "Hybrid"), id, dino, inputs (espèces utilisées) |
| HybridDiscovered | player, nom |

Les dinos utilisés partent avec `DinoRemoved` et le résultat arrive avec `DinoAdded` (brief 3).

## Côté client

Remotes (`Remotes/Fusion.luau`) : `PreviewFusion(ids)`, `FuseDinos(ids)` ; événements `OpenFusionLab()` (le joueur a
utilisé le labo de son parc) et `FusionDone(infos)` (fusion réussie).

Clé replica `Hybrids` : `{ Total, Found, List = { { Id, Hint, Found, Name?, Key?, Head?, Body?, Rarity?, Income? } } }`
(une ligne par recette, dans l'ordre de l'Index ; les champs en `?` seulement une fois découvert).

```lua
-- FusionController
FusionController.Preview(ids) -> (ok, infos | texte)
FusionController.Fuse(ids) -> (ok, texte, infos?)
FusionController.LabOpened:Connect(fn)     -- ouvrir le menu du labo (brief 12)
FusionController.MenuReady = true          -- à mettre par le menu : enlève l'aide provisoire du labo
FusionController.Done:Connect(fn(infos))   -- carte de révélation (brief 12), effets de fusion (brief 11)
FusionController.Ensure(clé) -> Data?      -- chimère pour un ViewportFrame : DinoBuilder.Build(clé, options)
```

Pour les autres briefs :

- **Brief 9** : réglages des jointures dans la recette (`Tweak` : `HeadScale`, `HeadOffset`, `HeadPitch`, `LimbScale`,
  `LimbOffset`), aperçus avec `python3 models/hybrids/preview.py` (voir `models/hybrids/README.md`). Deux chimères
  dépassent le budget de 450 pièces : Tricera-Stego (493) et Ptero-Rex (451).
- **Brief 10** : le prompt du labo se pose sur la pièce `Lab` du parc (point d'ancrage du brief 3).
- **Brief 11** : effet de fusion sur `FusionController.Done` (le nouveau dino rugit, état `Roar`) ; le modèle de
  l'hybride porte l'attribut `Rarity`.
- **Brief 12** : menu du labo (choix de 2 ou 3 dinos dans la clé replica `Dinos`, aperçu, coût, bouton Fuse), page
  Hybrids de l'Index (clé replica `Hybrids`, silhouettes et indices), révélation sur `Done` (`infos.New`).
- **Briefs 13 et 15** : quêtes et analytics sur `DinosFused` et `HybridDiscovered`.

## Commandes admin et FossilDebug

Admin (chat) : `fuse <id> <id> [id]` (gratuit, de n'importe où), `givehybrid <nom|all> [taille] [mutation] [joueur]`
(ajoute l'hybride et le découvre), `hybrids [joueur]` (les recettes, `[x]` devant celles que le joueur a trouvées).

FossilDebug (Studio) : `fusion` (Upgrade, recette inconnue, hybride, ids hostiles ; tout est remis en place),
`hybrids` (chaque chimère s'assemble avec toutes les animations du corps).

## Choix faits sans Snaky (à valider)

- Coût : 60 s de revenu des dinos utilisés pour Upgrade, 120 s pour un hybride, au moins $50 ; recette inconnue gratuite.
- Niveau d'un hybride : le plus petit des deux parents. Rareté : la plus haute des deux.
- Fusion seulement dans son propre parc ; le dino obtenu sort en rugissant.
- Les 12 recettes, leurs noms et leurs indices (tableau ci-dessus), dont Ptero-Rex = tête de Pteranodon sur un corps
  de T-Rex (les ailes viennent du Pteranodon).
- Ailes greffées sur un corps qui marche : envergure 1,2 fois la longueur du corps, repliées le long des flancs.
