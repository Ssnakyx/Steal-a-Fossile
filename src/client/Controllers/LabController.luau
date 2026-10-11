--!strict
-- Menu du labo de fusion (brief 12 « ui-ux », GDD : labo de fusion avec 2 ou 3 emplacements, aperçu « ??? » et indice).
-- S'ouvre quand le joueur utilise le labo de son parc (FusionController.LabOpened, prompt « Fuse ») :
--   * à gauche ses dinos (clé replica « Dinos »), rangés par espèce : un clic en choisit 2 ou 3 ;
--   * à droite les emplacements choisis, l'aperçu du résultat (« ??? » pour un hybride pas encore découvert), le prix,
--     le bouton Fuse, la règle des deux modes, « Auto pick » (3 dinos identiques) et un lien vers les hybrides de l'Index.
-- Le serveur décide tout (PreviewFusion, FuseDinos) ; ses textes d'erreur sont montrés tels quels. Une fusion réussie
-- montre l'écran de révélation (RevealController) puis rouvre le labo.
-- API : LabController.Open(), Close(), IsOpen(), Select(ids), Selected() -> ids.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DinoView = require(script.Parent.Parent.UI.DinoView)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local FusionController = require(script.Parent.FusionController)
local IndexController = require(script.Parent.IndexController)
local NotifyController = require(script.Parent.NotifyController)
local ReplicaController = require(script.Parent.ReplicaController)
local RevealController = require(script.Parent.RevealController)

local LabController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local Z = 23
local PANEL = Vector2.new(1000, 600)
local LEFT = 600
local CARD = Vector2.new(140, 150)
local MAX_PICK = 3
local PREVIEW_DELAY = 0.15

type Dino = { Id: string, Species: string, Size: string, Mutation: string, Level: number, Income: number }
type Slot = { Frame: Frame, Text: TextLabel, View: ViewportFrame, Shown: string }
type Ui = {
	Panel: UIKit.Panel,
	Grid: ScrollingFrame,
	Empty: TextLabel,
	Slots: { Slot },
	ResultTitle: TextLabel,
	ResultText: TextLabel,
	Cost: TextLabel,
	Fuse: TextButton,
	Auto: TextButton,
}

local ui: Ui? = nil
local picked: { string } = {}
local cards: { [string]: Frame } = {}
local previewToken = 0
local previewOk = false
local fusing = false
local reopenAfterReveal = false

