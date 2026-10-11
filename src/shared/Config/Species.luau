--!strict
-- Espèces de Steal a Fossil (GDD, section Espèces) : famille de mouvement, zone, taille de base et revenu de base.
--   Model    : module de src/shared/DinoModels (fabriqué par models/build.py) ; tant qu'il manque, l'espèce n'a pas
--              encore de modèle (pilotes faits : Velociraptor, Triceratops, Pteranodon, Mosasaurus)
--   Family   : "Biped" | "Quadruped" | "Flyer" | "Swimmer" (base commune des animations)
--   BaseSize : plus grande dimension du modèle à la taille Normal, en studs (petits 3-5, moyens 6-10 de haut,
--              grands 12-20, géants 25-35) ; la taille tirée à la réanimation multiplie (DinoBuilder.Sizes)
--   Income   : revenu de base en $/s, valeur de départ à équilibrer (revenu = base x taille x mutation)
-- La rareté de chaque espèce est fixée à l'équilibrage (brief boucle, Config/Rarity).

export type SpeciesDef = {
	Name: string,
	Model: string,
	Family: string,
	Zone: string,
	BaseSize: number,
	Income: number,
	Secret: boolean?,
}

local list: { SpeciesDef } = {
	-- 1. Beach
	{ Name = "Compy", Model = "Compy", Family = "Biped", Zone = "Beach", BaseSize = 4, Income = 1 },
	{ Name = "Oviraptor", Model = "Oviraptor", Family = "Biped", Zone = "Beach", BaseSize = 5, Income = 2 },
	{ Name = "Pteranodon", Model = "Pteranodon", Family = "Flyer", Zone = "Beach", BaseSize = 16, Income = 3 },
	{ Name = "Protoceratops", Model = "Protoceratops", Family = "Quadruped", Zone = "Beach", BaseSize = 6, Income = 2 },
	{ Name = "Psittacosaurus", Model = "Psittacosaurus", Family = "Biped", Zone = "Beach", BaseSize = 5, Income = 1 },
	{ Name = "Dimorphodon", Model = "Dimorphodon", Family = "Flyer", Zone = "Beach", BaseSize = 8, Income = 2 },
	{ Name = "Archelon", Model = "Archelon", Family = "Swimmer", Zone = "Beach", BaseSize = 12, Income = 4 },
	{ Name = "Tanystropheus", Model = "Tanystropheus", Family = "Quadruped", Zone = "Beach", BaseSize = 14, Income = 3 },
	-- 2. Fern Forest
	{ Name = "Gallimimus", Model = "Gallimimus", Family = "Biped", Zone = "Fern Forest", BaseSize = 9, Income = 8 },
	{ Name = "Parasaurolophus", Model = "Parasaurolophus", Family = "Quadruped", Zone = "Fern Forest", BaseSize = 12, Income = 11 },
	{ Name = "Stegosaurus", Model = "Stegosaurus", Family = "Quadruped", Zone = "Fern Forest", BaseSize = 14, Income = 15 },
	{ Name = "Hypsilophodon", Model = "Hypsilophodon", Family = "Biped", Zone = "Fern Forest", BaseSize = 6, Income = 6 },
	{ Name = "Microraptor", Model = "Microraptor", Family = "Flyer", Zone = "Fern Forest", BaseSize = 7, Income = 7 },
	{ Name = "Kentrosaurus", Model = "Kentrosaurus", Family = "Quadruped", Zone = "Fern Forest", BaseSize = 11, Income = 10 },
	{ Name = "Styracosaurus", Model = "Styracosaurus", Family = "Quadruped", Zone = "Fern Forest", BaseSize = 13, Income = 12 },
	{ Name = "Dilophosaurus", Model = "Dilophosaurus", Family = "Biped", Zone = "Fern Forest", BaseSize = 12, Income = 18 },
	-- 3. Swamp
	{ Name = "Iguanodon", Model = "Iguanodon", Family = "Quadruped", Zone = "Swamp", BaseSize = 12, Income = 35 },
	{ Name = "Baryonyx", Model = "Baryonyx", Family = "Biped", Zone = "Swamp", BaseSize = 13, Income = 45 },
	{ Name = "Sarcosuchus", Model = "Sarcosuchus", Family = "Quadruped", Zone = "Swamp", BaseSize = 16, Income = 60 },
	-- 4. Canyon
	{ Name = "Pachycephalosaurus", Model = "Pachycephalosaurus", Family = "Biped", Zone = "Canyon", BaseSize = 8, Income = 160 },
	{ Name = "Velociraptor", Model = "Velociraptor", Family = "Biped", Zone = "Canyon", BaseSize = 14, Income = 220 },
	{ Name = "Triceratops", Model = "Triceratops", Family = "Quadruped", Zone = "Canyon", BaseSize = 19, Income = 300 },
	-- 5. Glacier
	{ Name = "Ankylosaurus", Model = "Ankylosaurus", Family = "Quadruped", Zone = "Glacier", BaseSize = 15, Income = 750 },
	{ Name = "Therizinosaurus", Model = "Therizinosaurus", Family = "Biped", Zone = "Glacier", BaseSize = 16, Income = 1000 },
	{ Name = "Cryolophosaurus", Model = "Cryolophosaurus", Family = "Biped", Zone = "Glacier", BaseSize = 15, Income = 1400 },
	-- 6. Volcano
	{ Name = "Carnotaurus", Model = "Carnotaurus", Family = "Biped", Zone = "Volcano", BaseSize = 16, Income = 3600 },
	{ Name = "Brachiosaurus", Model = "Brachiosaurus", Family = "Quadruped", Zone = "Volcano", BaseSize = 32, Income = 5000 },
	{ Name = "Spinosaurus", Model = "Spinosaurus", Family = "Biped", Zone = "Volcano", BaseSize = 20, Income = 7000 },
	{ Name = "Dracorex", Model = "Dracorex", Family = "Biped", Zone = "Volcano", BaseSize = 10, Income = 3300 },
	{ Name = "Ceratosaurus", Model = "Ceratosaurus", Family = "Biped", Zone = "Volcano", BaseSize = 16, Income = 4000 },
	{ Name = "Acrocanthosaurus", Model = "Acrocanthosaurus", Family = "Biped", Zone = "Volcano", BaseSize = 19, Income = 5500 },
	{ Name = "Magma Behemoth", Model = "MagmaBehemoth", Family = "Quadruped", Zone = "Volcano", BaseSize = 22, Income = 5800 },
	{ Name = "Phoenix", Model = "Phoenix", Family = "Flyer", Zone = "Volcano", BaseSize = 24, Income = 8500 },
	-- 7. Ocean Trench
	{ Name = "Plesiosaurus", Model = "Plesiosaurus", Family = "Swimmer", Zone = "Ocean Trench", BaseSize = 18, Income = 18000 },
	{ Name = "Megalodon", Model = "Megalodon", Family = "Swimmer", Zone = "Ocean Trench", BaseSize = 24, Income = 25000 },
	{ Name = "Mosasaurus", Model = "Mosasaurus", Family = "Swimmer", Zone = "Ocean Trench", BaseSize = 30, Income = 35000 },
	-- 8. Meteor Crater
	{ Name = "Quetzalcoatlus", Model = "Quetzalcoatlus", Family = "Flyer", Zone = "Meteor Crater", BaseSize = 26, Income = 90000 },
	{ Name = "Giganotosaurus", Model = "Giganotosaurus", Family = "Biped", Zone = "Meteor Crater", BaseSize = 22, Income = 130000 },
	{ Name = "T-Rex", Model = "TRex", Family = "Biped", Zone = "Meteor Crater", BaseSize = 20, Income = 180000 },
	-- Secrets (zones lointaines surtout)
	{ Name = "Golden Raptor", Model = "GoldenRaptor", Family = "Biped", Zone = "Secret", BaseSize = 14, Income = 500000, Secret = true },
	{ Name = "Crystal Rex", Model = "CrystalRex", Family = "Biped", Zone = "Secret", BaseSize = 22, Income = 1000000, Secret = true },
	{ Name = "Lava Titan", Model = "LavaTitan", Family = "Biped", Zone = "Secret", BaseSize = 32, Income = 2000000, Secret = true },
}

local byName: { [string]: SpeciesDef } = {}
local byModel: { [string]: SpeciesDef } = {}
for _, s in list do
	byName[s.Name] = s
	byModel[s.Model] = s
end

return {
	List = list,
	ByName = byName,
	ByModel = byModel,
	Families = { "Biped", "Quadruped", "Flyer", "Swimmer" },
}
