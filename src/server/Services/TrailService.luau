--!strict
-- Trails (brief 4 « vitesse-treadmill ») : vitesse gratuite, achetée avec l'argent du jeu (Config.Speed.Trails, de
-- Common à Divine). Une seule trail portée à la fois : sa vitesse s'ajoute à celle du joueur (SpeedService, bonus
-- « Trail ») et une traînée colorée le suit. Une trail achetée est portée tout de suite si elle va plus vite.
--   TrailService.Equipped(player)   clé de la trail portée ("" = aucune)
--   TrailService.Buy(player, clé)   achète avec l'argent du jeu -> (ok, texte) (remote BuyTrail)
--   TrailService.Equip(player, clé) porte une trail possédée, "" pour aucune -> (ok, texte) (remote EquipTrail)
-- Signaux : TrailBought(player, clé)
-- Replica : Trails ({ Owned = { [clé] = true }, Equipped = clé })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local MoneyService = require(script.Parent.MoneyService)
local ReplicaService = require(script.Parent.ReplicaService)
local SpeedService = require(script.Parent.SpeedService)

local TrailService = {}

local TRAILS = SpeedConfig.Trails
local TRAIL_NAME = "SAF_Trail"
local TOP_NAME = "SAF_TrailTop"
local BOTTOM_NAME = "SAF_TrailBottom"

local players: { [Player]: boolean } = {}
local connections: { [Player]: RBXScriptConnection } = {}

function TrailService.Equipped(player: Player): string
	local data = DataService.Get(player)
	return if data then data.Trails.Equipped else ""
end

local function speedOf(id: string): number
	local trail = TRAILS[id]
	return if trail then trail.Speed else 0
end

-- ===== traînée visible =====

local function clearVisual(root: BasePart)
	for _, name in { TRAIL_NAME, TOP_NAME, BOTTOM_NAME } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

local function attachVisual(player: Player)
	local root = Guard.Root(player)
	if not root then
		return
	end
	clearVisual(root)
	local trail = TRAILS[TrailService.Equipped(player)]
	if not trail then
		return
	end
	local look = SpeedConfig.TrailLook
	local top = Instance.new("Attachment")
	top.Name = TOP_NAME
	top.Position = Vector3.new(0, look.Height / 2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = BOTTOM_NAME
	bottom.Position = Vector3.new(0, -look.Height / 2, 0)
	bottom.Parent = root
	local effect = Instance.new("Trail")
	effect.Name = TRAIL_NAME
	effect.Attachment0 = top
	effect.Attachment1 = bottom
	effect.Color = ColorSequence.new(trail.Colors[1], trail.Colors[2] or trail.Colors[1])
	effect.Transparency = NumberSequence.new(0.15, 1)
	effect.WidthScale = NumberSequence.new(1, 0.3)
	effect.Lifetime = look.Lifetime
	effect.LightEmission = look.LightEmission
	effect.FaceCamera = true
	effect.Parent = root
end

-- ===== état =====

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ReplicaService.Set(player, "Trails", { Owned = table.clone(data.Trails.Owned), Equipped = data.Trails.Equipped })
end

-- Applique la trail portée : bonus de vitesse et traînée
local function apply(player: Player)
	SpeedService.SetBonus(player, "Trail", speedOf(TrailService.Equipped(player)))
	attachVisual(player)
	publish(player)
end

function TrailService.Buy(player: Player, rawId: any): (boolean, string)
	local id = Guard.Key(rawId, TRAILS)
	if not id then
		return false, "Unknown trail"
	end
	local data = DataService.Get(player)
	if not data or not players[player] then
		return false, "Please wait..."
	end
	if data.Trails.Owned[id] then
		return false, "Already owned"
	end
	local trail = TRAILS[id]
	if not MoneyService.Spend(player, trail.Price, "Trail") then
		return false, "Not enough money!"
	end
	data.Trails.Owned[id] = true
	if trail.Speed > speedOf(data.Trails.Equipped) then
		data.Trails.Equipped = id
	end
	apply(player)
	Signals.Fire("TrailBought", player, id)
	Notify.Send(player, trail.Name .. " bought!", "success")
	return true, trail.Name .. " bought!"
end

function TrailService.Equip(player: Player, rawId: any): (boolean, string)
	local data = DataService.Get(player)
	if not data or not players[player] then
		return false, "Please wait..."
	end
	if rawId == "" then
		data.Trails.Equipped = ""
		apply(player)
		return true, "Trail removed"
	end
	local id = Guard.Key(rawId, TRAILS)
	if not id then
		return false, "Unknown trail"
	end
	if not data.Trails.Owned[id] then
		return false, "You don't own this trail"
	end
	data.Trails.Equipped = id
	apply(player)
	return true, TRAILS[id].Name .. " equipped"
end

-- ===== cycle de vie =====

function TrailService.Init()
	Net.Function("BuyTrail", { Rate = 2, Burst = 4 }, TrailService.Buy)
	Net.Function("EquipTrail", { Rate = 2, Burst = 4 }, TrailService.Equip)
end

function TrailService.OnPlayerReady(player: Player)
	players[player] = true
	apply(player)
	connections[player] = player.CharacterAdded:Connect(function(character: Model)
		-- (la pièce centrale arrive parfois juste après le Model)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if players[player] and player.Character == character then
				attachVisual(player)
			end
		end)
	end)
end

function TrailService.OnPlayerRemoving(player: Player)
	players[player] = nil
	local connection = connections[player]
	if connection then
		connection:Disconnect()
		connections[player] = nil
	end
end

return TrailService
