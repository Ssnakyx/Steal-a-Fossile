--!strict
-- Index (brief 12 « ui-ux », GDD : Index avec silhouettes des espèces et hybrides non découverts). Bouton Index du HUD.
-- Une page par zone de la route (+ Secret) : chaque espèce avec son portrait 3D, sa rareté et son revenu de base ;
-- une espèce pas encore découverte est une silhouette noire « ??? » (sa zone et sa rareté restent visibles).
-- Page Hybrids : les recettes du labo de fusion dans l'ordre de l'Index, avec l'indice tant que l'hybride n'est pas
-- découvert (le serveur n'envoie ni son nom ni ses parents avant).
-- État lu dans le Replica : « Index » (IndexService : { Species = { [espèce] = true }, Found, Total }) et « Hybrids »
-- (FusionService : { Total, Found, List }). Les portraits ne sont construits que pour la page affichée.
-- API : IndexController.Open(page?), Close(), Toggle(page?), IsOpen(), Unseen() -> découvertes pas encore vues (pastille).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DinoView = require(script.Parent.Parent.UI.DinoView)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local ReplicaController = require(script.Parent.ReplicaController)

local IndexController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local Z = 23
local PANEL = Vector2.new(1000, 600)
local SIDE = 170
local CARD = Vector2.new(180, 226)
local HYBRIDS = "Hybrids"
local SECRET = "Secret"

type Ui = {
	Panel: UIKit.Panel,
	Tabs: UIKit.Tabs,
	Title: TextLabel,
	Count: TextLabel,
	Grid: ScrollingFrame,
	Totals: TextLabel,
}

local ui: Ui? = nil
local current = ""
local views: { ViewportFrame } = {}
local seen: { [string]: boolean }? = nil -- découvertes déjà montrées (nil : pas encore d'état)

local function rankOf(rarity: string?): number
	local info = rarity and Config.Rarity.Info[rarity]
	return if info then info.Rank else 0
end

local function discovered(): { [string]: boolean }
	local index = ReplicaController.Get("Index")
	return if type(index) == "table" and type(index.Species) == "table" then index.Species else {}
end

local function hybrids(): { [string]: any }
	local value = ReplicaController.Get("Hybrids")
	return if type(value) == "table" then value else {}
end

-- Tout ce qui est découvert, sous forme de clés (« Species:T-Rex », « Hybrid:3 »)
local function discoveryKeys(): { [string]: boolean }
	local keys: { [string]: boolean } = {}
	for name in discovered() do
		keys["Species:" .. tostring(name)] = true
	end
	local list = hybrids().List
	if type(list) == "table" then
		for _, entry in list do
			if type(entry) == "table" and entry.Found == true then
				keys["Hybrid:" .. tostring(entry.Id)] = true
			end
		end
	end
	return keys
end

function IndexController.Unseen(): number
	local known = seen
	if not known then
		return 0
	end
	local count = 0
	for key in discoveryKeys() do
		if not known[key] then
			count += 1
		end
	end
	return count
end

local function markSeen()
	seen = discoveryKeys()
end

-- Espèces d'une page (zone ou Secret), de la plus commune à la plus rare
local function speciesOf(page: string): { any }
	local list = {}
	for _, def in Config.Species.List do
		local isSecret = def.Secret == true or def.Zone == SECRET
		if (page == SECRET and isSecret) or (page ~= SECRET and not isSecret and def.Zone == page) then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = rankOf(Config.Rarity.Species[a.Name]), rankOf(Config.Rarity.Species[b.Name])
		if ra ~= rb then
			return ra < rb
		end
		return a.Income < b.Income
	end)
	return list
end

-- ===================================================================== cartes

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 3
	return UIKit.label(props)
end

local function clearGrid(currentUi: Ui)
	for _, view in views do
		DinoView.Clear(view)
	end
	views = {}
	for _, child in currentUi.Grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function baseCard(currentUi: Ui, order: number, name: string, rarity: string?, found: boolean): Frame
	local card = UIKit.card({
		Name = name,
		Color = Colors.SlateDark,
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		ZIndex = Z,
		Parent = currentUi.Grid,
	})
	if rarity then
		UIKit.rarityTag(rarity, {
			Name = "Rarity",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 132),
			Size = UDim2.fromOffset(132, 26),
			ZIndex = Z + 2,
			Parent = card,
		})
	end
	if not found then
		new("Frame", {
			Name = "Locked",
			Size = UDim2.new(1, -8, 0, 124),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			ZIndex = Z + 1,
			Parent = card,
		})
	end
	return card
