-- Trails Robux : un game pass chacune, portée = vitesse de la meilleure trail en argent x Multiplier du passe, portée
-- dès que le passe arrive, remplacée si le passe est remboursé, cachée tant que le passe n'existe pas.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local Shop = Config.Shop
local Trails = Config.Speed.Trails
local RobuxTrails = Config.Speed.RobuxTrails
-- (passes « créés dans le Creator Hub » pour ce test ; GoldenTrail reste à Id = 0)
Shop.Passes.NeonTrail.Id = 801
Shop.Passes.GalaxyTrail.Id = 802
env.productPrices[801] = 99
env.productPrices[802] = 249
env.ownedPasses[501] = { [801] = true }
local Boot = T.bootServer()
local TrailService = Boot.Services.TrailService
local SpeedService = Boot.Services.SpeedService
local ShopService = Boot.Services.ShopService
local MoneyService = Boot.Services.MoneyService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local RateLimit = T.lib("RateLimit")
local market = env.game:GetService("MarketplaceService")

local function call(player: any, name: string, ...: any): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, name, ...)
end

local function visual(player: any): any
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root:FindFirstChild("SAF_Trail")
end

T.section("config")
local count = 0
local orders = {}
for id, trail in RobuxTrails do
	count += 1
	orders[trail.Order] = id
	local pass = Shop.Passes[trail.Pass]
	T.check(Trails[id] == nil, id .. " : clé différente des trails en argent")
	T.check(pass ~= nil and pass.Trail == id, id .. " : passe " .. tostring(trail.Pass) .. " relié dans les deux sens")
	T.check(pass and (pass.Multiplier or 1) > 1, id .. " : multiplie la vitesse")
	T.check(pass and pass.Name == trail.Name, id .. " : même nom que le passe")
	T.check(pass and string.find(pass.Description, "x" .. tostring(pass.Multiplier) .. " Speed", 1, true) ~= nil, id .. " : la description donne le multiplicateur")
	T.check(#trail.Colors >= 1, id .. " : couleur")
end
T.eq(count, 3, "3 trails Robux")
for key, pass in Shop.Passes do
	if pass.Trail then
		T.check(RobuxTrails[pass.Trail] ~= nil and RobuxTrails[pass.Trail].Pass == key, key .. " : trail Robux connue")
	end
end
local rising = true
for order = 2, count do
	local a, b = RobuxTrails[orders[order - 1]], RobuxTrails[orders[order]]
	local pa, pb = a and Shop.Passes[a.Pass], b and Shop.Passes[b.Pass]
	if not (pa and pb and pb.Price > pa.Price and (pb.Multiplier or 1) > (pa.Multiplier or 1)) then
		rising = false
	end
end
T.check(rising, "prix et multiplicateur montent avec l'ordre")

T.section("passe trouvé chez Roblox")
local player = T.join({ UserId = 501, Character = true })
env.advance(1)
T.check(ShopService.HasPass(player, "NeonTrail"), "passe Neon trouvé")
T.check(TrailService.Owns(player, "Neon"), "Neon possédée")
T.eq(TrailService.Equipped(player), "Neon", "portée tout de suite")
SpeedService.Add(player, 1000, "Test")
T.eq(SpeedService.Get(player), 1500, "vitesse x1.5")
T.eq(T.data(player).Speed, 1000, "multiplicateur pas compté comme vitesse gagnée")
local effect = visual(player)
T.check(effect ~= nil and effect.LightEmission == RobuxTrails.Neon.LightEmission, "traînée Neon")
env.flush()
local replica = ReplicaService.Get(player, "Trails")
T.check(replica and replica.Owned.Neon and replica.Equipped == "Neon", "Replica Trails avec la trail Robux")

T.section("avec les trails en argent")
MoneyService.Add(player, 5000, "Test")
local ok, text = call(player, "BuyTrail", "Fern")
T.check(ok, "Fern achetée (" .. tostring(text) .. ")")
T.eq(TrailService.Equipped(player), "Neon", "la trail Robux reste portée")
T.eq(SpeedService.Get(player), (1000 + Trails.Fern.Speed) * 1.5, "garde la vitesse de la meilleure trail en argent")
ok = call(player, "BuyTrail", "Dust")
T.check(ok, "Dust achetée")
T.eq(SpeedService.Get(player), (1000 + Trails.Fern.Speed) * 1.5, "la meilleure compte, pas la dernière")
ok = call(player, "EquipTrail", "Fern")
T.check(ok, "Fern portée")
T.eq(SpeedService.Get(player), 1000 + Trails.Fern.Speed, "plus de multiplicateur")
T.eq(SpeedService.GetMultiplier(player, "Trail"), 1, "multiplicateur enlevé")
ok, text = call(player, "EquipTrail", "Neon")
T.check(ok and text == "Neon Trail equipped", "Neon remise")
T.eq(SpeedService.Get(player), (1000 + Trails.Fern.Speed) * 1.5, "multiplicateur remis")

T.section("passe acheté en jeu")
ok, text = call(player, "EquipTrail", "Galaxy")
T.check(not ok and text == "You don't own this trail", "Galaxy pas possédée")
ok, text = call(player, "BuyTrail", "Galaxy")
T.check(ok, "BuyTrail Galaxy (" .. tostring(text) .. ")")
local prompt = env.prompts[#env.prompts]
T.check(prompt and prompt.Kind == "GamePass" and prompt.Id == 802 and prompt.Player == player, "achat du passe proposé")
env.fire(env.signal(market, "PromptGamePassPurchaseFinished"), player, 802, true)
env.flush()
env.ownedPasses[501][802] = true
T.eq(TrailService.Equipped(player), "Galaxy", "la meilleure trail Robux est portée")
T.eq(SpeedService.Get(player), (1000 + Trails.Fern.Speed) * 2, "vitesse x2")
ok, text = call(player, "BuyTrail", "Galaxy")
T.check(not ok and text == "Already owned", "pas deux fois")
ok, text = call(player, "BuyTrail", "Golden")
T.check(not ok and text == "Coming soon!", "passe à Id = 0 pas en vente")
ok, text = call(player, "EquipTrail", "Golden")
T.check(not ok and text == "You don't own this trail", "Golden pas portable")
-- (un passe moins bon reçu ensuite ne remplace pas la trail portée)
env.ownedPasses[503] = { [801] = true, [802] = true }
local both = T.join({ UserId = 503, Character = true })
env.advance(1)
T.eq(TrailService.Equipped(both), "Galaxy", "deux passes : la meilleure portée")
T.leave(both)

T.section("contenu du shop")
local shop = call(player, "GetShop")
local listed = {}
for _, pass in shop.Passes do
	listed[pass.Key] = pass
end
T.check(listed.NeonTrail and listed.NeonTrail.Trail == "Neon" and listed.NeonTrail.Price == 99, "Neon listée avec son prix")
T.check(listed.GalaxyTrail and listed.GalaxyTrail.Owned, "Galaxy marquée possédée")
T.check(listed.GoldenTrail == nil, "Golden cachée tant que le passe n'existe pas")

T.section("valeurs hostiles")
local money = MoneyService.Get(player)
for _, bad in T.hostileValues() do
	call(player, "BuyTrail", bad)
	call(player, "EquipTrail", bad)
end
for _, name in { "neon", "NeonTrail", "Pass", "__index" } do
	ok = call(player, "EquipTrail", name)
	T.check(not ok, "EquipTrail " .. name .. " refusé")
end
T.clean("aucune erreur")
T.eq(MoneyService.Get(player), money, "argent intact")
call(player, "EquipTrail", "Galaxy")

T.section("sauvegarde et remboursement")
T.leave(player)
local saved = env.saved("SAF_Players_1", "Player_501")
T.eq(saved.Trails.Equipped, "Galaxy", "trail Robux portée écrite")
T.check(saved.Trails.Owned.Neon == nil and saved.Trails.Owned.Galaxy == nil, "les trails Robux ne sont pas dans Owned (ce sont des passes)")
local back = T.join({ UserId = 501, Character = true })
env.advance(1)
T.eq(TrailService.Equipped(back), "Galaxy", "trail Robux remise au retour")
T.eq(SpeedService.Get(back), (1000 + Trails.Fern.Speed) * 2, "multiplicateur remis au retour")
T.leave(back)
env.ownedPasses[501][802] = nil -- (Galaxy remboursé)
local refunded = T.join({ UserId = 501, Character = true })
env.advance(5)
T.check(not TrailService.Owns(refunded, "Galaxy"), "Galaxy retirée")
T.eq(TrailService.Equipped(refunded), "Fern", "la meilleure trail en argent la remplace")
T.eq(SpeedService.Get(refunded), 1000 + Trails.Fern.Speed, "vitesse sans multiplicateur")
T.check(TrailService.Owns(refunded, "Neon"), "Neon toujours là")
env.flush()
T.check(ReplicaService.Get(refunded, "Trails").Owned.Galaxy == nil, "Replica à jour")
T.leave(refunded)

T.section("passe pas confirmé")
-- (trail Robux portée dans la sauvegarde, mais Roblox ne répond pas et le passe n'est pas noté : rien ne s'applique)
local realOwns = market.UserOwnsGamePassAsync
env.stubMethod("MarketplaceService", "UserOwnsGamePassAsync", function()
	error("HTTP 500")
end)
local unsure = T.join({ UserId = 502, Character = true })
env.advance(30)
T.data(unsure).Trails.Equipped = "Galaxy"
T.leave(unsure)
local unsureBack = T.join({ UserId = 502, Character = true })
env.advance(30)
T.eq(T.data(unsureBack).Trails.Equipped, "Galaxy", "gardée dans la sauvegarde")
T.eq(TrailService.Equipped(unsureBack), "", "pas portée sans le passe")
T.eq(SpeedService.GetMultiplier(unsureBack, "Trail"), 1, "pas de multiplicateur")
T.eq(visual(unsureBack), nil, "pas de traînée")
env.stubMethod("MarketplaceService", "UserOwnsGamePassAsync", realOwns)
T.clean("aucune erreur quand Roblox ne répond pas")

T.section("admin dans Studio")
env.studio = true
local admin = T.join({ UserId = 3346721423, Character = true })
ok = AdminService.Run(admin, "pass", { "GoldenTrail" })
T.check(ok and TrailService.Equipped(admin) == "Golden", "pass GoldenTrail : portée pour tester")
T.eq(SpeedService.GetMultiplier(admin, "Trail"), 3, "x3")
ok = AdminService.Run(admin, "pass", { "GoldenTrail" })
T.check(ok and TrailService.Equipped(admin) == "", "passe retiré : plus de trail")
T.eq(SpeedService.GetMultiplier(admin, "Trail"), 1, "plus de multiplicateur")
env.studio = false

T.done("speed_robux_trails")
