--!strict
-- Zones de la route (brief 3 « boucle ») : données de Config.Zones et géométrie Workspace.Map.Zones.<Nom de la zone>
-- avec ses points d'ancrage nommés (Area, Arch, DigSites/Site1..., Guardian ; docs/BOUCLE.md). Une zone absente au
-- démarrage reçoit une géométrie provisoire (la vraie map est faite par le brief 10, avec les mêmes noms).
-- La route part du spawn vers +Z : zone 1 (Beach) la plus proche, zone 8 (Meteor Crater) la plus loin.
-- Attribut joueur « Zone » : nom de la zone où il se trouve ("" au spawn ou dans un parc), mis à jour 4 fois par seconde.
-- Signaux : ZoneChanged(player, zone, previous)  (noms de zones, "" hors route)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Format)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local PlotService = require(script.Parent.PlotService)

export type ZoneGeo = {
	Name: string,
	Index: number,
	Model: Model,
	Area: BasePart, -- étendue de la zone (boîte prolongée vers le haut)
	Arch: BasePart?, -- arche d'entrée (nom et vitesse conseillée)
	Sites: { BasePart }, -- gisements (DigSiteService), triés par nom
	Guardian: BasePart?, -- point d'ancrage du gardien (brief 7)
}

local ZoneService = {}
ZoneService.Priority = -20

-- Géométrie provisoire : la route commence à Z = RouteStart (bord du spawn), chaque zone fait Length studs
ZoneService.RouteStart = 60
ZoneService.Length = 240
ZoneService.Width = 200

local AREA_BELOW = 20
local AREA_ABOVE = 300
local UPDATE_INTERVAL = 0.25

local geos: { ZoneGeo } = {}
local byName: { [string]: ZoneGeo } = {}
local current: { [Player]: string } = {}

-- ===================================================================== géométrie provisoire

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decor(part: Part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function speedText(speed: number): string
	return if speed <= 0 then "No speed needed" else "Recommended speed: " .. Format.Number(speed)
end

local function archLabel(part: BasePart, zone: Zones.Zone)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(30, 7)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.MaxDistance = 400
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.62)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.Text = string.upper(zone.Name)
	title.Parent = gui
	local speed = Instance.new("TextLabel")
	speed.Name = "Speed"
	speed.BackgroundTransparency = 1
	speed.Position = UDim2.fromScale(0, 0.62)
	speed.Size = UDim2.fromScale(1, 0.38)
	speed.Font = Enum.Font.GothamBold
	speed.TextScaled = true
	speed.TextColor3 = Color3.fromRGB(255, 230, 120)
	speed.TextStrokeTransparency = 0.3
	speed.Text = speedText(zone.Speed)
	speed.Parent = gui
	gui.Parent = part
end

