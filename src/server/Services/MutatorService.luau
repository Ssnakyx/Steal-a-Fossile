--!strict
-- Sérum de mutation (Config.Mutator, docs/MUTATIONS.md « Sérum de mutation ») : un objet qui applique une mutation à un
-- dino du parc, avec une chance d'échouer, comme le Fragment d'éclipse du Mutator de Pet Fusion Lab.
--   * MutatorService.Mutate(player, id) : consomme un sérum ; réussite (Config.Mutator.SuccessChance %) = une mutation
--     meilleure que celle du dino (Config.Mutator.Pick), échec = rien ne change. Remote MutateDino.
--   * MutatorService.Buy(player, count) : sérums achetés avec l'argent du jeu (Config.Mutator.Price). Remote BuySerums.
--   * MutatorService.Give(player, count) : sérums donnés (récompenses : genre « Serums » de RewardService, produit Robux
--     MutationSerums3 de Config.Shop.Products, commande admin « serums »).
-- Clé replica « Serums » (sérums en réserve) et « SerumPrice » (prix d'un sérum pour ce joueur, rafraîchi avec son
-- revenu). Une mutation rare obtenue avec un sérum est annoncée au serveur comme à la réanimation (MutationService).
-- Signal : DinoSerum(player, id, success, mutation, before)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Mutator = require(ReplicatedStorage.Shared.Config.Mutator)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local EnclosureService = require(script.Parent.EnclosureService)
local FusionService = require(script.Parent.FusionService)
local IncomeService = require(script.Parent.IncomeService)
local MoneyService = require(script.Parent.MoneyService)
local MutationService = require(script.Parent.MutationService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)
local RewardService = require(script.Parent.RewardService)

local MutatorService = {}

local PRICE_INTERVAL = 5 -- secondes entre deux mises à jour de SerumPrice

