--!strict
-- Données du joueur, domaine Daily : récompense quotidienne (cycle de 14 jours).
-- Fichier posé par le brief 1 « fondations » ; appartient au brief 13 « quotidien-quetes ».
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

return {
	Version = 1,
	Defaults = {
		Daily = {
			Day = 0, -- jours déjà récupérés dans le cycle de 14 (0 = jamais)
			LastClaim = 0, -- os.time() de la dernière récompense prise
		},
	},

	Sanitize = function(data: Data)
		data.Daily.Day = Guard.IntegerOr(data.Daily.Day, 0, 0, 14)
		data.Daily.LastClaim = Guard.IntegerOr(data.Daily.LastClaim, 0, 0)
	end,
}
