--!strict
-- Réglages communs (brief 1 « fondations ») : administrateurs, sauvegarde, argent, achats Robux.
-- Les autres domaines ont chacun leur fichier dans ce dossier.

local Core = {
	-- Comptes Roblox administrateurs (UserId). Le propriétaire du jeu publié (compte ou groupe) l'est toujours.
	Admins = {
		3346721423, -- Ssnakyyx (Snaky)
	} :: { number },

	Admin = {
		StudioEveryone = true, -- dans Studio, tous les joueurs de test sont administrateurs (jamais en jeu publié)
		MaxMoney = 1e15, -- montant maximal d'une commande « money »
	},

	-- Argent
	StartingMoney = 0,
	MaxMoney = 1e300, -- plafond de data.Money (au-delà, les nombres deviennent infinis)

	-- Sauvegarde (DataService)
	Data = {
		StoreName = "SAF_Players_1", -- changer le nom remet tout le monde à zéro (l'ancienne sauvegarde reste dans l'ancien nom)
		AutosaveInterval = 60, -- secondes
		LoadAttempts = 24, -- essais de chargement (verrou d'un autre serveur, panne passagère)
		SaveInStudio = false, -- Studio lit la vraie sauvegarde mais ne l'écrit jamais (les tests modifient les données)
	},

	-- Achats Robux (ReceiptService)
	Purchases = {
		Remember = 100, -- identifiants d'achat (PurchaseId) gardés dans la sauvegarde pour ne jamais donner deux fois
	},
}

export type Core = typeof(Core)

return Core
