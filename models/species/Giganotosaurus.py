"""Giganotosaurus : bipède du Meteor Crater, géant élancé et menaçant, rival du T-Rex.

Voxels de 0,4 stud : environ 22 studs de long et 10 de haut à la taille Normal. Tête longue et plus basse que celle
du T-Rex, museau étroit, arcades bosselées, bras à trois griffes, très longue queue. Gris anthracite rayé de rouge."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.4

BODY = (84, 82, 94)
STRIPE = (164, 56, 48)
BELLY = (210, 206, 200)
DARK = (54, 52, 62)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 214, 64)
MOUTH = (150, 46, 54)
TONGUE = (204, 92, 98)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.85,
    "weight": 1.35,
    "stride": 1.05,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 1.1,
    "diet": "meat",
    "happy": "stomp",
    "catch": "headbutt",
}


def build():
    d = Dino("Giganotosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15.4, 3))
    d.bone("Chest", (0, 15.8, -1.8), "Hips")
    d.bone("Neck1", (0, 17.8, -8.6), "Chest")
    d.bone("Neck2", (0, 19.8, -11.2), "Neck1")
    d.bone("Head", (0, 21.2, -13.0), "Neck2")
    d.bone("Jaw", (0, 20.6, -14.6), "Head")
    d.bone_pair("Lid", (-2.8, 24, -18), "Head")
    d.bone_pair("Arm", (-4.0, 14.0, -7.0), "Chest")
    d.bone_pair("Forearm", (-4.6, 11.4, -8.2), "ArmL")
    d.bone_pair("Thigh", (-4.2, 14.8, 3.6), "Hips")
    d.bone_pair("Shin", (-4.6, 8.6, 0.2), "ThighL")
    d.bone_pair("Foot", (-4.5, 4.0, 3.6), "ShinL")
    tz = [10.2, 14.4, 18.4, 22.2, 25.8, 29.0]
    ty = [16.4, 16.8, 17.0, 17.0, 16.8, 16.6]
    tr = [4.0, 3.2, 2.5, 1.9, 1.3, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps élancé
    d.ellipsoid("Hips", (0, 16.0, 4.8), (4.8, 4.8, 6.8), BODY, where=left)
    d.ellipsoid("Chest", (0, 15.4, -4.0), (5.0, 5.4, 5.6), BODY, where=left)
    d.limb("Neck1", (0, 17.4, -8.4), (0, 19.8, -11.2), 3.4, 3.0, BODY, where=left)
    d.limb("Neck2", (0, 19.8, -11.2), (0, 21.0, -12.8), 3.0, 2.9, BODY, where=left)
    # ---------------------------------------------------------------- tête longue : crâne, museau étroit, mâchoire
    d.ellipsoid("Head", (0, 22.2, -16.0), (3.0, 2.9, 4.2), BODY, where=lambda x, y, z: x <= 0 and y >= 21, power=2.7)
    d.ellipsoid("Head", (0, 21.6, -21.6), (2.3, 2.2, 4.0), BODY, where=lambda x, y, z: x <= 0 and y >= 21, power=2.5)
    d.ellipsoid("Jaw", (0, 20.0, -19.6), (2.2, 1.3, 5.6), BELLY, where=lambda x, y, z: x <= 0 and y <= 20, power=2.6)
    d.box("Jaw", (-1, 20, -15), (0, 20, -14), BODY)
    d.box("Head", (0, 21, -25), (0, 21, -16), MOUTH)
    d.box("Jaw", (0, 20, -24), (0, 20, -16), TONGUE)
    for z in (-25, -23, -21, -19, -17):
        x = d.surface_x(21, z, "Head")
        if x is not None:
            d.set("Head", x, 21, z, TOOTH, "Smooth")
    d.set("Head", -1, 23, -25, DARK, "Smooth")  # narine
    # ---------------------------------------------------------------- bras à trois griffes
    d.limb("ArmL", (-4.0, 14.0, -7.0), (-4.6, 11.4, -8.2), 1.3, 1.1, BODY)
    d.limb("ForearmL", (-4.6, 11.4, -8.2), (-4.4, 10.0, -10.6), 1.1, 0.9, BODY)
    for p in ((-5, 9, -11), (-4, 9, -11), (-3, 9, -11)):
        d.set("ForearmL", p[0], p[1], p[2], CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes
    d.ellipsoid("ThighL", (-4.8, 11.6, 2.0), (2.8, 4.4, 4.0), BODY)
    d.limb("ShinL", (-4.6, 8.6, 0.2), (-4.5, 4.0, 3.6), 2.0, 1.6, BODY)
    d.limb("FootL", (-4.5, 4.0, 3.6), (-4.5, 1.0, 1.2), 1.6, 1.5, BODY)
    d.box("FootL", (-7, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-6, 1, -3), (-3, 1, 1), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, -4))
    # ---------------------------------------------------------------- très longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 23, -18, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.28, only=[BODY])
    d.back_stripes(["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], STRIPE,
                   frac=0.3, period=5, width=2, only=[BODY])
    return d
