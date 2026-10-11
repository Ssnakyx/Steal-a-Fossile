--!strict
-- Roue de la chance (Config.Daily.Spins) : 1 tour gratuit par jour, des tours en réserve gagnés en jouant (cadeaux de
-- temps de jeu, calendrier, case « Spin Again ») ou achetés en Robux (produits Spins3, Spins10). Le tour gratuit du
-- jour passe en premier. Le serveur tire la case (Weight), la donne avec RewardService et renvoie son numéro pour
-- que le client fasse tourner la roue jusqu'à elle.
-- Achats au hasard payants : jamais proposés à un joueur dont le pays les interdit (PolicyService,
-- ArePaidRandomItemsRestricted ; interdit tant que Roblox n'a pas répondu). Les chances sont affichées sur la roue.
--   SpinService.Spin(player)            -> (ok, texte, case)   (remote Spin)
--   SpinService.Give(player, n)         -> bool                tours en réserve (récompenses, achats, admin)
--   SpinService.Available(player)       -> (gratuits, en réserve)
--   SpinService.Pick()                  -> numéro de case tiré selon les Weight
--   SpinService.Refresh(player)         renvoie l'état au client (après un changement de data.Spins hors du service)
-- Replica « Spins » = { Free, Stored, Total, NextFree (os.time()), CanBuy }.
-- Signal : SpinDone(player, case, reward)

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)

local SpinService = {}

local SPINS = DailyConfig.Spins
local PRIZES = SPINS.Prizes

local players: { [Player]: boolean } = {}
local lastSpin: { [Player]: number } = {}
-- Achats au hasard payants permis (PolicyService a répondu « pas interdit »)
local canBuy: { [Player]: boolean } = {}
local rng = Random.new()

local function freeLeft(data: { [string]: any }, today: number): number
	if data.Spins.FreeDay ~= today then
		return SPINS.FreePerDay
	end
	return math.max(0, SPINS.FreePerDay - data.Spins.FreeUsed)
end

function SpinService.Available(player: Player): (number, number)
	local data = DataService.Get(player)
	if not data then
		return 0, 0
	end
	return freeLeft(data, DailyConfig.Day(os.time())), data.Spins.Stored
end

local function anyOnSale(): boolean
	for key in SPINS.Products do
		if ReceiptService.IsOnSale(key) then
			return true
		end
	end
	return false
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data or not players[player] then
		return
	end
	local now = os.time()
	ReplicaService.Set(player, "Spins", {
		Free = freeLeft(data, DailyConfig.Day(now)),
		Stored = data.Spins.Stored,
		Total = data.Spins.Total,
		NextFree = DailyConfig.NextReset(now),
		CanBuy = canBuy[player] == true and anyOnSale(),
	})
end

function SpinService.Refresh(player: Player)
	publish(player)
end

-- Ajoute des tours en réserve. false si le joueur n'est pas chargé ou si la réserve déborderait.
function SpinService.Give(player: Player, count: number): boolean
	local data = DataService.Get(player)
	if not data or not Guard.Integer(count, 1) or data.Spins.Stored + count > SPINS.MaxStored then
		return false
	end
	data.Spins.Stored += count
	publish(player)
	return true
end

-- Tire une case de la roue selon les Weight (numéro dans Config.Daily.Spins.Prizes)
function SpinService.Pick(): number
	local total = 0
	for _, prize in PRIZES do
		total += prize.Weight
	end
	local roll = rng:NextNumber() * total
	for index, prize in PRIZES do
		roll -= prize.Weight
		if roll < 0 then
			return index
		end
	end
	return #PRIZES
end

