# Boucle principale (brief 3)

Ce que le brief 3 met en place et ce que les autres briefs peuvent utiliser : la carte des points d'ancrage (brief 10),
les API des services, les signaux, les clés replica et les attributs. Les valeurs de jeu sont dans
`Config/Zones.luau`, `Config/Rarity.luau` et `Config/Economy.luau` (valeurs de départ, à équilibrer).

## La boucle en bref

1. Le joueur arrive : PlotService lui donne un parc libre (5 parcs alignés au spawn, `Config.Map.Plots.Count` : serveurs
   de 5 joueurs) et le fait apparaître dedans.
2. Il court vers une zone de la route (+Z depuis le spawn). Chaque zone a 3 gisements de 4 blocs, remplis toutes les
   5 min (`Zones.Dig.RefillInterval`). La rareté d'un bloc est tirée avec les poids de sa zone (`Zones.Chances`).
3. Il maintient E 1 s sur un bloc (`ProximityPrompt` « Grab ») : le serveur vérifie la durée et la distance, puis le
   bloc passe sur son dos (un seul à la fois, malus de vitesse par rareté).
4. Dès qu'il entre dans son parc, le bloc est à lui pour de bon : il part dans une cuve libre, sinon en réserve
   (12 blocs). Mort, reset ou départ avant : le bloc retourne à son gisement. Arrivé plus vite que sa vitesse de
   marche ne le permet (téléportation) : le bloc retourne aussi à son gisement.
5. La cuve tourne (30 s pour un Common, 3 h pour un Secret), puis « Reveal » : espèce tirée parmi la rareté et la zone,
   taille, mutation. Le dino apparaît dans l'enclos et rapporte $/s, aussi hors ligne (plafond 8 h).

