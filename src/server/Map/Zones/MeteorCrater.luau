--!strict
-- Zone 8 : Meteor Crater. Sol violet sombre, le gardien dort au fond du grand cratère (rebord en escalier, fissures
-- lumineuses), une météorite géante à demi enterrée, petits cratères, cristaux lumineux, aiguilles et rochers ; éclats
-- de cristal qui flottent au-dessus du grand cratère, camp des chercheurs (télescope, tente, tableau), éclats de
-- météorite fendus qui luisent, rochers qui flottent, flèche de cristaux géants et cristaux de toutes les couleurs.

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local ROCK = rgb(66, 54, 84)
local GREEN = rgb(70, 230, 120)
local PURPLE = rgb(160, 90, 255)
local STAR_GLOW = { Crystal = rgb(190, 110, 255), Crystal2 = rgb(90, 220, 255), Crystal3 = rgb(255, 120, 220), Crystal4 = rgb(120, 255, 170), Rock = ROCK }
local GOLD = { Crystal = rgb(255, 214, 90), Crystal2 = rgb(255, 180, 60), Rock = ROCK }

local function glow(parent: Instance, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Kit.prop(parent, size, cframe, color, Enum.Material.Neon)
	part.Transparency = 0.35
	return part
end

local function archTop(info: ZoneBase.Info, beam: CFrame)
	for _, side in { -1, 1 } do
		Props.crystals(info.Model, beam * CFrame.new(side * 12, 8.6, 0), 1, info.Rng, { Crystal = PURPLE, Glow = GREEN, Rock = ROCK })
	end
end

-- Camp des chercheurs qui étudient la météorite : tente, télescope sur trépied pointé vers le ciel, caisses, tableau
-- couvert de calculs
local function researchCamp(info: ZoneBase.Info, spot: Vector3)
	local rng = info.Rng
	local m = Kit.group("ResearchCamp")
	local base = CFrame.new(spot) * CFrame.Angles(0, math.rad(Kit.range(rng, 0, 360)), 0)
	Props.tent(m, base * CFrame.new(-5, 0, 2), 0.9, rng, { Cloth = rgb(120, 150, 190) })
	local scope = base * CFrame.new(5, 0, -2)
	for k = 0, 2 do
		local leg = scope * CFrame.Angles(0, k * math.pi * 2 / 3, 0) * CFrame.new(0, 2.2, -0.9) * CFrame.Angles(math.rad(20), 0, 0)
		Kit.prop(m, Vector3.new(0.3, 4.6, 0.3), leg, rgb(70, 70, 80))
	end
	local tube = scope * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(40), math.rad(30), 0)
	Kit.prop(m, Vector3.new(1.3, 1.3, 6), tube, rgb(220, 220, 230))
	Kit.prop(m, Vector3.new(1.6, 1.6, 0.8), tube * CFrame.new(0, 0, -3), rgb(60, 60, 70))
	Kit.prop(m, Vector3.new(0.6, 0.6, 1), tube * CFrame.new(0, 0, 3.4), rgb(60, 60, 70))
	Props.crate(m, base * CFrame.new(1, 0, 5), 0.8, rng, nil)
	Props.crate(m, base * CFrame.new(2.8, 0, 6.6) * CFrame.Angles(0, 0.4, 0), 0.6, rng, nil)
	local board = base * CFrame.new(0, 0, -6)
	for _, x in { -2.4, 2.4 } do
		Kit.prop(m, Vector3.new(0.4, 5, 0.4), board * CFrame.new(x, 2.5, 0), rgb(110, 80, 50))
	end
	Kit.prop(m, Vector3.new(4.6, 3, 0.3), board * CFrame.new(0, 3.6, 0), rgb(40, 50, 46))
	for k = 0, 2 do
		glow(m, Vector3.new(3.6 - k * 0.8, 0.2, 0.1), board * CFrame.new(-0.2 + k * 0.2, 4.6 - k * 0.8, -0.2), GREEN)
	end
	m.Parent = info.Decor
end

