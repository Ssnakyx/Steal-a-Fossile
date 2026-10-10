-- Test hors Studio des modèles de dinos (lancé par models/tests/run.py avec l'interpréteur luau).
-- Vérifie chaque module de src/shared/DinoModels lu par DinoBuilder : structure, états obligatoires par famille,
-- budget de pièces, pistes d'animation, boucles fermées, lecture (valeurs aux clés, pas de dépassement entre deux clés),
-- fondu par le plus court chemin, et la même pose que les aperçus Blender (cinématique des os, models/tests/expect).

local DinoBuilder = require("./DinoBuilder")
local species = require("./species")

local fails, oks = 0, 0
local function check(name, cond, detail)
	if cond then
		oks += 1
	else
		fails += 1
		print("FAIL " .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

local COMMON = {
	"Idle", "IdleSniff", "IdleScratch", "IdleStretch", "IdleShake", "IdleYawn", "Walk", "Run", "Happy", "Roar", "Eat",
	"Sleep", "Spawn", "Wake", "Catch", "Search", "BackToSleep", "Fusion", "Index",
}
local EXTRA = { Flyer = { "TakeOff", "Fly", "Glide", "Land" }, Swimmer = { "Dive", "Jump" } }

for _, name in species do
	local raw = require("./models/" .. name)
	local ok, data = pcall(DinoBuilder.Decode, name, raw)
	check(name .. " : décodage", ok, data)
	if not ok then
		continue
	end
	-- structure
	check(name .. " : famille connue", data.Family == "Biped" or data.Family == "Quadruped" or data.Family == "Flyer" or data.Family == "Swimmer", data.Family)
	check(name .. " : au plus 450 pièces", #data.Boxes <= 450, #data.Boxes)
	local seen, known = {}, {}
	for _, b in data.Bones do
		known[b.Name] = true
	end
	local order = true
	for _, b in data.Bones do
		if b.Parent and not seen[b.Parent] then
			order = false
		end
		seen[b.Name] = true
	end
	check(name .. " : os parents avant les enfants", order)
	check(name .. " : os racine Hips", data.Bones[1].Name == "Hips" and data.Bones[1].Parent == nil)
	local badBox = 0
	for _, box in data.Boxes do
		if not known[box.Bone] or box.Size.X <= 0 or box.Size.Y <= 0 or box.Size.Z <= 0 then
			badBox += 1
		end
	end
	check(name .. " : boîtes sur des os connus", badBox == 0, badBox)
	local grouped = {}
	for _, list in data.Groups do
		for _, b in list do
			grouped[b] = (grouped[b] or 0) + 1
		end
	end
	local badGroup = 0
	for b in known do
		if grouped[b] ~= 1 then
			badGroup += 1
		end
	end
	check(name .. " : chaque os dans un seul groupe", badGroup == 0, badGroup)
	-- états obligatoires
	local wanted = table.clone(COMMON)
	for _, extra in EXTRA[data.Family] or {} do
		table.insert(wanted, extra)
	end
	for _, state in wanted do
		check(name .. " : état " .. state, data.Clips[state] ~= nil)
	end
	-- pistes
	for clipName, clip in data.Clips do
		local tag = name .. "." .. clipName
		check(tag .. " : durée", clip.Length > 0)
		if clip.Next then
			check(tag .. " : état suivant " .. clip.Next, data.Clips[clip.Next] ~= nil)
		end
		local badTrack = 0
		for _, tr in clip.Tracks do
			local n = #tr.Times
			if not known[tr.Bone] or tr.Channel < 1 or tr.Channel > 6 or n < 2 or tr.Times[1] ~= 0 then
				badTrack += 1
			elseif math.abs(tr.Times[n] - clip.Length) > 1 / 60 + 1e-6 then
				badTrack += 1
			else
				for i = 2, n do
					if tr.Times[i] <= tr.Times[i - 1] then
						badTrack += 1
						break
					end
				end
				if clip.Loop and math.abs(tr.Values[1] - tr.Values[n]) > 1e-6 then
					badTrack += 1
				end
			end
		end
		check(tag .. " : pistes valides", badTrack == 0, badTrack)
		for _, ev in clip.Events do
			check(tag .. " : événement dans la durée", ev[1] >= 0 and ev[1] <= clip.Length + 1e-6, ev[1])
		end
		-- lecture : valeur exacte aux clés, jamais en dehors des deux clés voisines (cubique monotone)
		local badSample = 0
		for _, tr in clip.Tracks do
			for i = 1, #tr.Times - 1 do
				local pose = DinoBuilder.Sample(clip, tr.Times[i])
				if math.abs(pose[tr.Bone][tr.Channel] - tr.Values[i]) > 1e-6 then
					badSample += 1
				end
				local mid = DinoBuilder.Sample(clip, (tr.Times[i] + tr.Times[i + 1]) / 2)[tr.Bone][tr.Channel]
				local lo, hi = math.min(tr.Values[i], tr.Values[i + 1]), math.max(tr.Values[i], tr.Values[i + 1])
				if mid < lo - 1e-6 or mid > hi + 1e-6 then
					badSample += 1
				end
			end
		end
		check(tag .. " : lecture aux clés et entre les clés", badSample == 0, badSample)
	end
	check(name .. " : Catch a un impact", (function()
		for _, ev in data.Clips.Catch.Events do
			if ev[2] == "Hit" then
				return true
			end
		end
		return false
	end)())
	check(name .. " : Walk a une vitesse", (data.Clips.Walk.Speed or 0) > 0)
	-- même pose que les aperçus (Python) : pivots posés
	local okExpect, expect = pcall(require, "./expect/" .. name)
	check(name .. " : poses attendues présentes", okExpect, expect)
	if okExpect then
		local worst = 0
		for _, e in expect do
			local clip = data.Clips[e[1]]
			if clip then
				local pose = DinoBuilder.Sample(clip, e[2])
				local solved = DinoBuilder.Solve(data, pose, 1, {})
				for _, b in data.Bones do
					local want = e[3][b.Name]
					local got = solved[b.Name] * b.Pivot
					local d = math.max(math.abs(got.X - want[1]), math.abs(got.Y - want[2]), math.abs(got.Z - want[3]))
					worst = math.max(worst, d)
				end
			end
		end
		check(name .. " : même pose que les aperçus Blender", worst < 2e-3, worst)
	end
end

-- fondu : un tour complet ne se rembobine pas (chemin le plus court)
local a = { Hips = { 0, 350, 0, 0, 0, 0 } }
local b = { Hips = { 0, 10, 0, 0, 0, 0 } }
local m = DinoBuilder.Blend(a, b, 0.5)
local ry = m.Hips[2] % 360
check("fondu au plus court", math.abs(ry) < 1e-6 or math.abs(ry - 360) < 1e-6, m.Hips[2])
local m2 = DinoBuilder.Blend(a, b, 0)
check("fondu à 0 = départ", math.abs(m2.Hips[2] - 350) < 1e-6, m2.Hips[2])

print(string.format("@@ dino: %d OK / %d FAIL", oks, fails))
