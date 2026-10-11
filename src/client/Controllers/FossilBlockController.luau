--!strict
-- FossilBlockController (brief 9 « blocs-hybrides ») : habille chez le client les blocs de fossiles du serveur (des cubes
-- de la couleur de leur rareté) avec les modèles en briques de BlockModels : une forme par biome, la couleur, la
-- taille et la lumière de la rareté.
--
-- Contrat : une BasePart nommée
--   FossilBlock    bloc posé sur un gisement (DigSiteService)
--   DroppedFossil  bloc lâché au sol (DroppedBlockService)
--   CarriedFossil  bloc porté sur le dos (CarryService) : tourné, son crâne regarde derrière le joueur et ses cristaux
--                  s'éloignent de lui
--   TankBlock      bloc dans une cuve du parc (ReviveService)
-- avec l'attribut Rarity (Common ... Secret) et, facultatifs, Zone (décor du biome, Config.Zones) et BlockId (tourne
-- le bloc d'un quart de tour : les gisements ne montrent pas tous la même face). La pièce du serveur garde son prompt
-- et ses attributs ; elle est seulement cachée chez le client (LocalTransparencyModifier) tant que son modèle est
-- construit. Au loin, ou si la rareté est inconnue, le cube coloré du serveur reste visible (modèle simplifié).
-- Les raretés hautes sont plus grosses que la pièce du serveur (BlockModels.SideOf) : le bloc grandit vers le haut (il
-- reste posé au sol), et vers l'arrière sur le dos d'un joueur.
--
-- Le modèle est construit près de la caméra et défait au loin. Joué ici, près de la caméra et à l'écran
-- (BlockModels.Looks) : lave, coeur, cristaux Neon et lumière qui battent ; couches, cristaux et lumière arc-en-ciel
-- du Secret ; morceaux qui flottent (Float, Mythic) et éclats qui tournent autour du bloc (Orbit, Secret), qui montent
-- et descendent doucement. Les auras autour des blocs
-- viennent d'un autre module (thread des auras) par le point d'accroche :
--   FossilBlockController.SetAura(function(model, info) ... return cleanup end)
--     appelée pour chaque modèle construit (et pour ceux qui le sont déjà) ; info = { Rarity, Zone?, Kind, Size, Part,
--     Own } ; la fonction renvoyée (facultative) est appelée quand le modèle est défait.
-- Le modèle porte aussi le tag « FossilBlockModel », sa pièce invisible Root (PrimaryPart, au centre, elle suit le
-- bloc même porté) et les attributs Rarity, Zone, Kind, Size et Own.
-- StreamingEnabled : une pièce qui repart est oubliée (son modèle défait), une pièce qui revient est rhabillée.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlockModels = require(ReplicatedStorage.Shared.BlockModels)

local FossilBlockController = {}

-- noms des pièces de bloc posées par le serveur
FossilBlockController.Names = {
	FossilBlock = true,
	DroppedFossil = true,
	CarriedFossil = true,
	TankBlock = true,
} :: { [string]: boolean }
FossilBlockController.Tag = "FossilBlockModel" -- tag des modèles construits chez le client

export type AuraInfo = {
	Rarity: string,
	Zone: string?,
	Kind: string, -- nom de la pièce du serveur (FossilBlock, DroppedFossil, CarriedFossil, TankBlock)
	Size: number, -- côté du bloc en studs
	Part: BasePart, -- pièce du serveur
	Own: boolean, -- bloc porté par le joueur local
}
export type AuraFn = (model: Model, info: AuraInfo) -> (() -> ())?

