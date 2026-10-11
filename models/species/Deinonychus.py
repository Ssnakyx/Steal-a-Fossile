"""Deinonychus : grand raptor à plumes du Swamp, rapide et redoutable.

Voxels de 0,22 stud : environ 11 studs de long et 6 de haut à la taille Normal. Plus massif que le Velociraptor :
grosse tête haute à dents blanches, bras-ailes couverts de longues plumes (plaques d'un voxel posées à l'extérieur
du bras, pointes orange), crinière de plumes de la nuque aux épaules, énorme griffe en faucille relevée sur chaque
pied, longue queue raide terminée par un éventail de plumes en losange. Sarcelle foncé rayé de vert nuit, gorge et
pointes des plumes orange, ventre crème."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.22

BODY = (30, 104, 112)
DARK = (18, 62, 70)
BELLY = (236, 222, 188)
THROAT = (244, 130, 40)
TIP = (250, 146, 46)
CLAW = (246, 240, 226)
PUPIL = (24, 18, 16)
IRIS = (255, 206, 60)
MOUTH = (172, 52, 60)
TONGUE = (214, 98, 104)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 1.2,           # chasseur vif
    "weight": 0.95,         # plus lourd que le Velociraptor
    "stride": 1.05,
    "bob": 1.0,
    "headBob": 1.0,
    "tail": 0.9,            # queue raide
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("Deinonychus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 12, 2))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.6, -6.2), "Chest")
    d.bone("Neck2", (0, 17.4, -8.6), "Neck1")
    d.bone("Head", (0, 19.8, -10.4), "Neck2")
    d.bone("Jaw", (0, 18.8, -12.4), "Head")
    d.bone_pair("Lid", (-2.8, 23, -15), "Head")
    d.bone_pair("Arm", (-3.4, 11.6, -6.0), "Chest")
    d.bone_pair("Forearm", (-4.0, 9.4, -7.4), "ArmL")
    d.bone_pair("Thigh", (-3.8, 11.6, 2), "Hips")
    d.bone_pair("Shin", (-4.0, 6.5, -0.6), "ThighL")
    d.bone_pair("Foot", (-3.9, 3.2, 2.6), "ShinL")
    tz = [7.6, 11.2, 14.8, 18.2, 21.4, 24.6]
    tr = [3.6, 3.0, 2.3, 1.7, 1.2, 0.8]
    ty = [12.4, 12.9, 13.3, 13.6, 13.8, 14.0]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps massif
    d.ellipsoid("Hips", (0, 12, 3.4), (4.2, 4.0, 5.2), BODY, where=left)
    d.ellipsoid("Chest", (0, 11.8, -3.0), (4.6, 4.7, 4.8), BODY, where=left)
    d.limb("Neck1", (0, 14.0, -6.0), (0, 17.4, -8.6), 3.1, 2.7, BODY, where=left)
    d.limb("Neck2", (0, 17.4, -8.6), (0, 19.8, -10.2), 2.7, 2.6, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête haute, mâchoire séparée
    d.ellipsoid("Head", (0, 21.2, -12.8), (3.4, 3.1, 3.6), BODY, where=left, power=2.6)
    d.ellipsoid("Head", (0, 20.6, -17.0), (2.5, 2.3, 3.6), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.4)
    d.ellipsoid("Jaw", (0, 18.2, -16.0), (2.1, 1.2, 4.0), THROAT, where=lambda x, y, z: x <= 0 and y <= 18, power=2.6)
    d.box("Jaw", (-1, 17, -13), (0, 18, -12), THROAT)
    # palais rouge (vu quand la gueule s'ouvre), langue, rangée de dents blanches au bord
    d.box("Head", (0, 19, -19), (0, 19, -13), MOUTH)
    d.box("Jaw", (0, 18, -18), (0, 18, -14), TONGUE)
    for z in (-20, -18, -16, -14):
        x = d.surface_x(19, z, "Head")
        if x is not None:
            d.set("Head", x, 19, z, TOOTH, "Smooth")
    d.set("Head", -1, 21, -20, DARK, "Smooth")  # narine
    # ---------------------------------------------------------------- bras-ailes : longues plumes, griffes
    d.limb("ArmL", (-3.4, 11.6, -6.0), (-4.0, 9.4, -7.4), 1.4, 1.2, BODY)
    d.limb("ForearmL", (-4.0, 9.4, -7.4), (-3.8, 7.8, -10.2), 1.1, 0.9, BODY)
    d.set("ForearmL", -4, 7, -11, CLAW, "Smooth")
    d.set("ForearmL", -3, 7, -11, CLAW, "Smooth")
    d.set("ForearmL", -4, 6, -11, CLAW, "Smooth")
    d.plate("ForearmL", 0, -5, [(10.2, -7.0), (8.4, -10.8), (6.2, -11.4), (5.2, -10.0), (6.6, -9.4), (5.8, -8.2),
                                (7.2, -7.6), (7.0, -6.2), (8.4, -5.8), (9.6, -5.6)], BODY)
    d.plate("ArmL", 0, -5, [(12.4, -5.4), (10.2, -7.2), (9.6, -5.6), (8.2, -5.4), (8.6, -4.0), (10.6, -3.8)], BODY)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone in ("ArmL", "ForearmL") and x == -5 and col == BODY:
            tip = any((x, y - k, z) not in d.vox for k in (1, 2)) and y <= 8
            d.set(bone, x, y, z, TIP if tip else DARK)
    # ---------------------------------------------------------------- pattes puissantes, griffe en faucille
    d.ellipsoid("ThighL", (-4.2, 9.2, 0.6), (2.5, 3.6, 3.4), BODY)
    d.limb("ShinL", (-4.0, 6.5, -0.6), (-3.9, 3.2, 2.6), 1.8, 1.4, BODY)
    d.limb("FootL", (-3.9, 3.2, 2.6), (-3.9, 0.9, 0.4), 1.4, 1.2, BODY)
    d.box("FootL", (-5, 0, -3), (-3, 0, 1), BODY)
    d.box("FootL", (-4, 1, -2), (-3, 1, 1), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.set("FootL", -2, 1, 1, BODY)
    d.set("FootL", -2, 1, 0, BODY)
    for p in ((-2, 2, 0), (-2, 3, -1), (-2, 3, -2), (-2, 2, -3), (-2, 1, -3)):     # grande griffe en faucille relevée
        d.set("FootL", *p, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -3.5))
    # ---------------------------------------------------------------- longue queue raide, éventail en losange
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # éventail de plumes au bout de la queue : grand losange à bord dentelé (une plume tous les 3 voxels),
    # porté par les deux derniers segments
    for z in range(17, 32):
        env = 1.8 + 5.6 * ((z - 17) / 8.0) ** 0.9 if z <= 25 else 7.4 * (31.8 - z) / 6.8
        w = int(env + (1.3 if z % 3 == 1 else 0.0))
        bone = "Tail4" if z < 21 else "Tail5"
        for x in range(-w, 1):
            if (x, 14, z) not in d.vox:
                d.set(bone, x, 14, z, BODY)
    # ---------------------------------------------------------------- plumet couché derrière la tête : trois
    # mèches de plumes horizontales, la plus haute la plus longue
    for y, z0, z1 in ((25, -13, -4), (24, -11, -5), (23, -10, -7)):
        for z in range(z0, z1 + 1):
            for x in (-1, 0):
                if x == -1 and z >= z1 - 1 and y == 25:
                    continue
                d.set("Head", x, y, z, DARK)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 21, -15, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3"]
    d.countershade(body, BELLY, frac=0.28, only=[BODY])
    d.paint(lambda x, y, z, bone, c: THROAT if bone in ("Neck1", "Neck2") and c == BELLY else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.3, period=4, width=2,
                   only=[BODY])
    d.paint(lambda x, y, z, bone, c: shade(BODY, -0.12) if bone == "Head" and c == BODY and y >= 23 else None)
    # pointes orange : bande extérieure de l'éventail de queue, bouts du plumet
    fan = {(x, z) for (x, y, z), v in d.vox.items() if y == 14 and v[0] in ("Tail4", "Tail5")}
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone in ("Tail4", "Tail5") and y == 14 and col in (BODY, DARK):
            out = 1 if x > 0 else -1
            far = (x + 2 * out, z) not in fan or (x, z + 2) not in fan or (x + out, z + 1) not in fan
            if far and (abs(x) >= 2 or z >= 28):
                d.set(bone, x, y, z, TIP)
        if bone == "Head" and col == DARK and abs(x) <= 1 and y >= 23 and (x, y, z + 2) not in d.vox:
            d.set(bone, x, y, z, TIP)
    return d