local function buildZone(zone: Zones.Zone, parent: Instance): Model
	local gt = PlotService.GroundTop
	local length, width = ZoneService.Length, ZoneService.Width
	local zStart = ZoneService.RouteStart + (zone.Index - 1) * length
	local model = Instance.new("Model")
	model.Name = zone.Name
	local area = newPart("Area", Vector3.new(width, 2, length), CFrame.new(0, gt - 1, zStart + length / 2), zone.Color, model)
	model.PrimaryPart = area
	local stone = Color3.fromRGB(125, 115, 105)
	newPart("ArchPillarLeft", Vector3.new(4, 20, 4), CFrame.new(-24, gt + 10, zStart + 4), stone, model)
	newPart("ArchPillarRight", Vector3.new(4, 20, 4), CFrame.new(24, gt + 10, zStart + 4), stone, model)
	local arch = newPart("Arch", Vector3.new(52, 3, 4), CFrame.new(0, gt + 21.5, zStart + 4), stone, model)
	archLabel(arch, zone)
	local sites = Instance.new("Folder")
	sites.Name = "DigSites"
	sites.Parent = model
	local spots = { { -55, 0.35 }, { 50, 0.55 }, { -15, 0.8 }, { 60, 0.85 }, { -70, 0.65 }, { 20, 0.3 } }
	for k = 1, math.min(Zones.Dig.Sites, #spots) do
		local spot = spots[k]
		local site = newPart("Site" .. k, Vector3.new(14, 0.4, 14), CFrame.new(spot[1], gt + 0.2, zStart + spot[2] * length), Color3.fromRGB(110, 80, 55), sites)
		site.Material = Enum.Material.Ground
		site.TopSurface = Enum.SurfaceType.Smooth
		decor(site)
	end
	local guardian = newPart("Guardian", Vector3.new(6, 0.4, 6), CFrame.new(0, gt + 0.2, zStart + 0.6 * length), Color3.new(0, 0, 0), model)
	guardian.Transparency = 1
	decor(guardian)
	model.Parent = parent
	return model
end

-- ===================================================================== lecture des points d'ancrage

local function readZone(zone: Zones.Zone, model: Model): ZoneGeo?
	local area = model:FindFirstChild("Area", true)
	if not (area and area:IsA("BasePart")) then
		warn(string.format("[ZoneService] %s : il manque la pièce Area (zone ignorée)", model:GetFullName()))
		return nil
	end
	local sites: { BasePart } = {}
	local folder = model:FindFirstChild("DigSites", true)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(sites, child)
			end
		end
	end
	table.sort(sites, function(a, b)
		-- Site2 avant Site10
		local na, nb = tonumber(string.match(a.Name, "%d+$")), tonumber(string.match(b.Name, "%d+$"))
		if na and nb and na ~= nb then
			return na < nb
		end
		return a.Name < b.Name
	end)
	local arch = model:FindFirstChild("Arch", true)
	local guardian = model:FindFirstChild("Guardian", true)
	model:SetAttribute("Zone", zone.Name)
	model:SetAttribute("Index", zone.Index)
	model:SetAttribute("Speed", zone.Speed)
	return {
		Name = zone.Name,
		Index = zone.Index,
		Model = model,
		Area = area,
		Arch = if arch and arch:IsA("BasePart") then arch else nil,
		Sites = sites,
		Guardian = if guardian and guardian:IsA("BasePart") then guardian else nil,
	}
end

-- ===================================================================== API

-- Géométrie d'une zone par nom
function ZoneService.Get(name: string): ZoneGeo?
	return byName[name]
end

-- Toutes les zones, dans l'ordre de la route
function ZoneService.List(): { ZoneGeo }
	return table.clone(geos)
end

-- Nom de la zone qui contient cette position (nil hors route)
function ZoneService.ZoneAt(position: Vector3): string?
	for _, geo in geos do
		local area = geo.Area
		local relative = area.CFrame:PointToObjectSpace(position)
		local half = area.Size / 2
		if math.abs(relative.X) <= half.X and math.abs(relative.Z) <= half.Z and relative.Y >= -half.Y - AREA_BELOW and relative.Y <= half.Y + AREA_ABOVE then
			return geo.Name
		end
	end
	return nil
end

-- Zone où se trouve le joueur ("" hors route)
function ZoneService.PlayerZone(player: Player): string
	return current[player] or ""
end

local function update(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zone = if root and root:IsA("BasePart") then ZoneService.ZoneAt(root.Position) or "" else ""
	local previous = current[player] or ""
	if zone ~= previous then
		current[player] = zone
		player:SetAttribute("Zone", zone)
		Signals.Fire("ZoneChanged", player, zone, previous)
	end
end

local function registerCommands()
	AdminService.RegisterCommand("tpzone", {
		Description = "Teleport to a zone (1 = Beach ... 8 = Meteor Crater) or home (0)",
		Usage = "tpzone <0-8>",
		Run = function(caller: Player, args: { string })
			local index = tonumber(args[1] or "")
			if index == 0 then
				return PlotService.Teleport(caller), "Home"
			end
			local zone = if index then Zones.List[index] else nil
			local geo = zone and byName[zone.Name]
			local character = caller.Character
			if not (geo and character) then
				return false, "Usage: tpzone <0-8>"
			end
			local area = geo.Area
			character:PivotTo(area.CFrame * CFrame.new(0, area.Size.Y / 2 + 3, -area.Size.Z / 2 + 12) * CFrame.Angles(0, math.pi, 0))
			return true, "Teleported to " .. geo.Name
		end,
	})
end

function ZoneService.Init()
	registerCommands()
	local map = PlotService.MapFolder()
	local zonesFolder: Instance
	local existing = map:FindFirstChild("Zones")
	if existing then
		zonesFolder = existing
	else
		zonesFolder = Instance.new("Folder")
		zonesFolder.Name = "Zones"
		zonesFolder.Parent = map
	end
	for _, zone in Zones.List do
		local model = zonesFolder:FindFirstChild(zone.Name)
		if not (model and model:IsA("Model")) then
			model = buildZone(zone, zonesFolder)
		end
		local geo = readZone(zone, model :: Model)
		if geo then
			table.insert(geos, geo)
			byName[zone.Name] = geo
		end
	end
end

function ZoneService.Start()
	while true do
		task.wait(UPDATE_INTERVAL)
		-- (joueurs prêts seulement : ils ont une entrée dans `current`, vidée dans OnPlayerRemoving)
		for player in current do
			if player.Parent == Players then
				update(player)
			end
		end
	end
end

function ZoneService.OnPlayerReady(player: Player, _data: { [string]: any })
	current[player] = ""
	player:SetAttribute("Zone", "")
end

function ZoneService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	current[player] = nil
end

return ZoneService
