-- Promenade des dinos dans l'enclos (Config.Park.Roam, src/shared/Roam.luau, EnclosureService) : chaque dino apparaît à
-- une place libre au hasard (plus tous dans un coin), fait une pause, puis marche vers un autre point libre de l'enclos.
-- Un trajet = attributs WalkFrom, WalkTo, Speed, State « Walk », StateAt ; le serveur ne déplace la pièce Root qu'à
-- l'arrivée. Jamais hors de l'enclos, jamais deux arrivées l'une sur l'autre. Les dinos provisoires restent sur place.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local EnclosureService = Boot.Services.EnclosureService
local PlotService = Boot.Services.PlotService
local Park = T.module("src/shared/Config/Park")
local Roam = T.module("src/shared/Roam")
local Economy = T.module("src/shared/Config/Economy")
local Species = T.module("src/shared/Config/Species")
local Vector3, CFrame = env.Vector3, env.CFrame
local typeof = env.typeof

local ROAM = Park.Roam

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

T.section("Roam.PoseAt : tourner sur place, puis marcher tout droit")
local from = CFrame.new(10, 2, 10) -- (regarde vers -Z)
local to = Vector3.new(10, 2, 40) -- (derrière lui : demi-tour)
local speed = 5
local duration = Roam.Duration(from, to, speed)
T.near(duration, ROAM.TurnTime + 30 / speed, 1e-9, "durée = demi-tour + distance / vitesse")
T.near((Roam.PoseAt(from, to, speed, 0).Position - from.Position).Magnitude, 0, 1e-9, "au départ : pose de départ")
local turning = Roam.PoseAt(from, to, speed, ROAM.TurnTime / 2)
T.near((turning.Position - from.Position).Magnitude, 0, 1e-6, "pendant le demi-tour : sur place")
local walking = Roam.PoseAt(from, to, speed, ROAM.TurnTime + 2)
T.near((walking.Position - (from.Position + Vector3.new(0, 0, 10))).Magnitude, 0, 1e-6, "puis avance de vitesse x temps")
T.check(walking.LookVector:Dot(Vector3.new(0, 0, 1)) > 0.999, "tourné vers l'arrivée (le dino regarde vers -Z du repère)")
local arrived = Roam.PoseAt(from, to, speed, duration)
T.near((arrived.Position - to).Magnitude, 0, 1e-6, "à la fin : au point d'arrivée")
T.near((Roam.PoseAt(from, to, speed, duration + 50).Position - to).Magnitude, 0, 1e-6, "après : reste à l'arrivée")
local slope = Roam.PoseAt(from, Vector3.new(10, 6, 40), speed, ROAM.TurnTime + 3)
T.near(slope.Position.Y, 2 + 4 * 0.5, 1e-6, "la hauteur suit le trajet")
T.near((Roam.PoseAt(from, from.Position, speed, 3).Position - from.Position).Magnitude, 0, 1e-9, "trajet nul : ne bouge pas")
T.check(Roam.WalkSpeed("Velociraptor") ~= nil and Roam.WalkSpeed("Velociraptor") > 0, "vitesse de marche lue dans le module DinoModels")
T.eq(Roam.WalkSpeed("NoSuchDino"), nil, "espèce sans module : nil")

T.section("places de départ : partout dans l'enclos")
local alice = T.join({ Name = "Alice", Character = true })
env.flush()
local data = T.data(alice)
data.EnclosureUpgrades = #Economy.Enclosure.Prices
local enclosure = PlotService.Get(alice).Enclosure
local half = enclosure.Size / 2

-- Le corps (rayon `radius`) est-il dans l'enclos, à Margin studs du bord ?
local function inPen(position, radius: number): boolean
	local relative = enclosure.CFrame:PointToObjectSpace(position)
	local limitX = math.max(0, half.X - radius - ROAM.Margin) + 1e-6
	local limitZ = math.max(0, half.Z - radius - ROAM.Margin) + 1e-6
	return math.abs(relative.X) <= limitX and math.abs(relative.Z) <= limitZ and math.abs(relative.Y - half.Y) < 1e-3
