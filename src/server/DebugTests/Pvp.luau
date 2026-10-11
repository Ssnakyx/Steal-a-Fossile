--!strict
-- Tests FossilDebug du brief 7 « gardiens-vol » : gardiens, pelle et pièges, blocs au sol.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("guardians")
-- (ou "pvp", "dropped", "all"). Chaque test remet le jeu comme il l'a trouvé (bloc de test enlevé).
-- Commandes d'admin utiles pour tester à deux dans Studio : « protection off », « traps 5 », « guardians off »,
-- « returnblocks », « tpzone 1 ».

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardiansConfig = require(ReplicatedStorage.Shared.Config.Guardians)
local Pvp = require(ReplicatedStorage.Shared.Config.Pvp)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Services = script.Parent.Parent.Services
local CarryService = require(Services.CarryService)
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local DroppedBlockService = require(Services.DroppedBlockService)
local GuardianService = require(Services.GuardianService)
local PlotService = require(Services.PlotService)
local PvpService = require(Services.PvpService)
local ZoneService = require(Services.ZoneService)

type Tester = DebugService.Tester

local HOSTILE: { any } = { 0 / 0, math.huge, -1, 0, 0.5, 99, "1", "", true, {}, Vector3.zero, workspace }

return {
	guardians = function(t: Tester)
		local list = GuardianService.List()
		t:Equal(#list, #ZoneService.List(), "one guardian per zone")
		local previous = 0
		for _, zone in Zones.List do
			local g = GuardianService.Get(zone.Name)
			if not t:Check(g, zone.Name .. " has a guardian") then
				continue
			end
			local guardian = g :: GuardianService.Guardian
			local model = guardian.Model
			t:Check(model.Parent ~= nil and model:HasTag("Dino") and model:HasTag("Guardian"), zone.Name .. " guardian model tagged Dino and Guardian")
			t:Equal(model:GetAttribute("Guardian"), zone.Name, zone.Name .. " guardian attribute")
			t:Check(type(model:GetAttribute("Species")) == "string" and type(model:GetAttribute("Scale")) == "number", zone.Name .. " Species and Scale attributes")
			local info = GuardiansConfig.Zones[zone.Name]
			t:Check(info and info.Scale >= 1.5 and info.Scale <= 3, zone.Name .. " guardian scale x1.5 to x3")
			t:Check(not PlotService.IsSafe(guardian.Home.Position), zone.Name .. " guardian sleeps on the road")
			t:Check(guardian.Speed >= previous, zone.Name .. " guardian not slower than the previous zone")
			previous = guardian.Speed
		end
		-- tutoriel : un nouveau joueur chargé d'un bloc Common distance le gardien de la Beach
		local beach = GuardianService.SpeedFor(Zones.List[1].Name)
		t:Check(beach < SpeedConfig.WalkSpeedFor(0) * 0.9, "Beach guardian slower than a new player carrying a Common block", beach)
	end,

	pvp = function(t: Tester)
		t:Check(Pvp.Shovel.Cooldown >= 1 and Pvp.Shovel.Range > 0, "shovel cooldown and range")
		t:Check(Pvp.Trap.HoldTime > 0 and Pvp.Trap.Price > 0, "bear trap hold time and price")
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local data = DataService.Get(target) :: { [string]: any }
		local traps = data.BearTraps
		t:Equal(type(target:GetAttribute("Protected")), "boolean", "Protected attribute")
		if target.Character then
			local backpack = target:FindFirstChildOfClass("Backpack")
			local shovel = (backpack and backpack:FindFirstChild(Pvp.Shovel.ToolName)) or target.Character:FindFirstChild(Pvp.Shovel.ToolName)
			t:Check(shovel and shovel:IsA("Tool"), "player has a shovel")
		end
		for _, value in HOSTILE do
			local ok = PvpService.Bonk(target, value)
			t:Check(not ok, "hostile bonk target refused: " .. typeof(value))
		end
		t:Equal(data.BearTraps, traps, "bear traps untouched")
		t:Check(not PvpService.SpringTrapAt(Vector3.new(0 / 0, 0, 0)), "NaN position springs no trap")
	end,

	dropped = function(t: Tester)
		local player = t:Player()
		local route = ZoneService.List()[1]
		if not t:Check(route, "the road has a zone") then
			return
		end
		local area = (route :: ZoneService.ZoneGeo).Area
		local ground = area.Position + Vector3.new(area.Size.X / 2 - 6, area.Size.Y / 2, 0)
		local block: CarryService.Block = { Id = -1, Rarity = "Rare", Zone = route.Name }
		local entry = DroppedBlockService.Place(block, ground, player, "Debug")
		if not t:Check(entry, "test block dropped on the road") then
			return
		end
		local dropped = entry :: DroppedBlockService.Dropped
		t:Check(dropped.Part:HasTag("DroppedFossil"), "DroppedFossil tag")
		t:Equal(dropped.Part:GetAttribute("Rarity"), "Rare", "Rarity attribute")
		t:Check(dropped.Part:FindFirstChild("PickUpPrompt") ~= nil, "Pick up prompt")
		if player and not CarryService.IsCarrying(player) then
			local ok, text = DroppedBlockService.PickUp(player, dropped.Id)
			t:Check(not ok and text == "Locked", "dropper cannot grab it back right away", text)
		end
		t:Check(DroppedBlockService.Return(dropped.Id), "test block returned")
		t:Equal(DroppedBlockService.Get(dropped.Id), nil, "test block gone")
		t:Equal(dropped.Part.Parent, nil, "test block removed from the world")
	end,
}
