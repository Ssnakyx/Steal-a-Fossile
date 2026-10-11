--!strict
-- Zone 7 : Ocean Trench. Fond marin bleu, la mer ouverte de part et d'autre en hauts murs d'eau (poissons, écume en
-- haut), récifs de corail, algues hautes, coquillages, colonnes en ruine et un bénitier géant avec sa perle ; ammonite
-- fossile géante, méduses lumineuses qui flottent, anémones et cristaux des abysses (cyan, bleu, rose).

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local ZoneBase = require(script.Parent.Parent.ZoneBase)

local rgb = Color3.fromRGB
local shade = Kit.shade

local WATER = rgb(44, 126, 206)
local DEEP = rgb(28, 88, 168)
local STONE = rgb(124, 142, 150)
local DEEP_GLOW = { Crystal = rgb(80, 230, 255), Crystal2 = rgb(120, 140, 255), Crystal3 = rgb(255, 120, 220), Rock = rgb(80, 96, 112) }

-- Ammonite fossile géante dressée sur la tranche : spirale de deux tours et demi, blocs qui grossissent vers l'extérieur
-- (le plus gros posé au sol), côtes en relief sur les deux faces, perles de nacre lumineuses au cœur
local function ammonite(info: ZoneBase.Info, spot: Vector3)
	local rng = info.Rng
	local shell = { rgb(222, 198, 160), rgb(196, 164, 126), rgb(236, 216, 186) }
	local count, step, outer = 37, 0.42, 8
	local growth = math.log(2.2) * step / (math.pi * 2) -- x2,2 par tour
	local base = CFrame.new(spot) * CFrame.Angles(0, math.rad(Kit.range(rng, 50, 80)), 0)
	local center = base * CFrame.new(0, outer + (outer * 0.55 + 0.6) / 2 - 0.6, 0)
	for k = 0, count - 1 do
		local r = outer * math.exp(growth * (k - count + 1))
		local a = -math.pi / 2 - (count - 1 - k) * step
		local size = r * 0.55 + 0.6
		local thick = 1.6 + r * 0.25
		local spoke = center * CFrame.Angles(0, 0, a) * CFrame.new(r, 0, 0)
		Kit.solid(Kit.block(info.Ground, Vector3.new(size, size * 0.9, thick), spoke, shell[k % 3 + 1]))
		if k % 2 == 0 then
			Kit.prop(info.Decor, Vector3.new(size + 0.2, 0.4, thick + 0.5), spoke, shade(shell[1], -0.25))
		end
	end
	for k = 0, 2 do
		local pearl = Kit.prop(info.Decor, Vector3.new(0.8, 0.8, 2.4), center * CFrame.Angles(0, 0, k * 2.1) * CFrame.new(0.5 + k * 0.4, 0, 0), DEEP_GLOW.Crystal, Enum.Material.Neon)
		pearl.Transparency = 0.2
	end
	Kit.disc(info.Decor, base * CFrame.new(0, 0.05, 0), 9, 0.25, rgb(176, 190, 196))
	Props.anemone(info.Decor, base * CFrame.new(6, 0, 4), 1, rng, { Glow = DEEP_GLOW.Crystal3, Coral = rgb(70, 60, 140) })
	Props.glowCrystal(info.Decor, base * CFrame.new(-6, 0, -4), 1.2, rng, DEEP_GLOW)
end

-- Bords : murs d'eau (décor) sur un récif bas, le mur invisible de la route garde les joueurs
local function waterWall(info: ZoneBase.Info, side: number): boolean
	local gt, hw, border, rng = info.GroundTop, info.HalfWidth, info.Border, info.Rng
	local zc = (info.Z0 + info.Z1) / 2
	local height = 72
	local inner = Kit.prop(info.Decor, Vector3.new(border - 2, height, info.Length), CFrame.new(side * (hw + 2 + (border - 2) / 2), gt + height / 2, zc), WATER, Enum.Material.SmoothPlastic)
	inner.Transparency = 0.42
	local outer = Kit.prop(info.Decor, Vector3.new(60, height, info.Length), CFrame.new(side * (hw + border + 30), gt + height / 2, zc), DEEP, Enum.Material.SmoothPlastic)
	outer.Transparency = 0.12
	-- au-delà : la mer profonde, opaque, jusqu'en haut des murs
	Kit.prop(info.Decor, Vector3.new(260, height + 2, info.Length), CFrame.new(side * (hw + border + 60 + 130), gt - 2 + (height + 2) / 2, zc), rgb(22, 66, 132), Enum.Material.SmoothPlastic)
	Kit.prop(info.Decor, Vector3.new(border - 2, 1, info.Length), CFrame.new(side * (hw + 2 + (border - 2) / 2), gt + height + 0.5, zc), rgb(220, 240, 255), Enum.Material.SmoothPlastic).Transparency = 0.3
	-- récif au pied du mur
	local z = info.Z0
	while z < info.Z1 - 0.01 do
		local length = math.min(Kit.range(rng, 8, 16), info.Z1 - z)
		local h = Kit.range(rng, 2, 5)
		Kit.block(info.Ground, Vector3.new(Kit.range(rng, 6, 10), h, length), CFrame.new(side * (hw + 3), gt + h / 2, z + length / 2), if rng:NextNumber() < 0.5 then STONE else shade(STONE, 0.15))
		z += length
	end
	-- poissons dans le mur d'eau
	for _ = 1, 10 do
		local fish = CFrame.new(side * Kit.range(rng, hw + 8, hw + border - 6), gt + Kit.range(rng, 14, 60), Kit.range(rng, info.Z0 + 8, info.Z1 - 8))
		local body = Kit.pick(rng, { rgb(250, 170, 60), rgb(250, 230, 90), rgb(240, 120, 150), rgb(30, 70, 120) })
		Kit.prop(info.Decor, Vector3.new(1.4, 1.6, 3.2), fish, body)
		Kit.prop(info.Decor, Vector3.new(0.4, 1.6, 1), fish * CFrame.new(0, 0, 2.1), shade(body, 0.2))
	end
	return true
