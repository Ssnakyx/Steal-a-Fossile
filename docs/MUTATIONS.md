# Mutations et nouvelles espèces

Ce que le thread « 5 nouveaux dinos par biome et système de mutations » met en place : 12 mutations (les 3 du GDD,
une par biome et Rainbow), leurs couleurs et leurs effets animés, l'annonce des plus rares, et 40 espèces de plus
(5 par biome, des créatures fantastiques pour les plus rares).

Valeurs : `src/shared/Config/Economy.luau` (`Mutations`, `MutationAnnounce`). Couleurs des briques :
`src/shared/DinoBuilder.luau`. Effets animés : `src/client/Controllers/MutationController.luau`. Annonce et commande
admin : `src/server/Services/MutationService.luau`.

## Les 40 nouvelles espèces

5 par biome, dans les raretés de la zone (`Config.Zones` : `Weights` inchangés). Une rareté de bloc donne une
espèce tirée parmi celles de la zone qui ont cette rareté. Les plus rares sont des créatures fantastiques (*).
Modèles voxel faits dans Blender comme les autres (`models/species/<Espece>.py`, rendus de contrôle dans
`models/previews/<Espece>/`), avec toutes les animations du parc, des gardiens, de la fusion et de l'Index.
Taille : plus grande dimension à la taille Normal (studs). Revenu : base en $/s, à équilibrer.

**Beach**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Protoceratops | quadrupède | Common | 6 | $2 | petit cératopsien trapu, gros bec, collerette bordée de corail |
| Psittacosaurus | bipède | Common | 5 | $1 | « lézard-perroquet » : bec orange, soies dressées sur la queue |
| Dimorphodon | volant | Common | 8 | $2 | petit ptérosaure à tête de macareux, queue à palette en losange |
| Archelon | nageur | Uncommon | 12 | $4 | tortue de mer géante, carapace à crêtes, grandes nageoires |
| Tanystropheus | quadrupède | Uncommon | 14 | $3 | cou démesuré en gros segments, pattes de lézard |

**Fern Forest**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Hypsilophodon | bipède | Common | 6 | $6 | petit coureur vert aux grands yeux |
| Microraptor | volant | Common | 7 | $7 | petit raptor à quatre ailes de plumes irisées |
| Kentrosaurus | quadrupède | Uncommon | 11 | $10 | cousin du Stégosaure : plaques puis longues pointes |
| Styracosaurus | quadrupède | Uncommon | 13 | $12 | collerette couronnée de longues pointes, grande corne |
| Dilophosaurus | bipède | Rare | 12 | $18 | deux crêtes rouges sur le crâne |

**Swamp**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Diplocaulus | quadrupède | Uncommon | 6 | $30 | amphibien à tête en boomerang |
| Dimetrodon | quadrupède | Uncommon | 10 | $38 | haute voile dorsale rayée |
| Deinonychus | bipède | Rare | 11 | $48 | grand raptor à plumes, griffe en faucille |
| Corythosaurus | quadrupède | Rare | 14 | $52 | bec de canard et crête en casque |
| Basilisk * | quadrupède | Epic | 15 | $75 | roi des marais : couronne de piques, capuchon de cobra, taches toxiques lumineuses |

**Canyon**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Coelophysis | bipède | Rare | 9 | $150 | chasseur fin et rapide, rayé |
| Edmontonia | quadrupède | Rare | 13 | $180 | nodosaure blindé aux pointes d'épaule |
| Allosaurus | bipède | Epic | 17 | $240 | grand prédateur tigré aux cornes rouges |
| Amargasaurus | quadrupède | Epic | 21 | $260 | sauropode au cou hérissé de doubles épines |
| Thunder Raptor * | bipède | Legendary | 16 | $360 | raptor de tempête, éclairs lumineux sur les plumes |

**Glacier**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Troodon | bipède | Rare | 6 | $700 | petit raptor malin aux énormes yeux, plumage d'hiver |
| Smilodon | quadrupède | Rare | 10 | $800 | tigre à dents de sabre |
| Yutyrannus | bipède | Epic | 18 | $1100 | tyrannosaure à plumes blanches |
| Woolly Mammoth | quadrupède | Epic | 17 | $1200 | mammouth laineux aux grandes défenses |
| Frost Wyvern * | volant | Legendary | 22 | $1700 | wyverne de glace, ailes translucides, lame de cristal au bout de la queue |

