--!strict
-- Données des blocs de fossiles, générées par models/blocks/build.py --export : ne pas modifier à la main.
-- Lues par BlockModels (init.luau). Boxes : une boîte par ligne « rôle x0 y0 z0 x1 y1 z1 peinture » (cases
-- incluses) ; centre en studs = ((x0 + x1 + 1) / 2 - Origin) * Voxel, taille = (x1 - x0 + 1) * Voxel ;
-- peinture = Colors[i], Materials[i]. Bones : rôles qui ont un pivot et une rotation de repos (cristaux,
-- feuilles, morceaux qui flottent), en studs depuis le centre.

export type Raw = {
	Voxel: number,
	Origin: number,
	Bones: { [string]: { Pivot: Vector3, Rest: Vector3 } },
	Colors: { Color3 },
	Materials: { string },
	Boxes: string,
}

local V = Vector3.new
local C = Color3.fromRGB

-- taille en jeu par rapport à un bloc Common (les plus rares sont beaucoup plus gros)
local Scales: { [string]: number } = { Common = 1, Uncommon = 1.06, Rare = 1.14, Epic = 1.24, Legendary = 1.38, Mythic = 1.55, Secret = 1.8 }

-- forme de chaque biome (nom de la zone de Config.Zones)
local Forms: { [string]: string } = {
	Beach = "Ammonite",
	["Fern Forest"] = "Stump",
	Swamp = "Mound",
	Canyon = "Hoodoo",
	Glacier = "Crystal",
	Volcano = "Volcano",
	["Ocean Trench"] = "Scallop",
	["Meteor Crater"] = "Meteorite",
}

-- cubes sans biome (zone inconnue), par rareté
local Generic: { [string]: Raw } = {
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
Fossil 17 4 5 17 5 5 3
Fossil 17 4 8 17 5 8 3
Fossil 17 4 11 17 5 11 3
Fossil 17 4 14 17 5 14 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 2 6 -1 3 10 -1 3
Fossil 17 6 4 17 11 4 3
Fossil 17 6 7 17 11 7 3
Fossil 17 6 10 17 11 10 3
Fossil 17 6 13 17 11 13 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil -1 7 6 -1 8 7 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil 17 10 2 17 11 2 3
Fossil 17 10 5 17 11 5 3
Fossil 17 10 8 17 11 8 3
Fossil 17 10 11 17 11 11 3
Fossil -1 10 12 -1 11 14 3
Fossil 17 10 14 17 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil -1 11 9 -1 11 9 3
Fossil -1 12 13 -1 12 13 3
]],
	},
	Uncommon = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(-0.088, 1.5, -0.265), Rest = V(-6, 0, 0) },
			Gem2 = { Pivot = V(0.971, 1.147, 1.324), Rest = V(30, 0, -30) },
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
Fossil 17 4 5 17 5 5 3
Fossil 17 4 8 17 5 8 3
Fossil 17 4 11 17 5 11 3
Fossil 17 4 14 17 5 14 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 2 6 -1 3 10 -1 3
Fossil 17 6 4 17 11 4 3
Fossil 17 6 7 17 11 7 3
Fossil 17 6 10 17 11 10 3
Fossil 17 6 13 17 11 13 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil -1 7 6 -1 8 7 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil 17 10 2 17 11 2 3
Fossil 17 10 5 17 11 5 3
Fossil 17 10 8 17 11 8 3
Fossil 17 10 11 17 11 11 3
Fossil -1 10 12 -1 11 14 3
Fossil 17 10 14 17 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil -1 11 9 -1 11 9 3
Fossil -1 12 13 -1 12 13 3
Gem1 7 15 6 8 20 7 4
Gem2 13 13 15 14 17 16 4
Gem1 7 21 6 7 21 6 5
Gem2 13 18 15 13 18 15 5
]],
	},
	Rare = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-6, 0, 0) },
			Gem2 = { Pivot = V(0.971, 1.147, 1.324), Rest = V(30, 0, -30) },
			Gem3 = { Pivot = V(-0.971, 1.147, 1.324), Rest = V(30, 0, 30) },
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
Fossil 17 4 5 17 5 5 3
Fossil 17 4 8 17 5 8 3
Fossil 17 4 11 17 5 11 3
Fossil 17 4 14 17 5 14 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 2 6 -1 3 10 -1 3
Fossil 17 6 4 17 11 4 3
Fossil 17 6 7 17 11 7 3
Fossil 17 6 10 17 11 10 3
Fossil 17 6 13 17 11 13 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil -1 7 6 -1 8 7 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil 17 10 2 17 11 2 3
Fossil 17 10 5 17 11 5 3
Fossil 17 10 8 17 11 8 3
Fossil 17 10 11 17 11 11 3
Fossil -1 10 12 -1 11 14 3
Fossil 17 10 14 17 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil -1 11 9 -1 11 9 3
Fossil -1 12 13 -1 12 13 3
Gem1 7 15 6 9 21 8 4
Gem2 13 13 15 14 18 16 4
Gem3 2 13 15 3 17 16 4
Gem1 8 22 6 8 22 8 5
Gem1 7 22 7 9 22 7 5
Gem1 8 16 7 8 23 7 5
Gem2 13 19 15 13 19 15 5
Gem3 2 18 15 2 18 15 5
]],
	},
	Epic = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-6, 0, 0) },
			Gem2 = { Pivot = V(0.971, 1.147, 1.324), Rest = V(30, 0, -30) },
			Gem3 = { Pivot = V(-0.971, 1.147, 1.324), Rest = V(30, 0, 30) },
			Gem4 = { Pivot = V(1.324, 1.147, -0.971), Rest = V(-30, 0, -30) },
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
Fossil 17 4 5 17 5 5 3
Fossil 17 4 8 17 5 8 3
Fossil 17 4 11 17 5 11 3
Fossil 17 4 14 17 5 14 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 2 6 -1 3 10 -1 3
Fossil 17 6 4 17 11 4 3
Fossil 17 6 7 17 11 7 3
Fossil 17 6 10 17 11 10 3
Fossil 17 6 13 17 11 13 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil -1 7 6 -1 8 7 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil 17 10 2 17 11 2 3
Fossil 17 10 5 17 11 5 3
Fossil 17 10 8 17 11 8 3
Fossil 17 10 11 17 11 11 3
Fossil -1 10 12 -1 11 14 3
Fossil 17 10 14 17 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil -1 11 9 -1 11 9 3
Fossil -1 12 13 -1 12 13 3
Gem1 7 15 6 9 21 8 4
Gem2 13 13 15 14 18 16 4
Gem4 15 13 2 16 18 3 4
Gem3 2 13 15 3 17 16 4
Gem1 8 22 6 8 22 8 5
Gem1 7 22 7 9 22 7 5
Gem1 8 16 7 8 23 7 5
Gem2 13 19 15 13 19 15 5
Gem3 2 18 15 2 18 15 5
Gem4 15 19 2 15 19 2 5
]],
	},
	Legendary = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-6, 0, 0) },
			Gem2 = { Pivot = V(0.971, 1.147, 1.324), Rest = V(30, 0, -30) },
			Gem3 = { Pivot = V(-0.971, 1.147, 1.324), Rest = V(30, 0, 30) },
			Gem4 = { Pivot = V(1.324, 1.147, -0.971), Rest = V(-30, 0, -30) },
			Gem5 = { Pivot = V(-1.324, 1.147, -0.971), Rest = V(-30, 0, 30) },
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
Fossil 17 4 5 17 5 5 3
Fossil 17 4 8 17 5 8 3
Fossil 17 4 11 17 5 11 3
Fossil 17 4 14 17 5 14 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 2 6 -1 3 10 -1 3
Fossil 17 6 4 17 11 4 3
Fossil 17 6 7 17 11 7 3
Fossil 17 6 10 17 11 10 3
Fossil 17 6 13 17 11 13 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil -1 7 6 -1 8 7 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil 17 10 2 17 11 2 3
Fossil 17 10 5 17 11 5 3
Fossil 17 10 8 17 11 8 3
Fossil 17 10 11 17 11 11 3
Fossil -1 10 12 -1 11 14 3
Fossil 17 10 14 17 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil -1 11 9 -1 11 9 3
Fossil -1 12 13 -1 12 13 3
Gem1 7 15 6 9 21 8 4
Gem2 13 13 15 14 18 16 4
Gem4 15 13 2 16 18 3 4
Gem3 2 13 15 3 17 16 4
Gem5 0 13 2 1 17 3 4
Gem1 8 22 6 8 22 8 5
Gem1 7 22 7 9 22 7 5
Gem1 8 16 7 8 23 7 5
Gem2 13 19 15 13 19 15 5
Gem3 2 18 15 2 18 15 5
Gem4 15 19 2 15 19 2 5
Gem5 0 18 2 0 18 2 5
]],
	},
	Mythic = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-6, 0, 0) },
			Gem2 = { Pivot = V(0.971, 1.147, 1.324), Rest = V(30, 0, -30) },
			Gem3 = { Pivot = V(-0.971, 1.147, 1.324), Rest = V(30, 0, 30) },
			Gem4 = { Pivot = V(1.324, 1.147, -0.971), Rest = V(-30, 0, -30) },
			Gem5 = { Pivot = V(-1.324, 1.147, -0.971), Rest = V(-30, 0, 30) },
		},
		Colors = { C(150, 22, 26), C(117, 17, 20), C(238, 228, 200), C(255, 74, 30), C(255, 106, 30), C(255, 128, 98) },
		Materials = { "Plastic", "Plastic", "Plastic", "Neon", "Neon", "Neon" },
		Boxes = [[
Rock 2 2 0 14 14 16 1
Rock 1 2 1 15 15 15 1
Rock 0 2 2 16 14 14 1
Rock 2 1 2 14 16 14 1
Rock 2 0 2 14 15 14 2
Rock 1 1 1 15 1 15 2
Fossil 6 4 -1 11 5 -1 3
Fossil -1 4 2 -1 4 2 3
Fossil 17 4 5 17 5 5 3
Fossil 17 4 8 17 5 8 3
Fossil 17 4 11 17 5 11 3
Fossil 17 4 14 17 5 14 3
Fossil 4 5 -1 4 12 -1 3
Fossil 5 5 -1 5 5 -1 3
Fossil 12 5 -1 13 5 -1 3
Fossil -1 5 3 -1 6 4 3
Fossil 2 6 -1 3 10 -1 3
Fossil 17 6 4 17 11 4 3
Fossil 17 6 7 17 11 7 3
Fossil 17 6 10 17 11 10 3
Fossil 17 6 13 17 11 13 3
Fossil 5 7 -1 6 8 -1 3
Fossil 8 7 -1 8 12 -1 3
Fossil 10 7 -1 10 11 -1 3
Fossil 12 7 -1 12 10 -1 3
Fossil 14 7 -1 14 9 -1 3
Fossil -1 7 3 -1 7 3 3
Fossil -1 7 6 -1 8 7 3
Fossil 7 8 -1 7 12 -1 3
Fossil 9 8 -1 9 8 -1 3
Fossil 11 8 -1 11 11 -1 3
Fossil 13 8 -1 13 10 -1 3
Fossil -1 9 6 -1 9 6 3
Fossil -1 9 9 -1 10 10 3
Fossil 17 10 2 17 11 2 3
Fossil 17 10 5 17 11 5 3
Fossil 17 10 8 17 11 8 3
Fossil 17 10 11 17 11 11 3
Fossil -1 10 12 -1 11 14 3
Fossil 17 10 14 17 11 14 3
Fossil 3 11 -1 3 12 -1 3
Fossil 5 11 -1 6 12 -1 3
Fossil 9 11 -1 9 11 -1 3
Fossil -1 11 9 -1 11 9 3
Fossil -1 12 13 -1 12 13 3
Gem1 7 15 6 9 21 8 4
Gem2 13 13 15 14 18 16 4
Gem4 15 13 2 16 18 3 4
Gem3 2 13 15 3 17 16 4
Gem5 0 13 2 1 17 3 4
Glow 7 4 17 7 4 17 5
Glow 8 5 17 8 5 17 5
Glow 9 6 17 9 7 17 5
Glow 8 8 17 8 8 17 5
Glow 7 9 17 7 10 17 5
Glow 8 11 17 8 12 17 5
Gem1 8 22 6 8 22 8 6
Gem1 7 22 7 9 22 7 6
Gem1 8 16 7 8 23 7 6
Gem2 13 19 15 13 19 15 6
Gem3 2 18 15 2 18 15 6
Gem4 15 19 2 15 19 2 6
Gem5 0 18 2 0 18 2 6
]],
	},
	Secret = {
		Voxel = 0.176471,
		Origin = 8.5,
		Bones = {
			Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-6, 0, 0) },
			Gem2 = { Pivot = V(0.971, 1.147, 1.324), Rest = V(30, 0, -30) },
			Gem3 = { Pivot = V(-0.971, 1.147, 1.324), Rest = V(30, 0, 30) },
			Gem4 = { Pivot = V(1.324, 1.147, -0.971), Rest = V(-30, 0, -30) },
			Gem5 = { Pivot = V(-1.324, 1.147, -0.971), Rest = V(-30, 0, 30) },
			Gem6 = { Pivot = V(0.971, 1.5, 0.088), Rest = V(6, 0, -30) },
		},
		Colors = { C(236, 56, 64), C(170, 90, 235), C(80, 200, 90), C(60, 140, 240), C(250, 248, 255), C(255, 170, 40), C(236, 56, 64), C(255, 170, 40), C(60, 140, 240), C(80, 200, 90), C(170, 90, 235), C(242, 116, 121), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241) },
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
Rainbow 2 11 0 14 13 16 4
Rainbow 1 11 1 15 13 15 4
Rainbow 0 11 2 16 13 14 4
Fossil 6 4 -1 11 5 -1 5
Fossil -1 4 2 -1 4 2 5
Fossil 17 4 5 17 5 5 5
Fossil 17 4 8 17 5 8 5
Fossil 17 4 11 17 5 11 5
Fossil 17 4 14 17 5 14 5
Fossil 4 5 -1 4 12 -1 5
Fossil 5 5 -1 5 5 -1 5
Fossil 12 5 -1 13 5 -1 5
Fossil -1 5 3 -1 6 4 5
Fossil 2 6 -1 3 10 -1 5
Fossil 17 6 4 17 11 4 5
Fossil 17 6 7 17 11 7 5
Fossil 17 6 10 17 11 10 5
Fossil 17 6 13 17 11 13 5
Fossil 5 7 -1 6 8 -1 5
Fossil 8 7 -1 8 12 -1 5
Fossil 10 7 -1 10 11 -1 5
Fossil 12 7 -1 12 10 -1 5
Fossil 14 7 -1 14 9 -1 5
Fossil -1 7 3 -1 7 3 5
Fossil -1 7 6 -1 8 7 5
Fossil 7 8 -1 7 12 -1 5
Fossil 9 8 -1 9 8 -1 5
Fossil 11 8 -1 11 11 -1 5
Fossil 13 8 -1 13 10 -1 5
Fossil -1 9 6 -1 9 6 5
Fossil -1 9 9 -1 10 10 5
Fossil 17 10 2 17 11 2 5
Fossil 17 10 5 17 11 5 5
Fossil 17 10 8 17 11 8 5
Fossil 17 10 11 17 11 11 5
Fossil -1 10 12 -1 11 14 5
Fossil 17 10 14 17 11 14 5
Fossil 3 11 -1 3 12 -1 5
Fossil 5 11 -1 6 12 -1 5
Fossil 9 11 -1 9 11 -1 5
Fossil -1 11 9 -1 11 9 5
Fossil -1 12 13 -1 12 13 5
Rainbow 2 4 0 14 6 16 6
Rainbow 1 4 1 15 6 15 6
Rainbow 0 4 2 16 6 14 6
Gem1 7 15 6 9 21 8 7
Gem2 13 13 15 14 18 16 8
Gem4 15 13 2 16 18 3 9
Gem3 2 13 15 3 17 16 10
Gem5 0 13 2 1 17 3 11
Gem6 13 15 8 14 19 9 7
Gem1 8 22 6 8 22 8 12
Gem1 7 22 7 9 22 7 12
Gem1 8 16 7 8 23 7 12
Gem2 13 19 15 13 19 15 13
Gem3 2 18 15 2 18 15 14
Gem4 15 19 2 15 19 2 15
Gem5 0 18 2 0 18 2 16
Gem6 13 20 8 13 20 8 12
]],
	},
}

