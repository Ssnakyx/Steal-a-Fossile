--!strict
-- Promenade des dinos du parc (Config.Park.Roam) : calcul partagé par le serveur (EnclosureService, qui choisit les
-- trajets) et les clients (DinoAnimController, qui affiche la pose en cours). Un trajet part d'une pose `from`
-- (attribut WalkFrom), va au point `to` (attribut WalkTo) à `speed` studs/s (attribut Speed), à partir de l'heure
-- serveur StateAt (State = "Walk") : le dino tourne d'abord sur place vers le point (TurnTime), puis marche tout droit.
-- Même calcul partout : le dino est à la même place chez tous les joueurs.
-- Les modèles de DinoModels regardent vers -Z : CFrame.lookAt(position, position + direction) les tourne vers la marche.

local Park = require(script.Parent.Config.Park)

local Roam = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function cleanSpeed(speed: number): number
	return if speed == speed and speed > 0.1 then speed else 0.1
end

-- Durée d'un trajet (secondes) : le demi-tour sur place, puis la marche
function Roam.Duration(from: CFrame, to: Vector3, speed: number): number
	return Park.Roam.TurnTime + flat(to - from.Position).Magnitude / cleanSpeed(speed)
end

-- Pose (CFrame) `elapsed` secondes après le départ (avant : la pose de départ ; après : celle de l'arrivée)
function Roam.PoseAt(from: CFrame, to: Vector3, speed: number, elapsed: number): CFrame
	local start = from.Position
	local offset = flat(to - start)
	local distance = offset.Magnitude
	if distance < 1e-3 then
		return from
	end
	local direction = offset / distance
	local facing = CFrame.lookAt(start, start + direction)
	local turnTime = Park.Roam.TurnTime
	if elapsed <= 0 then
		return from
	elseif elapsed < turnTime then
		return from:Lerp(facing, smooth(elapsed / turnTime))
	end
	local walked = math.min(distance, (elapsed - turnTime) * cleanSpeed(speed))
	local t = walked / distance
	local position = Vector3.new(start.X + direction.X * walked, start.Y + (to.Y - start.Y) * t, start.Z + direction.Z * walked)
	return CFrame.lookAt(position, position + direction)
end

-- Vitesse de marche naturelle d'une espèce à l'échelle 1 (studs/s, vitesse de son animation Walk), lue dans son module
-- DinoModels sans le décoder ; nil sans module ni animation Walk
local speeds: { [string]: number | false } = {}
function Roam.WalkSpeed(moduleName: string): number?
	local cached = speeds[moduleName]
	if type(cached) == "number" then
		return cached
	elseif cached == false then
		return nil
	end
	local found: number? = nil
	local models = script.Parent:FindFirstChild("DinoModels")
	local module = models and models:FindFirstChild(moduleName)
	if module and module:IsA("ModuleScript") then
		local ok, raw = pcall(require, module)
		local anims = ok and type(raw) == "table" and raw.Anims
		local walk = type(anims) == "table" and anims.Walk
		local speed = type(walk) == "table" and walk.Speed
		if type(speed) == "number" and speed == speed and speed > 0 then
			found = speed
		end
	end
	speeds[moduleName] = found or false
	return found
end

return Roam
