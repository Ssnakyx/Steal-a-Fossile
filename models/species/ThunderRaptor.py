"""Thunder Raptor : Legendary fantastique du Canyon, raptor de tempête plus grand que le Velociraptor.

Voxels de 0,33 stud : environ 16 studs de long et 11 de haut (crête comprise) à la taille Normal. Plumage bleu nuit
orageux, ventre gris d'orage, zébrures Neon cyan en zigzag d'éclair (chevrons sur le dos, brisées en éclair sur les
flancs) des épaules au bout de la queue, grande crête de plumes en éclair sur la tête (os Crest, pointe Neon jaune),
lame de plumes en dents de scie sous chaque avant-bras (pointe Neon cyan), queue terminée par un éclair de plumes,
yeux Neon jaune, griffes en faucille Neon cyan."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.33

NAVY = (34, 46, 100)
DEEP = (22, 28, 64)
FEATHER = (66, 104, 206)
BELLY = (150, 170, 216)
BOLT = (90, 236, 255)
SPARK = (255, 232, 70)
CLAW = (236, 242, 255)
PUPIL = (14, 14, 30)
MOUTH = (128, 36, 74)
TONGUE = (206, 96, 128)
TOOTH = (250, 250, 255)

PERSONALITY = {
    "tempo": 1.25,          # vif comme l'éclair
    "weight": 0.9,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 1.0,
    "tail": 1.15,
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",
}

# Dessins en pixels vus de profil : rangées du haut vers le bas, colonnes de l'avant vers l'arrière.
# Crête : grand éclair dressé sur le crâne et rabattu vers l'arrière, pointe Neon jaune.
CREST = [
    ".........YY",
    "........YYY",
    ".......YYF.",
    "......FFF..",
    ".....FFF...",
    "....FFFFFFF",
    "........FFF",
    ".......FFF.",
    "......FFF..",
    ".....FFF...",
    "...FFFFF...",
]
CREST_X = [(0,)] * 9 + [(-1, 0, 1)] * 2      # épaisseur de chaque rangée (x)
# Plumes d'avant-bras : lame de plumes en marches sous l'avant-bras, pointe Neon cyan (reste devant le genou).
WING = ["FFFFF", "FFFFF", ".FFFF", "..FF.", "..C.."]
# Bout de la queue : éclair de plumes dressé.
TAIL_BOLT = [
    "......CCC",
    ".....CCC.",
    "....FFF..",
    "...FFFFFF",
    "......FFF",
    ".....FFF.",
    "....FFF..",
    "...FFF...",
]
# Zébrure : rangée u = distance le long de la peau depuis l'échine, colonnes = z - z0 (vers l'arrière). Vue de
# dessus elle fait un chevron rabattu vers l'arrière (zigzag le long de l'échine), sur le flanc elle se brise en éclair
# (barre puis pointe).
ZIG = ["......XXX", ".....XXX.", "....XXX..", "...XXX...", "..XXXXXX.", ".....XXX.", "....XX...", "....X...."]
STRIPES = [-4, 2, 8, 14, 19]


def build():
    d = Dino("ThunderRaptor", FAMILY, voxel=VOXEL, display="Thunder Raptor")
    # ---------------------------------------------------------------- os (squelette du Velociraptor)
    d.bone("Hips", (0, 12, 2))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.5, -6.2), "Chest")
    d.bone("Neck2", (0, 17.2, -8.6), "Neck1")
    d.bone("Head", (0, 19.6, -10.4), "Neck2")
    d.bone("Jaw", (0, 18.8, -12.2), "Head")
    d.bone("Crest", (0, 23.5, -11.5), "Head")
    d.bone_pair("Lid", (-2.6, 22, -15), "Head")
    d.bone_pair("Arm", (-3.0, 11.5, -6.2), "Chest")
    d.bone_pair("Forearm", (-3.6, 9.6, -7.6), "ArmL")
    d.bone_pair("Thigh", (-3.6, 11.5, 2), "Hips")
    d.bone_pair("Shin", (-3.8, 6.5, -0.6), "ThighL")
    d.bone_pair("Foot", (-3.7, 3.2, 2.6), "ShinL")
    tz = [7.6, 11.2, 14.8, 18.2, 21.4, 24.4]
    tr = [3.4, 2.8, 2.2, 1.7, 1.25, 0.85]
    ty = [12.4, 12.9, 13.3, 13.6, 13.8, 14.0]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    def sprite(bone, rows, x0, x1, y_top, z0, palette, keep=()):
        """Dessin en pixels dans le plan YZ, épais de x0 à x1. keep : os dont on n'écrase pas les voxels."""
        for i, row in enumerate(rows):
            for j, ch in enumerate(row):
                if ch in palette:
                    col, mat = palette[ch]
                    for x in range(x0, x1 + 1):
                        k = (x, y_top - i, z0 + j)
                        if k in d.vox and d.vox[k][0] in keep:
                            continue
                        d.set(bone, *k, col, mat)

    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 12, 3.5), (4.0, 3.9, 5.0), NAVY, where=left, power=2.5)
    d.ellipsoid("Chest", (0, 11.8, -3.0), (4.3, 4.5, 4.6), NAVY, where=left, power=2.5)
    d.limb("Neck1", (0, 14.0, -6.0), (0, 17.2, -8.6), 2.9, 2.5, NAVY, where=left)
    d.limb("Neck2", (0, 17.2, -8.6), (0, 19.6, -10.2), 2.5, 2.4, NAVY, where=left)
    # ---------------------------------------------------------------- queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], NAVY, where=left)
    # ---------------------------------------------------------------- tête : crâne, museau, mâchoire
    d.ellipsoid("Head", (0, 21.0, -12.8), (3.2, 2.9, 3.4), NAVY, where=left, power=2.7)
    d.ellipsoid("Head", (0, 20.3, -16.8), (2.3, 1.9, 3.3), NAVY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.4)
    d.ellipsoid("Jaw", (0, 18.2, -15.6), (1.9, 1.0, 3.8), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.6)
    d.box("Jaw", (-1, 18, -13), (0, 18, -12), NAVY)
    d.box("Head", (0, 19, -18), (0, 19, -13), MOUTH)
    d.box("Jaw", (0, 18, -17), (0, 18, -14), TONGUE)
    for z in (-18, -16, -14):
        d.set("Head", -1, 19, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- bras : plumes en dents de scie
    d.limb("ArmL", (-3.0, 11.5, -6.2), (-3.6, 9.6, -7.6), 1.3, 1.1, NAVY)
    d.limb("ForearmL", (-3.6, 9.6, -7.6), (-3.4, 8.4, -9.8), 1.0, 0.8, NAVY)
    sprite("ForearmL", WING, -4, -4, 9, -11, {"F": (FEATHER, "Plastic"), "C": (BOLT, "Neon")}, keep=("Chest",))
    for p in ((-4, 7, -11), (-3, 7, -10), (-4, 8, -12)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes, griffes en faucille Neon
    d.ellipsoid("ThighL", (-4.0, 9.2, 0.6), (2.4, 3.5, 3.3), NAVY)
    d.limb("ShinL", (-3.8, 6.5, -0.6), (-3.7, 3.2, 2.6), 1.7, 1.3, NAVY)
    d.limb("FootL", (-3.7, 3.2, 2.6), (-3.7, 0.9, 0.4), 1.3, 1.2, NAVY)
    d.box("FootL", (-5, 0, -3), (-3, 0, 1), NAVY)
    d.box("FootL", (-4, 1, -2), (-3, 1, 1), NAVY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    for p in ((-2, 1, 0), (-2, 2, -1), (-2, 2, -2), (-2, 1, -3)):
        d.set("FootL", *p, BOLT, "Neon")
    d.point("ToeL", "FootL", (-4, 0, -3.5))
    # ---------------------------------------------------------------- yeux Neon jaune
    d.eye("Head", "LidL", 20, -15, SPARK, PUPIL, lid_color=DEEP, h=2, w=2, pupil_rows=(0,))
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == SPARK and bone == "Head" else None)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : ventre d'orage coupé à plat
    belly = {"Chest": 9, "Hips": 10, "Tail1": 11, "Tail2": 12, "Tail3": 12, "Tail4": 13}
    d.paint(lambda x, y, z, bone, c: BELLY if c == NAVY and bone in belly and y <= belly[bone] else None)
    necks = {"Neck1": ((14.0, -6.0), (17.2, -8.6)), "Neck2": ((17.2, -8.6), (19.6, -10.2))}

    def throat(x, y, z, bone, c):
        if bone not in necks or c != NAVY:
            return None
        (y0, z0), (y1, z1) = necks[bone]
        ny, nz = -(z1 - z0), (y1 - y0)
        m = (ny * ny + nz * nz) ** 0.5
        return BELLY if ((y - y0) * ny + (z - z0) * nz) / m < -0.6 else None
    d.paint(throat)

    # ---------------------------------------------------------------- zébrures en éclairs Neon cyan
    body = ("Chest", "Hips", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5")
    span = {}
    for (x, y, z), (bone, c, m) in d.vox.items():
        if x == 0 and bone in body:
            lo, hi = span.get(z, (y, y))
            span[z] = (min(lo, y), max(hi, y))
    cells = set()
    for z0 in STRIPES:
        for u, row in enumerate(ZIG):
            for j, ch in enumerate(row):
                if ch == "X":
                    cells.add((u, z0 + j))

    def zebra(x, y, z, bone, c):
        if c != NAVY or bone not in body or z not in span:
            return None
        lo, hi = span[z]
        yc, r = (lo + hi) / 2, max(1.0, (hi - lo) / 2)
        u = round(math.atan2(abs(x), y - yc) * r)
        return (BOLT, "Neon") if (u, z) in cells else None
    d.paint(zebra)
    # ---------------------------------------------------------------- crête et bout de queue (après les zébrures)
    for i, xs in enumerate(CREST_X):
        for x in xs:
            sprite("Crest", CREST[i:i + 1], x, x, 33 - i, -16, {"F": (FEATHER, "Plastic"), "Y": (SPARK, "Neon")})
    sprite("Tail5", TAIL_BOLT, 0, 0, 20, 19, {"F": (FEATHER, "Plastic"), "C": (BOLT, "Neon")})
    return d
