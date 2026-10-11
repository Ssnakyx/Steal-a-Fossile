--!strict
-- Économie de la boucle (brief 3 « boucle », GDD sections Boucle, Taille et mutations, Fusion, Rétention) :
-- revenus des dinos, tailles et mutations tirées à la réanimation, cuves, enclos, revenu hors ligne.
-- Valeurs de départ à équilibrer.

export type SizeInfo = { Name: string, Chance: number, Income: number, Scale: number }
export type MutationInfo = {
	Name: string,
	Chance: number, -- % (tirage unique à la réanimation)
	Income: number, -- multiplicateur de revenu
	Zone: string?, -- mutation de biome : ne sort que des fossiles de cette zone (nil : toutes les zones)
	Color: Color3, -- couleur de la mutation (textes, effets)
}
export type MutationChance = { Name: string, Chance: number, Income: number }
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

	-- Mutations (docs/MUTATIONS.md), de la plus commune à la plus rare. Chance en % (tirage unique ; sans mutation le
	-- reste du temps), multipliée par la chance du joueur (pass VIP). Amber, Crystal, Lava et Rainbow sortent de toutes
	-- les zones ; chaque biome a en plus sa mutation à lui (Zone), qui ne sort que de ses fossiles.
	-- Apparence : DinoBuilder (couleurs des briques) et MutationController (effets autour du dino), mêmes noms.
	Mutations = {
		{ Name = "Amber", Chance = 8, Income = 1.5, Color = Color3.fromRGB(255, 172, 38) },
		{ Name = "Crystal", Chance = 3, Income = 2, Color = Color3.fromRGB(150, 228, 255) },
		{ Name = "Pearl", Chance = 2, Income = 2, Zone = "Beach", Color = Color3.fromRGB(255, 226, 236) },
		{ Name = "Bloom", Chance = 2, Income = 2, Zone = "Fern Forest", Color = Color3.fromRGB(255, 120, 196) },
		{ Name = "Toxic", Chance = 1.5, Income = 2.5, Zone = "Swamp", Color = Color3.fromRGB(150, 255, 60) },
		{ Name = "Ruby", Chance = 1.5, Income = 2.5, Zone = "Canyon", Color = Color3.fromRGB(235, 30, 70) },
		{ Name = "Frost", Chance = 1.5, Income = 2.5, Zone = "Glacier", Color = Color3.fromRGB(190, 236, 255) },
		{ Name = "Lava", Chance = 1, Income = 3, Color = Color3.fromRGB(255, 108, 28) },
		{ Name = "Obsidian", Chance = 1, Income = 3, Zone = "Volcano", Color = Color3.fromRGB(170, 90, 255) },
		{ Name = "Abyssal", Chance = 0.75, Income = 4, Zone = "Ocean Trench", Color = Color3.fromRGB(60, 230, 255) },
		{ Name = "Galaxy", Chance = 0.5, Income = 5, Zone = "Meteor Crater", Color = Color3.fromRGB(190, 120, 255) },
		{ Name = "Rainbow", Chance = 0.05, Income = 10, Color = Color3.fromRGB(255, 90, 200) },
	} :: { MutationInfo },
	-- Une mutation de Chance <= MutationAnnounce (%) est annoncée à tout le serveur quand elle sort (MutationService)
	MutationAnnounce = 1,
	-- Bloc rare = plus de chances d'une mutation rare (demande de Snaky du 2026-10-11 : « quand on ouvre un œuf rare, on
	-- a une chance qu'il ait une mutation rare »). Une mutation est rare si sa Chance <= MaxChance (%) : Lava, Obsidian,
	-- Abyssal, Galaxy et Rainbow, les mêmes que celles annoncées au serveur. À la réanimation, sa chance est multipliée
	-- par Boost[rareté du bloc] (en plus de la chance du joueur) ; les autres mutations ne changent pas.
	RareMutation = {
		MaxChance = 1,
		Boost = {
			Common = 1,
			Uncommon = 1,
			Rare = 1.5,
			Epic = 2,
			Legendary = 3,
			Mythic = 5,
			Secret = 10,
		} :: { [string]: number },
	},

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

