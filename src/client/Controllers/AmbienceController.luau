--!strict
-- Ambiances de la map (côté client, chez chaque joueur seulement) : selon l'endroit où se trouve son personnage (place
-- du spawn et parcs, ou une des 8 zones de la route), l'heure du jour, la lumière, la brume, les nuages, les couleurs
-- de l'image et le bloom prennent les valeurs de Config.Ambience, avec un fondu entre deux zones et en douceur après
-- une téléportation. En plus :
--   * particules en petits cubes autour du joueur (lucioles, spores, poussière, neige, braises, cendres, bulles,
--     plancton, poussière d'étoiles), recyclées dans un seul lot de pièces ;
--   * ciel animé qui suit la caméra : aurores, planète à anneau, étoiles filantes, ptérosaures qui tournent ;
--   * décor flottant de la map (modèles tagués « AmbientFloat » : cristaux, feux follets, méduses) qui monte, descend
--     et tourne doucement, près du joueur seulement.
-- Toutes les pièces créées ici sont dans un dossier « Ambience » de la caméra (jamais vues par les autres joueurs),
-- sans collision ni requêtes. Lighting n'est écrit que pendant un fondu (au plus LightingRate fois par seconde).
-- Les effets de couleur des autres controllers (StressController...) s'ajoutent à celui de l'ambiance (« AmbienceGrade »).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

type Preset = Ambience.Preset
type MoteKind = Ambience.MoteKind

export type Region = { Name: string, Z0: number, Z1: number }

export type Stats = {
	Motes: number,
	Kinds: { [string]: number },
	Aurora: boolean,
	Planet: boolean,
	Stars: number,
	Birds: number,
	Floaters: number,
	Moving: number,
}

type Mote = {
	Part: Part,
	Alive: boolean,
	Kind: string,
	Def: MoteKind?,
	Position: Vector3,
	Velocity: Vector3,
	Age: number,
	Life: number,
	Phase: number,
	Spin: number,
}

type Pane = { Curtain: Part, Edge: Part, Ribbon: number, Index: number, Heading: number }
type Piece = { Part: Part, Offset: CFrame, Opacity: number }
type Star = { Head: Part, Tail: Part, Active: boolean, Offset: Vector3, Dir: Vector3, Age: number, Life: number }
type Bird = { Parts: { Part }, Radius: number, Height: number, Speed: number, Angle: number, Center: Vector3, Fade: number }
type Floater = { Model: Model, Base: CFrame?, Height: number, Speed: number, Spin: number, Phase: number }

local AmbienceController = {}

local TAU = math.pi * 2
local MAX_DT = 0.1 -- (une image très longue ne fait pas tout sauter)
local REFRESH = 2 -- secondes entre deux vérifications des effets de Lighting (supprimés, remplacés)
local FADE_IN = 0.6 -- apparition d'une particule (s)
local FADE_OUT = 0.8 -- disparition
local STAR_FADE_IN = 0.15
local STAR_FADE_OUT = 0.3
local BIRD_FADE = 1 -- par seconde
local BIRD_SCALE = 2
local WHITE = Color3.new(1, 1, 1)

local regions: { Region } = {}
local target: Preset
local current: Preset
local snapped = false
local clock = 0
local lightingTimer = 0
local refreshTimer = 0
local rng = Random.new()

local folder: Folder? = nil
local effects: {
	Atmosphere: Atmosphere?,
	Clouds: Clouds?,
	Sky: Sky?,
	Grade: ColorCorrectionEffect?,
	Bloom: BloomEffect?,
	SunRays: SunRaysEffect?,
} = {}

local motes: { Mote } = {}
local moteCount: { [string]: number } = {}
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}
local scratchMotes: { [string]: number } = {}

local panes: { Pane } = {}
local auroraShown = false
local planet: { Piece } = {}
local planetShown = false
local stars: { Star } = {}
local birds: { Bird } = {}
local floaters: { [Instance]: Floater } = {}
local moving = 0

-- ===================================================================== calculs (sans effet de bord)

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Copie complète d'une ambiance (tables imbriquées comprises)
function AmbienceController.Copy(p: Preset): Preset
	local copy = table.clone(p)
	copy.Atmosphere = table.clone(p.Atmosphere)
	copy.Clouds = table.clone(p.Clouds)
	copy.Sky = table.clone(p.Sky)
	copy.Grade = table.clone(p.Grade)
	copy.Bloom = table.clone(p.Bloom)
	copy.SunRays = table.clone(p.SunRays)
	copy.Motes = table.clone(p.Motes)
	copy.AuroraColors = table.clone(p.AuroraColors)
	return copy
