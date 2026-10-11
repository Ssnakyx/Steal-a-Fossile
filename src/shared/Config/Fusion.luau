--!strict
-- Fusion (brief 8, GDD section Fusion) : règles publiques du labo de fusion du parc. Les recettes d'hybrides sont
-- secrètes, côté serveur (src/server/ServerConfig/Fusion.luau) : rien ici ne doit les trahir. Valeurs de départ à équilibrer.
--   Upgrade : 3 dinos identiques (même espèce, même niveau) -> 1 dino du niveau suivant (Normal, Golden, Diamond : revenus
--             dans Config.Economy.Levels), avec la meilleure taille et la meilleure mutation des trois.
--   Hybride : 2 dinos d'espèces différentes -> la chimère de la recette, avec la meilleure taille et la meilleure mutation
--             des deux, au plus petit de leurs deux niveaux. Recette inconnue : « Unknown recipe », les dinos restent et
--             rien n'est payé (on ne perd rien à tester).

return {
	UpgradeCount = 3, -- dinos identiques pour monter d'un niveau
	HybridCount = 2, -- dinos d'espèces différentes pour tenter un hybride
	HybridIncome = 1.5, -- revenu de base d'un hybride = (base de A + base de B) x 1,5
	-- Prix d'une fusion réussie : secondes de revenu des dinos utilisés (sans les multiplicateurs du joueur), au moins MinCost
	CostSeconds = {
		Upgrade = 60,
		Hybrid = 120,
	} :: { [string]: number },
	MinCost = 50,
	ResultState = "Roar", -- animation du dino qui sort du labo (GDD : « l'hybride apparaît et rugit »)
	UnknownName = "???", -- nom montré pour un hybride pas encore découvert (aperçu du labo, Index)
}
