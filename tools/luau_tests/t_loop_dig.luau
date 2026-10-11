-- Boucle (brief 3) : gisements, arrachage (maintien et distance vérifiés), transport, retour au parc, retour au gisement,
-- remplissage toutes les 5 min, annonce d'un bloc Secret, tutoriel côté serveur, Server Luck du brief 4.
local T = require("./testkit")
local env = T.env

env.quiet = true

local Boot = T.bootServer()
local DigSiteService = Boot.Services.DigSiteService
local CarryService = Boot.Services.CarryService
local PlotService = Boot.Services.PlotService
local ReviveService = Boot.Services.ReviveService
local ReplicaService = Boot.Services.ReplicaService
local Zones = T.module("src/shared/Config/Zones")
local Rarity = T.module("src/shared/Config/Rarity")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local Workspace = env.game:GetService("Workspace")
local CollectionService = env.game:GetService("CollectionService")
local Vector3, CFrame = env.Vector3, env.CFrame

-- Server Luck du brief 4 (ShopService) consultée par les gisements
local ShopService = Boot.Services.ShopService
local serverLuck = ShopService.ServerLuck
local luckCalls = 0
ShopService.ServerLuck = function()
	luckCalls += 1
	return 1
end

local function presentSlots(zone: string?): { any }
	local list = {}
	for _, site in DigSiteService.Sites() do
		if zone == nil or site.Zone == zone then
			for _, slot in site.Slots do
				if slot.State == "Present" then
					table.insert(list, slot)
				end
			end
		end
	end
	return list
end

local function moveNear(player, part)
	player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 1, 4)))
end

local function hold(player, prompt, seconds: number)
	env.fire(env.signal(prompt, "PromptButtonHoldBegan"), player)
	env.advance(seconds)
end

local function trigger(player, prompt)
	env.fire(env.signal(prompt, "Triggered"), player)
	env.flush()
end

local function grab(player, slot)
	local part = slot.Part
	moveNear(player, part)
	local prompt = part.GrabPrompt
	hold(player, prompt, Zones.Dig.GrabTime + 0.05)
	trigger(player, prompt)
end

-- Rentre au parc comme en marchant (le temps du trajet passe d'abord : sinon c'est une téléportation)
local function goHome(player)
	env.advance(20)
	PlotService.Teleport(player)
	env.advance(0.25)
end

