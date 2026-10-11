--!strict
-- DinoAnimController : joue les animations des dinos côté client (lecteur des données de DinoBuilder).
--
-- Contrat (serveur ou client) : un Model tagué "Dino" (DinoBuilder.Tag) avec les attributs
--   Species (string)         espèce (module de src/shared/DinoModels) ou clé enregistrée (hybride)
--   Scale (number)           échelle construite (taille x gardien), voir DinoBuilder.ScaleOf
--   Mutation, Level          (facultatifs) apparence
--   State (string)           état à jouer : Idle, Walk, Run, Happy, Roar, Eat, Sleep, Spawn, Wake, Catch, Search,
--                            Return, BackToSleep, Fusion, Index (+ TakeOff, Fly, Glide, Land pour les volants,
--                            Dive, Jump pour les nageurs). Un état absent retombe sur un proche puis sur Idle.
--   StateAt (number)         (facultatif) workspace:GetServerTimeNow() du début de l'état : même phase chez tous
--   Speed (number)           (facultatif) vitesse de déplacement en studs/s : la marche se cale dessus (pas de glisse)
--   AlwaysAnimate (boolean)  (facultatif) pour les ViewportFrame (Index) : pas de coupure à distance ou hors écran
--   Rarity (string)          (facultatif) Common ... Secret ; sans lui, la rareté de l'espèce (Config.Rarity.Species).
--                            Effets qui s'empilent avec la rareté : anneau de briques au sol de la couleur de la rareté,
--                            cubes lumineux qui montent, paillettes qui scintillent sur le corps, aura de cubes qui
--                            tournent, couronne au-dessus de la tête, braises (Mythic), arc-en-ciel (Secret)
-- Si le modèle n'a que sa pièce "Root" (DinoBuilder.CreateProxy), les briques sont construites ici, chez le client.
--
-- Fondus de 0,2 s entre états, variantes d'Idle au hasard, cadence plus lente pour les gros, animation complète
-- près de la caméra, cadence réduite au loin, figée hors de vue. DinoAnimController.Event : (model, nom, os) pour
-- les effets liés aux pas, au rugissement et à l'impact (seulement pour les dinos proches).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DinoBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DinoBuilder"))

local DinoAnimController = {}

local FADE = 0.2
local NEAR, MID, FAR, CULL = 70, 140, 260, 420 -- studs, multipliés par la taille du dino
local IDLE_VARIANTS = { "IdleSniff", "IdleScratch", "IdleStretch", "IdleShake", "IdleYawn" }
local FALLBACK: { [string]: { string } } = {
	Return = { "Walk" },
	Run = { "Walk" },
	Fly = { "Glide", "Walk" },
	Glide = { "Fly", "Walk" },
	TakeOff = { "Fly", "Walk" },
	Land = { "Idle" },
	Dive = { "Walk" },
	Jump = { "Happy" },
	Wake = { "Idle" },
	BackToSleep = { "Sleep" },
	Search = { "Idle" },
	Catch = { "Roar" },
}

type Spark = { Part: Part, Age: number, Life: number, Pos: Vector3, Vel: Vector3, Spin: number, Size: number, Hue: number }
type Glint = { Part: Part, Age: number, Life: number, At: CFrame, Size: number, Hue: number }

type Fx = {
	Look: DinoBuilder.RarityLook,
	Color: Color3,
	Light: Color3,
	Folder: Model,
	Parts: { BasePart }, -- anneau, aura, couronne (posés ensemble)
	Rest: { CFrame },
	Out: { CFrame },
	RingCount: number,
	OrbCount: number,
	Sparks: { Spark },
	Spawn: number,
	Glints: { Glint },
	GlintSpawn: number,
	Clock: number,
	A: number,
	B: number,
	Height: number,
	Scale: number,
	HeadPivot: Vector3?,
	HaloRadius: number,
	Lit: boolean,
}

