-- ReceiptService : achats Robux idempotents, produits Id = 0 cachés, pannes de sauvegarde, achats simulés
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Boot = T.bootServer()
local ReceiptService = Boot.Services.ReceiptService
local MoneyService = Boot.Services.MoneyService
local Signals = T.lib("Signals")
local Core = T.config().Core
local Enum = env.Enum

local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet

local grants = 0
ReceiptService.Register("TestCoins", 111, function(player, _data, _receipt)
	grants += 1
	return MoneyService.Add(player, 100, "TestCoins")
end)
ReceiptService.Register("TestHidden", 0, function(_player, data)
	data.TreadmillLevel += 1
	return true
end)
ReceiptService.Register("TestRefuse", 113, function()
	return false
end)
ReceiptService.Register("TestBoom", 114, function()
	error("boom")
end)

T.section("enregistrement")
T.errors(function()
	ReceiptService.Register("TestCoins", 120, function()
		return true
	end)
end, "déjà enregistré", "clé en double")
T.errors(function()
	ReceiptService.Register("Other", 111, function()
		return true
	end)
end, "déjà pris", "Id en double")
T.errors(function()
	ReceiptService.Register("Neg", -1, function()
		return true
	end)
end, "Id invalide", "Id négatif")
T.errors(function()
	ReceiptService.Register("Frac", 1.5, function()
		return true
	end)
end, "Id invalide", "Id décimal")
T.errors(function()
	ReceiptService.Register("NoGrant", 130, nil :: any)
end, "Grant", "sans fonction Grant")
T.check(ReceiptService.IsOnSale("TestCoins"), "produit créé en vente")
T.check(not ReceiptService.IsOnSale("TestHidden"), "Id = 0 caché")
T.check(not ReceiptService.IsOnSale("Nope"), "produit inconnu pas en vente")
T.eq(ReceiptService.ProductId("TestCoins"), 111, "ProductId")
T.check(env.callback(env.game:GetService("MarketplaceService"), "ProcessReceipt") == ReceiptService.Process, "ProcessReceipt posé")