end

-- Place du spawn puis zones de la route, de Z0 à Z1 (mêmes mesures que la map : Config.Map, ordre de Config.Zones).
-- La place va jusqu'à -l'infini (parcs), la dernière zone jusqu'à +l'infini (falaise de fin).
function AmbienceController.Regions(): { Region }
	local list: { Region } = { { Name = "Plaza", Z0 = -math.huge, Z1 = Map.Plaza.Depth } }
	local z = Map.Plaza.Depth
	for _, zone in Zones.List do
		local entry = (Map.Zones :: any)[zone.Name]
		local length = if entry and type(entry.Length) == "number" then entry.Length else 240
		table.insert(list, { Name = zone.Name, Z0 = z, Z1 = z + length })
		z += length
	end
	list[#list].Z1 = math.huge
	return list
end

-- Mélange à la position Z : (région A, région B, part de B de 0 à 1). Hors des fondus, A = B et la part vaut 0.
function AmbienceController.Mix(z: number): (string, string, number)
	if #regions == 0 then
		regions = AmbienceController.Regions()
	end
	if z ~= z then
		return "Plaza", "Plaza", 0
	end
	local blend = math.max(1, Ambience.Blend)
	local half = blend / 2
	for index, region in regions do
		if z < region.Z1 or index == #regions then
			local previous = regions[index - 1]
			if previous and z < region.Z0 + half then
				return previous.Name, region.Name, smooth((z - (region.Z0 - half)) / blend)
			end
			local following = regions[index + 1]
			if following and z > region.Z1 - half then
				return region.Name, following.Name, smooth((z - (region.Z1 - half)) / blend)
			end
			return region.Name, region.Name, 0
		end
	end
	return "Plaza", "Plaza", 0
end

-- Ambiance d'une région (celle de la place si la région n'en a pas)
function AmbienceController.PresetOf(name: string): Preset
	return Ambience.Regions[name] or Ambience.Regions.Plaza
end

