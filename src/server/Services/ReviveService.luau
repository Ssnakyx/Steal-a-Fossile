--!strict
-- Cuves de réanimation (brief 3 « boucle ») : 2 au départ, achetables jusqu'à 6 (Config.Economy.Tanks).
-- Un bloc rapporté au parc part dans la première cuve libre, sinon en réserve (data.Stored, Config.Economy.MaxStored) :
-- il partira tout seul dans la prochaine cuve libérée. Minuteur selon la rareté (Config.Rarity), 2x plus court avec le
-- pass Fast Revive (ShopService du brief 4, s'il existe). Cuve prête : « Reveal » tire l'espèce (parmi les espèces de la
-- zone du bloc qui ont sa rareté), la taille et la mutation, et le dino va dans l'enclos (s'il y a de la place).
-- Pièces Tank1..Tank6 du parc : étiquette (compte à rebours tagué « LoopCountdown »), bloc visible dans la cuve,
-- ProximityPrompt « Reveal » quand elle est prête et « Buy Tank » sur la première cuve pas encore achetée.
-- Clés replica « Tanks » ({ [slot]: { Rarity, Zone, StartedAt, EndsAt } }, os.time()), « TankCount », « Stored ».
-- Remotes RevealTank, BuyTank ; événement DinoRevealed. Produit Robux « InstantRevive » (si Config.Shop du brief 4 existe).
-- Signaux : TankStarted(player, slot, tank), DinoRevived(player, id, dino, rarity)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local EnclosureService = require(script.Parent.EnclosureService)
local IncomeService = require(script.Parent.IncomeService)
local MoneyService = require(script.Parent.MoneyService)
local PlotService = require(script.Parent.PlotService)
local ReceiptService = require(script.Parent.ReceiptService)
local ReplicaService = require(script.Parent.ReplicaService)

export type Tank = { Rarity: string, Zone: string, StartedAt: number, EndsAt: number }
export type Rolled = { Species: string, Size: string, Mutation: string, Level: number }

local ReviveService = {}

local CHECK_INTERVAL = 1

type Visual = { Label: TextLabel, Gui: BillboardGui, Prompt: ProximityPrompt, Block: Part? }

local visuals: { [Player]: { [number]: Visual } } = {}
local announced: { [Player]: { [number]: number } } = {} -- cuves prêtes déjà annoncées (slot -> EndsAt)
local rng = Random.new()

-- ===================================================================== tirages

local function shopModule(): any
	local module = script.Parent:FindFirstChild("ShopService")
	if module and module:IsA("ModuleScript") then
		return (require :: any)(module)
	end
	return nil
end

local function hasPass(player: Player, pass: string): boolean
	local shop = shopModule()
	if not shop then
		return false
	end
	local ok, owned = pcall(shop.HasPass, player, pass)
	return ok and owned == true
end

-- Bonus de chance des mutations du joueur (0.1 = +10 %) : pass VIP, dont Config.Shop.Passes.VIP.LuckBonus (brief 4)
-- est un multiplicateur (1.1 = chance x1.1). 0 sans le pass.
function ReviveService.MutationLuck(player: Player): number
	if not hasPass(player, "VIP") then
		return 0
	end
	local folder = ReplicatedStorage.Shared:FindFirstChild("Config")
	if not (folder and folder:FindFirstChild("Shop")) then
		return 0
	end
	local ok, bonus = pcall(function()
		return Config.Shop.Passes.VIP.LuckBonus
	end)
	return if ok and Guard.IsFinite(bonus) and bonus > 1 then bonus - 1 else 0
end

