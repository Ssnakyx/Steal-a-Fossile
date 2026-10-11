--!strict
-- DinoAnimController : joue les animations des dinos côté client (lecteur des données de DinoBuilder).
--
-- Contrat (serveur ou client) : un Model tagué "Dino" (DinoBuilder.Tag) avec les attributs
--   Species (string)         espèce (module de src/shared/DinoModels) ou clé enregistrée (hybride)
--   Scale (number)           échelle construite (taille x gardien), voir DinoBuilder.ScaleOf
--   Mutation, Level          (facultatifs) apparence
--   State (string)           état à jouer : Idle, Walk, Run, Happy, Roar, Eat, Sleep, Spawn, Wake, Catch, Search,
--                            Return, BackToSleep, Fusion, Index (+ TakeOff, Fly, Glide, Land pour les volants,
--                            Dive, Jump pour les nageurs). Un état absent retombe sur un proche puis sur Idle.
--   StateAt (number)         (facultatif) workspace:GetServerTimeNow() du début de l'état : même phase chez tous
--   Speed (number)           (facultatif) vitesse de déplacement en studs/s : la marche se cale dessus (pas de glisse)
--   WalkFrom, WalkTo         (facultatifs) promenade dans l'enclos (src/shared/Roam.luau) : avec State = "Walk", le dino
--                            va de la pose WalkFrom (CFrame) au point WalkTo (Vector3) à Speed studs/s depuis StateAt ;
--                            la pose est calculée ici et la pièce Root y est posée chez ce client (le nom suit)
--   AlwaysAnimate (boolean)  (facultatif) pour les ViewportFrame (Index) : pas de coupure à distance ou hors écran
--   Rarity (string)          (facultatif) Common ... Secret ; sans lui, la rareté de l'espèce (Config.Rarity.Species).
--                            Aura de rareté (module Aura, le même que les blocs de fossiles) : cercle magique à runes au
--                            sol de la couleur de la rareté, de plus en plus riche (poussière lumineuse, comètes, cercles
--                            au-dessus de la tête, rayon de lumière, flammes Mythic, arc-en-ciel Secret) ; onde de choc
--                            aux états Spawn et Fusion. Pas d'aura sur les gardiens (tag « Guardian »).
-- Si le modèle n'a que sa pièce "Root" (DinoBuilder.CreateProxy), les briques sont construites ici, chez le client.
-- StreamingEnabled : un modèle tagué peut arriver avant sa pièce Root, ou la perdre au loin. Le dino est construit quand
-- la pièce arrive, défait quand elle repart, refait sur la nouvelle pièce quand elle revient.
--
-- Fondus de 0,2 s entre états, variantes d'Idle au hasard, cadence plus lente pour les gros, animation complète
-- près de la caméra, cadence réduite au loin, figée hors de vue. DinoAnimController.Event : (model, nom, os) pour
-- les effets liés aux pas, au rugissement et à l'impact (seulement pour les dinos proches).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DinoBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DinoBuilder"))
local Roam = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Roam"))
local Aura = require(script.Parent.Parent.Aura)

local DinoAnimController = {}

local FADE = 0.2
local NEAR, MID, FAR, CULL = 70, 140, 260, 420 -- studs, multipliés par la taille du dino
local IDLE_VARIANTS = { "IdleSniff", "IdleScratch", "IdleStretch", "IdleShake", "IdleYawn" }
local PULSE_STATES = { Spawn = true, Fusion = true } -- onde de choc de l'aura au début de ces états
local FALLBACK: { [string]: { string } } = {
	Return = { "Walk" },
	Run = { "Walk" },
	Fly = { "Glide", "Walk" },
	Glide = { "Fly", "Walk" },
	TakeOff = { "Fly", "Walk" },
	Land = { "Idle" },
	Dive = { "Walk" },
	Jump = { "Happy" },
	Wake = { "Idle" },
	BackToSleep = { "Sleep" },
	Search = { "Idle" },
	Catch = { "Roar" },
}