local function dinos(): { Dino }
	local value = ReplicaController.Get("Dinos")
	local list: { Dino } = {}
	if type(value) ~= "table" then
		return list
	end
	for id, dino in value do
		if type(dino) == "table" and type(dino.Species) == "string" then
			table.insert(list, {
				Id = tostring(id),
				Species = dino.Species,
				Size = if type(dino.Size) == "string" then dino.Size else "Normal",
				Mutation = if type(dino.Mutation) == "string" then dino.Mutation else "",
				Level = if type(dino.Level) == "number" then dino.Level else 0,
				Income = if type(dino.Income) == "number" then dino.Income else 0,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Species ~= b.Species then
			return a.Species < b.Species
		end
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Id < b.Id
	end)
	return list
end

local function byId(): { [string]: Dino }
	local map = {}
	for _, dino in dinos() do
		map[dino.Id] = dino
	end
	return map
end

-- Rareté d'une espèce ou d'un hybride découvert
local function rarityOf(species: string): string
	local rarity = Config.Rarity.Species[species]
	if type(rarity) == "string" then
		return rarity
	end
	local state = ReplicaController.Get("Hybrids")
	if type(state) == "table" and type(state.List) == "table" then
		for _, entry in state.List do
			if type(entry) == "table" and entry.Name == species and type(entry.Rarity) == "string" then
				return entry.Rarity
			end
		end
	end
	return "Common"
end

local function levelName(level: number): string
	local info = Config.Economy.Levels[level + 1]
	return if info then info.Name else ""
end

-- « Big Amber » (taille et mutation, rien pour un dino Normal sans mutation)
local function traits(dino: Dino): string
	local parts = {}
	if dino.Size ~= "Normal" then
		table.insert(parts, dino.Size)
	end
	if dino.Mutation ~= "" then
		table.insert(parts, dino.Mutation)
	end
	return table.concat(parts, " ")
end

-- Portrait 3D d'un dino du joueur (taille, mutation et niveau comme en jeu)
local function showDino(view: ViewportFrame, dino: Dino): boolean
	local level = Config.Economy.Levels[dino.Level + 1]
	return DinoView.Show(view, dino.Species, {
		Size = if dino.Size ~= "" then dino.Size else nil,
		Mutation = if dino.Mutation ~= "" then dino.Mutation else nil,
		Level = if level then level.Name else nil,
	}, false, 0.62)
end

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 3
	return UIKit.label(props)
end

-- ===================================================================== aperçu

local function setResult(currentUi: Ui, title: string, body: string, color: Color3?, cost: number?)
	currentUi.ResultTitle.Text = title
	currentUi.ResultTitle.TextColor3 = color or Colors.Text
	currentUi.ResultText.Text = body
	currentUi.Cost.Text = if cost then "Cost: " .. Format.Money(cost) else ""
end

local function refreshSlots(currentUi: Ui)
	local map = byId()
	for index, slot in currentUi.Slots do
		local dino = map[picked[index] or ""]
		local face = slot.Frame:FindFirstChild("Face")
		-- (portrait refait seulement quand le dino de la case change)
		local key = if dino then dino.Id else ""
		if slot.Shown ~= key then
			slot.Shown = key
			if dino then
				slot.View.Visible = showDino(slot.View, dino)
			else
				DinoView.Clear(slot.View)
				slot.View.Visible = false
			end
		end
		if dino then
			local colors = UIKit.Rarity[rarityOf(dino.Species)] or UIKit.Rarity.Common
			-- (le nom ne s'affiche que si l'espèce n'a pas de modèle)
			slot.Text.Text = if slot.View.Visible then "" else dino.Species
			if face then
				face:SetAttribute("Tint", colors.Fill)
				face:SetAttribute("Rainbow", colors.Rainbow == true)
			end
		else
			slot.Text.Text = if index == MAX_PICK then "+ (3rd)" else "+"
			if face then
				face:SetAttribute("Tint", Colors.SlateDark)
				face:SetAttribute("Rainbow", false)
			end
		end
	end
	for id, card in cards do
		local order = table.find(picked, id)
		local glow = card:FindFirstChild("Glow")
		if glow and glow:IsA("GuiObject") then
			glow.Visible = order ~= nil
		end
		local number = card:FindFirstChild("Pick", true)
		if number and number:IsA("TextLabel") then
			number.Text = if order then tostring(order) else ""
		end
	end
end

local function preview()
	local currentUi = ui
	if not currentUi then
		return
	end
	previewToken += 1
	local token = previewToken
	previewOk = false
	currentUi.Fuse:SetAttribute("Disabled", true)
	if #picked < 2 then
		setResult(currentUi, "PICK DINOS", "Pick 2 different dinos for a hybrid, or 3 identical dinos to level up.", Colors.Yellow)
		return
	end
	setResult(currentUi, "...", "", Colors.Muted)
	local ids = table.clone(picked)
	task.delay(PREVIEW_DELAY, function()
		if token ~= previewToken then
			return
		end
		local called, ok, result = pcall(FusionController.Preview, ids)
		if not called then
			ok, result = false, "Try again"
		end
		if token ~= previewToken or ui ~= currentUi then
			return
		end
		if ok ~= true or type(result) ~= "table" then
			setResult(currentUi, "CAN'T FUSE", if type(result) == "string" then result else "Try again", Colors.Tomato)
			return
		end
		previewOk = true
		currentUi.Fuse:SetAttribute("Disabled", false)
		local mode = if result.Mode == "Upgrade" then "LEVEL UP" else "HYBRID"
		local cost = tonumber(result.Cost)
		if result.Known == true and type(result.Species) == "string" then
			local name = result.Species
			local level = tonumber(result.Level) or 0
			if level > 0 and type(result.LevelName) == "string" then
				name = result.LevelName .. " " .. name
			end
			local colors = UIKit.Rarity[if type(result.Rarity) == "string" then result.Rarity else rarityOf(result.Species)] or UIKit.Rarity.Common
			setResult(currentUi, string.upper(name), string.format("%s  -  %s", mode, Format.Rate(tonumber(result.Income) or 0)), colors.Tag, cost)
		else
			setResult(currentUi, Config.Fusion.UnknownName, mode .. "  -  Unknown recipe. Try it: if it fails, you keep your dinos!", Colors.Purple, cost)
		end
	end)
end

function LabController.Selected(): { string }
	return table.clone(picked)
end

function LabController.Select(ids: { string })
	picked = {}
	local map = byId()
	for _, id in ids do
		if map[id] and #picked < MAX_PICK and not table.find(picked, id) then
			table.insert(picked, id)
		end
	end
	local currentUi = ui
	if currentUi then
		refreshSlots(currentUi)
	end
	preview()
end

local function toggle(id: string)
	local index = table.find(picked, id)
	if index then
		table.remove(picked, index)
	elseif #picked >= MAX_PICK then
		NotifyController.Show("3 dinos at most! Tap one to remove it.", "info")
		return
	else
		table.insert(picked, id)
	end
	LabController.Select(picked)
end

-- 3 dinos identiques (même espèce, même niveau, pas au niveau maximal) : les meilleurs d'abord
local function autoPick(): { string }?
	local groups: { [string]: { Dino } } = {}
	local maxLevel = #Config.Economy.Levels - 1
	for _, dino in dinos() do
		if dino.Level < maxLevel then
			local key = dino.Species .. "#" .. dino.Level
			local group = groups[key] or {}
			groups[key] = group
			table.insert(group, dino)
		end
	end
	local best: { Dino }? = nil
	for _, group in groups do
		if #group >= Config.Fusion.UpgradeCount then
			table.sort(group, function(a, b)
				return a.Income > b.Income
			end)
			if not best or group[1].Income > best[1].Income then
				best = group
			end
		end
	end
	if not best then
		return nil
	end
	local ids = {}
	for index = 1, Config.Fusion.UpgradeCount do
		table.insert(ids, best[index].Id)
	end
	return ids
end

local function fuse()
	local currentUi = ui
	if not currentUi or fusing then
		return
	end
	if not previewOk then
		NotifyController.Show(if #picked < 2 then "Pick 2 or 3 dinos." else currentUi.ResultText.Text, "error")
		return
	end
	fusing = true
	currentUi.Fuse.Text = "..."
	local ids = table.clone(picked)
	task.spawn(function()
		local called, ok, message = pcall(FusionController.Fuse, ids)
		if not called then
			ok, message = false, "Try again"
		end
		fusing = false
		currentUi.Fuse.Text = "FUSE!"
		if ok == true then
			picked = {}
			reopenAfterReveal = true
			refreshSlots(currentUi)
			preview()
		else
			local textOut = if type(message) == "string" then message else "Try again"
			NotifyController.Show(textOut, "error")
			setResult(currentUi, "CAN'T FUSE", textOut, Colors.Tomato)
		end
	end)
end

-- ===================================================================== cartes des dinos

local function dinoCard(currentUi: Ui, order: number, dino: Dino)
	local rarity = rarityOf(dino.Species)
	local colors = UIKit.Rarity[rarity] or UIKit.Rarity.Common
	local button: TextButton = new("TextButton", {
		Name = "Dino" .. dino.Id,
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = Z,
		Parent = currentUi.Grid,
	})
	local card = UIKit.card({
		Name = "Card",
		Color = colors.Fill,
		Rainbow = colors.Rainbow,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Z,
		Parent = button,
	})
	new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = Z + 6,
		Parent = button,
	}, { new("UIStroke", { Color = Colors.Yellow, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	-- le dino lui-même en 3D, son nom en petit au-dessus
	local view = DinoView.new({
		Name = "View",
		Position = UDim2.fromOffset(4, 20),
		Size = UDim2.new(1, -8, 0, 82),
		ZIndex = Z + 2,
		Parent = card,
	})
	local hasModel = showDino(view, dino)
	view.Visible = hasModel
	text({
		Name = "Name",
		Position = UDim2.fromOffset(6, 4),
		Size = if hasModel then UDim2.new(1, -12, 0, 18) else UDim2.new(1, -12, 0, 80),
		MaxTextSize = if hasModel then 18 else 30,
		Text = dino.Species,
		ZIndex = Z + 3,
		Parent = card,
	})
	local level = levelName(dino.Level)
	text({
		Name = "Traits",
		Position = UDim2.fromOffset(6, 104),
		Size = UDim2.new(1, -12, 0, 18),
		Text = string.upper(if dino.Level > 0 then level .. " " .. traits(dino) else traits(dino)),
		TextColor3 = if dino.Level >= 2 then Colors.Cyan elseif dino.Level == 1 then Colors.Yellow else Colors.Muted,
		Parent = card,
	})
	text({
		Name = "Income",
		Position = UDim2.fromOffset(6, 124),
		Size = UDim2.new(1, -12, 0, 20),
		Text = Format.Rate(dino.Income),
		TextColor3 = Colors.GreenText,
		Parent = card,
	})
	text({
		Name = "Pick",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -4),
		Size = UDim2.fromOffset(30, 24),
		Text = "",
		TextColor3 = Colors.Yellow,
		Parent = card,
	})
	UIKit.packHover(button)
	button.Activated:Connect(function()
		toggle(dino.Id)
	end)
	cards[dino.Id] = button :: any
end

local function drawGrid()
	local currentUi = ui
	if not currentUi then
		return
	end
	for _, child in currentUi.Grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	cards = {}
	local list = dinos()
	for order, dino in list do
		dinoCard(currentUi, order, dino)
	end
	currentUi.Empty.Visible = #list == 0
	currentUi.Auto:SetAttribute("Disabled", autoPick() == nil)
	-- (dinos partis : fusionnés ou vendus)
	local still = {}
	local map = byId()
	for _, id in picked do
		if map[id] then
			table.insert(still, id)
		end
	end
	if #still ~= #picked then
		picked = still
		preview()
	end
	refreshSlots(currentUi)
end

-- ===================================================================== API

function LabController.IsOpen(): boolean
	local currentUi = ui
	return currentUi ~= nil and currentUi.Panel.IsOpen()
end

function LabController.Open()
	local currentUi = ui
	if not currentUi then
		return
	end
	currentUi.Panel.Open()
	drawGrid()
	preview()
end

function LabController.Close()
	local currentUi = ui
	if currentUi then
		currentUi.Panel.Close()
	end
end

-- ===================================================================== cycle de vie

local function buildRight(content: Frame): (Frame, { Slot }, TextLabel, TextLabel, TextLabel, TextButton, TextButton)
	local right: Frame = new("Frame", {
		Name = "Right",
		Position = UDim2.fromOffset(LEFT + 16, 0),
		Size = UDim2.new(1, -(LEFT + 16), 1, 0),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = content,
	})
	local slots = {}
	for index = 1, MAX_PICK do
		local slot = UIKit.card({
			Name = "Slot" .. index,
			Color = Colors.SlateDark,
			Position = UDim2.fromOffset((index - 1) * 120, 0),
			Size = UDim2.fromOffset(110, 84),
			ZIndex = Z,
			Parent = right,
		})
		local label = text({
			Name = "Text",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -12, 0, 52),
			MaxTextSize = 40,
			Text = "+",
			Parent = slot,
		})
		local view = DinoView.new({
			Name = "View",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
			Visible = false,
			ZIndex = Z + 2,
			Parent = slot,
		})
		table.insert(slots, { Frame = slot, Text = label, View = view, Shown = "" })
	end
	local result = UIKit.card({
		Name = "Result",
		Color = Colors.SlateDark,
		Accent = Colors.Purple,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, -6, 0, 150),
		ZIndex = Z,
		Parent = right,
	})
	local resultTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 38),
		Text = "",
		Parent = result,
	})
	local resultText = text({
		Name = "Text",
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 60),
		TextWrapped = true,
		Body = true,
		MaxTextSize = 20,
		Text = "",
		Parent = result,
	})
	local cost = text({
		Name = "Cost",
		Position = UDim2.fromOffset(12, 116),
		Size = UDim2.new(1, -24, 0, 26),
		TextColor3 = Colors.GreenText,
		Text = "",
		Parent = result,
	})
	local fuseButton = UIKit.button({
		Name = "Fuse",
		Text = "FUSE!",
		Color = Colors.Purple,
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.new(1, -6, 0, 72),
		MaxTextSize = 36,
		ZIndex = Z,
		Parent = right,
	}, fuse)
	local auto = UIKit.button({
		Name = "AutoPick",
		Text = "AUTO PICK 3",
		Color = Colors.Blue,
		Position = UDim2.fromOffset(0, 342),
		Size = UDim2.new(0.5, -10, 0, 52),
		MaxTextSize = 22,
		ZIndex = Z,
		Parent = right,
	}, function()
		local ids = autoPick()
		if ids then
			LabController.Select(ids)
		else
			NotifyController.Show("You need 3 identical dinos (same species, same level).", "info")
		end
	end)
	UIKit.button({
		Name = "Hybrids",
		Text = "HYBRIDS",
		Color = Colors.Orange,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 342),
		Size = UDim2.new(0.5, -10, 0, 52),
		MaxTextSize = 22,
		ZIndex = Z,
		Parent = right,
	}, function()
		IndexController.Open("Hybrids")
	end)
	text({
		Name = "Rules",
		Position = UDim2.fromOffset(0, 404),
		Size = UDim2.new(1, -6, 0, 90),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		Body = true,
		MaxTextSize = 19,
		TextColor3 = Colors.Muted,
		Text = "2 different dinos: HYBRID (secret recipes, check the hints in the Index).\n3 identical dinos: LEVEL UP (Golden, then Diamond).",
		Parent = right,
	})
	return right, slots, resultTitle, resultText, cost, fuseButton, auto
