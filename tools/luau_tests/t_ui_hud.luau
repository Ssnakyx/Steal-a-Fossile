-- Interface du brief 12 (HUD et shop), serveur et client ensemble : boutons Shop / Index et leurs pastilles, colonne de
-- gauche sans chevauchement, compteurs (argent, revenu, vitesse comparée à la zone), bandeau de zone, carte du transport
-- (flèche, distance, gardien), messages courts sous la carte du haut, cuves (temps, OPEN, nouvelle cuve), shop (onglets,
-- achats par les boutons, objets Robux à Id = 0 cachés hors Studio, trails en argent), événements abîmés.
local T = require("./testkit")
local env = T.env

env.studio = false -- (hors Studio : les objets Robux à Id = 0 restent cachés)
env.quiet = true
local Config = T.config()
local Shop = Config.Shop
-- (« créés dans le Creator Hub » pour ce test ; les autres restent à Id = 0)
Shop.Passes.DoubleMoney.Id = 501
Shop.Passes.NeonTrail.Id = 502
Shop.Products.InstantRevive.Id = 601
Shop.Treadmill.Levels[1].Id = 701
env.productPrices[501] = 299
env.productPrices[502] = 99
env.productPrices[601] = 29
env.productPrices[701] = 25
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local DigSiteService = Boot.Services.DigSiteService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local ReplicaService = Boot.Services.ReplicaService
local ReviveService = Boot.Services.ReviveService
local SpeedService = Boot.Services.SpeedService
local Format = T.module("src/shared/Format")
local Zones = Config.Zones
local Vector3, CFrame = env.Vector3, env.CFrame

local player = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
local data = T.data(player)
data.Tutorial = 3
ReplicaService.Set(player, "Tutorial", 3)
Boot.Services.DailyService.Claim(player) -- (pas de calendrier ouvert tout seul)
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

