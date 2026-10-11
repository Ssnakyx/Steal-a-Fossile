#!/usr/bin/env python3
"""Aperçus des chimères de la fusion hybride (brief 8), sans Blender ni Studio.

    python3 models/hybrids/preview.py                 les recettes de src/server/ServerConfig/Fusion.luau
    python3 models/hybrids/preview.py Ptero-Rex       seulement celles dont le nom contient ce texte
    python3 models/hybrids/preview.py --json DOSSIER  écrit aussi les chimères assemblées en JSON (os, boîtes, poses)

Le vrai code du jeu assemble chaque chimère (src/shared/HybridBuilder.luau, lancé avec l'interpréteur Luau et le faux
Roblox de tools/luau_tests), puis ce script dessine ses boîtes en projection orthographique : profil, face, dessus au
repos, puis trois quarts pour Idle, Walk, Happy (ailes greffées qui battent) et Index. La silhouette grise de 5 studs
est l'avatar. Sortie : models/previews/hybrids/<Nom>.png et la planche _toutes.png. Le brief 9 refait les rendus dans
Blender et corrige les jointures avec les réglages Tweak des recettes.
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "luau_tests"))
import run  # noqa: E402  (tools/luau_tests/run.py : arbre du jeu + faux Roblox)

OUT = os.path.join(ROOT, "models", "previews", "hybrids")

# (état, instant en fraction de la durée) des vues trois quarts
FRAMES = [("Idle", 0.0), ("Walk", 0.3), ("Happy", 0.45), ("Index", 0.2)]

DUMP = r'''
local env = require("./env")
local CFrame = env.CFrame
env.setSide("server")
local DinoBuilder = env.module("src/shared/DinoBuilder")
local HybridBuilder = env.module("src/shared/HybridBuilder")
local Species = env.module("src/shared/Config/Species")
local Fusion = env.module("src/server/ServerConfig/Fusion")
local filter = FILTER
local frames = FRAMES

local function num(x)
	return string.format("%.4f", x)
end

local function encode(v)
	local t = type(v)
	if t == "number" then
		return num(v)
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in v do
				table.insert(parts, encode(x))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in v do
			table.insert(parts, string.format("%q", tostring(k)) .. ":" .. encode(x))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local function v3(v)
	return { v.X, v.Y, v.Z }
end

for _, recipe in Fusion.Recipes do
	if filter ~= "" and not string.find(string.lower(recipe.Name), string.lower(filter), 1, true) then
		continue
	end
	local a, b = Species.ByName[recipe.Head], Species.ByName[recipe.Body]
	local key = HybridBuilder.Key(a.Model, b.Model, recipe.Tweak)
	local data = HybridBuilder.Ensure(key)
	if not data then
		print("@@MISSING " .. recipe.Name .. " " .. key)
		continue
	end
	local out = {
		Name = recipe.Name, Key = key, Head = recipe.Head, Body = recipe.Body, Family = data.Family,
		Boxes = #data.Boxes, Size = v3(data.Size), BaseSize = b.BaseSize, Frames = {},
		Bones = {}, Clips = {},
	}
	for _, bone in data.Bones do
		table.insert(out.Bones, { Name = bone.Name, Parent = bone.Parent or "", Pivot = v3(bone.Pivot), Rest = if bone.Rest then v3(bone.Rest) else { 0, 0, 0 } })
	end
	for name, clip in data.Clips do
		out.Clips[name] = clip.Length
	end
	local function frame(state, at)
		local clip = data.Clips[state] or data.Clips.Idle
		local pose = DinoBuilder.Sample(clip, clip.Length * at)
		local solved = DinoBuilder.Solve(data, pose, 1, {})
		local boxes = {}
		for _, box in data.Boxes do
			local cf = (solved[box.Bone] or CFrame.identity) * CFrame.new(box.Center)
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			table.insert(boxes, {
				v3(cf.Position), { r.X, r.Y, r.Z, u.X, u.Y, u.Z, -l.X, -l.Y, -l.Z }, v3(box.Size),
				{ box.Color.R, box.Color.G, box.Color.B }, box.Material, box.Bone,
			})
		end
		return { State = clip.Name, At = at, Boxes = boxes }
	end
	table.insert(out.Frames, frame("Idle", 0))
	for _, f in frames do
		table.insert(out.Frames, frame(f[1], f[2]))
	end
	print("@@H " .. encode(out))
end
print("@@DONE")
'''


def dump(filter_text):
    run.setup_tools.ensure(quiet=True)
    luau = run.setup_tools.tool("luau")
    build = run.build_tree()
    tests_dir = os.path.join(build, "tools", "luau_tests")
    frames = "{ " + ", ".join('{ "%s", %s }' % (s, at) for s, at in FRAMES) + " }"
    script = DUMP.replace("FILTER", json.dumps(filter_text)).replace("FRAMES", frames, 1)
    open(os.path.join(tests_dir, "hybrid_dump.luau"), "w", encoding="utf-8").write(script)
    proc = subprocess.run([luau, "hybrid_dump.luau"], cwd=tests_dir, capture_output=True, text=True, timeout=run.TIMEOUT)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0 or "@@DONE" not in out:
        print(run.clean_output(out[-4000:], build))
        sys.exit(1)
    hybrids = []
    for line in out.split("\n"):
        if line.startswith("@@H "):
            hybrids.append(json.loads(line[4:]))
        elif line.startswith("@@MISSING"):
            print("sans modèle :", line[10:])
    return hybrids


# ====================================================================== dessin

def norm(v):
    m = math.sqrt(sum(x * x for x in v)) or 1
    return [x / m for x in v]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def camera(d, up=(0, 1, 0)):
    d = norm(d)
    r = norm(cross(d, up))
    u = cross(r, d)
    return d, r, u


VIEWS = {
    "side": camera((1, 0, 0)),
    "front": camera((0, 0, 1)),
    "top": camera((0, -1, 0), (0, 0, -1)),
    "3/4": camera((1, -0.55, 0.9)),
}
LIGHT = norm((-0.35, 1, -0.45))
FACES = [  # (axe, signe)
    (0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1),
]


def box_faces(pos, rot, size):
    axes = [rot[0:3], rot[3:6], rot[6:9]]
    half = [s / 2 for s in size]
    out = []
    for axis, sign in FACES:
        n = [sign * c for c in axes[axis]]
        o = [i for i in range(3) if i != axis]
        corners = []
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = list(pos)
            for k in range(3):
                p[k] += n[k] * half[axis] + axes[o[0]][k] * a * half[o[0]] + axes[o[1]][k] * b * half[o[1]]
            corners.append(p)
        out.append((n, corners))
    return out


def scene_faces(boxes, extra=()):
    faces = []
    for pos, rot, size, color, material, *_ in list(boxes) + list(extra):
        for n, corners in box_faces(pos, rot, size):
            faces.append((n, corners, color, material))
    return faces


def project_bounds(faces, view):
    d, r, u = VIEWS[view]
    xs, ys = [], []
    for _, corners, _, _ in faces:
        for p in corners:
            xs.append(dot(p, r))
            ys.append(dot(p, u))
    return min(xs), max(xs), min(ys), max(ys)


def draw_view(img, faces, view, origin, scale, ground=True):
    d, r, u = VIEWS[view]
    draw = ImageDraw.Draw(img)
    ox, oy = origin
    visible = []
    for n, corners, color, material in faces:
        if dot(n, d) >= -1e-6:
            continue
        depth = sum(dot(p, d) for p in corners) / 4
        visible.append((depth, n, corners, color, material))
    visible.sort(key=lambda f: -f[0])
    if ground and view != "top":
        y0 = oy
        draw.line([(0, y0), (img.width, y0)], fill=(150, 150, 140), width=1)
    for depth, n, corners, color, material in visible:
        shade = 0.55 + 0.45 * max(0.0, dot(n, LIGHT))
        if material == "Neon":
            shade = 1.1
        c = tuple(min(255, int(255 * x * shade)) for x in color)
        pts = [(ox + dot(p, r) * scale, oy - dot(p, u) * scale) for p in corners]
        outline = tuple(int(x * 0.6) for x in c)
        draw.polygon(pts, fill=c, outline=outline)


def avatar(size_x):
    # avatar gris de 5 studs à côté du dino (corps 2 x 3, tête 1,2)
    x = size_x / 2 + 3
    rot = [1, 0, 0, 0, 1, 0, 0, 0, 1]
    grey = (0.62, 0.62, 0.64)
    return [
        ([x, 1, 0], rot, [1.8, 2, 1], grey, "Plastic"),
        ([x, 2.9, 0], rot, [2, 1.8, 1], grey, "Plastic"),
        ([x, 4.4, 0], rot, [1.2, 1.2, 1.2], grey, "Plastic"),
    ]


def render(h, font, small):
    cell = 300
    pad = 10
    rest = h["Frames"][0]
    extra = avatar(h["Size"][0])
    static_views = ["side", "front", "top"]
    # échelle commune : la plus grande étendue sur toutes les vues
    span = 1
    all_faces = [scene_faces(f["Boxes"], extra) for f in h["Frames"]]
    for view in VIEWS:
        for faces in all_faces:
            x0, x1, y0, y1 = project_bounds(faces, view)
            span = max(span, x1 - x0, y1 - y0)
    scale = (cell - 2 * pad) / span
    img = Image.new("RGB", (cell * 4, cell * 2 + 34), (246, 244, 238))
    draw = ImageDraw.Draw(img)
    title = "%s  =  tête %s + corps %s   (%s, %d pièces, %.0f x %.0f x %.0f studs)" % (
        h["Name"], h["Head"], h["Body"], h["Family"], h["Boxes"], h["Size"][0], h["Size"][1], h["Size"][2])
    draw.text((8, 8), title, fill=(30, 30, 30), font=font)
    labels = ["profil", "face", "dessus", "trois quarts : Idle"]
    for i, view in enumerate(static_views + ["3/4"]):
        faces = all_faces[0]
        x0, x1, y0, y1 = project_bounds(faces, view)
        cx = i * cell + cell / 2 - (x0 + x1) / 2 * scale
        cy = 34 + cell - pad - (0 - min(0, y0)) * scale if view != "top" else 34 + cell / 2 + (y0 + y1) / 2 * scale
        draw_view(img, faces, view, (cx, cy), scale)
        draw.text((i * cell + 6, 36), labels[i], fill=(90, 90, 90), font=small)
    for j, frame in enumerate(h["Frames"][1:]):
        faces = all_faces[j + 1]
        x0, x1, y0, y1 = project_bounds(faces, "3/4")
        cx = j * cell + cell / 2 - (x0 + x1) / 2 * scale
        cy = 34 + 2 * cell - pad - (0 - min(0, y0)) * scale
        draw_view(img, faces, "3/4", (cx, cy), scale)
        draw.text((j * cell + 6, 36 + cell), "%s (%d %%)" % (frame["State"], round(frame["At"] * 100)), fill=(90, 90, 90), font=small)
    for k in range(1, 4):
        draw.line([(k * cell, 34), (k * cell, img.height)], fill=(225, 222, 214))
    draw.line([(0, 34 + cell), (img.width, 34 + cell)], fill=(225, 222, 214))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("filter", nargs="?", default="")
    ap.add_argument("--json", help="dossier où écrire les chimères assemblées (JSON)")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    hybrids = dump(a.filter)
    if not hybrids:
        print("aucune chimère")
        return 1
    os.makedirs(a.out, exist_ok=True)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 15)
        small = ImageFont.truetype("DejaVuSans.ttf", 12)
    except OSError:
        font = small = ImageFont.load_default()
    sheets = []
    for h in hybrids:
        img = render(h, font, small)
        name = re.sub(r"[^\w-]", "", h["Name"])
        path = os.path.join(a.out, name + ".png")
        img.save(path)
        sheets.append(img)
        print("%-15s %-24s %3d pièces  %5.1f x %5.1f x %5.1f  -> %s" % (
            h["Name"], h["Key"], h["Boxes"], h["Size"][0], h["Size"][1], h["Size"][2], os.path.relpath(path, ROOT)))
        if a.json:
            os.makedirs(a.json, exist_ok=True)
            json.dump(h, open(os.path.join(a.json, name + ".json"), "w"))
    if len(sheets) > 1:
        w, hgt = sheets[0].width // 2, sheets[0].height // 2
        cols = 3
        rows = (len(sheets) + cols - 1) // cols
        board = Image.new("RGB", (w * cols, hgt * rows), (246, 244, 238))
        for i, img in enumerate(sheets):
            board.paste(img.resize((w, hgt), Image.LANCZOS), ((i % cols) * w, (i // cols) * hgt))
        board.save(os.path.join(a.out, "_toutes.png"))
        print("planche ->", os.path.relpath(os.path.join(a.out, "_toutes.png"), ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
