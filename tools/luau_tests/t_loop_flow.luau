-- Boucle (brief 3) : la boucle complète d'un nouveau joueur, serveur et client ensemble. Apparition dans son parc,
-- course à la Beach, arrachage (maintien 1 s), retour au parc, cuve, révélation par le prompt, revenus. Côté client :
-- comptes à rebours du LoopController et annonce dans le chat.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
-- (gardiens du brief 7 éteints : ici le trajet du retour se fait en attendant sur place ; t_pvp_guardians refait le
-- tutoriel en courant devant le gardien de la Beach)
Boot.Services.GuardianService.SetEnabled(false)
local CarryService = Boot.Services.CarryService
local DigSiteService = Boot.Services.DigSiteService
local EnclosureService = Boot.Services.EnclosureService
local IncomeService = Boot.Services.IncomeService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local ZoneService = Boot.Services.ZoneService
local Zones = T.module("src/shared/Config/Zones")
local Workspace = env.game:GetService("Workspace")
local Vector3, CFrame = env.Vector3, env.CFrame

local player = env.addPlayer({ Local = true, Name = "Newbie", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()

T.section("client")
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
T.check(ClientBoot.Controllers.LoopController ~= nil, "LoopController chargé")
local Replica = ClientBoot.Controllers.ReplicaController
env.waitUntil(function()
	return Replica.IsReady()
end, "état reçu", 30)
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")
T.eq(Replica.Get("Plot"), 1, "le client connaît son parc")
T.eq(Replica.Get("Tutorial"), 0, "tutoriel : nouveau")
T.eq(Replica.Get("TankCount"), 2, "le client connaît ses cuves")
env.advance(0.5)
local siteLabel = DigSiteService.Sites()[1].Label
T.check(string.match(siteLabel.Text, "^Refill in %d+:%d%d$") ~= nil, "compte à rebours du gisement : " .. siteLabel.Text)

T.section("dans son parc")
T.check(PlotService.IsInOwnPlot(player), "apparaît dans son parc")
T.eq(player:GetAttribute("Zone"), "", "pas sur la route")

T.section("courir à la Beach et arracher un bloc")
local beach = ZoneService.Get("Beach")
player.Character:PivotTo(CFrame.new(beach.Area.Position + Vector3.new(0, 4, -100)))
env.advance(0.5)
T.eq(player:GetAttribute("Zone"), "Beach", "sur la Beach")
local target = nil
for _, site in DigSiteService.Sites() do
	if site.Zone == "Beach" then
		for _, slot in site.Slots do
			if slot.State == "Present" and slot.Block.Rarity == "Common" and not target then
				target = slot
			end
		end
	end
end
T.check(target ~= nil, "un bloc Common à la Beach (tutoriel)")
local part = target.Part
player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(3, 1, 3)))
local prompt = part.GrabPrompt
T.eq(prompt.HoldDuration, Zones.Dig.GrabTime, "maintenir 1 s")
T.eq(prompt.KeyboardKeyCode, env.Enum.KeyCode.E, "touche E")
env.fire(env.signal(prompt, "PromptButtonHoldBegan"), player)
env.advance(1)
env.fire(env.signal(prompt, "Triggered"), player)
env.advance(0.1)
T.check(CarryService.IsCarrying(player), "bloc sur le dos")
T.eq(Replica.Get("Carrying").Rarity, "Common", "le client sait ce qu'il porte")
T.eq(Replica.Get("Tutorial"), 1, "tutoriel : bloc arraché")

T.section("rentrer au parc")
local plot = PlotService.Get(player)
env.advance(15) -- (le trajet du retour, à pied)
player.Character:PivotTo(CFrame.new(plot.Entrance.Position + Vector3.new(0, 3, 8)))
env.advance(0.3)
T.check(CarryService.IsCarrying(player), "encore dehors, devant l'entrée")
player.Character:PivotTo(CFrame.new(plot.Entrance.Position + Vector3.new(0, 3, -2)))
env.advance(0.3)
T.check(not CarryService.IsCarrying(player), "l'entrée passée : le bloc est à lui")
T.eq(Replica.Get("Carrying"), nil, "plus rien sur le dos côté client")
T.eq(Replica.Get("Tanks")["1"].Rarity, "Common", "le client voit la cuve 1 occupée")
local tankLabel = plot.Tanks[1].TankLabel.Text
local tankFill = plot.Tanks[1].TankLabel.Bar.Fill
env.advance(1)
T.check(string.match(tankLabel.Text, "^%d+:%d%d$") ~= nil, "compte à rebours de la cuve : " .. tankLabel.Text)
T.eq(plot.Tanks[1].TankLabel.Title.Text, "COMMON FOSSIL", "rareté au-dessus du compte à rebours")
T.check(plot.Tanks[1].TankLabel.Bar.Visible, "barre de progression visible")
local early = tankFill.Size.X.Scale
env.advance(14)
T.check(tankFill.Size.X.Scale > early and tankFill.Size.X.Scale > 0.4 and tankFill.Size.X.Scale < 0.65, "la barre avance avec le temps (" .. tankFill.Size.X.Scale .. ")")

