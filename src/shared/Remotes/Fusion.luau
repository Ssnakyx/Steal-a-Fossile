--!strict
-- Remotes du labo de fusion (brief 8). Les ids sont ceux de data.Dinos (clé replica « Dinos ») : 2 ids pour un hybride,
-- 3 ids identiques pour un Upgrade. Le serveur vérifie tout (dinos à toi, distincts, parc, prix) ; les recettes ne
-- sont jamais envoyées : un hybride pas encore découvert s'affiche « ??? » (Config.Fusion.UnknownName).
-- Infos de résultat : { Mode = "Upgrade" | "Hybrid", Known, Species, Key?, Size, Mutation, Level, Income, Cost, Rarity? }

return {
	Events = {
		OpenFusionLab = "serveur -> client : le joueur a utilisé le labo de son parc (ouvrir le menu du labo, brief 12)",
		FusionDone = "serveur -> client : fusion réussie (infos du résultat + Id, Inputs, New) : carte de révélation et effets",
	},
	Functions = {
		PreviewFusion = "client -> serveur : aperçu d'une fusion (liste d'ids de dinos) -> (ok, infos ou texte)",
		FuseDinos = "client -> serveur : fusionner (liste d'ids de dinos) -> (ok, texte, infos?)",
	},
}