local rng = Random.new()
local prices: { [Player]: number } = {}
-- (tirages imposés par les tests : { réussite, choix } dans [0, 1[)
local forced: { { number } } = {}

local function publish(player: Player)
	local data = DataService.Get(player)
	if data then
		ReplicaService.Set(player, "Serums", data.Serums)
	end
end

local function publishPrice(player: Player)
	if not DataService.Get(player) then
		return
	end
	local price = Mutator.Price(IncomeService.GetIncome(player))
	if prices[player] ~= price then
		prices[player] = price
		ReplicaService.Set(player, "SerumPrice", price)
	end
end

-- Renvoie la clé replica « Serums » (après avoir changé data.Serums à la main : debug, tests)
function MutatorService.Publish(player: Player)
	publish(player)
end

-- Prix d'un sérum pour ce joueur (argent du jeu)
function MutatorService.Price(player: Player): number
	return Mutator.Price(IncomeService.GetIncome(player))
end

-- Sérums en réserve
function MutatorService.Count(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Serums else 0
end

-- Donne des sérums. false si le plafond (Config.Mutator.MaxOwned) serait dépassé.
function MutatorService.Give(player: Player, count: number): boolean
	local data = DataService.Get(player)
	if not data or not Guard.Integer(count, 1) or data.Serums + count > Mutator.MaxOwned then
		return false
	end
	data.Serums += count
	publish(player)
	return true
end

-- Achète des sérums avec l'argent du jeu. Renvoie (ok, texte).
function MutatorService.Buy(player: Player, rawCount: any): (boolean, string)
	local count = if rawCount == nil then 1 else Guard.Integer(rawCount, 1, Mutator.MaxBuy)
	local data = DataService.Get(player)
	if not count then
		return false, "Invalid amount"
	end
	if not data then
		return false, "Please wait..."
	end
	if data.Serums + count > Mutator.MaxOwned then
		return false, "You can't carry more serums"
	end
	local cost = MutatorService.Price(player) * count
	if not MoneyService.Spend(player, cost, "Serums") then
		return false, "Not enough money!"
	end
	MutatorService.Give(player, count)
	return true, string.format("Bought %d %s for %s", count, if count > 1 then Mutator.Plural else Mutator.Name, Format.Money(cost))
end

-- Infos du dino pour l'écran de révélation (comme FusionService : modèle d'un hybride, rareté)
local function describe(id: string, dino: EnclosureService.Dino, success: boolean, before: string): { [string]: any }
	local hybrid = FusionService.Get(dino.Species)
	return {
		Success = success,
		Id = id,
		Species = dino.Species,
		Key = if hybrid then hybrid.Key else nil,
		Rarity = if hybrid then hybrid.Rarity else Rarity.Species[dino.Species],
		Size = dino.Size,
		Mutation = dino.Mutation,
		Before = before,
		Level = dino.Level,
		Income = IncomeService.DinoIncome(dino),
	}
end

local function roll(): (number, number)
	local pair = table.remove(forced, 1)
	if pair then
		return pair[1], pair[2]
	end
	return rng:NextNumber(), rng:NextNumber()
end

-- Utilise un sérum sur le dino `id`. Renvoie (ok, texte, résultat) ; ok = le sérum a été utilisé (réussi ou non).
function MutatorService.Mutate(player: Player, id: any): (boolean, string, { [string]: any }?)
	local data = DataService.Get(player)
	if not data then
		return false, "Please wait...", nil
	end
	local dinoId = Guard.String(id, 20)
	local dino = dinoId and EnclosureService.GetDino(player, dinoId)
	if not (dinoId and dino) then
		return false, "Pick one of your dinos", nil
	end
	if not Mutator.CanMutate(dino.Mutation) then
		return false, "This dino already has the best mutation!", nil
	end
	if data.Serums < 1 then
		return false, "You need a " .. Mutator.Name .. "!", nil
	end
	data.Serums -= 1
	data.SerumsUsed += 1
	publish(player)
	local before = dino.Mutation
	local successRoll, pickRoll = roll()
	local success = successRoll * 100 < Mutator.SuccessChance
	local name = EnclosureService.DisplayName(dino)
	if not success then
		Signals.Fire("DinoSerum", player, dinoId, false, before, before)
		return true, "The mutation failed... " .. name .. " is unchanged.", describe(dinoId, dino, false, before)
	end
	local mutation = Mutator.Pick(before, pickRoll) :: string
	local changed = EnclosureService.SetMutation(player, dinoId, mutation, Mutator.ResultState) :: EnclosureService.Dino
	local info = Economy.Mutation(mutation)
	Signals.Fire("DinoSerum", player, dinoId, true, mutation, before)
	local text = MutationService.AnnounceText(player, changed)
	if text then
		Remotes.Event("LoopAnnounce"):FireAllClients(text)
		Notify.All(text, "success")
	end
	return true,
		string.format("MUTATION! %s is now %s (x%s income)", name, mutation, tostring(info and info.Income or 1)),
		describe(dinoId, changed, true, before)
end

-- Tests : impose les prochains tirages ({ réussite, choix } dans [0, 1[)
function MutatorService.ForceRolls(list: { { number } })
	forced = table.clone(list)
end

-- ===================================================================== cycle de vie

local function registerProduct()
	local products = Config.Shop.Products
	local product = type(products) == "table" and products.MutationSerums3
	if type(product) ~= "table" or type(product.Id) ~= "number" then
		return
	end
	ReceiptService.Register("MutationSerums3", product.Id, function(player: Player, data, _receipt): boolean
		-- (toujours accordé, sinon l'achat serait retenté sans fin : au plafond, seulement ce qui tient)
		local count = math.clamp(Mutator.MaxOwned - data.Serums, 0, Mutator.PerProduct)
		data.Serums += count
		publish(player)
		Notify.Send(player, "+" .. count .. " " .. Mutator.Plural .. "!", "success")
		return true
	end)
end

local function registerCommands()
	AdminService.RegisterCommand("serums", {
		Description = "Give mutation serums",
		Usage = "serums <amount> [player]",
		Run = function(caller: Player, args: { string })
			local count = Guard.Integer(tonumber(args[1] or ""), 1, Mutator.MaxOwned)
			local target = AdminService.FindPlayer(caller, args[2])
			if not (count and target) then
				return false, "Usage: serums <amount> [player]"
			end
			if not MutatorService.Give(target, count) then
				return false, "Too many serums (max " .. Mutator.MaxOwned .. ")"
			end
			return true, target.Name .. " got " .. count .. " serum(s)"
		end,
	})
end

function MutatorService.Init()
	Net.Function("MutateDino", { Rate = 2, Burst = 3 }, function(player: Player, id: any)
		return MutatorService.Mutate(player, id)
	end)
	Net.Function("BuySerums", { Rate = 2, Burst = 4 }, function(player: Player, count: any)
		return MutatorService.Buy(player, count)
	end)
	RewardService.RegisterKind("Serums", function(player: Player, amount: number): boolean
		return MutatorService.Give(player, amount)
	end)
	registerProduct()
	registerCommands()
end

function MutatorService.Start()
	while true do
		task.wait(PRICE_INTERVAL)
		for player in prices do
			if player.Parent == Players then
				publishPrice(player)
			end
		end
	end
end

function MutatorService.OnPlayerReady(player: Player, _data: { [string]: any })
	publish(player)
	prices[player] = -1
	publishPrice(player)
end

function MutatorService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	prices[player] = nil
end

return MutatorService
