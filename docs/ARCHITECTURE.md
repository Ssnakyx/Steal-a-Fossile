# Architecture du code (brief 1 « fondations »)

Ce fichier explique comment ajouter du code au jeu sans toucher au squelette. Règle d'or : **on ajoute des fichiers, on ne modifie pas ceux des autres**. Tout est chargé automatiquement.

## Arbre du projet

```
default.project.json          arbre Rojo (Shared, Server, Client)
src/shared/   -> ReplicatedStorage.Shared       (serveur + client)
  Config/<Domaine>.luau          configuration lisible par tous : Config.<Domaine>
  Remotes/<Domaine>.luau         déclaration des remotes de chaque domaine
  Format.luau, Signal.luau       nombres et durées pour l'UI ; signal simple
src/server/   -> ServerScriptService.Server     (serveur seulement)
  Main.server.luau, Boot.luau    démarrage (ne pas modifier)
  Services/<Nom>Service.luau     logique du jeu, chargée automatiquement
  Data/<Domaine>.luau            champs de la sauvegarde de chaque domaine
  DebugTests/<Domaine>.luau      tests FossilDebug (Studio)
  ServerConfig/<Domaine>.luau    configuration secrète (jamais envoyée aux clients)
  Lib/                           Guard, Net, RateLimit, Signals, Notify, Leaderstats
src/client/   -> StarterPlayerScripts.Client    (client seulement)
  Main.client.luau, Boot.luau    démarrage (ne pas modifier)
  Controllers/<Nom>Controller.luau  logique client, chargée automatiquement
  UI/UIKit.luau                  boîte à outils d'interface (brief 12 la complète)
tools/                           outils, tests hors Studio, aperçu d'interface, vérifications
```

Mode strict partout (`--!strict` en première ligne de chaque fichier de `src/`).

## Vérifier avant chaque commit

```
python3 tools/check.py          outils, analyse stricte, selene, tests hors Studio, build Rojo
python3 tools/check.py --fast   sans les tests ni le build
python3 tools/luau_tests/run.py loop    seulement les tests dont le nom contient « loop »
```

La CI (`.github/workflows/ci.yml`) lance `tools/check.py` sur chaque PR. Les outils (rojo, luau-lsp, selene, luau) sont ceux de `rokit.toml` ; `python3 tools/setup_tools.py` les télécharge dans `tools/.bin` si Rokit n'est pas installé.

## Ajouter un service (serveur)

Créer `src/server/Services/<Nom>Service.luau` (le nom doit finir par `Service`) :

```lua
--!strict
-- Ce que fait le service, en une ou deux lignes. Signaux émis : ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Parent.Lib.Net)
local Guard = require(script.Parent.Parent.Lib.Guard)
local MoneyService = require(script.Parent.MoneyService)

local GemService = {}
GemService.Priority = 0 -- facultatif : plus petit = chargé avant (DataService -100 ... AdminService -60)

function GemService.Init()
	-- poser les handlers de remotes, enregistrer les produits Robux et les commandes d'admin
end

function GemService.Start()
	-- boucles, minuteurs (tourne dans son propre fil)
end

function GemService.OnPlayerReady(player: Player, data: { [string]: any })
	-- joueur chargé : data est sa sauvegarde vivante. Ne pas attendre ici (pas de task.wait).
end

function GemService.OnPlayerRemoving(player: Player, data: { [string]: any })
	-- juste avant la dernière sauvegarde
end

return GemService
```

Ordre : tous les `Init` (par priorité puis par nom), puis tous les `Start`. Quand tous les `OnPlayerReady` sont passés, le joueur reçoit l'attribut `Ready = true` et le signal `PlayerReady` part. Une erreur dans un service est notée (`warn [Boot]`) sans bloquer les autres.

Services du socle :

