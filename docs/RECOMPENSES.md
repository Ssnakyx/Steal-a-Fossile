# Récompenses, AFK et premières minutes

Demandes de Snaky du 2026-10-11 : « un système de rewards comme des daily spin, sur le treadmill on doit pouvoir AFK, le
jeu doit avoir une bonne rétention et un bon CCU » puis « les 5 premières minutes sont extrêmement importantes ».
Toutes les valeurs sont dans les fichiers de config (valeurs de départ, à équilibrer).

## Ce que voit le joueur

- **Daily** (bouton jaune à gauche) : calendrier de 14 jours, une récompense par jour (argent, tours de roue, vitesse,
  Bear Traps, blocs Epic et Legendary). Un jour manqué : retour au jour 1. S'ouvre tout seul à l'arrivée quand la
  récompense du jour attend ; pour un nouveau joueur, juste après son premier dino.
- **Spin** (bouton violet) : roue de 8 cases avec leurs chances affichées. 1 tour gratuit par jour, des tours en plus
  dans les cadeaux et le calendrier, et en Robux (3 Spins, 10 Spins) sauf dans les pays qui interdisent les achats au
  hasard payants (PolicyService : les offres sont cachées et refusées par le serveur).
- **Gifts** (bouton rose) : 9 cadeaux débloqués par le temps de jeu du jour, AFK compris (2, 5, 10, 15, 25, 40, 60,
  90 et 120 min). Les cadeaux prêts et pas ouverts sont donnés tout seuls au changement de jour (00:00 UTC).
- Une pastille rouge sur chaque bouton quand quelque chose attend.
- **Treadmill** : sans achat, il donne déjà 5 vitesse/s (x0.2 du treadmill acheté), même AFK. Une carte en bas de
  l'écran montre le gain par seconde et le gain depuis qu'on est monté. Roblox expulse un joueur inactif depuis 20 min :
  après 15 min d'inactivité sur son tapis, le joueur est reconnecté au même serveur et reposé sur son tapis (seulement
  dans le jeu publié, TeleportService ne marche pas dans Studio).
- **Guide des premières minutes** (nouveau joueur seulement) : une carte en bas de l'écran et un rayon jaune vers le but.

## Les 5 premières minutes

Mesuré par `t_daily_onboarding` sur la map du repo, un joueur qui marche (vitesse 0, WalkSpeed 16) :

| Temps | Ce qui se passe |
|---|---|
| 0 s | Arrivée dans son parc. Guide « 1/4 GRAB A FOSSIL », rayon vers le bloc de la Beach le plus proche. |
| ~12 s | Arrivé au bloc, E maintenu 1 s. Le gardien de la Beach rugit (« RUN!! ») mais court moins vite qu'un porteur. |
| ~13 s | « 2/4 BRING IT HOME! », rayon vers l'entrée du parc. ~13 s de retour avec le bloc. |
| ~26 s | « 3/4 REVIVING... 0:10 » : la première cuve d'un nouveau joueur prend 10 s au lieu de 30 s (60 s pour un Uncommon). Le guide propose le tour de roue gratuit en attendant. |
| ~36 s | « 4/4 YOUR DINO IS READY! », rayon vers la cuve. Premier dino : « It makes $X/s for you, even when you're offline. » |
| ~39 s | Le calendrier s'ouvre : jour 1 = $500. |
| ~45 s | « GET FASTER » : rayon vers le treadmill, vitesse gagnée même AFK. Puis « GO FURTHER ». |
| 2 min | Cadeau 1 : $250 (5 min du revenu, au moins $250). |
| 5 min | Cadeau 2 : un tour de roue. Avec ~$1K, la 3e cuve ($1K) est à portée. |
| 10 min | Cadeau 3 : vitesse. Fin de la protection des nouveaux joueurs (vol). |

Avant ce travail : aucun guide à l'écran (le tutoriel n'existait que côté serveur), première cuve de 30 s, premier
cadeau à 5 min, calendrier qui s'ouvrait dès l'arrivée (avant que le joueur sache quoi faire).

## Fichiers

