-- Les 5 premières minutes d'un nouveau joueur, serveur et client ensemble : guide pas à pas (TutorialController : carte,
-- rayon et étiquette vers le bloc, le parc, la cuve, le treadmill), première cuve rapide, tour de roue gratuit pendant
-- l'attente, calendrier ouvert juste après le premier dino (pas avant), premier cadeau de temps de jeu à 2 min.
-- Mesure aussi le temps jusqu'au premier dino pour un joueur qui marche (vitesse 0).
local T = require("./testkit")
local env = T.env

env.quiet = true
local Config = T.config()
local Daily = Config.Daily
local Zones = Config.Zones
local SpeedConfig = Config.Speed
local Rarity = T.module("src/shared/Config/Rarity")
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local AdminService = Boot.Services.AdminService
local DigSiteService = Boot.Services.DigSiteService
local EnclosureService = Boot.Services.EnclosureService
local GiftService = Boot.Services.GiftService
local PlotService = Boot.Services.PlotService
local TreadmillService = Boot.Services.TreadmillService
local ZoneService = Boot.Services.ZoneService
local RateLimit = T.lib("RateLimit")
local Vector3, CFrame = env.Vector3, env.CFrame

local player = env.addPlayer({ Local = true, Name = "Newbie", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()
local joinedAt = env.now()

local function find(name: string): any
	return player.PlayerGui:FindFirstChild(name, true)
end

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local Tutorial = ClientBoot.Controllers.TutorialController
local Rewards = ClientBoot.Controllers.RewardsController
local Replica = ClientBoot.Controllers.ReplicaController
T.check(Tutorial ~= nil, "TutorialController chargé")
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(0.5)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")
local plot = PlotService.Get(player)
local card = find("TutorialCard")
local guide = env.game:GetService("Workspace"):FindFirstChild("TutorialTarget")

local function step(): any
	return Tutorial.Step()
end

T.section("1. arracher un fossile")
T.check(Tutorial.IsActive(), "guide actif pour un nouveau joueur")
local s = step()
T.check(s and s.Key == "Grab" and s.Number == 1, "étape 1 : Grab")
T.check(card and card.Visible and card.Title.Text == "GRAB A FOSSIL", "carte : GRAB A FOSSIL")
T.check(string.find(card.Text.Text, "hold E", 1, true) ~= nil, "carte : maintenir E")
T.eq(card.Number.Text.Text, "1/4", "étape 1/4")
local target = nil
for _, site in DigSiteService.Sites() do
	if site.Zone == Zones.Dig.TutorialZone then
		for _, slot in site.Slots do
			if slot.State == "Present" and slot.Block.Rarity == "Common" and not target then
				target = slot
			end
		end
	end
end
T.check(target ~= nil, "un bloc Common à la Beach")
T.check(guide ~= nil and guide.Guide.Enabled, "rayon vers le but")
T.eq(guide.Marker.Text.Text, "GRAB", "étiquette GRAB")
T.check(string.find(guide.Marker.Distance.Text, "studs", 1, true) ~= nil, "distance affichée")
local beachBlock = false
for _, site in DigSiteService.Sites() do
	for _, slot in site.Slots do
		if site.Zone == Zones.Dig.TutorialZone and slot.Part and (slot.Part.Position - s.Target).Magnitude < 0.01 then
			beachBlock = true
		end
	end
end
T.check(beachBlock, "le rayon montre un bloc de la Beach")
-- temps de marche réel jusqu'au bloc le plus proche (vitesse 0 : WalkSpeed 16)
local spawnPosition = PlotService.SpawnCFrame(plot).Position
local walkTo = (s.Target - spawnPosition).Magnitude / SpeedConfig.WalkSpeedFor(0)
local walkBack = (s.Target - plot.Entrance.Position).Magnitude / (SpeedConfig.WalkSpeedFor(0) * Rarity.Info.Common.CarrySpeed)
env.advance(3)
T.check(not find("Daily RewardsBackdrop").Visible, "calendrier pas ouvert avant le premier dino")

local part = target.Part
player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(3, 1, 3)))
env.advance(0.3)
s = step()
T.check(s and s.Key == "Grab", "toujours l'étape 1 près du bloc")
env.fire(env.signal(part.GrabPrompt, "PromptButtonHoldBegan"), player)
env.advance(Zones.Dig.GrabTime)
env.fire(env.signal(part.GrabPrompt, "Triggered"), player)
env.advance(0.3)

T.section("2. rentrer au parc")
s = step()
T.check(s and s.Key == "Home" and s.Number == 2, "étape 2 : Home")
T.eq(card.Title.Text, "BRING IT HOME!", "carte : BRING IT HOME!")
T.check((s.Target - plot.Entrance.Position).Magnitude < 0.01, "le rayon montre l'entrée du parc")
T.eq(guide.Marker.Text.Text, "HOME", "étiquette HOME")
env.advance(walkBack + 1) -- (le trajet du retour, à pied)
player.Character:PivotTo(CFrame.new(plot.Entrance.Position + Vector3.new(0, 3, -2)))
env.advance(0.5)