end

function LabController.Init()
	local _, root = UIKit.Root("Menus", 7)
	local panel = UIKit.panel(root, "Fusion Lab", Colors.Purple, PANEL)
	local content = panel.Content
	text({
		Name = "Mine",
		Size = UDim2.fromOffset(LEFT, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Yellow,
		Text = "YOUR DINOS",
		Parent = content,
	})
	local grid = UIKit.scroll({
		Name = "Grid",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0, LEFT, 1, -40),
		ZIndex = Z,
		Parent = content,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(6, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	-- (marge : le bord des cartes ne se coupe pas en haut)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = grid })
	local empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.fromOffset(LEFT - 20, 80),
		TextWrapped = true,
		Text = "No dinos yet! Revive fossils in your tanks first.",
		TextColor3 = Colors.Muted,
		Visible = false,
		Parent = content,
	})
	local _, slots, resultTitle, resultText, cost, fuseButton, auto = buildRight(content)
	-- (labo fermé : les portraits 3D sont retirés, ils sont refaits à l'ouverture)
	panel.OnClose = function()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		cards = {}
		for _, slot in slots do
			slot.Shown = ""
			DinoView.Clear(slot.View)
			slot.View.Visible = false
		end
	end
	ui = {
		Panel = panel,
		Grid = grid,
		Empty = empty,
		Slots = slots,
		ResultTitle = resultTitle,
		ResultText = resultText,
		Cost = cost,
		Fuse = fuseButton,
		Auto = auto,
	}
	FusionController.MenuReady = true
	FusionController.LabOpened:Connect(function()
		LabController.Open()
	end)
	ReplicaController.Observe("Dinos", function()
		if LabController.IsOpen() then
			drawGrid()
		end
	end)
	RevealController.Closed:Connect(function(kind: string)
		if kind == "Fusion" and reopenAfterReveal then
			reopenAfterReveal = false
			LabController.Open()
		end
	end)
end

return LabController
