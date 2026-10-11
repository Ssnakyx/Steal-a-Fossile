--!strict
-- Gardiens des zones (brief 7 « gardiens-vol », GDD sections Carte et Animations) : un dino géant par zone dort sur le
-- point « Guardian » de sa zone (docs/BOUCLE.md). Quand un bloc de sa zone est arraché (ou qu'un porteur d'un bloc de
-- sa zone passe à portée), il se réveille, rugit (« RUN!! ») et poursuit le porteur sur toute la route, jusqu'au bord
-- de la Beach (Config.Guardians.SafeZones) ; plus la zone est loin, plus il court vite (Config.Guardians : un peu moins
-- vite qu'un joueur à la vitesse conseillée de la zone, chargé du même bloc). S'il l'attrape : chute cartoon, le bloc
-- retourne à son gisement. Il n'entre jamais dans un parc ni dans la Beach (sauf celui de la Beach, qui garde sa
-- laisse : sa zone + Leash studs) : il cherche, puis rentre chez lui et se rendort (coincé en rentrant, il y
-- réapparaît). Un Bear Trap le bloque 3 s (PvpService).
-- États (noms identiques aux animations du brief 2) : Sleep, Wake, Roar, Run, Catch, Search, Return, BackToSleep.
-- Modèle : contrat du brief 2 (DinoAnimController) : Model tagué « Dino » (et « Guardian ») dans Workspace.Guardians,
-- pièce invisible « Root » au sol (PrimaryPart), attributs Species, Scale, State, StateAt, Speed (studs/s, cadence de
-- la marche), plus Guardian (nom de la zone), TargetUserId (0 sans cible) et Trapped. Le serveur ne fait que déplacer
-- le pivot 10 fois par seconde : le client lisse et anime. Sans module DinoModels pour l'espèce, un gardien provisoire
-- en briques est posé ici.
-- Attribut joueur « ChasedBy » : zone du gardien qui le poursuit ("" sinon). Remote GuardianAlert au joueur visé
-- (zone, état, et pour Lost la raison : Safe, Escaped ou Dropped).
-- Signaux : GuardianStateChanged(zone, state), GuardianWoke(zone, player), GuardianCaught(player, zone, block)
-- Écoute : BlockGrabbed(player, block)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GuardiansConfig = require(ReplicatedStorage.Shared.Config.Guardians)
local Pvp = require(ReplicatedStorage.Shared.Config.Pvp)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local CarryService = require(script.Parent.CarryService)
local EnclosureService = require(script.Parent.EnclosureService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local PvpService = require(script.Parent.PvpService)
local ZoneService = require(script.Parent.ZoneService)

export type Guardian = {
	Zone: string,
	Species: string,
	Area: BasePart, -- étendue de la zone (endormi, réveil jusqu'à Leash studs au-delà)
	Model: Model,
	Home: CFrame, -- où il dort (point Guardian de la zone, au sol, tourné comme lui)
	CFrame: CFrame, -- où il est (au sol)
	State: string,
	StateEndsAt: number, -- os.clock() de la fin d'un état minuté
	Target: Player?,
	Speed: number, -- course de base (studs/s) ; contre un porteur, x le malus de son bloc (sauf FixedSpeed)
	FixedSpeed: boolean, -- Speed donnée par la config (Beach) : la même contre tous
	ReturnSpeed: number,
	CatchRange: number,
	Size: number, -- taille (studs) : taille de base de l'espèce x Scale
	TrappedUntil: number, -- os.clock()
}

local GuardianService = {}

local guardians: { Guardian } = {}
local byZone: { [string]: Guardian } = {}
local chased: { [Player]: string } = {}
local enabled = true
local folder: Folder? = nil

-- ===================================================================== modèle

local function container(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Guardians"
	created.Parent = Workspace
	folder = created
	return created
end

local function hasDinoModel(moduleName: string): boolean
	local models = ReplicatedStorage.Shared:FindFirstChild("DinoModels")
	local module = models and models:FindFirstChild(moduleName)
	return module ~= nil and module:IsA("ModuleScript")
end

local function placeholderPart(name: string, size: Vector3, offset: Vector3, base: CFrame, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = base * CFrame.new(offset)
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

-- Gardien provisoire en briques (espèce sans module DinoModels) : corps, tête vers -Z, queue, pattes, yeux
local function buildPlaceholder(model: Model, base: CFrame, b: number)
	local skin = Color3.fromRGB(95, 110, 70)
	placeholderPart("Body", Vector3.new(0.4, 0.35, 0.75) * b, Vector3.new(0, 0.45, 0) * b, base, skin, model)
	placeholderPart("Head", Vector3.new(0.3, 0.28, 0.32) * b, Vector3.new(0, 0.72, -0.45) * b, base, skin, model)
	placeholderPart("Tail", Vector3.new(0.16, 0.16, 0.5) * b, Vector3.new(0, 0.45, 0.6) * b, base, skin, model)
	placeholderPart("LegLeft", Vector3.new(0.12, 0.3, 0.12) * b, Vector3.new(-0.12, 0.15, 0) * b, base, skin, model)
	placeholderPart("LegRight", Vector3.new(0.12, 0.3, 0.12) * b, Vector3.new(0.12, 0.15, 0) * b, base, skin, model)
	local eye = Color3.fromRGB(255, 220, 60)
	placeholderPart("EyeLeft", Vector3.new(0.05, 0.05, 0.02) * b, Vector3.new(-0.09, 0.78, -0.61) * b, base, eye, model)
	placeholderPart("EyeRight", Vector3.new(0.05, 0.05, 0.02) * b, Vector3.new(0.09, 0.78, -0.61) * b, base, eye, model)
end

local function buildModel(zone: string, info: GuardiansConfig.GuardianInfo, home: CFrame): (Model, number)
	local moduleName = EnclosureService.ModelName(info.Species)
	local speciesInfo = IncomeService.SpeciesInfo(info.Species)
	local baseSize = if speciesInfo and Guard.Number(speciesInfo.BaseSize, 0.1) then speciesInfo.BaseSize else GuardiansConfig.DefaultSize
	local size = baseSize * info.Scale
	local model = Instance.new("Model")
	model.Name = zone .. " Guardian"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = home
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Species", moduleName)
	model:SetAttribute("Scale", info.Scale)
	model:SetAttribute("State", "Sleep")
	model:SetAttribute("StateAt", Workspace:GetServerTimeNow())
	model:SetAttribute("Speed", 0)
	model:SetAttribute("Guardian", zone)
	model:SetAttribute("TargetUserId", 0)
	model:SetAttribute("Trapped", false)
	if not hasDinoModel(moduleName) then
		buildPlaceholder(model, home, size)
	end
	model:AddTag("Dino")
	model:AddTag("Guardian")
	-- (StreamingEnabled : toujours chez tous les clients, avec sa pièce Root, même loin de sa zone)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = container()
	return model, size
end

-- ===================================================================== états

local function setChased(player: Player, zone: string)
	if (chased[player] or "") == zone then
		return
	end
	if zone == "" then
		chased[player] = nil
	else
		chased[player] = zone
	end
	if player.Parent == Players then
		player:SetAttribute("ChasedBy", zone)
	end
end

local function alert(player: Player?, zone: string, state: string, reason: string?)
	if player and player.Parent == Players then
		Remotes.Event("GuardianAlert"):FireClient(player, zone, state, reason)
	end
end

local function setTarget(g: Guardian, target: Player?)
	local previous = g.Target
	if previous == target then
		return
	end
	if previous and chased[previous] == g.Zone then
		setChased(previous, "")
	end
	g.Target = target
	g.Model:SetAttribute("TargetUserId", if target then target.UserId else 0)
	if target then
		setChased(target, g.Zone)
	end
end

local function setState(g: Guardian, state: string, duration: number?)
	g.State = state
	g.StateEndsAt = os.clock() + (duration or 0)
	if os.clock() >= g.TrappedUntil then
		g.Model:SetAttribute("State", state)
		g.Model:SetAttribute("StateAt", Workspace:GetServerTimeNow())
	end
	if state ~= "Run" and state ~= "Return" then
		g.Model:SetAttribute("Speed", 0)
	end
	Signals.Fire("GuardianStateChanged", g.Zone, state)
end

local function place(g: Guardian, cframe: CFrame)
	g.CFrame = cframe
	g.Model:PivotTo(cframe)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local root = Guard.Root(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or (humanoid and humanoid.Health <= 0) then
		return nil
	end
	return root
end

-- La position est-elle dans la zone du gardien (ou à moins de Leash studs) ?
local function inLeash(g: Guardian, position: Vector3): boolean
	local relative = g.Area.CFrame:PointToObjectSpace(position)
	local half = g.Area.Size / 2
	local leash = GuardiansConfig.Leash
	return math.abs(relative.X) <= half.X + leash and math.abs(relative.Z) <= half.Z + leash
end

-- La position est-elle dans une zone sûre qui n'est pas la sienne (la Beach pour les autres gardiens) ?
local function inForeignSafeZone(g: Guardian, position: Vector3): boolean
	local zone = ZoneService.ZoneAt(position)
	return zone ~= nil and zone ~= g.Zone and GuardiansConfig.SafeZones[zone] == true
end

-- Peut-il poursuivre jusqu'ici ? Dans sa zone (+ Leash) toujours ; réveillé (`wide`), sur toute la route
-- (ChaseWholeRoute). Jamais dans une zone sûre qui n'est pas la sienne ; le gardien d'une zone sûre garde sa laisse.
local function inChase(g: Guardian, position: Vector3, wide: boolean): boolean
	local zone = ZoneService.ZoneAt(position)
	if zone ~= nil and zone ~= g.Zone and GuardiansConfig.SafeZones[zone] then
		return false
	end
	if inLeash(g, position) then
		return true
	end
	return wide and GuardiansConfig.ChaseWholeRoute and zone ~= nil and not GuardiansConfig.SafeZones[g.Zone]
end

-- Le joueur est-il une proie pour ce gardien ? (porte un bloc de sa zone, sur la route, hors d'un parc ; à portée de
-- laisse s'il dort, partout sur la route jusqu'à la Beach s'il est réveillé : `wide`)
local function isPrey(g: Guardian, player: Player, wide: boolean): boolean
	if player.Parent ~= Players then
		return false
	end
	local block = CarryService.Get(player)
	local root = rootOf(player)
	return block ~= nil and block.Zone == g.Zone and root ~= nil and not PlotService.IsSafe(root.Position) and inChase(g, root.Position, wide)
end

-- Proie la plus proche du gardien (nil s'il n'y en a pas)
local function nearestPrey(g: Guardian, wide: boolean): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if isPrey(g, player, wide) then
			local distance = (flat((rootOf(player) :: BasePart).Position) - flat(g.CFrame.Position)).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

-- Raycast du sol : sans les gardiens, les personnages, les blocs au sol et les pièges (filtre refait une fois par tour)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function refreshGroundFilter()
	local ignore: { Instance } = { container() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, name in { "DroppedFossils", "BearTraps" } do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
end

-- Hauteur du sol sous une position (raycast ; sinon la hauteur où il dort)
local function groundY(g: Guardian, position: Vector3): number
	local result = Workspace:Raycast(Vector3.new(position.X, g.Home.Position.Y + 40, position.Z), Vector3.new(0, -120, 0), groundParams)
	return if result then result.Position.Y else g.Home.Position.Y
end

-- Avance vers `goal` (sur le sol) d'au plus speed x dt, en s'arrêtant à `stop` studs. Renvoie la distance restante.
local function moveToward(g: Guardian, goal: Vector3, speed: number, dt: number, stop: number): number
	local here = g.CFrame.Position
	local offset = flat(goal) - flat(here)
	local distance = offset.Magnitude
	if distance < 1e-3 then
		g.Model:SetAttribute("Speed", 0)
		return 0
	end
	local direction = offset / distance
	local step = math.min(speed * dt, math.max(0, distance - stop))
	local nextFlat = flat(here) + direction * step
	local nextPosition = Vector3.new(nextFlat.X, groundY(g, nextFlat), nextFlat.Z)
	-- (jamais dans un parc ni dans la Beach s'il n'en est pas le gardien : il s'arrête au bord)
	local lifted = nextPosition + Vector3.new(0, 3, 0)
	if PlotService.IsSafe(lifted) or inForeignSafeZone(g, lifted) then
		g.Model:SetAttribute("Speed", 0)
		return distance
	end
	place(g, CFrame.lookAt(nextPosition, nextPosition + direction))
	g.Model:SetAttribute("Speed", if step > 0 then speed else 0)
	return distance - step
end

local function face(g: Guardian, position: Vector3)
	local here = g.CFrame.Position
	local offset = flat(position) - flat(here)
	if offset.Magnitude > 0.1 then
		place(g, CFrame.lookAt(here, here + offset.Unit))
	end
end

-- Vitesse de course contre ce porteur : course de base x le malus de son bloc (MatchCarry), ou Speed fixe (Beach)
local function chaseSpeed(g: Guardian, target: Player): number
	if g.FixedSpeed or not GuardiansConfig.MatchCarry then
		return g.Speed
	end
	return g.Speed * CarryService.GetSpeedMultiplier(target)
end

local function wake(g: Guardian, player: Player)
	setTarget(g, player)
	setState(g, "Wake", GuardiansConfig.WakeTime)
	Signals.Fire("GuardianWoke", g.Zone, player)
end

local function roar(g: Guardian, target: Player)
	setTarget(g, target)
	setState(g, "Roar", GuardiansConfig.RoarTime)
	alert(target, g.Zone, "Roar")
	Notify.Send(target, "RUN!! The guardian woke up!", "error")
end

local function startRun(g: Guardian, target: Player)
	setTarget(g, target)
	setState(g, "Run")
	alert(target, g.Zone, "Run")
end

-- Rentre chez lui en marchant (avec une échéance : s'il reste coincé, il réapparaît chez lui)
local function goHome(g: Guardian)
	local distance = (flat(g.Home.Position) - flat(g.CFrame.Position)).Magnitude
	setState(g, "Return", distance / g.ReturnSpeed + GuardiansConfig.ReturnSlack)
end

-- Pourquoi le gardien lâche ce joueur : Safe (rentré dans un parc), Dropped (plus de bloc de sa zone, ou mort) ou
-- Escaped (arrivé à la Beach avec son bloc, ou hors de portée). Seuls Safe et Escaped affichent « ESCAPED! ».
local function lostReason(g: Guardian, player: Player): string
	if PlotService.IsPlayerSafe(player) then
		return "Safe"
	end
	local block = CarryService.Get(player)
	if not block or block.Zone ~= g.Zone or not rootOf(player) then
		return "Dropped"
	end
	return "Escaped"
end

local function lose(g: Guardian)
	local target = g.Target
	setTarget(g, nil)
	if target then
		alert(target, g.Zone, "Lost", lostReason(g, target))
	end
	setState(g, "Search", GuardiansConfig.SearchTime)
end

local function catch(g: Guardian, target: Player)
	local root = rootOf(target)
	local block = CarryService.Get(target)
	setTarget(g, nil)
	setState(g, "Catch", GuardiansConfig.CatchTime)
	if root then
		face(g, root.Position)
	end
	CarryService.ReturnToSite(target)
	PvpService.Knock(target, GuardiansConfig.KnockTime, "Catch")
	alert(target, g.Zone, "Catch")
	Notify.Send(target, "Caught by the guardian! The fossil went back to its dig site.", "error")
	if root then
		Remotes.Event("PvpEffect"):FireAllClients("Catch", root.Position)
	end
	Signals.Fire("GuardianCaught", target, g.Zone, block)
end

-- Remet le gardien endormi chez lui
local function sleep(g: Guardian)
	setTarget(g, nil)
	g.TrappedUntil = 0
	g.Model:SetAttribute("Trapped", false)
	place(g, g.Home)
	setState(g, "Sleep")
end

-- Bloque le gardien `seconds` secondes (Bear Trap)
local function trap(g: Guardian, seconds: number)
	g.TrappedUntil = os.clock() + seconds
	g.StateEndsAt += seconds
	g.Model:SetAttribute("Trapped", true)
	g.Model:SetAttribute("Speed", 0)
	g.Model:SetAttribute("State", GuardiansConfig.TrappedState)
	g.Model:SetAttribute("StateAt", Workspace:GetServerTimeNow())
end

local function tick(g: Guardian, dt: number, now: number)
	if g.TrappedUntil > 0 then
		if now < g.TrappedUntil then
			return
		end
		g.TrappedUntil = 0
		g.Model:SetAttribute("Trapped", false)
		g.Model:SetAttribute("State", g.State)
		g.Model:SetAttribute("StateAt", Workspace:GetServerTimeNow())
	end
	local state = g.State
	if state == "Sleep" or state == "BackToSleep" then
		-- (un porteur d'un bloc de sa zone tout près, par exemple celui qui a ramassé un bloc lâché : il se réveille)
		local other = nearestPrey(g, false)
		if other then
			wake(g, other)
		elseif state == "BackToSleep" and now >= g.StateEndsAt then
			setState(g, "Sleep")
		end
	elseif state == "Wake" then
		if now >= g.StateEndsAt then
			local target = g.Target
			if target and isPrey(g, target, true) then
				roar(g, target)
			else
				local other = nearestPrey(g, true)
				if other then
					roar(g, other)
				else
					lose(g)
				end
			end
		end
	elseif state == "Roar" then
		local target = g.Target
		local root = target and rootOf(target)
		if root then
			face(g, root.Position)
		end
		if now >= g.StateEndsAt then
			if target and isPrey(g, target, true) then
				startRun(g, target)
			else
				local other = nearestPrey(g, true)
				if other then
					startRun(g, other)
				else
					lose(g)
				end
			end
		end
	elseif state == "Run" then
		local target = g.Target
		if not (target and isPrey(g, target, true)) then
			local other = nearestPrey(g, true)
			if not other then
				lose(g)
				return
			end
			if target then
				alert(target, g.Zone, "Lost", lostReason(g, target))
			end
			startRun(g, other)
			target = other
		end
		local root = rootOf(target :: Player) :: BasePart
		local left = moveToward(g, root.Position, chaseSpeed(g, target :: Player), dt, g.CatchRange * 0.5)
		if left <= g.CatchRange then
			catch(g, target :: Player)
			return
		end
		if PvpService.SpringTrapAt(g.CFrame.Position, g.Size * 0.25, g.Zone) then
			trap(g, Pvp.Trap.HoldTime)
		end
	elseif state == "Catch" then
		if now >= g.StateEndsAt then
			local other = nearestPrey(g, true)
			if other then
				startRun(g, other)
			else
				goHome(g)
			end
		end
	elseif state == "Search" then
		local other = nearestPrey(g, true)
		if other then
			startRun(g, other)
		elseif now >= g.StateEndsAt then
			goHome(g)
		end
	elseif state == "Return" then
		local other = nearestPrey(g, true)
		if other then
			roar(g, other)
			return
		end
		-- (loin de sa zone, après une longue poursuite, il rentre plus vite : sa zone ne reste pas longtemps sans gardien)
		local speed = g.ReturnSpeed
		if not inLeash(g, g.CFrame.Position) then
			speed = math.max(speed, g.Speed * GuardiansConfig.FarReturnFactor)
		end
		local left = moveToward(g, g.Home.Position, speed, dt, 0)
		if left <= 0.5 or now >= g.StateEndsAt then
			place(g, g.Home)
			setState(g, "BackToSleep", GuardiansConfig.BackToSleepTime)
		elseif PvpService.SpringTrapAt(g.CFrame.Position, g.Size * 0.25, g.Zone) then
			trap(g, Pvp.Trap.HoldTime)
		end
	end
end

-- Un bloc vient d'être arraché : le gardien de sa zone se réveille (ou reprend la poursuite)
local function onGrab(player: Player, block: CarryService.Block)
	if not enabled or type(block) ~= "table" then
		return
	end
	local g = byZone[block.Zone]
	if not g then
		return
	end
	local state = g.State
	if state == "Sleep" or state == "BackToSleep" then
		wake(g, player)
	elseif state == "Search" or state == "Return" then
		roar(g, player)
	end
	-- (Wake, Roar, Run, Catch : il est déjà réveillé ; Run choisit la proie la plus proche)
end

-- ===================================================================== API

-- Gardien d'une zone
function GuardianService.Get(zone: string): Guardian?
	return byZone[zone]
end

-- Tous les gardiens, dans l'ordre de la route
function GuardianService.List(): { Guardian }
	return table.clone(guardians)
end

-- Vitesse de course de base du gardien d'une zone (studs/s) : Speed de Config.Guardians, sinon SpeedFactor x WalkSpeed
-- conseillé de la zone (contre un porteur, x le malus de son bloc : ChaseSpeed)
function GuardianService.SpeedFor(zone: string): number
	local info = GuardiansConfig.Zones[zone]
	if info and Guard.Number(info.Speed, 0) then
		return info.Speed :: number
	end
	local zoneInfo = Zones.ByName[zone]
	return GuardiansConfig.SpeedFactor * SpeedConfig.WalkSpeedFor(if zoneInfo then zoneInfo.Speed else 0)
end

-- Vitesse de course du gardien d'une zone contre ce joueur (avec le malus du bloc qu'il porte) ; 0 sans gardien
function GuardianService.ChaseSpeed(zone: string, player: Player): number
	local g = byZone[zone]
	return if g then chaseSpeed(g, player) else 0
end

-- Gardiens actifs ou non (commande d'admin « guardians », tests de la boucle) : éteints, ils dorment chez eux
function GuardianService.SetEnabled(on: boolean)
	enabled = on
	if not on then
		for _, g in guardians do
			sleep(g)
		end
	end
end

function GuardianService.IsEnabled(): boolean
	return enabled
end

-- Réveille le gardien d'une zone contre un joueur (tests, debug). true si c'est fait.
function GuardianService.Wake(zone: string, player: Player): boolean
	local g = byZone[zone]
	if not g or not enabled then
		return false
	end
	wake(g, player)
	return true
end

-- Rendort tous les gardiens chez eux (tests, debug)
function GuardianService.ResetAll()
	for _, g in guardians do
		sleep(g)
	end
end

-- ===================================================================== cycle de vie

local function homeOf(geo: ZoneService.ZoneGeo): CFrame
	local anchor = geo.Guardian
	if anchor then
		return anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0)
	end
	local area = geo.Area
	return CFrame.new(area.Position + Vector3.new(0, area.Size.Y / 2, 0))
end

function GuardianService.Init()
	for _, geo in ZoneService.List() do
		local info = GuardiansConfig.Zones[geo.Name]
		if not info then
			continue
		end
		local home = homeOf(geo)
		local model, size = buildModel(geo.Name, info, home)
		local speed = GuardianService.SpeedFor(geo.Name)
		local g: Guardian = {
			Zone = geo.Name,
			Species = info.Species,
			Area = geo.Area,
			Model = model,
			Home = home,
			CFrame = home,
			State = "Sleep",
			StateEndsAt = 0,
			Target = nil,
			Speed = speed,
			FixedSpeed = Guard.Number(info.Speed, 0) ~= nil,
			ReturnSpeed = math.max(GuardiansConfig.MinReturnSpeed, speed * GuardiansConfig.ReturnFactor),
			CatchRange = GuardiansConfig.CatchRange + GuardiansConfig.CatchReach * size,
			Size = size,
			TrappedUntil = 0,
		}
		table.insert(guardians, g)
		byZone[geo.Name] = g
	end
	Signals.Connect("BlockGrabbed", onGrab)
	AdminService.RegisterCommand("guardians", {
		Description = "Turn the zone guardians on or off",
		Usage = "guardians <on|off>",
		Run = function(_caller: Player, args: { string })
			local mode = string.lower(args[1] or "")
			if mode ~= "on" and mode ~= "off" then
				return false, "Usage: guardians <on|off>"
			end
			GuardianService.SetEnabled(mode == "on")
			return true, "Guardians " .. mode
		end,
	})
end

function GuardianService.Start()
	local last = os.clock()
	while true do
		task.wait(GuardiansConfig.TickRate)
		local now = os.clock()
		local dt = math.min(now - last, 0.5)
		last = now
		if enabled then
			refreshGroundFilter()
			for _, g in guardians do
				tick(g, dt, now)
			end
		end
	end
end

function GuardianService.OnPlayerReady(player: Player, _data: { [string]: any })
	player:SetAttribute("ChasedBy", "")
end

function GuardianService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	chased[player] = nil
	for _, g in guardians do
		if g.Target == player then
			setTarget(g, nil)
		end
	end
end

return GuardianService
