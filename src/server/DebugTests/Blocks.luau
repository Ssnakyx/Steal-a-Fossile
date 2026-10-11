--!strict
-- Tests FossilDebug du brief 9 « blocs-hybrides » : les modèles des blocs de fossiles (BlockModels), une forme par
-- biome et par rareté.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("blocks")
-- Rien n'est laissé dans le jeu : les modèles de test sont construits hors du Workspace puis détruits. L'habillage des
-- blocs chez le client (FossilBlockController) se regarde en jeu : un bloc près de la caméra est en briques, son cube
-- coloré du serveur reste visible au loin.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockModels = require(ReplicatedStorage.Shared.BlockModels)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local DebugService = require(script.Parent.Parent.Services.DebugService)

type Tester = DebugService.Tester

local BUDGET = 116 -- pièces au plus par bloc, pièce Root comprise

-- Bas des briques droites (non tournées) d'un modèle : le bas du bloc
local function bottom(model: Model): number
	local low = math.huge
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Root" and math.abs(p.CFrame.UpVector.Y - 1) < 1e-4 then
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
		end
	end
	return low
end

return {
	blocks = function(t: Tester)
		local zones: { string? } = { nil }
		for _, zone in Zones.List do
			t:Check(BlockModels.Biome(zone.Name), zone.Name .. ": block form")
			table.insert(zones, zone.Name)
		end
		local worst, total = 0, 0
		for i = 1, #Zones.List + 1 do
			local zone = zones[i]
			for _, name in Rarity.Order do
				local label = (zone or "no zone") .. " " .. name
				local model = BlockModels.Build(name, 3, zone)
				if not t:Check(model, label .. ": block model built") then
					continue
				end
				local built = model :: Model
				local count, loose = 0, 0
				for _, p in built:GetChildren() do
					if p:IsA("BasePart") then
						count += 1
						if p.Anchored == false or p.CanCollide or p.CanQuery or p.CanTouch then
							loose += 1
						end
					end
				end
				worst = math.max(worst, count)
				total += 1
				t:Check(count > 1 and count <= BUDGET, label .. ": parts within budget", count)
				t:Equal(loose, 0, label .. ": anchored, no collision, no query, no touch")
				t:Check(math.abs(bottom(built) + BlockModels.Size / 2) < 0.02, label .. ": sits on the ground", bottom(built))
				built:Destroy()
			end
		end
		t:Note(string.format("%d block models, at most %d parts", total, worst))
		-- chaque bloc posé par le serveur peut être habillé chez le client
		local unknown, noForm = 0, 0
		local placed = CollectionService:GetTagged("FossilBlock")
		for _, block in placed do
			if not BlockModels.Get(block:GetAttribute("Rarity")) then
				unknown += 1
			end
			if not BlockModels.Biome(block:GetAttribute("Zone")) then
				noForm += 1
			end
		end
		t:Equal(unknown, 0, "dig site blocks all have a known rarity")
		t:Equal(noForm, 0, "dig site blocks all have a biome form")
		t:Note(string.format("%d blocks on dig sites", #placed))
		t:Equal(BlockModels.Build("Nope"), nil, "unknown rarity: no model")
	end,
}
