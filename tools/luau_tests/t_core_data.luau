-- DataService : valeurs de départ, verrou de session, migrations, versions trop récentes, pannes, réparations
local T = require("./testkit")
local env = T.env

env.studio = false -- serveur en ligne : les sauvegardes s'écrivent
env.quiet = true
local STORE = "SAF_Players_1/global"
local Boot = T.bootServer()
local DataService = Boot.Services.DataService
local Core = T.config().Core

local function key(userId: number): string
	return "Player_" .. tostring(userId)
end

local function kickedWith(player: any, text: string): boolean
	for _, kick in env.kicks do
		if kick.Player == player and string.find(kick.Message, text, 1, true) then
			return true
		end
	end
	return false
end

local function warned(text: string): boolean
	for _, line in env.warnings do
		if string.find(line, text, 1, true) then
			return true
		end
	end
	return false
end

T.section("domaines")
T.eq(table.concat(DataService.Domains(), ","), "Core,Daily,Loop,Quests,Speed", "domaines chargés depuis src/server/Data")
T.eq(DataService.Owner("Money"), "Core", "Money appartient à Core")
T.eq(DataService.Owner("Dinos"), "Loop", "Dinos appartient à Loop")
T.errors(function()
	DataService.RegisterDomain("Bad", { Version = 1, Defaults = { Money = 1 } })
end, "appartient déjà", "champ en double refusé")
T.errors(function()
	DataService.RegisterDomain("Bad", { Version = 1, Defaults = { Version = 1 } })
end, "réservé", "champ réservé refusé")
T.errors(function()
	DataService.RegisterDomain("Bad", { Version = 1, Defaults = { Broken = 0 / 0 } })
end, "non sauvegardables", "valeur de départ NaN refusée")
T.errors(function()
	DataService.RegisterDomain("Bad", { Version = 0, Defaults = {} })
end, "Version", "version 0 refusée")
-- domaine de test avec migration : Old (version 1) devient New (version 2)
DataService.RegisterDomain("ZTest", {
	Version = 2,
	Defaults = { ZNew = 0, ZList = {} },
	Migrate = function(data, from)
		if from < 2 then
			data.ZNew = (tonumber(data.ZOld) or 0) * 10
			data.ZOld = nil
		end
	end,
})

