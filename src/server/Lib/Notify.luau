--!strict
-- Messages courts à l'écran d'un joueur (ou de tous) : Notify.Send(player, "Not enough money!", "error").
-- Genres : "info" (par défaut), "success", "error", "money". L'affichage est fait par NotifyController côté client.
-- Textes en anglais (jeu).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Kind = "info" | "success" | "error" | "money"

local Notify = {}

local remote = Remotes.Event("Notify")

function Notify.Send(player: Player, text: string, kind: Kind?)
	remote:FireClient(player, text, kind or "info")
end

function Notify.All(text: string, kind: Kind?)
	remote:FireAllClients(text, kind or "info")
end

return Notify
