-- Poursuite sur toute la route (Config.Guardians : ChaseWholeRoute, RouteOnly, MatchCarry). Réveillé, le gardien suit
-- le porteur de zone en zone, Beach comprise, jusqu'à la place du spawn, jamais dessus. Sa course = 0.9 x le WalkSpeed conseillé de sa
-- zone x le malus du bloc porté : un nouveau joueur ne peut pas voler au fond de la route, un joueur un peu trop lent est
-- rattrapé loin de la zone, un joueur à la vitesse conseillée rentre. Endormi, il ne se réveille que dans sa laisse.
-- Loin de chez lui, il rentre à sa vitesse de course.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local GuardianService = Boot.Services.GuardianService
local CarryService = Boot.Services.CarryService
local DroppedBlockService = Boot.Services.DroppedBlockService
local DigSiteService = Boot.Services.DigSiteService
local PlotService = Boot.Services.PlotService
local SpeedService = Boot.Services.SpeedService
local ZoneService = Boot.Services.ZoneService
local Guardians = T.module("src/shared/Config/Guardians")
local SpeedConfig = T.module("src/shared/Config/Speed")
local Zones = T.module("src/shared/Config/Zones")
local Rarity = T.module("src/shared/Config/Rarity")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local Vector3, CFrame = env.Vector3, env.CFrame

local STEP = 0.1
local CRATER = "Meteor Crater"

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function waitFor(condition: () -> boolean, limit: number): boolean
	local deadline = env.now() + limit
	while not condition() do
		if env.now() >= deadline then
			return false
		end
		env.advance(STEP)
	end
	return true
end

-- Bloc présent de la zone le plus près du spawn (le gardien est derrière lui)
local function nearestSlot(zone: string): any
	local best, bestZ = nil, nil
	for _, site in DigSiteService.Sites() do
		if site.Zone == zone then
			for _, slot in site.Slots do
				if slot.State == "Present" and (bestZ == nil or slot.Part.Position.Z < bestZ) then
					best, bestZ = slot, slot.Part.Position.Z
				end
			end
		end
	end
	return best
end

local function grab(player, slot)
	RateLimit.Reset(player)
	local part = slot.Part
	player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 1.5, -4)))
	local prompt = part.GrabPrompt
	env.fire(env.signal(prompt, "PromptButtonHoldBegan"), player)
	env.advance(Zones.Dig.GrabTime + 0.05)
	env.fire(env.signal(prompt, "Triggered"), player)
	env.flush()
end

local function rootOf(player)
	return player.Character.HumanoidRootPart
end

-- Marche vers `goal` à la vitesse de son Humanoid (posée par SpeedService) ; check() à chaque pas (arrêt si false)
local function walkTo(player, goal, limit: number, check: (() -> boolean)?): boolean
	local deadline = env.now() + limit
	while env.now() < deadline do
		local root = rootOf(player)
		local offset = flat(goal) - flat(root.Position)
		if offset.Magnitude < 0.5 then
			return true
		end
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		local step = math.min(humanoid.WalkSpeed * STEP, offset.Magnitude)
		if step > 0 then
			local position = root.Position + offset.Unit * step
			player.Character:PivotTo(CFrame.lookAt(position, position + offset.Unit))
		end
		env.advance(STEP)
		if check and not check() then
			return false
		end
	end
	return false
end

-- Rentre au parc par la route (couloir entre les murs invisibles) : d'abord sur la place du spawn, puis devant son parc
local function walkHome(player, limit: number, check: () -> boolean)
	local entrance = PlotService.Get(player).Entrance.Position
	local deadline = env.now() + limit
	local plaza = Vector3.new(0, entrance.Y + 3, entrance.Z + 40)
	if not walkTo(player, plaza, limit, check) then
		return
	end
	walkTo(player, entrance + Vector3.new(0, 3, 8), math.max(0, deadline - env.now()), check)
end

