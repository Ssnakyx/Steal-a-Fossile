--!strict
-- Treadmill du parc (brief 4 « vitesse-treadmill ») : en courant dessus, ou AFK dessus, le joueur gagne de la vitesse
-- chaque seconde. Rien à regarder pendant. Sans achat, le tapis donne Config.Speed.Treadmill.FreeMultiplier x BaseGain
-- (tout le monde peut AFK dessus ; reconnexion AFK : AfkService).
-- Achat (Config.Shop.Treadmill.Levels), un niveau à la fois, le suivant du joueur seulement :
--   * avec l'argent du jeu (Cash) : déblocage à $1K, puis le prix monte. Remote BuyTreadmill() ou BuyTreadmill("Cash"),
--     ou le ProximityPrompt « Unlock ($1K) » / « Upgrade ($15K) » sur le tapis de son parc (panneau du prix au-dessus).
--   * en Robux : BuyTreadmill("Robux"), un produit développeur par niveau (caché tant que son Id = 0). Un reçu d'un
--     autre niveau n'est pas donné (Roblox le représente plus tard, et il passe quand il devient le niveau suivant).
--   Un achat Robux en cours du niveau suivant bloque l'achat en argent de ce niveau (sinon il serait payé deux fois).
-- Tapis : toute BasePart taguée « Treadmill » (CollectionService) dans le Workspace. Le joueur est dessus si son
-- HumanoidRootPart est au-dessus de la pièce (Config.Speed.Treadmill.Height). Si la pièce ou un de ses ancêtres (le
-- parc) a l'attribut OwnerUserId, seul ce joueur y gagne de la vitesse.
--   TreadmillService.Rate(player)           vitesse gagnée par seconde sur le tapis (gain gratuit sans treadmill)
--   TreadmillService.IsOnTreadmill(player)
--   TreadmillService.SetLevel(player, niveau)   fixe le niveau sans achat (admin Studio, FossilDebug)
--   TreadmillService.Buy(player, "Cash" | "Robux" | nil) -> (ok, texte)   achat du niveau suivant (comme le remote)
-- Signaux : TreadmillUpgraded(player, level)   niveau acheté et sauvegardé
-- Replica : TreadmillLevel, TreadmillRate. Attribut OnTreadmill sur le joueur (VFX, UI).
-- Modèle du tapis du parc : un par niveau (Map/Treadmills), refait à chaque niveau acheté, remis au niveau 0 quand le
-- propriétaire part. Course sur place et chaussures « +N » : côté client (TreadmillController).

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Format = require(ReplicatedStorage.Shared.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Signals = require(script.Parent.Parent.Lib.Signals)
local Treadmills = require(script.Parent.Parent.Map.Treadmills)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local MoneyService = require(script.Parent.MoneyService)
local PlotService = require(script.Parent.PlotService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)
local ShopService = require(script.Parent.ShopService)
local SpeedService = require(script.Parent.SpeedService)

type Pending = { Level: number, Since: number, Paid: boolean }
-- Tapis du parc du joueur : prompt d'achat et panneau du prix
type Station = { Prompt: ProximityPrompt, Gui: BillboardGui, Title: TextLabel, Price: TextLabel }

local TreadmillService = {}

local LEVELS = Shop.Treadmill.Levels
local MAX_LEVEL = #LEVELS
local KEY_PREFIX = "TreadmillLevel"

local players: { [Player]: boolean } = {}
local onBelt: { [Player]: boolean } = {}
local pending: { [Player]: Pending } = {}
local lastHint: { [Player]: number } = {}
local upsold: { [Player]: boolean } = {} -- rappel « achète le treadmill » déjà montré (gain gratuit)
local stations: { [Player]: Station } = {}
local dressed: { [BasePart]: number } = {} -- niveau du modèle posé autour de chaque tapis de parc
local beltOf: { [Player]: BasePart } = {}

local GREEN = Color3.fromRGB(110, 235, 120)
local GOLD = Color3.fromRGB(255, 215, 90)

local function keyFor(level: number): string
	return KEY_PREFIX .. tostring(level)
end

local function levelOf(player: Player): number
	local data = DataService.Get(player)
	return if data then data.TreadmillLevel else 0
end

-- Multiplicateur du niveau (0 = pas acheté : gain gratuit)
local function multiplierAt(level: number): number
	if level == 0 then
		return math.max(0, SpeedConfig.Treadmill.FreeMultiplier or 0)
	end
	local entry = LEVELS[level]
	return if entry then entry.Multiplier else 0
end

-- Vitesse par seconde au niveau donné (passe x2 Treadmill compris)
local function rateAt(player: Player, level: number): number
	local multiplier = multiplierAt(level)
	if multiplier <= 0 then
		return 0
	end
	return SpeedConfig.Treadmill.BaseGain * multiplier * ShopService.PassMultiplier(player, "DoubleTreadmill")
end

function TreadmillService.Rate(player: Player): number
	return rateAt(player, levelOf(player))
end

function TreadmillService.IsOnTreadmill(player: Player): boolean
	return onBelt[player] == true
end

-- Prompt et panneau du tapis : « Unlock ($1K) », « Upgrade ($15K) », puis MAX
local function updateStation(player: Player)
	local station = stations[player]
	if not station then
		return
	end
	local level = levelOf(player)
	local entry = LEVELS[level + 1]
	local verb = if level == 0 then "Unlock" else "Upgrade"
	station.Title.Text = string.format(
		"%s  +%s speed/s",
		if level == 0 then "Free" else "Lv " .. level,
		Format.Number(TreadmillService.Rate(player))
	)
	if entry then
		station.Prompt.ActionText = string.format("%s (%s)", verb, Format.Money(entry.Cash))
		station.Price.Text = string.format("%s: %s", verb, Format.Money(entry.Cash))
		station.Price.TextColor3 = GREEN
	else
		station.Prompt.ActionText = "Max level"
		station.Price.Text = "MAX LEVEL"
		station.Price.TextColor3 = GOLD
	end
	station.Prompt.ObjectText = if level == 0 then "Treadmill" else string.format("Treadmill Lv %d/%d", level, MAX_LEVEL)
	station.Prompt.Enabled = entry ~= nil
end

-- Modèle du tapis au niveau donné (Map/Treadmills), à la place de l'ancien ; rien si c'est déjà le bon
local function dress(belt: BasePart, level: number)
	local parent = belt.Parent
	if dressed[belt] == level or not parent then
		return
	end
	dressed[belt] = level
	local base = belt.CFrame * CFrame.new(0, -Treadmills.BeltY, 0)
	for _, child in parent:GetChildren() do
		if child.Name == Treadmills.ModelName and child:IsA("Model") then
			child:Destroy()
		end
	end
	Treadmills.Paint(belt, level)
	Treadmills.Build(level, base).Parent = parent
end

local function publish(player: Player)
	ReplicaService.Set(player, "TreadmillLevel", levelOf(player))
	ReplicaService.Set(player, "TreadmillRate", TreadmillService.Rate(player))
	updateStation(player)
	local plot = PlotService.Get(player)
	local belt = plot and plot.Treadmill
	if belt and players[player] then
		beltOf[player] = belt
		dress(belt, levelOf(player))
	end
end

function TreadmillService.SetLevel(player: Player, level: number): boolean
	local data = DataService.Get(player)
	local clean = Guard.Integer(level, 0, MAX_LEVEL)
	if not data or not clean then
		return false
	end
	data.TreadmillLevel = clean
	publish(player)
	return true
end

-- ===== tapis =====

-- Propriétaire du tapis : attribut OwnerUserId de la pièce ou d'un ancêtre (nil = tapis libre pour tous)
local function ownerOf(belt: Instance): number?
	local current: Instance? = belt
	while current and current ~= Workspace do
		local value = current:GetAttribute(SpeedConfig.Treadmill.OwnerAttribute)
		if type(value) == "number" then
			return value
		end
		current = current.Parent
	end
	return nil
end

local function isOn(belt: BasePart, position: Vector3): boolean
	local relative = belt.CFrame:PointToObjectSpace(position)
	local half = belt.Size / 2
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Z) <= half.Z
		and relative.Y >= -half.Y
		and relative.Y <= half.Y + SpeedConfig.Treadmill.Height
