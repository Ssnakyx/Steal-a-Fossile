--!strict
-- Cadeaux de temps de jeu (Config.Daily.Gifts) : le temps passé en jeu dans la journée (AFK compris) débloque des
-- cadeaux, ouverts d'un clic. Tout repart de zéro chaque jour (Config.Daily.Day) ; un cadeau prêt mais pas ouvert
-- à la fin du jour est donné tout seul. Le temps est compté par le serveur et sauvegardé (une reconnexion ne le perd
-- pas et ne le remet pas à zéro).
--   GiftService.Claim(player, numéro)   -> (ok, texte)   (remote ClaimGift)
--   GiftService.Seconds(player)         -> temps de jeu du jour (secondes)
-- Replica « Gifts » = { Seconds, At (os.time() de Seconds), Claimed = { numéros }, NextReset (os.time()) } : le client
-- ajoute le temps écoulé depuis At.
-- Signal : GiftClaimed(player, numéro)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Format = require(ReplicatedStorage.Shared.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReplicaService = require(script.Parent.ReplicaService)
local RewardService = require(script.Parent.RewardService)

local GiftService = {}

local GIFTS = DailyConfig.Gifts
local TICK = 1 -- secondes entre deux comptes du temps de jeu
local MAX_STEP = 5 -- secondes comptées au plus d'un coup (serveur qui a ramé)
local REPUBLISH = 60 -- secondes entre deux renvois du temps (le client dérive un peu)

-- joueurs suivis : os.clock() du dernier compte
local counted: { [Player]: number } = {}
local lastPublish: { [Player]: number } = {}

local function readyAt(index: number): number
	return GIFTS[index].Minutes * 60
end

function GiftService.Seconds(player: Player): number
	local data = DataService.Get(player)
	if not data or data.Gifts.Day ~= DailyConfig.Day(os.time()) then
		return 0
	end
	return data.Gifts.Seconds
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data or not counted[player] then
		return
	end
	local now = os.time()
	local today = DailyConfig.Day(now)
	local claimed = {}
	if data.Gifts.Day == today then
		for index in GIFTS do
			if data.Gifts.Claimed[tostring(index)] then
				table.insert(claimed, index)
			end
		end
	end
	lastPublish[player] = os.clock()
	ReplicaService.Set(player, "Gifts", {
		Seconds = if data.Gifts.Day == today then data.Gifts.Seconds else 0,
		At = now,
		Claimed = claimed,
		NextReset = DailyConfig.NextReset(now),
	})
end

-- Nouveau jour pour ce joueur : les cadeaux prêts et pas ouverts sont donnés, puis tout repart de zéro
local function rollover(player: Player, data: { [string]: any }, today: number)
	local gifts = data.Gifts
	if gifts.Day == today then
		return
	end
	local pending = {}
	if gifts.Day ~= 0 then
		for index, gift in GIFTS do
			if not gifts.Claimed[tostring(index)] and gifts.Seconds >= readyAt(index) then
				table.insert(pending, gift.Reward)
			end
		end
	end
	gifts.Day = today
	gifts.Seconds = 0
	gifts.Claimed = {}
	for _, reward in pending do
		RewardService.Grant(player, reward, "Gift")
	end
	if #pending > 0 then
		Notify.Send(player, "Yesterday's unopened gifts were added to your stuff!", "success")
	end
	publish(player)
end

-- Ajoute du temps de jeu ; prévient le joueur quand un cadeau devient prêt
local function addTime(player: Player, data: { [string]: any }, seconds: number)
	local gifts = data.Gifts
	local before: number = gifts.Seconds
	gifts.Seconds = math.min(before + seconds, DailyConfig.DayLength)
	local ready = 0
	for index in GIFTS do
		local at = readyAt(index)
		if before < at and gifts.Seconds >= at and not gifts.Claimed[tostring(index)] then
			ready += 1
		end
	end
	if ready > 0 then
		Notify.Send(player, "A free gift is ready! Open Gifts to claim it.", "success")
		publish(player)
	end
end

function GiftService.Tick()
	local clock = os.clock()
	local today = DailyConfig.Day(os.time())
	for player, last in counted do
		if player.Parent ~= Players then
			continue
		end
		local data = DataService.Get(player)
		if not data then
			continue
		end
		counted[player] = clock
		rollover(player, data, today)
		addTime(player, data, math.clamp(clock - last, 0, MAX_STEP))
		if clock - (lastPublish[player] or 0) >= REPUBLISH then
			publish(player)
		end
	end
end

function GiftService.Claim(player: Player, rawIndex: any): (boolean, string)
	local index = Guard.Integer(rawIndex, 1, #GIFTS)
	if not index then
		return false, "Unknown gift"
	end
	local data = DataService.Get(player)
	if not data or not counted[player] then
		return false, "Please wait..."
	end
	rollover(player, data, DailyConfig.Day(os.time()))
	local gifts = data.Gifts
	local key = tostring(index)
	if gifts.Claimed[key] then
		return false, "Already opened"
	end
	local left = readyAt(index) - gifts.Seconds
	if left > 0 then
		return false, "Ready in " .. Format.Clock(math.ceil(left))
	end
	gifts.Claimed[key] = true
	local ok, text = RewardService.Grant(player, GIFTS[index].Reward, "Gift")
	if not ok then
		gifts.Claimed[key] = nil
		return false, text
	end
	publish(player)
	Signals.Fire("GiftClaimed", player, index)
	return true, text
end

-- ===== cycle de vie =====

function GiftService.Init()
	Net.Function("ClaimGift", { Rate = 2, Burst = 5 }, GiftService.Claim)

	Signals.Connect("DailyReset", function(player: Player)
		local data = DataService.Get(player)
		if data and counted[player] then
			rollover(player, data, DailyConfig.Day(os.time()))
		end
	end)

	AdminService.RegisterCommand("playtime", {
		Description = "Add playtime for today's gifts (Studio only)",
		Usage = "playtime <minutes> [player]",
		Run = function(player, args)
			if not RunService:IsStudio() then
				return false, "Studio only"
			end
			local minutes = Guard.Number(tonumber(args[1] or ""), 0, 1440)
			local target = AdminService.FindPlayer(player, args[2])
			local data = target and DataService.Get(target)
			if not target or not data or not counted[target] then
				return false, "Player not found"
			end
			if not minutes then
				return false, "Minutes between 0 and 1440"
			end
			rollover(target, data, DailyConfig.Day(os.time()))
			addTime(target, data, minutes * 60)
			publish(target)
			return true, string.format("%s played %s today", target.Name, Format.Duration(data.Gifts.Seconds))
		end,
	})
end

function GiftService.Start()
	while true do
		task.wait(TICK)
		GiftService.Tick()
	end
end

function GiftService.OnPlayerReady(player: Player)
	counted[player] = os.clock()
	-- (le nouveau jour, s'il y en a un, est appliqué au premier compte : les autres services sont prêts)
	publish(player)
end

function GiftService.OnPlayerRemoving(player: Player)
	counted[player] = nil
	lastPublish[player] = nil
end

return GiftService
