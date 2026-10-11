--!strict
-- HUD du jeu (brief 12 « ui-ux », GDD section UI/UX), pensé pour le téléphone (iPhone 15 en paysage) :
--   * bloc de boutons à gauche : Shop et Index, au-dessus des boutons Daily, Spin, Gifts (RewardsController) ;
--   * compteurs en bas à gauche : argent qui monte en douceur (+ revenu par seconde, gains et dépenses qui s'envolent),
--     vitesse comparée à la vitesse conseillée de la zone (verte : assez rapide, rouge : trop lent), prochaine zone ;
--   * bandeau en haut au milieu en entrant dans une zone de la route (vitesse conseillée, verte ou rouge) ;
--   * pendant le transport d'un bloc : carte en haut au milieu (rareté du bloc, flèche et distance vers son parc,
--     distance du gardien qui poursuit) et rayon de la couleur du bloc vers l'entrée du parc ;
--   * cuves à droite : minuteur de chaque cuve, bouton Open quand le dino est prêt, blocs en attente, cuve suivante.
-- Tout s'efface quand un menu est ouvert (UIKit.PanelsChanged), sauf les boutons (sous le fond sombre du menu).
-- Le client ne décide rien : il lit les clés replica (Money, Income, Speed, Carrying, Plot, Tanks, TankCount, Stored,
-- Trails, Tutorial) et les attributs du joueur (Zone, ChasedBy), et demande au serveur (RevealTank, BuyTank).
-- API : HudController.SetVisible(bool) (cinématiques), HudController.Heading(depuis, vers, caméra) -> degrés (tests).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local IndexController = require(script.Parent.IndexController)
local NotifyController = require(script.Parent.NotifyController)
local ReplicaController = require(script.Parent.ReplicaController)
local ShopController = require(script.Parent.ShopController)
local TutorialController = require(script.Parent.TutorialController)

local HudController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local ZONES = Config.Zones.List
local ECONOMY = Config.Economy

