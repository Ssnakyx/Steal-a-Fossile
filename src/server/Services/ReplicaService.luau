--!strict
-- État du joueur envoyé à son propre client (argent, vitesse, dinos, cuves...) : le serveur pose une valeur par clé,
-- le client la lit avec ReplicaController.Get / Observe.
--   ReplicaService.Set(player, "Money", data.Money)
-- Les changements d'une même image partent ensemble en un seul envoi. Une table modifiée sur place n'est pas vue :
-- rappeler Set après l'avoir changée. Valeurs permises : celles qui passent par un remote (nombres, textes, booléens,
-- tables à clés texte ou listes, Vector3...). Pour un état visible par tous, utiliser des attributs ou des instances.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Net = require(script.Parent.Parent.Lib.Net)

type Batch = { Changes: { [string]: any }, Removed: { [string]: boolean } }

local ReplicaService = {}
ReplicaService.Priority = -90

local states: { [Player]: { [string]: any } } = {}
local pending: { [Player]: Batch } = {}
local sequence: { [Player]: number } = {}

local function flush()
	if next(pending) == nil then
		return
	end
	local event = Remotes.Event("Replica")
	local batches = pending
	pending = {}
	for player, batch in batches do
		if player.Parent == Players then
			local seq = (sequence[player] or 0) + 1
			sequence[player] = seq
			local removed = {}
			for key in batch.Removed do
				table.insert(removed, key)
			end
			event:FireClient(player, seq, batch.Changes, removed)
		end
	end
end

-- Pose une valeur (nil l'efface) ; elle part au client à la fin de l'image
function ReplicaService.Set(player: Player, key: string, value: any)
	if player.Parent ~= Players then
		return
	end
	local state = states[player]
	if not state then
		state = {}
		states[player] = state
	end
	state[key] = value
	local batch = pending[player]
	if not batch then
		batch = { Changes = {}, Removed = {} }
		pending[player] = batch
	end
	if value == nil then
		batch.Changes[key] = nil
		batch.Removed[key] = true
	else
		batch.Changes[key] = value
		batch.Removed[key] = nil
	end
end

function ReplicaService.Get(player: Player, key: string): any
	local state = states[player]
	return if state then state[key] else nil
end

-- État complet et numéro du dernier envoi (ce que reçoit le client au démarrage)
function ReplicaService.Snapshot(player: Player): ({ [string]: any }, number)
	return table.clone(states[player] or {}), sequence[player] or 0
end

-- Envoie tout de suite les changements en attente (tests)
ReplicaService.Flush = flush

function ReplicaService.Init()
	Net.Function("GetReplica", { Rate = 1, Burst = 5 }, function(player: Player)
		return ReplicaService.Snapshot(player)
	end)
	RunService.Heartbeat:Connect(flush)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		pending[player] = nil
		sequence[player] = nil
	end)
end

return ReplicaService