end

local function archTop(info: ZoneBase.Info, beam: CFrame)
	for k = -2, 2 do
		Props.coral(info.Model, beam * CFrame.new(k * 5.5, 8.6, 0), 0.7, info.Rng, nil)
	end
end

local function landmark(info: ZoneBase.Info)
	local gt, rng = info.GroundTop, info.Rng
	-- bénitier géant ouvert avec sa perle
	local cx, cz = 72, info.Z0 + info.Length * 0.26
	local clam = CFrame.new(cx, gt, cz) * CFrame.Angles(0, math.rad(-60), 0)
	Kit.disc(info.Ground, clam, 7, 2, rgb(150, 120, 170), nil, true)
	for k = 0, 4 do
		Kit.prop(info.Decor, Vector3.new(14 - k * 1.6, 1.2, 1.4), clam * CFrame.new(0, 3 + k * 1.3, 5.5 + k * 0.4) * CFrame.Angles(math.rad(70), 0, 0), if k % 2 == 0 then rgb(170, 140, 190) else rgb(150, 120, 170))
	end
	Kit.dome(info.Decor, clam * CFrame.new(0, 2, -0.5), 2, 2.6, 2, rgb(250, 250, 255), Enum.Material.SmoothPlastic)
	Kit.markCircle(info.Grid, cx, cz, 11)
	-- colonnes en ruine
	local made = 0
	for _ = 1, 60 do
		if made >= 6 then
			break
		end
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = side * Kit.range(rng, 40, 80), Kit.range(rng, info.Z0 + 20, info.Z1 - 10)
		if Kit.isFree(info.Grid, x, z, 6) then
			local base = CFrame.new(x, gt, z)
			Kit.block(info.Ground, Vector3.new(5, 1.4, 5), base * CFrame.new(0, 0.7, 0), shade(STONE, 0.1))
			local h = Kit.range(rng, 5, 16)
			for _, part in Kit.trunk(info.Ground, base * CFrame.new(0, 1.4, 0), 3.2, h, STONE, true) do
				Kit.solid(part)
			end
			if h > 11 then
				Kit.solid(Kit.block(info.Ground, Vector3.new(4.6, 1.2, 4.6), base * CFrame.new(0, 1.4 + h + 0.6, 0), shade(STONE, 0.1)))
			else
				Kit.prop(info.Decor, Vector3.new(3, 2.8, 6), base * CFrame.new(2.6, 1.4, 3) * CFrame.Angles(math.rad(80), 0.4, 0), STONE)
			end
			Props.kelp(info.Decor, base * CFrame.new(-2.8, 0, 1.6), 0.7, rng, nil)
			Kit.markCircle(info.Grid, x, z, 6)
			made += 1
		end
	end
	-- ammonite fossile géante
	local spot = ZoneBase.Spot(info, 12, 44, 76, 0.55, 0.8, -1)
	if spot then
		ammonite(info, spot)
	end
end

local theme: ZoneBase.Theme = {
	Ground = rgb(70, 112, 154),
	Patches = { rgb(60, 98, 140), rgb(84, 126, 166), rgb(96, 122, 128) },
	Path = rgb(164, 182, 190),
	PathEdge = rgb(110, 130, 142),
	Cliff = { STONE, STONE, STONE },
	CliffTop = STONE,
	Arch = { Pillar = STONE, Beam = rgb(96, 116, 126), Board = rgb(30, 88, 150), Trim = rgb(250, 146, 166) },
	Dirt = rgb(92, 102, 112),
	Rim = rgb(122, 142, 152),
	Nest = { Ring = rgb(110, 130, 142), Bed = rgb(172, 182, 172) },
	Glow = rgb(130, 230, 255),
	Border = waterWall,
	ArchTop = archTop,
	Landmark = landmark,
	Scatter = {
		{ Prop = Props.coral, Count = 30, Radius = 3.5, Scale = { 0.9, 1.5 } },
		{ Prop = Props.kelp, Count = 22, Radius = 3, Scale = { 0.9, 1.4 } },
		{ Prop = Props.shell, Count = 14, Radius = 2.5, Scale = { 1.2, 2 } },
		{ Prop = Props.starfish, Count = 10, Radius = 2, Scale = { 1, 1.5 } },
		{ Prop = Props.rock, Count = 12, Radius = 4, Pal = { Rock = rgb(100, 112, 122) } },
		{ Prop = Props.jellyfish, Count = 4, Radius = 3, Scale = { 0.8, 1.3 }, Pal = { Glow = rgb(255, 130, 220) } },
		{ Prop = Props.jellyfish, Count = 4, Radius = 3, Scale = { 0.8, 1.3 }, Pal = { Glow = rgb(100, 200, 255) } },
		{ Prop = Props.jellyfish, Count = 2, Radius = 3, Scale = { 1, 1.4 }, Pal = { Glow = rgb(180, 120, 255) } },
		{ Prop = Props.anemone, Count = 5, Radius = 2.5, Scale = { 0.8, 1.2 }, Pal = { Glow = rgb(90, 240, 255), Coral = rgb(120, 60, 140) } },
		{ Prop = Props.anemone, Count = 5, Radius = 2.5, Scale = { 0.8, 1.2 }, Pal = { Glow = rgb(255, 140, 200), Coral = rgb(70, 60, 140) } },
		{ Prop = Props.glowCrystal, Count = 10, Radius = 3.5, Scale = { 0.7, 1.1 }, Pal = DEEP_GLOW },
	},
}

return theme