T.section("3. la cuve tourne")
local tanks = Replica.Get("Tanks")
T.check(tanks["1"] ~= nil, "le bloc est dans la cuve 1")
T.eq(tanks["1"].EndsAt - tanks["1"].StartedAt, Zones.Dig.TutorialReviveTime, "première cuve rapide")
T.check(Zones.Dig.TutorialReviveTime <= 15, "première cuve : 15 s au plus")
s = step()
T.check(s and s.Key == "Revive" and s.Number == 3, "étape 3 : Revive")
T.check(string.match(card.Title.Text, "^REVIVING%.%.%. 0:%d%d$") ~= nil, "compte à rebours (" .. card.Title.Text .. ")")
T.check(string.find(card.Text.Text, "spin the wheel for free", 1, true) ~= nil, "tour de roue gratuit proposé pendant l'attente")
T.check(not guide.Guide.Enabled, "pas de rayon pendant l'attente")
RateLimit.Reset(player)
local ok, text = Rewards.Spin()
T.check(ok, "tour de roue gratuit (" .. tostring(text) .. ")")
env.advance(0.5)
T.check(string.find(card.Text.Text, "grab another fossil", 1, true) ~= nil, "sans tour gratuit : un autre fossile")

T.section("4. ouvrir la cuve")
env.advance(Zones.Dig.TutorialReviveTime)
s = step()
T.check(s and s.Key == "Open" and s.Number == 4, "étape 4 : Open")
T.check((s.Target - plot.Tanks[1].Position).Magnitude < 0.01, "le rayon montre la cuve")
T.eq(guide.Marker.Text.Text, "OPEN", "étiquette OPEN")
env.fire(env.signal(plot.Tanks[1].TankPrompt, "Triggered"), player)
env.advance(0.3)
T.eq(EnclosureService.Count(player), 1, "premier dino")
local firstDino = env.now() - joinedAt
local walking = walkTo + Zones.Dig.GrabTime + walkBack + Zones.Dig.TutorialReviveTime
print(string.format("premier dino : %.0f s à pied (aller %.0f s, retour chargé %.0f s, cuve %d s)", walking, walkTo, walkBack, Zones.Dig.TutorialReviveTime))
T.check(walking < 75, string.format("premier dino en moins de 75 s à pied (%.0f s)", walking))
T.check(firstDino < 60, "premier dino dans le test")

T.section("après le premier dino")
s = step()
T.check(s and s.Key == "FirstDino" and s.Number == nil, "message du premier dino")
T.check(string.find(card.Text.Text, "/s", 1, true) ~= nil and string.find(card.Text.Text, "offline", 1, true) ~= nil, "revenu, même hors ligne")
-- (écran de révélation du brief 12 d'abord, puis le calendrier quand il se ferme)
env.advance(1)
local reveal = find("NEW DINO!Backdrop")
T.check(reveal ~= nil and reveal.Visible, "écran de révélation du premier dino")
T.check(string.find(reveal:FindFirstChild("Hint", true).Text, "offline", 1, true) ~= nil, "révélation : rapporte même hors ligne")
T.check(not find("Daily RewardsBackdrop").Visible, "calendrier pas par-dessus la révélation")
env.fire(env.signal(find("Nice"), "Activated"))
env.advance(3)
T.check(not reveal.Visible, "révélation fermée (NICE!)")
T.check(find("Daily RewardsBackdrop").Visible, "calendrier ouvert juste après le premier dino")
T.check(not card.Visible, "carte du guide cachée sous le calendrier")
local money = T.data(player).Money
RateLimit.Reset(player)
ok = Rewards.ClaimDaily()
T.check(ok, "jour 1 pris")
T.check(T.data(player).Money - money >= Daily.Amount(Daily.Login.Days[1], nil), "argent du jour 1")
Rewards.Close()
env.advance(4)
s = step()
T.check(s and s.Key == "Treadmill", "étape treadmill")
T.check(card.Visible and card.Title.Text == "GET FASTER", "carte : GET FASTER")
T.check(plot.Treadmill and (s.Target - plot.Treadmill.Position).Magnitude < 0.01, "le rayon montre le treadmill")
player.Character:PivotTo(plot.Treadmill.CFrame * CFrame.new(0, plot.Treadmill.Size.Y / 2 + 3, 0))
TreadmillService.Tick()
env.advance(0.5)
T.check(step().Key == "Treadmill" and step().Target == nil, "sur le tapis : plus de rayon")
T.check(card.Position.Y.Offset < -100, "carte au-dessus de la carte AFK")
env.advance(5)
s = step()
T.check(s and s.Key == "Explore", "dernier conseil")
env.advance(11)
T.eq(step(), nil, "guide fini")
T.check(not Tutorial.IsActive(), "plus actif")
T.check(not card.Visible and not guide.Guide.Enabled and not guide.Marker.Enabled, "carte et rayon cachés")

T.section("premier cadeau")
T.check(Daily.Gifts[1].Minutes <= 2, "premier cadeau à 2 min de jeu au plus")
local played = env.now() - joinedAt
T.check(GiftService.Seconds(player) >= played - 2, "temps de jeu compté depuis l'arrivée")
env.studio = true
AdminService.Run(player, "playtime", { tostring(Daily.Gifts[1].Minutes) })
env.advance(1.5)
T.eq(Rewards.Badge("Gifts"), 1, "cadeau 1 prêt")
RateLimit.Reset(player)
ok = Rewards.ClaimGift(1)
T.check(ok, "cadeau 1 ouvert")

T.section("sans parc ni bloc")
T.check(ZoneService.Get(Zones.Dig.TutorialZone) ~= nil, "zone du tutoriel")
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.clean("aucune erreur")

T.done("daily_onboarding")
