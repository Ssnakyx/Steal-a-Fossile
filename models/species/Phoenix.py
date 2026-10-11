"""Phoenix : volant mythique du Volcano, oiseau de feu majestueux, fier et rayonnant.

Modélisé ailes déployées (plaques horizontales), voxels de 0,381 stud : environ 24 studs d'envergure à la taille
Normal. Grandes ailes de plumes en dégradé rouge > orange > jaune, bord de fuite en plumes dentelées aux bouts
incandescents (Neon), rémiges écartées comme des doigts au bout des ailes ; longues plumes de queue en flammes (Neon
orange et jaune) ; crête de trois plumes-flammes (Neon) ; bec doré crochu (Metal) ; corps cramoisi à poitrail de braise.
Au parc il se tient replié sur ses pattes et ses poignets (les animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.381

CRIMSON = (176, 20, 44)
BREAST = (255, 128, 36)
RED = (226, 36, 34)
ORANGE = (255, 122, 20)
YELLOW = (255, 204, 40)
TIP_RED = (255, 84, 30)
TIP_ORANGE = (255, 156, 34)
TIP_YELLOW = (255, 232, 96)
FLAME = (255, 112, 26)
FLAME_TIP = (255, 214, 60)
GOLD = (236, 178, 46)
CLAW = (60, 30, 30)
PUPIL = (40, 12, 8)
IRIS = (255, 214, 60)

PERSONALITY = {
    "tempo": 1.0,
    "weight": 0.9,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.5,         # port de tête d'oiseau
    "tail": 0.9,            # longues plumes de queue qui ondulent
    "diet": "meat",
    "happy": "flap",
    "catch": "peck",        # coup de bec plongé
}

Y_W = 12                    # plan des ailes (y)


def build():
    d = Dino("Phoenix", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 10, 3.5))
    d.bone("Chest", (0, 11, -0.5), "Hips")
    d.bone("Neck1", (0, 14.0, -3.8), "Chest")
    d.bone("Head", (0, 17.5, -6.0), "Neck1")
    d.bone("Jaw", (0, 16.6, -9.4), "Head")
    d.bone("Crest", (0, 20.5, -7.0), "Head")
    d.bone_pair("Lid", (-2.2, 20, -9), "Head")
    WZ = float(os.environ.get("PH_WZ", "0"))
    HZ = float(os.environ.get("PH_HZ", "7"))
    d.bone_pair("Wing1", (-3.0, 12.5, -1.0 + WZ), "Chest")
    d.bone_pair("Wing2", (-9.0, 12.5, -1.0 + WZ), "Wing1L")
    d.bone_pair("Wing3", (-18.0, 12.5, -1.5 + WZ), "Wing2L")
    d.bone_pair("Thigh", (-2.0, 9.5, 3.5), "Hips")
    d.bone_pair("Shin", (-2.2, 6.2, 1.4), "ThighL")
    d.bone_pair("Foot", (-2.2, 2.6, 3.4), "ShinL")
    tz = [7.0, 11.5, 16.0, 20.5]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, 11.0, tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : poitrail bombé, dos cramoisi
    d.ellipsoid("Chest", (0, 11.5, -1.0), (3.8, 4.0, 4.6), CRIMSON, where=lambda x, y, z: x <= 0 and z <= 2)
    d.ellipsoid("Hips", (0, 11.0, 4.0), (3.2, 3.2, 3.6), CRIMSON, where=lambda x, y, z: x <= 0 and z >= 3)
    d.limb("Neck1", (0, 13.5, -3.5), (0, 17.0, -6.0), 2.2, 1.9, CRIMSON, where=lambda x, y, z: x <= 0 and z <= -4)
    # ---------------------------------------------------------------- tête d'aigle, bec doré crochu
    d.ellipsoid("Head", (0, 18.5, -7.5), (2.6, 2.6, 3.0), CRIMSON, where=left)
    d.limb("Head", (0, 18.0, -9.8), (0, 17.2, -13.4), 1.4, 0.6, GOLD, "Metal", where=lambda x, y, z: x <= 0 and y >= 17)
    d.limb("Head", (0, 17.2, -13.4), (0, 16.2, -13.8), 0.6, 0.4, GOLD, "Metal", where=left)
    d.limb("Jaw", (0, 16.6, -9.6), (0, 16.4, -12.4), 1.0, 0.5, GOLD, "Metal", where=lambda x, y, z: x <= 0 and y <= 16)
    d.eye("Head", "LidL", 19, -9, IRIS, PUPIL, lid_color=CRIMSON, h=1, w=2)
    # ---------------------------------------------------------------- crête de trois plumes-flammes
    for base, tip, rb in (((0, 20.5, -8.5), (0, 28.0, -6.0), 1.5), ((0, 21.0, -6.5), (0, 27.0, -2.0), 1.4),
                          ((0, 20.5, -4.5), (0, 24.5, 0.5), 1.2)):
        mid = tuple(base[i] + (tip[i] - base[i]) * 0.45 for i in range(3))
        d.limb("Crest", base, mid, rb, rb * 0.75, FLAME, "Neon", flat=4)
        d.limb("Crest", mid, tip, rb * 0.75, 0.3, FLAME_TIP, "Neon", flat=4)
    # ---------------------------------------------------------------- ailes (gauche) : plumes posées une à une
    # couvertures (bande avant) : plaque d'un voxel, de l'épaule au bout de l'aile
    cov = [(-2.5, -1.5), (-9, -1.5), (-18, -2.0), (-26, -0.5), (-31, 1.5), (-31, 3.5), (-26, 4.5), (-18, 5.0),
           (-9, 5.0), (-2.5, 5.0)]
    d.plate("Wing1L", 1, Y_W, cov, CRIMSON)
    # rémiges secondaires (vers l'arrière) : plumes de 2 voxels, une longue une courte (bord dentelé en arc)
    for x, z1 in zip(range(-4, -18, -2), (13, 15, 13, 12, 10, 11, 9)):
        d.box("Wing1L", (x - 1, Y_W, 5), (x, Y_W, z1), RED)
    # main et rémiges primaires écartées comme des doigts au bout de l'aile
    d.box("Wing1L", (-21, Y_W, 4), (-18, Y_W, 13), RED)
    for z, x1 in ((4, -31), (7, -30), (10, -28), (13, -25)):
        d.box("Wing1L", (x1, Y_W, z), (-18, Y_W, z + 1), RED)
    # dégradé rouge > orange > jaune vers le bout de l'aile ; couvertures d'un cran plus foncées que les rémiges
    shift = {CRIMSON: RED, RED: ORANGE}
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col in (CRIMSON, RED):
            if x <= -18:
                d.set("Wing3L", x, y, z, ORANGE if col == CRIMSON else YELLOW)
            elif x <= -9:
                d.set("Wing2L", x, y, z, shift[col])
    # bouts des plumes incandescents (dernier voxel de chaque plume, vers l'arrière ou vers l'extérieur)
    tips = {"Wing1L": TIP_RED, "Wing2L": TIP_ORANGE, "Wing3L": TIP_YELLOW}
    feather = {k: v for k, v in d.vox.items() if v[0].startswith("Wing") and k[1] == Y_W}
    for (x, y, z), (bone, col, mat) in feather.items():
        outward = x <= -18 and z >= 4 and (x - 1, y, z) not in feather
        backward = x > -18 and (x, y, z + 1) not in feather and z >= 5
        if outward or backward:
            d.set(bone, x, y, z, tips[bone], "Neon")
    # les rémiges du bras suivent l'avant-bras : ailes repliées, elles se couchent le long du flanc vers l'arrière
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and z >= int(os.environ.get("PH_RZ", "6")):
            d.set("Wing2L", x, y, z, col, mat)
    # bord d'attaque : bras, avant-bras, main (plumes de couverture)
    d.limb("Wing1L", (-3.0, 12.5, -1.0), (-9.0, 12.5, -1.0), 1.2, 1.0, CRIMSON)
    d.limb("Wing2L", (-9.0, 12.5, -1.0), (-18.0, 12.5, -1.5), 1.0, 0.8, RED)
    d.limb("Wing3L", (-18.0, 12.5, -1.5), (-31.0, 12.5, 2.0), 0.7, 0.4, ORANGE)
    d.point("HandL", "Wing2L", (-18.0, 11.5, HZ))         # poignet (au sol quand il marche ailes repliées)
    d.point("WingTipL", "Wing3L", (-31.0, 12.5, 2.0 + WZ))
    # ---------------------------------------------------------------- pattes : cuisses emplumées, tarses dorés
    d.limb("ThighL", (-2.0, 9.5, 3.5), (-2.2, 6.2, 1.4), 1.5, 1.1, CRIMSON)
    d.limb("ShinL", (-2.2, 6.2, 1.4), (-2.2, 2.6, 3.4), 0.7, 0.6, GOLD, "Metal")
    d.limb("FootL", (-2.2, 2.6, 3.4), (-2.2, 0.6, 2.2), 0.6, 0.6, GOLD, "Metal")
    d.box("FootL", (-3, 0, 0), (-1, 0, 2), GOLD, "Metal")
    for x in (-3, -1):
        d.set("FootL", x, 0, -1, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-2.0, 0, 0.6))
    # ---------------------------------------------------------------- queue : éventail de langues de feu
    d.limb("Tail1", (0, 11.0, 7.0), (0, 11.0, 11.0), 1.6, 1.0, CRIMSON, where=left)
    d.box("Tail1", (-3, 11, 8), (0, 11, 11), ORANGE)
    # grande plume de flamme au centre (plaque verticale qui ondule), langues de feu de chaque côté (éventail)
    d.plate("Tail2", 0, 0, [(10.5, 11.5), (12.5, 11.5), (14.0, 15.5), (10.0, 15.5)], FLAME, "Neon")
    d.plate("Tail3", 0, 0, [(10.0, 15.5), (14.0, 15.5), (15.0, 20.5), (9.5, 20.5)], FLAME, "Neon")
    d.plate("Tail4", 0, 0, [(9.5, 20.5), (15.0, 20.5), (14.5, 25.0), (12.5, 30.0), (12.0, 35.0), (11.0, 35.0),
                            (10.5, 30.0), (10.0, 25.0)], FLAME_TIP, "Neon")
    for bone, x0, x1, z0, z1, col in (
            ("Tail2", -3, -1, 12, 15, FLAME), ("Tail3", -5, -2, 16, 20, FLAME), ("Tail4", -6, -3, 21, 23, FLAME),
            ("Tail4", -6, -4, 24, 26, FLAME_TIP), ("Tail4", -6, -5, 27, 28, FLAME_TIP), ("Tail4", -6, -6, 29, 29, FLAME_TIP),
            ("Tail2", -5, -4, 12, 14, FLAME), ("Tail3", -8, -6, 15, 17, FLAME), ("Tail3", -9, -8, 18, 19, FLAME_TIP),
            ("Tail3", -9, -9, 20, 20, FLAME_TIP)):
        d.box(bone, (x0, 11, z0), (x1, 11, z1), col, "Neon")
    # ---------------------------------------------------------------- symétrie, poitrail de braise
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    d.paint(lambda x, y, z, bone, c: BREAST if c == CRIMSON and bone in ("Chest", "Neck1") and y <= 10 else None)
    return d
