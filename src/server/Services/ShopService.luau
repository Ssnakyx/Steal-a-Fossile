--!strict
-- Shop Robux (brief 4 « vitesse-treadmill ») : passes (game passes), produits développeur, Server Luck, et le contenu
-- du shop avec les prix lus sur Roblox. Le treadmill et ses niveaux sont dans TreadmillService (section « Treadmill »
-- du shop). Les achats de produits passent par ReceiptService (idempotent par PurchaseId).
--   ShopService.HasPass(player, "DoubleMoney")          le joueur a-t-il ce passe ?
--   ShopService.PassMultiplier(player, "DoubleMoney")   Multiplier du passe (Config.Shop.Passes) s'il l'a, sinon 1
--   ShopService.ServerLuck()                            chance du serveur : 2 pendant un Server Luck x2, sinon 1
--   ShopService.Price("Product" | "GamePass", id)       prix Robux lu sur Roblox (nil si inconnu), gardé 10 min
--   ShopService.RegisterSection(nom, fn)                ajoute une section au contenu du shop (GetShop)
--   ShopService.BuyPass(player, clé)                    propose l'achat d'un passe -> (ok, texte) (remote BuyPass)
-- Produits : chaque produit de Config.Shop.Products est donné par le service de son champ Owner, qui l'enregistre avec
-- ReceiptService.Register ; ShopService enregistre ServerLuck. Un produit pas enregistré ou à Id = 0 reste caché.
-- Passes : Roblox est la source. À chaque arrivée, chaque passe en vente est redemandé (UserOwnsGamePassAsync) ; la
-- sauvegarde (data.Passes) ne sert que quand Roblox ne répond pas. Un passe que Roblox dit ne plus avoir (remboursé)
-- est retiré, sauf s'il vient d'être acheté sur ce serveur (Roblox peut répondre en retard).
-- Signaux : PassOwned(player, clé)                    passe trouvé au chargement ou acheté en jeu
--           PassLost(player, clé)                     passe retiré (Roblox dit que le joueur ne l'a plus)
--           ServerLuckChanged(multiplier, endsAt)     Server Luck commencé, prolongé ou fini (endsAt = os.time())
-- Replica : Passes ({ [clé] = true }). Attributs : VIP (joueur) ; ServerLuck et ServerLuckEndsAt (Workspace).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)

export type PriceKind = "Product" | "GamePass"
type CachedPrice = { Price: number?, At: number, Fetching: boolean }
type Section = (player: Player) -> any

local ShopService = {}
ShopService.Priority = -20

local PRICE_RETRY = 30 -- secondes avant de redemander un prix que Roblox n'a pas donné
local PASS_CHECK_ATTEMPTS = 3

local owned: { [Player]: { [string]: boolean } } = {}
local boughtHere: { [Player]: { [string]: boolean } } = {} -- passes achetés sur ce serveur (jamais retirés)
local passById: { [number]: string } = {}
local prices: { [string]: CachedPrice } = {}
local sections: { [string]: Section } = {}
local luckEndsAt = 0 -- os.time() de la fin du Server Luck (0 = aucun)

for key, pass in Shop.Passes do
	if pass.Id ~= 0 then
		if passById[pass.Id] then
			error(string.format("Config.Shop.Passes : Id %d pris par %s et %s", pass.Id, passById[pass.Id], key))
		end
		passById[pass.Id] = key
	end
end

-- ===== passes =====

