--!strict
-- Menu d'admin : un bouton « Admin » à droite des boutons Shop / Index, visible seulement pour les admins (attribut
-- « Admin » du joueur, posé par AdminService). Le menu donne des boutons pour les commandes d'admin du serveur ;
-- chaque bouton appelle le remote Admin (nom, arguments), et le serveur vérifie le droit à chaque fois. Le client ne
-- décide rien : un joueur normal qui ouvrirait le menu n'obtiendrait que « Not allowed ».
-- Pages : Player (argent, vitesse, treadmill, objets, tutoriel, remise à zéro), Dinos (donner un dino avec taille et
-- mutation, hybrides, blocs fossiles), World (téléportation, gisements, bloc rare, gardiens), Console (toutes les
-- commandes en texte). Cible : bouton en haut à droite (« Me » ou un autre joueur du serveur).
-- API : AdminController.Open(page?), Close(), Toggle(), IsOpen(), Run(nom, arguments) -> (ok, texte),
-- SetTarget(nom du joueur | nil), Target() -> argument joueur des commandes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local AdminController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local Z = 23
local PANEL = Vector2.new(1000, 600)
local SIDE = 170
local BUTTON = Vector2.new(140, 46)
local PER_ROW = 5
local OUTPUT_HEIGHT = 40
local CONFIRM_TIME = 4 -- secondes pour appuyer une deuxième fois sur un bouton dangereux
local LOG_LINES = 40

local PAGES = {
	{ Name = "Player", Color = Colors.Green },
	{ Name = "Dinos", Color = Colors.Orange },
	{ Name = "World", Color = Colors.Blue },
	{ Name = "Console", Color = Colors.Purple },
}

type Item = {
	Text: string,
	Color: Color3?,
	Click: (button: TextButton) -> (),
}

type Ui = {
	Panel: UIKit.Panel,
	Tabs: UIKit.Tabs,
	Pages: { [string]: GuiObject },
	Output: TextLabel,
	Target: TextButton,
	Open: TextButton,
	Log: ScrollingFrame,
	Input: TextBox,
}

local ui: Ui? = nil
local target: string? = nil -- nom du joueur visé (nil : soi-même)
local logOrder = 0

-- ===================================================================== commandes

-- Argument « joueur » des commandes : « me » ou le nom du joueur visé
function AdminController.Target(): string
	if target and Players:FindFirstChild(target) then
		return target
	end
	return "me"
end

function AdminController.SetTarget(name: string?)
	target = if name and name ~= Players.LocalPlayer.Name then name else nil
	local current = ui
	if current then
		current.Target.Text = "Target: " .. (target or "Me")
	end
end

local function addLog(text: string, ok: boolean)
	local current = ui
	if not current then
		return
	end
	logOrder += 1
	UIKit.label({
		Name = "Line",
		Body = true,
		LayoutOrder = logOrder,
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if ok then Colors.GreenText else Colors.Tomato,
		Text = text,
		ZIndex = Z + 1,
		Parent = current.Log,
	})
	local lines = {}
	for _, child in current.Log:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #lines - LOG_LINES do
		lines[index]:Destroy()
	end
	-- (défile jusqu'en bas une fois la nouvelle ligne placée)
	local log = current.Log
	task.defer(function()
		log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y))
	end)
end

