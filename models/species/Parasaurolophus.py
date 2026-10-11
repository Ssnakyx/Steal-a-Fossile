"""Parasaurolophus : quadrupède à bec de canard de la Fern Forest, calme, il « trompette » avec sa crête.

Voxels de 0,235 stud : environ 12 studs de long et 6 de haut (crête comprise) à la taille Normal.
La crête est une lame plate (os Crest, plaque droite inclinée vers l'arrière par sa rotation de repos) : pas de tube."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.235

BODY = (234, 178, 62)
DARK = (156, 98, 44)
BELLY = (246, 232, 192)
CREST = (214, 68, 48)
CREST_RIM = (150, 44, 40)
BILL = (238, 214, 160)
NAIL = (236, 226, 204)
PUPIL = (26, 22, 20)
IRIS = (255, 222, 96)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.95,
    "weight": 1.1,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 0.9,
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
}


def build():
    d = Dino("Parasaurolophus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 10.5, 5))
    d.bone("Chest", (0, 10, 1), "Hips")
    d.bone("Neck1", (0, 11, -6), "Chest")
    d.bone("Neck2", (0, 13.4, -8.6), "Neck1")
    d.bone("Head", (0, 15.6, -10.6), "Neck2")
    d.bone("Jaw", (0, 14.6, -13.0), "Head")
    d.bone("Crest", (0, 18.6, -11.6), "Head", rest=(-20, 0, 0))
    d.bone_pair("Lid", (-2.6, 18, -14), "Head")
    d.bone_pair("Arm", (-4.2, 8.6, -3.8), "Chest")
    d.bone_pair("Forearm", (-4.6, 5.4, -2.2), "ArmL")
    d.bone_pair("Hand", (-4.6, 2.2, -4.2), "ForearmL")
    d.bone_pair("Thigh", (-4.6, 9.8, 6), "Hips")
    d.bone_pair("Shin", (-5.0, 5.4, 3.8), "ThighL")
    d.bone_pair("Foot", (-5.0, 2.4, 6.4), "ShinL")
    tz = [11.5, 15.5, 19.4, 23.0, 26.4, 29.4]
    ty = [11.0, 10.8, 10.4, 9.9, 9.4, 9.0]
    tr = [4.0, 3.2, 2.4, 1.7, 1.1, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 10.6, 6), (5.0, 5.2, 6.2), BODY, where=left, power=2.6)
    d.ellipsoid("Chest", (0, 9.8, -1.2), (4.8, 4.8, 5.2), BODY, where=left, power=2.6)
    d.limb("Neck1", (0, 10.6, -5.4), (0, 13.4, -8.6), 3.2, 2.8, BODY, where=left)
    d.limb("Neck2", (0, 13.4, -8.6), (0, 15.6, -10.6), 2.8, 2.6, BODY, where=left)
    # ---------------------------------------------------------------- tête de cheval, bec de canard
    d.ellipsoid("Head", (0, 16.9, -12.4), (3.0, 3.0, 3.2), BODY, where=left, power=2.4)
    d.ellipsoid("Head", (0, 15.6, -16.2), (2.2, 1.9, 3.0), BODY, where=lambda x, y, z: x <= 0 and y >= 14.6, power=2.3)
    d.ellipsoid("Head", (0, 15.0, -18.8), (2.7, 1.2, 1.6), BILL, where=lambda x, y, z: x <= 0 and y >= 14.6)
    d.ellipsoid("Jaw", (0, 14.0, -15.6), (1.8, 1.0, 3.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 14, power=2.4)
    d.ellipsoid("Jaw", (0, 13.8, -18.4), (2.3, 0.9, 1.4), BILL, where=lambda x, y, z: x <= 0 and y <= 14)
    d.box("Jaw", (-1, 14, -13), (0, 14, -12), BODY)
    for z in range(-18, -12):
        if (0, 15, z) in d.vox:
            d.set("Head", 0, 15, z, MOUTH)
        if (0, 14, z) in d.vox:
            d.set("Jaw", 0, 14, z, MOUTH)
    # ---------------------------------------------------------------- crête : lame plate de 3 voxels d'épaisseur
    blade = [(17.6, -12.4), (21.4, -12.4), (21.6, -8), (21.2, -4), (20.4, -1), (19.6, 0.6), (18.6, 1.0), (18.0, 0.0), (18.0, -3), (17.9, -7)]
    d.plate("Crest", 0, -1, blade, CREST, thick=2)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Crest" and z >= -1:
            d.vox[(x, y, z)] = (bone, CREST_RIM, mat)
    # ---------------------------------------------------------------- pattes avant fines, pattes arrière fortes
    d.limb("ArmL", (-4.2, 8.6, -3.8), (-4.6, 5.4, -2.2), 1.8, 1.5, BODY)
    d.limb("ForearmL", (-4.6, 5.4, -2.2), (-4.6, 2.2, -4.2), 1.4, 1.2, BODY)
    d.limb("HandL", (-4.6, 2.2, -4.2), (-4.6, 0.7, -4.8), 1.2, 1.2, BODY)
    d.box("HandL", (-6, 0, -6), (-3, 1, -4), BODY)
    for x in (-6, -4):
        d.set("HandL", x, 0, -7, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-5.0, 7.6, 5.4), (2.6, 3.8, 3.4), BODY)
    d.limb("ShinL", (-5.0, 5.4, 3.8), (-5.0, 2.4, 6.4), 2.0, 1.7, BODY)
    d.limb("FootL", (-5.0, 2.4, 6.4), (-5.0, 0.8, 4.8), 1.7, 1.7, BODY)
    d.box("FootL", (-7, 0, 2), (-3, 1, 6), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 2))
    d.point("FrontToeL", "HandL", (-4.5, 0, -6.5))
    # ---------------------------------------------------------------- queue épaisse
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 17, -14, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 7, "Chest": 6, "Neck1": 9, "Neck2": 12, "Tail1": 8, "Tail2": 8, "Tail3": 8}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4"], DARK, frac=0.28, period=5, width=2, only=[BODY])
    return d
