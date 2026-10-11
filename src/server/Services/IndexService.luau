--!strict
-- Index des espèces (brief 12 « ui-ux ») : envoie au client les espèces déjà découvertes, pour la page Dinos de l'Index
-- (silhouettes des espèces pas encore découvertes). Les hybrides ont leur propre clé replica (« Hybrids », FusionService).
-- Une espèce est découverte quand elle sort d'une cuve (ReviveService note data.Index.Species) ou quand le joueur en a
-- une dans son enclos (dino donné par un admin, fusion) : les deux sont notés ici aussi.
--   IndexService.Discover(player, espèce) -> nouvelle ?
--   IndexService.Publish(player)            renvoie la clé replica (après un changement fait à la main)
-- Replica : Index ({ Species = { [espèce] = true }, Found, Total }).
-- Les récompenses de pages d'Index (data.Index.Claimed) sont pour le brief 13.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local ReplicaService = require(script.Parent.ReplicaService)

local IndexService = {}

local ready: { [Player]: boolean } = {}

local function isSpecies(name: any): boolean
	return type(name) == "string" and Config.Species.ByName[name] ~= nil
end

function IndexService.Publish(player: Player)
	local data = DataService.Get(player)
	if not data or not ready[player] then
		return
	end
	local species: { [string]: boolean } = {}
	local found = 0
	for name in data.Index.Species do
		if isSpecies(name) then
			species[name] = true
			found += 1
		end
	end
	ReplicaService.Set(player, "Index", { Species = species, Found = found, Total = #Config.Species.List })
end

-- Note une espèce comme découverte ; renvoie true si elle ne l'était pas
function IndexService.Discover(player: Player, name: string): boolean
	local data = DataService.Get(player)
	if not data or not isSpecies(name) then
		return false
	end
	local fresh = data.Index.Species[name] ~= true
	data.Index.Species[name] = true
	IndexService.Publish(player)
	return fresh
end

function IndexService.Init()
	Signals.Connect("DinoRevived", function(player: Player, _id: string, dino: any)
		if type(dino) == "table" then
			IndexService.Discover(player, dino.Species)
		end
	end)
	Signals.Connect("DinoAdded", function(player: Player, _id: string, dino: any)
		if type(dino) == "table" then
			IndexService.Discover(player, dino.Species)
		end
	end)
end

function IndexService.OnPlayerReady(player: Player, data: { [string]: any })
	ready[player] = true
	-- (un dino de l'enclos est forcément découvert, même donné par un admin avant l'Index)
	for _, dino in data.Dinos do
		if type(dino) == "table" and isSpecies(dino.Species) then
			data.Index.Species[dino.Species] = true
		end
	end
	IndexService.Publish(player)
end

function IndexService.OnPlayerRemoving(player: Player)
	ready[player] = nil
end

return IndexService
