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
-- Contenu d'un pack ou d'un pack d'argent. Money, Speed, BearTraps : même format que les récompenses de Config.Daily
-- (Amount = minimum, IncomeMinutes = minutes du revenu actuel, SpeedPercent = % de la vitesse gagnée). Revives :
-- Instant Revive (Amount). Pass : un passe donné pour de bon (Key). ServerLuck : Server Luck x2 pour tout le serveur
-- (Minutes). Jamais de dino, de bloc ni de tour de roue (achat au hasard) dans un pack.
export type Item = {
	Kind: string, -- "Money" | "Speed" | "BearTraps" | "Revives" | "Pass" | "ServerLuck"
	Amount: number?,
	IncomeMinutes: number?,
	SpeedPercent: number?,
	Key: string?,
	Minutes: number?,
}
export type CashPack = { Id: number, Name: string, Price: number, Order: number, Icon: string, Reward: Item }
export type Pack = {
	Id: number,
	Name: string,
	Kind: string, -- "Starter" | "Limited" | "Deal"
	Price: number, -- prix à mettre dans le Creator Hub
	Worth: number, -- valeur du contenu en Robux (prix barré, « -75% »)
	Order: number,
	Icon: string,
	Items: { Item },
}
export type Gift = { Id: number, Price: number }

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
		DoubleMoney = { Id = 2026551002, Name = "x2 Money", Description = "Earn double money from all your dinos.", Price = 299, Order = 1, Multiplier = 2 },
		DoubleTreadmill = { Id = 2025152896, Name = "x2 Treadmill", Description = "Gain double speed on your treadmill.", Price = 199, Order = 2, Multiplier = 2 },
		FastRevive = { Id = 2026814954, Name = "Fast Revive", Description = "Your revival tanks work twice as fast.", Price = 249, Order = 3, Multiplier = 2 },
		VIP = { Id = 2026520956, Name = "VIP", Description = "VIP tag and a little extra luck.", Price = 149, Order = 4, LuckBonus = 1.1 },
		NeonTrail = { Id = 2026094921, Name = "Neon Trail", Description = "A glowing neon trail. x1.5 Speed while you wear it, on top of your best trail.", Price = 99, Order = 5, Multiplier = 1.5, Trail = "Neon" },
		GalaxyTrail = { Id = 2025920982, Name = "Galaxy Trail", Description = "A trail full of stars. x2 Speed while you wear it, on top of your best trail.", Price = 249, Order = 6, Multiplier = 2, Trail = "Galaxy" },
		GoldenTrail = { Id = 2026028944, Name = "Golden Trail", Description = "A shining gold trail. x3 Speed while you wear it, on top of your best trail.", Price = 499, Order = 7, Multiplier = 3, Trail = "Golden" },
	} :: { [string]: Pass },

	-- Produits développeur (achats répétables). Owner = le service qui donne l'effet : c'est lui qui appelle
	-- ReceiptService.Register(clé, Config.Shop.Products[clé].Id, grant). Un produit sans Register reste caché.
	Products = {
		BearTraps5 = { Id = 3717982859, Name = "Bear Traps x5", Description = "5 bear traps to stop thieves on the road.", Price = 49, Order = 1, Owner = "PvpService" },
		ServerLuck = { Id = 3717983391, Name = "Server Luck x2", Description = "Double luck for everyone in the server for 15 minutes.", Price = 99, Order = 2, Owner = "ShopService" },
		InstantRevive = { Id = 3717983480, Name = "Instant Revive", Description = "Finish your revivals right now.", Price = 29, Order = 3, Owner = "ReviveService" },
		-- sérums de mutation (Config.Mutator) : 3 par achat
		MutationSerums3 = { Id = 3717983549, Name = "Mutation Serums x3", Description = "3 serums to mutate your dinos in the lab.", Price = 99, Order = 4, Owner = "MutatorService" },
	} :: { [string]: Product },

	-- Server Luck x2 : toute la chance du serveur est multipliée pendant Duration secondes. Un nouvel achat pendant
	-- qu'elle tourne ajoute Duration au temps restant.
	ServerLuck = {
		Multiplier = 2,
		Duration = 15 * 60,
	},

	PriceCacheSeconds = 600, -- les prix lus sur Roblox sont gardés 10 min

	-- ===== Offres (OfferService, demande de Snaky du 2026-10-11 : shop beaucoup plus complet) =====
	-- Comme le reste : Id = 0 tant que le produit n'est pas créé dans le Creator Hub (caché en jeu, gris « Id = 0 »
	-- dans Studio). Price = prix à mettre dans le Creator Hub. Valeurs de départ, à régler en jeu.

	-- MONEY : argent du jeu contre Robux. Montant = IncomeMinutes minutes du revenu actuel du joueur, au moins Amount
	-- (le pack reste utile à tout moment du jeu). Les gros packs donnent plus par Robux : le shop affiche « +N% MORE »
	-- par rapport au plus petit et « BEST VALUE » sur le meilleur.
	Cash = {
		CashSmall = { Id = 3717983783, Name = "Pile of Cash", Price = 49, Order = 1, Icon = "coin", Reward = { Kind = "Money", IncomeMinutes = 10, Amount = 5_000 } },
		CashMedium = { Id = 3717983845, Name = "Bag of Cash", Price = 149, Order = 2, Icon = "coins", Reward = { Kind = "Money", IncomeMinutes = 40, Amount = 20_000 } },
		CashLarge = { Id = 3717983927, Name = "Chest of Cash", Price = 399, Order = 3, Icon = "chest", Reward = { Kind = "Money", IncomeMinutes = 150, Amount = 80_000 } },
		CashHuge = { Id = 3717984004, Name = "Vault of Cash", Price = 999, Order = 4, Icon = "crate", Reward = { Kind = "Money", IncomeMinutes = 480, Amount = 300_000 } },
	} :: { [string]: CashPack },

	-- Packs : un produit développeur par pack, contenu en plusieurs morceaux, prix barré (Worth) et réduction.
	--   Starter : proposé StarterHours heures après la première connexion, une seule fois par joueur.
	--   Limited : un seul à la fois pour tout le monde, il change tous les LimitedDays jours (ordre de Rotation.Limited).
	--   Deal    : l'offre du jour, une par jour (00:00 UTC, ordre de Rotation.Deals), achetable plusieurs fois.
	-- Un pack qui contient un passe déjà possédé n'est pas proposé à ce joueur.
	Packs = {
		Starter = {
			Id = 3717984091, Name = "Starter Pack", Kind = "Starter", Price = 99, Worth = 399, Order = 1, Icon = "gift",
			Items = {
				{ Kind = "Pass", Key = "NeonTrail" },
				{ Kind = "Money", IncomeMinutes = 30, Amount = 15_000 },
				{ Kind = "BearTraps", Amount = 10 },
				{ Kind = "Revives", Amount = 3 },
			},
		},
		SpeedRush = {
			Id = 3717984182, Name = "Speed Rush Pack", Kind = "Limited", Price = 299, Worth = 699, Order = 2, Icon = "speed",
			Items = {
				{ Kind = "Pass", Key = "DoubleTreadmill" },
				{ Kind = "Speed", SpeedPercent = 25, Amount = 5_000 },
				{ Kind = "Money", IncomeMinutes = 60, Amount = 30_000 },
			},
		},
		FossilHunter = {
			Id = 3717984283, Name = "Fossil Hunter Pack", Kind = "Limited", Price = 399, Worth = 899, Order = 3, Icon = "hammer",
			Items = {
				{ Kind = "Pass", Key = "FastRevive" },
				{ Kind = "Revives", Amount = 5 },
				{ Kind = "BearTraps", Amount = 15 },
				{ Kind = "Money", IncomeMinutes = 90, Amount = 50_000 },
			},
		},
		DinoTycoon = {
			Id = 3717984403, Name = "Dino Tycoon Pack", Kind = "Limited", Price = 699, Worth = 1_499, Order = 4, Icon = "crown",
			Items = {
				{ Kind = "Pass", Key = "DoubleMoney" },
				{ Kind = "Pass", Key = "VIP" },
				{ Kind = "Money", IncomeMinutes = 240, Amount = 150_000 },
				{ Kind = "Revives", Amount = 5 },
			},
		},
		CashDeal = {
			Id = 3717984487, Name = "Mega Cash Deal", Kind = "Deal", Price = 249, Worth = 499, Order = 5, Icon = "coins",
			Items = { { Kind = "Money", IncomeMinutes = 240, Amount = 150_000 } },
		},
		TrapCrate = {
			Id = 3717984615, Name = "Trap Crate", Kind = "Deal", Price = 79, Worth = 196, Order = 6, Icon = "shield",
			Items = { { Kind = "BearTraps", Amount = 20 } },
		},
		ReviveBundle = {
			Id = 3717984686, Name = "Revive Bundle", Kind = "Deal", Price = 99, Worth = 203, Order = 7, Icon = "egg_gold",
			Items = { { Kind = "Revives", Amount = 7 } },
		},
		LuckParty = {
			Id = 3717984760, Name = "Luck Party", Kind = "Deal", Price = 149, Worth = 297, Order = 8, Icon = "star",
			Items = { { Kind = "ServerLuck", Minutes = 45 } },
		},
		SpeedBoost = {
			Id = 3717984852, Name = "Speed Boost", Kind = "Deal", Price = 99, Worth = 199, Order = 9, Icon = "muscle",
			Items = { { Kind = "Speed", SpeedPercent = 15, Amount = 3_000 } },
		},
	} :: { [string]: Pack },

	StarterHours = 72, -- le Starter Pack reste proposé 3 jours après la première connexion
	Rotation = {
		LimitedDays = 3,
		Limited = { "SpeedRush", "FossilHunter", "DinoTycoon" },
		Deals = { "CashDeal", "TrapCrate", "ReviveBundle", "LuckParty", "SpeedBoost" },
	},
	-- Contenu donné à la place d'un passe déjà possédé au moment du reçu (rare : le pack n'est pas proposé dans ce cas)
	PassRefund = { Kind = "Money", IncomeMinutes = 60, Amount = 20_000 } :: Item,

	-- Cadeaux : offrir un passe à un autre joueur du serveur. Roblox ne permet pas d'acheter un game pass pour quelqu'un
	-- d'autre : chaque passe offrable a son produit développeur « cadeau » (même prix que le passe). Le passe offert est
	-- gardé dans la sauvegarde du joueur qui le reçoit (data.Offers.Granted, jamais retiré). Si le joueur choisi est parti
	-- ou a déjà le passe quand Roblox confirme l'achat, le cadeau est gardé (« gift ready ») et s'envoie plus tard.
	Gifts = {
		DoubleMoney = { Id = 3717984927, Price = 299 },
		DoubleTreadmill = { Id = 3717985072, Price = 199 },
		FastRevive = { Id = 3717985180, Price = 249 },
		VIP = { Id = 3717985270, Price = 149 },
		NeonTrail = { Id = 3717985343, Price = 99 },
		GalaxyTrail = { Id = 3717985433, Price = 249 },
		GoldenTrail = { Id = 3717985505, Price = 499 },
	} :: { [string]: Gift },
	GiftHoldSeconds = 180, -- temps pendant lequel le joueur choisi reste réservé, fenêtre d'achat de Roblox ouverte
}

-- Offres du moment, Shop.Current(os.time()) (même calcul chez le serveur et le client) : Limited et Deal en cours, et leur heure de fin (os.time())
function Shop.Current(now: number): { Limited: string, LimitedEnds: number, Deal: string, DealEnds: number }
	local rotation = Shop.Rotation
	local period = rotation.LimitedDays * 86400
	local slot = math.floor(now) // period
	local day = math.floor(now) // 86400
	return {
		Limited = rotation.Limited[slot % #rotation.Limited + 1] or "",
		LimitedEnds = (slot + 1) * period,
		Deal = rotation.Deals[day % #rotation.Deals + 1] or "",
		DealEnds = (day + 1) * 86400,
	}
end

export type Shop = typeof(Shop)

return Shop
