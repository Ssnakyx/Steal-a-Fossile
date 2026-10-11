"""Rendus de contrôle des blocs de fossiles dans Blender (lancé par models/blocks/build.py, jamais à la main) :

    blender -b --factory-startup -P models/blocks/blender_blocks.py -- <modeles.json> <dossier_tmp>

<modeles.json> : {"zones": {zone: {rareté: modèle}}, "scales": {rareté: échelle}, "only": [zone...] ou null}.
Rendus (Eevee, même lumière que les rendus des dinos), tous à la même échelle de caméra (les tailles se comparent) :
  <n>_<rareté>_face.png   trois-quarts avant du bloc de la zone n, à sa taille en jeu
  <n>_<rareté>_dos.png    trois-quarts arrière (décor du biome)
  rang_<n>.png            les 7 raretés de la zone n à leur taille en jeu, à côté de l'avatar de 5 studs
Les images brutes vont dans <dossier_tmp> ; build.py les assemble."""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))

import bpy  # noqa: E402,F401
from mathutils import Vector  # noqa: E402

import bscene as S  # noqa: E402

GROUND = [(196, 178, 140), (186, 168, 130)]
SKY = (0.70, 0.82, 0.94)


def place(model, x=0.0, y=0.0, rot=0.0, scale=1.0, name="Block"):
    """Bloc posé sur le sol (le bas de la grille à z = 0), décalé de (x, y) dans le monde Blender."""
    space, arm, obj = S.build_rig(model, name=name)
    space.location = (x, y, model["size"][1] / 2 * scale)
    space.rotation_euler = (math.radians(90), 0, math.radians(rot))
    space.scale = (scale, scale, scale)
    return space


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    data = json.load(open(args[0], encoding="utf-8"))
    tmp = args[1]
    os.makedirs(tmp, exist_ok=True)
    zones, scales = data["zones"], data["scales"]
    only = data.get("only")
    for n, zone in enumerate(zones):
        if only and zone not in only:
            continue
        row = zones[zone]
        # ------------------------------------------------------------ chaque bloc, de trois-quarts avant et arrière
        for rarity, model in row.items():
            s = scales[rarity]
            for view, rot, d in (("face", 25, (-0.35, 1, 0.55)), ("dos", 205, (-0.35, 1, 0.62))):
                S.reset()
                S.eevee(420, 420, sky=SKY)
                S.ground_tiles(14, 1.0, GROUND)
                place(model, rot=rot, scale=s)
                cam = S.ortho_camera("cam", Vector((0, 0, 2.9)), d, 8.4)
                S.render_to(os.path.join(tmp, "%d_%s_%s.png" % (n, rarity, view)), cam)
        # ------------------------------------------------------------ les 7 raretés à leur taille, avec l'avatar
        S.reset()
        S.eevee(1900, 620, sky=SKY)
        S.ground_tiles(52, 2.0, GROUND)
        x = 0.0
        xs = []
        for i, (rarity, model) in enumerate(row.items()):
            half = 1.5 * scales[rarity] + 0.6
            if i > 0:
                x -= half + 1.4
            place(model, x, 0, rot=25, scale=scales[rarity], name="B%d" % i)
            xs.append(x)
            x -= half
        avatar = xs[0] + 4.2
        S.dummy(x=avatar, y=0.8)
        mid = (avatar + xs[-1]) / 2
        cam = S.ortho_camera("cam_rang", Vector((mid, 0, 3.0)), (-0.25, 1, 0.42), abs(xs[-1] - avatar) + 9)
        S.render_to(os.path.join(tmp, "rang_%d.png" % n), cam)
        print("[blocs] %s" % (zone or "(sans biome)"), flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
