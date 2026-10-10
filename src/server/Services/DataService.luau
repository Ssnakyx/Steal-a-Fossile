--!strict
-- Sauvegarde des joueurs (reprise de Steal a Snack et adaptée, brief 1) : une sauvegarde par joueur dans le DataStore
-- Config.Core.Data.StoreName, protégée par un verrou de session (deux serveurs n'écrivent jamais la même sauvegarde),
-- écrite toutes les Config.Core.Data.AutosaveInterval secondes, quand le joueur part et quand le serveur s'arrête.
--
-- Les champs viennent des domaines de src/server/Data/<Domaine>.luau (un fichier par brief, chargés tout seuls) :
--   return {
--       Version = 1,                                -- à monter à chaque changement de format du domaine
--       Defaults = { Gems = 0 },                    -- champs du domaine et valeurs de départ
--       Migrate = function(data, from) end,         -- (facultatif) met à jour une sauvegarde de la version `from`
--       Sanitize = function(data) end,              -- (facultatif) répare les valeurs abîmées, après chaque chargement
--       BeforeSave = function(data, elapsed) end,   -- (facultatif) avant chaque écriture (elapsed = secondes depuis la précédente)
--   }
-- Un champ n'appartient qu'à un domaine. Un champ manquant prend sa valeur de départ (aussi dans les sous-tables) ; une
-- valeur du mauvais type est remplacée par la valeur de départ.
--
-- Usage : DataService.Get(player) renvoie la table vivante (nil tant que le joueur n'est pas chargé) ; les services la
-- modifient directement. OnPlayerReady(player, data) des services reçoit la même table. Avant l'écriture, les nombres
-- NaN ou infinis deviennent 0 et ce qui ne se sauvegarde pas (fonctions, instances) est retiré, avec un warn.
-- Studio lit la vraie sauvegarde mais ne l'écrit jamais (sauf Config.Core.Data.SaveInStudio) ; sans accès aux API dans
-- Studio, les données repartent de zéro.
--
-- Échec de chargement : le joueur est expulsé avec un message, sa sauvegarde n'est jamais écrasée. Une sauvegarde écrite
-- par une version plus récente du jeu n'est pas chargée (« server outdated »).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Config.Core)

export type Data = { [string]: any }
export type Spec = {
	Version: number,
	Defaults: { [string]: any },
	Migrate: ((data: Data, from: number) -> ())?,
	Sanitize: ((data: Data) -> ())?,
	BeforeSave: ((data: Data, elapsed: number) -> ())?,
}

type Domain = { Name: string, Spec: Spec }
type Profile = {
	Player: Player,
	Key: string,
	Session: string,
	Data: Data,
	ReadOnly: boolean,
	Released: boolean,
	Saving: boolean,
	LastSave: number,
}

local DataService = {}
DataService.Priority = -100

-- Version du format global (Version, Domains). Chaque domaine a en plus sa propre version.
DataService.SchemaVersion = 1
-- GLOBAL_MIGRATIONS[n] passe une sauvegarde de la version globale n à n + 1
local GLOBAL_MIGRATIONS: { [number]: (Data) -> () } = {}

local RESERVED = { Version = true, Domains = true, _Lock = true }
local KEY_PREFIX = "Player_"
local SAVE_ATTEMPTS = 3
local MAX_JSON = 3_500_000 -- (limite du DataStore : 4 Mo)

local domains: { Domain } = {}
local owners: { [string]: string } = {}
local profiles: { [Player]: Profile } = {}
local loading: { [Player]: boolean } = {}
local leaving: { [Player]: boolean } = {}
local pendingSaves = 0
local store: DataStore? = nil

local function lockExpiry(): number
	return Core.Data.AutosaveInterval + 50
end

local function readOnlyStudio(): boolean
	return RunService:IsStudio() and not Core.Data.SaveInStudio
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy
end

-- Champs manquants ou du mauvais type : valeur de départ (récursif dans les sous-tables)
local function fill(target: { [any]: any }, defaults: { [any]: any }, path: string)
	for key, default in defaults do
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(default)
		elseif type(current) ~= type(default) then
			warn(string.format("[DataService] %s.%s : %s au lieu de %s, valeur de départ remise", path, tostring(key), type(current), type(default)))
			target[key] = deepCopy(default)
		elseif type(default) == "table" then
			fill(current, default, path .. "." .. tostring(key))
		end
	end
end

-- Copie sauvegardable de `value` (format accepté par le DataStore) ; les problèmes trouvés vont dans `problems`
local function storable(value: any, path: string, problems: { string }, seen: { [any]: boolean }): any
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			table.insert(problems, path .. " = " .. tostring(value))
			return 0
		end
		return value
	elseif kind == "string" then
		if utf8.len(value) == nil then
			table.insert(problems, path .. " : texte invalide")
			return ""
		end
		return value
	elseif kind == "boolean" then
		return value
	elseif kind == "table" then
		if seen[value] then
			table.insert(problems, path .. " : table en boucle")
			return nil
		end
		seen[value] = true
		local count = 0
		for _ in value do
			count += 1
		end
		local clean: { [any]: any } = {}
		if count == #value then
			-- liste : les éléments retirés ne laissent pas de trou
			for index, item in ipairs(value) do
				local cleaned = storable(item, path .. "[" .. index .. "]", problems, seen)
				if cleaned ~= nil then
					table.insert(clean, cleaned)
				end
			end
		else
			for key, item in value do
				local keyPath = path .. "." .. tostring(key)
				if type(key) ~= "string" then
					table.insert(problems, keyPath .. " : clé " .. type(key) .. " dans une table à clés texte")
				else
					local cleaned = storable(item, keyPath, problems, seen)
					if cleaned ~= nil then
						clean[key] = cleaned
					end
				end
			end
		end
		seen[value] = nil
		return clean
	end
	table.insert(problems, path .. " : " .. typeof(value) .. " ne se sauvegarde pas")
	return nil
end

local function getStore(): (DataStore?, string?)
	if store then
		return store, nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Core.Data.StoreName)
	end)
	if not ok then
		return nil, tostring(result)
	end
	store = result
	return result, nil