Tutoriel côté serveur (`data.Tutorial` : 0 nouveau, 1 bloc arraché, 2 bloc rentré, 3 premier dino) : tant qu'un joueur
prêt n'a pas rentré son premier bloc, un bloc Common est toujours présent à la Beach. S'il faut en ajouter un, il est
posé sur une place vide (jamais à la place d'un autre bloc) et réservé aux joueurs du tutoriel (`Block.Tutorial`).

## Points d'ancrage de la map (brief 10)

Au démarrage, PlotService et ZoneService lisent `Workspace.Map`. Tout ce qui existe déjà est gardé tel quel ; seul ce
qui manque reçoit une géométrie provisoire (cubes simples). Les noms sont cherchés dans tout le modèle (sous-dossiers
permis). Le brief 10 n'a donc qu'à construire `Workspace.Map` avec ces noms avant l'`Init` de PlotService et
ZoneService (Priority -20) : depuis un service de Priority plus petite, ou en la laissant enregistrée dans la place.

```
Workspace.Map
  SpawnGround            (seulement si Map.Plots n'existait pas : sol provisoire)
  Plots                  (si le dossier existe, aucun parc n'est créé : il faut les 5)
    Plot1 ... Plot5      Model
      Floor        BasePart  obligatoire : sol du parc. La zone sûre est sa boîte, de 4 studs dessous à 60 au-dessus.
      Spawn        BasePart  obligatoire : apparition (au-dessus de la pièce, dans son orientation)
      Enclosure    BasePart  obligatoire : sol de l'enclos (les dinos sont posés en grille dessus, 6 par rangée)
      Entrance     BasePart  entrée (flèche de retour du brief 12)
      Sign         BasePart  enseigne : BillboardGui "Label" > TextLabel "Text" (texte « <Nom>'s Park » écrit ici)
      Tank1..Tank6 BasePart  emplacements des 6 cuves (les 6 sont attendues ; une cuve sans pièce marche, sans visuel)
      Treadmill    BasePart  tagué "Treadmill" (brief 4)
      Lab          BasePart  labo de fusion (brief 8)
  Zones
    <Nom de la zone>     Model, nom exact de Config.Zones ("Beach", "Fern Forest", ..., "Meteor Crater")
      Area         BasePart  obligatoire : étendue de la zone (sa boîte, de 20 studs dessous à 300 au-dessus)
      Arch         BasePart  arche d'entrée (nom et vitesse conseillée)
      DigSites     Folder
        Site1, Site2 ...  BasePart  un gisement (triés par numéro : Site2 avant Site10)
          Slot1, Slot2 ... Attachment  emplacements des blocs (sinon 4 places en carré au-dessus de la pièce)
      Guardian     BasePart  point d'attache du gardien (brief 7)
```

Un parc sans Floor, Spawn ou Enclosure, ou une zone sans Area, est ignoré avec un `warn` dans l'Output. Le serveur
ajoute les attributs `Index` et `OwnerUserId` (0 si libre) sur chaque parc, `Zone`, `Index` et `Speed` sur chaque
zone. Sous les ancres, le brief 3 crée `TankLabel` (minuteur, voir « Côté client »), `TankPrompt`, `TankBlock` (cuves), `SiteLabel` (gisements),
`ExpandPrompt` (enclos), `Dinos` (dossier des dinos du parc) et les blocs `FossilBlock`.

## API des services

```lua
-- PlotService (Priority -20)
PlotService.Get(player) -> Plot?                -- { Index, Model, Floor, Spawn, Entrance?, Sign?, Tanks, Enclosure, Treadmill?, Lab?, Owner? }
PlotService.ByIndex(index) / List()
PlotService.IsSafe(position) -> boolean         -- dans un parc, quel qu'il soit : rien n'y est volable (brief 7)
PlotService.IsPlayerSafe(player) / IsInOwnPlot(player) / PlotAt(position) -> index?
PlotService.SpawnCFrame(plot) / Teleport(player)

-- ZoneService (Priority -20)
ZoneService.Get(name) -> ZoneGeo?               -- { Name, Index, Model, Area, Arch?, Sites, Guardian? }
ZoneService.List() / ZoneAt(position) -> name? / PlayerZone(player) -> name ("" hors route)

-- DigSiteService
DigSiteService.RollRarity(zone, luck?) -> rarity
DigSiteService.Refill() -> placés / RefillAt() -> heure serveur du prochain remplissage
DigSiteService.ReturnBlock(block) -> boolean    -- remet un bloc à sa place (bloc au sol non ramassé, brief 7)

-- CarryService
CarryService.Get(player) -> Block?              -- { Id, Rarity, Zone, Site?, Slot? }
CarryService.IsCarrying(player)
CarryService.GetSpeedMultiplier(player) -> 1 sans bloc, 0.9 (Common) à 0.6 (Secret)   -- lu par SpeedService (brief 4)
CarryService.Carry(player, block) -> boolean    -- un bloc sans Site (météorites du brief 14) disparaît s'il est perdu
CarryService.Drop(player) -> Block?             -- enlève le bloc sans le rendre (le brief 7 le pose au sol)
CarryService.ReturnToSite(player) -> boolean    -- attrapé par un gardien

-- ReviveService
ReviveService.AddBlock(player, block) -> boolean   -- cuve libre ou réserve
ReviveService.Roll(rarity, zone, luck?) -> { Species, Size, Mutation, Level }
ReviveService.Reveal(player, slot) / BuyTank(player) -> (ok, texte)
ReviveService.FinishAll(player) -> nombre       -- Instant Revive
ReviveService.Running(player) -> nombre
ReviveService.MutationLuck(player) -> bonus     -- 0 sans VIP, 0.1 avec LuckBonus = 1.1

-- EnclosureService
EnclosureService.AddDino(player, dino, state?) -> id?      -- fusion (brief 8)
EnclosureService.RemoveDino(player, id) -> Dino?
EnclosureService.GetDino(player, id) / ModelOf(player, id) / Count / Slots / HasRoom
EnclosureService.DisplayName(dino) -> "Big Amber Golden Compy"

-- IncomeService
IncomeService.DinoIncome(dino) -> $/s           -- base x taille x mutation x niveau
IncomeService.RegisterBase(species, income)     -- base d'un hybride (brief 8)
IncomeService.SetMultiplier(player, key, value?)   -- bonus nommé (événements, amis...) ; nil l'enlève
IncomeService.GetIncome(player) / Refresh(player)
```

Le brief 3 utilise sans en dépendre `ShopService.HasPass(player, "DoubleMoney" | "FastRevive" | "VIP")`,
`ShopService.ServerLuck()`, `Config.Shop.Passes.VIP.LuckBonus` (multiplicateur : 1.1 = mutations x1.1) et le produit
`InstantRevive` (brief 4), ainsi que `Config.Species` (`Income`, `Model`, brief 2) : chacun est lu seulement s'il
existe. `HasPass` et `ServerLuck` doivent répondre sans attendre (lecture d'un cache, jamais d'appel Roblox).
Un Instant Revive acheté sans cuve en cours est gardé (`data.InstantCredits`, 20 au plus) : la prochaine cuve lancée
est prête tout de suite.

## Signaux (Lib/Signals)

| Signal | Arguments |
|---|---|
| PlotAssigned / PlotReleased | player, index |
| ZoneChanged | player, zone, previous ("" hors route) |
| BlockGrabbed | player, block |
| DigSitesRefilled | (rien) |
| CarryChanged | player, block? |
| BlockBanked | player, block |
| BlockReturned | block |
| TankStarted | player, slot, tank |
| DinoRevived | player, id, dino, rarity |
| DinoAdded / DinoRemoved | player, id, dino |

## Côté client

Clés replica : `Plot` (index, 0 sans parc), `Carrying` ({ Rarity, Zone } ou nil), `Tanks` ({ ["1"] = { Rarity, Zone,
StartedAt, EndsAt } }, heures `os.time()`), `TankCount`, `Stored` (liste de { Rarity, Zone }), `Dinos`
({ [id] = { Species, Size, Mutation, Level, Income } }), `EnclosureSlots`, `Income` ($/s), `Tutorial` (0 à 3),
`InstantCredits`.

Attributs : joueur `Plot`, `Zone`, `Carrying` ; `Workspace.DigRefillAt` ; modèles tagués `Dino` (contrat du brief 2 :
`Species`, `Scale`, `Mutation`, `Level`, `State`, `StateAt`, plus `DinoId` et `OwnerUserId`) ; blocs tagués
`FossilBlock` (`BlockId`, `Rarity`, `Zone`).

Remotes (`Remotes/Loop.luau`) : `RevealTank(slot)`, `BuyTank()`, `BuyEnclosure()` renvoient (ok, texte) ;
`DinoRevealed(id, infos)` pour l'écran de révélation (brief 12) ; `LoopAnnounce(texte)` pour l'annonce dans le chat.

`LoopController` met à jour tous les TextLabel tagués `LoopCountdown` (attributs `EndsAt`, `Format` avec `%s`,
`Done`), la largeur de tous les GuiObject tagués `LoopProgress` (attributs `StartedAt` et `EndsAt` : `Size` =
`UDim2.fromScale(progression, 1)`) et affiche les annonces dans le chat.

Minuteur au-dessus de chaque cuve (BillboardGui `TankLabel`, 8 x 3 studs, 4.2 studs au-dessus du verre, visible à
120 studs) : `Back` (panneau sombre, contour `Stroke` à la couleur de la rareté), `Title` (« EPIC FOSSIL », « REVIVAL
TANK »), `Text` (compte à rebours tagué `LoopCountdown`, « READY! » en vert, « Empty », « Buy: $1K ») et `Bar` > `Fill`
(barre de progression taguée `LoopProgress`, cachée quand la cuve est vide ou que son début est inconnu).

## Commandes admin et FossilDebug

Admin (chat) : `tpzone <0-8>`, `refill`, `tutorial <0-3> [joueur]`, `giveblock <rareté> [n° de zone] [joueur]`,
`finishtanks [joueur]`, `givedino <espèce> [taille] [mutation|none] [joueur]`. Mutations : `mutations [zone]` (voir
`docs/MUTATIONS.md`).

FossilDebug (Studio) : `plots`, `zones`, `digsites`, `carry`, `revive`, `enclosure`, `income`.
