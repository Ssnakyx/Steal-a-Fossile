-- TrailService : achat avec l'argent du jeu, trail portée = bonus de vitesse et traînée visible, sauvegarde.
local T = require("./testkit")
local env = T.env

env.studio = false
env.quiet = true
local Config = T.config()
local Trails = Config.Speed.Trails
local Boot = T.bootServer()
local TrailService = Boot.Services.TrailService
local SpeedService = Boot.Services.SpeedService
local MoneyService = Boot.Services.MoneyService
local ReplicaService = Boot.Services.ReplicaService
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")

local function call(player: any, name: string, ...: any): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, name, ...)
end

local function visual(player: any): any
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root:FindFirstChild("SAF_Trail")
end

T.section("config")
local orders = {}
local count = 0
for id, trail in Trails do
	count += 1
	orders[trail.Order] = id
	T.check(trail.Price > 0 and trail.Speed > 0 and #trail.Colors >= 1, id .. " : prix, vitesse et couleur")
end
T.eq(count, 10, "10 trails (GDD)")
T.eq(Trails[orders[1]].Tier, "Common", "la première est Common")
T.eq(Trails[orders[10]].Tier, "Divine", "la dernière est Divine")
local increasing = true
for order = 2, 10 do
	local a, b = Trails[orders[order - 1]], Trails[orders[order]]
	if not (a and b and b.Price > a.Price and b.Speed > a.Speed) then
		increasing = false
	end
end
T.check(increasing, "prix et vitesse montent avec l'ordre")

T.section("achat")
local bought = {}
Signals.Connect("TrailBought", function(p, id)
	table.insert(bought, { p, id })
end)
local player = T.join({ UserId = 301, Character = true })
T.eq(TrailService.Equipped(player), "", "aucune trail au départ")
local ok, text = call(player, "BuyTrail", "Dust")
T.check(not ok and text == "Not enough money!", "pas assez d'argent")
T.eq(next(T.data(player).Trails.Owned), nil, "rien acheté")
MoneyService.Add(player, 3000, "Test")
ok, text = call(player, "BuyTrail", "Dust")
T.check(ok, "Dust achetée (" .. tostring(text) .. ")")
T.eq(MoneyService.Get(player), 3000 - Trails.Dust.Price, "argent dépensé")
T.check(T.data(player).Trails.Owned.Dust, "Dust possédée")
T.eq(TrailService.Equipped(player), "Dust", "portée tout de suite")
T.eq(SpeedService.Get(player), Trails.Dust.Speed, "vitesse de la trail ajoutée")
T.eq(T.data(player).Speed, 0, "bonus pas compté comme vitesse gagnée")
T.check(#bought == 1 and bought[1][2] == "Dust", "signal TrailBought")
local effect = visual(player)
T.check(effect ~= nil and effect:IsA("Trail"), "traînée sur le personnage")
T.check(effect and effect.Attachment0 ~= nil and effect.Attachment1 ~= nil, "traînée attachée")
env.flush()
local replica = ReplicaService.Get(player, "Trails")
T.check(replica and replica.Owned.Dust and replica.Equipped == "Dust", "Replica Trails")
ok, text = call(player, "BuyTrail", "Dust")
T.check(not ok and text == "Already owned", "pas deux fois")
T.eq(MoneyService.Get(player), 3000 - Trails.Dust.Price, "pas payé deux fois")

T.section("meilleure trail")
ok = call(player, "BuyTrail", "Fern")
T.check(ok, "Fern achetée")
T.eq(TrailService.Equipped(player), "Fern", "la plus rapide est portée")
T.eq(SpeedService.Get(player), Trails.Fern.Speed, "une seule trail compte")
ok = call(player, "EquipTrail", "Dust")
T.check(ok, "Dust remise")
T.eq(SpeedService.Get(player), Trails.Dust.Speed, "vitesse de Dust")
ok = call(player, "EquipTrail", "")
T.check(ok, "trail enlevée")
T.eq(SpeedService.Get(player), 0, "plus de bonus")
T.eq(visual(player), nil, "plus de traînée")
ok, text = call(player, "EquipTrail", "Rainbow")
T.check(not ok and text == "You don't own this trail", "trail pas possédée")
T.eq(TrailService.Equipped(player), "", "rien porté")
call(player, "EquipTrail", "Fern")

T.section("personnage")
player:LoadCharacter()
env.flush()
T.check(visual(player) ~= nil, "traînée remise au nouveau personnage")
local count2 = 0
for _, child in player.Character.HumanoidRootPart:GetChildren() do
	if child.Name == "SAF_Trail" then
		count2 += 1
	end
end
T.eq(count2, 1, "une seule traînée")
call(player, "EquipTrail", "Dust")
call(player, "EquipTrail", "Fern")
count2 = 0
for _, child in player.Character.HumanoidRootPart:GetChildren() do
	if child.Name == "SAF_Trail" or child.Name == "SAF_TrailTop" or child.Name == "SAF_TrailBottom" then
		count2 += 1
	end
end
T.eq(count2, 3, "changer de trail ne les empile pas")

T.section("valeurs hostiles")
local money = MoneyService.Get(player)
for _, bad in T.hostileValues() do
	call(player, "BuyTrail", bad)
	call(player, "EquipTrail", bad)
end
for _, name in { "__index", "Nope", "dust", "Order" } do
	ok = call(player, "BuyTrail", name)
	T.check(not ok, "BuyTrail " .. name .. " refusé")
end
T.clean("aucune erreur")
T.eq(MoneyService.Get(player), money, "argent intact")
-- (« "" » fait partie des valeurs hostiles : c'est la demande légitime « enlever la trail »)
T.check(TrailService.Equipped(player) == "Fern" or TrailService.Equipped(player) == "", "trail portée : Fern ou aucune")
local ownedCount = 0
for _ in T.data(player).Trails.Owned do
	ownedCount += 1
end
T.eq(ownedCount, 2, "trails possédées intactes")
call(player, "EquipTrail", "Fern")
local noCharacter = T.join({ UserId = 302 })
MoneyService.Add(noCharacter, 1000, "Test")
ok = call(noCharacter, "BuyTrail", "Dust")
T.check(ok, "achat sans personnage")
T.clean("pas d'erreur sans personnage")

T.section("sauvegarde")
T.leave(player)
local saved = env.saved("SAF_Players_1", "Player_301")
T.check(saved.Trails.Owned.Fern and saved.Trails.Equipped == "Fern", "trails écrites")
local back = T.join({ UserId = 301, Character = true })
T.eq(TrailService.Equipped(back), "Fern", "trail portée rechargée")
T.eq(SpeedService.Get(back), Trails.Fern.Speed, "bonus remis au retour")
T.check(visual(back) ~= nil, "traînée remise au retour")

T.done("speed_trails")
