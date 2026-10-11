-- Modèles du treadmill (Map/Treadmills) : un modèle différent par niveau (0 à 50), dans l'emprise du tapis, mêmes
-- pièces à chaque construction, budget de pièces, et TreadmillService qui change le modèle du parc à chaque niveau.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Config = T.config()
local Shop = Config.Shop
local Boot = T.bootServer()
local TreadmillService = Boot.Services.TreadmillService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local RateLimit = T.lib("RateLimit")
local Treadmills = T.module("src/server/Map/Treadmills")
local Vector3 = env.Vector3
local CFrame = env.CFrame
local Workspace = env.game:GetService("Workspace")

local BUDGET = 200 -- pièces au plus par modèle (5 parcs par serveur)

-- Pièces du modèle, triées : taille, couleur, matériau et position (pour comparer deux modèles)
local function signature(model: any): string
	local lines = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local p, s, c = part.Position, part.Size, part.Color
			table.insert(lines, string.format("%.2f %.2f %.2f|%.2f %.2f %.2f|%.3f %.3f %.3f|%s|%.2f", s.X, s.Y, s.Z, p.X, p.Y, p.Z, c.R, c.G, c.B, tostring(part.Material), part.Transparency))
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

local function texts(model: any): string
	local out = {}
	for _, label in model:GetDescendants() do
		if label:IsA("TextLabel") then
			table.insert(out, label.Text)
		end
	end
	return table.concat(out, " / ")
end

