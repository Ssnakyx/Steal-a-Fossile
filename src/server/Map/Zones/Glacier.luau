--!strict
-- Zone 5 : Glacier. Neige, sentier de glace bleue, falaises de glace, sapins enneigés, pointes de glace, congères,
-- lac gelé avec ses fissures, cascade gelée sur la falaise droite et blocs de glace géants ; squelette fossile pris
-- dans un bloc de glace (le crâne dépasse), camp polaire (igloos, feu de camp, traîneau), bonshommes de neige,
-- bosquet de grands cristaux et cristaux couleur aurore (cyan, menthe, violet).

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local SNOW = rgb(244, 248, 252)
local ICE = rgb(170, 216, 242)
local ICE_GLOW = { Crystal = rgb(110, 236, 255), Crystal2 = rgb(150, 255, 210), Crystal3 = rgb(196, 150, 255), Crystal4 = rgb(236, 250, 255), Rock = rgb(150, 172, 196) }
local BONE = { Bone = rgb(226, 222, 206) }

-- Squelette fossile pris dans un bloc de glace translucide, le crâne qui dépasse devant, neige dessus, éclats de
-- glace et cristaux autour
local function frozenFossil(info: ZoneBase.Info, spot: Vector3)
	local rng = info.Rng
	local base = CFrame.new(spot) * CFrame.Angles(0, math.rad(Kit.range(rng, 20, 60)), 0)
	local block = Kit.solid(Kit.block(info.Ground, Vector3.new(15, 11, 21), base * CFrame.new(0, 5.5, 1.5), rgb(176, 222, 246), Enum.Material.Ice))
	block.Transparency = 0.5
	block.CastShadow = false
	Props.ribcage(info.Decor, base * CFrame.new(0, 1.6, 3), 1, rng, BONE)
	Props.skull(info.Decor, base * CFrame.new(0, 1.2, -10.5) * CFrame.Angles(math.rad(-6), 0, 0), 1, rng, BONE)
	Kit.prop(info.Decor, Vector3.new(15.4, 1.2, 21.4), base * CFrame.new(0, 11.4, 1.5), SNOW)
	Kit.prop(info.Decor, Vector3.new(9, 1, 12), base * CFrame.new(-2, 12.4, 3), shade(SNOW, -0.04))
	for k = 0, 3 do
		local a = k * 1.6 + rng:NextNumber() * 0.6
		local size = Vector3.new(Kit.range(rng, 1.6, 3), Kit.range(rng, 1.2, 2.4), Kit.range(rng, 1.6, 3))
		Kit.prop(info.Decor, size, base * CFrame.new(math.cos(a) * 11, size.Y / 2, 1.5 + math.sin(a) * 13) * CFrame.Angles(0, a, 0), if k % 2 == 0 then ICE else SNOW)
	end
	for _, offset in { Vector3.new(9, 0, 9), Vector3.new(-9.5, 0, -6) } do
		Props.glowCrystal(info.Decor, base * CFrame.new(offset), Kit.range(rng, 1, 1.3), rng, ICE_GLOW)
	end
end

-- Igloo en blocs de neige (solide), entrée en tunnel, lueur chaude au fond de la porte
local function igloo(info: ZoneBase.Info, decor: Instance, cf: CFrame, r: number)
	for _, part in Kit.dome(info.Ground, cf, r, r * 0.8, 4, SNOW, nil, true) do
		Kit.solid(part)
	end
	Kit.solid(Kit.block(info.Ground, Vector3.new(3.6, 3.2, 4), cf * CFrame.new(0, 1.6, -r - 0.6), shade(SNOW, 0.04)))
	local door = Kit.prop(decor, Vector3.new(2.2, 2.4, 0.2), cf * CFrame.new(0, 1.2, -r - 2.65), rgb(255, 170, 90), Enum.Material.Neon)
	door.Transparency = 0.35
end

