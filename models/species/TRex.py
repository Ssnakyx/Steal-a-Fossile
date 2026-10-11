"""T-Rex : bipède du Meteor Crater, le roi, lourd et puissant (le sol tremble à chaque pas).

Voxels de 0,385 stud : environ 20 studs de long et 10 de haut à la taille Normal. Énorme tête haute avec arcades
au-dessus des yeux, bras minuscules à deux doigts, cuisses massives, queue épaisse en six segments.
Gardien du Meteor Crater (zone 8) : cette espèce x2 (Scale = 2, environ 41 studs de long)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.385

BODY = (132, 90, 58)
DARK = (86, 56, 40)
BELLY = (236, 214, 176)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 186, 40)
MOUTH = (164, 52, 58)
TONGUE = (208, 96, 100)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.75,          # lourd : pas lents et appuyés
    "weight": 1.6,
    "stride": 0.95,
    "bob": 1.1,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "meat",
    "happy": "stomp",       # pas de tour sur lui-même : trop lourd
    "catch": "headbutt",
}


def build():
    d = Dino("TRex", FAMILY, voxel=VOXEL, display="T-Rex")
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15, 3))
    d.bone("Chest", (0, 15.4, -1.6), "Hips")
    d.bone("Neck1", (0, 17.6, -8.2), "Chest")
    d.bone("Neck2", (0, 19.6, -10.6), "Neck1")
    d.bone("Head", (0, 21.2, -12.4), "Neck2")
    d.bone("Jaw", (0, 20.6, -14.0), "Head")
    d.bone_pair("Lid", (-3.0, 24, -17), "Head")
    d.bone_pair("Arm", (-4.2, 13.6, -6.8), "Chest")
    d.bone_pair("Forearm", (-4.8, 11.8, -7.6), "ArmL")
    d.bone_pair("Thigh", (-4.4, 14.4, 3.6), "Hips")
    d.bone_pair("Shin", (-4.8, 8.4, 0.4), "ThighL")
    d.bone_pair("Foot", (-4.7, 4.0, 3.6), "ShinL")
    tz = [9.8, 13.8, 17.6, 21.2, 24.4, 27.2]
    ty = [16.0, 16.4, 16.6, 16.6, 16.4, 16.2]
    tr = [4.2, 3.4, 2.7, 2.0, 1.4, 0.9]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps massif
    d.ellipsoid("Hips", (0, 15.6, 4.6), (5.0, 5.0, 6.4), BODY, where=left)
    d.ellipsoid("Chest", (0, 15.0, -3.8), (5.4, 5.6, 5.4), BODY, where=left)
    d.limb("Neck1", (0, 17.2, -8.0), (0, 19.6, -10.6), 3.6, 3.4, BODY, where=left)
    d.limb("Neck2", (0, 19.6, -10.6), (0, 21.0, -12.2), 3.4, 3.3, BODY, where=left)
    # ---------------------------------------------------------------- énorme tête : crâne haut, museau, mâchoire
    d.ellipsoid("Head", (0, 22.4, -15.4), (3.6, 3.4, 4.0), BODY, where=lambda x, y, z: x <= 0 and y >= 21, power=2.7)
    d.ellipsoid("Head", (0, 21.8, -20.4), (2.8, 2.6, 3.4), BODY, where=lambda x, y, z: x <= 0 and y >= 21, power=2.6)
    d.ellipsoid("Jaw", (0, 19.8, -18.4), (2.6, 1.6, 5.0), BELLY, where=lambda x, y, z: x <= 0 and y <= 20, power=2.6)
    d.box("Jaw", (-2, 20, -14), (0, 20, -13), BODY)
    d.box("Head", (0, 21, -23), (0, 21, -15), MOUTH)
    d.box("Jaw", (0, 20, -22), (0, 20, -15), TONGUE)
    for z in (-23, -21, -19, -17):
        x = d.surface_x(21, z, "Head")
        if x is not None:
            d.set("Head", x, 21, z, TOOTH, "Smooth")
    for z in (-22, -20, -18):
        x = d.surface_x(20, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 20, z, TOOTH, "Smooth")
    d.set("Head", -1, 23, -24, DARK, "Smooth")  # narine
    # ---------------------------------------------------------------- bras minuscules à deux doigts
    d.limb("ArmL", (-4.2, 13.6, -6.8), (-4.8, 11.8, -7.6), 1.1, 1.0, BODY)
    d.limb("ForearmL", (-4.8, 11.8, -7.6), (-4.6, 11.0, -9.2), 0.9, 0.8, BODY)
    d.set("ForearmL", -5, 10, -10, CLAW, "Smooth")
    d.set("ForearmL", -4, 10, -10, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes massives
    d.ellipsoid("ThighL", (-5.0, 11.4, 2.2), (3.0, 4.4, 4.2), BODY)
    d.limb("ShinL", (-4.8, 8.4, 0.4), (-4.7, 4.0, 3.6), 2.2, 1.7, BODY)
    d.limb("FootL", (-4.7, 4.0, 3.6), (-4.7, 1.0, 1.2), 1.7, 1.6, BODY)
    d.box("FootL", (-7, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-6, 1, -3), (-3, 1, 1), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, -4))
    # ---------------------------------------------------------------- queue épaisse
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, arcades, symétrie, peinture
    d.eye("Head", "LidL", 23, -17, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.box("Head", (-3, 25, -18), (-3, 25, -16), DARK)  # arcade au-dessus de l'oeil
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    d.back_stripes(["Hips", "Chest", "Neck1", "Neck2", "Head", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK,
                   frac=0.3, period=5, width=2, only=[BODY])
    return d
