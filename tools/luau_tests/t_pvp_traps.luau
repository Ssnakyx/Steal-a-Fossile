-- Bear Traps (brief 7) : achat avec l'argent du jeu et produit Robux BearTraps5, outil « Bear Trap », pose sur la route
-- seulement (pas dans ni devant un parc), espacement, 3 posés au plus, durée de vie, déclenchement (immobilise 3 s et fait
-- lâcher le bloc), poseur et nouveaux joueurs épargnés, départ du poseur. Appels hostiles sur BuyTraps et PlaceTrap.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Shop = T.config().Shop
Shop.Products.BearTraps5.Id = 701
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local AdminService = Boot.Services.AdminService
local CarryService = Boot.Services.CarryService
local DigSiteService = Boot.Services.DigSiteService
local DroppedBlockService = Boot.Services.DroppedBlockService
local MoneyService = Boot.Services.MoneyService
local PlotService = Boot.Services.PlotService
local PvpService = Boot.Services.PvpService
local ReceiptService = Boot.Services.ReceiptService
local ReplicaService = Boot.Services.ReplicaService
local SpeedService = Boot.Services.SpeedService
local ZoneService = Boot.Services.ZoneService
local Pvp = T.module("src/shared/Config/Pvp")
local Zones = T.module("src/shared/Config/Zones")
local Signals = T.lib("Signals")
local RateLimit = T.lib("RateLimit")
local CollectionService = env.game:GetService("CollectionService")
local Vector3, CFrame = env.Vector3, env.CFrame

local function place(player, position)
	player.Character:PivotTo(CFrame.new(position))
end

local function lastNotify(player): string?
	local list = env.received(player, "Notify")
	local last = list[#list]
	return if last then last[1] else nil
end

local function placeTrap(player)
	RateLimit.Reset(player)
	env.fireServer(player, "PlaceTrap")
	env.flush()
end

local function buy(player, ...): (any, any)
	RateLimit.Reset(player)
	return env.invokeServer(player, "BuyTraps", ...)
end

local function carryOne(player)
	for _, site in DigSiteService.Sites() do
		if site.Zone == "Beach" then
			for _, slot in site.Slots do
				if slot.State == "Present" and not slot.Block.Tutorial then
					RateLimit.Reset(player)
					local part = slot.Part
					player.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 1.5, 4)))
					env.fire(env.signal(part.GrabPrompt, "PromptButtonHoldBegan"), player)
					env.advance(Zones.Dig.GrabTime + 0.05)
					env.fire(env.signal(part.GrabPrompt, "Triggered"), player)
					env.flush()
					return slot
				end
			end
		end
	end
	error("plus de bloc à la Beach")
end

local function armed(): number
	local count = 0
	for _, trap in PvpService.Traps() do
		if trap.Armed then
			count += 1
		end
	end
	return count
end

local beach = ZoneService.Get("Beach").Area
local top = beach.Position.Y + beach.Size.Y / 2
local road = Vector3.new(beach.Position.X + 60, top + 3, beach.Position.Z - 40)

local sprung = {}
Signals.Connect("TrapSprung", function(owner, victim, block)
	table.insert(sprung, { Owner = owner, Victim = victim, Block = block })
end)

T.section("acheter des pièges")
local alice = T.join({ Name = "Alice", Character = true })
local bob = T.join({ Name = "Bob", Character = true })
env.flush()
local data = T.data(alice)
T.eq(data.BearTraps, 0, "aucun piège au départ")
ReplicaService.Flush()
T.eq(ReplicaService.Get(alice, "BearTraps"), 0, "replica BearTraps")
local ok, text = buy(alice)
T.check(not ok and text == "Not enough money!", "sans argent : refusé")
for _, value in T.hostileValues() do
	ok = buy(alice, value)
	T.check(not ok, "nombre hostile refusé : " .. T.show(value))
