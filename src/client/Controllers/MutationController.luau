--!strict
-- MutationController : effets animés des mutations autour des dinos, chez le client (docs/MUTATIONS.md).
-- Les couleurs des briques viennent de DinoBuilder (mutation peinte à la construction) ; ici, ce qui bouge, en petits
-- cubes nets, à côté de l'aura de rareté (module Aura, posée par DinoAnimController, qui ne s'occupe pas des mutations) :
--   * chute : gouttes d'ambre, pétales (Bloom), flocons (Frost) ;
--   * montée : bulles toxiques ou des abysses, braises de lave, éclats violets d'obsidienne ;
--   * éclats posés sur le corps qui s'allument et s'éteignent : cristal, nacre, rubis, étoiles de la galaxie ;
--   * Rainbow : éclats de toutes les couleurs et arc-en-ciel qui défile en vague sur tout le corps.
-- Pour tout modèle tagué « Dino » (DinoBuilder.Tag) qui a un attribut Mutation connu (Config.Economy.Mutations), dans
-- workspace (rien dans les ViewportFrame). Coupé au loin et derrière la caméra ; budget de cubes borné, les dinos les plus
-- proches servis d'abord, vague arc-en-ciel sur les MaxWaves plus proches seulement. Les cubes vivent dans
-- workspace.MutationFx, créé chez le client (jamais répliqué), sans collision ni requête, déplacés en un seul BulkMoveTo.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))
local DinoBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DinoBuilder"))

export type Effect = {
	Kind: string, -- "Fall" | "Rise" | "Glint"
	Rate: number, -- cubes par seconde pour un dino d'environ 10 studs (plus pour les gros, borné)
	Colors: { Color3 },
	Neon: boolean,
	Size: number, -- côté du cube (studs) pour un dino d'environ 10 studs
	Life: number, -- secondes
	Speed: number, -- studs par seconde (montée ou chute)
	Drift: number, -- balancement sur les côtés (studs)
	Spin: boolean, -- le cube tourne sur lui-même
	Rainbow: boolean, -- couleurs au hasard sur tout le cercle chromatique + vague sur les briques
}

local MutationController = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function effect(kind: string, rate: number, colors: { Color3 }, neon: boolean, size: number, life: number, speed: number, drift: number, spin: boolean): Effect
	return { Kind = kind, Rate = rate, Colors = colors, Neon = neon, Size = size, Life = life, Speed = speed, Drift = drift, Spin = spin, Rainbow = false }
end

-- Effet de chaque mutation (mêmes noms que Config.Economy.Mutations)
MutationController.Effects = {
	Amber = effect("Fall", 1.6, { rgb(255, 172, 38), rgb(255, 214, 110) }, false, 0.3, 1.5, 2.6, 0.1, false),
	Crystal = effect("Glint", 4, { rgb(214, 246, 255), rgb(150, 228, 255) }, true, 0.36, 0.8, 0, 0, false),
	Pearl = effect("Glint", 3, { rgb(255, 242, 250), rgb(232, 214, 255), rgb(208, 255, 240) }, true, 0.3, 1, 0, 0, false),
	Bloom = effect("Fall", 2.4, { rgb(255, 120, 196), rgb(255, 222, 80), rgb(255, 250, 245), rgb(196, 120, 255) }, false, 0.34, 2.4, 1.1, 1.1, true),
	Toxic = effect("Rise", 3.5, { rgb(150, 255, 60), rgb(214, 255, 96) }, true, 0.36, 1.4, 2.2, 0.5, false),
	Ruby = effect("Glint", 3.5, { rgb(255, 90, 124), rgb(255, 176, 194) }, true, 0.3, 0.8, 0, 0, false),
	Frost = effect("Fall", 4, { rgb(255, 255, 255), rgb(214, 238, 255) }, false, 0.26, 2.6, 1.3, 0.8, true),
	Lava = effect("Rise", 4, { rgb(255, 120, 30), rgb(255, 200, 60) }, true, 0.3, 1.2, 3, 0.35, true),
	Obsidian = effect("Rise", 3, { rgb(170, 90, 255), rgb(120, 60, 220) }, true, 0.28, 1.3, 1.8, 0.3, true),
	Abyssal = effect("Rise", 3, { rgb(60, 230, 255), rgb(130, 200, 255) }, true, 0.4, 2.2, 1.4, 0.6, false),
	Galaxy = effect("Glint", 7, { rgb(255, 255, 255), rgb(255, 230, 150), rgb(255, 140, 230), rgb(150, 180, 255) }, true, 0.36, 1.2, 0, 0, false),
	Rainbow = effect("Glint", 6, {}, true, 0.36, 1, 0, 0, false),
} :: { [string]: Effect }
MutationController.Effects.Rainbow.Rainbow = true

