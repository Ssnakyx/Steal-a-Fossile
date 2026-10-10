-- Types de données de Roblox pour le faux Roblox des tests (env.luau) : Vector3, Vector2, CFrame (rotations comprises),
-- Color3, UDim, UDim2, ColorSequence, NumberSequence, NumberRange, Rect, TweenInfo, Font, BrickColor, Random, DateTime,
-- Ray, RaycastParams, OverlapParams, PhysicalProperties, Region3, Axes, Faces, Content.
-- Comme dans Roblox : valeurs immuables, comparaison par valeur (==), membre inconnu = erreur, typeof() donne le nom.

local D = {}

local function invalid(typeName: string, key: any)
	error(string.format("%s is not a valid member of %s", tostring(key), typeName), 3)
end

local function immutable(typeName: string)
	return function(_, key)
		error(string.format("%s cannot be assigned to (%s is immutable)", tostring(key), typeName), 2)
	end
end

local function fmt(n: number): string
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.6g", n)
end

-- ===== Vector3 =====

local V3 = { __type = "Vector3" }
local V3Methods = {}

local function v3(x: number?, y: number?, z: number?): any
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end

V3.__index = function(self, key)
	local method = V3Methods[key]
	if method then
		return method
	end
	if key == "Magnitude" or key == "magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" or key == "unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif key == "x" then
		return self.X
	elseif key == "y" then
		return self.Y
	elseif key == "z" then
		return self.Z
	end
	invalid("Vector3", key)
end
V3.__newindex = immutable("Vector3")
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(self)
	return fmt(self.X) .. ", " .. fmt(self.Y) .. ", " .. fmt(self.Z)
end
local function isV3(value: any): boolean
	return type(value) == "table" and getmetatable(value) == V3
end
V3.__add = function(a, b)
	if not (isV3(a) and isV3(b)) then
		error("attempt to perform arithmetic (add) on Vector3 and " .. (if isV3(a) then typeof(b) else typeof(a)), 2)
	end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	if not (isV3(a) and isV3(b)) then
		error("attempt to perform arithmetic (sub) on Vector3", 2)
	end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	elseif isV3(a) and isV3(b) then
		return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	error("attempt to perform arithmetic (mul) on Vector3", 2)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	elseif type(a) == "number" then
		return v3(a / b.X, a / b.Y, a / b.Z)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__idiv = function(a, b)
	if type(b) == "number" then
		return v3(a.X // b, a.Y // b, a.Z // b)
	end
	return v3(a.X // b.X, a.Y // b.Y, a.Z // b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
function V3Methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3Methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3Methods.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3Methods.FuzzyEq(a, b, epsilon)
	local e = epsilon or 1e-5
	return math.abs(a.X - b.X) <= e and math.abs(a.Y - b.Y) <= e and math.abs(a.Z - b.Z) <= e
end
function V3Methods.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3Methods.Floor(a)
	return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z))
end
function V3Methods.Ceil(a)
	return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z))
end
function V3Methods.Sign(a)
	return v3(math.sign(a.X), math.sign(a.Y), math.sign(a.Z))
end
function V3Methods.Min(a, ...)
	local r = a
	for _, b in { ... } do
		r = v3(math.min(r.X, b.X), math.min(r.Y, b.Y), math.min(r.Z, b.Z))
	end
	return r
end
function V3Methods.Max(a, ...)
	local r = a
	for _, b in { ... } do
		r = v3(math.max(r.X, b.X), math.max(r.Y, b.Y), math.max(r.Z, b.Z))
	end
	return r
end
function V3Methods.Angle(a, b)
	local m = a.Magnitude * b.Magnitude
	if m == 0 then
		return 0
	end
	return math.acos(math.clamp(a:Dot(b) / m, -1, 1))
end

D.Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
	FromNormalId = function(normal)
		local map = { Right = v3(1, 0, 0), Left = v3(-1, 0, 0), Top = v3(0, 1, 0), Bottom = v3(0, -1, 0), Back = v3(0, 0, 1), Front = v3(0, 0, -1) }
		return map[normal.Name]
	end,
}

-- ===== Vector2 =====

