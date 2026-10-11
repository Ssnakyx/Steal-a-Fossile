-- Petits modules communs : Guard, Format, RateLimit, Signal, Signals, Leaderstats, Config, ServerConfig
local T = require("./testkit")
local env = T.env

local Guard = T.lib("Guard")
local RateLimit = T.lib("RateLimit")
local Signals = T.lib("Signals")
local Leaderstats = T.lib("Leaderstats")
local Format = T.module("src/shared/Format")
local Signal = T.module("src/shared/Signal")
local Config = T.config()
local ServerConfig = T.module("src/server/ServerConfig")

local NAN = 0 / 0

T.section("Guard")
T.check(Guard.IsFinite(1) and not Guard.IsFinite(NAN) and not Guard.IsFinite(math.huge) and not Guard.IsFinite("1"), "IsFinite")
T.eq(Guard.Number(5, 0, 10), 5, "Number dans les bornes")
T.eq(Guard.Number(11, 0, 10), nil, "Number trop grand")
T.eq(Guard.Number(NAN), nil, "Number NaN")
T.eq(Guard.Number("5"), nil, "Number texte")
T.eq(Guard.Integer(3, 1, 5), 3, "Integer")
T.eq(Guard.Integer(2.5, 1, 5), nil, "Integer décimal refusé")
T.eq(Guard.String("abc", 5), "abc", "String")
T.eq(Guard.String("abcdef", 5), nil, "String trop long")
T.eq(Guard.String("a\nb"), nil, "String avec caractère de contrôle")
T.eq(Guard.String("\255\254"), nil, "String UTF-8 invalide")
T.eq(Guard.String(12), nil, "String nombre refusé")
T.eq(Guard.Key("a", { a = 1 }), "a", "Key connue")
T.eq(Guard.Key("b", { a = 1 }), nil, "Key inconnue")
T.eq(Guard.Key("__index", setmetatable({}, { __index = { __index = 1 } })), nil, "Key ignore les métatables")
T.check(Guard.Vector3(env.Vector3.new(1, 2, 3)) ~= nil, "Vector3")
T.eq(Guard.Vector3(env.Vector3.new(NAN, 0, 0)), nil, "Vector3 NaN")
T.eq(Guard.Vector3({ X = 1, Y = 2, Z = 3 }), nil, "Vector3 imité par une table")
T.eq(Guard.NumberOr(NAN, 7), 7, "NumberOr NaN")
T.eq(Guard.NumberOr(50, 7, 0, 10), 10, "NumberOr borné")
T.eq(Guard.IntegerOr(4.7, 0), 4, "IntegerOr")
local set = Guard.StringSet({ a = true, b = false, [3] = true, c = "yes", d = true })
T.check(set.a and set.d and set.b == nil and set.c == nil and set[3 :: any] == nil, "StringSet")

T.section("Format")
T.eq(Format.Number(0), "0", "0")
T.eq(Format.Number(999), "999", "999")
T.eq(Format.Number(1234), "1.23K", "1.23K")
T.eq(Format.Number(5600000), "5.6M", "5.6M")
T.eq(Format.Number(999950), "1M", "arrondi au suffixe suivant")
T.eq(Format.Number(-1500), "-1.5K", "négatif")
T.eq(Format.Number(NAN), "0", "NaN")
T.eq(Format.Number(math.huge), "inf", "infini")
T.check(string.find(Format.Number(1e300), "e", 1, true) ~= nil, "nombre géant en notation e")
T.eq(Format.Money(1500), "$1.5K", "Money")
T.eq(Format.Money(-20), "-$20", "Money négatif")
T.eq(Format.Rate(12500), "$12.5K/s", "Rate")
T.eq(Format.Duration(45), "45s", "Duration s")
T.eq(Format.Duration(200), "3m 20s", "Duration m")
T.eq(Format.Duration(3700), "1h 01m", "Duration h")
T.eq(Format.Duration(90000), "1d 1h", "Duration d")
T.eq(Format.Clock(65), "1:05", "Clock")
T.eq(Format.Clock(3725), "1:02:05", "Clock h")
T.eq(Format.Percent(0.25), "25%", "Percent")
T.eq(Format.Percent(0.001), "0.1%", "Percent petit")
T.eq(Format.Percent(0.055), "5.5%", "Percent moyen")