local function lastNotify(player): string?
	local list = env.received(player, "Notify")
	local last = list[#list]
	return if last then last[1] else nil
end

T.section("remplissage au démarrage")
local total = 0
for _, site in DigSiteService.Sites() do
	total += #site.Slots
end
T.eq(#DigSiteService.Sites(), 8 * Zones.Dig.Sites, "gisements de toutes les zones")
T.eq(total, 8 * Zones.Dig.Sites * Zones.Dig.BlocksPerSite, "places de blocs")
T.eq(#presentSlots(), total, "toutes les places remplies au démarrage")
T.eq(#CollectionService:GetTagged("FossilBlock"), total, "blocs tagués FossilBlock")
DigSiteService.Refill()
T.check(luckCalls > 0, "Server Luck consultée au remplissage")
ShopService.ServerLuck = serverLuck
local refillAt = Workspace:GetAttribute("DigRefillAt")
T.near(refillAt, Workspace:GetServerTimeNow() + Zones.Dig.RefillInterval, 2, "DigRefillAt dans 5 min (heure serveur)")
local siteLabel = DigSiteService.Sites()[1].Label
T.eq(siteLabel:GetAttribute("EndsAt"), refillAt, "étiquette du gisement : EndsAt")
T.check(CollectionService:HasTag(siteLabel, "LoopCountdown"), "étiquette taguée LoopCountdown")
local wrongRarity = 0
for _, slot in presentSlots() do
	local zone = Zones.ByName[slot.Zone]
	if not zone.Weights[slot.Block.Rarity] then
		wrongRarity += 1
	end
	T.eq(slot.Part:GetAttribute("Rarity"), slot.Block.Rarity, "attribut Rarity du bloc") -- (une fois par bloc)
end
T.eq(wrongRarity, 0, "chaque bloc a une rareté de sa zone")

T.section("probas des zones")
for _, zone in Zones.List do
	local chances = Zones.Chances(zone.Name)
	local sum = 0
	for rarity, chance in chances do
		sum += chance
		if rarity ~= "Secret" then
			local hasSpecies = false
			for _, species in zone.Species do
				if Rarity.Species[species] == rarity then
					hasSpecies = true
				end
			end
			T.check(hasSpecies, zone.Name .. " : une espèce " .. rarity)
		end
	end
	T.near(sum, 1, 1e-9, zone.Name .. " : probas qui font 100 %")
	local lucky = Zones.Chances(zone.Name, 2)
	T.check((lucky.Secret or 0) > (chances.Secret or 0), zone.Name .. " : Server Luck x2 augmente le Secret")
end
T.check(next(Zones.Chances("Nope")) == nil, "zone inconnue : aucune proba")
T.near(Zones.Chances("Beach", 0 / 0).Common, Zones.Chances("Beach").Common, 1e-9, "chance NaN ignorée")
for _ = 1, 200 do
	local rarity = DigSiteService.RollRarity("Meteor Crater", 1)
	if not Zones.ByName["Meteor Crater"].Weights[rarity] then
		T.check(false, "tirage hors des raretés de la zone : " .. rarity)
	end
end

T.section("arracher un bloc")
local alice = T.join({ Name = "Alice", Character = true })
local bob = T.join({ Name = "Bob", Character = true })
env.flush()
T.eq(T.data(alice).Tutorial, 0, "tutoriel : nouveau joueur")
local grabbed = {}
local disconnect = Signals.Connect("BlockGrabbed", function(player, block)
	table.insert(grabbed, { player, block })
end)
local slot = presentSlots("Beach")[1]
local blockId = slot.Block.Id
local rarity = slot.Block.Rarity
local part = slot.Part
local oldPrompt = part.GrabPrompt
grab(alice, slot)
local carried = CarryService.Get(alice)
T.check(carried ~= nil and carried.Id == blockId, "Alice porte le bloc")
T.eq(slot.State, "Out", "la place est « dehors »")
T.eq(part.Parent, nil, "le bloc a quitté le gisement")
T.eq(alice:GetAttribute("Carrying"), rarity, "attribut Carrying")
ReplicaService.Flush()
T.eq(ReplicaService.Get(alice, "Carrying").Rarity, rarity, "replica Carrying")
local visual = alice.Character:FindFirstChild("CarriedFossil")
T.check(visual ~= nil and visual:FindFirstChildOfClass("WeldConstraint") ~= nil, "bloc soudé dans le dos")
T.eq(CarryService.GetSpeedMultiplier(alice), Rarity.Info[rarity].CarrySpeed, "malus de vitesse de la rareté")
T.eq(CarryService.GetSpeedMultiplier(bob), 1, "pas de malus sans bloc")
T.eq(#grabbed, 1, "signal BlockGrabbed")
T.eq(T.data(alice).Tutorial, 1, "tutoriel : premier bloc arraché")
disconnect()

T.section("arrachages hostiles")
local function tryHostile(label: string, action: (any) -> ())
	RateLimit.Reset(bob)
	local target = presentSlots("Beach")[1]
	local id = target.Block.Id
	action(target)
	T.check(not CarryService.IsCarrying(bob) and target.State == "Present" and target.Block.Id == id, label)
end
tryHostile("déclenché sans maintenir", function(target)
	moveNear(bob, target.Part)
	trigger(bob, target.Part.GrabPrompt)
end)
tryHostile("maintien trop court puis déclenché plus tard", function(target)
	moveNear(bob, target.Part)
	local prompt = target.Part.GrabPrompt
	hold(bob, prompt, 0.3)
	env.fire(env.signal(prompt, "PromptButtonHoldEnded"), bob)
	env.advance(2)
	trigger(bob, prompt)
end)
tryHostile("maintien sur un autre bloc", function(target)
	local other = presentSlots("Beach")[2]
	moveNear(bob, target.Part)
	hold(bob, other.Part.GrabPrompt, 1.2)
	trigger(bob, target.Part.GrabPrompt)
end)
tryHostile("de loin", function(target)
	local prompt = target.Part.GrabPrompt
	bob.Character:PivotTo(CFrame.new(target.Part.Position + Vector3.new(0, 0, 60)))
	hold(bob, prompt, 1.2)
	trigger(bob, prompt)
end)
tryHostile("sans personnage", function(target)
	local character = bob.Character
	bob.Character = nil
	local prompt = target.Part.GrabPrompt
	hold(bob, prompt, 1.2)
	trigger(bob, prompt)
	bob.Character = character
end)
-- bloc déjà pris par Alice (ancien prompt détruit) : rien
RateLimit.Reset(bob)
moveNear(bob, part)
hold(bob, oldPrompt, 1.2)
trigger(bob, oldPrompt)
T.check(not CarryService.IsCarrying(bob), "bloc déjà pris : rien")
-- un seul bloc à la fois
RateLimit.Reset(alice)
local second = presentSlots("Beach")[1]
grab(alice, second)
T.eq(CarryService.Get(alice).Id, blockId, "un seul bloc à la fois")
T.eq(second.State, "Present", "le second bloc reste au gisement")
T.eq(lastNotify(alice), "You can only carry one fossil!", "message « one fossil »")
-- joueur pas encore chargé
env.datastore.latency = 5
local loading = env.addPlayer({ Name = "Loading", Character = true })
local target = presentSlots("Beach")[1]
moveNear(loading, target.Part)
hold(loading, target.Part.GrabPrompt, 1.2)
trigger(loading, target.Part.GrabPrompt)
T.check(not CarryService.IsCarrying(loading), "joueur pas chargé : rien")
env.datastore.latency = 0
env.waitUntil(function()
	return loading:GetAttribute("Ready") == true
end, "Loading prêt", 60)
T.clean("aucune erreur pendant les arrachages hostiles")

T.section("rentrer au parc")
-- dans le parc de Bob : rien
bob.Character:PivotTo(CFrame.new(0, 100, 0))
alice.Character:PivotTo(PlotService.SpawnCFrame(PlotService.Get(bob)))
env.advance(0.3)
T.check(CarryService.IsCarrying(alice), "le parc d'un autre ne prend pas le bloc")
local banked = {}
disconnect = Signals.Connect("BlockBanked", function(player, block)
	table.insert(banked, { player, block })
end)
goHome(alice)
T.check(not CarryService.IsCarrying(alice), "dans son parc : le bloc est à elle")
T.eq(alice:GetAttribute("Carrying"), "", "plus d'attribut Carrying")
T.eq(alice.Character:FindFirstChild("CarriedFossil"), nil, "plus de bloc dans le dos")
T.eq(T.data(alice).Tanks["1"].Rarity, rarity, "le bloc est dans la cuve 1")
T.eq(slot.State, "Empty", "place libérée au gisement")
T.eq(#banked, 1, "signal BlockBanked")
T.eq(T.data(alice).Tutorial, 2, "tutoriel : premier bloc rapporté")
T.eq(lastNotify(alice), "Fossil secured! It is yours for good.", "message « Fossil secured »")
disconnect()

T.section("retour au gisement")
local function grabAndCheck(player, label)
	RateLimit.Reset(player)
	local s = presentSlots("Beach")[1]
	grab(player, s)
	T.check(CarryService.IsCarrying(player), label .. " : bloc pris")
	return s, s.Block
end
local s1, b1 = grabAndCheck(bob, "mort")
local humanoid = bob.Character:FindFirstChildOfClass("Humanoid")
env.fire(env.signal(humanoid, "Died"))
env.flush()
T.check(not CarryService.IsCarrying(bob), "mort : plus de bloc")
T.check(s1.State == "Present" and s1.Block.Id == b1.Id, "mort : le bloc revient à sa place")
local s2, b2 = grabAndCheck(bob, "reset")
bob:LoadCharacter()
env.flush()
T.check(not CarryService.IsCarrying(bob) and s2.State == "Present" and s2.Block.Id == b2.Id, "reset : le bloc revient")
local s3, b3 = grabAndCheck(bob, "départ")
T.leave(bob)
T.check(s3.State == "Present" and s3.Block.Id == b3.Id, "départ : le bloc revient")
T.check(not DigSiteService.ReturnBlock(b3), "un bloc déjà revenu n'est pas reposé deux fois")
T.check(not DigSiteService.ReturnBlock({ Id = 999999, Rarity = "Common", Zone = "Beach" }), "bloc sans gisement : disparaît")
-- Drop (brief 7) : le bloc n'est pas rendu tout de suite
local s4, b4 = grabAndCheck(alice, "drop")
local dropped = CarryService.Drop(alice)
T.check(dropped == b4 and s4.State == "Out", "Drop rend le bloc sans le reposer")
T.check(DigSiteService.ReturnBlock(dropped), "ReturnBlock le repose")
T.eq(s4.State, "Present", "place à nouveau occupée")

T.section("réserve pleine")
local data = T.data(alice)
while ReviveService.AddBlock(alice, { Rarity = "Common", Zone = "Beach" }) do
end
T.check(not ReviveService.HasRoom(alice), "cuves et réserve pleines")
local s5 = grabAndCheck(alice, "plein")
goHome(alice)
T.check(CarryService.IsCarrying(alice), "tout est plein : le bloc reste sur le dos")
T.eq(lastNotify(alice), "Your tanks and storage are full! Reveal your dinos first.", "message « full »")
env.advance(1)
local fullMessages = 0
for _, sent in env.received(alice, "Notify") do
	if string.find(sent[1], "full", 1, true) then
		fullMessages += 1
	end
end
T.eq(fullMessages, 1, "message « full » pas répété à chaque vérification")
data.Stored = {}
env.advance(0.2)
T.check(not CarryService.IsCarrying(alice), "de la place : le bloc part en réserve")
T.eq(#data.Stored, 1, "bloc en réserve")
T.eq(s5.State, "Empty", "place libérée")

T.section("téléportation chez soi")
local s7, b7 = grabAndCheck(alice, "téléportation")
PlotService.Teleport(alice)
env.advance(0.25)
T.check(not CarryService.IsCarrying(alice), "téléportée chez elle juste après l'arrachage : plus de bloc")
T.check(s7.State == "Present" and s7.Block.Id == b7.Id, "le bloc retourne à son gisement")
T.eq(#data.Stored, 1, "rien de plus en réserve")
T.eq(lastNotify(alice), "Too fast! The fossil went back to its dig site.", "message « Too fast »")
local s8 = grabAndCheck(alice, "rapide")
local aliceHumanoid = alice.Character:FindFirstChildOfClass("Humanoid")
aliceHumanoid.WalkSpeed = 120 -- (vitesse donnée par SpeedService du brief 4)
env.advance(4)
PlotService.Teleport(alice)
env.advance(0.25)
T.check(not CarryService.IsCarrying(alice), "grande vitesse de marche : arrivée rapide acceptée")
T.eq(#data.Stored, 2, "bloc en réserve")
T.eq(s8.State, "Empty", "place libérée")
aliceHumanoid.WalkSpeed = 16

T.section("remplissage toutes les 5 min")
local kept = presentSlots()[1]
local keptId = kept.Block.Id
local emptyBefore = 0
for _, site in DigSiteService.Sites() do
	for _, s in site.Slots do
		if s.State == "Empty" then
			emptyBefore += 1
		end
	end
end
T.check(emptyBefore >= 2, "des places vides avant le remplissage (" .. emptyBefore .. ")")
local before = Workspace:GetAttribute("DigRefillAt")
env.advance(before - Workspace:GetServerTimeNow() + 1.5)
T.eq(#presentSlots(), total, "places vides remplies")
T.eq(kept.Block.Id, keptId, "les blocs restés ne changent pas")
T.near(Workspace:GetAttribute("DigRefillAt"), before + Zones.Dig.RefillInterval, 1e-6, "prochain remplissage 5 min plus tard")

T.section("annonce d'un bloc Secret")
local carol = T.join({ Name = "Carol", Character = true })
env.flush() -- (apparition dans son parc, faite juste après le placement du personnage)
local s6 = grabAndCheck(carol, "secret")
CarryService.Drop(carol)
DigSiteService.ReleaseBlock(s6.Block)
T.eq(s6.State, "Empty", "place vidée")
local roll = DigSiteService.RollRarity
DigSiteService.RollRarity = function()
	return "Secret"
end
local sentBefore = #env.received(alice, "LoopAnnounce")
DigSiteService.Refill()
DigSiteService.RollRarity = roll
T.eq(s6.Block.Rarity, "Secret", "bloc Secret posé")
local announces = env.received(alice, "LoopAnnounce")
T.eq(#announces, sentBefore + 1, "annonce envoyée à tout le serveur")
T.eq(announces[#announces][1], "A SECRET fossil appeared in the Beach!", "texte de l'annonce")
T.eq(lastNotify(carol), "A SECRET fossil appeared in the Beach!", "et un message à l'écran")
T.eq(s6.Part.Material, env.Enum.Material.Neon, "bloc Secret en Neon (provisoire)")

T.section("tutoriel : un bloc Common à la Beach")
for _, site in DigSiteService.Sites() do
	if site.Zone == "Beach" then
		for _, s in site.Slots do
			if s.State == "Present" and s.Block.Rarity == "Common" then
				s.Part:Destroy()
				s.State = "Empty"
				s.Block = nil
				s.Part = nil
			end
		end
	end
end
T.eq(T.data(carol).Tutorial, 1, "Carol est encore dans le tutoriel")
env.advance(2.5)
local commons = 0
for _, s in presentSlots("Beach") do
	if s.Block.Rarity == "Common" then
		commons += 1
	end
end
T.eq(commons, 1, "un bloc Common remis à la Beach pour le tutoriel")
T.check(not DigSiteService.EnsureTutorialBlock(), "déjà un Common : rien de plus")
local tutorialSlot = nil
for _, s in presentSlots("Beach") do
	if s.Block.Rarity == "Common" then
		tutorialSlot = s
	end
end
T.eq(tutorialSlot.Block.Tutorial, true, "bloc réservé au tutoriel")
RateLimit.Reset(alice)
grab(alice, tutorialSlot)
T.check(not CarryService.IsCarrying(alice), "un ancien joueur ne prend pas le bloc du tutoriel")
T.eq(lastNotify(alice), "This fossil is for new players!", "message « for new players »")
RateLimit.Reset(carol)
grab(carol, tutorialSlot)
T.check(CarryService.IsCarrying(carol), "Carol, dans le tutoriel, le prend")
DigSiteService.ReleaseBlock(CarryService.Drop(carol))
DigSiteService.RollRarity = function()
	return "Uncommon"
end
DigSiteService.Refill()
DigSiteService.RollRarity = roll
local beachIds = {}
for _, s in presentSlots("Beach") do
	beachIds[s] = s.Block.Id
end
T.check(next(beachIds) ~= nil, "Beach pleine, sans Common")
T.check(not DigSiteService.EnsureTutorialBlock(), "pas de place vide : pas de bloc du tutoriel")
local unchanged = true
for s, id in beachIds do
	unchanged = unchanged and s.State == "Present" and s.Block.Id == id
end
T.check(unchanged, "aucun bloc remplacé pour le tutoriel")
T.data(carol).Tutorial = 3
T.data(alice).Tutorial = 3
T.data(loading).Tutorial = 3
for _, s in presentSlots("Beach") do
	if s.Block.Rarity == "Common" then
		s.Part:Destroy()
		s.State = "Empty"
		s.Block = nil
		s.Part = nil
	end
end
T.check(not DigSiteService.EnsureTutorialBlock(), "plus personne dans le tutoriel : rien")

T.section("commandes d'admin")
local AdminService = Boot.Services.AdminService
local ok, text = AdminService.Run(alice, "refill", {})
T.check(ok, "refill : " .. tostring(text))
T.eq(#presentSlots(), total, "refill remplit tout")
ok = AdminService.Run(alice, "tutorial", { "0" })
T.check(ok and T.data(alice).Tutorial == 0, "tutorial 0")
ok = AdminService.Run(alice, "tutorial", { "9" })
T.check(not ok, "tutorial 9 refusé")

T.done("loop_dig")
