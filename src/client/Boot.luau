--!strict
-- Démarrage du client (brief 1) : charge chaque module de src/client/Controllers/.
--
-- Un controller est un module qui renvoie une table, avec des fonctions facultatives :
--   Priority = 0     ordre de chargement (plus petit d'abord, puis ordre alphabétique)
--   Init()           appelée une fois, dans l'ordre, avant tout Start : brancher les remotes, créer l'interface
--   Start()          appelée ensuite dans son propre fil : boucles, attente de l'état du joueur
-- Une erreur dans un controller est notée (warn « [Boot] ») sans empêcher les autres de démarrer.

type Controller = { [string]: any }
type Entry = { Name: string, Module: Controller, Priority: number }

local Boot = {}

-- Controllers chargés, par nom (tests)
Boot.Controllers = {} :: { [string]: Controller }
-- Ordre de chargement
Boot.Order = {} :: { string }
-- Erreurs attrapées depuis le démarrage (les tests vérifient qu'il n'y en a pas)
Boot.Errors = {} :: { string }

local started = false

local function report(where: string, err: any)
	local text = string.format("[Boot] %s : %s", where, tostring(err))
	if #Boot.Errors < 200 then
		table.insert(Boot.Errors, text)
	end
	warn(text)
end

local function call(entry: Entry, hook: string)
	local fn = entry.Module[hook]
	if type(fn) ~= "function" then
		return
	end
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		report(entry.Name .. "." .. hook, err)
	end
end

function Boot.Start(folder: Instance?)
	if started then
		return
	end
	started = true
	local entries: { Entry } = {}
	for _, child in (folder or script.Parent:WaitForChild("Controllers")):GetChildren() do
		if child:IsA("ModuleScript") then
			if not string.match(child.Name, "Controller$") then
				report(child.Name, "un module de Controllers/ doit s'appeler <Nom>Controller (ignoré)")
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
		Boot.Controllers[entry.Name] = entry.Module
		table.insert(Boot.Order, entry.Name)
	end
	for _, entry in entries do
		call(entry, "Init")
	end
	for _, entry in entries do
		if type(entry.Module.Start) == "function" then
			task.spawn(call, entry, "Start")
		end
	end
end

return Boot
