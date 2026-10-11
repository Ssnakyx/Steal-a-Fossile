"""Cryolophosaurus : bipède du Glacier, chasseur à crête, vif et fier.

Voxels de 0,33 stud : environ 15 studs de long et 9 de haut (crête comprise) à la taille Normal. Grosse tête au long
museau, crête en éventail posée en travers du crâne (plaque droite), bras courts, queue en six segments.
Gardien du Glacier (zone 5) : cette espèce x2 (Scale = 2, environ 30 studs de long)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.33

BODY = (70, 118, 184)
DARK = (44, 74, 126)
BELLY = (226, 236, 244)
CREST = (255, 198, 48)
RIM = (238, 112, 40)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 150, 40)
MOUTH = (176, 56, 66)
TONGUE = (214, 98, 104)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 1.05,
    "weight": 1.0,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.3,
    "tail": 1.0,
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("Cryolophosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 13, 2))
    d.bone("Chest", (0, 13.2, -1.5), "Hips")
    d.bone("Neck1", (0, 15.0, -7.2), "Chest")
    d.bone("Neck2", (0, 17.4, -9.6), "Neck1")
    d.bone("Head", (0, 19.4, -11.4), "Neck2")
    d.bone("Jaw", (0, 18.0, -13.4), "Head")
    d.bone("Crest", (0, 22.4, -13.5), "Head")
    d.bone_pair("Lid", (-2.6, 21, -16), "Head")
    d.bone_pair("Arm", (-3.6, 12.0, -6.0), "Chest")
    d.bone_pair("Forearm", (-4.2, 9.8, -7.2), "ArmL")
    d.bone_pair("Thigh", (-4.0, 12.4, 2.4), "Hips")
    d.bone_pair("Shin", (-4.4, 7.0, -0.4), "ThighL")
    d.bone_pair("Foot", (-4.3, 3.4, 2.8), "ShinL")
    tz = [8.2, 11.8, 15.2, 18.4, 21.4, 24.0]
    ty = [13.4, 13.8, 14.0, 14.2, 14.3, 14.4]
    tr = [3.6, 3.0, 2.4, 1.8, 1.3, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 13.4, 3.4), (4.4, 4.2, 5.4), BODY, where=left)
    d.ellipsoid("Chest", (0, 13.0, -3.6), (4.6, 4.8, 4.8), BODY, where=left)
    d.limb("Neck1", (0, 14.8, -7.0), (0, 17.4, -9.6), 3.0, 2.7, BODY, where=left)
    d.limb("Neck2", (0, 17.4, -9.6), (0, 19.4, -11.2), 2.7, 2.6, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête : crâne, long museau, mâchoire
    d.ellipsoid("Head", (0, 20.4, -13.6), (3.0, 2.8, 3.4), BODY, where=left, power=2.6)
    d.ellipsoid("Head", (0, 19.6, -18.2), (2.2, 2.0, 3.4), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.4)
    d.ellipsoid("Jaw", (0, 17.8, -16.8), (2.0, 1.1, 4.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.6)
    d.box("Jaw", (-1, 18, -14), (0, 18, -13), BODY)
    d.box("Head", (0, 19, -20), (0, 19, -15), MOUTH)
    d.box("Jaw", (0, 18, -19), (0, 18, -15), TONGUE)
    for z in (-20, -18, -16):
        d.set("Head", -1, 19, z, TOOTH, "Smooth")
    d.set("Head", -1, 21, -21, DARK, "Smooth")  # narine
    # crête en éventail : plaque droite de deux voxels, bord du haut en dents arrondies
    crest = [(-2.6, 21.0), (-4.0, 23.0), (-4.4, 25.0), (-3.6, 26.4), (-2.8, 25.6), (-2.0, 27.4), (-1.2, 26.4),
             (-0.4, 28.4), (0.4, 28.4), (0.4, 21.0)]
    d.plate("Crest", 2, -14, crest, CREST, thick=2)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Crest" and (x, y + 1, z) not in d.vox:
            d.set("Crest", x, y, z, RIM)
    # ---------------------------------------------------------------- bras courts
    d.limb("ArmL", (-3.6, 12.0, -6.0), (-4.2, 9.8, -7.2), 1.4, 1.2, BODY)
    d.limb("ForearmL", (-4.2, 9.8, -7.2), (-4.0, 8.6, -9.6), 1.1, 0.9, BODY)
    d.set("ForearmL", -4, 7, -10, CLAW, "Smooth")
    d.set("ForearmL", -3, 7, -10, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes
    d.ellipsoid("ThighL", (-4.4, 9.8, 1.0), (2.6, 3.8, 3.6), BODY)
    d.limb("ShinL", (-4.4, 7.0, -0.4), (-4.3, 3.4, 2.8), 1.8, 1.4, BODY)
    d.limb("FootL", (-4.3, 3.4, 2.8), (-4.3, 1.0, 0.6), 1.4, 1.3, BODY)
    d.box("FootL", (-6, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -3), (-3, 1, 1), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, -4))
    # ---------------------------------------------------------------- queue en six segments
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 19, -16, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    d.back_stripes(["Hips", "Chest", "Neck1", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.32, period=5,
                   width=2, only=[BODY])
    return d
