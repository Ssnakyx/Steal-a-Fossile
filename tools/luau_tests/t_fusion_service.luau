-- Fusion (brief 8) : FusionService. Recettes chargées, secret des recettes (replica, aperçu), labo du parc, fusion
-- Upgrade (règles, coût, meilleure taille et mutation), recette inconnue (rien ne bouge), fusion hybride (découverte,
-- modèle de la chimère, revenu), ids hostiles, double fusion, limite de fréquence, commandes d'admin, sauvegarde.
local T = require("./testkit")
local env = T.env
local CFrame = env.CFrame

env.studio = false -- (les sauvegardes sont écrites : découvertes gardées au retour)
env.quiet = true

local Boot = T.bootServer()
local FusionService = Boot.Services.FusionService
local EnclosureService = Boot.Services.EnclosureService
local IncomeService = Boot.Services.IncomeService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Config = T.config()
local Fusion = T.module("src/shared/Config/Fusion")
local Economy = T.module("src/shared/Config/Economy")
local Rarity = T.module("src/shared/Config/Rarity")
local HybridBuilder = T.module("src/shared/HybridBuilder")
local Recipes = T.module("src/server/ServerConfig/Fusion").Recipes
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local CollectionService = env.game:GetService("CollectionService")
local ReplicatedStorage = env.game:GetService("ReplicatedStorage")

local UNKNOWN_TEXT = "Unknown recipe! Your dinos are safe. Try another pair."

local function replica(player, key: string): any
	ReplicaService.Flush()
	return ReplicaService.Get(player, key)
end

