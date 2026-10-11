-- Map (brief 10) : MapService construit Workspace.Map au démarrage avec les points d'ancrage lus par PlotService et
-- ZoneService (docs/BOUCLE.md). Parcs et zones sans chevauchement, zones bout à bout dans l'ordre, gisements et gardien
-- dans leur zone, décor non collidable, budgets de lumières et de pièces, même map à chaque construction, enseigne
-- recopiée à l'intérieur du parc.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local MapService = Boot.Services.MapService
local PlotService = Boot.Services.PlotService
local ZoneService = Boot.Services.ZoneService
local Map = T.module("src/shared/Config/Map")
local Zones = T.module("src/shared/Config/Zones")
local MapBuilder = T.module("src/server/Map/MapBuilder")
local Workspace = env.game:GetService("Workspace")
local Vector3 = env.Vector3

-- Les deux boîtes (Size, CFrame sans rotation) se chevauchent-elles sur X/Z ?
local function overlap(a: any, b: any): boolean
	local pa, pb = a.Position, b.Position
	local ha, hb = a.Size / 2, b.Size / 2
	return math.abs(pa.X - pb.X) < ha.X + hb.X - 0.01 and math.abs(pa.Z - pb.Z) < ha.Z + hb.Z - 0.01
end

local function inside(area: any, position: any): boolean
	local relative = area.CFrame:PointToObjectSpace(position)
	local half = area.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Z) <= half.Z
end

