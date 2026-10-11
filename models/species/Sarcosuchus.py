"""Sarcosuchus : crocodile géant du Swamp, lent et lourd.

Voxels de 0,333 stud : environ 16 studs de long et 4 de haut à la taille Normal.
Il marche « haut » sur ses pattes (comme les crocodiles hors de l'eau) et tient sa tête un peu relevée (rotation de
repos de l'os Head) : quand la famille baisse la tête (manger, renifler, dormir), le long museau reste près du sol au
lieu de s'y enfoncer. Museau plat (bout un peu élargi, pas de boule), yeux en relief sur le crâne, rangées d'écailles
sur le dos qui se rejoignent en une crête sur la queue."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.333

BODY = (112, 132, 70)
DARK = (70, 86, 46)
BELLY = (230, 216, 150)
TOOTH = (250, 248, 238)
NAIL = (228, 220, 196)
PUPIL = (26, 22, 20)
IRIS = (240, 200, 60)
MOUTH = (190, 96, 96)

PERSONALITY = {
    "tempo": 0.8,           # lent, lourd
    "weight": 1.3,
    "stride": 0.9,
    "bob": 0.6,
    "headBob": 0.0,
    "tail": 1.3,            # grosse queue qui ondule
    "diet": "fish",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.42,      # couché, le ventre touche le sol
}


def build():
    d = Dino("Sarcosuchus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 7.6, 5))
    d.bone("Chest", (0, 7.4, -0.5), "Hips")
    d.bone("Neck1", (0, 7.6, -6), "Chest")
    d.bone("Head", (0, 7.8, -8.4), "Neck1", rest=(12, 0, 0))
    d.bone("Jaw", (0, 6.8, -9.6), "Head")
    d.bone_pair("Lid", (-2, 11, -11.5), "Head")
    d.bone_pair("Arm", (-4.2, 6.6, -2.8), "Chest")
    d.bone_pair("Forearm", (-5.0, 3.8, -1.4), "ArmL")
    d.bone_pair("Hand", (-5.0, 1.2, -3.0), "ForearmL")
    d.bone_pair("Thigh", (-4.4, 7.0, 6), "Hips")
    d.bone_pair("Shin", (-5.2, 3.8, 4.4), "ThighL")
    d.bone_pair("Foot", (-5.2, 1.2, 6.4), "ShinL")
    tz = [10.0, 14.0, 18.0, 21.6, 25.0, 28.2]
    ty = [7.6, 7.2, 6.6, 5.8, 5.0, 4.4]
    tr = [3.8, 3.1, 2.4, 1.8, 1.3, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps large et plat
    d.ellipsoid("Hips", (0, 7.4, 5.2), (4.4, 3.2, 5.6), BODY, where=left, power=2.6)
    d.ellipsoid("Chest", (0, 7.2, -1.6), (4.2, 3.0, 4.6), BODY, where=left, power=2.6)
    d.limb("Neck1", (0, 7.6, -5.4), (0, 7.8, -8.4), 3.0, 2.8, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne plat, long museau, mâchoire du bas
    d.ellipsoid("Head", (0, 8.3, -10.6), (2.8, 1.9, 2.4), BODY, where=left, power=2.8)
    d.ellipsoid("Head", (0, 7.6, -15.0), (1.7, 1.3, 4.0), BODY, where=lambda x, y, z: x <= 0 and y >= 7, power=2.6)
    d.ellipsoid("Head", (0, 7.6, -18.6), (2.0, 1.2, 1.0), BODY, where=lambda x, y, z: x <= 0 and y >= 7, power=2.6)
    d.ellipsoid("Jaw", (0, 5.9, -14.2), (1.6, 1.0, 5.0), BELLY, where=lambda x, y, z: x <= 0 and y <= 6, power=2.6)
    d.ellipsoid("Jaw", (0, 5.9, -10.4), (2.4, 1.0, 1.6), BODY, where=lambda x, y, z: x <= 0 and y <= 6, power=2.6)
    for z in range(-17, -9):
        if (0, 7, z) in d.vox:
            d.set("Head", 0, 7, z, MOUTH)
        if (0, 6, z) in d.vox:
            d.set("Jaw", 0, 6, z, MOUTH)
    # dents sur les bords (quelques-unes, dessin cartoon)
    for z in (-18, -15, -12):
        x = d.surface_x(7, z, "Head")
        if x is not None:
            d.set("Head", x, 6, z, TOOTH, "Smooth")
    # yeux en relief sur le crâne
    d.box("Head", (-2, 10, -12), (-1, 11, -11), BODY)
    # ---------------------------------------------------------------- pattes un peu écartées, corps relevé
    d.limb("ArmL", (-4.2, 6.6, -2.8), (-5.0, 3.8, -1.4), 1.4, 1.2, BODY)
    d.limb("ForearmL", (-5.0, 3.8, -1.4), (-5.0, 1.2, -3.0), 1.1, 1.0, BODY)
    d.limb("HandL", (-5.0, 1.2, -3.0), (-5.0, 0.6, -3.6), 1.0, 1.0, BODY)
    d.box("HandL", (-6, 0, -5), (-4, 0, -3), BODY)
    d.set("HandL", -6, 0, -6, NAIL, "Smooth")
    d.set("HandL", -4, 0, -6, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-4.8, 5.4, 5.6), (1.9, 2.6, 2.6), BODY)
    d.limb("ShinL", (-5.2, 3.8, 4.4), (-5.2, 1.2, 6.4), 1.3, 1.1, BODY)
    d.limb("FootL", (-5.2, 1.2, 6.4), (-5.2, 0.6, 5.6), 1.0, 1.0, BODY)
    d.box("FootL", (-7, 0, 3), (-4, 0, 6), BODY)
    d.box("FootL", (-6, 1, 5), (-4, 1, 6), BODY)
    for x in (-7, -5):
        d.set("FootL", x, 0, 2, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5.5, 0, 3))
    d.point("FrontToeL", "HandL", (-5, 0, -4.5))
    # ---------------------------------------------------------------- queue haute et plate (aplatie sur les côtés)
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left, flat=1.4)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 10, -12, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 5, "Chest": 5, "Neck1": 5, "Tail1": 5, "Tail2": 5, "Tail3": 5, "Tail4": 4}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    # dos plus foncé que les flancs
    d.back_stripes(["Hips", "Chest", "Neck1", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], shade(BODY, -0.22), frac=0.3,
                   period=1, width=1, only=[BODY])
    d.paint(lambda x, y, z, bone, c: shade(BODY, -0.22) if bone == "Head" and c == BODY and y >= 9 else None)
    # écailles du dos : deux rangées de bosses, puis une crête double sur la queue qui se rejoint au bout
    segs = [(-99, -4, "Neck1"), (-4, 2, "Chest"), (2, 9, "Hips"), (9, 14, "Tail1"), (14, 18, "Tail2"), (18, 22, "Tail3"),
            (22, 25, "Tail4"), (25, 99, "Tail5")]

    def seg(z):
        return next(b for a, c, b in segs if a <= z < c)
    for z in range(-7, 23, 2):
        xs = (-2, 2) if z < 14 else (-1, 1)
        for x in xs:
            top = d.surface_y(x, z)
            if top is not None:
                d.set(seg(z), x, top + 1, z, DARK)
    for z in range(23, 29, 2):
        top = d.surface_y(0, z)
        if top is not None:
            d.set(seg(z), 0, top + 1, z, DARK)
    return d