type Dino = {
	Model: Model,
	Data: DinoBuilder.Data,
	Rig: DinoBuilder.Rig,
	Local: Model?, -- briques construites ici (modèle proxy)
	Root: BasePart,
	Base: CFrame, -- repère affiché (lissé)
	Clip: DinoBuilder.Clip,
	ClipName: string,
	Time: number,
	Rate: number,
	State: string,
	From: DinoBuilder.Pose?,
	Fade: number,
	Pose: DinoBuilder.Pose,
	Mix: DinoBuilder.Pose,
	Last: DinoBuilder.Pose,
	Acc: number,
	Phase: number,
	NextVariant: number,
	Radius: number,
	Fx: Fx?,
	Conns: { RBXScriptConnection },
}

local dinos: { [Model]: Dino } = {}
local eventBindable = Instance.new("BindableEvent")
DinoAnimController.Event = eventBindable.Event

local function clipFor(data: DinoBuilder.Data, state: string): (string, DinoBuilder.Clip?)
	local c = data.Clips[state]
	if c then
		return state, c
	end
	local alts = FALLBACK[state]
	if alts then
		for _, alt in alts do
			if data.Clips[alt] then
				return alt, data.Clips[alt]
			end
		end
	end
	return "Idle", data.Clips.Idle
end

-- cadence : les gros sont plus lents et plus lourds ; une marche se cale sur la vitesse réelle
local function rateFor(d: Dino, clip: DinoBuilder.Clip): number
	local scale = d.Rig.Scale
	local speed = d.Model:GetAttribute("Speed")
	if clip.Speed and type(speed) == "number" and speed > 0.05 then
		return math.clamp(speed / (clip.Speed * scale), 0.35, 3)
	end
	return scale ^ -0.3
end

local function play(d: Dino, name: string, startTime: number?)
	local clipName, clip = clipFor(d.Data, name)
	if not clip then
		return
	end
	d.From = DinoBuilder.Copy(d.Last, d.From)
	d.Fade = 0
	d.Clip = clip
	d.ClipName = clipName
	d.Time = startTime or 0
	d.Rate = rateFor(d, clip)
	if clipName == "Idle" then
		d.NextVariant = 6 + math.random() * 8
	end
end

local function onState(d: Dino)
	local state = d.Model:GetAttribute("State")
	if type(state) ~= "string" then
		state = "Idle"
	end
	d.State = state :: string
	local at = d.Model:GetAttribute("StateAt")
	local start = 0
	if type(at) == "number" then
		start = math.max(0, workspace:GetServerTimeNow() - at)
	end
	play(d, state :: string, start)
end

local function fire(d: Dino, t0: number, t1: number)
	for _, ev in d.Clip.Events do
		local t = ev[1] :: number
		if t > t0 and t <= t1 then
			eventBindable:Fire(d.Model, ev[2], ev[3])
		end
	end
end

-- ====================================================================== rareté
local SPARK_MAX, GLINT_MAX = 16, 20

-- couleurs et rareté des espèces : Config.Rarity (blocs de fossiles, brief boucle) quand il est là
local Config: any = nil
do
	local module = ReplicatedStorage:WaitForChild("Shared"):FindFirstChild("Config")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			Config = result
		end
	end
end

local function lookup(fn: () -> any): any
	if not Config then
		return nil
	end
	local ok, value = pcall(fn)
	return if ok then value else nil
end

-- Rareté affichée : attribut Rarity, sinon celle de l'espèce
local function rarityOf(model: Model): string?
	local attr = model:GetAttribute("Rarity")
	if type(attr) == "string" then
		return attr
	end
	local species = model:GetAttribute("Species")
	if type(species) ~= "string" then
		return nil
	end
	local rarity = lookup(function()
		local def = Config.Species.ByModel[species]
		return Config.Rarity.Species[if def then def.Name else species]
	end)
	return if type(rarity) == "string" then rarity else nil
end

