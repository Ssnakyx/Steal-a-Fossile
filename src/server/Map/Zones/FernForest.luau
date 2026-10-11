--!strict
-- Zone 2 : Fern Forest. Herbe dense, fougères géantes, cycas, grands arbres, champignons et fleurs, troncs moussus,
-- un ruisseau qui traverse la route (cascade sur la falaise gauche, pierres de gué), un arbre ancien géant, un cercle
-- de pierres moussues autour d'un grand cristal émeraude, traces de pas d'un gros dino, fleurs géantes qui luisent
-- (rose, bleu, jaune) et champignons lumineux (cyan, vert).

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local WATER = rgb(74, 166, 214)
local STONE = rgb(128, 132, 124)
local MOSS = rgb(96, 158, 70)
local EMERALD = { Crystal = rgb(60, 232, 122), Crystal2 = rgb(172, 255, 92), Crystal3 = rgb(255, 232, 92), Rock = rgb(96, 104, 92) }

local function archTop(info: ZoneBase.Info, beam: CFrame)
	local leaf = rgb(70, 150, 58)
	-- feuillage aux bouts de la poutre et sur l'enseigne (le texte reste visible)
	for _, x in { -15.5, 15.5 } do
		Kit.dome(info.Model, beam * CFrame.new(x, 1.2, 0), 3, 2.4, 2, leaf)
	end
	for k = -2, 2 do
		Kit.dome(info.Model, beam * CFrame.new(k * 4.6, 8.5, 0), 2 + (k % 2) * 0.5, 1.6, 2, if k % 2 == 0 then leaf else shade(leaf, -0.12))
	end
end

local function landmark(info: ZoneBase.Info)
	local gt, hw, rng = info.GroundTop, info.HalfWidth, info.Rng
	-- ruisseau en travers de la route, entre le 1er et le 2e gisement
	local cz = info.Z0 + info.Length * 0.41
	local stream = Kit.prop(info.Decor, Vector3.new(hw * 2, 0.2, 10), CFrame.new(0, gt + 0.3, cz), WATER, Enum.Material.SmoothPlastic)
	stream.Transparency = 0.2
	for _, side in { -1, 1 } do
		Kit.prop(info.Decor, Vector3.new(hw * 2, 0.3, 1.2), CFrame.new(0, gt + 0.2, cz + side * 5.4), shade(STONE, -0.1))
	end
	for k = -1, 1 do
		Kit.prop(info.Decor, Vector3.new(4, 0.4, 3), CFrame.new(k * 7, gt + 0.45, cz + (k % 2) * 1.5 - 0.75), STONE)
	end
	-- cascade sur la falaise gauche
	local fall = Kit.prop(info.Decor, Vector3.new(1, 20, 8), CFrame.new(-hw - 1.2, gt + 10, cz), WATER, Enum.Material.SmoothPlastic)
	fall.Transparency = 0.15
	Kit.prop(info.Decor, Vector3.new(1.2, 20, 1.2), CFrame.new(-hw - 0.6, gt + 10, cz - 2), rgb(220, 240, 250), Enum.Material.SmoothPlastic).Transparency = 0.3
	for k = 0, 5 do
		local x = Kit.range(rng, -hw + 6, hw - 6)
		if math.abs(x) > 16 then
			Props.reeds(info.Decor, CFrame.new(x, gt, cz + (if k % 2 == 0 then 6.5 else -6.5)), 0.8, rng, { Leaf = rgb(90, 160, 70) })
		end
	end
	Kit.markRect(info.Grid, -hw - info.Border, cz - 8, hw + info.Border, cz + 8)
	-- arbre ancien géant, côté droit
	local tx, tz = 72, info.Z0 + info.Length * 0.72
	Props.bigTree(info.Decor, CFrame.new(tx, gt, tz), 2.2, rng, { Leaf = rgb(58, 132, 54) })
	Kit.markCircle(info.Grid, tx, tz, 18)
	-- cercle de pierres moussues autour d'un grand cristal émeraude, côté gauche
	local spot = ZoneBase.Spot(info, 13, 50, 76, 0.1, 0.3, -1)
	if spot then
		local center = CFrame.new(spot)
		Kit.disc(info.Decor, center * CFrame.new(0, 0.05, 0), 6, 0.2, shade(MOSS, 0.1))
		for k = 0, 5 do
			local base = center * CFrame.Angles(0, k * math.pi / 3 + 0.3, 0) * CFrame.new(0, 0, -8.5)
			local h = Kit.range(rng, 4, 6.5)
			Kit.prop(info.Decor, Vector3.new(2.4, h, 1.8), base * CFrame.new(0, h / 2, 0), if k % 2 == 0 then STONE else shade(STONE, 0.1))
			Kit.prop(info.Decor, Vector3.new(2.6, 0.6, 2), base * CFrame.new(0, h + 0.3, 0), MOSS)
		end
		Props.glowCrystal(info.Decor, center, 1.6, rng, EMERALD)
	end