-- blocs de chaque biome, par rareté
local Zones: { [string]: { [string]: Raw } } = {
	Beach = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {},
			Colors = { C(150, 149, 152), C(238, 228, 200), C(226, 206, 150), C(117, 116, 119), C(240, 140, 80), C(232, 224, 206) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 7 2 4 9 14 12 1
Rock 3 2 5 13 14 11 1
Rock 5 3 4 6 13 12 1
Rock 10 3 4 11 13 12 1
Rock 2 3 5 2 13 11 1
Rock 14 3 5 14 13 11 1
Rock 4 4 4 4 12 12 1
Rock 12 4 4 12 12 12 1
Rock 1 4 5 1 12 11 1
Rock 15 4 5 15 12 11 1
Rock 3 5 4 3 11 12 1
Rock 13 5 4 13 11 12 1
Rock 0 6 5 0 10 11 1
Rock 16 6 5 16 10 11 1
Rock 2 7 4 2 9 12 1
Rock 14 7 4 14 9 12 1
Rock 4 15 5 12 15 11 1
Rock 6 16 5 10 16 11 1
Fossil 6 3 3 11 3 3 2
Fossil 4 4 3 6 4 3 2
Fossil 11 4 3 12 4 3 2
Fossil 4 5 3 4 6 3 2
Fossil 7 5 3 10 5 3 2
Fossil 12 5 3 13 5 3 2
Fossil 3 6 3 3 9 3 2
Fossil 6 6 3 6 9 3 2
Fossil 7 6 3 7 6 3 2
Fossil 10 6 3 11 6 3 2
Fossil 13 6 3 13 6 3 2
Fossil 14 6 4 14 6 4 2
Fossil 11 7 3 11 11 3 2
Fossil 14 7 3 14 9 3 2
Fossil 4 9 3 4 11 3 2
Fossil 7 9 3 9 9 3 2
Fossil 14 10 4 14 11 4 2
Fossil 5 11 3 6 11 3 2
Fossil 10 11 3 10 12 3 2
Fossil 13 11 3 13 11 3 2
Fossil 6 12 3 9 12 3 2
Fossil 13 12 4 13 12 4 2
Biome 6 0 3 10 0 4 3
Biome 5 0 4 5 0 12 3
Biome 11 0 4 11 0 12 3
Biome 4 0 5 4 0 11 3
Biome 12 0 5 12 0 11 3
Biome 6 0 12 10 0 13 3
Biome 7 1 4 9 1 4 3
Biome 7 1 12 9 1 12 3
Rock 6 0 5 10 1 11 4
Rock 4 1 5 5 1 11 4
Rock 11 1 5 12 1 11 4
Biome 6 3 13 6 4 13 5
Biome 10 3 13 10 4 13 5
Biome 7 4 13 7 7 13 5
Biome 9 4 13 9 7 13 5
Biome 8 5 13 8 9 13 5
Biome 6 6 13 6 7 13 5
Biome 10 6 13 10 7 13 5
Biome 5 7 13 5 7 13 5
Biome 11 7 13 11 7 13 5
Biome 4 2 3 4 2 3 6
Biome 12 2 13 12 2 13 6
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(-0.088, 1.5, -0.265), Rest = V(-7.1, 0, 2.6) },
				Gem2 = { Pivot = V(1.147, 0.794, 0.441), Rest = V(16.9, 0, -30) },
			},
			Colors = { C(66, 160, 66), C(238, 228, 200), C(226, 206, 150), C(51, 125, 51), C(150, 226, 108), C(240, 140, 80), C(232, 224, 206), C(182, 235, 152) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 7 2 4 9 14 12 1
Rock 3 2 5 13 14 11 1
Rock 5 3 4 6 13 12 1
Rock 10 3 4 11 13 12 1
Rock 2 3 5 2 13 11 1
Rock 14 3 5 14 13 11 1
Rock 4 4 4 4 12 12 1
Rock 12 4 4 12 12 12 1
Rock 1 4 5 1 12 11 1
Rock 15 4 5 15 12 11 1
Rock 3 5 4 3 11 12 1
Rock 13 5 4 13 11 12 1
Rock 0 6 5 0 10 11 1
Rock 16 6 5 16 10 11 1
Rock 2 7 4 2 9 12 1
Rock 14 7 4 14 9 12 1
Rock 4 15 5 12 15 11 1
Rock 6 16 5 10 16 11 1
Fossil 6 3 3 11 3 3 2
Fossil 4 4 3 6 4 3 2
Fossil 11 4 3 12 4 3 2
Fossil 4 5 3 4 6 3 2
Fossil 7 5 3 10 5 3 2
Fossil 12 5 3 13 5 3 2
Fossil 3 6 3 3 9 3 2
Fossil 6 6 3 6 9 3 2
Fossil 7 6 3 7 6 3 2
Fossil 10 6 3 11 6 3 2
Fossil 13 6 3 13 6 3 2
Fossil 14 6 4 14 6 4 2
Fossil 11 7 3 11 11 3 2
Fossil 14 7 3 14 9 3 2
Fossil 4 9 3 4 11 3 2
Fossil 7 9 3 9 9 3 2
Fossil 14 10 4 14 11 4 2
Fossil 5 11 3 6 11 3 2
Fossil 10 11 3 10 12 3 2
Fossil 13 11 3 13 11 3 2
Fossil 6 12 3 9 12 3 2
Fossil 13 12 4 13 12 4 2
Biome 6 0 3 10 0 4 3
Biome 5 0 4 5 0 12 3
Biome 11 0 4 11 0 12 3
Biome 4 0 5 4 0 11 3
Biome 12 0 5 12 0 11 3
Biome 6 0 12 10 0 13 3
Biome 7 1 4 9 1 4 3
Biome 7 1 12 9 1 12 3
Rock 6 0 5 10 1 11 4
Rock 4 1 5 5 1 11 4
Rock 11 1 5 12 1 11 4
Gem1 7 15 6 8 20 7 5
Biome 6 3 13 6 4 13 6
Biome 10 3 13 10 4 13 6
Biome 7 4 13 7 7 13 6
Biome 9 4 13 9 7 13 6
Biome 8 5 13 8 9 13 6
Biome 6 6 13 6 7 13 6
Biome 10 6 13 10 7 13 6
Biome 5 7 13 5 7 13 6
Biome 11 7 13 11 7 13 6
Gem2 14 11 10 15 15 11 5
Biome 4 2 3 4 2 3 7
Biome 12 2 13 12 2 13 7
Gem1 7 21 6 7 21 6 8
Gem2 14 16 10 14 16 10 8
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-7.1, 0, 2.6) },
				Gem2 = { Pivot = V(1.147, 0.794, 0.441), Rest = V(16.9, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.265, 0.618), Rest = V(22.9, 0, 30) },
			},
			Colors = { C(32, 102, 204), C(238, 228, 200), C(226, 206, 150), C(25, 80, 159), C(120, 200, 255), C(240, 140, 80), C(160, 216, 255), C(232, 224, 206) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Glass", "Plastic" },
			Boxes = [[
Rock 7 2 4 9 14 12 1
Rock 3 2 5 13 14 11 1
Rock 5 3 4 6 13 12 1
Rock 10 3 4 11 13 12 1
Rock 2 3 5 2 13 11 1
Rock 14 3 5 14 13 11 1
Rock 4 4 4 4 12 12 1
Rock 12 4 4 12 12 12 1
Rock 1 4 5 1 12 11 1
Rock 15 4 5 15 12 11 1
Rock 3 5 4 3 11 12 1
Rock 13 5 4 13 11 12 1
Rock 0 6 5 0 10 11 1
Rock 16 6 5 16 10 11 1
Rock 2 7 4 2 9 12 1
Rock 14 7 4 14 9 12 1
Rock 4 15 5 12 15 11 1
Rock 6 16 5 10 16 11 1
Fossil 6 3 3 11 3 3 2
Fossil 4 4 3 6 4 3 2
Fossil 11 4 3 12 4 3 2
Fossil 4 5 3 4 6 3 2
Fossil 7 5 3 10 5 3 2
Fossil 12 5 3 13 5 3 2
Fossil 3 6 3 3 9 3 2
Fossil 6 6 3 6 9 3 2
Fossil 7 6 3 7 6 3 2
Fossil 10 6 3 11 6 3 2
Fossil 13 6 3 13 6 3 2
Fossil 14 6 4 14 6 4 2
Fossil 11 7 3 11 11 3 2
Fossil 14 7 3 14 9 3 2
Fossil 4 9 3 4 11 3 2
Fossil 7 9 3 9 9 3 2
Fossil 14 10 4 14 11 4 2
Fossil 5 11 3 6 11 3 2
Fossil 10 11 3 10 12 3 2
Fossil 13 11 3 13 11 3 2
Fossil 6 12 3 9 12 3 2
Fossil 13 12 4 13 12 4 2
Biome 6 0 3 10 0 4 3
Biome 5 0 4 5 0 12 3
Biome 11 0 4 11 0 12 3
Biome 4 0 5 4 0 11 3
Biome 12 0 5 12 0 11 3
Biome 6 0 12 10 0 13 3
Biome 7 1 4 9 1 4 3
Biome 7 1 12 9 1 12 3
Rock 6 0 5 10 1 11 4
Rock 4 1 5 5 1 11 4
Rock 11 1 5 12 1 11 4
Gem1 7 15 6 9 21 8 5
Gem2 14 11 10 15 16 11 5
Biome 6 3 13 6 4 13 6
Biome 10 3 13 10 4 13 6
Biome 7 4 13 7 7 13 6
Biome 9 4 13 9 7 13 6
Biome 8 5 13 8 9 13 6
Biome 6 6 13 6 7 13 6
Biome 10 6 13 10 7 13 6
Biome 5 7 13 5 7 13 6
Biome 11 7 13 11 7 13 6
Gem3 2 8 11 3 12 12 5
Gem1 8 22 6 8 22 8 7
Gem1 7 22 7 9 22 7 7
Gem1 8 16 7 8 23 7 7
Biome 4 2 3 4 2 3 8
Biome 12 2 13 12 2 13 8
Gem2 14 17 10 14 17 10 7
Gem3 2 13 11 2 13 11 7
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 0.794, -0.176), Rest = V(-6.6, 0, 2.7) },
				Gem2 = { Pivot = V(1.324, 0.441, 0.441), Rest = V(17.4, 0, -30) },
				Gem3 = { Pivot = V(-1.147, 0.794, 0.441), Rest = V(17.4, 0, 30) },
				Gem4 = { Pivot = V(0.265, 0.794, 0.618), Rest = V(23.4, 0, -9.3) },
			},
			Colors = { C(124, 54, 192), C(238, 228, 200), C(226, 206, 150), C(97, 42, 150), C(190, 120, 255), C(214, 150, 255), C(240, 140, 80), C(210, 160, 255), C(232, 224, 206) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Neon", "Plastic", "Glass", "Plastic" },
			Boxes = [[
Rock 7 2 4 9 11 12 1
Rock 3 2 5 5 14 11 1
Rock 6 2 5 13 11 11 1
Rock 5 3 4 6 12 12 1
Rock 10 3 4 11 12 12 1
Rock 2 3 5 2 13 11 1
Rock 14 3 5 14 13 11 1
Rock 4 4 4 4 12 12 1
Rock 12 4 4 12 12 12 1
Rock 1 4 5 1 12 11 1
Rock 15 4 5 15 12 11 1
Rock 3 5 4 3 11 12 1
Rock 13 5 4 13 11 12 1
Rock 0 6 5 0 10 11 1
Rock 16 6 5 16 10 11 1
Rock 2 7 4 2 9 12 1
Rock 14 7 4 14 9 12 1
Rock 11 5 5 13 14 11 1
Rock 5 13 4 5 13 12 1
Rock 11 13 4 11 13 12 1
Rock 4 15 5 5 15 11 1
Rock 11 15 5 12 15 11 1
Fossil 6 3 3 11 3 3 2
Fossil 4 4 3 6 4 3 2
Fossil 11 4 3 12 4 3 2
Fossil 4 5 3 4 6 3 2
Fossil 7 5 3 10 5 3 2
Fossil 12 5 3 13 5 3 2
Fossil 3 6 3 3 9 3 2
Fossil 6 6 3 6 9 3 2
Fossil 7 6 3 7 6 3 2
Fossil 10 6 3 11 6 3 2
Fossil 13 6 3 13 6 3 2
Fossil 14 6 4 14 6 4 2
Fossil 11 7 3 11 11 3 2
Fossil 14 7 3 14 9 3 2
Fossil 4 9 3 4 11 3 2
Fossil 7 9 3 9 9 3 2
Fossil 14 10 4 14 11 4 2
Fossil 5 11 3 6 11 3 2
Fossil 10 11 3 10 12 3 2
Fossil 13 11 3 13 11 3 2
Fossil 6 12 3 9 12 3 2
Fossil 13 12 4 13 12 4 2
Biome 6 0 3 10 0 4 3
Biome 5 0 4 5 0 12 3
Biome 11 0 4 11 0 12 3
Biome 4 0 5 4 0 11 3
Biome 12 0 5 12 0 11 3
Biome 6 0 12 10 0 13 3
Biome 7 1 4 9 1 4 3
Biome 7 1 12 9 1 12 3
Rock 6 0 5 10 1 11 4
Rock 4 1 5 5 1 11 4
Rock 11 1 5 12 1 11 4
Gem1 7 11 6 9 17 8 5
Glow 7 12 4 9 12 12 6
Glow 6 13 4 6 13 12 6
Glow 10 13 4 10 13 12 6
Gem2 15 9 10 16 14 11 5
Gem4 9 11 11 10 16 12 5
Biome 6 3 13 6 4 13 7
Biome 10 3 13 10 4 13 7
Biome 7 4 13 7 7 13 7
Biome 9 4 13 9 7 13 7
Biome 8 5 13 8 9 13 7
Biome 6 6 13 6 7 13 7
Biome 10 6 13 10 7 13 7
Biome 5 7 13 5 7 13 7
Biome 11 7 13 11 7 13 7
Gem3 1 11 10 2 15 11 5
Gem1 8 18 6 8 18 8 8
Gem1 7 18 7 9 18 7 8
Gem1 8 12 7 8 19 7 8
Biome 4 2 3 4 2 3 9
Biome 12 2 13 12 2 13 9
Gem2 15 15 10 15 15 10 8
Gem3 1 16 10 1 16 10 8
Gem4 9 17 11 9 17 11 8
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.676, -0.176), Rest = V(-7.1, 0, 2.6) },
				Gem2 = { Pivot = V(1.147, 0.971, 0.441), Rest = V(16.9, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.441, 0.618), Rest = V(22.9, 0, 30) },
				Gem4 = { Pivot = V(0.794, 1.324, -0.441), Rest = V(-13.1, 0, -27.4) },
				Gem5 = { Pivot = V(0.088, 1.324, 0.618), Rest = V(22.9, 0, -3.4) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(255, 196, 30), C(226, 206, 150), C(240, 140, 80), C(176, 87, 9), C(255, 214, 98), C(232, 224, 206) },
			Materials = { "Plastic", "Foil", "Neon", "Plastic", "Plastic", "Plastic", "Neon", "Plastic" },
			Boxes = [[
Rock 7 3 4 9 15 12 1
Rock 3 3 5 13 15 11 1
Rock 5 4 4 6 14 12 1
Rock 10 4 4 11 14 12 1
Rock 2 4 5 2 14 11 1
Rock 14 4 5 14 14 11 1
Rock 4 5 4 4 13 12 1
Rock 12 5 4 12 13 12 1
Rock 1 5 5 1 13 11 1
Rock 15 5 5 15 13 11 1
Rock 3 6 4 3 12 12 1
Rock 13 6 4 13 12 12 1
Rock 0 7 5 0 11 11 1
Rock 16 7 5 16 11 11 1
Rock 2 8 4 2 10 12 1
Rock 14 8 4 14 10 12 1
Rock 4 16 5 12 16 11 1
Rock 6 17 5 10 17 11 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Fossil 6 4 3 11 4 3 2
Fossil 4 5 3 6 5 3 2
Fossil 11 5 3 12 5 3 2
Fossil 4 6 3 4 7 3 2
Fossil 7 6 3 10 6 3 2
Fossil 12 6 3 13 6 3 2
Fossil 3 7 3 3 10 3 2
Fossil 6 7 3 6 10 3 2
Fossil 7 7 3 7 7 3 2
Fossil 10 7 3 11 7 3 2
Fossil 13 7 3 13 7 3 2
Fossil 14 7 4 14 7 4 2
Fossil 11 8 3 11 12 3 2
Fossil 14 8 3 14 10 3 2
Fossil 4 10 3 4 12 3 2
Fossil 7 10 3 9 10 3 2
Fossil 14 11 4 14 12 4 2
Fossil 5 12 3 6 12 3 2
Fossil 10 12 3 10 13 3 2
Fossil 13 12 3 13 12 3 2
Fossil 6 13 3 9 13 3 2
Fossil 13 13 4 13 13 4 2
Gem1 7 16 6 9 22 8 3
Biome 6 1 3 10 1 4 4
Biome 5 1 4 5 1 12 4
Biome 11 1 4 11 1 12 4
Biome 4 1 5 5 1 11 4
Biome 11 1 5 12 1 11 4
Biome 6 1 12 10 1 13 4
Biome 7 1 4 9 2 4 4
Biome 7 1 12 9 2 12 4
Gem2 14 12 10 15 17 11 3
Gem4 12 14 5 13 19 6 3
Biome 6 4 13 6 5 13 5
Biome 10 4 13 10 5 13 5
Biome 7 5 13 7 8 13 5
Biome 9 5 13 9 8 13 5
Biome 8 6 13 8 10 13 5
Biome 6 7 13 6 8 13 5
Biome 10 7 13 10 8 13 5
Biome 5 8 13 5 8 13 5
Biome 11 8 13 11 8 13 5
Rock 4 2 5 12 2 11 6
Gem3 2 9 11 3 13 12 3
Gem5 8 14 11 9 18 12 3
Gem1 8 23 6 8 23 8 7
Gem1 7 23 7 9 23 7 7
Gem1 8 17 7 8 24 7 7
Biome 4 3 3 4 3 3 8
Biome 12 3 13 12 3 13 8
Gem2 14 18 10 14 18 10 7
Gem3 2 14 11 2 14 11 7
Gem4 12 20 5 12 20 5 7
Gem5 8 19 11 8 19 11 7
Rock 6 1 5 10 1 11 1
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.5, -0.176), Rest = V(-7.1, 0, 2.6) },
				Gem2 = { Pivot = V(1.147, 0.794, 0.441), Rest = V(16.9, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.265, 0.618), Rest = V(22.9, 0, 30) },
				Gem4 = { Pivot = V(0.265, 0.971, 0.618), Rest = V(22.9, 0, -9.4) },
				Gem5 = { Pivot = V(0.971, 0.971, -0.441), Rest = V(-13.1, 0, -30) },
				Float1 = { Pivot = V(-1.676, 1.147, -0.265), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.5, 1.5, -0.088), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 2.206, 0.265), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(238, 228, 200), C(226, 206, 150), C(117, 17, 20), C(255, 74, 30), C(240, 140, 80), C(255, 106, 30), C(255, 128, 98), C(232, 224, 206) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Plastic" },
			Boxes = [[
Rock 7 2 4 9 14 12 1
Rock 3 2 5 13 14 11 1
Rock 5 3 4 6 13 12 1
Rock 10 3 4 11 13 12 1
Rock 2 3 5 2 13 11 1
Rock 14 3 5 14 13 11 1
Rock 4 4 4 4 12 12 1
Rock 12 4 4 12 12 12 1
Rock 1 4 5 1 12 11 1
Rock 15 4 5 15 12 11 1
Rock 3 5 4 3 11 12 1
Rock 13 5 4 13 11 12 1
Rock 0 6 5 0 10 11 1
Rock 16 6 5 16 10 11 1
Rock 2 7 4 2 9 12 1
Rock 14 7 4 14 9 12 1
Rock 4 15 5 12 15 11 1
Rock 6 16 5 10 16 11 1
Fossil 6 3 3 11 3 3 2
Fossil 4 4 3 6 4 3 2
Fossil 11 4 3 12 4 3 2
Fossil 4 5 3 4 6 3 2
Fossil 7 5 3 10 5 3 2
Fossil 12 5 3 13 5 3 2
Fossil 3 6 3 3 9 3 2
Fossil 6 6 3 6 9 3 2
Fossil 7 6 3 7 6 3 2
Fossil 10 6 3 11 6 3 2
Fossil 13 6 3 13 6 3 2
Fossil 14 6 4 14 6 4 2
Fossil 11 7 3 11 11 3 2
Fossil 14 7 3 14 9 3 2
Fossil 4 9 3 4 11 3 2
Fossil 7 9 3 9 9 3 2
Fossil 14 10 4 14 11 4 2
Fossil 5 11 3 6 11 3 2
Fossil 10 11 3 10 12 3 2
Fossil 13 11 3 13 11 3 2
Fossil 6 12 3 9 12 3 2
Fossil 13 12 4 13 12 4 2
Biome 6 0 3 10 0 4 3
Biome 5 0 4 5 0 12 3
Biome 11 0 4 11 0 12 3
Biome 4 0 5 4 0 11 3
Biome 12 0 5 12 0 11 3
Biome 6 0 12 10 0 13 3
Biome 7 1 4 9 1 4 3
Biome 7 1 12 9 1 12 3
Rock 6 0 5 10 1 11 4
Rock 4 1 5 5 1 11 4
Rock 11 1 5 12 1 11 4
Gem1 7 15 6 9 21 8 5
Gem2 14 11 10 15 16 11 5
Gem4 9 12 11 10 17 12 5
Biome 6 3 13 6 4 13 6
Biome 10 3 13 10 4 13 6
Biome 7 4 13 7 7 13 6
Biome 9 4 13 9 7 13 6
Biome 8 5 13 8 9 13 6
Biome 6 6 13 6 7 13 6
Biome 10 6 13 10 7 13 6
Biome 5 7 13 5 7 13 6
Biome 11 7 13 11 7 13 6
Gem3 2 8 11 3 12 12 5
Gem5 13 12 5 14 16 6 5
Glow 15 3 9 15 3 9 7
Glow 16 4 8 16 4 8 7
Glow 0 5 7 0 5 7 7
Glow 16 5 7 16 5 7 7
Glow 17 6 7 17 6 7 7
Glow -1 6 8 -1 6 8 7
Glow 17 7 8 17 7 8 7
Glow -1 7 9 -1 8 9 7
Glow 17 8 9 17 9 9 7
Glow -1 9 8 -1 9 8 7
Glow -1 10 7 -1 10 7 7
Glow 17 10 8 17 10 8 7
Glow 0 11 7 0 11 7 7
Glow 16 11 8 16 11 8 7
Glow 0 12 8 0 12 8 7
Glow 1 13 8 1 13 8 7
Float1 -2 14 6 -1 15 7 1
Float2 16 16 7 17 17 8 1
Float3 10 20 9 11 21 10 1
Gem1 8 22 6 8 22 8 8
Gem1 7 22 7 9 22 7 8
Gem1 8 16 7 8 23 7 8
Biome 4 2 3 4 2 3 9
Biome 12 2 13 12 2 13 9
Gem2 14 17 10 14 17 10 8
Gem3 2 13 11 2 13 11 8
Gem4 9 18 11 9 18 11 8
Gem5 13 17 5 13 17 5 8
Float1 -1 16 7 -1 16 7 7
Float2 17 18 8 17 18 8 7
Float3 11 22 10 11 22 10 7
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 2.206, -0.176), Rest = V(-7.1, 0, 2.6) },
				Gem2 = { Pivot = V(1.147, 1.5, 0.441), Rest = V(16.9, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.971, 0.618), Rest = V(22.9, 0, 30) },
				Gem4 = { Pivot = V(0.088, 1.853, 0.618), Rest = V(22.9, 0, -3.4) },
				Gem5 = { Pivot = V(-0.971, 1.676, -0.441), Rest = V(-13.1, 0, 30) },
				Gem6 = { Pivot = V(0.971, 1.676, -0.441), Rest = V(-13.1, 0, -30) },
				Orbit1 = { Pivot = V(1.235, 0.529, 1.235), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.235, 0.882, 1.235), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.235, 0.529, -1.235), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.235, 0.882, -1.235), Rest = V(10, 0, 15) },
			},
			Colors = { C(80, 200, 90), C(236, 56, 64), C(170, 90, 235), C(60, 140, 240), C(255, 170, 40), C(250, 248, 255), C(236, 56, 64), C(64, 58, 72), C(255, 170, 40), C(60, 140, 240), C(240, 140, 80), C(80, 200, 90), C(170, 90, 235), C(78, 70, 90), C(242, 116, 121), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Foil", "Neon", "Plastic", "Neon", "Neon", "Plastic", "Neon", "Neon", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 2 11 4 14 13 12 1
Rainbow 0 11 5 16 14 11 1
Rainbow 3 14 4 13 14 12 1
Rainbow 6 4 5 10 17 11 2
Rainbow 4 5 5 5 16 11 2
Rainbow 11 5 5 12 16 11 2
Rainbow 7 6 4 9 7 12 2
Rainbow 3 6 5 3 7 11 2
Rainbow 13 6 5 13 7 11 2
Rainbow 5 7 4 11 7 11 2
Rainbow 2 7 5 2 7 11 2
Rainbow 14 7 5 14 7 11 2
Rainbow 5 7 5 6 7 12 2
Rainbow 10 7 5 11 7 12 2
Rainbow 7 18 4 9 18 12 3
Rainbow 3 18 5 13 18 11 3
Rainbow 4 19 5 12 19 11 3
Rainbow 6 20 5 10 20 11 3
Rainbow 3 15 4 13 15 12 4
Rainbow 1 15 5 15 16 11 4
Rainbow 4 16 4 12 16 12 4
Rainbow 5 17 4 11 17 12 4
Rainbow 2 17 5 14 17 11 4
Rainbow 4 8 4 12 10 12 5
Rainbow 1 8 5 15 10 11 5
Rainbow 3 9 4 3 10 12 5
Rainbow 13 9 4 13 10 12 5
Rainbow 0 10 5 0 10 11 5
Rainbow 16 10 5 16 10 11 5
Fossil 6 7 3 11 7 3 6
Fossil 4 8 3 6 8 3 6
Fossil 11 8 3 12 8 3 6
Fossil 4 9 3 4 10 3 6
Fossil 7 9 3 10 9 3 6
Fossil 12 9 3 13 9 3 6
Fossil 3 10 3 3 13 3 6
Fossil 6 10 3 6 13 3 6
Fossil 7 10 3 7 10 3 6
Fossil 10 10 3 11 10 3 6
Fossil 13 10 3 13 10 3 6
Fossil 14 10 4 14 10 4 6
Fossil 11 11 3 11 15 3 6
Fossil 14 11 3 14 13 3 6
Fossil 4 13 3 4 15 3 6
Fossil 7 13 3 9 13 3 6
Fossil 14 14 4 14 15 4 6
Fossil 5 15 3 6 15 3 6
Fossil 10 15 3 10 16 3 6
Fossil 13 15 3 13 15 3 6
Fossil 6 16 3 9 16 3 6
Fossil 13 16 4 13 16 4 6
Gem1 7 19 6 9 25 8 7
Base 11 0 3 12 0 4 8
Base 3 0 4 5 0 6 8
Base 8 0 7 9 0 9 8
Base 12 0 11 14 0 12 8
Base 5 0 12 6 0 13 8
Gem2 14 15 10 15 20 11 9
Gem4 8 17 11 9 22 12 10
Biome 6 7 13 6 8 13 11
Biome 10 7 13 10 8 13 11
Biome 7 8 13 7 11 13 11
Biome 9 8 13 9 11 13 11
Biome 8 9 13 8 13 13 11
Biome 6 10 13 6 11 13 11
Biome 10 10 13 10 11 13 11
Biome 5 11 13 5 11 13 11
Biome 11 11 13 11 11 13 11
Gem3 2 12 11 3 16 12 12
Gem5 2 16 5 3 20 6 13
Gem6 13 16 5 14 20 6 7
Base 3 1 4 5 1 6 14
Base 12 1 11 14 1 12 14
Gem1 8 26 6 8 26 8 15
Gem1 7 26 7 9 26 7 15
Gem1 8 20 7 8 27 7 15
Orbit1 15 10 15 15 12 15 9
Orbit2 1 12 15 1 14 15 12
Orbit3 1 10 1 1 12 1 10
Orbit4 15 12 1 15 14 1 13
Gem2 14 21 10 14 21 10 16
Gem3 2 17 11 2 17 11 17
Gem4 8 23 11 8 23 11 18
Gem5 2 21 5 2 21 5 19
Gem6 13 21 5 13 21 5 15
Orbit1 15 13 15 15 13 15 20
Orbit2 1 15 15 1 15 15 21
Orbit3 1 13 1 1 13 1 22
Orbit4 15 15 1 15 15 1 23
]],
		},
	},
	["Fern Forest"] = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 0.794, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 0.794, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 0.794, 0.529), Rest = V(-6, 0, -30) },
			},
			Colors = { C(150, 149, 152), C(117, 116, 119), C(108, 107, 109), C(167, 166, 168), C(138, 137, 140), C(238, 228, 200), C(86, 150, 60), C(70, 150, 56), C(104, 186, 78) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 1 4 2 1 1
Rock 5 2 2 11 8 14 1
Rock 4 2 3 12 8 13 1
Rock 3 2 4 13 8 12 1
Rock 2 2 5 14 8 11 1
Rock 3 1 7 15 3 8 1
Rock 1 1 8 13 3 9 1
Rock 10 1 15 11 3 15 1
Rock 4 10 3 4 10 3 1
Rock 13 10 4 13 11 4 1
Rock 2 10 6 2 11 6 1
Rock 14 10 10 14 10 10 1
Rock 5 1 13 5 10 13 1
Rock 9 10 14 9 11 14 1
Rock 3 0 0 5 1 1 2
Rock 5 0 2 11 1 14 2
Rock 4 0 3 4 1 13 2
Rock 12 0 3 12 1 13 2
Rock 3 0 4 3 1 12 2
Rock 13 0 4 13 1 12 2
Rock 2 0 5 2 1 11 2
Rock 14 0 5 14 1 11 2
Rock 15 0 6 16 1 9 2
Rock 0 0 7 1 1 10 2
Rock 9 0 15 12 1 16 2
Rock 5 9 2 11 9 3 3
Rock 4 9 3 4 9 3 3
Rock 10 8 3 12 9 4 3
Rock 3 9 4 3 9 12 3
Rock 13 9 4 13 9 12 3
Rock 2 9 5 2 9 11 3
Rock 14 9 5 14 9 11 3
Rock 4 9 13 12 9 13 3
Rock 5 9 14 11 9 14 3
Rock 4 1 4 5 9 12 4
Rock 6 1 4 12 9 5 4
Rock 11 1 6 12 9 12 4
Rock 8 1 8 8 9 8 4
Rock 6 1 11 10 9 12 4
Rock 6 1 6 10 9 7 5
Rock 6 1 8 7 9 10 5
Rock 9 1 8 10 9 10 5
Rock 8 1 9 8 9 10 5
Fossil 8 1 1 8 9 1 6
Fossil 6 3 1 6 3 1 6
Fossil 10 3 1 10 3 1 6
Fossil 5 4 1 5 4 1 6
Fossil 11 4 1 11 4 1 6
Fossil 6 5 1 6 5 1 6
Fossil 10 5 1 10 5 1 6
Fossil 5 6 1 5 6 1 6
Fossil 11 6 1 11 6 1 6
Fossil 6 7 1 6 7 1 6
Fossil 10 7 1 10 7 1 6
Fossil 7 8 1 7 8 1 6
Fossil 9 8 1 9 8 1 6
Biome 12 7 2 12 8 2 7
Biome 10 8 1 11 8 1 7
Biome 13 8 3 13 8 3 7
Biome 10 10 3 12 10 4 7
Biome 12 10 5 13 10 6 7
Deco1 8 10 11 8 15 11 8
Deco2 7 10 11 7 15 11 8
Deco3 9 10 11 9 15 11 8
Deco1 8 16 11 8 16 11 9
Deco2 7 16 11 7 16 11 9
Deco3 9 16 11 9 16 11 9
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 0.794, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 0.794, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 0.794, 0.529), Rest = V(-6, 0, -30) },
				Gem1 = { Pivot = V(-0.088, 0.265, -0.265), Rest = V(-6.6, 0, 1.1) },
				Gem2 = { Pivot = V(0.441, -0.794, 1.147), Rest = V(30, 0, -16.9) },
			},
			Colors = { C(66, 160, 66), C(51, 125, 51), C(48, 115, 48), C(96, 175, 96), C(61, 147, 61), C(150, 226, 108), C(238, 228, 200), C(86, 150, 60), C(70, 150, 56), C(104, 186, 78), C(182, 235, 152) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 1 4 2 1 1
Rock 5 2 2 11 8 14 1
Rock 4 2 3 12 8 13 1
Rock 3 2 4 13 8 12 1
Rock 2 2 5 14 8 11 1
Rock 3 1 7 15 3 8 1
Rock 1 1 8 13 3 9 1
Rock 10 1 15 11 3 15 1
Rock 4 10 3 4 10 3 1
Rock 13 10 4 13 11 4 1
Rock 2 10 6 2 11 6 1
Rock 14 10 10 14 10 10 1
Rock 5 1 13 5 10 13 1
Rock 9 10 14 9 11 14 1
Rock 3 0 0 5 1 1 2
Rock 5 0 2 11 1 14 2
Rock 4 0 3 4 1 13 2
Rock 12 0 3 12 1 13 2
Rock 3 0 4 3 1 12 2
Rock 13 0 4 13 1 12 2
Rock 2 0 5 2 1 11 2
Rock 14 0 5 14 1 11 2
Rock 15 0 6 16 1 9 2
Rock 0 0 7 1 1 10 2
Rock 9 0 15 12 1 16 2
Rock 5 9 2 11 9 3 3
Rock 4 9 3 4 9 3 3
Rock 10 8 3 12 9 4 3
Rock 3 9 4 3 9 12 3
Rock 13 9 4 13 9 12 3
Rock 2 9 5 2 9 11 3
Rock 14 9 5 14 9 11 3
Rock 4 9 13 12 9 13 3
Rock 5 9 14 11 9 14 3
Rock 4 1 4 5 9 12 4
Rock 6 1 4 12 9 5 4
Rock 11 1 6 12 9 12 4
Rock 8 1 8 8 9 8 4
Rock 6 1 11 10 9 12 4
Rock 6 1 6 10 9 7 5
Rock 6 1 8 7 9 10 5
Rock 9 1 8 10 9 10 5
Rock 8 1 9 8 9 10 5
Gem1 7 8 6 8 13 7 6
Fossil 8 1 1 8 9 1 7
Fossil 6 3 1 6 3 1 7
Fossil 10 3 1 10 3 1 7
Fossil 5 4 1 5 4 1 7
Fossil 11 4 1 11 4 1 7
Fossil 6 5 1 6 5 1 7
Fossil 10 5 1 10 5 1 7
Fossil 5 6 1 5 6 1 7
Fossil 11 6 1 11 6 1 7
Fossil 6 7 1 6 7 1 7
Fossil 10 7 1 10 7 1 7
Fossil 7 8 1 7 8 1 7
Fossil 9 8 1 9 8 1 7
Gem2 10 2 14 11 6 15 6
Biome 12 7 2 12 8 2 8
Biome 10 8 1 11 8 1 8
Biome 13 8 3 13 8 3 8
Biome 10 10 3 12 10 4 8
Biome 12 10 5 13 10 6 8
Deco1 8 10 11 8 15 11 9
Deco2 7 10 11 7 15 11 9
Deco3 9 10 11 9 15 11 9
Deco1 8 16 11 8 16 11 10
Deco2 7 16 11 7 16 11 10
Deco3 9 16 11 9 16 11 10
Gem1 7 14 6 7 14 6 11
Gem2 10 7 14 10 7 14 11
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 0.794, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 0.794, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 0.794, 0.529), Rest = V(-6, 0, -30) },
				Gem1 = { Pivot = V(0, 0.265, -0.176), Rest = V(-6.6, 0, 1.1) },
				Gem2 = { Pivot = V(0.441, -0.794, 1.147), Rest = V(30, 0, -16.9) },
				Gem3 = { Pivot = V(1.147, -1.147, 0.088), Rest = V(5.4, 0, -30) },
			},
			Colors = { C(32, 102, 204), C(25, 80, 159), C(23, 73, 147), C(120, 200, 255), C(68, 126, 212), C(29, 94, 188), C(238, 228, 200), C(86, 150, 60), C(70, 150, 56), C(160, 216, 255), C(104, 186, 78) },
			Materials = { "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic" },
			Boxes = [[
Rock 4 2 1 4 2 1 1
Rock 5 2 2 11 8 14 1
Rock 4 2 3 12 8 13 1
Rock 3 2 4 13 8 12 1
Rock 2 2 5 14 8 11 1
Rock 3 1 7 15 3 8 1
Rock 1 1 8 13 3 9 1
Rock 10 1 15 11 3 15 1
Rock 4 10 3 4 10 3 1
Rock 13 10 4 13 11 4 1
Rock 2 10 6 2 11 6 1
Rock 14 10 10 14 10 10 1
Rock 5 1 13 5 10 13 1
Rock 9 10 14 9 11 14 1
Rock 3 0 0 5 1 1 2
Rock 5 0 2 11 1 14 2
Rock 4 0 3 4 1 13 2
Rock 12 0 3 12 1 13 2
Rock 3 0 4 3 1 12 2
Rock 13 0 4 13 1 12 2
Rock 2 0 5 2 1 11 2
Rock 14 0 5 14 1 11 2
Rock 15 0 6 16 1 9 2
Rock 0 0 7 1 1 10 2
Rock 9 0 15 12 1 16 2
Rock 5 9 2 11 9 3 3
Rock 4 9 3 4 9 3 3
Rock 10 8 3 12 9 4 3
Rock 3 9 4 3 9 12 3
Rock 13 9 4 13 9 12 3
Rock 2 9 5 2 9 11 3
Rock 14 9 5 14 9 11 3
Rock 4 9 13 12 9 13 3
Rock 5 9 14 11 9 14 3
Gem1 7 8 6 9 14 8 4
Rock 4 1 4 5 9 12 5
Rock 6 1 4 12 9 5 5
Rock 11 1 6 12 9 12 5
Rock 8 1 8 8 9 8 5
Rock 6 1 11 10 9 12 5
Rock 6 1 6 10 9 7 6
Rock 6 1 8 7 9 10 6
Rock 9 1 8 10 9 10 6
Rock 8 1 9 8 9 10 6
Gem2 10 2 14 11 7 15 4
Fossil 8 1 1 8 9 1 7
Fossil 6 3 1 6 3 1 7
Fossil 10 3 1 10 3 1 7
Fossil 5 4 1 5 4 1 7
Fossil 11 4 1 11 4 1 7
Fossil 6 5 1 6 5 1 7
Fossil 10 5 1 10 5 1 7
Fossil 5 6 1 5 6 1 7
Fossil 11 6 1 11 6 1 7
Fossil 6 7 1 6 7 1 7
Fossil 10 7 1 10 7 1 7
Fossil 7 8 1 7 8 1 7
Fossil 9 8 1 9 8 1 7
Gem3 14 0 8 15 4 9 4
Biome 12 7 2 12 8 2 8
Biome 10 8 1 11 8 1 8
Biome 13 8 3 13 8 3 8
Biome 10 10 3 12 10 4 8
Biome 12 10 5 13 10 6 8
Deco1 8 10 11 8 15 11 9
Deco2 7 10 11 7 15 11 9
Deco3 9 10 11 9 15 11 9
Gem1 8 15 6 8 15 8 10
Gem1 7 15 7 9 15 7 10
Gem1 8 9 7 8 16 7 10
Deco1 8 16 11 8 16 11 11
Deco2 7 16 11 7 16 11 11
Deco3 9 16 11 9 16 11 11
Gem2 10 8 14 10 8 14 10
Gem3 14 5 8 14 5 8 10
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 0.794, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 0.794, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 0.794, 0.529), Rest = V(-6, 0, -30) },
				Gem1 = { Pivot = V(-0.176, -0.088, -0.176), Rest = V(-6.3, 0, 6.3) },
				Gem2 = { Pivot = V(0.441, -0.794, 1.147), Rest = V(30, 0, -17.7) },
				Gem3 = { Pivot = V(1.147, -0.794, -0.088), Rest = V(-0.3, 0, -30) },
				Gem4 = { Pivot = V(-0.618, 0.265, 0.794), Rest = V(29.7, 0, 18.3) },
			},
			Colors = { C(124, 54, 192), C(97, 42, 150), C(214, 150, 255), C(190, 120, 255), C(89, 39, 138), C(145, 86, 202), C(238, 228, 200), C(86, 150, 60), C(70, 150, 56), C(210, 160, 255), C(104, 186, 78) },
			Materials = { "Plastic", "Plastic", "Neon", "Glass", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic" },
			Boxes = [[
Rock 4 2 1 4 2 1 1
Rock 5 2 2 11 6 14 1
Rock 4 2 3 12 6 13 1
Rock 3 2 4 13 6 12 1
Rock 2 2 5 14 6 11 1
Rock 3 1 7 15 3 8 1
Rock 1 1 8 13 3 9 1
Rock 10 1 15 11 3 15 1
Rock 5 7 2 5 8 14 1
Rock 10 7 2 11 7 14 1
Rock 4 7 3 5 8 13 1
Rock 11 7 3 12 8 13 1
Rock 3 7 4 5 8 12 1
Rock 11 7 4 13 8 12 1
Rock 2 7 5 5 8 11 1
Rock 11 7 5 14 8 11 1
Rock 6 7 2 6 7 14 1
Rock 11 8 2 11 8 14 1
Rock 4 10 3 4 10 3 1
Rock 13 10 4 13 11 4 1
Rock 2 10 6 2 11 6 1
Rock 14 10 10 14 10 10 1
Rock 5 10 13 5 10 13 1
Rock 3 0 0 5 1 1 2
Rock 5 0 2 11 1 14 2
Rock 4 0 3 4 1 13 2
Rock 12 0 3 12 1 13 2
Rock 3 0 4 3 1 12 2
Rock 13 0 4 13 1 12 2
Rock 2 0 5 2 1 11 2
Rock 14 0 5 14 1 11 2
Rock 15 0 6 16 1 9 2
Rock 0 0 7 1 1 10 2
Rock 9 0 15 12 1 16 2
Glow 7 7 2 9 7 14 3
Glow 6 8 2 6 8 14 3
Glow 10 8 2 10 8 14 3
Gem1 6 6 6 8 12 8 4
Rock 5 9 2 5 9 3 5
Rock 11 8 2 11 9 3 5
Rock 4 9 3 4 9 3 5
Rock 12 8 3 12 9 6 5
Rock 3 9 4 3 9 12 5
Rock 13 9 4 13 9 12 5
Rock 2 9 5 2 9 11 5
Rock 14 9 5 14 9 11 5
Rock 4 9 13 5 9 13 5
Rock 11 9 13 12 9 13 5
Rock 5 9 14 5 9 14 5
Rock 11 9 14 11 9 14 5
Rock 4 1 4 5 9 12 6
Rock 11 1 4 12 9 12 6
Gem2 10 2 14 11 7 15 4
Gem4 4 8 12 5 13 13 4
Gem3 14 2 7 15 6 8 4
Fossil 8 1 1 8 7 1 7
Fossil 6 3 1 6 3 1 7
Fossil 10 3 1 10 3 1 7
Fossil 5 4 1 5 4 1 7
Fossil 11 4 1 11 4 1 7
Fossil 6 5 1 6 5 1 7
Fossil 10 5 1 10 5 1 7
Fossil 5 6 1 5 6 1 7
Fossil 11 6 1 11 6 1 7
Fossil 6 7 1 6 7 1 7
Fossil 10 7 1 10 7 1 7
Biome 12 7 2 12 8 2 8
Biome 10 8 1 11 8 1 8
Biome 13 8 3 13 8 3 8
Biome 11 10 3 12 10 4 8
Biome 12 10 5 13 10 6 8
Deco1 8 10 11 8 15 11 9
Deco2 7 10 11 7 15 11 9
Deco3 9 10 11 9 15 11 9
Gem1 7 13 6 7 13 8 10
Gem1 6 13 7 8 13 7 10
Gem1 7 7 7 7 14 7 10
Deco1 8 16 11 8 16 11 11
Deco2 7 16 11 7 16 11 11
Deco3 9 16 11 9 16 11 11
Gem2 10 8 14 10 8 14 10
Gem3 14 7 7 14 7 7 10
Gem4 4 14 12 4 14 12 10
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 0.971, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 0.971, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 0.971, 0.529), Rest = V(-6, 0, -30) },
				Gem1 = { Pivot = V(0, 0.441, -0.176), Rest = V(-6.6, 0, 1.1) },
				Gem2 = { Pivot = V(0.441, -0.618, 1.147), Rest = V(30, 0, -16.9) },
				Gem3 = { Pivot = V(1.147, -0.971, 0.088), Rest = V(5.4, 0, -30) },
				Gem4 = { Pivot = V(-0.794, 0.441, 0.618), Rest = V(23.4, 0, 25.1) },
				Gem5 = { Pivot = V(-0.971, 0.441, -0.441), Rest = V(-12.6, 0, 30) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(176, 87, 9), C(163, 81, 9), C(255, 196, 30), C(231, 135, 51), C(208, 103, 11), C(86, 150, 60), C(70, 150, 56), C(255, 214, 98), C(104, 186, 78) },
			Materials = { "Plastic", "Foil", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic" },
			Boxes = [[
Rock 4 3 1 4 3 1 1
Rock 5 3 2 11 9 14 1
Rock 4 3 3 12 9 13 1
Rock 3 3 4 13 9 12 1
Rock 2 3 5 14 9 11 1
Rock 3 1 7 15 4 8 1
Rock 1 1 8 13 4 9 1
Rock 10 1 15 11 4 15 1
Rock 4 11 3 4 11 3 1
Rock 13 11 4 13 12 4 1
Rock 2 11 6 2 12 6 1
Rock 14 11 10 14 11 10 1
Rock 5 1 13 5 11 13 1
Rock 9 11 14 9 12 14 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Rock 3 1 0 5 2 1 3
Rock 5 1 2 11 2 14 3
Rock 4 1 3 12 2 13 3
Rock 3 1 4 13 2 12 3
Rock 2 1 5 14 2 11 3
Rock 3 1 6 16 2 9 3
Rock 0 1 7 13 2 10 3
Rock 9 1 15 12 2 16 3
Rock 5 10 2 11 10 3 4
Rock 4 10 3 4 10 3 4
Rock 10 9 3 12 10 4 4
Rock 3 10 4 3 10 12 4
Rock 13 10 4 13 10 12 4
Rock 2 10 5 2 10 11 4
Rock 14 10 5 14 10 11 4
Rock 4 10 13 12 10 13 4
Rock 5 10 14 11 10 14 4
Gem1 7 9 6 9 15 8 5
Rock 4 1 4 5 10 12 6
Rock 6 1 4 12 10 5 6
Rock 11 1 6 12 10 12 6
Rock 8 1 8 8 10 8 6
Rock 6 1 11 10 10 12 6
Rock 6 1 6 10 10 7 7
Rock 6 1 8 7 10 10 7
Rock 9 1 8 10 10 10 7
Rock 8 1 9 8 10 10 7
Gem2 10 3 14 11 8 15 5
Gem4 3 9 11 4 14 12 5
Fossil 8 2 1 8 10 1 2
Fossil 6 4 1 6 4 1 2
Fossil 10 4 1 10 4 1 2
Fossil 5 5 1 5 5 1 2
Fossil 11 5 1 11 5 1 2
Fossil 6 6 1 6 6 1 2
Fossil 10 6 1 10 6 1 2
Fossil 5 7 1 5 7 1 2
Fossil 11 7 1 11 7 1 2
Fossil 6 8 1 6 8 1 2
Fossil 10 8 1 10 8 1 2
Fossil 7 9 1 7 9 1 2
Fossil 9 9 1 9 9 1 2
Gem3 14 1 8 15 5 9 5
Gem5 2 9 5 3 13 6 5
Biome 12 8 2 12 9 2 8
Biome 10 9 1 11 9 1 8
Biome 13 9 3 13 9 3 8
Biome 10 11 3 12 11 4 8
Biome 12 11 5 13 11 6 8
Deco1 8 11 11 8 16 11 9
Deco2 7 11 11 7 16 11 9
Deco3 9 11 11 9 16 11 9
Gem1 8 16 6 8 16 8 10
Gem1 7 16 7 9 16 7 10
Gem1 8 10 7 8 17 7 10
Deco1 8 17 11 8 17 11 11
Deco2 7 17 11 7 17 11 11
Deco3 9 17 11 9 17 11 11
Gem2 10 9 14 10 9 14 10
Gem3 14 6 8 14 6 8 10
Gem4 3 15 11 3 15 11 10
Gem5 2 14 5 2 14 5 10
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 0.794, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 0.794, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 0.794, 0.529), Rest = V(-6, 0, -30) },
				Gem1 = { Pivot = V(0, 0.265, -0.176), Rest = V(-6.6, 0, 1.1) },
				Gem2 = { Pivot = V(0.441, -0.794, 1.147), Rest = V(30, 0, -16.9) },
				Gem3 = { Pivot = V(1.147, -1.147, 0.088), Rest = V(5.4, 0, -30) },
				Gem4 = { Pivot = V(-0.794, 0.265, 0.618), Rest = V(23.4, 0, 25.1) },
				Gem5 = { Pivot = V(-0.971, 0.265, -0.441), Rest = V(-12.6, 0, 30) },
				Float1 = { Pivot = V(-1.676, 0.265, -0.971), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.5, 0.441, 0.618), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 1.147, 0.971), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(117, 17, 20), C(108, 16, 19), C(255, 74, 30), C(167, 59, 63), C(138, 20, 24), C(238, 228, 200), C(255, 106, 30), C(86, 150, 60), C(70, 150, 56), C(255, 128, 98), C(104, 186, 78) },
			Materials = { "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Neon", "Plastic" },
			Boxes = [[
Rock 4 2 1 4 2 1 1
Rock 5 2 2 11 8 14 1
Rock 4 2 3 12 8 13 1
Rock 3 2 4 13 8 12 1
Rock 2 2 5 14 8 11 1
Rock 3 1 7 15 3 8 1
Rock 1 1 8 13 3 9 1
Rock 10 1 15 11 3 15 1
Rock 4 10 3 4 10 3 1
Rock 13 10 4 13 11 4 1
Rock 2 10 6 2 11 6 1
Rock 14 10 10 14 10 10 1
Rock 5 1 13 5 10 13 1
Rock 9 10 14 9 11 14 1
Rock 3 0 0 5 1 1 2
Rock 5 0 2 11 1 14 2
Rock 4 0 3 4 1 13 2
Rock 12 0 3 12 1 13 2
Rock 3 0 4 3 1 12 2
Rock 13 0 4 13 1 12 2
Rock 2 0 5 2 1 11 2
Rock 14 0 5 14 1 11 2
Rock 15 0 6 16 1 9 2
Rock 0 0 7 1 1 10 2
Rock 9 0 15 12 1 16 2
Rock 5 9 2 11 9 3 3
Rock 4 9 3 4 9 3 3
Rock 10 8 3 12 9 4 3
Rock 3 9 4 3 9 12 3
Rock 13 9 4 13 9 12 3
Rock 2 9 5 2 9 11 3
Rock 14 9 5 14 9 11 3
Rock 4 9 13 12 9 13 3
Rock 5 9 14 11 9 14 3
Gem1 7 8 6 9 14 8 4
Rock 4 1 4 5 9 12 5
Rock 6 1 4 12 9 5 5
Rock 11 1 6 12 9 12 5
Rock 8 1 8 8 9 8 5
Rock 6 1 11 10 9 12 5
Rock 6 1 6 10 9 7 6
Rock 6 1 8 7 9 10 6
Rock 9 1 8 10 9 10 6
Rock 8 1 9 8 9 10 6
Gem2 10 2 14 11 7 15 4
Gem4 3 8 11 4 13 12 4
Fossil 8 1 1 8 9 1 7
Fossil 6 3 1 6 3 1 7
Fossil 10 3 1 10 3 1 7
Fossil 5 4 1 5 4 1 7
Fossil 11 4 1 11 4 1 7
Fossil 6 5 1 6 5 1 7
Fossil 10 5 1 10 5 1 7
Fossil 5 6 1 5 6 1 7
Fossil 11 6 1 11 6 1 7
Fossil 6 7 1 6 7 1 7
Fossil 10 7 1 10 7 1 7
Fossil 7 8 1 7 8 1 7
Fossil 9 8 1 9 8 1 7
Gem3 14 0 8 15 4 9 4
Gem5 2 8 5 3 12 6 4
Glow 1 2 6 1 2 6 8
Glow 15 2 10 15 2 10 8
Glow 1 3 7 1 3 7 8
Glow 15 3 9 15 3 9 8
Glow 1 4 8 1 5 8 8
Glow 15 4 8 15 5 8 8
Glow 1 6 7 1 6 7 8
Glow 15 6 9 15 6 9 8
Glow 1 7 6 1 8 6 8
Glow 15 7 10 15 8 10 8
Glow 1 9 7 1 9 7 8
Glow 15 9 9 15 9 9 8
Biome 12 7 2 12 8 2 9
Biome 10 8 1 11 8 1 9
Biome 13 8 3 13 8 3 9
Biome 10 10 3 12 10 4 9
Biome 12 10 5 13 10 6 9
Float1 -2 9 2 -1 10 3 1
Float2 16 10 11 17 11 12 1
Float3 10 14 13 11 15 14 1
Deco1 8 10 11 8 15 11 10
Deco2 7 10 11 7 15 11 10
Deco3 9 10 11 9 15 11 10
Gem1 8 15 6 8 15 8 11
Gem1 7 15 7 9 15 7 11
Gem1 8 9 7 8 16 7 11
Deco1 8 16 11 8 16 11 12
Deco2 7 16 11 7 16 11 12
Deco3 9 16 11 9 16 11 12
Gem2 10 8 14 10 8 14 11
Gem3 14 5 8 14 5 8 11
Gem4 3 14 11 3 14 11 11
Gem5 2 13 5 2 13 5 11
Float1 -1 11 3 -1 11 3 8
Float2 17 12 12 17 12 12 8
Float3 11 16 14 11 16 14 8
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0, 1.5, 0.529), Rest = V(28, 0, 0) },
				Deco2 = { Pivot = V(-0.176, 1.5, 0.529), Rest = V(-6, 0, 30) },
				Deco3 = { Pivot = V(0.176, 1.5, 0.529), Rest = V(-6, 0, -30) },
				Gem1 = { Pivot = V(0, 0.971, -0.176), Rest = V(-6.6, 0, 1.1) },
				Gem2 = { Pivot = V(0.441, -0.088, 1.147), Rest = V(30, 0, -16.9) },
				Gem3 = { Pivot = V(1.147, -0.441, 0.088), Rest = V(5.4, 0, -30) },
				Gem4 = { Pivot = V(-0.794, 0.971, 0.618), Rest = V(23.4, 0, 25.1) },
				Gem5 = { Pivot = V(-0.971, 0.971, -0.441), Rest = V(-12.6, 0, 30) },
				Gem6 = { Pivot = V(0.618, 0.971, -0.794), Rest = V(-24.6, 0, -22.9) },
				Orbit1 = { Pivot = V(1.235, 0, 1.235), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.235, 0.529, 1.235), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.235, 0, -1.235), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.235, 0.529, -1.235), Rest = V(10, 0, 15) },
			},
			Colors = { C(236, 56, 64), C(170, 90, 235), C(255, 170, 40), C(60, 140, 240), C(80, 200, 90), C(236, 56, 64), C(64, 58, 72), C(255, 170, 40), C(60, 140, 240), C(250, 248, 255), C(80, 200, 90), C(170, 90, 235), C(86, 150, 60), C(78, 70, 90), C(70, 150, 56), C(242, 116, 121), C(104, 186, 78), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Foil", "Neon", "Neon", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 3 4 0 5 5 1 1
Rainbow 5 4 2 11 5 14 1
Rainbow 4 4 3 4 5 13 1
Rainbow 12 4 3 12 5 13 1
Rainbow 3 4 4 3 5 12 1
Rainbow 13 4 4 13 5 12 1
Rainbow 2 4 5 2 5 11 1
Rainbow 14 4 5 14 5 11 1
Rainbow 15 4 6 16 5 9 1
Rainbow 0 4 7 1 5 10 1
Rainbow 9 4 15 12 5 16 1
Rainbow 5 12 2 11 13 14 2
Rainbow 4 12 3 4 13 13 2
Rainbow 3 12 4 3 13 12 2
Rainbow 12 12 4 13 13 12 2
Rainbow 2 12 5 14 12 11 2
Rainbow 12 12 13 12 13 13 2
Rainbow 10 12 3 12 13 4 2
Rainbow 2 13 5 2 13 11 2
Rainbow 14 13 5 14 13 11 2
Rainbow 4 14 3 4 14 3 2
Rainbow 13 14 4 13 15 4 2
Rainbow 2 14 6 2 15 6 2
Rainbow 14 14 10 14 14 10 2
Rainbow 5 5 13 5 14 13 2
Rainbow 9 14 14 9 15 14 2
Rainbow 4 6 1 4 6 1 3
Rainbow 5 6 2 11 7 14 3
Rainbow 4 6 3 12 7 13 3
Rainbow 3 6 4 13 7 12 3
Rainbow 2 6 5 14 7 11 3
Rainbow 3 5 7 15 7 8 3
Rainbow 1 5 8 13 7 9 3
Rainbow 10 5 15 11 7 15 3
Rainbow 5 10 2 11 11 14 4
Rainbow 4 10 3 12 11 13 4
Rainbow 3 10 4 13 11 12 4
Rainbow 2 10 5 14 11 11 4
Rainbow 5 8 2 11 9 14 5
Rainbow 4 8 3 12 9 13 5
Rainbow 3 8 4 13 9 12 5
Rainbow 2 8 5 14 9 11 5
Gem1 7 12 6 9 18 8 6
Base 11 0 3 12 0 4 7
Base 3 0 4 5 0 6 7
Base 8 0 7 9 0 9 7
Base 12 0 11 14 0 12 7
Base 5 0 12 6 0 13 7
Gem2 10 6 14 11 11 15 8
Gem4 3 12 11 4 17 12 9
Fossil 8 5 1 8 13 1 10
Fossil 6 7 1 6 7 1 10
Fossil 10 7 1 10 7 1 10
Fossil 5 8 1 5 8 1 10
Fossil 11 8 1 11 8 1 10
Fossil 6 9 1 6 9 1 10
Fossil 10 9 1 10 9 1 10
Fossil 5 10 1 5 10 1 10
Fossil 11 10 1 11 10 1 10
Fossil 6 11 1 6 11 1 10
Fossil 10 11 1 10 11 1 10
Fossil 7 12 1 7 12 1 10
Fossil 9 12 1 9 12 1 10
Gem3 14 4 8 15 8 9 11
Gem5 2 12 5 3 16 6 12
Gem6 11 12 3 12 16 4 6
Biome 12 11 2 12 12 2 13
Biome 10 12 1 11 12 1 13
Biome 13 12 3 13 12 3 13
Biome 10 14 3 12 14 4 13
Biome 12 14 5 13 14 6 13
Base 3 1 4 5 1 6 14
Base 12 1 11 14 1 12 14
Deco1 8 14 11 8 19 11 15
Deco2 7 14 11 7 19 11 15
Deco3 9 14 11 9 19 11 15
Gem1 8 19 6 8 19 8 16
Gem1 7 19 7 9 19 7 16
Gem1 8 13 7 8 20 7 16
Orbit1 15 7 15 15 9 15 8
Orbit2 1 10 15 1 12 15 11
Orbit3 1 7 1 1 9 1 9
Orbit4 15 10 1 15 12 1 12
Deco1 8 20 11 8 20 11 17
Deco2 7 20 11 7 20 11 17
Deco3 9 20 11 9 20 11 17
Gem2 10 12 14 10 12 14 18
Gem3 14 9 8 14 9 8 19
Gem4 3 18 11 3 18 11 20
Gem5 2 17 5 2 17 5 21
Gem6 11 17 3 11 17 3 16
Orbit1 15 10 15 15 10 15 22
Orbit2 1 13 15 1 13 15 23
Orbit3 1 10 1 1 10 1 24
Orbit4 15 13 1 15 13 1 25
]],
		},
	},
	Swamp = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 0.706, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 0.529, 0.706), Rest = V(-6, 0, -18) },
			},
			Colors = { C(150, 149, 152), C(117, 116, 119), C(238, 228, 200), C(70, 150, 72), C(88, 74, 48), C(92, 150, 70), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 17 1
Rock 2 2 2 14 3 16 1
Rock 1 2 3 15 3 15 1
Rock 0 2 4 16 3 14 1
Rock 3 1 2 13 6 16 1
Rock 2 1 3 2 6 15 1
Rock 14 1 3 14 6 15 1
Rock 1 1 4 15 5 14 1
Rock 1 6 4 1 6 14 1
Rock 15 6 4 15 6 14 1
Rock 5 1 6 11 8 14 1
Rock 4 1 7 4 8 13 1
Rock 12 1 7 12 8 13 1
Rock 3 1 8 13 7 12 1
Rock 3 8 8 3 8 12 1
Rock 13 8 8 13 8 12 1
Rock 10 1 10 12 9 12 1
Rock 3 0 1 13 1 17 2
Rock 2 0 2 2 1 16 2
Rock 14 0 2 14 1 16 2
Rock 1 0 3 1 1 15 2
Rock 15 0 3 15 1 15 2
Rock 0 0 4 0 1 14 2
Rock 16 0 4 16 1 14 2
Fossil 3 0 0 13 0 0 3
Fossil 14 0 1 14 0 1 3
Fossil 3 1 0 3 1 0 3
Fossil 5 1 0 5 1 0 3
Fossil 7 1 0 7 1 0 3
Fossil 9 1 0 9 1 0 3
Fossil 11 1 0 11 1 0 3
Fossil 13 1 0 13 1 0 3
Fossil 4 2 0 4 3 0 3
Fossil 6 2 0 6 3 0 3
Fossil 8 2 0 8 3 0 3
Fossil 10 2 0 10 3 0 3
Fossil 12 2 0 12 3 0 3
Fossil 2 2 1 2 3 1 3
Fossil 14 2 1 14 3 1 3
Fossil 3 3 0 3 3 0 3
Fossil 5 3 0 5 3 0 3
Fossil 7 3 0 7 3 0 3
Fossil 9 3 0 9 3 0 3
Fossil 11 3 0 11 3 0 3
Fossil 13 3 0 13 3 0 3
Fossil 3 4 1 12 4 1 3
Fossil 5 5 1 8 5 1 3
Biome 6 9 7 7 9 11 4
Biome 5 9 8 5 9 11 4
Biome 8 9 8 8 9 11 4
Biome 6 9 12 6 9 12 4
Biome -1 2 4 -1 3 4 5
Biome 17 2 10 17 3 10 5
Biome -1 3 10 -1 3 10 5
Biome 0 4 4 0 4 4 5
Biome 0 4 10 0 4 10 5
Biome 16 4 10 16 5 10 5
Deco1 11 8 13 11 16 13 6
Deco2 13 8 12 13 14 12 6
Biome 2 1 1 2 1 1 7
Biome 2 4 2 2 6 2 7
Biome 6 9 9 6 11 9 8
Deco1 11 17 13 11 18 13 9
Deco2 13 15 12 13 16 12 9
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 0.706, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 0.529, 0.706), Rest = V(-6, 0, -18) },
				Gem1 = { Pivot = V(-0.088, 0.088, -0.088), Rest = V(-8.5, 0, 2.5) },
				Gem2 = { Pivot = V(0.794, -0.794, 1.5), Rest = V(30, 0, -27.5) },
			},
			Colors = { C(66, 160, 66), C(51, 125, 51), C(238, 228, 200), C(150, 226, 108), C(70, 150, 72), C(88, 74, 48), C(92, 150, 70), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44), C(182, 235, 152) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 17 1
