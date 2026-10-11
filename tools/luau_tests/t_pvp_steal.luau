-- Vol sur la route (brief 7) : pelle (bonk, recharge 2 s, portée vérifiée), bloc au sol ramassable par tous sauf celui
-- qui l'a lâché pendant 3 s, retour au gisement en 30 s, zone sûre des parcs, protection débutant 10 min, chute.
-- Appels hostiles : bonk de loin, bonk dans un parc, spam, cibles invalides, ramassage pendant les 3 s.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
-- (gardiens éteints : ce test ne parle que du vol entre joueurs)
Boot.Services.GuardianService.SetEnabled(false)
local AdminService = Boot.Services.AdminService
local CarryService = Boot.Services.CarryService
local DigSiteService = Boot.Services.DigSiteService
local DroppedBlockService = Boot.Services.DroppedBlockService
local PlotService = Boot.Services.PlotService
local PvpService = Boot.Services.PvpService
local SpeedService = Boot.Services.SpeedService
local ZoneService = Boot.Services.ZoneService
local Pvp = T.module("src/shared/Config/Pvp")
local Zones = T.module("src/shared/Config/Zones")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local Workspace = env.game:GetService("Workspace")
local CollectionService = env.game:GetService("CollectionService")
local Vector3, CFrame = env.Vector3, env.CFrame

local function slots(zone: string): { any }
	local list = {}
	for _, site in DigSiteService.Sites() do
		if site.Zone == zone then
			for _, slot in site.Slots do
				if slot.State == "Present" then
					table.insert(list, slot)
				end
			end
		end
	end
	return list
end

local function grab(player, slot)
	RateLimit.Reset(player)
	local part = slot.Part
	player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 1.5, 4)))
	local prompt = part.GrabPrompt
	env.fire(env.signal(prompt, "PromptButtonHoldBegan"), player)
	env.advance(Zones.Dig.GrabTime + 0.05)
	env.fire(env.signal(prompt, "Triggered"), player)
	env.flush()
end

-- Bloc de la Beach sur le dos (hors tutoriel)
local function carryOne(player): (any, any)
	for _, slot in slots("Beach") do
		if not slot.Block.Tutorial then
			local block = slot.Block
			grab(player, slot)
			return slot, block
		end
	end
	error("plus de bloc à la Beach")
end

local function rootOf(player)
	return player.Character.HumanoidRootPart
end

local function place(player, position)
	player.Character:PivotTo(CFrame.new(position))
end

local function equip(player)
	local tool = player.Backpack:FindFirstChild(Pvp.Shovel.ToolName)
	if tool then
		tool.Parent = player.Character
	end
	return player.Character:FindFirstChild(Pvp.Shovel.ToolName)
end

local function bonk(attacker, target)
	RateLimit.Reset(attacker)
	env.fireServer(attacker, "Bonk", target)
	env.flush()
end