type Dino = {
	Model: Model,
	Data: DinoBuilder.Data,
	Rig: DinoBuilder.Rig,
	Local: Model?, -- briques construites ici (modèle proxy)
	Root: BasePart,
	Base: CFrame, -- repère affiché (lissé)
	Clip: DinoBuilder.Clip,
	ClipName: string,
	Time: number,
	Rate: number,
	State: string,
	From: DinoBuilder.Pose?,
	Fade: number,
	Pose: DinoBuilder.Pose,
	Mix: DinoBuilder.Pose,
	Last: DinoBuilder.Pose,
	Acc: number,
	Phase: number,
	NextVariant: number,
	Radius: number,
	Aura: Aura.Handle?,
	PulsedAt: number, -- os.clock() de la dernière onde de choc
	Conns: { RBXScriptConnection },
}

local dinos: { [Model]: Dino } = {}
local waiting: { [Model]: RBXScriptConnection } = {} -- modèles tagués dont la pièce Root n'est pas (encore) là
local eventBindable = Instance.new("BindableEvent")
DinoAnimController.Event = eventBindable.Event

local function clipFor(data: DinoBuilder.Data, state: string): (string, DinoBuilder.Clip?)
	local c = data.Clips[state]
	if c then
		return state, c
	end
	local alts = FALLBACK[state]
	if alts then
		for _, alt in alts do
			if data.Clips[alt] then
				return alt, data.Clips[alt]
			end
		end
	end
	return "Idle", data.Clips.Idle
end

-- cadence : les gros sont plus lents et plus lourds ; une marche se cale sur la vitesse réelle
local function rateFor(d: Dino, clip: DinoBuilder.Clip): number
	local scale = d.Rig.Scale
	local speed = d.Model:GetAttribute("Speed")
	if clip.Speed and type(speed) == "number" and speed > 0.05 then
		return math.clamp(speed / (clip.Speed * scale), 0.35, 3)
	end
	return scale ^ -0.3
end

local function play(d: Dino, name: string, startTime: number?)
	local clipName, clip = clipFor(d.Data, name)
	if not clip then
		return
	end
	d.From = DinoBuilder.Copy(d.Last, d.From)
	d.Fade = 0
	d.Clip = clip
	d.ClipName = clipName
	d.Time = startTime or 0
	d.Rate = rateFor(d, clip)
	if clipName == "Idle" then
		d.NextVariant = 6 + math.random() * 8
	end
end

local function onState(d: Dino)
	local state = d.Model:GetAttribute("State")
	if type(state) ~= "string" then
		state = "Idle"
	end
	d.State = state :: string
	local at = d.Model:GetAttribute("StateAt")
	local start = 0
	if type(at) == "number" then
		start = math.max(0, workspace:GetServerTimeNow() - at)
	end
	play(d, state :: string, start)
	-- onde de choc de l'aura au début de Spawn et Fusion (une seule quand State et StateAt arrivent l'un après l'autre)
	local handle = d.Aura
	local now = os.clock()
	if handle and PULSE_STATES[state] and start < 1 and now - d.PulsedAt > 0.5 then
		d.PulsedAt = now
		Aura.Pulse(handle)
	end
end

local function fire(d: Dino, t0: number, t1: number)
	for _, ev in d.Clip.Events do
		local t = ev[1] :: number
		if t > t0 and t <= t1 then
			eventBindable:Fire(d.Model, ev[2], ev[3])
		end
	end
end

-- ====================================================================== rareté : aura (module Aura)
-- couleurs et rareté des espèces : Config.Rarity (blocs de fossiles, brief boucle) quand il est là
local Config: any = nil
do
	local module = ReplicatedStorage:WaitForChild("Shared"):FindFirstChild("Config")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			Config = result
		end
	end
end

local function lookup(fn: () -> any): any
	if not Config then
		return nil
	end
	local ok, value = pcall(fn)
	return if ok then value else nil
