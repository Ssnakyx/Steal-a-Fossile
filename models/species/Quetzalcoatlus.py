"""Quetzalcoatlus : volant géant du Meteor Crater, grand échassier du ciel, calme et curieux.

Modélisé ailes déployées (plaques horizontales : peu de pièces), voxels de 0,42 stud : environ 26 studs d'envergure
à la taille Normal. Long cou raide en trois segments, bec immense et pointu, petite crête, longues pattes. Au parc il
marche replié sur ses pattes et ses mains (les animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.42

BODY = (228, 226, 220)
BACK = (152, 150, 168)
WING = (88, 78, 150)
WING_DARK = (58, 50, 108)
BONE = (64, 58, 100)
CREST = (236, 98, 52)
BEAK = (238, 214, 152)
BEAK_TIP = (206, 162, 92)
CLAW = (52, 46, 60)
PUPIL = (26, 22, 20)
IRIS = (255, 214, 90)
MOUTH = (200, 110, 100)

PERSONALITY = {
    "tempo": 0.9,           # grand, pas posés
    "weight": 1.0,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.4,
    "tail": 0.4,
    "diet": "meat",
    "happy": "flap",
    "catch": "peck",        # coup de bec plongé (bec fermé à l'impact)
}


def build():
    d = Dino("Quetzalcoatlus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 11, 3))
    d.bone("Chest", (0, 11.8, 0.4), "Hips")
    d.bone("Neck1", (0, 14.0, -3.4), "Chest")
    d.bone("Neck2", (0, 17.4, -5.4), "Neck1")
    d.bone("Neck3", (0, 20.6, -7.2), "Neck2")
    d.bone("Head", (0, 23.4, -8.6), "Neck3")
    d.bone("Jaw", (0, 23.6, -10.8), "Head")
    d.bone_pair("Lid", (-1.6, 26, -11), "Head")
    d.bone_pair("Wing1", (-2.6, 13, -1.4), "Chest")
    d.bone_pair("Wing2", (-8, 13, -1.4), "Wing1L")
    d.bone_pair("Wing3", (-17.5, 13, -2.0), "Wing2L")
    d.bone_pair("Thigh", (-1.8, 10.4, 4.0), "Hips")
    d.bone_pair("Shin", (-2.1, 6.6, 1.8), "ThighL")
    d.bone_pair("Foot", (-2.1, 2.4, 4.6), "ShinL")
    d.bone("Tail1", (0, 11.4, 6.0), "Hips")
    d.bone("Tail2", (0, 11.6, 8.0), "Tail1")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps court
    d.ellipsoid("Hips", (0, 11.6, 3.2), (2.6, 2.4, 2.8), BODY, where=left)
    d.ellipsoid("Chest", (0, 12.2, -0.8), (3.0, 3.0, 3.4), BODY, where=left)
    # ---------------------------------------------------------------- long cou raide en trois segments
    d.limb("Neck1", (0, 13.6, -3.0), (0, 17.4, -5.4), 1.8, 1.6, BODY, where=left)
    d.limb("Neck2", (0, 17.4, -5.4), (0, 20.6, -7.2), 1.6, 1.5, BODY, where=left)
    d.limb("Neck3", (0, 20.6, -7.2), (0, 23.4, -8.6), 1.5, 1.5, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne, bec immense, petite crête
    d.ellipsoid("Head", (0, 25.0, -9.8), (1.8, 1.8, 2.4), BODY, where=lambda x, y, z: x <= 0 and y >= 24)
    d.limb("Head", (0, 24.6, -11.6), (0, 24.2, -21.0), 1.3, 0.35, BEAK, where=lambda x, y, z: x <= 0 and y >= 24)
    d.limb("Jaw", (0, 23.2, -11.6), (0, 23.6, -20.0), 1.0, 0.35, BEAK, where=lambda x, y, z: x <= 0 and y <= 23)
    for z in range(-21, -17):
        for bone, y in (("Head", 24), ("Jaw", 23)):
            if (0, y, z) in d.vox:
                d.set(bone, 0, y, z, BEAK_TIP)
    for z in range(-15, -11):
        if (0, 24, z) in d.vox:
            d.set("Head", 0, 24, z, MOUTH)
    d.limb("Head", (0, 26.4, -10.4), (0, 27.8, -7.6), 1.0, 0.4, CREST, where=left)
    # ---------------------------------------------------------------- ailes (gauche)
    # membrane d'abord : plaque horizontale derrière le bras, partagée entre les trois os de l'aile selon x
    edge = [(-2.2, -1.0), (-8, -1.0), (-17.5, -1.6), (-31, 1.0), (-25, 3.4), (-17, 5.4), (-9, 6.6), (-3, 6.2),
            (-2, 4.8)]
    d.plate("Wing1L", 1, 13, edge, WING)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col == WING:
            if x <= -18:
                d.set("Wing3L", x, y, z, WING)
            elif x <= -9:
                d.set("Wing2L", x, y, z, WING)
    # bord de fuite plus foncé et deux nervures
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if col == WING and bone.startswith("Wing"):
            if (x, y, z + 1) not in d.vox:
                d.set(bone, x, y, z, WING_DARK)
            elif x in (-13, -24) and z > 0:
                d.set(bone, x, y, z, WING_DARK)
    # puis les os : bras, avant-bras, doigt-aile (bord d'attaque)
    d.limb("Wing1L", (-2.6, 13, -1.4), (-8, 13, -1.4), 1.2, 0.95, BONE)
    d.limb("Wing2L", (-8, 13, -1.4), (-17.5, 13, -2.0), 0.85, 0.65, BONE)
    d.limb("Wing3L", (-17.5, 13, -2.0), (-31, 13, 1.0), 0.6, 0.3, BONE)
    # griffes de la main (au poignet, vers l'avant) : elles touchent le sol quand il marche
    d.box("Wing2L", (-18, 12, -4), (-17, 12, -3), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-17.5, 12, -3.6))
    d.point("WingTipL", "Wing3L", (-31, 13, 1.0))
    # ---------------------------------------------------------------- longues pattes
    d.limb("ThighL", (-1.8, 10.4, 4.0), (-2.1, 6.6, 1.8), 1.3, 1.0, BODY)
    d.limb("ShinL", (-2.1, 6.6, 1.8), (-2.1, 2.4, 4.6), 0.9, 0.7, BACK)
    d.limb("FootL", (-2.1, 2.4, 4.6), (-2.1, 0.6, 3.0), 0.7, 0.7, BACK)
    d.box("FootL", (-3, 0, 1), (-1, 0, 3), BACK)
    for x in (-3, -1):
        d.set("FootL", x, 0, 0, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-2, 0, 1.2))
    # ---------------------------------------------------------------- queue courte
    d.limb("Tail1", (0, 11.4, 6.0), (0, 11.6, 8.0), 0.9, 0.55, BODY, where=left)
    d.limb("Tail2", (0, 11.6, 8.0), (0, 11.8, 9.8), 0.55, 0.3, BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 25, -11, IRIS, PUPIL, lid_color=BACK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    d.paint(lambda x, y, z, bone, c: BACK if c == BODY and bone in ("Hips", "Chest", "Tail1") and
            y >= {"Hips": 13, "Chest": 14, "Tail1": 12}[bone] else None)
    return d
