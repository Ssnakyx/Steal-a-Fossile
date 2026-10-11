--!strict
-- Shop (brief 12 « ui-ux », GDD : Monétisation, Vitesse et treadmill ; refait en grandes cartes illustrées par
-- sections, style des Steal a ... du moment). Bouton Shop du HUD, quatre onglets :
--   * Speed   : treadmill (niveau, gain actuel, niveau suivant avec son gain, son prix en argent du jeu et, si le
--               produit est en vente, son prix Robux réel lu sur Roblox), passe x2 Treadmill, et un raccourci vers les trails ;
--   * Trails  : trails Robux (Neon, Galaxy, Golden : passes) puis trails en argent du jeu (acheter, porter) ;
--   * Passes  : x2 Money, Fast Revive, VIP ;
--   * Items   : Bear Traps (argent du jeu, par 1 ou 5), Bear Traps x5, Instant Revive et Server Luck (Robux), tours de
--               roue (Robux, seulement si le serveur les permet à ce joueur).
-- Ce qui est en vente vient du serveur (GetShop, GetSpinOffers) : un objet Robux à Id = 0 n'y est pas et reste caché.
-- Dans Studio seulement, ces objets sont montrés grisés (« Id = 0 ») pour voir la mise en page et savoir quoi créer
-- dans le Creator Hub. Les prix Robux affichés sont ceux de Roblox (« R$ ... » tant qu'il ne les a pas donnés).
-- Le client ne décide rien : BuyTreadmill, BuyPass, BuyProduct, BuyTrail, EquipTrail, BuyTraps, BuySpins.
-- API : ShopController.Open(onglet?), Close(), Toggle(onglet?), IsOpen(), Select(onglet), Tabs = { "Speed", ... }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotifyController = require(script.Parent.NotifyController)
local ReplicaController = require(script.Parent.ReplicaController)

local ShopController = {}
ShopController.Tabs = { "Speed", "Trails", "Passes", "Items" }

local Colors = UIKit.Colors
local new = UIKit.new
local Z = 23
local PANEL = Vector2.new(1040, 620)
local SIDE = 196 -- largeur des onglets
local PAGE_W = PANEL.X - 32 - (SIDE + 14) - 14 -- (largeur des cartes : page moins la barre de défilement)
local COLUMNS = 3
local GAP = 12
local CARD_W = math.floor((PAGE_W - (COLUMNS - 1) * GAP) / COLUMNS)
local CARD_H = 300
local TAB_H = 72
local WIDE_H = 210
local RELOAD_DELAY = 1.2 -- secondes entre deux GetShop (limite du serveur : 1 par seconde)
local STUDIO = RunService:IsStudio()

type ButtonSpec = { Text: string, Color: Color3, Disabled: boolean?, OnClick: (() -> ())? }
type CardSpec = {
	Name: string,
	Title: string,
	Subtitle: string,
	Color: Color3,
	Rainbow: boolean?,
	Icon: string?, -- icône du pack (UIKit.Icons)
	Glyph: string?, -- gros texte sur l'image (« x2 »)
	Ribbon: { Color3 }?, -- bande aux couleurs d'une trail derrière l'icône
	Pips: Vector2?, -- carte large : niveaux (X faits sur Y)
	Buttons: { ButtonSpec },
}

type Ui = {
	Panel: UIKit.Panel,
	Tabs: UIKit.Tabs,
	Page: ScrollingFrame,
	Money: TextLabel,
}

local ui: Ui? = nil
local shop: { [string]: any }? = nil
local spinOffers: { { [string]: any } } = {}
local loading = false
local missed = false
local reloadQueued = false
local lastLoad = -math.huge
local busy: { [string]: boolean } = {}
local updaters: { () -> () } = {} -- (mises à jour de la page affichée sans la refaire : argent, trails portées...)
local current = "Speed"

local function num(key: string): number
	local value = ReplicaController.Get(key)
	return if type(value) == "number" and value == value then value else 0
end

-- « x1.5 » (Format.Number arrondit à l'entier)
local function times(value: any): string
	local n = tonumber(value) or 1
	if n == math.floor(n) then
		return "x" .. Format.Number(n)
	end
	local short = string.gsub(string.format("%.2f", n), "0+$", "")
	return "x" .. short
end

local function robux(price: any): string
	return if type(price) == "number" then "R$ " .. Format.Number(price) else "R$ ..."
end

-- ===================================================================== demandes au serveur

-- Demande au serveur (une seule à la fois par clé). successToast : montrer le texte renvoyé quand ça marche.
local function request(key: string, remote: string, arg: any, successToast: boolean?)
	if busy[key] then
		return
	end
	busy[key] = true
	task.spawn(function()
		local called, ok, message = pcall(function()
			return Remotes.Function(remote):InvokeServer(arg)
		end)
		busy[key] = nil
		if not called then
			ok, message = false, "Try again"
		end
		local textOut = if type(message) == "string" then message else ""
		if not ok then
			NotifyController.Show(if textOut ~= "" then textOut else "Try again", "error")
		elseif successToast and textOut ~= "" then
			NotifyController.Show(textOut, "success")
		end
	end)
end

local render: (() -> ())? = nil

local function load()
	if loading then
		missed = true -- (refait à la fin du chargement en cours)
		return
	end
	missed = false
	loading = true
	lastLoad = os.clock()
	local ok, result = pcall(function()
		return Remotes.Function("GetShop"):InvokeServer()
	end)
	if ok and type(result) == "table" then
		shop = result
	end
	local spins = ReplicaController.Get("Spins")
	if type(spins) == "table" and spins.CanBuy == true then
		local okOffers, list = pcall(function()
			return Remotes.Function("GetSpinOffers"):InvokeServer()
		end)
		if okOffers and type(list) == "table" then
			spinOffers = list
		end
	else
		spinOffers = {}
	end
	loading = false
	if missed then
		load()
		return
	end
	local draw = render
	if draw and ShopController.IsOpen() then
		draw()
	end
end

-- Recharge le contenu (achat Robux reçu, passe, niveau du treadmill) sans dépasser la limite du serveur
local function reload()
	if reloadQueued or not ShopController.IsOpen() then
		return
	end
	reloadQueued = true
	task.delay(math.max(0, RELOAD_DELAY - (os.clock() - lastLoad)), function()
		reloadQueued = false
		if ShopController.IsOpen() then
			load()
		end
	end)
end

-- ===================================================================== cartes

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 2
	return UIKit.label(props)
end

-- Section de la page : titre « -- SPEED -- » puis une grille de cartes (3 par ligne, ou cartes larges) dont la hauteur
-- suit le nombre de cartes.
type Section = { Grid: Frame, Count: number, Wide: boolean }

local sectionOrder = 0

local function resize(sec: Section)
	if sec.Wide then
		sec.Grid.Size = UDim2.fromOffset(PAGE_W, sec.Count * WIDE_H + math.max(0, sec.Count - 1) * GAP)
	else
		local rows = math.max(1, math.ceil(sec.Count / COLUMNS))
		sec.Grid.Size = UDim2.fromOffset(PAGE_W, rows * CARD_H + (rows - 1) * GAP)
	end
end

-- Couleur du titre de chaque section (comme Steal an Egg : PASSES jaune, SPEED bleu ciel, MONEY vert)
local SECTION_COLORS: { [string]: Color3 } = {
	FEATURED = Colors.Yellow,
	SPEED = Colors.Cyan,
	PASSES = Colors.Yellow,
	["SUPER TRAILS"] = Colors.Pink,
	["CASH TRAILS"] = Colors.GreenText,
	ITEMS = Colors.Orange,
	SPINS = Colors.Pink,
}

local function section(page: ScrollingFrame, title: string, wide: boolean?): Section
	sectionOrder += 1
	UIKit.sectionTitle({
		Name = "Section" .. sectionOrder,
		Text = title,
		Color = SECTION_COLORS[title],
		Width = PAGE_W,
		LayoutOrder = sectionOrder * 10,
		ZIndex = Z,
		Parent = page,
	})
	local cell = if wide then Vector2.new(PAGE_W, WIDE_H) else Vector2.new(CARD_W, CARD_H)
	local grid: Frame = new("Frame", {
		Name = "Grid" .. sectionOrder,
		LayoutOrder = sectionOrder * 10 + 1,
		Size = UDim2.fromOffset(PAGE_W, cell.Y),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = page,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	return { Grid = grid, Count = 0, Wide = wide == true }
end

-- Image d'une carte : icône du pack sur un halo clair, bande aux couleurs d'une trail derrière, gros texte « x2 » en
-- bas à droite. Le cadre s'appelle « Swatch » et son texte « Glyph » (les tests les lisent).
local function swatch(parent: GuiObject, spec: CardSpec, size: number, position: UDim2, anchor: Vector2): Frame
	local holder: Frame = new("Frame", {
		Name = "Swatch",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = Z + 1,
		Parent = parent,
	})
	-- (rayons blancs derrière l'image, comme les cartes de Steal an Egg)
	new("ImageLabel", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.45, 1.45),
		BackgroundTransparency = 1,
		Image = UIKit.Sunburst,
		ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = Z + 1,
		Parent = holder,
	})
	local colors = spec.Ribbon
	if colors and #colors > 0 then
		local ribbon: Frame = new("Frame", {
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.42, 0.56),
			Size = UDim2.fromScale(0.86, 0.24),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = Z + 2,
			Parent = holder,
		}, { new("UIStroke", { Color = Colors.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local keys = {}
		for index, color in colors do
			table.insert(keys, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
		end
		if #keys == 1 then
			table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
		end
		new("UIGradient", { Color = if spec.Rainbow then UIKit.RainbowSequence else ColorSequence.new(keys), Parent = ribbon })
	end
	-- (trail : la fusée au bout de la bande de couleurs, comme si elle la laissait derrière elle)
	local hasRibbon = colors ~= nil and #colors > 0
	UIKit.icon(spec.Icon or "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if hasRibbon then UDim2.fromScale(0.74, 0.46) else UDim2.fromScale(0.5, 0.47),
		Size = if hasRibbon then UDim2.fromScale(0.62, 0.62) else UDim2.fromScale(0.8, 0.8),
		ZIndex = Z + 3,
		Parent = holder,
	})
	text({
		Name = "Glyph",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1.02, 1),
		Size = UDim2.fromScale(0.56, 0.28),
		Text = spec.Glyph or "",
		Visible = (spec.Glyph or "") ~= "",
		ZIndex = Z + 6,
		Parent = holder,
	})
	return holder
end

local function buttonsOf(frame: Frame, specs: { ButtonSpec }, wide: boolean): { TextButton }
	local buttons = {}
	local count = #specs
	for index, buttonSpec in specs do
		local props: { [string]: any } = {
			Name = "Button" .. index,
			Text = buttonSpec.Text,
			Color = buttonSpec.Color,
			MaxTextSize = 28,
			ZIndex = Z + 3,
			Parent = frame,
		}
		if wide then
			-- (carte large : boutons empilés à droite)
			local height = 62
			local total = count * height + (count - 1) * 10
			props.AnchorPoint = Vector2.new(1, 0.5)
			props.Position = UDim2.new(1, -20, 0.5, -total / 2 + (index - 1) * (height + 10) + height / 2)
			props.Size = UDim2.fromOffset(232, height)
		else
			local width = math.floor((CARD_W - 28 - (count - 1) * 8) / count)
			props.AnchorPoint = Vector2.new(0, 1)
			props.Position = UDim2.new(0, 14 + (index - 1) * (width + 8), 1, -14)
			props.Size = UDim2.fromOffset(width, 56)
			props.MaxTextSize = if count > 1 then 22 else 28
		end
		local button = UIKit.button(props, buttonSpec.OnClick)
		button:SetAttribute("Disabled", buttonSpec.Disabled == true)
		table.insert(buttons, button)
	end
	return buttons
end

-- Carte du shop (grille) : grande image, titre, description, un ou deux boutons en bas. Renvoie la carte, ses boutons
-- (Button1, Button2) et sa description (« Subtitle »).
local function card(sec: Section, spec: CardSpec): (Frame, { TextButton }, TextLabel)
	sec.Count += 1
	resize(sec)
	local frame = UIKit.card({
		Name = spec.Name,
		Color = spec.Color,
		Rainbow = spec.Rainbow,
		LayoutOrder = sec.Count,
		ZIndex = Z,
		Parent = sec.Grid,
	})
	swatch(frame, spec, 128, UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	text({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 142),
		Size = UDim2.new(1, -20, 0, 34),
		Text = spec.Title,
		Parent = frame,
	})
	local subtitle = text({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 178),
		Size = UDim2.new(1, -24, 0, 46),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Body = true,
		MaxTextSize = 18,
		StrokeThickness = 2,
		Text = spec.Subtitle,
		Parent = frame,
	})
	return frame, buttonsOf(frame, spec.Buttons, false), subtitle
end

-- Carte large (« FEATURED ») : image à gauche, titre, description, niveaux en pastilles, boutons empilés à droite
local function wideCard(sec: Section, spec: CardSpec): (Frame, { TextButton }, TextLabel)
	sec.Count += 1
	resize(sec)
	local frame = UIKit.card({
		Name = spec.Name,
		Color = spec.Color,
		Rainbow = spec.Rainbow,
		LayoutOrder = sec.Count,
		ZIndex = Z,
		Parent = sec.Grid,
	})
	swatch(frame, spec, 166, UDim2.new(0, 22, 0.5, 0), Vector2.new(0, 0.5))
	local left = 210
	local right = 272
	text({
		Name = "Title",
		Position = UDim2.fromOffset(left, 18),
		Size = UDim2.new(1, -(left + right), 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = spec.Title,
		Parent = frame,
	})
	local subtitle = text({
		Name = "Subtitle",
		Position = UDim2.fromOffset(left, 68),
		Size = UDim2.new(1, -(left + right), 0, 66),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Body = true,
		MaxTextSize = 20,
		StrokeThickness = 2,
		Text = spec.Subtitle,
		Parent = frame,
	})
	local pipsSpec = spec.Pips
	if pipsSpec then
		local pips: Frame = new("Frame", {
			Name = "Pips",
			Position = UDim2.new(0, left, 1, -52),
			Size = UDim2.new(1, -(left + right), 0, 30),
			BackgroundTransparency = 1,
			ZIndex = Z + 2,
			Parent = frame,
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})
		for index = 1, pipsSpec.Y do
			new("Frame", {
				Name = "Pip" .. index,
				LayoutOrder = index,
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = if index <= pipsSpec.X then Colors.Yellow else Colors.SlateDark,
				BorderSizePixel = 0,
				ZIndex = Z + 2,
				Parent = pips,
			}, { new("UIStroke", { Color = Colors.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		end
	end
	return frame, buttonsOf(frame, spec.Buttons, true), subtitle
end

local function studioPlaceholder(): ButtonSpec
	return { Text = "Id = 0", Color = Colors.Disabled, Disabled = true, OnClick = function()
		NotifyController.Show("Not on sale: create it in the Creator Hub, then put its Id in the config.", "info")
	end }
end

local function onSaleList(kind: string): { [string]: { [string]: any } }
	local out = {}
	local list = shop and shop[kind]
	if type(list) == "table" then
		for _, entry in list do
			if type(entry) == "table" and type(entry.Key) == "string" then
				out[entry.Key] = entry
			end
		end
	end
	return out
end

-- Clés d'une table de config triées par Order
local function ordered(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local oa, ob = tonumber(map[a].Order) or 0, tonumber(map[b].Order) or 0
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return keys
end

-- ===================================================================== pages

type Look = { Icon: string, Glyph: string, Color: Color3 }

-- Allure des passes et produits : icône du pack, gros texte, couleur de la carte
local LOOKS: { [string]: Look } = {
	DoubleMoney = { Icon = "coins", Glyph = "x2", Color = Colors.Money },
	DoubleTreadmill = { Icon = "speed", Glyph = "x2", Color = Colors.Cyan },
	FastRevive = { Icon = "clock", Glyph = "x2", Color = Colors.Purple },
	VIP = { Icon = "crown", Glyph = "VIP", Color = Colors.Yellow },
	BearTraps5 = { Icon = "shield", Glyph = "x5", Color = Colors.Orange },
	InstantRevive = { Icon = "egg_gold", Glyph = "", Color = Colors.Pink },
	ServerLuck = { Icon = "star", Glyph = "x2", Color = Colors.Blue },
}

local function look(key: string): Look
	return LOOKS[key] or { Icon = "star", Glyph = "", Color = Colors.Robux }
end

local function passCard(sec: Section, key: string): boolean
	local pass = Config.Shop.Passes[key]
	local entry = onSaleList("Passes")[key]
	if not pass or (not entry and not STUDIO) then
		return false
	end
	local owned = function(): boolean
		local passes = ReplicaController.Get("Passes")
		return type(passes) == "table" and passes[key] == true
	end
	local button: ButtonSpec = if entry
		then {
			Text = robux(entry.Price),
			Color = Colors.Green,
			OnClick = function()
				if not owned() then
					request("Pass" .. key, "BuyPass", key)
				end
			end,
		}
		else studioPlaceholder()
	local style = look(key)
	local _, buttons = card(sec, {
		Name = key,
		Title = pass.Name,
		Subtitle = pass.Description,
		Color = style.Color,
		Icon = style.Icon,
		Glyph = style.Glyph,
		Buttons = { button },
	})
	if entry then
		local buy = buttons[1]
		table.insert(updaters, function()
			local has = owned()
			buy.Text = if has then "OWNED" else robux(entry.Price)
			buy:SetAttribute("Disabled", has)
		end)
	end
	return true
end

local function productCard(sec: Section, key: string, extra: (() -> string)?): boolean
	local product = Config.Shop.Products[key]
	local entry = onSaleList("Products")[key]
	if not product or (not entry and not STUDIO) then
		return false
	end
	local button: ButtonSpec = if entry
		then {
			Text = robux(entry.Price),
			Color = Colors.Green,
			OnClick = function()
				request("Product" .. key, "BuyProduct", key)
			end,
		}
		else studioPlaceholder()
	local style = look(key)
	local _, _, subtitle = card(sec, {
		Name = key,
		Title = product.Name,
		Subtitle = product.Description,
		Color = style.Color,
		Icon = style.Icon,
		Glyph = style.Glyph,
		Buttons = { button },
	})
	if extra then
		local base = product.Description
		table.insert(updaters, function()
			local more = extra()
			subtitle.Text = if more ~= "" then base .. " " .. more else base
		end)
	end
	return true
end

local function treadmillPage(page: ScrollingFrame)
	local info = shop and shop.Treadmill
	local level = math.floor(num("TreadmillLevel"))
	local levels = Config.Shop.Treadmill.Levels
	local maxLevel = #levels
	local nextInfo = if type(info) == "table" and type(info.Next) == "table" then info.Next else nil
	local nextLevel = level + 1
	local buttons: { ButtonSpec } = {}
	local subtitle: string
	local cash: number? = nil
	if level >= maxLevel then
		table.insert(buttons, { Text = "MAX", Color = Colors.Disabled, Disabled = true })
		subtitle = "Your treadmill is maxed out!"
	else
		-- argent du jeu (déblocage $1K, puis le prix monte), et Robux pour aller plus vite quand le produit est en vente
		local entry = levels[nextLevel]
		local price = if nextInfo and type(nextInfo.Cash) == "number" then nextInfo.Cash else entry.Cash
		cash = price
		table.insert(buttons, {
			Text = Format.Money(price),
			Color = Colors.Green,
			OnClick = function()
				request("Treadmill", "BuyTreadmill", "Cash")
			end,
		})
		if nextInfo and type(nextInfo.Price) == "number" then
			table.insert(buttons, {
				Text = robux(nextInfo.Price),
				Color = Colors.Green,
				OnClick = function()
					request("TreadmillRobux", "BuyTreadmill", "Robux")
				end,
			})
		end
		local rate = if nextInfo and type(nextInfo.Rate) == "number"
			then nextInfo.Rate
			else Config.Speed.Treadmill.BaseGain * entry.Multiplier
		subtitle = string.format(
			"Level %d: +%s Speed/s (%s).",
			nextLevel,
			Format.Number(rate),
			times(entry.Multiplier)
		)
	end
	local featured = section(page, "FEATURED", true)
	local _, wideButtons, sub = wideCard(featured, {
		Name = "Treadmill",
		Title = if level <= 0 then "Treadmill" else string.format("Treadmill  Level %d", level),
		Subtitle = "",
		Color = Colors.Cyan,
		Icon = "speed",
		Glyph = if level > 0 then "LV" .. level else "AFK",
		Pips = Vector2.new(level, maxLevel),
		Buttons = buttons,
	})
	table.insert(updaters, function()
		local rate = num("TreadmillRate")
		sub.Text = string.format("Now: +%s Speed/s on your treadmill, even AFK!\nNext %s", Format.Number(rate), subtitle)
		if cash and wideButtons[1] then
			wideButtons[1]:SetAttribute("Disabled", num("Money") < cash)
		end
	end)
	local boosts = section(page, "SPEED")
	passCard(boosts, "DoubleTreadmill")
	card(boosts, {
		Name = "TrailsHint",
		Title = "Trails",
		Subtitle = "Trails add speed while you wear them. Cheap ones cost cash!",
		Color = Colors.Orange,
		Icon = "star",
		Ribbon = { Colors.Yellow, Colors.Orange, Colors.Pink },
		Buttons = {
			{
				Text = "SEE TRAILS",
				Color = Colors.Blue,
				OnClick = function()
					ShopController.Select("Trails")
				end,
			},
		},
	})
end

local function trailState(): ({ [string]: any }, string)
	local trails = ReplicaController.Get("Trails")
	local owned = if type(trails) == "table" and type(trails.Owned) == "table" then trails.Owned else {}
	local equipped = if type(trails) == "table" and type(trails.Equipped) == "string" then trails.Equipped else ""
	return owned, equipped
end

local function trailsPage(page: ScrollingFrame)
	local passes = onSaleList("Passes")
	local robuxSection: Section? = nil
	for _, id in ordered(Config.Speed.RobuxTrails) do
		local trail = Config.Speed.RobuxTrails[id]
		local pass = Config.Shop.Passes[trail.Pass]
		local entry = passes[trail.Pass]
		if not pass or (not entry and not STUDIO) then
			continue
		end
		local sec = robuxSection or section(page, "SUPER TRAILS")
		robuxSection = sec
		local button: ButtonSpec = if entry
			then {
				Text = robux(entry.Price),
				Color = Colors.Green,
				OnClick = function()
					local owned, equipped = trailState()
					if owned[id] then
						if equipped ~= id then
							request("Equip", "EquipTrail", id)
						end
					else
						request("Trail" .. id, "BuyTrail", id)
					end
				end,
			}
			else studioPlaceholder()
		local _, buttons = card(sec, {
			Name = id,
			Title = trail.Name,
			Subtitle = string.format("%s Speed while you wear it, on top of your best cash trail.", times(pass.Multiplier)),
			Color = trail.Colors[1],
			Rainbow = id == "Galaxy",
			Icon = "speed",
			Ribbon = trail.Colors,
			Glyph = times(pass.Multiplier),
			Buttons = { button },
		})
		if entry then
			local buy = buttons[1]
			table.insert(updaters, function()
				local owned, equipped = trailState()
				if owned[id] then
					buy.Text = if equipped == id then "EQUIPPED" else "EQUIP"
					buy:SetAttribute("Tint", Colors.Blue)
					buy:SetAttribute("Disabled", equipped == id)
				else
					buy.Text = robux(entry.Price)
					buy:SetAttribute("Tint", Colors.Green)
					buy:SetAttribute("Disabled", false)
				end
			end)
		end
	end
	local cashSection = section(page, "CASH TRAILS")
	for _, id in ordered(Config.Speed.Trails) do
		local trail = Config.Speed.Trails[id]
		local _, buttons = card(cashSection, {
			Name = id,
			Title = trail.Name,
			Subtitle = string.format("%s trail: +%s Speed while you wear it.", trail.Tier, Format.Number(trail.Speed)),
			Color = trail.Colors[1],
			Icon = "speed",
			Ribbon = trail.Colors,
			Glyph = "+" .. Format.Number(trail.Speed),
			Buttons = {
				{
					Text = Format.Money(trail.Price),
					Color = Colors.Green,
					OnClick = function()
						local owned, equipped = trailState()
						if owned[id] then
							if equipped ~= id then
								request("Equip", "EquipTrail", id)
							end
						else
							request("Trail" .. id, "BuyTrail", id)
						end
					end,
				},
			},
		})
		local buy = buttons[1]
		table.insert(updaters, function()
			local owned, equipped = trailState()
			if owned[id] then
				buy.Text = if equipped == id then "EQUIPPED" else "EQUIP"
				buy:SetAttribute("Tint", Colors.Blue)
				buy:SetAttribute("Disabled", equipped == id)
			else
				buy.Text = Format.Money(trail.Price)
				buy:SetAttribute("Tint", Colors.Green)
				buy:SetAttribute("Disabled", num("Money") < trail.Price)
			end
		end)
	end
end

local function passesPage(page: ScrollingFrame)
	local sec = section(page, "PASSES")
	for _, key in ordered(Config.Shop.Passes) do
		if Config.Shop.Passes[key].Trail then
			continue -- (trails Robux : onglet Trails)
		end
		passCard(sec, key)
	end
	if sec.Count == 0 then
		sec.Grid.Visible = false
		text({
			Name = "Empty",
			LayoutOrder = 9999,
			Size = UDim2.fromOffset(PAGE_W, 60),
			Text = "Passes are coming soon!",
			TextColor3 = Colors.Muted,
			Parent = page,
		})
	end
end

local function itemsPage(page: ScrollingFrame)
	local trap = Config.Pvp.Trap
	local items = section(page, "ITEMS")
	local _, buttons, trapSub = card(items, {
		Name = "BearTraps",
		Title = "Bear Traps",
		Subtitle = "",
		Color = Colors.Orange,
		Icon = "shield",
		Buttons = {
			{
				Text = "x1 " .. Format.Money(trap.Price),
				Color = Colors.Green,
				OnClick = function()
					request("Traps1", "BuyTraps", 1, true)
				end,
			},
			{
				Text = "x5 " .. Format.Money(trap.Price * 5),
				Color = Colors.Green,
				OnClick = function()
					request("Traps5", "BuyTraps", 5, true)
				end,
			},
		},
	})
	table.insert(updaters, function()
		trapSub.Text = string.format("Stops thieves on the road. You have %d.", math.floor(num("BearTraps")))
		buttons[1]:SetAttribute("Disabled", num("Money") < trap.Price)
		buttons[2]:SetAttribute("Disabled", num("Money") < trap.Price * 5)
	end)
	productCard(items, "BearTraps5")
	productCard(items, "InstantRevive", function(): string
		local credits = math.floor(num("InstantCredits"))
		return if credits > 0 then string.format("(%d saved)", credits) else ""
	end)
	productCard(items, "ServerLuck", function(): string
		local endsAt = Workspace:GetAttribute("ServerLuckEndsAt")
		local left = if type(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() else 0
		return if left > 0 then "Active: " .. Format.Clock(left) .. " left!" else ""
	end)
	local offers: { [string]: { [string]: any } } = {}
	for _, offer in spinOffers do
		if type(offer) == "table" and type(offer.Key) == "string" then
			offers[offer.Key] = offer
		end
	end
	local spins = ReplicaController.Get("Spins")
	local canBuy = type(spins) == "table" and spins.CanBuy == true
	local spinSection: Section? = nil
	for _, key in ordered(Config.Daily.Spins.Products) do
		local product = Config.Daily.Spins.Products[key]
		local offer = offers[key]
		if not offer and not (STUDIO and canBuy) then
			continue
		end
		local sec = spinSection or section(page, "SPINS")
		spinSection = sec
		card(sec, {
			Name = key,
			Title = product.Name,
			Subtitle = "Spins for the Lucky Wheel. The chances are shown on the wheel.",
			Color = Colors.Pink,
			Icon = "wheel",
			Glyph = "x" .. tostring(product.Count),
			Buttons = {
				if offer
					then {
						Text = robux(offer.Price),
						Color = Colors.Green,
						OnClick = function()
							request("Spins" .. key, "BuySpins", key)
						end,
					}
					else studioPlaceholder(),
			},
		})
	end
end

local PAGES: { [string]: (ScrollingFrame) -> () } = {
	Speed = treadmillPage,
	Trails = trailsPage,
	Passes = passesPage,
	Items = itemsPage,
}

local function update()
	for _, fn in updaters do
		fn()
	end
	local currentUi = ui
	if currentUi then
		currentUi.Money.Text = Format.Money(num("Money"))
	end
end

-- Refait la page affichée
local function draw()
	local currentUi = ui
	if not currentUi then
		return
	end
	local page = currentUi.Page
	for _, child in page:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	updaters = {}
	sectionOrder = 0
	local build: (ScrollingFrame) -> () = PAGES[current] or treadmillPage
	build(page)
	page.CanvasPosition = Vector2.zero
	update()
end
render = draw

-- ===================================================================== API

function ShopController.IsOpen(): boolean
	local currentUi = ui
	return currentUi ~= nil and currentUi.Panel.IsOpen()
end

function ShopController.Select(tab: string)
	local currentUi = ui
	if currentUi and PAGES[tab] then
		currentUi.Tabs.Select(tab)
	end
end

function ShopController.Open(tab: string?)
	local currentUi = ui
	if not currentUi then
		return
	end
	if tab and PAGES[tab] then
		current = tab
	end
	currentUi.Panel.Open()
	currentUi.Tabs.Select(current)
	task.spawn(load)
end

function ShopController.Close()
	local currentUi = ui
	if currentUi then
		currentUi.Panel.Close()
	end
end

function ShopController.Toggle(tab: string?)
	if ShopController.IsOpen() then
		ShopController.Close()
	else
		ShopController.Open(tab)
	end
end

-- ===================================================================== cycle de vie

function ShopController.Init()
	local _, root = UIKit.Root("Menus", 7)
	local panel = UIKit.panel(root, "Shop", Colors.Green, PANEL)
	local content = panel.Content
	local money = text({
		Name = "Money",
		Size = UDim2.new(0, 260, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Colors.GreenText,
		Text = "$0",
		Parent = panel.HeaderRight,
	})
	local entries = {
		{ Name = "Speed", Color = Colors.Cyan, Icon = "speed" },
		{ Name = "Trails", Color = Colors.Orange, Icon = "star" },
		{ Name = "Passes", Color = Colors.Robux, Icon = "crown" },
		{ Name = "Items", Color = Colors.Pink, Icon = "bag" },
	}
	local page = UIKit.scroll({
		Name = "Page",
		Position = UDim2.fromOffset(SIDE + 14, 0),
		Size = UDim2.new(1, -(SIDE + 14), 1, 0),
		ZIndex = Z,
		Parent = content,
	})
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	local tabs = UIKit.tabs(content, entries, function(name: string)
		current = name
		draw()
	end, {
		Vertical = true,
		ButtonSize = UDim2.fromOffset(SIDE, TAB_H),
		Size = UDim2.fromOffset(SIDE, 4 * TAB_H + 3 * 8),
		ZIndex = Z,
	})
	-- (icône du pack à gauche de chaque onglet, nom à droite)
	for _, entry in entries do
		local button = tabs.Buttons[entry.Name]
		UIKit.icon(entry.Icon, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, -2),
			Size = UDim2.fromOffset(TAB_H - 24, TAB_H - 24),
			ZIndex = button.ZIndex + 3,
			Parent = button,
		})
		local label = button:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			label.AnchorPoint = Vector2.new(0, 0.5)
			label.Position = UDim2.new(0, TAB_H - 10, 0.47, 0)
			label.Size = UDim2.new(1, -(TAB_H - 4), 0.56, 0)
		end
	end
	ui = { Panel = panel, Tabs = tabs, Page = page, Money = money }

	for _, key in { "Money", "Trails", "BearTraps", "InstantCredits", "TreadmillRate" } do
		ReplicaController.Observe(key, function()
			if ShopController.IsOpen() then
				update()
			end
		end)
	end
	for _, key in { "Passes", "TreadmillLevel", "Spins" } do
		ReplicaController.Observe(key, function()
			reload()
		end)
	end
end

function ShopController.Start()
	-- (minuteur du Server Luck)
	while true do
		task.wait(1)
		if ShopController.IsOpen() then
			update()
		end
	end
end

return ShopController
