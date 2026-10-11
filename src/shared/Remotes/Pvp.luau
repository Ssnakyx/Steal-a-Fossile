--!strict
-- Remotes des gardiens et du vol (brief 7 « gardiens-vol »). Ramasser un bloc au sol passe par le ProximityPrompt du
-- bloc (vérifié côté serveur), pas par un remote.

return {
	Events = {
		Bonk = "client -> serveur : coup de pelle (joueur visé, facultatif : sinon le porteur le plus proche à portée)",
		PlaceTrap = "client -> serveur : poser un Bear Trap à ses pieds",
		Knocked = "serveur -> client : ton personnage est au sol ou bloqué (secondes, raison : Bonk | Catch | Trap)",
		GuardianAlert = "serveur -> client : un gardien te poursuit (zone, état : Roar | Run | Lost | Catch, raison de Lost : Safe | Escaped | Dropped)",
		PvpEffect = "serveur -> client : effet à jouer chez tous (genre : Bonk | Catch | Trap | Drop, position Vector3)",
	},
	Functions = {
		BuyTraps = "client -> serveur : acheter des Bear Traps avec l'argent du jeu (nombre) -> (ok, texte)",
	},
}