local function fxPart(name: string, size: Vector3, color: Color3, neon: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
	p.TopSurface = if neon then Enum.SurfaceType.Smooth else Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function clearFx(d: Dino)
	local fx = d.Fx
	if fx then
		fx.Folder:Destroy()
		d.Fx = nil
	end
end

local function buildFx(d: Dino)
	clearFx(d)
	local name = rarityOf(d.Model)
	local look = if name then DinoBuilder.RarityByName[name] else nil
	if not look then
		return
	end
	local color = lookup(function()
		return Config.Rarity.Info[look.Name].Color
	end)
	if typeof(color) ~= "Color3" then
		color = look.Color
	end
	local scale = d.Rig.Scale
	local folder = Instance.new("Model")
	folder.Name = "RarityFx"
	local parts: { BasePart } = {}
	local rest: { CFrame } = {}
	local segments = DinoBuilder.RingSegments(d.Data, scale)
	for i, seg in segments do
		local p = fxPart("Ring", seg[2], color, look.Neon)
		p.Parent = folder
		parts[i] = p
		rest[i] = seg[1]
	end
	local cube = 0.7 * math.sqrt(scale)
	for _ = 1, look.Orbiters do
		local p = fxPart("Aura", Vector3.new(cube, cube, cube), color, true)
		p.Parent = folder
		table.insert(parts, p)
		table.insert(rest, CFrame.identity)
	end
	local gem = 0.38 * math.sqrt(scale)
	for _ = 1, look.Halo do
		local p = fxPart("Crown", Vector3.new(gem, gem, gem), color, true)
		p.Parent = folder
		table.insert(parts, p)
		table.insert(rest, CFrame.identity)
	end
	local headPivot: Vector3? = nil
	for _, bone in d.Data.Bones do
		if bone.Name == "Head" then
			headPivot = bone.Pivot * scale
		end
	end
	local a, b = DinoBuilder.RingShape(d.Data, scale)
	folder.Parent = d.Local or d.Model
	d.Fx = {
		Look = look,
		Color = color,
		Light = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Folder = folder,
		Parts = parts,
		Rest = rest,
		Out = table.create(#parts, CFrame.identity),
		RingCount = #segments,
		OrbCount = look.Orbiters,
		Sparks = {},
		Spawn = 0,
		Glints = {},
		GlintSpawn = 0,
		Clock = math.random() * 10,
		A = a,
		B = b,
		Height = d.Data.Height * scale,
		Scale = scale,
		HeadPivot = headPivot,
		HaloRadius = math.clamp(0.13 * d.Data.Height * scale, 0.6, 4),
		Lit = true,
	}
end

local function hue(h: number): Color3
	return Color3.fromHSV(h % 1, 0.7, 1)
end

-- Anneau, aura et couronne suivent le dino ; cubes, paillettes et braises seulement quand il est proche (full)
local function stepFx(d: Dino, dt: number, full: boolean)
	local fx = d.Fx
	if not fx then
		return
	end
	local look = fx.Look
	fx.Clock += dt
	local t = fx.Clock
	local base = d.Base
	local s = math.sqrt(fx.Scale)
	-- anneau de briques (bat pour Mythic et Secret)
	local pulse = if look.Pulse then math.sin(t * 2 * math.pi * 1.6) else 0
	for i = 1, fx.RingCount do
		local r = fx.Rest[i]
		if look.Pulse then
			local out = Vector3.new(r.Position.X, 0, r.Position.Z).Unit
			fx.Out[i] = base * (CFrame.new(out * 0.18 * fx.Scale * pulse) * r)
		else
			fx.Out[i] = base * r
		end
	end
	-- aura : cubes qui tournent autour du corps
	local n = fx.OrbCount
	for k = 1, n do
		local ang = t * 0.8 + (k - 1) / n * 2 * math.pi
		local y = fx.Height * (0.45 + 0.08 * math.sin(t * 2 + k))
		local pos = Vector3.new(fx.A * 0.8 * math.cos(ang), y, fx.B * 0.8 * math.sin(ang))
		fx.Out[fx.RingCount + k] = base * CFrame.new(pos) * CFrame.Angles(t * 1.3 + k, t * 1.7, 0)
	end
	-- couronne : petits cubes en losange qui tournent au-dessus de la tête (suit la tête quand elle bouge)
	local first = fx.RingCount + n + 1
	local count = #fx.Parts - first + 1
	if count > 0 then
		local head = d.Rig.Solved.Head
		local hp = fx.HeadPivot
		local center = if head and hp
			then (base * head * hp) + Vector3.new(0, 0.3 * fx.Height, 0)
			else (base * CFrame.new(0, fx.Height * 1.15, 0)).Position
		for k = 0, count - 1 do
			local ang = t * 1.2 + k / count * 2 * math.pi
			local pos = center + Vector3.new(fx.HaloRadius * math.cos(ang), 0.12 * s * math.sin(t * 3 + k), fx.HaloRadius * math.sin(ang))
			fx.Out[first + k] = CFrame.new(pos) * CFrame.Angles(0, -ang, math.pi / 4)
		end
	end
	workspace:BulkMoveTo(fx.Parts, fx.Out, Enum.BulkMoveMode.FireCFrameChanged)
	if look.Rainbow and full then
		for i, p in fx.Parts do
			p.Color = hue(t * 0.25 + i / #fx.Parts)
		end
	elseif look.Pulse and full then
		for i = 1, fx.RingCount do
			fx.Parts[i].Transparency = 0.15 + 0.15 * pulse
		end
	end
	if not full then
		-- loin : on cache ce qui vit peu de temps
		if fx.Lit then
			for _, sp in fx.Sparks do
				sp.Part.Transparency = 1
				sp.Age = sp.Life
			end
			for _, g in fx.Glints do
				g.Part.Transparency = 1
				g.Age = g.Life
			end
			fx.Lit = false
		end
		return
	end
	fx.Lit = true
	-- cubes lumineux qui montent de l'anneau et du corps (braises qui vacillent pour Mythic)
	if look.Particles > 0 then
		fx.Spawn += dt * look.Particles
		while fx.Spawn >= 1 do
			fx.Spawn -= 1
			local free: Spark? = nil
			for _, sp in fx.Sparks do
				if sp.Age >= sp.Life then
					free = sp
					break
				end
			end
			if not free and #fx.Sparks < SPARK_MAX then
				local p = fxPart("Spark", Vector3.one, fx.Color, true)
				p.Transparency = 1
				p.Parent = fx.Folder
				local created: Spark = { Part = p, Age = 1, Life = 1, Pos = Vector3.zero, Vel = Vector3.zero, Spin = 0, Size = 0.4, Hue = 0 }
				table.insert(fx.Sparks, created)
				free = created
			end
			if free then
				local ang = math.random() * 2 * math.pi
				local fromRing = math.random() < 0.5
				local k = if fromRing then 1 else 0.55 * math.random()
				local y = if fromRing then 0.2 else fx.Height * (0.25 + 0.5 * math.random())
				local loc = Vector3.new(fx.A * k * math.cos(ang), y, fx.B * k * math.sin(ang))
				free.Pos = (base * CFrame.new(loc)).Position
				free.Vel = Vector3.new((math.random() - 0.5) * 0.6, 1.6 + math.random() * 1.4, (math.random() - 0.5) * 0.6) * s
				free.Age = 0
				free.Life = 1.1 + math.random() * 0.8
				free.Spin = (math.random() - 0.5) * 6
				free.Size = (0.4 + math.random() * 0.35) * s
				free.Hue = math.random()
				free.Part.Color = if look.Rainbow then hue(free.Hue) else fx.Color
			end
		end
	end
	for _, sp in fx.Sparks do
		if sp.Age < sp.Life then
			sp.Age += dt
			sp.Pos += sp.Vel * dt
			local k = math.clamp(sp.Age / sp.Life, 0, 1)
			local size = sp.Size * (1 - 0.6 * k)
			sp.Part.Size = Vector3.new(size, size, size)
			local fade = 0.1 + 0.9 * k * k
			if look.Flicker then
				fade = math.min(1, fade + 0.35 * math.random())
				sp.Part.Color = if math.random() < 0.5 then fx.Color else fx.Light
			elseif look.Rainbow then
				sp.Part.Color = hue(sp.Hue + t * 0.3)
			end
			sp.Part.Transparency = if k >= 1 then 1 else fade
			sp.Part.CFrame = CFrame.new(sp.Pos) * CFrame.Angles(sp.Age * sp.Spin, sp.Age * sp.Spin * 0.7, 0)
		end
	end
	-- paillettes : petits losanges clairs qui scintillent sur le dessus des briques du corps
	local bodyParts = d.Rig.Parts
	if look.Glitter > 0 and #bodyParts > 0 then
		fx.GlintSpawn += dt * look.Glitter
		while fx.GlintSpawn >= 1 do
			fx.GlintSpawn -= 1
			local free: Glint? = nil
			for _, g in fx.Glints do
				if g.Age >= g.Life then
					free = g
					break
				end
			end
			if not free and #fx.Glints < GLINT_MAX then
				local p = fxPart("Glitter", Vector3.one, fx.Light, true)
				p.Transparency = 1
				p.Parent = fx.Folder
				local created: Glint = { Part = p, Age = 1, Life = 1, At = CFrame.identity, Size = 0.2, Hue = 0 }
				table.insert(fx.Glints, created)
				free = created
			end
			if free then
				local part = bodyParts[math.random(1, #bodyParts)]
				local size = part.Size
				local on = part.CFrame * CFrame.new((math.random() - 0.5) * size.X * 0.9, size.Y / 2 + 0.03, (math.random() - 0.5) * size.Z * 0.9)
				free.At = CFrame.new(on.Position) * CFrame.Angles(0, math.random() * math.pi, math.pi / 4)
				free.Age = 0
				free.Life = 0.35 + math.random() * 0.25
				free.Size = (0.2 + math.random() * 0.12) * s
				free.Hue = math.random()
				free.Part.Color = if look.Rainbow then hue(free.Hue) else fx.Light
			end
		end
	end
	for _, g in fx.Glints do
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

local function step(d: Dino, dt: number, full: boolean)
	local clip = d.Clip
	local t0 = d.Time
	d.Time += dt * d.Rate
	if full and #clip.Events > 0 then
		if clip.Loop then
			local a, b = t0 % clip.Length, d.Time % clip.Length
			if b >= a then
				fire(d, a, b)
			else
				fire(d, a, clip.Length)
				fire(d, -1, b)
			end
		else
			fire(d, t0, math.min(d.Time, clip.Length))
		end
	end
	-- fin d'une animation simple : état suivant (local tant que le serveur n'a rien dit d'autre)
	if not clip.Loop and d.Time >= clip.Length then
		play(d, clip.Next or "Idle")
		clip = d.Clip
	elseif d.ClipName == "Idle" and d.State == "Idle" then
		d.NextVariant -= dt
		if d.NextVariant <= 0 then
			local options = {}
			for _, n in IDLE_VARIANTS do
				if d.Data.Clips[n] then
					table.insert(options, n)
				end
			end
			if #options > 0 then
				play(d, options[math.random(1, #options)])
				clip = d.Clip
			else
				d.NextVariant = 10
			end
		end
	end
	local pose = DinoBuilder.Sample(clip, d.Time, d.Pose)
	if d.From and d.Fade < 1 then
		d.Fade = math.min(1, d.Fade + dt / FADE)
		local w = d.Fade * d.Fade * (3 - 2 * d.Fade)
		pose = DinoBuilder.Blend(d.From :: DinoBuilder.Pose, pose, w, d.Mix)
	end
	DinoBuilder.Copy(pose, d.Last)
	-- repère : suit la pièce Root (déplacée par le serveur à basse fréquence) en lissant
	local target = d.Root.CFrame
	local k = 1 - math.exp(-dt * 14)
	if (d.Base.Position - target.Position).Magnitude > 8 * d.Rig.Scale then
		d.Base = target
	else
		d.Base = d.Base:Lerp(target, k)
	end
	DinoBuilder.Pose(d.Rig, pose, d.Base)
	stepFx(d, dt, full)
end

local function attach(model: Model)
	if dinos[model] then
		return
	end
	local species = model:GetAttribute("Species")
	if type(species) ~= "string" then
		return
	end
	local data = DinoBuilder.Get(species)
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not data or not (root and root:IsA("BasePart")) then
		return
	end
	local hasBones = false
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Bone") then
			hasBones = true
			break
		end
	end
	local visual: Model = model
	local localModel: Model? = nil
	if not hasBones then
		-- proxy du serveur : briques construites chez le client, alignées sur la pièce Root
		local mutation = model:GetAttribute("Mutation")
		local level = model:GetAttribute("Level")
		local scale = model:GetAttribute("Scale")
		localModel = DinoBuilder.Build(data, {
			Size = if type(scale) == "number" then scale else 1,
			Mutation = if type(mutation) == "string" then mutation else nil,
			Level = if type(level) == "string" then level else nil,
		})
		visual = localModel :: Model
	end
	local rig = DinoBuilder.Rig(visual, data)
	if localModel then
		localModel:PivotTo(root.CFrame)
		localModel.Parent = model
	end
	local d: Dino = {
		Model = model,
		Data = data,
		Rig = rig,
		Local = localModel,
		Root = root,
		Base = root.CFrame,
		Clip = data.Clips.Idle,
		ClipName = "Idle",
		Time = math.random() * 2,
		Rate = 1,
		State = "Idle",
		From = nil,
		Fade = 1,
		Pose = {},
		Mix = {},
		Last = {},
		Acc = math.random() * 0.05,
		Phase = math.random(0, 11),
		NextVariant = 6 + math.random() * 8,
		Radius = math.max(data.Size.X, data.Size.Y, data.Size.Z) * rig.Scale * 0.6,
		Fx = nil,
		Conns = {},
	}
	dinos[model] = d
	buildFx(d)
	onState(d)
	table.insert(d.Conns, model:GetAttributeChangedSignal("State"):Connect(function()
		onState(d)
	end))
	table.insert(d.Conns, model:GetAttributeChangedSignal("StateAt"):Connect(function()
		onState(d)
	end))
	table.insert(d.Conns, model:GetAttributeChangedSignal("Speed"):Connect(function()
		d.Rate = rateFor(d, d.Clip)
	end))
	table.insert(d.Conns, model:GetAttributeChangedSignal("Rarity"):Connect(function()
		buildFx(d)
	end))
end

local function detach(model: Model)
	local d = dinos[model]
	if not d then
		return
	end
	dinos[model] = nil
	for _, c in d.Conns do
		c:Disconnect()
	end
	clearFx(d)
	if d.Local then
		d.Local:Destroy()
	end
end

local frame = 0
local function update(dt: number)
	frame += 1
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, d in dinos do
		if not model.Parent then
			continue
		end
		local always = model:GetAttribute("AlwaysAnimate") == true
		local full = true
		local every = 1
		if not always and cam then
			local pos = d.Root.Position
			local size = math.max(1, d.Radius / 4)
			local dist = (pos - camPos).Magnitude / size
			if dist > CULL then
				continue -- figé : trop loin
			end
			local _, onScreen = cam:WorldToViewportPoint(pos)
			if not onScreen then
				-- hors du cadre : on vérifie aussi un point au-dessus (gros dinos à moitié visibles)
				local _, top = cam:WorldToViewportPoint(pos + Vector3.new(0, d.Radius, 0))
				if not top and dist > 12 then
					continue -- figé : hors de vue
				end
			end
			if dist > FAR then
				every, full = 4, false
			elseif dist > MID then
				every, full = 3, false
			elseif dist > NEAR then
				every = 2
			end
		end
		d.Acc += dt
		if every == 1 or (frame + d.Phase) % every == 0 then
			step(d, math.min(d.Acc, 0.25), full)
			d.Acc = 0
		end
	end
end

-- Joue un état sur un modèle local (ViewportFrame, aperçu) : même effet que l'attribut State
function DinoAnimController.Play(model: Model, state: string)
	model:SetAttribute("State", state)
	model:SetAttribute("StateAt", nil)
end

-- Enregistre un modèle sans passer par le tag (déjà construit par DinoBuilder.Build)
function DinoAnimController.Register(model: Model)
	attach(model)
end

function DinoAnimController.Unregister(model: Model)
	detach(model)
end

function DinoAnimController.Init() end

function DinoAnimController.Start()
	CollectionService:GetInstanceAddedSignal(DinoBuilder.Tag):Connect(function(inst)
		if inst:IsA("Model") then
			task.defer(attach, inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(DinoBuilder.Tag):Connect(function(inst)
		if inst:IsA("Model") then
			detach(inst)
		end
	end)
	for _, inst in CollectionService:GetTagged(DinoBuilder.Tag) do
		if inst:IsA("Model") then
			task.defer(attach, inst)
		end
	end
	RunService.RenderStepped:Connect(update)
end

return DinoAnimController
