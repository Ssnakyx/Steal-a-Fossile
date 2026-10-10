--!strict
-- Remotes du brief 4 « vitesse-treadmill » : shop Robux (treadmill, passes, produits), trails, récompense de groupe.
-- L'état du joueur (Speed, TreadmillLevel, TreadmillRate, Trails, Passes, GroupRewardClaimed) arrive par le Replica.

return {
	Functions = {
		GetShop = "client -> serveur : contenu du shop (treadmill et niveau suivant, passes, produits, prix lus sur Roblox) -> table",
		BuyTreadmill = "client -> serveur : acheter le niveau suivant du treadmill (ouvre l'achat Robux) -> (ok, texte)",
		BuyPass = "client -> serveur : acheter un passe (clé de Config.Shop.Passes) -> (ok, texte)",
		BuyProduct = "client -> serveur : acheter un produit Robux (clé de Config.Shop.Products) -> (ok, texte)",
		BuyTrail = "client -> serveur : acheter une trail avec l'argent du jeu (clé de Config.Speed.Trails) -> (ok, texte)",
		EquipTrail = "client -> serveur : porter une trail possédée (clé, ou \"\" pour aucune) -> (ok, texte)",
		ClaimGroupReward = "client -> serveur : récompense like + favori + groupe (groupe vérifié par le serveur) -> (ok, texte)",
	},
}
