# Steal a Fossil : prompt maître

Rédigé le 2026-10-10 à la demande de Snaky. Ce fichier découpe tout le projet en threads. Chaque thread reçoit : **la partie 1 (règles communes) + son brief numéroté (partie 3)**. La référence du jeu est `docs/GDD.md` dans ce repo.

---

## Partie 0 : pour le coordinateur du projet

- Repo : https://github.com/Ssnakyx/Steal-a-Fossile.git (branche `main`).
- Lancer un thread par brief, **par vagues** (partie 2). Une vague commence quand les briefs dont elle dépend ont leur PR fusionnée sur `main`.
- Modèle et effort de chaque thread (règle de Snaky, 2026-10-10) :
  - **Grosses tâches** : Opus 5.5 (`claude-opus-5-5`), effort `xhigh`.
  - **Petites tâches** : Sonnet 5.5 (`claude-sonnet-5-5`).
  - **Tout ce qui utilise Blender** : Opus 5.5 (`claude-opus-5-5`), effort `max`.
- Où tourne chaque thread :
  - **Cloud** : code Luau + tests hors Studio. Rien à faire sur le PC de Snaky.
  - **PC (Remote Control)** : Blender via MCP et Roblox Studio via le Studio MCP. Démarrer avec `start_rc_session` en passant `model` et `effort`. Chaque session travaille dans son propre clone `C:\Users\BOUYO\Desktop\Rblox Game\SAF-<nom>` (jamais le dossier principal, jamais le port Rojo 34872), sur sa branche, avec sa propre instance de Studio.
- Relayer tout de suite à chaque thread concerné : les « fusionne » de Snaky, les changements d'API annoncés par un autre thread, les conflits.
- Quand un thread a fini, rappeler à Snaky qu'il peut le fermer.

---

## Partie 1 : règles communes (à donner à chaque thread)

**Le jeu**
- Lire `docs/GDD.md` (seulement les sections utiles à ton brief) et ce fichier. Le GDD fait foi. Ne pas inventer de nouveau système de jeu : si le brief et le GDD ne le disent pas, demander à Snaky.
- Jeu calqué sur Steal an Egg : parcs alignés au spawn, route de 8 zones, gardiens, blocs fossiles, cuves, enclos, treadmill, fusion. Le parc est une zone sûre : rien n'y est jamais volable.

