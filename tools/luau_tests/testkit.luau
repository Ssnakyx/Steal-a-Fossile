-- Outils communs des tests hors Studio. Un test type :
--   local T = require("./testkit")
--   local env = T.env
--   local Boot = T.bootServer()
--   local player = T.join()
--   T.eq(T.data(player).Money, 0, "argent de départ")
--   T.done("core_money")
-- T.done affiche « @@ nom: N OK / M FAIL » (lu par run.py) et échoue s'il y a un échec ou une erreur dans un fil.

local env = require("./env")

local T = {}
T.env = env

local passed, failed = 0, 0
local section = ""

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end
T.show = show

local function where(): string
	-- ligne du test qui a appelé check/eq (niveaux : where, record, T.eq, test)
	local info = debug.info(4, "l")
	return if info then " (ligne " .. tostring(info) .. ")" else ""
end

local function record(ok: boolean, label: string, detail: string?)
	if ok then
		passed += 1
		return
	end
	failed += 1
	print(string.format("FAIL %s%s%s%s", if section ~= "" then "[" .. section .. "] " else "", label, if detail then " : " .. detail else "", where()))
end

-- Titre des vérifications qui suivent (dans les messages d'échec)
function T.section(name: string)
	section = name
end

function T.check(condition: any, label: string)
	record(condition and true or false, label)
end

function T.eq(actual: any, expected: any, label: string)
	record(actual == expected, label, if actual == expected then nil else "reçu " .. show(actual) .. ", attendu " .. show(expected))
end

function T.near(actual: number, expected: number, tolerance: number?, label: string)
	local ok = type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6)
	record(ok, label, if ok then nil else "reçu " .. show(actual) .. ", attendu " .. show(expected))
end

-- Vérifie que fn lève une erreur (dont le texte contient `pattern`, recherche simple)
function T.errors(fn: () -> any, pattern: string?, label: string)
	local ok, err = pcall(fn)
	if ok then
		record(false, label, "aucune erreur")
	elseif pattern and not string.find(tostring(err), pattern, 1, true) then
		record(false, label, "erreur inattendue : " .. tostring(err))
	else
		record(true, label)
	end
end

-- Vérifie qu'aucune erreur n'est passée dans un fil, un handler de remote ou un service depuis le dernier appel
function T.clean(label: string)
	local problems = {}
	for _, err in env.errors do
		table.insert(problems, tostring(err))
	end
	local Boot = T.serverBoot
	if Boot then
		local Net = T.lib("Net")
		for _, err in Net.Errors do
			table.insert(problems, err)
		end
		table.clear(Net.Errors)
		for _, err in Boot.Errors do
			table.insert(problems, err)
		end
		table.clear(Boot.Errors)
	end
	table.clear(env.errors)
	record(#problems == 0, label, if #problems > 0 then table.concat(problems, "\n") else nil)
end

function T.done(name: string)
	T.clean("aucune erreur dans les fils à la fin")
	print(string.format("@@ %s: %d OK / %d FAIL", name, passed, failed))
	if failed > 0 then
		error(string.format("%d vérification(s) en échec", failed), 0)
	end
end

-- ===== modules du jeu =====

function T.module(file: string): any
	return env.module(file)
end

function T.lib(name: string): any
	return env.module("src/server/Lib/" .. name)
end

function T.service(name: string): any
	return env.module("src/server/Services/" .. name)
end

function T.config(): any
	return env.module("src/shared/Config")
end

-- ===== serveur et joueurs =====

T.serverBoot = nil :: any

-- Démarre le serveur comme Main.server.luau (une fois par fichier de test)
function T.bootServer(): any
	if T.serverBoot then
		return T.serverBoot
	end
	env.setSide("server")
	local Boot = env.module("src/server/Boot")
	T.serverBoot = Boot
	Boot.Start()
	env.flush()
	return Boot
end

-- Ajoute un joueur et attend qu'il soit prêt (données chargées, attribut Ready) ; opts comme env.addPlayer
function T.join(opts: any?): any
	local player = env.addPlayer(opts)
	env.waitUntil(function()
		return player:GetAttribute("Ready") == true or player.Parent == nil
	end, "joueur prêt", 120)
	return player
end

function T.leave(player: any)
	env.removePlayer(player)
	env.flush()
end

-- Données en mémoire d'un joueur (DataService)
function T.data(player: any): any
	return T.service("DataService").Get(player)
end

-- Avance le temps virtuel
function T.advance(seconds: number)
	env.advance(seconds)
end

-- ===== clients hostiles =====

-- Valeurs qu'un exploiteur peut envoyer à un remote
function T.hostileValues(): { any }
	local deep: any = {}
	local cursor = deep
	for _ = 1, 50 do
		cursor.x = {}
		cursor = cursor.x
	end
	local big = {}
	for index = 1, 2000 do
		big[index] = index
	end
	return {
		0 / 0,
		math.huge,
		-math.huge,
		-1,
		0,
		1e308,
		-1e308,
		0.5,
		123456789,
		"",
		string.rep("x", 100000),
		"\0\255",
		"../../",
		true,
		false,
		{},
		{ 1, 2, 3 },
		{ x = 0 / 0 },
		{ [1] = "a", foo = "b" },
		deep,
		big,
		env.Vector3.new(0 / 0, math.huge, 0),
		env.CFrame.new(),
		env.Color3.new(2, -1, 0),
		env.game:GetService("Workspace"),
		env.game:GetService("ServerScriptService"),
		function() end,
	}
end

-- Appelle chaque remote déclaré avec des valeurs hostiles (1 à 3 arguments) au nom de `player`. Les remotes de
-- `skip` (noms) sont ignorés. Aucune erreur ne doit sortir d'un handler (Net les attrape et les note).
-- Renvoie le nombre d'appels faits.
function T.fuzzRemotes(player: any, skip: { [string]: boolean }?): number
	local Remotes = env.module("src/shared/Remotes")
	local values = T.hostileValues()
	local calls = 0
	local RateLimit = T.lib("RateLimit")
	for _, declaration in Remotes.List() do
		if skip and skip[declaration.Name] then
			continue
		end
		local function call(...: any)
			calls += 1
			-- (on vide la limite de fréquence : sinon presque tous les appels seraient refusés avant le handler)
			RateLimit.Reset(player)
			if declaration.Kind == "Function" then
				local ok, err = pcall(env.invokeServer, player, declaration.Name, ...)
				if not ok then
					table.insert(env.errors, "InvokeServer " .. declaration.Name .. " a levé une erreur vers le client : " .. tostring(err))
				end
			else
				env.fireServer(player, declaration.Name, ...)
			end
		end
		call()
		for _, a in values do
			call(a)
			call(a, a)
			call("money", a)
			call(a, "1", a)
		end
		env.flush()
	end
	return calls
end

-- Spamme un remote : renvoie le nombre d'appels qu'un handler a vraiment traités selon `counter` (fonction lue
-- avant/après) ; sert à vérifier la limite de fréquence
function T.spam(player: any, name: string, count: number, ...: any): { any }
	local results = {}
	local Remotes = env.module("src/shared/Remotes")
	local declaration = Remotes.Find(name)
	assert(declaration, "remote inconnu " .. name)
	for _ = 1, count do
		if declaration.Kind == "Function" then
			table.insert(results, table.pack(env.invokeServer(player, name, ...)))
		else
			env.fireServer(player, name, ...)
		end
	end
	env.flush()
	return results
end

return T