MutationController.Range = 150 -- studs (x taille du dino) : plus loin, aucun cube
MutationController.WaveRange = 110 -- studs (x taille du dino) : vague arc-en-ciel
MutationController.WaveRate = 12 -- mises à jour de la vague par seconde
MutationController.WaveSpeed = 0.35 -- tours du cercle chromatique par seconde
MutationController.MaxWaves = 3 -- dinos Rainbow animés en même temps (les plus proches)
MutationController.MaxCubes = 260 -- cubes en même temps, tous dinos confondus (les plus proches d'abord)
MutationController.MaxPerDino = 28

type Cube = {
	Part: Part,
	Kind: string,
	Age: number,
	Life: number,
	Size: number,
	Start: Vector3,
	Speed: number,
	Drift: number,
	Phase: number,
	Spin: boolean,
	Anchor: BasePart?, -- éclat : suit la brique où il est posé
	Offset: CFrame,
}

type Tracked = {
	Model: Model,
	Name: string,
	Effect: Effect,
	Bricks: { BasePart },
	Paint: { BasePart }, -- briques que la vague arc-en-ciel recolore (pas les détails : yeux, dents, griffes)
	Shade: { [BasePart]: number }, -- clarté d'origine de ces briques (la vague garde les ombres du motif)
	Dirty: boolean,
	Scanned: number,
	Acc: number,
	WaveAcc: number,
	Length: number, -- plus grande dimension du dino (studs, à son échelle)
	Cubes: { Cube },
	Conns: { RBXScriptConnection },
	Dist: number, -- distance à la caméra (image en cours)
	Pivot: CFrame,
}

local tracked: { [Model]: Tracked } = {}
local watching: { [Model]: RBXScriptConnection } = {} -- modèles tagués : changement de l'attribut Mutation
local pool: { Part } = {}
local alive = 0
local clock = 0
local folder: Folder? = nil
local rng = Random.new()
-- (réutilisés à chaque image : cubes déplacés en un seul BulkMoveTo, dinos visibles triés par distance)
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}
local near: { Tracked } = {}

local function fxFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = "MutationFx"
	created.Parent = Workspace
	folder = created
	return created
end

local function takePart(): Part
	local part = table.remove(pool)
	if part then
		return part
	end
	local p = Instance.new("Part")
	p.Name = "MutationCube"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function release(cube: Cube)
	cube.Part.Parent = nil
	alive -= 1
	if #pool < MutationController.MaxCubes then
		table.insert(pool, cube.Part)
	else
		cube.Part:Destroy()
	end
end

