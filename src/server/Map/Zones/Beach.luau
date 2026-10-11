--!strict
-- Zone 1 : Beach. Sable clair, mer à gauche (eau peu profonde, écume, aiguilles de roche, arche dans la mer, ponton),
-- falaises de grès couronnées de palmiers à droite, coquillages, étoiles de mer, bois flotté, flaques entre les rochers.

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local SHALLOW = rgb(96, 196, 222)
local DEEP = rgb(52, 142, 204)
local FOAM = rgb(240, 250, 255)
local ROCK = rgb(150, 140, 130)

local function water(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, transparency: number): Part
	local part = Kit.prop(parent, size, cframe, color, Enum.Material.SmoothPlastic)
	part.Transparency = transparency
	return part
end

-- Bord gauche : la mer (pas de falaise ; le mur invisible de la route garde les joueurs sur la plage)
local function ocean(info: ZoneBase.Info, side: number): boolean
	if side ~= -1 then
		return false
	end
	local gt, hw, border = info.GroundTop, info.HalfWidth, info.Border
	local z0, z1, rng = info.Z0, info.Z1, info.Rng
	local zc = (z0 + z1) / 2
	-- sable mouillé, eau peu profonde, puis le large (prolongé avant et après la zone, derrière la forêt)
	Kit.block(info.Ground, Vector3.new(14, 1, info.Length), CFrame.new(-hw + 9, gt - 0.38, zc), rgb(214, 188, 136))
	water(info.Decor, Vector3.new(border + 6, 0.6, info.Length), CFrame.new(-hw - border / 2 + 3, gt + 0.2, zc), SHALLOW, 0.35)
	water(info.Decor, Vector3.new(700, 0.6, info.Length + 600), CFrame.new(-hw - border - 350, gt + 0.2, z0 + (info.Length + 600) / 2), DEEP, 0.05)
	-- écume en traits interrompus
	for _, x in { -hw + 4, -hw - 10, -hw - 26 } do
		local z = z0
		while z < z1 - 4 do
			local length = Kit.range(rng, 6, 16)
			if rng:NextNumber() < 0.75 then
				water(info.Decor, Vector3.new(1.4, 0.1, math.min(length, z1 - z)), CFrame.new(x + Kit.range(rng, -1.5, 1.5), gt + 0.55, z + length / 2), FOAM, 0.25)
			end
			z += length + Kit.range(rng, 2, 6)
		end
	end
	return true
end

local function archTop(info: ZoneBase.Info, beam: CFrame)
	local leaf = rgb(80, 170, 64)
	for _, side in { -1, 1 } do
		local top = beam * CFrame.new(side * 14, 1.2, 0)
		for k = 0, 4 do
			local frond = top * CFrame.Angles(0, k * math.pi * 2 / 5, 0)
			Kit.prop(info.Model, Vector3.new(1.6, 0.4, 4), frond * CFrame.new(0, 0.4, -1.8) * CFrame.Angles(math.rad(-15), 0, 0), if k % 2 == 0 then leaf else shade(leaf, 0.15))
		end
	end
end

