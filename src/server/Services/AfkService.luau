--!strict
-- AFK sur le treadmill. Roblox expulse un joueur inactif depuis 20 minutes : le client (AfkController) demande ici une
-- reconnexion quand le joueur est inactif depuis Config.Speed.Treadmill.Afk.RejoinAfter secondes sur son treadmill.
-- Le serveur vérifie qu'il est bien sur son tapis, sauvegarde, puis TeleportService le renvoie dans ce même serveur
-- (sinon dans un autre) avec la donnée de téléportation { AfkTreadmill = true }. À l'arrivée, il est reposé sur le tapis
-- de son parc et reçoit l'attribut Config.Speed.Treadmill.Afk.Attribute (« AfkReturn ») : il continue à gagner de la
-- vitesse, de l'argent et du temps de jeu pour les cadeaux, des heures durant.
-- TeleportService ne marche pas dans Studio : le joueur y reçoit un message, rien d'autre.
--   AfkService.Rejoin(player)            -> (ok, texte)   (remote AfkRejoin)
--   AfkService.Teleport(players, options) envoi réel (remplacé par les tests et FossilDebug)
--   AfkService.BeltCFrame(player)         -> CFrame?      où poser le personnage sur le tapis de son parc
--   AfkService.ClearCooldown(player)      oublie la dernière demande (FossilDebug)
-- Signal : AfkRejoin(player)   reconnexion lancée

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Net = require(script.Parent.Parent.Lib.Net)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillService = require(script.Parent.TreadmillService)

local AfkService = {}

local AFK = SpeedConfig.Treadmill.Afk
local PLACE_TIMEOUT = 20 -- secondes pour attendre le personnage et le parc à l'arrivée
local PLACE_DELAY = 0.5 -- (après le placement de PlotService sur le point Spawn du parc)

local lastRequest: { [Player]: number } = {}
local teleporting: { [Player]: boolean } = {}
local retried: { [Player]: boolean } = {}

function AfkService.Teleport(players: { Player }, options: TeleportOptions)
	TeleportService:TeleportAsync(game.PlaceId, players, options)
end

local function teleportOptions(sameServer: boolean): TeleportOptions
	local options = Instance.new("TeleportOptions")
	if sameServer and game.JobId ~= "" then
		options.ServerInstanceId = game.JobId
	end
	options:SetTeleportData({ AfkTreadmill = true })
	return options
end

local function send(player: Player, sameServer: boolean): (boolean, any)
	return pcall(function()
		AfkService.Teleport({ player }, teleportOptions(sameServer))
	end)
end

function AfkService.IsTeleporting(player: Player): boolean
	return teleporting[player] == true
end

function AfkService.Rejoin(player: Player): (boolean, string)
	if not AFK.Rejoin then
		return false, "AFK reconnect is off"
	end
	if not DataService.Get(player) then
		return false, "Please wait..."
	end
	if teleporting[player] then
		return false, "Already reconnecting"
	end
	local clock = os.clock()
	if lastRequest[player] and clock - lastRequest[player] < AFK.RejoinCooldown then
		return false, "Slow down!"
	end
	lastRequest[player] = clock
	if not TreadmillService.IsOnTreadmill(player) then
		return false, "Not on your treadmill"
	end
	if RunService:IsStudio() then
		Notify.Send(player, "AFK reconnect only works in the live game, not in Studio.", "info")
		return false, "Studio"
	end
	teleporting[player] = true
	retried[player] = nil
	Notify.Send(player, "Reconnecting you to keep you AFK on your treadmill...", "info")
	-- (sauvegarde d'abord : la reconnexion relit la sauvegarde)
	DataService.Save(player)
	if player.Parent ~= Players then
		teleporting[player] = nil
		return false, "Left"
	end
	local ok, err = send(player, true)
	if not ok then
		retried[player] = true
		ok, err = send(player, false)
	end
	if not ok then
		teleporting[player] = nil
		warn(string.format("[AfkService] reconnexion de %s impossible : %s", player.Name, tostring(err)))
		Notify.Send(player, "Could not reconnect you. Move a little to stay in the game!", "error")
		return false, "Could not reconnect"
	end
	Signals.Fire("AfkRejoin", player)
	return true, ""
end

function AfkService.ClearCooldown(player: Player)
	lastRequest[player] = nil
end

-- Debout au milieu du tapis du parc du joueur (nil sans parc ou sans tapis)
function AfkService.BeltCFrame(player: Player): CFrame?
	local plot = PlotService.Get(player)
	local belt = plot and plot.Treadmill
	if not belt or belt.Parent == nil then
		return nil
	end
	return belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, 0)
end

-- À l'arrivée d'une reconnexion AFK : sur le tapis de son parc dès que le personnage et le parc sont là
local function placeOnTreadmill(player: Player)
	local deadline = os.clock() + PLACE_TIMEOUT
	while player.Parent == Players and os.clock() < deadline do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and AfkService.BeltCFrame(player) then
			task.wait(PLACE_DELAY)
			local target = AfkService.BeltCFrame(player)
			if player.Character == character and character.Parent ~= nil and target then
				character:PivotTo(target)
				Notify.Send(player, "Welcome back! You are still AFK on your treadmill.", "success")
				return
			end
		end
		task.wait(0.25)
	end
end

local function cameFromAfk(player: Player): boolean
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(join) ~= "table" then
		return false
	end
	local data = (join :: any).TeleportData
	return type(data) == "table" and data.AfkTreadmill == true
end

-- ===== cycle de vie =====

function AfkService.Init()
	Net.Event("AfkRejoin", { Rate = 0.2, Burst = 1 }, function(player: Player)
		AfkService.Rejoin(player)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result: Enum.TeleportResult, message: string)
		if not teleporting[player] then
			return
		end
		if not retried[player] and player.Parent == Players then
			-- (ce serveur a refusé, plein par exemple : un autre serveur)
			retried[player] = true
			local ok = send(player, false)
			if ok then
				return
			end
		end
		teleporting[player] = nil
		warn(string.format("[AfkService] reconnexion de %s ratée : %s", player.Name, tostring(message)))
		if player.Parent == Players then
			Notify.Send(player, "Could not reconnect you. Move a little to stay in the game!", "error")
		end
	end)
end

function AfkService.OnPlayerReady(player: Player)
	if cameFromAfk(player) then
		player:SetAttribute(AFK.Attribute, true)
		task.spawn(placeOnTreadmill, player)
	end
end

function AfkService.OnPlayerRemoving(player: Player)
	lastRequest[player] = nil
	teleporting[player] = nil
	retried[player] = nil
end

return AfkService
