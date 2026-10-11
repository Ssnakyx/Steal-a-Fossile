-- Faux Roblox strict pour les tests hors Studio (brief 1). Chargé par chaque module du jeu via la ligne d'en-tête que
-- run.py met à la place de « --!strict » ; les tests le requièrent avec require("./env").
--
-- Ce qui est simulé :
--   * l'arbre du jeu (default.project.json) avec de vraies instances : parent, enfants, attributs, tags, signaux,
--     Destroy, Clone, WaitForChild ; les classes, propriétés, événements et enums viennent de l'API de Roblox
--     (globalTypes.d.luau) : une propriété inconnue ou du mauvais type lève une erreur comme dans Studio ;
--   * le temps virtuel : task.spawn/defer/delay/wait, os.clock/os.time, Heartbeat ; un task.wait dans le fil principal
--     du test fait avancer le temps ; env.advance(secondes) aussi ;
--   * les services utiles : Players (env.addPlayer / env.removePlayer), RunService (env.side, env.studio),
--     DataStoreService (stockage strict, pannes et lenteurs simulées), MarketplaceService (env.purchase), HttpService
--     (GUID, JSON), TweenService, CollectionService, GroupService, TextService, UserInputService... ;
--   * les remotes en boucle locale : un FireServer du client arrive au serveur avec env.localPlayer, un FireClient vers
--     ce joueur arrive au client ; env.fireServer / env.invokeServer jouent un client hostile ; env.sent garde les envois.
-- Ce qui ne l'est pas : rendu, physique, mise en page (AbsoluteSize se déduit de Size), réseau réel.
-- Une méthode Roblox non simulée lève une erreur : la simuler avec env.stubMethod(classe, nom, fonction).
-- Les erreurs dans les fils (handlers, task.spawn) vont dans env.errors ; les warn dans env.warnings.

local api = require("./api")
local manifestList = require("./manifest")
local D = require("./datatypes")

local nativeRequire = require
local nativeTypeof = typeof
local nativeOs = os
local nativePrint = print

local env: any = {}
env.errors = {} -- erreurs dans des fils
env.warnings = {} -- textes passés à warn
env.side = "server" -- "server" ou "client" (RunService:IsServer / IsClient)
env.studio = true -- RunService:IsStudio()
env.touch = false -- UserInputService.TouchEnabled sans clavier
env.frame = 1 / 60 -- durée d'une image virtuelle
env.baseTime = 1760000000 -- os.time() au temps 0 (2025-10-09)
env.sent = {} -- envois serveur -> client : { Remote, Player, Args }
env.kicks = {} -- { Player, Message }
env.quiet = false -- true : warn n'affiche rien (les textes restent dans env.warnings)
env.localPlayer = nil

local function quote(value: any): string
	return if type(value) == "string" then string.format("%q", value) else tostring(value)
end

-- ===== typeof =====

local function typeOf(value: any): string
	if type(value) == "table" then
		local mt = getmetatable(value)
		if type(mt) == "table" then
			local name = rawget(mt, "__type")
			if name then
				return name
			end
		end
	end
	return nativeTypeof(value)
end
env.typeof = typeOf

-- type() de Roblox : les instances et les types de données (Vector3, CFrame, EnumItem...) sont des userdata
local nativeType = type
local function typeFn(value: any): string
	local kind = nativeType(value)
	if kind == "table" then
		local mt = getmetatable(value)
		if nativeType(mt) == "table" and rawget(mt, "__type") then
			return "userdata"
		end
	end
	return kind
end
env.type = typeFn

-- ===== Temps virtuel et fils =====

local now = 0
local timers: { any } = {}
local deferred: { any } = {}
local timerSeq = 0
local cancelled = setmetatable({}, { __mode = "k" })
local heartbeatSignals: { any } = {}

local function reportError(thread: thread?, err: any)
	local text = if thread then debug.traceback(thread, tostring(err)) else tostring(err)
	table.insert(env.errors, text)
	nativePrint("ERROR " .. text)
end

local function resume(thread: thread, ...: any)
	if cancelled[thread] or coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		reportError(thread, err)
	end
end
env.resume = resume

local function schedule(at: number, thread: thread, ...: any)
	timerSeq += 1
	local item = { At = at, Seq = timerSeq, Thread = thread, Args = table.pack(...) }
	local index = #timers
	while index >= 1 and timers[index].At > at do
		index -= 1
	end
	table.insert(timers, index + 1, item)
end

local ownThreads: { [thread]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function toThread(fn: any): thread
	if type(fn) == "thread" then
		return fn
	end
	if type(fn) ~= "function" then
		error("task : fonction ou thread attendu, reçu " .. typeOf(fn), 3)
	end
	local thread = coroutine.create(fn)
	ownThreads[thread] = true
	return thread
end

-- Le fil courant peut-il attendre en rendant la main au planificateur ? (oui pour les fils créés par task.spawn,
-- les handlers de signaux... ; non pour le fil principal du test, même dans un pcall : il fait avancer le temps)
local function canYield(): boolean
	return coroutine.isyieldable() and ownThreads[coroutine.running()] == true
end
env.canYield = canYield

local function runDeferred()
	local rounds = 0
	while #deferred > 0 do
		local batch = deferred
		deferred = {}
		for _, item in batch do
			resume(item.Thread, table.unpack(item.Args, 1, item.Args.n))
		end
		rounds += 1
		if rounds > 10000 then
			error("env : boucle de task.defer sans fin")
		end
	end
end

local function runTimers()
	while timers[1] and timers[1].At <= now + 1e-9 do
		local item = table.remove(timers, 1)
		resume(item.Thread, table.unpack(item.Args, 1, item.Args.n))
		runDeferred()
	end
end

local fireSignal: (any, ...any) -> ()

local function hasFrameListeners(): boolean
	for _, signal in heartbeatSignals do
		if #signal._conns > 0 or #signal._waiting > 0 then
			return true
		end
	end
	return false
end

local function step(dt: number)
	now += dt
	runTimers()
	for _, signal in heartbeatSignals do
		if signal._name == "Stepped" then
			fireSignal(signal, now, dt)
		elseif signal._name ~= "RenderStepped" or env.side == "client" or env.localPlayer ~= nil then
			fireSignal(signal, dt)
		end
	end
	runDeferred()
end

local function runUntil(target: number)
	runTimers()
	runDeferred()
	while now < target - 1e-9 do
		local dt = math.min(env.frame, target - now)
		if not hasFrameListeners() then
			-- personne n'écoute les images : on saute directement au prochain minuteur
			local nextAt = if timers[1] then timers[1].At else target
			dt = math.max(math.min(nextAt, target) - now, 0)
			if dt == 0 then
				runTimers()
				runDeferred()
				continue
			end
		end
		step(dt)
	end
	-- (les erreurs d'arrondi ne doivent jamais bloquer le temps juste avant la cible)
	if now < target then
		now = target
	end
	runTimers()
	runDeferred()
end

-- Avance le temps virtuel de `seconds` (minuteurs, task.wait, Heartbeat...)
function env.advance(seconds: number?)
	runUntil(now + (seconds or 0))
end

-- Exécute ce qui attend sans avancer le temps (task.defer, minuteurs échus)
function env.flush()
	runTimers()
	runDeferred()
end

function env.now(): number
	return now
end

-- Fait avancer le temps (fil principal) jusqu'à ce que `condition()` soit vraie ; erreur au bout de `limit` secondes
local function waitUntil(condition: () -> boolean, what: string, limit: number?)
	local deadline = now + (limit or 120)
	while not condition() do
		if now >= deadline - 1e-9 then
			error("env : attente sans fin (" .. what .. ")", 3)
		end
		runUntil(math.min(now + env.frame, deadline))
	end
end
env.waitUntil = waitUntil

local Task = {}
function Task.spawn(fn: any, ...: any): thread
	local thread = toThread(fn)
	resume(thread, ...)
	return thread
end
function Task.defer(fn: any, ...: any): thread
	local thread = toThread(fn)
	table.insert(deferred, { Thread = thread, Args = table.pack(...) })
	return thread
end
function Task.delay(seconds: number?, fn: any, ...: any): thread
	local thread = toThread(fn)
	schedule(now + math.max(tonumber(seconds) or 0, 0), thread, ...)
	return thread
end
function Task.wait(seconds: number?): number
	local duration = math.max(tonumber(seconds) or 0, 0)
	local start = now
	if canYield() then
		schedule(now + math.max(duration, 1e-6), coroutine.running())
		coroutine.yield()
	else
		runUntil(now + math.max(duration, env.frame))
	end
	return now - start
end
function Task.cancel(thread: thread)
	cancelled[thread] = true
	if coroutine.status(thread) == "suspended" then
		pcall(coroutine.close, thread)
	end
end
function Task.synchronize() end
function Task.desynchronize() end

-- os, tick, time avec le temps virtuel
local Os = {
	time = function(t: any?): number
		if t ~= nil then
			return nativeOs.time(t)
		end
		return env.baseTime + math.floor(now)
	end,
	clock = function(): number
		return now
	end,
	date = function(format: string?, t: number?): any
		return nativeOs.date(format or "%c", t or (env.baseTime + math.floor(now)))
	end,
	difftime = nativeOs.difftime,
}

-- ===== Signaux (RBXScriptSignal) =====

local SignalMeta: any = { __type = "RBXScriptSignal" }
SignalMeta.__index = SignalMeta
local ConnectionMeta: any = { __type = "RBXScriptConnection" }
ConnectionMeta.__index = ConnectionMeta

-- Côté du code qui appelle : le premier fichier de src/client/ ou src/server/ dans la pile, sinon env.side. Un même
-- test peut ainsi faire tourner le serveur et le client (FireClient depuis le serveur, FireServer depuis le client).
local function currentSide(): string
	for level = 3, 60 do
		local source = debug.info(level, "s")
		if source == nil then
			break
		end
		if string.find(source, "src/client/", 1, true) then
			return "client"
		elseif string.find(source, "src/server/", 1, true) then
			return "server"
		end
	end
	return env.side
end
env.currentSide = currentSide

local function newSignal(name: string): any
	return setmetatable({ _name = name, _conns = {}, _waiting = {} }, SignalMeta)
end
env.newSignal = newSignal

function ConnectionMeta:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._conns
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

function SignalMeta:Connect(fn: any): any
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	local connection = setmetatable({ Connected = true, _signal = self, _fn = fn }, ConnectionMeta)
	table.insert(self._conns, connection)
	return connection
end
SignalMeta.ConnectParallel = SignalMeta.Connect

function SignalMeta:Once(fn: any): any
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function SignalMeta:Wait(): ...any
	if canYield() then
		table.insert(self._waiting, coroutine.running())
		return coroutine.yield()
	end
	local fired, result = false, nil
	local connection = self:Connect(function(...)
		fired = true
		result = table.pack(...)
	end)
	waitUntil(function()
		return fired
	end, "Wait sur " .. self._name)
	connection:Disconnect()
	return table.unpack(result, 1, result.n)
end

fireSignal = function(signal: any, ...: any)
	for _, connection in table.clone(signal._conns) do
		if connection.Connected then
			Task.spawn(connection._fn, ...)
		end
	end
	if #signal._waiting > 0 then
		local waiting = signal._waiting
		signal._waiting = {}
		for _, thread in waiting do
			resume(thread, ...)
		end
	end
end
env.fire = fireSignal

-- ===== Enum =====

local enumCache: { [string]: any } = {}
local EnumItemMeta: any = { __type = "EnumItem" }
local EnumMeta: any = { __type = "Enum" }

EnumItemMeta.__index = function(self, key)
	if key == "IsA" then
		return function(item, name)
			return rawget(item, "_enumName") == name
		end
	end
	error(string.format("%s is not a valid member of EnumItem", tostring(key)), 2)
end
EnumItemMeta.__newindex = function()
	error("EnumItem est en lecture seule", 2)
end
EnumItemMeta.__tostring = function(self)
	return "Enum." .. self._enumName .. "." .. self.Name
end

local function getEnum(name: string): any
	local cached = enumCache[name]
	if cached then
		return cached
	end
	local items = api.Enums[name]
	if not items then
		return nil
	end
	local enum = setmetatable({ _name = name, _items = {}, _list = {} }, EnumMeta)
	enumCache[name] = enum
	for index, itemName in items do
		local item = setmetatable({ Name = itemName, Value = index - 1, EnumType = enum, _enumName = name }, EnumItemMeta)
		enum._items[itemName] = item
		table.insert(enum._list, item)
	end
	return enum
end

EnumMeta.__index = function(self, key)
	local item = self._items[key]
	if item then
		return item
	end
	if key == "GetEnumItems" then
		return function(enum)
			return table.clone(enum._list)
		end
	elseif key == "FromName" then
		return function(enum, name)
			return enum._items[name]
		end
	elseif key == "FromValue" then
		return function(enum, value)
			for _, candidate in enum._list do
				if candidate.Value == value then
					return candidate
				end
			end
			return nil
		end
	end
	error(string.format("%s is not a valid member of \"Enum.%s\"", tostring(key), self._name), 2)
end
EnumMeta.__tostring = function(self)
	return self._name
end

local Enum = setmetatable({}, {
	__type = "Enums",
	__index = function(_, name)
		local enum = getEnum(name)
		if not enum then
			error(string.format("%s is not a valid member of \"Enum\"", tostring(name)), 2)
		end
		return enum
	end,
})

local function isEnumItem(value: any): boolean
	return type(value) == "table" and getmetatable(value) == EnumItemMeta
end

-- ===== Types de données qui ont besoin des Enums =====

local TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delayTime)
		return D.makeTweenInfo({
			Time = time or 1,
			EasingStyle = style or Enum.EasingStyle.Quad,
			EasingDirection = direction or Enum.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
		})
	end,
}

