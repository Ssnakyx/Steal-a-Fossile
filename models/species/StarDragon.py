"""Star Dragon : volant Mythic du Meteor Crater, wyverne cosmique, la créature la plus spectaculaire du jeu.

Modélisé ailes déployées (membranes en plaques horizontales : peu de pièces), voxels de 0,4 stud : environ 28 studs
d'envergure à la taille Normal. Corps violet nuit parcouru de constellations Neon (étoiles blanches reliées par des
traits cyan) : une figure sur chaque flanc, une grande étoile sur le poitrail et un chemin d'étoiles sur l'arête de la
queue qui mène à une lame de cristal Neon en étoile à quatre branches. Grandes ailes de dragon attachées haut sur les
épaules, festonnées, aux membranes de nébuleuse (bandes violet, magenta et bleu) semées d'étoiles Neon blanches posées
sur la membrane (elles se voient aussi ailes repliées). Pics de cristal lilas (Glass) le long du dos, grandes cornes
dorées (Metal) balayées vers l'arrière en V, yeux Neon blanc cyan. Le cou et la tête sont modélisés droits devant (peu
de pièces) puis relevés par les rotations de repos ; la queue en segments effilés se relève vers la lame. Au parc il
marche replié sur ses pattes et ses poignets (les animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.4

BODY = (70, 44, 130)
BELLY = (128, 96, 196)
NEB1 = BODY                 # membrane : violet nuit (bord d'attaque, comme les os de l'aile)
NEB2 = (196, 52, 168)       # magenta
NEB3 = (56, 92, 214)        # bleu (bord de fuite)
STRUT = (52, 30, 96)
STAR = (240, 246, 255)
CONST = (150, 230, 255)     # traits des constellations
CRYSTAL = (214, 176, 255)
HORN = (255, 176, 48)
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

WY = 15                     # plan des ailes : haut des épaules
NY = 14                     # axe du cou et de la tête (modélisés à l'horizontale)
TY = 13                     # axe de la queue


def build():
    d = Dino("StarDragon", FAMILY, voxel=VOXEL, display="Star Dragon")
    # ---------------------------------------------------------------- os
    # cou relevé de 45 puis 60 degrés par les rotations de repos, tête ramenée à l'horizontale
    d.bone("Hips", (0, 12, 4))
    d.bone("Chest", (0, 12.5, -1), "Hips")
    d.bone("Neck1", (0, NY, -5.5), "Chest", rest=(45, 0, 0))
    d.bone("Neck2", (0, NY, -9.5), "Neck1", rest=(15, 0, 0))
    d.bone("Head", (0, NY, -13.0), "Neck2", rest=(-60, 0, 0))
    d.bone("Jaw", (0, NY - 0.4, -16.0), "Head")
    d.bone_pair("Lid", (-2.8, NY + 3, -18), "Head")
    d.bone_pair("Wing1", (-3, WY, -2), "Chest")
    d.bone_pair("Wing2", (-11, WY, -1), "Wing1L")
    d.bone_pair("Wing3", (-20, WY, -3), "Wing2L")
    d.bone_pair("Thigh", (-2.4, 11, 4.5), "Hips")
    d.bone_pair("Shin", (-2.8, 6.5, 2.5), "ThighL")
    d.bone_pair("Foot", (-2.8, 2.6, 5.0), "ShinL")
    tz = [8.0, 12.0, 16.0, 20.0, 24.0, 28.0]
    tr = [2.5, 2.0, 1.6, 1.2, 0.8]
    trest = [4, 0, -5, -7, -7]                                  # la queue s'abaisse puis se relève vers la lame
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, TY, tz[i]), "Hips" if i == 0 else f"Tail{i}", rest=(trest[i], 0, 0))

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- ailes (gauche), avant le corps qui recouvre leur racine
    # membrane : plaque horizontale festonnée entre trois baleines, partagée entre les os de l'aile selon x
    edge = [(-2.5, -1.5), (-11, -1.0), (-20, -2.5), (-35, 4.0), (-31.5, 5.8), (-28, 9.0), (-24, 8.0), (-20, 12.0),
            (-16, 9.6), (-12, 12.5), (-7, 10.2), (-3, 10.0), (-2.2, 7.0)]
    d.plate("Wing1L", 1, WY, edge, NEB1)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        b = "Wing3L" if x <= -21 else ("Wing2L" if x <= -12 else "Wing1L")
        # nébuleuse : violet devant, magenta au milieu, bleu au bord de fuite
        d.set(b, x, y, z, NEB1 if z <= 1 else (NEB2 if z <= 5 else NEB3))
    # baleines (doigts) sombres qui tiennent la membrane
    for xs, z0, z1, b in ((-12, 0, 13, "Wing2L"), (-20, -2, 12, "Wing2L"), (-28, 2, 9, "Wing3L")):
        for z in range(z0, z1 + 1):
            if (xs, WY, z) in d.vox:
                d.set(b, xs, WY, z, STRUT)
    # étoiles Neon posées sur la membrane (dessus : vers l'extérieur quand l'aile est repliée)
    for (x, z) in ((-6, 4), (-8, 8), (-15, 2), (-17, 7), (-24, 5), (-31, 4), (-14, 10)):
        if (x, WY, z) in d.vox:
            d.set(d.vox[(x, WY, z)][0], x, WY + 1, z, STAR, "Neon")
    # puis les os : bras, avant-bras, doigt-aile (bord d'attaque)
    d.limb("Wing1L", (-3, WY, -2), (-11, WY, -1), 1.3, 1.0, BODY)
    d.limb("Wing2L", (-11, WY, -1), (-20, WY, -3), 1.0, 0.8, BODY)
    d.limb("Wing3L", (-20, WY, -3), (-35, WY, 4), 0.7, 0.35, BODY)
    # griffe du poignet (vers l'avant) : elle touche le sol quand il marche
    d.box("Wing2L", (-21, WY, -5), (-20, WY, -4), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-20.5, WY, -4.6))
    d.point("WingTipL", "Wing3L", (-35, WY, 4))
    # ---------------------------------------------------------------- corps de wyverne
    d.ellipsoid("Chest", (0, 12.8, -2.0), (3.8, 4.0, 4.6), BODY, where=left, power=2.6)
    d.ellipsoid("Hips", (0, 12.4, 4.6), (3.4, 3.6, 4.0), BODY, where=left, power=2.6)
    # ---------------------------------------------------------------- cou en deux segments épais (droit devant)
    d.limb("Neck1", (0, NY, -5.5), (0, NY, -9.5), 2.5, 2.5, BODY, where=left)
    d.limb("Neck2", (0, NY, -9.5), (0, NY, -13.0), 2.3, 2.3, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête : crâne, museau en coin, mâchoire
    d.limb("Head", (0, NY, -13.0), (0, NY, -14.5), 2.3, 2.4, BODY, where=left)
    d.ellipsoid("Head", (0, NY + 1.8, -16.2), (3.0, 2.6, 3.4), BODY, where=lambda x, y, z: x <= 0 and y >= NY,
                power=2.8)
    d.ellipsoid("Head", (0, NY + 1.2, -21.0), (2.2, 1.8, 3.0), BODY, where=lambda x, y, z: x <= 0 and y >= NY,
                power=2.6)
    d.ellipsoid("Jaw", (0, NY - 0.6, -19.6), (2.0, 1.2, 4.0), BELLY, where=lambda x, y, z: x <= 0 and y <= NY - 1,
                power=2.6)
    for z in range(-22, -15):
        if (0, NY, z) in d.vox:
            d.set("Head", 0, NY, z, MOUTH)
        if (0, NY - 1, z) in d.vox:
            d.set("Jaw", 0, NY - 1, z, MOUTH)
    for z in (-23, -21):
        x = d.surface_x(NY, z, "Head")
        if x is not None:
            d.set("Head", x, NY, z, TOOTH, "Smooth")              # crocs
    if (-1, NY + 2, -23) in d.vox:
        d.set("Head", -1, NY + 2, -23, PUPIL, "Smooth")          # narine
    # grandes cornes dorées en V : elles montent puis filent vers l'arrière
    for a, b, ra, rb in (((-2.0, NY + 3.8, -14.6), (-3.0, NY + 5.8, -12.2), 1.15, 0.95),
                         ((-3.0, NY + 5.8, -12.2), (-3.8, NY + 6.8, -9.4), 0.95, 0.7),
                         ((-3.8, NY + 6.8, -9.4), (-4.2, NY + 7.0, -7.0), 0.7, 0.35)):
        d.limb("Head", a, b, ra, rb, HORN, "Metal")
    # ---------------------------------------------------------------- pattes arrière puissantes
    d.ellipsoid("ThighL", (-2.9, 9.8, 4.2), (1.9, 2.8, 2.4), BODY)
    d.limb("ShinL", (-2.8, 6.5, 2.5), (-2.8, 2.6, 5.0), 1.4, 1.1, BODY)
    d.limb("FootL", (-2.8, 2.6, 5.0), (-2.8, 0.7, 3.0), 1.1, 1.0, BODY)
    d.box("FootL", (-4, 0, 0), (-2, 0, 3), BODY)
    for x in (-4, -2):
        d.set("FootL", x, 0, -1, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, 0.5))
    # ---------------------------------------------------------------- longue queue en segments empilés effilés
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, TY, tz[i]), (0, TY, tz[i + 1]), tr[i], tr[i], BODY,
               where=lambda x, y, z, e=tz[i + 1]: x <= 0 and z <= e)
    # ---------------------------------------------------------------- pics de cristal lilas le long du dos
    # grands éclats translucides penchés vers l'arrière, du plus grand (épaules) au plus petit (queue)
    for bone, base, tip, r in (
            ("Chest", (0, 15.8, -3.2), (0, 21.4, -0.4), 1.3),
            ("Hips", (0, 15.0, 3.0), (0, 20.2, 5.8), 1.2),
            ("Tail1", (0, 14.6, 9.6), (0, 18.0, 11.6), 0.9)):
        d.limb(bone, base, tip, r, 0.3, CRYSTAL, "Glass")
    # ---------------------------------------------------------------- lame de cristal Neon en étoile au bout de la queue
    # étoile à quatre branches aux côtés creusés, dans deux plaques croisées (verticale et horizontale)
    cy, cz = TY, 31
    for a in range(-5, 6):
        for b in range(-5, 8):
            rb = 6.5 if b >= 0 else 4.6
            if (abs(a) / 4.8) ** (2 / 3) + (abs(b) / rb) ** (2 / 3) <= 1:
                d.set("Tail5", 0, cy + a, cz + b, BLADE, "Neon")
                if a <= 0 and (abs(a) / 3.8) ** (2 / 3) + (abs(b) / rb) ** (2 / 3) <= 1:
                    d.set("Tail5", a, cy, cz + b, BLADE, "Neon")
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", NY + 2, -19, IRIS, PUPIL, lid_color=BODY, h=1, w=3)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {}

    def paint(x, y, z, bone, c):
        if c == IRIS:
            return (IRIS, "Neon")
        if c == BODY and bone in belly and y <= belly[bone]:
            return BELLY
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- constellations Neon
    # étoiles blanches (les plus brillantes en croix) reliées par des traits cyan, en léger relief sur la peau des deux
    # côtés (la peau reste d'un seul tenant : peu de pièces) : une grande figure sur le flanc, une le long de la queue
    def put(y, z, col, bones):
        xs = [k[0] for k, v in d.vox.items() if k[1] == y and k[2] == z and v[0] in bones and v[1] == BODY]
        if xs:
            x = min(xs)
            for xx in (x - 1, 1 - x):
                d.set(d.vox[(x if xx < 0 else -x, y, z)][0], xx, y, z, col, "Neon")

    figures = [
        (("Chest", "Hips"), [(14, -3, 0), (12, -1, 0), (13, 3, 0), (14, 6, 0)]),
    ]
    for bones, pts in figures:
        for (y0, z0, _), (y1, z1, _) in zip(pts, pts[1:]):
            n = max(abs(y1 - y0), abs(z1 - z0))
            for i in range(1, n):
                put(round(y0 + (y1 - y0) * i / n), round(z0 + (z1 - z0) * i / n), CONST, bones)
        for y, z, big in pts:
            put(y, z, STAR, bones)
            if big:
                for dy, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    put(y + dy, z + dz, STAR, bones)
    # chemin d'étoiles sur le dessus de la queue : un trait cyan le long de l'arête, des étoiles blanches en relief,
    # jusqu'à la lame en étoile
    tail = ("Tail2", "Tail3", "Tail4", "Tail5")
    for z in range(12, 29):
        ys = [k[1] for k, v in d.vox.items() if k[0] == 0 and k[2] == z and v[0] in tail and v[1] == BODY]
        if ys:
            d.set(d.vox[(0, max(ys), z)][0], 0, max(ys), z, CONST, "Neon")
    for z in (13, 19, 24):
        ys = [k[1] for k, v in d.vox.items() if k[0] == 0 and k[2] == z and v[0] in tail]
        if ys:
            y = max(ys)
            b = d.vox[(0, y, z)][0]
            d.set(b, 0, y, z, STAR, "Neon")
            d.set(b, 0, y + 1, z, STAR, "Neon")
            for xx in (-1, 1):
                d.set(b, xx, y, z, STAR, "Neon")
    # grande étoile du poitrail, en relief : elle se voit de face quand il se dresse
    for x, y in ((0, 10), (-1, 10), (1, 10), (0, 9), (0, 11)):
        zs = [k[2] for k, v in d.vox.items() if k[0] == x and k[1] == y and v[0] == "Chest"]
        if zs:
            d.set("Chest", x, y, min(zs) - 1, STAR, "Neon")
    return d
