--!strict
-- Données du joueur, domaine Offers (shop Robux complet, 2026-10-11) : passes reçus en cadeau ou dans un pack, packs
-- achetés, cadeaux payés pas encore envoyés (OfferService, Config.Shop).
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

local MAX_CREDITS = 50

return {
	Version = 1,
	Defaults = {
		Offers = {
			-- Passes donnés par un cadeau ou un pack : { [clé du passe] = true }. Contrairement à data.Passes (achats
			-- Roblox, revérifiés à chaque arrivée), ils ne sont jamais retirés.
			Granted = {},
			Bought = {}, -- { [clé du pack] = nombre d'achats }
			GiftCredits = {}, -- { [clé du passe] = cadeaux payés pas encore envoyés }
			GiftsSent = 0,
			GiftsReceived = 0,
		},
	},

	Sanitize = function(data: Data)
		local offers = data.Offers
		local granted = {}
		for key in Guard.StringSet(offers.Granted, 50) do
			if Shop.Passes[key] then
				granted[key] = true
			end
		end
		offers.Granted = granted
		local bought = {}
		for key, count in offers.Bought do
			if type(key) == "string" and Shop.Packs[key] then
				bought[key] = Guard.IntegerOr(count, 0, 0)
			end
		end
		offers.Bought = bought
		local credits = {}
		for key, count in offers.GiftCredits do
			if type(key) == "string" and Shop.Passes[key] then
				local n = Guard.IntegerOr(count, 0, 0, MAX_CREDITS)
				if n > 0 then
					credits[key] = n
				end
			end
		end
		offers.GiftCredits = credits
		offers.GiftsSent = Guard.IntegerOr(offers.GiftsSent, 0, 0)
		offers.GiftsReceived = Guard.IntegerOr(offers.GiftsReceived, 0, 0)
	end,
}
