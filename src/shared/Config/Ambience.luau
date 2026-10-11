--!strict
-- Ambiances de la map : heure du jour, lumière, brume (Atmosphere), nuages, couleurs de l'image, bloom, particules
-- autour du joueur et ciel animé (aurores, planète, étoiles filantes, ptérosaures) pour la place du spawn (avec les
-- parcs) et chacune des 8 zones de la route. Valeurs de départ à régler dans Studio.
--
-- Appliquées chez chaque joueur seulement par src/client/Controllers/AmbienceController.luau, selon l'endroit où se
-- trouve son personnage (Z sur la route, mêmes mesures que la map : Config.Map), avec un fondu sur Blend studs autour
-- de chaque frontière et en douceur après une téléportation (Response). Le serveur pose l'ambiance de la place au
-- démarrage (MapBuilder.Lighting) : rien ne saute à l'arrivée d'un joueur.
--
-- Couleurs et nombres se mélangent pendant les fondus ; Motes donne le nombre de particules de chaque sorte (voir
-- Motes plus bas) ; Aurora et Planet vont de 0 (rien) à 1 ; ShootingStars : étoiles filantes par seconde ; Birds :
-- ptérosaures qui tournent haut dans le ciel.

export type Preset = {
	ClockTime: number, -- heure (0 à 24) : soleil levé vers 6 h, couché vers 18 h
	Brightness: number,
	Exposure: number, -- Lighting.ExposureCompensation
	Ambient: Color3, -- lumière des coins à l'ombre
	OutdoorAmbient: Color3, -- lumière du ciel dehors
	SunTint: Color3, -- Lighting.ColorShift_Top : teinte ajoutée aux faces éclairées par le soleil (noir = aucune)
	Atmosphere: { Density: number, Offset: number, Color: Color3, Decay: Color3, Glare: number, Haze: number },
	Clouds: { Cover: number, Density: number, Color: Color3 },
	Sky: { Stars: number, Sun: number, Moon: number }, -- nombre d'étoiles, taille du soleil et de la lune (degrés)
	Grade: { Brightness: number, Contrast: number, Saturation: number, Tint: Color3 },
	Bloom: { Intensity: number, Size: number, Threshold: number },
	SunRays: { Intensity: number, Spread: number },
	Motes: { [string]: number },
	Aurora: number,
	AuroraColors: { Color3 }, -- une couleur par ruban (Sky.Aurora.Ribbons)
	Planet: number,
	ShootingStars: number,
	Birds: number,
}

-- Particules en petits cubes autour du joueur (style studs, aucune texture)
export type MoteKind = {
	Colors: { Color3 },
	Size: { number }, -- côté du cube (studs) : min, max
	Neon: boolean, -- lumineux
	Transparency: number,
	Life: { number }, -- durée de vie (s) : min, max
	Velocity: Vector3, -- dérive (studs/s)
	Jitter: Vector3, -- dérive au hasard en plus, de -x à x (studs/s)
	Wobble: number, -- balancement (studs)
	WobbleSpeed: number,
	Blink: number, -- 0 à 1 : clignote (lucioles)
	Spin: number, -- tours sur lui-même (radians/s)
	Low: number, -- hauteur d'apparition par rapport au centre du personnage (studs) : de Low à High
	High: number,
}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

local function preset(values: { [string]: any }): Preset
	local p = values :: any
	p.Motes = p.Motes or {}
	p.Aurora = p.Aurora or 0
	p.AuroraColors = p.AuroraColors or { rgb(90, 255, 170), rgb(80, 220, 255), rgb(190, 120, 255) }
	p.Planet = p.Planet or 0
	p.ShootingStars = p.ShootingStars or 0
	p.Birds = p.Birds or 0
	return p :: Preset
end

