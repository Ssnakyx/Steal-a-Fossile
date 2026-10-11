-- Sérum de mutation (Config.Mutator, MutatorService, MutatorController) : probas (seulement des mutations meilleures,
-- 100 %), tirages, échec sans effet, réussite (mutation, modèle refait, revenu), Rainbow refusé, achat avec l'argent du
-- jeu, plafond, produit Robux MutationSerums3, récompense « Serums », commande serums, test FossilDebug, sauvegarde,
-- appels hostiles, puis le menu côté client (bouton MUTATE du labo, choix, MUTATE!, révélation, réouverture).
local T = require("./testkit")
local env = T.env

env.studio = false -- (sauvegardes écrites : sérums gardés au retour)
env.quiet = true
local Config = T.config()
Config.Shop.Products.MutationSerums3.Id = 702
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local AdminService = Boot.Services.AdminService
local EnclosureService = Boot.Services.EnclosureService
local IncomeService = Boot.Services.IncomeService
local MoneyService = Boot.Services.MoneyService
local MutatorService = Boot.Services.MutatorService
local ReceiptService = Boot.Services.ReceiptService
local ReplicaService = Boot.Services.ReplicaService
local RewardService = Boot.Services.RewardService
local Mutator = T.module("src/shared/Config/Mutator")
local Economy = T.module("src/shared/Config/Economy")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")

local function replica(player, key: string): any
	ReplicaService.Flush()
	return ReplicaService.Get(player, key)
end

local function mutate(player, ...): (any, any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, "MutateDino", ...)
end

local function buy(player, ...): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, "BuySerums", ...)
end

local serumSignals = {}
Signals.Connect("DinoSerum", function(...)
	table.insert(serumSignals, table.pack(...))
end)

T.section("probas")
T.check(Mutator.SuccessChance > 0 and Mutator.SuccessChance < 100, "réussite entre 0 et 100 %")
for _, info in Economy.Mutations do
	T.check(Mutator.Rank(info.Name) > 0, info.Name .. " : rang")
