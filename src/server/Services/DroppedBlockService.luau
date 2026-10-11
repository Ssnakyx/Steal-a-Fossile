--!strict
-- Blocs au sol (brief 7 « gardiens-vol ») : un porteur bonké ou piégé sur la route lâche son bloc à ses pieds.
-- Le bloc au sol est ramassable par tous (ProximityPrompt « Pick up », distance vérifiée), sauf par celui qui l'a lâché
-- pendant 3 s (Config.Pvp.Dropped.LockTime). Pas ramassé en 30 s, il retourne à son gisement (signal BlockReturned,
-- écouté par DigSiteService ; un bloc sans gisement, comme ceux de la pluie de météorites, disparaît).
-- Pièces « DroppedFossil » taguées « DroppedFossil » dans Workspace.DroppedFossils, attributs BlockId, Rarity, Zone,
-- DroppedBy (UserId), LockedUntil et ReturnAt (heures serveur, Workspace:GetServerTimeNow()) pour les effets du
-- brief 11 (rebond, compte à rebours de 3 s) ; étiquette « Returns in 0:27 » (tag LoopCountdown du brief 3).
-- Signaux : BlockDropped(player, block, reason), BlockPickedUp(player, block, droppedByUserId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pvp = require(ReplicatedStorage.Shared.Config.Pvp)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Notify = require(script.Parent.Parent.Lib.Notify)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Signals = require(script.Parent.Parent.Lib.Signals)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)

type Block = CarryService.Block
export type Dropped = {
	Id: number,
	Block: Block,
	Part: Part,
	DroppedBy: number, -- UserId (0 : personne)
	Reason: string,
	LockedUntil: number, -- os.clock()
	ReturnAt: number, -- os.clock()
}

local DroppedBlockService = {}

local TAG = "DroppedFossil"
local BLOCK_SIZE = 3
local ROOT_HEIGHT = 3 -- studs entre le sol et le HumanoidRootPart d'un personnage debout
local DISTANCE_TOLERANCE = 5 -- studs de plus permis sur la portée du ProximityPrompt
local CHECK_INTERVAL = 0.5

local dropped: { [number]: Dropped } = {}
local nextId = 0
local folder: Folder? = nil