T.section("RateLimit")
local player = env.addPlayer()
local allowed = 0
for _ = 1, 10 do
	if RateLimit.Allow(player, "test", 1, 3) then
		allowed += 1
	end
end
T.eq(allowed, 3, "rafale de 3")
env.advance(2)
allowed = 0
for _ = 1, 10 do
	if RateLimit.Allow(player, "test", 1, 3) then
		allowed += 1
	end
end
T.eq(allowed, 2, "2 jetons revenus en 2 s")
T.check(RateLimit.Allow(player, "other", 1, 1), "clés séparées")
RateLimit.Reset(player)
T.check(RateLimit.Allow(player, "test", 1, 3), "Reset")
env.quiet = true
table.clear(env.warnings)
for _ = 1, 500 do
	RateLimit.Allow(player, "spam", 1, 1)
end
env.quiet = false
T.check(#env.warnings <= 3, "peu de warn même sous le spam (" .. #env.warnings .. ")")
table.clear(env.warnings)

T.section("Signal")
local signal = Signal.new()
local got = {}
local connection = signal:Connect(function(value)
	table.insert(got, value)
end)
signal:Once(function(value)
	table.insert(got, "once " .. tostring(value))
end)
signal:Fire(1)
signal:Fire(2)
T.eq(table.concat(got, ","), "1,once 1,2", "Connect et Once")
connection:Disconnect()
signal:Fire(3)
T.eq(#got, 3, "Disconnect")
local waited = nil
env.task.spawn(function()
	waited = signal:Wait()
end)
signal:Fire("w")
env.flush()
T.eq(waited, "w", "Wait")
signal:Connect(function()
	error("boom")
end)
local after = false
signal:Connect(function()
	after = true
end)
signal:Fire()
T.check(after, "une erreur dans un handler n'arrête pas les autres")
T.eq(#env.errors, 1, "erreur du handler signalée")
table.clear(env.errors)
signal:DisconnectAll()

T.section("Signals")
local seen = nil
local disconnect = Signals.Connect("TestSignal", function(a, b)
	seen = a + b
end)
Signals.Fire("TestSignal", 2, 3)
T.eq(seen, 5, "Fire et Connect")
disconnect()
Signals.Fire("TestSignal", 10, 10)
T.eq(seen, 5, "débranché")
Signals.Fire("NobodyListens", 1)

T.section("Leaderstats")
Leaderstats.Set(player, "Money", "$10")
Leaderstats.Set(player, "Speed", "5")
Leaderstats.Set(player, "Money", "$20")
local folder = player:FindFirstChild("leaderstats")
T.check(folder ~= nil and folder:IsA("Folder"), "dossier leaderstats")
T.eq(folder.Money.Value, "$20", "valeur mise à jour")
T.eq(#folder:GetChildren(), 2, "pas de doublon")

T.section("Config")
T.check(type(Config.Core) == "table", "Config.Core")
T.errors(function()
	local _ = Config.Nope
end, "Config.Nope n'existe pas", "domaine inconnu")
T.errors(function()
	local _ = ServerConfig.Nope
end, "ServerConfig.Nope", "domaine serveur inconnu")
T.check(table.find(Config.Core.Admins, 3346721423) ~= nil, "Snaky est admin")
T.check(Config.Core.Data.AutosaveInterval >= 30, "autosave pas trop fréquent")
T.check(Config.Core.Data.SaveInStudio == false, "Studio n'écrit pas par défaut")

T.done("core_lib")
