-- Fusion (brief 8) : chimères de HybridBuilder. Clés (écriture, lecture, clés hostiles), puis chaque recette de
-- ServerConfig.Fusion assemblée à partir des vrais modèles DinoModels : os, boîtes, groupes, animations, sol, ailes
-- repliées qui battent seulement dans les états de fête, parents intacts, construction en briques.
local T = require("./testkit")
local env = T.env
local Vector3 = env.Vector3
local CFrame = env.CFrame

env.quiet = true
env.setSide("server")
local DinoBuilder = T.module("src/shared/DinoBuilder")
local HybridBuilder = T.module("src/shared/HybridBuilder")
local Config = T.config()
local Recipes = T.module("src/server/ServerConfig/Fusion").Recipes

local function finite(v: any): boolean
	if type(v) == "number" then
		return v == v and math.abs(v) < 1e6
	end
	return finite(v.X) and finite(v.Y) and finite(v.Z)
end

local function near3(a: any, b: any, tolerance: number): boolean
	return (a - b).Magnitude <= tolerance
end

T.section("clés")
T.eq(HybridBuilder.Key("TRex", "Pteranodon"), "TRex+Pteranodon", "clé simple")
local tweaked = HybridBuilder.Key("TRex", "Pteranodon", { HeadScale = 1.25, HeadOffset = Vector3.new(0, 0.5, -1), HeadPitch = -10 })
T.eq(tweaked, "TRex+Pteranodon;HeadScale=1.25;HeadOffset=0,0.5,-1;HeadPitch=-10", "clé avec réglages")
local head, body, tweak = HybridBuilder.Parse(tweaked)
T.eq(head, "TRex", "lecture : tête")
T.eq(body, "Pteranodon", "lecture : corps")
T.eq(tweak.HeadScale, 1.25, "lecture : HeadScale")
T.check(tweak.HeadOffset == Vector3.new(0, 0.5, -1), "lecture : HeadOffset")
T.eq(tweak.HeadPitch, -10, "lecture : HeadPitch")
T.eq(HybridBuilder.Key("A", "B", tweak), (string.gsub(tweaked, "^TRex%+Pteranodon", "A+B")), "aller-retour des réglages")
T.eq(HybridBuilder.Key("A", "B", { HeadScale = 99, LimbOffset = Vector3.new(-500, 0, 0), HeadPitch = 0 / 0 }), "A+B;HeadScale=4;LimbOffset=-40,0,0", "réglages bornés, NaN ignoré")
local _, _, clamped = HybridBuilder.Parse("A+B;HeadScale=1e9;HeadPitch=-1e9;LimbScale=0;HeadOffset=1e9,-1e9,0")
T.eq(clamped.HeadScale, 4, "HeadScale lu borné")
T.eq(clamped.HeadPitch, -90, "HeadPitch lu borné")
T.eq(clamped.LimbScale, 0.2, "LimbScale lu borné")
T.check(clamped.HeadOffset == Vector3.new(40, -40, 0), "HeadOffset lu borné")
local _, _, ignored = HybridBuilder.Parse("A+B;HeadScale=nan;HeadOffset=1,2;LimbScale=1,2,3;Foo=1;HeadPitch=;=3;HeadScale")
T.check(next(ignored) == nil, "réglages mal écrits ignorés")
T.check(HybridBuilder.IsHybrid("TRex+Pteranodon"), "IsHybrid : clé")
for _, value in { "TRex", "", 5, nil, {}, true } do
	T.check(not HybridBuilder.IsHybrid(value), "IsHybrid faux : " .. tostring(value))
end
for _, bad in { "TRex", "TRex+TRex", "T-Rex+Pteranodon", "A+B+C", "+B", "A+", "A + B", ";HeadScale=2", string.rep("A", 200) .. "+" .. string.rep("B", 101) } do
	T.check(HybridBuilder.Parse(bad) == nil, "clé refusée : " .. string.sub(bad, 1, 30))
