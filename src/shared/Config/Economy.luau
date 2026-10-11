--!strict
-- Économie de la boucle (brief 3 « boucle », GDD sections Boucle, Taille et mutations, Fusion, Rétention) :
-- revenus des dinos, tailles et mutations tirées à la réanimation, cuves, enclos, revenu hors ligne.
-- Valeurs de départ à équilibrer.

export type SizeInfo = { Name: string, Chance: number, Income: number, Scale: number }
export type MutationInfo = { Name: string, Chance: number, Income: number }
export type LevelInfo = { Name: string, Income: number }

local Economy = {
	-- Tailles tirées à la réanimation. Chance : relative. Income : multiplicateur de revenu (GDD « Taille et
	-- mutations »). Scale : échelle visible du modèle (GDD « Tailles », mêmes valeurs que DinoBuilder.Sizes).
	Sizes = {
		{ Name = "Small", Chance = 30, Income = 0.8, Scale = 0.75 },
		{ Name = "Normal", Chance = 50, Income = 1, Scale = 1 },
		{ Name = "Big", Chance = 17, Income = 1.5, Scale = 1.5 },
		{ Name = "Huge", Chance = 3, Income = 3, Scale = 2.5 },
	} :: { SizeInfo },

	-- Mutations : Chance en % (tirage unique ; sans mutation le reste du temps)
	Mutations = {
		{ Name = "Amber", Chance = 8, Income = 1.5 },
		{ Name = "Crystal", Chance = 3, Income = 2 },
		{ Name = "Lava", Chance = 1, Income = 3 },
	} :: { MutationInfo },

	-- Niveaux de fusion Upgrade (data.Dinos[id].Level : 0, 1, 2), multiplicateur de revenu. Réglés avec le brief 8.
	Levels = {
		{ Name = "Normal", Income = 1 },
		{ Name = "Golden", Income = 4 },
		{ Name = "Diamond", Income = 16 },
	} :: { LevelInfo },

	-- Revenu de base ($/s) par rareté, utilisé seulement pour une espèce absente de Config.Species (brief 2) et sans
	-- base enregistrée (IncomeService.RegisterBase, hybrides du brief 8)
	FallbackIncome = {
		Common = 1,
		Uncommon = 3,
		Rare = 12,
		Epic = 60,
		Legendary = 300,
		Mythic = 1500,
		Secret = 500000,
	} :: { [string]: number },

	IncomeInterval = 1, -- secondes entre deux versements
	OfflineCap = 8 * 3600, -- revenu hors ligne plafonné à 8 h (secondes)

	-- Effets des passes du brief 4 (ShopService.HasPass)
	Passes = {
		DoubleMoney = 2, -- revenus x2
		FastRevive = 2, -- cuves 2x plus rapides
	},

	-- Cuves de réanimation : 2 au départ, jusqu'à 6. Prices[n] = prix de la (Start + n)-ième cuve.
	Tanks = {
		Start = 2,
		Max = 6,
		Prices = { 1000, 25000, 500000, 10000000 } :: { number },
	},

	-- Blocs rapportés quand toutes les cuves sont pleines : ils attendent en réserve (data.Stored)
	MaxStored = 12,
	MaxInstantCredits = 20, -- Instant Revive gardés pour plus tard (achetés sans cuve en cours)

	-- Enclos : BaseSlots dinos, + SlotsPerUpgrade par agrandissement. Prices[n] = prix du n-ième agrandissement.
	Enclosure = {
		BaseSlots = 8,
		SlotsPerUpgrade = 2,
		Prices = { 750, 5000, 25000, 150000, 1000000, 7500000, 50000000, 400000000 } :: { number },
	},
}

-- Prix de la prochaine cuve quand le joueur en a `owned` (nil : toutes achetées)
function Economy.NextTankPrice(owned: number): number?
	if owned >= Economy.Tanks.Max then
		return nil
	end
	return Economy.Tanks.Prices[owned - Economy.Tanks.Start + 1]
end

-- Nombre de slots d'enclos après `upgrades` agrandissements
function Economy.EnclosureSlots(upgrades: number): number
	local count = math.clamp(math.floor(upgrades), 0, #Economy.Enclosure.Prices)
	return Economy.Enclosure.BaseSlots + count * Economy.Enclosure.SlotsPerUpgrade
end

-- Prix du prochain agrandissement après `upgrades` (nil : enclos au maximum)
function Economy.NextEnclosurePrice(upgrades: number): number?
	return Economy.Enclosure.Prices[math.floor(upgrades) + 1]
end

export type Economy = typeof(Economy)

return Economy
