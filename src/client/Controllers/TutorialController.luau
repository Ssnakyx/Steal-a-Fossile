--!strict
-- Guide des premières minutes d'un nouveau joueur (Snaky : « les 5 premières minutes sont extrêmement importantes »).
-- Une carte en bas de l'écran dit quoi faire, un rayon jaune part du joueur vers le but (avec une étiquette au-dessus) :
--   1. GRAB A FOSSIL     courir à la Beach, maintenir E sur un bloc       rayon vers le bloc de la Beach le plus proche
--   2. BRING IT HOME!    rentrer au parc avec le bloc sur le dos          rayon vers l'entrée du parc
--   3. REVIVING...       la première cuve tourne (10 s, Zones.Dig.TutorialReviveTime) : tour de roue gratuit en attendant
--   4. YOUR DINO IS READY!  ouvrir la cuve                                rayon vers la cuve
-- Puis, après le premier dino : son revenu (même hors ligne), le treadmill (vitesse gagnée même AFK, rayon vers le
-- tapis) et le but du jeu (aller plus loin). Le calendrier s'ouvre juste après le premier dino (RewardsController).
-- Le serveur tient l'étape (data.Tutorial, clé replica « Tutorial » : 0 nouveau, 1 bloc arraché, 2 bloc rentré,
-- 3 premier dino) ; un joueur qui arrive avec le tutoriel fini ne voit rien. Le client ne fait qu'afficher.
-- API : TutorialController.Step() -> étape affichée ou nil ({ Key, Title, Text, Number?, Target?, Marker? }),
-- TutorialController.IsActive(), TutorialController.Skip().
-- Le HUD du brief 12 peut reprendre la carte (« tutoriel fléché ») : les étapes viennent de Step().

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local ReplicaController = require(script.Parent.ReplicaController)

local TutorialController = {}

export type Step = {
	Key: string, -- Grab, Home, Revive, Open, FirstDino, Treadmill, Explore
	Title: string,
	Text: string,
	Number: number?, -- numéro d'étape affiché (1 à 4), nil après le premier dino
	Target: Vector3?, -- but du rayon
	Marker: string?, -- étiquette au-dessus du but
}

local REFRESH = 0.2 -- secondes entre deux mises à jour
local STEPS = 4
local FIRST_DINO_TIME = 7 -- secondes du message « premier dino »
local TREADMILL_TIME = 45 -- au plus, secondes de l'étape treadmill
local ON_BELT_TIME = 4 -- secondes sur le tapis pour finir l'étape treadmill
local EXPLORE_TIME = 10 -- secondes du dernier conseil
local CARD_SIZE = Vector2.new(600, 104)
local CARD_LIFT = 124 -- (au-dessus de la carte AFK du treadmill, en bas au milieu elle aussi)
local Colors = UIKit.Colors
local new = UIKit.new

type Ui = {
	Card: Frame,
	Pop: UIScale,
	Number: Frame,
	NumberText: TextLabel,
	Title: TextLabel,
	Text: TextLabel,
	Anchor: Part,
	Beam: Beam,
	Marker: BillboardGui,
	MarkerText: TextLabel,
	Distance: TextLabel,
	From: Attachment?,
}

local ui: Ui? = nil
local active = false -- tutoriel pas fini à l'arrivée
local finished = false
local firstDinoAt: number? = nil -- os.clock() du premier dino (pendant cette session)
local beltSince: number? = nil
local treadmillDoneAt: number? = nil
local shownKey: string? = nil

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function tutorialStep(): number
	return tonumber(ReplicaController.Get("Tutorial")) or 0
end

local function positionOf(inst: Instance?): Vector3?
	if inst and inst:IsA("BasePart") then
		return inst.Position
	elseif inst and inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function rootPosition(): Vector3?
	local player = Players.LocalPlayer
	local character = player and player.Character
	return positionOf(character and character:FindFirstChild("HumanoidRootPart"))
end

local function myPlot(): Instance?
	local index = tonumber(ReplicaController.Get("Plot")) or 0
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return if plots and index > 0 then plots:FindFirstChild("Plot" .. index) else nil
end

local function plotPart(name: string): Vector3?
	local plot = myPlot()
	return positionOf(plot and plot:FindFirstChild(name, true))
end

-- Bloc de la zone du tutoriel le plus proche du joueur (sinon le milieu de la zone)
local function nearestBlock(): (Vector3?, boolean)
	local from = rootPosition()
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, block in CollectionService:GetTagged("FossilBlock") do
		local position = positionOf(block)
		if position and block:GetAttribute("Zone") == Zones.Dig.TutorialZone and block:IsDescendantOf(Workspace) then
			local distance = if from then (position - from).Magnitude else 0
			if distance < bestDistance then
				best = position
				bestDistance = distance
			end
		end
	end
	if best then
		return best, true
	end
	local map = Workspace:FindFirstChild("Map")
	local zones = map and map:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(Zones.Dig.TutorialZone)
	return positionOf(zone and zone:FindFirstChild("Area")), false
