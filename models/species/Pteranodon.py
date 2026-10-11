"""Pteranodon : volant de la Beach (pilote de la famille Flyer).

Modélisé ailes déployées (plaques horizontales : peu de pièces), voxels de 0,26 stud : environ 16 studs d'envergure.
Au parc il se tient replié sur ses pattes et ses mains (les animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.26

BODY = (236, 222, 196)
BACK = (178, 150, 120)
WING = (198, 108, 72)
WING_DARK = (150, 76, 52)
BONE = (120, 72, 54)
CREST = (226, 70, 50)
BEAK = (250, 196, 78)
BEAK_TIP = (220, 150, 50)
CLAW = (60, 48, 44)
PUPIL = (26, 22, 20)
IRIS = (255, 230, 120)
MOUTH = (200, 110, 100)

PERSONALITY = {
    "tempo": 1.05,
    "weight": 0.8,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.6,
    "tail": 0.5,
    "diet": "fish",         # Eat : happe un poisson et l'avale tête levée
    "happy": "flap",        # Happy : petits bonds en battant des ailes
    "catch": "peck",        # Catch : coup de bec plongé (bec fermé à l'impact)
}


def build():
    d = Dino("Pteranodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 10, 3))
    d.bone("Chest", (0, 10.8, 0.5), "Hips")
    d.bone("Neck1", (0, 13.0, -3.8), "Chest")
    d.bone("Head", (0, 15.6, -5.9), "Neck1")
    d.bone("Jaw", (0, 15.0, -8.4), "Head")
    d.bone_pair("Lid", (-2.0, 17.5, -8.0), "Head")
    d.bone_pair("Wing1", (-2.6, 12, -1.5), "Chest")
    d.bone_pair("Wing2", (-7, 12, -1.5), "Wing1L")
    d.bone_pair("Wing3", (-15.5, 12, -2.2), "Wing2L")
    d.bone_pair("Thigh", (-1.6, 9.5, 4), "Hips")
    d.bone_pair("Shin", (-1.9, 6.2, 2.6), "ThighL")
    d.bone_pair("Foot", (-1.9, 2.6, 4.6), "ShinL")
    d.bone("Tail1", (0, 10.6, 6), "Hips")
    d.bone("Tail2", (0, 10.8, 8.4), "Tail1")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 10.6, 3.2), (2.6, 2.5, 3.0), BODY, where=left)
    d.ellipsoid("Chest", (0, 11.2, -1.0), (3.0, 3.0, 3.6), BODY, where=left)
    d.limb("Neck1", (0, 12.8, -3.6), (0, 15.4, -5.6), 1.9, 1.6, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne, long bec, crête vers l'arrière
    d.ellipsoid("Head", (0, 16.4, -7.2), (2.2, 2.3, 2.6), BODY, where=left)
    d.limb("Head", (0, 16.0, -9.2), (0, 15.0, -18.6), 1.6, 0.35, BEAK, where=lambda x, y, z: x <= 0 and y >= 15)
    d.limb("Head", (0, 17.8, -7.0), (0, 20.6, 2.4), 1.5, 0.4, CREST, where=left)
    d.limb("Jaw", (0, 14.6, -9.0), (0, 14.0, -17.6), 1.1, 0.3, BEAK, where=lambda x, y, z: x <= 0 and y <= 14)
    for z in range(-18, -15):
        for bone, y in (("Head", 15), ("Jaw", 14)):
            if (0, y, z) in d.vox:
                d.set(bone, 0, y, z, BEAK_TIP)
    for z in range(-14, -9):
        if (0, 15, z) in d.vox:
            d.set("Head", 0, 15, z, MOUTH)
    # ---------------------------------------------------------------- ailes (gauche)
    # membrane d'abord : plaque horizontale derrière le bras, partagée entre les trois os de l'aile selon x
    edge = [(-2.2, -1.0), (-7, -1.0), (-15.5, -1.7), (-31, 1.8), (-24, 4.2), (-16, 6.6), (-9, 8.2), (-3, 7.6), (-2, 6)]
    d.plate("Wing1L", 1, 12, edge, WING)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col == WING:
            if x <= -16:
                d.set("Wing3L", x, y, z, WING)
            elif x <= -8:
                d.set("Wing2L", x, y, z, WING)
    # bord de fuite plus foncé et deux nervures
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if col == WING and bone.startswith("Wing"):
            if (x, y, z + 1) not in d.vox:
                d.set(bone, x, y, z, WING_DARK)
            elif x in (-12, -22) and z > 0:
                d.set(bone, x, y, z, WING_DARK)
    # puis les os : bras, avant-bras, doigt-aile (bord d'attaque)
    d.limb("Wing1L", (-2.6, 12, -1.5), (-7, 12, -1.5), 1.15, 0.9, BONE)
    d.limb("Wing2L", (-7, 12, -1.5), (-15.5, 12, -2.2), 0.8, 0.6, BONE)
    d.limb("Wing3L", (-15.5, 12, -2.2), (-31, 12, 1.5), 0.6, 0.3, BONE)
    # petites griffes de la main (au poignet, vers l'avant) : elles touchent le sol quand il marche
    d.box("Wing2L", (-16, 11, -4), (-15, 11, -3), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-15.5, 11, -3.6))
    d.point("WingTipL", "Wing3L", (-31, 12, 1.5))
    # ---------------------------------------------------------------- pattes arrière
    d.limb("ThighL", (-1.6, 9.5, 4), (-1.9, 6.2, 2.6), 1.4, 1.0, BODY)
    d.limb("ShinL", (-1.9, 6.2, 2.6), (-1.9, 2.6, 4.6), 0.95, 0.75, BODY)
    d.limb("FootL", (-1.9, 2.6, 4.6), (-1.9, 0.6, 2.8), 0.75, 0.7, BACK)
    d.box("FootL", (-3, 0, 1), (-1, 0, 3), BACK)
    for x in (-3, -1):
        d.set("FootL", x, 0, 0, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-2, 0, 1.2))
    # ---------------------------------------------------------------- queue courte
    d.limb("Tail1", (0, 10.6, 6), (0, 10.8, 8.4), 0.9, 0.55, BODY, where=left)
    d.limb("Tail2", (0, 10.8, 8.4), (0, 11.0, 10.4), 0.55, 0.3, BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 16, -9, IRIS, PUPIL, lid_color=BACK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    d.paint(lambda x, y, z, bone, c: BACK if c == BODY and bone in ("Hips", "Chest", "Neck1", "Tail1", "Head") and
            y >= {"Hips": 12, "Chest": 13, "Neck1": 99, "Tail1": 11, "Head": 17}[bone] else None)
    return d
