--!strict
-- Course sur le treadmill, côté client :
--   * le joueur qui reste immobile (Config.Speed.Treadmill.Run.StillSeconds) sur un tapis où il gagne de la vitesse (le
--     sien, ou un tapis sans propriétaire : même règle que TreadmillService) monte dessus : il est posé au milieu du
--     tapis, tourné vers la console, et court sur place (animation de course de son personnage, priorité Action, par-
--     dessus l'idle du script Animate ; elle se voit chez les autres joueurs). Les bandes du tapis défilent.
--   * il descend dès qu'il bouge, saute ou quitte le tapis, et ne remonte pas avant Run.Cooldown secondes.
--   * à chaque gain de vitesse sur le tapis (Replica Speed qui monte pendant la course, ou attribut OnTreadmill posé par
--     le serveur), une petite chaussure « 👟 +N » sort à côté de lui, monte et s'efface (N = le vrai gain).
-- Le serveur compte la vitesse tout seul (joueur au-dessus du tapis) : ici, ce n'est que de l'affichage.
--   TreadmillController.IsRunning() -> boolean
--   TreadmillController.Track() -> AnimationTrack?   animation de course en cours
--   TreadmillController.Update(dt)          un pas de la boucle (Heartbeat), appelé aussi par les tests
--   TreadmillController.Pop(gain)           une chaussure « +gain »

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local ReplicaController = require(script.Parent.ReplicaController)

local TreadmillController = {}

local CFG = SpeedConfig.Treadmill
local RUN = CFG.Run
-- animation de course de Roblox quand le personnage n'a pas de script Animate (R15, R6)
local RUN_R15 = "rbxassetid://913376220"
local RUN_R6 = "rbxassetid://180426354"
local SEARCH_EVERY = 0.15 -- secondes entre deux recherches du tapis sous le joueur (pas monté)

type Stripe = { Part: BasePart, Z: number }

local belt: BasePart? = nil -- tapis sur lequel le joueur court
local track: AnimationTrack? = nil -- animation de course qui joue
local loaded: AnimationTrack? = nil -- chargée une fois par personnage (Roblox limite les animations chargées)
local loadedFor: Animator? = nil
local stripes: { Stripe } = {}
local stripeModel: Instance? = nil
local scroll = 0
local stillFor = 0
local searchIn = 0
local lastDismount = -math.huge
local clock = 0
local pops = 0
local popSide = 1

local function character(): (Model?, Humanoid?, BasePart?)
	local player = Players.LocalPlayer
	local model = player and player.Character
	if not model then
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not (root and root:IsA("BasePart")) then
		return model, nil, nil
	end
	return model, humanoid, root
end

-- Propriétaire du tapis : attribut OwnerUserId de la pièce ou d'un ancêtre (nil = tapis libre)
local function ownerOf(part: Instance): number?
	local current: Instance? = part
	while current and current ~= Workspace do
		local value = current:GetAttribute(CFG.OwnerAttribute)
		if type(value) == "number" then
			return value
		end
		current = current.Parent
	end
	return nil
end

local function isOn(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Z) <= half.Z and relative.Y >= -half.Y and relative.Y <= half.Y + CFG.Height
end

local function findBelt(position: Vector3): BasePart?
	local player = Players.LocalPlayer
	for _, part in CollectionService:GetTagged(CFG.Tag) do
		if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
			local owner = ownerOf(part)
			if (owner == nil or (player and owner == player.UserId)) and isOn(part, position) then
				return part
			end
		end
	end
	return nil
end

-- ===================================================================== bandes du tapis

-- Bandes du modèle posé autour du tapis (Map/Treadmills), avec leur place le long du tapis
local function findStripes(part: BasePart)
	local parent = part.Parent
	local model = parent and parent:FindFirstChild(CFG.ModelName)
	if model == stripeModel and model ~= nil then
		return
	end
	stripeModel = model
	table.clear(stripes)
	if not model then
		return
	end
	for _, child in model:GetChildren() do
		if child.Name == CFG.StripeName and child:IsA("BasePart") then
			table.insert(stripes, { Part = child, Z = part.CFrame:PointToObjectSpace(child.Position).Z })
		end
	end
end

-- Les bandes glissent vers l'arrière du tapis (-Z) et reviennent devant : 5 bandes sur toute la longueur
local function scrollStripes(part: BasePart, dt: number)
	findStripes(part)
	if #stripes == 0 then
		return
	end
	local length = part.Size.Z
	scroll = (scroll + RUN.StripeSpeed * dt) % length
	local top = part.Size.Y / 2
	for _, stripe in stripes do
		if stripe.Part.Parent == nil then
			stripeModel = nil -- (modèle refait par le serveur : nouvelles bandes au prochain pas)
			return
		end
		local z = (stripe.Z - scroll + length / 2) % length - length / 2
		stripe.Part.CFrame = part.CFrame * CFrame.new(0, top + stripe.Part.Size.Y / 2 - 0.01, z)
	end
end

-- ===================================================================== monter, courir, descendre

local function runAnimation(model: Model, humanoid: Humanoid): Animation
	local animate = model:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local found = run and run:FindFirstChildOfClass("Animation")
	if found then
		return found
	end
	local animation = Instance.new("Animation")
	animation.Name = "TreadmillRun"
	animation.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15 then RUN_R15 else RUN_R6
	return animation
end

local function mount(part: BasePart, model: Model, humanoid: Humanoid, root: BasePart)
	belt = part
	scroll = 0
	-- au milieu du tapis, pieds sur la bande, tourné vers la console (+Z du tapis)
	local stand = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
	local position = (part.CFrame * CFrame.new(0, part.Size.Y / 2 + stand, 0)).Position
	local forward = part.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
	-- (la racine entraîne tout le personnage par ses articulations)
	root.CFrame = CFrame.lookAt(position, position + forward)
	root.AssemblyLinearVelocity = Vector3.zero
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		if loadedFor ~= animator or not loaded then
			local run = animator:LoadAnimation(runAnimation(model, humanoid))
			run.Priority = Enum.AnimationPriority.Action
			run.Looped = true
			loaded = run
			loadedFor = animator
		end
		local run = loaded :: AnimationTrack
		run:Play(0.15)
		run:AdjustSpeed(RUN.AnimSpeed)
		track = run
	end
end

local function dismount()
	if not belt then
		return
	end
	belt = nil
	lastDismount = clock
	stillFor = 0
	local current = track
	track = nil
	if current then
		current:Stop(0.2)
	end
end

function TreadmillController.IsRunning(): boolean
	return belt ~= nil
end

function TreadmillController.Track(): AnimationTrack?
	return track
end

function TreadmillController.Update(dt: number)
	clock += dt
	local model, humanoid, root = character()
	if not (model and humanoid and root) or humanoid.Health <= 0 then
		dismount()
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump
	local current = belt
	if current then
		if moving or current.Parent == nil or not isOn(current, root.Position) then
			dismount()
			return
		end
		scrollStripes(current, dt)
		return
	end
	if moving or clock - lastDismount < RUN.Cooldown then
		stillFor = 0
		return
	end
	stillFor += dt
	searchIn -= dt
	if stillFor < RUN.StillSeconds or searchIn > 0 then
		return
	end
	searchIn = SEARCH_EVERY
	local part = findBelt(root.Position)
	if part then
		mount(part, model, humanoid, root)
	end
end

-- ===================================================================== chaussures « +N »

function TreadmillController.Pop(gain: number)
	local _, _, root = character()
	local player = Players.LocalPlayer
	if not root or not player or pops >= RUN.MaxPops or gain <= 0 then
		return
	end
	pops += 1
	popSide = -popSide
	local gui = Instance.new("BillboardGui")
	gui.Name = "TreadmillPop"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(150, 46)
	local start = Vector3.new(popSide * (2.6 + math.random() * 0.6), 0.6 + math.random() * 0.8, 0)
	gui.StudsOffset = start
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = UIKit.TitleFont
	label.TextScaled = true
	label.Text = "👟 +" .. Format.Number(gain)
	label.TextColor3 = UIKit.Colors.GreenText
	label.TextStrokeColor3 = Color3.fromRGB(20, 40, 20)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = label
	gui.Parent = player:FindFirstChildOfClass("PlayerGui") or root
	local seconds = RUN.PopSeconds
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- (monte, puis s'efface sur la seconde moitié ; partie avant d'être détruite)
	TweenService:Create(gui, TweenInfo.new(seconds * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = start + Vector3.new(0, 2.6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(seconds * 0.45, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, seconds * 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(seconds, function()
		pops -= 1
		gui:Destroy()
	end)
end

local function onTreadmill(): boolean
	local player = Players.LocalPlayer
	return belt ~= nil or (player ~= nil and player:GetAttribute("OnTreadmill") == true)
end

function TreadmillController.Init()
	ReplicaController.Changed:Connect(function(key: string, value: any, old: any)
		if key == "Speed" and type(value) == "number" and type(old) == "number" and value > old and onTreadmill() then
			TreadmillController.Pop(value - old)
		end
	end)
	UserInputService.JumpRequest:Connect(dismount)
	local player = Players.LocalPlayer
	if player then
		player.CharacterAdded:Connect(function()
			dismount()
			lastDismount = -math.huge
			loaded = nil
			loadedFor = nil
		end)
	end
end

function TreadmillController.Start()
	RunService.Heartbeat:Connect(TreadmillController.Update)
end

return TreadmillController
