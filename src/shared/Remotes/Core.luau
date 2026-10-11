--!strict
-- Remotes communs (brief 1 « fondations »).

return {
	Events = {
		Replica = "serveur -> client : changements de l'état du joueur (seq: numéro d'envoi, changes: {[clé]: valeur}, removed: {clé})",
		Notify = "serveur -> client : message court à afficher (texte, genre : info | success | error | money)",
	},
	Functions = {
		GetReplica = "client -> serveur : état complet du joueur au démarrage -> ({[clé]: valeur}, seq)",
		Admin = "client -> serveur : commande d'administrateur (nom, arguments) -> (ok, texte)",
	},
}