-- haut et bas (unités de l'écran de 720 de haut) d'un cadre posé dans un fond plein écran
local function span(gui: any): (number, number)
	local height = 720
	local h = gui.Size.Y.Offset + gui.Size.Y.Scale * height
	local top = gui.Position.Y.Scale * height + gui.Position.Y.Offset - gui.AnchorPoint.Y * h
	return top, top + h
end

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
local UIKit = env.module("src/client/UI/UIKit")
local Hud, ShopUi, Replica = C.HudController, C.ShopController, C.ReplicaController
T.check(Hud ~= nil and ShopUi ~= nil and C.IndexController ~= nil and C.LabController ~= nil, "contrôleurs du brief 12 chargés")
T.check(C.RevealController ~= nil and C.DinoLabelController ~= nil, "révélation et étiquettes chargées")
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(1)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")
T.check(not find("Daily RewardsBackdrop").Visible, "pas de calendrier (déjà pris)")

T.section("colonne de gauche")
local buttons = find("HudButtons")
T.check(buttons ~= nil and buttons.Visible, "boutons du HUD")
T.check(buttons.Shop ~= nil and buttons.Index ~= nil, "boutons Shop et Index")
local rewards = find("RewardButtons")
local counters = find("Counters")
local _, buttonsBottom = span(buttons)
local rewardsTop, rewardsBottom = span(rewards)
local countersTop = span(counters)
local buttonsTop = span(buttons)
T.check(buttonsTop >= 70, "Shop sous la barre de Roblox (" .. buttonsTop .. ")")
T.check(buttonsBottom <= rewardsTop, "Shop / Index au-dessus de Daily / Spin / Gifts")
T.check(rewardsBottom <= countersTop, "Daily / Spin / Gifts au-dessus des compteurs")
T.check(span(counters) + counters.Size.Y.Offset <= 720 - 8, "compteurs dans l'écran")
local tutorialCard = find("TutorialCard")
T.check(16 + counters.Size.X.Offset + 16 <= 640 - tutorialCard.Size.X.Offset / 2, "compteurs à gauche de la carte du guide")

T.section("compteurs")
MoneyService.Add(player, 12_345, "Test")
env.advance(1)
local money = Replica.Get("Money")
T.eq(find("Money", counters).Text, Format.Money(money), "argent affiché : " .. Format.Money(money))
T.check(#find("Pops", counters):GetChildren() >= 1, "gain qui s'envole")
T.check(string.find(find("Income", counters).Text, "/s", 1, true) ~= nil, "revenu par seconde")
SpeedService.Add(player, 1_500, "Test")
env.advance(1)
local speedLabel = find("Speed", counters)
local zoneLine = find("ZoneLine", counters)
T.eq(speedLabel.Text, Format.Number(Replica.Get("Speed")) .. " Speed", "vitesse affichée")
local swamp = Zones.ByName.Swamp
T.check(string.find(zoneLine.Text, "Swamp", 1, true) ~= nil, "zone suivante : " .. zoneLine.Text)

T.section("bandeau de zone")
player:SetAttribute("Zone", "Swamp")
env.advance(0.4)
local banner = find("ZoneBanner")
T.check(banner.Visible, "bandeau à l'entrée d'une zone")
T.eq(banner.Title.Text, "SWAMP", "nom de la zone")
T.check(string.find(banner.Text.Text, Format.Number(swamp.Speed), 1, true) ~= nil, "vitesse conseillée : " .. banner.Text.Text)
T.check(string.find(banner.Text.Text, "Too slow", 1, true) ~= nil, "trop lent : prévenu")
T.near(speedLabel.TextColor3.R, UIKit.Colors.Tomato.R, 0.01, "vitesse en rouge : trop lent pour la zone")
T.check(string.find(zoneLine.Text, "advised", 1, true) ~= nil, "compteur : vitesse conseillée de la zone")
local toastList = nil
C.NotifyController.Show("Hello", "info")
env.advance(0.1)
for _, inst in player.PlayerGui:GetDescendants() do
	if inst:IsA("Frame") and inst.Name == "Toasts" then
		toastList = inst
	end
end
T.check(toastList ~= nil, "liste des messages courts")
local _, bannerBottom = span(banner)
T.check(toastList.Position.Y.Offset >= bannerBottom, "messages courts sous le bandeau")
env.advance(4)
T.check(not banner.Visible, "bandeau parti tout seul")
T.eq(toastList.Position.Y.Offset, 70, "messages courts à leur place")
player:SetAttribute("Zone", "")
env.advance(0.3)

T.section("flèche du transport")
local north = CFrame.new(Vector3.new(0, 0, 0))
T.near(Hud.Heading(Vector3.new(0, 0, 0), Vector3.new(0, 0, -10), north), 0, 0.01, "devant : 0°")
T.near(Hud.Heading(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), north), 90, 0.01, "à droite : 90°")
T.near(math.abs(Hud.Heading(Vector3.new(0, 0, 0), Vector3.new(0, 0, 10), north)), 180, 0.01, "derrière : 180°")
T.near(Hud.Heading(Vector3.new(0, 0, 0), Vector3.new(-10, 0, 0), north), -90, 0.01, "à gauche : -90°")
local turned = CFrame.Angles(0, math.rad(90), 0) -- (caméra tournée vers -X)
T.near(Hud.Heading(Vector3.new(0, 0, 0), Vector3.new(-10, 0, 0), turned), 0, 0.01, "caméra tournée : devant")
T.eq(Hud.Heading(Vector3.new(1, 2, 3), Vector3.new(1, 9, 3), north), 0, "juste au-dessus : 0°")

T.section("carte du transport")
local target = nil
for _, site in DigSiteService.Sites() do
	for _, slot in site.Slots do
		if site.Zone == Zones.Dig.TutorialZone and slot.State == "Present" and not target then
			target = slot
		end
	end
end
local part = target.Part
player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(3, 1, 3)))
env.advance(0.3)
env.fire(env.signal(part.GrabPrompt, "PromptButtonHoldBegan"), player)
env.advance(Zones.Dig.GrabTime)
env.fire(env.signal(part.GrabPrompt, "Triggered"), player)
env.advance(0.5)
local carry = find("CarryCard")
T.check(Replica.Get("Carrying") ~= nil, "bloc sur le dos")
T.check(carry.Visible, "carte du transport")
T.check(string.find(find("Home", carry).Text, "HOME", 1, true) ~= nil and string.find(find("Home", carry).Text, "studs", 1, true) ~= nil, "distance du parc : " .. find("Home", carry).Text)
T.check(find("Arrow", carry).Visible, "flèche vers le parc")
local beam = env.game:GetService("Workspace"):FindFirstChild("HomeBeam", true)
T.check(beam ~= nil and beam.Enabled, "rayon vers le parc")
T.check(not find("Chase", carry).Visible, "pas de gardien")
local _, carryBottom = span(carry)
T.check(toastList.Position.Y.Offset >= carryBottom, "messages courts sous la carte du transport")
player:SetAttribute("Zone", "Swamp")
env.advance(0.3)
T.check(not banner.Visible, "pas de bandeau pendant le transport")
player:SetAttribute("ChasedBy", "Beach")
env.advance(0.3)
T.check(find("Chase", carry).Visible, "alerte gardien")
T.check(string.find(find("Chase", carry).Text, "GUARDIAN", 1, true) ~= nil, "texte : " .. find("Chase", carry).Text)
T.eq(carry.Size.Y.Offset, 92, "carte plus haute pendant la poursuite")
local _, chasedBottom = span(carry)
T.check(toastList.Position.Y.Offset >= chasedBottom, "messages courts sous la carte agrandie")
player:SetAttribute("ChasedBy", "")
player:SetAttribute("Zone", "")
-- (posé au parc : la carte disparaît)
local plot = PlotService.Get(player)
Boot.Services.CarryService.Drop(player)
env.advance(0.5)
T.check(Replica.Get("Carrying") == nil, "bloc lâché")
T.check(not carry.Visible, "carte cachée")
T.check(not beam.Enabled, "rayon éteint")
T.check(plot ~= nil, "parc")

