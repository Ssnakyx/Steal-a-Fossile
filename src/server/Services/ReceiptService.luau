--!strict
-- Achats Robux de produits développeur (ProcessReceipt, reprise de Steal a Snack et adaptée, brief 1).
-- Chaque produit est enregistré une fois par le service qui le donne (en général dans son Init) :
--   ReceiptService.Register("TreadmillLevel2", Config.Shop.Products.TreadmillLevel2.Id, function(player, data, receipt)
--       if data.TreadmillLevel ~= 1 then return false end -- pas le bon niveau : pas donné (Roblox réessaiera)
--       data.TreadmillLevel = 2
--       return true
--   end)
-- La fonction Grant vérifie tout AVANT de modifier `data`, ne doit pas attendre (pas de task.wait ni d'appel web) et
-- renvoie true si le produit est donné. Ensuite la sauvegarde est écrite tout de suite ; Roblox n'est prévenu
-- (PurchaseGranted) qu'après une écriture réussie. Un même achat (PurchaseId) n'est jamais donné deux fois.
-- Id = 0 : le produit n'existe pas encore dans le Creator Hub. Il reste caché en jeu (IsOnSale = false) et ne peut
-- être obtenu que par un achat simulé (Simulate : commande d'admin « simulate » dans Studio, FossilDebug, tests).
-- Ne jamais poser MarketplaceService.ProcessReceipt ailleurs : il n'y en a qu'un par jeu.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Config.Core)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)

export type Receipt = {
	PlayerId: number,
	PurchaseId: string,
	ProductId: number,
	CurrencySpent: number,
	Simulated: boolean,
	-- (achat simulé sans PurchaseId choisi : pas noté dans data.Purchases, qui ne garde que les vrais achats)
	Temporary: boolean?,
}
export type Grant = (player: Player, data: { [string]: any }, receipt: Receipt) -> boolean
type Product = { Key: string, Id: number, Grant: Grant }

local ReceiptService = {}
ReceiptService.Priority = -70

local products: { [string]: Product } = {}
local byId: { [number]: Product } = {}
local processing: { [string]: boolean } = {}

local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet

function ReceiptService.Register(key: string, productId: number, grant: Grant)
	if type(key) ~= "string" or key == "" then
		error("ReceiptService.Register : clé de produit invalide", 2)
	end
	if type(productId) ~= "number" or productId < 0 or productId % 1 ~= 0 then
		error(string.format("ReceiptService.Register(%s) : Id invalide (0 tant que le produit n'existe pas)", key), 2)
	end
	if type(grant) ~= "function" then
		error(string.format("ReceiptService.Register(%s) : il faut une fonction Grant", key), 2)
	end
	if products[key] then
		error(string.format("ReceiptService.Register : produit %s déjà enregistré", key), 2)
	end
	if productId ~= 0 and byId[productId] then
		error(string.format("ReceiptService.Register(%s) : Id %d déjà pris par %s", key, productId, byId[productId].Key), 2)
	end
	local product = { Key = key, Id = productId, Grant = grant }
	products[key] = product
	if productId ~= 0 then
		byId[productId] = product
	end
end

-- Le produit peut-il être acheté pour de vrai (créé dans le Creator Hub) ?
function ReceiptService.IsOnSale(key: string): boolean
	local product = products[key]
	return product ~= nil and product.Id ~= 0
end

function ReceiptService.ProductId(key: string): number?
	local product = products[key]
	return if product then product.Id else nil
end

-- Achat déjà donné et noté dans la sauvegarde ?
function ReceiptService.HasProcessed(player: Player, purchaseId: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and table.find(data.Purchases, purchaseId) ~= nil
end

local function remember(data: { [string]: any }, purchaseId: string)
	local purchases: { string } = data.Purchases
	table.insert(purchases, purchaseId)
	while #purchases > Core.Purchases.Remember do
		table.remove(purchases, 1)
	end
end

local function grantPurchase(player: Player, data: { [string]: any }, receipt: Receipt, product: Product?): Enum.ProductPurchaseDecision
	local purchaseId = receipt.PurchaseId
	if table.find(data.Purchases, purchaseId) then
		-- déjà donné : il reste peut-être à l'écrire
		return if DataService.Save(player) then GRANTED else NOT_YET
	end
	if not product then
		warn(string.format("[ReceiptService] produit inconnu %d (achat %s de %s)", receipt.ProductId, purchaseId, player.Name))
		return NOT_YET
	end
	if not product.Grant(player, data, receipt) then
		warn(string.format("[ReceiptService] %s non donné à %s (achat %s)", product.Key, player.Name, purchaseId))
		return NOT_YET
	end
	if not receipt.Temporary then
		remember(data, purchaseId)
	end
	if not receipt.Simulated then
		data.RobuxSpent += receipt.CurrencySpent
	end
	-- (si l'écriture rate, l'achat reste noté dans les données : le prochain appel de Roblox n'aura plus qu'à l'écrire)
	if not DataService.Save(player) then
		return NOT_YET
	end
	Signals.Fire("PurchaseGranted", player, product.Key, if receipt.Simulated then 0 else receipt.CurrencySpent)
	return GRANTED
end

local function process(receipt: Receipt, product: Product?): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NOT_YET -- (Roblox réessaiera quand le joueur reviendra)
	end
	local data = DataService.WaitFor(player, 30)
	if not data then
		return NOT_YET
	end
	local purchaseId = receipt.PurchaseId
	if processing[purchaseId] then
		return NOT_YET
	end
	processing[purchaseId] = true
	local ok, result = pcall(grantPurchase, player, data, receipt, product)
	processing[purchaseId] = nil
	if not ok then
		warn(string.format("[ReceiptService] achat %s : %s", purchaseId, tostring(result)))
		return NOT_YET
	end
	return result
end

-- Callback de MarketplaceService.ProcessReceipt
function ReceiptService.Process(info: { [any]: any }): Enum.ProductPurchaseDecision
	local playerId = tonumber(info.PlayerId)
	local productId = tonumber(info.ProductId)
	local purchaseId = info.PurchaseId
	if not playerId or not productId or purchaseId == nil then
		return NOT_YET
	end
	local spent = tonumber(info.CurrencySpent) or 0
	local receipt: Receipt = {
		PlayerId = playerId,
		PurchaseId = tostring(purchaseId),
		ProductId = productId,
		CurrencySpent = if spent == spent and spent >= 0 and spent < math.huge then spent else 0,
		Simulated = false,
	}
	return process(receipt, if productId ~= 0 then byId[productId] else nil)
end

-- Achat simulé, gratuit (Studio, commande d'admin, tests). À n'appeler que depuis du code serveur qui a vérifié le
-- droit du joueur. `purchaseId` permet de rejouer le même achat (tests d'idempotence).
function ReceiptService.Simulate(player: Player, key: string, purchaseId: string?): (boolean, string)
	local product = products[key]
	if not product then
		return false, "Unknown product " .. tostring(key)
	end
	local receipt: Receipt = {
		PlayerId = player.UserId,
		PurchaseId = purchaseId or ("SIM-" .. HttpService:GenerateGUID(false)),
		ProductId = product.Id,
		CurrencySpent = 0,
		Simulated = true,
		Temporary = purchaseId == nil,
	}
	local decision = process(receipt, product)
	if decision == GRANTED then
		return true, "Granted " .. key
	end
	return false, "Not granted " .. key
end

function ReceiptService.Init()
	MarketplaceService.ProcessReceipt = ReceiptService.Process
end

return ReceiptService
