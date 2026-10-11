-- Menu d'admin (AdminController) et alerte des blocs rares (DigSiteService, AlertController) : commandes en plus
-- (spawnrare, goto, bring, resetdata), seuil de l'alerte, regroupement par zone, bouton caché aux joueurs normaux,
-- boutons du menu qui passent par le serveur, bandeau d'alerte, événements abîmés.
local T = require("./testkit")
local env = T.env

env.quiet = true
env.studio = false -- (en Studio tout le monde est admin : ici on vérifie le vrai droit)
local Enum = env.Enum
local game = env.game
env.setProperty(game, "CreatorType", Enum.CreatorType.User)
env.setProperty(game, "CreatorId", 555)
local Config = T.config()
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local AdminService = Boot.Services.AdminService
local DigSiteService = Boot.Services.DigSiteService
local MoneyService = Boot.Services.MoneyService
local EnclosureService = Boot.Services.EnclosureService

local snaky = env.addPlayer({ Local = true, Name = "Snaky", UserId = 3346721423, Character = true })
local bob = env.addPlayer({ Name = "Bob", Character = true })
env.waitUntil(function()
	return snaky:GetAttribute("Ready") == true and bob:GetAttribute("Ready") == true
end, "joueurs prêts", 60)
T.data(snaky).Tutorial = 3
T.data(bob).Tutorial = 3
Boot.Services.DailyService.Claim(snaky) -- (pas de calendrier ouvert tout seul par-dessus le menu)
env.flush()

T.section("droits")
T.eq(snaky:GetAttribute("Admin"), true, "Snaky est admin (Config.Core.Admins)")
T.eq(bob:GetAttribute("Admin"), false, "Bob n'est pas admin")
for _, name in { "spawnrare", "goto", "bring", "resetdata" } do
	local ok, text = env.invokeServer(bob, "Admin", name, { "me" })
	T.check(not ok and text == "Not allowed", name .. " refusé à un joueur normal")
end

T.section("seuil de l'alerte")
T.eq(Config.Zones.Dig.AlertRarity, "Mythic", "seuil dans Config.Zones.Dig")
T.check(not DigSiteService.IsAlertRarity("Legendary"), "Legendary : pas d'alerte")
T.check(DigSiteService.IsAlertRarity("Mythic"), "Mythic : alerte")
T.check(DigSiteService.IsAlertRarity("Secret"), "Secret : alerte")
T.check(not DigSiteService.IsAlertRarity("Nope"), "rareté inconnue : pas d'alerte")

local function alerts(player): { any }
	return env.received(player, "FossilAlert")
end

T.section("spawnrare")
local before = #alerts(bob)
local ok, text = AdminService.Run(snaky, "spawnrare", { "mythic", "2" })
T.check(ok, "spawnrare mythic 2 (" .. tostring(text) .. ")")
local found = false
for _, site in DigSiteService.Sites() do
	if site.Zone == "Fern Forest" then
		for _, slot in site.Slots do
			if slot.State == "Present" and slot.Block.Rarity == "Mythic" then
				found = true
			end
		end
	end
