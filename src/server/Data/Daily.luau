--!strict
-- Données du joueur, domaine Daily : calendrier de 14 jours, roue de la chance, cadeaux de temps de jeu
-- (Config/Daily.luau ; DailyService, SpinService, GiftService).
-- Fichier posé par le brief 1 « fondations » ; complété par le thread « Récompenses, AFK et rétention » (2026-10-11).
-- Format d'un domaine : voir src/server/Services/DataService.luau.
-- (Version 1 complétée avant toute publication : aucune sauvegarde de l'ancien format n'existe ; les champs ajoutés
-- prennent de toute façon leur valeur de départ s'ils manquent.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

local DAYS = #DailyConfig.Login.Days

return {
	Version = 1,
	Defaults = {
		Daily = {
			Day = 0, -- jours déjà récupérés dans le cycle de 14 (0 = jamais, ou série perdue)
			LastClaim = 0, -- os.time() de la dernière récompense prise
			Streak = 0, -- jours d'affilée récupérés (continue après le jour 14)
			Best = 0, -- plus longue série
		},
		Spins = {
			Stored = 0, -- tours en réserve (gagnés ou achetés)
			FreeDay = 0, -- jour (Config.Daily.Day) des tours gratuits déjà utilisés
			FreeUsed = 0, -- tours gratuits utilisés ce jour-là
			Total = 0, -- tours joués depuis toujours
		},
		Gifts = {
			Day = 0, -- jour (Config.Daily.Day) du temps de jeu compté
			Seconds = 0, -- temps de jeu de ce jour-là
			Claimed = {}, -- { ["1"] = true } cadeaux déjà ouverts ce jour-là (numéro dans Config.Daily.Gifts)
		},
	},

	Sanitize = function(data: Data)
		data.Daily.Day = Guard.IntegerOr(data.Daily.Day, 0, 0, DAYS)
		data.Daily.LastClaim = Guard.IntegerOr(data.Daily.LastClaim, 0, 0)
		data.Daily.Streak = Guard.IntegerOr(data.Daily.Streak, 0, 0)
		data.Daily.Best = math.max(Guard.IntegerOr(data.Daily.Best, 0, 0), data.Daily.Streak)
		data.Spins.Stored = Guard.IntegerOr(data.Spins.Stored, 0, 0, DailyConfig.Spins.MaxStored)
		data.Spins.FreeDay = Guard.IntegerOr(data.Spins.FreeDay, 0, 0)
		data.Spins.FreeUsed = Guard.IntegerOr(data.Spins.FreeUsed, 0, 0)
		data.Spins.Total = Guard.IntegerOr(data.Spins.Total, 0, 0)
		data.Gifts.Day = Guard.IntegerOr(data.Gifts.Day, 0, 0)
		data.Gifts.Seconds = Guard.NumberOr(data.Gifts.Seconds, 0, 0, DailyConfig.DayLength)
		local claimed = {}
		for key in Guard.StringSet(data.Gifts.Claimed) do
			local index = tonumber(key)
			if index and DailyConfig.Gifts[index] then
				claimed[tostring(index)] = true
			end
		end
		data.Gifts.Claimed = claimed
	end,
}
