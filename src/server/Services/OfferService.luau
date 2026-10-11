--!strict
-- Offres du shop Robux (demande de Snaky du 2026-10-11 : « shop beaucoup plus complet, packs, réductions ») :
--   * MONEY : packs d'argent du jeu (Config.Shop.Cash), le montant suit le revenu du joueur ;
--   * packs : Starter Pack (premiers jours, une fois), pack Limited (change tous les quelques jours), offre du jour
--     (Config.Shop.Packs, Config.Shop.Current) ; prix barré et réduction ;
--   * cadeaux : offrir un passe à un autre joueur du serveur (produit « cadeau » de Config.Shop.Gifts).
-- Tout est un produit développeur donné par ReceiptService (idempotent). Contenu d'un pack : argent, vitesse et Bear
-- Traps par RewardService (comme les récompenses), Instant Revive par ReviveService, passes par ShopService.GrantPass,
-- Server Luck par ShopService.AddServerLuck.
--   OfferService.PackState(player, clé)   -> (proposé ?, heure de fin os.time() ou 0)
--   OfferService.GiveItems(player, items) donne le contenu d'un pack
--   OfferService.Get(player)              section « Offers » du shop (GetShop)
-- Remotes : BuyOffer(clé) propose l'achat d'un pack ou d'un pack d'argent ; GiftPass(passe, UserId) envoie un cadeau
-- déjà payé ou propose l'achat du cadeau.
-- Replica « GiftCredits » ({ [passe] = cadeaux payés pas encore envoyés }).
-- Signaux : PackBought(player, clé), GiftSent(acheteur, joueur qui reçoit, passe)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)
local ReviveService = require(script.Parent.ReviveService)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)

type Item = Shop.Item
type Pending = { Key: string, Target: number, At: number }

local OfferService = {}

local MAX_CREDITS = 50
local GIFT_PREFIX = "Gift"

local pending: { [Player]: Pending } = {} -- cadeau en cours d'achat : passe et joueur choisi
local ready: { [Player]: boolean } = {}

local function studio(): boolean
	return RunService:IsStudio()
end

-- ===== contenu =====

-- Texte d'un morceau de pack : "+$15K", "10 Bear Traps", "3 Instant Revives", "Neon Trail", "Server Luck x2 (45 min)"
local function itemLabel(item: Item, scale: Daily.Scale): string
	if item.Kind == "Money" or item.Kind == "Speed" or item.Kind == "BearTraps" then
		return Daily.Label(item :: any, scale)
	elseif item.Kind == "Revives" then
		local count = math.max(1, math.floor(tonumber(item.Amount) or 1))
		return count .. (if count == 1 then " Instant Revive" else " Instant Revives")
	elseif item.Kind == "Pass" then
		local pass = Shop.Passes[item.Key or ""]
		return if pass then pass.Name else "Pass"
	elseif item.Kind == "ServerLuck" then
		return string.format("Server Luck x%d (%d min)", Shop.ServerLuck.Multiplier, math.floor(tonumber(item.Minutes) or 0))
	end
	return item.Kind
end

-- Donne le contenu d'un pack. Ne doit pas attendre (appelé pendant un reçu). Un morceau impossible est remplacé :
-- RewardService donne son argent de secours, un passe déjà possédé devient Config.Shop.PassRefund.
function OfferService.GiveItems(player: Player, items: { Item })
	for _, item in items do
		local ok, err = pcall(function()
			if item.Kind == "Money" or item.Kind == "Speed" or item.Kind == "BearTraps" then
				RewardService.Grant(player, item :: any, "Shop")
			elseif item.Kind == "Revives" then
				ReviveService.GiveInstant(player, math.max(1, math.floor(tonumber(item.Amount) or 1)))
			elseif item.Kind == "Pass" then
				local key = item.Key or ""
				if ShopService.HasPass(player, key) or not ShopService.GrantPass(player, key) then
					RewardService.Grant(player, Shop.PassRefund :: any, "Shop")
				else
					Notify.Send(player, Shop.Passes[key].Name .. " unlocked!", "success")
				end
			elseif item.Kind == "ServerLuck" then
				ShopService.AddServerLuck((tonumber(item.Minutes) or 0) * 60)
				Notify.All(string.format("%s activated Server Luck x%d for everyone!", player.DisplayName, Shop.ServerLuck.Multiplier), "success")
			else
				warn("[OfferService] morceau de pack inconnu : " .. tostring(item.Kind))
			end
		end)
		if not ok then
			warn(string.format("[OfferService] %s pour %s : %s", tostring(item.Kind), player.Name, tostring(err)))
		end
	end
