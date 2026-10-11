"""Archelon : tortue de mer géante de la Beach, calme et majestueuse.

Voxels de 0,24 stud : environ 12 studs de long (bec à queue) et 11 d'envergure de nageoires à la taille Normal,
3,6 de haut. Carapace bombée en goutte (pointe à l'arrière), cinq crêtes longitudinales claires sur le sarcelle foncé,
bord clair, plastron crème. Grosse tête au bec corné très crochu (pointe qui descend devant la mâchoire), grands yeux,
cou court et épais qui sort sous le bord de la carapace. Grandes nageoires avant en ailes (FinF1 + FinF2), petites
nageoires arrière arrondies (FinB1 + FinB2), petite queue en quatre segments terminée par une petite palette.
Peau gris-bleu semée de petites taches claires. Toute la carapace et le plastron sont portés par Hips (la carapace ne
se plie jamais) ; Chest porte les épaules, le cou et les nageoires avant."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Swimmer"
VOXEL = 0.24

SHELL = (34, 98, 108)
RIDGE = (104, 186, 178)
SKIN = (96, 124, 146)
SPOT = (222, 232, 230)
BELLY = (244, 232, 196)
BEAK = (232, 206, 140)
MOUTH = (186, 84, 92)
PUPIL = (24, 20, 20)
IRIS = (255, 200, 80)

PERSONALITY = {
    "tempo": 0.8,           # calme, grands coups de nageoires lents
    "weight": 1.2,
    "tail": 0.4,            # toute petite queue
    "diet": "fish",         # Eat : happe un poisson au vol et l'avale tête levée
    "happy": "roll",        # tonneau sur elle-même
    "catch": "ram",         # coup de tête, bec fermé à l'impact
}


def build():
    d = Dino("Archelon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 5, 3))
    d.bone("Chest", (0, 5, -6), "Hips")
    d.bone("Neck1", (0, 4.6, -12.5), "Chest")
    d.bone("Neck2", (0, 5.0, -15.5), "Neck1")
    d.bone("Head", (0, 6.4, -18.5), "Neck2")
    d.bone("Jaw", (0, 6.5, -19.5), "Head")
    d.bone_pair("Lid", (-3.4, 11, -23.5), "Head")
    d.bone_pair("FinF1", (-7, 2.5, -8), "Chest")
    d.bone_pair("FinF2", (-14.5, 2.5, -6.5), "FinF1L")
    d.bone_pair("FinB1", (-5.5, 2.5, 8.5), "Hips")
    d.bone_pair("FinB2", (-9.5, 2.5, 11), "FinB1L")
    tz = [10.0, 12.4, 14.6, 16.6, 18.4]
    ty = [3.6, 3.6, 3.5, 3.4, 3.3]
    tr = [2.2, 1.8, 1.5, 1.2, 1.0]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    def taper(z):
        """Largeur relative de la carapace : pleine à l'avant, effilée en pointe arrondie à l'arrière."""
        return 1.0 if z <= -2 else max(0.35, 1.0 - 0.042 * (z + 2))

    # ---------------------------------------------------------------- épaules (Chest), sous le bord avant
    d.ellipsoid("Chest", (0, 4.0, -11.0), (6.5, 2.6, 3.5), SKIN, where=left)
    # ---------------------------------------------------------------- plastron crème (bords arrondis vers le bas)
    for y, (fx, fz) in enumerate([(0.72, 0.80), (0.80, 0.86), (0.86, 0.90), (0.90, 0.93)]):
        for x in range(-12, 1):
            for z in range(-16, 15):
                u = abs(x) / (11.0 * taper(z) * fx)
                w = abs(z + 1) / (13.5 * fz)
                if u ** 2.2 + w ** 2.2 <= 1.0:
                    d.set("Hips", x, y, z, BELLY)
    # ---------------------------------------------------------------- grandes nageoires avant en ailes, petites arrière
    d.plate("FinF1L", 1, 2, [(-5, -11), (-10, -11.5), (-14.5, -10.5), (-14.5, -3.5), (-10, -4.5), (-5, -5.5)],
            SKIN, thick=2)
    d.plate("FinF2L", 1, 2, [(-14.5, -10.5), (-18.5, -8), (-21.5, -4.2), (-23, 0.4), (-21.8, 1.4), (-18.5, -2.2),
                             (-14.5, -3.5)], SKIN, thick=2)
    d.plate("FinB1L", 1, 2, [(-4.5, 7), (-9.5, 8.5), (-9.5, 12.5), (-5, 11)], SKIN, thick=2)
    d.plate("FinB2L", 1, 2, [(-9.5, 8.5), (-12.5, 10), (-13.5, 12.5), (-12, 14.5), (-9.5, 12.5)], SKIN, thick=2)
    # ---------------------------------------------------------------- petite queue + petite palette en losange
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], SKIN, where=left)
    d.plate("Tail4", 1, 3, [(0.4, 16.4), (-2.8, 18.8), (0.4, 21.6)], SKIN)
    # ---------------------------------------------------------------- cou court et épais (sort sous la carapace)
    d.limb("Neck1", (0, 4.4, -12.0), (0, 5.0, -15.5), 3.2, 3.0, SKIN, where=left)
    d.limb("Neck2", (0, 5.0, -15.5), (0, 6.4, -18.5), 3.0, 2.8, SKIN, where=left)
    # ---------------------------------------------------------------- grosse tête au bec crochu
    up = lambda x, y, z: x <= 0 and y >= 7  # noqa: E731
    d.ellipsoid("Head", (0, 8.8, -21.4), (3.8, 3.4, 4.4), SKIN, where=up, power=2.3)
    d.ellipsoid("Head", (0, 8.6, -24.4), (2.9, 2.9, 2.4), SKIN, where=up, power=2.3)
    # bec du haut sculpté colonne par colonne : arête qui plonge vers un crochet pointu devant la mâchoire
    upper = {0: {-26: (7, 10), -27: (6, 10), -28: (5, 9), -29: (4, 7)},
             -1: {-26: (7, 10), -27: (6, 9), -28: (5, 7)}}
    for x, cols in upper.items():
        for z, (y0, y1) in cols.items():
            d.box("Head", (x, y0, z), (x, y1, z), BEAK)
    d.ellipsoid("Jaw", (0, 5.8, -22.2), (2.8, 1.7, 3.6), SKIN, where=lambda x, y, z: x <= 0 and y <= 6, power=2.3)
    lower = {0: {-26: (4, 6), -27: (5, 6)}, -1: {-26: (5, 6)}}
    for x, cols in lower.items():
        for z, (y0, y1) in cols.items():
            d.box("Jaw", (x, y0, z), (x, y1, z), BEAK)
    for z in range(-26, -17):
        if (0, 7, z) in d.vox and d.vox[(0, 7, z)][0] == "Head":
            d.set("Head", 0, 7, z, MOUTH)
        if (0, 6, z) in d.vox and d.vox[(0, 6, z)][0] == "Jaw":
            d.set("Jaw", 0, 6, z, MOUTH)
    # ---------------------------------------------------------------- carapace bombée (os Hips) : posée en dernier
    for x in range(-12, 1):
        for y in range(4, 14):
            for z in range(-16, 15):
                u = abs(x) / (11.0 * taper(z))
                v = (y - 4) / 9.0
                w = abs(z + 1) / 14.0
                if u ** 2.2 + v ** 2.2 + w ** 2.2 <= 1.0:
                    d.set("Hips", x, y, z, SHELL)
    # cinq crêtes longitudinales en relief (x = 0, ±4, ±8)
    for x in (0, -4, -8):
        tops = {z: d.surface_y(x, z, "Hips") for z in range(-16, 15)}
        for z, top in tops.items():
            if top is not None and top >= 6 + abs(x) // 4:
                d.set("Hips", x, top + 1, z, RIDGE)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 9, -24, IRIS, PUPIL, lid_color=shade(SKIN, -0.15), h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # bord de carapace clair ; gorge claire ; petites taches claires sur la peau (tête, cou, nageoires)
    d.paint(lambda x, y, z, bone, c: RIDGE if bone == "Hips" and c == SHELL and y == 4 else None)
    throat = {"Jaw": 4, "Neck1": 3, "Neck2": 3, "Chest": 3}
    d.paint(lambda x, y, z, bone, c: BELLY if c == SKIN and bone in throat and y <= throat[bone] else None)
    skin_bones = ("Head", "Neck1", "Neck2", "FinF1L", "FinF1R", "FinF2L", "FinF2R", "FinB1L", "FinB1R", "FinB2L",
                  "FinB2R")
    d.paint(lambda x, y, z, bone, c: SPOT if c == SKIN and bone in skin_bones and y >= 3
            and (abs(x) * 3 + y * 5 + z * 7) % 11 == 0 else None)
    return d
