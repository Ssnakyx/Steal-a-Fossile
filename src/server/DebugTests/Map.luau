--!strict
-- Test FossilDebug de la map (brief 10) : points d'ancrage des parcs et des 8 zones (docs/BOUCLE.md), décor non
-- collidable, budgets de lumières et de pièces, chemin dégagé (raycasts le long de l'axe de chaque zone), enseigne du
-- parc du joueur. Lancer pendant un Play : game.ServerScriptService.FossilDebug:Invoke("map")
-- Test « ambience » : une ambiance pour la place et chaque zone (Config.Ambience), effets de Lighting posés une seule
-- fois par le serveur, décor flottant valide et inerte, décor lumineux dans chaque zone. Ce que voit le joueur
-- (AmbienceController, côté client) se vérifie en marchant d'une zone à l'autre.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)
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
			-- (sans aucun impact, les raycasts ne marchent pas ici : faux Roblox des tests hors Studio)
			local ground = geo.Model:FindFirstChild("Ground")
			local rays, hits, blocked = 0, 0, 0
			local area = geo.Area
			local z0 = area.Position.Z - area.Size.Z / 2
			for z = z0 + 12, z0 + area.Size.Z - 4, 10 do
				rays += 1
				local hit = Workspace:Raycast(Vector3.new(0, Map.GroundTop + 100, z), Vector3.new(0, -200, 0), rayParams)
				if hit then
					hits += 1
					if not (ground and hit.Instance:IsDescendantOf(ground)) then
						blocked += 1
					end
				end
			end
			if hits == 0 then
				t:Note(name .. ": raycasts unavailable, path check skipped")
			else
				t:Equal(hits, rays, name .. " path has ground all along")
				t:Equal(blocked, 0, name .. " path is clear")
			end
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

	ambience = function(t: Tester)
		-- réglages : la place et chaque zone
		local missing = {}
		for _, zone in Zones.List do
			if not Ambience.Regions[zone.Name] then
				table.insert(missing, zone.Name)
			end
		end
		t:Check(Ambience.Regions.Plaza ~= nil, "spawn plaza has an ambience")
		t:Check(#missing == 0, "every zone has an ambience", table.concat(missing, ", "))
		-- effets de Lighting : un seul de chaque (ceux de la place sont réutilisés)
		for _, className in { "Atmosphere", "Sky", "BloomEffect", "SunRaysEffect" } do
			local count = 0
			for _, child in Lighting:GetChildren() do
				if child:IsA(className) then
					count += 1
				end
			end
			t:Equal(count, 1, "Lighting has one " .. className)
		end
		local grade = Lighting:FindFirstChild(Ambience.GradeName)
		t:Check(grade ~= nil and grade:IsA("ColorCorrectionEffect"), "Lighting has the ambience color grade")
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			local clouds = terrain:FindFirstChildOfClass("Clouds")
			t:Check(clouds ~= nil and clouds.Enabled, "terrain clouds are on")
		end
		-- décor flottant : modèles de la map, pièce centrale, réglages, aucune collision
		local map = Workspace:FindFirstChild("Map")
		local zones = map and map:FindFirstChild("Zones")
		local tagged = CollectionService:GetTagged(Ambience.Float.Tag)
		t:Check(#tagged > 0, "floating decor exists", #tagged)
		local bad = {}
		for _, item in tagged do
			local ok = item:IsA("Model") and zones ~= nil and item:IsDescendantOf(zones)
			if ok and item:IsA("Model") then
				local core = item.PrimaryPart
				ok = core ~= nil and core:IsDescendantOf(item)
				for _, key in { "FloatHeight", "FloatSpeed", "FloatSpin" } do
					ok = ok and type(item:GetAttribute(key)) == "number"
				end
				for _, part in item:GetDescendants() do
					if part:IsA("BasePart") and (part.CanCollide or part.CanQuery or part.CanTouch) then
						ok = false
					end
				end
			end
			if not ok then
				table.insert(bad, item:GetFullName())
			end
		end
		t:Equal(#bad, 0, "floating decor is valid and inert")
		if #bad > 0 then
			t:Note(table.concat(bad, ", ", 1, math.min(#bad, 5)))
		end
		-- décor lumineux (cristaux, champignons...) dans chaque zone
		for _, geo in ZoneService.List() do
			local decor = geo.Model:FindFirstChild("Decor")
			local glowing = 0
			if decor then
				for _, item in decor:GetDescendants() do
					if item:IsA("BasePart") and item.Material == Enum.Material.Neon then
						glowing += 1
					end
				end
			end
			t:Check(glowing >= 40, geo.Name .. " has glowing decor", glowing)
		end
		t:Note("walk through the zones to see each ambience (client side)")
	end,
}
