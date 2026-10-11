--!strict
-- Squelette commun des 8 zones de la route (brief 10) : étendue (Area), sol et taches de couleur, chemin central,
-- falaises de bord, arche d'entrée avec nom et vitesse conseillée (Arch), gisements décorés (DigSites/SiteN avec leurs
-- Attachments Slot1...), clairière et nid du gardien (Guardian), puis le décor de la zone posé par raycast en évitant
-- une grille de places réservées, et le décor accroché aux parois des falaises. Chaque module de zone
-- (Map/Zones/<Nom>.luau) donne son thème et son lieu marquant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local ZoneBase = {}

local rgb = Color3.fromRGB
local shade = Kit.shade

-- Décor éparpillé : Count modèles de Prop, chacun réservant un disque de Radius studs. XMin/XMax : distance à l'axe de
-- la route (par défaut tout le couloir hors chemin), Side : -1 ou 1 pour un seul côté, Scale : { min, max }.
export type Scatter = {
	Prop: Props.PropFn,
	Count: number,
	Radius: number,
	XMin: number?,
	XMax: number?,
	Side: number?,
	Scale: { number }?,
	Pal: Props.Palette?,
}

export type Theme = {
	Ground: Color3,
	Patches: { Color3 },
	Path: Color3,
	PathEdge: Color3,
	Planks: boolean?, -- chemin en planches (ponton)
	Cliff: { Color3 }, -- 3 étages, du bas vers le haut
	CliffTop: Color3,
	CliffScale: number?, -- hauteur des falaises (1 par défaut)
	Arch: { Pillar: Color3, Beam: Color3, Board: Color3, Trim: Color3 },
	Dirt: Color3,
	Rim: Color3,
	Nest: { Ring: Color3, Bed: Color3 },
	Glow: Color3?, -- lanternes des gisements
	Pal: Props.Palette?, -- couleurs du décor des gisements
	Scatter: { Scatter },
	Wall: { Scatter }?, -- décor qui sort des parois des falaises (cristaux), vers la route ; XMin/XMax inutilisés
	Border: ((info: Info, side: number) -> boolean)?, -- bord spécial (renvoie true si fait, sinon falaises)
	ArchTop: ((info: Info, beam: CFrame) -> ())?,
	Landmark: ((info: Info) -> ())?,
}

export type Info = {
	Zone: Zones.Zone,
	Theme: Theme,
	Model: Model,
	Ground: Folder, -- pièces de sol (cibles des raycasts de placement)
	Decor: Folder,
	Z0: number,
	Z1: number,
	Length: number,
	HalfWidth: number, -- demi-largeur du couloir jouable
	Border: number,
	GroundTop: number,
	Ctx: Kit.Ctx,
	Grid: Kit.Grid,
	Rng: Random,
	NestZ: number,
	Sites: { Vector3 }, -- centres des gisements (au sol)
}

-- ===================================================================== sol

local function ground(info: Info)
	local theme, gt = info.Theme, info.GroundTop
	local full = info.HalfWidth + info.Border
	local slab = Kit.block(info.Ground, Vector3.new(full * 2, 2, info.Length), CFrame.new(0, gt - 1, info.Z0 + info.Length / 2), theme.Ground)
	slab.Name = "Ground"
	local rng = info.Rng
	for _ = 1, math.floor(info.Length / 12) do
		local w, d = Kit.snap(Kit.range(rng, 12, 34), 2), Kit.snap(Kit.range(rng, 12, 40), 2)
		local x = Kit.snap(Kit.range(rng, -info.HalfWidth + w / 2, info.HalfWidth - w / 2), 2)
		local z = Kit.snap(Kit.range(rng, info.Z0 + d / 2, info.Z1 - d / 2), 2)
		Kit.block(info.Ground, Vector3.new(w, 1, d), CFrame.new(x, gt - 0.4, z), theme.Ground:Lerp(Kit.pick(rng, theme.Patches), 0.55))
	end
end