end

local theme: ZoneBase.Theme = {
	Ground = rgb(98, 162, 74),
	Patches = { rgb(86, 148, 66), rgb(112, 174, 84), rgb(124, 112, 72) },
	Path = rgb(158, 122, 82),
	PathEdge = STONE,
	Cliff = { rgb(104, 112, 96), rgb(92, 124, 74), rgb(122, 130, 112) },
	CliffTop = rgb(78, 152, 58),
	Arch = { Pillar = rgb(120, 84, 52), Beam = rgb(100, 70, 44), Board = rgb(64, 128, 58), Trim = rgb(206, 232, 156) },
	Dirt = rgb(108, 78, 52),
	Rim = rgb(136, 100, 66),
	Nest = { Ring = rgb(120, 92, 62), Bed = rgb(156, 134, 84) },
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.bigTree, Count = 6, Radius = 10, XMin = 52, XMax = 82, Scale = { 0.9, 1.2 } },
		{ Prop = Props.bigTree, Count = 6, Radius = 8, XMin = 104, XMax = 120, Scale = { 1, 1.3 } },
		{ Prop = Props.pine, Count = 6, Radius = 5, XMin = 50, Pal = { Leaf = rgb(52, 118, 62) } },
		{ Prop = Props.pine, Count = 6, Radius = 5, XMin = 104, XMax = 122, Scale = { 1.2, 1.6 } },
		{ Prop = Props.tracks, Count = 3, Radius = 9, XMin = 30, XMax = 70, Scale = { 1, 1.3 }, Pal = { Mud = rgb(92, 78, 52) } },
		{ Prop = Props.glowFlower, Count = 3, Radius = 3.5, Pal = { Petal = rgb(255, 112, 202) } },
		{ Prop = Props.glowFlower, Count = 3, Radius = 3.5, Pal = { Petal = rgb(90, 200, 255) } },
		{ Prop = Props.glowFlower, Count = 3, Radius = 3.5, Pal = { Petal = rgb(255, 214, 80), Heart = rgb(255, 255, 220) } },
		{ Prop = Props.glowShroom, Count = 3, Radius = 3.5, Pal = { Cap = rgb(80, 230, 255) } },
		{ Prop = Props.glowShroom, Count = 3, Radius = 3.5, Pal = { Cap = rgb(172, 255, 92) } },
		{ Prop = Props.cycad, Count = 10, Radius = 5 },
		{ Prop = Props.fern, Count = 22, Radius = 4, Scale = { 0.8, 1.4 } },
		{ Prop = Props.bush, Count = 12, Radius = 3.5 },
		{ Prop = Props.log, Count = 5, Radius = 5 },
		{ Prop = Props.mushroom, Count = 10, Radius = 2.5 },
		{ Prop = Props.flowers, Count = 12, Radius = 2.5 },
		{ Prop = Props.rock, Count = 6, Radius = 4, Pal = { Rock = STONE } },
	},
}

return theme
