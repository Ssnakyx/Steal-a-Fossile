"""Star Dragon : volant Mythic du Meteor Crater, wyverne cosmique, la créature la plus spectaculaire du jeu.

Modélisé ailes déployées (membranes en plaques horizontales : peu de pièces), voxels de 0,4 stud : environ 28 studs
d'envergure à la taille Normal. Corps violet nuit parcouru de constellations Neon (étoiles blanches reliées par des
traits cyan), grandes ailes de dragon festonnées aux membranes de nébuleuse (bandes violet, magenta et bleu) semées
d'étoiles Neon blanches posées sur la membrane (elles se voient aussi ailes repliées), pics de cristal lilas (Glass)
le long du dos, grandes cornes dorées (Metal) balayées vers l'arrière, yeux Neon blanc cyan, longue queue terminée par
une lame de cristal Neon en étoile à quatre branches. Au parc il marche replié sur ses pattes et ses poignets (les
animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.4

BODY = (70, 44, 130)
BELLY = (128, 96, 196)
NEB1 = (84, 40, 150)        # membrane : violet (bord d'attaque)
NEB2 = (196, 52, 168)       # magenta
NEB3 = (56, 92, 214)        # bleu (bord de fuite)
STRUT = (52, 30, 96)
STAR = (240, 246, 255)
CONST = (150, 230, 255)     # traits des constellations
CRYSTAL = (214, 176, 255)
HORN = (255, 206, 84)
CLAW = (236, 228, 255)
PUPIL = (40, 30, 80)
IRIS = (200, 250, 255)
MOUTH = (150, 50, 120)
TOOTH = (246, 244, 255)
BLADE = (190, 240, 255)

PERSONALITY = {
    "tempo": 0.95,
    "weight": 1.1,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.3,
    "tail": 0.8,
    "diet": "meat",
    "happy": "flap",
    "catch": "peck",        # coup de tête plongé (gueule fermée à l'impact)
}

WY = 13                     # hauteur du plan des ailes


def build():
    d = Dino("StarDragon", FAMILY, voxel=VOXEL, display="Star Dragon")
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 12, 4))
    d.bone("Chest", (0, 12.5, -1), "Hips")
    d.bone("Neck1", (0, 14.5, -5.5), "Chest")
    d.bone("Neck2", (0, 17.5, -8.0), "Neck1")
    d.bone("Head", (0, 20.0, -10.0), "Neck2")
    d.bone("Jaw", (0, 19.6, -13.0), "Head")
    d.bone_pair("Lid", (-2.8, 23, -15), "Head")
    d.bone_pair("Wing1", (-3, WY, -2), "Chest")
    d.bone_pair("Wing2", (-11, WY, -1), "Wing1L")
    d.bone_pair("Wing3", (-20, WY, -3), "Wing2L")
    d.bone_pair("Thigh", (-2.4, 11, 4.5), "Hips")
    d.bone_pair("Shin", (-2.8, 6.5, 2.5), "ThighL")
    d.bone_pair("Foot", (-2.8, 2.6, 5.0), "ShinL")
    tz = [8.0, 12.0, 16.0, 20.0, 24.0, 28.0]
    ty = [12.6, 12.9, 13.1, 13.2, 13.2, 13.2]
    tr = [2.6, 2.1, 1.7, 1.35, 1.05, 0.75]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps de wyverne
    d.ellipsoid("Chest", (0, 12.8, -2.0), (3.8, 3.8, 4.6), BODY, where=left, power=2.6)
    d.ellipsoid("Hips", (0, 12.4, 4.6), (3.4, 3.4, 4.0), BODY, where=left, power=2.6)
    d.limb("Neck1", (0, 14.0, -5.0), (0, 17.5, -8.0), 2.6, 2.3, BODY, where=left)
    d.limb("Neck2", (0, 17.5, -8.0), (0, 20.0, -10.0), 2.3, 2.2, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête : crâne, museau en coin, mâchoire
    d.ellipsoid("Head", (0, 21.8, -13.2), (2.9, 2.6, 3.3), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.7)
    d.ellipsoid("Head", (0, 21.1, -17.8), (2.1, 1.8, 2.9), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.5)
    d.ellipsoid("Jaw", (0, 19.4, -16.6), (1.9, 1.1, 3.9), BELLY, where=lambda x, y, z: x <= 0 and y <= 19, power=2.5)
    for z in range(-19, -12):
        if (0, 20, z) in d.vox:
            d.set("Head", 0, 20, z, MOUTH)
        if (0, 19, z) in d.vox:
            d.set("Jaw", 0, 19, z, MOUTH)
    for z in (-20, -18):
        x = d.surface_x(20, z, "Head")
        if x is not None:
            d.set("Head", x, 20, z, TOOTH, "Smooth")
    if (-1, 22, -20) in d.vox:
        d.set("Head", -1, 22, -20, PUPIL, "Smooth")      # narine
    # grandes cornes dorées balayées vers l'arrière (trois segments épais qui montent puis filent)
    for a, b, ra, rb in (((-2.2, 23.6, -12.6), (-2.2, 25.8, -9.8), 1.15, 0.95),
                         ((-2.2, 25.8, -9.8), (-2.2, 26.8, -6.8), 0.95, 0.7),
                         ((-2.2, 26.8, -6.8), (-2.2, 27.0, -4.4), 0.7, 0.35)):
        d.limb("Head", a, b, ra, rb, HORN, "Metal")
    # ---------------------------------------------------------------- ailes (gauche)
    # membrane d'abord : plaque horizontale festonnée entre trois baleines, partagée entre les os de l'aile selon x
    edge = [(-2.5, -1.5), (-11, -1.0), (-20, -2.5), (-35, 4.0), (-31.5, 5.8), (-28, 9.0), (-24, 8.0), (-20, 12.0),
            (-16, 9.6), (-12, 12.5), (-7, 10.2), (-3, 10.0), (-2.2, 7.0)]
    d.plate("Wing1L", 1, WY, edge, NEB1)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col == NEB1:
            b = "Wing3L" if x <= -21 else ("Wing2L" if x <= -12 else "Wing1L")
            # nébuleuse : violet devant, magenta au milieu, bleu au bord de fuite
            c = NEB1 if z <= 1 else (NEB2 if z <= 5 else NEB3)
            d.set(b, x, y, z, c)
    # baleines (doigts) sombres qui tiennent la membrane
    for xs, z0, z1, b in ((-12, 0, 13, "Wing2L"), (-20, -2, 12, "Wing2L"), (-28, 2, 9, "Wing3L")):
        for z in range(z0, z1 + 1):
            if (xs, WY, z) in d.vox:
                d.set(b, xs, WY, z, STRUT)
    # étoiles Neon posées sur la membrane (dessus : vers l'extérieur quand l'aile est repliée)
    for (x, z) in ((-6, 4), (-8, 8), (-15, 2), (-17, 7), (-24, 5), (-26, 1), (-31, 4), (-14, 10), (-4, 7)):
        if (x, WY, z) in d.vox:
            d.set(d.vox[(x, WY, z)][0], x, WY + 1, z, STAR, "Neon")
    # puis les os : bras, avant-bras, doigt-aile (bord d'attaque)
    d.limb("Wing1L", (-3, WY, -2), (-11, WY, -1), 1.3, 1.0, BODY)
    d.limb("Wing2L", (-11, WY, -1), (-20, WY, -3), 1.0, 0.8, BODY)
    d.limb("Wing3L", (-20, WY, -3), (-35, WY, 4), 0.7, 0.35, BODY)
    # griffe du poignet (vers l'avant) : elle touche le sol quand il marche
    d.box("Wing2L", (-21, WY - 1, -5), (-20, WY - 1, -4), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-20.5, WY - 1, -4.6))
    d.point("WingTipL", "Wing3L", (-35, WY, 4))
    # ---------------------------------------------------------------- pattes arrière puissantes
    d.ellipsoid("ThighL", (-2.9, 9.8, 4.2), (1.9, 2.8, 2.4), BODY)
    d.limb("ShinL", (-2.8, 6.5, 2.5), (-2.8, 2.6, 5.0), 1.4, 1.1, BODY)
    d.limb("FootL", (-2.8, 2.6, 5.0), (-2.8, 0.7, 3.0), 1.1, 1.0, BODY)
    d.box("FootL", (-4, 0, 0), (-2, 0, 3), BODY)
    for x in (-4, -2):
        d.set("FootL", x, 0, -1, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, 0.5))
    # ---------------------------------------------------------------- longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- pics de cristal lilas le long du dos
    # grands éclats translucides penchés vers l'arrière, du plus grand (épaules) au plus petit (queue)
    for bone, base, tip, r in (
            ("Neck1", (0, 17.0, -6.4), (0, 20.0, -4.6), 0.9),
            ("Chest", (0, 15.8, -3.2), (0, 21.4, -0.4), 1.3),
            ("Hips", (0, 15.0, 3.0), (0, 20.2, 5.8), 1.2),
            ("Tail1", (0, 14.4, 9.6), (0, 17.8, 11.8), 0.9),
            ("Tail2", (0, 14.0, 14.4), (0, 16.4, 16.0), 0.7)):
        d.limb(bone, base, tip, r, 0.3, CRYSTAL, "Glass")
    # ---------------------------------------------------------------- lame de cristal Neon en étoile au bout de la queue
    # étoile à quatre branches aux côtés creusés, dans deux plaques croisées (verticale et horizontale)
    cy, cz = 13, 31
    for a in range(-5, 6):
        for b in range(-5, 8):
            rb = 6.5 if b >= 0 else 4.6
            if (abs(a) / 4.8) ** (2 / 3) + (abs(b) / rb) ** (2 / 3) <= 1:
                d.set("Tail5", 0, cy + a, cz + b, BLADE, "Neon")
                if a <= 0 and (abs(a) / 3.8) ** (2 / 3) + (abs(b) / rb) ** (2 / 3) <= 1:
                    d.set("Tail5", a, cy, cz + b, BLADE, "Neon")
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 22, -16, IRIS, PUPIL, lid_color=BODY, h=1, w=3)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Chest": 11, "Hips": 11}

    def paint(x, y, z, bone, c):
        if c == IRIS:
            return (IRIS, "Neon")
        if c == BODY and bone in belly and y <= belly[bone]:
            return BELLY
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- constellations Neon sur le dos
    # de chaque côté de la rangée de cristaux, une constellation en zigzag du cou à la queue : étoiles blanches
    # (les plus brillantes en croix) reliées par des traits cyan, posées sur le dessus de la peau
    body = ("Neck1", "Chest", "Hips", "Tail1", "Tail2", "Tail3")

    def top(x, z):
        ys = [k[1] for k, v in d.vox.items() if k[0] == x and k[2] == z and v[0] in body and v[1] == BODY]
        return max(ys) if ys else None

    def put(x, z, col):
        y = top(x, z)
        if y is not None:
            for xx in (x, -x):
                d.set(d.vox[(xx, y, z)][0], xx, y, z, col, "Neon")

    nodes = [(-2, -7, 0), (-3, -2, 1), (-2, 1, 0), (-3, 5, 1), (-2, 9, 0), (-1, 13, 0), (-1, 18, 0)]
    for (x0, z0, _), (x1, z1, _) in zip(nodes, nodes[1:]):
        n = max(abs(x1 - x0), abs(z1 - z0))
        for i in range(1, n):
            put(round(x0 + (x1 - x0) * i / n), round(z0 + (z1 - z0) * i / n), CONST)
    for x, z, big in nodes:
        put(x, z, STAR)
        if big:
            for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                put(x + dx, z + dz, STAR)
    return d
