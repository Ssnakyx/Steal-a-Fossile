"""Protoceratops : petit cératopsien de la Beach, trapu et curieux (taille d'un mouton).

Voxels de 0,14 stud : environ 6 studs de long et près de 4 de haut (collerette comprise) à la taille Normal, le dos à
hauteur des hanches de l'avatar. Grosse tête au bec de perroquet crochu, large collerette osseuse en éventail SANS
longues cornes (petite bosse sur le nez), joues saillantes, corps dodu, queue haute aplatie sur les côtés.
Fauve sable, selle brune sur le dos et la queue, ventre crème, collerette claire bordée de corail (bord festonné).
La collerette est une plaque droite inclinée vers l'arrière par la rotation de repos de son os (peu de pièces)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.14

BODY = (228, 170, 96)
DARK = (156, 96, 52)
BELLY = (250, 236, 200)
FRILL = (250, 214, 158)
RIM = (244, 110, 88)
BEAK = (92, 72, 64)
HORN = (252, 240, 214)
NAIL = (252, 240, 214)
PUPIL = (26, 22, 20)
IRIS = (255, 200, 60)
MOUTH = (196, 98, 100)

PERSONALITY = {
    "tempo": 1.15,          # curieux et vif pour un cératopsien
    "weight": 1.1,          # dodu
    "stride": 1.0,
    "bob": 1.2,
    "headBob": 0.0,
    "tail": 0.9,
    "diet": "plants",
    "happy": "stomp",       # se cabre un peu et tape des pattes avant
    "catch": "toss",        # charge tête basse puis relève la collerette
    "sleepDrop": 0.46,      # couché, le ventre touche le sol
}


def build():
    d = Dino("Protoceratops", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.6, 4))
    d.bone("Chest", (0, 9.4, -0.5), "Hips")
    d.bone("Neck1", (0, 10.4, -5.2), "Chest")
    d.bone("Head", (0, 12.4, -8.0), "Neck1")
    d.bone("Jaw", (0, 11.4, -11.0), "Head")
    d.bone("Frill", (0, 16.6, -9.0), "Head", rest=(40, 0, 0))
    d.bone_pair("Lid", (-3.2, 16, -13.0), "Head")
    d.bone_pair("Arm", (-3.9, 7.8, -3.2), "Chest")
    d.bone_pair("Forearm", (-4.5, 5.0, -1.8), "ArmL")
    d.bone_pair("Hand", (-4.4, 2.1, -3.6), "ForearmL")
    d.bone_pair("Thigh", (-3.8, 8.8, 5.2), "Hips")
    d.bone_pair("Shin", (-4.3, 5.4, 3.6), "ThighL")
    d.bone_pair("Foot", (-4.3, 2.4, 5.4), "ShinL")
    tz = [8.4, 11.6, 14.6, 17.4, 19.9, 22.0]
    ty = [11.2, 11.0, 10.4, 9.6, 8.8, 8.2]
    tr = [3.9, 3.4, 2.8, 2.1, 1.4, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps dodu et court (dos plus haut aux hanches)
    d.ellipsoid("Hips", (0, 10.0, 4.4), (4.8, 5.0, 4.8), BODY, where=left, power=2.4)
    d.ellipsoid("Chest", (0, 9.4, -1.8), (4.8, 4.7, 4.4), BODY, where=left, power=2.4)
    d.limb("Neck1", (0, 10.0, -4.8), (0, 12.4, -8.0), 3.6, 3.5, BODY, where=left)
    # ---------------------------------------------------------------- tête : gros crâne, museau haut, bec crochu
    up = lambda x, y, z: x <= 0 and y >= 12  # noqa: E731
    d.ellipsoid("Head", (0, 14.2, -11.0), (3.8, 4.0, 3.6), BODY, where=up, power=2.3)
    d.ellipsoid("Head", (0, 13.8, -14.0), (2.6, 3.4, 2.4), BODY, where=up, power=2.3)
    # bec de perroquet sculpté colonne par colonne : bord du haut qui plonge vers une pointe crochue, 1 voxel de large
    # au bout (triangle pointé vers le bas vu de face)
    upper = {0: {-16: (12, 16), -17: (12, 16), -18: (11, 15), -19: (10, 14), -20: (10, 12)},
             -1: {-16: (12, 16), -17: (12, 15), -18: (11, 14), -19: (11, 13)}}
    for x, cols in upper.items():
        for z, (y0, y1) in cols.items():
            d.box("Head", (x, y0, z), (x, y1, z), BEAK)
    # petite bosse osseuse sur le nez (pas de corne)
    for x, z in ((0, -15), (-1, -15), (0, -14)):
        top = d.surface_y(x, z, "Head")
        d.set("Head", x, top + 1, z, HORN)
    # mâchoire et bec du bas (rentré sous le crochet)
    d.ellipsoid("Jaw", (0, 10.6, -13.2), (2.3, 1.6, 3.2), BODY, where=lambda x, y, z: x <= 0 and y <= 11, power=2.4)
    for x in (0, -1):
        d.box("Jaw", (x, 10, -18), (x, 11, -16), BEAK)
    d.set("Jaw", 0, 9, -17, BEAK)
    for z in range(-17, -11):
        if (0, 12, z) in d.vox and d.vox[(0, 12, z)][1] == BODY:
            d.set("Head", 0, 12, z, MOUTH)
        if (0, 11, z) in d.vox and d.vox[(0, 11, z)][1] == BODY:
            d.set("Jaw", 0, 11, z, MOUTH)
    # joues saillantes : pointes osseuses vers l'extérieur et le bas, sous l'oeil
    d.limb("Head", (-3.0, 13.2, -11.0), (-5.8, 11.4, -11.4), 1.5, 0.6, BODY, where=lambda x, y, z: y >= 11)
    d.set("Head", -6, 11, -12, HORN, "Smooth")
    d.set("Head", -6, 11, -11, HORN, "Smooth")
    # ---------------------------------------------------------------- collerette en éventail : plaque droite
    def half_w(y):
        return 4.0 + (7.8 - 4.0) * min(1.0, max(0.0, (y - 14) / 7.0))

    def inside(x, y, k):
        if y < 14:
            return False
        w = half_w(y) - k
        cap = (abs(x) / max(w, 0.1)) ** 2.2 + (max(0.0, y - 21.0) / (5.6 - k)) ** 2.2
        return abs(x) <= w and cap <= 1.0

    top = {}
    for x in range(-8, 1):
        for y in range(14, 28):
            if inside(x, y, 0):
                col = FRILL if inside(x, y, 1.3) else RIM
                d.set("Frill", x, y, -9, col)
                d.set("Frill", x, y, -8, col)
                if col == RIM:
                    d.set("Frill", x, y, -7, RIM)  # bord en relief vers l'arrière
                top[x] = max(top.get(x, y), y)
    # bord festonné : petites bosses osseuses sur le haut de la collerette
    for x in (0, -3, -6):
        for z in (-9, -8, -7):
            d.set("Frill", x, top[x] + 1, z, RIM)
    # ---------------------------------------------------------------- pattes courtes et fortes
    d.limb("ArmL", (-4.0, 7.8, -3.2), (-4.5, 5.0, -1.8), 1.9, 1.7, BODY)
    d.limb("ForearmL", (-4.5, 5.0, -1.8), (-4.4, 2.1, -3.6), 1.6, 1.4, BODY)
    d.limb("HandL", (-4.4, 2.1, -3.6), (-4.4, 0.7, -4.1), 1.4, 1.4, BODY)
    d.box("HandL", (-6, 0, -6), (-3, 1, -3), BODY)
    for x in (-6, -4):
        d.set("HandL", x, 0, -7, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-4.3, 6.8, 4.6), (2.1, 3.1, 2.8), BODY)
    d.limb("ShinL", (-4.3, 5.4, 3.6), (-4.3, 2.4, 5.4), 1.7, 1.5, BODY)
    d.limb("FootL", (-4.3, 2.4, 5.4), (-4.3, 0.7, 4.4), 1.5, 1.5, BODY)
    d.box("FootL", (-6, 0, 2), (-3, 1, 5), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, 2))
    d.point("FrontToeL", "HandL", (-4.5, 0, -6))
    # ---------------------------------------------------------------- queue haute, aplatie sur les côtés
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left,
               flat=1.7)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 13, -13, IRIS, PUPIL, lid_color=shade(BODY, -0.16), h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 6, "Chest": 6, "Neck1": 8, "Tail1": 8, "Tail2": 8, "Tail3": 8}
    saddle = {"Hips": 13, "Chest": 13, "Tail1": 13, "Tail2": 12, "Tail3": 11}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else
            (DARK if c == BODY and bone in saddle and y >= saddle[bone] else None))
    # queue : bandes brunes qui continuent la selle vers le bout
    d.back_stripes(["Tail3", "Tail4", "Tail5"], DARK, frac=0.5, period=3, width=1, only=[BODY])
    return d
