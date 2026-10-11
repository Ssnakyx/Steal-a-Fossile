-- OfferService : packs d'argent (montant selon le revenu), Starter Pack (une fois, premiers jours), pack Limited et
-- offre du jour (rotation), pack caché si un de ses passes est déjà possédé, cadeaux (joueur choisi, cadeau gardé si
-- le joueur est parti, envoi d'un cadeau déjà payé), passes donnés jamais retirés, section « Offers » de GetShop.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local Shop = Config.Shop
local now0 = env.baseTime
local current = Shop.Current(now0)
-- (« créés dans le Creator Hub » pour ce test ; le reste reste à Id = 0)
Shop.Cash.CashSmall.Id = 801
Shop.Cash.CashHuge.Id = 802
Shop.Packs.Starter.Id = 811
Shop.Packs[current.Limited].Id = 812
Shop.Packs[current.Deal].Id = 813
Shop.Gifts.DoubleMoney.Id = 821
Shop.Gifts.VIP.Id = 822
Shop.Passes.DoubleMoney.Id = 501
env.productPrices[801] = 49
env.productPrices[811] = 99
env.productPrices[821] = 299
local Boot = T.bootServer()
local OfferService = Boot.Services.OfferService
local ShopService = Boot.Services.ShopService
local ReplicaService = Boot.Services.ReplicaService
local RewardService = Boot.Services.RewardService
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local GRANTED = env.Enum.ProductPurchaseDecision.PurchaseGranted

local function call(player: any, name: string, ...: any): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, name, ...)
end

local function packKeys(offers: any): { [string]: any }
	local out = {}
	for _, entry in offers.Packs do
		out[entry.Key] = entry
	end
	return out
end

T.check(OfferService ~= nil, "OfferService chargé")

T.section("rotation des offres")
local later = Shop.Current(now0 + Shop.Rotation.LimitedDays * 86400)
T.check(later.Limited ~= current.Limited, "le pack Limited change après LimitedDays jours")
T.eq(current.LimitedEnds - now0 <= Shop.Rotation.LimitedDays * 86400, true, "fin du Limited dans moins de LimitedDays jours")
T.check(Shop.Current(now0 + 86400).Deal ~= current.Deal, "l'offre du jour change chaque jour")
for _, key in Shop.Rotation.Limited do
	T.eq(Shop.Packs[key] and Shop.Packs[key].Kind, "Limited", "rotation Limited : " .. key)
end
for _, key in Shop.Rotation.Deals do
	T.eq(Shop.Packs[key] and Shop.Packs[key].Kind, "Deal", "rotation Deals : " .. key)
end
for key, pack in Shop.Packs do
	T.check(pack.Worth > pack.Price, key .. " : prix barré plus haut que le prix")
	for _, item in pack.Items do
		T.check(item.Kind ~= "Spins" and item.Kind ~= "Block", key .. " : jamais de hasard payant ni de bloc")
		if item.Kind == "Pass" then
			T.check(Shop.Passes[item.Key] ~= nil, key .. " : passe connu " .. tostring(item.Key))
		end
	end
end

T.section("section Offers de GetShop")
local player = T.join({ UserId = 701, Name = "Buyer" })
env.advance(1)
local shop = call(player, "GetShop")
local offers = shop and shop.Offers
T.check(type(offers) == "table", "section Offers")
local cashKeys = {}
for _, entry in offers.Cash do
	cashKeys[entry.Key] = entry
