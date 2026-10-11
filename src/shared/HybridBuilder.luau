--!strict
-- HybridBuilder (brief 8 « fusion ») : chimères de la fusion hybride, assemblées en jeu à partir des données de leurs deux
-- parents, sans modèle Blender en plus (models/BRIEF.md section 7, validé par Snaky). Partagé serveur et client.
--
--   local key = HybridBuilder.Key("TRex", "Pteranodon")    -- "TRex+Pteranodon" : modules DinoModels de A (tête) et B (corps)
--   local data = HybridBuilder.Ensure(key)                  -- assemble et enregistre (DinoBuilder.Register) ; nil sans modèles
--   local model = DinoBuilder.Build(key, { Size = "Big" })  -- ensuite comme une espèce (DinoAnimController l'anime)
--
-- Assemblage : la tête (groupe Head : Neck1..N, Head, Jaw, Lid, Frill, Crest) vient de A ; le corps, les pattes, les bras et
-- la queue viennent de B ; les ailes ou les nageoires viennent de celui qui en a (de B si les deux en ont).
--   - Tête : Neck1 de A est rattaché au Chest de B, son pivot posé sur le pivot Neck1 de B, et toute la tête est mise à
--     l'échelle largeur du cou de B / largeur du cou de A (bornée entre 0,6 et 1,6). Jamais sous le sol.
--   - Ailes greffées : Wing1 sur le Chest de B, sur le dos au niveau de ses épaules, envergure = 1,2 x la longueur de B.
--     Sur un corps qui marche, elles restent repliées sur le dos et battent seulement en Happy, Roar, Fusion et Index.
--   - Nageoires greffées : FinF sur le Chest, FinB sur les Hips de B, à l'échelle longueur de B / longueur de A (0,5 à 1,6).
--   - Animations : pour chaque état de B, les os de B jouent l'animation de B ; ceux de la tête (et des nageoires greffées)
--     jouent l'animation de A du même nom (ou la plus proche), étirée à la durée de celle de B.
-- La clé suffit pour reconstruire la chimère : le client la lit dans l'attribut Species du modèle (FusionController).
-- Réglages fins par recette (brief 9, ServerConfig/Fusion.luau) : Key(tête, corps, { HeadScale = 1.2, ... }) les écrit
-- dans la clé : "TRex+Pteranodon;HeadScale=1.2;HeadOffset=0,0.5,0".

local DinoBuilder = require(script.Parent.DinoBuilder)

type Data = DinoBuilder.Data
type BoneDef = DinoBuilder.BoneDef
type Box = DinoBuilder.Box
type Clip = DinoBuilder.Clip
type Track = DinoBuilder.Track

-- Réglages d'une recette (tous facultatifs)
export type Tweak = {
	HeadScale: number?, -- échelle de la tête (sinon largeur du cou de B / largeur du cou de A, bornée)
	HeadOffset: Vector3?, -- décalage de la tête, en studs (repère de B)
	HeadPitch: number?, -- rotation de repos du cou en plus, en degrés (+ relève la tête)
	LimbScale: number?, -- échelle des ailes ou nageoires greffées
	LimbOffset: Vector3?, -- décalage des ailes ou nageoires greffées (côté gauche, en miroir à droite)
	LimbTurn: Vector3?, -- rotation de repos en plus des ailes ou nageoires greffées, degrés XYZ (côté gauche, en miroir)
}

local HybridBuilder = {}

HybridBuilder.Separator = "+"
HybridBuilder.HeadScale = { Min = 0.6, Max = 1.6 }
HybridBuilder.WingSpan = 1.2 -- envergure des ailes greffées, en longueurs du corps de B
HybridBuilder.FinScale = { Min = 0.5, Max = 1.6 }
-- états où des ailes greffées sur un corps qui marche se déplient et battent
HybridBuilder.FlapStates = { Happy = true, Roar = true, Fusion = true, Index = true } :: { [string]: boolean }

-- Ailes repliées le long des flancs (côté gauche, degrés XYZ ; à droite ry et rz changent de signe). Le bras part vers
-- l'arrière en descendant de 12°, écarté de 6° vers l'extérieur, et sa membrane pend le long du flanc, penchée de 12°
-- vers l'extérieur (Rx(90) Rz(-90), puis ces trois inclinaisons, écrits en angles XYZ). L'avant-bras revient vers
-- l'avant et le doigt-aile repart vers l'arrière en accordéon : demi-tour autour de l'axe de la membrane (Rz), pas autour
-- de sa normale, pour que chaque membrane pende encore vers le bas (brief 9 : dans le plan, elles se dressaient au-dessus
-- des épaules) ; ±4° pour qu'elles se recouvrent vers l'extérieur.
local FOLD: { [string]: Vector3 } = {
	["1"] = Vector3.new(103.2, -10.7, -84),
	["2"] = Vector3.new(0, 0, 176),
	["3"] = Vector3.new(0, 0, 184),
}
-- Battement (côté gauche) : relevé moyen, amplitude de rz et retard de phase par segment (les ailes montent plus
-- qu'elles ne descendent : elles ne touchent jamais le sol)
local FLAP: { [string]: { number } } = {
	["1"] = { -20, 30, 0 },
	["2"] = { 0, 12, 0.7 },
	["3"] = { 0, 8, 1.4 },
}

-- états de repli quand A n'a pas l'animation de B (comme DinoAnimController)
local FALLBACK: { [string]: { string } } = {
	Return = { "Walk" },
	Run = { "Walk" },
	Fly = { "Glide", "Walk" },
	Glide = { "Fly", "Walk" },
	TakeOff = { "Fly", "Walk" },
	Land = { "Idle" },
	Dive = { "Walk" },
	Jump = { "Happy" },
	Wake = { "Idle" },
	BackToSleep = { "Sleep" },
	Search = { "Idle" },
	Catch = { "Roar" },
}

local TWEAK_FIELDS = { "HeadScale", "HeadOffset", "HeadPitch", "LimbScale", "LimbOffset", "LimbTurn" }
local TWEAK_LIMITS: { [string]: { number } } = {
	HeadScale = { 0.2, 4 },
	HeadOffset = { -40, 40 },
	HeadPitch = { -90, 90 },
	LimbScale = { 0.2, 4 },
	LimbOffset = { -40, 40 },
	LimbTurn = { -180, 180 },
}
-- réglages qui sont des Vector3 (les autres sont des nombres)
local TWEAK_VECTORS: { [string]: boolean } = { HeadOffset = true, LimbOffset = true, LimbTurn = true }

-- coins d'une boîte (multipliés par sa demi-taille)
local CORNERS: { Vector3 } = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

local modelsFolder: Instance? = script.Parent and script.Parent:FindFirstChild("DinoModels")
local built: { [string]: Data } = {}

-- ====================================================================== clés

local function number(value: number): string
	local text = string.format("%.3f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return if text == "-0" then "0" else text
end

local function clamp(value: number, field: string): number
	local limits = TWEAK_LIMITS[field]
	return math.clamp(value, limits[1], limits[2])
end

-- Clé d'une chimère : modules DinoModels de la tête (A) et du corps (B), puis les réglages
function HybridBuilder.Key(head: string, body: string, tweak: Tweak?): string
	local key = head .. HybridBuilder.Separator .. body
	if tweak then
		local t = tweak :: { [string]: any }
		for _, field in TWEAK_FIELDS do
			local value = t[field]
			if type(value) == "number" and value == value then
				key ..= ";" .. field .. "=" .. number(clamp(value, field))
			elseif typeof(value) == "Vector3" then
				local v = value :: Vector3
				key ..= string.format(
					";%s=%s,%s,%s",
					field,
					number(clamp(v.X, field)),
					number(clamp(v.Y, field)),
					number(clamp(v.Z, field))
				)
			end
		end
	end
	return key
end

-- La clé désigne-t-elle une chimère ?
function HybridBuilder.IsHybrid(key: any): boolean
	return type(key) == "string" and string.find(key, HybridBuilder.Separator, 1, true) ~= nil
end

-- Lit une clé : (tête, corps, réglages), ou nil si elle est mal formée
function HybridBuilder.Parse(key: any): (string?, string?, Tweak?)
	if type(key) ~= "string" or #key > 300 then
		return nil, nil, nil
	end
	local parts = string.split(key, ";")
	local head, body = string.match(parts[1], "^(%w+)%+(%w+)$")
	if not (head and body) or head == body then
		return nil, nil, nil
	end
	local tweak: { [string]: any } = {}
	for i = 2, #parts do
		local field, value = string.match(parts[i], "^(%a+)=(.+)$")
		if field and TWEAK_LIMITS[field] and value then
			local x, y, z = string.match(value, "^([^,]+),([^,]+),([^,]+)$")
			if x then
				local nx, ny, nz = tonumber(x), tonumber(y), tonumber(z)
				if nx and ny and nz and nx == nx and ny == ny and nz == nz and TWEAK_VECTORS[field] then
					tweak[field] = Vector3.new(clamp(nx, field), clamp(ny, field), clamp(nz, field))
				end
			else
				local n = tonumber(value)
				if n and n == n and not TWEAK_VECTORS[field] then
					tweak[field] = clamp(n, field)
				end
			end
		end
	end
	return head, body, tweak :: Tweak
end

-- Le module DinoModels d'une espèce existe-t-il ? (sans le lire)
function HybridBuilder.HasModel(model: string): boolean
	local module = modelsFolder and modelsFolder:FindFirstChild(model)
	return module ~= nil and module:IsA("ModuleScript")
end

-- Les deux parents d'une clé ont-ils un modèle ?
function HybridBuilder.CanBuild(key: string): boolean
	local head, body = HybridBuilder.Parse(key)
	return head ~= nil and body ~= nil and HybridBuilder.HasModel(head) and HybridBuilder.HasModel(body)
end

-- ====================================================================== outils

local function pchip(d0: number, d1: number, h0: number, h1: number): number
	if d0 * d1 <= 0 then
		return 0
	end
	local w1, w2 = 2 * h1 + h0, h1 + 2 * h0
	return (w1 + w2) / (w1 / d0 + w2 / d1)
end

-- Pentes de la cubique monotone (mêmes calculs que DinoBuilder et models/lib/anim.py)
local function slopes(times: { number }, values: { number }, loop: boolean): { number }
	local k = #times
	local m = table.create(k, 0)
	if k < 3 then
		return m
	end
	local h = table.create(k - 1, 0)
	local d = table.create(k - 1, 0)
	for j = 1, k - 1 do
		h[j] = times[j + 1] - times[j]
		d[j] = if h[j] > 1e-9 then (values[j + 1] - values[j]) / h[j] else 0
	end
	for j = 2, k - 1 do
		m[j] = pchip(d[j - 1], d[j], h[j - 1], h[j])
	end
	if loop then
		m[1] = pchip(d[k - 1], d[1], h[k - 1], h[1])
		m[k] = m[1]
	end
	return m
end

local function clipFor(data: Data, state: string): Clip?
	local c = data.Clips[state]
	if c then
		return c
	end
	local alts = FALLBACK[state]
	if alts then
		for _, alt in alts do
			if data.Clips[alt] then
				return data.Clips[alt]
			end
		end
	end
	return data.Clips.Idle
end

local function groupOf(data: Data): { [string]: string }
	local out = {}
	for group, list in data.Groups do
		for _, bone in list do
			out[bone] = group
		end
	end
	return out
end

local function hasGroup(data: Data, group: string): boolean
	local list = data.Groups[group]
	return list ~= nil and #list > 0
end

-- Étendue des boîtes d'un ensemble d'os (repère du modèle, au repos sans rotations) : min, max
local function extent(data: Data, bones: { [string]: boolean }): (Vector3?, Vector3?)
	local lo, hi = nil :: Vector3?, nil :: Vector3?
	for _, box in data.Boxes do
		if bones[box.Bone] then
			local a = box.Center - box.Size / 2
			local b = box.Center + box.Size / 2
			lo = if lo then lo:Min(a) else a
			hi = if hi then hi:Max(b) else b
		end
	end
	return lo, hi
end

-- Largeur du cou : boîtes de l'os racine de la tête (Neck1), sinon de toute la tête
local function neckWidth(data: Data, root: string, set: { [string]: boolean }): number
	local lo, hi = extent(data, { [root] = true })
	if not (lo and hi) then
		lo, hi = extent(data, set)
	end
	if lo and hi then
		return math.max(hi.X - lo.X, 0.1)
	end
	return 1
end

-- Boîtes d'un os qui croisent la tranche z (repli : toutes les boîtes de l'os)
local function slice(data: Data, bone: string, z: number): (Vector3?, Vector3?)
	local lo, hi = nil :: Vector3?, nil :: Vector3?
	for pass = 1, 2 do
		for _, box in data.Boxes do
			if box.Bone == bone and (pass == 2 or math.abs(box.Center.Z - z) <= box.Size.Z / 2 + 0.05) then
				local a = box.Center - box.Size / 2
				local b = box.Center + box.Size / 2
				lo = if lo then lo:Min(a) else a
				hi = if hi then hi:Max(b) else b
			end
		end
		if lo then
			break
		end
	end
	return lo, hi
end

local function boneMap(data: Data): { [string]: BoneDef }
	local out = {}
	for _, bone in data.Bones do
		out[bone.Name] = bone
	end
	return out
end

-- ====================================================================== assemblage

type Graft = {
	AnchorA: Vector3, -- point de A posé sur AnchorB
	AnchorB: Vector3,
	Scale: number,
}

local function mapPoint(g: Graft, p: Vector3): Vector3
	return g.AnchorB + (p - g.AnchorA) * g.Scale
end

-- Assemble la chimère tête de `head` (A) + corps de `body` (B). Fonction pure : rien n'est enregistré.
function HybridBuilder.Assemble(head: Data, body: Data, key: string, tweak: Tweak?): Data
	local t: Tweak = tweak or {}
	local aBones, bBones = boneMap(head), boneMap(body)
	local aGroup, bGroup = groupOf(head), groupOf(body)

	-- ailes ou nageoires : celles de B s'il en a, sinon celles de A
	local limb: string? = nil
	if not (hasGroup(body, "Wings") or hasGroup(body, "Fins")) then
		if hasGroup(head, "Wings") then
			limb = "Wings"
		elseif hasGroup(head, "Fins") then
			limb = "Fins"
		end
	end

	-- os gardés de B : tout sauf sa tête (et ce qui pend dessous). Des ailes greffées sur un bipède remplacent ses bras
	-- (brief 9 : les ailes repliées les couvraient, et le modèle reste sous le budget de pièces)
	local dropArms = limb == "Wings" and body.Family == "Biped"
	local kept: { [string]: boolean } = {}
	for _, bone in body.Bones do
		local parentKept = bone.Parent == nil or kept[bone.Parent]
		local group = bGroup[bone.Name]
		if parentKept and group ~= "Head" and not (dropArms and group == "Arms") then
			kept[bone.Name] = true
		end
	end

	-- os greffés de A : la tête, les ailes ou nageoires, et les os sans groupe qui pendent dessous
	local grafted: { [string]: string } = {} -- os de A -> "Head" | "Wings" | "Fins"
	for _, bone in head.Bones do
		local group = aGroup[bone.Name]
		if group == "Head" or (limb ~= nil and group == limb) then
			grafted[bone.Name] = group
		elseif group == nil and bone.Parent and grafted[bone.Parent] then
			grafted[bone.Name] = grafted[bone.Parent]
		end
	end

	-- noms : un os greffé qui porte le nom d'un os gardé de B est renommé (suffixe A)
	local rename: { [string]: string } = {}
	for name in grafted do
		rename[name] = if kept[name] then name .. "A" else name
	end

	-- os de B où l'on accroche : le parent du même nom s'il est gardé, sinon Chest, sinon la racine
	local rootB = body.Bones[1].Name
	local function attach(parent: string?, preferred: string): string
		if parent and kept[parent] then
			return parent
		end
		return if kept[preferred] then preferred else rootB
	end

	-- ---------------------------------------------------------------- tête
	local headSet: { [string]: boolean } = {}
	local headRoot: string? = nil
	for _, bone in head.Bones do
		if grafted[bone.Name] == "Head" then
			headSet[bone.Name] = true
			if not headRoot and not (bone.Parent and grafted[bone.Parent] == "Head") then
				headRoot = bone.Name
			end
		end
	end
	local bHeadSet: { [string]: boolean } = {}
	local bHeadRoot: string? = nil
	for _, bone in body.Bones do
		if bGroup[bone.Name] == "Head" then
			bHeadSet[bone.Name] = true
			if not bHeadRoot then
				bHeadRoot = bone.Name
			end
		end
	end
	local chestB = bBones.Chest or body.Bones[1]
	local headAnchorA = if headRoot then aBones[headRoot].Pivot else Vector3.zero
	local headAnchorB = if bHeadRoot then bBones[bHeadRoot].Pivot else chestB.Pivot
	local headScale = t.HeadScale
	if not headScale then
		local wa = if headRoot then neckWidth(head, headRoot, headSet) else 1
		local wb = if bHeadRoot then neckWidth(body, bHeadRoot, bHeadSet) else wa
		headScale = math.clamp(wb / wa, HybridBuilder.HeadScale.Min, HybridBuilder.HeadScale.Max)
	end
	local headGraft: Graft = {
		AnchorA = headAnchorA,
		AnchorB = headAnchorB + (t.HeadOffset or Vector3.zero),
		Scale = headScale :: number,
	}

	-- ---------------------------------------------------------------- ailes ou nageoires greffées
	local limbScale = 1
	local limbGrafts: { [string]: Graft } = {} -- racine greffée -> greffe
	local limbParent: { [string]: string } = {}
	local walkerWings = limb == "Wings"
	if limb then
		local lengthB = body.Size.Z
		if limb == "Wings" then
			limbScale = t.LimbScale or math.clamp(HybridBuilder.WingSpan * lengthB / math.max(head.Size.X, 0.1), 0.3, 3)
		else
			limbScale = t.LimbScale
				or math.clamp(lengthB / math.max(head.Size.Z, 0.1), HybridBuilder.FinScale.Min, HybridBuilder.FinScale.Max)
		end
		local offset = t.LimbOffset or Vector3.zero
		-- épaules de B : bras, sinon entre le Chest et le cou
		local shoulderZ = if bBones.ArmL
			then bBones.ArmL.Pivot.Z
			elseif bHeadRoot then (chestB.Pivot.Z + headAnchorB.Z) / 2
			else chestB.Pivot.Z
		local hipsB = bBones.Hips or body.Bones[1]
		local hipZ = if bBones.ThighL then bBones.ThighL.Pivot.Z else hipsB.Pivot.Z
		for _, bone in head.Bones do
			if grafted[bone.Name] == limb and not (bone.Parent and grafted[bone.Parent] == limb) then
				local side = if bone.Pivot.X < 0 then -1 else 1
				local anchorB: Vector3
				local parent: string
				if limb == "Wings" then
					-- en haut des flancs, au niveau des épaules
					parent = attach(nil, "Chest")
					local lo, hi = slice(body, parent, shoulderZ)
					local half = if lo and hi then math.max(math.abs(lo.X), math.abs(hi.X)) else 0.5
					local top = if lo and hi then hi.Y - 0.15 * (hi.Y - lo.Y) else chestB.Pivot.Y
					anchorB = Vector3.new(side * math.max(half * 0.8, 0.3), top, shoulderZ)
				else
					-- FinF sur les flancs du Chest, FinB sur les flancs des Hips, au tiers bas
					local front = string.sub(bone.Name, 1, 4) ~= "FinB"
					parent = attach(nil, if front then "Chest" else (hipsB.Name))
					local z = if front then shoulderZ else hipZ
					local lo, hi = slice(body, parent, z)
					local half = if lo and hi then math.max(math.abs(lo.X), math.abs(hi.X)) else 0.5
					local y = if lo and hi then lo.Y + 0.35 * (hi.Y - lo.Y) else bBones[parent].Pivot.Y
					anchorB = Vector3.new(side * half, y, z)
				end
				limbGrafts[bone.Name] = {
					AnchorA = bone.Pivot,
					AnchorB = anchorB + Vector3.new(offset.X * side * -1, offset.Y, offset.Z),
					Scale = limbScale,
				}
				limbParent[bone.Name] = parent
			end
		end
	end

	-- greffe de chaque os de A (celle de sa racine)
	local graftOf: { [string]: Graft } = {}
	for _, bone in head.Bones do
		local group = grafted[bone.Name]
		if group then
			local inherited = bone.Parent and graftOf[bone.Parent]
			graftOf[bone.Name] = limbGrafts[bone.Name] or inherited or headGraft
		end
	end

	-- jamais sous le sol : la tête remonte si une de ses boîtes passe sous Y = 0 au repos
	local pitch = t.HeadPitch or 0
	local function lowest(group: string): number
		local low = math.huge
		local chain: { [string]: CFrame } = {}
		-- (rotations de repos de A le long de la chaîne greffée, avec le HeadPitch de la recette)
		for _, bone in head.Bones do
			if grafted[bone.Name] == group then
				local parent = bone.Parent and chain[bone.Parent]
				local r = bone.Rest
				if bone.Name == headRoot and pitch ~= 0 then
					r = (r or Vector3.zero) + Vector3.new(pitch, 0, 0)
				end
				local pivot = mapPoint(graftOf[bone.Name], bone.Pivot)
				local localCF = if r
					then CFrame.new(pivot) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z)) * CFrame.new(-pivot)
					else CFrame.identity
				chain[bone.Name] = if parent then parent * localCF else localCF
			end
		end
		for _, box in head.Boxes do
			local cf = chain[box.Bone]
			if cf and grafted[box.Bone] == group then
				local g = graftOf[box.Bone]
				local center = mapPoint(g, box.Center)
				local half = box.Size * g.Scale / 2
				for _, corner in CORNERS do
					low = math.min(low, (cf * (center + half * corner)).Y)
				end
			end
		end
		return low
	end
	local headLow = lowest("Head")
	if headLow < 0.1 then
		headGraft.AnchorB += Vector3.new(0, 0.1 - headLow, 0)
	end

	-- ---------------------------------------------------------------- os
	local bones: { BoneDef } = {}
	for _, bone in body.Bones do
		if kept[bone.Name] then
			table.insert(bones, bone)
		end
	end
	for _, bone in head.Bones do
		local group = grafted[bone.Name]
		if group then
			local g = graftOf[bone.Name]
			local parent: string
			if bone.Parent and grafted[bone.Parent] then
				parent = rename[bone.Parent]
			elseif limbParent[bone.Name] then
				parent = limbParent[bone.Name]
			else
				parent = attach(bone.Parent, "Chest")
			end
			local rest = bone.Rest or Vector3.zero
			if group == "Head" and bone.Name == headRoot and pitch ~= 0 then
				rest += Vector3.new(pitch, 0, 0)
			end
			if limbGrafts[bone.Name] and t.LimbTurn then
				-- racine d'une aile ou nageoire greffée : rotation de repos en plus (miroir à droite)
				local turn = t.LimbTurn :: Vector3
				rest += if bone.Pivot.X > 0 then Vector3.new(turn.X, -turn.Y, -turn.Z) else turn
			end
			if group == "Wings" and walkerWings then
				local segment, side = string.match(bone.Name, "^Wing(%d)([LR])$")
				local fold = segment and FOLD[segment]
				if fold then
					rest += if side == "R" then Vector3.new(fold.X, -fold.Y, -fold.Z) else fold
				end
			end
			table.insert(bones, {
				Name = rename[bone.Name],
				Parent = parent,
				Pivot = mapPoint(g, bone.Pivot),
				Rest = if rest.Magnitude > 1e-9 then rest else nil,
			})
		end
	end

	-- ---------------------------------------------------------------- boîtes, points, groupes
	local boxes: { Box } = {}
	for _, box in body.Boxes do
		if kept[box.Bone] then
			table.insert(boxes, box)
		end
	end
	for _, box in head.Boxes do
		if grafted[box.Bone] then
			local g = graftOf[box.Bone]
			table.insert(boxes, {
				Bone = rename[box.Bone],
				Center = mapPoint(g, box.Center),
				Size = box.Size * g.Scale,
				Color = box.Color,
				Material = box.Material,
			})
		end
	end
	local points: { [string]: { any } } = {}
	for name, point in body.Points do
		if kept[point[1]] then
			points[name] = point
		end
	end
	for name, point in head.Points do
		local bone = point[1]
		if grafted[bone] and not points[name] then
			points[name] = { rename[bone], mapPoint(graftOf[bone], point[2]) }
		end
	end
	local groups: { [string]: { string } } = {}
	for group, list in body.Groups do
		if group ~= "Head" then
			local keep: { string } = {}
			for _, name in list do
				if kept[name] then
					table.insert(keep, name)
				end
			end
			if #keep > 0 then
				groups[group] = keep
			end
		end
	end
	for _, bone in head.Bones do
		local group = grafted[bone.Name]
		if group then
			local list = groups[group] or {}
			groups[group] = list
			table.insert(list, rename[bone.Name])
		end
	end

	-- ---------------------------------------------------------------- animations
	local clips: { [string]: Clip } = {}
	for name, clipB in body.Clips do
		local tracks: { Track } = {}
		for _, track in clipB.Tracks do
			if kept[track.Bone] then
				table.insert(tracks, track)
			end
		end
		-- tête (et nageoires greffées) : animation de A du même nom, étirée à la durée de celle de B
		local clipA = clipFor(head, name)
		if clipA and clipA.Length > 0 then
			local k = clipB.Length / clipA.Length
			for _, track in clipA.Tracks do
				local group = grafted[track.Bone]
				if group and not (group == "Wings" and walkerWings) then
					local s = if track.Channel >= 4 then graftOf[track.Bone].Scale else 1
					local times = table.create(#track.Times, 0)
					local values = table.create(#track.Values, 0)
					local slope = table.create(#track.Slopes, 0)
					for i, time in track.Times do
						times[i] = time * k
					end
					for i, value in track.Values do
						values[i] = value * s
					end
					for i, m in track.Slopes do
						slope[i] = m * s / k
					end
					table.insert(tracks, {
						Bone = rename[track.Bone],
						Channel = track.Channel,
						Times = times,
						Values = values,
						Slopes = slope,
					})
				end
			end
		end
		-- ailes greffées sur un corps qui marche : repliées (pose de repos), battent dans les états de fête
		if walkerWings and HybridBuilder.FlapStates[name] then
			local length = math.max(clipB.Length, 0.2)
			local cycles = math.max(1, math.floor(length * 2.2 + 0.5))
			local omega = 2 * math.pi * cycles / length
			local steps = math.max(8, math.ceil(length * 20))
			for _, bone in head.Bones do
				local segment, side = string.match(bone.Name, "^Wing(%d)([LR])$")
				local fold = segment and FOLD[segment]
				local flap = segment and FLAP[segment]
				if grafted[bone.Name] == "Wings" and fold and flap then
					local mirror = if side == "R" then -1 else 1
					for channel = 1, 3 do
						local times = table.create(steps + 1, 0)
						local values = table.create(steps + 1, 0)
						for i = 0, steps do
							local time = length * i / steps
							local u = 1
							if not clipB.Loop then
								local ramp = math.min(0.3, length / 3)
								local a = math.clamp(time / ramp, 0, 1)
								local b = math.clamp((length - time) / ramp, 0, 1)
								u = (a * a * (3 - 2 * a)) * (b * b * (3 - 2 * b))
							end
							local target = 0
							if channel == 3 then
								target = flap[1] + flap[2] * math.sin(omega * time - flap[3])
							end
							local folded = if channel == 1 then fold.X elseif channel == 2 then fold.Y else fold.Z
							times[i + 1] = time
							values[i + 1] = u * (target - folded) * (if channel == 1 then 1 else mirror)
						end
						table.insert(tracks, {
							Bone = rename[bone.Name],
							Channel = channel,
							Times = times,
							Values = values,
							Slopes = slopes(times, values, clipB.Loop),
						})
					end
				end
			end
		end
		clips[name] = {
			Name = name,
			Length = clipB.Length,
			Loop = clipB.Loop,
			Next = clipB.Next,
			Speed = clipB.Speed,
			Events = clipB.Events,
			Tracks = tracks,
		}
	end

	local data: Data = {
		Species = key,
		Name = key,
		Family = body.Family,
		Voxel = body.Voxel,
		Height = body.Height,
		Size = body.Size,
		LidDrop = head.LidDrop * headGraft.Scale,
		Bones = bones,
		Groups = groups,
		Points = points,
		Boxes = boxes,
		Clips = clips,
	}

	-- encombrement au repos (ailes repliées comprises)
	local solved = DinoBuilder.Solve(data, {}, 1, {})
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, box in boxes do
		local cf = solved[box.Bone] or CFrame.identity
		local half = box.Size / 2
		for _, corner in CORNERS do
			local p = cf * (box.Center + half * corner)
			lo = lo:Min(p)
			hi = hi:Max(p)
		end
	end
	if lo.X < math.huge then
		data.Height = hi.Y
		data.Size = Vector3.new(hi.X - lo.X, hi.Y, hi.Z - lo.Z)
	end
	return data
end

-- Données d'une chimère (assemblée une fois puis enregistrée dans DinoBuilder sous sa clé). nil si la clé est mal
-- formée ou si un parent n'a pas encore de modèle.
function HybridBuilder.Ensure(key: string): Data?
	local hit = built[key]
	if hit then
		return hit
	end
	local head, body, tweak = HybridBuilder.Parse(key)
	if not (head and body and HybridBuilder.HasModel(head) and HybridBuilder.HasModel(body)) then
		return nil
	end
	local a, b = DinoBuilder.Get(head :: string), DinoBuilder.Get(body :: string)
	if not (a and b) then
		return nil
	end
	local ok, data = pcall(HybridBuilder.Assemble, a, b, key, tweak)
	if not ok then
		warn("[HybridBuilder] assemblage impossible", key, data)
		return nil
	end
	built[key] = data
	DinoBuilder.Register(key, data)
	return data
end

return HybridBuilder
