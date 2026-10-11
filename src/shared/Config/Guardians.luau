--!strict
-- Gardiens des zones (brief 7 « gardiens-vol », GDD sections Carte, Animations et Tutoriel). Valeurs de départ à
-- équilibrer. Un gardien par zone dort près des gisements ; quand un bloc de sa zone est arraché, il se réveille et
-- poursuit le porteur. S'il l'attrape : chute cartoon, le bloc retourne à son gisement.
--
-- Vitesse de course : Speed (studs/s) si elle est donnée, sinon SpeedFactor x le WalkSpeed conseillé de la zone
-- (Config.Speed.WalkSpeedFor(vitesse conseillée)). Un joueur à la vitesse conseillée, même chargé, garde son avance ;
-- un joueur trop lent pour la zone se fait rattraper (la vitesse conseillée n'est pas un mur).
--   zone             Beach  Fern   Swamp  Canyon  Glacier  Volcano  Trench  Crater
--   WalkSpeed conseillé  16     26     36     43      49       56       63      70
--   gardien (x0.75)   10*    19.5   27     32      37       42       47      52.5     (* Beach : lent, tutoriel)
--
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

	SpeedFactor = 0.75, -- course = 0.75 x WalkSpeed conseillé de la zone (sans Speed)
	ReturnFactor = 0.5, -- marche du retour au gisement = 0.5 x course (au moins MinReturnSpeed)
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
	Leash = 40, -- studs au-delà de la zone (sa pièce Area) où il poursuit encore ; jamais dans un parc
	CatchRange = 4, -- studs (horizontal) entre le pivot du gardien et le joueur pour l'attraper...
	CatchReach = 0.35, -- ... + 0.35 x sa taille (taille de base de l'espèce x Scale) : la tête est devant le pivot
	DefaultSize = 6, -- taille de base (studs) d'une espèce sans fiche Config.Species
	KnockTime = 2, -- secondes au sol pour le joueur attrapé

	TickRate = 0.1, -- secondes entre deux déplacements serveur (le client lisse et anime : pas de PivotTo à 60 Hz)
}

export type Guardians = typeof(Guardians)

return Guardians
