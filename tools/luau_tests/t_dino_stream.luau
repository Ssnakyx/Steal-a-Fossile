-- Dinos côté client avec StreamingEnabled (brief 2) : DinoAnimController. Le modèle tagué « Dino » (proxy du serveur)
-- peut arriver avant sa pièce Root : le contrôleur attend la pièce et construit les briques quand elle arrive. Si la
-- pièce repart (streaming out), les briques sont défaites ; quand une nouvelle pièce Root revient, le dino est refait
-- et suit la nouvelle pièce. Un modèle qui perd son tag pendant l'attente n'est jamais construit.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3, CFrame, Instance = env.Vector3, env.CFrame, env.Instance
local workspace = env.game:GetService("Workspace")

local me = env.addPlayer({ Local = true, Name = "Me" })
env.setSide("client", me)
local DinoAnimController = env.module("src/client/Controllers/DinoAnimController")
DinoAnimController.Init()
DinoAnimController.Start()
env.flush()

-- Proxy comme le serveur (DinoBuilder.CreateProxy ou GuardianService) : attributs + tag, pièce Root à part
local function proxy(name: string, species: string): any
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Species", species)
	model:SetAttribute("Scale", 1)
	model:SetAttribute("State", "Idle")
	model:AddTag("Dino")
	return model
end

local function rootAt(position: any): any
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(position)
	return root
end

-- Briques du dino construites chez le client (pièces avec l'attribut Bone) et position de l'os Hips
local function bricks(model: any): (number, any)
	local count, hips = 0, nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Bone") then
			count += 1
			if part:GetAttribute("Bone") == "Hips" and not hips then
				hips = part.Position
			end
		end
	end
	return count, hips
end

local function flat(a: any, b: any): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

T.section("modèle avant sa pièce Root")
local raptor = proxy("Raptor", "Velociraptor")
raptor.Parent = workspace
env.advance(0.2)
T.eq((bricks(raptor)), 0, "sans Root : rien de construit")
T.eq(#env.errors, 0, "sans Root : aucune erreur")

T.section("la pièce Root arrive")
local here = Vector3.new(0, 0, -30)
rootAt(here).Parent = raptor
env.advance(0.2)
local count, hips = bricks(raptor)
T.check(count > 50, "Root arrivée : briques construites (" .. count .. ")")
T.check(hips ~= nil and flat(hips, here) < 3, "briques posées sur la pièce Root")

T.section("le dino suit la pièce Root")
local root = raptor:FindFirstChild("Root")
local moved = here + Vector3.new(30, 0, 0)
root.CFrame = CFrame.new(moved)
env.advance(0.5)
local _, hips2 = bricks(raptor)
T.check(hips2 ~= nil and flat(hips2, moved) < 3, "briques déplacées avec la pièce Root")

T.section("streaming out puis in")
root.Parent = nil
env.advance(0.2)
T.eq((bricks(raptor)), 0, "Root repartie : briques défaites")
local back = Vector3.new(-40, 0, -60)
rootAt(back).Parent = raptor
env.advance(0.5)
local count3, hips3 = bricks(raptor)
T.check(count3 > 50, "nouvelle Root : dino refait (" .. count3 .. ")")
T.check(hips3 ~= nil and flat(hips3, back) < 3, "dino posé sur la nouvelle pièce Root")
T.eq(count3, count, "même nombre de briques qu'avant")
local newRoot = raptor:FindFirstChild("Root")
local again = back + Vector3.new(0, 0, 25)
newRoot.CFrame = CFrame.new(again)
env.advance(0.5)
local _, hips4 = bricks(raptor)
T.check(hips4 ~= nil and flat(hips4, again) < 3, "suit la nouvelle pièce Root")

T.section("modèle complet d'un coup")
local trike = proxy("Trike", "Triceratops")
rootAt(Vector3.new(50, 0, -50)).Parent = trike
trike.Parent = workspace
env.advance(0.2)
T.check((bricks(trike)) > 50, "modèle arrivé avec sa Root : construit")

T.section("tag retiré pendant l'attente")
local ptera = proxy("Ptera", "Pteranodon")
ptera.Parent = workspace
env.advance(0.1)
ptera:RemoveTag("Dino")
rootAt(Vector3.new(-50, 0, -50)).Parent = ptera
env.advance(0.2)
T.eq((bricks(ptera)), 0, "plus de tag : pas construit")

T.section("modèle Atomic : sort puis revient")
-- Roblox lance GetInstanceRemovedSignal / GetInstanceAddedSignal quand un modèle tagué quitte ou rejoint le jeu ;
-- le faux Roblox ne le fait que pour AddTag, RemoveTag et Destroy : on les lance à la main
local CollectionService = env.game:GetService("CollectionService")
trike.Parent = nil
env.fire(CollectionService:GetInstanceRemovedSignal("Dino"), trike)
env.advance(0.1)
T.eq((bricks(trike)), 0, "modèle sorti : briques défaites")
trike.Parent = workspace
env.fire(CollectionService:GetInstanceAddedSignal("Dino"), trike)
env.advance(0.2)
T.check((bricks(trike)) > 50, "modèle revenu : refait")
local before = #trike:GetChildren()
env.fire(CollectionService:GetInstanceAddedSignal("Dino"), trike)
env.advance(0.2)
T.eq(#trike:GetChildren(), before, "signal en double : pas construit deux fois")

T.section("modèle détruit")
raptor:Destroy()
trike:Destroy()
env.advance(0.2)
T.eq(#env.errors, 0, "aucune erreur")

T.done("dino_stream")
