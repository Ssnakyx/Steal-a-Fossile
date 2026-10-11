--!strict
-- Le parc du joueur : promenade des dinos dans l'enclos (EnclosureService au serveur, src/shared/Roam.luau pour le
-- calcul de la pose, DinoAnimController chez le client). Valeurs de départ à équilibrer.
--
-- Chaque dino se promène seul : une pause (Idle, parfois Eat ou Happy), puis il tourne sur place vers un point libre de
-- l'enclos et y marche à la vitesse naturelle de son animation de marche (pas de glisse), puis une nouvelle pause. Les
-- points d'arrivée restent loin du bord et des autres dinos. Un trajet = quelques attributs posés une fois sur le
-- modèle (WalkFrom, WalkTo, Speed, State = "Walk", StateAt) : chaque client calcule la pose en cours, le serveur ne
-- déplace la pièce Root qu'à l'arrivée.

local Park = {
	Roam = {
		Enabled = true,
		TickRate = 0.25, -- secondes entre deux passages du serveur (décisions seulement : rien ne bouge au serveur)
		TurnTime = 0.6, -- secondes pour tourner sur place vers le point d'arrivée, avant de marcher
		RestMin = 3, -- pause entre deux trajets (secondes, au hasard entre RestMin et RestMax)
		RestMax = 9,
		WalkChance = 0.8, -- à la fin d'une pause : chance de partir (sinon une pause de plus)
		MinLeg = 8, -- longueur d'un trajet (studs)
		MaxLeg = 32,
		MinSpeed = 1.5, -- vitesse de marche (studs/s) = vitesse naturelle de l'animation Walk x taille, bornée ici
		MaxSpeed = 10,
		DefaultSpeed = 4, -- espèce sans vitesse de marche connue
		-- Place d'un dino : un disque de rayon Footprint x sa taille (Config.Species.BaseSize x taille Small...Huge, sa
		-- plus grande dimension) ; queues et ailes peuvent se croiser, les corps non
		Footprint = 0.3,
		Margin = 2, -- studs entre le bord de l'enclos et ce disque
		Gap = 2, -- studs entre les disques de deux dinos à l'arrêt (et de deux points d'arrivée) ; enclos très plein :
		-- un dino qui apparaît prend la place la plus dégagée, un dino sans place libre reste en pause
		Tries = 16, -- points tirés au hasard pour trouver une place libre
		-- À l'arrivée, chance de jouer cette animation plutôt qu'Idle (un état absent du modèle retombe sur Idle)
		Moods = { Eat = 0.12, Happy = 0.06 } :: { [string]: number },
		SpawnRest = 4, -- secondes sans bouger après l'apparition (Spawn, Fusion) : on voit le dino arriver
	},
}

export type Park = typeof(Park)

return Park
