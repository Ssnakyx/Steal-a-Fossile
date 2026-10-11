-- Roue de la chance (SpinService) : tour gratuit du jour, tours en réserve, recharge entre deux tours, tirage selon les
-- Weight, produits Robux (idempotents), achats au hasard payants cachés quand PolicyService les interdit, tour gratuit
-- revenu le lendemain, commande spins, appels hostiles.
local T = require("./testkit")
local env = T.env

env.studio = false -- (sauvegardes écrites ; la commande spins repasse en Studio, où tout le monde est admin)
env.quiet = true
local Config = T.config()
local Daily = Config.Daily
local Products = Daily.Spins.Products
-- (produits « créés dans le Creator Hub » pour ce test)
Products.Spins3.Id = 9301
Products.Spins10.Id = 9302
env.productPrices[9301] = 49
env.productPrices[9302] = 129
-- PolicyService : achats au hasard payants interdits pour le joueur 666, Roblox en panne pour le joueur 667
env.stubMethod("PolicyService", "GetPolicyInfoForPlayerAsync", function(_, player)
	if player.UserId == 667 then
		error("HTTP 500 (simulated)")
	end
	return { ArePaidRandomItemsRestricted = player.UserId == 666 }
end)
local Boot = T.bootServer()
local SpinService = Boot.Services.SpinService
local DailyService = Boot.Services.DailyService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local Enum = env.Enum
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local COOLDOWN = Daily.Spins.Cooldown

local done = {}
Signals.Connect("SpinDone", function(p, index)
	table.insert(done, { p, index })
end)

local function spin(player: any): (any, any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, "Spin")
end

T.section("tirage")
local total = 0
for _, prize in Daily.Spins.Prizes do
	total += prize.Weight
	T.check(prize.Weight > 0, prize.Name .. " : chance positive")
	T.check(Daily.Amount(prize.Reward, nil) > 0, prize.Name .. " : récompense valide")
