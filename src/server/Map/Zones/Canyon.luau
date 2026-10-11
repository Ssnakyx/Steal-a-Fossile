--!strict
-- Zone 4 : Canyon. Roche rouge, hautes mesas en strates, arche naturelle au-dessus de la route, rails de mine qui
-- longent le bord gauche jusqu'à l'entrée d'une galerie, wagonnet, rochers, aiguilles et herbes sèches ; pont de
-- cordes tendu d'une falaise à l'autre au-dessus de la route, squelette fossile dégagé par les fouilles, géodes et
-- cristaux couleur ambre, orange et or (au sol, sur les falaises et sortant des parois).

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local BANDS = { rgb(170, 82, 52), rgb(204, 112, 66), rgb(226, 152, 92), rgb(186, 96, 58) }
local WOOD = rgb(130, 90, 55)
local RAIL = rgb(110, 112, 120)
local AMBER = { Crystal = rgb(255, 170, 50), Crystal2 = rgb(255, 110, 40), Crystal3 = rgb(255, 216, 82), Rock = rgb(150, 82, 52) }
local BONE = { Bone = rgb(232, 216, 182) }

-- Pont de cordes d'une falaise à l'autre, en travers de la route à Z = z, au niveau des falaises (planches qui suivent la
-- courbe du pont, mains courantes, poteaux, deux lanternes suspendues)
local function bridge(info: ZoneBase.Info, z: number)
	local gt = info.GroundTop
	local half = info.HalfWidth + 6
	local top = gt + 36
	local sag = 7
	local function heightAt(x: number): number
		return top - sag * (1 - (x / half) ^ 2)
	end
	local m = Kit.group("RopeBridge")
	local x = -half
	local index = 0
	while x < half - 0.01 do
		local w = math.min(3.6, half - x)
		local cx = x + w / 2
		local slope = 2 * sag * cx / (half * half)
		Kit.prop(m, Vector3.new(w - 0.4, 0.4, 6), CFrame.new(cx, heightAt(cx), z) * CFrame.Angles(0, 0, math.atan(slope)), if index % 2 == 0 then WOOD else shade(WOOD, 0.12))
		x += w
		index += 1
	end
	local rope = rgb(200, 176, 128)
	for _, dz in { -3.2, 3.2 } do
		local segments = 10
		for k = 0, segments - 1 do
			local x0 = -half + k * 2 * half / segments
			local x1 = x0 + 2 * half / segments
			local a = Vector3.new(x0, heightAt(x0) + 2.6, z + dz)
			local b = Vector3.new(x1, heightAt(x1) + 2.6, z + dz)
			Kit.prop(m, Vector3.new(0.3, 0.3, (b - a).Magnitude + 0.2), CFrame.lookAt((a + b) / 2, b), rope)
		end
		for _, side in { -1, 1 } do
			Kit.prop(m, Vector3.new(0.9, 5, 0.9), CFrame.new(side * (half - 1), top + 1.6, z + dz), shade(WOOD, 0.2))
		end
	end
	for _, t in { -0.45, 0.4 } do
		local lx = half * t
		local hang = heightAt(lx) - 0.2
		Kit.prop(m, Vector3.new(0.2, 2, 0.2), CFrame.new(lx, hang - 1, z + 2.6), rope)
		local lamp = Kit.prop(m, Vector3.new(1, 1.2, 1), CFrame.new(lx, hang - 2.6, z + 2.6), rgb(255, 200, 110), Enum.Material.Neon)
		lamp.Transparency = 0.1
	end
	m.Parent = info.Decor
end

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
			Kit.solid(Kit.block(info.Ground, size, base * CFrame.new(0, y + size.Y / 2, 0) * CFrame.Angles(0, k * 0.3, 0), BANDS[k]))
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
	-- pont de cordes au-dessus de la route
	bridge(info, info.Z0 + info.Length * 0.8)
	-- squelette fossile dégagé par les fouilles, avec une pioche plantée à côté
	local spot = ZoneBase.Spot(info, 19, 40, 70, 0.12, 0.3, 1)
	if spot then
		local base = CFrame.new(spot) * CFrame.Angles(0, math.rad(Kit.range(rng, -60, -20)), 0)
		Kit.disc(info.Decor, base * CFrame.new(0, 0.05, -1), 13, 0.2, rgb(214, 150, 96))
		Props.ribcage(info.Decor, base * CFrame.new(0, 0, 5), 1.2, rng, BONE)
		Props.skull(info.Decor, base * CFrame.new(0, 0, -9.5) * CFrame.Angles(0, math.rad(-12), 0), 1.1, rng, BONE)
		Props.pickaxe(info.Decor, base * CFrame.new(8, 0, -6) * CFrame.Angles(0, math.pi / 2, 0), 1, rng, nil)
	end
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
		{ Prop = Props.geode, Count = 6, Radius = 5, XMin = 36, Scale = { 0.9, 1.3 }, Pal = { Rock = rgb(176, 96, 60), Crystal = AMBER.Crystal, Crystal2 = AMBER.Crystal2, Crystal3 = AMBER.Crystal3 } },
		{ Prop = Props.glowCrystal, Count = 6, Radius = 3.5, Scale = { 0.7, 1.1 }, Pal = AMBER },
		{ Prop = Props.glowCrystal, Count = 4, Radius = 4, XMin = 104, XMax = 122, Scale = { 1.1, 1.5 }, Pal = AMBER },
		{ Prop = Props.rock, Count = 28, Radius = 4, Pal = { Rock = rgb(172, 94, 60) } },
		{ Prop = Props.bush, Count = 18, Radius = 3, Scale = { 0.6, 0.9 }, Pal = { Leaf = rgb(140, 140, 72) } },
		{ Prop = Props.reeds, Count = 16, Radius = 3, Pal = { Leaf = rgb(204, 172, 92), Tip = rgb(170, 130, 70) } },
		{ Prop = Props.rock, Count = 8, Radius = 5, XMin = 104, XMax = 122, Scale = { 1.2, 1.6 }, Pal = { Rock = rgb(214, 146, 90) } },
	},
	Wall = {
		{ Prop = Props.glowCrystal, Count = 10, Radius = 0, Scale = { 0.6, 1 }, Pal = AMBER },
	},
}

return theme
