-- Récompenses et AFK, serveur et client ensemble : RewardsController (boutons Daily / Spin / Gifts et leurs pastilles,
-- calendrier ouvert tout seul à l'arrivée, Claim, roue, cadeaux) et AfkController (carte du treadmill, demande de
-- reconnexion après l'inactivité). Événements abîmés du serveur sans erreur.
local T = require("./testkit")
local env = T.env

env.studio = false -- (la reconnexion AFK ne part pas dans Studio)
env.quiet = true
local Config = T.config()
local Daily = Config.Daily
local AFK = Config.Speed.Treadmill.Afk
env.stubMethod("TeleportOptions", "SetTeleportData", function() end)
local Boot = T.bootServer()
local AdminService = Boot.Services.AdminService
local AfkService = Boot.Services.AfkService
local PlotService = Boot.Services.PlotService
local TreadmillService = Boot.Services.TreadmillService
local RateLimit = T.lib("RateLimit")
local CFrame = env.CFrame

local sent = 0
AfkService.Teleport = function()
	sent += 1
end

local player = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()

local function find(name: string): any
	return player.PlayerGui:FindFirstChild(name, true)
end

local function shown(text: string): boolean
	for _, inst in player.PlayerGui:GetDescendants() do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Visible and string.find(inst.Text, text, 1, true) then
			return true
		end
	end
	return false
end

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local Rewards = ClientBoot.Controllers.RewardsController
local Afk = ClientBoot.Controllers.AfkController
local Replica = ClientBoot.Controllers.ReplicaController
T.check(Rewards ~= nil and Afk ~= nil, "RewardsController et AfkController chargés")
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
env.advance(0.5)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

T.section("boutons")
local buttons = find("RewardButtons")
T.check(buttons ~= nil and buttons.Visible, "boutons des récompenses")
for _, name in { "Daily", "Spin", "Gifts" } do
	T.check(buttons and buttons:FindFirstChild(name) ~= nil, "bouton " .. name)
end
T.eq(Rewards.Badge("Daily"), 1, "pastille Daily : récompense du jour")
T.eq(Rewards.Badge("Spin"), 1, "pastille Spin : tour gratuit")
T.eq(Rewards.Badge("Gifts"), 0, "pastille Gifts : rien de prêt")
T.check(buttons.Daily.Badge.Visible and buttons.Daily.Badge.Count.Text == "!", "pastille Daily affichée")
T.check(not buttons.Gifts.Badge.Visible, "pastille Gifts cachée")
Rewards.SetButtonsVisible(false)
T.check(not buttons.Visible, "SetButtonsVisible(false)")
Rewards.SetButtonsVisible(true)

T.section("calendrier")
env.advance(3)
local backdrop = find("Daily RewardsBackdrop")
T.check(backdrop ~= nil and backdrop.Visible, "calendrier ouvert tout seul à l'arrivée")
T.check(shown("CLAIM DAY 1"), "bouton Claim du jour 1")
local money = T.data(player).Money
local ok, text = Rewards.ClaimDaily()
env.advance(0.5)
T.check(ok, "Claim (" .. tostring(text) .. ")")
T.eq(T.data(player).Money - money, Daily.Amount(Daily.Login.Days[1], nil), "argent du jour 1")
T.eq(Rewards.Badge("Daily"), 0, "pastille Daily éteinte")
T.check(shown("NEXT IN"), "compte à rebours du jour suivant")
T.check(shown("added") or shown("Day 1"), "gain annoncé")
RateLimit.Reset(player)
ok, text = Rewards.ClaimDaily()
T.check(not ok and text == "Come back tomorrow for your next reward!", "pas deux fois")

T.section("roue")
Rewards.Open("Spin")
env.advance(0.3)
T.check(find("Lucky SpinBackdrop").Visible, "roue ouverte")
T.check(not backdrop.Visible, "calendrier fermé (un menu à la fois)")
T.check(shown("%"), "chances affichées sur la roue")
RateLimit.Reset(player)
ok, text = Rewards.Spin()
T.check(ok, "tour (" .. tostring(text) .. ")")
local again = Rewards.Spin()
T.check(not again, "pas de deuxième tour pendant que la roue tourne")
env.advance(4)
T.check(shown("You won"), "gain affiché quand la roue s'arrête")
T.eq(T.data(player).Spins.Total, 1, "un seul tour joué")
T.eq(Rewards.Badge("Spin"), T.data(player).Spins.Stored, "pastille Spin : tours qui restent")

T.section("cadeaux")
Rewards.Open("Gifts")
env.advance(0.3)
T.check(find("Free GiftsBackdrop").Visible, "cadeaux ouverts")
T.check(shown("Ready in") or shown(":"), "compte à rebours")
-- (temps de jeu avancé par la commande playtime : 5 minutes de jeu simulées image par image sont trop lentes)
env.studio = true
T.check(AdminService.Run(player, "playtime", { tostring(Daily.Gifts[1].Minutes) }), "commande playtime")
env.studio = false
env.advance(1.5)
T.eq(Rewards.Badge("Gifts"), 1, "pastille Gifts : cadeau 1 prêt")
T.check(shown("OPEN"), "bouton OPEN")
RateLimit.Reset(player)
money = T.data(player).Money
ok, text = Rewards.ClaimGift(1)
env.advance(0.5)
T.check(ok, "cadeau 1 (" .. tostring(text) .. ")")
T.check(T.data(player).Money > money, "argent du cadeau")
T.eq(Rewards.Badge("Gifts"), 0, "pastille Gifts éteinte")
RateLimit.Reset(player)
ok = Rewards.ClaimGift(1)
T.check(not ok, "pas deux fois")

T.section("carte AFK")
local plot = PlotService.Get(player)
local belt = plot.Treadmill
local afkCard = find("AfkCard")
T.check(afkCard ~= nil and not afkCard.Visible, "carte cachée hors du tapis")
Afk.OnIdle(AFK.RejoinAfter + 60)
env.flush()
T.eq(sent, 0, "inactif hors du tapis : pas de reconnexion")
player.Character.HumanoidRootPart.CFrame = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, 0)
TreadmillService.Tick()
env.advance(3)
T.check(afkCard.Visible, "carte visible sur le tapis")
T.check(shown("Speed/s"), "gain par seconde affiché")
T.check(Afk.Gained() > 0, "vitesse gagnée depuis la montée")
T.check(shown("You can stay AFK here"), "rappel : on peut rester AFK")
Afk.OnIdle(AFK.RejoinAfter - 60)
env.flush()
T.eq(sent, 0, "pas encore assez longtemps inactif")
Afk.OnIdle(AFK.RejoinAfter)
env.flush()
T.eq(sent, 1, "inactif assez longtemps : reconnexion demandée et lancée")
T.check(shown("Reconnecting"), "carte : reconnexion en cours")
Afk.OnIdle(AFK.RejoinAfter + 30)
env.flush()
T.eq(sent, 1, "une seule demande")
local idled = env.signal(player, "Idled")
env.fire(idled, AFK.RejoinAfter + 200)
env.flush()
T.eq(sent, 1, "Players.LocalPlayer.Idled branché, sans redemander tout de suite")
player.Character.HumanoidRootPart.CFrame = CFrame.new(belt.Position + env.Vector3.new(0, 3, 60))
TreadmillService.Tick()
env.advance(0.5)
T.check(not afkCard.Visible, "carte cachée en descendant")

T.section("événements abîmés")
local remotes = env.game:GetService("ReplicatedStorage").Remotes
for _, value in T.hostileValues() do
	env.fire(env.signal(remotes.RewardGranted, "OnClientEvent"), value, value, value)
	Afk.OnIdle(value)
end
env.fire(env.signal(remotes.RewardGranted, "OnClientEvent"), "Gift", "+2 Spins", nil)
env.fire(env.signal(remotes.RewardGranted, "OnClientEvent"), "Daily", "Epic Fossil", "Epic")
env.advance(0.5)
T.check(shown("added to your revival tanks"), "fossile gagné : annoncé")
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")

T.done("daily_client")
