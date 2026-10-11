--!strict
-- Zone 6 : Volcano. Basalte sombre, deux coulées de lave le long de la route, falaises noires avec des traînées de
-- lave, roches fissurées, souches calcinées, aiguilles d'obsidienne et le grand volcan derrière la falaise droite, avec
-- son panache de fumée ; mares et fontaines de lave, fumerolles qui crachent de la vapeur, géodes et cristaux couleur
-- braise (rouge, orange, jaune).

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local BASALT = rgb(56, 48, 50)
local LAVA = rgb(255, 112, 32)
local EMBER_GLOW = { Crystal = rgb(255, 84, 40), Crystal2 = rgb(255, 160, 40), Crystal3 = rgb(255, 222, 90), Rock = rgb(40, 34, 38) }

local function lava(parent: Instance, size: Vector3, cframe: CFrame): Part
	local part = Kit.prop(parent, size, cframe, LAVA, Enum.Material.Neon)
	part.Transparency = 0.12
	return part
end

local function archTop(info: ZoneBase.Info, beam: CFrame)
	for _, x in { -9, -3, 4, 10 } do
		lava(info.Model, Vector3.new(0.6, 2.4, 0.4), beam * CFrame.new(x, -0.4, -1.75))
		lava(info.Model, Vector3.new(0.6, 2.4, 0.4), beam * CFrame.new(x + 1, -0.4, 1.75))
	end
end

local function landmark(info: ZoneBase.Info)
	local gt, hw, border, rng = info.GroundTop, info.HalfWidth, info.Border, info.Rng
	-- coulées de lave parallèles à la route
	local first: Part? = nil
	for _, side in { -1, 1 } do
		local x = side * 79
		local z0, z1 = info.Z0 + 14, info.Z1 - 2
		local stream = lava(info.Decor, Vector3.new(6, 0.2, z1 - z0), CFrame.new(x, gt + 0.15, (z0 + z1) / 2))
		first = first or stream
		local z = z0
		while z < z1 - 4 do
			local length = Kit.range(rng, 5, 12)
			for _, edge in { -1, 1 } do
				Kit.prop(info.Decor, Vector3.new(Kit.range(rng, 1.2, 2), Kit.range(rng, 0.5, 1.1), math.min(length, z1 - z)), CFrame.new(x + edge * 3.6, gt + 0.4, z + length / 2), shade(BASALT, Kit.range(rng, -0.1, 0.15)))
			end
			z += length
		end
		Kit.markRect(info.Grid, x - 5, z0, x + 5, z1)
	end
	if first then
		Kit.light(info.Ctx, first, LAVA, 24, 1.2)
	end
	-- traînées de lave sur les falaises
	for _ = 1, 6 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local z = Kit.range(rng, info.Z0 + 20, info.Z1 - 10)
		local h = Kit.range(rng, 6, 12)
		lava(info.Decor, Vector3.new(0.4, h, 1.2), CFrame.new(side * (hw + 0.4), gt + h / 2, z))
	end
	-- le grand volcan, derrière la falaise droite
	-- (16 gradins irréguliers, cratère de lave, coulée qui descend la pente tournée vers la route)
	local vx, vz = hw + border + 110, info.Z0 + info.Length * 0.5
	local tiers, step = 16, 7.5
	local top = gt - 2 + tiers * step
	for k = 0, tiers - 1 do
		local t = k / (tiers - 1)
		local r = 92 * (1 - t * 0.76) + Kit.range(rng, -3, 3)
		local y = gt - 2 + k * step
		Kit.disc(info.Decor, CFrame.new(vx + Kit.range(rng, -2, 2), y, vz + Kit.range(rng, -2, 2)), r, step, if k % 3 == 2 then shade(BASALT, -0.08) else BASALT)
		if k >= 3 then
			lava(info.Decor, Vector3.new(7, step + 0.4, 6 - t * 2), CFrame.new(vx - r + 2.5, y + step / 2 + 0.1, vz - 4 + (k % 2) * 2))
		end
	end
	lava(info.Decor, Vector3.new(30, 1, 30), CFrame.new(vx, top + 0.3, vz))
	-- panache de fumée au-dessus du cratère : gros cubes gris de plus en plus clairs et transparents, qui penchent avec
	-- le vent (le premier, rougi par la lave)
	local plume = Kit.group("SmokePlume")
	for k = 0, 8 do
		local size = 16 + k * 4
		local center = CFrame.new(vx + 6 + k * 4, top + 10 + k * 12, vz - k * 2.5) * CFrame.Angles(0, k * 0.5, 0)
		local tone = if k == 0 then rgb(130, 74, 60) else rgb(84, 78, 80):Lerp(rgb(170, 164, 166), k / 8)
		Kit.prop(plume, Vector3.new(size, size * 0.8, size), center, tone, Enum.Material.SmoothPlastic).Transparency = 0.3 + k * 0.05
		Kit.prop(plume, Vector3.new(size * 0.6, size * 0.5, size * 0.6), center * CFrame.new(size * 0.45, size * 0.2, size * 0.2), shade(tone, -0.08), Enum.Material.SmoothPlastic).Transparency = 0.35 + k * 0.05
	end
	plume.Parent = info.Decor
