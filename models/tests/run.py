"""Lance le test hors Studio des dinos : DinoBuilder (src/shared) + modules DinoModels + poses attendues.

    python models/tests/run.py [--luau chemin/vers/luau]

Il faut l'interpréteur luau (https://github.com/luau-lang/luau/releases, ou celui de Rokit : ~/.rokit/bin/luau).
Les poses attendues viennent de models/tests/make_expect.py (relancé ici automatiquement)."""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

# faux environnement Roblox minimal : Vector3, CFrame (vraies maths), Color3, Enum, script
MOCKS = r'''
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return setmetatable({ X = v.X / m, Y = v.Y / m, Z = v.Z / m }, V3)
	end
	return rawget(V3, k)
end
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3.Cross = function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }
local function mm(A, B)
	local C = {}
	for i = 1, 3 do
		C[i] = {}
		for j = 1, 3 do
			C[i][j] = A[i][1] * B[1][j] + A[i][2] * B[2][j] + A[i][3] * B[3][j]
		end
	end
	return C
end
local function mv(A, p)
	return v3(A[1][1] * p.X + A[1][2] * p.Y + A[1][3] * p.Z, A[2][1] * p.X + A[2][2] * p.Y + A[2][3] * p.Z,
		A[3][1] * p.X + A[3][2] * p.Y + A[3][3] * p.Z)
end
local I = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
local CF = {}
CF.__index = function(c, k)
	if k == "Position" then return c.P end
	return rawget(CF, k)
end
local function cf(R, p) return setmetatable({ R = R, P = p }, CF) end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then return cf(mm(a.R, b.R), a.P + mv(a.R, b.P)) end
	return a.P + mv(a.R, b)
end
local CFrame = {
	new = function(p, y, z)
		if type(p) == "number" then return cf(I, v3(p, y, z)) end
		return cf(I, p or v3(0, 0, 0))
	end,
	Angles = function(rx, ry, rz)
		local ca, sa, cb, sb, cc, sc = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
		local Rx = { { 1, 0, 0 }, { 0, ca, -sa }, { 0, sa, ca } }
		local Ry = { { cb, 0, sb }, { 0, 1, 0 }, { -sb, 0, cb } }
		local Rz = { { cc, -sc, 0 }, { sc, cc, 0 }, { 0, 0, 1 } }
		return cf(mm(mm(Rx, Ry), Rz), v3(0, 0, 0))
	end,
}
CFrame.identity = cf(I, v3(0, 0, 0))
CFrame.fromMatrix = function(p, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return cf({ { vx.X, vy.X, vz.X }, { vx.Y, vy.Y, vz.Y }, { vx.Z, vy.Z, vz.Z } }, p)
end
local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
local Enum = setmetatable({}, { __index = function(_, k)
	return setmetatable({}, { __index = function(_, kk) return k .. "." .. kk end })
end })
local script = { Parent = nil }
'''


def with_mocks(src):
    first, rest = src.split("\n", 1)
    if first.startswith("--!"):
        return first + "\n" + MOCKS + rest
    return MOCKS + src


def find_luau():
    # le binaire rangé par Rokit marche sans manifeste (le raccourci ~/.rokit/bin/luau en demande un)
    stored = sorted(glob.glob(os.path.expanduser("~/.rokit/tool-storage/luau-lang/luau/*/luau*")))
    if stored:
        return stored[-1]
    return shutil.which("luau") or "luau"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default=find_luau())
    a = ap.parse_args()
    subprocess.run([sys.executable, os.path.join(HERE, "make_expect.py")], check=True)
    tmp = tempfile.mkdtemp(prefix="saf_dino_test_")
    try:
        src = open(os.path.join(ROOT, "src", "shared", "DinoBuilder.luau"), encoding="utf-8").read()
        open(os.path.join(tmp, "DinoBuilder.luau"), "w", encoding="utf-8").write(with_mocks(src))
        os.makedirs(os.path.join(tmp, "models"))
        os.makedirs(os.path.join(tmp, "expect"))
        names = []
        for f in sorted(glob.glob(os.path.join(ROOT, "src", "shared", "DinoModels", "*.luau"))):
            name = os.path.splitext(os.path.basename(f))[0]
            names.append(name)
            t = open(f, encoding="utf-8").read()
            open(os.path.join(tmp, "models", name + ".luau"), "w", encoding="utf-8").write(with_mocks(t))
            shutil.copy(os.path.join(HERE, "expect", name + ".luau"), os.path.join(tmp, "expect", name + ".luau"))
        open(os.path.join(tmp, "species.luau"), "w", encoding="utf-8").write(
            "return { " + ", ".join('"%s"' % n for n in names) + " }\n")
        shutil.copy(os.path.join(HERE, "t_dino.luau"), os.path.join(tmp, "t_dino.luau"))
        proc = subprocess.run([a.luau, "t_dino.luau"], cwd=tmp, capture_output=True, text=True, encoding="utf-8",
                              errors="replace")
        out = proc.stdout + proc.stderr
        print(out.strip())
        if proc.returncode != 0 or "@@ dino:" not in out or " 0 FAIL" not in out:
            sys.exit(1)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
