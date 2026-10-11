--!strict
-- Remotes du brief 4 « vitesse-treadmill » : shop Robux (treadmill, passes, produits), trails, récompense de groupe.
-- L'état du joueur (Speed, TreadmillLevel, TreadmillRate, Trails, Passes, GroupRewardClaimed, GiftCredits) arrive par le
-- Replica. Offres (packs, argent, cadeaux) : OfferService, section « Offers » de GetShop.

return {
	Functions = {
		GetShop = "client -> serveur : contenu du shop (treadmill et niveau suivant, passes, produits, prix lus sur Roblox) -> table",
		BuyTreadmill = "client -> serveur : acheter le niveau suivant du treadmill (\"Cash\" ou rien : argent du jeu ; \"Robux\" : ouvre l'achat Robux) -> (ok, texte)",
		BuyPass = "client -> serveur : acheter un passe (clé de Config.Shop.Passes) -> (ok, texte)",
		BuyProduct = "client -> serveur : acheter un produit Robux (clé de Config.Shop.Products) -> (ok, texte)",
		BuyTrail = "client -> serveur : acheter une trail avec l'argent du jeu (clé de Config.Speed.Trails) -> (ok, texte)",
		EquipTrail = "client -> serveur : porter une trail possédée (clé, ou \"\" pour aucune) -> (ok, texte)",
		BuyOffer = "client -> serveur : acheter un pack d'argent (clé de Config.Shop.Cash) ou un pack proposé (clé de Config.Shop.Packs) -> (ok, texte)",
		GiftPass = "client -> serveur : offrir un passe (clé de Config.Shop.Gifts) à un joueur du serveur (UserId) : cadeau déjà payé envoyé tout de suite, sinon achat proposé -> (ok, texte)",
		ClaimGroupReward = "client -> serveur : récompense like + favori + groupe (groupe vérifié par le serveur) -> (ok, texte)",
	},
}
