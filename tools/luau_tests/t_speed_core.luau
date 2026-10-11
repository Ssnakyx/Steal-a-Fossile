-- SpeedService : courbe vitesse -> WalkSpeed, vitesse gagnée, bonus, effets temporaires, malus du bloc porté
-- (CarryService du brief 3, avec repli), récompense de groupe, commande d'admin, sauvegarde.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local SpeedConfig = Config.Speed
local Boot = T.bootServer()
local SpeedService = Boot.Services.SpeedService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")

T.section("courbe")
local walk = SpeedConfig.WalkSpeedFor
T.eq(walk(0), 16, "vitesse 0 = WalkSpeed de Roblox")
T.near(walk(1000), 26.41, 0.01, "1 K")
T.near(walk(25e6), 70, 0.05, "25 M (dernière zone)")
local previous = walk(0)
local rising = true
for _, speed in { 1, 10, 100, 1e3, 1e4, 5e4, 2e5, 1e6, 5e6, 25e6, 1e8, 1e10, 1e12, 1e15 } do
	local value = walk(speed)
	if value < previous then
		rising = false
	end
	previous = value
end
T.check(rising, "la courbe ne descend jamais")
T.eq(walk(1e15), SpeedConfig.WalkSpeed.Max, "plafond")
T.eq(walk(0 / 0), 16, "NaN")
T.eq(walk(-5), 16, "négatif")
T.eq(walk(math.huge), SpeedConfig.WalkSpeed.Max, "infini")

T.section("vitesse gagnée")
local player = T.join({ UserId = 101, Character = true })
local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
T.advance(0.5)
T.eq(humanoid.WalkSpeed, 16, "WalkSpeed de départ")
T.eq(SpeedService.Get(player), 0, "vitesse 0 au départ")
T.eq(ReplicaService.Get(player, "Speed"), 0, "Replica Speed")
T.eq(player.leaderstats.Speed.Value, "0", "leaderstats Speed")
local changes = {}
Signals.Connect("SpeedChanged", function(p, delta, reason, total)
	table.insert(changes, { p, delta, reason, total })
end)
T.check(SpeedService.Add(player, 1000, "Quest"), "Add 1000")
env.flush()
T.eq(SpeedService.Get(player), 1000, "vitesse ajoutée")
T.eq(T.data(player).Speed, 1000, "dans la sauvegarde")
T.eq(ReplicaService.Get(player, "Speed"), 1000, "Replica à jour")
T.eq(player.leaderstats.Speed.Value, "1K", "leaderstats à jour")
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "WalkSpeed suit tout de suite")
T.eq(#changes, 1, "signal SpeedChanged")
T.check(changes[1] and changes[1][2] == 1000 and changes[1][3] == "Quest" and changes[1][4] == 1000, "signal avec delta, raison, total")
for _, bad in { 0 / 0, math.huge, -math.huge, -1, 0 } do
	T.check(not SpeedService.Add(player, bad, "Bad"), "Add refusé : " .. tostring(bad))
end
T.check(not SpeedService.Add(player, "5" :: any, "Bad"), "Add refusé : texte")
T.eq(SpeedService.Get(player), 1000, "vitesse intacte après les refus")
SpeedService.Add(player, 1e300, "Huge")
T.eq(SpeedService.Get(player), SpeedConfig.Max, "plafond Config.Speed.Max")
SpeedService.Set(player, 1000)
T.eq(SpeedService.Get(player), 1000, "Set")

T.section("bonus")
SpeedService.SetBonus(player, "Trail", 9000)
T.eq(SpeedService.Get(player), 10000, "bonus ajouté")
T.eq(T.data(player).Speed, 1000, "bonus pas sauvegardé comme vitesse gagnée")
T.near(humanoid.WalkSpeed, walk(10000), 1e-6, "WalkSpeed avec le bonus")
SpeedService.SetBonus(player, "Trail", 0 / 0)
T.eq(SpeedService.Get(player), 1000, "bonus NaN = enlevé")
SpeedService.SetBonus(player, "Trail", -50)
T.eq(SpeedService.Get(player), 1000, "bonus négatif ramené à 0")
SpeedService.SetBonus(player, "Trail", nil)
T.eq(SpeedService.GetBonus(player, "Trail"), 0, "bonus enlevé")

T.section("multiplicateurs")
SpeedService.SetBonus(player, "Trail", 500)
SpeedService.SetMultiplier(player, "Trail", 2)
T.eq(SpeedService.Get(player), 3000, "(vitesse + bonus) x2")
T.eq(SpeedService.GetMultiplier(player, "Trail"), 2, "GetMultiplier")
T.eq(T.data(player).Speed, 1000, "multiplicateur pas sauvegardé comme vitesse gagnée")
T.near(humanoid.WalkSpeed, walk(3000), 1e-6, "WalkSpeed avec le multiplicateur")
SpeedService.SetMultiplier(player, "Event", 1.5)
T.eq(SpeedService.Get(player), 4500, "multiplicateurs multipliés")
SpeedService.SetMultiplier(player, "Event", 0 / 0)
T.eq(SpeedService.Get(player), 3000, "multiplicateur NaN = enlevé")
SpeedService.SetMultiplier(player, "Event", -3)
T.eq(SpeedService.Get(player), 0, "multiplicateur négatif ramené à 0")
SpeedService.SetMultiplier(player, "Event", 1e9)
T.eq(SpeedService.GetMultiplier(player, "Event"), 100, "multiplicateur plafonné à 100")
SpeedService.SetMultiplier(player, "Event", 1)
T.eq(SpeedService.GetMultiplier(player, "Event"), 1, "1 = enlevé")
SpeedService.SetMultiplier(player, "Trail", nil)
SpeedService.SetBonus(player, "Trail", nil)
T.eq(SpeedService.Get(player), 1000, "plus de multiplicateur")

T.section("effets temporaires")
SpeedService.SetModifier(player, "BearTrap", 0, 3)
T.eq(humanoid.WalkSpeed, 0, "immobilisé")
T.check(SpeedService.HasModifier(player, "BearTrap"), "HasModifier")
T.advance(2)
T.eq(humanoid.WalkSpeed, 0, "toujours immobilisé à 2 s")
T.advance(1.5)
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "libéré après 3 s")
T.check(not SpeedService.HasModifier(player, "BearTrap"), "effet fini")
SpeedService.SetModifier(player, "Slow", 0.5)
SpeedService.SetModifier(player, "Slow2", 0.5)
T.near(humanoid.WalkSpeed, walk(1000) * 0.25, 1e-6, "effets multipliés")
SpeedService.SetModifier(player, "Slow", nil)
SpeedService.SetModifier(player, "Slow2", nil)
SpeedService.SetModifier(player, "Weird", 0 / 0, 0 / 0)
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "effets enlevés, NaN ignoré")
humanoid.WalkSpeed = 500 -- (un autre script qui écrirait le WalkSpeed)
T.advance(0.3)
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "WalkSpeed remis par SpeedService")

