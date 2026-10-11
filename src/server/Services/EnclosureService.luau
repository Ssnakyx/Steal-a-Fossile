--!strict
-- Enclos du parc (brief 3 « boucle ») : les dinos du joueur (data.Dinos), un nombre de slots agrandissable
-- (Config.Economy.Enclosure) et leurs modèles posés sur la pièce « Enclosure » du parc, à une place libre au hasard.
-- Promenade (Config.Park.Roam, src/shared/Roam.luau) : chaque dino fait une pause, puis marche vers un autre point
-- libre de l'enclos, et ainsi de suite. Un trajet = attributs WalkFrom (CFrame), WalkTo (Vector3), Speed, State
-- « Walk » et StateAt : chaque client calcule la pose en cours (DinoAnimController) ; le serveur ne déplace la pièce
-- Root qu'à l'arrivée. Les dinos provisoires en briques (espèce sans modèle) restent à leur place.
-- Modèle d'un dino, compatible avec le pipeline dinos (brief 2) : Model tagué « Dino », pièce invisible « Root » au sol
-- (PrimaryPart), attributs Species (nom du module de src/shared/DinoModels), Scale, Mutation, Level ("Normal",
-- "Golden", "Diamond"), State, StateAt, plus DinoId et OwnerUserId. Si l'espèce a son module DinoModels, le client
-- (DinoAnimController) construit et anime les briques ; sinon un dino provisoire en quelques briques est posé ici.
-- Espèces assemblées en jeu (hybrides du brief 8) : FusionService les déclare avec RegisterSpecies (modèle, taille de base,
-- rareté), comme une fiche de Config.Species.
-- Clés replica « Dinos » ({ [id]: { Species, Size, Mutation, Level, Income } }) et « EnclosureSlots ».
-- Remote BuyEnclosure (et ProximityPrompt « Expand » sur l'enclos).
-- Signaux : DinoAdded(player, id, dino), DinoRemoved(player, id, dino), DinoMutated(player, id, dino)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Park = require(ReplicatedStorage.Shared.Config.Park)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Format = require(ReplicatedStorage.Shared.Format)
local Roam = require(ReplicatedStorage.Shared.Roam)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MoneyService = require(script.Parent.MoneyService)
local PlotService = require(script.Parent.PlotService)
local ReplicaService = require(script.Parent.ReplicaService)

export type Dino = { Species: string, Size: string, Mutation: string, Level: number, Got: number }
-- Espèce sans fiche Config.Species (hybride) : Model = attribut Species du modèle (clé HybridBuilder), HasModel = le
-- client sait construire ses briques, Rarity = rareté affichée (effets de DinoAnimController)
export type SpeciesLook = { Model: string, BaseSize: number, HasModel: boolean, Rarity: string? }

local EnclosureService = {}

local COLUMNS = 6
local DEFAULT_SIZE = 6 -- taille de base (studs) d'un dino provisoire sans fiche Config.Species
local SIZE_INFO: { [string]: Economy.SizeInfo } = {}
for _, size in Economy.Sizes do
	SIZE_INFO[size.Name] = size
end
local MUTATIONS: { [string]: boolean } = { [""] = true }
for _, mutation in Economy.Mutations do
	MUTATIONS[mutation.Name] = true
end

-- Un dino qui se promène (Config.Park.Roam)
type Walker = {
	Model: Model,
	Radius: number, -- rayon du corps pour les places (studs) : Footprint x taille du dino
	Speed: number, -- vitesse de marche (studs/s)
	Pose: CFrame, -- où il est à l'arrêt, ou où il arrive pendant un trajet
	Walking: boolean,
	Until: number, -- os.clock() de la fin du trajet ou de la pause
}

type Pen = {
	Plot: PlotService.Plot,
	Folder: Folder,
	Models: { [string]: Model },
	Spots: { [string]: number }, -- id -> place sur la grille (dinos provisoires, ou enclos plein)
	Walkers: { [string]: Walker }, -- id -> promenade
	Prompt: ProximityPrompt?,
}

local pens: { [Player]: Pen } = {}
local looks: { [string]: SpeciesLook } = {}
local rng = Random.new()

local function rateText(income: number): string
	if income < 10 then
		local text = string.format("%.1f", income)
		text = string.gsub(text, "%.0$", "")
		return "$" .. text .. "/s"
	end
	return Format.Rate(income)
end

-- Nom affiché : « Big Amber Golden Compy »
function EnclosureService.DisplayName(dino: Dino): string
	local parts = {}
	if dino.Size ~= "Normal" then
		table.insert(parts, dino.Size)
	end
	if dino.Mutation ~= "" then
		table.insert(parts, dino.Mutation)
	end
	local level = Economy.Levels[dino.Level + 1]
	if level and dino.Level > 0 then
		table.insert(parts, level.Name)
	end
	table.insert(parts, dino.Species)
	return table.concat(parts, " ")
end

-- Déclare une espèce assemblée en jeu (hybride du brief 8, appelé dans l'Init de FusionService)
function EnclosureService.RegisterSpecies(species: string, look: SpeciesLook)
	if type(species) ~= "string" or type(look) ~= "table" or type(look.Model) ~= "string" then
		error("EnclosureService.RegisterSpecies : espèce ou modèle invalide", 2)
	end
	if not Guard.IsFinite(look.BaseSize) or look.BaseSize <= 0 then
		error("EnclosureService.RegisterSpecies : taille de base invalide", 2)
	end
	looks[species] = table.clone(look)
end

-- Taille de base (studs) d'une espèce : Config.Species, sinon RegisterSpecies, sinon une taille par défaut
local function baseSize(species: string): number
	local info = IncomeService.SpeciesInfo(species)
	if info and Guard.IsFinite(info.BaseSize) and info.BaseSize > 0 then
		return info.BaseSize
	end
	local look = looks[species]
	return if look then look.BaseSize else DEFAULT_SIZE
end

-- Nom du module DinoModels d'une espèce (Config.Species.Model, sinon le nom sans espaces ni tirets : T-Rex -> TRex) ;
-- pour un hybride, sa clé HybridBuilder (RegisterSpecies)
function EnclosureService.ModelName(species: string): string
	local look = looks[species]
	if look then
		return look.Model
	end
	local info = IncomeService.SpeciesInfo(species)
	if info and type(info.Model) == "string" then
		return info.Model
	end
	return (string.gsub(species, "[^%w]", ""))
end

local function hasDinoModel(species: string, moduleName: string): boolean
	local look = looks[species]
	if look then
		return look.HasModel
	end
	local folder = ReplicatedStorage.Shared:FindFirstChild("DinoModels")
	local module = folder and folder:FindFirstChild(moduleName)
	return module ~= nil and module:IsA("ModuleScript")
end

-- ===================================================================== données

function EnclosureService.Slots(player: Player): number
	local data = DataService.Get(player)
	return Economy.EnclosureSlots(if data then data.EnclosureUpgrades else 0)
end

function EnclosureService.Count(player: Player): number
	local data = DataService.Get(player)
	local count = 0
	if data then
		for _ in data.Dinos do
			count += 1
		end
	end
	return count
end

function EnclosureService.HasRoom(player: Player): boolean
	return DataService.Get(player) ~= nil and EnclosureService.Count(player) < EnclosureService.Slots(player)
end

function EnclosureService.GetDino(player: Player, id: string): Dino?
	local data = DataService.Get(player)
	return if data and type(id) == "string" then data.Dinos[id] else nil
end

-- Modèle d'un dino dans le parc (nil si le joueur n'a pas de parc)
function EnclosureService.ModelOf(player: Player, id: string): Model?
	local pen = pens[player]
	return if pen then pen.Models[id] else nil
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local list = {}
	for id, dino in data.Dinos do
		list[id] = {
			Species = dino.Species,
			Size = dino.Size,
			Mutation = dino.Mutation,
			Level = dino.Level,
			Income = IncomeService.DinoIncome(dino),
		}
	end
	ReplicaService.Set(player, "Dinos", list)
	ReplicaService.Set(player, "EnclosureSlots", Economy.EnclosureSlots(data.EnclosureUpgrades))
	IncomeService.Refresh(player)
end

-- ===================================================================== modèles

local function spotCFrame(enclosure: BasePart, spot: number): CFrame
	local rows = math.ceil(Economy.EnclosureSlots(#Economy.Enclosure.Prices) / COLUMNS)
	local column = (spot - 1) % COLUMNS
	local row = (spot - 1) // COLUMNS
	local size = enclosure.Size
	local x = (column + 0.5 - COLUMNS / 2) * size.X / COLUMNS
	local z = (row + 0.5 - rows / 2) * size.Z / rows
	return enclosure.CFrame * CFrame.new(x, size.Y / 2, z) * CFrame.Angles(0, math.pi, 0)
end

local function placeholderPart(name: string, size: Vector3, offset: Vector3, base: CFrame, color: Color3, dino: Dino, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = base * CFrame.new(offset)
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	if dino.Level == 1 then
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Reflectance = 0.2
	elseif dino.Level >= 2 then
		part.Color = Color3.fromRGB(180, 240, 255)
		part.Material = Enum.Material.Glass
	elseif dino.Mutation == "Amber" then
		part.Color = Color3.fromRGB(255, 170, 30)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.2
	elseif dino.Mutation == "Crystal" then
		part.Color = Color3.fromRGB(150, 230, 255)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.15
	elseif dino.Mutation == "Lava" then
		part.Material = Enum.Material.CrackedLava
		part.Color = Color3.fromRGB(200, 70, 30)
	end
	part.Parent = parent
end

-- Dino provisoire en briques (espèce sans module DinoModels) : corps, tête vers -Z, queue, pattes
local function buildPlaceholder(model: Model, dino: Dino, base: CFrame, scale: number)
	local b = baseSize(dino.Species) * scale
	local look = looks[dino.Species]
	local rarity = Rarity.Info[Rarity.Species[dino.Species] or (look and look.Rarity) or ""]
	local color = if rarity then rarity.Color else Color3.fromRGB(120, 160, 110)
	placeholderPart("Body", Vector3.new(0.4, 0.35, 0.75) * b, Vector3.new(0, 0.45, 0) * b, base, color, dino, model)
	placeholderPart("Head", Vector3.new(0.3, 0.28, 0.32) * b, Vector3.new(0, 0.72, -0.45) * b, base, color, dino, model)
	placeholderPart("Tail", Vector3.new(0.16, 0.16, 0.5) * b, Vector3.new(0, 0.45, 0.6) * b, base, color, dino, model)
	placeholderPart("LegLeft", Vector3.new(0.12, 0.3, 0.12) * b, Vector3.new(-0.12, 0.15, 0) * b, base, color, dino, model)
	placeholderPart("LegRight", Vector3.new(0.12, 0.3, 0.12) * b, Vector3.new(0.12, 0.15, 0) * b, base, color, dino, model)
end

local function nameLabel(root: BasePart, dino: Dino, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffset = Vector3.new(0, height + 1.5, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Name"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = EnclosureService.DisplayName(dino)
	title.Parent = gui
	local income = Instance.new("TextLabel")
	income.Name = "Income"
	income.BackgroundTransparency = 1
	income.Position = UDim2.fromScale(0, 0.55)
	income.Size = UDim2.fromScale(1, 0.45)
	income.Font = Enum.Font.GothamBold
	income.TextScaled = true
	income.TextColor3 = Color3.fromRGB(120, 255, 120)
	income.TextStrokeTransparency = 0.4
	income.Text = rateText(IncomeService.DinoIncome(dino))
	income.Parent = gui
	gui.Parent = root
end

local function freeSpot(pen: Pen): number
	local used: { [number]: boolean } = {}
	for _, spot in pen.Spots do
		used[spot] = true
	end
	local spot = 1
	while used[spot] do
		spot += 1
	end
	return spot
end

-- ===================================================================== promenade

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Place libre autour d'un point : studs entre ce corps et le plus proche des autres dinos (à l'arrêt, ou là où ils
-- arrivent), corps compris (négatif : ils se touchent)
local function clearance(pen: Pen, point: Vector3, radius: number, skip: string?): number
	local best = math.huge
	for id, other in pen.Walkers do
		if id ~= skip then
			best = math.min(best, (flat(other.Pose.Position) - flat(point)).Magnitude - radius - other.Radius)
		end
	end
	return best
end

-- Point de l'enclos pour un corps de rayon `radius`, loin du bord, à Gap studs au moins des autres dinos. Avec `from` :
-- à une distance de MinLeg à MaxLeg studs de ce point. Si aucun essai n'a assez de place : nil (`strict`), sinon le
-- plus dégagé des essais (apparition dans un enclos très plein).
local function pickPoint(pen: Pen, radius: number, from: Vector3?, skip: string?, strict: boolean): Vector3?
	local roam = Park.Roam
	local enclosure = pen.Plot.Enclosure
	local size = enclosure.Size
	local hx = math.max(0, size.X / 2 - radius - roam.Margin)
	local hz = math.max(0, size.Z / 2 - radius - roam.Margin)
	local best: Vector3? = nil
	local bestClearance = -math.huge
	for _ = 1, roam.Tries do
		local point = enclosure.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-hx, hx), size.Y / 2, rng:NextNumber(-hz, hz)))
		if from then
			local leg = (flat(point) - flat(from)).Magnitude
			if leg < roam.MinLeg or leg > roam.MaxLeg then
				continue
			end
		end
		local room = clearance(pen, point, radius, skip)
		if room >= roam.Gap then
			return point
		elseif room > bestClearance then
			best, bestClearance = point, room
		end
	end
	return if strict then nil else best
end

local function restTime(): number
	return rng:NextNumber(Park.Roam.RestMin, Park.Roam.RestMax)
end

local function setState(model: Model, state: string)
	model:SetAttribute("State", state)
	model:SetAttribute("StateAt", Workspace:GetServerTimeNow())
end

-- État de la pause : Idle, parfois une humeur (Config.Park.Roam.Moods)
local function restState(): string
	local roll = rng:NextNumber()
	for mood, chance in Park.Roam.Moods do
		if roll < chance then
			return mood
		end
		roll -= chance
	end
	return "Idle"
end

-- Un passage de la promenade : fin des trajets et des pauses, nouveaux trajets
local function roamStep(now: number)
	for _, pen in pens do
		for id, w in pen.Walkers do
			if now < w.Until then
				continue
			end
			local model = w.Model
			if not model.Parent then
				continue
			end
			if w.Walking then
				-- arrivé : la pièce Root le rejoint (les clients l'y montrent déjà), puis une pause
				w.Walking = false
				model:PivotTo(w.Pose)
				model:SetAttribute("Speed", 0)
				setState(model, restState())
				w.Until = now + restTime()
				continue
			end
			local goal = if rng:NextNumber() < Park.Roam.WalkChance then pickPoint(pen, w.Radius, w.Pose.Position, id, true) else nil
			if not goal then
				w.Until = now + restTime()
				continue
			end
			local from = w.Pose
			local duration = Roam.Duration(from, goal, w.Speed)
			w.Walking = true
			w.Pose = Roam.PoseAt(from, goal, w.Speed, duration)
			w.Until = now + duration
			model:SetAttribute("WalkFrom", from)
			model:SetAttribute("WalkTo", goal)
			model:SetAttribute("Speed", w.Speed)
			setState(model, "Walk")
		end
	end
end

local function spawnModel(player: Player, pen: Pen, id: string, dino: Dino, state: string)
	local sizeInfo = SIZE_INFO[dino.Size]
	local scale = if sizeInfo then sizeInfo.Scale else 1
	local moduleName = EnclosureService.ModelName(dino.Species)
	local roams = Park.Roam.Enabled and hasDinoModel(dino.Species, moduleName)
	local radius = baseSize(dino.Species) * scale * Park.Roam.Footprint
	-- (une place libre au hasard dans l'enclos, tournée au hasard ; les dinos provisoires sur la grille)
	local point = if roams then pickPoint(pen, radius, nil, id, false) else nil
	local base: CFrame
	if point then
		base = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	else
		local spot = freeSpot(pen)
		pen.Spots[id] = spot
		base = spotCFrame(pen.Plot.Enclosure, spot)
	end
	local model = Instance.new("Model")
	model.Name = dino.Species
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = base
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Species", moduleName)
	model:SetAttribute("Scale", scale)
	if dino.Mutation ~= "" then
		model:SetAttribute("Mutation", dino.Mutation)
	end
	local level = Economy.Levels[dino.Level + 1]
	model:SetAttribute("Level", if level then level.Name else "Normal")
	model:SetAttribute("State", state)
	model:SetAttribute("StateAt", Workspace:GetServerTimeNow())
	model:SetAttribute("DinoId", id)
	model:SetAttribute("OwnerUserId", player.UserId)
	local look = looks[dino.Species]
	if look and look.Rarity then
		model:SetAttribute("Rarity", look.Rarity)
	end
	local height = baseSize(dino.Species) * scale
	if not hasDinoModel(dino.Species, moduleName) then
		buildPlaceholder(model, dino, base, scale)
		height *= 0.9
	end
	nameLabel(root, dino, height)
	model:AddTag("Dino")
	-- (StreamingEnabled : le modèle arrive chez le client d'un seul bloc, avec sa pièce Root)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = pen.Folder
	pen.Models[id] = model
	if roams then
		local walk = Roam.WalkSpeed(moduleName)
		local roam = Park.Roam
		pen.Walkers[id] = {
			Model = model,
			Radius = radius,
			Speed = if walk then math.clamp(walk * scale, roam.MinSpeed, roam.MaxSpeed) else roam.DefaultSpeed,
			Pose = base,
			Walking = false,
			-- (après Spawn ou Fusion, il reste un moment là où il est apparu)
			Until = os.clock() + restTime() + (if state ~= "Idle" then roam.SpawnRest else 0),
		}
	end
end

local function removeModel(pen: Pen, id: string)
	local model = pen.Models[id]
	pen.Models[id] = nil
	pen.Spots[id] = nil
	pen.Walkers[id] = nil
	if model then
		model:Destroy()
	end
end

local function updatePrompt(player: Player)
	local pen = pens[player]
	local data = DataService.Get(player)
	local prompt = pen and pen.Prompt
	if not (prompt and data) then
		return
	end
	local price = Economy.NextEnclosurePrice(data.EnclosureUpgrades)
	prompt.ObjectText = string.format("Enclosure %d/%d", EnclosureService.Count(player), Economy.EnclosureSlots(data.EnclosureUpgrades))
	prompt.ActionText = if price then "Expand (" .. Format.Money(price) .. ")" else "Max size"
	prompt.Enabled = price ~= nil
end

-- ===================================================================== API

-- Ajoute un dino dans l'enclos (s'il y a de la place). state : état d'animation de départ ("Spawn" à la révélation).
-- Renvoie son identifiant, ou nil si l'enclos est plein ou le dino invalide.
function EnclosureService.AddDino(player: Player, dino: { [string]: any }, state: string?): string?
	local data = DataService.Get(player)
	if not data or type(dino) ~= "table" or type(dino.Species) ~= "string" or #dino.Species > 50 then
		return nil
	end
	if not EnclosureService.HasRoom(player) then
		return nil
	end
	local clean: Dino = {
		Species = dino.Species,
		Size = if SIZE_INFO[dino.Size] then dino.Size else "Normal",
		Mutation = if MUTATIONS[dino.Mutation] then dino.Mutation else "",
		Level = Guard.IntegerOr(dino.Level, 0, 0, #Economy.Levels - 1),
		Got = os.time(),
	}
	local id = tostring(data.NextDinoId)
	data.NextDinoId += 1
	data.Dinos[id] = clean
	local pen = pens[player]
	if pen then
		spawnModel(player, pen, id, clean, state or "Idle")
	end
	publish(player)
	updatePrompt(player)
	Signals.Fire("DinoAdded", player, id, clean)
	return id
end

-- Retire un dino (fusion du brief 8) ; renvoie ses données, ou nil s'il n'existe pas
function EnclosureService.RemoveDino(player: Player, id: string): Dino?
	local data = DataService.Get(player)
	if not data or type(id) ~= "string" then
		return nil
	end
	local dino = data.Dinos[id]
	if not dino then
		return nil
	end
	data.Dinos[id] = nil
	local pen = pens[player]
	if pen then
		removeModel(pen, id)
	end
	publish(player)
	updatePrompt(player)
	Signals.Fire("DinoRemoved", player, id, dino)
	return dino
end

-- Change la mutation d'un dino de l'enclos (sérum de mutation, MutatorService) : le modèle est refait avec ses
-- nouvelles couleurs et son étiquette, dans l'état d'animation `state`. Renvoie le dino, ou nil (id ou mutation inconnus).
function EnclosureService.SetMutation(player: Player, id: string, mutation: string, state: string?): Dino?
	local data = DataService.Get(player)
	local dino = data and type(id) == "string" and data.Dinos[id]
	if not dino or not MUTATIONS[mutation] then
		return nil
	end
	dino.Mutation = mutation
	local pen = pens[player]
	if pen then
		removeModel(pen, id)
		spawnModel(player, pen, id, dino, state or "Idle")
	end
	publish(player)
	Signals.Fire("DinoMutated", player, id, dino)
	return dino
end

-- Achète un agrandissement d'enclos. Renvoie (ok, texte).
function EnclosureService.BuyUpgrade(player: Player): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Please wait..."
	end
	local price = Economy.NextEnclosurePrice(data.EnclosureUpgrades)
	if not price then
		return false, "Your enclosure is at max size!"
	end
	if not MoneyService.Spend(player, price, "Enclosure") then
		return false, "Not enough money!"
	end
	data.EnclosureUpgrades += 1
	publish(player)
	updatePrompt(player)
	return true, string.format("Enclosure expanded to %d slots!", Economy.EnclosureSlots(data.EnclosureUpgrades))
end

-- Espèce connue d'après un texte d'admin (« trex », « Golden_Raptor »...)
local function findSpecies(text: string): string?
	local wanted = string.lower((string.gsub(text, "[^%w]", "")))
	for name in Rarity.Species do
		if string.lower((string.gsub(name, "[^%w]", ""))) == wanted then
			return name
		end
	end
	return nil
end

function EnclosureService.Init()
	Net.Function("BuyEnclosure", { Rate = 2, Burst = 4 }, function(player: Player)
		return EnclosureService.BuyUpgrade(player)
	end)
	AdminService.RegisterCommand("givedino", {
		Description = "Put a dino in the enclosure",
		Usage = "givedino <species> [Small|Normal|Big|Huge] [mutation|none] [player]",
		Run = function(caller: Player, args: { string })
			local species = findSpecies(args[1] or "")
			local target = AdminService.FindPlayer(caller, args[4])
			if not (species and target) then
				return false, "Usage: givedino <species> [size] [mutation] [player]"
			end
			local mutation = Economy.FindMutation(args[3]) or args[3] -- (Config.Economy.Mutations, sans les majuscules)
			local id = EnclosureService.AddDino(target, { Species = species, Size = args[2], Mutation = mutation }, "Spawn")
			if not id then
				return false, "Enclosure full"
			end
			return true, species .. " added (id " .. id .. ")"
		end,
	})
end

function EnclosureService.Start()
	while true do
		task.wait(Park.Roam.TickRate)
		if Park.Roam.Enabled then
			roamStep(os.clock())
		end
	end
end

function EnclosureService.OnPlayerReady(player: Player, data: { [string]: any })
	local plot = PlotService.Get(player)
	if plot then
		local folder = Instance.new("Folder")
		folder.Name = "Dinos"
		folder.Parent = plot.Model
		local pen: Pen = { Plot = plot, Folder = folder, Models = {}, Spots = {}, Walkers = {}, Prompt = nil }
		pens[player] = pen
		-- (ordre stable : identifiants croissants)
		local ids = {}
		for id in data.Dinos do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end)
		for _, id in ids do
			spawnModel(player, pen, id, data.Dinos[id], "Idle")
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ExpandPrompt"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OwnerUserId", player.UserId)
		prompt.Triggered:Connect(function(who: Player)
			if who ~= player then
				Notify.Send(who, "This is not your park!", "error")
				return
			end
			if not RateLimit.Allow(player, "ExpandPrompt", 2, 3) then
				return
			end
			local ok, text = EnclosureService.BuyUpgrade(player)
			Notify.Send(player, text, if ok then "success" else "error")
		end)
		prompt.Parent = plot.Enclosure
		pen.Prompt = prompt
	end
	publish(player)
	updatePrompt(player)
end

function EnclosureService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	local pen = pens[player]
	pens[player] = nil
	if pen then
		pen.Folder:Destroy()
		if pen.Prompt then
			pen.Prompt:Destroy()
		end
	end
end

return EnclosureService
