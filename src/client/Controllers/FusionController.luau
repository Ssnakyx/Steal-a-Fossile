--!strict
-- Côté client de la fusion (brief 8) :
--   * chimères : chaque dino tagué « Dino » dont l'attribut Species est une clé HybridBuilder (« Pteranodon+TRex ») est
--     assemblé et enregistré dans DinoBuilder avant que DinoAnimController construise ses briques et l'anime.
--   * API pour le menu du labo et l'Index (brief 12), le client ne décide rien :
--       FusionController.Preview({ "3", "7" })   -> (ok, infos ou texte)   aperçu (« ??? » si pas encore découvert)
--       FusionController.Fuse({ "3", "7" })      -> (ok, texte, infos?)
--       FusionController.LabOpened:Connect(fn)   le joueur a utilisé le labo de son parc (ouvrir le menu ; mettre
--                                                FusionController.MenuReady = true pour enlever l'aide provisoire)
--       FusionController.Done:Connect(fn)        fusion réussie (infos : carte de révélation, effets du brief 11)
--       FusionController.Ensure(clé)             données d'une chimère pour un ViewportFrame (DinoBuilder.Build(clé))
--     État de l'Index des hybrides : clé replica « Hybrids » ({ Total, Found, List = { { Id, Hint, Found, Name?, Key?,
--     Head?, Body?, Rarity?, Income? } } }).
-- Tant que le menu du brief 12 n'existe pas, le labo affiche une aide et les admins fusionnent avec « fuse <id> <id> ».

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DinoBuilder = require(ReplicatedStorage.Shared.DinoBuilder)
local HybridBuilder = require(ReplicatedStorage.Shared.HybridBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NotifyController = require(script.Parent.NotifyController)

local FusionController = {}
FusionController.MenuReady = false

local labOpened = Instance.new("BindableEvent")
local done = Instance.new("BindableEvent")
FusionController.LabOpened = labOpened.Event
FusionController.Done = done.Event

-- Données d'une chimère (assemblée une fois) ; nil si ce n'est pas une clé de chimère ou si un parent n'a pas de modèle
function FusionController.Ensure(key: any): DinoBuilder.Data?
	if not HybridBuilder.IsHybrid(key) then
		return nil
	end
	return HybridBuilder.Ensure(key :: string)
end

local function onDino(instance: Instance)
	if instance:IsA("Model") then
		FusionController.Ensure(instance:GetAttribute("Species"))
	end
end

function FusionController.Preview(ids: { string }): (boolean, any)
	return Remotes.Function("PreviewFusion"):InvokeServer(ids)
end

function FusionController.Fuse(ids: { string }): (boolean, string, any)
	return Remotes.Function("FuseDinos"):InvokeServer(ids)
end

function FusionController.Init()
	-- (dans Init : avant que DinoAnimController branche le tag dans son Start ; enregistré tout de suite, sans attendre)
	CollectionService:GetInstanceAddedSignal(DinoBuilder.Tag):Connect(onDino)
	for _, instance in CollectionService:GetTagged(DinoBuilder.Tag) do
		onDino(instance)
	end
	Remotes.Event("OpenFusionLab").OnClientEvent:Connect(function()
		if not FusionController.MenuReady then
			NotifyController.Show("Fusion Lab: 2 different dinos make a hybrid, 3 identical dinos level up.", "info")
		end
		labOpened:Fire()
	end)
	Remotes.Event("FusionDone").OnClientEvent:Connect(function(info: any)
		if type(info) == "table" then
			FusionController.Ensure(info.Key)
			done:Fire(info)
		end
	end)
end

return FusionController