T.section("construction")
local map = Workspace:FindFirstChild("Map")
T.check(map ~= nil, "Workspace.Map construit")
T.check(MapService.Built, "construit par MapService")
T.eq(#Boot.Errors, 0, "aucune erreur au démarrage")
local stats = MapService.Stats
T.check(stats ~= nil and stats.Parts > 5000, "la map a du détail")
T.eq(#stats.Zones, #Zones.List, "une entrée de stats par zone")
T.eq(#PlotService.List(), Map.Plots.Count, "PlotService lit les 8 parcs de la map")
T.eq(#ZoneService.List(), #Zones.List, "ZoneService lit les 8 zones de la map")
T.eq(map:FindFirstChild("Plots"):FindFirstChild("Plot1"):FindFirstChild("WallLeft"), nil, "pas de géométrie provisoire dans les parcs")

T.section("parcs")
local plots = PlotService.List()
for index, plot in plots do
	T.eq(plot.Index, index, "Plot" .. index .. " dans l'ordre")
	T.eq(#plot.Tanks, 6, "Plot" .. index .. " : 6 cuves")
	T.check(plot.Treadmill ~= nil and plot.Lab ~= nil and plot.Sign ~= nil and plot.Entrance ~= nil, "Plot" .. index .. " : treadmill, labo, enseigne, entrée")
	T.check(PlotService.Contains(plot, plot.Spawn.Position), "Plot" .. index .. " : apparition dans la zone sûre")
	T.check(PlotService.Contains(plot, plot.Enclosure.Position), "Plot" .. index .. " : enclos dans la zone sûre")
	for k, tank in plot.Tanks do
		T.check(PlotService.Contains(plot, tank.Position), "Plot" .. index .. " : cuve " .. k .. " dans la zone sûre")
	end
	T.check(plot.Spawn.CFrame.LookVector.Z > 0.99, "Plot" .. index .. " : on apparaît tourné vers la route")
	T.check(PlotService.Contains(plot, plot.Entrance.Position + Vector3.new(0, 3, -2)), "Plot" .. index .. " : juste derrière l'entrée = dans le parc")
	T.check(not PlotService.Contains(plot, plot.Entrance.Position + Vector3.new(0, 3, 8)), "Plot" .. index .. " : devant l'entrée = dehors")
	if index > 1 then
		T.check(not overlap(plots[index - 1].Floor, plot.Floor), "Plot" .. index .. " ne chevauche pas le précédent")
		T.check(plot.Floor.Position.X > plots[index - 1].Floor.Position.X, "Plot" .. index .. " à droite du précédent")
	end
	T.eq(plot.Floor.Position.Z + plot.Floor.Size.Z / 2, 0, "Plot" .. index .. " : entrée au bord Z = 0")
end

T.section("zones")
local geos = ZoneService.List()
local previousEnd = Map.Plaza.Depth
for index, geo in geos do
	local zone = Zones.List[index]
	T.eq(geo.Name, zone.Name, "zone " .. index .. " dans l'ordre")
	local area = geo.Area
	local z0 = area.Position.Z - area.Size.Z / 2
	T.near(z0, previousEnd, 0.01, zone.Name .. " commence où finit la précédente")
	previousEnd = z0 + area.Size.Z
	T.near(area.Size.Z, MapBuilder.Length(zone.Name), 0.01, zone.Name .. " : longueur de Config.Map")
	T.near(area.Position.Y + area.Size.Y / 2, Map.GroundTop, 0.01, zone.Name .. " : Area au niveau du sol")
	for _, plot in plots do
		T.check(not overlap(plot.Floor, area), zone.Name .. " ne touche pas le parc " .. plot.Index)
	end
	T.check(geo.Arch ~= nil and inside(area, geo.Arch.Position), zone.Name .. " : arche dans la zone")
	T.check(string.find(geo.Arch.Label.Title.Text, string.upper(zone.Name), 1, true) ~= nil, zone.Name .. " : nom sur l'arche")
	T.check(geo.Guardian ~= nil and inside(area, geo.Guardian.Position), zone.Name .. " : point Guardian dans la zone")
	T.eq(ZoneService.ZoneAt(geo.Guardian.Position + Vector3.new(0, 3, 0)), zone.Name, zone.Name .. " : ZoneAt au nid du gardien")
	T.eq(#geo.Sites, #Map.Sites, zone.Name .. " : gisements")
	for _, site in geo.Sites do
		T.check(inside(area, site.Position), zone.Name .. "/" .. site.Name .. " dans la zone")
		local slots = 0
		for _, child in site:GetChildren() do
			if child:IsA("Attachment") and string.match(child.Name, "^Slot%d+$") then
				slots += 1
			end
		end
		T.eq(slots, Map.SiteSlots, zone.Name .. "/" .. site.Name .. " : emplacements de blocs")
		T.check(math.abs(site.Position.X) > Map.Route.PathWidth / 2 + 6, zone.Name .. "/" .. site.Name .. " : hors du chemin")
		T.check((site.Position - geo.Guardian.Position).Magnitude > Map.Guardian.Radius, zone.Name .. "/" .. site.Name .. " : hors de la clairière du gardien")
	end
end
T.eq(previousEnd, stats.RouteEnd, "la falaise de fin est au bout de la dernière zone")

T.section("décor et budgets")
local loud = {}
local function checkDecor(root: any)
	for _, folder in root:GetDescendants() do
		if folder.Name == "Decor" and folder:IsA("Folder") then
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") and (part.CanCollide or part.CanQuery or part.CanTouch or part.CastShadow) then
					table.insert(loud, part:GetFullName())
				end
			end
		end
	end
end
checkDecor(map)
T.eq(#loud, 0, "tout le décor est inerte (" .. (loud[1] or "") .. ")")
for _, zone in stats.Zones do
	T.check(zone.Lights <= Map.Lights.Zone, zone.Name .. " : " .. zone.Lights .. " lumières (budget " .. Map.Lights.Zone .. ")")
	T.check(zone.Parts <= Map.MaxPartsPerZone, zone.Name .. " : " .. zone.Parts .. " pièces (budget " .. Map.MaxPartsPerZone .. ")")
end
for index = 1, Map.Plots.Count do
	local lights = 0
	for _, item in map.Plots["Plot" .. index]:GetDescendants() do
		if item:IsA("Light") then
			lights += 1
		end
	end
	T.check(lights <= Map.Lights.Plot, "Plot" .. index .. " : budget de lumières")
end
local barriers = 0
for _, item in map:GetDescendants() do
	if item.Name == "Barrier" then
		barriers += 1
		T.check(item.CanCollide and item.Transparency == 1 and not item.CanQuery, item:GetFullName() .. " : mur invisible")
	end
end
T.check(barriers >= 6, "murs invisibles autour de la place et de la route")

T.section("même map à chaque construction")
local holder = env.Instance.new("Folder")
holder.Name = "Copy"
holder.Parent = Workspace
local copy, copyStats = MapBuilder.Build(holder)
T.eq(copyStats.Parts, stats.Parts, "même nombre de pièces")
local function signature(root: any): string
	local acc = {}
	for _, item in root.Zones.Swamp.Decor:GetDescendants() do
		if item:IsA("BasePart") and #acc < 40 then
			local p = item.Position
			table.insert(acc, string.format("%.2f,%.2f,%.2f", p.X, p.Y, p.Z))
		end
	end
	return table.concat(acc, ";")
end
T.eq(signature(copy), signature(map), "décor du Swamp au même endroit")
holder:Destroy()

T.section("enseigne du parc")
local player = T.join()
local plot = PlotService.Get(player)
T.check(plot ~= nil, "le joueur a un parc")
local outside = plot.Sign.Label.Text
local insideLabel = plot.Sign.LabelInside.Text
T.eq(outside.Text, player.DisplayName .. "'s Park", "nom sur la face extérieure (PlotService)")
T.eq(insideLabel.Text, outside.Text, "recopié sur la face intérieure")
T.leave(player)
T.eq(insideLabel.Text, "Empty park", "parc libéré : face intérieure remise à zéro")

T.clean("aucune erreur")
T.done("map_build")
