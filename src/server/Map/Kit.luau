--!strict
-- Briques de la map (brief 10) : pièces en studs (Plastic, studs sur le dessus), formes rondes en escalier, décor non
-- collidable, placement par raycast, grille des places à éviter et budget de lumières. Utilisé par MapBuilder, Plots,
-- Plaza, ZoneBase, Props et les modules de zone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)

local Kit = {}

-- Grille des places à éviter (chemin, gisements, clairière du gardien, décor déjà posé), en cases de Cell studs
export type Grid = {
	X0: number,
	Z0: number,
	Cell: number,
	Columns: number,
	Rows: number,
	Blocked: { [number]: boolean },
}

-- Contexte d'une partie de la map en construction (une zone, la place, les parcs)
export type Ctx = {
	Rng: Random,
	Lights: number, -- lumières déjà posées dans cette partie
	LightBudget: number, -- au plus
	Grid: Grid?,
	Ray: RaycastParams?, -- raycast vers le sol de cette partie (placement du décor)
	GroundTop: number,
}

export type Line = { Text: string, Color: Color3, Weight: number, Name: string? }

local DARK = Color3.new(0, 0, 0)
local LIGHT = Color3.new(1, 1, 1)

-- ===================================================================== nombres et couleurs

function Kit.snap(n: number, step: number): number
	return math.floor(n / step + 0.5) * step
end

-- Arrondi d'une dimension : pair au-delà de 6 studs (les studs des pièces superposées restent alignés), sinon au demi
local function dim(n: number): number
	if n >= 6 then
		return math.max(2, Kit.snap(n, 2))
	end
	return math.max(0.5, Kit.snap(n, 0.5))
end
Kit.dim = dim

function Kit.range(rng: Random, a: number, b: number): number
	return a + rng:NextNumber() * (b - a)
end

function Kit.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Couleur assombrie (amount > 0) ou éclaircie (amount < 0)
function Kit.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(DARK, amount)
	end
	return color:Lerp(LIGHT, -amount)
end

-- ===================================================================== pièces

