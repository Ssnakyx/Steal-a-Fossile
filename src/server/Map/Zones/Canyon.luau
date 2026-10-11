--!strict
-- Zone 4 : Canyon. Roche rouge, hautes mesas en strates, arche naturelle au-dessus de la route, rails de mine qui
-- longent le bord gauche jusqu'à l'entrée d'une galerie, wagonnet, rochers, aiguilles et herbes sèches.

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local BANDS = { rgb(170, 82, 52), rgb(204, 112, 66), rgb(226, 152, 92), rgb(186, 96, 58) }
local WOOD = rgb(130, 90, 55)
local RAIL = rgb(110, 112, 120)

local function archTop(info: ZoneBase.Info, beam: CFrame)
	for _, side in { -1, 1 } do
		Kit.prop(info.Model, Vector3.new(4, 2.6, 3.4), beam * CFrame.new(side * 15, 2.5, 0), BANDS[3])
		Kit.prop(info.Model, Vector3.new(2.4, 1.6, 2.4), beam * CFrame.new(side * 15, 4.6, 0), BANDS[2])
	end
end

local function landmark(info: ZoneBase.Info)
	local gt, hw, rng = info.GroundTop, info.HalfWidth, info.Rng
	-- arche naturelle (piliers solides, pont de roche au-dessus de la route)
	local az = info.Z0 + info.Length * 0.41
	for _, side in { -1, 1 } do
		local base = CFrame.new(side * 32, gt, az)
		local y = 0
		for k, size in { Vector3.new(12, 12, 12), Vector3.new(10, 10, 10), Vector3.new(11, 9, 11), Vector3.new(12, 6, 12) } do
			Kit.block(info.Ground, size, base * CFrame.new(0, y + size.Y / 2, 0) * CFrame.Angles(0, k * 0.3, 0), BANDS[k])
			y += size.Y
		end
		Kit.markCircle(info.Grid, side * 32, az, 12)
	end
	local top = gt + 37
	Kit.prop(info.Decor, Vector3.new(80, 6, 12), CFrame.new(0, top + 3, az), BANDS[2])
	Kit.prop(info.Decor, Vector3.new(60, 3, 9), CFrame.new(0, top - 1.5, az), BANDS[1])
	Kit.prop(info.Decor, Vector3.new(70, 3, 10), CFrame.new(0, top + 7.5, az), BANDS[3])
	-- rails de mine le long du bord gauche
	local rx = -80
	local z0, z1 = info.Z0 + 20, info.Z1 - 26
	for _, dx in { -1.6, 1.6 } do
		Kit.prop(info.Decor, Vector3.new(0.5, 0.5, z1 - z0), CFrame.new(rx + dx, gt + 0.75, (z0 + z1) / 2), RAIL)
	end
	for z = z0 + 2, z1 - 1, 4 do
		Kit.prop(info.Decor, Vector3.new(5, 0.4, 1.2), CFrame.new(rx, gt + 0.3, z), if z % 8 < 4 then WOOD else shade(WOOD, 0.12))
	end
	Kit.markRect(info.Grid, rx - 4, z0, rx + 4, z1)
	-- wagonnet plein de pierres
	local cart = CFrame.new(rx, gt + 1, info.Z0 + info.Length * 0.62)
	Kit.prop(info.Decor, Vector3.new(4, 2.6, 5), cart * CFrame.new(0, 1.8, 0), rgb(120, 80, 60))
	Kit.prop(info.Decor, Vector3.new(4.4, 0.4, 5.4), cart * CFrame.new(0, 3.2, 0), RAIL)
	for k = 0, 3 do
		Kit.prop(info.Decor, Vector3.new(1.4, 1.2, 1.4), cart * CFrame.new(-0.8 + (k % 2) * 1.6, 3.6, -1.2 + (k // 2) * 2), BANDS[k + 1])
	end
	for _, dz in { -1.6, 1.6 } do
		for _, dx in { -2.1, 2.1 } do
			Kit.prop(info.Decor, Vector3.new(0.5, 1.2, 1.2), cart * CFrame.new(dx, 0.4, dz), rgb(50, 50, 55))
		end
	end
	-- entrée de galerie dans la falaise, au bout des rails
	local gz = z1 + 6
	local frame = CFrame.new(-hw - 1.5, gt, gz)
	Kit.prop(info.Decor, Vector3.new(1, 9, 9), frame * CFrame.new(0, 4.5, 0), rgb(26, 20, 18))
	for _, dz in { -5, 5 } do
		Kit.prop(info.Decor, Vector3.new(1.4, 10, 1.4), frame * CFrame.new(1, 5, dz), WOOD)
	end
	Kit.prop(info.Decor, Vector3.new(1.6, 1.4, 12), frame * CFrame.new(1, 10.4, 0), shade(WOOD, 0.15))
	Props.lantern(info.Decor, CFrame.new(-hw + 2, gt, gz + 7), 1, info.Ctx, nil)
	Kit.markRect(info.Grid, -hw - 4, gz - 8, -hw + 6, gz + 9)
	-- quelques caisses et une pioche près des rails
	Props.crate(info.Decor, CFrame.new(rx + 5, gt, z0 + 30), 1, rng, nil)
	Props.crate(info.Decor, CFrame.new(rx + 5.5, gt, z0 + 33), 0.8, rng, nil)
	Props.pickaxe(info.Decor, CFrame.new(rx + 5, gt, z0 + 36) * CFrame.Angles(0, -math.pi / 2, 0), 1, rng, nil)
end

local theme: ZoneBase.Theme = {
	Ground = rgb(200, 112, 68),
	Patches = { rgb(188, 100, 60), rgb(212, 130, 80), rgb(178, 122, 82) },
	Path = rgb(228, 184, 124),
	PathEdge = rgb(160, 90, 60),
	Cliff = { BANDS[1], BANDS[2], BANDS[3] },
	CliffTop = rgb(236, 176, 116),
	CliffScale = 1.5,
	Arch = { Pillar = rgb(184, 92, 56), Beam = rgb(150, 74, 46), Board = rgb(120, 62, 40), Trim = rgb(236, 186, 120) },
	Dirt = rgb(150, 90, 56),
	Rim = rgb(178, 104, 64),
	Nest = { Ring = rgb(150, 80, 50), Bed = rgb(212, 170, 110) },
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.boulder, Count = 9, Radius = 6, XMin = 40, Pal = { Rock = rgb(190, 108, 68) } },
		{ Prop = Props.spike, Count = 12, Radius = 4, XMin = 36, Scale = { 1.2, 2 }, Pal = { Ice = rgb(178, 92, 58) } },
		{ Prop = Props.rock, Count = 28, Radius = 4, Pal = { Rock = rgb(172, 94, 60) } },
		{ Prop = Props.bush, Count = 18, Radius = 3, Scale = { 0.6, 0.9 }, Pal = { Leaf = rgb(140, 140, 72) } },
		{ Prop = Props.reeds, Count = 16, Radius = 3, Pal = { Leaf = rgb(204, 172, 92), Tip = rgb(170, 130, 70) } },
		{ Prop = Props.rock, Count = 8, Radius = 5, XMin = 104, XMax = 122, Scale = { 1.2, 1.6 }, Pal = { Rock = rgb(214, 146, 90) } },
	},
}

return theme
