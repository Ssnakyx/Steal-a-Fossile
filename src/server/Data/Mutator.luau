--!strict
-- Données du joueur, domaine Mutator (thread « Objet de mutation », 2026-10-11) : sérums de mutation en réserve.
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mutator = require(ReplicatedStorage.Shared.Config.Mutator)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

return {
	Version = 1,
	Defaults = {
		Serums = 0, -- sérums de mutation en réserve (Config.Mutator)
		SerumsUsed = 0, -- sérums utilisés depuis toujours (statistiques)
	},

	Sanitize = function(data: Data)
		data.Serums = Guard.IntegerOr(data.Serums, 0, 0, Mutator.MaxOwned)
		data.SerumsUsed = Guard.IntegerOr(data.SerumsUsed, 0, 0)
	end,
}
