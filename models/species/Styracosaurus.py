"""Styracosaurus : quadrupède de la Fern Forest, cératopsien à couronne de pointes, fonceur.

Voxels de 0,29 stud : environ 13 studs de long et 8 de haut (pointes de la collerette comprises) à la taille Normal.
Grande corne sur le nez, pas de cornes au-dessus des yeux, collerette couronnée de six longues pointes qui rayonnent.
La collerette et ses pointes sont une plaque droite (peu de pièces) inclinée vers l'arrière par la rotation de repos
de son os."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.29

BODY = (196, 160, 98)
DARK = (120, 128, 64)
BELLY = (236, 218, 172)
FRILL = (222, 186, 118)
RAY = (222, 86, 44)
RIM = (164, 54, 38)
HORN = (244, 234, 206)
BEAK = (74, 66, 62)
NAIL = (232, 224, 202)
PUPIL = (26, 22, 20)
IRIS = (255, 210, 80)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.95,          # cératopsien plus léger que le Tricératops
    "weight": 1.15,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 0.8,
    "diet": "plants",
    "happy": "stomp",       # se cabre un peu et tape des pattes avant
    "catch": "ram",         # fonce tête baissée, corne en avant
}

# collerette (dans le plan de la plaque, côté gauche) : disque + six pointes (angle depuis la verticale, longueur)
FC, FR = 17.6, 6.7
SPIKES = [(13, 9.0), (37, 8.0), (62, 6.0)]


def build():
    d = Dino("Styracosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.5, 4))
    d.bone("Chest", (0, 9.5, 0.5), "Hips")
    d.bone("Neck1", (0, 10, -7.2), "Chest")
    d.bone("Head", (0, 10.5, -9.8), "Neck1")
    d.bone("Jaw", (0, 8.8, -12.2), "Head")
    d.bone("Frill", (0, 12.8, -10.3), "Head", rest=(38, 0, 0))
    d.bone_pair("Lid", (-3.2, 13, -14.5), "Head")
    d.bone_pair("Arm", (-4.6, 8.0, -4.6), "Chest")
    d.bone_pair("Forearm", (-5.4, 5.0, -2.8), "ArmL")
    d.bone_pair("Hand", (-5.2, 2.0, -5.0), "ForearmL")
    d.bone_pair("Thigh", (-4.4, 9.2, 5.5), "Hips")
    d.bone_pair("Shin", (-4.9, 5.0, 3.6), "ThighL")
    d.bone_pair("Foot", (-5.0, 2.2, 6.0), "ShinL")
    tz = [11.0, 14.6, 18.0, 21.2, 24.0]
    ty = [10.4, 9.8, 9.0, 8.3, 7.8]
    tr = [3.7, 2.9, 2.1, 1.4, 0.7]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps (tonneau bas sur pattes)
    d.ellipsoid("Hips", (0, 10, 5.5), (5.2, 5.2, 6.2), BODY, where=left, power=2.9)
    d.ellipsoid("Chest", (0, 9.3, -2.4), (5.0, 4.9, 5.4), BODY, where=left, power=2.9)
    d.limb("Neck1", (0, 9.8, -6.6), (0, 10.4, -9.4), 3.5, 3.3, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne, museau, bec, grande corne nasale
    d.ellipsoid("Head", (0, 10.8, -12.6), (3.4, 3.6, 3.6), BODY, where=left, power=2.3)
    d.ellipsoid("Head", (0, 9.8, -16.2), (2.4, 2.7, 3.0), BODY, where=lambda x, y, z: x <= 0 and y >= 8.8, power=2.3)
    d.ellipsoid("Head", (0, 9.5, -18.9), (1.5, 1.9, 1.4), BEAK, where=lambda x, y, z: x <= 0 and y >= 8.8)
    d.limb("Head", (0, 11.6, -16.6), (0, 18.0, -19.6), 1.8, 0.4, HORN)
    d.ellipsoid("Jaw", (0, 8.0, -15.6), (2.0, 1.1, 3.3), BODY, where=lambda x, y, z: x <= 0 and y <= 8.2, power=2.4)
    d.ellipsoid("Jaw", (0, 8.1, -18.3), (1.2, 1.0, 1.2), BEAK, where=lambda x, y, z: x <= 0 and y <= 8.2)
    for z in range(-18, -13):
        if (0, 9, z) in d.vox:
            d.set("Head", 0, 9, z, MOUTH)
        if (0, 8, z) in d.vox:
            d.set("Jaw", 0, 8, z, MOUTH)
    # petites cornes de joue (vers le bas et l'extérieur)
    d.limb("Head", (-3.0, 9.4, -13.2), (-4.6, 8.0, -13.6), 0.8, 0.3, HORN)
    # ---------------------------------------------------------------- collerette : disque + six pointes rayonnantes
    def disc(x, y, r):
        return (abs(x) / r) ** 2.6 + (abs(y - FC) / r) ** 2.6 <= 1.0

    for x in range(-9, 1):
        for y in range(11, 25):
            if disc(x, y, FR):
                col = FRILL if disc(x, y, FR - 1.2) else RIM
                d.set("Frill", x, y, -10, col)
                d.set("Frill", x, y, -9, col)
                if col == RIM:
                    d.set("Frill", x, y, -8, RIM)  # bord en relief vers l'arrière : la collerette a de l'épaisseur
    # rayons rouge-orangé du centre vers chaque pointe
    for (x, y, z), (b, col, mat) in list(d.vox.items()):
        if b == "Frill" and col == FRILL:
            dx, dy = x, y - FC
            r = math.hypot(dx, dy)
            if r < 1.6:
                d.set("Frill", x, y, z, RAY)
                continue
            ang = math.degrees(math.atan2(-dx, dy))
            if any(abs(ang - a) < 9 for a, _ in SPIKES) and dy > -2:
                d.set("Frill", x, y, z, RAY)
    # pointes : triangles longs qui partent du bord de la collerette
    for a, ln in SPIKES:
        t = math.radians(a)
        ux, uy = -math.sin(t), math.cos(t)          # direction de la pointe
        px, py = -uy, ux                            # perpendiculaire
        bx, by = ux * (FR - 1.0), FC + uy * (FR - 1.0)
        w = 1.2
        poly = [(bx + px * w, by + py * w), (bx + ux * (ln + 1.0), by + uy * (ln + 1.0)), (bx - px * w, by - py * w)]
        d.plate("Frill", 2, -10, poly, HORN, thick=2)
    d.remove(lambda x, y, z: y < 0)
    # ---------------------------------------------------------------- pattes
    d.limb("ArmL", (-4.7, 8.0, -4.6), (-5.4, 5.0, -2.8), 2.1, 1.8, BODY)
    d.limb("ForearmL", (-5.4, 5.0, -2.8), (-5.2, 2.0, -5.0), 1.8, 1.5, BODY)
    d.limb("HandL", (-5.2, 2.0, -5.0), (-5.2, 0.7, -5.6), 1.5, 1.5, BODY)
    d.box("HandL", (-7, 0, -8), (-4, 1, -5), BODY)
    for x in (-7, -5):
        d.set("HandL", x, 0, -9, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-4.8, 7.0, 5.0), (2.4, 3.6, 3.1), BODY)
    d.limb("ShinL", (-4.9, 5.0, 3.6), (-5.0, 2.2, 6.0), 1.9, 1.7, BODY)
    d.limb("FootL", (-5.0, 2.2, 6.0), (-5.0, 0.7, 4.8), 1.7, 1.7, BODY)
    d.box("FootL", (-7, 0, 2), (-3, 1, 6), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 2))
    d.point("FrontToeL", "HandL", (-5.5, 0, -8))
    # ---------------------------------------------------------------- queue
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 11, -15, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 6, "Chest": 5, "Neck1": 8, "Tail1": 9, "Tail2": 8, "Head": 8}
    saddle = {"Neck1": 13, "Chest": 13, "Hips": 14, "Tail1": 12, "Tail2": 11, "Tail3": 10, "Head": 14}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else
            (DARK if c == BODY and bone in saddle and y >= saddle[bone] else None))
    return d
