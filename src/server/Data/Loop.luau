--!strict
-- Données du joueur, domaine Loop : dinos, blocs en cuve, enclos, tutoriel.
-- Fichier posé par le brief 1 « fondations » ; appartient au brief 3 « boucle » (qui le complète et le fait évoluer).
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

local MAX_TANKS = 6 -- (GDD : 2 cuves au départ, jusqu'à 6)

return {
	Version = 1,
	Defaults = {
		-- Dinos possédés, par identifiant (texte) :
		--   { Species = "Triceratops", Size = "Normal", Mutation = "", Level = 0, Got = os.time() }
		-- Size : Small, Normal, Big, Huge. Mutation : "", Amber, Crystal, Lava. Level : 0 Normal, 1 Golden, 2 Diamond.
		-- Un hybride a pour Species le nom de l'hybride (brief 8).
		Dinos = {},
		NextDinoId = 1, -- prochain identifiant de dino (tostring(NextDinoId))
		-- Blocs en réanimation, par numéro de cuve ("1" à "6") : { Rarity = "Rare", Zone = "Beach", StartedAt = 0, EndsAt = 0 }
		Tanks = {},
		TankCount = 2, -- cuves possédées
		EnclosureUpgrades = 0, -- agrandissements d'enclos achetés (le nombre de slots se calcule dans la config du brief 3)
		Tutorial = 0, -- étape du tutoriel (0 = pas commencé)
	},

	Sanitize = function(data: Data)
		local dinos = {}
		local highest = 0
		for id, dino in data.Dinos do
			if type(id) == "string" and type(dino) == "table" and type(dino.Species) == "string" then
				dino.Size = if type(dino.Size) == "string" then dino.Size else "Normal"
				dino.Mutation = if type(dino.Mutation) == "string" then dino.Mutation else ""
				dino.Level = Guard.IntegerOr(dino.Level, 0, 0, 2)
				dino.Got = Guard.IntegerOr(dino.Got, 0, 0)
				dinos[id] = dino
				local number = tonumber(id)
				if number and number > highest then
					highest = number
				end
			end
		end
		data.Dinos = dinos
		data.NextDinoId = math.max(Guard.IntegerOr(data.NextDinoId, 1, 1), math.floor(highest) + 1)
		local tanks = {}
		for slot, tank in data.Tanks do
			local index = tonumber(slot)
			if type(slot) == "string" and index and index % 1 == 0 and index >= 1 and index <= MAX_TANKS and type(tank) == "table" and type(tank.Rarity) == "string" then
				tank.Zone = if type(tank.Zone) == "string" then tank.Zone else ""
				tank.StartedAt = Guard.IntegerOr(tank.StartedAt, 0, 0)
				tank.EndsAt = Guard.IntegerOr(tank.EndsAt, 0, 0)
				tanks[slot] = tank
			end
		end
		data.Tanks = tanks
		data.TankCount = Guard.IntegerOr(data.TankCount, 2, 2, MAX_TANKS)
		data.EnclosureUpgrades = Guard.IntegerOr(data.EnclosureUpgrades, 0, 0)
		data.Tutorial = Guard.IntegerOr(data.Tutorial, 0, 0)
	end,
}
