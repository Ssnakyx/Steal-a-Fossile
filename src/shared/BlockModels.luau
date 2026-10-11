--!strict
-- BlockModels (brief 9 « blocs-hybrides ») : les blocs de fossiles en briques, un modèle voxel par rareté (fait par
-- models/blocks/blocks.py, rendu dans Blender, exporté ici par models/blocks/build.py), et les effets de chaque rareté.
-- Partagé serveur et client.
--
--   local model = BlockModels.Build("Epic", 2.5)   -- Model en briques, centre du bloc au pivot, côté de 2,5 studs
--   local look = BlockModels.Looks.Epic            -- effets joués en jeu par FossilBlockController
--
-- Le bloc montre seulement sa rareté (GDD : l'espèce reste une surprise) : roche de la couleur de Config.Rarity, même
-- squelette en relief pour toutes les raretés (crâne devant, côtes à droite, queue à gauche), puis des cristaux de plus
-- en plus nombreux, des os en or (Legendary), une base de lave (Mythic), des couches arc-en-ciel (Secret).
-- Repère : l'avant du bloc (le crâne) regarde vers -Z, les cristaux sont sur la moitié avant du dessus ; le pivot du
-- modèle est le centre du bloc. Les briques portent leur rôle dans leur nom : Rock, Fossil, Glow (lave), Rainbow
-- (couches du Secret), Gem (cristaux, attribut Gem = numéro du cristal).

local BlockModels = {}

export type Box = {
	Role: string, -- Rock, Fossil, Glow, Rainbow, Gem
	Gem: number?, -- numéro du cristal (rôle Gem)
	CFrame: CFrame, -- position et orientation dans le repère du bloc (côté de Size studs)
	Size: Vector3,
	Color: Color3,
	Material: string, -- nom de BlockModels.Materials
}

export type Data = {
	Rarity: string,
	Size: number, -- côté du bloc en studs (3)
	Boxes: { Box },
	Gems: number, -- nombre de cristaux
}

-- Effets d'une rareté, joués par FossilBlockController ; ils s'empilent avec la rareté comme ceux des dinos
-- (DinoBuilder.Rarities), toujours en cubes nets
export type Look = {
	Name: string,
	Rank: number, -- 1 Common ... 7 Secret
	Rise: number, -- cubes lumineux qui montent du bloc, par seconde
	Glint: number, -- paillettes qui scintillent sur la roche, par seconde
	Orbit: number, -- cubes de l'aura qui tournent autour du bloc
	Pulse: boolean, -- les briques Glow et les cristaux battent
	Flicker: boolean, -- braises qui vacillent
	Rainbow: boolean, -- couleurs qui tournent (couches, cristaux, cubes)
	Beam: boolean, -- colonne de cubes vers le ciel, visible de loin
}

BlockModels.Size = 3 -- studs : la pièce FossilBlock du serveur
BlockModels.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

BlockModels.Looks = {
	Common = { Name = "Common", Rank = 1, Rise = 0, Glint = 0, Orbit = 0, Pulse = false, Flicker = false, Rainbow = false, Beam = false },
	Uncommon = { Name = "Uncommon", Rank = 2, Rise = 0.7, Glint = 0, Orbit = 0, Pulse = false, Flicker = false, Rainbow = false, Beam = false },
	Rare = { Name = "Rare", Rank = 3, Rise = 1.2, Glint = 1.5, Orbit = 0, Pulse = false, Flicker = false, Rainbow = false, Beam = false },
	Epic = { Name = "Epic", Rank = 4, Rise = 1.8, Glint = 2.5, Orbit = 2, Pulse = false, Flicker = false, Rainbow = false, Beam = false },
	Legendary = { Name = "Legendary", Rank = 5, Rise = 2.4, Glint = 3.5, Orbit = 3, Pulse = false, Flicker = false, Rainbow = false, Beam = false },
	Mythic = { Name = "Mythic", Rank = 6, Rise = 3, Glint = 3.5, Orbit = 4, Pulse = true, Flicker = true, Rainbow = false, Beam = false },
	Secret = { Name = "Secret", Rank = 7, Rise = 4, Glint = 5, Orbit = 5, Pulse = true, Flicker = false, Rainbow = true, Beam = true },
} :: { [string]: Look }

-- Matières des briques : matière Roblox, reflet, transparence
BlockModels.Materials = {
	Plastic = { Enum.Material.Plastic, 0, 0 },
	Smooth = { Enum.Material.SmoothPlastic, 0, 0 },
	Neon = { Enum.Material.Neon, 0, 0 },
	Ice = { Enum.Material.Ice, 0.15, 0 },
	Glass = { Enum.Material.Glass, 0.1, 0.3 },
	Metal = { Enum.Material.Metal, 0, 0 },
	Gold = { Enum.Material.Plastic, 0.22, 0 }, -- os en or du Legendary : plastique brillant
} :: { [string]: { any } }

-- ====================================================================== données des modèles

-- modèle d'une rareté tel qu'exporté (voir la section générée)
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
-- Bones : rôles qui ont un pivot et une rotation de repos (cristaux), en studs depuis le centre du bloc.
local V = Vector3.new
local C = Color3.fromRGB
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
		Colors = { C(32, 102, 204), C(25, 80, 159), C(238, 228, 200), C(140, 205, 255), C(174, 220, 255) },
		Materials = { "Plastic", "Plastic", "Plastic", "Ice", "Ice" },
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
		Colors = { C(124, 54, 192), C(97, 42, 150), C(238, 228, 200), C(176, 84, 255), C(200, 135, 255) },
		Materials = { "Plastic", "Plastic", "Plastic", "Neon", "Neon" },
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
		Colors = { C(226, 112, 12), C(176, 87, 9), C(255, 208, 64), C(255, 196, 30), C(255, 214, 98) },
		Materials = { "Plastic", "Plastic", "Gold", "Neon", "Neon" },
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
			Gem8 = { Pivot = V(0.794, 1.5, 0.794), Rest = V(14, 0, -16) },
			Gem9 = { Pivot = V(-0.618, 1.5, 0.794), Rest = V(16, 0, 14) },
		},
		Colors = { C(236, 56, 64), C(170, 90, 235), C(80, 200, 90), C(255, 170, 40), C(250, 248, 255), C(60, 140, 240), C(236, 56, 64), C(60, 140, 240), C(255, 170, 40), C(80, 200, 90), C(170, 90, 235), C(242, 116, 121), C(118, 174, 244), C(255, 196, 104), C(132, 216, 140), C(196, 140, 241) },
		Materials = { "Plastic", "Plastic", "Plastic", "Plastic", "Smooth", "Plastic", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon", "Neon" },
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
Gem9 4 15 12 5 20 13 8
Gem3 3 15 8 4 19 9 10
Gem5 13 15 8 14 19 9 11
Gem6 9 15 4 10 19 5 7
Gem8 12 15 12 13 19 13 10
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
Gem8 12 20 12 12 20 12 15
Gem9 4 21 12 4 21 12 13
]],
	},
}
-- <<< fin des données générées

