--!strict
-- Tests FossilDebug des récompenses et de l'AFK (docs/RECOMPENSES.md) : rewards, spin, gifts, afk.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("rewards")
-- (ou "spin", "gifts", "afk", "all"). Chaque test remet le joueur dans l'état où il l'a trouvé.
-- Pour essayer en vrai : commandes d'admin dailyreset (calendrier, tour gratuit et cadeaux du jour à nouveau
-- disponibles), playtime <minutes> (temps de jeu des cadeaux), spins <n> (tours en réserve).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Services = script.Parent.Parent.Services
local AfkService = require(Services.AfkService)
local DailyService = require(Services.DailyService)
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local GiftService = require(Services.GiftService)
local MoneyService = require(Services.MoneyService)
local PlotService = require(Services.PlotService)
local ReplicaService = require(Services.ReplicaService)
local RewardService = require(Services.RewardService)
local SpeedService = require(Services.SpeedService)
local SpinService = require(Services.SpinService)
local TreadmillService = require(Services.TreadmillService)

type Tester = DebugService.Tester

local function loaded(t: Tester): (Player?, { [string]: any }?)
	local player = t:Player()
	if not t:Check(player, "a player is loaded") then
		return nil, nil
	end
	return player, DataService.Get(player :: Player)
end

return {
	rewards = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local scale = RewardService.Scale(player)
		t:Equal(#DailyConfig.Login.Days, 14, "14 login days")
		for day, reward in DailyConfig.Login.Days do
			t:Check(DailyConfig.Amount(reward, scale) > 0 and DailyConfig.Label(reward, scale) ~= "", "day " .. day .. " reward is valid")
		end
		local state = DailyService.State(player)
		if t:Check(state, "daily state") then
			local s = state :: DailyService.State
			t:Check(s.Next >= 1 and s.Next <= #DailyConfig.Login.Days, "next day in the calendar")
			t:Check(s.NextReset > os.time(), "next reset in the future")
			t:Note(string.format("next day %d, can claim: %s, streak %d (best %d)", s.Next, tostring(s.CanClaim), s.Streak, s.Best))
		end
		t:Check(ReplicaService.Get(player, "Daily") ~= nil, "client got the calendar")
		t:Check(ReplicaService.Get(player, "RewardScale") ~= nil, "client got the reward scale")

		local money = MoneyService.Get(player)
		local earned: number = data.TotalEarned
		local speed: number = data.Speed
		local ok, text, amount = RewardService.Grant(player, { Kind = "Money", Amount = 100 }, "Debug")
		t:Check(ok and amount == 100, "money reward (" .. text .. ")")
		t:Equal(MoneyService.Get(player), money + 100, "money went up")
		ok, text, amount = RewardService.Grant(player, { Kind = "Speed", Amount = 10 }, "Debug")
		t:Check(ok and amount == 10, "speed reward (" .. text .. ")")
		t:Equal(data.Speed, speed + 10, "speed went up")
		local before = MoneyService.Get(player)
		ok, text = RewardService.Grant(player, { Kind = "Nope" }, "Debug")
		t:Check(ok and MoneyService.Get(player) > before, "unknown reward: fallback money (" .. text .. ")")
		MoneyService.Set(player, money, "Debug")
		data.TotalEarned = earned
		SpeedService.Set(player, speed)
		t:Equal(MoneyService.Get(player), money, "money restored")
		t:Equal(data.Speed, speed, "speed restored")
	end,

	spin = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local total = 0
		for index in DailyConfig.Spins.Prizes do
			total += DailyConfig.Chance(index)
		end
		t:Check(math.abs(total - 1) < 1e-9, "shown chances add up to 100%")
		local seen: { [number]: number } = {}
		for _ = 1, 2000 do
			local index = SpinService.Pick()
			seen[index] = (seen[index] or 0) + 1
		end
		for index, prize in DailyConfig.Spins.Prizes do
			t:Check((seen[index] or 0) > 0, prize.Name .. " can be won")
		end
		local free, stored = SpinService.Available(player)
		t:Note(string.format("%d free spin(s) today, %d stored, %d spun in total", free, stored, data.Spins.Total))
		t:Check(SpinService.Give(player, 2), "give 2 spins")
		t:Equal(data.Spins.Stored, stored + 2, "spins stored")
		t:Check(not SpinService.Give(player, 0 / 0), "NaN refused")
		data.Spins.Stored = stored
		SpinService.Refresh(player)
		t:Equal((ReplicaService.Get(player, "Spins") :: any).Stored, stored, "spins restored")
		for key, product in DailyConfig.Spins.Products do
			t:Note(string.format("%s: product id %d%s", key, product.Id, if product.Id == 0 then " (hidden until created in the Creator Hub)" else ""))
		end
	end,

	gifts = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local seconds = GiftService.Seconds(player)
		t:Check(seconds >= 0 and seconds <= DailyConfig.DayLength, "playtime today")
		-- (un nouveau jour est appliqué à la première seconde comptée)
		t:Check(data.Gifts.Day <= DailyConfig.Day(os.time()), "gifts day not in the future")
		local state = ReplicaService.Get(player, "Gifts") :: any
		if t:Check(type(state) == "table", "client got the gifts") then
			t:Check(type(state.Claimed) == "table" and state.NextReset > os.time(), "gifts state")
		end
		local ready = 0
		for index, gift in DailyConfig.Gifts do
			if seconds >= gift.Minutes * 60 and not data.Gifts.Claimed[tostring(index)] then
				ready += 1
			end
		end
		t:Note(string.format("%d min played today, %d gift(s) ready to open", seconds // 60, ready))
	end,

	afk = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local treadmill = SpeedConfig.Treadmill
		if data.TreadmillLevel == 0 then
			t:Equal(TreadmillService.Rate(player), treadmill.BaseGain * treadmill.FreeMultiplier, "free treadmill gain")
		else
			t:Check(TreadmillService.Rate(player) > 0, "treadmill gain")
		end
		local plot = PlotService.Get(player)
		local belt = plot and plot.Treadmill
		local target = AfkService.BeltCFrame(player)
		if not belt or not target then
			t:Note("no treadmill in the plot: placement not checked")
		else
			local relative = belt.CFrame:PointToObjectSpace(target.Position)
			local half = belt.Size / 2
			local inside = math.abs(relative.X) <= half.X
				and math.abs(relative.Z) <= half.Z
				and relative.Y >= -half.Y
				and relative.Y <= half.Y + treadmill.Height
			t:Check(inside, "an AFK reconnect puts the player on the treadmill")
		end
		if TreadmillService.IsOnTreadmill(player) and RunService:IsStudio() then
			local ok, text = AfkService.Rejoin(player)
			t:Check(not ok and text == "Studio", "no teleport in Studio (" .. text .. ")")
			AfkService.ClearCooldown(player)
		else
			t:Note("stand on your treadmill and run again to check the reconnect request")
		end
		t:Note(string.format("reconnect after %d s idle on the treadmill (Roblox kicks after 20 min)", treadmill.Afk.RejoinAfter))
	end,
}