**Volcano**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Dracorex | bipède | Epic | 10 | $3300 | tête de dragon couverte de piques |
| Ceratosaurus | bipède | Epic | 16 | $4000 | cornes rouges et plaques sur le dos |
| Acrocanthosaurus | bipède | Legendary | 19 | $5500 | haute crête dorsale cramoisie |
| Magma Behemoth * | quadrupède | Legendary | 22 | $5800 | colosse de basalte fissuré de lave, volcan sur le dos |
| Phoenix * | volant | Mythic | 24 | $8500 | oiseau de feu aux plumes en flammes |

**Ocean Trench**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Ichthyosaurus | nageur | Epic | 13 | $17000 | reptile-dauphin |
| Dunkleosteus | nageur | Epic | 16 | $20000 | poisson cuirassé aux mâchoires en lames |
| Helicoprion | nageur | Legendary | 18 | $24000 | requin à la spirale de dents |
| Liopleurodon | nageur | Legendary | 24 | $28000 | pliosaure massif à quatre nageoires |
| Abyssal Leviathan * | nageur | Mythic | 34 | $42000 | anguille-dragon des abysses, points lumineux et leurre de cristal |

**Meteor Crater**

| Espèce | Famille | Rareté | Taille | Revenu | Allure |
|---|---|---|---|---|---|
| Kosmoceratops | quadrupède | Legendary | 14 | $85000 | la collerette la plus ornée, crochets dorés |
| Deinocheirus | bipède | Legendary | 20 | $100000 | bras géants à griffes, bosse-voile |
| Argentinosaurus | quadrupède | Legendary | 35 | $110000 | le plus grand dino du jeu |
| Celestial Serpent * | nageur | Mythic | 32 | $200000 | dragon céleste semé d'étoiles, crinière et bois dorés |
| Star Dragon * | volant | Mythic | 28 | $220000 | wyverne cosmique, ailes en nébuleuse |

## Les 12 mutations

Un seul tirage à la réanimation. Amber, Crystal, Lava (valeurs du GDD, inchangées) et Rainbow sortent de toutes les
zones ; chaque biome a en plus sa mutation, qui ne sort que des fossiles de sa zone.

| Mutation | Chance | Revenu | Zone | Couleurs des briques | Effet animé (client) |
|---|---|---|---|---|---|
| Amber | 8 % | x1.5 | toutes | ambre doré, gouttes translucides | gouttes d'ambre qui tombent |
| Crystal | 3 % | x2 | toutes | cyan, facettes de glace, éclats Neon | éclats qui s'allument sur le corps |
| Pearl | 2 % | x2 | Beach | nacre rose, lavande et menthe, lisse et brillante | reflets nacrés |
| Bloom | 2 % | x2 | Fern Forest | feuillage vert, petites fleurs roses, jaunes, blanches, violettes | pétales qui tombent en tournant |
| Toxic | 1.5 % | x2.5 | Swamp | vert poison, taches Neon | bulles toxiques qui montent |
| Ruby | 1.5 % | x2.5 | Canyon | rouge rubis, facettes de verre, éclats | éclats rouges |
| Frost | 1.5 % | x2.5 | Glacier | bleu glacé, plaques de glace, givre blanc | flocons qui tombent |
| Lava | 1 % | x3 | toutes | basalte sombre, fissures de lave Neon | braises qui montent |
| Obsidian | 1 % | x3 | Volcano | noir brillant, veines violettes Neon | éclats violets qui montent |
| Abyssal | 0.75 % | x4 | Ocean Trench | bleu des abysses, points bioluminescents | bulles cyan qui montent |
| Galaxy | 0.5 % | x5 | Meteor Crater | nuit violette, nébuleuses, étoiles Neon | étoiles qui scintillent |
| Rainbow | 0.05 % | x10 | toutes | toutes les couleurs | arc-en-ciel qui défile sur tout le corps, éclats de toutes les couleurs |