end

-- Le pack est-il proposé à ce joueur maintenant ? (sans regarder s'il est en vente sur Roblox). Renvoie aussi l'heure
-- de fin de l'offre (os.time(), 0 = pas de fin).
function OfferService.PackState(player: Player, key: string): (boolean, number)
	local pack = Shop.Packs[key]
	local data = DataService.Get(player)
	if not pack or not data then
		return false, 0
	end
	local now = os.time()
	local endsAt = 0
	if pack.Kind == "Starter" then
		if (data.Offers.Bought[key] or 0) > 0 then
			return false, 0
		end
		endsAt = data.FirstJoin + Shop.StarterHours * 3600
		if now >= endsAt then
			return false, 0
		end
	else
		local current = Shop.Current(now)
		if pack.Kind == "Limited" and current.Limited == key then
			endsAt = current.LimitedEnds
		elseif pack.Kind == "Deal" and current.Deal == key then
			endsAt = current.DealEnds
		else
			return false, 0
		end
	end
	for _, item in pack.Items do
		if item.Kind == "Pass" and ShopService.HasPass(player, item.Key or "") then
			return false, 0
		end
	end
	return true, endsAt
end

-- ===== cadeaux =====

local function publishCredits(player: Player)
	local data = DataService.Get(player)
	if data then
		ReplicaService.Set(player, "GiftCredits", table.clone(data.Offers.GiftCredits))
	end
end

local function addCredit(player: Player, key: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local credits = data.Offers.GiftCredits
	credits[key] = math.min(MAX_CREDITS, (credits[key] or 0) + 1)
	publishCredits(player)
	return true
end

-- Le joueur choisi peut-il recevoir ce passe ? -> (joueur, texte d'erreur)
local function giftTarget(buyer: Player, key: string, userId: any): (Player?, string)
	local id = Guard.Integer(userId, 1)
	local target = if id then Players:GetPlayerByUserId(id) else nil
	if not target or target.Parent ~= Players or not ready[target] then
		return nil, "This player is not here anymore"
	end
	if target == buyer then
		return nil, "Pick a friend, not yourself!"
	end
	if ShopService.HasPass(target, key) then
		return nil, target.DisplayName .. " already has " .. Shop.Passes[key].Name
	end
	return target, ""
end

-- Donne le passe au joueur choisi. Ne doit pas attendre (appelé pendant un reçu).
local function deliver(buyer: Player, target: Player, key: string): boolean
	if not ShopService.GrantPass(target, key) then
		return false
	end
	local buyerData = DataService.Get(buyer)
	local targetData = DataService.Get(target)
	if buyerData then
		buyerData.Offers.GiftsSent += 1
	end
	if targetData then
		targetData.Offers.GiftsReceived += 1
	end
	local name = Shop.Passes[key].Name
	Notify.Send(target, string.format("%s gifted you %s!", buyer.DisplayName, name), "success")
	Notify.All(string.format("%s gifted %s to %s!", buyer.DisplayName, name, target.DisplayName), "info")
	Signals.Fire("GiftSent", buyer, target, key)
	-- (le passe est noté dans la sauvegarde de celui qui le reçoit : écrite tout de suite, sans attendre ici)
	task.spawn(DataService.Save, target)
	return true
end

-- Remote GiftPass : envoie un cadeau déjà payé, sinon propose l'achat du cadeau
function OfferService.Gift(player: Player, rawKey: any, userId: any): (boolean, string)
	local key = Guard.Key(rawKey, Shop.Gifts)
	if not key or not Shop.Passes[key] then
		return false, "Unknown pass"
	end
	local data = DataService.Get(player)
	if not data or not ready[player] then
		return false, "Please wait..."
	end
	local target, problem = giftTarget(player, key, userId)
	if not target then
		return false, problem
	end
	local credits = data.Offers.GiftCredits
	if (credits[key] or 0) > 0 then
		credits[key] -= 1
		if credits[key] <= 0 then
			credits[key] = nil
		end
		publishCredits(player)
		if not deliver(player, target, key) then
			addCredit(player, key)
			return false, "Try again"
		end
		return true, "Gift sent to " .. target.DisplayName .. "!"
	end
	local gift = Shop.Gifts[key]
	if gift.Id == 0 then
		return false, "Coming soon!"
	end
	pending[player] = { Key = key, Target = target.UserId, At = os.clock() }
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, gift.Id)
	end)
	return ok, if ok then "" else "Try again"
end

-- ===== achats =====

-- Remote BuyOffer : pack d'argent ou pack
function OfferService.Buy(player: Player, rawKey: any): (boolean, string)
	if type(rawKey) ~= "string" then
		return false, "Unknown offer"
	end
	if not ready[player] then
		return false, "Please wait..."
	end
	local id: number
	if Shop.Cash[rawKey] then
		id = Shop.Cash[rawKey].Id
	elseif Shop.Packs[rawKey] then
		if not OfferService.PackState(player, rawKey) then
			return false, "This offer has ended"
		end
		id = Shop.Packs[rawKey].Id
	else
		return false, "Unknown offer"
	end
	if id == 0 then
		return false, "Coming soon!"
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	return ok, if ok then "" else "Try again"
end

-- ===== contenu du shop =====

local function byOrder(a: { [string]: any }, b: { [string]: any }): boolean
	if a.Order ~= b.Order then
		return a.Order < b.Order
	end
	return a.Key < b.Key
end

-- Section « Offers » de GetShop. Ce qui n'est pas en vente (Id = 0) n'y est que dans Studio (OnSale = false).
function OfferService.Get(player: Player): { [string]: any }
	local scale = RewardService.Scale(player)
	local showAll = studio()
	-- (« +N% MORE » : minutes de revenu par Robux, comparées au plus petit pack d'argent)
	local baseRatio = math.huge
	local bestRatio = 0
	for _, cash in Shop.Cash do
		local ratio = (cash.Reward.IncomeMinutes or 0) / math.max(1, cash.Price)
		baseRatio = math.min(baseRatio, ratio)
		bestRatio = math.max(bestRatio, ratio)
	end
	local cashList = {}
	for key, cash in Shop.Cash do
		if cash.Id == 0 and not showAll then
			continue
		end
		local ratio = (cash.Reward.IncomeMinutes or 0) / math.max(1, cash.Price)
		table.insert(cashList, {
			Key = key,
			Name = cash.Name,
			Order = cash.Order,
			OnSale = cash.Id ~= 0,
			Price = if cash.Id ~= 0 then ShopService.Price("Product", cash.Id) else cash.Price,
			Amount = Daily.Amount(cash.Reward :: any, scale),
			Bonus = if baseRatio > 0 then math.floor((ratio / baseRatio - 1) * 100 + 0.5) else 0,
			Best = ratio >= bestRatio and ratio > baseRatio,
		})
	end
	table.sort(cashList, byOrder)
	local packs = {}
	for key, pack in Shop.Packs do
		if pack.Id == 0 and not showAll then
			continue
		end
		local shown, endsAt = OfferService.PackState(player, key)
		if not shown then
			continue
		end
		local labels = {}
		for _, item in pack.Items do
			-- (« +$15K » devient « $15K » : les morceaux sont déjà reliés par des « + »)
			table.insert(labels, (string.gsub(itemLabel(item, scale), "^%+", "")))
		end
		table.insert(packs, {
			Key = key,
			Name = pack.Name,
			Kind = pack.Kind,
			Order = pack.Order,
			Icon = pack.Icon,
			OnSale = pack.Id ~= 0,
			Price = if pack.Id ~= 0 then ShopService.Price("Product", pack.Id) else pack.Price,
			Worth = pack.Worth,
			EndsAt = endsAt,
			Items = labels,
		})
	end
	table.sort(packs, byOrder)
	local gifts = {}
	for key, gift in Shop.Gifts do
		if Shop.Passes[key] and (gift.Id ~= 0 or showAll) then
			gifts[key] = {
				OnSale = gift.Id ~= 0,
				Price = if gift.Id ~= 0 then ShopService.Price("Product", gift.Id) else gift.Price,
			}
		end
	end
	local data = DataService.Get(player)
	return {
		Now = os.time(),
		Cash = cashList,
		Packs = packs,
		Gifts = gifts,
		Credits = if data then table.clone(data.Offers.GiftCredits) else {},
	}
end

-- ===== cycle de vie =====

local function prefetchPrices()
	local function fetch(id: number)
		if id ~= 0 then
			task.spawn(function()
				ShopService.Price("Product", id)
			end)
		end
	end
	for _, cash in Shop.Cash do
		fetch(cash.Id)
	end
	for _, pack in Shop.Packs do
		fetch(pack.Id)
	end
	for _, gift in Shop.Gifts do
		fetch(gift.Id)
	end
end

function OfferService.Init()
	for key, cash in Shop.Cash do
		ReceiptService.Register(key, cash.Id, function(player: Player): boolean
			-- (le joueur voit « +$25K! » par l'événement RewardGranted)
			local ok = RewardService.Grant(player, cash.Reward :: any, "Shop")
			return ok
		end)
	end
	for key, pack in Shop.Packs do
		ReceiptService.Register(key, pack.Id, function(player: Player, data): boolean
			-- (toujours donné : Roblox a déjà pris les Robux, même si l'offre vient de finir)
			data.Offers.Bought[key] = (data.Offers.Bought[key] or 0) + 1
			OfferService.GiveItems(player, pack.Items)
			Notify.Send(player, pack.Name .. " unlocked!", "success")
			Signals.Fire("PackBought", player, key)
			return true
		end)
	end
	for key, gift in Shop.Gifts do
		if not Shop.Passes[key] then
			error("Config.Shop.Gifts : passe inconnu " .. key)
		end
		ReceiptService.Register(GIFT_PREFIX .. key, gift.Id, function(player: Player): boolean
			local wanted = pending[player]
			pending[player] = nil
			if wanted and wanted.Key == key and os.clock() - wanted.At <= Shop.GiftHoldSeconds then
				local target = giftTarget(player, key, wanted.Target)
				if target and deliver(player, target, key) then
					return true
				end
			end
			-- (joueur choisi parti, ou il a déjà le passe : le cadeau attend, à envoyer depuis le shop)
			if not addCredit(player, key) then
				return false
			end
			Notify.Send(player, string.format("Your %s gift is ready! Send it from the shop.", Shop.Passes[key].Name), "info")
			return true
		end)
	end

	Net.Function("BuyOffer", { Rate = 1, Burst = 3 }, OfferService.Buy)
	Net.Function("GiftPass", { Rate = 1, Burst = 3 }, OfferService.Gift)
	ShopService.RegisterSection("Offers", OfferService.Get)
end

function OfferService.Start()
	prefetchPrices()
end

function OfferService.OnPlayerReady(player: Player, data: { [string]: any })
	ready[player] = true
	publishCredits(player)
	local count = 0
	for _, n in data.Offers.GiftCredits do
		count += n
	end
	if count > 0 then
		Notify.Send(player, string.format("You have %d gift(s) to send! Open the shop.", count), "info")
	end
end

function OfferService.OnPlayerRemoving(player: Player)
	ready[player] = nil
	pending[player] = nil
end

return OfferService