local V2 = { __type = "Vector2" }
local V2Methods = {}
local function v2(x: number?, y: number?): any
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(self, key)
	local method = V2Methods[key]
	if method then
		return method
	end
	if key == "Magnitude" or key == "magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	elseif key == "Unit" or key == "unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y)
		return v2(self.X / m, self.Y / m)
	elseif key == "x" then
		return self.X
	elseif key == "y" then
		return self.Y
	end
	invalid("Vector2", key)
end
V2.__newindex = immutable("Vector2")
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2.__tostring = function(self)
	return fmt(self.X) .. ", " .. fmt(self.Y)
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
function V2Methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
function V2Methods.Cross(a, b)
	return a.X * b.Y - a.Y * b.X
end
function V2Methods.Lerp(a, b, t)
	return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end
function V2Methods.FuzzyEq(a, b, epsilon)
	local e = epsilon or 1e-5
	return math.abs(a.X - b.X) <= e and math.abs(a.Y - b.Y) <= e
end
function V2Methods.Abs(a)
	return v2(math.abs(a.X), math.abs(a.Y))
end
function V2Methods.Floor(a)
	return v2(math.floor(a.X), math.floor(a.Y))
end
function V2Methods.Ceil(a)
	return v2(math.ceil(a.X), math.ceil(a.Y))
end
function V2Methods.Min(a, b)
	return v2(math.min(a.X, b.X), math.min(a.Y, b.Y))
end
function V2Methods.Max(a, b)
	return v2(math.max(a.X, b.X), math.max(a.Y, b.Y))
end
D.Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1), xAxis = v2(1, 0), yAxis = v2(0, 1) }

-- ===== CFrame =====

local CF = { __type = "CFrame" }
local CFMethods = {}

-- position (x, y, z) et matrice de rotation en lignes : r00 r01 r02 / r10 r11 r12 / r20 r21 r22
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22): any
	return setmetatable({
		_x = x, _y = y, _z = z,
		_r = { r00 or 1, r01 or 0, r02 or 0, r10 or 0, r11 or 1, r12 or 0, r20 or 0, r21 or 0, r22 or 1 },
	}, CF)
end

local function rotation(m: { number }, x, y, z)
	return cf(x, y, z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end

local function matMul(a: { number }, b: { number }): { number }
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end

local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

local function fromQuaternion(x, y, z, qx, qy, qz, qw)
	local n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
	if n == 0 then
		return cf(x, y, z)
	end
	qx, qy, qz, qw = qx / n, qy / n, qz / n, qw / n
	return cf(
		x, y, z,
		1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
		2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
		2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)
	)
end

local function toQuaternion(r: { number }): (number, number, number, number)
	local trace = r[1] + r[5] + r[9]
	if trace > 0 then
		local s = math.sqrt(1 + trace) * 2
		return (r[8] - r[6]) / s, (r[3] - r[7]) / s, (r[4] - r[2]) / s, 0.25 * s
	elseif r[1] > r[5] and r[1] > r[9] then
		local s = math.sqrt(1 + r[1] - r[5] - r[9]) * 2
		return 0.25 * s, (r[2] + r[4]) / s, (r[3] + r[7]) / s, (r[8] - r[6]) / s
	elseif r[5] > r[9] then
		local s = math.sqrt(1 + r[5] - r[1] - r[9]) * 2
		return (r[2] + r[4]) / s, 0.25 * s, (r[6] + r[8]) / s, (r[3] - r[7]) / s
	end
	local s = math.sqrt(1 + r[9] - r[1] - r[5]) * 2
	return (r[3] + r[7]) / s, (r[6] + r[8]) / s, 0.25 * s, (r[4] - r[2]) / s
end

local function lookAt(at, target, up)
	local upVector = up or v3(0, 1, 0)
	local look = target - at
	if look.Magnitude == 0 then
		return cf(at.X, at.Y, at.Z)
	end
	local back = -look.Unit
	local right = upVector:Cross(back)
	if right.Magnitude < 1e-6 then
		right = v3(1, 0, 0):Cross(back)
		if right.Magnitude < 1e-6 then
			right = v3(0, 0, 1):Cross(back)
		end
	end
	right = right.Unit
	local newUp = back:Cross(right)
	return cf(at.X, at.Y, at.Z, right.X, newUp.X, back.X, right.Y, newUp.Y, back.Y, right.Z, newUp.Z, back.Z)
