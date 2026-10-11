"""Rendus Blender des chimères et des apparences des dinos (lancé par models/hybrids/render.py, jamais à la main) :

    blender -b --factory-startup -P models/hybrids/blender_hybrids.py -- <items.json> <dossier_tmp> <mode>

mode : `stills` (face, trois-quarts, profil, dos au repos, Eevee), `both` (+ chaque instant des états, Workbench),
`levels` (une vue trois-quarts au repos par élément), `index` (la pose d'Index vue de face comme dans la fiche).
Même scène que les dinos (models/lib/bscene.py) : armature, cubes liés aux os, poses du jeu (DinoBuilder.Sample)."""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))

import bpy  # noqa: E402,F401
from mathutils import Vector  # noqa: E402

import bscene as S  # noqa: E402


def slug(name):
    return re.sub(r"[^\w-]", "", name)


def model_of(item):
    return {
        "bones": [{"name": b["name"], "parent": b["parent"] or None, "pivot": b["pivot"], "rest": b["rest"]}
                  for b in item["Bones"]],
        "boxes": item["Boxes"],
        "height": item["Height"],
        "size": item["Size"],
    }


def sky(item):
    return (0.45, 0.66, 0.86) if item["Family"] == "Swimmer" else (0.66, 0.8, 0.95)


def ground_colors(item):
    return [(214, 196, 150), (204, 186, 140)] if item["Family"] == "Swimmer" else [(118, 178, 92), (108, 166, 84)]


def scene(item, engine, res):
    S.reset()
    if engine == "eevee":
        S.eevee(res, res, sky=sky(item))
    else:
        S.workbench(res, res)
        S.set_world_color(sky(item))
    space, arm, obj = S.build_rig(model_of(item))
    sx, sy, sz = item["Size"]
    ext = max(sx, sy, sz)
    S.ground_tiles(ext * 3 + 10, 2.0 if item["Height"] < 12 else 4.0, ground_colors(item))
    return arm, ext


def pose_of(frame):
    pose = frame["Pose"]
    # (une pose vide arrive du Luau comme une liste vide)
    return {bone: v for bone, v in pose.items()} if isinstance(pose, dict) else {}


def stills(item, tmp):
    arm, ext = scene(item, "eevee", 600)
    sx, sy, sz = item["Size"]
    S.dummy(x=sx / 2 + 3.0, y=0.0)
    S.apply_pose(arm, {})
    center = Vector((1.0, 0, sy * 0.45))
    views = [("face", (0, 1, 0.12)), ("trois-quarts", (-0.85, 1, 0.42)), ("profil", (-1, 0, 0.08)), ("dos", (0.75, -1, 0.45))]
    for name, d in views:
        cam = S.ortho_camera("cam_" + name, center, d, ext * 1.35)
        S.render_to(os.path.join(tmp, "%s_%s.png" % (slug(item["Name"]), name)), cam)


def states(item, tmp):
    arm, ext = scene(item, "workbench", 360)
    groups = {}
    for i, f in enumerate(item["Frames"]):
        if f["State"] != "Rest":
            groups.setdefault(f["State"], []).append(i)
    direction = (-0.9, 1.0, 0.5)
    for state, idx in groups.items():
        lo = [min(item["Frames"][i]["Lo"][k] for i in idx) for k in range(3)]
        hi = [max(item["Frames"][i]["Hi"][k] for i in idx) for k in range(3)]
        lo[1] = min(lo[1], 0.0)
        cam = S.ortho_camera("cam_" + state, Vector((0, 0, 0)), direction, 10.0)
        S.fit_camera(cam, direction, lo, hi, 1.15)
        for i in idx:
            S.apply_pose(arm, pose_of(item["Frames"][i]))
            S.render_to(os.path.join(tmp, "%s_f%03d.png" % (slug(item["Name"]), i)), cam)


def single(item, tmp, suffix, frame, direction):
    arm, ext = scene(item, "eevee", 420)
    S.apply_pose(arm, pose_of(frame) if frame else {})
    lo, hi = (frame["Lo"], frame["Hi"]) if frame else (item["Frames"][0]["Lo"], item["Frames"][0]["Hi"])
    lo = list(lo)
    lo[1] = min(lo[1], 0.0)
    cam = S.ortho_camera("cam", Vector((0, 0, 0)), direction, 10.0)
    S.fit_camera(cam, direction, lo, hi, 1.12)
    S.render_to(os.path.join(tmp, "%s_%s.png" % (slug(item["Name"]), suffix)), cam)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    items = json.load(open(args[0], encoding="utf-8"))
    tmp, mode = args[1], args[2]
    for item in items:
        if mode in ("stills", "both"):
            stills(item, tmp)
        if mode == "both":
            states(item, tmp)
        if mode == "levels":
            single(item, tmp, "level", None, (-0.85, 1, 0.42))
        if mode == "index":
            frames = [f for f in item["Frames"] if f["State"] == "Index"]
            # vue de la fiche : de face, un peu de côté (la tête se tourne vers le joueur)
            single(item, tmp, "index", frames[0] if frames else None, (-0.5, 1, 0.25))
        print("[rendu] %s" % item["Name"], flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