local function pickWeighted<T>(list: { T }, weight: (T) -> number): T
	local total = 0
	for _, item in list do
		total += weight(item)
	end
	local roll = rng:NextNumber() * total
	for _, item in list do
		roll -= weight(item)
		if roll < 0 then
			return item
		end
	end
	return list[#list]
end

-- Espèces possibles pour un bloc de cette rareté venu de cette zone
function ReviveService.Candidates(rarity: string, zoneName: string): { string }
	if rarity == "Secret" then
		return table.clone(Rarity.SecretSpecies)
	end
	local list = {}
	local zone = Zones.ByName[zoneName]
	if zone then
		for _, species in zone.Species do
			if Rarity.Species[species] == rarity then
				table.insert(list, species)
			end
		end
	end
	if #list == 0 then
		-- (bloc d'une source sans zone, ou zone sans cette rareté : toutes les espèces de cette rareté)
		for _, other in Zones.List do
			for _, species in other.Species do
				if Rarity.Species[species] == rarity then
					table.insert(list, species)
				end
			end
		end
	end
	return list
end

-- Tire le dino d'un bloc : espèce (rareté + zone), taille, mutation. luck : bonus de chance des mutations (0.1 = +10 %).
function ReviveService.Roll(rarity: string, zoneName: string, luck: number?): Rolled
	local candidates = ReviveService.Candidates(rarity, zoneName)
	local species = if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else "Compy"
	local size = pickWeighted(Economy.Sizes, function(info: Economy.SizeInfo): number
		return info.Chance
	end)
	local boost = 1 + (if type(luck) == "number" and Guard.IsFinite(luck) and luck > 0 then luck else 0)
	local mutation = ""
	local roll = rng:NextNumber() * 100
	local acc = 0
	-- (de la plus rare à la plus commune : Lava, Crystal, Amber ; chances en %)
	for index = #Economy.Mutations, 1, -1 do
		local info = Economy.Mutations[index]
		acc += info.Chance * boost
		if roll < acc then
			mutation = info.Name
			break
		end
	end
	return { Species = species, Size = size.Name, Mutation = mutation, Level = 0 }
end

-- ===================================================================== état des cuves

local function tankOf(data: { [string]: any }, slot: number): Tank?
	return data.Tanks[tostring(slot)]
end

local function isReady(tank: Tank): boolean
	return os.time() >= tank.EndsAt
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ReplicaService.Set(player, "Tanks", table.clone(data.Tanks))
	ReplicaService.Set(player, "TankCount", data.TankCount)
	ReplicaService.Set(player, "Stored", table.clone(data.Stored))
	ReplicaService.Set(player, "InstantCredits", data.InstantCredits)
end

local function blockPart(tankPart: BasePart, rarity: string): Part
	local info = Rarity.Info[rarity]
	local part = Instance.new("Part")
	part.Name = "TankBlock"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(2.5, 2.5, 2.5)
	part.CFrame = tankPart.CFrame
	part.Color = if info then info.Color else Color3.new(0.5, 0.5, 0.5)
	part.Material = if rarity == "Secret" then Enum.Material.Neon else Enum.Material.Slate
	part.Parent = tankPart
	return part
end

local function updateVisual(player: Player, slot: number)
	local visual = visuals[player] and visuals[player][slot]
	local data = DataService.Get(player)
	if not (visual and data) then
		return
	end
	local plot = PlotService.Get(player)
	local tankPart = plot and plot.Tanks[slot]
	local tank = if slot <= data.TankCount then tankOf(data, slot) else nil
	local label, prompt = visual.Label, visual.Prompt
	-- bloc visible dans la cuve
	local blockRarity = if tank then tank.Rarity else nil
	if visual.Block and (blockRarity == nil or visual.Block:GetAttribute("Rarity") ~= blockRarity) then
		visual.Block:Destroy()
		visual.Block = nil
	end
	if blockRarity and not visual.Block and tankPart then
		local part = blockPart(tankPart, blockRarity)
		part:SetAttribute("Rarity", blockRarity)
		part:SetAttribute("Zone", if tank then tank.Zone else nil) -- (décor du biome : FossilBlockController, brief 9)
		visual.Block = part
	end
	label:SetAttribute("EndsAt", nil)
	if slot > data.TankCount then
		local price = if slot == data.TankCount + 1 then Economy.NextTankPrice(data.TankCount) else nil
		visual.Gui.Enabled = price ~= nil
		label.Text = if price then "Buy Tank: " .. Format.Money(price) else "Locked"
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		prompt.ActionText = if price then "Buy Tank (" .. Format.Money(price) .. ")" else "Locked"
		prompt.ObjectText = "Revival Tank " .. slot
		prompt.HoldDuration = 0.5
		prompt.Enabled = price ~= nil
	elseif not tank then
		visual.Gui.Enabled = true
		label.Text = "Empty"
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		prompt.Enabled = false
	else
		visual.Gui.Enabled = true
		local ready = isReady(tank)
		local info = Rarity.Info[tank.Rarity]
		label.TextColor3 = if info then info.Color else Color3.new(1, 1, 1)
		-- (compte à rebours affiché par LoopController côté client)
		label:SetAttribute("EndsAt", tank.EndsAt)
		label.Text = if ready then "READY!" else tank.Rarity .. " " .. Format.Clock(tank.EndsAt - os.time())
		prompt.ActionText = "Reveal"
		prompt.ObjectText = tank.Rarity .. " Fossil"
		prompt.HoldDuration = 0
		prompt.Enabled = ready
	end
end

local function updateAll(player: Player)
	local list = visuals[player]
	if list then
		for slot in list do
			updateVisual(player, slot)
		end
	end
end

local function startTank(player: Player, data: { [string]: any }, slot: number, rarity: string, zone: string)
	local speed = if hasPass(player, "FastRevive") then Economy.Passes.FastRevive else 1
	local info = Rarity.Info[rarity]
	local duration = math.max(1, math.ceil((if info then info.ReviveTime else 60) / speed))
	local now = os.time()
	-- (Instant Revive gardé : cuve prête tout de suite)
	if data.InstantCredits > 0 then
		data.InstantCredits -= 1
		duration = 0
	end
	local tank: Tank = { Rarity = rarity, Zone = zone, StartedAt = now, EndsAt = now + duration }
	data.Tanks[tostring(slot)] = tank
	Signals.Fire("TankStarted", player, slot, tank)
end

-- Remplit les cuves libres avec les blocs en réserve (les plus anciens d'abord)
local function fillFromStorage(player: Player, data: { [string]: any })
	for slot = 1, data.TankCount do
		if #data.Stored == 0 then
			break
		end
		if not tankOf(data, slot) then
			local block = table.remove(data.Stored, 1)
			startTank(player, data, slot, block.Rarity, block.Zone)
		end
	end
end

-- ===================================================================== API

-- Bloc rapporté au parc (CarryService) : première cuve libre, sinon réserve. false si tout est plein.
function ReviveService.AddBlock(player: Player, block: { [string]: any }): boolean
	local data = DataService.Get(player)
	if not data or type(block) ~= "table" or not Rarity.Info[block.Rarity] then
		return false
	end
	local zone = if type(block.Zone) == "string" then block.Zone else ""
	for slot = 1, data.TankCount do
		if not tankOf(data, slot) then
			startTank(player, data, slot, block.Rarity, zone)
			publish(player)
			updateVisual(player, slot)
			return true
		end
	end
	if #data.Stored >= Economy.MaxStored then
		return false
	end
	table.insert(data.Stored, { Rarity = block.Rarity, Zone = zone })
	publish(player)
	return true
end

-- Place libre pour un bloc (cuve ou réserve) ?
function ReviveService.HasRoom(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	for slot = 1, data.TankCount do
		if not tankOf(data, slot) then
			return true
		end
	end
	return #data.Stored < Economy.MaxStored
end

-- Révèle le dino d'une cuve prête. Renvoie (ok, texte).
function ReviveService.Reveal(player: Player, rawSlot: any): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Please wait..."
	end
	local slot = Guard.Integer(rawSlot, 1, data.TankCount)
	local tank = slot and tankOf(data, slot)
	if not (slot and tank) then
		return false, "This tank is empty."
	end
	if not isReady(tank) then
		return false, "Not ready yet: " .. Format.Clock(tank.EndsAt - os.time())
	end
	if not EnclosureService.HasRoom(player) then
		return false, "Your enclosure is full! Expand it or fuse dinos."
	end
	-- (cuve vidée avant tout le reste : deux demandes en même temps ne révèlent jamais deux dinos)
	local key = tostring(slot)
	data.Tanks[key] = nil
	local rolled = ReviveService.Roll(tank.Rarity, tank.Zone, ReviveService.MutationLuck(player))
	local id = EnclosureService.AddDino(player, rolled, "Spawn")
	if not id then
		data.Tanks[key] = tank
		return false, "Your enclosure is full! Expand it or fuse dinos."
	end
	data.Index.Species[rolled.Species] = true
	fillFromStorage(player, data)
	publish(player)
	updateAll(player)
	local dino = data.Dinos[id]
	Remotes.Event("DinoRevealed"):FireClient(player, id, {
		Species = dino.Species,
		Size = dino.Size,
		Mutation = dino.Mutation,
		Level = dino.Level,
		Rarity = tank.Rarity,
		Income = IncomeService.DinoIncome(dino),
	})
	Signals.Fire("DinoRevived", player, id, dino, tank.Rarity)
	return true, "You revived a " .. EnclosureService.DisplayName(dino) .. "!"
end

-- Achète la cuve suivante. Renvoie (ok, texte).
function ReviveService.BuyTank(player: Player): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Please wait..."
	end
	local price = Economy.NextTankPrice(data.TankCount)
	if not price then
		return false, "You have all the tanks!"
	end
	if not MoneyService.Spend(player, price, "Tank") then
		return false, "Not enough money!"
	end
	data.TankCount += 1
	fillFromStorage(player, data)
	publish(player)
	updateAll(player)
	return true, string.format("New revival tank! (%d/%d)", data.TankCount, Economy.Tanks.Max)
end

-- Finit tout de suite les cuves en cours (produit Instant Revive, admin). Renvoie le nombre de cuves finies.
function ReviveService.FinishAll(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local count = 0
	local now = os.time()
	for _, tank in data.Tanks do
		if tank.EndsAt > now then
			tank.EndsAt = now
			count += 1
		end
	end
	if count > 0 then
		publish(player)
		updateAll(player)
	end
	return count
end

-- Cuves en train de réanimer (pas encore prêtes)
function ReviveService.Running(player: Player): number
	local data = DataService.Get(player)
	local count = 0
	if data then
		local now = os.time()
		for _, tank in data.Tanks do
			if tank.EndsAt > now then
				count += 1
			end
		end
	end
	return count
end

-- ===================================================================== parc

local function onPrompt(player: Player, slot: number, who: Player)
	if who ~= player then
		Notify.Send(who, "This is not your park!", "error")
		return
	end
	if not RateLimit.Allow(player, "TankPrompt", 3, 4) then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ok, text
	if slot == data.TankCount + 1 then
		ok, text = ReviveService.BuyTank(player)
	else
		ok, text = ReviveService.Reveal(player, slot)
	end
	Notify.Send(player, text, if ok then "success" else "error")
end

local function createVisuals(player: Player)
	local plot = PlotService.Get(player)
	if not plot then
		return
	end
	local list: { [number]: Visual } = {}
	for slot, tankPart in plot.Tanks do
		local gui = Instance.new("BillboardGui")
		gui.Name = "TankLabel"
		gui.Size = UDim2.fromScale(7, 1.6)
		gui.StudsOffset = Vector3.new(0, tankPart.Size.Y / 2 + 1.2, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label:SetAttribute("Format", "%s")
		label:SetAttribute("Done", "READY!")
		label:AddTag("LoopCountdown")
		label.Parent = gui
		gui.Parent = tankPart
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TankPrompt"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("OwnerUserId", player.UserId)
		prompt.Triggered:Connect(function(who: Player)
			onPrompt(player, slot, who)
		end)
		prompt.Parent = tankPart
		list[slot] = { Label = label, Gui = gui, Prompt = prompt, Block = nil }
	end
	visuals[player] = list
	updateAll(player)
end

local function destroyVisuals(player: Player)
	local list = visuals[player]
	visuals[player] = nil
	if list then
		for _, visual in list do
			visual.Gui:Destroy()
			visual.Prompt:Destroy()
			if visual.Block then
				visual.Block:Destroy()
			end
		end
	end
end

-- Cuves devenues prêtes : prompt « Reveal » et message (une fois par cuve)
local function checkReady(player: Player)
	local data = DataService.Get(player)
	local seen = announced[player]
	if not (data and seen) then
		return
	end
	for key, tank in data.Tanks do
		local slot = tonumber(key)
		if slot and isReady(tank) and seen[slot] ~= tank.EndsAt then
			seen[slot] = tank.EndsAt
			updateVisual(player, slot)
			Notify.Send(player, "Your " .. tank.Rarity .. " fossil is ready to reveal!", "success")
		end
	end
end

function ReviveService.Init()
	Net.Function("RevealTank", { Rate = 3, Burst = 5 }, function(player: Player, slot: any)
		return ReviveService.Reveal(player, slot)
	end)
	Net.Function("BuyTank", { Rate = 2, Burst = 4 }, function(player: Player)
		return ReviveService.BuyTank(player)
	end)
	AdminService.RegisterCommand("finishtanks", {
		Description = "Finish every running revival tank now",
		Usage = "finishtanks [player]",
		Run = function(caller: Player, args: { string })
			local target = AdminService.FindPlayer(caller, args[1])
			if not target then
				return false, "Player not found"
			end
			return true, ReviveService.FinishAll(target) .. " tank(s) finished"
		end,
	})
	AdminService.RegisterCommand("giveblock", {
		Description = "Bring a fossil block home (tank or storage)",
		Usage = "giveblock <rarity> [zone index] [player]",
		Run = function(caller: Player, args: { string })
			local wanted = string.lower(args[1] or "")
			local rarity = nil
			for _, name in Rarity.Order do
				if string.lower(name) == wanted then
					rarity = name
				end
			end
			local zoneIndex = Guard.Integer(tonumber(args[2] or "1"), 1, #Zones.List)
			local target = AdminService.FindPlayer(caller, args[3])
			if not (rarity and zoneIndex and target) then
				return false, "Usage: giveblock <rarity> [zone index 1-8] [player]"
			end
			local zone = Zones.List[zoneIndex].Name
			if not ReviveService.AddBlock(target, { Rarity = rarity, Zone = zone }) then
				return false, "Tanks and storage are full"
			end
			return true, rarity .. " block from " .. zone .. " given"
		end,
	})
	-- Instant Revive : produit déclaré par le brief 4 dans Config.Shop.Products (Id = 0 tant qu'il n'est pas créé)
	local folder = ReplicatedStorage.Shared:FindFirstChild("Config")
	if folder and folder:FindFirstChild("Shop") then
		local products = Config.Shop.Products
		local product = type(products) == "table" and products.InstantRevive
		if type(product) == "table" and type(product.Id) == "number" then
			ReceiptService.Register("InstantRevive", product.Id, function(player: Player, _data, _receipt): boolean
				if ReviveService.Running(player) > 0 then
					ReviveService.FinishAll(player)
					return true
				end
				-- aucune cuve en cours : gardé pour la prochaine cuve lancée
				local data = DataService.Get(player)
				if not data or data.InstantCredits >= Economy.MaxInstantCredits then
					return false
				end
				data.InstantCredits += 1
				publish(player)
				Notify.Send(player, "Instant Revive saved! Your next fossil will be ready right away.", "success")
				return true
			end)
		end
	end
end

function ReviveService.Start()
	while true do
		task.wait(CHECK_INTERVAL)
		for player in announced do
			checkReady(player)
		end
	end
end

function ReviveService.OnPlayerReady(player: Player, data: { [string]: any })
	-- cuves déjà prêtes à l'arrivée : annoncées une fois
	local seen: { [number]: number } = {}
	announced[player] = seen
	fillFromStorage(player, data)
	createVisuals(player)
	publish(player)
	local ready = 0
	for key, tank in data.Tanks do
		local slot = tonumber(key)
		if slot and isReady(tank) then
			seen[slot] = tank.EndsAt
			ready += 1
		end
	end
	if ready > 0 then
		Notify.Send(player, ready .. " fossil(s) ready to reveal in your park!", "success")
	end
end

function ReviveService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	announced[player] = nil
	destroyVisuals(player)
end

return ReviveService
