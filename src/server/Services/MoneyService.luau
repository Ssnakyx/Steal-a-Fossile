--!strict
-- Argent du joueur (data.Money, brief 1) : tout l'argent du jeu passe par ici pour que le HUD, le classement et les
-- quêtes suivent.
--   MoneyService.Add(player, 120, "Income")
--   if MoneyService.Spend(player, 500, "Trail") then ... end
-- Un montant invalide (NaN, infini, négatif) est refusé. L'argent est plafonné à Config.Core.MaxMoney.
-- Signal MoneyChanged(player, delta, reason, total). Côté client : ReplicaController.Get("Money").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Config.Core)
local Format = require(ReplicatedStorage.Shared.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Leaderstats = require(script.Parent.Parent.Lib.Leaderstats)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local ReplicaService = require(script.Parent.ReplicaService)

local MoneyService = {}
MoneyService.Priority = -80

local function publish(player: Player, money: number)
	ReplicaService.Set(player, "Money", money)
	Leaderstats.Set(player, "Money", Format.Money(money))
end

function MoneyService.Get(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Money else 0
end

function MoneyService.CanAfford(player: Player, cost: number): boolean
	return Guard.IsFinite(cost) and cost >= 0 and MoneyService.Get(player) >= cost
end

-- Ajoute de l'argent gagné (compte aussi dans TotalEarned). Renvoie false si le montant est invalide ou le joueur pas chargé.
function MoneyService.Add(player: Player, amount: number, reason: string): boolean
	if not Guard.IsFinite(amount) or amount <= 0 then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local before: number = data.Money
	local total = math.min(before + amount, Core.MaxMoney)
	local delta = total - before
	data.Money = total
	data.TotalEarned = math.min(data.TotalEarned + delta, Core.MaxMoney)
	publish(player, total)
	if delta > 0 then
		Signals.Fire("MoneyChanged", player, delta, reason, total)
	end
	return true
end

-- Retire `cost` si le joueur l'a. Renvoie true si c'est payé.
function MoneyService.Spend(player: Player, cost: number, reason: string): boolean
	if not Guard.IsFinite(cost) or cost < 0 then
		return false
	end
	local data = DataService.Get(player)
	if not data or data.Money < cost then
		return false
	end
	local total = data.Money - cost
	data.Money = total
	publish(player, total)
	if cost > 0 then
		Signals.Fire("MoneyChanged", player, -cost, reason, total)
	end
	return true
end

-- Fixe l'argent (commandes d'admin et tests seulement : ne compte pas dans TotalEarned)
function MoneyService.Set(player: Player, amount: number, reason: string): boolean
	if not Guard.IsFinite(amount) or amount < 0 then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local before: number = data.Money
	local total = math.min(amount, Core.MaxMoney)
	data.Money = total
	publish(player, total)
	if total ~= before then
		Signals.Fire("MoneyChanged", player, total - before, reason, total)
	end
	return true
end

function MoneyService.OnPlayerReady(player: Player, data: { [string]: any })
	publish(player, data.Money)
end

return MoneyService