local Ambience = {
	Blend = 70, -- studs de fondu autour de chaque frontière (moitié de chaque côté)
	Response = 1.5, -- vitesse à laquelle l'ambiance rejoint celle du lieu (par seconde ; ~2 s après une téléportation)
	LightingRate = 20, -- écritures de Lighting par seconde au plus pendant un fondu (rien quand c'est stable)
	GradeName = "AmbienceGrade", -- ColorCorrectionEffect de l'ambiance dans Lighting (les autres effets de couleur s'y ajoutent)

	-- Place du spawn et parcs (tout ce qui est avant la route), puis les zones (noms de Config.Zones)
	Regions = {
		-- Après-midi ensoleillé, nuages blancs, couleurs franches
		Plaza = preset({
			ClockTime = 14,
			Brightness = 2.3,
			Exposure = 0.1,
			Ambient = rgb(92, 92, 108),
			OutdoorAmbient = rgb(150, 152, 166),
			SunTint = rgb(18, 14, 4),
			Atmosphere = { Density = 0.27, Offset = 0.2, Color = rgb(200, 222, 242), Decay = rgb(112, 142, 182), Glare = 0.25, Haze = 1.2 },
			Clouds = { Cover = 0.52, Density = 0.65, Color = WHITE },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.12, Tint = rgb(255, 252, 246) },
			Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.5 },
			SunRays = { Intensity = 0.03, Spread = 0.6 },
		}),

		-- Midi tropical : ciel très clair, mer turquoise, quelques ptérosaures au loin
		Beach = preset({
			ClockTime = 13.2,
			Brightness = 2.6,
			Exposure = 0.12,
			Ambient = rgb(100, 100, 112),
			OutdoorAmbient = rgb(164, 166, 172),
			SunTint = rgb(22, 16, 2),
			Atmosphere = { Density = 0.24, Offset = 0.25, Color = rgb(190, 226, 246), Decay = rgb(98, 160, 212), Glare = 0.4, Haze = 0.9 },
			Clouds = { Cover = 0.45, Density = 0.6, Color = WHITE },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.03, Contrast = 0.08, Saturation = 0.2, Tint = rgb(255, 250, 240) },
			Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.45 },
			SunRays = { Intensity = 0.05, Spread = 0.6 },
			Birds = 4,
		}),

		-- Matin doré dans la brume légère, spores et lucioles entre les fougères
		["Fern Forest"] = preset({
			ClockTime = 8.6,
			Brightness = 2.1,
			Exposure = 0.12,
			Ambient = rgb(90, 106, 86),
			OutdoorAmbient = rgb(140, 160, 126),
			SunTint = rgb(36, 28, 6),
			Atmosphere = { Density = 0.38, Offset = 0.12, Color = rgb(212, 230, 192), Decay = rgb(122, 150, 102), Glare = 0.6, Haze = 2.2 },
			Clouds = { Cover = 0.6, Density = 0.7, Color = rgb(255, 250, 236) },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.14, Tint = rgb(250, 255, 238) },
			Bloom = { Intensity = 0.45, Size = 26, Threshold = 1.35 },
			SunRays = { Intensity = 0.09, Spread = 0.45 },
			Motes = { Fireflies = 16, Spores = 14 },
			Birds = 2,
		}),

		-- Fin d'après-midi dans le brouillard vert, champignons et feux follets qui brillent, plein de lucioles
		Swamp = preset({
			ClockTime = 17.4,
			Brightness = 1.7,
			Exposure = 0.12,
			Ambient = rgb(86, 102, 82),
			OutdoorAmbient = rgb(122, 142, 116),
			SunTint = rgb(14, 26, 6),
			Atmosphere = { Density = 0.5, Offset = 0.06, Color = rgb(152, 176, 140), Decay = rgb(80, 100, 72), Glare = 0.2, Haze = 2.7 },
			Clouds = { Cover = 0.82, Density = 0.75, Color = rgb(176, 190, 166) },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.01, Contrast = 0.08, Saturation = -0.02, Tint = rgb(234, 250, 226) },
			Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.2 },
			SunRays = { Intensity = 0.02, Spread = 0.4 },
			Motes = { Fireflies = 34 },
		}),

		-- Heure dorée sur la roche rouge, poussière de sable dans le vent
		Canyon = preset({
			ClockTime = 16.7,
			Brightness = 2.4,
			Exposure = 0.05,
			Ambient = rgb(110, 90, 80),
			OutdoorAmbient = rgb(170, 140, 120),
			SunTint = rgb(60, 30, 4),
			Atmosphere = { Density = 0.3, Offset = 0.2, Color = rgb(246, 206, 166), Decay = rgb(190, 120, 86), Glare = 0.8, Haze = 1.6 },
			Clouds = { Cover = 0.35, Density = 0.55, Color = rgb(255, 232, 206) },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.14, Tint = rgb(255, 240, 222) },
			Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.4 },
			SunRays = { Intensity = 0.06, Spread = 0.5 },
			Motes = { Dust = 22 },
			Birds = 2,
		}),

		-- Aube rose polaire, neige qui tombe, aurore boréale douce dans le ciel
		Glacier = preset({
			ClockTime = 6.8,
			Brightness = 2,
			Exposure = 0.2,
			Ambient = rgb(112, 116, 142),
			OutdoorAmbient = rgb(176, 182, 212),
			SunTint = rgb(42, 20, 30),
			Atmosphere = { Density = 0.33, Offset = 0.18, Color = rgb(226, 216, 242), Decay = rgb(150, 170, 230), Glare = 0.9, Haze = 1.6 },
			Clouds = { Cover = 0.5, Density = 0.6, Color = rgb(255, 232, 242) },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.03, Contrast = 0.06, Saturation = 0.1, Tint = rgb(242, 246, 255) },
			Bloom = { Intensity = 0.45, Size = 26, Threshold = 1.35 },
			SunRays = { Intensity = 0.06, Spread = 0.5 },
			Motes = { Snow = 46 },
			Aurora = 0.55,
			AuroraColors = { rgb(100, 255, 190), rgb(90, 220, 255), rgb(170, 140, 255) },
		}),

		-- Crépuscule rouge sous les nuages de cendre, braises qui montent, cendres qui tombent
		Volcano = preset({
			ClockTime = 18,
			Brightness = 1.8,
			Exposure = 0.05,
			Ambient = rgb(122, 78, 66),
			OutdoorAmbient = rgb(166, 108, 92),
			SunTint = rgb(78, 26, 10),
			Atmosphere = { Density = 0.45, Offset = 0.08, Color = rgb(192, 112, 90), Decay = rgb(110, 40, 30), Glare = 0.3, Haze = 2.4 },
			Clouds = { Cover = 0.88, Density = 0.8, Color = rgb(112, 82, 76) },
			Sky = { Stars = 600, Sun = 24, Moon = 11 },
			Grade = { Brightness = 0.01, Contrast = 0.12, Saturation = 0.08, Tint = rgb(255, 234, 216) },
			Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.2 },
			SunRays = { Intensity = 0.04, Spread = 0.4 },
			Motes = { Embers = 32, Ash = 18 },
		}),

		-- Bleu profond comme sous la mer, rayons de lumière, bulles et plancton lumineux
		["Ocean Trench"] = preset({
			ClockTime = 12.5,
			Brightness = 1.9,
			Exposure = 0.08,
			Ambient = rgb(72, 102, 132),
			OutdoorAmbient = rgb(112, 152, 186),
			SunTint = rgb(0, 18, 40),
			Atmosphere = { Density = 0.48, Offset = 0.1, Color = rgb(92, 166, 216), Decay = rgb(26, 76, 140), Glare = 0.2, Haze = 2.4 },
			Clouds = { Cover = 0.6, Density = 0.6, Color = rgb(200, 230, 255) },
			Sky = { Stars = 3000, Sun = 21, Moon = 11 },
			Grade = { Brightness = 0.01, Contrast = 0.06, Saturation = 0.06, Tint = rgb(212, 236, 255) },
			Bloom = { Intensity = 0.5, Size = 26, Threshold = 1.3 },
			SunRays = { Intensity = 0.11, Spread = 0.6 },
			Motes = { Bubbles = 28, Plankton = 18 },
		}),

		-- Nuit étoilée violette : grande lune, planète à anneau, aurore verte et rose, étoiles filantes, poussière d'étoiles
		["Meteor Crater"] = preset({
			ClockTime = 22,
			Brightness = 1.4,
			Exposure = 0.35,
			Ambient = rgb(98, 84, 138),
			OutdoorAmbient = rgb(128, 108, 172),
			SunTint = rgb(30, 20, 62),
			Atmosphere = { Density = 0.3, Offset = 0.2, Color = rgb(122, 96, 192), Decay = rgb(52, 30, 102), Glare = 0, Haze = 1.4 },
			Clouds = { Cover = 0.28, Density = 0.5, Color = rgb(132, 106, 200) },
			Sky = { Stars = 5000, Sun = 21, Moon = 24 },
			Grade = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.18, Tint = rgb(234, 226, 255) },
			Bloom = { Intensity = 0.7, Size = 30, Threshold = 1.1 },
			SunRays = { Intensity = 0, Spread = 0.4 },
			Motes = { Stardust = 34 },
			Aurora = 0.85,
			AuroraColors = { rgb(90, 255, 150), rgb(255, 90, 220), rgb(120, 200, 255) },
			Planet = 1,
			ShootingStars = 0.45,
		}),
	} :: { [string]: Preset },

	-- Particules autour du joueur : petits cubes posés dans un disque de Radius studs autour du personnage, recyclés
	Motes = {
		Max = 64, -- cubes au plus (toutes sortes ensemble)
		Radius = 42,
		SpawnPerFrame = 3, -- (pas d'apparition en bloc)
		Kinds = {
			Fireflies = {
				Colors = { rgb(255, 238, 120), rgb(206, 255, 110) },
				Size = { 0.22, 0.34 },
				Neon = true,
				Transparency = 0.1,
				Life = { 4, 7 },
				Velocity = Vector3.new(0, 0.2, 0),
				Jitter = Vector3.new(0.6, 0.4, 0.6),
				Wobble = 1.4,
				WobbleSpeed = 1.1,
				Blink = 0.8,
				Spin = 0,
				Low = -1,
				High = 9,
			},
			Spores = {
				Colors = { rgb(222, 255, 200), rgb(255, 250, 216) },
				Size = { 0.18, 0.28 },
				Neon = true,
				Transparency = 0.35,
				Life = { 5, 9 },
				Velocity = Vector3.new(0.3, 0.5, 0.2),
				Jitter = Vector3.new(0.4, 0.2, 0.4),
				Wobble = 0.8,
				WobbleSpeed = 0.6,
				Blink = 0,
				Spin = 1,
				Low = -2,
				High = 14,
			},
			Dust = {
				Colors = { rgb(236, 200, 150), rgb(220, 170, 122) },
				Size = { 0.15, 0.3 },
				Neon = false,
				Transparency = 0.35,
				Life = { 3, 6 },
				Velocity = Vector3.new(3, 0.2, 1),
				Jitter = Vector3.new(1, 0.3, 1),
				Wobble = 0.5,
				WobbleSpeed = 1.5,
				Blink = 0,
				Spin = 2,
				Low = -2,
				High = 7,
			},
			Snow = {
				Colors = { WHITE, rgb(232, 242, 255) },
				Size = { 0.3, 0.5 },
				Neon = false,
				Transparency = 0.05,
				Life = { 6, 9 },
				Velocity = Vector3.new(1.2, -4.5, 0.6),
				Jitter = Vector3.new(0.6, 0.8, 0.6),
				Wobble = 1,
				WobbleSpeed = 1.3,
				Blink = 0,
				Spin = 1.5,
				Low = 6,
				High = 32,
			},
			Embers = {
				Colors = { rgb(255, 150, 50), rgb(255, 92, 32), rgb(255, 204, 92) },
				Size = { 0.2, 0.35 },
				Neon = true,
				Transparency = 0.05,
				Life = { 2.5, 4.5 },
				Velocity = Vector3.new(0.6, 4, 0.3),
				Jitter = Vector3.new(1.2, 1.5, 1.2),
				Wobble = 0.7,
				WobbleSpeed = 2.2,
				Blink = 0.4,
				Spin = 3,
				Low = -3,
				High = 5,
			},
			Ash = {
				Colors = { rgb(92, 86, 86), rgb(132, 122, 120) },
				Size = { 0.2, 0.35 },
				Neon = false,
				Transparency = 0.2,
				Life = { 5, 8 },
				Velocity = Vector3.new(0.8, -2.2, 0.4),
				Jitter = Vector3.new(0.6, 0.6, 0.6),
				Wobble = 1,
				WobbleSpeed = 1,
				Blink = 0,
				Spin = 1.5,
				Low = 6,
				High = 26,
			},
			Bubbles = {
				Colors = { rgb(204, 242, 255), rgb(172, 226, 255) },
				Size = { 0.25, 0.6 },
				Neon = false,
				Transparency = 0.45,
				Life = { 3, 6 },
				Velocity = Vector3.new(0, 3.2, 0),
				Jitter = Vector3.new(0.3, 1, 0.3),
				Wobble = 0.6,
				WobbleSpeed = 3,
				Blink = 0,
				Spin = 0,
				Low = -3,
				High = 7,
			},
			Plankton = {
				Colors = { rgb(92, 240, 255), rgb(122, 255, 212), rgb(172, 152, 255) },
				Size = { 0.15, 0.25 },
				Neon = true,
				Transparency = 0.25,
				Life = { 4, 8 },
				Velocity = Vector3.new(0.2, 0.1, 0.2),
				Jitter = Vector3.new(0.4, 0.3, 0.4),
				Wobble = 1.2,
				WobbleSpeed = 0.8,
				Blink = 0.6,
				Spin = 0,
				Low = -2,
				High = 13,
			},
			Stardust = {
				Colors = { rgb(192, 122, 255), rgb(112, 255, 162), rgb(255, 122, 230), rgb(122, 222, 255) },
				Size = { 0.18, 0.32 },
				Neon = true,
				Transparency = 0.1,
				Life = { 3, 6 },
				Velocity = Vector3.new(0, 0.6, 0),
				Jitter = Vector3.new(0.5, 0.4, 0.5),
				Wobble = 1,
				WobbleSpeed = 1,
				Blink = 0.7,
				Spin = 2,
				Low = -2,
				High = 13,
			},
		} :: { [string]: MoteKind },
	},

	-- Ciel animé, posé autour de la caméra (il la suit comme un décor à l'infini) ; pièces lumineuses sans collision
	Sky = {
		Distance = 260, -- studs entre la caméra et les éléments du ciel
		Aurora = {
			Ribbons = 3,
			Segments = 14,
			Headings = { 0, 140, 235 }, -- direction de chaque ruban (degrés, 0 = vers le bout de la route)
			Arc = 90, -- largeur de chaque ruban (degrés)
			Height = 70, -- hauteur du rideau
			Elevation = 110, -- bas des rubans au-dessus de la caméra (studs)
			Speed = 0.35, -- ondulation
		},
		Planet = {
			Direction = Vector3.new(-0.55, 0.42, 0.72), -- vers où la regarder depuis la caméra
			Radius = 30,
			Colors = { rgb(118, 78, 178), rgb(156, 104, 214), rgb(96, 64, 160) },
			Ring = rgb(226, 196, 255),
		},
		ShootingStars = {
			Pool = 3, -- en même temps au plus
			Speed = 320, -- studs/s
			Life = { 0.6, 1 },
			Length = 24,
			Color = rgb(236, 228, 255),
		},
		Birds = {
			Pool = 5,
			Height = { 70, 95 }, -- au-dessus de la caméra
			Radius = { 45, 110 }, -- rayon de leur cercle
			Speed = { 0.18, 0.32 }, -- tours (radians/s)
			Color = rgb(70, 56, 72),
		},
	},

	-- Décor flottant de la map (cristaux, feux follets, méduses) : modèles tagués Float.Tag, attributs FloatHeight
	-- (studs), FloatSpeed (radians/s), FloatSpin (radians/s). Animés chez le joueur seulement, près de lui.
	Float = {
		Tag = "AmbientFloat",
		Range = 220, -- studs autour de la caméra
		Height = 0.6, -- valeurs par défaut des attributs
		Speed = 1.2,
		Spin = 0,
	},
}

export type Ambience = typeof(Ambience)

return Ambience
