--!strict
-- BlockModels (brief 9 « blocs-hybrides ») : les blocs de fossiles en briques, un bloc voxel par rareté et un décor
-- par biome (faits par models/blocks/blocks.py, rendus dans Blender, exportés ici par models/blocks/build.py), et
-- l'apparence de chaque rareté. Partagé serveur et client.
--
--   local side = BlockModels.SideOf("Epic", 3)               -- côté en jeu d'un bloc Epic posé à la place d'un cube de 3
--   local model = BlockModels.Build("Epic", side, "Swamp")   -- Model en briques, centre du bloc au pivot
--   local look = BlockModels.Looks.Epic                      -- taille, lumière, battement, arc-en-ciel
--
-- Le bloc montre sa rareté (GDD : l'espèce reste une surprise) : roche de la couleur de Config.Rarity, même squelette
-- en relief pour toutes les raretés (crâne devant, côtes à droite, queue à gauche), des cristaux de plus en plus
-- nombreux, des os en or (Legendary), une base de lave (Mythic), des couches arc-en-ciel et des os nacrés
-- (Secret). Les raretés hautes sont plus grosses (Looks.Scale, jusqu'à x1,8 pour le Secret) et éclairent autour
-- d'elles (Looks.Light). Chaque biome (Config.Zones) pose son décor autour : sable et étoile de mer, mousse et fougère, boue
-- et liane, strates, glace, basalte et braises, sable et coraux, météorite et éclats violets.
-- Repère : l'avant du bloc (le crâne) regarde vers -Z, les cristaux sont sur la moitié avant du dessus, le décor du
-- biome derrière et sur la moitié arrière. Le pivot du modèle est le centre du bloc : pièce invisible « Root »
-- (PrimaryPart, porte la PointLight des raretés qui brillent). Les briques portent leur rôle dans leur nom : Rock,
-- Fossil, Glow (lave), Rainbow (couches du Secret), Gem (cristaux, attribut Gem), Biome, Ember (braises), Deco.
-- Les auras autour des blocs (cubes, particules) ne sont pas faites ici : thread des auras, via FossilBlockController.

local BlockModels = {}

export type Box = {
	Role: string, -- Rock, Fossil, Glow, Rainbow, Gem, Biome, Ember, Deco
	Gem: number?, -- numéro du cristal (rôle Gem)
	CFrame: CFrame, -- position et orientation dans le repère du bloc (côté de Size studs)
	Size: Vector3,
	Color: Color3,
	Material: string, -- nom de BlockModels.Materials
}

export type Data = {
	Name: string, -- rareté ou biome
	Size: number, -- côté du bloc en studs (3)
	Boxes: { Box },
	Gems: number, -- nombre de cristaux
}

-- Apparence d'une rareté (FossilBlockController) : ce qui grandit avec la rareté
export type Look = {
	Name: string,
	Rank: number, -- 1 Common ... 7 Secret
	Scale: number, -- taille en jeu par rapport à un bloc Common (demande de Snaky : les plus rares beaucoup plus gros)
	Light: number, -- éclat de la PointLight au centre du bloc (0 : pas de lumière ; réglé dans Studio : plus fort, le
	-- sol autour virait au blanc)
	Range: number, -- portée de cette lumière, en studs pour un bloc Common (grandit avec le bloc)
	LightColor: Color3,
	Pulse: boolean, -- lave, cristaux Neon et lumière battent
	Rainbow: boolean, -- couches, cristaux et lumière changent de couleur
}

BlockModels.Size = 3 -- studs : la pièce FossilBlock du serveur
BlockModels.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
BlockModels.Biomes = { "Beach", "Fern Forest", "Swamp", "Canyon", "Glacier", "Volcano", "Ocean Trench", "Meteor Crater" }
BlockModels.TankScale = 1.6 -- dans une cuve (verre de 5 studs), un bloc ne dépasse pas x1,6

-- Matières des briques : matière Roblox, reflet, transparence
BlockModels.Materials = {
	Plastic = { Enum.Material.Plastic, 0, 0 },
	Smooth = { Enum.Material.SmoothPlastic, 0, 0 },
	Neon = { Enum.Material.Neon, 0, 0 },
	Ice = { Enum.Material.Ice, 0.15, 0 },
	Glass = { Enum.Material.Glass, 0.05, 0.2 }, -- cristaux des Rare et Epic
	Metal = { Enum.Material.Metal, 0, 0 },
	Foil = { Enum.Material.Foil, 0, 0 }, -- os en or du Legendary
} :: { [string]: { any } }

-- ====================================================================== données des modèles

-- modèle d'une rareté ou décor d'un biome, tel qu'exporté (voir la section générée)
type Raw = {
	Voxel: number,
	Origin: number,
	Bones: { [string]: { Pivot: Vector3, Rest: Vector3 } },
	Colors: { Color3 },
	Materials: { string },
	Boxes: string,
}

-- >>> données générées par models/blocks/build.py (python models/blocks/build.py --export) : ne pas modifier à la main.
-- Boxes : une boîte par ligne « rôle x0 y0 z0 x1 y1 z1 peinture » (cases incluses) ; centre en studs =
-- ((x0 + x1 + 1) / 2 - Origin) * Voxel, taille = (x1 - x0 + 1) * Voxel ; peinture = Colors[i], Materials[i].
-- Bones : rôles qui ont un pivot et une rotation de repos (cristaux, feuilles), en studs depuis le centre.
local V = Vector3.new
local C = Color3.fromRGB
-- blocs de chaque rareté
local DATA: { [string]: Raw } = {
	Common = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(150, 149, 152), C(117, 116, 119), C(238, 228, 200) },
		Materials = { "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 1 2 14 16 14 1
Rock 2 0 2 14 15 14 2
Rock 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 17 5 5 17 6 5 3
Fossil 17 5 8 17 6 8 3
Fossil 17 5 11 17 6 11 3
Fossil 17 5 14 17 6 14 3
Fossil 2 6 -1 3 10 -1 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil 17 7 4 17 12 4 3
Fossil -1 7 6 -1 8 7 3
Fossil 17 7 7 17 12 7 3
Fossil 17 7 10 17 12 10 3
Fossil 17 7 13 17 12 13 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil -1 10 12 -1 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil 17 11 2 17 12 2 3
Fossil 17 11 5 17 12 5 3
Fossil 17 11 8 17 12 8 3
Fossil -1 11 9 -1 11 9 3
Fossil 17 11 11 17 12 11 3
Fossil 17 11 14 17 12 14 3
Fossil -1 12 13 -1 12 13 3
]],
	},
	Uncommon = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.618, 1.5, -0.441), Rest = V(-10, 0, 10) },
			Gem2 = { Pivot = V(-0.088, 1.5, -0.618), Rest = V(-24, 0, -8) },
		},
		Colors = { C(66, 160, 66), C(51, 125, 51), C(238, 228, 200), C(150, 226, 108), C(182, 235, 152) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 1 2 14 16 14 1
Rock 2 0 2 14 15 14 2
Rock 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 17 5 5 17 6 5 3
Fossil 17 5 8 17 6 8 3
Fossil 17 5 11 17 6 11 3
Fossil 17 5 14 17 6 14 3
Fossil 2 6 -1 3 10 -1 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil 17 7 4 17 12 4 3
Fossil -1 7 6 -1 8 7 3
Fossil 17 7 7 17 12 7 3
Fossil 17 7 10 17 12 10 3
Fossil 17 7 13 17 12 13 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil -1 10 12 -1 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil 17 11 2 17 12 2 3
Fossil 17 11 5 17 12 5 3
Fossil 17 11 8 17 12 8 3
Fossil -1 11 9 -1 11 9 3
Fossil 17 11 11 17 12 11 3
Fossil 17 11 14 17 12 14 3
Fossil -1 12 13 -1 12 13 3
Gem1 4 15 5 5 20 6 4
Gem2 7 15 4 8 19 5 4
Gem1 4 21 5 4 21 5 5
Gem2 7 20 4 7 20 4 5
]],
	},
	Rare = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.529, 1.5, -0.353), Rest = V(-8, 0, 8) },
			Gem2 = { Pivot = V(-0.088, 1.5, -0.618), Rest = V(-22, 0, -10) },
			Gem3 = { Pivot = V(-0.794, 1.5, 0.088), Rest = V(10, 0, 24) },
		},
		Colors = { C(32, 102, 204), C(25, 80, 159), C(238, 228, 200), C(120, 200, 255), C(160, 216, 255) },
		Materials = { "Plastic", "Plastic", "Plastic", "Glass", "Glass" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 1 2 14 16 14 1
Rock 2 0 2 14 15 14 2
Rock 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 17 5 5 17 6 5 3
Fossil 17 5 8 17 6 8 3
Fossil 17 5 11 17 6 11 3
Fossil 17 5 14 17 6 14 3
Fossil 2 6 -1 3 10 -1 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil 17 7 4 17 12 4 3
Fossil -1 7 6 -1 8 7 3
Fossil 17 7 7 17 12 7 3
Fossil 17 7 10 17 12 10 3
Fossil 17 7 13 17 12 13 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil -1 10 12 -1 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil 17 11 2 17 12 2 3
Fossil 17 11 5 17 12 5 3
Fossil 17 11 8 17 12 8 3
Fossil -1 11 9 -1 11 9 3
Fossil 17 11 11 17 12 11 3
Fossil 17 11 14 17 12 14 3
Fossil -1 12 13 -1 12 13 3
Gem1 4 15 5 6 22 7 4
Gem2 7 15 4 8 20 5 4
Gem3 3 15 8 4 19 9 4
Gem1 5 23 5 5 23 7 5
Gem1 4 23 6 6 23 6 5
Gem1 5 16 6 5 24 6 5
Gem2 7 21 4 7 21 4 5
Gem3 3 20 8 3 20 8 5
]],
	},
	Epic = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.529, 1.5, -0.353), Rest = V(-8, 0, 8) },
			Gem2 = { Pivot = V(-0.088, 1.5, -0.618), Rest = V(-22, 0, -10) },
			Gem3 = { Pivot = V(-0.794, 1.5, 0.088), Rest = V(10, 0, 24) },
			Gem4 = { Pivot = V(0.706, 1.5, -0.353), Rest = V(-10, 0, -10) },
			Gem5 = { Pivot = V(0.971, 1.5, 0.088), Rest = V(6, 0, -24) },
			Gem6 = { Pivot = V(0.265, 1.5, -0.618), Rest = V(-24, 0, 6) },
		},
		Colors = { C(124, 54, 192), C(97, 42, 150), C(238, 228, 200), C(190, 120, 255), C(210, 160, 255) },
		Materials = { "Plastic", "Plastic", "Plastic", "Glass", "Glass" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 1 2 14 16 14 1
Rock 2 0 2 14 15 14 2
Rock 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 17 5 5 17 6 5 3
Fossil 17 5 8 17 6 8 3
Fossil 17 5 11 17 6 11 3
Fossil 17 5 14 17 6 14 3
Fossil 2 6 -1 3 10 -1 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil 17 7 4 17 12 4 3
Fossil -1 7 6 -1 8 7 3
Fossil 17 7 7 17 12 7 3
Fossil 17 7 10 17 12 10 3
Fossil 17 7 13 17 12 13 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil -1 10 12 -1 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil 17 11 2 17 12 2 3
Fossil 17 11 5 17 12 5 3
Fossil 17 11 8 17 12 8 3
Fossil -1 11 9 -1 11 9 3
Fossil 17 11 11 17 12 11 3
Fossil 17 11 14 17 12 14 3
Fossil -1 12 13 -1 12 13 3
Gem1 4 15 5 6 22 7 4
Gem4 11 15 5 13 21 7 4
Gem2 7 15 4 8 20 5 4
Gem3 3 15 8 4 19 9 4
Gem5 13 15 8 14 19 9 4
Gem6 9 15 4 10 19 5 4
Gem1 5 23 5 5 23 7 5
Gem1 4 23 6 6 23 6 5
Gem1 5 16 6 5 24 6 5
Gem4 12 22 5 12 22 7 5
Gem4 11 22 6 13 22 6 5
Gem4 12 16 6 12 23 6 5
Gem2 7 21 4 7 21 4 5
Gem3 3 20 8 3 20 8 5
Gem5 13 20 8 13 20 8 5
Gem6 9 20 4 9 20 4 5
]],
	},
	Legendary = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.529, 1.5, -0.353), Rest = V(-8, 0, 8) },
			Gem2 = { Pivot = V(-0.088, 1.5, -0.618), Rest = V(-22, 0, -10) },
			Gem3 = { Pivot = V(-0.794, 1.5, 0.088), Rest = V(10, 0, 24) },
			Gem4 = { Pivot = V(0.706, 1.5, -0.353), Rest = V(-10, 0, -10) },
			Gem5 = { Pivot = V(0.971, 1.5, 0.088), Rest = V(6, 0, -24) },
			Gem6 = { Pivot = V(0.265, 1.5, -0.618), Rest = V(-24, 0, 6) },
			Gem7 = { Pivot = V(-0.088, 1.5, 0.088), Rest = V(4, 0, -4) },
		},
		Colors = { C(226, 112, 12), C(176, 87, 9), C(255, 200, 50), C(255, 196, 30), C(255, 214, 98) },
		Materials = { "Plastic", "Plastic", "Foil", "Neon", "Neon" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 1 2 14 16 14 1
Rock 2 0 2 14 15 14 2
Rock 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 17 5 5 17 6 5 3
Fossil 17 5 8 17 6 8 3
Fossil 17 5 11 17 6 11 3
Fossil 17 5 14 17 6 14 3
Fossil 2 6 -1 3 10 -1 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil 17 7 4 17 12 4 3
Fossil -1 7 6 -1 8 7 3
Fossil 17 7 7 17 12 7 3
Fossil 17 7 10 17 12 10 3
Fossil 17 7 13 17 12 13 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil -1 10 12 -1 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil 17 11 2 17 12 2 3
Fossil 17 11 5 17 12 5 3
Fossil 17 11 8 17 12 8 3
Fossil -1 11 9 -1 11 9 3
Fossil 17 11 11 17 12 11 3
Fossil 17 11 14 17 12 14 3
Fossil -1 12 13 -1 12 13 3
Gem1 4 15 5 6 22 7 4
Gem4 11 15 5 13 21 7 4
Gem2 7 15 4 8 20 5 4
Gem7 7 15 8 8 20 9 4
Gem3 3 15 8 4 19 9 4
Gem5 13 15 8 14 19 9 4
Gem6 9 15 4 10 19 5 4
Gem1 5 23 5 5 23 7 5
Gem1 4 23 6 6 23 6 5
Gem1 5 16 6 5 24 6 5
Gem4 12 22 5 12 22 7 5
Gem4 11 22 6 13 22 6 5
Gem4 12 16 6 12 23 6 5
Gem2 7 21 4 7 21 4 5
Gem3 3 20 8 3 20 8 5
Gem5 13 20 8 13 20 8 5
Gem6 9 20 4 9 20 4 5
Gem7 7 21 8 7 21 8 5
]],
	},
	Mythic = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.529, 1.5, -0.353), Rest = V(-8, 0, 8) },
			Gem2 = { Pivot = V(-0.088, 1.5, -0.618), Rest = V(-22, 0, -10) },
			Gem3 = { Pivot = V(-0.794, 1.5, 0.088), Rest = V(10, 0, 24) },
			Gem4 = { Pivot = V(0.706, 1.5, -0.353), Rest = V(-10, 0, -10) },
			Gem5 = { Pivot = V(0.971, 1.5, 0.088), Rest = V(6, 0, -24) },
			Gem6 = { Pivot = V(0.265, 1.5, -0.618), Rest = V(-24, 0, 6) },
			Gem7 = { Pivot = V(-0.088, 1.5, 0.088), Rest = V(4, 0, -4) },
		},
		Colors = { C(150, 22, 26), C(255, 106, 30), C(238, 228, 200), C(255, 74, 30), C(255, 128, 98) },
		Materials = { "Plastic", "Neon", "Plastic", "Neon", "Neon" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 2 2 14 16 14 1
Glow 2 0 2 14 1 14 2
Glow 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 17 5 5 17 6 5 3
Fossil 17 5 8 17 6 8 3
Fossil 17 5 11 17 6 11 3
Fossil 17 5 14 17 6 14 3
Fossil 2 6 -1 3 10 -1 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil 17 7 4 17 12 4 3
Fossil -1 7 6 -1 8 7 3
Fossil 17 7 7 17 12 7 3
Fossil 17 7 10 17 12 10 3
Fossil 17 7 13 17 12 13 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil -1 10 12 -1 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil 17 11 2 17 12 2 3
Fossil 17 11 5 17 12 5 3
Fossil 17 11 8 17 12 8 3
Fossil -1 11 9 -1 11 9 3
Fossil 17 11 11 17 12 11 3
Fossil 17 11 14 17 12 14 3
Fossil -1 12 13 -1 12 13 3
Gem1 4 15 5 6 22 7 4
Gem4 11 15 5 13 21 7 4
Gem2 7 15 4 8 20 5 4
Gem7 7 15 8 8 20 9 4
Gem3 3 15 8 4 19 9 4
Gem5 13 15 8 14 19 9 4
Gem6 9 15 4 10 19 5 4
Gem1 5 23 5 5 23 7 5
Gem1 4 23 6 6 23 6 5
Gem1 5 16 6 5 24 6 5
Gem4 12 22 5 12 22 7 5
Gem4 11 22 6 13 22 6 5
Gem4 12 16 6 12 23 6 5
Gem2 7 21 4 7 21 4 5
Gem3 3 20 8 3 20 8 5
Gem5 13 20 8 13 20 8 5
Gem6 9 20 4 9 20 4 5
Gem7 7 21 8 7 21 8 5
]],
	},
	Secret = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.529, 1.5, -0.353), Rest = V(-8, 0, 8) },
			Gem2 = { Pivot = V(-0.088, 1.5, -0.618), Rest = V(-22, 0, -10) },
			Gem3 = { Pivot = V(-0.794, 1.5, 0.088), Rest = V(10, 0, 24) },
			Gem4 = { Pivot = V(0.706, 1.5, -0.353), Rest = V(-10, 0, -10) },
			Gem5 = { Pivot = V(0.971, 1.5, 0.088), Rest = V(6, 0, -24) },
			Gem6 = { Pivot = V(0.265, 1.5, -0.618), Rest = V(-24, 0, 6) },
			Gem7 = { Pivot = V(-0.088, 1.5, 0.088), Rest = V(4, 0, -4) },
			Gem8 = { Pivot = V(0.971, 1.5, 0.794), Rest = V(14, 0, -16) },
			Gem9 = { Pivot = V(-0.971, 1.5, 0.794), Rest = V(16, 0, 14) },
		},
		Colors = { C(236, 56, 64), C(170, 90, 235), C(80, 200, 90), C(255, 170, 40), C(250, 248, 255), C(60, 140, 240), C(236, 56, 64), C(60, 140, 240), C(255, 170, 40), C(80, 200, 90), C(170, 90, 235), C(242, 116, 121), C(118, 174, 244), C(255, 196, 104), C(132, 216, 140), C(196, 140, 241) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Foil", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
		Boxes = [[
Rainbow 2 0 2 14 15 14 1
Rainbow 1 1 1 15 3 15 1
Rainbow 2 2 0 14 3 16 1
Rainbow 0 2 2 16 3 14 1
Rainbow 2 14 0 14 14 16 2
Rainbow 1 14 1 15 15 15 2
Rainbow 0 14 2 16 14 14 2
Rainbow 2 1 2 14 16 14 2
Rainbow 2 7 0 14 10 16 3
Rainbow 1 7 1 15 10 15 3
Rainbow 0 7 2 16 10 14 3
Rainbow 2 4 0 14 6 16 4
Rainbow 1 4 1 15 6 15 4
Rainbow 0 4 2 16 6 14 4
Fossil 6 4 -1 11 5 -1 5
Fossil -1 4 2 -1 4 2 5
Fossil 4 5 -1 4 12 -1 5
Fossil 5 5 -1 5 5 -1 5
Fossil 12 5 -1 13 5 -1 5
Fossil -1 5 3 -1 6 4 5
Fossil 17 5 5 17 6 5 5
Fossil 17 5 8 17 6 8 5
Fossil 17 5 11 17 6 11 5
Fossil 17 5 14 17 6 14 5
Fossil 2 6 -1 3 10 -1 5
Fossil 5 7 -1 6 8 -1 5
Fossil 8 7 -1 8 12 -1 5
Fossil 10 7 -1 10 11 -1 5
Fossil 12 7 -1 12 10 -1 5
Fossil 14 7 -1 14 9 -1 5
Fossil -1 7 3 -1 7 3 5
Fossil 17 7 4 17 12 4 5
Fossil -1 7 6 -1 8 7 5
Fossil 17 7 7 17 12 7 5
Fossil 17 7 10 17 12 10 5
Fossil 17 7 13 17 12 13 5
Fossil 7 8 -1 7 12 -1 5
Fossil 9 8 -1 9 8 -1 5
Fossil 11 8 -1 11 11 -1 5
Fossil 13 8 -1 13 10 -1 5
Fossil -1 9 6 -1 9 6 5
Fossil -1 9 9 -1 10 10 5
Fossil -1 10 12 -1 11 14 5
Fossil 3 11 -1 3 12 -1 5
Fossil 5 11 -1 6 12 -1 5
Fossil 9 11 -1 9 11 -1 5
Fossil 17 11 2 17 12 2 5
Fossil 17 11 5 17 12 5 5
Fossil 17 11 8 17 12 8 5
Fossil -1 11 9 -1 11 9 5
Fossil 17 11 11 17 12 11 5
Fossil 17 11 14 17 12 14 5
Fossil -1 12 13 -1 12 13 5
Rainbow 2 11 0 14 13 16 6
Rainbow 1 11 1 15 13 15 6
Rainbow 0 11 2 16 13 14 6
Gem1 4 15 5 6 22 7 7
Gem4 11 15 5 13 21 7 8
Gem2 7 15 4 8 20 5 9
Gem7 7 15 8 8 20 9 9
Gem9 2 15 12 3 20 13 8
Gem3 3 15 8 4 19 9 10
Gem5 13 15 8 14 19 9 11
Gem6 9 15 4 10 19 5 7
Gem8 13 15 12 14 19 13 10
Gem1 5 23 5 5 23 7 12
Gem1 4 23 6 6 23 6 12
Gem1 5 16 6 5 24 6 12
Gem4 12 22 5 12 22 7 13
Gem4 11 22 6 13 22 6 13
Gem4 12 16 6 12 23 6 13
Gem2 7 21 4 7 21 4 14
Gem3 3 20 8 3 20 8 15
Gem5 13 20 8 13 20 8 16
Gem6 9 20 4 9 20 4 12
Gem7 7 21 8 7 21 8 14
Gem8 13 20 12 13 20 12 15
Gem9 2 21 12 2 21 12 13
]],
	},
}
-- décor de chaque biome (nom de la zone, Config.Zones), posé autour du bloc
local BIOMES: { [string]: Raw } = {
	Beach = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(226, 206, 150), C(240, 140, 80), C(232, 224, 206), C(214, 204, 186) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Biome -1 0 -1 17 0 1 1
Biome -1 0 2 1 0 17 1
Biome 15 0 2 17 0 17 1
Biome 2 0 15 14 0 17 1
Biome 0 1 0 16 1 0 1
Biome 0 1 1 0 1 16 1
Biome 16 1 1 16 1 16 1
Biome 1 1 16 15 1 16 1
Biome 6 5 17 6 6 17 2
Biome 10 5 17 10 6 17 2
Biome 7 6 17 7 9 17 2
Biome 9 6 17 9 9 17 2
Biome 8 7 17 8 11 17 2
Biome 6 8 17 6 9 17 2
Biome 10 8 17 10 9 17 2
Biome 5 9 17 5 9 17 2
Biome 11 9 17 11 9 17 2
Biome 7 17 11 8 17 12 3
Biome 10 17 13 10 17 13 4
]],
	},
	["Fern Forest"] = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Deco1 = { Pivot = V(-0.176, 1.676, 0.706), Rest = V(28, 0, 0) },
			Deco2 = { Pivot = V(-0.353, 1.676, 0.706), Rest = V(-6, 0, 30) },
			Deco3 = { Pivot = V(0, 1.676, 0.706), Rest = V(-6, 0, -30) },
		},
		Colors = { C(86, 150, 60), C(52, 104, 44), C(70, 150, 56), C(104, 186, 78) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Biome 4 13 17 5 14 17 1
Biome 10 13 17 11 14 17 1
Biome 3 14 17 3 14 17 1
Biome 6 14 17 9 14 17 1
Biome 12 14 17 13 14 17 1
Biome 4 17 10 9 17 14 1
Biome 10 17 12 12 17 14 1
Biome 8 4 17 8 9 17 2
Biome 5 6 17 5 6 17 2
Biome 11 6 17 11 6 17 2
Biome 6 7 17 6 7 17 2
Biome 10 7 17 10 7 17 2
Biome 5 8 17 5 8 17 2
Biome 11 8 17 11 8 17 2
Biome 6 9 17 6 9 17 2
Biome 10 9 17 10 9 17 2
Biome 7 10 17 7 10 17 2
Biome 9 10 17 9 10 17 2
Biome 8 11 17 8 11 17 2
Deco2 6 17 12 6 22 12 3
Deco3 8 17 12 8 22 12 3
Deco1 7 17 12 7 22 12 3
Deco1 7 20 11 7 20 13 4
Deco2 6 20 11 6 20 11 4
Deco2 6 20 13 6 20 13 4
Deco3 8 20 11 8 20 11 4
Deco3 8 20 13 8 20 13 4
]],
	},
	Swamp = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(88, 74, 48), C(70, 150, 72), C(72, 128, 52), C(236, 124, 172) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Biome -1 0 -1 17 0 1 1