| Service | À quoi il sert |
|---|---|
| `DataService` | sauvegarde : `DataService.Get(player)` renvoie la table vivante (nil si pas chargé), `DataService.Save(player)` écrit tout de suite |
| `ReplicaService` | état du joueur pour son client : `ReplicaService.Set(player, "Gems", 12)` |
| `MoneyService` | argent : `Add`, `Spend`, `CanAfford`, `Get` (tout l'argent passe par lui) |
| `ReceiptService` | achats Robux : `Register(clé, id, grant)` |
| `AdminService` | admins et commandes : `IsAdmin`, `RegisterCommand` |
| `DebugService` | `FossilDebug` en Studio : `RegisterTest`, `RegisterCommand` |

Communication entre services sans `require` en cercle : `Lib/Signals.luau` (`Signals.Fire("DinoRevived", player, dino)` / `Signals.Connect`). Liste les signaux de ton domaine en tête de ton service.

## Ajouter un controller (client)

Créer `src/client/Controllers/<Nom>Controller.luau` (nom fini par `Controller`), avec `Priority`, `Init()` et `Start()` facultatifs, comme un service. L'état du joueur se lit avec `ReplicaController` :

```lua
local ReplicaController = require(script.Parent.ReplicaController)
ReplicaController.Observe("Money", function(money) label.Text = Format.Money(money or 0) end)
```

Le client ne décide jamais : il demande au serveur par un remote et affiche la réponse.

## Ajouter une configuration

- Tout ce que le client peut voir : `src/shared/Config/<Domaine>.luau`, lu partout avec `Config.<Domaine>` (`local Config = require(ReplicatedStorage.Shared.Config)`). Lire un domaine qui n'existe pas lève une erreur.
- Ce qui doit rester secret (recettes d'hybrides, tables de tirage cachées) : `src/server/ServerConfig/<Domaine>.luau`, lu avec `ServerConfig.<Domaine>` côté serveur. **Tout ce qui est dans `src/shared` est lisible par les exploiteurs.**
- Produits et passes Robux : `Id = 0` tant que Snaky ne les a pas créés. Un item à `Id = 0` reste caché en jeu.

## Ajouter des remotes

1. Déclarer dans `src/shared/Remotes/<Domaine>.luau`. La description commence par le sens, **« client -> serveur »** ou **« serveur -> client »** (le test `t_core_remotes` le vérifie) :

```lua
--!strict
return {
	Events = {
		DigBlock = "client -> serveur : creuser un bloc (blockId)",
		BlockDug = "serveur -> client : bloc creusé (blockId, rarity)",
	},
	Functions = {
		BuyTrail = "client -> serveur : acheter un trail (trailId) -> (ok, texte)",
	},
	-- Unreliable = { ... } pour les mises à jour fréquentes qui peuvent se perdre
}
```

2. Poser le handler côté serveur dans l'`Init` du service, avec `Lib/Net.luau` (limite de fréquence et erreurs attrapées). Vérifier chaque argument avec `Lib/Guard.luau` :

```lua
Net.Function("BuyTrail", { Rate = 2, Burst = 4 }, function(player, trailId)
	local id = Guard.Key(trailId, Config.Speed.Trails)
	if not id then
		return false, "Unknown trail"
	end
	...
	return true, "Trail equipped"
end)
```

3. Côté client : `Remotes.Function("BuyTrail"):InvokeServer(id)`, `Remotes.Event("BlockDug").OnClientEvent:Connect(...)`.

Chaque remote « client -> serveur » doit avoir un handler `Net` (sinon `t_core_remotes` échoue), et `t_core_remotes` l'appelle automatiquement avec des valeurs hostiles (NaN, infini, tables géantes, instances...) : aucune erreur et aucune donnée abîmée permises. Le serveur vérifie toujours types, NaN (`x == x`), distance (`Guard.Near`), recharge et fréquence. Messages au joueur : `Notify.Send(player, "Not enough money!", "error")` (textes en anglais, sans emoji).

## Ajouter des données à la sauvegarde

Créer `src/server/Data/<Domaine>.luau` (chargé automatiquement par `DataService`) :

```lua
--!strict
return {
	Version = 1,                         -- monter à chaque changement de format
	Defaults = { Gems = 0, GemLog = {} },
	Migrate = function(data, from) end,  -- (facultatif) sauvegarde de la version `from` -> version actuelle
	Sanitize = function(data) end,       -- (facultatif) répare les valeurs abîmées après chaque chargement
	BeforeSave = function(data, elapsed) end, -- (facultatif) avant chaque écriture
}
```

- Un champ appartient à un seul domaine (doublon = erreur au démarrage). `Version`, `Domains` et `_Lock` sont réservés.
- Un champ manquant prend sa valeur de départ, aussi dans les sous-tables ; une valeur du mauvais type est remplacée.
- Clés des tables : texte (`"1"`, `"Triceratops"`) ou listes sans trou. NaN et infini deviennent 0 à la sauvegarde (avec un warn).
- La sauvegarde a un verrou de session (deux serveurs n'écrivent jamais la même), est écrite toutes les 60 s, au départ et à l'arrêt du serveur. Une sauvegarde plus récente que le code n'est jamais chargée.
- Studio lit la vraie sauvegarde mais ne l'écrit pas (`Config.Core.Data.SaveInStudio`).

Domaines posés par le brief 1 : `Core` (argent, temps de jeu, achats, index), `Loop` (brief 3 : dinos, cuves, enclos, tutoriel), `Speed` (brief 4 : vitesse, treadmill, trails), `Daily` et `Quests` (brief 13). Chaque brief complète le sien.

## Ajouter un produit Robux

Dans l'`Init` du service qui le donne :

```lua
ReceiptService.Register("TreadmillLevel2", Config.Shop.Products.TreadmillLevel2.Id, function(player, data, receipt)
	if data.TreadmillLevel ~= 1 then
		return false -- vérifier tout AVANT de modifier data ; ne pas attendre
	end
	data.TreadmillLevel = 2
	return true
end)
```

Le reçu n'est confirmé à Roblox qu'après une sauvegarde réussie, et un même `PurchaseId` n'est jamais donné deux fois. `ReceiptService.IsOnSale(clé)` dit si le produit existe (Id ≠ 0). Pour tester sans Robux : commande d'admin `simulate <clé>` ou `ReceiptService.Simulate(player, clé)`.

## Ajouter une commande d'admin

```lua
AdminService.RegisterCommand("meteor", {
	Description = "Start a meteor shower now",
	Usage = "meteor",
	Run = function(player, args) return true, "Meteor shower started" end,
})
```

Admins : `Config.Core.Admins`, le créateur du jeu (ou le propriétaire du groupe), et tout le monde dans Studio.

## Ajouter un test FossilDebug (Studio)

Créer `src/server/DebugTests/<Domaine>.luau` (chargé seulement dans Studio) :

```lua
--!strict
local DebugService = require(script.Parent.Parent.Services.DebugService)
type Tester = DebugService.Tester

return {
	gems = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		t:Equal(1 + 1, 2, "math works")
	end,
}
```

Pendant un Play, barre de commande en vue serveur : `game.ServerScriptService.FossilDebug:Invoke("all")` (ou `"gems"`, `"help"`). Chaque test finit par `@@ nom: N OK / 0 FAIL`.

## Ajouter un test hors Studio

Créer `tools/luau_tests/t_<domaine>_<sujet>.luau` (découvert automatiquement) :

```lua
local T = require("./testkit")
local env = T.env

local Boot = T.bootServer()          -- démarre le serveur comme dans le jeu
local player = T.join()              -- joueur chargé et prêt
local GemService = Boot.Services.GemService

T.eq(T.data(player).Gems, 0, "pas de gemmes au départ")
local ok, text = env.invokeServer(player, "BuyGem", 0 / 0)   -- client hostile
T.check(not ok, "NaN refusé")
T.advance(60)                        -- temps virtuel (task.wait, autosave, minuteurs)
T.done("gems")                       -- @@ gems: N OK / 0 FAIL
```

Le faux Roblox (`env.luau`) vérifie les noms et les types des propriétés comme Studio. Il simule l'arbre du jeu, le temps (`env.advance`), les joueurs (`env.addPlayer`, `env.removePlayer`), le DataStore (`env.datastore` : pannes, lenteurs, `env.saved`), les achats (`env.purchase`), les remotes (`env.fireServer`, `env.invokeServer`, `env.received`) et le client dans le même test (`env.addPlayer({ Local = true })` puis `env.module("src/client/Boot").Start()`, voir `t_core_client.luau`). Une méthode Roblox non simulée lève une erreur : la simuler dans le test avec `env.stubMethod(classe, nom, fonction)`.

## Aperçu de l'interface hors Studio

`tools/luau_tests/p_<domaine>_<sujet>.luau` construit un écran avec le vrai code client ; `python3 tools/luau_tests/ui_preview.py [filtre] [--phone]` en fait des images (HTML + PNG avec Chromium, dans `tools/.cache/ui_preview/`). Exemple : `p_core_uikit.luau`. Ce n'est pas le rendu exact de Roblox, mais les tailles, les positions et les chevauchements sont ceux du code. Vérification finale dans Studio.

## Qui possède quoi

Le brief 1 possède le squelette : `Main`, les deux `Boot`, `Config/init.luau`, `Config/Core.luau`, `Remotes/init.luau`, `Remotes/Core.luau`, `ServerConfig/init.luau`, `Lib/`, les services du socle, `Data/Core.luau`, `DebugTests/Core.luau`, `tools/`, la CI et le README. Les fichiers `Data/Loop.luau`, `Data/Speed.luau`, `Data/Daily.luau` et `Data/Quests.luau` sont posés par le brief 1 mais appartiennent aux briefs 3, 4 et 13. `UI/UIKit.luau` appartient au brief 12 (`src/client/UI/`). Pour changer un fichier qui n'est pas à toi : demander au coordinateur.
