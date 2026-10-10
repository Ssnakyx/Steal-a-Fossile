--!strict
-- Colonnes du classement Roblox (leaderstats) : Leaderstats.Set(player, "Money", Format.Money(n)).
-- Les colonnes apparaissent dans l'ordre de leur premier Set. Valeur texte : le chiffre déjà formaté.

local Leaderstats = {}

function Leaderstats.Set(player: Player, name: string, text: string)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end
	local value = (folder :: Instance):FindFirstChild(name)
	if not (value and value:IsA("StringValue")) then
		if value then
			value:Destroy()
		end
		local created = Instance.new("StringValue")
		created.Name = name
		created.Parent = folder
		value = created
	end
	(value :: StringValue).Value = text
end

return Leaderstats
