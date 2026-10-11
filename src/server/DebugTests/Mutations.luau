--!strict
-- Tests FossilDebug des mutations (docs/MUTATIONS.md) et des espèces (Config.Species, modèles de src/shared/DinoModels).
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("mutations")
-- (ou "species", "all"). Chaque test remet le jeu comme il l'a trouvé (dinos de test retirés, modèles détruits).
-- Outils pour regarder en jeu (vitrine devant le premier joueur, animée chez le client comme les vrais dinos) :
--   FossilDebug:Invoke("dinoshow")                     toutes les espèces, une rangée par zone (+ les Secrets)
--   FossilDebug:Invoke("dinoshow", "Glacier")          une zone (nom ou 1 à 8), ou "secret"
--   FossilDebug:Invoke("mutationshow", "Velociraptor") une espèce avec chaque mutation (effets animés compris)
--   FossilDebug:Invoke("mutationshow", "Compy", "Huge", "Golden")  avec une taille et un niveau
--   FossilDebug:Invoke("clearshow")                    retire la vitrine

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DinoBuilder = require(ReplicatedStorage.Shared.DinoBuilder)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Species = require(ReplicatedStorage.Shared.Config.Species)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local EnclosureService = require(Services.EnclosureService)
local IncomeService = require(Services.IncomeService)
local MutationService = require(Services.MutationService)

type Tester = DebugService.Tester

local SHOW_NAME = "DinoShowcase"
local MAX_PIECES = 450 -- pièces au plus par dino (models/BRIEF.md)

-- ===================================================================== vitrine

local function firstRoot(): BasePart?
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				return root
			end
		end
	end
	return nil
end