end
ok = buy(alice, Pvp.Trap.MaxBuy + 1)
T.check(not ok, "plus de " .. Pvp.Trap.MaxBuy .. " d'un coup : refusé")
T.eq(data.BearTraps, 0, "toujours aucun piège")
MoneyService.Add(alice, Pvp.Trap.Price * 4 + 10, "Test")
ok, text = buy(alice, 3)
T.check(ok and text == "Bought 3 bear traps for $15K", "3 pièges achetés (" .. tostring(text) .. ")")
T.eq(data.BearTraps, 3, "3 pièges en réserve")
T.eq(MoneyService.Get(alice), Pvp.Trap.Price + 10, "argent dépensé")
ok, text = buy(alice)
T.check(ok and text == "Bought 1 bear trap for $5K", "1 piège sans nombre")
T.eq(data.BearTraps, 4, "4 pièges")
ReplicaService.Flush()
T.eq(ReplicaService.Get(alice, "BearTraps"), 4, "replica à jour")
local tool = alice.Backpack:FindFirstChild(Pvp.Trap.ToolName)
T.check(tool ~= nil and tool:IsA("Tool"), "outil « Bear Trap » dans le sac")
T.eq(tool.ToolTip, "Bear Trap x4", "nombre de pièges dans le ToolTip")
data.BearTraps = Pvp.Trap.MaxOwned
MoneyService.Add(alice, Pvp.Trap.Price, "Test")
ok, text = buy(alice, 1)
T.check(not ok and text == "You can't carry more traps", "plafond de pièges")
data.BearTraps = 4

T.section("produit Robux Bear Traps x5")
T.check(ReceiptService.IsOnSale("BearTraps5"), "produit enregistré par PvpService")
T.check(ReceiptService.Simulate(alice, "BearTraps5"), "achat simulé")
env.flush()
T.eq(data.BearTraps, 4 + Pvp.Trap.PerProduct, "+5 pièges")
T.eq(lastNotify(alice), "+5 bear traps!", "message")
local purchase = env.purchase(alice, 701)
env.flush()
T.eq(data.BearTraps, 4 + 2 * Pvp.Trap.PerProduct, "vrai achat : +5")
T.check(purchase ~= nil, "reçu traité")
data.BearTraps = Pvp.Trap.MaxOwned - 1
T.check(not ReceiptService.Simulate(alice, "BearTraps5"), "au plafond : pas donné")
data.BearTraps = 4
PvpService.GiveTraps(alice, 0)
T.check(not PvpService.GiveTraps(alice, 0 / 0), "GiveTraps NaN refusé")

