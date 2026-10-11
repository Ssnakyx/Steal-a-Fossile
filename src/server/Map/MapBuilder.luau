--!strict
-- Construction de la map (brief 10) : Workspace.Map avec les 5 parcs (Plots, Config.Map.Plots.Count), la place du spawn (Spawn), les 8 zones de
-- la route (Zones, une par module de Map/Zones), les murs invisibles de la route et la falaise de fin. Les noms des
-- points d'ancrage sont ceux que lisent PlotService et ZoneService (docs/BOUCLE.md). La map est la même à chaque
-- démarrage (graine Config.Map.Seed). Lancée par MapService ; Build({ Yield = true }) laisse respirer Studio entre
-- deux zones (aperçu en mode édition). Lighting() pose l'ambiance de la place (Config.Ambience).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)
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

-- Effet de Lighting (ou nuages du Terrain) : celui qui existe déjà dans la place, sinon un nouveau
local function effect(parent: Instance, className: string, name: string?): Instance
	local found = if name then parent:FindFirstChild(name) else parent:FindFirstChildOfClass(className)
	if found and found:IsA(className) then
		return found
	end
	local created = Instance.new(className)
	if name then
		created.Name = name
	end
	created.Parent = parent
	return created
end

-- Ambiance de la place du spawn (Config.Ambience.Regions.Plaza) : heure, lumière, brume, nuages, ciel, couleurs, bloom.
-- Chaque joueur passe ensuite à l'ambiance de l'endroit où il se trouve (AmbienceController, côté client) ; les
-- effets déjà présents dans la place sont réglés plutôt que doublés.
function MapBuilder.Lighting()
	local base = Ambience.Regions.Plaza
	Lighting.ClockTime = base.ClockTime
	Lighting.Brightness = base.Brightness
	Lighting.ExposureCompensation = base.Exposure
	Lighting.Ambient = base.Ambient
	Lighting.OutdoorAmbient = base.OutdoorAmbient
	Lighting.ColorShift_Top = base.SunTint
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	local atmosphere = effect(Lighting, "Atmosphere") :: Atmosphere
	atmosphere.Density = base.Atmosphere.Density
	atmosphere.Offset = base.Atmosphere.Offset
	atmosphere.Color = base.Atmosphere.Color
	atmosphere.Decay = base.Atmosphere.Decay
	atmosphere.Glare = base.Atmosphere.Glare
	atmosphere.Haze = base.Atmosphere.Haze
	local sky = effect(Lighting, "Sky") :: Sky
	sky.StarCount = math.floor(base.Sky.Stars)
	sky.SunAngularSize = base.Sky.Sun
	sky.MoonAngularSize = base.Sky.Moon
	local bloom = effect(Lighting, "BloomEffect") :: BloomEffect
	bloom.Intensity = base.Bloom.Intensity
	bloom.Size = base.Bloom.Size
	bloom.Threshold = base.Bloom.Threshold
	local rays = effect(Lighting, "SunRaysEffect") :: SunRaysEffect
	rays.Intensity = base.SunRays.Intensity
	rays.Spread = base.SunRays.Spread
	local grade = effect(Lighting, "ColorCorrectionEffect", Ambience.GradeName) :: ColorCorrectionEffect
	grade.Brightness = base.Grade.Brightness
	grade.Contrast = base.Grade.Contrast
	grade.Saturation = base.Grade.Saturation
	grade.TintColor = base.Grade.Tint
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = effect(terrain, "Clouds") :: Clouds
		clouds.Cover = base.Clouds.Cover
		clouds.Density = base.Clouds.Density
		clouds.Color = base.Clouds.Color
		clouds.Enabled = true
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