function ShopService.HasPass(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function ShopService.PassMultiplier(player: Player, key: string): number
	local pass = Shop.Passes[key]
	if not pass or not ShopService.HasPass(player, key) then
		return 1
	end
	return pass.Multiplier or 1
end

local function publishPasses(player: Player)
	ReplicaService.Set(player, "Passes", table.clone(owned[player] or {}))
	player:SetAttribute("VIP", ShopService.HasPass(player, "VIP"))
end

-- Donne un passe (acheté en jeu ou trouvé chez Roblox). remember : le noter dans la sauvegarde.
local function grantPass(player: Player, key: string, remember: boolean)
	local set = owned[player]
	local data = DataService.Get(player)
	if not set or not data then
		return
	end
	if remember then
		data.Passes[key] = true
	end
	if set[key] then
		return
	end
	set[key] = true
	publishPasses(player)
	Signals.Fire("PassOwned", player, key)
end

-- Retire un passe que Roblox dit ne plus être au joueur
local function revokePass(player: Player, key: string)
	local set = owned[player]
	local data = DataService.Get(player)
	local here = boughtHere[player]
	if not set or not data or (here and here[key]) then
		return
	end
	data.Passes[key] = nil
	if not set[key] then
		return
	end
	set[key] = nil
	publishPasses(player)
	Signals.Fire("PassLost", player, key)
end

-- Demande à Roblox chaque passe en vente (achetés hors du jeu, remboursés). Peut attendre.
local function checkPasses(player: Player)
	for key, pass in Shop.Passes do
		if pass.Id == 0 then
			continue
		end
		for attempt = 1, PASS_CHECK_ATTEMPTS do
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if not owned[player] then
				return -- parti pendant la question
			end
			if ok then
				if result == true then
					grantPass(player, key, true)
				elseif result == false then
					revokePass(player, key)
				end
				break
			end
			if attempt < PASS_CHECK_ATTEMPTS then
				task.wait(2 * attempt)
			end
		end
	end
end

-- ===== Server Luck =====

function ShopService.ServerLuck(): number
	return if os.time() < luckEndsAt then Shop.ServerLuck.Multiplier else 1
end

function ShopService.ServerLuckEndsAt(): number
	return if os.time() < luckEndsAt then luckEndsAt else 0
end

local function publishLuck()
	Workspace:SetAttribute("ServerLuck", ShopService.ServerLuck())
	Workspace:SetAttribute("ServerLuckEndsAt", ShopService.ServerLuckEndsAt())
	Signals.Fire("ServerLuckChanged", ShopService.ServerLuck(), ShopService.ServerLuckEndsAt())
end

-- ===== prix =====

-- Prix Robux lu sur Roblox (GetProductInfoAsync), gardé Config.Shop.PriceCacheSeconds. nil si Roblox ne répond pas.
-- Peut attendre (appel web).
function ShopService.Price(kind: PriceKind, id: number): number?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	local key = kind .. ":" .. tostring(id)
	local cached = prices[key]
	local now = os.clock()
	if cached then
		local maxAge = if cached.Price ~= nil then Shop.PriceCacheSeconds else PRICE_RETRY
		if cached.Fetching or now - cached.At < maxAge then
			return cached.Price
		end
	end
	local entry: CachedPrice = cached or { Price = nil, At = now, Fetching = false }
	prices[key] = entry
	entry.Fetching = true
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, if kind == "Product" then Enum.InfoType.Product else Enum.InfoType.GamePass)
	end)
	entry.Fetching = false
	entry.At = os.clock()
	if ok and type(info) == "table" then
		local price = Guard.Integer(info.PriceInRobux, 0)
		if price then
			entry.Price = price
		end
	end
	return entry.Price
end

-- Lit tous les prix en avance (au démarrage), pour que le shop s'ouvre sans attendre
local function prefetchPrices()
	local function fetch(kind: PriceKind, id: number)
		if id ~= 0 then
			task.spawn(function()
				ShopService.Price(kind, id)
			end)
		end
	end
	for _, pass in Shop.Passes do
		fetch("GamePass", pass.Id)
	end
	for _, product in Shop.Products do
		fetch("Product", product.Id)
	end
	for _, level in Shop.Treadmill.Levels do
		fetch("Product", level.Id)
	end
end

-- ===== contenu du shop =====

function ShopService.RegisterSection(name: string, section: Section)
	if type(name) ~= "string" or name == "" or type(section) ~= "function" then
		error("ShopService.RegisterSection : il faut un nom et une fonction", 2)
	end
	if sections[name] or name == "Passes" or name == "Products" or name == "ServerLuck" then
		error("ShopService.RegisterSection : section déjà prise " .. name, 2)
	end
	sections[name] = section
end

local function byOrder(a: { Order: number, Key: string }, b: { Order: number, Key: string }): boolean
	if a.Order ~= b.Order then
		return a.Order < b.Order
	end
	return a.Key < b.Key
end

-- Contenu du shop pour un joueur : seulement ce qui est en vente (Id ≠ 0), avec le prix de Roblox
function ShopService.Get(player: Player): { [string]: any }
	local passes = {}
	for key, pass in Shop.Passes do
		if pass.Id ~= 0 then
			table.insert(passes, {
				Key = key,
				Name = pass.Name,
				Description = pass.Description,
				Order = pass.Order,
				Owned = ShopService.HasPass(player, key),
				Price = ShopService.Price("GamePass", pass.Id),
				Trail = pass.Trail, -- (trail Robux : à montrer aussi avec les trails)
			})
		end
	end
	table.sort(passes, byOrder)
	local products = {}
	for key, product in Shop.Products do
		if ReceiptService.IsOnSale(key) then
			table.insert(products, {
				Key = key,
				Name = product.Name,
				Description = product.Description,
				Order = product.Order,
				Price = ShopService.Price("Product", product.Id),
			})
		end
	end
	table.sort(products, byOrder)
	local result: { [string]: any } = {
		Passes = passes,
		Products = products,
		ServerLuck = { Multiplier = ShopService.ServerLuck(), EndsAt = ShopService.ServerLuckEndsAt() },
	}
	for name, section in sections do
		local ok, value = pcall(section, player)
		if ok then
			result[name] = value
		else
			warn(string.format("[ShopService] section %s : %s", name, tostring(value)))
		end
	end
	return result