Rock 2 2 2 14 3 16 1
Rock 1 2 3 15 3 15 1
Rock 0 2 4 16 3 14 1
Rock 3 1 2 13 6 16 1
Rock 2 1 3 2 6 15 1
Rock 14 1 3 14 6 15 1
Rock 1 1 4 15 5 14 1
Rock 1 6 4 1 6 14 1
Rock 15 6 4 15 6 14 1
Rock 5 1 6 11 8 14 1
Rock 4 1 7 4 8 13 1
Rock 12 1 7 12 8 13 1
Rock 3 1 8 13 7 12 1
Rock 3 8 8 3 8 12 1
Rock 13 8 8 13 8 12 1
Rock 10 1 10 12 9 12 1
Rock 3 0 1 13 1 17 2
Rock 2 0 2 2 1 16 2
Rock 14 0 2 14 1 16 2
Rock 1 0 3 1 1 15 2
Rock 15 0 3 15 1 15 2
Rock 0 0 4 0 1 14 2
Rock 16 0 4 16 1 14 2
Fossil 3 0 0 13 0 0 3
Fossil 14 0 1 14 0 1 3
Fossil 3 1 0 3 1 0 3
Fossil 5 1 0 5 1 0 3
Fossil 7 1 0 7 1 0 3
Fossil 9 1 0 9 1 0 3
Fossil 11 1 0 11 1 0 3
Fossil 13 1 0 13 1 0 3
Fossil 4 2 0 4 3 0 3
Fossil 6 2 0 6 3 0 3
Fossil 8 2 0 8 3 0 3
Fossil 10 2 0 10 3 0 3
Fossil 12 2 0 12 3 0 3
Fossil 2 2 1 2 3 1 3
Fossil 14 2 1 14 3 1 3
Fossil 3 3 0 3 3 0 3
Fossil 5 3 0 5 3 0 3
Fossil 7 3 0 7 3 0 3
Fossil 9 3 0 9 3 0 3
Fossil 11 3 0 11 3 0 3
Fossil 13 3 0 13 3 0 3
Fossil 3 4 1 12 4 1 3
Fossil 5 5 1 8 5 1 3
Gem1 7 7 7 8 12 8 4
Gem2 12 2 16 13 6 17 4
Biome 6 9 7 7 9 11 5
Biome 5 9 8 5 9 11 5
Biome 8 9 8 8 9 11 5
Biome 6 9 12 6 9 12 5
Biome -1 2 4 -1 3 4 6
Biome 17 2 10 17 3 10 6
Biome -1 3 10 -1 3 10 6
Biome 0 4 4 0 4 4 6
Biome 0 4 10 0 4 10 6
Biome 16 4 10 16 5 10 6
Deco1 11 8 13 11 16 13 7
Deco2 13 8 12 13 14 12 7
Biome 2 1 1 2 1 1 8
Biome 2 4 2 2 6 2 8
Biome 6 9 9 6 11 9 9
Deco1 11 17 13 11 18 13 10
Deco2 13 15 12 13 16 12 10
Gem1 7 13 7 7 13 7 11
Gem2 12 7 16 12 7 16 11
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 0.706, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 0.529, 0.706), Rest = V(-6, 0, -18) },
				Gem1 = { Pivot = V(0, 0.088, 0), Rest = V(-8.5, 0, 2.5) },
				Gem2 = { Pivot = V(0.794, -0.794, 1.5), Rest = V(30, 0, -27.5) },
				Gem3 = { Pivot = V(-0.971, -0.794, 1.324), Rest = V(30, 0, 30) },
			},
			Colors = { C(32, 102, 204), C(25, 80, 159), C(120, 200, 255), C(238, 228, 200), C(70, 150, 72), C(88, 74, 48), C(92, 150, 70), C(160, 216, 255), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44) },
			Materials = { "Plastic", "Plastic", "Glass", "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 17 1
Rock 2 2 2 14 3 16 1
Rock 1 2 3 15 3 15 1
Rock 0 2 4 16 3 14 1
Rock 3 1 2 13 6 16 1
Rock 2 1 3 2 6 15 1
Rock 14 1 3 14 6 15 1
Rock 1 1 4 15 5 14 1
Rock 1 6 4 1 6 14 1
Rock 15 6 4 15 6 14 1
Rock 5 1 6 11 8 14 1
Rock 4 1 7 4 8 13 1
Rock 12 1 7 12 8 13 1
Rock 3 1 8 13 7 12 1
Rock 3 8 8 3 8 12 1
Rock 13 8 8 13 8 12 1
Rock 10 1 10 12 9 12 1
Rock 3 0 1 13 1 17 2
Rock 2 0 2 2 1 16 2
Rock 14 0 2 14 1 16 2
Rock 1 0 3 1 1 15 2
Rock 15 0 3 15 1 15 2
Rock 0 0 4 0 1 14 2
Rock 16 0 4 16 1 14 2
Gem1 7 7 7 9 13 9 3
Fossil 3 0 0 13 0 0 4
Fossil 14 0 1 14 0 1 4
Fossil 3 1 0 3 1 0 4
Fossil 5 1 0 5 1 0 4
Fossil 7 1 0 7 1 0 4
Fossil 9 1 0 9 1 0 4
Fossil 11 1 0 11 1 0 4
Fossil 13 1 0 13 1 0 4
Fossil 4 2 0 4 3 0 4
Fossil 6 2 0 6 3 0 4
Fossil 8 2 0 8 3 0 4
Fossil 10 2 0 10 3 0 4
Fossil 12 2 0 12 3 0 4
Fossil 2 2 1 2 3 1 4
Fossil 14 2 1 14 3 1 4
Fossil 3 3 0 3 3 0 4
Fossil 5 3 0 5 3 0 4
Fossil 7 3 0 7 3 0 4
Fossil 9 3 0 9 3 0 4
Fossil 11 3 0 11 3 0 4
Fossil 13 3 0 13 3 0 4
Fossil 3 4 1 12 4 1 4
Fossil 5 5 1 8 5 1 4
Gem2 12 2 16 13 7 17 3
Gem3 2 2 15 3 6 16 3
Biome 6 9 7 7 9 11 5
Biome 5 9 8 5 9 11 5
Biome 8 9 8 8 9 11 5
Biome 6 9 12 6 9 12 5
Biome -1 2 4 -1 3 4 6
Biome 17 2 10 17 3 10 6
Biome -1 3 10 -1 3 10 6
Biome 0 4 4 0 4 4 6
Biome 0 4 10 0 4 10 6
Biome 16 4 10 16 5 10 6
Deco1 11 8 13 11 16 13 7
Deco2 13 8 12 13 14 12 7
Gem1 8 14 7 8 14 9 8
Gem1 7 14 8 9 14 8 8
Gem1 8 8 8 8 15 8 8
Biome 2 1 1 2 1 1 9
Biome 2 4 2 2 6 2 9
Biome 6 9 9 6 11 9 10
Deco1 11 17 13 11 18 13 11
Deco2 13 15 12 13 16 12 11
Gem2 12 8 16 12 8 16 8
Gem3 2 7 15 2 7 15 8
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 0.706, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 0.529, 0.706), Rest = V(-6, 0, -18) },
				Gem1 = { Pivot = V(-0.176, -0.441, 0), Rest = V(-8.3, 0, 8.3) },
				Gem2 = { Pivot = V(1.324, -0.794, 0.971), Rest = V(27.7, 0, -30) },
				Gem3 = { Pivot = V(-0.794, -0.794, 1.5), Rest = V(30, 0, 26.3) },
				Gem4 = { Pivot = V(1.324, -0.794, -0.618), Rest = V(-26.3, 0, -30) },
			},
			Colors = { C(124, 54, 192), C(97, 42, 150), C(214, 150, 255), C(190, 120, 255), C(238, 228, 200), C(70, 150, 72), C(88, 74, 48), C(92, 150, 70), C(210, 160, 255), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44) },
			Materials = { "Plastic", "Plastic", "Neon", "Glass", "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 17 1
Rock 2 2 2 14 3 16 1
Rock 1 2 3 15 3 15 1
Rock 0 2 4 16 3 14 1
Rock 11 1 2 13 6 16 1
Rock 2 1 3 5 6 15 1
Rock 14 1 3 14 6 15 1
Rock 1 1 4 1 6 14 1
Rock 15 1 4 15 6 14 1
Rock 3 1 2 6 5 16 1
Rock 7 1 2 10 4 16 1
Rock 10 5 2 10 5 16 1
Rock 3 6 2 5 6 2 1
Rock 3 6 16 5 6 16 1
Rock 5 1 6 5 8 14 1
Rock 11 1 6 11 8 14 1
Rock 4 1 7 4 8 13 1
Rock 12 1 7 12 8 13 1
Rock 3 1 8 3 8 12 1
Rock 13 1 8 13 8 12 1
Rock 12 1 10 12 9 12 1
Rock 3 0 1 13 1 17 2
Rock 2 0 2 2 1 16 2
Rock 14 0 2 14 1 16 2
Rock 1 0 3 1 1 15 2
Rock 15 0 3 15 1 15 2
Rock 0 0 4 0 1 14 2
Rock 16 0 4 16 1 14 2
Glow 7 5 2 9 5 16 3
Glow 6 6 2 6 6 16 3
Glow 10 6 2 10 6 16 3
Gem1 6 4 7 8 10 9 4
Fossil 3 0 0 13 0 0 5
Fossil 14 0 1 14 0 1 5
Fossil 3 1 0 3 1 0 5
Fossil 5 1 0 5 1 0 5
Fossil 7 1 0 7 1 0 5
Fossil 9 1 0 9 1 0 5
Fossil 11 1 0 11 1 0 5
Fossil 13 1 0 13 1 0 5
Fossil 4 2 0 4 3 0 5
Fossil 6 2 0 6 3 0 5
Fossil 8 2 0 8 3 0 5
Fossil 10 2 0 10 3 0 5
Fossil 12 2 0 12 3 0 5
Fossil 2 2 1 2 3 1 5
Fossil 14 2 1 14 3 1 5
Fossil 3 3 0 3 3 0 5
Fossil 5 3 0 5 3 0 5
Fossil 7 3 0 7 3 0 5
Fossil 9 3 0 9 3 0 5
Fossil 11 3 0 11 3 0 5
Fossil 13 3 0 13 3 0 5
Fossil 3 4 1 12 4 1 5
Fossil 5 5 1 8 5 1 5
Gem2 15 2 13 16 7 14 4
Gem4 15 2 4 16 7 5 4
Gem3 3 2 16 4 6 17 4
Biome 7 6 7 7 6 11 6
Biome 8 6 8 8 6 11 6
Biome 6 7 7 6 7 12 6
Biome 5 9 8 5 9 11 6
Biome -1 2 4 -1 3 4 7
Biome 17 2 10 17 3 10 7
Biome -1 3 10 -1 3 10 7
Biome 0 4 4 0 4 4 7
Biome 0 4 10 0 4 10 7
Biome 16 4 10 16 5 10 7
Deco1 11 8 13 11 16 13 8
Deco2 13 8 12 13 14 12 8
Gem1 7 11 7 7 11 9 9
Gem1 6 11 8 8 11 8 9
Gem1 7 5 8 7 12 8 9
Biome 2 1 1 2 1 1 10
Biome 2 4 2 2 6 2 10
Biome 6 8 9 6 9 9 11
Deco1 11 17 13 11 18 13 12
Deco2 13 15 12 13 16 12 12
Gem2 15 8 13 15 8 13 9
Gem3 3 7 16 3 7 16 9
Gem4 15 8 4 15 8 4 9
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 0.882, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 0.706, 0.706), Rest = V(-6, 0, -18) },
				Gem1 = { Pivot = V(0, 0.265, 0), Rest = V(-8.5, 0, 2.5) },
				Gem2 = { Pivot = V(0.794, -0.618, 1.5), Rest = V(30, 0, -27.5) },
				Gem3 = { Pivot = V(-0.971, -0.618, 1.324), Rest = V(30, 0, 30) },
				Gem4 = { Pivot = V(1.324, -0.618, -0.618), Rest = V(-26.5, 0, -30) },
				Gem5 = { Pivot = V(-1.147, -0.088, -0.618), Rest = V(-26.5, 0, 30) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(176, 87, 9), C(255, 196, 30), C(70, 150, 72), C(88, 74, 48), C(92, 150, 70), C(255, 214, 98), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44) },
			Materials = { "Plastic", "Foil", "Plastic", "Neon", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 3 1 13 4 17 1
Rock 2 3 2 14 4 16 1
Rock 1 3 3 15 4 15 1
Rock 0 3 4 16 4 14 1
Rock 3 2 2 13 7 16 1
Rock 2 2 3 2 7 15 1
Rock 14 2 3 14 7 15 1
Rock 1 2 4 15 6 14 1
Rock 1 7 4 1 7 14 1
Rock 15 7 4 15 7 14 1
Rock 5 1 6 11 9 14 1
Rock 4 1 7 4 9 13 1
Rock 12 1 7 12 9 13 1
Rock 3 1 8 13 8 12 1
Rock 3 9 8 3 9 12 1
Rock 13 9 8 13 9 12 1
Rock 10 1 10 12 10 12 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Rock 3 1 1 13 2 17 3
Rock 2 1 2 14 2 15 3
Rock 1 1 3 15 2 14 3
Rock 0 1 4 16 2 13 3
Rock 0 1 14 0 2 14 3
Rock 16 1 14 16 2 14 3
Rock 1 1 15 1 2 15 3
Rock 15 1 15 15 2 15 3
Rock 2 1 16 2 2 16 3
Rock 14 1 16 14 2 16 3
Gem1 7 8 7 9 14 9 4
Fossil 3 1 0 13 1 0 2
Fossil 14 1 1 14 1 1 2
Fossil 3 2 0 3 2 0 2
Fossil 5 2 0 5 2 0 2
Fossil 7 2 0 7 2 0 2
Fossil 9 2 0 9 2 0 2
Fossil 11 2 0 11 2 0 2
Fossil 13 2 0 13 2 0 2
Fossil 4 3 0 4 4 0 2
Fossil 6 3 0 6 4 0 2
Fossil 8 3 0 8 4 0 2
Fossil 10 3 0 10 4 0 2
Fossil 12 3 0 12 4 0 2
Fossil 2 3 1 2 4 1 2
Fossil 14 3 1 14 4 1 2
Fossil 3 4 0 3 4 0 2
Fossil 5 4 0 5 4 0 2
Fossil 7 4 0 7 4 0 2
Fossil 9 4 0 9 4 0 2
Fossil 11 4 0 11 4 0 2
Fossil 13 4 0 13 4 0 2
Fossil 3 5 1 12 5 1 2
Fossil 5 6 1 8 6 1 2
Gem2 12 3 16 13 8 17 4
Gem4 15 3 4 16 8 5 4
Gem3 2 3 15 3 7 16 4
Gem5 1 6 4 2 10 5 4
Biome 6 10 7 7 10 11 5
Biome 5 10 8 5 10 11 5
Biome 8 10 8 8 10 11 5
Biome 6 10 12 6 10 12 5
Biome -1 3 4 -1 4 4 6
Biome 17 3 10 17 4 10 6
Biome -1 4 10 -1 4 10 6
Biome 0 5 4 0 5 4 6
Biome 0 5 10 0 5 10 6
Biome 16 5 10 16 6 10 6
Deco1 11 9 13 11 17 13 7
Deco2 13 9 12 13 15 12 7
Gem1 8 15 7 8 15 9 8
Gem1 7 15 8 9 15 8 8
Gem1 8 9 8 8 16 8 8
Biome 2 2 1 2 2 1 9
Biome 2 5 2 2 7 2 9
Biome 6 10 9 6 12 9 10
Deco1 11 18 13 11 19 13 11
Deco2 13 16 12 13 17 12 11
Gem2 12 9 16 12 9 16 8
Gem3 2 8 15 2 8 15 8
Gem4 15 9 4 15 9 4 8
Gem5 1 11 4 1 11 4 8
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 0.706, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 0.529, 0.706), Rest = V(-6, 0, -18) },
				Gem1 = { Pivot = V(0, 0.088, 0), Rest = V(-8.5, 0, 2.5) },
				Gem2 = { Pivot = V(0.794, -0.794, 1.5), Rest = V(30, 0, -27.5) },
				Gem3 = { Pivot = V(-0.971, -0.794, 1.324), Rest = V(30, 0, 30) },
				Gem4 = { Pivot = V(1.324, -0.794, -0.618), Rest = V(-26.5, 0, -30) },
				Gem5 = { Pivot = V(-1.147, -0.265, -0.618), Rest = V(-26.5, 0, 30) },
				Float1 = { Pivot = V(-1.676, -0.088, -0.794), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.5, 0.088, 0.794), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 0.794, 1.147), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(117, 17, 20), C(255, 74, 30), C(238, 228, 200), C(70, 150, 72), C(255, 106, 30), C(88, 74, 48), C(92, 150, 70), C(255, 128, 98), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44) },
			Materials = { "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 17 1
Rock 2 2 2 14 3 16 1
Rock 1 2 3 15 3 15 1
Rock 0 2 4 16 3 14 1
Rock 3 1 2 13 6 16 1
Rock 2 1 3 2 6 15 1
Rock 14 1 3 14 6 15 1
Rock 1 1 4 15 5 14 1
Rock 1 6 4 1 6 14 1
Rock 15 6 4 15 6 14 1
Rock 5 1 6 11 8 14 1
Rock 4 1 7 4 8 13 1
Rock 12 1 7 12 8 13 1
Rock 3 1 8 13 7 12 1
Rock 3 8 8 3 8 12 1
Rock 13 8 8 13 8 12 1
Rock 10 1 10 12 9 12 1
Rock 3 0 1 13 1 17 2
Rock 2 0 2 2 1 16 2
Rock 14 0 2 14 1 16 2
Rock 1 0 3 1 1 15 2
Rock 15 0 3 15 1 15 2
Rock 0 0 4 0 1 14 2
Rock 16 0 4 16 1 14 2
Gem1 7 7 7 9 13 9 3
Fossil 3 0 0 13 0 0 4
Fossil 14 0 1 14 0 1 4
Fossil 3 1 0 3 1 0 4
Fossil 5 1 0 5 1 0 4
Fossil 7 1 0 7 1 0 4
Fossil 9 1 0 9 1 0 4
Fossil 11 1 0 11 1 0 4
Fossil 13 1 0 13 1 0 4
Fossil 4 2 0 4 3 0 4
Fossil 6 2 0 6 3 0 4
Fossil 8 2 0 8 3 0 4
Fossil 10 2 0 10 3 0 4
Fossil 12 2 0 12 3 0 4
Fossil 2 2 1 2 3 1 4
Fossil 14 2 1 14 3 1 4
Fossil 3 3 0 3 3 0 4
Fossil 5 3 0 5 3 0 4
Fossil 7 3 0 7 3 0 4
Fossil 9 3 0 9 3 0 4
Fossil 11 3 0 11 3 0 4
Fossil 13 3 0 13 3 0 4
Fossil 3 4 1 12 4 1 4
Fossil 5 5 1 8 5 1 4
Gem2 12 2 16 13 7 17 3
Gem4 15 2 4 16 7 5 3
Gem3 2 2 15 3 6 16 3
Gem5 1 5 4 2 9 5 3
Biome 6 9 7 7 9 11 5
Biome 5 9 8 5 9 11 5
Biome 8 9 8 8 9 11 5
Biome 6 9 12 6 9 12 5
Glow 17 0 7 17 0 7 6
Glow -1 0 9 -1 0 9 6
Glow 17 1 6 17 2 6 6
Glow -1 1 10 -1 2 10 6
Glow 17 3 7 17 3 7 6
Glow -1 3 9 -1 3 9 6
Glow 0 4 8 0 5 8 6
Glow 16 4 8 16 5 8 6
Glow 16 6 7 16 6 7 6
Glow 0 6 9 0 6 9 6
Glow 13 7 7 13 7 7 6
Glow 2 7 9 2 7 9 6
Biome -1 2 4 -1 3 4 7
Biome 17 2 10 17 3 10 7
Biome -1 3 10 -1 3 10 7
Biome 0 4 4 0 4 4 7
Biome 0 4 10 0 4 10 7
Biome 16 4 10 16 5 10 7
Deco1 11 8 13 11 16 13 8
Float1 -2 7 3 -1 8 4 1
Float2 16 8 12 17 9 13 1
Float3 10 12 14 11 13 15 1
Deco2 13 8 12 13 14 12 8
Gem1 8 14 7 8 14 9 9
Gem1 7 14 8 9 14 8 9
Gem1 8 8 8 8 15 8 9
Biome 2 1 1 2 1 1 10
Biome 2 4 2 2 6 2 10
Biome 6 9 9 6 11 9 11
Deco1 11 17 13 11 18 13 12
Deco2 13 15 12 13 16 12 12
Gem2 12 8 16 12 8 16 9
Gem3 2 7 15 2 7 15 9
Gem4 15 8 4 15 8 4 9
Gem5 1 10 4 1 10 4 9
Float1 -1 9 4 -1 9 4 6
Float2 17 10 13 17 10 13 6
Float3 11 14 15 11 14 15 6
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Deco1 = { Pivot = V(0.529, 1.412, 0.882), Rest = V(10, 0, -8) },
				Deco2 = { Pivot = V(0.882, 1.235, 0.706), Rest = V(-6, 0, -18) },
				Gem1 = { Pivot = V(0, 0.794, 0), Rest = V(-8.5, 0, 2.5) },
				Gem2 = { Pivot = V(0.794, -0.088, 1.5), Rest = V(30, 0, -27.5) },
				Gem3 = { Pivot = V(-0.971, -0.088, 1.324), Rest = V(30, 0, 30) },
				Gem4 = { Pivot = V(1.324, -0.088, -0.618), Rest = V(-26.5, 0, -30) },
				Gem5 = { Pivot = V(-1.147, 0.441, -0.618), Rest = V(-26.5, 0, 30) },
				Gem6 = { Pivot = V(1.147, 0.441, 0.441), Rest = V(9.5, 0, -30) },
				Orbit1 = { Pivot = V(1.235, -0.176, 1.235), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.235, 0.353, 1.235), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.235, -0.176, -1.235), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.235, 0.353, -1.235), Rest = V(10, 0, 15) },
			},
			Colors = { C(236, 56, 64), C(80, 200, 90), C(60, 140, 240), C(255, 170, 40), C(236, 56, 64), C(250, 248, 255), C(64, 58, 72), C(255, 170, 40), C(60, 140, 240), C(80, 200, 90), C(170, 90, 235), C(70, 150, 72), C(78, 70, 90), C(170, 90, 235), C(88, 74, 48), C(92, 150, 70), C(242, 116, 121), C(72, 128, 52), C(236, 124, 172), C(120, 76, 44), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Foil", "Plastic", "Neon", "Neon", "Neon", "Neon", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 3 4 1 13 5 17 1
Rainbow 2 4 2 2 5 16 1
Rainbow 14 4 2 14 5 16 1
Rainbow 1 4 3 1 5 15 1
Rainbow 15 4 3 15 5 15 1
Rainbow 0 4 4 0 5 14 1
Rainbow 16 4 4 16 5 14 1
Rainbow 3 5 2 13 10 16 2
Rainbow 2 5 3 2 10 15 2
Rainbow 14 5 3 14 10 15 2
Rainbow 1 5 4 15 9 14 2
Rainbow 1 10 4 1 10 14 2
Rainbow 15 10 4 15 10 14 2
Rainbow 5 5 6 11 12 14 3
Rainbow 4 5 7 4 12 13 3
Rainbow 12 5 7 12 12 13 3
Rainbow 3 5 8 13 11 12 3
Rainbow 3 12 8 3 12 12 3
Rainbow 13 12 8 13 12 12 3
Rainbow 3 6 1 13 7 17 4
Rainbow 2 6 2 14 7 16 4
Rainbow 1 6 3 15 7 15 4
Rainbow 0 6 4 16 7 14 4
Gem1 7 11 7 9 17 9 5
Fossil 3 4 0 13 4 0 6
Fossil 14 4 1 14 4 1 6
Fossil 3 5 0 3 5 0 6
Fossil 5 5 0 5 5 0 6
Fossil 7 5 0 7 5 0 6
Fossil 9 5 0 9 5 0 6
Fossil 11 5 0 11 5 0 6
Fossil 13 5 0 13 5 0 6
Fossil 4 6 0 4 7 0 6
Fossil 6 6 0 6 7 0 6
Fossil 8 6 0 8 7 0 6
Fossil 10 6 0 10 7 0 6
Fossil 12 6 0 12 7 0 6
Fossil 2 6 1 2 7 1 6
Fossil 14 6 1 14 7 1 6
Fossil 3 7 0 3 7 0 6
Fossil 5 7 0 5 7 0 6
Fossil 7 7 0 7 7 0 6
Fossil 9 7 0 9 7 0 6
Fossil 11 7 0 11 7 0 6
Fossil 13 7 0 13 7 0 6
Fossil 3 8 1 12 8 1 6
Fossil 5 9 1 8 9 1 6
Base 11 0 3 12 0 4 7
Base 3 0 4 5 0 6 7
Base 8 0 7 9 0 9 7
Base 12 0 11 14 0 12 7
Base 5 0 12 6 0 13 7
Gem2 12 6 16 13 11 17 8
Gem4 15 6 4 16 11 5 9
Gem3 2 6 15 3 10 16 10
Gem5 1 9 4 2 13 5 11
Gem6 14 9 10 15 13 11 5
Biome 6 13 7 7 13 11 12
Biome 5 13 8 5 13 11 12
Biome 8 13 8 8 13 11 12
Biome 6 13 12 6 13 12 12
Base 3 1 4 5 1 6 13
Base 12 1 11 14 1 12 13
Rainbow 10 5 10 12 13 12 14
Biome -1 6 4 -1 7 4 15
Biome 17 6 10 17 7 10 15
Biome -1 7 10 -1 7 10 15
Biome 0 8 4 0 8 4 15
Biome 0 8 10 0 8 10 15
Biome 16 8 10 16 9 10 15
Deco1 11 12 13 11 20 13 16
Deco2 13 12 12 13 18 12 16
Gem1 8 18 7 8 18 9 17
Gem1 7 18 8 9 18 8 17
Gem1 8 12 8 8 19 8 17
Biome 2 5 1 2 5 1 18
Biome 2 8 2 2 10 2 18
Orbit1 15 6 15 15 8 15 8
Orbit2 1 9 15 1 11 15 10
Orbit3 1 6 1 1 8 1 9
Orbit4 15 9 1 15 11 1 11
Biome 6 13 9 6 15 9 19
Deco1 11 21 13 11 22 13 20
Deco2 13 19 12 13 20 12 20
Gem2 12 12 16 12 12 16 21
Gem3 2 11 15 2 11 15 22
Gem4 15 12 4 15 12 4 23
Gem5 1 14 4 1 14 4 24
Gem6 14 14 10 14 14 10 17
Orbit1 15 9 15 15 9 15 25
Orbit2 1 12 15 1 12 15 26
Orbit3 1 9 1 1 9 1 27
Orbit4 15 12 1 15 12 1 28
]],
		},
	},
	Canyon = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {},
			Colors = { C(150, 149, 152), C(117, 116, 119), C(120, 119, 122), C(163, 162, 164), C(238, 228, 200), C(70, 140, 70), C(184, 92, 58) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 6 1 5 10 3 11 1
Rock 5 1 6 11 3 10 1
Rock 6 5 5 10 7 11 1
Rock 5 5 6 11 7 10 1
Rock 6 9 5 10 13 11 1
Rock 5 9 6 11 13 10 1
Rock 3 11 1 13 11 15 1
Rock 2 11 2 2 11 14 1
Rock 14 11 2 14 11 14 1
Rock 1 11 3 1 11 13 1
Rock 15 11 3 15 11 13 1
Rock 0 11 4 0 11 12 1
Rock 16 11 4 16 11 12 1
Rock 5 12 4 11 13 12 1
Rock 4 12 5 12 13 11 1
Rock 3 12 6 13 13 10 1
Rock 4 0 2 12 1 14 2
Rock 3 0 3 3 1 13 2
Rock 13 0 3 13 1 13 2
Rock 2 0 4 2 1 12 2
Rock 14 0 4 14 1 12 2
Rock 6 4 5 10 4 11 3
Rock 5 4 6 11 4 10 3
Rock 6 8 5 10 8 11 3
Rock 5 8 6 11 8 10 3
Rock 3 12 1 13 12 15 3
Rock 2 12 2 2 12 14 3
Rock 14 12 2 14 12 14 3
Rock 1 12 3 1 12 13 3
Rock 15 12 3 15 12 13 3
Rock 0 12 4 0 12 12 3
Rock 16 12 4 16 12 12 3
Rock 5 14 4 11 14 12 4
Rock 4 14 5 4 14 11 4
Rock 12 14 5 12 14 11 4
Rock 3 14 6 3 14 10 4
Rock 13 14 6 13 14 10 4
Fossil 7 2 4 9 2 4 5
Fossil 8 3 4 8 4 4 5
Fossil 7 4 4 7 6 4 5
Fossil 9 4 4 9 6 4 5
Fossil 6 5 4 6 5 4 5
Fossil 10 5 4 10 5 4 5
Fossil 8 6 4 8 8 4 5
Fossil 7 8 4 7 10 4 5
Fossil 9 8 4 9 10 4 5
Fossil 6 9 4 6 9 4 5
Fossil 10 9 4 10 9 4 5
Fossil 8 10 4 8 10 4 5
Biome 3 2 7 3 7 7 6
Biome 1 4 7 1 6 7 6
Biome 2 4 7 2 4 7 6
Biome 1 0 2 1 1 2 7
Biome 14 0 2 14 0 2 7
Biome 15 0 13 15 0 13 7
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(-0.088, 1.147, -0.265), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.794, 0.794, 1.147), Rest = V(30, 0, -30) },
			},
			Colors = { C(66, 160, 66), C(51, 125, 51), C(53, 128, 53), C(89, 171, 89), C(238, 228, 200), C(150, 226, 108), C(70, 140, 70), C(184, 92, 58), C(182, 235, 152) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 6 1 5 10 3 11 1
Rock 5 1 6 11 3 10 1
Rock 6 5 5 10 7 11 1
Rock 5 5 6 11 7 10 1
Rock 6 9 5 10 13 11 1
Rock 5 9 6 11 13 10 1
Rock 3 11 1 13 11 15 1
Rock 2 11 2 2 11 14 1
Rock 14 11 2 14 11 14 1
Rock 1 11 3 1 11 13 1
Rock 15 11 3 15 11 13 1
Rock 0 11 4 0 11 12 1
Rock 16 11 4 16 11 12 1
Rock 5 12 4 11 13 12 1
Rock 4 12 5 12 13 11 1
Rock 3 12 6 13 13 10 1
Rock 4 0 2 12 1 14 2
Rock 3 0 3 3 1 13 2
Rock 13 0 3 13 1 13 2
Rock 2 0 4 2 1 12 2
Rock 14 0 4 14 1 12 2
Rock 6 4 5 10 4 11 3
Rock 5 4 6 11 4 10 3
Rock 6 8 5 10 8 11 3
Rock 5 8 6 11 8 10 3
Rock 3 12 1 13 12 15 3
Rock 2 12 2 2 12 14 3
Rock 14 12 2 14 12 14 3
Rock 1 12 3 1 12 13 3
Rock 15 12 3 15 12 13 3
Rock 0 12 4 0 12 12 3
Rock 16 12 4 16 12 12 3
Rock 5 14 4 11 14 12 4
Rock 4 14 5 4 14 11 4
Rock 12 14 5 12 14 11 4
Rock 3 14 6 3 14 10 4
Rock 13 14 6 13 14 10 4
Fossil 7 2 4 9 2 4 5
Fossil 8 3 4 8 4 4 5
Fossil 7 4 4 7 6 4 5
Fossil 9 4 4 9 6 4 5
Fossil 6 5 4 6 5 4 5
Fossil 10 5 4 10 5 4 5
Fossil 8 6 4 8 8 4 5
Fossil 7 8 4 7 10 4 5
Fossil 9 8 4 9 10 4 5
Fossil 6 9 4 6 9 4 5
Fossil 10 9 4 10 9 4 5
Fossil 8 10 4 8 10 4 5
Gem1 7 13 6 8 18 7 6
Gem2 12 11 14 13 15 15 6
Biome 3 2 7 3 7 7 7
Biome 1 4 7 1 6 7 7
Biome 2 4 7 2 4 7 7
Biome 1 0 2 1 1 2 8
Biome 14 0 2 14 0 2 8
Biome 15 0 13 15 0 13 8
Gem1 7 19 6 7 19 6 9
Gem2 12 16 14 12 16 14 9
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.147, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.794, 0.794, 1.147), Rest = V(30, 0, -30) },
				Gem3 = { Pivot = V(-0.794, 0.794, 1.147), Rest = V(30, 0, 24) },
			},
			Colors = { C(32, 102, 204), C(25, 80, 159), C(26, 82, 163), C(59, 120, 210), C(120, 200, 255), C(238, 228, 200), C(70, 140, 70), C(160, 216, 255), C(184, 92, 58) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Plastic", "Glass", "Plastic" },
			Boxes = [[
Rock 6 1 5 10 3 11 1
Rock 5 1 6 11 3 10 1
Rock 6 5 5 10 7 11 1
Rock 5 5 6 11 7 10 1
Rock 6 9 5 10 13 11 1
Rock 5 9 6 11 13 10 1
Rock 3 11 1 13 11 15 1
Rock 2 11 2 2 11 14 1
Rock 14 11 2 14 11 14 1
Rock 1 11 3 1 11 13 1
Rock 15 11 3 15 11 13 1
Rock 0 11 4 0 11 12 1
Rock 16 11 4 16 11 12 1
Rock 5 12 4 11 13 12 1
Rock 4 12 5 12 13 11 1
Rock 3 12 6 13 13 10 1
Rock 4 0 2 12 1 14 2
Rock 3 0 3 3 1 13 2
Rock 13 0 3 13 1 13 2
Rock 2 0 4 2 1 12 2
Rock 14 0 4 14 1 12 2
Rock 6 4 5 10 4 11 3
Rock 5 4 6 11 4 10 3
Rock 6 8 5 10 8 11 3
Rock 5 8 6 11 8 10 3
Rock 3 12 1 13 12 15 3
Rock 2 12 2 2 12 14 3
Rock 14 12 2 14 12 14 3
Rock 1 12 3 1 12 13 3
Rock 15 12 3 15 12 13 3
Rock 0 12 4 0 12 12 3
Rock 16 12 4 16 12 12 3
Rock 5 14 4 11 14 12 4
Rock 4 14 5 4 14 11 4
Rock 12 14 5 12 14 11 4
Rock 3 14 6 3 14 10 4
Rock 13 14 6 13 14 10 4
Gem1 7 13 6 9 19 8 5
Fossil 7 2 4 9 2 4 6
Fossil 8 3 4 8 4 4 6
Fossil 7 4 4 7 6 4 6
Fossil 9 4 4 9 6 4 6
Fossil 6 5 4 6 5 4 6
Fossil 10 5 4 10 5 4 6
Fossil 8 6 4 8 8 4 6
Fossil 7 8 4 7 10 4 6
Fossil 9 8 4 9 10 4 6
Fossil 6 9 4 6 9 4 6
Fossil 10 9 4 10 9 4 6
Fossil 8 10 4 8 10 4 6
Gem2 12 11 14 13 16 15 5
Gem3 3 11 14 4 15 15 5
Biome 3 2 7 3 7 7 7
Biome 1 4 7 1 6 7 7
Biome 2 4 7 2 4 7 7
Gem1 8 20 6 8 20 8 8
Gem1 7 20 7 9 20 7 8
Gem1 8 14 7 8 21 7 8
Biome 1 0 2 1 1 2 9
Biome 14 0 2 14 0 2 9
Biome 15 0 13 15 0 13 9
Gem2 12 17 14 12 17 14 8
Gem3 3 16 14 3 16 14 8
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(-0.176, 0.441, -0.176), Rest = V(-6, 0, 5.3) },
				Gem2 = { Pivot = V(1.324, 0.794, 0.618), Rest = V(24, 0, -30) },
				Gem3 = { Pivot = V(-0.794, 0.794, 1.147), Rest = V(30, 0, 23.3) },
				Gem4 = { Pivot = V(0.971, 0.794, -0.971), Rest = V(-30, 0, -30) },
			},
			Colors = { C(124, 54, 192), C(97, 42, 150), C(99, 43, 154), C(190, 120, 255), C(214, 150, 255), C(238, 228, 200), C(140, 78, 200), C(70, 140, 70), C(210, 160, 255), C(184, 92, 58) },
			Materials = { "Plastic", "Plastic", "Plastic", "Glass", "Neon", "Plastic", "Plastic", "Plastic", "Glass", "Plastic" },
			Boxes = [[
Rock 6 1 5 10 3 11 1
Rock 5 1 6 11 3 10 1
Rock 6 5 5 10 7 11 1
Rock 5 5 6 11 7 10 1
Rock 6 9 5 10 9 11 1
Rock 5 9 6 11 9 10 1
Rock 6 10 5 6 10 11 1
Rock 10 10 5 10 10 11 1
Rock 5 10 6 6 10 10 1
Rock 10 10 6 11 10 10 1
Rock 3 11 1 5 11 15 1
Rock 11 11 1 13 11 15 1
Rock 2 11 2 2 11 14 1
Rock 14 11 2 14 11 14 1
Rock 1 11 3 1 11 13 1
Rock 15 11 3 15 11 13 1
Rock 0 11 4 0 11 12 1
Rock 16 11 4 16 11 12 1
Rock 5 13 4 5 13 12 1
Rock 11 13 4 11 13 12 1
Rock 4 12 5 4 13 11 1
Rock 12 12 5 12 13 11 1
Rock 3 12 6 4 13 10 1
Rock 12 12 6 13 13 10 1
Rock 4 0 2 12 1 14 2
Rock 3 0 3 3 1 13 2
Rock 13 0 3 13 1 13 2
Rock 2 0 4 2 1 12 2
Rock 14 0 4 14 1 12 2
Rock 6 4 5 10 4 11 3
Rock 5 4 6 11 4 10 3
Rock 6 8 5 10 8 11 3
Rock 5 8 6 11 8 10 3
Rock 3 12 1 5 12 15 3
Rock 11 12 1 13 12 15 3
Rock 2 12 2 2 12 14 3
Rock 14 12 2 14 12 14 3
Rock 1 12 3 1 12 13 3
Rock 15 12 3 15 12 13 3
Rock 0 12 4 0 12 12 3
Rock 16 12 4 16 12 12 3
Gem1 6 9 6 8 15 8 4
Glow 7 10 5 9 10 11 5
Glow 6 11 1 6 11 15 5
Glow 10 11 1 10 11 15 5
Fossil 7 2 4 9 2 4 6
Fossil 8 3 4 8 4 4 6
Fossil 7 4 4 7 6 4 6
Fossil 9 4 4 9 6 4 6
Fossil 6 5 4 6 5 4 6
Fossil 10 5 4 10 5 4 6
Fossil 8 6 4 8 8 4 6
Fossil 7 8 4 7 10 4 6
Fossil 9 8 4 9 10 4 6
Fossil 6 9 4 6 9 4 6
Fossil 10 9 4 10 9 4 6
Fossil 8 10 4 8 10 4 6
Rock 4 14 5 4 14 11 7
Rock 12 14 5 12 14 11 7
Rock 3 14 6 3 14 10 7
Rock 13 14 6 13 14 10 7
Gem2 15 11 11 16 16 12 4
Gem4 13 11 2 14 16 3 4
Gem3 3 11 14 4 15 15 4
Biome 3 2 7 3 7 7 8
Biome 1 4 7 1 6 7 8
Biome 2 4 7 2 4 7 8
Gem1 7 16 6 7 16 8 9
Gem1 6 16 7 8 16 7 9
Gem1 7 10 7 7 17 7 9
Biome 1 0 2 1 1 2 10
Biome 14 0 2 14 0 2 10
Biome 15 0 13 15 0 13 10
Gem2 15 17 11 15 17 11 9
Gem3 3 16 14 3 16 14 9
Gem4 13 17 2 13 17 2 9
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.324, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.794, 0.971, 1.147), Rest = V(30, 0, -30) },
				Gem3 = { Pivot = V(-0.794, 0.971, 1.147), Rest = V(30, 0, 24) },
				Gem4 = { Pivot = V(1.324, 0.971, -0.618), Rest = V(-18, 0, -30) },
				Gem5 = { Pivot = V(-1.324, 0.971, -0.618), Rest = V(-18, 0, 30) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(181, 90, 10), C(176, 87, 9), C(229, 129, 41), C(255, 196, 30), C(70, 140, 70), C(255, 214, 98), C(184, 92, 58) },
			Materials = { "Plastic", "Foil", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Plastic" },
			Boxes = [[
Rock 6 1 5 10 4 11 1
Rock 5 1 6 11 4 10 1
Rock 6 6 5 10 8 11 1
Rock 5 6 6 11 8 10 1
Rock 6 10 5 10 14 11 1
Rock 5 10 6 11 14 10 1
Rock 3 12 1 13 12 15 1
Rock 2 12 2 2 12 14 1
Rock 14 12 2 14 12 14 1
Rock 1 12 3 1 12 13 1
Rock 15 12 3 15 12 13 1
Rock 0 12 4 0 12 12 1
Rock 16 12 4 16 12 12 1
Rock 5 13 4 11 14 12 1
Rock 4 13 5 12 14 11 1
Rock 3 13 6 13 14 10 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Rock 6 5 5 10 5 11 3
Rock 5 5 6 11 5 10 3
Rock 6 9 5 10 9 11 3
Rock 5 9 6 11 9 10 3
Rock 3 13 1 13 13 15 3
Rock 2 13 2 2 13 14 3
Rock 14 13 2 14 13 14 3
Rock 1 13 3 1 13 13 3
Rock 15 13 3 15 13 13 3
Rock 0 13 4 0 13 12 3
Rock 16 13 4 16 13 12 3
Rock 4 1 2 12 2 14 4
Rock 3 1 3 3 2 13 4
Rock 13 1 3 13 2 13 4
Rock 2 1 4 14 1 12 4
Rock 2 2 4 2 2 12 4
Rock 14 2 4 14 2 12 4
Rock 5 15 4 11 15 12 5
Rock 4 15 5 4 15 11 5
Rock 12 15 5 12 15 11 5
Rock 3 15 6 3 15 10 5
Rock 13 15 6 13 15 10 5
Gem1 7 14 6 9 20 8 6
Fossil 7 3 4 9 3 4 2
Fossil 8 4 4 8 5 4 2
Fossil 7 5 4 7 7 4 2
Fossil 9 5 4 9 7 4 2
Fossil 6 6 4 6 6 4 2
Fossil 10 6 4 10 6 4 2
Fossil 8 7 4 8 9 4 2
Fossil 7 9 4 7 11 4 2
Fossil 9 9 4 9 11 4 2
Fossil 6 10 4 6 10 4 2
Fossil 10 10 4 10 10 4 2
Fossil 8 11 4 8 11 4 2
Gem2 12 12 14 13 17 15 6
Gem4 15 12 4 16 17 5 6
Gem3 3 12 14 4 16 15 6
Gem5 0 12 4 1 16 5 6
Biome 3 3 7 3 8 7 7
Biome 1 5 7 1 7 7 7
Biome 2 5 7 2 5 7 7
Gem1 8 21 6 8 21 8 8
Gem1 7 21 7 9 21 7 8
Gem1 8 15 7 8 22 7 8
Biome 1 1 2 1 2 2 9
Biome 14 1 2 14 1 2 9
Biome 15 1 13 15 1 13 9
Gem2 12 18 14 12 18 14 8
Gem3 3 17 14 3 17 14 8
Gem4 15 18 4 15 18 4 8
Gem5 0 17 4 0 17 4 8
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.147, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.794, 0.794, 1.147), Rest = V(30, 0, -30) },
				Gem3 = { Pivot = V(-0.794, 0.794, 1.147), Rest = V(30, 0, 24) },
				Gem4 = { Pivot = V(1.324, 0.794, -0.618), Rest = V(-18, 0, -30) },
				Gem5 = { Pivot = V(-1.324, 0.794, -0.618), Rest = V(-18, 0, 30) },
				Float1 = { Pivot = V(-1.676, 0.794, -0.794), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.5, 1.147, 0.441), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 1.853, 0.794), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(117, 17, 20), C(120, 18, 21), C(163, 50, 53), C(255, 74, 30), C(238, 228, 200), C(255, 106, 30), C(70, 140, 70), C(255, 128, 98), C(184, 92, 58) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Plastic", "Neon", "Plastic" },
			Boxes = [[
Rock 6 1 5 10 3 11 1
Rock 5 1 6 11 3 10 1
Rock 6 5 5 10 7 11 1
Rock 5 5 6 11 7 10 1
Rock 6 9 5 10 13 11 1
Rock 5 9 6 11 13 10 1
Rock 3 11 1 13 11 15 1
Rock 2 11 2 2 11 14 1
Rock 14 11 2 14 11 14 1
Rock 1 11 3 1 11 13 1
Rock 15 11 3 15 11 13 1
Rock 0 11 4 0 11 12 1
Rock 16 11 4 16 11 12 1
Rock 5 12 4 11 13 12 1
Rock 4 12 5 12 13 11 1
Rock 3 12 6 13 13 10 1
Rock 4 0 2 12 1 14 2
Rock 3 0 3 3 1 13 2
Rock 13 0 3 13 1 13 2
Rock 2 0 4 2 1 12 2
Rock 14 0 4 14 1 12 2
Rock 6 4 5 10 4 11 3
Rock 5 4 6 11 4 10 3
Rock 6 8 5 10 8 11 3
Rock 5 8 6 11 8 10 3
Rock 3 12 1 13 12 15 3
Rock 2 12 2 2 12 14 3
Rock 14 12 2 14 12 14 3
Rock 1 12 3 1 12 13 3
Rock 15 12 3 15 12 13 3
Rock 0 12 4 0 12 12 3
Rock 16 12 4 16 12 12 3
Rock 5 14 4 11 14 12 4
Rock 4 14 5 4 14 11 4
Rock 12 14 5 12 14 11 4
Rock 3 14 6 3 14 10 4
Rock 13 14 6 13 14 10 4
Gem1 7 13 6 9 19 8 5
Fossil 7 2 4 9 2 4 6
Fossil 8 3 4 8 4 4 6
Fossil 7 4 4 7 6 4 6
Fossil 9 4 4 9 6 4 6
Fossil 6 5 4 6 5 4 6
Fossil 10 5 4 10 5 4 6
Fossil 8 6 4 8 8 4 6
Fossil 7 8 4 7 10 4 6
Fossil 9 8 4 9 10 4 6
Fossil 6 9 4 6 9 4 6
Fossil 10 9 4 10 9 4 6
Fossil 8 10 4 8 10 4 6
Gem2 12 11 14 13 16 15 5
Gem4 15 11 4 16 16 5 5
Gem3 3 11 14 4 15 15 5
Gem5 0 11 4 1 15 5 5
Glow 4 7 7 4 7 7 7
Glow 12 7 9 12 7 9 7
Glow 4 8 8 4 8 8 7
Glow 12 8 8 12 8 8 7
Glow 12 9 7 12 10 7 7
Glow 4 9 9 4 10 9 7
Glow -1 11 8 -1 11 8 7
Glow 17 11 8 17 11 8 7
Glow -1 12 7 -1 12 7 7
Glow 17 12 9 17 12 9 7
Glow 2 13 7 2 13 7 7
Glow 14 13 9 14 13 9 7
Glow 2 14 8 2 14 8 7
Glow 14 14 8 14 14 8 7
Biome 3 2 7 3 7 7 8
Biome 1 4 7 1 6 7 8
Biome 2 4 7 2 4 7 8
Float1 -2 12 3 -1 13 4 1
Float2 16 14 10 17 15 11 1
Float3 10 18 12 11 19 13 1
Gem1 8 20 6 8 20 8 9
Gem1 7 20 7 9 20 7 9
Gem1 8 14 7 8 21 7 9
Biome 1 0 2 1 1 2 10
Biome 14 0 2 14 0 2 10
Biome 15 0 13 15 0 13 10
Gem2 12 17 14 12 17 14 9
Gem3 3 16 14 3 16 14 9
Gem4 15 17 4 15 17 4 9
Gem5 0 16 4 0 16 4 9
Float1 -1 14 4 -1 14 4 7
Float2 17 16 11 17 16 11 7
Float3 11 20 13 11 20 13 7
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.853, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(1.324, 1.5, 0.618), Rest = V(24, 0, -30) },
				Gem3 = { Pivot = V(-0.794, 1.5, 1.147), Rest = V(30, 0, 24) },
				Gem4 = { Pivot = V(1.147, 1.5, -0.794), Rest = V(-24, 0, -30) },
				Gem5 = { Pivot = V(-1.324, 1.5, -0.618), Rest = V(-18, 0, 30) },
				Gem6 = { Pivot = V(0.265, 1.5, 0.794), Rest = V(30, 0, -12) },
				Orbit1 = { Pivot = V(1.235, 0.176, 1.235), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.235, 0.882, 1.235), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.235, 0.176, -1.235), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.235, 0.882, -1.235), Rest = V(10, 0, 15) },
			},
			Colors = { C(60, 140, 240), C(236, 56, 64), C(170, 90, 235), C(80, 200, 90), C(255, 170, 40), C(236, 56, 64), C(64, 58, 72), C(250, 248, 255), C(255, 170, 40), C(60, 140, 240), C(80, 200, 90), C(170, 90, 235), C(78, 70, 90), C(70, 140, 70), C(242, 116, 121), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Foil", "Neon", "Neon", "Neon", "Neon", "Plastic", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 3 15 1 13 16 15 1
Rainbow 2 15 2 2 16 14 1
Rainbow 14 15 2 14 16 14 1
Rainbow 1 15 3 1 16 13 1
Rainbow 15 15 3 15 16 13 1
Rainbow 0 15 4 0 16 12 1
Rainbow 16 15 4 16 16 12 1
Rainbow 4 4 2 12 5 14 2
Rainbow 3 4 3 3 5 13 2
Rainbow 13 4 3 13 5 13 2
Rainbow 2 4 4 2 5 12 2
Rainbow 14 4 4 14 5 12 2
Rainbow 5 16 4 11 18 12 3
Rainbow 4 16 5 4 18 11 3
Rainbow 12 16 5 12 18 11 3
Rainbow 3 16 6 13 17 10 3
Rainbow 3 18 6 3 18 10 3
Rainbow 13 18 6 13 18 10 3
Rainbow 6 10 5 10 17 11 4
Rainbow 5 10 6 11 17 10 4
Rainbow 6 5 5 10 9 11 5
Rainbow 5 5 6 11 9 10 5
Gem1 7 17 6 9 23 8 6
Base 11 0 3 12 0 4 7
Base 3 0 4 5 0 6 7
Base 8 0 7 9 0 9 7
Base 12 0 11 14 0 12 7
Base 5 0 12 6 0 13 7
Fossil 7 6 4 9 6 4 8
Fossil 8 7 4 8 8 4 8
Fossil 7 8 4 7 10 4 8
Fossil 9 8 4 9 10 4 8
Fossil 6 9 4 6 9 4 8
Fossil 10 9 4 10 9 4 8
Fossil 8 10 4 8 12 4 8
Fossil 7 12 4 7 14 4 8
Fossil 9 12 4 9 14 4 8
Fossil 6 13 4 6 13 4 8
Fossil 10 13 4 10 13 4 8
Fossil 8 14 4 8 14 4 8
Gem2 15 15 11 16 20 12 9
Gem4 14 15 3 15 20 4 10
Gem3 3 15 14 4 19 15 11
Gem5 0 15 4 1 19 5 12
Gem6 9 15 12 10 19 13 6
Base 3 1 4 5 1 6 13
Base 12 1 11 14 1 12 13
Biome 3 6 7 3 11 7 14
Biome 1 8 7 1 10 7 14
Biome 2 8 7 2 8 7 14
Gem1 8 24 6 8 24 8 15
Gem1 7 24 7 9 24 7 15
Gem1 8 18 7 8 25 7 15
Orbit1 15 8 15 15 10 15 9
Orbit2 1 12 15 1 14 15 11
Orbit3 1 8 1 1 10 1 10
Orbit4 15 12 1 15 14 1 12
Gem2 15 21 11 15 21 11 16
Gem3 3 20 14 3 20 14 17
Gem4 14 21 3 14 21 3 18
Gem5 0 20 4 0 20 4 19
Gem6 9 20 12 9 20 12 15
Orbit1 15 11 15 15 11 15 20
Orbit2 1 15 15 1 15 15 21
Orbit3 1 11 1 1 11 1 22
Orbit4 15 15 1 15 15 1 23
]],
		},
	},
	Glacier = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.618, 0.353), Rest = V(8, 0, 24) },
				Rock2 = { Pivot = V(1.059, -0.794, -0.353), Rest = V(-10, 0, -26) },
				Rock3 = { Pivot = V(0.441, -1.059, 0.794), Rest = V(30, 0, -10) },
			},
			Colors = { C(176, 176, 178), C(182, 182, 184), C(238, 228, 200), C(244, 250, 255), C(204, 204, 205), C(200, 200, 201) },
			Materials = { "Ice", "Ice", "Plastic", "Plastic", "Ice", "Ice" },
			Boxes = [[
Rock 4 0 4 12 11 12 1
Rock 3 0 5 3 11 11 1
Rock 13 0 5 13 11 11 1
Rock 2 0 6 2 11 10 1
Rock 14 0 6 14 11 10 1
Rock 5 12 4 11 12 12 1
Rock 4 1 5 12 12 11 1
Rock 3 1 6 13 12 10 1
Rock 5 1 5 11 13 11 1
Rock 4 1 6 12 13 10 1
Rock 6 14 5 10 14 11 1
Rock 5 1 6 11 14 10 1
Rock 6 1 6 10 15 10 1
Rock 7 16 6 9 16 10 1
Rock1 1 0 9 3 9 11 2
Rock2 13 0 5 15 7 7 2
Fossil 5 2 3 11 2 3 3
Fossil 4 3 3 5 5 3 3
Fossil 6 4 3 6 5 3 3
Fossil 8 4 3 8 5 3 3
Fossil 10 4 3 10 8 3 3
Fossil 12 4 3 12 7 3 3
Fossil 7 5 3 7 9 3 3
Fossil 9 5 3 9 9 3 3
Fossil 11 5 3 11 8 3 3
Fossil 4 6 3 4 8 3 3
Fossil 5 8 3 6 9 3 3
Fossil 8 8 3 8 9 3 3
Rock3 10 0 12 11 4 13 1
Biome 3 0 0 6 0 1 4
Biome 0 0 9 1 0 10 4
Biome 11 0 15 13 0 16 4
Rock1 2 1 10 2 10 10 5
Rock2 14 1 6 14 8 6 5
Rock3 11 5 13 11 5 13 6
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.618, 0.353), Rest = V(8, 0, 24) },
				Rock2 = { Pivot = V(1.059, -0.794, -0.353), Rest = V(-10, 0, -26) },
				Rock3 = { Pivot = V(0.441, -1.059, 0.794), Rest = V(30, 0, -10) },
				Gem1 = { Pivot = V(0.088, 1.5, -0.088), Rest = V(-3, 0, -3) },
				Gem2 = { Pivot = V(0.794, 0.618, 0.441), Rest = V(15, 0, -27) },
			},
			Colors = { C(113, 184, 113), C(124, 190, 124), C(238, 228, 200), C(150, 226, 108), C(244, 250, 255), C(163, 210, 163), C(156, 205, 156), C(182, 235, 152) },
			Materials = { "Ice", "Ice", "Plastic", "Plastic", "Plastic", "Ice", "Ice", "Plastic" },
			Boxes = [[
Rock 4 0 4 12 11 12 1
Rock 3 0 5 3 11 11 1
Rock 13 0 5 13 11 11 1
Rock 2 0 6 2 11 10 1
Rock 14 0 6 14 11 10 1
Rock 5 12 4 11 12 12 1
Rock 4 1 5 12 12 11 1
Rock 3 1 6 13 12 10 1
Rock 5 1 5 11 13 11 1
Rock 4 1 6 12 13 10 1
Rock 6 14 5 10 14 11 1
Rock 5 1 6 11 14 10 1
Rock 6 1 6 10 15 10 1
Rock 7 16 6 9 16 10 1
Rock1 1 0 9 3 9 11 2
Rock2 13 0 5 15 7 7 2
Fossil 5 2 3 11 2 3 3
Fossil 4 3 3 5 5 3 3
Fossil 6 4 3 6 5 3 3
Fossil 8 4 3 8 5 3 3
Fossil 10 4 3 10 8 3 3
Fossil 12 4 3 12 7 3 3
Fossil 7 5 3 7 9 3 3
Fossil 9 5 3 9 9 3 3
Fossil 11 5 3 11 8 3 3
Fossil 4 6 3 4 8 3 3
Fossil 5 8 3 6 9 3 3
Fossil 8 8 3 8 9 3 3
Gem1 8 15 7 9 20 8 4
Rock3 10 0 12 11 4 13 1
Gem2 12 10 10 13 14 11 4
Biome 3 0 0 6 0 1 5
Biome 0 0 9 1 0 10 5
Biome 11 0 15 13 0 16 5
Rock1 2 1 10 2 10 10 6
Rock2 14 1 6 14 8 6 6
Rock3 11 5 13 11 5 13 7
Gem1 8 21 7 8 21 7 8
Gem2 12 15 10 12 15 10 8
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.618, 0.353), Rest = V(8, 0, 24) },
				Rock2 = { Pivot = V(1.059, -0.794, -0.353), Rest = V(-10, 0, -26) },
				Rock3 = { Pivot = V(0.441, -1.059, 0.794), Rest = V(30, 0, -10) },
				Gem1 = { Pivot = V(0.176, 1.324, 0), Rest = V(-3, 0, -3) },
				Gem2 = { Pivot = V(0.794, 0.618, 0.441), Rest = V(15, 0, -27) },
				Gem3 = { Pivot = V(-0.441, 0.794, 0.618), Rest = V(21, 0, 15) },
			},
			Colors = { C(88, 140, 217), C(101, 149, 220), C(120, 200, 255), C(238, 228, 200), C(244, 250, 255), C(160, 216, 255), C(147, 181, 230), C(138, 174, 228) },
			Materials = { "Ice", "Ice", "Glass", "Plastic", "Plastic", "Glass", "Ice", "Ice" },
			Boxes = [[
Rock 4 0 4 12 11 12 1
Rock 3 0 5 3 11 11 1
Rock 13 0 5 13 11 11 1
Rock 2 0 6 2 11 10 1
Rock 14 0 6 14 11 10 1
Rock 5 12 4 11 12 12 1
Rock 4 1 5 12 12 11 1
Rock 3 1 6 13 12 10 1
Rock 5 1 5 11 13 11 1
Rock 4 1 6 12 13 10 1
Rock 6 14 5 10 14 11 1
Rock 5 1 6 11 14 10 1
Rock 6 1 6 10 15 10 1
Rock 7 16 6 9 16 10 1
Rock1 1 0 9 3 9 11 2
Rock2 13 0 5 15 7 7 2
Gem1 8 14 7 10 20 9 3
Fossil 5 2 3 11 2 3 4
Fossil 4 3 3 5 5 3 4
Fossil 6 4 3 6 5 3 4
Fossil 8 4 3 8 5 3 4
Fossil 10 4 3 10 8 3 4
Fossil 12 4 3 12 7 3 4
Fossil 7 5 3 7 9 3 4
Fossil 9 5 3 9 9 3 4
Fossil 11 5 3 11 8 3 4
Fossil 4 6 3 4 8 3 4
Fossil 5 8 3 6 9 3 4
Fossil 8 8 3 8 9 3 4
Gem2 12 10 10 13 15 11 3
Rock3 10 0 12 11 4 13 1
Gem3 5 11 11 6 15 12 3
Biome 3 0 0 6 0 1 5
Biome 0 0 9 1 0 10 5
Biome 11 0 15 13 0 16 5
Gem1 9 21 7 9 21 9 6
Gem1 8 21 8 10 21 8 6
Gem1 9 15 8 9 22 8 6
Rock1 2 1 10 2 10 10 7
Rock2 14 1 6 14 8 6 7
Rock3 11 5 13 11 5 13 8
Gem2 12 16 10 12 16 10 6
Gem3 5 16 11 5 16 11 6
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.618, 0.353), Rest = V(8, 0, 24) },
				Rock2 = { Pivot = V(1.059, -0.794, -0.353), Rest = V(-10, 0, -26) },
				Rock3 = { Pivot = V(0.441, -1.059, 0.794), Rest = V(30, 0, -10) },
				Gem1 = { Pivot = V(0, 0.794, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.971, 0.618, 0.265), Rest = V(12, 0, -30) },
				Gem3 = { Pivot = V(-0.618, 0.618, 0.618), Rest = V(24, 0, 18) },
				Gem4 = { Pivot = V(-0.971, 0.618, -0.265), Rest = V(-6, 0, 30) },
			},
			Colors = { C(157, 104, 208), C(165, 116, 212), C(190, 120, 255), C(238, 228, 200), C(214, 150, 255), C(244, 250, 255), C(210, 160, 255), C(192, 158, 225), C(186, 149, 222) },
			Materials = { "Ice", "Ice", "Glass", "Plastic", "Neon", "Plastic", "Glass", "Ice", "Ice" },
			Boxes = [[
Rock 4 0 4 12 11 12 1
Rock 3 0 5 3 11 11 1
Rock 13 0 5 13 11 11 1
Rock 2 0 6 2 11 10 1
Rock 14 0 6 14 11 10 1
Rock 5 12 4 11 12 4 1
Rock 4 1 5 6 12 11 1
Rock 10 1 5 12 12 11 1
Rock 3 1 6 6 12 10 1
Rock 10 1 6 13 12 10 1
Rock 5 12 12 11 12 12 1
Rock 5 1 5 5 13 11 1
Rock 11 1 5 11 13 11 1
Rock 4 1 6 5 13 10 1
Rock 11 1 6 12 13 10 1
Rock 5 1 6 5 14 10 1
Rock 11 1 6 11 14 10 1
Rock1 1 0 9 3 9 11 2
Rock2 13 0 5 15 7 7 2
Gem1 7 11 6 9 17 8 3
Fossil 5 2 3 11 2 3 4
Fossil 4 3 3 5 5 3 4
Fossil 6 4 3 6 5 3 4
Fossil 8 4 3 8 5 3 4
Fossil 10 4 3 10 8 3 4
Fossil 12 4 3 12 7 3 4
Fossil 7 5 3 7 9 3 4
Fossil 9 5 3 9 9 3 4
Fossil 11 5 3 11 8 3 4
Fossil 4 6 3 4 8 3 4
Fossil 5 8 3 6 9 3 4
Fossil 8 8 3 8 9 3 4
Glow 7 12 5 9 12 11 5
Glow 6 13 5 6 13 11 5
Glow 10 13 5 10 13 11 5
Gem2 13 10 9 14 15 10 3
Gem4 2 10 6 3 15 7 3
Rock3 10 0 12 11 4 13 1
Gem3 4 10 11 5 14 12 3
Biome 3 0 0 6 0 1 6
Biome 0 0 9 1 0 10 6
Biome 11 0 15 13 0 16 6
Gem1 8 18 6 8 18 8 7
Gem1 7 18 7 9 18 7 7
Gem1 8 12 7 8 19 7 7
Rock1 2 1 10 2 10 10 8
Rock2 14 1 6 14 8 6 8
Rock3 11 5 13 11 5 13 9
Gem2 13 16 9 13 16 9 7
Gem3 4 15 11 4 15 11 7
Gem4 2 16 6 2 16 6 7
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.441, 0.353), Rest = V(8, 0, 24) },
				Rock2 = { Pivot = V(1.059, -0.618, -0.353), Rest = V(-10, 0, -26) },
				Rock3 = { Pivot = V(0.441, -0.882, 0.794), Rest = V(30, 0, -10) },
				Gem1 = { Pivot = V(0.176, 1.5, 0), Rest = V(-3, 0, -3) },
				Gem2 = { Pivot = V(0.794, 0.794, 0.441), Rest = V(15, 0, -27) },
				Gem3 = { Pivot = V(-0.618, 0.971, 0.441), Rest = V(15, 0, 21) },
				Gem4 = { Pivot = V(-0.618, 1.147, -0.265), Rest = V(-9, 0, 21) },
				Gem5 = { Pivot = V(0.088, 0.971, 0.618), Rest = V(21, 0, -3) },
			},
			Colors = { C(233, 148, 73), C(255, 200, 50), C(235, 157, 88), C(255, 196, 30), C(244, 250, 255), C(255, 214, 98), C(241, 186, 138), C(240, 180, 128) },
			Materials = { "Ice", "Foil", "Ice", "Neon", "Plastic", "Neon", "Ice", "Ice" },
			Boxes = [[
Rock 4 1 4 12 12 12 1
Rock 3 1 5 13 12 11 1
Rock 2 1 6 14 12 10 1
Rock 5 13 4 11 13 12 1
Rock 4 1 5 12 13 11 1
Rock 3 1 6 13 13 10 1
Rock 5 1 5 11 14 11 1
Rock 4 1 6 12 14 10 1
Rock 6 15 5 10 15 11 1
Rock 5 1 6 11 15 10 1
Rock 6 1 6 10 16 10 1
Rock 7 17 6 9 17 10 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Rock1 1 1 9 3 10 11 3
Rock2 13 1 5 15 8 7 3
Gem1 8 15 7 10 21 9 4
Fossil 5 3 3 11 3 3 2
Fossil 4 4 3 5 6 3 2
Fossil 6 5 3 6 6 3 2
Fossil 8 5 3 8 6 3 2
Fossil 10 5 3 10 9 3 2
Fossil 12 5 3 12 8 3 2
Fossil 7 6 3 7 10 3 2
Fossil 9 6 3 9 10 3 2
Fossil 11 6 3 11 9 3 2
Fossil 4 7 3 4 9 3 2
Fossil 5 9 3 6 10 3 2
Fossil 8 9 3 8 10 3 2
Gem2 12 11 10 13 16 11 4
Gem4 4 13 6 5 18 7 4
Rock3 10 1 12 11 5 13 1
Gem3 4 12 10 5 16 11 4
Gem5 8 12 11 9 16 12 4
Biome 3 1 0 6 1 1 5
Biome 0 1 9 1 1 10 5
Biome 11 1 15 13 1 16 5
Gem1 9 22 7 9 22 9 6
Gem1 8 22 8 10 22 8 6
Gem1 9 16 8 9 23 8 6
Rock1 2 2 10 2 11 10 7
Rock2 14 2 6 14 9 6 7
Rock3 11 6 13 11 6 13 8
Gem2 12 17 10 12 17 10 6
Gem3 4 17 10 4 17 10 6
Gem4 4 19 6 4 19 6 6
Gem5 8 17 11 8 17 11 6
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.618, 0.353), Rest = V(8, 0, 24) },
				Rock2 = { Pivot = V(1.059, -0.794, -0.353), Rest = V(-10, 0, -26) },
				Rock3 = { Pivot = V(0.441, -1.059, 0.794), Rest = V(30, 0, -10) },
				Gem1 = { Pivot = V(0.176, 1.324, 0), Rest = V(-3, 0, -3) },
				Gem2 = { Pivot = V(0.794, 0.618, 0.441), Rest = V(15, 0, -27) },
				Gem3 = { Pivot = V(-0.441, 0.794, 0.618), Rest = V(21, 0, 15) },
				Gem4 = { Pivot = V(-0.618, 0.971, -0.265), Rest = V(-9, 0, 21) },
				Gem5 = { Pivot = V(0.794, 0.794, -0.265), Rest = V(-9, 0, -27) },
				Float1 = { Pivot = V(-1.324, 1.147, -0.265), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.147, 1.5, -0.088), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 2.206, 0.265), Rest = V(24, -10, 16) },
			},
			Colors = { C(176, 80, 83), C(182, 94, 97), C(255, 74, 30), C(238, 228, 200), C(255, 106, 30), C(244, 250, 255), C(150, 22, 26), C(255, 128, 98), C(204, 142, 144), C(200, 132, 135) },
			Materials = { "Ice", "Ice", "Neon", "Plastic", "Neon", "Plastic", "Plastic", "Neon", "Ice", "Ice" },
			Boxes = [[
Rock 4 0 4 12 11 12 1
Rock 3 0 5 3 11 11 1
Rock 13 0 5 13 11 11 1
Rock 2 0 6 2 11 10 1
Rock 14 0 6 14 11 10 1
Rock 5 12 4 11 12 12 1
Rock 4 1 5 12 12 11 1
Rock 3 1 6 13 12 10 1
Rock 5 1 5 11 13 11 1
Rock 4 1 6 12 13 10 1
Rock 6 14 5 10 14 11 1
Rock 5 1 6 11 14 10 1
Rock 6 1 6 10 15 10 1
Rock 7 16 6 9 16 10 1
Rock1 1 0 9 3 9 11 2
Rock2 13 0 5 15 7 7 2
Gem1 8 14 7 10 19 9 3
Gem1 8 20 7 10 20 8 3
Gem1 8 20 9 9 20 9 3
Fossil 5 2 3 11 2 3 4
Fossil 4 3 3 5 5 3 4
Fossil 6 4 3 6 5 3 4
Fossil 8 4 3 8 5 3 4
Fossil 10 4 3 10 8 3 4
Fossil 12 4 3 12 7 3 4
Fossil 7 5 3 7 9 3 4
Fossil 9 5 3 9 9 3 4
Fossil 11 5 3 11 8 3 4
Fossil 4 6 3 4 8 3 4
Fossil 5 8 3 6 9 3 4
Fossil 8 8 3 8 9 3 4
Gem2 12 10 10 13 15 11 3
Gem4 4 12 6 5 17 7 3
Rock3 10 0 12 11 4 13 1
Gem3 5 11 11 6 15 12 3
Gem5 12 11 6 13 15 7 3
Glow 1 2 7 1 2 7 5
Glow 15 2 9 15 2 9 5
Glow 1 3 8 1 3 8 5
Glow 15 3 8 15 3 8 5
Glow 15 4 7 15 5 7 5
Glow 1 4 9 1 5 9 5
Glow 1 6 8 1 6 8 5
Glow 15 6 8 15 6 8 5
Glow 1 7 7 1 8 7 5
Glow 15 7 9 15 8 9 5
Glow 1 9 8 1 10 8 5
Glow 15 9 8 15 10 8 5
Biome 3 0 0 6 0 1 6
Biome 0 0 9 1 0 10 6
Biome 11 0 15 13 0 16 6
Float1 0 14 6 1 15 7 7
Float2 14 16 7 15 17 8 7
Float3 10 20 9 11 21 10 7
Gem1 9 21 7 9 21 9 8
Gem1 8 21 8 10 21 8 8
Gem1 9 15 8 9 22 8 8
Rock1 2 1 10 2 10 10 9
Rock2 14 1 6 14 8 6 9
Rock3 11 5 13 11 5 13 10
Gem2 12 16 10 12 16 10 8
Gem3 5 16 11 5 16 11 8
Gem4 4 18 6 4 18 6 8
Gem5 12 16 6 12 16 6 8
Float1 1 16 7 1 16 7 5
Float2 15 18 8 15 18 8 5
Float3 11 22 10 11 22 10 5
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rainbow1 = { Pivot = V(-1.059, 0.088, 0.353), Rest = V(8, 0, 24) },
				Rainbow2 = { Pivot = V(1.059, -0.088, -0.353), Rest = V(-10, 0, -26) },
				Rainbow3 = { Pivot = V(0.441, -0.353, 0.794), Rest = V(30, 0, -10) },
				Gem1 = { Pivot = V(0, 2.206, 0), Rest = V(-3, 0, 3) },
				Gem2 = { Pivot = V(0.794, 1.324, 0.441), Rest = V(15, 0, -27) },
				Gem3 = { Pivot = V(0.618, 1.5, -0.441), Rest = V(-15, 0, -21) },
				Gem4 = { Pivot = V(-0.441, 1.5, 0.618), Rest = V(21, 0, 15) },
				Gem5 = { Pivot = V(0.088, 1.853, 0.441), Rest = V(15, 0, -3) },
				Gem6 = { Pivot = V(-0.618, 1.676, 0.088), Rest = V(3, 0, 21) },
				Orbit1 = { Pivot = V(1.059, 0.529, 1.059), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.059, 0.882, 1.059), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.059, 0.529, -1.059), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.059, 0.882, -1.059), Rest = V(10, 0, 15) },
			},
			Colors = { C(236, 56, 64), C(170, 90, 235), C(60, 140, 240), C(255, 170, 40), C(80, 200, 90), C(236, 56, 64), C(250, 248, 255), C(64, 58, 72), C(255, 170, 40), C(60, 140, 240), C(80, 200, 90), C(170, 90, 235), C(78, 70, 90), C(242, 116, 121), C(255, 196, 104), C(242, 116, 121), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Ice", "Ice", "Ice", "Ice", "Ice", "Neon", "Foil", "Plastic", "Neon", "Neon", "Neon", "Neon", "Plastic", "Neon", "Ice", "Ice", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 4 4 4 12 6 12 1
Rainbow 3 4 5 3 6 11 1
Rainbow 13 4 5 13 6 11 1
Rainbow 2 4 6 2 6 10 1
Rainbow 14 4 6 14 6 10 1
Rainbow 5 16 4 11 16 12 2
Rainbow 4 5 5 12 16 11 2
Rainbow 3 5 6 13 16 10 2
Rainbow 5 5 5 11 17 11 2
Rainbow 4 5 6 12 17 10 2
Rainbow 6 18 5 10 18 11 2
Rainbow 5 5 6 11 18 10 2
Rainbow 6 5 6 10 19 10 2
Rainbow 7 20 6 9 20 10 2
Rainbow 4 13 4 12 15 12 3
Rainbow 3 13 5 13 15 11 3
Rainbow 2 13 6 14 15 10 3
Rainbow 4 7 4 12 9 12 4
Rainbow 3 7 5 13 9 11 4
Rainbow 2 7 6 14 9 10 4
Rainbow 4 10 4 12 12 12 5
Rainbow 3 10 5 13 12 11 5
Rainbow 2 10 6 14 12 10 5
Rainbow1 1 4 9 3 13 11 4
Rainbow2 13 4 5 15 11 7 4
Gem1 7 19 7 9 25 9 6
Fossil 5 6 3 11 6 3 7
Fossil 4 7 3 5 9 3 7
Fossil 6 8 3 6 9 3 7
Fossil 8 8 3 8 9 3 7
Fossil 10 8 3 10 12 3 7
Fossil 12 8 3 12 11 3 7
Fossil 7 9 3 7 13 3 7
Fossil 9 9 3 9 13 3 7
Fossil 11 9 3 11 12 3 7
Fossil 4 10 3 4 12 3 7
Fossil 5 12 3 6 13 3 7
Fossil 8 12 3 8 13 3 7
Base 11 0 3 12 0 4 8
Base 3 0 4 5 0 6 8
Base 8 0 7 9 0 9 8
Base 12 0 11 14 0 12 8
Base 5 0 12 6 0 13 8
Gem2 12 14 10 13 19 11 9
Gem4 5 15 11 6 20 12 10
Rainbow3 10 4 12 11 8 13 1
Gem3 11 15 5 12 19 6 11
Gem5 8 17 10 9 21 11 12
Gem6 4 16 8 5 20 9 6
Base 3 1 4 5 1 6 13
Base 12 1 11 14 1 12 13
Gem1 8 26 7 8 26 9 14
Gem1 7 26 8 9 26 8 14
Gem1 8 20 8 8 27 8 14
Orbit1 14 10 14 14 12 14 9
Orbit2 2 12 14 2 14 14 11
Orbit3 2 10 2 2 12 2 10
Orbit4 14 12 2 14 14 2 12
Rainbow1 2 5 10 2 14 10 15
Rainbow2 14 5 6 14 12 6 15
Rainbow3 11 9 13 11 9 13 16
Gem2 12 20 10 12 20 10 17
Gem3 11 20 5 11 20 5 18
Gem4 5 21 11 5 21 11 19
Gem5 8 22 10 8 22 10 20
Gem6 4 21 8 4 21 8 14
Orbit1 14 13 14 14 13 14 21
Orbit2 2 15 14 2 15 14 22
Orbit3 2 13 2 2 13 2 23
Orbit4 14 15 2 14 15 2 24
]],
		},
	},
	Volcano = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {},
			Colors = { C(150, 149, 152), C(117, 116, 119), C(255, 112, 40), C(238, 228, 200), C(44, 38, 40) },
			Materials = { "Plastic", "Plastic", "Neon", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 15 1
Rock 2 2 2 2 3 14 1
Rock 14 2 2 14 3 14 1
Rock 1 2 3 15 2 13 1
Rock 1 3 3 1 3 13 1
Rock 15 3 3 15 3 13 1
Rock 5 1 3 11 7 13 1
Rock 4 1 4 12 7 12 1
Rock 3 1 5 13 7 11 1
Rock 5 1 4 11 10 12 1
Rock 4 1 5 12 9 11 1
Rock 4 10 5 4 10 11 1
Rock 12 10 5 12 10 11 1
Rock 6 1 5 10 13 6 1
Rock 5 1 6 5 13 10 1
Rock 11 1 6 11 13 10 1
Rock 6 1 10 10 13 11 1
Rock 6 1 7 6 13 9 1
Rock 10 1 7 10 13 9 1
Rock 3 0 1 13 1 15 2
Rock 2 0 2 2 1 14 2
Rock 14 0 2 14 1 14 2
Rock 1 0 3 1 1 13 2
Rock 15 0 3 15 1 13 2
Ember 9 1 16 9 3 16 3
Ember 3 4 4 3 4 4 3
Ember 8 4 14 8 7 14 3
Ember 9 4 14 9 4 14 3
Ember 8 8 13 8 10 13 3
Ember 12 11 6 12 11 6 3
Ember 7 11 7 9 11 9 3
Ember 8 11 12 8 12 12 3
Fossil 6 0 0 10 1 0 4
Fossil 5 1 0 5 2 0 4
Fossil 11 1 0 11 2 0 4
Fossil 4 2 0 4 3 0 4
Fossil 8 2 0 8 3 0 4
Fossil 12 2 0 12 3 0 4
Fossil 8 4 2 8 4 2 4
Fossil 4 4 3 4 4 3 4
Fossil 12 4 3 12 4 3 4
Biome 14 0 1 14 0 1 5
Biome 0 0 3 0 1 3 5
Biome 16 0 12 16 0 12 5
Biome 3 0 16 3 0 16 5
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0.088, 0.618, -0.265), Rest = V(-9, 0, -3) },
				Gem2 = { Pivot = V(-0.441, -0.088, 0.794), Rest = V(27, 0, 15) },
			},
			Colors = { C(66, 160, 66), C(51, 125, 51), C(255, 112, 40), C(150, 226, 108), C(238, 228, 200), C(44, 38, 40), C(182, 235, 152) },
			Materials = { "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 3 2 1 13 3 15 1
Rock 2 2 2 2 3 14 1
Rock 14 2 2 14 3 14 1
Rock 1 2 3 15 2 13 1
Rock 1 3 3 1 3 13 1
Rock 15 3 3 15 3 13 1
Rock 5 1 3 11 7 13 1
Rock 4 1 4 12 7 12 1
Rock 3 1 5 13 7 11 1
Rock 5 1 4 11 10 12 1
Rock 4 1 5 12 9 11 1
Rock 4 10 5 4 10 11 1
Rock 12 10 5 12 10 11 1
Rock 6 1 5 10 13 6 1
Rock 5 1 6 5 13 10 1
Rock 11 1 6 11 13 10 1
Rock 6 1 10 10 13 11 1
Rock 6 1 7 6 13 9 1
Rock 10 1 7 10 13 9 1
Rock 3 0 1 13 1 15 2
Rock 2 0 2 2 1 14 2
Rock 14 0 2 14 1 14 2
Rock 1 0 3 1 1 13 2
Rock 15 0 3 15 1 13 2
Ember 9 1 16 9 3 16 3
Ember 3 4 4 3 4 4 3
Ember 8 4 14 8 7 14 3
Ember 9 4 14 9 4 14 3
Ember 8 8 13 8 10 13 3
Ember 12 11 6 12 11 6 3
Ember 7 11 7 9 11 9 3
Ember 8 11 12 8 12 12 3
Gem1 8 10 6 9 15 7 4
Fossil 6 0 0 10 1 0 5
Fossil 5 1 0 5 2 0 5
Fossil 11 1 0 11 2 0 5
Fossil 4 2 0 4 3 0 5
Fossil 8 2 0 8 3 0 5
Fossil 12 2 0 12 3 0 5
Fossil 8 4 2 8 4 2 5
Fossil 4 4 3 4 4 3 5
Fossil 12 4 3 12 4 3 5
Gem2 5 6 12 6 10 13 4
Biome 14 0 1 14 0 1 6
Biome 0 0 3 0 1 3 6
Biome 16 0 12 16 0 12 6
Biome 3 0 16 3 0 16 6
Gem1 8 16 6 8 16 6 7
Gem2 5 11 12 5 11 12 7
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0.176, 0.618, -0.176), Rest = V(-9, 0, -3) },
				Gem2 = { Pivot = V(-0.441, -0.088, 0.794), Rest = V(27, 0, 15) },
				Gem3 = { Pivot = V(0.794, -0.794, 0.618), Rest = V(21, 0, -27) },
			},
			Colors = { C(32, 102, 204), C(25, 80, 159), C(120, 200, 255), C(255, 112, 40), C(238, 228, 200), C(44, 38, 40), C(160, 216, 255) },
			Materials = { "Plastic", "Plastic", "Glass", "Neon", "Plastic", "Plastic", "Glass" },
			Boxes = [[
Rock 3 2 1 13 3 15 1
Rock 2 2 2 2 3 14 1
Rock 14 2 2 14 3 14 1
Rock 1 2 3 15 2 13 1
Rock 1 3 3 1 3 13 1
Rock 15 3 3 15 3 13 1
Rock 5 1 3 11 7 13 1
Rock 4 1 4 12 7 12 1
Rock 3 1 5 13 7 11 1
Rock 5 1 4 11 10 12 1
Rock 4 1 5 12 9 11 1
Rock 4 10 5 4 10 11 1
Rock 12 10 5 12 10 11 1
Rock 6 1 5 10 13 6 1
Rock 5 1 6 5 13 10 1
Rock 11 1 6 11 13 10 1
Rock 6 1 10 10 13 11 1
Rock 6 1 7 6 13 9 1
Rock 10 1 7 10 13 9 1
Rock 3 0 1 13 1 15 2
Rock 2 0 2 2 1 14 2
Rock 14 0 2 14 1 14 2
Rock 1 0 3 1 1 13 2
Rock 15 0 3 15 1 13 2
Gem1 8 10 6 10 16 8 3
Ember 9 1 16 9 3 16 4
Ember 3 4 4 3 4 4 4
Ember 8 4 14 8 7 14 4
Ember 9 4 14 9 4 14 4
Ember 8 8 13 8 10 13 4
Ember 12 11 6 12 11 6 4
Ember 7 11 7 9 11 9 4
Ember 8 11 12 8 12 12 4
Gem2 5 6 12 6 11 13 3
Fossil 6 0 0 10 1 0 5
Fossil 5 1 0 5 2 0 5
Fossil 11 1 0 11 2 0 5
Fossil 4 2 0 4 3 0 5
Fossil 8 2 0 8 3 0 5
Fossil 12 2 0 12 3 0 5
Fossil 8 4 2 8 4 2 5
Fossil 4 4 3 4 4 3 5
Fossil 12 4 3 12 4 3 5
Gem3 12 2 11 13 6 12 3
Biome 14 0 1 14 0 1 6
Biome 0 0 3 0 1 3 6
Biome 16 0 12 16 0 12 6
Biome 3 0 16 3 0 16 6
Gem1 9 17 6 9 17 8 7
Gem1 8 17 7 10 17 7 7
Gem1 9 11 7 9 18 7 7
Gem2 5 12 12 5 12 12 7
Gem3 12 7 11 12 7 11 7
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0.176, 0.265, -0.176), Rest = V(-9, 0, -3) },
				Gem2 = { Pivot = V(-0.441, -0.088, 0.794), Rest = V(27, 0, 15) },
				Gem3 = { Pivot = V(0.794, -0.794, 0.618), Rest = V(21, 0, -27) },
				Gem4 = { Pivot = V(0.794, -0.088, -0.441), Rest = V(-15, 0, -27) },
			},
			Colors = { C(124, 54, 192), C(97, 42, 150), C(190, 120, 255), C(214, 150, 255), C(238, 228, 200), C(255, 112, 40), C(44, 38, 40), C(210, 160, 255) },
			Materials = { "Plastic", "Plastic", "Glass", "Neon", "Plastic", "Neon", "Plastic", "Glass" },
			Boxes = [[
Rock 3 2 1 13 3 15 1
Rock 2 2 2 2 3 14 1
Rock 14 2 2 14 3 14 1
Rock 1 2 3 15 2 13 1
Rock 1 3 3 1 3 13 1
Rock 15 3 3 15 3 13 1
Rock 5 1 3 11 7 13 1
Rock 4 1 4 12 7 12 1
Rock 3 1 5 13 7 11 1
Rock 5 1 4 11 8 12 1
Rock 4 1 5 5 10 11 1
Rock 11 1 5 12 10 11 1
Rock 5 9 4 6 9 12 1
Rock 10 9 4 11 9 12 1
Rock 5 10 4 5 10 4 1
Rock 11 10 4 11 10 4 1
Rock 5 10 12 5 10 12 1
Rock 11 10 12 11 10 12 1
Rock 5 1 6 5 12 10 1
Rock 11 1 6 11 12 10 1
Rock 3 0 1 13 1 15 2
Rock 2 0 2 2 1 14 2
Rock 14 0 2 14 1 14 2
Rock 1 0 3 1 1 13 2
Rock 15 0 3 15 1 13 2
Gem1 8 8 6 10 14 8 3
Glow 7 9 4 9 9 12 4
Glow 6 10 4 6 10 12 4
Glow 10 10 4 10 10 12 4
Gem2 5 6 12 6 11 13 3
Gem4 12 6 5 13 11 6 3
Fossil 6 0 0 10 1 0 5
Fossil 5 1 0 5 2 0 5
Fossil 11 1 0 11 2 0 5
Fossil 4 2 0 4 3 0 5
Fossil 8 2 0 8 3 0 5
Fossil 12 2 0 12 3 0 5
Fossil 8 4 2 8 4 2 5
Fossil 4 4 3 4 4 3 5
Fossil 12 4 3 12 4 3 5
Ember 9 1 16 9 3 16 6
Ember 3 4 4 3 4 4 6
Ember 8 4 14 8 7 14 6
Ember 9 4 14 9 4 14 6
Ember 8 8 13 8 9 13 6
Ember 12 11 6 12 11 6 6
Ember 7 11 7 9 11 9 6
Gem3 12 2 11 13 6 12 3
Biome 14 0 1 14 0 1 7
Biome 0 0 3 0 1 3 7
Biome 16 0 12 16 0 12 7
Biome 3 0 16 3 0 16 7
Gem1 9 15 6 9 15 8 8
Gem1 8 15 7 10 15 7 8
Gem1 9 9 7 9 16 7 8
Gem2 5 12 12 5 12 12 8
Gem3 12 7 11 12 7 11 8
Gem4 12 12 5 12 12 5 8
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 0.794, -0.176), Rest = V(-9, 0, 3) },
				Gem2 = { Pivot = V(0.618, -0.618, 0.794), Rest = V(27, 0, -21) },
				Gem3 = { Pivot = V(-0.441, 0.088, 0.794), Rest = V(27, 0, 15) },
				Gem4 = { Pivot = V(0.794, 0.088, -0.441), Rest = V(-15, 0, -27) },
				Gem5 = { Pivot = V(0.265, 0.794, 0.265), Rest = V(9, 0, -9) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(176, 87, 9), C(255, 196, 30), C(255, 112, 40), C(44, 38, 40), C(255, 214, 98) },
			Materials = { "Plastic", "Foil", "Plastic", "Neon", "Neon", "Plastic", "Neon" },
			Boxes = [[
Rock 3 3 1 13 4 15 1
Rock 2 3 2 2 4 14 1
Rock 14 3 2 14 4 14 1
Rock 1 3 3 15 3 13 1
Rock 1 4 3 1 4 13 1
Rock 15 4 3 15 4 13 1
Rock 5 1 3 11 8 13 1
Rock 4 1 4 12 8 12 1
Rock 3 1 5 13 8 11 1
Rock 5 1 4 11 11 12 1
Rock 4 1 5 12 10 11 1
Rock 4 11 5 4 11 11 1
Rock 12 11 5 12 11 11 1
Rock 6 1 5 10 14 6 1
Rock 5 1 6 5 14 10 1
Rock 11 1 6 11 14 10 1
Rock 6 1 10 10 14 11 1
Rock 6 1 7 6 14 9 1
Rock 10 1 7 10 14 9 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Rock 3 1 1 13 2 15 3
Rock 2 1 2 14 2 14 3
Rock 1 1 3 15 2 13 3
Gem1 7 11 6 9 17 8 4
Ember 9 2 16 9 4 16 5
Ember 3 5 4 3 5 4 5
Ember 8 5 14 8 8 14 5
Ember 9 5 14 9 5 14 5
Ember 8 9 13 8 11 13 5
Ember 12 12 6 12 12 6 5
Ember 7 12 7 9 12 9 5
Ember 8 12 12 8 13 12 5
Gem2 11 3 12 12 8 13 4
Gem4 12 7 5 13 12 6 4
Fossil 6 1 0 10 2 0 2
Fossil 5 2 0 5 3 0 2
Fossil 11 2 0 11 3 0 2
Fossil 4 3 0 4 4 0 2
Fossil 8 3 0 8 4 0 2
Fossil 12 3 0 12 4 0 2
Fossil 8 5 2 8 5 2 2
Fossil 4 5 3 4 5 3 2
Fossil 12 5 3 12 5 3 2
Gem3 5 7 12 6 11 13 4
Gem5 9 11 9 10 15 10 4
Biome 14 1 1 14 1 1 6
Biome 0 1 3 0 2 3 6
Biome 16 1 12 16 1 12 6
Biome 3 1 16 3 1 16 6
Gem1 8 18 6 8 18 8 7
Gem1 7 18 7 9 18 7 7
Gem1 8 12 7 8 19 7 7
Gem2 11 9 12 11 9 12 7
Gem3 5 12 12 5 12 12 7
Gem4 12 13 5 12 13 5 7
Gem5 9 16 9 9 16 9 7
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0.176, 0.618, -0.176), Rest = V(-9, 0, -3) },
				Gem2 = { Pivot = V(-0.441, -0.088, 0.794), Rest = V(27, 0, 15) },
				Gem3 = { Pivot = V(0.794, -0.794, 0.618), Rest = V(21, 0, -27) },
				Gem4 = { Pivot = V(0.794, -0.088, -0.441), Rest = V(-15, 0, -27) },
				Gem5 = { Pivot = V(-0.618, 0.441, -0.441), Rest = V(-15, 0, 21) },
				Float1 = { Pivot = V(-1.5, 0.618, -0.794), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.324, 0.794, 0.441), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 1.5, 0.794), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(117, 17, 20), C(255, 74, 30), C(255, 112, 40), C(238, 228, 200), C(255, 106, 30), C(44, 38, 40), C(255, 128, 98) },
			Materials = { "Plastic", "Plastic", "Neon", "Neon", "Plastic", "Neon", "Plastic", "Neon" },
			Boxes = [[
Rock 3 2 1 13 3 15 1
Rock 2 2 2 2 3 14 1
Rock 14 2 2 14 3 14 1
Rock 1 2 3 1 3 13 1
Rock 15 2 3 15 3 13 1
Rock 5 1 3 11 7 13 1
Rock 4 1 4 12 7 12 1
Rock 3 1 5 13 7 11 1
Rock 5 1 4 11 10 12 1
Rock 4 1 5 12 9 11 1
Rock 4 10 5 4 10 11 1
Rock 12 10 5 12 10 11 1
Rock 6 1 5 10 13 6 1
Rock 5 1 6 5 13 10 1
Rock 11 1 6 11 13 10 1
Rock 6 1 10 10 13 11 1
Rock 6 1 7 6 13 9 1
Rock 10 1 7 10 13 9 1
Rock 3 0 1 13 1 15 2
Rock 2 0 2 2 1 14 2
Rock 14 0 2 14 1 14 2
Rock 1 0 3 1 1 13 2
Rock 15 0 3 15 1 13 2
Gem1 8 10 6 10 16 8 3
Ember 9 1 16 9 3 16 4
Ember 3 4 4 3 4 4 4
Ember 8 4 14 8 7 14 4
Ember 9 4 14 9 4 14 4
Ember 8 8 13 8 10 13 4
Ember 12 11 6 12 11 6 4
Ember 7 11 7 9 11 9 4
Ember 8 11 12 8 12 12 4
Gem2 5 6 12 6 11 13 3
Gem4 12 6 5 13 11 6 3
Fossil 6 0 0 10 1 0 5
Fossil 5 1 0 5 2 0 5
Fossil 11 1 0 11 2 0 5
Fossil 4 2 0 4 3 0 5
Fossil 8 2 0 8 3 0 5
Fossil 12 2 0 12 3 0 5
Fossil 8 4 2 8 4 2 5
Fossil 4 4 3 4 4 3 5
Fossil 12 4 3 12 4 3 5
Gem3 12 2 11 13 6 12 3
Gem5 4 9 5 5 13 6 3
Glow 0 2 7 0 2 7 6
Glow 16 2 9 16 2 9 6
Glow 0 3 8 0 3 8 6
Glow 16 3 8 16 3 8 6
Glow 14 4 7 14 5 7 6
Glow 2 4 9 2 5 9 6
Glow 2 6 8 2 6 8 6
Glow 14 6 8 14 6 8 6
Glow 2 7 7 2 7 7 6
Glow 14 7 9 14 7 9 6
Glow 3 8 7 3 8 7 6
Glow 13 8 9 13 8 9 6
Glow 3 9 8 3 10 8 6
Glow 13 9 8 13 10 8 6
Float1 -1 11 3 0 12 4 1
Float2 15 12 10 16 13 11 1
Float3 10 16 12 11 17 13 1
Biome 14 0 1 14 0 1 7
Biome 0 0 3 0 1 3 7
Biome 16 0 12 16 0 12 7
Biome 3 0 16 3 0 16 7
Gem1 9 17 6 9 17 8 8
Gem1 8 17 7 10 17 7 8
Gem1 9 11 7 9 18 7 8
Gem2 5 12 12 5 12 12 8
Gem3 12 7 11 12 7 11 8
Gem4 12 12 5 12 12 5 8
Gem5 4 14 5 4 14 5 8
Float1 0 13 4 0 13 4 6
Float2 16 14 11 16 14 11 6
Float3 11 18 13 11 18 13 6
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Gem1 = { Pivot = V(0, 1.324, -0.176), Rest = V(-9, 0, 3) },
				Gem2 = { Pivot = V(0.618, -0.088, 0.794), Rest = V(27, 0, -21) },
				Gem3 = { Pivot = V(-0.441, 0.618, 0.794), Rest = V(27, 0, 15) },
				Gem4 = { Pivot = V(0.794, 0.618, -0.441), Rest = V(-15, 0, -27) },
				Gem5 = { Pivot = V(0.088, 1.676, 0.441), Rest = V(15, 0, -3) },
				Gem6 = { Pivot = V(-0.618, 1.147, 0.088), Rest = V(3, 0, 21) },
				Orbit1 = { Pivot = V(1.235, 0.176, 1.235), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.235, 0.706, 1.235), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.235, 0.176, -1.235), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.235, 0.706, -1.235), Rest = V(10, 0, 15) },
			},
			Colors = { C(236, 56, 64), C(255, 170, 40), C(80, 200, 90), C(170, 90, 235), C(236, 56, 64), C(64, 58, 72), C(255, 112, 40), C(255, 170, 40), C(60, 140, 240), C(250, 248, 255), C(80, 200, 90), C(170, 90, 235), C(60, 140, 240), C(78, 70, 90), C(242, 116, 121), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Neon", "Foil", "Neon", "Neon", "Plastic", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 3 4 1 13 7 15 1
Rainbow 2 4 2 2 7 14 1
Rainbow 14 4 2 14 7 14 1
Rainbow 1 4 3 1 7 13 1
Rainbow 15 4 3 15 7 13 1
Rainbow 5 5 3 11 11 13 2
Rainbow 4 5 4 12 11 12 2
Rainbow 3 5 5 13 11 11 2
Rainbow 5 5 4 11 14 12 3
Rainbow 4 5 5 12 13 11 3
Rainbow 4 14 5 4 14 11 3
Rainbow 12 14 5 12 14 11 3
Rainbow 6 16 5 10 17 6 4
Rainbow 5 16 6 5 17 10 4
Rainbow 11 16 6 11 17 10 4
Rainbow 6 5 7 6 17 10 4
Rainbow 10 5 7 10 17 10 4
Rainbow 7 16 10 9 17 11 4
Rainbow 6 16 11 6 17 11 4
Rainbow 10 16 11 10 17 11 4
Gem1 7 14 6 9 20 8 5
Base 11 0 3 12 0 4 6
Base 3 0 4 5 0 6 6
Base 8 0 7 9 0 9 6
Base 12 0 11 14 0 12 6
Base 5 0 12 6 0 13 6
Ember 9 5 16 9 7 16 7
Ember 3 8 4 3 8 4 7
Ember 8 8 14 8 11 14 7
Ember 9 8 14 9 8 14 7
Ember 8 12 13 8 14 13 7
Ember 12 15 6 12 15 6 7
Ember 7 15 7 9 15 9 7
Ember 8 15 12 8 16 12 7
Gem2 11 6 12 12 11 13 8
Gem4 12 10 5 13 15 6 9
Fossil 6 4 0 10 5 0 10
Fossil 5 5 0 5 6 0 10
Fossil 11 5 0 11 6 0 10
Fossil 4 6 0 4 7 0 10
Fossil 8 6 0 8 7 0 10
Fossil 12 6 0 12 7 0 10
Fossil 8 8 2 8 8 2 10
Fossil 4 8 3 4 8 3 10
Fossil 12 8 3 12 8 3 10
Gem3 5 10 12 6 14 13 11
Gem5 8 16 10 9 20 11 12
Gem6 4 13 8 5 17 9 5
Rainbow 6 5 5 10 15 6 13
Rainbow 5 5 6 6 15 10 13
Rainbow 10 5 6 11 15 10 13
Rainbow 6 5 10 10 15 11 13
Base 3 1 4 5 1 6 14
Base 12 1 11 14 1 12 14
Gem1 8 21 6 8 21 8 15
Gem1 7 21 7 9 21 7 15
Gem1 8 15 7 8 22 7 15
Orbit1 15 8 15 15 10 15 8
Orbit2 1 11 15 1 13 15 11
Orbit3 1 8 1 1 10 1 9
Orbit4 15 11 1 15 13 1 12
Gem2 11 12 12 11 12 12 16
Gem3 5 15 12 5 15 12 17
Gem4 12 16 5 12 16 5 18
Gem5 8 21 10 8 21 10 19
Gem6 4 18 8 4 18 8 15
Orbit1 15 11 15 15 11 15 20
Orbit2 1 14 15 1 14 15 21
Orbit3 1 11 1 1 11 1 22
Orbit4 15 14 1 15 14 1 23
]],
		},
	},
	["Ocean Trench"] = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -1.147, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, -0.529, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, -0.176, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, -0.088, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, -0.176, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, -0.529, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -1.147, -0.706), Rest = V(0, 0, -64) },
			},
			Colors = { C(150, 149, 152), C(117, 116, 119), C(214, 196, 150), C(238, 228, 200), C(60, 150, 92), C(244, 108, 140), C(210, 214, 218) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 5 12 13 11 1
Rock 3 2 6 13 12 10 1
Rock 3 3 5 3 12 5 1
Rock 13 3 5 13 12 5 1
Rock 3 3 11 3 12 11 1
Rock 13 3 11 13 12 11 1
Rock 2 4 5 2 12 11 1
Rock 14 4 5 14 12 11 1
Rock 1 5 5 1 10 11 1
Rock 15 5 5 15 10 11 1
Rock 0 6 5 0 9 11 1
Rock 16 6 5 16 9 11 1
Rock 5 14 5 11 14 11 1
Rock 6 0 5 10 1 11 2
Rock 3 0 6 5 1 10 2
Rock 11 0 6 13 1 10 2
Rock 5 1 5 5 1 11 2
Rock 11 1 5 11 1 11 2
Biome 3 0 3 13 0 4 3
Biome 2 0 4 2 0 12 3
Biome 14 0 4 14 0 12 3
Biome 1 0 5 1 0 7 3
Biome 3 0 5 5 0 5 3
Biome 11 0 5 13 0 5 3
Biome 15 0 5 15 0 6 3
Biome 15 0 8 15 0 11 3
Biome 1 0 9 1 0 11 3
Biome 3 0 11 5 0 13 3
Biome 11 0 11 13 0 11 3
Biome 6 0 12 11 0 13 3
Biome 13 0 12 13 0 13 3
Biome 12 0 13 12 0 13 3
Fossil4 8 0 4 8 15 4 4
Fossil3 5 0 4 5 14 4 4
Fossil2 4 -1 4 4 11 4 4
Fossil6 12 -1 4 12 11 4 4
Fossil5 11 5 4 11 14 4 4
Biome 15 0 7 15 3 7 5
Biome 1 0 8 1 4 8 5
Fossil7 11 -1 4 11 4 4 4
Biome 12 0 12 12 2 12 6
Biome 11 2 12 11 2 12 6
Biome 5 2 12 6 2 12 7
Biome 11 3 12 11 3 12 7
Biome 10 6 12 10 6 12 7
Fossil1 5 -1 4 5 -1 4 4
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -1.147, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, -0.529, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, -0.176, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, -0.088, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, -0.176, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, -0.529, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -1.147, -0.706), Rest = V(0, 0, -64) },
				Gem1 = { Pivot = V(-0.088, 1.147, -0.265), Rest = V(-6, 0, 3) },
				Gem2 = { Pivot = V(1.147, 0.441, 0.441), Rest = V(18, 0, -30) },
			},
			Colors = { C(66, 160, 66), C(51, 125, 51), C(214, 196, 150), C(150, 226, 108), C(238, 228, 200), C(60, 150, 92), C(244, 108, 140), C(210, 214, 218), C(182, 235, 152) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 5 12 13 11 1
Rock 3 2 6 13 12 10 1
Rock 3 3 5 3 12 5 1
Rock 13 3 5 13 12 5 1
Rock 3 3 11 3 12 11 1
Rock 13 3 11 13 12 11 1
Rock 2 4 5 2 12 11 1
Rock 14 4 5 14 12 11 1
Rock 1 5 5 1 10 11 1
Rock 15 5 5 15 10 11 1
Rock 0 6 5 0 9 11 1
Rock 16 6 5 16 9 11 1
Rock 5 14 5 11 14 11 1
Rock 6 0 5 10 1 11 2
Rock 3 0 6 5 1 10 2
Rock 11 0 6 13 1 10 2
Rock 5 1 5 5 1 11 2
Rock 11 1 5 11 1 11 2
Biome 3 0 3 13 0 4 3
Biome 2 0 4 2 0 12 3
Biome 14 0 4 14 0 12 3
Biome 1 0 5 1 0 7 3
Biome 3 0 5 5 0 5 3
Biome 11 0 5 13 0 5 3
Biome 15 0 5 15 0 6 3
Biome 15 0 8 15 0 11 3
Biome 1 0 9 1 0 11 3
Biome 3 0 11 5 0 13 3
Biome 11 0 11 13 0 11 3
Biome 6 0 12 11 0 13 3
Biome 13 0 12 13 0 13 3
Biome 12 0 13 12 0 13 3
Gem1 7 13 6 8 18 7 4
Gem2 14 9 10 15 13 11 4
Fossil4 8 0 4 8 15 4 5
Fossil3 5 0 4 5 14 4 5
Fossil2 4 -1 4 4 11 4 5
Fossil6 12 -1 4 12 11 4 5
Fossil5 11 5 4 11 14 4 5
Biome 15 0 7 15 3 7 6
Biome 1 0 8 1 4 8 6
Fossil7 11 -1 4 11 4 4 5
Biome 12 0 12 12 2 12 7
Biome 11 2 12 11 2 12 7
Biome 5 2 12 6 2 12 8
Biome 11 3 12 11 3 12 8
Biome 10 6 12 10 6 12 8
Fossil1 5 -1 4 5 -1 4 5
Gem1 7 19 6 7 19 6 9
Gem2 14 14 10 14 14 10 9
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -1.147, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, -0.529, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, -0.176, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, -0.088, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, -0.176, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, -0.529, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -1.147, -0.706), Rest = V(0, 0, -64) },
				Gem1 = { Pivot = V(0, 1.147, -0.176), Rest = V(-6, 0, 3) },
				Gem2 = { Pivot = V(1.147, 0.441, 0.441), Rest = V(18, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.794, 0.441), Rest = V(18, 0, 30) },
			},
			Colors = { C(32, 102, 204), C(25, 80, 159), C(214, 196, 150), C(120, 200, 255), C(238, 228, 200), C(60, 150, 92), C(160, 216, 255), C(244, 108, 140), C(210, 214, 218) },
			Materials = { "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Plastic", "Glass", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 5 12 13 11 1
Rock 3 2 6 13 12 10 1
Rock 3 3 5 3 12 5 1
Rock 13 3 5 13 12 5 1
Rock 3 3 11 3 12 11 1
Rock 13 3 11 13 12 11 1
Rock 2 4 5 2 12 11 1
Rock 14 4 5 14 12 11 1
Rock 1 5 5 1 10 11 1
Rock 15 5 5 15 10 11 1
Rock 0 6 5 0 9 11 1
Rock 16 6 5 16 9 11 1
Rock 5 14 5 11 14 11 1
Rock 6 0 5 10 1 11 2
Rock 3 0 6 5 1 10 2
Rock 11 0 6 13 1 10 2
Rock 5 1 5 5 1 11 2
Rock 11 1 5 11 1 11 2
Biome 3 0 3 13 0 4 3
Biome 2 0 4 2 0 12 3
Biome 14 0 4 14 0 12 3
Biome 1 0 5 1 0 7 3
Biome 3 0 5 5 0 5 3
Biome 11 0 5 13 0 5 3
Biome 15 0 5 15 0 6 3
Biome 15 0 8 15 0 11 3
Biome 1 0 9 1 0 11 3
Biome 3 0 11 5 0 13 3
Biome 11 0 11 13 0 11 3
Biome 6 0 12 11 0 13 3
Biome 13 0 12 13 0 13 3
Biome 12 0 13 12 0 13 3
Gem1 7 13 6 9 19 8 4
Gem2 14 9 10 15 14 11 4
Gem3 2 11 10 3 15 11 4
Fossil4 8 0 4 8 15 4 5
Fossil3 5 0 4 5 14 4 5
Fossil2 4 -1 4 4 11 4 5
Fossil6 12 -1 4 12 11 4 5
Fossil5 11 5 4 11 14 4 5
Biome 15 0 7 15 3 7 6
Biome 1 0 8 1 4 8 6
Fossil7 11 -1 4 11 4 4 5
Gem1 8 20 6 8 20 8 7
Gem1 7 20 7 9 20 7 7
Gem1 8 14 7 8 21 7 7
Biome 12 0 12 12 2 12 8
Biome 11 2 12 11 2 12 8
Biome 5 2 12 6 2 12 9
Biome 11 3 12 11 3 12 9
Biome 10 6 12 10 6 12 9
Fossil1 5 -1 4 5 -1 4 5
Gem2 14 15 10 14 15 10 7
Gem3 2 16 10 2 16 10 7
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -1.147, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, -0.529, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, -0.176, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, -0.088, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, -0.176, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, -0.529, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -1.147, -0.706), Rest = V(0, 0, -64) },
				Gem1 = { Pivot = V(0.176, 0.441, -0.176), Rest = V(-6, 0, -3) },
				Gem2 = { Pivot = V(-1.147, 0.441, 0.441), Rest = V(18, 0, 30) },
				Gem3 = { Pivot = V(1.324, 0.265, 0.441), Rest = V(18, 0, -30) },
				Gem4 = { Pivot = V(1.147, 0.441, -0.441), Rest = V(-12, 0, -30) },
			},
			Colors = { C(124, 54, 192), C(97, 42, 150), C(214, 196, 150), C(190, 120, 255), C(214, 150, 255), C(238, 228, 200), C(60, 150, 92), C(210, 160, 255), C(244, 108, 140), C(210, 214, 218) },
			Materials = { "Plastic", "Plastic", "Plastic", "Glass", "Neon", "Plastic", "Plastic", "Glass", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 5 12 9 11 1
Rock 3 2 6 13 9 10 1
Rock 3 3 5 3 12 5 1
Rock 13 3 5 13 12 5 1
Rock 3 3 11 3 12 11 1
Rock 13 3 11 13 12 11 1
Rock 2 4 5 2 12 11 1
Rock 14 4 5 14 12 11 1
Rock 1 5 5 1 10 11 1
Rock 15 5 5 15 10 11 1
Rock 0 6 5 0 9 11 1
Rock 16 6 5 16 9 11 1
Rock 4 10 5 5 13 11 1
Rock 6 10 5 6 10 11 1
Rock 10 10 5 12 10 11 1
Rock 11 11 5 12 13 11 1
Rock 3 4 6 4 12 10 1
Rock 12 4 6 13 12 10 1
Rock 6 0 5 10 1 11 2
Rock 3 0 6 5 1 10 2
Rock 11 0 6 13 1 10 2
Rock 5 1 5 5 1 11 2
Rock 11 1 5 11 1 11 2
Biome 3 0 3 13 0 4 3
Biome 2 0 4 2 0 12 3
Biome 14 0 4 14 0 12 3
Biome 1 0 5 1 0 7 3
Biome 3 0 5 5 0 5 3
Biome 11 0 5 13 0 5 3
Biome 15 0 5 15 0 6 3
Biome 15 0 8 15 0 11 3
Biome 1 0 9 1 0 11 3
Biome 3 0 11 5 0 13 3
Biome 11 0 11 13 0 11 3
Biome 6 0 12 11 0 13 3
Biome 13 0 12 13 0 13 3
Biome 12 0 13 12 0 13 3
Gem1 8 9 6 10 15 8 4
Glow 7 10 5 9 10 11 5
Glow 6 11 5 6 11 11 5
Glow 10 11 5 10 11 11 5
Gem2 1 9 10 2 14 11 4
Gem4 14 9 5 15 14 6 4
Gem3 15 8 10 16 12 11 4
Fossil4 8 0 4 8 15 4 6
Fossil3 5 0 4 5 14 4 6
Fossil2 4 -1 4 4 11 4 6
Fossil6 12 -1 4 12 11 4 6
Fossil5 11 5 4 11 14 4 6
Biome 15 0 7 15 3 7 7
Biome 1 0 8 1 4 8 7
Fossil7 11 -1 4 11 4 4 6
Gem1 9 16 6 9 16 8 8
Gem1 8 16 7 10 16 7 8
Gem1 9 10 7 9 17 7 8
Biome 12 0 12 12 2 12 9
Biome 11 2 12 11 2 12 9
Biome 5 2 12 6 2 12 10
Biome 11 3 12 11 3 12 10
Biome 10 6 12 10 6 12 10
Fossil1 5 -1 4 5 -1 4 6
Gem2 1 15 10 1 15 10 8
Gem3 15 13 10 15 13 10 8
Gem4 14 15 5 14 15 5 8
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -0.971, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, -0.353, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, 0, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, 0.265, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, 0, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, -0.353, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -0.971, -0.706), Rest = V(0, 0, -64) },
				Gem1 = { Pivot = V(0, 1.324, -0.176), Rest = V(-6, 0, 3) },
				Gem2 = { Pivot = V(1.147, 0.618, 0.441), Rest = V(18, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.971, 0.441), Rest = V(18, 0, 30) },
				Gem4 = { Pivot = V(0.794, 0.971, -0.441), Rest = V(-12, 0, -27) },
				Gem5 = { Pivot = V(-0.971, 0.971, -0.441), Rest = V(-12, 0, 30) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(214, 196, 150), C(255, 196, 30), C(176, 87, 9), C(60, 150, 92), C(255, 214, 98), C(210, 214, 218), C(244, 108, 140) },
			Materials = { "Plastic", "Foil", "Plastic", "Neon", "Plastic", "Plastic", "Neon", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 3 5 12 14 11 1
Rock 3 3 6 13 13 10 1
Rock 3 4 5 3 13 5 1
Rock 13 4 5 13 13 5 1
Rock 3 4 11 3 13 11 1
Rock 13 4 11 13 13 11 1
Rock 2 5 5 2 13 11 1
Rock 14 5 5 14 13 11 1
Rock 1 6 5 1 11 11 1
Rock 15 6 5 15 11 11 1
Rock 0 7 5 0 10 11 1
Rock 16 7 5 16 10 11 1
Rock 5 15 5 11 15 11 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Biome 3 1 3 13 1 4 3
Biome 2 1 4 2 1 12 3
Biome 14 1 4 14 1 12 3
Biome 1 1 5 1 1 7 3
Biome 3 1 5 5 1 5 3
Biome 11 1 5 13 1 5 3
Biome 15 1 5 15 1 6 3
Biome 15 1 8 15 1 11 3
Biome 1 1 9 1 1 11 3
Biome 3 1 11 5 1 13 3
Biome 11 1 11 13 1 13 3
Biome 6 1 12 10 1 13 3
Gem1 7 14 6 9 20 8 4
Rock 5 2 5 11 2 11 5
Rock 3 1 6 13 2 10 5
Gem2 14 10 10 15 15 11 4
Gem4 12 12 5 13 17 6 4
Gem3 2 12 10 3 16 11 4
Gem5 2 12 5 3 16 6 4
Fossil4 8 2 4 8 17 4 2
Fossil3 5 1 4 5 15 4 2
Fossil2 4 0 4 4 12 4 2
Fossil6 12 0 4 12 12 4 2
Fossil5 11 6 4 11 15 4 2
Biome 15 1 7 15 4 7 6
Biome 1 1 8 1 5 8 6
Fossil7 11 0 4 11 5 4 2
Gem1 8 21 6 8 21 8 7
Gem1 7 21 7 9 21 7 7
Gem1 8 15 7 8 22 7 7
Biome 5 3 12 6 3 12 8
Biome 11 4 12 11 4 12 8
Biome 10 7 12 10 7 12 8
Biome 12 1 12 12 3 12 9
Biome 11 3 12 11 3 12 9
Fossil1 5 0 4 5 0 4 2
Gem2 14 16 10 14 16 10 7
Gem3 2 17 10 2 17 10 7
Gem4 12 18 5 12 18 5 7
Gem5 2 17 5 2 17 5 7
Rock 6 1 5 10 1 11 1
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -1.147, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, -0.529, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, -0.176, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, -0.088, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, -0.176, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, -0.529, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -1.147, -0.706), Rest = V(0, 0, -64) },
				Gem1 = { Pivot = V(0, 1.147, -0.176), Rest = V(-6, 0, 3) },
				Gem2 = { Pivot = V(1.147, 0.441, 0.441), Rest = V(18, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 0.794, 0.441), Rest = V(18, 0, 30) },
				Gem4 = { Pivot = V(0.794, 0.794, -0.441), Rest = V(-12, 0, -27) },
				Gem5 = { Pivot = V(-0.971, 0.794, -0.441), Rest = V(-12, 0, 30) },
				Float1 = { Pivot = V(-1.676, 0.794, -0.088), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.5, 1.147, -0.265), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 1.853, 0.088), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(117, 17, 20), C(214, 196, 150), C(255, 74, 30), C(255, 106, 30), C(238, 228, 200), C(60, 150, 92), C(255, 128, 98), C(244, 108, 140), C(210, 214, 218) },
			Materials = { "Plastic", "Plastic", "Plastic", "Neon", "Neon", "Plastic", "Plastic", "Neon", "Plastic", "Plastic" },
			Boxes = [[
Rock 4 2 5 12 13 11 1
Rock 3 2 6 13 12 10 1
Rock 3 3 5 3 12 5 1
Rock 13 3 5 13 12 5 1
Rock 3 3 11 3 12 11 1
Rock 13 3 11 13 12 11 1
Rock 2 4 5 2 12 11 1
Rock 14 4 5 14 12 11 1
Rock 1 5 5 1 10 11 1
Rock 15 5 5 15 10 11 1
Rock 0 6 5 0 9 11 1
Rock 16 6 5 16 9 11 1
Rock 5 14 5 11 14 11 1
Rock 6 0 5 10 1 11 2
Rock 3 0 6 5 1 10 2
Rock 11 0 6 13 1 10 2
Rock 5 1 5 5 1 11 2
Rock 11 1 5 11 1 11 2
Biome 3 0 3 13 0 4 3
Biome 2 0 4 2 0 12 3
Biome 14 0 4 14 0 12 3
Biome 1 0 5 1 0 7 3
Biome 3 0 5 5 0 5 3
Biome 11 0 5 13 0 5 3
Biome 15 0 5 15 0 6 3
Biome 15 0 8 15 0 11 3
Biome 1 0 9 1 0 11 3
Biome 3 0 11 5 0 13 3
Biome 11 0 11 13 0 11 3
Biome 6 0 12 11 0 13 3
Biome 13 0 12 13 0 13 3
Biome 12 0 13 12 0 13 3
Gem1 7 13 6 9 19 8 4
Gem2 14 9 10 15 14 11 4
Gem4 12 11 5 13 16 6 4
Gem3 2 11 10 3 15 11 4
Gem5 2 11 5 3 15 6 4
Glow -1 6 7 -1 6 7 5
Glow 17 6 9 17 6 9 5
Glow -1 7 8 -1 7 8 5
Glow 17 7 8 17 7 8 5
Glow 17 8 7 17 9 7 5
Glow -1 8 9 -1 9 9 5
Glow 0 10 8 0 10 8 5
Glow 16 10 8 16 10 8 5
Glow 1 11 7 1 12 7 5
Glow 15 11 9 15 12 9 5
Glow 3 13 8 3 13 8 5
Glow 13 13 8 13 13 8 5
Glow 4 14 8 4 14 8 5
Glow 12 14 8 12 14 8 5
Fossil4 8 0 4 8 15 4 6
Fossil3 5 0 4 5 14 4 6
Fossil2 4 -1 4 4 11 4 6
Fossil6 12 -1 4 12 11 4 6
Fossil5 11 5 4 11 14 4 6
Biome 15 0 7 15 3 7 7
Biome 1 0 8 1 4 8 7
Float1 -2 12 7 -1 13 8 1
Float2 16 14 6 17 15 7 1
Float3 10 18 8 11 19 9 1
Fossil7 11 -1 4 11 4 4 6
Gem1 8 20 6 8 20 8 8
Gem1 7 20 7 9 20 7 8
Gem1 8 14 7 8 21 7 8
Biome 12 0 12 12 2 12 9
Biome 11 2 12 11 2 12 9
Biome 5 2 12 6 2 12 10
Biome 11 3 12 11 3 12 10
Biome 10 6 12 10 6 12 10
Fossil1 5 -1 4 5 -1 4 6
Gem2 14 15 10 14 15 10 8
Gem3 2 16 10 2 16 10 8
Gem4 12 17 5 12 17 5 8
Gem5 2 16 5 2 16 5 8
Float1 -1 14 8 -1 14 8 5
Float2 17 16 7 17 16 7 5
Float3 11 20 9 11 20 9 5
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Fossil1 = { Pivot = V(-0.529, -0.441, -0.706), Rest = V(0, 0, 64) },
				Fossil2 = { Pivot = V(-0.706, 0.176, -0.706), Rest = V(0, 0, 43) },
				Fossil3 = { Pivot = V(-0.529, 0.529, -0.706), Rest = V(0, 0, 21) },
				Fossil4 = { Pivot = V(0, 0.618, -0.706), Rest = V(0, 0, 0) },
				Fossil5 = { Pivot = V(0.529, 0.529, -0.706), Rest = V(0, 0, -21) },
				Fossil6 = { Pivot = V(0.706, 0.176, -0.706), Rest = V(0, 0, -43) },
				Fossil7 = { Pivot = V(0.529, -0.441, -0.706), Rest = V(0, 0, -64) },
				Gem1 = { Pivot = V(0, 1.853, -0.176), Rest = V(-6, 0, 3) },
				Gem2 = { Pivot = V(1.147, 1.147, 0.441), Rest = V(18, 0, -30) },
				Gem3 = { Pivot = V(-0.971, 1.5, 0.441), Rest = V(18, 0, 30) },
				Gem4 = { Pivot = V(0.794, 1.5, -0.441), Rest = V(-12, 0, -27) },
				Gem5 = { Pivot = V(-0.971, 1.5, -0.441), Rest = V(-12, 0, 30) },
				Gem6 = { Pivot = V(0.265, 1.853, 0.441), Rest = V(18, 0, -9) },
				Orbit1 = { Pivot = V(1.235, 0.176, 1.235), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.235, 0.882, 1.235), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.235, 0.176, -1.235), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.235, 0.882, -1.235), Rest = V(10, 0, 15) },
			},
			Colors = { C(236, 56, 64), C(80, 200, 90), C(60, 140, 240), C(255, 170, 40), C(170, 90, 235), C(236, 56, 64), C(64, 58, 72), C(255, 170, 40), C(60, 140, 240), C(80, 200, 90), C(170, 90, 235), C(250, 248, 255), C(78, 70, 90), C(60, 150, 92), C(242, 116, 121), C(210, 214, 218), C(244, 108, 140), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Neon", "Neon", "Foil", "Plastic", "Plastic", "Neon", "Plastic", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 6 4 5 10 7 11 1
Rainbow 3 4 6 5 15 10 1
Rainbow 11 4 6 13 15 10 1
Rainbow 5 5 5 5 7 11 1
Rainbow 11 5 5 11 7 11 1
Rainbow 4 6 5 4 7 11 1
Rainbow 12 6 5 12 7 11 1
Rainbow 3 7 5 3 7 5 1
Rainbow 13 7 5 13 7 5 1
Rainbow 3 7 11 3 7 11 1
Rainbow 13 7 11 13 7 11 1
Rainbow 0 11 5 16 13 11 2
Rainbow 1 14 5 15 14 11 3
Rainbow 2 15 5 14 16 11 3
Rainbow 2 8 5 14 10 11 4
Rainbow 1 9 5 1 10 11 4
Rainbow 15 9 5 15 10 11 4
Rainbow 0 10 5 0 10 11 4
Rainbow 16 10 5 16 10 11 4
Rainbow 4 17 5 12 17 11 5
Rainbow 5 18 5 11 18 11 5
Gem1 7 17 6 9 23 8 6
Base 11 0 3 12 0 4 7
Base 3 0 4 5 0 6 7
Base 8 0 7 9 0 9 7
Base 12 0 11 14 0 12 7
Base 5 0 12 6 0 13 7
Gem2 14 13 10 15 18 11 8
Gem4 12 15 5 13 20 6 9
Gem3 2 15 10 3 19 11 10
Gem5 2 15 5 3 19 6 11
Gem6 9 17 10 10 21 11 6
Fossil4 8 4 4 8 19 4 12
Fossil3 5 4 4 5 18 4 12
Base 3 1 4 5 1 6 13
Base 12 1 11 14 1 12 13
Fossil2 4 3 4 4 15 4 12
Fossil6 12 3 4 12 15 4 12
Fossil5 11 9 4 11 18 4 12
Biome 15 4 7 15 7 7 14
Biome 1 4 8 1 8 8 14
Fossil7 11 3 4 11 8 4 12
Gem1 8 24 6 8 24 8 15
Gem1 7 24 7 9 24 7 15
Gem1 8 18 7 8 25 7 15
Biome 5 6 12 6 6 12 16
Biome 11 7 12 11 7 12 16
Biome 10 10 12 10 10 12 16
Biome 12 4 12 12 6 12 17
Biome 11 6 12 11 6 12 17
Orbit1 15 8 15 15 10 15 8
Orbit2 1 12 15 1 14 15 10
Orbit3 1 8 1 1 10 1 9
Orbit4 15 12 1 15 14 1 11
Fossil1 5 3 4 5 3 4 12
Gem2 14 19 10 14 19 10 18
Gem3 2 20 10 2 20 10 19
Gem4 12 21 5 12 21 5 20
Gem5 2 20 5 2 20 5 21
Gem6 9 22 10 9 22 10 15
Orbit1 15 11 15 15 11 15 22
Orbit2 1 15 15 1 15 15 23
Orbit3 1 11 1 1 11 1 24
Orbit4 15 15 1 15 15 1 25
]],
		},
	},
	["Meteor Crater"] = {
		Common = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.353, 0.265), Rest = V(10, 25, 18) },
				Rock2 = { Pivot = V(0.882, -0.088, 0.441), Rest = V(-15, 30, -20) },
				Rock3 = { Pivot = V(0.088, 0.618, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.059, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 0.618, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, -0.176, -0.353), Rest = V(-10, 0, 50) },
			},
			Colors = { C(150, 149, 152), C(117, 116, 119), C(141, 140, 143), C(155, 154, 157), C(70, 62, 84), C(135, 134, 137), C(238, 228, 200), C(170, 110, 255), C(255, 230, 120), C(220, 180, 255) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Neon", "Neon" },
			Boxes = [[
Rock 4 2 2 12 10 14 1
Rock 3 2 3 13 9 13 1
Rock 2 2 4 14 9 12 1
Rock 3 10 3 3 10 13 1
Rock 13 10 3 13 10 13 1
Rock 2 10 4 2 10 12 1
Rock 14 10 4 14 10 12 1
Rock 5 1 4 11 11 12 1
Rock 4 1 5 6 12 11 1
Rock 10 1 5 12 12 11 1
Rock 5 12 4 11 12 4 1
Rock 7 1 5 9 12 5 1
Rock 7 12 9 9 12 12 1
Rock 5 12 12 6 12 12 1
Rock 10 12 12 11 12 12 1
Rock 5 0 3 11 9 13 2
Rock 4 0 4 4 9 12 2
Rock 12 0 4 12 9 12 2
Rock 3 0 5 3 9 11 2
Rock 13 0 5 13 9 11 2
Rock 4 1 2 12 1 14 2
Rock 3 1 3 13 1 13 2
Rock 2 1 4 14 1 12 2
Rock1 0 3 7 4 9 12 3
Rock2 11 5 8 15 9 13 4
Rock2 11 10 8 15 10 8 4
Rock2 12 10 9 15 10 13 4
Biome 3 0 1 13 0 2 5
Biome 2 0 2 2 0 14 5
Biome 14 0 2 14 0 14 5
Biome 1 0 3 1 0 13 5
Biome 3 0 3 4 0 3 5
Biome 12 0 3 13 0 3 5
Biome 15 0 3 15 0 13 5
Biome 3 0 4 3 0 4 5
Biome 13 0 4 13 0 4 5
Biome 3 0 12 3 0 15 5
Biome 13 0 12 13 0 15 5
Biome 4 0 13 4 0 15 5
Biome 12 0 13 12 0 15 5
Biome 5 0 14 11 0 15 5
Rock3 6 10 9 11 13 13 6
Fossil 5 2 1 5 3 1 7
Fossil 8 2 1 8 3 1 7
Fossil 11 2 1 11 3 1 7
Fossil 14 2 3 14 3 3 7
Fossil 4 4 1 4 9 1 7
Fossil 7 4 1 7 9 1 7
Fossil 10 4 1 10 9 1 7
Fossil 13 4 2 13 9 2 7
Fossil 5 8 1 5 9 1 7
Fossil 8 8 1 8 9 1 7
Fossil 11 8 1 11 9 1 7
Fossil 2 8 3 2 9 3 7
Fossil 14 8 3 14 9 3 7
Deco1 6 12 6 7 16 7 8
Deco2 11 10 4 11 13 4 8
Deco3 1 6 6 1 8 6 8
Biome 14 4 13 14 4 13 9
Biome 3 10 14 3 10 14 9
Biome 12 11 12 12 11 12 9
Deco1 7 17 7 7 17 7 10
Deco2 11 14 4 11 14 4 10
Deco3 1 9 6 1 9 6 10
]],
		},
		Uncommon = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.353, 0.265), Rest = V(10, 25, 18) },
				Rock2 = { Pivot = V(0.882, -0.088, 0.441), Rest = V(-15, 30, -20) },
				Rock3 = { Pivot = V(0.088, 0.618, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.059, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 0.618, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, -0.176, -0.353), Rest = V(-10, 0, 50) },
				Gem1 = { Pivot = V(-0.088, 0.618, -0.265), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.618, 0.441, 0.971), Rest = V(30, 0, -24) },
			},
			Colors = { C(66, 160, 66), C(51, 125, 51), C(62, 150, 62), C(75, 165, 75), C(70, 62, 84), C(59, 144, 59), C(238, 228, 200), C(150, 226, 108), C(170, 110, 255), C(255, 230, 120), C(182, 235, 152), C(220, 180, 255) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Neon", "Plastic", "Neon" },
			Boxes = [[
Rock 4 2 2 12 10 14 1
Rock 3 2 3 13 9 13 1
Rock 2 2 4 14 9 12 1
Rock 3 10 3 3 10 13 1
Rock 13 10 3 13 10 13 1
Rock 2 10 4 2 10 12 1
Rock 14 10 4 14 10 12 1
Rock 5 1 4 11 11 12 1
Rock 4 1 5 6 12 11 1
Rock 10 1 5 12 12 11 1
Rock 5 12 4 11 12 4 1
Rock 7 1 5 9 12 5 1
Rock 7 12 9 9 12 12 1
Rock 5 12 12 6 12 12 1
Rock 10 12 12 11 12 12 1
Rock 5 0 3 11 9 13 2
Rock 4 0 4 4 9 12 2
Rock 12 0 4 12 9 12 2
Rock 3 0 5 3 9 11 2
Rock 13 0 5 13 9 11 2
Rock 4 1 2 12 1 14 2
Rock 3 1 3 13 1 13 2
Rock 2 1 4 14 1 12 2
Rock1 0 3 7 4 9 12 3
Rock2 11 5 8 15 8 13 4
Rock2 11 9 8 15 9 12 4
Rock2 13 9 9 14 10 13 4
Rock2 15 9 13 15 10 13 4
Rock2 11 10 8 15 10 8 4
Rock2 12 6 9 12 10 12 4
Rock2 15 10 9 15 10 12 4
Biome 3 0 1 13 0 2 5
Biome 2 0 2 2 0 14 5
Biome 14 0 2 14 0 14 5
Biome 1 0 3 1 0 13 5
Biome 3 0 3 4 0 3 5
Biome 12 0 3 13 0 3 5
Biome 15 0 3 15 0 13 5
Biome 3 0 4 3 0 4 5
Biome 13 0 4 13 0 4 5
Biome 3 0 12 3 0 15 5
Biome 13 0 12 13 0 15 5
Biome 4 0 13 4 0 15 5
Biome 12 0 13 12 0 15 5
Biome 5 0 14 11 0 15 5
Rock3 6 10 9 10 13 13 6
Rock3 11 10 9 11 13 12 6
Fossil 5 2 1 5 3 1 7
Fossil 8 2 1 8 3 1 7
Fossil 11 2 1 11 3 1 7
Fossil 14 2 3 14 3 3 7
Fossil 4 4 1 4 9 1 7
Fossil 7 4 1 7 9 1 7
Fossil 10 4 1 10 9 1 7
Fossil 13 4 2 13 9 2 7
Fossil 5 8 1 5 9 1 7
Fossil 8 8 1 8 9 1 7
Fossil 11 8 1 11 9 1 7
Fossil 2 8 3 2 9 3 7
Fossil 14 8 3 14 9 3 7
Gem1 7 10 6 8 15 7 8
Gem2 11 9 13 12 13 14 8
Deco1 6 12 6 6 16 7 9
Deco1 7 16 7 7 16 7 9
Deco2 11 10 4 11 13 4 9
Deco3 1 6 6 1 8 6 9
Biome 14 4 13 14 4 13 10
Biome 3 10 14 3 10 14 10
Biome 12 11 12 12 11 12 10
Gem1 7 16 6 7 16 6 11
Deco1 7 17 7 7 17 7 12
Deco2 11 14 4 11 14 4 12
Deco3 1 9 6 1 9 6 12
Gem2 11 10 13 11 14 13 11
]],
		},
		Rare = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.353, 0.265), Rest = V(10, 25, 18) },
				Rock2 = { Pivot = V(0.882, -0.088, 0.441), Rest = V(-15, 30, -20) },
				Rock3 = { Pivot = V(0.088, 0.618, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.059, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 0.618, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, -0.176, -0.353), Rest = V(-10, 0, 50) },
				Gem1 = { Pivot = V(0, 0.618, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.618, 0.441, 0.971), Rest = V(30, 0, -24) },
				Gem3 = { Pivot = V(-0.794, 0.441, 0.794), Rest = V(30, 0, 24) },
			},
			Colors = { C(32, 102, 204), C(25, 80, 159), C(30, 96, 192), C(43, 110, 207), C(70, 62, 84), C(29, 92, 184), C(120, 200, 255), C(238, 228, 200), C(170, 110, 255), C(160, 216, 255), C(255, 230, 120), C(220, 180, 255) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Glass", "Plastic", "Neon", "Glass", "Neon", "Neon" },
			Boxes = [[
Rock 4 2 2 12 10 14 1
Rock 3 2 3 13 9 13 1
Rock 2 2 4 14 9 12 1
Rock 3 10 3 3 10 13 1
Rock 13 10 3 13 10 13 1
Rock 2 10 4 2 10 12 1
Rock 14 10 4 14 10 12 1
Rock 5 1 4 11 11 12 1
Rock 4 1 5 6 12 11 1
Rock 10 1 5 12 12 11 1
Rock 5 12 4 11 12 4 1
Rock 7 1 5 9 12 5 1
Rock 7 12 9 9 12 12 1
Rock 5 12 12 6 12 12 1
Rock 10 12 12 11 12 12 1
Rock 5 0 3 11 9 13 2
Rock 4 0 4 4 9 12 2
Rock 12 0 4 12 9 12 2
Rock 3 0 5 3 9 11 2
Rock 13 0 5 13 9 11 2
Rock 4 1 2 12 1 14 2
Rock 3 1 3 13 1 13 2
Rock 2 1 4 14 1 12 2
Rock1 0 3 7 4 8 12 3
Rock1 0 9 7 4 9 11 3
Rock1 0 9 12 2 9 12 3
Rock2 11 5 8 15 8 13 4
Rock2 11 9 8 15 9 12 4
Rock2 13 9 9 14 10 13 4
Rock2 15 9 13 15 10 13 4
Rock2 11 10 8 15 10 8 4
Rock2 12 6 9 12 10 12 4
Rock2 15 10 9 15 10 12 4
Biome 3 0 1 13 0 2 5
Biome 2 0 2 2 0 14 5
Biome 14 0 2 14 0 14 5
Biome 1 0 3 1 0 13 5
Biome 3 0 3 4 0 3 5
Biome 12 0 3 13 0 3 5
Biome 15 0 3 15 0 13 5
Biome 3 0 4 3 0 4 5
Biome 13 0 4 13 0 4 5
Biome 3 0 12 3 0 15 5
Biome 13 0 12 13 0 15 5
Biome 4 0 13 4 0 15 5
Biome 12 0 13 12 0 15 5
Biome 5 0 14 11 0 15 5
Rock3 6 10 9 10 13 13 6
Rock3 11 10 9 11 13 12 6
Gem1 7 10 6 9 16 8 7
Fossil 5 2 1 5 3 1 8
Fossil 8 2 1 8 3 1 8
Fossil 11 2 1 11 3 1 8
Fossil 14 2 3 14 3 3 8
Fossil 4 4 1 4 9 1 8
Fossil 7 4 1 7 9 1 8
Fossil 10 4 1 10 9 1 8
Fossil 13 4 2 13 9 2 8
Fossil 5 8 1 5 9 1 8
Fossil 8 8 1 8 9 1 8
Fossil 11 8 1 11 9 1 8
Fossil 2 8 3 2 9 3 8
Fossil 14 8 3 14 9 3 8
Gem3 3 9 12 4 13 13 7
Gem2 11 9 13 12 14 14 7
Deco1 6 12 6 6 16 7 9
Gem1 8 17 6 8 17 8 10
Gem1 7 17 7 9 17 7 10
Gem1 8 11 7 8 18 7 10
Deco2 11 10 4 11 13 4 9
Deco3 1 6 6 1 8 6 9
Biome 14 4 13 14 4 13 11
Biome 3 10 14 3 10 14 11
Biome 12 11 12 12 11 12 11
Deco2 11 14 4 11 14 4 12
Deco3 1 9 6 1 9 6 12
Gem2 11 15 13 11 15 13 10
Gem3 3 14 12 3 14 12 10
]],
		},
		Epic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.353, 0.265), Rest = V(10, 25, 18) },
				Rock2 = { Pivot = V(0.882, -0.088, 0.441), Rest = V(-15, 30, -20) },
				Rock3 = { Pivot = V(0.088, 0.618, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.059, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 0.618, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, -0.176, -0.353), Rest = V(-10, 0, 50) },
				Gem1 = { Pivot = V(-0.176, 0.088, -0.176), Rest = V(-6, 0, 4.9) },
				Gem2 = { Pivot = V(0.971, 0.441, 0.618), Rest = V(24, 0, -30) },
				Gem3 = { Pivot = V(-0.618, 0.441, 0.971), Rest = V(30, 0, 16.9) },
				Gem4 = { Pivot = V(0.971, 0.441, -0.618), Rest = V(-18, 0, -30) },
			},
			Colors = { C(124, 54, 192), C(97, 42, 150), C(117, 51, 180), C(131, 64, 195), C(70, 62, 84), C(112, 49, 173), C(214, 150, 255), C(190, 120, 255), C(238, 228, 200), C(170, 110, 255), C(210, 160, 255), C(255, 230, 120), C(220, 180, 255) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Glass", "Plastic", "Neon", "Glass", "Neon", "Neon" },
			Boxes = [[
Rock 4 2 2 12 7 14 1
Rock 3 2 3 5 10 13 1
Rock 11 2 3 13 10 13 1
Rock 2 2 4 14 7 12 1
Rock 4 8 2 5 9 14 1
Rock 6 8 2 6 8 14 1
Rock 11 8 2 12 9 14 1
Rock 2 8 4 2 10 12 1
Rock 14 8 4 14 10 12 1
Rock 10 8 2 10 8 14 1
Rock 4 10 2 5 10 2 1
Rock 11 10 2 12 10 2 1
Rock 4 10 14 5 10 14 1
Rock 11 10 14 12 10 14 1
Rock 5 11 4 5 11 12 1
Rock 11 11 4 11 11 12 1
Rock 4 1 5 4 12 11 1
Rock 12 1 5 12 12 11 1
Rock 5 0 3 11 7 13 2
Rock 4 0 4 4 9 12 2
Rock 12 0 4 12 9 12 2
Rock 3 0 5 3 9 11 2
Rock 13 0 5 13 9 11 2
Rock 4 1 2 12 1 14 2
Rock 3 1 3 13 1 13 2
Rock 2 1 4 14 1 12 2
Rock1 0 3 7 4 9 12 3
Rock2 11 5 8 15 8 13 4
Rock2 11 9 8 15 10 8 4
Rock2 11 9 9 12 9 13 4
Rock2 12 9 9 15 10 10 4
Rock2 15 9 11 15 10 13 4
Rock2 13 9 13 14 10 13 4
Rock2 12 10 11 12 10 13 4
Biome 3 0 1 13 0 2 5
Biome 2 0 2 2 0 14 5
Biome 14 0 2 14 0 14 5
Biome 1 0 3 1 0 13 5
Biome 3 0 3 4 0 3 5
Biome 12 0 3 13 0 3 5
Biome 15 0 3 15 0 13 5
Biome 3 0 4 3 0 4 5
Biome 13 0 4 13 0 4 5
Biome 3 0 12 3 0 15 5
Biome 13 0 12 13 0 15 5
Biome 4 0 13 4 0 15 5
Biome 12 0 13 12 0 15 5
Biome 5 0 14 11 0 15 5
Rock3 6 10 9 11 13 13 6
Glow 7 8 2 9 8 14 7
Glow 6 9 2 6 9 14 7
Glow 10 9 2 10 9 14 7
Gem1 6 7 6 8 13 8 8
Fossil 5 2 1 5 3 1 9
Fossil 8 2 1 8 3 1 9
Fossil 11 2 1 11 3 1 9
Fossil 14 2 3 14 3 3 9
Fossil 4 4 1 4 9 1 9
Fossil 7 4 1 7 8 1 9
Fossil 10 4 1 10 9 1 9
Fossil 13 4 2 13 9 2 9
Fossil 5 8 1 5 9 1 9
Fossil 8 8 1 8 8 1 9
Fossil 11 8 1 11 9 1 9
Fossil 2 8 3 2 9 3 9
Fossil 14 8 3 14 9 3 9
Gem4 13 9 4 14 14 5 8
Gem3 4 9 13 5 13 14 8
Gem2 13 9 11 14 14 12 8
Deco1 6 14 6 6 16 6 10
Deco1 7 15 6 7 16 6 10
Deco1 6 15 7 6 16 7 10
Deco1 7 16 7 7 16 7 10
Gem1 7 14 6 7 14 8 11
Gem1 6 14 7 8 14 7 11
Gem1 7 8 7 7 15 7 11
Deco2 11 10 4 11 13 4 10
Deco3 1 6 6 1 8 6 10
Biome 14 4 13 14 4 13 12
Biome 3 10 14 3 10 14 12
Biome 12 11 12 12 11 12 12
Deco1 7 17 7 7 17 7 13
Deco2 11 14 4 11 14 4 13
Deco3 1 9 6 1 9 6 13
Gem2 13 15 11 13 15 11 11
Gem3 4 14 13 4 14 13 11
Gem4 13 15 4 13 15 4 11
]],
		},
		Legendary = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.176, 0.265), Rest = V(10, 25, 18) },
				Rock2 = { Pivot = V(0.882, 0.088, 0.441), Rest = V(-15, 30, -20) },
				Rock3 = { Pivot = V(0.088, 0.971, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.059, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 0.794, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, -0.176, -0.353), Rest = V(-10, 0, 50) },
				Gem1 = { Pivot = V(0, 0.794, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.618, 0.618, 0.971), Rest = V(30, 0, -24) },
				Gem3 = { Pivot = V(-0.794, 0.618, 0.794), Rest = V(30, 0, 24) },
				Gem4 = { Pivot = V(0.971, 0.618, -0.618), Rest = V(-18, 0, -30) },
				Gem5 = { Pivot = V(-0.971, 0.618, -0.618), Rest = V(-18, 0, 30) },
			},
			Colors = { C(226, 112, 12), C(255, 200, 50), C(212, 105, 11), C(227, 119, 24), C(203, 101, 11), C(70, 62, 84), C(255, 196, 30), C(176, 87, 9), C(170, 110, 255), C(255, 214, 98), C(255, 230, 120), C(220, 180, 255) },
			Materials = { "Plastic", "Foil", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rock 4 3 2 12 11 14 1
Rock 3 3 3 13 10 13 1
Rock 2 3 4 14 10 12 1
Rock 3 11 3 3 11 13 1
Rock 13 11 3 13 11 13 1
Rock 2 11 4 2 11 12 1
Rock 14 11 4 14 11 12 1
Rock 5 1 4 11 12 12 1
Rock 4 1 5 6 13 11 1
Rock 10 1 5 12 13 11 1
Rock 5 13 4 11 13 4 1
Rock 7 1 5 9 13 5 1
Rock 7 13 9 9 13 12 1
Rock 5 13 12 6 13 12 1
Rock 10 13 12 11 13 12 1
Base 3 0 1 13 0 15 2
Base 2 0 2 2 0 14 2
Base 14 0 2 14 0 14 2
Base 1 0 3 1 0 13 2
Base 15 0 3 15 0 13 2
Rock1 0 4 7 4 9 12 3
Rock1 0 10 7 4 10 11 3
Rock1 0 10 12 2 10 12 3
Rock2 11 6 8 15 11 12 4
Rock2 11 6 13 15 9 13 4
Rock2 13 10 13 15 11 13 4
Rock3 6 12 9 10 15 13 5
Rock3 11 12 9 11 15 12 5
Biome 3 1 1 13 1 2 6
Biome 2 1 2 2 1 14 6
Biome 14 1 2 14 1 14 6
Biome 1 1 3 1 1 13 6
Biome 15 1 3 15 1 13 6
Biome 3 1 14 13 1 15 6
Gem1 7 11 6 9 17 8 7
Fossil 5 3 1 5 4 1 2
Fossil 8 3 1 8 4 1 2
Fossil 11 3 1 11 4 1 2
Fossil 14 3 3 14 4 3 2
Fossil 4 5 1 4 10 1 2
Fossil 7 5 1 7 10 1 2
Fossil 10 5 1 10 10 1 2
Fossil 13 5 2 13 10 2 2
Fossil 5 9 1 5 10 1 2
Fossil 8 9 1 8 10 1 2
Fossil 11 9 1 11 10 1 2
Fossil 2 9 3 2 10 3 2
Fossil 14 9 3 14 10 3 2
Rock 4 2 2 12 2 14 8
Rock 3 2 3 13 2 13 8
Rock 2 2 4 14 2 12 8
Gem4 13 10 4 14 15 5 7
Gem5 2 10 4 3 14 5 7
Gem3 3 10 12 4 14 13 7
Gem2 11 10 13 12 15 14 7
Deco1 6 12 6 6 16 7 9
Gem1 8 18 6 8 18 8 10
Gem1 7 18 7 9 18 7 10
Gem1 8 12 7 8 19 7 10
Deco2 11 11 4 11 14 4 9
Deco3 1 6 6 1 8 6 9
Biome 14 5 13 14 5 13 11
Biome 3 11 14 3 11 14 11
Biome 12 12 12 12 12 12 11
Deco2 11 15 4 11 15 4 12
Deco3 1 9 6 1 9 6 12
Gem2 11 12 13 11 16 13 10
Gem3 3 15 12 3 15 12 10
Gem4 13 16 4 13 16 4 10
Gem5 2 15 4 2 15 4 10
Rock 5 1 3 11 10 13 1
Rock 4 1 4 12 10 12 1
Rock 3 1 5 13 10 11 1
Biome 3 1 3 4 1 3 6
Biome 12 1 3 13 1 3 6
Biome 2 1 4 3 1 4 6
Biome 13 1 4 14 1 4 6
Biome 3 1 12 3 1 13 6
Biome 13 1 12 13 1 13 6
Biome 4 1 13 4 1 14 6
Biome 12 1 13 12 1 14 6
]],
		},
		Mythic = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rock1 = { Pivot = V(-1.059, -0.353, 0.265), Rest = V(10, 25, 18) },
				Rock2 = { Pivot = V(0.882, -0.088, 0.441), Rest = V(-15, 30, -20) },
				Rock3 = { Pivot = V(0.088, 0.618, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.059, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 0.618, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, -0.176, -0.353), Rest = V(-10, 0, 50) },
				Gem1 = { Pivot = V(0, 0.618, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.618, 0.441, 0.971), Rest = V(30, 0, -24) },
				Gem3 = { Pivot = V(-0.794, 0.441, 0.794), Rest = V(30, 0, 24) },
				Gem4 = { Pivot = V(0.971, 0.441, -0.618), Rest = V(-18, 0, -30) },
				Gem5 = { Pivot = V(-0.971, 0.441, -0.618), Rest = V(-18, 0, 30) },
				Float1 = { Pivot = V(-1.324, 0.441, -0.618), Rest = V(18, 30, 12) },
				Float2 = { Pivot = V(1.147, 0.794, 0.265), Rest = V(-14, 20, -20) },
				Float3 = { Pivot = V(0.441, 1.5, 0.618), Rest = V(24, -10, 16) },
			},
			Colors = { C(150, 22, 26), C(117, 17, 20), C(141, 21, 24), C(155, 34, 37), C(70, 62, 84), C(135, 20, 23), C(255, 74, 30), C(238, 228, 200), C(255, 106, 30), C(170, 110, 255), C(255, 128, 98), C(255, 230, 120), C(220, 180, 255) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rock 4 2 2 12 10 14 1
Rock 3 2 3 13 9 13 1
Rock 2 2 4 14 9 12 1
Rock 3 10 3 3 10 13 1
Rock 13 10 3 13 10 13 1
Rock 2 10 4 2 10 12 1
Rock 14 10 4 14 10 12 1
Rock 5 1 4 11 11 12 1
Rock 4 1 5 6 12 11 1
Rock 10 1 5 12 12 11 1
Rock 5 12 4 11 12 4 1
Rock 7 1 5 9 12 5 1
Rock 7 12 9 9 12 12 1
Rock 5 12 12 6 12 12 1
Rock 10 12 12 11 12 12 1
Rock 5 0 3 11 9 13 2
Rock 4 0 4 4 9 12 2
Rock 12 0 4 12 9 12 2
Rock 3 0 5 3 9 11 2
Rock 13 0 5 13 9 11 2
Rock 4 1 2 12 1 14 2
Rock 3 1 3 13 1 13 2
Rock 2 1 4 14 1 12 2
Rock1 0 3 7 4 8 12 3
Rock1 0 9 7 4 9 11 3
Rock1 0 9 12 2 9 12 3
Rock2 11 5 8 15 8 13 4
Rock2 11 9 8 15 9 12 4
Rock2 13 9 9 14 10 13 4
Rock2 15 9 13 15 10 13 4
Rock2 11 10 8 15 10 8 4
Rock2 12 6 9 12 10 12 4
Rock2 15 10 9 15 10 12 4
Biome 3 0 1 13 0 2 5
Biome 2 0 2 2 0 14 5
Biome 14 0 2 14 0 14 5
Biome 1 0 3 1 0 13 5
Biome 3 0 3 4 0 3 5
Biome 12 0 3 13 0 3 5
Biome 15 0 3 15 0 13 5
Biome 3 0 4 3 0 4 5
Biome 13 0 4 13 0 4 5
Biome 3 0 12 3 0 15 5
Biome 13 0 12 13 0 15 5
Biome 4 0 13 4 0 15 5
Biome 12 0 13 12 0 15 5
Biome 5 0 14 11 0 15 5
Rock3 6 10 9 10 13 13 6
Rock3 11 10 9 11 13 12 6
Gem1 7 10 6 9 16 8 7
Fossil 5 2 1 5 3 1 8
Fossil 8 2 1 8 3 1 8
Fossil 11 2 1 11 3 1 8
Fossil 14 2 3 14 3 3 8
Fossil 4 4 1 4 9 1 8
Fossil 7 4 1 7 9 1 8
Fossil 10 4 1 10 9 1 8
Fossil 13 4 2 13 9 2 8
Fossil 5 8 1 5 9 1 8
Fossil 8 8 1 8 9 1 8
Fossil 11 8 1 11 9 1 8
Fossil 2 8 3 2 9 3 8
Fossil 14 8 3 14 9 3 8
Gem4 13 9 4 14 14 5 7
Gem5 2 9 4 3 13 5 7
Gem3 3 9 12 4 13 13 7
Gem2 11 9 13 12 14 14 7
Glow 1 3 7 1 3 7 9
Glow 1 4 8 1 4 8 9
Glow 10 4 15 10 4 15 9
Glow 1 5 9 1 6 9 9
Glow 11 5 15 11 5 15 9
Glow 12 6 15 12 7 15 9
Glow 1 7 8 1 7 8 9
Glow 1 8 7 1 9 7 9
Glow 11 8 15 11 8 15 9
Glow 10 9 15 10 10 15 9
Glow 1 10 8 1 10 8 9
Glow 3 11 8 3 11 8 9
Glow 11 11 13 11 12 13 9
Deco1 6 12 6 6 16 7 10
Float1 0 10 4 1 11 5 1
Float2 14 12 9 15 13 10 1
Float3 10 16 11 11 17 12 1
Gem1 8 17 6 8 17 8 11
Gem1 7 17 7 9 17 7 11
Gem1 8 11 7 8 18 7 11
Deco2 11 10 4 11 13 4 10
Deco3 1 6 6 1 8 6 10
Biome 14 4 13 14 4 13 12
Biome 3 10 14 3 10 14 12
Biome 12 11 12 12 11 12 12
Deco2 11 14 4 11 14 4 13
Deco3 1 9 6 1 9 6 13
Gem2 11 15 13 11 15 13 11
Gem3 3 14 12 3 14 12 11
Gem4 13 15 4 13 15 4 11
Gem5 2 14 4 2 14 4 11
Float1 1 12 5 1 12 5 9
Float2 15 14 10 15 14 10 9
Float3 11 18 12 11 18 12 9
]],
		},
		Secret = {
			Voxel = 0.176471,
			Origin = 8.5,
			Bones = {
				Rainbow1 = { Pivot = V(-1.059, 0.353, 0.265), Rest = V(10, 25, 18) },
				Rainbow2 = { Pivot = V(0.882, 0.618, 0.441), Rest = V(-15, 30, -20) },
				Rainbow3 = { Pivot = V(0.088, 1.324, 0.529), Rest = V(12, 15, 8) },
				Deco1 = { Pivot = V(-0.265, 1.765, -0.265), Rest = V(14, 0, 18) },
				Deco2 = { Pivot = V(0.529, 1.324, -0.706), Rest = V(-24, 0, -20) },
				Deco3 = { Pivot = V(-1.235, 0.529, -0.353), Rest = V(-10, 0, 50) },
				Gem1 = { Pivot = V(0, 1.324, -0.176), Rest = V(-6, 0, 0) },
				Gem2 = { Pivot = V(0.618, 1.147, 0.971), Rest = V(30, 0, -24) },
				Gem3 = { Pivot = V(-0.794, 1.147, 0.794), Rest = V(30, 0, 24) },
				Gem4 = { Pivot = V(0.971, 1.147, -0.618), Rest = V(-18, 0, -30) },
				Gem5 = { Pivot = V(-0.971, 1.147, -0.618), Rest = V(-18, 0, 30) },
				Gem6 = { Pivot = V(0.265, 1.147, -0.971), Rest = V(-30, 0, -12) },
				Orbit1 = { Pivot = V(1.059, 0.176, 1.059), Rest = V(-10, 0, 15) },
				Orbit2 = { Pivot = V(-1.059, 0.529, 1.059), Rest = V(10, 0, 15) },
				Orbit3 = { Pivot = V(-1.059, 0.176, -1.059), Rest = V(-10, 0, 15) },
				Orbit4 = { Pivot = V(1.059, 0.529, -1.059), Rest = V(10, 0, 15) },
			},
			Colors = { C(236, 56, 64), C(80, 200, 90), C(60, 140, 240), C(255, 170, 40), C(170, 90, 235), C(236, 56, 64), C(250, 248, 255), C(64, 58, 72), C(60, 140, 240), C(170, 90, 235), C(80, 200, 90), C(255, 170, 40), C(78, 70, 90), C(170, 110, 255), C(242, 116, 121), C(255, 230, 120), C(220, 180, 255), C(255, 196, 104), C(132, 216, 140), C(118, 174, 244), C(196, 140, 241), C(255, 200, 115), C(141, 219, 148), C(128, 180, 245), C(200, 148, 242) },
			Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Plastic", "Neon", "Foil", "Plastic", "Neon", "Neon", "Neon", "Neon", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
			Boxes = [[
Rainbow 5 4 3 11 13 13 1
Rainbow 4 4 4 4 13 12 1
Rainbow 12 4 4 12 13 12 1
Rainbow 3 4 5 3 13 11 1
Rainbow 13 4 5 13 13 11 1
Rainbow 4 5 2 12 6 14 1
Rainbow 3 5 3 3 6 13 1
Rainbow 13 5 3 13 6 13 1
Rainbow 2 5 4 2 6 12 1
Rainbow 14 5 4 14 6 12 1
Rainbow1 0 7 7 4 12 12 2
Rainbow1 0 13 7 4 13 11 2
Rainbow1 0 13 12 2 13 12 2
Rainbow2 11 9 8 15 12 13 3
Rainbow2 11 13 8 15 13 12 3
Rainbow2 13 13 9 14 14 13 3
Rainbow2 15 13 13 15 14 13 3
Rainbow2 11 14 8 15 14 8 3
Rainbow2 12 10 9 12 14 12 3
Rainbow2 15 14 9 15 14 12 3
Rainbow 4 13 2 12 14 14 3
Rainbow 3 13 3 3 14 13 3
Rainbow 2 13 4 14 13 12 3
Rainbow 13 13 3 13 14 13 3
Rainbow 2 14 4 2 14 12 3
Rainbow 14 14 4 14 14 12 3
Rainbow 4 7 2 12 9 14 4
Rainbow 3 7 3 13 9 13 4
Rainbow 2 7 4 14 9 12 4
Rainbow 4 10 2 12 12 14 2
Rainbow 3 10 3 13 12 13 2
Rainbow 2 10 4 14 12 12 2
Rainbow 5 5 4 11 15 12 5
Rainbow 4 5 5 6 16 11 5
Rainbow 10 5 5 12 16 11 5
Rainbow 5 16 4 11 16 4 5
Rainbow 7 5 5 9 16 5 5
Rainbow 7 16 9 9 16 12 5
Rainbow 5 16 12 6 16 12 5
Rainbow 10 16 12 11 16 12 5
Rainbow3 6 14 9 10 17 13 5
Rainbow3 11 14 9 11 17 12 5
Gem1 7 14 6 9 20 8 6
Fossil 5 6 1 5 7 1 7
Fossil 8 6 1 8 7 1 7
Fossil 11 6 1 11 7 1 7
Fossil 14 6 3 14 7 3 7
Fossil 4 8 1 4 13 1 7
Fossil 7 8 1 7 13 1 7
Fossil 10 8 1 10 13 1 7
Fossil 13 8 2 13 13 2 7
Fossil 5 12 1 5 13 1 7
Fossil 8 12 1 8 13 1 7
Fossil 11 12 1 11 13 1 7
Fossil 2 12 3 2 13 3 7
Fossil 14 12 3 14 13 3 7
Base 11 0 3 12 0 4 8
Base 3 0 4 5 0 6 8
Base 8 0 7 9 0 9 8
Base 12 0 11 14 0 12 8
Base 5 0 12 6 0 13 8
Gem4 13 13 4 14 18 5 9
Gem5 2 13 4 3 17 5 10
Gem6 9 13 2 10 17 3 6
Gem3 3 13 12 4 17 13 11
Gem2 11 13 13 12 18 14 12
Base 3 1 4 5 1 6 13
Base 12 1 11 14 1 12 13
Deco1 6 16 6 6 20 7 14
Gem1 8 21 6 8 21 8 15
Gem1 7 21 7 9 21 7 15
Gem1 8 15 7 8 22 7 15
Deco2 11 14 4 11 17 4 14
Deco3 1 10 6 1 12 6 14
Biome 14 8 13 14 8 13 16
Biome 3 14 14 3 14 14 16
Biome 12 15 12 12 15 12 16
Orbit1 14 8 14 14 10 14 12
Orbit2 2 10 14 2 12 14 11
Orbit3 2 8 2 2 10 2 9
Orbit4 14 10 2 14 12 2 10
Deco2 11 18 4 11 18 4 17
Deco3 1 13 6 1 13 6 17
Gem2 11 19 13 11 19 13 18
Gem3 3 18 12 3 18 12 19
Gem4 13 19 4 13 19 4 20
Gem5 2 18 4 2 18 4 21
Gem6 9 18 2 9 18 2 15
Orbit1 14 11 14 14 11 14 22
Orbit2 2 13 14 2 13 14 23
Orbit3 2 11 2 2 11 2 24
Orbit4 14 13 2 14 13 2 25
]],
		},
	},
}

return { Scales = Scales, Forms = Forms, Generic = Generic, Zones = Zones }