end
T.check(found, "bloc Mythic posé dans la Fern Forest")
local list = alerts(bob)
T.eq(#list, before + 1, "alerte envoyée à tout le serveur")
T.check(list[#list][1] == "Mythic" and list[#list][2] == "Fern Forest" and list[#list][3] == 1, "rareté, zone, nombre")
local announces = env.received(bob, "LoopAnnounce")
T.eq(announces[#announces][1], "A MYTHIC fossil appeared in the Fern Forest!", "message du chat")
before = #alerts(bob)
ok = AdminService.Run(snaky, "spawnrare", { "rare", "1" })
T.check(ok, "spawnrare rare (remplace un bloc moins rare de la Beach)")
T.eq(#alerts(bob), before, "un bloc Rare n'alerte personne")
ok, text = AdminService.Run(snaky, "spawnrare", { "common", "2" })
T.check(not ok, "gisements pleins de blocs au moins Common : rien à remplacer (" .. tostring(text) .. ")")
for _, bad in { { "gold", "1" }, { "mythic", "9" }, { "mythic", "0" }, { "mythic", "x" }, {} } do
	ok = AdminService.Run(snaky, "spawnrare", bad)
	T.check(not ok, "spawnrare " .. table.concat(bad, " ") .. " refusé")
end
-- zone pleine de blocs Secret : rien de moins rare à remplacer
local spawned = 0
repeat
	ok, text = AdminService.Run(snaky, "spawnrare", { "secret", "1" })
	spawned += 1
until not ok or spawned > 50
local secrets, places = 0, 0
for _, site in DigSiteService.Sites() do
	if site.Zone == "Beach" then
		for _, slot in site.Slots do
			places += 1
			if slot.State == "Present" and slot.Block.Rarity == "Secret" then
				secrets += 1
			end
		end
	end
end
T.eq(secrets, places, "toute la Beach en Secret")
T.check(not ok and string.find(text, "Beach", 1, true) ~= nil, "plus de place à la Beach : refusé")

T.section("remplissage : une alerte par zone")
for _, site in DigSiteService.Sites() do
	for _, slot in site.Slots do
		if slot.State == "Present" and not slot.Block.Tutorial then
			slot.Part:Destroy()
			slot.State = "Empty"
			slot.Block = nil
			slot.Part = nil
		end
	end
end
local roll = DigSiteService.RollRarity
DigSiteService.RollRarity = function(zone: string)
	if zone == "Volcano" then
		return "Mythic"
	elseif zone == "Swamp" then
		return "Secret"
	end
	return "Common"
end
before = #alerts(bob)
DigSiteService.Refill()
DigSiteService.RollRarity = roll
list = alerts(bob)
T.eq(#list, before + 2, "deux zones, deux alertes")
T.eq(list[before + 1][1], "Secret", "la plus rare d'abord")
T.eq(list[before + 1][2], "Swamp", "zone du Secret")
T.eq(list[before + 2][2], "Volcano", "puis le Volcano")
T.check(list[before + 2][3] > 1, "nombre de blocs Mythic du Volcano")
announces = env.received(bob, "LoopAnnounce")
T.check(string.find(announces[#announces][1], "MYTHIC fossils appeared in the Volcano!", 1, true) ~= nil, "pluriel dans le chat")

T.section("goto et bring")
local snakyRoot = snaky.Character.HumanoidRootPart
local bobRoot = bob.Character.HumanoidRootPart
bob.Character:PivotTo(env.CFrame.new(500, 10, 500))
ok = AdminService.Run(snaky, "goto", { "bob" })
T.check(ok, "goto bob")
T.check((snakyRoot.Position - bobRoot.Position).Magnitude < 10, "Snaky à côté de Bob")
snaky.Character:PivotTo(env.CFrame.new(-300, 10, 40))
ok = AdminService.Run(snaky, "bring", { "bob" })
T.check(ok, "bring bob")
T.check((snakyRoot.Position - bobRoot.Position).Magnitude < 10, "Bob à côté de Snaky")
T.check(not (AdminService.Run(snaky, "goto", { "me" })), "goto soi-même refusé")
T.check(not (AdminService.Run(snaky, "bring", { "nobody" })), "bring joueur inconnu refusé")

T.section("client : bouton et menu")
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
local Admin, Alert = C.AdminController, C.AlertController
env.waitUntil(function()
	return C.ReplicaController.IsReady()
end, "état reçu", 30)
env.advance(0.5)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")
local gui = snaky.PlayerGui
local openButton = gui:FindFirstChild("AdminButton"):FindFirstChild("Admin", true)
T.check(openButton ~= nil and openButton:IsA("TextButton"), "bouton Admin")
T.eq(openButton.Visible, true, "visible pour un admin")
local function click(button: any)
	env.fire(env.signal(button, "Activated"))
	env.advance(0.3)
end
click(openButton)
T.check(Admin.IsOpen(), "le bouton ouvre le menu")
local menu = gui:FindFirstChild("Menus"):FindFirstChild("AdminBackdrop", true)
T.check(menu ~= nil and menu.Visible, "panneau Admin affiché")
-- page du menu (pas l'onglet du même nom, qui est un bouton)
local function pageOf(pageName: string): any
	for _, inst in menu:GetDescendants() do
		if inst.Name == pageName and not inst:IsA("TextButton") then
			return inst
		end
	end
	error("page introuvable : " .. pageName)
end
local function button(pageName: string, text: string): any
	local pageFrame = pageOf(pageName)
	for _, inst in pageFrame:GetDescendants() do
		if inst:IsA("TextButton") and inst.Text == text then
			return inst
		end
	end
	error("bouton introuvable : " .. pageName .. " / " .. text)
end

local money = MoneyService.Get(snaky)
click(button("Player", "+$1M"))
env.advance(0.5)
T.eq(MoneyService.Get(snaky), money + 1e6, "+$1M donné par le serveur")
local output = menu:FindFirstChild("Output", true)
T.check(string.find(output.Text, "Snaky now has", 1, true) ~= nil, "réponse du serveur en bas du menu")

T.section("client : cible")
local targetButton = menu:FindFirstChild("Target", true)
T.eq(Admin.Target(), "me", "cible : soi-même")
click(targetButton)
T.eq(Admin.Target(), "Bob", "cible suivante : Bob")
T.eq(targetButton.Text, "Target: Bob", "texte du bouton de cible")
local bobMoney = MoneyService.Get(bob)
click(button("Player", "+$1K"))
env.advance(0.5)
T.eq(MoneyService.Get(bob), bobMoney + 1000, "argent donné à la cible")
click(targetButton)
T.eq(Admin.Target(), "me", "retour à soi-même")

T.section("client : dino avec mutation")
Admin.Open("Dinos")
env.advance(0.3)
local dinos = pageOf("Dinos")
T.check(dinos.Visible, "page Dinos")
click(button("Dinos", "Compy"))
local mutation = button("Dinos", "Mut: none")
click(mutation)
T.eq(mutation.Text, "Mut: " .. Config.Economy.Mutations[1].Name, "mutation suivante")
local count = 0
for _ in T.data(snaky).Dinos do
	count += 1
end
click(button("Dinos", "GIVE DINO"))
env.advance(0.5)
local after, given = 0, nil
for _, dino in T.data(snaky).Dinos do
	after += 1
	if dino.Species == "Compy" then
		given = dino
	end
end
T.eq(after, count + 1, "un dino de plus dans le parc")
T.check(given ~= nil and given.Mutation == Config.Economy.Mutations[1].Name, "Compy avec la mutation choisie")

T.section("client : monde et console")
Admin.Open("World")
env.advance(0.3)
before = #alerts(snaky)
click(button("World", "SPAWN!"))
env.advance(0.5)
T.eq(#alerts(snaky), before + 1, "SPAWN! : bloc rare et alerte")
Admin.Open("Console")
env.advance(0.3)
local input = menu:FindFirstChild("Input", true)
input.Text = "money 5 me"
local money2 = MoneyService.Get(snaky)
click(button("Console", "RUN"))
env.advance(0.5)
T.eq(MoneyService.Get(snaky), money2 + 5, "commande tapée dans la console")
T.eq(input.Text, "", "champ vidé")
local log = menu:FindFirstChild("Log", true)
T.check(#log:GetChildren() > 1, "journal de la console")

T.section("client : bandeau d'alerte")
local toasts = gui:FindFirstChild("Toasts")
local function alertCards(): number
	local n = 0
	for _, inst in toasts:GetDescendants() do
		if inst.Name == "Alert" then
			n += 1
		end
	end
	return n
end
local shownBefore = alertCards()
local card = Alert.Show("Secret", "Meteor Crater", 2)
T.check(card ~= nil, "alerte montrée")
T.eq(alertCards(), shownBefore + 1, "carte dans la liste des messages")
T.eq((card :: any):FindFirstChild("Title", true).Text, "2 SECRET FOSSILS!", "titre au pluriel")
T.check(Alert.Show("Gold", "Beach") == nil, "rareté inconnue ignorée")
T.check(Alert.Show("Rare", "Moon") == nil, "zone inconnue ignorée")
env.advance(Config.Zones.Dig.AlertTime + 1)
T.eq(alertCards(), 0, "l'alerte s'en va toute seule")
local remote = env.instance("ReplicatedStorage.Remotes.FossilAlert")
for _, value in T.hostileValues() do
	env.fire(env.signal(remote, "OnClientEvent"), value, value, value)
end
env.fire(env.signal(remote, "OnClientEvent"), "Mythic", "Volcano", 0 / 0)
env.advance(0.5)
T.eq(alertCards(), 1, "événements abîmés ignorés, NaN compté comme 1")
T.eq(#ClientBoot.Errors, 0, "aucune erreur du client")

T.section("client : joueur normal")
snaky:SetAttribute("Admin", false)
env.advance(0.1)
T.eq(openButton.Visible, false, "bouton caché sans le droit")
T.check(not Admin.IsOpen(), "menu fermé sans le droit")
Admin.Open()
env.advance(0.3)
T.check(not Admin.IsOpen(), "Open refusé sans le droit")
snaky:SetAttribute("Admin", true)

T.section("resetdata")
ok = AdminService.Run(snaky, "resetdata", { "bob" })
T.check(not ok, "resetdata sans confirm refusé")
T.data(bob).Money = 12345
EnclosureService.AddDino(bob, { Species = "Compy" })
ok, text = AdminService.Run(snaky, "resetdata", { "bob", "confirm" })
T.check(ok, "resetdata bob confirm (" .. tostring(text) .. ")")
env.advance(1)
local kicked = false
for _, kick in env.kicks do
	if kick.Player == bob then
		kicked = true
	end
end
T.check(kicked, "Bob expulsé")
env.advance(2)
local saved = env.saved(Config.Core.Data.StoreName, "Player_" .. bob.UserId)
T.check(type(saved) == "table", "sauvegarde écrite")
T.eq(saved.Money, Config.Core.StartingMoney, "argent remis à zéro")
local dinoCount = 0
for _ in saved.Dinos do
	dinoCount += 1
end
T.eq(dinoCount, 0, "parc vide")
ok = AdminService.Run(snaky, "resetdata", { "bob", "confirm" })
T.check(not ok, "joueur parti : refusé")

T.clean("admin menu")
T.done("admin_menu")