end

local function findBelt(player: Player, belts: { Instance }): BasePart?
	local root = Guard.Root(player)
	if not root then
		return nil
	end
	local position = root.Position
	for _, belt in belts do
		if belt:IsA("BasePart") and belt:IsDescendantOf(Workspace) then
			local owner = ownerOf(belt)
			if (owner == nil or owner == player.UserId) and isOn(belt, position) then
				return belt
			end
		end
	end
	return nil
end

local function setOnBelt(player: Player, on: boolean)
	if (onBelt[player] == true) ~= on then
		if on then
			onBelt[player] = true
		else
			onBelt[player] = nil
		end
		player:SetAttribute("OnTreadmill", on)
	end
end

-- Un tour du treadmill : chaque joueur sur son tapis gagne Rate x TickSeconds de vitesse
function TreadmillService.Tick()
	local seconds = SpeedConfig.Treadmill.TickSeconds
	local belts = CollectionService:GetTagged(SpeedConfig.Treadmill.Tag)
	for player in players do
		if player.Parent ~= Players then
			continue
		end
		local on = findBelt(player, belts) ~= nil
		setOnBelt(player, on)
		if not on then
			continue
		end
		local rate = TreadmillService.Rate(player)
		if rate > 0 then
			SpeedService.Add(player, rate * seconds, "Treadmill")
			if levelOf(player) == 0 and not upsold[player] then
				-- (gain gratuit : un seul rappel par visite, pour ne pas gêner un joueur AFK)
				upsold[player] = true
				local paid = multiplierAt(1)
				local free = multiplierAt(0)
				Notify.Send(
					player,
					string.format(
						"+%s speed/s here, even AFK! Unlock the Treadmill for %s to get x%s.",
						Format.Number(rate),
						Format.Money(LEVELS[1].Cash),
						Format.Number(paid / free)
					),
					"info"
				)
			end
		else
			local now = os.clock()
			if not lastHint[player] or now - lastHint[player] >= SpeedConfig.Treadmill.HintCooldown then
				lastHint[player] = now
				Notify.Send(player, "Unlock the Treadmill for " .. Format.Money(LEVELS[1].Cash) .. " to gain speed here!", "info")
			end
		end
	end
