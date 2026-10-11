"""Stegosaurus : quadrupède de la Fern Forest, lent et placide, dos voûté couvert de plaques.

Voxels de 0,28 stud : environ 14 studs de long et 7 de haut (plaques comprises) à la taille Normal.
Petite tête basse, pattes avant courtes, deux rangées de plaques en quinconce (portées par les os du corps et de la
queue, pas un os à part : elles suivent le dos), quatre pointes au bout de la queue."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.28

BODY = (72, 142, 132)
DARK = (46, 100, 96)
BELLY = (228, 222, 192)
PLATE = (240, 130, 56)
PLATE_TOP = (214, 70, 48)
SPIKE = (246, 238, 216)
BEAK = (70, 62, 58)
NAIL = (232, 226, 204)
PUPIL = (26, 22, 20)
IRIS = (255, 214, 90)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.75,          # lent et placide
    "weight": 1.45,
    "stride": 0.9,
    "bob": 0.9,
    "headBob": 0.0,
    "tail": 0.7,            # queue lourde à pointes : balance moins
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
}

# os qui porte la plaque selon sa position le long du dos (z en voxels)
SEGMENTS = [(-99, -6, "Neck1"), (-6, 1, "Chest"), (1, 11, "Hips"), (11, 15, "Tail1"), (15, 19, "Tail2"), (19, 23, "Tail3")]


def seg_of(z):
    for a, b, bone in SEGMENTS:
        if a <= z < b:
            return bone
    return "Tail4"


def build():
    d = Dino("Stegosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 11, 4))
    d.bone("Chest", (0, 9.4, -1.5), "Hips")
    d.bone("Neck1", (0, 8.6, -7.6), "Chest")
    d.bone("Head", (0, 7.6, -11.0), "Neck1")
    d.bone("Jaw", (0, 6.6, -13.0), "Head")
    d.bone_pair("Lid", (-2.2, 9, -13.5), "Head")
    d.bone_pair("Arm", (-4.4, 7.4, -5.0), "Chest")
    d.bone_pair("Forearm", (-4.8, 4.4, -3.6), "ArmL")
    d.bone_pair("Hand", (-4.8, 1.8, -5.4), "ForearmL")
    d.bone_pair("Thigh", (-4.8, 10.6, 5.5), "Hips")
    d.bone_pair("Shin", (-5.2, 5.6, 3.4), "ThighL")
    d.bone_pair("Foot", (-5.2, 2.4, 6.2), "ShinL")
    tz = [11.0, 15.0, 19.0, 23.0, 27.0, 30.6]
    ty = [12.4, 12.6, 12.2, 11.6, 11.0, 10.6]
    tr = [4.4, 3.4, 2.6, 1.9, 1.3, 0.9]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps voûté (hanches hautes, épaules basses)
    d.ellipsoid("Hips", (0, 12.2, 5.0), (5.2, 5.8, 6.4), BODY, where=left, power=2.5)
    d.ellipsoid("Chest", (0, 9.8, -2.4), (4.6, 4.8, 5.0), BODY, where=left, power=2.5)
    d.limb("Neck1", (0, 9.4, -6.6), (0, 7.8, -10.8), 3.0, 2.3, BODY, where=left)
    # ---------------------------------------------------------------- petite tête basse à bec
    d.ellipsoid("Head", (0, 8.0, -13.0), (2.2, 2.0, 2.8), BODY, where=left, power=2.3)
    d.ellipsoid("Head", (0, 7.4, -15.8), (1.5, 1.3, 1.4), BEAK, where=lambda x, y, z: x <= 0 and y >= 7)
    d.ellipsoid("Jaw", (0, 6.4, -14.2), (1.5, 0.9, 2.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 6, power=2.3)
    d.ellipsoid("Jaw", (0, 6.4, -16.0), (1.1, 0.8, 0.9), BEAK, where=lambda x, y, z: x <= 0 and y <= 6)
    d.box("Jaw", (-1, 6, -12), (0, 6, -11), BODY)
    for z in range(-16, -11):
        if (0, 7, z) in d.vox:
            d.set("Head", 0, 7, z, MOUTH)
    # ---------------------------------------------------------------- pattes : piliers, avant courtes
    d.limb("ArmL", (-4.4, 7.4, -5.0), (-4.8, 4.4, -3.6), 2.0, 1.7, BODY)
    d.limb("ForearmL", (-4.8, 4.4, -3.6), (-4.8, 1.8, -5.4), 1.6, 1.4, BODY)
    d.limb("HandL", (-4.8, 1.8, -5.4), (-4.8, 0.7, -5.8), 1.4, 1.4, BODY)
    d.box("HandL", (-6, 0, -7), (-3, 1, -5), BODY)
    for x in (-6, -4):
        d.set("HandL", x, 0, -8, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-5.2, 8.0, 5.0), (2.8, 4.4, 3.6), BODY)
    d.limb("ShinL", (-5.2, 5.6, 3.4), (-5.2, 2.4, 6.2), 2.2, 1.8, BODY)
    d.limb("FootL", (-5.2, 2.4, 6.2), (-5.2, 0.8, 4.4), 1.8, 1.8, BODY)
    d.box("FootL", (-7, 0, 2), (-3, 1, 6), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 2))
    d.point("FrontToeL", "HandL", (-4.5, 0, -7))
    # ---------------------------------------------------------------- queue et pointes (thagomizer)
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    d.limb("Tail5", (-1, 11.6, 27.8), (-4.6, 15.6, 28.6), 1.0, 0.4, SPIKE, "Smooth")
    d.limb("Tail5", (-1, 11.2, 30.2), (-5.6, 12.8, 32.4), 1.0, 0.4, SPIKE, "Smooth")
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 8, -14, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 8, "Chest": 6, "Neck1": 7, "Tail1": 10, "Tail2": 10, "Tail3": 10}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4"], DARK, frac=0.22, period=5, width=2, only=[BODY])
    # ---------------------------------------------------------------- plaques en quinconce (après la symétrie)
    # (z du centre, hauteur, demi-longueur, côté) : petites sur le cou, grandes sur les hanches
    plates = [(-8.5, 3.0, 1.4, -1), (-6.0, 3.6, 1.6, 1), (-3.4, 4.4, 1.8, -1), (-0.6, 5.2, 2.0, 1), (2.4, 6.2, 2.2, -1),
              (5.4, 6.8, 2.4, 1), (8.4, 6.6, 2.4, -1), (11.4, 5.8, 2.2, 1), (14.4, 4.8, 2.0, -1), (17.2, 3.8, 1.8, 1),
              (19.8, 3.0, 1.5, -1), (22.2, 2.4, 1.3, 1)]
    for zc, h, half, side in plates:
        zi = int(round(zc))
        base = d.surface_y(side, zi)
        if base is None:
            continue
        bone = seg_of(zc)
        y0 = base - 1
        poly = [(y0, zc - half), (y0 + 0.55 * h, zc - half - 0.2), (y0 + h + 1, zc), (y0 + 0.55 * h, zc + half + 0.2),
                (y0, zc + half)]
        xs = (-2, -1) if side < 0 else (1, 2)
        for x in xs:
            d.plate(bone, 0, x, poly, PLATE)
        for (x, y, z), (b, col, mat) in list(d.vox.items()):
            if b == bone and col == PLATE and x in xs and abs(z - zc) <= half + 0.7 and y >= y0 + 0.62 * (h + 1):
                d.vox[(x, y, z)] = (b, PLATE_TOP, mat)
    return d