Chance d'avoir une mutation (sans le pass VIP) : 14.05 % à Beach et Fern Forest, 13.55 % à Swamp, Canyon et Glacier,
13.05 % à Volcano, 12.8 % à Ocean Trench, 12.55 % à Meteor Crater (le GDD donnait 12 %). Revenu moyen d'un dino :
environ x1.115 au lieu de x1.09, soit +2.5 % : l'économie ne bouge presque pas, les mutations rares sont des jackpots.

Le motif de chaque espèce reste lisible : la couleur de la mutation suit la clarté d'origine de chaque brique. Les
yeux, dents et griffes (détails lisses) gardent leur couleur. Avec un niveau Golden ou Diamond, la matière du niveau
reste (or en Foil, cristal brillant) et la mutation donne la couleur.

## Tirage et probas

- `ReviveService.Roll(rareté, zone, chance)` appelle `Economy.RollMutation(zone, chance, roll)` : de la plus rare à la
  plus commune, seulement les mutations possibles dans la zone du bloc. `chance` vient du pass VIP
  (`ReviveService.MutationLuck` : `Config.Shop.Passes.VIP.LuckBonus` 1.1 = toutes les chances x1.1).
- `Economy.MutationChances(zone, chance)` donne les probas affichables (0 à 1), de la plus commune à la plus rare, puis
  « aucune » : mêmes calculs que le tirage (toute chance payante affiche ses probas). La somme fait toujours 100 %.
- `Economy.Mutation(nom)` (fiche : `Chance`, `Income`, `Zone`, `Color`), `Economy.FindMutation(texte)` (sans les
  majuscules, pour les commandes), `Economy.MutationInZone(fiche, zone)`.

## Revenus et fusion

- Revenu d'un dino = base de l'espèce x taille x mutation x niveau (`IncomeService.DinoIncome`, inchangé).
- Fusion (Upgrade et Hybride) : la meilleure mutation est gardée, celle qui rapporte le plus ; à revenu égal, la plus
  rare (Pearl plutôt que Crystal, Obsidian plutôt que Lava).
- Sauvegarde : une mutation inconnue est effacée au chargement (`Data/Loop.luau`, liste de `Config.Economy`).

## Annonce des mutations rares

Une mutation de chance <= 1 % (`Economy.MutationAnnounce`) qui sort d'une cuve est annoncée à tout le serveur, dans le
chat (`LoopAnnounce`) et à l'écran (`Notify`) : « Alice revived a Big Galaxy Compy! Galaxy mutation: 1 in 200, x5
income ». Lava, Obsidian, Abyssal, Galaxy et Rainbow sont annoncées.

Signal serveur pour les autres systèmes (sons, quêtes, statistiques) : `MutationRevealed(player, id, dino, info)`, à
chaque dino réanimé avec une mutation (`info` : la fiche de `Config.Economy`). Le client reçoit déjà la mutation dans
`DinoRevealed` (écran de révélation du brief 12 : `Economy.Mutation(nom).Color` pour la couleur du nom).

## Effets animés chez le client

`MutationController` suit tous les modèles tagués `Dino` qui ont un attribut `Mutation` connu (enclos, vitrines,
gardiens...) et fait vivre de petits cubes nets autour d'eux, dans le style des effets de rareté de `DinoAnimController` :

- **chute** (Amber, Bloom, Frost) : partent du corps et tombent en se balançant ;
- **montée** (Toxic, Lava, Obsidian, Abyssal) : partent du corps et montent ;
- **éclats** (Crystal, Pearl, Ruby, Galaxy, Rainbow) : posés sur une brique, ils grandissent puis s'éteignent en suivant
  l'animation ;
- **Rainbow** : en plus, la teinte de chaque brique défile en vague le long du corps (les ombres du motif restent).

Limites : rien de neuf au-delà de 150 studs (x la taille du dino) ni derrière la caméra, vague Rainbow jusqu'à 110 studs,
260 cubes au plus en même temps et 28 par dino. Les cubes sont dans `workspace.MutationFx` (créé chez le client, jamais
répliqué), ancrés, sans collision, requête, contact ni ombre, et réutilisés. Les sons des mutations ne sont pas faits
ici (brief 11 : écouter `DinoRevealed` chez le client, ou `MutationRevealed` côté serveur).