local function landmark(info: ZoneBase.Info)
	local gt, hw, border = info.GroundTop, info.HalfWidth, info.Border
	local rng, z0, length = info.Rng, info.Z0, info.Length
	local sea = gt + 0.5
	-- aiguilles de roche dans la mer
	for _ = 1, 6 do
		local x = -hw - border - Kit.range(rng, 20, 150)
		local z = z0 + Kit.range(rng, 10, length - 10)
		Kit.cone(info.Decor, CFrame.new(x, sea - 2, z), Kit.range(rng, 5, 9), Kit.range(rng, 14, 26), 4, ROCK)
	end
	-- arche de roche dans la mer
	local ax, az = -hw - border - 70, z0 + length * 0.55
	for _, dz in { -16, 16 } do
		Kit.cone(info.Decor, CFrame.new(ax, sea - 2, az + dz), 9, 34, 5, shade(ROCK, 0.05), nil, nil, 0.55)
	end
	Kit.prop(info.Decor, Vector3.new(10, 6, 44), CFrame.new(ax, sea + 33, az), ROCK)
	Kit.prop(info.Decor, Vector3.new(8, 3, 30), CFrame.new(ax, sea + 29, az), shade(ROCK, 0.1))
	-- ponton de bois qui part dans la mer
	local pz = z0 + 42
	local wood = rgb(170, 125, 80)
	for k = 0, 17 do
		Kit.prop(info.Decor, Vector3.new(1.8, 0.5, 6), CFrame.new(-hw + 6 - k * 2, gt + 1.2, pz), if k % 2 == 0 then wood else shade(wood, 0.12))
	end
	for k = 0, 4 do
		for _, dz in { -3.2, 3.2 } do
			Kit.prop(info.Decor, Vector3.new(0.9, 3.4, 0.9), CFrame.new(-hw + 5 - k * 8, gt + 0.4, pz + dz), shade(wood, 0.3))
		end
	end
	Kit.markRect(info.Grid, -hw - border, pz - 6, -hw + 10, pz + 6)
	-- flaques entre les rochers, côté mer
	local pools = 0
	for _ = 1, 40 do
		if pools >= 3 then
			break
		end
		local x, z = -Kit.range(rng, 58, 76), z0 + Kit.range(rng, 30, length - 20)
		if Kit.isFree(info.Grid, x, z, 8) then
			water(info.Decor, Vector3.new(7, 0.2, 7), CFrame.new(x, gt + 0.22, z), SHALLOW, 0.2)
			for k = 0, 7 do
				local ring = CFrame.new(x, gt, z) * CFrame.Angles(0, k * math.pi / 4, 0)
				Kit.prop(info.Decor, Vector3.new(3, Kit.range(rng, 0.8, 1.6), 1.6), ring * CFrame.new(0, 0.5, -4.6), if k % 2 == 0 then ROCK else shade(ROCK, -0.12))
			end
			Props.starfish(info.Decor, CFrame.new(x + 1, gt + 0.3, z - 1), 1, rng, nil)
			Kit.markCircle(info.Grid, x, z, 8)
			pools += 1
		end
	end
end

local theme: ZoneBase.Theme = {
	Ground = rgb(236, 214, 160),
	Patches = { rgb(228, 204, 148), rgb(244, 226, 180), rgb(222, 196, 140) },
	Path = rgb(218, 188, 134),
	PathEdge = rgb(196, 186, 172),
	Cliff = { rgb(196, 168, 118), rgb(214, 188, 138), rgb(228, 206, 160) },
	CliffTop = rgb(112, 174, 70),
	Arch = { Pillar = rgb(176, 126, 78), Beam = rgb(140, 96, 58), Board = rgb(64, 150, 206), Trim = rgb(244, 230, 194) },
	Dirt = rgb(150, 112, 72),
	Rim = rgb(196, 160, 106),
	Nest = { Ring = ROCK, Bed = rgb(204, 176, 116) },
	Pal = { Wood = rgb(184, 140, 92) },
	Border = ocean,
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.palm, Count = 10, Radius = 6, XMin = 40, XMax = 84, Side = 1, Scale = { 0.9, 1.3 } },
		{ Prop = Props.palm, Count = 7, Radius = 6, XMin = 40, XMax = 76, Side = -1, Scale = { 0.9, 1.2 } },
		{ Prop = Props.palm, Count = 7, Radius = 6, XMin = 104, XMax = 122, Side = 1, Scale = { 1, 1.4 } },
		{ Prop = Props.rock, Count = 12, Radius = 4, Pal = { Rock = ROCK } },
		{ Prop = Props.log, Count = 5, Radius = 5, Pal = { Trunk = rgb(186, 166, 136), Moss = rgb(206, 192, 160) } },
		{ Prop = Props.reeds, Count = 18, Radius = 3, XMin = 30, Pal = { Leaf = rgb(150, 172, 82), Tip = rgb(206, 186, 126) } },
		{ Prop = Props.shell, Count = 14, Radius = 2, Scale = { 0.7, 1.1 } },
		{ Prop = Props.starfish, Count = 10, Radius = 2, Scale = { 0.8, 1.2 } },
		{ Prop = Props.crate, Count = 3, Radius = 3, Pal = { Wood = rgb(180, 150, 110) } },
		{ Prop = Props.rock, Count = 6, Radius = 5, XMin = 102, XMax = 122, Side = 1, Pal = { Rock = rgb(200, 176, 128) } },
	},
}

return theme