end

-- Une sauvegarde écrite par une version plus récente du jeu : on ne la touche pas (on perdrait ses nouveautés)
local function newerThanCode(stored: any): string?
	if type(stored) ~= "table" then
		return nil
	end
	local version = tonumber(stored.Version) or 0
	if version > DataService.SchemaVersion then
		return "Version " .. version
	end
	if type(stored.Domains) == "table" then
		for _, domain in domains do
			local domainVersion = tonumber(stored.Domains[domain.Name]) or 0
			if domainVersion > domain.Spec.Version then
				return domain.Name .. " " .. domainVersion
			end
		end
	end
	return nil
end

-- Sauvegarde brute -> données de jeu à jour (migrations, valeurs de départ, réparations)
local function build(stored: any, name: string): Data
	local fresh = type(stored) ~= "table"
	if stored ~= nil and fresh then
		warn(string.format("[DataService] sauvegarde de %s illisible (%s) : nouvelles données", name, type(stored)))
	end
	local data: Data = if fresh then {} else deepCopy(stored)
	data._Lock = nil
	local version = if fresh then DataService.SchemaVersion else math.max(1, tonumber(data.Version) or 1)
	while version < DataService.SchemaVersion do
		local migrate = GLOBAL_MIGRATIONS[version]
		if migrate then
			migrate(data)
		end
		version += 1
	end
	data.Version = DataService.SchemaVersion
	local versions = if type(data.Domains) == "table" then data.Domains else {}
	data.Domains = versions
	for _, domain in domains do
		local spec = domain.Spec
		local from = tonumber(versions[domain.Name]) or 0
		if not fresh and from > 0 and from < spec.Version and spec.Migrate then
			spec.Migrate(data, from)
		end
		versions[domain.Name] = spec.Version
	end
	for _, domain in domains do
		fill(data, domain.Spec.Defaults, name)
	end
	for _, domain in domains do
		local sanitize = domain.Spec.Sanitize
		if sanitize then
			sanitize(data)
		end
	end
	return data
