--!strict
-- Course stressante (côté client) : ce que ressent le joueur quand il porte un bloc et quand un gardien le poursuit.
-- Valeurs de départ à équilibrer. Effets joués par src/client/Controllers/StressController.luau, chez lui seulement.
--
-- Intensité (0 à 1) : porter un bloc donne Carry.Base + Carry.PerRank x rang de la rareté (Common 1 ... Secret 7) ;
-- être poursuivi donne au moins Chase.Base, et monte jusqu'à 1 quand le gardien est à Chase.Near studs ou moins.
-- L'intensité règle le battement de cœur (volume, vitesse), la vignette, les couleurs, le champ de vision et la
-- secousse continue de la caméra. Les événements (rugissement, pas du gardien, prise, bonk, piège) ajoutent des
-- secousses ponctuelles (« trauma » de 0 à 1 ; amplitude de la secousse = trauma²).
--
-- Sons : audio public du Creator Store (bibliothèques APM Music et Pro Sound Effects mises à disposition par Roblox),
-- choisis sans écoute : à écouter dans Studio et à changer ici si besoin (Id = "" : pas de son). Le brief 16 (sons du
-- jeu) peut les remplacer.

local Stress = {
	-- Intensité
	Carry = { Base = 0.25, PerRank = 0.04 }, -- Common 0.29 ... Secret 0.53
	Chase = { Base = 0.55, Near = 12, Far = 70 }, -- 0.55 à Far studs et plus, 1 à Near studs et moins
	Rise = 2.5, -- montée de l'intensité (par seconde)
	Fall = 0.7, -- descente (on se calme lentement)

	-- Image
	Vignette = {
		Width = 0.34, -- part de l'écran couverte par le dégradé de chaque bord
		Carry = 0.6, -- opacité au bord en portant un bloc (x intensité)
		Chase = 0.8, -- opacité au bord poursuivi (x intensité)
		Pulse = 0.22, -- en plus, sur chaque battement de cœur
		CarryColor = Color3.fromRGB(10, 6, 14),
		ChaseColor = Color3.fromRGB(150, 0, 12),
	},
	Grade = { Saturation = -0.35, Contrast = 0.12, Tint = Color3.fromRGB(255, 208, 208) }, -- à intensité 1
	Flash = { Roar = 0.35, Catch = 0.6, Bonk = 0.3, Fade = 2.2 }, -- éclair rouge (opacité), disparition par seconde
	Fov = { Chase = 8, RoarPunch = 14, CatchPunch = -10, PunchFade = 3 }, -- degrés en plus (ou en moins)

	-- Secousse de la caméra
	Shake = {
		MaxAngle = 2.2, -- degrés (tangage, lacet, roulis) à trauma 1
		MaxOffset = 0.35, -- studs à trauma 1
		Frequency = 14, -- vitesse du bruit
		Decay = 1.4, -- trauma perdu par seconde
		Chase = 0.3, -- trauma continu au plus près du gardien (x proximité)
		Roar = 0.85,
		Step = 0.32, -- pas du gardien tout près (moins quand il est loin)
		Catch = 1,
		Bonk = 0.6,
		Trap = 0.5,
		Nearby = 0.2, -- bonk, prise ou piège d'un autre joueur à moins de NearbyRange studs
		NearbyRange = 30,
		ReducedMotion = 0.3, -- multiplicateur quand le joueur a activé « Reduce Motion » dans les réglages Roblox
	},
	Step = { Stride = 9, Min = 0.28, Max = 0.6, Hearing = 90 }, -- pas du gardien qui court : Stride / vitesse (s), entendus jusqu'à Hearing studs

	Sounds = {
		Heartbeat = { Id = "rbxassetid://9043365842", Volume = 0.9, Bpm = 96, MinSpeed = 0.85, MaxSpeed = 1.45 }, -- boucle (APM)
		Roar = { Id = "rbxassetid://9113980319", Volume = 0.9, Speed = 0.85 }, -- rugissement du réveil (Pro Sound Effects)
		Stinger = { Id = "rbxassetid://1846887497", Volume = 0.45, Speed = 1 }, -- coup d'orchestre du réveil (APM)
		Step = { Id = "rbxassetid://9119874551", Volume = 0.7, Speed = 0.8 }, -- pas lourd du gardien (Pro Sound Effects)
		Catch = { Id = "rbxassetid://9113041746", Volume = 0.9, Speed = 0.9 }, -- choc de la prise (Pro Sound Effects)
	},

	-- Gros textes au milieu de l'écran ("" : pas de texte ; le HUD du brief 12 peut les reprendre)
	Texts = {
		Run = { Text = "RUN!!", Color = Color3.fromRGB(255, 70, 60), Time = 2.2 },
		Escaped = { Text = "ESCAPED!", Color = Color3.fromRGB(120, 240, 110), Time = 1.6 },
		Caught = { Text = "CAUGHT!", Color = Color3.fromRGB(255, 70, 60), Time = 1.6 },
	},
}

export type Stress = typeof(Stress)

return Stress
