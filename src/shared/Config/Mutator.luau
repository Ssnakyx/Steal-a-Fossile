--!strict
-- Sérum de mutation (demande de Snaky du 2026-10-11 : « un objet qui permet d'appliquer une mutation à un monstre, qui
-- lui donne des bonus, mais qui a une chance d'échouer », comme le Fragment d'éclipse du Mutator de Pet Fusion Lab).
-- Le joueur choisit un de ses dinos dans le labo (bouton MUTATE du labo de fusion) et utilise un sérum :
--   * le sérum est toujours consommé ;
--   * réussite (SuccessChance %) : le dino reçoit une mutation tirée parmi celles qui sont MEILLEURES que la sienne
--     (Config.Economy.Mutations, toutes les zones, plus une mutation est rare moins elle sort : poids = sa Chance). La
--     mutation donne son bonus de revenu (Income) et ses effets animés (MutationController), comme à la réanimation ;
--   * échec : rien ne change, le dino garde sa mutation (pas de malus, comme le Fragment d'éclipse).
-- Un dino qui a déjà la meilleure mutation (Rainbow) ne peut plus être muté.
-- Sources de sérums : achat avec l'argent du jeu (prix = minutes du revenu du joueur), produit Robux MutationSerums3
-- (Config.Shop.Products), calendrier et cadeaux de temps de jeu (Config.Daily, genre de récompense « Serums »).
-- Toute chance payante affiche ses probas : le menu montre la réussite et la chance de chaque mutation possible.
-- Valeurs de départ, à équilibrer.

local Economy = require(script.Parent.Economy)

export type Odds = { Name: string, Chance: number, Income: number } -- Chance : 0 à 1, sachant que le sérum réussit

local Mutator = {
	Name = "Mutation Serum",
	Plural = "Mutation Serums",
	Color = Color3.fromRGB(255, 80, 220),
	SuccessChance = 40, -- % de réussite (comme le Fragment d'éclipse de Pet Fusion Lab)
	MaxOwned = 99, -- sérums gardés au plus
	-- Achat avec l'argent du jeu : PriceSeconds secondes du revenu actuel du joueur, au moins MinPrice
	PriceSeconds = 600,
	MinPrice = 2_500,
	MaxBuy = 10, -- sérums achetés en une fois au plus
	PerProduct = 3, -- sérums du produit Robux MutationSerums3
	ResultState = "Roar", -- animation du dino qui vient de muter
}

-- Rang d'une mutation (plus grand = meilleure) : revenu, puis la plus rare. "" ou inconnue : 0.
local RANK: { [string]: number } = { [""] = 0 }
do
	local list = table.clone(Economy.Mutations)
	table.sort(list, function(a, b)
		if a.Income ~= b.Income then
			return a.Income < b.Income
		end
		return a.Chance > b.Chance
	end)
	for index, info in list do
		RANK[info.Name] = index
	end
end

function Mutator.Rank(name: string?): number
	return if type(name) == "string" then RANK[name] or 0 else 0
end

-- Mutations qu'un sérum peut donner à un dino qui a déjà `current` ("" : aucune), avec leur chance (0 à 1, sachant
-- que le sérum réussit), de la plus commune à la plus rare. Vide : rien de mieux possible.
function Mutator.Odds(current: string?): { Odds }
	local rank = Mutator.Rank(current)
	local total = 0
	local out: { Odds } = {}
	for _, info in Economy.Mutations do
		if Mutator.Rank(info.Name) > rank and info.Chance > 0 then
			total += info.Chance
			table.insert(out, { Name = info.Name, Chance = info.Chance, Income = info.Income })
		end
	end
	for _, odds in out do
		odds.Chance /= total
	end
	return out
end

-- Le sérum peut-il améliorer ce dino ?
function Mutator.CanMutate(current: string?): boolean
	return #Mutator.Odds(current) > 0
end

-- Tire la mutation donnée par un sérum qui a réussi (roll dans [0, 1[) ; nil si rien de mieux n'est possible
function Mutator.Pick(current: string?, roll: number): string?
	local list = Mutator.Odds(current)
	if #list == 0 then
		return nil
	end
	local r = if type(roll) == "number" and roll == roll then math.clamp(roll, 0, 1) else 0
	local acc = 0
	for _, odds in list do
		acc += odds.Chance
		if r < acc then
			return odds.Name
		end
	end
	return list[#list].Name
end

-- Prix d'un sérum avec l'argent du jeu pour un joueur qui gagne `income` $/s
function Mutator.Price(income: number?): number
	local value = if type(income) == "number" and income == income and income > 0 and income < math.huge then income else 0
	return math.floor(math.max(Mutator.MinPrice, value * Mutator.PriceSeconds))
end

export type Mutator = typeof(Mutator)

return Mutator