T.section("bloc porté (CarryService du brief 3)")
local services = env.instance("ServerScriptService.Server.Services")
local carry = services:FindFirstChild("CarryService")
local fake: any = nil
if not carry then
	-- (brief 3 pas encore fusionné : faux CarryService, avec la même API)
	fake = {}
	carry = env.create("ModuleScript")
	carry.Name = "CarryService"
	env.Data[carry].Extra.Module = fake
	carry.Parent = services
end
local CarryService = env.require(carry)
local original = CarryService.GetSpeedMultiplier
CarryService.GetSpeedMultiplier = function(p)
	return if p == player then 0.6 else 1
end
Signals.Fire("CarryChanged", player, {})
env.flush()
T.near(humanoid.WalkSpeed, walk(1000) * 0.6, 1e-6, "signal CarryChanged : malus appliqué tout de suite")
T.advance(0.3)
T.near(humanoid.WalkSpeed, walk(1000) * 0.6, 1e-6, "malus du bloc appliqué")
SpeedService.SetModifier(player, "Slow", 0.5)
T.near(humanoid.WalkSpeed, walk(1000) * 0.3, 1e-6, "malus du bloc et effet ensemble")
SpeedService.SetModifier(player, "Slow", nil)
CarryService.GetSpeedMultiplier = function()
	return 0 / 0
end
T.advance(0.3)
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "multiplicateur NaN ignoré")
CarryService.GetSpeedMultiplier = function()
	error("boom")
end
T.advance(0.3)
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "CarryService en erreur ignoré")
CarryService.GetSpeedMultiplier = original
Signals.Fire("CarryChanged", "not a player")
Signals.Fire("CarryChanged", nil)
env.flush()
if fake then
	carry:Destroy()
end
T.advance(0.3)
T.near(humanoid.WalkSpeed, walk(1000), 1e-6, "sans bloc")
T.clean("aucune erreur avec CarryService")

T.section("personnage")
player:LoadCharacter()
local newHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
env.flush()
T.near(newHumanoid.WalkSpeed, walk(1000), 1e-6, "nouveau personnage à la bonne vitesse")
local noCharacter = T.join({ UserId = 102 })
SpeedService.Add(noCharacter, 50, "Test")
T.advance(0.5)
T.eq(SpeedService.Get(noCharacter), 50, "joueur sans personnage : vitesse comptée")
T.clean("aucune erreur sans personnage")

