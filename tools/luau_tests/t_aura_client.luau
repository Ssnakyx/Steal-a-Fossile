-- Auras de rareté (src/client/Aura) : cercles magiques des dinos (DinoAnimController) et des blocs de fossiles
-- (AuraController, branché sur FossilBlockController.SetAura). Ce que montre chaque rareté, l'aura qui suit sa cible,
-- niveau de détail selon la distance, contours et lumières prêtés (plafonnés), onde de choc, ViewportFrame, nettoyage ;
-- valeurs hostiles (rareté inconnue, rien pour placer l'aura, pivot qui plante, tailles absurdes).
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3, CFrame, Instance = env.Vector3, env.CFrame, env.Instance
local workspace = env.game:GetService("Workspace")

local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
local other = env.addPlayer({ Name = "Other", Character = true })
env.setSide("client", me)
local Aura = env.module("src/client/Aura")
local DinoBuilder = env.module("src/shared/DinoBuilder")
local BlockModels = env.module("src/shared/BlockModels")
local camera = workspace.CurrentCamera
camera.CFrame = CFrame.new(0, 12, 40)

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local function holder(name: string, position: any): (any, any)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = workspace
	return model, root
end

local function count(inst: any, class: string, name: string?): number
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA(class) and (name == nil or d.Name == name) then
			n += 1
		end
	end
	return n
end

local function find(inst: any, class: string, name: string): any
	for _, d in inst:GetDescendants() do
		if d:IsA(class) and d.Name == name then
			return d
		end
	end
	return nil
end

local function guisEnabled(part: any): boolean
	for _, g in part:GetChildren() do
		if g:IsA("SurfaceGui") and not g.Enabled then
			return false
		end
	end
	return true
end

T.section("ce que montre chaque rareté")
local handles, models, roots = {}, {}, {}
local start = Aura.Count()
local lastRank = 0
for i, rarity in RARITIES do
	local model, root = holder(rarity, Vector3.new((i - 4) * 12, 0.5, 0))
	local handle = Aura.Attach(model, {
		Rarity = rarity,
		Radius = 3,
		Height = 5,
		Root = root,
		Top = function()
			return root.Position + Vector3.new(0, 5, 0)
		end,
	})
	handles[rarity], models[rarity], roots[rarity] = handle, model, root
	T.check(handle ~= nil, rarity .. " : aura posée")
	T.check(Aura.Has(rarity), rarity .. " : rareté connue")
	T.check(Aura.Rank(rarity) > lastRank, rarity .. " : rang croissant")
	lastRank = Aura.Rank(rarity)
	local tier = Aura.Tiers[rarity]
	local folder = model:FindFirstChild("Aura")
	T.check(folder ~= nil and folder:IsA("Folder"), rarity .. " : dossier Aura dans le modèle")
	if folder then
		local circle = folder:FindFirstChild("Circle")
		T.check(circle ~= nil and count(circle, "SurfaceGui") == 1, rarity .. " : cercle magique au sol")
		T.check(circle ~= nil and count(circle, "UIStroke") >= tier.Rings, rarity .. " : anneaux du cercle")
		T.eq(circle and count(circle, "TextLabel", "Rune"), tier.Runes, rarity .. " : runes du cercle au sol")
		T.eq(count(folder, "BasePart", "HeadCircle"), tier.Halos, rarity .. " : cercles au-dessus de la tête")
		T.eq(count(folder, "BasePart", "Comet"), tier.Orbiters, rarity .. " : comètes")
		T.eq(count(folder, "Beam", "Pillar"), if tier.Pillar then 1 else 0, rarity .. " : rayon de lumière")
		T.eq(find(folder, "ParticleEmitter", "Flames") ~= nil, tier.Flames > 0, rarity .. " : flammes")
		T.eq(find(folder, "ParticleEmitter", "Haze") ~= nil, tier.Haze > 0, rarity .. " : brume autour du corps")
		T.eq(find(folder, "ParticleEmitter", "Glow") ~= nil, tier.Glow > 0, rarity .. " : lueur au sol")
		local ribbons = count(folder, "Beam", "Veil")
		T.eq(ribbons > 0, tier.Veil > 0, rarity .. " : voile d'énergie autour du corps")
		if tier.Veil > 0 then
			T.check(ribbons >= 8 and ribbons <= 20, rarity .. " : rubans du voile (" .. ribbons .. ")")
			T.eq(count(folder, "Beam", "Wisp"), ribbons // 2, rarity .. " : une volute sur deux rubans")
			local tallest = 0
			for _, b in folder:GetDescendants() do
				if b:IsA("Beam") and b.Name == "Veil" then
					tallest = math.max(tallest, b.Attachment1.Position.Y)
					T.check(not b.FaceCamera, rarity .. " : ruban posé autour du corps (pas tourné vers la caméra)")
					break
				end
			end
			T.check(tallest > 0.5 and tallest <= 5 * tier.Veil * 1.25 + 0.01, rarity .. " : hauteur du voile")
		end
		T.check(find(folder, "ParticleEmitter", "Motes") ~= nil, rarity .. " : poussière lumineuse")
		for _, p in folder:GetDescendants() do
			if p:IsA("BasePart") and (p.CanCollide or p.CanQuery or p.CanTouch or not p.Anchored) then
				T.check(false, rarity .. " : pièce " .. p.Name .. " sans collision ni requête, ancrée")
				break
			end
		end
	end
end
T.eq(Aura.Count(), start + #RARITIES, "7 auras actives")
T.check(Aura.Tiers.Mythic.Shock > 0 and Aura.Tiers.Secret.Rainbow, "onde de choc Mythic, arc-en-ciel Secret")
env.advance(0.5)
T.clean("aucune erreur dans la boucle des auras")

T.section("l'aura suit sa cible")
local secret, secretRoot = models.Secret, roots.Secret
local circle = secret.Aura.Circle
T.near(circle.Position.X, secretRoot.Position.X, 0.01, "cercle sous la pièce suivie")
T.near(circle.Position.Y, secretRoot.Position.Y, 0.2, "cercle au sol (un peu au-dessus)")
secretRoot.CFrame = CFrame.new(secretRoot.Position + Vector3.new(6, 0, -4))
env.advance(0.1)
T.near(circle.Position.X, secretRoot.Position.X, 0.01, "cercle déplacé avec la pièce (X)")
T.near(circle.Position.Z, secretRoot.Position.Z, 0.01, "cercle déplacé avec la pièce (Z)")
env.advance(1)
local lowest = math.huge
for _, p in secret.Aura:GetChildren() do
	if p.Name == "HeadCircle" then
		lowest = math.min(lowest, p.Position.Y)
		T.near(p.Position.X, secretRoot.Position.X, 0.6, "cercle de tête au-dessus de la tête")
	end
end
T.check(lowest > secretRoot.Position.Y + 5, "cercles de tête au-dessus du haut de la tête")
local pillarRoot = secret.Aura:FindFirstChild("PillarRoot")
T.check(pillarRoot ~= nil and pillarRoot.Position.Y > lowest, "rayon de lumière posé sur le dernier cercle")

T.section("niveau de détail")
local common = models.Common.Aura
camera.CFrame = CFrame.new(0, 12, 3000)
env.advance(0.3)
T.check(not guisEnabled(common.Circle), "loin : cercle caché")
T.eq(find(common, "ParticleEmitter", "Motes").Enabled, false, "loin : plus de particules")
local secretPillar = find(secret.Aura, "Beam", "Pillar")
T.eq(secretPillar.Enabled, false, "au-delà de la portée : rayon caché")
local secretVeil, secretWisp = find(secret.Aura, "Beam", "Veil"), find(secret.Aura, "Beam", "Wisp")
T.eq(secretVeil.Enabled, false, "loin : voile caché")
-- mi-distance (Secret, cercle de 3 studs : portée 380 x 0,875 ; entre 38 % et 70 %)
camera.CFrame = CFrame.new(roots.Secret.Position + Vector3.new(0, 0, 0.5 * 380 * 0.875))
env.advance(0.3)
T.eq(secretVeil.Enabled, true, "mi-distance : voile visible")
T.eq(secretWisp.Enabled, false, "mi-distance : volutes cachées")
camera.CFrame = CFrame.new(0, 12, 40)
env.advance(0.3)
T.check(guisEnabled(common.Circle), "de près : cercle visible")
T.eq(secretPillar.Enabled, true, "de près : rayon visible")
T.eq(find(secret.Aura, "ParticleEmitter", "Motes").Enabled, true, "de près : particules")
T.eq(secretWisp.Enabled, true, "de près : volutes du voile")

T.section("voile qui suit sa cible")
local veilFoot = secret.Aura:FindFirstChild("Veil")
T.check(veilFoot ~= nil, "pied du voile")
local turned = CFrame.new(roots.Secret.Position + Vector3.new(-2, 0, 3)) * CFrame.Angles(0, math.rad(60), 0)
roots.Secret.CFrame = turned
env.advance(0.1)
T.near((veilFoot.Position - turned.Position).Magnitude, 0, 0.01, "voile déplacé avec la pièce")
T.near(veilFoot.CFrame.LookVector:Dot(turned.LookVector), 1, 0.001, "voile tourné comme la pièce")

T.section("onde de choc")
local motes = find(secret.Aura, "ParticleEmitter", "Motes")
local emitted = env.particlesEmitted[motes] or 0
Aura.Pulse(handles.Secret)
T.check((env.particlesEmitted[motes] or 0) > emitted, "Pulse : gerbe d'étincelles")
env.advance(0.3)
local shockRing = find(secret.Aura, "Frame", "Shock")
T.check(shockRing ~= nil, "onde de choc dessinée dans le cercle")

T.section("contours et lumières prêtés")
local crowd = {}
for k = 1, 12 do
	local model, root = holder("Crowd" .. k, Vector3.new(-30 + k * 5, 0.5, 20))
	table.insert(crowd, Aura.Attach(model, { Rarity = "Mythic", Radius = 2, Height = 4, Root = root }))
end
env.advance(0.6)
local outlinesUsed = count(workspace, "Highlight", "AuraOutline")
local lightsUsed = count(workspace, "PointLight", "AuraLight")
T.check(outlinesUsed > 0 and outlinesUsed <= 6, "contours : au plus 6 (" .. outlinesUsed .. ")")
T.check(lightsUsed > 0 and lightsUsed <= 8, "lumières : au plus 8 (" .. lightsUsed .. ")")
for _, h in crowd do
	Aura.Detach(h)
end
for _, rarity in RARITIES do
	Aura.Detach(handles[rarity])
	T.eq(models[rarity]:FindFirstChild("Aura"), nil, rarity .. " : Detach enlève le dossier")
end
Aura.Detach(handles.Common) -- deux fois : sans effet
env.advance(0.3)
T.eq(count(workspace, "Highlight", "AuraOutline"), 0, "contours rendus au réservoir")
T.eq(count(workspace, "PointLight", "AuraLight"), 0, "lumières rendues au réservoir")
T.eq(Aura.Count(), start, "plus d'aura active")

T.section("ViewportFrame et bloc porté")
local vpModel, vpRoot = holder("Viewport", Vector3.new(0, 0.5, 60))
local vp = Aura.Attach(vpModel, { Rarity = "Legendary", Radius = 3, Height = 5, Root = vpRoot, Viewport = true })
T.check(vp ~= nil, "aura de ViewportFrame posée")
T.eq(count(vpModel, "SurfaceGui"), 0, "ViewportFrame : pas de SurfaceGui (pas rendues)")
T.eq(count(vpModel, "ParticleEmitter"), 0, "ViewportFrame : pas de particules (pas rendues)")
T.eq(count(vpModel, "Beam"), 0, "ViewportFrame : ni voile ni rayon (Beam pas rendus)")
T.check(count(vpModel, "BasePart", "Ring") >= 12, "ViewportFrame : anneau de briques")
local airModel, airRoot = holder("Carried", Vector3.new(10, 4, 60))
local air = Aura.Attach(airModel, { Rarity = "Mythic", Radius = 2.5, Height = 2.5, Root = airRoot, Ground = false })
T.check(air ~= nil, "aura sans sol posée")
T.eq(airModel.Aura:FindFirstChild("Circle"), nil, "sans sol : pas de cercle")
T.eq(find(airModel, "ParticleEmitter", "Flames"), nil, "sans sol : pas de flammes")
T.check(find(airModel, "ParticleEmitter", "Motes") ~= nil, "sans sol : poussière lumineuse")
airModel:Destroy()
env.advance(0.1)
T.eq(Aura.Count(), start + 1, "modèle détruit : son aura part toute seule")
Aura.Detach(vp :: any)

T.section("comètes hors de l'écran, rayon de loin")
-- caméra qui ne voit rien (le faux Camera voit tout d'habitude)
local function cameraSees(seen: boolean)
	env.stubMethod("Camera", "WorldToViewportPoint", function(_, position)
		return Vector3.new(position.X, position.Y, 0), seen
	end)
end
cameraSees(false)
local offModel, offRoot = holder("OffScreen", Vector3.new(40, 0.5, 80))
local off = Aura.Attach(offModel, { Rarity = "Legendary", Radius = 3, Height = 5, Root = offRoot })
env.advance(0.2)
local comets = {}
for _, d in offModel.Aura:GetChildren() do
	if d.Name == "Comet" then
		table.insert(comets, d)
	end
end
T.eq(#comets, Aura.Tiers.Legendary.Orbiters, "comètes créées")
local function cometsState(): (number, number)
	local shown, near = 0, 0
	for _, c in comets do
		local trail = c:FindFirstChildOfClass("Trail")
		if c.Transparency < 1 or (trail and trail.Enabled) then
			shown += 1
		end
		if (c.Position - offRoot.Position).Magnitude < 6 then
			near += 1
		end
	end
	return shown, near
end
local shown = cometsState()
T.eq(shown, 0, "aura posée hors de l'écran : comètes cachées (pas à l'origine du monde)")
cameraSees(true)
env.advance(env.frame)
local shown1, near1 = cometsState()
T.eq(shown1, 0, "de retour à l'écran : comètes d'abord placées, encore cachées (pas de traînée depuis l'origine)")
T.eq(near1, #comets, "comètes placées autour du corps")
env.advance(env.frame)
local shown2, near2 = cometsState()
T.eq(shown2, #comets, "image suivante : comètes visibles")
T.eq(near2, #comets, "comètes visibles autour du corps")
cameraSees(false)
env.advance(env.frame)
T.eq((cometsState()), 0, "sortie de l'écran : comètes cachées")
cameraSees(true)
Aura.Detach(off :: any)
-- posée de loin (LOD 2 : cercles de tête cachés) : le pied du rayon est quand même au-dessus de la tête
local farModel, farRoot = holder("Far", Vector3.new(0, 0.5, -160))
local far = Aura.Attach(farModel, {
	Rarity = "Legendary",
	Radius = 3,
	Height = 5,
	Root = farRoot,
	Top = function(): any
		return farRoot.Position + Vector3.new(0, 5, 0)
	end,
})
env.advance(0.2)
local farPillarRoot = farModel.Aura:FindFirstChild("PillarRoot")
T.check(farPillarRoot ~= nil, "Legendary avec tête : pied du rayon")
if farPillarRoot then
	T.near(farPillarRoot.Position.Z, farRoot.Position.Z, 0.1, "de loin : pied du rayon au-dessus du dino (pas à l'origine)")
	T.check(farPillarRoot.Position.Y > farRoot.Position.Y + 5, "de loin : pied du rayon au-dessus de la tête")
end
T.eq(find(farModel, "Beam", "Pillar").Enabled, true, "de loin : rayon visible")
T.check(not guisEnabled(farModel.Aura:FindFirstChild("HeadCircle")), "de loin : cercles de tête cachés")
Aura.Detach(far :: any)
T.clean("comètes et rayon : aucune erreur")

T.section("valeurs hostiles")
local badModel, badRoot = holder("Bad", Vector3.new(0, 0.5, 80))
T.eq(Aura.Attach(badModel, { Rarity = "Nope", Radius = 3, Height = 5, Root = badRoot }), nil, "rareté inconnue : rien")
T.eq(Aura.Attach(badModel, { Rarity = "Epic", Radius = 3, Height = 5 }), nil, "ni Pivot ni Root : rien")
T.eq(Aura.Has("Nope"), false, "Has : rareté inconnue")
T.eq(Aura.Rank("Nope"), 0, "Rank : rareté inconnue")
local boom = Aura.Attach(badModel, {
	Rarity = "Secret",
	Radius = 0 / 0,
	Height = math.huge,
	Pivot = function(): any
		error("pivot en panne")
	end,
	Top = function(): any
		return "pas un Vector3"
	end,
})
T.check(boom ~= nil, "pivot qui plante : aura posée quand même")
local huge = Aura.Attach(badModel, { Rarity = "Rare", Radius = 1e9, Height = -5, Root = badRoot })
T.check(huge ~= nil, "taille absurde : aura posée")
if huge then
	local c = badModel.Aura:FindFirstChild("Circle")
	T.check(c ~= nil and c.Size.X <= 300, "taille absurde : cercle borné")
end
env.advance(0.5)
T.clean("valeurs hostiles : aucune erreur")
Aura.Detach(boom :: any)
Aura.Detach(huge :: any)

T.section("dinos : DinoAnimController")
local DinoAnimController = env.module("src/client/Controllers/DinoAnimController")
DinoAnimController.Init()
DinoAnimController.Start()
-- arrivée d'un dino tagué dans le jeu (comme un modèle répliqué : le tag compte quand il entre dans le DataModel)
local function arrive(model: any, position: any)
	model:RemoveTag("Dino")
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	model:AddTag("Dino")
	env.advance(0.2)
end
local dino = DinoBuilder.Build("Velociraptor", { Size = "Normal", Rarity = "Legendary" })
arrive(dino, Vector3.new(0, 0.5, 10))
local dinoAura = dino:FindFirstChild("Aura")
T.check(dinoAura ~= nil, "dino Legendary : aura")
T.eq(dino:FindFirstChild("RarityFx"), nil, "anciens effets de rareté remplacés")
T.eq(count(dino, "BasePart", "HeadCircle"), 1, "Legendary : un cercle au-dessus de la tête")
local head = -math.huge
for _, p in dino:GetChildren() do
	if p:IsA("BasePart") and p:GetAttribute("Bone") == "Head" then
		head = math.max(head, p.Position.Y + p.Size.Y / 2)
	end
end
env.advance(1)
local halo = dinoAura and dinoAura:FindFirstChild("HeadCircle")
T.check(halo ~= nil and halo.Position.Y > head, "cercle au-dessus du haut de la tête")
dino:SetAttribute("Rarity", "Secret")
env.advance(0.2)
T.eq(count(dino, "BasePart", "HeadCircle"), 3, "rareté changée : aura refaite (Secret, 3 cercles)")
local dinoMotes = find(dino, "ParticleEmitter", "Motes")
local before = env.particlesEmitted[dinoMotes] or 0
dino:SetAttribute("State", "Spawn")
dino:SetAttribute("StateAt", workspace:GetServerTimeNow())
env.advance(0.1)
T.check((env.particlesEmitted[dinoMotes] or 0) > before, "réanimation (Spawn) : onde de choc")
before = env.particlesEmitted[dinoMotes] or 0
dino:SetAttribute("StateAt", workspace:GetServerTimeNow())
env.advance(0.1)
T.eq(env.particlesEmitted[dinoMotes] or 0, before, "State puis StateAt l'un après l'autre : une seule onde")
dino:SetAttribute("StateAt", workspace:GetServerTimeNow() - 30)
dino:SetAttribute("State", "Fusion")
env.advance(0.1)
T.eq(env.particlesEmitted[dinoMotes] or 0, before, "état commencé depuis longtemps : pas d'onde")
env.advance(1)
dino:SetAttribute("StateAt", workspace:GetServerTimeNow())
env.advance(0.1)
T.check((env.particlesEmitted[dinoMotes] or 0) > before, "fusion qui commence : onde de choc")
dino:RemoveTag("Dino")
env.advance(0.1)
T.eq(dino:FindFirstChild("Aura"), nil, "tag enlevé : aura enlevée")
local guardian = DinoBuilder.Build("Velociraptor", { Size = "Normal", Rarity = "Mythic" })
guardian:AddTag("Guardian")
arrive(guardian, Vector3.new(20, 0.5, 10))
T.check(guardian:FindFirstChild("Root") ~= nil or #guardian:GetChildren() > 0, "gardien construit")
T.eq(guardian:FindFirstChild("Aura"), nil, "gardien : pas d'aura")
local preview = DinoBuilder.Build("Velociraptor", { Size = "Normal", Rarity = "Epic" })
preview:SetAttribute("AlwaysAnimate", true)
arrive(preview, Vector3.new(-20, 0.5, 10))
T.check(count(preview, "BasePart", "Ring") >= 12 and count(preview, "SurfaceGui") == 0, "aperçu (AlwaysAnimate) : anneau de briques")
T.clean("dinos : aucune erreur")

T.section("blocs de fossiles : AuraController")
local FossilBlockController = env.module("src/client/Controllers/FossilBlockController")
local AuraController = env.module("src/client/Controllers/AuraController")
FossilBlockController.Init()
FossilBlockController.Start()
AuraController.Start()
camera.CFrame = CFrame.new(0, 5, 0)
local function block(name: string, rarity: string, position: any, size: number?, parent: any?): any
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = parent == nil
	part.CanCollide = false
	part.Size = Vector3.new(size or 3, size or 3, size or 3)
	part.CFrame = CFrame.new(position)
	part:SetAttribute("Rarity", rarity)
	part:SetAttribute("Zone", "Beach")
	part.Parent = parent or workspace
	return part
end
local function blockModel(part: any): any
	local m = FossilBlockController.Tracked()[part]
	return if m then m else nil
end
-- Distance au centre des pieds des rubans du voile (la plus petite et la plus grande) et hauteur du plus haut
local function veilShape(model: any): (number, number, number)
	local near, far, top = math.huge, 0, 0
	for _, b in model:GetDescendants() do
		if b:IsA("Beam") and b.Name == "Veil" then
			local foot = b.Attachment0.Position
			local r = Vector3.new(foot.X, 0, foot.Z).Magnitude
			near, far = math.min(near, r), math.max(far, r)
			top = math.max(top, b.Attachment1.Position.Y)
		end
	end
	return near, far, top
end
local site = block("FossilBlock", "Epic", Vector3.new(0, 1.5, -20))
local dropped = block("DroppedFossil", "Mythic", Vector3.new(8, 1.5, -20))
local plain = block("FossilBlock", "Common", Vector3.new(-8, 1.5, -20))
local tank = block("TankBlock", "Legendary", Vector3.new(16, 4.9, -20), 2.5)
local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
local theirs = block("CarriedFossil", "Mythic", otherRoot.Position + Vector3.new(0, 0.6, 1.6), 2.5, other.Character)
local myRoot = me.Character:FindFirstChild("HumanoidRootPart")
local mine = block("CarriedFossil", "Secret", myRoot.Position + Vector3.new(0, 0.6, 1.6), 2.5, me.Character)
env.advance(0.5)
local siteModel = blockModel(site)
T.check(siteModel ~= nil and siteModel:FindFirstChild("Aura") ~= nil, "bloc de gisement : aura")
if siteModel then
	local c = siteModel.Aura:FindFirstChild("Circle")
	T.check(c ~= nil, "bloc de gisement : cercle au sol")
	T.near(c.Position.Y, site.Position.Y - 1.5, 0.2, "cercle au bas du bloc (pas de sol trouvé)")
	T.check(c.Size.X > BlockModels.SideOf("Epic", 3) * 1.42, "cercle plus large que la diagonale du bloc")
	T.eq(find(siteModel, "PointLight", "AuraLight") ~= nil, true, "Epic : lumière colorée de l'aura (le bloc n'en a pas)")
	T.check(find(siteModel, "Beam", "Veil") ~= nil, "bloc de gisement : voile d'énergie autour du bloc")
	local side = BlockModels.SideOf("Epic", 3)
	local near, _, top = veilShape(siteModel)
	T.check(near > side * 0.71, "voile du bloc : au-delà des coins du bloc (pas caché dedans)")
	T.check(near < c.Size.X / 2, "voile du bloc : sur le cercle au sol")
	T.check(top > side, "voile du bloc : plus haut que le bloc (il ressort au-dessus)")
end
local droppedModel = blockModel(dropped)
T.check(droppedModel ~= nil and droppedModel.Aura:FindFirstChild("Circle") ~= nil, "bloc lâché : cercle au sol")
T.check(droppedModel ~= nil and find(droppedModel, "ParticleEmitter", "Flames") ~= nil, "bloc Mythic lâché : flammes")
T.check(droppedModel ~= nil and find(droppedModel, "PointLight", "AuraLight") == nil, "Mythic : pas de 2e lumière (le bloc a la sienne)")
local plainModel = blockModel(plain)
T.check(plainModel ~= nil and plainModel:FindFirstChild("Aura") == nil, "bloc Common : pas d'aura (GDD)")
local tankModel = blockModel(tank)
T.check(tankModel ~= nil and tankModel:FindFirstChild("Aura") ~= nil, "bloc de cuve : aura")
T.check(tankModel ~= nil and tankModel.Aura:FindFirstChild("Circle") == nil, "bloc de cuve : pas de cercle (verre)")
T.check(tankModel ~= nil and find(tankModel, "Beam", "Pillar") ~= nil, "bloc de cuve Legendary : rayon par le couvercle")
if tankModel then
	-- (verre de 5 x 7 x 5 studs centré sur le bloc)
	local tankSide = BlockModels.SideOf("Legendary", 2.5, "TankBlock")
	local _, far, top = veilShape(tankModel)
	T.check(far > 0 and far <= 2.31, "voile du bloc de cuve : dans le verre")
	T.check(top > 0 and top <= 3.5 + tankSide / 2, "voile du bloc de cuve : sous le couvercle")
end
local theirModel = blockModel(theirs)
T.check(theirModel ~= nil and theirModel:FindFirstChild("Aura") ~= nil, "bloc porté par un autre : aura")
T.check(theirModel ~= nil and theirModel.Aura:FindFirstChild("Circle") == nil, "bloc porté : pas de cercle")
T.check(theirModel ~= nil and find(theirModel, "Beam", "Pillar") ~= nil, "bloc porté par un autre : rayon qui le suit")
local myModel = blockModel(mine)
T.check(myModel ~= nil and myModel:FindFirstChild("Aura") ~= nil, "son propre bloc : aura")
T.check(myModel ~= nil and find(myModel, "Beam", "Pillar") == nil, "son propre bloc : pas de rayon devant la caméra")
T.check(myModel ~= nil and find(myModel, "Beam", "Veil") == nil, "son propre bloc : pas de voile devant la caméra")
T.check(theirModel ~= nil and find(theirModel, "Beam", "Veil") ~= nil, "bloc porté par un autre : voile")
T.eq(myModel and count(myModel, "BasePart", "Comet"), math.floor(Aura.Tiers.Secret.Orbiters * 0.45 + 0.5), "son propre bloc : moins de comètes")
local auras = Aura.Count()
dropped:Destroy()
env.advance(0.2)
T.eq(Aura.Count(), auras - 1, "bloc ramassé : aura enlevée")
T.clean("blocs : aucune erreur")

T.done("aura_client")
