-- Course stressante (côté client) : StressController. Porter un bloc : battement de cœur, vignette sombre, couleurs
-- ternies. Poursuivi par un gardien : rugissement et coup d'orchestre, « RUN!! », éclair rouge, coup de zoom, vignette
-- rouge, champ de vision élargi, pas du gardien qui secouent la caméra ; prise : « CAUGHT! » ; abandon : « ESCAPED! ».
-- Tout revient au calme, sans dérive de la caméra ni du champ de vision. Bonk, piège, effet proche. Messages abîmés
-- du serveur sans erreur. « Reduce Motion » et caméra scriptée.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local CarryService = Boot.Services.CarryService
local DigSiteService = Boot.Services.DigSiteService
local GuardianService = Boot.Services.GuardianService
local Stress = T.module("src/shared/Config/Stress")
local Zones = T.module("src/shared/Config/Zones")
local Rarity = T.module("src/shared/Config/Rarity")
local RateLimit = T.lib("RateLimit")
local Vector3, CFrame, Enum = env.Vector3, env.CFrame, env.Enum
local Workspace = env.game:GetService("Workspace")
local Lighting = env.game:GetService("Lighting")
local SoundService = env.game:GetService("SoundService")
local GuiService = env.game:GetService("GuiService")
local ReplicatedStorage = env.game:GetService("ReplicatedStorage")

local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return me:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
env.flush()
local StressController = ClientBoot.Controllers.StressController
T.check(StressController ~= nil, "StressController chargé")
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Custom
local BASE = CFrame.new(10, 20, 30) * CFrame.Angles(-0.3, 0.5, 0)
camera.CFrame = BASE
camera.FieldOfView = 70

local function played(name: string, since: number): number
	local count = 0
	for index = since + 1, #env.soundsPlayed do
		if env.soundsPlayed[index].Name == name then
			count += 1
		end
	end
	return count
end

local function waitFor(condition: () -> boolean, limit: number): boolean
	local deadline = env.now() + limit
	while not condition() do
		if env.now() >= deadline then
			return false
		end
		env.advance(0.1)
	end
	return true
end

local function slotOf(zone: string): any
	for _, site in DigSiteService.Sites() do
		if site.Zone == zone then
			for _, slot in site.Slots do
				if slot.State == "Present" and slot.Block.Rarity == "Common" then
					return slot
				end
			end
		end
	end
	return nil
end

local function grab(player, slot)
	RateLimit.Reset(player)
	local part = slot.Part
	player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 1.5, 4)))
	local prompt = part.GrabPrompt
	env.fire(env.signal(prompt, "PromptButtonHoldBegan"), player)
	env.advance(Zones.Dig.GrabTime + 0.05)
	env.fire(env.signal(prompt, "Triggered"), player)
	env.flush()
end

local function shakeOffset(): number
	return (camera.CFrame.Position - BASE.Position).Magnitude
end

local function calm(): boolean
	local state = StressController.State()
	return state.Intensity == 0 and state.Trauma == 0 and state.Flash == 0 and state.Text == 0
end

local playerGui = me:WaitForChild("PlayerGui")
local screen = playerGui:FindFirstChild("Stress")
local stressGrade = Lighting:FindFirstChild("StressGrade")
local soundFolder = SoundService:FindFirstChild("StressSounds")
local heartbeat = soundFolder and soundFolder:FindFirstChild("StressHeartbeat")
local alert = playerGui:FindFirstChild("StressText") and playerGui.StressText.Root:FindFirstChild("Alert")

T.section("au calme")
T.check(screen ~= nil and screen.IgnoreGuiInset and not screen.ResetOnSpawn, "ScreenGui Stress plein écran, gardé à la réapparition")
T.check(screen.DisplayOrder < 0, "vignette sous le HUD")
local edges = {}
for _, side in { "Left", "Right", "Top", "Bottom" } do
	local edge = screen:FindFirstChild("Vignette" .. side)
	T.check(edge ~= nil and edge:FindFirstChildOfClass("UIGradient") ~= nil, "vignette " .. side .. " en dégradé")
	table.insert(edges, edge)
end
T.check(stressGrade ~= nil and stressGrade:IsA("ColorCorrectionEffect") and not stressGrade.Enabled, "correction de couleur prête, éteinte")
T.check(heartbeat ~= nil and heartbeat.Looped and heartbeat.SoundId == Stress.Sounds.Heartbeat.Id, "battement de cœur en boucle")
for _, name in { "Roar", "Stinger", "Step", "Catch" } do
	T.check(soundFolder:FindFirstChild("Stress" .. name) ~= nil, "son " .. name)
