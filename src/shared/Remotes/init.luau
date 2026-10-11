--!strict
-- Remotes du jeu. Chaque domaine déclare les siens dans un fichier de ce dossier (Remotes/<Domaine>.luau) :
--   return {
--       Events = { NomDeLEvenement = "sens : arguments" },
--       Functions = { NomDeLaFonction = "sens : arguments -> retour" },
--       Unreliable = { NomDeLEvenement = "..." }, -- (facultatif) UnreliableRemoteEvent : mises à jour fréquentes, perte permise
--   }
-- Le serveur les crée dans ReplicatedStorage.Remotes au premier require ; le client les attend. Un nom inconnu, du
-- mauvais genre ou déclaré deux fois lève une erreur. Côté serveur, les handlers se posent avec src/server/Lib/Net.luau
-- (limite de fréquence et protection contre les erreurs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Kind = "Event" | "Function" | "Unreliable"
export type Declaration = {
	Name: string,
	Kind: Kind,
	Domain: string,
	Doc: string,
}

local FOLDER_NAME = "Remotes"
local CLASS_NAMES: { [Kind]: string } = {
	Event = "RemoteEvent",
	Function = "RemoteFunction",
	Unreliable = "UnreliableRemoteEvent",
}
local LIST_KEYS: { [string]: Kind } = {
	Events = "Event",
	Functions = "Function",
	Unreliable = "Unreliable",
}

local declared: { [string]: Declaration } = {}
local order: { Declaration } = {}

local function declare(domain: string, kind: Kind, list: any)
	if list == nil then
		return
	end
	if type(list) ~= "table" then
		error(string.format("Remotes/%s : la liste de %s doit être une table", domain, kind))
	end
	for name, doc in list do
		if type(name) ~= "string" or not string.match(name, "^%a%w*$") then
			error(string.format("Remotes/%s : nom de remote invalide %s", domain, tostring(name)))
		end
		local existing = declared[name]
		if existing then
			error(string.format("Remote %s déclaré deux fois (Remotes/%s et Remotes/%s)", name, existing.Domain, domain))
		end
		local declaration: Declaration = { Name = name, Kind = kind, Domain = domain, Doc = tostring(doc) }
		declared[name] = declaration
		table.insert(order, declaration)
	end
end

local modules = script:GetChildren()
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)
for _, module in modules do
	if module:IsA("ModuleScript") then
		local spec = (require :: any)(module)
		if type(spec) ~= "table" then
			error(string.format("Remotes/%s doit renvoyer une table { Events, Functions, Unreliable }", module.Name))
		end
		for key, list in spec do
			local kind = LIST_KEYS[key]
			if not kind then
				error(string.format("Remotes/%s : clé inconnue %s (Events, Functions ou Unreliable)", module.Name, tostring(key)))
			end
			declare(module.Name, kind :: Kind, list)
		end
	end
end
table.sort(order, function(a, b)
	return a.Name < b.Name
end)

local folder: Folder
if RunService:IsServer() then
	-- (un dossier resté dans le fichier de la place ne correspond peut-être plus aux déclarations : on le refait)
	local stale = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if stale then
		stale:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, declaration in order do
		local remote = Instance.new(CLASS_NAMES[declaration.Kind])
		remote.Name = declaration.Name
		if remote:IsA("RemoteFunction") then
			-- réponse par défaut : un client qui appelle une fonction encore sans handler n'attend pas pour toujours
			remote.OnServerInvoke = function()
				return nil
			end
		else
			-- écouteur vide : un événement sans handler serveur ne s'accumule pas dans une file
			(remote :: any).OnServerEvent:Connect(function() end)
		end
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Remotes = {}

local function get(name: string, kind: Kind): Instance
	local declaration = declared[name]
	if not declaration then
		error(string.format("Remote inconnu : %s (à déclarer dans src/shared/Remotes/<Domaine>.luau)", tostring(name)), 3)
	end
	if declaration.Kind ~= kind then
		error(string.format("Le remote %s est de genre %s, pas %s", name, declaration.Kind, kind), 3)
	end
	return folder:WaitForChild(name)
end

function Remotes.Event(name: string): RemoteEvent
	return get(name, "Event") :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return get(name, "Function") :: RemoteFunction
end

function Remotes.Unreliable(name: string): UnreliableRemoteEvent
	return get(name, "Unreliable") :: UnreliableRemoteEvent
end

-- Toutes les déclarations, triées par nom (tests, commandes de debug)
function Remotes.List(): { Declaration }
	return table.clone(order)
end

function Remotes.Find(name: string): Declaration?
	return declared[name]
end

return Remotes
