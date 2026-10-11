-- Gardiens (brief 7) : un par zone, modèle au contrat du brief 2, réveil quand on arrache un bloc de sa zone, rugissement,
-- poursuite, prise (chute et bloc rendu au gisement), recherche, retour et sommeil. Tutoriel : le nouveau joueur
-- distance le gardien de la Beach. Trop lent pour la zone : rattrapé. Assez rapide : il abandonne. Jamais dans un parc.
-- Bear Trap sur un gardien. Gardiens éteints.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local GuardianService = Boot.Services.GuardianService
local CarryService = Boot.Services.CarryService
local DroppedBlockService = Boot.Services.DroppedBlockService
local DigSiteService = Boot.Services.DigSiteService
local PlotService = Boot.Services.PlotService
local PvpService = Boot.Services.PvpService
local SpeedService = Boot.Services.SpeedService
local ZoneService = Boot.Services.ZoneService
local AdminService = Boot.Services.AdminService
local Guardians = T.module("src/shared/Config/Guardians")
local SpeedConfig = T.module("src/shared/Config/Speed")
local Zones = T.module("src/shared/Config/Zones")
local Pvp = T.module("src/shared/Config/Pvp")
local Species = T.module("src/shared/Config/Species")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local CollectionService = env.game:GetService("CollectionService")
local Vector3, CFrame = env.Vector3, env.CFrame

local STEP = 0.1

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Avance le temps jusqu'à condition() (false au bout de `limit` secondes, sans erreur)
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

local function slots(zone: string): { any }
	local list = {}
	for _, site in DigSiteService.Sites() do
		if site.Zone == zone then
			for _, slot in site.Slots do
				if slot.State == "Present" then
					table.insert(list, slot)
				end
			end
		end
	end
	return list
end

-- Bloc présent de la zone le plus loin du spawn (le gardien est entre lui et les parcs) ou le plus près
local function slotBy(zone: string, farthest: boolean, filter: ((any) -> boolean)?): any
	local best, bestZ = nil, nil
	for _, slot in slots(zone) do
		if not filter or filter(slot) then
			local z = slot.Part.Position.Z
			if bestZ == nil or (farthest and z > bestZ) or (not farthest and z < bestZ) then
				best, bestZ = slot, z
			end
		end
	end
	return best
end

local function grab(player, slot)
	RateLimit.Reset(player)
	local part = slot.Part
	player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 1.5, 4)))
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

