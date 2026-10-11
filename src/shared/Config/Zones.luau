--!strict
-- Les 8 zones de la route (brief 3 « boucle », GDD sections Carte et Espèces) et les réglages des gisements.
-- Valeurs de départ à équilibrer. La géométrie (provisoire) est construite par ZoneService ; la vraie map est faite
-- par le brief 10 avec les mêmes noms (voir docs/BOUCLE.md).
--
-- Weights : chances relatives de chaque rareté pour un bloc de la zone. Seules les raretés qui ont au moins une espèce
-- de la zone (Config.Rarity.Species) y figurent, plus Secret (espèces Secret, toutes zones, surtout les lointaines).
-- Zones.Chances(nom, chance) donne les probas affichables (toute chance payante affiche ses probas).

export type Zone = {
	Name: string, -- nom affiché et identifiant (identique au champ Zone de Config.Species)
	Index: number, -- 1 (près du spawn) à 8 (le plus loin)
	Speed: number, -- vitesse conseillée (pas un mur : le gardien rattrape ceux qui vont trop vite trop loin)
	Weights: { [string]: number },
	Species: { string }, -- espèces de la zone (hors Secrets)
	Color: Color3, -- sol provisoire
}

local List: { Zone } = {
	{
		Name = "Beach",
		Index = 1,
		Speed = 0,
		Weights = { Common = 75, Uncommon = 25, Secret = 0.01 },
		Species = { "Compy", "Oviraptor", "Pteranodon", "Protoceratops", "Psittacosaurus", "Dimorphodon", "Archelon", "Tanystropheus" },
		Color = Color3.fromRGB(232, 210, 150),
	},
	{
		Name = "Fern Forest",
		Index = 2,
		Speed = 1e3,
		Weights = { Common = 60, Uncommon = 28, Rare = 12, Secret = 0.02 },
		Species = { "Gallimimus", "Parasaurolophus", "Stegosaurus" },
		Color = Color3.fromRGB(88, 150, 70),
	},
	{
		Name = "Swamp",
		Index = 3,
		Speed = 1e4,
		Weights = { Uncommon = 60, Rare = 30, Epic = 10, Secret = 0.03 },
		Species = { "Iguanodon", "Baryonyx", "Sarcosuchus" },
		Color = Color3.fromRGB(85, 105, 60),
	},
	{
		Name = "Canyon",
		Index = 4,
		Speed = 5e4,
		Weights = { Rare = 62, Epic = 30, Legendary = 8, Secret = 0.05 },
		Species = { "Pachycephalosaurus", "Velociraptor", "Triceratops" },
		Color = Color3.fromRGB(185, 95, 55),
	},
	{
		Name = "Glacier",
		Index = 5,
		Speed = 2e5,
		Weights = { Rare = 50, Epic = 38, Legendary = 12, Secret = 0.08 },
		Species = { "Ankylosaurus", "Therizinosaurus", "Cryolophosaurus" },
		Color = Color3.fromRGB(200, 230, 245),
	},
	{
		Name = "Volcano",
		Index = 6,
		Speed = 1e6,
		Weights = { Epic = 62, Legendary = 31, Mythic = 7, Secret = 0.12 },
		Species = { "Carnotaurus", "Brachiosaurus", "Spinosaurus" },
		Color = Color3.fromRGB(50, 45, 45),
	},
	{
		Name = "Ocean Trench",
		Index = 7,
		Speed = 5e6,
		Weights = { Epic = 52, Legendary = 38, Mythic = 10, Secret = 0.18 },
		Species = { "Plesiosaurus", "Megalodon", "Mosasaurus" },
		Color = Color3.fromRGB(40, 85, 135),
	},
	{
		Name = "Meteor Crater",
		Index = 8,
		Speed = 2.5e7,
		Weights = { Legendary = 72, Mythic = 28, Secret = 0.3 },
		Species = { "Quetzalcoatlus", "Giganotosaurus", "T-Rex" },
		Color = Color3.fromRGB(95, 60, 130),
	},
}

local ByName: { [string]: Zone } = {}
for _, zone in List do
	ByName[zone.Name] = zone
end

local Zones = {
	List = List,
	ByName = ByName,

	-- Gisements (DigSiteService)
	Dig = {
		Sites = 3, -- gisements par zone (géométrie provisoire ; la vraie map peut en mettre plus ou moins)
		BlocksPerSite = 4, -- places de blocs par gisement (sauf points « Slot » posés par la map)
		RefillInterval = 300, -- secondes entre deux remplissages (les places vides seulement)
		GrabTime = 1, -- secondes à maintenir E pour arracher un bloc
		GrabDistance = 10, -- portée du ProximityPrompt (studs) ; le serveur tolère un peu plus
		TutorialZone = "Beach", -- tutoriel : cette zone garde un bloc Common tant qu'un nouveau n'a pas rapporté son premier bloc
		TutorialRarity = "Common",
	},
}

-- (ordre des raretés, sans requérir Config.Rarity : chaque fichier de config se lit seul)
local RANKS: { [string]: number } = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
function Zones.RankOf(rarity: string): number
	return RANKS[rarity] or 0
end

-- Probas de chaque rareté dans une zone (0 à 1), avec un multiplicateur de chance (Server Luck : 2) qui s'applique à
-- toutes les raretés au-dessus de la plus commune de la zone. Table vide si la zone n'existe pas.
function Zones.Chances(zoneName: string, luck: number?): { [string]: number }
	local zone = ByName[zoneName]
	local chances: { [string]: number } = {}
	if not zone then
		return chances
	end
	local boost = if type(luck) == "number" and luck == luck and luck >= 1 and luck < math.huge then luck else 1
	local lowest = math.huge
	for rarity in zone.Weights do
		local rank = Zones.RankOf(rarity)
		if rank < lowest then
			lowest = rank
		end
	end
	local total = 0
	for rarity, weight in zone.Weights do
		local w = if Zones.RankOf(rarity) > lowest then weight * boost else weight
		chances[rarity] = w
		total += w
	end
	if total > 0 then
		for rarity, w in chances do
			chances[rarity] = w / total
		end
	end
	return chances
end

export type Zones = typeof(Zones)

return Zones
