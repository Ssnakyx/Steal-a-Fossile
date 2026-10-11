--!strict
-- Modèles du treadmill du parc : un modèle différent pour chaque niveau (0 = pas encore acheté, puis 1 à 50). 10 thèmes
-- (les 8 zones de la route, puis Fossil Gold et Galaxy) de 5 crans chacun ; chaque cran garde tout le cran d'avant et
-- ajoute du détail :
--   1 : socle, montants, console et panneau aux couleurs du thème (« TREADMILL » et « <THÈME> LV n »)
--   2 : marchepied autour du socle, rebords le long du tapis, petit décor de chaque côté de la console
--   3 : néons sur les rebords et autour du marchepied, décor aux coins arrière
--   4 : arche au-dessus de l'entrée du tapis (côté -Z) avec le niveau écrit dessus et l'emblème du thème
--   5 : grand décor sur les côtés, rambardes en néon, couronne sur le panneau, particules autour de l'emblème
-- Treadmills.Build(level, base) -> Model « TreadmillModel » (attributs Level et Theme), à parenter par l'appelant.
-- `base` = centre du sol sous le tapis, +Z = vers la console (le coureur regarde +Z, il monte par -Z). Le tapis lui-même
-- (pièce taguée Treadmill, au-dessus de `base` de BeltY) n'en fait pas partie : il reste dans le parc (PlotService,
-- TreadmillService) ; Treadmills.Paint(belt, level) lui donne la couleur du thème. Les bandes du tapis sont nommées
-- « BeltStripe » (elles défilent chez le joueur qui court, TreadmillController).
-- Tout reste dans Treadmills.Bounds (en studs autour de `base`) : rien ne déborde sur l'allée des cuves (derrière, -Z),
-- l'enclos ou le portail du parc. Seuls le socle et le marchepied sont solides ; le reste est du décor (Kit.prop).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

export type Ornament = { Fn: Props.PropFn, Scale: number, Pal: Props.Palette? }
-- Montant : segments de couleurs alternées (Colors), anneaux entre deux segments (Ring, en néon si Glow)
export type Post = { Width: number, Colors: { Color3 }, Segment: number, Ring: Color3?, Glow: boolean?, Material: Enum.Material?, Transparency: number? }
export type Theme = {
	Name: string,
	Base: Color3, -- socle et marchepied
	Material: Enum.Material,
	Trim: Color3, -- console, rebords, poutre de l'arche
	Accent: Color3, -- néons
	Rainbow: { Color3 }?, -- néons de plusieurs couleurs (Galaxy), à la place d'Accent
	Belt: Color3,
	Stripe: Color3,
	Text: Color3,
	Post: Post,
	Crest: string, -- emblème en haut de l'arche (voir crests)
	CrestColor: Color3,
	Small: { Ornament }, -- cran 2 : de chaque côté de la console
	Corner: { Ornament }, -- cran 3 : coins arrière
	Big: { Ornament }, -- cran 5 : sur les côtés
	Particle: { Texture: string, Colors: { Color3 } },
}

local Treadmills = {}

