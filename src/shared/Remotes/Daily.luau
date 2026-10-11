--!strict
-- Remotes des récompenses (calendrier, roue, cadeaux) et de l'AFK sur le treadmill. L'état arrive par le Replica :
-- « Daily », « Spins », « Gifts », « RewardScale » (voir docs/RECOMPENSES.md).

return {
	Events = {
		AfkRejoin = "client -> serveur : le joueur est inactif sur son treadmill depuis longtemps, le reconnecter au même serveur avant que Roblox ne l'expulse (aucun argument)",
		RewardGranted = "serveur -> client : récompense donnée (source, texte, rareté du bloc ou nil) pour l'afficher",
	},
	Functions = {
		ClaimDaily = "client -> serveur : prendre la récompense du jour du calendrier -> (ok, texte, jour)",
		Spin = "client -> serveur : faire tourner la roue (tour gratuit d'abord) -> (ok, texte, numéro de la case gagnée)",
		ClaimGift = "client -> serveur : ouvrir un cadeau de temps de jeu (numéro dans Config.Daily.Gifts) -> (ok, texte)",
		GetSpinOffers = "client -> serveur : tours à acheter en Robux (vide si interdit pour ce joueur) -> { { Key, Name, Count, Price } }",
		BuySpins = "client -> serveur : acheter des tours (clé de Config.Daily.Spins.Products) -> (ok, texte)",
	},
}