end

-- ===== achat =====

-- Niveau acheté (argent ou Robux) : message et signal
local function upgraded(player: Player, level: number)
	if player.Parent == Players then
		local rate = Format.Number(TreadmillService.Rate(player))
		if level == 1 then
			Notify.Send(player, "Treadmill unlocked! Run on it to gain +" .. rate .. " speed/s.", "success")
		else
			Notify.Send(player, string.format("Treadmill level %d! +%s speed/s.", level, rate), "success")
		end
	end
	Signals.Fire("TreadmillUpgraded", player, level)
end

-- Achat Robux du niveau suivant en cours (prompt ouvert depuis moins de PendingSeconds, ou payé mais pas encore donné,
-- par exemple pendant une panne de sauvegarde : bloqué jusqu'à ce que le niveau arrive, sinon il serait payé deux fois)
local function robuxPending(player: Player, level: number): boolean
	local waiting = pending[player]
	return waiting ~= nil and waiting.Level == level and (waiting.Paid or os.clock() - waiting.Since < Shop.Treadmill.PendingSeconds)
end

-- currency : nil ou "Cash" = argent du jeu, "Robux" = produit développeur
local function buy(player: Player, currency: any): (boolean, string)
	if currency ~= nil and currency ~= "Cash" and currency ~= "Robux" then
		return false, "Try again"
	end
	local data = DataService.Get(player)
	if not data or not players[player] then
		return false, "Please wait..."
	end
	local nextLevel: number = data.TreadmillLevel + 1
	if nextLevel > MAX_LEVEL then
		return false, "Your treadmill is maxed out!"
	end
	if robuxPending(player, nextLevel) then
		return false, "Purchase in progress..."
	end
	if currency ~= "Robux" then
		local price = LEVELS[nextLevel].Cash
		if not MoneyService.Spend(player, price, "Treadmill") then
			return false, "Not enough money! You need " .. Format.Money(price) .. "."
		end
		data.TreadmillLevel = nextLevel
		publish(player)
		upgraded(player, nextLevel)
		return true, ""
	end
	local key = keyFor(nextLevel)
	if not ReceiptService.IsOnSale(key) then
		return false, "Coming soon!"
	end
	pending[player] = { Level = nextLevel, Since = os.clock(), Paid = false }
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, LEVELS[nextLevel].Id)
	end)
	if not ok then
		pending[player] = nil
		return false, "Try again"
	end
	return true, ""
end

TreadmillService.Buy = buy

-- Contenu de la section « Treadmill » du shop
local function section(player: Player): { [string]: any }
	local level = levelOf(player)
	local nextLevel = level + 1
	local nextInfo = nil
	if nextLevel <= MAX_LEVEL then
		-- (Cash : prix en argent du jeu ; Price : prix Robux lu sur Roblox, seulement si le produit est en vente)
		nextInfo = {
			Level = nextLevel,
			Multiplier = LEVELS[nextLevel].Multiplier,
			Rate = rateAt(player, nextLevel),
			Cash = LEVELS[nextLevel].Cash,
			Price = if ReceiptService.IsOnSale(keyFor(nextLevel)) then ShopService.Price("Product", LEVELS[nextLevel].Id) else nil,
		}
	end
	return {
		Name = Shop.Treadmill.Name,
		Level = level,
		MaxLevel = MAX_LEVEL,
		Multiplier = multiplierAt(level),
		Rate = TreadmillService.Rate(player),
		Next = nextInfo,
	}
end

