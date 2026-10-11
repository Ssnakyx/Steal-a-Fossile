-- Fusion (brief 8), serveur et client ensemble : le FusionController assemble les chimères des modèles tagués Dino
-- (déjà là au démarrage ou ajoutés ensuite) avant que DinoAnimController construise leurs briques ; labo, aperçu,
-- fusion par le client, événements hostiles.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local EnclosureService = Boot.Services.EnclosureService
local FusionService = Boot.Services.FusionService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local DinoBuilder = T.module("src/shared/DinoBuilder")
local Economy = T.module("src/shared/Config/Economy")

local player = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()
local data = T.data(player)
data.EnclosureUpgrades = #Economy.Enclosure.Prices

-- briques construites par le client : un modèle enfant avec des pièces d'os
local function built(model: any): boolean
	for _, child in model:GetChildren() do
		if child:IsA("Model") then
			for _, part in child:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("Bone") then
					return true
				end
			end
		end
	end
	return false
end

local function shown(text: string): boolean
	for _, inst in player.PlayerGui:GetDescendants() do
		if inst:IsA("TextLabel") and string.find(inst.Text, text, 1, true) then
			return true
		end
	end
	return false
end

T.section("chimère déjà dans l'enclos")
local pteroRex = FusionService.Get("Ptero-Rex")
T.check(DinoBuilder.Get(pteroRex.Key) == nil, "pas encore assemblée")
local early = EnclosureService.AddDino(player, { Species = "Ptero-Rex", Size = "Big" })
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local FusionController = ClientBoot.Controllers.FusionController
T.check(FusionController ~= nil, "FusionController chargé")
local Replica = ClientBoot.Controllers.ReplicaController
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(0.5)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")
T.check(DinoBuilder.Get(pteroRex.Key) ~= nil, "chimère assemblée côté client")
T.check(built(EnclosureService.ModelOf(player, early)), "briques de la chimère construites et animées")
T.eq(Replica.Get("Hybrids").Total, #FusionService.Hybrids(), "Index des hybrides reçu")

T.section("chimère ajoutée ensuite")
local quetza = FusionService.Get("Quetza-Carno")
local later = EnclosureService.AddDino(player, { Species = "Quetza-Carno" }, "Roar")
env.advance(0.5)
T.check(DinoBuilder.Get(quetza.Key) ~= nil, "chimère assemblée à l'arrivée du modèle")
T.check(built(EnclosureService.ModelOf(player, later)), "briques construites")
T.check(FusionController.Ensure(quetza.Key) == DinoBuilder.Get(quetza.Key), "Ensure : données déjà prêtes")
T.check(FusionController.Ensure("T-Rex") == nil and FusionController.Ensure(5) == nil, "Ensure : pas une clé de chimère")

T.section("labo")
local opened = 0
FusionController.LabOpened:Connect(function()
	opened += 1
end)
local prompt = PlotService.Get(player).Lab:FindFirstChild("LabPrompt")
env.fire(env.signal(prompt, "Triggered"), player)
env.advance(0.2)
T.eq(opened, 1, "LabOpened au déclenchement du labo")
T.check(not shown("Fusion Lab: 2 different dinos make a hybrid"), "pas d'aide provisoire : le menu du brief 12 est là")
local labMenu = player.PlayerGui:FindFirstChild("Fusion LabBackdrop", true)
T.check(labMenu ~= nil and labMenu.Visible, "menu du labo ouvert (brief 12)")

T.section("fusion par le client")
local raptor = EnclosureService.AddDino(player, { Species = "Velociraptor" }) :: string
local shark = EnclosureService.AddDino(player, { Species = "Megalodon" }) :: string
local ok, info = FusionController.Preview({ raptor, shark })
T.check(ok and info.Known == false and info.Species == "???", "aperçu : « ??? » avant la découverte")
MoneyService.Add(player, 1e9, "Test")
local received = nil
FusionController.Done:Connect(function(value)
	received = value
end)
local text
ok, text, info = FusionController.Fuse({ raptor, shark })
env.advance(0.5)
T.check(ok, "fusion : " .. tostring(text))
T.eq(text, "New hybrid discovered: Shark-Raptor!", "fusion : texte")
local key = FusionService.Get("Shark-Raptor").Key
T.check(received ~= nil and received.Key == key and received.New == true, "Done reçu avec la clé")
T.check(DinoBuilder.Get(key) ~= nil, "chimère assemblée")
T.check(built(EnclosureService.ModelOf(player, info.Id)), "chimère construite dans l'enclos")
T.eq(Replica.Get("Hybrids").Found, 1, "Index : 1 hybride trouvé")
ok, text = FusionController.Fuse({ raptor, shark })
T.check(not ok, "mêmes dinos : refusé")

T.section("événements hostiles")
local remotes = env.game:GetService("ReplicatedStorage").Remotes
local count = 0
FusionController.Done:Connect(function()
	count += 1
end)
for _, value in T.hostileValues() do
	env.fire(env.signal(remotes.FusionDone, "OnClientEvent"), value)
	env.fire(env.signal(remotes.FusionDone, "OnClientEvent"), { Key = value })
	env.fire(env.signal(remotes.OpenFusionLab, "OnClientEvent"), value)
end
env.fire(env.signal(remotes.FusionDone, "OnClientEvent"), { Key = "Nope+Missing" })
env.advance(0.2)
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.check(count > 0, "Done relaie les tables (le menu vérifie les champs)")
T.done("fusion_client")
