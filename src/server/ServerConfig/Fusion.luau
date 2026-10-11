--!strict
-- Recettes secrètes de la fusion hybride (brief 8, GDD section Fusion). Côté serveur seulement : jamais envoyées à un
-- client avant qu'il les découvre (seuls les indices le sont, pour la page Hybrids de l'Index).
--   Name  : nom de l'hybride (data.Dinos[id].Species, data.Index.Hybrids) ; ne plus le changer une fois publié
--   Head  : espèce qui donne la tête (nom de Config.Species) ; Body : celle qui donne le corps, les pattes et la queue.
--           Les ailes ou les nageoires viennent de celle qui en a (de Body si les deux en ont).
--   Hint  : indice affiché dans l'Index avant la découverte (texte en jeu, anglais)
--   Tweak : (facultatif) réglages fins de l'assemblage, voir HybridBuilder.Tweak (brief 9, corrections des jointures)
-- Une recette marche dans les deux sens (A + B = B + A). Revenu de base : (A + B) x Config.Fusion.HybridIncome.
-- Lancement : 12 recettes ; 2 ou 3 de plus à chaque mise à jour (ajouter à la fin de la liste).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HybridBuilder = require(ReplicatedStorage.Shared.HybridBuilder)

export type Recipe = {
	Name: string,
	Head: string,
	Body: string,
	Hint: string,
	Tweak: HybridBuilder.Tweak?,
}

local Recipes: { Recipe } = {
	-- Beach
	{ Name = "Ovi-Ptero", Head = "Oviraptor", Body = "Pteranodon", Hint = "Two beach neighbors: one steals eggs, one rules the sky." },
	-- Fern Forest
	{ Name = "Para-Mimus", Head = "Parasaurolophus", Body = "Gallimimus", Hint = "A trumpet crest on the fastest legs of the forest." },
	{ Name = "Tricera-Stego", Head = "Triceratops", Body = "Stegosaurus", Hint = "Three horns on a back full of plates.", Tweak = { HeadPitch = 8, HeadOffset = Vector3.new(0, 0.3, 0) } },
	-- Swamp, Canyon, Glacier
	{ Name = "Croco-Don", Head = "Sarcosuchus", Body = "Iguanodon", Hint = "A swamp jaw on a gentle plant eater." },
	{ Name = "Pachy-Anky", Head = "Pachycephalosaurus", Body = "Ankylosaurus", Hint = "A hard head on an armored back." },
	{ Name = "Shark-Raptor", Head = "Megalodon", Body = "Velociraptor", Hint = "The jaws of the deep on a canyon hunter.", Tweak = { LimbTurn = Vector3.new(0, 25, 35) } },
	-- Volcano, Ocean Trench
	{ Name = "Brachio-Tops", Head = "Brachiosaurus", Body = "Triceratops", Hint = "The longest neck on three-horned legs." },
	{ Name = "Quetza-Carno", Head = "Quetzalcoatlus", Body = "Carnotaurus", Hint = "A giant sky beak on a horned runner.", Tweak = { HeadScale = 1.15 } },
	{ Name = "Spino-Mosa", Head = "Spinosaurus", Body = "Mosasaurus", Hint = "A river hunter's head on a sea monster." },
	{ Name = "Plesio-Shark", Head = "Plesiosaurus", Body = "Megalodon", Hint = "A long neck rises from the biggest shark.", Tweak = { HeadPitch = 30 } },
	-- Meteor Crater, Secret
	{ Name = "Ptero-Rex", Head = "Pteranodon", Body = "T-Rex", Hint = "The king of the crater grows wings." },
	{ Name = "Crystal Dragon", Head = "Crystal Rex", Body = "Quetzalcoatlus", Hint = "A shining secret king takes to the sky." },
}

return {
	Recipes = Recipes,
}