local cache: { [string]: Data } = {}

local function decode(rarity: string, raw: Raw): Data
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
			-- cristal : incliné par la rotation de repos de son os, autour de sa base
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
	return { Rarity = rarity, Size = BlockModels.Size, Boxes = boxes, Gems = gems }
end

-- Données du bloc d'une rareté (nil si la rareté n'existe pas). Mises en cache.
function BlockModels.Get(rarity: any): Data?
	if type(rarity) ~= "string" then
		return nil
	end
	local hit = cache[rarity]
	if hit then
		return hit
	end
	local raw = DATA[rarity]
	if not raw then
		return nil
	end
	local data = decode(rarity, raw)
	cache[rarity] = data
	return data
end

-- Nombre de briques du bloc d'une rareté (0 si elle n'existe pas)
function BlockModels.Count(rarity: any): number
	local data = BlockModels.Get(rarity)
	return if data then #data.Boxes else 0
end

-- Échelle d'un bloc dont le côté mesure `size` studs (BlockModels.Size par défaut)
function BlockModels.ScaleOf(size: number?): number
	if type(size) ~= "number" or size ~= size or size <= 0 then
		return 1
	end
	return math.clamp(size / BlockModels.Size, 0.05, 20)
end

-- Modèle en briques au repos : centre du bloc à l'origine (pivot du modèle), côté de `size` studs. Les briques sont
-- ancrées, sans collision ni requête ; leur nom est leur rôle. nil si la rareté n'existe pas.
function BlockModels.Build(rarity: any, size: number?): Model?
	local data = BlockModels.Get(rarity)
	if not data then
		return nil
	end
	local scale = BlockModels.ScaleOf(size)
	local model = Instance.new("Model")
	model.Name = data.Rarity .. "Fossil"
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
		p:SetAttribute("Box", i)
		p.Parent = model
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("Rarity", data.Rarity)
	model:SetAttribute("Scale", scale)
	return model
end

return BlockModels
