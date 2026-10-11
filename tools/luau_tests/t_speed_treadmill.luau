-- TreadmillService : vitesse gagnée sur le tapis, propriétaire du tapis, échelle d'achats Robux (un produit par niveau,
-- seulement le niveau suivant, verrou contre le double achat), achat avec l'argent du jeu (remote et prompt sur le tapis
-- du parc, $1K pour débloquer), prix lus sur Roblox, passe x2 Treadmill, admin.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local Shop = Config.Shop
local SpeedConfig = Config.Speed
-- (échelle payante seule dans ce test : le gain gratuit sans achat est testé dans t_daily_afk)
SpeedConfig.Treadmill.FreeMultiplier = 0
-- (produits « créés dans le Creator Hub » pour ce test : Id 9001 à 9050, prix du GDD)
for level, entry in Shop.Treadmill.Levels do
	entry.Id = 9000 + level
	env.productPrices[entry.Id] = entry.Price
end
Shop.Passes.DoubleTreadmill.Id = 7002
local Boot = T.bootServer()
local TreadmillService = Boot.Services.TreadmillService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local SpeedService = Boot.Services.SpeedService
local ReceiptService = Boot.Services.ReceiptService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Signals = T.lib("Signals")
local Format = T.module("src/shared/Format")
local RateLimit = T.lib("RateLimit")
local Enum = env.Enum
local Vector3 = env.Vector3
local CFrame = env.CFrame
local Workspace = env.game:GetService("Workspace")
local Players = env.game:GetService("Players")
local market = env.game:GetService("MarketplaceService")
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local BASE = SpeedConfig.Treadmill.BaseGain
local MAX = #Shop.Treadmill.Levels

local function place(player: any, position: any)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end

-- Un parc avec son tapis (attribut OwnerUserId sur le parc, tag Treadmill sur le tapis)
local function makePlot(ownerId: number?, center: any): any
	local plot = env.create("Model")
	plot.Name = "Plot"
	if ownerId then
		plot:SetAttribute("OwnerUserId", ownerId)
	end
	local belt = env.create("Part")
	belt.Name = "Belt"
	belt.Anchored = true
	belt.Size = Vector3.new(4, 1, 8)
	belt.CFrame = CFrame.new(center)
	belt.Parent = plot
	env.addTag(belt, "Treadmill")
	plot.Parent = Workspace
	return plot
end

local upgrades = {}
Signals.Connect("TreadmillUpgraded", function(p, level)
	table.insert(upgrades, { p, level })
end)

