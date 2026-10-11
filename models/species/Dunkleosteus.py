"""Dunkleosteus : nageur de l'Ocean Trench (Epic), poisson cuirassé du Dévonien, mâchoires de cisaille.

Voxels de 0,33 stud : environ 16 studs de long à la taille Normal. Tête et épaules dans une cuirasse de plaques
bronze-gris aux joints sombres (casque un voxel plus large que le corps, rebord net derrière les épaules), petit oeil
jaune dans une orbite cerclée, mâchoires en lames osseuses ivoire sans dents avec les crocs du « bec » à l'avant
(deux en haut, un en bas qui s'emboîtent), corps de requin olive-gris au ventre pâle, aileron dorsal, nageoires
pectorales en triangle, queue de requin (lobe haut plus long). Neck1 = la cuirasse des épaules, derrière l'articulation
du crâne (la tête se lève comme chez le vrai Dunkleosteus)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.33

ARMOR = (156, 132, 92)
RIM = (112, 94, 66)
SEAM = (62, 46, 36)
BODY = (122, 126, 92)
BELLY = (226, 224, 204)
ARMOR_BELLY = (200, 184, 146)
FIN = (88, 92, 64)
BLADE = (232, 220, 188)
MOUTH = (56, 30, 30)
IRIS = (255, 196, 64)
PUPIL = (20, 16, 14)

PERSONALITY = {
    "tempo": 0.9,           # lourd et cuirassé, mais rapide à l'attaque
    "weight": 1.3,
    "tail": 1.0,
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
    (yeux, lames, bouche) ne peuvent plus s'étendre jusqu'à l'articulation, qui garde la couleur de la peau quand
    l'os tourne."""
    cut = []
    for (x, y, z), (b, c, m) in d.vox.items():
        if b == child and not d.visible((x, y, z)):
            if any(d.vox.get((x + dx, y + dy, z + dz), (None,))[0] == parent
                   for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))):
                cut.append((x, y, z))
    for k in cut:
        del d.vox[k]


