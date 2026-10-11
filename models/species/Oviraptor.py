"""Oviraptor : petit bipède à plumes de la Beach, curieux, tête d'oiseau.

Voxels de 0,12 stud : environ 5 studs de long et 3,5 de haut (crête comprise) à la taille Normal.
Bec de perroquet sans dents, haute crête orange (os Crest, plaque droite), bras à plumes, éventail de plumes au bout
de la queue."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.12

BODY = (64, 156, 196)
DARK = (34, 90, 140)
BELLY = (240, 240, 230)
CREST = (246, 128, 44)
CREST_RIM = (204, 70, 46)
BEAK = (252, 196, 64)
BEAK_DARK = (214, 140, 40)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 226, 92)
MOUTH = (186, 70, 76)

PERSONALITY = {
    "tempo": 1.25,          # vif et curieux
    "weight": 0.7,
    "stride": 1.0,
    "bob": 1.1,
    "headBob": 1.5,         # vraie tête d'oiseau
    "tail": 0.8,            # queue plus courte
    "diet": "plants",       # Eat : picore trois fois puis mâche
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("Oviraptor", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 12, 3))
    d.bone("Chest", (0, 12, 0), "Hips")
    d.bone("Neck1", (0, 14.5, -4.6), "Chest")
    d.bone("Neck2", (0, 17.4, -6.6), "Neck1")
    d.bone("Head", (0, 20.0, -8.4), "Neck2")
    d.bone("Jaw", (0, 19.6, -10.4), "Head")
    d.bone("Crest", (0, 23.0, -11.0), "Head")
    d.bone_pair("Lid", (-2.6, 22, -11.5), "Head")
    d.bone_pair("Arm", (-3.2, 12.4, -4.2), "Chest")
    d.bone_pair("Forearm", (-3.6, 10.4, -4.8), "ArmL")
    d.bone_pair("Thigh", (-3.0, 11.6, 3), "Hips")
    d.bone_pair("Shin", (-3.2, 6.8, 0.8), "ThighL")
    d.bone_pair("Foot", (-3.2, 3.2, 3.4), "ShinL")
    tz = [7.4, 11.0, 14.6, 18.0, 21.2]
    ty = [12.6, 13.2, 13.7, 14.1, 14.4]
    tr = [3.0, 2.4, 1.8, 1.3, 1.0]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps d'oiseau, rond
    d.ellipsoid("Hips", (0, 12.2, 3.6), (3.3, 3.3, 4.2), BODY, where=left)
    d.ellipsoid("Chest", (0, 12.0, -1.8), (3.5, 3.7, 3.6), BODY, where=left)
    d.limb("Neck1", (0, 14.2, -4.2), (0, 17.4, -6.6), 2.4, 2.1, BODY, where=left)
    d.limb("Neck2", (0, 17.4, -6.6), (0, 20.0, -8.4), 2.1, 2.0, BODY, where=left)
    # tête courte et haute, bec de perroquet crochu (haut sur la tête, bas sur la mâchoire)
    d.ellipsoid("Head", (0, 21.6, -10.4), (2.6, 2.6, 2.6), BODY, where=left, power=2.3)
    d.ellipsoid("Head", (0, 21.0, -13.2), (1.7, 1.6, 2.0), BEAK, where=lambda x, y, z: x <= 0 and y >= 20, power=2.2)
    d.box("Head", (-1, 19, -15), (0, 19, -15), BEAK_DARK)      # pointe crochue
    d.ellipsoid("Jaw", (0, 19.0, -12.4), (1.4, 1.2, 1.8), BEAK_DARK, where=lambda x, y, z: x <= 0 and y <= 19, power=2.2)
    d.box("Jaw", (-1, 18, -10), (0, 19, -10), BODY)
    d.box("Head", (0, 20, -14), (0, 20, -11), MOUTH)
    d.set("Head", -1, 22, -15, BEAK_DARK, "Smooth")  # narine
    # crête : plaque droite de 3 voxels d'épaisseur, posée sur le crâne et le haut du bec
    crest = [(22.5, -14), (25, -13.6), (27, -12.2), (27.9, -10.2), (27.2, -8.4), (25, -7.8), (23, -8.4)]
    d.plate("Crest", 0, -1, crest, CREST, thick=2)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Crest" and (y >= 27 or z <= -13):
            d.vox[(x, y, z)] = (bone, CREST_RIM, mat)
    # bras à plumes : bras, avant-bras, trois doigts, éventail de plumes vers l'arrière
    d.limb("ArmL", (-3.2, 12.4, -4.2), (-3.6, 10.4, -4.8), 1.1, 1.0, BODY)
    d.limb("ForearmL", (-3.6, 10.4, -4.8), (-3.6, 8.6, -6.6), 0.9, 0.8, BODY)
    for z in (-7, -8):
        d.set("ForearmL", -4, 8, z, CLAW, "Smooth")
    feather = [(10.5, -4.5), (11.5, -3.5), (9.5, -1.5), (7.5, -1.5), (6.5, -4), (8, -6)]
    d.plate("ForearmL", 0, -4, feather, BODY)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "ForearmL" and x == -4 and col == BODY and (z >= -2 or y <= 7):
            d.vox[(x, y, z)] = (bone, DARK, mat)
    # longues pattes d'oiseau
    d.ellipsoid("ThighL", (-3.2, 9.6, 2.0), (1.9, 3.0, 2.7), BODY)
    d.limb("ShinL", (-3.2, 6.8, 0.8), (-3.2, 3.2, 3.4), 1.3, 1.0, BODY)
    d.limb("FootL", (-3.2, 3.2, 3.4), (-3.2, 0.8, 1.2), 1.0, 0.9, BEAK_DARK)
    d.box("FootL", (-4, 0, -2), (-2, 0, 2), BEAK_DARK)
    d.box("FootL", (-4, 1, 0), (-2, 1, 2), BEAK_DARK)
    for x in (-4, -2):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, -2.5))
    # queue courte et éventail de plumes vertical au bout
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # éventail horizontal, comme une queue d'oiseau
    fan = [(0.5, 18.5), (-2.5, 20), (-4.2, 23), (-3.6, 25.6), (-1.5, 26.6), (0.5, 26.6)]
    d.plate("Tail4", 1, 14, fan, BODY, thick=2)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Tail4" and col == BODY and z >= 24:
            d.vox[(x, y, z)] = (bone, DARK, mat)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 21, -12, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2"]
    d.countershade(body, BELLY, frac=0.34, only=[BODY])
    # colonnes trop fines (bouts de queue, bords) : le ventre clair ne remonte pas sur le dessus
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    d.paint(lambda x, y, z, bone, c: BELLY if bone == "Head" and c == BODY and y <= 19 else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3"], DARK, frac=0.25, period=5, width=2, only=[BODY])
    return d
