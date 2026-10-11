"""Liopleurodon : nageur de l'Ocean Trench (Legendary), le pliosaure massif, terreur des mers jurassiques.

Voxels de 0,41 stud : environ 24 studs de long à la taille Normal, 15 d'envergure (nageoires). Tête énorme (un quart
du corps) au crâne haut derrière les yeux, longue gueule bordée de dents coniques blanches qui s'entrecroisent et de
crocs en rosette au bout du museau, cou court et épais, corps en goutte d'eau, quatre grandes nageoires-palettes
(dessus ardoise, dessous pâle) et queue courte terminée par une petite nageoire en losange. Dos ardoise bleu nuit,
ventre pâle moucheté d'ardoise, oeil ambre sous une arcade sourcilière. Neck1 = le cou court entre crâne et poitrail."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.41

BACK = (44, 55, 78)
DARK = (28, 35, 52)
BELLY = (214, 218, 210)
SPECK = (92, 104, 128)
FIN = (37, 47, 68)
TOOTH = (252, 250, 242)
GAP = (70, 24, 30)
MOUTH = (172, 64, 76)
IRIS = (255, 176, 56)
PUPIL = (20, 14, 12)

TEETH_END = -23
BELLY_LINE = 1.6
SPECK_N = 5

PERSONALITY = {
    "tempo": 0.85,          # massif : battements amples et puissants
    "weight": 1.4,
    "tail": 0.7,
    "diet": "fish",
    "happy": "roll",
    "catch": "ram",
}


def catmull(pts, z, j):
    for i in range(len(pts) - 1):
        z0, z1 = pts[i][0], pts[i + 1][0]
        if z0 <= z <= z1:
            p0 = pts[max(0, i - 1)][j]
            p1, p2 = pts[i][j], pts[i + 1][j]
            p3 = pts[min(len(pts) - 1, i + 2)][j]
            t = (z - z0) / (z1 - z0)
            return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
    return None


def loft(d, pts, bone_at, color, power=2.0):
    """Corps profilé : à chaque z, une section (centre cy, demi-hauteurs dessus/dessous, demi-largeur rx et, en option,
    l'exposant de la section : 2 = ellipse, plus = plus carré)."""
    for z in range(math.ceil(pts[0][0]), math.floor(pts[-1][0]) + 1):
        cy, top, bot, rx = (catmull(pts, z, j) for j in (1, 2, 3, 4))
        if len(pts[0]) > 5:
            power = catmull(pts, z, 5)
        for y in range(math.floor(cy - bot) - 1, math.ceil(cy + top) + 2):
            dy = y - cy
            ry = max(0.3, top if dy >= 0 else bot)
            for x in range(-math.ceil(rx) - 1, 1):
                if (abs(x) / max(rx, 0.3)) ** power + (abs(dy) / ry) ** power <= 1.0:
                    b = bone_at(x, y, z)
                    if b:
                        d.set(b, x, y, z, color)


def socket_eye(d, ey, ez, h, w, iris, pupil, skin, ring, ring_top=None, pupil_rows=None, bone="Head", lid="LidL"):
    """Oeil gauche dans une orbite : oeil et paupière sur un panneau plat (même x, la paupière couvre bien l'oeil en se
    fermant), cadre en relief d'un voxel tout autour (anneau `ring` autour de l'oeil, `ring_top` au-dessus), et creux
    derrière la paupière (quand elle descend, on voit la peau `skin` et pas les voxels cachés du crâne)."""
    cells = [(y, z) for y in range(ey, ey + 2 * h) for z in range(ez, ez + w)]
    xe = min(d.surface_x(y, z) for y, z in cells if d.surface_x(y, z) is not None)
    for y, z in cells:
        xs = d.surface_x(y, z)
        for x in range(xe, xs if xs is not None else xe + 1):
            d.set(bone, x, y, z, skin)
    d.eye(bone, lid, ey, ez, iris, pupil, lid_color=skin, h=h, w=w, pupil_rows=pupil_rows)
    for y in range(ey, ey + h):
        for z in range(ez, ez + w):
            d.clear(xe + 1, y, z)                      # creux derrière l'oeil : ses boîtes restent à sa surface
    frame = [(ey - 1, z) for z in range(ez - 1, ez + w + 1)] + [(y, z) for y in range(ey, ey + h) for z in (ez - 1, ez + w)]
    top = [(y, z) for y in range(ey + h, ey + 2 * h) for z in (ez - 1, ez + w)] + [(ey + 2 * h, z) for z in range(ez - 1, ez + w + 1)]
    for cells2, col in ((frame, ring), (top, ring_top or skin)):
        for y, z in cells2:
            xs = d.surface_x(y, z)
            if xs is None:
                continue
            for x in range(min(xe - 1, xs), xs + 1):
                d.set(bone, x, y, z, col)
    for (x, y, z), (b, col, mat) in list(d.vox.items()):
        if b == lid and (x + 1, y, z) in d.vox and d.vox[(x + 1, y, z)][0] != lid:
            del d.vox[(x + 1, y, z)]
            if (x + 2, y, z) in d.vox:
                d.vox[(x + 2, y, z)] = (d.vox[(x + 2, y, z)][0], skin, "Plastic")


def seal_joint(d, child, parent):
    """Creux d'une tranche dans l'os enfant, sous la peau, contre l'os parent : à la fusion des boîtes, les détails
    (yeux, dents, bouche) ne peuvent plus s'étendre jusqu'à l'articulation, qui garde la couleur de la peau quand
    l'os tourne."""
    cut = []
    for (x, y, z), (b, c, m) in d.vox.items():
        if b == child and not d.visible((x, y, z)):
            if any(d.vox.get((x + dx, y + dy, z + dz), (None,))[0] == parent
                   for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))):
                cut.append((x, y, z))
    for k in cut:
        del d.vox[k]