end

local function newCF(...): any
	local n = select("#", ...)
	local a, b, c = ...
	if n == 0 then
		return cf(0, 0, 0)
	elseif n == 1 then
		return cf(a.X, a.Y, a.Z)
	elseif n == 2 then
		return lookAt(a, b)
	elseif n == 3 then
		return cf(a, b, c)
	elseif n == 7 then
		local x, y, z, qx, qy, qz, qw = ...
		return fromQuaternion(x, y, z, qx, qy, qz, qw)
	elseif n == 12 then
		return cf(...)
	end
	error("CFrame.new : arguments invalides (" .. n .. ")", 2)
end

CF.__index = function(self, key)
	local method = CFMethods[key]
	if method then
		return method
	end
	local r = self._r
	if key == "Position" or key == "p" then
		return v3(self._x, self._y, self._z)
	elseif key == "X" or key == "x" then
		return self._x
	elseif key == "Y" or key == "y" then
		return self._y
	elseif key == "Z" or key == "z" then
		return self._z
	elseif key == "LookVector" or key == "lookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif key == "RightVector" or key == "XVector" then
		return v3(r[1], r[4], r[7])
	elseif key == "UpVector" or key == "YVector" then
		return v3(r[2], r[5], r[8])
	elseif key == "ZVector" then
		return v3(r[3], r[6], r[9])
	elseif key == "Rotation" then
		return rotation(r, 0, 0, 0)
	end
	invalid("CFrame", key)
end
CF.__newindex = immutable("CFrame")
CF.__eq = function(a, b)
	if a._x ~= b._x or a._y ~= b._y or a._z ~= b._z then
		return false
	end
	for i = 1, 9 do
		if a._r[i] ~= b._r[i] then
			return false
		end
	end
	return true
end
CF.__tostring = function(self)
	local parts = { fmt(self._x), fmt(self._y), fmt(self._z) }
	for i = 1, 9 do
		table.insert(parts, fmt(self._r[i]))
	end
	return table.concat(parts, ", ")
end