-- Mélange de deux ambiances (t = part de b, de 0 à 1), écrit dans `out` (peut être `a` lui-même) ou une copie
function AmbienceController.Blend(a: Preset, b: Preset, t: number, out: Preset?): Preset
	local w = math.clamp(if t == t then t else 0, 0, 1)
	local o = out or AmbienceController.Copy(a)
	o.ClockTime = lerp(a.ClockTime, b.ClockTime, w)
	o.Brightness = lerp(a.Brightness, b.Brightness, w)
	o.Exposure = lerp(a.Exposure, b.Exposure, w)
	o.Ambient = a.Ambient:Lerp(b.Ambient, w)
	o.OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, w)
	o.SunTint = a.SunTint:Lerp(b.SunTint, w)
	local aa, ba, oa = a.Atmosphere, b.Atmosphere, o.Atmosphere
	oa.Density = lerp(aa.Density, ba.Density, w)
	oa.Offset = lerp(aa.Offset, ba.Offset, w)
	oa.Color = aa.Color:Lerp(ba.Color, w)
	oa.Decay = aa.Decay:Lerp(ba.Decay, w)
	oa.Glare = lerp(aa.Glare, ba.Glare, w)
	oa.Haze = lerp(aa.Haze, ba.Haze, w)
	local ac, bc, oc = a.Clouds, b.Clouds, o.Clouds
	oc.Cover = lerp(ac.Cover, bc.Cover, w)
	oc.Density = lerp(ac.Density, bc.Density, w)
	oc.Color = ac.Color:Lerp(bc.Color, w)
	local ask, bsk, osk = a.Sky, b.Sky, o.Sky
	osk.Stars = lerp(ask.Stars, bsk.Stars, w)
	osk.Sun = lerp(ask.Sun, bsk.Sun, w)
	osk.Moon = lerp(ask.Moon, bsk.Moon, w)
	local ag, bg, og = a.Grade, b.Grade, o.Grade
	og.Brightness = lerp(ag.Brightness, bg.Brightness, w)
	og.Contrast = lerp(ag.Contrast, bg.Contrast, w)
	og.Saturation = lerp(ag.Saturation, bg.Saturation, w)
	og.Tint = ag.Tint:Lerp(bg.Tint, w)
	local ab, bb, ob = a.Bloom, b.Bloom, o.Bloom
	ob.Intensity = lerp(ab.Intensity, bb.Intensity, w)
	ob.Size = lerp(ab.Size, bb.Size, w)
	ob.Threshold = lerp(ab.Threshold, bb.Threshold, w)
	local ar, br, orr = a.SunRays, b.SunRays, o.SunRays
	orr.Intensity = lerp(ar.Intensity, br.Intensity, w)
	orr.Spread = lerp(ar.Spread, br.Spread, w)
	-- particules : toutes les sortes des deux côtés
	table.clear(scratchMotes)
	for kind, n in a.Motes do
		scratchMotes[kind] = n * (1 - w)
	end
	for kind, n in b.Motes do
		scratchMotes[kind] = (scratchMotes[kind] or 0) + n * w
	end
	table.clear(o.Motes)
	for kind, n in scratchMotes do
		if n > 0.001 then
			o.Motes[kind] = n
		end
	end
	-- aurores : couleurs de celle qui se voit le plus
	local wa, wb = a.Aurora * (1 - w), b.Aurora * w
	if wa + wb > 0 then
		local k = wb / (wa + wb)
		for index = 1, math.max(#a.AuroraColors, #b.AuroraColors) do
			local ca = a.AuroraColors[index] or b.AuroraColors[index]
			local cb = b.AuroraColors[index] or ca
			o.AuroraColors[index] = ca:Lerp(cb, k)
		end
	end
	o.Aurora = lerp(a.Aurora, b.Aurora, w)
	o.Planet = lerp(a.Planet, b.Planet, w)
	o.ShootingStars = lerp(a.ShootingStars, b.ShootingStars, w)
	o.Birds = lerp(a.Birds, b.Birds, w)
	return o
end

-- Ambiance visée à la position Z (fondu compris)
function AmbienceController.TargetAt(z: number, out: Preset?): Preset
	local a, b, t = AmbienceController.Mix(z)
	return AmbienceController.Blend(AmbienceController.PresetOf(a), AmbienceController.PresetOf(b), t, out)
end

-- ===================================================================== Lighting et effets

local function setNumber(inst: Instance, key: string, value: number, epsilon: number)
	local object = inst :: any
	if math.abs(object[key] - value) > epsilon then
		object[key] = value
	end
end

local function setColor(inst: Instance, key: string, value: Color3)
	local object = inst :: any
	local old: Color3 = object[key]
	if math.abs(old.R - value.R) + math.abs(old.G - value.G) + math.abs(old.B - value.B) > 0.003 then
		object[key] = value
	end
end

local function findOrCreate(parent: Instance, className: string, name: string?): Instance
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

-- Effets de Lighting (ceux de la place s'ils existent, sinon créés chez le joueur) et nuages du Terrain
local function ensureEffects()
	local e = effects
	if not (e.Atmosphere and e.Atmosphere.Parent) then
		e.Atmosphere = findOrCreate(Lighting, "Atmosphere") :: Atmosphere
	end
	if not (e.Sky and e.Sky.Parent) then
		e.Sky = findOrCreate(Lighting, "Sky") :: Sky
	end
	if not (e.Grade and e.Grade.Parent) then
		e.Grade = findOrCreate(Lighting, "ColorCorrectionEffect", Ambience.GradeName) :: ColorCorrectionEffect
	end
	if not (e.Bloom and e.Bloom.Parent) then
		e.Bloom = findOrCreate(Lighting, "BloomEffect") :: BloomEffect
	end
	if not (e.SunRays and e.SunRays.Parent) then
		e.SunRays = findOrCreate(Lighting, "SunRaysEffect") :: SunRaysEffect
	end
	if not (e.Clouds and e.Clouds.Parent) then
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		e.Clouds = if terrain then findOrCreate(terrain, "Clouds") :: Clouds else nil
	end
end

local function apply(p: Preset)
	setNumber(Lighting, "ClockTime", p.ClockTime, 0.002)
	setNumber(Lighting, "Brightness", p.Brightness, 0.002)
	setNumber(Lighting, "ExposureCompensation", p.Exposure, 0.002)
	setColor(Lighting, "Ambient", p.Ambient)
	setColor(Lighting, "OutdoorAmbient", p.OutdoorAmbient)
	setColor(Lighting, "ColorShift_Top", p.SunTint)
	local e = effects
	local atmosphere = e.Atmosphere
	if atmosphere then
		setNumber(atmosphere, "Density", p.Atmosphere.Density, 0.001)
		setNumber(atmosphere, "Offset", p.Atmosphere.Offset, 0.001)
		setColor(atmosphere, "Color", p.Atmosphere.Color)
		setColor(atmosphere, "Decay", p.Atmosphere.Decay)
		setNumber(atmosphere, "Glare", p.Atmosphere.Glare, 0.002)
		setNumber(atmosphere, "Haze", p.Atmosphere.Haze, 0.002)
	end
	local clouds = e.Clouds
	if clouds then
		if not clouds.Enabled then
			clouds.Enabled = true
		end
		setNumber(clouds, "Cover", p.Clouds.Cover, 0.002)
		setNumber(clouds, "Density", p.Clouds.Density, 0.002)
		setColor(clouds, "Color", p.Clouds.Color)
	end
	local sky = e.Sky
	if sky then
		setNumber(sky, "StarCount", math.floor(p.Sky.Stars + 0.5), 0.5)
		setNumber(sky, "SunAngularSize", p.Sky.Sun, 0.05)
		setNumber(sky, "MoonAngularSize", p.Sky.Moon, 0.05)
	end
	local grade = e.Grade
	if grade then
		setNumber(grade, "Brightness", p.Grade.Brightness, 0.001)
		setNumber(grade, "Contrast", p.Grade.Contrast, 0.001)
		setNumber(grade, "Saturation", p.Grade.Saturation, 0.001)
		setColor(grade, "TintColor", p.Grade.Tint)
	end
	local bloom = e.Bloom
	if bloom then
		setNumber(bloom, "Intensity", p.Bloom.Intensity, 0.002)
		setNumber(bloom, "Size", p.Bloom.Size, 0.1)
		setNumber(bloom, "Threshold", p.Bloom.Threshold, 0.002)
	end
	local rays = e.SunRays
	if rays then
		setNumber(rays, "Intensity", p.SunRays.Intensity, 0.001)
		setNumber(rays, "Spread", p.SunRays.Spread, 0.002)
	end
end

-- ===================================================================== pièces de l'ambiance (dans la caméra)

local function ensureFolder(camera: Camera): Folder
	local f = folder or Instance.new("Folder")
	if not folder then
		f.Name = "Ambience"
		folder = f
	end
	if f.Parent ~= camera then
		f.Parent = camera
	end
	return f
end

local function newPart(parent: Instance, size: Vector3, color: Color3, neon: boolean): Part
	local part = Instance.new("Part")
	part.Name = "Ambience"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.Color = color
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function setTransparency(part: BasePart, value: number)
	local v = math.clamp(value, 0, 1)
	if math.abs(part.Transparency - v) > 0.01 then
		part.Transparency = v
	end
end

local function queue(part: BasePart, cframe: CFrame)
	table.insert(moveParts, part)
	table.insert(moveFrames, cframe)
end

-- ===================================================================== particules

local function range(pair: { number }): number
	return pair[1] + rng:NextNumber() * ((pair[2] or pair[1]) - pair[1])
end

local function jitter(amount: number): number
	return (rng:NextNumber() * 2 - 1) * amount
end

local function wanted(kind: string): number
	local n = current.Motes[kind]
	return if n and Ambience.Motes.Kinds[kind] then math.floor(n + 0.5) else 0
end

local function kill(mote: Mote)
	mote.Alive = false
	mote.Def = nil
	moteCount[mote.Kind] = math.max(0, (moteCount[mote.Kind] or 0) - 1)
	setTransparency(mote.Part, 1)
end

local function freeMote(parent: Instance): Mote?
	for _, mote in motes do
		if not mote.Alive then
			return mote
		end
	end
	if #motes >= Ambience.Motes.Max then
		return nil
	end
	local mote: Mote = {
		Part = newPart(parent, Vector3.one * 0.3, WHITE, true),
		Alive = false,
		Kind = "",
		Def = nil,
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Age = 0,
		Life = 1,
		Phase = 0,
		Spin = 0,
	}
	table.insert(motes, mote)
	return mote
end

local function spawnMote(mote: Mote, kind: string, def: MoteKind, focus: Vector3)
	local radius = Ambience.Motes.Radius * math.sqrt(rng:NextNumber())
	local angle = rng:NextNumber() * TAU
	mote.Position = focus + Vector3.new(math.cos(angle) * radius, lerp(def.Low, def.High, rng:NextNumber()), math.sin(angle) * radius)
	mote.Velocity = def.Velocity + Vector3.new(jitter(def.Jitter.X), jitter(def.Jitter.Y), jitter(def.Jitter.Z))
	mote.Life = math.max(0.5, range(def.Life))
	mote.Age = 0
	mote.Phase = rng:NextNumber() * TAU
	mote.Spin = def.Spin * (0.5 + rng:NextNumber())
	mote.Kind = kind
	mote.Def = def
	mote.Alive = true
	local part = mote.Part
	local size = range(def.Size)
	part.Size = Vector3.new(size, size, size)
	part.Color = def.Colors[rng:NextInteger(1, #def.Colors)]
	part.Material = if def.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Transparency = 1
	moteCount[kind] = (moteCount[kind] or 0) + 1
end

local function updateMotes(dt: number, focus: Vector3, parent: Instance)
	local limit = (Ambience.Motes.Radius * 1.35) ^ 2
	for _, mote in motes do
		local def = mote.Def
		if mote.Alive and def then
			-- une sorte qui n'est plus voulue (changement de zone) s'éteint plus vite
			mote.Age += if (moteCount[mote.Kind] or 0) > wanted(mote.Kind) then dt * 3 else dt
			mote.Position += mote.Velocity * dt
			local offset = mote.Position - focus
			if mote.Age >= mote.Life or offset.X * offset.X + offset.Z * offset.Z > limit or offset.Y < def.Low - 10 or offset.Y > def.High + 14 then
				kill(mote)
			else
				local fade = math.clamp(math.min(mote.Age / FADE_IN, (mote.Life - mote.Age) / FADE_OUT), 0, 1)
				local alpha = def.Transparency
				if def.Blink > 0 then
					local pulse = 0.5 + 0.5 * math.sin(mote.Phase + mote.Age * 3)
					alpha += (1 - alpha) * def.Blink * (1 - pulse)
				end
				setTransparency(mote.Part, 1 - (1 - alpha) * fade)
				local s = mote.Phase + mote.Age * def.WobbleSpeed
				local w = def.Wobble
				local position = mote.Position + Vector3.new(math.sin(s) * w, math.sin(s * 1.7) * w * 0.4, math.cos(s * 0.8) * w)
				local turn = mote.Age * mote.Spin
				queue(mote.Part, CFrame.new(position) * CFrame.Angles(turn, turn * 0.7, 0))
			end
		end
	end
	-- nouvelles particules : la sorte qui manque le plus, quelques-unes par image
	for _ = 1, Ambience.Motes.SpawnPerFrame do
		local bestKind, bestGap = nil :: string?, 0
		for kind in current.Motes do
			local gap = wanted(kind) - (moteCount[kind] or 0)
			if gap > bestGap then
				bestKind, bestGap = kind, gap
			end
		end
		local def = bestKind and Ambience.Motes.Kinds[bestKind]
		if not (bestKind and def) then
			break
		end
		local mote = freeMote(parent)
		if not mote then
			break
		end
		spawnMote(mote, bestKind, def, focus)
	end
end

-- ===================================================================== ciel animé

local function buildAurora(parent: Instance)
	local cfg = Ambience.Sky.Aurora
	local segments = math.max(2, cfg.Segments)
	local step = cfg.Arc / (segments - 1)
	for ribbon = 1, cfg.Ribbons do
		local distance = Ambience.Sky.Distance + (ribbon - 1) * 26
		local width = distance * math.rad(step) * 1.04
		local heading = cfg.Headings[ribbon] or (ribbon - 1) * 120
		for index = 1, segments do
			table.insert(panes, {
				Curtain = newPart(parent, Vector3.new(width, cfg.Height, 0.4), WHITE, true),
				Edge = newPart(parent, Vector3.new(width, 5, 0.6), WHITE, true),
				Ribbon = ribbon,
				Index = index,
				Heading = math.rad(heading - cfg.Arc / 2 + (index - 1) * step),
			})
		end
	end
end

local function updateAurora(eye: Vector3, parent: Instance)
	local strength = current.Aurora
	if strength < 0.01 then
		if auroraShown then
			for _, pane in panes do
				setTransparency(pane.Curtain, 1)
				setTransparency(pane.Edge, 1)
			end
			auroraShown = false
		end
		return
	end
	if #panes == 0 then
		buildAurora(parent)
	end
	auroraShown = true
	local cfg = Ambience.Sky.Aurora
	for _, pane in panes do
		local ribbon, index = pane.Ribbon, pane.Index
		local color = current.AuroraColors[ribbon] or current.AuroraColors[1] or WHITE
		local wave = math.sin(clock * cfg.Speed + index * 0.45 + ribbon * 1.7)
		local heading = pane.Heading + math.rad(math.sin(clock * cfg.Speed * 0.6 + ribbon) * 3)
		local direction = Vector3.new(math.sin(heading), 0, math.cos(heading))
		local distance = Ambience.Sky.Distance + (ribbon - 1) * 26 + wave * 10
		local lift = cfg.Elevation + (ribbon - 1) * 16 + math.sin(clock * cfg.Speed * 1.3 + index * 0.8 + ribbon) * 6
		local base = eye + direction * distance + Vector3.new(0, lift, 0)
		local look = CFrame.lookAt(base, Vector3.new(eye.X, base.Y, eye.Z))
		local shimmer = 0.5 + 0.5 * math.sin(clock * 0.9 + index * 0.7 + ribbon * 2.3)
		setColor(pane.Curtain, "Color", color)
		setColor(pane.Edge, "Color", color:Lerp(WHITE, 0.35))
		setTransparency(pane.Curtain, 1 - strength * (0.24 + 0.12 * shimmer))
		setTransparency(pane.Edge, 1 - strength * (0.5 + 0.25 * shimmer))
		queue(pane.Curtain, look * CFrame.new(0, cfg.Height / 2, 0))
		queue(pane.Edge, look * CFrame.new(0, 2.5, -0.3))
	end
end

-- Planète en disques empilés (boule en escalier) avec un anneau
local function buildPlanet(parent: Instance)
	local cfg = Ambience.Sky.Planet
	local r = cfg.Radius
	local layers = 7
	local h = 2 * r / layers
	for k = 0, layers - 1 do
		local y = -r + (k + 0.5) * h
		local lr = r * math.sqrt(math.max(0.05, 1 - (y / r) ^ 2))
		local color = cfg.Colors[(k % #cfg.Colors) + 1]
		for _, size in { Vector3.new(lr * 2, h, lr * 1.24), Vector3.new(lr * 1.24, h, lr * 2), Vector3.new(lr * 1.72, h, lr * 1.72) } do
			table.insert(planet, { Part = newPart(parent, size, color, true), Offset = CFrame.new(0, y, 0), Opacity = 0.88 })
		end
	end
	local pieces = 16
	local ring = r * 1.75
	for k = 0, pieces - 1 do
		local a = k * TAU / pieces
		local length = TAU * ring / pieces * 1.08
		table.insert(planet, {
			Part = newPart(parent, Vector3.new(r * 0.32, 0.6, length), cfg.Ring, true),
			Offset = CFrame.Angles(0, a, 0) * CFrame.new(ring, 0, 0),
			Opacity = 0.5,
		})
	end
end

local function updatePlanet(eye: Vector3, parent: Instance)
	local strength = current.Planet
	if strength < 0.01 then
		if planetShown then
			for _, piece in planet do
				setTransparency(piece.Part, 1)
			end
			planetShown = false
		end
		return
	end
	if #planet == 0 then
		buildPlanet(parent)
	end
	planetShown = true
	local cfg = Ambience.Sky.Planet
	local direction = if cfg.Direction.Magnitude > 0 then cfg.Direction.Unit else Vector3.new(0, 0.5, 0.8).Unit
	local base = CFrame.new(eye + direction * (Ambience.Sky.Distance + 60)) * CFrame.Angles(math.rad(18), clock * 0.04, math.rad(-22))
	for _, piece in planet do
		setTransparency(piece.Part, 1 - strength * piece.Opacity)
		queue(piece.Part, base * piece.Offset)
	end
end

local function updateStars(dt: number, eye: Vector3, parent: Instance)
	local cfg = Ambience.Sky.ShootingStars
	local rate = current.ShootingStars
	if rate > 0.001 and rng:NextNumber() < rate * dt then
		local star: Star? = nil
		for _, s in stars do
			if not s.Active then
				star = s
				break
			end
		end
		if not star and #stars < cfg.Pool then
			local fresh: Star = {
				Head = newPart(parent, Vector3.new(1.2, 1.2, 1.2), cfg.Color, true),
				Tail = newPart(parent, Vector3.new(0.5, 0.5, cfg.Length), cfg.Color, true),
				Active = false,
				Offset = Vector3.zero,
				Dir = Vector3.zAxis,
				Age = 0,
				Life = 1,
			}
			table.insert(stars, fresh)
			star = fresh
		end
		if star then
			local heading = rng:NextNumber() * TAU
			local elevation = math.rad(25 + rng:NextNumber() * 35)
			star.Offset = Vector3.new(math.cos(elevation) * math.sin(heading), math.sin(elevation), math.cos(elevation) * math.cos(heading)) * Ambience.Sky.Distance
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			star.Dir = (Vector3.new(math.cos(heading), 0, -math.sin(heading)) * side + Vector3.new(0, -0.45, 0)).Unit
			star.Age = 0
			star.Life = range(cfg.Life)
			star.Active = true
		end
	end
	for _, star in stars do
		if star.Active then
			star.Age += dt
			if star.Age >= star.Life then
				star.Active = false
				setTransparency(star.Head, 1)
				setTransparency(star.Tail, 1)
			else
				star.Offset += star.Dir * cfg.Speed * dt
				local fade = math.clamp(math.min(star.Age / STAR_FADE_IN, (star.Life - star.Age) / STAR_FADE_OUT), 0, 1)
				local head = eye + star.Offset
				setTransparency(star.Head, 1 - fade * 0.95)
				setTransparency(star.Tail, 1 - fade * 0.6)
				queue(star.Head, CFrame.new(head))
				queue(star.Tail, CFrame.lookAt(head - star.Dir * (cfg.Length / 2), head))
			end
		end
	end
end

-- Ptérosaure en silhouette : corps, deux ailes, tête et crête (regarde vers -Z)
local function buildBird(parent: Instance, index: number): Bird
	local cfg = Ambience.Sky.Birds
	local s = BIRD_SCALE
	local color = cfg.Color
	local parts = {
		newPart(parent, Vector3.new(0.9, 0.7, 3.2) * s, color, false), -- corps
		newPart(parent, Vector3.new(5.2, 0.25, 1.8) * s, color, false), -- aile gauche
		newPart(parent, Vector3.new(5.2, 0.25, 1.8) * s, color, false), -- aile droite
		newPart(parent, Vector3.new(0.55, 0.55, 2) * s, color, false), -- tête et bec
		newPart(parent, Vector3.new(0.3, 0.9, 1.4) * s, color, false), -- crête
	}
	local seed = Random.new(index * 7919)
	return {
		Parts = parts,
		Radius = range({ cfg.Radius[1], cfg.Radius[2] }),
		Height = range({ cfg.Height[1], cfg.Height[2] }),
		Speed = range({ cfg.Speed[1], cfg.Speed[2] }) * (if index % 2 == 0 then -1 else 1),
		Angle = seed:NextNumber() * TAU,
		Center = Vector3.new(seed:NextNumber() * 60 - 30, 0, seed:NextNumber() * 60 - 30),
		Fade = 0,
	}
end

local function updateBirds(dt: number, eye: Vector3, parent: Instance)
	local cfg = Ambience.Sky.Birds
	local want = math.clamp(math.floor(current.Birds + 0.5), 0, cfg.Pool)
	if want > 0 then
		while #birds < want do
			table.insert(birds, buildBird(parent, #birds + 1))
		end
	end
	local s = BIRD_SCALE
	for index, bird in birds do
		local goal = if index <= want then 1 else 0
		if bird.Fade ~= goal then
			bird.Fade = if goal > bird.Fade then math.min(goal, bird.Fade + BIRD_FADE * dt) else math.max(goal, bird.Fade - BIRD_FADE * dt)
			for _, part in bird.Parts do
				setTransparency(part, 1 - bird.Fade)
			end
		end
		if bird.Fade > 0 then
			bird.Angle += bird.Speed * dt
			local a = bird.Angle
			local center = eye + bird.Center + Vector3.new(0, bird.Height + math.sin(clock * 0.5 + index) * 3, 0)
			local position = center + Vector3.new(math.cos(a), 0, math.sin(a)) * bird.Radius
			local sign = if bird.Speed >= 0 then 1 else -1
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * sign
			local body = CFrame.lookAt(position, position + tangent) * CFrame.Angles(0, 0, math.rad(14) * sign)
			-- battements d'ailes, puis vol plané
			local flap = math.sin(clock * 5 + index * 1.3) * 0.5 * (0.5 + 0.5 * math.sin(clock * 0.6 + index))
			local p = bird.Parts
			queue(p[1], body)
			queue(p[2], body * CFrame.new(-0.4 * s, 0.1 * s, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-2.6 * s, 0, 0.2 * s))
			queue(p[3], body * CFrame.new(0.4 * s, 0.1 * s, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(2.6 * s, 0, 0.2 * s))
			queue(p[4], body * CFrame.new(0, 0.25 * s, -2.3 * s) * CFrame.Angles(math.rad(-8), 0, 0))
			queue(p[5], body * CFrame.new(0, 0.75 * s, -1.6 * s) * CFrame.Angles(math.rad(-35), 0, 0))
		end
	end
end

-- ===================================================================== décor flottant

local function numberAttribute(inst: Instance, name: string, default: number): number
	local value = inst:GetAttribute(name)
	return if type(value) == "number" and value == value and math.abs(value) < 1e4 then value else default
end

local function addFloater(inst: Instance)
	if not inst:IsA("Model") or floaters[inst] then
		return
	end
	local cfg = Ambience.Float
	floaters[inst] = {
		Model = inst,
		Base = nil, -- position de repos, lue quand la pièce centrale est là (StreamingEnabled)
		Height = numberAttribute(inst, "FloatHeight", cfg.Height),
		Speed = numberAttribute(inst, "FloatSpeed", cfg.Speed),
		Spin = numberAttribute(inst, "FloatSpin", cfg.Spin),
		Phase = 0,
	}
end

local function removeFloater(inst: Instance)
	floaters[inst] = nil
end

local function updateFloaters(eye: Vector3)
	local rangeSq = Ambience.Float.Range ^ 2
	moving = 0
	for inst, f in floaters do
		if not inst.Parent then
			floaters[inst] = nil
			continue
		end
		local saved = f.Base
		local base: CFrame
		if saved then
			base = saved
		else
			-- le modèle peut arriver avant sa pièce centrale : on attend qu'elle soit là pour lire sa position
			if not f.Model.PrimaryPart then
				continue
			end
			base = f.Model:GetPivot()
			f.Base = base
			f.Phase = (base.Position.X * 0.13 + base.Position.Z * 0.071) % TAU
		end
		local offset = base.Position - eye
		if offset.X * offset.X + offset.Z * offset.Z <= rangeSq then
			moving += 1
			local bob = math.sin(clock * f.Speed + f.Phase) * f.Height
			f.Model:PivotTo(base * CFrame.new(0, bob, 0) * CFrame.Angles(0, (clock * f.Spin) % TAU, 0))
		end
	end
end

-- ===================================================================== image par image

local function focusOf(camera: Camera): Vector3
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return camera.CFrame.Position
end

local function step(rawDt: number)
	local dt = math.clamp(if rawDt == rawDt then rawDt else 0, 0, MAX_DT)
	clock += dt
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local focus = focusOf(camera)
	AmbienceController.TargetAt(focus.Z, target)
	refreshTimer -= dt
	if refreshTimer <= 0 then
		refreshTimer = REFRESH
		ensureEffects()
	end
	lightingTimer += dt
	if not snapped then
		-- première image : l'ambiance du lieu tout de suite (pas de fondu depuis celle du serveur)
		AmbienceController.Blend(target, target, 0, current)
		snapped = true
		lightingTimer = math.huge
	else
		AmbienceController.Blend(current, target, 1 - math.exp(-Ambience.Response * dt), current)
	end
	if lightingTimer >= 1 / Ambience.LightingRate then
		lightingTimer = 0
		apply(current)
	end
	local parent = ensureFolder(camera)
	local eye = camera.CFrame.Position
	table.clear(moveParts)
	table.clear(moveFrames)
	updateMotes(dt, focus, parent)
	updateAurora(eye, parent)
	updatePlanet(eye, parent)
	updateStars(dt, eye, parent)
	updateBirds(dt, eye, parent)
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	updateFloaters(eye)
end

-- ===================================================================== tests et cycle de vie

-- Ambiance appliquée en ce moment (lecture seule)
function AmbienceController.Current(): Preset
	return current
end

function AmbienceController.Stats(): Stats
	local kinds: { [string]: number } = {}
	local total = 0
	for kind, n in moteCount do
		if n > 0 then
			kinds[kind] = n
			total += n
		end
	end
	local starCount, birdCount, floaterCount = 0, 0, 0
	for _, star in stars do
		if star.Active then
			starCount += 1
		end
	end
	for _, bird in birds do
		if bird.Fade > 0 then
			birdCount += 1
		end
	end
	for _ in floaters do
		floaterCount += 1
	end
	return {
		Motes = total,
		Kinds = kinds,
		Aurora = auroraShown,
		Planet = planetShown,
		Stars = starCount,
		Birds = birdCount,
		Floaters = floaterCount,
		Moving = moving,
	}
end

function AmbienceController.Init()
	regions = AmbienceController.Regions()
	target = AmbienceController.Copy(Ambience.Regions.Plaza)
	current = AmbienceController.Copy(Ambience.Regions.Plaza)
end

function AmbienceController.Start()
	local tag = Ambience.Float.Tag
	for _, inst in CollectionService:GetTagged(tag) do
		addFloater(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(addFloater)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removeFloater)
	RunService:BindToRenderStep("Ambience", Enum.RenderPriority.Camera.Value + 5, step)
end

return AmbienceController
