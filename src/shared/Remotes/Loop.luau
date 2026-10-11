--!strict
-- Remotes de la boucle (brief 3 « boucle »). Arracher un bloc passe par le ProximityPrompt du bloc (vérifié côté
-- serveur), pas par un remote.

return {
	Events = {
		DinoRevealed = "serveur -> client : dino révélé dans une cuve (dinoId, { Species, Size, Mutation, Level, Rarity, Income })",
		LoopAnnounce = "serveur -> client : annonce à afficher dans le chat (texte), par exemple un bloc Secret",
		FossilAlert = "serveur -> client : bloc rare apparu dans un gisement (rareté, nom de la zone, nombre), bandeau pour tout le serveur",
	},
	Functions = {
		RevealTank = "client -> serveur : révéler le dino d'une cuve prête (slot) -> (ok, texte)",
		BuyTank = "client -> serveur : acheter la cuve suivante -> (ok, texte)",
		BuyEnclosure = "client -> serveur : agrandir l'enclos -> (ok, texte)",
	},
}
