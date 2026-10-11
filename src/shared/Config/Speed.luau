--!strict
-- Vitesse, treadmill et trails (brief 4 « vitesse-treadmill »). Valeurs de départ à équilibrer (GDD : Vitesse et
-- treadmill). La vitesse est la stat principale : un nombre qui part de 0 et monte jusqu'à des millions (la dernière
-- zone conseille 25 M). WalkSpeedFor la transforme en WalkSpeed Roblox avec une courbe lisible : chaque fois que la
-- vitesse est multipliée par 10, on court PerDecade studs/s plus vite.
--   vitesse    0    1 K    10 K   50 K   200 K   1 M   5 M   25 M
--   WalkSpeed  16   26     36     43     49      56    63    70
-- Les prix Robux du treadmill, des passes et des trails Robux sont dans Config/Shop.luau.

export type Trail = {
	Name: string,
	Tier: string, -- Common, Uncommon, Rare, Epic, Legendary, Mythic, Ancient, Celestial, Cosmic, Divine
	Order: number, -- ordre d'affichage (1 = la moins chère)
	Price: number, -- prix en argent du jeu
	Speed: number, -- vitesse ajoutée tant que la trail est portée
	Colors: { Color3 }, -- couleur du début et de la fin de la traînée
	LightEmission: number?, -- éclat de la traînée (sinon TrailLook.LightEmission)
}

-- Trail Robux : un game pass (Config.Shop.Passes[Pass], avec son prix et son Multiplier)
export type RobuxTrail = {
	Name: string,
	Pass: string, -- clé du passe dans Config.Shop.Passes
	Order: number, -- ordre d'affichage (1 = la moins chère)
	Colors: { Color3 },
	LightEmission: number?,
}

local WALK = {
	Base = 16, -- WalkSpeed à vitesse 0 (celui de Roblox)
	PerDecade = 10, -- WalkSpeed en plus chaque fois que la vitesse est multipliée par 10
	Pivot = 100, -- vitesse à partir de laquelle la courbe commence à monter vraiment
	Max = 100, -- WalkSpeed maximal
}

-- WalkSpeed (studs/s) d'un joueur qui a `speed` de vitesse, avant malus (bloc porté, piège...). Aussi pour l'UI et les
-- gardiens (brief 7) : Config.Speed.WalkSpeedFor(zone.AdvisedSpeed) donne le WalkSpeed conseillé d'une zone.
local function walkSpeedFor(speed: number): number
	if type(speed) ~= "number" or speed ~= speed or speed <= 0 then
		return WALK.Base
	end
	if speed == math.huge then
		return WALK.Max
	end
	return math.min(WALK.Max, WALK.Base + WALK.PerDecade * math.log10(1 + speed / WALK.Pivot))
end