Treadmills.ModelName = SpeedConfig.Treadmill.ModelName
Treadmills.StripeName = SpeedConfig.Treadmill.StripeName
Treadmills.BeltY = 1.2 -- centre du tapis au-dessus de `base`
Treadmills.BeltSize = Vector3.new(6, 0.4, 14)
Treadmills.Grades = 5 -- crans par thème
-- Emprise autour de `base` (x de part et d'autre, z de Min à Max, hauteur) : l'allée des cuves commence à z = -9.5
Treadmills.Bounds = { X = 11, MinZ = -10, MaxZ = 12, Height = 14.5 }

local rgb = Color3.fromRGB
local shade = Kit.shade
local prop = Kit.prop
local rad = math.rad
local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic

local TEX = "rbxasset://textures/particles/"
local SPARKLE = TEX .. "sparkles_main.dds"
local FIRE = TEX .. "fire_main.dds"

-- (niveau 0 : le tapis de départ, gris)
local PLAIN_BELT = rgb(36, 36, 40)
local METAL = rgb(96, 102, 112)
local WOOD_DARK = rgb(116, 76, 46)

local function o(fn: Props.PropFn, scale: number, pal: Props.Palette?): Ornament
	return { Fn = fn, Scale = scale, Pal = pal }
end

local RAINBOW = { rgb(255, 80, 120), rgb(255, 170, 60), rgb(255, 240, 90), rgb(90, 255, 140), rgb(80, 200, 255), rgb(170, 110, 255) }

local THEMES: { Theme } = {
	{
		Name = "Beach",
		Base = rgb(232, 212, 160),
		Material = Enum.Material.Plastic,
		Trim = rgb(176, 124, 74),
		Accent = rgb(60, 225, 235),
		Belt = rgb(36, 74, 88),
		Stripe = rgb(250, 240, 210),
		Text = rgb(255, 250, 232),
		-- bambou
		Post = { Width = 0.7, Colors = { rgb(204, 178, 100), rgb(178, 150, 78) }, Segment = 1.2, Ring = rgb(122, 100, 52) },
		Crest = "sun",
		CrestColor = rgb(255, 196, 60),
		Small = { o(Props.shell, 0.8), o(Props.starfish, 1) },
		Corner = { o(Props.eggNest, 0.4), o(Props.tidePool, 0.5) },
		Big = { o(Props.palm, 0.34) },
		Particle = { Texture = SPARKLE, Colors = { rgb(120, 245, 255), rgb(255, 255, 255) } },
	},
	{
		Name = "Fern",
		Base = rgb(96, 146, 70),
		Material = Enum.Material.Plastic,
		Trim = rgb(110, 76, 46),
		Accent = rgb(170, 255, 90),
		Belt = rgb(44, 58, 36),
		Stripe = rgb(150, 210, 90),
		Text = rgb(236, 255, 210),
		-- rondin
		Post = { Width = 0.8, Colors = { rgb(122, 84, 52), rgb(104, 70, 42) }, Segment = 1.8, Ring = rgb(90, 150, 60) },
		Crest = "leaf",
		CrestColor = rgb(110, 210, 80),
		Small = { o(Props.fern, 0.38), o(Props.mushroom, 0.55) },
		Corner = { o(Props.cycad, 0.45), o(Props.glowFlower, 0.6, { Petal = rgb(255, 150, 210) }) },
		Big = { o(Props.cycad, 0.62) },
		Particle = { Texture = SPARKLE, Colors = { rgb(200, 255, 110), rgb(255, 240, 120) } },
	},
	{
		Name = "Swamp",
		Base = rgb(74, 82, 56),
		Material = Enum.Material.Plastic,
		Trim = rgb(88, 72, 56),
		Accent = rgb(120, 255, 110),
		Belt = rgb(30, 40, 30),
		Stripe = rgb(110, 150, 70),
		Text = rgb(210, 255, 190),
		-- bois mort moussu
		Post = { Width = 0.8, Colors = { rgb(92, 76, 60), rgb(76, 90, 56) }, Segment = 1.2 },
		Crest = "jaws",
		CrestColor = rgb(100, 170, 60),
		Small = { o(Props.lilypad, 0.8), o(Props.glowShroom, 0.4, { Cap = rgb(130, 255, 140) }) },
		Corner = { o(Props.flytrap, 0.55), o(Props.bogPool, 0.45) },
		Big = { o(Props.deadTree, 0.55, { Moss = rgb(100, 150, 70) }) },
		Particle = { Texture = SPARKLE, Colors = { rgb(140, 255, 120), rgb(220, 255, 150) } },
	},
	{
		Name = "Canyon",
		Base = rgb(210, 128, 76),
		Material = Enum.Material.Plastic,
		Trim = rgb(150, 82, 52),
		Accent = rgb(255, 180, 60),
		Belt = rgb(70, 42, 30),
		Stripe = rgb(240, 186, 120),
		Text = rgb(255, 236, 200),
		-- grès en couches
		Post = { Width = 0.9, Colors = { rgb(222, 150, 92), rgb(188, 104, 64), rgb(238, 182, 120) }, Segment = 0.9 },
		Crest = "horns",
		CrestColor = rgb(240, 228, 200),
		Small = { o(Props.tumbleweed, 0.6), o(Props.rock, 0.3, { Rock = rgb(200, 120, 74) }) },
		Corner = { o(Props.cactus, 0.5), o(Props.rock, 0.42, { Rock = rgb(186, 106, 66) }) },
		Big = { o(Props.cactus, 0.85) },
		Particle = { Texture = SPARKLE, Colors = { rgb(255, 200, 90), rgb(255, 140, 60) } },
	},
	{
		Name = "Glacier",
		Base = rgb(176, 222, 246),
		Material = Enum.Material.Ice,
		Trim = rgb(236, 246, 255),
		Accent = rgb(120, 232, 255),
		Belt = rgb(56, 84, 110),
		Stripe = rgb(220, 244, 255),
		Text = rgb(40, 90, 140),
		-- glace et neige
		Post = { Width = 0.9, Colors = { rgb(170, 220, 245), rgb(200, 236, 252) }, Segment = 1.2, Ring = rgb(250, 252, 255), Material = Enum.Material.Ice, Transparency = 0.15 },
		Crest = "snowflake",
		CrestColor = rgb(150, 236, 255),
		Small = { o(Props.spike, 0.35), o(Props.crystals, 0.45, { Crystal = rgb(160, 220, 250), Rock = rgb(230, 240, 250) }) },
		Corner = { o(Props.snowman, 0.42), o(Props.pine, 0.3, { Snow = rgb(248, 252, 255) }) },
		Big = { o(Props.spike, 0.85) },
		Particle = { Texture = SPARKLE, Colors = { rgb(255, 255, 255), rgb(170, 230, 255) } },
	},
	{
		Name = "Volcano",
		Base = rgb(52, 46, 48),
		Material = Enum.Material.Slate,
		Trim = rgb(78, 66, 64),
		Accent = rgb(255, 112, 32),
		Belt = rgb(28, 22, 22),
		Stripe = rgb(255, 120, 40),
		Text = rgb(255, 200, 120),
		-- basalte fendu de lave
		Post = { Width = 0.9, Colors = { rgb(56, 48, 50), rgb(40, 34, 36) }, Segment = 1, Ring = rgb(255, 120, 40), Glow = true },
		Crest = "flame",
		CrestColor = rgb(255, 110, 30),
		Small = { o(Props.lavaRock, 0.35), o(Props.steamVent, 0.4) },
		Corner = { o(Props.lavaPool, 0.4), o(Props.lavaRock, 0.45) },
		Big = { o(Props.lavaGeyser, 0.5) },
		Particle = { Texture = FIRE, Colors = { rgb(255, 210, 90), rgb(255, 80, 20) } },
	},
	{
		Name = "Ocean",
		Base = rgb(36, 72, 128),
		Material = Enum.Material.Plastic,
		Trim = rgb(240, 112, 128),
		Accent = rgb(90, 240, 255),
		Belt = rgb(20, 36, 70),
		Stripe = rgb(120, 220, 255),
		Text = rgb(220, 250, 255),
		-- corail
		Post = { Width = 0.8, Colors = { rgb(250, 120, 140), rgb(255, 160, 120) }, Segment = 1, Ring = rgb(90, 240, 255), Glow = true },
		Crest = "trident",
		CrestColor = rgb(255, 210, 80),
		Small = { o(Props.coral, 0.45), o(Props.anemone, 0.45) },
		Corner = { o(Props.bubbleVent, 0.45), o(Props.treasure, 0.5) },
		Big = { o(Props.kelp, 0.45), o(Props.jellyfish, 0.45) },
		Particle = { Texture = SPARKLE, Colors = { rgb(160, 245, 255), rgb(255, 255, 255) } },
	},
	{
		Name = "Meteor",
		Base = rgb(62, 52, 78),
		Material = Enum.Material.Slate,
		Trim = rgb(92, 80, 112),
		Accent = rgb(185, 100, 255),
		Belt = rgb(26, 20, 36),
		Stripe = rgb(170, 110, 255),
		Text = rgb(236, 210, 255),
		-- roche noire veinée de cristal
		Post = { Width = 0.9, Colors = { rgb(66, 56, 82), rgb(48, 40, 60) }, Segment = 1.4, Ring = rgb(190, 110, 255), Glow = true },
		Crest = "crystal",
		CrestColor = rgb(190, 110, 255),
		Small = { o(Props.meteorite, 0.35), o(Props.crystals, 0.45, { Crystal = rgb(170, 100, 240), Glow = rgb(220, 160, 255) }) },
		Corner = { o(Props.geode, 0.4, { Crystal = rgb(200, 120, 255), Crystal2 = rgb(90, 230, 255) }), o(Props.glowCrystal, 0.45) },
		Big = { o(Props.glowCrystal, 0.85, { Crystal = rgb(180, 100, 255), Crystal2 = rgb(90, 220, 255) }), o(Props.floatRock, 0.5) },
		Particle = { Texture = SPARKLE, Colors = { rgb(220, 150, 255), rgb(120, 220, 255) } },
	},
	{
		Name = "Fossil Gold",
		Base = rgb(236, 186, 64),
		Material = Enum.Material.Metal,
		Trim = rgb(236, 226, 198),
		Accent = rgb(255, 222, 100),
		Belt = rgb(60, 44, 20),
		Stripe = rgb(255, 228, 130),
		Text = rgb(120, 70, 20),
		-- vertèbres
		Post = { Width = 0.9, Colors = { rgb(240, 230, 204), rgb(220, 206, 172) }, Segment = 0.8, Ring = rgb(255, 210, 80), Material = SMOOTH },
		Crest = "skull",
		CrestColor = rgb(240, 230, 204),
		Small = { o(Props.treasure, 0.4), o(Props.skull, 0.25) },
		Corner = { o(Props.treasure, 0.55), o(Props.skull, 0.35, { Bone = rgb(255, 214, 90) }) },
		Big = { o(Props.skull, 0.55) },
		Particle = { Texture = SPARKLE, Colors = { rgb(255, 230, 120), rgb(255, 255, 255) } },
	},
	{
		Name = "Galaxy",
		Base = rgb(24, 18, 46),
		Material = SMOOTH,
		Trim = rgb(56, 44, 100),
		Accent = rgb(170, 110, 255),
		Rainbow = RAINBOW,
		Belt = rgb(10, 8, 24),
		Stripe = rgb(140, 120, 255),
		Text = rgb(255, 255, 255),
		-- colonne noire à anneaux de toutes les couleurs
		Post = { Width = 0.8, Colors = { rgb(30, 24, 56), rgb(44, 34, 80) }, Segment = 0.9, Ring = rgb(170, 110, 255), Glow = true },
		Crest = "star",
		CrestColor = rgb(255, 240, 120),
		Small = { o(Props.floatShard, 0.3, { Crystal = rgb(120, 220, 255) }), o(Props.wisp, 0.6, { Glow = rgb(255, 140, 220) }) },
		Corner = { o(Props.glowCrystal, 0.45, { Crystal = rgb(255, 120, 200), Crystal2 = rgb(120, 220, 255), Crystal3 = rgb(255, 240, 120) }), o(Props.floatShard, 0.35, { Crystal = rgb(255, 160, 80) }) },
		Big = { o(Props.glowCrystal, 0.85, { Crystal = rgb(170, 110, 255), Crystal2 = rgb(90, 255, 200), Crystal3 = rgb(255, 120, 200), Crystal4 = rgb(255, 230, 110) }), o(Props.floatShard, 0.45, { Crystal = rgb(255, 240, 140) }) },
		Particle = { Texture = SPARKLE, Colors = RAINBOW },
	},
}

Treadmills.Themes = THEMES
Treadmills.Levels = #THEMES * Treadmills.Grades

-- Thème et cran d'un niveau (nil pour le niveau 0)
function Treadmills.Info(level: number): (Theme?, number)
	if level <= 0 then
		return nil, 0
	end
	local index = math.min(#THEMES, (level - 1) // Treadmills.Grades + 1)
	local grade = math.min(Treadmills.Grades, level - (index - 1) * Treadmills.Grades)
	return THEMES[index], grade
end

-- Couleur du tapis au niveau donné
function Treadmills.Paint(belt: BasePart, level: number)
	local theme = Treadmills.Info(level)
	belt.Color = if theme then theme.Belt else PLAIN_BELT
end

-- ===================================================================== pièces

local function neon(parent: Instance, size: Vector3, cf: CFrame, c: Color3, transparency: number?): Part
	local part = prop(parent, size, cf, c, NEON)
	part.Transparency = transparency or 0
	return part
end

-- Couleur des néons : Accent, ou une couleur de l'arc-en-ciel par pièce (Galaxy)
local function accent(t: Theme, index: number): Color3
	local list = t.Rainbow
	if list then
		return list[(index - 1) % #list + 1]
	end
	return t.Accent
end

-- Montant posé sur `foot` (bas du montant), de `height` studs, épaisseur `scale` x Post.Width
local function post(m: Model, t: Theme, foot: CFrame, height: number, scale: number)
	local spec = t.Post
	local width = spec.Width * scale
	local count = math.max(1, math.floor(height / spec.Segment + 0.5))
	local seg = height / count
	for k = 0, count - 1 do
		local part = prop(m, Vector3.new(width, seg, width), foot * CFrame.new(0, (k + 0.5) * seg, 0), spec.Colors[k % #spec.Colors + 1], spec.Material)
		if spec.Transparency then
			part.Transparency = spec.Transparency
		end
		local ring = spec.Ring
		if ring and k > 0 then
			local c = if spec.Glow and t.Rainbow then accent(t, k) else ring
			prop(m, Vector3.new(width + 0.16, 0.18, width + 0.16), foot * CFrame.new(0, k * seg, 0), c, if spec.Glow then NEON else spec.Material)
		end
	end
	-- chapeau du montant
	prop(m, Vector3.new(width + 0.3, 0.3, width + 0.3), foot * CFrame.new(0, height + 0.15, 0), shade(t.Trim, 0.1))
end

-- Décor `index` de la liste, posé sur `cf`, son +X tourné vers le tapis (côté `side` = -1 ou 1 : les palmiers penchent
-- vers +X, ils restent dans l'emprise)
local function ornament(m: Model, list: { Ornament }, index: number, side: number, cf: CFrame, rng: Random)
	local spec = list[(index - 1) % #list + 1]
	spec.Fn(m, cf * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), spec.Scale, rng, spec.Pal)
end

-- ===================================================================== emblèmes (en haut de l'arche, `top` = dessus de la
-- poutre, tournés vers -Z et +Z). Rendent la pièce centrale (où accrocher les particules).

local crests: { [string]: (m: Model, t: Theme, top: CFrame) -> BasePart } = {}

function crests.sun(m, t, top)
	local c = t.CrestColor
	local center = top * CFrame.new(0, 1.3, 0)
	local core = neon(m, Vector3.new(1.6, 1.6, 0.5), center, c, 0.05)
	neon(m, Vector3.new(1.6, 1.6, 0.4), center * CFrame.Angles(0, 0, rad(45)), shade(c, 0.1), 0.05)
	for k = 0, 7 do
		local ray = center * CFrame.Angles(0, 0, k * math.pi / 4)
		neon(m, Vector3.new(0.3, 0.7, 0.3), ray * CFrame.new(0, 1.35, 0), shade(c, -0.2), 0.1)
	end
	return core
end

function crests.leaf(m, t, top)
	local c = t.CrestColor
	local core = prop(m, Vector3.new(0.5, 0.6, 0.5), top * CFrame.new(0, 0.3, 0), t.Trim)
	for k, angle in { -35, 0, 35 } do
		local blade = top * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, rad(angle))
		local h = if angle == 0 then 2.6 else 2
		prop(m, Vector3.new(0.9, h, 0.25), blade * CFrame.new(0, h / 2, 0), if k == 2 then c else shade(c, 0.15))
		prop(m, Vector3.new(0.15, h * 0.9, 0.3), blade * CFrame.new(0, h / 2, 0), shade(c, -0.3))
	end
	return core
end

function crests.jaws(m, t, top)
	local c = t.CrestColor
	local core = prop(m, Vector3.new(0.6, 0.8, 0.6), top * CFrame.new(0, 0.4, 0), shade(c, 0.2))
	for _, side in { -1, 1 } do
		local lobe = top * CFrame.new(side * 0.5, 1.4, 0) * CFrame.Angles(0, 0, -side * rad(30))
		prop(m, Vector3.new(0.4, 2, 1.4), lobe, c)
		neon(m, Vector3.new(0.1, 1.7, 1.2), lobe * CFrame.new(-side * 0.25, 0, 0), rgb(255, 70, 90), 0.2)
		for k = -1, 1 do
			prop(m, Vector3.new(0.5, 0.15, 0.15), lobe * CFrame.new(-side * 0.35, 0.95, k * 0.45), rgb(230, 250, 160))
		end
	end
	return core
end

function crests.horns(m, t, top)
	local bone = t.CrestColor
	local core = prop(m, Vector3.new(1.4, 1.2, 0.9), top * CFrame.new(0, 0.6, 0), bone)
	prop(m, Vector3.new(0.9, 0.7, 1), top * CFrame.new(0, 0.1, 0), shade(bone, 0.08))
	for _, side in { -1, 1 } do
		prop(m, Vector3.new(0.3, 0.3, 0.1), top * CFrame.new(side * 0.35, 0.75, -0.45), rgb(60, 40, 30))
		local root = top * CFrame.new(side * 0.8, 0.9, 0)
		prop(m, Vector3.new(1.4, 0.45, 0.45), root * CFrame.new(side * 0.6, 0, 0), shade(bone, 0.1))
		prop(m, Vector3.new(0.4, 1.2, 0.4), root * CFrame.new(side * 1.25, 0.5, 0) * CFrame.Angles(0, 0, -side * rad(15)), bone)
	end
	return core
end

function crests.snowflake(m, t, top)
	local c = t.CrestColor
	local center = top * CFrame.new(0, 1.5, 0)
	local core = neon(m, Vector3.new(0.6, 0.6, 0.6), center, rgb(255, 255, 255), 0)
	for k = 0, 2 do
		local arm = center * CFrame.Angles(0, 0, k * math.pi / 3)
		neon(m, Vector3.new(0.3, 2.8, 0.3), arm, c, 0.1)
		for _, side in { -1, 1 } do
			neon(m, Vector3.new(0.2, 0.6, 0.2), arm * CFrame.new(0, side * 1, 0) * CFrame.Angles(0, 0, rad(45)), shade(c, -0.3), 0.1)
			neon(m, Vector3.new(0.2, 0.6, 0.2), arm * CFrame.new(0, side * 1, 0) * CFrame.Angles(0, 0, rad(-45)), shade(c, -0.3), 0.1)
		end
	end
	return core
end

function crests.flame(m, t, top)
	local c = t.CrestColor
	local core = neon(m, Vector3.new(1.4, 0.9, 1.4), top * CFrame.new(0, 0.45, 0), c, 0.05)
	neon(m, Vector3.new(1, 0.8, 1), top * CFrame.new(0.1, 1.25, 0) * CFrame.Angles(0, rad(45), 0), shade(c, -0.3), 0.05)
	neon(m, Vector3.new(0.6, 0.7, 0.6), top * CFrame.new(-0.1, 1.95, 0), rgb(255, 220, 110), 0.05)
	neon(m, Vector3.new(0.3, 0.5, 0.3), top * CFrame.new(0, 2.5, 0), rgb(255, 250, 200), 0.05)
	for _, side in { -1, 1 } do
		neon(m, Vector3.new(0.5, 0.9, 0.5), top * CFrame.new(side * 0.75, 0.75, 0) * CFrame.Angles(0, 0, -side * rad(20)), shade(c, 0.1), 0.1)
	end
	return core
end

function crests.trident(m, t, top)
	local gold = t.CrestColor
	local core = prop(m, Vector3.new(0.3, 1.8, 0.3), top * CFrame.new(0, 0.9, 0), gold, SMOOTH)
	prop(m, Vector3.new(1.8, 0.3, 0.3), top * CFrame.new(0, 1.75, 0), gold, SMOOTH)
	for _, x in { -0.75, 0, 0.75 } do
		local h = if x == 0 then 1.1 else 0.8
		prop(m, Vector3.new(0.25, h, 0.25), top * CFrame.new(x, 1.9 + h / 2, 0), gold, SMOOTH)
		neon(m, Vector3.new(0.3, 0.3, 0.3), top * CFrame.new(x, 1.9 + h + 0.1, 0) * CFrame.Angles(0, rad(45), rad(45)), t.Accent, 0.1)
	end
	return core
end

function crests.crystal(m, t, top)
	local c = t.CrestColor
	local center = top * CFrame.new(0, 1.5, 0)
	local core = neon(m, Vector3.new(1.2, 1.2, 1.2), center * CFrame.Angles(0, 0, rad(45)), c, 0.15)
	neon(m, Vector3.new(0.7, 0.7, 1.3), center * CFrame.Angles(0, 0, rad(45)), shade(c, -0.4), 0)
	for _, side in { -1, 1 } do
		neon(m, Vector3.new(0.6, 0.6, 0.6), center * CFrame.new(side * 1.2, -0.5, 0) * CFrame.Angles(0, 0, rad(45)), rgb(120, 220, 255), 0.15)
	end
	return core
end

function crests.skull(m, t, top)
	local core = prop(m, Vector3.new(1.4, 0.4, 1.4), top * CFrame.new(0, 0.2, 0), t.Accent, NEON)
	Props.skull(m, top * CFrame.new(0, 0.55, 0), 0.38, Random.new(1), { Bone = t.CrestColor })
	return core
end

function crests.star(m, t, top)
	local center = top * CFrame.new(0, 1.6, 0)
	local core = neon(m, Vector3.new(0.8, 0.8, 0.6), center, t.CrestColor, 0)
	for k = 0, 4 do
		local arm = center * CFrame.Angles(0, 0, k * math.pi * 2 / 5)
		neon(m, Vector3.new(0.55, 1.4, 0.4), arm * CFrame.new(0, 0.9, 0), RAINBOW[k + 1], 0.05)
		neon(m, Vector3.new(0.3, 0.5, 0.3), arm * CFrame.new(0, 1.75, 0), shade(RAINBOW[k + 1], -0.3), 0.05)
	end
	return core
end

local function particles(t: Theme, part: BasePart)
	local spec = t.Particle
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = spec.Texture
	local keys = {}
	for k, c in spec.Colors do
		table.insert(keys, ColorSequenceKeypoint.new(if #spec.Colors == 1 then 0 else (k - 1) / (#spec.Colors - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, spec.Colors[1]))
	end
	emitter.Color = ColorSequence.new(keys)
	emitter.Rate = 7
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, 1, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = part
end

-- ===================================================================== modèles

-- Bandes du tapis (défilent chez le coureur) : 5, espacées de 2,8 studs
local function stripes(m: Model, base: CFrame, c: Color3)
	for k = -2, 2 do
		local stripe = prop(m, Vector3.new(6, 0.06, 0.5), base * CFrame.new(0, 1.42, k * 2.8), c, SMOOTH)
		stripe.Name = Treadmills.StripeName
	end
end

-- Niveau 0 : le tapis gris de départ
local function plain(m: Model, base: CFrame)
	Kit.block(m, Vector3.new(8, 1, 16), base * CFrame.new(0, 0.5, 0), rgb(70, 74, 82))
	stripes(m, base, rgb(80, 80, 88))
	for _, side in { -1, 1 } do
		prop(m, Vector3.new(0.5, 3.6, 0.5), base * CFrame.new(side * 3.6, 2.8, 6.8), METAL)
		prop(m, Vector3.new(0.4, 0.4, 6), base * CFrame.new(side * 3.6, 4.4, 4), shade(METAL, -0.3))
	end
	Kit.block(m, Vector3.new(7.6, 2, 0.8), base * CFrame.new(0, 4.6, 7.2) * CFrame.Angles(rad(-20), 0, 0), rgb(60, 64, 72))
	local screen = prop(m, Vector3.new(3, 1, 0.1), base * CFrame.new(0, 4.75, 6.75) * CFrame.Angles(rad(-20), 0, 0), rgb(120, 220, 255), NEON)
	screen.Transparency = 0.3
	local board = prop(m, Vector3.new(7, 1.4, 0.4), base * CFrame.new(0, 6.6, 7.2), WOOD_DARK)
	Kit.text(board, Enum.NormalId.Back, "Title", { { Text = "TREADMILL", Color = rgb(255, 230, 140), Weight = 1 } })
end

local function themed(m: Model, base: CFrame, level: number, t: Theme, grade: number)
	local rng = Random.new(7919 * level)
	local stone = t.Base

	-- cran 1 : socle, bandes, montants, rambardes, console, panneau
	Kit.block(m, Vector3.new(8, 1, 16), base * CFrame.new(0, 0.5, 0), stone, t.Material)
	for _, side in { -1, 1 } do
		prop(m, Vector3.new(0.2, 0.4, 16.2), base * CFrame.new(side * 4.05, 0.7, 0), t.Trim)
	end
	stripes(m, base, t.Stripe)
	for index, side in { -1, 1 } do
		post(m, t, base * CFrame.new(side * 3.6, 1, 6.8), 3.4, 1)
		local rail = base * CFrame.new(side * 3.6, 4.4, 4)
		if grade >= 5 then
			neon(m, Vector3.new(0.4, 0.4, 6), rail, accent(t, index + 2), 0.05)
		else
			prop(m, Vector3.new(0.4, 0.4, 6), rail, shade(t.Trim, -0.15))
		end
	end
	local tilt = CFrame.Angles(rad(-20), 0, 0)
	Kit.block(m, Vector3.new(7.6, 2, 0.8), base * CFrame.new(0, 4.6, 7.2) * tilt, t.Trim)
	neon(m, Vector3.new(3, 1, 0.1), base * CFrame.new(0, 4.75, 6.75) * tilt, accent(t, 1), 0.3)
	local board = prop(m, Vector3.new(7, 1.8, 0.4), base * CFrame.new(0, 6.8, 7.2), shade(t.Trim, 0.25))
	prop(m, Vector3.new(7.4, 0.25, 0.5), base * CFrame.new(0, 7.8, 7.2), shade(t.Trim, -0.1))
	-- (des deux côtés : vu du portail du parc et par le coureur)
	local title = {
		{ Text = "TREADMILL", Color = t.Text, Weight = 0.6 },
		{ Text = string.format("%s  LV %d", string.upper(t.Name), level), Name = "Level", Color = t.Accent, Weight = 0.4 },
	}
	Kit.text(board, Enum.NormalId.Back, "Title", title)
	Kit.text(board, Enum.NormalId.Front, "TitleInside", title)

	-- cran 2 : marchepied, rebords du tapis, petit décor autour de la console
	if grade >= 2 then
		Kit.block(m, Vector3.new(10, 0.5, 18), base * CFrame.new(0, 0.25, 0), shade(stone, 0.18), t.Material)
		for _, side in { -1, 1 } do
			prop(m, Vector3.new(0.4, 0.5, 14), base * CFrame.new(side * 3.4, 1.45, 0), t.Trim)
		end
		for index, side in { -1, 1 } do
			ornament(m, t.Small, index, side, base * CFrame.new(side * 6.4, 0, 7.6), rng)
		end
	end

	-- cran 3 : néons sur les rebords et autour du marchepied, décor aux coins arrière
	if grade >= 3 then
		for index, side in { -1, 1 } do
			neon(m, Vector3.new(0.16, 0.16, 14), base * CFrame.new(side * 3.4, 1.78, 0), accent(t, index), 0.05)
			neon(m, Vector3.new(0.12, 0.12, 18), base * CFrame.new(side * 5.02, 0.44, 0), accent(t, index + 2), 0.15)
			neon(m, Vector3.new(10, 0.12, 0.12), base * CFrame.new(0, 0.44, side * 9.02), accent(t, index + 4), 0.15)
		end
		for index, side in { -1, 1 } do
			ornament(m, t.Corner, index, side, base * CFrame.new(side * 7.4, 0, -7.4), rng)
		end
	end

	-- cran 4 : arche au-dessus de l'entrée du tapis, niveau écrit dessus, emblème
	local crest: BasePart? = nil
	if grade >= 4 then
		local z = -7.6
		for _, side in { -1, 1 } do
			post(m, t, base * CFrame.new(side * 4.6, 0.5, z), 8.6, 1.5)
		end
		local beamCf = base * CFrame.new(0, 9.75, z)
		local beam = prop(m, Vector3.new(10.8, 1.3, 1.4), beamCf, t.Trim)
		local lines = { { Text = "LV " .. level, Color = t.Text, Weight = 1 } }
		Kit.text(beam, Enum.NormalId.Front, "LevelFront", lines)
		Kit.text(beam, Enum.NormalId.Back, "LevelBack", lines)
		neon(m, Vector3.new(10.4, 0.18, 1.5), beamCf * CFrame.new(0, -0.74, 0), accent(t, 3), 0.1)
		neon(m, Vector3.new(10.4, 0.18, 1.5), beamCf * CFrame.new(0, 0.74, 0), accent(t, 4), 0.1)
		crest = crests[t.Crest](m, t, beamCf * CFrame.new(0, 0.83, 0))
	end

	-- cran 5 : grand décor sur les côtés, couronne du panneau, particules
	if grade >= 5 then
		for index, side in { -1, 1 } do
			ornament(m, t.Big, index, side, base * CFrame.new(side * 8, 0, 0.5), rng)
		end
		for k = -1, 1 do
			local h = if k == 0 then 1.1 else 0.7
			neon(m, Vector3.new(0.5, h, 0.3), base * CFrame.new(k * 1.6, 7.95 + h / 2, 7.2), accent(t, k + 3), 0.05)
			neon(m, Vector3.new(0.35, 0.35, 0.35), base * CFrame.new(k * 1.6, 8.1 + h, 7.2) * CFrame.Angles(0, rad(45), rad(45)), t.CrestColor, 0)
		end
		if crest then
			particles(t, crest)
		end
	end
end

-- Modèle du treadmill au niveau `level` (0 à Treadmills.Levels), posé sur `base`
function Treadmills.Build(level: number, base: CFrame): Model
	local clamped = math.clamp(math.floor(level), 0, Treadmills.Levels)
	local m = Kit.group(Treadmills.ModelName)
	local theme, grade = Treadmills.Info(clamped)
	if theme then
		themed(m, base, clamped, theme, grade)
	else
		plain(m, base)
	end
	m:SetAttribute("Level", clamped)
	m:SetAttribute("Theme", if theme then theme.Name else "Plain")
	return m
end

return Treadmills