end

local function portrait(card: Frame, species: string, silhouette: boolean): ViewportFrame
	local view = DinoView.new({
		Name = "Portrait",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 120),
		ZIndex = Z + 2,
		Parent = card,
	})
	DinoView.Show(view, species, nil, silhouette)
	table.insert(views, view)
	return view
end

local function speciesCard(currentUi: Ui, order: number, def: any, found: boolean)
	local rarity = Config.Rarity.Species[def.Name]
	local card = baseCard(currentUi, order, def.Name, rarity, found)
	portrait(card, def.Name, not found)
	text({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 162),
		Size = UDim2.new(1, -14, 0, 28),
		Text = if found then def.Name else "???",
		Parent = card,
	})
	text({
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 192),
		Size = UDim2.new(1, -14, 0, 22),
		Text = if found then Format.Rate(def.Income) .. " base" else "Revive one to unlock",
		TextColor3 = if found then Colors.GreenText else Colors.Muted,
		Body = not found,
		MaxTextSize = 18,
		Parent = card,
	})
end

local function hybridCard(currentUi: Ui, order: number, entry: { [string]: any })
	local found = entry.Found == true
	local rarity = if found and type(entry.Rarity) == "string" then entry.Rarity else nil
	local card = baseCard(currentUi, order, "Hybrid" .. tostring(entry.Id), rarity, found)
	if found and type(entry.Key) == "string" then
		portrait(card, entry.Key, false)
	else
		text({
			Name = "Mystery",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 120),
			Text = "?",
			TextColor3 = Colors.Yellow,
			MaxTextSize = 90,
			Parent = card,
		})
	end
	text({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if found then 162 else 132),
		Size = UDim2.new(1, -14, 0, 28),
		Text = if found and type(entry.Name) == "string" then entry.Name else "???",
		Parent = card,
	})
	local info = if found
		then string.format("%s + %s", tostring(entry.Head or "?"), tostring(entry.Body or "?"))
		else (if type(entry.Hint) == "string" then entry.Hint else "")
	text({
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if found then 192 else 162),
		Size = UDim2.new(1, -14, 0, if found then 26 else 58),
		Text = info,
		TextWrapped = true,
		Body = true,
		MaxTextSize = if found then 16 else 15,
		TextColor3 = if found then Colors.GreenText else Colors.Muted,
		Parent = card,
	})
end

-- ===================================================================== pages