T.section("cuves")
local tanksCard = find("TanksCard")
ReviveService.AddBlock(player, { Rarity = "Rare", Zone = "Fern Forest" })
env.advance(1.2)
T.check(tanksCard.Visible, "carte des cuves")
local row1 = find("Tank1", tanksCard)
T.check(row1.Visible and not row1.Open.Visible, "cuve en cours : pas de OPEN")
T.check(string.find(row1.Time.Text, ":", 1, true) ~= nil, "temps restant : " .. row1.Time.Text)
T.eq(row1:FindFirstChild("Name").Text, "RARE", "rareté")
data.Tanks["1"].EndsAt = os.time() - 1
ReviveService.FinishAll(player)
env.advance(1.2)
T.check(row1.Open.Visible, "cuve prête : OPEN")
local before = 0
for _ in data.Dinos do
	before += 1
end
click(row1.Open)
env.advance(0.5)
local after = 0
for _ in data.Dinos do
	after += 1
end
T.eq(after, before + 1, "OPEN : dino sorti de la cuve")
T.check(C.RevealController.IsOpen(), "écran de révélation")
T.check(find("NEW DINO!Backdrop").Visible, "carte NEW DINO!")
T.check(not find("Widgets").Visible, "HUD caché sous le menu")
click(find("Nice"))
env.advance(0.5)
T.check(not C.RevealController.IsOpen(), "NICE! ferme la carte")
T.check(find("Widgets").Visible, "HUD revenu")
local buy = find("BuyTank", tanksCard)
T.check(buy.Visible and string.find(buy.Text, "NEW TANK", 1, true) ~= nil, "bouton nouvelle cuve : " .. buy.Text)
local count = Replica.Get("TankCount")
MoneyService.Add(player, 10_000_000, "Test")
env.advance(0.5)
click(buy)
env.advance(0.5)
T.eq(Replica.Get("TankCount"), count + 1, "NEW TANK : une cuve de plus")

