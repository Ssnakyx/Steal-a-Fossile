-- FossilDebug du brief 8 : les tests en jeu fusion et hybrids passent et remettent le joueur en l'état (dinos, argent,
-- Index des hybrides), avec ou sans personnage, enclos plein compris.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local DebugService = Boot.Services.DebugService
local EnclosureService = Boot.Services.EnclosureService
local MoneyService = Boot.Services.MoneyService
local ReplicaService = Boot.Services.ReplicaService

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

for _, characterless in { false, true } do
	T.section(if characterless then "sans personnage" else "avec personnage")
	local player = T.join({ Character = not characterless })
	MoneyService.Add(player, 1234, "Test")
	local data = T.data(player)
	EnclosureService.AddDino(player, { Species = "T-Rex" })
	local dinos = count(data.Dinos)
	for _, name in { "fusion", "hybrids" } do
		T.check(table.find(DebugService.Tests(), name) ~= nil, "test en jeu " .. name)
		local ok, fail, lines = DebugService.RunTest(name)
		T.check(ok > 0, name .. " : vérifications faites")
		T.eq(fail, 0, name .. " : aucun échec")
		if fail > 0 then
			print(table.concat(lines, "\n"))
		end
	end
	T.eq(MoneyService.Get(player), 1234, "argent remis")
	T.eq(count(data.Dinos), dinos, "dinos de test retirés")
	T.eq(count(data.Index.Hybrids), 0, "Index des hybrides remis")
	ReplicaService.Flush()
	T.eq(ReplicaService.Get(player, "Hybrids").Found, 0, "replica Hybrids remise")
	T.leave(player)
end

T.section("enclos plein")
local player = T.join()
while EnclosureService.HasRoom(player) do
	EnclosureService.AddDino(player, { Species = "Compy" })
end
local _, fail, lines = DebugService.RunTest("fusion")
T.eq(fail, 0, "enclos plein : pas d'échec")
T.check(string.find(table.concat(lines, "\n"), "skipped", 1, true) ~= nil, "enclos plein : test sauté")
T.done("fusion_debug")
