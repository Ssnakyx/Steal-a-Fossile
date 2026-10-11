-- Effets animés des mutations chez le client (docs/MUTATIONS.md) : MutationController. Chaque dino tagué « Dino » avec
-- une mutation connue a ses petits cubes (chute, montée, éclats posés sur le corps) dans workspace.MutationFx ; Rainbow
-- fait défiler l'arc-en-ciel sur ses briques. Rien sans mutation, rien de neuf au loin ou derrière la caméra, budget de
-- cubes borné, cubes rendus quand le dino perd sa mutation, son tag ou ses briques (streaming).
local T = require("./testkit")
local env = T.env

env.quiet = true
env.frame = 1 / 20 -- (images plus longues : le test va plus vite, les effets marchent pareil)
local Vector3, CFrame, Instance, Enum = env.Vector3, env.CFrame, env.Instance, env.Enum
local workspace = env.game:GetService("Workspace")

local me = env.addPlayer({ Local = true, Name = "Me" })
env.setSide("client", me)
local DinoAnimController = env.module("src/client/Controllers/DinoAnimController")
local MutationController = env.module("src/client/Controllers/MutationController")
local Economy = env.module("src/shared/Config/Economy")
local DinoBuilder = env.module("src/shared/DinoBuilder")
DinoAnimController.Init()
MutationController.Init()
DinoAnimController.Start()
MutationController.Start()
env.flush()

-- Proxy comme le serveur (DinoBuilder.CreateProxy) posé à `position`
local function proxy(species: string, mutation: string?, position: any): any
	local model = DinoBuilder.CreateProxy(species, { Mutation = mutation })
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	return model
end

local function fx(): { any }
	local folder = workspace:FindFirstChild("MutationFx")
	return if folder then folder:GetChildren() else {}
end

-- Briques que la vague Rainbow recolore (pas les détails lisses ni les Neon)
local function painted(model: any): { any }
	local out = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Bone") and part.Material ~= Enum.Material.SmoothPlastic and part.Material ~= Enum.Material.Neon then
			table.insert(out, part)
		end
	end
	return out
end

local function camera(position: any, look: any)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(position, look)
end

camera(Vector3.new(0, 5, 0), Vector3.new(0, 5, -100))

