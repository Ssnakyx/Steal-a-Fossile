"""Baryonyx : bipède pêcheur du Swamp, patient, long museau de crocodile et grosse griffe de pouce.

Voxels de 0,266 stud : environ 13 studs de long et 6 de haut à la taille Normal.
Museau long et bas avec une petite crête rouge, cou en S, bras forts (griffe en crochet sur le pouce)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.266

BODY = (80, 104, 138)
DARK = (50, 68, 98)
BELLY = (228, 224, 206)
CREST = (220, 74, 54)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 200, 60)
MOUTH = (176, 64, 70)
TONGUE = (214, 104, 110)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.95,
    "weight": 1.15,
    "stride": 1.0,
    "bob": 0.9,
    "headBob": 0.3,
    "tail": 1.0,
    "diet": "fish",         # Eat : trois coups de museau rapides (pêche) puis avale
    "happy": "bounce",      # saute sur place sans tourner
    "catch": "headbutt",
}


def build():
    d = Dino("Baryonyx", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 13, 3))
    d.bone("Chest", (0, 13, -0.5), "Hips")
    d.bone("Neck1", (0, 15.2, -6.0), "Chest")
    d.bone("Neck2", (0, 17.4, -8.4), "Neck1")
    d.bone("Head", (0, 18.8, -10.4), "Neck2")
    d.bone("Jaw", (0, 18.2, -12.4), "Head")
    d.bone_pair("Lid", (-2.6, 21, -13), "Head")
    d.bone_pair("Arm", (-3.8, 12.4, -5.6), "Chest")
    d.bone_pair("Forearm", (-4.4, 10.0, -6.8), "ArmL")
    d.bone_pair("Thigh", (-4.0, 12.4, 3), "Hips")
    d.bone_pair("Shin", (-4.2, 7.0, 0.2), "ThighL")
    d.bone_pair("Foot", (-4.2, 3.4, 3.4), "ShinL")
    tz = [8.0, 12.0, 16.0, 20.0, 23.6, 27.0]
    ty = [13.4, 13.8, 14.0, 14.0, 13.8, 13.6]
    tr = [3.8, 3.0, 2.3, 1.7, 1.2, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 13.2, 3.6), (4.2, 4.0, 5.2), BODY, where=left)
    d.ellipsoid("Chest", (0, 12.8, -2.6), (4.4, 4.6, 4.6), BODY, where=left)
    d.limb("Neck1", (0, 14.8, -5.6), (0, 17.4, -8.4), 3.0, 2.6, BODY, where=left)
    d.limb("Neck2", (0, 17.4, -8.4), (0, 18.8, -10.4), 2.6, 2.4, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne + long museau bas (haut / mâchoire)
    d.ellipsoid("Head", (0, 20.0, -12.4), (2.6, 2.4, 2.8), BODY, where=left, power=2.4)
    d.ellipsoid("Head", (0, 19.2, -17.0), (1.7, 1.4, 4.4), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.5)
    d.ellipsoid("Jaw", (0, 18.2, -16.4), (1.5, 1.0, 4.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.5)
    d.box("Jaw", (-1, 18, -13), (0, 18, -12), BODY)
    d.box("Head", (0, 19, -20), (0, 19, -13), MOUTH)
    d.box("Jaw", (0, 18, -19), (0, 18, -14), TONGUE)
    for z in (-20, -18, -16, -14):
        d.set("Head", -1, 19, z, TOOTH, "Smooth")
    d.set("Head", -1, 20, -21, DARK, "Smooth")  # narine
    # petite crête rouge sur le dessus du museau (deux rangs en triangle)
    for z in range(-19, -14):
        d.set("Head", 0, 21, z, CREST)
    for z in range(-18, -15):
        d.set("Head", 0, 22, z, CREST)
    # ---------------------------------------------------------------- bras forts, griffe en crochet sur le pouce
    d.limb("ArmL", (-3.8, 12.4, -5.6), (-4.4, 10.0, -6.8), 1.5, 1.3, BODY)
    d.limb("ForearmL", (-4.4, 10.0, -6.8), (-4.2, 8.6, -9.2), 1.2, 1.0, BODY)
    for p in ((-5, 7, -10), (-4, 7, -10), (-5, 6, -10), (-5, 6, -9)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    d.set("ForearmL", -3, 8, -10, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes
    d.ellipsoid("ThighL", (-4.2, 10.0, 1.6), (2.4, 3.8, 3.4), BODY)
    d.limb("ShinL", (-4.2, 7.0, 0.2), (-4.2, 3.4, 3.4), 1.8, 1.4, BODY)
    d.limb("FootL", (-4.2, 3.4, 3.4), (-4.2, 0.9, 1.0), 1.4, 1.3, BODY)
    d.box("FootL", (-6, 0, -3), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -2), (-3, 1, 1), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, -3.5))
    # ---------------------------------------------------------------- queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 20, -14, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    # colonnes trop fines (bouts de queue, bords) : le ventre clair ne remonte pas sur le dessus
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.3, period=4, width=2,
                   only=[BODY])
    d.paint(lambda x, y, z, bone, c: shade(BODY, -0.12) if bone == "Head" and c == BODY and y >= 22 else None)
    return d