end

-- Cuve du premier bloc : celle qui finit le plus tôt
local function firstTank(): (number?, number?)
	local tanks = ReplicaController.Get("Tanks")
	if type(tanks) ~= "table" then
		return nil, nil
	end
	local slot: number? = nil
	local endsAt: number? = nil
	for key, tank in tanks do
		local index = tonumber(key)
		if index and type(tank) == "table" and type(tank.EndsAt) == "number" and (endsAt == nil or tank.EndsAt < endsAt) then
			slot = index
			endsAt = tank.EndsAt
		end
	end
	return slot, endsAt
end

local function freeSpin(): boolean
	local spins = ReplicaController.Get("Spins")
	return type(spins) == "table" and (tonumber(spins.Free) or 0) > 0
end

local function onTreadmill(): boolean
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute("OnTreadmill") == true
end

-- Étape à afficher maintenant (nil : rien)
function TutorialController.Step(): Step?
	if not active or finished then
		return nil
	end
	local tutorial = tutorialStep()
	if tutorial < 3 then
		if ReplicaController.Get("Carrying") ~= nil then
			return {
				Key = "Home",
				Number = if tutorial < 2 then 2 else nil,
				Title = "BRING IT HOME!",
				Text = "Run back to your park. Inside, your fossil is safe!",
				Target = plotPart("Entrance") or plotPart("Spawn"),
				Marker = "HOME",
			}
		end
		if tutorial < 2 then
			local target, isBlock = nearestBlock()
			local hold = if UIKit.Touch then "hold the button" else "hold E"
			return {
				Key = "Grab",
				Number = 1,
				Title = "GRAB A FOSSIL",
				Text = "Run to the " .. Zones.Dig.TutorialZone .. ", then " .. hold .. " on a fossil block.",
				Target = target,
				Marker = if isBlock then "GRAB" else string.upper(Zones.Dig.TutorialZone),
			}
		end
		local slot, endsAt = firstTank()
		if slot and endsAt and endsAt <= serverNow() then
			return {
				Key = "Open",
				Number = 4,
				Title = "YOUR DINO IS READY!",
				Text = "Go to your tank and open it to meet your dino.",
				Target = plotPart("Tank" .. slot),
				Marker = "OPEN",
			}
		end
		local left = if endsAt then " " .. Format.Clock(math.ceil(endsAt - serverNow())) else ""
		return {
			Key = "Revive",
			Number = 3,
			Title = "REVIVING..." .. left,
			Text = if freeSpin() then "While you wait, spin the wheel for free! (Spin button)" else "While you wait, grab another fossil!",
		}
	end
	-- premier dino pendant cette session : revenu, treadmill, but du jeu
	local now = os.clock()
	local since = firstDinoAt or now
	if now - since < FIRST_DINO_TIME then
		local income = tonumber(ReplicaController.Get("Income")) or 0
		return {
			Key = "FirstDino",
			Title = "YOUR FIRST DINO!",
			Text = "It makes " .. Format.Rate(income) .. " for you, even when you're offline.",
		}
	end
	local belt = plotPart("Treadmill")
	if not treadmillDoneAt then
		local onBelt = onTreadmill()
		beltSince = if onBelt then beltSince or now else nil
		if not belt or now - since >= FIRST_DINO_TIME + TREADMILL_TIME or (beltSince and now - beltSince >= ON_BELT_TIME) then
			treadmillDoneAt = now
		else
			local rate = tonumber(ReplicaController.Get("TreadmillRate")) or (SpeedConfig.Treadmill.BaseGain * SpeedConfig.Treadmill.FreeMultiplier)
			return {
				Key = "Treadmill",
				Title = "GET FASTER",
				Text = "Stand on your treadmill: +" .. Format.Number(rate) .. " speed every second, even AFK!",
				Target = if onBelt then nil else belt,
				Marker = "TREADMILL",
			}
		end
	end
	if now - (treadmillDoneAt :: number) < EXPLORE_TIME then
		return {
			Key = "Explore",
			Title = "GO FURTHER",
			Text = "More speed = farther zones = rarer fossils. Fill your tanks and buy more!",
		}
	end
	finished = true
	return nil
end

function TutorialController.IsActive(): boolean
	return active and not finished
end

-- Cache le guide pour cette session
function TutorialController.Skip()
	finished = true
end

-- ===================================================================== affichage