end

-- Rend le verrou sans rien changer d'autre (chargement abandonné)
local function releaseLock(key: string, session: string)
	local dataStore = getStore()
	if not dataStore then
		return
	end
	local ok, err = pcall(function()
		dataStore:UpdateAsync(key, function(current: any): any
			if type(current) == "table" and type(current._Lock) == "table" and current._Lock.Session == session then
				current._Lock = nil
				return current
			end
			return nil
		end)
	end)
	if not ok then
		warn("[DataService] verrou non rendu (il expirera tout seul) : " .. tostring(err))
	end
end

local function runBeforeSave(profile: Profile)
	local now = os.clock()
	local elapsed = math.max(0, now - profile.LastSave)
	profile.LastSave = now
	for _, domain in domains do
		local hook = domain.Spec.BeforeSave
		if hook then
			local ok, err = pcall(hook :: any, profile.Data, elapsed)
			if not ok then
				warn(string.format("[DataService] Data/%s BeforeSave : %s", domain.Name, tostring(err)))
			end
		end
	end
end

-- Liste de ce qui ne se sauvegarderait pas tel quel dans `data` (NaN, fonctions, clés mélangées...)
function DataService.Problems(data: Data): { string }
	local problems = {}
	storable(data, "data", problems, {})
	return problems
end

