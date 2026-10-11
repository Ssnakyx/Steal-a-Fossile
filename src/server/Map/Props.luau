--!strict
-- Décor de la map en studs (brief 10) : arbres, plantes, rochers, objets du camp et des gisements. Chaque fonction
-- construit un modèle de décor (non collidable) posé sur `cf` (pied du modèle, -Z = avant), à l'échelle `s`, et le
-- range dans `parent`. `pal` remplace les couleurs par défaut (Trunk, Leaf, Rock, Snow...). Les objets lumineux sont en
-- Neon translucide (ils brillent avec le bloom, sans PointLight) ; les objets flottants portent le tag de
-- Config.Ambience.Float (montés, descendus et tournés chez les joueurs par AmbienceController).

local Kit = require(script.Parent.Kit)

export type Palette = { [string]: Color3 }
export type PropFn = (parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?) -> Model

local Props = {}

local rgb = Color3.fromRGB
local shade = Kit.shade
local prop = Kit.prop
local rad = math.rad

local function color(pal: Palette?, key: string, default: Color3): Color3
	local value = pal and pal[key]
	return value or default
end

local function finish(model: Model, parent: Instance): Model
	model.Parent = parent
	return model
end

-- ===================================================================== arbres et plantes

function Props.palm(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Palm")
	local trunk = color(pal, "Trunk", rgb(160, 112, 66))
	local leaf = color(pal, "Leaf", rgb(76, 170, 64))
	local segments = 7
	local seg = 2.2 * s
	local lean = Kit.range(rng, 0.25, 0.45) * s
	local x = 0
	for i = 1, segments do
		local w = (2 - i * 0.08) * s
		prop(m, Vector3.new(w, seg, w), cf * CFrame.new(x, (i - 0.5) * seg, 0), if i % 2 == 0 then trunk else shade(trunk, 0.18))
		x += lean * (i / segments) * 1.6
	end
	local top = cf * CFrame.new(x, segments * seg, 0)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		prop(m, Vector3.new(0.9, 0.9, 0.9) * s, top * CFrame.new(math.cos(a) * 0.7 * s, -0.5 * s, math.sin(a) * 0.7 * s), rgb(110, 74, 40))
	end
	for k = 0, 5 do
		local frond = top * CFrame.Angles(0, k * math.pi / 3 + rng:NextNumber() * 0.3, 0)
		prop(m, Vector3.new(2.2, 0.5, 5) * s, frond * CFrame.new(0, 0.3 * s, -2.3 * s) * CFrame.Angles(rad(12), 0, 0), leaf)
		prop(m, Vector3.new(1.8, 0.5, 4.5) * s, frond * CFrame.new(0, -0.15 * s, -6.6 * s) * CFrame.Angles(rad(-28), 0, 0), shade(leaf, 0.15))
	end
	return finish(m, parent)
end

function Props.fern(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Fern")
	local leaf = color(pal, "Leaf", rgb(70, 150, 60))
	local count = rng:NextInteger(6, 8)
	for k = 0, count - 1 do
		local f = cf * CFrame.Angles(0, k * math.pi * 2 / count + rng:NextNumber() * 0.4, 0)
		prop(m, Vector3.new(1.4, 0.3, 4) * s, f * CFrame.new(0, 1.2 * s, -1.8 * s) * CFrame.Angles(rad(35), 0, 0), leaf)
		prop(m, Vector3.new(1, 0.3, 2.6) * s, f * CFrame.new(0, 2.12 * s, -4.72 * s) * CFrame.Angles(rad(-10), 0, 0), shade(leaf, -0.18))
	end
	prop(m, Vector3.new(1, 1, 1) * s, cf * CFrame.new(0, 0.5 * s, 0), shade(leaf, 0.3))
	return finish(m, parent)
end

-- Conifère en étages carrés tournés d'un huitième de tour (neige sur les étages si pal.Snow)
function Props.pine(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Pine")
	local trunk = color(pal, "Trunk", rgb(110, 75, 45))
	local leaf = color(pal, "Leaf", rgb(46, 110, 60))
	local snow = pal and pal.Snow
	prop(m, Vector3.new(1.4, 3, 1.4) * s, cf * CFrame.new(0, 1.5 * s, 0), trunk)
	local y = 2.5 * s
	local tiers = rng:NextInteger(3, 4)
	for k = 0, tiers - 1 do
		local w = (7.5 - k * 1.7) * s
		local h = 2.4 * s
		local tier = cf * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, if k % 2 == 0 then 0 else math.pi / 4, 0)
		prop(m, Vector3.new(w, h, w), tier, if k % 2 == 0 then leaf else shade(leaf, -0.1))
		if snow then
			prop(m, Vector3.new(w * 0.8, 0.5 * s, w * 0.8), tier * CFrame.new(0, h / 2 + 0.25 * s, 0), snow)
		end
		y += h * 0.85
	end
	prop(m, Vector3.new(1, 1.6, 1) * s, cf * CFrame.new(0, y + 0.8 * s, 0), snow or leaf)
	return finish(m, parent)
end

-- Grand arbre feuillu : tronc large, racines, couronne de dômes
function Props.bigTree(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("BigTree")
	local trunk = color(pal, "Trunk", rgb(120, 82, 50))
	local leaf = color(pal, "Leaf", rgb(62, 140, 58))
	local height = Kit.range(rng, 10, 13) * s
	Kit.trunk(m, cf, 3 * s, height, trunk)
	for k = 0, 3 do
		local root = cf * CFrame.Angles(0, k * math.pi / 2 + 0.4, 0)
		prop(m, Vector3.new(1.2, 1.6, 3) * s, root * CFrame.new(0, 0.6 * s, -2 * s) * CFrame.Angles(rad(-20), 0, 0), shade(trunk, 0.1))
	end
	local top = cf * CFrame.new(0, height - 1.5 * s, 0)
	Kit.dome(m, top, 7 * s, 5 * s, 2, leaf)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3 + rng:NextNumber()
		Kit.dome(m, top * CFrame.new(math.cos(a) * 4.5 * s, 1.5 * s, math.sin(a) * 4.5 * s), 4 * s, 3.5 * s, 2, shade(leaf, -0.12 + k * 0.08))
	end
	Kit.dome(m, top * CFrame.new(0, 4.5 * s, 0), 4 * s, 3 * s, 2, shade(leaf, -0.2))
	return finish(m, parent)
end

-- Cycas : tronc court écaillé, couronne de palmes raides
function Props.cycad(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Cycad")
	local trunk = color(pal, "Trunk", rgb(130, 96, 60))
	local leaf = color(pal, "Leaf", rgb(80, 150, 50))
	for i = 1, 3 do
		prop(m, Vector3.new(2.2, 1.4, 2.2) * s, cf * CFrame.new(0, (i - 0.5) * 1.4 * s, 0) * CFrame.Angles(0, i * rad(20), 0), if i % 2 == 0 then trunk else shade(trunk, 0.15))
	end
	local top = cf * CFrame.new(0, 4.2 * s, 0)
	for k = 0, 7 do
		local f = top * CFrame.Angles(0, k * math.pi / 4 + rng:NextNumber() * 0.2, 0)
		prop(m, Vector3.new(1, 0.4, 4.5) * s, f * CFrame.new(0, 0.9 * s, -2 * s) * CFrame.Angles(rad(25), 0, 0), if k % 2 == 0 then leaf else shade(leaf, -0.12))
	end
	return finish(m, parent)
end

function Props.bush(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Bush")
	local leaf = color(pal, "Leaf", rgb(70, 150, 60))
	Kit.dome(m, cf, 2.6 * s, 2.8 * s, 2, leaf)
	if rng:NextNumber() < 0.5 then
		Kit.dome(m, cf * CFrame.new(1.8 * s, 0, 0.8 * s), 1.6 * s, 1.8 * s, 2, shade(leaf, -0.12))
	end
	return finish(m, parent)
end

function Props.mushroom(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Mushroom")
	local cap = color(pal, "Cap", rgb(205, 70, 55))
	local count = rng:NextInteger(1, 3)
	for k = 1, count do
		local scale = s * (if k == 1 then 1 else 0.6)
		local base = cf * CFrame.new((k - 1) * 1.6 * s, 0, (k - 1) * -0.8 * s)
		prop(m, Vector3.new(0.8, 2, 0.8) * scale, base * CFrame.new(0, 1 * scale, 0), rgb(240, 230, 210))
		Kit.disc(m, base * CFrame.new(0, 2 * scale, 0), 1.6 * scale, 0.8 * scale, cap)
		prop(m, Vector3.new(0.5, 0.2, 0.5) * scale, base * CFrame.new(0.6 * scale, 2.9 * scale, 0.3 * scale), rgb(250, 245, 235))
		prop(m, Vector3.new(0.4, 0.2, 0.4) * scale, base * CFrame.new(-0.5 * scale, 2.9 * scale, -0.6 * scale), rgb(250, 245, 235))
	end
	return finish(m, parent)
end

function Props.flowers(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Flowers")
	local colors = { rgb(240, 90, 110), rgb(250, 210, 70), rgb(160, 110, 230), rgb(250, 250, 245) }
	local stem = color(pal, "Leaf", rgb(80, 160, 60))
	for _ = 1, rng:NextInteger(3, 5) do
		local base = cf * CFrame.new(Kit.range(rng, -1.6, 1.6) * s, 0, Kit.range(rng, -1.6, 1.6) * s)
		local h = Kit.range(rng, 1, 1.8) * s
		prop(m, Vector3.new(0.2, h, 0.2) * 1, base * CFrame.new(0, h / 2, 0), stem)
		prop(m, Vector3.new(0.7, 0.4, 0.7) * s, base * CFrame.new(0, h, 0), Kit.pick(rng, colors))
	end
	return finish(m, parent)
end

-- Herbes hautes (plage, marais) : brins fins, quelques épis bruns
function Props.reeds(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Reeds")
	local leaf = color(pal, "Leaf", rgb(110, 150, 70))
	local tip = color(pal, "Tip", rgb(120, 80, 45))
	for k = 1, rng:NextInteger(4, 6) do
		local base = cf * CFrame.new(Kit.range(rng, -1.2, 1.2) * s, 0, Kit.range(rng, -1.2, 1.2) * s)
		local h = Kit.range(rng, 2.5, 4.5) * s
		prop(m, Vector3.new(0.3, h, 0.3) * 1, base * CFrame.new(0, h / 2, 0), if k % 2 == 0 then leaf else shade(leaf, 0.12))
		if k <= 3 then
			prop(m, Vector3.new(0.5, 1, 0.5) * 1, base * CFrame.new(0, h + 0.3, 0), tip)
		end
	end
	return finish(m, parent)
end

function Props.log(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Log")
	local bark = color(pal, "Trunk", rgb(115, 80, 50))
	local moss = color(pal, "Moss", rgb(90, 150, 60))
	local length = Kit.range(rng, 6, 9) * s
	local center = cf * CFrame.new(0, 0.9 * s, 0)
	prop(m, Vector3.new(length, 1.8 * s, 1.1 * s), center, bark)
	prop(m, Vector3.new(length, 1.1 * s, 1.8 * s), center, shade(bark, 0.12))
	prop(m, Vector3.new(0.3, 1.4 * s, 1.4 * s), center * CFrame.new(length / 2, 0, 0), rgb(200, 160, 110))
	prop(m, Vector3.new(0.3, 1.4 * s, 1.4 * s), center * CFrame.new(-length / 2, 0, 0), rgb(200, 160, 110))
	prop(m, Vector3.new(length * 0.6, 0.3, 1.2 * s), center * CFrame.new(-length * 0.1, 0.95 * s, 0), moss)
	return finish(m, parent)
end

-- Arbre mort (marais, volcan) : tronc nu, branches en escalier, mousse pendante si pal.Moss
function Props.deadTree(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("DeadTree")
	local bark = color(pal, "Trunk", rgb(90, 75, 60))
	local moss = pal and pal.Moss
	local height = Kit.range(rng, 8, 11) * s
	Kit.trunk(m, cf, 1.8 * s, height, bark)
	for k = 0, 2 do
		local y = height * (0.5 + k * 0.18)
		local branch = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, k * 2.2 + rng:NextNumber(), 0)
		local arm = branch * CFrame.new(0, 0.8 * s, -1.8 * s) * CFrame.Angles(rad(50), 0, 0)
		prop(m, Vector3.new(0.8, 0.8, 3.6) * s, arm, shade(bark, 0.1))
		if moss then
			prop(m, Vector3.new(0.3, 2.4, 1) * s, branch * CFrame.new(0, 0.2 * s, -3 * s), moss)
		end
	end
	return finish(m, parent)
end

function Props.stump(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Stump")
	local bark = color(pal, "Trunk", rgb(40, 34, 32))
	Kit.trunk(m, cf, 2.4 * s, 2 * s, bark)
	prop(m, Vector3.new(1.6, 0.2, 1.6) * s, cf * CFrame.new(0, 2.1 * s, 0), color(pal, "Ring", rgb(70, 60, 55)))
	return finish(m, parent)
end

-- ===================================================================== rochers et minéraux

function Props.rock(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Rock")
	local stone = color(pal, "Rock", rgb(130, 125, 120))
	local base = cf * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
	local w, h, d = Kit.range(rng, 3, 5) * s, Kit.range(rng, 1.8, 3) * s, Kit.range(rng, 2.5, 4) * s
	prop(m, Vector3.new(w, h, d), base * CFrame.new(0, h / 2, 0), stone)
	prop(m, Vector3.new(w * 0.6, h * 0.6, d * 0.7), base * CFrame.new(w * 0.15, h * 1.2, -d * 0.05), shade(stone, -0.1))
	if rng:NextNumber() < 0.6 then
		prop(m, Vector3.new(w * 0.45, h * 0.5, d * 0.45), base * CFrame.new(w * 0.55, h * 0.25, d * 0.45), shade(stone, 0.12))
	end
	return finish(m, parent)
end

function Props.boulder(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Boulder")
	local stone = color(pal, "Rock", rgb(130, 125, 120))
	Kit.dome(m, cf, 4 * s, 5 * s, 3, stone)
	prop(m, Vector3.new(1.6, 0.4, 2.4) * s, cf * CFrame.new(1.2 * s, 5 * s, 0.4 * s), color(pal, "Top", shade(stone, -0.15)))
	return finish(m, parent)
end

-- Pointe de glace ou de cristal : blocs qui rétrécissent, tournés d'un huitième de tour
function Props.spike(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Spike")
	local ice = color(pal, "Ice", rgb(170, 220, 245))
	local material = if pal and pal.Glow then Enum.Material.Neon else Enum.Material.Plastic
	local lean = cf * CFrame.Angles(rad(Kit.range(rng, -8, 8)), rng:NextNumber() * math.pi, rad(Kit.range(rng, -8, 8)))
	local y = 0
	for k = 0, 2 do
		local w = (2.6 - k * 0.8) * s
		local h = (3.4 - k * 0.5) * s
		local part = prop(m, Vector3.new(w, h, w), lean * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, k * math.pi / 4, 0), if k == 1 then shade(ice, -0.15) else ice, if k == 2 then material else nil)
		if material == Enum.Material.Neon and k == 2 then
			part.Transparency = 0.3
		end
		y += h * 0.9
	end
	return finish(m, parent)
end

-- Grappe de cristaux (pal.Crystal, pal.Glow pour une pointe lumineuse)
function Props.crystals(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Crystals")
	local crystal = color(pal, "Crystal", rgb(150, 90, 220))
	local glow = pal and pal.Glow
	prop(m, Vector3.new(3, 0.8, 3) * s, cf * CFrame.new(0, 0.4 * s, 0), color(pal, "Rock", rgb(60, 50, 70)))
	for k = 0, rng:NextInteger(3, 4) do
		local a = k * 1.7 + rng:NextNumber()
		local h = Kit.range(rng, 2.5, 5) * s
		local tilt = cf * CFrame.new(math.cos(a) * 0.8 * s, 0.6 * s, math.sin(a) * 0.8 * s) * CFrame.Angles(math.sin(a) * rad(18), 0, -math.cos(a) * rad(18))
		local part = prop(m, Vector3.new(0.9, h, 0.9) * 1 * (0.7 + s * 0.3), tilt * CFrame.new(0, h / 2, 0), if k == 0 and glow then glow else shade(crystal, k * 0.06), if k == 0 and glow then Enum.Material.Neon else nil)
		if k == 0 and glow then
			part.Transparency = 0.35
		end
	end
	return finish(m, parent)
end

-- Roche de lave : basalte et fissure orange
function Props.lavaRock(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("LavaRock")
	local stone = color(pal, "Rock", rgb(45, 40, 42))
	local glow = color(pal, "Glow", rgb(255, 120, 30))
	local base = cf * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
	local w, h = Kit.range(rng, 3, 5) * s, Kit.range(rng, 1.6, 2.6) * s
	prop(m, Vector3.new(w, h, w * 0.8), base * CFrame.new(0, h / 2, 0), stone)
	prop(m, Vector3.new(w * 0.55, h * 0.7, w * 0.5), base * CFrame.new(-w * 0.15, h * 1.25, 0), shade(stone, -0.12))
	local crack = prop(m, Vector3.new(w * 0.8, 0.2, 0.4 * s), base * CFrame.new(0, h + 0.05, w * 0.15), glow, Enum.Material.Neon)
	crack.Transparency = 0.1
	return finish(m, parent)
end

-- ===================================================================== lumineux et flottants

local TAU = math.pi * 2

-- Pièce de décor lumineuse (Neon translucide)
local function neon(parent: Instance, size: Vector3, cframe: CFrame, c: Color3, transparency: number): Part
	local part = prop(parent, size, cframe, c, Enum.Material.Neon)
	part.Transparency = transparency
	return part
end

-- Couleurs de cristal de la palette : Crystal, Crystal2, Crystal3, Crystal4 (au moins une)
local function crystalColors(pal: Palette?, default: Color3): { Color3 }
	local list = { color(pal, "Crystal", default) }
	for _, key in { "Crystal2", "Crystal3", "Crystal4" } do
		local value = pal and pal[key]
		if value then
			table.insert(list, value)
		end
	end
	return list
end

-- Pointe de cristal lumineuse posée sur `foot` (bas de la pointe) : prisme tourné d'un huitième de tour et pointe
-- plus claire en deux étages
local function shard(m: Model, foot: CFrame, w: number, h: number, c: Color3)
	local f = foot * CFrame.Angles(0, math.pi / 4, 0)
	neon(m, Vector3.new(w, h, w), f * CFrame.new(0, h / 2, 0), c, 0.3)
	neon(m, Vector3.new(w * 0.64, w * 0.9, w * 0.64), f * CFrame.new(0, h + w * 0.45, 0), shade(c, -0.3), 0.15)
	neon(m, Vector3.new(w * 0.3, w * 0.7, w * 0.3), f * CFrame.new(0, h + w * 1.25, 0), shade(c, -0.55), 0.05)
end

-- Grappe de cristaux lumineux : 3 à 5 pointes penchées vers l'extérieur, de 1 à 4 couleurs (pal.Crystal, Crystal2,
-- Crystal3, Crystal4), sur un socle de roche (pal.Rock)
function Props.glowCrystal(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("GlowCrystal")
	local colors = crystalColors(pal, rgb(170, 100, 255))
	local rock = color(pal, "Rock", rgb(70, 64, 80))
	local base = cf * CFrame.Angles(0, rng:NextNumber() * TAU, 0)
	prop(m, Vector3.new(3.6, 0.8, 3) * s, base * CFrame.new(0, 0.4 * s, 0), rock)
	prop(m, Vector3.new(1.8, 0.6, 1.6) * s, base * CFrame.new(1.5 * s, 0.3 * s, 1.1 * s), shade(rock, -0.12))
	local first = rng:NextInteger(1, #colors)
	for k = 0, rng:NextInteger(3, 5) - 1 do
		local c = colors[(first + k - 1) % #colors + 1]
		local main = k == 0
		local h = (if main then Kit.range(rng, 4.6, 6.2) else Kit.range(rng, 2.2, 4)) * s
		local w = (if main then 1.4 else Kit.range(rng, 0.8, 1.1)) * s
		local a = k * 2.3 + rng:NextNumber() * 0.5
		local r = if main then 0 else Kit.range(rng, 0.9, 1.4) * s
		local tilt = if main then rad(Kit.range(rng, -4, 4)) else rad(Kit.range(rng, 15, 30))
		local foot = base * CFrame.new(math.cos(a) * r, 0.5 * s, math.sin(a) * r) * CFrame.fromAxisAngle(Vector3.new(-math.sin(a), 0, math.cos(a)), -tilt)
		shard(m, foot, w, h, c)
	end
	return finish(m, parent)
end

-- Champignons lumineux : chapeau Neon (pal.Cap) en croix, pied pâle, un point clair
function Props.glowShroom(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("GlowShroom")
	local cap = color(pal, "Cap", rgb(80, 230, 255))
	for k = 1, rng:NextInteger(2, 3) do
		local scale = s * (if k == 1 then 1 else Kit.range(rng, 0.45, 0.7))
		local a = k * 2.1 + rng:NextNumber()
		local r = if k == 1 then 0 else 1.7 * s
		local foot = cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(rad(Kit.range(rng, -8, 8)), 0, rad(Kit.range(rng, -8, 8)))
		local h = 2.6 * scale
		prop(m, Vector3.new(0.8 * scale, h, 0.8 * scale), foot * CFrame.new(0, h / 2, 0), rgb(236, 230, 214))
		neon(m, Vector3.new(3 * scale, 0.8 * scale, 1.9 * scale), foot * CFrame.new(0, h + 0.3 * scale, 0), cap, 0.15)
		neon(m, Vector3.new(1.9 * scale, 0.8 * scale, 3 * scale), foot * CFrame.new(0, h + 0.3 * scale, 0), shade(cap, 0.08), 0.15)
		neon(m, Vector3.new(1.6 * scale, 0.5 * scale, 1.6 * scale), foot * CFrame.new(0, h + 0.95 * scale, 0), shade(cap, -0.2), 0.1)
		neon(m, Vector3.new(0.45, 0.2, 0.45) * scale, foot * CFrame.new(0.5 * scale, h + 1.25 * scale, 0.3 * scale), rgb(255, 255, 255), 0)
	end
	return finish(m, parent)
end

-- Géode : rocher fendu en deux moitiés penchées, l'intérieur sombre tapissé de cristaux lumineux
function Props.geode(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Geode")
	local rock = color(pal, "Rock", rgb(150, 92, 62))
	local colors = crystalColors(pal, rgb(255, 170, 50))
	local base = cf * CFrame.Angles(0, rng:NextNumber() * TAU, 0)
	for _, side in { -1, 1 } do
		local half = base * CFrame.new(side * 1.9 * s, 0, 0) * CFrame.Angles(0, 0, -side * rad(10))
		local stone = if side < 0 then rock else shade(rock, 0.08)
		prop(m, Vector3.new(2.8, 1.6, 4.4) * s, half * CFrame.new(side * 0.2 * s, 0.8 * s, 0), stone)
		prop(m, Vector3.new(2.4, 1.4, 3.8) * s, half * CFrame.new(side * 0.4 * s, 2.3 * s, 0), shade(stone, -0.06))
		prop(m, Vector3.new(1.6, 1.2, 2.6) * s, half * CFrame.new(side * 0.6 * s, 3.6 * s, 0), shade(stone, 0.05))
		prop(m, Vector3.new(0.3, 3.2, 3.4) * s, half * CFrame.new(-side * 1.15 * s, 1.9 * s, 0), shade(rock, 0.5))
		for k = 1, 3 do
			local c = colors[(k + (if side < 0 then 0 else 1) - 1) % #colors + 1]
			local spot = half * CFrame.new(-side * 1.3 * s, (0.8 + k * 0.8) * s, (k - 2) * 1.1 * s)
			neon(m, Vector3.new(0.6, 1.5, 0.6) * s, spot * CFrame.Angles(0, 0, side * rad(Kit.range(rng, 60, 80))) * CFrame.new(0, 0.5 * s, 0), c, 0.15)
		end
	end
	return finish(m, parent)
end

-- Feu follet : lueur qui flotte au-dessus du sol (pal.Glow)
function Props.wisp(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Wisp")
	local c = color(pal, "Glow", rgb(170, 255, 120))
	local center = cf * CFrame.new(0, Kit.range(rng, 3, 5.5) * s, 0)
	local shell = neon(m, Vector3.new(1.6, 1.6, 1.6) * s, center, c, 0.6)
	neon(m, Vector3.new(0.9, 0.9, 0.9) * s, center * CFrame.Angles(math.pi / 4, math.pi / 4, 0), shade(c, -0.4), 0)
	neon(m, Vector3.new(0.4, 0.4, 0.4) * s, center * CFrame.new(0.9 * s, -0.8 * s, 0.3 * s), c, 0.2)
	Kit.float(m, shell, Kit.range(rng, 0.8, 1.4), Kit.range(rng, 0.9, 1.5), Kit.range(rng, 0.6, 1.2))
	return finish(m, parent)
end

-- Méduse lumineuse qui flotte entre deux eaux (pal.Glow)
function Props.jellyfish(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Jellyfish")
	local c = color(pal, "Glow", rgb(255, 130, 220))
	local center = cf * CFrame.new(0, Kit.range(rng, 7, 13) * s, 0)
	local bell = neon(m, Vector3.new(3.2, 1.2, 3.2) * s, center, c, 0.35)
	neon(m, Vector3.new(2.2, 0.8, 2.2) * s, center * CFrame.new(0, 0.95 * s, 0), shade(c, -0.25), 0.3)
	neon(m, Vector3.new(3.6, 0.3, 3.6) * s, center * CFrame.new(0, -0.6 * s, 0), shade(c, 0.1), 0.45)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local h = Kit.range(rng, 2.4, 4) * s
		neon(m, Vector3.new(0.3 * s, h, 0.3 * s), center * CFrame.new(math.cos(a) * 0.9 * s, -0.6 * s - h / 2, math.sin(a) * 0.9 * s), shade(c, -0.15), 0.4)
	end
	Kit.float(m, bell, Kit.range(rng, 1.2, 2), Kit.range(rng, 0.6, 1), Kit.range(rng, 0.1, 0.25))
	return finish(m, parent)
end

-- Anémone de mer lumineuse : pied (pal.Coral), tentacules Neon (pal.Glow)
function Props.anemone(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Anemone")
	local c = color(pal, "Glow", rgb(90, 240, 255))
	local foot = color(pal, "Coral", rgb(120, 60, 140))
	prop(m, Vector3.new(2.4, 1.2, 2.4) * s, cf * CFrame.new(0, 0.6 * s, 0), foot)
	prop(m, Vector3.new(1.8, 0.6, 1.8) * s, cf * CFrame.new(0, 1.5 * s, 0) * CFrame.Angles(0, math.pi / 4, 0), shade(foot, -0.1))
	for k = 0, 6 do
		local a = k * TAU / 7 + rng:NextNumber() * 0.3
		local h = Kit.range(rng, 1.4, 2.4) * s
		local root = cf * CFrame.new(math.cos(a) * 0.7 * s, 1.6 * s, math.sin(a) * 0.7 * s) * CFrame.fromAxisAngle(Vector3.new(-math.sin(a), 0, math.cos(a)), -rad(25))
		neon(m, Vector3.new(0.3 * s, h, 0.3 * s), root * CFrame.new(0, h / 2, 0), if k % 2 == 0 then c else shade(c, 0.15), 0.2)
	end
	return finish(m, parent)
end

-- Éclat de cristal qui flotte et tourne lentement (losange en 5 blocs, pal.Crystal)
function Props.floatShard(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("FloatShard")
	local c = color(pal, "Crystal", rgb(170, 100, 255))
	local center = cf * CFrame.new(0, Kit.range(rng, 8, 15) * s, 0)
	local turn = CFrame.Angles(0, math.pi / 4, 0)
	local core = neon(m, Vector3.new(1.6, 2.6, 1.6) * s, center * turn, c, 0.25)
	for _, side in { -1, 1 } do
		neon(m, Vector3.new(1.1, 1.4, 1.1) * s, center * CFrame.new(0, side * 2 * s, 0) * turn, shade(c, if side > 0 then -0.25 else -0.1), 0.15)
		neon(m, Vector3.new(0.5, 1, 0.5) * s, center * CFrame.new(0, side * 3.1 * s, 0) * turn, shade(c, if side > 0 then -0.5 else -0.3), 0.05)
	end
	Kit.float(m, core, Kit.range(rng, 1, 2), Kit.range(rng, 0.6, 1.1), Kit.range(rng, 0.3, 0.7) * (if rng:NextNumber() < 0.5 then -1 else 1))
	return finish(m, parent)
end

-- Squelette fossile à demi enterré (pal.Bone) : colonne de vertèbres à épines, côtes en arcs de 3 blocs de chaque côté,
-- plus hautes au milieu ; le crâne est à part (Props.skull)
function Props.ribcage(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Ribcage")
	local bone = color(pal, "Bone", rgb(236, 226, 198))
	local count = 6
	local spacing = 3 * s
	local sink = cf * CFrame.new(0, -1.2 * s, 0)
	for k = 0, count - 1 do
		local z = (k - (count - 1) / 2) * spacing
		local middle = 1 - math.abs(k - (count - 1) / 2) / count
		local height = (6 + middle * 3) * s
		local width = (4.2 + middle * 1.6) * s
		local tone = if k % 2 == 0 then bone else shade(bone, 0.08)
		prop(m, Vector3.new(1.4 * s, 1.2 * s, spacing * 0.8), sink * CFrame.new(0, height, z), tone)
		prop(m, Vector3.new(0.6 * s, 1.3 * s, 0.6 * s), sink * CFrame.new(0, height + 1.2 * s, z), shade(bone, 0.12))
		for _, side in { -1, 1 } do
			local points = {
				Vector3.new(side * 0.6 * s, height, z),
				Vector3.new(side * width * 0.72, height * 0.86, z),
				Vector3.new(side * width, height * 0.48, z),
				Vector3.new(side * width * 0.92, 0, z),
			}
			for index = 1, 3 do
				local a, b = points[index], points[index + 1]
				local length = (b - a).Magnitude + 0.6 * s
				prop(m, Vector3.new(0.9 * s, 0.9 * s, length), sink * CFrame.lookAt((a + b) / 2, b), tone)
			end
		end
	end
	return finish(m, parent)
end

-- Crâne fossile en blocs (pal.Bone), à demi enterré, tourné vers -Z : boîte crânienne, museau, orbites, mâchoire, dents
function Props.skull(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Skull")
	local bone = color(pal, "Bone", rgb(236, 226, 198))
	local dark = rgb(60, 50, 44)
	local base = cf * CFrame.new(0, -0.6 * s, 0)
	prop(m, Vector3.new(4.4, 3.4, 4.4) * s, base * CFrame.new(0, 2.4 * s, 1 * s), bone)
	prop(m, Vector3.new(3.2, 2.2, 4.6) * s, base * CFrame.new(0, 1.9 * s, -3.2 * s), shade(bone, 0.06))
	prop(m, Vector3.new(2.4, 1, 2.4) * s, base * CFrame.new(0, 3.5 * s, -2.6 * s), shade(bone, -0.06))
	prop(m, Vector3.new(3, 0.8, 5.4) * s, base * CFrame.new(0, 0.5 * s, -1.6 * s), shade(bone, 0.12))
	for _, side in { -1, 1 } do
		prop(m, Vector3.new(0.3, 1.3, 1.5) * s, base * CFrame.new(side * 2.25 * s, 2.9 * s, 0.4 * s), dark)
		prop(m, Vector3.new(0.3, 0.6, 0.9) * s, base * CFrame.new(side * 1.65 * s, 1.5 * s, -4.4 * s), dark)
		for k = 0, 1 do
			prop(m, Vector3.new(0.4, 0.8, 0.4) * s, base * CFrame.new(side * 1.3 * s, 1.1 * s, (-4.6 + k * 1.3) * s), rgb(250, 246, 236))
		end
	end
	return finish(m, parent)
end

-- Mare de lave : disque Neon, rebord de basalte, deux pierres
function Props.lavaPool(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("LavaPool")
	local stone = color(pal, "Rock", rgb(46, 40, 42))
	local lava = color(pal, "Glow", rgb(255, 112, 32))
	for _, part in Kit.disc(m, cf * CFrame.new(0, 0.05, 0), 3.6 * s, 0.25, lava, Enum.Material.Neon) do
		part.Transparency = 0.05
	end
	for k = 0, 7 do
		local ring = cf * CFrame.Angles(0, k * math.pi / 4, 0)
		prop(m, Vector3.new(3.2 * s, Kit.range(rng, 0.6, 1.1), 1.4), ring * CFrame.new(0, 0.35, -3.9 * s), if k % 2 == 0 then stone else shade(stone, -0.1))
	end
	for k = 0, 1 do
		prop(m, Vector3.new(1.6, 0.6, 1.4) * s, cf * CFrame.new((k * 2 - 1) * 1.2 * s, 0.35, (k - 0.5) * 1.6 * s) * CFrame.Angles(0, rng:NextNumber(), 0), shade(stone, 0.1))
	end
	return finish(m, parent)
end

-- ===================================================================== mer et marais

function Props.shell(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Shell")
	local main = color(pal, "Shell", rgb(250, 200, 190))
	local base = cf * CFrame.Angles(0, rng:NextNumber() * math.pi, 0) * CFrame.Angles(rad(-60), 0, 0)
	prop(m, Vector3.new(1, 0.4, 0.8) * s, base * CFrame.new(0, 0.2 * s, 0.6 * s), shade(main, 0.15))
	prop(m, Vector3.new(2, 0.4, 1) * s, base * CFrame.new(0, 0.2 * s, -0.2 * s), main)
	prop(m, Vector3.new(2.8, 0.4, 1) * s, base * CFrame.new(0, 0.2 * s, -1.1 * s), shade(main, -0.12))
	return finish(m, parent)
end

function Props.starfish(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Starfish")
	local main = color(pal, "Star", Kit.pick(rng, { rgb(240, 130, 70), rgb(230, 90, 100), rgb(250, 190, 70) }))
	prop(m, Vector3.new(0.8, 0.3, 0.8) * s, cf * CFrame.new(0, 0.15 * s, 0), main)
	for k = 0, 4 do
		local arm = cf * CFrame.Angles(0, k * math.pi * 2 / 5, 0)
		prop(m, Vector3.new(0.5, 0.25, 1.3) * s, arm * CFrame.new(0, 0.13 * s, -0.9 * s), main)
	end
	return finish(m, parent)
end

-- Corail (pal.Coral) : grappe de tubes, corail cerveau (dôme à sillons) ou éventail, au hasard
function Props.coral(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Coral")
	local main = color(pal, "Coral", Kit.pick(rng, { rgb(250, 110, 140), rgb(255, 150, 70), rgb(170, 100, 230), rgb(255, 210, 80) }))
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then
		for k = 0, rng:NextInteger(3, 5) do
			local a = k * 2.4 + rng:NextNumber()
			local r = if k == 0 then 0 else Kit.range(rng, 0.9, 1.4) * s
			local h = Kit.range(rng, 1.2, 3.4) * s
			local base = cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
			prop(m, Vector3.new(1.2, h, 1.2) * s, base * CFrame.new(0, h / 2, 0), main)
			prop(m, Vector3.new(1.5, 0.4, 1.5) * s, base * CFrame.new(0, h + 0.2 * s, 0), shade(main, -0.3))
		end
	elseif kind == 2 then
		Kit.dome(m, cf, 2.2 * s, 2.4 * s, 3, main)
		prop(m, Vector3.new(3.2 * s, 0.2, 0.3 * s), cf * CFrame.new(0, 2.4 * s, 0.5 * s), shade(main, 0.2))
		prop(m, Vector3.new(2.6 * s, 0.2, 0.3 * s), cf * CFrame.new(0, 2.2 * s, -0.7 * s), shade(main, 0.2))
	else
		local fan = cf * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
		prop(m, Vector3.new(0.6, 1.2, 0.6) * s, fan * CFrame.new(0, 0.6 * s, 0), shade(main, 0.2))
		for k, size in { Vector3.new(2, 1.4, 0.3), Vector3.new(3.2, 1.4, 0.3), Vector3.new(3.6, 1.2, 0.3), Vector3.new(2.4, 0.8, 0.3) } do
			prop(m, size * s, fan * CFrame.new(0, (0.5 + k * 1.25) * s, 0), shade(main, -0.08 * k))
		end
	end
	return finish(m, parent)
end

-- Algue haute ondulée (pal.Leaf)
function Props.kelp(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Kelp")
	local leaf = color(pal, "Leaf", rgb(60, 140, 80))
	for strand = 1, rng:NextInteger(2, 3) do
		local base = cf * CFrame.new((strand - 2) * 1.2 * s, 0, Kit.range(rng, -0.8, 0.8) * s)
		local segments = rng:NextInteger(5, 8)
		for k = 0, segments - 1 do
			local x = if k % 2 == 0 then 0.35 * s else -0.35 * s
			prop(m, Vector3.new(0.7, 2.2, 0.3) * s, base * CFrame.new(x, (k + 0.5) * 2 * s, 0), if k % 2 == 0 then leaf else shade(leaf, -0.12))
			if k % 2 == 1 then
				prop(m, Vector3.new(1.2, 0.5, 0.25) * s, base * CFrame.new(x + 0.8 * s, (k + 0.6) * 2 * s, 0), shade(leaf, 0.1))
			end
		end
	end
	return finish(m, parent)
end

function Props.lilypad(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("Lilypad")
	local leaf = color(pal, "Leaf", rgb(80, 150, 60))
	Kit.disc(m, cf, 1.6 * s, 0.2, leaf)
	if rng:NextNumber() < 0.35 then
		prop(m, Vector3.new(0.8, 0.6, 0.8) * s, cf * CFrame.new(0.3 * s, 0.4, 0), rgb(245, 160, 200))
	end
	return finish(m, parent)
end

-- ===================================================================== camp, chemin et gisements

function Props.crate(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Crate")
	local wood = color(pal, "Wood", rgb(175, 125, 75))
	local size = 2.6 * s
	local center = cf * CFrame.new(0, size / 2, 0)
	prop(m, Vector3.new(size, size, size), center, wood)
	prop(m, Vector3.new(size + 0.1, 0.4 * s, size + 0.1), center * CFrame.new(0, size / 2 - 0.2 * s, 0), shade(wood, 0.25))
	prop(m, Vector3.new(size + 0.1, 0.4 * s, size + 0.1), center * CFrame.new(0, -size / 2 + 0.2 * s, 0), shade(wood, 0.25))
	return finish(m, parent)
end

function Props.barrel(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Barrel")
	local wood = color(pal, "Wood", rgb(150, 100, 60))
	Kit.trunk(m, cf, 2.4 * s, 3 * s, wood)
	for _, y in { 0.7, 2.3 } do
		Kit.trunk(m, cf * CFrame.new(0, y * s - 0.2 * s, 0), 2.5 * s, 0.4 * s, rgb(90, 90, 95))
	end
	return finish(m, parent)
end

-- Lampadaire (lanterne sur poteau) ; `lit` : la lanterne reçoit une PointLight si le budget le permet
function Props.lamp(parent: Instance, cf: CFrame, s: number, ctx: Kit.Ctx, pal: Palette?): Model
	local m = Kit.group("Lamp")
	local post = color(pal, "Post", rgb(70, 60, 55))
	local glow = color(pal, "Glow", rgb(255, 210, 120))
	local h = 8 * s
	prop(m, Vector3.new(1.4, 0.6, 1.4) * s, cf * CFrame.new(0, 0.3 * s, 0), shade(post, 0.2))
	prop(m, Vector3.new(0.6, h, 0.6) * s, cf * CFrame.new(0, h / 2, 0), post)
	prop(m, Vector3.new(1.6, 0.4, 1.6) * s, cf * CFrame.new(0, h + 0.2 * s, 0), post)
	local lantern = prop(m, Vector3.new(1.1, 1.4, 1.1) * s, cf * CFrame.new(0, h + 1.1 * s, 0), glow, Enum.Material.Neon)
	lantern.Transparency = 0.15
	prop(m, Vector3.new(1.6, 0.4, 1.6) * s, cf * CFrame.new(0, h + 2 * s, 0), post)
	Kit.light(ctx, lantern, glow, 22, 1.4)
	return finish(m, parent)
end

function Props.torch(parent: Instance, cf: CFrame, s: number, ctx: Kit.Ctx, pal: Palette?): Model
	local m = Kit.group("Torch")
	local wood = color(pal, "Wood", rgb(110, 75, 45))
	local glow = color(pal, "Glow", rgb(255, 160, 60))
	prop(m, Vector3.new(0.7, 5, 0.7) * s, cf * CFrame.new(0, 2.5 * s, 0), wood)
	prop(m, Vector3.new(1.1, 0.8, 1.1) * s, cf * CFrame.new(0, 5.2 * s, 0), rgb(70, 70, 75))
	local flame = prop(m, Vector3.new(0.8, 1.2, 0.8) * s, cf * CFrame.new(0, 6.1 * s, 0), glow, Enum.Material.Neon)
	flame.Transparency = 0.1
	Kit.light(ctx, flame, glow, 16, 1.2)
	return finish(m, parent)
end

function Props.bench(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Bench")
	local wood = color(pal, "Wood", rgb(165, 115, 70))
	prop(m, Vector3.new(6, 0.5, 2) * s, cf * CFrame.new(0, 1.6 * s, 0), wood)
	prop(m, Vector3.new(6, 1.4, 0.4) * s, cf * CFrame.new(0, 2.6 * s, 0.9 * s), shade(wood, 0.1))
	for _, x in { -2.4, 2.4 } do
		prop(m, Vector3.new(0.6, 1.4, 1.6) * s, cf * CFrame.new(x * s, 0.7 * s, 0), rgb(80, 80, 85))
	end
	return finish(m, parent)
end

-- Tente du camp de fouilles (toile pal.Cloth)
function Props.tent(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Tent")
	local cloth = color(pal, "Cloth", rgb(215, 190, 140))
	local w, d, h = 8 * s, 9 * s, 5 * s
	local slope = math.atan2(h, w / 2)
	local panel = math.sqrt(h * h + (w / 2) ^ 2)
	prop(m, Vector3.new(panel, 0.4, d), cf * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, 0, slope), cloth)
	prop(m, Vector3.new(panel, 0.4, d), cf * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, 0, -slope), shade(cloth, 0.08))
	prop(m, Vector3.new(0.5, h + 0.6, 0.5), cf * CFrame.new(0, (h + 0.6) / 2, -d / 2), rgb(110, 75, 45))
	prop(m, Vector3.new(0.5, h + 0.6, 0.5), cf * CFrame.new(0, (h + 0.6) / 2, d / 2), rgb(110, 75, 45))
	prop(m, Vector3.new(w * 0.3, h * 0.55, 0.2), cf * CFrame.new(0, h * 0.28, -d / 2 + 0.1), shade(cloth, 0.45))
	return finish(m, parent)
end

-- Pioche posée contre quelque chose (penchée vers -Z)
function Props.pickaxe(parent: Instance, cf: CFrame, s: number, _rng: Random, _pal: Palette?): Model
	local m = Kit.group("Pickaxe")
	local lean = cf * CFrame.Angles(rad(-18), 0, 0)
	prop(m, Vector3.new(0.35, 4.2, 0.35) * s, lean * CFrame.new(0, 2.1 * s, 0), rgb(150, 105, 60))
	local head = lean * CFrame.new(0, 4.1 * s, 0)
	prop(m, Vector3.new(1.5, 0.45, 0.45) * s, head * CFrame.new(-0.7 * s, -0.15 * s, 0) * CFrame.Angles(0, 0, rad(-12)), rgb(150, 155, 165))
	prop(m, Vector3.new(1.5, 0.45, 0.45) * s, head * CFrame.new(0.7 * s, -0.15 * s, 0) * CFrame.Angles(0, 0, rad(12)), rgb(150, 155, 165))
	return finish(m, parent)
end

function Props.shovel(parent: Instance, cf: CFrame, s: number, _rng: Random, _pal: Palette?): Model
	local m = Kit.group("Shovel")
	local lean = cf * CFrame.Angles(rad(15), 0, 0)
	prop(m, Vector3.new(1.1, 1.5, 0.2) * s, lean * CFrame.new(0, 0.75 * s, 0), rgb(140, 145, 155))
	prop(m, Vector3.new(0.3, 3.4, 0.3) * s, lean * CFrame.new(0, 3.1 * s, 0), rgb(150, 105, 60))
	prop(m, Vector3.new(0.9, 0.3, 0.3) * s, lean * CFrame.new(0, 4.8 * s, 0), rgb(40, 40, 45))
	return finish(m, parent)
end

-- Tas de terre en escalier
function Props.dirtPile(parent: Instance, cf: CFrame, s: number, rng: Random, pal: Palette?): Model
	local m = Kit.group("DirtPile")
	local dirt = color(pal, "Dirt", rgb(125, 90, 60))
	Kit.dome(m, cf, Kit.range(rng, 2.2, 3) * s, 2.4 * s, 3, dirt)
	prop(m, Vector3.new(0.8, 0.6, 0.6) * s, cf * CFrame.new(2.4 * s, 0.3 * s, 1 * s), shade(dirt, 0.15))
	return finish(m, parent)
end

function Props.wheelbarrow(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Wheelbarrow")
	local metal = color(pal, "Metal", rgb(200, 80, 60))
	prop(m, Vector3.new(2.6, 1.2, 3.4) * s, cf * CFrame.new(0, 1.9 * s, 0), metal)
	prop(m, Vector3.new(2.2, 0.3, 3) * s, cf * CFrame.new(0, 2.5 * s, 0), color(pal, "Dirt", rgb(125, 90, 60)))
	prop(m, Vector3.new(0.5, 1.6, 1.6) * s, cf * CFrame.new(0, 0.8 * s, -2 * s), rgb(40, 40, 45))
	for _, x in { -1, 1 } do
		prop(m, Vector3.new(0.3, 0.3, 3.6) * s, cf * CFrame.new(x * 1.1 * s, 1.5 * s, 2.2 * s) * CFrame.Angles(rad(-10), 0, 0), rgb(150, 105, 60))
		prop(m, Vector3.new(0.3, 1.2, 0.3) * s, cf * CFrame.new(x * 1 * s, 0.6 * s, 1.2 * s), rgb(90, 90, 95))
	end
	return finish(m, parent)
end

function Props.bucket(parent: Instance, cf: CFrame, s: number, _rng: Random, pal: Palette?): Model
	local m = Kit.group("Bucket")
	Kit.trunk(m, cf, 1.4 * s, 1.4 * s, color(pal, "Metal", rgb(150, 160, 170)))
	prop(m, Vector3.new(1, 0.2, 1) * s, cf * CFrame.new(0, 1.35 * s, 0), color(pal, "Dirt", rgb(125, 90, 60)))
	return finish(m, parent)
end

-- Lanterne posée au sol (lumière si le budget le permet)
function Props.lantern(parent: Instance, cf: CFrame, s: number, ctx: Kit.Ctx, pal: Palette?): Model
	local m = Kit.group("Lantern")
	local glow = color(pal, "Glow", rgb(255, 200, 110))
	prop(m, Vector3.new(1.2, 0.3, 1.2) * s, cf * CFrame.new(0, 0.15 * s, 0), rgb(60, 55, 50))
	local light = prop(m, Vector3.new(0.9, 1.1, 0.9) * s, cf * CFrame.new(0, 0.85 * s, 0), glow, Enum.Material.Neon)
	light.Transparency = 0.15
	prop(m, Vector3.new(1.2, 0.3, 1.2) * s, cf * CFrame.new(0, 1.55 * s, 0), rgb(60, 55, 50))
	prop(m, Vector3.new(0.2, 0.6, 0.2) * s, cf * CFrame.new(0, 2 * s, 0), rgb(60, 55, 50))
	Kit.light(ctx, light, glow, 14, 1)
	return finish(m, parent)
end

-- Panneau de bois sur poteau, avec du texte sur ses deux faces
function Props.signpost(parent: Instance, cf: CFrame, s: number, text: string, pal: Palette?): Model
	local m = Kit.group("Signpost")
	local wood = color(pal, "Wood", rgb(160, 110, 65))
	for _, x in { -2.2, 2.2 } do
		prop(m, Vector3.new(0.5, 5.4, 0.5) * s, cf * CFrame.new(x * s, 2.7 * s, 0), shade(wood, 0.2))
	end
	local board = prop(m, Vector3.new(5, 1.6, 0.4) * s, cf * CFrame.new(0, 4.4 * s, 0), wood)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.text(board, face, "Text" .. face.Name, { { Text = text, Color = Color3.new(1, 1, 1), Weight = 1 } })
	end
	return finish(m, parent)
end

return Props