end
for _, value in T.hostileValues() do
	local ok = pcall(HybridBuilder.Parse, value)
	T.check(ok, "Parse ne plante pas : " .. typeof(value))
	local okEnsure, result = pcall(HybridBuilder.Ensure, value)
	T.check(okEnsure and result == nil, "Ensure hostile -> nil : " .. typeof(value))
end
T.check(HybridBuilder.CanBuild("TRex+Pteranodon"), "CanBuild : deux modèles")
T.check(not HybridBuilder.CanBuild("TRex+Nope"), "CanBuild : modèle absent")
T.check(HybridBuilder.Ensure("TRex+Nope") == nil, "Ensure sans modèle -> nil")
T.check(HybridBuilder.Ensure("Nope+Pteranodon") == nil, "Ensure sans modèle de tête -> nil")
T.check(DinoBuilder.Get("TRex+Pteranodon") == nil, "pas enregistré avant Ensure")

-- os de B qui ne sont pas sa tête (ni sous sa tête)
local function keptOf(b: any): { [string]: boolean }
	local headSet = {}
	for _, name in b.Groups.Head or {} do
		headSet[name] = true
	end
	local kept = {}
	for _, bone in b.Bones do
		if (bone.Parent == nil or kept[bone.Parent]) and not headSet[bone.Name] then
			kept[bone.Name] = true
		end
	end
	return kept
end

local function hasGroup(data: any, group: string): boolean
	return data.Groups[group] ~= nil and #data.Groups[group] > 0
end

-- point le plus bas des boîtes d'un ensemble d'os dans une pose
local function lowest(data: any, pose: any, only: { [string]: boolean }?): number
	local solved = DinoBuilder.Solve(data, pose, 1, {})
	local low = math.huge
	for _, box in data.Boxes do
		if not only or only[box.Bone] then
			local cf = solved[box.Bone] or CFrame.identity
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						low = math.min(low, (cf * (box.Center + box.Size / 2 * Vector3.new(x, y, z))).Y)
					end
				end
			end
		end
	end
	return low
end

