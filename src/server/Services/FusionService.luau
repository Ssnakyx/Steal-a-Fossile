--!strict
-- Fusion (brief 8, GDD section Fusion) : le labo de fusion du parc et ses deux modes (règles : Config.Fusion).
--   Upgrade : 3 dinos identiques (même espèce, même niveau) -> 1 dino du niveau suivant (Normal, Golden, Diamond), avec la
--             meilleure taille et la meilleure mutation des trois.
--   Hybride : 2 dinos d'espèces différentes -> la chimère de la recette (src/server/ServerConfig/Fusion.luau, secrète), avec
--             la meilleure taille et la meilleure mutation des deux, au plus petit de leurs niveaux. Recette inconnue :
--             « Unknown recipe », les dinos restent et rien n'est payé.
-- Une fusion réussie coûte des secondes de revenu des dinos utilisés et se fait dans son propre parc. Le dino obtenu sort
-- en rugissant. Un hybride a pour Species le nom de sa recette ; son modèle est la chimère de HybridBuilder (clé tête+corps
-- dans l'attribut Species du modèle), déclarée à EnclosureService.RegisterSpecies et IncomeService.RegisterBase.
-- Découverte : data.Index.Hybrids[nom] = true. Clé replica « Hybrids » (page Hybrids de l'Index) :
--   { Total, Found, List = { { Id, Hint, Found, Name?, Key?, Head?, Body?, Rarity?, Income? } } } (le nom, la clé et les
--   parents seulement une fois découvert).
-- Remotes PreviewFusion, FuseDinos ; événements OpenFusionLab (ProximityPrompt « Fuse » sur la pièce Lab du parc) et
-- FusionDone. Signaux : DinosFused(player, mode, id, dino, inputs), HybridDiscovered(player, name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Fusion = require(ReplicatedStorage.Shared.Config.Fusion)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Format = require(ReplicatedStorage.Shared.Format)
local HybridBuilder = require(ReplicatedStorage.Shared.HybridBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Signals = require(script.Parent.Parent.Lib.Signals)
local ServerConfig = require(script.Parent.Parent.ServerConfig)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local EnclosureService = require(script.Parent.EnclosureService)
local IncomeService = require(script.Parent.IncomeService)
local MoneyService = require(script.Parent.MoneyService)
local PlotService = require(script.Parent.PlotService)
local ReplicaService = require(script.Parent.ReplicaService)

type Dino = EnclosureService.Dino

-- Recette prête (lue dans ServerConfig.Fusion au démarrage)
export type Hybrid = {
	Id: number, -- place dans la liste (ordre de l'Index)
	Name: string,
	Head: string,
	Body: string,
	Hint: string,
	Key: string, -- clé HybridBuilder (attribut Species du modèle)
	Rarity: string, -- la plus haute des deux parents
	Income: number, -- revenu de base ($/s)
	BaseSize: number, -- celle du corps
}

-- Résultat calculé d'une fusion (aperçu ou fusion)
type Plan = {
	Mode: string, -- "Upgrade" | "Hybrid"
	Inputs: { { Id: string, Dino: Dino } },
	Hybrid: Hybrid?, -- recette trouvée (mode Hybrid)
	Result: Dino?, -- dino obtenu (nil : recette inconnue)
	Cost: number,
}

local FusionService = {}

local hybrids: { Hybrid } = {}
local byName: { [string]: Hybrid } = {}
local byPair: { [string]: Hybrid } = {}
local prompts: { [Player]: ProximityPrompt } = {}

local SIZE_RANK: { [string]: number } = {}
for index, size in Economy.Sizes do
	SIZE_RANK[size.Name] = index
end
local MUTATION_RANK: { [string]: number } = { [""] = 0 }
for _, mutation in Economy.Mutations do
	MUTATION_RANK[mutation.Name] = mutation.Income
end
local MAX_LEVEL = #Economy.Levels - 1

local function pairKey(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end

-- ===================================================================== recettes

-- Lit et vérifie les recettes (une recette invalide est ignorée avec un warn)
local function loadRecipes()
	table.clear(hybrids)
	table.clear(byName)
	table.clear(byPair)
	local species = Config.Species
	for _, recipe in ServerConfig.Fusion.Recipes do
		local name = recipe.Name
		local head, body = species.ByName[recipe.Head], species.ByName[recipe.Body]
		local problem: string? = nil
		if type(name) ~= "string" or #name == 0 or #name > 50 then
			problem = "nom invalide"
		elseif byName[name] or species.ByName[name] then
			problem = "nom déjà pris"
		elseif not (head and body) then
			problem = "espèce inconnue"
		elseif head == body then
			problem = "deux fois la même espèce"
		elseif byPair[pairKey(head.Name, body.Name)] then
			problem = "paire déjà utilisée"
		elseif type(recipe.Hint) ~= "string" or #recipe.Hint == 0 then
			problem = "indice manquant"
		end
		if problem then
			warn(string.format("[FusionService] recette %s ignorée : %s", tostring(name), problem))
			continue
		end
		local rankA, rankB = Rarity.Rank(Rarity.Species[head.Name] or ""), Rarity.Rank(Rarity.Species[body.Name] or "")
		local hybrid: Hybrid = {
			Id = #hybrids + 1,
			Name = name,
			Head = head.Name,
			Body = body.Name,
			Hint = recipe.Hint,
			Key = HybridBuilder.Key(head.Model, body.Model, recipe.Tweak),
			Rarity = Rarity.Order[math.max(rankA, rankB, 1)],
			Income = (head.Income + body.Income) * Fusion.HybridIncome,
			BaseSize = body.BaseSize,
		}
		table.insert(hybrids, hybrid)
		byName[name] = hybrid
		byPair[pairKey(head.Name, body.Name)] = hybrid
		IncomeService.RegisterBase(name, hybrid.Income)
		EnclosureService.RegisterSpecies(name, {
			Model = hybrid.Key,
			BaseSize = hybrid.BaseSize,
			HasModel = HybridBuilder.CanBuild(hybrid.Key),
			Rarity = hybrid.Rarity,
		})
	end
end

-- Recettes (serveur seulement)
function FusionService.Hybrids(): { Hybrid }
	return hybrids
end

-- Recette d'un hybride par son nom
function FusionService.Get(name: string): Hybrid?
	return byName[name]
end

-- Recette de deux espèces (dans les deux sens), nil s'il n'y en a pas
function FusionService.FindRecipe(a: string, b: string): Hybrid?
	if type(a) ~= "string" or type(b) ~= "string" then
		return nil
	end
	return byPair[pairKey(a, b)]
end

-- L'espèce est-elle un hybride ?
function FusionService.IsHybrid(species: string): boolean
	return byName[species] ~= nil
end

-- ===================================================================== Index

function FusionService.IsDiscovered(player: Player, name: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Index.Hybrids[name] == true
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local list = {}
	local found = 0
	for _, hybrid in hybrids do
		local entry: { [string]: any } = { Id = hybrid.Id, Hint = hybrid.Hint, Found = false }
		if data.Index.Hybrids[hybrid.Name] then
			found += 1
			entry.Found = true
			entry.Name = hybrid.Name
			entry.Key = hybrid.Key
			entry.Head = hybrid.Head
			entry.Body = hybrid.Body
			entry.Rarity = hybrid.Rarity
			entry.Income = hybrid.Income
		end
		table.insert(list, entry)
	end
	ReplicaService.Set(player, "Hybrids", { Total = #hybrids, Found = found, List = list })
end

-- Renvoie la clé replica « Hybrids » au joueur (après avoir changé data.Index.Hybrids à la main : debug, admin)
function FusionService.Publish(player: Player)
	publish(player)
end

-- Marque un hybride comme découvert ; renvoie true si c'est nouveau
function FusionService.Discover(player: Player, name: string): boolean
	local data = DataService.Get(player)
	if not (data and byName[name]) or data.Index.Hybrids[name] then
		return false
	end
	data.Index.Hybrids[name] = true
	publish(player)
	Signals.Fire("HybridDiscovered", player, name)
	return true
end

-- ===================================================================== calcul d'une fusion

-- Ids envoyés par le client : liste de 2 ou 3 textes distincts, dinos du joueur. Renvoie les dinos ou un texte d'erreur.
local function readInputs(player: Player, ids: any): ({ { Id: string, Dino: Dino } }?, string?)
	local data = DataService.Get(player)
	if not data then
		return nil, "Please wait..."
	end
	if type(ids) ~= "table" then
		return nil, "Pick dinos to fuse."
	end
	local inputs: { { Id: string, Dino: Dino } } = {}
	local seen: { [string]: boolean } = {}
	local count = 0
	for index, value in ids do
		count += 1
		if count > Fusion.UpgradeCount or index ~= count then
			return nil, "Pick 2 or 3 dinos."
		end
		local id = Guard.String(value, 12)
		if not (id and string.match(id, "^%d+$")) or seen[id] then
			return nil, "Pick 2 or 3 different dinos."
		end
		seen[id] = true
		local dino = data.Dinos[id]
		if not dino then
			return nil, "This dino is not in your park."
		end
		table.insert(inputs, { Id = id, Dino = dino })
	end
	if count ~= Fusion.HybridCount and count ~= Fusion.UpgradeCount then
		return nil, "Pick 2 dinos for a hybrid or 3 identical dinos to upgrade."
	end
	return inputs, nil
end

local function best(inputs: { { Id: string, Dino: Dino } }): (string, string, number, number)
	local size, mutation = "Small", ""
	local low, high = math.huge, 0
	for _, input in inputs do
		local dino = input.Dino
		if (SIZE_RANK[dino.Size] or 0) > (SIZE_RANK[size] or 0) then
			size = dino.Size
		end
		if (MUTATION_RANK[dino.Mutation] or 0) > (MUTATION_RANK[mutation] or 0) then
			mutation = dino.Mutation
		end
		low = math.min(low, dino.Level)
		high = math.max(high, dino.Level)
	end
	return size, mutation, low, high
end

-- Plan d'une fusion (sans rien changer). Renvoie (plan) ou (nil, texte).
local function plan(player: Player, ids: any): (Plan?, string?)
	local inputs, problem = readInputs(player, ids)
	if not inputs then
		return nil, problem
	end
	local size, mutation, low, high = best(inputs)
	local income = 0
	for _, input in inputs do
		income += IncomeService.DinoIncome(input.Dino)
	end
	local first = inputs[1].Dino
	if #inputs == Fusion.UpgradeCount then
		for _, input in inputs do
			if input.Dino.Species ~= first.Species then
				return nil, "Upgrade needs 3 dinos of the same species."
			end
		end
		if low ~= high then
			return nil, "Upgrade needs 3 dinos of the same level."
		end
		if low >= MAX_LEVEL then
			return nil, "This dino is already at max level!"
		end
		return {
			Mode = "Upgrade",
			Inputs = inputs,
			Hybrid = nil,
			Result = { Species = first.Species, Size = size, Mutation = mutation, Level = low + 1, Got = 0 },
			Cost = math.max(Fusion.MinCost, math.floor(income * Fusion.CostSeconds.Upgrade)),
		},
			nil
	end
	local second = inputs[2].Dino
	if first.Species == second.Species then
		return nil, "A hybrid needs 2 different species. Use 3 to upgrade!"
	end
	local hybrid = FusionService.FindRecipe(first.Species, second.Species)
	return {
		Mode = "Hybrid",
		Inputs = inputs,
		Hybrid = hybrid,
		Result = if hybrid then { Species = hybrid.Name, Size = size, Mutation = mutation, Level = low, Got = 0 } else nil,
		Cost = math.max(Fusion.MinCost, math.floor(income * Fusion.CostSeconds.Hybrid)),
	},
		nil
end

-- Infos d'un résultat pour le client. Un hybride pas encore découvert reste « ??? » (que la recette existe ou non).
local function describe(player: Player, p: Plan): { [string]: any }
	local result = p.Result
	local known = result ~= nil and (p.Mode == "Upgrade" or FusionService.IsDiscovered(player, result.Species))
	if not (known and result) then
		return { Mode = p.Mode, Known = false, Species = Fusion.UnknownName, Cost = p.Cost }
	end
	local level = Economy.Levels[result.Level + 1]
	local hybrid = byName[result.Species]
	return {
		Mode = p.Mode,
		Known = true,
		Species = result.Species,
		Key = if hybrid then hybrid.Key else nil,
		Size = result.Size,
		Mutation = result.Mutation,
		Level = result.Level,
		LevelName = if level then level.Name else "Normal",
		Income = IncomeService.DinoIncome(result),
		Rarity = if hybrid then hybrid.Rarity else Rarity.Species[result.Species],
		Cost = p.Cost,
	}
end

-- Aperçu d'une fusion. Renvoie (ok, infos) ou (false, texte).
function FusionService.Preview(player: Player, ids: any): (boolean, any)
	local p, problem = plan(player, ids)
	if not p then
		return false, problem or "Error"
	end
	return true, describe(player, p)
end

export type FuseOptions = { Free: boolean?, Anywhere: boolean? }

-- Fusionne. Renvoie (ok, texte, infos?). Options (commandes d'admin) : Free (gratuit), Anywhere (hors du parc).
function FusionService.Fuse(player: Player, ids: any, options: FuseOptions?): (boolean, string, any)
	local free = options ~= nil and options.Free == true
	if not (options and options.Anywhere) and not PlotService.IsInOwnPlot(player) then
		return false, "Go to the lab in your park to fuse!", nil
	end
	local p, problem = plan(player, ids)
	if not p then
		return false, problem or "Error", nil
	end
	-- (place et argent vérifiés avant la recette : sinon la réponse dirait si une paire est une recette sans la payer)
	-- (enclos au-dessus de sa taille, ne devrait pas arriver : le dino obtenu doit avoir sa place une fois les autres partis)
	if EnclosureService.Count(player) - #p.Inputs + 1 > EnclosureService.Slots(player) then
		return false, "Your enclosure is too full!", nil
	end
	local cost = if free then 0 else p.Cost
	local tooPoor = "Not enough money! Fusion costs " .. Format.Money(cost) .. "."
	if cost > 0 and not MoneyService.CanAfford(player, cost) then
		return false, tooPoor, nil
	end
	local result = p.Result
	if not result then
		return false, "Unknown recipe! Your dinos are safe. Try another pair.", nil
	end
	if cost > 0 and not MoneyService.Spend(player, cost, "Fusion") then
		return false, tooPoor, nil
	end
	-- (tout est vérifié : aucune attente entre ici et la fin, deux demandes ne fusionnent jamais les mêmes dinos)
	local removed: { Dino } = {}
	local inputs: { string } = {}
	for _, input in p.Inputs do
		local dino = EnclosureService.RemoveDino(player, input.Id)
		if dino then
			table.insert(removed, dino)
			table.insert(inputs, dino.Species)
		end
	end
	local id = if #removed == #p.Inputs then EnclosureService.AddDino(player, result, Fusion.ResultState) else nil
	if not id then
		-- (ne devrait pas arriver : on remet les dinos et l'argent)
		for _, dino in removed do
			EnclosureService.AddDino(player, dino)
		end
		if cost > 0 then
			MoneyService.Add(player, cost, "FusionRefund")
		end
		warn("[FusionService] fusion annulée pour " .. player.Name)
		return false, "Error", nil
	end
	local dino = EnclosureService.GetDino(player, id) :: Dino
	local isNew = false
	if p.Mode == "Hybrid" then
		isNew = FusionService.Discover(player, dino.Species)
	end
	local info = describe(player, p)
	info.Id = id
	info.Inputs = inputs
	info.New = isNew
	Remotes.Event("FusionDone"):FireClient(player, info)
	Signals.Fire("DinosFused", player, p.Mode, id, dino, inputs)
	local name = EnclosureService.DisplayName(dino)
	if isNew then
		return true, "New hybrid discovered: " .. name .. "!", info
	end
	return true, "You made a " .. name .. "!", info
end

-- ===================================================================== labo du parc

local function addPrompt(player: Player)
	local plot = PlotService.Get(player)
	local lab = plot and plot.Lab
	if not lab then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LabPrompt"
	prompt.ActionText = "Fuse"
	prompt.ObjectText = "Fusion Lab"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Triggered:Connect(function(who: Player)
		if who ~= player then
			Notify.Send(who, "This is not your park!", "error")
			return
		end
		if RateLimit.Allow(player, "LabPrompt", 2, 3) then
			Remotes.Event("OpenFusionLab"):FireClient(player)
		end
	end)
	prompt.Parent = lab
	prompts[player] = prompt
end

-- ===================================================================== admin

local function findHybrid(text: string): Hybrid?
	local wanted = string.lower((string.gsub(text, "[^%w]", "")))
	for _, hybrid in hybrids do
		if string.lower((string.gsub(hybrid.Name, "[^%w]", ""))) == wanted then
			return hybrid
		end
	end
	return nil
end

local function registerAdmin()
	AdminService.RegisterCommand("fuse", {
		Description = "Fuse dinos by id (free, from anywhere)",
		Usage = "fuse <id> <id> [id]",
		Run = function(caller: Player, args: { string })
			local ok, text = FusionService.Fuse(caller, args, { Free = true, Anywhere = true })
			return ok, text
		end,
	})
	AdminService.RegisterCommand("givehybrid", {
		Description = "Put a hybrid in the enclosure (and discover it)",
		Usage = "givehybrid <name|all> [Small|Normal|Big|Huge] [Amber|Crystal|Lava|none] [player]",
		Run = function(caller: Player, args: { string })
			local target = AdminService.FindPlayer(caller, args[4])
			local list: { Hybrid } = {}
			if string.lower(args[1] or "") == "all" then
				list = hybrids
			else
				local hybrid = findHybrid(args[1] or "")
				if hybrid then
					list = { hybrid }
				end
			end
			if not target or #list == 0 then
				return false, "Usage: givehybrid <name|all> [size] [mutation] [player]"
			end
			local given = 0
			for _, hybrid in list do
				if EnclosureService.AddDino(target, { Species = hybrid.Name, Size = args[2], Mutation = args[3] }, Fusion.ResultState) then
					FusionService.Discover(target, hybrid.Name)
					given += 1
				end
			end
			if given == 0 then
				return false, "Enclosure full"
			end
			return true, string.format("%d hybrid(s) added", given)
		end,
	})
	AdminService.RegisterCommand("hybrids", {
		Description = "List the hybrid recipes (secret!)",
		Usage = "hybrids [player]",
		Run = function(caller: Player, args: { string })
			local target = AdminService.FindPlayer(caller, args[1])
			local lines = {}
			for _, hybrid in hybrids do
				local found = target ~= nil and FusionService.IsDiscovered(target, hybrid.Name)
				table.insert(lines, string.format("%s%s = %s + %s", if found then "[x] " else "", hybrid.Name, hybrid.Head, hybrid.Body))
			end
			return true, table.concat(lines, "\n")
		end,
	})
end

-- ===================================================================== cycle de vie

function FusionService.Init()
	loadRecipes()
	Net.Function("PreviewFusion", { Rate = 6, Burst = 10 }, function(player: Player, ids: any)
		return FusionService.Preview(player, ids)
	end)
	Net.Function("FuseDinos", { Rate = 2, Burst = 4 }, function(player: Player, ids: any)
		local ok, text, info = FusionService.Fuse(player, ids)
		return ok, text, info
	end)
	registerAdmin()
end

function FusionService.OnPlayerReady(player: Player, _data: { [string]: any })
	addPrompt(player)
	publish(player)
end

function FusionService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	local prompt = prompts[player]
	prompts[player] = nil
	if prompt then
		prompt:Destroy()
	end
end

return FusionService