T.section("nouveau joueur")
local defaults = DataService.Defaults()
T.eq(#DataService.Problems(defaults), 0, "valeurs de départ sauvegardables")
local player = T.join({ UserId = 101 })
local data = T.data(player)
T.eq(data.Money, Core.StartingMoney, "argent de départ")
T.eq(data.Version, DataService.SchemaVersion, "version globale")
T.eq(data.Domains.Core, 1, "version du domaine Core")
T.eq(data.TankCount, 2, "2 cuves au départ")
T.eq(data.TreadmillLevel, 0, "tapis niveau 0")
T.check(type(data.Dinos) == "table" and next(data.Dinos) == nil, "aucun dino")
T.check(type(data.Purchases) == "table", "achats traités")
T.check(type(data.Index) == "table" and type(data.Index.Species) == "table", "index")
T.check(type(data.Daily) == "table" and type(data.Quests) == "table", "daily et quêtes")
local saved = env.saved("SAF_Players_1", key(101))
T.check(saved ~= nil and type(saved._Lock) == "table", "verrou posé au chargement")

T.section("autosave et départ")
data.Money = 1234
local writes = env.datastore.writes
T.advance(Core.Data.AutosaveInterval + 1)
T.check(env.datastore.writes > writes, "autosave écrit")
saved = env.saved("SAF_Players_1", key(101))
T.eq(saved.Money, 1234, "argent dans l'autosave")
T.check(type(saved._Lock) == "table", "verrou gardé pendant le jeu")
T.check(saved.PlayTime > 0, "temps de jeu compté (BeforeSave)")
data.Money = 0 / 0
data.Bad = function() end
T.leave(player)
saved = env.saved("SAF_Players_1", key(101))
T.eq(saved.Money, 0, "NaN remplacé par 0 à la sauvegarde")
T.eq(saved.Bad, nil, "fonction retirée de la sauvegarde")
T.eq(saved._Lock, nil, "verrou rendu au départ")
T.check(warned("réparée"), "warn sur les valeurs réparées")

T.section("retour du joueur")
env.datastore.set(STORE, key(101), (function()
	local value = env.saved("SAF_Players_1", key(101))
	value.Money = 50
	value.TankCount = "six" -- mauvais type
	value.ZOld = 7
	value.Domains.ZTest = 1
	return value
end)())
player = T.join({ UserId = 101 })
data = T.data(player)
T.eq(data.Money, 50, "argent rechargé")
T.eq(data.TankCount, 2, "mauvais type remplacé par la valeur de départ")
T.eq(data.ZNew, 70, "migration du domaine appliquée")
T.eq(data.ZOld, nil, "ancien champ retiré par la migration")
T.eq(data.Domains.ZTest, 2, "version du domaine à jour")

T.section("verrou volé")
local stolen = env.saved("SAF_Players_1", key(101))
stolen._Lock = { Job = "other", Session = "other-session", Time = env.os.time() }
env.datastore.set(STORE, key(101), stolen)
T.eq(DataService.Save(player), false, "sauvegarde refusée si un autre serveur a la main")
env.flush()
T.check(kickedWith(player, "another server"), "joueur expulsé")
T.eq(env.saved("SAF_Players_1", key(101))._Lock.Session, "other-session", "verrou de l'autre serveur intact")

T.section("sauvegarde ouverte ailleurs")
env.datastore.set(STORE, key(202), { Money = 5, _Lock = { Job = "other", Session = "x", Time = env.os.time() } })
local blocked = env.addPlayer({ UserId = 202 })
T.advance(30)
T.check(blocked:GetAttribute("Ready") ~= true, "pas chargé tant que le verrou est actif")
T.check(warned("encore ouverte"), "warn sur le verrou")
env.waitUntil(function()
	return blocked:GetAttribute("Ready") == true
end, "verrou expiré", 300)
T.eq(T.data(blocked).Money, 5, "chargé après expiration du verrou")
T.leave(blocked)

T.section("sauvegarde plus récente que le serveur")
env.datastore.set(STORE, key(303), { Version = 99, Money = 9 })
local outdated = env.addPlayer({ UserId = 303 })
env.flush()
T.advance(1)
T.check(kickedWith(outdated, "outdated"), "expulsé : serveur trop vieux")
T.eq(env.saved("SAF_Players_1", key(303)).Version, 99, "sauvegarde intacte")
env.datastore.set(STORE, key(304), { Version = 1, Domains = { Loop = 99 }, Money = 9 })
local outdatedDomain = env.addPlayer({ UserId = 304 })
T.advance(1)
T.check(kickedWith(outdatedDomain, "outdated"), "expulsé : domaine trop récent")
T.eq(env.saved("SAF_Players_1", key(304)).Money, 9, "sauvegarde du domaine intacte")

T.section("DataStore en panne")
env.datastore.set(STORE, key(404), { Money = 77 })
env.datastore.fail(1000)
local unlucky = env.addPlayer({ UserId = 404 })
T.advance(Core.Data.LoadAttempts * 3)
T.check(kickedWith(unlucky, "could not be loaded"), "expulsé quand le chargement échoue")
env.datastore.failures = 0
T.eq(env.saved("SAF_Players_1", key(404)).Money, 77, "sauvegarde jamais écrasée")

T.section("pannes passagères à la sauvegarde")
local flaky = T.join({ UserId = 505 })
T.data(flaky).Money = 10
env.datastore.fail(2)
T.eq(DataService.Save(flaky), true, "sauvegarde réussie au 3e essai")
T.eq(env.saved("SAF_Players_1", key(505)).Money, 10, "valeur écrite")
env.datastore.fail(3)
T.eq(DataService.Save(flaky), false, "sauvegarde ratée après 3 essais")
env.datastore.failures = 0

T.section("départ pendant le chargement")
env.datastore.latency = 3
local quick = env.addPlayer({ UserId = 606 })
env.removePlayer(quick)
T.advance(10)
env.datastore.latency = 0
T.eq(T.data(quick), nil, "pas de données pour un joueur parti")
local quickSave = env.saved("SAF_Players_1", key(606))
T.check(quickSave == nil or quickSave._Lock == nil, "aucun verrou laissé")

T.section("Studio")
env.studio = true
env.datastore.set(STORE, key(707), { Money = 88 })
writes = env.datastore.writes
local studioPlayer = T.join({ UserId = 707 })
T.eq(T.data(studioPlayer).Money, 88, "Studio lit la vraie sauvegarde")
T.data(studioPlayer).Money = 1
T.eq(DataService.Save(studioPlayer), true, "Save réussit en Studio")
T.leave(studioPlayer)
T.eq(env.datastore.writes, writes, "Studio n'écrit jamais")
T.eq(env.saved("SAF_Players_1", key(707)).Money, 88, "sauvegarde intacte")
env.datastore.disabled = true
local offline = T.join({ UserId = 808 })
T.eq(T.data(offline).Money, Core.StartingMoney, "Studio sans API : nouvelles données")
T.check(warned("Studio sans accès"), "warn Studio sans API")
T.leave(offline)
env.datastore.disabled = false
env.studio = false

T.section("arrêt du serveur")
local a = T.join({ UserId = 909 })
local b = T.join({ UserId = 910 })
T.data(a).Money = 1
T.data(b).Money = 2
env.close(30)
T.eq(env.saved("SAF_Players_1", key(909)).Money, 1, "joueur A sauvegardé à l'arrêt")
T.eq(env.saved("SAF_Players_1", key(910)).Money, 2, "joueur B sauvegardé à l'arrêt")
T.eq(env.saved("SAF_Players_1", key(910))._Lock, nil, "verrous rendus à l'arrêt")

-- (les warn attendus ci-dessus ne sont pas des erreurs ; les erreurs Boot de chargement raté le sont)
table.clear(Boot.Errors)
T.done("core_data")
