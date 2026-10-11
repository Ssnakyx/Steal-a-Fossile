--!strict
-- Écran de révélation (brief 12 « ui-ux ») : quand un dino sort d'une cuve (DinoRevealed) ou du labo de fusion
-- (FusionController.Done), une carte montre le dino en 3D qui tourne, sa rareté, son nom, sa taille, sa mutation, son
-- niveau et son revenu, avec « NEW! » la première fois (espèce pas encore dans l'Index, hybride découvert à l'instant).
-- Le premier dino d'un nouveau joueur rappelle qu'il rapporte même hors ligne. La carte se ferme au clic ou toute seule ;
-- plusieurs révélations passent l'une après l'autre.
-- API : RevealController.Show(infos, genre) (genre : « Tank » ou « Fusion »), RevealController.Closed (signal : genre),
-- RevealController.IsOpen(), RevealController.Pending() -> nombre en attente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local DinoView = require(script.Parent.Parent.UI.DinoView)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local FusionController = require(script.Parent.FusionController)
local ReplicaController = require(script.Parent.ReplicaController)

local RevealController = {}
RevealController.Closed = Signal.new()

local Colors = UIKit.Colors
local Z = 23
local PANEL = Vector2.new(760, 470)
local AUTO_CLOSE = 7 -- secondes avant de se fermer tout seul
local MAX_QUEUE = 10

type Item = { Info: { [string]: any }, Kind: string, New: boolean, First: boolean }
type Ui = {
	Panel: UIKit.Panel,
	Title: TextLabel,
	Bar: ImageLabel,
	View: ViewportFrame,
	Tag: Frame,
	TagText: TextLabel,
	New: Frame,
	Name: TextLabel,
	Details: TextLabel,
	Income: TextLabel,
	Hint: TextLabel,
}

local ui: Ui? = nil
local queue: { Item } = {}
local showing: Item? = nil
local token = 0

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 3
	return UIKit.label(props)
end

local function knownSpecies(name: string): boolean
	local index = ReplicaController.Get("Index")
	if type(index) ~= "table" or type(index.Species) ~= "table" then
		return true -- (état pas encore reçu : pas de « NEW » au hasard)
	end
	return index.Species[name] == true
end

-- Nom affiché : « Big Amber Golden Compy »
local function displayName(info: { [string]: any }): string
	local parts = {}
	if type(info.Size) == "string" and info.Size ~= "Normal" then
		table.insert(parts, info.Size)
	end
	if type(info.Mutation) == "string" and info.Mutation ~= "" then
		table.insert(parts, info.Mutation)
	end
	local level = tonumber(info.Level) or 0
	local levelInfo = Config.Economy.Levels[level + 1]
	if level > 0 and levelInfo then
		table.insert(parts, levelInfo.Name)
	end
	table.insert(parts, tostring(info.Species))
	return table.concat(parts, " ")
end

local function paintHeader(currentUi: Ui, color: Color3)
	local tint = currentUi.Bar:FindFirstChild("Tint")
	if tint and tint:IsA("UIGradient") then
		tint.Color = ColorSequence.new(UIKit.Lighten(color, 0.3), UIKit.Darken(color, 0.06))
	end
end

local showNext: () -> ()

local function close()
	local currentUi = ui
	if currentUi and currentUi.Panel.IsOpen() then
		currentUi.Panel.Close()
	end
end

local function display(item: Item)
	local currentUi = ui
	if not currentUi then
		return
	end
	showing = item
	token += 1
	local myToken = token
	local info = item.Info
	local rarity = if type(info.Rarity) == "string" and UIKit.Rarity[info.Rarity] then info.Rarity else (Config.Rarity.Species[tostring(info.Species)] or "Common")
	local colors = UIKit.Rarity[rarity] or UIKit.Rarity.Common
	local hybrid = item.Kind == "Fusion" and info.Mode == "Hybrid"
	currentUi.Title.Text = if item.Kind == "Tank" then "NEW DINO!" elseif hybrid and item.New then "HYBRID DISCOVERED!" elseif hybrid then "HYBRID!" else "LEVEL UP!"
	paintHeader(currentUi, if colors.Rainbow then Colors.Pink else colors.Fill)
	currentUi.TagText.Text = string.upper(rarity)
	local tagFace = currentUi.Tag:FindFirstChild("Face")
	if tagFace then
		tagFace:SetAttribute("Tint", colors.Fill)
		tagFace:SetAttribute("Rainbow", colors.Rainbow == true)
	end
	currentUi.New.Visible = item.New
	currentUi.Name.Text = displayName(info)
	currentUi.Name.TextColor3 = colors.Tag
	local details = {}
	if type(info.Size) == "string" then
		table.insert(details, "Size: " .. info.Size)
	end
	table.insert(details, "Mutation: " .. (if type(info.Mutation) == "string" and info.Mutation ~= "" then info.Mutation else "None"))
	local levelInfo = Config.Economy.Levels[(tonumber(info.Level) or 0) + 1]
	if levelInfo then
		table.insert(details, "Level: " .. levelInfo.Name)
	end
	currentUi.Details.Text = table.concat(details, "\n")
	currentUi.Income.Text = Format.Rate(tonumber(info.Income) or 0)
	currentUi.Hint.Text = if item.First
		then "Your dinos make money for you, even when you're offline!"
		elseif item.Kind == "Tank" then "Added to your park!"
		else "It just came out of your lab!"
	local model = if type(info.Key) == "string" then info.Key else tostring(info.Species)
	local level = Config.Economy.Levels[(tonumber(info.Level) or 0) + 1]
	DinoView.Show(currentUi.View, model, {
		Size = if type(info.Size) == "string" then info.Size else nil,
		Mutation = if type(info.Mutation) == "string" and info.Mutation ~= "" then info.Mutation else nil,
		Level = if level then level.Name else nil,
	})
	currentUi.Panel.Open()
	task.delay(AUTO_CLOSE, function()
		if myToken == token and showing == item then
			close()
		end
	end)