local BUILD, DROP = 170, 210 -- studs (pour un bloc de 3) : modèle construit en deçà, défait au-delà
local SHINE_NEAR = 140 -- battement et arc-en-ciel en deçà (et à l'écran)
local CHECK_EVERY = 0.2 -- secondes entre deux tris par distance

type Entry = {
	Part: BasePart,
	Rarity: string?,
	Zone: string?,
	Look: BlockModels.Look?,
	Side: number, -- côté du modèle en studs
	Offset: CFrame, -- rotation (BlockId, bloc porté) et décalage (bloc plus gros que la pièce) dans le repère de la pièce
	Moving: boolean, -- suit la pièce à chaque image (bloc porté)
	Own: boolean, -- porté par le joueur local
	Dist: number,
	Dirty: boolean,
	Model: Model?,
	Parts: { BasePart },
	Offsets: { CFrame },
	Out: { CFrame },
	Shine: { BasePart }, -- lave et cristaux Neon (battent)
	Rainbow: { BasePart },
	RainbowHue: { number },
	Gems: { BasePart },
	GemHue: { number },
	Drift: { BasePart }, -- morceaux qui flottent et éclats qui tournent
	DriftIndex: { number }, -- leur place dans Parts
	DriftOut: { CFrame },
	Light: PointLight?,
	Clock: number,
	Cleanup: (() -> ())?,
	Conns: { RBXScriptConnection },
}

local entries: { [BasePart]: Entry } = {}
local folder: Folder? = nil
local auraFn: AuraFn? = nil
local started = false

local function hue(h: number): Color3
	return Color3.fromHSV(h % 1, 0.7, 1)
end

local function sizeOf(part: BasePart): number
	local s = part.Size
	return math.max(s.X, s.Y, s.Z)
end

local function isOwn(part: BasePart): boolean
	local me = Players.LocalPlayer
	local character = me and me.Character
	return character ~= nil and part:IsDescendantOf(character)
end

-- Rotation et décalage du modèle dans le repère de la pièce : le bloc porté est retourné (crâne vers l'arrière) et
-- grandit vers le haut et l'arrière ; les autres tournent d'un quart de tour par BlockId et grandissent vers le haut
-- (posés au sol), sauf dans une cuve où ils restent centrés
local function offsetOf(part: BasePart, side: number): CFrame
	local grow = math.max(0, side - sizeOf(part)) / 2
	if part.Name == "CarriedFossil" then
		return CFrame.new(0, grow, grow) * CFrame.Angles(0, math.pi, 0)
	end
	local id = part:GetAttribute("BlockId")
	local quarter = if type(id) == "number" and id == id and math.abs(id) < 1e9 then math.floor(id) % 4 else 0
	local lift = if part.Name == "TankBlock" then 0 else grow
	return CFrame.new(0, lift, 0) * CFrame.Angles(0, quarter * math.pi / 2, 0)
end

-- ====================================================================== auras (autre module)

local function infoOf(e: Entry): AuraInfo
	return {
		Rarity = e.Rarity :: string,
		Zone = e.Zone,
		Kind = e.Part.Name,
		Size = e.Side,
		Part = e.Part,
		Own = e.Own,
	}
end

local function attachAura(e: Entry)
	local fn, model = auraFn, e.Model
	if not (fn and model) or e.Cleanup then
		return
	end
	local ok, result = pcall(fn, model, infoOf(e))
	if ok and type(result) == "function" then
		e.Cleanup = result
	elseif not ok then
		warn("[FossilBlockController] aura : " .. tostring(result))
	end
end

local function detachAura(e: Entry)
	local cleanup = e.Cleanup
	e.Cleanup = nil
	if cleanup then
		xpcall(cleanup, function(err: any)
			warn("[FossilBlockController] aura (nettoyage) : " .. tostring(err))
		end)
	end
end

-- Branche le module des auras : fn(model, info) pour chaque modèle construit, maintenant et plus tard. nil : retire.
function FossilBlockController.SetAura(fn: AuraFn?)
	for _, e in entries do
		detachAura(e)
	end
	auraFn = fn
	for _, e in entries do
		attachAura(e)
	end
end

-- ====================================================================== brillance

-- Lave, cristaux Neon et lumière qui battent ; couches, cristaux et lumière arc-en-ciel (Secret)
local function stepShine(e: Entry, dt: number)
	local look = e.Look
	if not look then
		return
	end
	e.Clock += dt
	local t = e.Clock
	if look.Pulse then
		local w = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 0.9)
		for _, p in e.Shine do
			p.Transparency = 0.35 * w
		end
		local light = e.Light
		if light then
			light.Brightness = look.Light * (0.75 + 0.5 * (1 - w))
		end
	end
	if look.Rainbow then
		for i, p in e.Rainbow do
			p.Color = hue(e.RainbowHue[i] - t * 0.15)
		end
		for i, p in e.Gems do
			p.Color = hue(e.GemHue[i] + t * 0.15)
		end
		local light = e.Light
		if light then
			light.Color = hue(t * 0.15)
		end
	end
end

-- Morceaux qui flottent (montent et descendent) et éclats qui tournent autour du bloc (et flottent aussi)
local function stepFloat(e: Entry)
	if #e.Drift == 0 then
		return
	end
	local base = e.Part.CFrame * e.Offset
	local t = e.Clock
	local amp = 0.04 * e.Side
	for k, part in e.Drift do
		local i = e.DriftIndex[k]
		-- (même phase pour les briques d'une même pièce : son numéro en attribut)
		local n = part:GetAttribute(part.Name)
		local phase = if type(n) == "number" then n * 1.9 else 0
		local bob = CFrame.new(0, math.sin(t * 1.7 + phase) * amp, 0)
		local motion = if part.Name == "Orbit" then CFrame.Angles(0, t * 0.6, 0) * bob else bob
		e.DriftOut[k] = base * motion * e.Offsets[i]
	end
	Workspace:BulkMoveTo(e.Drift, e.DriftOut, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ====================================================================== modèles

local function place(e: Entry)
	local base = e.Part.CFrame * e.Offset
	for i, offset in e.Offsets do
		e.Out[i] = base * offset
	end
	if #e.Parts > 0 then
		Workspace:BulkMoveTo(e.Parts, e.Out, Enum.BulkMoveMode.FireCFrameChanged)
	end
	e.Dirty = false
end

local function unbuild(e: Entry)
	detachAura(e)
	if e.Model then
		e.Model:Destroy()
		e.Model = nil
	end
	table.clear(e.Parts)
	table.clear(e.Offsets)
	table.clear(e.Out)
	table.clear(e.Shine)
	table.clear(e.Rainbow)
	table.clear(e.RainbowHue)
	table.clear(e.Gems)
	table.clear(e.GemHue)
	table.clear(e.Drift)
	table.clear(e.DriftIndex)
	table.clear(e.DriftOut)
	e.Light = nil
	if e.Part.Parent then
		e.Part.LocalTransparencyModifier = 0
	end
end

local function build(e: Entry)
	unbuild(e)
	if not folder then
		return
	end
	local model = BlockModels.Build(e.Rarity, e.Side, e.Zone)
	if not model then
		return
	end
	local data = BlockModels.Get(e.Rarity, e.Zone)
	local gems = if data then math.max(1, data.Gems) else 1
	for _, p in model:GetChildren() do
		if not p:IsA("BasePart") then
			continue
		end
		table.insert(e.Parts, p)
		table.insert(e.Offsets, p.CFrame)
		table.insert(e.Out, p.CFrame)
		local neon = p.Material == Enum.Material.Neon
		if p.Name == "Glow" or (p.Name == "Gem" and neon) then
			table.insert(e.Shine, p)
		end
		if p.Name == "Gem" then
			table.insert(e.Gems, p)
			local index = p:GetAttribute("Gem")
			table.insert(e.GemHue, (if type(index) == "number" then index else 1) / gems)
		elseif p.Name == "Rainbow" then
			table.insert(e.Rainbow, p)
			table.insert(e.RainbowHue, p.CFrame.Position.Y / e.Side * 0.9)
		elseif p.Name == "Root" then
			e.Light = p:FindFirstChildOfClass("PointLight")
		elseif p.Name == "Float" or p.Name == "Orbit" then
			table.insert(e.Drift, p)
			table.insert(e.DriftIndex, #e.Parts)
			table.insert(e.DriftOut, p.CFrame)
		end
	end
	model.Name = e.Part.Name .. "Model"
	model:SetAttribute("Kind", e.Part.Name)
	model:SetAttribute("Size", e.Side)
	model:SetAttribute("Own", e.Own)
	model:AddTag(FossilBlockController.Tag)
	e.Model = model
	place(e)
	model.Parent = folder
	e.Part.LocalTransparencyModifier = 1
	attachAura(e)
end

-- Rareté, biome et taille relus sur la pièce : refait le modèle s'il était construit
local function refresh(e: Entry)
	local rarity = e.Part:GetAttribute("Rarity")
	local look = if type(rarity) == "string" and BlockModels.Get(rarity) then BlockModels.Looks[rarity] else nil
	e.Rarity = if look then rarity :: string else nil
	e.Look = look
	local zone = e.Part:GetAttribute("Zone")
	e.Zone = if type(zone) == "string" and BlockModels.Biome(zone) then zone else nil
	e.Side = BlockModels.SideOf(e.Rarity, sizeOf(e.Part), e.Part.Name)
	e.Offset = offsetOf(e.Part, e.Side)
	e.Own = e.Moving and isOwn(e.Part)
	e.Dirty = true
	local wasBuilt = e.Model ~= nil
	unbuild(e)
	if wasBuilt and look then
		build(e)
	end
end

local function untrack(part: BasePart)
	local e = entries[part]
	if not e then
		return
	end
	entries[part] = nil
	for _, c in e.Conns do
		c:Disconnect()
	end
	unbuild(e)
end

local function track(part: BasePart)
	if entries[part] or not FossilBlockController.Names[part.Name] or not part:IsDescendantOf(Workspace) then
		return
	end
	local e: Entry = {
		Part = part,
		Rarity = nil,
		Zone = nil,
		Look = nil,
		Side = sizeOf(part),
		Offset = CFrame.identity,
		Moving = part.Name == "CarriedFossil",
		Own = false,
		Dist = math.huge,
		Dirty = true,
		Model = nil,
		Parts = {},
		Offsets = {},
		Out = {},
		Shine = {},
		Rainbow = {},
		RainbowHue = {},
		Gems = {},
		GemHue = {},
		Drift = {},
		DriftIndex = {},
		DriftOut = {},
		Light = nil,
		Clock = math.random() * 10,
		Cleanup = nil,
		Conns = {},
	}
	entries[part] = e
	refresh(e)
	for _, name in { "Rarity", "Zone" } do
		table.insert(e.Conns, part:GetAttributeChangedSignal(name):Connect(function()
			refresh(e)
		end))
	end
	table.insert(e.Conns, part:GetAttributeChangedSignal("BlockId"):Connect(function()
		e.Offset = offsetOf(part, e.Side)
		e.Dirty = true
	end))
	table.insert(e.Conns, part:GetPropertyChangedSignal("CFrame"):Connect(function()
		e.Dirty = true
	end))
	table.insert(e.Conns, part:GetPropertyChangedSignal("Size"):Connect(function()
		refresh(e)
	end))
	-- la pièce quitte le jeu (arrachée, rendue, streaming out) : modèle défait
	table.insert(e.Conns, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) then
			untrack(part)
		end
	end))
end

local checkAcc = 0

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	checkAcc += dt
	local check = checkAcc >= CHECK_EVERY
	if check then
		checkAcc = 0
		-- (compteurs lisibles dans Studio sur le dossier : blocs suivis et modèles construits)
		if folder then
			local tracked, built = 0, 0
			for _, e in entries do
				tracked += 1
				if e.Model then
					built += 1
				end
			end
			if folder:GetAttribute("Tracked") ~= tracked then
				folder:SetAttribute("Tracked", tracked)
			end
			if folder:GetAttribute("Built") ~= built then
				folder:SetAttribute("Built", built)
			end
		end
	end
	for part, e in entries do
		if check then
			local scale = math.max(e.Side / BlockModels.Size, 0.5)
			e.Dist = (part.Position - camPos).Magnitude / scale
			if not e.Model and e.Look and e.Dist < BUILD then
				build(e)
			elseif e.Model and e.Dist > DROP then
				unbuild(e)
			end
			if e.Model and part.LocalTransparencyModifier ~= 1 then
				-- (les scripts de caméra remettent à 0 les pièces du personnage quand on zoome)
				part.LocalTransparencyModifier = 1
			end
		end
		if e.Model then
			if e.Moving or e.Dirty then
				place(e)
			end
			local look = e.Look
			if look and (look.Pulse or look.Rainbow) and e.Dist < SHINE_NEAR then
				local onScreen = true
				if cam then
					local _, visible = cam:WorldToViewportPoint(part.Position)
					onScreen = visible
				end
				if onScreen then
					stepShine(e, math.min(dt, 0.1))
					stepFloat(e)
				end
			end
		end
	end
end

-- Pièces de bloc suivies, avec leur modèle construit chez ce client (false s'il ne l'est pas) : tests et debug
function FossilBlockController.Tracked(): { [BasePart]: Model | false }
	local out: { [BasePart]: Model | false } = {}
	for part, e in entries do
		out[part] = e.Model or false
	end
	return out
end

-- Fait un tri par distance tout de suite (tests) : construit ou défait les modèles
function FossilBlockController.Refresh()
	checkAcc = CHECK_EVERY
	update(0)
end

function FossilBlockController.Init()
	local f = Instance.new("Folder")
	f.Name = "FossilBlockModels" -- modèles construits chez ce client (jamais répliqués)
	f.Parent = Workspace
	folder = f
end

function FossilBlockController.Start()
	if started then
		return
	end
	started = true
	Workspace.DescendantAdded:Connect(function(inst: Instance)
		if inst:IsA("BasePart") and FossilBlockController.Names[inst.Name] then
			track(inst)
		end
	end)
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("BasePart") and FossilBlockController.Names[inst.Name] then
			track(inst)
		end
	end
	local warned = false
	local function report(err: any)
		-- (une seule fois : l'erreur est aussi gardée sur le dossier pour le debug dans Studio)
		if warned then
			return
		end
		warned = true
		warn("[FossilBlockController] " .. tostring(err))
		if folder then
			folder:SetAttribute("Error", tostring(err))
		end
	end
	RunService.RenderStepped:Connect(function(dt: number)
		xpcall(update, report, dt)
	end)
end

return FossilBlockController
