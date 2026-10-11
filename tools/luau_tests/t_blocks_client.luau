-- Blocs de fossiles côté client (brief 9) : FossilBlockController habille les pièces FossilBlock, DroppedFossil,
-- CarriedFossil et TankBlock du serveur avec les modèles de BlockModels (rareté, décor du biome, taille, lumière), les
-- suit, les défait au loin et quand la pièce part (arrachée, streaming out), fait battre la lave et tourner
-- l'arc-en-ciel, et appelle le module des auras (SetAura). Valeurs hostiles : raretés et zones inconnues, BlockId
-- absurdes, pièces au mauvais nom, aura qui plante.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3, CFrame, Instance = env.Vector3, env.CFrame, env.Instance
local workspace = env.game:GetService("Workspace")
local CollectionService = env.game:GetService("CollectionService")

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

local function bricks(model: any, role: string?): { any }
	local out = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and (role == nil or p.Name == role) then
			table.insert(out, p)
		end
	end
	return out
end

-- Bas des briques droites (non tournées) du modèle, en coordonnées du monde : le bas du bloc
local function bottom(model: any): number
	local low = math.huge
	for _, p in bricks(model) do
		local up = p.CFrame.UpVector
		if p.Name ~= "Root" and math.abs(up.Y - 1) < 1e-4 then
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
		end
	end
	return low
end

