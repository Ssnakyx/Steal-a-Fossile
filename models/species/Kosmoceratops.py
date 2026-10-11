"""Kosmoceratops : quadrupède Legendary du Meteor Crater, le cératopsien à la collerette la plus ornée.

Voxels de 0,32 stud : environ 14 studs de long et 8 de haut (collerette comprise) à la taille Normal. Corps sable
chaud à selle brune, ventre crème. Collerette courte et large (plaque droite inclinée vers l'arrière par la rotation de
repos de son os) : magenta bordée de violet, couronnée d'une rangée de crochets dorés recourbés vers l'avant.
Cornes frontales dorées pointées sur les côtés, petite corne nasale en lame, bec sombre."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.32

BODY = (220, 172, 106)
DARK = (170, 112, 66)
BELLY = (246, 228, 186)
FRILL = (196, 54, 150)
RIM = (106, 46, 156)
GOLD = (255, 200, 58)
BEAK = (72, 56, 64)
NAIL = (246, 236, 210)
PUPIL = (26, 22, 20)
IRIS = (255, 206, 70)
MOUTH = (186, 92, 110)

PERSONALITY = {
    "tempo": 0.95,          # cératopsien moyen, plus vif que le Triceratops
    "weight": 1.15,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 0.9,
    "diet": "plants",
    "happy": "stomp",       # se cabre un peu et tape des pattes avant
    "catch": "toss",        # charge tête basse puis relève les cornes
}


def build():
    d = Dino("Kosmoceratops", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.5, 4))
    d.bone("Chest", (0, 9.5, 0.5), "Hips")
    d.bone("Neck1", (0, 10, -7.5), "Chest")
    d.bone("Head", (0, 10.5, -10), "Neck1")
    d.bone("Jaw", (0, 8.8, -12.3), "Head")
    d.bone("Frill", (0, 13.4, -10.4), "Head", rest=(36, 0, 0))
    d.bone_pair("Lid", (-3.4, 13, -14.5), "Head")
    d.bone_pair("Arm", (-4.8, 8.0, -4.6), "Chest")
    d.bone_pair("Forearm", (-5.6, 5.0, -2.8), "ArmL")
    d.bone_pair("Hand", (-5.4, 2.0, -5.0), "ForearmL")
    d.bone_pair("Thigh", (-4.6, 9.2, 5.5), "Hips")
    d.bone_pair("Shin", (-5.1, 5.0, 3.6), "ThighL")
    d.bone_pair("Foot", (-5.2, 2.2, 6.0), "ShinL")
    tz = [11.0, 14.2, 17.2, 20.0, 22.4]
    ty = [10.6, 9.9, 9.2, 8.6, 8.2]
    tr = [3.8, 2.9, 2.1, 1.4, 0.7]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : un seul tonneau coupé en deux (torse / bassin)
    d.ellipsoid("Hips", (0, 9.8, 1.6), (5.4, 5.2, 10.4), BODY, where=left, power=3.0)
    for k, (b, c, m) in list(d.vox.items()):
        if k[2] < 1:
            d.vox[k] = ("Chest", c, m)
    d.limb("Neck1", (0, 9.8, -6.8), (0, 10.4, -9.6), 3.7, 3.4, BODY, where=left)
    # ---------------------------------------------------------------- tête : gros crâne, museau, bec, cornes dorées
    d.ellipsoid("Head", (0, 10.8, -12.6), (3.6, 3.8, 3.8), BODY, where=left, power=2.3)
    d.ellipsoid("Head", (0, 9.8, -16.2), (2.5, 2.8, 3.2), BODY, where=lambda x, y, z: x <= 0 and y >= 8.8, power=2.3)
    d.ellipsoid("Head", (0, 9.5, -19.0), (1.6, 2.0, 1.5), BEAK, where=lambda x, y, z: x <= 0 and y >= 8.8)
    # petite corne nasale en lame
    d.limb("Head", (0, 12.2, -16.8), (0, 14.0, -17.8), 1.0, 0.4, GOLD)
    # cornes frontales : partent au-dessus des yeux, pointées sur les côtés, bout un peu relevé vers l'avant
    d.limb("Head", (-2.4, 13.2, -13.4), (-6.4, 14.2, -14.2), 1.2, 0.85, GOLD)
    d.limb("Head", (-6.4, 14.2, -14.2), (-8.2, 16.6, -15.2), 0.85, 0.3, GOLD)
    d.ellipsoid("Jaw", (0, 8.0, -15.8), (2.1, 1.1, 3.4), BODY, where=lambda x, y, z: x <= 0 and y <= 8.2, power=2.4)
    d.ellipsoid("Jaw", (0, 8.1, -18.6), (1.2, 1.0, 1.2), BEAK, where=lambda x, y, z: x <= 0 and y <= 8.2)
    for z in range(-18, -13):
        if (0, 9, z) in d.vox:
            d.set("Head", 0, 9, z, MOUTH)
        if (0, 8, z) in d.vox:
            d.set("Jaw", 0, 8, z, MOUTH)
    # ---------------------------------------------------------------- collerette : plaque droite de 2 voxels
    # courte et large, plus étroite à la base (trapèze aux coins arrondis) : deux panneaux magenta dans un cadre
    # violet en relief (le bord et la barre du milieu), rangée de crochets dorés sur le haut
    y0, y1 = 11, 22

    def half(y):
        return 5.6 + (9.6 - 5.6) * min(1.0, max(0.0, (y - y0) / (y1 - 2 - y0)))

    def inside(x, y, k=0.0):
        if y < y0 + k or y > y1 - k:
            return False
        h = half(y) - k
        # coins du haut arrondis
        if y > y1 - 2.5 and abs(x) > h - (y - (y1 - 2.5)) * 1.1:
            return False
        return abs(x) <= h

    for x in range(-10, 1):
        for y in range(y0, y1 + 1):
            if inside(x, y):
                col = FRILL if inside(x, y, 1.0) and x < -1 else RIM
                d.set("Frill", x, y, -10, col)
                d.set("Frill", x, y, -9, col)
                if col == RIM:
                    d.set("Frill", x, y, -8, RIM)
    # crochets : chacun monte au-dessus du bord puis se recourbe vers l'avant et retombe (creux sous la courbe)
    for x0 in (-9, -6, -3):
        for x in (x0, x0 + 1):
            t = max(y for (xx, y, z), v in d.vox.items() if v[0] == "Frill" and xx == x)
            for (y, z) in ((t + 1, -10), (t + 1, -9), (t + 2, -10), (t + 2, -9), (t + 3, -10), (t + 3, -9),
                           (t + 4, -10), (t + 4, -11), (t + 4, -12), (t + 3, -11), (t + 3, -12), (t + 3, -13),
                           (t + 2, -13), (t + 1, -13)):
                d.set("Frill", x, y, z, GOLD)
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
    # ventre clair et selle brune coupés à plat (lignes droites : peu de pièces)
    belly = {"Hips": 6, "Chest": 6, "Neck1": 8, "Tail1": 9, "Tail2": 8, "Head": 8}
    saddle = {"Chest": 14, "Hips": 14, "Neck1": 13, "Tail1": 13}

    def paint(x, y, z, bone, c):
        if c != BODY:
            return None
        if bone in belly and y <= belly[bone]:
            return BELLY
        if bone in saddle and y >= saddle[bone]:
            return DARK
        return None
    d.paint(paint)
    # bandes brunes en travers du dos et de la queue (sous la selle)
    d.back_stripes(["Chest", "Hips", "Tail1", "Tail2"], DARK, frac=0.4, period=4, width=2, only=[BODY])
    return d
