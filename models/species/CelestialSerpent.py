"""Celestial Serpent : nageur Mythic du Meteor Crater, dragon céleste oriental qui « nage » dans les airs.

Voxels de 0,38 stud : environ 30 studs de long à la taille Normal. Long corps de serpent bleu nuit indigo semé
d'étoiles (points Neon blancs et or pâle, quelques grandes étoiles en croix), ventre en écailles dorées, crinière dorée
en mèches dentelées le long du cou et du dos, grands bois de cerf dorés, moustaches en fines plaques ondulées,
barbiche dorée, yeux Neon or. Quatre petites pattes griffues (os FinF / FinB : patte en plaque à trois griffes dorées)
et une touffe de flammes dorée au coeur Neon au bout de la queue. Le corps est modélisé droit (peu de pièces) puis
ondulé par les rotations de repos des os : le cou se dresse, le dos fait une vague et le bout de la queue se relève.
Le pivot des hanches est placé haut dans le corps : le serpent flotte haut et son tonneau (Happy) ne touche pas le sol."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.38

NIGHT = (48, 40, 118)
GOLD = (255, 196, 58)
STAR = (236, 240, 255)
STAR_GOLD = (255, 228, 150)
FLAME = (255, 236, 170)
WHISKER = (255, 206, 84)    # moustaches lumineuses (Neon or)
MOUTH = (196, 70, 116)
TOOTH = (250, 248, 240)
PUPIL = (30, 18, 50)
IRIS = (255, 212, 70)

PERSONALITY = {
    "tempo": 0.85,          # ondulations amples et majestueuses
    "weight": 1.0,
    "tail": 1.2,
    "diet": "fish",
    "happy": "roll",        # tonneau dans les airs
    "catch": "ram",
}

AXIS = 8                    # hauteur de l'axe du corps (modèle droit)


def build():
    d = Dino("CelestialSerpent", FAMILY, voxel=VOXEL, display="Celestial Serpent")
    # ---------------------------------------------------------------- os (corps droit le long de z, ondulé au repos)
    d.bone("Hips", (0, AXIS + 2, 3))
    d.bone("Chest", (0, AXIS, -1), "Hips", rest=(10, 0, 0))
    d.bone("Neck1", (0, AXIS, -9), "Chest", rest=(18, 0, 0))
    d.bone("Neck2", (0, AXIS, -15), "Neck1", rest=(14, 0, 0))
    d.bone("Head", (0, AXIS, -20), "Neck2", rest=(-40, 0, 0))
    d.bone("Jaw", (0, 6.5, -24), "Head")
    d.bone_pair("Lid", (-3.5, 11, -28), "Head")
    tz = [9, 15, 21, 27, 33, 38, 42]
    tr = [3.0, 2.8, 2.5, 2.1, 1.7, 1.3, 1.0]
    trest = [-16, -10, 26, 30, 10, -55]
    for i in range(6):
        d.bone(f"Tail{i + 1}", (0, AXIS, tz[i]), "Hips" if i == 0 else f"Tail{i}", rest=(trest[i], 0, 0))
    d.bone_pair("FinF1", (-2.4, 6.0, -5.5), "Chest")
    d.bone_pair("FinF2", (-4.0, 3.2, -5.0), "FinF1L")
    d.bone_pair("FinB1", (-2.4, 6.0, 6.0), "Hips")
    d.bone_pair("FinB2", (-4.0, 3.2, 6.5), "FinB1L")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : capsules épaisses enchaînées
    # chaque segment commence par une boule centrée sur son pivot : la jointure reste pleine quand il tourne
    d.limb("Hips", (0, AXIS, -1), (0, AXIS, 9), 3.0, 3.0, NIGHT, where=left)
    d.limb("Chest", (0, AXIS, -1), (0, AXIS, -9), 3.0, 3.0, NIGHT, where=left)
    d.limb("Neck1", (0, AXIS, -9), (0, AXIS, -15), 3.0, 2.8, NIGHT, where=left)
    d.limb("Neck2", (0, AXIS, -15), (0, AXIS, -20), 2.8, 2.7, NIGHT, where=left)
    for i in range(6):
        d.limb(f"Tail{i + 1}", (0, AXIS, tz[i]), (0, AXIS, tz[i + 1]), tr[i], tr[i + 1], NIGHT, where=left)
    # ---------------------------------------------------------------- grosse tête de dragon
    d.limb("Head", (0, AXIS, -20), (0, AXIS, -22), 2.7, 2.8, NIGHT, where=left)
    d.ellipsoid("Head", (0, 9.2, -24.5), (3.6, 3.2, 3.8), NIGHT, where=lambda x, y, z: x <= 0 and y >= 7, power=2.4)
    d.ellipsoid("Head", (0, 8.6, -29.5), (2.6, 2.2, 3.2), NIGHT, where=lambda x, y, z: x <= 0 and y >= 7, power=2.3)
    d.ellipsoid("Head", (0, 10.4, -31.0), (2.0, 1.3, 1.5), NIGHT, where=left, power=2.2)     # nez retroussé
    d.ellipsoid("Jaw", (0, 6.0, -28.0), (2.4, 1.3, 4.2), NIGHT, where=lambda x, y, z: x <= 0 and y <= 6, power=2.4)
    for z in range(-30, -25):
        if (0, 7, z) in d.vox:
            d.set("Head", 0, 7, z, MOUTH)
        if (0, 6, z) in d.vox:
            d.set("Jaw", 0, 6, z, MOUTH)
    for z in (-32, -30):
        x = d.surface_x(7, z, "Head")
        if x is not None:
            d.set("Head", x, 7, z, TOOTH, "Smooth")      # crocs
    d.set("Head", -1, 11, -32, PUPIL, "Smooth")          # narine
    # barbiche dorée dentelée sous le menton
    d.plate("Jaw", 0, 0, [(5.5, -31.5), (2.0, -30.5), (3.5, -29.2), (1.5, -27.8), (4.0, -27.0), (5.5, -25.0)], GOLD)
    # grands bois de cerf dorés : merrain qui monte puis file vers l'arrière, deux andouillers vers l'avant
    d.limb("Head", (-2.2, 12.0, -23.0), (-3.2, 15.0, -21.5), 1.0, 0.85, GOLD)
    d.limb("Head", (-3.2, 15.0, -21.5), (-3.8, 18.0, -19.0), 0.85, 0.65, GOLD)
    d.limb("Head", (-3.8, 18.0, -19.0), (-3.8, 19.4, -16.4), 0.65, 0.45, GOLD)
    d.limb("Head", (-2.8, 13.8, -22.3), (-3.6, 15.8, -25.0), 0.7, 0.5, GOLD)
    d.limb("Head", (-3.5, 16.5, -20.3), (-4.6, 19.2, -21.6), 0.6, 0.45, GOLD)
    # moustaches lumineuses (Neon or) : partent du museau, retombent le long de la tête et se relèvent au bout
    wh = [(-2.5, 8.0, -32.5), (-3.8, 7.6, -32.6), (-5.0, 6.6, -31.8), (-5.8, 5.4, -30.4), (-6.2, 5.0, -28.4),
          (-6.6, 4.0, -26.4), (-6.8, 3.6, -24.4), (-7.0, 3.0, -22.4), (-7.0, 4.2, -20.8)]
    for (a, b) in zip(wh, wh[1:]):
        d.limb("Head", a, b, 0.5, 0.5, WHISKER, "Neon")
    # ---------------------------------------------------------------- pattes griffues (FinF / FinB)
    for f1, f2, z0 in (("FinF1L", "FinF2L", -5.5), ("FinB1L", "FinB2L", 6.0)):
        d.limb(f1, (-2.4, 6.0, z0), (-4.0, 3.2, z0 + 0.5), 1.3, 1.1, NIGHT)
        d.limb(f2, (-4.0, 3.2, z0 + 0.5), (-4.4, 1.0, z0 - 1.0), 1.1, 1.0, NIGHT)
        # patte en plaque : paume et trois doigts griffus dorés vers l'avant
        zc = int(math.floor(z0)) - 1
        d.box(f2, (-6, 0, zc), (-3, 0, zc + 2), NIGHT)
        for x in (-6, -4.5, -3):
            xi = int(math.floor(x)) if x != -4.5 else -5
            d.set(f2, xi, 0, zc - 1, NIGHT)
            d.set(f2, xi, 0, zc - 2, GOLD, "Smooth")
    # ---------------------------------------------------------------- touffe de flammes au bout de la queue
    # dessin de profil (z de 40 à 51 vers l'arrière, y de 15 à 3) : bulbe au coeur Neon (3 voxels d'épaisseur) et
    # langues dorées fines qui montent, filent et retombent ; vue de dessus, deux langues partent sur les côtés
    art = [
        "15 .......G....",
        "14 ......GG....",
        "13 .....GG...G.",
        "12 ....GGG..GG.",
        "11 ...GGNG.GG..",
        "10 ..GGNNGGG...",
        " 9 .GGNNNNGGGGG",
        " 8 GGNNNNNNGG..",
        " 7 .GGNNNNGG...",
        " 6 ..GGNNGG....",
        " 5 ...GGGGGG...",
        " 4 .......GGG..",
        " 3 .........G..",
    ]
    for row in art:
        y = int(row[:2])
        for k, ch in enumerate(row[3:]):
            if ch == ".":
                continue
            z = 40 + k
            col, mat = (FLAME, "Neon") if ch == "N" else (GOLD, "Plastic")
            d.set("Tail6", 0, y, z, col, mat)
            if ch == "N" or (5 <= y <= 11 and z <= 47):
                d.set("Tail6", -1, y, z, col, mat)
    for (x, z) in ((-2, 44), (-2, 45), (-3, 46), (-3, 47), (-4, 48), (-4, 49)):
        d.set("Tail6", x, AXIS, z, GOLD)
    # ---------------------------------------------------------------- yeux
    # grand oeil Neon or : l'iris se voit de face, la pupille fendue au milieu se voit de profil
    d.eye("Head", "LidL", 9, -30, IRIS, PUPIL, lid_color=NIGHT, h=2, w=3, pupil_rows=[])
    for y in (9, 10):
        x = d.surface_x(y, -29, "Head")
        if x is not None:
            d.set("Head", x, y, -29, PUPIL, "Smooth")
    for z in range(-31, -26):                                                        # arcade dorée
        for x in (-3, -2):
            ys = [y for (xx, y, zz), v in d.vox.items() if xx == x and zz == z and v[0] in ("Head", "LidL")]
            if ys:
                d.set("Head", x, max(ys) + 1, z, GOLD)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : ventre doré, yeux Neon
    body = ("Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6")

    def paint(x, y, z, bone, c):
        if c == IRIS:
            return (IRIS, "Neon")
        if c == NIGHT and bone in body and y <= AXIS - 2:
            return GOLD
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- crinière dorée en mèches (après la peinture)
    # dents de scie tournées vers l'arrière, plus longues sur le cou et derrière la tête
    mane = [("Head", -22, -20, 2), ("Neck2", -20, -15, 4), ("Neck1", -15, -9, 4), ("Chest", -9, -1, 3),
            ("Hips", -1, 9, 3), ("Tail1", 9, 15, 3), ("Tail2", 15, 21, 2), ("Tail3", 21, 27, 2)]
    for bone, z0, z1, hmax in mane:
        for z in range(z0, z1):
            top = max((y for (x, y, zz), v in d.vox.items() if x == 0 and zz == z and v[0] == bone), default=None)
            if top is None:
                continue
            k = (z - z0) % 3                                 # 0, 1, 2 : la mèche monte vers l'arrière
            h = max(1, round(hmax * (k + 1) / 3))
            for y in range(top + 1, top + h + 1):
                d.set(bone, 0, y, z, GOLD)
    # ---------------------------------------------------------------- étoiles Neon semées sur le dos et les flancs
    big = [("Chest", 9, -5, STAR), ("Hips", 9, 4, STAR_GOLD), ("Tail2", 9, 18, STAR)]
    small = [("Chest", 10, -2, STAR_GOLD), ("Chest", 7, -8, STAR), ("Hips", 10, 7, STAR), ("Hips", 7, 1, STAR_GOLD),
             ("Neck1", 9, -12, STAR), ("Neck2", 10, -17, STAR_GOLD), ("Tail1", 10, 11, STAR_GOLD), ("Tail1", 7, 14, STAR),
             ("Tail2", 7, 20, STAR_GOLD), ("Tail3", 9, 24, STAR_GOLD), ("Tail3", 8, 26, STAR), ("Tail4", 9, 29, STAR),
             ("Tail4", 8, 32, STAR_GOLD), ("Tail5", 8, 35, STAR)]

    def dot(bone, y, z, col):
        x = d.surface_x(y, z, bone)
        if x is not None and d.vox[(x, y, z)][1] == NIGHT:
            d.set(bone, x, y, z, col, "Neon")
            d.set(bone, -x, y, z, col, "Neon")

    for bone, y, z, col in big:
        for dy, dz in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            dot(bone, y + dy, z + dz, col)
    for bone, y, z, col in small:
        dot(bone, y, z, col)
    return d