local function lastNotify(player): string?
	local list = env.received(player, "Notify")
	local last = list[#list]
	return if last then last[1] else nil
end

local function droppedOf(block)
	for _, entry in DroppedBlockService.List() do
		if entry.Block.Id == block.Id then
			return entry
		end
	end
	return nil
end

local prompts = {}
local function pickUp(player, entry)
	RateLimit.Reset(player)
	-- (prompt gardé : un bloc déjà ramassé n'a plus de pièce, mais un client lent peut encore déclencher l'ancien)
	prompts[entry] = prompts[entry] or entry.Part:FindFirstChild("PickUpPrompt")
	env.fire(env.signal(prompts[entry], "Triggered"), player)
	env.flush()
end

local bonked = {}
Signals.Connect("Bonked", function(attacker, victim, block)
	table.insert(bonked, { Attacker = attacker, Victim = victim, Block = block })
end)
local pickedUp = {}
Signals.Connect("BlockPickedUp", function(player, block, droppedBy)
	table.insert(pickedUp, { Player = player, Block = block, DroppedBy = droppedBy })
end)

local beach = ZoneService.Get("Beach").Area
local road = beach.Position + Vector3.new(80, beach.Size.Y / 2 + 3, -60)

T.section("outils et protection")
local alice = T.join({ Name = "Alice", Character = true })
local bob = T.join({ Name = "Bob", Character = true })
env.flush()
for _, player in { alice, bob } do
	local shovel = player.Backpack:FindFirstChild(Pvp.Shovel.ToolName)
	T.check(shovel ~= nil and shovel:IsA("Tool") and shovel:FindFirstChild("Handle") ~= nil, player.Name .. " a une pelle avec un Handle")
	T.eq(shovel.CanBeDropped, false, "la pelle ne se lâche pas")
	T.eq(player.Backpack:FindFirstChild(Pvp.Trap.ToolName), nil, "pas de piège sans réserve")
	T.eq(player:GetAttribute("Protected"), true, player.Name .. " : protection débutant")
	T.near(player:GetAttribute("ProtectedUntil") - Workspace:GetServerTimeNow(), Pvp.Protection.Time, 0.5, "10 min de protection")
end
bob:LoadCharacter()
env.flush()
T.eq(#bob.Backpack:GetChildren(), 1, "une seule pelle après réapparition")

T.section("protection débutant")
local slot, block = carryOne(bob)
T.check(CarryService.IsCarrying(bob), "Bob porte un bloc")
place(bob, road)
place(alice, road + Vector3.new(4, 0, 0))
equip(alice)
bonk(alice, bob)
T.check(CarryService.IsCarrying(bob), "Bob protégé : pas bonké")
T.eq(lastNotify(alice), "This player has new player protection!", "message à Alice")
PvpService.SetProtection(bob, false)
T.eq(bob:GetAttribute("Protected"), false, "protection retirée")
env.advance(Pvp.Shovel.Cooldown)

T.section("bonk")
T.check(PvpService.IsProtected(alice), "Alice encore protégée avant d'attaquer")
bonk(alice, bob)
T.check(not CarryService.IsCarrying(bob), "Bob lâche son bloc")
T.eq(#bonked, 1, "signal Bonked")
T.check(bonked[1].Attacker == alice and bonked[1].Victim == bob and bonked[1].Block.Id == block.Id, "Bonked(attaquant, victime, bloc)")
local entry = droppedOf(block)
T.check(entry ~= nil, "le bloc est au sol")
T.check(CollectionService:HasTag(entry.Part, "DroppedFossil"), "tag DroppedFossil")
T.eq(entry.Part:GetAttribute("DroppedBy"), bob.UserId, "attribut DroppedBy")
T.eq(entry.Part:GetAttribute("Rarity"), block.Rarity, "attribut Rarity")
T.near(entry.Part:GetAttribute("LockedUntil") - Workspace:GetServerTimeNow(), Pvp.Dropped.LockTime, 1e-6, "LockedUntil dans 3 s")
T.near(entry.Part:GetAttribute("ReturnAt") - Workspace:GetServerTimeNow(), Pvp.Dropped.ReturnTime, 1e-6, "ReturnAt dans 30 s")
T.near(entry.Part.Position.Y, rootOf(bob).Position.Y - 3 + 1.5, 1e-6, "posé au sol (sous le personnage)")
T.eq(entry.Part.Parent.Name, "DroppedFossils", "dans Workspace.DroppedFossils")
T.eq(slot.State, "Out", "la place du gisement reste « dehors »")
T.check(SpeedService.HasModifier(bob, "Knocked"), "Bob au sol")
local knocked = env.received(bob, "Knocked")
T.check(#knocked == 1 and knocked[1][1] == Pvp.Shovel.KnockTime and knocked[1][2] == "Bonk", "remote Knocked (1.5 s, Bonk)")
T.eq(lastNotify(bob), "Bonk! You dropped your fossil!", "message à Bob")
local aliceNotes = env.received(alice, "Notify")
T.eq(aliceNotes[#aliceNotes - 1] and aliceNotes[#aliceNotes - 1][1], "Bonk! Grab the fossil!", "message à Alice")
T.eq(lastNotify(alice), "You attacked a player: your new player protection is over!", "Alice a attaqué : fin de sa protection")
T.check(not PvpService.IsProtected(alice) and alice:GetAttribute("Protected") == false, "Alice n'est plus protégée")
local effects = env.received(alice, "PvpEffect")
T.check(#effects == 1 and effects[1][1] == "Bonk", "effet Bonk pour tous")

T.section("ramassage et règle des 3 s")
pickUp(bob, entry)
T.check(not CarryService.IsCarrying(bob) and droppedOf(block) ~= nil, "Bob ne peut pas le reprendre tout de suite")
T.eq(lastNotify(bob), "You can't grab it back yet!", "message à Bob")
env.advance(2)
pickUp(bob, entry)
T.check(not CarryService.IsCarrying(bob), "toujours pas à 2 s")
local carol = T.join({ Name = "Carol", Character = true })
env.flush()
place(carol, entry.Part.Position + Vector3.new(0, 1.5, 30))
pickUp(carol, entry)
T.check(not CarryService.IsCarrying(carol), "Carol trop loin : rien")
pickUp(alice, entry)
T.check(CarryService.IsCarrying(alice), "Alice le ramasse (pas besoin d'attendre)")
T.eq(CarryService.Get(alice).Id, block.Id, "c'est le même bloc")
T.eq(droppedOf(block), nil, "plus au sol")
T.eq(entry.Part.Parent, nil, "pièce retirée")
T.check(#pickedUp == 1 and pickedUp[1].Player == alice and pickedUp[1].DroppedBy == bob.UserId, "signal BlockPickedUp")
pickUp(carol, entry)
T.check(not CarryService.IsCarrying(carol), "déjà ramassé : rien")

T.section("se venger")
PvpService.SetProtection(alice, false)
place(bob, rootOf(alice).Position + Vector3.new(3, 0, 0))
equip(bob)
PvpService.Knock(bob, 1, "Bonk")
T.check(PvpService.IsKnocked(bob), "Bob au sol")
bonk(bob, alice)
T.check(CarryService.IsCarrying(alice), "Bob au sol : pas de coup")
env.advance(1)
T.check(not PvpService.IsKnocked(bob), "Bob relevé")
bonk(bob, alice)
T.check(not CarryService.IsCarrying(alice), "relevé, Bob bonke Alice")
entry = droppedOf(block)
pickUp(bob, entry)
T.check(CarryService.IsCarrying(bob), "Bob reprend le bloc lâché par Alice (pas par lui)")
T.eq(#bonked, 2, "deux bonks en tout")

T.section("bonk hostile")
PvpService.SetProtection(carol, false)
local carolSlot = carryOne(carol)
T.check(CarryService.IsCarrying(carol), "Carol porte un bloc")
place(carol, road + Vector3.new(0, 0, 30))
place(alice, road + Vector3.new(0, 0, 30 + Pvp.Shovel.Range + Pvp.Shovel.RangeTolerance + 5))
env.advance(Pvp.Shovel.Cooldown)
local before = #bonked
bonk(alice, carol)
T.eq(#bonked, before, "de loin (cible donnée) : rien")
env.advance(Pvp.Shovel.Cooldown)
bonk(alice, nil)
T.eq(#bonked, before, "de loin (sans cible) : rien")
-- (une fonction arrive nil par le réseau : c'est la visée automatique, testée plus haut)
local function hostileBonks()
	for _, value in T.hostileValues() do
		if type(value) ~= "function" then
			env.advance(Pvp.Shovel.Cooldown)
			bonk(alice, value)
		end
	end
end
hostileBonks()
place(alice, rootOf(carol).Position + Vector3.new(3, 0, 0))
hostileBonks()
T.eq(#bonked, before, "cibles invalides (nombres, textes, tables, instances...) : rien")
T.check(CarryService.IsCarrying(carol), "Carol garde son bloc")
T.clean("aucune erreur pendant les bonks hostiles")
-- sans pelle en main
alice.Character[Pvp.Shovel.ToolName].Parent = alice.Backpack
env.advance(Pvp.Shovel.Cooldown)
bonk(alice, carol)
T.check(CarryService.IsCarrying(carol), "pelle pas en main : rien")
equip(alice)
-- se frapper soi-même
bonk(alice, alice)
T.eq(#bonked, before, "se bonker soi-même : rien")
-- un joueur sans bloc
local dave = T.join({ Name = "Dave", Character = true })
env.flush()
PvpService.SetProtection(dave, false)
place(dave, rootOf(alice).Position + Vector3.new(-3, 0, 0))
env.advance(Pvp.Shovel.Cooldown)
bonk(alice, dave)
T.eq(#bonked, before, "sans bloc : rien à voler")
T.check(not SpeedService.HasModifier(dave, "Knocked"), "et pas de chute")
-- spam : un seul coup toutes les 2 s
local spamBefore = #bonked
for _ = 1, 20 do
	env.fireServer(alice, "Bonk", carol)
end
env.flush()
T.eq(#bonked, spamBefore, "spam juste après le coup raté : recharge")
env.advance(Pvp.Shovel.Cooldown)
for _ = 1, 20 do
	env.fireServer(alice, "Bonk", carol)
end
env.flush()
T.eq(#bonked, spamBefore + 1, "spam : un seul coup")
T.check(not CarryService.IsCarrying(carol), "Carol a lâché son bloc une fois")
T.eq(#DroppedBlockService.List(), 1, "un seul bloc au sol")
DroppedBlockService.ReturnAll()
T.eq(carolSlot.State, "Present", "returnblocks : le bloc retourne à son gisement")

T.section("zone sûre des parcs")
local alicePlot = PlotService.Get(alice)
local carolPlot = PlotService.Get(carol)
carryOne(carol)
-- la victime dans un parc (pas le sien : le sien prendrait le bloc)
place(carol, alicePlot.Floor.Position + Vector3.new(0, 3, 0))
place(alice, alicePlot.Floor.Position + Vector3.new(3, 3, 0))
env.advance(Pvp.Shovel.Cooldown)
bonk(alice, carol)
T.check(CarryService.IsCarrying(carol), "victime dans un parc : rien")
T.eq(lastNotify(alice), "No bonking in parks!", "message « No bonking in parks! »")
-- l'attaquant dans un parc, la victime juste devant
place(alice, alicePlot.Entrance.Position + Vector3.new(0, 3, -3))
place(carol, alicePlot.Entrance.Position + Vector3.new(0, 3, 4))
T.check(not PlotService.IsPlayerSafe(carol) and PlotService.IsPlayerSafe(alice), "Alice dans son parc, Carol dehors")
env.advance(Pvp.Shovel.Cooldown)
bonk(alice, carol)
T.check(CarryService.IsCarrying(carol), "attaquant dans un parc : rien")
T.check(carolPlot ~= nil, "Carol a un parc")

T.section("bloc au sol pas ramassé : retour au gisement")
place(carol, road)
place(alice, road + Vector3.new(4, 0, 0))
env.advance(Pvp.Shovel.Cooldown)
local carried = CarryService.Get(carol)
bonk(alice, carol)
local lost = droppedOf(carried)
T.check(lost ~= nil, "bloc au sol")
env.advance(Pvp.Dropped.ReturnTime - 1)
T.check(droppedOf(carried) ~= nil, "encore au sol à 29 s")
env.advance(1.5)
T.eq(droppedOf(carried), nil, "plus au sol après 30 s")
local back = nil
for _, s in DigSiteService.Sites() do
	for _, sl in s.Slots do
		if sl.Block and sl.Block.Id == carried.Id then
			back = sl
		end
	end
end
T.check(back ~= nil and back.State == "Present", "retourné à sa place au gisement")

T.section("bloc sans gisement (météorites) et bloc du tutoriel")
local meteor = { Id = 900001, Rarity = "Epic", Zone = "Beach" }
local meteorEntry = DroppedBlockService.Place(meteor, road - Vector3.new(0, 3, 0), nil, "Meteor")
T.check(meteorEntry ~= nil, "posé")
env.advance(Pvp.Dropped.ReturnTime + 1)
T.eq(DroppedBlockService.Get(meteorEntry.Id), nil, "disparu au bout de 30 s")
local tutorial = { Id = 900002, Rarity = "Common", Zone = "Beach", Tutorial = true }
local tutorialEntry = DroppedBlockService.Place(tutorial, road - Vector3.new(0, 3, 0), nil, "Test")
place(alice, road)
CarryService.ReturnToSite(alice)
T.data(alice).Tutorial = 3
pickUp(alice, tutorialEntry)
T.check(not CarryService.IsCarrying(alice), "bloc du tutoriel : pas pour un ancien")
T.eq(lastNotify(alice), "This fossil is for new players!", "message")
T.check(not DroppedBlockService.Place({ Rarity = "Nope" } :: any, road, nil, "x"), "rareté inconnue refusée")
T.check(not DroppedBlockService.Place(meteor, Vector3.new(0 / 0, 0, 0), nil, "x"), "position NaN refusée")
DroppedBlockService.ReturnAll()

T.section("ramassage hostile")
-- porteur qui veut un second bloc, joueur pas chargé, prompt d'un bloc déjà rendu
carryOne(carol)
place(carol, road)
local loose = DroppedBlockService.Place({ Id = 900003, Rarity = "Rare", Zone = "Beach" }, road - Vector3.new(0, 3, 0), nil, "Test")
pickUp(carol, loose)
T.eq(CarryService.Get(carol).Id ~= 900003, true, "un seul bloc à la fois")
T.eq(lastNotify(carol), "You can only carry one fossil!", "message")
env.datastore.latency = 5
local loading = env.addPlayer({ Name = "Loading", Character = true })
place(loading, road)
pickUp(loading, loose)
T.check(not CarryService.IsCarrying(loading), "joueur pas chargé : rien")
env.datastore.latency = 0
env.waitUntil(function()
	return loading:GetAttribute("Ready") == true
end, "Loading prêt", 60)
T.leave(loading) -- (serveurs de 5 joueurs : sa place sert à Gina)
local ok, text = DroppedBlockService.PickUp(dave, 123456)
T.check(not ok and text == "Too late!", "bloc inconnu")
DroppedBlockService.ReturnAll()
T.clean("aucune erreur pendant les ramassages hostiles")

T.section("ramassage : debout, vivant, sur la route")
local gina = T.join({ Name = "Gina", Character = true })
env.flush()
T.check(PvpService.IsProtected(gina), "Gina est nouvelle")
local ginaPlot = PlotService.Get(gina)
local inside = ginaPlot.Entrance.Position + Vector3.new(0, 3, -3)
local outside = ginaPlot.Entrance.Position + Vector3.new(0, 3, 5)
local edge = DroppedBlockService.Place({ Id = 900004, Rarity = "Rare", Zone = "Beach" }, outside - Vector3.new(0, 3, 0), dave, "Test")
place(gina, inside)
T.check(PlotService.IsPlayerSafe(gina), "Gina dans son parc, le bloc juste devant")
pickUp(gina, edge)
T.check(not CarryService.IsCarrying(gina), "depuis un parc : refusé")
T.eq(lastNotify(gina), "Step onto the road to grab it!", "message")
place(gina, outside)
PvpService.Knock(gina, 1, "Bonk")
pickUp(gina, edge)
T.check(not CarryService.IsCarrying(gina), "au sol (bonk) : refusé")
env.advance(1.1)
local humanoid = gina.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
pickUp(gina, edge)
T.check(not CarryService.IsCarrying(gina), "mort : refusé")
humanoid.Health = humanoid.MaxHealth
T.check(PvpService.IsProtected(gina), "toujours protégée")
-- un bloc sans joueur qui l'a lâché (météorite) : la protection reste
local free = DroppedBlockService.Place({ Id = 900005, Rarity = "Rare", Zone = "Beach" }, outside + Vector3.new(4, -3, 0), nil, "Meteor")
pickUp(gina, free)
T.check(CarryService.IsCarrying(gina), "debout sur la route : ramassé")
T.check(PvpService.IsProtected(gina), "bloc de météorite : protection gardée")
CarryService.ReturnToSite(gina)
-- le bloc lâché par un autre joueur : la protection s'arrête
pickUp(gina, edge)
T.check(CarryService.IsCarrying(gina), "bloc lâché par Dave ramassé")
T.eq(lastNotify(gina), "You took another player's fossil: your new player protection is over!", "message")
T.check(not PvpService.IsProtected(gina) and gina:GetAttribute("Protected") == false, "Gina n'est plus protégée")
CarryService.ReturnToSite(gina)
T.check(not CarryService.IsCarrying(gina), "rendu")
DroppedBlockService.ReturnAll()
T.leave(gina)

T.section("départ et mort")
local eve = T.join({ Name = "Eve", Character = true })
env.flush()
PvpService.SetProtection(eve, false)
carryOne(eve)
place(eve, road)
place(alice, road + Vector3.new(3, 0, 0))
env.advance(Pvp.Shovel.Cooldown)
bonk(alice, eve)
local eveDrop = DroppedBlockService.List()[1]
T.check(eveDrop ~= nil, "Eve a lâché son bloc")
T.leave(eve)
T.check(DroppedBlockService.Get(eveDrop.Id) ~= nil, "le bloc reste au sol après son départ")
pickUp(alice, eveDrop)
T.check(CarryService.IsCarrying(alice), "Alice le ramasse")
T.clean("aucune erreur au départ")

T.section("protection : fin au bout de 10 min de jeu")
local frank = T.join({ Name = "Frank", Character = true })
env.flush()
T.eq(frank:GetAttribute("Protected"), true, "protégé à l'arrivée")
local ended = {}
Signals.Connect("ProtectionEnded", function(player)
	table.insert(ended, player)
end)
env.advance(Pvp.Protection.Time - 5)
T.eq(frank:GetAttribute("Protected"), true, "encore protégé à 9 min 55")
env.advance(6)
T.eq(frank:GetAttribute("Protected"), false, "plus protégé après 10 min")
T.check(table.find(ended, frank) ~= nil, "signal ProtectionEnded")
-- (le cadeau de temps de jeu de 10 min arrive en même temps : on cherche le message parmi les derniers)
local protectionMessage = false
for _, args in env.received(frank, "Notify") do
	protectionMessage = protectionMessage or args[1] == "Your new player protection is over. Watch out for thieves!"
end
T.check(protectionMessage, "message")
T.leave(frank)
-- un joueur qui a déjà joué 10 min (PlayTime sauvegardé) n'est plus protégé à son retour ; 4 min jouées : 6 min restent
env.datastore.set("SAF_Players_1/global", "Player_7001", { Money = 0, PlayTime = Pvp.Protection.Time + 1 })
local veteran = T.join({ Name = "Veteran", UserId = 7001, Character = true })
T.eq(veteran:GetAttribute("Protected"), false, "ancien joueur : pas protégé")
env.datastore.set("SAF_Players_1/global", "Player_7002", { Money = 0, PlayTime = 240 })
local returning = T.join({ Name = "Returning", UserId = 7002, Character = true })
T.eq(returning:GetAttribute("Protected"), true, "4 min déjà jouées : encore protégé")
T.near(returning:GetAttribute("ProtectedUntil") - Workspace:GetServerTimeNow(), Pvp.Protection.Time - 240, 0.5, "pour les 6 min qui restent")
T.leave(veteran)
T.leave(returning)
local ok2, text2 = AdminService.Run(alice, "protection", { "on", "Alice" })
T.check(ok2 and string.find(text2, "protection on", 1, true) ~= nil, "commande « protection on »")
T.eq(alice:GetAttribute("Protected"), true, "Alice protégée")
T.check(PvpService.IsProtected(alice), "IsProtected")
ok2 = AdminService.Run(alice, "protection", { "off" })
T.check(ok2 and not PvpService.IsProtected(alice), "commande « protection off »")
T.check(not AdminService.Run(alice, "protection", { "maybe" }), "commande mal écrite refusée")

T.done("pvp_steal")
