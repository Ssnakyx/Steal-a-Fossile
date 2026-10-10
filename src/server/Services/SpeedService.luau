--!strict
-- Vitesse du joueur (brief 4 « vitesse-treadmill ») : la stat principale du jeu.
-- Vitesse totale = data.Speed (gagnée pour de bon : treadmill, quêtes, récompenses) + bonus (trail portée).
-- WalkSpeed = Config.Speed.WalkSpeedFor(vitesse totale) x malus du bloc porté (CarryService.GetSpeedMultiplier,
-- brief 3) x effets temporaires (piège, gardien...). SpeedService est le seul à écrire Humanoid.WalkSpeed.
--   SpeedService.Get(player)                          vitesse totale (à comparer à la vitesse conseillée des zones)
--   SpeedService.Add(player, 50, "Quest")             vitesse gagnée pour de bon
--   SpeedService.SetBonus(player, "Trail", 1500)      bonus tant qu'il est posé (nil ou 0 l'enlève)
--   SpeedService.SetModifier(player, "BearTrap", 0, 3) multiplie le WalkSpeed pendant 3 s (nil l'enlève)
--   SpeedService.Refresh(player)                      recalcule le WalkSpeed tout de suite (sinon toutes les 0.2 s)
-- Signaux : SpeedChanged(player, delta, reason, total)  vitesse gagnée (total = vitesse totale)
-- Replica : Speed (vitesse totale), GroupRewardClaimed. Leaderstats : Speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Leaderstats = require(script.Parent.Parent.Lib.Leaderstats)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReplicaService = require(script.Parent.ReplicaService)

type Modifier = { Multiplier: number, Expires: number? }
type State = {
	Bonuses: { [string]: number },
	Modifiers: { [string]: Modifier },
	Claiming: boolean,
}

local SpeedService = {}
-- (avant les services du jeu : leurs OnPlayerReady peuvent poser des bonus)
SpeedService.Priority = -10

local states: { [Player]: State } = {}

-- ===== CarryService (brief 3), facultatif =====

local carry: { [string]: any }? = nil

-- Malus de vitesse du bloc porté : 1 sans bloc ou tant que CarryService n'existe pas
local function carryMultiplier(player: Player): number
	if not carry then
		local module = script.Parent:FindFirstChild("CarryService")
		if not (module and module:IsA("ModuleScript")) then
			return 1
		end
		local ok, result = pcall((require :: any), module)
		if not ok or type(result) ~= "table" then
			return 1
		end
		carry = result
	end
	local getter = (carry :: { [string]: any }).GetSpeedMultiplier
	if type(getter) ~= "function" then
		return 1
	end
	local ok, value = pcall(getter, player)
	if not ok or not Guard.IsFinite(value) then
		return 1
	end
	return math.clamp(value, 0, 10)
end

-- ===== calculs =====

function SpeedService.Get(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local total: number = data.Speed
	local state = states[player]
	if state then
		for _, bonus in state.Bonuses do
			total += bonus
		end
	end
	return math.min(total, SpeedConfig.Max)
end

-- Multiplicateur des effets temporaires en cours (les effets finis sont retirés)
local function modifierMultiplier(state: State): number
	local now = os.clock()
	local multiplier = 1
	for key, modifier in state.Modifiers do
		if modifier.Expires and modifier.Expires <= now then
			state.Modifiers[key] = nil
		else
			multiplier *= modifier.Multiplier
		end
	end
	return multiplier
end

-- WalkSpeed que doit avoir le joueur maintenant
function SpeedService.WalkSpeed(player: Player): number
	local state = states[player]
	local base = SpeedConfig.WalkSpeedFor(SpeedService.Get(player))
	local multiplier = carryMultiplier(player) * (if state then modifierMultiplier(state) else 1)
	return math.max(0, base * multiplier)
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function SpeedService.Refresh(player: Player)
	if not states[player] then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local target = SpeedService.WalkSpeed(player)
	if math.abs(humanoid.WalkSpeed - target) > 1e-3 then
		humanoid.WalkSpeed = target
	end
end

local function publish(player: Player)
	local total = SpeedService.Get(player)
	ReplicaService.Set(player, "Speed", total)
	Leaderstats.Set(player, "Speed", Format.Number(total))
	SpeedService.Refresh(player)
end

-- ===== changements =====

-- Ajoute de la vitesse pour de bon. Renvoie false si le montant est invalide ou le joueur pas chargé.
function SpeedService.Add(player: Player, amount: number, reason: string): boolean
	if not Guard.IsFinite(amount) or amount <= 0 then
		return false
	end
	local data = DataService.Get(player)
	if not data or not states[player] then
		return false
	end
	local before: number = data.Speed
	data.Speed = math.min(before + amount, SpeedConfig.Max)
	publish(player)
	local delta = data.Speed - before
	if delta > 0 then
		Signals.Fire("SpeedChanged", player, delta, reason, SpeedService.Get(player))
	end
	return true
end

-- Fixe la vitesse gagnée (commandes d'admin et tests seulement)
function SpeedService.Set(player: Player, amount: number): boolean
	if not Guard.IsFinite(amount) or amount < 0 then
		return false
	end
	local data = DataService.Get(player)
	if not data or not states[player] then
		return false
	end
	data.Speed = math.min(amount, SpeedConfig.Max)
	publish(player)
	return true
end

-- Bonus de vitesse tant qu'il est posé (trail portée...). nil ou 0 l'enlève.
function SpeedService.SetBonus(player: Player, key: string, amount: number?)
	local state = states[player]
	if not state or type(key) ~= "string" then
		return
	end
	if amount == nil or not Guard.IsFinite(amount) or amount == 0 then
		state.Bonuses[key] = nil
	else
		state.Bonuses[key] = math.max(0, amount)
	end
	publish(player)
end

function SpeedService.GetBonus(player: Player, key: string): number
	local state = states[player]
	return if state then state.Bonuses[key] or 0 else 0
end

-- Effet temporaire sur le WalkSpeed (0 = immobile, 0.5 = moitié moins vite). duration en secondes (nil = jusqu'à ce
-- qu'on l'enlève) ; multiplier nil l'enlève.
function SpeedService.SetModifier(player: Player, key: string, multiplier: number?, duration: number?)
	local state = states[player]
	if not state or type(key) ~= "string" then
		return
	end
	if multiplier == nil or not Guard.IsFinite(multiplier) then
		state.Modifiers[key] = nil
	else
		local expires = if duration ~= nil and Guard.IsFinite(duration) and duration > 0 then os.clock() + duration else nil
		state.Modifiers[key] = { Multiplier = math.clamp(multiplier, 0, 10), Expires = expires }
	end
	SpeedService.Refresh(player)
end

function SpeedService.HasModifier(player: Player, key: string): boolean
	local state = states[player]
	if not state then
		return false
	end
	local modifier = state.Modifiers[key]
	return modifier ~= nil and (modifier.Expires == nil or modifier.Expires > os.clock())
end

-- ===== récompense like + favori + groupe =====

local function claimGroupReward(player: Player): (boolean, string)
	local reward = SpeedConfig.GroupReward
	local data = DataService.Get(player)
	local state = states[player]
	if not data or not state then
		return false, "Please wait..."
	end
	if reward.GroupId == 0 then
		return false, "Coming soon!"
	end
	if data.GroupRewardClaimed then
		return false, "Already claimed"
	end
	if state.Claiming then
		return false, "Please wait..."
	end
	state.Claiming = true
	local ok, member = pcall(function()
		return player:IsInGroupAsync(reward.GroupId)
	end)
	state.Claiming = false
	-- (la réponse de Roblox a pu prendre du temps : le joueur est peut-être parti ou a déjà pris la récompense)
	data = DataService.Get(player)
	if not data or not states[player] or data.GroupRewardClaimed then
		return false, "Already claimed"
	end
	if not ok then
		return false, "Roblox did not answer, try again"
	end
	if not member then
		return false, "Join the group first!"
	end
	data.GroupRewardClaimed = true
	ReplicaService.Set(player, "GroupRewardClaimed", true)
	SpeedService.Add(player, reward.Speed, "GroupReward")
	Notify.Send(player, "+" .. Format.Number(reward.Speed) .. " Speed! Thanks for the support!", "success")
	return true, "Reward claimed"
end

-- ===== cycle de vie =====

function SpeedService.Init()
	Net.Function("ClaimGroupReward", { Rate = 0.5, Burst = 2 }, function(player: Player)
		return claimGroupReward(player)
	end)

	AdminService.RegisterCommand("speed", {
		Description = "Give speed (or set it with =)",
		Usage = "speed <amount | =amount> [player]",
		Run = function(player, args)
			local text = args[1] or ""
			local set = string.sub(text, 1, 1) == "="
			local amount = tonumber(if set then string.sub(text, 2) else text)
			local target = AdminService.FindPlayer(player, args[2])
			if not target then
				return false, "Player not found"
			end
			if amount == nil or not Guard.Number(amount, 0, SpeedConfig.Max) then
				return false, "Amount between 0 and " .. Format.Number(SpeedConfig.Max)
			end
			local ok = if set then SpeedService.Set(target, amount) else SpeedService.Add(target, amount, "Admin")
			if not ok then
				return false, "Player not loaded"
			end
			return true, string.format("%s now has %s speed", target.Name, Format.Number(SpeedService.Get(target)))
		end,
	})
end

function SpeedService.Start()
	-- (un seul fil pour tout le serveur : le bloc porté et les effets qui finissent se voient en moins de 0.2 s)
	while true do
		task.wait(SpeedConfig.RefreshInterval)
		for player in states do
			if player.Parent == Players then
				SpeedService.Refresh(player)
			end
		end
	end
end

function SpeedService.OnPlayerReady(player: Player, data: { [string]: any })
	states[player] = { Bonuses = {}, Modifiers = {}, Claiming = false }
	ReplicaService.Set(player, "GroupRewardClaimed", data.GroupRewardClaimed)
	publish(player)
	player.CharacterAdded:Connect(function()
		-- (le Humanoid arrive parfois un peu après le Model : Refresh repasse toutes les 0.2 s de toute façon)
		SpeedService.Refresh(player)
	end)
end

function SpeedService.OnPlayerRemoving(player: Player)
	states[player] = nil
end

return SpeedService