-- Bloc de boutons à gauche : même taille que ceux de RewardsController (136 x 68, écart 14), juste au-dessus d'eux.
-- RewardsController centre les siens 82 unités sous le milieu de l'écran : les 5 boutons sont centrés ensemble.
local BUTTON = Vector2.new(84, 84) -- (boutons carrés à icône, deux par ligne)
local GAP = 10
local BUTTONS_BOTTOM = -52 -- (bas des boutons du HUD, depuis le milieu de l'écran : haut des boutons Daily - GAP)
local COUNTERS_WIDTH = 300
local BANNER_TIME = 3.2
local REFRESH = 0.1
local POP_LIMIT = 4

type Ui = {
	Screen: ScreenGui,
	Root: Frame,
	Widgets: Frame,
	Buttons: Frame,
	ShopBadge: UIKit.Badge,
	IndexBadge: UIKit.Badge,
	Money: TextLabel,
	Income: TextLabel,
	Pops: Frame,
	Speed: TextLabel,
	ZoneLine: TextLabel,
	Banner: Frame,
	BannerPop: UIScale,
	BannerTitle: TextLabel,
	BannerText: TextLabel,
	Carry: Frame,
	CarryFace: Frame,
	CarryTag: Frame,
	CarryArrow: TextLabel,
	CarryText: TextLabel,
	ChaseText: TextLabel,
	Tanks: Frame,
	TankTitle: TextLabel,
	TankRows: Frame,
	Stored: TextLabel,
	BuyTank: TextButton,
	Home: Part,
	Beam: Beam,
	From: Attachment?,
}

type TankRow = {
	Frame: Frame,
	Chip: Frame,
	Name: TextLabel,
	Time: TextLabel,
	Fill: Frame,
	Open: TextButton,
}

local ui: Ui? = nil
local rows: { TankRow } = {}
local visible = true
local panelsOpen = false
local shownMoney: number? = nil
local lastMoney: number? = nil
local lastZone = ""
local bannerToken = 0
local popCount = 0
local busy: { [string]: boolean } = {} -- demandes au serveur en cours (pas deux à la fois)
local homePlot = -1 -- (entrée du parc gardée : voir homePosition)
local homeAt: Vector3? = nil
local homeRetry = 0
local tutorialBeam = false -- le guide des premières minutes montre déjà son rayon (lu toutes les REFRESH s)
local beamFill: Color3? = nil

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function num(key: string): number
	local value = ReplicaController.Get(key)
	return if type(value) == "number" and value == value then value else 0
end

local function localPlayer(): Player
	return Players.LocalPlayer
end

local function rootPart(): BasePart?
	local character = localPlayer().Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function zoneByName(name: string): any
	return Config.Zones.ByName[name]
end

-- Première zone qui demande plus de vitesse que `speed` (nil : toutes sont ouvertes)
local function nextZone(speed: number): any
	for _, zone in ZONES do
		if zone.Speed > speed then
			return zone
		end
	end
	return nil
end

-- Angle (degrés, sens des aiguilles d'une montre, 0 = tout droit devant la caméra) de la flèche qui va de `from` à `to`
function HudController.Heading(from: Vector3, to: Vector3, camera: CFrame): number
	local relative = camera:VectorToObjectSpace(to - from)
	if math.abs(relative.X) < 1e-6 and math.abs(relative.Z) < 1e-6 then
		return 0
	end
	return math.deg(math.atan2(relative.X, -relative.Z))
end

-- Entrée de son parc (sinon son point d'apparition ou son sol). Gardée une fois trouvée : un parc ne bouge pas, et ses
-- pièces peuvent sortir du streaming quand le joueur est loin. Cherchée au plus une fois par seconde tant qu'elle manque.
local function homePosition(): Vector3?
	local index = num("Plot")
	if index == homePlot and (homeAt ~= nil or os.clock() < homeRetry) then
		return homeAt
	end
	homePlot = index
	homeAt = nil
	homeRetry = os.clock() + 1
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local plot = plots and index > 0 and plots:FindFirstChild("Plot" .. index)
	if not plot then
		return nil
	end
	for _, name in { "Entrance", "Spawn", "Floor" } do
		local part = plot:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			homeAt = part.Position
			return homeAt
		end
	end
	return nil
end

local function guardianPosition(zone: string): Vector3?
	local folder = Workspace:FindFirstChild("Guardians")
	local model = folder and folder:FindFirstChild(zone .. " Guardian")
	if model and model:IsA("Model") then
		return model:GetPivot().Position
	end
	return nil
end

-- (un attribut reposé à la même valeur ne repeint rien)
local function setAttr(inst: Instance, name: string, value: any)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

local function rarityColors(rarity: string): (Color3, boolean)
	local colors = UIKit.Rarity[rarity] or UIKit.Rarity.Common
	return colors.Fill, colors.Rainbow == true
end

-- ===================================================================== construction

local function text(props: { [string]: any }): TextLabel
	return UIKit.label(props)
end

local function buildButtons(root: Frame): (Frame, UIKit.Badge, UIKit.Badge)
	local frame: Frame = new("Frame", {
		Name = "HudButtons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 0.5, BUTTONS_BOTTOM),
		Size = UDim2.fromOffset(2 * BUTTON.X + GAP, BUTTON.Y),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local shop = UIKit.menuButton({
		Name = "Shop",
		Text = "Shop",
		Icon = "shop",
		Color = Colors.Green,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		Parent = frame,
	}, function()
		ShopController.Toggle()
	end)
	local index = UIKit.menuButton({
		Name = "Index",
		Text = "Index",
		Icon = "book",
		Color = Colors.Orange,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		Parent = frame,
	}, function()
		IndexController.Toggle()
	end)
	return frame, UIKit.badge(shop), UIKit.badge(index)
end

-- Case carrée colorée avec un petit texte (icône des compteurs)
local function iconSquare(parent: GuiObject, name: string, color: Color3, glyph: string, size: number): Frame
	local square = UIKit.card({
		Name = name,
		Color = color,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(size, size),
		ZIndex = parent.ZIndex + 2,
		Parent = parent,
	})
	text({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.7),
		Text = glyph,
		ZIndex = square.ZIndex + 3,
		Parent = square,
	})
	return square
end

local function buildCounters(widgets: Frame): (TextLabel, TextLabel, Frame, TextLabel, TextLabel)
	local frame: Frame = new("Frame", {
		Name = "Counters",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(COUNTERS_WIDTH, 66 + 8 + 60),
		BackgroundTransparency = 1,
		Parent = widgets,
	})
	local moneyCard = UIKit.card({
		Name = "MoneyCard",
		Color = Colors.Slate,
		Size = UDim2.fromOffset(COUNTERS_WIDTH, 66),
		Parent = frame,
	})
	iconSquare(moneyCard, "Icon", Colors.Money, "$", 50)
	local z = moneyCard.ZIndex + 2
	local money = text({
		Name = "Money",
		Position = UDim2.fromOffset(68, 4),
		Size = UDim2.new(1, -78, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.GreenText,
		Text = "$0",
		ZIndex = z,
		Parent = moneyCard,
	})
	local income = text({
		Name = "Income",
		Position = UDim2.fromOffset(68, 40),
		Size = UDim2.new(1, -78, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "+$0/s",
		ZIndex = z,
		Parent = moneyCard,
	})
	local pops: Frame = new("Frame", {
		Name = "Pops",
		Position = UDim2.fromOffset(68, -6),
		Size = UDim2.fromOffset(COUNTERS_WIDTH - 78, 30),
		BackgroundTransparency = 1,
		ZIndex = z + 2,
		Parent = moneyCard,
	})

	local speedCard = UIKit.card({
		Name = "SpeedCard",
		Color = Colors.Slate,
		Position = UDim2.fromOffset(0, 66 + 8),
		Size = UDim2.fromOffset(COUNTERS_WIDTH, 60),
		Parent = frame,
	})
	iconSquare(speedCard, "Icon", Colors.Cyan, ">>", 44)
	local speed = text({
		Name = "Speed",
		Position = UDim2.fromOffset(62, 4),
		Size = UDim2.new(1, -72, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0 Speed",
		ZIndex = z,
		Parent = speedCard,
	})
	local zoneLine = text({
		Name = "ZoneLine",
		Position = UDim2.fromOffset(62, 34),
		Size = UDim2.new(1, -72, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		TextColor3 = Colors.Muted,
		ZIndex = z,
		Parent = speedCard,
	})
	return money, income, pops, speed, zoneLine
end

local function buildBanner(widgets: Frame): (Frame, UIScale, TextLabel, TextLabel)
	local banner = UIKit.card({
		Name = "ZoneBanner",
		Color = Colors.Slate,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 76),
		Visible = false,
		Parent = widgets,
	})
	local pop: UIScale = new("UIScale", { Parent = banner })
	local title = text({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -24, 0, 36),
		Text = "",
		ZIndex = banner.ZIndex + 2,
		Parent = banner,
	})
	local line = text({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "",
		ZIndex = banner.ZIndex + 2,
		Parent = banner,
	})
	return banner, pop, title, line
end

local function buildCarry(widgets: Frame): (Frame, Frame, Frame, TextLabel, TextLabel, TextLabel)
	local carry = UIKit.card({
		Name = "CarryCard",
		Color = Colors.Slate,
		Accent = Colors.Yellow,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 60),
		Visible = false,
		Parent = widgets,
	})
	local face = carry:FindFirstChild("Face") :: Frame
	local z = carry.ZIndex + 2
	local tag = UIKit.rarityTag("Common", {
		Name = "Rarity",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(124, 44),
		ZIndex = z,
		Parent = carry,
	})
	local arrow = text({
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(170, 30),
		Size = UDim2.fromOffset(44, 44),
		Text = ">",
		TextColor3 = Colors.Yellow,
		ZIndex = z,
		Parent = carry,
	})
	local home = text({
		Name = "Home",
		Position = UDim2.fromOffset(204, 10),
		Size = UDim2.new(1, -216, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = z,
		Parent = carry,
	})
	local chase = text({
		Name = "Chase",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.new(1, -24, 0, 28),
		Text = "",
		TextColor3 = Colors.Tomato,
		Visible = false,
		ZIndex = z,
		Parent = carry,
	})
	return carry, face, tag, arrow, home, chase
end

local function revealTank(slot: number)
	local key = "Reveal" .. slot
	if busy[key] then
		return
	end
	busy[key] = true
	task.spawn(function()
		local called, ok, message = pcall(function()
			return Remotes.Function("RevealTank"):InvokeServer(slot)
		end)
		busy[key] = false
		if not called then
			ok, message = false, "Try again"
		end
		if not ok then
			NotifyController.Show(if type(message) == "string" then message else "Try again", "error")
		end
	end)
end

local function buyTank()
	if busy.BuyTank then
		return
	end
	busy.BuyTank = true
	task.spawn(function()
		local called, ok, message = pcall(function()
			return Remotes.Function("BuyTank"):InvokeServer()
		end)
		busy.BuyTank = false
		if not called then
			ok, message = false, "Try again"
		end
		NotifyController.Show(if type(message) == "string" then message else "Try again", if ok then "success" else "error")
	end)
end

local function buildTankRow(parent: Frame, slot: number): TankRow
	local frame = UIKit.card({
		Name = "Tank" .. slot,
		Color = Colors.SlateDark,
		LayoutOrder = slot,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = parent,
	})
	local z = frame.ZIndex + 2
	local chip = UIKit.card({
		Name = "Chip",
		Color = Colors.Slate,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = z,
		Parent = frame,
	})
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(44, 4),
		Size = UDim2.new(0.55, -44, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = z,
		Parent = frame,
	})
	local time = text({
		Name = "Time",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 4),
		Size = UDim2.new(0.45, -8, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = z,
		Parent = frame,
	})
	local bar: Frame = new("Frame", {
		Name = "Bar",
		Position = UDim2.new(0, 44, 1, -12),
		Size = UDim2.new(1, -52, 0, 6),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = frame,
	})
	local fill: Frame = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Green,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = bar,
	})
	local open = UIKit.button({
		Name = "Open",
		Text = "OPEN",
		Color = Colors.Green,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(92, 34),
		MaxTextSize = 22,
		Visible = false,
		ZIndex = z + 2,
		Parent = frame,
	}, function()
		revealTank(slot)
	end)
	return { Frame = frame, Chip = chip, Name = name, Time = time, Fill = fill, Open = open }
end

local function buildTanks(widgets: Frame): (Frame, TextLabel, Frame, TextLabel, TextButton)
	local width = 232
	local panel = UIKit.card({
		Name = "TanksCard",
		Color = Colors.Slate,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 30),
		Size = UDim2.fromOffset(width, 120),
		Visible = false,
		Parent = widgets,
	})
	local z = panel.ZIndex + 2
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Yellow,
		Text = "TANKS",
		ZIndex = z,
		Parent = panel,
	})
	local list: Frame = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = panel,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local stored = text({
		Name = "Stored",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "",
		ZIndex = z,
		Parent = panel,
	})
	local buy = UIKit.button({
		Name = "BuyTank",
		Text = "",
		Color = Colors.Green,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 40),
		MaxTextSize = 22,
		ZIndex = z,
		Parent = panel,
	}, buyTank)
	return panel, title, list, stored, buy
