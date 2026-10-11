-- Shop, onglets des offres (client et serveur ensemble) : Deals (Starter Pack, Limited, offre du jour avec réduction,
-- prix barré et compte à rebours), Money (packs d'argent au revenu du joueur, « BEST VALUE »), bouton GIFT et liste des
-- joueurs, objets à Id = 0 cachés hors Studio et gris « Id = 0 » dans Studio.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local Shop = Config.Shop
local current = Shop.Current(env.baseTime)
Shop.Cash.CashSmall.Id = 801
Shop.Cash.CashHuge.Id = 802
Shop.Packs.Starter.Id = 811
Shop.Packs[current.Deal].Id = 813
Shop.Passes.DoubleMoney.Id = 501
Shop.Gifts.DoubleMoney.Id = 821
env.productPrices[801] = 49
env.productPrices[802] = 999
env.productPrices[811] = 99
env.productPrices[813] = Shop.Packs[current.Deal].Price
env.productPrices[501] = 299
env.productPrices[821] = 299
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local ReplicaService = Boot.Services.ReplicaService
local Format = T.module("src/shared/Format")

local player = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
local data = T.data(player)
data.Tutorial = 3
ReplicaService.Set(player, "Tutorial", 3)
Boot.Services.DailyService.Claim(player) -- (pas de calendrier ouvert tout seul)
local friend = T.join({ Name = "Friend", DisplayName = "Friend" })
env.flush()

local function find(name: string, from: any?): any
	return (from or player.PlayerGui):FindFirstChild(name, true)
end

local function click(button: any)
	env.fire(env.signal(button, "Activated"))
	env.advance(0.3)
end

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
local ShopUi, Replica = C.ShopController, C.ReplicaController
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(1)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

T.section("onglets")
T.eq(table.concat(ShopUi.Tabs, ","), "Deals,Speed,Trails,Passes,Money,Items", "six onglets")
ShopUi.Open()
env.advance(1)
local backdrop = find("ShopBackdrop")
T.check(find("Treadmill", backdrop) ~= nil, "le shop s'ouvre toujours sur Speed")
for _, tab in ShopUi.Tabs do
	T.check(find(tab, find("Tabs", backdrop) or backdrop) ~= nil, "onglet " .. tab)
end

T.section("Deals")
ShopUi.Select("Deals")
env.advance(1)
local starter = find("Starter", backdrop)
T.check(starter ~= nil, "Starter Pack")
T.eq(starter.Tag.Text.Text, "-75%", "réduction (99 au lieu de 399)")
T.eq(starter.Was.Text, "R$ 399", "prix barré")
T.check(starter.Was:FindFirstChild("Strike") ~= nil, "trait sur le prix barré")
T.check(string.find(starter.Timer.Text, "Ends in 2d", 1, true) ~= nil, "compte à rebours : " .. starter.Timer.Text)
T.check(string.find(starter.Subtitle.Text, "Neon Trail", 1, true) ~= nil, "contenu : " .. starter.Subtitle.Text)
T.eq(starter.Button1.Text, "R$ 99", "prix Roblox")
local deal = find(current.Deal, backdrop)
T.check(deal ~= nil, "offre du jour " .. current.Deal)
T.check(string.find(deal.Timer.Text, "Ends in", 1, true) ~= nil, "offre du jour : compte à rebours")
T.check(find(current.Limited, backdrop) == nil, "Limited à Id = 0 : caché hors Studio")
env.prompts = {}
click(starter.Button1)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Id == 811, "achat du Starter Pack proposé")
local before = starter.Timer.Text
env.advance(2)
T.check(starter.Timer.Text ~= before or string.find(before, "d", 1, true) ~= nil, "le compte à rebours avance")

T.section("Money")
ShopUi.Select("Money")
env.advance(1)
local small = find("CashSmall", backdrop)
local huge = find("CashHuge", backdrop)
T.check(small ~= nil and huge ~= nil, "packs d'argent en vente")
T.check(find("CashMedium", backdrop) == nil, "pack à Id = 0 caché")
T.eq(small.Swatch.Glyph.Text, Format.Money(Shop.Cash.CashSmall.Reward.Amount), "montant (minimum sans revenu)")
T.eq(huge.Tag.Text.Text, "BEST VALUE", "BEST VALUE sur le plus gros")
T.check(small:FindFirstChild("Tag") == nil, "pas d'étiquette sur le plus petit")
ReplicaService.Set(player, "RewardScale", { Income = 1000, Speed = 0 })
env.advance(1)
T.eq(small.Swatch.Glyph.Text, Format.Money(1000 * 60 * 10), "montant au revenu du joueur")
env.prompts = {}
click(huge.Button1)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Id == 802, "achat du pack d'argent proposé")

T.section("cadeau")
ShopUi.Select("Passes")
env.advance(1)
local doubleMoney = find("DoubleMoney", backdrop)
T.eq(doubleMoney.Button1.Text, "R$ 299", "bouton d'achat")
T.eq(doubleMoney.Button2.Text, "GIFT", "bouton GIFT")
click(doubleMoney.Button2)
local picker = find("GiftPicker", backdrop)
T.check(picker ~= nil, "liste des joueurs ouverte")
local row = find("Player" .. friend.UserId, picker)
T.check(row ~= nil, "l'ami est dans la liste")
T.check(find("Player" .. player.UserId, picker) == nil, "pas soi-même")
env.prompts = {}
click(row.Send)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Id == 821, "achat du cadeau proposé")
T.eq(find("GiftPicker", backdrop), nil, "liste fermée après l'envoi")
T.eq(env.purchase(player, 821, { PurchaseId = "G1" }), env.Enum.ProductPurchaseDecision.PurchaseGranted, "cadeau payé")
T.check(Boot.Services.ShopService.HasPass(friend, "DoubleMoney"), "l'ami a x2 Money")
-- (cadeau payé alors que l'ami est parti : « GIFT (1) »)
data.Offers.GiftCredits.DoubleMoney = 1
ReplicaService.Set(player, "GiftCredits", { DoubleMoney = 1 })
env.advance(1)
T.eq(doubleMoney.Button2.Text, "GIFT (1)", "cadeau prêt affiché")
click(doubleMoney.Button2)
picker = find("GiftPicker", backdrop)
T.check(string.find(picker.Info.Text, "ready", 1, true) ~= nil, "liste : cadeau prêt")
click(picker.Close)
T.eq(find("GiftPicker", backdrop), nil, "liste fermée par la croix")

T.section("Studio : objets à Id = 0 en gris")
env.studio = true
ShopUi.Close()
env.advance(2)
ShopUi.Open("Deals")
env.advance(1.5)
local limited = find(current.Limited, backdrop)
T.check(limited ~= nil, "Limited à Id = 0 montré dans Studio")
T.eq(limited and limited.Button1.Text, "Id = 0", "bouton gris Id = 0")
ShopUi.Select("Money")
env.advance(0.5)
T.check(find("CashMedium", backdrop) ~= nil, "pack d'argent à Id = 0 montré dans Studio")
ShopUi.Close()
env.studio = false
env.advance(1)

T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.done("offers_client")
