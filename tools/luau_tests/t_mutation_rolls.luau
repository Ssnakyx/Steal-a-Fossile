-- Mutations (docs/MUTATIONS.md) : liste de Config.Economy (Amber, Crystal, Lava du GDD gardées, une exclusive par
-- biome, Rainbow), tirage par zone et chance du pass VIP (Economy.RollMutation, ReviveService.Roll), probas affichées
-- (Economy.MutationChances, commande admin « mutations »), revenus, enclos et sauvegarde, fusion (meilleure mutation
-- gardée), annonce des mutations rares à tout le serveur (MutationService), couleurs des briques (DinoBuilder).
local T = require("./testkit")
local env = T.env

env.quiet = true

local Boot = T.bootServer()
-- pass VIP choisi par le test (ShopService.HasPass remplacé, comme t_loop_revive)
local passes: { [any]: { [string]: boolean } } = {}
Boot.Services.ShopService.HasPass = function(player, pass)
	return passes[player] ~= nil and passes[player][pass] == true
end
local Config = T.config()
local Economy = T.module("src/shared/Config/Economy")
local Zones = T.module("src/shared/Config/Zones")
local DinoBuilder = T.module("src/shared/DinoBuilder")
local ReviveService = Boot.Services.ReviveService
local MutationService = Boot.Services.MutationService
local EnclosureService = Boot.Services.EnclosureService
local IncomeService = Boot.Services.IncomeService
local FusionService = Boot.Services.FusionService
local AdminService = Boot.Services.AdminService
local Signals = T.lib("Signals")

