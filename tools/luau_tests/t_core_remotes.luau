-- Remotes : déclarations, handlers serveur, et appels hostiles sur chaque remote (tous domaines confondus).
-- Ce test couvre aussi les remotes ajoutés par les autres briefs : chaque nouveau remote client -> serveur doit
-- avoir un handler Net et survivre aux valeurs hostiles sans erreur ni donnée abîmée.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Boot = T.bootServer()
local Remotes = T.module("src/shared/Remotes")
local Net = T.lib("Net")
local DataService = Boot.Services.DataService
local MoneyService = Boot.Services.MoneyService

T.section("déclarations")
local list = Remotes.List()
T.check(#list >= 4, "remotes déclarés")
for _, name in { "Replica", "Notify", "GetReplica", "Admin" } do
	T.check(Remotes.Find(name) ~= nil, "remote " .. name)
end
for _, declaration in list do
	local doc = declaration.Doc
	local toClient = string.sub(doc, 1, 17) == "serveur -> client"
	local toServer = string.sub(doc, 1, 17) == "client -> serveur"
	T.check(toClient or toServer, declaration.Name .. " : la doc commence par « serveur -> client » ou « client -> serveur »")
	if toServer then
		T.check(Net.Handled[declaration.Name] == true, declaration.Name .. " a un handler Net côté serveur")
	end
	if toClient then
		T.check(declaration.Kind ~= "Function", declaration.Name .. " : pas de RemoteFunction serveur -> client")
	end
	local remote = env.game:GetService("ReplicatedStorage").Remotes:FindFirstChild(declaration.Name)
	T.check(remote ~= nil, declaration.Name .. " créé dans ReplicatedStorage.Remotes")
end
T.errors(function()
	Remotes.Event("Nope")
end, "Remote inconnu", "remote inconnu")
T.errors(function()
	Remotes.Function("Replica")
end, "de genre Event", "mauvais genre")
T.errors(function()
	Net.Function("Admin", { Rate = 1 }, function() end)
end, "déjà un handler", "deux handlers refusés")
T.errors(function()
	Net.Event("Notify", { Rate = 0 }, function() end)
end, "limite invalide", "limite invalide refusée")

T.section("valeurs hostiles, joueur normal")
local player = T.join({ UserId = 7 })
local before = MoneyService.Get(player)
local calls = T.fuzzRemotes(player)
T.check(calls > 100, "appels hostiles faits (" .. calls .. ")")
T.clean("aucune erreur avec un joueur normal")
T.eq(#DataService.Problems(T.data(player)), 0, "données intactes")
T.eq(MoneyService.Get(player), before, "argent intact")
T.check(player.Parent ~= nil, "le serveur tient (joueur toujours là)")

T.section("valeurs hostiles, admin")
local admin = T.join({ UserId = 3346721423 })
T.fuzzRemotes(admin)
T.clean("aucune erreur avec un admin")
T.eq(#DataService.Problems(T.data(admin)), 0, "données de l'admin intactes")

T.section("valeurs hostiles, joueur pas encore chargé")
env.datastore.latency = 5
local loading = env.addPlayer({ UserId = 9 })
T.fuzzRemotes(loading)
env.datastore.latency = 0
T.clean("aucune erreur avant le chargement")
env.waitUntil(function()
	return loading:GetAttribute("Ready") == true
end, "joueur chargé", 60)
T.eq(#DataService.Problems(T.data(loading)), 0, "données saines après le chargement")

T.section("spam")
local results = T.spam(player, "GetReplica", 30)
local slowed = 0
for _, result in results do
	if result[1] == false and result[2] == "Slow down!" then
		slowed += 1
	end
end
T.check(slowed >= 20, "GetReplica limité (" .. slowed .. " refusés sur 30)")

T.done("core_remotes")
