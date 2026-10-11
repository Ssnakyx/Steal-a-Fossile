"""Abyssal Leviathan : nageur Mythic de l'Ocean Trench, dragon-anguille des grands fonds (créature fantastique).

Voxels de 0,47 stud : environ 34 studs de long à la taille Normal. Long corps d'anguille noir-bleu des abysses qui
ondule (le cou se dresse, le dos plonge, la queue remonte puis redescend), crête dorsale en épines dentelées à pointe
Neon cyan, grandes nageoires pectorales déchiquetées bordées de Neon, petites nageoires pelviennes, nageoire de queue
en éventail dentelé. Tête massive à mâchoire prognathe : la mâchoire inférieure dépasse et remonte en menton, des dents
en aiguilles (Smooth) dépassent des deux lèvres et s'entrecroisent. Grands yeux pâles lumineux (Neon) à pupille fendue.
Points et tirets bioluminescents Neon cyan le long des flancs. Leurre lumineux au-dessus du front (os Crest) : tige
épaisse en segments empilés qui s'effilent et se courbe vers l'avant, au bout un cristal anguleux Neon en double
pyramide (losange de face comme de profil). Neck1-2 = le long cou, Tail1-6 = la queue."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.53

BODY = (16, 22, 40)
BELLY = (30, 40, 70)
FINC = (22, 34, 64)
RING = (8, 11, 22)
NEON = (40, 230, 255)
PALE = (196, 250, 255)
TOOTH = (226, 238, 246)
LIP = (10, 12, 22)
MOUTH = (112, 34, 66)
PUPIL = (6, 8, 18)
DEEP = (16, 150, 210)
STALK = (34, 48, 84)
EYE_PUPIL = -21                # colonne du milieu de l'oeil : iris cyan dans le blanc lumineux
CRYSTAL = (21, -30)            # cristal du leurre : centre y, z
CRYSTAL_R = (0, 1, 2, 2, 2, 2, 2, 1, 0)   # rayon de chaque couche, de la pointe haute à la pointe basse
HIPS_UP = 4.0                  # pivot du bassin au-dessus de l'axe du corps : le tonneau tourne autour du milieu
                               # de la silhouette (leurre compris) et le leurre ne plonge pas dans le sol



def crystal_color(i, x, dz):
    """Facettes du cristal (couche i depuis la pointe haute, décalage x et dz depuis son axe) : arête avant pâle,
    faces avant cyan, faces arrière bleu profond. La couleur ne dépend que de la colonne (x, dz), ce qui garde le
    cristal en peu de pièces."""
    if i == 0:
        return PALE
    if i == len(CRYSTAL_R) - 1 or dz > 0:
        return DEEP
    if dz < 0 and x == 0 and CRYSTAL_R[i] == max(CRYSTAL_R):
        return PALE
    return NEON


PERSONALITY = {
    "tempo": 0.8,           # géant des abysses : ondulations lentes et amples
    "weight": 1.5,
    "tail": 1.3,
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


def loft(d, pts, bone_at, color):
    """Corps profilé : à chaque z, une section (centre cy, demi-hauteurs dessus/dessous, demi-largeur rx, exposant)."""
    for z in range(math.ceil(pts[0][0]), math.floor(pts[-1][0]) + 1):
        cy, top, bot, rx, power = (catmull(pts, z, j) for j in (1, 2, 3, 4, 5))
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
    return xe


def seal_joint(d, child, parent):
    """Creux d'une tranche dans l'os enfant, sous la peau, contre l'os parent : à la fusion des boîtes, les détails
    (yeux, dents, bouche) ne peuvent plus s'étendre jusqu'à l'articulation."""
    cut = []
    for (x, y, z), (b, c, m) in d.vox.items():
        if b == child and not d.visible((x, y, z)):
            if any(d.vox.get((x + dx, y + dy, z + dz), (None,))[0] == parent
                   for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))):
                cut.append((x, y, z))
    for k in cut:
        del d.vox[k]


