-- FossilDebug des mutations et des espèces : les tests en jeu « mutations » et « species » passent sur un serveur
-- démarré sans rien laisser dans le jeu ; les outils « dinoshow », « mutationshow » et « clearshow » posent puis
-- retirent la vitrine devant le premier joueur.
local T = require("./testkit")
local env = T.env

env.quiet = true
local Boot = T.bootServer()
local DebugService = Boot.Services.DebugService
local Species = T.module("src/shared/Config/Species")
local Economy = T.module("src/shared/Config/Economy")
local DinoBuilder = T.module("src/shared/DinoBuilder")
local workspace = env.game:GetService("Workspace")

local alice = T.join({ Name = "Alice", Character = true })
env.flush()
local data = T.data(alice)

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

T.section("tests en jeu")
local before = #workspace:GetDescendants()
local dinos = count(data.Dinos)
for _, name in { "mutations", "species" } do
	T.check(table.find(DebugService.Tests(), name) ~= nil, "test en jeu " .. name)
	local ok, fail, lines = DebugService.RunTest(name)
	T.check(ok > 40, name .. " : vérifications faites (" .. ok .. ")")
	T.eq(fail, 0, name .. " : aucun échec")
	if fail > 0 then
		print(table.concat(lines, "\n"))
	end
end
T.eq(#workspace:GetDescendants(), before, "rien laissé dans le Workspace")
T.eq(count(data.Dinos), dinos, "dinos de test retirés de l'enclos")
T.clean("tests en jeu : aucune erreur")

T.section("vitrine d'une zone")
local text = DebugService.Run("dinoshow", "glacier")
local show = workspace:FindFirstChild("DinoShowcase")
T.check(show ~= nil, "vitrine posée (" .. text .. ")")
local glacier = 0
for _, def in Species.List do
	if def.Zone == "Glacier" then
		glacier += 1
	end
end
T.eq(#show:GetChildren(), glacier, "une espèce du glacier par dino")
local tagged, labelled, known = 0, 0, 0
local root = alice.Character.HumanoidRootPart
local far = 0
for _, model in show:GetChildren() do
	if model:HasTag("Dino") then
		tagged += 1
	end
	if DinoBuilder.Get(model:GetAttribute("Species")) then
		known += 1
	end
	if model.PrimaryPart and model.PrimaryPart:FindFirstChild("ShowLabel") then
		labelled += 1
	end
	if (model:GetPivot().Position - root.Position).Magnitude > 120 then
		far += 1
	end
end
T.eq(tagged, glacier, "dinos tagués (animés chez le client)")
T.eq(known, glacier, "modèles connus de DinoBuilder")
T.eq(labelled, glacier, "nom et rareté au-dessus de chacun")
T.eq(far, 0, "devant le joueur")

T.section("vitrine des mutations")
text = DebugService.Run("mutationshow", "velociraptor", "Big", "Golden")
show = workspace:FindFirstChild("DinoShowcase")
T.eq(#show:GetChildren(), #Economy.Mutations + 1, "une par mutation, plus sans mutation (" .. text .. ")")
local mutations = {}
for _, model in show:GetChildren() do
	local m = model:GetAttribute("Mutation")
	if m then
		mutations[m] = true
	end
	T.eq(model:GetAttribute("Level"), "Golden", "niveau demandé")
	T.eq(model:GetAttribute("Scale"), DinoBuilder.Sizes.Big, "taille demandée")
end
for _, info in Economy.Mutations do
	T.check(mutations[info.Name] == true, "vitrine : " .. info.Name)
end
T.check(string.find(DebugService.Run("mutationshow", "nope"), "Unknown species", 1, true) ~= nil, "espèce inconnue refusée")
T.check(string.find(DebugService.Run("dinoshow", "moon"), "Usage", 1, true) ~= nil, "zone inconnue refusée")

T.section("toutes les espèces")
DebugService.Run("dinoshow")
show = workspace:FindFirstChild("DinoShowcase")
T.eq(#show:GetChildren(), #Species.List, "toutes les espèces")
local shows = 0
for _, child in workspace:GetChildren() do
	if child.Name == "DinoShowcase" then
		shows += 1
	end
end
T.eq(shows, 1, "une seule vitrine à la fois")

T.section("retirer la vitrine")
T.eq(DebugService.Run("clearshow"), "Showcase removed", "vitrine retirée")
T.eq(workspace:FindFirstChild("DinoShowcase"), nil, "plus de vitrine")
T.eq(DebugService.Run("clearshow"), "No showcase", "rien à retirer")
T.clean("aucune erreur")

T.done("mutation_debug")
