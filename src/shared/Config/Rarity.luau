--!strict
-- Raretés des blocs fossiles (brief 3 « boucle », GDD section Raretés) : couleur du bloc, durée de réanimation,
-- malus de vitesse pendant le transport, et rareté de chaque espèce. Valeurs de départ à équilibrer.
-- Les chances de tirer chaque rareté dépendent de la zone : voir Config.Zones (les zones lointaines ont de meilleures
-- probas).

export type RarityInfo = {
	Name: string,
	Rank: number, -- 1 (Common) à 7 (Secret)
	Color: Color3, -- couleur du bloc (provisoire : les effets par rareté sont faits par le brief 11)
	ReviveTime: number, -- secondes en cuve
	CarrySpeed: number, -- multiplicateur de vitesse pendant le transport (CarryService.GetSpeedMultiplier)
}

local Order: { string } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local Info: { [string]: RarityInfo } = {
	Common = { Name = "Common", Rank = 1, Color = Color3.fromRGB(163, 162, 165), ReviveTime = 30, CarrySpeed = 0.9 },
	Uncommon = { Name = "Uncommon", Rank = 2, Color = Color3.fromRGB(75, 175, 75), ReviveTime = 60, CarrySpeed = 0.85 },
	Rare = { Name = "Rare", Rank = 3, Color = Color3.fromRGB(30, 110, 220), ReviveTime = 180, CarrySpeed = 0.8 },
	Epic = { Name = "Epic", Rank = 4, Color = Color3.fromRGB(140, 60, 210), ReviveTime = 600, CarrySpeed = 0.75 },
	Legendary = { Name = "Legendary", Rank = 5, Color = Color3.fromRGB(255, 145, 20), ReviveTime = 1800, CarrySpeed = 0.7 },
	Mythic = { Name = "Mythic", Rank = 6, Color = Color3.fromRGB(215, 35, 35), ReviveTime = 3600, CarrySpeed = 0.65 },
	-- (arc-en-ciel : couleur provisoire, le brief 11 fait l'arc-en-ciel qui tourne)
	Secret = { Name = "Secret", Rank = 7, Color = Color3.fromRGB(255, 90, 200), ReviveTime = 10800, CarrySpeed = 0.6 },
}

-- Rareté de chaque espèce (GDD : « rareté de chacune à fixer à l'équilibrage »). La couleur du bloc fixe la rareté,
-- puis l'espèce est tirée parmi les espèces de la zone qui ont cette rareté. Un bloc Secret donne une espèce Secret,
-- quelle que soit la zone. Noms identiques à Config.Species (brief 2).
local Species: { [string]: string } = {
	-- Beach
	Compy = "Common",
	Oviraptor = "Common",
	Pteranodon = "Uncommon",
	Protoceratops = "Common",
	Psittacosaurus = "Common",
	Dimorphodon = "Common",
	Archelon = "Uncommon",
	Tanystropheus = "Uncommon",
	-- Fern Forest
	Gallimimus = "Common",
	Parasaurolophus = "Uncommon",
	Stegosaurus = "Rare",
	Hypsilophodon = "Common",
	Microraptor = "Common",
	Kentrosaurus = "Uncommon",
	Styracosaurus = "Uncommon",
	Dilophosaurus = "Rare",
	-- Swamp
	Iguanodon = "Uncommon",
	Baryonyx = "Rare",
	Sarcosuchus = "Epic",
	-- Canyon
	Pachycephalosaurus = "Rare",
	Velociraptor = "Epic",
	Triceratops = "Legendary",
	-- Glacier
	Ankylosaurus = "Rare",
	Therizinosaurus = "Epic",
	Cryolophosaurus = "Legendary",
	Troodon = "Rare",
	Smilodon = "Rare",
	Yutyrannus = "Epic",
	["Woolly Mammoth"] = "Epic",
	["Frost Wyvern"] = "Legendary",
	-- Volcano
	Carnotaurus = "Epic",
	Brachiosaurus = "Legendary",
	Spinosaurus = "Mythic",
	Dracorex = "Epic",
	Ceratosaurus = "Epic",
	Acrocanthosaurus = "Legendary",
	["Magma Behemoth"] = "Legendary",
	Phoenix = "Mythic",
	-- Ocean Trench
	Plesiosaurus = "Epic",
	Megalodon = "Legendary",
	Mosasaurus = "Mythic",
	-- Meteor Crater
	Quetzalcoatlus = "Legendary",
	Giganotosaurus = "Mythic",
	["T-Rex"] = "Mythic",
	-- Secrets (toutes zones, surtout les lointaines)
	["Golden Raptor"] = "Secret",
	["Crystal Rex"] = "Secret",
	["Lava Titan"] = "Secret",
}

-- Espèces Secret (tirées pour un bloc Secret), dans l'ordre alphabétique
local SecretSpecies: { string } = {}
for name, rarity in Species do
	if rarity == "Secret" then
		table.insert(SecretSpecies, name)
	end
end
table.sort(SecretSpecies)

local Rarity = {
	Order = Order,
	Info = Info,
	Species = Species,
	SecretSpecies = SecretSpecies,
}

-- Rang d'une rareté (1 à 7), 0 si elle n'existe pas
function Rarity.Rank(name: string): number
	local info = Info[name]
	return if info then info.Rank else 0
end

export type Rarity = typeof(Rarity)

return Rarity