-- Camp polaire : deux igloos, feu de camp (flammes Neon, pierres, bûches), traîneau chargé, bonhomme de neige
local function polarCamp(info: ZoneBase.Info, spot: Vector3)
	local rng = info.Rng
	local m = Kit.group("PolarCamp")
	local base = CFrame.new(spot) * CFrame.Angles(0, math.rad(Kit.range(rng, 0, 360)), 0)
	igloo(info, m, base * CFrame.new(-6, 0, 3), 5.5)
	igloo(info, m, base * CFrame.new(7, 0, 5) * CFrame.Angles(0, math.rad(-35), 0), 4.2)
	local fire = base * CFrame.new(0, 0, -6)
	for k = 0, 5 do
		Kit.prop(m, Vector3.new(1.2, 0.7, 1), fire * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0.35, -1.8), rgb(120, 126, 136))
	end
	for k = 0, 2 do
		Kit.prop(m, Vector3.new(0.6, 0.6, 3), fire * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0.5, 0), rgb(110, 76, 46))
	end
	local flame = Kit.prop(m, Vector3.new(1.4, 1.8, 1.4), fire * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.pi / 4, 0), rgb(255, 140, 40), Enum.Material.Neon)
	flame.Transparency = 0.15
	Kit.prop(m, Vector3.new(0.8, 1.4, 0.8), fire * CFrame.new(0, 2.4, 0), rgb(255, 220, 110), Enum.Material.Neon).Transparency = 0.1
	local sled = base * CFrame.new(8, 0, -6) * CFrame.Angles(0, math.rad(20), 0)
	for _, x in { -1, 1 } do
		Kit.prop(m, Vector3.new(0.3, 0.3, 6), sled * CFrame.new(x * 1.2, 0.15, 0), rgb(90, 64, 40))
		Kit.prop(m, Vector3.new(0.3, 1.2, 0.3), sled * CFrame.new(x * 1.2, 0.6, -2.9), rgb(90, 64, 40))
	end
	Kit.prop(m, Vector3.new(3, 0.3, 5), sled * CFrame.new(0, 0.9, 0.3), rgb(150, 104, 62))
	Props.crate(m, sled * CFrame.new(0, 1.05, 0.8), 0.6, rng, nil)
	Props.snowman(m, base * CFrame.new(-2, 0, -12), 1, rng, { Snow = SNOW })
	m.Parent = info.Decor
end

-- Bosquet de grands cristaux lumineux sur un tapis de neige
local function crystalGrove(info: ZoneBase.Info, spot: Vector3)
	local rng = info.Rng
	Kit.disc(info.Decor, CFrame.new(spot) * CFrame.new(0, 0.05, 0), 10, 0.3, shade(SNOW, -0.03))
	Props.glowCrystal(info.Decor, CFrame.new(spot), 2.2, rng, ICE_GLOW)
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5 + rng:NextNumber() * 0.4
		Props.glowCrystal(info.Decor, CFrame.new(spot + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)), Kit.range(rng, 0.9, 1.4), rng, ICE_GLOW)
	end
end

local function archTop(info: ZoneBase.Info, beam: CFrame)
	for k = -6, 6 do
		local h = 1.4 + ((k * 5) % 4) * 0.7
		Kit.prop(info.Model, Vector3.new(0.8, h, 0.8), beam * CFrame.new(k * 2.6, -1.2 - h / 2, 0), if k % 2 == 0 then ICE else shade(ICE, -0.25))
	end
	Kit.prop(info.Model, Vector3.new(30, 1, 3.6), beam * CFrame.new(0, 9, 0), SNOW)
end

