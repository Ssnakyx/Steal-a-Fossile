--!strict
-- Achats Robux (brief 4 « vitesse-treadmill ») : treadmill et ses niveaux, passes, produits (GDD : Monétisation).
-- Le treadmill s'achète aussi avec l'argent du jeu (Treadmill.Levels[n].Cash).
-- Id = 0 tant que Snaky n'a pas créé l'objet dans le Creator Hub : il reste caché en jeu et ne s'achète pas.
-- Price = prix à mettre dans le Creator Hub (celui du GDD pour le treadmill, conseillé pour le reste). Le prix affiché
-- en jeu est toujours celui que Roblox renvoie (GetProductInfoAsync), jamais celui-ci.
-- Jamais de dino ni de bloc vendu en Robux. Toute chance payante affiche ses probas (UI, brief 12).

export type Level = { Cash: number, Id: number, Price: number, Multiplier: number }
export type Pass = { Id: number, Name: string, Description: string, Price: number, Order: number, Multiplier: number?, LuckBonus: number?, Trail: string? }
export type Product = { Id: number, Name: string, Description: string, Price: number, Order: number, Owner: string }

local Shop = {
	-- Treadmill : niveau 1 = le déblocage, puis un niveau à la fois. Chaque niveau s'achète avec l'argent du jeu
	-- (Cash, en $ : déblocage à $1K comme dans Steal an Egg, puis le prix monte avec les revenus des zones), ou en
	-- Robux pour aller plus vite (un produit développeur par niveau : un produit a un prix fixe sur Roblox ; caché
	-- tant que son Id = 0). Le serveur ne propose que le niveau suivant du joueur. Clé du produit : "TreadmillLevel<niveau>".
	-- Multiplier = vitesse gagnée par seconde, en multiple de Config.Speed.Treadmill.BaseGain.
	Treadmill = {
		Name = "Treadmill",
		Levels = {
			{ Cash = 1_000, Id = 0, Price = 25, Multiplier = 1 },
			{ Cash = 15_000, Id = 0, Price = 39, Multiplier = 1.5 },
			{ Cash = 75_000, Id = 0, Price = 59, Multiplier = 2 },
			{ Cash = 350_000, Id = 0, Price = 89, Multiplier = 3 },
			{ Cash = 1_500_000, Id = 0, Price = 129, Multiplier = 4 },
			{ Cash = 7_500_000, Id = 0, Price = 179, Multiplier = 6 },
			{ Cash = 40_000_000, Id = 0, Price = 249, Multiplier = 8 },
			{ Cash = 200_000_000, Id = 0, Price = 349, Multiplier = 11 },
			{ Cash = 1_000_000_000, Id = 0, Price = 499, Multiplier = 15 },
			{ Cash = 5_000_000_000, Id = 0, Price = 699, Multiplier = 20 },
		} :: { Level },
		-- secondes pendant lesquelles un achat de niveau en cours bloque un nouvel achat (évite d'acheter deux fois
		-- le même niveau en cliquant vite)
		PendingSeconds = 60,
	},

	-- Passes (game passes). Lire avec ShopService.HasPass(player, clé). Multiplier : effet du passe pour le service
	-- qui l'applique (IncomeService pour DoubleMoney, ReviveService pour FastRevive, TreadmillService pour
	-- DoubleTreadmill, TrailService pour les trails Robux : vitesse multipliée tant que la trail est portée).
	-- LuckBonus : chance en plus du VIP (mutations à la révélation, brief 3). Trail : la trail Robux que donne le
	-- passe (Config.Speed.RobuxTrails, avec ses couleurs).
	Passes = {
		DoubleMoney = { Id = 0, Name = "x2 Money", Description = "Earn double money from all your dinos.", Price = 299, Order = 1, Multiplier = 2 },
		DoubleTreadmill = { Id = 0, Name = "x2 Treadmill", Description = "Gain double speed on your treadmill.", Price = 199, Order = 2, Multiplier = 2 },
		FastRevive = { Id = 0, Name = "Fast Revive", Description = "Your revival tanks work twice as fast.", Price = 249, Order = 3, Multiplier = 2 },
		VIP = { Id = 0, Name = "VIP", Description = "VIP tag and a little extra luck.", Price = 149, Order = 4, LuckBonus = 1.1 },
		NeonTrail = { Id = 0, Name = "Neon Trail", Description = "A glowing neon trail. x1.5 Speed while you wear it, on top of your best trail.", Price = 99, Order = 5, Multiplier = 1.5, Trail = "Neon" },
		GalaxyTrail = { Id = 0, Name = "Galaxy Trail", Description = "A trail full of stars. x2 Speed while you wear it, on top of your best trail.", Price = 249, Order = 6, Multiplier = 2, Trail = "Galaxy" },
		GoldenTrail = { Id = 0, Name = "Golden Trail", Description = "A shining gold trail. x3 Speed while you wear it, on top of your best trail.", Price = 499, Order = 7, Multiplier = 3, Trail = "Golden" },
	} :: { [string]: Pass },

	-- Produits développeur (achats répétables). Owner = le service qui donne l'effet : c'est lui qui appelle
	-- ReceiptService.Register(clé, Config.Shop.Products[clé].Id, grant). Un produit sans Register reste caché.
	Products = {
		BearTraps5 = { Id = 0, Name = "Bear Traps x5", Description = "5 bear traps to stop thieves on the road.", Price = 49, Order = 1, Owner = "PvpService" },
		ServerLuck = { Id = 0, Name = "Server Luck x2", Description = "Double luck for everyone in the server for 15 minutes.", Price = 99, Order = 2, Owner = "ShopService" },
		InstantRevive = { Id = 0, Name = "Instant Revive", Description = "Finish your revivals right now.", Price = 29, Order = 3, Owner = "ReviveService" },
	} :: { [string]: Product },

	-- Server Luck x2 : toute la chance du serveur est multipliée pendant Duration secondes. Un nouvel achat pendant
	-- qu'elle tourne ajoute Duration au temps restant.
	ServerLuck = {
		Multiplier = 2,
		Duration = 15 * 60,
	},

	PriceCacheSeconds = 600, -- les prix lus sur Roblox sont gardés 10 min
}

export type Shop = typeof(Shop)

return Shop
