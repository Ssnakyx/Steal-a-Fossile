--!strict
-- DinoBuilder : dinos en briques à partir des données voxel de src/shared/DinoModels/<Espece> (générées par
-- models/build.py), et lecture de leurs animations. Partagé serveur et client.
--
--   local data = DinoBuilder.Get("Velociraptor")
--   local model = DinoBuilder.Build("Velociraptor", { Size = "Big", Mutation = "Amber", Level = "Golden" })
--   local rig = DinoBuilder.Rig(model)                    -- juste après Build, quand le modèle est au repos
--   DinoBuilder.Pose(rig, DinoBuilder.Sample(data.Clips.Walk, t), model:GetPivot())
--
-- Repère : le dino regarde vers -Z, pieds à Y = 0 ; le pivot du modèle (pièce invisible "Root") est au sol, au centre.
-- Les animations sont jouées côté client par DinoAnimController (aucun PivotTo serveur à 60 Hz).

local DinoBuilder = {}

export type Pose = { [string]: { number } } -- os -> { rx, ry, rz (degrés), px, py, pz (studs à l'échelle 1) }

export type Track = {
	Bone: string,
	Channel: number, -- 1 rx, 2 ry, 3 rz, 4 px, 5 py, 6 pz
	Times: { number },
	Values: { number },
	Slopes: { number },
}

export type Clip = {
	Name: string,
	Length: number,
	Loop: boolean,
	Next: string?, -- état joué ensuite (animation simple)
	Speed: number?, -- studs/s de la marche à l'échelle 1 (cadence calée sur la vitesse réelle)
	Events: { { any } }, -- { t, nom, os? } : "Step" (pas), "Roar", "Hit"
	Tracks: { Track },
}

export type BoneDef = { Name: string, Parent: string?, Pivot: Vector3, Rest: Vector3? } -- Rest : rotation de repos (degrés)

export type Box = { Bone: string, Center: Vector3, Size: Vector3, Color: Color3, Material: string }

export type Data = {
	Species: string, -- nom du module (gardé dans l'attribut "Species" du modèle)
	Name: string,
	Family: string, -- "Biped" | "Quadruped" | "Flyer" | "Swimmer"
	Voxel: number,
	Height: number,
	Size: Vector3,
	LidDrop: number,
	Bones: { BoneDef },
	Groups: { [string]: { string } },
	Points: { [string]: { any } }, -- nom -> { os, position au repos }
	Boxes: { Box },
	Clips: { [string]: Clip },
}

export type BuildOptions = {
	Size: (string | number)?, -- "Small" | "Normal" | "Big" | "Huge" ou une échelle
	Scale: number?, -- échelle en plus (gardiens x1.5 à x3)
	Mutation: string?, -- un nom de DinoBuilder.Mutations ("Amber", "Rainbow"...)
	Level: string?, -- "Normal" | "Golden" | "Diamond"
	Rarity: string?, -- "Common" ... "Secret" : anneau et effets de rareté (DinoAnimController)
}

-- Apparence de la rareté sur le dino (DinoAnimController) : effets qui s'empilent avec la rareté
export type RarityLook = {
	Name: string,
	Level: number, -- 1 Common ... 7 Secret
	Color: Color3, -- couleur de secours (le jeu prend celle de Config.Rarity, la même que les blocs de fossiles)
	Neon: boolean, -- anneau lumineux (sinon briques à studs)
	Particles: number, -- cubes lumineux qui montent, par seconde
	Glitter: number, -- paillettes qui scintillent sur le corps, par seconde
	Orbiters: number, -- cubes de l'aura qui tournent autour
	Halo: number, -- cubes de la couronne au-dessus de la tête
	Pulse: boolean, -- l'anneau bat
	Flicker: boolean, -- braises qui vacillent
	Rainbow: boolean, -- couleurs qui tournent
}

export type Rig = {
	Model: Model,
	Data: Data,
	Scale: number,
	Parts: { BasePart },
	Bones: { string },
	Rest: { CFrame },
	CFrames: { CFrame },
	Solved: { [string]: CFrame },
	PerBone: { [string]: CFrame },
}

-- tailles tirées à la réanimation (échelle visible du modèle, GDD section Tailles)
DinoBuilder.Sizes = { Small = 0.75, Normal = 1, Big = 1.5, Huge = 2.5 } :: { [string]: number }
-- (mêmes noms que Config.Economy.Mutations, de la plus commune à la plus rare)
DinoBuilder.Mutations = { "Amber", "Crystal", "Pearl", "Bloom", "Toxic", "Ruby", "Frost", "Lava", "Obsidian", "Abyssal", "Galaxy", "Rainbow" }
DinoBuilder.Levels = { "Normal", "Golden", "Diamond" }
DinoBuilder.Tag = "Dino" -- tag CollectionService des dinos animés par DinoAnimController

-- 7 raretés du GDD : chaque rareté ajoute un effet (anneau, cubes qui montent, paillettes, aura, couronne, braises,
-- arc-en-ciel), toujours en cubes nets
DinoBuilder.Rarities = {
	{ Name = "Common", Level = 1, Color = Color3.fromRGB(163, 162, 165), Neon = false, Particles = 0, Glitter = 0, Orbiters = 0, Halo = 0, Pulse = false, Flicker = false, Rainbow = false },
	{ Name = "Uncommon", Level = 2, Color = Color3.fromRGB(75, 175, 75), Neon = false, Particles = 0.8, Glitter = 0, Orbiters = 0, Halo = 0, Pulse = false, Flicker = false, Rainbow = false },
	{ Name = "Rare", Level = 3, Color = Color3.fromRGB(30, 110, 220), Neon = true, Particles = 1.6, Glitter = 3, Orbiters = 0, Halo = 0, Pulse = false, Flicker = false, Rainbow = false },
	{ Name = "Epic", Level = 4, Color = Color3.fromRGB(140, 60, 210), Neon = true, Particles = 2.5, Glitter = 5, Orbiters = 2, Halo = 0, Pulse = false, Flicker = false, Rainbow = false },
	{ Name = "Legendary", Level = 5, Color = Color3.fromRGB(255, 145, 20), Neon = true, Particles = 3.5, Glitter = 7, Orbiters = 3, Halo = 6, Pulse = false, Flicker = false, Rainbow = false },
	{ Name = "Mythic", Level = 6, Color = Color3.fromRGB(215, 35, 35), Neon = true, Particles = 5, Glitter = 9, Orbiters = 4, Halo = 8, Pulse = true, Flicker = true, Rainbow = false },
	{ Name = "Secret", Level = 7, Color = Color3.fromRGB(255, 90, 200), Neon = true, Particles = 7, Glitter = 12, Orbiters = 6, Halo = 10, Pulse = true, Flicker = false, Rainbow = true },
} :: { RarityLook }
DinoBuilder.RarityByName = {} :: { [string]: RarityLook }
for _, r in DinoBuilder.Rarities do
	DinoBuilder.RarityByName[r.Name] = r
end

local MATERIALS: { [string]: Enum.Material } = {
	Plastic = Enum.Material.Plastic,
	Smooth = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
	Ice = Enum.Material.Ice,
	Metal = Enum.Material.Metal,
}

local modelsFolder: Instance? = script.Parent and script.Parent:FindFirstChild("DinoModels")
local cache: { [string]: Data } = {}
local registered: { [string]: Data } = {}

-- ====================================================================== lecture des données
local function pchip(d0: number, d1: number, h0: number, h1: number): number
	if d0 * d1 <= 0 then
		return 0
	end
	local w1, w2 = 2 * h1 + h0, h1 + 2 * h0
	return (w1 + w2) / (w1 / d0 + w2 / d1)
end

-- Pentes de la cubique monotone (mêmes calculs que models/lib/anim.py : tangents)
local function slopes(times: { number }, values: { number }, loop: boolean): { number }
	local k = #times
	local m = table.create(k, 0)
	if k < 3 then
		return m
	end
	local h = table.create(k - 1, 0)
	local d = table.create(k - 1, 0)
	for j = 1, k - 1 do
		h[j] = times[j + 1] - times[j]
		d[j] = if h[j] > 1e-9 then (values[j + 1] - values[j]) / h[j] else 0
	end
	for j = 2, k - 1 do
		m[j] = pchip(d[j - 1], d[j], h[j - 1], h[j])
	end
	if loop then
		m[1] = pchip(d[k - 1], d[1], h[k - 1], h[1])
		m[k] = m[1]
	end
	return m
end

local function decode(species: string, raw: any): Data
	local voxel: number = raw.Voxel
	local origin: Vector3 = raw.Origin
	local boxes: { Box } = table.create(#raw.Boxes)
	for i, b in raw.Boxes do
		local paint = raw.Paints[b[8]]
		local x0, y0, z0, x1, y1, z1 = b[2], b[3], b[4], b[5], b[6], b[7]
		boxes[i] = {
			Bone = b[1],
			Center = Vector3.new((x0 + x1 + 1) / 2 - origin.X, (y0 + y1 + 1) / 2 - origin.Y, (z0 + z1 + 1) / 2 - origin.Z) * voxel,
			Size = Vector3.new(x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1) * voxel,
			Color = paint[1],
			Material = paint[2],
		}
	end
	local clips: { [string]: Clip } = {}
	for name, a in raw.Anims do
		local tracks: { Track } = table.create(#a.Tracks)
		for i, tr in a.Tracks do
			local flat = tr[3]
			local n = #flat // 2
			local times, values = table.create(n, 0), table.create(n, 0)
			for j = 1, n do
				times[j] = flat[2 * j - 1] / 60
				values[j] = flat[2 * j]
			end
			tracks[i] = { Bone = tr[1], Channel = tr[2], Times = times, Values = values, Slopes = slopes(times, values, a.Loop) }
		end
		clips[name] = {
			Name = name,
			Length = a.Length,
			Loop = a.Loop,
			Next = a.Next,
			Speed = a.Speed,
			Events = a.Events or {},
			Tracks = tracks,
		}
	end
	return {
		Species = species,
		Name = raw.Name,
		Family = raw.Family,
		Voxel = voxel,
		Height = raw.Height,
		Size = raw.Size,
		LidDrop = raw.LidDrop or 0,
		Bones = raw.Bones,
		Groups = raw.Groups or {},
		Points = raw.Points or {},
		Boxes = boxes,
		Clips = clips,
	}
end

-- Données brutes d'un module DinoModels -> Data (sans cache) : sert aux tests et aux modèles assemblés ailleurs
function DinoBuilder.Decode(species: string, raw: any): Data
	return decode(species, raw)
end

-- Données d'une espèce (nil si son module n'existe pas encore). Mises en cache.
function DinoBuilder.Get(species: string): Data?
	local hit = registered[species] or cache[species]
	if hit then
		return hit
	end
	local module = modelsFolder and modelsFolder:FindFirstChild(species)
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, raw = pcall(require, module)
	if not ok or type(raw) ~= "table" then
		warn("[DinoBuilder] modèle illisible", species, raw)
		return nil
	end
	local okDecode, data = pcall(decode, species, raw)
	if not okDecode then
		warn("[DinoBuilder] données invalides", species, data)
		return nil
	end
	cache[species] = data :: Data
	return data :: Data
end

-- Espèces qui ont un modèle (modules de DinoModels)
function DinoBuilder.List(): { string }
	local out = {}
	if modelsFolder then
		for _, m in modelsFolder:GetChildren() do
			if m:IsA("ModuleScript") then
				table.insert(out, m.Name)
			end
		end
	end
	table.sort(out)
	return out
end

-- Données assemblées ailleurs (hybrides du labo de fusion) : Get(key) et Build(key) les trouvent ensuite
function DinoBuilder.Register(key: string, data: Data)
	data.Species = key
	registered[key] = data
end

-- ====================================================================== construction en briques
local AMBER = Color3.fromRGB(255, 172, 38)
local CRYSTAL = Color3.fromRGB(150, 228, 255)
local BASALT = Color3.fromRGB(46, 34, 32)
local LAVA = Color3.fromRGB(255, 108, 28)
-- mutations ajoutées après Amber, Crystal et Lava (docs/MUTATIONS.md) : couleurs posées par paintMutation, plus bas
local paintMutation: (box: Box, i: number, mutation: string, color: Color3, material: Enum.Material, transparency: number, reflectance: number) -> (Color3, Enum.Material, number, number)

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function ramp(dark: Color3, light: Color3, c: Color3): Color3
	return dark:Lerp(light, math.clamp(luminance(c) * 1.25, 0, 1))
end

-- petit hasard fixe par pièce (même rendu sur tous les clients)
local function noise(i: number): number
	local x = math.sin(i * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

-- Couleur, matière, transparence, reflet d'une boîte selon le niveau et la mutation.
-- Niveaux (brief 9, comparés dans Studio) : Golden = statue d'or en Foil (le plastique doré avec reflet virait au beige),
-- dégradé d'or selon la clarté d'origine (les motifs de l'espèce restent lisibles) ; Diamond = cristal cyan brillant :
-- plastique à reflet, un tiers de facettes en verre, quelques petits éclats Neon blancs qui scintillent.
-- Les yeux et l'intérieur de la bouche (détails sombres) gardent leur couleur.
local function paint(box: Box, i: number, level: string?, mutation: string?): (Color3, Enum.Material, number, number)
	local color = box.Color
	local mat = box.Material
	local material = MATERIALS[mat] or Enum.Material.Plastic
	local transparency = if mat == "Glass" or mat == "Ice" then 0.25 else 0
	local reflectance = 0
	local detail = mat == "Smooth" -- yeux, griffes, dents, bouche : gardent leur couleur
	local dark = detail and luminance(color) < 0.15
	if level == "Golden" and not dark then
		color = ramp(Color3.fromRGB(176, 116, 20), Color3.fromRGB(255, 222, 90), color)
		material, transparency = Enum.Material.Foil, 0
	elseif level == "Diamond" and not dark then
		color = ramp(Color3.fromRGB(80, 180, 240), Color3.fromRGB(228, 251, 255), color)
		reflectance = 0.25
		if not detail then
			local r = noise(i)
			local size = box.Size
			if r < 0.07 and size.X * size.Y * size.Z < 0.5 then
				-- petit éclat qui brille
				color, material, transparency = Color3.fromRGB(205, 246, 255), Enum.Material.Neon, 0
			elseif r < 0.35 then
				material, transparency = Enum.Material.Glass, 0.1
			end
		end
	end
	if detail then
		return color, material, transparency, reflectance
	end
	if mutation == "Amber" then
		-- gouttes dorées translucides
		color = color:Lerp(AMBER, 0.55)
		if noise(i + 17) < 0.25 then
			material, transparency = Enum.Material.Glass, 0.2
		end
	elseif mutation == "Crystal" then
		-- éclats brillants
		color = color:Lerp(CRYSTAL, 0.6)
		local r = noise(i + 31)
		if r < 0.06 then
			material = Enum.Material.Neon
		elseif r < 0.3 then
			material, reflectance = Enum.Material.Ice, 0.25
		end
	elseif mutation == "Lava" then
		-- roche sombre et fissures lumineuses
		if noise(i + 53) < 0.18 then
			color, material = LAVA, Enum.Material.Neon
		else
			color = color:Lerp(BASALT, 0.72)
		end
	elseif mutation then
		return paintMutation(box, i, mutation, color, material, transparency, reflectance)
	end
	return color, material, transparency, reflectance
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Mutations des biomes et Rainbow. Le motif de l'espèce reste lisible (dégradé selon la clarté d'origine) ; la matière
-- ne change que sur le plastique de base (le Foil d'un Golden, le verre d'un Diamond restent), sauf les points Neon.
-- Les effets animés (bulles, flocons, étoiles, arc-en-ciel qui défile) sont faits par MutationController, chez le client.
paintMutation = function(box: Box, i: number, mutation: string, color: Color3, material: Enum.Material, transparency: number, reflectance: number): (Color3, Enum.Material, number, number)
	local plain = material == Enum.Material.Plastic
	local small = box.Size.X * box.Size.Y * box.Size.Z < 0.5
	if mutation == "Pearl" then
		-- nacre : blanc rosé brillant, reflets pastel (lavande, rose, menthe)
		color = ramp(rgb(214, 188, 206), rgb(255, 244, 248), color)
		local r = noise(i + 71)
		if r < 0.25 then
			color = color:Lerp(rgb(226, 204, 255), 0.6)
		elseif r < 0.5 then
			color = color:Lerp(rgb(255, 192, 218), 0.6)
		elseif r < 0.65 then
			color = color:Lerp(rgb(200, 255, 234), 0.5)
		end
		if plain then
			material = Enum.Material.SmoothPlastic
		end
		reflectance = math.max(reflectance, 0.25)
	elseif mutation == "Bloom" then
		-- mousse verte et fleurs roses, jaunes et blanches
		color = ramp(rgb(40, 88, 34), rgb(130, 196, 96), color)
		local r = if small then noise(i + 89) else 1
		if r < 0.12 then
			color = rgb(255, 120, 196)
		elseif r < 0.18 then
			color = rgb(255, 222, 80)
		elseif r < 0.23 then
			color = rgb(255, 250, 245)
		elseif r < 0.27 then
			color = rgb(196, 120, 255)
		end
	elseif mutation == "Toxic" then
		-- vert radioactif, taches qui brillent
		color = ramp(rgb(24, 52, 18), rgb(104, 170, 40), color)
		local r = noise(i + 97)
		if r < 0.16 then
			color, material, transparency = rgb(150, 255, 60), Enum.Material.Neon, 0
		elseif r < 0.2 then
			color, material, transparency = rgb(214, 255, 96), Enum.Material.Neon, 0
		end
	elseif mutation == "Ruby" then
		-- rubis : rouge profond, facettes de verre, éclats
		color = ramp(rgb(104, 6, 26), rgb(240, 58, 94), color)
		local r = noise(i + 101)
		if r < 0.06 and small then
			color, material, transparency = rgb(255, 130, 160), Enum.Material.Neon, 0
		elseif r < 0.4 and plain then
			material, transparency = Enum.Material.Glass, 0.1
		end
		reflectance = math.max(reflectance, 0.15)
	elseif mutation == "Frost" then
		-- givre : bleu glacier, plaques de glace, neige
		color = ramp(rgb(84, 140, 206), rgb(206, 234, 255), color)
		local r = noise(i + 107)
		if r < 0.14 then
			color = rgb(255, 255, 255)
		elseif r < 0.42 and plain then
			material, transparency, reflectance = Enum.Material.Ice, 0.1, 0.2
		end
	elseif mutation == "Obsidian" then
		-- verre volcanique noir et brillant, éclats violets
		color = ramp(rgb(10, 8, 16), rgb(56, 46, 74), color)
		if noise(i + 113) < 0.08 then
			color, material, transparency = rgb(170, 90, 255), Enum.Material.Neon, 0
		else
			if plain then
				material = Enum.Material.SmoothPlastic
			end
			reflectance = math.max(reflectance, 0.3)
		end
	elseif mutation == "Abyssal" then
		-- bleu des abysses, points bioluminescents
		color = ramp(rgb(6, 14, 38), rgb(40, 82, 144), color)
		if noise(i + 127) < 0.12 then
			color, material, transparency = rgb(60, 230, 255), Enum.Material.Neon, 0
		end
	elseif mutation == "Galaxy" then
		-- nuit violette, nébuleuses, étoiles
		color = ramp(rgb(14, 8, 34), rgb(74, 42, 136), color)
		local cloud = noise(i + 131)
		if cloud < 0.25 then
			color = color:Lerp(rgb(150, 50, 170), 0.55)
		elseif cloud < 0.45 then
			color = color:Lerp(rgb(40, 70, 176), 0.5)
		end
		local r = noise(i + 137)
		if r < 0.16 and small then
			color, material, transparency = rgb(255, 255, 255), Enum.Material.Neon, 0
		elseif r < 0.2 and small then
			color, material, transparency = rgb(255, 230, 150), Enum.Material.Neon, 0
		end
	elseif mutation == "Rainbow" then
		-- toutes les couleurs (MutationController les fait défiler en vague)
		color = Color3.fromHSV(noise(i + 149), 0.72, 0.72 + 0.28 * luminance(color))
	end
	return color, material, transparency, reflectance
end

local function newPart(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Échelle finale d'après les options (taille tirée x échelle en plus)
function DinoBuilder.ScaleOf(options: BuildOptions?): number
	local s = 1
	if options then
		local size = options.Size
		if type(size) == "number" then
			s = size
		elseif type(size) == "string" then
			s = DinoBuilder.Sizes[size] or 1
		end
		s *= options.Scale or 1
	end
	return s
end

-- Modèle en pièces, au repos, pivot au sol (pièce invisible "Root"). Pièces nommées d'après leur os (attribut "Bone").
function DinoBuilder.Build(species: string | Data, options: BuildOptions?): Model
	local data: Data? = if type(species) == "string" then DinoBuilder.Get(species) else species
	assert(data, "[DinoBuilder] espèce sans modèle : " .. tostring(species))
	local scale = DinoBuilder.ScaleOf(options)
	local level = options and options.Level
	local mutation = options and options.Mutation
	local model = Instance.new("Model")
	model.Name = data.Name
	local root = newPart("Root")
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CastShadow = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	-- pose de repos (os avec une rotation de repos : collerette, ailes...)
	local restPose = DinoBuilder.Solve(data, {}, scale, {})
	for i, box in data.Boxes do
		local p = newPart(box.Bone)
		local size = box.Size * scale
		p.Size = size
		p.CFrame = (restPose[box.Bone] or CFrame.identity) * CFrame.new(box.Center * scale)
		local color, material, transparency, reflectance = paint(box, i, level, mutation)
		p.Color = color
		p.Material = material
		p.Transparency = transparency
		p.Reflectance = reflectance
		-- studs entiers seulement : dessus d'au moins 1 x 1 stud en plastique
		if material == Enum.Material.Plastic and size.X >= 0.99 and size.Z >= 0.99 then
			p.TopSurface = Enum.SurfaceType.Studs
		end
		p.CastShadow = size.Magnitude > 1.2
		p:SetAttribute("Bone", box.Bone)
		p:SetAttribute("Box", i)
		p.Parent = model
	end
	model:SetAttribute("Species", data.Species)
	model:SetAttribute("Family", data.Family)
	model:SetAttribute("Scale", scale)
	if mutation then
		model:SetAttribute("Mutation", mutation)
	end
	if level then
		model:SetAttribute("Level", level)
	end
	if options and options.Rarity then
		model:SetAttribute("Rarity", options.Rarity)
	end
	return model
end

-- Modèle léger pour le serveur : une pièce "Root" invisible + les attributs. Le client (DinoAnimController) construit
-- et anime les briques chez lui ; le serveur déplace seulement le pivot et change l'attribut "State".
function DinoBuilder.CreateProxy(species: string, options: BuildOptions?): Model
	local model = Instance.new("Model")
	model.Name = species
	local root = newPart("Root")
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Species", species)
	model:SetAttribute("Scale", DinoBuilder.ScaleOf(options))
	if options and options.Mutation then
		model:SetAttribute("Mutation", options.Mutation)
	end
	if options and options.Level then
		model:SetAttribute("Level", options.Level)
	end
	if options and options.Rarity then
		model:SetAttribute("Rarity", options.Rarity)
	end
	model:SetAttribute("State", "Idle")
	model:AddTag(DinoBuilder.Tag)
	return model
end

-- Demi-largeur (X) et demi-longueur (Z) de l'anneau de rareté, en studs, autour de l'empreinte du dino
function DinoBuilder.RingShape(data: Data, scale: number): (number, number)
	local sx, sz = data.Size.X / 2, data.Size.Z / 2
	local margin = 0.6 + 0.04 * math.max(data.Size.X, data.Size.Z)
	return (math.min(sx, 0.9 * sz) + margin) * scale, (sz + margin) * scale
end

-- Briques de l'anneau (repère du modèle, pivot au sol) : { position et orientation, taille }
function DinoBuilder.RingSegments(data: Data, scale: number): { { any } }
	local a, b = DinoBuilder.RingShape(data, scale)
	local h = ((a - b) / (a + b)) ^ 2
	local perimeter = math.pi * (a + b) * (1 + 3 * h / (10 + math.sqrt(4 - 3 * h)))
	local n = math.clamp(math.floor(perimeter / (2.4 * math.sqrt(scale)) + 0.5), 10, 24)
	local width = math.max(0.8, math.sqrt(scale))
	local thick = 0.4 * math.max(1, math.sqrt(scale))
	local out: { { any } } = {}
	for i = 0, n - 1 do
		local t0, t1 = i / n * 2 * math.pi, (i + 1) / n * 2 * math.pi
		local p0 = Vector3.new(a * math.cos(t0), 0, b * math.sin(t0))
		local p1 = Vector3.new(a * math.cos(t1), 0, b * math.sin(t1))
		local dir = p1 - p0
		local mid = (p0 + p1) / 2 + Vector3.new(0, thick / 2 + 0.02, 0)
		local cf = CFrame.fromMatrix(mid, dir.Unit, Vector3.yAxis)
		local entry: { any } = { cf, Vector3.new(dir.Magnitude + width * 0.35, thick, width) }
		table.insert(out, entry)
	end
	return out
end

-- ====================================================================== animations
local function hermite(ta: number, va: number, ma: number, tb: number, vb: number, mb: number, t: number): number
	local h = tb - ta
	if h <= 1e-9 then
		return vb
	end
	local x = (t - ta) / h
	local x2 = x * x
	local x3 = x2 * x
	return (2 * x3 - 3 * x2 + 1) * va + (x3 - 2 * x2 + x) * h * ma + (-2 * x3 + 3 * x2) * vb + (x3 - x2) * h * mb
end

local function trackValue(tr: Track, t: number): number
	local times, values = tr.Times, tr.Values
	local n = #times
	if t <= times[1] then
		return values[1]
	elseif t >= times[n] then
		return values[n]
	end
	-- recherche dichotomique du segment
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local m = tr.Slopes
	return hermite(times[lo], values[lo], m[lo], times[hi], values[hi], m[hi], t)
end

-- Pose de l'animation à l'instant t (boucle : t modulo la durée). `out` est réutilisé s'il est donné.
function DinoBuilder.Sample(clip: Clip, t: number, out: Pose?): Pose
	local pose: Pose = out or {}
	for _, v in pose do
		v[1], v[2], v[3], v[4], v[5], v[6] = 0, 0, 0, 0, 0, 0
	end
	local time = t
	if clip.Loop and clip.Length > 0 then
		time = t % clip.Length
	end
	for _, tr in clip.Tracks do
		local v = pose[tr.Bone]
		if not v then
			v = { 0, 0, 0, 0, 0, 0 }
			pose[tr.Bone] = v
		end
		v[tr.Channel] = trackValue(tr, time)
	end
	return pose
end

local function angleLerp(a: number, b: number, w: number): number
	local d = (b - a + 180) % 360 - 180 -- chemin le plus court (un tour complet ne se rembobine pas)
	return a + d * w
end

-- Fondu de deux poses (w = part de b). Les rotations prennent le chemin le plus court.
function DinoBuilder.Blend(a: Pose, b: Pose, w: number, out: Pose?): Pose
	local pose: Pose = out or {}
	local zero = { 0, 0, 0, 0, 0, 0 }
	for bone, va in a do
		local vb = b[bone] or zero
		local v = pose[bone]
		if not v then
			v = table.create(6, 0)
			pose[bone] = v
		end
		v[1], v[2], v[3] = angleLerp(va[1], vb[1], w), angleLerp(va[2], vb[2], w), angleLerp(va[3], vb[3], w)
		v[4], v[5], v[6] = va[4] + (vb[4] - va[4]) * w, va[5] + (vb[5] - va[5]) * w, va[6] + (vb[6] - va[6]) * w
	end
	for bone, vb in b do
		if not a[bone] then
			local v = pose[bone]
			if not v then
				v = table.create(6, 0)
				pose[bone] = v
			end
			v[1], v[2], v[3] = angleLerp(0, vb[1], w), angleLerp(0, vb[2], w), angleLerp(0, vb[3], w)
			v[4], v[5], v[6] = vb[4] * w, vb[5] * w, vb[6] * w
		end
	end
	return pose
end

-- Copie une pose dans `out`
function DinoBuilder.Copy(src: Pose, out: Pose?): Pose
	local pose: Pose = out or {}
	for bone, v in pose do
		if not src[bone] then
			v[1], v[2], v[3], v[4], v[5], v[6] = 0, 0, 0, 0, 0, 0
		end
	end
	for bone, s in src do
		local v = pose[bone]
		if not v then
			v = table.create(6, 0)
			pose[bone] = v
		end
		v[1], v[2], v[3], v[4], v[5], v[6] = s[1], s[2], s[3], s[4], s[5], s[6]
	end
	return pose
end

-- Transformations des os (espace du modèle, échelle `scale`) : M = M_parent * T(pivot + décalage) * R * T(-pivot)
function DinoBuilder.Solve(data: Data, pose: Pose, scale: number, out: { [string]: CFrame }): { [string]: CFrame }
	local rad = math.rad
	for _, bone in data.Bones do
		local parent = if bone.Parent then out[bone.Parent] else nil
		local v = pose[bone.Name]
		local r = bone.Rest
		if r or (v and (v[1] ~= 0 or v[2] ~= 0 or v[3] ~= 0 or v[4] ~= 0 or v[5] ~= 0 or v[6] ~= 0)) then
			local rx, ry, rz = if r then r.X else 0, if r then r.Y else 0, if r then r.Z else 0
			local px, py, pz = 0, 0, 0
			if v then
				rx, ry, rz = rx + v[1], ry + v[2], rz + v[3]
				px, py, pz = v[4], v[5], v[6]
			end
			local pivot = bone.Pivot * scale
			local localCF = CFrame.new(pivot + Vector3.new(px, py, pz) * scale)
				* CFrame.Angles(rad(rx), rad(ry), rad(rz))
				* CFrame.new(-pivot)
			out[bone.Name] = if parent then parent * localCF else localCF
		else
			out[bone.Name] = parent or CFrame.identity
		end
	end
	return out
end

-- Prépare un modèle construit par Build pour être posé vite : pièces, os, positions de repos (tirées des données)
function DinoBuilder.Rig(model: Model, data: Data?): Rig
	local d = data or DinoBuilder.Get(model:GetAttribute("Species") :: string)
	assert(d, "[DinoBuilder] Rig : données introuvables")
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	local parts, bones, rest = {}, {}, {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local bone = p:GetAttribute("Bone")
			local index = p:GetAttribute("Box")
			local box = if type(index) == "number" then d.Boxes[index] else nil
			if type(bone) == "string" and box then
				table.insert(parts, p)
				table.insert(bones, bone)
				table.insert(rest, CFrame.new(box.Center * scale))
			end
		end
	end
	return {
		Model = model,
		Data = d,
		Scale = scale,
		Parts = parts,
		Bones = bones,
		Rest = rest,
		CFrames = table.create(#parts, CFrame.identity),
		Solved = {},
		PerBone = {},
	}
end

-- Place toutes les pièces pour une pose (un seul BulkMoveTo). `base` = repère du modèle (pivot au sol).
function DinoBuilder.Pose(rig: Rig, pose: Pose, base: CFrame)
	local solved = DinoBuilder.Solve(rig.Data, pose, rig.Scale, rig.Solved)
	local per = rig.PerBone
	table.clear(per)
	local out = rig.CFrames
	for i, offset in rig.Rest do
		local bone = rig.Bones[i]
		local m = per[bone]
		if not m then
			m = base * (solved[bone] or CFrame.identity)
			per[bone] = m
		end
		out[i] = m * offset
	end
	workspace:BulkMoveTo(rig.Parts, out, Enum.BulkMoveMode.FireCFrameChanged)
end

return DinoBuilder
