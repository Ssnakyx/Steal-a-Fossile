--!strict
-- Tests FossilDebug du brief 8 « fusion » : fusion Upgrade, recette inconnue, fusion hybride, chimères des recettes.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("fusion")
-- (ou "hybrids", "all"). Les fusions de test sont gratuites et marchent hors du parc ; chaque test retire ses dinos et
-- remet l'Index des hybrides comme il l'a trouvé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DinoBuilder = require(ReplicatedStorage.Shared.DinoBuilder)
local Fusion = require(ReplicatedStorage.Shared.Config.Fusion)
local HybridBuilder = require(ReplicatedStorage.Shared.HybridBuilder)
local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local EnclosureService = require(Services.EnclosureService)
local FusionService = require(Services.FusionService)
local MoneyService = require(Services.MoneyService)

type Tester = DebugService.Tester

local HOSTILE: { any } = { 0 / 0, math.huge, -1, "1", "", true, {}, { "1" }, { "1", "1" }, { 1, 2 }, Vector3.zero }
local TEST = { Free = true, Anywhere = true }

-- Deux espèces sans recette (pour la recette inconnue)
local function unknownPair(): (string?, string?)
	local list = Config.Species.List
	for i = 1, #list do
		for j = i + 1, #list do
			if not FusionService.FindRecipe(list[i].Name, list[j].Name) then
				return list[i].Name, list[j].Name
			end
		end
	end
	return nil, nil
end

return {
	fusion = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local data = DataService.Get(target) :: DataService.Data
		if EnclosureService.Slots(target) - EnclosureService.Count(target) < 3 then
			t:Note("enclosure has less than 3 free slots: fusion test skipped")
			return
		end
		local money = MoneyService.Get(target)
		local count = EnclosureService.Count(target)
		local made: { string } = {}
		local function give(species: string, size: string?, mutation: string?): string
			local id = EnclosureService.AddDino(target, { Species = species, Size = size, Mutation = mutation }) :: string
			table.insert(made, id)
			return id
		end

		-- Upgrade
		local ids = { give("Compy", "Small"), give("Compy", "Big", "Amber"), give("Compy", "Normal") }
		local ok, info = FusionService.Preview(target, ids)
		if t:Check(ok, "upgrade preview", info) then
			t:Equal(info.Mode, "Upgrade", "upgrade mode")
			t:Equal(info.Size, "Big", "best size kept")
			t:Equal(info.Mutation, "Amber", "best mutation kept")
			t:Equal(info.LevelName, "Golden", "next level")
			t:Check(info.Cost >= Fusion.MinCost, "upgrade has a cost")
		end
		local text
		ok, text, info = FusionService.Fuse(target, ids, TEST)
		if t:Check(ok, "upgrade fused", text) then
			table.insert(made, info.Id)
			local dino = EnclosureService.GetDino(target, info.Id)
			t:Check(dino ~= nil and dino.Level == 1 and dino.Size == "Big", "Golden Big Compy made")
			t:Equal(EnclosureService.GetDino(target, ids[1]), nil, "inputs used up")
		end
		ok = FusionService.Fuse(target, ids, TEST)
		t:Check(not ok, "same dinos twice refused")

		-- recette inconnue
		local a, b = unknownPair()
		if t:Check(a and b, "a pair without recipe exists") then
			local pair = { give(a :: string), give(b :: string) }
			ok, info = FusionService.Preview(target, pair)
			t:Check(ok and info.Known == false and info.Species == Fusion.UnknownName, "unknown preview shows ???")
			ok, text = FusionService.Fuse(target, pair, TEST)
			t:Check(not ok and string.find(text, "Unknown recipe", 1, true) ~= nil, "unknown recipe refused", text)
			t:Check(EnclosureService.GetDino(target, pair[1]) and EnclosureService.GetDino(target, pair[2]), "dinos kept")
		end

		-- hybride
		local hybrid = FusionService.Hybrids()[1]
		if t:Check(hybrid, "recipes loaded") then
			local wasFound = data.Index.Hybrids[hybrid.Name] == true
			local pair = { give(hybrid.Body, "Huge"), give(hybrid.Head, nil, "Crystal") }
			ok, info = FusionService.Preview(target, pair)
			t:Check(ok and info.Known == wasFound, "hybrid preview hidden until found")
			ok, text, info = FusionService.Fuse(target, pair, TEST)
			if t:Check(ok, "hybrid fused", text) then
				table.insert(made, info.Id)
				local dino = EnclosureService.GetDino(target, info.Id)
				t:Check(dino ~= nil and dino.Species == hybrid.Name and dino.Size == "Huge" and dino.Mutation == "Crystal", hybrid.Name .. " made (Huge Crystal)")
				t:Equal(info.Key, hybrid.Key, "chimera key sent")
				local model = EnclosureService.ModelOf(target, info.Id)
				if t:Check(model, "chimera in the park") then
					t:Equal((model :: Model):GetAttribute("Species"), hybrid.Key, "model Species = chimera key")
					t:Equal((model :: Model):GetAttribute("Rarity"), hybrid.Rarity, "model Rarity")
				end
				t:Check(data.Index.Hybrids[hybrid.Name] == true, "hybrid discovered")
			end
			if not wasFound then
				data.Index.Hybrids[hybrid.Name] = nil
				FusionService.Publish(target)
			end
		end

		for _, value in HOSTILE do
			t:Check(not FusionService.Preview(target, value), "hostile ids refused: " .. typeof(value))
		end

		for _, id in made do
			EnclosureService.RemoveDino(target, id)
		end
		t:Equal(EnclosureService.Count(target), count, "test dinos removed")
		t:Equal(MoneyService.Get(target), money, "money unchanged (test fusions are free)")
	end,

	hybrids = function(t: Tester)
		local list = FusionService.Hybrids()
		t:Check(#list >= 12, "12 recipes or more", #list)
		for _, hybrid in list do
			t:Equal(EnclosureService.ModelName(hybrid.Name), hybrid.Key, hybrid.Name .. ": model = key")
			if not HybridBuilder.CanBuild(hybrid.Key) then
				t:Note(hybrid.Name .. ": a parent has no model yet (placeholder in the park)")
				continue
			end
			local data = HybridBuilder.Ensure(hybrid.Key)
			if t:Check(data, hybrid.Name .. ": chimera assembled") then
				local chimera = data :: DinoBuilder.Data
				local _, bodyModel = HybridBuilder.Parse(hybrid.Key)
				local body = if bodyModel then DinoBuilder.Get(bodyModel) else nil
				local clips = 0
				for _ in chimera.Clips do
					clips += 1
				end
				local bodyClips = 0
				if body then
					for _ in body.Clips do
						bodyClips += 1
					end
				end
				t:Equal(clips, bodyClips, hybrid.Name .. ": all body animations")
				t:Note(string.format("%s = %s + %s: %d parts, %.1f x %.1f x %.1f", hybrid.Name, hybrid.Head, hybrid.Body, #chimera.Boxes, chimera.Size.X, chimera.Size.Y, chimera.Size.Z))
			end
		end
	end,
}
