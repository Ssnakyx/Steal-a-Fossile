--!strict
-- Handlers de remotes côté serveur, avec limite de fréquence et protection contre les erreurs :
--   Net.Function("BuyTrail", { Rate = 2, Burst = 4 }, function(player, trailId) ... return true, "OK" end)
--   Net.Event("Bonk", { Rate = 1, Burst = 2 }, function(player, targetId) ... end)
-- Rate = appels permis par seconde en moyenne, Burst = rafale maximale. Un appel en trop est ignoré (une Function
-- renvoie false, "Slow down!"). Une erreur dans un handler est notée (warn « [Net] ») et ne remonte jamais au client
-- (une Function renvoie false, "Error"). Les arguments restent à vérifier dans le handler (Guard) : ils viennent du client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.RateLimit)

export type Limit = { Rate: number, Burst: number? }

local Net = {}

-- Erreurs attrapées depuis le démarrage (les tests vérifient qu'il n'y en a pas)
Net.Errors = {} :: { string }
-- Remotes qui ont un handler serveur (les tests vérifient que chaque remote client -> serveur en a un)
Net.Handled = {} :: { [string]: boolean }

local function report(name: string, player: Player, err: any)
	local text = string.format("[Net] %s (%s) : %s", name, player.Name, tostring(err))
	if #Net.Errors < 200 then
		table.insert(Net.Errors, text)
	end
	warn(text)
end

local function checkLimit(name: string, limit: Limit)
	if type(limit) ~= "table" or type(limit.Rate) ~= "number" or limit.Rate <= 0 then
		error(string.format("Net : limite invalide pour %s (attendu { Rate = n, Burst = n })", name), 3)
	end
end

function Net.Function(name: string, limit: Limit, handler: (Player, ...any) -> ...any)
	checkLimit(name, limit)
	local remote = Remotes.Function(name)
	if Net.Handled[name] then
		error(string.format("Net : le remote %s a déjà un handler", name), 2)
	end
	Net.Handled[name] = true
	remote.OnServerInvoke = function(player: Player, ...: any)
		if not RateLimit.Allow(player, name, limit.Rate, limit.Burst) then
			return false, "Slow down!"
		end
		local results = table.pack(xpcall(handler, debug.traceback, player, ...))
		if not results[1] then
			report(name, player, results[2])
			return false, "Error"
		end
		return table.unpack(results, 2, results.n)
	end
end

function Net.Event(name: string, limit: Limit, handler: (Player, ...any) -> ())
	checkLimit(name, limit)
	local remote = Remotes.Event(name)
	if Net.Handled[name] then
		error(string.format("Net : le remote %s a déjà un handler", name), 2)
	end
	Net.Handled[name] = true
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not RateLimit.Allow(player, name, limit.Rate, limit.Burst) then
			return
		end
		local ok, err = xpcall(handler :: any, debug.traceback, player, ...)
		if not ok then
			report(name, player, err)
		end
	end)
end

function Net.Unreliable(name: string, limit: Limit, handler: (Player, ...any) -> ())
	checkLimit(name, limit)
	local remote = Remotes.Unreliable(name)
	if Net.Handled[name] then
		error(string.format("Net : le remote %s a déjà un handler", name), 2)
	end
	Net.Handled[name] = true
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not RateLimit.Allow(player, name, limit.Rate, limit.Burst) then
			return
		end
		local ok, err = xpcall(handler :: any, debug.traceback, player, ...)
		if not ok then
			report(name, player, err)
		end
	end)
end

return Net