local function lastNotify(player): string?
	local list = env.received(player, "Notify")
	local last = list[#list]
	return if last then last[1] else nil
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function give(player, species: string, size: string?, mutation: string?, level: number?): string
	local id = EnclosureService.AddDino(player, { Species = species, Size = size, Mutation = mutation, Level = level })
	assert(id, "enclos plein")
	return id
end

-- tous les textes d'une valeur (récursif)
local function texts(value: any, out: { string }): { string }
	if type(value) == "string" then
		table.insert(out, value)
	elseif type(value) == "table" then
		for k, v in value do
			texts(k, out)
			texts(v, out)
		end
	end
	return out
end

local signals: { [string]: { any } } = { DinosFused = {}, HybridDiscovered = {} }
for name, list in signals do
	Signals.Connect(name, function(...)
		table.insert(list, table.pack(...))
	end)
end

T.section("recettes")
local hybrids = FusionService.Hybrids()
T.eq(#hybrids, #Recipes, "toutes les recettes chargées")
for index, hybrid in hybrids do
	local recipe = Recipes[index]
	local head, body = Config.Species.ByName[recipe.Head], Config.Species.ByName[recipe.Body]
	T.eq(hybrid.Id, index, hybrid.Name .. " : ordre de l'Index")
	T.eq(hybrid.Key, HybridBuilder.Key(head.Model, body.Model, recipe.Tweak), hybrid.Name .. " : clé tête+corps")
	T.near(hybrid.Income, (head.Income + body.Income) * Fusion.HybridIncome, 1e-6, hybrid.Name .. " : revenu (A + B) x 1,5")
	T.near(IncomeService.BaseIncome(hybrid.Name), hybrid.Income, 1e-6, hybrid.Name .. " : revenu enregistré")
	T.eq(hybrid.BaseSize, body.BaseSize, hybrid.Name .. " : taille de base du corps")
	local rank = math.max(Rarity.Rank(Rarity.Species[head.Name]), Rarity.Rank(Rarity.Species[body.Name]))
	T.eq(hybrid.Rarity, Rarity.Order[rank], hybrid.Name .. " : rareté la plus haute")
	T.eq(EnclosureService.ModelName(hybrid.Name), hybrid.Key, hybrid.Name .. " : modèle = clé")
	T.check(FusionService.FindRecipe(head.Name, body.Name) == hybrid and FusionService.FindRecipe(body.Name, head.Name) == hybrid, hybrid.Name .. " : recette dans les deux sens")
	T.check(FusionService.IsHybrid(hybrid.Name) and FusionService.Get(hybrid.Name) == hybrid, hybrid.Name .. " : IsHybrid, Get")
end
T.check(FusionService.FindRecipe("T-Rex", "T-Rex") == nil, "pas de recette avec deux fois la même espèce")
T.check(FusionService.FindRecipe("Velociraptor", "Stegosaurus") == nil, "paire sans recette")
T.check(FusionService.FindRecipe(nil :: any, 5 :: any) == nil, "FindRecipe hostile")
T.check(not FusionService.IsHybrid("T-Rex"), "une espèce n'est pas un hybride")
T.check(Config.Fusion.Recipes == nil, "pas de recettes dans Config (répliqué)")
local shared = texts(T.module("src/shared/Config"), {})
local leaked = false
for _, hybrid in hybrids do
	for _, text in shared do
		if text == hybrid.Name or text == hybrid.Key then
			leaked = true
		end
	end
end
T.check(not leaked, "aucun nom ni clé d'hybride dans Config (répliqué)")
T.check(ReplicatedStorage:FindFirstChild("ServerConfig", true) == nil, "ServerConfig pas dans ReplicatedStorage")

T.section("départ")
local alice = T.join({ Name = "Alice", Character = true })
local bob = T.join({ Name = "Bob", Character = true })
env.flush()
local data = T.data(alice)
data.EnclosureUpgrades = #Economy.Enclosure.Prices
local index = replica(alice, "Hybrids")
T.eq(index.Total, #hybrids, "replica Hybrids : Total")
T.eq(index.Found, 0, "replica Hybrids : rien de trouvé")
T.eq(#index.List, #hybrids, "replica Hybrids : une ligne par recette")
local onlyHints = true
for i, entry in index.List do
	if entry.Id ~= i or entry.Hint ~= hybrids[i].Hint or entry.Found ~= false or count(entry) ~= 3 then
		onlyHints = false
	end
end
T.check(onlyHints, "replica Hybrids : seulement Id, Hint, Found avant la découverte")
local function secretsVisible(player): boolean
	ReplicaService.Flush()
	local snapshot = ReplicaService.Snapshot(player)
	local list = texts(snapshot, {})
	for _, hybrid in hybrids do
		for _, text in list do
			if text == hybrid.Name or text == hybrid.Key then
				return true
			end
		end
	end
	return false
end
T.check(not secretsVisible(alice), "aucun nom ni clé d'hybride dans l'état du joueur")

T.section("labo")
local plot = PlotService.Get(alice)
local prompt = plot.Lab:FindFirstChild("LabPrompt")
T.check(prompt ~= nil and prompt:IsA("ProximityPrompt"), "prompt du labo")
T.eq(prompt.ActionText, "Fuse", "prompt : Fuse")
T.eq(prompt.ObjectText, "Fusion Lab", "prompt : Fusion Lab")
T.eq(prompt:GetAttribute("OwnerUserId"), alice.UserId, "prompt marqué au propriétaire")
env.fire(env.signal(prompt, "Triggered"), alice)
env.flush()
T.eq(#env.received(alice, "OpenFusionLab"), 1, "le propriétaire ouvre le labo")
env.fire(env.signal(prompt, "Triggered"), bob)
env.flush()
T.eq(#env.received(bob, "OpenFusionLab"), 0, "un autre joueur n'ouvre pas le labo")
T.eq(lastNotify(bob), "This is not your park!", "un autre joueur est prévenu")
for _ = 1, 20 do
	env.fire(env.signal(prompt, "Triggered"), alice)
end
env.flush()
T.check(#env.received(alice, "OpenFusionLab") <= 5, "labo : limite de fréquence")

T.section("améliorer")
local a = give(alice, "Triceratops", "Small", nil)
local b = give(alice, "Triceratops", "Big", "Amber")
local c = give(alice, "Triceratops", "Normal", "Crystal")
local upgradeIds = { a, b, c }
local income = 0
for _, id in upgradeIds do
	income += IncomeService.DinoIncome(data.Dinos[id])
end
local upgradeCost = math.max(Fusion.MinCost, math.floor(income * Fusion.CostSeconds.Upgrade))
local ok, info = FusionService.Preview(alice, upgradeIds)
T.check(ok, "aperçu Upgrade")
T.eq(info.Mode, "Upgrade", "aperçu : mode")
T.eq(info.Known, true, "aperçu : connu")
T.eq(info.Species, "Triceratops", "aperçu : espèce")
T.eq(info.Size, "Big", "aperçu : meilleure taille")
T.eq(info.Mutation, "Crystal", "aperçu : meilleure mutation")
T.eq(info.Level, 1, "aperçu : niveau suivant")
T.eq(info.LevelName, "Golden", "aperçu : Golden")
T.eq(info.Cost, upgradeCost, "aperçu : coût")
T.near(info.Income, IncomeService.DinoIncome({ Species = "Triceratops", Size = "Big", Mutation = "Crystal", Level = 1 }), 1e-6, "aperçu : revenu")
alice.Character:PivotTo(CFrame.new(0, 100, 0))
local text
ok, text = FusionService.Fuse(alice, upgradeIds)
T.check(not ok and text == "Go to the lab in your park to fuse!", "hors du parc : refusé")
PlotService.Teleport(alice)
T.check(PlotService.IsInOwnPlot(alice), "de retour dans son parc")
ok, text = FusionService.Fuse(alice, upgradeIds)
T.check(not ok and string.find(text, "Not enough money", 1, true) ~= nil, "sans argent : refusé (" .. tostring(text) .. ")")
T.check(data.Dinos[a] and data.Dinos[b] and data.Dinos[c], "sans argent : dinos gardés")
MoneyService.Add(alice, upgradeCost + 1000, "Test")
local fusedBefore = #signals.DinosFused
local done = #env.received(alice, "FusionDone")
ok, text, info = FusionService.Fuse(alice, upgradeIds)
env.flush()
T.check(ok, "Upgrade : " .. tostring(text))
T.eq(text, "You made a " .. EnclosureService.DisplayName(data.Dinos[info.Id]) .. "!", "Upgrade : texte")
T.eq(data.Money, 1000, "Upgrade : coût payé")
T.check(data.Dinos[a] == nil and data.Dinos[b] == nil and data.Dinos[c] == nil, "Upgrade : les 3 dinos sont partis")
local up = data.Dinos[info.Id]
T.check(up ~= nil, "Upgrade : nouveau dino")
T.eq(up.Species, "Triceratops", "Upgrade : espèce")
T.eq(up.Level, 1, "Upgrade : Golden")
T.eq(up.Size, "Big", "Upgrade : meilleure taille")
T.eq(up.Mutation, "Crystal", "Upgrade : meilleure mutation")
local model = EnclosureService.ModelOf(alice, info.Id)
T.check(model ~= nil and model:GetAttribute("Level") == "Golden" and model:GetAttribute("State") == Fusion.ResultState, "Upgrade : modèle Golden qui rugit")
T.eq(#env.received(alice, "FusionDone") - done, 1, "Upgrade : FusionDone envoyé")
local sent = env.received(alice, "FusionDone")[done + 1][1]
T.eq(sent.Id, info.Id, "FusionDone : id")
T.eq(sent.Mode, "Upgrade", "FusionDone : mode")
T.eq(table.concat(sent.Inputs, ","), "Triceratops,Triceratops,Triceratops", "FusionDone : dinos utilisés")
T.eq(sent.New, false, "FusionDone : pas une découverte")
T.eq(#signals.DinosFused - fusedBefore, 1, "signal DinosFused")
T.eq(signals.DinosFused[#signals.DinosFused][2], "Upgrade", "signal DinosFused : mode")
T.eq(count(data.Index.Hybrids), 0, "Upgrade : rien découvert")
-- erreurs
local g1, g2 = give(alice, "Triceratops", nil, nil, 1), give(alice, "Triceratops", nil, nil, 1)
ok, text = FusionService.Preview(alice, { info.Id, g1, g2 })
T.check(ok and text.Level == 2 and text.LevelName == "Diamond", "Golden x3 -> Diamond")
local n1 = give(alice, "Triceratops")
ok, text = FusionService.Preview(alice, { info.Id, g1, n1 })
T.check(not ok and text == "Upgrade needs 3 dinos of the same level.", "niveaux différents : refusé")
local s1 = give(alice, "Stegosaurus", nil, nil, 1)
ok, text = FusionService.Preview(alice, { info.Id, g1, s1 })
T.check(not ok and text == "Upgrade needs 3 dinos of the same species.", "espèces différentes : refusé")
local m1, m2, m3 = give(alice, "Compy", nil, nil, 2), give(alice, "Compy", nil, nil, 2), give(alice, "Compy", nil, nil, 2)
ok, text = FusionService.Fuse(alice, { m1, m2, m3 })
T.check(not ok and text == "This dino is already at max level!", "niveau max : refusé")
ok, text = FusionService.Preview(alice, { g1, g2 })
T.check(not ok and string.find(text, "2 different species", 1, true) ~= nil, "deux dinos de la même espèce : refusé")
for _, id in { g1, g2, n1, s1, m1, m2, m3, info.Id } do
	EnclosureService.RemoveDino(alice, id)
end
T.eq(count(data.Dinos), 0, "enclos vidé")

T.section("ids hostiles")
local v1, v2 = give(alice, "Velociraptor"), give(alice, "Velociraptor")
local bobId = give(bob, "Megalodon")
local hostileIds = {
	{},
	{ v1 },
	{ v1, v1 },
	{ v1, v2, v1 },
	{ v1, v2, "1", "2" },
	{ [1] = v1, [3] = v2 },
	{ x = v1, y = v2 },
	{ v1, 5 },
	{ v1, "-1" },
	{ v1, "1.5" },
	{ v1, "99999" },
	{ v1, " " .. v2 },
	{ v1, string.rep("1", 13) },
	{ v1, bobId .. "0" },
}
local refused = true
for _, ids in hostileIds do
	local okPreview = FusionService.Preview(alice, ids)
	local okFuse = FusionService.Fuse(alice, ids)
	if okPreview or okFuse then
		refused = false
		print("accepté : " .. T.show(table.concat(ids, ",")))
	end
end
T.check(refused, "listes d'ids invalides refusées")
local money = data.Money
local before = count(data.Dinos)
for _, value in T.hostileValues() do
	RateLimit.Reset(alice)
	local okPreview = env.invokeServer(alice, "PreviewFusion", value)
	RateLimit.Reset(alice)
	local okFuse = env.invokeServer(alice, "FuseDinos", value)
	RateLimit.Reset(alice)
	local okTwo = env.invokeServer(alice, "FuseDinos", { v1, value })
	if okPreview or okFuse or okTwo then
		refused = false
		print("accepté : " .. T.show(value))
	end
end
T.check(refused, "remotes : valeurs hostiles refusées")
T.clean("aucune erreur avec des valeurs hostiles")
T.eq(data.Money, money, "argent intact")
T.eq(count(data.Dinos), before, "dinos intacts")
T.eq(#Boot.Services.DataService.Problems(data), 0, "données valides")
-- un dino d'un autre joueur : Bob ne peut pas fusionner ceux d'Alice
local okBob, textBob = FusionService.Preview(bob, { bobId, v1 })
T.check(not okBob or textBob.Known == false, "Bob : ids d'Alice inconnus chez lui")
EnclosureService.RemoveDino(alice, v1)
EnclosureService.RemoveDino(alice, v2)

T.section("recette inconnue")
local r = give(alice, "Velociraptor")
local s = give(alice, "Stegosaurus")
local unknownPreviewOk, unknown = FusionService.Preview(alice, { r, s })
T.check(unknownPreviewOk, "aperçu d'une paire sans recette")
T.eq(unknown.Mode, "Hybrid", "aperçu : mode Hybrid")
T.eq(unknown.Known, false, "aperçu : inconnu")
T.eq(unknown.Species, Fusion.UnknownName, "aperçu : ???")
money = data.Money
ok, text = FusionService.Fuse(alice, { r, s })
T.check(not ok and text == UNKNOWN_TEXT, "recette inconnue : « Unknown recipe »")
T.check(data.Dinos[r] ~= nil and data.Dinos[s] ~= nil, "recette inconnue : dinos gardés")
T.eq(data.Money, money, "recette inconnue : rien payé")
local rs = env.invokeServer(alice, "FuseDinos", { r, s })
T.check(rs == false, "recette inconnue par le remote")
EnclosureService.RemoveDino(alice, r)

T.section("hybride")
local hybrid = FusionService.Get("Tricera-Stego") :: any
local t1 = give(alice, "Triceratops", "Small", nil, 1)
local okPreview, secret = FusionService.Preview(alice, { s, t1 })
T.check(okPreview, "aperçu d'une vraie recette")
local sameShape = count(secret) == count(unknown)
for key, value in unknown do
	if key ~= "Cost" and secret[key] ~= value then
		sameShape = false
	end
end
T.check(sameShape, "aperçu d'une recette pas découverte = aperçu d'une paire sans recette")
T.check(not secretsVisible(alice), "recette toujours secrète")
data.Dinos[s].Size = "Huge"
data.Dinos[s].Mutation = "Lava"
local hybridIncome = IncomeService.DinoIncome(data.Dinos[s]) + IncomeService.DinoIncome(data.Dinos[t1])
local hybridCost = math.max(Fusion.MinCost, math.floor(hybridIncome * Fusion.CostSeconds.Hybrid))
T.eq(select(2, FusionService.Preview(alice, { s, t1 })).Cost, hybridCost, "aperçu : coût Hybrid")
MoneyService.Add(alice, hybridCost, "Test")
money = data.Money
local discovered = #signals.HybridDiscovered
done = #env.received(alice, "FusionDone")
ok, text, info = FusionService.Fuse(alice, { s, t1 })
env.flush()
T.check(ok, "hybride : " .. tostring(text))
T.eq(text, "New hybrid discovered: " .. EnclosureService.DisplayName(data.Dinos[info.Id]) .. "!", "hybride : texte de découverte")
T.eq(data.Money, money - hybridCost, "hybride : coût payé")
local made = data.Dinos[info.Id]
T.eq(made.Species, "Tricera-Stego", "hybride : espèce = nom de la recette")
T.eq(made.Size, "Huge", "hybride : meilleure taille")
T.eq(made.Mutation, "Lava", "hybride : meilleure mutation")
T.eq(made.Level, 0, "hybride : plus petit niveau des parents")
T.check(data.Dinos[s] == nil and data.Dinos[t1] == nil, "hybride : les parents sont partis")
T.near(IncomeService.DinoIncome(made), hybrid.Income * 3 * 3, 1e-6, "hybride : revenu (A + B) x 1,5 x taille x mutation")
T.check(data.Index.Hybrids["Tricera-Stego"] == true, "hybride : découvert")
T.eq(#signals.HybridDiscovered - discovered, 1, "signal HybridDiscovered")
T.eq(info.Known, true, "infos : connu")
T.eq(info.Key, hybrid.Key, "infos : clé de la chimère")
T.eq(info.Rarity, hybrid.Rarity, "infos : rareté")
T.eq(info.New, true, "infos : nouveau")
local sentHybrid = env.received(alice, "FusionDone")[done + 1]
T.check(sentHybrid ~= nil and sentHybrid[1].Key == hybrid.Key and sentHybrid[1].New == true, "FusionDone : clé et découverte")
model = EnclosureService.ModelOf(alice, info.Id)
T.check(model ~= nil, "hybride : modèle dans l'enclos")
T.eq(model:GetAttribute("Species"), hybrid.Key, "modèle : attribut Species = clé de la chimère")
T.eq(model:GetAttribute("Rarity"), hybrid.Rarity, "modèle : attribut Rarity (effets de rareté)")
T.eq(model:GetAttribute("State"), "Roar", "modèle : rugit")
T.check(CollectionService:HasTag(model, "Dino"), "modèle : tagué Dino (animé par le client)")
T.check(model:FindFirstChild("Body") == nil and model:FindFirstChild("Head") == nil, "modèle : pas de dino provisoire")
T.eq(replica(alice, "Dinos")[info.Id].Species, "Tricera-Stego", "replica Dinos : l'hybride")
index = replica(alice, "Hybrids")
T.eq(index.Found, 1, "replica Hybrids : 1 trouvé")
local entry = index.List[hybrid.Id]
T.check(entry.Found and entry.Name == "Tricera-Stego" and entry.Key == hybrid.Key and entry.Head == "Triceratops" and entry.Body == "Stegosaurus" and entry.Rarity == hybrid.Rarity, "replica Hybrids : fiche complète une fois trouvé")
local others = 0
for _, line in index.List do
	if line.Name then
		others += 1
	end
end
T.eq(others, 1, "replica Hybrids : les autres restent secrets")
-- deuxième fois : connu, pas une découverte, dans l'autre sens
local t2, s2 = give(alice, "Triceratops"), give(alice, "Stegosaurus", "Big")
ok, info = FusionService.Preview(alice, { t2, s2 })
T.check(ok and info.Known and info.Species == "Tricera-Stego" and info.Key == hybrid.Key and info.Size == "Big", "aperçu : connu après la découverte")
MoneyService.Add(alice, 1e9, "Test")
discovered = #signals.HybridDiscovered
ok, text, info = FusionService.Fuse(alice, { t2, s2 })
T.check(ok and text == "You made a " .. EnclosureService.DisplayName(data.Dinos[info.Id]) .. "!" and info.New == false, "deuxième fois : pas une découverte")
T.eq(#signals.HybridDiscovered, discovered, "pas de signal HybridDiscovered")
-- double fusion des mêmes dinos
local p1, p2 = give(alice, "Pteranodon"), give(alice, "T-Rex")
money = data.Money
local first = table.pack(env.invokeServer(alice, "FuseDinos", { p1, p2 }))
local second = table.pack(env.invokeServer(alice, "FuseDinos", { p1, p2 }))
T.check(first[1] == true, "Ptero-Rex par le remote : " .. tostring(first[2]))
T.check(second[1] == false and second[2] == "This dino is not in your park.", "mêmes dinos une deuxième fois : refusé")
T.eq(data.Dinos[first[3].Id].Species, "Ptero-Rex", "Ptero-Rex dans l'enclos")
T.check(data.Money < money, "une seule fusion payée")
T.clean("aucune erreur pendant les fusions")

T.section("limite de fréquence")
local x1, x2 = give(alice, "Velociraptor"), give(alice, "Stegosaurus")
RateLimit.Reset(alice)
local results = T.spam(alice, "FuseDinos", 30, { x1, x2 })
local handled = 0
for _, result in results do
	if result[2] == UNKNOWN_TEXT then
		handled += 1
	end
end
T.check(handled >= 1 and handled <= 5, "FuseDinos : limite de fréquence (" .. handled .. " traités sur 30)")
RateLimit.Reset(alice)
results = T.spam(alice, "PreviewFusion", 50, { x1, x2 })
handled = 0
for _, result in results do
	if result[1] == true then
		handled += 1
	end
end
T.check(handled >= 1 and handled <= 12, "PreviewFusion : limite de fréquence (" .. handled .. " traités sur 50)")

T.section("enclos trop plein")
local o1, o2 = give(alice, "Pteranodon"), give(alice, "T-Rex")
local fillers = {}
while count(data.Dinos) < 12 do
	table.insert(fillers, give(alice, "Compy"))
end
local savedUpgrades = data.EnclosureUpgrades
data.EnclosureUpgrades = 0
T.check(EnclosureService.Count(alice) - 1 > EnclosureService.Slots(alice), "plus de dinos que de places")
money = data.Money
local dinosBefore = count(data.Dinos)
ok, text = FusionService.Fuse(alice, { o1, o2 })
T.check(not ok and text == "Your enclosure is too full!", "enclos trop plein : refusé (" .. tostring(text) .. ")")
T.eq(count(data.Dinos), dinosBefore, "enclos trop plein : dinos gardés")
T.eq(data.Money, money, "enclos trop plein : rien payé")
data.EnclosureUpgrades = savedUpgrades
ok = FusionService.Fuse(alice, { o1, o2 })
T.check(ok, "avec de la place : fusion faite")
for _, id in fillers do
	EnclosureService.RemoveDino(alice, id)
end

T.section("commandes d'admin")
local admin = T.join({ Name = "Admin", UserId = 3346721423 })
local adminData = T.data(admin)
adminData.EnclosureUpgrades = #Economy.Enclosure.Prices
ok, text = AdminService.Run(alice, "fuse", { x1, x2 })
T.check(not ok and text == "Not allowed", "fuse refusé à un joueur normal")
local q1, q2, q3 = give(admin, "Velociraptor"), give(admin, "Velociraptor"), give(admin, "Velociraptor")
ok, text = AdminService.Run(admin, "fuse", { q1, q2, q3 })
T.check(ok, "fuse (hors du parc, gratuit) : " .. tostring(text))
T.eq(adminData.Money, 0, "fuse : gratuit")
ok = AdminService.Run(admin, "fuse", { q1, q2 })
T.check(not ok, "fuse : ids partis")
ok, text = AdminService.Run(admin, "givehybrid", { "all" })
T.check(ok and text == string.format("%d hybrid(s) added", #hybrids), "givehybrid all : " .. tostring(text))
T.eq(count(adminData.Index.Hybrids), #hybrids, "givehybrid all : tout découvert")
T.eq(replica(admin, "Hybrids").Found, #hybrids, "replica Hybrids : tout trouvé")
local beforeGive = count(data.Dinos)
ok, text = AdminService.Run(admin, "givehybrid", { "crystal-dragon", "Huge", "Lava", "Alice" })
T.check(ok, "givehybrid à Alice : " .. tostring(text))
T.eq(count(data.Dinos), beforeGive + 1, "givehybrid : un dino de plus")
T.check(data.Index.Hybrids["Crystal Dragon"] == true, "givehybrid : découvert")
ok = AdminService.Run(admin, "givehybrid", { "nope" })
T.check(not ok, "givehybrid : nom inconnu")
ok, text = AdminService.Run(admin, "hybrids", { "Alice" })
T.check(ok and string.find(text, "[x] Tricera-Stego = Triceratops + Stegosaurus", 1, true) ~= nil, "hybrids : découverts marqués")
T.check(string.find(text, "Plesio-Shark = Plesiosaurus + Megalodon", 1, true) ~= nil, "hybrids : toutes les recettes")
T.clean("aucune erreur dans les commandes")

T.section("sauvegarde")
local userId = alice.UserId
local found = count(data.Index.Hybrids)
local dinos = count(data.Dinos)
T.leave(alice)
env.advance(60)
local back = T.join({ UserId = userId, Name = "Alice", Character = true })
env.flush()
local backData = T.data(back)
T.eq(count(backData.Index.Hybrids), found, "découvertes gardées")
T.eq(count(backData.Dinos), dinos, "dinos gardés")
T.eq(replica(back, "Hybrids").Found, found, "replica Hybrids au retour")
local hybridModels = 0
for id, dino in backData.Dinos do
	local hybridInfo = FusionService.Get(dino.Species)
	if hybridInfo then
		local m = EnclosureService.ModelOf(back, id)
		if m and m:GetAttribute("Species") == hybridInfo.Key and m:GetAttribute("Rarity") == hybridInfo.Rarity then
			hybridModels += 1
		end
	end
end
T.check(hybridModels >= 3, "chimères remises dans l'enclos au retour (" .. hybridModels .. ")")
local newPrompt = PlotService.Get(back).Lab:FindFirstChild("LabPrompt")
T.check(newPrompt ~= nil and newPrompt:GetAttribute("OwnerUserId") == userId, "prompt du labo au retour")
T.done("fusion_service")
