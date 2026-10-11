-- Côté client du vol (brief 7) : PvpController. La pelle en main envoie Bonk (le serveur décide), le piège envoie
-- PlaceTrap, la chute (Knocked) fait tomber puis relever le personnage, le prompt d'un bloc qu'on vient de lâcher est
-- caché 3 s. Messages abîmés du serveur sans erreur.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local CarryService = Boot.Services.CarryService
local DigSiteService = Boot.Services.DigSiteService
local DroppedBlockService = Boot.Services.DroppedBlockService
local PvpService = Boot.Services.PvpService
local ZoneService = Boot.Services.ZoneService
local Pvp = T.module("src/shared/Config/Pvp")
local Zones = T.module("src/shared/Config/Zones")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local Vector3, CFrame = env.Vector3, env.CFrame

local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return me:GetAttribute("Ready") == true
end, "joueur prêt", 60)
local thief = T.join({ Name = "Thief", Character = true })
env.flush()

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local PvpController = ClientBoot.Controllers.PvpController
T.check(PvpController ~= nil, "PvpController chargé")
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

local beach = ZoneService.Get("Beach").Area
local road = beach.Position + Vector3.new(60, beach.Size.Y / 2 + 3, -40)
PvpService.SetProtection(me, false)
PvpService.SetProtection(thief, false)

local bonked = {}
Signals.Connect("Bonked", function(attacker, victim)
	table.insert(bonked, { attacker, victim })
end)

T.section("pelle")
-- Thief porte un bloc à 4 studs
for _, site in DigSiteService.Sites() do
	for _, slot in site.Slots do
		if site.Zone == "Beach" and slot.State == "Present" and not CarryService.IsCarrying(thief) then
			-- (comme un arrachage : la place passe « dehors »)
			CarryService.Carry(thief, slot.Block)
			slot.State = "Out"
			slot.Part:Destroy()
			slot.Part = nil
		end
	end
end
T.check(CarryService.IsCarrying(thief), "Thief porte un bloc")
thief.Character:PivotTo(CFrame.new(road))
me.Character:PivotTo(CFrame.new(road + Vector3.new(4, 0, 0)))
T.eq(PvpController.BonkTarget(), thief, "cible proposée : le porteur à portée")
thief.Character:PivotTo(CFrame.new(road + Vector3.new(0, 0, 40)))
T.eq(PvpController.BonkTarget(), nil, "trop loin : aucune")
thief.Character:PivotTo(CFrame.new(road))
local shovel = me.Backpack:FindFirstChild(Pvp.Shovel.ToolName)
shovel.Parent = me.Character
env.flush()
env.setSide("client", me)
env.fire(env.signal(shovel, "Activated"))
env.setSide("server")
env.flush()
T.eq(#bonked, 1, "clic avec la pelle : Bonk envoyé, le serveur a frappé")
T.check(bonked[1] and bonked[1][1] == me and bonked[1][2] == thief, "Me bonke Thief")
T.check(not CarryService.IsCarrying(thief), "Thief a lâché le bloc")

T.section("piège")
PvpService.GiveTraps(me, 2)
env.flush()
local trapTool = me.Backpack:FindFirstChild(Pvp.Trap.ToolName)
T.check(trapTool ~= nil, "outil Bear Trap")
trapTool.Parent = me.Character
env.flush()
me.Character:PivotTo(CFrame.new(road + Vector3.new(30, 0, 0)))
env.setSide("client", me)
env.fire(env.signal(trapTool, "Activated"))
env.setSide("server")
env.flush()
T.eq(#PvpService.Traps(), 1, "clic avec le piège : PlaceTrap envoyé, piège posé")

T.section("chute")
local humanoid = me.Character:FindFirstChildOfClass("Humanoid")
PvpService.Knock(me, 1.5, "Bonk")
env.flush()
T.eq(humanoid.PlatformStand, true, "le personnage tombe")
env.advance(1.6)
T.eq(humanoid.PlatformStand, false, "puis se relève")
PvpService.Knock(me, 3, "Trap")
env.flush()
T.eq(humanoid.PlatformStand, false, "un piège bloque sans faire tomber")
local remote = env.game:GetService("ReplicatedStorage").Remotes.Knocked
for _, value in T.hostileValues() do
	env.fire(env.signal(remote, "OnClientEvent"), value, value)
end
env.fire(env.signal(remote, "OnClientEvent"), 1e9, "Bonk")
env.flush()
T.eq(humanoid.PlatformStand, true, "durée énorme : bornée")
env.advance(10.5)
T.eq(humanoid.PlatformStand, false, "relevé au bout de 10 s au plus")
T.eq(#ClientBoot.Errors, 0, "messages abîmés sans erreur")

T.section("bloc qu'on vient de lâcher")
local mine = DroppedBlockService.Place({ Id = 800001, Rarity = "Rare", Zone = "Beach" }, road - Vector3.new(0, 3, 0), me, "Test")
env.flush()
T.eq(mine.Part.PickUpPrompt.Enabled, false, "prompt caché pour celui qui l'a lâché")
local theirs = DroppedBlockService.Place({ Id = 800002, Rarity = "Rare", Zone = "Beach" }, road + Vector3.new(10, -3, 0), thief, "Test")
env.flush()
T.eq(theirs.Part.PickUpPrompt.Enabled, true, "prompt visible pour les autres")
env.advance(Pvp.Dropped.LockTime + 0.1)
T.eq(mine.Part.PickUpPrompt.Enabled, true, "prompt visible après 3 s")
DroppedBlockService.ReturnAll()
RateLimit.Reset(me)
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.check(Zones.Dig.GrabTime > 0, "config lue")

T.done("pvp_client")
