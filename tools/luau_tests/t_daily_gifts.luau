-- Cadeaux de temps de jeu (GiftService) : temps compté par le serveur (AFK compris), cadeau prêt annoncé, ouverture,
-- refus (pas prêt, déjà ouvert, numéro hostile), temps gardé après reconnexion, nouveau jour (cadeaux prêts donnés tout
-- seuls, puis tout repart de zéro), commande playtime.
local T = require("./testkit")
local env = T.env

env.studio = false -- (sauvegardes écrites ; la commande playtime repasse en Studio)
env.quiet = true
local Config = T.config()
local Daily = Config.Daily
local GIFTS = Daily.Gifts
local Boot = T.bootServer()
local GiftService = Boot.Services.GiftService
local ReplicaService = Boot.Services.ReplicaService
local AdminService = Boot.Services.AdminService
local RateLimit = T.lib("RateLimit")

local function claim(player: any, index: any): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, "ClaimGift", index)
end

local function notified(player: any, pattern: string): number
	local count = 0
	for _, args in env.received(player, "Notify") do
		if type(args[1]) == "string" and string.find(args[1], pattern, 1, true) then
			count += 1
		end
	end
	return count
end

T.section("configuration")
for index, gift in GIFTS do
	T.check(gift.Minutes > 0 and Daily.Amount(gift.Reward, nil) > 0, "cadeau " .. index .. " valide")
	if index > 1 then
		T.check(gift.Minutes > GIFTS[index - 1].Minutes, "cadeau " .. index .. " après le précédent")
	end
end

T.section("temps de jeu")
local player = T.join({ UserId = 501, Character = true })
local state = ReplicaService.Get(player, "Gifts")
T.check(type(state) == "table" and type(state.Seconds) == "number" and type(state.At) == "number", "Replica Gifts")
T.eq(#state.Claimed, 0, "aucun cadeau ouvert")
T.check(state.NextReset > state.At, "prochaine remise à zéro")
local ok, text = claim(player, 1)
T.check(not ok and string.sub(text, 1, 8) == "Ready in", "cadeau 1 pas encore prêt (" .. tostring(text) .. ")")
T.advance(GIFTS[1].Minutes * 60 + 2)
T.check(GiftService.Seconds(player) >= GIFTS[1].Minutes * 60, "temps compté sans bouger (AFK compris)")
T.eq(notified(player, "A free gift is ready!"), 1, "cadeau prêt annoncé une fois")
T.check(ReplicaService.Get(player, "Gifts").Seconds >= GIFTS[1].Minutes * 60, "Replica à jour quand un cadeau est prêt")
local money = T.data(player).Money
ok, text = claim(player, 1)
T.check(ok, "cadeau 1 ouvert (" .. tostring(text) .. ")")
T.eq(T.data(player).Money - money, Daily.Amount(GIFTS[1].Reward, nil), "argent du cadeau 1")
T.eq(T.data(player).Gifts.Claimed["1"], true, "cadeau noté")
T.check(table.find(ReplicaService.Get(player, "Gifts").Claimed, 1) ~= nil, "Replica : cadeau 1 ouvert")
ok, text = claim(player, 1)
T.check(not ok and text == "Already opened", "pas deux fois")
T.eq(T.data(player).Money - money, Daily.Amount(GIFTS[1].Reward, nil), "rien de plus")

T.section("appels hostiles")
for _, value in T.hostileValues() do
	ok = claim(player, value)
	T.check(not ok, "ClaimGift hostile refusé : " .. T.show(value))
end
for _, value in { 0, #GIFTS + 1, 1.5, "1", -1 } do
	ok, text = claim(player, value)
	T.check(not ok and text == "Unknown gift", "numéro invalide : " .. T.show(value))
end
T.clean("aucune erreur après les appels hostiles")

T.section("reconnexion : temps gardé")
local seconds = GiftService.Seconds(player)
T.leave(player)
local saved = env.saved("SAF_Players_1", "Player_501")
T.check(saved and saved.Gifts.Seconds >= seconds - 1 and saved.Gifts.Claimed["1"] == true, "temps et cadeaux sauvegardés")
player = T.join({ UserId = 501, Character = true })
T.check(GiftService.Seconds(player) >= seconds - 1, "temps relu après reconnexion (pas de remise à zéro)")
ok, text = claim(player, 1)
T.check(not ok and text == "Already opened", "toujours ouvert après reconnexion")

T.section("commande playtime (Studio)")
env.studio = true
local adminOk, adminText = AdminService.Run(player, "playtime", { tostring(GIFTS[2].Minutes) })
T.check(adminOk, "playtime (" .. tostring(adminText) .. ")")
T.check(GiftService.Seconds(player) >= GIFTS[2].Minutes * 60, "temps ajouté")
adminOk = AdminService.Run(player, "playtime", { "abc" })
T.check(not adminOk, "minutes invalides refusées")
env.studio = false
adminOk = AdminService.Run(player, "playtime", { "10" })
T.check(not adminOk, "playtime refusé hors Studio")

T.section("nouveau jour")
-- cadeau 2 (un tour de roue) prêt mais pas ouvert : donné tout seul au changement de jour
local spins = T.data(player).Spins.Stored
T.check(GiftService.Seconds(player) >= GIFTS[2].Minutes * 60 and T.data(player).Gifts.Claimed["2"] == nil, "cadeau 2 prêt, pas ouvert")
local notes = notified(player, "unopened gifts")
env.baseTime += Daily.DayLength
T.advance(1.1)
local data = T.data(player)
T.eq(data.Gifts.Day, Daily.Day(env.baseTime + math.floor(env.now())), "nouveau jour noté")
T.check(data.Gifts.Seconds < 5, "temps de jeu reparti de zéro (" .. data.Gifts.Seconds .. ")")
T.check(next(data.Gifts.Claimed) == nil, "cadeaux à nouveau fermés")
local reward = GIFTS[2].Reward
T.eq(reward.Kind, "Spins", "(cadeau 2 : des tours)")
T.eq(data.Spins.Stored - spins, reward.Amount, "cadeau prêt d'hier donné tout seul")
T.eq(notified(player, "unopened gifts") - notes, 1, "joueur prévenu")
T.eq(#ReplicaService.Get(player, "Gifts").Claimed, 0, "Replica remis à zéro")
ok = claim(player, 1)
T.check(not ok, "cadeau 1 du nouveau jour pas encore prêt")

T.done("daily_gifts")
