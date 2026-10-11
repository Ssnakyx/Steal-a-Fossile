--!strict
-- BlockModels (brief 9 « blocs-hybrides ») : les blocs de fossiles en briques, un modèle différent pour chaque biome
-- et chaque rareté (faits par models/blocks/blocks.py, rendus dans Blender, exportés dans BlockModels/Data par
-- models/blocks/build.py), et l'apparence de chaque rareté. Partagé serveur et client.
--
--   local side = BlockModels.SideOf("Epic", 3)               -- côté en jeu d'un bloc Epic posé à la place d'un cube de 3
--   local model = BlockModels.Build("Epic", side, "Swamp")   -- Model en briques, centre du bloc au pivot
--   local look = BlockModels.Looks.Epic                      -- taille, lumière, battement, arc-en-ciel
--
-- Le bloc montre sa rareté par sa couleur (Config.Rarity ; GDD : l'espèce reste une surprise) et son biome par sa
-- forme (demande de Snaky : aucun bloc ne ressemble à un autre). Formes (BlockModels.Forms) : Beach ammonite dressée,
-- Fern Forest souche pétrifiée, Swamp butte de boue à roseaux, Canyon cheminée de fée, Glacier grappe de cristaux de
-- glace, Volcano volcan à cratère de lave, Ocean Trench coquille Saint-Jacques, Meteor Crater météorite dans son
-- cratère ; chacune avec son fossile en relief et son décor. La rareté change aussi la silhouette : cristaux de plus en
-- plus nombreux, Epic fendu en V au coeur qui brille, Legendary os en or sur un socle d'or, Mythic fissures de lave et
-- morceaux qui flottent au-dessus, Secret couches arc-en-ciel en lévitation, éclats qui tournent autour. Les raretés
-- hautes sont plus grosses (Looks.Scale, jusqu'à x1,8 pour le Secret) et éclairent autour d'elles (Looks.Light).
-- Sans biome connu (vieille sauvegarde), le bloc est un cube biseauté avec des os sur trois faces.
-- Repère : l'avant du bloc (le fossile) regarde vers -Z, le bas du bloc est au sol (y = -Size/2). Le pivot du modèle
-- est le centre de la grille : pièce invisible « Root » (PrimaryPart, porte la PointLight des raretés qui brillent).
-- Les briques portent leur rôle dans leur nom : Rock, Fossil, Glow (coeur de l'Epic, lave du Mythic), Rainbow (couches
-- du Secret), Base (socle), Biome, Ember (lueurs du décor), Gem (cristaux), Deco, Float (morceaux qui flottent), Orbit
-- (éclats qui tournent) ; les quatre derniers ont leur numéro en attribut du même nom (Gem = 2...).
-- Les auras autour des blocs (cubes, particules) ne sont pas faites ici : thread des auras, via FossilBlockController.

local Data = require(script.Data)

local BlockModels = {}

export type Box = {
	Role: string, -- Rock, Fossil, Glow, Rainbow, Base, Biome, Ember, Gem, Deco, Float, Orbit
	Index: number?, -- numéro de la pièce (Gem, Deco, Float, Orbit)
	CFrame: CFrame, -- position et orientation dans le repère du bloc (côté de Size studs)
	Size: Vector3,
	Color: Color3,
	Material: string, -- nom de BlockModels.Materials
}

export type Data = {
	Name: string, -- rareté
	Zone: string?, -- biome (nil : cube sans biome)
	Form: string, -- forme (Ammonite, Stump..., Block pour le cube sans biome)
	Size: number, -- côté du bloc en studs (3)
	Boxes: { Box },
	Gems: number, -- nombre de cristaux
	Floats: number, -- morceaux qui flottent (Mythic)
	Orbits: number, -- éclats qui tournent autour (Secret)
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
BlockModels.Forms = Data.Forms -- forme de chaque biome
BlockModels.TankScale = 1.6 -- dans une cuve (verre de 5 studs), un bloc ne dépasse pas x1,6

-- Matières des briques : matière Roblox, reflet, transparence
BlockModels.Materials = {
	Plastic = { Enum.Material.Plastic, 0, 0 },
	Smooth = { Enum.Material.SmoothPlastic, 0, 0 },
	Neon = { Enum.Material.Neon, 0, 0 },
	Ice = { Enum.Material.Ice, 0.15, 0 }, -- grappe de cristaux du Glacier
	Glass = { Enum.Material.Glass, 0.05, 0.2 }, -- cristaux des Rare et Epic
	Metal = { Enum.Material.Metal, 0, 0 },
	Foil = { Enum.Material.Foil, 0, 0 }, -- os et socle en or du Legendary, os nacrés du Secret
} :: { [string]: { any } }

local SCALES = Data.Scales

BlockModels.Looks = {
	Common = { Name = "Common", Rank = 1, Scale = SCALES.Common, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Uncommon = { Name = "Uncommon", Rank = 2, Scale = SCALES.Uncommon, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Rare = { Name = "Rare", Rank = 3, Scale = SCALES.Rare, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Epic = { Name = "Epic", Rank = 4, Scale = SCALES.Epic, Light = 0, Range = 0, LightColor = Color3.new(1, 1, 1), Pulse = false, Rainbow = false },
	Legendary = { Name = "Legendary", Rank = 5, Scale = SCALES.Legendary, Light = 0.8, Range = 6, LightColor = Color3.fromRGB(255, 196, 90), Pulse = true, Rainbow = false },
	Mythic = { Name = "Mythic", Rank = 6, Scale = SCALES.Mythic, Light = 0.9, Range = 6.5, LightColor = Color3.fromRGB(255, 96, 50), Pulse = true, Rainbow = false },
	Secret = { Name = "Secret", Rank = 7, Scale = SCALES.Secret, Light = 1, Range = 7, LightColor = Color3.fromRGB(255, 120, 220), Pulse = true, Rainbow = true },
} :: { [string]: Look }

-- ====================================================================== données des modèles

-- pièces numérotées dont le numéro est gardé (attribut du même nom sur la brique)
local INDEXED: { [string]: boolean } = { Gem = true, Deco = true, Float = true, Orbit = true }

local cache: { [string]: Data } = {}

local function decode(name: string, zone: string?, raw: Data.Raw): Data
	local voxel, origin = raw.Voxel, raw.Origin
	local boxes: { Box } = {}
	local counts: { [string]: number } = {}
	for bone, a, b, c, d, e, f, paint in string.gmatch(raw.Boxes, "(%w+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%d+)") do
		local x0, y0, z0 = tonumber(a) :: number, tonumber(b) :: number, tonumber(c) :: number
		local x1, y1, z1 = tonumber(d) :: number, tonumber(e) :: number, tonumber(f) :: number
		local p = tonumber(paint) :: number
		local center = Vector3.new((x0 + x1 + 1) / 2 - origin, (y0 + y1 + 1) / 2 - origin, (z0 + z1 + 1) / 2 - origin) * voxel
		local size = Vector3.new(x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1) * voxel
		local cf = CFrame.new(center)
		local rest = raw.Bones[bone]
		if rest then
			-- pièce inclinée (cristal, feuille, côte, morceau qui flotte) : tournée par la rotation de repos de son os
			local r = rest.Rest
			cf = CFrame.new(rest.Pivot)
				* CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
				* CFrame.new(-rest.Pivot)
				* cf
		end
		-- « Gem3 » : cristal numéro 3 ; « Rock2 » : morceau de roche incliné (rôle Rock)
		local role, n = string.match(bone, "^(%a+)(%d+)$")
		local index: number? = nil
		if role and n then
			if INDEXED[role] then
				index = tonumber(n)
				counts[role] = math.max(counts[role] or 0, index or 0)
			end
		else
			role = bone
		end
		table.insert(boxes, {
			Role = role :: string,
			Index = index,
			CFrame = cf,
			Size = size,
			Color = raw.Colors[p] or Color3.new(1, 0, 1),
			Material = raw.Materials[p] or "Plastic",
		})
	end
	return {
		Name = name,
		Zone = zone,
		Form = if zone then Data.Forms[zone] or "Block" else "Block",
		Size = BlockModels.Size,
		Boxes = boxes,
		Gems = counts.Gem or 0,
		Floats = counts.Float or 0,
		Orbits = counts.Orbit or 0,
	}
end

-- Données du bloc d'une rareté dans un biome (zone inconnue ou absente : cube sans biome ; nil si la rareté n'existe
-- pas). Mises en cache.
function BlockModels.Get(rarity: any, zone: any?): Data?
	if type(rarity) ~= "string" then
		return nil
	end
	local row = if type(zone) == "string" then Data.Zones[zone] else nil
	local raw = if row then row[rarity] else Data.Generic[rarity]
	if not raw then
		return nil
	end
	local where: string? = if row then zone :: string else nil
	local key = (where or "") .. "/" .. rarity
	local hit = cache[key]
	if hit then
		return hit
	end
	local data = decode(rarity, where, raw)
	cache[key] = data
	return data
end

-- Forme du biome d'une zone (nom de la zone de Config.Zones), nil si la zone n'a pas de forme
function BlockModels.Biome(zone: any): string?
	if type(zone) ~= "string" then
		return nil
	end
	return Data.Forms[zone]
end

-- Nombre de briques du bloc d'une rareté dans une zone (0 si la rareté n'existe pas), pièce Root comprise
function BlockModels.Count(rarity: any, zone: any?): number
	local data = BlockModels.Get(rarity, zone)
	return if data then #data.Boxes + 1 else 0
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

-- Modèle en briques au repos : centre de la grille à l'origine (pièce Root, PrimaryPart), côté de `size` studs, bas
-- du bloc à -size/2. Les briques sont ancrées, sans collision ni requête ; leur nom est leur rôle. Les raretés qui
-- brillent ont une PointLight dans Root. nil si la rareté n'existe pas. Zone inconnue : cube sans biome.
function BlockModels.Build(rarity: any, size: number?, zone: any?): Model?
	local data = BlockModels.Get(rarity, zone)
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
		if box.Index then
			p:SetAttribute(box.Role, box.Index)
		end
		p:SetAttribute("Box", i)
		p.Parent = model
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
	model:SetAttribute("Form", data.Form)
	if data.Zone then
		model:SetAttribute("Zone", data.Zone)
	end
	return model
end

return BlockModels
