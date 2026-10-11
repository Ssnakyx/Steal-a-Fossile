--!strict
-- Menu du sérum de mutation (Config.Mutator, MutatorService) : s'ouvre avec le bouton MUTATE du labo de fusion.
--   * à gauche ses dinos (clé replica « Dinos ») : un clic en choisit un (« MAX » : il a déjà la meilleure mutation) ;
--   * à droite le dino choisi, les sérums en réserve, la chance de réussite et la chance de chaque mutation possible
--     (toute chance payante affiche ses probas), le bouton MUTATE! et l'achat d'un sérum avec l'argent du jeu.
-- Le serveur décide tout (MutateDino, BuySerums) ; ses textes d'erreur sont montrés tels quels. Le résultat (réussi ou
-- raté) passe par l'écran de révélation (RevealController, genre « Mutation »), puis le menu se rouvre.
-- API : MutatorController.Open(id?), Close(), IsOpen(), Selected() -> id?

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotifyController = require(script.Parent.NotifyController)
local ReplicaController = require(script.Parent.ReplicaController)
local RevealController = require(script.Parent.RevealController)

local MutatorController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local Z = 23
local PANEL = Vector2.new(1000, 600)
local LEFT = 560
local CARD = Vector2.new(130, 124)

type Dino = { Id: string, Species: string, Size: string, Mutation: string, Level: number, Income: number }
type Ui = {
	Panel: UIKit.Panel,
	Grid: ScrollingFrame,
	Empty: TextLabel,
	Title: TextLabel,
	Info: TextLabel,
	Odds: TextLabel,
	Serums: TextLabel,
	Mutate: TextButton,
	Buy: TextButton,
}

