"""Plesiosaurus : nageur de l'Ocean Trench, curieux et gracieux.

Voxels de 0,37 stud : environ 18 studs de long et 6 de haut à la taille Normal. Corps large et rond, très long cou
relevé en quatre segments épais, petite tête aux dents fines, quatre grandes nageoires en plaques, queue courte."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.37

BACK = (40, 112, 128)
SIDE = (66, 160, 170)
BELLY = (230, 238, 232)
FIN = (36, 92, 108)
SPOT = (128, 204, 204)
TOOTH = (252, 250, 242)
MOUTH = (196, 96, 104)
PUPIL = (24, 20, 20)
IRIS = (255, 214, 80)

PERSONALITY = {
    "tempo": 1.0,           # curieux, nage souple
    "weight": 1.0,
    "tail": 0.6,
    "diet": "fish",
    "happy": "roll",
    "catch": "ram",
}


def build():
    d = Dino("Plesiosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 5, 4))
    d.bone("Chest", (0, 5.2, -1), "Hips")
    d.bone("Neck1", (0, 6.6, -7.6), "Chest")
    d.bone("Neck2", (0, 8.6, -11.0), "Neck1")
    d.bone("Neck3", (0, 10.8, -14.4), "Neck2")
    d.bone("Neck4", (0, 12.4, -17.6), "Neck3")
    d.bone("Head", (0, 13.4, -20.6), "Neck4")
    d.bone("Jaw", (0, 13.0, -22.4), "Head")
    d.bone_pair("Lid", (-1.8, 15, -23), "Head")
    d.bone_pair("FinF1", (-4.0, 3.4, -4.0), "Chest")
    d.bone_pair("FinF2", (-8.6, 3.4, -3.2), "FinF1L")
    d.bone_pair("FinB1", (-3.6, 3.4, 7.0), "Hips")
    d.bone_pair("FinB2", (-7.4, 3.4, 7.8), "FinB1L")
    tz = [10.0, 12.6, 15.0, 17.2, 19.2]
    ty = [5.2, 5.4, 5.5, 5.6, 5.6]
    tr = [2.8, 2.2, 1.6, 1.1, 0.6]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps large et rond
    d.ellipsoid("Chest", (0, 5.4, -2.0), (5.0, 4.2, 6.2), SIDE, where=left)
    d.ellipsoid("Hips", (0, 5.2, 5.4), (4.6, 3.9, 5.2), SIDE, where=left)
    # ---------------------------------------------------------------- long cou relevé en quatre segments épais
    neck = [(0, 6.4, -7.2), (0, 8.6, -11.0), (0, 10.8, -14.4), (0, 12.4, -17.6), (0, 13.4, -20.6)]
    nr = [2.8, 2.4, 2.1, 1.9, 1.8]
    for i in range(4):
        d.limb(f"Neck{i + 1}", neck[i], neck[i + 1], nr[i], nr[i + 1], SIDE, where=left)
    # ---------------------------------------------------------------- petite tête, museau fin, dents fines
    d.ellipsoid("Head", (0, 14.0, -22.6), (2.0, 1.8, 2.4), SIDE, where=lambda x, y, z: x <= 0 and y >= 13, power=2.6)
    d.limb("Head", (0, 13.8, -24.0), (0, 13.4, -27.2), 1.3, 0.9, SIDE, where=lambda x, y, z: x <= 0 and y >= 13)
    d.limb("Jaw", (0, 12.6, -23.0), (0, 12.6, -26.8), 1.0, 0.7, BELLY, where=lambda x, y, z: x <= 0 and y <= 12)
    d.box("Head", (0, 13, -26), (0, 13, -23), MOUTH)
    d.box("Jaw", (0, 12, -26), (0, 12, -23), MOUTH)
    for z in (-26, -24):
        x = d.surface_x(13, z, "Head")
        if x is not None:
            d.set("Head", x, 13, z, TOOTH, "Smooth")
        x = d.surface_x(12, z + 1, "Jaw")
        if x is not None:
            d.set("Jaw", x, 12, z + 1, TOOTH, "Smooth")
    # ---------------------------------------------------------------- quatre grandes nageoires (plaques de 2 voxels)
    d.plate("FinF1L", 1, 2, [(-3.6, -6.4), (-8.6, -5.0), (-8.6, -1.4), (-3.6, -2.0)], FIN, thick=2)
    d.plate("FinF2L", 1, 2, [(-8.6, -5.0), (-13.0, -2.8), (-13.4, -1.0), (-8.6, -1.4)], FIN, thick=2)
    d.plate("FinB1L", 1, 2, [(-3.4, 5.6), (-7.4, 6.4), (-7.4, 9.2), (-3.4, 8.8)], FIN, thick=2)
    d.plate("FinB2L", 1, 2, [(-7.4, 6.4), (-11.0, 8.2), (-11.2, 9.8), (-7.4, 9.2)], FIN, thick=2)
    # ---------------------------------------------------------------- queue courte et petite nageoire de queue
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], SIDE, where=left)
    d.plate("Tail4", 0, 0, [(5.0, 17.4), (8.0, 18.6), (8.4, 20.6), (5.6, 20.0), (3.0, 20.4), (3.2, 18.6)], FIN)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 14, -23, IRIS, PUPIL, lid_color=BACK, h=1, w=2)
    d.mirror()
    # contre-ombrage coupé à plat : dos foncé tacheté, flancs, ventre clair (le cou relevé suit sa pente)
    top = {"Chest": 7, "Hips": 7, "Tail1": 7, "Tail2": 7, "Tail3": 7}
    low = {"Chest": 3, "Hips": 3, "Tail1": 4, "Tail2": 4}

    def paint(x, y, z, bone, c):
        if c != SIDE:
            return None
        if bone in low and y <= low[bone]:
            return BELLY
        if bone in top and y >= top[bone]:
            return SPOT if bone in ("Chest", "Hips") and abs(x) in (2, 3) and z % 5 == 0 else BACK
        if bone.startswith("Neck"):
            # cou relevé : dos et gorge coupés le long de son axe (il monte de 0,52 voxel par voxel vers l'avant)
            axis = 6.4 - 0.52 * (z + 7.2)
            if y >= axis + 1.0:
                return BACK
            if y <= axis - 1.6:
                return BELLY
        if bone == "Head" and y >= 15:
            return BACK
        return None
    d.paint(paint)
    return d
