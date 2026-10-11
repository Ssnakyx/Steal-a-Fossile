--!strict
-- Vol sur la route (brief 7 « gardiens-vol », GDD section Vol) : pelle, Bear Traps, protection débutant, chutes.
-- Uniquement sur la route : dans un parc (PlotService.IsSafe), personne n'est bonké ni piégé et aucun piège n'est posé.
--   * Pelle (outil « Shovel » donné à chaque apparition) : remote Bonk(cible?). Recharge 2 s, portée vérifiée. Le
--     porteur touché tombe (chute cartoon) et lâche son bloc au sol (DroppedBlockService). Sans bloc : rien.
--   * Bear Trap (outil « Bear Trap » tant qu'il en reste) : remote PlaceTrap, à ses pieds. Celui qui marche dessus
--     (joueur ou gardien, jamais celui qui l'a posé) est immobilisé 3 s et lâche son bloc. Achat avec l'argent du jeu
--     (BuyTraps) ou par 5 avec le produit Robux BearTraps5 (Config.Shop.Products).
--   * Protection débutant : les 10 premières minutes de jeu (data.PlayTime), ni bonk ni piège. Elle s'arrête plus
--     tôt si le joueur bonke, pose un piège ou ramasse le bloc lâché par un autre. Attributs joueur Protected (booléen)
--     et ProtectedUntil (heure serveur).
--   * Knock(player, secondes, raison) : immobile (SpeedService.SetModifier) et chute côté client (remote Knocked).
-- Pièges posés : modèles « BearTrap » tagués « BearTrap » dans Workspace.BearTraps, attributs OwnerUserId, Armed,
-- ArmsAt (heure serveur à partir de laquelle il se ferme : 1 s après la pose).
-- Clé replica « BearTraps » (pièges en réserve).
-- Signaux : Bonked(attacker, victim, block), TrapPlaced(player), TrapSprung(owner?, victim (Player ou nom de zone du
-- gardien), block?), ProtectionEnded(player)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Pvp = require(ReplicatedStorage.Shared.Config.Pvp)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local DroppedBlockService = require(script.Parent.DroppedBlockService)
local MoneyService = require(script.Parent.MoneyService)
local PlotService = require(script.Parent.PlotService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)
local SpeedService = require(script.Parent.SpeedService)

export type Trap = {
	Id: number,
	Owner: Player?,
	OwnerUserId: number,
	Model: Model,
	Position: Vector3, -- point du sol
	Armed: boolean,
	ArmsAt: number, -- os.clock() : se ferme sur quelqu'un à partir de là
	ExpiresAt: number, -- os.clock()
}

type State = {
	ProtectedUntil: number, -- os.clock()
	Protected: boolean,
	LastBonk: number,
	LastTrap: number,
	KnockedUntil: number,
	Connection: RBXScriptConnection?,
}

local PvpService = {}

local CHECK_INTERVAL = 0.1 -- secondes entre deux vérifications des pièges et de la protection
local TRAP_HEIGHT = 6 -- studs au-dessus du piège où l'on compte comme dessus
local PARK_CLEARANCE = 10 -- studs autour d'un parc où l'on ne pose pas de piège (pas de piège à l'entrée d'un parc)

local states: { [Player]: State } = {}
local traps: { [number]: Trap } = {}
local nextTrapId = 0
local trapFolder: Folder? = nil

-- ===================================================================== protection et chutes

-- Le joueur a-t-il encore la protection débutant (ni bonk ni piège) ?
function PvpService.IsProtected(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.Protected
end

local function setProtected(player: Player, state: State, protected: boolean)
	local was = state.Protected
	state.Protected = protected
	player:SetAttribute("Protected", protected)
	player:SetAttribute("ProtectedUntil", if protected then Workspace:GetServerTimeNow() + (state.ProtectedUntil - os.clock()) else 0)
	if was and not protected then
		Signals.Fire("ProtectionEnded", player)
	end
end

-- Donne ou enlève la protection débutant (commande d'admin, tests). seconds : durée (sinon le reste du temps normal).
function PvpService.SetProtection(player: Player, protected: boolean, seconds: number?): boolean
	local state = states[player]
	if not state then
		return false
	end
	if protected then
		state.ProtectedUntil = os.clock() + (if Guard.Number(seconds, 0) then seconds :: number else Pvp.Protection.Time)
	else
		state.ProtectedUntil = 0
	end
	setProtected(player, state, protected)
	return true
end

-- Le joueur protégé attaque ou vole un autre joueur : sa protection s'arrête (Config.Pvp.Protection.EndsOnAttack)
local function endProtection(player: Player, message: string)
	local state = states[player]
	if not (Pvp.Protection.EndsOnAttack and state and state.Protected) then
		return
	end
	state.ProtectedUntil = 0
	setProtected(player, state, false)
	Notify.Send(player, message, "info")
end

-- Le joueur est-il au sol ou bloqué (bonk, gardien, piège) ?
function PvpService.IsKnocked(player: Player): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.KnockedUntil
end

-- Immobilise le joueur `seconds` secondes et le fait tomber côté client (raison : Bonk, Catch, Trap)
function PvpService.Knock(player: Player, seconds: number, reason: string)
	local state = states[player]
	if not state or not Guard.Number(seconds, 0, 60) then
		return
	end
	state.KnockedUntil = math.max(state.KnockedUntil, os.clock() + seconds)
	SpeedService.SetModifier(player, if reason == "Trap" then "BearTrap" else "Knocked", 0, seconds)
	Remotes.Event("Knocked"):FireClient(player, seconds, reason)
end

local function effect(kind: string, position: Vector3)
	Remotes.Event("PvpEffect"):FireAllClients(kind, position)
end

-- ===================================================================== outils

local WOOD = Color3.fromRGB(150, 105, 65)
local METAL = Color3.fromRGB(120, 125, 130)
local DARK = Color3.fromRGB(60, 62, 66)

local function toolPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function weld(a: BasePart, b: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = a
	constraint.Part1 = b
	constraint.Parent = b
end

-- Pelle en briques : manche en bois, lame en métal (Handle tenu par la main)
local function makeShovel(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Pvp.Shovel.ToolName
	tool.ToolTip = "Bonk thieves on the road"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -1.2, 0)
	local handle = toolPart("Handle", Vector3.new(0.4, 4, 0.4), WOOD, tool)
	local blade = toolPart("Blade", Vector3.new(1.4, 1.6, 0.4), METAL, tool)
	blade.CFrame = handle.CFrame * CFrame.new(0, 2.8, 0)
	weld(handle, blade)
	return tool
end

-- Piège en main : socle et mâchoires
local function makeTrapTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Pvp.Trap.ToolName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, 0, -0.6)
	local handle = toolPart("Handle", Vector3.new(2, 0.4, 2), DARK, tool)
	local jaw = toolPart("Jaw", Vector3.new(2, 0.6, 0.4), METAL, tool)
	jaw.CFrame = handle.CFrame * CFrame.new(0, 0.5, 0)
	weld(handle, jaw)
	return tool
end

-- Outil du joueur, dans son sac ou en main
local function findTool(player: Player, name: string): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local found = (backpack and backpack:FindFirstChild(name)) or (character and character:FindFirstChild(name))
	return if found and found:IsA("Tool") then found else nil
end

-- Outils du joueur à jour : pelle toujours, piège tant qu'il en a (ToolTip « x3 »)
local function refreshTools(player: Player)
	local data = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	if not findTool(player, Pvp.Shovel.ToolName) then
		makeShovel().Parent = backpack
	end
	local trapTool = findTool(player, Pvp.Trap.ToolName)
	if data.BearTraps > 0 then
		local tool = trapTool or makeTrapTool()
		tool.ToolTip = "Bear Trap x" .. data.BearTraps
		if not trapTool then
			tool.Parent = backpack
		end
	elseif trapTool then
		trapTool:Destroy()
	end
end

local function publishTraps(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ReplicaService.Set(player, "BearTraps", data.BearTraps)
	refreshTools(player)
end

-- Ajoute des pièges à la réserve (achat, récompense). false si le plafond serait dépassé.
function PvpService.GiveTraps(player: Player, count: number): boolean
	local data = DataService.Get(player)
	if not data or not Guard.Integer(count, 1) or data.BearTraps + count > Pvp.Trap.MaxOwned then
		return false
	end
	data.BearTraps += count
	publishTraps(player)
	return true
end

-- ===================================================================== pelle

local function rootOf(player: Player): BasePart?
	local root = Guard.Root(player)
	if not root then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Le joueur peut-il être bonké ou piégé maintenant ? (sur la route, pas protégé, en jeu)
local function canBeHit(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and states[player] ~= nil and not PvpService.IsProtected(player) and not PlotService.IsSafe(root.Position)
end

-- Porteur à frapper : la cible donnée si elle est à portée, sinon (pas de cible) le porteur le plus proche à portée
local function pickTarget(attacker: Player, origin: Vector3, wanted: Player?): Player?
	local reach = Pvp.Shovel.Range + Pvp.Shovel.RangeTolerance
	if wanted then
		local target = wanted
		if target == attacker or target.Parent ~= Players then
			return nil
		end
		local root = rootOf(target)
		if not root or flatDistance(root.Position, origin) > reach or math.abs(root.Position.Y - origin.Y) > reach then
			return nil
		end
		return target
	end
	local best: Player? = nil
	local bestDistance = math.huge
	for other in states do
		if other ~= attacker and other.Parent == Players and CarryService.IsCarrying(other) and canBeHit(other) then
			local root = rootOf(other) :: BasePart
			local distance = flatDistance(root.Position, origin)
			if distance <= Pvp.Shovel.Range and math.abs(root.Position.Y - origin.Y) <= reach and distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- Coup de pelle de `attacker` (cible facultative : un joueur, sinon le porteur le plus proche). Renvoie (touché, texte).
function PvpService.Bonk(attacker: Player, wanted: any): (boolean, string)
	if wanted ~= nil and not (typeof(wanted) == "Instance" and wanted:IsA("Player")) then
		return false, "Invalid target"
	end
	local state = states[attacker]
	local root = rootOf(attacker)
	if not state or not root then
		return false, "Not ready"
	end
	local character = attacker.Character
	local tool = character and character:FindFirstChild(Pvp.Shovel.ToolName)
	if not (tool and tool:IsA("Tool")) then
		return false, "No shovel"
	end
	local now = os.clock()
	if now - state.LastBonk < Pvp.Shovel.Cooldown - 0.05 then
		return false, "Cooldown"
	end
	if now < state.KnockedUntil then
		return false, "Knocked"
	end
	if PlotService.IsSafe(root.Position) then
		Notify.Send(attacker, "No bonking in parks!", "error")
		return false, "Safe zone"
	end
	state.LastBonk = now
	local target = pickTarget(attacker, root.Position, wanted)
	if not target then
		return false, "Missed"
	end
	local targetRoot = rootOf(target) :: BasePart
	if PlotService.IsSafe(targetRoot.Position) then
		Notify.Send(attacker, "No bonking in parks!", "error")
		return false, "Safe zone"
	end
	if PvpService.IsProtected(target) then
		Notify.Send(attacker, "This player has new player protection!", "error")
		return false, "Protected"
	end
	if not CarryService.IsCarrying(target) then
		return false, "Nothing to steal"
	end
	local position = targetRoot.Position
	local block = DroppedBlockService.Drop(target, "Bonk")
	if not block then
		return false, "Nothing to steal"
	end
	PvpService.Knock(target, Pvp.Shovel.KnockTime, "Bonk")
	effect("Bonk", position)
	Notify.Send(target, "Bonk! You dropped your fossil!", "error")
	Notify.Send(attacker, "Bonk! Grab the fossil!", "success")
	endProtection(attacker, "You attacked a player: your new player protection is over!")
	Signals.Fire("Bonked", attacker, target, block)
	return true, "Bonk!"
end

-- ===================================================================== pièges

local function trapContainer(): Folder
	local existing = trapFolder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "BearTraps"
	created.Parent = Workspace
	trapFolder = created
	return created
end

local function trapPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Piège en briques au sol : socle, deux mâchoires ouvertes, plaque au centre
local function buildTrap(ground: Vector3, owner: Player): Model
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	local base = CFrame.new(ground)
	local root = trapPart("Base", Vector3.new(3, 0.4, 3), base * CFrame.new(0, 0.2, 0), DARK, model)
	trapPart("Plate", Vector3.new(1, 0.2, 1), base * CFrame.new(0, 0.5, 0), Color3.fromRGB(200, 170, 60), model)
	trapPart("JawLeft", Vector3.new(0.4, 0.4, 3), base * CFrame.new(-1.6, 0.4, 0), METAL, model)
	trapPart("JawRight", Vector3.new(0.4, 0.4, 3), base * CFrame.new(1.6, 0.4, 0), METAL, model)
	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("Armed", true)
	model:SetAttribute("PlacedAt", Workspace:GetServerTimeNow())
	model:SetAttribute("ArmsAt", Workspace:GetServerTimeNow() + Pvp.Trap.ArmTime)
	return model
end

local function removeTrap(trap: Trap)
	if traps[trap.Id] ~= trap then
		return
	end
	traps[trap.Id] = nil
	trap.Model:Destroy()
end

-- Pièges posés par un joueur, du plus ancien au plus récent
local function trapsOf(userId: number): { Trap }
	local list = {}
	for _, trap in traps do
		if trap.OwnerUserId == userId and trap.Armed then
			table.insert(list, trap)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

-- La position est-elle dans un parc ou à moins de `margin` studs de l'un d'eux ?
local function nearPark(position: Vector3, margin: number): boolean
	for _, plot in PlotService.List() do
		local floor = plot.Floor
		local relative = floor.CFrame:PointToObjectSpace(position)
		local half = floor.Size / 2
		local dx = math.max(0, math.abs(relative.X) - half.X)
		local dz = math.max(0, math.abs(relative.Z) - half.Z)
		if dx * dx + dz * dz <= margin * margin and math.abs(relative.Y) <= half.Y + 60 then
			return true
		end
	end
	return false
end

-- Pose un piège aux pieds du joueur. Renvoie (ok, texte).
function PvpService.PlaceTrap(player: Player): (boolean, string)
	local state = states[player]
	local data = DataService.Get(player)
	local root = rootOf(player)
	if not state or not data or not root then
		return false, "Not ready"
	end
	if data.BearTraps <= 0 then
		Notify.Send(player, "You have no bear traps!", "error")
		return false, "No traps"
	end
	local now = os.clock()
	if now - state.LastTrap < Pvp.Trap.PlaceCooldown - 0.05 or now < state.KnockedUntil then
		return false, "Cooldown"
	end
	local character = player.Character
	local ground = DroppedBlockService.GroundBelow(root.Position, character)
	if PlotService.IsSafe(root.Position) or nearPark(ground, PARK_CLEARANCE) then
		Notify.Send(player, "Bear traps go on the road, not near parks!", "error")
		return false, "Safe zone"
	end
	for _, trap in traps do
		if trap.Armed and (trap.Position - ground).Magnitude < Pvp.Trap.MinSpacing then
			Notify.Send(player, "There is already a trap here!", "error")
			return false, "Too close"
		end
	end
	state.LastTrap = now
	data.BearTraps -= 1
	nextTrapId += 1
	local model = buildTrap(ground, player)
	local trap: Trap = {
		Id = nextTrapId,
		Owner = player,
		OwnerUserId = player.UserId,
		Model = model,
		Position = ground,
		Armed = true,
		ArmsAt = now + Pvp.Trap.ArmTime,
		ExpiresAt = now + Pvp.Trap.Lifetime,
	}
	traps[trap.Id] = trap
	model:AddTag("BearTrap")
	model.Parent = trapContainer()
	-- (trop de pièges posés : le plus ancien disparaît)
	local mine = trapsOf(player.UserId)
	while #mine > Pvp.Trap.MaxActive do
		removeTrap(table.remove(mine, 1) :: Trap)
	end
	publishTraps(player)
	Signals.Fire("TrapPlaced", player)
	Notify.Send(player, "Bear trap placed!", "success")
	endProtection(player, "You placed a bear trap: your new player protection is over!")
	return true, "Placed"
end

local function spring(trap: Trap, victim: Player | string, block: CarryService.Block?)
	trap.Armed = false
	trap.ExpiresAt = os.clock() + Pvp.Trap.HoldTime
	trap.Model:SetAttribute("Armed", false)
	trap.Model:SetAttribute("SprungAt", Workspace:GetServerTimeNow())
	effect("Trap", trap.Position)
	local owner = trap.Owner
	Signals.Fire("TrapSprung", if owner and owner.Parent == Players then owner else nil, victim, block)
end

-- Un gardien marche-t-il sur un piège ? Si oui, le piège se ferme sur lui (GuardianService le bloque HoldTime s).
-- extra : rayon du gardien (studs) ajouté au rayon du piège. Renvoie true si un piège s'est fermé.
function PvpService.SpringTrapAt(position: Vector3, extra: number?, zoneName: string?): boolean
	if not Guard.Vector3(position) then
		return false
	end
	local radius = Pvp.Trap.Radius + (Guard.Number(extra, 0, 100) or 0)
	local now = os.clock()
	for _, trap in traps do
		if trap.Armed and now >= trap.ArmsAt and flatDistance(trap.Position, position) <= radius and math.abs(trap.Position.Y - position.Y) <= TRAP_HEIGHT then
			spring(trap, zoneName or "Guardian", nil)
			return true
		end
	end
	return false
end

local function checkTraps(now: number)
	for _, trap in table.clone(traps) do
		if now >= trap.ExpiresAt then
			removeTrap(trap)
			continue
		end
		if not trap.Armed or now < trap.ArmsAt then
			continue
		end
		for player, state in states do
			if player.UserId == trap.OwnerUserId or now < state.KnockedUntil or player.Parent ~= Players then
				continue
			end
			local root = rootOf(player)
			if not root or flatDistance(root.Position, trap.Position) > Pvp.Trap.Radius then
				continue
			end
			local dy = root.Position.Y - trap.Position.Y
			if dy < -1 or dy > TRAP_HEIGHT or not canBeHit(player) then
				continue
			end
			local block = DroppedBlockService.Drop(player, "Trap")
			PvpService.Knock(player, Pvp.Trap.HoldTime, "Trap")
			spring(trap, player, block)
			Notify.Send(player, if block then "Bear trap! You dropped your fossil!" else "Bear trap!", "error")
			local owner = trap.Owner
			if owner and owner.Parent == Players then
				Notify.Send(owner, "Your bear trap caught " .. player.DisplayName .. "!", "success")
			end
			break
		end
	end
end

-- Pièges posés (tests, debug)
function PvpService.Traps(): { Trap }
	local list = {}
	for _, trap in traps do
		table.insert(list, trap)
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

-- Achat de pièges avec l'argent du jeu. Renvoie (ok, texte).
local function buyTraps(player: Player, rawCount: any): (boolean, string)
	local count = if rawCount == nil then 1 else Guard.Integer(rawCount, 1, Pvp.Trap.MaxBuy)
	local data = DataService.Get(player)
	if not count then
		return false, "Invalid amount"
	end
	if not data then
		return false, "Please wait..."
	end
	if data.BearTraps + count > Pvp.Trap.MaxOwned then
		return false, "You can't carry more traps"
	end
	local cost = Pvp.Trap.Price * count
	if not MoneyService.Spend(player, cost, "BearTraps") then
		return false, "Not enough money!"
	end
	PvpService.GiveTraps(player, count)
	return true, string.format("Bought %d bear trap%s for %s", count, if count > 1 then "s" else "", Format.Money(cost))
end

-- ===================================================================== cycle de vie

local function registerProduct()
	-- Bear Traps x5 : produit déclaré par le brief 4 dans Config.Shop.Products (Id = 0 tant qu'il n'est pas créé)
	local folder = ReplicatedStorage.Shared:FindFirstChild("Config")
	if not (folder and folder:FindFirstChild("Shop")) then
		return
	end
	local products = Config.Shop.Products
	local product = type(products) == "table" and products.BearTraps5
	if type(product) ~= "table" or type(product.Id) ~= "number" then
		return
	end
	ReceiptService.Register("BearTraps5", product.Id, function(player: Player, data, _receipt): boolean
		-- (toujours accordé, sinon l'achat serait retenté sans fin : au plafond, seulement ce qui tient)
		local count = math.clamp(Pvp.Trap.MaxOwned - data.BearTraps, 0, Pvp.Trap.PerProduct)
		data.BearTraps += count
		publishTraps(player)
		Notify.Send(player, "+" .. count .. " bear traps!", "success")
		return true
	end)
end

local function registerCommands()
	AdminService.RegisterCommand("traps", {
		Description = "Give bear traps",
		Usage = "traps <amount> [player]",
		Run = function(caller: Player, args: { string })
			local count = Guard.Integer(tonumber(args[1] or ""), 1, Pvp.Trap.MaxOwned)
			local target = AdminService.FindPlayer(caller, args[2])
			if not (count and target) then
				return false, "Usage: traps <amount> [player]"
			end
			if not PvpService.GiveTraps(target, count) then
				return false, "Too many traps (max " .. Pvp.Trap.MaxOwned .. ")"
			end
			return true, target.Name .. " got " .. count .. " bear trap(s)"
		end,
	})
	AdminService.RegisterCommand("protection", {
		Description = "Turn new player protection on or off",
		Usage = "protection <on|off> [player]",
		Run = function(caller: Player, args: { string })
			local mode = string.lower(args[1] or "")
			local target = AdminService.FindPlayer(caller, args[2])
			if not ((mode == "on" or mode == "off") and target) then
				return false, "Usage: protection <on|off> [player]"
			end
			if not PvpService.SetProtection(target, mode == "on") then
				return false, "Player not loaded"
			end
			return true, target.Name .. " protection " .. mode
		end,
	})
	AdminService.RegisterCommand("returnblocks", {
		Description = "Send every fossil on the ground back to its dig site",
		Usage = "returnblocks",
		Run = function()
			return true, DroppedBlockService.ReturnAll() .. " fossil(s) returned"
		end,
	})
end

function PvpService.Init()
	Net.Event("Bonk", { Rate = 2, Burst = 3 }, function(player: Player, target: any)
		PvpService.Bonk(player, target)
	end)
	Net.Event("PlaceTrap", { Rate = 2, Burst = 3 }, function(player: Player)
		PvpService.PlaceTrap(player)
	end)
	Net.Function("BuyTraps", { Rate = 2, Burst = 4 }, function(player: Player, count: any)
		return buyTraps(player, count)
	end)
	registerProduct()
	registerCommands()
	Signals.Connect("BlockPickedUp", function(player: Player, _block: any, droppedByUserId: number)
		if droppedByUserId ~= 0 and droppedByUserId ~= player.UserId then
			endProtection(player, "You took another player's fossil: your new player protection is over!")
		end
	end)
end

function PvpService.Start()
	while true do
		task.wait(CHECK_INTERVAL)
		local now = os.clock()
		for player, state in states do
			if state.Protected and now >= state.ProtectedUntil and player.Parent == Players then
				setProtected(player, state, false)
				Notify.Send(player, "Your new player protection is over. Watch out for thieves!", "info")
			end
		end
		checkTraps(now)
	end
end

function PvpService.OnPlayerReady(player: Player, data: { [string]: any })
	-- (protection : le reste des 10 premières minutes de jeu, temps déjà joué lu dans la sauvegarde)
	local left = math.max(0, Pvp.Protection.Time - (Guard.Number(data.PlayTime, 0) or 0))
	local state: State = {
		ProtectedUntil = os.clock() + left,
		Protected = false,
		LastBonk = -math.huge,
		LastTrap = -math.huge,
		KnockedUntil = 0,
		Connection = nil,
	}
	states[player] = state
	setProtected(player, state, left > 0)
	state.Connection = player.CharacterAdded:Connect(function()
		-- (après le remplissage du sac par Roblox à l'apparition, et une seconde fois plus tard au cas où le sac serait
		-- vidé après CharacterAdded : refreshTools ne donne jamais un outil deux fois)
		task.defer(refreshTools, player)
		task.delay(1, refreshTools, player)
	end)
	publishTraps(player)
end

function PvpService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	local state = states[player]
	states[player] = nil
	if state and state.Connection then
		state.Connection:Disconnect()
	end
	for _, trap in trapsOf(player.UserId) do
		removeTrap(trap)
	end
	for _, trap in traps do
		if trap.Owner == player then
			trap.Owner = nil
		end
	end
end

return PvpService
