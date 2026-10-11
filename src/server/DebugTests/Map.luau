--!strict
-- Test FossilDebug de la map (brief 10) : points d'ancrage des 8 parcs et des 8 zones (docs/BOUCLE.md), décor non
-- collidable, budgets de lumières et de pièces, chemin dégagé (raycasts le long de l'axe de chaque zone), enseigne du
-- parc du joueur. Lancer pendant un Play : game.ServerScriptService.FossilDebug:Invoke("map")

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Services = script.Parent.Parent.Services
local DebugService = require(Services.DebugService)
local PlotService = require(Services.PlotService)
local ZoneService = require(Services.ZoneService)

type Tester = DebugService.Tester

local PLOT_ANCHORS = { "Floor", "Spawn", "Entrance", "Sign", "Enclosure", "Treadmill", "Lab", "Tank1", "Tank6" }

-- Une pièce de décor est-elle bien inerte ?
local function inert(part: BasePart): boolean
	return not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow
end

return {
	map = function(t: Tester)
		local map = Workspace:FindFirstChild("Map")
		if not t:Check(map ~= nil, "Workspace.Map exists") or not map then
			return
		end
		-- parcs
		t:Equal(#PlotService.List(), Map.Plots.Count, "every park is read by PlotService")
		for index = 1, Map.Plots.Count do
			local plot = PlotService.ByIndex(index)
			if t:Check(plot ~= nil, "Plot" .. index .. " read") and plot then
				local missing = {}
				for _, name in PLOT_ANCHORS do
					if not plot.Model:FindFirstChild(name, true) then
						table.insert(missing, name)
					end
				end
				t:Check(#missing == 0, "Plot" .. index .. " anchors", table.concat(missing, ", "))
				t:Check(plot.Treadmill ~= nil and CollectionService:HasTag(plot.Treadmill, "Treadmill"), "Plot" .. index .. " treadmill tagged")
			end
		end
		-- zones
		local geos = ZoneService.List()
		t:Equal(#geos, #Zones.List, "every zone is read by ZoneService")
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { map }
		for _, geo in geos do
			local name = geo.Name
			t:Check(geo.Arch ~= nil and geo.Guardian ~= nil, name .. " has Arch and Guardian")
			t:Equal(#geo.Sites, #Map.Sites, name .. " dig sites")
			local slotsOk = true
			for _, site in geo.Sites do
				local slots = 0
				for _, child in site:GetChildren() do
					if child:IsA("Attachment") and string.match(child.Name, "^Slot%d+$") then
						slots += 1
					end
				end
				slotsOk = slotsOk and slots == Map.SiteSlots
			end
			t:Check(slotsOk, name .. " sites have " .. Map.SiteSlots .. " slots")
			local parts, lights, loud = 0, 0, 0
			for _, item in geo.Model:GetDescendants() do
				if item:IsA("BasePart") then
					parts += 1
				elseif item:IsA("Light") then
					lights += 1
				end
			end
			local decor = geo.Model:FindFirstChild("Decor")
			if decor then
				for _, item in decor:GetDescendants() do
					if item:IsA("BasePart") and not inert(item) then
						loud += 1
					end
				end
			end
			t:Check(parts <= Map.MaxPartsPerZone, name .. " part budget", parts)
			t:Check(lights <= Map.Lights.Zone, name .. " light budget", lights)
			t:Equal(loud, 0, name .. " decor is not collidable")
			-- chemin dégagé : le premier obstacle sous l'axe est le sol de la zone
			local ground = geo.Model:FindFirstChild("Ground")
			local blocked = 0
			local area = geo.Area
			local z0 = area.Position.Z - area.Size.Z / 2
			for z = z0 + 12, z0 + area.Size.Z - 4, 10 do
				local hit = Workspace:Raycast(Vector3.new(0, Map.GroundTop + 100, z), Vector3.new(0, -200, 0), rayParams)
				if not (hit and ground and hit.Instance:IsDescendantOf(ground)) then
					blocked += 1
				end
			end
			t:Equal(blocked, 0, name .. " path is clear")
		end
		-- enseigne du parc du joueur, recopiée à l'intérieur
		local player = t:Player()
		local plot = player and PlotService.Get(player)
		if player and plot and plot.Sign then
			local outside = plot.Sign:FindFirstChild("Label")
			local inside = plot.Sign:FindFirstChild("LabelInside")
			local a = outside and outside:FindFirstChild("Text")
			local b = inside and inside:FindFirstChild("Text")
			if t:Check(a and b and a:IsA("TextLabel") and b:IsA("TextLabel"), "park sign has both faces") then
				t:Equal((b :: TextLabel).Text, player.DisplayName .. "'s Park", "inside face shows the owner")
			end
		else
			t:Note("no player with a park: sign check skipped")
		end
	end,
}