T.section("recettes")
T.eq(#Recipes, 12, "12 recettes au lancement")
local built = 0
local withWings = 0
for _, recipe in Recipes do
	T.section(recipe.Name)
	local headInfo, bodyInfo = Config.Species.ByName[recipe.Head], Config.Species.ByName[recipe.Body]
	T.check(headInfo and bodyInfo, "espèces connues")
	if not (headInfo and bodyInfo) then
		continue
	end
	local key = HybridBuilder.Key(headInfo.Model, bodyInfo.Model, recipe.Tweak)
	T.check(HybridBuilder.CanBuild(key), "les deux parents ont un modèle")
	local a, b = DinoBuilder.Get(headInfo.Model), DinoBuilder.Get(bodyInfo.Model)
	local aBones, bBones, aBoxes, bBoxes = #a.Bones, #b.Bones, #a.Boxes, #b.Boxes
	local data = HybridBuilder.Ensure(key)
	T.check(data ~= nil, "assemblée")
	if not data then
		continue
	end
	built += 1
	T.check(HybridBuilder.Ensure(key) == data, "assemblée une seule fois")
	T.check(DinoBuilder.Get(key) == data, "enregistrée dans DinoBuilder")
	T.eq(data.Species, key, "Species = clé")
	T.eq(data.Family, b.Family, "famille du corps")
	T.eq(a.Species, headInfo.Model, "parent A intact (Species)")
	T.eq(b.Species, bodyInfo.Model, "parent B intact (Species)")
	T.eq(#a.Bones + #b.Bones + #a.Boxes + #b.Boxes, aBones + bBones + aBoxes + bBoxes, "parents intacts (os, boîtes)")

	-- os : noms uniques, parents déclarés avant, racine de B
	local bones = {}
	local order = {}
	local okBones = true
	for index, bone in data.Bones do
		if bones[bone.Name] or (bone.Parent and not bones[bone.Parent]) or (index > 1 and not bone.Parent) then
			okBones = false
		end
		if not finite(bone.Pivot) or (bone.Rest and not finite(bone.Rest)) then
			okBones = false
		end
		bones[bone.Name] = bone
		order[bone.Name] = index
	end
	T.check(okBones, "os : noms uniques, parents avant enfants, une seule racine, valeurs finies")
	T.eq(data.Bones[1].Name, b.Bones[1].Name, "racine = racine du corps")
	local kept = keptOf(b)
	local keptCount = 0
	for name in kept do
		keptCount += 1
		T.check(bones[name] ~= nil, "os du corps gardé : " .. name)
	end

	-- tête : groupe Head de A, accroché où était celle de B, à une échelle bornée
	local hybridHead = data.Groups.Head or {}
	T.eq(#hybridHead, #a.Groups.Head, "groupe Head = celui de A")
	local rootName = hybridHead[1]
	local aRoot = a.Groups.Head[1]
	local bRoot = b.Groups.Head and b.Groups.Head[1]
	local aRootBone, bRootBone
	for _, bone in a.Bones do
		if bone.Name == aRoot then
			aRootBone = bone
		end
	end
	for _, bone in b.Bones do
		if bone.Name == bRoot then
			bRootBone = bone
		end
	end
	local root = bones[rootName]
	T.check(root ~= nil and kept[root.Parent], "racine de la tête accrochée à un os du corps")
	if root and bRootBone then
		T.eq(root.Parent, bRootBone.Parent, "tête accrochée au même os que celle de B")
		if not (recipe.Tweak and recipe.Tweak.HeadOffset) then
			T.check(math.abs(root.Pivot.X - bRootBone.Pivot.X) < 1e-4 and math.abs(root.Pivot.Z - bRootBone.Pivot.Z) < 1e-4, "cou posé sur le cou de B")
			T.check(root.Pivot.Y >= bRootBone.Pivot.Y - 1e-4, "cou pas plus bas que celui de B")
		end
	end
	-- (les boîtes greffées gardent l'ordre de A : la première boîte de tête de la chimère est la première de A)
	local headBoxA, headBoxH
	for _, box in a.Boxes do
		if table.find(a.Groups.Head, box.Bone) then
			headBoxA = box
			break
		end
	end
	local headSet = {}
	for _, name in hybridHead do
		headSet[name] = true
	end
	for _, box in data.Boxes do
		if headSet[box.Bone] then
			headBoxH = box
			break
		end
	end
	T.check(headBoxA ~= nil and headBoxH ~= nil, "boîtes de tête")
	if headBoxA and headBoxH and not (recipe.Tweak and recipe.Tweak.HeadScale) then
		local scale = headBoxH.Size.X / headBoxA.Size.X
		T.check(scale >= HybridBuilder.HeadScale.Min - 1e-6 and scale <= HybridBuilder.HeadScale.Max + 1e-6, "échelle de la tête bornée (" .. string.format("%.2f", scale) .. ")")
	end
	T.check(aRootBone ~= nil, "racine de la tête de A trouvée")

	-- boîtes, points, groupes
	local okBoxes = true
	for _, box in data.Boxes do
		if not bones[box.Bone] or not finite(box.Center) or not finite(box.Size) or box.Size.X <= 0 or box.Size.Y <= 0 or box.Size.Z <= 0 then
			okBoxes = false
		end
	end
	T.check(okBoxes, "boîtes sur des os connus, tailles positives")
	for name, point in data.Points do
		T.check(bones[point[1]] ~= nil and finite(point[2]), "point " .. name .. " sur un os connu")
	end
	for group, list in data.Groups do
		for _, name in list do
			T.check(bones[name] ~= nil, "groupe " .. group .. " : os " .. name)
		end
	end
	for group, list in b.Groups do
		if group ~= "Head" then
			for _, name in list do
				T.check(table.find(data.Groups[group], name) ~= nil, "groupe " .. group .. " du corps gardé : " .. name)
			end
		end
	end

	-- ailes et nageoires : celles de B, sinon celles de A
	local walkerWings = not (hasGroup(b, "Wings") or hasGroup(b, "Fins")) and hasGroup(a, "Wings")
	local graftedFins = not (hasGroup(b, "Wings") or hasGroup(b, "Fins")) and not hasGroup(a, "Wings") and hasGroup(a, "Fins")
	if hasGroup(b, "Wings") or hasGroup(b, "Fins") then
		T.eq(#(data.Groups.Wings or {}), #(b.Groups.Wings or {}), "ailes du corps seulement")
		T.eq(#(data.Groups.Fins or {}), #(b.Groups.Fins or {}), "nageoires du corps seulement")
	elseif walkerWings then
		T.eq(#data.Groups.Wings, #a.Groups.Wings, "ailes de A greffées")
	elseif graftedFins then
		T.eq(#data.Groups.Fins, #a.Groups.Fins, "nageoires de A greffées")
	end
	local wingSet = {}
	if walkerWings then
		withWings += 1
		for _, name in data.Groups.Wings do
			wingSet[name] = true
		end
		local left, right = bones.Wing1L, bones.Wing1R
		T.check(left and right, "Wing1L et Wing1R")
		if left and right then
			T.eq(left.Parent, if bones.Chest then "Chest" else data.Bones[1].Name, "ailes sur le Chest")
			T.check(left.Pivot.X < 0 and right.Pivot.X > 0, "une aile de chaque côté")
			T.check(near3(left.Pivot * Vector3.new(-1, 1, 1), right.Pivot, 1e-4), "ailes symétriques")
			local aLeft, aRight
			for _, bone in a.Bones do
				if bone.Name == "Wing1L" then
					aLeft = bone
				elseif bone.Name == "Wing1R" then
					aRight = bone
				end
			end
			local foldL = left.Rest - (aLeft.Rest or Vector3.zero)
			local foldR = right.Rest - (aRight.Rest or Vector3.zero)
			T.check(foldL.Magnitude > 30, "ailes repliées au repos")
			T.check(near3(foldR, Vector3.new(foldL.X, -foldL.Y, -foldL.Z), 1e-3), "repli en miroir")
		end
		T.check(lowest(data, {}, wingSet) >= -0.05, "ailes repliées au-dessus du sol")
	end

	-- animations : les états de B, durées de B, pistes valides ; ailes greffées : battent seulement en fête
	-- (les clés des modèles exportés peuvent dépasser la durée arrondie du clip d'un peu moins d'une image)
	local okClips = true
	local okTracks = true
	local okEvents = true
	local flapOk = true
	local wingLow = math.huge
	for name, clipB in b.Clips do
		local clip = data.Clips[name]
		if not clip or clip.Length ~= clipB.Length or clip.Loop ~= clipB.Loop or clip.Next ~= clipB.Next then
			okClips = false
			continue
		end
		local flaps = false
		for _, track in clip.Tracks do
			local n = #track.Times
			if not bones[track.Bone] or track.Channel < 1 or track.Channel > 6 or n == 0 or #track.Values ~= n or #track.Slopes ~= n then
				okTracks = false
				continue
			end
			for i = 1, n do
				local time = track.Times[i]
				if not (finite(time) and finite(track.Values[i]) and finite(track.Slopes[i])) or time < -1e-6 or time > clip.Length + 0.02 or (i > 1 and time < track.Times[i - 1]) then
					okTracks = false
				end
			end
			if wingSet[track.Bone] then
				flaps = true
			end
		end
		for _, ev in clip.Events do
			if ev[3] ~= nil and not bones[ev[3]] then
				okEvents = false
			end
		end
		if walkerWings then
			if (HybridBuilder.FlapStates[name] == true) ~= flaps then
				flapOk = false
			end
			if flaps then
				for step = 0, 12 do
					wingLow = math.min(wingLow, lowest(data, DinoBuilder.Sample(clip, clip.Length * step / 12), wingSet))
				end
			end
		end
	end
	for name in data.Clips do
		if not b.Clips[name] then
			okClips = false
		end
	end
	T.check(okClips, "mêmes états que le corps (durée, boucle, suite)")
	T.check(okTracks, "pistes valides (os connus, canaux 1 à 6, temps croissants, valeurs finies)")
	T.check(okEvents, "événements sur des os connus")
	if walkerWings then
		T.check(flapOk, "ailes greffées : battent en Happy, Roar, Fusion, Index seulement")
		T.check(wingLow >= -0.5, "battement : les ailes ne passent pas sous le sol (" .. string.format("%.2f", wingLow) .. ")")
	end

	-- au repos : la tête jamais sous le sol, le reste comme le corps
	T.check(lowest(data, {}, headSet) >= 0.1 - 1e-4, "tête au-dessus du sol au repos")
	local idle = data.Clips.Idle
	if idle then
		local low = math.huge
		for step = 0, 8 do
			low = math.min(low, lowest(data, DinoBuilder.Sample(idle, idle.Length * step / 8), headSet))
		end
		T.check(low >= -0.05, "tête au-dessus du sol en Idle (" .. string.format("%.2f", low) .. ")")
	end
	T.check(finite(data.Size) and data.Size.X > 0 and data.Size.Y > 0 and data.Size.Z > 0 and data.Height > 0, "encombrement calculé")
	T.check(data.LidDrop >= 0 and finite(data.LidDrop), "LidDrop fini")
	T.check(order[rootName] ~= nil and order[rootName] > keptCount, "os greffés après ceux du corps")
end
T.section("bilan")
T.eq(built, #Recipes, "toutes les recettes s'assemblent")
T.check(withWings >= 2, "ailes greffées sur un corps qui marche (Ptero-Rex, Quetza-Carno)")
T.clean("aucune erreur pendant l'assemblage")

T.section("réglages")
local plain = HybridBuilder.Ensure("Oviraptor+TRex")
local big = HybridBuilder.Ensure("Oviraptor+TRex;HeadScale=2;HeadOffset=0,1,0;HeadPitch=20")
T.check(plain ~= nil and big ~= nil and plain ~= big, "deux clés, deux chimères")
if plain and big then
	local function headBox(data: any): any
		for _, box in data.Boxes do
			if table.find(data.Groups.Head, box.Bone) then
				return box
			end
		end
		return nil
	end
	local function boneNamed(data: any, name: string): any
		for _, bone in data.Bones do
			if bone.Name == name then
				return bone
			end
		end
		return nil
	end
	local rootName = plain.Groups.Head[1]
	local a = DinoBuilder.Get("Oviraptor")
	local aBox = headBox(a)
	T.near(headBox(big).Size.X / aBox.Size.X, 2, 1e-4, "HeadScale imposé")
	T.check(boneNamed(big, rootName).Pivot.Y >= boneNamed(plain, rootName).Pivot.Y + 1 - 1e-4, "HeadOffset relève le cou")
	local restPlain = boneNamed(plain, rootName).Rest or Vector3.zero
	T.near((boneNamed(big, rootName).Rest or Vector3.zero).X - restPlain.X, 20, 1e-4, "HeadPitch ajouté au repos du cou")
end

T.section("briques")
local model = DinoBuilder.Build("Oviraptor+TRex", { Size = "Big", Mutation = "Amber", Level = "Golden" })
T.eq(model:GetAttribute("Species"), "Oviraptor+TRex", "modèle construit : attribut Species = clé")
T.check(#model:GetChildren() > 10, "modèle construit : briques")
model:Destroy()
T.done("fusion_hybrids")