T.section("poser un piège")
local plot = PlotService.Get(alice)
place(alice, plot.Floor.Position + Vector3.new(0, 3, 0))
placeTrap(alice)
T.eq(#PvpService.Traps(), 0, "dans son parc : refusé")
T.eq(lastNotify(alice), "Bear traps go on the road, not near parks!", "message")
place(alice, plot.Entrance.Position + Vector3.new(0, 3, 6))
placeTrap(alice)
T.eq(#PvpService.Traps(), 0, "devant l'entrée d'un parc : refusé")
T.eq(data.BearTraps, 4, "aucun piège dépensé")
place(alice, road)
placeTrap(alice)
T.eq(#PvpService.Traps(), 1, "sur la route : posé")
T.eq(data.BearTraps, 3, "un piège de moins")
T.eq(alice.Backpack[Pvp.Trap.ToolName].ToolTip, "Bear Trap x3", "ToolTip à jour")
local trap = PvpService.Traps()[1]
T.check(CollectionService:HasTag(trap.Model, "BearTrap"), "modèle tagué BearTrap")
T.eq(trap.Model:GetAttribute("OwnerUserId"), alice.UserId, "attribut OwnerUserId")
T.eq(trap.Model:GetAttribute("Armed"), true, "armé")
T.eq(trap.Model.Parent.Name, "BearTraps", "dans Workspace.BearTraps")
T.near(trap.Position.Y, road.Y - 3, 1e-6, "au sol, sous le personnage")
T.eq(lastNotify(alice), "Bear trap placed!", "message")
env.advance(Pvp.Trap.PlaceCooldown)
placeTrap(alice)
T.eq(#PvpService.Traps(), 1, "au même endroit : refusé")
T.eq(lastNotify(alice), "There is already a trap here!", "message")
place(alice, road + Vector3.new(10, 0, 0))
placeTrap(alice)
T.eq(#PvpService.Traps(), 2, "un peu plus loin : posé")
place(alice, road + Vector3.new(20, 0, 0))
placeTrap(alice)
T.eq(#PvpService.Traps(), 2, "recharge : refusé")
env.advance(Pvp.Trap.PlaceCooldown)
placeTrap(alice)
env.advance(Pvp.Trap.PlaceCooldown)
place(alice, road + Vector3.new(30, 0, 0))
placeTrap(alice)
T.eq(armed(), Pvp.Trap.MaxActive, "3 pièges posés au plus")
T.check(PvpService.Traps()[1].Id ~= trap.Id, "le plus ancien a disparu")
T.eq(trap.Model.Parent, nil, "son modèle aussi")
T.eq(data.BearTraps, 0, "réserve vide")
T.eq(alice.Backpack:FindFirstChild(Pvp.Trap.ToolName), nil, "plus d'outil « Bear Trap »")
env.advance(Pvp.Trap.PlaceCooldown)
placeTrap(alice)
T.eq(lastNotify(alice), "You have no bear traps!", "sans piège : refusé")
for _ = 1, 20 do
	env.fireServer(alice, "PlaceTrap")
end
env.flush()
T.eq(armed(), Pvp.Trap.MaxActive, "spam sans piège : rien")
T.clean("aucune erreur pendant la pose")

T.section("marcher sur un piège")
PvpService.SetProtection(bob, false)
local slot = carryOne(bob)
T.check(CarryService.IsCarrying(bob), "Bob porte un bloc")
local victimTrap = PvpService.Traps()[1]
place(bob, victimTrap.Position + Vector3.new(Pvp.Trap.Radius + 2, 3, 0))
env.advance(0.3)
T.eq(victimTrap.Armed, true, "à côté : rien")
place(bob, victimTrap.Position + Vector3.new(1, 3, 0))
env.advance(0.2)
T.eq(victimTrap.Armed, false, "dessus : le piège se ferme")
T.eq(victimTrap.Model:GetAttribute("Armed"), false, "attribut Armed")
T.check(not CarryService.IsCarrying(bob), "Bob lâche son bloc")
T.eq(#DroppedBlockService.List(), 1, "bloc au sol")
T.eq(DroppedBlockService.List()[1].Part:GetAttribute("DroppedBy"), bob.UserId, "lâché par Bob")
T.check(SpeedService.HasModifier(bob, "BearTrap"), "Bob immobilisé")
SpeedService.Refresh(bob)
T.eq(bob.Character.Humanoid.WalkSpeed, 0, "WalkSpeed 0")
local knocked = env.received(bob, "Knocked")
T.check(#knocked == 1 and knocked[1][1] == Pvp.Trap.HoldTime and knocked[1][2] == "Trap", "remote Knocked (3 s, Trap)")
T.eq(lastNotify(bob), "Bear trap! You dropped your fossil!", "message à Bob")
T.eq(lastNotify(alice), "Your bear trap caught Bob!", "message à Alice")
T.check(#sprung == 1 and sprung[1].Owner == alice and sprung[1].Victim == bob and sprung[1].Block ~= nil, "signal TrapSprung")
local effects = env.received(alice, "PvpEffect")
T.eq(effects[#effects][1], "Trap", "effet Trap pour tous")
local other = PvpService.Traps()[2]
place(bob, other.Position + Vector3.new(0, 3, 0))
env.advance(0.3)
T.eq(other.Armed, true, "déjà pris : pas de second piège")
place(bob, victimTrap.Position + Vector3.new(1, 3, 0))
env.advance(Pvp.Trap.HoldTime - 0.5)
T.check(SpeedService.HasModifier(bob, "BearTrap"), "encore pris à 2.5 s")
env.advance(0.6)
T.check(not SpeedService.HasModifier(bob, "BearTrap"), "libre après 3 s")
T.eq(victimTrap.Model.Parent, nil, "le piège refermé disparaît")
T.eq(slot.State, "Out", "le bloc est au sol, pas au gisement")
DroppedBlockService.ReturnAll()

T.section("sans bloc, poseur, nouveau joueur")
local before = #sprung
place(alice, other.Position + Vector3.new(0, 3, 0))
env.advance(0.3)
T.eq(other.Armed, true, "le poseur ne se prend pas dans son piège")
local carol = T.join({ Name = "Carol", Character = true })
env.flush()
T.eq(carol:GetAttribute("Protected"), true, "Carol est nouvelle")
place(carol, other.Position + Vector3.new(0, 3, 0))
env.advance(0.3)
T.eq(other.Armed, true, "nouveau joueur : épargné")
place(carol, road + Vector3.new(0, 0, 60))
env.advance(0.3)
PvpService.SetProtection(carol, false)
place(carol, other.Position + Vector3.new(0, 3, 0))
env.advance(0.3)
T.eq(other.Armed, false, "sans bloc : immobilisé quand même")
T.check(SpeedService.HasModifier(carol, "BearTrap"), "Carol immobilisée")
T.eq(lastNotify(carol), "Bear trap!", "message sans bloc")
T.eq(#sprung, before + 1, "signal TrapSprung")
T.eq(sprung[#sprung].Block, nil, "sans bloc")
env.advance(Pvp.Trap.HoldTime + 0.2)

T.section("dans un parc, au-dessus, durée de vie")
PvpService.GiveTraps(alice, 3)
place(alice, road + Vector3.new(0, 0, 50))
placeTrap(alice)
local high = PvpService.Traps()[#PvpService.Traps()]
place(bob, high.Position + Vector3.new(0, 40, 0))
env.advance(0.3)
T.eq(high.Armed, true, "loin au-dessus : rien")
env.advance(Pvp.Trap.Lifetime)
T.eq(armed(), 0, "pièges pas déclenchés disparus après " .. Pvp.Trap.Lifetime .. " s")

T.section("départ du poseur")
env.advance(Pvp.Trap.PlaceCooldown)
place(alice, road)
placeTrap(alice)
T.eq(armed(), 1, "piège posé")
local leaving = PvpService.Traps()[1]
T.leave(alice)
T.eq(#PvpService.Traps(), 0, "ses pièges disparaissent")
T.eq(leaving.Model.Parent, nil, "modèle retiré")

T.section("commandes d'admin")
local ok2, text2 = AdminService.Run(bob, "traps", { "5" })
T.check(ok2 and text2 == "Bob got 5 bear trap(s)", "traps 5 (" .. tostring(text2) .. ")")
T.eq(T.data(bob).BearTraps, 5, "5 pièges")
T.check(not AdminService.Run(bob, "traps", { "-3" }), "nombre invalide refusé")
T.check(not AdminService.Run(bob, "traps", { "5", "Nobody" }), "joueur inconnu refusé")

T.section("appels hostiles")
local calls = T.fuzzRemotes(bob)
T.check(calls > 0, "remotes appelés avec des valeurs hostiles")
T.check(T.data(bob).BearTraps <= 5, "pas de piège gagné")
T.check(MoneyService.Get(bob) >= 0, "argent intact")
T.clean("aucune erreur avec des valeurs hostiles")

T.done("pvp_traps")