T.section("un effet par mutation")
local kinds = { Fall = true, Rise = true, Glint = true }
local count = 0
for name, effect in MutationController.Effects do
	count += 1
	T.check(Economy.Mutation(name) ~= nil, name .. " : mutation de Config.Economy")
	T.check(kinds[effect.Kind] == true, name .. " : genre d'effet connu (" .. tostring(effect.Kind) .. ")")
	T.check(effect.Rate > 0 and effect.Life > 0 and effect.Size > 0, name .. " : débit, durée et taille")
	T.check(effect.Rainbow or #effect.Colors > 0, name .. " : couleurs")
end
for _, info in Economy.Mutations do
	T.check(MutationController.Effects[info.Name] ~= nil, info.Name .. " : a son effet")
end
T.eq(count, #Economy.Mutations, "un effet par mutation, pas plus")
T.check(MutationController.Effects.Rainbow.Rainbow, "Rainbow : toutes les couleurs")

T.section("dino sans mutation")
local plain = proxy("Velociraptor", nil, Vector3.new(-12, 0, -30))
env.advance(1.5)
T.eq(MutationController.Tracked(plain), nil, "sans mutation : pas suivi")
T.eq(MutationController.Alive(), 0, "sans mutation : aucun cube")

T.section("dino Galaxy devant la caméra")
local galaxy = proxy("Velociraptor", "Galaxy", Vector3.new(0, 0, -30))
env.advance(2)
T.eq(MutationController.Tracked(galaxy), "Galaxy", "Galaxy : suivi")
local cubes = fx()
T.check(#cubes > 3, "Galaxy : des cubes (" .. #cubes .. ")")
T.eq(MutationController.Alive(), #cubes, "cubes en vie = cubes dans MutationFx")
local loose, colors, far = 0, 0, 0
local allowed = {}
for _, color in MutationController.Effects.Galaxy.Colors do
	allowed[tostring(color)] = true
end
for _, cube in cubes do
	if not cube.Anchored or cube.CanCollide or cube.CanQuery or cube.CanTouch or cube.CastShadow then
		loose += 1
	end
	if not allowed[tostring(cube.Color)] then
		colors += 1
	end
	if (cube.Position - Vector3.new(0, 0, -30)).Magnitude > 12 then
		far += 1
	end
end
T.eq(loose, 0, "cubes ancrés, sans collision, requête, contact ni ombre")
T.eq(colors, 0, "cubes aux couleurs de Galaxy")
T.eq(far, 0, "cubes posés sur le dino")
T.check(#cubes <= MutationController.MaxPerDino, "pas plus de MaxPerDino cubes par dino")
local before = {}
for _, cube in cubes do
	before[cube] = cube.Size.X
end
env.advance(0.2)
local changed = 0
for cube, size in before do
	if cube.Parent and cube.Size.X ~= size then
		changed += 1
	end
end
T.check(changed > 0, "les éclats grandissent et rapetissent")

T.section("toutes les mutations")
local row = {}
for index, info in Economy.Mutations do
	row[info.Name] = proxy("Compy", info.Name, Vector3.new(-33 + index * 5.5, 0, -45))
end
env.advance(1)
-- (cubes au hasard : on regarde pendant 3 s, une fois par image de 0.1 s)
local near: { [string]: number } = {}
local fall, rise, most = 0, 0, 0
for _ = 1, 30 do
	env.advance(0.1)
	local cubes = fx()
	most = math.max(most, #cubes)
	for _, cube in cubes do
		for name, model in row do
			if (cube.Position - model:GetPivot().Position).Magnitude < 4 then
				near[name] = (near[name] or 0) + 1
			end
		end
		-- les chutes descendent sous le dos, les montées montent au-dessus
		local frost = row.Frost:GetPivot().Position
		if (cube.Position - frost).Magnitude < 4 and cube.Position.Y < frost.Y + 0.5 then
			fall += 1
		end
		local toxic = row.Toxic:GetPivot().Position
		if (cube.Position - toxic).Magnitude < 6 and cube.Position.Y > toxic.Y + 3 then
			rise += 1
		end
	end
end
for _, info in Economy.Mutations do
	T.eq(MutationController.Tracked(row[info.Name]), info.Name, info.Name .. " : suivi")
	T.check((near[info.Name] or 0) > 0, info.Name .. " : des cubes autour")
end
T.check(fall > 0, "Frost : flocons qui tombent")
T.check(rise > 0, "Toxic : bulles qui montent")
T.check(most <= MutationController.MaxCubes, "budget de cubes respecté")

T.section("vague arc-en-ciel")
local rainbow = row.Rainbow
local parts = painted(rainbow)
T.check(#parts > 20, "Rainbow : briques peintes (" .. #parts .. ")")
local first = {}
for _, part in parts do
	first[part] = part.Color
end
env.advance(0.6)
local moved, hues = 0, {}
for _, part in parts do
	if part.Color ~= first[part] then
		moved += 1
	end
	local h = part.Color:ToHSV()
	hues[math.floor(h * 6)] = true
end
local spread = 0
for _ in hues do
	spread += 1
end
T.check(moved > #parts * 0.8, "Rainbow : les couleurs défilent (" .. moved .. "/" .. #parts .. ")")
T.check(spread >= 4, "Rainbow : plusieurs couleurs le long du corps (" .. spread .. ")")
local galaxyParts = painted(row.Galaxy)
local galaxyFirst = {}
for _, part in galaxyParts do
	galaxyFirst[part] = part.Color
end
env.advance(0.4)
local galaxyMoved = 0
for _, part in galaxyParts do
	if part.Color ~= galaxyFirst[part] then
		galaxyMoved += 1
	end
end
T.eq(galaxyMoved, 0, "les autres mutations gardent leurs couleurs")

T.section("loin ou derrière la caméra")
camera(Vector3.new(0, 5, 0), Vector3.new(0, 5, 100)) -- tout est derrière
env.advance(4)
T.eq(MutationController.Alive(), 0, "derrière la caméra : plus de cubes")
camera(Vector3.new(0, 5, 3000), Vector3.new(0, 5, -100)) -- devant, mais très loin
env.advance(4)
T.eq(MutationController.Alive(), 0, "très loin : plus de cubes")
camera(Vector3.new(0, 5, 0), Vector3.new(0, 5, -100))
env.advance(2)
T.check(MutationController.Alive() > 0, "de retour : les cubes reviennent")

T.section("mutation changée ou retirée")
galaxy:SetAttribute("Mutation", "Frost")
env.advance(0.1)
T.eq(MutationController.Tracked(galaxy), "Frost", "nouvelle mutation suivie")
galaxy:SetAttribute("Mutation", "Plutonium")
env.advance(0.1)
T.eq(MutationController.Tracked(galaxy), nil, "mutation inconnue : plus suivi")
galaxy:SetAttribute("Mutation", nil)
env.advance(0.1)
T.eq(MutationController.Tracked(galaxy), nil, "sans mutation : plus suivi")
galaxy:SetAttribute("Mutation", "Pearl")
env.advance(0.1)
T.eq(MutationController.Tracked(galaxy), "Pearl", "mutation remise : suivi")

T.section("streaming : briques défaites puis refaites")
local root = row.Lava:FindFirstChild("Root")
local spot = root.Position
local lavaColors = {}
for _, color in MutationController.Effects.Lava.Colors do
	lavaColors[tostring(color)] = true
end
-- cubes de lave (couleurs de Lava) autour du dino
local function lavaCubes(): number
	local n = 0
	for _, cube in fx() do
		if lavaColors[tostring(cube.Color)] and (cube.Position - spot).Magnitude < 8 then
			n += 1
		end
	end
	return n
end
T.check(lavaCubes() > 0, "Lava : des braises")
-- (pièce sortie du streaming : le client ne la voit plus, son PrimaryPart vaut nil ; le faux Roblox ne le fait pas seul)
row.Lava.PrimaryPart = nil
root.Parent = nil
env.advance(3)
T.eq(lavaCubes(), 0, "sans briques : pas de cubes")
local newRoot = Instance.new("Part")
newRoot.Name = "Root"
newRoot.Anchored = true
newRoot.Size = Vector3.new(0.2, 0.2, 0.2)
newRoot.Transparency = 1
newRoot.CFrame = CFrame.new(spot)
newRoot.Parent = row.Lava
env.advance(2)
T.check(lavaCubes() > 0, "briques refaites : les cubes reviennent")

T.section("tag retiré, modèle détruit")
local rubyColors = {}
for _, color in MutationController.Effects.Ruby.Colors do
	rubyColors[tostring(color)] = true
end
local rubySpot = row.Ruby:GetPivot().Position
local function rubyCubes(): number
	local n = 0
	for _, cube in fx() do
		if rubyColors[tostring(cube.Color)] and (cube.Position - rubySpot).Magnitude < 6 then
			n += 1
		end
	end
	return n
end
for _ = 1, 40 do
	if rubyCubes() > 0 then
		break
	end
	env.advance(0.05)
end
T.check(rubyCubes() > 0, "Ruby : des éclats")
row.Ruby:RemoveTag("Dino")
env.advance(0.05)
T.eq(MutationController.Tracked(row.Ruby), nil, "tag retiré : plus suivi")
T.eq(rubyCubes(), 0, "tag retiré : ses cubes rendus tout de suite")
for _, model in row do
	model:Destroy()
end
galaxy:Destroy()
plain:Destroy()
env.advance(0.1)
T.eq(MutationController.Alive(), 0, "tout détruit : aucun cube")
T.eq(#fx(), 0, "tout détruit : MutationFx vide")

T.section("beaucoup de dinos")
local crowd = {}
for index = 1, 14 do
	table.insert(crowd, proxy("Compy", "Galaxy", Vector3.new((index - 7) * 3, 0, -20)))
end
env.advance(3)
T.check(MutationController.Alive() <= MutationController.MaxCubes, "budget global respecté (" .. MutationController.Alive() .. ")")
for _, model in crowd do
	model:Destroy()
end
env.advance(0.1)
T.eq(MutationController.Alive(), 0, "foule détruite : aucun cube")

T.done("mutation_client")
