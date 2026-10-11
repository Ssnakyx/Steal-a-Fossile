"""Psittacosaurus : « lézard-perroquet » de la Beach, petit bipède herbivore nerveux.

Voxels de 0,115 stud : environ 5 studs de long et 2,8 de haut (soies comprises) à la taille Normal : sa tête arrive
à la taille de l'avatar. Tête courte et haute au bec de perroquet orange crochu, petites cornes de joue pointées sur
les côtés (tête en triangle vue de dessus), grands yeux, petits bras, longues pattes, longue queue portant une rangée
de soies dressées (piquants fins, brun foncé) sur le dessus. Kaki olive, dos rayé plus foncé, ventre clair."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.115

BODY = (150, 152, 76)
DARK = (98, 104, 50)
BELLY = (236, 228, 176)
BRISTLE = (96, 62, 40)
BEAK = (248, 142, 44)
BEAK_DARK = (214, 102, 34)
HORN = (250, 238, 210)
CLAW = (250, 238, 210)
PUPIL = (26, 20, 18)
IRIS = (255, 214, 72)
MOUTH = (186, 70, 76)

PERSONALITY = {
    "tempo": 1.3,           # nerveux
    "weight": 0.7,          # léger
    "stride": 1.0,
    "bob": 1.1,
    "headBob": 1.0,         # petits coups de tête d'oiseau
    "tail": 1.0,
    "diet": "plants",       # Eat : broute au ras du sol puis mâche
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("Psittacosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 12, 3))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 13.6, -4.6), "Chest")
    d.bone("Neck2", (0, 16.0, -6.4), "Neck1")
    d.bone("Head", (0, 18.4, -7.8), "Neck2")
    d.bone("Jaw", (0, 17.6, -10.0), "Head")
    d.bone_pair("Lid", (-2.6, 22, -11.0), "Head")
    d.bone_pair("Arm", (-3.0, 11.0, -4.8), "Chest")
    d.bone_pair("Forearm", (-3.4, 9.2, -5.6), "ArmL")
    d.bone_pair("Thigh", (-3.2, 11.4, 3.2), "Hips")
    d.bone_pair("Shin", (-3.4, 6.8, 1.2), "ThighL")
    d.bone_pair("Foot", (-3.4, 3.2, 3.6), "ShinL")
    tz = [7.2, 11.0, 14.8, 18.6, 22.4, 26.4]
    ty = [12.4, 12.6, 12.6, 12.4, 12.0, 11.6]
    tr = [2.9, 2.4, 1.9, 1.4, 1.0, 0.6]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 12.2, 2.8), (3.2, 3.4, 4.2), BODY, where=left)
    d.ellipsoid("Chest", (0, 12.0, -2.2), (3.3, 3.6, 3.6), BODY, where=left)
    d.limb("Neck1", (0, 13.2, -4.2), (0, 16.0, -6.4), 2.4, 2.2, BODY, where=left)
    d.limb("Neck2", (0, 16.0, -6.4), (0, 18.4, -7.8), 2.2, 2.1, BODY, where=left)
    # ---------------------------------------------------------------- tête courte et haute, bec de perroquet
    up = lambda x, y, z: x <= 0 and y >= 18  # noqa: E731
    d.ellipsoid("Head", (0, 20.0, -9.6), (3.1, 3.1, 3.0), BODY, where=up, power=2.3)
    d.ellipsoid("Head", (0, 19.6, -11.8), (2.1, 2.6, 2.0), BODY, where=up, power=2.3)
    # bec orange crochu sculpté colonne par colonne (pointe vers le bas, 1 voxel de large au bout)
    upper = {0: {-14: (18, 22), -15: (17, 21), -16: (16, 19), -17: (16, 17)},
             -1: {-14: (18, 21), -15: (17, 20), -16: (17, 18)}}
    for x, cols in upper.items():
        for z, (y0, y1) in cols.items():
            d.box("Head", (x, y0, z), (x, y1, z), BEAK)
    d.set("Head", 0, 16, -17, BEAK_DARK)
    d.set("Head", 0, 17, -17, BEAK_DARK)
    d.set("Head", -1, 20, -14, BEAK_DARK, "Smooth")   # narine
    # mâchoire et bec du bas
    d.ellipsoid("Jaw", (0, 17.0, -11.2), (1.9, 1.2, 2.6), BODY, where=lambda x, y, z: x <= 0 and y <= 17, power=2.4)
    for x in (0, -1):
        d.box("Jaw", (x, 16, -15), (x, 17, -14), BEAK_DARK)
    for z in range(-15, -8):
        if (0, 18, z) in d.vox and d.vox[(0, 18, z)][1] == BODY:
            d.set("Head", 0, 18, z, MOUTH)
        if (0, 17, z) in d.vox and d.vox[(0, 17, z)][1] == BODY:
            d.set("Jaw", 0, 17, z, MOUTH)
    # petites cornes de joue pointées vers l'extérieur et un peu vers le bas
    d.limb("Head", (-2.4, 18.6, -10.0), (-4.8, 17.8, -10.2), 1.1, 0.45, BODY, where=lambda x, y, z: y >= 18)
    d.set("Head", -5, 18, -10, HORN, "Smooth")
    d.set("Head", -4, 18, -10, HORN, "Smooth")
    # ---------------------------------------------------------------- petits bras à quatre doigts
    d.limb("ArmL", (-3.0, 11.0, -4.8), (-3.4, 9.2, -5.6), 1.0, 0.9, BODY)
    d.limb("ForearmL", (-3.4, 9.2, -5.6), (-3.3, 7.8, -7.2), 0.85, 0.7, BODY)
    d.set("ForearmL", -4, 7, -8, CLAW, "Smooth")
    d.set("ForearmL", -3, 7, -8, CLAW, "Smooth")
    # ---------------------------------------------------------------- longues pattes
    d.ellipsoid("ThighL", (-3.4, 9.4, 2.2), (1.8, 3.0, 2.6), BODY)
    d.limb("ShinL", (-3.4, 6.8, 1.2), (-3.4, 3.2, 3.6), 1.25, 0.95, BODY)
    d.limb("FootL", (-3.4, 3.2, 3.6), (-3.4, 0.8, 1.6), 0.95, 0.9, BODY)
    d.box("FootL", (-4, 0, -1), (-3, 0, 2), BODY)
    d.box("FootL", (-5, 0, -1), (-5, 0, 0), BODY)
    d.box("FootL", (-4, 1, 0), (-3, 1, 2), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3.5, 0, -1.5))
    # ---------------------------------------------------------------- longue queue en 5 segments
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 20, -11, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.32, only=[BODY])
    # colonnes trop fines (bouts de queue, bords) : le ventre clair ne remonte pas sur le dessus
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    d.paint(lambda x, y, z, bone, c: BELLY if bone in ("Head", "Jaw") and c == BODY and y <= 17 else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.3, period=4, width=2,
                   only=[BODY])
    d.paint(lambda x, y, z, bone, c: DARK if bone == "Head" and c == BODY and y >= 22 else None)
    # ---------------------------------------------------------------- soies dressées sur le dessus de la queue
    # (posées après la peinture : fines tiges brun foncé, penchées vers l'arrière, plus hautes au milieu)
    seg = [(6, 11, "Tail1"), (11, 15, "Tail2"), (15, 19, "Tail3"), (19, 23, "Tail4")]
    tops = {z: d.surface_y(0, z) for z in range(7, 22, 2)}
    for z in range(7, 22, 2):
        bone = next(b for a, c, b in seg if a <= z < c)
        top = tops[z]
        h = 5 if 10 <= z <= 15 else (4 if z < 18 else 3)
        for k in range(h):
            d.set(bone, 0, top + 1 + k, z + k // 2, BRISTLE)
    return d