end

-- ===== achats =====

function ShopService.BuyPass(player: Player, rawKey: any): (boolean, string)
	local key = Guard.Key(rawKey, Shop.Passes)
	if not key then
		return false, "Unknown pass"
	end
	if not owned[player] then
		return false, "Please wait..."
	end
	local pass = Shop.Passes[key]
	if pass.Id == 0 then
		return false, "Coming soon!"
	end
	if ShopService.HasPass(player, key) then
		return false, "Already owned"
	end
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end)
	return ok, if ok then "" else "Try again"
end

local function buyProduct(player: Player, rawKey: any): (boolean, string)
	local key = Guard.Key(rawKey, Shop.Products)
	if not key then
		return false, "Unknown product"
	end
	if not owned[player] then
		return false, "Please wait..."
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

-- ===== cycle de vie =====

function ShopService.Init()
	-- Server Luck x2 : tout le serveur, Duration secondes (prolongé si déjà en cours)
	local luck = Shop.Products.ServerLuck
	ReceiptService.Register("ServerLuck", luck.Id, function()
		luckEndsAt = math.max(os.time(), luckEndsAt) + Shop.ServerLuck.Duration
		publishLuck()
		return true
	end)
	Signals.Connect("PurchaseGranted", function(player: Player, key: string)
		if key == "ServerLuck" then
			Notify.All(string.format("%s activated %s for everyone!", player.DisplayName, luck.Name), "success")
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key and player.Parent == Players and owned[player] then
			local here = boughtHere[player] or {}
			boughtHere[player] = here
			here[key] = true
			-- (un achat de test dans Studio ne va jamais dans la sauvegarde)
			grantPass(player, key, not RunService:IsStudio())
			Notify.Send(player, Shop.Passes[key].Name .. " unlocked!", "success")
		end
	end)

	Net.Function("GetShop", { Rate = 1, Burst = 3 }, function(player: Player)
		if not owned[player] then
			return nil
		end
		return ShopService.Get(player)
	end)
	Net.Function("BuyPass", { Rate = 1, Burst = 3 }, ShopService.BuyPass)
	Net.Function("BuyProduct", { Rate = 1, Burst = 3 }, buyProduct)

	AdminService.RegisterCommand("pass", {
		Description = "Give or remove a game pass for this server only (Studio only)",
		Usage = "pass <passKey> [player]",
		Run = function(player, args)
			if not RunService:IsStudio() then
				return false, "Studio only"
			end
			local key = Guard.Key(args[1], Shop.Passes)
			if not key then
				local keys = {}
				for passKey in Shop.Passes do
					table.insert(keys, passKey)
				end
				table.sort(keys)
				return false, "Passes: " .. table.concat(keys, ", ")
			end
			local target = AdminService.FindPlayer(player, args[2])
			local set = target and owned[target]
			if not target or not set then
				return false, "Player not found"
			end
			-- (session seulement : jamais noté dans la sauvegarde, un passe ne se donne pas gratuitement pour de bon)
			local give = not set[key]
			if give then
				set[key] = true
			else
				set[key] = nil
			end
			publishPasses(target)
			Signals.Fire(if give then "PassOwned" else "PassLost", target, key)
			return true, string.format("%s %s %s", target.Name, if give then "now has" else "lost", key)
		end,
	})
end

function ShopService.Start()
	publishLuck()
	prefetchPrices()
	while true do
		task.wait(1)
		if luckEndsAt ~= 0 and os.time() >= luckEndsAt then
			luckEndsAt = 0
			publishLuck()
			Notify.All("Server Luck has ended.", "info")
		end
	end
end

function ShopService.OnPlayerReady(player: Player, data: { [string]: any })
	local set: { [string]: boolean } = {}
	for key in data.Passes do
		set[key] = true
	end
	owned[player] = set
	publishPasses(player)
	-- (Roblox peut mettre du temps à répondre : jamais d'attente dans OnPlayerReady)
	task.spawn(checkPasses, player)
end

function ShopService.OnPlayerRemoving(player: Player)
	owned[player] = nil
	boughtHere[player] = nil
end

return ShopService
