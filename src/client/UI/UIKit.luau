--!strict
-- Boîte à outils d'interface (base reprise du UIKit de Steal a Snack, brief 1 ; le brief 12 « ui-ux » la complète).
-- Style « studs » des jeux du moment : tout est carré et couvert de plots. Panneaux gris foncé à plots cernés de noir
-- avec une barre de titre à plots de la couleur du menu, cartes vives à plots en dégradé, boutons à plots avec une
-- lèvre sombre en bas, texte Fredoka One blanc cerné de noir. Animations : survol x1.05, appui x0.95, panneau qui
-- s'ouvre de 90 % à 100 % sur un fond assombri. Pas d'emoji dans les textes. Textes en anglais.
-- Les plots viennent d'une seule texture grise teintée par un UIGradient (un dégradé sur une image multiplie ses couleurs).
--
-- Mise à l'échelle : UIKit.Root(nom) donne un ScreenGui et un cadre « Root » dessiné pour un écran de 1280 x 720 unités,
-- agrandi ou réduit d'un bloc selon l'écran réel. Tout ce qui est dans Root se place en unités de ce cadre.
-- Sons : UIKit.Sound(nom) ne fait rien tant que le brief 16 ne l'a pas remplacé (Hover, Click, Open, Close, Notify).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Shared.Signal)

local UIKit = {}

local C = Color3.fromRGB
local INK = C(14, 12, 24) -- noir profond des contours
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SLATE = C(54, 56, 66) -- gris foncé des panneaux et des cases neutres

UIKit.Colors = {
	Ink = INK,
	Slate = SLATE,
	SlateDark = C(36, 38, 46),
	SlateLight = C(74, 77, 90),
	Text = WHITE,
	Muted = C(222, 222, 232),
	Disabled = C(132, 134, 146),
	Green = C(92, 214, 48), -- boutons d'achat, succès
	GreenText = C(142, 229, 122), -- texte vert clair (gains, $/s, « NEW »)
	Tomato = C(240, 56, 72), -- erreur, croix de fermeture
	Yellow = C(255, 222, 40), -- titres de section
	Orange = C(255, 142, 32),
	Blue = C(52, 142, 255),
	Purple = C(164, 84, 255),
	Cyan = C(40, 214, 244),
	Pink = C(255, 70, 160),
	Robux = C(145, 80, 232),
	Money = C(92, 203, 63),
}
local Colors = UIKit.Colors

-- Couleurs des raretés du GDD (gris, vert, bleu, violet, orange, rouge, arc-en-ciel). Fill = case, Tag = texte.
UIKit.Rarity = {
	Common = { Fill = C(158, 160, 168), Tag = C(220, 222, 228) },
	Uncommon = { Fill = C(76, 200, 72), Tag = C(150, 236, 140) },
	Rare = { Fill = C(52, 132, 240), Tag = C(130, 186, 255) },
	Epic = { Fill = C(156, 76, 232), Tag = C(204, 160, 255) },
	Legendary = { Fill = C(255, 152, 24), Tag = C(255, 204, 110) },
	Mythic = { Fill = C(232, 44, 52), Tag = C(255, 132, 132) },
	Secret = { Fill = C(46, 42, 51), Tag = WHITE, Rainbow = true },
} :: { [string]: { Fill: Color3, Tag: Color3, Rainbow: boolean? } }

-- Plots ronds (une tuile = un plot gris clair, téléversée pour les menus à plots des jeux de Snaky). "" = aplat sans plots.
UIKit.StudTexture = "rbxassetid://79812142862554"
UIKit.StudSize = 26 -- taille d'un plot des panneaux (unités) ; cartes et boutons : 20

-- Pack d'icônes de Steal a Snack (Free Icon Pack 3.0.1 et icônes du jeu, déjà téléversées sur le compte de Snaky).
-- UIKit.icon(nom, props) les pose avec une ombre nette.
UIKit.Icons = {
	shop = "rbxassetid://97493315422791",
	book = "rbxassetid://138787751104353",
	wheel = "rbxassetid://138297996642417",
	coins = "rbxassetid://126698472806052",
	muscle = "rbxassetid://87652362787600",
	gift = "rbxassetid://117729978447512",
	paw = "rbxassetid://116617031858872",
	star = "rbxassetid://94000396318036",
	upgrade = "rbxassetid://122983677793091",
	bag = "rbxassetid://117734677962483",
	cart = "rbxassetid://138393172367188",
	chest = "rbxassetid://79070392212018",
	crown = "rbxassetid://120098129570043",
	trophy = "rbxassetid://114620958791367",
	egg = "rbxassetid://75929189166185",
	egg_gold = "rbxassetid://81132328909441",
	clock = "rbxassetid://117669978258159",
	hammer = "rbxassetid://97308359332508",
	magnet = "rbxassetid://79367111690008",
	shield = "rbxassetid://90984276027454",
	speed = "rbxassetid://111749047569690",
	lock = "rbxassetid://95395220609866",
	crate = "rbxassetid://135476803643444",
	key = "rbxassetid://101279989333529",
	calendar = "rbxassetid://132670079602648",
	coin = "rbxassetid://118808117081323",
	gem = "rbxassetid://86611632937531",
	ticket = "rbxassetid://93392430331107",
	check = "rbxassetid://81028595063433",
	plus = "rbxassetid://126668120643038",
	info = "rbxassetid://116086284335525",
} :: { [string]: string }

