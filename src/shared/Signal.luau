--!strict
-- Signal simple pour les modules du jeu (serveur ou client) : Connect, Once, Wait, Fire, DisconnectAll.
-- Chaque fonction branchée tourne dans son propre fil (task.spawn), comme les événements de Roblox : une erreur
-- dans l'une n'empêche pas les autres.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Wait: (self: Signal) -> ...any,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

type Handler = { Fn: (...any) -> (), Connection: Connection }

local Signal = {}

function Signal.new(): Signal
	local handlers: { Handler } = {}
	local waiting: { thread } = {}
	local self = {} :: Signal

	local function remove(handler: Handler)
		local index = table.find(handlers, handler)
		if index then
			table.remove(handlers, index)
		end
	end

	function self.Connect(_: Signal, fn: (...any) -> ()): Connection
		local connection = { Connected = true } :: Connection
		local handler: Handler = { Fn = fn, Connection = connection }
		function connection.Disconnect(c: Connection)
			c.Connected = false
			remove(handler)
		end
		table.insert(handlers, handler)
		return connection
	end

	function self.Once(signal: Signal, fn: (...any) -> ()): Connection
		local connection: Connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end

	function self.Wait(_: Signal): ...any
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end

	function self.Fire(_: Signal, ...: any)
		for _, handler in table.clone(handlers) do
			if handler.Connection.Connected then
				task.spawn(handler.Fn, ...)
			end
		end
		local threads = waiting
		waiting = {}
		for _, thread in threads do
			task.spawn(thread, ...)
		end
	end

	function self.DisconnectAll(_: Signal)
		for _, handler in handlers do
			handler.Connection.Connected = false
		end
		table.clear(handlers)
	end

	return self
end

return Signal
