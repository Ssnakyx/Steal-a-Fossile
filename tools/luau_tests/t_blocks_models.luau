-- Blocs de fossiles (brief 9) : BlockModels. Un bloc voxel par rareté et un décor par biome (models/blocks/build.py
-- --export), de la couleur de Config.Rarity, au budget, à la bonne taille ; les raretés hautes plus grosses et
-- lumineuses. Appels hostiles : raretés et zones inconnues, tailles absurdes.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3 = env.Vector3
local Enum = env.Enum

local BlockModels = env.module("src/shared/BlockModels")
local Rarity = env.module("src/shared/Config/Rarity")
local Zones = env.module("src/shared/Config/Zones")

local BUDGET = 110 -- pièces au plus par bloc, décor du biome et pièce Root compris

local function colorGap(a: any, b: any): number
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

-- Étendue (min, max) des pièces d'un rôle, dans le repère du modèle (coins des pièces tournées compris)
local function extent(model: any, roles: { [string]: boolean }): (any, any)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and roles[p.Name] then
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

local ROCK = { Rock = true, Rainbow = true, Glow = true }

T.section("une rareté par bloc, dans l'ordre de Config.Rarity ; un décor par zone de Config.Zones")
T.eq(#BlockModels.Order, #Rarity.Order, "7 raretés")
for i, name in Rarity.Order do
	T.eq(BlockModels.Order[i], name, "ordre " .. name)
	T.check(BlockModels.Get(name) ~= nil, "modèle " .. name)
	T.check(BlockModels.Looks[name] ~= nil, "apparence " .. name)
end
T.eq(#BlockModels.Biomes, #Zones.List, "un décor par zone")
for _, zone in Zones.List do
	T.check(BlockModels.Biome(zone.Name) ~= nil, "décor du biome " .. zone.Name)
	T.check(table.find(BlockModels.Biomes, zone.Name) ~= nil, "BlockModels.Biomes contient " .. zone.Name)
end

T.section("modèles en briques")
local previousGems, previous = -1, nil
for _, name in BlockModels.Order do
	local data = BlockModels.Get(name)
	local model = BlockModels.Build(name)
	T.check(model ~= nil and model:IsA("Model"), name .. " : Build donne un Model")
	if not (model and data) then
		continue
	end
	T.eq(#model:GetChildren(), BlockModels.Count(name), name .. " : une pièce par boîte, plus Root")
	T.eq(model:GetAttribute("Rarity"), name, name .. " : attribut Rarity")
	local root = model.PrimaryPart
	T.check(root ~= nil and root.Name == "Root" and root.Transparency == 1, name .. " : pièce Root invisible (PrimaryPart)")
	T.check(root ~= nil and root.CFrame.Position.Magnitude < 1e-6, name .. " : Root au centre du bloc")
	local loose, roles = 0, {}
	for _, p in model:GetChildren() do
		if not (p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch) then
			loose += 1
		end
		roles[p.Name] = (roles[p.Name] or 0) + 1
	end
	T.eq(loose, 0, name .. " : pièces ancrées, sans collision, requête ni contact")
	T.check((roles.Fossil or 0) >= 20, name .. " : squelette en relief (" .. tostring(roles.Fossil) .. " os)")
	-- roche : un cube de 3 studs centré sur le pivot ; os juste au-dessus des faces ; cristaux au-dessus du dessus
	local lo, hi = extent(model, ROCK)
	T.near(lo.X, -1.5, 0.01, name .. " : roche à -1,5 en X")
	T.near(hi.Y, 1.5, 0.01, name .. " : dessus à 1,5")
	T.near(lo.Y, -1.5, 0.01, name .. " : dessous à -1,5")
	T.near(hi.Z, 1.5, 0.01, name .. " : roche à 1,5 en Z")
	local flo, fhi = extent(model, { Fossil = true })
	T.check(flo.Z < -1.5 and flo.Z > -1.8, name .. " : crâne en relief sur l'avant (-Z)")
	T.check(fhi.X > 1.5 and fhi.X < 1.8 and flo.X < -1.5 and flo.X > -1.8, name .. " : os en relief sur les flancs")
	T.check(fhi.Y < 1.5, name .. " : rien sur le dessus (studs et cristaux)")
	if (roles.Gem or 0) > 0 then
		local glo, ghi = extent(model, { Gem = true })
		T.check(ghi.Y > 1.9 and ghi.Y < 3.2, name .. " : cristaux au-dessus du bloc")
		T.check(glo.Y > 0.9, name .. " : base des cristaux dans le dessus de la roche")
		T.check((glo.Z + ghi.Z) / 2 < 0.6, name .. " : cristaux surtout sur la moitié avant du dessus")
		T.check(glo.X > -2 and ghi.X < 2 and glo.Z > -2, name .. " : cristaux au-dessus du bloc, pas à côté")
	end
	T.check(data.Gems >= previousGems, name .. " : au moins autant de cristaux que la rareté d'avant")
	previousGems = data.Gems
	-- couleur : la roche montre la rareté (Config.Rarity, celle des cubes du serveur et des anneaux des dinos)
	if name ~= "Secret" then
		local best = math.huge
		for _, p in model:GetChildren() do
			if p.Name == "Rock" and p.Size.Magnitude > 3 then
				best = math.min(best, colorGap(p.Color, Rarity.Info[name].Color))
			end
		end
		T.check(best < 0.4, name .. " : roche de la couleur de la rareté (écart " .. string.format("%.2f", best) .. ")")
		local studs = 0
		for _, p in model:GetChildren() do
			if p.Name == "Rock" and p.TopSurface == Enum.SurfaceType.Studs then
				studs += 1
			end
		end
		T.check(studs > 0, name .. " : studs sur le dessus de la roche")
	end
	-- apparence : plus grosse et plus lumineuse avec la rareté
	local look = BlockModels.Looks[name]
	T.eq(look.Name, name, name .. " : nom")
	T.eq(look.Rank, Rarity.Info[name].Rank, name .. " : rang")
	if previous then
		T.check(look.Scale > previous.Scale, name .. " : plus gros que la rareté d'avant")
		T.check(look.Light >= previous.Light, name .. " : au moins aussi lumineux que la rareté d'avant")
	end
	local light = if root then root:FindFirstChildOfClass("PointLight") else nil
	T.eq(light ~= nil, look.Light > 0, name .. " : PointLight seulement s'il brille")
	previous = look
	model:Destroy()
end
T.eq(BlockModels.Looks.Common.Scale, 1, "Common : taille de référence")
T.check(BlockModels.Looks.Secret.Scale >= 1.7, "Secret : presque deux fois plus gros")
T.check(BlockModels.Looks.Legendary.Light > 0 and BlockModels.Looks.Mythic.Light > 0, "Legendary et Mythic brillent")
T.check(BlockModels.Looks.Secret.Rainbow and BlockModels.Looks.Secret.Pulse, "Secret : arc-en-ciel et battement")

T.section("signes des raretés hautes")
local function rolesOf(name: string): { [string]: { any } }
	local out: { [string]: { any } } = {}
	local model = BlockModels.Build(name)
	for _, p in model:GetChildren() do
		out[p.Name] = out[p.Name] or {}
		table.insert(out[p.Name], p)
	end
	return out
end
local legendary = rolesOf("Legendary")
local gold = 0
for _, p in legendary.Fossil do
	if p.Material == Enum.Material.Foil and p.Color.R > 0.9 and p.Color.B < 0.5 then
		gold += 1
	end
end
T.eq(gold, #legendary.Fossil, "Legendary : os en or (Foil)")
local mythic = rolesOf("Mythic")
T.check(mythic.Glow ~= nil and #mythic.Glow > 0, "Mythic : base de lave")
for _, p in mythic.Glow or {} do
	T.eq(p.Material, Enum.Material.Neon, "Mythic : lave en Neon")
end
local secret = rolesOf("Secret")
local hues = {}
for _, p in secret.Rainbow or {} do
	hues[string.format("%.2f", p.Color.R) .. string.format("%.2f", p.Color.G)] = true
end
local distinct = 0
for _ in hues do
	distinct += 1
end
T.check(distinct >= 5, "Secret : couches arc-en-ciel (" .. distinct .. " couleurs)")
local pearl = 0
for _, p in secret.Fossil do
	if p.Material == Enum.Material.Foil and p.Color.R > 0.9 and p.Color.B > 0.9 then
		pearl += 1
	end
end
T.eq(pearl, #secret.Fossil, "Secret : os nacrés (Foil ; en Neon blanc, le halo effaçait le crâne)")
local shining = 0
for _, p in secret.Gem or {} do
	if p.Material == Enum.Material.Neon then
		shining += 1
	end
end
T.check(shining > 0 and shining == #secret.Gem, "Secret : cristaux en Neon")
T.eq(rolesOf("Common").Gem, nil, "Common : pas de cristal")

T.section("décor des biomes")
local seen = {}
for _, zone in BlockModels.Biomes do
	local biome = BlockModels.Biome(zone)
	T.check(biome ~= nil and #biome.Boxes >= 6 and #biome.Boxes <= 30, zone .. " : décor de 6 à 30 pièces")
	for _, rarity in BlockModels.Order do
		local count = BlockModels.Count(rarity, zone)
		T.check(count <= BUDGET, rarity .. " + " .. zone .. " : " .. count .. " pièces (budget " .. BUDGET .. ")")
	end
	local model = BlockModels.Build("Rare", 3, zone)
	T.eq(#model:GetChildren(), BlockModels.Count("Rare", zone), zone .. " : décor ajouté au bloc")
	T.eq(model:GetAttribute("Zone"), zone, zone .. " : attribut Zone")
	-- le décor reste autour du bloc et ne s'envole pas
	local lo, hi = extent(model, { Biome = true, Ember = true, Deco = true })
	T.check(lo.X > -1.9 and hi.X < 1.9 and lo.Z > -1.9 and hi.Z < 1.9 and lo.Y > -1.6 and hi.Y < 2.8, zone .. " : décor autour du bloc")
	local signature = {}
	for _, p in model:GetChildren() do
		if p.Name == "Biome" then
			signature[string.format("%.2f %.2f %.2f", p.Color.R, p.Color.G, p.Color.B)] = true
		end
	end
	local key = {}
	for k in signature do
		table.insert(key, k)
	end
	table.sort(key)
	local text = table.concat(key, "|")
	T.check(seen[text] == nil, zone .. " : décor différent des autres biomes")
	seen[text] = true
	model:Destroy()
end

T.section("taille en jeu")
T.near(BlockModels.SideOf("Common", 3), 3, 1e-6, "Common : la taille de la pièce")
T.near(BlockModels.SideOf("Secret", 3), 3 * BlockModels.Looks.Secret.Scale, 1e-6, "Secret : plus gros que la pièce")
T.near(BlockModels.SideOf("Secret", 2.5, "TankBlock"), 2.5 * BlockModels.TankScale, 1e-6, "dans une cuve : borné")
T.near(BlockModels.SideOf("Rare", 2.5, "TankBlock"), 2.5 * BlockModels.Looks.Rare.Scale, 1e-6, "cuve : les petites raretés gardent leur taille")
local big = BlockModels.Build("Mythic", BlockModels.SideOf("Mythic", 3))
local lo, hi = extent(big, ROCK)
T.near(hi.Y - lo.Y, 3 * BlockModels.Looks.Mythic.Scale, 0.02, "Mythic construit plus gros")
local light = big.PrimaryPart:FindFirstChildOfClass("PointLight")
T.near(light.Range, BlockModels.Looks.Mythic.Range * BlockModels.Looks.Mythic.Scale, 1e-6, "portée de la lumière à l'échelle du bloc")
big:Destroy()
local small = BlockModels.Build("Rare", 2.5)
local slo, shi = extent(small, { Rock = true })
T.near(shi.X - slo.X, 2.5, 0.01, "bloc porté : 2,5 studs de côté")
T.near(small:GetAttribute("Scale"), 2.5 / 3, 1e-6, "attribut Scale")
small:Destroy()

T.section("appels hostiles")
for _, bad in { nil, 0, -1, "", "Nope", "common", "Gem1", {}, true, 0 / 0, math.huge } do
	T.eq(BlockModels.Get(bad), nil, "Get(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Build(bad), nil, "Build(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Count(bad), 0, "Count(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Biome(bad), nil, "Biome(" .. T.show(bad) .. ")")
	local model = BlockModels.Build("Common", 3, bad)
	T.check(model ~= nil and model:GetAttribute("Zone") == nil, "Build avec la zone " .. T.show(bad) .. " : bloc sans décor")
	T.near(BlockModels.SideOf(bad, 3), 3, 1e-6, "SideOf(" .. T.show(bad) .. ") : taille de la pièce")
	if model then
		model:Destroy()
	end
end
for _, bad in { 0 / 0, -3, 0, math.huge, -math.huge, "3" } do
	local s = BlockModels.ScaleOf(bad :: any)
	T.check(s == s and s > 0 and s < 100, "ScaleOf(" .. T.show(bad) .. ") reste fini et positif")
	local side = BlockModels.SideOf("Epic", bad :: any)
	T.check(side == side and side > 0 and side < 100, "SideOf(Epic, " .. T.show(bad) .. ") reste fini et positif")
	local model = BlockModels.Build("Common", bad :: any)
	T.check(model ~= nil, "Build avec une taille absurde : bloc quand même")
	if model then
		model:Destroy()
	end
end
T.eq(#env.errors, 0, "aucune erreur")

T.done("blocks_models")
