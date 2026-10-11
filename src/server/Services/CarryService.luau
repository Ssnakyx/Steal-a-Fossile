--!strict
-- Port des blocs fossiles (brief 3 « boucle ») : un seul bloc à la fois, porté sur le dos (visible par tous), avec un
-- malus de vitesse selon la rareté (GetSpeedMultiplier, appliqué par SpeedService du brief 4 : ce service n'écrit
-- jamais WalkSpeed).
-- Dès que le porteur entre dans son propre parc, le bloc est à lui pour de bon : il part dans une cuve libre ou en
-- réserve (ReviveService.AddBlock). Si tout est plein, il reste sur le dos (le parc est sûr, rien n'y est volable).
-- Mort, reset, départ : le bloc retourne à son gisement (signal BlockReturned, écouté par DigSiteService).
-- Anti-téléportation : un porteur arrivé chez lui plus vite que sa vitesse de marche ne le permet perd le bloc.
-- Attribut joueur « Carrying » (rareté portée, "" sinon). Clé replica « Carrying » ({ Rarity, Zone } ou nil).
-- Signaux : CarryChanged(player, block?), BlockBanked(player, block), BlockReturned(block)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ReplicaService = require(script.Parent.ReplicaService)
local ReviveService = require(script.Parent.ReviveService)

-- Bloc fossile qui circule entre services : Site et Slot disent d'où il vient (nil pour un bloc sans gisement,
-- comme ceux de la pluie de météorites du brief 14). Tutorial : bloc du tutoriel, réservé aux nouveaux joueurs.
export type Block = { Id: number, Rarity: string, Zone: string, Site: string?, Slot: number?, Tutorial: boolean? }

-- From, GrabbedAt : où et quand le bloc a été pris. TopSpeed : plus grande WalkSpeed vue depuis (côté serveur).
type Carried = { Block: Block, Part: Part?, Connections: { RBXScriptConnection }, From: Vector3, GrabbedAt: number, TopSpeed: number }

local CarryService = {}

local CHECK_INTERVAL = 0.1 -- secondes entre deux vérifications « est-il rentré dans son parc ? »
local FULL_MESSAGE_COOLDOWN = 4
-- Anti-téléportation : distance à vol d'oiseau permise = TopSpeed x TRAVEL_TOLERANCE x temps + TRAVEL_GRACE
local TRAVEL_TOLERANCE = 1.5 -- (sauts, chutes, latence)
local TRAVEL_GRACE = 30 -- studs
local MIN_WALK_SPEED = 16

local carried: { [Player]: Carried } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local fullMessageAt: { [Player]: number } = {}