-- Rayons blancs (Essential UI Pack, téléversé pour Steal a Snack) derrière les images des cartes
UIKit.Sunburst = "rbxassetid://101335357428300"

UIKit.TitleFont = Font.fromEnum(Enum.Font.FredokaOne)
UIKit.LabelFont = UIKit.TitleFont
UIKit.BodyFont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

UIKit.DesignSize = Vector2.new(1280, 720) -- taille du cadre Root, en unités

-- Écran tactile sans clavier (téléphone, tablette). Studio : attribut StudioTouch de ReplicatedStorage pour tester.
UIKit.Touch = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	or (RunService:IsStudio() and ReplicatedStorage:GetAttribute("StudioTouch") == true)

-- Sons de l'interface : remplacé par le brief 16 (UIKit.Sound = function(name) ... end)
UIKit.Sound = function(_name: string) end

local function playSound(name: string)
	local ok, err = pcall(UIKit.Sound :: any, name)
	if not ok then
		warn("[UIKit] son " .. name .. " : " .. tostring(err))
	end
end

-- ===== Base =====

-- Crée une instance : UIKit.new("Frame", { Size = ..., Parent = ... }, { enfants }). Parent est posé en dernier.
function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	local propTable: { [string]: any } = props or {}
	local childList: { Instance } = children or {}
	for key, value in propTable do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in childList do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UIKit.new

-- Coins presque droits (le style est carré) ; un grand rayon (40 et plus) reste rond (pastilles)
function UIKit.corner(radius: number?): UICorner
	local r = radius or 10
	return new("UICorner", { CornerRadius = UDim.new(0, if r >= 40 then r else math.min(r, 3)) })
end

function UIKit.stroke(color: Color3?, thickness: number?): UIStroke
	return new("UIStroke", {
		Color = color or INK,
		Thickness = (thickness or 3) + 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.gradient(color0: Color3, color1: Color3, rotation: number?): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(color0, color1), Rotation = rotation or 90 })
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, amount)
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(BLACK, amount)
end
UIKit.Lighten = lighten
UIKit.Darken = darken

-- Couleur neutre (sombre ou grise) : case gris foncé à plots ; couleur vive : carte en dégradé
local function isNeutral(color: Color3): boolean
	local _, saturation, value = color:ToHSV()
	return saturation < 0.2 or value < 0.3
end
UIKit.IsNeutral = isNeutral

-- Dégradé d'une case vive : couleur pleine sur les bords, claire au milieu
local function cardSequence(c: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c),
		ColorSequenceKeypoint.new(0.5, lighten(c, 0.38)),
		ColorSequenceKeypoint.new(1, c),
	})
end
UIKit.CardSequence = cardSequence

-- Dégradé d'un bouton : clair en haut, couleur pleine en bas
local function buttonSequence(c: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, lighten(c, 0.32)),
		ColorSequenceKeypoint.new(0.55, c),
		ColorSequenceKeypoint.new(1, darken(c, 0.08)),
	})
end
UIKit.ButtonSequence = buttonSequence

local SLATE_SEQUENCE = ColorSequence.new(lighten(SLATE, 0.1), darken(SLATE, 0.12))
UIKit.SlateSequence = SLATE_SEQUENCE

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(255, 80, 110)),
	ColorSequenceKeypoint.new(0.2, C(255, 196, 50)),
	ColorSequenceKeypoint.new(0.4, C(120, 235, 80)),
	ColorSequenceKeypoint.new(0.6, C(60, 210, 250)),
	ColorSequenceKeypoint.new(0.8, C(170, 100, 255)),
	ColorSequenceKeypoint.new(1, C(255, 100, 200)),
})
UIKit.RainbowSequence = RAINBOW

-- ===== Animation =====

UIKit.Motion = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Bouncy = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
}

