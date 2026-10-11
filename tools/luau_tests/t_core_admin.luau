-- AdminService : qui est admin, commandes, arguments hostiles, remote Admin
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Enum = env.Enum
local game = env.game
env.setProperty(game, "CreatorType", Enum.CreatorType.User)
env.setProperty(game, "CreatorId", 555)
local Boot = T.bootServer()
local AdminService = Boot.Services.AdminService
local MoneyService = Boot.Services.MoneyService
local ReceiptService = Boot.Services.ReceiptService

T.section("qui est admin")
local snaky = T.join({ UserId = 3346721423, Name = "Snaky" })
local owner = T.join({ UserId = 555, Name = "Owner" })
local random = T.join({ UserId = 42, Name = "Random" })
T.check(AdminService.IsAdmin(snaky), "Config.Core.Admins")
T.check(AdminService.IsAdmin(owner), "créateur du jeu")
T.check(not AdminService.IsAdmin(random), "joueur normal")
T.eq(snaky:GetAttribute("Admin"), true, "attribut Admin")
T.eq(random:GetAttribute("Admin"), false, "attribut Admin faux")

T.section("droits")
local ok, text = AdminService.Run(random, "money", { "1000" })
T.check(not ok and text == "Not allowed", "commande refusée à un joueur normal")
T.eq(MoneyService.Get(random), 0, "rien donné")
ok, text = env.invokeServer(random, "Admin", "money", { "1000" })
T.check(not ok and text == "Not allowed", "remote refusé à un joueur normal")

T.section("commandes")
ok, text = AdminService.Run(snaky, "help")
T.check(ok and string.find(text, "money", 1, true) ~= nil and string.find(text, "simulate", 1, true) ~= nil, "help")
ok = AdminService.Run(snaky, "money", { "500" })
T.check(ok, "money 500")
T.eq(MoneyService.Get(snaky), 500, "argent ajouté")
ok = AdminService.Run(snaky, "MONEY", { "=42" })
T.check(ok, "nom de commande sans casse, money =42")
T.eq(MoneyService.Get(snaky), 42, "argent fixé")
ok = AdminService.Run(snaky, "money", { 7 })
T.check(ok, "argument nombre accepté")
T.eq(MoneyService.Get(snaky), 49, "argent ajouté (nombre)")
ok = AdminService.Run(snaky, "money", { "10", "rand" })
T.check(ok, "money vers un autre joueur (début du nom)")
T.eq(MoneyService.Get(random), 10, "autre joueur payé")
for _, bad in { "abc", "-5", "nan", "inf", "1e16", "=-1", "" } do
	ok = AdminService.Run(snaky, "money", { bad })
	T.check(not ok, "money " .. bad .. " refusé")
end
T.eq(MoneyService.Get(snaky), 49, "argent intact après les refus")
ok, text = AdminService.Run(snaky, "money", { "10", "nobody" })
T.check(not ok and text == "Player not found", "joueur introuvable")

T.section("arguments hostiles")
local function refused(args: any, label: string)
	local success, message = AdminService.Run(snaky, "money", args)
	T.check(not success and type(message) == "string", label)
end
refused("10", "arguments pas en table")
refused({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11" }, "trop d'arguments")
refused({ string.rep("9", 200) }, "argument trop long")
refused({ "1\n0" }, "caractère de contrôle")
refused({ {} }, "table en argument")
refused({ 0 / 0 }, "NaN en argument")
ok, text = AdminService.Run(snaky, string.rep("a", 1000))
T.check(not ok, "nom de commande trop long")
ok, text = AdminService.Run(snaky, nil)
T.check(not ok and text == "Unknown command (try: help)", "commande absente")
ok, text = AdminService.Run(snaky, {})
T.check(not ok, "commande en table")

T.section("enregistrement")
T.errors(function()
	AdminService.RegisterCommand("Bad", { Description = "x", Run = function()
		return true, ""
	end })
end, "nom invalide", "nom en majuscules refusé")
T.errors(function()
	AdminService.RegisterCommand("help", { Description = "x", Run = function()
		return true, ""
	end })
end, "déjà prise", "nom en double refusé")
T.errors(function()
	AdminService.RegisterCommand("norun", { Description = "x" } :: any)
end, "Description, Run", "sans Run refusé")
AdminService.RegisterCommand("boom", {
	Description = "Fails on purpose",
	Run = function()
		error("boom")
	end,
})
ok, text = AdminService.Run(snaky, "boom")
T.check(not ok and text == "Error", "erreur d'une commande attrapée")

T.section("simulate")
ReceiptService.Register("AdminTestProduct", 0, function(_player, data)
	data.TankCount += 1
	return true
end)
ok, text = AdminService.Run(snaky, "simulate", { "AdminTestProduct" })
T.check(not ok and text == "Studio only", "simulate refusé sur un vrai serveur")
T.eq(T.data(snaky).TankCount, 2, "rien donné hors Studio")
env.studio = true
ok, text = AdminService.Run(snaky, "simulate", { "AdminTestProduct" })
T.check(ok, "simulate en Studio (" .. tostring(text) .. ")")
T.eq(T.data(snaky).TankCount, 3, "produit simulé donné")
ok = AdminService.Run(snaky, "simulate", { "Nope" })
T.check(not ok, "simulate produit inconnu")
env.studio = false
ok = AdminService.Run(random, "simulate", { "AdminTestProduct" })
T.check(not ok, "simulate refusé à un joueur normal")

T.section("remote Admin")
ok, text = env.invokeServer(snaky, "Admin", "money", { "1" })
T.check(ok == true and type(text) == "string", "remote Admin")
local slowed = 0
for _ = 1, 20 do
	local success, message = env.invokeServer(snaky, "Admin", "help")
	if not success and message == "Slow down!" then
		slowed += 1
	end
end
T.check(slowed >= 10, "limite de fréquence sur le remote (" .. slowed .. " refusés)")

T.section("groupe propriétaire")
env.setProperty(game, "CreatorType", Enum.CreatorType.Group)
env.setProperty(game, "CreatorId", 777)
env.groups[777] = { Name = "Fossil Studio", Owner = { Id = 888, Name = "GroupOwner" } }
local groupOwner = T.join({ UserId = 888 })
local member = T.join({ UserId = 889 })
T.check(AdminService.IsAdmin(groupOwner), "propriétaire du groupe admin")
T.check(not AdminService.IsAdmin(member), "membre du groupe pas admin")

T.section("Studio")
env.studio = true
T.check(AdminService.IsAdmin(random), "tout le monde est admin en Studio")
env.studio = false

-- (la commande boom a levé une erreur exprès)
table.clear(env.errors)
T.done("core_admin")
