--!strict
-- Données du joueur, domaine Speed (brief 4 « vitesse-treadmill ») : vitesse, niveau de treadmill acheté, trails,
-- récompense de groupe, passes. Fichier posé par le brief 1 « fondations ».
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

return {
	Version = 1,
	Defaults = {
		Speed = 0, -- vitesse gagnée pour de bon (treadmill, quêtes, récompenses) ; la trail portée s'y ajoute (SpeedService)
		TreadmillLevel = 0, -- 0 = treadmill pas acheté, 1 à 10 = dernier niveau acheté (un produit développeur par niveau)
		Trails = {
			Owned = {}, -- { [trail] = true }
			Equipped = "", -- trail portée ("" = aucune)
		},
		GroupRewardClaimed = false, -- récompense like + favori + groupe déjà prise
		-- Passes déjà vus en sa possession (ShopService) : Roblox reste la source (UserOwnsGamePassAsync à chaque
		-- arrivée), cette liste garde les avantages d'un passe acheté quand Roblox ne répond pas.
		Passes = {}, -- { [clé du passe] = true }
	},

	Sanitize = function(data: Data)
		data.Speed = Guard.NumberOr(data.Speed, 0, 0, SpeedConfig.Max)
		data.TreadmillLevel = Guard.IntegerOr(data.TreadmillLevel, 0, 0, #Shop.Treadmill.Levels)
		-- (une trail retirée de la config disparaît de la sauvegarde)
		local owned = {}
		for id in Guard.StringSet(data.Trails.Owned) do
			if SpeedConfig.Trails[id] then
				owned[id] = true
			end
		end
		data.Trails.Owned = owned
		if type(data.Trails.Equipped) ~= "string" or (data.Trails.Equipped ~= "" and not owned[data.Trails.Equipped]) then
			data.Trails.Equipped = ""
		end
		data.Passes = Guard.StringSet(data.Passes, 50)
	end,
}
