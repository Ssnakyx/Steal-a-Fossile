"""Helicoprion : nageur de l'Ocean Trench (Legendary), le requin à la scie en spirale.

Voxels de 0,38 stud : environ 18 studs de long à la taille Normal. Corps de requin fuselé bleu-gris profond, ventre blanc
coupé à plat, grand oeil cyan pâle des grands fonds, cinq ouïes, deux ailerons dorsaux, grandes pectorales et queue de
requin (lobe haut plus long), toutes les nageoires à bout noir. La mâchoire inférieure (os Jaw) est une lame étroite
dont l'avant est la célèbre spirale de dents : un disque plat sombre où s'enroule une ligne de dents blanches, bordé de
dents en scie, qui dépasse sous le menton. Neck1 = la région des ouïes."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.355

BACK = (58, 76, 102)
BELLY = (236, 238, 240)
TIP = (24, 26, 32)
GILL = (34, 44, 60)
GUM = (30, 36, 50)
TOOTH = (252, 250, 242)
MOUTH = (150, 70, 84)
IRIS = (150, 224, 232)
PUPIL = (16, 20, 28)

WHORL = (2.4, -20.2, 4.6)      # centre y, z et rayon du disque de la spirale
KEEL = (0.2, 0.5)              # bord inférieur de la quille : hauteur sous le centre du disque, pente vers la gorge
SPIRAL = (2.7, 1.6, 2.4)       # pas, tours, rotation
RIM = (11, 7.0)                # dents du bord : nombre, demi-largeur (degrés)
RIM_ROT = 0.0
RIM_X = (0,)
RAISED = False

PERSONALITY = {
    "tempo": 1.0,           # requin souple et rapide
    "weight": 1.1,
    "tail": 1.2,
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
    """Corps profilé : à chaque z, une section (centre cy, demi-hauteurs dessus/dessous, demi-largeur rx)."""
    for z in range(math.ceil(pts[0][0]), math.floor(pts[-1][0]) + 1):
        cy, top, bot, rx = (catmull(pts, z, j) for j in (1, 2, 3, 4))
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


def spiral_cells(r0, spacing, turns, rot=0.0):
    """Ligne continue (4-connexe) d'une spirale d'Archimède tracée voxel par voxel : [(dy, dz)] du centre vers le bord."""
    k = spacing / (2 * math.pi)
    pts = []
    th = 0.0
    while th <= turns * 2 * math.pi:
        r = r0 + k * th
        p = (round(r * math.sin(th + rot)), round(r * math.cos(th + rot)))
        if not pts or pts[-1] != p:
            if pts and abs(pts[-1][0] - p[0]) == 1 and abs(pts[-1][1] - p[1]) == 1:
                pts.append((pts[-1][0], p[1]))         # coin ajouté : la ligne reste d'un seul tenant
            pts.append(p)
        th += 0.01
    return pts


def mouth_slot(d, color, y=6):
    """Fente fermée entre les mâchoires : on retire les voxels cachés de la rangée haute de Jaw (sous Head) ; le
    plancher et le palais qui la bordent (eux aussi cachés de l'extérieur) prennent la couleur de la bouche, visible
    seulement quand la gueule s'ouvre."""
    nb = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    slot = {k for k, (b, c, m) in d.vox.items() if k[1] == y and b == "Jaw" and not d.visible(k)
            and d.vox.get((k[0], y + 1, k[2]), (None,))[0] == "Head"}
    for k in slot:
        del d.vox[k]
    for x, _, z in slot:
        for k in ((x, y - 1, z), (x, y + 1, z)):
            if k in d.vox and all((k[0] + a, k[1] + b, k[2] + c) in d.vox or (k[0] + a, k[1] + b, k[2] + c) in slot
                                  for a, b, c in nb):
                d.vox[k] = (d.vox[k][0], color, "Plastic")


def fin(d, bone, axis, level, poly, split, thick=1):
    """Nageoire en plaque, bout noir : split(a, b) -> True pour la partie noire (coordonnées du plan de la plaque)."""
    d.plate(bone, axis, level, poly, BACK, thick=thick)
    others = [i for i in range(3) if i != axis]
    for k, (b, c, m) in list(d.vox.items()):
        if b == bone and c == BACK and level <= k[axis] < level + thick and split(k[others[0]], k[others[1]]):
            d.vox[k] = (b, TIP, m)


def build():
    d = Dino("Helicoprion", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 8.6, 1.5))
    d.bone("Chest", (0, 8.6, 1.0), "Hips")
    d.bone("Neck1", (0, 8.4, -9.0), "Chest")
    d.bone("Head", (0, 8.4, -13.5), "Neck1")
    d.bone("Jaw", (0, 6.5, -13.5), "Head")
    d.bone_pair("Lid", (-3.0, 12.0, -19.0), "Head")
    d.bone_pair("FinF1", (-3.4, 4.6, -8.0), "Chest")
    d.bone_pair("FinF2", (-7.6, 4.6, -6.0), "FinF1L")
    d.bone_pair("FinB1", (-2.6, 5.2, 5.0), "Hips")
    d.bone_pair("FinB2", (-4.6, 5.2, 6.2), "FinB1L")
    tz = [7.0, 10.5, 13.5, 16.5, 19.0]
    for i, z in enumerate(tz):
        d.bone(f"Tail{i + 1}", (0, 8.8 + 0.12 * i, z), "Hips" if i == 0 else f"Tail{i}")

    def bone_at(x, y, z):
        if z < -13:
            return "Jaw" if y <= 6 else "Head"
        if z < -9:
            return "Neck1"
        if z < 1:
            return "Chest"
        if z < tz[0]:
            return "Hips"
        for i in range(len(tz) - 1, -1, -1):
            if z >= tz[i]:
                return f"Tail{i + 1}"
        return "Hips"

    # ---------------------------------------------------------------- corps de requin fuselé
    #          z     cy   dessus dessous  demi-largeur
    prof = [(-25.6, 8.2, 0.8, 0.7, 0.7),
            (-23.5, 8.2, 2.2, 1.9, 2.0),
            (-19.5, 8.3, 3.6, 3.3, 3.1),
            (-14.5, 8.3, 4.4, 4.6, 3.8),
            (-9.0, 8.3, 4.8, 5.2, 4.2),
            (-3.0, 8.4, 4.6, 5.0, 4.0),
            (3.0, 8.6, 4.0, 4.2, 3.4),
            (8.0, 8.8, 3.0, 3.1, 2.6),
            (12.0, 9.0, 2.2, 2.2, 1.9),
            (16.0, 9.2, 1.5, 1.5, 1.3),
            (19.0, 9.3, 1.1, 1.1, 0.9),
            (20.5, 9.4, 0.9, 0.9, 0.7)]
    loft(d, prof, bone_at, BACK)
    # ---------------------------------------------------------------- spirale de dents sous la mâchoire (lame étroite)
    yc, zc, R = WHORL
    for z in range(-27, -13):
        for y in range(-6, 7):
            if (-1, y, z) in d.vox or (0, y, z) in d.vox:
                continue
            r = math.hypot(y - yc, z - zc)
            in_disc = r <= R + 0.25
            in_keel = z >= zc and y >= KEEL[0] + (z - zc) * KEEL[1]   # quille : rejoint la gorge en pente
            if in_disc or in_keel:
                for x in (-1, 0):
                    d.set("Jaw", x, y, z, GUM if in_disc else BACK)
    # ligne de dents enroulée sur les deux faces du disque, dents en scie sur le bord
    for dy, dz in spiral_cells(0.0, SPIRAL[0], SPIRAL[1], rot=SPIRAL[2]):
        y, z = round(yc + dy), round(zc + dz)
        if d.vox.get((-1, y, z), (None, None))[1:2] == (GUM,) and (-2, y, z) not in d.vox:
            d.set("Jaw", -1, y, z, TOOTH, "Smooth")
    n, tw = RIM
    for z in range(-27, -13):
        for y in range(-7, 6):
            r = math.hypot(y - yc, z - zc)
            if R + 0.25 < r <= R + 1.25 and (0, y, z) not in d.vox and (-1, y, z) not in d.vox:
                a = math.degrees(math.atan2(y - yc, z - zc)) - RIM_ROT
                if abs((a + 180.0 / n) % (360.0 / n) - 180.0 / n) <= tw:
                    for x in RIM_X:
                        d.set("Jaw", x, y, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- nageoires à bout noir
    fin(d, "FinF1L", 1, 4, [(-3.0, -10.4), (-7.6, -8.4), (-7.6, -4.4), (-3.0, -5.6)], lambda x, z: False, thick=2)
    fin(d, "FinF2L", 1, 4, [(-7.6, -8.4), (-12.6, -3.6), (-11.4, -2.4), (-7.6, -4.4)], lambda x, z: x <= -10, thick=2)
    fin(d, "FinB1L", 1, 5, [(-2.2, 4.0), (-4.6, 5.0), (-4.6, 7.4), (-2.2, 7.0)], lambda x, z: False)
    fin(d, "FinB2L", 1, 5, [(-4.6, 5.0), (-6.8, 7.4), (-6.2, 8.4), (-4.6, 7.4)], lambda x, z: x <= -6)
    # ---------------------------------------------------------------- grand oeil cyan pâle, ouïes
    socket_eye(d, 9, -20, 2, 2, IRIS, PUPIL, BACK, BACK, pupil_rows=[0])
    for z, hi in ((-13, 11), (-11, 11), (-9, 11), (-7, 10)):
        for y in range(6, hi):
            x = d.surface_x(y, z)
            if x is not None:
                d.set(d.vox[(x, y, z)][0], x, y, z, GILL)
    d.mirror()
    mouth_slot(d, MOUTH)
    seal_joint(d, "Head", "Neck1")
    # ---------------------------------------------------------------- ventre blanc coupé à plat
    def paint(x, y, z, bone, c):
        if c != BACK or bone.startswith("Fin"):
            return None
        cy = catmull(prof, min(max(z, prof[0][0]), prof[-1][0]), 1)
        if y <= cy - 1.6:
            return BELLY
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- ailerons (plaques verticales) et queue
    fin(d, "Chest", 0, 0, [(12.0, -7.0), (15.0, -5.2), (19.4, -1.6), (19.0, -0.6), (16.0, -0.6), (13.6, 0.8), (12.0, 0.8)],
        lambda y, z: y >= 17)
    fin(d, "Tail1", 0, 0, [(10.6, 9.0), (12.4, 10.0), (14.0, 12.2), (13.4, 12.8), (11.6, 12.4), (10.6, 12.8)],
        lambda y, z: y >= 13)
    fin(d, "Tail1", 0, 0, [(6.8, 8.2), (4.4, 9.6), (3.8, 10.6), (4.6, 10.8), (6.8, 10.6)], lambda y, z: y <= 4.6)
    fin(d, "Tail5", 0, 0, [(10.0, 18.6), (13.4, 20.6), (18.6, 24.6), (17.8, 25.4), (13.6, 23.0), (10.8, 22.0),
                           (9.0, 22.0), (6.2, 23.6), (4.8, 23.2), (7.0, 20.6), (8.4, 18.6)],
        lambda y, z: y >= 16 or y <= 6)
    return d
