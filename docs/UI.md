# Interface (brief 12)

HUD, Shop, Index, labo de fusion, écran de révélation et étiquettes des dinos. Tout est dans `src/client/UI/` et
`src/client/Controllers/` (HudController, ShopController, IndexController, LabController, RevealController,
DinoLabelController), plus un service serveur : `IndexService` (espèces découvertes). Textes du jeu en anglais, pas
d'emoji. Le client ne décide rien : chaque achat ou action passe par un remote du serveur, qui vérifie tout.

## Ce que voit le joueur

- **Colonne de gauche** (de haut en bas) : **Shop** (vert), **Index** (orange), puis Daily, Spin et Gifts (brief 13).
  Les 5 boutons sont centrés ensemble. Pastilles rouges : Shop « ! » quand une trail en argent est payable, Index = nombre
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
- **Shop** (4 onglets) :
  - *Speed* : Treadmill (gain actuel par seconde, même AFK ; niveau suivant avec sa vitesse et son vrai prix Roblox ;
    MAX au niveau 10), passe x2 Treadmill, raccourci vers les trails.
  - *Trails* : Super trails (Neon x1.5, Galaxy x2, Golden x3, passes Robux, EQUIP / EQUIPPED une fois achetées) puis
    les 10 trails en argent (grisées tant qu'elles sont trop chères, EQUIP / EQUIPPED).
  - *Passes* : x2 Money, x2 Treadmill, Fast Revive, VIP (OWNED une fois achetés).
  - *Items* : Bear Traps à l'unité ou par 5 en argent, Bear Traps x5 en Robux, Instant Revive (« N saved »), Server
    Luck x2 (temps restant), 3 Spins et 10 Spins.
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

## Placement (écran de 1280 x 720 unités, mis à l'échelle)

| Élément | Où | ScreenGui (DisplayOrder) |
|---|---|---|
| Boutons Shop / Index | gauche, bas à 48 au-dessus du milieu | Hud (3) |
| Daily / Spin / Gifts | gauche, centrés 82 sous le milieu | Rewards (5) |
| Compteurs (300 x 134) | bas à gauche, marge 16 | Hud (3) |
| Bandeau de zone, carte du transport (440 de large) | haut au milieu, y = 8 | Hud (3) |
| Cuves (232 de large) | droite, milieu + 30 | Hud (3) |
| Carte AFK, guide des premières minutes | bas au milieu | Afk (4), Tutorial (6) |
| Shop, Index, Fusion Lab (1000 x 600) | milieu | Menus (7) |
| Écran de révélation (760 x 470) | milieu | Reveal (8) |
| Texte RUN!! / CAUGHT! | 30 % de la hauteur | StressText (20) |
| Messages courts | haut au milieu, y = 70 (sous la carte du haut si elle est là) | Toasts (50) |

Un nouvel élément d'interface prend une place libre de ce tableau, ou le complète.

## Pour les autres briefs

- `HudController.SetVisible(bool)` : cache tout le HUD (cinématique). `HudController.Heading(de, vers, caméra)` :
  angle de la flèche.
- `ShopController.Open(onglet?)` (« Speed », « Trails », « Passes », « Items »), `Close`, `Toggle`, `IsOpen`,
  `Select(onglet)`. Ex. : le message « Buy the Treadmill in the Shop » peut appeler `ShopController.Open("Speed")`.
- `IndexController.Open(page?)` (nom de zone, « Secret », « Hybrids »), `Close`, `Toggle`, `IsOpen`, `Unseen()`.
- `LabController.Open`, `Close`, `IsOpen`, `Select(ids)`, `Selected()`. Il met `FusionController.MenuReady = true`.
- `RevealController.Show(infos, "Tank" | "Fusion")`, `IsOpen`, `Pending`, signal `Closed(genre)`. Le brief 11 peut
  jouer un son sur `DinoRevealed` sans toucher à la carte.
- UIKit : `UIKit.tabs`, `UIKit.scroll`, `UIKit.badge`, `UIKit.SetToastTop(y)`. `UI/DinoView` : portrait 3D d'une
  espèce ou d'une chimère dans un ViewportFrame (`new`, `Show`, `Spin`, `Clear`, silhouette noire possible).
- `IndexService` (serveur) : `Discover(joueur, espèce)`, `Publish(joueur)`. Clé replica `Index` = `{ Species = {
  [espèce] = true }, Found, Total }`. Une espèce est découverte quand elle sort d'une cuve ou entre dans le parc
  (fusion, admin). Les récompenses de pages d'Index (`data.Index.Claimed`) restent au brief 13.

## Choix faits sans Snaky (à changer facilement)

- Shop et Index en boutons à gauche avec Daily / Spin / Gifts (comme Steal a Brainrot), plutôt qu'une barre en bas
  (la carte AFK et le guide y sont déjà).
- Le Shop s'ouvre sur l'onglet Speed (le treadmill est l'achat principal).
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
- `tools/luau_tests/t_ui_menus.luau` : IndexService, Index, labo (choix, aperçu, fusion, hybride), révélation (file,
  fermeture toute seule), étiquettes, événements abîmés.
- Aperçus : `python3 tools/luau_tests/ui_preview.py ui_hud [--phone]` (HUD, cuve prête, bandeau, transport poursuivi,
  4 onglets du Shop, Index, labo, révélation). Les portraits 3D y sont des cases « 3D ».
