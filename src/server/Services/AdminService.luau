--!strict
-- Administrateurs et commandes d'admin (reprise de Steal a Snack et adaptée, brief 1).
-- Admin : un UserId de Config.Core.Admins, le propriétaire du jeu publié (compte, ou propriétaire du groupe), ou tout
-- joueur de test dans Studio (Config.Core.Admin.StudioEveryone). Attribut « Admin » = true sur le joueur.
-- Chaque domaine ajoute ses commandes (en général dans son Init) :
--   AdminService.RegisterCommand("meteor", {
--       Description = "Start a meteor shower now",
--       Usage = "meteor",
--       Run = function(player, args) ... return true, "Meteor shower started" end,
--   })
-- Le client les lance par le remote Admin (nom, { arguments en texte }) -> (ok, texte). Le serveur vérifie le droit à
-- chaque appel. Textes de réponse en anglais.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Config.Core)
local Format = require(ReplicatedStorage.Shared.Format)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local MoneyService = require(script.Parent.MoneyService)
local ReceiptService = require(script.Parent.ReceiptService)

export type Command = {
	Description: string,
	Usage: string?,
	Run: (player: Player, args: { string }) -> (boolean, string),
}

local AdminService = {}
AdminService.Priority = -60

local commands: { [string]: Command } = {}
local cache: { [number]: boolean } = {}

local MAX_ARGS = 10
local MAX_ARG_LENGTH = 100

local groupOwner: number? = nil

-- Propriétaire du groupe qui possède le jeu (nil si Roblox ne répond pas : on redemandera)
local function groupOwnerId(): number?
	if groupOwner then
		return groupOwner
	end
	local ok, info = pcall(function()
		return GroupService:GetGroupInfoAsync(game.CreatorId)
	end)
	if ok and type(info) == "table" and type(info.Owner) == "table" and type(info.Owner.Id) == "number" then
		groupOwner = info.Owner.Id
	end
	return groupOwner
end

local function lookup(player: Player): boolean?
	if table.find(Core.Admins, player.UserId) then
		return true
	end
	if game.CreatorId == 0 then
		return false
	end
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId == player.UserId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local owner = groupOwnerId()
		if owner == nil then
			return nil
		end
		return owner == player.UserId
	end
	return false
end

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() and Core.Admin.StudioEveryone then
		return true
	end
	local known = cache[player.UserId]
	if known ~= nil then
		return known
	end
	local result = lookup(player)
	if result == nil then
		return false
	end
	cache[player.UserId] = result
	return result
end

function AdminService.RegisterCommand(name: string, command: Command)
	if type(name) ~= "string" or not string.match(name, "^%l[%l%d]*$") then
		error("AdminService.RegisterCommand : nom invalide (minuscules et chiffres) " .. tostring(name), 2)
	end
	if commands[name] then
		error("AdminService.RegisterCommand : commande déjà prise " .. name, 2)
	end
	if type(command) ~= "table" or type(command.Run) ~= "function" or type(command.Description) ~= "string" then
		error("AdminService.RegisterCommand(" .. name .. ") : il faut { Description, Run }", 2)
	end
	commands[name] = command
end

-- Lance une commande pour `player` (droit vérifié ici). Renvoie (ok, texte).
function AdminService.Run(player: Player, name: any, args: any): (boolean, string)
	if not AdminService.IsAdmin(player) then
		return false, "Not allowed"
	end
	local commandName = Guard.String(name, 30)
	local command = commandName and commands[string.lower(commandName)]
	if not command then
		return false, "Unknown command (try: help)"
	end
	local clean: { string } = {}
	if args ~= nil then
		if type(args) ~= "table" then
			return false, "Bad arguments"
		end
		for index = 1, MAX_ARGS + 1 do
			local value = args[index]
			if value == nil then
				break
			end
			if index > MAX_ARGS then
				return false, "Too many arguments"
			end
			local text = if type(value) == "number" and Guard.IsFinite(value) then tostring(value) else Guard.String(value, MAX_ARG_LENGTH)
			if not text then
				return false, "Bad arguments"
			end
			table.insert(clean, text)
		end
	end
	local ok, success, message = pcall(command.Run, player, clean)
	if not ok then
		warn(string.format("[AdminService] %s : %s", tostring(commandName), tostring(success)))
		return false, "Error"
	end
	return success == true, if type(message) == "string" then message else ""
end

-- Liste des commandes, triées (aide, panneau d'admin)
function AdminService.Commands(): { { Name: string, Description: string, Usage: string } }
	local list = {}
	for name, command in commands do
		table.insert(list, { Name = name, Description = command.Description, Usage = command.Usage or name })
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- Joueur visé par une commande : nom (début du nom ou du nom affiché) ou « me »
function AdminService.FindPlayer(caller: Player, text: string?): Player?
	if text == nil or text == "" or string.lower(text) == "me" then
		return caller
	end
	local wanted = string.lower(text)
	for _, player in Players:GetPlayers() do
		if string.sub(string.lower(player.Name), 1, #wanted) == wanted or string.sub(string.lower(player.DisplayName), 1, #wanted) == wanted then
			return player
		end
	end
	return nil
end

AdminService.RegisterCommand("help", {
	Description = "List admin commands",
	Run = function()
		local lines = {}
		for _, entry in AdminService.Commands() do
			table.insert(lines, entry.Usage .. " : " .. entry.Description)
		end
		return true, table.concat(lines, "\n")
	end,
})

AdminService.RegisterCommand("money", {
	Description = "Give money (or set it with =)",
	Usage = "money <amount | =amount> [player]",
	Run = function(player, args)
		local text = args[1] or ""
		local set = string.sub(text, 1, 1) == "="
		local amount = tonumber(if set then string.sub(text, 2) else text)
		local target = AdminService.FindPlayer(player, args[2])
		if not target then
			return false, "Player not found"
		end
		if amount == nil or not Guard.Number(amount, 0, Core.Admin.MaxMoney) then
			return false, "Amount between 0 and " .. Format.Number(Core.Admin.MaxMoney)
		end
		local ok = if set then MoneyService.Set(target, amount, "Admin") else MoneyService.Add(target, amount, "Admin")
		if not ok then
			return false, "Player not loaded"
		end
		return true, string.format("%s now has %s", target.Name, Format.Money(MoneyService.Get(target)))
	end,
})

AdminService.RegisterCommand("simulate", {
	Description = "Simulate a free purchase of a developer product (Studio only)",
	Usage = "simulate <productKey> [player]",
	Run = function(player, args)
		-- (jamais sur un vrai serveur : un produit payant ne se donne pas gratuitement en jeu)
		if not RunService:IsStudio() then
			return false, "Studio only"
		end
		local target = AdminService.FindPlayer(player, args[2])
		if not target then
			return false, "Player not found"
		end
		return ReceiptService.Simulate(target, args[1] or "")
	end,
})

function AdminService.Init()
	Net.Function("Admin", { Rate = 2, Burst = 6 }, function(player: Player, name: any, args: any)
		return AdminService.Run(player, name, args)
	end)
end

function AdminService.Start()
	-- (le propriétaire d'un groupe se demande à Roblox une fois, avant l'arrivée des joueurs si possible)
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId ~= 0 then
		groupOwnerId()
	end
end

function AdminService.OnPlayerReady(player: Player)
	-- (IsAdmin peut attendre une réponse web : jamais dans OnPlayerReady lui-même)
	task.spawn(function()
		local admin = AdminService.IsAdmin(player)
		if player.Parent == Players then
			player:SetAttribute("Admin", admin)
		end
	end)
end

return AdminService
