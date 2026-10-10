--!strict
-- Affiche les messages courts envoyés par le serveur (Notify.Send, brief 1) en haut de l'écran.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local KINDS = { info = true, success = true, error = true, money = true }
local MAX_LENGTH = 200

local NotifyController = {}

function NotifyController.Show(text: string, kind: string?)
	UIKit.toast(text, if kind and KINDS[kind] then kind else "info")
end

function NotifyController.Init()
	Remotes.Event("Notify").OnClientEvent:Connect(function(text: any, kind: any)
		if type(text) ~= "string" or text == "" then
			return
		end
		NotifyController.Show(string.sub(text, 1, MAX_LENGTH), if type(kind) == "string" then kind else nil)
	end)
end

return NotifyController
