--!strict
-- Zone 3 : Swamp. Boue sombre, ponton de planches, mares d'eau verte avec nénuphars et roseaux, arbres morts à mousse
-- pendante, champignons violets, un tronc creux géant et un vieil arbre-palétuvier.

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local MURK = rgb(74, 98, 66)
local MOSS = rgb(96, 136, 62)
local BARK = rgb(84, 70, 56)

local function archTop(info: ZoneBase.Info, beam: CFrame)
	for k = -5, 5 do
		local h = 1.5 + (k * 7 % 5) * 0.6
		Kit.prop(info.Model, Vector3.new(0.6, h, 0.8), beam * CFrame.new(k * 2.6, -1.2 - h / 2, 0), if k % 2 == 0 then MOSS else shade(MOSS, 0.15))
	end
end

local function pool(info: ZoneBase.Info, x: number, z: number, radius: number)
	local gt, rng = info.GroundTop, info.Rng
	for _, part in Kit.disc(info.Decor, CFrame.new(x, gt + 0.1, z), radius, 0.2, MURK, Enum.Material.SmoothPlastic) do
		part.Transparency = 0.12
	end
	Kit.disc(info.Decor, CFrame.new(x, gt, z), radius + 1.2, 0.2, rgb(62, 56, 40))
	for _ = 1, rng:NextInteger(2, 4) do
		local a, r = rng:NextNumber() * math.pi * 2, Kit.range(rng, 0, radius * 0.6)
		Props.lilypad(info.Decor, CFrame.new(x + math.cos(a) * r, gt + 0.3, z + math.sin(a) * r), Kit.range(rng, 0.7, 1.1), rng, nil)
	end
	for _ = 1, 2 do
		local a = rng:NextNumber() * math.pi * 2
		Props.reeds(info.Decor, CFrame.new(x + math.cos(a) * (radius + 1), gt, z + math.sin(a) * (radius + 1)), 1, rng, { Leaf = rgb(104, 138, 66) })
	end
	Kit.markCircle(info.Grid, x, z, radius + 3)
end

local function landmark(info: ZoneBase.Info)
	local gt, hw, rng = info.GroundTop, info.HalfWidth, info.Rng
	-- mares
	local made = 0
	for _ = 1, 120 do
		if made >= 9 then
			break
		end
		local radius = Kit.range(rng, 5, 10)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * Kit.range(rng, 22 + radius, hw - radius - 4)
		local z = Kit.range(rng, info.Z0 + 16 + radius, info.Z1 - radius - 4)
		if Kit.isFree(info.Grid, x, z, radius + 3) then
			pool(info, x, z, radius)
			made += 1
		end
	end
	-- tronc creux géant couché près du bord gauche
	local lz = info.Z0 + info.Length * 0.55
	local log = CFrame.new(-74, gt, lz) * CFrame.Angles(0, math.rad(80), 0)
	-- (creux : on peut passer dedans)
	Kit.block(info.Ground, Vector3.new(22, 1.5, 6), log * CFrame.new(0, 0.75, 0), shade(BARK, 0.15))
	Kit.solid(Kit.block(info.Ground, Vector3.new(22, 2, 6), log * CFrame.new(0, 8.5, 0), BARK))
	for _, side in { -1, 1 } do
		Kit.solid(Kit.block(info.Ground, Vector3.new(22, 6, 1.6), log * CFrame.new(0, 4.5, side * 3.2), shade(BARK, 0.08)))
		for _, x in { -11, 11 } do
			Kit.prop(info.Decor, Vector3.new(0.4, 7.6, 0.8), log * CFrame.new(x, 4.6, side * 3.6), rgb(150, 120, 86))
		end
	end
	for _, x in { -11, 11 } do
		Kit.prop(info.Decor, Vector3.new(0.4, 0.8, 8), log * CFrame.new(x, 9.2, 0), rgb(150, 120, 86))
	end
	Kit.prop(info.Decor, Vector3.new(14, 0.6, 5), log * CFrame.new(-2, 9.8, 0), MOSS)
	Kit.markCircle(info.Grid, -74, lz, 14)
	-- vieil arbre-palétuvier à droite
	local tz = info.Z0 + info.Length * 0.2
	Props.deadTree(info.Decor, CFrame.new(76, gt, tz), 2, rng, { Trunk = BARK, Moss = MOSS })
	for k = 0, 3 do
		local root = CFrame.new(76, gt, tz) * CFrame.Angles(0, k * math.pi / 2 + 0.3, 0)
		Kit.prop(info.Decor, Vector3.new(1.4, 1.4, 5), root * CFrame.new(0, 1.4, -3.5) * CFrame.Angles(math.rad(-30), 0, 0), BARK)
	end
	Kit.markCircle(info.Grid, 76, tz, 10)
end

local theme: ZoneBase.Theme = {
	Ground = rgb(80, 96, 58),
	Patches = { rgb(68, 82, 50), rgb(94, 108, 62), rgb(76, 66, 46) },
	Path = rgb(132, 96, 62),
	PathEdge = rgb(90, 80, 60),
	Planks = true,
	Cliff = { rgb(70, 76, 60), rgb(64, 88, 52), rgb(86, 94, 72) },
	CliffTop = rgb(72, 114, 52),
	Arch = { Pillar = BARK, Beam = rgb(70, 54, 40), Board = rgb(84, 106, 58), Trim = rgb(170, 196, 116) },
	Dirt = rgb(82, 64, 46),
	Rim = rgb(102, 84, 60),
	Nest = { Ring = rgb(92, 82, 66), Bed = rgb(112, 102, 62) },
	Glow = rgb(196, 255, 150),
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.deadTree, Count = 16, Radius = 6, XMin = 40, Pal = { Trunk = BARK, Moss = MOSS } },
		{ Prop = Props.deadTree, Count = 8, Radius = 6, XMin = 104, XMax = 120, Scale = { 1, 1.4 }, Pal = { Trunk = BARK, Moss = MOSS } },
		{ Prop = Props.reeds, Count = 24, Radius = 3, Pal = { Leaf = rgb(104, 138, 66) } },
		{ Prop = Props.fern, Count = 16, Radius = 4, Pal = { Leaf = rgb(70, 112, 50) } },
		{ Prop = Props.bush, Count = 14, Radius = 3.5, Pal = { Leaf = rgb(60, 98, 48) } },
		{ Prop = Props.log, Count = 5, Radius = 5, Pal = { Trunk = BARK, Moss = MOSS } },
		{ Prop = Props.mushroom, Count = 12, Radius = 2.5, Pal = { Cap = rgb(150, 92, 200) } },
		{ Prop = Props.stump, Count = 6, Radius = 3, Pal = { Trunk = BARK, Ring = rgb(130, 110, 86) } },
	},
}

return theme
