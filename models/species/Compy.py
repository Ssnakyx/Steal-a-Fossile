"""Compy (Compsognathus) : petit bipède de la Beach, nerveux et rapide.

Voxels de 0,103 stud : environ 4 studs de long et 2 de haut à la taille Normal (plus petit que l'avatar).
Long cou, longue queue fine, grosse tête et grands yeux (version mignonne), petits bras à deux griffes."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.103

BODY = (126, 186, 62)
DARK = (62, 112, 44)
BELLY = (236, 228, 172)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 206, 52)
MOUTH = (176, 58, 64)
TONGUE = (220, 104, 110)
TOOTH = (252, 250, 242)

# personnalité : lue par la famille d'animation (models/lib/fam_biped.py)
PERSONALITY = {
    "tempo": 1.4,           # nerveux : tout va vite
    "weight": 0.6,          # très léger : gros rebonds
    "stride": 1.1,
    "bob": 1.2,
    "headBob": 1.4,         # tête d'oiseau très marquée
    "tail": 1.25,           # longue queue qui fouette
    "diet": "meat",         # Eat : mord, tire, mâche
    "happy": "hop",         # Happy : saut avec un tour complet
    "catch": "headbutt",
}


def build():
    d = Dino("Compy", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 11, 2))
    d.bone("Chest", (0, 11, -0.5), "Hips")
    d.bone("Neck1", (0, 12.8, -4.4), "Chest")
    d.bone("Neck2", (0, 15.4, -6.4), "Neck1")
    d.bone("Head", (0, 17.6, -7.9), "Neck2")
    d.bone("Jaw", (0, 17.4, -10.2), "Head")
    d.bone_pair("Lid", (-2.3, 20, -11.5), "Head")
    d.bone_pair("Arm", (-2.2, 10.2, -4.4), "Chest")
    d.bone_pair("Forearm", (-2.5, 8.6, -5.3), "ArmL")
    d.bone_pair("Thigh", (-2.6, 10.4, 2), "Hips")
    d.bone_pair("Shin", (-2.8, 6.2, 0), "ThighL")
    d.bone_pair("Foot", (-2.8, 3.0, 2.4), "ShinL")
    tz = [5.6, 9.2, 12.8, 16.2, 19.6, 23.2]
    ty = [11.4, 11.9, 12.3, 12.6, 12.8, 13.0]
    tr = [2.5, 2.0, 1.55, 1.15, 0.85, 0.55]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps fin
    d.ellipsoid("Hips", (0, 11, 2.8), (2.7, 2.8, 3.6), BODY, where=left)
    d.ellipsoid("Chest", (0, 10.7, -2.2), (2.8, 3.0, 3.2), BODY, where=left)
    d.limb("Neck1", (0, 12.4, -4.0), (0, 15.4, -6.4), 2.0, 1.75, BODY, where=left)
    d.limb("Neck2", (0, 15.4, -6.4), (0, 17.6, -7.9), 1.75, 1.7, BODY, where=left)
    # tête : gros crâne arrondi + museau pointu, mâchoire séparée
    d.ellipsoid("Head", (0, 19.3, -9.8), (2.6, 2.5, 2.7), BODY, where=left, power=2.2)
    d.ellipsoid("Head", (0, 18.6, -12.3), (1.6, 1.4, 1.9), BODY, where=lambda x, y, z: x <= 0 and y >= 18, power=2.3)
    d.ellipsoid("Jaw", (0, 17.4, -11.8), (1.4, 0.8, 2.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 17, power=2.4)
    d.box("Jaw", (-1, 17, -9), (0, 17, -8), BODY)
    d.box("Head", (0, 18, -13), (0, 18, -10), MOUTH)
    d.box("Jaw", (0, 17, -12), (0, 17, -10), TONGUE)
    for z in (-13, -11):
        d.set("Head", -1, 18, z, TOOTH, "Smooth")
    d.set("Head", -1, 19, -14, DARK, "Smooth")  # narine
    # petits bras à deux griffes
    d.limb("ArmL", (-2.2, 10.2, -4.4), (-2.5, 8.6, -5.3), 0.9, 0.8, BODY)
    d.limb("ForearmL", (-2.5, 8.6, -5.3), (-2.5, 7.3, -7.4), 0.7, 0.6, BODY)
    d.set("ForearmL", -3, 7, -8, CLAW, "Smooth")
    d.set("ForearmL", -2, 7, -8, CLAW, "Smooth")
    # pattes fines : cuisse, jambe, pied à trois doigts
    d.ellipsoid("ThighL", (-2.8, 8.6, 0.9), (1.6, 2.6, 2.3), BODY)
    d.limb("ShinL", (-2.8, 6.2, 0), (-2.8, 3.0, 2.4), 1.1, 0.85, BODY)
    d.limb("FootL", (-2.8, 3.0, 2.4), (-2.8, 0.8, 0.6), 0.8, 0.8, BODY)
    d.box("FootL", (-4, 0, -2), (-2, 0, 1), BODY)
    d.box("FootL", (-3, 1, -1), (-2, 1, 1), BODY)
    for x in (-4, -2):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, -2.5))
    # longue queue fine en 5 segments
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 19, -11, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    # colonnes trop fines (bouts de queue, bords) : le ventre clair ne remonte pas sur le dessus
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.32, period=4, width=2,
                   only=[BODY])
    d.paint(lambda x, y, z, bone, c: shade(BODY, -0.12) if bone == "Head" and c == BODY and y >= 21 else None)
    return d
