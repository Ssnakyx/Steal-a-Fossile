-- AFK sur le treadmill : gain gratuit sans achat (et un seul rappel d'achat), reconnexion AFK (AfkService) : refus hors
-- du tapis, sauvegarde puis téléportation vers ce serveur, deuxième essai vers un autre serveur, recharge, Studio,
-- arrivée d'une reconnexion reposée sur son tapis.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local SpeedConfig = Config.Speed
local AFK = SpeedConfig.Treadmill.Afk
local teleportData: { [any]: any } = {}
local joinData: { [number]: any } = {}
env.stubMethod("TeleportOptions", "SetTeleportData", function(self, data)
	teleportData[self] = data
end)
env.stubMethod("Player", "GetJoinData", function(self)
	return joinData[self.UserId] or {}
end)
local Boot = T.bootServer()
local AfkService = Boot.Services.AfkService
local TreadmillService = Boot.Services.TreadmillService
local SpeedService = Boot.Services.SpeedService
local PlotService = Boot.Services.PlotService
local Signals = T.lib("Signals")
local Enum = env.Enum
local CFrame = env.CFrame
local Vector3 = env.Vector3
local teleportService = env.game:GetService("TeleportService")

type Sent = { Players: { any }, Options: any }
local sent: { Sent } = {}
local failNext = 0
AfkService.Teleport = function(players, options)
	table.insert(sent, { Players = players, Options = options })
	if failNext > 0 then
		failNext -= 1
		error("Teleport failed (simulated)")
	end
end
local rejoins = 0
Signals.Connect("AfkRejoin", function()
	rejoins += 1
end)

local function notified(player: any, pattern: string): number
	local count = 0
	for _, args in env.received(player, "Notify") do
		if type(args[1]) == "string" and string.find(args[1], pattern, 1, true) then
			count += 1
		end
	end
	return count
end

local function beltOf(player: any): any
	local plot = PlotService.Get(player)
	return plot and plot.Treadmill
end

local function putOnBelt(player: any)
	local belt = beltOf(player)
	player.Character.HumanoidRootPart.CFrame = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, 0)
	TreadmillService.Tick()
end

T.section("treadmill gratuit")
local player = T.join({ UserId = 601, Character = true })
env.flush()
T.check(beltOf(player) ~= nil, "tapis dans le parc du joueur")
T.eq(T.data(player).TreadmillLevel, 0, "treadmill pas acheté")
local free = SpeedConfig.Treadmill.BaseGain * SpeedConfig.Treadmill.FreeMultiplier
T.check(free > 0, "gain gratuit configuré")
T.eq(TreadmillService.Rate(player), free, "gain gratuit au niveau 0")
local speed = SpeedService.Get(player)
putOnBelt(player)
T.check(TreadmillService.IsOnTreadmill(player), "sur son tapis")
T.eq(SpeedService.Get(player) - speed, free, "vitesse gagnée sans achat")
T.eq(notified(player, "Buy the Treadmill"), 1, "rappel d'achat")
T.advance(5)
T.check(SpeedService.Get(player) - speed >= free * 5, "gain chaque seconde sans bouger (AFK)")
T.eq(notified(player, "Buy the Treadmill"), 1, "rappel d'achat une seule fois (pas de spam pendant l'AFK)")

