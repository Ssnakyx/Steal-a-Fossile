-- Blocs de fossiles (brief 9) : BlockModels. Un modèle voxel par biome et par rareté (models/blocks/build.py
-- --export) : une forme par biome, aucun bloc pareil à un autre, la couleur de Config.Rarity, au budget, posé au sol ;
-- les raretés hautes plus grosses et lumineuses, avec leurs signes (coeur, socle d'or, lave, morceaux qui flottent,
-- lévitation). Appels hostiles : raretés et zones inconnues, tailles absurdes.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3 = env.Vector3
local Enum = env.Enum
local CFrame = env.CFrame

local BlockModels = env.module("src/shared/BlockModels")
local Rarity = env.module("src/shared/Config/Rarity")
local Zones = env.module("src/shared/Config/Zones")

local BUDGET = 116 -- pièces au plus par bloc, pièce Root comprise (models/blocks/blocks.py : 115 boîtes)

local function colorGap(a: any, b: any): number
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

local function straight(p: any): boolean
	local r = p.CFrame.Rotation
	return (r.XVector - Vector3.new(1, 0, 0)).Magnitude < 1e-4 and (r.YVector - Vector3.new(0, 1, 0)).Magnitude < 1e-4
end

-- Étendue (min, max) des pièces de certains rôles (tous si nil), coins des pièces tournées compris
local function extent(model: any, roles: { [string]: boolean }?): (any, any)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Root" and (roles == nil or roles[p.Name]) then
			local half = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = p.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						lo = lo:Min(corner)
						hi = hi:Max(corner)
					end
				end
			end
		end
	end
	return lo, hi
end

-- Bas des pièces droites (non tournées) : le bas du bloc
local function bottom(model: any, roles: { [string]: boolean }?): number
	local low = math.huge
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Root" and (roles == nil or roles[p.Name]) and straight(p) then
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
		end
	end
	return low
end

local function rolesOf(model: any): { [string]: { any } }
	local out: { [string]: { any } } = {}
	for _, p in model:GetChildren() do
		out[p.Name] = out[p.Name] or {}
		table.insert(out[p.Name], p)
	end
	return out
end

-- Signature d'un modèle : ses briques (rôle, taille, position, couleur), triées
local function signature(model: any): string
	local rows = {}
	for _, p in model:GetChildren() do
		if p.Name ~= "Root" then
			local s, c, k = p.Size, p.Position, p.Color
			table.insert(rows, string.format("%s %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f", p.Name, s.X, s.Y, s.Z, c.X, c.Y, c.Z, k.R, k.G, k.B))
		end
	end
	table.sort(rows)
	return table.concat(rows, ";")
end

-- Silhouette d'un modèle : tailles et positions de ses briques de roche, sans les couleurs
local function silhouette(model: any): string
	local rows = {}
	for _, p in model:GetChildren() do
		if p.Name == "Rock" or p.Name == "Rainbow" then
			local s, c = p.Size, p.Position
			table.insert(rows, string.format("%.2f %.2f %.2f %.2f %.2f %.2f", s.X, s.Y, s.Z, c.X, c.Y, c.Z))
		end
	end
	table.sort(rows)
	return table.concat(rows, ";")
end