function SpinService.Spin(player: Player): (boolean, string, number?)
	local data = DataService.Get(player)
	if not data or not players[player] then
		return false, "Please wait...", nil
	end
	local clock = os.clock()
	if lastSpin[player] and clock - lastSpin[player] < SPINS.Cooldown then
		return false, "The wheel is still spinning!", nil
	end
	local spins = data.Spins
	local today = DailyConfig.Day(os.time())
	local before = { FreeDay = spins.FreeDay, FreeUsed = spins.FreeUsed, Stored = spins.Stored, Total = spins.Total }
	if freeLeft(data, today) > 0 then
		if spins.FreeDay ~= today then
			spins.FreeDay = today
			spins.FreeUsed = 0
		end
		spins.FreeUsed += 1
	elseif spins.Stored > 0 then
		spins.Stored -= 1
	else
		return false, "No spins left! Play to earn more.", nil
	end
	spins.Total += 1
	lastSpin[player] = clock
	local index = SpinService.Pick()
	local prize = PRIZES[index]
	local ok, text = RewardService.Grant(player, prize.Reward, "Spin")
	if not ok then
		-- (rien n'a été donné : le tour est rendu)
		spins.FreeDay = before.FreeDay
		spins.FreeUsed = before.FreeUsed
		spins.Stored = before.Stored
		spins.Total = before.Total
		lastSpin[player] = nil
		publish(player)
		return false, text, nil
	end
	publish(player)
	Signals.Fire("SpinDone", player, index, prize.Reward)
	return true, text, index
end

-- ===== achats Robux =====

local function offers(player: Player): { { [string]: any } }
	local list = {}
	if not canBuy[player] then
		return list
	end
	for key, product in SPINS.Products do
		if ReceiptService.IsOnSale(key) then
			table.insert(list, {
				Key = key,
				Name = product.Name,
				Count = product.Count,
				Order = product.Order,
				Price = ShopService.Price("Product", product.Id),
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

local function buy(player: Player, rawKey: any): (boolean, string)
	local key = Guard.Key(rawKey, SPINS.Products)
	if not key then
		return false, "Unknown offer"
	end
	if not players[player] then
		return false, "Please wait..."
	end
	if not canBuy[player] then
		return false, "Spins can't be bought here."
	end
	if not ReceiptService.IsOnSale(key) then
		return false, "Coming soon!"
	end
	local productId = ReceiptService.ProductId(key) :: number
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	return ok, if ok then "" else "Try again"
end

local function checkPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not players[player] then
		return
	end
	-- (sans réponse de Roblox : interdit, par prudence)
	canBuy[player] = ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == false
	publish(player)
end

-- ===== cycle de vie =====

function SpinService.Init()
	RewardService.RegisterKind("Spins", function(player: Player, amount: number): boolean
		return SpinService.Give(player, amount)
	end)

	for key, product in SPINS.Products do
		ReceiptService.Register(key, product.Id, function(player: Player, data): boolean
			if data.Spins.Stored + product.Count > SPINS.MaxStored then
				return false
			end
			data.Spins.Stored += product.Count
			publish(player)
			return true
		end)
	end
	Signals.Connect("PurchaseGranted", function(player: Player, key: string)
		local product = SPINS.Products[key]
		if product and player.Parent == Players then
			Notify.Send(player, string.format("+%d Spins! Open the wheel to use them.", product.Count), "success")
		end
	end)

	Signals.Connect("NewDay", function()
		for player in players do
			publish(player)
		end
	end)
	Signals.Connect("DailyReset", function(player: Player)
		lastSpin[player] = nil
		publish(player)
	end)

	Net.Function("Spin", { Rate = 1, Burst = 2 }, function(player: Player)
		return SpinService.Spin(player)
	end)
	Net.Function("GetSpinOffers", { Rate = 1, Burst = 3 }, function(player: Player)
		return offers(player)
	end)
	Net.Function("BuySpins", { Rate = 1, Burst = 3 }, buy)

	AdminService.RegisterCommand("spins", {
		Description = "Give spins for the lucky wheel",
		Usage = "spins <1-1000> [player]",
		Run = function(player, args)
			local count = Guard.Integer(tonumber(args[1] or ""), 1, 1000)
			local target = AdminService.FindPlayer(player, args[2])
			if not target or not DataService.Get(target) then
				return false, "Player not found"
			end
			if not count then
				return false, "Count between 1 and 1000"
			end
			if not SpinService.Give(target, count) then
				return false, "Too many spins stored"
			end
			return true, string.format("%s now has %d spins stored", target.Name, (DataService.Get(target) :: any).Spins.Stored)
		end,
	})
end

function SpinService.OnPlayerReady(player: Player)
	players[player] = true
	publish(player)
	task.spawn(checkPolicy, player)
end

function SpinService.OnPlayerRemoving(player: Player)
	players[player] = nil
	lastSpin[player] = nil
	canBuy[player] = nil
end

return SpinService
