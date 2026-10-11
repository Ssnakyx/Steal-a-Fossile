--!strict
-- Calendrier de récompenses quotidiennes (GDD, Rétention : 14 jours) : une récompense par jour (Config.Daily.Login),
-- prise d'un clic. Après le jour 14 on repart au jour 1, la série continue. Un jour manqué : retour au jour 1 et série à
-- 0 (Config.Daily.Login.ResetOnMiss). Un jour = Config.Daily.Day(os.time()) (00:00 UTC + ResetOffset).
--   DailyService.State(player)     -> état du calendrier (aussi dans le Replica « Daily »)
--   DailyService.Claim(player)     -> (ok, texte, jour)   (remote ClaimDaily)
--   DailyService.Today()           -> numéro du jour
-- Replica « Daily » = { Next (1..14, jour à prendre), CanClaim, Streak, Best, NextReset (os.time()), Days (14) }.
-- Signaux : NewDay(day) (le jour vient de changer, une fois pour tout le serveur), DailyClaimed(player, day, streak)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReplicaService = require(script.Parent.ReplicaService)
local RewardService = require(script.Parent.RewardService)

export type State = { Next: number, CanClaim: boolean, Streak: number, Best: number, NextReset: number, Days: number }

local DailyService = {}

local DAYS = #DailyConfig.Login.Days
local CHECK_INTERVAL = 5 -- secondes entre deux vérifications du changement de jour

local players: { [Player]: boolean } = {}
local currentDay = DailyConfig.Day(os.time())

function DailyService.Today(): number
	return DailyConfig.Day(os.time())
end

-- Le joueur a-t-il manqué au moins un jour depuis sa dernière récompense ?
local function missed(data: { [string]: any }, today: number): boolean
	local last: number = data.Daily.LastClaim
	return last > 0 and today - DailyConfig.Day(last) >= 2
end

function DailyService.State(player: Player): State?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local now = os.time()
	local today = DailyConfig.Day(now)
	local daily = data.Daily
	local lost = missed(data, today) and DailyConfig.Login.ResetOnMiss
	local canClaim = daily.LastClaim <= 0 or DailyConfig.Day(daily.LastClaim) < today
	local nextDay = if lost then 1 else (daily.Day % DAYS) + 1
	if not canClaim then
		-- (déjà pris aujourd'hui : le jour affiché est celui qu'on vient de prendre)
		nextDay = math.max(1, daily.Day)
	end
	return {
		Next = nextDay,
		CanClaim = canClaim,
		Streak = if lost then 0 else daily.Streak,
		Best = daily.Best,
		NextReset = DailyConfig.NextReset(now),
		Days = DAYS,
	}
end

local function publish(player: Player)
	local state = DailyService.State(player)
	if state then
		ReplicaService.Set(player, "Daily", state)
	end
end

function DailyService.Claim(player: Player): (boolean, string, number?)
	local data = DataService.Get(player)
	local state = DailyService.State(player)
	if not data or not state or not players[player] then
		return false, "Please wait...", nil
	end
	if not state.CanClaim then
		return false, "Come back tomorrow for your next reward!", nil
	end
	local day = state.Next
	local reward = DailyConfig.Login.Days[day]
	local daily = data.Daily
	local streak = state.Streak + 1
	-- (noté avant de donner : un deuxième appel ne peut pas reprendre le même jour)
	local before = { Day = daily.Day, LastClaim = daily.LastClaim, Streak = daily.Streak, Best = daily.Best }
	daily.Day = day
	daily.LastClaim = os.time()
	daily.Streak = streak
	daily.Best = math.max(daily.Best, streak)
	local ok, text = RewardService.Grant(player, reward, "Daily")
	if not ok then
		daily.Day = before.Day
		daily.LastClaim = before.LastClaim
		daily.Streak = before.Streak
		daily.Best = before.Best
		return false, text, nil
	end
	publish(player)
	Signals.Fire("DailyClaimed", player, day, streak)
	return true, string.format("Day %d: %s", day, text), day
end

-- Changement de jour : chaque joueur voit tout de suite sa nouvelle récompense
local function checkDay()
	local today = DailyService.Today()
	if today == currentDay then
		return
	end
	currentDay = today
	Signals.Fire("NewDay", today)
	for player in players do
		if player.Parent == Players then
			publish(player)
			local state = DailyService.State(player)
			if state and state.CanClaim then
				Notify.Send(player, "A new day! Your daily reward is ready.", "success")
			end
		end
	end
end

-- ===== cycle de vie =====

function DailyService.Init()
	Net.Function("ClaimDaily", { Rate = 1, Burst = 3 }, function(player: Player)
		return DailyService.Claim(player)
	end)

	AdminService.RegisterCommand("dailyreset", {
		Description = "Make today's daily reward, free spin and gifts claimable again (Studio only)",
		Usage = "dailyreset [player]",
		Run = function(player, args)
			if not RunService:IsStudio() then
				return false, "Studio only"
			end
			local target = AdminService.FindPlayer(player, args[1])
			local data = target and DataService.Get(target)
			if not target or not data then
				return false, "Player not found"
			end
			-- (la dernière récompense passe à hier : la série continue)
			if data.Daily.LastClaim > 0 then
				data.Daily.LastClaim = math.max(1, data.Daily.LastClaim - DailyConfig.DayLength)
			end
			data.Spins.FreeDay = 0
			data.Spins.FreeUsed = 0
			data.Gifts.Day = 0
			Signals.Fire("DailyReset", target)
			publish(target)
			return true, target.Name .. ": daily reward, free spin and gifts reset"
		end,
	})
end

function DailyService.Start()
	while true do
		task.wait(CHECK_INTERVAL)
		checkDay()
	end
end

function DailyService.OnPlayerReady(player: Player)
	players[player] = true
	publish(player)
end

function DailyService.OnPlayerRemoving(player: Player)
	players[player] = nil
end

-- (tests : vérifie le changement de jour tout de suite)
DailyService.CheckDay = checkDay
return DailyService