T.section("raretés de Config.Rarity, une forme par zone de Config.Zones")
T.eq(#BlockModels.Order, #Rarity.Order, "7 raretés")
for i, name in Rarity.Order do
	T.eq(BlockModels.Order[i], name, "ordre " .. name)
	T.check(BlockModels.Get(name) ~= nil, "cube sans biome " .. name)
	T.check(BlockModels.Looks[name] ~= nil, "apparence " .. name)
end
T.eq(#BlockModels.Biomes, #Zones.List, "une forme par zone")
local forms = {}
for _, zone in Zones.List do
	local form = BlockModels.Biome(zone.Name)
	T.check(type(form) == "string", "forme du biome " .. zone.Name .. " : " .. tostring(form))
	T.check(table.find(BlockModels.Biomes, zone.Name) ~= nil, "BlockModels.Biomes contient " .. zone.Name)
	T.check(form ~= nil and forms[form] == nil, zone.Name .. " : forme qu'aucune autre zone n'a")
	if form then
		forms[form] = true
	end
	for _, rarity in Rarity.Order do
		T.check(BlockModels.Get(rarity, zone.Name) ~= nil, zone.Name .. " " .. rarity .. " : modèle")
	end
end

T.section("modèles en briques : au sol, au budget, de la couleur de la rareté")
local zones: { any } = { false }
for _, zone in BlockModels.Biomes do
	table.insert(zones, zone)
end
local signatures, silhouettes = {}, {}
for _, zone in zones do
	local where = if zone then zone else nil
	local label = if zone then zone else "sans biome"
	local previousGems = -1
	for _, name in BlockModels.Order do
		local tag = label .. " " .. name
		local data = BlockModels.Get(name, where)
		local model = BlockModels.Build(name, 3, where)
		T.check(model ~= nil and model:IsA("Model"), tag .. " : Build donne un Model")
		if not (model and data) then
			continue
		end
		local count = BlockModels.Count(name, where)
		T.eq(#model:GetChildren(), count, tag .. " : une pièce par boîte, plus Root")
		T.check(count <= BUDGET, tag .. " : " .. count .. " pièces (budget " .. BUDGET .. ")")
		T.eq(model:GetAttribute("Rarity"), name, tag .. " : attribut Rarity")
		T.eq(model:GetAttribute("Zone"), where, tag .. " : attribut Zone")
		T.eq(model:GetAttribute("Form"), if where then BlockModels.Biome(where) else "Block", tag .. " : attribut Form")
		local root = model.PrimaryPart
		T.check(root ~= nil and root.Name == "Root" and root.Transparency == 1, tag .. " : pièce Root invisible (PrimaryPart)")
		T.check(root ~= nil and root.CFrame.Position.Magnitude < 1e-6, tag .. " : Root au centre de la grille")
		local loose = 0
		for _, p in model:GetChildren() do
			if not (p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch) then
				loose += 1
			end
		end
		T.eq(loose, 0, tag .. " : pièces ancrées, sans collision, requête ni contact")
		local roles = rolesOf(model)
		T.check(#(roles.Fossil or {}) >= 5, tag .. " : fossile en relief (" .. #(roles.Fossil or {}) .. " os)")
		-- posé au sol : le bas des pièces droites est à -1,5 (bas de la pièce du serveur)
		T.near(bottom(model), -1.5, 0.01, tag .. " : posé au sol")
		local lo, hi = extent(model)
		T.check(lo.Y > -1.75, tag .. " : rien ne s'enfonce loin dans le sol (" .. string.format("%.2f", lo.Y) .. ")")
		T.check(hi.Y < 3.6 and lo.X > -2.8 and hi.X < 2.8 and lo.Z > -2.8 and hi.Z < 2.8, tag .. " : tient autour de la pièce")
		-- cristaux : de plus en plus nombreux, avec leur numéro en attribut
		T.check(data.Gems >= previousGems, tag .. " : au moins autant de cristaux que la rareté d'avant")
		previousGems = data.Gems
		for _, p in roles.Gem or {} do
			local n = p:GetAttribute("Gem")
			T.check(type(n) == "number" and n >= 1 and n <= data.Gems, tag .. " : numéro de cristal")
		end
		-- couleur : la roche montre la rareté (Config.Rarity, celle des cubes du serveur et des anneaux des dinos)
		if name ~= "Secret" then
			local best = math.huge
			for _, p in roles.Rock or {} do
				if p.Size.Magnitude > 1.5 then
					best = math.min(best, colorGap(p.Color, Rarity.Info[name].Color))
				end
			end
			T.check(best < 0.6, tag .. " : roche de la couleur de la rareté (écart " .. string.format("%.2f", best) .. ")")
		end
		-- aucun bloc pareil à un autre
		local sig = signature(model)
		T.check(signatures[sig] == nil, tag .. " : différent de tous les autres blocs")
		signatures[sig] = true
		if name == "Common" then
			local sil = silhouette(model)
			T.check(silhouettes[sil] == nil, label .. " : silhouette différente de celle des autres biomes")
			silhouettes[sil] = true
		end
		model:Destroy()
	end
end

T.section("apparence : plus gros et plus lumineux avec la rareté")
local previous = nil
for _, name in BlockModels.Order do
	local look = BlockModels.Looks[name]
	T.eq(look.Name, name, name .. " : nom")
	T.eq(look.Rank, Rarity.Info[name].Rank, name .. " : rang")
	if previous then
		T.check(look.Scale > previous.Scale, name .. " : plus gros que la rareté d'avant")
		T.check(look.Light >= previous.Light, name .. " : au moins aussi lumineux que la rareté d'avant")
	end
	local model = BlockModels.Build(name, 3, "Beach")
	local light = model.PrimaryPart:FindFirstChildOfClass("PointLight")
	T.eq(light ~= nil, look.Light > 0, name .. " : PointLight seulement s'il brille")
	model:Destroy()
	previous = look
end
T.eq(BlockModels.Looks.Common.Scale, 1, "Common : taille de référence")
T.check(BlockModels.Looks.Secret.Scale >= 1.7, "Secret : presque deux fois plus gros")
T.check(BlockModels.Looks.Secret.Rainbow and BlockModels.Looks.Secret.Pulse, "Secret : arc-en-ciel et battement")

T.section("signes des raretés, dans chaque biome")
for _, zone in BlockModels.Biomes do
	local function build(name: string): (any, { [string]: { any } })
		local model = BlockModels.Build(name, 3, zone)
		return model, rolesOf(model)
	end
	local common, croles = build("Common")
	T.eq(croles.Gem, nil, zone .. " Common : pas de cristal")
	T.eq(croles.Glow, nil, zone .. " Common : rien qui brille")
	common:Destroy()
	local epic, eroles = build("Epic")
	T.check(eroles.Glow ~= nil and #eroles.Glow > 0, zone .. " Epic : coeur qui brille dans la fente")
	for _, p in eroles.Glow or {} do
		T.eq(p.Material, Enum.Material.Neon, zone .. " Epic : coeur en Neon")
	end
	local _, ehi = extent(epic, { Rock = true })
	epic:Destroy()
	local legendary, lroles = build("Legendary")
	T.check(lroles.Base ~= nil and #lroles.Base > 0, zone .. " Legendary : socle")
	for _, p in lroles.Base or {} do
		T.check(p.Material == Enum.Material.Foil and p.Color.R > 0.9 and p.Color.B < 0.5, zone .. " Legendary : socle en or")
	end
	local gold = 0
	for _, p in lroles.Fossil or {} do
		if p.Material == Enum.Material.Foil and p.Color.R > 0.9 and p.Color.B < 0.5 then
			gold += 1
		end
	end
	T.eq(gold, #(lroles.Fossil or {}), zone .. " Legendary : os en or (Foil)")
	T.check(bottom(legendary, { Rock = true }) > -1.5 + 0.1, zone .. " Legendary : posé sur son socle")
	legendary:Destroy()
	local mythic, mroles = build("Mythic")
	T.check(mroles.Glow ~= nil and #mroles.Glow > 0, zone .. " Mythic : fissures de lave")
	local floats = {}
	for _, p in mroles.Float or {} do
		floats[p:GetAttribute("Float")] = true
	end
	T.eq(#floats, 3, zone .. " Mythic : trois morceaux qui flottent (une brique et sa veine de lave chacun)")
	T.eq(BlockModels.Get("Mythic", zone).Floats, 3, zone .. " Mythic : Floats")
	local _, mtop = extent(mythic, { Rock = true })
	for _, p in mroles.Float or {} do
		T.check(type(p:GetAttribute("Float")) == "number", zone .. " Mythic : numéro du morceau")
		T.check(p.Position.Y > mtop.Y - 1.2, zone .. " Mythic : morceau en haut du bloc")
	end
	mythic:Destroy()
	local secret, sroles = build("Secret")
	local hues = {}
	for _, p in sroles.Rainbow or {} do
		hues[string.format("%.2f %.2f", p.Color.R, p.Color.G)] = true
	end
	local distinct = 0
	for _ in hues do
		distinct += 1
	end
	T.check(distinct >= 4, zone .. " Secret : couches arc-en-ciel (" .. distinct .. " couleurs)")
	local orbits = {}
	for _, p in sroles.Orbit or {} do
		orbits[p:GetAttribute("Orbit")] = true
	end
	T.eq(#orbits, 4, zone .. " Secret : quatre éclats qui tournent")
	T.eq(BlockModels.Get("Secret", zone).Orbits, 4, zone .. " Secret : Orbits")
	T.check(sroles.Base ~= nil, zone .. " Secret : pierres au sol")
	T.near(bottom(secret, { Base = true }), -1.5, 0.01, zone .. " Secret : pierres posées au sol")
	T.check(bottom(secret, { Rainbow = true }) > -1.5 + 0.5, zone .. " Secret : bloc en lévitation au-dessus des pierres")
	local pearl = 0
	for _, p in sroles.Fossil or {} do
		if p.Material == Enum.Material.Foil and p.Color.R > 0.9 and p.Color.B > 0.9 then
			pearl += 1
		end
	end
	T.eq(pearl, #(sroles.Fossil or {}), zone .. " Secret : os nacrés")
	for _, p in sroles.Gem or {} do
		T.eq(p.Material, Enum.Material.Neon, zone .. " Secret : cristaux en Neon")
	end
	secret:Destroy()
	T.check(ehi.Y > 0, zone .. " Epic : la roche monte encore au-dessus du centre")
end

T.section("taille en jeu")
T.near(BlockModels.SideOf("Common", 3), 3, 1e-6, "Common : la taille de la pièce")
T.near(BlockModels.SideOf("Secret", 3), 3 * BlockModels.Looks.Secret.Scale, 1e-6, "Secret : plus gros que la pièce")
T.near(BlockModels.SideOf("Secret", 2.5, "TankBlock"), 2.5 * BlockModels.TankScale, 1e-6, "dans une cuve : borné")
T.near(BlockModels.SideOf("Rare", 2.5, "TankBlock"), 2.5 * BlockModels.Looks.Rare.Scale, 1e-6, "cuve : les petites raretés gardent leur taille")
local side = BlockModels.SideOf("Mythic", 3)
local big = BlockModels.Build("Mythic", side, "Volcano")
T.near(bottom(big), -side / 2, 0.02, "Mythic construit plus gros, toujours au sol")
local blo, bhi = extent(big, { Rock = true })
T.check(bhi.Y - blo.Y > 3, "Mythic plus haut qu'un bloc Common")
local light = big.PrimaryPart:FindFirstChildOfClass("PointLight")
T.near(light.Range, BlockModels.Looks.Mythic.Range * BlockModels.Looks.Mythic.Scale, 1e-6, "portée de la lumière à l'échelle du bloc")
big:Destroy()
local small = BlockModels.Build("Rare", 2.5, "Canyon")
T.near(bottom(small), -1.25, 0.01, "bloc porté de 2,5 studs : bas à -1,25")
T.near(small:GetAttribute("Scale"), 2.5 / 3, 1e-6, "attribut Scale")
small:Destroy()
T.eq(CFrame.identity.Position.Magnitude, 0, "(repère)")

T.section("appels hostiles")
for _, bad in { nil, 0, -1, "", "Nope", "common", "Gem1", {}, true, 0 / 0, math.huge } do
	T.eq(BlockModels.Get(bad), nil, "Get(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Build(bad), nil, "Build(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Count(bad), 0, "Count(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Biome(bad), nil, "Biome(" .. T.show(bad) .. ")")
	local model = BlockModels.Build("Common", 3, bad)
	T.check(model ~= nil and model:GetAttribute("Zone") == nil and model:GetAttribute("Form") == "Block",
		"Build avec la zone " .. T.show(bad) .. " : cube sans biome")
	T.near(BlockModels.SideOf(bad, 3), 3, 1e-6, "SideOf(" .. T.show(bad) .. ") : taille de la pièce")
	if model then
		model:Destroy()
	end
end
for _, bad in { 0 / 0, -3, 0, math.huge, -math.huge, "3" } do
	local s = BlockModels.ScaleOf(bad :: any)
	T.check(s == s and s > 0 and s < 100, "ScaleOf(" .. T.show(bad) .. ") reste fini et positif")
	local sideOf = BlockModels.SideOf("Epic", bad :: any)
	T.check(sideOf == sideOf and sideOf > 0 and sideOf < 100, "SideOf(Epic, " .. T.show(bad) .. ") reste fini et positif")
	local model = BlockModels.Build("Common", bad :: any, "Swamp")
	T.check(model ~= nil, "Build avec une taille absurde : bloc quand même")
	if model then
		model:Destroy()
	end
end
T.eq(#env.errors, 0, "aucune erreur")

T.done("blocks_models")
