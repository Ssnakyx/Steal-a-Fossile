"""Velociraptor : bipède du Canyon, nerveux et vif (pilote de la famille Biped).

Modélisé en voxels de 0,3 stud (détail fin) : environ 14 studs de long et 7 de haut à la taille Normal."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.3

BODY = (206, 124, 54)
DARK = (122, 66, 36)
BELLY = (241, 216, 168)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 196, 46)
MOUTH = (172, 56, 62)
TONGUE = (214, 98, 104)
TOOTH = (252, 250, 242)

# personnalité : lue par la famille d'animation (models/lib/fam_biped.py)
PERSONALITY = {
    "tempo": 1.2,           # nerveux et rapide
    "weight": 0.85,         # léger : petits rebonds, anticipations courtes
    "stride": 1.0,          # longueur de pas (x hauteur de hanche)
    "bob": 1.0,             # rebond du corps en marchant
    "headBob": 1.0,         # tête d'oiseau qui se stabilise puis avance
    "tail": 1.0,            # amplitude de la queue
    "diet": "meat",         # Eat : mord, tire, mâche
    "happy": "hop",         # Happy : saut sur place avec un demi-tour
    "catch": "headbutt",    # Catch : coup de tête
}


def build():
    d = Dino("Velociraptor", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 12, 2))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.5, -6.2), "Chest")
    d.bone("Neck2", (0, 17.2, -8.6), "Neck1")
    d.bone("Head", (0, 19.6, -10.4), "Neck2")
    d.bone("Jaw", (0, 18.8, -12.2), "Head")
    d.bone_pair("Lid", (-2.6, 22, -14.5), "Head")
    d.bone_pair("Arm", (-3.0, 11.5, -6.2), "Chest")
    d.bone_pair("Forearm", (-3.6, 9.6, -7.6), "ArmL")
    d.bone_pair("Thigh", (-3.6, 11.5, 2), "Hips")
    d.bone_pair("Shin", (-3.8, 6.5, -0.6), "ThighL")
    d.bone_pair("Foot", (-3.7, 3.2, 2.6), "ShinL")
    tz = [7.6, 11.2, 14.8, 18.2, 21.4, 24.4]
    tr = [3.4, 2.8, 2.2, 1.7, 1.25, 0.85]
    ty = [12.4, 12.9, 13.3, 13.6, 13.8, 14.0]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 12, 3.5), (4.0, 3.8, 5.0), BODY, where=left)
    d.ellipsoid("Chest", (0, 11.8, -3.0), (4.3, 4.4, 4.6), BODY, where=left)
    d.limb("Neck1", (0, 14.0, -6.0), (0, 17.2, -8.6), 2.9, 2.5, BODY, where=left)
    d.limb("Neck2", (0, 17.2, -8.6), (0, 19.6, -10.2), 2.5, 2.4, BODY, where=left)
    # tête : crâne carré + long museau, mâchoire séparée
    d.ellipsoid("Head", (0, 21.0, -12.8), (3.2, 2.9, 3.4), BODY, where=left, power=2.6)
    d.ellipsoid("Head", (0, 20.3, -16.8), (2.3, 1.9, 3.3), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.4)
    d.ellipsoid("Jaw", (0, 18.2, -15.6), (1.9, 1.0, 3.8), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.6)
    d.box("Jaw", (-1, 18, -13), (0, 18, -12), BODY)
    # palais rouge (vu quand la gueule s'ouvre), langue sur la mâchoire, dents au bord
    d.box("Head", (0, 19, -18), (0, 19, -13), MOUTH)
    d.box("Jaw", (0, 18, -17), (0, 18, -14), TONGUE)
    for z in (-18, -16, -14):
        d.set("Head", -1, 19, z, TOOTH, "Smooth")
    d.set("Head", -1, 21, -19, DARK, "Smooth")  # narine
    # bras repliés et griffes
    d.limb("ArmL", (-3.0, 11.5, -6.2), (-3.6, 9.6, -7.6), 1.3, 1.1, BODY)
    d.limb("ForearmL", (-3.6, 9.6, -7.6), (-3.4, 8.4, -9.8), 1.0, 0.8, BODY)
    d.set("ForearmL", -4, 7, -10, CLAW, "Smooth")
    d.set("ForearmL", -3, 7, -10, CLAW, "Smooth")
    d.set("ForearmL", -4, 8, -11, CLAW, "Smooth")
    # pattes : grosse cuisse, jambe, pied (métatarse + doigts + griffe en faucille)
    d.ellipsoid("ThighL", (-4.0, 9.2, 0.6), (2.4, 3.5, 3.3), BODY)
    d.limb("ShinL", (-3.8, 6.5, -0.6), (-3.7, 3.2, 2.6), 1.7, 1.3, BODY)
    d.limb("FootL", (-3.7, 3.2, 2.6), (-3.7, 0.9, 0.4), 1.3, 1.2, BODY)
    d.box("FootL", (-5, 0, -3), (-3, 0, 1), BODY)
    d.box("FootL", (-4, 1, -2), (-3, 1, 1), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.set("FootL", -2, 1, -1, CLAW, "Smooth")       # griffe en faucille relevée
    d.set("FootL", -2, 2, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -3.5))
    # queue en 5 segments épais, légèrement relevée
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux (sur la surface) + peinture
    d.eye("Head", "LidL", 20, -15, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.28, only=[BODY])
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.3, period=4, width=2,
                   only=[BODY])
    d.paint(lambda x, y, z, bone, c: shade(BODY, -0.1) if bone == "Head" and c == BODY and y >= 22 else None)
    return d
