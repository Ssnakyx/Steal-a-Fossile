--!strict
-- Map (brief 10 « map ») : construit Workspace.Map au démarrage (src/server/Map/MapBuilder.luau), avant PlotService et
-- ZoneService qui en lisent les points d'ancrage (docs/BOUCLE.md, docs/MAP.md). Une map déjà présente dans la place
-- (enregistrée dans Studio, ou faite à la main par un test) est gardée telle quelle.
-- Recopie aussi le texte de l'enseigne de chaque parc (« <Nom>'s Park », écrit par PlotService) sur sa face intérieure.

local Workspace = game:GetService("Workspace")

local MapBuilder = require(script.Parent.Parent.Map.MapBuilder)

local MapService = {}
MapService.Priority = -30 -- avant PlotService et ZoneService (-20)

MapService.Built = false -- la map a-t-elle été construite par ce serveur ?
MapService.Stats = nil :: MapBuilder.Stats?

-- Enseigne d'un parc : le texte de la face extérieure (Label) est recopié sur la face intérieure (LabelInside)
local function mirrorSign(plot: Instance)
	local sign = plot:FindFirstChild("Sign", true)
	local outside = sign and sign:FindFirstChild("Label")
	local inside = sign and sign:FindFirstChild("LabelInside")
	local from = outside and outside:FindFirstChild("Text")
	local to = inside and inside:FindFirstChild("Text")
	if from and to and from:IsA("TextLabel") and to:IsA("TextLabel") then
		local source, target = from, to
		target.Text = source.Text
		source:GetPropertyChangedSignal("Text"):Connect(function()
			target.Text = source.Text
		end)
	end
end

function MapService.Init()
	if not Workspace:FindFirstChild("Map") then
		local _, stats = MapBuilder.Build(Workspace)
		MapService.Built = true
		MapService.Stats = stats
		MapBuilder.Lighting()
	end
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			mirrorSign(plot)
		end
	end
end

return MapService
