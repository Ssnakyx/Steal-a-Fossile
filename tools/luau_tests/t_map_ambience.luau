-- Ambiances de la map : Config.Ambience (une ambiance par zone, bloom modéré, pas de rayons partout, particules sous le
-- plafond), décor lumineux et flottant des zones (côté serveur : inerte, dans la map, lieux marquants), effets de
-- Lighting posés une seule fois avec l'ambiance de la place, test FossilDebug « ambience ». Côté client
-- (AmbienceController) : régions calquées sur la map, fondus aux frontières, ambiance du lieu dès la première image,
-- fondu en douceur après une téléportation puis plus aucune écriture de Lighting, particules, aurores, planète,
-- étoiles filantes et ptérosaures selon la zone, effets recréés s'ils disparaissent, décor flottant qui bouge près du
-- joueur seulement, caméra seule quand il n'y a pas de personnage.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Workspace = env.game:GetService("Workspace")
local Lighting = env.game:GetService("Lighting")
local CollectionService = env.game:GetService("CollectionService")
local terrain = env.Instance.new("Terrain")
terrain.Parent = Workspace

local Boot = T.bootServer()
local DebugService = Boot.Services.DebugService
local Ambience = T.module("src/shared/Config/Ambience")
local Map = T.module("src/shared/Config/Map")
local Zones = T.module("src/shared/Config/Zones")
local MapBuilder = T.module("src/server/Map/MapBuilder")
local Vector3, CFrame, Enum = env.Vector3, env.CFrame, env.Enum
local gt = Map.GroundTop
local hw = Map.Route.Width / 2

local names = { "Plaza" }
for _, zone in Zones.List do
	table.insert(names, zone.Name)
end
local starts, routeEnd = MapBuilder.Layout()

-- Milieu d'une zone sur Z
local function middle(name: string): number
	return starts[name] + MapBuilder.Length(name) / 2
end

local function zoneModel(name: string): any
	return Workspace.Map.Zones:FindFirstChild(name)
end

-- Modèles d'un nom donné dans le décor d'une zone
local function models(name: string, kind: string): { any }
	local list = {}
	for _, item in zoneModel(name):GetDescendants() do
		if item:IsA("Model") and item.Name == kind then
			table.insert(list, item)
		end
	end
	return list
end

local function inert(part: any): boolean
	return not part.CanCollide and not part.CanQuery and not part.CanTouch
end

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

local function colorNear(a: any, b: any, tolerance: number): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) <= tolerance
end

-- ===================================================================== réglages

