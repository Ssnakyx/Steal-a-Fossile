"""Fabrique les poses attendues (calculées en Python, comme les aperçus Blender) pour le test Luau t_dino.luau.

    python models/tests/make_expect.py            # toutes les espèces de src/shared/DinoModels

Lit chaque module Luau exporté, rejoue quelques animations avec la lecture du jeu (cubique monotone) et la cinématique
des os (rig.py), et écrit models/tests/expect/<Espece>.luau : { { anim, t, { os = { x, y, z } } } } (pivots posés)."""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "models", "lib"))

import anim as A  # noqa: E402
from rig import Skeleton, apply  # noqa: E402

NUM = r"-?\d+(?:\.\d+)?"


def parse(path):
    src = open(path, encoding="utf-8").read()
    bones = []
    for m in re.finditer(r'\{ Name = "(\w+)", Parent = (nil|"\w+"), Pivot = V\((%s), (%s), (%s)\)(?:, Rest = V\((%s), (%s), (%s)\))? \}'
                         % ((NUM,) * 6), src):
        rest = [float(m.group(i)) for i in (6, 7, 8)] if m.group(6) else None
        bones.append({"name": m.group(1), "parent": None if m.group(2) == "nil" else m.group(2).strip('"'),
                      "pivot": [float(m.group(i)) for i in (3, 4, 5)], "rest": rest})
    anims = {}
    for m in re.finditer(r"\t\t(\w+) = \{ Length = (%s), Loop = (true|false)[^\n]*Tracks = \{\n(.*?)\n\t\t\} \}," % NUM, src, re.S):
        tracks = {}
        for t in re.finditer(r'\{ "(\w+)", (\d), \{ ([^}]*) \} \}', m.group(4)):
            vals = [float(x) for x in t.group(3).split(",")]
            tracks[(t.group(1), int(t.group(2)) - 1)] = [(vals[i] / 60, vals[i + 1]) for i in range(0, len(vals), 2)]
        anims[m.group(1)] = {"length": float(m.group(2)), "loop": m.group(3) == "true", "tracks": tracks}
    return {"bones": bones}, anims


def n(x):
    s = f"{x:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def main():
    out_dir = os.path.join(HERE, "expect")
    os.makedirs(out_dir, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(ROOT, "src", "shared", "DinoModels", "*.luau"))):
        name = os.path.splitext(os.path.basename(path))[0]
        model, anims = parse(path)
        sk = Skeleton(model)
        lines = ["-- Poses attendues de %s (models/tests/make_expect.py). Ne pas modifier à la main." % name, "return {"]
        for clip in ("Idle", "Walk", "Roar", "Sleep", "Happy", "Fly", "Jump"):
            a = anims.get(clip)
            if not a:
                continue
            for k in (0.0, 0.37, 0.81):
                t = a["length"] * k
                pose = A.game_sample(a["tracks"], t, a["length"], a["loop"])
                W = sk.solve(pose)
                parts = []
                for b in model["bones"]:
                    p = apply(W[b["name"]], tuple(b["pivot"]))
                    parts.append('%s = { %s, %s, %s }' % (b["name"], n(p[0]), n(p[1]), n(p[2])))
                lines.append('\t{ "%s", %s, { %s } },' % (clip, n(t), ", ".join(parts)))
        lines.append("}")
        with open(os.path.join(out_dir, name + ".luau"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print("[expect]", name, len(lines) - 2, "poses")


if __name__ == "__main__":
    main()
