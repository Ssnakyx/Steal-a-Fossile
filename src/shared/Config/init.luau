--!strict
-- Configuration du jeu, partagée par le serveur et le client : un fichier par domaine dans ce dossier
-- (Config/Core.luau, Config/Zones.luau, Config/Shop.luau...), chargé automatiquement et lu via Config.<Domaine>.
-- Pour avoir les types d'un domaine, on peut aussi requérir son fichier directement : require(Shared.Config.Zones).
-- Lire un domaine qui n'existe pas lève une erreur : une faute de frappe se voit tout de suite.
-- Attention : tout ce qui est ici est lisible par les clients (et les exploiteurs). Les données secrètes (recettes
-- d'hybrides...) vont côté serveur, dans src/server/ServerConfig/.

local Config: { [string]: any } = {}

local children = script:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)
for _, child in children do
	if child:IsA("ModuleScript") then
		Config[child.Name] = (require :: any)(child)
	end
end

setmetatable(Config, {
	__index = function(_, key)
		error(string.format("Config.%s n'existe pas (pas de fichier src/shared/Config/%s.luau)", tostring(key), tostring(key)), 2)
	end,
})

return Config