local function rotate(r: { number }, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function transpose(r: { number }): { number }
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end

CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local p = rotate(a._r, v3(b._x, b._y, b._z))
		return rotation(matMul(a._r, b._r), a._x + p.X, a._y + p.Y, a._z + p.Z)
	elseif isV3(b) then
		local p = rotate(a._r, b)
		return v3(a._x + p.X, a._y + p.Y, a._z + p.Z)
	end
	error("attempt to perform arithmetic (mul) on CFrame and " .. typeof(b), 2)
end
CF.__add = function(a, b)
	return rotation(a._r, a._x + b.X, a._y + b.Y, a._z + b.Z)
end
CF.__sub = function(a, b)
	return rotation(a._r, a._x - b.X, a._y - b.Y, a._z - b.Z)
end

function CFMethods.Inverse(self)
	local t = transpose(self._r)
	local p = rotate(t, v3(-self._x, -self._y, -self._z))
	return rotation(t, p.X, p.Y, p.Z)
end
function CFMethods.ToWorldSpace(self, other)
	return self * other
end
function CFMethods.ToObjectSpace(self, other)
	return self:Inverse() * other
end
function CFMethods.PointToWorldSpace(self, v)
	return self * v
end
function CFMethods.PointToObjectSpace(self, v)
	return self:Inverse() * v
end
function CFMethods.VectorToWorldSpace(self, v)
	return rotate(self._r, v)
end
function CFMethods.VectorToObjectSpace(self, v)
	return rotate(transpose(self._r), v)
end
function CFMethods.GetComponents(self)
	local r = self._r
	return self._x, self._y, self._z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
CFMethods.components = CFMethods.GetComponents
function CFMethods.ToEulerAnglesXYZ(self)
	local r = self._r
	local y = math.asin(math.clamp(r[3], -1, 1))
	local x = math.atan2(-r[6], r[9])
	local z = math.atan2(-r[2], r[1])
	return x, y, z
end
function CFMethods.ToEulerAnglesYXZ(self)
	local r = self._r
	local x = math.asin(math.clamp(-r[6], -1, 1))
	local y = math.atan2(r[3], r[9])
	local z = math.atan2(r[4], r[5])
	return x, y, z
end
CFMethods.ToOrientation = CFMethods.ToEulerAnglesYXZ
function CFMethods.ToAxisAngle(self)
	local qx, qy, qz, qw = toQuaternion(self._r)
	local angle = 2 * math.acos(math.clamp(qw, -1, 1))
	local s = math.sqrt(1 - qw * qw)
	if s < 1e-6 then
		return v3(1, 0, 0), 0
	end
	return v3(qx / s, qy / s, qz / s), angle
end
function CFMethods.Lerp(a, b, t)
	local ax, ay, az, aw = toQuaternion(a._r)
	local bx, by, bz, bw = toQuaternion(b._r)
	local dot = ax * bx + ay * by + az * bz + aw * bw
	if dot < 0 then
		bx, by, bz, bw, dot = -bx, -by, -bz, -bw, -dot
	end
	local qx, qy, qz, qw
	if dot > 0.9995 then
		qx, qy, qz, qw = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, aw + (bw - aw) * t
	else
		local theta = math.acos(dot)
		local sa, sb = math.sin((1 - t) * theta) / math.sin(theta), math.sin(t * theta) / math.sin(theta)
		qx, qy, qz, qw = ax * sa + bx * sb, ay * sa + by * sb, az * sa + bz * sb, aw * sa + bw * sb
	end
	return fromQuaternion(a._x + (b._x - a._x) * t, a._y + (b._y - a._y) * t, a._z + (b._z - a._z) * t, qx, qy, qz, qw)
end
function CFMethods.FuzzyEq(a, b, epsilon)
	local e = epsilon or 1e-5
	if math.abs(a._x - b._x) > e or math.abs(a._y - b._y) > e or math.abs(a._z - b._z) > e then
		return false
	end
	for i = 1, 9 do
		if math.abs(a._r[i] - b._r[i]) > e then
			return false
		end
	end
	return true
end
function CFMethods.Orthonormalize(self)
	return self
end

local function angles(x, y, z)
	return rotation(matMul(matMul(rx(x or 0), ry(y or 0)), rz(z or 0)), 0, 0, 0)
end
local function orientation(x, y, z)
	return rotation(matMul(matMul(ry(y or 0), rx(x or 0)), rz(z or 0)), 0, 0, 0)
end

D.CFrame = {
	new = newCF,
	identity = cf(0, 0, 0),
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	fromEulerAnglesYXZ = orientation,
	fromOrientation = orientation,
	fromEulerAngles = function(x, y, z, order)
		if order and order.Name == "YXZ" then
			return orientation(x, y, z)
		end
		return angles(x, y, z)
	end,
	fromAxisAngle = function(axis, angle)
		local u = axis.Unit
		local s = math.sin(angle / 2)
		return fromQuaternion(0, 0, 0, u.X * s, u.Y * s, u.Z * s, math.cos(angle / 2))
	end,
	lookAt = lookAt,
	lookAlong = function(at, direction, up)
		return lookAt(at, at + direction, up)
	end,
	fromMatrix = function(pos, vx, vy, vz)
		local z = vz or vx:Cross(vy).Unit
		return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, z.X, vx.Y, vy.Y, z.Y, vx.Z, vy.Z, z.Z)
	end,
}

-- ===== Color3 =====

local C3 = { __type = "Color3" }
local C3Methods = {}
local function c3(r: number?, g: number?, b: number?): any
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
C3.__index = function(self, key)
	local method = C3Methods[key]
	if method then
		return method
	end
	if key == "r" then
		return self.R
	elseif key == "g" then
		return self.G
	elseif key == "b" then
		return self.B
	end
	invalid("Color3", key)
