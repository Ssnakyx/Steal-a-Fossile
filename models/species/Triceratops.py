"""Triceratops : quadrupède du Canyon, lourd et têtu (pilote de la famille Quadruped).

Voxels de 0,44 stud : environ 20 studs de long et 10 de haut (collerette comprise) à la taille Normal.
La collerette est une plaque droite (peu de pièces) inclinée vers l'arrière par la rotation de repos de son os."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.44

BODY = (112, 152, 94)
DARK = (80, 116, 70)
BELLY = (212, 206, 162)
FRILL = (228, 114, 60)
RIM = (168, 62, 46)
SPOT = (252, 214, 118)
HORN = (246, 238, 216)
BEAK = (74, 66, 62)
NAIL = (232, 224, 202)
PUPIL = (26, 22, 20)
IRIS = (255, 210, 80)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.85,          # lourd, posé
    "weight": 1.35,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 0.8,
    "diet": "plants",
    "happy": "stomp",       # se cabre un peu et tape des pattes avant
    "catch": "toss",        # charge tête basse puis relève les cornes
}


def build():
    d = Dino("Triceratops", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.5, 4))
    d.bone("Chest", (0, 9.5, 0.5), "Hips")
    d.bone("Neck1", (0, 10, -7.5), "Chest")
    d.bone("Head", (0, 10.5, -10), "Neck1")
    d.bone("Jaw", (0, 8.8, -12.3), "Head")
    d.bone("Frill", (0, 12.8, -10.3), "Head", rest=(30, 0, 0))
    d.bone_pair("Lid", (-3.4, 13, -14.5), "Head")
    d.bone_pair("Arm", (-4.8, 8.0, -4.6), "Chest")
    d.bone_pair("Forearm", (-5.6, 5.0, -2.8), "ArmL")
    d.bone_pair("Hand", (-5.4, 2.0, -5.0), "ForearmL")
    d.bone_pair("Thigh", (-4.6, 9.2, 5.5), "Hips")
    d.bone_pair("Shin", (-5.1, 5.0, 3.6), "ThighL")
    d.bone_pair("Foot", (-5.2, 2.2, 6.0), "ShinL")
    tz = [11.2, 14.8, 18.2, 21.4, 24.2]
    ty = [10.6, 9.8, 9.0, 8.3, 7.8]
    tr = [3.9, 3.0, 2.2, 1.4, 0.7]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps (tonneau bas sur pattes)
    d.ellipsoid("Hips", (0, 10, 5.5), (5.6, 5.4, 6.4), BODY, where=left, power=2.9)
    d.ellipsoid("Chest", (0, 9.3, -2.5), (5.3, 5.0, 5.6), BODY, where=left, power=2.9)
    d.limb("Neck1", (0, 9.8, -6.8), (0, 10.4, -9.6), 3.7, 3.4, BODY, where=left)
    # ---------------------------------------------------------------- tête : gros crâne, museau, bec, trois cornes
    d.ellipsoid("Head", (0, 10.8, -12.6), (3.6, 3.8, 3.8), BODY, where=left, power=2.3)
    d.ellipsoid("Head", (0, 9.8, -16.4), (2.5, 2.8, 3.2), BODY, where=lambda x, y, z: x <= 0 and y >= 8.8, power=2.3)
    d.ellipsoid("Head", (0, 9.5, -19.2), (1.6, 2.0, 1.5), BEAK, where=lambda x, y, z: x <= 0 and y >= 8.8)
    d.limb("Head", (-2.2, 13.6, -13.4), (-3.0, 17.4, -18.6), 1.0, 0.4, HORN)
    d.limb("Head", (0, 12.2, -17.2), (0, 14.0, -18.8), 0.9, 0.35, HORN)
    d.ellipsoid("Jaw", (0, 8.0, -15.8), (2.1, 1.1, 3.4), BODY, where=lambda x, y, z: x <= 0 and y <= 8.2, power=2.4)
    d.ellipsoid("Jaw", (0, 8.1, -18.6), (1.2, 1.0, 1.2), BEAK, where=lambda x, y, z: x <= 0 and y <= 8.2)
    for z in range(-18, -13):
        if (0, 9, z) in d.vox:
            d.set("Head", 0, 9, z, MOUTH)
        if (0, 8, z) in d.vox:
            d.set("Jaw", 0, 8, z, MOUTH)
    # ---------------------------------------------------------------- collerette : plaque droite de 2 voxels
    # forme presque carrée aux coins arrondis (superellipse) : bords en marches régulières, peu de pièces
    cy, R = 17.6, 7.4

    def inside(x, y, r):
        return (abs(x) / r) ** 3.2 + (abs(y - cy) / r) ** 3.2 <= 1.0

    for x in range(-8, 1):
        for y in range(12, 26):
            if inside(x, y, R):
                col = FRILL if inside(x, y, R - 1.3) else RIM
                if col == FRILL and abs(x + 4) <= 1 and 19 <= y <= 21:
                    col = SPOT
                d.set("Frill", x, y, -10, col)
                d.set("Frill", x, y, -9, col)
                if col == RIM:
                    d.set("Frill", x, y, -8, RIM)  # bord en relief vers l'arrière : la collerette a de l'épaisseur
    for (x, y) in ((-2, 25), (-5, 24), (-7, 21)):
        for z in (-10, -9, -8):
            d.set("Frill", x, y, z, RIM)
    # ---------------------------------------------------------------- pattes
    # articulations pliées au repos (genou devant, coude derrière) : l'IK a de la marge pour marcher
    d.limb("ArmL", (-4.9, 8.0, -4.6), (-5.6, 5.0, -2.8), 2.2, 1.9, BODY)
    d.limb("ForearmL", (-5.6, 5.0, -2.8), (-5.4, 2.0, -5.0), 1.9, 1.6, BODY)
    d.limb("HandL", (-5.4, 2.0, -5.0), (-5.4, 0.7, -5.6), 1.6, 1.6, BODY)
    d.box("HandL", (-7, 0, -8), (-4, 1, -5), BODY)
    for x in (-7, -5):
        d.set("HandL", x, 0, -9, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-5.0, 7.0, 5.0), (2.5, 3.6, 3.2), BODY)
    d.limb("ShinL", (-5.1, 5.0, 3.6), (-5.2, 2.2, 6.0), 2.0, 1.8, BODY)
    d.limb("FootL", (-5.2, 2.2, 6.0), (-5.2, 0.7, 4.8), 1.8, 1.8, BODY)
    d.box("FootL", (-7, 0, 2), (-3, 1, 6), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 2))
    d.point("FrontToeL", "HandL", (-5.5, 0, -8))
    # ---------------------------------------------------------------- queue
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 11, -15, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)  # rien sous le sol
    d.mirror()
    # ventre clair et dos plus foncé coupés à plat (lignes droites : peu de pièces)
    belly = {"Hips": 6, "Chest": 5, "Neck1": 8, "Tail1": 9, "Tail2": 8, "Head": 8}
    saddle = {"Chest": 13}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else
            (DARK if c == BODY and bone in saddle and y >= saddle[bone] else None))
    return d
