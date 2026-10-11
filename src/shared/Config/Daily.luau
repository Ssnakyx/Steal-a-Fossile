--!strict
-- Récompenses pour revenir et rester (demande de Snaky du 2026-10-11 : « daily spin », AFK, bonne rétention et bon CCU ;
-- reprend la récompense quotidienne de 14 jours du GDD, section Rétention). Valeurs de départ à équilibrer.
--   * Login : calendrier de 14 jours, une récompense par jour, la série repart au jour 1 si un jour est manqué.
--   * Spins : roue de la chance, 1 tour gratuit par jour, des tours en plus gagnés en jouant (cadeaux, calendrier) ou
--     achetés en Robux (produits Spins3, Spins10 : jamais proposés aux joueurs des pays où les achats au hasard payants
--     sont interdits, PolicyService). Les chances sont affichées sur la roue.
--   * Gifts : cadeaux de temps de jeu, débloqués par le temps passé en jeu dans la journée (AFK compris) ; ils repartent
--     de zéro chaque jour.
-- Un jour = Daily.Day(os.time()) : le jour change à 00:00 UTC (+ ResetOffset secondes).
-- Montants : l'argent vaut des minutes du revenu actuel du joueur (IncomeMinutes, avec un minimum Amount) et la vitesse
-- un pourcentage de sa vitesse gagnée (SpeedPercent, minimum Amount) : la récompense reste utile à tout moment du jeu.
-- Le serveur et le client calculent avec la même fonction (Daily.Amount), le serveur décide.

local Format = require(script.Parent.Parent.Format)