local function draw()
	local currentUi = ui
	if not currentUi or current == "" then
		return
	end
	clearGrid(currentUi)
	local foundCount, total = 0, 0
	if current == HYBRIDS then
		local state = hybrids()
		local list = if type(state.List) == "table" then state.List else {}
		for order, entry in list do
			if type(entry) == "table" then
				total += 1
				if entry.Found == true then
					foundCount += 1
				end
				hybridCard(currentUi, order, entry)
			end
		end
		currentUi.Title.Text = "HYBRIDS"
		currentUi.Title.TextColor3 = Colors.Purple
		if total == 0 then
			text({
				Name = "Empty",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(CARD.X * 4, 60),
				Text = "Fuse 2 different dinos in your lab to find hybrids!",
				TextColor3 = Colors.Muted,
				Parent = currentUi.Grid,
			})
		end
	else
		local known = discovered()
		for order, def in speciesOf(current) do
			total += 1
			local found = known[def.Name] == true
			if found then
				foundCount += 1
			end
			speciesCard(currentUi, order, def, found)
		end
		local zone = Config.Zones.ByName[current]
		currentUi.Title.Text = string.upper(current)
		currentUi.Title.TextColor3 = if zone then UIKit.Lighten(zone.Color, 0.35) else Colors.Pink
	end
	currentUi.Count.Text = string.format("Found %d/%d", foundCount, total)
	currentUi.Count.TextColor3 = if total > 0 and foundCount == total then Colors.GreenText else Colors.Text
	currentUi.Grid.CanvasPosition = Vector2.zero
	local index = ReplicaController.Get("Index")
	local state = hybrids()
	local speciesFound = if type(index) == "table" and type(index.Found) == "number" then index.Found else 0
	local speciesTotal = #Config.Species.List
	currentUi.Totals.Text = string.format("Dinos %d/%d   Hybrids %d/%d", speciesFound, speciesTotal, tonumber(state.Found) or 0, tonumber(state.Total) or 0)
end

-- ===================================================================== API

function IndexController.IsOpen(): boolean
	local currentUi = ui
	return currentUi ~= nil and currentUi.Panel.IsOpen()
end

function IndexController.Open(page: string?)
	local currentUi = ui
	if not currentUi then
		return
	end
	currentUi.Panel.Open()
	local target = if page and currentUi.Tabs.Buttons[page] then page elseif current ~= "" then current else Config.Zones.List[1].Name
	currentUi.Tabs.Select(target)
	markSeen()
end

function IndexController.Close()
	local currentUi = ui
	if currentUi then
		currentUi.Panel.Close()
	end
end

function IndexController.Toggle(page: string?)
	if IndexController.IsOpen() then
		IndexController.Close()
	else
		IndexController.Open(page)
	end
end

-- ===================================================================== cycle de vie

function IndexController.Init()
	local _, root = UIKit.Root("Menus", 7)
	local panel = UIKit.panel(root, "Index", Colors.Orange, PANEL)
	local content = panel.Content
	local totals = text({
		Name = "Totals",
		Size = UDim2.new(0, 360, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = panel.HeaderRight,
	})
	local entries = {}
	for _, zone in Config.Zones.List do
		table.insert(entries, { Name = zone.Name, Color = UIKit.Lighten(zone.Color, 0.1) })
	end
	table.insert(entries, { Name = SECRET, Color = Colors.Pink })
	table.insert(entries, { Name = HYBRIDS, Color = Colors.Purple })
	local right: Frame = new("Frame", {
		Name = "Page",
		Position = UDim2.fromOffset(SIDE + 14, 0),
		Size = UDim2.new(1, -(SIDE + 14), 1, 0),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = content,
	})
	local title = text({
		Name = "Title",
		Size = UDim2.new(0.6, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = right,
	})
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.new(0.4, -14, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = right,
	})
	local grid = UIKit.scroll({
		Name = "Grid",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		ZIndex = Z,
		Parent = right,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	-- (marge : le bord des cartes ne se coupe pas en haut)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = grid })
	local tabs = UIKit.tabs(content, entries, function(name: string)
		current = name
		draw()
	end, {
		Vertical = true,
		ButtonSize = UDim2.fromOffset(SIDE, 40),
		MaxTextSize = 22,
		Size = UDim2.new(0, SIDE, 1, 0),
		ZIndex = Z,
	})
	ui = { Panel = panel, Tabs = tabs, Title = title, Count = count, Grid = grid, Totals = totals }
	panel.OnClose = function()
		local currentUi = ui
		if currentUi then
			clearGrid(currentUi)
		end
	end
	for _, key in { "Index", "Hybrids" } do
		ReplicaController.Observe(key, function()
			if seen == nil and ReplicaController.IsReady() then
				markSeen()
			end
			if IndexController.IsOpen() then
				draw()
				markSeen()
			end
		end)
	end
end

return IndexController
