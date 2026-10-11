--!strict
-- Parcs des joueurs (brief 3 « boucle ») : 8 parcs alignés au spawn face à la route, un par joueur, attribué à
-- l'arrivée et rendu au départ. Le parc est une zone sûre : rien n'y est jamais volable (IsSafe, PlotAt).
-- Géométrie : Workspace.Map.Plots.Plot1 à Plot8, points d'ancrage nommés (docs/BOUCLE.md). S'ils manquent au
-- démarrage, une géométrie provisoire est construite ici (la vraie map est faite par le brief 10, avec les mêmes noms).
-- Attributs : joueur « Plot » (1 à 8, 0 sans parc) ; Model du parc « Index » et « OwnerUserId » (0 = libre).
-- Clé replica « Plot ». Le personnage apparaît sur le point « Spawn » de son parc.
-- Signaux : PlotAssigned(player, index), PlotReleased(player, index)

local Workspace = game:GetService("Workspace")

local Signals = require(script.Parent.Parent.Lib.Signals)
local Notify = require(script.Parent.Parent.Lib.Notify)
local ReplicaService = require(script.Parent.ReplicaService)

export type Plot = {
	Index: number,
	Model: Model,
	Floor: BasePart, -- zone sûre : la boîte de cette pièce, prolongée vers le haut
	Spawn: BasePart,
	Entrance: BasePart?,
	Sign: BasePart?,
	Tanks: { BasePart }, -- Tank1 à Tank6 (cuves de réanimation)
	Enclosure: BasePart, -- surface de l'enclos (les dinos sont posés dessus)
	Treadmill: BasePart?, -- point d'ancrage du brief 4 (tagué « Treadmill »)
	Lab: BasePart?, -- point d'ancrage du labo de fusion (brief 8)
	Owner: Player?,
}

local PlotService = {}
PlotService.Priority = -20 -- avant les autres services de la boucle (ils posent leurs objets dans les parcs)

