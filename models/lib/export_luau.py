"""export_luau : écrit src/shared/DinoModels/<Espece>.luau (modèle + animations), lu par DinoBuilder.

Format compact (voir models/README.md) : boîtes en coordonnées voxel entières + palette de peintures, clés
d'animation en images à 60 par seconde (entiers), rotations au dixième de degré, déplacements au millième de stud."""
from __future__ import annotations

import os

from families import group_of


def n(x, d=3):
    s = f"{x:.{d}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "", "-") else s


def v3(p):
    return f"V({n(p[0])}, {n(p[1])}, {n(p[2])})"


def write(model, rig, clips, baked, root, only=None):
    name = model["name"]
    out_dir = os.path.join(root, "src", "shared", "DinoModels")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".luau")
    if only and os.path.exists(path):
        # export partiel (quelques animations pour un aperçu) : on ne réécrit pas le module complet
        return path, os.path.getsize(path), ["export partiel : module non réécrit"]
    L = ["--!nocheck",
         f"-- {model['display']} : modèle voxel et animations générés par models/build.py (models/species/{name}.py).",
         "-- Ne pas modifier à la main : relancer `python models/build.py " + name + "`. Format : models/README.md.",
         "local V = Vector3.new", "local C = Color3.fromRGB", "", "return {"]
    sx, sy, sz = model["size"]
    L.append(f'\tName = "{model["display"]}",')
    L.append(f'\tFamily = "{model["family"]}",')
    L.append(f"\tVoxel = {n(model['voxel'])},")
    L.append(f"\tHeight = {n(model['height'])},")
    L.append(f"\tSize = V({n(sx)}, {n(sy)}, {n(sz)}),")
    L.append(f"\tLidDrop = {n(rig.lid_drop)},")
    L.append("\t-- os : pivot en studs (espace du modèle, pieds à Y = 0, regarde vers -Z) ; Rest = rotation de repos")
    L.append("\tBones = {")
    for b in model["bones"]:
        par = f'"{b["parent"]}"' if b["parent"] else "nil"
        rest = f', Rest = {v3(b["rest"])}' if b.get("rest") else ""
        L.append(f'\t\t{{ Name = "{b["name"]}", Parent = {par}, Pivot = {v3(b["pivot"])}{rest} }},')
    L.append("\t},")
    groups = {}
    for b in model["bones"]:
        groups.setdefault(group_of(b["name"]), []).append(b["name"])
    L.append("\t-- groupes d'os (hybrides : tête de A, corps et queue de B, ailes ou nageoires de celui qui en a)")
    L.append("\tGroups = {")
    for g in ("Body", "Head", "Tail", "Legs", "Arms", "Wings", "Fins"):
        if g in groups:
            L.append(f"\t\t{g} = {{ " + ", ".join(f'"{x}"' for x in groups[g]) + " },")
    L.append("\t},")
    L.append("\t-- points utiles aux effets (pieds pour la poussière, yeux, bouche...) : os, position au repos en studs")
    L.append("\tPoints = {")
    for k, p in sorted(model["points"].items()):
        L.append(f'\t\t{k} = {{ "{p["bone"]}", {v3(p["p"])} }},')
    L.append("\t},")
    paints = []
    for bx in model["boxes"]:
        k = (tuple(bx["col"]), bx["mat"])
        if k not in paints:
            paints.append(k)
    L.append("\t-- peintures des boîtes : couleur, matière (Plastic = studs sur le dessus)")
    L.append("\tPaints = {")
    for (c, m) in paints:
        L.append(f'\t\t{{ C({c[0]}, {c[1]}, {c[2]}), "{m}" }},')
    L.append("\t},")
    ox, oy, oz = model["origin"]
    L.append("\t-- boîtes en voxels : os, x0, y0, z0, x1, y1, z1 (coins inclus), peinture ;")
    L.append("\t-- centre en studs = ((x0 + x1 + 1) / 2 - Origin.X) * Voxel, taille = (x1 - x0 + 1) * Voxel")
    L.append(f"\tOrigin = V({n(ox)}, {n(oy)}, {n(oz)}),")
    L.append("\tBoxes = {")
    for bx in model["boxes"]:
        a, b = bx["a"], bx["b"]
        pi = paints.index((tuple(bx["col"]), bx["mat"])) + 1
        L.append(f'\t\t{{ "{bx["bone"]}", {a[0]}, {a[1]}, {a[2]}, {b[0]}, {b[1]}, {b[2]}, {pi} }},')
    L.append("\t},")
    L.append("\t-- animations : Tracks = { os, canal (1 rx, 2 ry, 3 rz en degrés ; 4 px, 5 py, 6 pz en studs),")
    L.append("\t--   { image, valeur, image, valeur... } } avec image = t * 60 ; lecture en cubique monotone (pchip)")
    L.append("\t-- Speed = studs/s de la marche à l'échelle 1 ; Next = état joué ensuite ; Events = { t, nom, os }")
    L.append("\tAnims = {")
    stats = []
    for cname, clip in clips.items():
        tracks = baked[cname]
        ev = ", ".join(f'{{ {n(t)}, "{k}"' + (f', "{d}"' if d else "") + " }" for t, k, d in sorted(clip.events))
        head = f"\t\t{cname} = {{ Length = {n(clip.length)}, Loop = {str(clip.loop).lower()}"
        if clip.next:
            head += f', Next = "{clip.next}"'
        if clip.speed:
            head += f", Speed = {n(clip.speed, 2)}"
        head += f", Events = {{ {ev} }}, Tracks = {{"
        L.append(head)
        keys = 0
        for (bone, ch), vals in tracks.items():
            d = 1 if ch < 3 else 3
            flat = ",".join(f"{round(t * 60)},{n(v, d)}" for t, v in vals)
            L.append(f'\t\t\t{{ "{bone}", {ch + 1}, {{ {flat} }} }},')
            keys += len(vals)
        L.append("\t\t} },")
        stats.append("%-12s L=%.2f %s pistes=%3d clés=%4d" % (cname, clip.length, "boucle" if clip.loop else "      ",
                                                           len(tracks), keys))
    L.append("\t},")
    L.append("}")
    text = "\n".join(L) + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return path, len(text.encode("utf-8")), stats
