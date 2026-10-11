"""Iguanodon : quadrupède robuste du Swamp, tranquille, tête de cheval à bec et pouces en pointe.

Voxels de 0,23 stud : environ 12 studs de long et 4,5 de haut à la taille Normal.
Pattes arrière fortes, pattes avant plus fines avec un pouce en pointe (sans danger : il pointe vers le haut)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.23

BODY = (192, 108, 74)
DARK = (134, 70, 50)
BELLY = (240, 218, 178)
BEAK = (92, 76, 66)
THUMB = (246, 238, 220)
NAIL = (236, 226, 204)
PUPIL = (26, 22, 20)
IRIS = (255, 214, 90)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.9,
    "weight": 1.2,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 0.9,
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
}


def build():
    d = Dino("Iguanodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 11, 5))
    d.bone("Chest", (0, 10.4, 1), "Hips")
    d.bone("Neck1", (0, 11.4, -6), "Chest")
    d.bone("Neck2", (0, 13.2, -8.8), "Neck1")
    d.bone("Head", (0, 14.8, -11), "Neck2")
    d.bone("Jaw", (0, 13.8, -13.4), "Head")
    d.bone_pair("Lid", (-2.4, 17, -14), "Head")
    d.bone_pair("Arm", (-4.4, 9.4, -3.6), "Chest")
    d.bone_pair("Forearm", (-4.8, 6.0, -2.2), "ArmL")
    d.bone_pair("Hand", (-4.8, 2.6, -4.2), "ForearmL")
    d.bone_pair("Thigh", (-4.8, 10.4, 6), "Hips")
    d.bone_pair("Shin", (-5.2, 5.6, 3.8), "ThighL")
    d.bone_pair("Foot", (-5.2, 2.4, 6.6), "ShinL")
    tz = [12.0, 16.0, 20.0, 23.8, 27.4, 30.6]
    ty = [11.4, 11.2, 10.8, 10.3, 9.8, 9.4]
    tr = [4.2, 3.4, 2.6, 1.9, 1.2, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps massif
    d.ellipsoid("Hips", (0, 11.2, 6), (5.2, 5.4, 6.4), BODY, where=left, power=2.7)
    d.ellipsoid("Chest", (0, 10.2, -1.4), (5.0, 5.0, 5.4), BODY, where=left, power=2.7)
    d.limb("Neck1", (0, 11.0, -5.4), (0, 13.2, -8.8), 3.2, 2.8, BODY, where=left)
    d.limb("Neck2", (0, 13.2, -8.8), (0, 14.8, -11.0), 2.8, 2.6, BODY, where=left)
    # ---------------------------------------------------------------- longue tête de cheval, bec
    d.ellipsoid("Head", (0, 16.0, -12.8), (2.7, 2.7, 2.9), BODY, where=left, power=2.4)
    d.ellipsoid("Head", (0, 15.2, -16.6), (2.1, 1.9, 2.9), BODY, where=lambda x, y, z: x <= 0 and y >= 14, power=2.4)
    d.ellipsoid("Head", (0, 14.8, -19.2), (1.6, 1.3, 1.3), BEAK, where=lambda x, y, z: x <= 0 and y >= 14)
    d.ellipsoid("Jaw", (0, 13.2, -16.0), (1.8, 1.1, 3.0), BELLY, where=lambda x, y, z: x <= 0 and y <= 13, power=2.4)
    d.ellipsoid("Jaw", (0, 13.2, -18.6), (1.3, 0.9, 1.1), BEAK, where=lambda x, y, z: x <= 0 and y <= 13)
    d.box("Jaw", (-1, 13, -13), (0, 13, -12), BODY)
    for z in range(-19, -12):
        if (0, 14, z) in d.vox:
            d.set("Head", 0, 14, z, MOUTH)
    d.set("Head", -1, 16, -20, DARK, "Smooth")  # narine
    # ---------------------------------------------------------------- pattes avant avec pouce en pointe
    d.limb("ArmL", (-4.4, 9.4, -3.6), (-4.8, 6.0, -2.2), 2.0, 1.7, BODY)
    d.limb("ForearmL", (-4.8, 6.0, -2.2), (-4.8, 2.6, -4.2), 1.6, 1.4, BODY)
    d.limb("HandL", (-4.8, 2.6, -4.2), (-4.8, 0.7, -4.8), 1.4, 1.4, BODY)
    d.box("HandL", (-6, 0, -6), (-3, 1, -4), BODY)
    for x in (-6, -4):
        d.set("HandL", x, 0, -7, NAIL, "Smooth")
    d.limb("HandL", (-4.4, 2.2, -5.6), (-3.4, 4.4, -7.8), 0.85, 0.3, THUMB, "Smooth")
    # ---------------------------------------------------------------- pattes arrière
    d.ellipsoid("ThighL", (-5.2, 7.8, 5.4), (2.8, 4.2, 3.6), BODY)
    d.limb("ShinL", (-5.2, 5.6, 3.8), (-5.2, 2.4, 6.6), 2.1, 1.8, BODY)
    d.limb("FootL", (-5.2, 2.4, 6.6), (-5.2, 0.8, 4.8), 1.8, 1.8, BODY)
    d.box("FootL", (-7, 0, 2), (-3, 1, 6), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 2))
    d.point("FrontToeL", "HandL", (-4.5, 0, -6.5))
    # ---------------------------------------------------------------- queue épaisse
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 16, -15, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 8, "Chest": 7, "Neck1": 10, "Neck2": 12, "Tail1": 9, "Tail2": 9, "Tail3": 9}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3"], DARK, frac=0.2, period=6, width=2, only=[BODY])
    return d
