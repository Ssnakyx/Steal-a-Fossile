--!strict
-- Données du joueur, domaine Pvp (brief 7 « gardiens-vol ») : Bear Traps en réserve.
-- (La protection débutant lit data.PlayTime du domaine Core.)
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pvp = require(ReplicatedStorage.Shared.Config.Pvp)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

return {
	Version = 1,
	Defaults = {
		BearTraps = 0, -- pièges en réserve (achetés avec l'argent du jeu ou le produit Robux BearTraps5)
	},

	Sanitize = function(data: Data)
		data.BearTraps = Guard.IntegerOr(data.BearTraps, 0, 0, Pvp.Trap.MaxOwned)
	end,
}