end
C3.__newindex = immutable("Color3")
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
C3.__tostring = function(self)
	return fmt(self.R) .. ", " .. fmt(self.G) .. ", " .. fmt(self.B)
end
function C3Methods.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3Methods.ToHSV(self)
	local r, g, b = self.R, self.G, self.B
	local maxc, minc = math.max(r, g, b), math.min(r, g, b)
	local v = maxc
	local delta = maxc - minc
	local s = if maxc == 0 then 0 else delta / maxc
	local h = 0
	if delta ~= 0 then
		if maxc == r then
			h = ((g - b) / delta) % 6
		elseif maxc == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end
		h /= 6
	end
	return h, s, v
end
function C3Methods.ToHex(self)
	local function byte(x)
		return math.clamp(math.floor(x * 255 + 0.5), 0, 255)
	end
	return string.format("%02X%02X%02X", byte(self.R), byte(self.G), byte(self.B))
end
local function fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i %= 6
	if i == 0 then
		return c3(v, t, p)
	elseif i == 1 then
		return c3(q, v, p)
	elseif i == 2 then
		return c3(p, v, t)
	elseif i == 3 then
		return c3(p, q, v)
	elseif i == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end
D.Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = fromHSV,
	toHSV = function(c)
		return c:ToHSV()
	end,
	fromHex = function(hex)
		local h = string.gsub(hex, "#", "")
		if #h == 3 then
			h = string.gsub(h, ".", "%0%0")
		end
		return c3(tonumber(string.sub(h, 1, 2), 16) / 255, tonumber(string.sub(h, 3, 4), 16) / 255, tonumber(string.sub(h, 5, 6), 16) / 255)
	end,
}

-- ===== UDim, UDim2 =====

local UD = { __type = "UDim" }
local function udim(scale, offset): any
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UD)
end
UD.__index = function(_, key)
	invalid("UDim", key)
end
UD.__newindex = immutable("UDim")
UD.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UD.__add = function(a, b)
	return udim(a.Scale + b.Scale, a.Offset + b.Offset)
end
UD.__sub = function(a, b)
	return udim(a.Scale - b.Scale, a.Offset - b.Offset)
end
UD.__unm = function(a)
	return udim(-a.Scale, -a.Offset)
end
UD.__tostring = function(self)
	return fmt(self.Scale) .. ", " .. fmt(self.Offset)
end
D.UDim = { new = udim }

local UD2 = { __type = "UDim2" }
local UD2Methods = {}
local function udim2(...): any
	local n = select("#", ...)
	local a, b = ...
	if n == 2 and type(a) == "table" then
		return setmetatable({ X = a, Y = b }, UD2)
	end
	local xs, xo, ys, yo = ...
	return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UD2)
end
UD2.__index = function(self, key)
	local method = UD2Methods[key]
	if method then
		return method
	end
	if key == "Width" then
		return self.X
	elseif key == "Height" then
		return self.Y
	end
	invalid("UDim2", key)
end
UD2.__newindex = immutable("UDim2")
UD2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UD2.__add = function(a, b)
	return udim2(a.X + b.X, a.Y + b.Y)
end
UD2.__sub = function(a, b)
	return udim2(a.X - b.X, a.Y - b.Y)
end
UD2.__unm = function(a)
	return udim2(-a.X, -a.Y)
end
UD2.__tostring = function(self)
	return "{" .. tostring(self.X) .. "}, {" .. tostring(self.Y) .. "}"
