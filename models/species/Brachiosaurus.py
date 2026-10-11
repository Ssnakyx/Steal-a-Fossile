"""Brachiosaurus : quadrupède géant du Volcano, lent et majestueux.

Voxels de 0,7 stud (gros voxels : le géant reste sous 450 pièces) : environ 32 studs de haut (tête comprise) et 29 de
long à la taille Normal, la plus grande dimension est la hauteur. Épaules plus hautes que le bassin, long cou presque
vertical en quatre segments épais, petite tête avec la bosse du nez, pattes en piliers, queue courte."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.7

BODY = (86, 146, 150)
DARK = (58, 104, 112)
BELLY = (224, 216, 182)
NAIL = (232, 224, 202)
PUPIL = (26, 22, 20)
IRIS = (255, 196, 64)
MOUTH = (186, 96, 100)

PERSONALITY = {
    "tempo": 0.65,          # lent et majestueux
    "weight": 1.6,
    "stride": 1.1,
    "bob": 0.6,
    "headBob": 0.0,
    "tail": 0.8,
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.4,
}


def build():
    d = Dino("Brachiosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 13.9, 6.6))
    d.bone("Chest", (0, 14.8, 0.8), "Hips")
    d.bone("Neck1", (0, 21.3, -7.8), "Chest")
    d.bone("Neck2", (0, 27.1, -9.8), "Neck1")
    d.bone("Neck3", (0, 32.8, -11.5), "Neck2")
    d.bone("Neck4", (0, 37.7, -12.7), "Neck3")
    d.bone("Head", (0, 41.3, -13.6), "Neck4")
    d.bone("Jaw", (0, 40.3, -15.1), "Head")
    d.bone_pair("Lid", (-2.0, 43, -17), "Head")
    d.bone_pair("Arm", (-4.6, 15.2, -5.3), "Chest")
    d.bone_pair("Forearm", (-4.9, 9.4, -2.1), "ArmL")
    d.bone_pair("Hand", (-4.9, 2.9, -5.7), "ForearmL")
    d.bone_pair("Thigh", (-4.4, 12.3, 8.2), "Hips")
    d.bone_pair("Shin", (-4.8, 7.1, 5.4), "ThighL")
    d.bone_pair("Foot", (-4.8, 2.3, 8.7), "ShinL")
    tz = [11.9, 14.9, 17.7, 20.0, 21.8]
    ty = [16.1, 14.8, 13.3, 12.0, 11.0]
    tr = [3.6, 2.8, 2.1, 1.4, 0.8]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : épaules hautes, bassin plus bas
    d.ellipsoid("Chest", (0, 17.2, -2.5), (5.7, 6.1, 6.9), BODY, where=left, power=3.3)
    d.ellipsoid("Hips", (0, 15.7, 6.2), (5.4, 5.2, 5.9), BODY, where=left, power=3.3)
    # ---------------------------------------------------------------- long cou presque vertical (segments épais)
    neck = [(0, 20.8, -7.2), (0, 27.1, -9.8), (0, 32.8, -11.5), (0, 37.7, -12.7), (0, 41.3, -13.6)]
    nr = [3.4, 3.0, 2.6, 2.2, 2.0]
    for i in range(4):
        d.limb(f"Neck{i + 1}", neck[i], neck[i + 1], nr[i], nr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- petite tête, bosse du nez, mâchoire
    d.ellipsoid("Head", (0, 42.0, -15.6), (2.3, 2.0, 2.8), BODY, where=lambda x, y, z: x <= 0 and y >= 41, power=3.0)
    d.ellipsoid("Head", (0, 41.5, -18.0), (1.7, 1.4, 1.5), BODY, where=lambda x, y, z: x <= 0 and y >= 41, power=2.3)
    d.ellipsoid("Head", (0, 44.0, -16.1), (1.5, 1.3, 1.6), DARK, where=left, power=2.4)
    d.ellipsoid("Jaw", (0, 40.2, -16.7), (1.8, 1.0, 2.5), BELLY, where=lambda x, y, z: x <= 0 and y <= 40, power=2.4)
    for z in range(-18, -14):
        if (0, 41, z) in d.vox:
            d.set("Head", 0, 41, z, MOUTH)
        if (0, 40, z) in d.vox:
            d.set("Jaw", 0, 40, z, MOUTH)
    # ---------------------------------------------------------------- pattes en piliers (avant plus longues)
    d.limb("ArmL", (-4.6, 15.2, -5.3), (-4.9, 9.4, -2.1), 2.4, 2.1, BODY)
    d.limb("ForearmL", (-4.9, 9.4, -2.1), (-4.9, 2.9, -5.7), 2.1, 1.8, BODY)
    d.limb("HandL", (-4.9, 2.9, -5.7), (-4.9, 0.7, -6.0), 1.8, 1.8, BODY)
    d.box("HandL", (-7, 0, -8), (-3, 1, -4), BODY)
    for x in (-6, -4):
        d.set("HandL", x, 0, -9, NAIL, "Smooth")
    d.point("FrontToeL", "HandL", (-5, 0, -7.5))
    d.ellipsoid("ThighL", (-4.8, 10.3, 7.2), (2.5, 3.8, 3.0), BODY)
    d.limb("ShinL", (-4.8, 7.1, 5.4), (-4.8, 2.3, 8.7), 2.1, 1.9, BODY)
    d.limb("FootL", (-4.8, 2.3, 8.7), (-4.8, 0.7, 8.2), 1.9, 1.9, BODY)
    d.box("FootL", (-7, 0, 6), (-3, 1, 10), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, 5, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 6.5))
    # ---------------------------------------------------------------- queue courte qui descend
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 42, -17, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ventre clair coupé à plat
    belly = {"Chest": 12, "Hips": 11}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    return d
