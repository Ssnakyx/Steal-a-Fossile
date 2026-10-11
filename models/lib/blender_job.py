"""Travail Blender d'une espèce (lancé par models/build.py, jamais à la main) :

    blender -b --factory-startup -P models/lib/blender_job.py -- <Espece> <mode> <dossier_tmp> [clips]

mode : `stills` (rendus de contrôle au repos), `anim` (actions Blender, cuisson, export Luau, images des
animations), `all`. Les images brutes vont dans <dossier_tmp> ; models/lib/post.py les assemble ensuite."""
import importlib.util
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
ROOT = os.path.dirname(MODELS)
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import anim as A  # noqa: E402
import bscene as S  # noqa: E402
from rig import Skeleton, apply, IDENT  # noqa: E402

FPS_AUTHOR = 60


def load_species(name):
    path = os.path.join(MODELS, "species", name + ".py")
    spec = importlib.util.spec_from_file_location("species_" + name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def model_bounds(model, sk=None, pose=None):
    """Boîte englobante (axes Roblox) du modèle posé."""
    lo = [1e9] * 3
    hi = [-1e9] * 3
    W = sk.solve(pose) if (sk and pose) else None
    for bx in model["boxes"]:
        M = W[bx["bone"]] if W else IDENT
        c, s = bx["c"], bx["s"]
        for dx in (-0.5, 0.5):
            for dy in (-0.5, 0.5):
                for dz in (-0.5, 0.5):
                    p = apply(M, (c[0] + dx * s[0], c[1] + dy * s[1], c[2] + dz * s[2]))
                    for i in range(3):
                        lo[i] = min(lo[i], p[i])
                        hi[i] = max(hi[i], p[i])
    return lo, hi


# ---------------------------------------------------------------------- rendus de contrôle (repos)
def stills(model, tmp, family):
    S.reset()
    S.eevee(640, 640, sky=(0.66, 0.8, 0.95) if family != "Swimmer" else (0.45, 0.66, 0.86))
    space, arm, obj = S.build_rig(model)
    sx, sy, sz = model["size"]
    ext = max(sx, sy, sz)
    S.ground_tiles(ext * 3, 2.0, [(118, 178, 92), (108, 166, 84)] if family != "Swimmer" else [(214, 196, 150), (204, 186, 140)])
    S.dummy(x=sx / 2 + 3.0, y=0.0)
    center = Vector((1.0, 0, sy * 0.45))
    views = [("face", (0, 1, 0.12)), ("trois-quarts", (-0.85, 1, 0.42)), ("profil", (-1, 0, 0.08)), ("dos", (0.75, -1, 0.45))]
    out = []
    for name, d in views:
        cam = S.ortho_camera("cam_" + name, center, d, ext * 1.35)
        p = os.path.join(tmp, "still_%s.png" % name)
        S.render_to(p, cam)
        out.append(p)
    return out


# ---------------------------------------------------------------------- animations
def author_actions(arm, clips, sampled):
    """Une Action Blender par animation, clés à 60 images/s (canaux composés + IK), CYCLES sur les boucles."""
    arm.animation_data_create()
    actions = {}
    for name, clip in clips.items():
        times, frames = sampled[name]
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        chans = {}
        for f in frames:
            for bone, v in f.items():
                for ch in range(6):
                    if abs(v[ch]) > 1e-5:
                        chans[(bone, ch)] = True
        for bone, r in S.REST.items():
            for ch in range(3):
                if abs(r[ch]) > 1e-5:
                    chans[(bone, ch)] = True
        for (bone, ch) in chans:
            path = 'pose.bones["%s"].%s' % (bone, "rotation_euler" if ch < 3 else "location")
            fc = act.fcurve_ensure_for_datablock(arm, path, index=ch % 3)
            r = S.REST.get(bone, (0.0, 0.0, 0.0))
            for t, f in zip(times, frames):
                v = f.get(bone, [0.0] * 6)[ch] + (r[ch] if ch < 3 else 0.0)
                kp = fc.keyframe_points.insert(t * FPS_AUTHOR, math.radians(v) if ch < 3 else v, options={"FAST"})
                kp.interpolation = "LINEAR"
            if clip.loop:
                fc.modifiers.new("CYCLES")
            fc.update()
        actions[name] = act
    arm.animation_data.action = None
    return actions


def _fcurves(act):
    out = {}
    for fc in act.layers[0].strips[0].channelbag(act.slots[0]).fcurves:
        bone = fc.data_path.split('"')[1]
        ch = fc.array_index + (0 if "rotation_euler" in fc.data_path else 3)
        out[(bone, ch)] = fc
    return out


def bake_from_blender(clip, act, times):
    """Relit les courbes de l'Action (fcurve.evaluate, modificateurs compris) aux mêmes instants."""
    fcs = _fcurves(act)
    frames = []
    for t in times:
        pose = {}
        for (bone, ch), fc in fcs.items():
            v = fc.evaluate(t * FPS_AUTHOR)
            r = S.REST.get(bone, (0.0, 0.0, 0.0))
            pose.setdefault(bone, [0.0] * 6)[ch] = (math.degrees(v) - r[ch]) if ch < 3 else v
        frames.append(pose)
    return frames


def framing(model, sk, tracks, clip):
    """Boîte englobante de l'animation entière (pour cadrer les deux vues)."""
    lo, hi = [1e9] * 3, [-1e9] * 3
    n = max(6, int(clip.length * 8))
    cache = {}
    for i in range(n + 1):
        pose = A.game_sample(tracks, clip.length * i / n, clip.length, clip.loop, cache)
        a, b = model_bounds(model, sk, pose)
        for k in range(3):
            lo[k] = min(lo[k], a[k])
            hi[k] = max(hi[k], b[k])
    return lo, hi


def render_anim(model, sk, rig, clips, baked, tmp, family):
    S.reset()
    S.workbench(400, 400)
    sky = (0.6, 0.76, 0.92) if family != "Swimmer" else (0.36, 0.58, 0.82)
    S.set_world_color(sky)
    space, arm, obj = S.build_rig(model)
    sx, sy, sz = model["size"]
    tile = 2.0 if model["height"] < 12 else 4.0
    cols = [(150, 206, 118), (136, 194, 106)] if family != "Swimmer" else [(226, 208, 160), (212, 194, 146)]
    ground = S.ground_tiles(max(sx, sz) * 6 + 40, tile, cols)
    meta = {}
    for name, clip in clips.items():
        tracks = baked[name]
        lo, hi = framing(model, sk, tracks, clip)
        lo[1] = min(lo[1], 0.0)
        dirs = [(-0.9, 1.0, 0.5), (-1.0, 0.0, 0.12)]
        cams = []
        for j, dvec in enumerate(dirs):
            cam = S.ortho_camera("c%d_%s" % (j, name), Vector((0, 0, 0)), dvec, 10.0)
            S.fit_camera(cam, dvec, lo, hi, 1.18)
            cams.append(cam)
        fps = 24
        loops = 2 if (clip.loop and clip.length < 2.2) else 1
        n = int(round(clip.length * fps * loops))
        speed = clip.speed or 0.0
        paths = []
        cache = {}
        for i in range(n):
            t = i / fps
            pose = A.game_sample(tracks, t, clip.length, clip.loop, cache)
            S.apply_pose(arm, pose)
            # le sol défile à la vitesse de la marche : les pieds posés ne doivent pas glisser
            ground.location.y = -((speed * t) % (2 * tile))
            row = []
            for j, cam in enumerate(cams):
                p = os.path.join(tmp, "%s_%04d_%d.png" % (name, i, j))
                S.render_to(p, cam)
                row.append(p)
            paths.append(row)
        meta[name] = {"frames": n, "fps": fps, "length": clip.length, "loop": clip.loop, "loops": loops,
                      "events": clip.events, "speed": speed, "next": clip.next}
        print("[job] rendu %-12s %3d images" % (name, n), flush=True)
    ground.location.y = 0
    with open(os.path.join(tmp, "anim_meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    name, mode, tmp = args[0], args[1], args[2]
    only = set(args[3].split(",")) if len(args) > 3 and args[3] else None
    os.makedirs(tmp, exist_ok=True)
    sp = load_species(name)
    d = sp.build()
    model = d.data()
    print("[job] %s : %d voxels -> %d pièces, %d os, %.1f x %.1f x %.1f studs" % (
        name, model["voxels"], len(model["boxes"]), len(model["bones"]), *model["size"]), flush=True)
    with open(os.path.join(tmp, "model.json"), "w", encoding="utf-8") as f:
        json.dump(model, f)
    if mode in ("stills", "all"):
        stills(model, tmp, sp.FAMILY)
    if mode in ("anim", "all", "bake"):
        import export_luau
        import families
        t0 = time.time()
        sk = Skeleton(model)
        rig = families.make_rig(model, sk, sp)
        clips = families.build_clips(rig)
        if only:
            clips = {k: v for k, v in clips.items() if k in only}
        sampled = {n: c.sample(FPS_AUTHOR) for n, c in clips.items()}
        print("[job] composition : %d animations en %.1f s" % (len(clips), time.time() - t0), flush=True)
        # Blender : armature + actions, puis cuisson depuis les F-curves
        S.reset()
        space, arm, obj = S.build_rig(model)
        actions = author_actions(arm, clips, sampled)
        baked = {}
        for n, c in clips.items():
            times, _ = sampled[n]
            frames = bake_from_blender(c, actions[n], times)
            baked[n] = A.bake(c, times, frames)
        blend = os.path.join(MODELS, "species", "blend", name + ".blend")
        os.makedirs(os.path.dirname(blend), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        path, size, stats = export_luau.write(model, rig, clips, baked, ROOT, only=only)
        print("[job] export : %s (%.1f Ko)" % (path, size / 1024), flush=True)
        for line in stats:
            print("   " + line, flush=True)
        if mode != "bake":
            render_anim(model, sk, rig, clips, baked, tmp, sp.FAMILY)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