PlotService.Count = 8
PlotService.GroundTop = 1 -- hauteur du sol provisoire (au-dessus d'une Baseplate éventuelle)

local SAFE_BELOW = 4 -- studs sous le sol encore comptés dans le parc
local SAFE_ABOVE = 60 -- studs au-dessus du sol (sauts)

local plots: { Plot } = {} -- parcs valides, par numéro croissant
local byIndex: { [number]: Plot } = {}
local byPlayer: { [Player]: Plot } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

-- ===================================================================== géométrie provisoire

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decor(part: Part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Étiquette au-dessus d'une pièce (enseigne du parc)
local function label(part: BasePart, text: string, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(16, 3)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = part
	return textLabel
end

local function buildPlot(index: number, parent: Instance): Model
	local gt = PlotService.GroundTop
	local cx = (index - (PlotService.Count + 1) / 2) * 70
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local wood = Color3.fromRGB(150, 105, 65)
	local floor = newPart("Floor", Vector3.new(60, 1, 70), CFrame.new(cx, gt - 0.5, -37), Color3.fromRGB(110, 170, 85), model)
	model.PrimaryPart = floor
	local entrance = newPart("Entrance", Vector3.new(16, 0.1, 2), CFrame.new(cx, gt + 0.05, -3), Color3.fromRGB(240, 220, 120), model)
	decor(entrance)
	local spawn = newPart("Spawn", Vector3.new(6, 0.2, 6), CFrame.new(cx, gt + 0.1, -12) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(245, 245, 245), model)
	decor(spawn)
	newPart("WallLeft", Vector3.new(1, 3, 70), CFrame.new(cx - 30.5, gt + 1.5, -37), wood, model)
	newPart("WallRight", Vector3.new(1, 3, 70), CFrame.new(cx + 30.5, gt + 1.5, -37), wood, model)
	newPart("WallBack", Vector3.new(62, 3, 1), CFrame.new(cx, gt + 1.5, -72.5), wood, model)
	newPart("WallFrontLeft", Vector3.new(22, 3, 1), CFrame.new(cx - 19.5, gt + 1.5, -1.5), wood, model)
	newPart("WallFrontRight", Vector3.new(22, 3, 1), CFrame.new(cx + 19.5, gt + 1.5, -1.5), wood, model)
	local sign = newPart("Sign", Vector3.new(14, 5, 1), CFrame.new(cx - 19.5, gt + 5.5, -1.5), wood, model)
	label(sign, "Empty park", 4.5)
	for k = 1, 6 do
		local tank = newPart("Tank" .. k, Vector3.new(6, 7, 6), CFrame.new(cx - 25 + (k - 1) * 10, gt + 3.5, -64), Color3.fromRGB(170, 220, 235), model)
		tank.Material = Enum.Material.Glass
		tank.Transparency = 0.6
		tank.TopSurface = Enum.SurfaceType.Smooth
	end
	local enclosure = newPart("Enclosure", Vector3.new(56, 0.1, 24), CFrame.new(cx, gt + 0.06, -40), Color3.fromRGB(140, 190, 95), model)
	decor(enclosure)
	local treadmill = newPart("Treadmill", Vector3.new(6, 1, 12), CFrame.new(cx + 22, gt + 0.5, -18), Color3.fromRGB(60, 60, 65), model)
	treadmill:AddTag("Treadmill")
	newPart("Lab", Vector3.new(8, 6, 8), CFrame.new(cx - 22, gt + 3, -18), Color3.fromRGB(200, 200, 215), model)
	model.Parent = parent
	return model
end

local function buildGround(parent: Instance)
	local gt = PlotService.GroundTop
	local ground = newPart("SpawnGround", Vector3.new(600, 2, 140), CFrame.new(0, gt - 1.05, -10), Color3.fromRGB(120, 175, 90), parent)
	ground.TopSurface = Enum.SurfaceType.Studs
end

-- Dossier (ou modèle) `name` de `parent`, créé s'il n'existe pas ; renvoie aussi s'il vient d'être créé
local function findOrCreate(parent: Instance, name: string): (Instance, boolean)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing, false
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder, true
end

-- Dossier Workspace.Map (créé s'il n'existe pas) : partagé avec ZoneService
function PlotService.MapFolder(): Instance
	local folder = findOrCreate(Workspace, "Map")
	return folder
end

-- ===================================================================== lecture des points d'ancrage

local function anchor(model: Instance, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function readPlot(index: number, model: Model): Plot?
	local floor = anchor(model, "Floor")
	local spawn = anchor(model, "Spawn")
	local enclosure = anchor(model, "Enclosure")
	if not (floor and spawn and enclosure) then
		warn(string.format("[PlotService] %s : il manque Floor, Spawn ou Enclosure (parc ignoré)", model:GetFullName()))
		return nil
	end
	local tanks = {}
	for k = 1, 6 do
		local tank = anchor(model, "Tank" .. k)
		if not tank then
			break
		end
		table.insert(tanks, tank)
	end
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)
	return {
		Index = index,
		Model = model,
		Floor = floor,
		Spawn = spawn,
		Entrance = anchor(model, "Entrance"),
		Sign = anchor(model, "Sign"),
		Tanks = tanks,
		Enclosure = enclosure,
		Treadmill = anchor(model, "Treadmill"),
		Lab = anchor(model, "Lab"),
		Owner = nil,
	}
end

local function setSign(plot: Plot, text: string)
	local sign = plot.Sign
	local gui = sign and sign:FindFirstChild("Label")
	local textLabel = gui and gui:FindFirstChild("Text")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

-- ===================================================================== API

-- Parc d'un joueur (nil s'il n'en a pas)
function PlotService.Get(player: Player): Plot?
	return byPlayer[player]
end

-- Parc numéro `index` (1 à 8)
function PlotService.ByIndex(index: number): Plot?
	return byIndex[index]
end

function PlotService.List(): { Plot }
	return table.clone(plots)
end

-- La position est-elle dans ce parc (boîte du sol prolongée vers le haut) ?
function PlotService.Contains(plot: Plot, position: Vector3): boolean
	local floor = plot.Floor
	local relative = floor.CFrame:PointToObjectSpace(position)
	local half = floor.Size / 2
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Z) <= half.Z
		and relative.Y >= -half.Y - SAFE_BELOW
		and relative.Y <= half.Y + SAFE_ABOVE
end

-- Numéro du parc qui contient cette position (nil sur la route)
function PlotService.PlotAt(position: Vector3): number?
	for _, plot in plots do
		if PlotService.Contains(plot, position) then
			return plot.Index
		end
	end
	return nil
end

-- Zone sûre : la position est dans un parc (n'importe lequel). Rien n'y est volable, personne n'y est bonké.
function PlotService.IsSafe(position: Vector3): boolean
	return PlotService.PlotAt(position) ~= nil
end

-- Le personnage du joueur est-il dans un parc ?
function PlotService.IsPlayerSafe(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and PlotService.IsSafe(root.Position)
end

-- Le personnage du joueur est-il dans son propre parc ?
function PlotService.IsInOwnPlot(player: Player): boolean
	local plot = byPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return plot ~= nil and root ~= nil and root:IsA("BasePart") and PlotService.Contains(plot, root.Position)
end

-- Repère d'apparition dans le parc (au-dessus du point Spawn, tourné vers la route)
function PlotService.SpawnCFrame(plot: Plot): CFrame
	local spawn = plot.Spawn
	return spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + 3, 0)
end

-- Ramène le personnage du joueur dans son parc
function PlotService.Teleport(player: Player): boolean
	local plot = byPlayer[player]
	local character = player.Character
	if not (plot and character) then
		return false
	end
	character:PivotTo(PlotService.SpawnCFrame(plot))
	return true
end

-- ===================================================================== attribution

local function assign(player: Player): Plot?
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			byPlayer[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, player.DisplayName .. "'s Park")
			player:SetAttribute("Plot", plot.Index)
			ReplicaService.Set(player, "Plot", plot.Index)
			return plot
		end
	end
	return nil
end

local function release(player: Player)
	local plot = byPlayer[player]
	byPlayer[player] = nil
	if plot and plot.Owner == player then
		plot.Owner = nil
		plot.Model:SetAttribute("OwnerUserId", 0)
		setSign(plot, "Empty park")
		Signals.Fire("PlotReleased", player, plot.Index)
	end
end

function PlotService.Init()
	local map = PlotService.MapFolder()
	local folder, created = findOrCreate(map, "Plots")
	if created then
		if not map:FindFirstChild("SpawnGround") then
			buildGround(map)
		end
		for index = 1, PlotService.Count do
			buildPlot(index, folder)
		end
	end
	for index = 1, PlotService.Count do
		local model = folder:FindFirstChild("Plot" .. index)
		if model and model:IsA("Model") then
			local plot = readPlot(index, model)
			if plot then
				table.insert(plots, plot)
				byIndex[index] = plot
			end
		else
			warn("[PlotService] Workspace.Map.Plots.Plot" .. index .. " manque")
		end
	end
end

function PlotService.OnPlayerReady(player: Player, _data: { [string]: any })
	local plot = assign(player)
	if not plot then
		player:SetAttribute("Plot", 0)
		ReplicaService.Set(player, "Plot", 0)
		Notify.Send(player, "All parks are taken!", "error")
		return
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		-- (après le placement de Roblox sur le SpawnLocation)
		task.defer(function()
			if byPlayer[player] == plot and character.Parent ~= nil then
				character:PivotTo(PlotService.SpawnCFrame(plot))
			end
		end)
	end)
	if player.Character then
		PlotService.Teleport(player)
	end
	Signals.Fire("PlotAssigned", player, plot.Index)
end

function PlotService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	local connection = characterConnections[player]
	characterConnections[player] = nil
	if connection then
		connection:Disconnect()
	end
	release(player)
end

return PlotService
