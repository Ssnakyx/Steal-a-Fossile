"""Frost Wyvern : dragon des glaces légendaire (créature fantastique du Glacier), majestueux et glacial.

Modélisé ailes déployées (membranes en plaques horizontales), voxels de 0,355 stud : environ 22 studs d'envergure et
19 de long à la taille Normal. Écailles bleu glace pâle, gorge et ventre blancs, bande bleu profond qui suit le dos du
crâne au bout de la queue ; ailes de dragon aux membranes de glace translucide (matière Ice) tendues sur des doigts
bleu foncé, bord de fuite festonné ; crête de grands cristaux de glace (Ice et Glass, alternés) le long du cou, du dos
et de la queue ; deux paires de cornes balayées vers l'arrière ; yeux cyan lumineux (Neon) ; longue queue finie par
une lame de cristal (Glass). Au sol il marche sur ses pattes et sur les poignets de ses ailes repliées, comme une
vraie vouivre."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.355

SCALE = (156, 206, 240)
DEEP = (70, 116, 186)
BELLY = (236, 246, 255)
MEMB = (126, 200, 244)
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


def build():
    d = Dino("FrostWyvern", FAMILY, voxel=VOXEL, display="Frost Wyvern")

    def crystal(bone, base, tip, r, color=ICE, mat="Ice"):
        """Cristal de glace : segment effilé translucide, de la peau vers la pointe."""
        d.limb(bone, base, tip, r, 0.25, color, mat)

    def band(segs, color, k, above=True):
        """Bande qui suit la courbe du cou ou de la queue : voxels d'écailles de chaque os au-dessus (dos) ou
        au-dessous (gorge) de son axe, à plus de k rayons (distance perpendiculaire, dans le plan du profil)."""
        for bone, (ay, az), (by, bz), r in segs:
            n = math.hypot(by - ay, bz - az)
            ny, nz = -(bz - az) / n, (by - ay) / n
            if ny < 0:
                ny, nz = -ny, -nz

            def fn(x, y, z, b, c, bone=bone, ay=ay, az=az, ny=ny, nz=nz, r=r):
                if b != bone or c != SCALE:
                    return None
                s = (y - ay) * ny + (z - az) * nz
                return color if (s > k * r if above else s < -k * r) else None
            d.paint(fn)

    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 11, 4))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.0, -4.6), "Chest")
    d.bone("Neck2", (0, 16.6, -7.6), "Neck1")
    d.bone("Neck3", (0, 19.4, -9.6), "Neck2")
    d.bone("Head", (0, 21.6, -11.2), "Neck3")
    d.bone("Jaw", (0, 21.4, -13.4), "Head")
    d.bone_pair("Lid", (-2.0, 24, -15), "Head")
    d.bone_pair("Wing1", (-3.0, 14.0, -2.6), "Chest")
    d.bone_pair("Wing2", (-9.5, 14.0, -2.8), "Wing1L")
    d.bone_pair("Wing3", (-17.5, 14.0, -3.4), "Wing2L")
    d.bone_pair("Thigh", (-2.4, 11.0, 5.0), "Hips")
    d.bone_pair("Shin", (-2.8, 6.6, 2.6), "ThighL")
    d.bone_pair("Foot", (-2.8, 2.6, 5.6), "ShinL")
    tz = [7.6, 11.4, 15.2, 19.0, 22.6, 26.0]
    ty = [12.2, 12.6, 13.2, 13.8, 14.4, 14.8]
    tr = [2.3, 1.9, 1.5, 1.15, 0.85, 0.55]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : poitrail puissant, bassin fin
    d.ellipsoid("Chest", (0, 12.6, -1.6), (3.8, 3.8, 4.4), SCALE, where=left, power=2.4)
    d.ellipsoid("Hips", (0, 12.0, 4.0), (3.2, 3.2, 3.6), SCALE, where=left, power=2.4)
    # ---------------------------------------------------------------- long cou en S (trois segments épais)
    neck = [("Neck1", (13.6, -4.2), (16.6, -7.6), 2.6, 2.3), ("Neck2", (16.6, -7.6), (19.4, -9.6), 2.3, 2.0),
            ("Neck3", (19.4, -9.6), (21.6, -11.2), 2.0, 1.9)]
    for bone, (ay, az), (by, bz), ra, rb in neck:
        d.limb(bone, (0, ay, az), (0, by, bz), ra, rb, SCALE, where=left)
    # ---------------------------------------------------------------- tête de dragon : crâne, long museau, mâchoire
    d.ellipsoid("Head", (0, 23.2, -13.6), (2.7, 2.4, 3.0), SCALE, where=lambda x, y, z: x <= 0 and y >= 22, power=2.5)
    d.ellipsoid("Head", (0, 22.7, -18.0), (1.9, 1.6, 3.2), SCALE, where=lambda x, y, z: x <= 0 and y >= 22, power=2.4)
    d.ellipsoid("Jaw", (0, 21.2, -16.6), (1.8, 1.0, 4.0), BELLY, where=lambda x, y, z: x <= 0 and y <= 21, power=2.4)
    d.box("Jaw", (-1, 21, -13), (0, 21, -12), BELLY)
    d.box("Head", (0, 22, -20), (0, 22, -14), MOUTH)
    d.box("Jaw", (0, 21, -19), (0, 21, -14), TONGUE)
    for z in (-20, -18, -16):
        x = d.surface_x(22, z, "Head")
        if x is not None:
            d.set("Head", x, 22, z, TOOTH, "Smooth")
    d.set("Head", -1, 23, -21, DEEP, "Smooth")  # narine
    d.box("Head", (-2, 25, -16), (-1, 25, -14), DEEP)  # arcade sourcilière
    # deux paires de cornes balayées vers l'arrière, en V vu de face : grandes sur le crâne, petites sur les joues
    d.limb("Head", (-1.8, 24.6, -12.8), (-3.0, 26.8, -10.0), 1.15, 0.85, HORN, "Smooth")
    d.limb("Head", (-3.0, 26.8, -10.0), (-4.2, 27.9, -6.6), 0.85, 0.5, HORN, "Smooth")
    d.limb("Head", (-4.2, 27.9, -6.6), (-4.5, 28.1, -4.0), 0.5, 0.2, HORN, "Smooth")
    d.limb("Head", (-2.4, 22.6, -12.2), (-3.8, 23.2, -8.8), 0.75, 0.25, HORN, "Smooth")
    # ---------------------------------------------------------------- ailes (gauche) : membrane de glace sur des doigts
    edge = [(-2.6, -2.6), (-9.5, -3.0), (-17.5, -3.6), (-31.0, 0.6), (-31.0, 1.4), (-27.0, 3.2), (-26.0, 8.0),
            (-21.6, 6.0), (-18.5, 10.0), (-14.4, 6.4), (-11.0, 8.6), (-6.8, 4.8), (-2.6, 6.0)]
    d.plate("Wing1L", 1, 14, edge, MEMB, "Ice")
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col == MEMB:
            if x <= -19:
                d.set("Wing3L", x, y, z, MEMB, "Ice")
            elif x <= -10:
                d.set("Wing2L", x, y, z, MEMB, "Ice")
    # bras (bord d'attaque) et doigts bleu foncé en éventail depuis le poignet
    d.limb("Wing1L", (-3.0, 14.0, -2.6), (-9.5, 14.0, -2.8), 1.3, 1.0, SCALE)
    d.limb("Wing2L", (-9.5, 14.0, -2.8), (-17.5, 14.0, -3.4), 1.0, 0.8, SCALE)
    d.limb("Wing3L", (-17.5, 14.0, -3.4), (-31.0, 14.0, 1.0), 0.75, 0.3, DEEP)
    d.limb("Wing3L", (-17.5, 14.0, -3.0), (-26.0, 14.0, 8.0), 0.6, 0.3, DEEP)
    for tip in ((-18.5, 14.0, 10.0), (-11.0, 14.0, 8.6)):
        d.limb("Wing2L", (-17.5, 14.0, -3.0), tip, 0.6, 0.3, DEEP)
    # griffe du poignet (vers l'avant) : elle touche le sol quand il marche
    d.box("Wing2L", (-18, 13, -5), (-17, 13, -4), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-17.5, 13, -4.6))
    d.point("WingTipL", "Wing3L", (-31.0, 14.0, 1.0))
    # ---------------------------------------------------------------- pattes de rapace
    d.ellipsoid("ThighL", (-2.8, 9.4, 4.2), (1.6, 2.6, 2.2), SCALE)
    d.limb("ShinL", (-2.8, 6.6, 2.6), (-2.8, 2.6, 5.6), 1.1, 0.85, SCALE)
    d.limb("FootL", (-2.8, 2.6, 5.6), (-2.8, 0.7, 4.0), 0.85, 0.8, DEEP)
    d.box("FootL", (-4, 0, 1), (-2, 0, 4), DEEP)
    for x in (-4, -2):
        d.set("FootL", x, 0, 0, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, 1.2))
    # ---------------------------------------------------------------- longue queue et lame de cristal
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], SCALE, where=left)
    blade = [(14.8, 25.0), (17.6, 27.6), (15.0, 31.6), (12.4, 27.6)]
    d.plate("Tail5", 0, 0, blade, GLASS, "Glass")
    # ---------------------------------------------------------------- yeux cyan lumineux
    d.eye("Head", "LidL", 23, -15, EYE, EYE, h=1, w=2)
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == EYE else None)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : gorge et ventre blancs, dos bleu profond
    # coupés à plat sur le torse et le bassin ; sur le cou et la queue, les bandes suivent la courbe
    belly = {"Chest": 11, "Hips": 10}
    d.paint(lambda x, y, z, bone, c: BELLY if c == SCALE and bone in belly and y <= belly[bone] else None)
    back = {"Chest": 15, "Hips": 14, "Head": 25}
    d.paint(lambda x, y, z, bone, c: DEEP if c == SCALE and bone in back and y >= back[bone] else None)
    necks = [(b, a, e, (ra + rb) / 2) for b, a, e, ra, rb in neck]
    tails = [(f"Tail{i + 1}", (ty[i], tz[i]), (ty[i + 1], tz[i + 1]), (tr[i] + tr[i + 1]) / 2) for i in range(5)]
    band(necks + tails, DEEP, 0.45)
    band(necks + tails[:2], BELLY, 0.3, above=False)
    # ---------------------------------------------------------------- crête de cristaux (posée après la peinture)
    # grands sur les épaules et le dos, plus petits vers la tête et le bout de la queue, couchés vers l'arrière
    ridge = [("Neck1", -5.6, 2.8), ("Neck2", -8.4, 2.4), ("Neck3", -10.4, 2.0), ("Chest", -3.0, 5.0),
             ("Chest", 0.6, 6.4), ("Hips", 4.2, 5.2), ("Tail1", 8.8, 3.8), ("Tail2", 12.6, 3.0), ("Tail3", 16.4, 2.3),
             ("Tail4", 20.0, 1.7)]
    for i, (bone, z, h) in enumerate(ridge):
        top = max(y for (x, y, zz), v in d.vox.items() if v[0] == bone and x == 0 and zz == round(z))
        col, mat = (ICE, "Ice") if i % 2 == 0 else (GLASS, "Glass")
        crystal(bone, (0, top, z), (0, top + h, z + 0.55 * h), 0.5 + 0.15 * h, col, mat)
    return d
