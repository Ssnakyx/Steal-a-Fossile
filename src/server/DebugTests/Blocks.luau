--!strict
-- Tests FossilDebug du brief 9 « blocs-hybrides » : les modèles des blocs de fossiles (BlockModels).
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("blocks")
-- Rien n'est laissé dans le jeu : les modèles de test sont construits hors du Workspace puis détruits. L'habillage des
-- blocs chez le client (FossilBlockController) se regarde en jeu : un bloc près de la caméra est en briques, son cube
-- coloré du serveur reste visible au loin.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockModels = require(ReplicatedStorage.Shared.BlockModels)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local DebugService = require(script.Parent.Parent.Services.DebugService)

type Tester = DebugService.Tester

local BUDGET = 100 -- pièces au plus par bloc

return {
	blocks = function(t: Tester)
		for _, name in Rarity.Order do
			local model = BlockModels.Build(name)
			if not t:Check(model, name .. ": block model built") then
				continue
			end
			local built = model :: Model
			local count, loose = 0, 0
			local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
			for _, p in built:GetChildren() do
				if p:IsA("BasePart") then
					count += 1
					if p.Anchored == false or p.CanCollide or p.CanQuery or p.CanTouch then
						loose += 1
					end
					if p.Name == "Rock" or p.Name == "Rainbow" or p.Name == "Glow" then
						lo = lo:Min(p.Position - p.Size / 2)
						hi = hi:Max(p.Position + p.Size / 2)
					end
				end
			end
			t:Check(count > 0 and count <= BUDGET, name .. ": parts within budget", count)
			t:Equal(loose, 0, name .. ": anchored, no collision, no query, no touch")
			t:Check(math.abs(hi.Y - lo.Y - BlockModels.Size) < 0.05, name .. ": rock is " .. BlockModels.Size .. " studs", hi.Y - lo.Y)
			t:Check(BlockModels.Looks[name] ~= nil, name .. ": rarity effects")
			t:Note(string.format("%s: %d parts", name, count))
			built:Destroy()
		end
		-- chaque bloc posé par le serveur peut être habillé chez le client
		local unknown = 0
		local placed = CollectionService:GetTagged("FossilBlock")
		for _, block in placed do
			if not BlockModels.Get(block:GetAttribute("Rarity")) then
				unknown += 1
			end
		end
		t:Equal(unknown, 0, "dig site blocks all have a known rarity")
		t:Note(string.format("%d blocks on dig sites", #placed))
		t:Equal(BlockModels.Build("Nope"), nil, "unknown rarity: no model")
	end,
}
