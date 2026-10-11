# Gardiens et vol (brief 7)

Ce que le brief 7 met en place et ce que les autres briefs peuvent utiliser : les gardiens (brief 2 pour les modèles,
10 pour la map, 11 pour les effets, 12 pour l'alerte du HUD), le vol sur la route, les signaux et les remotes. Les
valeurs de jeu sont dans `Config/Guardians.luau` et `Config/Pvp.luau` (valeurs de départ, à équilibrer).

## Les règles

- **Parc = zone sûre** (`PlotService.IsSafe`) : un bloc rapporté au parc n'est jamais volable, personne n'y est bonké
  ni piégé, aucun piège ne se pose dans un parc ni à moins de 10 studs, et les gardiens n'y entrent jamais.
- **Gardien** : un par zone, il dort sur le point `Guardian` de la zone. Arracher un bloc de sa zone le réveille
  (Wake 1.2 s, Roar 1.3 s avec « RUN!! »), puis il court vers le porteur. Vitesse : `Speed` de la config, sinon
  0.75 x le WalkSpeed conseillé de la zone (Beach : 10, lent pour le tutoriel ; Meteor Crater : 52.5). Il attrape à
  4 studs + 0.35 x sa taille : chute de 2 s et le bloc retourne à son gisement. Il poursuit tant que le porteur garde un
  bloc de sa zone, reste à moins de 40 studs de la zone (`Leash`) et hors des parcs ; sinon il cherche 3 s, rentre en
  marchant, se recouche. Réveillé, il prend la proie la plus proche (le voleur qui a ramassé le bloc, par exemple).
  Endormi, il se réveille aussi dès qu'un porteur d'un bloc de sa zone est à portée (celui qui ramasse au sol un bloc
  lâché près de lui). S'il reste coincé en rentrant (un parc sur le chemin), il réapparaît chez lui au bout de
  distance / vitesse + 5 s (`ReturnSlack`).
- **Pelle** (outil « Shovel » donné à chaque apparition) : un coup toutes les 2 s, portée 8 studs (+4 de tolérance).
  Le porteur touché tombe 1.5 s et lâche son bloc à ses pieds. Un joueur sans bloc ne subit rien.
- **Bear Trap** (outil « Bear Trap » tant qu'il en reste) : posé à ses pieds sur la route, 3 posés au plus (le plus
  ancien disparaît), 4 studs entre deux pièges, disparaît au bout de 120 s s'il ne sert pas. Il ne se ferme qu'1 s
  après la pose (`ArmTime` : on ne le pose pas sous les pieds d'un porteur comme un coup de pelle). Celui qui marche
  dessus (joueur ou gardien, jamais celui qui l'a posé) est immobilisé 3 s et lâche son bloc. Achat : 5 000 $ pièce (10 au
  plus d'un coup) ou 5 avec le produit Robux `BearTraps5`.
- **Bloc au sol** : ramassable par tous (prompt « Pick up », E, instantané), sauf par celui qui l'a lâché pendant 3 s,
  et seulement debout, vivant et sur la route (pas depuis un parc : le bloc y serait rangé aussitôt).
  Pas ramassé en 30 s, il retourne à son gisement (un bloc sans gisement, comme ceux des météorites, disparaît). Le
  bloc du tutoriel reste réservé aux nouveaux joueurs.
- **Protection débutant** : les 10 premières minutes de jeu au total (`data.PlayTime`), ni bonk ni piège. Un joueur
  protégé peut voler aux gardiens, et les gardiens l'attrapent comme les autres. Sa protection s'arrête dès qu'il
  bonke quelqu'un, pose un piège ou ramasse le bloc lâché par un autre joueur (`Protection.EndsOnAttack`), sinon un
  compte neuf volerait les autres sans risque pendant 10 min.

## Pour la map (brief 10)

Rien de neuf : le point `Guardian` de chaque zone (docs/BOUCLE.md) est l'endroit où le gardien dort, au-dessus de la
pièce, tourné comme elle (le dino regarde vers -Z). Sans point `Guardian`, il dort au centre de la zone. La zone
(`Area`) + 40 studs borne la poursuite. Le gardien suit le sol par raycast (sans les personnages, les blocs au sol, les
pièges et les gardiens) : les pièces de décor `CanQuery = false` ne le gênent pas.

## Modèles des gardiens (brief 2, contrat de DinoAnimController)

`Workspace.Guardians.<Zone> Guardian` : Model tagué `Dino` et `Guardian` (`ModelStreamingMode = Persistent` : toujours
chez tous les clients avec StreamingEnabled), pièce invisible `Root` au sol (PrimaryPart),
attributs `Species` (nom du module DinoModels, `T-Rex` donne `TRex`), `Scale`, `State`, `StateAt`, `Speed` (studs/s
pendant Run et Return, 0 sinon), `Guardian` (nom de la zone), `TargetUserId` (0 sans cible), `Trapped`. Le serveur
déplace le pivot 10 fois par seconde ; le client lisse et anime. États : `Sleep`, `Wake`, `Roar`, `Run`, `Catch`,
`Search`, `Return`, `BackToSleep` ; pris dans un piège : `Idle` avec `Trapped = true` (`Config.Guardians.TrappedState`).
Sans module DinoModels pour l'espèce, un gardien provisoire en briques est posé à la place.

Espèces et tailles (proposées par les briefs 5 et 6, pas encore validées par Snaky) : Beach Oviraptor x3, Fern Forest
Stegosaurus x2, Swamp Baryonyx x2, Canyon Velociraptor x2, Glacier Cryolophosaurus x2, Volcano Carnotaurus x2, Ocean
Trench Megalodon x1.5, Meteor Crater T-Rex x2.

## API des services

```lua
-- GuardianService
GuardianService.Get(zone) -> Guardian?          -- { Zone, Species, Model, Home, CFrame, State, Target?, Speed, ... }
GuardianService.List() / SpeedFor(zone) -> studs/s
GuardianService.SetEnabled(on) / IsEnabled()    -- éteints : ils dorment chez eux (commande « guardians on|off »)
GuardianService.Wake(zone, player) / ResetAll() -- tests, debug

-- PvpService
PvpService.Bonk(attacker, target?) -> (touché, texte)
PvpService.PlaceTrap(player) -> (ok, texte) / Traps() / GiveTraps(player, n) -> boolean
PvpService.SpringTrapAt(position, rayonEnPlus?, zone?) -> boolean   -- un gardien marche-t-il sur un piège ?
PvpService.IsProtected(player) / SetProtection(player, on, secondes?)
PvpService.Knock(player, secondes, "Bonk" | "Catch" | "Trap") / IsKnocked(player)

-- DroppedBlockService
DroppedBlockService.Drop(player, raison) -> Block?          -- le porteur lâche son bloc à ses pieds
DroppedBlockService.Place(block, sol, lâchéPar?, raison?) -> Dropped?   -- poser un bloc au sol (météorites...)
DroppedBlockService.PickUp(player, id) -> (ok, texte) / Return(id) / ReturnAll() / List() / Get(id)
DroppedBlockService.GroundBelow(position, ignorer?) -> Vector3
```

## Signaux (Lib/Signals)

| Signal | Arguments |
|---|---|
| GuardianStateChanged | zone, state |
| GuardianWoke | zone, player |
| GuardianCaught | player, zone, block |
| Bonked | attacker, victim, block |
| TrapPlaced | player |
| TrapSprung | owner? (parti : nil), victim (Player ou nom de zone du gardien), block? |
| BlockDropped | player, block, reason ("Bonk" ou "Trap") |
| BlockPickedUp | player, block, droppedByUserId |
| ProtectionEnded | player |

## Côté client (briefs 11, 12, 16)

Remotes (`Remotes/Pvp.luau`) :
- `Bonk(cible?)`, `PlaceTrap()` : envoyés par `PvpController` quand on clique avec la pelle ou le piège en main.
- `BuyTraps(nombre)` -> (ok, texte) : pour le shop du brief 12.
- `Knocked(secondes, raison)` : au joueur touché ; `PvpController` le fait tomber (sauf pour un piège).
- `GuardianAlert(zone, état, raison?)` : au joueur poursuivi (`Roar`, `Run`, `Lost`, `Catch`) : alerte du HUD, « RUN!! ».
  `Lost` porte une raison : `Safe` (rentré dans un parc), `Escaped` (sorti de la laisse avec son bloc) ou `Dropped`
  (plus de bloc de la zone : bonk, piège, mort).
- `PvpEffect(genre, position)` : à tous (`Bonk`, `Catch`, `Trap`) : étoiles, piège qui se ferme, sons.

Attributs : joueur `ChasedBy` (zone du gardien qui le poursuit, "" sinon), `Protected`, `ProtectedUntil` (heure
serveur) ; gardiens (ci-dessus) ; pièges tagués `BearTrap` (`OwnerUserId`, `Armed`, `PlacedAt`, `ArmsAt`, `SprungAt`) dans
`Workspace.BearTraps` ; blocs au sol tagués `DroppedFossil` (`BlockId`, `Rarity`, `Zone`, `DroppedBy`, `LockedUntil`,
`ReturnAt`) dans `Workspace.DroppedFossils`, avec une étiquette « Returns in 0:27 ». Clé replica `BearTraps`.

## Course stressante (côté client)

`StressController` (valeurs dans `Config/Stress.luau`) rend le trajet du retour stressant, chez le joueur seulement :

- **Bloc sur le dos** (attribut `Carrying`) : battement de cœur discret, vignette sombre légère, couleurs un peu
  ternies ; plus la rareté est haute, plus c'est fort.
- **Poursuivi** (attribut `ChasedBy`) : cœur plus fort et plus rapide quand le gardien se rapproche, vignette rouge
  qui bat avec le cœur, couleurs ternies et teintées de rouge, champ de vision élargi, secousse continue de la caméra
  près du gardien, et chacun de ses pas (modèle tagué `Guardian`, `State = Run`, au rythme de `Speed`) fait un « boum »
  qui secoue la caméra, de plus en plus fort.
- **GuardianAlert** : `Roar` = rugissement + coup d'orchestre + éclair rouge + coup de zoom + « RUN!! » ; `Catch` =
  choc + grosse secousse + « CAUGHT! » ; `Lost` = « ESCAPED! » (raison `Safe` ou `Escaped` seulement). **Knocked**
  `Bonk` / `Trap` : secousse ; **PvpEffect** à moins de 30 studs (pas sur soi, ni juste après son propre coup) :
  petite secousse.
- La secousse est posée juste après la caméra de Roblox et retirée au début de l'image suivante, avant les commandes
  et la caméra (pas de dérive, déplacements non faussés) ; rien quand la caméra est
  `Scriptable` (cinématiques) ; réduite avec « Reduce Motion » des réglages Roblox.
- Sons : audio public du Creator Store (APM Music, Pro Sound Effects), choisis sans écoute : `Config.Stress.Sounds`
  (le brief 16 peut les remplacer). Les gros textes peuvent être repris par le HUD du brief 12 (`Config.Stress.Texts`).

## Commandes admin et FossilDebug

Admin (chat) : `guardians <on|off>`, `traps <nombre> [joueur]`, `protection <on|off> [joueur]` (indispensable pour
tester le vol à deux dans Studio : un compte neuf est protégé 10 min), `returnblocks`.

FossilDebug (Studio) : `guardians`, `pvp`, `dropped`.