**Communication**
- Répondre à Snaky en français simple, court. Textes en jeu en anglais. Pas d'emoji dans l'UI.
- Un message par étape importante. Le message final commence par ce que Snaky doit faire (en général : `git pull`, tester dans Studio, ce qu'il faut regarder), puis les changements groupés par thème, puis ce qui n'a pas pu être vérifié.
- Tokens : ne jamais lire tout le projet. Seulement les fichiers de ton brief, un à la fois, les parties utiles.

**Git**
- Une branche par brief : `fossil/<nom-du-brief>` créée depuis `origin/main` à jour.
- Ne toucher **que les fichiers listés dans ton brief** (colonne « possède »). Pour un fichier d'un autre brief : demander au coordinateur, qui relaie.
- `git add <fichiers>` par nom (jamais `-A`, jamais `git add src/`). Commits en français, une ligne de résumé + puces, avec le trailer exigé par la session. Pas d'amend, pas de rebase, pas de force push.
- Pousser la branche et ouvrir une PR vers `main`. **Fusion sur `main` uniquement quand Snaky écrit « fusionne » dans ton thread** (pas relayé par une autre session), avec un merge commit. Avant de fusionner : merger `main` dans ta branche et relancer les tests.

**Roblox**
- **Ne jamais publier** sur Roblox (jamais Publish, Publish As, Update, Create). Snaky publie lui-même.
- Ne jamais cocher de case légale, taper de mot de passe, acheter quoi que ce soit, ni contester une modération.
- Serveur autoritaire partout : le client demande, le serveur vérifie (types, NaN avec `x == x`, distance, recharge, `RateLimit.Allow`) et décide.
- Passes et produits Robux : `Id = 0` dans la config tant que Snaky ne les a pas créés dans le Creator Hub. Un item avec `Id = 0` reste caché en jeu. `ProcessReceipt` idempotent par `PurchaseId`. Toute chance payante affiche ses probas.
- Contenu Minimal/Mild : vol cartoon (bonk, ragdoll), pas de dégâts, pas de sang, pas de morsure.

**Style et modèles**
- Tout en studs : cubes sur grille de 1 à 2 studs, couleurs plates, `SurfaceType.Studs` sur le dessus des pièces Plastic, formes rondes en escalier.
- Modèles faits dans Blender puis exportés en **données voxel Luau** (pipeline des boss de Pet Fusion Lab). **Aucun upload de mesh**. Avant tout export, rendre chaque modèle face et profil et refuser ce qui ressemble à une partie du corps (tube + boule, sphères par paires). Cous, queues et os en segments épais empilés.
- Budget lumière et Neon raisonnable, bloom modéré. Les visuels « IA » (rayons, halos partout, étoiles d'explosion) sont à éviter sauf demande du GDD.

**Studio (threads PC seulement)**
- Snaky a demandé Studio via le Studio MCP pour ce projet (2026-10-10) : tu peux lancer Play, lire l'Output, vérifier les visuels.
- Rojo reste la source du code : une modification de script faite dans Studio est écrasée au prochain sync. Le bouton Rojo Connect est cliqué par Snaky si besoin.
- Stop avant toute modification. Jamais deux Play en même temps sur le même PC.

**Tests**
- Avant chaque commit : `luau-lsp analyze` sans sortie et `selene src` propre.
- Tests hors Studio (`tools/luau_tests/run.py`) : ajouter un test pour chaque nouveau système, avec des appels hostiles sur chaque remote. Tester seulement ce qui change ; la suite complète tourne dans le brief Bilan.
- Commande de debug `FossilDebug` (BindableFunction Studio uniquement) : ajouter une sous-commande de test par système (`@@ nom: N OK / 0 FAIL`).

**Architecture (posée par le brief 1, à respecter)**
- `src/server/Services/<Nom>Service.luau` : chargés automatiquement par `Main` (chacun a `Init()` et éventuellement `Start()`). Ne pas modifier `Main`.
- `src/client/Controllers/<Nom>Controller.luau` : chargés automatiquement côté client.
- `src/shared/Config/<Domaine>.luau` : un fichier de config par domaine, lu via `Config.<Domaine>`. Tu n'édites que le tien.
- `src/shared/Remotes/<Domaine>.luau` : chaque domaine déclare ses remotes, enregistrés automatiquement.
- Tests : `tools/luau_tests/t_<domaine>_*.luau`, découverts automatiquement (pas de liste à éditer).

---

## Partie 2 : vagues et répartition

| # | Brief | Modèle / effort | Où | Dépend de |
|---|-------|-----------------|----|-----------|
| 1 | fondations | Opus 5.5 xhigh | Cloud | (rien) |
| 2 | pipeline-dinos | Opus 5.5 max | PC (Blender MCP) | (rien) |
| 3 | boucle | Opus 5.5 xhigh | Cloud | 1 |
| 4 | vitesse-treadmill | Opus 5.5 xhigh | Cloud | 1 |
| 5 | dinos-zones-1-4 | Opus 5.5 max | PC (Blender MCP) | 2 validé par Snaky |
| 6 | dinos-zones-5-8 | Opus 5.5 max | PC (Blender MCP) | 2 validé par Snaky |
| 7 | gardiens-vol | Opus 5.5 xhigh | Cloud | 3 |
| 8 | fusion | Opus 5.5 xhigh | Cloud | 2, 3 |
| 9 | blocs-hybrides | Opus 5.5 max | PC (Blender MCP) | 2, 8 |
| 10 | map | Opus 5.5 xhigh | PC (Studio MCP) | 3 |
| 11 | vfx | Opus 5.5 xhigh | PC (Studio MCP) | 3, 7, 10 |
| 12 | ui-ux | Opus 5.5 xhigh | Cloud puis PC | 3, 4, 8 |
| 13 | quotidien-quetes | Sonnet 5.5 | Cloud | 3, 12 |
| 14 | evenements | Sonnet 5.5 | Cloud | 3, 10 |
| 15 | social-analytics | Sonnet 5.5 | Cloud | 3 |
| 16 | sons | Sonnet 5.5 | Cloud | 3 |
| 17 | miniature-icone | Opus 5.5 max | PC (Blender MCP) | 5, 6 |
| 18 | bilan | Opus 5.5 xhigh | PC (Studio MCP) | tous |

- **Vague 1** : 1 et 2.
- **Vague 2** : 3 et 4 (après fusion de 1) ; 5 et 6 (après validation des 4 dinos pilotes par Snaky).
- **Vague 3** : 7, 8, 10 ; puis 9.
- **Vague 4** : 11, 12, 13, 14, 15, 16.
- **Vague 5** : 17, puis 18.

---

## Partie 3 : briefs

### 1. fondations (Opus 5.5 xhigh, cloud)
**But** : un projet Rojo propre où les autres threads n'ont qu'à ajouter leurs fichiers.
- Outils : `rokit.toml` (rojo 7.7.0, luau-lsp 1.70.1, selene 0.31.0), `default.project.json`, `selene.toml`, `.luaurc` (strict), `.gitignore`, `globalTypes.d.luau`, CI GitHub Actions (analyse + selene + tests hors Studio).
- Arborescence de la partie 1 (Services, Controllers, Config, Remotes) avec chargement automatique et un `Config/init.luau` qui agrège les domaines.
- Copier depuis Steal a Snack (https://github.com/Ssnakyx/Steal-a-Snack.git, **copie seulement, ne jamais modifier l'original**) et adapter : DataService (session lock, autosave, BindToClose, version de schéma), ProcessReceipt, RateLimit, Format, UIKit (base), harness `tools/luau_tests` (mocks, `run.py` avec découverte automatique des `t_*.luau`), FossilDebug, admin (`Config.Admins` + propriétaire du place).
- Schéma de données joueur de départ (argent, vitesse, dinos, blocs en cuve, index, achats traités, niveaux treadmill, quotidien, quêtes) avec migration versionnée.
- **Possède** : tout le squelette, `Main`, `Config/init.luau`, `Config/Core.luau`, `DataService`, `tools/`, CI, README.
- **Fini quand** : analyse et selene propres, tests verts, `docs/ARCHITECTURE.md` explique comment ajouter un service, un controller, une config, des remotes, un test.

### 2. pipeline-dinos (Opus 5.5 max, PC avec Blender MCP)
**But** : la chaîne Blender vers jeu, validée sur 4 dinos pilotes, un par famille de mouvement.
- Copier et adapter le pipeline de Pet Fusion Lab (https://github.com/Ssnakyx/PetLabFusion.git : `models/bosses/bosslib.py`, `models/anim/`) : voxelisation, os, fusion gloutonne des cubes (450 briques max par modèle), export en module Luau (`src/shared/DinoModels/<Espece>.luau`, en-tête `--!nocheck`), rendus de contrôle.
- Squelette du GDD (section Animations) : mâchoire, paupières, cou 2-3 segments, torse avant/arrière, queue 4-6 segments, pattes 3 parties, bras, ailes, nageoires, collerette/plaques.
- Les 4 familles (bipède, quadrupède, volant, nageur) avec leurs cycles de base.
- Tous les états du GDD : parc (Idle + variantes, Walk, Happy, Roar, Eat, Sleep, Spawn), gardien (Sleep, Wake, Roar, Run, Catch, Search, Return, BackToSleep), Fusion, Index. Fondus de 0.2 s.
- Runtime : `src/shared/DinoBuilder.luau` (construit le modèle en briques, échelle Small/Normal/Big/Huge, couleurs et matières des mutations Amber/Crystal/Lava, niveaux Golden/Diamond), `src/client/Controllers/DinoAnimController.luau` (lecteur d'animations, cadence réduite au loin, figé hors de vue).
- Pilotes : **Velociraptor** (bipède), **Triceratops** (quadrupède), **Pteranodon** (volant), **Mosasaurus** (nageur).
- Pour chaque pilote : planche d'images + MP4 de chaque état dans `/mnt/project-files/steal-a-fossil/anim-previews/<Espece>/` (ou envoyées dans le thread). **S'arrêter et attendre la validation de Snaky** avant que les briefs 5 et 6 démarrent.
- `models/README.md` + `models/BRIEF.md` (la recette exacte pour les briefs 5, 6, 9 et 17).
- **Possède** : `models/`, `src/shared/DinoModels/`, `src/shared/DinoBuilder.luau`, `src/client/Controllers/DinoAnimController.luau`, `src/shared/Config/Species.luau` (liste des espèces, famille, taille de base, revenu de base).

### 3. boucle (Opus 5.5 xhigh, cloud)
**But** : la boucle principale jouable de bout en bout avec des modèles provisoires.
- PlotService : 8 parcs alignés au spawn, attribution à l'arrivée, zone sûre (tout ce qui est dans le parc est invulnérable).
- Zones : données des 8 zones (ordre, vitesse conseillée, probas de rareté, espèces), géométrie provisoire (le brief 10 fera la vraie map, prévoir des points d'ancrage nommés).
- Gisements : remplissage toutes les 5 min (compte à rebours répliqué), annonce chat pour un bloc Secret.
- Arracher (maintenir 1 s, distance vérifiée), porter sur le dos (un seul bloc, malus de vitesse par rareté), rentrer au parc (le bloc devient à toi pour de bon).
- Cuves (2 au départ, jusqu'à 6), minuteurs par rareté, révélation (espèce tirée parmi la rareté et la zone, taille, mutation), enclos (slots agrandissables), revenus $/s, revenu hors ligne plafonné à 8 h.
- Tutoriel côté serveur : premier bloc Common garanti à la Beach.
- **Possède** : `PlotService`, `ZoneService`, `DigSiteService`, `CarryService`, `ReviveService`, `EnclosureService`, `IncomeService`, `Config/Zones.luau`, `Config/Rarity.luau`, `Config/Economy.luau`, `Remotes/Loop.luau`.

### 4. vitesse-treadmill (Opus 5.5 xhigh, cloud)
**But** : la vitesse comme stat principale et sa monétisation.
- Stat vitesse (appliquée à WalkSpeed avec une courbe lisible), malus de port géré avec le brief 3 (API `CarryService.GetSpeedMultiplier`).
- Treadmill dans le parc : vitesse par seconde en courant dessus ou AFK dessus. Rien à regarder pendant.
- Achat 25 R$ puis 10 niveaux de prix croissant (table du GDD) : **un produit développeur par niveau**, le serveur ne propose que le niveau suivant. Prix affiché lu sur Roblox (`GetProductInfo`).
- Vitesse gratuite : 10 trails achetées avec l'argent du jeu, récompense like + favori + groupe.
- Passes du GDD (x2 Money, x2 Treadmill, Fast Revive, VIP) et produits (Bear Traps x5, Server Luck x2 15 min, Instant Revive) dans `Config/Shop.luau`, tous `Id = 0`.
- **Possède** : `SpeedService`, `TreadmillService`, `TrailService`, `ShopService`, `Config/Speed.luau`, `Config/Shop.luau`, `Remotes/Shop.luau`.

### 5. dinos-zones-1-4 (Opus 5.5 max, PC avec Blender MCP)
**But** : les espèces des zones Beach, Fern Forest, Swamp, Canyon avec tous leurs états.
- Suivre exactement `models/BRIEF.md` du brief 2.
- Espèces : Compy, Oviraptor, Pteranodon (déjà pilote), Gallimimus, Parasaurolophus, Stegosaurus, Iguanodon, Baryonyx, Sarcosuchus, Pachycephalosaurus, Velociraptor (déjà pilote), Triceratops (déjà pilote).
- Personnalité par espèce (Compy nerveux, Stegosaurus lent…). Gardien de chaque zone = version x1.5 à x3 d'une espèce de la zone, avec tous les états gardien.
- Previews de chaque espèce pour Snaky, par lots de 4.
- **Possède** : `models/species/` des espèces listées, leurs `src/shared/DinoModels/<Espece>.luau`.

### 6. dinos-zones-5-8 (Opus 5.5 max, PC avec Blender MCP)
Même brief que 5 pour : Ankylosaurus, Therizinosaurus, Cryolophosaurus, Carnotaurus, Brachiosaurus, Spinosaurus, Plesiosaurus, Megalodon, Mosasaurus (déjà pilote), Quetzalcoatlus, Giganotosaurus, T-Rex, et les Secrets Golden Raptor, Crystal Rex, Lava Titan. Gardiens des zones 5 à 8.
- **Possède** : `models/species/` des espèces listées, leurs `src/shared/DinoModels/<Espece>.luau`.

### 7. gardiens-vol (Opus 5.5 xhigh, cloud)
**But** : les gardiens et le vol sur la route.
- IA serveur des gardiens : états Sleep, Wake, Roar, Run, Catch, Search, Return, BackToSleep (noms identiques aux animations du brief 2). Vitesse selon la zone. Catch = ragdoll cartoon, le bloc retourne au gisement. Pas de PivotTo serveur à 60 Hz : le client anime.
- Pelle (bonk, recharge 2 s, portée vérifiée), Bear Trap (immobilise 3 s, fait lâcher le bloc, marche aussi sur les gardiens).
- Bloc au sol : ramassable par tous sauf celui qui l'a lâché pendant 3 s, retour au gisement après 30 s.
- Protection débutant 10 min.
- Tests : appels hostiles (bonk de loin, bonk dans un parc, spam, ramassage pendant les 3 s).
- **Possède** : `GuardianService`, `PvpService`, `DroppedBlockService`, `Config/Guardians.luau`, `Config/Pvp.luau`, `Remotes/Pvp.luau`.

### 8. fusion (Opus 5.5 xhigh, cloud)
**But** : les deux modes de fusion.
- Upgrade : 3 dinos identiques (même espèce, même niveau) donnent Normal, puis Golden, puis Diamond. Garde la meilleure taille et la meilleure mutation.
- Hybride : 2 espèces différentes, recettes secrètes (environ 12 au lancement, jamais envoyées au client avant découverte), « Unknown recipe » rend les dinos, revenu (A + B) x1.5.
- Assemblage des hybrides au runtime à partir des groupes d'os des deux espèces (tête de A, corps et queue de B, ailes ou nageoires de celui qui en a), via `DinoBuilder` du brief 2 (demander l'API au coordinateur si besoin).
- **Possède** : `FusionService`, `Config/Fusion.luau` (recettes), `src/shared/HybridBuilder.luau`, `Remotes/Fusion.luau`.

### 9. blocs-hybrides (Opus 5.5 max, PC avec Blender MCP)
**But** : les modèles qui restent.
- Blocs fossiles : un bloc de roche voxel par rareté avec os incrustés visibles (formes sûres pour la modération).
- Validation visuelle des 12 hybrides assemblés par le brief 8 (rendus de chaque hybride et de ses animations), corrections des jointures.
- Apparence Golden et Diamond, poses d'Index.
- **Possède** : `models/blocks/`, `src/shared/BlockModels.luau`, corrections dans `models/hybrids/`.

### 10. map (Opus 5.5 xhigh, PC avec Studio MCP)
**But** : la map détaillée du GDD, en studs.
- Construite par code (`src/server/Map/MapBuilder.luau` + un module par zone) pour rester dans git, puis vérifiée et réglée dans Studio via le Studio MCP.
- Spawn : 8 parcs clôturés (enseigne au nom du joueur, emplacements cuves, enclos, treadmill, labo).
- 8 zones avec leur identité (GDD, section Map détaillée), arche d'entrée avec nom et vitesse conseillée, gisements décorés (cordes, pioches, lampes, piles de terre).
- Décor non collidable (`CanCollide/CanQuery/CanTouch/CastShadow = false`), placement par raycast, grille spatiale pour les zones à éviter, StreamingEnabled, budget lumière par zone, contrôle de la densité vue de haut.
- Utiliser les points d'ancrage du brief 3.
- Captures de chaque zone pour Snaky.
- **Possède** : `src/server/Map/`, `Config/Map.luau`.

### 11. vfx (Opus 5.5 xhigh, PC avec Studio MCP)
**But** : tous les effets du GDD, réglés dans Studio.
- Fossiles par rareté, mutations des dinos (couleurs et effets animés déjà faits : `MutationController`, `docs/MUTATIONS.md` ; il reste leurs sons), effets de gameplay (arrachage, réveil du gardien, bonk, bloc lâché, réanimation, fusion, météorites, treadmill), effets liés aux animations (poussière de pas, tremblement caméra, bulles).
- Côté client, distance cull, aucun effet sans limite.
- **Possède** : `src/client/Vfx/`, `src/shared/VfxSheets.luau`.

### 12. ui-ux (Opus 5.5 xhigh, cloud puis PC)
**But** : toute l'interface du GDD (section UI/UX).
- HUD (bloc de boutons à gauche, compteurs en bas à gauche, mobile iPhone 15 paysage), vitesse comparée à la zone, flèche et distance vers son parc pendant le transport, alerte gardien, minuteurs des cuves, labo de fusion, Index (espèces + hybrides, silhouettes, indices), shop (treadmill avec niveau suivant et prix réel), tutoriel fléché, écran de révélation.
- Previews avec `tools/luau_tests/ui_preview.py` (PC et `--phone`) ; vérification finale dans Studio.
- **Possède** : `src/client/UI/`, `src/client/Controllers/HudController.luau` et les controllers de menus.

### 13. quotidien-quetes (Sonnet 5.5, cloud)
Récompense quotidienne 14 jours, 3 quêtes par jour, récompenses de pages d'Index. Menus dans le style du brief 12.
- **Possède** : `DailyService`, `QuestService`, `Config/Daily.luau`, `Config/Quests.luau`, leurs menus.

### 14. evenements (Sonnet 5.5, cloud)
Pluie de météorites toutes les 20 min (alerte 30 s, blocs Epic+ pendant 60 s), compte à rebours de la mise à jour du samedi, commandes admin abuse.
- **Possède** : `EventService`, `Config/Events.luau`.

### 15. social-analytics (Sonnet 5.5, cloud)
Bonus ami (+10 % par ami, max 3), récompense like + favori + groupe (avec le brief 4), analytics (entonnoir du tutoriel, dépenses, sources d'argent).
- **Possède** : `SocialService`, `AnalyticsService`, `Config/Social.luau`.

### 16. sons (Sonnet 5.5, cloud)
Liste des sons nécessaires (pas, rugissements, bonk, réanimation, fusion, météorite, UI), `Config/Sounds.luau` avec `Id = 0` en attendant que Snaky les uploade, branchement aux événements. Pas de musique sauf demande.
- **Possède** : `SoundService` du jeu, `Config/Sounds.luau`.

### 17. miniature-icone (Opus 5.5 max, PC avec Blender MCP)
Miniatures et icône rendues dans Blender avec les modèles du repo (style de `/mnt/project-files/rework/ref_7_miniatures_style.png` s'il existe : avatar bacon hair, dino géant, « YOU! », valeurs $/s vertes, étiquette SECRET). Icône carrée sans texte, lisible à 64 px. **Rien n'est uploadé sans validation de Snaky.**
- **Possède** : `models/store/`.

### 18. bilan (Opus 5.5 xhigh, PC avec Studio MCP)
Intégration finale : merge de toutes les branches, suite complète des tests, tests à 2 joueurs dans Studio (vol sur la route, zone sûre, fusion, achats simulés), passe perf (nombre de briques, effets, réseau), corrections, rapport `docs/BILAN.md` avec ce que Snaky doit tester avant de publier lui-même.