T.section("récompense de groupe")
local ok, text = env.invokeServer(player, "ClaimGroupReward")
T.check(not ok and text == "Coming soon!", "cachée tant que GroupId = 0")
SpeedConfig.GroupReward.GroupId = 777
ok, text = env.invokeServer(player, "ClaimGroupReward")
T.check(not ok and text == "Join the group first!", "pas dans le groupe")
T.eq(SpeedService.Get(player), 1000, "rien donné")
env.groupRanks[777] = { [101] = 1 }
RateLimit.Reset(player)
ok, text = env.invokeServer(player, "ClaimGroupReward")
T.check(ok, "récompense prise (" .. tostring(text) .. ")")
T.eq(SpeedService.Get(player), 1000 + SpeedConfig.GroupReward.Speed, "vitesse donnée")
T.eq(T.data(player).GroupRewardClaimed, true, "notée dans la sauvegarde")
env.flush()
T.eq(ReplicaService.Get(player, "GroupRewardClaimed"), true, "Replica GroupRewardClaimed")
RateLimit.Reset(player)
ok, text = env.invokeServer(player, "ClaimGroupReward")
T.check(not ok and text == "Already claimed", "une seule fois")
T.eq(SpeedService.Get(player), 1000 + SpeedConfig.GroupReward.Speed, "pas donnée deux fois")
-- deux demandes pendant que Roblox répond lentement
local slowPlayer = T.join({ UserId = 103 })
env.groupRanks[777][103] = 1
local realIsInGroup = env.game:GetService("Players"):GetPlayerByUserId(103).IsInGroupAsync
env.stubMethod("Player", "IsInGroupAsync", function(self, groupId)
	env.task.wait(2)
	return realIsInGroup(self, groupId)
end)
local results = {}
for _ = 1, 2 do
	env.task.spawn(function()
		table.insert(results, { env.invokeServer(slowPlayer, "ClaimGroupReward") })
	end)
end
T.advance(5)
env.stubMethod("Player", "IsInGroupAsync", realIsInGroup)
local granted = 0
for _, result in results do
	if result[1] == true then
		granted += 1
	end
end
T.eq(granted, 1, "deux demandes en même temps : une seule donnée")
T.eq(SpeedService.Get(slowPlayer), SpeedConfig.GroupReward.Speed, "vitesse donnée une fois")
env.stubMethod("Player", "IsInGroupAsync", function()
	error("HTTP 500")
end)
local failing = T.join({ UserId = 104 })
ok, text = env.invokeServer(failing, "ClaimGroupReward")
T.check(not ok and text == "Roblox did not answer, try again", "Roblox ne répond pas")
T.eq(T.data(failing).GroupRewardClaimed, false, "pas notée si Roblox ne répond pas")
env.stubMethod("Player", "IsInGroupAsync", realIsInGroup)
SpeedConfig.GroupReward.GroupId = 0

T.section("admin")
local admin = T.join({ UserId = 3346721423 })
T.check(not AdminService.Run(player, "speed", { "500" }), "commande refusée à un joueur normal")
ok, text = AdminService.Run(admin, "speed", { "500", "Player1" })
T.check(ok, "speed 500 (" .. tostring(text) .. ")")
T.eq(T.data(player).Speed, 2500, "vitesse ajoutée par l'admin")
ok = AdminService.Run(admin, "speed", { "=10", "Player1" })
T.check(ok, "speed =10")
T.eq(T.data(player).Speed, 10, "vitesse fixée")
for _, bad in { "abc", "-1", "nan", "inf", "1e16", "=-1" } do
	T.check(not AdminService.Run(admin, "speed", { bad, "Player1" }), "speed " .. bad .. " refusé")
end
T.eq(T.data(player).Speed, 10, "intacte après les refus")

T.section("sauvegarde")
SpeedService.Add(player, 990, "Test")
T.leave(player)
T.eq(env.saved("SAF_Players_1", "Player_101").Speed, 1000, "vitesse écrite au départ")
local back = T.join({ UserId = 101, Character = true })
T.eq(SpeedService.Get(back), 1000, "vitesse rechargée")
T.eq(T.data(back).GroupRewardClaimed, true, "récompense rechargée")
local SpeedData = T.module("src/server/Data/Speed")
local broken: any = {
	Speed = 0 / 0,
	TreadmillLevel = 99,
	Trails = { Owned = { Dust = true, Nope = true, [5] = true }, Equipped = "Nope" },
	GroupRewardClaimed = false,
	Passes = { VIP = true, Bad = 3 },
}
SpeedData.Sanitize(broken)
T.eq(broken.Speed, 0, "Sanitize : vitesse NaN")
T.eq(broken.TreadmillLevel, 50, "Sanitize : niveau borné au dernier (50)")
T.check(broken.Trails.Owned.Dust and not broken.Trails.Owned.Nope, "Sanitize : trail inconnue retirée")
T.eq(broken.Trails.Equipped, "", "Sanitize : trail portée inconnue retirée")
T.check(broken.Passes.VIP and broken.Passes.Bad == nil, "Sanitize : passes")

T.done("speed_core")