def mouth_slot(d, color, rows):
    """Fente fermée entre les mâchoires (voxels cachés de la rangée haute de Jaw retirés) : plancher, palais et fond
    prennent la couleur de la bouche, visible seulement quand la gueule s'ouvre."""
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


def neon_rim(d, bone, axis, keep):
    """Bord lumineux d'une nageoire en plaque (axis 1 : plaque horizontale, 0 : verticale) : les voxels de bord (un
    voisin manquant dans le plan, marches du dièdre comprises) pour lesquels keep(x, y, z) est vrai passent en Neon."""
    cells = {k for k, v in d.vox.items() if v[0] == bone}
    dirs = ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)) if axis == 1 else ((0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    steps = (-1, 0, 1) if axis == 1 else (0,)
    rim = []
    for (x, y, z) in cells:
        if keep(x, y, z) and any(not any((x + a, y + b + s, z + c) in cells for s in steps) for a, b, c in dirs):
            rim.append((x, y, z))
    for k in rim:
        d.vox[k] = (bone, NEON, "Neon")


def build():
    d = Dino("AbyssalLeviathan", FAMILY, voxel=VOXEL, display="Abyssal Leviathan")
    tz = [7.0, 11.0, 15.0, 19.0, 23.0, 26.5]
    # ---------------------------------------------------------------- corps sinueux (profil lissé)
    #          z     cy   dessus dessous demi-largeur exposant
    prof = [(-28.0, 15.4, 1.2, 1.0, 1.8, 2.2),
            (-26.0, 15.6, 2.6, 2.0, 3.2, 2.3),
            (-22.5, 15.8, 4.2, 3.4, 4.8, 2.4),
            (-19.0, 15.6, 4.8, 4.2, 5.2, 2.4),
            (-16.5, 14.8, 4.0, 3.8, 4.2, 2.3),
            (-12.5, 12.6, 3.4, 3.4, 3.4, 2.2),
            (-8.0, 10.4, 3.8, 3.9, 3.6, 2.1),
            (-2.0, 9.0, 4.2, 4.4, 3.8, 2.0),
            (4.0, 9.0, 3.9, 4.1, 3.5, 2.0),
            (9.0, 10.2, 3.3, 3.4, 3.0, 2.0),
            (13.5, 11.8, 2.7, 2.8, 2.5, 2.0),
            (18.0, 11.6, 2.2, 2.2, 2.0, 2.0),
            (22.0, 10.2, 1.7, 1.7, 1.5, 2.0),
            (25.5, 9.4, 1.2, 1.2, 1.1, 2.0),
            (28.0, 9.6, 0.8, 0.8, 0.7, 2.0)]

    def axis(z):
        return catmull(prof, min(max(z, prof[0][0]), prof[-1][0]), 1)

    def half(z, j):
        return catmull(prof, min(max(z, prof[0][0]), prof[-1][0]), j)

    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, axis(2.5) + HIPS_UP, 2.5))
    d.bone("Chest", (0, axis(2.0), 2.0), "Hips")
    d.bone("Neck1", (0, axis(-10.0), -10.0), "Chest")
    d.bone("Neck2", (0, axis(-13.5), -13.5), "Neck1")
    d.bone("Head", (0, axis(-17.0), -17.0), "Neck2")
    d.bone("Jaw", (0, 14.6, -18.5), "Head")
    d.bone_pair("Lid", (-5.0, 19.0, -21.0), "Head")
    d.bone("Crest", (0, 19.5, -20.0), "Head")
    d.bone_pair("FinF1", (-3.4, 8.0, -6.0), "Chest")
    d.bone_pair("FinF2", (-8.5, 8.0, -4.5), "FinF1L")
    d.bone_pair("FinB1", (-3.0, 6.6, 5.5), "Hips")
    d.bone_pair("FinB2", (-6.2, 6.6, 6.5), "FinB1L")
    for i, z in enumerate(tz):
        d.bone(f"Tail{i + 1}", (0, axis(z), z), "Hips" if i == 0 else f"Tail{i}")

    M = 14                                              # rangée haute de la mâchoire (ligne de la gueule)

    def bone_at(x, y, z):
        if z < -17:
            return "Jaw" if y <= M and z < -18.5 else "Head"
        if z < -13.5:
            return "Neck2"
        if z < -10:
            return "Neck1"
        if z < 2.0:
            return "Chest"
        if z < tz[0]:
            return "Hips"
        for i in range(len(tz) - 1, -1, -1):
            if z >= tz[i]:
                return f"Tail{i + 1}"
        return "Hips"

    loft(d, prof, bone_at, BODY)
    # ---------------------------------------------------------------- mâchoire prognathe : profonde, elle dépasse en menton
    d.ellipsoid("Jaw", (0, 12.6, -23.5), (3.4, 2.4, 5.4), BODY, where=lambda x, y, z: x <= 0 and y <= M, power=2.3)
    d.ellipsoid("Jaw", (0, 14.0, -28.6), (2.0, 1.8, 1.6), BODY, where=lambda x, y, z: x <= 0, power=2.2)
    # ---------------------------------------------------------------- dents en aiguilles qui dépassent des lèvres
    for z in range(-29, -19):
        xs = d.surface_x(M, z, "Jaw")
        if xs is not None:
            d.set("Jaw", xs, M, z, LIP)                 # lèvre sombre : la ligne de la gueule
    for z in range(-27, -20, 2):
        xh = d.surface_x(M + 1, z, "Head")
        if xh is not None:                             # aiguille du haut : pend le long de la lèvre inférieure
            for y in (M + 1, M, M - 1):
                d.set("Head", xh - 1, y, z, TOOTH, "Smooth")
    for z in range(-26, -20, 2):
        xj = d.surface_x(M, z, "Jaw")
        if xj is not None:                             # aiguille du bas : monte le long de la lèvre supérieure
            for y in (M, M + 1, M + 2):
                d.set("Jaw", xj - 1, y, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- grand oeil pâle lumineux, pupille fendue au milieu
    socket_eye(d, 17, -22, 2, 3, PALE, PUPIL, BODY, RING, ring_top=RING, pupil_rows=[])
    for (x, y, z), (b, c, mat) in list(d.vox.items()):
        if b == "Head" and c == PALE:
            d.vox[(x, y, z)] = (b, NEON, "Neon") if z == EYE_PUPIL else (b, PALE, "Neon")
    # épines de joue vers l'arrière, pointe Neon
    for y0, z0 in ((15, -17), (17, -16)):
        x = d.surface_x(y0, z0)
        if x is not None:
            d.set("Head" if z0 < -17 else d.vox[(x, y0, z0)][0], x - 1, y0, z0, BODY)
            d.set(d.vox[(x, y0, z0)][0], x - 1, y0, z0 + 1, NEON, "Neon")
    # ---------------------------------------------------------------- nageoires déchiquetées
    d.plate("FinF1L", 1, 8, [(-2.0, -9.0), (-8.5, -8.4), (-8.5, -0.6), (-2.0, -3.4)], FINC, thick=1)
    d.plate("FinF2L", 1, 8, [(-8.5, -8.4), (-13.4, -7.6), (-17.6, -5.2), (-15.6, -2.4), (-16.4, 0.8), (-13.4, -0.8),
                             (-12.8, 3.0), (-10.8, 0.6), (-9.4, 3.4), (-8.5, -0.6)], FINC, thick=1)
    d.plate("FinB1L", 1, 6, [(-2.0, 4.0), (-6.2, 5.0), (-6.2, 8.2), (-2.0, 7.6)], FINC, thick=1)
    d.plate("FinB2L", 1, 6, [(-6.2, 5.0), (-9.2, 6.8), (-10.0, 10.2), (-8.6, 9.0), (-7.6, 10.8), (-6.2, 8.2)], FINC, thick=1)
    for b in ("FinF1L", "FinF2L"):
        lift(d, b, lambda x: (x <= -8) + (x <= -12))
    for b in ("FinB1L", "FinB2L"):
        lift(d, b, lambda x: (x <= -7))
    neon_rim(d, "FinF2L", 1, lambda x, y, z: x <= -9)
    for tip in ((-17.0, -5.0), (-15.8, 0.4)):               # rayons lumineux de la racine aux pointes
        for k in range(0, 41):
            t = k / 40
            x, z = round(-3.0 + (tip[0] + 3.0) * t), round(-5.0 + (tip[1] + 5.0) * t)
            for y in range(7, 12):
                v = d.vox.get((x, y, z))
                if v and v[0] in ("FinF1L", "FinF2L") and x <= -5:
                    d.vox[(x, y, z)] = (v[0], NEON, "Neon")
    neon_rim(d, "FinB2L", 1, lambda x, y, z: x <= -7)
    # ---------------------------------------------------------------- points bioluminescents le long du flanc
    for z in range(-14, 24, 3):
        y = round(axis(z) - half(z, 3) * 0.5)
        x = d.surface_x(y, z)
        if x is not None:
            d.set(d.vox[(x, y, z)][0], x, y, z, NEON, "Neon")
    for z in range(-13, 22, 7):                         # ligne latérale en tirets
        y = round(axis(z + 1) + 0.8)
        for zz in (z, z + 1, z + 2):
            x = d.surface_x(y, zz)
            if x is not None and not d.vox[(x, y, zz)][0].startswith("Fin"):
                d.set(d.vox[(x, y, zz)][0], x, y, zz, NEON, "Neon")
    for z in (-26, -23):                                # points sur la joue, sous l'oeil
        x = d.surface_x(12, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 12, z, NEON, "Neon")
    d.mirror()
    mouth_slot(d, MOUTH, (M,))
    seal_joint(d, "Head", "Neck2")

    # ---------------------------------------------------------------- crête dorsale : épines dentelées à pointe Neon
    for z0 in range(-12, 26, 4):
        top = axis(z0) + half(z0, 2)
        h = 4.4 if -8 <= z0 <= 8 else (3.4 if z0 < 18 else 2.4)
        base = math.floor(top) - 1
        bone = bone_at(0, base, z0)
        poly = [(base, z0 - 1.6), (base + h, z0 + 1.2), (base + h - 0.6, z0 + 2.0), (base, z0 + 1.8)]
        d.plate(bone, 0, 0, poly, FINC)
        cells = [k for k, v in d.vox.items() if v[0] == bone and k[0] == 0 and z0 - 2 <= k[2] <= z0 + 2 and k[1] > top]
        if cells:
            tip = max(cells, key=lambda k: (k[1], k[2]))
            d.vox[tip] = (bone, NEON, "Neon")
    # ---------------------------------------------------------------- nageoire de queue en éventail dentelé
    d.plate("Tail6", 0, 0, [(10.4, 25.5), (14.4, 29.4), (15.0, 32.2), (12.6, 30.4), (11.0, 33.0), (9.6, 31.0),
                            (8.2, 33.0), (6.6, 30.4), (4.2, 32.2), (4.8, 29.4), (8.8, 25.5)], FINC)
    neon_rim(d, "Tail6", 0, lambda x, y, z: z >= 29)
    # ---------------------------------------------------------------- leurre : tige segmentée courbée vers l'avant, cristal Neon
    # tige : blocs épais empilés en escalier, qui montent puis partent vers l'avant en s'affinant (3 -> 1 voxel)
    blocks = [((-1, 19, -21), (1, 21, -19), BODY), ((-1, 22, -22), (1, 23, -20), STALK),
              ((-1, 24, -24), (1, 25, -22), BODY), ((0, 25, -27), (0, 26, -25), STALK),
              ((0, 25, -29), (0, 26, -28), BODY)]
    for a, b, col in blocks:
        d.box("Crest", a, b, col)
    # cristal : colonne à pointes (losange de face comme de profil), rayon des couches de haut en bas
    cy, cz = CRYSTAL
    for i, r in enumerate(CRYSTAL_R):
        y = cy + len(CRYSTAL_R) // 2 - i
        for x in range(-r, r + 1):
            for z in range(cz - r, cz + r + 1):
                if abs(x) + abs(z - cz) <= r:
                    d.set("Crest", x, y, z, crystal_color(i, x, z - cz), "Neon")
    return d
