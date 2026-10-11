--!strict
-- FossilBlockController (brief 9 « blocs-hybrides ») : habille chez le client les blocs de fossiles du serveur (des cubes
-- de la couleur de leur rareté) avec les modèles en briques de BlockModels et les effets de leur rareté.
--
-- Contrat : une BasePart nommée
--   FossilBlock    bloc posé sur un gisement (DigSiteService)
--   DroppedFossil  bloc lâché au sol (DroppedBlockService)
--   CarriedFossil  bloc porté sur le dos (CarryService) : tourné, son crâne regarde derrière le joueur et ses cristaux
--                  s'éloignent de lui
--   TankBlock      bloc dans une cuve du parc (ReviveService)
-- avec l'attribut Rarity (Common ... Secret). BlockId (facultatif) tourne le bloc d'un quart de tour : les gisements
-- ne montrent pas tous la même face. La pièce du serveur garde son prompt et ses attributs ; elle est seulement cachée
-- chez le client (LocalTransparencyModifier) tant que son modèle est construit. Au loin, ou si la rareté est inconnue,
-- le cube coloré du serveur reste visible : c'est le modèle simplifié.
--
-- Le modèle est construit près de la caméra et défait au loin. Effets de la rareté (BlockModels.Looks), toujours en
-- cubes nets comme ceux des dinos : cubes lumineux qui montent, paillettes, aura de cubes qui tournent, lave et
-- cristaux qui battent, braises (Mythic), arc-en-ciel qui tourne (Secret). Les effets vivent seulement près et à
-- l'écran ; la colonne de cubes du Secret se voit de loin (sauf sur son propre dos : elle cacherait la vue).
-- StreamingEnabled : une pièce qui repart est oubliée (son modèle défait), une pièce qui revient est rhabillée.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlockModels = require(ReplicatedStorage.Shared.BlockModels)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local FossilBlockController = {}

-- noms des pièces de bloc posées par le serveur
FossilBlockController.Names = {
	FossilBlock = true,
	DroppedFossil = true,
	CarriedFossil = true,
	TankBlock = true,
} :: { [string]: boolean }

