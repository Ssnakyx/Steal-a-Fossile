--!strict
-- Donne les récompenses de Config.Daily (calendrier, roue de la chance, cadeaux de temps de jeu) : argent, vitesse,
-- tours de roue, Bear Traps, blocs fossiles (qui partent dans une cuve, l'espèce est tirée à la révélation).
--   RewardService.Grant(player, reward, "Daily")      -> (ok, texte, montant)
--   RewardService.Scale(player)                       -> { Income = $/s, Speed = vitesse gagnée } (bases des montants)
--   RewardService.RegisterKind("Spins", fn)           donne un genre de récompense ailleurs (SpinService : tours)
-- Une récompense impossible (cuves et réserve pleines, pièges au maximum) est remplacée par Config.Daily.Fallback.
-- Replica « RewardScale » ({ Income, Speed }, rafraîchi toutes les ScaleInterval secondes) : le client calcule les
-- montants affichés avec Config.Daily.Amount, comme le serveur.
-- Événement RewardGranted(source, texte, rareté du bloc ou nil) vers le client du joueur.
-- Signal : RewardGranted(player, source, reward, amount)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MoneyService = require(script.Parent.MoneyService)
local PvpService = require(script.Parent.PvpService)
local ReplicaService = require(script.Parent.ReplicaService)
local ReviveService = require(script.Parent.ReviveService)
local SpeedService = require(script.Parent.SpeedService)

type Reward = DailyConfig.Reward
type Scale = DailyConfig.Scale
export type Granter = (player: Player, amount: number, reward: Reward) -> boolean

local RewardService = {}
RewardService.Priority = -5 -- (avant les services qui donnent des récompenses à l'arrivée)

local SCALE_INTERVAL = 5 -- secondes entre deux mises à jour de RewardScale
local SCALE_CHANGE = 0.005 -- écart relatif à partir duquel RewardScale est renvoyé

local granters: { [string]: Granter } = {}
local published: { [Player]: Scale } = {}

local grantedRemote = Remotes.Event("RewardGranted")

function RewardService.RegisterKind(kind: string, granter: Granter)
	if type(kind) ~= "string" or kind == "" or type(granter) ~= "function" then
		error("RewardService.RegisterKind : genre ou fonction invalide", 2)
	end
	if granters[kind] then
		error("RewardService.RegisterKind : genre " .. kind .. " déjà enregistré", 2)
	end
	granters[kind] = granter
end

function RewardService.Scale(player: Player): Scale
	local data = DataService.Get(player)
	if not data then
		return { Income = 0, Speed = 0 }
	end
	local income = IncomeService.GetIncome(player)
	return {
		Income = if Guard.IsFinite(income) then math.max(0, income) else 0,
		Speed = if Guard.IsFinite(data.Speed) then math.max(0, data.Speed) else 0,
	}
end

local function changed(old: number, new: number): boolean
	if old == new then
		return false
	end
	return math.abs(new - old) > math.max(math.abs(old), 1) * SCALE_CHANGE
end

local function publishScale(player: Player, force: boolean?)
	if not DataService.Get(player) then
		return
	end
	local scale = RewardService.Scale(player)
	local old = published[player]
	if force or not old or changed(old.Income, scale.Income) or changed(old.Speed, scale.Speed) then
		published[player] = scale
		ReplicaService.Set(player, "RewardScale", scale)
	end
end

-- ===== genres de récompenses =====

granters.Money = function(player: Player, amount: number): boolean
	return MoneyService.Add(player, amount, "Reward")
end

granters.Speed = function(player: Player, amount: number): boolean
	return SpeedService.Add(player, amount, "Reward")
end

granters.BearTraps = function(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or type(data.BearTraps) ~= "number" then
		return false
	end
	return PvpService.GiveTraps(player, amount)
end

granters.Block = function(player: Player, _amount: number, reward: Reward): boolean
	if type(reward.Rarity) ~= "string" or not Rarity.Info[reward.Rarity] then
		return false
	end
	-- (zone vide : l'espèce sera tirée parmi toutes celles de cette rareté)
	return ReviveService.AddBlock(player, { Rarity = reward.Rarity, Zone = "" })
end

-- Donne une récompense de Config.Daily. Renvoie (ok, texte de la récompense donnée, montant).
function RewardService.Grant(player: Player, reward: Reward, source: string): (boolean, string, number)
	if not DataService.Get(player) or type(reward) ~= "table" then
		return false, "Please wait...", 0
	end
	local scale = RewardService.Scale(player)
	local given = reward
	local amount = DailyConfig.Amount(reward, scale)
	local granter = granters[reward.Kind]
	local ok = false
	if granter and amount > 0 then
		local success, result = pcall(granter, player, amount, reward)
		if not success then
			warn(string.format("[RewardService] %s pour %s : %s", reward.Kind, player.Name, tostring(result)))
		end
		ok = success and result == true
	end
	if not ok then
		-- (impossible à donner : l'argent de secours, qui passe toujours tant que le joueur est chargé)
		given = DailyConfig.Fallback
		amount = DailyConfig.Amount(given, scale)
		ok = granters.Money(player, amount, given)
	end
	if not ok then
		return false, "Please wait...", 0
	end
	local text = DailyConfig.Label(given, scale)
	grantedRemote:FireClient(player, source, text, if given.Kind == "Block" then given.Rarity else nil)
	Signals.Fire("RewardGranted", player, source, given, amount)
	publishScale(player)
	return true, text, amount
end

-- ===== cycle de vie =====

function RewardService.Start()
	while true do
		task.wait(SCALE_INTERVAL)
		for player in published do
			if player.Parent == Players then
				publishScale(player)
			end
		end
	end
end

function RewardService.OnPlayerReady(player: Player)
	publishScale(player, true)
end

function RewardService.OnPlayerRemoving(player: Player)
	published[player] = nil
end

return RewardService
