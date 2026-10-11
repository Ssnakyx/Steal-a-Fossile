-- Aperçu de l'interface du brief 12, avec le vrai serveur : HUD (boutons, compteurs, cuves), bandeau de zone, transport
-- d'un bloc poursuivi par le gardien, shop (4 onglets), Index (zone et hybrides), labo de fusion, écran de révélation.
-- Le monde 3D n'est pas dessiné (les portraits 3D sont des cases « 3D »). python3 tools/luau_tests/ui_preview.py ui_hud [--phone]
local P = require("./previewkit")
local T = require("./testkit")
local env = P.env

env.quiet = true
env.touch = P.Phone
env.setViewport(P.Width, P.Height)
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local DigSiteService = Boot.Services.DigSiteService
local EnclosureService = Boot.Services.EnclosureService
local FusionService = Boot.Services.FusionService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local ReplicaService = Boot.Services.ReplicaService
local ReviveService = Boot.Services.ReviveService
local SpeedService = Boot.Services.SpeedService
local Zones = T.config().Zones
local Vector3, CFrame = env.Vector3, env.CFrame

local player = env.addPlayer({ Local = true, Name = "Snaky", DisplayName = "Snaky", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
-- joueur qui a déjà joué un peu : tutoriel fini, argent, vitesse, quelques dinos
local data = T.data(player)
data.Tutorial = 3
ReplicaService.Set(player, "Tutorial", 3)
Boot.Services.DailyService.Claim(player) -- (pas de calendrier ouvert tout seul)
MoneyService.Add(player, 12_450, "Preview")
SpeedService.Add(player, 1_800, "Preview")
for _, dino in {
	{ Species = "Compy", Size = "Big" },
	{ Species = "Compy" },
	{ Species = "Compy", Mutation = "Amber" },
	{ Species = "Pteranodon", Size = "Huge" },
	{ Species = "Stegosaurus", Mutation = "Crystal" },
	{ Species = "Velociraptor" },
} do
	EnclosureService.AddDino(player, dino)
end
ReviveService.AddBlock(player, { Rarity = "Rare", Zone = "Fern Forest" })
ReviveService.AddBlock(player, { Rarity = "Epic", Zone = "Swamp" })
env.flush()

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
P.settle(3)
P.page("ui_hud")

-- une cuve prête
data.Tanks["1"].EndsAt = os.time() - 1
ReviveService.FinishAll(player)
P.settle(1)
P.page("ui_hud_tank_ready")

-- entrée dans une zone trop rapide pour le joueur
player:SetAttribute("Zone", "Swamp")
P.settle(0.6)
P.page("ui_zone_banner")

-- bloc sur le dos, gardien qui poursuit
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
player:SetAttribute("ChasedBy", "Beach")
P.settle(1)
P.page("ui_carry_chased")
player:SetAttribute("ChasedBy", "")
local plot = PlotService.Get(player)
player.Character:PivotTo(CFrame.new(plot.Entrance.Position + Vector3.new(0, 3, -2)))
player:SetAttribute("Zone", "")
P.settle(3.5) -- (le temps que les messages courts partent)

-- shop
C.ShopController.Open("Speed")
P.settle(1)
P.page("ui_shop_speed")
C.ShopController.Select("Trails")
P.settle(0.5)
P.page("ui_shop_trails")
C.ShopController.Select("Passes")
P.settle(0.5)
P.page("ui_shop_passes")
C.ShopController.Select("Items")
P.settle(0.5)
P.page("ui_shop_items")
C.ShopController.Close()
P.settle(0.5)

-- Index
C.IndexController.Open("Beach")
P.settle(1)
P.page("ui_index_beach")
FusionService.Discover(player, "Ptero-Rex")
FusionService.Publish(player)
C.IndexController.Open("Hybrids")
P.settle(1)
P.page("ui_index_hybrids")
C.IndexController.Close()
P.settle(0.5)

-- labo de fusion : 3 Compy choisis
C.LabController.Open()
P.settle(0.5)
local ids = {}
for id, dino in data.Dinos do
	if dino.Species == "Compy" then
		table.insert(ids, id)
	end
end
table.sort(ids)
C.LabController.Select(ids)
P.settle(1)
P.page("ui_lab")
C.LabController.Close()
P.settle(0.5)

-- révélation d'un dino
C.RevealController.Show({ Species = "Triceratops", Size = "Big", Mutation = "Lava", Level = 0, Rarity = "Legendary", Income = 1350 }, "Tank")
P.settle(1)
P.page("ui_reveal")
