"""Rendus de contrôle des blocs de fossiles dans Blender (lancé par models/blocks/build.py, jamais à la main) :

    blender -b --factory-startup -P models/blocks/blender_blocks.py -- <modeles.json> <dossier_tmp>

<modeles.json> : {"bases": {rareté: modèle}, "biomes": {zone: modèle}, "scales": {rareté: échelle}}.
Rendus (Eevee, même lumière que les rendus des dinos) :
  <Rareté>_<vue>.png   face, trois-quarts gauche et droit, dos et dessus du bloc de chaque rareté (sans décor)
  rang.png             les 7 raretés à leur taille en jeu, à côté de l'avatar de 5 studs
  biome_<n>.png        un rang des 7 raretés avec le décor du biome n, vu de l'arrière (le décor est derrière et
                       dessus)
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

# directions de caméra dans le monde Blender (l'avant du bloc, -Z Roblox, regarde vers +Y Blender)
VIEWS = [("face", (0, 1, 0.35)), ("gauche", (-0.85, 1, 0.65)), ("droite", (0.85, 1, 0.65)), ("dos", (0.3, -1, 0.6)),
         ("dessus", (0.35, 0.45, 1.6))]


def place(model, x=0.0, y=0.0, rot=0.0, scale=1.0, name="Block"):
    """Bloc posé sur le sol (le bas du bloc à z = 0), décalé de (x, y) dans le monde Blender."""
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
    bases, biomes, scales = data["bases"], data["biomes"], data["scales"]
    order = list(bases)

    # ---------------------------------------------------------------- un bloc à la fois (sans décor)
    for name in order:
        model = bases[name]
        S.reset()
        S.eevee(560, 560, sky=(0.70, 0.82, 0.94))
        S.ground_tiles(12, 1.0, [(196, 178, 140), (186, 168, 130)])
        place(model)
        center = Vector((0, 0, 1.6))
        for view, d in VIEWS:
            cam = S.ortho_camera("cam_" + view, center, d, 5.4)
            S.render_to(os.path.join(tmp, "%s_%s.png" % (name, view)), cam)
        print("[blocs] %s : %d pièces" % (name, len(model["boxes"])), flush=True)

    # ---------------------------------------------------------------- les 7 raretés à leur taille, avec l'avatar
    # (vue de face : +X Blender est à gauche de l'image ; Common à gauche, près de l'avatar)
    def row(biome=None, back=False, out="rang.png"):
        S.reset()
        S.eevee(1900, 640, sky=(0.70, 0.82, 0.94))
        S.ground_tiles(48, 2.0, [(196, 178, 140), (186, 168, 130)])
        sign = 1
        x = 0.0
        xs = []
        for i, name in enumerate(order):
            s = scales[name]
            half = 1.5 * s
            if i > 0:
                x -= sign * (half + 1.6)
            rot = 20 if not back else 200
            place(bases[name], x, 0, rot=rot, scale=s, name="B%d" % i)
            if biome:
                place(biome, x, 0, rot=rot, scale=s, name="D%d" % i)
            xs.append(x)
            x -= sign * half
        avatar = xs[0] + sign * 4.4
        S.dummy(x=avatar, y=0.8)
        mid = (avatar + xs[-1]) / 2
        # (de dos : les blocs sont tournés d'un demi-tour, la caméra ne bouge pas)
        d = (-0.25, 1, 0.42) if not back else (-0.25, 1, 0.55)
        cam = S.ortho_camera("cam_rang", Vector((mid, 0, 2.6)), d, abs(xs[-1] - avatar) + 9)
        S.render_to(os.path.join(tmp, out), cam)

    row()
    print("[blocs] rangée rendue", flush=True)
    for n, zone in enumerate(biomes):
        row(biomes[zone], back=True, out="biome_%d.png" % n)
        # gros plan d'un bloc Rare de ce biome, de dos puis de face
        for side, rot in (("dos", 200), ("face", 25)):
            S.reset()
            S.eevee(520, 520, sky=(0.70, 0.82, 0.94))
            S.ground_tiles(12, 1.0, [(196, 178, 140), (186, 168, 130)])
            place(bases["Rare"], rot=rot, name="B")
            place(biomes[zone], rot=rot, name="D")
            cam = S.ortho_camera("cam_close", Vector((0, 0, 1.7)), (-0.35, 1, 0.6), 5.6)
            S.render_to(os.path.join(tmp, "biome_%d_%s.png" % (n, side)), cam)
        print("[blocs] biome %s" % zone, flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
