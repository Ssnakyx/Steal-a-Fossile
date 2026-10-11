"""Ichthyosaurus : nageur de l'Ocean Trench (Epic), reptile-dauphin vif et curieux.

Voxels de 0,28 stud : environ 13 studs de long à la taille Normal (nageoire de queue comprise), 4 de haut avec l'aileron.
Corps en fuseau de dauphin, museau long et fin bordé de petites dents, très grand oeil cerclé d'un anneau osseux pâle,
aileron dorsal triangulaire, grandes nageoires avant en pagaie, petites nageoires arrière, queue en croissant vertical
(plaque). Dos bleu acier, bande gris foncé sur le flanc de l'oeil à la queue, ventre blanc.
Neck1 = la nuque, entre le crâne et le torse."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.28

BACK = (70, 114, 160)
BELLY = (240, 242, 240)
BAND = (60, 66, 78)
FIN = (52, 88, 128)
RING = (176, 198, 220)
EYE = (18, 22, 34)
GLINT = (255, 255, 255)
TOOTH = (252, 250, 242)
MOUTH = (178, 74, 90)

EYE_Y = 6                      # rangée basse de l'oeil (3 x 3 voxels, paupière de 3 rangées au-dessus)
EYE_H = 3
EYE_IN = 1                      # oeil creusé d'un voxel : l'anneau pâle reste au ras de la tête
BELLY_TOP = -1.2               # ventre blanc jusqu'à l'axe du corps - 1,2 voxel
BAND_TOP = 0.8                 # bande gris foncé au-dessus du ventre, jusqu'à l'axe + 0,8

PERSONALITY = {
    "tempo": 1.2,           # vif, nage nerveuse de dauphin
    "weight": 0.9,
    "tail": 1.1,
    "diet": "fish",
    "happy": "roll",
    "catch": "ram",
}


def catmull(pts, z, j):
    """Valeur j du profil au z donné (Catmull-Rom entre les points de contrôle)."""
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
    """Corps profilé : à chaque z, une section elliptique (centre cy, demi-hauteurs dessus/dessous, demi-largeur rx)."""
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


def socket_eye(d, ey, ez, h, w, iris, pupil, skin, ring, ring_top=None, pupil_rows=None, bone="Head", lid="LidL",
               inset=0):
    """Oeil gauche dans une orbite : oeil et paupière sur un panneau plat (même x, la paupière couvre bien l'oeil en se
    fermant), cadre en relief d'un voxel tout autour (anneau `ring` autour de l'oeil, `ring_top` au-dessus), et creux
    derrière la paupière (quand elle descend, on voit la peau `skin` et pas les voxels cachés du crâne).
    inset = 1 : le panneau est creusé d'un voxel dans la tête, le cadre reste au ras de la peau (rien ne dépasse de
    face)."""
    cells = [(y, z) for y in range(ey, ey + 2 * h) for z in range(ez, ez + w)]
    xe = min(d.surface_x(y, z) for y, z in cells if d.surface_x(y, z) is not None) + inset
    for y, z in cells:
        xs = d.surface_x(y, z)
        for x in range(xs if xs is not None else xe, xe):
            d.clear(x, y, z)
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
    d = Dino("Ichthyosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 6.2, 2.5))
    d.bone("Chest", (0, 6.2, 2.0), "Hips")
    d.bone("Neck1", (0, 6.4, -4.5), "Chest")
    d.bone("Head", (0, 6.6, -8.0), "Neck1")
    d.bone("Jaw", (0, 4.6, -9.0), "Head")
    d.bone_pair("Lid", (-3.0, EYE_Y + EYE_H + 0.5, -11.0), "Head")
    d.bone_pair("FinF1", (-3.0, 2.6, -2.8), "Chest")
    d.bone_pair("FinF2", (-6.8, 2.6, -1.8), "FinF1L")
    d.bone_pair("FinB1", (-2.2, 3.0, 7.4), "Hips")
    d.bone_pair("FinB2", (-4.2, 3.0, 8.0), "FinB1L")
    tz = [9.0, 12.0, 14.5, 17.0, 19.0]
    for i, z in enumerate(tz):
        d.bone(f"Tail{i + 1}", (0, 6.6 + 0.05 * i, z), "Hips" if i == 0 else f"Tail{i}")

    def bone_at(x, y, z):
        if z < -8:
            if z <= -9 or y <= 4:
                return "Jaw" if y <= 4 and z >= -22 else "Head"
            return "Head"
        if z < -4.5:
            return "Neck1"
        if z < 2:
            return "Chest"
        if z < 9:
            return "Hips"
        for i in range(len(tz) - 1, -1, -1):
            if z >= tz[i]:
                return f"Tail{i + 1}"
        return "Hips"

    # ---------------------------------------------------------------- corps en fuseau de dauphin (profil lissé)
    #          z     cy   dessus dessous  demi-largeur
    prof = [(-23.0, 4.6, 0.8, 0.7, 0.6),
            (-20.0, 4.8, 1.4, 1.3, 1.0),
            (-16.5, 5.0, 1.9, 1.6, 1.5),
            (-13.5, 6.0, 4.1, 2.6, 2.6),
            (-11.0, 6.5, 5.0, 3.1, 3.3),
            (-8.0, 6.4, 5.0, 3.6, 3.7),
            (-4.5, 6.3, 5.2, 4.3, 4.1),
            (-1.0, 6.2, 5.4, 4.7, 4.3),
            (3.0, 6.3, 5.0, 4.4, 3.9),
            (7.0, 6.5, 4.3, 3.9, 3.3),
            (10.0, 6.7, 3.4, 3.1, 2.6),
            (13.0, 6.8, 2.5, 2.3, 1.9),
            (16.0, 6.9, 1.7, 1.6, 1.3),
            (19.0, 6.9, 1.2, 1.1, 0.9),
            (20.5, 6.9, 1.0, 1.0, 0.7)]
    loft(d, prof, bone_at, BACK)
    # bouche : rainure fermée entre les mâchoires (palais et langue roses quand la gueule s'ouvre)
    for z in range(-20, -9):
        if (0, 4, z) in d.vox and (0, 3, z) in d.vox:
            d.clear(0, 4, z)
            d.set("Head", 0, 5, z, MOUTH)
            d.set("Jaw", 0, 3, z, MOUTH)
    # ---------------------------------------------------------------- nageoires avant en pagaie, petites arrière (plaques)
    d.plate("FinF1L", 1, 2, [(-2.6, -4.6), (-6.8, -3.6), (-6.8, 0.0), (-2.6, -0.6)], FIN, thick=2)
    d.plate("FinF2L", 1, 2, [(-6.8, -3.6), (-9.4, -1.8), (-10.8, 1.4), (-9.2, 1.8), (-6.8, 0.0)], FIN, thick=2)
    d.plate("FinB1L", 1, 3, [(-2.0, 6.4), (-4.2, 7.0), (-4.2, 8.8), (-2.0, 8.6)], FIN)
    d.plate("FinB2L", 1, 3, [(-4.2, 7.0), (-5.8, 8.4), (-5.6, 9.8), (-4.2, 8.8)], FIN)
    # ---------------------------------------------------------------- queue en croissant (plaque verticale)
    d.plate("Tail5", 0, 0, [(7.8, 17.6), (10.6, 20.0), (13.4, 23.2), (13.0, 24.2), (10.2, 23.0), (7.6, 22.0),
                            (6.4, 22.0), (3.6, 23.0), (0.8, 24.2), (0.4, 23.2), (3.2, 20.0), (6.0, 17.6)], FIN)
    # ---------------------------------------------------------------- très grand oeil cerclé (anneau sclérotique)
    # oeil sombre de 3 x 3 voxels dans un anneau osseux pâle en relief, reflet blanc en haut à l'avant
    socket_eye(d, EYE_Y, -12, EYE_H, 3, EYE, GLINT, BACK, RING, pupil_rows=[EYE_H - 1], inset=EYE_IN)
    # petites dents le long du museau
    for z in range(-21, -14, 2):
        x = d.surface_x(5, z, "Head")
        if x is not None:
            d.set("Head", x, 5, z, TOOTH, "Smooth")
        x = d.surface_x(4, z + 1, "Jaw")
        if x is not None:
            d.set("Jaw", x, 4, z + 1, TOOTH, "Smooth")
    d.mirror()
    seal_joint(d, "Head", "Neck1")
    # ---------------------------------------------------------------- peinture : dos bleu acier, bande grise, ventre blanc
    def paint(x, y, z, bone, c):
        if c != BACK:
            return None
        if bone == "Jaw":
            return BELLY
        if bone == "Head":
            return None                                 # museau : dessus bleu, mâchoire blanche, la ligne de la bouche reste nette
        axis = 6.2 + 0.04 * max(0, z)
        if y <= axis + BELLY_TOP:
            return BELLY
        if y <= axis + BAND_TOP and z <= 18:
            return BAND
        return None
    d.paint(paint)
    # ---------------------------------------------------------------- aileron dorsal (plaque verticale, au milieu du dos)
    d.plate("Hips", 0, 0, [(10.0, -1.6), (13.0, 0.8), (16.6, 4.0), (16.4, 5.0), (14.0, 4.8), (11.4, 6.6), (10.0, 6.6)], FIN)
    # ---------------------------------------------------------------- bouts des nageoires gris foncé, comme la bande
    tips = {"FinF2L": lambda x, y, z: x <= -9, "FinF2R": lambda x, y, z: x >= 9,
            "FinB2L": lambda x, y, z: x <= -5, "FinB2R": lambda x, y, z: x >= 5,
            "Tail5": lambda x, y, z: y >= 11 or y <= 2, "Hips": lambda x, y, z: y >= 15}
    d.paint(lambda x, y, z, bone, c: BAND if c == FIN and tips[bone](x, y, z) else None, surface_only=False,
            bones=list(tips))
    return d
