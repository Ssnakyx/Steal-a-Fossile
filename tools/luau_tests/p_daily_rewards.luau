-- Aperçu des récompenses et du guide des premières minutes, avec le vrai serveur : arrivée d'un nouveau joueur (guide
-- « GRAB A FOSSIL », boutons Daily / Spin / Gifts), cuve qui tourne, calendrier, roue, cadeaux, carte AFK du treadmill
-- sous le guide. Le monde 3D n'est pas dessiné. python3 tools/luau_tests/ui_preview.py daily [--phone]
local P = require("./previewkit")
local T = require("./testkit")
local env = P.env

env.quiet = true
env.touch = P.Phone
env.setViewport(P.Width, P.Height)
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local DigSiteService = Boot.Services.DigSiteService
local PlotService = Boot.Services.PlotService
local TreadmillService = Boot.Services.TreadmillService
local Zones = T.config().Zones
local Vector3, CFrame = env.Vector3, env.CFrame

local player = env.addPlayer({ Local = true, Name = "Snaky", DisplayName = "Snaky", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local Rewards = ClientBoot.Controllers.RewardsController
P.settle(1)
P.page("daily_guide_grab")

-- bloc arraché puis rapporté : la cuve tourne
local target = nil
for _, site in DigSiteService.Sites() do
	for _, slot in site.Slots do
		if site.Zone == Zones.Dig.TutorialZone and slot.State == "Present" and not target then
			target = slot
		end
	end
end
local part = target.Part
player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(3, 1, 3)))
env.advance(0.3)
env.fire(env.signal(part.GrabPrompt, "PromptButtonHoldBegan"), player)
env.advance(Zones.Dig.GrabTime)
env.fire(env.signal(part.GrabPrompt, "Triggered"), player)
P.settle(0.5)
P.page("daily_guide_home")
local plot = PlotService.Get(player)
env.advance(20)
player.Character:PivotTo(CFrame.new(plot.Entrance.Position + Vector3.new(0, 3, -2)))
P.settle(1)
P.page("daily_guide_revive")

Rewards.Open("Daily")
P.settle(1)
P.page("daily_calendar")
Rewards.Open("Spin")
P.settle(1)
P.page("daily_spin")
Rewards.Open("Gifts")
P.settle(1)
P.page("daily_gifts")
Rewards.Close()

-- premier dino, puis l'étape treadmill sur le tapis (carte AFK en dessous)
env.advance(Zones.Dig.TutorialReviveTime)
env.fire(env.signal(plot.Tanks[1].TankPrompt, "Triggered"), player)
env.advance(4)
Rewards.Close()
env.advance(4)
player.Character:PivotTo(plot.Treadmill.CFrame * CFrame.new(0, plot.Treadmill.Size.Y / 2 + 3, 0))
TreadmillService.Tick()
P.settle(1.5)
P.page("daily_treadmill")
