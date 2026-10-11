"""Golden Raptor : Secret, raptor doré à plumes, rapide et fier.

Voxels de 0,3 stud (comme le Velociraptor) : environ 14 studs de long et 9 de haut (plumes comprises) à la taille
Normal. Corps doré rayé d'ambre, éventail de trois plumes sur la tête (plaque droite), ailerons de plumes sur les bras,
éventail de plumes au bout de la queue, yeux rubis. Différent du Velociraptor « Golden » de la fusion (simple teinte)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.3

GOLD = (250, 192, 40)
AMBER = (228, 128, 28)
BELLY = (255, 238, 176)
PLUME = (252, 250, 242)
TIP = (214, 40, 72)
CLAW = (252, 250, 242)
PUPIL = (30, 16, 20)
IRIS = (224, 36, 64)
MOUTH = (176, 56, 66)
TONGUE = (214, 98, 104)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 1.25,          # le plus vif des raptors
    "weight": 0.8,
    "stride": 1.05,
    "bob": 1.0,
    "headBob": 1.0,
    "tail": 1.1,
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("GoldenRaptor", FAMILY, voxel=VOXEL, display="Golden Raptor")
    # ---------------------------------------------------------------- os (squelette du Velociraptor)
    d.bone("Hips", (0, 12, 2))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.5, -6.2), "Chest")
    d.bone("Neck2", (0, 17.2, -8.6), "Neck1")
    d.bone("Head", (0, 19.6, -10.4), "Neck2")
    d.bone("Jaw", (0, 18.8, -12.2), "Head")
    d.bone("Crest", (0, 22.6, -11.6), "Head")
    d.bone_pair("Lid", (-2.6, 21, -15), "Head")
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
    d.ellipsoid("Hips", (0, 12, 3.5), (3.8, 3.7, 5.0), GOLD, where=left)
    d.ellipsoid("Chest", (0, 11.8, -3.0), (4.1, 4.3, 4.6), GOLD, where=left)
    d.limb("Neck1", (0, 14.0, -6.0), (0, 17.2, -8.6), 2.8, 2.4, GOLD, where=left)
    d.limb("Neck2", (0, 17.2, -8.6), (0, 19.6, -10.2), 2.4, 2.3, GOLD, where=left)
    # ---------------------------------------------------------------- tête : crâne, museau, mâchoire
    d.ellipsoid("Head", (0, 21.0, -12.8), (3.1, 2.8, 3.4), GOLD, where=left, power=2.8)
    d.ellipsoid("Head", (0, 20.3, -16.8), (2.2, 1.9, 3.3), GOLD, where=lambda x, y, z: x <= 0 and y >= 19, power=2.4)
    d.ellipsoid("Jaw", (0, 18.2, -15.6), (1.9, 1.0, 3.8), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.6)
    d.box("Jaw", (-1, 18, -13), (0, 18, -12), GOLD)
    d.box("Head", (0, 19, -18), (0, 19, -13), MOUTH)
    d.box("Jaw", (0, 18, -17), (0, 18, -14), TONGUE)
    for z in (-18, -16, -14):
        d.set("Head", -1, 19, z, TOOTH, "Smooth")
    d.set("Head", -1, 21, -19, AMBER, "Smooth")  # narine
    # éventail de trois plumes sur la tête (plaque droite d'un voxel, pointes rubis)
    crest = [(22.0, -13.4), (28.4, -11.6), (25.0, -10.6), (27.4, -8.4), (24.4, -8.6), (25.0, -5.4), (22.0, -8.4)]
    d.plate("Crest", 0, -1, crest, PLUME, thick=2)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Crest" and y >= 25 and ((x, y + 1, z) not in d.vox or (x, y + 2, z) not in d.vox):
            d.set("Crest", x, y, z, TIP)
    # ---------------------------------------------------------------- bras avec ailerons de plumes
    d.limb("ArmL", (-3.0, 11.5, -6.2), (-3.6, 9.6, -7.6), 1.3, 1.1, GOLD)
    d.limb("ForearmL", (-3.6, 9.6, -7.6), (-3.4, 8.4, -9.8), 1.0, 0.8, GOLD)
    d.set("ForearmL", -4, 7, -10, CLAW, "Smooth")
    d.set("ForearmL", -3, 7, -10, CLAW, "Smooth")
    d.plate("ForearmL", 0, -4, [(9.8, -7.0), (8.4, -9.8), (5.4, -7.6), (6.4, -5.0)], PLUME)
    d.plate("ArmL", 0, -4, [(11.4, -5.6), (9.8, -7.0), (6.4, -5.0), (8.8, -3.8)], PLUME)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone in ("ArmL", "ForearmL") and col == PLUME and (x, y - 1, z) not in d.vox:
            d.set(bone, x, y, z, TIP)
    # ---------------------------------------------------------------- pattes
    d.ellipsoid("ThighL", (-4.0, 9.2, 0.6), (2.3, 3.4, 3.2), GOLD)
    d.limb("ShinL", (-3.8, 6.5, -0.6), (-3.7, 3.2, 2.6), 1.6, 1.3, GOLD)
    d.limb("FootL", (-3.7, 3.2, 2.6), (-3.7, 0.9, 0.4), 1.3, 1.2, GOLD)
    d.box("FootL", (-5, 0, -3), (-3, 0, 1), GOLD)
    d.box("FootL", (-4, 1, -2), (-3, 1, 1), GOLD)
    for x in (-5, -3):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.set("FootL", -2, 1, -1, CLAW, "Smooth")       # griffe en faucille relevée
    d.set("FootL", -2, 2, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -3.5))
    # ---------------------------------------------------------------- queue et éventail de plumes au bout
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], GOLD, where=left)
    d.plate("Tail5", 1, 14, [(0.4, 21.6), (-2.6, 23.4), (-3.6, 26.2), (-2.0, 25.6), (-1.2, 28.0), (0.4, 28.0)], PLUME)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Tail5" and col == PLUME and z >= 25:
            d.set("Tail5", x, y, z, TIP)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 20, -15, IRIS, PUPIL, lid_color=AMBER, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.28, only=[GOLD])
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], AMBER, frac=0.3, period=4, width=2,
                   only=[GOLD])
    return d