Biome -1 0 2 1 0 17 1
Biome 15 0 2 17 0 17 1
Biome 2 0 15 14 0 17 1
Biome 0 1 0 16 1 0 1
Biome 0 1 1 0 1 16 1
Biome 16 1 1 16 1 16 1
Biome 1 1 16 15 1 16 1
Biome 3 2 17 3 3 17 1
Biome 6 2 17 6 2 17 1
Biome 10 2 17 10 4 17 1
Biome 14 2 17 14 2 17 1
Biome 7 17 10 9 17 11 2
Biome 6 17 11 6 17 13 2
Biome 10 17 11 10 17 13 2
Biome 7 17 12 7 17 14 2
Biome 9 17 12 9 17 13 2
Biome 8 17 13 8 17 14 2
Biome 12 7 17 12 14 17 3
Biome 11 8 17 11 8 17 3
Biome 13 10 17 13 10 17 3
Biome 11 12 17 11 12 17 3
Biome 8 17 12 8 18 12 4
]],
	},
	Canyon = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(184, 92, 58), C(214, 138, 86), C(196, 110, 70), C(170, 88, 56), C(206, 128, 82) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Biome 2 2 -1 14 2 -1 1
Biome -1 2 2 -1 2 14 1
Biome 17 2 2 17 2 14 1
Biome 2 2 17 14 2 17 1
Biome 2 14 -1 14 14 -1 2
Biome -1 14 2 -1 14 14 2
Biome 17 14 2 17 14 14 2
Biome 2 14 17 14 14 17 2
Biome 2 8 17 14 8 17 3
Biome 7 17 12 8 18 13 4
Biome 10 17 13 10 17 14 5
]],
	},
	Glacier = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(244, 250, 255), C(196, 232, 255) },
		Materials = { "Plastic", "Ice" },
		Boxes = [[
Biome -1 0 -1 17 0 1 1
Biome -1 0 2 1 0 17 1
Biome 15 0 2 17 0 17 1
Biome 2 0 15 14 0 17 1
Biome 9 11 17 9 14 17 2
Biome 3 12 17 3 14 17 2
Biome 6 13 17 6 14 17 2
Biome 12 13 17 12 14 17 2
Biome 2 17 9 14 18 14 2
]],
	},
	Volcano = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(44, 38, 40), C(110, 104, 104), C(255, 112, 40) },
		Materials = { "Plastic", "Plastic", "Neon" },
		Boxes = [[
Biome -1 0 -1 17 0 1 1
Biome -1 0 2 1 0 17 1
Biome 15 0 2 17 0 17 1
Biome 2 0 15 14 0 17 1
Biome 0 1 0 16 1 0 1
Biome 0 1 1 0 1 16 1
Biome 16 1 1 16 1 16 1
Biome 1 1 16 15 1 16 1
Biome 2 2 17 14 3 17 1
Biome 6 17 10 10 17 11 2
Biome 6 17 12 7 17 14 2
Biome 9 17 12 10 17 12 2
Biome 8 17 13 8 17 14 2
Biome 10 17 13 10 17 14 2
Biome 9 17 14 9 17 14 2
Ember 4 6 17 4 6 17 3
Ember 11 9 17 11 9 17 3
Ember 7 12 17 7 12 17 3
Ember 8 17 12 8 17 12 3
Ember 9 17 13 9 17 13 3
]],
	},
	["Ocean Trench"] = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {},
		Colors = { C(214, 196, 150), C(210, 214, 218), C(60, 150, 92), C(244, 108, 140), C(250, 150, 70) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
		Boxes = [[
Biome -1 0 -1 17 0 1 1
Biome -1 0 2 1 0 17 1
Biome 15 0 2 17 0 17 1
Biome 2 0 15 14 0 17 1
Biome 11 2 -1 12 2 -1 2
Biome -1 2 4 -1 2 5 2
Biome 17 2 11 17 2 12 2
Biome 4 2 17 5 2 17 2
Biome 4 3 -1 5 3 -1 2
Biome 17 3 4 17 3 5 2
Biome -1 3 11 -1 3 12 2
Biome 11 3 17 12 3 17 2
Biome 3 1 17 3 9 17 3
Biome 14 1 17 14 3 17 3
Biome 13 4 17 13 5 17 3
Biome 4 10 17 4 11 17 3
Biome 7 17 12 7 20 12 4
Biome 8 18 12 8 18 12 4
Biome 6 19 12 6 19 12 4
Biome 10 17 13 10 19 13 5
Biome 11 17 13 11 17 13 5
Biome 9 18 13 9 18 13 5
]],
	},
	["Meteor Crater"] = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Deco1 = { Pivot = V(0, 1.853, 0.706), Rest = V(6, 0, 4) },
			Deco2 = { Pivot = V(-0.176, 1.853, 0.529), Rest = V(-24, 0, 26) },
			Deco3 = { Pivot = V(0.176, 1.853, 0.882), Rest = V(26, 0, -24) },
		},
		Colors = { C(70, 62, 84), C(56, 50, 70), C(170, 110, 255), C(255, 230, 120), C(220, 180, 255) },
		Materials = { "Plastic", "Plastic", "Neon", "Neon", "Neon" },
		Boxes = [[
Biome -1 0 -1 17 0 1 1
Biome -1 0 2 1 0 17 1
Biome 15 0 2 17 0 17 1
Biome 2 0 15 14 0 17 1
Biome 11 2 17 12 2 17 2
Biome 4 3 17 5 3 17 2
Biome 12 3 17 12 3 17 2
Biome 4 4 17 4 4 17 2
Biome 7 17 11 9 18 13 2
Deco1 8 17 12 8 22 12 3
Deco2 7 17 11 7 20 11 3
Deco3 9 17 13 9 20 13 3
Biome 8 7 17 8 7 17 4
Biome 13 11 17 13 11 17 4
Biome 3 12 17 3 12 17 4
Deco1 8 23 12 8 23 12 5
Deco2 7 21 11 7 21 11 5
Deco3 9 21 13 9 21 13 5
]],
	},
}
-- taille en jeu par rapport à un bloc Common (les plus rares sont beaucoup plus gros)
local SCALES: { [string]: number } = { Common = 1, Uncommon = 1.06, Rare = 1.14, Epic = 1.24, Legendary = 1.38, Mythic = 1.55, Secret = 1.8 }
-- <<< fin des données générées

