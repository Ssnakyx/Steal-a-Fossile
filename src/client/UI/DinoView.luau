--!strict
-- Portrait d'un dino dans un ViewportFrame (Index, écran de révélation, labo de fusion), brief 12.
--   local view = DinoView.new({ Size = UDim2.fromOffset(200, 160), Parent = card })
--   DinoView.Show(view, "T-Rex", { Size = "Big", Mutation = "Amber" })   -- nom d'espèce, module ou clé de chimère
--   DinoView.Show(view, "T-Rex", nil, true)                              -- silhouette noire (pas encore découvert)
--   DinoView.Spin(view, dt)                                              -- tourne la caméra autour (révélation)
-- Le modèle est construit avec DinoBuilder (mêmes briques qu'en jeu, au repos, sans effets de rareté). Une espèce sans
-- modèle laisse la vue vide (Show renvoie false). Un portrait coûte autant de pièces que le dino : n'en garder que
-- quelques-uns à la fois (une page de l'Index), et Clear quand le menu se ferme.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DinoBuilder = require(ReplicatedStorage.Shared.DinoBuilder)
local HybridBuilder = require(ReplicatedStorage.Shared.HybridBuilder)

local DinoView = {}

local FOV = 30
local DIRECTION = Vector3.new(-0.8, 0.38, -1).Unit -- caméra devant à gauche (le dino regarde vers -Z)
local FIT = 0.9 -- < 1 : un peu plus près que la sphère qui contient tout le dino

type Framing = { Center: Vector3, Distance: number, Angle: number }
local framings: { [ViewportFrame]: Framing } = setmetatable({}, { __mode = "k" }) :: any

-- Nom du module DinoModels d'une espèce (nom affiché, module ou clé de chimère) ; nil sans modèle
function DinoView.ModuleOf(species: string): string?
	if type(species) ~= "string" or species == "" then
		return nil
	end
	local def = Config.Species.ByName[species]
	local module = if def then def.Model else species
	if HybridBuilder.IsHybrid(module) then
		HybridBuilder.Ensure(module)
	end
	return if DinoBuilder.Get(module) then module else nil
end

function DinoView.new(props: { [string]: any }): ViewportFrame
	local parent = props.Parent
	props.Parent = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	local view = Instance.new("ViewportFrame")
	for key, value in props do
		(view :: any)[key] = value
	end
	view.Ambient = Color3.fromRGB(150, 150, 160)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-0.6, -1, -0.4)
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = view
	view.CurrentCamera = camera
	view.Parent = parent
	return view
end

function DinoView.Clear(view: ViewportFrame)
	for _, child in view:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	framings[view] = nil
end

local function place(view: ViewportFrame, framing: Framing)
	local camera = view.CurrentCamera
	if not camera then
		return
	end
	local direction = CFrame.Angles(0, framing.Angle, 0):VectorToWorldSpace(DIRECTION)
	camera.CFrame = CFrame.lookAt(framing.Center + direction * framing.Distance, framing.Center)
end

-- Montre une espèce (silhouette = noir, pour l'Index). Renvoie false si l'espèce n'a pas de modèle.
-- zoom (< 1 : plus près, pour une petite vue où le dino doit remplir la case) ; 1 par défaut.
function DinoView.Show(view: ViewportFrame, species: string, options: DinoBuilder.BuildOptions?, silhouette: boolean?, zoom: number?): boolean
	DinoView.Clear(view)
	local module = DinoView.ModuleOf(species)
	if not module then
		return false
	end
	local ok, model = pcall(DinoBuilder.Build, module, options)
	if not ok or typeof(model) ~= "Instance" then
		return false
	end
	local box, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude / 2, 0.5)
	local framing = {
		Center = box.Position,
		Distance = radius / math.sin(math.rad(FOV / 2)) * FIT * (zoom or 1),
		Angle = 0,
	}
	framings[view] = framing
	view.ImageColor3 = if silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
	view.ImageTransparency = if silhouette then 0.15 else 0
	model.Parent = view
	place(view, framing)
	return true
end

-- Tourne la caméra autour du dino (radians par seconde x dt)
function DinoView.Spin(view: ViewportFrame, dt: number, speed: number?)
	local framing = framings[view]
	if framing and dt == dt then
		framing.Angle = (framing.Angle + dt * (speed or 0.6)) % (2 * math.pi)
		place(view, framing)
	end
end

return DinoView