local FontType = {
	new = function(family, weight, style)
		return D.makeFont({ Family = family, Weight = weight or Enum.FontWeight.Regular, Style = style or Enum.FontStyle.Normal, Bold = weight == Enum.FontWeight.Bold })
	end,
	fromEnum = function(font)
		if not isEnumItem(font) then
			error("Font.fromEnum : EnumItem attendu", 2)
		end
		return D.makeFont({ Family = "rbxasset://fonts/families/" .. font.Name .. ".json", Weight = Enum.FontWeight.Regular, Style = Enum.FontStyle.Normal, Bold = false })
	end,
	fromName = function(name, weight, style)
		return D.makeFont({ Family = "rbxasset://fonts/families/" .. name .. ".json", Weight = weight or Enum.FontWeight.Regular, Style = style or Enum.FontStyle.Normal, Bold = false })
	end,
	fromId = function(id, weight, style)
		return D.makeFont({ Family = "rbxassetid://" .. tostring(id), Weight = weight or Enum.FontWeight.Regular, Style = style or Enum.FontStyle.Normal, Bold = false })
	end,
}

local DateTimeMeta: any = { __type = "DateTime" }
DateTimeMeta.__index = DateTimeMeta
function DateTimeMeta:ToUniversalTime()
	local t = nativeOs.date("!*t", math.floor(self.UnixTimestamp))
	return { Year = t.year, Month = t.month, Day = t.day, Hour = t.hour, Minute = t.min, Second = t.sec, Millisecond = 0 }
end
DateTimeMeta.ToLocalTime = DateTimeMeta.ToUniversalTime
function DateTimeMeta:FormatUniversalTime(_format)
	return nativeOs.date("!%Y-%m-%d %H:%M:%S", math.floor(self.UnixTimestamp))
end
local function dateTime(seconds: number): any
	return setmetatable({ UnixTimestamp = math.floor(seconds), UnixTimestampMillis = math.floor(seconds * 1000) }, DateTimeMeta)
end
local DateTime = {
	now = function()
		return dateTime(env.baseTime + now)
	end,
	fromUnixTimestamp = function(seconds)
		return dateTime(seconds)
	end,
	fromUnixTimestampMillis = function(ms)
		return dateTime(ms / 1000)
	end,
}

-- ===== Instances =====

local Data: { [any]: any } = setmetatable({}, { __mode = "k" })
local InstanceMeta: any = { __type = "Instance" }
local classCache: { [string]: any } = {}
local Methods: { [string]: { [string]: any } } = {} -- [classe][méthode] = fonction simulée
local Getters: { [string]: { [string]: any } } = {} -- propriétés calculées
local Setters: { [string]: { [string]: any } } = {}
local Init: { [string]: any } = {} -- [classe] = function(instance, state) à la création

local DATATYPES = {
	Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim = true, UDim2 = true, ColorSequence = true,
	NumberSequence = true, NumberRange = true, Rect = true, Font = true, BrickColor = true, PhysicalProperties = true,
	Faces = true, Axes = true, Ray = true, TweenInfo = true, Region3 = true, Vector3int16 = true, Vector2int16 = true,
}

-- Propriétés en lecture seule (le jeu ne peut pas les écrire)
local READ_ONLY = {
	AbsoluteSize = true, AbsolutePosition = true, AbsoluteRotation = true, AbsoluteContentSize = true, TextBounds = true,
	ContentText = true, TextFits = true, UserId = true, ViewportSize = true, ClassName = true, AccountAge = true,
	MembershipType = true, JobId = true, PlaceId = true, GameId = true, CreatorId = true, CreatorType = true,
	PlaceVersion = true, PlaybackState = true, IsLoaded = true, TimeLength = true, CanvasPosition = false,
}

local function classInfo(name: string): any
	local cached = classCache[name]
	if cached then
		return cached
	end
	if not api.Classes[name] then
		return nil
	end
	local info = { Name = name, Props = {}, Events = {}, Methods = {}, Callbacks = {}, Chain = {}, IsA = {} }
	local current = name
	while current and current ~= "" do
		local def = api.Classes[current]
		if not def then
			break
		end
		table.insert(info.Chain, current)
		info.IsA[current] = true
		for key, valueType in def.Properties do
			if info.Props[key] == nil then
				info.Props[key] = valueType
			end
		end
		for _, event in def.Events do
			info.Events[event] = true
		end
		for _, method in def.Methods do
			info.Methods[method] = true
		end
		for _, callback in def.Callbacks do
			info.Callbacks[callback] = true
		end
		current = def.Superclass
	end
	info.IsA.Object = true
	classCache[name] = info
	return info
end
env.classInfo = classInfo

local function findInChain(registry: { [string]: { [string]: any } }, info: any, key: string): any
	for _, className in info.Chain do
		local entries = registry[className]
		if entries and entries[key] ~= nil then
			return entries[key]
		end
	end
	return nil
end

local function isInstance(value: any): boolean
	return type(value) == "table" and getmetatable(value) == InstanceMeta
end
env.isInstance = isInstance

local function fullName(inst: any): string
	local names = {}
	local current = inst
	while current do
		local state = Data[current]
		if state.Class == "DataModel" then
			break
		end
		table.insert(names, 1, state.Props.Name)
		current = state.Parent
	end
	return table.concat(names, ".")
end

-- Valeurs par défaut (proches de celles de Roblox pour ce qui compte dans les tests)
local DEFAULTS: { [string]: { [string]: any } } = {
	GuiObject = {
		Visible = true, BackgroundTransparency = 0, BorderSizePixel = 1, ZIndex = 1,
		BackgroundColor3 = D.Color3.fromRGB(163, 162, 165), BorderColor3 = D.Color3.fromRGB(27, 42, 53),
		-- (enums : la valeur par défaut de Roblox, pas la première par ordre alphabétique)
		SizeConstraint = "RelativeXY", AutomaticSize = "None", BorderMode = "Outline",
	},
	ScrollingFrame = { ScrollingDirection = "XY", ScrollBarThickness = 12, CanvasSize = D.UDim2.new(0, 0, 2, 0), ScrollingEnabled = true, AutomaticCanvasSize = "None", ElasticBehavior = "WhenScrollable", VerticalScrollBarPosition = "Right" },
	LayerCollector = { Enabled = true, ResetOnSpawn = true },
	ScreenGui = { ZIndexBehavior = "Sibling", ScreenInsets = "CoreUISafeInsets" },
	TextLabel = { Text = "Label", TextColor3 = D.Color3.fromRGB(27, 42, 53), TextSize = 14, TextStrokeTransparency = 1, TextXAlignment = "Center", TextYAlignment = "Center", Font = "Legacy" },
	TextButton = { Text = "Button", TextColor3 = D.Color3.fromRGB(27, 42, 53), TextSize = 14, TextStrokeTransparency = 1, AutoButtonColor = true, Font = "Legacy", TextXAlignment = "Center", TextYAlignment = "Center" },
	TextBox = { TextColor3 = D.Color3.fromRGB(27, 42, 53), TextSize = 14, TextStrokeTransparency = 1, Font = "Legacy", TextXAlignment = "Center", TextYAlignment = "Center" },
	ImageLabel = { ImageColor3 = D.Color3.new(1, 1, 1), ScaleType = "Stretch", TileSize = D.UDim2.fromScale(1, 1) },
	ImageButton = { ImageColor3 = D.Color3.new(1, 1, 1), ScaleType = "Stretch", TileSize = D.UDim2.fromScale(1, 1), AutoButtonColor = true },
	UIStroke = { Color = D.Color3.new(0, 0, 0), Thickness = 1, Enabled = true, ApplyStrokeMode = "Contextual", LineJoinMode = "Round" },
	UIScale = { Scale = 1 },
	UICorner = { CornerRadius = D.UDim.new(0, 8) },
	UIGradient = { Enabled = true },
	UITextSizeConstraint = { MaxTextSize = 100, MinTextSize = 1 },
	UISizeConstraint = { MaxSize = D.Vector2.new(math.huge, math.huge) },
	UIAspectRatioConstraint = { AspectRatio = 1, AspectType = "FitWithinMaxSize", DominantAxis = "Width" },
	UIListLayout = { FillDirection = "Vertical", SortOrder = "LayoutOrder", HorizontalAlignment = "Left", VerticalAlignment = "Top" },
	UIGridLayout = {
		FillDirection = "Horizontal", SortOrder = "LayoutOrder", HorizontalAlignment = "Left", VerticalAlignment = "Top", StartCorner = "TopLeft",
		CellSize = D.UDim2.fromOffset(100, 100), CellPadding = D.UDim2.fromOffset(5, 5),
	},
	BasePart = { Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, Size = D.Vector3.new(4, 1, 2), Color = D.Color3.fromRGB(163, 162, 165), Material = "Plastic", CastShadow = true },
	Humanoid = { WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, Health = 100, MaxHealth = 100, AutoRotate = true },
	Sound = { Volume = 0.5, PlaybackSpeed = 1, RollOffMaxDistance = 10000 },
	Camera = { FieldOfView = 70 },
	Light = { Enabled = true, Brightness = 1 },
	ParticleEmitter = { Enabled = true },
	Beam = { Enabled = true },
	Trail = { Enabled = true },
	Attachment = { Visible = false },
	Workspace = { Gravity = 196.2 },
	Player = { DisplayName = "" },
	DataModel = { JobId = "env-job", PlaceId = 0, GameId = 0, CreatorId = 0, CreatorType = "User", PlaceVersion = 0 },
	UserInputService = { KeyboardEnabled = true, MouseEnabled = true },
	ProximityPrompt = { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10, RequiresLineOfSight = true },
	ClickDetector = { MaxActivationDistance = 32 },
	SpawnLocation = { Enabled = true },
	Model = {},
	Tween = { PlaybackState = "Begin" },
}