T.section("pastilles")
env.advance(1.2)
T.eq(buttons.Shop.Badge.Count.Text, "!", "Shop : une trail payable")
T.check(buttons.Shop.Badge.Visible, "pastille Shop affichée")

T.section("shop : onglet Speed")
click(buttons.Shop)
env.advance(1)
local backdrop = find("ShopBackdrop")
T.check(backdrop.Visible and ShopUi.IsOpen(), "Shop ouvert par le bouton")
T.check(not find("Widgets").Visible, "HUD caché derrière le shop")
local treadmill = find("Treadmill", backdrop)
T.check(treadmill ~= nil, "ligne du treadmill")
T.eq(treadmill.Button1.Text, "R$ 25", "prix Roblox du niveau 1")
T.check(string.find(treadmill.Subtitle.Text, "Level 1", 1, true) ~= nil, "niveau suivant : " .. treadmill.Subtitle.Text)
T.check(string.find(treadmill.Subtitle.Text, "even AFK", 1, true) ~= nil, "gain actuel, même AFK")
T.check(find("DoubleTreadmill", backdrop) == nil, "x2 Treadmill à Id = 0 : caché")
env.prompts = {}
click(treadmill.Button1)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Kind == "Product" and env.prompts[1].Id == 701, "achat du niveau 1 proposé par Roblox")
click(find("TrailsHint", backdrop).Button1)
env.advance(0.3)

T.section("shop : onglet Trails")
local neon = find("Neon", backdrop)
T.check(neon ~= nil, "Neon Trail en vente")
T.eq(neon.Button1.Text, "R$ 99", "prix Roblox")
T.eq(neon.Swatch.Glyph.Text, "x1.5", "x1.5 (pas arrondi)")
T.check(find("Galaxy", backdrop) == nil and find("Golden", backdrop) == nil, "trails Robux à Id = 0 : cachées")
local dust = find("Dust", backdrop)
T.eq(dust.Button1.Text, Format.Money(Config.Speed.Trails.Dust.Price), "trail en argent : prix")
click(dust.Button1)
env.advance(0.6)
T.check(data.Trails.Owned.Dust == true, "Dust achetée par le bouton")
T.check(dust.Button1.Text == "EQUIPPED" or dust.Button1.Text == "EQUIP", "bouton : " .. dust.Button1.Text)
local rainbow = find("Rainbow", backdrop)
T.eq(rainbow.Button1:GetAttribute("Disabled"), true, "trop chère : grisée")
local moneyBefore = data.Money
click(rainbow.Button1)
env.advance(0.6)
T.check(not data.Trails.Owned.Rainbow, "pas achetée sans l'argent")
T.check(data.Money >= moneyBefore, "argent pas dépensé")
T.check(shown("Not enough"), "message : pas assez d'argent")
env.prompts = {}
click(neon.Button1)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Kind == "GamePass" and env.prompts[1].Id == 502, "Neon : passe proposé par Roblox")

T.section("shop : onglet Passes")
ShopUi.Select("Passes")
env.advance(0.3)
local doubleMoney = find("DoubleMoney", backdrop)
T.check(doubleMoney ~= nil, "x2 Money en vente")
T.eq(doubleMoney.Button1.Text, "R$ 299", "prix Roblox")
for _, key in { "VIP", "FastRevive", "DoubleTreadmill", "NeonTrail" } do
	T.check(find(key, backdrop) == nil, key .. " pas dans Passes")
end
env.prompts = {}
click(doubleMoney.Button1)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Id == 501, "x2 Money proposé")

