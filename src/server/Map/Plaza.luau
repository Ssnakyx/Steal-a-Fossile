--!strict
-- La place du spawn (brief 10) : sol général, pavés devant les parcs, haies entre les parcs, lampadaires, tableau de la
-- route, camp de fouilles, forêt derrière les parcs et murs invisibles autour. La route part du milieu de la place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Kit = require(script.Parent.Kit)
local Plots = require(script.Parent.Plots)
local Props = require(script.Parent.Props)

local Plaza = {}

local rgb = Color3.fromRGB
local shade = Kit.shade

local GRASS = rgb(90, 142, 66)
local PAVING = rgb(204, 190, 160)
local CURB = rgb(152, 142, 126)
local HEDGE = rgb(66, 128, 58)
local SAND = rgb(236, 214, 162)

-- Demi-largeur de la place (au-delà des parcs extrêmes)
function Plaza.HalfWidth(): number
	local cfg = Map.Plots
	return Plots.CenterX(cfg.Count) + cfg.Width / 2 + Map.Plaza.Margin
end

-- Mur invisible et collidable
function Plaza.Barrier(parent: Instance, size: Vector3, cframe: CFrame): Part
	local part = Kit.block(parent, size, cframe, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	part.Name = "Barrier"
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function speedText(speed: number): string
	return if speed <= 0 then "No speed needed" else Format.Number(speed) .. " speed"
end

-- Tableau « THE ROUTE » : les 8 zones et leur vitesse conseillée
local function routeBoard(parent: Instance, cframe: CFrame)
	local m = Kit.group("RouteBoard")
	local wood = rgb(120, 80, 48)
	for _, x in { -8.4, 8.4 } do
		Kit.prop(m, Vector3.new(1.2, 14, 1.2), cframe * CFrame.new(x, 7, 0), wood)
	end
	local board = Kit.prop(m, Vector3.new(16, 11, 0.6), cframe * CFrame.new(0, 8.5, 0), rgb(236, 222, 190))
	Kit.prop(m, Vector3.new(17.2, 0.8, 1), cframe * CFrame.new(0, 14.4, 0), wood)
	Kit.prop(m, Vector3.new(17.2, 0.8, 1), cframe * CFrame.new(0, 2.6, 0), wood)
	local lines: { Kit.Line } = { { Text = "THE ROUTE", Color = rgb(255, 214, 90), Weight = 1.6 } }
	for _, zone in Zones.List do
		table.insert(lines, {
			Text = string.format("%d. %s  -  %s", zone.Index, zone.Name, speedText(zone.Speed)),
			Color = rgb(255, 255, 255),
			Weight = 1,
		})
	end
	local gui = Kit.text(board, Enum.NormalId.Front, "Text", lines)
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			child.TextXAlignment = if child.Name == "Line1" then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			child.TextColor3 = if child.Name == "Line1" then rgb(150, 70, 30) else rgb(80, 50, 30)
			child.TextStrokeTransparency = 1
		end
	end
	m.Parent = parent
end

local function hedge(parent: Instance, x: number, z0: number, z1: number, width: number, rng: Random)
	local length = z1 - z0
	Kit.block(parent, Vector3.new(width, 6, length), CFrame.new(x, Map.GroundTop + 3, (z0 + z1) / 2), HEDGE)
	local count = math.floor(length / 12)
	for k = 0, count - 1 do
		local z = z0 + (k + 0.5) * length / count
		Kit.prop(parent, Vector3.new(width + 0.6, Kit.range(rng, 1.2, 2.4), 8), CFrame.new(x, Map.GroundTop + 6.6, z), if k % 2 == 0 then shade(HEDGE, -0.12) else shade(HEDGE, 0.06))
	end
end

function Plaza.Build(parent: Instance, ctx: Kit.Ctx): Folder
	local folder = Kit.folder("Spawn", parent)
	local deco = Kit.folder("Decor", folder)
	local gt = Map.GroundTop
	local rng = ctx.Rng
	local hw = Plaza.HalfWidth()
	local depth = Map.Plaza.Depth
	local parkDepth = Map.Plots.Depth
	local back = -parkDepth - Map.Plaza.Back
	local route = Map.Route.Width / 2 + Map.Route.Border
	ctx.Lights = 0
	ctx.LightBudget = Map.Lights.Plaza

	-- sol général (sous les parcs, visible entre les haies et dans la forêt), pavés de la place
	local z0, z1 = back - 240, depth
	Kit.block(parent, Vector3.new(hw * 2 + 600, 2, z1 - z0), CFrame.new(0, gt - 1.2, (z0 + z1) / 2), GRASS).Name = "SpawnGround"
	Kit.block(folder, Vector3.new(hw * 2, 2, depth), CFrame.new(0, gt - 1, depth / 2), PAVING).Name = "Plaza"
	Kit.prop(folder, Vector3.new(hw * 2, 0.3, 3), CFrame.new(0, gt + 0.15, 1.5), CURB)
	for _, z in { 26, 50 } do
		Kit.prop(folder, Vector3.new(hw * 2, 0.2, 2), CFrame.new(0, gt + 0.1, z), shade(PAVING, 0.1))
	end
	for index = 1, Map.Plots.Count do
		local x = Plots.CenterX(index)
		Kit.prop(folder, Vector3.new(Map.Plots.EntranceWidth, 0.4, 14), CFrame.new(x, gt + 0.2, 7), rgb(214, 198, 168))
		Kit.prop(folder, Vector3.new(Map.Plots.EntranceWidth + 2, 0.3, 14), CFrame.new(x, gt + 0.15, 7), shade(CURB, 0.1))
	end
	-- sentier de sable du milieu de la place jusqu'à la Beach, bordé de pierres
	Kit.prop(folder, Vector3.new(Map.Route.PathWidth, 0.4, depth - 14), CFrame.new(0, gt + 0.2, 14 + (depth - 14) / 2), SAND)
	for z = 18, depth - 2, 7 do
		for _, side in { -1, 1 } do
			Kit.prop(folder, Vector3.new(1.6, 0.8, 2.4), CFrame.new(side * (Map.Route.PathWidth / 2 + 1), gt + 0.4, z), if z % 2 == 0 then CURB else shade(CURB, -0.12))
		end
	end

	-- haies entre les parcs et sur les bords, lampadaires et bancs devant les haies
	local cfg = Map.Plots
	for index = 1, cfg.Count - 1 do
		local x = (Plots.CenterX(index) + Plots.CenterX(index + 1)) / 2
		hedge(folder, x, -parkDepth + 2, -2, cfg.Gap - 2, rng)
		Props.lamp(deco, CFrame.new(x, gt, 5), 1, ctx, nil)
		if index % 2 == 1 then
			Props.bench(deco, CFrame.new(x + 7, gt, 6) * CFrame.Angles(0, math.pi, 0), 1, rng, nil)
		end
	end
	local edge = Plots.CenterX(cfg.Count) + cfg.Width / 2
	for _, side in { -1, 1 } do
		hedge(folder, side * (hw - 2), back + 2, depth, 4, rng)
		for z = -parkDepth + 12, -10, 22 do
			local x = side * Kit.range(rng, edge + 7, hw - 8)
			if rng:NextNumber() < 0.5 then
				Props.pine(deco, CFrame.new(x, gt, z), Kit.range(rng, 1, 1.3), rng, nil)
			else
				Props.bigTree(deco, CFrame.new(x, gt, z), Kit.range(rng, 0.8, 1), rng, nil)
			end
		end
		-- haie de devant, de la route jusqu'au bord de la place
		local x0, x1 = route, hw
		Kit.block(folder, Vector3.new(x1 - x0, 7, 5), CFrame.new(side * (x0 + x1) / 2, gt + 3.5, depth + 2.5), HEDGE)
		Plaza.Barrier(folder, Vector3.new(x1 - Map.Route.Width / 2, Map.Route.BarrierHeight, 1), CFrame.new(side * (Map.Route.Width / 2 + x1) / 2, gt + Map.Route.BarrierHeight / 2, depth + 0.5))
	end
	for _, side in { -1, 1 } do
		Props.lamp(deco, CFrame.new(side * (Map.Route.PathWidth / 2 + 5), gt, 40), 1, ctx, nil)
	end
	-- jardinières (pierre, terre, arbre) au milieu de la place, en face des haies
	for index = 1, cfg.Count - 1 do
		local x = (Plots.CenterX(index) + Plots.CenterX(index + 1)) / 2
		if math.abs(x) > Map.Route.PathWidth then
			local planter = CFrame.new(x, gt, 36)
			Kit.block(folder, Vector3.new(12, 2, 12), planter * CFrame.new(0, 1, 0), CURB)
			Kit.prop(deco, Vector3.new(10.4, 0.4, 10.4), planter * CFrame.new(0, 2.1, 0), rgb(110, 80, 52))
			if index % 2 == 0 then
				Props.bigTree(deco, planter * CFrame.new(0, 2.3, 0), 0.75, rng, nil)
			else
				Props.palm(deco, planter * CFrame.new(0, 2.3, 0), 0.8, rng, nil)
			end
			Props.bush(deco, planter * CFrame.new(3.2, 2.3, 3.2), 0.5, rng, nil)
			Props.flowers(deco, planter * CFrame.new(-3, 2.3, -3), 0.8, rng, nil)
		end
	end

	-- tableau de la route et panneau du sentier
	routeBoard(deco, CFrame.new(-36, gt, 56))
	Props.signpost(deco, CFrame.new(Map.Route.PathWidth / 2 + 6, gt, 60), 1.2, "DIG SITES", nil)

	-- camp de fouilles devant, de part et d'autre du sentier
	local camp: { (CFrame) -> () } = {
		function(cf)
			Props.tent(deco, cf, Kit.range(rng, 0.9, 1.1), rng, nil)
		end,
		function(cf)
			Props.crate(deco, cf, 1, rng, nil)
			Props.crate(deco, cf * CFrame.new(2.8, 0, 0.4), 0.9, rng, nil)
			Props.crate(deco, cf * CFrame.new(1.4, 2.6, 0.2), 0.8, rng, nil)
		end,
		function(cf)
			Props.barrel(deco, cf, 1, rng, nil)
			Props.barrel(deco, cf * CFrame.new(2.6, 0, 0.8), 1, rng, nil)
			Props.shovel(deco, cf * CFrame.new(-1.6, 0, 0), 1, rng, nil)
		end,
		function(cf)
			Props.wheelbarrow(deco, cf, 1, rng, nil)
			Props.dirtPile(deco, cf * CFrame.new(3.5, 0, -1), 0.9, rng, nil)
		end,
		function(cf)
			Props.rock(deco, cf, 1.1, rng, nil)
			Props.fern(deco, cf * CFrame.new(3, 0, 1), 0.9, rng, nil)
		end,
		function(cf)
			Props.bench(deco, cf, 1, rng, nil)
		end,
	}
	for _, side in { -1, 1 } do
		local x = 72
		while x < hw - 14 do
			local z = Kit.range(rng, 54, 64)
			local cf = CFrame.new(side * x, gt, z) * CFrame.Angles(0, math.pi + Kit.range(rng, -0.25, 0.25), 0)
			camp[rng:NextInteger(1, #camp)](cf)
			x += Kit.range(rng, 26, 36)
		end
	end

	-- forêt derrière les parcs : collines et arbres, fond du décor
	local forest = Kit.folder("Forest", folder)
	for k = 0, 7 do
		local x = -hw + (k + 0.5) * hw * 2 / 8 + Kit.range(rng, -20, 20)
		Kit.dome(forest, CFrame.new(x, gt - 0.5, back - Kit.range(rng, 6, 14)), Kit.range(rng, 30, 40), Kit.range(rng, 14, 24), 3, Kit.pick(rng, { rgb(74, 128, 60), rgb(64, 116, 56), rgb(84, 138, 64) }))
	end
	for k = 0, 23 do
		local x = -hw + (k + 0.5) * hw * 2 / 24 + Kit.range(rng, -8, 8)
		local z = -parkDepth - Kit.range(rng, 8, Map.Plaza.Back - 6)
		local cf = CFrame.new(x, gt - 0.2, z)
		if k % 4 == 0 then
			Props.bigTree(forest, cf, Kit.range(rng, 1, 1.3), rng, nil)
		else
			Props.pine(forest, cf, Kit.range(rng, 1.2, 1.7), rng, nil)
		end
	end

	-- murs invisibles : fond, côtés
	local height = Map.Route.BarrierHeight
	Plaza.Barrier(folder, Vector3.new(hw * 2, height, 1), CFrame.new(0, gt + height / 2, -parkDepth - 2.5))
	for _, side in { -1, 1 } do
		Plaza.Barrier(folder, Vector3.new(1, height, depth + parkDepth + 3), CFrame.new(side * (hw - 3.5), gt + height / 2, (depth - parkDepth - 3) / 2))
	end

	-- apparition de secours (avant que PlotService place le joueur dans son parc)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, gt + 0.5, 32)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	return folder
end

return Plaza
