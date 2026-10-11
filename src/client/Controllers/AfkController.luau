--!strict
-- AFK sur le treadmill, côté client :
--   * carte en bas de l'écran tant que le joueur est sur son treadmill (attribut OnTreadmill posé par TreadmillService) :
--     vitesse gagnée par seconde, vitesse gagnée depuis qu'il est monté, et le rappel qu'il peut rester AFK.
--   * Roblox expulse un joueur inactif depuis 20 min : après Config.Speed.Treadmill.Afk.RejoinAfter secondes
--     d'inactivité sur le treadmill (Players.LocalPlayer.Idled), demande au serveur de le reconnecter (AfkRejoin) ; il
--     revient dans le même serveur, sur son tapis (AfkService).
-- Le serveur vérifie tout (joueur sur son tapis, fréquence) : le client ne fait que demander.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.Speed)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local ReplicaController = require(script.Parent.ReplicaController)

local AfkController = {}

local AFK = SpeedConfig.Treadmill.Afk
local RETRY_AFTER = 90 -- secondes avant de pouvoir redemander une reconnexion (si la première a échoué)

type Card = { Frame: Frame, Rate: TextLabel, Gained: TextLabel, Hint: TextLabel }

local card: Card? = nil
local onBelt = false
local gained = 0
local requestedAt: number? = nil

local function onTreadmill(): boolean
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute("OnTreadmill") == true
end

-- Vitesse gagnée depuis la montée sur le tapis
function AfkController.Gained(): number
	return gained
end

local function refresh()
	local current = card
	if not current then
		return
	end
	current.Frame.Visible = onBelt
	if not onBelt then
		return
	end
	local rate = tonumber(ReplicaController.Get("TreadmillRate")) or 0
	local level = tonumber(ReplicaController.Get("TreadmillLevel")) or 0
	current.Rate.Text = "+" .. Format.Number(rate) .. " Speed/s"
	current.Gained.Text = "+" .. Format.Number(gained) .. " since you got on"
	if requestedAt then
		current.Hint.Text = "Reconnecting to keep you AFK..."
	elseif level <= 0 then
		current.Hint.Text = "You can stay AFK here! Upgrade your Treadmill to go faster."
	else
		current.Hint.Text = "You can stay AFK here: you keep gaining speed."
	end
end

-- Inactif depuis `seconds` secondes (Players.LocalPlayer.Idled) : reconnexion si le joueur est sur son tapis
function AfkController.OnIdle(seconds: number)
	if not AFK.Rejoin or type(seconds) ~= "number" or seconds < AFK.RejoinAfter or not onTreadmill() then
		return
	end
	local now = os.clock()
	if requestedAt and now - requestedAt < RETRY_AFTER then
		return
	end
	requestedAt = now
	Remotes.Event("AfkRejoin"):FireServer()
	refresh()
end

local function build()
	local _, root = UIKit.Root("Afk", 4)
	local frame = UIKit.card({
		Name = "AfkCard",
		Color = UIKit.Colors.Cyan,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(460, 92),
		Visible = false,
		Parent = root,
	})
	UIKit.label({
		Name = "Title",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(200, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "TREADMILL",
		TextColor3 = UIKit.Colors.Yellow,
		ZIndex = frame.ZIndex + 2,
		Parent = frame,
	})
	local rate = UIKit.label({
		Name = "Rate",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.fromOffset(230, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		TextColor3 = UIKit.Colors.GreenText,
		ZIndex = frame.ZIndex + 2,
		Parent = frame,
	})
	local gainedLabel = UIKit.label({
		Name = "Gained",
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = frame.ZIndex + 2,
		Parent = frame,
	})
	local hint = UIKit.label({
		Name = "Hint",
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Body = true,
		MaxTextSize = 18,
		Text = "",
		ZIndex = frame.ZIndex + 2,
		Parent = frame,
	})
	card = { Frame = frame, Rate = rate, Gained = gainedLabel, Hint = hint }
end

function AfkController.Init()
	build()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local function changed()
		local now = onTreadmill()
		if now and not onBelt then
			gained = 0
		end
		onBelt = now
		refresh()
	end
	player:GetAttributeChangedSignal("OnTreadmill"):Connect(changed)
	changed()
	ReplicaController.Changed:Connect(function(key: string, value: any, old: any)
		if key == "Speed" then
			if onBelt and type(value) == "number" and type(old) == "number" and value > old then
				gained += value - old
			end
			refresh()
		elseif key == "TreadmillRate" or key == "TreadmillLevel" then
			refresh()
		end
	end)
	player.Idled:Connect(AfkController.OnIdle)
end

return AfkController