local function landmark(info: ZoneBase.Info)
	local gt, hw, rng = info.GroundTop, info.HalfWidth, info.Rng
	-- lac gelé à gauche, avec fissures et blocs de glace sur la rive
	local lx, lz = -64, info.Z0 + info.Length * 0.6
	for _, part in Kit.disc(info.Decor, CFrame.new(lx, gt + 0.05, lz), 20, 0.2, rgb(150, 206, 236), Enum.Material.SmoothPlastic) do
		part.Transparency = 0.1
	end
	for k = 0, 4 do
		local crack = CFrame.new(lx, gt + 0.27, lz) * CFrame.Angles(0, k * 1.3, 0)
		Kit.prop(info.Decor, Vector3.new(0.3, 0.05, Kit.range(rng, 8, 16)), crack * CFrame.new(0, 0, -Kit.range(rng, 3, 8)), rgb(235, 248, 255), Enum.Material.SmoothPlastic)
	end
	for k = 0, 5 do
		local a = k * 1.05 + rng:NextNumber() * 0.5
		local x, z = lx + math.cos(a) * 22, lz + math.sin(a) * 22
		Kit.prop(info.Decor, Vector3.new(Kit.range(rng, 2, 4), Kit.range(rng, 1.5, 3), Kit.range(rng, 2, 4)), CFrame.new(x, gt + 1, z) * CFrame.Angles(0, a, 0), if k % 2 == 0 then ICE else SNOW)
	end
	Kit.markCircle(info.Grid, lx, lz, 25)
	-- cascade gelée sur la falaise droite
	local fz = info.Z0 + info.Length * 0.24
	for k = 0, 5 do
		local w = 9 - k * 0.6
		Kit.prop(info.Decor, Vector3.new(2 + k * 0.4, 4, w), CFrame.new(hw + 1 + k * 0.5, gt + 2 + k * 4, fz), if k % 2 == 0 then ICE else shade(ICE, -0.2))
	end
	Kit.dome(info.Decor, CFrame.new(hw - 3, gt, fz), 6, 3, 2, shade(ICE, -0.1))
	Kit.markCircle(info.Grid, hw - 3, fz, 9)
	-- blocs de glace géants
	for _, spot in { { 74, 0.9 }, { -76, 0.2 } } do
		local x, z = spot[1], info.Z0 + info.Length * spot[2]
		if Kit.isFree(info.Grid, x, z, 9) then
			local base = CFrame.new(x, gt, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
			Kit.solid(Kit.block(info.Ground, Vector3.new(10, 12, 9), base * CFrame.new(0, 6, 0), ICE, Enum.Material.Ice))
			Kit.solid(Kit.block(info.Ground, Vector3.new(7, 6, 6), base * CFrame.new(4, 3, 4), shade(ICE, -0.2), Enum.Material.Ice))
			Kit.prop(info.Decor, Vector3.new(10.4, 1, 9.4), base * CFrame.new(0, 12.5, 0), SNOW)
			Kit.markCircle(info.Grid, x, z, 10)
		end
	end
	-- fossile pris dans la glace (à droite), bosquet de cristaux (à gauche)
	local fossil = ZoneBase.Spot(info, 15, 44, 76, 0.36, 0.56, 1)
	if fossil then
		frozenFossil(info, fossil)
	end
	local grove = ZoneBase.Spot(info, 12, 44, 76, 0.76, 0.94, -1)
	if grove then
		crystalGrove(info, grove)
	end
	-- camp polaire
	local camp = ZoneBase.Spot(info, 17, 40, 72, 0.06, 0.32, nil)
	if camp then
		polarCamp(info, camp)
	end
end

local theme: ZoneBase.Theme = {
	Ground = rgb(216, 230, 242),
	Patches = { rgb(202, 220, 238), rgb(232, 240, 248), rgb(190, 214, 236) },
	Path = rgb(158, 198, 228),
	PathEdge = rgb(150, 190, 220),
	Cliff = { rgb(150, 192, 222), rgb(188, 220, 240), rgb(220, 236, 248) },
	CliffTop = SNOW,
	Arch = { Pillar = rgb(172, 214, 240), Beam = rgb(140, 190, 226), Board = rgb(64, 116, 178), Trim = rgb(240, 250, 255) },
	Dirt = rgb(118, 108, 108),
	Rim = rgb(204, 222, 236),
	Nest = { Ring = rgb(150, 190, 220), Bed = rgb(232, 242, 250) },
	Glow = rgb(176, 224, 255),
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.pine, Count = 24, Radius = 5, XMin = 36, Scale = { 1, 1.5 }, Pal = { Leaf = rgb(52, 110, 84), Snow = SNOW } },
		{ Prop = Props.pine, Count = 10, Radius = 5, XMin = 104, XMax = 122, Scale = { 1.2, 1.7 }, Pal = { Leaf = rgb(52, 110, 84), Snow = SNOW } },
		{ Prop = Props.snowman, Count = 3, Radius = 4, XMin = 30, XMax = 80, Scale = { 0.9, 1.2 }, Pal = { Snow = SNOW } },
		{ Prop = Props.glowCrystal, Count = 5, Radius = 3.5, Scale = { 0.7, 1.1 }, Pal = ICE_GLOW },
		{ Prop = Props.glowCrystal, Count = 4, Radius = 4, XMin = 104, XMax = 122, Scale = { 1.1, 1.5 }, Pal = ICE_GLOW },
		{ Prop = Props.spike, Count = 22, Radius = 3, Scale = { 0.9, 1.8 }, Pal = { Ice = ICE } },
		{ Prop = Props.bush, Count = 16, Radius = 3.5, Pal = { Leaf = SNOW } },
		{ Prop = Props.rock, Count = 12, Radius = 4, Pal = { Rock = rgb(130, 140, 150) } },
		{ Prop = Props.crystals, Count = 6, Radius = 3, Pal = { Crystal = rgb(150, 210, 250), Rock = rgb(200, 220, 236) } },
	},
	Wall = {
		{ Prop = Props.glowCrystal, Count = 6, Radius = 0, Scale = { 0.6, 1 }, Pal = ICE_GLOW },
	},
}

return theme