-- Briques du dino (pièces avec l'attribut Bone, construites par DinoBuilder ici ou sur le modèle)
local function scan(t: Tracked)
	local bricks, paint, shade = {}, {}, {}
	local species = t.Model:GetAttribute("Species")
	local data = if type(species) == "string" then DinoBuilder.Get(species) else nil
	for _, inst in t.Model:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Bone") ~= nil then
			table.insert(bricks, inst)
			-- détails (yeux, dents, griffes : boîtes « Smooth » du modèle) jamais repeints, même dorés en Foil (Golden)
			local index = inst:GetAttribute("Box")
			local box = if data and type(index) == "number" then data.Boxes[index] else nil
			local detail = if box then box.Material == "Smooth" else inst.Material == Enum.Material.SmoothPlastic
			if not detail and inst.Material ~= Enum.Material.Neon then
				table.insert(paint, inst)
				local known = t.Shade[inst]
				if known then
					shade[inst] = known
				else
					local _, _, value = inst.Color:ToHSV()
					shade[inst] = value
				end
			end
		end
	end
	t.Bricks, t.Paint, t.Shade = bricks, paint, shade
	t.Dirty = false
	t.Scanned = clock
	local scale = t.Model:GetAttribute("Scale")
	local s = if type(scale) == "number" and scale > 0 and scale < 100 then scale else 1
	t.Length = if data then math.max(data.Size.X, data.Size.Y, data.Size.Z) * s else 10 * s
end

local function untrack(model: Model)
	local t = tracked[model]
	if not t then
		return
	end
	tracked[model] = nil
	for _, conn in t.Conns do
		conn:Disconnect()
	end
	for _, cube in t.Cubes do
		release(cube)
	end
	table.clear(t.Cubes)
end

local function track(model: Model)
	local name = model:GetAttribute("Mutation")
	local fx = if type(name) == "string" then MutationController.Effects[name] else nil
	local current = tracked[model]
	if current and current.Name == name then
		return
	end
	untrack(model)
	if not fx or not Economy.Mutation(name :: string) then
		return
	end
	local t: Tracked = {
		Model = model,
		Name = name :: string,
		Effect = fx,
		Bricks = {},
		Paint = {},
		Shade = {},
		Dirty = true,
		Scanned = -math.huge,
		Acc = rng:NextNumber(),
		WaveAcc = rng:NextNumber(),
		Length = 10,
		Cubes = {},
		Conns = {},
		Dist = math.huge,
		Pivot = CFrame.identity,
	}
	tracked[model] = t
	-- (briques faites ou défaites : DinoAnimController construit et retire tout un modèle de briques d'un coup ; les
	-- pièces de l'aura, rangées dans le modèle et ajoutées ou retirées selon la distance, ne comptent pas)
	local function dirty(inst: Instance)
		if inst:IsA("BasePart") and inst:GetAttribute("Bone") ~= nil then
			t.Dirty = true
		end
	end
	table.insert(t.Conns, model.DescendantAdded:Connect(dirty))
	table.insert(t.Conns, model.DescendantRemoving:Connect(dirty))
end

-- (appelé en différé : le modèle a pu quitter le jeu entre-temps, déjà vu par unwatch)
local function watch(inst: Instance)
	if not (inst:IsA("Model") and inst:HasTag(DinoBuilder.Tag) and inst:IsDescendantOf(game)) then
		return
	end
	local model = inst :: Model
	if not watching[model] then
		watching[model] = model:GetAttributeChangedSignal("Mutation"):Connect(function()
			track(model)
		end)
	end
	track(model)
end

local function unwatch(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local model = inst :: Model
	local conn = watching[model]
	if conn then
		conn:Disconnect()
		watching[model] = nil
	end
	untrack(model)
end

local function pick(list: { Color3 }): Color3
	return list[rng:NextInteger(1, #list)]
end

-- Point au hasard sur une face de la brique (repère de la brique)
local function onSurface(part: BasePart): CFrame
	local s = part.Size
	local axis = rng:NextInteger(1, 3)
	local sign = if rng:NextNumber() < 0.5 then -1 else 1
	local x = (rng:NextNumber() - 0.5) * s.X
	local y = (rng:NextNumber() - 0.5) * s.Y
	local z = (rng:NextNumber() - 0.5) * s.Z
	if axis == 1 then
		x = sign * s.X / 2
	elseif axis == 2 then
		y = math.abs(s.Y) / 2 -- (dessus de préférence : plus visible)
	else
		z = sign * s.Z / 2
	end
	return CFrame.new(x, y, z)
end

-- Avance un cube ; false quand il a fini (rendu au stock)
local function stepCube(cube: Cube, dt: number): boolean
	cube.Age += dt
	local k = cube.Age / cube.Life
	if k >= 1 then
		return false
	end
	local part = cube.Part
	local position: Vector3
	local size: number
	if cube.Kind == "Glint" then
		local anchor = cube.Anchor
		position = if anchor and anchor.Parent then (anchor.CFrame * cube.Offset).Position else cube.Start
		size = cube.Size * math.sin(math.pi * k)
	else
		local a = cube.Age
		local dy = if cube.Kind == "Rise" then cube.Speed * a else -cube.Speed * a
		position = cube.Start + Vector3.new(math.sin(a * 2.1 + cube.Phase) * cube.Drift, dy, math.cos(a * 1.7 + cube.Phase) * cube.Drift)
		size = cube.Size * (1 - k * k)
	end
	size = math.max(size, 0.05)
	part.Size = Vector3.new(size, size, size)
	local turn = if cube.Spin then cube.Age * 2.4 + cube.Phase else 0
	-- (placé avec les autres cubes en un seul BulkMoveTo, en fin d'image)
	table.insert(moveParts, part)
	table.insert(moveFrames, CFrame.new(position) * CFrame.Angles(math.rad(45) + turn, math.rad(45) + turn * 0.7, 0))
	return true
end

local function spawnCube(t: Tracked, scale: number)
	local fx = t.Effect
	local bricks = t.Bricks
	local brick = bricks[rng:NextInteger(1, #bricks)]
	if not brick.Parent then
		t.Dirty = true -- (briques défaites depuis le dernier inventaire)
		return
	end
	local part = takePart()
	local size = math.clamp(fx.Size * scale, 0.18, 1.6)
	part.Material = if fx.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = if fx.Rainbow then Color3.fromHSV(rng:NextNumber(), 0.8, 1) else pick(fx.Colors)
	part.Transparency = 0
	local offset = onSurface(brick)
	local cube: Cube = {
		Part = part,
		Kind = fx.Kind,
		Age = 0,
		Life = fx.Life * (0.8 + 0.4 * rng:NextNumber()),
		Size = size,
		Start = (brick.CFrame * offset).Position,
		Speed = fx.Speed * math.sqrt(scale) * (0.8 + 0.4 * rng:NextNumber()),
		Drift = fx.Drift * math.sqrt(scale),
		Phase = rng:NextNumber() * math.pi * 2,
		Spin = fx.Spin,
		Anchor = if fx.Kind == "Glint" then brick else nil,
		Offset = offset,
	}
	part.CFrame = CFrame.new(cube.Start)
	part.Parent = fxFolder()
	alive += 1
	table.insert(t.Cubes, cube)
	stepCube(cube, 0) -- (taille et place de départ : un éclat naît tout petit)
end

-- Vague arc-en-ciel : la teinte de chaque brique dépend de sa place le long du dino et du temps
local function wave(t: Tracked, center: Vector3, forward: Vector3, length: number)
	local base = clock * MutationController.WaveSpeed
	for _, part in t.Paint do
		local along = (part.Position - center):Dot(forward) / length
		local hue = (base + along) % 1
		part.Color = Color3.fromHSV(hue, 0.72, t.Shade[part] or 1)
	end
end

local function update(dt: number)
	dt = math.min(dt, 0.1)
	clock += dt
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else nil
	local camLook = if camera then camera.CFrame.LookVector else nil
	table.clear(near)
	for model, t in tracked do
		-- cubes en cours (même loin ou hors de vue : ils finissent leur vie)
		local i = 1
		while i <= #t.Cubes do
			if stepCube(t.Cubes[i], dt) then
				i += 1
			else
				release(table.remove(t.Cubes, i) :: Cube)
			end
		end
		if not model:IsDescendantOf(Workspace) then
			continue
		end
		if t.Dirty and clock - t.Scanned >= 0.5 then
			scan(t)
		end
		if #t.Bricks == 0 or not camPos or not camLook then
			continue
		end
		local pivot = model:GetPivot()
		local length = t.Length
		local toDino = pivot.Position - camPos
		local dist = toDino.Magnitude
		-- derrière la caméra (au-delà de sa propre taille) ou trop loin : rien de neuf
		local behind = dist > length and toDino:Dot(camLook) < 0
		if behind or dist > MutationController.Range * math.max(1, math.clamp(length / 10, 0.5, 3)) then
			continue
		end
		t.Dist, t.Pivot = dist, pivot
		table.insert(near, t)
	end
	-- les plus proches d'abord : ils prennent les cubes libres et la vague arc-en-ciel
	table.sort(near, function(a: Tracked, b: Tracked): boolean
		return a.Dist < b.Dist
	end)
	local waves = 0
	for _, t in near do
		local fx = t.Effect
		local sizeFactor = math.clamp(t.Length / 10, 0.5, 3)
		t.Acc += dt * fx.Rate * sizeFactor
		while t.Acc >= 1 do
			t.Acc -= 1
			if alive < MutationController.MaxCubes and #t.Cubes < MutationController.MaxPerDino then
				spawnCube(t, sizeFactor)
			end
		end
		if fx.Rainbow and waves < MutationController.MaxWaves and t.Dist <= MutationController.WaveRange * math.max(1, sizeFactor) then
			waves += 1
			t.WaveAcc += dt * MutationController.WaveRate
			if t.WaveAcc >= 1 then
				t.WaveAcc %= 1
				wave(t, t.Pivot.Position, t.Pivot.LookVector, math.max(t.Length, 4))
			end
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveFrames)
	end
end

-- Nombre de cubes en vie (tests, debug)
function MutationController.Alive(): number
	return alive
end

-- Modèles suivis (tests)
function MutationController.Tracked(model: Model): string?
	local t = tracked[model]
	return if t then t.Name else nil
end

function MutationController.Init() end

function MutationController.Start()
	CollectionService:GetInstanceAddedSignal(DinoBuilder.Tag):Connect(function(inst)
		task.defer(watch, inst)
	end)
	CollectionService:GetInstanceRemovedSignal(DinoBuilder.Tag):Connect(unwatch)
	for _, inst in CollectionService:GetTagged(DinoBuilder.Tag) do
		task.defer(watch, inst)
	end
	RunService.RenderStepped:Connect(update)
end

return MutationController
