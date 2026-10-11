-- Aperçu du menu d'admin (4 pages, bouton Admin à droite de Index) et de l'alerte d'un bloc rare, avec le vrai serveur.
-- python3 tools/luau_tests/ui_preview.py admin_menu [--phone]
local P = require("./previewkit")
local T = require("./testkit")
local env = P.env

env.quiet = true
env.touch = P.Phone
env.setViewport(P.Width, P.Height)
local Boot = T.bootServer()
Boot.Services.GuardianService.SetEnabled(false)
local ReplicaService = Boot.Services.ReplicaService

local player = env.addPlayer({ Local = true, Name = "Snaky", DisplayName = "Snaky", Character = true })
env.addPlayer({ Name = "Bob", Character = true })
env.waitUntil(function()
	return player:GetAttribute("Ready") == true
end, "joueur prêt", 60)
local data = T.data(player)
data.Tutorial = 3
ReplicaService.Set(player, "Tutorial", 3)
Boot.Services.DailyService.Claim(player) -- (pas de calendrier ouvert tout seul)
Boot.Services.MoneyService.Add(player, 12_450, "Preview")
env.flush()

local ClientBoot = env.module("src/client/Boot")
ClientBoot.Start()
local C = ClientBoot.Controllers
P.settle(3)

-- alerte d'un bloc rare (un Mythic forcé dans le Volcano, puis un Secret)
Boot.Services.AdminService.Run(player, "spawnrare", { "mythic", "6" })
P.settle(0.5)
C.AlertController.Show("Secret", "Meteor Crater", 1)
P.settle(0.6)
P.page("admin_alert")
P.settle(8)

C.AdminController.Open("Player")
P.settle(1)
P.page("admin_player")
C.AdminController.Open("Dinos")
P.settle(0.5)
P.page("admin_dinos")
C.AdminController.Open("World")
P.settle(0.5)
P.page("admin_world")
C.AdminController.Open("Console")
P.settle(0.3)
C.AdminController.Run("help", {})
P.settle(0.5)
P.page("admin_console")

