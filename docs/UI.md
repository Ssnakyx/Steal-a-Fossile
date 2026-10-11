# Interface (brief 12)

HUD, Shop, Index, labo de fusion, écran de révélation et étiquettes des dinos. Tout est dans `src/client/UI/` et
`src/client/Controllers/` (HudController, ShopController, IndexController, LabController, RevealController,
DinoLabelController), plus un service serveur : `IndexService` (espèces découvertes). Textes du jeu en anglais, pas
d'emoji. Le client ne décide rien : chaque achat ou action passe par un remote du serveur, qui vérifie tout.

## Ce que voit le joueur

- **Colonne de gauche** (comme Shop / Index de Steal an Egg) : boutons larges à icône du pack, en colonne : **Shop**
  (vert), **Index** (orange), puis Daily, Spin et Gifts (brief 13). Les 5 boutons sont centrés ensemble. Pastilles rouges : Shop « ! » quand une trail en argent est payable, Index = nombre
  d'espèces et d'hybrides découverts depuis la dernière ouverture.
- **Compteurs** en bas à gauche : argent (il monte doucement, les gros gains et les dépenses s'envolent en +$ / -$),
  revenu par seconde, vitesse. Sous la vitesse : dans une zone, « Swamp: 10K advised » (vert si assez rapide, rouge
  sinon) ; hors zone, la prochaine zone et sa vitesse conseillée.
- **Bandeau de zone** en haut au milieu, 3 s à l'entrée d'une zone : nom, vitesse conseillée, « Too slow, watch the
  guardian! » si le joueur est trop lent. Pas de bandeau pendant un transport.
- **Carte du transport** en haut au milieu, pendant qu'un bloc est sur le dos : rareté, flèche qui tourne vers le parc
  (suivant la caméra), « HOME 190 studs », et un rayon de la couleur de la rareté vers l'entrée du parc (pas pendant le
  guide des premières minutes, qui a déjà son rayon jaune). Poursuivi : la carte clignote en rouge avec
  « GUARDIAN 84 studs! ».
- **Messages courts** : ils passent sous la carte du haut (bandeau ou transport) au lieu de la cacher.
- **Cuves** à droite : une ligne par cuve (rareté, temps restant, barre), **OPEN** quand elle est prête (ouvre la cuve
  de loin), « +N fossils waiting », bouton **NEW TANK $X**. Visible dès qu'une cuve sert.