end

local list = { "Compy", "Velociraptor", "Triceratops", "Stegosaurus", "T-Rex", "Parasaurolophus", "Ankylosaurus", "Pteranodon" }
local dinos = {}
for k, name in list do
	local id = EnclosureService.AddDino(alice, { Species = name, Size = if k % 3 == 0 then "Big" else "Normal" }, "Idle")
	T.check(id ~= nil, name .. " dans l'enclos")
	local model = EnclosureService.ModelOf(alice, id)
	local scale = model:GetAttribute("Scale")
	table.insert(dinos, { Id = id, Name = name, Model = model, Radius = Species.ByName[name].BaseSize * scale * ROAM.Footprint, Walks = 0, Seen = {} })
end
local spread = 0
for i, a in dinos do
	local pa = a.Model.PrimaryPart.Position
	T.check(inPen(pa, a.Radius), a.Name .. " : posé dans l'enclos, loin du bord")
	for j = i + 1, #dinos do
		local b = dinos[j]
		local gap = (flat(pa) - flat(b.Model.PrimaryPart.Position)).Magnitude
		spread = math.max(spread, gap)
		T.check(gap >= a.Radius + b.Radius + ROAM.Gap - 1e-6, a.Name .. " et " .. b.Name .. " : pas l'un sur l'autre")
	end
end
T.check(spread > half.X, string.format("répartis dans tout l'enclos (%.0f studs entre les plus éloignés)", spread))

T.section("promenade")
local SECONDS = 120
local STEP = 0.25
local walking = {} -- id -> { From, To, Speed, EndsAt }
local problems = {}
local function problem(text: string)
	if #problems < 5 then
		table.insert(problems, text)
	end
