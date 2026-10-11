--!strict
-- Gardiens des zones (brief 7 « gardiens-vol », GDD sections Carte, Animations et Tutoriel). Valeurs de départ à
-- équilibrer. Un gardien par zone dort près des gisements ; quand un bloc de sa zone est arraché, il se réveille et
-- poursuit le porteur. S'il l'attrape : chute cartoon, le bloc retourne à son gisement.
--
-- Vitesse de course : Speed (studs/s) si elle est donnée (Beach), sinon SpeedFactor x le WalkSpeed conseillé de la zone
-- (Config.Speed.WalkSpeedFor(vitesse conseillée)), multiplié par le malus du bloc que porte sa proie (MatchCarry : le
-- même que celui du joueur, Config.Rarity.CarrySpeed). Réveillé, il poursuit sur toute la route, Beach comprise, jusqu'à
-- la place du spawn (ChaseWholeRoute, RouteOnly : hors de toute zone, plus de poursuite) : la course est longue, c'est
-- donc la vitesse qui décide.
--   * à la vitesse conseillée, chargé de n'importe quel bloc, on va 1 / 0.9 = 11 % plus vite que lui : on rentre ;
--   * un nouveau joueur (WalkSpeed 16) est rattrapé dans toutes les zones après la Beach, quel que soit le gisement ;
--   * deux zones trop lent (exemple : vitesse conseillée du Volcano au Meteor Crater) : rattrapé, quel que soit le gisement ;
--   * une zone trop lent : rattrapé depuis le gisement le plus loin de la place du spawn, souvent rentré depuis le plus
--     proche (Fern Forest : toujours rattrapé ; Glacier, Ocean Trench, Meteor Crater : parfois rentré de partout, leurs
--     vitesses conseillées sont proches de la zone d'avant). SpeedFactor plus haut = barrière plus dure (1 : la vitesse
--     conseillée devient un mur ; garder une marge, le joueur contourne le décor, le gardien va tout droit).
--   zone                 Beach  Fern   Swamp  Canyon  Glacier  Volcano  Trench  Crater
--   WalkSpeed conseillé    16     26.4   36     43      49       56       63      70
--   gardien (x0.9)         10*    23.8   32.4   38.7    44.1     50.4     56.7    63     (* Beach : fixe, tutoriel)
--   contre un Legendary (x0.7) : 0.7 x ces valeurs (exemple Crater : 44.1, joueur conseillé chargé : 49)

-- Espèces et tailles proposées par les briefs 5 et 6 (pas encore validées par Snaky), faciles à changer ici.
-- Species : nom de l'espèce (Config.Species du brief 2) ; le modèle vient de src/shared/DinoModels s'il existe, sinon
-- un gardien provisoire en briques. Scale : x1.5 à x3 (GDD : « pour qu'ils fassent peur de loin »).

export type GuardianInfo = {
	Species: string,
	Scale: number,
	Speed: number?, -- studs/s ; sinon SpeedFactor x WalkSpeed conseillé de la zone
}

local Guardians = {
	-- Un gardien par zone (noms identiques à Config.Zones)
	Zones = {
		Beach = { Species = "Oviraptor", Scale = 3, Speed = 10 },
		["Fern Forest"] = { Species = "Stegosaurus", Scale = 2 },
		Swamp = { Species = "Baryonyx", Scale = 2 },
		Canyon = { Species = "Velociraptor", Scale = 2 },
		Glacier = { Species = "Cryolophosaurus", Scale = 2 },
		Volcano = { Species = "Carnotaurus", Scale = 2 },
		["Ocean Trench"] = { Species = "Megalodon", Scale = 1.5 },
		["Meteor Crater"] = { Species = "T-Rex", Scale = 2 },
	} :: { [string]: GuardianInfo },

	SpeedFactor = 0.9, -- course de base = 0.9 x WalkSpeed conseillé de la zone (sans Speed)
	MatchCarry = true, -- course x malus du bloc porté par la proie (sans Speed) : la rareté ne change pas qui s'échappe
	ReturnFactor = 0.5, -- marche du retour au gisement = 0.5 x course (au moins MinReturnSpeed)...
	FarReturnFactor = 1, -- ... mais hors de sa zone (+ Leash), il rentre à FarReturnFactor x course : pas longtemps absent
	MinReturnSpeed = 8,

	-- Durées des états (secondes) : noms identiques aux animations du brief 2
	WakeTime = 1.2, -- Wake : sursaut, se relève
	RoarTime = 1.3, -- Roar : rugit vers le joueur (« RUN!! »), puis Run
	CatchTime = 1.2, -- Catch : coup de tête cartoon, puis Run (autre porteur) ou Return
	SearchTime = 3, -- Search : a perdu le joueur, renifle, puis Return
	BackToSleepTime = 2, -- BackToSleep : tourne sur lui-même et se recouche, puis Sleep
	ReturnSlack = 5, -- Return : bloqué (un parc sur le chemin) plus de distance / vitesse + 5 s, il réapparaît chez lui
	TrappedState = "Idle", -- animation jouée pendant qu'un Bear Trap le bloque (attribut Trapped = true)

	-- Poursuite
	Leash = 40, -- studs autour de sa zone (sa pièce Area) : endormi, il se réveille pour un porteur dans ce rayon
	ChaseWholeRoute = true, -- réveillé, il poursuit sur toute la route (toutes les zones), pas seulement dans sa laisse
	-- La limite : hors de toute zone (pièce Area), c'est-à-dire la place du spawn devant les parcs, il n'y a plus de
	-- poursuite, laisse comprise ; le gardien ne va pas plus loin. Jamais dans un parc non plus.
	RouteOnly = true,
	-- Zones où les gardiens des autres zones n'entrent jamais (la poursuite s'arrête à leur bord ; le gardien d'une de
	-- ces zones garde sa laisse). Vide : les gardiens poursuivent jusqu'à la place du spawn, Beach comprise.
	SafeZones = {} :: { [string]: boolean },
	CatchRange = 4, -- studs (horizontal) entre le pivot du gardien et le joueur pour l'attraper...
	CatchReach = 0.35, -- ... + 0.35 x sa taille (taille de base de l'espèce x Scale) : la tête est devant le pivot
	DefaultSize = 6, -- taille de base (studs) d'une espèce sans fiche Config.Species
	KnockTime = 2, -- secondes au sol pour le joueur attrapé

	TickRate = 0.1, -- secondes entre deux déplacements serveur (le client lisse et anime : pas de PivotTo à 60 Hz)
}

export type Guardians = typeof(Guardians)

return Guardians