local function lastNotify(player): string?
	local list = env.received(player, "Notify")
	local last = list[#list]
	return if last then last[1] else nil
end

local function received(player, name: string, first: any): boolean
	for _, args in env.received(player, name) do
		if args[1] == first then
			return true
		end
	end
	return false
end

-- Le joueur a-t-il reçu GuardianAlert(_, "Lost", reason) ?
local function lostWith(player, reason: string): boolean
	for _, args in env.received(player, "GuardianAlert") do
		if args[2] == "Lost" and args[3] == reason then
			return true
		end
	end
	return false
end

local caught = {}
Signals.Connect("GuardianCaught", function(player, zone, block)
	table.insert(caught, { Player = player, Zone = zone, Block = block })
end)
local woke = {}
Signals.Connect("GuardianWoke", function(zone, player)
	table.insert(woke, { Zone = zone, Player = player })
end)

T.section("un gardien par zone")
local list = GuardianService.List()
T.eq(#list, #Zones.List, "8 gardiens")
local folder = env.game:GetService("Workspace"):FindFirstChild("Guardians")
T.check(folder ~= nil, "dossier Workspace.Guardians")
local previousSpeed = 0
for index, zone in Zones.List do
	local g = GuardianService.Get(zone.Name)
	T.check(g ~= nil and list[index] == g, zone.Name .. " : gardien dans l'ordre de la route")
	local model = g.Model
	local info = Guardians.Zones[zone.Name]
	T.check(CollectionService:HasTag(model, "Dino") and CollectionService:HasTag(model, "Guardian"), zone.Name .. " : tags Dino et Guardian")
	T.eq(model.Parent, folder, zone.Name .. " : dans Workspace.Guardians")
	T.eq(model.PrimaryPart and model.PrimaryPart.Name, "Root", zone.Name .. " : pivot Root")
	T.eq(model.PrimaryPart.Transparency, 1, zone.Name .. " : Root invisible")
	T.eq(model.ModelStreamingMode, env.Enum.ModelStreamingMode.Persistent, zone.Name .. " : Persistent (toujours chez le client)")
	T.eq(model:GetAttribute("Species"), (string.gsub(info.Species, "[^%w]", "")), zone.Name .. " : attribut Species (nom du module DinoModels)")
	T.eq(model:GetAttribute("Scale"), info.Scale, zone.Name .. " : attribut Scale")
	T.check(info.Scale >= 1.5 and info.Scale <= 3, zone.Name .. " : x1.5 à x3")
	T.eq(model:GetAttribute("State"), "Sleep", zone.Name .. " : dort au départ")
	T.check(type(model:GetAttribute("StateAt")) == "number", zone.Name .. " : StateAt")
	T.eq(model:GetAttribute("Speed"), 0, zone.Name .. " : immobile")
	T.eq(model:GetAttribute("Guardian"), zone.Name, zone.Name .. " : attribut Guardian")
	T.eq(model:GetAttribute("TargetUserId"), 0, zone.Name .. " : sans cible")
	local dinoModels = env.game:GetService("ReplicatedStorage").Shared:FindFirstChild("DinoModels")
	T.check(dinoModels and dinoModels:FindFirstChild(model:GetAttribute("Species")) ~= nil, zone.Name .. " : l'espèce a son module DinoModels")
	T.eq(#model:GetChildren(), 1, zone.Name .. " : seulement Root, le client construit les briques")
	T.near(g.Size, Species.ByName[info.Species].BaseSize * info.Scale, 1e-6, zone.Name .. " : taille = BaseSize de l'espèce x Scale")
	local anchor = ZoneService.Get(zone.Name).Guardian
	T.near((g.CFrame.Position - (anchor.Position + Vector3.new(0, anchor.Size.Y / 2, 0))).Magnitude, 0, 1e-6, zone.Name .. " : dort sur le point Guardian")
	T.check(not PlotService.IsSafe(g.CFrame.Position), zone.Name .. " : sur la route")
	T.check(g.Speed >= previousSpeed, zone.Name .. " : plus loin, plus rapide")
	previousSpeed = g.Speed
end
T.eq(GuardianService.Get("Beach").Speed, 10, "gardien de la Beach lent (tutoriel)")
T.near(GuardianService.Get("Fern Forest").Speed, Guardians.SpeedFactor * SpeedConfig.WalkSpeedFor(1e3), 1e-9, "Fern Forest : 0.75 x WalkSpeed conseillé")
T.check(GuardianService.Get("Beach").Speed < SpeedConfig.WalkSpeedFor(0) * 0.9, "un nouveau joueur chargé d'un Common va plus vite que le gardien de la Beach")

T.section("réveil, rugissement, poursuite, prise")
local alice = T.join({ Name = "Alice", Character = true })
env.flush()
local beach = GuardianService.Get("Beach")
local slot = slotBy("Beach", false)
local block = slot.Block
grab(alice, slot)
T.check(CarryService.IsCarrying(alice), "Alice porte un bloc de la Beach")
T.eq(beach.State, "Wake", "le gardien se réveille")
T.eq(beach.Model:GetAttribute("State"), "Wake", "attribut State = Wake")
T.eq(beach.Model:GetAttribute("TargetUserId"), alice.UserId, "cible : Alice")
T.eq(alice:GetAttribute("ChasedBy"), "Beach", "attribut ChasedBy d'Alice")
T.check(#woke == 1 and woke[1].Zone == "Beach" and woke[1].Player == alice, "signal GuardianWoke")
T.eq(GuardianService.Get("Fern Forest").State, "Sleep", "les autres gardiens dorment")
local grabbedAt = env.now()
T.check(waitFor(function()
	return beach.State == "Roar"
end, 3), "puis rugit")
T.eq(lastNotify(alice), "RUN!! The guardian woke up!", "« RUN!! »")
T.check(received(alice, "GuardianAlert", "Beach"), "alerte gardien envoyée à Alice")
T.check(waitFor(function()
	return beach.State == "Run"
end, 3), "puis court")
local home = beach.Home.Position
env.advance(0.3)
T.eq(beach.Model:GetAttribute("Speed"), 10, "attribut Speed = vitesse de course (cadence de la marche)")
T.check((flat(beach.CFrame.Position) - flat(home)).Magnitude > 1, "le pivot se déplace")
T.check((flat(rootOf(alice).Position) - flat(beach.CFrame.Position)).Magnitude < (flat(rootOf(alice).Position) - flat(home)).Magnitude, "vers Alice")
local look = beach.CFrame.LookVector
local toward = (flat(rootOf(alice).Position) - flat(beach.CFrame.Position)).Unit
T.check(look:Dot(toward) > 0.99, "tourné vers Alice (le dino regarde vers -Z)")
T.check(waitFor(function()
	return #caught > 0
end, 20), "Alice, immobile, est attrapée")
T.check(env.now() - grabbedAt >= Guardians.WakeTime + Guardians.RoarTime, "pas avant la fin du réveil et du rugissement")
T.check(caught[1] and caught[1].Player == alice and caught[1].Zone == "Beach" and caught[1].Block.Id == block.Id, "signal GuardianCaught")
T.check(not CarryService.IsCarrying(alice), "Alice a perdu le bloc")
T.check(slot.State == "Present" and slot.Block.Id == block.Id, "le bloc est retourné à son gisement")
T.eq(beach.State, "Catch", "état Catch")
T.eq(alice:GetAttribute("ChasedBy"), "", "plus poursuivie")
T.check(SpeedService.HasModifier(alice, "Knocked"), "Alice au sol (immobile)")
SpeedService.Refresh(alice)
T.eq(alice.Character.Humanoid.WalkSpeed, 0, "WalkSpeed 0 pendant la chute")
local knocked = env.received(alice, "Knocked")
T.check(#knocked == 1 and knocked[1][1] == Guardians.KnockTime and knocked[1][2] == "Catch", "remote Knocked (2 s, Catch)")
T.eq(lastNotify(alice), "Caught by the guardian! The fossil went back to its dig site.", "message de la prise")
local effects = env.received(alice, "PvpEffect")
T.check(#effects == 1 and effects[1][1] == "Catch", "effet Catch pour tous")
T.check(waitFor(function()
	return beach.State == "Return"
end, 3), "puis rentre à son gisement")
T.check(waitFor(function()
	return beach.State == "BackToSleep"
end, 60), "se recouche chez lui")
T.near((beach.CFrame.Position - home).Magnitude, 0, 1e-6, "à sa place")
T.check(waitFor(function()
	return beach.State == "Sleep"
end, 5), "dort à nouveau")
T.eq(beach.Model:GetAttribute("Speed"), 0, "immobile")
T.check(not SpeedService.HasModifier(alice, "Knocked"), "Alice relevée")
T.clean("aucune erreur pendant la poursuite")

T.section("tutoriel : distancer le gardien de la Beach")
local newbie = T.join({ Name = "Newbie", Character = true })
env.flush()
local joinedAt = env.now()
T.eq(T.data(newbie).Tutorial, 0, "nouveau joueur")
local common = slotBy("Beach", true, function(s)
	return s.Block.Rarity == "Common"
end)
T.check(common ~= nil, "un bloc Common à la Beach")
local caughtBefore = #caught
grab(newbie, common)
T.check(CarryService.IsCarrying(newbie), "bloc Common sur le dos")
T.near(newbie.Character.Humanoid.WalkSpeed, SpeedConfig.WalkSpeedFor(0) * 0.9, 1e-6, "WalkSpeed d'un nouveau chargé d'un Common")
local plot = PlotService.Get(newbie)
local outside = plot.Entrance.Position + Vector3.new(0, 3, 8)
local inside = plot.Entrance.Position + Vector3.new(0, 3, -4)
local lostHim = false
walkTo(newbie, outside, 60, function()
	if beach.State == "Search" or beach.State == "Return" then
		lostHim = true
	end
	return CarryService.IsCarrying(newbie)
end)
T.eq(#caught, caughtBefore, "jamais rattrapé")
T.check(lostHim, "le gardien l'a perdu (Search puis Return)")
walkTo(newbie, inside, 10)
env.advance(0.3)
T.check(not CarryService.IsCarrying(newbie), "rentré au parc : le bloc est à lui")
T.eq(T.data(newbie).Tutorial, 2, "tutoriel : premier bloc rapporté")
T.check(env.now() - joinedAt < 90, "bloc rapporté en moins de 90 s (" .. math.floor(env.now() - joinedAt) .. " s)")
T.eq(newbie:GetAttribute("ChasedBy"), "", "plus poursuivi")
waitFor(function()
	return beach.State == "Sleep"
end, 60)
T.eq(beach.State, "Sleep", "le gardien s'est rendormi")

T.section("trop lent pour la zone : rattrapé")
local fern = GuardianService.Get("Fern Forest")
local slow = T.join({ Name = "Slow", Character = true })
env.flush()
T.eq(SpeedService.Get(slow), 0, "vitesse 0 (zone conseillée : 1 K)")
local far = slotBy("Fern Forest", true)
caughtBefore = #caught
grab(slow, far)
T.check(CarryService.IsCarrying(slow), "bloc de la Fern Forest")
walkTo(slow, PlotService.Get(slow).Entrance.Position + Vector3.new(0, 3, 8), 60, function()
	return CarryService.IsCarrying(slow)
end)
T.check(#caught == caughtBefore + 1 and caught[#caught].Player == slow and caught[#caught].Zone == "Fern Forest", "rattrapé par le gardien de la Fern Forest")
T.check(far.State == "Present", "bloc rendu au gisement")
waitFor(function()
	return fern.State == "Sleep"
end, 90)
T.eq(fern.State, "Sleep", "le gardien s'est rendormi")

T.section("assez rapide : le gardien abandonne")
local fast = T.join({ Name = "Fast", Character = true })
env.flush()
SpeedService.Set(fast, 1e4)
-- (le gisement le plus loin : il repasse devant le gardien, qui le poursuit jusqu'à la Beach)
local farSlot = slotBy("Fern Forest", true)
caughtBefore = #caught
grab(fast, farSlot)
T.check(CarryService.IsCarrying(fast), "bloc de la Fern Forest")
T.check(fast.Character.Humanoid.WalkSpeed > fern.Speed, "chargé, il court plus vite que le gardien")
local states = {}
local fastPlot = PlotService.Get(fast)
walkTo(fast, fastPlot.Entrance.Position + Vector3.new(0, 3, 8), 60, function()
	states[fern.State] = true
	return CarryService.IsCarrying(fast)
end)
T.eq(#caught, caughtBefore, "jamais rattrapé")
T.check(states.Run and states.Search, "poursuite puis recherche")
T.check(lostWith(fast, "Escaped") and not lostWith(fast, "Dropped"), "alerte Lost avec la raison Escaped (semé)")
T.check(CarryService.IsCarrying(fast), "toujours chargé devant son parc")
T.check(waitFor(function()
	return fern.State == "Sleep"
end, 90), "le gardien rentre et se rendort")
walkTo(fast, fastPlot.Entrance.Position + Vector3.new(0, 3, -4), 10)
env.advance(0.3)
T.check(not CarryService.IsCarrying(fast), "bloc rapporté")

T.section("jamais dans un parc")
Guardians.Leash = 1000 -- (laisse très longue : seule la règle du parc l'arrête)
-- (serveurs de 5 joueurs : Newbie et Slow s'en vont, pour qu'il reste un parc libre)
T.leave(newbie)
T.leave(slow)
local runner = T.join({ Name = "Runner", Character = true })
env.flush()
SpeedService.Set(runner, 1e3)
local start = slotBy("Beach", false)
grab(runner, start)
T.check(CarryService.IsCarrying(runner), "bloc de la Beach")
local emptyPlot = PlotService.ByIndex(PlotService.Count)
T.eq(emptyPlot.Owner, nil, "dernier parc libre")
local everInPark = false
local goal = emptyPlot.Floor.Position + Vector3.new(0, 3, 0)
walkTo(runner, goal, 60, function()
	if PlotService.IsSafe(beach.CFrame.Position + Vector3.new(0, 3, 0)) then
		everInPark = true
	end
	return true
end)
T.check(PlotService.IsSafe(rootOf(runner).Position), "Runner dans un parc (pas le sien)")
T.check(CarryService.IsCarrying(runner), "toujours chargé (le parc d'un autre ne prend pas le bloc)")
env.advance(5)
T.check(not everInPark and not PlotService.IsSafe(beach.CFrame.Position + Vector3.new(0, 3, 0)), "le gardien n'entre pas dans le parc")
T.check(CarryService.IsCarrying(runner), "pas attrapé dans le parc")
T.check(beach.State == "Search" or beach.State == "Return" or beach.State == "BackToSleep" or beach.State == "Sleep", "il abandonne (" .. beach.State .. ")")
T.check(lostWith(runner, "Safe"), "alerte Lost avec la raison Safe (dans un parc)")
Guardians.Leash = 40
CarryService.ReturnToSite(runner)
waitFor(function()
	return beach.State == "Sleep"
end, 90)

T.section("bloc ramassé au sol : le gardien se réveille")
T.eq(beach.State, "Sleep", "le gardien de la Beach dort")
local finder = T.join({ Name = "Finder", Character = true })
env.flush()
local function pickUpLoose(player, id: number, ground: Vector3)
	local entry = DroppedBlockService.Place({ Id = id, Rarity = "Rare", Zone = "Beach" }, ground, nil, "Test")
	player.Character:PivotTo(CFrame.new(entry.Part.Position + Vector3.new(0, 1.5, 3)))
	RateLimit.Reset(player)
	env.fire(env.signal(entry.Part.PickUpPrompt, "Triggered"), player)
	env.flush()
end
-- loin de sa zone : il dort toujours
local canyon = ZoneService.Get("Canyon").Area
pickUpLoose(finder, 990001, canyon.Position + Vector3.new(0, canyon.Size.Y / 2, 0))
T.check(CarryService.IsCarrying(finder), "Finder ramasse un bloc de la Beach au Canyon")
env.advance(1)
T.eq(beach.State, "Sleep", "loin de sa zone : le gardien dort toujours")
CarryService.ReturnToSite(finder)
-- près de lui : il se réveille contre celui qui l'a ramassé
pickUpLoose(finder, 990002, beach.Home.Position + Vector3.new(0, 0, 30))
T.check(CarryService.IsCarrying(finder), "Finder ramasse un bloc de la Beach près du gardien")
T.check(waitFor(function()
	return beach.State == "Wake"
end, 0.5), "le gardien se réveille")
T.eq(beach.Target, finder, "contre Finder")
T.check(waitFor(function()
	return beach.State == "Run"
end, 5), "et le poursuit")
env.advance(1)

T.section("bloqué en rentrant : il réapparaît chez lui")
finder.Character:PivotTo(CFrame.new(canyon.Position + Vector3.new(0, canyon.Size.Y / 2 + 3, 0)))
T.check(waitFor(function()
	return beach.State == "Return"
end, 10), "Finder hors de portée : recherche puis retour")
local returnSpeed = beach.ReturnSpeed
local away = (flat(beach.CFrame.Position) - flat(beach.Home.Position)).Magnitude
T.check(away > 2, "loin de chez lui (" .. math.floor(away) .. " studs)")
beach.ReturnSpeed = 0 -- (comme un parc sur le chemin : il n'avance plus)
local startedAt = env.now()
T.check(waitFor(function()
	return beach.State == "BackToSleep"
end, away / returnSpeed + Guardians.ReturnSlack + 1), "il se recouche au bout de distance / vitesse + 5 s")
T.check(env.now() - startedAt >= Guardians.ReturnSlack - 0.2, "pas avant l'échéance")
T.near((beach.CFrame.Position - beach.Home.Position).Magnitude, 0, 1e-6, "replacé chez lui")
beach.ReturnSpeed = returnSpeed
CarryService.ReturnToSite(finder)
waitFor(function()
	return beach.State == "Sleep"
end, 10)
T.leave(finder)

T.section("Bear Trap sur un gardien")
local trapper = T.join({ Name = "Trapper", Character = true })
local prey = T.join({ Name = "Prey", Character = true })
env.flush()
PvpService.GiveTraps(trapper, 1)
local target = slotBy("Beach", true)
local path = beach.Home.Position + (flat(target.Part.Position) - flat(beach.Home.Position)) * 0.5
trapper.Character:PivotTo(CFrame.new(path.X, beach.Home.Position.Y + 3, path.Z))
RateLimit.Reset(trapper)
env.fireServer(trapper, "PlaceTrap")
env.flush()
T.eq(#PvpService.Traps(), 1, "piège posé entre le gardien et le gisement")
trapper.Character:PivotTo(CFrame.new(0, 3, -30))
grab(prey, target)
T.check(CarryService.IsCarrying(prey), "Prey porte un bloc de la Beach")
local trappedSeen = false
local frozenFrom, frozenTo = nil, nil
local closed = false
T.check(waitFor(function()
	if beach.Model:GetAttribute("Trapped") == true then
		trappedSeen = true
		local trap = PvpService.Traps()[1]
		closed = closed or (trap ~= nil and trap.Armed == false and trap.Model:GetAttribute("Armed") == false)
		frozenFrom = frozenFrom or beach.CFrame.Position
		frozenTo = beach.CFrame.Position
		T.eq(beach.Model:GetAttribute("State"), Guardians.TrappedState, "animation pendant le piège")
		T.eq(beach.Model:GetAttribute("Speed"), 0, "immobile dans le piège")
	end
	return trappedSeen and beach.Model:GetAttribute("Trapped") == false
end, 30), "le gardien marche sur le piège puis s'en libère")
T.check(frozenFrom ~= nil and (frozenFrom - frozenTo).Magnitude < 1e-6, "il ne bouge pas pendant qu'il est pris")
T.check(closed, "piège refermé sur le gardien")
T.check(waitFor(function()
	return #PvpService.Traps() == 0
end, Pvp.Trap.HoldTime + 1), "piège retiré après la prise")
T.eq(beach.State, "Run", "il reprend la poursuite")
CarryService.ReturnToSite(prey)
waitFor(function()
	return beach.State == "Sleep"
end, 90)
T.check(lostWith(prey, "Dropped") and not lostWith(prey, "Escaped"), "bloc perdu pendant la poursuite : alerte Lost avec la raison Dropped")

T.section("gardiens éteints")
GuardianService.SetEnabled(false)
local calm = slotBy("Beach", false)
grab(prey, calm)
T.check(CarryService.IsCarrying(prey), "bloc pris")
env.advance(10)
T.eq(beach.State, "Sleep", "éteints : il dort")
T.check(CarryService.IsCarrying(prey), "pas attrapé")
CarryService.ReturnToSite(prey)
local ok, text = AdminService.Run(alice, "guardians", { "on" })
T.check(ok and text == "Guardians on", "commande d'admin « guardians on »")
T.check(GuardianService.IsEnabled(), "rallumés")
T.check(not AdminService.Run(alice, "guardians", { "maybe" }), "commande mal écrite refusée")

T.section("départ du joueur poursuivi")
local leaver = T.join({ Name = "Leaver", Character = true })
env.flush()
grab(leaver, slotBy("Beach", false))
T.check(waitFor(function()
	return beach.State == "Run"
end, 5), "poursuite")
T.leave(leaver)
env.advance(0.5)
T.check(beach.State == "Search" or beach.State == "Return", "il perd sa cible")
T.eq(beach.Model:GetAttribute("TargetUserId"), 0, "plus de cible")
T.check(waitFor(function()
	return beach.State == "Sleep"
end, 90), "et se rendort")

T.done("pvp_guardians")