-- Pièce en studs (Plastic avec studs sur le dessus, sinon lisse), ancrée et collidable
function Kit.block(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	local mat = material or Enum.Material.Plastic
	part.Material = mat
	part.TopSurface = if mat == Enum.Material.Plastic then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Décor : ni collision, ni requêtes (raycasts, ProximityPrompt), ni contact, ni ombre
function Kit.decor(part: Part): Part
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Pièce de décor
function Kit.prop(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return Kit.decor(Kit.block(parent, size, cframe, color, material))
end

-- Gros volume solide d'un lieu marquant (pilier, tronc, bloc de glace) : on s'y cogne, mais les raycasts le traversent
-- (le gardien du brief 7 suit le sol par raycast : il ne grimpe pas dessus ; le décor ne s'y pose pas)
function Kit.solid(part: Part): Part
	part.CanQuery = false
	return part
end

-- Point d'ancrage invisible (lu par les services : Spawn, Guardian...)
function Kit.anchor(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local part = Kit.prop(parent, size, cframe, LIGHT, Enum.Material.SmoothPlastic)
	part.Name = name
	part.Transparency = 1
	return part
end

-- Modèle de décor (diffusé d'un bloc avec StreamingEnabled), à parenter par l'appelant
function Kit.group(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end

-- Le modèle flotte chez les joueurs (AmbienceController) : monte et descend de `height` studs (vitesse `speed` rad/s)
-- et tourne de `spin` rad/s autour de `core` (pièce droite, au centre)
function Kit.float(model: Model, core: BasePart, height: number, speed: number, spin: number)
	model.PrimaryPart = core
	model:SetAttribute("FloatHeight", height)
	model:SetAttribute("FloatSpeed", speed)
	model:SetAttribute("FloatSpin", spin)
	model:AddTag(Ambience.Float.Tag)
end

function Kit.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- ===================================================================== formes rondes en escalier

-- Disque posé sur `base` (centre du dessous) : rectangles superposés en croix, 2 pour un petit rayon, 3 au-delà de
-- 2,5 studs, 5 au-delà de 10 (le bord reste rond vu de haut)
function Kit.disc(parent: Instance, base: CFrame, radius: number, height: number, color: Color3, material: Enum.Material?, solid: boolean?): { Part }
	local parts = {}
	local d = radius * 2
	local center = base * CFrame.new(0, height / 2, 0)
	local sizes: { Vector3 } = {}
	if radius < 2.5 then
		sizes = { Vector3.new(dim(d), height, dim(d * 0.62)), Vector3.new(dim(d * 0.62), height, dim(d)) }
	elseif radius < 10 then
		sizes = { Vector3.new(dim(d), height, dim(d * 0.58)), Vector3.new(dim(d * 0.58), height, dim(d)), Vector3.new(dim(d * 0.86), height, dim(d * 0.86)) }
	else
		for _, angle in { 15, 30, 45, 60, 75 } do
			local a = math.rad(angle)
			table.insert(sizes, Vector3.new(dim(d * math.cos(a) * 1.02), height, dim(d * math.sin(a) * 1.02)))
		end
	end
	for _, size in sizes do
		local part = Kit.block(parent, size, center, color, material)
		if not solid then
			Kit.decor(part)
		end
		table.insert(parts, part)
	end
	return parts
end

-- Dôme : disques empilés dont le rayon suit un quart de cercle
function Kit.dome(parent: Instance, base: CFrame, radius: number, height: number, tiers: number, color: Color3, material: Enum.Material?, solid: boolean?): { Part }
	local parts = {}
	local step = height / tiers
	for k = 1, tiers do
		local t = (k - 1) / tiers
		local r = radius * math.sqrt(1 - t * t)
		for _, part in Kit.disc(parent, base * CFrame.new(0, (k - 1) * step, 0), math.max(0.5, r), step, color, material, solid) do
			table.insert(parts, part)
		end
	end
	return parts
end

-- Cône : disques empilés dont le rayon diminue régulièrement
function Kit.cone(parent: Instance, base: CFrame, radius: number, height: number, tiers: number, color: Color3, material: Enum.Material?, solid: boolean?, top: number?): { Part }
	local parts = {}
	local step = height / tiers
	local last = top or 0.15
	for k = 1, tiers do
		local t = (k - 1) / math.max(1, tiers - 1)
		local r = radius * (1 - t * (1 - last))
		for _, part in Kit.disc(parent, base * CFrame.new(0, (k - 1) * step, 0), math.max(0.5, r), step, color, material, solid) do
			table.insert(parts, part)
		end
	end
	return parts
end

-- Tronc rond (2 pièces en croix) posé sur `base`
function Kit.trunk(parent: Instance, base: CFrame, width: number, height: number, color: Color3, solid: boolean?): { Part }
	local center = base * CFrame.new(0, height / 2, 0)
	local a = Kit.block(parent, Vector3.new(width, height, width * 0.62), center, color)
	local b = Kit.block(parent, Vector3.new(width * 0.62, height, width), center, color)
	if not solid then
		Kit.decor(a)
		Kit.decor(b)
	end
	return { a, b }
end

-- ===================================================================== lumières

-- PointLight sur `part`, dans la limite du budget de la partie en cours ; false si le budget est épuisé
function Kit.light(ctx: Ctx, part: BasePart, color: Color3, range: number, brightness: number?): boolean
	if ctx.Lights >= ctx.LightBudget then
		return false
	end
	ctx.Lights += 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.2
	light.Shadows = false
	light.Parent = part
	return true
end

-- ===================================================================== textes (enseignes, arches)

-- SurfaceGui `name` sur la face `face` de `part`, une ligne de texte par entrée (Weight = part de la hauteur)
function Kit.text(part: BasePart, face: Enum.NormalId, name: string, lines: { Line }): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	local total = 0
	for _, line in lines do
		total += line.Weight
	end
	local y = 0.06
	for index, line in lines do
		local height = 0.88 * line.Weight / total
		local label = Instance.new("TextLabel")
		label.Name = line.Name or ("Line" .. index)
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line.Color
		label.TextStrokeColor3 = Color3.fromRGB(30, 22, 16)
		label.TextStrokeTransparency = 0.2
		label.Text = line.Text
		label.Parent = gui
		y += height
	end
	gui.Parent = part
	return gui
end

-- ===================================================================== sol et placement

-- Hauteur du sol sous (x, z) : raycast vers les pièces de sol du contexte, sinon `fallback` (ou GroundTop)
function Kit.groundAt(ctx: Ctx, x: number, z: number, fallback: number?): number
	local params = ctx.Ray
	if params then
		local hit = Workspace:Raycast(Vector3.new(x, ctx.GroundTop + 400, z), Vector3.new(0, -800, 0), params)
		if hit then
			return hit.Position.Y
		end
	end
	return fallback or ctx.GroundTop
end

-- X de la paroi du côté `side` (-1 gauche, 1 droite) à la hauteur y : raycast horizontal depuis X = side * from vers
-- l'extérieur, vers les pièces de sol du contexte (falaises) ; sinon `fallback`
function Kit.wallAt(ctx: Ctx, side: number, from: number, y: number, z: number, fallback: number): number
	local params = ctx.Ray
	if params then
		local hit = Workspace:Raycast(Vector3.new(side * from, y, z), Vector3.new(side * 120, 0, 0), params)
		if hit then
			return hit.Position.X
		end
	end
	return fallback
end

-- Paramètres de raycast qui ne touchent que les descendants de `folders`
function Kit.rayTo(folders: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = folders
	params.IgnoreWater = true
	return params
end

-- ===================================================================== grille des places à éviter

function Kit.grid(x0: number, z0: number, x1: number, z1: number, cell: number): Grid
	return {
		X0 = x0,
		Z0 = z0,
		Cell = cell,
		Columns = math.ceil((x1 - x0) / cell),
		Rows = math.ceil((z1 - z0) / cell),
		Blocked = {},
	}
end

local function cellRange(grid: Grid, a: number, b: number, origin: number, count: number): (number, number)
	local first = math.max(0, math.floor((a - origin) / grid.Cell))
	local last = math.min(count - 1, math.floor((b - origin) / grid.Cell))
	return first, last
end

-- Marque un rectangle (coordonnées monde X/Z)
function Kit.markRect(grid: Grid, x0: number, z0: number, x1: number, z1: number)
	local c0, c1 = cellRange(grid, math.min(x0, x1), math.max(x0, x1), grid.X0, grid.Columns)
	local r0, r1 = cellRange(grid, math.min(z0, z1), math.max(z0, z1), grid.Z0, grid.Rows)
	for row = r0, r1 do
		for column = c0, c1 do
			grid.Blocked[row * grid.Columns + column] = true
		end
	end
end

-- Marque un disque
function Kit.markCircle(grid: Grid, x: number, z: number, radius: number)
	local c0, c1 = cellRange(grid, x - radius, x + radius, grid.X0, grid.Columns)
	local r0, r1 = cellRange(grid, z - radius, z + radius, grid.Z0, grid.Rows)
	local half = grid.Cell / 2
	for row = r0, r1 do
		for column = c0, c1 do
			local cx = grid.X0 + column * grid.Cell + half
			local cz = grid.Z0 + row * grid.Cell + half
			if (cx - x) ^ 2 + (cz - z) ^ 2 <= (radius + half) ^ 2 then
				grid.Blocked[row * grid.Columns + column] = true
			end
		end
	end
end

-- Le disque (x, z, radius) est-il entièrement libre et dans la grille ?
function Kit.isFree(grid: Grid, x: number, z: number, radius: number): boolean
	local x1, z1 = grid.X0 + grid.Columns * grid.Cell, grid.Z0 + grid.Rows * grid.Cell
	if x - radius < grid.X0 or x + radius > x1 or z - radius < grid.Z0 or z + radius > z1 then
		return false
	end
	local c0, c1 = cellRange(grid, x - radius, x + radius, grid.X0, grid.Columns)
	local r0, r1 = cellRange(grid, z - radius, z + radius, grid.Z0, grid.Rows)
	for row = r0, r1 do
		for column = c0, c1 do
			if grid.Blocked[row * grid.Columns + column] then
				return false
			end
		end
	end
	return true
end

return Kit