end
T.check(cashKeys.CashSmall and cashKeys.CashHuge, "packs d'argent en vente")
T.check(cashKeys.CashMedium == nil and cashKeys.CashLarge == nil, "packs d'argent à Id = 0 cachés")
T.eq(cashKeys.CashSmall.Price, 49, "prix lu sur Roblox")
T.eq(cashKeys.CashSmall.Amount, Shop.Cash.CashSmall.Reward.Amount, "sans revenu : le minimum")
T.check(cashKeys.CashHuge.Best == true and cashKeys.CashHuge.Bonus > 0, "le plus gros : BEST VALUE (+" .. tostring(cashKeys.CashHuge.Bonus) .. "%)")
T.eq(cashKeys.CashSmall.Bonus, 0, "le plus petit : pas de bonus")
local packs = packKeys(offers)
T.check(packs.Starter ~= nil, "Starter Pack proposé à un nouveau joueur")
T.check(packs[current.Limited] ~= nil, "pack Limited du moment")
T.check(packs[current.Deal] ~= nil, "offre du jour")
T.check(packs[later.Limited] == nil, "les autres Limited cachés")
T.near(packs.Starter.EndsAt, T.data(player).FirstJoin + Shop.StarterHours * 3600, 1, "fin du Starter Pack")
T.eq(packs[current.Deal].EndsAt, current.DealEnds, "fin de l'offre du jour")
T.check(#packs.Starter.Items == #Shop.Packs.Starter.Items, "contenu du Starter Pack en texte")
T.check(offers.Gifts.DoubleMoney and offers.Gifts.VIP and offers.Gifts.FastRevive == nil, "cadeaux en vente seulement")

T.section("pack d'argent")
local data = T.data(player)
local before = data.Money
T.eq(env.purchase(player, 801, { PurchaseId = "C1" }), GRANTED, "pack d'argent acheté")
T.eq(data.Money, before + Shop.Cash.CashSmall.Reward.Amount, "argent donné")
local ok, text = call(player, "BuyOffer", "CashSmall")
T.check(ok and env.prompts[#env.prompts].Id == 801, "BuyOffer propose le pack d'argent (" .. tostring(text) .. ")")
ok, text = call(player, "BuyOffer", "CashMedium")
T.check(not ok and text == "Coming soon!", "pack à Id = 0 : pas en vente")
ok, text = call(player, "BuyOffer", "Nope")
T.check(not ok and text == "Unknown offer", "offre inconnue")
ok, text = call(player, "BuyOffer", later.Limited)
T.check(not ok and text == "This offer has ended", "Limited pas en cours : pas achetable")
-- (le montant suit le revenu : 10 min d'un revenu de $1K/s = $600K)
local IncomeServiceStub = Boot.Services.IncomeService
local realIncome = IncomeServiceStub.GetIncome
IncomeServiceStub.GetIncome = function()
	return 1000
end
T.eq(RewardService.Scale(player).Income, 1000, "revenu simulé")
before = data.Money
T.eq(env.purchase(player, 801, { PurchaseId = "C2" }), GRANTED, "pack d'argent avec revenu")
T.eq(data.Money, before + 1000 * 60 * 10, "10 min de revenu")
IncomeServiceStub.GetIncome = realIncome

T.section("Starter Pack")
local traps = data.BearTraps
local bought = {}
Signals.Connect("PackBought", function(p, key)
	table.insert(bought, { p, key })
end)
T.eq(env.purchase(player, 811, { PurchaseId = "S1" }), GRANTED, "Starter Pack acheté")
T.check(ShopService.HasPass(player, "NeonTrail"), "Neon Trail donnée")
T.check(data.Offers.Granted.NeonTrail, "passe noté comme donné")
T.eq(data.BearTraps, traps + 10, "10 Bear Traps")
T.eq(data.InstantCredits, 3, "3 Instant Revive gardés (aucune cuve en cours)")
T.check(data.Trails.Equipped == "Neon", "trail Neon portée tout de suite")
T.eq(data.Offers.Bought.Starter, 1, "achat noté")
T.check(#bought == 1 and bought[1][2] == "Starter", "signal PackBought")
packs = packKeys(call(player, "GetShop").Offers)
T.check(packs.Starter == nil, "Starter Pack plus proposé après l'achat")
ok, text = call(player, "BuyOffer", "Starter")
T.check(not ok and text == "This offer has ended", "plus achetable")
T.eq(env.purchase(player, 811, { PurchaseId = "S1" }), GRANTED, "même reçu rejoué")
T.eq(data.Offers.Bought.Starter, 1, "pas donné deux fois")

T.section("passe donné jamais retiré")
T.leave(player)
local back = T.join({ UserId = 701, Name = "Buyer" })
env.advance(5)
T.check(ShopService.HasPass(back, "NeonTrail"), "Neon Trail gardée (Roblox ne connaît pas ce passe)")
env.flush()
T.check(ReplicaService.Get(back, "Passes").NeonTrail, "Replica Passes")
player = back
data = T.data(player)

T.section("pack caché si un passe est déjà possédé")
local fresh = T.join({ UserId = 702 })
env.advance(1)
local limitedPass: string? = nil
for _, item in Shop.Packs[current.Limited].Items do
	if item.Kind == "Pass" then
		limitedPass = item.Key
	end
end
if limitedPass then
	T.check(packKeys(call(fresh, "GetShop").Offers)[current.Limited] ~= nil, "Limited proposé")
	ShopService.GrantPass(fresh, limitedPass)
	T.check(packKeys(call(fresh, "GetShop").Offers)[current.Limited] == nil, "Limited caché : " .. limitedPass .. " déjà possédé")
	-- (reçu arrivé quand même : le passe déjà possédé devient de l'argent)
	local money = T.data(fresh).Money
	T.eq(env.purchase(fresh, 812, { PurchaseId = "L1" }), GRANTED, "reçu du Limited donné")
	T.check(T.data(fresh).Money > money, "passe déjà possédé : remplacé par de l'argent")
end
T.section("Starter Pack fini après StarterHours")
T.data(fresh).FirstJoin = env.os.time() - Shop.StarterHours * 3600 - 1
T.check(packKeys(call(fresh, "GetShop").Offers).Starter == nil, "plus proposé après 3 jours")

T.section("cadeaux")
local friend = T.join({ UserId = 703, Name = "Friend" })
env.advance(1)
local sent = {}
Signals.Connect("GiftSent", function(buyer, target, key)
	table.insert(sent, { buyer, target, key })
end)
ok, text = call(player, "GiftPass", "DoubleMoney", friend.UserId)
T.check(ok and env.prompts[#env.prompts].Id == 821, "achat du cadeau proposé (" .. tostring(text) .. ")")
T.eq(env.purchase(player, 821, { PurchaseId = "G1" }), GRANTED, "cadeau payé")
T.check(ShopService.HasPass(friend, "DoubleMoney"), "x2 Money donné à l'ami")
T.check(not ShopService.HasPass(player, "DoubleMoney"), "pas à l'acheteur")
T.check(T.data(friend).Offers.Granted.DoubleMoney, "noté chez l'ami")
T.eq(T.data(friend).Offers.GiftsReceived, 1, "GiftsReceived")
T.eq(data.Offers.GiftsSent, 1, "GiftsSent")
T.check(#sent == 1 and sent[1][2] == friend, "signal GiftSent")
local told = false
for _, args in env.received(friend, "Notify") do
	if string.find(args[1], "gifted you", 1, true) then
		told = true
	end
end
T.check(told, "l'ami est prévenu")
ok, text = call(player, "GiftPass", "DoubleMoney", friend.UserId)
T.check(not ok and string.find(text, "already has", 1, true) ~= nil, "l'ami l'a déjà : refusé")
ok, text = call(player, "GiftPass", "VIP", player.UserId)
T.check(not ok and string.find(text, "yourself", 1, true) ~= nil, "pas à soi-même")
ok, text = call(player, "GiftPass", "VIP", 999999)
T.check(not ok, "joueur absent")
ok, text = call(player, "GiftPass", "FastRevive", friend.UserId)
T.check(not ok and text == "Coming soon!", "cadeau à Id = 0 : pas en vente")
ok, text = call(player, "GiftPass", "Nope", friend.UserId)
T.check(not ok and text == "Unknown pass", "passe inconnu")

T.section("cadeau gardé quand le joueur choisi part")
ok = call(player, "GiftPass", "VIP", friend.UserId)
T.check(ok, "achat du cadeau VIP proposé")
T.leave(friend)
T.eq(env.purchase(player, 822, { PurchaseId = "G2" }), GRANTED, "cadeau payé après le départ de l'ami")
T.eq(data.Offers.GiftCredits.VIP, 1, "cadeau gardé")
env.flush()
T.eq(ReplicaService.Get(player, "GiftCredits").VIP, 1, "Replica GiftCredits")
local other = T.join({ UserId = 704, Name = "Other" })
env.advance(1)
local prompts = #env.prompts
ok, text = call(player, "GiftPass", "VIP", other.UserId)
T.check(ok and string.find(text, "Gift sent", 1, true) ~= nil, "cadeau déjà payé envoyé (" .. tostring(text) .. ")")
T.eq(#env.prompts, prompts, "sans repasser par Roblox")
T.check(ShopService.HasPass(other, "VIP"), "VIP donné")
T.eq(other:GetAttribute("VIP"), true, "attribut VIP")
T.eq(data.Offers.GiftCredits.VIP, nil, "cadeau utilisé")
T.eq(env.purchase(player, 822, { PurchaseId = "G3" }), GRANTED, "reçu sans cadeau en cours")
T.eq(data.Offers.GiftCredits.VIP, 1, "gardé pour plus tard")

T.section("hostile")
for _, value in T.hostileValues() do
	call(player, "BuyOffer", value)
	call(player, "GiftPass", value, value)
	call(player, "GiftPass", "VIP", value)
end
T.clean("valeurs abîmées sans erreur")

T.done("offers_server")
