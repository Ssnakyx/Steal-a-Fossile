-- Blocs de fossiles côté client (brief 9) : FossilBlockController habille les pièces FossilBlock, DroppedFossil,
-- CarriedFossil et TankBlock du serveur avec les modèles de BlockModels, les suit, les défait au loin et quand la pièce
-- part (arrachée, streaming out), joue les effets de la rareté. Valeurs hostiles : raretés inconnues, BlockId absurdes,
-- pièces au mauvais nom.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3, CFrame, Instance = env.Vector3, env.CFrame, env.Instance
local workspace = env.game:GetService("Workspace")

local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
local other = env.addPlayer({ Name = "Other", Character = true })
env.setSide("client", me)
local BlockModels = env.module("src/shared/BlockModels")
local Controller = env.module("src/client/Controllers/FossilBlockController")
Controller.Init()
Controller.Start()
env.flush()

local camera = workspace.CurrentCamera
camera.CFrame = CFrame.new(0, 5, 0)
local folder = workspace:FindFirstChild("FossilBlockModels")
T.check(folder ~= nil, "dossier des modèles du client dans Workspace")

local function block(name: string, rarity: any, position: any, size: number?): any
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(size or 3, size or 3, size or 3)
	part.CFrame = CFrame.new(position)
	if rarity ~= nil then
		part:SetAttribute("Rarity", rarity)
	end
	return part
end

local function modelOf(part: any): any
	return Controller.Tracked()[part]
end

-- Briques du modèle (sans les effets)
local function bricks(model: any): { any }
	local out = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(out, p)
		end
	end
	return out
end

local function fxCount(model: any, name: string): number
	local fx = model:FindFirstChild("Fx")
	local n = 0
	for _, p in (if fx then fx:GetChildren() else {}) do
		if p.Name == name and p.Transparency < 1 then
			n += 1
		end
	end
	return n
end

local function center(model: any): any
	local sum, n = Vector3.zero, 0
	for _, p in bricks(model) do
		if p.Name == "Rock" or p.Name == "Rainbow" then
			sum += p.Position
			n += 1
		end
	end
	return if n > 0 then sum / n else Vector3.new(math.huge, 0, 0)
end

