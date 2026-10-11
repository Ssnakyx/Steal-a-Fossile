-- Boucle (brief 3) : cuves de réanimation, révélation, enclos, revenus, revenu hors ligne, achats de cuves et de slots,
-- branchements au brief 4 (passes Double Money / Fast Revive / VIP, produit Instant Revive) avec un faux ShopService.
local T = require("./testkit")
local env = T.env

env.studio = false -- (les sauvegardes sont écrites : revenu hors ligne)
env.quiet = true

-- faux brief 4 : ShopService et Config.Shop, posés avant le démarrage
local passes: { [any]: { [string]: boolean } } = {}
local shopStub = {
	HasPass = function(player, pass)
		return passes[player] ~= nil and passes[player][pass] == true
	end,
	ServerLuck = function()
		return 1
	end,
}
local stub = env.Instance.new("ModuleScript")
stub.Name = "ShopService"
env.Data[stub].Extra.Module = shopStub
stub.Parent = env.instance("ServerScriptService.Server.Services")
local shopConfig = env.Instance.new("ModuleScript")
shopConfig.Name = "Shop"
local shopValues = {
	Products = { InstantRevive = { Id = 0 } },
	Passes = { VIP = { LuckBonus = 1.5 } }, -- (multiplicateur, comme Config.Shop du brief 4 : 1.1 = chance x1.1)
}
env.Data[shopConfig].Extra.Module = shopValues
shopConfig.Parent = env.instance("ReplicatedStorage.Shared.Config")

local Boot = T.bootServer()
local ReviveService = Boot.Services.ReviveService
local EnclosureService = Boot.Services.EnclosureService
local IncomeService = Boot.Services.IncomeService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local ReceiptService = Boot.Services.ReceiptService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Economy = T.module("src/shared/Config/Economy")
local Rarity = T.module("src/shared/Config/Rarity")
local Zones = T.module("src/shared/Config/Zones")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local CollectionService = env.game:GetService("CollectionService")
local Shared = env.instance("ReplicatedStorage.Shared")