-- Sol sous un point (vitrine posée dessus), sinon 3 studs sous les pieds
local function groundY(from: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(from + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else from.Y - 3
end

local function label(root: BasePart, top: string, bottom: string, height: number, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShowLabel"
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, height + 1.5, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	for index, text in { top, bottom } do
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0, (index - 1) * 0.55)
		line.Size = UDim2.fromScale(1, if index == 1 then 0.55 else 0.45)
		line.Font = Enum.Font.GothamBold
		line.TextScaled = true
		line.TextColor3 = if index == 1 then Color3.new(1, 1, 1) else color
		line.TextStrokeTransparency = 0.3
		line.Text = text
		line.Parent = gui
	end
	gui.Parent = root
end

type Entry = { Module: string, Top: string, Bottom: string, Color: Color3, Rank: number, Options: DinoBuilder.BuildOptions }

-- Vitrine : rangées de dinos (une liste par rangée) devant le premier joueur, tournés vers lui
local function showcase(rows: { { Entry } }): string
	local root = firstRoot()
	if not root then
		return "No loaded player with a character"
	end
	local old = Workspace:FindFirstChild(SHOW_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = SHOW_NAME
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local right = forward:Cross(Vector3.yAxis)
	local ignore: { Instance } = { folder }
	if root.Parent then
		table.insert(ignore, root.Parent)
	end
	local depth = 10
	local count = 0
	for _, row in rows do
		-- largeur de chaque dino (tourné vers le joueur : sa largeur X le long de la rangée), profondeur de la rangée
		local widths, rowDepth, total = {}, 0, 0
		for index, entry in row do
			local data = DinoBuilder.Get(entry.Module)
			local scale = DinoBuilder.ScaleOf(entry.Options)
			local width = if data then data.Size.X * scale else 6
			widths[index] = math.max(width, 4) + 3
			total += widths[index]
			rowDepth = math.max(rowDepth, if data then data.Size.Z * scale else 6)
		end
		depth += rowDepth / 2
		local x = -total / 2
		for index, entry in row do
			x += widths[index] / 2
			local spot = root.Position + forward * depth + right * x
			spot = Vector3.new(spot.X, groundY(spot, ignore), spot.Z)
			local model = DinoBuilder.CreateProxy(entry.Module, entry.Options)
			model.Name = entry.Module
			-- (tête vers -Z du modèle : regarde le joueur)
			model:PivotTo(CFrame.lookAt(spot, spot - forward))
			local proxyRoot = model.PrimaryPart
			local data = DinoBuilder.Get(entry.Module)
			if proxyRoot then
				local height = if data then data.Size.Y * DinoBuilder.ScaleOf(entry.Options) else 6
				label(proxyRoot, entry.Top, entry.Bottom, height, entry.Color)
			end
			model.Parent = folder
			count += 1
			x += widths[index] / 2
		end
		depth += rowDepth / 2 + 8
	end
	folder.Parent = Workspace
	return string.format("%d dinos in workspace.%s (clearshow to remove)", count, SHOW_NAME)
end

local function rarityColor(name: string?): Color3
	local info = if name then Rarity.Info[name] else nil
	return if info then info.Color else Color3.new(1, 1, 1)
end

local function speciesEntry(def: Species.SpeciesDef): Entry
	local rarity = Rarity.Species[def.Name]
	return {
		Module = def.Model,
		Top = def.Name,
		Bottom = string.format("%s - %s", rarity or "?", def.Zone),
		Color = rarityColor(rarity),
		Rank = Rarity.Rank(rarity or ""),
		Options = { Rarity = rarity },
	}
end

-- Espèce d'après son nom ou son module (sans faire attention aux majuscules, espaces ni tirets)
local function findSpecies(text: string?): Species.SpeciesDef?
	if type(text) ~= "string" then
		return nil
	end
	local wanted = string.lower((string.gsub(text, "[^%w]", "")))
	for _, def in Species.List do
		if string.lower(def.Model) == wanted or string.lower((string.gsub(def.Name, "[^%w]", ""))) == wanted then
			return def
		end
	end
	return nil
end

DebugService.RegisterCommand("dinoshow", function(which: any?): string
	local rows: { { Entry } } = {}
	local wanted = if type(which) == "string" and which ~= "" then string.lower(which) else "all"
	local zone = if wanted ~= "all" and wanted ~= "secret" then MutationService.FindZone(which) else nil
	if wanted ~= "all" and wanted ~= "secret" and not zone then
		return "Usage: dinoshow [all | secret | zone 1-8 or name]"
	end
	for _, z in Zones.List do
		if wanted == "all" or zone == z.Name then
			local row = {}
			for _, def in Species.List do
				if def.Zone == z.Name then
					table.insert(row, speciesEntry(def))
				end
			end
			-- de la plus commune à la plus rare
			table.sort(row, function(a, b)
				return if a.Rank ~= b.Rank then a.Rank < b.Rank else a.Top < b.Top
			end)
			table.insert(rows, row)
		end
	end
	if wanted == "all" or wanted == "secret" then
		local row = {}
		for _, def in Species.List do
			if def.Secret then
				table.insert(row, speciesEntry(def))
			end
		end
		table.insert(rows, row)
	end
	return showcase(rows)
end)

DebugService.RegisterCommand("mutationshow", function(name: any?, size: any?, level: any?): string
	local def = findSpecies(if type(name) == "string" then name else "Velociraptor")
	if not def then
		return "Unknown species " .. tostring(name)
	end
	local sizeName = if type(size) == "string" and DinoBuilder.Sizes[size] then size else "Normal"
	local levelName = if type(level) == "string" and table.find(DinoBuilder.Levels, level) then level else nil
	local rarity = Rarity.Species[def.Name]
	local row: { Entry } = {
		{ Module = def.Model, Top = def.Name, Bottom = "No mutation", Color = Color3.new(1, 1, 1), Rank = 0, Options = { Size = sizeName, Level = levelName, Rarity = rarity } },
	}
	for _, info in Economy.Mutations do
		table.insert(row, {
			Module = def.Model,
			Top = info.Name,
			Bottom = string.format("%s x%s", MutationService.Odds(info), tostring(info.Income)),
			Color = info.Color,
			Rank = 0,
			Options = { Size = sizeName, Level = levelName, Mutation = info.Name, Rarity = rarity },
		})
	end
	-- deux rangées : les communes devant, les rares derrière
	local front, back = {}, {}
	for index, entry in row do
		table.insert(if index <= 7 then front else back, entry)
	end
	return showcase({ front, back })
end)

DebugService.RegisterCommand("clearshow", function(): string
	local old = Workspace:FindFirstChild(SHOW_NAME)
	if old then
		old:Destroy()
		return "Showcase removed"
	end
	return "No showcase"
end)

-- ===================================================================== tests

return {
	mutations = function(t: Tester)
		-- liste et probas de chaque zone
		local seen: { [string]: boolean } = {}
		for _, info in Economy.Mutations do
			t:Check(not seen[info.Name], info.Name .. ": unique name")
			seen[info.Name] = true
			t:Check(info.Chance > 0 and info.Income > 1, info.Name .. ": chance and income")
		end
		t:Equal(table.concat(DinoBuilder.Mutations, ","), (function()
			local names = {}
			for _, info in Economy.Mutations do
				table.insert(names, info.Name)
			end
			return table.concat(names, ",")
		end)(), "DinoBuilder knows every mutation")
		for _, zone in Zones.List do
			local total, own = 0, 0
			for _, chance in Economy.MutationChances(zone.Name, 0) do
				total += chance.Chance
				local info = Economy.Mutation(chance.Name)
				if info and info.Zone == zone.Name then
					own += 1
				end
			end
			t:Check(math.abs(total - 1) < 1e-9, zone.Name .. ": odds add up to 100%", total)
			t:Equal(own, 1, zone.Name .. ": one mutation of its own")
		end
		-- apparence : chaque mutation construit un dino (attribut Mutation)
		for _, info in Economy.Mutations do
			local model = DinoBuilder.Build("Velociraptor", { Mutation = info.Name })
			t:Equal(model:GetAttribute("Mutation"), info.Name, info.Name .. ": dino built")
			model:Destroy()
		end
		local someone = { DisplayName = "Test" } :: any
		local function announced(mutation: string): boolean
			return MutationService.AnnounceText(someone, { Species = "Compy", Size = "Normal", Mutation = mutation, Level = 0, Got = 0 }) ~= nil
		end
		t:Check(announced("Rainbow"), "Rainbow is announced to the server")
		t:Check(not announced("Amber"), "Amber is not announced")
		-- dans l'enclos du joueur : modèle, revenu, nom
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local added = 0
		for _, info in Economy.Mutations do
			if not EnclosureService.HasRoom(target) then
				t:Note("enclosure full: stopped at " .. info.Name)
				break
			end
			local id = EnclosureService.AddDino(target, { Species = "Compy", Size = "Normal", Mutation = info.Name })
			if not t:Check(id, info.Name .. ": test dino added") then
				continue
			end
			local dinoId = id :: string
			added += 1
			local dino = EnclosureService.GetDino(target, dinoId)
			local model = EnclosureService.ModelOf(target, dinoId)
			t:Equal(model and model:GetAttribute("Mutation"), info.Name, info.Name .. ": Mutation attribute")
			if dino then
				t:Check(math.abs(IncomeService.DinoIncome(dino) - IncomeService.BaseIncome("Compy") * info.Income) < 1e-6, info.Name .. ": income x" .. info.Income)
				t:Equal(EnclosureService.DisplayName(dino), info.Name .. " Compy", info.Name .. ": display name")
			end
			t:Check(EnclosureService.RemoveDino(target, dinoId), info.Name .. ": test dino removed")
		end
		t:Note(string.format("%d mutations tried in the enclosure", added))
	end,

	species = function(t: Tester)
		local zoneNames: { [string]: boolean } = {}
		for _, zone in Zones.List do
			zoneNames[zone.Name] = true
		end
		local biggest, biggestName = 0, ""
		for _, def in Species.List do
			local rarity = Rarity.Species[def.Name]
			t:Check(rarity and Rarity.Info[rarity], def.Name .. ": rarity", rarity)
			t:Check(zoneNames[def.Zone] or def.Secret, def.Name .. ": zone", def.Zone)
			if not def.Secret then
				local zone = Zones.ByName[def.Zone]
				t:Check(zone and table.find(zone.Species, def.Name), def.Name .. ": in its zone list")
				t:Check(zone and rarity and zone.Weights[rarity], def.Name .. ": its rarity drops in its zone", rarity)
			end
			local data = DinoBuilder.Get(def.Model)
			if not t:Check(data, def.Name .. ": model " .. def.Model) then
				continue
			end
			local model = DinoBuilder.Build(def.Model)
			local pieces = 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute("Bone") then
					pieces += 1
				end
			end
			model:Destroy()
			t:Check(pieces > 0 and pieces <= MAX_PIECES, def.Name .. ": pieces within budget", pieces)
			if pieces > biggest then
				biggest, biggestName = pieces, def.Name
			end
			local d = data :: DinoBuilder.Data
			t:Check(d.Clips.Idle and d.Clips.Walk, def.Name .. ": Idle and Walk animations")
		end
		-- chaque rareté d'une zone a au moins une espèce de la zone
		for _, zone in Zones.List do
			for rarity in zone.Weights do
				if rarity ~= "Secret" then
					local found = 0
					for _, name in zone.Species do
						if Rarity.Species[name] == rarity then
							found += 1
						end
					end
					t:Check(found > 0, zone.Name .. ": a " .. rarity .. " species", found)
				end
			end
		end
		t:Note(string.format("%d species, biggest model: %s (%d pieces)", #Species.List, biggestName, biggest))
	end,
}