T.section("bloc d'un gisement près de la caméra")
local site = block("FossilBlock", "Epic", Vector3.new(0, 1.5, -20))
site:SetAttribute("BlockId", 0)
site:SetAttribute("Zone", "Swamp")
site.Parent = workspace
env.advance(0.3)
local model = modelOf(site)
T.check(model ~= nil and model ~= false, "modèle construit")
if model then
	T.eq(model.Parent, folder, "modèle dans le dossier du client")
	T.eq(#bricks(model), BlockModels.Count("Epic", "Swamp"), "toutes les briques du bloc Epic et du décor du marais")
	T.check(#bricks(model, "Biome") > 0, "décor du biome posé")
	T.eq(model:GetAttribute("Form"), BlockModels.Biome("Swamp"), "forme du marais")
	T.eq(site.LocalTransparencyModifier, 1, "cube du serveur caché chez le client")
	T.eq(site.Transparency, 0, "transparence du serveur intacte")
	T.check(model:HasTag(Controller.Tag), "tag FossilBlockModel pour le module des auras")
	T.eq(model:GetAttribute("Rarity"), "Epic", "attribut Rarity")
	T.eq(model:GetAttribute("Zone"), "Swamp", "attribut Zone")
	T.eq(model:GetAttribute("Kind"), "FossilBlock", "attribut Kind")
	T.near(model:GetAttribute("Size"), BlockModels.SideOf("Epic", 3), 1e-6, "attribut Size : bloc Epic plus gros que le cube")
	-- plus gros que la pièce, mais posé au même sol : il grandit vers le haut
	T.near(bottom(model), site.Position.Y - 1.5, 0.05, "le bloc reste posé au sol")
	T.check((model.PrimaryPart.Position - (site.Position + Vector3.new(0, (BlockModels.SideOf("Epic", 3) - 3) / 2, 0))).Magnitude < 0.05, "Root au-dessus du centre de la pièce")
	local front = false
	for _, p in bricks(model, "Fossil") do
		if p.Position.Z < site.Position.Z - 1.5 then
			front = true
		end
	end
	T.check(front, "BlockId 0 : crâne vers -Z")
end

T.section("BlockId fait tourner le bloc")
site:SetAttribute("BlockId", 2)
env.advance(0.1)
model = modelOf(site)
if model then
	local back = false
	for _, p in bricks(model, "Fossil") do
		if p.Position.Z > site.Position.Z + 1.5 then
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
if model then
	local at = model.PrimaryPart.Position
	T.near(at.X, 10, 0.05, "modèle déplacé avec la pièce (X)")
	T.near(at.Z, -25, 0.05, "modèle déplacé avec la pièce (Z)")
	T.near(bottom(model), 0, 0.05, "toujours posé au sol")
end

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

T.section("rareté et biome qui changent, valeurs inconnues")
site:SetAttribute("Rarity", "Secret")
env.advance(0.3)
model = modelOf(site)
T.check(model and #bricks(model) == BlockModels.Count("Secret", "Swamp"), "Epic -> Secret : modèle refait")
local rainbow = model and bricks(model, "Rainbow")[1]
local colorBefore = rainbow and rainbow.Color
local light = model and model.PrimaryPart:FindFirstChildOfClass("PointLight")
local lightBefore = light and light.Color
env.advance(1)
T.check(rainbow ~= nil and rainbow.Color ~= colorBefore, "Secret : les couches changent de couleur")
T.check(light ~= nil and light.Color ~= lightBefore, "Secret : la lumière change de couleur")
site:SetAttribute("Zone", "Glacier")
env.advance(0.3)
model = modelOf(site)
T.check(model and model:GetAttribute("Zone") == "Glacier" and #bricks(model) == BlockModels.Count("Secret", "Glacier"), "zone changée : décor du glacier")
for _, bad in { "Nope", 42, "", true } do
	site:SetAttribute("Zone", bad)
	env.advance(0.3)
	model = modelOf(site)
	T.check(model and model:GetAttribute("Zone") == nil and #bricks(model, "Biome") == 0, "zone " .. T.show(bad) .. " : bloc sans décor")
end
for _, bad in { "Nope", 42, "", true, "secret" } do
	site:SetAttribute("Rarity", bad)
	env.advance(0.3)
	T.eq(modelOf(site), false, "rareté " .. T.show(bad) .. " : pas de modèle")
	T.eq(site.LocalTransparencyModifier, 0, "rareté " .. T.show(bad) .. " : cube du serveur visible")
end
site:SetAttribute("Rarity", "Mythic")
env.advance(0.3)
model = modelOf(site)
T.check(model and #bricks(model) == BlockModels.Count("Mythic"), "retour à une vraie rareté : refait")
local lava = model and bricks(model, "Glow")[1]
local seen, bright = {}, {}
local mythicLight = model and model.PrimaryPart:FindFirstChildOfClass("PointLight")
for _ = 1, 8 do
	env.advance(0.1)
	if lava then
		seen[string.format("%.2f", lava.Transparency)] = true
	end
	if mythicLight then
		bright[string.format("%.2f", mythicLight.Brightness)] = true
	end
end
local pulses, glows = 0, 0
for _ in seen do
	pulses += 1
end
for _ in bright do
	glows += 1
end
T.check(pulses > 2, "Mythic : la lave bat")
T.check(glows > 2, "Mythic : la lumière bat")

T.section("morceaux qui flottent (Mythic) et éclats qui tournent (Secret)")
local floating = block("DroppedFossil", "Mythic", Vector3.new(8, 1.5, -14))
floating:SetAttribute("Zone", "Canyon")
floating.Parent = workspace
env.advance(0.3)
local floatModel = modelOf(floating)
T.check(floatModel ~= nil and floatModel ~= false, "bloc Mythic construit")
if floatModel then
	local pieces = bricks(floatModel, "Float")
	T.check(#pieces >= 3, "morceaux qui flottent")
	local function heights(): { number }
		local out = {}
		for i, p in pieces do
			out[i] = p.Position.Y
		end
		return out
	end
	local h0 = heights()
	env.advance(0.4)
	local h1 = heights()
	local moved, together = 0, true
	for i, p in pieces do
		if math.abs(h1[i] - h0[i]) > 1e-3 then
			moved += 1
		end
		-- les briques d'un même morceau bougent ensemble
		for j, q in pieces do
			if j ~= i and p:GetAttribute("Float") == q:GetAttribute("Float") then
				together = together and math.abs((h1[i] - h0[i]) - (h1[j] - h0[j])) < 1e-4
			end
		end
	end
	T.eq(moved, #pieces, "les morceaux montent et descendent")
	T.check(together, "chaque morceau garde sa veine de lave")
	local bobMax = 0
	for i in pieces do
		bobMax = math.max(bobMax, math.abs(h1[i] - h0[i]))
	end
	T.check(bobMax < 0.3 * BlockModels.SideOf("Mythic", 3), "mouvement doux")
end
floating:SetAttribute("Rarity", "Secret")
env.advance(0.3)
local orbitModel = modelOf(floating)
if orbitModel then
	local shards = bricks(orbitModel, "Orbit")
	T.check(#shards >= 4, "éclats du Secret")
	local root = orbitModel.PrimaryPart.Position
	local function angle(p: any): number
		local d = p.Position - root
		return math.atan2(d.Z, d.X)
	end
	local before = angle(shards[1])
	local radius = Vector3.new(shards[1].Position.X - root.X, 0, shards[1].Position.Z - root.Z).Magnitude
	env.advance(0.5)
	T.check(math.abs(angle(shards[1]) - before) > 0.05, "les éclats tournent autour du bloc")
	T.near(Vector3.new(shards[1].Position.X - root.X, 0, shards[1].Position.Z - root.Z).Magnitude, radius, 0.02, "à la même distance")
end
floating:Destroy()
env.advance(0.1)

T.section("rareté posée après la pièce (cuve)")
local tank = block("TankBlock", nil, Vector3.new(-6, 4.5, -20), 2.5)
tank.Parent = workspace
env.advance(0.3)
T.eq(modelOf(tank), false, "sans rareté : rien")
tank:SetAttribute("Rarity", "Secret")
env.advance(0.3)
local tankModel = modelOf(tank)
T.check(tankModel ~= nil and tankModel ~= false, "rareté arrivée : construit")
if tankModel then
	T.near(tankModel:GetAttribute("Size"), 2.5 * BlockModels.TankScale, 1e-6, "bloc de cuve : borné pour tenir dans le verre")
	T.near((tankModel.PrimaryPart.Position - tank.Position).Magnitude, 0, 0.05, "bloc de cuve : centré dans la cuve")
end

T.section("bloc porté sur le dos")
local function carry(player: any, rarity: string): (any, any)
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	local part = block("CarriedFossil", rarity, root.Position + Vector3.new(0, 0.6, 1.6), 2.5)
	part.Anchored = false
	part.Massless = true
	part:SetAttribute("Zone", "Beach")
	part.Parent = player.Character
	return part, root
end
local carried = carry(other, "Legendary")
env.advance(0.3)
local carriedModel = modelOf(carried)
T.check(carriedModel ~= nil and carriedModel ~= false, "bloc porté habillé")
if carriedModel then
	T.eq(carriedModel:GetAttribute("Own"), false, "porté par un autre joueur")
	local back = false
	for _, p in bricks(carriedModel, "Fossil") do
		if p.Position.Z > carried.Position.Z + 1.2 then
			back = true
		end
	end
	T.check(back, "porté : crâne tourné vers l'arrière")
	-- plus gros que la pièce : il grandit vers le haut et l'arrière, pas dans le dos du joueur
	local grow = (BlockModels.SideOf("Legendary", 2.5) - 2.5) / 2
	local at = carriedModel.PrimaryPart.Position
	T.check(grow > 0, "porté : bloc Legendary plus gros que la pièce")
	T.near(at.Z, carried.Position.Z + grow, 0.05, "porté : il grandit vers l'arrière, pas dans le dos")
	T.near(at.Y, carried.Position.Y + grow, 0.05, "porté : il grandit vers le haut")
	T.near(bottom(carriedModel), carried.Position.Y - 1.25, 0.05, "porté : le bas ne bouge pas")
	-- le personnage court : la pièce soudée bouge sans signal CFrame (physique), le modèle suit à chaque image
	env.setProperty(carried, "CFrame", CFrame.new(carried.Position + Vector3.new(0, 0, -30)))
	env.advance(0.05)
	T.near(carriedModel.PrimaryPart.Position.Z, carried.Position.Z + grow, 0.05, "porté : le modèle suit la pièce")
end
local mine = carry(me, "Secret")
env.advance(0.3)
local mineModel = modelOf(mine)
T.check(mineModel ~= nil and mineModel ~= false and mineModel:GetAttribute("Own") == true, "son propre bloc : attribut Own")

T.section("point d'accroche des auras")
local calls, cleanups = {}, 0
Controller.SetAura(function(m: any, info: any)
	table.insert(calls, { Model = m, Info = info })
	return function()
		cleanups += 1
	end
end)
local built = 0
for _, m in Controller.Tracked() do
	if m then
		built += 1
	end
end
T.eq(#calls, built, "SetAura : appelée pour chaque modèle déjà construit")
local fresh = block("DroppedFossil", "Rare", Vector3.new(4, 1.5, -12))
fresh:SetAttribute("Zone", "Volcano")
fresh.Parent = workspace
env.advance(0.3)
local last = calls[#calls]
T.check(last and last.Model == modelOf(fresh), "nouveau modèle : aura appelée")
if last then
	T.eq(last.Info.Rarity, "Rare", "info : rareté")
	T.eq(last.Info.Zone, "Volcano", "info : zone")
	T.eq(last.Info.Kind, "DroppedFossil", "info : sorte de bloc")
	T.near(last.Info.Size, BlockModels.SideOf("Rare", 3), 1e-6, "info : taille")
	T.eq(last.Info.Part, fresh, "info : pièce du serveur")
end
local before = cleanups
fresh:Destroy()
env.advance(0.1)
T.eq(cleanups, before + 1, "modèle défait : nettoyage de l'aura")
Controller.SetAura(function()
	error("aura en panne")
end)
local broken = block("DroppedFossil", "Epic", Vector3.new(-4, 1.5, -12))
broken.Parent = workspace
env.advance(0.3)
T.check(modelOf(broken) ~= false and modelOf(broken) ~= nil, "aura qui plante : le bloc est quand même construit")
Controller.SetAura(nil)
T.eq(cleanups, before + 1 + built, "SetAura(nil) : nettoie les auras branchées")
env.errors = {}

T.section("la pièce part : modèle défait")
local count = #folder:GetChildren()
carried:Destroy()
env.advance(0.1)
T.eq(modelOf(carried), nil, "pièce détruite : plus suivie")
T.check(#folder:GetChildren() < count, "pièce détruite : modèle retiré")
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
T.eq(#CollectionService:GetTagged(Controller.Tag), #folder:GetChildren(), "chaque modèle construit porte le tag")

T.eq(#env.errors, 0, "aucune erreur")
T.done("blocks_client")