local function defaultFor(info: any, key: string, valueType: string): any
	for _, className in info.Chain do
		local defaults = DEFAULTS[className]
		if defaults and defaults[key] ~= nil then
			local value = defaults[key]
			if type(value) == "string" and string.sub(valueType, 1, 4) == "Enum" then
				return Enum[string.sub(valueType, 5)][value]
			end
			return value
		end
	end
	local base = if string.sub(valueType, -1) == "?" then nil else valueType
	if base == "number" then
		return 0
	elseif base == "string" or base == "ContentId" or base == "ProtectedString" then
		return if key == "Name" then info.Name else ""
	elseif base == "boolean" then
		return false
	elseif base == "Vector3" or base == "Vector3int16" then
		return D.Vector3.zero
	elseif base == "Vector2" or base == "Vector2int16" then
		return D.Vector2.zero
	elseif base == "CFrame" then
		return D.CFrame.identity
	elseif base == "Color3" then
		return D.Color3.new(1, 1, 1)
	elseif base == "UDim" then
		return D.UDim.new(0, 0)
	elseif base == "UDim2" then
		return D.UDim2.new(0, 0, 0, 0)
	elseif base == "ColorSequence" then
		return D.ColorSequence.new(D.Color3.new(1, 1, 1))
	elseif base == "NumberSequence" then
		return D.NumberSequence.new(0)
	elseif base == "NumberRange" then
		return D.NumberRange.new(0)
	elseif base == "Rect" then
		return D.Rect.new(0, 0, 0, 0)
	elseif base == "Font" then
		return FontType.fromEnum(Enum.Font.Legacy)
	elseif base == "Content" then
		return D.Content.none
	elseif base and string.sub(base, 1, 4) == "Enum" and api.Enums[string.sub(base, 5)] then
		return Enum[string.sub(base, 5)]:GetEnumItems()[1]
	end
	return nil
end

-- Vérifie (et convertit comme Roblox) une valeur pour une propriété ; erreur si le type ne va pas
local function coerce(state: any, key: string, valueType: string, value: any): any
	local optional = string.sub(valueType, -1) == "?"
	local base = if optional then string.sub(valueType, 1, -2) else valueType
	local function bad(expected: string)
		error(string.format("Unable to assign property %s. %s expected, got %s (%s.%s)", key, expected, typeOf(value), state.Class, key), 4)
	end
	if base == "number" then
		if type(value) == "number" then
			return value
		elseif type(value) == "string" and tonumber(value) then
			return tonumber(value)
		end
		bad("number")
	elseif base == "string" or base == "ContentId" or base == "ProtectedString" then
		if type(value) == "string" then
			return value
		elseif type(value) == "number" then
			return tostring(value)
		end
		bad("string")
	elseif base == "boolean" then
		if type(value) == "boolean" then
			return value
		end
		bad("bool")
	elseif base == "Content" then
		if type(value) == "string" or typeOf(value) == "Content" then
			return value
		end
		bad("Content")
	elseif string.sub(base, 1, 4) == "Enum" and api.Enums[string.sub(base, 5)] then
		local enum = Enum[string.sub(base, 5)]
		if isEnumItem(value) then
			if value.EnumType == enum then
				return value
			end
			bad("Enum." .. enum._name)
		elseif type(value) == "string" then
			local item = enum._items[value]
			if item then
				return item
			end
		elseif type(value) == "number" then
			local item = enum:FromValue(value)
			if item then
				return item
			end
		end
		bad("Enum." .. enum._name)
	elseif DATATYPES[base] then
		if typeOf(value) == base then
			return value
		end
		if value == nil and optional then
			return nil
		end
		bad(base)
	elseif api.Classes[base] then
		if value == nil or (isInstance(value) and value:IsA(base)) then
			return value
		end
		bad(base)
	end
	return value
end

local function getSignal(inst: any, key: string): any
	local state = Data[inst]
	local signal = state.Signals[key]
	if not signal then
		signal = newSignal(key)
		state.Signals[key] = signal
	end
	return signal
end
env.signal = getSignal

local function fireChanged(inst: any, key: string)
	local state = Data[inst]
	local changed = state.Signals.Changed
	if changed then
		fireSignal(changed, key)
	end
	local propSignal = state.Signals["prop:" .. key]
	if propSignal then
		fireSignal(propSignal)
	end
end

local function methodFor(info: any, key: string): any
	local custom = findInChain(Methods, info, key)
	if custom then
		return custom
	end
	if info.Methods[key] then
		return function()
			error(string.format("env : %s:%s n'est pas simulé (ajouter env.stubMethod(%q, %q, fonction) dans le test)", info.Name, key, info.Name, key), 2)
		end
	end
	return nil
end

InstanceMeta.__index = function(self, key)
	local state = Data[self]
	if key == "Parent" then
		return state.Parent
	elseif key == "ClassName" then
		return state.Class
	end
	local info = state.Info
	local valueType = info.Props[key]
	if valueType ~= nil then
		local getter = findInChain(Getters, info, key)
		if getter then
			return getter(self, state)
		end
		local value = state.Props[key]
		if value == nil and state.Props[key] == nil and not state.Nil[key] then
			value = defaultFor(info, key, valueType)
		end
		return value
	end
	if info.Events[key] then
		return getSignal(self, key)
	end
	if info.Callbacks[key] then
		error(string.format("%s is a callback member of %s; you can only set the callback value, get is not available (env.callback)", key, state.Class), 2)
	end
	local method = methodFor(info, key)
	if method then
		return method
	end
	if type(key) == "string" then
		for _, child in state.Children do
			if Data[child].Props.Name == key then
				return child
			end
		end
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), state.Class, fullName(self)), 2)
end

InstanceMeta.__tostring = function(self)
	return Data[self].Props.Name
end

local setParent: (any, any) -> ()

InstanceMeta.__newindex = function(self, key, value)
	local state = Data[self]
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local info = state.Info
	local valueType = info.Props[key]
	if valueType ~= nil then
		if READ_ONLY[key] then
			error(string.format("Unable to assign property %s. Property is read only", key), 2)
		end
		local converted = coerce(state, key, valueType, value)
		local setter = findInChain(Setters, info, key)
		if setter then
			setter(self, state, converted)
			return
		end
		local old = self[key]
		state.Props[key] = converted
		state.Nil[key] = converted == nil or nil
		if old ~= converted then
			fireChanged(self, key)
		end
		return
	end
	if info.Callbacks[key] then
		if value ~= nil and type(value) ~= "function" then
			error(string.format("Unable to assign property %s. function expected, got %s", key, typeOf(value)), 2)
		end
		state.Props[key] = value
		return
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), state.Class, fullName(self)), 2)
end

-- Écrit une propriété sans contrôle (propriétés en lecture seule, simulation)
function env.setProperty(inst: any, key: string, value: any)
	local state = Data[inst]
	local old = state.Props[key]
	state.Props[key] = value
	state.Nil[key] = value == nil or nil
	if old ~= value then
		fireChanged(inst, key)
	end
end

-- Fonction posée sur un callback (ProcessReceipt, OnServerInvoke, OnInvoke...)
function env.callback(inst: any, key: string): any
	return Data[inst].Props[key]
end

local SERVICES = {
	Players = true, Workspace = true, ReplicatedStorage = true, ServerScriptService = true, ServerStorage = true,
	StarterGui = true, StarterPack = true, StarterPlayer = true, Lighting = true, SoundService = true, Teams = true,
	Chat = true, TextChatService = true, DataModel = true,
}

local function create(className: string, skipInit: boolean?): any
	local info = classInfo(className)
	if not info then
		error(string.format("Unable to create an Instance of type \"%s\"", tostring(className)), 3)
	end
	local inst = setmetatable({}, InstanceMeta)
	Data[inst] = {
		Class = className,
		Info = info,
		Props = { Name = className },
		Nil = {},
		Children = {},
		Parent = nil,
		Attributes = {},
		Signals = {},
		Tags = {},
		Destroyed = false,
		Extra = {},
	}
	if not skipInit then
		for index = #info.Chain, 1, -1 do
			local init = Init[info.Chain[index]]
			if init then
				init(inst, Data[inst])
			end
		end
	end
	return inst
end
env.create = create

local function ancestorsOf(inst: any): { any }
	local list = {}
	local current = Data[inst].Parent
	while current do
		table.insert(list, current)
		current = Data[current].Parent
	end
	return list
end

local function descendantsOf(inst: any, out: { any }): { any }
	for _, child in Data[inst].Children do
		table.insert(out, child)
		descendantsOf(child, out)
	end
	return out
end