| Fichier | Rôle |
|---|---|
| `src/shared/Config/Daily.luau` | calendrier, roue (cases, chances, produits Robux), cadeaux, récompense de secours, `Amount`, `Label`, `Chance`, `Day` |
| `src/shared/Config/Speed.luau` | `Treadmill.FreeMultiplier` (0 = rien sans achat), `Treadmill.Afk` (reconnexion) |
| `src/shared/Config/Zones.luau` | `Dig.TutorialReviveTime` (première cuve d'un nouveau joueur) |
| `src/server/Data/Daily.luau` | domaine de sauvegarde `Daily`, `Spins`, `Gifts` |
| `src/server/Services/RewardService.luau` | donne une récompense (argent, vitesse, tours, pièges, bloc) |
| `src/server/Services/DailyService.luau` | calendrier, changement de jour |
| `src/server/Services/SpinService.luau` | roue, produits Robux, PolicyService |
| `src/server/Services/GiftService.luau` | temps de jeu, cadeaux |
| `src/server/Services/AfkService.luau` | reconnexion AFK, arrivée sur le tapis |
| `src/client/Controllers/RewardsController.luau` | boutons et menus Daily, Spin, Gifts |
| `src/client/Controllers/AfkController.luau` | carte du treadmill, demande de reconnexion |
| `src/client/Controllers/TutorialController.luau` | guide des premières minutes |
| `src/server/DebugTests/Daily.luau` | tests FossilDebug `rewards`, `spin`, `gifts`, `afk` |

Changé ailleurs, au plus juste : `TreadmillService` (gain gratuit, un seul rappel d'achat), `ReviveService` (première
cuve rapide), `t_loop_revive` et `t_loop_flow` (première cuve), `t_pvp_steal` (le cadeau arrive en même temps que la fin
de la protection), `t_speed_treadmill` (échelle payante seule), `testkit` (`T.spendDailyRewards` avant le fuzz).

## Montants

L'argent vaut des minutes du revenu actuel du joueur (`IncomeMinutes`, avec un minimum `Amount`), la vitesse un
pourcentage de sa vitesse gagnée (`SpeedPercent`, minimum `Amount`) : une récompense reste utile à tout moment du jeu.
Le client calcule l'affichage avec la même fonction que le serveur (`Config.Daily.Amount`, clé replica `RewardScale`).
Une récompense impossible (cuves et réserve pleines, pièges au maximum) est remplacée par `Config.Daily.Fallback`.

## Contrats

Clés replica : `Daily` ({ Next, CanClaim, Streak, Best, NextReset, Days }), `Spins` ({ Free, Stored, Total, NextFree,
CanBuy }), `Gifts` ({ Seconds, At, Claimed = { numéros }, NextReset }), `RewardScale` ({ Income, Speed }).

Remotes (`Remotes/Daily.luau`) : `ClaimDaily()`, `Spin()` (renvoie aussi la case), `ClaimGift(n)`, `GetSpinOffers()`,
`BuySpins(clé)` ; `AfkRejoin` (client vers serveur) ; `RewardGranted(source, texte, rareté?)` (serveur vers client).

Signaux : `RewardGranted(player, source, reward, amount)`, `DailyClaimed(player, day, streak)`, `NewDay(day)`,
`DailyReset(player)`, `SpinDone(player, case, reward)`, `GiftClaimed(player, n)`, `AfkRejoin(player)`.

Côté client (pour le HUD du brief 12) : `RewardsController.Open(nom)`, `Close(nom?)`, `Badge(nom)`,
`SetButtonsVisible(bool)` ; `TutorialController.Step()` (étape affichée), `IsActive()`, `Skip()`.
Attributs joueur : `OnTreadmill` (TreadmillService), `AfkReturn` (revenu d'une reconnexion AFK).

## Commandes

Admin (chat, Studio seulement pour les deux premières) : `dailyreset [joueur]` (calendrier, tour gratuit et cadeaux du
jour à nouveau disponibles), `playtime <minutes> [joueur]`, `spins <1-1000> [joueur]`. Pour revoir le guide :
`tutorial 0` puis rejoindre.

FossilDebug : `rewards`, `spin`, `gifts`, `afk` (chacun remet le joueur dans son état).

## À faire par Snaky

- Créer les produits **3 Spins (49 R$)** et **10 Spins (129 R$)** dans le Creator Hub, puis mettre leurs Id dans
  `Config.Daily.Spins.Products` (Id = 0 : cachés).
- Tester la reconnexion AFK dans le jeu publié (rester 15 min sans toucher sur son tapis).
