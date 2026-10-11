-- Boucle (brief 3) : parcs et zones. Géométrie provisoire et points d'ancrage nommés, attribution des parcs, zone sûre,
-- apparition dans son parc, zone du joueur.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local PlotService = Boot.Services.PlotService
local ZoneService = Boot.Services.ZoneService
local Zones = T.module("src/shared/Config/Zones")
local MapConfig = T.module("src/shared/Config/Map")
local COUNT = MapConfig.Plots.Count
local Workspace = env.game:GetService("Workspace")
local CollectionService = env.game:GetService("CollectionService")
local Vector3 = env.Vector3

T.section("géométrie provisoire")
local map = Workspace:FindFirstChild("Map")
T.check(map ~= nil, "Workspace.Map construit")
T.check(map:FindFirstChild("SpawnGround") ~= nil, "sol du spawn")
T.eq(COUNT, 5, "serveurs de 5 joueurs : 5 parcs")
T.eq(PlotService.Count, COUNT, "PlotService suit Config.Map.Plots.Count")
T.eq(#PlotService.List(), COUNT, "5 parcs")
T.eq(map.Plots:FindFirstChild("Plot" .. (COUNT + 1)), nil, "pas de parc en trop")
for index = 1, COUNT do
	local model = map.Plots:FindFirstChild("Plot" .. index)
	T.check(model ~= nil, "Plot" .. index)
	for _, name in { "Floor", "Spawn", "Entrance", "Sign", "Enclosure", "Treadmill", "Lab" } do
		T.check(model:FindFirstChild(name) ~= nil, "Plot" .. index .. "." .. name)
	end
	T.eq(#PlotService.ByIndex(index).Tanks, 6, "Plot" .. index .. " : 6 cuves")
	T.eq(model:GetAttribute("OwnerUserId"), 0, "Plot" .. index .. " libre au départ")
	T.eq(model:GetAttribute("Index"), index, "Plot" .. index .. " : attribut Index")
	T.check(CollectionService:HasTag(model.Treadmill, "Treadmill"), "Plot" .. index .. " : treadmill tagué pour le brief 4")
end
T.eq(#ZoneService.List(), 8, "8 zones")
for index, zone in Zones.List do
	local geo = ZoneService.List()[index]
	T.eq(geo.Name, zone.Name, "zone " .. index .. " dans l'ordre de la route")
	local model = map.Zones:FindFirstChild(zone.Name)
	T.check(model ~= nil, "Map.Zones." .. zone.Name)
	T.check(model:FindFirstChild("Area") ~= nil and model:FindFirstChild("Arch") ~= nil, zone.Name .. " : Area et Arch")
	T.check(geo.Guardian ~= nil, zone.Name .. " : point Guardian pour le brief 7")
	T.eq(#geo.Sites, Zones.Dig.Sites, zone.Name .. " : gisements")
	T.eq(model:GetAttribute("Speed"), zone.Speed, zone.Name .. " : vitesse conseillée en attribut")
	T.check(string.find(model.Arch.Label.Title.Text, string.upper(zone.Name), 1, true) ~= nil, zone.Name .. " : nom sur l'arche")
end
-- les zones s'éloignent du spawn
local previous = -math.huge
for _, geo in ZoneService.List() do
	T.check(geo.Area.Position.Z > previous, geo.Name .. " plus loin que la précédente")
	previous = geo.Area.Position.Z
end
T.eq(ZoneService.List()[1].Sites[1].Name, "Site1", "gisements triés")

T.section("zones et zone sûre")
local plot1 = PlotService.ByIndex(1)
T.eq(PlotService.PlotAt(plot1.Floor.Position + Vector3.new(0, 3, 0)), 1, "PlotAt dans le parc 1")
T.check(PlotService.IsSafe(plot1.Spawn.Position), "le spawn du parc est sûr")
T.check(PlotService.IsSafe(plot1.Floor.Position + Vector3.new(0, 40, 0)), "sûr en sautant")
T.check(not PlotService.IsSafe(plot1.Floor.Position + Vector3.new(0, 200, 0)), "pas sûr très haut au-dessus")
local beach = ZoneService.Get("Beach")
T.check(not PlotService.IsSafe(beach.Area.Position), "la route n'est pas sûre")
T.eq(ZoneService.ZoneAt(beach.Area.Position + Vector3.new(0, 3, 0)), "Beach", "ZoneAt Beach")
T.eq(ZoneService.ZoneAt(ZoneService.Get("Meteor Crater").Area.Position), "Meteor Crater", "ZoneAt Meteor Crater")
T.eq(ZoneService.ZoneAt(plot1.Floor.Position), nil, "un parc n'est pas une zone")
T.eq(ZoneService.ZoneAt(Vector3.new(5000, 0, 0)), nil, "hors de la map")

T.section("attribution des parcs")
local a = T.join({ Name = "Alice", Character = true })
local b = T.join({ Name = "Bob", Character = true })
env.flush()
T.eq(a:GetAttribute("Plot"), 1, "Alice a le parc 1")
T.eq(b:GetAttribute("Plot"), 2, "Bob a le parc 2")
T.eq(PlotService.ByIndex(1).Model:GetAttribute("OwnerUserId"), a.UserId, "OwnerUserId du parc 1")
T.eq(PlotService.ByIndex(1).Sign.Label.Text.Text, "Alice's Park", "enseigne au nom du joueur")
T.check(PlotService.IsInOwnPlot(a), "Alice apparaît dans son parc")
T.check(PlotService.IsInOwnPlot(b), "Bob apparaît dans le sien")
T.check(PlotService.IsPlayerSafe(b), "Bob est en zone sûre")
T.check(not PlotService.Contains(PlotService.Get(b), a.Character.HumanoidRootPart.Position), "Alice n'est pas dans le parc de Bob")
-- réapparition : de retour dans son parc
a.Character:PivotTo(env.CFrame.new(beach.Area.Position + Vector3.new(0, 4, 0)))
T.check(not PlotService.IsInOwnPlot(a), "Alice partie sur la route")
a:LoadCharacter()
env.flush()
T.check(PlotService.IsInOwnPlot(a), "réapparaît dans son parc")

T.section("zone du joueur")
a.Character:PivotTo(env.CFrame.new(beach.Area.Position + Vector3.new(0, 4, 0)))
local changes = {}
local Signals = T.lib("Signals")
local disconnect = Signals.Connect("ZoneChanged", function(player, zone, before)
	table.insert(changes, player.Name .. ":" .. before .. ">" .. zone)
end)
env.advance(0.5)
T.eq(a:GetAttribute("Zone"), "Beach", "attribut Zone = Beach")
T.eq(ZoneService.PlayerZone(a), "Beach", "PlayerZone")
T.eq(changes[1], "Alice:>Beach", "signal ZoneChanged")
PlotService.Teleport(a)
env.advance(0.5)
T.eq(a:GetAttribute("Zone"), "", "de retour au parc : plus de zone")
disconnect()

T.section("départ et parc plein")
T.leave(a)
T.eq(PlotService.ByIndex(1).Model:GetAttribute("OwnerUserId"), 0, "parc 1 rendu")
T.eq(PlotService.ByIndex(1).Sign.Label.Text.Text, "Empty park", "enseigne remise")
local others = {}
for index = 1, COUNT do
	table.insert(others, T.join({ Name = "P" .. index }))
end
T.eq(others[1]:GetAttribute("Plot"), 1, "le parc libéré est repris")
T.eq(others[COUNT]:GetAttribute("Plot"), 0, "6e joueur : pas de parc")
T.check(PlotService.Get(others[COUNT]) == nil, "Get = nil sans parc")
local notified = false
for _, sent in env.received(others[COUNT], "Notify") do
	if sent[1] == "All parks are taken!" then
		notified = true
	end
end
T.check(notified, "message « All parks are taken! »")
T.leave(others[3])
local late = T.join({ Name = "Late" })
T.eq(late:GetAttribute("Plot"), 4, "un nouveau venu reprend le premier parc libre")

T.done("loop_world")
