--!strict
-- Données du joueur, domaine Speed : vitesse, niveau de treadmill acheté, trails.
-- Fichier posé par le brief 1 « fondations » ; appartient au brief 4 « vitesse-treadmill ».
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

local MAX_TREADMILL = 10 -- (GDD : achat puis niveaux jusqu'à 10)

return {
	Version = 1,
	Defaults = {
		Speed = 0, -- vitesse gagnée (treadmill, trails, quêtes) ; la courbe vers WalkSpeed est dans la config du brief 4
		TreadmillLevel = 0, -- 0 = treadmill pas acheté, 1 à 10 = dernier niveau acheté (un produit développeur par niveau)
		Trails = {
			Owned = {}, -- { [trail] = true }
			Equipped = "", -- trail portée ("" = aucune)
		},
	},

	Sanitize = function(data: Data)
		data.Speed = Guard.NumberOr(data.Speed, 0, 0)
		data.TreadmillLevel = Guard.IntegerOr(data.TreadmillLevel, 0, 0, MAX_TREADMILL)
		data.Trails.Owned = Guard.StringSet(data.Trails.Owned)
		if data.Trails.Equipped ~= "" and not data.Trails.Owned[data.Trails.Equipped] then
			data.Trails.Equipped = ""
		end
	end,
}