-- Petit cratère : anneau en escalier et fond brûlé
local function crater(info: ZoneBase.Info, x: number, z: number, radius: number)
	local gt = info.GroundTop
	local m = Kit.group("Crater")
	Kit.disc(m, CFrame.new(x, gt + 0.05, z), radius, 0.2, rgb(44, 36, 52))
	local count = math.max(8, math.floor(radius * 1.6))
	for k = 0, count - 1 do
		local ring = CFrame.new(x, gt, z) * CFrame.Angles(0, k * math.pi * 2 / count, 0)
		local h = if k % 2 == 0 then 1.6 else 1.1
		Kit.prop(m, Vector3.new(radius * 0.9, h, 1.6), ring * CFrame.new(0, h / 2, -radius - 0.6), if k % 2 == 0 then ROCK else shade(ROCK, -0.12))
	end
	m.Parent = info.Decor
	Kit.markCircle(info.Grid, x, z, radius + 3)
end

local function landmark(info: ZoneBase.Info)
	local gt, rng = info.GroundTop, info.Rng
	-- grand cratère autour de la clairière du gardien (ouvert là où passe le chemin)
	local z = info.NestZ
	local radius = 36
	local m = Kit.group("CraterRim")
	for k = 0, 23 do
		local a = k * math.pi * 2 / 24
		local facing = math.abs(math.cos(a))
		if facing < 0.9 then
			local ring = CFrame.new(0, gt, z) * CFrame.Angles(0, a + math.pi / 2, 0)
			Kit.prop(m, Vector3.new(10, 2.6, 4), ring * CFrame.new(0, 1.3, -radius), ROCK)
			Kit.prop(m, Vector3.new(8, 2, 3), ring * CFrame.new(0, 3.6, -radius - 0.6), shade(ROCK, -0.12))
			Kit.prop(m, Vector3.new(10, 1.6, 4), ring * CFrame.new(0, 0.8, -radius - 4), shade(ROCK, 0.15))
		end
	end
	m.Parent = info.Decor
	Kit.disc(info.Decor, CFrame.new(0, gt + 0.25, z), 24, 0.1, rgb(56, 44, 68))
	for k = 0, 5 do
		local crack = CFrame.new(0, gt + 0.38, z) * CFrame.Angles(0, k * math.pi / 3 + 0.3, 0)
		glow(info.Decor, Vector3.new(0.5, 0.06, Kit.range(rng, 7, 9)), crack * CFrame.new(0, 0, -28), if k % 2 == 0 then GREEN else PURPLE)
	end
	-- météorite géante à demi enterrée
	local mx, mz = -70, info.Z0 + info.Length * 0.52
	crater(info, mx, mz, 13)
	for _, part in Kit.dome(info.Ground, CFrame.new(mx, gt - 2, mz), 11, 14, 4, rgb(48, 40, 56), nil, true) do
		Kit.solid(part)
	end
	-- éclats rocheux qui dépassent de la météorite
	for k = 0, 4 do
		local a = k * 1.25 + 0.4
		local chunk = CFrame.new(mx + math.cos(a) * 7, gt + 4 + (k % 2) * 3, mz + math.sin(a) * 7) * CFrame.Angles(math.cos(a) * 0.5, a, math.sin(a) * 0.5)
		Kit.solid(Kit.block(info.Ground, Vector3.new(5, 6, 4), chunk, if k % 2 == 0 then rgb(40, 34, 48) else rgb(60, 50, 70)))
	end
	local core = glow(info.Decor, Vector3.new(2, 7, 2), CFrame.new(mx + 3, gt + 7, mz - 5) * CFrame.Angles(0.3, 0.2, 0.2), GREEN)
	glow(info.Decor, Vector3.new(1.6, 5, 1.6), CFrame.new(mx - 5, gt + 6, mz + 2) * CFrame.Angles(-0.2, 0, 0.4), PURPLE)
	glow(info.Decor, Vector3.new(1.2, 4, 1.2), CFrame.new(mx + 1, gt + 10.5, mz + 3) * CFrame.Angles(0.2, 0, -0.3), GREEN)
	Kit.light(info.Ctx, core, GREEN, 26, 1.4)
	Kit.markCircle(info.Grid, mx, mz, 20)
	-- petits cratères
	local made = 0
	for _ = 1, 60 do
		if made >= 6 then
			break
		end
		local r = Kit.range(rng, 3.5, 6)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, zz = side * Kit.range(rng, 22, 80), Kit.range(rng, info.Z0 + 20, info.Z1 - 10)
		if Kit.isFree(info.Grid, x, zz, r + 3) then
			crater(info, x, zz, r)
			made += 1
		end
	end
	-- éclats de cristal qui flottent au-dessus du rebord du grand cratère
	local colors = { STAR_GLOW.Crystal, STAR_GLOW.Crystal2, STAR_GLOW.Crystal3, STAR_GLOW.Crystal4 }
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		local at = CFrame.new(math.cos(a) * 31, gt, z + math.sin(a) * 31)
		Props.floatShard(info.Decor, at, Kit.range(rng, 0.9, 1.3), rng, { Crystal = colors[k % #colors + 1] })
	end
	-- flèche de cristaux géants
	local spire = ZoneBase.Spot(info, 16, 50, 76, 0.15, 0.4, 1)
	if spire then
		Props.glowCrystal(info.Decor, CFrame.new(spire), 3.2, rng, STAR_GLOW)
		for k = 0, 1 do
			local a = k * math.pi + rng:NextNumber()
			Props.glowCrystal(info.Decor, CFrame.new(spire + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)), 1.8, rng, if k == 0 then GOLD else STAR_GLOW)
		end
	end
	-- camp des chercheurs, près de la météorite géante
	local camp = ZoneBase.Spot(info, 13, 30, 56, 0.62, 0.86, -1)
	if camp then
		researchCamp(info, camp)
	end
end

local theme: ZoneBase.Theme = {
	Ground = rgb(94, 76, 114),
	Patches = { rgb(78, 60, 98), rgb(112, 92, 132), rgb(70, 64, 84) },
	Path = rgb(150, 136, 168),
	PathEdge = rgb(90, 70, 110),
	Cliff = { rgb(62, 50, 78), rgb(84, 66, 106), rgb(110, 88, 132) },
	CliffTop = rgb(52, 42, 64),
	CliffScale = 1.3,
	Arch = { Pillar = rgb(72, 58, 92), Beam = rgb(54, 44, 70), Board = rgb(38, 28, 58), Trim = GREEN },
	Dirt = rgb(70, 56, 66),
	Rim = rgb(98, 82, 102),
	Nest = { Ring = rgb(60, 50, 70), Bed = rgb(92, 72, 92) },
	Glow = PURPLE,
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.meteorite, Count = 6, Radius = 4.5, XMin = 30, Scale = { 0.9, 1.3 }, Pal = { Rock = rgb(40, 34, 48), Glow = GREEN } },
		{ Prop = Props.floatRock, Count = 8, Radius = 3, Scale = { 0.8, 1.3 }, Pal = { Rock = rgb(80, 64, 96), Glow = PURPLE } },
		{ Prop = Props.boulder, Count = 7, Radius = 6, XMin = 40, Pal = { Rock = rgb(80, 64, 96) } },
		{ Prop = Props.crystals, Count = 16, Radius = 3.5, Scale = { 0.9, 1.5 }, Pal = { Crystal = PURPLE, Glow = GREEN, Rock = ROCK } },
		{ Prop = Props.crystals, Count = 6, Radius = 3.5, Pal = { Crystal = rgb(110, 220, 160), Glow = PURPLE, Rock = ROCK } },
		{ Prop = Props.glowCrystal, Count = 6, Radius = 3.5, Scale = { 0.7, 1.2 }, Pal = STAR_GLOW },
		{ Prop = Props.glowCrystal, Count = 3, Radius = 3.5, Scale = { 0.7, 1 }, Pal = GOLD },
		{ Prop = Props.glowCrystal, Count = 4, Radius = 4, XMin = 104, XMax = 122, Scale = { 1.3, 1.8 }, Pal = STAR_GLOW },
		{ Prop = Props.spike, Count = 12, Radius = 3, Scale = { 1, 1.8 }, Pal = { Ice = rgb(120, 82, 182) } },
		{ Prop = Props.rock, Count = 18, Radius = 4, Pal = { Rock = rgb(62, 52, 72) } },
		{ Prop = Props.lavaRock, Count = 8, Radius = 4, Pal = { Rock = rgb(44, 38, 52), Glow = GREEN } },
		{ Prop = Props.crystals, Count = 8, Radius = 4, XMin = 104, XMax = 122, Scale = { 1.4, 2 }, Pal = { Crystal = PURPLE, Glow = GREEN, Rock = ROCK } },
	},
	Wall = {
		{ Prop = Props.glowCrystal, Count = 6, Radius = 0, Scale = { 0.6, 1.1 }, Pal = STAR_GLOW },
	},
}

return theme