setParent = function(inst: any, newParent: any)
	local state = Data[inst]
	if state.Destroyed then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", state.Props.Name, if newParent then Data[newParent].Props.Name else "NULL"), 3)
	end
	if newParent ~= nil and not isInstance(newParent) then
		error("Unable to assign property Parent. Instance expected, got " .. typeOf(newParent), 3)
	end
	local oldParent = state.Parent
	if oldParent == newParent then
		return
	end
	if newParent ~= nil then
		if newParent == inst or table.find(ancestorsOf(newParent), inst) then
			error(string.format("Attempt to set %s as its own parent", fullName(inst)), 3)
		end
	end
	local moving = descendantsOf(inst, { inst })
	if oldParent then
		local oldState = Data[oldParent]
		local index = table.find(oldState.Children, inst)
		if index then
			table.remove(oldState.Children, index)
		end
		for _, ancestor in { oldParent, table.unpack(ancestorsOf(oldParent)) } do
			local signal = Data[ancestor].Signals.DescendantRemoving
			if signal then
				for _, item in moving do
					fireSignal(signal, item)
				end
			end
		end
		local removed = oldState.Signals.ChildRemoved
		if removed then
			fireSignal(removed, inst)
		end
	end
	state.Parent = newParent
	if newParent then
		table.insert(Data[newParent].Children, inst)
		local added = Data[newParent].Signals.ChildAdded
		if added then
			fireSignal(added, inst)
		end
		for _, ancestor in { newParent, table.unpack(ancestorsOf(newParent)) } do
			local signal = Data[ancestor].Signals.DescendantAdded
			if signal then
				for _, item in moving do
					fireSignal(signal, item)
				end
			end
		end
	end
	for _, item in moving do
		local signal = Data[item].Signals.AncestryChanged
		if signal then
			fireSignal(signal, inst, newParent)
		end
	end
	fireChanged(inst, "Parent")
end

local function destroy(inst: any)
	local state = Data[inst]
	if state.Destroyed then
		return
	end
	local destroying = state.Signals.Destroying
	if destroying then
		fireSignal(destroying)
	end
	for _, child in table.clone(state.Children) do
		destroy(child)
	end
	if state.Parent then
		setParent(inst, nil)
	end
	state.Destroyed = true
	for _, signal in state.Signals do
		for _, connection in table.clone(signal._conns) do
			connection:Disconnect()
		end
	end
	for tag in state.Tags do
		env.removeTag(inst, tag)
	end
end

local function findChild(inst: any, test: (any) -> boolean, recursive: boolean?): any
	for _, child in Data[inst].Children do
		if test(child) then
			return child
		end
	end
	if recursive then
		for _, child in Data[inst].Children do
			local found = findChild(child, test, true)
			if found then
				return found
			end
		end
	end
	return nil
end

local function checkSelf(self: any, method: string)
	if not isInstance(self) then
		error(string.format("Expected ':' not '.' calling member function %s", method), 3)
	end
end

local function setAttribute(inst: any, name: string, value: any)
	if type(name) ~= "string" or #name > 100 or not string.match(name, "^[%w_]+$") or string.sub(name, 1, 3) == "RBX" then
		error("Attribute name " .. quote(name) .. " is invalid", 3)
	end
	local kind = typeOf(value)
	local allowed = {
		["nil"] = true, boolean = true, number = true, string = true, UDim = true, UDim2 = true, BrickColor = true,
		Color3 = true, Vector2 = true, Vector3 = true, CFrame = true, NumberSequence = true, ColorSequence = true,
		NumberRange = true, Rect = true, Font = true, EnumItem = true,
	}
	if not allowed[kind] then
		error(string.format("%s is not a supported attribute type", kind), 3)
	end
	local state = Data[inst]
	local old = state.Attributes[name]
	state.Attributes[name] = value
	if old ~= value then
		local signal = state.Signals["attr:" .. name]
		if signal then
			fireSignal(signal)
		end
		local any = state.Signals.AttributeChanged
		if any then
			fireSignal(any, name)
		end
	end
end
env.setAttribute = setAttribute

-- Tags (CollectionService et Instance:AddTag)
local tagged: { [string]: { any } } = {}
local tagSignals: { [string]: any } = {}
local function tagSignal(kind: string, tag: string): any
	local key = kind .. ":" .. tag
	local signal = tagSignals[key]
	if not signal then
		signal = newSignal(key)
		tagSignals[key] = signal
	end
	return signal
end
function env.addTag(inst: any, tag: string)
	local state = Data[inst]
	if state.Tags[tag] then
		return
	end
	state.Tags[tag] = true
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], inst)
	fireSignal(tagSignal("added", tag), inst)
end
function env.removeTag(inst: any, tag: string)
	local state = Data[inst]
	if not state.Tags[tag] then
		return
	end
	state.Tags[tag] = nil
	local list = tagged[tag]
	local index = list and table.find(list, inst)
	if index then
		table.remove(list, index)
	end
	fireSignal(tagSignal("removed", tag), inst)
end

local function cloneInstance(inst: any): any
	local state = Data[inst]
	if state.Props.Archivable == false then
		return nil
	end
	local copy = create(state.Class, true)
	local copyState = Data[copy]
	for key, value in state.Props do
		copyState.Props[key] = value
	end
	for key in state.Nil do
		copyState.Nil[key] = true
	end
	for key, value in state.Attributes do
		copyState.Attributes[key] = value
	end
	for key, value in state.Extra do
		copyState.Extra[key] = value
	end
	for tag in state.Tags do
		env.addTag(copy, tag)
	end
	for _, child in state.Children do
		local childCopy = cloneInstance(child)
		if childCopy then
			setParent(childCopy, copy)
		end
	end
	return copy
end

-- Méthodes communes (Object, Instance)
Methods.Object = {
	IsA = function(self, className)
		checkSelf(self, "IsA")
		return Data[self].Info.IsA[className] == true
	end,
	GetPropertyChangedSignal = function(self, property)
		checkSelf(self, "GetPropertyChangedSignal")
		local info = Data[self].Info
		if info.Props[property] == nil and property ~= "Parent" and property ~= "Name" then
			error(string.format("%s is not a valid property name.", tostring(property)), 2)
		end
		return getSignal(self, "prop:" .. property)
	end,
}

Methods.Instance = {
	FindFirstChild = function(self, name, recursive)
		checkSelf(self, "FindFirstChild")
		return findChild(self, function(child)
			return Data[child].Props.Name == name
		end, recursive)
	end,
	FindFirstChildOfClass = function(self, className)
		return findChild(self, function(child)
			return Data[child].Class == className
		end)
	end,
	FindFirstChildWhichIsA = function(self, className, recursive)
		return findChild(self, function(child)
			return Data[child].Info.IsA[className] == true
		end, recursive)
	end,
	FindFirstDescendant = function(self, name)
		return findChild(self, function(child)
			return Data[child].Props.Name == name
		end, true)
	end,
	FindFirstAncestor = function(self, name)
		for _, ancestor in ancestorsOf(self) do
			if Data[ancestor].Props.Name == name then
				return ancestor
			end
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, className)
		for _, ancestor in ancestorsOf(self) do
			if Data[ancestor].Class == className then
				return ancestor
			end
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, className)
		for _, ancestor in ancestorsOf(self) do
			if Data[ancestor].Info.IsA[className] then
				return ancestor
			end
		end
		return nil
	end,
	WaitForChild = function(self, name, timeout)
		checkSelf(self, "WaitForChild")
		local found = self:FindFirstChild(name)
		if found then
			return found
		end
		if canYield() then
			local thread = coroutine.running()
			local done = false
			local connection
			connection = getSignal(self, "ChildAdded"):Connect(function(child)
				if not done and Data[child].Props.Name == name then
					done = true
					connection:Disconnect()
					resume(thread, child)
				end
			end)
			if timeout then
				Task.delay(timeout, function()
					if not done then
						done = true
						connection:Disconnect()
						resume(thread, nil)
					end
				end)
			else
				Task.delay(5, function()
					if not done then
						warn(string.format("Infinite yield possible on '%s:WaitForChild(\"%s\")'", fullName(self), name))
					end
				end)
			end
			return coroutine.yield()
		end
		local limit = timeout or 60
		local deadline = now + limit
		while not self:FindFirstChild(name) and now < deadline do
			runUntil(math.min(now + env.frame, deadline))
		end
		local result = self:FindFirstChild(name)
		if not result and not timeout then
			error(string.format("env : WaitForChild(\"%s\") sur %s sans fin (fil principal)", name, fullName(self)), 2)
		end
		return result
	end,
	GetChildren = function(self)
		checkSelf(self, "GetChildren")
		return table.clone(Data[self].Children)
	end,
	GetDescendants = function(self)
		return descendantsOf(self, {})
	end,
	IsDescendantOf = function(self, ancestor)
		return table.find(ancestorsOf(self), ancestor) ~= nil
	end,
	IsAncestorOf = function(self, descendant)
		return table.find(ancestorsOf(descendant), self) ~= nil
	end,
	Destroy = function(self)
		checkSelf(self, "Destroy")
		destroy(self)
	end,
	ClearAllChildren = function(self)
		for _, child in table.clone(Data[self].Children) do
			destroy(child)
		end
	end,
	Clone = function(self)
		return cloneInstance(self)
	end,
	GetFullName = function(self)
		return fullName(self)
	end,
	SetAttribute = function(self, name, value)
		checkSelf(self, "SetAttribute")
		setAttribute(self, name, value)
	end,
	GetAttribute = function(self, name)
		return Data[self].Attributes[name]
	end,
	GetAttributes = function(self)
		return table.clone(Data[self].Attributes)
	end,
	GetAttributeChangedSignal = function(self, name)
		return getSignal(self, "attr:" .. name)
	end,
	AddTag = function(self, tag)
		env.addTag(self, tag)
	end,
	RemoveTag = function(self, tag)
		env.removeTag(self, tag)
	end,
	HasTag = function(self, tag)
		return Data[self].Tags[tag] == true
	end,
	GetTags = function(self)
		local list = {}
		for tag in Data[self].Tags do
			table.insert(list, tag)
		end
		return list
	end,
	GetActor = function()
		return nil
	end,
	GetDebugId = function(self)
		return tostring(self)
	end,
	IsPropertyModified = function(self, property)
		return Data[self].Props[property] ~= nil
	end,
}

-- ===== Mise en page simplifiée des interfaces =====

local function guiScale(inst: any): number
	local scale = 1
	for _, child in Data[inst].Children do
		if Data[child].Class == "UIScale" then
			scale *= child.Scale
		end
	end
	return scale
end

