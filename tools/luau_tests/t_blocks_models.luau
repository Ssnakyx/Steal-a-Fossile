-- Blocs de fossiles (brief 9) : BlockModels. Un modèle voxel par rareté (models/blocks/build.py --export), de la couleur
-- de Config.Rarity, au budget, à la bonne taille, avec des effets qui s'empilent avec la rareté. Appels hostiles :
-- raretés inconnues, tailles absurdes.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Vector3 = env.Vector3
local Enum = env.Enum

local BlockModels = env.module("src/shared/BlockModels")
local Rarity = env.module("src/shared/Config/Rarity")

local BUDGET = 100 -- pièces au plus par bloc (il y en a jusqu'à 96 sur la route)

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

T.section("une rareté par bloc, dans l'ordre de Config.Rarity")
T.eq(#BlockModels.Order, #Rarity.Order, "7 raretés")
for i, name in Rarity.Order do
	T.eq(BlockModels.Order[i], name, "ordre " .. name)
	T.check(BlockModels.Get(name) ~= nil, "modèle " .. name)
	T.check(BlockModels.Looks[name] ~= nil, "effets " .. name)
end

T.section("modèles en briques")
local previousGems, previous = -1, nil
for _, name in BlockModels.Order do
	local data = BlockModels.Get(name)
	local count = BlockModels.Count(name)
	T.check(count > 20 and count <= BUDGET, name .. " : " .. count .. " pièces (budget " .. BUDGET .. ")")
	local model = BlockModels.Build(name)
	T.check(model ~= nil and model:IsA("Model"), name .. " : Build donne un Model")
	if not (model and data) then
		continue
	end
	T.eq(#model:GetChildren(), count, name .. " : une pièce par boîte")
	T.eq(model:GetAttribute("Rarity"), name, name .. " : attribut Rarity")
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
	local lo, hi = extent(model, { Rock = true, Rainbow = true, Glow = true })
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
		T.check((glo.Z + ghi.Z) / 2 < 0.4, name .. " : cristaux sur la moitié avant du dessus")
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
	end
	-- studs : le dessus de la roche en plastique
	local studs = 0
	for _, p in model:GetChildren() do
		if p.Name == "Rock" and p.TopSurface == Enum.SurfaceType.Studs then
			studs += 1
		end
	end
	if name ~= "Secret" then
		T.check(studs > 0, name .. " : studs sur le dessus de la roche")
	end
	-- effets : s'empilent avec la rareté
	local look = BlockModels.Looks[name]
	T.eq(look.Name, name, name .. " : nom des effets")
	T.eq(look.Rank, Rarity.Info[name].Rank, name .. " : rang")
	if previous then
		T.check(look.Rise >= previous.Rise and look.Glint >= previous.Glint and look.Orbit >= previous.Orbit,
			name .. " : effets au moins aussi forts que la rareté d'avant")
	end
	previous = look
	model:Destroy()
end
local common = BlockModels.Looks.Common
T.check(common.Rise == 0 and common.Glint == 0 and common.Orbit == 0 and not common.Beam, "Common : aucun effet")
T.check(BlockModels.Looks.Secret.Rainbow and BlockModels.Looks.Secret.Beam, "Secret : arc-en-ciel et colonne")
T.check(BlockModels.Looks.Mythic.Pulse and BlockModels.Looks.Mythic.Flicker, "Mythic : lave qui bat et braises")

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
	if p.Reflectance > 0 and p.Color.R > 0.9 and p.Color.B < 0.5 then
		gold += 1
	end
end
T.eq(gold, #legendary.Fossil, "Legendary : os en or brillant")
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
T.eq(rolesOf("Common").Gem, nil, "Common : pas de cristal")

T.section("taille demandée")
local small = BlockModels.Build("Rare", 2.5)
local lo, hi = extent(small, { Rock = true })
T.near(hi.X - lo.X, 2.5, 0.01, "bloc porté : 2,5 studs de côté")
T.near(small:GetAttribute("Scale"), 2.5 / 3, 1e-6, "attribut Scale")
small:Destroy()

T.section("appels hostiles")
for _, bad in { nil, 0, -1, "", "Nope", "common", "Gem1", {}, true, 0 / 0, math.huge } do
	T.eq(BlockModels.Get(bad), nil, "Get(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Build(bad), nil, "Build(" .. T.show(bad) .. ")")
	T.eq(BlockModels.Count(bad), 0, "Count(" .. T.show(bad) .. ")")
end
for _, bad in { 0 / 0, -3, 0, math.huge, -math.huge, "3" } do
	local s = BlockModels.ScaleOf(bad :: any)
	T.check(s == s and s > 0 and s < 100, "ScaleOf(" .. T.show(bad) .. ") reste fini et positif")
	local model = BlockModels.Build("Common", bad :: any)
	T.check(model ~= nil, "Build avec une taille absurde : bloc quand même")
	if model then
		model:Destroy()
	end
end
T.eq(#env.errors, 0, "aucune erreur")

T.done("blocks_models")
