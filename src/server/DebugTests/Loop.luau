--!strict
-- Tests FossilDebug du domaine Loop (brief 3) : parcs, zones, gisements, port du bloc, cuves, enclos, revenus.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("all")
-- Chaque test remet le jeu comme il l'a trouvé (dino de test retiré, bloc de test enlevé, multiplicateur retiré).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Services = script.Parent.Parent.Services
local CarryService = require(Services.CarryService)
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local DigSiteService = require(Services.DigSiteService)
local EnclosureService = require(Services.EnclosureService)
local IncomeService = require(Services.IncomeService)
local PlotService = require(Services.PlotService)
local ReviveService = require(Services.ReviveService)
local ZoneService = require(Services.ZoneService)

type Tester = DebugService.Tester

local HOSTILE: { any } = { 0 / 0, math.huge, -1, 0, 0.5, 99, "1", "", true, {}, Vector3.zero }

-- Entrée d'une liste de Config.Economy par son nom (Sizes, Mutations, Levels)
local function byName<T>(list: { T }, name: string): T?
	for _, entry in list do
		if (entry :: any).Name == name then
			return entry
		end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return {
	plots = function(t: Tester)
		t:Equal(#PlotService.List(), PlotService.Count, "8 parks on the map")
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local plot = PlotService.Get(target)
		if not t:Check(plot, "player has a park") then
			return
		end
		local own = plot :: PlotService.Plot
		t:Equal(target:GetAttribute("Plot"), own.Index, "Plot attribute")
		t:Equal(own.Model:GetAttribute("OwnerUserId"), target.UserId, "park owner attribute")
		t:Check(PlotService.IsSafe(own.Spawn.Position), "park spawn is safe")
		t:Equal(PlotService.PlotAt(own.Floor.Position + Vector3.new(0, 3, 0)), own.Index, "PlotAt finds the park")
		t:Check(#own.Tanks >= Economy.Tanks.Max, "park has a part for every tank")
		local beach = ZoneService.Get("Beach")
		t:Check(beach and not PlotService.IsSafe((beach :: ZoneService.ZoneGeo).Area.Position), "the route is not safe")
		if rootOf(target) then
			t:Note("player in own park: " .. tostring(PlotService.IsInOwnPlot(target)))
		end
	end,

	zones = function(t: Tester)
		local list = ZoneService.List()
		t:Equal(#list, #Zones.List, "8 zones on the map")
		for index, geo in list do
			t:Equal(geo.Name, Zones.List[index] and Zones.List[index].Name, "zone " .. index .. " in route order")
			t:Equal(ZoneService.ZoneAt(geo.Area.Position + Vector3.new(0, 3, 0)), geo.Name, geo.Name .. " : ZoneAt")
			t:Check(#geo.Sites > 0, geo.Name .. " : dig sites")
		end
		for _, zone in Zones.List do
			local total = 0
			for _, chance in Zones.Chances(zone.Name) do
				total += chance
			end
			t:Check(math.abs(total - 1) < 1e-9, zone.Name .. " : chances add up to 100%")
			for _, species in zone.Species do
				t:Check(Rarity.Species[species] ~= nil, zone.Name .. " : " .. species .. " has a rarity")
			end
		end
		local beach = Zones.Chances("Beach", 0 / 0)
		t:Equal(beach.Common, Zones.Chances("Beach").Common, "NaN luck ignored")
	end,

	digsites = function(t: Tester)
		local sites = DigSiteService.Sites()
		t:Check(#sites >= #Zones.List, "dig sites created")
		local present = 0
		for _, site in sites do
			for _, slot in site.Slots do
				t:Check(slot.State == "Empty" or slot.State == "Present" or slot.State == "Out", site.Key .. "#" .. slot.Index .. " state")
				if slot.State == "Present" then
					present += 1
					local prompt = slot.Part and slot.Part:FindFirstChild("GrabPrompt")
					if not t:Check(prompt and prompt:IsA("ProximityPrompt"), site.Key .. "#" .. slot.Index .. " grab prompt") then
						continue
					end
					t:Equal((prompt :: ProximityPrompt).HoldDuration, Zones.Dig.GrabTime, site.Key .. "#" .. slot.Index .. " hold time")
				end
			end
		end
		t:Note(present .. " fossil block(s) waiting")
		t:Check(DigSiteService.RefillAt() > Workspace:GetServerTimeNow() - 2, "next refill planned")
		t:Equal(Workspace:GetAttribute("DigRefillAt"), DigSiteService.RefillAt(), "refill time replicated")
		for _, zone in Zones.List do
			local rarity = DigSiteService.RollRarity(zone.Name)
			t:Check((zone.Weights[rarity] or 0) > 0, zone.Name .. " : rolled rarity " .. rarity)
		end
		t:Check(not DigSiteService.ReturnBlock({ Id = -1, Rarity = "Common", Zone = "Beach", Site = "Beach/Site1", Slot = 1 }), "fake block not returned")
		t:Check(not DigSiteService.ReleaseBlock({ Id = -1, Rarity = "Common", Zone = "Beach", Site = "Nope", Slot = 1 }), "fake block not released")
	end,

	carry = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		t:Check(not CarryService.Carry(target, { Id = -1, Rarity = "Nope", Zone = "Beach" }), "unknown rarity refused")
		t:Check(not CarryService.Carry(target, nil :: any), "no block refused")
		if CarryService.IsCarrying(target) then
			t:Note("player is carrying a real block: carry test skipped")
			return
		end
		if not rootOf(target) then
			t:Note("player has no character: carry test skipped")
			return
		end
		local block = { Id = -1, Rarity = "Epic", Zone = "Swamp" }
		t:Check(CarryService.Carry(target, block), "carry a test block")
		t:Equal(CarryService.GetSpeedMultiplier(target), Rarity.Info.Epic.CarrySpeed, "speed malus while carrying")
		t:Equal(target:GetAttribute("Carrying"), "Epic", "Carrying attribute")
		t:Check(target.Character and target.Character:FindFirstChild("CarriedFossil"), "block on the back")
		t:Check(not CarryService.Carry(target, { Id = -2, Rarity = "Common", Zone = "Beach" }), "only one block at a time")
		t:Equal(CarryService.Drop(target), block, "test block removed")
		t:Equal(CarryService.GetSpeedMultiplier(target), 1, "no malus without a block")
		t:Equal(target:GetAttribute("Carrying"), "", "Carrying attribute cleared")
	end,

	revive = function(t: Tester)
		for _, rarity in Rarity.Order do
			for _, zone in Zones.List do
				local candidates = ReviveService.Candidates(rarity, zone.Name)
				if not t:Check(#candidates > 0, rarity .. " in " .. zone.Name .. " : species to revive") then
					continue
				end
				local rolled = ReviveService.Roll(rarity, zone.Name)
				t:Check(Rarity.Species[rolled.Species] == rarity, rarity .. " in " .. zone.Name .. " : " .. rolled.Species)
				t:Check(byName(Economy.Sizes, rolled.Size) ~= nil, rolled.Species .. " size " .. rolled.Size)
			end
		end
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local data = DataService.Get(target) :: DataService.Data
		local tanks = table.clone(data.Tanks)
		for _, value in HOSTILE do
			t:Check(not (ReviveService.Reveal(target, value)), "Reveal(" .. tostring(value) .. ") refused")
		end
		t:Check(data.TankCount >= Economy.Tanks.Start and data.TankCount <= Economy.Tanks.Max, "tank count " .. data.TankCount)
		t:Note(ReviveService.Running(target) .. " tank(s) running, " .. #data.Stored .. " block(s) in storage")
		-- (les révélations refusées n'ont rien changé)
		for slot in tanks do
			t:Check(data.Tanks[slot] ~= nil, "tank " .. tostring(slot) .. " untouched")
		end
	end,

	enclosure = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local data = DataService.Get(target) :: DataService.Data
		t:Equal(EnclosureService.Slots(target), Economy.EnclosureSlots(data.EnclosureUpgrades), "enclosure slots")
		t:Check(EnclosureService.Count(target) <= EnclosureService.Slots(target), "dinos fit in the enclosure")
		t:Check(EnclosureService.AddDino(target, { Species = string.rep("x", 100) }) == nil, "long species refused")
		t:Check(EnclosureService.AddDino(target, nil :: any) == nil, "no dino refused")
		t:Check(EnclosureService.RemoveDino(target, {} :: any) == nil, "bad id refused")
		if not EnclosureService.HasRoom(target) then
			t:Note("enclosure full: add test skipped")
			return
		end
		local count = EnclosureService.Count(target)
		local id = EnclosureService.AddDino(target, { Species = "Compy", Size = "Huge", Mutation = "Lava", Level = 2 })
		if not t:Check(id, "test dino added") then
			return
		end
		local dinoId = id :: string
		t:Equal(EnclosureService.Count(target), count + 1, "count went up")
		local model = EnclosureService.ModelOf(target, dinoId)
		if t:Check(model, "dino model in the park") then
			local m = model :: Model
			t:Check(m:HasTag("Dino"), "Dino tag")
			t:Equal(m:GetAttribute("Species"), "Compy", "Species attribute")
			t:Equal(m:GetAttribute("Scale"), (byName(Economy.Sizes, "Huge") :: Economy.SizeInfo).Scale, "Scale attribute")
			t:Equal(m:GetAttribute("Mutation"), "Lava", "Mutation attribute")
			t:Equal(m:GetAttribute("Level"), "Diamond", "Level attribute")
		end
		t:Equal(EnclosureService.DisplayName(EnclosureService.GetDino(target, dinoId) :: any), "Huge Lava Diamond Compy", "display name")
		t:Check(EnclosureService.RemoveDino(target, dinoId), "test dino removed")
		t:Equal(EnclosureService.Count(target), count, "count back to start")
		t:Equal(EnclosureService.ModelOf(target, dinoId), nil, "model removed")
	end,

	income = function(t: Tester)
		local base = IncomeService.BaseIncome("Compy")
		t:Check(base > 0, "Compy earns money")
		local income = IncomeService.DinoIncome({ Species = "Compy", Size = "Big", Mutation = "Amber", Level = 1 })
		local big = byName(Economy.Sizes, "Big") :: Economy.SizeInfo
		local amber = byName(Economy.Mutations, "Amber") :: Economy.MutationInfo
		local expected = base * big.Income * amber.Income * Economy.Levels[2].Income
		t:Check(math.abs(income - expected) < 1e-9, "income = base x size x mutation x level")
		t:Equal(IncomeService.DinoIncome({ Species = "Compy", Size = 0 / 0, Level = 0 / 0 }), base, "bad values ignored")
		t:Equal(Economy.OfflineCap, 8 * 3600, "offline income capped at 8 h")
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local start = IncomeService.GetIncome(target)
		t:Check(not pcall(IncomeService.SetMultiplier, target, "DebugTest", 0 / 0), "NaN multiplier refused")
		t:Check(not pcall(IncomeService.SetMultiplier, target, "DebugTest", -1), "negative multiplier refused")
		IncomeService.SetMultiplier(target, "DebugTest", 2)
		t:Check(math.abs(IncomeService.GetIncome(target) - start * 2) < 1e-6, "x2 multiplier")
		IncomeService.SetMultiplier(target, "DebugTest", nil)
		t:Check(math.abs(IncomeService.GetIncome(target) - start) < 1e-6, "multiplier removed")
		t:Note("income: $" .. start .. "/s")
	end,
}