local absoluteSizeOf: (any) -> any
absoluteSizeOf = function(inst: any): any
	local state = Data[inst]
	if state.Info.IsA.LayerCollector then
		return env.viewportSize()
	end
	if not state.Info.IsA.GuiObject then
		return D.Vector2.zero
	end
	local parent = state.Parent
	local parentSize = if parent and Data[parent].Info.IsA.GuiBase2d then absoluteSizeOf(parent) else D.Vector2.zero
	local inherited = 1
	local current = parent
	while current and Data[current].Info.IsA.GuiObject do
		inherited *= guiScale(current)
		current = Data[current].Parent
	end
	local size = inst.Size
	local own = guiScale(inst)
	return D.Vector2.new(
		(parentSize.X * size.X.Scale + size.X.Offset * inherited) * own,
		(parentSize.Y * size.Y.Scale + size.Y.Offset * inherited) * own
	)
end
Getters.GuiBase2d = {
	AbsoluteSize = function(self)
		return absoluteSizeOf(self)
	end,
	AbsolutePosition = function()
		return D.Vector2.zero
	end,
}
Getters.TextLabel = {
	TextBounds = function(self)
		return D.Vector2.new(#self.Text * self.TextSize * 0.5, self.TextSize)
	end,
	ContentText = function(self)
		return self.Text
	end,
}
Getters.TextButton = Getters.TextLabel
Getters.TextBox = Getters.TextLabel

-- Parties : Position, Orientation et CFrame liés
Getters.BasePart = {
	Position = function(self, state)
		return (state.Props.CFrame or D.CFrame.identity).Position
	end,
	Orientation = function(self, state)
		local x, y, z = (state.Props.CFrame or D.CFrame.identity):ToOrientation()
		return D.Vector3.new(math.deg(x), math.deg(y), math.deg(z))
	end,
}
Setters.BasePart = {
	Position = function(self, state, value)
		local current = state.Props.CFrame or D.CFrame.identity
		state.Props.CFrame = current.Rotation + value
		fireChanged(self, "CFrame")
		fireChanged(self, "Position")
	end,
	CFrame = function(self, state, value)
		state.Props.CFrame = value
		fireChanged(self, "CFrame")
		fireChanged(self, "Position")
	end,
	Orientation = function(self, state, value)
		local current = state.Props.CFrame or D.CFrame.identity
		state.Props.CFrame = D.CFrame.new(current.Position) * D.CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
		fireChanged(self, "CFrame")
		fireChanged(self, "Orientation")
	end,
}
-- Attachments : liés de la même façon (CFrame relatif à la partie parente)
Getters.Attachment = Getters.BasePart
Setters.Attachment = Setters.BasePart

Methods.PVInstance = {
	GetPivot = function(self)
		if self:IsA("BasePart") then
			return self.CFrame
		end
		local state = Data[self]
		if state.Extra.Pivot then
			return state.Extra.Pivot
		end
		local primary = state.Props.PrimaryPart
		if primary then
			return primary.CFrame
		end
		return D.CFrame.identity
	end,
	PivotTo = function(self, target)
		local current = self:GetPivot()
		local delta = target * current:Inverse()
		if self:IsA("BasePart") then
			self.CFrame = target
		end
		for _, part in self:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = delta * part.CFrame
			end
		end
		if not self:IsA("BasePart") then
			Data[self].Extra.Pivot = target
		end
	end,
}
Methods.Model = {
	GetBoundingBox = function(self)
		local min, max = nil, nil
		for _, part in self:GetDescendants() do
			if part:IsA("BasePart") then
				local p, half = part.Position, part.Size / 2
				min = if min then min:Min(p - half) else p - half
				max = if max then max:Max(p + half) else p + half
			end
		end
		if not min then
			return self:GetPivot(), D.Vector3.zero
		end
		return D.CFrame.new((min + max) / 2), max - min
	end,
	GetExtentsSize = function(self)
		local _, size = self:GetBoundingBox()
		return size
	end,
	MoveTo = function(self, position)
		self:PivotTo(D.CFrame.new(position))
	end,
	GetScale = function(self)
		return Data[self].Extra.Scale or 1
	end,
	ScaleTo = function(self, scale)
		Data[self].Extra.Scale = scale
	end,
}
Methods.BasePart = {
	GetMass = function(self)
		local size = self.Size
		return size.X * size.Y * size.Z * 0.7
	end,
	ApplyImpulse = function() end,
	ApplyAngularImpulse = function() end,
	SetNetworkOwner = function() end,
	GetNetworkOwner = function()
		return nil
	end,
	CanSetNetworkOwnership = function()
		return true
	end,
	GetTouchingParts = function()
		return {}
	end,
	GetVelocityAtPosition = function()
		return D.Vector3.zero
	end,
}

-- ===== Valeurs, bindables =====

Methods.BindableEvent = {
	Fire = function(self, ...)
		fireSignal(getSignal(self, "Event"), ...)
	end,
}
Methods.BindableFunction = {
	Invoke = function(self, ...)
		local callback = Data[self].Props.OnInvoke
		if not callback then
			error("env : BindableFunction " .. fullName(self) .. " sans OnInvoke", 2)
		end
		return callback(...)
	end,
}

-- ===== Remotes (boucle locale) =====

-- Copie d'une valeur comme le réseau de Roblox : tables recopiées (sans métatable), fonctions perdues
local function netCopy(value: any, seen: { [any]: boolean }?): any
	if type(value) == "function" or type(value) == "thread" then
		return nil
	end
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		return value
	end
	local visited = seen or {}
	if visited[value] then
		error("env : table en boucle envoyée par un remote", 3)
	end
	visited[value] = true
	local copy = {}
	for key, item in value do
		local k = netCopy(key, visited)
		if k ~= nil then
			copy[k] = netCopy(item, visited)
		end
	end
	visited[value] = nil
	return copy
end
env.netCopy = netCopy

local function packCopy(...: any): any
	local args = table.pack(...)
	for index = 1, args.n do
		args[index] = netCopy(args[index])
	end
	return args
end

local function deliverToClient(remote: any, player: any, args: any)
	table.insert(env.sent, { Remote = Data[remote].Props.Name, Player = player, Args = args })
	if player == env.localPlayer then
		fireSignal(getSignal(remote, "OnClientEvent"), table.unpack(args, 1, args.n))
	end
end

local function checkPlayer(player: any, method: string)
	if not (isInstance(player) and Data[player].Class == "Player") then
		error(method .. " : Player attendu, reçu " .. typeOf(player), 3)
	end
end

local remoteEventMethods = {
	FireServer = function(self, ...)
		if currentSide() ~= "client" then
			error("FireServer can only be called from the client", 2)
		end
		if env.localPlayer then
			fireSignal(getSignal(self, "OnServerEvent"), env.localPlayer, table.unpack(packCopy(...)))
		end
	end,
	FireClient = function(self, player, ...)
		if currentSide() ~= "server" then
			error("FireClient can only be called from the server", 2)
		end
		checkPlayer(player, "FireClient")
		deliverToClient(self, player, packCopy(...))
	end,
	FireAllClients = function(self, ...)
		if currentSide() ~= "server" then
			error("FireAllClients can only be called from the server", 2)
		end
		for _, player in env.players() do
			deliverToClient(self, player, packCopy(...))
		end
	end,
}
Methods.RemoteEvent = remoteEventMethods
Methods.UnreliableRemoteEvent = remoteEventMethods

local function invokeServer(remote: any, player: any, ...: any): ...any
	local callback = Data[remote].Props.OnServerInvoke
	if not callback then
		error("env : " .. fullName(remote) .. " n'a pas de OnServerInvoke (un vrai client attendrait pour toujours)", 3)
	end
	local results = table.pack(callback(player, table.unpack(packCopy(...))))
	return table.unpack(packCopy(table.unpack(results, 1, results.n)))
end

Methods.RemoteFunction = {
	InvokeServer = function(self, ...)
		if currentSide() ~= "client" then
			error("InvokeServer can only be called from the client", 2)
		end
		return invokeServer(self, env.localPlayer, ...)
	end,
	InvokeClient = function(self, player, ...)
		checkPlayer(player, "InvokeClient")
		local callback = Data[self].Props.OnClientInvoke
		if player ~= env.localPlayer or not callback then
			error("env : InvokeClient vers un client non simulé", 2)
		end
		return callback(table.unpack(packCopy(...)))
	end,
}

local function remoteNamed(name: string): any
	local folder = env.game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if not remote then
		error("env : remote introuvable " .. tostring(name), 3)
	end
	return remote
end

-- Client hostile : envoie un RemoteEvent au serveur au nom de `player` (arguments copiés comme par le réseau)
function env.fireServer(player: any, name: string, ...: any)
	local remote = remoteNamed(name)
	fireSignal(getSignal(remote, "OnServerEvent"), player, table.unpack(packCopy(...)))
end

-- Client hostile : appelle une RemoteFunction au nom de `player` ; renvoie ses résultats
function env.invokeServer(player: any, name: string, ...: any): ...any
	return invokeServer(remoteNamed(name), player, ...)
end

-- Envois serveur -> client d'un remote vers un joueur (liste des arguments de chaque envoi)
function env.received(player: any, name: string): { any }
	local list = {}
	for _, entry in env.sent do
		if entry.Player == player and entry.Remote == name then
			table.insert(list, entry.Args)
		end
	end
	return list
end

-- ===== Tweens et sons =====

Methods.TweenBase = {
	Play = function(self)
		local state = Data[self]
		local extra = state.Extra
		extra.Token = (extra.Token or 0) + 1
		local token = extra.Token
		env.setProperty(self, "PlaybackState", Enum.PlaybackState.Playing)
		local info = extra.Info
		Task.delay(info.Time + info.DelayTime, function()
			if extra.Token ~= token or not isInstance(extra.Target) or Data[extra.Target].Destroyed then
				return
			end
			for key, value in extra.Goals do
				extra.Target[key] = value
			end
			env.setProperty(self, "PlaybackState", Enum.PlaybackState.Completed)
			fireSignal(getSignal(self, "Completed"), Enum.PlaybackState.Completed)
		end)
	end,
	Cancel = function(self)
		local extra = Data[self].Extra
		extra.Token = (extra.Token or 0) + 1
		env.setProperty(self, "PlaybackState", Enum.PlaybackState.Cancelled)
		fireSignal(getSignal(self, "Completed"), Enum.PlaybackState.Cancelled)
	end,
	Pause = function(self)
		local extra = Data[self].Extra
		extra.Token = (extra.Token or 0) + 1
		env.setProperty(self, "PlaybackState", Enum.PlaybackState.Paused)
	end,
}

Methods.Sound = {
	Play = function(self)
		env.setProperty(self, "Playing", true)
		table.insert(env.soundsPlayed, self)
	end,
	Stop = function(self)
		env.setProperty(self, "Playing", false)
	end,
	Pause = function(self)
		env.setProperty(self, "Playing", false)
	end,
	Resume = function(self)
		env.setProperty(self, "Playing", true)
	end,
}
env.soundsPlayed = {}

-- Gerbes de particules (auras, src/client/Aura) : rien à dessiner hors de Studio, on compte par émetteur
Methods.ParticleEmitter = {
	Emit = function(self, count)
		env.particlesEmitted[self] = (env.particlesEmitted[self] or 0) + (count or 16)
	end,
	Clear = function() end,
}
env.particlesEmitted = setmetatable({}, { __mode = "k" })

Methods.Animator = {
	LoadAnimation = function(self, animation)
		local track = create("AnimationTrack")
		Data[track].Extra.Animation = animation
		return track
	end,
}
Methods.AnimationTrack = {
	Play = function(self)
		env.setProperty(self, "IsPlaying", true)
	end,
	Stop = function(self)
		env.setProperty(self, "IsPlaying", false)
		fireSignal(getSignal(self, "Stopped"))
	end,
	AdjustSpeed = function() end,
	AdjustWeight = function() end,
}
Methods.Humanoid = {
	MoveTo = function() end,
	ChangeState = function() end,
	GetState = function()
		return Enum.HumanoidStateType.Running
	end,
	SetStateEnabled = function() end,
	UnequipTools = function() end,
	EquipTool = function() end,
}

-- ===== Joueurs =====

local nextUserId = 1000
local playerList: { any } = {}

function env.players(): { any }
	local list = {}
	for _, player in playerList do
		if Data[player].Parent ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

Methods.Players = {
	GetPlayers = function()
		return env.players()
	end,
	GetPlayerByUserId = function(_, userId)
		for _, player in env.players() do
			if player.UserId == userId then
				return player
			end
		end
		return nil
	end,
	GetPlayerFromCharacter = function(_, character)
		for _, player in env.players() do
			if player.Character == character then
				return player
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_, userId)
		return "Player" .. tostring(userId)
	end,
	GetUserIdFromNameAsync = function()
		return 1
	end,
}