end
function UD2Methods.Lerp(a, b, t)
	return udim2(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end
D.UDim2 = {
	new = udim2,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
}

-- ===== Séquences, plages, rectangles =====

local function simple(typeName: string, fields: { string })
	local mt = { __type = typeName }
	mt.__index = function(_, key)
		invalid(typeName, key)
	end
	mt.__newindex = immutable(typeName)
	mt.__eq = function(a, b)
		for _, field in fields do
			if a[field] ~= b[field] then
				return false
			end
		end
		return true
	end
	mt.__tostring = function(self)
		local parts = {}
		for _, field in fields do
			table.insert(parts, tostring(self[field]))
		end
		return table.concat(parts, " ")
	end
	return function(values: { [string]: any }): any
		return setmetatable(values, mt)
	end
end

local makeCSK = simple("ColorSequenceKeypoint", { "Time", "Value" })
D.ColorSequenceKeypoint = {
	new = function(time, value)
		return makeCSK({ Time = time, Value = value })
	end,
}
local makeCS = simple("ColorSequence", { "Keypoints" })
D.ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			if #a < 2 then
				error("ColorSequence.new : il faut au moins 2 points", 2)
			end
			return makeCS({ Keypoints = table.clone(a) })
		end
		return makeCS({ Keypoints = { D.ColorSequenceKeypoint.new(0, a), D.ColorSequenceKeypoint.new(1, b or a) } })
	end,
}
local makeNSK = simple("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
D.NumberSequenceKeypoint = {
	new = function(time, value, envelope)
		return makeNSK({ Time = time, Value = value, Envelope = envelope or 0 })
	end,
}
local makeNS = simple("NumberSequence", { "Keypoints" })
D.NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then
			return makeNS({ Keypoints = table.clone(a) })
		end
		return makeNS({ Keypoints = { D.NumberSequenceKeypoint.new(0, a), D.NumberSequenceKeypoint.new(1, b or a) } })
	end,
}
local makeNR = simple("NumberRange", { "Min", "Max" })
D.NumberRange = {
	new = function(min, max)
		return makeNR({ Min = min, Max = max or min })
	end,
}
local makeRect = simple("Rect", { "Min", "Max" })
D.Rect = {
	new = function(a, b, c, d)
		local min, max
		if type(a) == "number" then
			min, max = v2(a, b), v2(c, d)
		else
			min, max = a or v2(), b or v2()
		end
		return makeRect({ Min = min, Max = max, Width = max.X - min.X, Height = max.Y - min.Y })
	end,
}
local makeTweenInfo = simple("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" })
D.makeTweenInfo = makeTweenInfo
local makeFont = simple("Font", { "Family", "Weight", "Style" })
D.makeFont = makeFont
local makePhysical = simple("PhysicalProperties", { "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight" })
D.PhysicalProperties = {
	new = function(density, friction, elasticity, frictionWeight, elasticityWeight)
		if type(density) ~= "number" then
			return makePhysical({ Density = 0.7, Friction = 0.3, Elasticity = 0.5, FrictionWeight = 1, ElasticityWeight = 1 })
		end
		return makePhysical({ Density = density, Friction = friction or 0.3, Elasticity = elasticity or 0.5, FrictionWeight = frictionWeight or 1, ElasticityWeight = elasticityWeight or 1 })
	end,
}
local makeRay = simple("Ray", { "Origin", "Direction" })
D.Ray = {
	new = function(origin, direction)
		return makeRay({ Origin = origin, Direction = direction, Unit = nil })
	end,
}
local makeRegion = simple("Region3", { "CFrame", "Size" })
D.Region3 = {
	new = function(min, max)
		local center = (min + max) / 2
		return makeRegion({ CFrame = newCF(center), Size = max - min })
	end,
}
local makeAxes = simple("Axes", { "X", "Y", "Z" })
D.Axes = {
	new = function(...)
		local values = { X = false, Y = false, Z = false }
		for _, item in { ... } do
			values[item.Name] = true
		end
		return makeAxes(values)
	end,
}
local makeFaces = simple("Faces", { "Top", "Bottom", "Left", "Right", "Back", "Front" })
D.Faces = {
	new = function(...)
		local values = { Top = false, Bottom = false, Left = false, Right = false, Back = false, Front = false }
		for _, item in { ... } do
			values[item.Name] = true
		end
		return makeFaces(values)
	end,
}
local makeContent = simple("Content", { "Uri" })
D.Content = {
	fromUri = function(uri)
		return makeContent({ Uri = uri, SourceType = "Uri" })
	end,
	none = makeContent({ Uri = "", SourceType = "None" }),
}

-- Paramètres modifiables (RaycastParams, OverlapParams) : simples tables typées
local function params(typeName: string, defaults: { [string]: any })
	return {
		new = function()
			local mt = { __type = typeName }
			local values = table.clone(defaults)
			values.FilterDescendantsInstances = {}
			return setmetatable(values, mt)
		end,
	}
