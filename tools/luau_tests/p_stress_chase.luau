-- Aperçu de la course stressante (StressController) : rugissement du gardien (« RUN!! », éclair, vignette rouge),
-- poursuite (vignette rouge qui bat), bloc porté (vignette sombre légère). Le monde 3D n'est pas dessiné : seulement
-- l'interface par-dessus. python3 tools/luau_tests/ui_preview.py stress [--phone]
local P = require("./previewkit")
local env = P.env

local player = P.setup()
-- (sans serveur : le dossier des remotes est posé à la main, comme le ferait le serveur)
local folder = env.Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = env.game:GetService("ReplicatedStorage")
for _, name in { "GuardianAlert", "Knocked", "PvpEffect" } do
	local remote = env.Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
end
local StressController = env.module("src/client/Controllers/StressController")
StressController.Init()
StressController.Start()

player:SetAttribute("Carrying", "Epic")
player:SetAttribute("ChasedBy", "Beach")
P.settle(0.6)
StressController.Alert("Roar")
P.settle(0.25)
P.page("stress_roar")
P.settle(3)
P.page("stress_chase")
player:SetAttribute("ChasedBy", "")
P.settle(4)
P.page("stress_carry")
