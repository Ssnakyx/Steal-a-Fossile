-- ShopService : passes (trouvés chez Roblox, achetés en jeu, gardés si Roblox ne répond pas), produits cachés tant
-- qu'ils n'existent pas, Server Luck x2, contenu du shop avec les prix de Roblox, commande d'admin.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local Shop = Config.Shop
-- (passes et produits « créés dans le Creator Hub » pour ce test ; FastRevive et BearTraps5 restent à Id = 0)
Shop.Passes.DoubleMoney.Id = 501
Shop.Passes.VIP.Id = 502
Shop.Products.ServerLuck.Id = 601
Shop.Products.InstantRevive.Id = 602 -- (donné par ReviveService du brief 3 : en vente)
-- (produit de test avec un Id, mais qu'aucun service ne donne : doit rester caché)
Shop.Products.TestOrphan = { Id = 603, Name = "Test", Description = "Test", Price = 1, Order = 99, Owner = "Nobody" }
env.productPrices[501] = 299
env.productPrices[502] = 149
env.productPrices[601] = 99
env.productPrices[602] = 29
env.ownedPasses[401] = { [501] = true }
local Boot = T.bootServer()
local ShopService = Boot.Services.ShopService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local Enum = env.Enum
local Workspace = env.game:GetService("Workspace")
local market = env.game:GetService("MarketplaceService")
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted

local function call(player: any, name: string, ...: any): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, name, ...)
end

local owned = {}
Signals.Connect("PassOwned", function(p, key)
	table.insert(owned, { p, key })
end)

