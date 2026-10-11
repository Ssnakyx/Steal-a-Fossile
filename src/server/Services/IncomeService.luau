--!strict
-- Revenus des dinos (brief 3 « boucle ») : chaque seconde, chaque dino de l'enclos rapporte
-- base de l'espèce x taille x mutation x niveau (GDD), le tout x les multiplicateurs du joueur.
-- Base : Config.Species (brief 2) ; sinon une base enregistrée (RegisterBase, hybrides du brief 8) ; sinon
-- Config.Economy.FallbackIncome selon la rareté de l'espèce.
-- Multiplicateurs : pass Double Money (ShopService.HasPass du brief 4, s'il existe) et SetMultiplier (bonus ami du
-- brief 15, événements...).
-- Revenu hors ligne à l'arrivée, plafonné à 8 h (data.LastSeen du domaine Core = heure de la dernière sauvegarde).
-- Clé replica « Income » ($/s, multiplicateurs compris). L'argent passe par MoneyService (raisons « Income », « Offline »).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Format = require(ReplicatedStorage.Shared.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Notify = require(script.Parent.Parent.Lib.Notify)
local DataService = require(script.Parent.DataService)
local MoneyService = require(script.Parent.MoneyService)
local ReplicaService = require(script.Parent.ReplicaService)

local IncomeService = {}

local SIZE_INCOME: { [string]: number } = {}
for _, size in Economy.Sizes do
	SIZE_INCOME[size.Name] = size.Income
end
local MUTATION_INCOME: { [string]: number } = {}
for _, mutation in Economy.Mutations do
	MUTATION_INCOME[mutation.Name] = mutation.Income
end

local registered: { [string]: number } = {}
local multipliers: { [Player]: { [string]: number } } = {}
local ready: { [Player]: boolean } = {}
local published: { [Player]: number } = {}
local speciesConfig: any = nil

-- Fiche de l'espèce dans Config.Species du brief 2 (nil tant que ce fichier n'existe pas ou sans cette espèce)
function IncomeService.SpeciesInfo(species: string): any
	if speciesConfig == nil then
		local folder = ReplicatedStorage.Shared:FindFirstChild("Config")
		speciesConfig = if folder and folder:FindFirstChild("Species") then Config.Species else false
	end
	if speciesConfig and type(speciesConfig.ByName) == "table" then
		return speciesConfig.ByName[species]
	end
	return nil
end

-- Revenu de base d'une espèce ou d'un hybride ($/s)
function IncomeService.BaseIncome(species: string): number
	local info = IncomeService.SpeciesInfo(species)
	if info and Guard.IsFinite(info.Income) and info.Income >= 0 then
		return info.Income
	end
	local base = registered[species]
	if base then
		return base
	end
	local rarity = Rarity.Species[species]
	return if rarity then Economy.FallbackIncome[rarity] or 0 else 0
end

-- Revenu de base d'une espèce absente de Config.Species (hybrides du brief 8, enregistrés dans leur Init)
function IncomeService.RegisterBase(species: string, income: number)
	if type(species) ~= "string" or not Guard.IsFinite(income) or income < 0 then
		error("IncomeService.RegisterBase : espèce ou revenu invalide", 2)
	end
	registered[species] = income
end

-- Revenu d'un dino ($/s, sans les multiplicateurs du joueur) : base x taille x mutation x niveau
function IncomeService.DinoIncome(dino: { [string]: any }): number
	local base = IncomeService.BaseIncome(dino.Species)
	local size = SIZE_INCOME[dino.Size] or 1
	local mutation = MUTATION_INCOME[dino.Mutation] or 1
	local level = Economy.Levels[(tonumber(dino.Level) or 0) + 1]
	return base * size * mutation * (if level then level.Income else 1)
end

local function hasPass(player: Player, pass: string): boolean
	local module = script.Parent:FindFirstChild("ShopService")
	if not (module and module:IsA("ModuleScript")) then
		return false
	end
	local ok, owned = pcall(function()
		return (require :: any)(module).HasPass(player, pass)
	end)
	return ok and owned == true
end

-- Multiplicateur nommé (nil l'enlève) : IncomeService.SetMultiplier(player, "Friends", 1.2)
function IncomeService.SetMultiplier(player: Player, key: string, value: number?)
	if value ~= nil and (not Guard.IsFinite(value) or value < 0) then
		error("IncomeService.SetMultiplier : valeur invalide", 2)
	end
	local list = multipliers[player]
	if not list then
		if value == nil or not ready[player] then
			return
		end
		list = {}
		multipliers[player] = list
	end
	if value == nil then
		list[key] = nil
	else
		list[key] = value
	end
	IncomeService.Refresh(player)
end

-- Produit des multiplicateurs du joueur (pass Double Money compris)
function IncomeService.Multiplier(player: Player): number
	local total = if hasPass(player, "DoubleMoney") then Economy.Passes.DoubleMoney else 1
	local list = multipliers[player]
	if list then
		for _, value in list do
			total *= value
		end
	end
	return total
end

-- Revenu total du joueur ($/s, multiplicateurs compris)
function IncomeService.GetIncome(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, dino in data.Dinos do
		total += IncomeService.DinoIncome(dino)
	end
	return total * IncomeService.Multiplier(player)
end

-- Recalcule et envoie le revenu au client (après un changement de l'enclos)
function IncomeService.Refresh(player: Player): number
	local income = IncomeService.GetIncome(player)
	if published[player] ~= income and ready[player] then
		published[player] = income
		ReplicaService.Set(player, "Income", income)
	end
	return income
end

local function pay(player: Player, seconds: number)
	local income = IncomeService.Refresh(player)
	if income > 0 then
		MoneyService.Add(player, income * seconds, "Income")
	end
end

function IncomeService.Start()
	while true do
		task.wait(Economy.IncomeInterval)
		for player in ready do
			pay(player, Economy.IncomeInterval)
		end
	end
end

function IncomeService.OnPlayerReady(player: Player, data: { [string]: any })
	ready[player] = true
	local income = IncomeService.Refresh(player)
	local lastSeen = data.LastSeen
	if income > 0 and type(lastSeen) == "number" and lastSeen > 0 then
		local away = math.clamp(os.time() - lastSeen, 0, Economy.OfflineCap)
		local earned = income * away
		if earned > 0 and MoneyService.Add(player, earned, "Offline") then
			Notify.Send(player, string.format("You earned %s while away!", Format.Money(earned)), "money")
		end
	end
end

function IncomeService.OnPlayerRemoving(player: Player, _data: { [string]: any })
	ready[player] = nil
	multipliers[player] = nil
	published[player] = nil
end

return IncomeService