local MUTATION_BY_NAME: { [string]: MutationInfo } = {}
for _, info in Economy.Mutations do
	MUTATION_BY_NAME[info.Name] = info
end

-- Fiche d'une mutation par son nom (nil : pas de mutation ou nom inconnu)
function Economy.Mutation(name: string?): MutationInfo?
	return if type(name) == "string" then MUTATION_BY_NAME[name] else nil
end

-- Nom exact d'une mutation tapé sans faire attention aux majuscules (commandes admin) ; nil si inconnu
function Economy.FindMutation(text: string?): string?
	if type(text) ~= "string" then
		return nil
	end
	local wanted = string.lower(text)
	for _, info in Economy.Mutations do
		if string.lower(info.Name) == wanted then
			return info.Name
		end
	end
	return nil
end

-- La mutation peut-elle sortir d'un fossile de cette zone ? (mutation de biome : seulement de sa zone)
function Economy.MutationInZone(info: MutationInfo, zoneName: string?): boolean
	return info.Zone == nil or info.Zone == zoneName
end

local function luckBoost(luck: number?): number
	return 1 + (if type(luck) == "number" and luck == luck and luck > 0 and luck < math.huge then luck else 0)
end

-- Mutation rare ? (Chance <= RareMutation.MaxChance : sa chance monte avec la rareté du bloc)
function Economy.IsRareMutation(info: MutationInfo): boolean
	return info.Chance <= Economy.RareMutation.MaxChance
end

-- Multiplicateur des mutations rares pour un bloc de cette rareté (1 : rareté inconnue ou sans bonus)
function Economy.RareMutationBoost(rarity: string?): number
	local boost = if type(rarity) == "string" then Economy.RareMutation.Boost[rarity] else nil
	return if type(boost) == "number" and boost > 0 and boost < math.huge then boost else 1
end

-- Chance (%) d'une mutation avec la chance du joueur et la rareté du bloc
local function boosted(info: MutationInfo, boost: number, rarity: string?): number
	return info.Chance * boost * (if Economy.IsRareMutation(info) then Economy.RareMutationBoost(rarity) else 1)
end

-- Tire la mutation d'un dino réanimé : zone du fossile, bonus de chance du joueur (0.1 = +10 %), roll dans [0, 1[,
-- rareté du bloc (facultative : plus de chances de mutation rare, voir RareMutation).
-- De la plus rare à la plus commune (avec une chance énorme, la plus rare de la zone sort toujours). "" : aucune.
function Economy.RollMutation(zoneName: string?, luck: number?, roll: number, rarity: string?): string
	local boost = luckBoost(luck)
	local r = (if type(roll) == "number" and roll == roll then math.clamp(roll, 0, 1) else 1) * 100
	local acc = 0
	for index = #Economy.Mutations, 1, -1 do
		local info = Economy.Mutations[index]
		if Economy.MutationInZone(info, zoneName) then
			acc += boosted(info, boost, rarity)
			if r < acc then
				return info.Name
			end
		end
	end
	return ""
end

-- Probas affichables des mutations d'une zone (0 à 1, avec la chance du joueur et la rareté du bloc facultative), de
-- la plus commune à la plus rare, puis { Name = "", ... } : aucune mutation. Mêmes calculs que RollMutation (toute
-- chance payante affiche ses probas).
function Economy.MutationChances(zoneName: string?, luck: number?, rarity: string?): { MutationChance }
	local boost = luckBoost(luck)
	local out: { MutationChance } = {}
	local left = 1
	-- (même ordre que le tirage : les plus rares d'abord, la somme bornée à 100 %)
	for index = #Economy.Mutations, 1, -1 do
		local info = Economy.Mutations[index]
		if Economy.MutationInZone(info, zoneName) then
			local p = math.min(boosted(info, boost, rarity) / 100, left)
			left -= p
			table.insert(out, 1, { Name = info.Name, Chance = p, Income = info.Income })
		end
	end
	table.insert(out, { Name = "", Chance = left, Income = 1 })
	return out
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
