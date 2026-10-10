--!strict
-- Configuration secrète, côté serveur seulement (jamais répliquée aux clients) : un fichier par domaine dans ce dossier
-- (ServerConfig/Fusion.luau pour les recettes d'hybrides...), chargé automatiquement et lu via ServerConfig.<Domaine>.
-- Tout le reste de la configuration va dans src/shared/Config/ (lisible par les clients).

local ServerConfig: { [string]: any } = {}

local children = script:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)
for _, child in children do
	if child:IsA("ModuleScript") then
		ServerConfig[child.Name] = (require :: any)(child)
	end
end

setmetatable(ServerConfig, {
	__index = function(_, key)
		error(
			string.format("ServerConfig.%s n'existe pas (pas de fichier src/server/ServerConfig/%s.luau)", tostring(key), tostring(key)),
			2
		)
	end,
})

return ServerConfig
