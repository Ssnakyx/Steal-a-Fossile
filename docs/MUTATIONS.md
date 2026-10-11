# Mutations et nouvelles espèces

Ce que le thread « 5 nouveaux dinos par biome et système de mutations » met en place : 12 mutations (les 3 du GDD,
une par biome et Rainbow), leurs couleurs et leurs effets animés, l'annonce des plus rares, et 40 espèces de plus
(5 par biome, des créatures fantastiques pour les plus rares).

Valeurs : `src/shared/Config/Economy.luau` (`Mutations`, `MutationAnnounce`). Couleurs des briques :
`src/shared/DinoBuilder.luau`. Effets animés : `src/client/Controllers/MutationController.luau`. Annonce et commande
admin : `src/server/Services/MutationService.luau`.

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
