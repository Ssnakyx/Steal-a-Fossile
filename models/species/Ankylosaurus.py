"""Ankylosaurus : quadrupède du Glacier, char d'assaut lent et têtu.

Voxels de 0,33 stud : environ 15 studs de long, 5 de haut et 7 de large à la taille Normal. Corps bas et large couvert
de bandes d'armure, épines sur les flancs, quatre cornes au coin du crâne, massue au bout de la queue (un seul bloc
carré, pas deux boules)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.33

BODY = (92, 118, 142)
ARMOR = (62, 82, 104)
BELLY = (198, 208, 206)
SPIKE = (240, 234, 214)
BEAK = (84, 78, 76)
NAIL = (232, 224, 202)
PUPIL = (26, 22, 20)
IRIS = (255, 196, 64)
MOUTH = (184, 92, 98)

PERSONALITY = {
    "tempo": 0.8,           # lent, pas lourds
    "weight": 1.45,
    "stride": 0.9,
    "bob": 0.7,
    "headBob": 0.0,
    "tail": 1.25,           # la massue balance largement
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.42,      # corps déjà bas : se couche moins loin
}


def build():
    d = Dino("Ankylosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 7.6, 5))
    d.bone("Chest", (0, 7.6, 0), "Hips")
    d.bone("Neck1", (0, 8.2, -11.5), "Chest")
    d.bone("Head", (0, 8.6, -14.8), "Neck1")
    d.bone("Jaw", (0, 6.6, -17.2), "Head")
    d.bone_pair("Lid", (-4.0, 10, -19), "Head")
    d.bone_pair("Arm", (-5.8, 6.2, -7.5), "Chest")
    d.bone_pair("Forearm", (-6.4, 3.8, -6.0), "ArmL")
    d.bone_pair("Hand", (-6.2, 1.6, -7.6), "ForearmL")
    d.bone_pair("Thigh", (-5.6, 7.2, 6.0), "Hips")
    d.bone_pair("Shin", (-6.0, 4.2, 4.6), "ThighL")
    d.bone_pair("Foot", (-6.0, 1.8, 6.6), "ShinL")
    tz = [11.5, 14.5, 17.4, 20.2, 22.2]
    ty = [8.4, 7.9, 7.4, 7.0, 6.8]
    tr = [3.4, 2.7, 2.1, 1.6, 1.3]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : dôme bas et large
    d.ellipsoid("Chest", (0, 8.8, -4.5), (7.2, 4.8, 8.0), BODY, where=left, power=2.5)
    d.ellipsoid("Hips", (0, 9.2, 5.2), (7.6, 5.0, 7.2), BODY, where=left, power=2.5)
    d.limb("Neck1", (0, 8.2, -11.0), (0, 8.6, -14.2), 3.4, 3.1, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne large et carré, petit bec, cornes
    d.ellipsoid("Head", (0, 8.8, -17.6), (4.3, 2.7, 3.3), BODY, where=lambda x, y, z: x <= 0 and y >= 7, power=3.0)
    d.ellipsoid("Head", (0, 8.0, -21.2), (2.0, 1.5, 1.3), BEAK, where=lambda x, y, z: x <= 0 and y >= 7, power=2.3)
    d.ellipsoid("Jaw", (0, 5.9, -19.0), (3.0, 1.3, 2.8), BODY, where=lambda x, y, z: x <= 0 and y <= 6, power=2.6)
    d.ellipsoid("Jaw", (0, 5.8, -21.2), (1.4, 0.9, 0.9), BEAK, where=lambda x, y, z: x <= 0 and y <= 6)
    for z in range(-20, -15):
        if (0, 7, z) in d.vox:
            d.set("Head", 0, 7, z, MOUTH)
        if (0, 6, z) in d.vox:
            d.set("Jaw", 0, 6, z, MOUTH)
    # cornes : deux en haut à l'arrière du crâne, deux plus petites sur les joues
    d.limb("Head", (-3.6, 10.6, -15.6), (-5.6, 11.8, -13.4), 1.0, 0.35, SPIKE)
    d.limb("Head", (-3.8, 7.4, -16.2), (-5.3, 5.8, -15.2), 0.85, 0.3, SPIKE)
    # ---------------------------------------------------------------- pattes courtes et massives
    d.ellipsoid("ThighL", (-5.8, 5.8, 5.8), (2.2, 2.6, 2.7), BODY)
    d.limb("ShinL", (-6.0, 4.2, 4.6), (-6.0, 1.8, 6.6), 2.0, 1.8, BODY)
    d.limb("FootL", (-6.0, 1.8, 6.6), (-6.0, 0.6, 5.6), 1.8, 1.8, BODY)
    d.box("FootL", (-8, 0, 3), (-4, 1, 7), BODY)
    for x in (-7, -5):
        d.set("FootL", x, 0, 2, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-6, 0, 3))
    d.limb("ArmL", (-5.8, 6.2, -7.5), (-6.4, 3.8, -6.0), 2.1, 1.9, BODY)
    d.limb("ForearmL", (-6.4, 3.8, -6.0), (-6.2, 1.6, -7.6), 1.9, 1.7, BODY)
    d.limb("HandL", (-6.2, 1.6, -7.6), (-6.2, 0.6, -8.2), 1.7, 1.7, BODY)
    d.box("HandL", (-8, 0, -10), (-5, 1, -7), BODY)
    for x in (-8, -6):
        d.set("HandL", x, 0, -11, NAIL, "Smooth")
    d.point("FrontToeL", "HandL", (-6.2, 0, -10))
    # ---------------------------------------------------------------- queue et massue (un seul bloc carré)
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    d.ellipsoid("Tail4", (0, 6.9, 22.6), (3.5, 2.0, 2.5), ARMOR, where=left, power=3.2)
    d.limb("Tail4", (-3.2, 6.9, 22.6), (-4.6, 6.9, 22.9), 0.8, 0.3, SPIKE)
    # ---------------------------------------------------------------- armure : grandes épines des flancs
    for z, bone in ((-9, "Chest"), (-3, "Chest"), (3, "Hips"), (9, "Hips")):
        x = d.surface_x(9, z, bone)
        if x is not None:
            d.limb(bone, (x + 0.6, 9, z), (x - 2.8, 9.4, z + 1.2), 1.35, 0.35, SPIKE)
    for z, bone in ((13.5, "Tail1"), (16.5, "Tail2")):
        x = d.surface_x(8, int(z), bone)
        if x is not None:
            d.limb(bone, (x + 0.5, 8, z), (x - 1.6, 8.2, z + 0.6), 0.85, 0.25, SPIKE)
    x = d.surface_x(9, -13, "Neck1")
    if x is not None:
        d.limb("Neck1", (x + 0.5, 9, -13), (x - 1.8, 10.0, -12.6), 0.95, 0.3, SPIKE)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 8, -19, IRIS, PUPIL, lid_color=ARMOR, h=2, w=2)
    # le crâne s'arrondit au-dessus de l'oeil : la paupière ressort d'un voxel (arcade) pour bien le couvrir
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "LidL" and x == -3:
            d.set("LidL", -4, y, z, col)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ventre clair coupé à plat, bandes d'armure sur le dos
    belly = {"Hips": 5, "Chest": 5, "Neck1": 6, "Tail1": 6, "Tail2": 6, "Tail3": 6}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Hips", "Chest", "Neck1", "Tail1", "Tail2", "Tail3"], ARMOR, frac=0.45, period=4, width=2,
                   only=[BODY])
    return d