local function container(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "DroppedFossils"
	created.Parent = Workspace
	folder = created
	return created
end

-- Point du sol sous une position (raycast vers le bas sans les personnages, `ignore` ni les objets du jeu ; sinon
-- ROOT_HEIGHT sous la position, comme sous un personnage debout)
function DroppedBlockService.GroundBelow(position: Vector3, ignore: Instance?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: { Instance } = { container() }
	for _, name in { "BearTraps", "Guardians" } do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(list, found)
		end
	end
	if ignore then
		table.insert(list, ignore)
	end
	params.FilterDescendantsInstances = list
	local result = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	if result then
		return result.Position
	end
	return position - Vector3.new(0, ROOT_HEIGHT, 0)
end

local function countdownLabel(part: Part, returnAt: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(7, 1.2)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Lost fossil"
	label:SetAttribute("EndsAt", returnAt)
	label:SetAttribute("Format", "Returns in %s")
	label:SetAttribute("Done", "")
	label:AddTag("LoopCountdown")
	label.Parent = gui
	gui.Parent = part
end

local function remove(entry: Dropped)
	if dropped[entry.Id] ~= entry then
		return
	end
	dropped[entry.Id] = nil
	entry.Part:Destroy()
end

-- Ramasser un bloc au sol (ProximityPrompt). Renvoie (ok, texte).
function DroppedBlockService.PickUp(player: Player, id: number): (boolean, string)
	local entry = dropped[id]
	if not entry or entry.Part.Parent == nil then
		return false, "Too late!"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Please wait..."
	end
	if CarryService.IsCarrying(player) then
		Notify.Send(player, "You can only carry one fossil!", "error")
		return false, "Already carrying"
	end
	if player.UserId == entry.DroppedBy and os.clock() < entry.LockedUntil then
		Notify.Send(player, "You can't grab it back yet!", "error")
		return false, "Locked"
	end
	-- (bloc du tutoriel : seulement pour ceux qui n'ont pas encore rapporté leur premier bloc, comme au gisement)
	if entry.Block.Tutorial and data.Tutorial >= 2 then
		Notify.Send(player, "This fossil is for new players!", "error")
		return false, "Tutorial"
	end
	if not Guard.Near(player, entry.Part.Position, Pvp.Dropped.PickupDistance + DISTANCE_TOLERANCE) then
		return false, "Too far"
	end
	-- (vivant, debout et sur la route : pas de ramassage à l'abri depuis le bord d'un parc)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Not ready"
	end
	if SpeedService.HasModifier(player, "Knocked") or SpeedService.HasModifier(player, "BearTrap") then
		return false, "Knocked"
	end
	if PlotService.IsPlayerSafe(player) then
		Notify.Send(player, "Step onto the road to grab it!", "error")
		return false, "Safe zone"
	end
	if not CarryService.Carry(player, entry.Block) then
		return false, "Cannot carry"
	end
	remove(entry)
	Signals.Fire("BlockPickedUp", player, entry.Block, entry.DroppedBy)
	return true, "Picked up"
end

-- Pose un bloc au sol (position = point du sol). droppedBy : joueur qui l'a lâché (règle des 3 s). Renvoie l'entrée.
function DroppedBlockService.Place(block: Block, ground: Vector3, droppedBy: Player?, reason: string?): Dropped?
	if type(block) ~= "table" or not Rarity.Info[block.Rarity] or not Guard.Vector3(ground) then
		return nil
	end
	nextId += 1
	local id = nextId
	local info = Rarity.Info[block.Rarity]
	local now, serverNow = os.clock(), Workspace:GetServerTimeNow()
	local part = Instance.new("Part")
	part.Name = "DroppedFossil"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	part.CFrame = CFrame.new(ground + Vector3.new(0, BLOCK_SIZE / 2, 0))
	part.Color = info.Color
	part.Material = if block.Rarity == "Secret" then Enum.Material.Neon else Enum.Material.Slate
	part:SetAttribute("BlockId", block.Id)
	part:SetAttribute("Rarity", block.Rarity)
	part:SetAttribute("Zone", block.Zone)
	part:SetAttribute("DroppedBy", if droppedBy then droppedBy.UserId else 0)
	part:SetAttribute("LockedUntil", serverNow + Pvp.Dropped.LockTime)
	part:SetAttribute("ReturnAt", serverNow + Pvp.Dropped.ReturnTime)
	countdownLabel(part, serverNow + Pvp.Dropped.ReturnTime)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUpPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = block.Rarity .. " Fossil"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Pvp.Dropped.PickupDistance
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if RateLimit.Allow(player, "PickUp", 4, 6) then
			DroppedBlockService.PickUp(player, id)
		end
	end)
	prompt.Parent = part
	local entry: Dropped = {
		Id = id,
		Block = block,
		Part = part,
		DroppedBy = if droppedBy then droppedBy.UserId else 0,
		Reason = reason or "",
		LockedUntil = now + Pvp.Dropped.LockTime,
		ReturnAt = now + Pvp.Dropped.ReturnTime,
	}
	dropped[id] = entry
	part:AddTag(TAG)
	part.Parent = container()
	return entry
end

-- Le porteur lâche son bloc à ses pieds (bonk, piège). Renvoie le bloc lâché (nil s'il ne portait rien).
function DroppedBlockService.Drop(player: Player, reason: string): Block?
	local root = Guard.Root(player)
	if not root or not CarryService.IsCarrying(player) then
		return nil
	end
	local character = player.Character
	local ground = DroppedBlockService.GroundBelow(root.Position, character)
	local block = CarryService.Drop(player)
	if not block then
		return nil
	end
	DroppedBlockService.Place(block, ground, player, reason)
	Signals.Fire("BlockDropped", player, block, reason)
	return block
end

-- Rend un bloc au sol à son gisement tout de suite. true si c'est fait.
function DroppedBlockService.Return(id: number): boolean
	local entry = dropped[id]
	if not entry then
		return false
	end
	remove(entry)
	Signals.Fire("BlockReturned", entry.Block)
	return true
end

-- Rend tous les blocs au sol (commande d'admin, tests). Renvoie le nombre de blocs rendus.
function DroppedBlockService.ReturnAll(): number
	local count = 0
	for id in table.clone(dropped) do
		if DroppedBlockService.Return(id) then
			count += 1
		end
	end
	return count
end

-- Blocs au sol (tests, debug)
function DroppedBlockService.List(): { Dropped }
	local list = {}
	for _, entry in dropped do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

function DroppedBlockService.Get(id: number): Dropped?
	return dropped[id]
end

function DroppedBlockService.Start()
	while true do
		task.wait(CHECK_INTERVAL)
		local now = os.clock()
		for id, entry in table.clone(dropped) do
			if now >= entry.ReturnAt or entry.Part.Parent == nil then
				DroppedBlockService.Return(id)
			end
		end
	end
end

return DroppedBlockService
