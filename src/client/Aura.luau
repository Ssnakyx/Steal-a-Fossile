--!strict
-- Aura : auras de rareté des dinos et des blocs de fossiles, côté client. Demande de Snaky (2026-10-11) : des auras
-- dans le style de la vidéo « Megumin Explosion - VFX Showcase » (cercles magiques à runes qui tournent, colonne de
-- cercles au-dessus de la tête, rayon de lumière, ondes de choc), propres et lisibles, plus fortes pour les raretés hautes.
--
--   local handle = Aura.Attach(model, { Rarity = "Mythic", Radius = 6, Height = 9, Root = model.Root })
--   Aura.Attach(model, { ..., Pivot = function() return base end, Top = function() return headTop end })
--   Aura.Pulse(handle)       -- onde de choc et gerbe d'étincelles (réanimation, fusion)
--   Aura.Detach(handle)      -- enlève tout
-- Utilisé par DinoAnimController (dinos) et AuraController (blocs de fossiles, via FossilBlockController.SetAura).
--
-- Ce que chaque rareté ajoute (cumulé) :
--   Common     anneau fin au sol, 4 points
--   Uncommon   double anneau qui tourne, poussière lumineuse qui monte, voile d'énergie autour du corps (rubans de
--              lumière qui montent du sol et se resserrent comme une flamme, plus haut et plus dense à chaque rareté)
--   Rare       runes entre les anneaux, cercle intérieur et triangle, lueur au sol, traits de lumière, lumière colorée
--   Epic       pentagramme, tourbillon au sol, brume colorée autour du corps, 2 comètes autour du corps
--   Legendary  hexagramme, couronne de losanges, cercle au-dessus de la tête, rayon de lumière, contour lumineux
--   Mythic     octagramme, 2 cercles empilés au-dessus de la tête, flammes, onde de choc régulière (le style Megumin)
--   Secret     étoile à 12 branches, 3 cercles au-dessus de la tête, poussière arc-en-ciel, tout en arc-en-ciel
-- Couleur : Config.Rarity.Info[rareté].Color (la même que les blocs de fossiles).
--
-- Rendu : cercles dessinés en SurfaceGui (anneaux UIStroke, traits, runes en texte) sur une pièce plate invisible,
-- particules, voile et rayons avec les textures intégrées de Roblox (rbxasset://textures/particles/...) : aucun asset
-- uploadé.
-- Une seule boucle (RenderStepped) pour toutes les auras, niveau de détail selon la distance à la caméra (tout de près,
-- moins de particules à mi-distance, cercle et rayon seuls au loin, rien au-delà de la portée de la rareté), pas
-- d'animation hors de l'écran. Contours (Highlight) et lumières (PointLight) prêtés seulement aux auras les plus proches
-- (MAX_OUTLINES et MAX_LIGHTS au plus).
-- ViewportFrame (Viewport = true) : ni SurfaceGui, ni particules, ni Beam n'y sont rendus, l'aura y est un anneau de
-- briques.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aura = {}

export type Options = {
	Rarity: string,
	Radius: number, -- rayon du cercle au sol (studs)
	Height: number, -- hauteur du corps (studs)
	Pivot: (() -> CFrame)?, -- point au sol sous le centre, orienté comme le corps (défaut : Root.CFrame)
	Root: BasePart?, -- pièce suivie quand il n'y a pas de Pivot
	Top: (() -> Vector3)?, -- haut de la tête (dinos) ou du bloc : les cercles au-dessus s'y empilent (sans Top : aucun)
	Footprint: Vector2?, -- demi-largeur (X) et demi-longueur (Z) du corps : orbite des comètes (défaut : le cercle)
	Body: Instance?, -- ce qu'entoure le contour lumineux (défaut : le modèle)
	Ground: boolean?, -- cercle, lueur et ondes au sol (défaut true ; false pour un bloc porté)
	Pillar: boolean?, -- rayon de lumière (défaut : selon la rareté)
	Halos: number?, -- cercles au-dessus de la tête (défaut : selon la rareté ; 0 sans Top)
	Intensity: number?, -- 0 à 1 : multiplie les étincelles et les comètes (défaut 1)
	Light: boolean?, -- lumière colorée (défaut : selon la rareté ; false quand le modèle a déjà la sienne)
	Veil: boolean?, -- voile d'énergie autour du corps (défaut : selon la rareté ; false s'il gênerait la vue)
	VeilSize: Vector3?, -- voile : demi-largeur (X) et demi-longueur (Z) au sol, hauteur (Y) avant le facteur de la rareté
	-- (défaut : 0,8 x Footprint et Height)
	Parent: Instance?, -- où ranger les pièces de l'aura (défaut : le modèle)
	Viewport: boolean?, -- ViewportFrame : anneau de briques seulement
}

