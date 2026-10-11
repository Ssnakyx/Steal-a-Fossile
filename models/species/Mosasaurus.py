"""Mosasaurus : nageur géant de l'Ocean Trench (pilote de la famille Swimmer).

Voxels de 0,52 stud : environ 30 studs de long à la taille Normal. Corps fuselé, grosse tête, quatre nageoires
(plaques), queue en six segments terminée par une nageoire en croissant."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.52

BACK = (52, 86, 118)
SIDE = (78, 122, 156)
BELLY = (228, 232, 234)
STRIPE = (40, 66, 92)
FIN = (44, 72, 100)
TOOTH = (252, 250, 242)
MOUTH = (196, 96, 104)
PUPIL = (24, 20, 20)
IRIS = (255, 214, 80)

PERSONALITY = {
    "tempo": 0.8,           # géant, ondulations amples et lentes
    "weight": 1.3,
    "tail": 1.0,
    "diet": "fish",
    "happy": "roll",        # tonneau sur lui-même
    "catch": "ram",         # coup de tête (gueule fermée à l'impact)
}


def build():
    d = Dino("Mosasaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 5, 4))
    d.bone("Chest", (0, 5, -1), "Hips")
    d.bone("Neck1", (0, 5.4, -11), "Chest")
    d.bone("Head", (0, 5.8, -13.5), "Neck1")
    d.bone("Jaw", (0, 4.8, -15), "Head")
    d.bone_pair("Lid", (-2.6, 7, -17.5), "Head")
    d.bone_pair("FinF1", (-3, 3, -5.5), "Chest")
    d.bone_pair("FinF2", (-6.5, 3, -5), "FinF1L")
    d.bone_pair("FinB1", (-2.8, 3, 7.2), "Hips")
    d.bone_pair("FinB2", (-5.5, 3, 7.6), "FinB1L")
    tz = [10.5, 14.0, 17.5, 21.0, 24.5, 27.5, 30.0]
    ty = [5.0, 5.2, 5.4, 5.6, 5.8, 6.0, 6.2]
    tr = [3.3, 2.8, 2.3, 1.8, 1.35, 0.95, 0.6]
    for i in range(6):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps fuselé
    d.ellipsoid("Chest", (0, 5.3, -5), (3.8, 4.3, 6.5), SIDE, where=left)
    d.ellipsoid("Hips", (0, 5.1, 5), (3.5, 4.0, 6.0), SIDE, where=left)
    d.limb("Neck1", (0, 5.2, -10.5), (0, 5.6, -13), 3.3, 3.1, SIDE, where=left)
    # ---------------------------------------------------------------- tête : crâne, long museau, mâchoire, dents
    d.ellipsoid("Head", (0, 6.3, -16.5), (2.9, 2.5, 3.6), SIDE, where=left, power=2.4)
    d.ellipsoid("Head", (0, 5.9, -21.5), (2.1, 1.9, 3.8), SIDE, where=lambda x, y, z: x <= 0 and y >= 5, power=2.3)
    d.ellipsoid("Jaw", (0, 4.0, -19.5), (2.3, 1.3, 5.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 4, power=2.4)
    for z in range(-24, -14):
        if (0, 5, z) in d.vox:
            d.set("Head", 0, 5, z, MOUTH)
        if (0, 4, z) in d.vox:
            d.set("Jaw", 0, 4, z, MOUTH)
    for z in range(-24, -15, 2):
        x = d.surface_x(5, z, "Head")
        if x is not None:
            d.set("Head", x, 5, z, TOOTH, "Smooth")
        x = d.surface_x(4, z + 1, "Jaw")
        if x is not None:
            d.set("Jaw", x, 4, z + 1, TOOTH, "Smooth")
    # ---------------------------------------------------------------- nageoires (plaques de 2 voxels)
    d.plate("FinF1L", 1, 2, [(-2.5, -7.5), (-6.8, -7.0), (-6.8, -3.4), (-2.5, -3.6)], FIN, thick=2)
    d.plate("FinF2L", 1, 2, [(-6.8, -7.0), (-10.2, -5.6), (-10.6, -3.6), (-6.8, -3.4)], FIN, thick=2)
    d.plate("FinB1L", 1, 2, [(-2.5, 5.8), (-5.6, 6.3), (-5.6, 9.2), (-2.5, 8.8)], FIN, thick=2)
    d.plate("FinB2L", 1, 2, [(-5.6, 6.3), (-8.2, 7.4), (-8.4, 9.6), (-5.6, 9.2)], FIN, thick=2)
    # ---------------------------------------------------------------- queue et nageoire en croissant
    for i in range(6):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], SIDE, where=left)
    d.plate("Tail6", 0, 0, [(6, 28.5), (8.5, 30.5), (12, 34.5), (10, 34.8), (6.5, 32), (3.5, 33.5), (0.5, 33.5),
                            (3.5, 31), (4.5, 28.5)], FIN)
    # petite crête dorsale en plaque
    d.plate("Chest", 0, 0, [(8.4, -8), (9.8, -6.5), (9.6, -2.5), (8.4, -1)], BACK)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 6, -18, IRIS, PUPIL, lid_color=BACK, h=1, w=2)
    d.mirror()
    # contre-ombrage coupé à plat : dos foncé, flancs, ventre blanc ; quelques bandes sur le dos
    top = {"Chest": 7, "Hips": 7, "Neck1": 7, "Head": 8, "Tail1": 7, "Tail2": 7, "Tail3": 7, "Tail4": 7, "Tail5": 7}
    low = {"Chest": 3, "Hips": 3, "Neck1": 3, "Tail1": 3, "Tail2": 4, "Tail3": 4, "Tail4": 5, "Tail5": 5}

    def paint(x, y, z, bone, c):
        if c != SIDE:
            return None
        if bone in low and y <= low[bone]:
            return BELLY
        if bone in top and y >= top[bone]:
            return STRIPE if (z % 6) in (0, 1) and bone != "Head" else BACK
        return None
    d.paint(paint)
    return d