local function lastNotify(player): string?
	local list = env.received(player, "Notify")
	local last = list[#list]
	return if last then last[1] else nil
end

local function replica(player, key: string): any
	ReplicaService.Flush()
	return ReplicaService.Get(player, key)
end

T.section("départ")
local alice = T.join({ Name = "Alice", Character = true })
env.flush()
local data = T.data(alice)
local plot = PlotService.Get(alice)
T.eq(replica(alice, "TankCount"), 2, "replica TankCount")
T.check(next(replica(alice, "Tanks")) == nil, "replica Tanks vide")
T.eq(#replica(alice, "Stored"), 0, "replica Stored vide")
T.eq(replica(alice, "EnclosureSlots"), Economy.Enclosure.BaseSlots, "replica EnclosureSlots")
T.eq(replica(alice, "Income"), 0, "replica Income")
T.check(next(replica(alice, "Dinos")) == nil, "replica Dinos vide")
local tank1 = plot.Tanks[1]
T.check(tank1:FindFirstChild("TankLabel") ~= nil and tank1:FindFirstChild("TankPrompt") ~= nil, "étiquette et prompt sur la cuve 1")
T.eq(tank1.TankLabel.Text.Text, "Empty", "cuve 1 vide")
T.check(CollectionService:HasTag(tank1.TankLabel.Text, "LoopCountdown"), "étiquette de cuve taguée LoopCountdown")
T.eq(plot.Tanks[3].TankPrompt.ActionText, "Buy Tank ($1K)", "cuve 3 : achat proposé")
T.check(plot.Tanks[3].TankPrompt.Enabled, "prompt d'achat actif")
T.check(not plot.Tanks[4].TankPrompt.Enabled and not plot.Tanks[4].TankLabel.Enabled, "cuve 4 cachée")
T.eq(tank1.TankPrompt:GetAttribute("OwnerUserId"), alice.UserId, "prompt marqué au propriétaire")

T.section("cuves et réserve")
local started = {}
local disconnect = Signals.Connect("TankStarted", function(player, slot, tank)
	table.insert(started, slot)
end)
T.check(ReviveService.AddBlock(alice, { Rarity = "Common", Zone = "Beach" }), "bloc 1 accepté")
local tank = data.Tanks["1"]
T.eq(tank.EndsAt - tank.StartedAt, Rarity.Info.Common.ReviveTime, "minuteur Common : 30 s")
T.eq(tank1.TankLabel.Text:GetAttribute("EndsAt"), tank.EndsAt, "compte à rebours sur l'étiquette")
T.check(tank1:FindFirstChild("TankBlock") ~= nil, "bloc visible dans la cuve")
T.check(not tank1.TankPrompt.Enabled, "pas de Reveal avant la fin")
T.check(ReviveService.AddBlock(alice, { Rarity = "Uncommon", Zone = "Beach" }), "bloc 2 accepté")
T.eq(data.Tanks["2"].EndsAt - data.Tanks["2"].StartedAt, 60, "minuteur Uncommon : 1 min")
T.check(ReviveService.AddBlock(alice, { Rarity = "Rare", Zone = "Fern Forest" }), "bloc 3 accepté (réserve)")
T.eq(#data.Stored, 1, "bloc 3 en réserve")
T.eq(replica(alice, "Stored")[1].Rarity, "Rare", "replica Stored")
T.eq(table.concat(started, ","), "1,2", "signal TankStarted")
T.check(not ReviveService.AddBlock(alice, { Rarity = "Nope" }), "rareté inconnue refusée")
T.check(not ReviveService.AddBlock(alice, "x" :: any), "bloc invalide refusé")
disconnect()

T.section("révélation")
local ok, text = ReviveService.Reveal(alice, 1)
T.check(not ok and string.find(text, "Not ready", 1, true) ~= nil, "pas prête : " .. text)
env.advance(31)
T.check(tank1.TankPrompt.Enabled, "prompt Reveal actif quand c'est prêt")
T.eq(tank1.TankPrompt.ActionText, "Reveal", "texte du prompt")
T.eq(lastNotify(alice), "Your Common fossil is ready to reveal!", "message « ready »")
local revived = {}
disconnect = Signals.Connect("DinoRevived", function(player, id, dino, rarity)
	table.insert(revived, { id, dino, rarity })
end)
ok, text = env.invokeServer(alice, "RevealTank", 1)
T.check(ok, "RevealTank : " .. tostring(text))
local id, dino = next(data.Dinos)
T.check(id ~= nil, "un dino dans l'enclos")
T.check(table.find(ReviveService.Candidates("Common", "Beach"), dino.Species) ~= nil, "espèce Common de la Beach : " .. dino.Species)
T.eq(Rarity.Species[dino.Species], "Common", "rareté de l'espèce = rareté du bloc")
T.check(data.Index.Species[dino.Species] == true, "espèce ajoutée à l'Index")
T.eq(data.Tutorial, 3, "tutoriel fini au premier dino révélé")
T.eq(#data.Stored, 0, "le bloc en réserve part dans la cuve libérée")
T.eq(data.Tanks["1"].Rarity, "Rare", "cuve 1 : bloc Rare")
T.eq(data.Tanks["1"].EndsAt - data.Tanks["1"].StartedAt, 180, "minuteur Rare : 3 min")
local reveals = env.received(alice, "DinoRevealed")
T.eq(#reveals, 1, "événement DinoRevealed")
T.eq(reveals[1][1], id, "DinoRevealed : identifiant")
T.eq(reveals[1][2].Rarity, "Common", "DinoRevealed : rareté")
T.eq(reveals[1][2].Species, dino.Species, "DinoRevealed : espèce")
T.eq(#revived, 1, "signal DinoRevived")
T.eq(replica(alice, "Dinos")[id].Species, dino.Species, "replica Dinos")
disconnect()

T.section("modèle du dino")
local model = EnclosureService.ModelOf(alice, id)
T.check(model ~= nil and model.Parent == plot.Model.Dinos, "modèle dans Plot.Dinos")
T.check(CollectionService:HasTag(model, "Dino"), "tagué Dino (pipeline du brief 2)")
T.eq(model.PrimaryPart and model.PrimaryPart.Name, "Root", "pièce Root = PrimaryPart")
T.eq(model:GetAttribute("Species"), EnclosureService.ModelName(dino.Species), "attribut Species = nom du module")
T.eq(model:GetAttribute("Level"), "Normal", "attribut Level")
T.eq(model:GetAttribute("State"), "Spawn", "état Spawn à la révélation")
T.check(type(model:GetAttribute("StateAt")) == "number", "attribut StateAt")
T.eq(model:GetAttribute("DinoId"), id, "attribut DinoId")
T.eq(model:GetAttribute("OwnerUserId"), alice.UserId, "attribut OwnerUserId")
local scaleFound = false
for _, size in Economy.Sizes do
	if size.Name == dino.Size then
		scaleFound = model:GetAttribute("Scale") == size.Scale
	end
end
T.check(scaleFound, "attribut Scale = échelle de la taille")
local folder = Shared:FindFirstChild("DinoModels")
local hasModule = folder ~= nil and folder:FindFirstChild(model:GetAttribute("Species")) ~= nil
local bricks = 0
for _, child in model:GetChildren() do
	if child:IsA("BasePart") and child.Name ~= "Root" then
		bricks += 1
		T.eq(child:GetAttribute("Bone"), nil, "brique provisoire sans attribut Bone")
	end
end
T.check(if hasModule then bricks == 0 else bricks > 0, "dino provisoire seulement sans module DinoModels")
T.check(model.Root:FindFirstChild("Label") ~= nil, "étiquette nom + revenu")
T.eq(EnclosureService.ModelName("T-Rex"), "TRex", "nom de module de T-Rex")
T.eq(EnclosureService.ModelName("Golden Raptor"), "GoldenRaptor", "nom de module de Golden Raptor")

T.section("revenus")
local income = IncomeService.DinoIncome(dino)
T.check(income > 0, "le dino rapporte")
T.near(IncomeService.GetIncome(alice), income, 1e-9, "revenu du joueur")
T.near(replica(alice, "Income"), income, 1e-9, "replica Income")
local test = { Species = "Compy", Size = "Big", Mutation = "Lava", Level = 1 }
T.near(IncomeService.DinoIncome(test), IncomeService.BaseIncome("Compy") * 1.5 * 3 * 4, 1e-9, "base x taille x mutation x niveau")
T.near(IncomeService.DinoIncome({ Species = "Compy", Size = "Small", Mutation = "", Level = 0 }), IncomeService.BaseIncome("Compy") * 0.8, 1e-9, "Small x0.8")
T.eq(IncomeService.BaseIncome("Nope"), 0, "espèce inconnue : 0")
IncomeService.RegisterBase("Ptero-Rex", 1234)
T.eq(IncomeService.BaseIncome("Ptero-Rex"), 1234, "base enregistrée (hybride)")
T.errors(function()
	IncomeService.RegisterBase("Bad", 0 / 0)
end, "invalide", "base NaN refusée")
local money = MoneyService.Get(alice)
env.advance(1)
T.near(MoneyService.Get(alice) - money, income, 1e-6, "versement chaque seconde")
passes[alice] = { DoubleMoney = true }
T.eq(IncomeService.Multiplier(alice), 2, "pass Double Money : x2")
IncomeService.SetMultiplier(alice, "Friends", 1.2)
T.near(IncomeService.Multiplier(alice), 2.4, 1e-9, "multiplicateur nommé")
IncomeService.SetMultiplier(alice, "Friends", nil)
passes[alice] = nil
T.eq(IncomeService.Multiplier(alice), 1, "multiplicateurs retirés")
T.errors(function()
	IncomeService.SetMultiplier(alice, "Bad", -1)
end, "invalide", "multiplicateur négatif refusé")

T.section("enclos plein et agrandissement")
MoneyService.Set(alice, 0, "Test")
while EnclosureService.HasRoom(alice) do
	EnclosureService.AddDino(alice, { Species = "Compy" })
end
T.eq(EnclosureService.Count(alice), Economy.Enclosure.BaseSlots, "enclos rempli")
T.eq(EnclosureService.AddDino(alice, { Species = "Compy" }), nil, "plus de place")
env.advance(60)
ok, text = ReviveService.Reveal(alice, 2)
T.check(not ok and string.find(text, "full", 1, true) ~= nil, "enclos plein : révélation refusée")
T.check(data.Tanks["2"] ~= nil, "le bloc reste dans sa cuve")
ok, text = env.invokeServer(alice, "BuyEnclosure")
T.check(not ok and text == "Not enough money!", "agrandir sans argent")
MoneyService.Set(alice, 1e6, "Test")
ok = env.invokeServer(alice, "BuyEnclosure")
T.check(ok, "agrandissement acheté")
T.eq(MoneyService.Get(alice), 1e6 - Economy.Enclosure.Prices[1], "prix payé")
T.eq(EnclosureService.Slots(alice), Economy.Enclosure.BaseSlots + Economy.Enclosure.SlotsPerUpgrade, "slots en plus")
T.eq(replica(alice, "EnclosureSlots"), EnclosureService.Slots(alice), "replica EnclosureSlots")
ok = ReviveService.Reveal(alice, 2)
T.check(ok, "révélation possible après l'agrandissement")
data.EnclosureUpgrades = #Economy.Enclosure.Prices
ok, text = EnclosureService.BuyUpgrade(alice)
T.check(not ok and string.find(text, "max", 1, true) ~= nil, "enclos au maximum")
-- retirer un dino (fusion du brief 8)
local removedId = next(data.Dinos)
local removed = EnclosureService.RemoveDino(alice, removedId)
T.check(removed ~= nil and data.Dinos[removedId] == nil, "RemoveDino")
T.eq(EnclosureService.ModelOf(alice, removedId), nil, "modèle retiré")
T.eq(EnclosureService.RemoveDino(alice, removedId), nil, "RemoveDino deux fois : nil")
T.eq(EnclosureService.RemoveDino(alice, 5 :: any), nil, "identifiant invalide : nil")

T.section("acheter des cuves")
MoneyService.Set(alice, 0, "Test")
ok, text = env.invokeServer(alice, "BuyTank")
T.check(not ok and text == "Not enough money!", "cuve sans argent")
while ReviveService.AddBlock(alice, { Rarity = "Common", Zone = "Beach" }) and #data.Stored == 0 do
end
data.Stored = { { Rarity = "Epic", Zone = "Swamp" } }
T.check(data.Tanks["1"] ~= nil and data.Tanks["2"] ~= nil, "cuves 1 et 2 occupées")
MoneyService.Set(alice, 1e9, "Test")
ok = env.invokeServer(alice, "BuyTank")
T.check(ok, "cuve 3 achetée")
T.eq(data.TankCount, 3, "3 cuves")
T.eq(MoneyService.Get(alice), 1e9 - Economy.Tanks.Prices[1], "prix de la cuve 3")
T.eq(data.Tanks["3"] and data.Tanks["3"].Rarity, "Epic", "le bloc en réserve part dans la nouvelle cuve")
T.eq(#data.Stored, 0, "réserve vidée")
T.eq(plot.Tanks[4].TankPrompt.ActionText, "Buy Tank ($25K)", "cuve 4 proposée")
for _ = 4, 6 do
	T.check(ReviveService.BuyTank(alice), "cuve achetée")
end
ok, text = ReviveService.BuyTank(alice)
T.check(not ok and text == "You have all the tanks!", "6 cuves au maximum")

T.section("passes et produits du brief 4")
for key in data.Tanks do
	data.Tanks[key] = nil
end
passes[alice] = { FastRevive = true }
ReviveService.AddBlock(alice, { Rarity = "Rare", Zone = "Canyon" })
T.eq(data.Tanks["1"].EndsAt - data.Tanks["1"].StartedAt, 90, "Fast Revive : 2x plus rapide")
passes[alice] = nil
T.eq(ReviveService.Running(alice), 1, "une cuve en cours")
T.eq(ReviveService.FinishAll(alice), 1, "FinishAll")
T.eq(ReviveService.Running(alice), 0, "plus rien en cours")
ok = ReceiptService.Simulate(alice, "InstantRevive")
T.check(ok, "Instant Revive sans cuve en cours : gardé pour plus tard")
T.eq(data.InstantCredits, 1, "1 Instant Revive gardé")
T.eq(replica(alice, "InstantCredits"), 1, "le client le sait")
ReviveService.AddBlock(alice, { Rarity = "Legendary", Zone = "Canyon" })
T.eq(data.Tanks["2"] and data.Tanks["2"].EndsAt - data.Tanks["2"].StartedAt, 0, "la cuve suivante est prête tout de suite")
T.eq(data.InstantCredits, 0, "Instant Revive gardé utilisé")
T.eq(ReviveService.Running(alice), 0, "rien en cours")
data.InstantCredits = Economy.MaxInstantCredits
ok = ReceiptService.Simulate(alice, "InstantRevive")
T.check(not ok, "trop d'Instant Revive gardés : pas donné")
data.InstantCredits = 0
ReviveService.AddBlock(alice, { Rarity = "Mythic", Zone = "Volcano" })
ok = ReceiptService.Simulate(alice, "InstantRevive")
T.check(ok, "Instant Revive donné")
T.eq(ReviveService.Running(alice), 0, "Instant Revive finit les cuves")
T.eq(ReviveService.MutationLuck(alice), 0, "sans VIP : pas de bonus de chance")
passes[alice] = { VIP = true }
T.near(ReviveService.MutationLuck(alice), 0.5, 1e-9, "VIP LuckBonus 1.5 : mutations x1.5 (+50 %)")
shopValues.Passes.VIP.LuckBonus = 1.1
T.near(ReviveService.MutationLuck(alice), 0.1, 1e-9, "VIP LuckBonus 1.1 : +10 %")
for _, bad in { 0 / 0, math.huge, -2, 0.5, "x" } do
	shopValues.Passes.VIP.LuckBonus = bad
	T.eq(ReviveService.MutationLuck(alice), 0, "LuckBonus invalide ignoré : " .. tostring(bad))
end
shopValues.Passes.VIP.LuckBonus = 1.5
for slot = 1, 2 do
	ok = ReviveService.Reveal(alice, slot)
	T.check(ok, "révélation avec le pass VIP (cuve " .. slot .. ")")
end
passes[alice] = nil

T.section("tirages")
local invalid = 0
local sizes, mutations = {}, {}
for _, zone in Zones.List do
	for rarity in zone.Weights do
		local candidates = ReviveService.Candidates(rarity, zone.Name)
		T.check(#candidates > 0, zone.Name .. " " .. rarity .. " : des espèces")
		for _ = 1, 30 do
			local rolled = ReviveService.Roll(rarity, zone.Name)
			if not table.find(candidates, rolled.Species) or Rarity.Species[rolled.Species] ~= rarity then
				invalid += 1
			end
			sizes[rolled.Size] = true
			mutations[rolled.Mutation] = true
		end
	end
end
T.eq(invalid, 0, "espèce toujours de la rareté et de la zone")
T.check(sizes.Small and sizes.Normal and sizes.Big, "plusieurs tailles tirées")
T.check(mutations[""] == true, "sans mutation la plupart du temps")
for name in sizes do
	local known = false
	for _, size in Economy.Sizes do
		known = known or size.Name == name
	end
	T.check(known, "taille connue : " .. name)
end
T.eq(ReviveService.Roll("Common", "Beach", 1e9).Mutation, "Lava", "chance énorme : la mutation la plus rare")
T.eq(Rarity.Species[ReviveService.Roll("Secret", "Beach").Species], "Secret", "bloc Secret : espèce Secret")
T.check(#ReviveService.Candidates("Mythic", "") > 0, "bloc sans zone : espèces de la rareté")

T.section("prompts des cuves")
local bob = T.join({ Name = "Bob", Character = true })
env.flush()
ReviveService.AddBlock(alice, { Rarity = "Common", Zone = "Beach" })
ReviveService.FinishAll(alice)
env.advance(1.5)
local readySlot = nil
for key, t in data.Tanks do
	if t.EndsAt <= os.time() then
		readySlot = tonumber(key)
	end
end
local prompt = plot.Tanks[readySlot].TankPrompt
local before = EnclosureService.Count(alice)
env.fire(env.signal(prompt, "Triggered"), bob)
env.flush()
T.eq(lastNotify(bob), "This is not your park!", "un autre joueur ne révèle pas")
T.eq(EnclosureService.Count(alice), before, "rien révélé par Bob")
env.fire(env.signal(prompt, "Triggered"), alice)
env.flush()
T.eq(EnclosureService.Count(alice), before + 1, "le propriétaire révèle par le prompt")

T.section("remotes hostiles")
for _, value in T.hostileValues() do
	RateLimit.Reset(alice)
	local okReveal = env.invokeServer(alice, "RevealTank", value)
	if okReveal then
		T.check(false, "RevealTank accepté avec " .. T.show(value))
	end
end
T.clean("aucune erreur avec des valeurs hostiles")
T.eq(#Boot.Services.DataService.Problems(data), 0, "données intactes")

T.section("commandes d'admin")
local admin = T.join({ Name = "Admin", UserId = 3346721423 })
ok, text = AdminService.Run(alice, "givedino", { "trex" })
T.check(not ok and text == "Not allowed", "commande refusée à un joueur normal")
data.EnclosureUpgrades = #Economy.Enclosure.Prices
local cleared = 0
for key in data.Dinos do
	if cleared < 3 then
		EnclosureService.RemoveDino(alice, key)
		cleared += 1
	end
end
ok, text = AdminService.Run(admin, "givedino", { "trex", "Huge", "Crystal", "Alice" })
T.check(ok, "givedino : " .. tostring(text))
local lastId = tostring(data.NextDinoId - 1)
T.eq(data.Dinos[lastId].Species, "T-Rex", "givedino : espèce trouvée")
T.eq(data.Dinos[lastId].Size, "Huge", "givedino : taille")
T.eq(data.Dinos[lastId].Mutation, "Crystal", "givedino : mutation")
ok = AdminService.Run(admin, "givedino", { "nope", "Normal", "none", "Alice" })
T.check(not ok, "givedino : espèce inconnue")
ok, text = AdminService.Run(admin, "giveblock", { "legendary", "4", "Alice" })
T.check(ok, "giveblock : " .. tostring(text))
ok = AdminService.Run(admin, "giveblock", { "gold", "1", "Alice" })
T.check(not ok, "giveblock : rareté inconnue")
ok, text = AdminService.Run(admin, "finishtanks", { "Alice" })
T.check(ok, "finishtanks : " .. tostring(text))

T.section("revenu hors ligne et cuves finies hors ligne")
for key in data.Tanks do
	data.Tanks[key] = nil
end
ReviveService.AddBlock(alice, { Rarity = "Legendary", Zone = "Canyon" })
local perSecond = IncomeService.GetIncome(alice)
T.check(perSecond > 0, "Alice a un revenu")
local userId = alice.UserId
local earnedBefore = data.TotalEarned
T.leave(alice)
env.advance(9 * 3600)
local back = T.join({ UserId = userId, Name = "Alice", Character = true })
env.flush()
local moneyBack = MoneyService.Get(back)
local saved = T.data(back)
T.check(moneyBack >= perSecond * Economy.OfflineCap * 0.99, "revenu hors ligne versé (" .. moneyBack .. ")")
T.check(saved.TotalEarned >= earnedBefore + perSecond * Economy.OfflineCap * 0.99, "compté dans TotalEarned")
T.check(saved.TotalEarned < earnedBefore + perSecond * (Economy.OfflineCap + 60), "plafonné à 8 h (absent 9 h)")
local offline, readyMessage = false, false
for _, sent in env.received(back, "Notify") do
	offline = offline or string.find(sent[1], "while away", 1, true) ~= nil
	readyMessage = readyMessage or string.find(sent[1], "ready to reveal in your park", 1, true) ~= nil
end
T.check(offline, "message « while away »")
T.check(readyMessage, "cuve finie hors ligne annoncée")
T.check(saved.Tanks["1"].EndsAt <= os.time(), "la cuve Legendary a fini hors ligne")
T.check(PlotService.Get(back).Tanks[1].TankPrompt.Enabled, "Reveal proposé à l'arrivée")

T.done("loop_revive")
