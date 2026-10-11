--!strict
-- Zone 5 : Glacier. Neige, sentier de glace bleue, falaises de glace, sapins enneigés, pointes de glace, congères,
-- lac gelé avec ses fissures, cascade gelée sur la falaise droite et blocs de glace géants.

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local SNOW = rgb(244, 248, 252)
local ICE = rgb(170, 216, 242)

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
			Kit.block(info.Ground, Vector3.new(10, 12, 9), base * CFrame.new(0, 6, 0), ICE, Enum.Material.Ice)
			Kit.block(info.Ground, Vector3.new(7, 6, 6), base * CFrame.new(4, 3, 4), shade(ICE, -0.2), Enum.Material.Ice)
			Kit.prop(info.Decor, Vector3.new(10.4, 1, 9.4), base * CFrame.new(0, 12.5, 0), SNOW)
			Kit.markCircle(info.Grid, x, z, 10)
		end
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
		{ Prop = Props.spike, Count = 22, Radius = 3, Scale = { 0.9, 1.8 }, Pal = { Ice = ICE } },
		{ Prop = Props.bush, Count = 16, Radius = 3.5, Pal = { Leaf = SNOW } },
		{ Prop = Props.rock, Count = 12, Radius = 4, Pal = { Rock = rgb(130, 140, 150) } },
		{ Prop = Props.crystals, Count = 8, Radius = 3, Pal = { Crystal = rgb(150, 210, 250), Rock = rgb(200, 220, 236) } },
	},
}

return theme
