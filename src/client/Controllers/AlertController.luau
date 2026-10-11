--!strict
-- Alerte de tout le serveur quand un bloc rare apparaît dans un gisement (DigSiteService, remote FossilAlert) :
-- grande carte de la couleur de la rareté (arc-en-ciel pour Secret) dans la liste des messages courts, en haut au
-- milieu (sous la carte du haut si elle est là). Le message du chat vient de LoopAnnounce (LoopController).
-- Seuil de rareté et durée : Config.Zones.Dig.AlertRarity, AlertTime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local AlertController = {}

local MAX_COUNT = 99

-- Montre l'alerte d'un bloc rare : rareté, zone, nombre de blocs (1 par défaut). Renvoie la carte (nil si refusée).
function AlertController.Show(rarity: string, zone: string, count: number?): Frame?
	local colors = UIKit.Rarity[rarity]
	if not colors or not Config.Zones.ByName[zone] then
		return nil
	end
	local amount = if count and count > 1 then math.min(math.floor(count), MAX_COUNT) else 1
	local title = if amount > 1
		then string.format("%d %s FOSSILS!", amount, string.upper(rarity))
		else string.upper(rarity) .. " FOSSIL!"
	return UIKit.alert({
		Title = title,
		Text = "Just appeared in the " .. zone .. "!",
		Color = colors.Fill,
		Rainbow = colors.Rainbow,
		Icon = "egg_gold",
		Duration = Config.Zones.Dig.AlertTime,
	})
end

function AlertController.Init()
	Remotes.Event("FossilAlert").OnClientEvent:Connect(function(rarity: any, zone: any, count: any)
		if type(rarity) ~= "string" or type(zone) ~= "string" then
			return
		end
		local amount = if type(count) == "number" and count == count and count >= 1 and count < math.huge then count else 1
		AlertController.Show(rarity, zone, amount)
	end)
end

return AlertController