end
T.check(alert ~= nil and not alert.Visible, "gros texte caché")
env.advance(1)
T.check(calm(), "rien sans bloc ni gardien")
T.check(not heartbeat.Playing, "cœur silencieux")
T.eq(edges[1].BackgroundTransparency, 1, "vignette invisible")
T.eq(camera.CFrame, BASE, "caméra intacte")
T.eq(camera.FieldOfView, 70, "champ de vision intact")

T.section("calculs")
T.eq(StressController.Target("", "", nil), 0, "sans bloc ni gardien : 0")
T.near(StressController.Target("Common", "", nil), Stress.Carry.Base + Stress.Carry.PerRank, 1e-9, "bloc Common")
T.check(StressController.Target("Secret", "", nil) > StressController.Target("Epic", "", nil), "plus rare, plus stressant")
T.check(StressController.Target("Secret", "", nil) < Stress.Chase.Base, "porter un Secret reste moins stressant qu'une poursuite")
T.eq(StressController.Target("Nope", "", nil), 0, "rareté inconnue : 0")
T.eq(StressController.Target("", "Beach", nil), Stress.Chase.Base, "poursuivi, gardien introuvable")
T.eq(StressController.Target("", "Beach", 1000), Stress.Chase.Base, "poursuivi de loin")
T.eq(StressController.Target("Common", "Beach", Stress.Chase.Near), 1, "gardien tout près : 1")
T.eq(StressController.Target("", "Beach", 0 / 0), Stress.Chase.Base, "distance NaN ignorée")
T.check(StressController.Closeness(20) > StressController.Closeness(40), "plus près, plus stressant")
T.eq(StressController.StepInterval(0), Stress.Step.Max, "gardien immobile : pas lents")
T.eq(StressController.StepInterval(1e6), Stress.Step.Min, "pas bornés")
T.near(StressController.StepInterval(20), Stress.Step.Stride / 20, 1e-9, "pas au rythme de la course")
T.eq(StressController.ShakeOffset(0, 3), CFrame.identity, "pas de trauma, pas de secousse")
local maxAngle = math.rad(Stress.Shake.MaxAngle)
local within = true
for k = 1, 200 do
	local offset = StressController.ShakeOffset(1, k * 0.037)
	if offset.Position.Magnitude > Stress.Shake.MaxOffset * math.sqrt(2) + 1e-6 or offset.LookVector:Dot(Vector3.new(0, 0, -1)) < math.cos(maxAngle * 2) then
		within = false
	end
end
T.check(within, "secousse bornée (angle et décalage)")
T.check(StressController.ShakeOffset(1, 0.5).Position.Magnitude > StressController.ShakeOffset(0.3, 0.5).Position.Magnitude, "amplitude = trauma²")
T.eq(StressController.Pulse(0), 1, "battement")
T.eq(StressController.Pulse(0.6), 0, "entre deux battements")

T.section("porter un bloc")
GuardianService.SetEnabled(false)
local slot = slotOf("Beach")
grab(me, slot)
T.check(CarryService.IsCarrying(me), "bloc sur le dos")
env.advance(1)
local state = StressController.State()
T.near(state.Intensity, StressController.Target("Common", "", nil), 1e-6, "intensité d'un bloc Common")
T.check(heartbeat.Playing, "le cœur bat")
T.check(heartbeat.Volume > 0 and heartbeat.Volume < Stress.Sounds.Heartbeat.Volume * 0.6, "cœur discret avec un Common (" .. heartbeat.Volume .. ")")
local alpha = 1 - edges[1].BackgroundTransparency
T.check(alpha > 0.05 and alpha < 0.3, "vignette légère (" .. alpha .. ")")
T.eq(edges[1].BackgroundColor3, Stress.Vignette.CarryColor, "vignette sombre")
T.check(stressGrade.Enabled and stressGrade.Saturation < 0, "couleurs ternies")
T.eq(camera.FieldOfView, 70, "pas de zoom sans poursuite")
T.eq(camera.CFrame, BASE, "pas de secousse sans poursuite")
CarryService.ReturnToSite(me)
local quietest = math.huge
waitFor(function()
	if heartbeat.Playing then
		quietest = math.min(quietest, heartbeat.Volume)
	end
	return not heartbeat.Playing
end, 3)
T.check(quietest < Stress.Sounds.Heartbeat.Volume * 0.1, "le cœur s'éteint en douceur (" .. quietest .. ")")
env.advance(3)
T.check(calm(), "bloc rendu : on se calme")
T.check(not heartbeat.Playing, "le cœur se tait")
T.eq(edges[1].BackgroundTransparency, 1, "vignette partie")
T.check(not stressGrade.Enabled, "couleurs rendues")