end
T.eq(#Daily.Spins.Prizes, 8, "8 cases")
local chances = 0
for index in Daily.Spins.Prizes do
	chances += Daily.Chance(index)
end
T.near(chances, 1, 1e-9, "les chances affichées font 100 %")
local counts = {}
local DRAWS = 40000
for _ = 1, DRAWS do
	local index = SpinService.Pick()
	counts[index] = (counts[index] or 0) + 1
end
for index, prize in Daily.Spins.Prizes do
	local expected = prize.Weight / total
	local got = (counts[index] or 0) / DRAWS
	T.check(math.abs(got - expected) < 0.012, string.format("%s tiré %.3f (attendu %.3f)", prize.Name, got, expected))
end

T.section("tour gratuit")
local player = T.join({ UserId = 401, Character = true })
env.flush()
local state = ReplicaService.Get(player, "Spins")
T.check(type(state) == "table", "Replica Spins")
T.eq(state.Free, 1, "1 tour gratuit")
T.eq(state.Stored, 0, "aucun tour en réserve")
T.eq(state.CanBuy, true, "achats permis (PolicyService) et produits en vente")
local granted = #env.received(player, "RewardGranted")
local ok, text, index = spin(player)
T.check(ok, "tour gratuit (" .. tostring(text) .. ")")
T.check(type(index) == "number" and Daily.Spins.Prizes[index] ~= nil, "case gagnée renvoyée")
T.eq(#env.received(player, "RewardGranted"), granted + 1, "gain envoyé au client")
T.eq(T.data(player).Spins.Total, 1, "tour compté")
T.eq(T.data(player).Spins.FreeUsed, 1, "tour gratuit utilisé")
T.check(#done == 1 and done[1][2] == index, "signal SpinDone")
state = ReplicaService.Get(player, "Spins")
T.eq(state.Free, 0, "plus de tour gratuit")
ok, text = spin(player)
T.check(not ok and text == "The wheel is still spinning!", "recharge entre deux tours")
T.advance(COOLDOWN + 0.1)
local stored = T.data(player).Spins.Stored
if stored == 0 then
	ok, text = spin(player)
	T.check(not ok and text == "No spins left! Play to earn more.", "plus de tour")
	T.eq(T.data(player).Spins.Total, 1, "rien de joué sans tour")
end

T.section("tours en réserve")
T.check(SpinService.Give(player, 3), "3 tours donnés")
T.eq(ReplicaService.Get(player, "Spins").Stored, stored + 3, "Replica Stored")
T.check(not SpinService.Give(player, 0), "0 tour refusé")
T.check(not SpinService.Give(player, 0 / 0), "NaN refusé")
T.check(not SpinService.Give(player, Daily.Spins.MaxStored), "réserve qui déborde refusée")
local before = T.data(player).Spins.Stored
ok = spin(player)
T.check(ok, "tour en réserve joué")
local after = T.data(player).Spins.Stored
-- (la case « Spin Again » rend un tour)
T.check(after == before - 1 or (after == before and Daily.Spins.Prizes[done[#done][2]].Reward.Kind == "Spins"), "un tour en réserve utilisé")
T.eq(T.data(player).Spins.Total, 2, "2 tours joués")

T.section("lendemain : tour gratuit revenu")
env.baseTime += Daily.DayLength
DailyService.CheckDay()
env.flush()
T.eq(ReplicaService.Get(player, "Spins").Free, 1, "nouveau tour gratuit")
T.advance(COOLDOWN + 0.1)
before = T.data(player).Spins.Stored
ok = spin(player)
T.check(ok, "tour gratuit du lendemain")
T.check(T.data(player).Spins.Stored >= before, "le tour gratuit passe avant la réserve")
T.eq(T.data(player).Spins.FreeDay, Daily.Day(env.baseTime + env.now()), "jour du tour gratuit noté")

T.section("produits Robux")
local stock = T.data(player).Spins.Stored
T.eq(env.purchase(player, 9301, { PurchaseId = "SP1" }), GRANTED, "3 Spins achetés")
env.flush()
T.eq(T.data(player).Spins.Stored - stock, 3, "+3 tours")
T.eq(env.purchase(player, 9301, { PurchaseId = "SP1" }), GRANTED, "même achat représenté")
env.flush()
T.eq(T.data(player).Spins.Stored - stock, 3, "pas donné deux fois")
T.eq(env.purchase(player, 9302, { PurchaseId = "SP2" }), GRANTED, "10 Spins achetés")
env.flush()
T.eq(T.data(player).Spins.Stored - stock, 13, "+10 tours")
T.check(env.saved("SAF_Players_1", "Player_401").Spins.Stored == stock + 13, "achat écrit tout de suite")
RateLimit.Reset(player)
local offers = env.invokeServer(player, "GetSpinOffers")
T.check(type(offers) == "table" and #offers == 2, "2 offres")
T.check(offers[1].Key == "Spins3" and offers[1].Price == 49 and offers[1].Count == 3, "offre 3 Spins avec le prix de Roblox")
T.check(offers[2].Key == "Spins10" and offers[2].Price == 129, "offre 10 Spins")
local prompts = #env.prompts
RateLimit.Reset(player)
ok, text = env.invokeServer(player, "BuySpins", "Spins10")
T.check(ok, "BuySpins (" .. tostring(text) .. ")")
T.eq(#env.prompts, prompts + 1, "achat Robux proposé")
T.check(env.prompts[#env.prompts].Id == 9302 and env.prompts[#env.prompts].Kind == "Product", "produit 10 Spins")
for _, value in T.hostileValues() do
	RateLimit.Reset(player)
	ok = env.invokeServer(player, "BuySpins", value)
	T.check(not ok, "BuySpins hostile refusé : " .. T.show(value))
end
T.eq(#env.prompts, prompts + 1, "aucun achat proposé par les appels hostiles")

T.section("achats au hasard payants interdits")
local restricted = T.join({ UserId = 666 })
env.flush()
T.eq(ReplicaService.Get(restricted, "Spins").CanBuy, false, "achat caché (pays qui l'interdit)")
RateLimit.Reset(restricted)
ok, text = env.invokeServer(restricted, "BuySpins", "Spins3")
T.check(not ok and text == "Spins can't be bought here.", "achat refusé")
RateLimit.Reset(restricted)
offers = env.invokeServer(restricted, "GetSpinOffers")
T.check(type(offers) == "table" and #offers == 0, "aucune offre")
local unknown = T.join({ UserId = 667 })
env.flush()
T.eq(ReplicaService.Get(unknown, "Spins").CanBuy, false, "Roblox sans réponse : achat caché par prudence")
T.clean("pas d'erreur quand PolicyService ne répond pas")

T.section("commande spins")
env.studio = true
stock = T.data(player).Spins.Stored
local adminOk, adminText = AdminService.Run(player, "spins", { "10" })
T.check(adminOk, "spins 10 (" .. tostring(adminText) .. ")")
T.eq(T.data(player).Spins.Stored - stock, 10, "+10 tours")
adminOk = AdminService.Run(player, "spins", { "abc" })
T.check(not adminOk, "nombre invalide refusé")
adminOk = AdminService.Run(player, "spins", { "5000" })
T.check(not adminOk, "trop de tours refusé")
env.studio = false

T.section("appels hostiles")
T.advance(COOLDOWN + 0.1)
local totalBefore = T.data(player).Spins.Total
for _, value in T.hostileValues() do
	RateLimit.Reset(player)
	env.invokeServer(player, "Spin", value, value)
end
T.eq(T.data(player).Spins.Total, totalBefore + 1, "un seul tour malgré le spam (recharge)")
T.clean("aucune erreur après les appels hostiles")

T.done("daily_spin")
