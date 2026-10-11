"""Spinosaurus : bipède du Volcano, grand pêcheur à voile, imposant et posé.

Voxels de 0,39 stud : environ 20 studs de long et 12 de haut (voile comprise) à la taille Normal. Long museau de
crocodile, grande voile dorsale (plaque d'un voxel portée par le torse et le bassin, rayée de rayons foncés), bras
robustes à grosses griffes, longue queue."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.39

BODY = (64, 110, 100)
DARK = (40, 74, 68)
BELLY = (232, 220, 186)
SAIL = (232, 98, 52)
SPINE = (166, 54, 42)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 210, 60)
MOUTH = (172, 60, 66)
TONGUE = (212, 100, 104)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.85,          # imposant, pas posés
    "weight": 1.25,
    "stride": 1.0,
    "bob": 0.9,
    "headBob": 0.0,
    "tail": 1.1,
    "diet": "meat",         # Eat : mord et tire (un poisson)
    "happy": "sway",        # pas de tour sur lui-même
    "catch": "headbutt",
}


def build():
    d = Dino("Spinosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 14, 3))
    d.bone("Chest", (0, 14.4, -1.5), "Hips")
    d.bone("Neck1", (0, 16.4, -8.0), "Chest")
    d.bone("Neck2", (0, 18.4, -10.4), "Neck1")
    d.bone("Head", (0, 19.8, -12.4), "Neck2")
    d.bone("Jaw", (0, 19.2, -14.6), "Head")
    d.bone_pair("Lid", (-2.4, 22, -16), "Head")
    d.bone_pair("Arm", (-3.8, 13.0, -6.4), "Chest")
    d.bone_pair("Forearm", (-4.4, 10.2, -7.6), "ArmL")
    d.bone_pair("Thigh", (-4.2, 13.4, 3.4), "Hips")
    d.bone_pair("Shin", (-4.6, 7.6, 0.4), "ThighL")
    d.bone_pair("Foot", (-4.5, 3.6, 3.4), "ShinL")
    tz = [9.6, 13.6, 17.4, 21.0, 24.2, 27.0]
    ty = [14.8, 15.0, 15.0, 14.8, 14.6, 14.4]
    tr = [3.6, 3.0, 2.4, 1.8, 1.3, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 14.6, 4.2), (4.6, 4.4, 6.0), BODY, where=left)
    d.ellipsoid("Chest", (0, 14.4, -3.6), (4.8, 5.0, 5.2), BODY, where=left)
    d.limb("Neck1", (0, 16.2, -7.8), (0, 18.4, -10.4), 3.0, 2.6, BODY, where=left)
    d.limb("Neck2", (0, 18.4, -10.4), (0, 19.8, -12.2), 2.6, 2.4, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne, long museau de crocodile
    d.ellipsoid("Head", (0, 20.8, -14.6), (2.6, 2.4, 3.0), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.6)
    d.limb("Head", (0, 20.6, -17.0), (0, 20.2, -21.6), 1.6, 1.3, BODY, where=lambda x, y, z: x <= 0 and y >= 20)
    d.ellipsoid("Head", (0, 20.4, -23.0), (1.6, 1.4, 1.4), BODY, where=lambda x, y, z: x <= 0 and y >= 20)
    d.ellipsoid("Head", (0, 22.6, -16.4), (0.8, 1.0, 1.4), DARK, where=left)  # petite crête devant les yeux
    d.limb("Jaw", (0, 19.0, -15.0), (0, 19.0, -23.4), 1.5, 1.2, BELLY, where=lambda x, y, z: x <= 0 and y <= 19)
    d.box("Head", (0, 20, -23), (0, 20, -16), MOUTH)
    d.box("Jaw", (0, 19, -22), (0, 19, -16), TONGUE)
    for z in (-23, -21, -19, -17):
        x = d.surface_x(20, z, "Head")
        if x is not None:
            d.set("Head", x, 20, z, TOOTH, "Smooth")
    d.set("Head", -1, 21, -24, DARK, "Smooth")  # narine
    # ---------------------------------------------------------------- bras robustes à grosses griffes
    d.limb("ArmL", (-3.8, 13.0, -6.4), (-4.4, 10.2, -7.6), 1.5, 1.3, BODY)
    d.limb("ForearmL", (-4.4, 10.2, -7.6), (-4.2, 8.6, -10.2), 1.3, 1.1, BODY)
    d.set("ForearmL", -4, 7, -11, CLAW, "Smooth")
    d.set("ForearmL", -3, 7, -11, CLAW, "Smooth")
    d.set("ForearmL", -5, 8, -11, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes
    d.ellipsoid("ThighL", (-4.6, 10.6, 2.0), (2.7, 4.0, 3.8), BODY)
    d.limb("ShinL", (-4.6, 7.6, 0.4), (-4.5, 3.6, 3.4), 1.9, 1.5, BODY)
    d.limb("FootL", (-4.5, 3.6, 3.4), (-4.5, 1.0, 1.0), 1.5, 1.4, BODY)
    d.box("FootL", (-6, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -3), (-3, 1, 1), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, -4))
    # ---------------------------------------------------------------- longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 21, -16, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    d.back_stripes(["Hips", "Chest", "Neck1", "Neck2", "Head", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK,
                   frac=0.25, period=1, width=1, only=[BODY])
    # ---------------------------------------------------------------- voile : plaque d'un voxel au milieu du dos
    # (posée après la peinture du corps ; partagée entre le torse et le bassin selon z)
    sail = [(17.5, -8.0), (23.5, -8.6), (27.6, -6.2), (30.2, -2.6), (30.8, 1.0), (29.8, 4.6), (27.0, 7.6),
            (22.6, 10.0), (18.6, 10.6), (17.5, 0.0)]
    d.plate("Chest", 0, 0, sail, SAIL)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Chest" and col == SAIL and z >= 0:
            d.set("Hips", x, y, z, SAIL)
    # rayons foncés de la voile (un sur trois) et bord supérieur foncé
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if col == SAIL and (z % 3 == 0 or (x, y + 1, z) not in d.vox):
            d.set(bone, x, y, z, SPINE)
    return d
