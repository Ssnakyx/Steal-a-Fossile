--!strict
-- AuraController : auras de rareté des blocs de fossiles (module Aura, le même que les dinos de DinoAnimController).
--
-- Branché sur le point d'accroche de FossilBlockController (brief 9) : FossilBlockController.SetAura(fn) appelle fn pour
-- chaque modèle de bloc construit chez le client, avec info = { Rarity, Zone?, Kind, Size, Part, Own }, et la fonction
-- renvoyée quand le modèle est défait. Rien d'autre à appeler.
--
-- Par sorte de bloc (Kind) :
--   FossilBlock, DroppedFossil  cercle magique au sol sous le bloc (à hauteur du sol trouvé par un rayon : un bloc de
--                               gisement est à moitié enterré), voile d'énergie qui monte autour du bloc et le dépasse,
--                               poussière, brume, rayon de lumière, contour
--   CarriedFossil               porté dans le dos : pas de cercle (il volerait), voile plus serré, poussière, brume et
--                               rayon qui suivent le porteur ; pour le joueur local, moins d'effets, ni voile ni rayon
--                               (ils gêneraient la vue)
--   TankBlock                   dans la cuve du parc : pas de cercle (le verre et le liquide le couperaient), voile qui
--                               reste dans le verre, poussière, brume et rayon qui sort par le couvercle
-- Common : pas d'aura (GDD, « VFX des fossiles »). Lumière colorée seulement pour les raretés dont le modèle n'a pas
-- déjà la sienne (BlockModels.Looks[rareté].Light).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aura = require(script.Parent.Parent.Aura)
local BlockModels = require(ReplicatedStorage.Shared.BlockModels)
local FossilBlockController = require(script.Parent.FossilBlockController)

local AuraController = {}

local GROUND_BELOW = 1.5 -- studs sous le bas du bloc où chercher le sol
local TANK_VEIL = 2.3 -- studs : demi-largeur du voile dans une cuve (verre de 5 studs de large)

-- Hauteur du sol sous le bloc : le bas du bloc, ou le sol trouvé un peu plus haut (bloc enterré) ou plus bas (posé de
-- travers)
local function groundUnder(model: Model, part: BasePart, center: Vector3, side: number): number
	local bottom = center.Y - side / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, part }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local hit = workspace:Raycast(center, Vector3.new(0, -(side / 2 + GROUND_BELOW), 0), params)
	return if hit then hit.Position.Y else bottom
end

-- Aura d'un modèle de bloc (point d'accroche de FossilBlockController) : renvoie de quoi l'enlever
function AuraController.Attach(model: Model, info: FossilBlockController.AuraInfo): (() -> ())?
	local rarity = info.Rarity
	if rarity == "Common" or not Aura.Has(rarity) then
		return nil
	end
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local followed: BasePart = root
	local side = if type(info.Size) == "number" and info.Size > 0 then info.Size else BlockModels.Size
	local kind = info.Kind
	local onGround = kind == "FossilBlock" or kind == "DroppedFossil"
	local own = kind == "CarriedFossil" and info.Own
	local pivot: () -> CFrame
	if onGround then
		-- posé : le sol est cherché une fois, le cercle suit le bloc s'il bouge (rebond d'un bloc lâché)
		local center = followed.Position
		local ground = groundUnder(model, info.Part, center, side)
		local drop = center.Y - ground
		pivot = function(): CFrame
			local cf = followed.CFrame
			return CFrame.new(cf.Position - Vector3.new(0, drop, 0)) * cf.Rotation
		end
	else
		local half = side / 2
		pivot = function(): CFrame
			return followed.CFrame * CFrame.new(0, -half, 0)
		end
	end
	local look = BlockModels.Looks[rarity]
	local radius = 0.62 * side + 0.9
	-- voile : au-delà des coins du bloc et bien plus haut que lui (il ressort au-dessus) ; plus serré et moins haut sur
	-- le dos ; dans une cuve, il reste dans le verre
	local veil, veilHeight = math.min(0.86 * side, 0.95 * radius), 1.8 * side
	if kind == "TankBlock" then
		veil, veilHeight = math.min(0.8 * side, TANK_VEIL), 1.05 * side
	elseif kind == "CarriedFossil" then
		veil, veilHeight = 0.78 * side, 1.4 * side
	end
	local handle = Aura.Attach(model, {
		Rarity = rarity,
		Radius = radius,
		Height = side,
		Pivot = pivot,
		Footprint = Vector2.new(0.8 * side, 0.8 * side),
		Body = model,
		Ground = onGround,
		Pillar = if own then false else nil,
		Veil = if own then false else nil,
		VeilSize = Vector3.new(veil, veilHeight, veil),
		Intensity = if own then 0.45 elseif kind == "CarriedFossil" then 0.8 else 1,
		Light = not (look and look.Light > 0),
		Parent = model,
	})
	if not handle then
		return nil
	end
	local attached: Aura.Handle = handle
	return function()
		Aura.Detach(attached)
	end
end

function AuraController.Start()
	FossilBlockController.SetAura(AuraController.Attach)
end

return AuraController
