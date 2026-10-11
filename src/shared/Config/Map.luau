--!strict
-- La map (brief 10 « map ») : mesures du spawn, des parcs et de la route, longueur de chaque zone, places des gisements
-- et budgets (lumières, décor). La map est construite par src/server/Map/MapBuilder.luau au démarrage du serveur, avec
-- les points d'ancrage nommés lus par PlotService et ZoneService (docs/BOUCLE.md, docs/MAP.md).
--
-- Repère : le sol est à Y = GroundTop. Les 5 parcs (serveurs de 5 joueurs) sont alignés sur X, leur entrée tournée vers +Z ; la place du spawn
-- s'étend devant eux (Z de 0 à Plaza.Depth), puis la route part vers +Z, zone 1 (Beach) d'abord.

local Map = {
	Seed = 20261011, -- graine du décor : la même map à chaque démarrage
	GroundTop = 1, -- hauteur du dessus du sol

	-- Parcs : Count parcs côte à côte (Plot1 à gauche, X négatif), Gap studs de haie entre deux parcs. Un parc par joueur :
	-- Count = nombre de joueurs max du serveur (à régler aussi sur Roblox : Creator Hub, Places, Max Players).
	-- Avec un nombre impair, le parc du milieu est en face de la route.
	Plots = {
		Count = 5,
		Width = 80, -- sur X
		Depth = 120, -- sur Z (l'entrée est au bord Z = 0, le fond à Z = -Depth)
		Gap = 12,
		EntranceWidth = 16,
	},

	-- Place du spawn devant les parcs (pavés, lampadaires, panneau de la route)
	Plaza = {
		Depth = 70, -- de Z = 0 (entrées des parcs) au début de la route
		Margin = 26, -- studs de place en plus à gauche du premier parc et à droite du dernier
		Back = 40, -- forêt derrière les parcs (fond du décor)
	},

	-- Route : couloir de Width studs, bordé de falaises (Border studs de chaque côté) et d'un mur invisible
	Route = {
		Width = 180,
		Border = 36,
		PathWidth = 24, -- chemin central
		BarrierHeight = 160, -- murs invisibles (bords de la route et de la place)
		EndDepth = 60, -- falaise de fin après la dernière zone
	},

	-- Longueur de chaque zone sur Z (noms de Config.Zones), de plus en plus longues
	Zones = {
		Beach = { Length = 220 },
		["Fern Forest"] = { Length = 240 },
		Swamp = { Length = 250 },
		Canyon = { Length = 260 },
		Glacier = { Length = 270 },
		Volcano = { Length = 280 },
		["Ocean Trench"] = { Length = 290 },
		["Meteor Crater"] = { Length = 300 },
	},

	-- Gisements de chaque zone : X (studs depuis l'axe de la route) et T (fraction de la longueur de la zone)
	Sites = {
		{ X = -52, T = 0.3 },
		{ X = 54, T = 0.5 },
		{ X = -48, T = 0.8 },
	} :: { { X: number, T: number } },
	SiteSlots = 4, -- emplacements de blocs (Attachments Slot1...) par gisement

	-- Gardien : sa clairière au milieu du chemin (T = fraction de la longueur), Radius studs
	Guardian = { T = 0.6, Radius = 30 },

	-- Budgets
	Lights = {
		Zone = 6, -- PointLights par zone
		Plot = 2, -- par parc
		Plaza = 10, -- sur la place du spawn
	},
	MaxPartsPerZone = 2200, -- contrôle (test hors Studio et FossilDebug « map »)
}

export type Map = typeof(Map)

return Map
