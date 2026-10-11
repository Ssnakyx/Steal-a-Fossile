--!strict
-- Trails (brief 4 « vitesse-treadmill ») : une seule trail portée à la fois, avec une traînée colorée qui suit le joueur.
-- Trails en argent (Config.Speed.Trails, de Common à Divine) : vitesse gratuite, achetée avec l'argent du jeu. Sa vitesse
-- s'ajoute à celle du joueur (SpeedService, bonus « Trail »). Une trail achetée est portée tout de suite si elle va plus
-- vite.
-- Trails Robux (Config.Speed.RobuxTrails) : un game pass chacune (Config.Shop.Passes). Portée, elle garde la vitesse de
-- la meilleure trail en argent du joueur et multiplie toute sa vitesse (SpeedService, multiplicateur « Trail »). Elle
-- est portée dès que son passe arrive (acheté en jeu ou trouvé chez Roblox) si elle vaut mieux que la trail portée ; si
-- le passe est retiré (remboursé), la meilleure trail en argent la remplace.
--   TrailService.Equipped(player)   clé de la trail portée ("" = aucune)
--   TrailService.Owns(player, clé)  le joueur a-t-il cette trail (en argent ou Robux) ?
--   TrailService.Buy(player, clé)   en argent : achète -> (ok, texte) ; Robux : propose le passe (remote BuyTrail)
--   TrailService.Equip(player, clé) porte une trail possédée, "" pour aucune -> (ok, texte) (remote EquipTrail)
-- Signaux : TrailBought(player, clé) (trail en argent achetée)
-- Replica : Trails ({ Owned = { [clé] = true } (en argent et Robux), Equipped = clé })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local MoneyService = require(script.Parent.MoneyService)
local ReplicaService = require(script.Parent.ReplicaService)
local ShopService = require(script.Parent.ShopService)
local SpeedService = require(script.Parent.SpeedService)

type Look = { Name: string, Colors: { Color3 }, LightEmission: number? }

local TrailService = {}

local TRAILS = SpeedConfig.Trails
local ROBUX = SpeedConfig.RobuxTrails
local TRAIL_NAME = "SAF_Trail"
local TOP_NAME = "SAF_TrailTop"
local BOTTOM_NAME = "SAF_TrailBottom"

local trailByPass: { [string]: string } = {}
for id, trail in ROBUX do
	trailByPass[trail.Pass] = id
end

local players: { [Player]: boolean } = {}
local connections: { [Player]: RBXScriptConnection } = {}

local function lookOf(id: string): Look?
	return TRAILS[id] or ROBUX[id]
end

-- Vitesse d'une trail en argent (0 pour "" ou une trail Robux)
local function speedOf(id: string): number
	local trail = TRAILS[id]
	return if trail then trail.Speed else 0
end

-- Multiplicateur d'une trail Robux (Multiplier de son passe), 1 sinon
local function multiplierOf(id: string): number
	local trail = ROBUX[id]
	local pass = if trail then Shop.Passes[trail.Pass] else nil
	return if pass then pass.Multiplier or 1 else 1
end

-- Meilleure trail en argent possédée et sa vitesse ("" et 0 si aucune)
local function bestMoneyTrail(data: { [string]: any }): (string, number)
	local best, speed = "", 0
	for id in data.Trails.Owned do
		local trail = TRAILS[id]
		if trail and trail.Speed > speed then
			best, speed = id, trail.Speed
		end
	end
	return best, speed
end

function TrailService.Owns(player: Player, id: string): boolean
	if type(id) ~= "string" then
		return false
	end
	if rawget(TRAILS, id) ~= nil then
		local data = DataService.Get(player)
		return data ~= nil and data.Trails.Owned[id] == true
	end
	local robux = rawget(ROBUX, id)
	return robux ~= nil and ShopService.HasPass(player, robux.Pass)
end

-- (une trail Robux portée dont le passe n'est pas, ou plus, au joueur ne compte pas)
function TrailService.Equipped(player: Player): string
	local data = DataService.Get(player)
	if not data then
		return ""
	end
	local id: string = data.Trails.Equipped
	return if id ~= "" and TrailService.Owns(player, id) then id else ""
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
	local trail = lookOf(TrailService.Equipped(player))
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
	effect.LightEmission = trail.LightEmission or look.LightEmission
	effect.FaceCamera = true
	effect.Parent = root
end

-- ===== état =====

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local owned = table.clone(data.Trails.Owned)
	for id, trail in ROBUX do
		if ShopService.HasPass(player, trail.Pass) then
			owned[id] = true
		end
	end
	ReplicaService.Set(player, "Trails", { Owned = owned, Equipped = TrailService.Equipped(player) })
end

-- Applique la trail portée : vitesse (bonus, et multiplicateur pour une trail Robux) et traînée
local function apply(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local id = TrailService.Equipped(player)
	if ROBUX[id] then
		local _, best = bestMoneyTrail(data)
		SpeedService.SetBonus(player, "Trail", best)
		SpeedService.SetMultiplier(player, "Trail", multiplierOf(id))
	else
		SpeedService.SetBonus(player, "Trail", speedOf(id))
		SpeedService.SetMultiplier(player, "Trail", nil)
	end
	attachVisual(player)
	publish(player)
end

function TrailService.Buy(player: Player, rawId: any): (boolean, string)
	local robuxId = Guard.Key(rawId, ROBUX)
	if robuxId then
		if not players[player] then
			return false, "Please wait..."
		end
		return ShopService.BuyPass(player, ROBUX[robuxId].Pass)
	end
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
	-- (une trail Robux portée garde déjà la vitesse de la meilleure trail en argent : on la laisse)
	local equipped = TrailService.Equipped(player)
	if not ROBUX[equipped] and trail.Speed > speedOf(equipped) then
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
	local id = Guard.Key(rawId, TRAILS) or Guard.Key(rawId, ROBUX)
	if not id then
		return false, "Unknown trail"
	end
	if not TrailService.Owns(player, id) then
		return false, "You don't own this trail"
	end
	data.Trails.Equipped = id
	apply(player)
	return true, (lookOf(id) :: Look).Name .. " equipped"
end

-- ===== passes des trails Robux =====

-- Passe reçu (acheté en jeu ou trouvé chez Roblox) : la trail est portée si elle vaut mieux que celle portée
local function onPassOwned(player: Player, passKey: string)
	local id = trailByPass[passKey]
	local data = if id then DataService.Get(player) else nil
	if not id or not data then
		return
	end
	local equipped = TrailService.Equipped(player)
	if not ROBUX[equipped] or multiplierOf(id) > multiplierOf(equipped) then
		data.Trails.Equipped = id
	end
	-- (avant OnPlayerReady, la trail est appliquée par OnPlayerReady)
	if players[player] then
		apply(player)
	end
end

-- Passe retiré (remboursé) : la meilleure trail en argent remplace la trail Robux portée
local function onPassLost(player: Player, passKey: string)
	local id = trailByPass[passKey]
	local data = if id then DataService.Get(player) else nil
	if not id or not data then
		return
	end
	if data.Trails.Equipped == id then
		data.Trails.Equipped = bestMoneyTrail(data)
	end
	if players[player] then
		apply(player)
	end
end

-- ===== cycle de vie =====

function TrailService.Init()
	Net.Function("BuyTrail", { Rate = 2, Burst = 4 }, TrailService.Buy)
	Net.Function("EquipTrail", { Rate = 2, Burst = 4 }, TrailService.Equip)
	Signals.Connect("PassOwned", onPassOwned)
	Signals.Connect("PassLost", onPassLost)
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