local function lostWith(player, reason: string): boolean
	for _, args in env.received(player, "GuardianAlert") do
		if args[2] == "Lost" and args[3] == reason then
			return true
		end
	end
	return false
end

-- Distance (studs, sur X/Z) entre une position et la pièce Area d'une zone (0 dedans)
local function outsideArea(zone: string, position: Vector3): number
	local area = ZoneService.Get(zone).Area
	local relative = area.CFrame:PointToObjectSpace(position)
	local half = area.Size / 2
	local dx = math.max(0, math.abs(relative.X) - half.X)
	local dz = math.max(0, math.abs(relative.Z) - half.Z)
	return math.sqrt(dx * dx + dz * dz)
end

local caught = {}
Signals.Connect("GuardianCaught", function(player, zone, block)
	local g = GuardianService.Get(zone)
	table.insert(caught, { Player = player, Zone = zone, Block = block, At = g.CFrame.Position })
end)

local crater = GuardianService.Get(CRATER)

T.section("réglages : la vitesse décide")
T.check(Guardians.ChaseWholeRoute == true, "poursuite sur toute la route")
T.check(Guardians.RouteOnly == true and next(Guardians.SafeZones) == nil, "la limite : la place du spawn (aucune zone sûre)")
for _, zone in Zones.List do
	local g = GuardianService.Get(zone.Name)
	local fixed = Guardians.Zones[zone.Name].Speed ~= nil
	local advised = SpeedConfig.WalkSpeedFor(zone.Speed)
	if fixed then
		T.eq(g.Speed, Guardians.Zones[zone.Name].Speed, zone.Name .. " : vitesse fixe (tutoriel)")
		T.check(SpeedConfig.WalkSpeedFor(0) * Rarity.Info.Uncommon.CarrySpeed > g.Speed, zone.Name .. " : un nouveau joueur chargé lui échappe")
		continue
	end
	T.near(g.Speed, Guardians.SpeedFactor * advised, 1e-9, zone.Name .. " : 0.9 x WalkSpeed conseillé")
	for rarity in zone.Weights do
		local carry = Rarity.Info[rarity].CarrySpeed
		T.check(advised * carry > g.Speed * carry, zone.Name .. " / " .. rarity .. " : à la vitesse conseillée, chargé, on va plus vite")
		T.check(SpeedConfig.WalkSpeedFor(0) * carry < g.Speed * carry, zone.Name .. " / " .. rarity .. " : un nouveau joueur chargé va moins vite")
	end
end

