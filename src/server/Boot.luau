--!strict
-- Démarrage du serveur (brief 1) : charge chaque module de src/server/Services/ et gère la vie des joueurs.
--
-- Un service est un module qui renvoie une table, avec des fonctions facultatives :
--   Priority = 0                      ordre de chargement (plus petit d'abord, puis ordre alphabétique)
--   Init()                            appelée une fois, dans l'ordre, avant tout Start : poser les handlers de remotes
--   Start()                           appelée ensuite dans son propre fil : boucles, minuteurs
--   OnPlayerReady(player, data)       joueur chargé (data = sa sauvegarde), dans l'ordre des services. Ne doit pas attendre.
--   OnPlayerRemoving(player, data)    joueur qui part, dans l'ordre inverse, juste avant la dernière sauvegarde : c'est ici
--                                     qu'on vide les tables par joueur. Appelé pour chaque service dont OnPlayerReady
--                                     a été appelé, même si le joueur part avant d'être prêt ou si sa sauvegarde est perdue.
-- Une erreur dans un service est notée (warn « [Boot] ») sans empêcher les autres de démarrer.
-- Quand tous les OnPlayerReady sont passés : attribut « Ready » = true sur le joueur et signal PlayerReady.

local Players = game:GetService("Players")

local Signals = require(script.Parent.Lib.Signals)

type Service = { [string]: any }
type Entry = { Name: string, Module: Service, Priority: number }

local Boot = {}

-- Services chargés, par nom (tests, debug)
Boot.Services = {} :: { [string]: Service }
-- Ordre de chargement
Boot.Order = {} :: { string }
-- Erreurs attrapées depuis le démarrage (les tests vérifient qu'il n'y en a pas)
Boot.Errors = {} :: { string }

local entries: { Entry } = {}
local ready: { [Player]: boolean } = {}
local removed: { [Player]: boolean } = {}
-- (joueur dont les OnPlayerReady tournent, nombre de OnPlayerReady terminés, données passées aux hooks)
local running: { [Player]: boolean } = {}
local hooksDone: { [Player]: number } = {}
local hookData: { [Player]: { [string]: any } } = {}
local started = false

local function report(where: string, err: any)
	local text = string.format("[Boot] %s : %s", where, tostring(err))
	if #Boot.Errors < 200 then
		table.insert(Boot.Errors, text)
	end
	warn(text)
end

local function call(entry: Entry, hook: string, ...: any)
	local fn = entry.Module[hook]
	if type(fn) ~= "function" then
		return
	end
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		report(entry.Name .. "." .. hook, err)
	end
end

local function loadServices(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			if not string.match(child.Name, "Service$") then
				report(child.Name, "un module de Services/ doit s'appeler <Nom>Service (ignoré)")
				continue
			end
			local ok, result = xpcall(require :: any, debug.traceback, child)
			if not ok then
				report("require " .. child.Name, result)
			elseif type(result) ~= "table" then
				report(child.Name, "le module doit renvoyer une table")
			else
				local priority = result.Priority
				table.insert(entries, {
					Name = child.Name,
					Module = result,
					Priority = if type(priority) == "number" then priority else 0,
				})
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority < b.Priority
		end
		return a.Name < b.Name
	end)
	for _, entry in entries do
		Boot.Services[entry.Name] = entry.Module
		table.insert(Boot.Order, entry.Name)
	end
end

local function getDataService(): Service
	local dataService = Boot.Services.DataService
	if not dataService then
		error("DataService manquant dans src/server/Services/")
	end
	return dataService
end

local function playerAdded(player: Player)
	local dataService = getDataService()
	local ok, data = xpcall(dataService.Load, debug.traceback, player)
	if not ok then
		report("DataService.Load " .. player.Name, data)
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin in a moment.")
		end
		return
	end
	-- (pas de données : chargement raté, joueur expulsé, ou parti pendant le chargement)
	if data == nil or player.Parent ~= Players or removed[player] then
		return
	end
	hookData[player] = data
	running[player] = true
	for index, entry in entries do
		-- (un joueur parti pendant un OnPlayerReady qui attend : les services suivants ne le voient pas)
		if removed[player] then
			break
		end
		call(entry, "OnPlayerReady", player, data)
		hooksDone[player] = index
	end
	running[player] = nil
	if player.Parent ~= Players or removed[player] then
		return
	end
	ready[player] = true
	player:SetAttribute("Ready", true)
	Signals.Fire("PlayerReady", player, data)
end

local function playerRemoving(player: Player)
	if removed[player] then
		return
	end
	removed[player] = true
	ready[player] = nil
	local dataService = getDataService()
	-- un OnPlayerReady en train d'attendre (contre la règle) : on le laisse finir, puis on défait ce qui a été fait
	local deadline = os.clock() + 10
	while running[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	-- (les données gardées par Boot : même si DataService a lâché la sauvegarde, chaque service fait son ménage)
	local data = hookData[player]
	local done = hooksDone[player] or 0
	hookData[player] = nil
	hooksDone[player] = nil
	if data then
		for index = done, 1, -1 do
			call(entries[index], "OnPlayerRemoving", player, data)
		end
	end
	local ok, err = xpcall(dataService.Release, debug.traceback, player)
	if not ok then
		report("DataService.Release " .. player.Name, err)
	end
	-- (un joueur qui revient sur ce serveur est un nouvel objet Player : la table se vide quand il part)
	task.delay(60, function()
		removed[player] = nil
	end)
end

-- Le joueur est-il chargé et prêt (après tous les OnPlayerReady) ?
function Boot.IsReady(player: Player): boolean
	return ready[player] == true
end

function Boot.Start(folder: Instance?)
	if started then
		return
	end
	started = true
	loadServices(folder or script.Parent:WaitForChild("Services"))
	for _, entry in entries do
		call(entry, "Init")
	end
	for _, entry in entries do
		if type(entry.Module.Start) == "function" then
			task.spawn(call, entry, "Start")
		end
	end
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end
	-- Arrêt du serveur : chaque joueur part proprement (hooks puis dernière sauvegarde), puis on attend les sauvegardes
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(playerRemoving, player)
		end
		local dataService = getDataService()
		local ok, err = xpcall(dataService.Close, debug.traceback, 25)
		if not ok then
			report("DataService.Close", err)
		end
	end)
end

return Boot