T.section("poursuite : réveil et rugissement")
GuardianService.SetEnabled(true)
local beach = GuardianService.Get("Beach")
local sounds = #env.soundsPlayed
slot = slotOf("Beach")
grab(me, slot)
T.eq(me:GetAttribute("ChasedBy"), "Beach", "poursuivi par le gardien de la Beach")
T.check(waitFor(function()
	return beach.State == "Roar"
end, 3), "il rugit")
env.advance(0.05)
T.eq(played("StressRoar", sounds), 1, "son du rugissement")
T.eq(played("StressStinger", sounds), 1, "coup d'orchestre")
T.check(alert.Visible and alert.Text == Stress.Texts.Run.Text, "« RUN!! » à l'écran")
state = StressController.State()
T.check(state.Trauma > 0.5, "grosse secousse (" .. state.Trauma .. ")")
T.check(screen.Flash.BackgroundTransparency < 1, "éclair rouge")
T.check(camera.FieldOfView > 75, "coup de zoom (" .. camera.FieldOfView .. ")")
T.check(shakeOffset() > 1e-4 or camera.CFrame.LookVector:Dot(BASE.LookVector) < 1 - 1e-7, "la caméra tremble")
T.check(shakeOffset() <= Stress.Shake.MaxOffset * 1.5, "secousse bornée")

T.section("poursuite : il se rapproche")
T.check(waitFor(function()
	return beach.State == "Run"
end, 3), "il court")
local stepsBefore = played("StressStep", sounds)
local closest = 0
local reds = true
local caught = waitFor(function()
	local s = StressController.State()
	closest = math.max(closest, s.Closeness)
	if s.Closeness > 0.5 and edges[1].BackgroundColor3 ~= Stress.Vignette.ChaseColor then
		reds = false
	end
	return me:GetAttribute("ChasedBy") ~= "Beach"
end, 30)
T.check(caught, "le gardien attrape le joueur immobile")
T.check(closest > 0.8, "il est arrivé tout près (" .. closest .. ")")
T.check(reds, "vignette rouge pendant la poursuite")
T.check(played("StressStep", sounds) - stepsBefore >= 3, "ses pas s'entendent (" .. (played("StressStep", sounds) - stepsBefore) .. ")")
env.advance(0.05)
T.eq(played("StressCatch", sounds), 1, "son de la prise")
T.check(alert.Visible and alert.Text == Stress.Texts.Caught.Text, "« CAUGHT! » à l'écran")
T.check(StressController.State().Trauma > 0.8, "secousse de la prise")

T.section("retour au calme")
T.check(waitFor(calm, 10), "tout se calme après la prise")
env.advance(0.5)
T.check(not heartbeat.Playing, "le cœur se tait")
T.eq(edges[1].BackgroundTransparency, 1, "vignette partie")
T.eq(screen.Flash.BackgroundTransparency, 1, "éclair parti")
T.check(not alert.Visible, "texte parti")
T.check(not stressGrade.Enabled, "couleurs rendues")
T.near(camera.FieldOfView, 70, 1e-6, "champ de vision rendu")
T.check(shakeOffset() < 1e-3 and camera.CFrame.LookVector:Dot(BASE.LookVector) > 1 - 1e-6, "caméra revenue à sa place (pas de dérive)")

T.section("abandon, bonk, piège, effet proche")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function fire(name: string, ...)
	env.fire(env.signal(remotes[name], "OnClientEvent"), ...)
	env.flush()
