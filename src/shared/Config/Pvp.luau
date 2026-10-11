--!strict
-- Vol sur la route (brief 7 « gardiens-vol », GDD section Vol). Valeurs de départ à équilibrer.
-- Uniquement sur la route : rien n'est volable dans un parc, personne n'y est bonké ni piégé.
--   * Pelle (Shovel), outil de départ : un coup (bonk) fait lâcher son bloc au porteur. Recharge 2 s, portée vérifiée.
--   * Bear Trap : posé au sol, immobilise 3 s celui qui marche dessus (joueur ou gardien) et lui fait lâcher son bloc.
--     Acheté avec l'argent du jeu, ou par 5 avec le produit Robux « BearTraps5 » (Config.Shop.Products).
--   * Bloc au sol : ramassable par tous, sauf par celui qui l'a lâché pendant 3 s ; retourne à son gisement en 30 s.
--   * Protection débutant : impossible d'être bonké ou piégé pendant les 10 premières minutes de jeu.

local Pvp = {
	Shovel = {
		ToolName = "Shovel",
		Cooldown = 2, -- secondes entre deux coups
		Range = 8, -- portée (studs) entre les deux personnages
		RangeTolerance = 4, -- studs de plus permis par le serveur (latence)
		KnockTime = 1.5, -- secondes au sol pour le joueur bonké
	},

	Trap = {
		ToolName = "Bear Trap",
		Price = 5_000, -- prix d'un piège en argent du jeu
		MaxBuy = 10, -- pièges achetés au plus en une fois
		MaxOwned = 999, -- pièges gardés au plus
		PerProduct = 5, -- pièges donnés par le produit Robux BearTraps5
		HoldTime = 3, -- secondes d'immobilisation (joueur ou gardien)
		Radius = 3, -- studs (horizontal) autour du piège où l'on marche dessus
		MaxActive = 3, -- pièges posés en même temps par joueur (le plus ancien disparaît)
		Lifetime = 120, -- secondes avant qu'un piège posé et pas déclenché disparaisse
		PlaceCooldown = 1, -- secondes entre deux pièges posés
		MinSpacing = 4, -- studs au moins entre deux pièges
	},

	Dropped = {
		LockTime = 3, -- secondes pendant lesquelles celui qui l'a lâché ne peut pas le reprendre
		ReturnTime = 30, -- secondes au sol avant de retourner à son gisement
		PickupDistance = 10, -- portée du ProximityPrompt « Pick up » (studs) ; le serveur tolère un peu plus
	},

	Protection = {
		Time = 600, -- secondes de jeu (au total) pendant lesquelles un nouveau joueur ne peut être ni bonké ni piégé
	},
}

export type Pvp = typeof(Pvp)

return Pvp