type Tier = {
	Rank: number,
	Rings: number, -- 1 anneau, 2 double anneau, 3 avec le cercle intérieur
	Dots: number, -- points sur l'anneau extérieur
	Runes: number, -- runes entre les deux anneaux extérieurs
	Star: { number }?, -- étoile { n, k } dans le cercle intérieur
	Crown: number, -- losanges sur un anneau extérieur qui tourne à l'envers
	Glow: number, -- opacité de la lueur au sol (0 : pas de lueur)
	Vortex: boolean, -- tourbillon au sol
	Spin: number, -- vitesse de rotation des cercles (radians par seconde)
	Motes: number, -- poussière lumineuse qui monte, par seconde pour un cercle de 6 studs
	Streaks: number, -- traits de lumière qui montent du bord du cercle, par seconde
	Haze: number, -- brume colorée qui monte autour du corps, par seconde (l'« aura » au sens propre)
	Flames: number, -- flammes qui montent du cercle, par seconde
	Orbiters: number, -- comètes autour du corps
	Veil: number, -- voile d'énergie autour du corps : hauteur (x la hauteur du corps), 0 : pas de voile
	Halos: number, -- cercles empilés au-dessus de la tête
	Pillar: boolean, -- rayon de lumière vers le ciel
	Shock: number, -- période de l'onde de choc au sol (secondes, 0 : seulement sur Pulse)
	Outline: boolean, -- contour lumineux (Highlight)
	Light: number, -- luminosité de la lumière colorée (0 : pas de lumière)
	Bright: number, -- luminosité des cercles et des particules (au-dessus de 1 : le bloom les fait briller)
	Rainbow: boolean,
	Range: number, -- portée de l'aura pour un cercle de 6 studs (studs)
}

local TIERS: { [string]: Tier } = {
	Common = {
		Rank = 1, Rings = 1, Dots = 4, Runes = 0, Star = nil, Crown = 0, Glow = 0, Vortex = false, Spin = 0.25,
		Motes = 0, Streaks = 0, Haze = 0, Flames = 0, Orbiters = 0, Halos = 0, Pillar = false, Shock = 0, Outline = false, Light = 0,
		Veil = 0, Bright = 1.3, Rainbow = false, Range = 110,
	},
	Uncommon = {
		Rank = 2, Rings = 2, Dots = 6, Runes = 0, Star = nil, Crown = 0, Glow = 0.22, Vortex = false, Spin = 0.3,
		Motes = 3, Streaks = 0, Haze = 0, Flames = 0, Orbiters = 0, Halos = 0, Pillar = false, Shock = 0, Outline = false, Light = 0,
		Veil = 0.7, Bright = 1.7, Rainbow = false, Range = 140,
	},
	Rare = {
		Rank = 3, Rings = 3, Dots = 6, Runes = 12, Star = { 3, 1 }, Crown = 0, Glow = 0.3, Vortex = false, Spin = 0.32,
		Motes = 5, Streaks = 4, Haze = 0, Flames = 0, Orbiters = 0, Halos = 0, Pillar = false, Shock = 0, Outline = false, Light = 0.8,
		Veil = 0.8, Bright = 2.1, Rainbow = false, Range = 180,
	},
	Epic = {
		Rank = 4, Rings = 3, Dots = 8, Runes = 16, Star = { 5, 2 }, Crown = 0, Glow = 0.38, Vortex = true, Spin = 0.35,
		Motes = 7, Streaks = 6, Haze = 5, Flames = 0, Orbiters = 2, Halos = 0, Pillar = false, Shock = 0, Outline = false, Light = 1.1,
		Veil = 0.88, Bright = 2.5, Rainbow = false, Range = 220,
	},
	Legendary = {
		Rank = 5, Rings = 3, Dots = 8, Runes = 20, Star = { 6, 2 }, Crown = 8, Glow = 0.46, Vortex = true, Spin = 0.38,
		Motes = 9, Streaks = 9, Haze = 7, Flames = 0, Orbiters = 3, Halos = 1, Pillar = true, Shock = 0, Outline = true, Light = 1.5,
		Veil = 0.95, Bright = 2.9, Rainbow = false, Range = 280,
	},
	Mythic = {
		Rank = 6, Rings = 3, Dots = 8, Runes = 24, Star = { 8, 3 }, Crown = 12, Glow = 0.55, Vortex = true, Spin = 0.42,
		Motes = 11, Streaks = 12, Haze = 9, Flames = 10, Orbiters = 4, Halos = 2, Pillar = true, Shock = 3.2, Outline = true, Light = 2,
		Veil = 1, Bright = 3.3, Rainbow = false, Range = 340,
	},
	Secret = {
		Rank = 7, Rings = 3, Dots = 12, Runes = 24, Star = { 12, 5 }, Crown = 12, Glow = 0.6, Vortex = true, Spin = 0.45,
		Motes = 14, Streaks = 14, Haze = 10, Flames = 0, Orbiters = 6, Halos = 3, Pillar = true, Shock = 2.6, Outline = true, Light = 2.2,
		Veil = 1.05, Bright = 3.3, Rainbow = true, Range = 380,
	},
}

-- Couleurs de secours (les mêmes que Config.Rarity) et accents chauds des hautes raretés (explosion de Megumin)
local FALLBACK: { [string]: Color3 } = {
	Common = Color3.fromRGB(163, 162, 165),
	Uncommon = Color3.fromRGB(75, 175, 75),
	Rare = Color3.fromRGB(30, 110, 220),
	Epic = Color3.fromRGB(140, 60, 210),
	Legendary = Color3.fromRGB(255, 145, 20),
	Mythic = Color3.fromRGB(215, 35, 35),
	Secret = Color3.fromRGB(255, 90, 200),
}
local ACCENT: { [string]: Color3 } = {
	Legendary = Color3.fromRGB(255, 232, 150),
	Mythic = Color3.fromRGB(255, 170, 60),
}

local WHITE = Color3.new(1, 1, 1)
local CANVAS = 512 -- pixels de la SurfaceGui d'un cercle (étirée sur la pièce)
local MARGIN = 1.45 -- la pièce du cercle au sol fait MARGIN x son diamètre (place pour l'onde de choc)
local LIFT = 0.07 -- hauteur du cercle au-dessus du sol (studs)
local HALO_TILT = math.rad(24) -- cercles au-dessus de la tête penchés vers la caméra
local MAX_OUTLINES, MAX_LIGHTS = 6, 8
local OUTLINE_DIST, LIGHT_DIST = 90, 70 -- studs (multipliés par la taille de l'aura)
local TEX = "rbxasset://textures/particles/"
local SPARKLE = TEX .. "sparkles_main.dds" -- étoile à 8 branches
local GLOW = TEX .. "explosion01_implosion_main.dds" -- halo rond et doux
local RING = TEX .. "explosion01_shockwave_main.dds" -- anneau doux
local VORTEX = TEX .. "forcefield_vortex_main.dds" -- anneau à reflets
local FLAME = TEX .. "fire_main.dds"
local SMOKE = TEX .. "smoke_main.dds" -- volutes du voile
local VEIL_INSET = 0.72 -- le voile se resserre en montant (largeur en haut / largeur au sol)
local VEIL_STEP = 1.6 -- studs entre deux rubans du voile
-- runes : lettres grecques (les runes nordiques ne s'affichent pas dans les polices de Roblox)
local RUNES = { "Γ", "Δ", "Θ", "Λ", "Ξ", "Π", "Σ", "Φ", "Ψ", "Ω", "δ", "ζ", "θ", "λ", "ξ", "π", "φ", "ψ", "ω", "β" }

type Palette = { Main: Color3, Light: Color3, Hot: Color3, Accent: Color3 }
type Layer = { Gui: Frame, Speed: number }
type Halo = { Part: Part, Radius: number, Lift: number }
type Orbiter = { Part: Part, Trail: Trail, Tilt: CFrame, Phase: number, Speed: number, Wobble: number }

export type Handle = {
	Model: Instance,
	Rarity: string,
	Rank: number,
	Tier: Tier,
	Colors: Palette,
	Radius: number,
	Height: number,
	Range: number,
	Size: number, -- facteur de taille (1 pour un cercle de 6 studs)
	Pivot: () -> CFrame,
	Top: (() -> Vector3)?,
	Footprint: Vector2,
	Body: Instance,
	Folder: Folder,
	Viewport: boolean,
	Ground: boolean,
	Intensity: number,
	Lit: boolean, -- lumière colorée prêtée quand l'aura est proche
	Layers: { Layer },
	Sigil: Part?,
	ShockRing: Frame?,
	ShockStroke: UIStroke?,
	ShockT: number, -- temps depuis la dernière onde (> 1 : rien en cours)
	NextShock: number,
	Core: Part,
	Center: Attachment,
	Emitters: { ParticleEmitter },
	Rates: { number },
	Motes: ParticleEmitter?,
	Shock: ParticleEmitter?,
	Halos: { Halo },
	HeadPos: Vector3?,
	PillarRoot: Part?, -- pied du rayon au-dessus du dernier cercle (jamais incliné)
	Orbiters: { Orbiter },
	OrbitState: number, -- comètes : 0 cachées, 1 placées mais encore cachées, 2 visibles
	Veil: Part?, -- pied du voile (au sol sous le centre, tourné comme le corps)
	VeilSize: Vector3,
	Veils: { Beam }, -- rubans (« Veil ») et volutes (« Wisp ») du voile
	VeilAt: Vector3?,
	VeilYaw: number,
	Beams: { Beam },
	Ring: { Part }, -- ViewportFrame : anneau de briques
	Lod: number, -- 0 tout, 1 mi-distance, 2 loin (cercle et rayon), 3 caché
	OnScreen: boolean,
	Dist: number,
	Clock: number,
	Moved: Vector3?,
	Outline: Highlight?,
	Light: PointLight?,
	Dead: boolean,
}

local auras: { Handle } = {}
local outlines: { Highlight } = {}
local lights: { PointLight } = {}
local seed = 0
local poolClock = 0
local started = false

-- ====================================================================== couleurs

local Config: any = nil
local configTried = false

local function baseColor(rarity: string): Color3
	if not configTried then
		configTried = true
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("Config")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok then
				Config = result
			end
		end
	end
	if Config then
		local ok, color = pcall(function()
			return Config.Rarity.Info[rarity].Color
		end)
		if ok and typeof(color) == "Color3" then
			return color
		end
	end
	return FALLBACK[rarity] or FALLBACK.Common
end

local function palette(rarity: string): Palette
	local h, s, v = baseColor(rarity):ToHSV()
	local main = Color3.fromHSV(h, math.min(1, s * 1.08), math.max(v, 0.88))
	return {
		Main = main,
		Light = main:Lerp(WHITE, 0.35),
		Hot = main:Lerp(WHITE, 0.7),
		Accent = ACCENT[rarity] or main:Lerp(WHITE, 0.35),
	}
end

local function hue(h: number): Color3
	return Color3.fromHSV(h % 1, 0.75, 1)
end

local function rainbow(): ColorSequence
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, hue(i / 6)))
	end
	return ColorSequence.new(keys)
end

-- ====================================================================== pièces et dessin

local function newPart(name: string, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surface(part: Part, face: Enum.NormalId, bright: number, range: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = if face == Enum.NormalId.Top then "Top" else "Bottom"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(CANVAS, CANVAS)
	gui.LightInfluence = 0
	gui.Brightness = bright
	gui.MaxDistance = range
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	return gui
end

local HALF = Vector2.new(0.5, 0.5)

local function layer(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = HALF
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

-- Anneau centré sur `radius` (pixels) : le trait UIStroke est dessiné à l'extérieur du cadre
local function ring(parent: Instance, radius: number, thick: number, color: Color3, transparency: number, z: number, gradient: ColorSequence?): Frame
	local d = math.max(1, 2 * radius - thick)
	local f = Instance.new("Frame")
	f.Name = "Ring"
	f.AnchorPoint = HALF
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(d, d)
	f.BackgroundTransparency = 1
	f.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thick
	stroke.Color = if gradient then WHITE else color
	stroke.Transparency = transparency
	stroke.Parent = f
	if gradient then
		local g = Instance.new("UIGradient")
		g.Color = gradient
		g.Parent = stroke
	end
	f.Parent = parent
	return f
end

local function disc(parent: Instance, at: Vector2, radius: number, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Dot"
	f.AnchorPoint = HALF
	f.Position = UDim2.fromOffset(at.X, at.Y)
	f.Size = UDim2.fromOffset(2 * radius, 2 * radius)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function line(parent: Instance, a: Vector2, b: Vector2, thick: number, color: Color3, transparency: number, z: number)
	local delta = b - a
	local mid = (a + b) / 2
	local f = Instance.new("Frame")
	f.Name = "Line"
	f.AnchorPoint = HALF
	f.Position = UDim2.fromOffset(mid.X, mid.Y)
	f.Size = UDim2.fromOffset(delta.Magnitude + thick * 0.6, thick)
	f.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
end

local function glyph(parent: Instance, text: string, at: Vector2, size: number, rotation: number, color: Color3, z: number)
	local t = Instance.new("TextLabel")
	t.Name = "Rune"
	t.AnchorPoint = HALF
	t.Position = UDim2.fromOffset(at.X, at.Y)
	t.Size = UDim2.fromOffset(size, size)
	t.Rotation = rotation
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Fantasy
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.ZIndex = z
	t.Parent = parent
end

type Spec = {
	Tier: Tier,
	Colors: Palette,
	Radius: number, -- rayon du cercle (pixels)
	Pps: number, -- pixels par stud
	Runes: number,
	Star: { number }?,
	Crown: number,
	Rings: number,
	Dots: number,
	Fill: number, -- transparence du voile coloré sous le cercle
	Rng: Random,
}

-- Dessine un cercle magique dans `gui` ; renvoie ses calques qui tournent
local function drawCircle(gui: SurfaceGui, spec: Spec): { Layer }
	local tier, c = spec.Tier, spec.Colors
	local rc, pps = spec.Radius, spec.Pps
	local center = Vector2.new(CANVAS / 2, CANVAS / 2)
	local bow = if tier.Rainbow then rainbow() else nil
	-- épaisseur : une part du rayon, jamais moins de `studs` pour que les petits cercles restent lisibles
	local function px(fraction: number, studs: number): number
		return math.max(fraction * rc, studs * pps)
	end
	local function polar(r: number, angle: number): Vector2
		return center + Vector2.new(math.cos(angle), math.sin(angle)) * r
	end
	local function tint(angle: number, color: Color3): Color3
		return if tier.Rainbow then hue(angle / (2 * math.pi)):Lerp(WHITE, 0.25) else color
	end
	local layers: { Layer } = {}
	local spin = tier.Spin

	local outer = layer(gui, "Outer")
	table.insert(layers, { Gui = outer, Speed = spin })
	-- voile coloré sous tout le cercle : il se lit de loin, même quand les traits sont trop fins pour l'écran
	disc(outer, center, rc, c.Main, spec.Fill, 0)
	ring(outer, rc, px(0.085, 0.3), c.Main, 0.62, 1, bow)
	ring(outer, rc, px(0.024, 0.1), c.Light, 0, 3, bow)
	local band = rc * 0.84
	if spec.Rings >= 2 then
		ring(outer, band, px(0.05, 0.18), c.Main, 0.7, 1, bow)
		ring(outer, band, px(0.014, 0.07), c.Light, 0.05, 3, bow)
	end
	for i = 1, spec.Dots do
		local angle = (i - 1) / spec.Dots * 2 * math.pi
		disc(outer, polar(rc, angle), px(0.035, 0.11), tint(angle, c.Hot), 0, 4)
	end
	if spec.Runes > 0 and spec.Rings >= 2 then
		local mid = (rc + band) / 2
		local size = (rc - band) * 0.78
		for i = 1, spec.Runes do
			local angle = (i - 0.5) / spec.Runes * 2 * math.pi
			local text = RUNES[spec.Rng:NextInteger(1, #RUNES)]
			glyph(outer, text, polar(mid, angle), size, math.deg(angle) + 90, tint(angle, c.Accent), 3)
		end
	end

	if spec.Rings >= 3 then
		local inner = layer(gui, "Inner")
		table.insert(layers, { Gui = inner, Speed = -1.6 * spin })
		local ri = rc * 0.6
		ring(inner, ri, px(0.07, 0.26), c.Main, 0.66, 1, bow)
		ring(inner, ri, px(0.02, 0.09), c.Light, 0, 3, bow)
		local star = spec.Star
		if star then
			local n, k = star[1], star[2]
			for j = 0, n - 1 do
				local a0 = -math.pi / 2 + j / n * 2 * math.pi
				local a1 = -math.pi / 2 + ((j + k) % n) / n * 2 * math.pi
				local p0, p1 = polar(ri, a0), polar(ri, a1)
				line(inner, p0, p1, px(0.06, 0.22), tint(a0, c.Main), 0.68, 1)
				line(inner, p0, p1, px(0.017, 0.08), tint(a0, c.Light), 0, 2)
				disc(inner, p0, px(0.035, 0.1), tint(a0, c.Hot), 0, 4)
			end
		end
		ring(inner, rc * 0.24, px(0.016, 0.07), c.Light, 0.05, 3, bow)
		disc(inner, center, px(0.06, 0.14), c.Main, 0.5, 2)
		disc(inner, center, px(0.028, 0.08), c.Hot, 0, 4)
	end

	if spec.Crown > 0 then
		local crown = layer(gui, "Crown")
		table.insert(layers, { Gui = crown, Speed = -0.7 * spin })
		local rr = rc * 1.12
		ring(crown, rr, px(0.01, 0.05), c.Light, 0.3, 1, bow)
		for i = 1, spec.Crown do
			local angle = (i - 1) / spec.Crown * 2 * math.pi
			local at = polar(rr, angle)
			local size = px(0.075, 0.22)
			local f = Instance.new("Frame")
			f.Name = "Gem"
			f.AnchorPoint = HALF
			f.Position = UDim2.fromOffset(at.X, at.Y)
			f.Size = UDim2.fromOffset(size, size)
			f.Rotation = math.deg(angle) + 45
			f.BackgroundColor3 = tint(angle, c.Accent)
			f.BorderSizePixel = 0
			f.ZIndex = 4
			f.Parent = crown
		end
	end
	return layers
end

-- ====================================================================== particules et rayons

local function sequence(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function emitter(a: Handle, name: string, parent: Instance, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = rate
	e.LightInfluence = 0
	e.Parent = parent
	table.insert(a.Emitters, e)
	table.insert(a.Rates, rate)
	return e
end

-- Particule plate posée au sol (VelocityPerpendicular : la vitesse vers le haut la couche à plat)
local function flatEmitter(a: Handle, name: string, texture: string, rate: number): ParticleEmitter
	local e = emitter(a, name, a.Center, rate)
	e.Texture = texture
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(0.01)
	e.SpreadAngle = Vector2.zero
	e.LockedToPart = true
	e.LightEmission = 1
	e.Brightness = a.Tier.Bright * 0.6
	return e
end

local function buildParticles(a: Handle)
	local tier, c = a.Tier, a.Colors
	local r = a.Radius
	local s = math.sqrt(a.Size)
	local amount = math.clamp(r / 6, 0.5, 2.5) * a.Intensity
	if a.Ground and tier.Glow > 0 then
		local glow = flatEmitter(a, "Glow", GLOW, 1.25)
		glow.Color = ColorSequence.new(c.Main)
		glow.Lifetime = NumberRange.new(1.6)
		glow.Size = NumberSequence.new(math.min(2.5 * r, 100))
		glow.Transparency = sequence({ { 0, 1 }, { 0.3, 1 - tier.Glow }, { 0.7, 1 - tier.Glow }, { 1, 1 } })
		glow.RotSpeed = NumberRange.new(-12, 12)
		glow.Rotation = NumberRange.new(0, 360)
		glow.ZOffset = -0.5
	end
	if a.Ground and tier.Vortex then
		local vortex = flatEmitter(a, "Vortex", VORTEX, 0.9)
		vortex.Color = ColorSequence.new(c.Light, c.Main)
		vortex.Lifetime = NumberRange.new(2.4)
		vortex.Size = sequence({ { 0, math.min(1.5 * r, 100) }, { 1, math.min(1.95 * r, 100) } })
		vortex.Transparency = sequence({ { 0, 1 }, { 0.25, 0.55 }, { 0.75, 0.6 }, { 1, 1 } })
		vortex.RotSpeed = NumberRange.new(70, 110)
		vortex.Rotation = NumberRange.new(0, 360)
	end
	if a.Ground then
		local shock = flatEmitter(a, "Shock", RING, 0)
		shock.Color = if tier.Rainbow then rainbow() else ColorSequence.new(c.Light, c.Main)
		shock.Lifetime = NumberRange.new(0.9)
		shock.Size = sequence({ { 0, math.min(0.8 * r, 100) }, { 1, math.min(3.2 * r, 100) } })
		shock.Transparency = sequence({ { 0, 0.05 }, { 0.6, 0.45 }, { 1, 1 } })
		shock.Brightness = tier.Bright
		a.Shock = shock
	end
	-- poussière lumineuse qui monte de tout le disque (le cœur est une pièce plate de la taille du cercle)
	local motes = emitter(a, "Motes", a.Core, tier.Motes * amount)
	motes.Shape = Enum.ParticleEmitterShape.Disc
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Texture = SPARKLE
	motes.Color = if tier.Rainbow then rainbow() else ColorSequence.new(c.Hot, c.Main)
	motes.Lifetime = NumberRange.new(1.2, 2.1)
	motes.Speed = NumberRange.new(2.2 * s, 4.5 * s)
	motes.SpreadAngle = Vector2.new(10, 10)
	motes.Acceleration = Vector3.new(0, 1.2 * s, 0)
	motes.Drag = 0.4
	motes.Size = sequence({ { 0, 0 }, { 0.15, 0.42 * s }, { 0.7, 0.3 * s }, { 1, 0 } })
	motes.Transparency = sequence({ { 0, 0.1 }, { 0.75, 0.25 }, { 1, 1 } })
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-120, 120)
	motes.LightEmission = 1
	motes.Brightness = tier.Bright
	a.Motes = motes
	if tier.Streaks > 0 and a.Ground then
		-- traits de lumière qui montent du bord du cercle (particules étirées dans le sens de la vitesse)
		local streaks = emitter(a, "Streaks", a.Core, tier.Streaks * amount)
		streaks.Shape = Enum.ParticleEmitterShape.Disc
		streaks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		streaks.ShapePartial = 0.9
		streaks.EmissionDirection = Enum.NormalId.Top
		streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
		streaks.Texture = GLOW
		streaks.Color = if tier.Rainbow then rainbow() else ColorSequence.new(c.Light, c.Main)
		streaks.Lifetime = NumberRange.new(0.6, 1)
		streaks.Speed = NumberRange.new(5 * s, 8 * s)
		streaks.SpreadAngle = Vector2.new(3, 3)
		streaks.Size = sequence({ { 0, 0.55 * s }, { 1, 0.25 * s } })
		streaks.Squash = NumberSequence.new(-2.4)
		streaks.Transparency = sequence({ { 0, 1 }, { 0.15, 0.2 }, { 0.7, 0.45 }, { 1, 1 } })
		streaks.LightEmission = 1
		streaks.Brightness = tier.Bright
	end
	if tier.Haze > 0 then
		-- brume colorée qui monte à travers le corps : l'aura qui entoure le dino ou le bloc
		local haze = emitter(a, "Haze", a.Core, 1.3 * tier.Haze * amount)
		haze.Shape = Enum.ParticleEmitterShape.Disc
		haze.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		haze.ShapePartial = 0.35
		haze.EmissionDirection = Enum.NormalId.Top
		haze.Texture = GLOW
		haze.Color = if tier.Rainbow then rainbow() else ColorSequence.new(c.Main)
		haze.Lifetime = NumberRange.new(1.2, 1.8)
		haze.Speed = NumberRange.new(0.25 * a.Height, 0.5 * a.Height)
		haze.SpreadAngle = Vector2.new(8, 8)
		haze.Size = sequence({ { 0, 0.48 * r }, { 1, 0.8 * r } })
		haze.Transparency = sequence({ { 0, 1 }, { 0.25, 0.74 }, { 0.7, 0.82 }, { 1, 1 } })
		haze.Rotation = NumberRange.new(0, 360)
		haze.RotSpeed = NumberRange.new(-30, 30)
		haze.LightEmission = 0.6
		haze.Brightness = tier.Bright * 0.5
	end
	if tier.Flames > 0 and a.Ground then
		-- flammes : seulement sur le bord du cercle (couronne entre 85 % et 100 % du rayon), assez pour en faire le tour
		local perimeter = math.clamp(2 * math.pi * r / 5, 2, 10)
		local flames = emitter(a, "Flames", a.Core, tier.Flames * perimeter * a.Intensity)
		flames.Shape = Enum.ParticleEmitterShape.Disc
		flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		flames.ShapePartial = 0.85
		flames.EmissionDirection = Enum.NormalId.Top
		flames.Texture = FLAME
		flames.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c.Hot),
			ColorSequenceKeypoint.new(0.35, c.Accent),
			ColorSequenceKeypoint.new(1, c.Main),
		})
		flames.Lifetime = NumberRange.new(0.5, 0.9)
		flames.Speed = NumberRange.new(4 * s, 6 * s)
		flames.SpreadAngle = Vector2.new(6, 6)
		flames.Drag = 1.5
		flames.Size = sequence({ { 0, 1 * s }, { 0.35, 2.2 * s }, { 1, 0.3 * s } })
		flames.Transparency = sequence({ { 0, 0.05 }, { 0.5, 0.25 }, { 1, 1 } })
		flames.Rotation = NumberRange.new(-20, 20)
		flames.RotSpeed = NumberRange.new(-40, 40)
		flames.LightEmission = 0.15 -- presque opaques : plus lumineuses, elles disparaîtraient sur l'herbe claire
		flames.Brightness = tier.Bright * 0.9
	end
end

local function newBeam(a: Handle, name: string, from: Attachment, to: Attachment, w0: number, w1: number, transparency: NumberSequence, color: ColorSequence): Beam
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0 = from
	b.Attachment1 = to
	b.FaceCamera = true
	b.Width0 = w0
	b.Width1 = w1
	b.Segments = 1
	b.Transparency = transparency
	b.Color = color
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = a.Tier.Bright
	b.Parent = from.Parent
	return b
end

-- Rayon (caché seulement au-delà de la portée)
local function beam(a: Handle, name: string, from: Attachment, to: Attachment, w0: number, w1: number, transparency: NumberSequence, color: ColorSequence): Beam
	local b = newBeam(a, name, from, to, w0, w1, transparency, color)
	table.insert(a.Beams, b)
	return b
end

-- Rayon de lumière : du haut de la colonne de cercles (dinos) ou du sol (blocs) vers le ciel
local function buildPillar(a: Handle, base: BasePart, width: number)
	local c = a.Colors
	local length = math.clamp(6 * a.Height, 24, 70)
	local from = Instance.new("Attachment")
	from.Name = "PillarBase"
	from.Parent = base
	local to = Instance.new("Attachment")
	to.Name = "PillarTop"
	to.Position = Vector3.new(0, length, 0)
	to.Parent = base
	local color = if a.Tier.Rainbow then rainbow() else ColorSequence.new(c.Main)
	beam(a, "Pillar", from, to, width, width * 0.5, sequence({ { 0, 0.62 }, { 0.5, 0.8 }, { 1, 1 } }), color)
	local core = beam(a, "PillarCore", from, to, width * 0.28, width * 0.12, sequence({ { 0, 0.2 }, { 0.6, 0.6 }, { 1, 1 } }), ColorSequence.new(c.Hot))
	core.Texture = SPARKLE
	core.TextureMode = Enum.TextureMode.Wrap
	core.TextureLength = math.max(1, width * 0.8)
	core.TextureSpeed = 0.5
end

-- ====================================================================== construction

local function flatCFrame(position: Vector3): CFrame
	return CFrame.new(position)
end

local function buildSigil(a: Handle)
	local tier = a.Tier
	local size = 2 * a.Radius * MARGIN
	local part = newPart("Circle", Vector3.new(size, 0.05, size), a.Folder)
	local gui = surface(part, Enum.NormalId.Top, tier.Bright, a.Range)
	seed += 1
	for _, l in
		drawCircle(gui, {
			Tier = tier,
			Colors = a.Colors,
			Radius = CANVAS / 2 / MARGIN,
			Pps = CANVAS / size,
			Runes = tier.Runes,
			Star = tier.Star,
			Crown = tier.Crown,
			Rings = tier.Rings,
			Dots = tier.Dots,
			Fill = 0.88 - 0.02 * tier.Rank,
			Rng = Random.new(seed),
		})
	do
		table.insert(a.Layers, l)
	end
	-- onde de choc dessinée (avec l'anneau doux en particules)
	local shock = ring(gui, CANVAS / 2 / MARGIN, 10, a.Colors.Hot, 1, 5, if tier.Rainbow then rainbow() else nil)
	shock.Name = "Shock"
	a.ShockRing = shock
	a.ShockStroke = shock:FindFirstChildOfClass("UIStroke")
	a.Sigil = part
end

local function buildHalos(a: Handle, count: number)
	local tier = a.Tier
	local h = a.Height
	local base = math.clamp(0.24 * h, 0.9, 5)
	for i = 0, count - 1 do
		local radius = base * (1 - 0.16 * i)
		local size = 2 * radius * 1.2
		local part = newPart("HeadCircle", Vector3.new(size, 0.05, size), a.Folder)
		local spec: Spec = {
			Tier = tier,
			Colors = a.Colors,
			Radius = CANVAS / 2 / 1.2,
			Pps = CANVAS / size,
			Runes = if tier.Runes > 0 then 10 else 0,
			Star = if i % 2 == 0 then { 6, 2 } else { 5, 2 },
			Crown = 0,
			Rings = 3,
			Dots = 6,
			Fill = 0.8,
			Rng = Random.new(seed + 100 + i),
		}
		-- visible de dessus et de dessous (la caméra passe souvent sous les cercles)
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local gui = surface(part, face, tier.Bright, a.Range)
			for _, l in drawCircle(gui, spec) do
				table.insert(a.Layers, { Gui = l.Gui, Speed = l.Speed * (if i % 2 == 0 then -1.3 else 1.5) })
			end
		end
		table.insert(a.Halos, { Part = part, Radius = radius, Lift = math.clamp(0.14 * h, 0.8, 4) + i * math.clamp(0.22 * h, 0.9, 5) })
	end
end

local function buildOrbiters(a: Handle, count: number)
	local c = a.Colors
	local rng = Random.new(seed + 7)
	local size = math.clamp(0.045 * a.Height, 0.25, 0.8)
	for k = 1, count do
		local orb = newPart("Comet", Vector3.new(size, size, size), a.Folder)
		orb.Shape = Enum.PartType.Ball
		orb.Material = Enum.Material.Neon
		-- tête presque blanche (la couleur est dans la traînée) : une boule pleine couleur fait jouet
		orb.Color = if a.Tier.Rainbow then hue(k / count):Lerp(WHITE, 0.55) else c.Hot
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, size * 0.45, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -size * 0.45, 0)
		a1.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.FaceCamera = true
		trail.Lifetime = 0.45
		trail.MinLength = 0.05
		trail.Color = if a.Tier.Rainbow then ColorSequence.new(hue(k / count)) else ColorSequence.new(c.Light, c.Main)
		trail.Transparency = sequence({ { 0, 0.1 }, { 1, 1 } })
		trail.WidthScale = sequence({ { 0, 1 }, { 1, 0 } })
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Brightness = a.Tier.Bright
		trail.Enabled = false -- montrée par stepAura une fois la comète à sa place
		trail.Parent = orb
		table.insert(a.Orbiters, {
			Part = orb,
			Trail = trail,
			Tilt = CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			Phase = (k - 1) / count * 2 * math.pi,
			Speed = rng:NextNumber(1.3, 1.9) * (if k % 2 == 0 then -1 else 1),
			Wobble = rng:NextNumber(0, 2 * math.pi),
		})
	end
end

-- Voile d'énergie autour du corps : rubans de lumière verticaux (Beam qui ne se tournent pas vers la caméra) posés sur
-- l'ellipse de l'empreinte, de hauteurs inégales, qui se resserrent et s'effacent en montant comme une flamme ; une
-- volute de fumée lumineuse sur un ruban sur deux défile vers le haut (animée par la carte graphique, rien par image)
local function buildVeil(a: Handle, factor: number)
	local tier, c = a.Tier, a.Colors
	local holder = newPart("Veil", Vector3.new(0.2, 0.2, 0.2), a.Folder)
	a.Veil = holder
	local fx, fz = a.VeilSize.X, a.VeilSize.Z
	-- (périmètre de l'ellipse, formule de Ramanujan)
	local perimeter = math.pi * (3 * (fx + fz) - math.sqrt((3 * fx + fz) * (fx + 3 * fz)))
	local n = math.clamp(math.floor(perimeter / VEIL_STEP + 0.5), 8, 20)
	local rng = Random.new(seed + 31)
	local t0 = math.clamp(0.8 - 0.035 * tier.Rank, 0.5, 0.9)
	local veilFade = sequence({ { 0, t0 }, { 0.35, (t0 + 1) / 2 }, { 1, 1 } })
	local wispFade = sequence({ { 0, 0.25 }, { 0.5, 0.6 }, { 1, 1 } })
	local base = if tier.Flames > 0 then c.Accent else c.Light
	local function at(k: number): Vector3
		local angle = k / n * 2 * math.pi
		return Vector3.new(math.cos(angle) * fx, 0.1, math.sin(angle) * fz)
	end
	for k = 1, n do
		local foot = at(k - 0.5)
		local width = (at(k) - at(k - 1)).Magnitude
		local top = Vector3.new(foot.X * VEIL_INSET, a.VeilSize.Y * factor * rng:NextNumber(0.6, 1.25), foot.Z * VEIL_INSET)
		local up = (top - foot).Unit
		local angle = (k - 0.5) / n * 2 * math.pi
		local tangent = Vector3.new(-math.sin(angle) * fx, 0, math.cos(angle) * fz)
		tangent = (tangent - up * tangent:Dot(up)).Unit
		-- (un ruban s'étale le long de l'axe Y de ses attachments : la tangente à l'ellipse)
		local a0 = Instance.new("Attachment")
		a0.CFrame = CFrame.fromMatrix(foot, up, tangent)
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.CFrame = CFrame.fromMatrix(top, up, tangent)
		a1.Parent = holder
		local color = if tier.Rainbow then ColorSequence.new(hue(k / n):Lerp(WHITE, 0.3), hue(k / n + 0.08)) else ColorSequence.new(base, c.Main)
		local veil = newBeam(a, "Veil", a0, a1, width, width * VEIL_INSET, veilFade, color)
		veil.FaceCamera = false
		veil.Brightness = 1 + 0.4 * tier.Bright
		table.insert(a.Veils, veil)
		if k % 2 == 0 then
			local tint = ColorSequence.new(if tier.Rainbow then hue(k / n):Lerp(WHITE, 0.35) else base)
			local wisp = newBeam(a, "Wisp", a0, a1, width, width * VEIL_INSET * 0.7, wispFade, tint)
			wisp.FaceCamera = false
			wisp.Texture = SMOKE
			wisp.TextureMode = Enum.TextureMode.Wrap
			wisp.TextureLength = math.max(1, a.VeilSize.Y * 0.7)
			wisp.TextureSpeed = rng:NextNumber(0.6, 1.1)
			table.insert(a.Veils, wisp)
		end
	end
end

-- ViewportFrame : anneau de briques lumineuses (ni SurfaceGui ni particules n'y sont rendus)
local function buildRing(a: Handle)
	local r = a.Radius
	local n = math.clamp(math.floor(2 * math.pi * r / 1.6 + 0.5), 12, 28)
	local width = math.clamp(0.12 * r, 0.25, 1.2)
	for i = 1, n do
		local p = newPart("Ring", Vector3.new(2 * math.pi * r / n + width * 0.3, width * 0.5, width), a.Folder)
		p.Material = Enum.Material.Neon
		p.Color = if a.Tier.Rainbow then hue(i / n) else a.Colors.Main
		p.Transparency = 0.1
		table.insert(a.Ring, p)
	end
end

-- ====================================================================== niveau de détail

local function setEmitters(a: Handle, factor: number)
	for i, e in a.Emitters do
		local rate = a.Rates[i] * factor
		e.Enabled = rate > 0 or e == a.Shock
		e.Rate = rate
	end
end

local function setVisible(a: Handle, sigil: boolean, halos: boolean, beams: boolean)
	local sigilPart = a.Sigil
	if sigilPart then
		for _, gui in sigilPart:GetChildren() do
			if gui:IsA("SurfaceGui") then
				gui.Enabled = sigil
			end
		end
	end
	for _, halo in a.Halos do
		for _, gui in halo.Part:GetChildren() do
			if gui:IsA("SurfaceGui") then
				gui.Enabled = halos
			end
		end
	end
	for _, b in a.Beams do
		b.Enabled = beams
	end
	for _, p in a.Ring do
		p.Transparency = if sigil then 0.1 else 1
	end
end

-- Comètes montrées ou cachées (tête et traînée)
local function showOrbiters(a: Handle, shown: boolean)
	for _, o in a.Orbiters do
		o.Part.Transparency = if shown then 0 else 1
		o.Trail.Enabled = shown
	end
	a.OrbitState = if shown then 2 else 0
end

local function applyLod(a: Handle, lod: number)
	a.Lod = lod
	if lod == 0 then
		setEmitters(a, 1)
		setVisible(a, true, true, true)
	elseif lod == 1 then
		setEmitters(a, 0.5)
		setVisible(a, true, true, true)
	elseif lod == 2 then
		setEmitters(a, 0)
		setVisible(a, true, false, true)
	else
		setEmitters(a, 0)
		setVisible(a, false, false, false)
	end
	-- voile : de près et à mi-distance, ses volutes de près seulement
	for _, b in a.Veils do
		b.Enabled = lod == 0 or (lod == 1 and b.Name == "Veil")
	end
	-- (comètes : seulement de près, voir stepAura)
	if lod > 0 and a.OrbitState ~= 0 then
		showOrbiters(a, false)
	end
end

-- ====================================================================== animation

local function startShock(a: Handle)
	local shock = a.Shock
	if shock and a.Lod <= 1 then
		shock:Emit(1)
	end
	a.ShockT = 0
end

local function stepShock(a: Handle, dt: number)
	local frame, stroke = a.ShockRing, a.ShockStroke
	if not (frame and stroke) or a.ShockT > 1 then
		return
	end
	a.ShockT += dt / 0.85
	local k = math.clamp(a.ShockT, 0, 1)
	local ease = 1 - (1 - k) ^ 3
	local rc = CANVAS / 2 / MARGIN
	local radius = rc * (0.95 + 0.45 * ease)
	local thick = 22 * (1 - k) + 3
	local d = math.max(1, 2 * radius - thick)
	frame.Size = UDim2.fromOffset(d, d)
	stroke.Thickness = thick
	stroke.Transparency = if k >= 1 then 1 else 0.1 + 0.9 * k * k
end

local function pivotOf(a: Handle): CFrame?
	local ok, cf = pcall(a.Pivot)
	if ok and typeof(cf) == "CFrame" then
		return cf
	end
	return nil
end

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local function stepAura(a: Handle, dt: number, camPos: Vector3, cam: Camera?)
	local pivot = pivotOf(a)
	if not pivot then
		return
	end
	local ground = pivot.Position
	a.Clock += dt
	-- niveau de détail (les ViewportFrame montrent tout)
	local lod = 0
	if not a.Viewport then
		local dist = (ground - camPos).Magnitude
		a.Dist = dist
		if dist > a.Range then
			lod = 3
		elseif dist > a.Range * 0.7 then
			lod = 2
		elseif dist > a.Range * 0.38 then
			lod = 1
		end
		local onScreen = true
		if cam and lod < 3 then
			local _, seen = cam:WorldToViewportPoint(ground + Vector3.new(0, a.Height * 0.5, 0))
			onScreen = seen or dist < a.Radius * 2.5
			if not onScreen then
				local _, top = cam:WorldToViewportPoint(ground + Vector3.new(0, a.Height * 1.6, 0))
				onScreen = top
			end
		end
		a.OnScreen = onScreen
	end
	if lod ~= a.Lod then
		applyLod(a, lod)
	end
	if lod == 3 then
		return
	end
	-- cercles qui tournent, onde de choc
	if a.OnScreen then
		local t = a.Clock
		for _, l in a.Layers do
			l.Gui.Rotation = math.deg(t * l.Speed) % 360
		end
		if a.Tier.Shock > 0 and t >= a.NextShock then
			a.NextShock = t + a.Tier.Shock
			startShock(a)
		end
		stepShock(a, dt)
	end
	-- cercle au sol et cœur des particules : suivent le pivot
	local moved = a.Moved
	if not moved or (moved - ground).Magnitude > 0.01 then
		a.Moved = ground
		local sigil = a.Sigil
		if sigil then
			table.insert(moveParts, sigil)
			table.insert(moveCFrames, flatCFrame(ground + Vector3.new(0, LIFT, 0)))
		end
		if a.Viewport then
			-- (ViewportFrame : hors de Workspace, pas de BulkMoveTo)
			a.Core.CFrame = flatCFrame(ground + Vector3.new(0, 0.12, 0))
		else
			table.insert(moveParts, a.Core)
			table.insert(moveCFrames, flatCFrame(ground + Vector3.new(0, 0.12, 0)))
		end
		if #a.Ring > 0 then
			local n = #a.Ring
			for i, p in a.Ring do
				local angle = (i - 0.5) / n * 2 * math.pi
				local at = ground + Vector3.new(math.cos(angle) * a.Radius, 0.15, math.sin(angle) * a.Radius)
				p.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0, math.cos(angle))) * CFrame.Angles(0, math.pi / 2, 0)
			end
		end
	end
	-- voile : son pied suit le pivot (position et lacet)
	local veil = a.Veil
	if veil and lod <= 1 then
		local look = pivot.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local at = a.VeilAt
		if not at or (at - ground).Magnitude > 0.01 or math.abs(yaw - a.VeilYaw) > 0.005 then
			a.VeilAt = ground
			a.VeilYaw = yaw
			table.insert(moveParts, veil)
			table.insert(moveCFrames, CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
		end
	end
	-- cercles au-dessus de la tête (suivent le haut de la tête, lissé ; jamais plus bas que 70 % de la hauteur, pour
	-- un dino qui dort ou qui mange) et pied du rayon posé sur le dernier : de loin les cercles sont cachés mais le
	-- rayon reste, son pied suit toujours
	if #a.Halos > 0 then
		local top = ground + Vector3.new(0, a.Height, 0)
		local getTop = a.Top
		if getTop then
			local ok, at = pcall(getTop)
			if ok and typeof(at) == "Vector3" then
				top = Vector3.new(at.X, math.max(at.Y, ground.Y + 0.7 * a.Height), at.Z)
			end
		end
		local prev = a.HeadPos
		local smooth = if prev and (prev - top).Magnitude < 4 * a.Height then prev:Lerp(top, 1 - math.exp(-dt * 10)) else top
		a.HeadPos = smooth
		if lod <= 1 then
			-- penchés vers la caméra (HALO_TILT) : vus de côté, des cercles à plat ne seraient qu'un trait
			local tilt = CFrame.identity
			local toCam = camPos - smooth
			local flat = Vector3.new(toCam.X, 0, toCam.Z)
			if flat.Magnitude > 0.1 then
				local dir = flat.Unit
				tilt = CFrame.fromAxisAngle(Vector3.new(dir.Z, 0, -dir.X), HALO_TILT) -- axe = Y × dir
			end
			for _, halo in a.Halos do
				table.insert(moveParts, halo.Part)
				table.insert(moveCFrames, CFrame.new(smooth + Vector3.new(0, halo.Lift, 0)) * tilt)
			end
		end
		local root = a.PillarRoot
		local last = a.Halos[#a.Halos]
		if root and last then
			table.insert(moveParts, root)
			table.insert(moveCFrames, flatCFrame(smooth + Vector3.new(0, last.Lift, 0)))
		end
	end
	-- comètes autour du corps : ellipse de l'empreinte, tournée comme le corps (lacet seulement). Cachées quand on ne
	-- les anime pas (loin, hors de l'écran) ; à leur retour, placées encore cachées et montrées à l'image suivante : la
	-- traînée tracerait sinon le saut depuis leur dernière place (l'origine du monde pour une aura neuve)
	if #a.Orbiters > 0 then
		if lod == 0 and a.OnScreen then
			local look = pivot.LookVector
			local frame = CFrame.new(ground + Vector3.new(0, a.Height * 0.5, 0)) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
			local fx, fz = a.Footprint.X, a.Footprint.Y
			local t = a.Clock
			for _, o in a.Orbiters do
				local angle = o.Phase + t * o.Speed
				local offset = Vector3.new(math.cos(angle) * fx, math.sin(t * 1.7 + o.Wobble) * 0.15 * a.Height, math.sin(angle) * fz)
				table.insert(moveParts, o.Part)
				table.insert(moveCFrames, CFrame.new(frame * o.Tilt:VectorToWorldSpace(offset)))
			end
			if a.OrbitState == 0 then
				a.OrbitState = 1
			elseif a.OrbitState == 1 then
				showOrbiters(a, true)
			end
		elseif a.OrbitState ~= 0 then
			showOrbiters(a, false)
		end
	end
end

-- Contours et lumières : prêtés aux auras les plus proches (les plus rares d'abord)
local function assignPools()
	local wantOutline: { Handle } = {}
	local wantLight: { Handle } = {}
	for _, a in auras do
		if a.Dead or a.Viewport or a.Lod > 1 then
			continue
		end
		if a.Tier.Outline and a.Dist < OUTLINE_DIST * a.Size then
			table.insert(wantOutline, a)
		end
		if a.Lit and a.Dist < LIGHT_DIST * a.Size then
			table.insert(wantLight, a)
		end
	end
	local function better(x: Handle, y: Handle): boolean
		if x.Rank ~= y.Rank then
			return x.Rank > y.Rank
		end
		return x.Dist < y.Dist
	end
	table.sort(wantOutline, better)
	table.sort(wantLight, better)
	local keepOutline: { [Handle]: boolean } = {}
	for i = 1, math.min(MAX_OUTLINES, #wantOutline) do
		keepOutline[wantOutline[i]] = true
	end
	local keepLight: { [Handle]: boolean } = {}
	for i = 1, math.min(MAX_LIGHTS, #wantLight) do
		keepLight[wantLight[i]] = true
	end
	-- rend d'abord ce qui n'est plus gardé (sorti du dossier de l'aura : il ne doit pas partir avec lui)
	for _, a in auras do
		local outline = a.Outline
		if outline and not keepOutline[a] then
			outline.Enabled = false
			outline.Adornee = nil
			outline.Parent = nil
			table.insert(outlines, outline)
			a.Outline = nil
		end
		local light = a.Light
		if light and not keepLight[a] then
			light.Enabled = false
			light.Parent = nil
			table.insert(lights, light)
			a.Light = nil
		end
	end
	for a in keepOutline do
		if not a.Outline then
			local h = table.remove(outlines) or Instance.new("Highlight")
			h.Name = "AuraOutline"
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.FillColor = a.Colors.Main
			h.FillTransparency = if a.Rank >= 6 then 0.84 else 0.9
			h.OutlineColor = a.Colors.Light
			h.OutlineTransparency = 0.2
			h.Adornee = a.Body
			h.Parent = a.Folder
			h.Enabled = true
			a.Outline = h
		end
	end
	for a in keepLight do
		if not a.Light then
			local l = table.remove(lights) or Instance.new("PointLight")
			l.Name = "AuraLight"
			l.Color = a.Colors.Main
			l.Brightness = a.Tier.Light
			l.Range = math.clamp(a.Radius * 1.9, 6, 24)
			l.Shadows = false
			l.Parent = a.Core
			l.Enabled = true
			a.Light = l
		end
	end
	-- arc-en-ciel : le contour change de couleur
	for _, a in auras do
		local outline = a.Outline
		if outline and a.Tier.Rainbow then
			outline.FillColor = hue(a.Clock * 0.15)
			outline.OutlineColor = hue(a.Clock * 0.15 + 0.5):Lerp(WHITE, 0.3)
		end
	end
end

-- Déplace d'un coup les pièces notées par stepAura (une par une si BulkMoveTo refuse)
local function flush()
	if #moveParts > 0 then
		local ok = pcall(function()
			workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			for k, p in moveParts do
				p.CFrame = moveCFrames[k]
			end
		end
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
end

local function update(dt: number)
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local i = 1
	while i <= #auras do
		local a = auras[i]
		if a.Dead or not a.Folder.Parent then
			-- modèle détruit : l'aura part avec lui
			Aura.Detach(a)
			if auras[i] == a then
				table.remove(auras, i)
			end
			continue
		end
		-- (modèle sorti du jeu sans être détruit : l'aura attend son retour)
		if a.Viewport or a.Folder:IsDescendantOf(workspace) then
			stepAura(a, dt, camPos, cam)
		end
		i += 1
	end
	flush()
	poolClock += dt
	if poolClock >= 0.25 then
		poolClock = 0
		assignPools()
	end
end

local function start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(update)
end

-- ====================================================================== API

-- Rareté connue (Common ... Secret)
function Aura.Has(rarity: string): boolean
	return TIERS[rarity] ~= nil
end

-- Rang d'une rareté (1 Common ... 7 Secret, 0 inconnue)
function Aura.Rank(rarity: string): number
	local tier = TIERS[rarity]
	return if tier then tier.Rank else 0
end

-- Pose une aura sur `model`. nil si la rareté est inconnue ou si rien ne permet de la placer.
function Aura.Attach(model: Instance, options: Options): Handle?
	local tier = TIERS[options.Rarity]
	if not tier then
		return nil
	end
	local root = options.Root
	local pivot = options.Pivot
	if not pivot then
		if not root then
			return nil
		end
		local followed: BasePart = root
		pivot = function(): CFrame
			return followed.CFrame
		end
	end
	-- (math.max(0.5, NaN) vaut 0.5 : une taille absurde reste bornée)
	local radius = math.clamp(math.max(0.5, options.Radius), 0.5, 80)
	local height = math.clamp(math.max(0.5, options.Height), 0.5, 200)
	local sizeFactor = math.clamp(radius / 6, 0.5, 3)
	local clock = math.random() * 10
	local footprint = options.Footprint or Vector2.new(0.85 * radius, 0.85 * radius)
	local folder = Instance.new("Folder")
	folder.Name = "Aura"
	local viewport = options.Viewport == true
	local a: Handle = {
		Model = model,
		Rarity = options.Rarity,
		Rank = tier.Rank,
		Tier = tier,
		Colors = palette(options.Rarity),
		Radius = radius,
		Height = height,
		Range = tier.Range * math.clamp(0.75 + radius / 24, 0.85, 1.6),
		Size = math.clamp(0.6 + 0.4 * sizeFactor, 0.8, 1.8),
		Pivot = pivot :: () -> CFrame,
		Top = options.Top,
		Footprint = footprint,
		Body = options.Body or model,
		Folder = folder,
		Viewport = viewport,
		Ground = options.Ground ~= false,
		Intensity = math.clamp(options.Intensity or 1, 0, 1),
		Lit = tier.Light > 0 and options.Light ~= false,
		Layers = {},
		Sigil = nil,
		ShockRing = nil,
		ShockStroke = nil,
		ShockT = 2,
		NextShock = clock + 0.5 + math.random() * tier.Shock,
		Core = newPart("Core", Vector3.new(2 * radius, 0.2, 2 * radius), folder),
		Center = Instance.new("Attachment"),
		Emitters = {},
		Rates = {},
		Motes = nil,
		Shock = nil,
		Halos = {},
		HeadPos = nil,
		PillarRoot = nil,
		Orbiters = {},
		OrbitState = 0,
		Veil = nil,
		VeilSize = options.VeilSize or Vector3.new(0.8 * footprint.X, height, 0.8 * footprint.Y),
		Veils = {},
		VeilAt = nil,
		VeilYaw = 0,
		Beams = {},
		Ring = {},
		Lod = -1,
		OnScreen = true,
		Dist = 0,
		Clock = clock,
		Moved = nil,
		Outline = nil,
		Light = nil,
		Dead = false,
	}
	a.Center.Name = "Center"
	a.Center.Parent = a.Core
	if viewport then
		if a.Ground then
			buildRing(a)
		end
	else
		if a.Ground then
			buildSigil(a)
		end
		buildParticles(a)
		local halos = if options.Top then (options.Halos or tier.Halos) else 0
		if halos > 0 then
			buildHalos(a, halos)
		end
		local orbiters = math.floor(tier.Orbiters * a.Intensity + 0.5)
		if orbiters > 0 then
			buildOrbiters(a, orbiters)
		end
		if tier.Veil > 0 and options.Veil ~= false then
			buildVeil(a, tier.Veil)
		end
		local pillar = if options.Pillar == nil then tier.Pillar else options.Pillar
		if pillar then
			local top = a.Halos[#a.Halos]
			if top then
				local pillarRoot = newPart("PillarRoot", Vector3.new(0.2, 0.2, 0.2), folder)
				a.PillarRoot = pillarRoot
				buildPillar(a, pillarRoot, top.Radius * 0.55)
			else
				buildPillar(a, a.Core, math.clamp(radius * 0.45, 0.8, 4))
			end
		end
	end
	-- tout est à sa place avant d'entrer dans le jeu (rien ne passe une image à l'origine)
	local cam = workspace.CurrentCamera
	stepAura(a, 0, if cam then cam.CFrame.Position else Vector3.zero, cam)
	flush()
	folder.Parent = options.Parent or model
	table.insert(auras, a)
	start()
	return a
end

-- Enlève l'aura (pièces, particules, contour et lumière prêtés)
function Aura.Detach(a: Handle)
	if a.Dead then
		return
	end
	a.Dead = true
	local index = table.find(auras, a)
	if index then
		table.remove(auras, index)
	end
	local outline = a.Outline
	if outline then
		outline.Enabled = false
		outline.Adornee = nil
		outline.Parent = nil
		table.insert(outlines, outline)
		a.Outline = nil
	end
	local light = a.Light
	if light then
		light.Enabled = false
		light.Parent = nil
		table.insert(lights, light)
		a.Light = nil
	end
	a.Folder:Destroy()
end

-- Onde de choc et gerbe d'étincelles (réanimation, fusion, bloc posé dans une cuve...)
function Aura.Pulse(a: Handle)
	if a.Dead then
		return
	end
	startShock(a)
	local motes = a.Motes
	if motes and a.Lod <= 1 then
		motes:Emit(math.floor(10 + 3 * a.Rank))
	end
end

-- Nombre d'auras actives (tests)
function Aura.Count(): number
	return #auras
end

-- Rareté -> ce qu'elle montre (lecture seule : tests et réglages)
Aura.Tiers = TIERS

return Aura