def mouth_slot(d, color, rows):
    """Fente fermée entre les mâchoires : on retire les voxels cachés de la rangée haute de Jaw (sous Head), sur les
    rangées `rows` ; le plancher et le palais qui la bordent (eux aussi cachés de l'extérieur) prennent la couleur de
    la bouche, visible seulement quand la gueule s'ouvre."""
    nb = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    slot = {k for k, (b, c, m) in d.vox.items() if k[1] in rows and b == "Jaw" and not d.visible(k)
            and d.vox.get((k[0], k[1] + 1, k[2]), (None,))[0] == "Head"}
    for k in slot:
        del d.vox[k]
    for x, y, z in slot:
        for k in ((x, y - 1, z), (x, y + 1, z), (x, y, z - 1), (x, y, z + 1)):
            if k in d.vox and all((k[0] + a, k[1] + b, k[2] + c) in d.vox or (k[0] + a, k[1] + b, k[2] + c) in slot
                                  for a, b, c in nb):
                d.vox[k] = (d.vox[k][0], color, "Plastic")


def lift(d, bone, rise):
    """Relève une nageoire vers son bout (dièdre) : chaque colonne x monte de rise(x) voxels."""
    moved = {}
    for k, v in list(d.vox.items()):
        if v[0] == bone and rise(k[0]):
            del d.vox[k]
            moved[(k[0], k[1] + rise(k[0]), k[2])] = v
    d.vox.update(moved)


def speck(x, y, z, n):
    """Mouchetures régulières mais sans motif visible : vrai pour environ un voxel sur n."""
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
    return (h >> 4) % n == 0


