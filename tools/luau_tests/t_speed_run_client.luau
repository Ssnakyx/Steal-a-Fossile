-- Course sur le treadmill (côté client) : TreadmillController. Immobile sur son tapis : posé au milieu, tourné vers la
-- console, animation de course en boucle, bandes du tapis qui défilent ; descend en bougeant, en sautant, en quittant
-- le tapis ou en mourant, remonte après le délai. Chaussures « 👟 +N » à chaque gain de vitesse sur le tapis (vrai gain,
-- plafond à l'écran), rien ailleurs ni sur le tapis d'un autre.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local PlotService = Boot.Services.PlotService
local SpeedService = Boot.Services.SpeedService
local TreadmillService = Boot.Services.TreadmillService
local SpeedConfig = T.module("src/shared/Config/Speed")
local Treadmills = T.module("src/server/Map/Treadmills")
local Format = T.module("src/shared/Format")
local Vector3, CFrame, Enum = env.Vector3, env.CFrame, env.Enum
local UserInputService = env.game:GetService("UserInputService")

local RUN = SpeedConfig.Treadmill.Run
local BASE = SpeedConfig.Treadmill.BaseGain

local me = env.addPlayer({ Local = true, Name = "Me", Character = true })
env.waitUntil(function()
	return me:GetAttribute("Ready") == true
end, "joueur prêt", 60)
env.flush()
local other = T.join({ UserId = 902, Character = true })
env.flush()

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
env.flush()
local Run = ClientBoot.Controllers.TreadmillController
T.check(Run ~= nil, "TreadmillController chargé")
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

local belt = PlotService.Get(me).Treadmill
local otherBelt = PlotService.Get(other).Treadmill
T.check(belt ~= nil and otherBelt ~= nil and belt ~= otherBelt, "un tapis par parc")
local character = me.Character
local humanoid = character:FindFirstChildOfClass("Humanoid")
local root = character.HumanoidRootPart

local function stand(on: any, x: number, z: number)
	character:PivotTo(on.CFrame * CFrame.new(x, on.Size.Y / 2 + 3, z))
end

-- Chaussures nouvelles depuis `known` (ensemble des précédentes)
local function fresh(known: { [any]: boolean }): { any }
	local list = {}
	for _, gui in me.PlayerGui:GetChildren() do
		if gui.Name == "TreadmillPop" and not known[gui] then
			table.insert(list, gui)
		end
	end
	return list
end

local function known(): { [any]: boolean }
	local set = {}
	for _, gui in me.PlayerGui:GetChildren() do
		set[gui] = true
	end
	return set
end

local function pops(): { any }
	local list = {}
	for _, gui in me.PlayerGui:GetChildren() do
		if gui.Name == "TreadmillPop" then
			table.insert(list, gui)
		end
	end
	return list
end

T.section("monter et courir")
stand(belt, 1.8, -4)
humanoid.MoveDirection = Vector3.zero
env.advance(0.1)
T.check(not Run.IsRunning(), "pas tout de suite : il faut s'arrêter un instant")
env.advance(RUN.StillSeconds + 0.3)
T.check(Run.IsRunning(), "immobile sur son tapis : il court")
local relative = belt.CFrame:PointToObjectSpace(root.Position)
T.near(relative.X, 0, 0.01, "posé au milieu du tapis (X)")
T.near(relative.Z, 0, 0.01, "posé au milieu du tapis (Z)")
T.check(relative.Y > belt.Size.Y / 2 and relative.Y < belt.Size.Y / 2 + 5, "debout sur la bande (" .. relative.Y .. ")")
local forward = belt.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
T.check(root.CFrame.LookVector:Dot(forward) > 0.99, "tourné vers la console")
local track = Run.Track()
T.check(track ~= nil and track.IsPlaying, "animation de course jouée")
T.check(track and track.Looped and track.Priority == Enum.AnimationPriority.Action, "en boucle, par-dessus l'idle")

-- bandes du tapis : elles glissent vers l'arrière et restent sur le tapis
local model = belt.Parent:FindFirstChild(SpeedConfig.Treadmill.ModelName)
local stripes = {}
for _, child in model:GetChildren() do
	if child.Name == SpeedConfig.Treadmill.StripeName then
		table.insert(stripes, child)
	end
end
T.eq(#stripes, 5, "5 bandes")
local before = {}
for index, stripe in stripes do
	before[index] = belt.CFrame:PointToObjectSpace(stripe.Position).Z
end
env.advance(0.25)
local moved, inside = 0, true
for index, stripe in stripes do
	local z = belt.CFrame:PointToObjectSpace(stripe.Position).Z
	if math.abs(z - before[index]) > 0.1 then
		moved += 1
	end
	if math.abs(z) > belt.Size.Z / 2 + 0.01 then
		inside = false
	end
end
T.eq(moved, 5, "les bandes défilent")
T.check(inside, "les bandes restent sur le tapis")
for _ = 1, 40 do
	env.advance(0.1)
end
inside = true
for _, stripe in stripes do
	if math.abs(belt.CFrame:PointToObjectSpace(stripe.Position).Z) > belt.Size.Z / 2 + 0.01 then
		inside = false
	end
end
T.check(inside, "toujours sur le tapis après plusieurs tours")
T.check(Run.IsRunning(), "il court toujours (AFK)")

T.section("chaussures +N")
for _, gui in pops() do
	gui:Destroy()
end
env.advance(RUN.PopSeconds + 0.1)
local seen = known()
local beforeSpeed = SpeedService.Get(me)
TreadmillService.Tick()
local gain = SpeedService.Get(me) - beforeSpeed
env.advance(0.05)
T.near(gain, BASE * SpeedConfig.Treadmill.FreeMultiplier, 0.001, "gain gratuit du tapis")
local shown = fresh(seen)
T.eq(#shown, 1, "une chaussure sort à côté du coureur")
local last = shown[#shown]
local text = last and last:FindFirstChild("Text")
T.check(text and string.find(text.Text, "+" .. Format.Number(gain), 1, true) ~= nil, "elle montre le vrai gain (" .. tostring(text and text.Text) .. ")")
T.check(text and string.find(text.Text, "👟", 1, true) ~= nil, "avec une petite chaussure")
T.check(last.Adornee == root, "accrochée au personnage")
local offset = last.StudsOffset
T.check(math.abs(offset.X) >= 2, "à côté du personnage, pas dessus")
env.advance(RUN.PopSeconds * 0.95)
T.check(last.Parent ~= nil and last.StudsOffset.Y > offset.Y + 2, "elle monte")
T.eq(text.TextTransparency, 1, "et s'efface")
env.advance(RUN.PopSeconds)
T.eq(last.Parent, nil, "puis disparaît")
TreadmillService.SetLevel(me, 3)
env.flush()
for _, gui in pops() do
	gui:Destroy()
end
env.advance(RUN.PopSeconds + 0.1)
seen = known()
beforeSpeed = SpeedService.Get(me)
TreadmillService.Tick()
gain = SpeedService.Get(me) - beforeSpeed
env.advance(0.05)
shown = fresh(seen)
text = shown[#shown] and shown[#shown]:FindFirstChild("Text")
T.check(text and string.find(text.Text, "+" .. Format.Number(gain), 1, true) ~= nil, "niveau 3 : +" .. Format.Number(gain))
for _ = 1, 20 do
	Run.Pop(10)
end
T.check(#pops() <= RUN.MaxPops, "pas plus de " .. RUN.MaxPops .. " chaussures à la fois (" .. #pops() .. ")")
env.advance(RUN.PopSeconds + 0.2)
local left = 0
for _, gui in pops() do
	if gui.Text.Text == "👟 +10" then
		left += 1
	end
end
T.eq(left, 0, "toutes reparties")

T.section("descendre")
humanoid.MoveDirection = Vector3.new(0, 0, 1)
env.advance(0.05)
T.check(not Run.IsRunning(), "il bouge : il descend")
T.check(not track.IsPlaying, "animation arrêtée")
humanoid.MoveDirection = Vector3.zero
env.advance(RUN.StillSeconds + 0.05)
T.check(not Run.IsRunning(), "pas de remontée avant le délai")
env.advance(RUN.Cooldown + RUN.StillSeconds)
T.check(Run.IsRunning(), "immobile de nouveau : il remonte")
T.check(Run.Track() == track, "même animation réutilisée (pas une nouvelle à chaque montée)")
env.fire(env.signal(UserInputService, "JumpRequest"))
env.flush()
T.check(not Run.IsRunning(), "saut : il descend")
env.advance(RUN.Cooldown + RUN.StillSeconds + 0.3)
T.check(Run.IsRunning(), "remonte après le saut")
stand(belt, 0, -30)
env.advance(0.05)
T.check(not Run.IsRunning(), "hors du tapis : il descend")
stand(belt, 0, 0)
env.advance(RUN.Cooldown + RUN.StillSeconds + 0.3)
T.check(Run.IsRunning(), "de retour sur le tapis")
humanoid.Health = 0
env.advance(0.05)
T.check(not Run.IsRunning(), "mort : il descend")
humanoid.Health = 100

T.section("ailleurs")
-- (modèle du tapis refait par le serveur pendant la course : nouvelles bandes, sans erreur)
env.advance(RUN.Cooldown + RUN.StillSeconds + 0.3)
T.check(Run.IsRunning(), "court")
TreadmillService.SetLevel(me, 12)
env.advance(0.3)
local newModel = belt.Parent:FindFirstChild(Treadmills.ModelName)
T.eq(newModel:GetAttribute("Level"), 12, "modèle du niveau 12")
T.check(Run.IsRunning(), "il court toujours sur le nouveau modèle")
humanoid.MoveDirection = Vector3.new(1, 0, 0)
env.advance(0.05)
humanoid.MoveDirection = Vector3.zero
stand(otherBelt, 0, 0)
env.advance(RUN.Cooldown + RUN.StillSeconds + 0.5)
T.check(not Run.IsRunning(), "tapis d'un autre joueur : pas de course")
for _, gui in pops() do
	gui:Destroy()
end
SpeedService.Add(me, 100, "Test")
env.flush()
T.eq(#pops(), 0, "vitesse gagnée ailleurs : pas de chaussure")
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")
T.clean("course sans erreur")

T.done("speed_run_client")