## Commandes

Admin (chat) : `mutations [zone 1-8 ou nom]` (probas de la zone avec sa propre chance),
`givedino <espèce> [taille] [mutation|none] [joueur]` et `givehybrid ... [mutation|none]` (mutation sans les majuscules).

FossilDebug (Studio, barre de commande en vue serveur) :

- `FossilDebug:Invoke("mutations")` : probas de chaque zone, construction de chaque mutation, essai de chaque mutation
  dans l'enclos du premier joueur (dinos de test retirés) ;
- `FossilDebug:Invoke("species")` : chaque espèce a sa rareté, sa zone, son modèle (450 pièces au plus) et ses
  animations ; chaque rareté d'une zone a au moins une espèce ;
- `FossilDebug:Invoke("dinoshow")` : vitrine animée de toutes les espèces devant le premier joueur, une rangée par zone
  (de la plus commune à la plus rare) et les Secrets ; `dinoshow Glacier` (ou `5`) pour une zone, `dinoshow secret` ;
- `FossilDebug:Invoke("mutationshow", "Velociraptor")` : une espèce avec chaque mutation ; taille et niveau en plus :
  `mutationshow Compy Huge Golden` ;
- `FossilDebug:Invoke("clearshow")` : retire la vitrine.

## Ajouter une mutation

1. `Config.Economy.Mutations` : une entrée à sa place (de la plus commune à la plus rare, revenu au moins égal à celui
   d'avant), avec `Zone` pour une mutation de biome et `Color`.
2. `DinoBuilder.Mutations` (même ordre) et une branche dans `paintMutation` (couleurs des briques).
3. `MutationController.Effects` : son effet animé.
4. Tests : `t_mutation_rolls` (nombre de mutations, probas) et `t_mutation_client` vérifient tout le reste tout seuls.

## Sérum de mutation (objet)

Demande de Snaky (2026-10-11) : un objet qui applique une mutation à un dino, lui donne un bonus, avec une chance
d'échouer, comme le Fragment d'éclipse du Mutator de Pet Fusion Lab (objet consommé, 40 % de réussite, rien ne change
si ça rate, menu « choisir un pet, puis l'objet », écran « MUTATION! » ou « MUTATION FAILED »).

Valeurs : `src/shared/Config/Mutator.luau`. Serveur : `src/server/Services/MutatorService.luau` (remotes `MutateDino`,
`BuySerums`, clés replica `Serums` et `SerumPrice`, commande admin `serums <n> [joueur]`). Données :
`src/server/Data/Mutator.luau` (`Serums`, `SerumsUsed`). Menu : `src/client/Controllers/MutatorController.luau`, ouvert
par le bouton **MUTATE (SERUM)** du labo de fusion (le premier dino choisi dans le labo est repris). Test FossilDebug :
`serum`.

| Réglage | Valeur de départ |
|---|---|
| Réussite | 40 % (`SuccessChance`) |
| Réussite : mutation donnée | une mutation **meilleure** que celle du dino (revenu plus haut, ou même revenu et plus rare), tirée parmi les 12, poids = leur `Chance` (sans mutation : Amber 35 %, Crystal 13 %, ... Rainbow 0,22 %) |
| Échec | le sérum est perdu, le dino ne change pas (pas de malus) |
| Dino Rainbow | refusé (déjà la meilleure), aucun sérum perdu |
| Bonus | celui de la mutation (`Income` de `Config.Economy.Mutations`) et ses effets animés ; une mutation rare est annoncée au serveur comme à la réanimation |
| Prix (argent du jeu) | 10 min du revenu du joueur, au moins $2,500 (`PriceSeconds`, `MinPrice`) |
| Robux | produit `MutationSerums3` dans `Config.Shop.Products` (3 sérums, 99 R$ conseillé, caché tant que `Id = 0`) |
| Récompenses | calendrier jour 11 : 2 sérums (avant : 3 tours de roue) ; cadeau de 40 min : 1 sérum (avant : 1 tour) |
| Plafond | 99 sérums gardés, 10 achetés d'un coup |

Le menu affiche toujours la chance de réussite et la chance de chaque mutation possible (toute chance payante affiche
ses probas).
