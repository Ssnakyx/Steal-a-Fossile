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
	-- 50 niveaux, chacun avec son modèle de tapis (src/server/Map/Treadmills.luau : 10 thèmes de 5 crans). L'argent est
	-- multiplié par ~1,45 à chaque niveau, le gain monte un peu moins vite pour que le suivant reste toujours
	-- intéressant. Robux plafonné à 2499 (un produit trop cher ne se vend pas). Valeurs de départ, à régler en jeu.
	Treadmill = {
		Name = "Treadmill",
		Levels = {
			{ Cash = 1_000, Id = 0, Price = 25, Multiplier = 1 }, -- 1
			{ Cash = 1_500, Id = 0, Price = 39, Multiplier = 1.5 }, -- 2
			{ Cash = 2_100, Id = 0, Price = 59, Multiplier = 2 }, -- 3
			{ Cash = 3_200, Id = 0, Price = 89, Multiplier = 3 }, -- 4
			{ Cash = 4_400, Id = 0, Price = 129, Multiplier = 4 }, -- 5
			{ Cash = 6_600, Id = 0, Price = 179, Multiplier = 6 }, -- 6
			{ Cash = 9_300, Id = 0, Price = 249, Multiplier = 8 }, -- 7
			{ Cash = 13_000, Id = 0, Price = 349, Multiplier = 11 }, -- 8
			{ Cash = 20_000, Id = 0, Price = 499, Multiplier = 15 }, -- 9
			{ Cash = 28_000, Id = 0, Price = 699, Multiplier = 20 }, -- 10
			{ Cash = 41_000, Id = 0, Price = 739, Multiplier = 22 }, -- 11
			{ Cash = 60_000, Id = 0, Price = 789, Multiplier = 24 }, -- 12
			{ Cash = 86_000, Id = 0, Price = 829, Multiplier = 27 }, -- 13
			{ Cash = 130_000, Id = 0, Price = 879, Multiplier = 30 }, -- 14
			{ Cash = 180_000, Id = 0, Price = 939, Multiplier = 33 }, -- 15
			{ Cash = 260_000, Id = 0, Price = 989, Multiplier = 36 }, -- 16
			{ Cash = 380_000, Id = 0, Price = 1099, Multiplier = 40 }, -- 17
			{ Cash = 550_000, Id = 0, Price = 1099, Multiplier = 44 }, -- 18
			{ Cash = 800_000, Id = 0, Price = 1199, Multiplier = 49 }, -- 19
			{ Cash = 1_200_000, Id = 0, Price = 1299, Multiplier = 54 }, -- 20
			{ Cash = 1_700_000, Id = 0, Price = 1299, Multiplier = 60 }, -- 21
			{ Cash = 2_400_000, Id = 0, Price = 1399, Multiplier = 66 }, -- 22
			{ Cash = 3_500_000, Id = 0, Price = 1499, Multiplier = 73 }, -- 23
			{ Cash = 5_100_000, Id = 0, Price = 1599, Multiplier = 81 }, -- 24
			{ Cash = 7_500_000, Id = 0, Price = 1699, Multiplier = 89 }, -- 25
			{ Cash = 11_000_000, Id = 0, Price = 1799, Multiplier = 99 }, -- 26
			{ Cash = 16_000_000, Id = 0, Price = 1899, Multiplier = 110 }, -- 27
			{ Cash = 23_000_000, Id = 0, Price = 1999, Multiplier = 120 }, -- 28
			{ Cash = 33_000_000, Id = 0, Price = 2099, Multiplier = 130 }, -- 29
			{ Cash = 48_000_000, Id = 0, Price = 2199, Multiplier = 150 }, -- 30
			{ Cash = 69_000_000, Id = 0, Price = 2399, Multiplier = 160 }, -- 31
			{ Cash = 100_000_000, Id = 0, Price = 2499, Multiplier = 180 }, -- 32
			{ Cash = 150_000_000, Id = 0, Price = 2499, Multiplier = 200 }, -- 33
			{ Cash = 210_000_000, Id = 0, Price = 2499, Multiplier = 220 }, -- 34
			{ Cash = 310_000_000, Id = 0, Price = 2499, Multiplier = 240 }, -- 35
			{ Cash = 440_000_000, Id = 0, Price = 2499, Multiplier = 270 }, -- 36
			{ Cash = 640_000_000, Id = 0, Price = 2499, Multiplier = 300 }, -- 37
			{ Cash = 930_000_000, Id = 0, Price = 2499, Multiplier = 330 }, -- 38
			{ Cash = 1_400_000_000, Id = 0, Price = 2499, Multiplier = 360 }, -- 39
			{ Cash = 2_000_000_000, Id = 0, Price = 2499, Multiplier = 400 }, -- 40
			{ Cash = 2_800_000_000, Id = 0, Price = 2499, Multiplier = 440 }, -- 41
			{ Cash = 4_100_000_000, Id = 0, Price = 2499, Multiplier = 490 }, -- 42
			{ Cash = 6_000_000_000, Id = 0, Price = 2499, Multiplier = 540 }, -- 43
			{ Cash = 8_700_000_000, Id = 0, Price = 2499, Multiplier = 600 }, -- 44
			{ Cash = 13_000_000_000, Id = 0, Price = 2499, Multiplier = 660 }, -- 45
			{ Cash = 18_000_000_000, Id = 0, Price = 2499, Multiplier = 730 }, -- 46
			{ Cash = 26_000_000_000, Id = 0, Price = 2499, Multiplier = 800 }, -- 47
			{ Cash = 38_000_000_000, Id = 0, Price = 2499, Multiplier = 890 }, -- 48
			{ Cash = 56_000_000_000, Id = 0, Price = 2499, Multiplier = 980 }, -- 49
			{ Cash = 81_000_000_000, Id = 0, Price = 2499, Multiplier = 1100 }, -- 50
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