- **Shop** (6 onglets à icône : Deals, Speed, Trails, Passes, Money, Items ; style des Steal a ... du moment) : chaque onglet est une page de **sections** (« -- FEATURED -- »,
  « -- SPEED -- », « -- PASSES -- »...) en titres d'une couleur par section, barre de titre à reflets en diagonale, cartes et boutons en verre (reflet clair en haut, bande de lumière qui les traverse toutes les 3,5 s, `UIKit.glass`), puis de **grandes cartes illustrées** (3 par ligne) :
  icône du pack de Steal a Snack, gros « x2 », nom, description, bouton vert. Prix Robux : logo Robux dessiné et prix
  (le texte du bouton reste « R$ 99 »).
  - *Speed* : FEATURED = carte large du Treadmill (gain actuel par seconde, même AFK ; niveau suivant ; pastilles des
    niveaux par paliers de 10 (50 niveaux) ; bouton en argent du jeu toujours là, grisé tant qu'il est trop cher
    (`Next.Cash`, déblocage $1K) ; bouton Robux seulement quand le produit est en vente (`Next.Price`) ; MAX au
    niveau 50). SPEED = passe x2
    Treadmill et raccourci vers les trails.
  - *Trails* : SUPER TRAILS (Neon x1.5, Galaxy x2, Golden x3, passes Robux, EQUIP / EQUIPPED une fois achetées) puis
    CASH TRAILS (10 trails en argent, grisées tant qu'elles sont trop chères). L'image : la fusée au bout d'une bande
    aux couleurs de la trail.
  - *Passes* : x2 Money, x2 Treadmill, Fast Revive, VIP (OWNED une fois achetés).
  - *Items* : Bear Traps à l'unité ou par 5 en argent, Bear Traps x5, Instant Revive (« N saved »), Server Luck x2
    (temps restant) ; SPINS : 3 Spins et 10 Spins.
  - *Deals* : STARTER PACK, LIMITED OFFER et DAILY DEAL en grandes cartes : contenu (« Neon Trail + $15K + 10 Bear
    Traps + 3 Instant Revives »), étiquette rouge « -75% », prix barré au-dessus du bouton, compte à rebours jaune
    (« Ends in 2d 23h », puis « Ends in 3:12:05 »). Voir « Offres Robux » plus bas.
  - *Money* : 4 packs d'argent (Pile, Bag, Chest, Vault of Cash). Le gros chiffre est le montant au revenu actuel du
    joueur (il bouge avec lui), « +32% MORE » / « BEST VALUE » sur les plus gros.
  - Bouton rose **GIFT** à côté du prix de chaque passe (Speed, Trails, Passes) quand son produit cadeau est en vente :
    il ouvre la liste des joueurs du serveur (SEND). « GIFT (1) » : un cadeau déjà payé attend d'être envoyé.
- **Index** : un onglet par zone, plus Secret et Hybrids. Les espèces vues ont leur portrait 3D, leur nom et leur
  revenu de base ; les autres sont une silhouette noire « ??? » (« Revive one to unlock »). Les hybrides pas trouvés
  montrent un « ? » et l'indice de leur recette ; trouvés, leur portrait et leurs deux parents. En haut : « Dinos a/b
  Hybrids c/d ».
- **Fusion Lab** (s'ouvre au labo du parc) : les dinos du joueur à gauche, 3 cases, l'aperçu (« GOLDEN COMPY / LEVEL
  UP », « ??? » pour un hybride jamais trouvé, le coût), **FUSE!**, **AUTO PICK 3** (3 identiques), **HYBRIDS**
  (ouvre la page des hybrides de l'Index).
- **Écran de révélation** : à chaque dino sorti d'une cuve ou du labo. Portrait 3D qui tourne, rareté, NEW! (espèce
  jamais vue, hybride découvert), nom complet (« Big Lava Golden Triceratops »), taille, mutation, niveau, revenu.
  NICE! ou fermeture toute seule après 7 s ; plusieurs révélations passent l'une après l'autre. Après une fusion, le
  labo se rouvre.
- **Étiquettes au-dessus des dinos du parc** : rareté en couleur (arc-en-ciel pour Secret), nom (doré pour Golden,
  bleu glacier pour Diamond), revenu en vert. Seulement chez le client : l'étiquette du serveur (EnclosureService) est
  restylée.
- Les compteurs, cartes et cuves se cachent quand un menu est ouvert ; les boutons restent.

## Récompenses (brief 13, refaites)

- **Daily Rewards** : 14 cartes (2 lignes de 7) à la couleur de la récompense, « DAY n », grande icône (pièces, fusée,
  roue, bouclier, oeuf pour un fossile), montant ; le jour à prendre brille et respire, les jours pris ont un voile et
  une coche. Série, record et CLAIM DAY n / NEXT IN en bas.
- **Lucky Spin** : une vraie roue de 8 parts (couleur de la récompense, icône, gain écrit le long du rayon, clous
  blancs, anneau doré, flèche rouge en haut, bouton SPIN rond au milieu). Elle tourne 5 tours en 3,6 s et s'arrête sur
  la part tirée par le serveur. À droite : tours en réserve, tour gratuit, tableau CHANCES (toutes les probabilités),
  MORE SPINS (Robux, seulement si le serveur les permet). Dessin : quatre quarts fixes qui rognent, repeints à chaque
  image par `SetAngle` (un CanvasGroup tourné ne tourne ni les rognages ni les dégradés : vu dans Studio).
- **Free Gifts** : 9 cartes (3 x 3) : boîte cadeau tant que le cadeau est fermé (compte à rebours, puis OPEN et la
  boîte qui respire), l'image du gain avec une coche une fois ouvert.

## Premières minutes

Le premier dino d'un nouveau joueur ouvre l'écran de révélation avec « Your dinos make money for you, even when you're
offline! ». Le calendrier (brief 13) attend qu'il soit fermé (NICE! ou 7 s), puis s'ouvre. Le guide des premières
minutes reste en bas au milieu, entre les compteurs et les cuves.

## Objets Robux à Id = 0

Le serveur n'envoie que ce qui est vraiment en vente (GetShop, GetSpinOffers) : dans le jeu publié, un passe ou un
produit à Id = 0 n'apparaît pas. **Dans Studio seulement**, ils sont montrés avec un bouton gris « Id = 0 » pour voir
la mise en page du shop. Pour les mettre en vente : créer le passe ou le produit dans le Creator Hub, mettre son Id dans
`Config/Shop.luau` (ou `Config/Daily.luau` pour les spins). Le prix affiché est celui de Roblox. Les spins Robux
n'apparaissent qu'une fois leurs Ids mis, et jamais dans les pays qui interdisent les achats au hasard payants
(PolicyService).

## Offres Robux (shop complet, 2026-10-11)

Config : `Config/Shop.luau` (Cash, Packs, StarterHours, Rotation, Gifts) ; serveur : `OfferService` ; sauvegarde :
domaine `Offers` (passes donnés, packs achetés, cadeaux à envoyer). Tout se règle dans la config (prix, contenu,
ordre de rotation).

- **Packs d'argent** : montant = N minutes du revenu du joueur, au moins un minimum. Pile 49 R$ (10 min, $5K min),
  Bag 149 R$ (40 min), Chest 399 R$ (2 h 30), Vault 999 R$ (8 h).
- **Starter Pack** 99 R$ (valeur 399) : Neon Trail, 30 min de revenu, 10 Bear Traps, 3 Instant Revive. Proposé 3
  jours après la première connexion, une seule fois.
- **Limited** (un à la fois pour tout le monde, change tous les 3 jours) : Speed Rush 299 R$ (x2 Treadmill, vitesse,
  cash), Fossil Hunter 399 R$ (Fast Revive, revives, pièges, cash), Dino Tycoon 699 R$ (x2 Money, VIP, cash, revives).
- **Daily Deal** (un par jour, 00:00 UTC) : Mega Cash Deal 249, Trap Crate 79, Revive Bundle 99, Luck Party 149
  (Server Luck 45 min pour tout le serveur), Speed Boost 99.
- Un pack qui contient un passe déjà possédé n'est pas proposé. Jamais de dino, de bloc ni de tour de roue dans un
  pack (pas d'achat au hasard payant).
- **Cadeaux** : Roblox ne vend pas un game pass pour quelqu'un d'autre, donc chaque passe offrable a un produit
  développeur « cadeau » au même prix. Le passe offert est gardé pour toujours chez celui qui le reçoit. Si l'ami part
  avant la fin de l'achat, le cadeau attend (« GIFT (1) ») et s'envoie plus tard sans repayer. Annonce à tout le
  serveur : « Snaky gifted x2 Money to Bob! ».

À créer dans le Creator Hub (produits développeur), puis mettre l'Id dans `Config/Shop.luau` : `Cash.CashSmall`,
`CashMedium`, `CashLarge`, `CashHuge` ; `Packs.Starter`, `SpeedRush`, `FossilHunter`, `DinoTycoon`, `CashDeal`,
`TrapCrate`, `ReviveBundle`, `LuckParty`, `SpeedBoost` ; `Gifts.DoubleMoney`, `DoubleTreadmill`, `FastRevive`, `VIP`,
`NeonTrail`, `GalaxyTrail`, `GoldenTrail`. Le prix conseillé est le champ `Price` de chacun. Une réduction se montre
avec `Worth` (valeur barrée) : pour une vraie promo, baisser le prix dans le Creator Hub et garder `Worth`.

## Placement (écran de 1280 x 720 unités, mis à l'échelle)

| Élément | Où | ScreenGui (DisplayOrder) |
|---|---|---|
| Boutons Shop / Index (196 x 64, en colonne) | gauche, bas à 43 au-dessus du milieu | Hud (3) |
| Daily / Spin / Gifts (196 x 64, en colonne) | gauche, haut à 33 au-dessus du milieu | Rewards (5) |
| Compteurs (300 x 134) | bas à gauche, marge 16 | Hud (3) |
| Bandeau de zone, carte du transport (440 de large) | haut au milieu, y = 8 | Hud (3) |
| Cuves (232 de large) | droite, milieu + 30 | Hud (3) |
| Carte AFK, guide des premières minutes | bas au milieu | Afk (4), Tutorial (6) |
| Shop (1040 x 620), Index, Fusion Lab (1000 x 600) | milieu | Menus (7) |
| Écran de révélation (760 x 470) | milieu | Reveal (8) |
| Texte RUN!! / CAUGHT! | 30 % de la hauteur | StressText (20) |
| Messages courts, alerte d'un bloc rare (500 x 86) | haut au milieu, y = 70 (sous la carte du haut si elle est là) | Toasts (50) |
| Bouton Admin (64 x 64, admins seulement) | à droite du bouton Index (x = 222), même bas | AdminButton (3) |
| Menu Admin (1000 x 600) | milieu | Menus (7) |

Un nouvel élément d'interface prend une place libre de ce tableau, ou le complète.

## Menu d'admin

Bouton rouge à marteau à droite du bouton Index, visible seulement pour un admin (attribut « Admin » posé par
AdminService : `Config.Core.Admins`, propriétaire du jeu, tout le monde dans Studio). Chaque bouton lance une commande
d'admin par le remote `Admin` ; le serveur vérifie le droit à chaque appel. Cible en haut à droite (« Target: Me », un
appui passe au joueur suivant du serveur). La réponse du serveur s'affiche en bas du menu et en message court.

- **Player** : argent (+$1K à +$1Qd, Set $0), vitesse, niveau du treadmill (Studio), +10 Spins, +5 Traps, Finish
  Tanks, protection, tutoriel (0 = nouveau joueur), Daily Reset et +30 min de jeu (Studio), Go To / Bring la cible,
  **Reset Data** (deux appuis : la sauvegarde repart de zéro, le joueur est expulsé ; sans effet dans Studio, qui
  n'écrit jamais la sauvegarde : utiliser Tutorial 0).
- **Dinos** : liste des espèces par zone, taille et mutation (un appui = valeur suivante), GIVE DINO ; tous les
  hybrides et leurs recettes ; bloc fossile d'une rareté et d'une zone (dans une cuve ou la réserve).
- **World** : téléportation (Home et les 8 zones), bloc rare forcé dans un gisement (rareté, zone, SPAWN!, avec
  l'alerte), remplir les gisements, rendre les blocs au sol, gardiens on / off.
- **Console** : toutes les commandes en texte (`givedino T-Rex Huge Galaxy me`), HELP, journal des réponses.

Commandes ajoutées pour le menu : `spawnrare <rareté> [zone 1-8]` (DigSiteService), `goto <joueur>`,
`bring <joueur>`, `resetdata <joueur> confirm` (AdminToolsService, `DataService.Reset`).

## Alerte d'un bloc rare

Quand un bloc de rareté `Config.Zones.Dig.AlertRarity` (Mythic) ou mieux apparaît dans un gisement (remplissage ou
`spawnrare`), tout le serveur voit une grande carte de la couleur de la rareté (arc-en-ciel pour Secret) dans la liste
des messages courts : « MYTHIC FOSSIL! / Just appeared in the Volcano! » pendant `AlertTime` (6 s), et le même message
dans le chat. Une seule alerte par zone et par remplissage (« 3 MYTHIC FOSSILS! »). Legendary n'alerte pas : 72 % des
blocs du Meteor Crater le sont. Remote `FossilAlert` (rareté, zone, nombre), `AlertController.Show`, `UIKit.alert`.

## Pour les autres briefs

- `HudController.SetVisible(bool)` : cache tout le HUD (cinématique). `HudController.Heading(de, vers, caméra)` :
  angle de la flèche.
- `ShopController.Open(onglet?)` (« Deals », « Speed », « Trails », « Passes », « Money », « Items »), `Close`, `Toggle`, `IsOpen`,
  `Select(onglet)`. Ex. : le message « Unlock the Treadmill » peut appeler `ShopController.Open("Speed")`.
- `IndexController.Open(page?)` (nom de zone, « Secret », « Hybrids »), `Close`, `Toggle`, `IsOpen`, `Unseen()`.
- `LabController.Open`, `Close`, `IsOpen`, `Select(ids)`, `Selected()`. Il met `FusionController.MenuReady = true`.
- `RevealController.Show(infos, "Tank" | "Fusion")`, `IsOpen`, `Pending`, signal `Closed(genre)`. Le brief 11 peut
  jouer un son sur `DinoRevealed` sans toucher à la carte.
- UIKit : `UIKit.tabs`, `UIKit.scroll`, `UIKit.badge`, `UIKit.SetToastTop(y)`, `UIKit.Icons` (pack d'icônes de
  Steal a Snack, ids déjà téléversés), `UIKit.icon(nom, props)` (icône avec ombre), `UIKit.menuButton` (bouton carré à
  icône), `UIKit.sectionTitle` (« -- FEATURED -- »), `UIKit.robuxGlyph`. Un bouton dont le texte commence par « R$ »
  montre le logo Robux et le prix. Les tailles de texte maximales suivent l'échelle de l'écran (`UIKit.sizeLimit`). `UI/DinoView` : portrait 3D d'une
  espèce ou d'une chimère dans un ViewportFrame (`new`, `Show`, `Spin`, `Clear`, silhouette noire possible).
- `IndexService` (serveur) : `Discover(joueur, espèce)`, `Publish(joueur)`. Clé replica `Index` = `{ Species = {
  [espèce] = true }, Found, Total }`. Une espèce est découverte quand elle sort d'une cuve ou entre dans le parc
  (fusion, admin). Les récompenses de pages d'Index (`data.Index.Claimed`) restent au brief 13.

## Choix faits sans Snaky (à changer facilement)

- Shop et Index en boutons à gauche avec Daily / Spin / Gifts (comme Steal a Brainrot), plutôt qu'une barre en bas
  (la carte AFK et le guide y sont déjà).
- Le Shop s'ouvre sur l'onglet Speed (le treadmill est l'achat principal) ; Deals est le premier onglet.
- Prix et contenus des packs, rotation (Limited tous les 3 jours, offre du jour), Starter Pack 3 jours : choisis sans
  Snaky (2026-10-11).
- Écran de révélation fermé tout seul après 7 s, file de 10 au plus.
- Bouton OPEN des cuves dans le HUD : ouvre une cuve prête de n'importe où (le serveur ne vérifie pas la distance).
- Les espèces Secret ont leur propre page dans l'Index.

## À tester dans Studio

1. Arrivée : boutons à gauche sans chevauchement, compteurs en bas à gauche, calendrier qui s'ouvre (si la récompense
   du jour attend).
2. Prendre un bloc : carte du haut, flèche qui suit la caméra, distance qui baisse, rayon vers le parc. Se faire
   poursuivre : « GUARDIAN N studs! » en rouge.
3. Cuve : temps qui descend, OPEN, écran de révélation, NICE!.
4. Shop : les 4 onglets, acheter une trail en argent (Dust, $250) puis EQUIP, un piège. Les objets Robux sont gris
   « Id = 0 » dans Studio.
5. Index : pages des zones (silhouettes), Hybrids (indices).
6. Labo du parc : 3 Compy, AUTO PICK 3, FUSE!, révélation « LEVEL UP! », le labo se rouvre.
7. Sur téléphone (émulateur iPhone 15 en paysage) : tout se lit et rien ne se chevauche.

## Tests et aperçus

- `tools/luau_tests/t_ui_hud.luau` : HUD, colonne de gauche, compteurs, bandeau, transport, messages courts, cuves,
  Shop (achats par les boutons, Id = 0 caché hors Studio), événements abîmés.
- `tools/luau_tests/t_offers_server.luau` et `t_offers_client.luau` : packs d'argent, Starter Pack, Limited, offre du
  jour, cadeaux (ami parti : cadeau gardé), onglets Deals et Money, bouton GIFT et liste des joueurs.
- `tools/luau_tests/t_ui_menus.luau` : IndexService, Index, labo (choix, aperçu, fusion, hybride), révélation (file,
  fermeture toute seule), étiquettes, événements abîmés.
- Aperçus : `python3 tools/luau_tests/ui_preview.py ui_hud [--phone] [--icons dossier]` (`--icons` : dossier de
  `<nom>.png` des icônes de `UIKit.Icons`, sinon des cases grises) (HUD, cuve prête, bandeau, transport poursuivi,
  4 onglets du Shop, Index, labo, révélation). Les portraits 3D y sont des cases « 3D ».
