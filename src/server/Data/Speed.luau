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
			Owned = {}, -- { [trail] = true } trails achetées avec l'argent du jeu (les trails Robux sont des passes)
			Equipped = "", -- trail portée ("" = aucune), trail en argent ou trail Robux (Config.Speed.RobuxTrails)
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
		-- (une trail Robux portée est gardée : son passe est vérifié à l'arrivée par ShopService, TrailService ne la
		-- montre que si le joueur l'a)
		local equipped = data.Trails.Equipped
		if type(equipped) ~= "string" or (equipped ~= "" and not owned[equipped] and not SpeedConfig.RobuxTrails[equipped]) then
			data.Trails.Equipped = ""
		end
		data.Passes = Guard.StringSet(data.Passes, 50)
	end,
}
