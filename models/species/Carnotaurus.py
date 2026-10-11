"""Carnotaurus : bipède du Volcano, coureur rapide et bagarreur, cornes de taureau.

Voxels de 0,35 stud : environ 16 studs de long et 9 de haut à la taille Normal. Tête courte et haute, deux cornes
épaisses au-dessus des yeux, bras minuscules, longues pattes de coureur, rangées de bosses sur le dos.
Gardien du Volcano (zone 6) : cette espèce x2 (Scale = 2, environ 32 studs de long)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.35

BODY = (190, 58, 46)
DARK = (112, 34, 32)
BELLY = (238, 206, 168)
HORN = (240, 226, 196)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 214, 64)
MOUTH = (150, 40, 50)
TONGUE = (206, 96, 100)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 1.15,          # coureur nerveux
    "weight": 0.95,
    "stride": 1.15,         # longues pattes : grands pas
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",    # coup de cornes
}


def build():
    d = Dino("Carnotaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15, 2))
    d.bone("Chest", (0, 15.2, -2), "Hips")
    d.bone("Neck1", (0, 16.8, -7.4), "Chest")
    d.bone("Neck2", (0, 18.8, -9.4), "Neck1")
    d.bone("Head", (0, 20.4, -10.8), "Neck2")
    d.bone("Jaw", (0, 19.6, -12.6), "Head")
    d.bone_pair("Lid", (-2.8, 23, -14), "Head")
    d.bone_pair("Arm", (-3.6, 13.6, -6.4), "Chest")
    d.bone_pair("Forearm", (-4.0, 12.4, -7.2), "ArmL")
    d.bone_pair("Thigh", (-4.0, 14.4, 2.6), "Hips")
    d.bone_pair("Shin", (-4.3, 8.0, -0.6), "ThighL")
    d.bone_pair("Foot", (-4.3, 3.6, 3.0), "ShinL")
    tz = [8.6, 12.4, 16.0, 19.6, 23.0, 26.4]
    ty = [15.4, 15.6, 15.8, 15.9, 16.0, 16.1]
    tr = [3.4, 2.8, 2.2, 1.7, 1.2, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps élancé
    d.ellipsoid("Hips", (0, 15.4, 3.6), (4.2, 4.0, 5.4), BODY, where=left)
    d.ellipsoid("Chest", (0, 15.0, -3.4), (4.4, 4.6, 4.6), BODY, where=left)
    d.limb("Neck1", (0, 16.6, -7.2), (0, 18.8, -9.4), 3.0, 2.8, BODY, where=left)
    d.limb("Neck2", (0, 18.8, -9.4), (0, 20.4, -10.8), 2.8, 2.8, BODY, where=left)
    # ---------------------------------------------------------------- tête courte et haute
    d.ellipsoid("Head", (0, 22.2, -13.8), (3.0, 3.0, 3.8), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=3.0)
    d.ellipsoid("Jaw", (0, 19.0, -14.6), (2.4, 1.4, 3.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 19, power=2.6)
    d.box("Jaw", (-1, 19, -12), (0, 19, -11), BODY)
    d.box("Head", (0, 20, -17), (0, 20, -13), MOUTH)
    d.box("Jaw", (0, 19, -16), (0, 19, -13), TONGUE)
    for z in (-17, -15):
        x = d.surface_x(20, z, "Head")
        if x is not None:
            d.set("Head", x, 20, z, TOOTH, "Smooth")
    d.set("Head", -1, 23, -18, DARK, "Smooth")  # narine
    # cornes épaisses au-dessus des yeux, vers l'extérieur et un peu vers l'avant
    d.limb("Head", (-1.8, 24.4, -12.8), (-5.0, 26.2, -13.4), 1.2, 0.45, HORN)
    # ---------------------------------------------------------------- bras minuscules
    d.limb("ArmL", (-3.6, 13.6, -6.4), (-4.0, 12.4, -7.2), 1.0, 0.9, BODY)
    d.limb("ForearmL", (-4.0, 12.4, -7.2), (-4.0, 11.6, -8.4), 0.8, 0.7, BODY)
    d.set("ForearmL", -4, 11, -9, CLAW, "Smooth")
    # ---------------------------------------------------------------- longues pattes de coureur
    d.ellipsoid("ThighL", (-4.4, 11.2, 1.0), (2.5, 4.2, 3.4), BODY)
    d.limb("ShinL", (-4.3, 8.0, -0.6), (-4.3, 3.6, 3.0), 1.6, 1.2, BODY)
    d.limb("FootL", (-4.3, 3.6, 3.0), (-4.3, 1.0, 0.8), 1.2, 1.2, BODY)
    d.box("FootL", (-6, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -3), (-3, 1, 1), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, -4))
    # ---------------------------------------------------------------- queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 21, -15, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    d.back_stripes(["Hips", "Chest", "Neck1", "Neck2", "Head", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK,
                   frac=0.28, period=1, width=1, only=[BODY])
    # deux rangées de bosses (écailles osseuses) le long du dos
    for z in range(-7, 12, 3):
        for x in (-3, 3):
            bone = "Chest" if z < -1 else "Hips"
            y = d.surface_y(x, z, bone)
            if y is not None:
                d.set(bone, x, y + 1, z, DARK)
    return d