BlockModels.Looks = {
	Common = { Name = "Common", Rank = 1, Scale = SCALES.Common, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Uncommon = { Name = "Uncommon", Rank = 2, Scale = SCALES.Uncommon, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Rare = { Name = "Rare", Rank = 3, Scale = SCALES.Rare, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Epic = { Name = "Epic", Rank = 4, Scale = SCALES.Epic, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Legendary = { Name = "Legendary", Rank = 5, Scale = SCALES.Legendary, Light = 0.8, Range = 6, LightColor = Color3.fromRGB(255, 196, 90), Pulse = true, Rainbow = false },
	Mythic = { Name = "Mythic", Rank = 6, Scale = SCALES.Mythic, Light = 0.9, Range = 6.5, LightColor = Color3.fromRGB(255, 96, 50), Pulse = true, Rainbow = false },
	Secret = { Name = "Secret", Rank = 7, Scale = SCALES.Secret, Light = 1, Range = 7, LightColor = Color3.fromRGB(255, 120, 220), Pulse = true, Rainbow = true },
} :: { [string]: Look }

local cache: { [string]: Data } = {}

local function decode(name: string, raw: Raw): Data
	local voxel, origin = raw.Voxel, raw.Origin
	local boxes: { Box } = {}
	local gems = 0
	for role, a, b, c, d, e, f, paint in string.gmatch(raw.Boxes, "(%w+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%d+)") do
		local x0, y0, z0 = tonumber(a) :: number, tonumber(b) :: number, tonumber(c) :: number
		local x1, y1, z1 = tonumber(d) :: number, tonumber(e) :: number, tonumber(f) :: number
		local index = tonumber(paint) :: number
		local center = Vector3.new((x0 + x1 + 1) / 2 - origin, (y0 + y1 + 1) / 2 - origin, (z0 + z1 + 1) / 2 - origin) * voxel
		local size = Vector3.new(x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1) * voxel
		local cf = CFrame.new(center)
		local bone = raw.Bones[role]
		if bone then
			-- cristal, feuille, éclat : incliné par la rotation de repos de son os, autour de sa base
			local r = bone.Rest
			cf = CFrame.new(bone.Pivot)
				* CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
				* CFrame.new(-bone.Pivot)
				* cf
		end
		local gem: number? = nil
		local n = string.match(role, "^Gem(%d+)$")
		if n then
			gem = tonumber(n)
			gems = math.max(gems, gem or 0)
			role = "Gem"
		elseif string.match(role, "^Deco%d+$") then
			role = "Deco"
		end
		table.insert(boxes, {
			Role = role,
			Gem = gem,
			CFrame = cf,
			Size = size,
			Color = raw.Colors[index] or Color3.new(1, 0, 1),
			Material = raw.Materials[index] or "Plastic",
		})
	end
	return { Name = name, Size = BlockModels.Size, Boxes = boxes, Gems = gems }
end

local function lookup(source: { [string]: Raw }, prefix: string, name: any): Data?
	if type(name) ~= "string" then
		return nil
	end
	local key = prefix .. name
	local hit = cache[key]
	if hit then
		return hit
	end
	local raw = source[name]
	if not raw then
		return nil
	end
	local data = decode(name, raw)
	cache[key] = data
	return data
end

-- Données du bloc d'une rareté (nil si la rareté n'existe pas). Mises en cache.
function BlockModels.Get(rarity: any): Data?
	return lookup(DATA, "R:", rarity)
end

-- Décor d'un biome (nom de la zone de Config.Zones ; nil si la zone n'a pas de décor). Mis en cache.
function BlockModels.Biome(zone: any): Data?
	return lookup(BIOMES, "B:", zone)
end

-- Nombre de briques du bloc d'une rareté avec le décor d'une zone (0 si la rareté n'existe pas), pièce Root comprise
function BlockModels.Count(rarity: any, zone: any?): number
	local data = BlockModels.Get(rarity)
	if not data then
		return 0
	end
	local biome = BlockModels.Biome(zone)
	return #data.Boxes + (if biome then #biome.Boxes else 0) + 1
end

-- Échelle d'un bloc dont le côté mesure `size` studs (BlockModels.Size par défaut)
function BlockModels.ScaleOf(size: number?): number
	if type(size) ~= "number" or size ~= size or size <= 0 then
		return 1
	end
	return math.clamp(size / BlockModels.Size, 0.05, 20)
end

-- Côté en jeu du bloc d'une rareté posé à la place d'un cube de `side` studs (pièce du serveur) : les raretés hautes
-- sont plus grosses ; dans une cuve (kind = "TankBlock"), au plus x BlockModels.TankScale.
function BlockModels.SideOf(rarity: any, side: any, kind: string?): number
	local look = if type(rarity) == "string" then BlockModels.Looks[rarity] else nil
	local scale = if look then look.Scale else 1
	if kind == "TankBlock" then
		scale = math.min(scale, BlockModels.TankScale)
	end
	local base: number = if type(side) == "number" and side == side and side > 0 and side < 1000 then side else BlockModels.Size
	return base * scale
end

local function addBoxes(model: Model, data: Data, scale: number, first: number)
	for i, box in data.Boxes do
		local p = Instance.new("Part")
		p.Name = box.Role
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local s = box.Size * scale
		p.Size = s
		local cf = box.CFrame
		p.CFrame = CFrame.new(cf.Position * scale) * cf.Rotation
		local mat = BlockModels.Materials[box.Material] or BlockModels.Materials.Plastic
		p.Material = mat[1]
		p.Reflectance = mat[2]
		p.Transparency = mat[3]
		p.Color = box.Color
		-- studs entiers seulement : dessus d'au moins 1 x 1 stud en plastique
		if p.Material == Enum.Material.Plastic and s.X >= 0.99 and s.Z >= 0.99 then
			p.TopSurface = Enum.SurfaceType.Studs
		end
		p.CastShadow = s.Magnitude > 1
		if box.Gem then
			p:SetAttribute("Gem", box.Gem)
		end
		p:SetAttribute("Box", first + i)
		p.Parent = model
	end
end

-- Modèle en briques au repos : centre du bloc à l'origine (pièce Root, PrimaryPart), côté de `size` studs, avec le
-- décor du biome `zone` s'il existe. Les briques sont ancrées, sans collision ni requête ; leur nom est leur rôle.
-- Les raretés qui brillent ont une PointLight dans Root. nil si la rareté n'existe pas.
function BlockModels.Build(rarity: any, size: number?, zone: any?): Model?
	local data = BlockModels.Get(rarity)
	if not data then
		return nil
	end
	local scale = BlockModels.ScaleOf(size)
	local model = Instance.new("Model")
	model.Name = data.Name .. "Fossil"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	addBoxes(model, data, scale, 0)
	local biome = BlockModels.Biome(zone)
	if biome then
		addBoxes(model, biome, scale, #data.Boxes)
		model:SetAttribute("Zone", biome.Name)
	end
	local look = BlockModels.Looks[data.Name]
	if look and look.Light > 0 then
		local light = Instance.new("PointLight")
		light.Brightness = look.Light
		light.Range = look.Range * scale
		light.Color = look.LightColor
		light.Shadows = false
		light.Parent = root
	end
	model:SetAttribute("Rarity", data.Name)
	model:SetAttribute("Scale", scale)
	return model
end

return BlockModels