-- ===== cycle de vie =====

function TreadmillService.Init()
	for level, entry in LEVELS do
		ReceiptService.Register(keyFor(level), entry.Id, function(player, data)
			-- (seulement le niveau suivant : un autre reçu attend son tour, rien n'est perdu)
			if data.TreadmillLevel ~= level - 1 then
				return false
			end
			data.TreadmillLevel = level
			local waiting = pending[player]
			if waiting and waiting.Level <= level then
				pending[player] = nil
			end
			publish(player)
			return true
		end)
	end

	Signals.Connect("PurchaseGranted", function(player: Player, key: string)
		local digits = string.match(key, "^" .. KEY_PREFIX .. "(%d+)$")
		local level = if digits then tonumber(digits) else nil
		if level then
			upgraded(player, level)
		end
	end)

	local function passChanged(player: Player, key: string)
		if key == "DoubleTreadmill" and players[player] then
			publish(player)
		end
	end
	Signals.Connect("PassOwned", passChanged)
	Signals.Connect("PassLost", passChanged)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		local player = Players:GetPlayerByUserId(userId)
		local waiting = player and pending[player]
		if not (player and waiting and LEVELS[waiting.Level] and LEVELS[waiting.Level].Id == productId) then
			return
		end
		if purchased then
			waiting.Paid = true -- (le verrou tombe quand le niveau est donné)
		else
			pending[player] = nil
		end
	end)

	Net.Function("BuyTreadmill", { Rate = 1, Burst = 3 }, function(player: Player, currency: any)
		return buy(player, currency)
	end)
	ShopService.RegisterSection("Treadmill", section)

	AdminService.RegisterCommand("treadmill", {
		Description = "Set the treadmill level (Studio only)",
		Usage = "treadmill <0-" .. MAX_LEVEL .. "> [player]",
		Run = function(player, args)
			if not RunService:IsStudio() then
				return false, "Studio only"
			end
			local level = Guard.Integer(tonumber(args[1] or ""), 0, MAX_LEVEL)
			local target = AdminService.FindPlayer(player, args[2])
			if not target or not DataService.Get(target) then
				return false, "Player not found"
			end
			if not level then
				return false, "Level between 0 and " .. MAX_LEVEL
			end
			TreadmillService.SetLevel(target, level)
			return true, string.format("%s treadmill level %d (+%s speed/s)", target.Name, level, Format.Number(TreadmillService.Rate(target)))
		end,
	})
end

-- ===== tapis du parc : prompt d'achat et panneau du prix =====

local function label(name: string, position: UDim2, size: UDim2, color: Color3, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.2
	text.Parent = parent
	return text
end

local function createStation(player: Player)
	local plot = PlotService.Get(player)
	local belt = plot and plot.Treadmill
	if not belt or stations[player] then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TreadmillLabel"
	gui.Size = UDim2.fromScale(7, 2.6)
	-- (au-dessus du modèle du tapis, arche et emblème compris (Treadmills.Bounds), et de l'étiquette du guide des
	-- premières minutes, à +5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Treadmills.Bounds.Height - Treadmills.BeltY + 1.5, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	local title = label("Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.42), Color3.new(1, 1, 1), gui)
	local price = label("Price", UDim2.fromScale(0, 0.45), UDim2.fromScale(1, 0.55), GREEN, gui)
	gui.Parent = belt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TreadmillPrompt"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Triggered:Connect(function(who: Player)
		if who ~= player then
			Notify.Send(who, "This is not your park!", "error")
			return
		end
		if not RateLimit.Allow(player, "TreadmillPrompt", 2, 3) then
			return
		end
		local ok, text = buy(player, "Cash")
		if not ok then
			Notify.Send(player, text, "error")
		end
	end)
	prompt.Parent = belt
	stations[player] = { Prompt = prompt, Gui = gui, Title = title, Price = price }
end

function TreadmillService.Start()
	while true do
		task.wait(SpeedConfig.Treadmill.TickSeconds)
		TreadmillService.Tick()
	end
end

function TreadmillService.OnPlayerReady(player: Player)
	players[player] = true
	createStation(player)
	publish(player)
end

function TreadmillService.OnPlayerRemoving(player: Player)
	players[player] = nil
	onBelt[player] = nil
	pending[player] = nil
	lastHint[player] = nil
	upsold[player] = nil
	local station = stations[player]
	stations[player] = nil
	if station then
		station.Prompt:Destroy()
		station.Gui:Destroy()
	end
	-- (le parc se libère : tapis de départ pour le prochain propriétaire)
	local belt = beltOf[player]
	beltOf[player] = nil
	if belt then
		dress(belt, 0)
	end
end

return TreadmillService
