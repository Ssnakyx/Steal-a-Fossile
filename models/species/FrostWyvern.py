"""Frost Wyvern : dragon des glaces légendaire (créature fantastique du Glacier), majestueux et glacial.

Modélisé ailes déployées (membranes en plaques horizontales), voxels de 0,4 stud : environ 22 studs d'envergure et
18 de long à la taille Normal. Écailles bleu glace pâle, gorge et ventre blancs, bande bleu profond qui suit le dos du
crâne au bout de la queue ; ailes de dragon aux membranes de glace translucide (matière Ice), givrées et plus pâles
vers le bout, tendues sur des doigts bleu foncé, bord de fuite festonné ; crête de grands éclats de glace (Ice et
Glass, alternés) le long du cou, du dos et de la queue ; deux paires de cornes balayées vers l'arrière ; yeux cyan
lumineux (Neon) sous des paupières bleu foncé ; longue queue finie par une lame de cristal (Glass). Au sol il marche
sur ses pattes et sur les poignets de ses ailes repliées, comme une vraie vouivre."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.4
K = 0.8875                  # dessiné sur une grille fine (0,355 stud), posé sur une grille plus grossière (0,4 stud)

SCALE = (156, 206, 240)
DEEP = (70, 116, 186)
BELLY = (236, 246, 255)
MEMB = (126, 200, 244)
FROST = (186, 230, 252)
ICE = (206, 242, 255)
GLASS = (150, 226, 255)
HORN = (238, 246, 255)
CLAW = (232, 244, 255)
EYE = (90, 246, 255)
MOUTH = (90, 70, 150)
TONGUE = (150, 120, 200)
TOOTH = (240, 248, 255)

PERSONALITY = {
    "tempo": 0.9,           # grand et majestueux
    "weight": 1.2,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.3,
    "tail": 0.9,
    "diet": "meat",
    "happy": "flap",
    "catch": "peck",        # coup de mâchoire plongé
}


def s(p):
    return tuple(v * K for v in p)


def n(v):
    return int(round(v * K))


def build():
    d = Dino("FrostWyvern", FAMILY, voxel=VOXEL, display="Frost Wyvern")

    def ell(bone, c, r, col, mat="Plastic", where=None, power=2.0):
        d.ellipsoid(bone, s(c), s(r), col, mat, where=where, power=power)

    def lmb(bone, a, b, ra, rb, col, mat="Plastic", where=None):
        d.limb(bone, s(a), s(b), ra * K, rb * K, col, mat, where=where)

    def crystal(bone, base, tip, r, color=ICE, mat="Ice"):
        """Éclat de glace : lame effilée translucide d'un voxel d'épaisseur (triangle couché vers l'arrière, vu de
        profil), de la peau vers la pointe (coordonnées de la grille)."""
        d.limb(bone, base, tip, r, 0.25, color, mat, flat=2.2)

    def band(segs, color, k, above=True):
        """Bande qui suit la courbe du cou ou de la queue : voxels d'écailles de chaque os au-dessus (dos) ou
        au-dessous (gorge) de son axe, à plus de k rayons (distance perpendiculaire, dans le plan du profil)."""
        for bone, (ay, az), (by, bz), r in segs:
            ay, az, by, bz, r = ay * K, az * K, by * K, bz * K, r * K
            m = math.hypot(by - ay, bz - az)
            ny, nz = -(bz - az) / m, (by - ay) / m
            if ny < 0:
                ny, nz = -ny, -nz

            def fn(x, y, z, b, c, bone=bone, ay=ay, az=az, ny=ny, nz=nz, r=r):
                if b != bone or c != SCALE:
                    return None
                t = (y - ay) * ny + (z - az) * nz
                return color if (t > k * r if above else t < -k * r) else None
            d.paint(fn)

    # ---------------------------------------------------------------- os
    WY = n(14)                  # plan des ailes déployées
    d.bone("Hips", s((0, 11, 4)))
    d.bone("Chest", s((0, 12, -0.5)), "Hips")
    d.bone("Neck1", s((0, 14.0, -4.6)), "Chest")
    d.bone("Neck2", s((0, 16.6, -7.6)), "Neck1")
    d.bone("Neck3", s((0, 19.4, -9.6)), "Neck2")
    d.bone("Head", s((0, 21.6, -11.2)), "Neck3")
    d.bone("Jaw", s((0, 21.4, -13.4)), "Head")
    d.bone_pair("Lid", s((-2.0, 24.4, -15)), "Head")
    d.bone_pair("Wing1", (-3.0 * K, WY, -2.6 * K), "Chest")
    d.bone_pair("Wing2", (-9.5 * K, WY, -2.8 * K), "Wing1L")
    d.bone_pair("Wing3", (-17.5 * K, WY, -3.4 * K), "Wing2L")
    d.bone_pair("Thigh", s((-2.4, 11.0, 5.0)), "Hips")
    d.bone_pair("Shin", s((-2.8, 6.6, 2.6)), "ThighL")
    d.bone_pair("Foot", s((-2.8, 2.6, 5.6)), "ShinL")
    tz = [7.6, 11.4, 15.2, 19.0, 22.6, 26.0]
    ty = [12.2, 12.6, 13.2, 13.8, 14.4, 14.8]
    tr = [2.4, 1.95, 1.5, 1.15, 0.85, 0.55]
    for i in range(5):
        d.bone(f"Tail{i + 1}", s((0, ty[i], tz[i])), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : poitrail puissant, bassin fin
    ell("Chest", (0, 12.6, -1.6), (4.0, 4.0, 4.6), SCALE, where=left, power=2.4)
    ell("Hips", (0, 12.0, 4.0), (3.3, 3.3, 3.7), SCALE, where=left, power=2.4)
    # ---------------------------------------------------------------- long cou en S (trois segments épais)
    neck = [("Neck1", (13.6, -4.2), (16.6, -7.6), 2.8, 2.4), ("Neck2", (16.6, -7.6), (19.4, -9.6), 2.4, 2.1),
            ("Neck3", (19.4, -9.6), (21.6, -11.2), 2.1, 2.0)]
    for bone, (ay, az), (by, bz), ra, rb in neck:
        lmb(bone, (0, ay, az), (0, by, bz), ra, rb, SCALE, where=left)
    # ---------------------------------------------------------------- tête de dragon : crâne, long museau, mâchoire
    m = n(22)                   # première rangée du crâne ; la mâchoire est juste dessous
    ell("Head", (0, 23.4, -13.6), (2.9, 2.8, 3.2), SCALE, where=lambda x, y, z: x <= 0 and y >= m, power=2.5)
    ell("Head", (0, 22.8, -18.0), (2.0, 1.8, 3.4), SCALE, where=lambda x, y, z: x <= 0 and y >= m, power=2.4)
    ell("Jaw", (0, 21.2, -16.6), (1.9, 1.3, 4.2), BELLY, where=lambda x, y, z: x <= 0 and y < m, power=2.4)
    d.box("Jaw", (-1, m - 1, n(-13)), (0, m - 1, n(-12)), BELLY)
    # gueule : bouche et langue en retrait d'un voxel du bout du museau, crocs blancs au bord
    zf = min(z for (x, y, z), v in d.vox.items() if v[0] == "Head" and x == 0 and y == m)
    d.box("Head", (0, m, zf + 1), (0, m, n(-14)), MOUTH)
    d.box("Jaw", (0, m - 1, zf + 2), (0, m - 1, n(-14)), TONGUE)
    for z in (zf + 1, zf + 3, zf + 5):
        x = d.surface_x(m, z, "Head")
        if x is not None:
            d.set("Head", x, m, z, TOOTH, "Smooth")
    zf = min(z for (x, y, z), v in d.vox.items() if v[0] == "Head" and x == -1 and y == m + 1)
    d.set("Head", -1, m + 1, zf + 1, DEEP, "Smooth")  # narine (sur le côté du museau : de face, seuls les yeux)
    d.box("Head", (-2, m + 3, n(-16)), (-1, m + 3, n(-14)), DEEP)  # arcade sourcilière
    # deux paires de cornes balayées vers l'arrière, en V vu de face : grandes sur le crâne, petites sur les joues
    lmb("Head", (-2.0, 24.8, -12.6), (-3.6, 26.6, -9.8), 1.2, 0.9, HORN, "Smooth")
    lmb("Head", (-3.6, 26.6, -9.8), (-5.0, 27.4, -6.6), 0.9, 0.55, HORN, "Smooth")
    lmb("Head", (-5.0, 27.4, -6.6), (-5.6, 27.6, -3.6), 0.55, 0.25, HORN, "Smooth")
    lmb("Head", (-2.6, 22.8, -12.2), (-4.2, 23.4, -8.6), 0.8, 0.3, HORN, "Smooth")
    # ---------------------------------------------------------------- ailes (gauche) : membrane de glace sur des doigts
    def w(x, z, dy=0):
        return (x * K, WY + dy, z * K)

    edge = [(-2.6, -2.6), (-9.5, -3.0), (-17.5, -3.6), (-31.0, 0.6), (-31.0, 1.4), (-27.0, 3.2), (-26.0, 8.0),
            (-21.6, 6.0), (-18.5, 10.0), (-14.4, 6.4), (-11.0, 8.6), (-6.8, 4.8), (-2.6, 6.0)]
    d.plate("Wing1L", 1, WY, [(x * K, z * K) for x, z in edge], MEMB, "Ice")
    # partage entre les os : l'avant-bras garde le secteur devant la ligne poignet -> bout du doigt intérieur ;
    # ce qui est derrière le poignet suit le doigt-aile (replié, il remonte le long du corps au lieu de passer
    # sous le sol quand le poignet est posé)
    xw, zw = -17.5, -3.0
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col == MEMB:
            ux, uz = x / K, z / K
            if ux <= -18.5 or (ux <= -10 and uz - zw > 1.78 * (ux - xw)):
                d.set("Wing3L", x, y, z, FROST, "Ice")    # bout des ailes givré, plus pâle
            elif ux <= -10:
                d.set("Wing2L", x, y, z, MEMB, "Ice")
    # bras (bord d'attaque), doigt-aile dans la membrane et trois doigts bleu foncé en éventail depuis le poignet,
    # posés sur le dessus de la membrane (elle reste d'un seul tenant ; ailes repliées, ce dessus est tourné dehors)
    d.limb("Wing1L", w(-3.0, -2.6), w(-9.5, -2.8), 1.3 * K, 1.0 * K, SCALE)
    d.limb("Wing2L", w(-9.5, -2.8), w(-17.5, -3.4), 1.0 * K, 0.8 * K, SCALE)
    d.limb("Wing3L", w(-17.5, -3.4), w(-31.0, 1.0), 0.75 * K, 0.3, DEEP)
    for tx, tz_ in ((-26.0, 8.0), (-18.5, 10.0)):
        d.limb("Wing3L", w(-17.5, -3.0, 1), w(tx, tz_, 1), 0.6, 0.3, DEEP)
    d.limb("Wing2L", w(-17.5, -3.0, 1), w(-11.0, 8.6, 1), 0.6, 0.3, DEEP)
    # griffe du poignet (vers l'avant) : elle touche le sol quand il marche
    d.box("Wing2L", (n(-18), WY - 1, n(-5)), (n(-17), WY - 1, n(-4)), CLAW, "Smooth")
    d.point("HandL", "Wing2L", w(-17.5, -4.6, -1))
    d.point("WingTipL", "Wing3L", w(-31.0, 1.0))
    # ---------------------------------------------------------------- pattes de rapace
    ell("ThighL", (-2.8, 9.4, 4.2), (1.8, 2.8, 2.4), SCALE)
    lmb("ShinL", (-2.8, 6.6, 2.6), (-2.8, 2.6, 5.6), 1.15, 0.9, SCALE)
    lmb("FootL", (-2.8, 2.6, 5.6), (-2.8, 0.7, 4.0), 0.9, 0.85, DEEP)
    d.box("FootL", (-4, 0, 1), (-2, 0, 4), DEEP)
    for x in (-4, -2):
        d.set("FootL", x, 0, 0, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, 1.2))
    # ---------------------------------------------------------------- longue queue et lame de cristal
    for i in range(5):
        lmb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], SCALE, where=left)
    blade = [(14.8, 25.0), (17.6, 27.6), (15.0, 31.6), (12.4, 27.6)]
    d.plate("Tail5", 0, 0, [s(p) for p in blade], GLASS, "Glass")
    # ---------------------------------------------------------------- yeux cyan lumineux
    d.eye("Head", "LidL", m + 1, n(-15) - 1, EYE, EYE, h=1, w=2)  # à l'avant du crâne : visibles aussi de face
    # paupières bleu foncé juste au-dessus de chaque voxel de l'oeil (le crâne se rétrécit au-dessus : sans ça,
    # la paupière baissée passerait derrière l'oeil au lieu de le couvrir)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "LidL":
            d.set("Head", x, y, z, col, mat)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Head" and col == EYE:
            d.set("LidL", x, y + 1, z, DEEP)
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == EYE else None)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : gorge et ventre blancs, dos bleu foncé
    # coupés à plat sur le torse et le bassin ; sur le cou et la queue, les bandes suivent la courbe
    belly = {"Chest": 11 * K, "Hips": 10 * K}
    d.paint(lambda x, y, z, bone, c: BELLY if c == SCALE and bone in belly and y <= belly[bone] else None)
    back = {"Chest": 15 * K, "Hips": 14 * K, "Head": 25 * K}
    d.paint(lambda x, y, z, bone, c: DEEP if c == SCALE and bone in back and y >= back[bone] else None)
    necks = [(b, a, e, (ra + rb) / 2) for b, a, e, ra, rb in neck]
    tails = [(f"Tail{i + 1}", (ty[i], tz[i]), (ty[i + 1], tz[i + 1]), (tr[i] + tr[i + 1]) / 2) for i in range(5)]
    band(necks + tails, DEEP, 0.45)
    band(necks + tails[:2], BELLY, 0.3, above=False)
    # ---------------------------------------------------------------- crête de cristaux (posée après la peinture)
    # grands sur les épaules et le dos, plus petits vers la tête et le bout de la queue, couchés vers l'arrière
    ridge = [("Neck1", -5.6, 3.2), ("Neck2", -8.4, 2.8), ("Neck3", -10.4, 2.3), ("Chest", -3.0, 6.2),
             ("Chest", 0.6, 7.8), ("Hips", 4.2, 6.4), ("Tail1", 8.8, 4.6), ("Tail2", 12.6, 3.6), ("Tail3", 16.4, 2.8),
             ("Tail4", 20.0, 2.0)]
    for i, (bone, z, h) in enumerate(ridge):
        z, h = z * K, h * K
        top = max(y for (x, y, zz), v in d.vox.items() if v[0] == bone and x == 0 and zz == round(z))
        col, mat = (ICE, "Ice") if i % 2 == 0 else (GLASS, "Glass")
        crystal(bone, (0, top, z), (0, top + h, z + 0.55 * h), 0.7 + 0.2 * h, col, mat)
    return d
