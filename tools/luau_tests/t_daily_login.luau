-- Calendrier de 14 jours (DailyService) et récompenses (RewardService) : un clic par jour, série, jour manqué, cycle,
-- chaque genre de récompense (argent, vitesse, tours, pièges, bloc fossile), récompense impossible remplacée, montants
-- calculés comme le client, sauvegarde abîmée réparée, commande dailyreset.
local T = require("./testkit")
local env = T.env

env.studio = false -- (sauvegardes écrites ; la commande dailyreset repasse en Studio)
env.quiet = true
local Config = T.config()
local Daily = Config.Daily
local Boot = T.bootServer()
local DailyService = Boot.Services.DailyService
local RewardService = Boot.Services.RewardService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local DAY = Daily.DayLength

local claimed = {}
Signals.Connect("DailyClaimed", function(p, day, streak)
	table.insert(claimed, { p, day, streak })
end)

local function now(): number
	return env.baseTime + math.floor(env.now())
end

-- Passe au jour suivant (ou `days` jours plus tard) sans faire tourner les boucles des services
local function nextDay(days: number?)
	env.baseTime += (days or 1) * DAY
	DailyService.CheckDay()
	env.flush()
end

local function claim(player: any): (any, any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, "ClaimDaily")
end

T.section("montants et textes (partagés avec le client)")
T.eq(#Daily.Login.Days, 14, "14 jours (GDD)")
T.eq(Daily.Amount({ Kind = "Money", IncomeMinutes = 5, Amount = 200 }, { Income = 0, Speed = 0 }), 200, "argent : minimum sans revenu")
T.eq(Daily.Amount({ Kind = "Money", IncomeMinutes = 5, Amount = 200 }, { Income = 10, Speed = 0 }), 3000, "argent : 5 min de 10 $/s")
T.eq(Daily.Amount({ Kind = "Speed", SpeedPercent = 3, Amount = 300 }, { Income = 0, Speed = 100000 }), 3000, "vitesse : 3 % de 100 K")
T.eq(Daily.Amount({ Kind = "Speed", SpeedPercent = 3, Amount = 300 }, nil), 300, "vitesse : minimum sans échelle")
T.eq(Daily.Amount({ Kind = "Money", IncomeMinutes = 5, Amount = 200 }, { Income = 0 / 0, Speed = math.huge }), 200, "NaN et infini ignorés")
T.eq(Daily.Amount({ Kind = "Spins", Amount = 3 }, nil), 3, "tours")
T.eq(Daily.Amount({ Kind = "Block", Rarity = "Epic" }, nil), 1, "bloc")
T.eq(Daily.Label({ Kind = "Money", IncomeMinutes = 5, Amount = 200 }, { Income = 10, Speed = 0 }), "+$3K", "texte argent")
T.eq(Daily.Label({ Kind = "Speed", SpeedPercent = 3, Amount = 300 }, nil), "+300 Speed", "texte vitesse")
T.eq(Daily.Label({ Kind = "Spins", Amount = 1 }, nil), "+1 Spin", "texte 1 tour")
T.eq(Daily.Label({ Kind = "Spins", Amount = 3 }, nil), "+3 Spins", "texte tours")
T.eq(Daily.Label({ Kind = "BearTraps", Amount = 3 }, nil), "3 Bear Traps", "texte pièges")
T.eq(Daily.Label({ Kind = "Block", Rarity = "Epic" }, nil), "Epic Fossil", "texte bloc")
T.eq(Daily.NextReset(now()) - now(), DAY - (now() % DAY), "prochaine remise à zéro à 00:00 UTC")
for index, reward in Daily.Login.Days do
	T.check(type(reward.Kind) == "string" and Daily.Amount(reward, nil) > 0, "jour " .. index .. " valide")
	if reward.Kind == "Block" then
		T.check(Config.Rarity.Info[reward.Rarity] ~= nil, "jour " .. index .. " : rareté connue")
	end
end

T.section("premier jour")
local player = T.join({ UserId = 301, Character = true })
local state = ReplicaService.Get(player, "Daily")
T.check(type(state) == "table", "Replica Daily")
T.eq(state.CanClaim, true, "récompense à prendre")
T.eq(state.Next, 1, "jour 1")
T.eq(state.Streak, 0, "série à 0")
T.check(type(ReplicaService.Get(player, "RewardScale")) == "table", "Replica RewardScale")
local money = T.data(player).Money
local ok, text, day = claim(player)
T.check(ok, "jour 1 pris (" .. tostring(text) .. ")")
T.eq(day, 1, "numéro du jour renvoyé")
T.eq(text, "Day 1: +$500", "texte de la récompense")
T.eq(T.data(player).Money - money, 500, "argent donné (minimum : pas encore de revenu)")
T.eq(T.data(player).Daily.Day, 1, "jour sauvegardé")
T.eq(T.data(player).Daily.Streak, 1, "série 1")
T.eq(T.data(player).Daily.Best, 1, "meilleure série 1")
T.check(#claimed == 1 and claimed[1][2] == 1 and claimed[1][3] == 1, "signal DailyClaimed")
local granted = env.received(player, "RewardGranted")
T.check(#granted >= 1 and granted[#granted][1] == "Daily" and granted[#granted][2] == "+$500", "événement RewardGranted vers le client")
state = ReplicaService.Get(player, "Daily")
T.eq(state.CanClaim, false, "plus rien à prendre aujourd'hui")
T.eq(state.Next, 1, "le jour pris reste affiché")
ok, text = claim(player)
T.check(not ok and text == "Come back tomorrow for your next reward!", "pas deux fois le même jour")
T.eq(T.data(player).Money - money, 500, "rien de plus")
for _ = 1, 5 do
	claim(player)
end
T.eq(T.data(player).Daily.Streak, 1, "spam sans effet")

T.section("jours suivants : chaque genre de récompense")
local notes = #env.received(player, "Notify")
nextDay()
T.eq(#env.received(player, "Notify"), notes + 1, "« A new day! » au changement de jour")
state = ReplicaService.Get(player, "Daily")
T.check(state.CanClaim and state.Next == 2 and state.Streak == 1, "jour 2 à prendre, série gardée")
local stored = T.data(player).Spins.Stored
ok = claim(player)
T.check(ok, "jour 2 pris")
T.eq(T.data(player).Spins.Stored - stored, 1, "jour 2 : 1 tour de roue")
T.eq(ReplicaService.Get(player, "Spins").Stored, stored + 1, "Replica Spins à jour")
nextDay()
local speed = T.data(player).Speed
ok = claim(player)
T.check(ok, "jour 3 pris")
T.eq(T.data(player).Speed - speed, 300, "jour 3 : vitesse (minimum)")
nextDay()
local traps = T.data(player).BearTraps
ok = claim(player)
T.check(ok, "jour 4 pris")
T.eq(T.data(player).BearTraps - traps, 3, "jour 4 : 3 Bear Traps")
T.eq(ReplicaService.Get(player, "BearTraps"), traps + 3, "Replica BearTraps à jour")
T.eq(T.data(player).Daily.Streak, 4, "série 4")

T.section("bloc fossile (jour 7)")
local data = T.data(player)
data.Daily.Day = 6
data.Daily.LastClaim = now() - DAY
local function countRarity(rarity: string): number
	local count = 0
	for _, tank in data.Tanks do
		if tank.Rarity == rarity then
			count += 1
		end
	end
	for _, block in data.Stored do
		if block.Rarity == rarity then
			count += 1
		end
	end
	return count
end
local epics = countRarity("Epic")
ok, text = claim(player)
T.check(ok and text == "Day 7: Epic Fossil", "jour 7 pris (" .. tostring(text) .. ")")
T.eq(countRarity("Epic") - epics, 1, "bloc Epic dans une cuve ou en réserve")
granted = env.received(player, "RewardGranted")
T.eq(granted[#granted][3], "Epic", "rareté envoyée au client")

T.section("bloc impossible : argent à la place")
nextDay()
data.Daily.Day = 13
local full = {}
for slot = 1, data.TankCount do
	full[tostring(slot)] = { Rarity = "Common", Zone = "Beach", StartedAt = now(), EndsAt = now() + 999999 }
end
data.Tanks = full
local storedBlocks = {}
for _ = 1, Config.Economy.MaxStored do
	table.insert(storedBlocks, { Rarity = "Common", Zone = "Beach" })
end
data.Stored = storedBlocks
money = data.Money
ok, text = claim(player)
T.check(ok, "jour 14 pris malgré les cuves pleines")
T.eq(countRarity("Legendary"), 0, "pas de bloc Legendary (plus de place)")
T.eq(data.Money - money, 250, "argent de secours (Config.Daily.Fallback)")
T.eq(text, "Day 14: +$250", "texte de l'argent de secours")
T.eq(data.Daily.Day, 14, "jour 14 noté")
data.Tanks = {}
data.Stored = {}

T.section("cycle de 14 jours et série")
nextDay()
state = ReplicaService.Get(player, "Daily")
T.check(state.CanClaim and state.Next == 1, "après le jour 14 : jour 1")
local streakBefore = data.Daily.Streak
ok = claim(player)
T.check(ok, "jour 1 du cycle suivant pris")
T.eq(data.Daily.Streak, streakBefore + 1, "la série continue après le jour 14")

T.section("jour manqué")
local best = data.Daily.Best
nextDay(3)
state = ReplicaService.Get(player, "Daily")
T.check(state.CanClaim and state.Next == 1 and state.Streak == 0, "jour manqué : retour au jour 1, série 0")
ok = claim(player)
T.check(ok, "jour 1 repris")
T.eq(data.Daily.Streak, 1, "série repartie à 1")
T.eq(data.Daily.Best, best, "meilleure série gardée")
Daily.Login.ResetOnMiss = false
nextDay(3)
state = ReplicaService.Get(player, "Daily")
T.check(state.Next == 2 and state.Streak == 1, "ResetOnMiss = false : la série continue")
Daily.Login.ResetOnMiss = true

T.section("argent selon le revenu")
local scale = RewardService.Scale(player)
T.eq(scale.Speed, data.Speed, "échelle : vitesse gagnée")
T.check(type(scale.Income) == "number" and scale.Income >= 0, "échelle : revenu")
data.Daily.Day = 4
data.Daily.LastClaim = now() - DAY
local reward = Daily.Login.Days[5]
money = data.Money
ok, text = claim(player)
T.check(ok, "jour 5 pris")
T.eq(data.Money - money, Daily.Amount(reward, RewardService.Scale(player)), "montant calculé comme le client")

T.section("appels hostiles")
for _, value in T.hostileValues() do
	RateLimit.Reset(player)
	env.invokeServer(player, "ClaimDaily", value, value)
end
T.eq(data.Daily.Day, 5, "rien de pris par des appels hostiles (déjà pris aujourd'hui)")
T.clean("aucune erreur après les appels hostiles")

T.section("sauvegarde")
nextDay()
claim(player)
local saveDay = data.Daily.Day
local saveStreak = data.Daily.Streak
T.leave(player)
local saved = env.saved("SAF_Players_1", "Player_301")
T.check(saved and saved.Daily.Day == saveDay and saved.Daily.Streak == saveStreak, "calendrier sauvegardé au départ")
player = T.join({ UserId = 301 })
T.eq(T.data(player).Daily.Day, saveDay, "calendrier relu")
T.eq(ReplicaService.Get(player, "Daily").CanClaim, false, "déjà pris aujourd'hui après reconnexion")

T.section("sauvegarde abîmée")
env.datastore.set("SAF_Players_1/global", "Player_302", {
	Version = 1,
	Domains = { Daily = 1 },
	Daily = { Day = 99, LastClaim = -5, Streak = -4, Best = 2 },
	Spins = { Stored = -3, FreeDay = -7, FreeUsed = "x", Total = -1 },
	Gifts = { Day = 0, Seconds = 1e12, Claimed = { ["99"] = true, ["2"] = true, x = true } },
})
local broken = T.join({ UserId = 302 })
local bd = T.data(broken)
T.eq(bd.Daily.Day, 14, "jour borné à 14")
T.eq(bd.Daily.LastClaim, 0, "dernière récompense réparée")
T.eq(bd.Daily.Streak, 0, "série négative réparée")
T.eq(bd.Spins.Stored, 0, "tours négatifs réparés")
T.eq(bd.Spins.FreeDay, 0, "jour gratuit réparé")
T.eq(bd.Spins.FreeUsed, 0, "tours gratuits utilisés réparés")
T.eq(bd.Gifts.Seconds, Daily.DayLength, "temps de jeu borné à un jour")
T.check(bd.Gifts.Claimed["2"] == true and bd.Gifts.Claimed["99"] == nil and bd.Gifts.Claimed.x == nil, "cadeaux inconnus retirés")

T.section("commande dailyreset (Studio)")
env.studio = true
local resetOk, resetText = AdminService.Run(player, "dailyreset", {})
T.check(resetOk, "dailyreset (" .. tostring(resetText) .. ")")
T.eq(ReplicaService.Get(player, "Daily").CanClaim, true, "récompense du jour à nouveau à prendre")
local streakNow = T.data(player).Daily.Streak
ok = claim(player)
T.check(ok, "reprise après dailyreset")
T.eq(T.data(player).Daily.Streak, streakNow + 1, "la série continue")
env.studio = false
resetOk = AdminService.Run(player, "dailyreset", {})
T.check(not resetOk, "dailyreset refusé hors Studio")

T.done("daily_login")