local function last(player, remote: string): any
	local list = env.received(player, remote)
	local entry = list[#list]
	return if entry then entry[1] else nil
end

local function zoneNamed(name: string): any
	for _, zone in Zones.List do
		if zone.Name == name then
			return zone
		end
	end
	return nil
end

T.section("liste")
local names, seen = {}, {}
local exclusives: { [string]: { string } } = {}
for index, info in Economy.Mutations do
	table.insert(names, info.Name)
	T.check(not seen[info.Name], "nom unique : " .. info.Name)
	seen[info.Name] = true
	T.check(info.Chance > 0 and info.Chance <= 100, info.Name .. " : chance entre 0 et 100 %")
	T.check(info.Income > 1, info.Name .. " : revenu multiplié")
	T.eq(env.typeof(info.Color), "Color3", info.Name .. " : couleur")
	local previous = Economy.Mutations[index - 1]
	if previous then
		T.check(info.Chance <= previous.Chance, info.Name .. " : rangée de la plus commune à la plus rare")
		T.check(info.Income >= previous.Income, info.Name .. " : plus rare, rapporte au moins autant")
	end
	if info.Zone ~= nil then
		T.check(zoneNamed(info.Zone) ~= nil, info.Name .. " : zone connue (" .. tostring(info.Zone) .. ")")
		exclusives[info.Zone] = exclusives[info.Zone] or {}
		table.insert(exclusives[info.Zone], info.Name)
	end
end
T.eq(#names, 12, "12 mutations")
for _, zone in Zones.List do
	T.eq(#(exclusives[zone.Name] or {}), 1, zone.Name .. " : une mutation à elle")
end
-- valeurs du GDD gardées (toutes zones)
for _, expected in { { "Amber", 8, 1.5 }, { "Crystal", 3, 2 }, { "Lava", 1, 3 } } do
	local info = Economy.Mutation(expected[1])
	T.check(info ~= nil and info.Chance == expected[2] and info.Income == expected[3] and info.Zone == nil, expected[1] .. " : valeurs du GDD, toutes zones")
end
local rainbow = Economy.Mutation("Rainbow")
T.check(rainbow ~= nil and rainbow.Zone == nil and rainbow.Income == 10, "Rainbow : toutes zones, x10")
T.eq(names[#names], "Rainbow", "Rainbow : la plus rare")
T.eq(table.concat(DinoBuilder.Mutations, ","), table.concat(names, ","), "DinoBuilder.Mutations : mêmes noms, même ordre")

T.section("fiches et noms")
T.eq(Economy.Mutation("Pearl").Zone, "Beach", "Pearl : plage")
T.eq(Economy.Mutation("Galaxy").Zone, "Meteor Crater", "Galaxy : cratère")
T.eq(Economy.Mutation("pearl"), nil, "Mutation : nom exact")
T.eq(Economy.Mutation(""), nil, "Mutation : vide")
T.eq(Economy.Mutation(nil), nil, "Mutation : nil")
T.eq(Economy.Mutation(12 :: any), nil, "Mutation : pas un texte")
T.eq(Economy.FindMutation("pearl"), "Pearl", "FindMutation : sans majuscules")
T.eq(Economy.FindMutation("RAINBOW"), "Rainbow", "FindMutation : en majuscules")
T.eq(Economy.FindMutation("none"), nil, "FindMutation : none")
T.eq(Economy.FindMutation(""), nil, "FindMutation : vide")
T.eq(Economy.FindMutation(nil), nil, "FindMutation : nil")
T.check(Economy.MutationInZone(Economy.Mutation("Pearl"), "Beach"), "Pearl sort de la plage")
T.check(not Economy.MutationInZone(Economy.Mutation("Pearl"), "Swamp"), "Pearl ne sort pas du marais")
T.check(not Economy.MutationInZone(Economy.Mutation("Pearl"), nil), "Pearl ne sort pas d'un bloc sans zone")
T.check(Economy.MutationInZone(Economy.Mutation("Amber"), "Volcano"), "Amber sort de partout")
T.check(Economy.MutationInZone(Economy.Mutation("Rainbow"), ""), "Rainbow sort même d'un bloc sans zone")

T.section("tirage : probas exactes sur une grille de rolls")
local STEPS = 20000
local function frequencies(zone: string?, luck: number?): { [string]: number }
	local counts: { [string]: number } = {}
	for k = 0, STEPS - 1 do
		local name = Economy.RollMutation(zone, luck, (k + 0.5) / STEPS)
		counts[name] = (counts[name] or 0) + 1
	end
	for name, n in counts do
		counts[name] = n / STEPS
	end
	return counts
end
for _, zone in Zones.List do
	for _, luck in { 0, 0.5 } do
		local freq = frequencies(zone.Name, luck)
		local chances = Economy.MutationChances(zone.Name, luck)
		local total, listed = 0, {}
		for _, chance in chances do
			total += chance.Chance
			listed[chance.Name] = true
			local info = Economy.Mutation(chance.Name)
			if info then
				T.near(chance.Chance, info.Chance * (1 + luck) / 100, 1e-12, zone.Name .. " " .. chance.Name .. " : chance x" .. (1 + luck))
				T.eq(chance.Income, info.Income, zone.Name .. " " .. chance.Name .. " : revenu affiché")
			end
			T.near(freq[chance.Name] or 0, chance.Chance, 2 / STEPS, zone.Name .. " " .. (if chance.Name == "" then "aucune" else chance.Name) .. " : tirée aussi souvent qu'affichée")
		end
		T.near(total, 1, 1e-9, zone.Name .. " : probas qui font 100 %")
		for name in freq do
			T.check(listed[name] == true, zone.Name .. " : " .. name .. " affichée")
		end
		for _, info in Economy.Mutations do
			local inZone = info.Zone == nil or info.Zone == zone.Name
			T.eq(listed[info.Name] == true, inZone, zone.Name .. " : " .. info.Name .. (if inZone then " possible" else " impossible"))
		end
		T.eq(chances[#chances].Name, "", zone.Name .. " : « aucune » en dernier")
		T.eq(chances[1].Name, "Amber", zone.Name .. " : la plus commune en premier")
	end
end
local blank = Economy.MutationChances("", 0)
T.eq(#blank, 5, "bloc sans zone : 4 mutations de toutes les zones + aucune")
T.eq(Economy.RollMutation("Glacier", 0, 0), "Rainbow", "roll 0 : la plus rare")
T.eq(Economy.RollMutation("Glacier", 0, 0.9999), "", "roll haut : aucune")
T.eq(Economy.RollMutation("Glacier", 0, 0 / 0), "", "roll NaN : aucune")
T.eq(Economy.RollMutation("Glacier", 0, 5), "", "roll trop grand : aucune")
T.eq(Economy.RollMutation("Glacier", 0, -3), "Rainbow", "roll négatif : borné à 0")
for _, zone in Zones.List do
	T.eq(Economy.RollMutation(zone.Name, 1e9, 0.999), "Rainbow", zone.Name .. " : chance énorme, Rainbow")
	local huge = Economy.MutationChances(zone.Name, 1e9)
	T.near(huge[#huge - 1].Chance, 1, 1e-12, zone.Name .. " : chance énorme, Rainbow à 100 %")
	T.near(huge[#huge].Chance, 0, 1e-12, zone.Name .. " : chance énorme, jamais rien")
end
for _, bad in { 0 / 0, -1, math.huge, -math.huge, "2" :: any } do
	local same = 0
	for k = 0, 999 do
		local roll = (k + 0.5) / 1000
		if Economy.RollMutation("Swamp", bad, roll) == Economy.RollMutation("Swamp", 0, roll) then
			same += 1
		end
	end
	T.eq(same, 1000, "chance invalide ignorée : " .. tostring(bad))
end

T.section("réanimation : mutation de la zone du bloc")
-- (chance x31 : les mutations rares sortent souvent, celles des autres biomes jamais)
local LUCK = 30
for _, zone in Zones.List do
	local own = exclusives[zone.Name][1]
	local got: { [string]: number } = {}
	local wrong = 0
	for _ = 1, 400 do
		local rolled = ReviveService.Roll("Common", zone.Name, LUCK)
		got[rolled.Mutation] = (got[rolled.Mutation] or 0) + 1
		local info = Economy.Mutation(rolled.Mutation)
		if info and info.Zone ~= nil and info.Zone ~= zone.Name then
			wrong += 1
		end
	end
	T.eq(wrong, 0, zone.Name .. " : jamais la mutation d'un autre biome")
	T.check((got[own] or 0) > 0, zone.Name .. " : sa mutation " .. own .. " sort")
	T.check((got.Rainbow or 0) + (got.Lava or 0) > 0, zone.Name .. " : les mutations de toutes les zones sortent")
end
local plain = 0
for _ = 1, 400 do
	if ReviveService.Roll("Common", "Beach").Mutation == "" then
		plain += 1
	end
end
T.check(plain > 300, "sans chance : sans mutation la plupart du temps (" .. plain .. "/400)")

T.section("revenus")
for _, info in Economy.Mutations do
	local income = IncomeService.DinoIncome({ Species = "Compy", Size = "Normal", Mutation = info.Name, Level = 0 })
	T.near(income, IncomeService.BaseIncome("Compy") * info.Income, 1e-9, info.Name .. " : revenu x" .. info.Income)
end

T.section("enclos")
local alice = T.join({ Name = "Alice", Character = true })
local bob = T.join({ Name = "Bob", Character = true })
local admin = T.join({ Name = "Admin", UserId = 3346721423 })
env.flush()
local data = T.data(alice)
local galaxyId = EnclosureService.AddDino(alice, { Species = "Compy", Size = "Big", Mutation = "Galaxy" })
T.check(galaxyId ~= nil, "dino Galaxy ajouté")
local model = EnclosureService.ModelOf(alice, galaxyId)
T.check(model ~= nil and model:GetAttribute("Mutation") == "Galaxy", "modèle : attribut Mutation")
T.eq(EnclosureService.DisplayName(data.Dinos[galaxyId]), "Big Galaxy Compy", "nom affiché avec la mutation")
local badId = EnclosureService.AddDino(alice, { Species = "Compy", Size = "Normal", Mutation = "Plutonium" })
T.eq(data.Dinos[badId].Mutation, "", "mutation inconnue : aucune")
EnclosureService.RemoveDino(alice, badId)
EnclosureService.RemoveDino(alice, galaxyId)

T.section("annonce des mutations rares")
local revealed = {}
local disconnect = Signals.Connect("MutationRevealed", function(player, id, dino, info)
	table.insert(revealed, { player, id, dino, info })
end)
local function revive(mutation: string): (number, number)
	local before, notes = #env.received(bob, "LoopAnnounce"), #env.received(bob, "Notify")
	local dino = { Species = "Compy", Size = "Big", Mutation = mutation, Level = 0, Got = 0 }
	Signals.Fire("DinoRevived", alice, "99", dino, "Common")
	env.flush()
	return #env.received(bob, "LoopAnnounce") - before, #env.received(bob, "Notify") - notes
end
local announced, noted = revive("Amber")
T.eq(announced, 0, "Amber (8 %) : pas d'annonce")
T.eq(noted, 0, "Amber : pas de message à l'écran")
T.eq(#revealed, 1, "Amber : signal MutationRevealed")
T.eq(revealed[1][4].Name, "Amber", "MutationRevealed : fiche de la mutation")
announced, noted = revive("")
T.eq(announced, 0, "sans mutation : pas d'annonce")
T.eq(#revealed, 1, "sans mutation : pas de signal")
for _, info in Economy.Mutations do
	announced, noted = revive(info.Name)
	local expected = if info.Chance <= Economy.MutationAnnounce then 1 else 0
	T.eq(announced, expected, info.Name .. " : annonce dans le chat de tous" .. (if expected == 0 then " (non)" else ""))
	T.eq(noted, expected, info.Name .. " : message à l'écran de tous" .. (if expected == 0 then " (non)" else ""))
end
T.eq(
	last(bob, "LoopAnnounce"),
	"Alice revived a Big Rainbow Compy! Rainbow mutation: 1 in 2000, x10 income",
	"texte de l'annonce Rainbow"
)
T.eq(last(alice, "LoopAnnounce"), last(bob, "LoopAnnounce"), "le joueur lui-même voit aussi l'annonce")
T.eq(MutationService.AnnounceText(alice, { Species = "Compy", Size = "Normal", Mutation = "Abyssal", Level = 0, Got = 0 }), "Alice revived an Abyssal Compy! Abyssal mutation: 1 in 133, x4 income", "texte : Abyssal (an)")
T.eq(MutationService.AnnounceText(alice, { Species = "Compy", Size = "Normal", Mutation = "Crystal", Level = 0, Got = 0 }), nil, "texte : Crystal pas annoncée")
T.eq(MutationService.Odds(Economy.Mutation("Galaxy")), "1 in 200", "chance de Galaxy : 1 in 200")
Signals.Fire("DinoRevived", alice, "99", "pas un dino", "Common")
Signals.Fire("DinoRevived", alice, "99", { Mutation = 42 }, "Common")
env.flush()
T.clean("dino invalide : aucune erreur")

T.section("révélation d'une cuve avec le pass VIP (chance énorme)")
passes[alice] = { VIP = true }
local vip = Config.Shop.Passes.VIP
local oldBonus = vip.LuckBonus
vip.LuckBonus = 1e6
T.near(ReviveService.MutationLuck(alice), 1e6 - 1, 1e-6, "chance du VIP")
local count = #revealed
ReviveService.AddBlock(alice, { Rarity = "Common", Zone = "Glacier" })
ReviveService.FinishAll(alice)
local slot
for key in data.Tanks do
	slot = tonumber(key)
end
local ok, text = ReviveService.Reveal(alice, slot)
env.flush()
T.check(ok, "révélation : " .. tostring(text))
T.check(string.find(text, "Rainbow", 1, true) ~= nil, "révélation : Rainbow")
T.eq(#revealed, count + 1, "révélation : MutationRevealed")
T.check(string.find(last(bob, "LoopAnnounce") or "", "Alice revived a", 1, true) ~= nil, "révélation : annoncée à Bob")
vip.LuckBonus = oldBonus
passes[alice] = nil
local revealedId = revealed[#revealed][2]
T.eq(data.Dinos[revealedId].Mutation, "Rainbow", "dino Rainbow dans l'enclos")
EnclosureService.RemoveDino(alice, revealedId)
disconnect()

T.section("fusion : meilleure mutation gardée")
local function give(mutation: string?): string
	local id = EnclosureService.AddDino(alice, { Species = "Triceratops", Size = "Normal", Mutation = mutation })
	assert(id, "enclos plein")
	return id
end
local function bestOf(list: { string? }): string?
	local ids = {}
	for index = 1, 3 do
		table.insert(ids, give(list[index]))
	end
	local okPreview, info = FusionService.Preview(alice, ids)
	for _, id in ids do
		EnclosureService.RemoveDino(alice, id)
	end
	return if okPreview then info.Mutation else nil
end
T.eq(bestOf({ "Crystal", "Pearl", nil }), "Pearl", "revenu égal (x2) : la plus rare (Pearl)")
T.eq(bestOf({ "Pearl", "Crystal", nil }), "Pearl", "revenu égal : l'ordre ne compte pas")
T.eq(bestOf({ "Obsidian", "Lava", "Amber" }), "Obsidian", "revenu égal (x3) : Obsidian, plus rare que Lava")
T.eq(bestOf({ "Ruby", "Galaxy", "Toxic" }), "Galaxy", "meilleur revenu : Galaxy")
T.eq(bestOf({ "Amber", "Rainbow", "Abyssal" }), "Rainbow", "Rainbow avant tout")

T.section("sauvegarde")
local Loop = T.module("src/server/Data/Loop")
local saved = table.clone(Loop.Defaults)
saved.Dinos = {
	["1"] = { Species = "Compy", Size = "Big", Mutation = "Obsidian", Level = 0, Got = 0 },
	["2"] = { Species = "Compy", Size = "Big", Mutation = "Rainbow", Level = 2, Got = 0 },
	["3"] = { Species = "Compy", Size = "Big", Mutation = "Plutonium", Level = 0, Got = 0 },
}
saved.Tanks, saved.Stored = {}, {}
Loop.Sanitize(saved)
T.eq(saved.Dinos["1"].Mutation, "Obsidian", "sauvegarde : mutation de biome gardée")
T.eq(saved.Dinos["2"].Mutation, "Rainbow", "sauvegarde : Rainbow gardée")
T.eq(saved.Dinos["3"].Mutation, "", "sauvegarde : mutation inconnue effacée")

T.section("commandes admin")
local okCmd, listText = AdminService.Run(admin, "mutations", { "glacier" })
T.check(okCmd, "mutations glacier : " .. tostring(listText))
T.eq(
	listText,
	"Glacier: Amber 8% (x1.5), Crystal 3% (x2), Frost 1.5% (x2.5), Lava 1% (x3), Rainbow 0.05% (x10), None 86.45% (x1)",
	"mutations glacier : probas"
)
okCmd, listText = AdminService.Run(admin, "mutations", { "8" })
T.check(okCmd and string.find(listText, "Meteor Crater: ", 1, true) == 1 and string.find(listText, "Galaxy 0.5%", 1, true) ~= nil, "mutations 8 : cratère, Galaxy")
okCmd, listText = AdminService.Run(admin, "mutations", { "oceantrench" })
T.check(okCmd and string.find(listText, "Abyssal 0.75%", 1, true) ~= nil, "mutations oceantrench : nom sans espace")
okCmd, listText = AdminService.Run(admin, "mutations", {})
T.check(okCmd and string.find(listText, "Beach: ", 1, true) == 1, "mutations sans zone : la plage")
okCmd = AdminService.Run(admin, "mutations", { "9" })
T.check(not okCmd, "mutations 9 : refusé")
okCmd = AdminService.Run(admin, "mutations", { "moon" })
T.check(not okCmd, "mutations zone inconnue : refusé")
passes[admin] = { VIP = true }
okCmd, listText = AdminService.Run(admin, "mutations", { "glacier" })
T.check(okCmd and string.find(listText, "Frost 1.65%", 1, true) ~= nil, "mutations avec le VIP : chance x1.1 (" .. tostring(listText) .. ")")
passes[admin] = nil
env.studio = false -- (dans Studio, tout le monde est admin : Config.Core.Admin.StudioEveryone)
okCmd = AdminService.Run(alice, "mutations", { "glacier" })
T.check(not okCmd, "mutations : réservé aux admins")
env.studio = true
okCmd, listText = AdminService.Run(admin, "givedino", { "compy", "Big", "galaxy", "Alice" })
T.check(okCmd, "givedino galaxy : " .. tostring(listText))
T.eq(data.Dinos[tostring(data.NextDinoId - 1)].Mutation, "Galaxy", "givedino : mutation sans majuscules")

T.section("couleurs des briques")
local function looks(mutation: string?): { string }
	local out = {}
	local built = DinoBuilder.Build("Velociraptor", { Mutation = mutation })
	for _, part in built:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			local c = part.Color
			table.insert(out, string.format("%d,%d,%d,%s", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), part.Material.Name))
		end
	end
	return out
end
local base = looks(nil)
local all = { base }
for _, name in names do
	local painted = looks(name)
	T.eq(#painted, #base, name .. " : autant de briques")
	local changed = 0
	for index, value in painted do
		if value ~= base[index] then
			changed += 1
		end
	end
	T.check(changed > #base * 0.5, name .. " : plus de la moitié des briques changent (" .. changed .. "/" .. #base .. ")")
	table.insert(all, painted)
end
-- deux mutations ne se ressemblent jamais : au moins 40 % des briques différentes
for i = 2, #all do
	for j = i + 1, #all do
		local differ = 0
		for index, value in all[i] do
			if value ~= all[j][index] then
				differ += 1
			end
		end
		T.check(differ > #base * 0.4, names[i - 1] .. " et " .. names[j - 1] .. " : différentes (" .. differ .. "/" .. #base .. ")")
	end
end
local hues: { [number]: boolean } = {}
local rainbowModel = DinoBuilder.Build("Velociraptor", { Mutation = "Rainbow" })
for _, part in rainbowModel:GetChildren() do
	if part:IsA("BasePart") and part.Name ~= "Root" then
		local h = part.Color:ToHSV()
		hues[math.floor(h * 6)] = true
	end
end
local spread = 0
for _ in hues do
	spread += 1
end
T.eq(spread, 6, "Rainbow : toutes les couleurs du cercle chromatique")
T.eq(rainbowModel:GetAttribute("Mutation"), "Rainbow", "modèle construit : attribut Mutation")

T.done("mutation_rolls")