-- Lance une commande d'admin sur le serveur et montre la réponse (barre du bas, journal de la console, message court)
function AdminController.Run(name: string, args: { string }?): (boolean, string)
	local called, ok, message = pcall(function()
		return Remotes.Function("Admin"):InvokeServer(name, args or {})
	end)
	local success = called and ok == true
	local text = if called and type(message) == "string" and message ~= "" then message else (if success then "Done" else "Try again")
	local current = ui
	if current then
		-- (la barre du bas montre la première ligne : « help » en a beaucoup, le journal les garde toutes)
		current.Output.Text = string.match(text, "^[^\n]*") or text
		current.Output.TextColor3 = if success then Colors.GreenText else Colors.Tomato
	end
	addLog("> " .. name .. (if args and #args > 0 then " " .. table.concat(args, " ") else "") .. "\n" .. text, success)
	if not string.find(text, "\n", 1, true) then
		UIKit.toast(text, if success then "success" else "error", 2)
	end
	return success, text
end

-- Lance la commande dans son propre fil (un bouton ne bloque pas l'interface pendant l'appel)
local function run(name: string, args: { string }?)
	task.spawn(AdminController.Run, name, args)
end

-- ===================================================================== construction

-- Section « -- TITRE -- » et ses boutons (5 par ligne) dans une page qui défile
local function section(page: GuiObject, title: string, color: Color3, items: { Item }, order: number)
	local rows = math.max(1, math.ceil(#items / PER_ROW))
	local frame: Frame = new("Frame", {
		Name = title,
		LayoutOrder = order,
		Size = UDim2.new(1, -14, 0, 38 + rows * (BUTTON.Y + 8)),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = page,
	})
	UIKit.sectionTitle({ Text = title, Color = color, Size = UDim2.new(1, 0, 0, 34), ZIndex = Z, Parent = frame })
	local grid: Frame = new("Frame", {
		Name = "Buttons",
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = frame,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, item in items do
		local button: TextButton
		button = UIKit.button({
			Name = item.Text,
			Text = item.Text,
			Color = item.Color or Colors.SlateLight,
			LayoutOrder = index,
			Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			MaxTextSize = 22,
			ZIndex = Z,
			Parent = grid,
		}, function()
			item.Click(button)
		end)
	end
end

local function page(content: GuiObject, name: string): ScrollingFrame
	local scroll = UIKit.scroll({
		Name = name,
		Position = UDim2.fromOffset(SIDE + 14, 0),
		Size = UDim2.new(1, -(SIDE + 14), 1, -(OUTPUT_HEIGHT + 8)),
		Visible = false,
		ZIndex = Z,
		Parent = content,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), Parent = scroll })
	return scroll
end

-- Bouton qui passe à la valeur suivante à chaque appui (« Size: Big ») ; renvoie l'élément et la valeur choisie
local function cycler(label: string, values: { string }, start: number?): (Item, () -> string)
	local index = start or 1
	local item: Item = {
		Text = label .. ": " .. values[index],
		Color = Colors.Slate,
		Click = function(button: TextButton)
			index = index % #values + 1
			button.Text = label .. ": " .. values[index]
		end,
	}
	return item, function(): string
		return values[index]
	end
end

-- Bouton dangereux : le premier appui demande une confirmation (« Sure? »), le deuxième lance l'action
local function confirmed(text: string, action: () -> ()): Item
	local armedUntil = 0
	return {
		Text = text,
		Color = Colors.Tomato,
		Click = function(button: TextButton)
			if os.clock() < armedUntil then
				armedUntil = 0
				button.Text = text
				action()
				return
			end
			armedUntil = os.clock() + CONFIRM_TIME
			button.Text = "Sure? Again!"
			task.delay(CONFIRM_TIME, function()
				if os.clock() >= armedUntil and button.Parent then
					button.Text = text
				end
			end)
		end,
	}
end

local function act(text: string, color: Color3?, name: string, args: () -> { string }): Item
	return {
		Text = text,
		Color = color,
		Click = function()
			run(name, args())
		end,
	}
end

local function rarityNames(): { string }
	return table.clone(Config.Rarity.Order)
end

local function zoneNames(): { string }
	local names = {}
	for _, zone in Config.Zones.List do
		table.insert(names, zone.Name)
	end
	return names
end

local function zoneIndex(name: string): string
	local zone = Config.Zones.ByName[name]
	return tostring(if zone then zone.Index else 1)
end

local function buildPlayer(scroll: ScrollingFrame)
	local me = AdminController.Target
	local function give(amount: string): () -> { string }
		return function()
			return { amount, me() }
		end
	end
	local order = 0
	local function add(title: string, color: Color3, items: { Item })
		order += 1
		section(scroll, title, color, items, order)
	end
	add("MONEY", Colors.Money, {
		act("+$1K", Colors.Money, "money", give("1000")),
		act("+$1M", Colors.Money, "money", give("1e6")),
		act("+$1B", Colors.Money, "money", give("1e9")),
		act("+$1T", Colors.Money, "money", give("1e12")),
		act("+$1Qd", Colors.Money, "money", give("1e15")),
		act("Set $0", Colors.SlateLight, "money", give("=0")),
	})
	add("SPEED", Colors.Cyan, {
		act("+100", Colors.Cyan, "speed", give("100")),
		act("+1K", Colors.Cyan, "speed", give("1000")),
		act("+10K", Colors.Cyan, "speed", give("10000")),
		act("+100K", Colors.Cyan, "speed", give("100000")),
		act("+1M", Colors.Cyan, "speed", give("1e6")),
		act("Set 0", Colors.SlateLight, "speed", give("=0")),
	})
	add("TREADMILL (STUDIO)", Colors.Yellow, {
		act("Level 0", nil, "treadmill", give("0")),
		act("Level 10", nil, "treadmill", give("10")),
		act("Level 25", nil, "treadmill", give("25")),
		act("Level 50", nil, "treadmill", give("50")),
	})
	add("ITEMS", Colors.Purple, {
		act("+10 Spins", Colors.Purple, "spins", give("10")),
		act("+5 Traps", Colors.Purple, "traps", give("5")),
		act("Finish Tanks", Colors.Purple, "finishtanks", function()
			return { me() }
		end),
		act("Protect On", nil, "protection", give("on")),
		act("Protect Off", nil, "protection", give("off")),
	})
	add("NEW PLAYER", Colors.Orange, {
		act("Tutorial 0", nil, "tutorial", give("0")),
		act("Tutorial Done", nil, "tutorial", give("3")),
		act("Daily Reset", nil, "dailyreset", function()
			return { me() }
		end),
		act("+30 Min Play", nil, "playtime", give("30")),
	})
	add("MOVE", Colors.Blue, {
		act("Go To Target", Colors.Blue, "goto", function()
			return { me() }
		end),
		act("Bring Target", Colors.Blue, "bring", function()
			return { me() }
		end),
	})
	add("DANGER", Colors.Tomato, {
		confirmed("Reset Data", function()
			run("resetdata", { me(), "confirm" })
		end),
	})
end

local function buildDinos(content: GuiObject): GuiObject
	local holder: Frame = new("Frame", {
		Name = "Dinos",
		Position = UDim2.fromOffset(SIDE + 14, 0),
		Size = UDim2.new(1, -(SIDE + 14), 1, -(OUTPUT_HEIGHT + 8)),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = Z,
		Parent = content,
	})
	local LIST = 236
	-- espèces, rangées par zone (puis les Secrets)
	local list = UIKit.scroll({
		Name = "Species",
		Size = UDim2.new(0, LIST, 1, 0),
		ZIndex = Z,
		Parent = holder,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = list })
	local right = UIKit.scroll({
		Name = "Options",
		Position = UDim2.fromOffset(LIST + 12, 0),
		Size = UDim2.new(1, -(LIST + 12), 1, 0),
		ZIndex = Z,
		Parent = holder,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), Parent = right })

	local chosen = ""
	local buttons: { [string]: TextButton } = {}
	local function choose(name: string)
		chosen = name
		for species, button in buttons do
			button:SetAttribute("Tint", if species == name then Colors.Orange else Colors.Slate)
		end
	end
	local order = 0
	local function header(text: string)
		order += 1
		UIKit.label({
			Name = text,
			LayoutOrder = order,
			Size = UDim2.new(1, -14, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Colors.Yellow,
			Text = text,
			MaxTextSize = 22,
			ZIndex = Z,
			Parent = list,
		})
	end
	local function speciesButton(name: string)
		order += 1
		buttons[name] = UIKit.button({
			Name = name,
			Text = name,
			Color = Colors.Slate,
			LayoutOrder = order,
			Size = UDim2.new(1, -14, 0, 38),
			MaxTextSize = 20,
			ZIndex = Z,
			Parent = list,
		}, function()
			choose(name)
		end)
	end
	local secrets = {}
	for _, zone in Config.Zones.List do
		header(zone.Name)
		for _, def in Config.Species.List do
			if def.Zone == zone.Name and not def.Secret then
				speciesButton(def.Name)
			end
		end
	end
	for _, def in Config.Species.List do
		if def.Secret then
			table.insert(secrets, def.Name)
		end
	end
	if #secrets > 0 then
		header("Secret")
		for _, name in secrets do
			speciesButton(name)
		end
	end
	local first = Config.Species.List[1]
	if first then
		choose(first.Name)
	end

	local sizes = {}
	for _, size in Config.Economy.Sizes do
		table.insert(sizes, size.Name)
	end
	local mutations = { "none" }
	for _, info in Config.Economy.Mutations do
		table.insert(mutations, info.Name)
	end
	local sizeItem, size = cycler("Size", sizes, math.max(1, table.find(sizes, "Normal") or 1))
	local mutationItem, mutation = cycler("Mut", mutations)
	local rarityItem, rarity = cycler("Rarity", rarityNames(), 3)
	local zoneItem, zone = cycler("Zone", zoneNames())
	local sections = 0
	local function add(title: string, color: Color3, items: { Item })
		sections += 1
		section(right, title, color, items, sections)
	end
	add("GIVE DINO", Colors.Orange, {
		sizeItem,
		mutationItem,
		{
			Text = "GIVE DINO",
			Color = Colors.Green,
			Click = function()
				if chosen ~= "" then
					run("givedino", { chosen, size(), mutation(), AdminController.Target() })
				end
			end,
		},
	})
	add("HYBRIDS", Colors.Purple, {
		{
			Text = "All Hybrids",
			Color = Colors.Purple,
			Click = function()
				run("givehybrid", { "all", size(), mutation(), AdminController.Target() })
			end,
		},
		act("Recipes", Colors.Purple, "hybrids", function()
			return { AdminController.Target() }
		end),
	})
	add("FOSSIL BLOCK", Colors.Cyan, {
		rarityItem,
		zoneItem,
		{
			Text = "GIVE BLOCK",
			Color = Colors.Green,
			Click = function()
				run("giveblock", { rarity(), zoneIndex(zone()), AdminController.Target() })
			end,
		},
	})
	return holder
end

local function buildWorld(scroll: ScrollingFrame)
	local order = 0
	local function add(title: string, color: Color3, items: { Item })
		order += 1
		section(scroll, title, color, items, order)
	end
	local teleports: { Item } = {
		act("Home", Colors.Green, "tpzone", function()
			return { "0" }
		end),
	}
	for _, zone in Config.Zones.List do
		local index = tostring(zone.Index)
		table.insert(teleports, act(zone.Name, UIKit.Lighten(zone.Color, 0.1), "tpzone", function()
			return { index }
		end))
	end
	add("TELEPORT", Colors.Blue, teleports)
	local rarityItem, rarity = cycler("Rarity", rarityNames(), table.find(Config.Rarity.Order, Config.Zones.Dig.AlertRarity) or 6)
	local zoneItem, zone = cycler("Zone", zoneNames())
	add("RARE SPAWN", Colors.Pink, {
		rarityItem,
		zoneItem,
		{
			Text = "SPAWN!",
			Color = Colors.Pink,
			Click = function()
				run("spawnrare", { rarity(), zoneIndex(zone()) })
			end,
		},
	})
	add("DIG SITES", Colors.Orange, {
		act("Refill All", Colors.Orange, "refill", function()
			return {}
		end),
		act("Return Blocks", nil, "returnblocks", function()
			return {}
		end),
	})
	add("GUARDIANS", Colors.Tomato, {
		act("Guardians On", Colors.Green, "guardians", function()
			return { "on" }
		end),
		act("Guardians Off", Colors.Tomato, "guardians", function()
			return { "off" }
		end),
	})
end

local function buildConsole(content: GuiObject): (GuiObject, ScrollingFrame, TextBox)
	local holder: Frame = new("Frame", {
		Name = "Console",
		Position = UDim2.fromOffset(SIDE + 14, 0),
		Size = UDim2.new(1, -(SIDE + 14), 1, -(OUTPUT_HEIGHT + 8)),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = Z,
		Parent = content,
	})
	local box = UIKit.card({
		Name = "InputCard",
		Color = Colors.SlateDark,
		Size = UDim2.new(1, -290, 0, 48),
		ZIndex = Z,
		Parent = holder,
	})
	local input: TextBox = new("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = UIKit.BodyFont,
		TextSize = 22,
		TextColor3 = Colors.Text,
		PlaceholderText = "givedino T-Rex Huge Galaxy me",
		PlaceholderColor3 = Colors.Disabled,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = Z + 3,
		Parent = box,
	})
	local function submit()
		local words = {}
		for word in string.gmatch(input.Text, "%S+") do
			table.insert(words, word)
		end
		if #words == 0 then
			return
		end
		local name = table.remove(words, 1) :: string
		input.Text = ""
		run(name, words)
	end
	UIKit.button({
		Name = "Run",
		Text = "RUN",
		Color = Colors.Green,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 0),
		Size = UDim2.fromOffset(130, 48),
		ZIndex = Z,
		Parent = holder,
	}, submit)
	UIKit.button({
		Name = "Help",
		Text = "HELP",
		Color = Colors.Purple,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(130, 48),
		ZIndex = Z,
		Parent = holder,
	}, function()
		run("help", {})
	end)
	input.FocusLost:Connect(function(enter: boolean)
		if enter then
			submit()
		end
	end)
	local logCard = UIKit.card({
		Name = "LogCard",
		Color = Colors.SlateDark,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, -10, 1, -58),
		ZIndex = Z,
		Parent = holder,
	})
	local log = UIKit.scroll({
		Name = "Log",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 1, -16),
		ZIndex = Z + 3,
		Parent = logCard,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = log })
	return holder, log, input
end

local function buildOpenButton(): TextButton
	local _, root = UIKit.Root("AdminButton", 3)
	-- (à droite du bouton Index du HUD : la colonne de gauche fait 196 de large depuis x = 16, son bas est à 43 au-dessus
	-- du milieu de l'écran, voir docs/UI.md)
	local button = UIKit.menuButton({
		Name = "Admin",
		Text = "",
		Icon = "hammer",
		Color = Colors.Tomato,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16 + 196 + 10, 0.5, -43),
		Size = UDim2.fromOffset(64, 64),
		Visible = false,
		Parent = root,
	}, function()
		AdminController.Toggle()
	end)
	return button
end

-- ===================================================================== API

function AdminController.IsOpen(): boolean
	local current = ui
	return current ~= nil and current.Panel.IsOpen()
end

function AdminController.Open(pageName: string?)
	local current = ui
	if not current or Players.LocalPlayer:GetAttribute("Admin") ~= true then
		return
	end
	if pageName and current.Pages[pageName] then
		current.Tabs.Select(pageName)
	end
	current.Panel.Open()
end

function AdminController.Close()
	local current = ui
	if current then
		current.Panel.Close()
	end
end

function AdminController.Toggle()
	if AdminController.IsOpen() then
		AdminController.Close()
	else
		AdminController.Open()
	end
end

-- Joueur suivant comme cible (Me, puis les autres joueurs du serveur par ordre de nom)
local function nextTarget()
	local names = {}
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			table.insert(names, player.Name)
		end
	end
	table.sort(names)
	local index = if target then table.find(names, target) else nil
	if index == nil then
		AdminController.SetTarget(names[1])
	else
		AdminController.SetTarget(names[index + 1])
	end
end

function AdminController.Init()
	local _, root = UIKit.Root("Menus", 7)
	local panel = UIKit.panel(root, "Admin", Colors.Tomato, PANEL)
	local content = panel.Content
	local targetButton = UIKit.button({
		Name = "Target",
		Text = "Target: Me",
		Color = Colors.Blue,
		Size = UDim2.fromOffset(240, 48),
		MaxTextSize = 24,
		ZIndex = 24,
		Parent = panel.HeaderRight,
	}, nextTarget)
	local output = UIKit.label({
		Name = "Output",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, SIDE + 14, 1, 0),
		Size = UDim2.new(1, -(SIDE + 14), 0, OUTPUT_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Every button runs on the server. Pick a target at the top right.",
		TextColor3 = Colors.Muted,
		MaxTextSize = 22,
		ZIndex = Z,
		Parent = content,
	})
	local pages: { [string]: GuiObject } = {}
	local player = page(content, "Player")
	buildPlayer(player)
	pages.Player = player
	pages.Dinos = buildDinos(content)
	local world = page(content, "World")
	buildWorld(world)
	pages.World = world
	local console, log, input = buildConsole(content)
	pages.Console = console
	local tabs = UIKit.tabs(content, PAGES, function(name: string)
		for key, frame in pages do
			frame.Visible = key == name
		end
	end, {
		Vertical = true,
		ButtonSize = UDim2.fromOffset(SIDE, 48),
		MaxTextSize = 24,
		Size = UDim2.fromOffset(SIDE, #PAGES * 56),
		ZIndex = Z,
	})
	local openButton = buildOpenButton()
	ui = {
		Panel = panel,
		Tabs = tabs,
		Pages = pages,
		Output = output,
		Target = targetButton,
		Open = openButton,
		Log = log,
		Input = input,
	}
	tabs.Select("Player")
	-- (le bouton n'apparaît que pour un admin ; un admin qui perd le droit voit le menu se fermer)
	local me = Players.LocalPlayer
	local function refresh()
		local admin = me:GetAttribute("Admin") == true
		openButton.Visible = admin
		if not admin and panel.IsOpen() then
			panel.Close()
		end
	end
	refresh()
	me:GetAttributeChangedSignal("Admin"):Connect(refresh)
	Players.PlayerRemoving:Connect(function(leaving: Player)
		if target == leaving.Name then
			AdminController.SetTarget(nil)
		end
	end)
end

return AdminController
