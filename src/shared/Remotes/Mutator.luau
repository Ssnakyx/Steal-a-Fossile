--!strict
-- Remotes du sérum de mutation (Config.Mutator, MutatorService).

return {
	Functions = {
		MutateDino = "client -> serveur : utiliser un sérum sur un de ses dinos (id) -> (ok, texte, résultat { Success, Id, Species, Size, Mutation, Before, Level, Income, Rarity, Key })",
		BuySerums = "client -> serveur : acheter des sérums avec l'argent du jeu (nombre) -> (ok, texte)",
	},
}