local function build(): Ui
	local _, root = UIKit.Root("Tutorial", 6)
	local card = UIKit.card({
		Name = "TutorialCard",
		Color = Colors.Slate,
		Accent = Colors.Yellow,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		Visible = false,
		Parent = root,
	})
	local pop: UIScale = new("UIScale", { Parent = card })
	local z = card.ZIndex + 2
	local number = UIKit.card({
		Name = "Number",
		Color = Colors.Yellow,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		ZIndex = z,
		Parent = card,
	})
	local numberText = UIKit.label({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.62),
		Text = "",
		ZIndex = z + 4,
		Parent = number,
	})
	local title = UIKit.label({
		Name = "Title",
		Position = UDim2.fromOffset(96, 10),
		Size = UDim2.new(1, -112, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Yellow,
		Text = "",
		ZIndex = z,
		Parent = card,
	})
	local text = UIKit.label({
		Name = "Text",
		Position = UDim2.fromOffset(96, 52),
		Size = UDim2.new(1, -112, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Body = true,
		MaxTextSize = 22,
		Text = "",
		ZIndex = z,
		Parent = card,
	})

	-- Rayon et étiquette dans le monde (côté client seulement)
	local anchor: Part = new("Part", {
		Name = "TutorialTarget",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
	})
	local to: Attachment = new("Attachment", { Name = "To", Parent = anchor })
	local beam: Beam = new("Beam", {
		Name = "Guide",
		Attachment1 = to,
		Color = ColorSequence.new(Colors.Yellow),
		Transparency = NumberSequence.new(0.2),
		Width0 = 0.6,
		Width1 = 0.6,
		FaceCamera = true,
		LightEmission = 0.6,
		LightInfluence = 0,
		Segments = 1,
		Enabled = false,
		Parent = anchor,
	})
	local marker: BillboardGui = new("BillboardGui", {
		Name = "Marker",
		Size = UDim2.fromOffset(170, 66),
		StudsOffset = Vector3.new(0, 5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = anchor,
	})
	local markerText = UIKit.label({
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 38),
		TextColor3 = Colors.Yellow,
		Text = "",
		Parent = marker,
	})
	local distance = UIKit.label({
		Name = "Distance",
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Parent = marker,
	})
	anchor.Parent = Workspace
	return {
		Card = card,
		Pop = pop,
		Number = number,
		NumberText = numberText,
		Title = title,
		Text = text,
		Anchor = anchor,
		Beam = beam,
		Marker = marker,
		MarkerText = markerText,
		Distance = distance,
		From = nil,
	}
end

-- Point de départ du rayon : un Attachment dans le HumanoidRootPart (refait à chaque personnage)
local function fromAttachment(current: Ui): Attachment?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local from = current.From
	if from and from.Parent == root then
		return from
	end
	local created: Attachment = new("Attachment", { Name = "TutorialFrom", Parent = root })
	current.From = created
	current.Beam.Attachment0 = created
	return created
end

local function render()
	local current = ui
	if not current then
		return
	end
	local step = TutorialController.Step()
	-- (caché sous un menu ouvert : le calendrier s'ouvre juste après le premier dino)
	current.Card.Visible = step ~= nil and not UIKit.AnyPanelOpen()
	if not step then
		current.Beam.Enabled = false
		current.Marker.Enabled = false
		return
	end
	if step.Key ~= shownKey then
		shownKey = step.Key
		current.Pop.Scale = 0.85
		UIKit.tween(current.Pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	current.Card.Position = UDim2.new(0.5, 0, 1, if onTreadmill() then -CARD_LIFT else -16)
	current.Number.Visible = step.Number ~= nil
	current.NumberText.Text = if step.Number then tostring(step.Number) .. "/" .. STEPS else ""
	local left = if step.Number then 96 else 22
	current.Title.Position = UDim2.fromOffset(left, 10)
	current.Title.Size = UDim2.new(1, -left - 16, 0, 38)
	current.Text.Position = UDim2.fromOffset(left, 52)
	current.Text.Size = UDim2.new(1, -left - 16, 0, 40)
	current.Title.Text = step.Title
	current.Text.Text = step.Text

	local target = step.Target
	local from = rootPosition()
	if target then
		current.Anchor.CFrame = CFrame.new(target)
		current.Marker.Enabled = true
		current.MarkerText.Text = step.Marker or ""
		current.Distance.Text = if from then string.format("%d studs", math.floor((target - from).Magnitude + 0.5)) else ""
		current.Beam.Enabled = fromAttachment(current) ~= nil
	else
		current.Beam.Enabled = false
		current.Marker.Enabled = false
	end
end

function TutorialController.Init()
	ui = build()
	ReplicaController.Changed:Connect(function(key: string, value: any, old: any)
		if key == "Tutorial" and active and not firstDinoAt and tonumber(value) == 3 and (tonumber(old) or 0) < 3 then
			firstDinoAt = os.clock()
		end
	end)
end

function TutorialController.Start()
	if not ReplicaController.WaitReady(60) then
		return
	end
	active = tutorialStep() < 3
	if not active then
		render()
		return
	end
	while not finished do
		render()
		task.wait(REFRESH)
	end
	render()
end

return TutorialController