T.section("un nouveau joueur ne peut pas voler au fond")
local newbie = T.join({ Name = "Newbie", Character = true })
env.flush()
T.eq(SpeedService.Get(newbie), 0, "vitesse 0")
local slot = nearestSlot(CRATER)
T.check(slot ~= nil, "un bloc au Meteor Crater")
local block = slot.Block
grab(newbie, slot)
T.check(CarryService.IsCarrying(newbie), "bloc du Meteor Crater sur le dos")
local carry = CarryService.GetSpeedMultiplier(newbie)
T.near(GuardianService.ChaseSpeed(CRATER, newbie), crater.Speed * carry, 1e-9, "course contre lui = course de base x malus de son bloc")
T.eq(GuardianService.ChaseSpeed("Beach", newbie), 10, "gardien de la Beach : vitesse fixe")
walkHome(newbie, 300, function()
	return CarryService.IsCarrying(newbie)
end)
T.check(#caught == 1 and caught[1].Player == newbie and caught[1].Zone == CRATER, "rattrapé par le gardien du Meteor Crater")
T.check(slot.State == "Present" and slot.Block.Id == block.Id, "le bloc est retourné à son gisement")
T.check(waitFor(function()
	return crater.State == "Sleep"
end, 120), "le gardien rentre et se rendort")
T.leave(newbie)

T.section("un peu trop lent : poursuivi de zone en zone")
local glacier = Zones.ByName.Glacier
local runner = T.join({ Name = "Runner", Character = true })
env.flush()
SpeedService.Set(runner, glacier.Speed)
slot = nearestSlot(CRATER)
grab(runner, slot)
T.check(CarryService.IsCarrying(runner), "bloc du Meteor Crater sur le dos")
T.check(runner.Character.Humanoid.WalkSpeed < GuardianService.ChaseSpeed(CRATER, runner), "chargé, plus lent que le gardien")
local states = {}
walkHome(runner, 300, function()
	states[crater.State] = true
	return CarryService.IsCarrying(runner)
end)
local last = caught[#caught]
T.check(#caught == 2 and last.Player == runner and last.Zone == CRATER, "rattrapé (vitesse conseillée du Glacier au Meteor Crater)")
T.check(states.Run == true and states.Search == nil, "poursuivi sans jamais être perdu")
local beyond = outsideArea(CRATER, last.At)
T.check(beyond > Guardians.Leash, "attrapé loin de sa zone (" .. math.floor(beyond) .. " studs, laisse : " .. Guardians.Leash .. ")")
T.check(ZoneService.ZoneAt(last.At) ~= CRATER and ZoneService.ZoneAt(last.At) ~= nil, "dans une autre zone de la route (" .. tostring(ZoneService.ZoneAt(last.At)) .. ")")
local away = (flat(crater.CFrame.Position) - flat(crater.Home.Position)).Magnitude
local startedAt = env.now()
T.check(waitFor(function()
	return crater.State == "BackToSleep" or crater.State == "Sleep"
end, 120), "il rentre chez lui")
local walkTime = away / crater.ReturnSpeed
T.check(env.now() - startedAt < walkTime, string.format("loin de sa zone, il rentre à sa vitesse de course (%.0f s, à pied : %.0f s)", env.now() - startedAt, walkTime))
T.near((crater.CFrame.Position - crater.Home.Position).Magnitude, 0, 1e-6, "à sa place")
waitFor(function()
	return crater.State == "Sleep"
end, 10)
T.leave(runner)

T.section("à la vitesse conseillée : il rentre, le gardien s'arrête au bord de la place du spawn")
local pro = T.join({ Name = "Pro", Character = true })
env.flush()
SpeedService.Set(pro, Zones.ByName[CRATER].Speed)
slot = nearestSlot(CRATER)
grab(pro, slot)
T.check(CarryService.IsCarrying(pro), "bloc du Meteor Crater sur le dos")
T.check(pro.Character.Humanoid.WalkSpeed > GuardianService.ChaseSpeed(CRATER, pro), "chargé, plus rapide que le gardien")
states = {}
local inPlaza, inPark = false, false
local farthest = 0 -- distance max du gardien à sa zone
local lostIn = nil -- zone de Pro quand le gardien l'a perdu
local proPlot = PlotService.Get(pro)
walkHome(pro, 300, function()
	states[crater.State] = true
	local position = crater.CFrame.Position
	farthest = math.max(farthest, outsideArea(CRATER, position))
	if lostIn == nil and crater.State == "Search" then
		lostIn = ZoneService.ZoneAt(rootOf(pro).Position) or ""
	end
	if ZoneService.ZoneAt(position + Vector3.new(0, 3, 0)) == nil then
		inPlaza = true
	end
	if PlotService.IsSafe(position + Vector3.new(0, 3, 0)) then
		inPark = true
	end
	return CarryService.IsCarrying(pro)
end)
T.eq(#caught, 2, "jamais rattrapé")
T.check(states.Run == true and states.Search == true, "poursuivi puis perdu")
T.check(not inPlaza and not inPark, "le gardien n'est jamais allé sur la place du spawn ni dans un parc")
T.eq(lostIn, "", "il ne l'a lâché qu'à son arrivée sur la place du spawn")
T.check(farthest > 1000, string.format("il l'a suivi loin de sa zone (%.0f studs)", farthest))
local fern = ZoneService.Get("Fern Forest").Area
local beachEdge = fern.Position.Z - fern.Size.Z / 2
T.check(lostWith(pro, "Escaped"), "alerte Lost avec la raison Escaped (arrivé sur la place du spawn)")
T.eq(pro:GetAttribute("ChasedBy"), "", "plus poursuivi")
walkTo(pro, proPlot.Entrance.Position + Vector3.new(0, 3, -4), 10)
env.advance(0.3)
T.check(not CarryService.IsCarrying(pro), "bloc rapporté au parc")
T.check(waitFor(function()
	return crater.State == "Sleep"
end, 120), "le gardien rentre et se rendort")

T.section("endormi : il ne se réveille que dans sa laisse")
local entry = DroppedBlockService.Place({ Id = 880001, Rarity = "Legendary", Zone = CRATER }, fern.Position + Vector3.new(0, fern.Size.Y / 2, 0), nil, "Test")
pro.Character:PivotTo(CFrame.new(entry.Part.Position + Vector3.new(0, 1.5, 3)))
RateLimit.Reset(pro)
env.fire(env.signal(entry.Part.PickUpPrompt, "Triggered"), pro)
env.flush()
T.check(CarryService.IsCarrying(pro), "un bloc du Meteor Crater ramassé dans la Fern Forest")
env.advance(2)
T.eq(crater.State, "Sleep", "loin de sa zone, le gardien du Meteor Crater dort toujours")
CarryService.ReturnToSite(pro)

T.section("réveillé : poursuivi dans la Beach, pas sur la place du spawn")
local fernGuardian = GuardianService.Get("Fern Forest")
local camper = T.join({ Name = "Camper", Character = true })
env.flush()
SpeedService.Set(camper, 1e4)
slot = nearestSlot("Fern Forest")
local slotPosition = slot.Part.Position
grab(camper, slot)
T.check(CarryService.IsCarrying(camper), "bloc de la Fern Forest")
local beachArea = ZoneService.Get("Beach").Area
local plazaEdge = beachArea.Position.Z - beachArea.Size.Z / 2
local inBeachSpot = Vector3.new(0, slotPosition.Y + 1.5, beachEdge - 30)
camper.Character:PivotTo(CFrame.new(inBeachSpot))
T.eq(ZoneService.ZoneAt(inBeachSpot), "Beach", "Camper est dans la Beach")
env.advance(Guardians.WakeTime + Guardians.RoarTime + 1)
T.eq(fernGuardian.State, "Run", "le gardien de la Fern Forest le poursuit dans la Beach")
T.eq(camper:GetAttribute("ChasedBy"), "Fern Forest", "toujours poursuivi")
local onPlaza = Vector3.new(0, slotPosition.Y + 1.5, plazaEdge - 10)
camper.Character:PivotTo(CFrame.new(onPlaza))
T.eq(ZoneService.ZoneAt(onPlaza), nil, "Camper est sur la place du spawn (hors de toute zone)")
T.check(not PlotService.IsSafe(onPlaza), "pas dans un parc")
env.advance(0.5)
T.check(fernGuardian.State == "Search" or fernGuardian.State == "Return", "le gardien le lâche sur la place (" .. fernGuardian.State .. ")")
T.check(lostWith(camper, "Escaped"), "alerte Lost avec la raison Escaped")
local beachGuardian = GuardianService.Get("Beach")
T.check(ZoneService.ZoneAt(beachGuardian.CFrame.Position + Vector3.new(0, 3, 0)) == "Beach", "le gardien de la Beach reste sur la route")
camper.Character:PivotTo(CFrame.new(Vector3.new(0, slotPosition.Y + 1.5, plazaEdge + 20)))
T.check(waitFor(function()
	return fernGuardian.State == "Roar" or fernGuardian.State == "Run"
end, 2), "il revient sur la route : le gardien, encore réveillé, reprend la poursuite")
CarryService.ReturnToSite(camper)
T.check(waitFor(function()
	return fernGuardian.State == "Sleep"
end, 60), "puis se rendort")
T.clean("aucune erreur pendant les poursuites")

T.done("pvp_chase")