T.section("réglages")
local moteTotal = 0
for _, name in names do
	local p = Ambience.Regions[name]
	T.check(p ~= nil, name .. " : une ambiance")
	if p then
		T.check(p.ClockTime >= 0 and p.ClockTime < 24, name .. " : heure")
		T.check(p.Brightness > 0.5 and p.Brightness <= 4, name .. " : luminosité")
		T.check(math.abs(p.Exposure) <= 0.6, name .. " : exposition")
		T.check(p.Atmosphere.Density >= 0 and p.Atmosphere.Density <= 0.55, name .. " : brume, on voit loin")
		T.check(p.Atmosphere.Offset >= 0 and p.Atmosphere.Offset <= 1, name .. " : brume, décalage")
		T.check(p.Atmosphere.Glare >= 0 and p.Atmosphere.Glare <= 10 and p.Atmosphere.Haze >= 0 and p.Atmosphere.Haze <= 10, name .. " : brume, éclat")
		T.check(p.Clouds.Cover >= 0 and p.Clouds.Cover <= 1 and p.Clouds.Density >= 0 and p.Clouds.Density <= 1, name .. " : nuages")
		T.check(p.Sky.Stars >= 0 and p.Sky.Stars <= 5000, name .. " : étoiles (5000 au plus)")
		T.check(p.Sky.Sun > 0 and p.Sky.Sun <= 60 and p.Sky.Moon > 0 and p.Sky.Moon <= 60, name .. " : soleil et lune")
		T.check(math.abs(p.Grade.Brightness) <= 0.15 and math.abs(p.Grade.Contrast) <= 0.3, name .. " : couleurs, lumière et contraste")
		T.check(math.abs(p.Grade.Saturation) <= 0.4, name .. " : couleurs, saturation")
		T.check(p.Bloom.Intensity >= 0 and p.Bloom.Intensity <= 0.75 and p.Bloom.Threshold >= 1, name .. " : bloom modéré")
		T.check(p.SunRays.Intensity >= 0 and p.SunRays.Intensity <= 0.15, name .. " : rayons du soleil discrets")
		local total = 0
		for kind, n in p.Motes do
			T.check(Ambience.Motes.Kinds[kind] ~= nil, name .. " : particules " .. kind .. " définies")
			total += n
		end
		T.check(total <= Ambience.Motes.Max, name .. " : " .. total .. " particules (plafond " .. Ambience.Motes.Max .. ")")
		moteTotal += total
		T.check(p.Aurora >= 0 and p.Aurora <= 1 and p.Planet >= 0 and p.Planet <= 1, name .. " : aurores et planète de 0 à 1")
		T.check(p.ShootingStars >= 0 and p.ShootingStars <= 2, name .. " : étoiles filantes")
		T.check(p.Birds >= 0 and p.Birds <= Ambience.Sky.Birds.Pool and p.Birds == math.floor(p.Birds), name .. " : ptérosaures")
		if p.Aurora > 0 then
			T.check(#p.AuroraColors >= Ambience.Sky.Aurora.Ribbons, name .. " : une couleur par ruban d'aurore")
		end
		if name ~= "Plaza" then
			T.check(total > 0 or p.Birds > 0 or p.Aurora > 0, name .. " : quelque chose de vivant (particules, ciel)")
		end
	end
end
T.check(moteTotal > 100, "des particules dans les zones")
for index = 2, #names do
	local a, b = Ambience.Regions[names[index - 1]], Ambience.Regions[names[index]]
	if a and b then
		T.check(math.abs(a.ClockTime - b.ClockTime) > 0.3 or not colorNear(a.Atmosphere.Color, b.Atmosphere.Color, 0.05), names[index] .. " : ambiance différente de " .. names[index - 1])
	end
end
for kind, def in Ambience.Motes.Kinds do
	T.check(#def.Colors > 0, kind .. " : couleurs")
	T.check(def.Size[1] > 0 and def.Size[1] <= def.Size[2] and def.Size[2] <= 1.5, kind .. " : petits cubes")
	T.check(def.Life[1] > 0 and def.Life[1] <= def.Life[2], kind .. " : durée de vie")
	T.check(def.Low <= def.High, kind .. " : hauteurs")
	T.check(def.Transparency >= 0 and def.Transparency < 1 and def.Blink >= 0 and def.Blink <= 1, kind .. " : transparence")
end
T.check(Ambience.Blend > 0 and Ambience.Response > 0 and Ambience.LightingRate > 0, "fondu, vitesse, écritures")

-- ===================================================================== serveur

T.section("serveur : Lighting")
local plaza = Ambience.Regions.Plaza
local function single(className: string): any
	local found, count = nil, 0
	for _, child in Lighting:GetChildren() do
		if child:IsA(className) then
			found = child
			count += 1
		end
	end
	T.eq(count, 1, "un seul " .. className .. " dans Lighting")
	return found
end
T.eq(Lighting.ClockTime, plaza.ClockTime, "heure de la place")
T.eq(Lighting.Brightness, plaza.Brightness, "luminosité de la place")
local atmosphere = single("Atmosphere")
T.check(atmosphere and atmosphere.Density == plaza.Atmosphere.Density, "brume de la place")
local sky = single("Sky")
T.check(sky and sky.StarCount == plaza.Sky.Stars, "ciel de la place")
local bloom = single("BloomEffect")
T.check(bloom and bloom.Intensity == plaza.Bloom.Intensity, "bloom de la place")
single("SunRaysEffect")
local grade = Lighting:FindFirstChild(Ambience.GradeName)
T.check(grade ~= nil and grade:IsA("ColorCorrectionEffect") and grade.Saturation == plaza.Grade.Saturation, "couleurs de la place (" .. Ambience.GradeName .. ")")
local clouds = terrain:FindFirstChildOfClass("Clouds")
T.check(clouds ~= nil and clouds.Enabled and clouds.Cover == plaza.Clouds.Cover, "nuages du Terrain")
MapBuilder.Lighting()
single("Atmosphere")
single("Sky")
T.eq(#Lighting:GetChildren(), 5, "relancé : effets réutilisés, pas doublés")

T.section("serveur : décor lumineux")
for _, zone in Zones.List do
	local model = zoneModel(zone.Name)
	local glowing, loud = 0, 0
	for _, item in model.Decor:GetDescendants() do
		if item:IsA("BasePart") and item.Material == Enum.Material.Neon then
			glowing += 1
			if not inert(item) or item.CastShadow then
				loud += 1
			end
		end
	end
	T.check(glowing >= 40, zone.Name .. " : " .. glowing .. " pièces lumineuses")
	T.eq(loud, 0, zone.Name .. " : décor lumineux inerte")
	-- (la forêt a surtout des champignons lumineux)
	T.check(#models(zone.Name, "GlowCrystal") >= (if zone.Name == "Fern Forest" then 5 else 8), zone.Name .. " : cristaux lumineux")
end
-- cristaux qui sortent des parois (sans raycasts ici : posés au pied de la paroi, entre 3 et 12 studs de haut)
for _, name in { "Beach", "Swamp", "Canyon", "Glacier", "Volcano", "Meteor Crater" } do
	local onWall = 0
	for _, crystal in models(name, "GlowCrystal") do
		local p = crystal:GetChildren()[1].Position
		if math.abs(p.X) > hw - 1 and math.abs(p.X) < hw + 4 and p.Y > gt + 2 and p.Y < gt + 13 then
			onWall += 1
		end
	end
	T.check(onWall >= 4, name .. " : cristaux sur les parois (" .. onWall .. ")")
end
T.check(#models("Fern Forest", "GlowShroom") >= 8, "Fern Forest : champignons lumineux")
T.check(#models("Swamp", "GlowShroom") >= 8 and #models("Swamp", "Wisp") >= 8, "Swamp : champignons et feux follets")
T.check(#models("Canyon", "Geode") >= 5, "Canyon : géodes")
T.check(#models("Volcano", "LavaPool") >= 3 and #models("Volcano", "SmokePlume") == 1, "Volcano : mares de lave et panache")
T.check(#models("Ocean Trench", "Jellyfish") >= 8 and #models("Ocean Trench", "Anemone") >= 8, "Ocean Trench : méduses et anémones")
T.eq(#models("Meteor Crater", "FloatShard"), 8, "Meteor Crater : éclats flottants autour du cratère")

T.section("serveur : lieux marquants")
T.check(#models("Beach", "Ribcage") == 1 and #models("Beach", "Skull") == 1, "Beach : squelette fossile")
T.check(#models("Canyon", "Ribcage") == 1, "Canyon : squelette dégagé par les fouilles")
local bridge = models("Canyon", "RopeBridge")[1]
T.check(bridge ~= nil, "Canyon : pont de cordes")
if bridge then
	local lo, hi, low, solid = math.huge, -math.huge, math.huge, 0
	for _, part in bridge:GetDescendants() do
		if part:IsA("BasePart") then
			lo, hi = math.min(lo, part.Position.X), math.max(hi, part.Position.X)
			low = math.min(low, part.Position.Y)
			solid += if inert(part) then 0 else 1
		end
	end
	T.eq(solid, 0, "Canyon : pont sans collision")
	T.check(lo < -hw and hi > hw, "Canyon : le pont traverse toute la route")
	T.check(low > gt + 20, "Canyon : le pont passe haut au-dessus des joueurs")
end
T.eq(#models("Glacier", "Ribcage"), 1, "Glacier : squelette pris dans la glace")
local ice = 0
for _, part in zoneModel("Glacier").Ground:GetChildren() do
	if part:IsA("BasePart") and part.Material == Enum.Material.Ice and part.Transparency >= 0.4 then
		ice += 1
		T.check(part.CanCollide and not part.CanQuery and not part.CastShadow, "Glacier : bloc de glace solide, transparent, sans ombre")
	end
end
T.eq(ice, 1, "Glacier : un bloc de glace translucide")
T.check(#models("Glacier", "GlowCrystal") >= 14, "Glacier : bosquet de cristaux")
local shell = 0
for _, part in zoneModel("Ocean Trench").Ground:GetChildren() do
	if part:IsA("BasePart") and part.Color.R > part.Color.B + 0.1 then
		shell += 1
	end
end
T.check(shell >= 30, "Ocean Trench : ammonite géante (" .. shell .. " blocs)")

T.section("serveur : décor flottant")
local floating = CollectionService:GetTagged(Ambience.Float.Tag)
T.check(#floating >= 24, #floating .. " modèles flottants")
local badFloat = 0
for _, item in floating do
	local ok = item:IsA("Model") and item:IsDescendantOf(Workspace.Map.Zones) and item.Parent.Name == "Decor"
	ok = ok and item.PrimaryPart ~= nil and item.PrimaryPart:IsDescendantOf(item)
	ok = ok and (item:GetAttribute("FloatHeight") or 0) > 0 and (item:GetAttribute("FloatSpeed") or 0) > 0
	ok = ok and type(item:GetAttribute("FloatSpin")) == "number"
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") and not inert(part) then
			ok = false
		end
	end
	if not ok then
		badFloat += 1
	end
end
T.eq(badFloat, 0, "modèles flottants : dans le décor, pièce centrale, réglages, sans collision")

T.section("FossilDebug ambience")
T.check(table.find(DebugService.Tests(), "ambience") ~= nil, "test en jeu ambience")
local okCount, failCount, lines = DebugService.RunTest("ambience")
T.check(okCount > 10, "ambience : vérifications faites")
T.eq(failCount, 0, "ambience : aucun échec")
if failCount > 0 then
	print(table.concat(lines, "\n"))
end

-- ===================================================================== calculs du client

local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return me:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
env.flush()
local Controller = ClientBoot.Controllers.AmbienceController
T.check(Controller ~= nil, "AmbienceController chargé")
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

T.section("régions")
local regions = Controller.Regions()
T.eq(#regions, #Zones.List + 1, "la place puis les 8 zones")
T.eq(regions[1].Name, "Plaza", "la place d'abord")
T.eq(regions[1].Z1, Map.Plaza.Depth, "la place s'arrête au début de la route")
for index, zone in Zones.List do
	local region = regions[index + 1]
	T.eq(region.Name, zone.Name, zone.Name .. " : dans l'ordre")
	T.eq(region.Z0, starts[zone.Name], zone.Name .. " : commence comme dans la map")
	T.eq(region.Z0, regions[index].Z1, zone.Name .. " : bout à bout")
end
T.eq(regions[#regions].Z1, math.huge, "la dernière zone va jusqu'au bout (falaise de fin)")
T.check(routeEnd > starts["Meteor Crater"], "fin de route après la dernière zone")

T.section("fondus")
for _, zone in Zones.List do
	local a, b, t = Controller.Mix(middle(zone.Name))
	T.check(a == zone.Name and b == zone.Name and t == 0, zone.Name .. " : au milieu, son ambiance seule")
end
local a0, b0, t0 = Controller.Mix(-500)
T.check(a0 == "Plaza" and b0 == "Plaza" and t0 == 0, "dans les parcs : la place")
local edge = starts.Glacier
local aEdge, bEdge, tEdge = Controller.Mix(edge)
T.check(aEdge == "Canyon" and bEdge == "Glacier" and near(tEdge, 0.5, 1e-6), "à la frontière : moitié-moitié")
local previous, steady = -1, true
for z = edge - Ambience.Blend / 2 - 5, edge + Ambience.Blend / 2 + 5, 2.5 do
	local a, b, t = Controller.Mix(z)
	local share = if a == b then (if a == "Glacier" then 1 else 0) else t
	steady = steady and share >= previous - 1e-9
	previous = share
end
T.check(steady, "le fondu avance sans à-coup")
local aNan = Controller.Mix(0 / 0)
T.eq(aNan, "Plaza", "position invalide : la place")
T.eq((Controller.Mix(1e9)), "Meteor Crater", "très loin : la dernière zone")
local plazaCopy = Controller.Copy(plaza)
local glacier = Ambience.Regions.Glacier
local half = Controller.Blend(plaza, glacier, 0.5)
T.check(near(half.ClockTime, (plaza.ClockTime + glacier.ClockTime) / 2, 1e-6), "mélange : heure à mi-chemin")
T.check(near(half.Motes.Snow, glacier.Motes.Snow / 2, 1e-6), "mélange : moitié de la neige")
T.check(near(half.Aurora, glacier.Aurora / 2, 1e-6), "mélange : aurores à moitié")
T.eq(plaza.ClockTime, plazaCopy.ClockTime, "mélange : la config n'est pas touchée")
local zero = Controller.Blend(plaza, glacier, 0)
local one = Controller.Blend(plaza, glacier, 1)
T.check(zero.ClockTime == plaza.ClockTime and one.ClockTime == glacier.ClockTime, "mélange : bouts du fondu")
T.check(colorNear(one.Atmosphere.Color, glacier.Atmosphere.Color, 1e-4) and one.Motes.Snow == glacier.Motes.Snow, "mélange : couleurs et particules du bout")
T.eq(zero.Motes.Snow, nil, "mélange : pas de neige sur la place")
local inPlace = Controller.Copy(plaza)
Controller.Blend(inPlace, glacier, 1, inPlace)
T.eq(inPlace.ClockTime, glacier.ClockTime, "mélange sur place")
T.check(Controller.Blend(plaza, glacier, 0 / 0).ClockTime == plaza.ClockTime, "part invalide : sans effet")
T.eq(Controller.PresetOf("Nowhere").ClockTime, plaza.ClockTime, "région inconnue : la place")
T.eq(Controller.TargetAt(middle("Volcano")).ClockTime, Ambience.Regions.Volcano.ClockTime, "ambiance visée au milieu du volcan")

-- ===================================================================== chez le joueur

local character = me.Character
local root = character:FindFirstChild("HumanoidRootPart")
local camera = Workspace.CurrentCamera

local function goTo(z: number)
	root.CFrame = CFrame.new(0, gt + 3, z)
	camera.CFrame = CFrame.new(0, gt + 12, z - 20)
end

-- (images de 1/20 s : l'ambiance ne dépend pas de la cadence, le test va plus vite)
local function settle(seconds: number)
	local frame = env.frame
	env.frame = 1 / 20
	env.advance(seconds)
	env.frame = frame
end

T.section("joueur : arrivée")
goTo(-60)
settle(0.1)
T.check(near(Lighting.ClockTime, plaza.ClockTime, 0.01), "dans son parc : heure de la place")
local folder = camera:FindFirstChild("Ambience")
T.check(folder ~= nil and folder:IsA("Folder"), "dossier Ambience dans la caméra")

T.section("joueur : téléportation au glacier")
goTo(middle("Glacier"))
settle(0.2)
T.check(Lighting.ClockTime < plaza.ClockTime - 0.05 and Lighting.ClockTime > glacier.ClockTime + 1, "fondu en douceur (pas de saut)")
settle(8)
T.check(near(Lighting.ClockTime, glacier.ClockTime, 0.02), "heure du glacier")
T.check(near(atmosphere.Density, glacier.Atmosphere.Density, 0.005), "brume du glacier")
T.check(colorNear(Lighting.ColorShift_Top, glacier.SunTint, 0.02), "teinte du soleil du glacier")
T.check(near(grade.Saturation, glacier.Grade.Saturation, 0.005), "couleurs du glacier")
T.check(near(clouds.Cover, glacier.Clouds.Cover, 0.005), "nuages du glacier")
local stats = Controller.Stats()
T.check((stats.Kinds.Snow or 0) > 10 and (stats.Kinds.Snow or 0) <= glacier.Motes.Snow, "neige autour du joueur (" .. tostring(stats.Kinds.Snow) .. ")")
T.check(stats.Motes <= Ambience.Motes.Max, "particules sous le plafond")
T.check(stats.Aurora, "aurores au-dessus du glacier")
T.check(not stats.Planet, "pas de planète au glacier")
T.eq(stats.Birds, 0, "pas de ptérosaures au glacier")
local writes = 0
local connection = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
	writes += 1
end)
settle(4)
T.eq(writes, 0, "ambiance atteinte : Lighting n'est plus écrit")
connection:Disconnect()

T.section("joueur : pièces de l'ambiance")
local badParts, count = 0, 0
for _, part in folder:GetDescendants() do
	if part:IsA("BasePart") then
		count += 1
		if not (part.Anchored and inert(part) and not part.CastShadow) then
			badParts += 1
		end
	end
end
T.check(count > 20, count .. " pièces d'ambiance chez le joueur")
T.eq(badParts, 0, "pièces d'ambiance ancrées, sans collision ni ombre")
local shown = 0
for _, part in folder:GetChildren() do
	if part:IsA("BasePart") and part.Transparency < 1 then
		shown += 1
		T.check((part.Position - camera.CFrame.Position).Magnitude < 600, "pièce d'ambiance près de la caméra")
	end
end
T.check(shown > 10, "particules et aurores visibles")

T.section("joueur : cratère de la météorite")
goTo(middle("Meteor Crater"))
settle(8)
local meteor = Ambience.Regions["Meteor Crater"]
T.check(near(Lighting.ClockTime, meteor.ClockTime, 0.02), "nuit au cratère")
T.check(near(sky.StarCount, meteor.Sky.Stars, 1), "ciel étoilé")
stats = Controller.Stats()
T.check(stats.Planet and stats.Aurora, "planète et aurores")
T.check((stats.Kinds.Stardust or 0) > 10, "poussière d'étoiles")
T.eq(stats.Kinds.Snow, nil, "plus de neige")
local starSeen = false
for _ = 1, 400 do
	settle(0.1)
	if Controller.Stats().Stars > 0 then
		starSeen = true
		break
	end
end
T.check(starSeen, "étoiles filantes")

T.section("joueur : plage")
goTo(middle("Beach"))
settle(6)
stats = Controller.Stats()
T.eq(stats.Birds, Ambience.Regions.Beach.Birds, "ptérosaures dans le ciel de la plage")
T.check(not stats.Aurora and not stats.Planet, "ni aurores ni planète à la plage")
T.eq(stats.Motes, 0, "pas de particules à la plage")
goTo(-60)
settle(6)
T.eq(Controller.Stats().Birds, 0, "les ptérosaures s'en vont")

T.section("joueur : décor flottant")
goTo(middle("Swamp"))
settle(0.5)
stats = Controller.Stats()
T.eq(stats.Floaters, #floating, "tous les modèles flottants suivis")
T.check(stats.Moving > 0 and stats.Moving < stats.Floaters, "seuls ceux près du joueur bougent (" .. stats.Moving .. "/" .. stats.Floaters .. ")")
local wisp = models("Swamp", "Wisp")[1]
local farShard = models("Meteor Crater", "FloatShard")[1]
local wispCore, shardCore = wisp.PrimaryPart, farShard.PrimaryPart
local shardStart = shardCore.Position
local ys, xz = {}, true
local wispStart: any = nil
for _ = 1, 40 do
	settle(0.1)
	local p = wispCore.Position
	wispStart = wispStart or p
	table.insert(ys, p.Y)
	xz = xz and near(p.X, wispStart.X, 1e-3) and near(p.Z, wispStart.Z, 1e-3)
end
local lowY, highY = math.min(table.unpack(ys)), math.max(table.unpack(ys))
local height = wisp:GetAttribute("FloatHeight")
T.check(highY - lowY > 0.2, "le feu follet monte et descend")
T.check(highY - lowY <= 2 * height + 1e-3, "dans sa hauteur de vol")
T.check(xz, "il reste à sa place")
T.eq(shardCore.Position, shardStart, "le décor loin du joueur ne bouge pas")
local removed = models("Swamp", "Wisp")[2]
removed:Destroy()
settle(0.1)
T.eq(Controller.Stats().Floaters, #floating - 1, "modèle retiré : plus suivi")

T.section("joueur : robustesse")
atmosphere:Destroy()
sky:Destroy()
settle(2.5)
T.check(Lighting:FindFirstChildOfClass("Atmosphere") ~= nil and Lighting:FindFirstChildOfClass("Sky") ~= nil, "effets supprimés : recréés")
me.Character = nil
camera.CFrame = CFrame.new(0, gt + 12, middle("Volcano"))
settle(8)
T.check(near(Lighting.ClockTime, Ambience.Regions.Volcano.ClockTime, 0.02), "sans personnage : la caméra décide")
T.check((Controller.Stats().Kinds.Embers or 0) > 0, "braises du volcan")
env.advance(0.1)

T.done("map_ambience")
