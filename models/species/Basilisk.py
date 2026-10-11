"""Basilisk : roi des marais (créature FANTASTIQUE, Epic), long lézard-serpent bas sur pattes.

Voxels de 0,25 stud : environ 15 studs de long, 5 de large (capuchon) et 6 de haut (couronne comprise) à la taille
Normal. Corps long et bas sur quatre pattes courtes écartées, longue queue de serpent ; cou dressé qui porte une tête
de vipère en flèche (large derrière, museau arrondi), deux grands crocs blancs, yeux vert toxique (Neon) à pupille
fendue sous des arcades noires. Sur le crâne, une couronne de 5 pointes noires (os Crest) sur un bandeau d'or en
diadème, aux bouts Neon ; derrière la tête, un immense capuchon de cobra (os Frill, écusson accroché au cou, un peu
creusé et penché en arrière) : membrane émeraude, anneau noir autour de la tête, taches Neon, bord noir en relief.
Écailles émeraude-noir annelées de noir, deux rangées de taches Neon sur le dos, ventre jaune d'or. Menaçant mais pas
gore."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.25

SCALE = (32, 106, 72)
BLACK = (14, 30, 24)
EMERALD = (44, 172, 108)
NEON = (150, 255, 60)
GOLD = (246, 196, 46)
FANG = (250, 248, 236)
PUPIL = (12, 12, 10)
MOUTH = (96, 24, 52)

PERSONALITY = {
    "tempo": 0.9,           # roi lent et sûr de lui
    "weight": 1.2,
    "stride": 0.85,
    "bob": 0.5,
    "headBob": 0.0,
    "tail": 1.4,            # queue de serpent qui ondule
    "diet": "meat",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.5,
}

# capuchon : demi-largeur par rangée (écusson large en haut, qui se resserre sur le cou)
HOOD = {8: 3.2, 9: 4.8, 10: 6.2, 11: 7.4, 12: 8.3, 13: 8.9, 14: 9.3, 15: 9.4, 16: 9.3, 17: 8.9, 18: 8.2, 19: 7.0,
        20: 5.4, 21: 3.4, 22: 1.2}


def build():
    d = Dino("Basilisk", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 5.5, 7))
    d.bone("Chest", (0, 5.6, 0), "Hips")
    d.bone("Neck1", (0, 7.0, -6.0), "Chest")
    d.bone("Neck2", (0, 9.8, -8.6), "Neck1")
    d.bone("Head", (0, 12.4, -11.0), "Neck2")
    d.bone("Jaw", (0, 11.6, -12.6), "Head")
    d.bone("Crest", (0, 16.5, -13.0), "Head")
    d.bone("Frill", (0, 8.6, -7.2), "Neck2", rest=(12, 0, 0))
    d.bone_pair("Lid", (-3.4, 15, -16.5), "Head")
    d.bone_pair("Arm", (-3.6, 5.2, -3.0), "Chest")
    d.bone_pair("Forearm", (-6.0, 3.6, -2.0), "ArmL")
    d.bone_pair("Hand", (-6.4, 1.2, -3.4), "ForearmL")
    d.bone_pair("Thigh", (-3.6, 5.2, 9.0), "Hips")
    d.bone_pair("Shin", (-6.0, 3.6, 8.0), "ThighL")
    d.bone_pair("Foot", (-6.4, 1.2, 9.4), "ShinL")
    tz = [12.4, 17.4, 22.2, 26.8, 31.2, 35.4]
    ty = [5.6, 5.4, 5.1, 4.7, 4.4, 4.2]
    tr = [3.4, 2.9, 2.3, 1.7, 1.1, 0.5]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- long corps bas, cou dressé
    d.ellipsoid("Hips", (0, 5.6, 7.5), (3.9, 3.0, 6.2), SCALE, where=left, power=2.4)
    d.ellipsoid("Chest", (0, 5.7, -0.5), (4.2, 3.1, 5.9), SCALE, where=left, power=2.4)
    d.limb("Neck1", (0, 6.6, -5.0), (0, 9.8, -8.6), 3.0, 2.7, SCALE, where=left)
    d.limb("Neck2", (0, 9.8, -8.6), (0, 12.4, -11.0), 2.7, 2.6, SCALE, where=left)
    # ---------------------------------------------------------------- tête de vipère en flèche
    for z in range(-22, -10):
        t = min(1.0, (z + 22) / 10.0)
        w = 1.8 + 2.6 * t ** 0.7
        top = 13 if t < 0.25 else 14 if t < 0.5 else 15 if t < 0.75 else 16
        for y in range(12, top + 1):
            ww = w - (0.8 if y == top else 0.0)
            for x in range(-int(ww + 0.5), 1):
                d.set("Head", x, y, z, SCALE)
        if -21 <= z <= -12:
            for y, dw in ((11, 0.4), (10, 1.3)):
                if y == 10 and z < -20:
                    continue
                for x in range(-int(w - dw + 0.5), 1):
                    d.set("Jaw", x, y, z, GOLD)
    # yeux en relief (on les voit aussi de face), arcade noire au-dessus (regard menaçant)
    for z in (-17, -16, -15):
        x = d.surface_x(13, z, "Head")
        for y in (13, 14, 15, 16):
            d.set("Head", x - 1, y, z, SCALE)
        d.set("Head", x, 16, z, BLACK)
    # crocs : deux longues dents qui pendent devant la mâchoire du bas
    for y in (11, 10, 9):
        d.set("Head", -2, y, -21, FANG, "Smooth")
    d.set("Head", -1, 13, -22, BLACK, "Smooth")                      # narine
    # ---------------------------------------------------------------- couronne de 5 pointes sur un bandeau d'or
    # bandeau en V vu de dessus (il recule vers les côtés, comme un diadème) : de profil on voit trois pointes en
    # escalier. Pointe = tige noire de 2 voxels d'épaisseur penchée vers l'arrière, bout Neon pointu.
    for xs, z0, h in (((0, -1), -16, 6), ((-2, -3), -14, 5), ((-4, -5), -12, 4)):
        for x in xs:
            for z in range(z0, z0 + (2 if z0 == -12 else 3)):
                top = d.surface_y(x, z, "Head")
                for y in range((16 if top is None else top) + 1, 19):
                    d.set("Crest", x, y, z, GOLD)
        xt = min(xs) if min(xs) < -1 else 0
        for k in range(h):
            z = z0 + k // 3
            tip = k >= h - 2
            for zz in ((z + 1,) if k >= h - 3 else (z, z + 1)):          # la tige s'affine vers le bout
                d.set("Crest", xt, 19 + k, zz, NEON if tip else BLACK, "Neon" if tip else "Plastic")
    # ---------------------------------------------------------------- capuchon de cobra (écusson accroché au cou)
    for y, w in HOOD.items():
        for x in range(-int(w + 0.5), 1):
            zo = -int(0.045 * x * x + 0.5)                          # capuchon creusé : les bords avancent
            edge = abs(x) >= int(w + 0.5) or y == max(HOOD) or (y + 1 in HOOD and abs(x) > HOOD[y + 1] + 0.5)
            r = math.hypot(x, (y - 12.5) * 1.2)
            col = GOLD if edge else BLACK if 6.8 <= r < 7.7 else EMERALD
            d.set("Frill", x, y, -8 + zo, col)
            d.set("Frill", x, y, -7 + zo, col)
            if edge and y >= 10:
                d.set("Frill", x, y, -6 + zo, BLACK)                # bord en relief vers l'arrière
    for (x, y) in ((-8, 14), (-7, 17), (-4, 19), (-6, 11)):
        for dx in (0, 1):
            for dy in (0, 1):
                for z in range(-12, -5):
                    k = (x + dx, y + dy, z)
                    if k in d.vox and d.vox[k][0] == "Frill" and d.vox[k][1] == EMERALD:
                        d.set("Frill", *k, NEON, "Neon")
    # ---------------------------------------------------------------- pattes courtes écartées de lézard
    d.limb("ArmL", (-3.4, 5.2, -3.0), (-6.0, 3.6, -2.0), 1.9, 1.6, SCALE)
    d.limb("ForearmL", (-6.0, 3.6, -2.0), (-6.4, 1.2, -3.4), 1.5, 1.3, SCALE)
    d.box("HandL", (-8, 0, -5), (-5, 0, -3), SCALE)
    for x in (-8, -6):
        d.set("HandL", x, 0, -6, FANG, "Smooth")
    d.limb("ThighL", (-3.4, 5.2, 9.0), (-6.0, 3.6, 8.0), 2.1, 1.7, SCALE)
    d.limb("ShinL", (-6.0, 3.6, 8.0), (-6.4, 1.2, 9.4), 1.5, 1.3, SCALE)
    d.box("FootL", (-8, 0, 6), (-5, 0, 9), SCALE)
    for x in (-8, -6):
        d.set("FootL", x, 0, 5, FANG, "Smooth")
    d.point("ToeL", "FootL", (-6.5, 0, 6.5))
    d.point("FrontToeL", "HandL", (-6.5, 0, -4.5))
    # ---------------------------------------------------------------- longue queue de serpent
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], SCALE, where=left)
    # ---------------------------------------------------------------- yeux Neon à pupille fendue, symétrie
    d.eye("Head", "LidL", 13, -17, NEON, PUPIL, lid_color=BLACK, h=2, w=3)
    for y in (13, 14):                                               # pupille fendue au milieu de l'oeil
        x = d.surface_x(y, -17, "Head")
        d.set("Head", x, y, -17, NEON, "Neon")
        x = d.surface_x(y, -16, "Head")
        d.set("Head", x, y, -16, PUPIL, "Smooth")
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == NEON else None)
    # ---------------------------------------------------------------- gueule : creux intérieur sombre
    jaw = {k for k, v in d.vox.items() if v[0] == "Jaw"}
    for (x, y, z) in list(jaw):
        if y != 11:
            continue
        ring = all((x + dx, 11, z + dz) in jaw for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        if ring and (x, 13, z) in d.vox and (x, 12, z) in d.vox:
            d.clear(x, 11, z)
            if all((x + dx, 10, z + dz) in d.vox for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                d.set("Jaw", x, 10, z, MOUTH)
            d.set("Head", x, 12, z, MOUTH)
    # ---------------------------------------------------------------- peinture : ventre d'or, anneaux noirs, taches
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
    d.countershade(["Neck1", "Neck2"], GOLD, frac=0.3, only=[SCALE])
    flat = {"Chest": 4, "Hips": 4, "Tail1": 4, "Tail2": 4, "Tail3": 4, "Tail4": 3, "Tail5": 3}   # ventre à plat
    d.paint(lambda x, y, z, bone, c: GOLD if c == SCALE and bone in flat and y <= flat[bone] else None)
    d.back_stripes(["Hips", "Chest", "Neck1", "Tail1", "Tail2", "Tail3", "Tail4"], BLACK, frac=0.35,
                   period=6, width=2, only=[SCALE])
    d.paint(lambda x, y, z, bone, c: BLACK if bone == "Head" and c == SCALE and y >= 16 else None)
    cols = d.columns(body)
    for (bone, x, z), (lo, hi) in cols.items():
        row = (abs(x) == 2 and bone in ("Chest", "Hips", "Neck1")) or (abs(x) == 1 and bone in ("Tail1", "Tail2"))
        if row and z % 6 == 4 and d.vox[(x, hi, z)][1] == SCALE:
            d.set(bone, x, hi, z, NEON, "Neon")
    return d
