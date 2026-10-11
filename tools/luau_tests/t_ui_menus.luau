-- Interface du brief 12 (menus), serveur et client ensemble : Index des espèces (IndexService, silhouettes, pages des
-- zones et des hybrides, pastille), labo de fusion (choix, aperçu, AUTO PICK, fusion, réouverture après la révélation),
-- écran de révélation (file, fermeture toute seule, NEW!), étiquettes des dinos du parc, événements abîmés.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Config = T.config()
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local EnclosureService = Boot.Services.EnclosureService
local FusionService = Boot.Services.FusionService
local IndexService = Boot.Services.IndexService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local ReplicaService = Boot.Services.ReplicaService
local ReviveService = Boot.Services.ReviveService
local DinoBuilder = T.module("src/shared/DinoBuilder")
local CollectionService = env.game:GetService("CollectionService")

local player = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
local data = T.data(player)
data.Tutorial = 3
data.EnclosureUpgrades = #Config.Economy.Enclosure.Prices
ReplicaService.Set(player, "Tutorial", 3)
Boot.Services.DailyService.Claim(player) -- (pas de calendrier ouvert tout seul)
-- un dino déjà dans le parc avant l'arrivée du client
local firstId = EnclosureService.AddDino(player, { Species = "Compy" })
env.flush()

local function find(name: string, from: any?): any
	return (from or player.PlayerGui):FindFirstChild(name, true)
end

local function shown(text: string): boolean
	for _, inst in player.PlayerGui:GetDescendants() do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Visible and string.find(inst.Text, text, 1, true) then
			return true
		end
	end
	return false
end

local function click(button: any)
	env.fire(env.signal(button, "Activated"))
	env.advance(0.3)
end

local function dinoCount(): number
	local count = 0
	for _ in data.Dinos do
		count += 1
	end
	return count
end

