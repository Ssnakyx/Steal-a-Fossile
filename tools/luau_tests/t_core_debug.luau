-- FossilDebug (Studio seulement) : la commande « all » passe tous les tests en jeu sans échec ; MoneyService
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local DebugService = Boot.Services.DebugService
local MoneyService = Boot.Services.MoneyService
local Signals = T.lib("Signals")

T.section("FossilDebug")
local bindable = env.game:GetService("ServerScriptService"):FindFirstChild("FossilDebug")
T.check(bindable ~= nil and bindable:IsA("BindableFunction"), "BindableFunction FossilDebug créée en Studio")
local player = T.join()
for _, name in { "data", "money", "receipts", "remotes", "admin", "format" } do
	T.check(table.find(DebugService.Tests(), name) ~= nil, "test en jeu " .. name)
end
local report = bindable:Invoke("all")
local ok, fail = string.match(report, "@@ all: (%d+) OK / (%d+) FAIL")
T.check(ok ~= nil and tonumber(ok) > 20, "tests en jeu lancés (" .. tostring(ok) .. " OK)")
T.eq(fail, "0", "aucun échec en jeu")
if fail ~= "0" then
	print(report)
end
local single = bindable:Invoke("format")
T.check(string.find(single, "@@ format: ", 1, true) ~= nil, "un seul test")
T.check(string.find(bindable:Invoke("help"), "all", 1, true) ~= nil, "help")
T.check(string.find(bindable:Invoke("nope"), "Unknown command", 1, true) ~= nil, "commande inconnue")
DebugService.RegisterCommand("echo", function(text)
	return "echo " .. tostring(text)
end)
T.eq(bindable:Invoke("echo", "hi"), "echo hi", "commande outil")
DebugService.RegisterTest("failing", function(t)
	t:Check(false, "fails on purpose")
	error("boom")
end)
local failingOk, failingFail = DebugService.RunTest("failing")
T.eq(failingOk, 0, "test en échec : 0 OK")
T.eq(failingFail, 2, "test en échec : échec et erreur comptés")
T.errors(function()
	DebugService.RegisterTest("failing", function() end)
end, "déjà pris", "nom de test en double")
T.errors(function()
	DebugService.RegisterTest("Bad", function() end)
end, "nom invalide", "nom de test invalide")

T.section("MoneyService")
local changes = {}
Signals.Connect("MoneyChanged", function(p, delta, reason, total)
	table.insert(changes, { p, delta, reason, total })
end)
MoneyService.Set(player, 0, "Test")
env.flush()
table.clear(changes)
local earned = T.data(player).TotalEarned
T.check(MoneyService.Add(player, 100, "Income"), "Add")
T.check(not MoneyService.Add(player, 0 / 0, "Bad"), "Add NaN refusé")
T.check(not MoneyService.Add(player, -1, "Bad"), "Add négatif refusé")
T.check(not MoneyService.Add(player, math.huge, "Bad"), "Add infini refusé")
T.check(MoneyService.CanAfford(player, 100), "CanAfford")
T.check(not MoneyService.CanAfford(player, 101), "CanAfford trop cher")
T.check(not MoneyService.CanAfford(player, 0 / 0), "CanAfford NaN")
T.check(not MoneyService.Spend(player, 101, "Too much"), "Spend trop cher refusé")
T.check(MoneyService.Spend(player, 40, "Trail"), "Spend")
T.eq(MoneyService.Get(player), 60, "solde")
T.eq(T.data(player).TotalEarned - earned, 100, "TotalEarned ne compte que les gains")
env.flush()
T.eq(#changes, 2, "MoneyChanged à chaque mouvement")
T.check(changes[2] and changes[2][2] == -40 and changes[2][3] == "Trail" and changes[2][4] == 60, "MoneyChanged(delta, raison, total)")
T.eq(player.leaderstats.Money.Value, "$60", "leaderstats à jour")
local Core = T.config().Core
MoneyService.Set(player, Core.MaxMoney, "Test")
MoneyService.Add(player, Core.MaxMoney, "Test")
T.eq(MoneyService.Get(player), Core.MaxMoney, "argent plafonné")
env.datastore.latency = 5
local outsider = env.addPlayer()
T.check(not MoneyService.Add(outsider, 10, "Test"), "joueur pas chargé")
T.eq(MoneyService.Get(outsider), 0, "Get d'un joueur pas chargé")
T.check(not MoneyService.Spend(outsider, 0, "Test"), "Spend d'un joueur pas chargé")
env.datastore.latency = 0
env.advance(10)

T.done("core_debug")