T.section("tapis pas acheté")
local player = T.join({ UserId = 201, Character = true })
env.flush() -- (apparition dans son parc par PlotService du brief 3, avant de le poser sur le tapis du test)
local plot = makePlot(201, Vector3.new(0, 0, 0))
T.eq(ReplicaService.Get(player, "TreadmillLevel"), 0, "Replica TreadmillLevel 0")
T.eq(TreadmillService.Rate(player), 0, "aucun gain sans treadmill")
place(player, Vector3.new(0, 3, 2))
local notes = #env.received(player, "Notify")
T.advance(1.1)
T.check(TreadmillService.IsOnTreadmill(player), "sur le tapis")
T.eq(player:GetAttribute("OnTreadmill"), true, "attribut OnTreadmill")
T.eq(SpeedService.Get(player), 0, "pas de vitesse sans treadmill")
T.eq(#env.received(player, "Notify"), notes + 1, "rappel « achète le treadmill »")
T.advance(5)
T.eq(#env.received(player, "Notify"), notes + 1, "rappel pas répété à chaque seconde")

T.section("achat du niveau 1")
local ok, text = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(ok, "BuyTreadmill (" .. tostring(text) .. ")")
local prompt = env.prompts[#env.prompts]
T.check(prompt and prompt.Player == player and prompt.Kind == "Product" and prompt.Id == 9001, "achat Robux du niveau 1 proposé")
ok, text = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(not ok and text == "Purchase in progress...", "pas deux fois le même niveau pendant l'achat")
env.fire(env.signal(market, "PromptProductPurchaseFinished"), 201, 9001, false)
RateLimit.Reset(player)
ok = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(ok, "fenêtre fermée sans acheter : on peut redemander")
T.eq(env.purchase(player, 9001, { PurchaseId = "T1" }), GRANTED, "niveau 1 acheté")
env.flush()
T.eq(T.data(player).TreadmillLevel, 1, "niveau 1 sauvegardé")
T.eq(ReplicaService.Get(player, "TreadmillLevel"), 1, "Replica TreadmillLevel")
T.eq(ReplicaService.Get(player, "TreadmillRate"), BASE, "Replica TreadmillRate")
T.check(#upgrades == 1 and upgrades[1][2] == 1, "signal TreadmillUpgraded")
T.check(env.saved("SAF_Players_1", "Player_201").TreadmillLevel == 1, "écrit tout de suite")

T.section("vitesse sur le tapis")
local before = SpeedService.Get(player)
T.advance(10)
local gained = SpeedService.Get(player) - before
T.check(gained >= 9 * BASE and gained <= 11 * BASE, "environ 10 s x " .. BASE .. "/s (" .. gained .. ")")
T.eq(T.data(player).Speed, SpeedService.Get(player), "gain sauvegardé comme vitesse gagnée")
before = SpeedService.Get(player)
TreadmillService.Tick()
T.eq(SpeedService.Get(player) - before, BASE, "un tour = BaseGain au niveau 1")
place(player, Vector3.new(0, 3, 30))
T.advance(1.1)
T.check(not TreadmillService.IsOnTreadmill(player), "descendu du tapis")
T.eq(player:GetAttribute("OnTreadmill"), false, "attribut OnTreadmill faux")
before = SpeedService.Get(player)
T.advance(5)
T.eq(SpeedService.Get(player), before, "rien gagné hors du tapis")
place(player, Vector3.new(0, 20, 0))
TreadmillService.Tick()
T.eq(SpeedService.Get(player), before, "trop haut au-dessus du tapis")
place(player, Vector3.new(2.5, 3, 0))
TreadmillService.Tick()
T.eq(SpeedService.Get(player), before, "à côté du tapis")
place(player, Vector3.new(1.5, 3, -3.5))
TreadmillService.Tick()
T.eq(SpeedService.Get(player), before + BASE, "au bord du tapis")

T.section("propriétaire du tapis")
local other = T.join({ UserId = 202, Character = true })
T.data(other).TreadmillLevel = 3
place(other, Vector3.new(0, 3, 0))
before = SpeedService.Get(other)
TreadmillService.Tick()
T.eq(SpeedService.Get(other), before, "pas de vitesse sur le tapis d'un autre")
local free = makePlot(nil, Vector3.new(100, 0, 0))
place(other, Vector3.new(100, 3, 0))
TreadmillService.Tick()
T.eq(SpeedService.Get(other), before + BASE * Shop.Treadmill.Levels[3].Multiplier, "tapis sans propriétaire : pour tous, à son propre niveau")
free.Parent = nil
TreadmillService.Tick()
T.eq(SpeedService.Get(other), before + BASE * Shop.Treadmill.Levels[3].Multiplier, "tapis hors du Workspace ignoré")
other.Character.HumanoidRootPart:Destroy()
TreadmillService.Tick()
T.clean("joueur sans HumanoidRootPart : pas d'erreur")

T.section("niveaux suivants")
place(player, Vector3.new(0, 3, 0))
T.eq(env.purchase(player, 9003, { PurchaseId = "T3" }), NOT_YET, "niveau 3 avant le 2 : pas donné")
T.eq(T.data(player).TreadmillLevel, 1, "toujours niveau 1")
T.check(not ReceiptService.HasProcessed(player, "T3"), "reçu du niveau 3 pas noté")
RateLimit.Reset(player)
ok = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(ok and env.prompts[#env.prompts].Id == 9002, "le serveur propose le niveau 2, pas un autre")
env.fire(env.signal(market, "PromptProductPurchaseFinished"), 201, 9002, true)
RateLimit.Reset(player)
ok, text = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(not ok and text == "Purchase in progress...", "acheté mais pas encore donné : verrou")
T.advance(Shop.Treadmill.PendingSeconds + 5)
RateLimit.Reset(player)
ok, text = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(not ok and text == "Purchase in progress...", "payé mais pas encore donné : toujours bloqué après PendingSeconds")
T.eq(env.purchase(player, 9002, { PurchaseId = "T2" }), GRANTED, "niveau 2 donné")
T.eq(env.purchase(player, 9002, { PurchaseId = "T2" }), GRANTED, "même reçu rejoué : accepté")
T.eq(T.data(player).TreadmillLevel, 2, "niveau 2, pas donné deux fois")
T.eq(env.purchase(player, 9002, { PurchaseId = "T2bis" }), NOT_YET, "niveau 2 déjà acheté : nouveau reçu pas donné")
T.eq(env.purchase(player, 9003, { PurchaseId = "T3" }), GRANTED, "le reçu du niveau 3 passe quand il devient le suivant")
T.eq(T.data(player).TreadmillLevel, 3, "niveau 3")
RateLimit.Reset(player)
ok = env.invokeServer(player, "BuyTreadmill", "Robux")
T.check(ok and env.prompts[#env.prompts].Id == 9004, "verrou levé au niveau suivant")
before = SpeedService.Get(player)
TreadmillService.Tick()
T.eq(SpeedService.Get(player) - before, BASE * Shop.Treadmill.Levels[3].Multiplier, "gain du niveau 3")
for level = 4, #Shop.Treadmill.Levels do
	ReceiptService.Simulate(player, "TreadmillLevel" .. level)
end
T.eq(T.data(player).TreadmillLevel, MAX, "niveau max")
T.eq(TreadmillService.Rate(player), BASE * Shop.Treadmill.Levels[MAX].Multiplier, "gain du dernier niveau")
RateLimit.Reset(player)
ok, text = env.invokeServer(player, "BuyTreadmill")
T.check(not ok and text == "Your treadmill is maxed out!", "niveau max")
T.eq(env.purchase(player, 9001, { PurchaseId = "Old1" }), NOT_YET, "vieux produit du niveau 1 : pas donné")
T.eq(T.data(player).TreadmillLevel, MAX, "toujours au max")

T.section("achat avec l'argent du jeu")
local LEVELS = Shop.Treadmill.Levels
T.eq(LEVELS[1].Cash, 1000, "déblocage à $1K (comme Steal an Egg)")
T.eq(MAX, 50, "50 niveaux (un modèle de tapis par niveau)")
for level = 2, #LEVELS do
	local at, prev = LEVELS[level], LEVELS[level - 1]
	T.check(at.Cash > prev.Cash, "niveau " .. level .. " plus cher que le " .. (level - 1))
	T.check(at.Multiplier > prev.Multiplier, "niveau " .. level .. " plus rapide que le " .. (level - 1))
	T.check(at.Price >= prev.Price, "prix Robux du niveau " .. level .. " jamais plus bas")
	T.check(at.Cash / at.Multiplier >= prev.Cash / prev.Multiplier, "niveau " .. level .. " : $ par gain jamais moins cher")
end
local cashy = T.join({ UserId = 203, Character = true })
env.flush()
local belt = PlotService.Get(cashy).Treadmill
local station = belt and belt:FindFirstChild("TreadmillPrompt")
local sign = belt and belt:FindFirstChild("TreadmillLabel")
T.check(station ~= nil and station:IsA("ProximityPrompt"), "prompt sur le tapis de son parc")
T.check(sign ~= nil and sign:IsA("BillboardGui"), "panneau du prix au-dessus du tapis")
T.eq(station:GetAttribute("OwnerUserId"), 203, "prompt marqué au propriétaire")
T.eq(station.ActionText, "Unlock ($1K)", "prompt : Unlock ($1K)")
T.eq(sign.Price.Text, "Unlock: $1K", "panneau : Unlock: $1K")
T.check(station.Enabled, "prompt actif")
local cashNotes = #env.received(cashy, "Notify")
local promptsBefore = #env.prompts
ok, text = env.invokeServer(cashy, "BuyTreadmill")
T.check(not ok and text == "Not enough money! You need $1K.", "pas assez d'argent (" .. tostring(text) .. ")")
T.eq(T.data(cashy).TreadmillLevel, 0, "toujours niveau 0")
MoneyService.Add(cashy, 1050, "Test")
RateLimit.Reset(cashy)
ok, text = env.invokeServer(cashy, "BuyTreadmill")
T.check(ok, "débloqué avec l'argent du jeu (" .. tostring(text) .. ")")
T.eq(T.data(cashy).TreadmillLevel, 1, "niveau 1")
T.eq(MoneyService.Get(cashy), 50, "$1K payés")
T.eq(ReplicaService.Get(cashy, "TreadmillLevel"), 1, "Replica TreadmillLevel")
T.eq(ReplicaService.Get(cashy, "TreadmillRate"), BASE, "Replica TreadmillRate")
local last = upgrades[#upgrades]
T.check(last and last[1] == cashy and last[2] == 1, "signal TreadmillUpgraded")
local unlocked = 0
for k, args in env.received(cashy, "Notify") do
	if k > cashNotes and type(args[1]) == "string" and string.find(args[1], "Treadmill unlocked!", 1, true) then
		unlocked += 1
	end
end
T.eq(unlocked, 1, "message « Treadmill unlocked! »")
T.eq(#env.prompts, promptsBefore, "aucun achat Robux ouvert")
T.eq(station.ActionText, "Upgrade (" .. Format.Money(LEVELS[2].Cash) .. ")", "prompt : Upgrade (prix du niveau 2)")
T.eq(station.ObjectText, "Treadmill Lv 1/50", "prompt : niveau")
T.eq(sign.Price.Text, "Upgrade: " .. Format.Money(LEVELS[2].Cash), "panneau : Upgrade (prix du niveau 2)")
MoneyService.Add(cashy, LEVELS[2].Cash, "Test")
RateLimit.Reset(cashy)
ok = env.invokeServer(cashy, "BuyTreadmill", "Cash")
T.check(ok and T.data(cashy).TreadmillLevel == 2, "« Cash » : niveau 2")
T.eq(MoneyService.Get(cashy), 50, "prix du niveau 2 payé")

-- (achat Robux du niveau suivant en cours : pas d'achat en argent du même niveau, sinon payé deux fois)
MoneyService.Add(cashy, LEVELS[3].Cash, "Test")
RateLimit.Reset(cashy)
local prompts = #env.prompts
ok = env.invokeServer(cashy, "BuyTreadmill", "Robux")
T.check(ok and #env.prompts == prompts + 1 and env.prompts[#env.prompts].Id == 9003, "achat Robux du niveau 3 ouvert")
RateLimit.Reset(cashy)
ok, text = env.invokeServer(cashy, "BuyTreadmill", "Cash")
T.check(not ok and text == "Purchase in progress...", "achat Robux en cours : pas d'achat en argent")
T.eq(MoneyService.Get(cashy), 50 + LEVELS[3].Cash, "argent pas pris")
env.fire(env.signal(station, "Triggered"), cashy)
env.flush()
T.eq(T.data(cashy).TreadmillLevel, 2, "prompt du tapis bloqué aussi")
env.fire(env.signal(market, "PromptProductPurchaseFinished"), 203, 9003, false)
RateLimit.Reset(cashy)
ok = env.invokeServer(cashy, "BuyTreadmill", "Cash")
T.check(ok and T.data(cashy).TreadmillLevel == 3, "fenêtre Robux fermée : achat en argent du niveau 3")
T.eq(env.purchase(cashy, 9003, { PurchaseId = "C3" }), NOT_YET, "reçu Robux du niveau 3 déjà acheté en argent : pas donné")
T.eq(T.data(cashy).TreadmillLevel, 3, "pas de niveau en plus")

for _, bad in { "robux", "Gems", "", 1, true, {}, { "Cash" } } do
	RateLimit.Reset(cashy)
	ok = env.invokeServer(cashy, "BuyTreadmill", bad)
	T.check(not ok, "monnaie " .. tostring(bad) .. " refusée")
end
T.eq(T.data(cashy).TreadmillLevel, 3, "niveau intact")

T.section("prompt du tapis")
MoneyService.Add(cashy, LEVELS[4].Cash - MoneyService.Get(cashy), "Test")
RateLimit.Reset(cashy)
env.fire(env.signal(station, "Triggered"), cashy)
env.flush()
T.eq(T.data(cashy).TreadmillLevel, 4, "prompt : niveau 4 acheté")
T.eq(MoneyService.Get(cashy), 0, "prix payé")
T.eq(station.ActionText, "Upgrade (" .. Format.Money(LEVELS[5].Cash) .. ")", "prompt : prix du niveau 5")
RateLimit.Reset(cashy)
env.fire(env.signal(station, "Triggered"), cashy)
env.flush()
local refused = env.received(cashy, "Notify")
T.check(string.find(refused[#refused][1], "Not enough money", 1, true) ~= nil, "pas assez d'argent : message")
T.eq(T.data(cashy).TreadmillLevel, 4, "pas acheté")
local bystander = T.join({ UserId = 204, Character = true })
env.flush()
MoneyService.Add(bystander, 1e12, "Test")
env.fire(env.signal(station, "Triggered"), bystander)
env.flush()
local warned = env.received(bystander, "Notify")
T.check(warned[#warned] and warned[#warned][1] == "This is not your park!", "un autre joueur ne peut pas acheter")
T.eq(T.data(cashy).TreadmillLevel, 4, "pas acheté pour lui")
T.eq(T.data(bystander).TreadmillLevel, 0, "ni pour l'autre")
for _ = 1, 20 do
	MoneyService.Add(cashy, 1e12, "Test")
	env.fire(env.signal(station, "Triggered"), cashy)
end
env.flush()
T.check(T.data(cashy).TreadmillLevel <= 7, "prompt limité en vitesse (" .. T.data(cashy).TreadmillLevel .. ")")
TreadmillService.SetLevel(cashy, MAX - 1)
MoneyService.Add(cashy, LEVELS[MAX].Cash, "Test")
RateLimit.Reset(cashy)
env.fire(env.signal(station, "Triggered"), cashy)
env.flush()
T.eq(T.data(cashy).TreadmillLevel, MAX, "dernier niveau en argent")
T.eq(TreadmillService.Rate(cashy), BASE * LEVELS[MAX].Multiplier, "gain du dernier niveau")
T.check(not station.Enabled, "niveau max : prompt éteint")
T.eq(sign.Price.Text, "MAX LEVEL", "panneau : MAX LEVEL")
RateLimit.Reset(cashy)
ok, text = env.invokeServer(cashy, "BuyTreadmill")
T.check(not ok and text == "Your treadmill is maxed out!", "niveau max en argent")
T.leave(cashy)
env.flush()
T.eq(station.Parent, nil, "prompt retiré au départ")
T.eq(sign.Parent, nil, "panneau retiré au départ")
T.leave(bystander)
env.flush()
T.clean("achat en argent sans erreur")

T.section("prix lus sur Roblox")
RateLimit.Reset(other)
local shop = env.invokeServer(other, "GetShop")
local section = shop and shop.Treadmill
T.check(section ~= nil, "section Treadmill dans le shop")
if section then
	T.eq(section.Level, 3, "niveau du joueur")
	T.eq(section.MaxLevel, MAX, "niveau max")
	T.check(section.Next and section.Next.Level == 4, "niveau suivant proposé")
	T.eq(section.Next and section.Next.Price, 89, "prix du niveau 4 lu sur Roblox")
	T.eq(section.Next and section.Next.Cash, Shop.Treadmill.Levels[4].Cash, "prix du niveau 4 en argent du jeu")
	T.eq(section.Next and section.Next.Rate, BASE * Shop.Treadmill.Levels[4].Multiplier, "gain du niveau suivant")
end
env.productPrices[9004] = 95
RateLimit.Reset(other)
shop = env.invokeServer(other, "GetShop")
T.eq(shop.Treadmill.Next.Price, 89, "prix gardé en cache")
T.advance(Shop.PriceCacheSeconds + 1)
RateLimit.Reset(other)
shop = env.invokeServer(other, "GetShop")
T.eq(shop.Treadmill.Next.Price, 95, "prix relu après le cache")
RateLimit.Reset(player)
shop = env.invokeServer(player, "GetShop")
T.check(shop.Treadmill.Next == nil and shop.Treadmill.Level == MAX, "niveau max : rien à proposer")

T.section("passe x2 Treadmill")
local rate = TreadmillService.Rate(other)
env.fire(env.signal(market, "PromptGamePassPurchaseFinished"), other, 7002, true)
env.flush()
T.eq(TreadmillService.Rate(other), rate * 2, "gain doublé")
T.eq(ReplicaService.Get(other, "TreadmillRate"), rate * 2, "Replica TreadmillRate doublé")

T.section("admin")
local admin = T.join({ UserId = 3346721423, Character = true })
ok, text = AdminService.Run(admin, "treadmill", { "5" })
T.check(not ok and text == "Studio only", "treadmill réservé à Studio")
env.studio = true
ok = AdminService.Run(admin, "treadmill", { "5" })
T.check(ok, "treadmill 5 dans Studio")
T.eq(T.data(admin).TreadmillLevel, 5, "niveau fixé")
for _, bad in { "51", "-1", "abc", "2.5", "nan" } do
	T.check(not AdminService.Run(admin, "treadmill", { bad }), "treadmill " .. bad .. " refusé")
end
env.studio = false

T.section("valeurs hostiles")
local Remotes = T.module("src/shared/Remotes")
local skip = {}
for _, declaration in Remotes.List() do
	if declaration.Domain ~= "Shop" then
		skip[declaration.Name] = true
	end
end
local levelBefore = T.data(other).TreadmillLevel
T.eq(T.data(other).Money, 0, "pas d'argent : rien à acheter en argent pendant le fuzz")
T.fuzzRemotes(other, skip)
T.clean("aucune erreur sur les remotes du shop")
T.eq(T.data(other).TreadmillLevel, levelBefore, "niveau intact")
T.check(plot.Parent == Workspace, "le parc est toujours là")
T.check(Players:GetPlayerByUserId(202) ~= nil, "joueur toujours là")

T.done("speed_treadmill")
