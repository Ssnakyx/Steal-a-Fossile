-- FossilDebug du brief 9 : le test en jeu « blocks » passe sur un serveur démarré (gisements remplis) et ne laisse rien
-- dans le jeu.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local DebugService = Boot.Services.DebugService
local workspace = env.game:GetService("Workspace")

local before = #workspace:GetDescendants()
T.check(table.find(DebugService.Tests(), "blocks") ~= nil, "test en jeu blocks")
local ok, fail, lines = DebugService.RunTest("blocks")
T.check(ok >= 7 * 4, "blocks : vérifications faites (" .. ok .. ")")
T.eq(fail, 0, "blocks : aucun échec")
if fail > 0 then
	print(table.concat(lines, "\n"))
end
local placed = 0
for _, line in lines do
	local n = string.match(line, "(%d+) blocks on dig sites")
	if n then
		placed = tonumber(n) or 0
	end
end
T.check(placed > 0, "des blocs sont posés sur les gisements (" .. placed .. ")")
T.eq(#workspace:GetDescendants(), before, "rien laissé dans le Workspace")
T.clean("aucune erreur")

T.done("blocks_debug")
