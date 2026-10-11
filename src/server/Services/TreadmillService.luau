--!strict
-- Treadmill du parc (brief 4 « vitesse-treadmill ») : en courant dessus, ou AFK dessus, le joueur gagne de la vitesse
-- chaque seconde. Rien à regarder pendant. Sans achat, le tapis donne Config.Speed.Treadmill.FreeMultiplier x BaseGain
-- (tout le monde peut AFK dessus ; reconnexion AFK : AfkService).
-- Achat : niveau 1 à 25 R$, puis un produit développeur par niveau, au prix qui monte (Config.Shop.Treadmill.Levels).
-- Le serveur ne propose que le niveau suivant du joueur ; un reçu d'un autre niveau n'est pas donné (Roblox le
-- représente plus tard, et il passe quand il devient le niveau suivant).
-- Tapis : toute BasePart taguée « Treadmill » (CollectionService) dans le Workspace. Le joueur est dessus si son
-- HumanoidRootPart est au-dessus de la pièce (Config.Speed.Treadmill.Height). Si la pièce ou un de ses ancêtres (le
-- parc) a l'attribut OwnerUserId, seul ce joueur y gagne de la vitesse.
--   TreadmillService.Rate(player)           vitesse gagnée par seconde sur le tapis (gain gratuit sans treadmill)
--   TreadmillService.IsOnTreadmill(player)
--   TreadmillService.SetLevel(player, niveau)   fixe le niveau sans achat (admin Studio, FossilDebug)
-- Signaux : TreadmillUpgraded(player, level)   niveau acheté et sauvegardé
-- Replica : TreadmillLevel, TreadmillRate. Attribut OnTreadmill sur le joueur (VFX, UI).

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
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)
local ShopService = require(script.Parent.ShopService)
local SpeedService = require(script.Parent.SpeedService)

type Pending = { Level: number, Since: number, Paid: boolean }

local TreadmillService = {}

local LEVELS = Shop.Treadmill.Levels
local MAX_LEVEL = #LEVELS
local KEY_PREFIX = "TreadmillLevel"

local players: { [Player]: boolean } = {}
local onBelt: { [Player]: boolean } = {}
local pending: { [Player]: Pending } = {}
local lastHint: { [Player]: number } = {}
local upsold: { [Player]: boolean } = {} -- rappel « achète le treadmill » déjà montré (gain gratuit)

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

local function publish(player: Player)
	ReplicaService.Set(player, "TreadmillLevel", levelOf(player))
	ReplicaService.Set(player, "TreadmillRate", TreadmillService.Rate(player))
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
					string.format("+%s speed/s here, even AFK! Buy the Treadmill in the Shop for x%s.", Format.Number(rate), Format.Number(paid / free)),
					"info"
				)
			end
		else
			local now = os.clock()
			if not lastHint[player] or now - lastHint[player] >= SpeedConfig.Treadmill.HintCooldown then
				lastHint[player] = now
				Notify.Send(player, "Buy the Treadmill in the Shop to gain speed here!", "info")
			end
		end
	end
end

-- ===== achat =====

local function buy(player: Player): (boolean, string)
	local data = DataService.Get(player)
	if not data or not players[player] then
		return false, "Please wait..."
	end
	local nextLevel: number = data.TreadmillLevel + 1
	if nextLevel > MAX_LEVEL then
		return false, "Your treadmill is maxed out!"
	end
	local key = keyFor(nextLevel)
	if not ReceiptService.IsOnSale(key) then
		return false, "Coming soon!"
	end
	-- (un achat de ce niveau en cours : on ne le propose pas une deuxième fois. Payé mais pas encore donné, par exemple
	-- pendant une panne de sauvegarde : bloqué jusqu'à ce que le niveau arrive, sinon il serait payé deux fois)
	local waiting = pending[player]
	if waiting and waiting.Level == nextLevel and (waiting.Paid or os.clock() - waiting.Since < Shop.Treadmill.PendingSeconds) then
		return false, "Purchase in progress..."
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

-- Contenu de la section « Treadmill » du shop
local function section(player: Player): { [string]: any }
	local level = levelOf(player)
	local nextLevel = level + 1
	local nextInfo = nil
	if nextLevel <= MAX_LEVEL and ReceiptService.IsOnSale(keyFor(nextLevel)) then
		nextInfo = {
			Level = nextLevel,
			Multiplier = LEVELS[nextLevel].Multiplier,
			Rate = rateAt(player, nextLevel),
			Price = ShopService.Price("Product", LEVELS[nextLevel].Id),
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
		if not level then
			return
		end
		if player.Parent == Players then
			local rate = Format.Number(TreadmillService.Rate(player))
			if level == 1 then
				Notify.Send(player, "Treadmill unlocked! Run on it to gain +" .. rate .. " speed/s.", "success")
			else
				Notify.Send(player, string.format("Treadmill level %d! +%s speed/s.", level, rate), "success")
			end
		end
		Signals.Fire("TreadmillUpgraded", player, level)
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

	Net.Function("BuyTreadmill", { Rate = 1, Burst = 3 }, function(player: Player)
		return buy(player)
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

function TreadmillService.Start()
	while true do
		task.wait(SpeedConfig.Treadmill.TickSeconds)
		TreadmillService.Tick()
	end
end

function TreadmillService.OnPlayerReady(player: Player)
	players[player] = true
	publish(player)
end

function TreadmillService.OnPlayerRemoving(player: Player)
	players[player] = nil
	onBelt[player] = nil
	pending[player] = nil
	lastHint[player] = nil
	upsold[player] = nil
end

return TreadmillService
