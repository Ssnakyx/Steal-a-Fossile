--!strict
-- Course stressante (côté client) : quand le joueur porte un bloc, et encore plus quand un gardien le poursuit, l'image
-- et le son montent en tension (valeurs dans Config.Stress) :
--   * battement de cœur en boucle (plus fort et plus rapide avec l'intensité), vignette sombre puis rouge qui bat avec
--     le cœur, couleurs ternies, champ de vision élargi pendant la poursuite ;
--   * secousse de la caméra : continue près du gardien, à chacun de ses pas (de plus en plus fort quand il se
--     rapproche), forte au rugissement et à la prise, plus légère au bonk, au piège et près d'un bonk d'un autre ;
--   * au réveil du gardien : rugissement, coup d'orchestre, éclair rouge, coup de zoom et « RUN!! » ; « CAUGHT! » à la
--     prise ; « ESCAPED! » quand il abandonne parce que le joueur est rentré ou l'a semé (pas après un bonk).
-- Lit l'attribut joueur « Carrying » (rareté portée, brief 3) et « ChasedBy » (zone du gardien, brief 7), le modèle
-- tagué « Guardian » de cette zone (attributs Guardian, State, Speed ; pièce Root) et les remotes GuardianAlert,
-- Knocked et PvpEffect (brief 7). Les effets de rareté des dinos restent à DinoAnimController.
-- La secousse est ajoutée juste après la caméra de Roblox et retirée au tout début de l'image suivante (avant les
-- commandes et la caméra) : la caméra ne dérive jamais et les déplacements ne sont pas faussés. « Reduce Motion » (réglages Roblox) : secousse réduite, ni coup de zoom ni texte qui tremble.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Stress = require(ReplicatedStorage.Shared.Config.Stress)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local StressController = {}

