#!/usr/bin/env python3
"""Rendus Blender des chimères (brief 9) et des apparences des dinos, à partir du vrai code du jeu.

    python models/hybrids/render.py                  les 12 chimères : rendu de contrôle + planche des états
    python models/hybrids/render.py Ptero            seulement les chimères dont le nom contient « Ptero »
    python models/hybrids/render.py --stills         seulement les rendus de contrôle (face, trois-quarts, profil, dos)
    python models/hybrids/render.py --levels         Normal, Golden et Diamond de chaque espèce et chimère (une planche)
    python models/hybrids/render.py --index          pose d'Index de chaque espèce et chimère (une planche)

Le jeu assemble chaque chimère (HybridBuilder) et la peint (DinoBuilder.Build : niveau, mutation) dans l'interpréteur
Luau avec le faux Roblox de tools/luau_tests (`python3 tools/setup_tools.py` une fois) ; ses animations sont lues par
DinoBuilder.Sample. Blender (headless, comme models/build.py) refait la scène des dinos (armature, cubes, lumière) et
rend chaque pose. Pas de vidéo : quelques instants de chaque état suffisent (règle de Snaky).
Sorties (models/previews/hybrids/) : <Nom>_controle.jpg, <Nom>_planche.jpg, _chimeres.jpg, _niveaux.jpg, _index.jpg."""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
ROOT = os.path.dirname(MODELS)
sys.path.insert(0, os.path.join(ROOT, "tools", "luau_tests"))
sys.path.insert(0, os.path.join(MODELS, "lib"))
import run  # noqa: E402  (tools/luau_tests/run.py : arbre du jeu + faux Roblox)
from post import LABELS, font, save_jpg  # noqa: E402

