-- FossilDebug du brief 4 : les tests en jeu speed, treadmill, trails et shop passent et remettent le joueur en l'état.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Shop = T.config().Shop
Shop.Passes.VIP.Id = 502
Shop.Products.ServerLuck.Id = 601
local Boot = T.bootServer()
local DebugService = Boot.Services.DebugService
local MoneyService = Boot.Services.MoneyService
local SpeedService = Boot.Services.SpeedService

for _, characterless in { false, true } do
	T.section(if characterless then "sans personnage" else "avec personnage")
	local player = T.join({ Character = not characterless })
	MoneyService.Add(player, 1234, "Test")
	SpeedService.Add(player, 77, "Test")
	local data = T.data(player)
	data.TreadmillLevel = 2
	local earned = data.TotalEarned
	for _, name in { "speed", "treadmill", "trails", "shop" } do
		T.check(table.find(DebugService.Tests(), name) ~= nil, "test en jeu " .. name)
		local ok, fail, lines = DebugService.RunTest(name)
		T.check(ok > 0, name .. " : vérifications faites")
		T.eq(fail, 0, name .. " : aucun échec")
		if fail > 0 then
			print(table.concat(lines, "\n"))
		end
	end
	T.eq(MoneyService.Get(player), 1234, "argent remis")
	T.eq(data.TotalEarned, earned, "TotalEarned intact")
	T.eq(data.Speed, 77, "vitesse remise")
	T.eq(data.TreadmillLevel, 2, "niveau remis")
	T.eq(next(data.Trails.Owned), nil, "trail de test retirée")
	T.eq(data.Trails.Equipped, "", "trail portée remise")
	T.leave(player)
end

T.section("outil belt")
local bindable = env.game:GetService("ServerScriptService"):FindFirstChild("FossilDebug")
local TreadmillService = Boot.Services.TreadmillService
local runner = T.join({ Character = true })
local report = bindable:Invoke("belt")
T.check(string.find(report, "Treadmill placed", 1, true) ~= nil, "tapis posé (" .. report .. ")")
local belt = env.game:GetService("Workspace"):FindFirstChild("DebugTreadmill")
T.check(belt ~= nil and belt:HasTag("Treadmill") and belt:GetAttribute("OwnerUserId") == runner.UserId, "tapis tagué, au joueur")
bindable:Invoke("belt")
local count = 0
for _, child in env.game:GetService("Workspace"):GetChildren() do
	if child.Name == "DebugTreadmill" then
		count += 1
	end
end
T.eq(count, 1, "un seul tapis de test")
belt = env.game:GetService("Workspace"):FindFirstChild("DebugTreadmill")
runner.Character.HumanoidRootPart.CFrame = env.CFrame.new(belt.Position + env.Vector3.new(0, 3, 0))
TreadmillService.Tick()
T.check(TreadmillService.IsOnTreadmill(runner), "le joueur peut courir dessus")

T.done("speed_debug")