end
D.makeParams = params

-- ===== Random =====

local RandomMeta = { __type = "Random" }
RandomMeta.__index = RandomMeta
local function nextRaw(self): number
	-- générateur linéaire congruentiel 48 bits (déterministe)
	self._state = (self._state * 25214903917 + 11) % 281474976710656
	return self._state / 281474976710656
end
function RandomMeta:NextNumber(min, max)
	local a, b = min or 0, max or 1
	return a + (b - a) * nextRaw(self)
end
function RandomMeta:NextInteger(min, max)
	if min > max then
		error("Random:NextInteger : min > max", 2)
	end
	return min + math.floor(nextRaw(self) * (max - min + 1))
end
function RandomMeta:NextUnitVector()
	local z = 2 * nextRaw(self) - 1
	local t = 2 * math.pi * nextRaw(self)
	local r = math.sqrt(1 - z * z)
	return v3(r * math.cos(t), r * math.sin(t), z)
end
function RandomMeta:Shuffle(list)
	for i = #list, 2, -1 do
		local j = self:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end
function RandomMeta:Clone()
	return setmetatable({ _state = self._state }, RandomMeta)
end
local randomCounter = 0
D.Random = {
	new = function(seed)
		randomCounter += 1
		local s = math.floor(math.abs(seed or (randomCounter * 7919))) % 281474976710656
		return setmetatable({ _state = s }, RandomMeta)
	end,
}

-- ===== BrickColor =====

local BrickMeta = { __type = "BrickColor" }
local BRICKS = {
	["Medium stone grey"] = { 194, 163, 162, 165 },
	["White"] = { 1, 242, 243, 243 },
	["Black"] = { 26, 27, 42, 53 },
	["Bright red"] = { 21, 196, 40, 28 },
	["Bright blue"] = { 23, 13, 105, 172 },
	["Bright green"] = { 37, 75, 151, 75 },
	["Bright yellow"] = { 24, 245, 205, 48 },
	["Really red"] = { 1004, 255, 0, 0 },
	["Lime green"] = { 1020, 0, 255, 0 },
	["Dark stone grey"] = { 199, 99, 95, 98 },
	["Institutional white"] = { 1001, 248, 248, 248 },
}
BrickMeta.__index = function(self, key)
	if key == "Name" then
		return self._name
	elseif key == "Number" then
		return self._number
	elseif key == "Color" then
		return self._color
	elseif key == "r" then
		return self._color.R
	elseif key == "g" then
		return self._color.G
	elseif key == "b" then
		return self._color.B
	end
	invalid("BrickColor", key)
end
BrickMeta.__eq = function(a, b)
	return a._name == b._name
end
BrickMeta.__tostring = function(self)
	return self._name
end
local function brick(name: string): any
	local data = BRICKS[name] or BRICKS["Medium stone grey"]
	return setmetatable({ _name = if BRICKS[name] then name else "Medium stone grey", _number = data[1], _color = c3(data[2] / 255, data[3] / 255, data[4] / 255) }, BrickMeta)
end
D.BrickColor = {
	new = function(value, g, b)
		if type(value) == "string" then
			return brick(value)
		elseif type(value) == "number" and g == nil then
			for name, data in BRICKS do
				if data[1] == value then
					return brick(name)
				end
			end
		end
		return brick("Medium stone grey")
	end,
	random = function()
		return brick("Bright blue")
	end,
	White = function()
		return brick("White")
	end,
	Black = function()
		return brick("Black")
	end,
	Red = function()
		return brick("Bright red")
	end,
	Blue = function()
		return brick("Bright blue")
	end,
	Green = function()
		return brick("Bright green")
	end,
	Yellow = function()
		return brick("Bright yellow")
	end,
	Gray = function()
		return brick("Medium stone grey")
	end,
	DarkGray = function()
		return brick("Dark stone grey")
	end,
}

D.isV3 = isV3
D.v3 = v3
D.v2 = v2
D.c3 = c3
D.cf = newCF
D.udim2 = udim2

return D
