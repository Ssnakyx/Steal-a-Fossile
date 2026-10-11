--!strict
-- Côté client des gardiens et du vol (brief 7 « gardiens-vol ») :
--   * outils : la pelle (« Shovel ») envoie Bonk avec le porteur le plus proche à portée (une proposition : le serveur
--     vérifie tout), le piège (« Bear Trap ») envoie PlaceTrap ;
--   * chute cartoon (remote Knocked) : le personnage tombe (PlatformStand) puis se relève ; un piège bloque sans faire
--     tomber (le serveur met déjà la vitesse à 0) ;
--   * bloc au sol lâché par soi-même : son prompt « Pick up » est caché pendant les 3 s où on ne peut pas le reprendre.
-- L'alerte gardien du HUD, l'écran « RUN!! » et les effets (étoiles du bonk, piège qui se ferme) sont faits par les
-- briefs 11 et 12 avec les remotes GuardianAlert et PvpEffect, l'attribut joueur ChasedBy et les modèles tagués
-- « Guardian », « BearTrap » et « DroppedFossil ».

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pvp = require(ReplicatedStorage.Shared.Config.Pvp)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PvpController = {}

local MAX_KNOCK = 10 -- secondes au plus (valeur venue du serveur)
local TIP_SPIN = 6 -- vitesse de rotation donnée pour basculer (rad/s)

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local knockToken = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Porteur le plus proche à portée de pelle (nil sinon)
function PvpController.BonkTarget(): Player?
	local me = Players.LocalPlayer
	local root = rootOf(me)
	if not root then
		return nil
	end
	local best: Player? = nil
	local bestDistance = Pvp.Shovel.Range
	for _, other in Players:GetPlayers() do
		local carrying = other:GetAttribute("Carrying")
		local otherRoot = rootOf(other)
		if other ~= me and type(carrying) == "string" and carrying ~= "" and otherRoot then
			local offset = otherRoot.Position - root.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or hooked[tool] then
		return
	end
	if tool.Name == Pvp.Shovel.ToolName then
		hooked[tool] = true
		tool.Activated:Connect(function()
			Remotes.Event("Bonk"):FireServer(PvpController.BonkTarget())
		end)
	elseif tool.Name == Pvp.Trap.ToolName then
		hooked[tool] = true
		tool.Activated:Connect(function()
			Remotes.Event("PlaceTrap"):FireServer()
		end)
	end
end

-- Outils dans un sac ou dans le personnage (ils passent de l'un à l'autre quand on les prend en main)
local function watchTools(container: Instance)
	for _, child in container:GetChildren() do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

-- Fait tomber le personnage `seconds` secondes (Bonk, Catch) ; un piège (Trap) le bloque sans le faire tomber
function PvpController.Knock(seconds: number, reason: string)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(Players.LocalPlayer)
	if not humanoid or reason == "Trap" then
		return
	end
	knockToken += 1
	local token = knockToken
	humanoid.PlatformStand = true
	if root then
		root.AssemblyAngularVelocity = root.CFrame.RightVector * TIP_SPIN
	end
	task.delay(seconds, function()
		if knockToken == token and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Bloc au sol qu'on vient de lâcher : prompt caché tant qu'on ne peut pas le reprendre
local function onDropped(instance: Instance)
	if not instance:IsA("BasePart") or instance:GetAttribute("DroppedBy") ~= Players.LocalPlayer.UserId then
		return
	end
	task.spawn(function()
		local prompt = instance:WaitForChild("PickUpPrompt", 5)
		local lockedUntil = instance:GetAttribute("LockedUntil")
		if not (prompt and prompt:IsA("ProximityPrompt")) or type(lockedUntil) ~= "number" then
			return
		end
		local left = lockedUntil - Workspace:GetServerTimeNow()
		if left > 0 then
			prompt.Enabled = false
			task.delay(math.min(left, Pvp.Dropped.LockTime), function()
				prompt.Enabled = true
			end)
		end
	end)
end

function PvpController.Init()
	Remotes.Event("Knocked").OnClientEvent:Connect(function(seconds: any, reason: any)
		if type(seconds) == "number" and seconds == seconds and seconds > 0 then
			PvpController.Knock(math.min(seconds, MAX_KNOCK), if type(reason) == "string" then reason else "")
		end
	end)
	for _, instance in CollectionService:GetTagged("DroppedFossil") do
		onDropped(instance)
	end
	CollectionService:GetInstanceAddedSignal("DroppedFossil"):Connect(onDropped)
end

function PvpController.Start()
	local me = Players.LocalPlayer
	for _, child in me:GetChildren() do
		if child:IsA("Backpack") then
			watchTools(child)
		end
	end
	me.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchTools(child)
		end
	end)
	if me.Character then
		watchTools(me.Character)
	end
	me.CharacterAdded:Connect(watchTools)
end

return PvpController
