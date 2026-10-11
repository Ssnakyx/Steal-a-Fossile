--!strict
-- Les parcs du spawn (brief 10, Config.Map.Plots.Count : 5), alignés sur X et tournés vers la route (+Z). Chaque parc : sol (Floor, zone sûre),
-- palissade, portail avec enseigne au nom du joueur (Sign), point d'apparition (Spawn), entrée (Entrance), 6 cuves de
-- réanimation (Tank1..Tank6), enclos (Enclosure), treadmill (Treadmill, tagué « Treadmill ») et labo de fusion (Lab).
-- Les noms des points d'ancrage sont ceux de docs/BOUCLE.md (lus par PlotService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Plots = {}

local rgb = Color3.fromRGB
local shade = Kit.shade

local GRASS = rgb(122, 178, 84)
local PEN = rgb(100, 156, 70)
local STONE = rgb(158, 150, 140)
local PATH = rgb(206, 190, 160)
local WOOD = rgb(156, 104, 62)
local WOOD_DARK = rgb(116, 76, 46)
local METAL = rgb(96, 102, 112)
local GLASS = rgb(186, 232, 242)

-- Couleur de chaque parc (portail, drapeaux, tapis d'entrée) : on reconnaît le sien de loin. Les 5 premières sont
-- celles des 5 parcs (les plus différentes), les suivantes servent si Config.Map.Plots.Count augmente.
Plots.Accents = {
	rgb(226, 72, 64),
	rgb(240, 200, 60),
	rgb(90, 190, 80),
	rgb(70, 120, 225),
	rgb(150, 90, 220),
	rgb(240, 140, 50),
	rgb(60, 190, 200),
	rgb(230, 100, 170),
} :: { Color3 }

-- Centre X du parc `index`
function Plots.CenterX(index: number): number
	local cfg = Map.Plots
	return (index - (cfg.Count + 1) / 2) * (cfg.Width + cfg.Gap)
end

-- Palissade de (x0, z0) à (x1, z1), sur un seul axe : socle de pierre, planches, lisse et poteaux
local function fence(model: Instance, origin: CFrame, x0: number, z0: number, x1: number, z1: number)
	local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
	local length = if alongX then math.abs(x1 - x0) else math.abs(z1 - z0)
	local mid = origin * CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
	local function run(width: number, height: number, y: number, color: Color3)
		local size = if alongX then Vector3.new(length, height, width) else Vector3.new(width, height, length)
		Kit.block(model, size, mid * CFrame.new(0, y + height / 2, 0), color)
	end
	run(1.6, 1.4, 0, STONE)
	-- planches de 10 studs, deux teintes
	local boards = math.max(1, math.floor(length / 10 + 0.5))
	local step = length / boards
	for k = 0, boards - 1 do
		local t = -length / 2 + (k + 0.5) * step
		local size = if alongX then Vector3.new(step, 4.5, 0.9) else Vector3.new(0.9, 4.5, step)
		local offset = if alongX then CFrame.new(t, 1.4 + 2.25, 0) else CFrame.new(0, 1.4 + 2.25, t)
		Kit.block(model, size, mid * offset, if k % 2 == 0 then WOOD else shade(WOOD, 0.1))
	end
	run(1.2, 0.6, 5.9, WOOD_DARK)
	-- poteaux tous les 20 studs environ, aux deux bouts compris
	local posts = math.max(1, math.floor(length / 20 + 0.5))
	for k = 0, posts do
		local t = -length / 2 + k * length / posts
		local offset = if alongX then CFrame.new(t, 0, 0) else CFrame.new(0, 0, t)
		Kit.block(model, Vector3.new(2, 7.4, 2), mid * offset * CFrame.new(0, 3.7, 0), WOOD_DARK)
		Kit.block(model, Vector3.new(2.6, 0.8, 2.6), mid * offset * CFrame.new(0, 7.8, 0), STONE)
	end
end

-- Cuve de réanimation : socle et couvercle ronds, cylindre de verre (point d'ancrage TankN), montants
local function tank(model: Instance, origin: CFrame, index: number, x: number, z: number)
	local base = origin * CFrame.new(x, 0.4, z)
	Kit.disc(model, base, 3.6, 1, METAL, nil, true)
	local glass = Kit.block(model, Vector3.new(5, 7, 5), base * CFrame.new(0, 1 + 3.5, 0), GLASS, Enum.Material.SmoothPlastic)
	glass.Name = "Tank" .. index
	glass.Transparency = 0.6
	-- liquide vert au fond de la cuve (sous le bloc posé par ReviveService au centre)
	local liquid = Kit.prop(model, Vector3.new(4.4, 1.6, 4.4), base * CFrame.new(0, 1 + 0.8, 0), rgb(110, 230, 150), Enum.Material.SmoothPlastic)
	liquid.Transparency = 0.15
	Kit.disc(model, base * CFrame.new(0, 8, 0), 3.6, 0.8, METAL, nil, true)
	Kit.prop(model, Vector3.new(2, 0.8, 2), base * CFrame.new(0, 9.2, 0), shade(METAL, -0.25))
	for _, corner in { { -2.6, -2.6 }, { 2.6, -2.6 }, { -2.6, 2.6 }, { 2.6, 2.6 } } do
		Kit.prop(model, Vector3.new(0.5, 7, 0.5), base * CFrame.new(corner[1], 4.5, corner[2]), shade(METAL, 0.2))
	end
	-- tuyau vers le fond
	Kit.prop(model, Vector3.new(0.8, 0.8, 2.4), base * CFrame.new(0, 2, -3.6), shade(METAL, 0.3))
	Kit.prop(model, Vector3.new(1.6, 0.6, 1.6), base * CFrame.new(0, 0.3, 3.2), rgb(90, 220, 140), Enum.Material.Neon).Transparency = 0.3
end

local function labo(model: Instance, origin: CFrame, x: number, z: number)
	local base = origin * CFrame.new(x, 0, z)
	Kit.block(model, Vector3.new(18, 0.6, 14), base * CFrame.new(0, 0.3, 0), shade(METAL, -0.45))
	local console = Kit.block(model, Vector3.new(6, 4.5, 3), base * CFrame.new(0, 0.6 + 2.25, -2), rgb(56, 92, 104))
	console.Name = "Lab"
	local screen = Kit.prop(model, Vector3.new(4.4, 2, 0.2), base * CFrame.new(0, 3.6, -0.45), rgb(110, 240, 200), Enum.Material.Neon)
	screen.Transparency = 0.25
	Kit.prop(model, Vector3.new(6.4, 0.6, 3.4), base * CFrame.new(0, 5.4, -2), shade(METAL, 0.2))
	for k, c in { rgb(230, 80, 70), rgb(250, 200, 60), rgb(80, 200, 100) } do
		Kit.prop(model, Vector3.new(0.7, 0.4, 0.7), base * CFrame.new(-1.6 + (k - 1) * 1.6, 1.6, -0.3), c)
	end
	for _, side in { -1, 1 } do
		local pod = base * CFrame.new(side * 6, 0.6, -2)
		Kit.disc(model, pod, 2.4, 0.8, METAL, nil, true)
		local glass = Kit.block(model, Vector3.new(3.4, 5, 3.4), pod * CFrame.new(0, 0.8 + 2.5, 0), rgb(190, 245, 210), Enum.Material.SmoothPlastic)
		glass.Transparency = 0.6
		Kit.disc(model, pod * CFrame.new(0, 5.8, 0), 2.4, 0.7, METAL, nil, true)
		Kit.prop(model, Vector3.new(3, 0.6, 0.6), pod * CFrame.new(-side * 2.8, 4.2, 0), shade(METAL, 0.3))
	end
	local board = Kit.prop(model, Vector3.new(8, 1.6, 0.4), base * CFrame.new(0, 7.4, -2), WOOD_DARK)
	Kit.text(board, Enum.NormalId.Back, "Title", { { Text = "FUSION LAB", Color = rgb(170, 255, 220), Weight = 1 } })
end

local function treadmill(model: Instance, origin: CFrame, x: number, z: number)
	local base = origin * CFrame.new(x, 0, z)
	Kit.block(model, Vector3.new(8, 1, 16), base * CFrame.new(0, 0.5, 0), rgb(70, 74, 82))
	local belt = Kit.block(model, Vector3.new(6, 0.4, 14), base * CFrame.new(0, 1.2, 0), rgb(36, 36, 40), Enum.Material.SmoothPlastic)
	belt.Name = "Treadmill"
	belt:AddTag("Treadmill")
	for k = -2, 2 do
		Kit.prop(model, Vector3.new(6, 0.06, 0.5), base * CFrame.new(0, 1.42, k * 2.8), rgb(80, 80, 88), Enum.Material.SmoothPlastic)
	end
	for _, side in { -1, 1 } do
		Kit.prop(model, Vector3.new(0.5, 3.6, 0.5), base * CFrame.new(side * 3.6, 2.8, 6.8), METAL)
		Kit.prop(model, Vector3.new(0.4, 0.4, 6), base * CFrame.new(side * 3.6, 4.4, 4), shade(METAL, -0.3))
	end
	Kit.block(model, Vector3.new(7.6, 2, 0.8), base * CFrame.new(0, 4.6, 7.2) * CFrame.Angles(math.rad(-20), 0, 0), rgb(60, 64, 72))
	local screen = Kit.prop(model, Vector3.new(3, 1, 0.1), base * CFrame.new(0, 4.75, 6.75) * CFrame.Angles(math.rad(-20), 0, 0), rgb(120, 220, 255), Enum.Material.Neon)
	screen.Transparency = 0.3
	local board = Kit.prop(model, Vector3.new(7, 1.4, 0.4), base * CFrame.new(0, 6.6, 7.2), WOOD_DARK)
	Kit.text(board, Enum.NormalId.Back, "Title", { { Text = "TREADMILL", Color = rgb(255, 230, 140), Weight = 1 } })
end

local function pen(model: Instance, origin: CFrame, cfg: typeof(Map.Plots))
	local width, x0, z0, z1 = cfg.Width - 10, -(cfg.Width - 10) / 2, -cfg.Depth + 7, -46
	local depth = z0 - z1
	local plate = Kit.prop(model, Vector3.new(width, 0.2, -depth), origin * CFrame.new(0, 0.1, (z0 + z1) / 2), PEN)
	plate.Name = "Enclosure"
	-- clôture basse (décor : l'enclos reste ouvert), ouverte devant au milieu
	local function rail(xa: number, za: number, xb: number, zb: number)
		local alongX = xa ~= xb
		local length = if alongX then math.abs(xb - xa) else math.abs(zb - za)
		local mid = origin * CFrame.new((xa + xb) / 2, 0, (za + zb) / 2)
		for _, y in { 1.3, 2.5 } do
			Kit.prop(model, if alongX then Vector3.new(length, 0.4, 0.4) else Vector3.new(0.4, 0.4, length), mid * CFrame.new(0, y, 0), WOOD)
		end
		local posts = math.max(1, math.floor(length / 10 + 0.5))
		for k = 0, posts do
			local t = -length / 2 + k * length / posts
			Kit.prop(model, Vector3.new(0.8, 3.2, 0.8), mid * (if alongX then CFrame.new(t, 1.6, 0) else CFrame.new(0, 1.6, t)), WOOD_DARK)
		end
	end
	local x1 = -x0
	rail(x0, z0, x1, z0)
	rail(x0, z0, x0, z1)
	rail(x1, z0, x1, z1)
	rail(x0, z1, -5, z1)
	rail(5, z1, x1, z1)
	-- abreuvoir devant l'enclos et petite enseigne
	Kit.prop(model, Vector3.new(6, 1.2, 2), origin * CFrame.new(-12, 0.6, z1 + 2.4), WOOD_DARK)
	Kit.prop(model, Vector3.new(5.2, 0.2, 1.4), origin * CFrame.new(-12, 1.15, z1 + 2.4), rgb(80, 160, 220), Enum.Material.SmoothPlastic)
	local board = Kit.prop(model, Vector3.new(6, 1.4, 0.4), origin * CFrame.new(9, 3.6, z1 + 0.6), WOOD)
	Kit.prop(model, Vector3.new(0.5, 3, 0.5), origin * CFrame.new(9, 1.5, z1 + 0.6), WOOD_DARK)
	Kit.text(board, Enum.NormalId.Back, "Title", { { Text = "DINO PEN", Color = Color3.new(1, 1, 1), Weight = 1 } })
end

local function gate(model: Instance, origin: CFrame, accent: Color3, half: number)
	for _, side in { -1, 1 } do
		local x = side * (half + 1.5)
		Kit.block(model, Vector3.new(3.4, 1.6, 3.4), origin * CFrame.new(x, 0.8, -0.6), shade(STONE, 0.15))
		Kit.block(model, Vector3.new(3, 12, 3), origin * CFrame.new(x, 7.6, -0.6), STONE)
		Kit.block(model, Vector3.new(3.6, 0.8, 3.6), origin * CFrame.new(x, 13.9, -0.6), shade(STONE, 0.15))
		Kit.prop(model, Vector3.new(2.4, 1, 2.4), origin * CFrame.new(x, 14.8, -0.6), shade(STONE, -0.1))
		-- bannière et drapeau à la couleur du parc
		Kit.prop(model, Vector3.new(2.2, 5, 0.3), origin * CFrame.new(x, 8, 1.05), accent)
		Kit.prop(model, Vector3.new(2.2, 0.6, 0.35), origin * CFrame.new(x, 10.7, 1.05), WOOD_DARK)
		Kit.prop(model, Vector3.new(0.4, 5, 0.4), origin * CFrame.new(x, 17.8, -0.6), WOOD_DARK)
		Kit.prop(model, Vector3.new(3, 2, 0.2), origin * CFrame.new(x + side * 1.7, 19.2, -0.6), accent)
	end
	Kit.block(model, Vector3.new(half * 2, 1.6, 1.8), origin * CFrame.new(0, 12.4, -0.6), WOOD_DARK)
	-- enseigne sur la poutre : texte « <Nom>'s Park » écrit par PlotService (Label > Text), recopié côté intérieur
	local sign = Kit.prop(model, Vector3.new(half * 2 - 1, 4.6, 0.8), origin * CFrame.new(0, 15.5, -0.6), rgb(236, 214, 170))
	sign.Name = "Sign"
	local textColor = rgb(92, 54, 30)
	local outside = Kit.text(sign, Enum.NormalId.Back, "Label", { { Text = "Empty park", Name = "Text", Color = textColor, Weight = 1 } })
	local inside = Kit.text(sign, Enum.NormalId.Front, "LabelInside", { { Text = "Empty park", Name = "Text", Color = textColor, Weight = 1 } })
	for _, gui in { outside, inside } do
		local label = gui:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.TextStrokeTransparency = 1
		end
	end
	for _, y in { 13.1, 17.9 } do
		Kit.prop(model, Vector3.new(half * 2 - 0.4, 0.5, 1.1), origin * CFrame.new(0, y, -0.6), WOOD_DARK)
	end
	for _, side in { -1, 1 } do
		Kit.prop(model, Vector3.new(0.5, 5.3, 1.1), origin * CFrame.new(side * (half - 0.45), 15.5, -0.6), WOOD_DARK)
	end
end

-- Construit Plot<index> dans `parent`
function Plots.Build(index: number, parent: Instance, ctx: Kit.Ctx): Model
	local cfg = Map.Plots
	local W, D = cfg.Width, cfg.Depth
	local half = cfg.EntranceWidth / 2
	local accent = Plots.Accents[index] or Plots.Accents[1]
	local origin = CFrame.new(Plots.CenterX(index), Map.GroundTop, 0)
	ctx.Lights = 0
	ctx.LightBudget = Map.Lights.Plot

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local floor = Kit.block(model, Vector3.new(W, 2, D), origin * CFrame.new(0, -1, -D / 2), GRASS)
	floor.Name = "Floor"
	model.PrimaryPart = floor

	-- palissade : côtés, fond, devant en deux morceaux autour du portail
	local inset = 1
	fence(model, origin, -W / 2 + inset, -inset, -W / 2 + inset, -D + inset)
	fence(model, origin, W / 2 - inset, -inset, W / 2 - inset, -D + inset)
	fence(model, origin, -W / 2 + inset, -D + inset, W / 2 - inset, -D + inset)
	fence(model, origin, -W / 2 + inset, -inset, -half - 3.2, -inset)
	fence(model, origin, half + 3.2, -inset, W / 2 - inset, -inset)
	gate(model, origin, accent, half)

	local entrance = Kit.prop(model, Vector3.new(half * 2, 0.1, 2), origin * CFrame.new(0, 0.05, -1), accent)
	entrance.Name = "Entrance"
	Kit.disc(model, origin * CFrame.new(0, 0, -13), 4, 0.3, rgb(236, 230, 214))
	Kit.disc(model, origin * CFrame.new(0, 0.3, -13), 2.5, 0.1, accent)
	local spawn = Kit.anchor(model, "Spawn", Vector3.new(6, 0.2, 6), origin * CFrame.new(0, 0.5, -13) * CFrame.Angles(0, math.pi, 0))
	spawn.Transparency = 1

	-- allée en dalles de l'entrée aux cuves, puis jusqu'à l'enclos
	for row = 0, 6 do
		for column = 0, 1 do
			if row ~= 2 and row ~= 3 then
				Kit.prop(model, Vector3.new(4.6, 0.3, 3.6), origin * CFrame.new(-2.5 + column * 5, 0.15, -3 - row * 4), if (row + column) % 2 == 0 then PATH else shade(PATH, 0.08))
			end
		end
	end
	Kit.prop(model, Vector3.new(66, 0.3, 4), origin * CFrame.new(0, 0.15, -29.5), shade(PATH, 0.04))
	Kit.prop(model, Vector3.new(10, 0.3, 8), origin * CFrame.new(0, 0.15, -41.5), PATH)

	-- cuves : deux rangées de 3 de part et d'autre de l'allée
	Kit.prop(model, Vector3.new(30, 0.4, 10), origin * CFrame.new(-19, 0.2, -36), shade(STONE, -0.15))
	Kit.prop(model, Vector3.new(30, 0.4, 10), origin * CFrame.new(19, 0.2, -36), shade(STONE, -0.15))
	for k, x in { -28, -19, -10, 10, 19, 28 } do
		tank(model, origin, k, x, -36)
	end

	labo(model, origin, -24, -17)
	treadmill(model, origin, 25, -18)
	pen(model, origin, cfg)

	-- lampadaires du portail (les 2 lumières du parc), tonneaux, caisses et buissons
	local deco = Kit.folder("Decor", model)
	for _, side in { -1, 1 } do
		Props.lamp(deco, origin * CFrame.new(side * (half + 6), 0, -3.5), 0.9, ctx, nil)
	end
	local rng = ctx.Rng
	Props.barrel(deco, origin * CFrame.new(-36, 0, -5), 1, rng, nil)
	Props.barrel(deco, origin * CFrame.new(-33, 0, -4.5), 0.9, rng, nil)
	Props.crate(deco, origin * CFrame.new(-35.5, 0, -9), 1, rng, nil)
	Props.crate(deco, origin * CFrame.new(35.5, 0, -30), 1, rng, nil)
	Props.wheelbarrow(deco, origin * CFrame.new(34, 0, -40) * CFrame.Angles(0, 0.6, 0), 1, rng, nil)
	for _, spot in { { -36.5, -116 }, { 36.5, -116 }, { -36.5, -50 }, { 36.5, -50 } } do
		Props.bush(deco, origin * CFrame.new(spot[1], 0, spot[2]), 0.8, rng, nil)
	end
	Props.fern(deco, origin * CFrame.new(-36, 0, -76), 0.9, rng, nil)
	Props.fern(deco, origin * CFrame.new(36, 0, -92), 0.9, rng, nil)

	model.Parent = parent
	return model
end

return Plots
