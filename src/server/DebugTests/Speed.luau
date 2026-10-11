--!strict
-- Tests FossilDebug du brief 4 « vitesse-treadmill » : vitesse, treadmill, trails, shop.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("speed")
-- (ou "treadmill", "trails", "shop", "all"). Chaque test remet le joueur dans l'état où il l'a trouvé.
-- Outil : FossilDebug:Invoke("belt") pose un tapis de test devant le premier joueur (tant que le parc du brief 3 et la
-- map du brief 10 n'en ont pas), à lui seul (attribut OwnerUserId).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local MoneyService = require(Services.MoneyService)
local PlotService = require(Services.PlotService)
local ReceiptService = require(Services.ReceiptService)
local ShopService = require(Services.ShopService)
local SpeedService = require(Services.SpeedService)
local TrailService = require(Services.TrailService)
local TreadmillService = require(Services.TreadmillService)

type Tester = DebugService.Tester

local BELT_NAME = "DebugTreadmill"

-- Tapis de test (gris, studs sur le dessus) posé au sol, 8 studs devant le premier joueur chargé
DebugService.RegisterCommand("belt", function(): string
	local player: Player? = nil
	for _, candidate in game:GetService("Players"):GetPlayers() do
		if DataService.Get(candidate) then
			player = candidate
			break
		end
	end
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not player or not (root and root:IsA("BasePart")) then
		return "No loaded player with a character"
	end
	local old = Workspace:FindFirstChild(BELT_NAME)
	if old then
		old:Destroy()
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local center = root.Position + flat * 8 - Vector3.new(0, 3.5, 0)
	local belt = Instance.new("Part")
	belt.Name = BELT_NAME
	belt.Anchored = true
	belt.Size = Vector3.new(6, 1, 10)
	belt.CFrame = CFrame.lookAt(center, center + flat)
	belt.Color = Color3.fromRGB(70, 70, 76)
	belt.TopSurface = Enum.SurfaceType.Studs
	belt:SetAttribute(SpeedConfig.Treadmill.OwnerAttribute, player.UserId)
	belt:AddTag(SpeedConfig.Treadmill.Tag)
	belt.Parent = Workspace
	return string.format("Treadmill placed for %s (level %d, +%s speed/s)", player.Name, (DataService.Get(player) :: any).TreadmillLevel, tostring(TreadmillService.Rate(player)))
end)

local function loaded(t: Tester): (Player?, { [string]: any }?)
	local player = t:Player()
	if not t:Check(player, "a player is loaded") then
		return nil, nil
	end
	return player, DataService.Get(player :: Player)
end

return {
	speed = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local start: number = data.Speed
		t:Check(SpeedConfig.WalkSpeedFor(1000) > SpeedConfig.WalkSpeedFor(0), "more speed = faster")
		t:Equal(SpeedConfig.WalkSpeedFor(0), SpeedConfig.WalkSpeed.Base, "speed 0 = base WalkSpeed")
		t:Check(SpeedService.Add(player, 100, "Debug"), "add 100 speed")
		t:Equal(data.Speed, start + 100, "speed went up")
		t:Check(not SpeedService.Add(player, 0 / 0, "Debug"), "NaN refused")
		t:Check(not SpeedService.Add(player, -5, "Debug"), "negative refused")
		local total = SpeedService.Get(player)
		SpeedService.SetBonus(player, "DebugBonus", 50)
		t:Equal(SpeedService.Get(player), total + 50, "bonus added")
		SpeedService.SetBonus(player, "DebugBonus", nil)
		t:Equal(SpeedService.Get(player), total, "bonus removed")
		SpeedService.SetMultiplier(player, "DebugMultiplier", 2)
		t:Equal(SpeedService.Get(player), math.min(total * 2, SpeedConfig.Max), "multiplier applied")
		SpeedService.SetMultiplier(player, "DebugMultiplier", nil)
		t:Equal(SpeedService.Get(player), total, "multiplier removed")
		SpeedService.SetModifier(player, "Debug", 0.5)
		t:Check(SpeedService.HasModifier(player, "Debug"), "modifier set")
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			t:Check(math.abs(humanoid.WalkSpeed - SpeedService.WalkSpeed(player)) < 1e-3, "WalkSpeed applied")
		else
			t:Note("no character: WalkSpeed not checked")
		end
		SpeedService.SetModifier(player, "Debug", nil)
		t:Check(not SpeedService.HasModifier(player, "Debug"), "modifier removed")
		SpeedService.Set(player, start)
		t:Equal(data.Speed, start, "speed restored")
	end,

	treadmill = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local level: number = data.TreadmillLevel
		local maxLevel = #Shop.Treadmill.Levels
		t:Equal(maxLevel, 10, "10 treadmill levels (GDD)")
		if level < maxLevel then
			local ok = ReceiptService.Simulate(player, "TreadmillLevel" .. (level + 1))
			t:Check(ok, "next level can be bought (simulated)")
			t:Equal(data.TreadmillLevel, level + 1, "level went up")
			t:Check(TreadmillService.Rate(player) > 0, "treadmill gives speed")
			if level + 3 <= maxLevel then
				local skipped = ReceiptService.Simulate(player, "TreadmillLevel" .. (level + 3))
				t:Check(not skipped, "a level that is not the next one is refused")
			end
			TreadmillService.SetLevel(player, level)
		end
		t:Equal(data.TreadmillLevel, level, "level restored")
		if level < maxLevel then
			local cash = Shop.Treadmill.Levels[level + 1].Cash
			local money = MoneyService.Get(player)
			MoneyService.Set(player, money + cash, "Debug") -- (Set : ne compte pas dans TotalEarned)
			local ok, text = TreadmillService.Buy(player, "Cash")
			t:Check(ok, "next level bought with cash (" .. text .. ")")
			t:Equal(data.TreadmillLevel, level + 1, "cash level went up")
			t:Equal(MoneyService.Get(player), money, "cash price paid")
			TreadmillService.SetLevel(player, level)
		end
		local plot = PlotService.Get(player)
		local prompt = plot and plot.Treadmill and plot.Treadmill:FindFirstChild("TreadmillPrompt")
		t:Check(prompt ~= nil and prompt:IsA("ProximityPrompt"), "unlock/upgrade prompt on the park treadmill")
		local belts = CollectionService:GetTagged(SpeedConfig.Treadmill.Tag)
		t:Note(string.format("%d treadmill belt(s) tagged %q, player on one: %s", #belts, SpeedConfig.Treadmill.Tag, tostring(TreadmillService.IsOnTreadmill(player))))
	end,

	trails = function(t: Tester)
		local player, data = loaded(t)
		if not player or not data then
			return
		end
		local money = MoneyService.Get(player)
		local hadDust = data.Trails.Owned.Dust == true
		local equipped: string = data.Trails.Equipped
		local speed = SpeedService.Get(player)
		-- (Set et pas Add : l'argent de test ne compte pas dans TotalEarned)
		MoneyService.Set(player, money + SpeedConfig.Trails.Dust.Price, "Debug")
		if not hadDust then
			t:Check(TrailService.Buy(player, "Dust"), "buy Dust")
		end
		t:Check(data.Trails.Owned.Dust, "Dust owned")
		t:Check(TrailService.Equip(player, "Dust"), "equip Dust")
		t:Equal(SpeedService.GetBonus(player, "Trail"), SpeedConfig.Trails.Dust.Speed, "trail speed bonus")
		t:Check(not TrailService.Equip(player, "Nope"), "unknown trail refused")
		t:Check(TrailService.Equip(player, ""), "unequip")
		t:Equal(SpeedService.GetBonus(player, "Trail"), 0, "no bonus without trail")
		for id, trail in SpeedConfig.RobuxTrails do
			if not TrailService.Owns(player, id) then
				t:Check(not TrailService.Equip(player, id), id .. " (Robux) not owned: cannot be worn")
			end
			t:Check(Shop.Passes[trail.Pass] ~= nil, id .. " (Robux) has its game pass in Config.Shop")
		end
		t:Note("Robux trails: give one in Studio with the admin command: pass NeonTrail (or GalaxyTrail, GoldenTrail)")
		if not hadDust then
			data.Trails.Owned.Dust = nil
		end
		-- (une trail Robux portée sans son passe ne se remet pas par Equip : elle reste juste notée)
		if not TrailService.Equip(player, equipped) then
			data.Trails.Equipped = equipped
		end
		MoneyService.Set(player, money, "Debug")
		t:Equal(SpeedService.Get(player), speed, "speed restored")
		t:Equal(MoneyService.Get(player), money, "money restored")
	end,

	shop = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local shop = ShopService.Get(player :: Player)
		t:Check(type(shop.Passes) == "table" and type(shop.Products) == "table", "shop lists")
		t:Check(type(shop.Treadmill) == "table", "treadmill section")
		for _, pass in shop.Passes do
			t:Check(Shop.Passes[pass.Key].Id ~= 0, pass.Key .. " is on sale")
		end
		for _, product in shop.Products do
			t:Check(ReceiptService.IsOnSale(product.Key), product.Key .. " is on sale")
		end
		t:Check(not ShopService.HasPass(player :: Player, "Nope"), "unknown pass not owned")
		local luck = ShopService.ServerLuck()
		t:Check(luck == 1 or luck == Shop.ServerLuck.Multiplier, "server luck multiplier")
		t:Note(string.format("%d pass(es) and %d product(s) on sale", #shop.Passes, #shop.Products))
	end,
}