end

local theme: ZoneBase.Theme = {
	Ground = rgb(62, 54, 54),
	Patches = { rgb(50, 44, 46), rgb(76, 66, 64), rgb(92, 62, 52) },
	Path = rgb(116, 100, 94),
	PathEdge = rgb(70, 60, 58),
	Cliff = { BASALT, rgb(72, 60, 58), rgb(96, 72, 62) },
	CliffTop = rgb(44, 40, 42),
	CliffScale = 1.2,
	Arch = { Pillar = rgb(64, 54, 54), Beam = rgb(46, 40, 42), Board = rgb(150, 48, 28), Trim = rgb(255, 150, 60) },
	Dirt = rgb(80, 60, 52),
	Rim = rgb(98, 76, 64),
	Nest = { Ring = rgb(72, 62, 60), Bed = rgb(112, 82, 62) },
	Glow = rgb(255, 160, 70),
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.lavaPool, Count = 4, Radius = 6, XMin = 34, XMax = 70, Scale = { 0.9, 1.3 }, Pal = { Glow = LAVA, Rock = BASALT } },
		{ Prop = Props.lavaGeyser, Count = 3, Radius = 5, XMin = 34, XMax = 70, Scale = { 0.9, 1.2 }, Pal = { Glow = LAVA, Rock = BASALT } },
		{ Prop = Props.steamVent, Count = 6, Radius = 4, Scale = { 0.9, 1.3 }, Pal = { Rock = rgb(64, 54, 56), Glow = LAVA } },
		{ Prop = Props.geode, Count = 3, Radius = 5, XMin = 36, XMax = 70, Scale = { 0.9, 1.2 }, Pal = { Rock = rgb(64, 54, 56), Crystal = EMBER_GLOW.Crystal, Crystal2 = EMBER_GLOW.Crystal2, Crystal3 = EMBER_GLOW.Crystal3 } },
		{ Prop = Props.glowCrystal, Count = 5, Radius = 3.5, Scale = { 0.7, 1.1 }, Pal = EMBER_GLOW },
		{ Prop = Props.glowCrystal, Count = 4, Radius = 4, XMin = 104, XMax = 122, Scale = { 1.1, 1.5 }, Pal = EMBER_GLOW },
		{ Prop = Props.lavaRock, Count = 24, Radius = 4 },
		{ Prop = Props.deadTree, Count = 12, Radius = 5, XMin = 30, Pal = { Trunk = rgb(40, 34, 34) } },
		{ Prop = Props.stump, Count = 12, Radius = 3, Pal = { Trunk = rgb(36, 32, 32), Ring = rgb(255, 120, 40) } },
		{ Prop = Props.rock, Count = 14, Radius = 4, Pal = { Rock = rgb(72, 64, 64) } },
		{ Prop = Props.spike, Count = 14, Radius = 3, Scale = { 1, 1.6 }, Pal = { Ice = rgb(40, 30, 52) } },
		{ Prop = Props.lavaRock, Count = 8, Radius = 5, XMin = 104, XMax = 122, Scale = { 1.2, 1.6 } },
	},
	Wall = {
		{ Prop = Props.glowCrystal, Count = 5, Radius = 0, Scale = { 0.6, 1 }, Pal = EMBER_GLOW },
	},
}

return theme