end
local elapsed = 0
while elapsed < SECONDS do
	env.advance(STEP)
	elapsed += STEP
	for _, d in dinos do
		local model = d.Model
		local root = model.PrimaryPart
		local state = model:GetAttribute("State")
		local current = walking[d.Id]
		if state == "Walk" then
			local walkFrom, walkTo, walkSpeed = model:GetAttribute("WalkFrom"), model:GetAttribute("WalkTo"), model:GetAttribute("Speed")
			if not current or current.StateAt ~= model:GetAttribute("StateAt") then
				-- nouveau trajet
				d.Walks += 1
				if typeof(walkFrom) ~= "CFrame" or typeof(walkTo) ~= "Vector3" or type(walkSpeed) ~= "number" then
					problem(d.Name .. " : attributs du trajet manquants")
					continue
				end
				local leg = (flat(walkTo) - flat(walkFrom.Position)).Magnitude
				if leg < ROAM.MinLeg - 1e-6 or leg > ROAM.MaxLeg + 1e-6 then
					problem(string.format("%s : trajet de %.1f studs", d.Name, leg))
				end
				if not inPen(walkTo, d.Radius) then
					problem(d.Name .. " : arrivée hors de l'enclos")
				end
				if walkSpeed < ROAM.MinSpeed or walkSpeed > ROAM.MaxSpeed then
					problem(string.format("%s : vitesse %.2f", d.Name, walkSpeed))
				end
				if (walkFrom.Position - root.Position).Magnitude > 1e-3 then
					problem(d.Name .. " : WalkFrom n'est pas là où il était")
				end
				-- (pas d'arrivée sur la place d'un autre : à l'arrêt, ou là où il arrive)
				for _, other in dinos do
					if other ~= d then
						local otherModel = other.Model
						local otherTo = otherModel:GetAttribute("WalkTo")
						local spot = if otherModel:GetAttribute("State") == "Walk" and typeof(otherTo) == "Vector3" then otherTo else otherModel.PrimaryPart.Position
						if (flat(spot) - flat(walkTo)).Magnitude < d.Radius + other.Radius + ROAM.Gap - 1e-6 then
							problem(d.Name .. " : arrivée sur la place de " .. other.Name)
						end
					end
				end
				walking[d.Id] = { From = walkFrom, To = walkTo, Speed = walkSpeed, StateAt = model:GetAttribute("StateAt") }
				table.insert(d.Seen, walkTo)
			else
				-- (le serveur ne déplace pas la pièce Root pendant le trajet : les clients calculent la pose)
				if (root.Position - current.From.Position).Magnitude > 1e-3 then
					problem(d.Name .. " : Root déplacée pendant le trajet")
				end
			end
		elseif current then
			-- arrivé
			walking[d.Id] = nil
			local final = Roam.PoseAt(current.From, current.To, current.Speed, math.huge)
			if (root.Position - current.To).Magnitude > 1e-3 then
				problem(d.Name .. " : Root pas posée à l'arrivée")
			end
			if root.CFrame.LookVector:Dot(final.LookVector) < 0.999 then
				problem(d.Name .. " : pas tourné comme à la fin du trajet")
			end
			if model:GetAttribute("Speed") ~= 0 then
				problem(d.Name .. " : Speed pas remise à 0")
			end
			local rest = model:GetAttribute("State")
			if rest ~= "Idle" and Park.Roam.Moods[rest] == nil then
				problem(d.Name .. " : état de pause inattendu " .. tostring(rest))
			end
		end
	end
end
T.eq(#problems, 0, "trajets corrects" .. (if #problems > 0 then " : " .. table.concat(problems, " ; ") else ""))
for _, d in dinos do
	T.check(d.Walks >= 3, string.format("%s se promène (%d trajets en %d s)", d.Name, d.Walks, SECONDS))
end
local reach = 0
for _, d in dinos do
	for _, point in d.Seen do
		local relative = enclosure.CFrame:PointToObjectSpace(point)
		reach = math.max(reach, math.abs(relative.X) / half.X, math.abs(relative.Z) / half.Z)
	end
end
T.check(reach > 0.6, string.format("dans tout l'enclos, pas seulement au milieu (%.0f %% du demi-enclos)", reach * 100))

T.section("apparition : il reste un moment sur place")
local id = EnclosureService.AddDino(alice, { Species = "Velociraptor" }, "Spawn")
local model = EnclosureService.ModelOf(alice, id)
local spawnedAt = env.now()
local firstWalk = nil
while env.now() - spawnedAt < 120 do
	env.advance(STEP)
	if model:GetAttribute("State") == "Walk" then
		firstWalk = env.now() - spawnedAt
		break
	end
end
T.check(firstWalk ~= nil and firstWalk >= ROAM.SpawnRest + ROAM.RestMin - STEP, "pas de marche pendant l'apparition (" .. tostring(firstWalk) .. " s)")

T.section("dino retiré pendant un trajet")
local removed = nil
for _, d in dinos do
	if d.Model:GetAttribute("State") == "Walk" then
		removed = d
		break
	end
end
if not removed then
	env.advance(10)
	for _, d in dinos do
		if d.Model:GetAttribute("State") == "Walk" then
			removed = d
			break
		end
	end
end
T.check(removed ~= nil, "un dino en marche")
if removed then
	EnclosureService.RemoveDino(alice, removed.Id)
	env.advance(ROAM.MaxLeg / ROAM.MinSpeed + 2)
	T.eq(removed.Model.Parent, nil, "modèle retiré")
end
T.clean("aucune erreur pendant la promenade")

T.section("enclos plein : chacun a sa place")
local count = EnclosureService.Count(alice)
local slots = EnclosureService.Slots(alice)
for k = count + 1, slots do
	EnclosureService.AddDino(alice, { Species = list[(k % #list) + 1], Size = if k % 4 == 0 then "Huge" else "Normal" }, "Idle")
end
T.eq(EnclosureService.Count(alice), slots, "enclos plein (" .. slots .. " dinos)")
env.advance(60)
T.clean("enclos plein : aucune erreur")

T.done("loop_roam")