T.section("IndexService")
local index = ReplicaService.Get(player, "Index")
T.check(type(index) == "table" and index.Species.Compy == true, "espèce du parc découverte")
T.eq(index.Found, 1, "Found")
T.eq(index.Total, #Config.Species.List, "Total : toutes les espèces")
T.check(data.Index.Species.Compy == true, "noté dans la sauvegarde")
T.check(not IndexService.Discover(player, "Compy"), "déjà découverte : pas nouvelle")
T.check(IndexService.Discover(player, "Pteranodon"), "Pteranodon : nouvelle")
for _, value in T.hostileValues() do
	T.check(not IndexService.Discover(player, value), "Discover hostile refusé")
end
T.check(not IndexService.Discover(player, "Ptero-Rex"), "un hybride n'est pas une espèce de l'Index")
env.flush()
T.eq(ReplicaService.Get(player, "Index").Found, 2, "deux espèces")

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
local Index, Lab, Reveal, Replica = C.IndexController, C.LabController, C.RevealController, C.ReplicaController
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(1)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

T.section("étiquettes des dinos")
local function modelOf(id: string): any
	for _, model in CollectionService:GetTagged(DinoBuilder.Tag) do
		if model:GetAttribute("DinoId") == id then
			return model
		end
	end
	return nil
end
local model = modelOf(firstId)
T.check(model ~= nil, "modèle du dino")
local label = model.Root.Label
T.eq(label:GetAttribute("Styled"), true, "étiquette restylée (dino déjà là)")
T.eq(label.Rarity.Text, "COMMON", "rareté")
T.eq(label.Title.Text, label:FindFirstChild("Name").Text, "nom du serveur")
T.check(not label:FindFirstChild("Name").Visible, "ancienne ligne cachée")
T.check(string.find(label.Rate.Text, "/s", 1, true) ~= nil, "revenu : " .. label.Rate.Text)
label.Income.Text = "$99/s"
T.eq(label.Rate.Text, "$99/s", "suit le texte du serveur")
local secondId = EnclosureService.AddDino(player, { Species = "Velociraptor", Mutation = "Amber" })
env.advance(0.5)
local second = modelOf(secondId)
T.eq(second.Root.Label:GetAttribute("Styled"), true, "dino ajouté ensuite : restylé")
T.eq(second.Root.Label.Rarity.Text, string.upper(Config.Rarity.Species.Velociraptor), "rareté du Velociraptor")
local children = #second.Root.Label:GetChildren()
C.DinoLabelController.Style(second, second.Root.Label)
T.eq(#second.Root.Label:GetChildren(), children, "Style deux fois : sans doublon")
local count = 0
for _, child in second.Root.Label:GetChildren() do
	if child.Name == "Title" then
		count += 1
	end
end
T.eq(count, 1, "une seule ligne de nom")

T.section("pastille de l'Index")
local badge = find("HudButtons").Index.Badge
T.eq(Index.Unseen(), 1, "Velociraptor (ajouté après l'arrivée) : pas encore vu")
IndexService.Discover(player, "Stegosaurus")
env.advance(1.5)
T.eq(Index.Unseen(), 2, "Stegosaurus en plus")
T.check(badge.Visible and badge.Count.Text == "2", "pastille : 2")

T.section("Index : pages des zones")
click(find("HudButtons").Index)
env.advance(0.5)
local backdrop = find("IndexBackdrop")
T.check(backdrop.Visible and Index.IsOpen(), "Index ouvert par le bouton")
env.advance(1.5)
T.eq(Index.Unseen(), 0, "vu à l'ouverture")
T.check(not badge.Visible, "pastille partie")
Index.Open("Beach")
env.advance(0.3)
local grid = find("Grid", backdrop)
local compy = grid:FindFirstChild("Compy")
T.check(compy ~= nil, "carte Compy")
T.eq(compy.Title.Text, "Compy", "découverte : nom")
T.check(compy.Portrait ~= nil and compy.Portrait.ImageColor3.R > 0.5, "portrait en couleurs")
local beach = {}
for _, def in Config.Species.List do
	if def.Zone == "Beach" and Config.Rarity.Species[def.Name] ~= "Secret" then
		table.insert(beach, def.Name)
	end
end
local unknown = nil
for _, name in beach do
	if not data.Index.Species[name] then
		unknown = name
	end
end
T.check(unknown ~= nil, "une espèce de la plage pas encore vue")
local hidden = grid:FindFirstChild(unknown)
T.eq(hidden.Title.Text, "???", "pas vue : ???")
T.check(hidden.Portrait.ImageColor3.R < 0.1, "pas vue : silhouette noire")
T.check(string.find(find("Count", backdrop).Text, "/" .. #beach, 1, true) ~= nil, "compte de la page : " .. find("Count", backdrop).Text)
T.check(string.find(find("Totals", backdrop).Text, "Dinos 4/", 1, true) ~= nil, "totaux : " .. find("Totals", backdrop).Text)
for _, zone in Config.Zones.List do
	Index.Open(zone.Name)
	env.advance(0.1)
	T.check(#grid:GetChildren() > 1, "page " .. zone.Name .. " remplie")
end

T.section("Index : hybrides")
Index.Open("Hybrids")
env.advance(0.3)
local cards = 0
for _, child in grid:GetChildren() do
	if string.sub(child.Name, 1, 6) == "Hybrid" then
		cards += 1
		T.eq(child.Title.Text, "???", "hybride pas trouvé : ???")
	end
end
T.eq(cards, #FusionService.Hybrids(), "une carte par hybride")
FusionService.Discover(player, "Ptero-Rex")
FusionService.Publish(player)
env.advance(0.6)
local foundCard = nil
for _, child in grid:GetChildren() do
	if child:FindFirstChild("Title") and child.Title.Text == "Ptero-Rex" then
		foundCard = child
	end
end
T.check(foundCard ~= nil, "Ptero-Rex trouvé : nom affiché (page redessinée)")
local pteroRex = FusionService.Get("Ptero-Rex")
T.check(foundCard and string.find(foundCard.Info.Text, pteroRex.Head, 1, true) ~= nil, "recette montrée : " .. (foundCard and foundCard.Info.Text or "?"))
Index.Open("Nope")
env.advance(0.2)
Index.Close()
env.advance(0.3)
T.check(not backdrop.Visible, "Index fermé")
T.check(#grid:GetChildren() <= 2, "cartes et portraits libérés à la fermeture")

T.section("labo : ouverture par le parc")
MoneyService.Add(player, 1e9, "Test")
local compies = { firstId }
for _ = 1, 2 do
	table.insert(compies, EnclosureService.AddDino(player, { Species = "Compy" }))
end
env.advance(0.5)
local labPrompt = PlotService.Get(player).Lab:FindFirstChild("LabPrompt")
env.fire(env.signal(labPrompt, "Triggered"), player)
env.advance(0.5)
local lab = find("Fusion LabBackdrop")
T.check(lab.Visible and Lab.IsOpen(), "labo ouvert par le prompt")
T.check(not shown("Fusion Lab: 2 different dinos"), "pas d'aide provisoire")
local labGrid = find("Grid", lab)
local cardsInLab = 0
for _, child in labGrid:GetChildren() do
	if string.sub(child.Name, 1, 4) == "Dino" then
		cardsInLab += 1
	end
end
T.eq(cardsInLab, dinoCount(), "une carte par dino")

T.section("labo : choix et aperçu")
for _, id in compies do
	click(labGrid:FindFirstChild("Dino" .. id))
end
env.advance(0.5)
T.eq(#Lab.Selected(), 3, "3 Compy choisis par clic")
T.check(labGrid:FindFirstChild("Dino" .. compies[1]).Glow.Visible, "carte choisie en surbrillance")
local result = find("Result", lab)
T.check(string.find(result.Title.Text, "COMPY", 1, true) ~= nil, "aperçu : " .. result.Title.Text)
T.check(string.find(result.Text.Text, "LEVEL UP", 1, true) ~= nil, "montée de niveau : " .. result.Text.Text)
T.check(string.find(result.Cost.Text, "$", 1, true) ~= nil, "coût : " .. result.Cost.Text)
click(labGrid:FindFirstChild("Dino" .. compies[3]))
env.advance(0.5)
T.eq(#Lab.Selected(), 2, "clic encore : enlevé")
Lab.Select({})
env.advance(0.3)
T.eq(#Lab.Selected(), 0, "Select({}) vide")
click(find("AutoPick", lab))
env.advance(0.5)
T.eq(#Lab.Selected(), 3, "AUTO PICK 3 : trois identiques")

T.section("labo : fusion")
local before = dinoCount()
click(find("Fuse", lab))
env.advance(1)
T.eq(dinoCount(), before - 2, "3 dinos -> 1")
T.check(Reveal.IsOpen(), "révélation après la fusion")
T.eq(find("NEW DINO!Backdrop"):FindFirstChild("Title", true).Text, "LEVEL UP!", "titre : LEVEL UP!")
T.check(not Lab.IsOpen(), "labo caché sous la révélation")
click(find("Nice"))
env.advance(0.6)
T.check(Lab.IsOpen(), "labo rouvert après la révélation")
T.eq(#Lab.Selected(), 0, "choix vidé")

T.section("labo : hybride")
local headId = EnclosureService.AddDino(player, { Species = pteroRex.Head })
local bodyId = EnclosureService.AddDino(player, { Species = pteroRex.Body })
env.advance(0.5)
Lab.Select({ headId, bodyId })
env.advance(0.5)
T.check(string.find(result.Text.Text, "HYBRID", 1, true) ~= nil, "aperçu : hybride (" .. result.Text.Text .. ")")
click(find("Fuse", lab))
env.advance(1)
T.check(Reveal.IsOpen(), "révélation de l'hybride")
T.check(find("NEW DINO!Backdrop"):FindFirstChild("Title", true).Text == "HYBRID!" or find("NEW DINO!Backdrop"):FindFirstChild("Title", true).Text == "HYBRID DISCOVERED!", "titre hybride")
click(find("Nice"))
env.advance(0.6)
Lab.Select({ "nope", "nope", "nope", "nope" })
env.advance(0.3)
T.check(#Lab.Selected() <= 3, "Select hostile : au plus 3")
click(find("Fuse", lab))
env.advance(0.5)
T.check(Reveal.IsOpen() == false, "fusion impossible : pas de révélation")
Lab.Close()
env.advance(0.3)
T.check(not lab.Visible, "labo fermé")

T.section("révélation : file et fermeture toute seule")
local closed = {}
Reveal.Closed:Connect(function(kind)
	table.insert(closed, kind)
end)
Reveal.Show({ Species = "Triceratops", Rarity = "Legendary", Size = "Big", Mutation = "Lava", Level = 1, Income = 1350 }, "Tank")
Reveal.Show({ Species = "Compy", Income = 1 }, "Tank")
Reveal.Show({ Species = "Compy", Income = 1 }, "Fusion")
env.advance(0.3)
local reveal = find("NEW DINO!Backdrop")
T.check(Reveal.IsOpen(), "première révélation")
T.eq(Reveal.Pending(), 2, "deux en attente")
T.check(shown("Big Lava Golden Triceratops"), "nom complet")
T.check(find("New", reveal).Visible, "NEW! : espèce pas dans l'Index")
T.check(shown("LEGENDARY"), "rareté")
env.advance(7.5)
T.check(Reveal.IsOpen() and Reveal.Pending() == 1, "fermée toute seule, la suivante s'ouvre")
T.check(not find("New", reveal).Visible, "Compy déjà dans l'Index : pas de NEW!")
click(find("Nice"))
env.advance(0.3)
click(find("Nice"))
env.advance(0.5)
T.check(not Reveal.IsOpen() and Reveal.Pending() == 0, "file vide")
T.eq(#closed, 3, "Closed pour chaque carte")
for _ = 1, 30 do
	Reveal.Show({ Species = "Compy" }, "Tank")
end
T.check(Reveal.Pending() <= 10, "file limitée")
for _ = 1, 12 do
	click(find("Nice"))
	env.advance(0.1)
end
env.advance(1)

T.section("événements abîmés")
local remotes = env.game:GetService("ReplicatedStorage").Remotes
for _, value in T.hostileValues() do
	env.fire(env.signal(remotes.DinoRevealed, "OnClientEvent"), value, value)
	env.fire(env.signal(remotes.FusionDone, "OnClientEvent"), value)
	env.fire(env.signal(remotes.OpenFusionLab, "OnClientEvent"), value)
	Reveal.Show(value, value)
	Reveal.Show({ Species = "Compy", Size = value, Mutation = value, Level = value, Income = value, Rarity = value, Key = value }, "Tank")
	Index.Open(value)
	Lab.Select(if type(value) == "table" then value else { value })
	env.advance(0.05)
end
for _ = 1, 20 do
	click(find("Nice"))
	env.advance(0.1)
end
Lab.Close()
Index.Close()
env.advance(10)
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")

T.done("ui_menus")
