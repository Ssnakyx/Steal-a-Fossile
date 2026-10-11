--!strict
-- Données du joueur, domaine Core (brief 1 « fondations ») : argent, statistiques, achats Robux traités, Index.
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Config.Core)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

return {
	Version = 1,
	Defaults = {
		Money = Core.StartingMoney,
		TotalEarned = 0, -- argent gagné depuis toujours (statistiques, classements)
		RobuxSpent = 0, -- Robux dépensés dans le jeu (achats réels seulement)
		FirstJoin = 0, -- os.time() de la première connexion
		LastSeen = 0, -- os.time() de la dernière sauvegarde (revenu hors ligne : comparer au chargement)
		PlayTime = 0, -- secondes de jeu au total (protection débutant)
		Purchases = {}, -- PurchaseId des achats Robux déjà donnés, les plus récents à la fin (ReceiptService)
		Index = {
			Species = {}, -- { [espèce] = true } espèces déjà réanimées
			Hybrids = {}, -- { [hybride] = true } hybrides déjà découverts
			Claimed = {}, -- { [page] = true } récompenses de pages déjà prises
		},
	},

	Sanitize = function(data: Data)
		data.Money = Guard.NumberOr(data.Money, Core.StartingMoney, 0, Core.MaxMoney)
		data.TotalEarned = Guard.NumberOr(data.TotalEarned, 0, 0, Core.MaxMoney)
		data.RobuxSpent = Guard.IntegerOr(data.RobuxSpent, 0, 0)
		data.FirstJoin = Guard.IntegerOr(data.FirstJoin, 0, 0)
		if data.FirstJoin == 0 then
			data.FirstJoin = os.time()
		end
		data.LastSeen = Guard.IntegerOr(data.LastSeen, 0, 0)
		data.PlayTime = Guard.NumberOr(data.PlayTime, 0, 0)
		local purchases = {}
		for _, purchaseId in data.Purchases do
			if type(purchaseId) == "string" and #purchaseId <= 100 then
				table.insert(purchases, purchaseId)
			end
		end
		while #purchases > Core.Purchases.Remember do
			table.remove(purchases, 1)
		end
		data.Purchases = purchases
		data.Index.Species = Guard.StringSet(data.Index.Species)
		data.Index.Hybrids = Guard.StringSet(data.Index.Hybrids)
		data.Index.Claimed = Guard.StringSet(data.Index.Claimed)
	end,

	BeforeSave = function(data: Data, elapsed: number)
		data.PlayTime += elapsed
		data.LastSeen = os.time()
	end,
}