local Speed = {
	Max = 1e15, -- plafond de la vitesse gagnée (data.Speed)
	WalkSpeed = WALK,
	WalkSpeedFor = walkSpeedFor,
	RefreshInterval = 0.2, -- secondes entre deux mises à jour du WalkSpeed (bloc porté, trail, effets)

	-- Treadmill du parc : vitesse gagnée chaque seconde en courant dessus ou AFK dessus (rien à regarder).
	-- Sans achat, le tapis donne FreeMultiplier x BaseGain (tout le monde peut AFK dessus) ; l'achat (niveau 1, 25 R$)
	-- et les niveaux suivants sont dans Config.Shop.Treadmill.
	Treadmill = {
		Tag = "Treadmill", -- BasePart taguée (CollectionService) = surface du tapis
		OwnerAttribute = "OwnerUserId", -- sur la pièce ou un ancêtre (parc) : seul ce joueur y gagne de la vitesse
		BaseGain = 25, -- vitesse par seconde au niveau 1 (x1), avant le passe x2 Treadmill
		-- Treadmill pas acheté (niveau 0) : gain x0.2 (5 vitesse/s), 5 fois moins que l'achat. 0 = rien sans achat.
		FreeMultiplier = 0.2,
		TickSeconds = 1, -- la vitesse est donnée toutes les TickSeconds
		Height = 8, -- hauteur au-dessus de la surface où le joueur compte comme dessus (studs)
		HintCooldown = 15, -- secondes entre deux rappels « achète le treadmill » (seulement si FreeMultiplier = 0)

		-- AFK : Roblox expulse un joueur inactif depuis 20 min. Un joueur inactif depuis RejoinAfter secondes sur son
		-- treadmill est reconnecté au même serveur (TeleportService, pas dans Studio) et reposé sur son tapis.
		Afk = {
			Rejoin = true,
			RejoinAfter = 15 * 60, -- secondes d'inactivité (Players.LocalPlayer.Idled) avant la reconnexion
			RejoinCooldown = 60, -- secondes entre deux demandes de reconnexion d'un même joueur
			Attribute = "AfkReturn", -- attribut posé sur le joueur revenu d'une reconnexion AFK (le client le montre)
		},
	},

	-- Trails achetées avec l'argent du jeu : vitesse gratuite pour les joueurs qui ne paient pas. Une seule portée à la
	-- fois ; sa vitesse s'ajoute tant qu'elle est portée.
	Trails = {
		Dust = { Name = "Dust Trail", Tier = "Common", Order = 1, Price = 250, Speed = 300, Colors = { Color3.fromRGB(214, 196, 160), Color3.fromRGB(150, 135, 110) } },
		Fern = { Name = "Fern Trail", Tier = "Uncommon", Order = 2, Price = 2_500, Speed = 1_500, Colors = { Color3.fromRGB(120, 210, 90), Color3.fromRGB(40, 140, 60) } },
		Tide = { Name = "Tide Trail", Tier = "Rare", Order = 3, Price = 25_000, Speed = 6_000, Colors = { Color3.fromRGB(90, 190, 255), Color3.fromRGB(30, 90, 200) } },
		Crystal = { Name = "Crystal Trail", Tier = "Epic", Order = 4, Price = 200_000, Speed = 25_000, Colors = { Color3.fromRGB(200, 140, 255), Color3.fromRGB(120, 60, 220) } },
		Amber = { Name = "Amber Trail", Tier = "Legendary", Order = 5, Price = 1_500_000, Speed = 80_000, Colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(230, 120, 20) } },
		Lava = { Name = "Lava Trail", Tier = "Mythic", Order = 6, Price = 10_000_000, Speed = 300_000, Colors = { Color3.fromRGB(255, 110, 50), Color3.fromRGB(200, 30, 30) } },
		Fossil = { Name = "Fossil Trail", Tier = "Ancient", Order = 7, Price = 75_000_000, Speed = 1_000_000, Colors = { Color3.fromRGB(245, 240, 225), Color3.fromRGB(170, 150, 120) } },
		Aurora = { Name = "Aurora Trail", Tier = "Celestial", Order = 8, Price = 500_000_000, Speed = 3_000_000, Colors = { Color3.fromRGB(90, 255, 200), Color3.fromRGB(150, 90, 255) } },
		Meteor = { Name = "Meteor Trail", Tier = "Cosmic", Order = 9, Price = 4_000_000_000, Speed = 10_000_000, Colors = { Color3.fromRGB(255, 160, 60), Color3.fromRGB(60, 40, 120) } },
		Rainbow = { Name = "Rainbow Trail", Tier = "Divine", Order = 10, Price = 30_000_000_000, Speed = 30_000_000, Colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 160, 255) } },
	} :: { [string]: Trail },

	-- Trails Robux (game passes, prix et multiplicateur dans Config.Shop.Passes) : portée, une trail Robux garde la
	-- vitesse de la meilleure trail achetée avec l'argent du jeu et multiplie toute la vitesse par le Multiplier de
	-- son passe. Elle vaut donc toujours mieux que les trails en argent. Clés différentes de celles de Trails.
	RobuxTrails = {
		Neon = { Name = "Neon Trail", Pass = "NeonTrail", Order = 1, LightEmission = 1, Colors = { Color3.fromRGB(0, 255, 230), Color3.fromRGB(255, 40, 200) } },
		Galaxy = { Name = "Galaxy Trail", Pass = "GalaxyTrail", Order = 2, LightEmission = 0.8, Colors = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(20, 10, 70) } },
		Golden = { Name = "Golden Trail", Pass = "GoldenTrail", Order = 3, LightEmission = 1, Colors = { Color3.fromRGB(255, 215, 40), Color3.fromRGB(255, 250, 215) } },
	} :: { [string]: RobuxTrail },

	-- Traînée visible derrière le joueur (Trail entre deux Attachments de HumanoidRootPart)
	TrailLook = {
		Lifetime = 0.6,
		Height = 1.6, -- écart vertical entre les deux Attachments (studs)
		LightEmission = 0.2,
	},

	-- Récompense like + favori + groupe : seule l'appartenance au groupe peut être vérifiée par le serveur.
	-- GroupId = 0 tant que Snaky n'a pas de groupe : la récompense reste cachée.
	GroupReward = {
		GroupId = 0,
		Speed = 1_000, -- vitesse donnée une fois pour toutes
	},
}

export type Speed = typeof(Speed)

return Speed