local BUILD, DROP = 170, 210 -- studs (pour un bloc de 3) : modèle construit en deçà, défait au-delà
local FX_NEAR = 110 -- effets complets en deçà (et à l'écran)
local CHECK_EVERY = 0.2 -- secondes entre deux tris par distance
local SPARK_MAX, GLINT_MAX = 10, 8
local BEAM_SEGMENTS, BEAM_STEP, BEAM_WIDTH = 9, 6, 1.1 -- colonne du Secret

type Spark = { Part: Part, Age: number, Life: number, Pos: Vector3, Vel: Vector3, Spin: number, Size: number, Hue: number }
type Glint = { Part: Part, Age: number, Life: number, At: CFrame, Size: number }

type Entry = {
	Part: BasePart,
	Rarity: string?,
	Look: BlockModels.Look?,
	Color: Color3,
	Light: Color3,
	Size: number, -- côté du bloc en studs
	Turn: CFrame, -- rotation du modèle dans le repère de la pièce
	Moving: boolean, -- suit la pièce à chaque image (bloc porté)
	Own: boolean, -- porté par le joueur local
	Base: CFrame,
	Dist: number,
	Dirty: boolean,
	Model: Model?,
	Parts: { BasePart },
	Offsets: { CFrame },
	Out: { CFrame },
	Glow: { BasePart },
	Gems: { BasePart },
	GemHue: { number },
	Rainbow: { BasePart },
	RainbowY: { number },
	Fx: Folder?,
	Orbit: { BasePart },
	OrbitOut: { CFrame },
	Sparks: { Spark },
	Glints: { Glint },
	Beam: { BasePart },
	BeamOut: { CFrame },
	BeamFolder: Folder?,
	SparkAcc: number,
	GlintAcc: number,
	Clock: number,
	Lit: boolean,
	Conns: { RBXScriptConnection },
}

local entries: { [BasePart]: Entry } = {}
local folder: Folder? = nil
local started = false

local function hue(h: number): Color3
	return Color3.fromHSV(h % 1, 0.7, 1)
end

local function fxPart(name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	return p
end

local function sizeOf(part: BasePart): number
	local s = part.Size
	return math.max(s.X, s.Y, s.Z)
end

-- Rotation du modèle : le bloc porté est retourné (crâne vers l'arrière), les autres tournent d'un quart de tour par
-- BlockId pour varier les gisements
local function turnOf(part: BasePart): CFrame
	if part.Name == "CarriedFossil" then
		return CFrame.Angles(0, math.pi, 0)
	end
	local id = part:GetAttribute("BlockId")
	local quarter = if type(id) == "number" and id == id and math.abs(id) < 1e9 then math.floor(id) % 4 else 0
	return CFrame.Angles(0, quarter * math.pi / 2, 0)
end

local function isOwn(part: BasePart): boolean
	local me = Players.LocalPlayer
	local character = me and me.Character
	return character ~= nil and part:IsDescendantOf(character)
end

-- ====================================================================== effets

local function clearFx(e: Entry)
	if e.Fx then
		e.Fx:Destroy()
		e.Fx = nil
	end
	table.clear(e.Orbit)
	table.clear(e.OrbitOut)
	table.clear(e.Sparks)
	table.clear(e.Glints)
	e.Lit = true
end

local function buildFx(e: Entry)
	clearFx(e)
	local look = e.Look
	if not (look and e.Model and folder) then
		return
	end
	local fx = Instance.new("Folder")
	fx.Name = "Fx"
	local s = e.Size / BlockModels.Size
	-- aura : cubes qui tournent autour du bloc (pas sur le dos d'un joueur : ils le traverseraient)
	if not e.Moving then
		local cube = 0.3 * s
		for _ = 1, look.Orbit do
			local p = fxPart("Aura", Vector3.new(cube, cube, cube), e.Color)
			p.Parent = fx
			table.insert(e.Orbit, p)
			table.insert(e.OrbitOut, CFrame.identity)
		end
	end
	fx.Parent = e.Model
	e.Fx = fx
end

local function clearBeam(e: Entry)
	if e.BeamFolder then
		e.BeamFolder:Destroy()
		e.BeamFolder = nil
	end
	table.clear(e.Beam)
	table.clear(e.BeamOut)
end

-- Colonne de cubes vers le ciel (Secret) : se voit de loin, même quand le modèle n'est pas construit
local function buildBeam(e: Entry)
	clearBeam(e)
	local look = e.Look
	if not (look and look.Beam and not e.Own and folder) then
		return
	end
	local beam = Instance.new("Folder")
	beam.Name = "Beam"
	for k = 1, BEAM_SEGMENTS do
		local p = fxPart("Beam", Vector3.new(BEAM_WIDTH, BEAM_STEP * 0.7, BEAM_WIDTH), hue(k / BEAM_SEGMENTS))
		p.Transparency = 0.3 + 0.55 * (k - 1) / (BEAM_SEGMENTS - 1)
		p.Parent = beam
		table.insert(e.Beam, p)
		table.insert(e.BeamOut, CFrame.identity)
	end
	beam.Parent = folder
	e.BeamFolder = beam
end

local function stepBeam(e: Entry, t: number)
	local top = e.Part.Position + Vector3.new(0, e.Size * 0.5 + 1, 0)
	for k, _ in e.Beam do
		e.BeamOut[k] = CFrame.new(top + Vector3.new(0, (k - 0.5) * BEAM_STEP, 0)) * CFrame.Angles(0, t * 0.6 + k * 0.35, 0)
	end
	Workspace:BulkMoveTo(e.Beam, e.BeamOut, Enum.BulkMoveMode.FireCFrameChanged)
	for k, p in e.Beam do
		p.Color = hue(k / BEAM_SEGMENTS - t * 0.15)
	end
end

local function hideShortLived(e: Entry)
	if not e.Lit then
		return
	end
	for _, sp in e.Sparks do
		sp.Part.Transparency = 1
		sp.Age = sp.Life
	end
	for _, g in e.Glints do
		g.Part.Transparency = 1
		g.Age = g.Life
	end
	e.Lit = false
end

-- Aura, lave et cristaux qui battent, arc-en-ciel : quand le bloc est à l'écran ; cubes qui montent, braises et
-- paillettes : seulement près (full)
local function stepFx(e: Entry, dt: number, full: boolean)
	local look = e.Look
	if not look then
		return
	end
	e.Clock += dt
	local t = e.Clock
	local base = e.Base
	local s = e.Size / BlockModels.Size
	local n = #e.Orbit
	if n > 0 then
		for k = 1, n do
			local ang = t * 1.1 + (k - 1) / n * 2 * math.pi
			local r = e.Size * 0.95
			local y = e.Size * (0.05 + 0.2 * math.sin(t * 1.7 + k))
			e.OrbitOut[k] = base * CFrame.new(r * math.cos(ang), y, r * math.sin(ang)) * CFrame.Angles(t * 1.3 + k, t * 1.9, 0)
		end
		Workspace:BulkMoveTo(e.Orbit, e.OrbitOut, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if look.Pulse then
		local w = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.1)
		for _, p in e.Glow do
			p.Transparency = 0.4 * w
		end
		for _, p in e.Gems do
			p.Transparency = 0.25 * w
		end
	end
	if look.Rainbow then
		-- les couches montent, les cristaux et l'aura changent de couleur chacun leur tour
		for i, p in e.Rainbow do
			p.Color = hue(e.RainbowY[i] * 0.9 - t * 0.15)
		end
		for i, p in e.Gems do
			p.Color = hue(e.GemHue[i] + t * 0.15)
		end
		for i, p in e.Orbit do
			p.Color = hue(i / math.max(1, n) + t * 0.25)
		end
	end
	if not full then
		hideShortLived(e)
		return
	end
	e.Lit = true
	local half = e.Size / 2
	-- cubes lumineux qui montent du dessus (braises qui vacillent pour Mythic)
	if look.Rise > 0 then
		e.SparkAcc += dt * look.Rise
		while e.SparkAcc >= 1 do
			e.SparkAcc -= 1
			local free: Spark? = nil
			for _, sp in e.Sparks do
				if sp.Age >= sp.Life then
					free = sp
					break
				end
			end
			if not free and #e.Sparks < SPARK_MAX and e.Fx then
				local p = fxPart("Spark", Vector3.one, e.Color)
				p.Transparency = 1
				p.Parent = e.Fx
				local created: Spark = { Part = p, Age = 1, Life = 1, Pos = Vector3.zero, Vel = Vector3.zero, Spin = 0, Size = 0.2, Hue = 0 }
				table.insert(e.Sparks, created)
				free = created
			end
			if free then
				local loc = Vector3.new((math.random() - 0.5) * 1.6 * half, half * (0.7 + 0.4 * math.random()), (math.random() - 0.5) * 1.6 * half)
				free.Pos = (base * CFrame.new(loc)).Position
				free.Vel = Vector3.new((math.random() - 0.5) * 0.5, 1.3 + math.random() * 1.1, (math.random() - 0.5) * 0.5) * s
				free.Age = 0
				free.Life = 0.9 + math.random() * 0.7
				free.Spin = (math.random() - 0.5) * 6
				free.Size = (0.18 + math.random() * 0.16) * s
				free.Hue = math.random()
				free.Part.Color = if look.Rainbow then hue(free.Hue) else e.Light
			end
		end
	end
	for _, sp in e.Sparks do
		if sp.Age < sp.Life then
			sp.Age += dt
			sp.Pos += sp.Vel * dt
			local k = math.clamp(sp.Age / sp.Life, 0, 1)
			local size = sp.Size * (1 - 0.6 * k)
			sp.Part.Size = Vector3.new(size, size, size)
			local fade = 0.1 + 0.9 * k * k
			if look.Flicker then
				fade = math.min(1, fade + 0.35 * math.random())
				sp.Part.Color = if math.random() < 0.5 then e.Color else e.Light
			elseif look.Rainbow then
				sp.Part.Color = hue(sp.Hue + t * 0.3)
			end
			sp.Part.Transparency = if k >= 1 then 1 else fade
			sp.Part.CFrame = CFrame.new(sp.Pos) * CFrame.Angles(sp.Age * sp.Spin, sp.Age * sp.Spin * 0.7, 0)
		end
	end
	-- paillettes : petits losanges clairs qui scintillent sur le dessus et les flancs de la roche
	if look.Glint > 0 then
		e.GlintAcc += dt * look.Glint
		while e.GlintAcc >= 1 do
			e.GlintAcc -= 1
			local free: Glint? = nil
			for _, g in e.Glints do
				if g.Age >= g.Life then
					free = g
					break
				end
			end
			if not free and #e.Glints < GLINT_MAX and e.Fx then
				local p = fxPart("Glint", Vector3.one, e.Light)
				p.Transparency = 1
				p.Parent = e.Fx
				local created: Glint = { Part = p, Age = 1, Life = 1, At = CFrame.identity, Size = 0.2 }
				table.insert(e.Glints, created)
				free = created
			end
			if free then
				local u, v = (math.random() - 0.5) * 1.5 * half, (math.random() - 0.5) * 1.5 * half
				local face = math.random(1, 5)
				local out = half + 0.03
				local loc = if face == 1
					then Vector3.new(u, out, v)
					elseif face == 2 then Vector3.new(out, u, v)
					elseif face == 3 then Vector3.new(-out, u, v)
					elseif face == 4 then Vector3.new(u, v, out)
					else Vector3.new(u, v, -out)
				free.At = base * CFrame.new(loc) * CFrame.Angles(0, math.random() * math.pi, math.pi / 4)
				free.Age = 0
				free.Life = 0.35 + math.random() * 0.25
				free.Size = (0.14 + math.random() * 0.1) * s
				free.Part.Color = if look.Rainbow then hue(math.random()) else e.Light
			end
		end
	end
	for _, g in e.Glints do
		if g.Age < g.Life then
			g.Age += dt
			local k = math.clamp(g.Age / g.Life, 0, 1)
			local size = g.Size * math.sin(math.pi * k)
			if k >= 1 or size <= 0.01 then
				g.Part.Transparency = 1
			else
				g.Part.Transparency = 0.05
				g.Part.Size = Vector3.new(size, size, size)
				g.Part.CFrame = g.At * CFrame.Angles(0, k * 1.5, 0)
			end
		end
	end
end

-- ====================================================================== modèles

local function place(e: Entry)
	e.Base = e.Part.CFrame * e.Turn
	for i, offset in e.Offsets do
		e.Out[i] = e.Base * offset
	end
	if #e.Parts > 0 then
		Workspace:BulkMoveTo(e.Parts, e.Out, Enum.BulkMoveMode.FireCFrameChanged)
	end
	e.Dirty = false
end

local function unbuild(e: Entry)
	clearFx(e)
	if e.Model then
		e.Model:Destroy()
		e.Model = nil
	end
	table.clear(e.Parts)
	table.clear(e.Offsets)
	table.clear(e.Out)
	table.clear(e.Glow)
	table.clear(e.Gems)
	table.clear(e.GemHue)
	table.clear(e.Rainbow)
	table.clear(e.RainbowY)
	if e.Part.Parent then
		e.Part.LocalTransparencyModifier = 0
	end
end

local function build(e: Entry)
	unbuild(e)
	if not folder then
		return
	end
	local model = BlockModels.Build(e.Rarity, e.Size)
	if not model then
		return
	end
	local data = BlockModels.Get(e.Rarity)
	local gems = if data then math.max(1, data.Gems) else 1
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(e.Parts, p)
			table.insert(e.Offsets, p.CFrame)
			table.insert(e.Out, p.CFrame)
			if p.Name == "Glow" then
				table.insert(e.Glow, p)
			elseif p.Name == "Gem" then
				table.insert(e.Gems, p)
				local index = p:GetAttribute("Gem")
				table.insert(e.GemHue, (if type(index) == "number" then index else 1) / gems)
			elseif p.Name == "Rainbow" then
				table.insert(e.Rainbow, p)
				table.insert(e.RainbowY, p.CFrame.Position.Y / e.Size + 0.5)
			end
		end
	end
	model.Name = e.Part.Name .. "Model"
	e.Model = model
	place(e)
	model.Parent = folder
	e.Part.LocalTransparencyModifier = 1
	buildFx(e)
end

-- Rareté (et apparence) relues sur la pièce : refait le modèle et la colonne
local function refresh(e: Entry)
	local rarity = e.Part:GetAttribute("Rarity")
	local look = if type(rarity) == "string" and BlockModels.Get(rarity) then BlockModels.Looks[rarity] else nil
	e.Rarity = if look then rarity :: string else nil
	e.Look = look
	local info = if look then Rarity.Info[look.Name] else nil
	e.Color = if info then info.Color else Color3.fromRGB(200, 200, 200)
	e.Light = e.Color:Lerp(Color3.new(1, 1, 1), 0.55)
	e.Size = sizeOf(e.Part)
	e.Turn = turnOf(e.Part)
	e.Own = e.Moving and isOwn(e.Part)
	local wasBuilt = e.Model ~= nil
	unbuild(e)
	buildBeam(e)
	if wasBuilt and look then
		build(e)
	end
end

local function untrack(part: BasePart)
	local e = entries[part]
	if not e then
		return
	end
	entries[part] = nil
	for _, c in e.Conns do
		c:Disconnect()
	end
	unbuild(e)
	clearBeam(e)
end

local function track(part: BasePart)
	if entries[part] or not FossilBlockController.Names[part.Name] or not part:IsDescendantOf(Workspace) then
		return
	end
	local e: Entry = {
		Part = part,
		Rarity = nil,
		Look = nil,
		Color = Color3.new(1, 1, 1),
		Light = Color3.new(1, 1, 1),
		Size = sizeOf(part),
		Turn = CFrame.identity,
		Moving = part.Name == "CarriedFossil",
		Own = false,
		Base = part.CFrame,
		Dist = math.huge,
		Dirty = true,
		Model = nil,
		Parts = {},
		Offsets = {},
		Out = {},
		Glow = {},
		Gems = {},
		GemHue = {},
		Rainbow = {},
		RainbowY = {},
		Fx = nil,
		Orbit = {},
		OrbitOut = {},
		Sparks = {},
		Glints = {},
		Beam = {},
		BeamOut = {},
		BeamFolder = nil,
		SparkAcc = 0,
		GlintAcc = 0,
		Clock = math.random() * 10,
		Lit = true,
		Conns = {},
	}
	entries[part] = e
	refresh(e)
	table.insert(e.Conns, part:GetAttributeChangedSignal("Rarity"):Connect(function()
		refresh(e)
	end))
	table.insert(e.Conns, part:GetAttributeChangedSignal("BlockId"):Connect(function()
		e.Turn = turnOf(part)
		e.Dirty = true
	end))
	table.insert(e.Conns, part:GetPropertyChangedSignal("CFrame"):Connect(function()
		e.Dirty = true
	end))
	table.insert(e.Conns, part:GetPropertyChangedSignal("Size"):Connect(function()
		refresh(e)
	end))
	-- la pièce quitte le jeu (arrachée, rendue, streaming out) : modèle défait
	table.insert(e.Conns, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) then
			untrack(part)
		end
	end))
end

local checkAcc = 0
local beamClock = 0

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	beamClock += dt
	checkAcc += dt
	local check = checkAcc >= CHECK_EVERY
	if check then
		checkAcc = 0
	end
	for part, e in entries do
		if check then
			local scale = math.max(e.Size / BlockModels.Size, 0.5)
			e.Dist = (part.Position - camPos).Magnitude / scale
			if not e.Model and e.Look and e.Dist < BUILD then
				build(e)
			elseif e.Model and e.Dist > DROP then
				unbuild(e)
			end
			if e.Model and part.LocalTransparencyModifier ~= 1 then
				-- (les scripts de caméra remettent à 0 les pièces du personnage quand on zoome)
				part.LocalTransparencyModifier = 1
			end
		end
		if e.Model then
			if e.Moving or e.Dirty then
				place(e)
			end
			local onScreen = true
			if cam then
				local _, visible = cam:WorldToViewportPoint(part.Position)
				onScreen = visible
			end
			if onScreen then
				stepFx(e, math.min(dt, 0.1), e.Dist < FX_NEAR)
			else
				hideShortLived(e)
			end
		end
		if #e.Beam > 0 then
			stepBeam(e, beamClock)
		end
	end
end

-- Pièces de bloc suivies, avec leur modèle construit chez ce client (nil s'il ne l'est pas) : tests et debug
function FossilBlockController.Tracked(): { [BasePart]: Model | false }
	local out: { [BasePart]: Model | false } = {}
	for part, e in entries do
		out[part] = e.Model or false
	end
	return out
end

-- Fait un tri par distance tout de suite (tests) : construit ou défait les modèles
function FossilBlockController.Refresh()
	checkAcc = CHECK_EVERY
	update(0)
end

function FossilBlockController.Init()
	local f = Instance.new("Folder")
	f.Name = "FossilBlockModels" -- modèles construits chez ce client (jamais répliqués)
	f.Parent = Workspace
	folder = f
end

function FossilBlockController.Start()
	if started then
		return
	end
	started = true
	Workspace.DescendantAdded:Connect(function(inst: Instance)
		if inst:IsA("BasePart") and FossilBlockController.Names[inst.Name] then
			track(inst)
		end
	end)
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("BasePart") and FossilBlockController.Names[inst.Name] then
			track(inst)
		end
	end
	RunService.RenderStepped:Connect(update)
end

return FossilBlockController