-- Chemin central de l'arche au bout de la zone (coupé par la clairière du gardien), et embranchements vers les gisements
local function path(info: Info)
	local theme, gt, rng = info.Theme, info.GroundTop, info.Rng
	local width = Map.Route.PathWidth
	local radius = Map.Guardian.Radius
	local step = if theme.Planks then 2 else 8
	local z = info.Z0
	local index = 0
	while z < info.Z1 - 0.01 do
		local length = math.min(step, info.Z1 - z)
		local center = z + length / 2
		if math.abs(center - info.NestZ) > radius - 4 then
			if theme.Planks then
				Kit.block(info.Ground, Vector3.new(width - 6, 1, length - 0.2), CFrame.new(0, gt - 0.25, center), if index % 2 == 0 then theme.Path else shade(theme.Path, 0.12))
			else
				local w = width + Kit.pick(rng, { -2, 0, 0, 2 })
				Kit.block(info.Ground, Vector3.new(w, 1, length), CFrame.new(Kit.pick(rng, { -1, 0, 1 }), gt - 0.3, center), theme.Path)
				if rng:NextNumber() < 0.6 then
					local side = if rng:NextNumber() < 0.5 then -1 else 1
					Kit.prop(info.Decor, Vector3.new(Kit.range(rng, 1.4, 2.4), 0.6, Kit.range(rng, 1.6, 3)), CFrame.new(side * (w / 2 + 0.6), gt + 0.3, center + Kit.range(rng, -2, 2)), theme.PathEdge)
				end
			end
		end
		z += length
		index += 1
	end
	if theme.Planks then
		-- poteaux du ponton
		for zp = info.Z0 + 6, info.Z1 - 4, 12 do
			if math.abs(zp - info.NestZ) > radius then
				for _, side in { -1, 1 } do
					Kit.prop(info.Decor, Vector3.new(1, 2.4, 1), CFrame.new(side * (width / 2 - 2.6), gt + 1, zp), shade(theme.Path, 0.3))
				end
			end
		end
	end
	-- clairière du gardien
	Kit.disc(info.Ground, CFrame.new(0, gt - 0.75, info.NestZ), radius, 1, shade(theme.Path, -0.06), nil, true)
	-- embranchements vers les gisements
	for _, site in info.Sites do
		local side = if site.X < 0 then -1 else 1
		local x0, x1 = side * (width / 2 - 1), site.X - side * 6
		Kit.block(info.Ground, Vector3.new(math.abs(x1 - x0), 1, 8), CFrame.new((x0 + x1) / 2, gt - 0.35, site.Z), shade(theme.Path, 0.06))
	end
end

-- ===================================================================== bords