BLENDER = os.environ.get("BLENDER", r"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
OUT = os.path.join(MODELS, "previews", "hybrids")

# états montrés sur la planche (ceux que le modèle a), avec les instants (fractions de la durée)
STATES = ["Idle", "Walk", "Run", "Happy", "Roar", "Eat", "Sleep", "Spawn", "Wake", "Catch", "Search", "BackToSleep",
          "Fusion", "Index", "TakeOff", "Fly", "Glide", "Land", "Dive", "Jump"]
LOOP_AT = [0.05, 0.38, 0.71]
ONCE_AT = [0.2, 0.5, 0.8]

DUMP = r'''
local env = require("./env")
local CFrame, Vector3 = env.CFrame, env.Vector3
env.setSide("server")
local DinoBuilder = env.module("src/shared/DinoBuilder")
local HybridBuilder = env.module("src/shared/HybridBuilder")
local Species = env.module("src/shared/Config/Species")
local Fusion = env.module("src/server/ServerConfig/Fusion")
local ITEMS = ITEMS_HERE
local STATES = STATES_HERE
local LOOP_AT, ONCE_AT = LOOP_HERE, ONCE_HERE

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
local MATERIAL = { Plastic = "Plastic", SmoothPlastic = "Smooth", Neon = "Neon", Glass = "Glass", Ice = "Ice", Metal = "Metal" }
local CORNERS = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

local recipes = {}
for _, r in Fusion.Recipes do
	recipes[r.Name] = r
end

for _, item in ITEMS do
	local key, title, family
	local recipe = recipes[item.Name]
	if recipe then
		local a, b = Species.ByName[recipe.Head], Species.ByName[recipe.Body]
		key = HybridBuilder.Key(a.Model, b.Model, recipe.Tweak)
		title = recipe.Name .. "  =  tête " .. recipe.Head .. " + corps " .. recipe.Body
	else
		local def = Species.ByName[item.Name] or Species.ByModel[item.Name]
		key = if def then def.Model else item.Name
		title = if def then def.Name else item.Name
	end
	local data = if HybridBuilder.IsHybrid(key) then HybridBuilder.Ensure(key) else DinoBuilder.Get(key)
	if not data then
		print("@@MISSING " .. item.Name)
		continue
	end
	-- peinture du jeu (niveau, mutation) lue sur les pièces construites
	local model = DinoBuilder.Build(data, { Level = item.Level, Mutation = item.Mutation })
	local paint = {}
	for _, p in model:GetChildren() do
		local i = p:GetAttribute("Box")
		if i then
			paint[i] = { math.floor(p.Color.R * 255 + 0.5), math.floor(p.Color.G * 255 + 0.5), math.floor(p.Color.B * 255 + 0.5), MATERIAL[p.Material.Name] or "Plastic" }
		end
	end
	local out = {
		Name = item.Name, Label = item.Label or "", Key = key, Title = title, Family = data.Family,
		Bones = {}, Boxes = {}, Size = v3(data.Size), Height = data.Height, Frames = {},
	}
	for _, bone in data.Bones do
		table.insert(out.Bones, { name = bone.Name, parent = bone.Parent or "", pivot = v3(bone.Pivot), rest = if bone.Rest then v3(bone.Rest) else { 0, 0, 0 } })
	end
	for i, box in data.Boxes do
		local p = paint[i]
		table.insert(out.Boxes, { bone = box.Bone, c = v3(box.Center), s = v3(box.Size), col = { p[1], p[2], p[3] }, mat = p[4] })
	end
	local function frame(state, at)
		local clip = data.Clips[state]
		local pose = if at < 0 then {} else DinoBuilder.Sample(clip, clip.Length * at)
		local solved = DinoBuilder.Solve(data, pose, 1, {})
		local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, box in data.Boxes do
			local cf = (solved[box.Bone] or CFrame.identity) * CFrame.new(box.Center)
			local half = box.Size / 2
			for _, c in CORNERS do
				local w = cf * (half * c)
				lo = lo:Min(w)
				hi = hi:Max(w)
			end
		end
		local p = {}
		for bone, v in pose do
			p[bone] = { v[1], v[2], v[3], v[4], v[5], v[6] }
		end
		return { State = state, At = at, Pose = p, Lo = v3(lo), Hi = v3(hi), Loop = clip and clip.Loop or false }
	end
	table.insert(out.Frames, frame("Rest", -1))
	for _, state in item.States do
		local clip = data.Clips[state]
		if clip then
			for _, at in (if clip.Loop then LOOP_AT else ONCE_AT) do
				table.insert(out.Frames, frame(state, at))
			end
		end
	end
	print("@@H " .. encode(out))
end
print("@@DONE")
'''


def lua_list(values):
    return "{ " + ", ".join(json.dumps(v) if isinstance(v, str) else repr(v) for v in values) + " }"


def lua_items(items):
    rows = []
    for it in items:
        fields = ["Name = %s" % json.dumps(it["Name"]), "States = %s" % lua_list(it.get("States", []))]
        for k in ("Level", "Mutation", "Label"):
            if it.get(k):
                fields.append("%s = %s" % (k, json.dumps(it[k])))
        rows.append("{ " + ", ".join(fields) + " }")
    return "{\n" + ",\n".join(rows) + "\n}"


def dump(items):
    run.setup_tools.ensure(quiet=True)
    luau = run.setup_tools.tool("luau")
    build = run.build_tree()
    tests_dir = os.path.join(build, "tools", "luau_tests")
    script = (DUMP.replace("ITEMS_HERE", lua_items(items)).replace("STATES_HERE", lua_list(STATES))
              .replace("LOOP_HERE", lua_list(LOOP_AT)).replace("ONCE_HERE", lua_list(ONCE_AT)))
    open(os.path.join(tests_dir, "render_dump.luau"), "w", encoding="utf-8").write(script)
    proc = subprocess.run([luau, "render_dump.luau"], cwd=tests_dir, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=run.TIMEOUT)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0 or "@@DONE" not in out:
        print(run.clean_output(out[-4000:], build))
        sys.exit(1)
    found = []
    for line in out.split("\n"):
        if line.startswith("@@H "):
            found.append(json.loads(line[4:]))
        elif line.startswith("@@MISSING"):
            print("sans modèle :", line[10:])
    return found


def recipes():
    """Noms des recettes, dans l'ordre de src/server/ServerConfig/Fusion.luau."""
    text = open(os.path.join(ROOT, "src", "server", "ServerConfig", "Fusion.luau"), encoding="utf-8").read()
    return re.findall(r'\{ Name = "([^"]+)", Head = "([^"]+)", Body = "([^"]+)"', text)


def species():
    text = open(os.path.join(ROOT, "src", "shared", "Config", "Species.luau"), encoding="utf-8").read()
    return re.findall(r'\{ Name = "([^"]+)", Model = "([^"]+)", Family = "([^"]+)"', text)


def blender(items, mode, tmp):
    path = os.path.join(tmp, "items.json")
    json.dump(items, open(path, "w", encoding="utf-8"))
    cmd = [BLENDER, "--background", "--factory-startup", "--python", os.path.join(HERE, "blender_hybrids.py"), "--",
           path, tmp, mode]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    for line in proc.stdout.splitlines():
        if line.startswith(("[rendu]", "Traceback", "  File", "    ")) or "Error" in line:
            print(line)
    if proc.returncode != 0:
        print(proc.stderr[-4000:])
        raise SystemExit("Blender a échoué")


def slug(name):
    return re.sub(r"[^\w-]", "", name)


def sheet_controle(item, tmp):
    names = [("face", "Face"), ("trois-quarts", "Trois-quarts"), ("profil", "Profil"), ("dos", "Dos")]
    ims = [Image.open(os.path.join(tmp, "%s_%s.png" % (slug(item["Name"]), n))).convert("RGB") for n, _ in names]
    w, h = ims[0].size
    head = 70
    img = Image.new("RGB", (w * 2, h * 2 + head), (26, 30, 38))
    for i, im in enumerate(ims):
        img.paste(im, ((i % 2) * w, head + (i // 2) * h))
    d = ImageDraw.Draw(img)
    sx, sy, sz = item["Size"]
    d.text((18, 10), "%s  (%s)" % (item["Title"], item["Family"]), font=font(28, True), fill=(250, 246, 236))
    d.text((18, 44), "%d pièces, %.1f x %.1f x %.1f studs à la taille Normal. Avatar gris = 5 studs." % (
        len(item["Boxes"]), sx, sy, sz), font=font(18), fill=(200, 206, 216))
    for i, (_, label) in enumerate(names):
        d.text(((i % 2) * w + 14, head + (i // 2) * h + 10), label, font=font(22, True), fill=(30, 34, 40))
    out = os.path.join(OUT, "%s_controle.jpg" % slug(item["Name"]))
    save_jpg(img, out, 600)
    return out


def sheet_states(item, tmp):
    rows = []
    groups = {}
    for i, f in enumerate(item["Frames"]):
        if f["State"] != "Rest":
            groups.setdefault(f["State"], []).append(i)
    f_sub = font(18)
    for state, idx in groups.items():
        ims = [Image.open(os.path.join(tmp, "%s_f%03d.png" % (slug(item["Name"]), i))).convert("RGB") for i in idx]
        tw, th = ims[0].size
        row = Image.new("RGB", (tw * 3, th + 30), (26, 30, 38))
        d = ImageDraw.Draw(row)
        d.text((10, 5), LABELS.get(state, state), font=f_sub, fill=(250, 246, 236))
        for q, im in enumerate(ims[:3]):
            row.paste(im, (q * tw, 30))
        rows.append(row)
    # deux colonnes d'états
    half = (len(rows) + 1) // 2
    cw, rh = rows[0].width, rows[0].height
    head = 52
    img = Image.new("RGB", (cw * 2, rh * half + head), (26, 30, 38))
    d = ImageDraw.Draw(img)
    d.text((14, 10), "%s : %d états (3 instants chacun)" % (item["Title"], len(rows)), font=font(26, True),
           fill=(250, 246, 236))
    for k, row in enumerate(rows):
        img.paste(row, ((k // half) * cw, head + (k % half) * rh))
    out = os.path.join(OUT, "%s_planche.jpg" % slug(item["Name"]))
    save_jpg(img, out, 900)
    return out


def board(items, tmp, suffix, out_name, title, cols=4, label=None):
    """Planche d'une image par élément (vue `suffix`), titrée."""
    ims = []
    for it in items:
        p = os.path.join(tmp, "%s_%s.png" % (slug(it["Name"]), suffix))
        if os.path.exists(p):
            ims.append((it, Image.open(p).convert("RGB")))
    if not ims:
        return None
    w, h = ims[0][1].size
    rows = (len(ims) + cols - 1) // cols
    head, cap = 50, 30
    img = Image.new("RGB", (w * cols, rows * (h + cap) + head), (26, 30, 38))
    d = ImageDraw.Draw(img)
    d.text((14, 10), title, font=font(26, True), fill=(250, 246, 236))
    f = font(17)
    for k, (it, im) in enumerate(ims):
        x, y = (k % cols) * w, head + (k // cols) * (h + cap)
        img.paste(im, (x, y + cap))
        text = label(it) if label else "%s (%d pièces)" % (it["Name"], len(it["Boxes"]))
        d.text((x + 8, y + 5), text, font=f, fill=(230, 232, 238))
    out = os.path.join(OUT, out_name)
    save_jpg(img, out, 1200)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("filter", nargs="?", default="")
    ap.add_argument("--stills", action="store_true")
    ap.add_argument("--levels", action="store_true")
    ap.add_argument("--index", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(tempfile.gettempdir(), "saf_hybrids")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)
    t0 = time.time()
    names = [r[0] for r in recipes()]
    if a.levels or a.index:
        everyone = [s[0] for s in species()] + names
        everyone = [n for n in everyone if a.filter.lower() in n.lower()]
        items = []
        for n in everyone:
            if a.levels:
                for level in ("Normal", "Golden", "Diamond"):
                    items.append({"Name": n, "Level": level, "Label": level, "States": []})
            else:
                items.append({"Name": n, "States": ["Index"]})
        found = dump(items)
        for f in found:
            if f["Label"]:
                f["Name"] = "%s %s" % (f["Name"], f["Label"])
        blender(found, "levels" if a.levels else "index", tmp)
        if a.levels:
            out = board(found, tmp, "level", "_niveaux.jpg", "Niveaux Normal, Golden et Diamond (DinoBuilder)", cols=6,
                        label=lambda it: it["Name"])
        else:
            out = board(found, tmp, "index", "_index.jpg", "Pose d'Index (état Index, vue de la fiche)", cols=6,
                        label=lambda it: it["Name"])
        print("[rendu] planche ->", os.path.relpath(out, ROOT), "en %.0f s" % (time.time() - t0))
        return 0
    items = [{"Name": n, "States": [] if a.stills else STATES} for n in names if a.filter.lower() in n.lower()]
    found = dump(items)
    if not found:
        print("aucune chimère")
        return 1
    blender(found, "stills" if a.stills else "both", tmp)
    for it in found:
        out = [sheet_controle(it, tmp)]
        if not a.stills:
            out.append(sheet_states(it, tmp))
        print("[rendu] %-15s %3d pièces  %5.1f x %5.1f x %5.1f  -> %s" % (
            it["Name"], len(it["Boxes"]), *it["Size"], ", ".join(os.path.relpath(p, ROOT) for p in out)))
    if len(found) > 1:
        out = board(found, tmp, "trois-quarts", "_chimeres.jpg", "Les %d chimères (repos, vue trois-quarts)" % len(found))
        print("[rendu] planche ->", os.path.relpath(out, ROOT))
    print("[rendu] fini en %.0f s" % (time.time() - t0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
