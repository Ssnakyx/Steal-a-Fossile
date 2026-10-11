--!strict
-- Gisements (brief 3 « boucle ») : blocs fossiles posés sur les gisements des zones (ZoneService), tirés selon les
-- chances de la zone (Config.Zones, x Server Luck du brief 4 s'il existe). Toutes les 5 min, les places vides se
-- remplissent (compte à rebours répliqué : attribut « DigRefillAt » de Workspace, heure serveur, et étiquette au-dessus
-- de chaque gisement). Un bloc de rareté Config.Zones.Dig.AlertRarity ou mieux (Mythic) est annoncé à tout le serveur :
-- bandeau en haut de l'écran (remote FossilAlert, AlertController) et message dans le chat (LoopAnnounce).
-- Arracher : ProximityPrompt « Grab » maintenu 1 s. Le serveur vérifie la durée (depuis PromptButtonHoldBegan), la
-- distance et qu'on ne porte rien, puis CarryService.Carry. La place reste « dehors » jusqu'à ce que le bloc soit
-- rapporté dans un parc (place libérée, remplie au prochain remplissage) ou rendu (il revient à sa place).
-- Blocs posés : pièces « FossilBlock » taguées « FossilBlock », attributs BlockId, Rarity, Zone.
-- Tutoriel côté serveur (data.Tutorial : 1 premier bloc arraché, 2 rapporté, 3 premier dino révélé) : tant qu'un joueur
-- n'a pas rapporté son premier bloc, la Beach garde un bloc Common disponible.
-- Signaux : BlockGrabbed(player, block), DigSitesRefilled()
-- Écoute : BlockReturned(block), BlockBanked(player, block), DinoRevived(player, ...)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Notify = require(script.Parent.Parent.Lib.Notify)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local ReplicaService = require(script.Parent.ReplicaService)
local ZoneService = require(script.Parent.ZoneService)

type Block = CarryService.Block
type Slot = {
	Index: number,
	Site: string, -- clé du gisement (« Beach/Site1 »)
	Zone: string,
	Anchor: BasePart, -- pièce du gisement (parent des blocs posés)
	CFrame: CFrame,
	State: "Empty" | "Present" | "Out",
	Block: Block?,
	Part: BasePart?,
}
type Site = { Key: string, Zone: string, Anchor: BasePart, Slots: { Slot }, Label: TextLabel }
type Hold = { Prompt: ProximityPrompt, Began: number, Ended: number? }

local DigSiteService = {}

local BLOCK_SIZE = 3
local HOLD_TOLERANCE = 0.2 -- secondes de moins permises sur le maintien (latence)
local DISTANCE_TOLERANCE = 5 -- studs de plus permis sur la portée du ProximityPrompt
local TUTORIAL_INTERVAL = 2

local sites: { Site } = {}
local siteByKey: { [string]: Site } = {}
local holds: { [Player]: Hold } = {}
local ready: { [Player]: boolean } = {}
local nextBlockId = 0
local refillAt = 0
local rng = Random.new()

-- ===================================================================== tirage

local function serverLuck(): number
	local module = script.Parent:FindFirstChild("ShopService")
	if not (module and module:IsA("ModuleScript")) then
		return 1
	end
	local ok, luck = pcall(function()
		return (require :: any)(module).ServerLuck()
	end)
	return if ok and Guard.IsFinite(luck) and luck >= 1 then luck else 1
end

-- Rareté d'un nouveau bloc dans cette zone
function DigSiteService.RollRarity(zoneName: string, luck: number?): string
	local chances = Zones.Chances(zoneName, luck or serverLuck())
	local roll = rng:NextNumber()
	local last = "Common"
	for _, rarity in Rarity.Order do
		local chance = chances[rarity]
		if chance then
			last = rarity
			roll -= chance
			if roll < 0 then
				return rarity
			end
		end
	end
	return last
end

local function newBlock(rarity: string, slot: Slot): Block
	nextBlockId += 1
	return { Id = nextBlockId, Rarity = rarity, Zone = slot.Zone, Site = slot.Site, Slot = slot.Index }
end

-- ===================================================================== tutoriel

local function advanceTutorial(player: Player, step: number)
	local data = DataService.Get(player)
	if data and data.Tutorial < step then
		data.Tutorial = step
		ReplicaService.Set(player, "Tutorial", step)
	end
end

-- ===================================================================== arracher

local function tryGrab(player: Player, slot: Slot, prompt: ProximityPrompt)
	if not RateLimit.Allow(player, "Grab", 3, 4) then
		return
	end
	local hold = holds[player]
	holds[player] = nil
	local block, part = slot.Block, slot.Part
	if slot.State ~= "Present" or not block or not part or prompt.Parent ~= part then
		return
	end
	if not DataService.Get(player) then
		return
	end
	if CarryService.IsCarrying(player) then
		Notify.Send(player, "You can only carry one fossil!", "error")
		return
	end
	-- (bloc du tutoriel : seulement pour ceux qui n'ont pas encore rapporté leur premier bloc)
	local data = DataService.Get(player)
	if block.Tutorial and data and data.Tutorial >= 2 then
		Notify.Send(player, "This fossil is for new players!", "error")
		return
	end
	-- maintien d'au moins GrabTime (mesuré par le serveur ; un client qui déclenche sans maintenir est ignoré)
	if not hold or hold.Prompt ~= prompt then
		return
	end
	local held = (hold.Ended or os.clock()) - hold.Began
	if held < Zones.Dig.GrabTime - HOLD_TOLERANCE then
		return
	end
	if not Guard.Near(player, part.Position, Zones.Dig.GrabDistance + DISTANCE_TOLERANCE) then
		return
	end
	if not CarryService.Carry(player, block) then
		return
	end
	slot.State = "Out"
	slot.Part = nil
	part:Destroy()
	Signals.Fire("BlockGrabbed", player, block)
	advanceTutorial(player, 1)
end

-- ===================================================================== blocs posés

local function placeBlock(slot: Slot, block: Block)
	local info = Rarity.Info[block.Rarity]
	local part = Instance.new("Part")
	part.Name = "FossilBlock"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	part.CFrame = slot.CFrame
	part.Color = if info then info.Color else Color3.new(0.6, 0.6, 0.6)
	part.Material = if block.Rarity == "Secret" then Enum.Material.Neon else Enum.Material.Slate
	part:SetAttribute("BlockId", block.Id)
	part:SetAttribute("Rarity", block.Rarity)
	part:SetAttribute("Zone", block.Zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = block.Rarity .. " Fossil"
	prompt.HoldDuration = Zones.Dig.GrabTime
	prompt.MaxActivationDistance = Zones.Dig.GrabDistance
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		holds[player] = { Prompt = prompt, Began = os.clock(), Ended = nil }
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		local hold = holds[player]
		if hold and hold.Prompt == prompt and hold.Ended == nil then
			hold.Ended = os.clock()
		end
	end)
	prompt.Triggered:Connect(function(player: Player)
		tryGrab(player, slot, prompt)
	end)
	prompt.Parent = part
	part:AddTag("FossilBlock")
	slot.State = "Present"
	slot.Block = block
	slot.Part = part
	part.Parent = slot.Anchor
end

local function clearSlot(slot: Slot)
	if slot.Part then
		slot.Part:Destroy()
	end
	slot.State = "Empty"
	slot.Block = nil
	slot.Part = nil
end

-- Remplit les places vides de tous les gisements (toutes les 5 min). Renvoie le nombre de blocs posés.
-- Rareté assez haute pour une alerte de tout le serveur (Config.Zones.Dig.AlertRarity)
function DigSiteService.IsAlertRarity(rarity: string): boolean
	local info = Rarity.Info[rarity]
	local threshold = Rarity.Info[Zones.Dig.AlertRarity or "Secret"]
	return info ~= nil and threshold ~= nil and info.Rank >= threshold.Rank
end

type Alert = { Zone: string, Rarity: string, Count: number }

-- Note un bloc posé pour l'alerte : un seul message par zone (sa meilleure rareté, et combien de blocs rares)
local function noteAlert(alerts: { [string]: Alert }, zone: string, rarity: string)
	if not DigSiteService.IsAlertRarity(rarity) then
		return
	end
	local alert = alerts[zone]
	if not alert then
		alerts[zone] = { Zone = zone, Rarity = rarity, Count = 1 }
		return
	end
	alert.Count += 1
	if Rarity.Info[rarity].Rank > Rarity.Info[alert.Rarity].Rank then
		alert.Rarity = rarity
	end
end

local function sendAlerts(alerts: { [string]: Alert })
	local list: { Alert } = {}
	for _, alert in alerts do
		table.insert(list, alert)
	end
	-- (les plus rares d'abord, puis dans l'ordre de la route)
	table.sort(list, function(a, b)
		local ra, rb = Rarity.Info[a.Rarity].Rank, Rarity.Info[b.Rarity].Rank
		if ra ~= rb then
			return ra > rb
		end
		local za, zb = Zones.ByName[a.Zone], Zones.ByName[b.Zone]
		return (if za then za.Index else 0) < (if zb then zb.Index else 0)
	end)
	for _, alert in list do
		local text = string.format("A %s fossil appeared in the %s!", string.upper(alert.Rarity), alert.Zone)
		if alert.Count > 1 then
			text = string.format("%d %s fossils appeared in the %s!", alert.Count, string.upper(alert.Rarity), alert.Zone)
		end
		Remotes.Event("LoopAnnounce"):FireAllClients(text)
		Remotes.Event("FossilAlert"):FireAllClients(alert.Rarity, alert.Zone, alert.Count)
	end
end

function DigSiteService.Refill(): number
	local luck = serverLuck()
	local placed = 0
	local alerts: { [string]: Alert } = {}
	for _, site in sites do
		for _, slot in site.Slots do
			if slot.State == "Empty" then
				local rarity = DigSiteService.RollRarity(site.Zone, luck)
				placeBlock(slot, newBlock(rarity, slot))
				placed += 1
				noteAlert(alerts, site.Zone, rarity)
			end
		end
	end
	sendAlerts(alerts)
	Signals.Fire("DigSitesRefilled")
	return placed
end

-- Pose tout de suite un bloc de cette rareté dans un gisement de la zone (commande d'admin) : une place vide si
-- possible, sinon à la place d'un bloc moins rare (jamais celui du tutoriel). L'alerte part comme pour un remplissage.
-- Renvoie true si le bloc est posé.
function DigSiteService.ForceSpawn(zoneName: string, rarity: string): boolean
	if not (Rarity.Info[rarity] and Zones.ByName[zoneName]) then
		return false
	end
	local empty: Slot? = nil
	local weakest: Slot? = nil
	for _, site in sites do
		if site.Zone == zoneName then
			for _, slot in site.Slots do
				if slot.State == "Empty" and not empty then
					empty = slot
				elseif slot.State == "Present" and slot.Block and not slot.Block.Tutorial then
					local rank = Rarity.Info[slot.Block.Rarity].Rank
					local best = weakest and weakest.Block
					if rank < Rarity.Info[rarity].Rank and (not best or rank < Rarity.Info[best.Rarity].Rank) then
						weakest = slot
					end
				end
			end
		end
	end
	local slot = empty or weakest
	if not slot then
		return false
	end
	if slot.State == "Present" then
		clearSlot(slot)
	end
	placeBlock(slot, newBlock(rarity, slot))
	local alerts: { [string]: Alert } = {}
	noteAlert(alerts, zoneName, rarity)
	sendAlerts(alerts)
	return true
end

-- Rend un bloc à sa place de gisement (gardien qui attrape, bloc au sol pas ramassé du brief 7...).
-- Un bloc sans gisement (pluie de météorites) ou dont la place a changé disparaît. Renvoie true s'il est reposé.
function DigSiteService.ReturnBlock(block: Block): boolean
	local site = if type(block) == "table" then siteByKey[block.Site or ""] else nil
	local slot = if site then site.Slots[block.Slot or 0] else nil
	if not (slot and slot.State == "Out" and slot.Block and slot.Block.Id == block.Id) then
		return false
	end
	placeBlock(slot, block)
	return true
end

-- Libère la place d'un bloc rapporté dans un parc (elle sera remplie au prochain remplissage)
function DigSiteService.ReleaseBlock(block: Block): boolean
	local site = if type(block) == "table" then siteByKey[block.Site or ""] else nil
	local slot = if site then site.Slots[block.Slot or 0] else nil
	if not (slot and slot.State == "Out" and slot.Block and slot.Block.Id == block.Id) then
		return false
	end
	clearSlot(slot)
	return true
end

-- Tous les gisements (tests, debug)
function DigSiteService.Sites(): { Site }
	return sites
end

-- Prochain remplissage (Workspace:GetServerTimeNow())
function DigSiteService.RefillAt(): number
	return refillAt
end

local function setRefillAt(at: number)
	refillAt = at
	Workspace:SetAttribute("DigRefillAt", at)
	for _, site in sites do
		site.Label:SetAttribute("EndsAt", at)
	end
end

-- Tutoriel : un bloc Common à la Beach tant qu'un joueur prêt n'a pas rapporté son premier bloc. Il est posé sur une
-- place vide (jamais à la place d'un autre bloc) et réservé aux nouveaux joueurs.
function DigSiteService.EnsureTutorialBlock(): boolean
	local needed = false
	for player in ready do
		local data = DataService.Get(player)
		if data and data.Tutorial < 2 then
			needed = true
			break
		end
	end
	if not needed then
		return false
	end
	local zone, rarity = Zones.Dig.TutorialZone, Zones.Dig.TutorialRarity
	local empty: Slot? = nil
	for _, site in sites do
		if site.Zone == zone then
			for _, slot in site.Slots do
				if slot.State == "Present" and slot.Block and slot.Block.Rarity == rarity then
					return false
				elseif slot.State == "Empty" and not empty then
					empty = slot
				end
			end
		end
	end
	if not empty then
		return false
	end
	local block = newBlock(rarity, empty)
	block.Tutorial = true
	placeBlock(empty, block)
	return true
end

-- ===================================================================== démarrage

local function slotFrames(anchor: BasePart): { CFrame }
	local frames = {}
	local points = {}
	for _, child in anchor:GetChildren() do
		if child:IsA("Attachment") and string.match(child.Name, "^Slot%d+$") then
			table.insert(points, child)
		end
	end
	table.sort(points, function(a, b)
		return (tonumber(string.match(a.Name, "%d+")) or 0) < (tonumber(string.match(b.Name, "%d+")) or 0)
	end)
	for _, point in points do
		table.insert(frames, anchor.CFrame * point.CFrame)
	end
	if #frames == 0 then
		local top = anchor.Size.Y / 2 + BLOCK_SIZE / 2
		local offsets = { { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 }, { 0, 0 }, { 0, -6 } }
		for k = 1, math.min(Zones.Dig.BlocksPerSite, #offsets) do
			table.insert(frames, anchor.CFrame * CFrame.new(offsets[k][1], top, offsets[k][2]))
		end
	end
	return frames
end

local function siteLabel(anchor: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "SiteLabel"
	gui.Size = UDim2.fromScale(10, 1.6)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 235, 170)
	label.TextStrokeTransparency = 0.4
	label.Text = "Dig Site"
	label:SetAttribute("Format", "Refill in %s")
	label:SetAttribute("Done", "Refilling...")
	label:AddTag("LoopCountdown")
	label.Parent = gui
	gui.Parent = anchor
	return label
end

function DigSiteService.Init()
	for _, geo in ZoneService.List() do
		for _, anchor in geo.Sites do
			local key = geo.Name .. "/" .. anchor.Name
			local slots: { Slot } = {}
			for index, frame in slotFrames(anchor) do
				table.insert(slots, {
					Index = index,
					Site = key,
					Zone = geo.Name,
					Anchor = anchor,
					CFrame = frame,
					State = "Empty",
					Block = nil,
					Part = nil,
				})
			end
			local site: Site = { Key = key, Zone = geo.Name, Anchor = anchor, Slots = slots, Label = siteLabel(anchor) }
			table.insert(sites, site)
			siteByKey[key] = site
		end
	end
	Signals.Connect("BlockReturned", function(block: Block)
		DigSiteService.ReturnBlock(block)
	end)
	Signals.Connect("BlockBanked", function(player: Player, block: Block)
		DigSiteService.ReleaseBlock(block)
		advanceTutorial(player, 2)
	end)
	Signals.Connect("DinoRevived", function(player: Player)
		advanceTutorial(player, 3)
	end)
	-- (un joueur qui part avant d'être prêt ne garde pas de maintien en mémoire)
	Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
	end)
	AdminService.RegisterCommand("refill", {
		Description = "Refill every dig site now",
		Usage = "refill",
		Run = function()
			local placed = DigSiteService.Refill()
			setRefillAt(Workspace:GetServerTimeNow() + Zones.Dig.RefillInterval)
			return true, placed .. " fossil(s) placed"
		end,
	})
	AdminService.RegisterCommand("spawnrare", {
		Description = "Spawn a fossil of this rarity in a dig site now (rare ones alert the server)",
		Usage = "spawnrare <rarity> [zone 1-8]",
		Run = function(_caller: Player, args: { string })
			local wanted = string.lower(args[1] or "")
			local rarity: string? = nil
			for _, name in Rarity.Order do
				if string.lower(name) == wanted then
					rarity = name
				end
			end
			local zoneIndex = Guard.Integer(tonumber(args[2] or "1"), 1, #Zones.List)
			if not (rarity and zoneIndex) then
				return false, "Usage: spawnrare <rarity> [zone 1-8]"
			end
			local zone = Zones.List[zoneIndex].Name
			if not DigSiteService.ForceSpawn(zone, rarity) then
				return false, "No free dig site place in " .. zone
			end
			return true, rarity .. " fossil spawned in " .. zone
		end,
	})
	AdminService.RegisterCommand("tutorial", {
		Description = "Set the tutorial step (0 = new player)",
		Usage = "tutorial <0-3> [player]",
		Run = function(caller: Player, args: { string })
			local step = Guard.Integer(tonumber(args[1]), 0, 3)
			local target = AdminService.FindPlayer(caller, args[2])
			local data = target and DataService.Get(target)
			if not (step and target and data) then
				return false, "Usage: tutorial <0-3> [player]"
			end
			data.Tutorial = step
			ReplicaService.Set(target, "Tutorial", step)
			return true, "Tutorial step " .. step
		end,
	})
end

function DigSiteService.Start()
	DigSiteService.Refill()
	setRefillAt(Workspace:GetServerTimeNow() + Zones.Dig.RefillInterval)
	local sinceTutorial = 0
	while true do
		task.wait(1)
		local now = Workspace:GetServerTimeNow()
		if now >= refillAt then
			DigSiteService.Refill()
			local nextAt = refillAt
			while nextAt <= now do
				nextAt += Zones.Dig.RefillInterval
			end
			setRefillAt(nextAt)
		end
		sinceTutorial += 1
		if sinceTutorial >= TUTORIAL_INTERVAL then
			sinceTutorial = 0
			DigSiteService.EnsureTutorialBlock()
		end
	end
end

function DigSiteService.OnPlayerReady(player: Player, data: { [string]: any })
	ready[player] = true
	ReplicaService.Set(player, "Tutorial", data.Tutorial)
	if data.Tutorial < 2 then
		DigSiteService.EnsureTutorialBlock()
	end
end

function DigSiteService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	ready[player] = nil
	holds[player] = nil
end

return DigSiteService
