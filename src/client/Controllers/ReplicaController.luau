--!strict
-- État du joueur reçu du serveur (ReplicaService, brief 1) : argent, vitesse, dinos, cuves...
--   ReplicaController.Get("Money")
--   ReplicaController.Observe("Money", function(money) label.Text = Format.Money(money or 0) end)
-- Observe appelle la fonction tout de suite si l'état est déjà là (sinon dès son arrivée), puis à chaque changement ;
-- elle renvoie de quoi se débrancher. Lecture seule : pour changer quelque chose, demander au serveur par un remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)

type Batch = { Seq: number, Changes: { [string]: any }, Removed: { string } }

local ReplicaController = {}
ReplicaController.Priority = -100

-- Changement d'une clé, après l'arrivée de l'état complet : (clé, valeur, ancienne valeur)
ReplicaController.Changed = Signal.new()
-- L'état complet vient d'arriver
ReplicaController.ReadySignal = Signal.new()

local state: { [string]: any } = {}
local ready = false
local lastSeq = 0
local buffered: { Batch } = {}

local function apply(changes: { [string]: any }, removed: { string })
	for key, value in changes do
		if type(key) == "string" then
			local old = state[key]
			state[key] = value
			ReplicaController.Changed:Fire(key, value, old)
		end
	end
	for _, key in removed do
		if type(key) == "string" and state[key] ~= nil then
			local old = state[key]
			state[key] = nil
			ReplicaController.Changed:Fire(key, nil, old)
		end
	end
end

local function receive(seq: any, changes: any, removed: any)
	if type(seq) ~= "number" or type(changes) ~= "table" or type(removed) ~= "table" then
		return
	end
	if not ready then
		table.insert(buffered, { Seq = seq, Changes = changes, Removed = removed })
		return
	end
	if seq <= lastSeq then
		return
	end
	lastSeq = seq
	apply(changes, removed)
end

function ReplicaController.Get(key: string): any
	return state[key]
end

function ReplicaController.IsReady(): boolean
	return ready
end

-- Attend l'état complet (au plus `timeout` secondes) ; renvoie true s'il est là
function ReplicaController.WaitReady(timeout: number?): boolean
	local deadline = os.clock() + (timeout or 60)
	while not ready and os.clock() < deadline do
		task.wait(0.1)
	end
	return ready
end

function ReplicaController.Observe(key: string, callback: (value: any) -> ()): () -> ()
	local connection = ReplicaController.Changed:Connect(function(changedKey: string, value: any)
		if changedKey == key then
			callback(value)
		end
	end)
	local readyConnection = nil
	if ready then
		task.spawn(callback, state[key])
	else
		readyConnection = ReplicaController.ReadySignal:Once(function()
			callback(state[key])
		end)
	end
	return function()
		connection:Disconnect()
		if readyConnection then
			readyConnection:Disconnect()
		end
	end
end

-- (tests) remet à zéro
function ReplicaController._reset()
	state = {}
	ready = false
	lastSeq = 0
	buffered = {}
end

local function fetchSnapshot(): boolean
	local ok, snapshot, seq = pcall(function()
		return Remotes.Function("GetReplica"):InvokeServer()
	end)
	if not ok or type(snapshot) ~= "table" or type(seq) ~= "number" then
		return false
	end
	state = snapshot
	lastSeq = seq
	ready = true
	-- les envois reçus avant l'état complet : seuls les plus récents que lui comptent
	local pending = buffered
	buffered = {}
	table.sort(pending, function(a, b)
		return a.Seq < b.Seq
	end)
	for _, batch in pending do
		if batch.Seq > lastSeq then
			lastSeq = batch.Seq
			apply(batch.Changes, batch.Removed)
		end
	end
	ReplicaController.ReadySignal:Fire()
	return true
end

function ReplicaController.Init()
	Remotes.Event("Replica").OnClientEvent:Connect(receive)
end

function ReplicaController.Start()
	local player = Players.LocalPlayer
	-- le serveur pose l'attribut Ready quand toutes les données du joueur sont prêtes
	while player:GetAttribute("Ready") ~= true do
		player:GetAttributeChangedSignal("Ready"):Wait()
	end
	for _ = 1, 20 do
		if fetchSnapshot() then
			return
		end
		task.wait(1)
	end
	warn("[ReplicaController] état du joueur jamais reçu")
end

return ReplicaController