env.groupRanks = {} -- [groupId][userId] = rang
env.groups = {} -- [groupId] = { Name, Owner = { Id, Name } }

Methods.Player = {
	Kick = function(self, message)
		table.insert(env.kicks, { Player = self, Message = message or "" })
		Data[self].Extra.Kicked = message or ""
		Task.defer(function()
			if Data[self].Parent then
				env.removePlayer(self)
			end
		end)
	end,
	GetRankInGroup = function(self, groupId)
		local ranks = env.groupRanks[groupId]
		return if ranks then ranks[self.UserId] or 0 else 0
	end,
	IsInGroup = function(self, groupId)
		return self:GetRankInGroup(groupId) > 0
	end,
	LoadCharacter = function(self)
		local old = self.Character
		if old then
			old:Destroy()
		end
		local character = create("Model")
		character.Name = self.Name
		local root = create("Part")
		root.Name = "HumanoidRootPart"
		root.Size = D.Vector3.new(2, 2, 1)
		root.CFrame = D.CFrame.new(0, 3, 0)
		root.Parent = character
		local head = create("Part")
		head.Name = "Head"
		head.Size = D.Vector3.new(2, 1, 1)
		head.CFrame = D.CFrame.new(0, 4.5, 0)
		head.Parent = character
		local humanoid = create("Humanoid")
		humanoid.Parent = character
		create("Animator").Parent = humanoid
		character.PrimaryPart = root
		self.Character = character
		character.Parent = env.game:GetService("Workspace")
		fireSignal(getSignal(self, "CharacterAdded"), character)
	end,
	GetMouse = function()
		error("env : Player:GetMouse n'est pas simulé", 2)
	end,
	GetFriendsOnline = function()
		return {}
	end,
	IsFriendsWith = function(self, userId)
		local friends = Data[self].Extra.Friends
		return friends ~= nil and friends[userId] == true
	end,
	HasAppearanceLoaded = function()
		return true
	end,
}
Methods.Player.GetRankInGroupAsync = Methods.Player.GetRankInGroup
Methods.Player.IsInGroupAsync = Methods.Player.IsInGroup
Methods.Player.IsFriendsWithAsync = Methods.Player.IsFriendsWith