end

showNext = function()
	local item = table.remove(queue, 1)
	if item then
		display(item)
	end
end

-- Montre une révélation (en file si une autre est déjà affichée)
function RevealController.Show(info: { [string]: any }, kind: string?)
	if type(info) ~= "table" or type(info.Species) ~= "string" then
		return
	end
	local mode = if kind == "Fusion" then "Fusion" else "Tank"
	local tutorial = tonumber(ReplicaController.Get("Tutorial"))
	local item: Item = {
		Info = info,
		Kind = mode,
		New = if mode == "Fusion" then info.New == true else not knownSpecies(info.Species),
		First = mode == "Tank" and tutorial ~= nil and tutorial < 3,
	}
	if #queue >= MAX_QUEUE then
		table.remove(queue, 1)
	end
	table.insert(queue, item)
	if not showing then
		showNext()
	end
end

function RevealController.IsOpen(): boolean
	local currentUi = ui
	return currentUi ~= nil and currentUi.Panel.IsOpen()
end

function RevealController.Pending(): number
	return #queue
end

-- ===================================================================== cycle de vie

function RevealController.Init()
	local _, root = UIKit.Root("Reveal", 8)
	local panel = UIKit.panel(root, "NEW DINO!", Colors.Yellow, PANEL)
	local header = panel.Frame:FindFirstChild("Header") :: Frame
	local title = header:FindFirstChild("Title") :: TextLabel
	local bar = header:FindFirstChild("Bar") :: ImageLabel
	title.Size = UDim2.fromScale(0.8, 0.64)
	local content = panel.Content
	local viewCard = UIKit.card({
		Name = "ViewCard",
		Color = Colors.SlateDark,
		Size = UDim2.fromOffset(320, 362),
		ZIndex = Z,
		Parent = content,
	})
	local view = DinoView.new({
		Name = "View",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		ZIndex = Z + 2,
		Parent = viewCard,
	})
	local x = 340
	local tag = UIKit.rarityTag("Common", {
		Name = "Rarity",
		Position = UDim2.fromOffset(x, 4),
		Size = UDim2.fromOffset(190, 40),
		ZIndex = Z + 1,
		Parent = content,
	})
	local tagText = tag:FindFirstChild("Text") :: TextLabel
	local newBadge = UIKit.card({
		Name = "New",
		Color = Colors.Tomato,
		Position = UDim2.fromOffset(x + 200, 4),
		Size = UDim2.fromOffset(110, 40),
		Visible = false,
		ZIndex = Z + 1,
		Parent = content,
	})
	text({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.7),
		Text = "NEW!",
		Parent = newBadge,
	})
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(x, 54),
		Size = UDim2.new(1, -x, 0, 74),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = content,
	})
	local details = text({
		Name = "Details",
		Position = UDim2.fromOffset(x, 134),
		Size = UDim2.new(1, -x, 0, 84),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Body = true,
		MaxTextSize = 22,
		TextColor3 = Colors.Muted,
		Text = "",
		Parent = content,
	})
	local income = text({
		Name = "Income",
		Position = UDim2.fromOffset(x, 222),
		Size = UDim2.new(1, -x, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.GreenText,
		Text = "",
		Parent = content,
	})
	local hint = text({
		Name = "Hint",
		Position = UDim2.fromOffset(x, 270),
		Size = UDim2.new(1, -x, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Body = true,
		MaxTextSize = 19,
		Text = "",
		Parent = content,
	})
	UIKit.button({
		Name = "Nice",
		Text = "NICE!",
		Color = Colors.Green,
		Position = UDim2.fromOffset(x, 306),
		Size = UDim2.new(1, -x, 0, 56),
		MaxTextSize = 30,
		ZIndex = Z + 1,
		Parent = content,
	}, close)
	ui = {
		Panel = panel,
		Title = title,
		Bar = bar,
		View = view,
		Tag = tag,
		TagText = tagText,
		New = newBadge,
		Name = name,
		Details = details,
		Income = income,
		Hint = hint,
	}
	panel.OnClose = function()
		local item = showing
		showing = nil
		local currentUi = ui
		if currentUi then
			DinoView.Clear(currentUi.View)
		end
		if item then
			RevealController.Closed:Fire(item.Kind)
		end
		if #queue > 0 then
			task.defer(showNext)
		end
	end

	Remotes.Event("DinoRevealed").OnClientEvent:Connect(function(_id: any, info: any)
		if type(info) == "table" then
			RevealController.Show(info, "Tank")
		end
	end)
	FusionController.Done:Connect(function(info: any)
		if type(info) == "table" then
			RevealController.Show(info, "Fusion")
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local currentUi = ui
		if currentUi and showing then
			DinoView.Spin(currentUi.View, dt)
		end
	end)
end

return RevealController