T.section("passes trouvés chez Roblox")
local player = T.join({ UserId = 401 })
env.advance(1)
T.check(ShopService.HasPass(player, "DoubleMoney"), "x2 Money acheté hors du jeu : trouvé")
T.check(T.data(player).Passes.DoubleMoney, "noté dans la sauvegarde")
T.eq(ShopService.PassMultiplier(player, "DoubleMoney"), 2, "PassMultiplier")
T.eq(ShopService.PassMultiplier(player, "VIP"), 1, "PassMultiplier sans le passe")
T.eq(ShopService.PassMultiplier(player, "Nope"), 1, "PassMultiplier passe inconnu")
T.check(not ShopService.HasPass(player, "VIP"), "pas VIP")
T.check(#owned == 1 and owned[1][2] == "DoubleMoney", "signal PassOwned")
env.flush()
local replica = ReplicaService.Get(player, "Passes")
T.check(replica and replica.DoubleMoney, "Replica Passes")
T.eq(player:GetAttribute("VIP"), false, "attribut VIP faux")

T.section("passe acheté en jeu")
local ok, text = call(player, "BuyPass", "VIP")
T.check(ok, "BuyPass VIP (" .. tostring(text) .. ")")
local prompt = env.prompts[#env.prompts]
T.check(prompt and prompt.Kind == "GamePass" and prompt.Id == 502 and prompt.Player == player, "achat du passe proposé")
env.fire(env.signal(market, "PromptGamePassPurchaseFinished"), player, 502, false)
T.check(not ShopService.HasPass(player, "VIP"), "fenêtre fermée sans acheter : rien")
env.fire(env.signal(market, "PromptGamePassPurchaseFinished"), player, 502, true)
env.flush()
T.check(ShopService.HasPass(player, "VIP"), "VIP acheté")
env.ownedPasses[401][502] = true
T.eq(player:GetAttribute("VIP"), true, "attribut VIP")
T.check(T.data(player).Passes.VIP, "VIP noté dans la sauvegarde")
env.fire(env.signal(market, "PromptGamePassPurchaseFinished"), player, 999, true)
T.clean("passe inconnu ignoré")
ok, text = call(player, "BuyPass", "VIP")
T.check(not ok and text == "Already owned", "déjà possédé")
ok, text = call(player, "BuyPass", "FastRevive")
T.check(not ok and text == "Coming soon!", "passe à Id = 0 caché")
ok, text = call(player, "BuyPass", "Nope")
T.check(not ok and text == "Unknown pass", "passe inconnu")

T.section("contenu du shop")
local shop = call(player, "GetShop")
T.check(type(shop) == "table", "GetShop")
local passKeys = {}
for _, pass in shop.Passes do
	passKeys[pass.Key] = pass
end
T.check(passKeys.DoubleMoney and passKeys.VIP, "passes en vente listés")
T.check(passKeys.FastRevive == nil and passKeys.DoubleTreadmill == nil, "passes à Id = 0 cachés")
T.eq(passKeys.DoubleMoney and passKeys.DoubleMoney.Price, 299, "prix du passe lu sur Roblox")
T.eq(passKeys.VIP and passKeys.VIP.Owned, true, "passe possédé marqué")
T.eq(shop.Passes[1] and shop.Passes[1].Key, "DoubleMoney", "passes dans l'ordre")
local productKeys = {}
for _, product in shop.Products do
	productKeys[product.Key] = product
end
T.check(productKeys.ServerLuck ~= nil, "Server Luck en vente")
T.eq(productKeys.ServerLuck and productKeys.ServerLuck.Price, 99, "prix du produit lu sur Roblox")
T.check(productKeys.BearTraps5 == nil, "produit à Id = 0 caché")
T.check(productKeys.InstantRevive ~= nil, "Instant Revive en vente (donné par ReviveService)")
T.check(productKeys.TestOrphan == nil, "produit sans service qui le donne caché")
T.check(shop.Treadmill ~= nil and shop.Treadmill.Level == 0, "section Treadmill")
T.eq(shop.ServerLuck.Multiplier, 1, "pas de Server Luck")
ok, text = call(player, "BuyProduct", "BearTraps5")
T.check(not ok and text == "Coming soon!", "produit caché pas achetable")
ok, text = call(player, "BuyProduct", "TestOrphan")
T.check(not ok and text == "Coming soon!", "produit sans service pas achetable")
ok, text = call(player, "BuyProduct", "Nope")
T.check(not ok and text == "Unknown product", "produit inconnu")
T.errors(function()
	ShopService.RegisterSection("Passes", function() end)
end, "déjà prise", "section réservée")

T.section("Server Luck")
local changes = {}
Signals.Connect("ServerLuckChanged", function(multiplier, endsAt)
	table.insert(changes, { multiplier, endsAt })
end)
ok = call(player, "BuyProduct", "ServerLuck")
T.check(ok and env.prompts[#env.prompts].Id == 601, "achat Server Luck proposé")
local start = env.os.time()
T.eq(env.purchase(player, 601, { PurchaseId = "L1" }), GRANTED, "Server Luck acheté")
env.flush()
T.eq(ShopService.ServerLuck(), 2, "chance x2")
T.eq(Workspace:GetAttribute("ServerLuck"), 2, "attribut ServerLuck")
local endsAt = Workspace:GetAttribute("ServerLuckEndsAt")
T.check(endsAt >= start + Shop.ServerLuck.Duration and endsAt <= start + Shop.ServerLuck.Duration + 1, "fin dans 15 min")
T.check(#changes >= 1 and changes[#changes][1] == 2, "signal ServerLuckChanged")
local announced = false
for _, args in env.received(player, "Notify") do
	if string.find(args[1], "Server Luck", 1, true) then
		announced = true
	end
end
T.check(announced, "annoncé à tout le serveur")
env.advance(60)
T.eq(env.purchase(player, 601, { PurchaseId = "L2" }), GRANTED, "deuxième Server Luck")
T.check(Workspace:GetAttribute("ServerLuckEndsAt") >= endsAt + Shop.ServerLuck.Duration, "temps ajouté au temps restant")
T.eq(env.purchase(player, 601, { PurchaseId = "L2" }), GRANTED, "même reçu rejoué")
T.check(Workspace:GetAttribute("ServerLuckEndsAt") < endsAt + 2 * Shop.ServerLuck.Duration, "pas prolongé deux fois par le même reçu")
env.advance(2 * Shop.ServerLuck.Duration)
T.eq(ShopService.ServerLuck(), 1, "Server Luck fini")
T.eq(Workspace:GetAttribute("ServerLuck"), 1, "attribut remis à 1")
T.eq(Workspace:GetAttribute("ServerLuckEndsAt"), 0, "fin remise à 0")

T.section("prix")
ShopService.Price("GamePass", 501)
local fetches = 0
local realInfo = market.GetProductInfoAsync
env.stubMethod("MarketplaceService", "GetProductInfoAsync", function(self, id, kind)
	fetches += 1
	return realInfo(self, id, kind)
end)
T.eq(ShopService.Price("GamePass", 501), 299, "prix en cache")
T.eq(fetches, 0, "pas redemandé pendant le cache")
env.stubMethod("MarketplaceService", "GetProductInfoAsync", function()
	fetches += 1
	error("HTTP 503")
end)
env.advance(Shop.PriceCacheSeconds + 1)
T.eq(ShopService.Price("GamePass", 501), 299, "Roblox en panne : ancien prix gardé")
T.eq(ShopService.Price("Product", 123456), nil, "prix inconnu : nil")
local failed = fetches
T.eq(ShopService.Price("Product", 123456), nil, "pas redemandé tout de suite")
T.eq(fetches, failed, "pas de spam vers Roblox")
T.eq(ShopService.Price("Product", 0), nil, "Id 0 : pas de prix")
T.eq(ShopService.Price("Product", 0 / 0), nil, "Id NaN : pas de prix")
env.stubMethod("MarketplaceService", "GetProductInfoAsync", realInfo)
T.clean("aucune erreur avec les prix")

T.section("passes gardés si Roblox ne répond pas")
T.leave(player)
T.check(env.saved("SAF_Players_1", "Player_401").Passes.VIP, "passes écrits")
local realOwns = market.UserOwnsGamePassAsync
env.stubMethod("MarketplaceService", "UserOwnsGamePassAsync", function()
	error("HTTP 500")
end)
local back = T.join({ UserId = 401 })
env.advance(30)
T.check(ShopService.HasPass(back, "VIP") and ShopService.HasPass(back, "DoubleMoney"), "passes de la sauvegarde")
T.eq(back:GetAttribute("VIP"), true, "VIP tout de suite")
local newcomer = T.join({ UserId = 402 })
env.advance(30)
T.check(not ShopService.HasPass(newcomer, "DoubleMoney"), "nouveau joueur : rien sans réponse de Roblox")
env.stubMethod("MarketplaceService", "UserOwnsGamePassAsync", realOwns)
T.clean("aucune erreur quand Roblox ne répond pas")

T.section("passe remboursé")
local lost = {}
Signals.Connect("PassLost", function(p, key)
	table.insert(lost, { p, key })
end)
T.leave(back)
env.ownedPasses[401][501] = nil -- (x2 Money remboursé)
local refunded = T.join({ UserId = 401 })
env.advance(5)
T.check(not ShopService.HasPass(refunded, "DoubleMoney"), "Roblox dit non : passe retiré")
T.check(not T.data(refunded).Passes.DoubleMoney, "retiré de la sauvegarde")
T.check(ShopService.HasPass(refunded, "VIP"), "les autres passes restent")
T.check(#lost == 1 and lost[1][2] == "DoubleMoney", "signal PassLost")
env.flush()
T.check(ReplicaService.Get(refunded, "Passes").DoubleMoney == nil, "Replica à jour")
-- (Roblox peut répondre « non » juste après un achat sur ce serveur : ce passe-là n'est jamais retiré)
local fresh = T.join({ UserId = 404 })
env.advance(5)
env.fire(env.signal(market, "PromptGamePassPurchaseFinished"), fresh, 501, true)
env.flush()
T.check(ShopService.HasPass(fresh, "DoubleMoney"), "acheté sur ce serveur")

T.section("admin")
local admin = T.join({ UserId = 3346721423 })
ok, text = AdminService.Run(admin, "pass", { "DoubleTreadmill" })
T.check(not ok and text == "Studio only", "pass réservé à Studio")
env.studio = true
ok = AdminService.Run(admin, "pass", { "DoubleTreadmill" })
T.check(ok and ShopService.HasPass(admin, "DoubleTreadmill"), "pass donné dans Studio")
T.check(not T.data(admin).Passes.DoubleTreadmill, "pas noté dans la sauvegarde")
ok = AdminService.Run(admin, "pass", { "DoubleTreadmill" })
T.check(ok and not ShopService.HasPass(admin, "DoubleTreadmill"), "pass retiré")
ok, text = AdminService.Run(admin, "pass", { "Nope" })
T.check(not ok and string.find(text, "VIP", 1, true) ~= nil, "pass inconnu : liste des passes")
env.studio = false

T.section("joueur pas chargé")
env.datastore.latency = 5
local loading = env.addPlayer({ UserId = 403 })
local result = env.invokeServer(loading, "GetShop")
T.eq(result, nil, "GetShop avant le chargement : rien")
ok, text = env.invokeServer(loading, "BuyPass", "VIP")
T.check(not ok and text == "Please wait...", "BuyPass avant le chargement")
env.datastore.latency = 0
env.advance(10)
T.clean("aucune erreur avant le chargement")

T.done("speed_shop")
