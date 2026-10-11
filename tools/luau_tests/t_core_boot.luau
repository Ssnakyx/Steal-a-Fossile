-- Démarrage du serveur : services chargés dans l'ordre, joueur prêt, départ propre, arrêt du serveur
local T = require("./testkit")
local env = T.env

local Boot = T.bootServer()

T.section("chargement")
local order = table.concat(Boot.Order, ",")
T.check(table.find(Boot.Order, "DataService") == 1, "DataService chargé en premier (" .. order .. ")")
for _, name in { "ReplicaService", "MoneyService", "ReceiptService", "AdminService", "DebugService" } do
	T.check(Boot.Services[name] ~= nil, name .. " chargé")
end
T.check(
	(table.find(Boot.Order, "ReplicaService") :: number) < (table.find(Boot.Order, "MoneyService") :: number),
	"ReplicaService avant MoneyService"
)
T.eq(#Boot.Errors, 0, "aucune erreur au démarrage")
T.check(env.game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") ~= nil, "dossier des remotes créé")

T.section("joueur")
local readySeen = 0
local Signals = T.lib("Signals")
Signals.Connect("PlayerReady", function()
	readySeen += 1
end)
local player = T.join()
T.eq(player:GetAttribute("Ready"), true, "attribut Ready")
T.check(Boot.IsReady(player), "Boot.IsReady")
T.eq(readySeen, 1, "signal PlayerReady une fois")
T.check(T.data(player) ~= nil, "données chargées")
local leaderstats = player:FindFirstChild("leaderstats")
T.check(leaderstats ~= nil and leaderstats:FindFirstChild("Money") ~= nil, "leaderstats Money")

T.section("départ")
T.leave(player)
T.check(not Boot.IsReady(player), "plus prêt après le départ")
T.check(T.data(player) == nil, "données libérées")
local saved = env.saved("SAF_Players_1", "Player_" .. player.UserId)
T.check(saved == nil, "rien d'écrit en Studio sans SaveInStudio")

T.section("arrêt du serveur")
local second = T.join()
T.check(Boot.IsReady(second), "deuxième joueur prêt")
env.close(30)
T.check(T.data(second) == nil, "données libérées à l'arrêt")

T.done("core_boot")
