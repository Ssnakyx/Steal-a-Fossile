-- Serveur et client ensemble : état du joueur (ReplicaService -> ReplicaController), messages Notify, démarrage client
local T = require("./testkit")
local env = T.env

local Boot = T.bootServer()
local MoneyService = Boot.Services.MoneyService
local ReplicaService = Boot.Services.ReplicaService
local Notify = T.lib("Notify")

local player = env.addPlayer({ Local = true, Name = "Me" })
local other = T.join({ Name = "Other" })

T.section("démarrage du client")
local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
T.check(ClientBoot.Controllers.ReplicaController ~= nil, "ReplicaController chargé")
T.check(ClientBoot.Controllers.NotifyController ~= nil, "NotifyController chargé")
T.eq(ClientBoot.Order[1], "ReplicaController", "ReplicaController en premier")
local Replica = ClientBoot.Controllers.ReplicaController
local observed = {}
Replica.Observe("Money", function(value)
	table.insert(observed, value)
end)
env.waitUntil(function()
	return Replica.IsReady()
end, "état du joueur reçu", 30)
T.check(player:GetAttribute("Ready") == true, "joueur prêt côté serveur")
T.eq(Replica.Get("Money"), 0, "argent reçu au démarrage")
T.eq(observed[1], 0, "Observe appelé à l'arrivée de l'état")
T.eq(#ClientBoot.Errors, 0, "aucune erreur au démarrage du client")

T.section("changements")
MoneyService.Add(player, 50, "Test")
MoneyService.Add(player, 25, "Test")
env.advance(0.1)
T.eq(Replica.Get("Money"), 75, "argent à jour côté client")
T.eq(observed[#observed], 75, "Observe suit les changements")
local sends = #env.received(player, "Replica")
MoneyService.Add(player, 1, "Test")
MoneyService.Add(player, 1, "Test")
MoneyService.Add(player, 1, "Test")
env.advance(0.1)
T.eq(#env.received(player, "Replica") - sends, 1, "changements d'une image groupés en un envoi")
ReplicaService.Set(player, "Temp", { a = 1 })
env.advance(0.1)
T.eq(Replica.Get("Temp").a, 1, "table reçue")
ReplicaService.Set(player, "Temp", nil)
env.advance(0.1)
T.eq(Replica.Get("Temp"), nil, "clé effacée")
local remote = env.game:GetService("ReplicatedStorage").Remotes.Replica
env.fire(env.signal(remote, "OnClientEvent"), 1, { Money = -999 }, {})
T.eq(Replica.Get("Money"), 78, "envoi plus ancien ignoré")
env.fire(env.signal(remote, "OnClientEvent"), "bad", nil, 5)
T.eq(Replica.Get("Money"), 78, "envoi abîmé ignoré")

T.section("état d'un autre joueur")
MoneyService.Add(other, 1000, "Test")
env.advance(0.1)
T.eq(Replica.Get("Money"), 78, "l'argent d'un autre joueur n'arrive pas chez moi")
T.eq(ReplicaService.Get(other, "Money"), 1000, "mais il est bien posé pour lui")
local snapshot, seq = ReplicaService.Snapshot(other)
T.eq(snapshot.Money, 1000, "Snapshot")
T.check(seq >= 1, "numéro d'envoi")

T.section("Notify")
local function toasts(): { any }
	local list = {}
	for _, item in player.PlayerGui:GetDescendants() do
		if item.Name == "Toast" then
			table.insert(list, item)
		end
	end
	return list
end
Notify.Send(player, "Hello there", "success")
env.flush()
local shown = toasts()
T.eq(#shown, 1, "un message affiché")
T.eq(shown[1] and shown[1]:FindFirstChild("Text", true).Text, "Hello there", "texte du message")
Notify.Send(player, string.rep("x", 1000), "weird")
env.flush()
local long = toasts()
local longest = 0
for _, toast in long do
	longest = math.max(longest, #toast:FindFirstChild("Text", true).Text)
end
T.eq(longest, 200, "message coupé à 200 caractères")
env.fire(env.signal(env.game:GetService("ReplicatedStorage").Remotes.Notify, "OnClientEvent"), {}, 5)
T.eq(#toasts(), 2, "message abîmé ignoré")
for index = 1, 10 do
	Notify.Send(player, "Spam " .. index)
end
env.flush()
T.check(#toasts() <= 4, "au plus 4 messages à l'écran (" .. #toasts() .. ")")
env.advance(5)
T.eq(#toasts(), 0, "les messages disparaissent")
Notify.All("To everyone")
env.flush()
T.eq(#toasts(), 1, "Notify.All")
T.eq(#env.received(other, "Notify"), 1, "Notify.All envoyé aux autres aussi, Notify.Send non")

T.section("départ")
T.leave(other)
T.eq(ReplicaService.Get(other, "Money"), nil, "état oublié au départ")
T.eq(#ClientBoot.Errors, 0, "aucune erreur côté client")

T.done("core_client")