export type Reward = {
	Kind: string, -- "Money" | "Speed" | "Spins" | "BearTraps" | "Block"
	Amount: number?, -- Money, Speed : minimum ; Spins, BearTraps : nombre
	IncomeMinutes: number?, -- Money : minutes du revenu actuel du joueur ($/s x 60 x minutes)
	SpeedPercent: number?, -- Speed : pourcentage de la vitesse gagnée (data.Speed)
	Rarity: string?, -- Block : rareté du bloc fossile (il part dans une cuve, l'espèce sera tirée à la révélation)
}
export type Prize = { Name: string, Weight: number, Reward: Reward }
export type Gift = { Minutes: number, Reward: Reward }
export type SpinProduct = { Id: number, Name: string, Count: number, Price: number, Order: number }
-- Bases du calcul des montants pour un joueur : son revenu ($/s) et sa vitesse gagnée
export type Scale = { Income: number, Speed: number }

local Daily = {
	DayLength = 86400,
	ResetOffset = 0, -- secondes ajoutées à os.time() avant de compter les jours (0 = nouveau jour à 00:00 UTC)

	-- Calendrier de 14 jours (GDD) : un clic par jour. Après le jour 14, on repart au jour 1 (la série continue).
	Login = {
		ResetOnMiss = true, -- un jour manqué : retour au jour 1 et série à 0
		AutoOpen = true, -- le calendrier s'ouvre tout seul à l'arrivée quand une récompense attend
		Days = {
			{ Kind = "Money", IncomeMinutes = 5, Amount = 200 },
			{ Kind = "Spins", Amount = 1 },
			{ Kind = "Speed", SpeedPercent = 3, Amount = 300 },
			{ Kind = "BearTraps", Amount = 3 },
			{ Kind = "Money", IncomeMinutes = 15, Amount = 1_000 },
			{ Kind = "Spins", Amount = 2 },
			{ Kind = "Block", Rarity = "Epic" },
			{ Kind = "Money", IncomeMinutes = 20, Amount = 2_500 },
			{ Kind = "Speed", SpeedPercent = 5, Amount = 1_000 },
			{ Kind = "BearTraps", Amount = 5 },
			{ Kind = "Spins", Amount = 3 },
			{ Kind = "Money", IncomeMinutes = 45, Amount = 10_000 },
			{ Kind = "Speed", SpeedPercent = 8, Amount = 3_000 },
			{ Kind = "Block", Rarity = "Legendary" },
		} :: { Reward },
	},

	-- Roue de la chance : 8 cases, Weight = chances relatives (affichées en % sur la roue).
	Spins = {
		FreePerDay = 1, -- tours gratuits chaque jour (pas cumulables d'un jour à l'autre)
		MaxStored = 10_000, -- tours en réserve au plus (gagnés ou achetés)
		Cooldown = 4, -- secondes entre deux tours (le temps que la roue tourne)
		Prizes = {
			{ Name = "Cash", Weight = 26, Reward = { Kind = "Money", IncomeMinutes = 10, Amount = 300 } },
			{ Name = "Speed", Weight = 20, Reward = { Kind = "Speed", SpeedPercent = 2, Amount = 300 } },
			{ Name = "Big Cash", Weight = 12, Reward = { Kind = "Money", IncomeMinutes = 30, Amount = 1_500 } },
			{ Name = "Bear Traps", Weight = 12, Reward = { Kind = "BearTraps", Amount = 3 } },
			{ Name = "Spin Again", Weight = 10, Reward = { Kind = "Spins", Amount = 1 } },
			{ Name = "Rare Fossil", Weight = 11, Reward = { Kind = "Block", Rarity = "Rare" } },
			{ Name = "Epic Fossil", Weight = 6, Reward = { Kind = "Block", Rarity = "Epic" } },
			{ Name = "Legendary Fossil", Weight = 3, Reward = { Kind = "Block", Rarity = "Legendary" } },
		} :: { Prize },
		-- Produits développeur : Id = 0 tant que Snaky ne les a pas créés dans le Creator Hub (ils restent cachés).
		-- Price = prix conseillé à mettre dans le Creator Hub ; le prix affiché est celui que Roblox renvoie.
		Products = {
			Spins3 = { Id = 0, Name = "3 Spins", Count = 3, Price = 49, Order = 1 },
			Spins10 = { Id = 0, Name = "10 Spins", Count = 10, Price = 129, Order = 2 },
		} :: { [string]: SpinProduct },
	},

	-- Cadeaux de temps de jeu : Minutes = temps de jeu du jour (AFK compris) pour débloquer le cadeau.
	Gifts = {
		{ Minutes = 5, Reward = { Kind = "Money", IncomeMinutes = 5, Amount = 150 } },
		{ Minutes = 10, Reward = { Kind = "Spins", Amount = 1 } },
		{ Minutes = 15, Reward = { Kind = "Speed", SpeedPercent = 1, Amount = 200 } },
		{ Minutes = 20, Reward = { Kind = "Money", IncomeMinutes = 10, Amount = 500 } },
		{ Minutes = 30, Reward = { Kind = "BearTraps", Amount = 2 } },
		{ Minutes = 45, Reward = { Kind = "Spins", Amount = 1 } },
		{ Minutes = 60, Reward = { Kind = "Money", IncomeMinutes = 25, Amount = 2_000 } },
		{ Minutes = 90, Reward = { Kind = "Block", Rarity = "Rare" } },
		{ Minutes = 120, Reward = { Kind = "Spins", Amount = 2 } },
	} :: { Gift },

	-- Donné à la place d'une récompense impossible (cuves et réserve pleines, pièges au maximum)
	Fallback = { Kind = "Money", IncomeMinutes = 5, Amount = 250 } :: Reward,
}

-- Numéro du jour (UTC + ResetOffset) d'un instant os.time()
function Daily.Day(time: number): number
	return (math.floor(time) + Daily.ResetOffset) // Daily.DayLength
end

-- os.time() du début du jour suivant (prochaine remise à zéro)
function Daily.NextReset(time: number): number
	return (Daily.Day(time) + 1) * Daily.DayLength - Daily.ResetOffset
end

local function finite(value: any): number
	return if type(value) == "number" and value == value and value > -math.huge and value < math.huge then value else 0
end

-- Montant d'une récompense pour un joueur (argent, vitesse, nombre de tours ou de pièges ; 1 pour un bloc)
function Daily.Amount(reward: Reward, scale: Scale?): number
	local income = math.max(0, finite(scale and scale.Income))
	local speed = math.max(0, finite(scale and scale.Speed))
	local minimum = math.max(0, finite(reward.Amount))
	if reward.Kind == "Money" then
		return math.floor(math.max(minimum, income * 60 * finite(reward.IncomeMinutes)))
	elseif reward.Kind == "Speed" then
		return math.floor(math.max(minimum, speed * finite(reward.SpeedPercent) / 100))
	elseif reward.Kind == "Block" then
		return 1
	end
	return math.max(1, math.floor(minimum))
end

-- Texte court d'une récompense : "+$1.2K", "+500 Speed", "+3 Spins", "3 Bear Traps", "Epic Fossil"
function Daily.Label(reward: Reward, scale: Scale?): string
	local amount = Daily.Amount(reward, scale)
	if reward.Kind == "Money" then
		return "+$" .. Format.Number(amount)
	elseif reward.Kind == "Speed" then
		return "+" .. Format.Number(amount) .. " Speed"
	elseif reward.Kind == "Spins" then
		return "+" .. amount .. (if amount == 1 then " Spin" else " Spins")
	elseif reward.Kind == "BearTraps" then
		return amount .. (if amount == 1 then " Bear Trap" else " Bear Traps")
	elseif reward.Kind == "Block" then
		return tostring(reward.Rarity) .. " Fossil"
	end
	return reward.Kind
end

-- Chance d'une case de la roue (0..1)
function Daily.Chance(index: number): number
	local total = 0
	for _, prize in Daily.Spins.Prizes do
		total += prize.Weight
	end
	local prize = Daily.Spins.Prizes[index]
	return if prize and total > 0 then prize.Weight / total else 0
end

export type Daily = typeof(Daily)

return Daily