def build():
    d = Dino("Dunkleosteus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 7.4, 2.0))
    d.bone("Chest", (0, 7.4, 1.5), "Hips")
    d.bone("Neck1", (0, 8.0, -7.0), "Chest")
    d.bone("Head", (0, 9.0, -12.0), "Neck1")
    d.bone("Jaw", (0, 6.6, -13.5), "Head")
    d.bone_pair("Lid", (-4.0, 12.0, -17.0), "Head")
    d.bone_pair("FinF1", (-4.4, 3.6, -3.0), "Chest")
    d.bone_pair("FinF2", (-8.0, 3.6, -1.4), "FinF1L")
    d.bone_pair("FinB1", (-2.6, 4.4, 7.2), "Hips")
    d.bone_pair("FinB2", (-4.6, 4.4, 8.4), "FinB1L")
    tz = [8.5, 11.5, 14.5, 17.5, 20.0]
    for i, z in enumerate(tz):
        d.bone(f"Tail{i + 1}", (0, 7.8 + 0.15 * i, z), "Hips" if i == 0 else f"Tail{i}")

    def bone_at(x, y, z):
        if z < -12:
            return "Jaw" if (y <= 6 and z < -13) else "Head"
        if z < -7:
            return "Neck1"
        if z < 1.5:
            return "Chest"
        if z < tz[0]:
            return "Hips"
        for i in range(len(tz) - 1, -1, -1):
            if z >= tz[i]:
                return f"Tail{i + 1}"
        return "Hips"

    # ---------------------------------------------------------------- corps de requin (profil lissé)
    #          z     cy   dessus dessous  demi-largeur
    body = [(-6.0, 7.3, 4.8, 4.4, 4.2),
            (-2.0, 7.3, 4.6, 4.2, 4.0),
            (1.5, 7.4, 4.2, 3.9, 3.7),
            (5.0, 7.6, 3.5, 3.2, 3.1),
            (9.0, 7.8, 2.7, 2.4, 2.4),
            (13.0, 8.0, 2.0, 1.8, 1.8),
            (17.0, 8.2, 1.4, 1.3, 1.3),
            (20.0, 8.4, 1.1, 1.0, 1.0),
            (21.5, 8.5, 0.9, 0.9, 0.8)]
    loft(d, body, bone_at, BODY)
    # ---------------------------------------------------------------- cuirasse : tête et épaules, un voxel plus large
    armor = [(-22.6, 7.2, 3.6, 3.3, 3.3),
             (-21.0, 7.4, 4.5, 4.0, 4.1),
             (-18.0, 7.5, 5.1, 4.4, 4.6),
             (-14.0, 7.5, 5.8, 4.8, 5.0),
             (-10.0, 7.4, 6.4, 5.1, 5.2),
             (-6.0, 7.3, 6.4, 5.2, 5.1),
             (-2.6, 7.3, 5.6, 5.0, 4.9)]
    loft(d, armor, bone_at, ARMOR, power=2.4)
    # ---------------------------------------------------------------- bouche : rainure fermée (intérieur sombre)
    for z in range(-21, -13):
        for x in range(-2, 1):
            if (x, 6, z) in d.vox and (x, 5, z) in d.vox and (x - 1, 6, z) in d.vox:
                d.clear(x, 6, z)
                d.set("Head", x, 7, z, MOUTH)
                d.set("Jaw", x, 5, z, MOUTH)

    def ring(z0, ymin=0):
        """Joint de plaques tout autour de la cuirasse (anneau sombre d'un voxel), sur la surface."""
        for (x, y, z), (bone, col, mat) in list(d.vox.items()):
            if z == z0 and y >= ymin and col == ARMOR and d.visible((x, y, z)):
                d.set(bone, x, y, z, SEAM)

    # ---------------------------------------------------------------- joints de la cuirasse : casque | épaules | dos
    # crête de la grande plaque dorsale (au milieu du dos de la cuirasse)
    for z in range(-11, -2):
        y = d.surface_y(0, z)
        if y is not None:
            d.set("Neck1" if z < -7 else "Chest", 0, y + 1, z, ARMOR)
            if z < -4:
                d.set("Neck1" if z < -7 else "Chest", 0, y + 2, z, ARMOR)
    ring(-12, 7)                                         # articulation crâne / épaules
    ring(-7, 8)                                          # entre les deux plaques d'épaule (dessus)
    # ---------------------------------------------------------------- bouche : fente sombre, lames ivoire, bec à crocs
    for z in range(-24, -13):
        x = d.surface_x(7, z)
        if x is None:
            continue
        if z <= -21:
            d.set("Head", x, 7, z, BLADE, "Smooth")          # crocs du haut (devant)
        elif z == -20:
            d.set("Jaw", x, 7, z, BLADE, "Smooth")           # croc du bas, s'emboîte derrière
        else:
            d.set("Head", x, 7, z, MOUTH)
        if z <= -16:
            x = d.surface_x(8, z)
            if x is not None and d.vox[(x, 8, z)][0] == "Head":
                d.set("Head", x, 8, z, BLADE, "Smooth")      # lame du haut
            x = d.surface_x(6, z)
            if x is not None and d.vox[(x, 6, z)][0] == "Jaw":
                d.set("Jaw", x, 6, z, BLADE, "Smooth")       # lame du bas
    # face avant : le bec (lames en haut et en bas, fente sombre, une paire de crocs de chaque mâchoire)
    for x in range(-4, 1):
        for y in (6, 7, 8):
            zs = [k[2] for k in d.vox if k[0] == x and k[1] == y]
            if not zs:
                continue
            z = min(zs)
            if y == 8 and x >= -2:
                d.set("Head", x, y, z, BLADE, "Smooth")
            elif y == 6 and x >= -2:
                d.set("Jaw", x, y, z, BLADE, "Smooth")
            elif y == 7:
                if x == -1:
                    d.set("Head", x, y, z, BLADE, "Smooth")  # crocs du haut
                else:
                    d.set("Head", x, y, z, MOUTH)
    # le bec dépasse d'un voxel devant le museau
    for x in range(-2, 1):
        for y in (6, 7, 8):
            zs = [k[2] for k in d.vox if k[0] == x and k[1] == y]
            if zs:
                z = min(zs) - 1
                if y == 7:
                    d.set("Head", x, y, z, BLADE if x == -1 else MOUTH, "Smooth" if x == -1 else "Plastic")
                else:
                    d.set("Head" if y == 8 else "Jaw", x, y, z, BLADE, "Smooth")
    # ---------------------------------------------------------------- orbite en relief et oeil jaune
    socket_eye(d, 10, -18, 2, 2, IRIS, PUPIL, ARMOR, ARMOR, pupil_rows=[0])
    # ---------------------------------------------------------------- nageoires (plaques)
    d.plate("FinF1L", 1, 3, [(-4.0, -4.6), (-8.0, -3.0), (-8.0, 0.4), (-4.0, -0.6)], FIN, thick=2)
    d.plate("FinF2L", 1, 3, [(-8.0, -3.0), (-11.8, 1.6), (-10.6, 2.6), (-8.0, 0.4)], FIN, thick=2)
    d.plate("FinB1L", 1, 4, [(-2.2, 6.4), (-4.6, 7.4), (-4.6, 9.4), (-2.2, 9.0)], FIN)
    d.plate("FinB2L", 1, 4, [(-4.6, 7.4), (-6.4, 9.4), (-6.0, 10.4), (-4.6, 9.4)], FIN)
    d.mirror()
    seal_joint(d, "Head", "Neck1")
    # ---------------------------------------------------------------- ventre pâle coupé à plat
    def paint(x, y, z, bone, c):
        if c == BODY and y <= 5:
            return BELLY
        if c == ARMOR and bone in ("Chest", "Neck1", "Jaw") and y <= 3:
            return ARMOR_BELLY
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- queue de requin (lobe haut plus long) et aileron
    d.plate("Tail5", 0, 0, [(9.0, 19.4), (12.4, 21.6), (16.4, 25.2), (15.6, 26.0), (12.0, 24.0), (9.6, 22.8),
                            (7.6, 23.0), (4.6, 24.4), (3.8, 23.6), (6.0, 21.2), (7.6, 19.4)], FIN)
    d.plate("Chest", 0, 0, [(11.0, -2.0), (14.0, 0.0), (17.4, 3.4), (17.0, 4.2), (14.6, 3.8), (12.4, 5.0), (11.0, 5.0)], FIN)
    return d