-- Ajoute un joueur (PlayerAdded) : opts = { Name, UserId, DisplayName, Local = true (joueur du client), Character = true }
function env.addPlayer(opts: any?): any
	local options = opts or {}
	nextUserId += 1
	local player = create("Player")
	local userId = options.UserId or nextUserId
	local name = options.Name or ("Player" .. tostring(#playerList + 1))
	player.Name = name
	env.setProperty(player, "UserId", userId)
	env.setProperty(player, "DisplayName", options.DisplayName or name)
	env.setProperty(player, "AccountAge", options.AccountAge or 100)
	create("PlayerGui").Parent = player
	create("Backpack").Parent = player
	create("PlayerScripts").Parent = player
	if options.Friends then
		local friends = {}
		for _, id in options.Friends do
			friends[id] = true
		end
		Data[player].Extra.Friends = friends
	end
	table.insert(playerList, player)
	if options.Local or (env.localPlayer == nil and env.side == "client") then
		env.localPlayer = player
	end
	local players = env.game:GetService("Players")
	setParent(player, players)
	fireSignal(getSignal(players, "PlayerAdded"), player)
	if options.Character then
		player:LoadCharacter()
	end
	return player
end

-- Retire un joueur (PlayerRemoving puis plus de parent)
function env.removePlayer(player: any)
	if Data[player].Parent == nil then
		return
	end
	local players = env.game:GetService("Players")
	fireSignal(getSignal(players, "PlayerRemoving"), player)
	if player.Character then
		player.Character:Destroy()
	end
	setParent(player, nil)
end

-- ===== DataStore =====

local datastore: any = {
	stores = {}, -- [nom][clé] = valeur (copie JSON)
	failures = 0, -- nombre de prochains appels qui échouent
	failMessage = "503: DataStore request failed (simulated)",
	latency = 0, -- secondes d'attente de chaque appel
	disabled = false, -- true : comme Studio sans accès aux API
	calls = 0,
	writes = 0,
}
env.datastore = datastore

local function storable(value: any, path: string, seen: { [any]: boolean }): any
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("104: Cannot store " .. tostring(value) .. " in data store (" .. path .. ")", 0)
		end
		return value
	elseif kind == "string" then
		if utf8.len(value) == nil then
			error("104: Cannot store invalid UTF-8 in data store (" .. path .. ")", 0)
		end
		return value
	elseif kind == "boolean" or kind == "nil" then
		return value
	elseif kind == "table" and getmetatable(value) == nil then
		if seen[value] then
			error("104: Cannot store a cyclic table in data store (" .. path .. ")", 0)
		end
		seen[value] = true
		local count, copy = 0, {}
		for _ in value do
			count += 1
		end
		local isArray = count == #value
		for key, item in value do
			if not isArray and type(key) ~= "string" then
				error("104: Cannot store a table with " .. type(key) .. " keys mixed with others in data store (" .. path .. ")", 0)
			end
			copy[key] = storable(item, path .. "." .. tostring(key), seen)
		end
		seen[value] = nil
		return copy
	end
	error("104: Cannot store " .. typeOf(value) .. " in data store (" .. path .. ")", 0)
end
env.storable = function(value: any): any
	return storable(value, "value", {})
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local function datastoreCall(): ()
	datastore.calls += 1
	if datastore.disabled then
		error("Studio access to API services is not allowed. (simulated)", 0)
	end
	if datastore.latency > 0 then
		Task.wait(datastore.latency)
	end
	if datastore.failures > 0 then
		datastore.failures -= 1
		error(datastore.failMessage, 0)
	end
end

local function storeTable(name: string): { [string]: any }
	local store = datastore.stores[name]
	if not store then
		store = {}
		datastore.stores[name] = store
	end
	return store
end

-- Lecture directe d'une valeur stockée (copie)
function datastore.get(name: string, key: string): any
	return deepCopy(storeTable(name)[key])
end
-- Écriture directe (préparer un test)
function datastore.set(name: string, key: string, value: any)
	storeTable(name)[key] = storable(value, key, {})
end
-- Les `count` prochains appels échouent
function datastore.fail(count: number?, message: string?)
	datastore.failures = count or 1
	if message then
		datastore.failMessage = message
	end
end

Methods.GlobalDataStore = {
	GetAsync = function(self, key)
		datastoreCall()
		return deepCopy(storeTable(Data[self].Extra.StoreName)[key])
	end,
	SetAsync = function(self, key, value)
		datastoreCall()
		storeTable(Data[self].Extra.StoreName)[key] = storable(value, tostring(key), {})
		datastore.writes += 1
	end,
	UpdateAsync = function(self, key, transform)
		datastoreCall()
		local store = storeTable(Data[self].Extra.StoreName)
		local result = transform(deepCopy(store[key]), nil)
		if result == nil then
			return nil
		end
		store[key] = storable(result, tostring(key), {})
		datastore.writes += 1
		return deepCopy(store[key])
	end,
	RemoveAsync = function(self, key)
		datastoreCall()
		local store = storeTable(Data[self].Extra.StoreName)
		local old = store[key]
		store[key] = nil
		return deepCopy(old)
	end,
	IncrementAsync = function(self, key, delta)
		datastoreCall()
		local store = storeTable(Data[self].Extra.StoreName)
		store[key] = (tonumber(store[key]) or 0) + (delta or 1)
		return store[key]
	end,
}

Methods.DataStoreService = {
	GetDataStore = function(_, name, scope)
		local store = create("DataStore")
		Data[store].Extra.StoreName = tostring(name) .. "/" .. tostring(scope or "global")
		store.Name = tostring(name)
		return store
	end,
	GetGlobalDataStore = function()
		local store = create("DataStore")
		Data[store].Extra.StoreName = "__global"
		return store
	end,
	GetOrderedDataStore = function(_, name, scope)
		local store = create("OrderedDataStore")
		Data[store].Extra.StoreName = "ordered:" .. tostring(name) .. "/" .. tostring(scope or "global")
		return store
	end,
}

-- Valeur stockée par DataService (nom du DataStore, clé)
function env.saved(storeName: string, key: string): any
	return datastore.get(storeName .. "/global", key)
end

-- ===== MarketplaceService =====

env.ownedPasses = {} -- [userId][passId] = true
env.productPrices = {} -- [productId] = prix en Robux
env.prompts = {} -- achats proposés : { Player, Kind, Id }

Methods.MarketplaceService = {
	PromptProductPurchase = function(_, player, productId)
		table.insert(env.prompts, { Player = player, Kind = "Product", Id = productId })
	end,
	PromptGamePassPurchase = function(_, player, passId)
		table.insert(env.prompts, { Player = player, Kind = "GamePass", Id = passId })
	end,
	PromptPurchase = function(_, player, assetId)
		table.insert(env.prompts, { Player = player, Kind = "Asset", Id = assetId })
	end,
	UserOwnsGamePassAsync = function(_, userId, passId)
		local owned = env.ownedPasses[userId]
		return owned ~= nil and owned[passId] == true
	end,
	GetProductInfo = function(_, id)
		return { Name = "Product " .. tostring(id), PriceInRobux = env.productPrices[id] or 0, IsForSale = true, ProductId = id }
	end,
	PlayerOwnsAsset = function()
		return false
	end,
}
Methods.MarketplaceService.GetProductInfoAsync = Methods.MarketplaceService.GetProductInfo
Methods.MarketplaceService.PlayerOwnsAssetAsync = Methods.MarketplaceService.PlayerOwnsAsset

local purchaseCounter = 0
-- Achat Robux réel simulé : appelle ProcessReceipt comme Roblox. opts = { PurchaseId, Price }. Renvoie la décision.
function env.purchase(player: any, productId: number, opts: any?): any
	local options = opts or {}
	purchaseCounter += 1
	local market = env.game:GetService("MarketplaceService")
	local callback = env.callback(market, "ProcessReceipt")
	if not callback then
		error("env.purchase : aucun ProcessReceipt", 2)
	end
	return callback({
		PlayerId = player.UserId,
		ProductId = productId,
		PurchaseId = options.PurchaseId or ("PURCHASE-" .. purchaseCounter),
		CurrencySpent = options.Price or env.productPrices[productId] or 0,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = env.game.PlaceId,
	})
end

-- ===== HttpService (GUID, JSON) =====

local guidCounter = 0

local function jsonEncode(value: any, seen: { [any]: boolean }): string
	local kind = type(value)
	if kind == "nil" then
		return "null"
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		if value == math.floor(value) and math.abs(value) < 1e15 then
			return string.format("%d", value)
		end
		return string.format("%.17g", value)
	elseif kind == "string" then
		return '"' .. string.gsub(value, '[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif kind == "table" then
		if seen[value] then
			error("Can't convert to JSON (cyclic table)", 0)
		end
		seen[value] = true
		local count = 0
		for _ in value do
			count += 1
		end
		local parts = {}
		if count == #value then
			for _, item in ipairs(value) do
				table.insert(parts, jsonEncode(item, seen))
			end
			seen[value] = nil
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for key in value do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		for _, key in keys do
			local item = value[key]
			if item == nil then
				item = value[tonumber(key)]
			end
			table.insert(parts, jsonEncode(key, seen) .. ":" .. jsonEncode(item, seen))
		end
		seen[value] = nil
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("Can't convert to JSON (" .. typeOf(value) .. ")", 0)
end

local function jsonDecode(text: string): any
	local pos = 1
	local function skip()
		pos = string.find(text, "[^%s]", pos) or (#text + 1)
	end
	local parse
	local function parseString(): string
		local out = {}
		pos += 1
		while true do
			local c = string.sub(text, pos, pos)
			if c == "" then
				error("Can't parse JSON (unterminated string)", 0)
			elseif c == '"' then
				pos += 1
				return table.concat(out)
			elseif c == "\\" then
				local n = string.sub(text, pos + 1, pos + 1)
				local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
				if n == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(text, pos + 2, pos + 5), 16) :: number))
					pos += 6
				else
					table.insert(out, map[n] or n)
					pos += 2
				end
			else
				table.insert(out, c)
				pos += 1
			end
		end
	end
	parse = function(): any
		skip()
		local c = string.sub(text, pos, pos)
		if c == "{" then
			pos += 1
			local result = {}
			skip()
			if string.sub(text, pos, pos) == "}" then
				pos += 1
				return result
			end
			while true do
				skip()
				local key = parseString()
				skip()
				pos += 1 -- :
				result[key] = parse()
				skip()
				local sep = string.sub(text, pos, pos)
				pos += 1
				if sep == "}" then
					return result
				end
			end
		elseif c == "[" then
			pos += 1
			local result = {}
			skip()
			if string.sub(text, pos, pos) == "]" then
				pos += 1
				return result
			end
			while true do
				table.insert(result, parse())
				skip()
				local sep = string.sub(text, pos, pos)
				pos += 1
				if sep == "]" then
					return result
				end
			end
		elseif c == '"' then
			return parseString()
		elseif string.sub(text, pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif string.sub(text, pos, pos + 4) == "false" then
			pos += 5
			return false
		elseif string.sub(text, pos, pos + 3) == "null" then
			pos += 4
			return nil
		end
		local number = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		if not number or number == "" then
			error("Can't parse JSON", 0)
		end
		pos += #number
		return tonumber(number)
	end
	return parse()
end

Methods.HttpService = {
	GenerateGUID = function(_, wrap)
		guidCounter += 1
		local hex = string.format("%032x", guidCounter)
		local guid = string.format("%s-%s-%s-%s-%s", string.sub(hex, 1, 8), string.sub(hex, 9, 12), string.sub(hex, 13, 16), string.sub(hex, 17, 20), string.sub(hex, 21, 32))
		guid = string.upper(guid)
		return if wrap == false then guid else "{" .. guid .. "}"
	end,
	JSONEncode = function(_, value)
		return jsonEncode(value, {})
	end,
	JSONDecode = function(_, text)
		return jsonDecode(text)
	end,
	UrlEncode = function(_, text)
		return (string.gsub(text, "[^%w%-_%.~]", function(c)
			return string.format("%%%02X", string.byte(c))
		end))
	end,
	GetAsync = function()
		error("env : pas d'accès web dans les tests", 2)
	end,
	PostAsync = function()
		error("env : pas d'accès web dans les tests", 2)
	end,
	RequestAsync = function()
		error("env : pas d'accès web dans les tests", 2)
	end,
}

-- ===== Autres services =====

Methods.GroupService = {
	GetGroupInfoAsync = function(_, groupId)
		local group = env.groups[groupId]
		if not group then
			error("env : groupe " .. tostring(groupId) .. " inconnu (env.groups)", 2)
		end
		return group
	end,
	GetGroupsAsync = function()
		return {}
	end,
}

Methods.TweenService = {
	Create = function(_, target, info, goals)
		if not isInstance(target) then
			error("TweenService:Create : Instance attendue", 2)
		end
		if typeOf(info) ~= "TweenInfo" then
			error("TweenService:Create : TweenInfo attendu", 2)
		end
		local targetInfo = Data[target].Info
		for key, value in goals do
			local valueType = targetInfo.Props[key]
			if not valueType then
				error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is not a valid member of %s)", tostring(key), Data[target].Class), 2)
			end
			coerce(Data[target], key, valueType, value)
		end
		local tween = create("Tween")
		local extra = Data[tween].Extra
		extra.Target = target
		extra.Info = info
		extra.Goals = table.clone(goals)
		return tween
	end,
	GetValue = function(_, alpha)
		return alpha
	end,
}

Methods.TextService = {
	GetTextSize = function(_, text, size)
		return D.Vector2.new(#text * size * 0.5, size)
	end,
	FilterStringAsync = function(_, text)
		local result = create("TextFilterResult")
		Data[result].Extra.Text = text
		return result
	end,
}
Methods.TextFilterResult = {
	GetNonChatStringForBroadcastAsync = function(self)
		return Data[self].Extra.Text
	end,
	GetNonChatStringForUserAsync = function(self)
		return Data[self].Extra.Text
	end,
	GetChatForUserAsync = function(self)
		return Data[self].Extra.Text
	end,
}

Methods.CollectionService = {
	AddTag = function(_, inst, tag)
		env.addTag(inst, tag)
	end,
	RemoveTag = function(_, inst, tag)
		env.removeTag(inst, tag)
	end,
	HasTag = function(_, inst, tag)
		return Data[inst].Tags[tag] == true
	end,
	GetTagged = function(_, tag)
		return table.clone(tagged[tag] or {})
	end,
	GetTags = function(_, inst)
		return inst:GetTags()
	end,
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal("added", tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return tagSignal("removed", tag)
	end,
	GetAllTags = function()
		local list = {}
		for tag in tagged do
			table.insert(list, tag)
		end
		return list
	end,
}

env.actions = {} -- ContextActionService : [nom] = { Fn, Keys }
Methods.ContextActionService = {
	BindAction = function(_, name, fn, _createButton, ...)
		env.actions[name] = { Fn = fn, Keys = { ... } }
	end,
	BindActionAtPriority = function(_, name, fn, _createButton, _priority, ...)
		env.actions[name] = { Fn = fn, Keys = { ... } }
	end,
	UnbindAction = function(_, name)
		env.actions[name] = nil
	end,
	SetTitle = function() end,
	SetImage = function() end,
	SetPosition = function() end,
	GetButton = function()
		return nil
	end,
}

Methods.RunService = {
	IsServer = function()
		return currentSide() == "server"
	end,
	IsClient = function()
		return currentSide() == "client"
	end,
	IsStudio = function()
		return env.studio
	end,
	IsRunning = function()
		return true
	end,
	IsRunMode = function()
		return false
	end,
	IsEdit = function()
		return false
	end,
	BindToRenderStep = function(self, name, _priority, fn)
		local bindings = Data[self].Extra.Bindings
		bindings[name] = getSignal(self, "RenderStepped"):Connect(fn)
	end,
	UnbindFromRenderStep = function(self, name)
		local bindings = Data[self].Extra.Bindings
		if bindings[name] then
			bindings[name]:Disconnect()
			bindings[name] = nil
		end
	end,
}
Init.RunService = function(inst, state)
	state.Extra.Bindings = {}
	for _, name in { "Stepped", "Heartbeat", "RenderStepped", "PreSimulation", "PostSimulation", "PreRender", "PreAnimation" } do
		local signal = getSignal(inst, name)
		if name == "Stepped" or name == "Heartbeat" or name == "RenderStepped" then
			table.insert(heartbeatSignals, signal)
		end
	end
end

Methods.UserInputService = {
	GetLastInputType = function()
		return if env.touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
	end,
	GetMouseLocation = function()
		return D.Vector2.zero
	end,
	IsKeyDown = function()
		return false
	end,
	GetConnectedGamepads = function()
		return {}
	end,
	GetNavigationGamepads = function()
		return {}
	end,
	GetGamepadConnected = function()
		return false
	end,
}
Getters.UserInputService = {
	TouchEnabled = function()
		return env.touch
	end,
	KeyboardEnabled = function()
		return not env.touch
	end,
	MouseEnabled = function()
		return not env.touch
	end,
}

Methods.GuiService = {
	GetGuiInset = function()
		return D.Vector2.new(0, 58), D.Vector2.zero
	end,
}

Methods.SoundService = {
	PlayLocalSound = function(_, sound)
		table.insert(env.soundsPlayed, sound)
	end,
}

Methods.Workspace = {
	GetServerTimeNow = function()
		return env.baseTime + now
	end,
	-- DinoBuilder.Pose place toutes les pièces d'un dino en un seul appel
	BulkMoveTo = function(_, parts, cframes)
		for i, part in parts do
			part.CFrame = cframes[i]
		end
	end,
	Raycast = function()
		return nil
	end,
	GetPartBoundsInRadius = function(self, position, radius)
		local list = {}
		for _, part in self:GetDescendants() do
			if part:IsA("BasePart") and (part.Position - position).Magnitude <= radius then
				table.insert(list, part)
			end
		end
		return list
	end,
	GetPartBoundsInBox = function(self, cframe, size)
		local list = {}
		local half = size / 2
		for _, part in self:GetDescendants() do
			if part:IsA("BasePart") then
				local p = cframe:PointToObjectSpace(part.Position)
				if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
					table.insert(list, part)
				end
			end
		end
		return list
	end,
	GetPartsInPart = function()
		return {}
	end,
	Blockcast = function()
		return nil
	end,
	Spherecast = function()
		return nil
	end,
}

Methods.Camera = {
	WorldToViewportPoint = function(_, position)
		return D.Vector3.new(position.X, position.Y, 0), true
	end,
	WorldToScreenPoint = function(_, position)
		return D.Vector3.new(position.X, position.Y, 0), true
	end,
	ScreenPointToRay = function()
		return D.Ray.new(D.Vector3.zero, D.Vector3.new(0, 0, -1))
	end,
	ViewportPointToRay = function()
		return D.Ray.new(D.Vector3.zero, D.Vector3.new(0, 0, -1))
	end,
}

-- ===== DataModel =====

local closeCallbacks: { any } = {}

Methods.ServiceProvider = {
	GetService = function(self, name)
		checkSelf(self, "GetService")
		return env.service(name)
	end,
	FindService = function(_, name)
		return env.findService(name)
	end,
}
Methods.DataModel = {
	BindToClose = function(_, fn)
		if type(fn) ~= "function" then
			error("BindToClose : fonction attendue", 2)
		end
		table.insert(closeCallbacks, fn)
	end,
	IsLoaded = function()
		return true
	end,
}

local game = create("DataModel")
Data[game].Props.Name = "Game"
env.game = game
local services: { [string]: any } = {}

function env.findService(name: string): any
	return services[name]
end

function env.service(name: string): any
	local existing = services[name]
	if existing then
		return existing
	end
	local info = classInfo(name)
	if not info or not (info.IsA.Instance) then
		error(string.format("'%s' is not a valid Service name", tostring(name)), 3)
	end
	local inst = create(name)
	Data[inst].Props.Name = name
	services[name] = inst
	setParent(inst, game)
	return inst
end

-- Simule l'arrêt du serveur : lance les BindToClose et attend leur fin (au plus `limit` secondes)
function env.close(limit: number?)
	local running = {}
	for _, fn in closeCallbacks do
		table.insert(running, Task.spawn(fn))
	end
	for _, player in env.players() do
		env.removePlayer(player)
	end
	waitUntil(function()
		for _, thread in running do
			if coroutine.status(thread) ~= "dead" then
				return false
			end
		end
		return true
	end, "BindToClose", limit or 30)
end

-- Taille de l'écran simulé (Camera.ViewportSize)
local viewport = D.Vector2.new(1280, 720)
function env.viewportSize(): any
	return viewport
end
function env.setViewport(width: number, height: number)
	viewport = D.Vector2.new(width, height)
	local camera = env.service("Workspace").CurrentCamera
	if camera then
		env.setProperty(camera, "ViewportSize", viewport)
	end
end

Init.Workspace = function(inst)
	local camera = create("Camera")
	Data[camera].Props.ViewportSize = viewport
	setParent(camera, inst)
	Data[inst].Props.CurrentCamera = camera
end

-- ===== Arbre du jeu (manifest de default.project.json) =====

local byFile: { [string]: any } = {}
local fileOf: { [any]: string } = {}

for _, node in manifestList do
	local segments = string.split(node.Path, ".")
	local parent = env.service(segments[1])
	if #segments == 1 then
		continue
	end
	for index = 2, #segments - 1 do
		local child = parent:FindFirstChild(segments[index])
		if not child then
			child = create("Folder")
			child.Name = segments[index]
			setParent(child, parent)
		end
		parent = child
	end
	local name = segments[#segments]
	local inst = parent:FindFirstChild(name)
	if inst and Data[inst].Class ~= node.Class then
		-- (un dossier créé plus tôt devient un ModuleScript init : on garde ses enfants)
		local replacement = create(node.Class)
		replacement.Name = name
		for _, child in inst:GetChildren() do
			setParent(child, replacement)
		end
		destroy(inst)
		setParent(replacement, parent)
		inst = replacement
	elseif not inst then
		inst = create(node.Class)
		inst.Name = name
		setParent(inst, parent)
	end
	if node.File then
		byFile[node.File] = inst
		fileOf[inst] = node.File
	end
end

-- Instance d'un chemin du jeu : env.instance("ServerScriptService.Server.Boot")
function env.instance(path: string): any
	local segments = string.split(path, ".")
	local current = env.service(segments[1])
	for index = 2, #segments do
		current = current:FindFirstChild(segments[index])
		if not current then
			error("env.instance : " .. path .. " introuvable", 2)
		end
	end
	return current
end

-- require d'un ModuleScript comme dans Roblox (une seule exécution par module)
local function requireInstance(target: any): any
	if not isInstance(target) then
		error("require : ModuleScript attendu, reçu " .. typeOf(target), 2)
	end
	if Data[target].Class ~= "ModuleScript" then
		error("require : " .. fullName(target) .. " n'est pas un ModuleScript", 2)
	end
	local file = fileOf[target]
	if not file then
		local state = Data[target]
		if state.Extra.Module ~= nil then
			return state.Extra.Module
		end
		error("require : " .. fullName(target) .. " n'a pas de fichier (module créé pendant le test ?)", 2)
	end
	local path = if string.sub(file, -5) == "/init" then string.sub(file, 1, -6) else file
	return nativeRequire("../../" .. path)
end
env.require = requireInstance

-- Module du jeu par son fichier : env.module("src/server/Boot")
function env.module(file: string): any
	local inst = byFile[file] or byFile[file .. "/init"]
	if not inst then
		error("env.module : " .. file .. " n'est pas dans l'arbre du jeu", 2)
	end
	return requireInstance(inst)
end

-- ===== Globales données aux modules du jeu =====

local function warnFn(...: any)
	local parts = {}
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	local text = table.concat(parts, " ")
	table.insert(env.warnings, text)
	if not env.quiet then
		nativePrint("WARN " .. text)
	end
end
env.warn = warnFn
warn = warnFn

local mathLib = setmetatable({
	noise = function(x, y, z)
		local n = math.sin((x or 0) * 12.9898 + (y or 0) * 78.233 + (z or 0) * 37.719) * 43758.5453
		return (n - math.floor(n)) * 2 - 1
	end,
}, { __index = math })

local debugLib = setmetatable({
	profilebegin = function() end,
	profileend = function() end,
	setmemorycategory = function() end,
	resetmemorycategory = function() end,
}, { __index = debug })

local InstanceGlobal = {
	new = function(className: string, parent: any?)
		if SERVICES[className] or string.match(className, "Service$") then
			error(string.format("Unable to create an Instance of type \"%s\"", className), 2)
		end
		local inst = create(className)
		if parent ~= nil then
			setParent(inst, parent)
		end
		return inst
	end,
	fromExisting = function(inst)
		return cloneInstance(inst)
	end,
}

local shared = {}
local globals: { [string]: any } = {
	require = requireInstance,
	game = game,
	workspace = env.service("Workspace"),
	Instance = InstanceGlobal,
	Enum = Enum,
	task = Task,
	os = Os,
	typeof = typeOf,
	type = typeFn,
	warn = warnFn,
	print = nativePrint,
	tick = function()
		return env.baseTime + now
	end,
	time = function()
		return now
	end,
	elapsedTime = function()
		return now
	end,
	wait = Task.wait,
	delay = Task.delay,
	spawn = Task.defer,
	shared = shared,
	debug = debugLib,
	math = mathLib,
	settings = function()
		return setmetatable({}, { __index = function() return {} end })
	end,
	UserSettings = function()
		return setmetatable({}, { __index = function() return {} end })
	end,
	Vector3 = D.Vector3,
	Vector2 = D.Vector2,
	CFrame = D.CFrame,
	Color3 = D.Color3,
	UDim = D.UDim,
	UDim2 = D.UDim2,
	ColorSequence = D.ColorSequence,
	ColorSequenceKeypoint = D.ColorSequenceKeypoint,
	NumberSequence = D.NumberSequence,
	NumberSequenceKeypoint = D.NumberSequenceKeypoint,
	NumberRange = D.NumberRange,
	Rect = D.Rect,
	TweenInfo = TweenInfo,
	Font = FontType,
	BrickColor = D.BrickColor,
	Random = D.Random,
	DateTime = DateTime,
	Ray = D.Ray,
	RaycastParams = D.makeParams("RaycastParams", { FilterType = "Exclude", IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false }),
	OverlapParams = D.makeParams("OverlapParams", { FilterType = "Exclude", MaxParts = 0, CollisionGroup = "Default", RespectCanCollide = false }),
	PhysicalProperties = D.PhysicalProperties,
	Region3 = D.Region3,
	Axes = D.Axes,
	Faces = D.Faces,
	Content = D.Content,
	Vector3int16 = D.Vector3,
	Vector2int16 = D.Vector2,
	PathWaypoint = { new = function(position, action) return { Position = position, Action = action } end },
	CatalogSearchParams = { new = function() return {} end },
	SharedTable = { new = function() return {} end },
}
env.globals = globals

-- Ce que reçoit un module du jeu (ligne d'en-tête de run.py) : les globales, avec `script` = son instance
function env.bind(file: string): any
	local inst = byFile[file]
	if not inst then
		error("env.bind : " .. file .. " n'est pas dans l'arbre du jeu (default.project.json)", 2)
	end
	return setmetatable({ script = inst }, { __index = globals })
end

-- Remplace une méthode Roblox non simulée (ou la change pour un test)
function env.stubMethod(className: string, method: string, fn: any)
	Methods[className] = Methods[className] or {}
	Methods[className][method] = fn
end

-- Passe côté client (RunService:IsClient) ; `player` devient Players.LocalPlayer
function env.setSide(side: string, player: any?)
	env.side = side
	if player then
		env.localPlayer = player
	end
end

Getters.Players = {
	LocalPlayer = function()
		return if currentSide() == "client" then env.localPlayer else nil
	end,
}

-- Les globales servent aussi aux tests : local Vector3 = env.globals.Vector3...
for key, value in globals do
	env[key] = env[key] or value
end
env.Data = Data

return env
