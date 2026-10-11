--!strict
-- Mise en forme des nombres et des durées pour l'interface (reprise de Steal a Snack).

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 5600000 -> "5.6M" ; gère aussi les négatifs, NaN, l'infini et les nombres géants
function Format.Number(n: number): string
	if type(n) ~= "number" or n ~= n then
		return "0"
	end
	if math.abs(n) == math.huge then
		return if n > 0 then "inf" else "-inf"
	end
	local sign = if n < 0 then "-" else ""
	n = math.floor(math.abs(n))
	if n < 1000 then
		return sign .. tostring(n)
	end
	local index = 1
	local value = n
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	if value >= 1000 then
		return sign .. string.format("%.2e", n)
	end
	local text = string.format(if value < 10 then "%.2f" elseif value < 100 then "%.1f" else "%.0f", value)
	-- l'arrondi peut donner "1000" (999 950 -> "1000K") : on passe au suffixe suivant
	local rounded = tonumber(text)
	if rounded and rounded >= 1000 and index < #SUFFIXES then
		index += 1
		text = string.format("%.2f", value / 1000)
	end
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return sign .. text .. SUFFIXES[index]
end

-- "$1.5K", "-$20"
function Format.Money(n: number): string
	if type(n) == "number" and n < 0 and n == n then
		return "-$" .. Format.Number(-n)
	end
	return "$" .. Format.Number(n)
end

-- Revenu par seconde : "$12.5K/s"
function Format.Rate(n: number): string
	return Format.Money(n) .. "/s"
end

-- Durée lisible : 45 -> "45s", 200 -> "3m 20s", 3700 -> "1h 01m", 90000 -> "1d 1h"
function Format.Duration(seconds: number): string
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return "0s"
	end
	if seconds == math.huge then
		return "inf"
	end
	local s = math.floor(seconds)
	if s < 60 then
		return s .. "s"
	elseif s < 3600 then
		return string.format("%dm %02ds", s // 60, s % 60)
	elseif s < 86400 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	end
	return string.format("%dd %dh", s // 86400, (s % 86400) // 3600)
end

-- Compte à rebours : 65 -> "1:05", 3725 -> "1:02:05"
function Format.Clock(seconds: number): string
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return "0:00"
	end
	local s = math.floor(math.min(seconds, 359999))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Probabilité affichée (toute chance payante doit afficher ses probas) : 0.25 -> "25%", 0.001 -> "0.1%"
function Format.Percent(p: number): string
	if type(p) ~= "number" or p ~= p then
		return "0%"
	end
	local value = p * 100
	local text = if value >= 10 then string.format("%.0f", value) elseif value >= 1 then string.format("%.1f", value) else string.format("%.2f", value)
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text .. "%"
end

-- Article anglais devant un nom : « an Amber Compy », « an Archelon », « a Big Compy »
function Format.Article(name: string): string
	return if type(name) == "string" and string.match(name, "^[AEIOUaeiou]") then "an" else "a"
end

return Format
