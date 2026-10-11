"""Rendus de contrôle des blocs de fossiles dans Blender (lancé par models/blocks/build.py, jamais à la main) :

    blender -b --factory-startup -P models/blocks/blender_blocks.py -- <modeles.json> <dossier_tmp>

Pour chaque rareté : face, trois-quarts gauche et droit, dos et dessus (Eevee, même lumière que les rendus des dinos), puis une
rangée des 7 blocs à côté de l'avatar de 5 studs. Les images brutes vont dans <dossier_tmp> ; build.py les assemble."""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import bscene as S  # noqa: E402

# directions de caméra dans le monde Blender (l'avant du bloc, -Z Roblox, regarde vers +Y Blender)
VIEWS = [("face", (0, 1, 0.35)), ("gauche", (-0.85, 1, 0.65)), ("droite", (0.85, 1, 0.65)), ("dos", (0.3, -1, 0.6)),
         ("dessus", (0.35, 0.45, 1.6))]


def place(model, x=0.0, y=0.0, rot=0.0):
    """Bloc posé sur le sol (centre à 1,5 stud de haut), décalé de (x, y) dans le monde Blender."""
    space, arm, obj = S.build_rig(model, name=model["name"])
    space.location = (x, y, model["size"][1] / 2)
    space.rotation_euler = (math.radians(90), 0, math.radians(rot))
    return space


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    models = json.load(open(args[0], encoding="utf-8"))
    tmp = args[1]
    os.makedirs(tmp, exist_ok=True)
    order = list(models)

    # ---------------------------------------------------------------- un bloc à la fois
    for name in order:
        model = models[name]
        S.reset()
        S.eevee(560, 560, sky=(0.70, 0.82, 0.94))
        S.ground_tiles(12, 1.0, [(196, 178, 140), (186, 168, 130)])
        place(model)
        center = Vector((0, 0, 1.6))
        for view, d in VIEWS:
            cam = S.ortho_camera("cam_" + view, center, d, 5.4)
            S.render_to(os.path.join(tmp, "%s_%s.png" % (name, view)), cam)
        print("[blocs] %s : %d pièces" % (name, len(model["boxes"])), flush=True)

    # ---------------------------------------------------------------- les 7 blocs en rang, avec l'avatar
    S.reset()
    S.eevee(1800, 620, sky=(0.70, 0.82, 0.94))
    S.ground_tiles(40, 2.0, [(196, 178, 140), (186, 168, 130)])
    # (la caméra regarde l'avant des blocs : +X Blender est à gauche de l'image ; Common à gauche, près de l'avatar)
    step = 4.2
    x0 = step * (len(order) - 1) / 2
    for i, name in enumerate(order):
        place(models[name], x0 - i * step, 0, rot=20)
    S.dummy(x=x0 + 4.2, y=0.6)
    cam = S.ortho_camera("cam_rang", Vector((1.0, 0, 2.2)), (-0.25, 1, 0.42), 33)
    S.render_to(os.path.join(tmp, "rang.png"), cam)
    print("[blocs] rangée rendue", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