-- Falaises en 3 étages sur le côté `side` (-1 gauche, 1 droite), tronçons de longueur variable, chapeau coloré
function ZoneBase.Cliffs(info: Info, side: number, colors: { Color3 }?, top: Color3?, scale: number?)
	local theme, gt, rng = info.Theme, info.GroundTop, info.Rng
	local palette = colors or theme.Cliff
	local cap = top or theme.CliffTop
	local k = scale or theme.CliffScale or 1
	local hw, border = info.HalfWidth, info.Border
	local z = info.Z0
	while z < info.Z1 - 0.01 do
		local length = math.min(Kit.snap(Kit.range(rng, 16, 26), 2), info.Z1 - z)
		if info.Z1 - (z + length) < 8 then
			length = info.Z1 - z
		end
		local heights = { Kit.range(rng, 10, 14) * k }
		heights[2] = heights[1] + Kit.range(rng, 6, 10) * k
		heights[3] = heights[2] + Kit.range(rng, 6, 12) * k
		local offsets = { Kit.range(rng, 0.5, 3) }
		offsets[2] = offsets[1] + Kit.range(rng, 5, 8)
		offsets[3] = offsets[2] + Kit.range(rng, 5, 9)
		for tier = 1, 3 do
			local inner = hw + offsets[tier]
			local width = hw + border - inner
			local x = side * (inner + width / 2)
			Kit.block(info.Ground, Vector3.new(width, heights[tier], length), CFrame.new(x, gt + heights[tier] / 2, z + length / 2), palette[tier] or palette[#palette])
			if tier == 3 then
				Kit.block(info.Ground, Vector3.new(width, 1, length), CFrame.new(x, gt + heights[tier] + 0.5, z + length / 2), cap)
			end
		end
		z += length
	end
	-- plateau derrière les falaises (on ne voit jamais le vide au-delà), un peu plus bas que leurs sommets
	ZoneBase.Plateau(info, side, gt + 22 * k - 1, cap)
end

-- Grand plateau plat au-delà du bord `side`, de la hauteur `top`
function ZoneBase.Plateau(info: Info, side: number, top: number, color: Color3)
	local width = 260
	local bottom = info.GroundTop - 2
	local x0 = info.HalfWidth + info.Border
	Kit.prop(info.Decor, Vector3.new(width, top - bottom, info.Length), CFrame.new(side * (x0 + width / 2), (top + bottom) / 2, info.Z0 + info.Length / 2), color)
	-- quelques collines pour casser le plat vu de haut
	local rng = info.Rng
	for _ = 1, 4 do
		local radius = Kit.range(rng, 16, 30)
		local x = side * Kit.range(rng, x0 + 30 + radius, x0 + width - radius)
		local z = Kit.range(rng, info.Z0 + radius * 0.5, info.Z1 - radius * 0.5)
		Kit.dome(info.Decor, CFrame.new(x, top, z), radius, Kit.range(rng, 6, 16), 2, Kit.shade(color, Kit.range(rng, -0.08, 0.1)))
	end
end

-- ===================================================================== arche d'entrée

local function speedText(speed: number): string
	return if speed <= 0 then "No speed needed" else "Recommended speed: " .. Format.Number(speed)
end

local function arch(info: Info)
	local theme, gt = info.Theme, info.GroundTop
	local colors = theme.Arch
	local z = info.Z0 + 5
	local px = Map.Route.PathWidth / 2 + 4
	local m = Instance.new("Model")
	m.Name = "Gate"
	for _, side in { -1, 1 } do
		local base = CFrame.new(side * px, gt, z)
		Kit.block(m, Vector3.new(5.2, 3, 5.2), base * CFrame.new(0, 1.5, 0), shade(colors.Pillar, 0.15))
		Kit.block(m, Vector3.new(3.8, 17, 3.8), base * CFrame.new(0, 3 + 8.5, 0), colors.Pillar)
		Kit.block(m, Vector3.new(4.8, 1.2, 4.8), base * CFrame.new(0, 20.6, 0), colors.Trim)
		for _, y in { 7, 13 } do
			Kit.prop(m, Vector3.new(4.2, 0.8, 4.2), base * CFrame.new(0, y, 0), shade(colors.Pillar, 0.12))
		end
		local lantern = Kit.prop(m, Vector3.new(1.2, 1.4, 1.2), base * CFrame.new(-side * 2.6, 16, -0.6), theme.Glow or rgb(255, 210, 120), Enum.Material.Neon)
		lantern.Transparency = 0.15
		Kit.prop(m, Vector3.new(1.6, 0.3, 1.6), base * CFrame.new(-side * 2.6, 16.85, -0.6), shade(colors.Trim, 0.2))
		Kit.light(info.Ctx, lantern, theme.Glow or rgb(255, 210, 120), 18, 1.1)
	end
	local beam = CFrame.new(0, gt + 22.4, z)
	Kit.prop(m, Vector3.new(px * 2 + 6, 2.4, 3.2), beam, colors.Beam)
	local board = Kit.prop(info.Model, Vector3.new(24, 7, 0.8), beam * CFrame.new(0, 4.7, 0), colors.Board)
	board.Name = "Arch"
	for _, y in { 1.2, 8.2 } do
		Kit.prop(m, Vector3.new(24.8, 0.6, 1.2), beam * CFrame.new(0, y, 0), colors.Trim)
	end
	for _, x in { -12.2, 12.2 } do
		Kit.prop(m, Vector3.new(0.6, 7.6, 1.2), beam * CFrame.new(x, 4.7, 0), colors.Trim)
	end
	local zone = info.Zone
	-- face avant (vers le spawn) : « Label », face arrière : « LabelBack »
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.text(board, face, if face == Enum.NormalId.Front then "Label" else "LabelBack", {
			{ Text = string.upper(zone.Name), Name = "Title", Color = rgb(255, 255, 255), Weight = 1.5 },
			{ Text = speedText(zone.Speed), Name = "Speed", Color = rgb(255, 226, 110), Weight = 0.75 },
		})
	end
	if theme.ArchTop then
		theme.ArchTop(info, beam)
	end
	m.Parent = info.Model
	Kit.markRect(info.Grid, -px - 8, info.Z0, px + 8, z + 8)
end

-- ===================================================================== gisements et gardien

-- Gisement : pièce SiteN (terre creusée) avec 4 Attachments Slot1..4, rebord, cordes, outils, tas de terre, lanterne
local function digSite(info: Info, folder: Folder, index: number, center: Vector3)
	local theme, gt, rng = info.Theme, info.GroundTop, info.Rng
	local pal = theme.Pal
	local base = CFrame.new(center.X, gt, center.Z)
	local pad = Kit.block(folder, Vector3.new(12, 0.6, 12), base * CFrame.new(0, 0.3, 0), theme.Dirt)
	pad.Name = "Site" .. index
	local slots = Map.SiteSlots
	local spots = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 }, { 0, 0 }, { 0, -6 } }
	for k = 1, math.min(slots, #spots) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Slot" .. k
		attachment.CFrame = CFrame.new(spots[k][1], 0.3 + 1, spots[k][2])
		attachment.Parent = pad
	end
	local m = Kit.group("DigSiteDecor")
	-- rebord de terre en escalier autour de la fosse
	for k = 0, 7 do
		local a = k * math.pi / 4
		local ring = base * CFrame.Angles(0, a, 0)
		Kit.prop(m, Vector3.new(5, Kit.range(rng, 0.8, 1.4), 1.6), ring * CFrame.new(0, 0.5, -6.8), if k % 2 == 0 then theme.Rim else shade(theme.Rim, 0.1))
	end
	-- poteaux et cordes (ouverts du côté du chemin)
	local toPath = if center.X < 0 then math.pi / 2 else -math.pi / 2
	local posts = {}
	for k = 0, 5 do
		local a = toPath + math.pi / 4 + k * (3 * math.pi / 2) / 5
		table.insert(posts, Vector3.new(center.X + math.sin(a) * 9.5, 0, center.Z + math.cos(a) * 9.5))
	end
	local wood, rope = rgb(130, 90, 55), rgb(220, 200, 150)
	for k, p in posts do
		local post = CFrame.new(p.X, gt, p.Z)
		Kit.prop(m, Vector3.new(0.7, 3.2, 0.7), post * CFrame.new(0, 1.6, 0), wood)
		Kit.prop(m, Vector3.new(0.9, 0.3, 0.9), post * CFrame.new(0, 3.3, 0), shade(wood, 0.2))
		local nextPost = posts[k + 1]
		if nextPost then
			local a, b = Vector3.new(p.X, gt + 2.8, p.Z), Vector3.new(nextPost.X, gt + 2.8, nextPost.Z)
			local mid = (a + b) / 2 - Vector3.new(0, 0.6, 0)
			for _, pair in { { a, mid }, { mid, b } } do
				local from, to = pair[1], pair[2]
				local length = (to - from).Magnitude
				Kit.prop(m, Vector3.new(0.25, 0.25, length), CFrame.lookAt((from + to) / 2, to), rope)
			end
		end
	end
	-- outils et terre, côté extérieur
	local out = if center.X < 0 then -1 else 1
	Props.pickaxe(m, CFrame.new(center.X + out * 9, gt, center.Z - 4) * CFrame.Angles(0, out * math.pi / 2, 0), 1, rng, pal)
	Props.shovel(m, CFrame.new(center.X + out * 8.5, gt, center.Z + 3) * CFrame.Angles(0, out * math.pi / 2, 0), 1, rng, pal)
	Props.dirtPile(m, CFrame.new(center.X + out * 12.5, gt, center.Z + Kit.range(rng, -6, -2)), 1, rng, { Dirt = theme.Rim })
	Props.dirtPile(m, CFrame.new(center.X + Kit.range(rng, -4, 4), gt, center.Z + 12), 0.8, rng, { Dirt = theme.Rim })
	if index % 2 == 1 then
		Props.wheelbarrow(m, CFrame.new(center.X + out * 12, gt, center.Z + 6) * CFrame.Angles(0, 0.4, 0), 0.9, rng, { Dirt = theme.Rim })
	else
		Props.bucket(m, CFrame.new(center.X + out * 11, gt, center.Z + 5), 1, rng, { Dirt = theme.Rim })
		Props.crate(m, CFrame.new(center.X + out * 12.5, gt, center.Z + 8), 0.9, rng, pal)
	end
	Props.lantern(m, CFrame.new(center.X - out * 7.5, gt, center.Z - 7.5), 1, info.Ctx, { Glow = theme.Glow or rgb(255, 200, 110) })
	m.Parent = info.Decor
	Kit.markCircle(info.Grid, center.X, center.Z, 16)
end

-- Taille du gardien de la zone (taille de base de l'espèce x Scale), lue dans Config.Guardians et Config.Species
-- (briefs 7 et 2) s'ils existent ; 20 studs sinon
function ZoneBase.GuardianSize(zoneName: string): number
	local config = ReplicatedStorage.Shared.Config
	local guardians = config:FindFirstChild("Guardians")
	local species = config:FindFirstChild("Species")
	if guardians and species and guardians:IsA("ModuleScript") and species:IsA("ModuleScript") then
		local info = ((require :: any)(guardians).Zones or {})[zoneName]
		local def = info and ((require :: any)(species).ByName or {})[info.Species]
		if def and type(def.BaseSize) == "number" and type(info.Scale) == "number" then
			return def.BaseSize * info.Scale
		end
	end
	return 20
end

-- Clairière du gardien : nid à sa taille (anneau de pierres, litière) et point d'ancrage Guardian tourné vers le
-- spawn (-Z)
local function nest(info: Info)
	local theme, gt = info.Theme, info.GroundTop
	local z = info.NestZ
	local radius = math.clamp(ZoneBase.GuardianSize(info.Zone.Name) * 0.5 + 2, 10, Map.Guardian.Radius - 8)
	local m = Kit.group("Nest")
	Kit.disc(m, CFrame.new(0, gt + 0.25, z), radius - 1.5, 0.3, theme.Nest.Bed)
	local count = math.max(12, math.floor(radius * 2 * math.pi / 5.5))
	for k = 0, count - 1 do
		local ring = CFrame.new(0, gt + 0.25, z) * CFrame.Angles(0, k * math.pi * 2 / count, 0)
		local h = if k % 3 == 0 then 2.2 else 1.4
		Kit.prop(m, Vector3.new(5, h, 2.2), ring * CFrame.new(0, h / 2, -radius), if k % 2 == 0 then theme.Nest.Ring else shade(theme.Nest.Ring, 0.12))
	end
	m.Parent = info.Model
	Kit.anchor(info.Model, "Guardian", Vector3.new(8, 0.4, 8), CFrame.new(0, gt + 0.75, z))
	Kit.markCircle(info.Grid, 0, z, Map.Guardian.Radius + 4)
end

-- ===================================================================== décor éparpillé

function ZoneBase.Scatter(info: Info, entry: Scatter)
	local rng, grid, ctx = info.Rng, info.Grid, info.Ctx
	local lo = entry.XMin or (Map.Route.PathWidth / 2 + 4)
	local hi = entry.XMax or (info.HalfWidth - 4)
	local scale = entry.Scale or { 0.85, 1.25 }
	local placed, attempts = 0, entry.Count * 15
	while placed < entry.Count and attempts > 0 do
		attempts -= 1
		local side = entry.Side or (if rng:NextNumber() < 0.5 then -1 else 1)
		local x = side * Kit.range(rng, lo, hi)
		local z = Kit.range(rng, info.Z0 + 14, info.Z1 - 4)
		if Kit.isFree(grid, x, z, entry.Radius) then
			local y = Kit.groundAt(ctx, x, z, info.GroundTop)
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
			entry.Prop(info.Decor, cf, Kit.range(rng, scale[1], scale[2]), rng, entry.Pal)
			Kit.markCircle(grid, x, z, entry.Radius)
			placed += 1
		end
	end
	return placed
end

-- Décor accroché aux parois des falaises (Theme.Wall) : trouvé par un raycast horizontal depuis le couloir, penché
-- vers la route et un peu vers le haut, entre 3 et 12 studs au-dessus du sol. Côté Side seulement s'il est donné.
function ZoneBase.WallScatter(info: Info, entry: Scatter): number
	local rng, gt, hw = info.Rng, info.GroundTop, info.HalfWidth
	local scale = entry.Scale or { 0.85, 1.25 }
	local placed, attempts = 0, entry.Count * 4
	while placed < entry.Count and attempts > 0 do
		attempts -= 1
		local side = entry.Side or (if rng:NextNumber() < 0.5 then -1 else 1)
		local z = Kit.range(rng, info.Z0 + 12, info.Z1 - 8)
		local y = gt + Kit.range(rng, 3, 12)
		-- pas devant un lieu marquant (cascade, galerie de mine...) ni sur un gros volume entre le couloir et la paroi
		local x = if Kit.isFree(info.Grid, side * (hw - 1), z, 2) then Kit.wallAt(info.Ctx, side, hw - 24, y, z, side * (hw + 1), hw - 1) else nil
		if x then
			local cf = CFrame.new(x + side * 0.5, y, z) * CFrame.Angles(0, 0, side * math.rad(Kit.range(rng, 62, 74))) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
			entry.Prop(info.Decor, cf, Kit.range(rng, scale[1], scale[2]), rng, entry.Pal)
			placed += 1
		end
	end
	return placed
end

-- Place libre pour un lieu marquant : disque de `radius` studs, X entre xMin et xMax de l'axe (côté `side` ou au
-- hasard), à une fraction de la longueur entre tMin et tMax ; marque la place prise. nil si rien n'est libre.
function ZoneBase.Spot(info: Info, radius: number, xMin: number, xMax: number, tMin: number, tMax: number, side: number?): Vector3?
	local rng = info.Rng
	for _ = 1, 80 do
		local s = side or (if rng:NextNumber() < 0.5 then -1 else 1)
		local x = s * Kit.range(rng, xMin, xMax)
		local z = info.Z0 + info.Length * Kit.range(rng, tMin, tMax)
		if Kit.isFree(info.Grid, x, z, radius) then
			Kit.markCircle(info.Grid, x, z, radius)
			return Vector3.new(x, Kit.groundAt(info.Ctx, x, z, info.GroundTop), z)
		end
	end
	return nil
end

-- ===================================================================== zone

-- Construit la zone `zone` de z0 à z0 + length dans `parent`, avec le thème `theme`
function ZoneBase.Build(zone: Zones.Zone, theme: Theme, z0: number, length: number, parent: Instance, rng: Random): Model
	local gt = Map.GroundTop
	local hw, border = Map.Route.Width / 2, Map.Route.Border
	local model = Instance.new("Model")
	model.Name = zone.Name
	model.Parent = parent
	local groundFolder = Kit.folder("Ground", model)
	local decor = Kit.folder("Decor", model)
	local ctx: Kit.Ctx = {
		Rng = rng,
		Lights = 0,
		LightBudget = Map.Lights.Zone,
		Grid = nil,
		Ray = Kit.rayTo({ groundFolder }),
		GroundTop = gt,
	}
	local grid = Kit.grid(-hw - border, z0, hw + border, z0 + length, 4)
	ctx.Grid = grid
	local sites = {}
	for _, site in Map.Sites do
		table.insert(sites, Vector3.new(site.X, gt, z0 + site.T * length))
	end
	local info: Info = {
		Zone = zone,
		Theme = theme,
		Model = model,
		Ground = groundFolder,
		Decor = decor,
		Z0 = z0,
		Z1 = z0 + length,
		Length = length,
		HalfWidth = hw,
		Border = border,
		GroundTop = gt,
		Ctx = ctx,
		Grid = grid,
		Rng = rng,
		NestZ = z0 + Map.Guardian.T * length,
		Sites = sites,
	}

	-- étendue de la zone (ZoneService : boîte de 20 studs dessous à 300 au-dessus)
	local area = Kit.anchor(model, "Area", Vector3.new((hw + border) * 2, 1, length), CFrame.new(0, gt - 0.5, z0 + length / 2))
	model.PrimaryPart = area

	ground(info)
	path(info)
	Kit.markRect(grid, -Map.Route.PathWidth / 2 - 3, z0, Map.Route.PathWidth / 2 + 3, z0 + length)
	for _, site in sites do
		local side = if site.X < 0 then -1 else 1
		Kit.markRect(grid, side * (Map.Route.PathWidth / 2), site.Z - 5, site.X, site.Z + 5)
	end
	for _, side in { -1, 1 } do
		if not (theme.Border and theme.Border(info, side)) then
			ZoneBase.Cliffs(info, side)
		end
	end
	arch(info)
	local folder = Kit.folder("DigSites", model)
	for index, site in sites do
		digSite(info, folder, index, site)
	end
	nest(info)
	if theme.Landmark then
		theme.Landmark(info)
	end
	for _, entry in theme.Scatter do
		ZoneBase.Scatter(info, entry)
	end
	local wall: { Scatter } = theme.Wall or {}
	for _, entry in wall do
		ZoneBase.WallScatter(info, entry)
	end
	return model
end

return ZoneBase
