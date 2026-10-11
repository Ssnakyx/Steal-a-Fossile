"""Megalodon : nageur géant de l'Ocean Trench, requin préhistorique, puissant et gourmand.

Voxels de 0,46 stud : environ 24 studs de long à la taille Normal. Corps en fuseau, museau conique, grande mâchoire
en dessous, ouïes, grandes nageoires pectorales et petites nageoires pelviennes (plaques), aileron dorsal et nageoire
de queue en croissant (plaques verticales). Neck1 = la partie des ouïes entre le torse et la tête.
Gardien de l'Ocean Trench (zone 7) : cette espèce x1,5 (Scale = 1.5, environ 36 studs de long)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.46

BACK = (86, 106, 128)
BELLY = (232, 236, 238)
FIN = (68, 86, 106)
GILL = (46, 58, 72)
TOOTH = (252, 250, 242)
MOUTH = (168, 68, 80)
PUPIL = (20, 20, 24)
IRIS = (236, 236, 236)

PERSONALITY = {
    "tempo": 0.9,           # puissant, ondulations amples
    "weight": 1.25,
    "tail": 1.2,
    "diet": "fish",
    "happy": "roll",
    "catch": "ram",         # coup de museau, gueule fermée à l'impact
}


def build():
    d = Dino("Megalodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 6, 6))
    d.bone("Chest", (0, 6.2, -1), "Hips")
    d.bone("Neck1", (0, 6.4, -9), "Chest")
    d.bone("Head", (0, 6.6, -12), "Neck1")
    d.bone("Jaw", (0, 5.0, -12.6), "Head")
    d.bone_pair("Lid", (-3.2, 9, -17), "Head")
    d.bone_pair("FinF1", (-4.2, 3.4, -6.0), "Chest")
    d.bone_pair("FinF2", (-7.6, 3.2, -4.8), "FinF1L")
    d.bone_pair("FinB1", (-3.0, 2.6, 8.4), "Hips")
    d.bone_pair("FinB2", (-5.2, 2.6, 9.4), "FinB1L")
    tz = [12.0, 15.4, 18.6, 21.6, 24.2, 26.4]
    ty = [6.6, 7.0, 7.4, 7.8, 8.2, 8.6]
    tr = [3.6, 2.8, 2.1, 1.5, 1.1, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps en fuseau
    d.ellipsoid("Chest", (0, 6.4, -3.6), (4.6, 5.4, 7.0), BACK, where=left)
    d.ellipsoid("Hips", (0, 6.4, 6.4), (4.0, 4.6, 6.6), BACK, where=left)
    d.ellipsoid("Neck1", (0, 6.6, -10.2), (4.2, 4.9, 2.8), BACK, where=left)
    # ---------------------------------------------------------------- tête : museau conique, grande mâchoire en dessous
    d.ellipsoid("Head", (0, 7.2, -15.6), (3.7, 3.7, 5.6), BACK, where=lambda x, y, z: x <= 0 and y >= 5)
    d.ellipsoid("Jaw", (0, 4.0, -15.4), (3.3, 1.7, 4.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 4)
    for z in range(-17, -11):
        if (0, 5, z) in d.vox:
            d.set("Head", 0, 5, z, MOUTH)
        if (0, 4, z) in d.vox:
            d.set("Jaw", 0, 4, z, MOUTH)
    # dents triangulaires au bord des mâchoires (une sur deux)
    for z in range(-19, -12, 2):
        x = d.surface_x(5, z, "Head")
        if x is not None:
            d.set("Head", x, 5, z, TOOTH, "Smooth")
        x = d.surface_x(4, z + 1, "Jaw")
        if x is not None:
            d.set("Jaw", x, 4, z + 1, TOOTH, "Smooth")
    # ---------------------------------------------------------------- nageoires pectorales et pelviennes (plaques)
    d.plate("FinF1L", 1, 2, [(-3.6, -8.0), (-7.6, -6.6), (-7.6, -2.8), (-3.6, -4.4)], FIN, thick=2)
    d.plate("FinF2L", 1, 2, [(-7.6, -6.6), (-11.6, -2.6), (-10.0, -1.6), (-7.6, -2.8)], FIN, thick=2)
    d.plate("FinB1L", 1, 2, [(-2.6, 7.2), (-5.2, 8.4), (-5.2, 10.6), (-2.6, 10.2)], FIN)
    d.plate("FinB2L", 1, 2, [(-5.2, 8.4), (-7.0, 10.6), (-6.6, 11.6), (-5.2, 10.6)], FIN)
    # ---------------------------------------------------------------- queue et nageoire en croissant (verticale)
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BACK, where=left)
    d.plate("Tail5", 0, 0, [(8.6, 24.4), (13.6, 26.4), (17.6, 30.8), (15.2, 31.0), (11.0, 28.2), (8.6, 28.6),
                            (6.0, 28.2), (2.6, 30.2), (1.6, 29.6), (4.6, 26.0)], FIN)
    # ---------------------------------------------------------------- yeux, ouïes, symétrie, peinture
    d.eye("Head", "LidL", 8, -17, IRIS, PUPIL, lid_color=BACK, h=1, w=2)
    for z in (-11, -9):
        for y in range(4, 10):
            x = d.surface_x(y, z, "Neck1")
            if x is not None:
                d.set("Neck1", x, y, z, GILL)
    d.mirror()
    # ventre blanc coupé à plat (requin), dos gris-bleu
    low = {"Chest": 5, "Hips": 5, "Neck1": 5, "Head": 5, "Tail1": 5, "Tail2": 6, "Tail3": 7}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BACK and bone in low and y <= low[bone] else None)
    # ---------------------------------------------------------------- aileron dorsal (plaque verticale, au milieu)
    d.plate("Chest", 0, 0, [(10.6, -4.6), (17.6, -1.2), (17.2, 0.4), (10.6, 2.6)], FIN)
    return d
