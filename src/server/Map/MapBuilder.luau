--!strict
-- Construction de la map (brief 10) : Workspace.Map avec les 5 parcs (Plots, Config.Map.Plots.Count), la place du spawn (Spawn), les 8 zones de
-- la route (Zones, une par module de Map/Zones), les murs invisibles de la route et la falaise de fin. Les noms des
-- points d'ancrage sont ceux que lisent PlotService et ZoneService (docs/BOUCLE.md). La map est la même à chaque
-- démarrage (graine Config.Map.Seed). Lancée par MapService ; Build({ Yield = true }) laisse respirer Studio entre
-- deux zones (aperçu en mode édition).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Kit = require(script.Parent.Kit)
local Plaza = require(script.Parent.Plaza)
local Plots = require(script.Parent.Plots)
local ZoneBase = require(script.Parent.ZoneBase)

local MapBuilder = {}

export type ZoneStats = { Name: string, Z0: number, Length: number, Parts: number, Lights: number }
export type Stats = { Parts: number, Lights: number, Zones: { ZoneStats }, RouteEnd: number }
export type Options = { Yield: boolean? }

local rgb = Color3.fromRGB

-- Thème de chaque zone : module Map/Zones/<Nom sans espaces>
local function themeOf(name: string): ZoneBase.Theme?
	local module = script.Parent.Zones:FindFirstChild((string.gsub(name, " ", "")))
	if module and module:IsA("ModuleScript") then
		return (require :: any)(module)
	end
	return nil
end

local function count(root: Instance): (number, number)
	local parts, lights = 0, 0
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
		elseif item:IsA("Light") then
			lights += 1
		end
	end
	return parts, lights
end

-- Longueur de la zone (Config.Map.Zones, sinon 240)
function MapBuilder.Length(name: string): number
	local entry = (Map.Zones :: any)[name]
	return if entry and type(entry.Length) == "number" then entry.Length else 240
end

-- Z où commence chaque zone et Z de la fin de la route
function MapBuilder.Layout(): ({ [string]: number }, number)
	local starts = {}
	local z = Map.Plaza.Depth
	for _, zone in Zones.List do
		starts[zone.Name] = z
		z += MapBuilder.Length(zone.Name)
	end
	return starts, z
end

-- Falaise de fin de route (3 gradins sur toute la largeur), avec quelques cristaux
local function routeEnd(parent: Instance, z: number, rng: Random)
	local folder = Kit.folder("RouteEnd", parent)
	local gt = Map.GroundTop
	local full = Map.Route.Width / 2 + Map.Route.Border
	local depth = Map.Route.EndDepth
	local colors = { rgb(62, 50, 78), rgb(84, 66, 106), rgb(110, 88, 132) }
	Kit.block(folder, Vector3.new(full * 2, 2, depth), CFrame.new(0, gt - 1, z + depth / 2), rgb(84, 64, 106))
	for tier = 1, 3 do
		local offset = (tier - 1) * depth / 4
		local height = 26 + tier * 16
		local x = -full
		while x < full - 0.01 do
			local width = math.min(Kit.range(rng, 18, 30), full - x)
			local h = height + Kit.range(rng, -4, 6)
			Kit.block(folder, Vector3.new(width, h, depth - offset), CFrame.new(x + width / 2, gt + h / 2, z + offset + (depth - offset) / 2), colors[tier])
			x += width
		end
	end
	Plaza.Barrier(folder, Vector3.new(full * 2, Map.Route.BarrierHeight, 1), CFrame.new(0, gt + Map.Route.BarrierHeight / 2, z + 0.5))
end

-- Lumière du jour, brume légère, bloom modéré (seulement ce qui n'existe pas déjà dans Lighting)
function MapBuilder.Lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2
	Lighting.Ambient = rgb(84, 84, 96)
	Lighting.OutdoorAmbient = rgb(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.15
		atmosphere.Color = rgb(206, 220, 238)
		atmosphere.Decay = rgb(120, 140, 170)
		atmosphere.Glare = 0
		atmosphere.Haze = 1.4
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.35
		bloom.Size = 24
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Saturation = 0.08
		grade.Contrast = 0.04
		grade.Parent = Lighting
	end
end

-- Construit Workspace.Map (ou `parent`.Map) et renvoie le dossier et les comptes (pièces, lumières, par zone)
function MapBuilder.Build(parent: Instance?, options: Options?): (Folder, Stats)
	local yield = options ~= nil and options.Yield == true
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = parent or Workspace
	local rng = Random.new(Map.Seed)
	local ctx: Kit.Ctx = { Rng = rng, Lights = 0, LightBudget = 0, Grid = nil, Ray = nil, GroundTop = Map.GroundTop }

	local plots = Kit.folder("Plots", map)
	for index = 1, Map.Plots.Count do
		Plots.Build(index, plots, ctx)
	end
	Plaza.Build(map, ctx)
	if yield then
		task.wait()
	end

	local stats: Stats = { Parts = 0, Lights = 0, Zones = {}, RouteEnd = 0 }
	local zonesFolder = Kit.folder("Zones", map)
	local starts, routeZ = MapBuilder.Layout()
	for _, zone in Zones.List do
		local theme = themeOf(zone.Name)
		if theme then
			local length = MapBuilder.Length(zone.Name)
			local model = ZoneBase.Build(zone, theme, starts[zone.Name], length, zonesFolder, Random.new(Map.Seed + zone.Index * 7919))
			local parts, lights = count(model)
			table.insert(stats.Zones, { Name = zone.Name, Z0 = starts[zone.Name], Length = length, Parts = parts, Lights = lights })
		else
			warn("[MapBuilder] pas de module Map/Zones pour la zone " .. zone.Name)
		end
		if yield then
			task.wait()
		end
	end

	-- murs invisibles de la route, falaise de fin
	local routeFolder = Kit.folder("Route", map)
	local gt, height = Map.GroundTop, Map.Route.BarrierHeight
	local z0 = Map.Plaza.Depth
	for _, side in { -1, 1 } do
		Plaza.Barrier(routeFolder, Vector3.new(1, height, routeZ - z0), CFrame.new(side * (Map.Route.Width / 2 + 0.5), gt + height / 2, (z0 + routeZ) / 2))
	end
	routeEnd(routeFolder, routeZ, rng)
	stats.RouteEnd = routeZ
	stats.Parts, stats.Lights = count(map)
	return map, stats
end

return MapBuilder