T.section("shop : onglet Items")
ShopUi.Select("Items")
env.advance(0.3)
local traps = find("BearTraps", backdrop)
T.check(traps ~= nil, "pièges en argent")
local trapsBefore = data.BearTraps
click(traps.Button1)
env.advance(0.6)
T.eq(data.BearTraps, trapsBefore + 1, "x1 : un piège acheté")
T.check(shown("Bought 1 bear trap"), "message de l'achat")
T.check(string.find(traps.Subtitle.Text, "You have " .. data.BearTraps, 1, true) ~= nil, "réserve affichée : " .. traps.Subtitle.Text)
T.check(find("BearTraps5", backdrop) == nil, "Bear Traps x5 à Id = 0 : caché")
T.check(find("ServerLuck", backdrop) == nil, "Server Luck à Id = 0 : caché")
T.check(find("Spins3", backdrop) == nil, "spins pas en vente : cachés")
local revive = find("InstantRevive", backdrop)
T.check(revive ~= nil, "Instant Revive en vente")
env.prompts = {}
click(revive.Button1)
env.advance(0.5)
T.check(#env.prompts == 1 and env.prompts[1].Id == 601, "Instant Revive proposé")

T.section("shop : fermeture")
ShopUi.Select("Nope")
ShopUi.Open("Garbage")
env.advance(0.3)
T.check(ShopUi.IsOpen(), "onglet inconnu : sans erreur")
ShopUi.Close()
env.advance(0.3)
T.check(not backdrop.Visible, "Shop fermé")
T.check(find("Widgets").Visible, "HUD revenu")
ShopUi.Toggle("Items")
env.advance(0.3)
T.check(ShopUi.IsOpen(), "Toggle ouvre")
ShopUi.Toggle()
env.advance(0.3)
T.check(not ShopUi.IsOpen(), "Toggle ferme")
Hud.SetVisible(false)
T.check(not buttons.Visible and not find("Widgets").Visible, "SetVisible(false) cache le HUD")
Hud.SetVisible(true)
T.check(buttons.Visible, "SetVisible(true)")

T.section("réseau coupé")
-- (InvokeServer qui plante côté client : le bouton doit remarcher ensuite)
local down = true
env.stubMethod("RemoteFunction", "InvokeServer", function(self: any, ...: any): ...any
	if down then
		error("network down")
	end
	return env.invokeServer(player, self.Name, ...)
end)
local tanksNow = Replica.Get("TankCount")
click(buy)
env.advance(0.5)
T.check(shown("Try again"), "nouvelle cuve sans réseau : message")
T.eq(Replica.Get("TankCount"), tanksNow, "pas de cuve en plus")
ShopUi.Open("Items")
env.advance(0.5)
local trapsNow = data.BearTraps
click(find("BearTraps", backdrop).Button1)
env.advance(0.5)
T.eq(data.BearTraps, trapsNow, "piège sans réseau : rien")
down = false
env.advance(4)
click(find("BearTraps", backdrop).Button1)
env.advance(0.6)
T.eq(data.BearTraps, trapsNow + 1, "réseau revenu : le bouton du shop remarche")
ShopUi.Close()
env.advance(0.3)
click(buy)
env.advance(0.6)
T.eq(Replica.Get("TankCount"), tanksNow + 1, "réseau revenu : NEW TANK remarche")

T.section("événements abîmés")
local remotes = env.game:GetService("ReplicatedStorage").Remotes
for _, value in T.hostileValues() do
	if type(value) ~= "function" and typeof(value) ~= "Instance" then
		for _, key in { "Money", "Speed", "Tanks", "Carrying", "Stored", "Index", "Trails" } do
			ReplicaService.Set(player, key, value)
		end
	end
	player:SetAttribute("Zone", if type(value) == "string" then value else nil)
	player:SetAttribute("ChasedBy", if type(value) == "string" then value else nil)
	env.fire(env.signal(remotes.DinoRevealed, "OnClientEvent"), value, value)
	env.advance(0.1)
end
ReplicaService.Set(player, "Money", data.Money)
ReplicaService.Set(player, "Speed", data.Speed)
ReplicaService.Set(player, "Carrying", nil)
ReplicaService.Set(player, "Tanks", {})
ReplicaService.Set(player, "Stored", {})
ReplicaService.Set(player, "Trails", { Owned = {}, Equipped = "" })
Boot.Services.IndexService.Publish(player)
player:SetAttribute("Zone", "")
player:SetAttribute("ChasedBy", "")
env.advance(10)
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")

T.done("ui_hud")
