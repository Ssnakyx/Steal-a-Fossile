"""Woolly Mammoth : mammouth laineux du Glacier, énorme et paisible (fossile de l'ère glaciaire).

Voxels de 0,52 stud (gros voxels : le mammouth reste sous 450 pièces) : environ 17 studs de long (défenses comprises)
et 11 de haut à la taille Normal. Grosse bosse de tête haute, creux de la nuque puis bosse des épaules, dos qui
descend vers la croupe ; fourrure brun-roux, plus sombre en bas, qui pend en mèches aux bords irréguliers (jupe de
poils sous le ventre et les flancs), petites oreilles, grandes défenses ivoire recourbées, trompe brun foncé
épaisse et effilée qui descend puis s'enroule vers l'avant entre les défenses (portée par l'os Frill : elle se
balance), pattes en piliers aux ongles ivoire, queue courte à touffe."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.52
K = 0.76                    # le modèle est dessiné à l'échelle 1, posé sur une grille plus grossière

FUR = (164, 92, 48)
LIGHT = (198, 126, 66)
DARK = (106, 60, 36)
SKIN = (80, 64, 58)
IVORY = (246, 236, 210)
NAIL = (232, 220, 196)
PUPIL = (26, 20, 18)
IRIS = (120, 72, 40)
MOUTH = (176, 84, 88)

PERSONALITY = {
    "tempo": 0.8,           # lourd et tranquille
    "weight": 1.5,
    "stride": 1.0,
    "bob": 0.8,
    "headBob": 0.0,
    "tail": 0.7,
    "diet": "plants",
    "happy": "stomp",       # se cabre et tape des pattes avant
    "catch": "toss",        # charge et relève les défenses
    "sleepDrop": 0.3,      # couché moins bas : la jupe de poils et la trompe restent au-dessus du sol
}


def s(p):
    return tuple(v * K for v in p)


def build():
    d = Dino("WoollyMammoth", FAMILY, voxel=VOXEL, display="Woolly Mammoth")

    def ell(bone, c, r, col, mat="Plastic", where=None, power=2.0):
        d.ellipsoid(bone, s(c), s(r), col, mat, where=where, power=power)

    def lmb(bone, a, b, ra, rb, col, mat="Plastic", where=None):
        d.limb(bone, s(a), s(b), ra * K, rb * K, col, mat, where=where)

    # ---------------------------------------------------------------- os
    d.bone("Hips", s((0, 15, 5)))
    d.bone("Chest", s((0, 15, -1)), "Hips")
    d.bone("Neck1", s((0, 19, -7.5)), "Chest")
    d.bone("Head", s((0, 21, -9.5)), "Neck1")
    d.bone("Jaw", s((0, 16.0, -12.0)), "Head")
    d.bone("Frill", s((0, 19.0, -13.8)), "Head")          # trompe
    d.bone_pair("Lid", s((-4.0, 24, -13)), "Head")
    d.bone_pair("Arm", s((-4.4, 14.5, -4.5)), "Chest")
    d.bone_pair("Forearm", s((-4.6, 8.6, -1.4)), "ArmL")
    d.bone_pair("Hand", s((-4.6, 3.0, -4.8)), "ForearmL")
    d.bone_pair("Thigh", s((-4.2, 14.5, 6.5)), "Hips")
    d.bone_pair("Shin", s((-4.6, 8.6, 3.6)), "ThighL")
    d.bone_pair("Foot", s((-4.6, 3.0, 6.6)), "ShinL")
    tz = [11.0, 12.6, 13.8, 14.8, 15.6]
    ty = [19.0, 17.2, 15.4, 13.6, 12.0]
    tr = [1.8, 1.5, 1.25, 1.0, 0.8]
    for i in range(4):
        d.bone(f"Tail{i + 1}", s((0, ty[i], tz[i])), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : bosse des épaules, croupe plus basse
    ell("Chest", (0, 17.0, -2.0), (8.0, 8.0, 7.4), FUR, where=left, power=2.6)
    ell("Hips", (0, 15.6, 6.0), (7.4, 6.8, 6.0), FUR, where=left, power=2.6)
    lmb("Neck1", (0, 19.0, -7.0), (0, 21.0, -10.0), 4.6, 4.4, FUR, where=left)
    # ---------------------------------------------------------------- tête : haute bosse, front plat
    ell("Head", (0, 23.0, -11.0), (4.6, 5.8, 4.2), FUR, where=left, power=2.5)
    ell("Head", (0, 19.0, -12.6), (3.6, 2.8, 2.6), FUR, where=left, power=2.4)   # joues sous les yeux
    ell("Jaw", (0, 15.6, -12.8), (2.0, 1.4, 1.8), FUR, where=lambda x, y, z: x <= 0 and y <= round(16 * K), power=2.4)
    # ---------------------------------------------------------------- trompe épaisse et effilée (os Frill)
    # brun foncé : elle se détache du visage de face (entre les défenses) et de profil (derrière la défense)
    trunk = [(0, 19.4, -14.0), (0, 14.6, -15.6), (0, 10.6, -16.4), (0, 8.4, -18.0), (0, 9.2, -20.0), (0, 11.4, -20.8)]
    tw = [2.8, 2.4, 2.0, 1.7, 1.3, 0.9]
    for i in range(5):
        lmb("Frill", trunk[i], trunk[i + 1], tw[i], tw[i + 1], DARK, where=left)
    # ---------------------------------------------------------------- défenses ivoire recourbées
    tusk = [(-2.6, 16.6, -13.4), (-3.6, 12.6, -15.6), (-5.0, 9.6, -18.4), (-5.8, 9.4, -21.4), (-5.0, 11.6, -23.8),
            (-3.0, 13.6, -24.6)]
    tkr = [1.25, 1.1, 1.0, 0.85, 0.7, 0.5]
    for i in range(5):
        lmb("Head", tusk[i], tusk[i + 1], tkr[i], tkr[i + 1], IVORY, "Smooth")
    # ---------------------------------------------------------------- pattes en piliers, pieds ronds
    lmb("ArmL", (-4.4, 14.5, -4.5), (-4.6, 8.6, -1.4), 3.0, 2.7, FUR)
    lmb("ForearmL", (-4.6, 8.6, -1.4), (-4.6, 3.0, -4.8), 2.7, 2.4, FUR)
    lmb("HandL", (-4.6, 3.0, -4.8), (-4.6, 1.0, -5.2), 2.4, 2.4, FUR)
    ell("HandL", (-4.6, 1.0, -5.2), (2.7, 1.4, 2.7), SKIN, power=2.6)
    d.point("FrontToeL", "HandL", s((-4.6, 0, -7.5)))
    ell("ThighL", (-4.4, 11.5, 5.4), (2.9, 4.0, 3.4), FUR)
    lmb("ShinL", (-4.6, 8.6, 3.6), (-4.6, 3.0, 6.6), 2.6, 2.3, FUR)
    lmb("FootL", (-4.6, 3.0, 6.6), (-4.6, 1.0, 6.2), 2.3, 2.3, FUR)
    ell("FootL", (-4.6, 1.0, 5.8), (2.6, 1.4, 2.6), SKIN, power=2.6)
    d.point("ToeL", "FootL", s((-4.6, 0, 3.5)))
    # ---------------------------------------------------------------- queue courte à touffe
    for i in range(4):
        lmb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], FUR, where=left)
    ell("Tail4", (0, 11.0, 15.8), (1.3, 1.9, 1.3), DARK, where=left)
    d.remove(lambda x, y, z: y < 0)
    # ongles ivoire devant les pieds
    for bone in ("HandL", "FootL"):
        zf = min(z for (x, y, z), v in d.vox.items() if v[0] == bone and y == 0)
        for (x, y, z), v in list(d.vox.items()):
            if v[0] == bone and y == 0 and z == zf and x % 2 == 0:
                d.set(bone, x, y, z, NAIL, "Smooth")
    # petites oreilles rondes sur les côtés (bord foncé)
    ex = d.surface_x(17, -7, "Head")
    d.plate("Head", 0, ex - 1, [(15.6, -7.4), (16.4, -8.6), (18.6, -8.6), (19.4, -7.4), (18.6, -5.6), (16.4, -5.6)], DARK)
    # ---------------------------------------------------------------- yeux, symétrie
    d.eye("Head", "LidL", round(22 * K), round(-14 * K), IRIS, PUPIL, h=2, w=2)
    # ---------------------------------------------------------------- fourrure en mèches : jupe de poils
    # les flancs tombent droit depuis leur partie la plus large jusqu'à un ourlet de mèches irrégulières (touffes de
    # deux voxels) ; les pattes bougent dans la jupe (cases déjà prises par les pattes laissées aux pattes)
    wide = {"Chest": round(17.0 * K), "Hips": round(15.6 * K)}
    sect = {}
    for (x, y, z), (b, c, m) in d.vox.items():
        if b in wide and y == wide[b] and x <= 0:
            sect[(x, z)] = b
    locks = (0, 2, 1, 3, 1, 2, 0, 3, 1, 2)
    for (x, z), b in sect.items():
        edge = any((x + dx, z + dz) not in sect for dx, dz in ((-1, 0), (0, -1), (0, 1), (-2, 0), (0, -2), (0, 2)))
        if not edge:
            continue
        side = (x - 1, z) not in sect
        ends = (x, z - 1) not in sect or (x, z + 1) not in sect
        # mèches de deux voxels séparées par un sillon : texture de poils sur les flancs, l'avant et l'arrière
        groove = (side and z % 3 == 0) or (ends and not side and x % 3 == 0)
        hem = 7 - locks[((z + 40) // 3) % len(locks)] + (1 if groove else 0)
        for y in range(wide[b] - 1, hem - 1, -1):
            if (x, y, z) not in d.vox and not (groove and y < wide[b] - 1):
                d.set(b, x, y, z, FUR)
    d.mirror()
    # bas du corps plus sombre, coupé à plat
    legs = ("ArmL", "ArmR", "ForearmL", "ForearmR", "HandL", "HandR", "ThighL", "ThighR", "ShinL", "ShinR", "FootL",
            "FootR")
    d.paint(lambda x, y, z, bone, c: DARK if c == FUR and bone in legs and y <= 7 else None)
    # dos et haut du crâne plus clairs (coupés à plat)
    top = {"Chest": 18, "Hips": 16, "Neck1": 18, "Head": 21}
    d.paint(lambda x, y, z, bone, c: LIGHT if c == FUR and bone in top and y >= top[bone] else None)
    return d