-- Un tween en cours sur la même propriété du même élément est annulé avant d'en lancer un nouveau
local liveTweens: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function UIKit.tween(inst: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local live = liveTweens[inst]
	if not live then
		live = {}
		liveTweens[inst] = live
	end
	for key in props do
		local previous = live[key]
		if previous and previous.PlaybackState == Enum.PlaybackState.Playing then
			previous:Cancel()
		end
	end
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(inst, info, props)
	for key in props do
		live[key] = tween
	end
	tween:Play()
	return tween
end

-- ===== Plots =====

-- Couche de plots en mosaïque dans `parent` (un plot = `stud` unités). La texture est gris clair : sa couleur vient du
-- UIGradient « Tint » (`sequence`, `rotation`). Sans texture (StudTexture = ""), un aplat du même dégradé.
function UIKit.studLayer(parent: GuiObject, stud: number?, sequence: ColorSequence?, rotation: number?): ImageLabel
	local px = stud or UIKit.StudSize
	local flat = UIKit.StudTexture == ""
	local layer = new("ImageLabel", {
		Name = "Studs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = if flat then 0 else 1,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Image = UIKit.StudTexture,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(px, px),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	new("UIGradient", { Name = "Tint", Rotation = rotation or 90, Color = sequence or SLATE_SEQUENCE, Parent = layer })
	return layer
end

-- ===== Texte =====

-- Taille de texte maximale en unités d'interface : un UITextSizeConstraint compte en pixels de l'écran, sans le UIScale
-- de UIKit.Root ; il est donc remis à l'échelle à chaque changement de taille de l'écran (sinon le texte reste petit
-- sur un grand écran ; jamais réduit sur un petit écran, où le texte suit déjà sa case).
UIKit.Scale = 1
-- (table forte : une table faible perdrait les entrées dont le proxy Lua est ramassé alors que l'instance vit encore)
local sizeLimits: { [UITextSizeConstraint]: number } = {}

function UIKit.sizeLimit(label: TextLabel, maxSize: number): UITextSizeConstraint
	local constraint: UITextSizeConstraint = new("UITextSizeConstraint", {
		MaxTextSize = math.floor(maxSize * math.max(1, UIKit.Scale)),
		Parent = label,
	})
	sizeLimits[constraint] = maxSize
	constraint.Destroying:Connect(function()
		sizeLimits[constraint] = nil
	end)
	return constraint
end

local function setScale(scale: number)
	if math.abs(scale - UIKit.Scale) < 0.001 then
		return
	end
	UIKit.Scale = scale
	for constraint, maxSize in sizeLimits do
		constraint.MaxTextSize = math.floor(maxSize * math.max(1, scale))
	end
end

-- Texte du kit : Fredoka One blanc cerné de noir. Options en plus des propriétés de TextLabel :
-- Body = true (texte courant Builder Sans, sans contour), StrokeThickness (0 = sans contour), MaxTextSize.
function UIKit.label(props: { [string]: any }): TextLabel
	local body = props.Body
	local strokeThickness = props.StrokeThickness
	local maxSize = props.MaxTextSize
	props.Body = nil
	props.StrokeThickness = nil
	props.MaxTextSize = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	if props.FontFace == nil then
		props.FontFace = if body then UIKit.BodyFont else UIKit.LabelFont
	end
	props.TextColor3 = props.TextColor3 or Colors.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	if maxSize == nil and body then
		maxSize = 20
	end
	local label = new("TextLabel", props)
	if maxSize and label.TextScaled then
		UIKit.sizeLimit(label, maxSize)
	end
	new("UIStroke", {
		Thickness = math.min(if strokeThickness == nil then (if body then 0 else 3) else strokeThickness, 3),
		Color = INK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = label,
	})
	return label
end

-- ===== Cases =====

-- Face d'un élément : carré à plots cerné de noir. Couleur vive : plots en dégradé de la couleur (clair au milieu) avec
-- un liseré intérieur plus sombre ; couleur neutre : plots gris foncé. Changer l'attribut « Tint » de la face la
-- repeint ; l'attribut « Rainbow » la peint aux couleurs de l'arc-en-ciel (Secret).
function UIKit.makeFace(outer: GuiObject, color: Color3, thickness: number?, strokeColor: Color3?): Frame
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = outer.ZIndex,
		Parent = outer,
	})
	new("UIStroke", { Name = "Stroke", Color = strokeColor or INK, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = face })
	local studs = UIKit.studLayer(face, 20)
	local gradient = studs:FindFirstChild("Tint") :: UIGradient
	local bevel = new("Frame", {
		Name = "Bevel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = face.ZIndex + 1,
		Parent = face,
	})
	local bevelStroke: UIStroke = new("UIStroke", { Thickness = 2.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bevel })
	local function paint()
		local tint = face:GetAttribute("Tint")
		local c = if typeof(tint) == "Color3" then tint else color
		if face:GetAttribute("Rainbow") then
			gradient.Rotation = 20
			gradient.Color = RAINBOW
			bevelStroke.Color = WHITE
			bevelStroke.Transparency = 0.55
		elseif isNeutral(c) then
			gradient.Rotation = 90
			gradient.Color = SLATE_SEQUENCE
			bevelStroke.Color = lighten(SLATE, 0.12)
			bevelStroke.Transparency = 0.35
		else
			gradient.Rotation = 35
			gradient.Color = cardSequence(c)
			bevelStroke.Color = darken(c, 0.35)
			bevelStroke.Transparency = 0.15
		end
	end
	face:SetAttribute("Tint", color)
	paint()
	face:GetAttributeChangedSignal("Tint"):Connect(paint)
	face:GetAttributeChangedSignal("Rainbow"):Connect(paint)
	return face
end

-- Carte à plots : props.Color = couleur (vive : dégradé, neutre : gris foncé), props.Accent = couleur du contour,
-- props.Rainbow = carte arc-en-ciel. Les autres props sont celles du cadre. La face est dans card.Face.
function UIKit.card(props: { [string]: any }): Frame
	local color = props.Color or SLATE
	local accent = props.Accent
	local rainbow = props.Rainbow
	local parent = props.Parent
	props.Color = nil
	props.Accent = nil
	props.Rainbow = nil
	props.Parent = nil
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	local outer = new("Frame", props)
	local face = UIKit.makeFace(outer, color, if accent then 4 else 3, accent)
	if rainbow then
		face:SetAttribute("Rainbow", true)
	end
	outer.Parent = parent
	return outer
end

-- ===== Icônes =====

-- Icône du pack (UIKit.Icons[nom]) avec une ombre nette décalée en bas à droite. props = propriétés du cadre (Size,
-- Position, AnchorPoint, ZIndex...). L'image est dans icon.Image (ImageLabel « Image »). Nom inconnu : cadre vide.
function UIKit.icon(name: string, props: { [string]: any }): Frame
	local parent = props.Parent
	props.Parent = nil
	props.Name = props.Name or "Icon"
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	local holder: Frame = new("Frame", props)
	local image = UIKit.Icons[name] or ""
	local z = holder.ZIndex
	new("ImageLabel", {
		Name = "Shadow",
		Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = BLACK,
		ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z,
		Parent = holder,
	})
	new("ImageLabel", {
		Name = "Image",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z + 1,
		Parent = holder,
	})
	holder.Parent = parent
	return holder
end

-- Logo Robux dessiné (hexagone arrondi évidé et carré plein), blanc cerné de noir, dans un carré de `size` unités
function UIKit.robuxGlyph(props: { [string]: any }): Frame
	local parent = props.Parent
	props.Parent = nil
	props.Name = props.Name or "Robux"
	props.BackgroundTransparency = 1
	local holder: Frame = new("Frame", props)
	local z = holder.ZIndex
	local size = holder.Size.Y.Offset
	local ring: Frame = new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = holder,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
		new("UIStroke", { Color = WHITE, Thickness = math.max(2, size * 0.14), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	-- (contour noir autour de l'anneau blanc)
	new("Frame", {
		Name = "Outline",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, size * 0.3, 1, size * 0.3),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = ring,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.34, 0) }),
		new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	new("Frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = holder,
	}, { new("UIStroke", { Color = INK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	holder.Parent = parent
	return holder
end

-- Titre de section « -- FEATURED -- » (comme Steal an Egg) : texte en dégradé de `props.Color` (jaune par défaut),
-- centré sur `props.Width`
function UIKit.sectionTitle(props: { [string]: any }): Frame
	local title = props.Text or ""
	local width = props.Width or 600
	local color: Color3 = props.Color or Colors.Yellow
	props.Text = nil
	props.Width = nil
	props.Color = nil
	props.BackgroundTransparency = 1
	props.Size = props.Size or UDim2.fromOffset(width, 48)
	local parent = props.Parent
	props.Parent = nil
	local frame: Frame = new("Frame", props)
	local label = UIKit.label({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -6),
		Text = "-- " .. title .. " --",
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(lighten(color, 0.45), color),
		Parent = label,
	})
	frame.Parent = parent
	return frame
end

-- Effet de verre sur une carte ou un bouton : reflet clair sur la moitié haute, fin liseré blanc en haut, et une bande
-- de lumière en diagonale qui traverse l'élément quand on appelle la fonction renvoyée (durée en secondes).
-- `z` = ZIndex du reflet (au-dessus des plots, sous le contenu) ; la bande passe au-dessus de tout (z + 6).
function UIKit.glass(frame: GuiObject, z: number?): (duration: number?) -> ()
	local base = z or frame.ZIndex + 1
	new("Frame", {
		Name = "Glass",
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = base,
		Parent = frame,
	}, {
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.7, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	new("Frame", {
		Name = "GlassRim",
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 0, 3),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = base,
		Parent = frame,
	})
	local clip: Frame = new("Frame", {
		Name = "ShineClip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = base + 6,
		Parent = frame,
	})
	local bar: Frame = new("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.5, 0.5),
		Size = UDim2.fromScale(0.28, 3),
		Rotation = 25,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = base + 6,
		Parent = clip,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	return function(duration: number?)
		if not bar.Parent then
			return
		end
		bar.Position = UDim2.fromScale(-0.5, 0.5)
		UIKit.tween(bar, duration or 0.75, { Position = UDim2.fromScale(1.5, 0.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
end

-- ===== Boutons =====

-- Retour des boutons : x1.05 au survol (pas sur écran tactile), x0.95 à l'appui
function UIKit.packHover(button: GuiButton, scaleTarget: Instance?)
	local target = scaleTarget or button
	local existing = target:FindFirstChild("HoverScale")
	local scale: UIScale = if existing and existing:IsA("UIScale") then existing else new("UIScale", { Name = "HoverScale", Parent = target })
	local hovering = false
	local function hoverScale(): number
		local value = button:GetAttribute("HoverScale")
		return if type(value) == "number" then value else 1.05
	end
	button.MouseEnter:Connect(function()
		if UIKit.Touch or button:GetAttribute("Disabled") then
			return
		end
		hovering = true
		UIKit.tween(scale, 0.15, { Scale = hoverScale() })
		playSound("Hover")
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		UIKit.tween(scale, 0.15, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.08, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = if hovering then hoverScale() else 1 }, Enum.EasingStyle.Back)
	end)
end

-- Face d'un bouton : plots en dégradé (clair en haut), lèvre sombre en bas, fin reflet, contour noir.
-- Renvoie la face et une fonction (couleur, arc-en-ciel) pour la repeindre.
local function buttonFace(button: GuiObject): (Frame, (Color3, boolean?) -> ())
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex,
		Parent = button,
	})
	new("UIStroke", { Name = "Stroke", Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = face })
	local studs = UIKit.studLayer(face, 18)
	local gradient = studs:FindFirstChild("Tint") :: UIGradient
	new("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.16),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 1,
		Parent = face,
	})
	new("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.new(1, -10, 0, 3),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 1,
		Parent = face,
	})
	return face, function(c: Color3, rainbow: boolean?)
		if rainbow then
			gradient.Rotation = 0
			gradient.Color = RAINBOW
		elseif isNeutral(c) and c ~= Colors.Disabled then
			gradient.Rotation = 90
			gradient.Color = SLATE_SEQUENCE
		else
			gradient.Rotation = 90
			gradient.Color = buttonSequence(c)
		end
	end
end
UIKit.buttonFace = buttonFace

-- Bouton à plots : props.Color = couleur (Colors.Green pour acheter), props.Text, props.Rainbow, props.MaxTextSize.
-- Les autres props sont celles du TextButton. Changer button.Text met à jour le texte ; l'attribut « Disabled » le grise
-- (le clic reste possible pour que le serveur explique pourquoi) ; l'attribut « Tint » (Color3) le repeint (onglets).
function UIKit.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color: Color3 = props.Color or Colors.Disabled
	local text = props.Text or ""
	local rainbow = props.Rainbow
	local maxTextSize = props.MaxTextSize
	local parent = props.Parent
	props.Color = nil
	props.Text = nil
	props.Rainbow = nil
	props.MaxTextSize = nil
	props.Parent = nil
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	local button: TextButton = new("TextButton", props)
	button.Text = text
	button.TextTransparency = 1
	local face, paint = buttonFace(button)
	paint(color, rainbow)
	local label = UIKit.label({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.88, 0.62),
		Text = text,
		MaxTextSize = maxTextSize or 40,
		ZIndex = button.ZIndex + 2,
		Parent = face,
	})
	-- Prix Robux : un texte « R$ 99 » s'affiche « [logo Robux] 99 » (button.Text garde « R$ 99 »)
	local height = if button.Size.Y.Offset > 0 then button.Size.Y.Offset else 56
	local price: Frame = new("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.92, 0.62),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = button.ZIndex + 2,
		Parent = face,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, math.floor(height * 0.1)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local glyphSize = math.floor(math.min(height * 0.56, 36))
	UIKit.robuxGlyph({ LayoutOrder = 1, Size = UDim2.fromOffset(glyphSize, glyphSize), ZIndex = button.ZIndex + 2, Parent = price })
	local amount = UIKit.label({
		Name = "Amount",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextScaled = false,
		TextSize = math.floor(math.min(height * 0.56, (maxTextSize or 40))),
		Text = "",
		ZIndex = button.ZIndex + 2,
		Parent = price,
	})
	local function showText()
		local value = string.match(button.Text, "^R%$%s*(.+)$")
		price.Visible = value ~= nil
		label.Visible = value == nil
		amount.Text = value or ""
		label.Text = button.Text
	end
	showText()
	button:GetPropertyChangedSignal("Text"):Connect(showText)
	local function repaint()
		local off = button:GetAttribute("Disabled") == true
		label.TextTransparency = if off then 0.35 else 0
		amount.TextTransparency = label.TextTransparency
		paint(if off then Colors.Disabled else color, rainbow and not off)
	end
	button:GetAttributeChangedSignal("Disabled"):Connect(repaint)
	button:GetAttributeChangedSignal("Tint"):Connect(function()
		local tint = button:GetAttribute("Tint")
		if typeof(tint) == "Color3" then
			color = tint
			repaint()
		end
	end)
	UIKit.packHover(button)
	button.Activated:Connect(function()
		playSound("Click")
		if onClick then
			onClick()
		end
	end)
	button.Parent = parent
	return button
end

-- Croix rouge carrée
function UIKit.closeButton(props: { [string]: any }, onClick: () -> ()): TextButton
	props.BackgroundTransparency = 1
	props.Text = ""
	props.AutoButtonColor = false
	local parent = props.Parent
	props.Parent = nil
	local button: TextButton = new("TextButton", props)
	local _, paint = buttonFace(button)
	paint(Colors.Tomato)
	UIKit.label({
		Name = "X",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = "X",
		ZIndex = button.ZIndex + 2,
		Parent = button,
	})
	button:SetAttribute("HoverScale", 1.08)
	UIKit.packHover(button)
	button.Activated:Connect(function()
		playSound("Click")
		onClick()
	end)
	button.Parent = parent
	return button
end

-- Bouton de la colonne du HUD (comme Shop / Index de Steal an Egg) : bouton large à plots de la couleur `props.Color`,
-- grande icône du pack (`props.Icon`) à gauche, nom à droite. Les autres props sont celles du TextButton.
function UIKit.menuButton(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color: Color3 = props.Color or Colors.Green
	local iconName: string = props.Icon or ""
	local text: string = props.Text or ""
	local parent = props.Parent
	props.Color = nil
	props.Icon = nil
	props.Text = nil
	props.Parent = nil
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	local button: TextButton = new("TextButton", props)
	button.Text = ""
	local _, paint = buttonFace(button)
	paint(color)
	local height = if button.Size.Y.Offset > 0 then button.Size.Y.Offset else 64
	-- (icône qui déborde un peu à gauche, nom à droite)
	UIKit.icon(iconName, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -4, 0.5, -2),
		Size = UDim2.fromOffset(height * 1.05, height * 1.05),
		ZIndex = button.ZIndex + 2,
		Parent = button,
	})
	UIKit.label({
		Name = "Label",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, height + 6, 0.47, 0),
		Size = UDim2.new(1, -(height + 14), 0.62, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		MaxTextSize = 34,
		ZIndex = button.ZIndex + 4,
		Parent = button,
	})
	button:SetAttribute("HoverScale", 1.08)
	UIKit.packHover(button)
	button.Activated:Connect(function()
		playSound("Click")
		if onClick then
			onClick()
		end
	end)
	button.Parent = parent
	return button
end

-- ===== Composants =====

-- Barre de progression : rail gris foncé cerné de noir, remplissage à plots, texte au milieu.
-- props.Color = couleur du remplissage. Renvoie la barre et une fonction (fraction 0..1, texte?) pour la mettre à jour.
function UIKit.progressBar(props: { [string]: any }): (Frame, (fraction: number, text: string?) -> ())
	local color = props.Color or Colors.Green
	props.Color = nil
	props.BackgroundColor3 = C(28, 29, 36)
	props.BackgroundTransparency = 0
	props.BorderSizePixel = 0
	local back: Frame = new("Frame", props, {
		new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local fill: Frame = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = back.ZIndex + 1,
		Parent = back,
	})
	UIKit.studLayer(fill, 16, buttonSequence(color), 90)
	local label = UIKit.label({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.78),
		Text = "",
		ZIndex = back.ZIndex + 2,
		Parent = back,
	})
	return back, function(fraction: number, text: string?)
		local f = if fraction == fraction then math.clamp(fraction, 0, 1) else 0
		fill.Visible = f > 0.001
		UIKit.tween(fill, 0.3, { Size = UDim2.fromScale(f, 1) })
		label.Text = text or ""
	end
end

-- Étiquette de rareté : case de la couleur de la rareté, nom en blanc cerné de noir
function UIKit.rarityTag(rarity: string, props: { [string]: any }): Frame
	local colors = UIKit.Rarity[rarity] or UIKit.Rarity.Common
	props.Color = colors.Fill
	props.Rainbow = colors.Rainbow
	local tag = UIKit.card(props)
	UIKit.label({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.72),
		Text = string.upper(rarity),
		ZIndex = tag.ZIndex + 2,
		Parent = tag,
	})
	return tag
end

-- Liste qui défile (verticale) : fond transparent, barre jaune. La taille du contenu suit ses enfants
-- (AutomaticCanvasSize) ; props = propriétés du ScrollingFrame.
function UIKit.scroll(props: { [string]: any }): ScrollingFrame
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 10
	props.ScrollBarImageColor3 = props.ScrollBarImageColor3 or Colors.Yellow
	props.ScrollingDirection = props.ScrollingDirection or Enum.ScrollingDirection.Y
	props.CanvasSize = props.CanvasSize or UDim2.new()
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	props.ElasticBehavior = Enum.ElasticBehavior.Never
	return new("ScrollingFrame", props)
end

export type Tabs = {
	Frame: Frame,
	Buttons: { [string]: TextButton },
	Select: (name: string) -> (),
	Selected: () -> string,
}

-- Rangée d'onglets dans `parent` : entries = { { Name, Text?, Color? } } ; l'onglet choisi prend sa couleur, les autres
-- restent gris. props.Vertical = colonne ; props.ButtonSize (UDim2) ; les autres props sont celles du cadre.
-- onSelect(nom) est appelé à chaque choix (aussi par Select).
function UIKit.tabs(parent: GuiObject, entries: { { Name: string, Text: string?, Color: Color3?, Icon: string? } }, onSelect: (string) -> (), props: { [string]: any }?): Tabs
	local options: { [string]: any } = props or {}
	local vertical = options.Vertical == true
	local buttonSize: UDim2 = options.ButtonSize or UDim2.fromOffset(150, 52)
	local maxText = options.MaxTextSize or 26
	options.Vertical = nil
	options.ButtonSize = nil
	options.MaxTextSize = nil
	options.BackgroundTransparency = 1
	options.Name = options.Name or "Tabs"
	options.Parent = parent
	local frame: Frame = new("Frame", options, {
		new("UIListLayout", {
			FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local buttons: { [string]: TextButton } = {}
	local colors: { [string]: Color3 } = {}
	local selected = ""
	local function choose(name: string)
		if not buttons[name] then
			return
		end
		selected = name
		for key, button in buttons do
			button:SetAttribute("Tint", if key == name then colors[key] else SLATE)
		end
		onSelect(name)
	end
	for order, entry in entries do
		local name = entry.Name
		colors[name] = entry.Color or Colors.Yellow
		buttons[name] = UIKit.button({
			Name = name,
			Text = entry.Text or name,
			Color = SLATE,
			LayoutOrder = order,
			Size = buttonSize,
			MaxTextSize = maxText,
			ZIndex = frame.ZIndex,
			Parent = frame,
		}, function()
			choose(name)
		end)
	end
	return {
		Frame = frame,
		Buttons = buttons,
		Select = choose,
		Selected = function(): string
			return selected
		end,
	}
end

export type Badge = { Frame: Frame, Label: TextLabel, Set: (count: number | string | nil) -> () }

-- Pastille rouge en haut à droite d'un bouton. badge.Set(nombre ou texte) : 0, "" ou nil la cache.
function UIKit.badge(button: GuiObject): Badge
	local frame: Frame = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Colors.Tomato,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = button.ZIndex + 6,
		Parent = button,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local label = UIKit.label({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.7),
		Text = "",
		StrokeThickness = 0,
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})
	return {
		Frame = frame,
		Label = label,
		Set = function(count: number | string | nil)
			local text = if type(count) == "number" then (if count > 99 then "99+" elseif count > 0 then tostring(count) else "") else (count or "")
			frame.Visible = text ~= ""
			label.Text = text
		end,
	}
end

-- ===== Écran =====

-- ScreenGui `name` dans le PlayerGui (créé s'il n'existe pas) et son cadre « Root » de UIKit.DesignSize unités,
-- mis à l'échelle de l'écran. Renvoie (ScreenGui, Root).
function UIKit.Root(name: string, displayOrder: number?): (ScreenGui, Frame)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild(name)
	if gui and gui:IsA("ScreenGui") then
		return gui, gui:WaitForChild("Root") :: Frame
	end
	local screen: ScreenGui = new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
	})
	local root: Frame = new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(UIKit.DesignSize.X, UIKit.DesignSize.Y),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local scale: UIScale = new("UIScale", { Parent = root })
	local function fit()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else UIKit.DesignSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		-- (le cadre couvre tout l'écran : l'axe le plus serré donne l'échelle, l'autre s'allonge)
		local s = math.min(viewport.X / UIKit.DesignSize.X, viewport.Y / UIKit.DesignSize.Y)
		scale.Scale = s
		root.Size = UDim2.fromOffset(viewport.X / s, viewport.Y / s)
		setScale(s)
	end
	fit()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	screen.Parent = playerGui
	return screen, root
end

-- ===== Panneaux =====

export type Panel = {
	Frame: Frame,
	Content: Frame,
	HeaderRight: Frame,
	IsOpen: () -> boolean,
	Open: () -> (),
	Close: () -> (),
	Toggle: () -> (),
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
}

local openPanels: { Panel } = {}
UIKit.HeaderHeight = 76
-- Un menu vient de s'ouvrir (true) ou plus aucun n'est ouvert (false) : le HUD s'efface pendant ce temps
UIKit.PanelsChanged = Signal.new()

function UIKit.AnyPanelOpen(): boolean
	for _, panel in openPanels do
		if panel.IsOpen() then
			return true
		end
	end
	return false
end

-- Panneau à plots dans `root` (le cadre Root de UIKit.Root) : corps gris foncé à plots cerné de noir avec une ombre
-- nette, barre de titre de la couleur `accent`, croix rouge. `size` en unités ; réduit d'un bloc s'il ne tient pas.
-- Contenu dans panel.Content ; panel.HeaderRight reçoit onglets ou infos à droite du titre. Cliquer à côté ferme.
function UIKit.panel(root: GuiObject, title: string, accent: Color3, size: Vector2): Panel
	local headerHeight = UIKit.HeaderHeight
	local backdrop: TextButton = new("TextButton", {
		Name = title .. "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(6, 6, 14),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	local holder: Frame = new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = backdrop,
	})
	local scale: UIScale = new("UIScale", { Parent = holder })
	local function fitScale(): number
		local available = root.AbsoluteSize
		local unit = if root.Size.X.Offset > 0 then available.X / root.Size.X.Offset else 1
		if available.X <= 0 or unit <= 0 then
			return 1
		end
		return math.min(1, (available.X / unit - 24) / size.X, (available.Y / unit - 40) / size.Y)
	end
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = holder,
	})
	local body: Frame = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = SLATE,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = holder,
	}, { new("UIStroke", { Color = INK, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	UIKit.studLayer(body, UIKit.StudSize, ColorSequence.new(C(68, 70, 82), C(46, 48, 58)), 90).ZIndex = 21
	-- (les clics dans le panneau ne le ferment pas)
	new("TextButton", {
		Name = "Blocker",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 21,
		Parent = body,
	})
	local header: Frame = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
		Parent = body,
	})
	local bar = UIKit.studLayer(header, UIKit.StudSize, ColorSequence.new(lighten(accent, 0.3), darken(accent, 0.06)), 90)
	bar.Name = "Bar"
	bar.ZIndex = 22
	header.ClipsDescendants = true
	-- (deux reflets blancs en diagonale, au même angle, comme les menus des Steal a ...)
	for index, spec in { { X = 0.42, W = 46 }, { X = 0.5, W = 18 } } do
		new("Frame", {
			Name = "Gloss" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spec.X, 0.5),
			Size = UDim2.new(0, spec.W, 2.4, 0),
			Rotation = 30,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			ZIndex = 22,
			Parent = header,
		})
	end
	new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ZIndex = 23,
		Parent = header,
	})
	UIKit.label({
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, -1),
		Size = UDim2.fromScale(0.42, 0.64),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UIKit.TitleFont,
		Text = title,
		ZIndex = 24,
		Parent = header,
	})
	local closeSize = math.floor(headerHeight * 0.74)
	local headerRight: Frame = new("Frame", {
		Name = "HeaderRight",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(closeSize + 24), 0.5, -1),
		Size = UDim2.fromScale(0.52, 0.7),
		BackgroundTransparency = 1,
		ZIndex = 24,
		Parent = header,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local content: Frame = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, headerHeight + 12),
		Size = UDim2.new(1, -32, 1, -(headerHeight + 12) - 14),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = body,
	})

	local panel = {} :: Panel
	panel.Frame = body
	panel.Content = content
	panel.HeaderRight = headerRight

	-- (un jeton évite qu'une fermeture en cours cache le panneau qu'on vient de rouvrir)
	local closeToken = 0
	local closing = false

	function panel.IsOpen(): boolean
		return backdrop.Visible and not closing
	end

	function panel.Close()
		if not backdrop.Visible or closing then
			return
		end
		closing = true
		closeToken += 1
		local token = closeToken
		playSound("Close")
		UIKit.tween(scale, 0.15, { Scale = fitScale() * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UIKit.tween(backdrop, 0.15, { BackgroundTransparency = 1 })
		task.delay(0.15, function()
			if token ~= closeToken then
				return
			end
			closing = false
			backdrop.Visible = false
			if panel.OnClose then
				panel.OnClose()
			end
			if not UIKit.AnyPanelOpen() then
				UIKit.PanelsChanged:Fire(false)
			end
		end)
	end

	function panel.Open()
		closeToken += 1
		closing = false
		for _, other in openPanels do
			if other ~= panel and other.IsOpen() then
				other.Close()
			end
		end
		local target = fitScale()
		scale.Scale = target * 0.9
		backdrop.BackgroundTransparency = 1
		backdrop.Visible = true
		UIKit.tween(scale, 0.22, { Scale = target }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		UIKit.tween(backdrop, 0.2, { BackgroundTransparency = 0.6 })
		playSound("Open")
		UIKit.PanelsChanged:Fire(true)
		if panel.OnOpen then
			panel.OnOpen()
		end
	end

	function panel.Toggle()
		if panel.IsOpen() then
			panel.Close()
		else
			panel.Open()
		end
	end

	UIKit.closeButton({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -1),
		Size = UDim2.fromOffset(closeSize, closeSize),
		ZIndex = 25,
		Parent = header,
	}, panel.Close)
	backdrop.Activated:Connect(panel.Close)
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if panel.IsOpen() then
			scale.Scale = fitScale()
		end
	end)

	table.insert(openPanels, panel)
	return panel
end

-- ===== Messages =====

local TOAST_COLORS: { [string]: Color3 } = {
	info = SLATE,
	success = Colors.Green,
	error = Colors.Tomato,
	money = Colors.Money,
}
local MAX_TOASTS = 4
local TOAST_TOP = 70
local toastTop = TOAST_TOP
local toastList: Frame? = nil

local function getToastList(): Frame
	local list = toastList
	if list and list.Parent then
		return list
	end
	local _, root = UIKit.Root("Toasts", 50)
	local created: Frame = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, toastTop),
		Size = UDim2.fromOffset(520, 300),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	toastList = created
	return created