T.section("révélation")
env.advance(16)
T.eq(tankLabel.Text, "READY!", "cuve prête")
T.eq(tankFill.Size.X.Scale, 1, "barre pleine")
local tankPrompt = plot.Tanks[1].TankPrompt
T.check(tankPrompt.Enabled, "prompt Reveal")
env.fire(env.signal(tankPrompt, "Triggered"), player)
env.advance(0.1)
T.eq(EnclosureService.Count(player), 1, "premier dino dans l'enclos")
T.eq(Replica.Get("Tutorial"), 3, "tutoriel fini")
local id, dino = next(Replica.Get("Dinos"))
T.check(id ~= nil and dino.Income > 0, "le client voit son dino et son revenu")
T.check(Replica.Get("Income") > 0, "revenu $/s côté client")
local timeline = env.now()
T.check(timeline < 120, "premier dino en moins de 2 min de temps de jeu (" .. math.floor(timeline) .. " s)")

T.section("revenus")
local money = MoneyService.Get(player)
env.advance(10)
T.near(MoneyService.Get(player) - money, IncomeService.GetIncome(player) * 10, 1e-6, "10 s de revenus")
T.near(Replica.Get("Money"), MoneyService.Get(player), 1e-6, "argent à jour côté client")

T.section("annonce dans le chat")
local LoopController = ClientBoot.Controllers.LoopController
local remote = env.game:GetService("ReplicatedStorage").Remotes.LoopAnnounce
env.fire(env.signal(remote, "OnClientEvent"), "A SECRET fossil appeared in the Volcano!")
env.fire(env.signal(remote, "OnClientEvent"), { "bad" })
env.fire(env.signal(remote, "OnClientEvent"), string.rep("x", 5000))
env.flush()
T.eq(#ClientBoot.Errors, 0, "annonces sans erreur (sans canal de chat dans les tests)")
local label = env.Instance.new("TextLabel")
label:SetAttribute("EndsAt", Workspace:GetServerTimeNow() + 65)
label:SetAttribute("Format", "Wait %s")
T.eq(LoopController.CountdownText(label, Workspace:GetServerTimeNow()), "Wait 1:05", "texte du compte à rebours")
label:SetAttribute("Done", "Go!")
T.eq(LoopController.CountdownText(label, Workspace:GetServerTimeNow() + 70), "Go!", "texte à la fin")
label:SetAttribute("EndsAt", 0 / 0)
T.eq(LoopController.CountdownText(label, 0), nil, "EndsAt NaN ignoré")
label:SetAttribute("EndsAt", nil)
T.eq(LoopController.CountdownText(label, 0), nil, "sans EndsAt : texte du serveur")
local bar = env.Instance.new("Frame")
T.eq(LoopController.Progress(bar, 0), nil, "barre sans heures : rien")
bar:SetAttribute("StartedAt", 100)
bar:SetAttribute("EndsAt", 200)
T.eq(LoopController.Progress(bar, 150), 0.5, "barre à moitié")
T.eq(LoopController.Progress(bar, 50), 0, "barre vide avant le début")
T.eq(LoopController.Progress(bar, 250), 1, "barre pleine à la fin")
bar:SetAttribute("EndsAt", 100)
T.eq(LoopController.Progress(bar, 0), 1, "durée nulle (Instant Revive) : pleine")
bar:SetAttribute("EndsAt", 0 / 0)
T.eq(LoopController.Progress(bar, 0), nil, "EndsAt NaN ignoré")
bar:SetAttribute("EndsAt", 50)
T.eq(LoopController.Progress(bar, 0), nil, "StartedAt après EndsAt : début inconnu, ignoré")
bar:SetAttribute("StartedAt", 0)
T.eq(LoopController.Progress(bar, 10), nil, "StartedAt nul (vieille sauvegarde) : ignoré")

T.section("FossilDebug avec un personnage")
local DebugService = Boot.Services.DebugService
local dinos = EnclosureService.Count(player)
local income = IncomeService.GetIncome(player)
for _, name in { "plots", "zones", "digsites", "carry", "revive", "enclosure", "income" } do
	local ok, fail, lines = DebugService.RunTest(name)
	T.eq(fail, 0, "test en jeu " .. name .. " sans échec")
	if fail > 0 then
		print(table.concat(lines, "\n"))
	end
	if name == "carry" then
		T.check(ok >= 10, "test carry fait en entier (" .. ok .. " OK)")
	end
end
env.advance(0.5)
T.eq(EnclosureService.Count(player), dinos, "dino de test retiré")
T.eq(IncomeService.GetIncome(player), income, "revenu inchangé")
T.check(not CarryService.IsCarrying(player), "bloc de test enlevé")
T.eq(player.Character:FindFirstChild("CarriedFossil"), nil, "plus de bloc sur le dos")

T.done("loop_flow")
