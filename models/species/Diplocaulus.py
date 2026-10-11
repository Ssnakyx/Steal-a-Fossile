"""Diplocaulus : amphibien du Swamp, plat et mignon, à tête en boomerang.

Voxels de 0,14 stud : environ 6 studs de long, 4,4 de large (tête) et 1,5 de haut à la taille Normal, plus petit que
l'avatar. Grosse tête plate en boomerang (deux cornes larges qui partent sur les côtés puis vers l'arrière, bouts un peu
relevés), yeux ronds en relief sur le dessus, large sourire ; corps aplati de salamandre sur pattes courtes écartées,
queue plate de triton (haute et fine) avec une petite crête. Olive vaseux moucheté de jaune-vert, ventre pâle."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, hash3  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.14

BODY = (96, 98, 50)
DARK = (64, 68, 36)
SPOT = (196, 222, 70)
BELLY = (232, 224, 168)
TOE = (204, 196, 140)
PUPIL = (24, 22, 20)
IRIS = (250, 214, 74)
MOUTH = (200, 104, 110)
TONGUE = (226, 132, 136)
SMILE = (54, 50, 34)

PERSONALITY = {
    "tempo": 1.05,          # petit trottinement de salamandre
    "weight": 0.85,
    "stride": 1.0,
    "bob": 0.6,
    "headBob": 0.0,
    "tail": 1.4,            # queue de triton qui ondule beaucoup
    "diet": "fish",
    "happy": "stomp",
    "catch": "ram",
    "sleepDrop": 0.42,
}

# tête en boomerang, vue de dessus (côté gauche, (x, z)) : bord avant bombé, cornes qui filent vers l'arrière
HEAD_POLY = [(0.0, -21.6), (-3.5, -21.2), (-7.0, -19.9), (-10.0, -17.7), (-12.6, -14.7), (-14.4, -11.1), (-15.4, -7.5),
             (-15.7, -3.6), (-14.9, -3.4), (-13.9, -4.8), (-12.4, -6.6), (-10.6, -8.4), (-8.6, -9.8), (-6.6, -10.6),
             (-4.6, -10.8), (-2.5, -10.7), (0.0, -10.6)]


def inside(poly, a, b):
    n, j, ok = len(poly), len(poly) - 1, False
    for i in range(n):
        ai, bi = poly[i]
        aj, bj = poly[j]
        if (bi > b) != (bj > b) and a < (aj - ai) * (b - bi) / (bj - bi + 1e-12) + ai:
            ok = not ok
        j = i
    return ok


def build():
    d = Dino("Diplocaulus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 6, 4))
    d.bone("Chest", (0, 6, -2), "Hips")
    d.bone("Neck1", (0, 6.5, -9.5), "Chest")
    d.bone("Head", (0, 7, -12), "Neck1", rest=(6, 0, 0))
    d.bone("Jaw", (0, 6.5, -14), "Head")
    d.bone_pair("Lid", (-6, 11, -19), "Head")
    d.bone_pair("Arm", (-5.0, 6.0, -5.4), "Chest")
    d.bone_pair("Forearm", (-7.6, 4.2, -4.2), "ArmL")
    d.bone_pair("Hand", (-8.0, 1.6, -5.8), "ForearmL")
    d.bone_pair("Thigh", (-5.0, 6.0, 5.0), "Hips")
    d.bone_pair("Shin", (-7.6, 4.2, 3.6), "ThighL")
    d.bone_pair("Foot", (-8.0, 1.6, 5.2), "ShinL")
    tz = [10.0, 13.4, 16.6, 19.6, 22.4]
    ty = [6.4, 6.6, 6.8, 7.0, 7.2]
    tr = [3.2, 2.6, 2.0, 1.4, 0.7]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps plat de salamandre
    d.ellipsoid("Hips", (0, 6.0, 4.0), (5.2, 2.9, 6.6), BODY, where=left, power=2.6)
    d.ellipsoid("Chest", (0, 6.0, -4.2), (5.4, 2.9, 5.8), BODY, where=left, power=2.6)
    d.ellipsoid("Neck1", (0, 6.6, -10.2), (5.4, 2.8, 2.4), BODY, where=left, power=2.6)
    # ---------------------------------------------------------------- tête en boomerang (plaque bombée au milieu)
    for x in range(-16, 1):
        for z in range(-22, -2):
            if not inside(HEAD_POLY, min(x, -0.01), z):
                continue
            k = min(1.0, abs(x) / 15.7)
            bot = 5 + int(2.6 * k * k + 0.5)
            top = bot + max(2, int(4.0 - 2.0 * k + 0.5)) - 1
            if abs(x) <= 6 and -20 <= z <= -12:
                top = 9
            if abs(x) <= 3 and -19 <= z <= -13:
                top = 10
            for y in range(bot, top + 1):
                bone = "Jaw" if (y <= 6 and abs(x) <= 9 and z <= -15) else "Head"
                d.set(bone, x, y, z, BODY)
    # yeux ronds en relief sur le dessus, un peu écartés (bosses de grenouille)
    d.box("Head", (-6, 10, -20), (-5, 11, -19), BODY)
    # ---------------------------------------------------------------- pattes courtes et écartées
    d.limb("ArmL", (-4.6, 6.0, -5.4), (-7.6, 4.2, -4.2), 1.7, 1.4, BODY)
    d.limb("ForearmL", (-7.6, 4.2, -4.2), (-8.0, 1.6, -5.8), 1.3, 1.1, BODY)
    d.box("HandL", (-9, 0, -8), (-7, 0, -6), BODY)
    d.set("HandL", -8, 1, -6, BODY)
    for x in (-10, -8):
        d.set("HandL", x, 0, -9, TOE)
    d.set("HandL", -10, 0, -7, TOE)
    d.limb("ThighL", (-4.6, 6.0, 5.0), (-7.6, 4.2, 3.6), 1.9, 1.5, BODY)
    d.limb("ShinL", (-7.6, 4.2, 3.6), (-8.0, 1.6, 5.2), 1.4, 1.1, BODY)
    d.box("FootL", (-9, 0, 2), (-7, 0, 5), BODY)
    d.set("FootL", -8, 1, 5, BODY)
    for x in (-10, -8):
        d.set("FootL", x, 0, 1, TOE)
    d.set("FootL", -10, 0, 3, TOE)
    d.point("ToeL", "FootL", (-8, 0, 2))
    d.point("FrontToeL", "HandL", (-8, 0, -7.5))
    # ---------------------------------------------------------------- queue plate de triton (haute et fine)
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left,
               flat=1.9)
    # ---------------------------------------------------------------- yeux : 2 voxels de large, paupière de 2 aussi
    d.eye("Head", "LidL", 10, -20, IRIS, PUPIL, lid_color=BODY, h=1, w=2)
    d.set("Head", -5, 10, -20, IRIS, "Smooth")
    d.set("Head", -5, 10, -19, IRIS, "Smooth")
    d.set("LidL", -5, 11, -20, BODY)
    d.set("LidL", -5, 11, -19, BODY)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- bouche : creux intérieur (palais et langue roses
    # vus quand la gueule s'ouvre), grand sourire sombre sur le bord avant
    jaw = {k for k, v in d.vox.items() if v[0] == "Jaw"}
    for (x, y, z) in list(jaw):
        if y != 6 or abs(x) > 5:
            continue
        ring = all((x + dx, 6, z + dz) in jaw for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        if ring and (x, 8, z) in d.vox:
            d.clear(x, 6, z)
            d.set("Jaw", x, 5, z, TONGUE)
            d.set("Head", x, 7, z, MOUTH)
    for x in range(-9, 10):
        zs = [z for z in range(-23, -12) if (x, 6, z) in d.vox]
        if zs:
            d.set("Jaw", x, 6, min(zs), SMILE, "Smooth")
    # ---------------------------------------------------------------- peinture : ventre pâle, mouchetures jaune-vert
    belly = {"Hips": 4, "Chest": 4, "Neck1": 5, "Tail1": 5, "Tail2": 5, "Tail3": 6}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in ("Head", "Jaw") and (x, y - 1, z) not in d.vox
            and (x, y + 1, z) in d.vox else None)

    # liseré jaune-vert sur le bord avant du boomerang (dessus) : la forme se lit de loin
    cols = {(x, z) for (x, y, z), v in d.vox.items() if v[0] in ("Head", "Jaw")}

    def rim(x, y, z, bone, c):
        if bone != "Head" or c != BODY or (x, y + 1, z) in d.vox or x == 0:
            return None
        out = x + (1 if x > 0 else -1)
        front = (x, z - 1) not in cols or (out, z) not in cols or (out, z - 1) not in cols
        back = (x, z + 1) not in cols and (x, z - 1) in cols and (out, z) in cols
        return SPOT if front and not back and z <= -6 and abs(x) >= 2 else None
    d.paint(rim)

    def speckle(x, y, z, bone, c):
        if c != BODY or (x, y + 1, z) in d.vox:
            return None
        if bone in ("Head", "Neck1", "Chest", "Hips", "Tail1", "Tail2", "Tail3", "ThighL", "ThighR", "ArmL", "ArmR"):
            if (x + 2 * z) % 4 == 0 and hash3(abs(x), y, z, 7) > 0.45:
                return SPOT
        return None
    d.paint(speckle)
    # petite crête de triton sur la queue (plaque d'un voxel au milieu)
    segs = [(9, 13, "Tail1"), (13, 17, "Tail2"), (17, 20, "Tail3"), (20, 99, "Tail4")]
    for z in range(9, 24):
        top = d.surface_y(0, z)
        if top is None:
            continue
        bone = next(b for a, c, b in segs if a <= z < c)
        d.set(bone, 0, top + 1, z, DARK)
    return d