T.section("un modèle par niveau")
T.eq(Treadmills.Levels, #Shop.Treadmill.Levels, "autant de modèles que de niveaux")
T.eq(Treadmills.Levels, 50, "50 niveaux")
local first, firstGrade = Treadmills.Info(1)
local last, lastGrade = Treadmills.Info(50)
T.check(first and first.Name == "Beach" and firstGrade == 1, "niveau 1 : Beach, cran 1")
T.check(last and last.Name == "Galaxy" and lastGrade == 5, "niveau 50 : Galaxy, cran 5")
T.check(Treadmills.Info(0) == nil, "niveau 0 : tapis de départ")
local origin = CFrame.new(100, 3, -50)
local bounds = Treadmills.Bounds
local seen: { [string]: number } = {}
local names: { [string]: boolean } = {}
for level = 0, Treadmills.Levels do
	local model = Treadmills.Build(level, origin)
	local theme, grade = Treadmills.Info(level)
	local label = "niveau " .. level
	T.eq(model.Name, Treadmills.ModelName, label .. " : nom du modèle")
	T.eq(model:GetAttribute("Level"), level, label .. " : attribut Level")
	local parts, stripes, solid, emitters, scripts = 0, 0, 0, 0, 0
	local outside: string? = nil
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			parts += 1
			if inst.Name == Treadmills.StripeName then
				stripes += 1
			end
			if inst.CanCollide then
				solid += 1
			end
			if not inst.Anchored then
				outside = "pièce pas ancrée"
			end
			local half = inst.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = origin:PointToObjectSpace((inst.CFrame * CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position)
						if math.abs(corner.X) > bounds.X or corner.Z < bounds.MinZ or corner.Z > bounds.MaxZ or corner.Y > bounds.Height or corner.Y < -1.5 then
							outside = string.format("%s hors de l'emprise (%.1f, %.1f, %.1f)", inst.Name, corner.X, corner.Y, corner.Z)
						end
					end
				end
			end
		elseif inst:IsA("ParticleEmitter") then
			emitters += 1
		elseif inst:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	T.check(outside == nil, label .. " : dans l'emprise du tapis (" .. tostring(outside) .. ")")
	T.check(parts <= BUDGET, label .. " : " .. parts .. " pièces (budget " .. BUDGET .. ")")
	T.eq(stripes, 5, label .. " : 5 bandes du tapis")
	T.check(solid <= 3, label .. " : seuls le socle, le marchepied et la console sont solides (" .. solid .. ")")
	T.eq(scripts, 0, label .. " : aucun script")
	T.eq(emitters, if grade >= 5 then 1 else 0, label .. " : particules au cran 5 seulement")
	if theme then
		T.check(string.find(texts(model), "LV " .. level, 1, true) ~= nil, label .. " : niveau écrit sur le panneau")
		T.eq(model:GetAttribute("Theme"), theme.Name, label .. " : thème")
		names[theme.Name] = true
	end
	local sig = signature(model)
	T.check(seen[sig] == nil, label .. " : différent du niveau " .. tostring(seen[sig]))
	seen[sig] = level
	T.eq(signature(Treadmills.Build(level, origin)), sig, label .. " : mêmes pièces à chaque construction")
	-- chaque cran ajoute du détail au précédent du même thème
	if grade > 1 then
		local before = Treadmills.Build(level - 1, origin)
		T.check(#model:GetDescendants() > #before:GetDescendants(), label .. " : plus détaillé que le niveau " .. (level - 1))
	end
end
local themeCount = 0
for _ in names do
	themeCount += 1
end
T.eq(themeCount, 10, "10 thèmes")
local belt = env.create("Part")
Treadmills.Paint(belt, 12)
T.eq(belt.Color, (Treadmills.Info(12) :: any).Belt, "couleur du tapis du thème")
Treadmills.Paint(belt, 0)
T.check(belt.Color ~= (Treadmills.Info(12) :: any).Belt, "couleur du tapis de départ")
T.clean("modèles sans erreur")

T.section("tapis des parcs")
local map = Workspace:FindFirstChild("Map")
local plotModels = 0
for _, inst in (map :: any):GetDescendants() do
	if inst.Name == Treadmills.ModelName then
		plotModels += 1
		T.eq(inst:GetAttribute("Level"), 0, "parc libre : tapis de départ")
	end
end
T.eq(plotModels, 5, "un modèle de tapis par parc")

local function modelOf(beltPart: any): any
	local found = nil
	local count = 0
	for _, child in beltPart.Parent:GetChildren() do
		if child.Name == Treadmills.ModelName then
			found = child
			count += 1
		end
	end
	T.eq(count, 1, "un seul modèle autour du tapis")
	return found
end

local player = T.join({ UserId = 301, Character = true })
env.flush()
local plotBelt = PlotService.Get(player).Treadmill
T.check(plotBelt ~= nil, "tapis du parc")
T.eq(modelOf(plotBelt):GetAttribute("Level"), 0, "pas acheté : tapis de départ")
local label = plotBelt:FindFirstChild("TreadmillLabel")
T.check(label and label.StudsOffsetWorldSpace.Y + Treadmills.BeltY > Treadmills.Bounds.Height, "panneau du prix au-dessus de l'arche")
MoneyService.Add(player, Shop.Treadmill.Levels[1].Cash, "Test")
RateLimit.Reset(player)
local ok = env.invokeServer(player, "BuyTreadmill", "Cash")
T.check(ok, "niveau 1 acheté")
local dressed = modelOf(plotBelt)
T.eq(dressed:GetAttribute("Level"), 1, "modèle du niveau 1")
T.eq(dressed:GetAttribute("Theme"), "Beach", "thème Beach")
T.eq(plotBelt.Color, (Treadmills.Info(1) :: any).Belt, "tapis à la couleur du thème")
local expected = Treadmills.Build(1, plotBelt.CFrame * CFrame.new(0, -Treadmills.BeltY, 0))
T.eq(signature(dressed), signature(expected), "posé sous le tapis du parc")
TreadmillService.SetLevel(player, 37)
T.eq(modelOf(plotBelt):GetAttribute("Level"), 37, "niveau fixé : modèle 37")
local before = modelOf(plotBelt)
TreadmillService.SetLevel(player, 37)
T.check(modelOf(plotBelt) == before, "même niveau : modèle gardé")
T.check(plotBelt:FindFirstChild("TreadmillPrompt") ~= nil, "prompt d'achat toujours sur le tapis")
T.leave(player)
env.flush()
T.eq(modelOf(plotBelt):GetAttribute("Level"), 0, "propriétaire parti : tapis de départ")
T.eq(plotBelt.Color, env.Color3.fromRGB(36, 36, 40), "couleur de départ")
T.clean("tapis des parcs sans erreur")

T.done("speed_models")
