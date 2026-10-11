--!strict
-- Données du joueur, domaine Loop (brief 3 « boucle ») : dinos de l'enclos, cuves, blocs en réserve, tutoriel.
-- Fichier posé par le brief 1 « fondations », complété par le brief 3.
-- Format d'un domaine : voir src/server/Services/DataService.luau.
-- (Version 1 complétée avant toute publication : aucune sauvegarde de l'ancien format n'existe.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

local MAX_TANKS = Economy.Tanks.Max
local SIZES: { [string]: boolean } = {}
for _, size in Economy.Sizes do
	SIZES[size.Name] = true
end
local MUTATIONS: { [string]: boolean } = { [""] = true }
for _, mutation in Economy.Mutations do
	MUTATIONS[mutation.Name] = true
end

-- Bloc gardé (cuve ou réserve) : { Rarity, Zone } valides, ou nil
local function cleanBlock(block: any): { [string]: any }?
	if type(block) ~= "table" or type(block.Rarity) ~= "string" or Rarity.Info[block.Rarity] == nil then
		return nil
	end
	block.Zone = if type(block.Zone) == "string" and #block.Zone <= 50 then block.Zone else ""
	return block
end

return {
	Version = 1,
	Defaults = {
		-- Dinos de l'enclos, par identifiant (texte) :
		--   { Species = "Triceratops", Size = "Normal", Mutation = "", Level = 0, Got = os.time() }
		-- Size : Small, Normal, Big, Huge. Mutation : "", Amber, Crystal, Lava. Level : 0 Normal, 1 Golden, 2 Diamond.
		-- Un hybride a pour Species le nom de l'hybride (brief 8).
		Dinos = {},
		NextDinoId = 1, -- prochain identifiant de dino (tostring(NextDinoId))
		-- Blocs en réanimation, par numéro de cuve ("1" à "6") : { Rarity = "Rare", Zone = "Beach", StartedAt = 0, EndsAt = 0 }
		-- (StartedAt, EndsAt : os.time())
		Tanks = {},
		TankCount = 2, -- cuves possédées
		-- Blocs rapportés au parc pendant que toutes les cuves étaient pleines : { { Rarity, Zone } }, les plus anciens
		-- d'abord. Ils partent tout seuls dans la prochaine cuve libre.
		Stored = {},
		EnclosureUpgrades = 0, -- agrandissements d'enclos achetés (slots : Config.Economy.EnclosureSlots)
		-- Tutoriel : 0 nouveau (aller à la Beach), 1 premier bloc arraché, 2 premier bloc rapporté, 3 premier dino révélé
		Tutorial = 0,
	},

	Sanitize = function(data: Data)
		local dinos = {}
		local highest = 0
		for id, dino in data.Dinos do
			if type(id) == "string" and type(dino) == "table" and type(dino.Species) == "string" and #dino.Species <= 50 then
				dino.Size = if SIZES[dino.Size] then dino.Size else "Normal"
				dino.Mutation = if MUTATIONS[dino.Mutation] then dino.Mutation else ""
				dino.Level = Guard.IntegerOr(dino.Level, 0, 0, #Economy.Levels - 1)
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
		data.TankCount = Guard.IntegerOr(data.TankCount, Economy.Tanks.Start, Economy.Tanks.Start, MAX_TANKS)
		local tanks = {}
		for slot, tank in data.Tanks do
			local index = tonumber(slot)
			if type(slot) == "string" and index and index % 1 == 0 and index >= 1 and index <= data.TankCount and cleanBlock(tank) then
				tank.StartedAt = Guard.IntegerOr(tank.StartedAt, 0, 0)
				tank.EndsAt = Guard.IntegerOr(tank.EndsAt, 0, 0)
				tanks[tostring(index)] = tank
			end
		end
		data.Tanks = tanks
		local stored = {}
		for _, block in data.Stored do
			local clean = cleanBlock(block)
			if clean and #stored < Economy.MaxStored then
				table.insert(stored, { Rarity = clean.Rarity, Zone = clean.Zone })
			end
		end
		data.Stored = stored
		data.EnclosureUpgrades = Guard.IntegerOr(data.EnclosureUpgrades, 0, 0, #Economy.Enclosure.Prices)
		data.Tutorial = Guard.IntegerOr(data.Tutorial, 0, 0, 3)
	end,
}