T.section("reconnexion refusée hors du tapis")
player.Character.HumanoidRootPart.CFrame = CFrame.new(beltOf(player).Position + Vector3.new(0, 3, 40))
TreadmillService.Tick()
T.check(not TreadmillService.IsOnTreadmill(player), "descendu du tapis")
local ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "Not on your treadmill", "refusé hors du tapis")
T.eq(#sent, 0, "aucune téléportation")

T.section("reconnexion vers ce serveur")
T.advance(AFK.RejoinCooldown + 1)
putOnBelt(player)
local saves = env.datastore.writes
ok, text = AfkService.Rejoin(player)
T.check(ok, "reconnexion lancée (" .. tostring(text) .. ")")
T.check(env.datastore.writes > saves, "sauvegarde écrite avant de partir")
T.eq(#sent, 1, "une téléportation")
T.check(sent[1].Players[1] == player and #sent[1].Players == 1, "le joueur seulement")
T.eq(sent[1].Options.ServerInstanceId, env.game.JobId, "vers ce même serveur")
local data = teleportData[sent[1].Options]
T.check(type(data) == "table" and data.AfkTreadmill == true, "donnée de téléportation AfkTreadmill")
T.eq(rejoins, 1, "signal AfkRejoin")
T.eq(notified(player, "Reconnecting"), 1, "joueur prévenu")
T.check(AfkService.IsTeleporting(player), "en cours de reconnexion")
ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "Already reconnecting", "pas deux reconnexions à la fois")

T.section("serveur qui refuse : un autre serveur, puis abandon")
env.fire(env.signal(teleportService, "TeleportInitFailed"), player, Enum.TeleportResult.GameFull, "Game is full", 0, sent[1].Options)
T.eq(#sent, 2, "deuxième essai")
T.eq(sent[2].Options.ServerInstanceId, "", "vers n'importe quel serveur")
T.check(AfkService.IsTeleporting(player), "toujours en cours")
env.fire(env.signal(teleportService, "TeleportInitFailed"), player, Enum.TeleportResult.Failure, "Failed", 0, sent[2].Options)
T.eq(#sent, 2, "pas de troisième essai")
T.check(not AfkService.IsTeleporting(player), "abandon")
T.eq(notified(player, "Could not reconnect"), 1, "joueur prévenu de l'échec")
ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "Slow down!", "recharge entre deux demandes")

T.section("erreur immédiate : un autre serveur")
T.advance(AFK.RejoinCooldown + 1)
putOnBelt(player)
failNext = 1
ok = AfkService.Rejoin(player)
T.check(ok, "reconnexion lancée après une erreur")
T.eq(#sent, 4, "deux envois")
T.eq(sent[3].Options.ServerInstanceId, env.game.JobId, "d'abord ce serveur")
T.eq(sent[4].Options.ServerInstanceId, "", "puis un autre")
env.fire(env.signal(teleportService, "TeleportInitFailed"), player, Enum.TeleportResult.Failure, "Failed", 0, sent[4].Options)
T.check(not AfkService.IsTeleporting(player), "abandon (deuxième essai déjà fait)")
T.eq(#sent, 4, "pas de nouvel envoi")
T.advance(AFK.RejoinCooldown + 1)
putOnBelt(player)
failNext = 2
ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "Could not reconnect", "les deux envois ratés")
T.check(not AfkService.IsTeleporting(player), "rien en cours")
T.clean("erreurs de téléportation attrapées")

T.section("Studio et réglage")
T.advance(AFK.RejoinCooldown + 1)
putOnBelt(player)
env.studio = true
local count = #sent
ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "Studio", "pas de téléportation dans Studio")
T.eq(notified(player, "only works in the live game"), 1, "joueur prévenu (Studio)")
env.studio = false
AFK.Rejoin = false
T.advance(AFK.RejoinCooldown + 1)
ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "AFK reconnect is off", "réglage coupé")
AFK.Rejoin = true
T.eq(#sent, count, "aucune téléportation")

T.section("remote AfkRejoin")
T.advance(AFK.RejoinCooldown + 1)
putOnBelt(player)
env.fireServer(player, "AfkRejoin")
env.flush()
T.eq(#sent, count + 1, "le remote lance la reconnexion")
for _, value in T.hostileValues() do
	env.fireServer(player, "AfkRejoin", value, value)
end
env.flush()
T.eq(#sent, count + 1, "spam sans effet")
T.clean("aucune erreur avec le remote")

T.section("arrivée d'une reconnexion AFK")
joinData[602] = { TeleportData = { AfkTreadmill = true } }
local back = T.join({ UserId = 602, Character = true })
T.advance(1.5)
T.eq(back:GetAttribute(AFK.Attribute), true, "attribut AfkReturn")
local belt = beltOf(back)
local root = back.Character.HumanoidRootPart
T.check((root.Position - belt.Position).Magnitude < belt.Size.Y / 2 + 4, "reposé sur son tapis")
TreadmillService.Tick()
T.check(TreadmillService.IsOnTreadmill(back), "compte comme sur son tapis")
T.eq(notified(back, "Welcome back"), 1, "joueur prévenu")
joinData[603] = { TeleportData = { AfkTreadmill = "yes" } }
local other = T.join({ UserId = 603, Character = true })
T.advance(1.5)
T.eq(other:GetAttribute(AFK.Attribute), nil, "donnée de téléportation invalide ignorée")
T.check(not TreadmillService.IsOnTreadmill(other), "pas déplacé")
local normal = T.join({ UserId = 604, Character = true })
T.advance(1.5)
T.eq(normal:GetAttribute(AFK.Attribute), nil, "arrivée normale : rien")
T.clean("aucune erreur à l'arrivée")

T.done("daily_afk")