end

local function buildWorld(): (Part, Beam)
	local home: Part = new("Part", {
		Name = "HudHomeTarget",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
	})
	local to: Attachment = new("Attachment", { Name = "To", Position = Vector3.new(0, 1, 0), Parent = home })
	local beam: Beam = new("Beam", {
		Name = "HomeBeam",
		Attachment1 = to,
		Color = ColorSequence.new(Colors.Yellow),
		Transparency = NumberSequence.new(0.35),
		Width0 = 0.5,
		Width1 = 0.5,
		FaceCamera = true,
		LightEmission = 0.5,
		LightInfluence = 0,
		Segments = 1,
		Enabled = false,
		Parent = home,
	})
	home.Parent = Workspace
	return home, beam
end

-- ===================================================================== mise à jour

local function setMoneyText(current: Ui, value: number)
	local textValue = Format.Money(value)
	if current.Money.Text ~= textValue then
		current.Money.Text = textValue
	end
end

-- Gain ou dépense qui s'envole au-dessus de l'argent
local function pop(current: Ui, delta: number)
	if popCount >= POP_LIMIT or panelsOpen then
		return
	end
	popCount += 1
	local gain = delta > 0
	local label = text({
		Name = "Pop",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if gain then Colors.GreenText else Colors.Tomato,
		Text = (if gain then "+" else "-") .. Format.Money(math.abs(delta)),
		ZIndex = current.Pops.ZIndex,
		Parent = current.Pops,
	})
	UIKit.tween(label, 1.1, { Position = UDim2.fromOffset(0, -46), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		UIKit.tween(stroke, 1.1, { Transparency = 1 })
	end
	task.delay(1.15, function()
		popCount -= 1
		label:Destroy()
	end)
end

local function onMoney(value: any)
	local current = ui
	if not current or type(value) ~= "number" or value ~= value then
		return
	end
	local previous = lastMoney
	lastMoney = value
	if shownMoney == nil or previous == nil then
		shownMoney = value
		setMoneyText(current, value)
		return
	end
	local delta = value - previous
	-- (le revenu de chaque seconde ne s'envole pas : seulement les vrais gains et les dépenses)
	local income = num("Income")
	if delta < 0 or delta > income * 1.5 + 1 then
		pop(current, delta)
	end
end

local function refreshCounters(current: Ui)
	current.Income.Text = "+" .. Format.Rate(num("Income"))
	local speed = num("Speed")
	current.Speed.Text = Format.Number(speed) .. " Speed"
	local zone = zoneByName(lastZone)
	if zone then
		local fast = speed >= zone.Speed
		current.Speed.TextColor3 = if fast then Colors.GreenText else Colors.Tomato
		current.ZoneLine.Text = if zone.Speed <= 0 then zone.Name .. ": open to everyone" else string.format("%s: %s advised", zone.Name, Format.Number(zone.Speed))
		current.ZoneLine.TextColor3 = if fast then Colors.GreenText else Colors.Tomato
	else
		current.Speed.TextColor3 = Colors.Text
		local target = nextZone(speed)
		current.ZoneLine.Text = if target then string.format("Next: %s at %s", target.Name, Format.Number(target.Speed)) else "Every zone is open!"
		current.ZoneLine.TextColor3 = Colors.Muted
	end
end

local function showBanner(current: Ui, zoneName: string)
	local zone = zoneByName(zoneName)
	if not zone then
		return
	end
	bannerToken += 1
	local token = bannerToken
	local speed = num("Speed")
	local fast = speed >= zone.Speed
	current.BannerTitle.Text = string.upper(zone.Name)
	current.BannerTitle.TextColor3 = UIKit.Lighten(zone.Color, 0.35)
	current.BannerText.Text = if zone.Speed <= 0
		then "Safe for everyone. Grab a fossil!"
		elseif fast then string.format("Advised speed %s. You are fast enough!", Format.Number(zone.Speed))
		else string.format("Advised speed %s. Too slow, watch the guardian!", Format.Number(zone.Speed))
	current.BannerText.TextColor3 = if fast then Colors.GreenText else Colors.Tomato
	current.Banner.Visible = true
	current.BannerPop.Scale = 0.7
	UIKit.tween(current.BannerPop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(BANNER_TIME, function()
		if token == bannerToken then
			UIKit.tween(current.BannerPop, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.16)
			if token == bannerToken then
				current.Banner.Visible = false
			end
		end
	end)
end

local function hideBanner(current: Ui)
	bannerToken += 1
	current.Banner.Visible = false
end

local function onZone()
	local current = ui
	local zone = localPlayer():GetAttribute("Zone")
	local name = if type(zone) == "string" then zone else ""
	if name == lastZone then
		return
	end
	lastZone = name
	if not current then
		return
	end
	refreshCounters(current)
	if name ~= "" and ReplicaController.Get("Carrying") == nil then
		showBanner(current, name)
	elseif name == "" then
		hideBanner(current)
	end
end

local function fromAttachment(current: Ui): Attachment?
	local root = rootPart()
	if not root then
		return nil
	end
	local from = current.From
	if from and from.Parent == root then
		return from
	end
	local created: Attachment = new("Attachment", { Name = "HudCarryFrom", Parent = root })
	current.From = created
	current.Beam.Attachment0 = created
	return created
end

-- Carte du transport (chaque image : la flèche suit la caméra)
local function refreshCarry(current: Ui)
	local carrying = ReplicaController.Get("Carrying")
	local show = visible and not panelsOpen and type(carrying) == "table"
	if not show then
		current.Carry.Visible = false
		current.Beam.Enabled = false
		return
	end
	if not current.Carry.Visible then
		hideBanner(current)
	end
	current.Carry.Visible = true
	local rarity = if type(carrying.Rarity) == "string" then carrying.Rarity else "Common"
	local fill, rainbow = rarityColors(rarity)
	local tagText = current.CarryTag:FindFirstChild("Text", true)
	if tagText and tagText:IsA("TextLabel") then
		tagText.Text = string.upper(rarity)
	end
	local tagFace = current.CarryTag:FindFirstChild("Face")
	if tagFace then
		setAttr(tagFace, "Tint", fill)
		setAttr(tagFace, "Rainbow", rainbow)
	end
	local root = rootPart()
	local home = homePosition()
	local camera = Workspace.CurrentCamera
	if root and home then
		local distance = math.floor((home - root.Position).Magnitude + 0.5)
		current.CarryText.Text = string.format("HOME %d studs", distance)
		current.CarryArrow.Visible = camera ~= nil
		if camera then
			-- (« > » regarde vers la droite : -90 pour qu'il regarde vers le haut à 0)
			current.CarryArrow.Rotation = HudController.Heading(root.Position, home, camera.CFrame) - 90
		end
		current.Home.CFrame = CFrame.new(home)
		if beamFill ~= fill then
			beamFill = fill
			current.Beam.Color = ColorSequence.new(fill)
		end
		current.Beam.Enabled = not tutorialBeam and fromAttachment(current) ~= nil
	else
		current.CarryText.Text = "BRING IT HOME!"
		current.CarryArrow.Visible = false
		current.Beam.Enabled = false
	end
	local chasedBy = localPlayer():GetAttribute("ChasedBy")
	local chased = type(chasedBy) == "string" and chasedBy ~= ""
	local guardian = if chased and root then guardianPosition(chasedBy :: string) else nil
	current.ChaseText.Visible = chased
	if chased then
		current.ChaseText.Text = if guardian and root then string.format("GUARDIAN %d studs!", math.floor((guardian - root.Position).Magnitude + 0.5)) else "GUARDIAN IS CHASING YOU!"
	end
	current.Carry.Size = UDim2.fromOffset(440, if chased then 92 else 60)
	local blink = chased and (os.clock() * 4) % 2 < 1
	setAttr(current.CarryFace, "Tint", if blink then Color3.fromRGB(120, 24, 30) else Colors.Slate)
	local stroke = current.CarryFace:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = if chased then Colors.Tomato else Colors.Yellow
	end
end

local function tankList(): { [string]: any }
	local tanks = ReplicaController.Get("Tanks")
	return if type(tanks) == "table" then tanks else {}
end

local function refreshTanks(current: Ui)
	local count = math.clamp(math.floor(num("TankCount")), 0, ECONOMY.Tanks.Max)
	local tanks = tankList()
	local storedList = ReplicaController.Get("Stored")
	local stored = if type(storedList) == "table" then #storedList else 0
	local used = 0
	for slot = 1, count do
		if type(tanks[tostring(slot)]) == "table" then
			used += 1
		end
	end
	local show = visible and not panelsOpen and count > 0 and (used > 0 or stored > 0)
	current.Tanks.Visible = show
	if not show then
		return
	end
	while #rows < count do
		table.insert(rows, buildTankRow(current.TankRows, #rows + 1))
	end
	local now = serverNow()
	for slot, row in rows do
		row.Frame.Visible = slot <= count
		if slot > count then
			continue
		end
		local tank = tanks[tostring(slot)]
		if type(tank) == "table" and type(tank.Rarity) == "string" then
			local fill, rainbow = rarityColors(tank.Rarity)
			local chipFace = row.Chip:FindFirstChild("Face")
			if chipFace then
				setAttr(chipFace, "Tint", fill)
				setAttr(chipFace, "Rainbow", rainbow)
			end
			row.Name.Text = string.upper(tank.Rarity)
			row.Name.TextColor3 = (UIKit.Rarity[tank.Rarity] or UIKit.Rarity.Common).Tag
			local endsAt = if type(tank.EndsAt) == "number" then tank.EndsAt else now
			local startedAt = if type(tank.StartedAt) == "number" then tank.StartedAt else endsAt
			local left = endsAt - now
			local ready = left <= 0
			row.Open.Visible = ready
			row.Time.Visible = not ready
			row.Time.Text = Format.Clock(math.ceil(left))
			row.Time.TextColor3 = Colors.Text
			local span = endsAt - startedAt
			local progress = if ready then 1 elseif span > 0 then math.clamp((now - startedAt) / span, 0, 1) else 0
			row.Fill.Size = UDim2.fromScale(progress, 1)
			row.Fill.BackgroundColor3 = if ready then Colors.Green else fill
		else
			local chipFace = row.Chip:FindFirstChild("Face")
			if chipFace then
				setAttr(chipFace, "Tint", Colors.Slate)
				setAttr(chipFace, "Rainbow", false)
			end
			row.Name.Text = "EMPTY"
			row.Name.TextColor3 = Colors.Disabled
			row.Open.Visible = false
			row.Time.Visible = true
			row.Time.Text = ""
			row.Fill.Size = UDim2.fromScale(0, 1)
		end
	end
	current.TankTitle.Text = string.format("TANKS  %d/%d", used, count)
	local listHeight = count * 44 + math.max(0, count - 1) * 6
	current.TankRows.Size = UDim2.new(1, -16, 0, listHeight)
	local y = 40 + listHeight + 8
	current.Stored.Visible = stored > 0
	if stored > 0 then
		current.Stored.Text = string.format("+%d fossil%s waiting", stored, if stored == 1 then "" else "s")
		current.Stored.Position = UDim2.fromOffset(12, y)
		y += 26
	end
	local price = ECONOMY.NextTankPrice(count)
	current.BuyTank.Visible = price ~= nil
	if price then
		current.BuyTank.Text = "NEW TANK " .. Format.Money(price)
		current.BuyTank:SetAttribute("Disabled", num("Money") < price)
		current.BuyTank.Position = UDim2.fromOffset(8, y)
		y += 48
	end
	current.Tanks.Size = UDim2.fromOffset(232, y + 4)
end

-- Pastille du Shop : une trail en argent pas encore achetée est payable
local function shopBadge(): string
	local trails = ReplicaController.Get("Trails")
	local owned = if type(trails) == "table" and type(trails.Owned) == "table" then trails.Owned else {}
	local money = num("Money")
	for id, trail in Config.Speed.Trails do
		if not owned[id] and money >= trail.Price then
			return "!"
		end
	end
	return ""
end

local function refresh()
	local current = ui
	if not current then
		return
	end
	local step = TutorialController.Step()
	tutorialBeam = step ~= nil and step.Target ~= nil
	refreshCounters(current)
	refreshTanks(current)
	current.ShopBadge.Set(shopBadge())
	current.IndexBadge.Set(IndexController.Unseen())
end

local function applyVisibility()
	local current = ui
	if not current then
		return
	end
	current.Widgets.Visible = visible and not panelsOpen
	current.Buttons.Visible = visible
	if not current.Widgets.Visible then
		current.Beam.Enabled = false
	end
end

function HudController.SetVisible(on: boolean)
	visible = on == true
	applyVisibility()
end

-- ===================================================================== cycle de vie

function HudController.Init()
	local screen, root = UIKit.Root("Hud", 3)
	local widgets: Frame = new("Frame", {
		Name = "Widgets",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local buttons, shopBadgeUi, indexBadge = buildButtons(root)
	local money, income, pops, speed, zoneLine = buildCounters(widgets)
	local banner, bannerPop, bannerTitle, bannerText = buildBanner(widgets)
	local carry, carryFace, carryTag, carryArrow, carryText, chaseText = buildCarry(widgets)
	local tanks, tankTitle, tankRows, stored, buy = buildTanks(widgets)
	local home, beam = buildWorld()
	ui = {
		Screen = screen,
		Root = root,
		Widgets = widgets,
		Buttons = buttons,
		ShopBadge = shopBadgeUi,
		IndexBadge = indexBadge,
		Money = money,
		Income = income,
		Pops = pops,
		Speed = speed,
		ZoneLine = zoneLine,
		Banner = banner,
		BannerPop = bannerPop,
		BannerTitle = bannerTitle,
		BannerText = bannerText,
		Carry = carry,
		CarryFace = carryFace,
		CarryTag = carryTag,
		CarryArrow = carryArrow,
		CarryText = carryText,
		ChaseText = chaseText,
		Tanks = tanks,
		TankTitle = tankTitle,
		TankRows = tankRows,
		Stored = stored,
		BuyTank = buy,
		Home = home,
		Beam = beam,
		From = nil,
	}
	UIKit.PanelsChanged:Connect(function(open: boolean)
		panelsOpen = open == true
		applyVisibility()
	end)
	ReplicaController.Observe("Money", onMoney)
	local player = localPlayer()
	player:GetAttributeChangedSignal("Zone"):Connect(onZone)
	RunService.Heartbeat:Connect(function(dt: number)
		local current = ui
		if not current then
			return
		end
		local target = lastMoney
		local shown = shownMoney
		if target and shown and shown ~= target then
			local nextValue = shown + (target - shown) * math.min(1, dt * 8)
			if math.abs(target - nextValue) < math.max(0.5, math.abs(target) * 1e-4) then
				nextValue = target
			end
			shownMoney = nextValue
			setMoneyText(current, nextValue)
		end
		refreshCarry(current)
		-- (messages courts sous la carte du haut, pour ne pas la cacher)
		local top: Frame? = if current.Carry.Visible then current.Carry elseif current.Banner.Visible and current.Widgets.Visible then current.Banner else nil
		UIKit.SetToastTop(if top then 8 + top.Size.Y.Offset + 10 else nil)
	end)
end

function HudController.Start()
	onZone()
	while true do
		refresh()
		task.wait(REFRESH)
	end
end

return HudController
