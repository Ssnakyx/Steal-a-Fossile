--!strict
-- Shop (brief 12 « ui-ux », GDD : Monétisation, Vitesse et treadmill). Bouton Shop du HUD, quatre onglets :
--   * Speed   : treadmill (niveau, gain actuel, niveau suivant avec son gain et son prix réel lu sur Roblox), passe
--               x2 Treadmill, et un raccourci vers les trails ;
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
local PANEL = Vector2.new(1000, 600)
local SIDE = 170 -- largeur des onglets
local ROW_W = 772
local ROW_H = 96
local RELOAD_DELAY = 1.2 -- secondes entre deux GetShop (limite du serveur : 1 par seconde)
local STUDIO = RunService:IsStudio()

type ButtonSpec = { Text: string, Color: Color3, Disabled: boolean?, OnClick: (() -> ())? }
type RowSpec = {
	Name: string,
	Title: string,
	Subtitle: string,
	Color: Color3,
	Rainbow: boolean?,
	Glyph: string?,
	Height: number?,
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
		local ok, message = Remotes.Function(remote):InvokeServer(arg)
		busy[key] = nil
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
		return
	end
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

-- ===================================================================== lignes

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 2
	return UIKit.label(props)
end

-- Ligne du shop : case de couleur, titre, sous-titre, un ou deux boutons à droite. Renvoie la ligne et ses boutons.
local function row(page: ScrollingFrame, order: number, spec: RowSpec): (Frame, { TextButton }, TextLabel)
	local height = spec.Height or ROW_H
	local card = UIKit.card({
		Name = spec.Name,
		Color = Colors.SlateDark,
		LayoutOrder = order,
		Size = UDim2.fromOffset(ROW_W, height),
		ZIndex = Z,
		Parent = page,
	})
	local swatch = UIKit.card({
		Name = "Swatch",
		Color = spec.Color,
		Rainbow = spec.Rainbow,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(70, 70),
		ZIndex = Z + 1,
		Parent = card,
	})
	if spec.Glyph and spec.Glyph ~= "" then
		text({
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.82, 0.6),
			Text = spec.Glyph,
			ZIndex = Z + 5,
			Parent = swatch,
		})
	end
	local buttonsWidth = #spec.Buttons * 170 + math.max(0, #spec.Buttons - 1) * 10
	text({
		Name = "Title",
		Position = UDim2.fromOffset(98, 10),
		Size = UDim2.new(1, -(98 + buttonsWidth + 24), 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = spec.Title,
		Parent = card,
	})
	local subtitle = text({
		Name = "Subtitle",
		Position = UDim2.fromOffset(98, 46),
		Size = UDim2.new(1, -(98 + buttonsWidth + 24), 1, -54),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Body = true,
		MaxTextSize = 20,
		TextColor3 = Colors.Muted,
		Text = spec.Subtitle,
		Parent = card,
	})
	local buttons = {}
	for index, buttonSpec in spec.Buttons do
		local button = UIKit.button({
			Name = "Button" .. index,
			Text = buttonSpec.Text,
			Color = buttonSpec.Color,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12 - (#spec.Buttons - index) * 180, 0.5, 0),
			Size = UDim2.fromOffset(170, 64),
			MaxTextSize = 28,
			ZIndex = Z + 1,
			Parent = card,
		}, buttonSpec.OnClick)
		button:SetAttribute("Disabled", buttonSpec.Disabled == true)
		table.insert(buttons, button)
	end
	return card, buttons, subtitle
end

-- Petit titre de section dans la page
local function section(page: ScrollingFrame, order: number, title: string)
	text({
		Name = "Section" .. order,
		LayoutOrder = order,
		Size = UDim2.fromOffset(ROW_W, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Yellow,
		Text = title,
		Parent = page,
	})
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

local function passRow(page: ScrollingFrame, order: number, key: string, glyph: string, color: Color3): boolean
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
			Color = Colors.Robux,
			OnClick = function()
				if not owned() then
					request("Pass" .. key, "BuyPass", key)
				end
			end,
		}
		else studioPlaceholder()
	local _, buttons = row(page, order, {
		Name = key,
		Title = pass.Name,
		Subtitle = pass.Description,
		Color = color,
		Glyph = glyph,
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

local function productRow(page: ScrollingFrame, order: number, key: string, glyph: string, color: Color3, extra: (() -> string)?): boolean
	local product = Config.Shop.Products[key]
	local entry = onSaleList("Products")[key]
	if not product or (not entry and not STUDIO) then
		return false
	end
	local button: ButtonSpec = if entry
		then {
			Text = robux(entry.Price),
			Color = Colors.Robux,
			OnClick = function()
				request("Product" .. key, "BuyProduct", key)
			end,
		}
		else studioPlaceholder()
	local _, _, subtitle = row(page, order, {
		Name = key,
		Title = product.Name,
		Subtitle = product.Description,
		Color = color,
		Glyph = glyph,
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
	local button: ButtonSpec
	local subtitle: string
	if level >= maxLevel then
		button = { Text = "MAX", Color = Colors.Disabled, Disabled = true }
		subtitle = "Your treadmill is maxed out!"
	elseif nextInfo then
		button = {
			Text = robux(nextInfo.Price),
			Color = Colors.Robux,
			OnClick = function()
				request("Treadmill", "BuyTreadmill")
			end,
		}
		subtitle = string.format(
			"Level %d: +%s Speed/s (%s).",
			nextLevel,
			Format.Number(tonumber(nextInfo.Rate) or 0),
			times(nextInfo.Multiplier)
		)
	elseif STUDIO then
		button = studioPlaceholder()
		local multiplier = levels[nextLevel].Multiplier
		subtitle = string.format(
			"Level %d: +%s Speed/s (%s).",
			nextLevel,
			Format.Number(Config.Speed.Treadmill.BaseGain * multiplier),
			times(multiplier)
		)
	else
		button = { Text = "SOON", Color = Colors.Disabled, Disabled = true }
		subtitle = "More levels are coming soon!"
	end
	local title = if level <= 0 then "Treadmill (free)" else string.format("Treadmill  Level %d/%d", level, maxLevel)
	local _, _, sub = row(page, 1, {
		Name = "Treadmill",
		Title = title,
		Subtitle = "",
		Color = Colors.Cyan,
		Glyph = if level > 0 then tostring(level) else "AFK",
		Height = 132,
		Buttons = { button },
	})
	table.insert(updaters, function()
		local rate = num("TreadmillRate")
		sub.Text = string.format("Now: +%s Speed/s on your treadmill, even AFK!\nNext %s", Format.Number(rate), subtitle)
	end)
	passRow(page, 2, "DoubleTreadmill", "x2", Colors.Cyan)
	local _, _ = row(page, 3, {
		Name = "TrailsHint",
		Title = "Trails",
		Subtitle = "Trails add speed while you wear them. Cheap ones are bought with cash!",
		Color = Colors.Orange,
		Glyph = ">>",
		Buttons = {
			{
				Text = "SEE TRAILS",
				Color = Colors.Orange,
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
	local order = 0
	local robuxShown = false
	for _, id in ordered(Config.Speed.RobuxTrails) do
		local trail = Config.Speed.RobuxTrails[id]
		local pass = Config.Shop.Passes[trail.Pass]
		local entry = passes[trail.Pass]
		if not pass or (not entry and not STUDIO) then
			continue
		end
		if not robuxShown then
			robuxShown = true
			order += 1
			section(page, order, "SUPER TRAILS")
		end
		order += 1
		local button: ButtonSpec = if entry
			then {
				Text = robux(entry.Price),
				Color = Colors.Robux,
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
		local _, buttons = row(page, order, {
			Name = id,
			Title = trail.Name,
			Subtitle = string.format("%s Speed while you wear it, on top of your best cash trail.", times(pass.Multiplier)),
			Color = trail.Colors[1],
			Rainbow = id == "Galaxy",
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
					buy:SetAttribute("Tint", Colors.Robux)
					buy:SetAttribute("Disabled", false)
				end
			end)
		end
	end
	order += 1
	section(page, order, "CASH TRAILS")
	for _, id in ordered(Config.Speed.Trails) do
		local trail = Config.Speed.Trails[id]
		order += 1
		local _, buttons = row(page, order, {
			Name = id,
			Title = trail.Name,
			Subtitle = string.format("%s  -  +%s Speed while you wear it.", trail.Tier, Format.Number(trail.Speed)),
			Color = trail.Colors[1],
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
	local order = 0
	local glyphs: { [string]: { Glyph: string, Color: Color3 } } = {
		DoubleMoney = { Glyph = "x2", Color = Colors.Money },
		DoubleTreadmill = { Glyph = "x2", Color = Colors.Cyan },
		FastRevive = { Glyph = ">>", Color = Colors.Purple },
		VIP = { Glyph = "VIP", Color = Colors.Yellow },
	}
	for _, key in ordered(Config.Shop.Passes) do
		local pass = Config.Shop.Passes[key]
		if pass.Trail then
			continue -- (trails Robux : onglet Trails)
		end
		local look = glyphs[key] or { Glyph = "", Color = Colors.Robux }
		order += 1
		passRow(page, order, key, look.Glyph, look.Color)
	end
	if order == 0 or (not STUDIO and next(onSaleList("Passes")) == nil) then
		text({
			Name = "Empty",
			LayoutOrder = 99,
			Size = UDim2.fromOffset(ROW_W, 60),
			Text = "Passes are coming soon!",
			TextColor3 = Colors.Muted,
			Parent = page,
		})
	end
end

local function itemsPage(page: ScrollingFrame)
	local trap = Config.Pvp.Trap
	local _, buttons, trapSub = row(page, 1, {
		Name = "BearTraps",
		Title = "Bear Traps",
		Subtitle = "",
		Color = Colors.Orange,
		Glyph = "TRAP",
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
	productRow(page, 2, "BearTraps5", "x5", Colors.Orange)
	productRow(page, 3, "InstantRevive", "GO", Colors.Purple, function(): string
		local credits = math.floor(num("InstantCredits"))
		return if credits > 0 then string.format("(%d saved)", credits) else ""
	end)
	productRow(page, 4, "ServerLuck", "x2", Colors.Yellow, function(): string
		local endsAt = Workspace:GetAttribute("ServerLuckEndsAt")
		local left = if type(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() else 0
		return if left > 0 then "Active: " .. Format.Clock(left) .. " left!" else ""
	end)
	local order = 4
	local offers: { [string]: { [string]: any } } = {}
	for _, offer in spinOffers do
		if type(offer) == "table" and type(offer.Key) == "string" then
			offers[offer.Key] = offer
		end
	end
	local spins = ReplicaController.Get("Spins")
	local canBuy = type(spins) == "table" and spins.CanBuy == true
	for _, key in ordered(Config.Daily.Spins.Products) do
		local product = Config.Daily.Spins.Products[key]
		local offer = offers[key]
		if not offer and not (STUDIO and canBuy) then
			continue
		end
		order += 1
		row(page, order, {
			Name = key,
			Title = product.Name,
			Subtitle = "Spins for the Lucky Wheel. The chances are shown on the wheel.",
			Color = Colors.Purple,
			Glyph = tostring(product.Count),
			Buttons = {
				if offer
					then {
						Text = robux(offer.Price),
						Color = Colors.Robux,
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
		{ Name = "Speed", Color = Colors.Cyan },
		{ Name = "Trails", Color = Colors.Orange },
		{ Name = "Passes", Color = Colors.Robux },
		{ Name = "Items", Color = Colors.Pink },
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
		ButtonSize = UDim2.fromOffset(SIDE, 62),
		Size = UDim2.fromOffset(SIDE, 4 * 62 + 3 * 8),
		ZIndex = Z,
	})
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