def build():
    d = Dino("Liopleurodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.1, 2.0))
    d.bone("Chest", (0, 9.0, 1.5), "Hips")
    d.bone("Neck1", (0, 9.0, -12.5), "Chest")
    d.bone("Head", (0, 9.0, -16.0), "Neck1")
    d.bone("Jaw", (0, 8.6, -17.0), "Head")
    d.bone_pair("Lid", (-6.4, 14.0, -19.5), "Head")
    d.bone_pair("FinF1", (-5.0, 3.8, -7.5), "Chest")
    d.bone_pair("FinF2", (-11.0, 3.8, -6.2), "FinF1L")
    d.bone_pair("FinB1", (-3.6, 4.2, 7.5), "Hips")
    d.bone_pair("FinB2", (-9.5, 4.2, 8.5), "FinB1L")
    tz = [10.5, 13.5, 16.0, 18.5, 20.5]
    for i, z in enumerate(tz):
        d.bone(f"Tail{i + 1}", (0, 9.4 + 0.03 * i, z), "Hips" if i == 0 else f"Tail{i}")

    def mouth_y(z):
        """Rangée de la ligne de la gueule (elle remonte un peu vers l'arrière)."""
        return 6 if z <= -30 else (7 if z <= -25 else (8 if z <= -21 else 9))

    def bone_at(x, y, z):
        if z < -16:
            return "Jaw" if y <= mouth_y(z) and z <= -17 else "Head"
        if z < -12.5:
            return "Neck1"
        if z < 1.0:
            return "Chest"
        if z < tz[0]:
            return "Hips"
        for i in range(len(tz) - 1, -1, -1):
            if z >= tz[i]:
                return f"Tail{i + 1}"
        return "Hips"

    # ---------------------------------------------------------------- tête énorme, cou court, corps en goutte d'eau
    #          z     cy   dessus dessous  demi-largeur
    prof = [(-33.0, 6.5, 2.4, 2.2, 3.0, 2.5),
            (-30.0, 6.8, 3.2, 3.0, 3.8, 2.5),
            (-26.0, 7.4, 4.4, 4.0, 4.8, 2.5),
            (-22.0, 8.0, 5.6, 5.2, 5.9, 2.5),
            (-18.5, 8.6, 6.6, 6.2, 6.8, 2.5),
            (-16.0, 8.8, 6.6, 6.4, 6.8, 2.4),
            (-13.5, 8.7, 5.6, 5.4, 6.2, 2.2),
            (-8.0, 8.6, 7.2, 7.4, 7.2, 2.0),
            (-2.0, 8.6, 7.4, 7.8, 7.4, 2.0),
            (4.0, 8.7, 6.6, 6.9, 6.6, 2.0),
            (9.5, 9.0, 4.6, 4.6, 4.6, 2.0),
            (13.5, 9.3, 2.9, 2.9, 3.0, 2.0),
            (17.0, 9.4, 1.9, 1.9, 1.9, 2.0),
            (20.0, 9.4, 1.2, 1.2, 1.2, 2.0),
            (22.0, 9.4, 0.8, 0.8, 0.8, 2.0)]
    loft(d, prof, bone_at, BACK)
    # ---------------------------------------------------------------- gueule : dents en quinconce dans la fente sombre
    # rangée m+1 (Head) : dents du haut ; rangée m (Jaw) : dents du bas ; les autres cases sont la gorge sombre
    for z in range(-33, -16):
        m = mouth_y(z)
        for y, bone, par in ((m + 1, "Head", 0), (m, "Jaw", 1)):
            x = d.surface_x(y, z, bone)
            if x is None:
                continue
            tooth = z <= TEETH_END and z % 2 == par
            d.set(bone, x, y, z, TOOTH if tooth else GAP, "Smooth" if tooth else "Plastic")
    # crocs en rosette au bout du museau, qui débordent vers l'avant
    m = mouth_y(-33)
    d.set("Head", -1, m + 1, -34, TOOTH, "Smooth")
    d.set("Jaw", -2, m, -34, TOOTH, "Smooth")
    # ---------------------------------------------------------------- nageoires-palettes
    d.plate("FinF1L", 1, 3, [(-3.0, -10.5), (-11.0, -9.0), (-11.0, -3.5), (-3.0, -5.0)], FIN, thick=2)
    d.plate("FinF2L", 1, 3, [(-11.0, -9.0), (-16.0, -6.5), (-19.5, -2.5), (-18.0, -1.2), (-11.0, -3.5)], FIN, thick=2)
    d.plate("FinB1L", 1, 4, [(-2.0, 5.0), (-9.5, 6.0), (-9.5, 11.0), (-2.0, 10.0)], FIN, thick=2)
    d.plate("FinB2L", 1, 4, [(-9.5, 6.0), (-14.0, 8.8), (-16.5, 13.0), (-15.0, 13.8), (-9.5, 11.0)], FIN, thick=2)
    for b in ("FinF1L", "FinF2L"):
        lift(d, b, lambda x: (x <= -9) + (x <= -15))
    for b in ("FinB1L", "FinB2L"):
        lift(d, b, lambda x: (x <= -9) + (x <= -13))
    # ---------------------------------------------------------------- oeil ambre sous une arcade
    socket_eye(d, 11, -20, 2, 2, IRIS, PUPIL, BACK, BACK, ring_top=BACK, pupil_rows=[0])
    d.mirror()
    mouth_slot(d, MOUTH, (6, 7, 8, 9))
    seal_joint(d, "Head", "Neck1")

    # ---------------------------------------------------------------- ventre pâle moucheté, dos ardoise
    def paint(x, y, z, bone, c):
        if c != BACK or bone.startswith("Fin"):
            return None
        zz = min(max(z, prof[0][0]), prof[-1][0])
        cy = catmull(prof, zz, 1)
        body = cy - BELLY_LINE                          # corps : ventre pâle jusqu'à mi-flanc
        head = cy - catmull(prof, zz, 3) + 1.4          # tête sombre : seul le dessous de la mâchoire est pâle
        t = min(1.0, max(0.0, (z + 17.0) / 8.0))        # de la gorge au poitrail, la limite remonte en pente douce
        line = head + (body - head) * t
        if y <= line:
            trunk = bone in ("Chest", "Hips", "Neck1") or bone.startswith("Tail")
            return SPECK if trunk and y >= line - 3 and speck(x, y, z, SPECK_N) else BELLY
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- petite nageoire de queue en losange
    d.plate("Tail5", 0, 0, [(9.5, 19.6), (12.8, 22.4), (9.5, 25.2), (6.2, 22.4)], FIN)
    return d