end
T.eq(Mutator.Rank(""), 0, "sans mutation : rang 0")
T.eq(Mutator.Rank("Nope"), 0, "mutation inconnue : rang 0")
for _, current in { "", "Amber", "Crystal", "Pearl", "Lava", "Abyssal", "Galaxy" } do
	local total = 0
	local list = Mutator.Odds(current)
	T.check(#list > 0, current .. " : un sérum peut l'améliorer")
	for _, odds in list do
		total += odds.Chance
		T.check(Mutator.Rank(odds.Name) > Mutator.Rank(current), current .. " -> " .. odds.Name .. " : meilleure")
		T.check((Economy.Mutation(odds.Name) :: any).Income >= ((Economy.Mutation(current) :: any) or { Income = 1 }).Income, odds.Name .. " : revenu pas plus bas")
	end
	T.near(total, 1, 1e-9, current .. " : les chances font 100 %")
end
T.eq(#Mutator.Odds(""), #Economy.Mutations, "sans mutation : les 12 possibles")
T.check(not Mutator.CanMutate("Rainbow"), "Rainbow : la meilleure")
T.eq(Mutator.Pick("Rainbow", 0.5), nil, "Rainbow : rien à tirer")
T.eq(Mutator.Pick("", 0), Mutator.Odds("")[1].Name, "roll 0 : la plus commune")
T.eq(Mutator.Pick("", 0.999999), "Rainbow", "roll ~1 : la plus rare")
T.eq(Mutator.Pick("Galaxy", 0.3), "Rainbow", "Galaxy : seulement Rainbow")
for _, bad in { 0 / 0, -1, 2, math.huge } do
	T.check(Mutator.Pick("", bad :: any) ~= nil, "roll abîmé : un résultat quand même")
end
-- tirage : fréquences proches des chances
local counts: { [string]: number } = {}
local rng = env.Random.new(7)
local DRAWS = 40000
for _ = 1, DRAWS do
	local name = Mutator.Pick("", rng:NextNumber()) :: string
	counts[name] = (counts[name] or 0) + 1
end
for _, odds in Mutator.Odds("") do
	local got = (counts[odds.Name] or 0) / DRAWS
	T.check(math.abs(got - odds.Chance) < 0.012, string.format("%s tiré %.3f (attendu %.3f)", odds.Name, got, odds.Chance))
end
T.eq(Mutator.Price(0), Mutator.MinPrice, "prix minimum")
T.eq(Mutator.Price(1000), 1000 * Mutator.PriceSeconds, "prix = secondes de revenu")
T.eq(Mutator.Price(0 / 0), Mutator.MinPrice, "revenu abîmé : prix minimum")
T.eq(Config.Daily.Label({ Kind = "Serums", Amount = 2 }, nil), "2 Mutation Serums", "texte de récompense")
T.eq(Config.Daily.Label({ Kind = "Serums", Amount = 1 }, nil), "1 Mutation Serum", "texte de récompense (1)")

T.section("sérum : échec et réussite")
local alice = T.join({ Name = "Alice", Character = true })
env.flush()
local data = T.data(alice)
data.EnclosureUpgrades = #Economy.Enclosure.Prices
T.eq(data.Serums, 0, "aucun sérum au départ")
T.eq(replica(alice, "Serums"), 0, "replica Serums")
T.eq(replica(alice, "SerumPrice"), Mutator.Price(IncomeService.GetIncome(alice)), "replica SerumPrice")
local id = EnclosureService.AddDino(alice, { Species = "Compy" }) :: string
local base = IncomeService.DinoIncome(EnclosureService.GetDino(alice, id) :: any)
local ok, text, result = mutate(alice, id)
T.check(not ok and text == "You need a Mutation Serum!", "sans sérum : refusé")
T.check(MutatorService.Give(alice, 3), "3 sérums donnés")
T.eq(replica(alice, "Serums"), 3, "replica Serums à jour")
MutatorService.ForceRolls({ { 0.99, 0 } })
local modelBefore = EnclosureService.ModelOf(alice, id)
ok, text, result = mutate(alice, id)
T.check(ok and type(result) == "table" and result.Success == false, "raté : " .. tostring(text))
T.eq((EnclosureService.GetDino(alice, id) :: any).Mutation, "", "raté : pas de mutation")
T.eq(EnclosureService.ModelOf(alice, id), modelBefore, "raté : modèle inchangé")
T.eq(data.Serums, 2, "raté : sérum consommé")
T.eq(data.SerumsUsed, 1, "sérums utilisés comptés")
T.eq(result.Species, "Compy", "résultat : espèce")
T.eq(result.Rarity, "Common", "résultat : rareté")
env.flush()
T.eq(serumSignals[1] and serumSignals[1][3], false, "signal DinoSerum : raté")
MutatorService.ForceRolls({ { 0, 0 } })
ok, text, result = mutate(alice, id)
local first = Mutator.Odds("")[1]
T.check(ok and result.Success == true, "réussi : " .. tostring(text))
T.eq((EnclosureService.GetDino(alice, id) :: any).Mutation, first.Name, "réussi : " .. first.Name)
T.eq(result.Mutation, first.Name, "résultat : mutation")
T.eq(result.Before, "", "résultat : mutation d'avant")
T.near(result.Income, base * first.Income, 1e-6, "résultat : revenu avec le bonus")
local model = EnclosureService.ModelOf(alice, id)
T.check(model ~= nil and model ~= modelBefore, "modèle refait")
T.eq(model and model:GetAttribute("Mutation"), first.Name, "attribut Mutation du modèle")
T.eq(model and model:GetAttribute("State"), Mutator.ResultState, "le dino rugit")
T.near(replica(alice, "Dinos")[id].Income, base * first.Income, 1e-6, "replica Dinos : revenu")
T.eq(data.Serums, 1, "réussi : sérum consommé")
-- Galaxy -> Rainbow (annonce au serveur), puis plus rien
EnclosureService.SetMutation(alice, id, "Galaxy")
MutatorService.ForceRolls({ { 0, 0.5 } })
local announced = #env.received(alice, "LoopAnnounce")
ok, text, result = mutate(alice, id)
T.check(ok and result.Success and result.Mutation == "Rainbow", "Galaxy -> Rainbow")
env.flush()
T.check(#env.received(alice, "LoopAnnounce") > announced, "Rainbow annoncé au serveur")
MoneyService.Add(alice, 1, "Test")
ok, text = mutate(alice, id)
T.check(not ok and text == "This dino already has the best mutation!", "Rainbow : refusé")
T.eq(data.Serums, 0, "Rainbow : aucun sérum perdu")
T.check(not EnclosureService.SetMutation(alice, id, "Nope"), "SetMutation : mutation inconnue refusée")
T.check(not EnclosureService.SetMutation(alice, "999", "Amber"), "SetMutation : dino inconnu refusé")

T.section("achat avec l'argent du jeu")
MoneyService.Set(alice, 0, "Test")
ok, text = buy(alice, 1)
T.check(not ok and text == "Not enough money!", "pas assez d'argent")
local price = MutatorService.Price(alice)
MoneyService.Set(alice, price * 2, "Test")
ok, text = buy(alice, 2)
T.check(ok, "2 sérums achetés : " .. tostring(text))
T.eq(data.Serums, 2, "+2")
T.eq(MoneyService.Get(alice), 0, "payé")
ok = buy(alice, Mutator.MaxBuy + 1)
T.check(not ok, "trop d'un coup refusé")
data.Serums = Mutator.MaxOwned
MoneyService.Add(alice, price, "Test")
ok, text = buy(alice)
T.check(not ok and text == "You can't carry more serums", "plafond")
T.check(not MutatorService.Give(alice, 1), "Give : plafond")
data.Serums = 0

T.section("produit Robux et récompenses")
T.check(ReceiptService.IsOnSale("MutationSerums3"), "produit enregistré par MutatorService")
T.check(ReceiptService.Simulate(alice, "MutationSerums3"), "achat simulé")
T.eq(data.Serums, Mutator.PerProduct, "+3")
env.purchase(alice, 702)
env.flush()
T.eq(data.Serums, 2 * Mutator.PerProduct, "vrai achat : +3")
data.Serums = Mutator.MaxOwned - 1
T.check(ReceiptService.Simulate(alice, "MutationSerums3"), "près du plafond : traité quand même")
T.eq(data.Serums, Mutator.MaxOwned, "seulement ce qui tient")
data.Serums = 0
local granted, label = RewardService.Grant(alice, { Kind = "Serums", Amount = 2 }, "Daily")
T.check(granted and label == "2 Mutation Serums", "récompense Serums : " .. tostring(label))
T.eq(data.Serums, 2, "récompense donnée")
local foundDay, foundGift = false, false
for _, reward in Config.Daily.Login.Days do
	foundDay = foundDay or reward.Kind == "Serums"
end
for _, gift in Config.Daily.Gifts do
	foundGift = foundGift or gift.Reward.Kind == "Serums"
end
T.check(foundDay and foundGift, "sérums dans le calendrier et les cadeaux")
env.studio = true -- (en Studio, tout le monde est admin)
local adminOk = AdminService.Run(alice, "serums", { "5" })
T.check(adminOk and data.Serums == 7, "commande serums")
T.check(not AdminService.Run(alice, "serums", { "-1" }), "commande : nombre invalide")
env.studio = false

T.section("appels hostiles")
local serumsBefore = data.Serums
MoneyService.Set(alice, 0, "Test") -- (BuySerums sans nombre = 1 sérum : sans argent, rien ne s'achète)
for _, value in T.hostileValues() do
	mutate(alice, value)
	buy(alice, value)
end
T.eq(data.Serums, serumsBefore, "aucun sérum perdu ni gagné")
T.clean("aucune erreur avec des valeurs hostiles")

T.section("sauvegarde")
T.leave(alice)
alice = T.join({ Name = "Alice", UserId = alice.UserId, Character = true })
T.eq(T.data(alice).Serums, serumsBefore, "sérums gardés au retour")

T.section("menu client")
local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return me:GetAttribute("Ready") == true
end, "joueur prêt", 60)
local myData = T.data(me)
myData.Tutorial = 3
ReplicaService.Set(me, "Tutorial", 3)
Boot.Services.DailyService.Claim(me)
local myDino = EnclosureService.AddDino(me, { Species = "Compy" }) :: string
MutatorService.Give(me, 1)
env.flush()
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
local Lab, Mut, Reveal, Replica = C.LabController, C.MutatorController, C.RevealController, C.ReplicaController
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(1)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

local function find(name: string, from: any?): any
	return (from or me.PlayerGui):FindFirstChild(name, true)
end
local function click(button: any)
	env.fire(env.signal(button, "Activated"))
	env.advance(0.3)
end

Lab.Open()
env.advance(0.3)
Lab.Select({ myDino })
click(find("Mutate", find("Fusion LabBackdrop")))
env.advance(0.3)
T.check(Mut.IsOpen() and not Lab.IsOpen(), "MUTATE du labo : menu du sérum")
T.eq(Mut.Selected(), myDino, "dino choisi dans le labo repris")
local panel = find("Mutation LabBackdrop")
T.check(panel ~= nil, "panneau Mutation Lab")
local resultCard = find("Result", panel)
T.check(string.find(resultCard.Title.Text, "COMPY", 1, true) ~= nil, "titre : " .. resultCard.Title.Text)
T.check(string.find(resultCard.Info.Text, Mutator.SuccessChance .. "%", 1, true) ~= nil, "chance affichée : " .. resultCard.Info.Text)
T.check(string.find(resultCard.Odds.Text, "Rainbow", 1, true) ~= nil, "probas affichées : " .. resultCard.Odds.Text)
T.eq(find("Serums", panel).Text, "MUTATION SERUMS: 1", "sérums affichés")
T.check(string.find(find("BuySerum", panel).Text, "$", 1, true) ~= nil, "prix affiché")
MutatorService.ForceRolls({ { 0, 0 } })
click(find("Mutate", panel))
env.advance(1)
T.eq((EnclosureService.GetDino(me, myDino) :: any).Mutation, first.Name, "dino muté par le menu")
T.check(Reveal.IsOpen(), "révélation après le sérum")
T.check(find("Title", find("RevealBackdrop") or me.PlayerGui) ~= nil, "titre de la révélation")
T.check(not Mut.IsOpen(), "menu caché sous la révélation")
click(find("Nice"))
env.advance(0.6)
T.check(Mut.IsOpen(), "menu rouvert après la révélation")
T.eq(find("Serums", panel).Text, "MUTATION SERUMS: 0", "plus de sérum")
-- un raté
MutatorService.Give(me, 1)
MutatorService.ForceRolls({ { 0.99, 0 } })
env.advance(0.5)
click(find("Mutate", panel))
env.advance(1)
T.check(Reveal.IsOpen(), "révélation du raté")
local texts = {}
for _, inst in me.PlayerGui:GetDescendants() do
	if inst:IsA("TextLabel") and inst.Visible then
		table.insert(texts, inst.Text)
	end
end
T.check(table.find(texts, "MUTATION FAILED") ~= nil, "MUTATION FAILED affiché")
click(find("Nice"))
env.advance(0.6)
-- achat d'un sérum depuis le menu
MoneyService.Add(me, MutatorService.Price(me), "Test")
click(find("BuySerum", panel))
env.advance(1)
T.eq(myData.Serums, 1, "sérum acheté depuis le menu")
Mut.Close()
env.advance(0.5)
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.clean("aucune erreur")

T.done("mutation_serum")