T.section("bloc d'un gisement près de la caméra")
local site = block("FossilBlock", "Epic", Vector3.new(0, 1.5, -20))
site:SetAttribute("BlockId", 0)
site.Parent = workspace
env.advance(0.3)
local model = modelOf(site)
T.check(model ~= nil and model ~= false, "modèle construit")
if model then
	T.eq(model.Parent, folder, "modèle dans le dossier du client")
	T.eq(#bricks(model), BlockModels.Count("Epic"), "toutes les briques du bloc Epic")
	T.check((center(model) - site.Position).Magnitude < 0.3, "modèle centré sur la pièce du serveur")
	T.eq(site.LocalTransparencyModifier, 1, "cube du serveur caché chez le client")
	T.eq(site.Transparency, 0, "transparence du serveur intacte")
	local front = false
	for _, p in bricks(model) do
		if p.Name == "Fossil" and p.Position.Z < site.Position.Z - 1.5 then
			front = true
		end
	end
	T.check(front, "BlockId 0 : crâne vers -Z")
end

T.section("effets de la rareté")
env.advance(3)
model = modelOf(site)
if model then
	T.eq(fxCount(model, "Aura"), BlockModels.Looks.Epic.Orbit, "Epic : cubes de l'aura")
	T.check(fxCount(model, "Spark") > 0, "Epic : cubes qui montent")
	local aura = model:FindFirstChild("Fx"):FindFirstChild("Aura")
	local before = aura.Position
	env.advance(0.5)
	T.check((aura.Position - before).Magnitude > 0.05, "l'aura tourne")
end
local plain = block("FossilBlock", "Common", Vector3.new(6, 1.5, -20))
plain.Parent = workspace
env.advance(2)
local plainModel = modelOf(plain)
T.check(plainModel ~= nil and plainModel ~= false, "Common construit")
if plainModel then
	local fx = plainModel:FindFirstChild("Fx")
	T.eq(if fx then #fx:GetChildren() else 0, 0, "Common : aucun effet")
end

T.section("BlockId fait tourner le bloc")
site:SetAttribute("BlockId", 2)
env.advance(0.1)
model = modelOf(site)
if model then
	local back = false
	for _, p in bricks(model) do
		if p.Name == "Fossil" and p.Position.Z > site.Position.Z + 1.5 then
			back = true
		end
	end
	T.check(back, "BlockId 2 : crâne vers +Z")
end
for _, bad in { 0 / 0, math.huge, -7, "x", 1e12 } do
	site:SetAttribute("BlockId", bad)
	env.advance(0.05)
end
T.eq(#env.errors, 0, "BlockId absurdes : aucune erreur")

T.section("la pièce bouge : le modèle suit")
site.CFrame = CFrame.new(10, 1.5, -25)
env.advance(0.1)
model = modelOf(site)
T.check(model and (center(model) - site.Position).Magnitude < 0.3, "modèle déplacé avec la pièce")

T.section("loin de la caméra : cube du serveur")
local far = block("DroppedFossil", "Rare", Vector3.new(0, 1.5, -600))
far.Parent = workspace
env.advance(0.5)
T.eq(modelOf(far), false, "trop loin : pas de modèle")
T.eq(far.LocalTransparencyModifier, 0, "trop loin : cube du serveur visible")
camera.CFrame = CFrame.new(0, 5, -560)
env.advance(0.5)
local farModel = modelOf(far)
T.check(farModel ~= nil and farModel ~= false, "caméra proche : modèle construit")
T.eq(far.LocalTransparencyModifier, 1, "caméra proche : cube caché")
T.eq(modelOf(site), false, "le bloc du gisement, maintenant loin, est défait")
T.eq(site.LocalTransparencyModifier, 0, "et son cube réapparaît")
camera.CFrame = CFrame.new(0, 5, 0)
env.advance(0.5)
T.check(modelOf(site) ~= false, "retour : refait")

T.section("rareté qui change, rareté inconnue")
site:SetAttribute("Rarity", "Secret")
env.advance(0.3)
model = modelOf(site)
T.check(model and #bricks(model) == BlockModels.Count("Secret"), "Epic -> Secret : modèle refait")
local beam = 0
for _, f in folder:GetChildren() do
	if f.Name == "Beam" then
		beam += #f:GetChildren()
	end
end
T.check(beam > 0, "Secret : colonne de cubes vers le ciel")
local rainbow = nil
for _, p in bricks(model) do
	if p.Name == "Rainbow" then
		rainbow = p
		break
	end
end
local hueBefore = rainbow and rainbow.Color
env.advance(1)
T.check(rainbow ~= nil and rainbow.Color ~= hueBefore, "Secret : les couches changent de couleur")
for _, bad in { "Nope", 42, "", true, "secret" } do
	site:SetAttribute("Rarity", bad)
	env.advance(0.3)
	T.eq(modelOf(site), false, "rareté " .. T.show(bad) .. " : pas de modèle")
	T.eq(site.LocalTransparencyModifier, 0, "rareté " .. T.show(bad) .. " : cube du serveur visible")
end
beam = 0
for _, f in folder:GetChildren() do
	if f.Name == "Beam" then
		beam += 1
	end
end
T.eq(beam, 0, "plus de Secret : colonne retirée")
site:SetAttribute("Rarity", "Mythic")
env.advance(0.3)
model = modelOf(site)
T.check(model and #bricks(model) == BlockModels.Count("Mythic"), "retour à une vraie rareté : refait")
local lava = model and model:FindFirstChild("Glow")
local seen = {}
for _ = 1, 8 do
	env.advance(0.1)
	if lava then
		seen[string.format("%.2f", lava.Transparency)] = true
	end
end
local pulses = 0
for _ in seen do
	pulses += 1
end
T.check(pulses > 2, "Mythic : la lave bat")

T.section("rareté posée après la pièce (cuve)")
local tank = block("TankBlock", nil, Vector3.new(-6, 1.5, -20), 2.5)
tank.Parent = workspace
env.advance(0.3)
T.eq(modelOf(tank), false, "sans rareté : rien")
tank:SetAttribute("Rarity", "Legendary")
env.advance(0.3)
local tankModel = modelOf(tank)
T.check(tankModel ~= nil and tankModel ~= false, "rareté arrivée : construit")
if tankModel then
	local lo, hi = math.huge, -math.huge
	for _, p in bricks(tankModel) do
		if p.Name == "Rock" then
			lo = math.min(lo, p.Position.X - p.Size.X / 2)
			hi = math.max(hi, p.Position.X + p.Size.X / 2)
		end
	end
	T.near(hi - lo, 2.5, 0.05, "bloc de cuve : 2,5 studs comme la pièce")
end

T.section("bloc porté sur le dos")
local function carry(player: any, rarity: string): any
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	local part = block("CarriedFossil", rarity, root.Position + Vector3.new(0, 0.6, 1.6), 2.5)
	part.Anchored = false
	part.Massless = true
	part.Parent = player.Character
	return part, root
end
local carried, root = carry(other, "Secret")
env.advance(0.3)
local carriedModel = modelOf(carried)
T.check(carriedModel ~= nil and carriedModel ~= false, "bloc porté habillé")
if carriedModel then
	T.eq(fxCount(carriedModel, "Aura"), 0, "porté : pas d'aura (elle traverserait le joueur)")
	local back = false
	for _, p in bricks(carriedModel) do
		if p.Name == "Fossil" and p.Position.Z > carried.Position.Z + 1.2 then
			back = true
		end
	end
	T.check(back, "porté : crâne tourné vers l'arrière")
	-- le personnage court : la pièce soudée bouge sans signal CFrame (physique), le modèle suit à chaque image
	env.setProperty(carried, "CFrame", CFrame.new(carried.Position + Vector3.new(0, 0, -30)))
	env.advance(0.05)
	T.check((center(carriedModel) - carried.Position).Magnitude < 0.3, "porté : le modèle suit la pièce")
end
local others = 0
for _, f in folder:GetChildren() do
	if f.Name == "Beam" then
		others += 1
	end
end
T.check(others >= 1, "Secret porté par un autre joueur : colonne visible")
local mine = carry(me, "Secret")
env.advance(0.3)
local after = 0
for _, f in folder:GetChildren() do
	if f.Name == "Beam" then
		after += 1
	end
end
T.eq(after, others, "Secret sur son propre dos : pas de colonne (elle cacherait la vue)")
T.check(modelOf(mine) ~= false, "son propre bloc est quand même habillé")
T.check(root ~= nil, "personnage avec HumanoidRootPart")

T.section("la pièce part : modèle défait")
local count = #folder:GetChildren()
carried:Destroy()
env.advance(0.1)
T.eq(modelOf(carried), nil, "pièce détruite : plus suivie")
T.check(#folder:GetChildren() < count, "pièce détruite : modèle et colonne retirés")
far.Parent = nil
env.advance(0.1)
T.eq(modelOf(far), nil, "streaming out : plus suivie")
far.Parent = workspace
camera.CFrame = CFrame.new(0, 5, -560)
env.advance(0.5)
T.check(modelOf(far) ~= nil and modelOf(far) ~= false, "streaming in : rhabillée")
camera.CFrame = CFrame.new(0, 5, 0)

T.section("pièces qui ne sont pas des blocs")
local stranger = block("Rock", "Epic", Vector3.new(3, 1.5, -10))
stranger.Parent = workspace
local label = Instance.new("Model")
label.Name = "FossilBlock"
label:SetAttribute("Rarity", "Epic")
label.Parent = workspace
env.advance(0.3)
T.eq(modelOf(stranger), nil, "pièce au mauvais nom ignorée")
T.eq(stranger.LocalTransparencyModifier, 0, "pièce au mauvais nom intacte")

T.eq(#env.errors, 0, "aucune erreur")
T.done("blocks_client")
