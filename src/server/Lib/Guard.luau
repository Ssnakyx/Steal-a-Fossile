--!strict
-- Vérification des valeurs venues d'ailleurs (arguments des remotes, sauvegardes abîmées) : le serveur ne fait jamais
-- confiance au client. Chaque fonction renvoie la valeur propre, ou nil si elle ne convient pas.
--   local count = Guard.Integer(rawCount, 1, 10) ; if not count then return false, "Error" end
-- Les variantes « Or » (NumberOr, IntegerOr) réparent une valeur de sauvegarde : valeur par défaut si invalide,
-- bornée sinon.

local Guard = {}

-- Nombre fini (ni NaN ni infini)
function Guard.IsFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Nombre fini compris entre min et max (inclus)
function Guard.Number(value: any, min: number?, max: number?): number?
	if not Guard.IsFinite(value) then
		return nil
	end
	if (min and value < min) or (max and value > max) then
		return nil
	end
	return value
end

-- Entier compris entre min et max (inclus)
function Guard.Integer(value: any, min: number?, max: number?): number?
	local n = Guard.Number(value, min, max)
	if n == nil or n % 1 ~= 0 then
		return nil
	end
	return n
end

-- Texte d'au plus maxLength octets (200 par défaut), UTF-8 valide, sans caractère de contrôle
function Guard.String(value: any, maxLength: number?): string?
	if type(value) ~= "string" then
		return nil
	end
	if #value > (maxLength or 200) or string.find(value, "%c") or utf8.len(value) == nil then
		return nil
	end
	return value
end

-- Clé connue d'une table (identifiant d'objet, de zone, d'espèce...)
function Guard.Key(value: any, known: { [string]: any }): string?
	if type(value) ~= "string" or #value > 100 then
		return nil
	end
	if rawget(known, value) == nil then
		return nil
	end
	return value
end

-- Vector3 aux composantes finies
function Guard.Vector3(value: any): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local v = value :: Vector3
	if not (Guard.IsFinite(v.X) and Guard.IsFinite(v.Y) and Guard.IsFinite(v.Z)) then
		return nil
	end
	return v
end

-- Sauvegardes : nombre réparé (par défaut si invalide, borné sinon)
function Guard.NumberOr(value: any, default: number, min: number?, max: number?): number
	if not Guard.IsFinite(value) then
		return default
	end
	local n = value :: number
	if min and n < min then
		n = min
	end
	if max and n > max then
		n = max
	end
	return n
end

-- Sauvegardes : entier réparé
function Guard.IntegerOr(value: any, default: number, min: number?, max: number?): number
	return math.floor(Guard.NumberOr(value, default, min, max))
end

-- Sauvegardes : ensemble { [texte] = true } nettoyé (clés texte, valeurs true seulement)
function Guard.StringSet(value: any, maxCount: number?): { [string]: boolean }
	local clean: { [string]: boolean } = {}
	if type(value) ~= "table" then
		return clean
	end
	local count = 0
	for key, flag in value do
		if type(key) == "string" and flag == true and #key <= 100 then
			count += 1
			if maxCount and count > maxCount then
				break
			end
			clean[key] = true
		end
	end
	return clean
end

-- Pièce centrale du personnage (nil si le joueur n'a pas de personnage)
function Guard.Root(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Le personnage du joueur est-il à moins de maxDistance studs de position ? (portée vérifiée par le serveur)
function Guard.Near(player: Player, position: Vector3, maxDistance: number): boolean
	local root = Guard.Root(player)
	if not root then
		return false
	end
	return (root.Position - position).Magnitude <= maxDistance
end

return Guard