T.section("achat réel")
local player = T.join({ UserId = 1 })
local granted = {}
Signals.Connect("PurchaseGranted", function(p, key, robux)
	table.insert(granted, { p, key, robux })
end)
T.eq(env.purchase(player, 111, { PurchaseId = "P1", Price = 25 }), GRANTED, "achat donné")
T.eq(MoneyService.Get(player), 100, "argent donné")
T.eq(T.data(player).RobuxSpent, 25, "Robux comptés")
T.check(ReceiptService.HasProcessed(player, "P1"), "achat noté")
local saved = env.saved("SAF_Players_1", "Player_1")
T.check(table.find(saved.Purchases, "P1") ~= nil and saved.Money == 100, "achat écrit tout de suite")
env.flush()
T.eq(#granted, 1, "signal PurchaseGranted")
T.check(granted[1] and granted[1][2] == "TestCoins" and granted[1][3] == 25, "signal avec la clé et le prix")

T.section("idempotence")
T.eq(env.purchase(player, 111, { PurchaseId = "P1", Price = 25 }), GRANTED, "même achat rejoué : accepté")
T.eq(MoneyService.Get(player), 100, "même achat rejoué : pas donné deux fois")
T.eq(grants, 1, "Grant appelé une fois")
env.datastore.latency = 2
local first = nil
env.task.spawn(function()
	first = env.purchase(player, 111, { PurchaseId = "P2", Price = 25 })
end)
T.eq(env.purchase(player, 111, { PurchaseId = "P2", Price = 25 }), NOT_YET, "achat en cours : le doublon attend")
env.advance(5)
env.datastore.latency = 0
T.eq(first, GRANTED, "premier appel donné")
T.eq(MoneyService.Get(player), 200, "donné une seule fois")

T.section("refus")
T.eq(env.purchase(player, 999, { PurchaseId = "P3" }), NOT_YET, "produit inconnu")
T.eq(env.purchase(player, 0, { PurchaseId = "P4" }), NOT_YET, "Id 0 jamais vendu pour de vrai")
T.eq(T.data(player).TreadmillLevel, 0, "produit caché pas donné")
T.eq(env.purchase(player, 113, { PurchaseId = "P5" }), NOT_YET, "Grant refusé")
T.eq(env.purchase(player, 114, { PurchaseId = "P6" }), NOT_YET, "Grant en erreur")
T.check(not ReceiptService.HasProcessed(player, "P5") and not ReceiptService.HasProcessed(player, "P6"), "refus non notés")
T.eq(ReceiptService.Process({ PlayerId = 424242, ProductId = 111, PurchaseId = "P7", CurrencySpent = 5 }), NOT_YET, "joueur absent")
T.eq(ReceiptService.Process({}), NOT_YET, "reçu vide")
T.eq(ReceiptService.Process({ PlayerId = "x", ProductId = {}, PurchaseId = nil }), NOT_YET, "reçu abîmé")
T.eq(MoneyService.Get(player), 200, "rien donné par les refus")

T.section("sauvegarde en panne")
env.datastore.fail(3)
T.eq(env.purchase(player, 111, { PurchaseId = "P8", Price = 10 }), NOT_YET, "pas confirmé si l'écriture rate")
T.eq(MoneyService.Get(player), 300, "donné en mémoire")
env.datastore.failures = 0
T.eq(env.purchase(player, 111, { PurchaseId = "P8", Price = 10 }), GRANTED, "confirmé au nouvel essai")
T.eq(MoneyService.Get(player), 300, "pas donné deux fois après la panne")
T.check(table.find(env.saved("SAF_Players_1", "Player_1").Purchases, "P8") ~= nil, "écrit au nouvel essai")
local spent = T.data(player).RobuxSpent
T.eq(ReceiptService.Process({ PlayerId = 1, ProductId = 111, PurchaseId = "P9", CurrencySpent = 0 / 0 }), GRANTED, "prix NaN")
T.eq(T.data(player).RobuxSpent, spent, "prix NaN compté 0")

T.section("achat simulé")
local remembered = #T.data(player).Purchases
local ok, text = ReceiptService.Simulate(player, "TestHidden")
T.check(ok, "Simulate donne un produit Id = 0 (" .. text .. ")")
T.eq(T.data(player).TreadmillLevel, 1, "produit simulé donné")
T.eq(#T.data(player).Purchases, remembered, "achat simulé sans PurchaseId pas noté (la liste garde les vrais achats)")
T.eq(T.data(player).RobuxSpent, spent, "achat simulé gratuit")
ok = ReceiptService.Simulate(player, "Nope")
T.check(not ok, "Simulate produit inconnu")
ok = ReceiptService.Simulate(player, "TestHidden", "SIM-fixed")
T.check(ok, "Simulate avec PurchaseId")
ok = ReceiptService.Simulate(player, "TestHidden", "SIM-fixed")
T.check(ok, "Simulate rejoué accepté")
T.eq(T.data(player).TreadmillLevel, 2, "Simulate rejoué pas donné deux fois")

T.section("mémoire des achats")
for index = 1, Core.Purchases.Remember + 20 do
	ReceiptService.Simulate(player, "TestCoins", "BULK-" .. index)
end
T.eq(#T.data(player).Purchases, Core.Purchases.Remember, "liste des achats bornée")
T.check(ReceiptService.HasProcessed(player, "BULK-" .. (Core.Purchases.Remember + 20)), "dernier achat gardé")

T.section("joueur qui revient")
T.leave(player)
local back = T.join({ UserId = 1 })
T.check(ReceiptService.HasProcessed(back, "BULK-50"), "achats notés rechargés")
T.eq(env.purchase(back, 111, { PurchaseId = "BULK-50" }), GRANTED, "achat d'une autre session pas redonné")
T.eq(grants, 4 + Core.Purchases.Remember + 20, "aucun Grant de trop (P1, P2, P8, P9 et les achats en série)")

table.clear(Boot.Errors)
T.done("core_receipts")
