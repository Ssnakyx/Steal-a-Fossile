-- Boucle (brief 3) : une map déjà construite dans Workspace.Map (comme celle du brief 10) est lue par ses points
-- d'ancrage nommés au lieu d'être reconstruite. Parcs incomplets ignorés avec un warn, zone sans Area ignorée,
-- emplacements de blocs donnés par des Attachments Slot1..., gisements triés Site2 avant Site10, zones manquantes
-- complétées par la géométrie provisoire.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Instance, Vector3, CFrame = env.Instance, env.Vector3, env.CFrame
local Workspace = env.game:GetService("Workspace")
local CollectionService = env.game:GetService("CollectionService")

local function part(name: string, size: any, cframe: any, parent: any): any
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- ===== map faite à la main, avant le démarrage du serveur =====
local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = Workspace
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = map
for index = 1, 7 do
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local x = (index - 4) * 100
	part("Floor", Vector3.new(60, 1, 70), CFrame.new(x, 0.5, -500), model)
	if index ~= 5 then
		-- (le parc 5 n'a pas de Spawn : ignoré)
		part("Spawn", Vector3.new(6, 1, 6), CFrame.new(x, 1.5, -520), model)
	end
	part("Entrance", Vector3.new(16, 1, 4), CFrame.new(x, 1.1, -466), model)
	local enclosure = part("Enclosure", Vector3.new(56, 0.1, 24), CFrame.new(x, 1.05, -495), model)
	enclosure.Transparency = 1
	-- points d'ancrage rangés dans des sous-modèles : trouvés quand même
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor.Parent = model
	local treadmill = part("Treadmill", Vector3.new(6, 1, 12), CFrame.new(x + 20, 1, -510), decor)
	CollectionService:AddTag(treadmill, "Treadmill")
	local tanks = Instance.new("Folder")
	tanks.Name = "Tanks"
	tanks.Parent = model
	for k = 1, if index == 1 then 2 else 6 do
		part("Tank" .. k, Vector3.new(6, 7, 6), CFrame.new(x - 25 + k * 7, 4.5, -530), tanks)
	end
	model.Parent = plotsFolder
end
-- (pas de Plot8 du tout)

local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = map
local beach = Instance.new("Model")
beach.Name = "Beach"
part("Area", Vector3.new(300, 2, 300), CFrame.new(0, -1, 2000), beach)
local digSites = Instance.new("Folder")
digSites.Name = "DigSites"
digSites.Parent = beach
local site10 = part("Site10", Vector3.new(14, 0.4, 14), CFrame.new(60, 0.2, 1950), digSites)
local site2 = part("Site2", Vector3.new(14, 0.4, 14), CFrame.new(-60, 0.2, 1950), digSites)
local site1 = part("Site1", Vector3.new(20, 0.4, 20), CFrame.new(0, 0.2, 2050), digSites)
for k, offset in { { -6, 0 }, { 0, 0 }, { 6, 0 } } do
	local attachment = Instance.new("Attachment")
	attachment.Name = "Slot" .. k
	attachment.CFrame = CFrame.new(offset[1], 1.7, offset[2])
	attachment.Parent = site1
end
local notSlot = Instance.new("Attachment")
notSlot.Name = "Sparkles"
notSlot.Parent = site1
beach.Parent = zonesFolder
local broken = Instance.new("Model")
broken.Name = "Swamp"
part("Ground", Vector3.new(100, 2, 100), CFrame.new(0, -1, 3000), broken)
broken.Parent = zonesFolder

local Boot = T.bootServer()
local PlotService = Boot.Services.PlotService
local ZoneService = Boot.Services.ZoneService
local DigSiteService = Boot.Services.DigSiteService
local ReviveService = Boot.Services.ReviveService
local Zones = T.module("src/shared/Config/Zones")

local function warned(pattern: string): boolean
	for _, text in env.warnings do
		if string.find(text, pattern, 1, true) then
			return true
		end
	end
	return false
end

T.section("parcs")
T.eq(map:FindFirstChild("SpawnGround"), nil, "pas de sol provisoire sur une map faite à la main")
T.eq(#plotsFolder:GetChildren(), 7, "aucun parc ajouté")
T.eq(#PlotService.List(), 6, "6 parcs utilisables (5 incomplet, 8 absent)")
T.eq(PlotService.ByIndex(5), nil, "parc 5 ignoré")
T.check(warned("Plot5"), "warn pour le parc 5")
T.check(warned("Plot8"), "warn pour le parc 8")
local plot1 = PlotService.ByIndex(1)
T.eq(#plot1.Tanks, 2, "parc 1 : 2 cuves trouvées dans un sous-dossier")
T.eq(plot1.Treadmill and plot1.Treadmill.Parent.Name, "Decor", "treadmill trouvé dans un sous-modèle")
T.eq(plot1.Sign, nil, "pas de panneau : rien d'obligatoire")
T.eq(plot1.Lab, nil, "pas de labo")
T.eq(PlotService.PlotAt(plot1.Floor.Position + Vector3.new(0, 3, 0)), 1, "PlotAt sur le sol fait à la main")
T.eq(PlotService.PlotAt(Vector3.new(100, 3, -500)), nil, "le parc 5 n'est pas une zone sûre")

T.section("zones")
T.eq(#ZoneService.List(), 7, "7 zones (Swamp sans Area ignorée)")
T.eq(ZoneService.Get("Swamp"), nil, "Swamp ignorée")
T.check(warned("Area"), "warn pour la zone sans Area")
local geo = ZoneService.Get("Beach")
T.eq(geo.Model, beach, "Beach faite à la main gardée")
T.eq(geo.Arch, nil, "pas d'arche : rien d'obligatoire")
T.eq(geo.Guardian, nil, "pas de point Guardian")
T.eq(#geo.Sites, 3, "3 gisements")
T.eq(geo.Sites[1], site1, "Site1 en premier")
T.eq(geo.Sites[2], site2, "Site2 ensuite")
T.eq(geo.Sites[3], site10, "Site10 en dernier")
T.eq(ZoneService.ZoneAt(Vector3.new(100, 3, 2100)), "Beach", "ZoneAt sur l'Area faite à la main")
local fern = ZoneService.Get("Fern Forest")
T.check(fern ~= nil and fern.Model:FindFirstChild("Arch") ~= nil, "zone manquante complétée par la géométrie provisoire")
T.eq(fern.Index, 2, "ordre de la route gardé")
T.eq(ZoneService.List()[3].Name, "Canyon", "Canyon suit Fern Forest")

T.section("gisements")
local siteByAnchor = {}
for _, site in DigSiteService.Sites() do
	siteByAnchor[site.Anchor] = site
end
local s1 = siteByAnchor[site1]
T.eq(#s1.Slots, 3, "Site1 : 3 emplacements (Attachments Slot1..3)")
T.check((s1.Slots[1].CFrame.Position - Vector3.new(-6, 1.9, 2050)).Magnitude < 1e-6, "emplacement 1 à l'Attachment Slot1")
T.check((s1.Slots[3].CFrame.Position - Vector3.new(6, 1.9, 2050)).Magnitude < 1e-6, "emplacement 3 à l'Attachment Slot3")
T.eq(#siteByAnchor[site2].Slots, Zones.Dig.BlocksPerSite, "Site2 sans Attachment : emplacements par défaut")
for _, slot in s1.Slots do
	T.eq(slot.State, "Present", "Site1 rempli")
	T.check(slot.Part and (slot.Part.Position - slot.CFrame.Position).Magnitude < 1e-6, "bloc posé sur son emplacement")
end
T.eq(#siteByAnchor[ZoneService.Get("Canyon").Sites[1]].Slots, Zones.Dig.BlocksPerSite, "gisement provisoire rempli")

T.section("joueurs")
local players = {}
for k = 1, 7 do
	players[k] = T.join({ Name = "P" .. k })
end
local given = {}
for k = 1, 6 do
	local index = players[k]:GetAttribute("Plot")
	T.check(index ~= 5 and index ~= 8 and PlotService.ByIndex(index) ~= nil, "P" .. k .. " reçoit un parc utilisable (" .. tostring(index) .. ")")
	T.check(not given[index], "parc " .. tostring(index) .. " donné une seule fois")
	given[index] = true
end
T.eq(players[7]:GetAttribute("Plot"), 0, "7e joueur : plus de parc")
local p1 = players[1]
T.eq(p1:GetAttribute("Plot"), 1, "P1 : parc 1 (2 cuves)")
local data = T.data(p1)
data.Money = 1e6
T.eq(env.invokeServer(p1, "BuyTank"), true, "3e cuve achetée même sans pièce Tank3")
T.eq(data.TankCount, 3, "3 cuves")
T.check(ReviveService.AddBlock(p1, { Id = 1, Rarity = "Common", Zone = "Beach" }), "bloc dans une cuve")
T.check(ReviveService.AddBlock(p1, { Id = 2, Rarity = "Common", Zone = "Beach" }), "bloc dans une cuve")
T.check(ReviveService.AddBlock(p1, { Id = 3, Rarity = "Common", Zone = "Beach" }), "bloc dans la cuve sans pièce")
T.eq(data.Tanks["3"].Rarity, "Common", "cuve 3 occupée")
T.advance(31)
local ok = env.invokeServer(p1, "RevealTank", 3)
T.eq(ok, true, "révélation de la cuve sans pièce par le remote")
T.clean("map faite à la main sans erreur")

T.done("loop_map")