end

-- Rareté affichée : attribut Rarity, sinon celle de l'espèce
local function rarityOf(model: Model): string?
	local attr = model:GetAttribute("Rarity")
	if type(attr) == "string" then
		return attr
	end
	local species = model:GetAttribute("Species")
	if type(species) ~= "string" then
		return nil
	end
	local rarity = lookup(function()
		local def = Config.Species.ByModel[species]
		return Config.Rarity.Species[if def then def.Name else species]
	end)
	return if type(rarity) == "string" then rarity else nil
end

local function clearAura(d: Dino)
	local handle = d.Aura
	if handle then
		d.Aura = nil
		Aura.Detach(handle)
	end
end

-- Haut de la tête au repos (repère du modèle, à l'échelle) : le plus haut des pavés de l'os Head
local function headTop(data: DinoBuilder.Data, scale: number): Vector3?
	local best: Vector3? = nil
	for _, box in data.Boxes do
		if box.Bone == "Head" then
			local top = Vector3.new(box.Center.X, box.Center.Y + box.Size.Y / 2, box.Center.Z) * scale
			if not best or top.Y > best.Y then
				best = top
			end
		end
	end
	return best
end

local function buildAura(d: Dino)
	clearAura(d)
	local model = d.Model
	-- gardiens : leur poursuite doit rester lisible (et leur taille dit déjà qu'ils sont dangereux)
	if model:HasTag("Guardian") or model:GetAttribute("Guardian") ~= nil then
		return
	end
	local rarity = rarityOf(model)
	if not rarity or not Aura.Has(rarity) then
		return
	end
	local scale = d.Rig.Scale
	local a, b = DinoBuilder.RingShape(d.Data, scale)
	local height = d.Data.Height * scale
	local rest = headTop(d.Data, scale)
	local top: () -> Vector3
	if rest then
		local restTop: Vector3 = rest
		top = function(): Vector3
			return d.Base * ((d.Rig.Solved.Head or CFrame.identity) * restTop)
		end
	else
		top = function(): Vector3
			return d.Base * Vector3.new(0, height, 0)
		end
	end
	d.Aura = Aura.Attach(model, {
		Rarity = rarity,
		Radius = math.sqrt(a * b),
		Height = height,
		Pivot = function(): CFrame
			return d.Base
		end,
		Top = top,
		Footprint = Vector2.new(a * 1.05, b * 0.95),
		Body = d.Local or model,
		Parent = model,
		Viewport = model:GetAttribute("AlwaysAnimate") == true,
	})
end

-- Promenade en cours (State = "Walk" avec WalkFrom et WalkTo) : pose calculée (Roam.PoseAt) et pièce Root posée là chez
-- ce client (le serveur ne la déplace qu'à l'arrivée) ; nil sinon
local function walkPose(d: Dino): CFrame?
	if d.State ~= "Walk" then
		return nil
	end
	local model = d.Model
	local from = model:GetAttribute("WalkFrom")
	local to = model:GetAttribute("WalkTo")
	local speed = model:GetAttribute("Speed")
	local at = model:GetAttribute("StateAt")
	if typeof(from) ~= "CFrame" or typeof(to) ~= "Vector3" or type(speed) ~= "number" or type(at) ~= "number" then
		return nil
	end
	local pose = Roam.PoseAt(from, to, speed, workspace:GetServerTimeNow() - at)
	d.Root.CFrame = pose
	return pose
end

local function step(d: Dino, dt: number, full: boolean)
	local clip = d.Clip
	local t0 = d.Time
	d.Time += dt * d.Rate
	if full and #clip.Events > 0 then
		if clip.Loop then
			local a, b = t0 % clip.Length, d.Time % clip.Length
			if b >= a then
				fire(d, a, b)
			else
				fire(d, a, clip.Length)
				fire(d, -1, b)
			end
		else
			fire(d, t0, math.min(d.Time, clip.Length))
		end
	end
	-- fin d'une animation simple : état suivant (local tant que le serveur n'a rien dit d'autre)
	if not clip.Loop and d.Time >= clip.Length then
		play(d, clip.Next or "Idle")
		clip = d.Clip
	elseif d.ClipName == "Idle" and d.State == "Idle" then
		d.NextVariant -= dt
		if d.NextVariant <= 0 then
			local options = {}
			for _, n in IDLE_VARIANTS do
				if d.Data.Clips[n] then
					table.insert(options, n)
				end
			end
			if #options > 0 then
				play(d, options[math.random(1, #options)])
				clip = d.Clip
			else
				d.NextVariant = 10
			end
		end
	end
	local pose = DinoBuilder.Sample(clip, d.Time, d.Pose)
	if d.From and d.Fade < 1 then
		d.Fade = math.min(1, d.Fade + dt / FADE)
		local w = d.Fade * d.Fade * (3 - 2 * d.Fade)
		pose = DinoBuilder.Blend(d.From :: DinoBuilder.Pose, pose, w, d.Mix)
	end
	DinoBuilder.Copy(pose, d.Last)
	-- repère : suit la pièce Root (déplacée par le serveur à basse fréquence) en lissant, ou la promenade en cours
	local target = walkPose(d) or d.Root.CFrame
	local k = 1 - math.exp(-dt * 14)
	if (d.Base.Position - target.Position).Magnitude > 8 * d.Rig.Scale then
		d.Base = target
	else
		d.Base = d.Base:Lerp(target, k)
	end
	DinoBuilder.Pose(d.Rig, pose, d.Base)
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		return root
	end
	local primary = model.PrimaryPart
	return if primary and primary:IsDescendantOf(model) then primary else nil
end

local function stopWaiting(model: Model)
	local conn = waiting[model]
	if conn then
		waiting[model] = nil
		conn:Disconnect()
	end
end

local attach: (Model) -> ()

-- Modèle tagué et dans le jeu : (re)construit, ou attend sa pièce Root
local function retry(model: Model)
	if model:HasTag(DinoBuilder.Tag) and model:IsDescendantOf(game) then
		attach(model)
	end
end

local function detach(model: Model)
	stopWaiting(model)
	local d = dinos[model]
	if not d then
		return
	end
	dinos[model] = nil
	for _, c in d.Conns do
		c:Disconnect()
	end
	clearAura(d)
	if d.Local then
		d.Local:Destroy()
	end
end

function attach(model: Model)
	if dinos[model] then
		return
	end
	local species = model:GetAttribute("Species")
	if type(species) ~= "string" then
		return
	end
	local data = DinoBuilder.Get(species)
	if not data then
		return
	end
	local root = rootOf(model)
	if not root then
		-- StreamingEnabled : le modèle est arrivé avant sa pièce Root (ou l'a perdue) ; on réessaie quand elle arrive
		if not waiting[model] and model:HasTag(DinoBuilder.Tag) then
			waiting[model] = model.ChildAdded:Connect(function(child)
				if child:IsA("BasePart") then
					task.defer(retry, model)
				end
			end)
		end
		return
	end
	stopWaiting(model)
	local hasBones = false
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Bone") then
			hasBones = true
			break
		end
	end
	local visual: Model = model
	local localModel: Model? = nil
	if not hasBones then
		-- proxy du serveur : briques construites chez le client, alignées sur la pièce Root
		local mutation = model:GetAttribute("Mutation")
		local level = model:GetAttribute("Level")
		local scale = model:GetAttribute("Scale")
		localModel = DinoBuilder.Build(data, {
			Size = if type(scale) == "number" then scale else 1,
			Mutation = if type(mutation) == "string" then mutation else nil,
			Level = if type(level) == "string" then level else nil,
		})
		visual = localModel :: Model
	end
	local rig = DinoBuilder.Rig(visual, data)
	if localModel then
		localModel:PivotTo(root.CFrame)
		localModel.Parent = model
	end
	local d: Dino = {
		Model = model,
		Data = data,
		Rig = rig,
		Local = localModel,
		Root = root,
		Base = root.CFrame,
		Clip = data.Clips.Idle,
		ClipName = "Idle",
		Time = math.random() * 2,
		Rate = 1,
		State = "Idle",
		From = nil,
		Fade = 1,
		Pose = {},
		Mix = {},
		Last = {},
		Acc = math.random() * 0.05,
		Phase = math.random(0, 11),
		NextVariant = 6 + math.random() * 8,
		Radius = math.max(data.Size.X, data.Size.Y, data.Size.Z) * rig.Scale * 0.6,
		Aura = nil,
		PulsedAt = -math.huge,
		Conns = {},
	}
	dinos[model] = d
	buildAura(d)
	onState(d)
	table.insert(d.Conns, model:GetAttributeChangedSignal("State"):Connect(function()
		onState(d)
	end))
	table.insert(d.Conns, model:GetAttributeChangedSignal("StateAt"):Connect(function()
		onState(d)
	end))
	table.insert(d.Conns, model:GetAttributeChangedSignal("Speed"):Connect(function()
		d.Rate = rateFor(d, d.Clip)
	end))
	table.insert(d.Conns, model:GetAttributeChangedSignal("Rarity"):Connect(function()
		buildAura(d)
	end))
	-- la pièce Root repart (streaming out) : briques défaites, on attend la suivante
	table.insert(d.Conns, model.ChildRemoved:Connect(function(child)
		if child == root then
			detach(model)
			retry(model)
		end
	end))
end

local frame = 0
local function update(dt: number)
	frame += 1
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, d in dinos do
		if not model.Parent then
			continue
		end
		local always = model:GetAttribute("AlwaysAnimate") == true
		local full = true
		local every = 1
		if not always and cam then
			local pos = d.Root.Position
			local size = math.max(1, d.Radius / 4)
			local dist = (pos - camPos).Magnitude / size
			if dist > CULL then
				continue -- figé : trop loin
			end
			local _, onScreen = cam:WorldToViewportPoint(pos)
			if not onScreen then
				-- hors du cadre : on vérifie aussi un point au-dessus (gros dinos à moitié visibles)
				local _, top = cam:WorldToViewportPoint(pos + Vector3.new(0, d.Radius, 0))
				if not top and dist > 12 then
					continue -- figé : hors de vue
				end
			end
			if dist > FAR then
				every, full = 4, false
			elseif dist > MID then
				every, full = 3, false
			elseif dist > NEAR then
				every = 2
			end
		end
		d.Acc += dt
		if every == 1 or (frame + d.Phase) % every == 0 then
			step(d, math.min(d.Acc, 0.25), full)
			d.Acc = 0
		end
	end
end

-- Joue un état sur un modèle local (ViewportFrame, aperçu) : même effet que l'attribut State
function DinoAnimController.Play(model: Model, state: string)
	model:SetAttribute("State", state)
	model:SetAttribute("StateAt", nil)
end

-- Enregistre un modèle sans passer par le tag (déjà construit par DinoBuilder.Build)
function DinoAnimController.Register(model: Model)
	attach(model)
end

function DinoAnimController.Unregister(model: Model)
	detach(model)
end

function DinoAnimController.Init() end

function DinoAnimController.Start()
	CollectionService:GetInstanceAddedSignal(DinoBuilder.Tag):Connect(function(inst)
		if inst:IsA("Model") then
			task.defer(retry, inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(DinoBuilder.Tag):Connect(function(inst)
		if inst:IsA("Model") then
			detach(inst)
		end
	end)
	for _, inst in CollectionService:GetTagged(DinoBuilder.Tag) do
		if inst:IsA("Model") then
			task.defer(retry, inst)
		end
	end
	RunService.RenderStepped:Connect(update)
end

return DinoAnimController
