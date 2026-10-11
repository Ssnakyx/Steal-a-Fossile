--!strict
-- Commande de debug FossilDebug (reprise du DebugService de Steal a Snack, brief 1). Studio seulement : une
-- BindableFunction dans ServerScriptService, à lancer pendant un Play depuis la barre de commande en vue serveur :
--   game.ServerScriptService.FossilDebug:Invoke("all")      tous les tests
--   game.ServerScriptService.FossilDebug:Invoke("money")    un test
--   game.ServerScriptService.FossilDebug:Invoke("help")     la liste
-- Le rapport s'affiche dans l'Output (et revient comme résultat) : une ligne OK / FAIL par vérification, puis
-- « @@ money: 6 OK / 0 FAIL ».
--
-- Chaque domaine ajoute ses tests dans src/server/DebugTests/<Domaine>.luau (un test par système, chargés tout seuls) :
--   return {
--       carry = function(t)
--           local player = t:Player() ; if not t:Check(player, "player loaded") then return end
--           t:Equal(CarryService.Get(player), nil, "nothing carried at start")
--       end,
--   }
-- Un test remet le jeu dans l'état où il l'a trouvé (argent rendu, objets retirés...).
-- Des commandes utilitaires (qui ne sont pas des tests) s'ajoutent avec DebugService.RegisterCommand.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(script.Parent.DataService)

type TesterData = { Name: string, Ok: number, Fail: number, Lines: { string }, Args: { any } }

local Tester = {}
Tester.__index = Tester

export type Tester = typeof(setmetatable({} :: TesterData, Tester))
export type Test = (t: Tester) -> ()
export type Command = (...any) -> string

local function describe(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

-- Vérifie une condition ; renvoie la condition (pour s'arrêter tôt : if not t:Check(...) then return end)
function Tester.Check(self: Tester, condition: any, label: string, detail: any?): boolean
	if condition then
		self.Ok += 1
		table.insert(self.Lines, "  OK   " .. label)
		return true
	end
	self.Fail += 1
	table.insert(self.Lines, "  FAIL " .. label .. if detail ~= nil then " (" .. tostring(detail) .. ")" else "")
	return false
end

function Tester.Equal(self: Tester, actual: any, expected: any, label: string): boolean
	return self:Check(actual == expected, label, "got " .. describe(actual) .. ", expected " .. describe(expected))
end

function Tester.Note(self: Tester, text: string)
	table.insert(self.Lines, "  ..   " .. text)
end

-- Premier joueur chargé (nil s'il n'y en a pas)
function Tester.Player(_self: Tester): Player?
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) then
			return player
		end
	end
	return nil
end

-- Tous les joueurs chargés
function Tester.Players(_self: Tester): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) then
			table.insert(list, player)
		end
	end
	return list
end

local DebugService = {}

local tests: { [string]: Test } = {}
local testDomains: { [string]: string } = {}
local commands: { [string]: Command } = {}

function DebugService.RegisterTest(name: string, test: Test, domain: string?)
	if type(name) ~= "string" or not string.match(name, "^%l[%w_]*$") then
		error("DebugService.RegisterTest : nom invalide (commence par une minuscule) " .. tostring(name), 2)
	end
	if tests[name] or commands[name] then
		error("DebugService : le nom " .. name .. " est déjà pris", 2)
	end
	if type(test) ~= "function" then
		error("DebugService.RegisterTest(" .. name .. ") : il faut une fonction", 2)
	end
	tests[name] = test
	testDomains[name] = domain or "?"
end

function DebugService.RegisterCommand(name: string, command: Command)
	if type(name) ~= "string" or not string.match(name, "^%l[%w_]*$") then
		error("DebugService.RegisterCommand : nom invalide " .. tostring(name), 2)
	end
	if tests[name] or commands[name] then
		error("DebugService : le nom " .. name .. " est déjà pris", 2)
	end
	commands[name] = command
end

local function sortedTests(): { string }
	local names = {}
	for name in tests do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- Lance un test ; renvoie (ok, fail, lignes du rapport)
function DebugService.RunTest(name: string, args: { any }?): (number, number, { string })
	local test = tests[name]
	local tester = setmetatable({ Name = name, Ok = 0, Fail = 0, Lines = {}, Args = args or {} } :: TesterData, Tester)
	if not test then
		tester:Check(false, "test " .. name .. " exists")
	else
		local ok, err = xpcall(test :: any, debug.traceback, tester)
		if not ok then
			tester:Check(false, "no error", err)
		end
	end
	table.insert(tester.Lines, string.format("@@ %s: %d OK / %d FAIL", name, tester.Ok, tester.Fail))
	return tester.Ok, tester.Fail, tester.Lines
end

-- Exécute une commande FossilDebug et renvoie le rapport (texte)
function DebugService.Run(command: string?, ...: any): string
	local name = string.lower(tostring(command or "help"))
	local lines: { string } = {}
	if name == "help" then
		table.insert(lines, "FossilDebug commands: help, all, " .. table.concat(sortedTests(), ", "))
		local extra = {}
		for commandName in commands do
			table.insert(extra, commandName)
		end
		table.sort(extra)
		if #extra > 0 then
			table.insert(lines, "Tools: " .. table.concat(extra, ", "))
		end
	elseif name == "all" then
		local totalOk, totalFail = 0, 0
		for _, testName in sortedTests() do
			local ok, fail, testLines = DebugService.RunTest(testName, { ... })
			totalOk += ok
			totalFail += fail
			table.move(testLines, 1, #testLines, #lines + 1, lines)
		end
		table.insert(lines, string.format("@@ all: %d OK / %d FAIL", totalOk, totalFail))
	elseif tests[name] then
		local _, _, testLines = DebugService.RunTest(name, { ... })
		lines = testLines
	elseif commands[name] then
		local ok, result = xpcall(commands[name], debug.traceback, ...)
		table.insert(lines, if ok then tostring(result) else "error: " .. tostring(result))
	else
		table.insert(lines, "Unknown command " .. name .. " (try: help)")
	end
	local report = table.concat(lines, "\n")
	print("[FossilDebug]\n" .. report)
	return report
end

-- Tests et noms connus (tests hors Studio)
function DebugService.Tests(): { string }
	return sortedTests()
end

function DebugService.Init()
	if not RunService:IsStudio() then
		return -- (jamais de commande de debug dans le jeu publié)
	end
	local folder = script.Parent.Parent:FindFirstChild("DebugTests")
	if folder then
		local modules = folder:GetChildren()
		table.sort(modules, function(a, b)
			return a.Name < b.Name
		end)
		for _, module in modules do
			if module:IsA("ModuleScript") then
				local list = (require :: any)(module)
				if type(list) ~= "table" then
					error("DebugTests/" .. module.Name .. " doit renvoyer une table { nom = function(t) ... end }")
				end
				for testName, test in list do
					DebugService.RegisterTest(testName, test, module.Name)
				end
			end
		end
	end
	local old = ServerScriptService:FindFirstChild("FossilDebug")
	if old then
		old:Destroy()
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "FossilDebug"
	bindable.OnInvoke = DebugService.Run
	bindable.Parent = ServerScriptService
end

return DebugService