local ui: Ui? = nil
local picked: string? = nil
local cards: { [string]: TextButton } = {}
local busy = false
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
	-- (les meilleurs revenus d'abord : ce sont eux qui gagnent le plus à muter)
	table.sort(list, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Id < b.Id
	end)
	return list
end

local function find(id: string?): Dino?
	if not id then
		return nil
	end
	for _, dino in dinos() do
		if dino.Id == id then
			return dino
		end
	end
	return nil
end

local function serums(): number
	local value = ReplicaController.Get("Serums")
	return if type(value) == "number" then value else 0
end

local function price(): number
	local value = ReplicaController.Get("SerumPrice")
	return if type(value) == "number" then value else Config.Mutator.MinPrice
end

local function rarityOf(species: string): string
	local rarity = Config.Rarity.Species[species]
	return if type(rarity) == "string" then rarity else "Common"
end

local function percent(value: number): string
	local text = string.format(if value * 100 < 1 then "%.2f" else "%.0f", value * 100)
	return text .. "%"
end

local function multiplier(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return "x" .. text
end

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 3
	return UIKit.label(props)
end

-- « Big Amber Golden Compy »
local function displayName(dino: Dino): string
	local parts = {}
	if dino.Size ~= "Normal" then
		table.insert(parts, dino.Size)
	end
	if dino.Mutation ~= "" then
		table.insert(parts, dino.Mutation)
	end
	local level = Config.Economy.Levels[dino.Level + 1]
	if level and dino.Level > 0 then
		table.insert(parts, level.Name)
	end
	table.insert(parts, dino.Species)
	return table.concat(parts, " ")
end

-- Texte des probas : « Amber 35% (x1.5), Crystal 13% (x2)... »
function MutatorController.OddsText(current: string): string
	local parts = {}
	for _, odds in Config.Mutator.Odds(current) do
		table.insert(parts, string.format("%s %s (%s)", odds.Name, percent(odds.Chance), multiplier(odds.Income)))
	end
	return table.concat(parts, ", ")
end

-- ===================================================================== panneau de droite

local function refresh()
	local currentUi = ui
	if not currentUi then
		return
	end
	local count = serums()
	currentUi.Serums.Text = string.format("%s: %d", string.upper(Config.Mutator.Plural), count)
	currentUi.Buy.Text = "BUY 1 SERUM  " .. Format.Money(price())
	local dino = find(picked)
	if not dino then
		picked = nil
		currentUi.Title.Text = "PICK A DINO"
		currentUi.Title.TextColor3 = Colors.Yellow
		currentUi.Info.Text = string.format("A serum gives a dino a better mutation and more income. %d%% chance to work: if it fails, nothing changes but the serum is used.", Config.Mutator.SuccessChance)
		currentUi.Odds.Text = ""
		currentUi.Mutate:SetAttribute("Disabled", true)
	else
		local colors = UIKit.Rarity[rarityOf(dino.Species)] or UIKit.Rarity.Common
		currentUi.Title.Text = string.upper(displayName(dino))
		currentUi.Title.TextColor3 = colors.Tag
		if Config.Mutator.CanMutate(dino.Mutation) then
			currentUi.Info.Text = string.format(
				"%s now. %d%% chance to work. Fail: nothing changes, the serum is used.",
				Format.Rate(dino.Income),
				Config.Mutator.SuccessChance
			)
			currentUi.Odds.Text = "If it works: " .. MutatorController.OddsText(dino.Mutation)
			currentUi.Mutate:SetAttribute("Disabled", count < 1)
		else
			currentUi.Info.Text = "This dino already has the best mutation!"
			currentUi.Odds.Text = ""
			currentUi.Mutate:SetAttribute("Disabled", true)
		end
	end
	for id, card in cards do
		local glow = card:FindFirstChild("Glow")
		if glow and glow:IsA("GuiObject") then
			glow.Visible = id == picked
		end
	end
end

-- ===================================================================== cartes des dinos

local function dinoCard(currentUi: Ui, order: number, dino: Dino)
	local colors = UIKit.Rarity[rarityOf(dino.Species)] or UIKit.Rarity.Common
	local maxed = not Config.Mutator.CanMutate(dino.Mutation)
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
	}, { new("UIStroke", { Color = Config.Mutator.Color, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	text({
		Name = "Name",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 42),
		MaxTextSize = 30,
		Text = dino.Species,
		Parent = card,
	})
	local info = Config.Economy.Mutation(dino.Mutation)
	text({
		Name = "Mutation",
		Position = UDim2.fromOffset(6, 50),
		Size = UDim2.new(1, -12, 0, 22),
		Text = if maxed then "MAX" elseif info then string.upper(info.Name) else "NO MUTATION",
		TextColor3 = if info then info.Color else Colors.Muted,
		Parent = card,
	})
	text({
		Name = "Income",
		Position = UDim2.fromOffset(6, 76),
		Size = UDim2.new(1, -12, 0, 24),
		Text = Format.Rate(dino.Income),
		TextColor3 = Colors.GreenText,
		Parent = card,
	})
	UIKit.packHover(button)
	button.Activated:Connect(function()
		picked = dino.Id
		refresh()
	end)
	cards[dino.Id] = button
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
	refresh()
end

-- ===================================================================== actions

local function mutate()
	local currentUi = ui
	local id = picked
	if not currentUi or busy then
		return
	end
	if not id then
		NotifyController.Show("Pick a dino first.", "info")
		return
	end
	if serums() < 1 then
		NotifyController.Show("You need a " .. Config.Mutator.Name .. "! Buy one below.", "error")
		return
	end
	busy = true
	currentUi.Mutate.Text = "..."
	task.spawn(function()
		local called, ok, message, result = pcall(function()
			return Remotes.Function("MutateDino"):InvokeServer(id)
		end)
		busy = false
		currentUi.Mutate.Text = "MUTATE!"
		if not called then
			ok, message = false, "Try again"
		end
		if ok == true and type(result) == "table" then
			reopenAfterReveal = true
			MutatorController.Close()
			RevealController.Show(result, "Mutation")
		else
			NotifyController.Show(if type(message) == "string" then message else "Try again", "error")
		end
		refresh()
	end)
end

local function buy()
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local called, ok, message = pcall(function()
			return Remotes.Function("BuySerums"):InvokeServer(1)
		end)
		busy = false
		if not called then
			ok, message = false, "Try again"
		end
		NotifyController.Show(if type(message) == "string" then message else "Try again", if ok == true then "success" else "error")
		refresh()
	end)
end

-- ===================================================================== API

function MutatorController.Selected(): string?
	return picked
end

function MutatorController.IsOpen(): boolean
	local currentUi = ui
	return currentUi ~= nil and currentUi.Panel.IsOpen()
end

-- Ouvre le menu (avec un dino déjà choisi, facultatif)
function MutatorController.Open(id: string?)
	local currentUi = ui
	if not currentUi then
		return
	end
	if id then
		picked = id
	end
	currentUi.Panel.Open()
	drawGrid()
end

function MutatorController.Close()
	local currentUi = ui
	if currentUi then
		currentUi.Panel.Close()
	end
end

-- ===================================================================== cycle de vie

function MutatorController.Init()
	local _, root = UIKit.Root("Mutator", 7)
	local panel = UIKit.panel(root, "Mutation Lab", Config.Mutator.Color, PANEL)
	local content = panel.Content
	text({
		Name = "Mine",
		Size = UDim2.fromOffset(LEFT, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Yellow,
		Text = "PICK A DINO",
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
	local right: Frame = new("Frame", {
		Name = "Right",
		Position = UDim2.fromOffset(LEFT + 16, 0),
		Size = UDim2.new(1, -(LEFT + 16), 1, 0),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = content,
	})
	local result = UIKit.card({
		Name = "Result",
		Color = Colors.SlateDark,
		Accent = Config.Mutator.Color,
		Size = UDim2.new(1, -6, 0, 260),
		ZIndex = Z,
		Parent = right,
	})
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 36),
		Text = "",
		Parent = result,
	})
	local info = text({
		Name = "Info",
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 70),
		TextWrapped = true,
		Body = true,
		MaxTextSize = 19,
		Text = "",
		Parent = result,
	})
	local odds = text({
		Name = "Odds",
		Position = UDim2.fromOffset(12, 124),
		Size = UDim2.new(1, -24, 0, 128),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Body = true,
		MaxTextSize = 17,
		TextColor3 = Colors.Muted,
		Text = "",
		Parent = result,
	})
	UIKit.icon("gem", {
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = Z + 1,
		Parent = right,
	})
	local count = text({
		Name = "Serums",
		Position = UDim2.fromOffset(48, 272),
		Size = UDim2.new(1, -54, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Config.Mutator.Color,
		Text = "",
		Parent = right,
	})
	local mutateButton = UIKit.button({
		Name = "Mutate",
		Text = "MUTATE!",
		Color = Colors.Purple,
		Position = UDim2.fromOffset(0, 320),
		Size = UDim2.new(1, -6, 0, 72),
		MaxTextSize = 36,
		ZIndex = Z,
		Parent = right,
	}, mutate)
	local buyButton = UIKit.button({
		Name = "BuySerum",
		Text = "BUY 1 SERUM",
		Color = Colors.Green,
		Position = UDim2.fromOffset(0, 404),
		Size = UDim2.new(1, -6, 0, 56),
		MaxTextSize = 24,
		ZIndex = Z,
		Parent = right,
	}, buy)
	ui = {
		Panel = panel,
		Grid = grid,
		Empty = empty,
		Title = title,
		Info = info,
		Odds = odds,
		Serums = count,
		Mutate = mutateButton,
		Buy = buyButton,
	}
	ReplicaController.Observe("Dinos", function()
		if MutatorController.IsOpen() then
			drawGrid()
		end
	end)
	for _, key in { "Serums", "SerumPrice" } do
		ReplicaController.Observe(key, function()
			if MutatorController.IsOpen() then
				refresh()
			end
		end)
	end
	RevealController.Closed:Connect(function(kind: string)
		if kind == "Mutation" and reopenAfterReveal then
			reopenAfterReveal = false
			MutatorController.Open()
		end
	end)
end

return MutatorController