local function write(profile: Profile, release: boolean): boolean
	runBeforeSave(profile)
	if profile.ReadOnly then
		return true
	end
	local player = profile.Player
	local problems = {}
	local copy = storable(profile.Data, "data", problems, {})
	if #problems > 0 then
		warn(string.format("[DataService] %s : %d valeur(s) réparée(s) avant sauvegarde : %s", player.Name, #problems, table.concat(problems, ", ", 1, math.min(#problems, 5))))
	end
	local encoded, json = pcall(HttpService.JSONEncode, HttpService, copy)
	if encoded and #json > MAX_JSON then
		warn(string.format("[DataService] sauvegarde de %s très grosse (%d octets)", player.Name, #json))
	end
	local dataStore, storeErr = getStore()
	if not dataStore then
		warn("[DataService] DataStore indisponible : " .. tostring(storeErr))
		return false
	end
	local stolen = false
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(profile.Key, function(current: any): any
				stolen = false
				local lock = if type(current) == "table" then current._Lock else nil
				if type(lock) ~= "table" or lock.Session ~= profile.Session then
					-- notre verrou a expiré et un autre serveur a ouvert la sauvegarde : on n'écrit surtout pas
					stolen = true
					return nil
				end
				copy._Lock = if release then nil else { Job = game.JobId, Session = profile.Session, Time = os.time() }
				return copy
			end)
		end)
		if ok then
			if stolen then
				warn(string.format("[DataService] sauvegarde de %s ouverte par un autre serveur : plus d'écriture ici", player.Name))
				profile.Released = true
				if profiles[player] == profile then
					profiles[player] = nil
				end
				if player.Parent == Players then
					player:Kick("Your data was opened on another server. Please rejoin.")
				end
				return false
			end
			return true
		end
		warn(string.format("[DataService] sauvegarde de %s, essai %d : %s", player.Name, attempt, tostring(err)))
		if attempt < SAVE_ATTEMPTS then
			task.wait(attempt)
		end
	end
	return false
end

-- Une seule écriture à la fois par joueur : la suivante attend la précédente
local function save(profile: Profile, release: boolean): boolean
	while profile.Saving do
		task.wait(0.1)
	end
	if profile.Released and not release then
		return false
	end
	profile.Saving = true
	pendingSaves += 1
	local ok, result = pcall(write, profile, release)
	pendingSaves -= 1
	profile.Saving = false
	if not ok then
		warn("[DataService] " .. tostring(result))
		return false
	end
	return result
end

-- Ajoute un domaine de données (fait tout seul pour src/server/Data/ ; les tests l'appellent aussi)
function DataService.RegisterDomain(name: string, spec: Spec)
	if type(name) ~= "string" or not string.match(name, "^%a%w*$") then
		error("DataService : nom de domaine invalide " .. tostring(name), 2)
	end
	if type(spec) ~= "table" then
		error(string.format("Data/%s doit renvoyer une table { Version, Defaults, ... }", name), 2)
	end
	if type(spec.Version) ~= "number" or spec.Version < 1 or spec.Version % 1 ~= 0 then
		error(string.format("Data/%s : Version doit être un entier >= 1", name), 2)
	end
	if type(spec.Defaults) ~= "table" then
		error(string.format("Data/%s : Defaults doit être une table", name), 2)
	end
	for _, hook in { "Migrate", "Sanitize", "BeforeSave" } do
		local value = (spec :: any)[hook]
		if value ~= nil and type(value) ~= "function" then
			error(string.format("Data/%s : %s doit être une fonction", name, hook), 2)
		end
	end
	for _, domain in domains do
		if domain.Name == name then
			error(string.format("Data/%s : domaine déjà enregistré", name), 2)
		end
	end
	for field in spec.Defaults do
		if type(field) ~= "string" then
			error(string.format("Data/%s : les champs doivent avoir des noms texte", name), 2)
		end
		if RESERVED[field] then
			error(string.format("Data/%s : le champ %s est réservé", name, field), 2)
		end
		if owners[field] then
			error(string.format("Data/%s : le champ %s appartient déjà au domaine %s", name, field, owners[field]), 2)
		end
	end
	local problems = DataService.Problems(spec.Defaults)
	if #problems > 0 then
		error(string.format("Data/%s : valeurs de départ non sauvegardables : %s", name, table.concat(problems, ", ")), 2)
	end
	for field in spec.Defaults do
		owners[field] = name
	end
	table.insert(domains, { Name = name, Spec = spec })
	table.sort(domains, function(a, b)
		return a.Name < b.Name
	end)
end

-- Domaines enregistrés, triés par nom
function DataService.Domains(): { string }
	local names = {}
	for _, domain in domains do
		table.insert(names, domain.Name)
	end
	return names
end

-- Domaine propriétaire d'un champ
function DataService.Owner(field: string): string?
	return owners[field]
end

-- Données d'un nouveau joueur (tests, debug)
function DataService.Defaults(): Data
	return build(nil, "defaults")
end

-- Charge la sauvegarde du joueur (appelé par Boot à l'arrivée). Renvoie nil si le chargement a échoué (joueur expulsé)
-- ou si le joueur est parti entre-temps.
function DataService.Load(player: Player): Data?
	local existing = profiles[player]
	if existing then
		return if existing.Released then nil else existing.Data
	end
	if loading[player] then
		while loading[player] do
			task.wait(0.1)
		end
		local profile = profiles[player]
		return if profile and not profile.Released then profile.Data else nil
	end
	loading[player] = true
	local key = KEY_PREFIX .. player.UserId
	local session = HttpService:GenerateGUID(false)
	local readOnly = readOnlyStudio()
	local stored: any = nil
	local acquired = false
	local success = false
	local failure: string? = nil
	local attempts = math.max(1, Core.Data.LoadAttempts)
	for attempt = 1, attempts do
		if player.Parent ~= Players or leaving[player] then
			break
		end
		local blocked = false
		local outdated: string? = nil
		local dataStore, storeErr = getStore()
		local ok, err = false, storeErr
		if dataStore then
			ok, err = pcall(function()
				if readOnly then
					stored = dataStore:GetAsync(key)
					outdated = newerThanCode(stored)
					return
				end
				dataStore:UpdateAsync(key, function(current: any): any
					blocked = false
					stored = current
					outdated = newerThanCode(current)
					if outdated then
						return nil
					end
					local lock = if type(current) == "table" then current._Lock else nil
					if type(lock) == "table" and lock.Session ~= session and os.time() - (tonumber(lock.Time) or 0) < lockExpiry() then
						blocked = true
						return nil
					end
					local saved = if type(current) == "table" then current else {}
					saved._Lock = { Job = game.JobId, Session = session, Time = os.time() }
					return saved
				end)
				acquired = not blocked and outdated == nil
			end)
		end
		if ok then
			if outdated then
				warn(string.format("[DataService] sauvegarde de %s plus récente que ce serveur (%s)", player.Name, outdated))
				failure = "This server is outdated. Please rejoin."
				break
			elseif not blocked then
				success = true
				break
			end
			warn(string.format("[DataService] sauvegarde de %s encore ouverte sur un autre serveur (essai %d/%d)", player.Name, attempt, attempts))
		else
			warn(string.format("[DataService] chargement de %s, essai %d/%d : %s", player.Name, attempt, attempts, tostring(err)))
			if RunService:IsStudio() then
				warn("[DataService] Studio sans accès au DataStore : nouvelles données, jamais sauvegardées")
				stored = nil
				readOnly = true
				success = true
				break
			end
		end
		if attempt < attempts then
			task.wait(if blocked then 5 else 2)
		end
	end

	local data: Data? = nil
	if success then
		local built, result = pcall(build, stored, player.Name)
		if built then
			data = result
		else
			warn(string.format("[DataService] sauvegarde de %s impossible à préparer : %s", player.Name, tostring(result)))
		end
	end
	if not data then
		if acquired then
			releaseLock(key, session)
		end
		loading[player] = nil
		leaving[player] = nil
		if player.Parent == Players then
			player:Kick(failure or "Your data could not be loaded. Please rejoin in a moment.")
		end
		return nil
	end

	local profile: Profile = {
		Player = player,
		Key = key,
		Session = session,
		Data = data,
		ReadOnly = readOnly,
		Released = false,
		Saving = false,
		LastSave = os.clock(),
	}
	profiles[player] = profile
	loading[player] = nil
	if leaving[player] or player.Parent ~= Players then
		leaving[player] = nil
		DataService.Release(player)
		return nil
	end
	return data
end

-- Données vivantes du joueur (nil s'il n'est pas chargé)
function DataService.Get(player: Player): Data?
	local profile = profiles[player]
	if profile and not profile.Released then
		return profile.Data
	end
	return nil
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.Get(player) ~= nil
end

-- Attend la fin du chargement (au plus `timeout` secondes) et renvoie les données
function DataService.WaitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or 30)
	while loading[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

-- Écrit tout de suite (achats Robux). Renvoie true si c'est écrit (ou en Studio sans écriture).
function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	return save(profile, false)
end

-- Dernière sauvegarde et fin du verrou (appelé par Boot quand le joueur part)
function DataService.Release(player: Player)
	if loading[player] then
		leaving[player] = true
		return
	end
	local profile = profiles[player]
	if not profile or profile.Released then
		return
	end
	profile.Released = true
	if not save(profile, true) then
		warn(string.format("[DataService] dernière sauvegarde de %s ratée (le verrou expirera tout seul)", player.Name))
	end
	if profiles[player] == profile then
		profiles[player] = nil
	end
end

-- Arrêt du serveur (appelé par Boot dans BindToClose) : rend toutes les sauvegardes et attend la fin des écritures
function DataService.Close(timeout: number?)
	for player, profile in profiles do
		if not profile.Released then
			task.spawn(DataService.Release, player)
		end
	end
	local deadline = os.clock() + (timeout or 25)
	while (pendingSaves > 0 or next(loading) ~= nil or next(profiles) ~= nil) and os.clock() < deadline do
		task.wait(0.1)
	end
end

function DataService.Init()
	local folder = script.Parent.Parent:FindFirstChild("Data")
	if not folder then
		return
	end
	local modules = folder:GetChildren()
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)
	for _, module in modules do
		if module:IsA("ModuleScript") then
			DataService.RegisterDomain(module.Name, (require :: any)(module))
		end
	end
end

function DataService.Start()
	while true do
		task.wait(Core.Data.AutosaveInterval)
		for _, profile in profiles do
			if not profile.Released then
				task.spawn(save, profile, false)
			end
		end
	end
end

return DataService