local ALERTS = { Roar = true, Run = true, Lost = true, Catch = true }
local ESCAPES = { Safe = true, Escaped = true } -- raisons de Lost qui affichent « ESCAPED! » (pas Dropped)
local MAX_DT = 0.1 -- (une image très longue ne fait pas tout disparaître d'un coup)
local CHASE_BLEND = 2.5 -- passage du sombre au rouge (par seconde)
local ONE_SHOT_LIFE = 10 -- secondes avant de détruire un son joué une fois
local SELF_RADIUS = 4 -- un PvpEffect à moins de 4 studs est le sien (déjà ressenti par Knocked ou GuardianAlert)
local SELF_WINDOW = 0.5 -- un PvpEffect juste après son propre coup est le sien aussi (le serveur l'envoie juste après)
local HEART_FADE = 0.2 -- en dessous de cette intensité, le cœur baisse jusqu'au silence
local POP_TIME = 0.18 -- texte : grossit puis revient à sa taille
local FADE_TIME = 0.4 -- texte : disparaît en fondu à la fin
local MOTION_CHECK = 2 -- secondes entre deux lectures de « Reduce Motion »
local WHITE = Color3.new(1, 1, 1)

type TextInfo = { Text: string, Color: Color3, Time: number }

type View = {
	Screen: ScreenGui,
	Edges: { Frame },
	Flash: Frame,
	Alert: TextLabel,
	AlertScale: UIScale,
	AlertStroke: UIStroke?,
}

local view: View? = nil
local grade: ColorCorrectionEffect? = nil
local heartbeat: Sound? = nil
local templates: { [string]: Sound } = {}

local intensity = 0 -- 0 à 1, suit la cible (Target) en douceur
local chaseMix = 0 -- 0 en portant un bloc, 1 poursuivi (couleur et champ de vision)
local closeness = 0 -- proximité du gardien qui poursuit (0 à 1)
local trauma = 0
local flash = 0
local fovPunch = 0
local fovApplied = 0
local fovWritten = 0 -- dernier champ de vision écrit (un autre script l'a changé s'il diffère)
local fovCamera: Camera? = nil
local shakeApplied = CFrame.identity
local shakeCamera: Camera? = nil
local shaking = false
local clock = 0
local beatPhase = 0
local stepTimer = 0
local textTimer = 0
local textTime = 1
local idle = false
local reducedMotion = false
local motionCheckAt = 0
local guardianZone = ""
local guardianModel: Model? = nil
local selfHitAt = -math.huge

-- ===================================================================== calculs (sans effet de bord)

-- Proximité du gardien : 0 à Chase.Far studs et plus (ou distance inconnue), 1 à Chase.Near studs et moins
function StressController.Closeness(distance: number?): number
	if distance == nil or distance ~= distance then
		return 0
	end
	local near, far = Stress.Chase.Near, Stress.Chase.Far
	return math.clamp((far - distance) / (far - near), 0, 1)
end

-- Intensité visée : rareté portée ("" sans bloc), zone du gardien qui poursuit ("" sinon), distance à ce gardien
function StressController.Target(carrying: string, chasedBy: string, distance: number?): number
	local target = 0
	local info = Rarity.Info[carrying]
	if info then
		target = Stress.Carry.Base + Stress.Carry.PerRank * info.Rank
	end
	if chasedBy ~= "" then
		local base = Stress.Chase.Base
		target = math.max(target, base + (1 - base) * StressController.Closeness(distance))
	end
	return math.clamp(target, 0, 1)
end

-- Secondes entre deux pas d'un gardien qui court à `speed` studs/s
function StressController.StepInterval(speed: number): number
	if not (speed > 0) then
		return Stress.Step.Max
	end
	return math.clamp(Stress.Step.Stride / speed, Stress.Step.Min, Stress.Step.Max)
end

-- Battement de cœur (0 à 1) à la phase `phase` (un battement de 0 à 1) : « boum-boum »
function StressController.Pulse(phase: number): number
	local p = phase % 1
	local first = math.max(0, 1 - p / 0.12)
	local second = math.max(0, 1 - math.abs(p - 0.26) / 0.1) * 0.7
	return math.max(first, second)
end

-- Secousse pour un trauma (0 à 1) à l'instant `t` : bruit lisse, amplitude = trauma² x `scale`
function StressController.ShakeOffset(amount: number, t: number, scale: number?): CFrame
	local shake = math.clamp(amount, 0, 1) ^ 2 * (scale or 1)
	if shake <= 1e-4 then
		return CFrame.identity
	end
	local cfg = Stress.Shake
	local f = cfg.Frequency * t
	local angle = math.rad(cfg.MaxAngle) * shake
	local offset = cfg.MaxOffset * shake
	local function wave(seed: number): number
		return math.clamp(math.noise(f, seed, 0.5) * 2, -1, 1)
	end
	return CFrame.new(wave(11.3) * offset, wave(23.7) * offset, 0) * CFrame.Angles(wave(1.1) * angle, wave(5.9) * angle, wave(9.4) * angle * 0.6)
end

-- État courant (tests, debug)
function StressController.State(): { [string]: number }
	return {
		Intensity = intensity,
		Closeness = closeness,
		Trauma = trauma,
		Flash = flash,
		Fov = fovApplied,
		Text = textTimer,
	}
end

-- ===================================================================== sons

local function makeSound(name: string, id: string, volume: number, speed: number, parent: Instance): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Stress" .. name
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.Parent = parent
	return sound
end

-- Joue un son une fois (une copie : plusieurs peuvent se chevaucher), volume x `volume`
local function playOnce(name: string, volume: number?)
	local template = templates[name]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.Volume = template.Volume * (volume or 1)
	sound.Parent = template.Parent
	sound:Play()
	task.delay(ONE_SHOT_LIFE, function()
		sound:Destroy()
	end)
end

-- ===================================================================== événements

local function addTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

local function showText(info: TextInfo)
	local v = view
	if not v or info.Text == "" then
		return
	end
	v.Alert.Text = info.Text
	v.Alert.TextColor3 = info.Color
	v.Alert.TextTransparency = 0
	v.Alert.Visible = true
	if v.AlertStroke then
		v.AlertStroke.Transparency = 0
	end
	textTime = math.max(info.Time, 0.1)
	textTimer = textTime
	idle = false
end

-- Alerte du gardien qui poursuit le joueur (remote GuardianAlert) : Roar, Run, Lost ou Catch ; raison de Lost :
-- Safe, Escaped (« ESCAPED! ») ou Dropped (rien : le bonk ou le piège a déjà secoué)
function StressController.Alert(state: string, reason: string?)
	if state == "Roar" then
		addTrauma(Stress.Shake.Roar)
		flash = math.max(flash, Stress.Flash.Roar)
		fovPunch = Stress.Fov.RoarPunch
		playOnce("Roar")
		playOnce("Stinger")
		showText(Stress.Texts.Run)
	elseif state == "Catch" then
		addTrauma(Stress.Shake.Catch)
		flash = math.max(flash, Stress.Flash.Catch)
		fovPunch = Stress.Fov.CatchPunch
		playOnce("Catch")
		showText(Stress.Texts.Caught)
		selfHitAt = clock
	elseif state == "Lost" and reason and ESCAPES[reason] then
		showText(Stress.Texts.Escaped)
	end
	idle = false
end

-- Le joueur est touché (remote Knocked) : Bonk (pelle) ou Trap (Bear Trap) ; la prise du gardien passe par Alert
function StressController.Hit(reason: string)
	if reason == "Bonk" then
		addTrauma(Stress.Shake.Bonk)
		flash = math.max(flash, Stress.Flash.Bonk)
		playOnce("Catch", 0.7)
	elseif reason == "Trap" then
		addTrauma(Stress.Shake.Trap)
		playOnce("Catch", 0.6)
	end
	selfHitAt = clock
	idle = false
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Effet chez tout le monde (remote PvpEffect) : secousse légère s'il a lieu tout près (mais pas sur soi)
function StressController.Nearby(position: Vector3)
	local root = rootOf(Players.LocalPlayer)
	if not root or clock - selfHitAt < SELF_WINDOW then
		return
	end
	local range = Stress.Shake.NearbyRange
	local distance = (position - root.Position).Magnitude
	if distance >= SELF_RADIUS and distance <= range then
		addTrauma(Stress.Shake.Nearby * (1 - distance / range))
		idle = false
	end
end

-- ===================================================================== image par image

local function guardianFor(zone: string): Model?
	local model = guardianModel
	if zone == guardianZone and model and model.Parent then
		return model
	end
	guardianZone, guardianModel = zone, nil
	for _, item in CollectionService:GetTagged("Guardian") do
		if item:IsA("Model") and item:GetAttribute("Guardian") == zone then
			guardianModel = item
			break
		end
	end
	return guardianModel
end

local function guardianPosition(model: Model): Vector3
	local root = model:FindFirstChild("Root")
	return if root and root:IsA("BasePart") then root.Position else model:GetPivot().Position
end

-- Ajoute `offset` au champ de vision de la caméra (en retirant celui de l'image précédente). Si un autre script l'a
-- changé entre-temps (zoom de sprint...), sa valeur devient la base : on ne la défait pas.
local function applyFov(camera: Camera?, offset: number)
	if camera ~= fovCamera then
		fovCamera, fovApplied = camera, 0
	end
	if not camera then
		return
	end
	if fovApplied ~= 0 and math.abs(camera.FieldOfView - fovWritten) > 0.01 then
		fovApplied = 0
	end
	if math.abs(offset - fovApplied) < 1e-3 then
		return
	end
	local base = camera.FieldOfView - fovApplied
	local value = math.clamp(base + offset, 1, 120)
	camera.FieldOfView = value
	fovWritten = camera.FieldOfView
	fovApplied = value - base
end

-- Au début de l'image (avant les commandes et la caméra de Roblox) : retire la secousse posée à l'image précédente
local function unshake()
	local camera = Workspace.CurrentCamera
	if shaking and camera and camera == shakeCamera then
		camera.CFrame = camera.CFrame * shakeApplied:Inverse()
	end
	shaking = false
	shakeApplied = CFrame.identity
end

local function neutral()
	local v = view
	if v then
		for _, edge in v.Edges do
			edge.BackgroundTransparency = 1
		end
		v.Flash.BackgroundTransparency = 1
		v.Alert.Visible = false
	end
	if grade then
		grade.Enabled = false
	end
	if heartbeat and heartbeat.Playing then
		heartbeat:Stop()
	end
	applyFov(Workspace.CurrentCamera, 0)
end

local function readReducedMotion()
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	reducedMotion = ok and value == true
end

local function updateText(v: View)
	if textTimer <= 0 then
		v.Alert.Visible = false
		return
	end
	local age = textTime - textTimer
	local fade = math.clamp(1 - textTimer / FADE_TIME, 0, 1)
	v.Alert.Visible = true
	v.Alert.TextTransparency = fade
	if v.AlertStroke then
		v.AlertStroke.Transparency = fade
	end
	v.AlertScale.Scale = 1 + 0.6 * math.max(0, 1 - age / POP_TIME)
	v.Alert.Rotation = if reducedMotion then 0 else math.noise(clock * 18, 3.3, 0.5) * 12 * (textTimer / textTime)
end

-- Une image : intensité, pas du gardien, puis vignette, couleurs, cœur, champ de vision, texte et secousse
function StressController.Step(dt: number)
	dt = math.clamp(dt, 0, MAX_DT)
	clock += dt
	if clock >= motionCheckAt then
		motionCheckAt = clock + MOTION_CHECK
		readReducedMotion()
	end
	local me = Players.LocalPlayer
	local carrying = me:GetAttribute("Carrying")
	local chasedBy = me:GetAttribute("ChasedBy")
	local zone = if type(chasedBy) == "string" then chasedBy else ""
	local guardian = if zone ~= "" then guardianFor(zone) else nil
	local root = rootOf(me)
	local distance: number? = nil
	if guardian and root then
		local offset = guardianPosition(guardian) - root.Position
		distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	end
	closeness = if zone ~= "" then StressController.Closeness(distance) else 0
	local target = StressController.Target(if type(carrying) == "string" then carrying else "", zone, distance)
	if target > intensity then
		intensity = math.min(target, intensity + Stress.Rise * dt)
	else
		intensity = math.max(target, intensity - Stress.Fall * dt)
	end
	local chased = if zone ~= "" then 1 else 0
	chaseMix += math.clamp(chased - chaseMix, -CHASE_BLEND * dt, CHASE_BLEND * dt)

	-- pas du gardien qui court vers le joueur : « BOUM », de plus en plus fort
	local hearing = Stress.Step.Hearing
	if guardian and distance and distance <= hearing and guardian:GetAttribute("State") == "Run" then
		stepTimer -= dt
		if stepTimer <= 0 then
			local speed = guardian:GetAttribute("Speed")
			stepTimer = StressController.StepInterval(if type(speed) == "number" then speed else 0)
			local near = 1 - math.clamp(distance / hearing, 0, 1)
			addTrauma(Stress.Shake.Step * near)
			playOnce("Step", 0.3 + 0.7 * near)
		end
	else
		stepTimer = 0
	end

	trauma = math.max(0, trauma - Stress.Shake.Decay * dt)
	flash = math.max(0, flash - Stress.Flash.Fade * dt)
	fovPunch *= math.exp(-Stress.Fov.PunchFade * dt)
	if math.abs(fovPunch) < 0.05 then
		fovPunch = 0
	end
	textTimer = math.max(0, textTimer - dt)

	local active = intensity > 1e-3 or trauma > 1e-3 or flash > 1e-3 or fovPunch ~= 0 or textTimer > 0 or chaseMix > 1e-3
	if not active then
		if not idle then
			idle = true
			neutral()
		end
		return
	end
	idle = false

	-- cœur : plus fort et plus rapide avec l'intensité (et qui s'éteint en douceur quand on se calme)
	local heart = Stress.Sounds.Heartbeat
	local level = math.clamp((intensity - 0.05) / 0.95, 0, 1)
	local speed = heart.MinSpeed + (heart.MaxSpeed - heart.MinSpeed) * level
	beatPhase = (beatPhase + dt * heart.Bpm / 60 * speed) % 1
	local beat = StressController.Pulse(beatPhase)
	if heartbeat then
		local fade = math.clamp(intensity / HEART_FADE, 0, 1)
		if fade > 0.01 then
			heartbeat.Volume = heart.Volume * (0.35 + 0.65 * level) * fade
			heartbeat.PlaybackSpeed = speed
			if not heartbeat.Playing then
				heartbeat:Play()
			end
		elseif heartbeat.Playing then
			heartbeat:Stop()
		end
	end

	-- vignette (sombre en portant un bloc, rouge poursuivi) qui bat avec le cœur, éclair rouge
	local cfg = Stress.Vignette
	local strength = cfg.Carry + (cfg.Chase - cfg.Carry) * chaseMix
	local alpha = math.clamp(intensity * (strength + cfg.Pulse * beat), 0, 0.95)
	local color = cfg.CarryColor:Lerp(cfg.ChaseColor, chaseMix)
	local v = view
	if v then
		for _, edge in v.Edges do
			edge.BackgroundTransparency = 1 - alpha
			edge.BackgroundColor3 = color
		end
		v.Flash.BackgroundTransparency = 1 - math.clamp(flash, 0, 1)
		updateText(v)
	end
	if grade then
		grade.Enabled = true
		grade.Saturation = Stress.Grade.Saturation * intensity
		grade.Contrast = Stress.Grade.Contrast * intensity
		grade.TintColor = WHITE:Lerp(Stress.Grade.Tint, intensity * chaseMix)
	end

	-- champ de vision : plus large poursuivi, coup de zoom au rugissement et à la prise
	local camera = Workspace.CurrentCamera
	local punch = if reducedMotion then 0 else fovPunch
	applyFov(camera, Stress.Fov.Chase * chaseMix * intensity + punch)

	-- secousse (retirée par unshake avant la caméra de Roblox à l'image suivante)
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		local amount = math.min(1, trauma + Stress.Shake.Chase * closeness)
		local offset = StressController.ShakeOffset(amount, clock, if reducedMotion then Stress.Shake.ReducedMotion else 1)
		if offset ~= CFrame.identity then
			camera.CFrame = camera.CFrame * offset
			shakeApplied, shakeCamera, shaking = offset, camera, true
		end
	end
end

-- ===================================================================== démarrage

local function buildView(): View
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- vignette et éclair : sous le HUD, sur tout l'écran
	local screen = Instance.new("ScreenGui")
	screen.Name = "Stress"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = -10
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local width = Stress.Vignette.Width
	local falloff = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	local edges: { Frame } = {}
	for _, side in {
		{ Name = "Left", Anchor = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(width, 1), Rotation = 0 },
		{ Name = "Right", Anchor = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(width, 1), Rotation = 180 },
		{ Name = "Top", Anchor = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, width), Rotation = 90 },
		{ Name = "Bottom", Anchor = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, width), Rotation = 270 },
	} do
		local edge = Instance.new("Frame")
		edge.Name = "Vignette" .. side.Name
		edge.AnchorPoint = side.Anchor
		edge.Position = side.Position
		edge.Size = side.Size
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = Stress.Vignette.CarryColor
		edge.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side.Rotation
		gradient.Transparency = falloff
		gradient.Parent = edge
		edge.Parent = screen
		table.insert(edges, edge)
	end
	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BorderSizePixel = 0
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 40, 30)
	flashFrame.BackgroundTransparency = 1
	flashFrame.Parent = screen
	screen.Parent = playerGui

	-- gros texte (RUN!!, CAUGHT!, ESCAPED!) au-dessus du HUD
	local _, root = UIKit.Root("StressText", 20)
	local alert = UIKit.label({
		Name = "Alert",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 160),
		Visible = false,
		Parent = root,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = alert
	return {
		Screen = screen,
		Edges = edges,
		Flash = flashFrame,
		Alert = alert,
		AlertScale = scale,
		AlertStroke = alert:FindFirstChildOfClass("UIStroke"),
	}
end

function StressController.Init()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "StressGrade"
	effect.Enabled = false
	effect.Parent = Lighting
	grade = effect

	local sounds = Stress.Sounds
	local folder = Instance.new("Folder")
	folder.Name = "StressSounds"
	folder.Parent = SoundService
	heartbeat = makeSound("Heartbeat", sounds.Heartbeat.Id, sounds.Heartbeat.Volume, 1, folder)
	if heartbeat then
		heartbeat.Looped = true
	end
	for _, name in { "Roar", "Stinger", "Step", "Catch" } do
		local info = (sounds :: any)[name]
		local sound = makeSound(name, info.Id, info.Volume, info.Speed, folder)
		if sound then
			templates[name] = sound
		end
	end

	Remotes.Event("GuardianAlert").OnClientEvent:Connect(function(zone: any, state: any, reason: any)
		if type(zone) == "string" and type(state) == "string" and ALERTS[state] then
			StressController.Alert(state, if type(reason) == "string" then reason else nil)
		end
	end)
	Remotes.Event("Knocked").OnClientEvent:Connect(function(_seconds: any, reason: any)
		if type(reason) == "string" then
			StressController.Hit(reason)
		end
	end)
	Remotes.Event("PvpEffect").OnClientEvent:Connect(function(_kind: any, position: any)
		if typeof(position) == "Vector3" and position.Magnitude < math.huge then
			StressController.Nearby(position)
		end
	end)
end

function StressController.Start()
	view = buildView()
	readReducedMotion()
	RunService:BindToRenderStep("StressUnshake", Enum.RenderPriority.First.Value, unshake)
	RunService:BindToRenderStep("Stress", Enum.RenderPriority.Camera.Value + 1, StressController.Step)
end

return StressController