end
fire("GuardianAlert", "Beach", "Lost", "Dropped")
T.check(not alert.Visible, "bloc perdu (bonk, piège) : pas de « ESCAPED! »")
fire("GuardianAlert", "Beach", "Lost")
T.check(not alert.Visible, "abandon sans raison : pas de « ESCAPED! »")
fire("GuardianAlert", "Beach", "Lost", {})
T.check(not alert.Visible, "raison abîmée ignorée")
fire("GuardianAlert", "Beach", "Lost", "Safe")
T.check(alert.Visible and alert.Text == Stress.Texts.Escaped.Text, "« ESCAPED! » quand il abandonne (rentré au parc)")
waitFor(calm, 10)
fire("GuardianAlert", "Beach", "Lost", "Escaped")
T.check(alert.Visible and alert.Text == Stress.Texts.Escaped.Text, "« ESCAPED! » quand il abandonne (semé)")
fire("Knocked", 1.5, "Bonk")
local bonked = StressController.State().Trauma
T.check(bonked >= Stress.Shake.Bonk - 1e-6, "bonk : secousse")
local root = me.Character.HumanoidRootPart
fire("PvpEffect", "Bonk", root.Position + Vector3.new(8, 0, 0))
T.eq(StressController.State().Trauma, bonked, "son propre bonk vu par tous, un peu plus loin (il court) : rien de plus")
waitFor(calm, 10)
fire("PvpEffect", "Bonk", root.Position + Vector3.new(10, 0, 0))
local nearby = StressController.State().Trauma
T.check(nearby > 0 and nearby < Stress.Shake.Nearby, "bonk à 10 studs : petite secousse")
waitFor(calm, 10)
fire("PvpEffect", "Catch", root.Position)
T.eq(StressController.State().Trauma, 0, "son propre effet : rien de plus")
fire("PvpEffect", "Bonk", root.Position + Vector3.new(200, 0, 0))
T.eq(StressController.State().Trauma, 0, "effet lointain : rien")
fire("Knocked", 3, "Trap")
T.check(StressController.State().Trauma >= Stress.Shake.Trap - 1e-6, "piège : secousse")
waitFor(calm, 10)

T.section("messages abîmés")
fire("GuardianAlert", {}, nil)
fire("GuardianAlert", "Beach", "Dance")
fire("GuardianAlert", nil, "Roar")
fire("PvpEffect", "Bonk", Vector3.new(0 / 0, 0, 0))
fire("PvpEffect", "Bonk", "here")
fire("PvpEffect")
fire("Knocked", nil, {})
fire("Knocked", "x", 5)
T.check(calm(), "messages abîmés ignorés")
T.eq(#ClientBoot.Errors, 0, "sans erreur")

T.section("Reduce Motion et caméra scriptée")
waitFor(calm, 10)
env.advance(1)
local cleanCFrame = camera.CFrame
GuiService.ReducedMotionEnabled = true
env.advance(2.5)
StressController.Alert("Roar")
env.advance(1 / 60)
T.near(camera.FieldOfView, 70, 1e-6, "pas de coup de zoom")
T.check((camera.CFrame.Position - cleanCFrame.Position).Magnitude <= Stress.Shake.MaxOffset * Stress.Shake.ReducedMotion * 1.5, "secousse réduite")
GuiService.ReducedMotionEnabled = false
waitFor(calm, 10)
env.advance(0.5)
cleanCFrame = camera.CFrame
camera.CameraType = Enum.CameraType.Scriptable
StressController.Alert("Catch")
env.advance(0.2)
T.eq(camera.CFrame, cleanCFrame, "caméra scriptée (cinématique) : pas de secousse")
camera.CameraType = Enum.CameraType.Custom
waitFor(calm, 10)

T.section("champ de vision changé par un autre script")
env.advance(0.5)
T.near(camera.FieldOfView, 70, 1e-6, "champ de vision de départ")
StressController.Alert("Roar")
env.advance(0.2)
T.check(camera.FieldOfView > 75, "coup de zoom")
camera.FieldOfView = 90 -- (zoom de sprint posé par un autre script)
env.advance(1 / 60)
T.check(camera.FieldOfView > 90, "le coup de zoom s'ajoute au sien (" .. camera.FieldOfView .. ")")
waitFor(calm, 10)
env.advance(1)
T.near(camera.FieldOfView, 90, 1e-3, "son champ de vision est gardé au calme")
camera.FieldOfView = 70
env.advance(0.5)
T.eq(camera.FieldOfView, 70, "plus rien ne le touche au calme")

T.section("rareté")
for _, name in Rarity.Order do
	T.check(StressController.Target(name, "", nil) > 0, name .. " : stress en portant le bloc")
end
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.done("stress_client")
