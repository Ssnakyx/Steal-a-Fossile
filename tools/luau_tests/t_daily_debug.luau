-- FossilDebug des récompenses et de l'AFK : les tests en jeu rewards, spin, gifts et afk passent et remettent le joueur
-- en l'état (avec et sans personnage, sur son tapis ou pas).
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local AfkService = Boot.Services.AfkService
local DebugService = Boot.Services.DebugService
local MoneyService = Boot.Services.MoneyService
local ReplicaService = Boot.Services.ReplicaService
local SpeedService = Boot.Services.SpeedService
local TreadmillService = Boot.Services.TreadmillService

local function runAll(player: any)
	MoneyService.Set(player, 4321, "Test")
	SpeedService.Set(player, 55)
	local data = T.data(player)
	data.Spins.Stored = 3
	local earned = data.TotalEarned
	local daily = table.clone(data.Daily)
	for _, name in { "rewards", "spin", "gifts", "afk" } do
		T.check(table.find(DebugService.Tests(), name) ~= nil, "test en jeu " .. name)
		local ok, fail, lines = DebugService.RunTest(name)
		T.check(ok > 0, name .. " : vérifications faites")
		T.eq(fail, 0, name .. " : aucun échec")
		if fail > 0 then
			print(table.concat(lines, "\n"))
		end
	end
	T.eq(MoneyService.Get(player), 4321, "argent remis")
	T.eq(data.TotalEarned, earned, "TotalEarned intact")
	T.eq(data.Speed, 55, "vitesse remise")
	T.eq(data.Spins.Stored, 3, "tours remis")
	T.eq(ReplicaService.Get(player, "Spins").Stored, 3, "client prévenu")
	for key, value in daily do
		T.eq(data.Daily[key], value, "calendrier intact : " .. key)
	end
end

for _, characterless in { false, true } do
	T.section(if characterless then "sans personnage" else "avec personnage")
	local player = T.join({ Character = not characterless })
	env.flush()
	runAll(player)
	T.leave(player)
end

T.section("sur son tapis (Studio)")
local player = T.join({ Character = true })
env.flush()
player.Character:PivotTo(AfkService.BeltCFrame(player))
TreadmillService.Tick()
T.check(TreadmillService.IsOnTreadmill(player), "sur son tapis")
runAll(player)
local ok, text = AfkService.Rejoin(player)
T.check(not ok and text == "Studio", "pas de recharge laissée par le test (" .. tostring(text) .. ")")
T.clean("aucune erreur")

T.done("daily_debug")