end

local toastOrder = 0

-- Hauteur (unités) où commencent les messages courts : le HUD la baisse quand une carte occupe le haut de l'écran
-- (bandeau de zone, transport d'un bloc). nil : place normale.
function UIKit.SetToastTop(y: number?)
	local top = y or TOAST_TOP
	if top == toastTop then
		return
	end
	toastTop = top
	local list = toastList
	if list and list.Parent then
		UIKit.tween(list, 0.15, { Position = UDim2.new(0.5, 0, 0, top) })
	end
end

-- Message court en haut de l'écran pendant `duration` secondes (3 par défaut). kind : info, success, error, money.
function UIKit.toast(text: string, kind: string?, duration: number?): Frame
	local list = getToastList()
	local toasts = {}
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #toasts - MAX_TOASTS + 1 do
		toasts[index]:Destroy()
	end
	toastOrder += 1
	local toast = UIKit.card({
		Name = "Toast",
		Color = TOAST_COLORS[kind or "info"] or SLATE,
		Size = UDim2.fromOffset(460, 52),
		LayoutOrder = toastOrder,
		Parent = list,
	})
	UIKit.label({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 30),
		Text = text,
		ZIndex = toast.ZIndex + 2,
		Parent = toast,
	})
	local pop: UIScale = new("UIScale", { Scale = 0.6, Parent = toast })
	UIKit.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	playSound("Notify")
	task.delay(duration or 3, function()
		if toast.Parent then
			UIKit.tween(pop, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.16)
			toast:Destroy()
		end
	end)
	return toast
end

return UIKit