-- Bloc porté par le joueur (nil s'il ne porte rien)
function CarryService.Get(player: Player): Block?
	local state = carried[player]
	return if state then state.Block else nil
end

function CarryService.IsCarrying(player: Player): boolean
	return carried[player] ~= nil
end

-- Multiplicateur de vitesse du joueur dû au bloc porté (1 sans bloc, 0.9 Common à 0.6 Secret). Lu par SpeedService.
function CarryService.GetSpeedMultiplier(player: Player): number
	local state = carried[player]
	if not state then
		return 1
	end
	local info = Rarity.Info[state.Block.Rarity]
	return if info then info.CarrySpeed else 1
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- WalkSpeed du personnage vue par le serveur (écrite par SpeedService du brief 4 ; le client ne peut pas la changer
-- pour le serveur), au moins MIN_WALK_SPEED
local function walkSpeed(player: Player): number
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = if humanoid then humanoid.WalkSpeed else 0
	return if speed == speed and speed < math.huge then math.max(speed, MIN_WALK_SPEED) else MIN_WALK_SPEED
end

-- Le porteur est-il allé plus vite que sa vitesse de marche depuis qu'il a pris le bloc (téléportation) ?
local function travelledTooFast(player: Player, state: Carried): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local offset = root.Position - state.From
	local distance = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	return distance > state.TopSpeed * TRAVEL_TOLERANCE * (os.clock() - state.GrabbedAt) + TRAVEL_GRACE
end

local function attachVisual(root: BasePart, block: Block): Part
	local info = Rarity.Info[block.Rarity]
	local part = Instance.new("Part")
	part.Name = "CarriedFossil"
	part.Size = Vector3.new(2.5, 2.5, 2.5)
	part.Color = if info then info.Color else Color3.new(0.6, 0.6, 0.6)
	part.Material = if block.Rarity == "Secret" then Enum.Material.Neon else Enum.Material.Slate
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	-- (dans le dos : +Z du HumanoidRootPart, qui regarde vers -Z)
	part.CFrame = root.CFrame * CFrame.new(0, 0.6, 1.6)
	part:SetAttribute("Rarity", block.Rarity)
	part:SetAttribute("Zone", block.Zone) -- (décor du biome sur le bloc porté : FossilBlockController, brief 9)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = root.Parent
	return part
end

local function publish(player: Player, block: Block?)
	player:SetAttribute("Carrying", if block then block.Rarity else "")
	ReplicaService.Set(player, "Carrying", if block then { Rarity = block.Rarity, Zone = block.Zone } else nil)
	Signals.Fire("CarryChanged", player, block)
end

-- Met le bloc sur le dos du joueur. false s'il porte déjà un bloc, n'est pas chargé ou n'a pas de personnage.
function CarryService.Carry(player: Player, block: Block): boolean
	if carried[player] or not DataService.Get(player) then
		return false
	end
	if type(block) ~= "table" or not Rarity.Info[block.Rarity] then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local state: Carried = {
		Block = block,
		Part = attachVisual(root, block),
		Connections = {},
		From = root.Position,
		GrabbedAt = os.clock(),
		TopSpeed = walkSpeed(player),
	}
	local character = root.Parent
	if character then
		-- personnage retiré (reset, réapparition) ou mort : le bloc retourne à son gisement
		table.insert(state.Connections, character.AncestryChanged:Connect(function()
			if character.Parent == nil and carried[player] == state then
				CarryService.ReturnToSite(player)
			end
		end))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(state.Connections, humanoid.Died:Connect(function()
				if carried[player] == state then
					CarryService.ReturnToSite(player)
				end
			end))
		end
	end
	carried[player] = state
	publish(player, block)
	return true
end

-- Enlève le bloc du dos du joueur sans le rendre à son gisement (le brief 7 le pose au sol) ; renvoie le bloc
function CarryService.Drop(player: Player): Block?
	local state = carried[player]
	if not state then
		return nil
	end
	carried[player] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
	if state.Part then
		state.Part:Destroy()
	end
	publish(player, nil)
	return state.Block
end

-- Rend le bloc porté à son gisement (attrapé par un gardien, mort, départ). true si le joueur portait un bloc.
function CarryService.ReturnToSite(player: Player): boolean
	local block = CarryService.Drop(player)
	if not block then
		return false
	end
	Signals.Fire("BlockReturned", block)
	return true
end

-- Le porteur est dans son parc : le bloc est à lui (cuve libre ou réserve). Renvoie true si c'est fait.
function CarryService.Bank(player: Player): boolean
	local state = carried[player]
	if not state then
		return false
	end
	if travelledTooFast(player, state) then
		CarryService.ReturnToSite(player)
		Notify.Send(player, "Too fast! The fossil went back to its dig site.", "error")
		return false
	end
	if not ReviveService.AddBlock(player, state.Block) then
		local now = os.clock()
		if now - (fullMessageAt[player] or -math.huge) >= FULL_MESSAGE_COOLDOWN then
			fullMessageAt[player] = now
			Notify.Send(player, "Your tanks and storage are full! Reveal your dinos first.", "error")
		end
		return false
	end
	local block = CarryService.Drop(player) :: Block
	Signals.Fire("BlockBanked", player, block)
	Notify.Send(player, "Fossil secured! It is yours for good.", "success")
	return true
end

function CarryService.Start()
	while true do
		task.wait(CHECK_INTERVAL)
		for player, state in carried do
			state.TopSpeed = math.max(state.TopSpeed, walkSpeed(player))
			if PlotService.IsInOwnPlot(player) then
				CarryService.Bank(player)
			end
		end
	end
end

function CarryService.OnPlayerReady(player: Player, _data: { [string]: any })
	player:SetAttribute("Carrying", "")
	characterConnections[player] = player.CharacterRemoving:Connect(function()
		CarryService.ReturnToSite(player)
	end)
end

function CarryService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	local connection = characterConnections[player]
	characterConnections[player] = nil
	if connection then
		connection:Disconnect()
	end
	CarryService.ReturnToSite(player)
	fullMessageAt[player] = nil
end

return CarryService
