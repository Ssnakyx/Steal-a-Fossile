-- Vie d'un joueur dans Boot, avec des services de test : ordre des hooks, départ pendant un OnPlayerReady qui attend,
-- ménage fait même quand la sauvegarde est perdue (verrou pris par un autre serveur)
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local DataService = T.service("DataService")

local folder = env.Instance.new("Folder")
folder.Name = "TestServices"
local function addService(name: string, module: any)
	local script = env.Instance.new("ModuleScript")
	script.Name = name
	env.Data[script].Extra.Module = module
	script.Parent = folder
end

local log: { string } = {}
local function logger(name: string, waits: number?): any
	return {
		Priority = string.byte(name),
		OnPlayerReady = function(player)
			table.insert(log, player.Name .. " ready " .. name)
			if waits then
				-- (contre la règle « ne pas attendre » : Boot doit quand même s'en sortir)
				env.task.wait(waits)
				table.insert(log, player.Name .. " ready " .. name .. " end")
			end
		end,
		OnPlayerRemoving = function(player, data)
			table.insert(log, player.Name .. " removing " .. name .. (if type(data) == "table" then "" else " (sans données)"))
		end,
	}
end
addService("DataService", DataService)
addService("AService", logger("A"))
addService("BService", logger("B"))
addService("CService", logger("C"))
local slow = logger("D", 5)
addService("DService", slow)
addService("EService", logger("E"))
addService("NotAService_x", {}) -- (mauvais nom : signalé, ignoré)

local Boot = env.module("src/server/Boot")
T.serverBoot = Boot
Boot.Start(folder)
env.flush()

T.section("chargement")
T.eq(table.concat(Boot.Order, ","), "DataService,AService,BService,CService,DService,EService", "ordre par priorité")
T.eq(#Boot.Errors, 1, "module mal nommé signalé")
table.clear(Boot.Errors)

T.section("départ pendant un OnPlayerReady qui attend")
local early = env.addPlayer({ Name = "Early" })
env.advance(1)
T.eq(table.concat(log, ","), "Early ready A,Early ready B,Early ready C,Early ready D", "hooks lancés jusqu'au service qui attend")
env.removePlayer(early)
env.advance(10)
T.eq(
	table.concat(log, ","),
	"Early ready A,Early ready B,Early ready C,Early ready D,Early ready D end,Early removing D,Early removing C,Early removing B,Early removing A",
	"les services suivants ne voient pas le joueur parti ; ceux qui l'ont vu font leur ménage, à l'envers"
)
T.check(not Boot.IsReady(early), "jamais prêt")
T.eq(early:GetAttribute("Ready"), nil, "pas d'attribut Ready")
T.check(env.saved("SAF_Players_1", "Player_" .. early.UserId)._Lock == nil, "sauvegarde rendue")

T.section("joueur normal")
table.clear(log)
slow.OnPlayerReady = function(player)
	table.insert(log, player.Name .. " ready D")
end
local normal = T.join({ Name = "Normal" })
T.eq(table.concat(log, ","), "Normal ready A,Normal ready B,Normal ready C,Normal ready D,Normal ready E", "tous les hooks dans l'ordre")
T.check(Boot.IsReady(normal), "prêt")

T.section("sauvegarde prise par un autre serveur")
table.clear(log)
local stolen = env.saved("SAF_Players_1", "Player_" .. normal.UserId)
stolen._Lock = { Job = "other", Session = "other", Time = env.os.time() }
env.datastore.set("SAF_Players_1/global", "Player_" .. normal.UserId, stolen)
T.eq(DataService.Save(normal), false, "sauvegarde refusée")
env.advance(1)
T.eq(normal.Parent, nil, "joueur expulsé")
T.eq(
	table.concat(log, ","),
	"Normal removing E,Normal removing D,Normal removing C,Normal removing B,Normal removing A",
	"chaque service fait son ménage même sans sauvegarde"
)

T.section("arrêt du serveur")
table.clear(log)
local last = T.join({ Name = "Last" })
env.close(30)
T.check(table.find(log, "Last removing A") ~= nil, "hooks de départ à l'arrêt")
T.eq(last.Parent, nil, "joueur parti")
T.check(env.saved("SAF_Players_1", "Player_" .. last.UserId)._Lock == nil, "sauvegarde rendue à l'arrêt")

T.done("core_lifecycle")
