"""Argentinosaurus : quadrupède Legendary du Meteor Crater, le plus grand des dinosaures.

Voxels de 0,7 stud (gros voxels : le géant reste sous 450 pièces) : environ 35 studs de long et 18 de haut à la taille
Normal, la plus grande dimension est la longueur. Sauropode titanesque gris ardoise bleuté au ventre clair, larges
bandes sombres en travers du dos, du cou et de la queue. Énorme tonneau de corps sur quatre pattes en colonnes, long cou
presque horizontal en quatre segments épais, petite tête, longue queue effilée en cinq segments."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.64

BODY = (100, 113, 134)
DARK = (54, 62, 84)
BELLY = (216, 216, 208)
NAIL = (232, 226, 210)
PUPIL = (26, 22, 20)
IRIS = (255, 196, 64)
MOUTH = (176, 92, 104)

PERSONALITY = {
    "tempo": 0.6,           # le plus lent de tous : chaque pas fait trembler le sol
    "weight": 1.8,
    "stride": 1.1,
    "bob": 0.5,
    "headBob": 0.0,
    "tail": 0.8,
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.4,
}


def build():
    d = Dino("Argentinosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15, 6))
    d.bone("Chest", (0, 15.5, -1), "Hips")
    neck = [(0, 18.6, -8.0), (0, 19.6, -12.4), (0, 20.9, -16.6), (0, 22.4, -20.3), (0, 24.0, -23.6)]
    nr = [3.7, 3.1, 2.6, 2.2, 2.0]
    for i in range(4):
        d.bone(f"Neck{i + 1}", neck[i], "Chest" if i == 0 else f"Neck{i}")
    d.bone("Head", neck[4], "Neck4")
    d.bone("Jaw", (0, 23.6, -24.8), "Head")
    d.bone_pair("Lid", (-2.0, 26, -27), "Head")
    d.bone_pair("Arm", (-4.5, 14.5, -4.5), "Chest")
    d.bone_pair("Forearm", (-4.5, 8.6, -1.4), "ArmL")
    d.bone_pair("Hand", (-4.5, 2.6, -4.6), "ForearmL")
    d.bone_pair("Thigh", (-4.4, 14.0, 7.5), "Hips")
    d.bone_pair("Shin", (-4.5, 8.0, 4.8), "ThighL")
    d.bone_pair("Foot", (-4.5, 2.6, 8.0), "ShinL")
    tz = [11.0, 14.8, 18.2, 21.2, 23.8, 26.0]
    ty = [16.8, 16.5, 15.9, 15.0, 13.9, 12.9]
    tr = [4.0, 3.1, 2.4, 1.8, 1.2, 0.6]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : un énorme tonneau coupé en deux
    d.ellipsoid("Hips", (0, 15.2, 1.5), (6.4, 7.0, 10.0), BODY, where=lambda x, y, z: x <= 0 and y >= 9, power=3.0)
    for k, (b, c, m) in list(d.vox.items()):
        if k[2] < 1:
            d.vox[k] = ("Chest", c, m)
    # ---------------------------------------------------------------- long cou presque horizontal (segments épais)
    d.limb("Neck1", (0, 18.0, -7.0), neck[1], nr[0], nr[1], BODY, where=left)
    for i in range(1, 4):
        d.limb(f"Neck{i + 1}", neck[i], neck[i + 1], nr[i], nr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- petite tête de sauropode, museau carré
    d.ellipsoid("Head", (0, 24.8, -25.8), (2.2, 2.1, 2.8), BODY, where=lambda x, y, z: x <= 0 and y >= 24, power=2.8)
    d.ellipsoid("Jaw", (0, 23.4, -26.0), (1.9, 1.1, 2.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 23, power=2.6)
    for z in range(-27, -23):
        if (0, 24, z) in d.vox:
            d.set("Head", 0, 24, z, MOUTH)
        if (0, 23, z) in d.vox:
            d.set("Jaw", 0, 23, z, MOUTH)
    # ---------------------------------------------------------------- pattes en colonnes massives
    # pivots pliés (coude derrière, genou devant : l'IK a de la marge) mais segments droits, comme des piliers
    d.limb("ArmL", (-4.5, 13.5, -3.5), (-4.5, 8.6, -3.5), 2.9, 2.8, BODY)
    d.limb("ForearmL", (-4.5, 8.6, -3.5), (-4.5, 2.6, -3.5), 2.8, 2.7, BODY)
    d.limb("HandL", (-4.5, 2.6, -3.5), (-4.5, 0.8, -3.5), 2.7, 2.7, BODY)
    d.box("HandL", (-7, 0, -7), (-2, 1, -1), BODY)
    for x in (-7, -5, -4, -2):
        d.set("HandL", x, 0, -8, NAIL, "Smooth")
    d.point("FrontToeL", "HandL", (-4.5, 0, -7))
    d.limb("ThighL", (-4.5, 13.0, 6.5), (-4.5, 8.0, 6.5), 3.1, 2.8, BODY)
    d.limb("ShinL", (-4.5, 8.0, 6.5), (-4.5, 2.6, 6.5), 2.8, 2.7, BODY)
    d.limb("FootL", (-4.5, 2.6, 6.5), (-4.5, 0.8, 6.5), 2.7, 2.7, BODY)
    d.box("FootL", (-7, 0, 3), (-2, 1, 9), BODY)
    for x in (-7, -5, -4, -2):
        d.set("FootL", x, 0, 2, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, 3))
    # ---------------------------------------------------------------- longue queue effilée
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 25, -27, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Chest": 11, "Hips": 11}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Neck1", "Neck2", "Neck3", "Chest", "Hips", "Tail1", "Tail2", "Tail3"], DARK,
                   frac=0.45, period=7, width=3, only=[BODY])
    return d
