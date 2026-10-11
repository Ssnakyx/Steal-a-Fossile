"""Pachycephalosaurus : bipède têtu du Canyon, crâne en dôme épais bordé de petites bosses.

Voxels de 0,195 stud : environ 8 studs de long et 5 de haut à la taille Normal.
Son coup de tête (Catch) est son vrai caractère ; dôme crème large et aplati, bosses sombres tout autour."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.195

BODY = (134, 106, 178)
DARK = (90, 68, 130)
BELLY = (236, 228, 218)
DOME = (246, 232, 196)
KNOB = (110, 84, 70)
BEAK = (214, 190, 150)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 210, 70)
MOUTH = (182, 72, 80)

PERSONALITY = {
    "tempo": 1.05,
    "weight": 1.1,
    "stride": 0.95,
    "bob": 1.0,
    "headBob": 0.4,
    "tail": 0.9,
    "diet": "plants",
    "happy": "hop",
    "catch": "headbutt",    # coup de tête avec le dôme
}


def build():
    d = Dino("Pachycephalosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 12, 3))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.2, -5.0), "Chest")
    d.bone("Neck2", (0, 16.4, -6.8), "Neck1")
    d.bone("Head", (0, 18.2, -8.2), "Neck2")
    d.bone("Jaw", (0, 17.6, -11.0), "Head")
    d.bone_pair("Lid", (-2.8, 20, -12), "Head")
    d.bone_pair("Arm", (-3.6, 11.4, -5.2), "Chest")
    d.bone_pair("Forearm", (-4.0, 9.4, -6.0), "ArmL")
    d.bone_pair("Thigh", (-3.8, 11.4, 3), "Hips")
    d.bone_pair("Shin", (-4.0, 6.6, 0.6), "ThighL")
    d.bone_pair("Foot", (-4.0, 3.2, 3.4), "ShinL")
    tz = [7.6, 11.2, 14.8, 18.2, 21.4, 24.4]
    ty = [12.4, 12.8, 13.0, 13.1, 13.1, 13.0]
    tr = [3.6, 2.9, 2.2, 1.6, 1.1, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps trapu
    d.ellipsoid("Hips", (0, 12.2, 3.6), (4.0, 3.9, 4.8), BODY, where=left)
    d.ellipsoid("Chest", (0, 11.8, -2.4), (4.0, 4.2, 4.2), BODY, where=left)
    d.limb("Neck1", (0, 13.8, -4.6), (0, 16.4, -6.8), 3.0, 2.7, BODY, where=left)
    d.limb("Neck2", (0, 16.4, -6.8), (0, 18.2, -8.2), 2.7, 2.6, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne, dôme crème aplati, museau court à bec
    d.ellipsoid("Head", (0, 19.4, -10.2), (3.0, 2.6, 3.0), BODY, where=left, power=2.4)
    d.ellipsoid("Head", (0, 21.0, -10.0), (3.2, 3.4, 3.5), DOME, where=lambda x, y, z: x <= 0 and y >= 20, power=2.1)
    d.ellipsoid("Head", (0, 18.6, -13.4), (1.8, 1.6, 1.9), BODY, where=lambda x, y, z: x <= 0 and y >= 18, power=2.3)
    d.box("Head", (-1, 18, -15), (0, 18, -15), BEAK)
    d.ellipsoid("Jaw", (0, 17.4, -12.8), (1.5, 0.9, 2.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 17, power=2.3)
    d.set("Jaw", -1, 17, -15, BEAK)
    d.set("Jaw", 0, 17, -15, BEAK)
    d.box("Jaw", (-1, 17, -11), (0, 17, -10), BODY)
    d.box("Head", (0, 18, -14), (0, 18, -11), MOUTH)
    # bosses sombres : sur les côtés et l'arrière du dôme (loin de l'oeil), deux sur le museau
    def bump_side(y, z):
        sx = d.surface_x(y, z, "Head")
        if sx is not None:
            d.set("Head", sx - 1, y, z, KNOB, "Smooth")

    def bump_back(x, y):
        zs = [k[2] for k, v in d.vox.items() if k[0] == x and k[1] == y and v[0] == "Head"]
        if zs:
            d.set("Head", x, y, max(zs) + 1, KNOB, "Smooth")
    for y, z in ((21, -7), (20, -8), (21, -13), (22, -9)):
        bump_side(y, z)
    for x, y in ((-2, 21), (0, 23), (-1, 20), (-2, 23)):
        bump_back(x, y)
    for z in (-15, -14):
        top = d.surface_y(-1, z, "Head")
        if top is not None:
            d.set("Head", -1, top + 1, z, KNOB, "Smooth")
    # ---------------------------------------------------------------- petits bras
    d.limb("ArmL", (-3.6, 11.4, -5.2), (-4.0, 9.4, -6.0), 1.2, 1.0, BODY)
    d.limb("ForearmL", (-4.0, 9.4, -6.0), (-3.8, 8.2, -7.8), 0.9, 0.8, BODY)
    for p in ((-4, 7, -8), (-3, 7, -8), (-4, 8, -9)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes solides
    d.ellipsoid("ThighL", (-4.0, 9.2, 1.8), (2.2, 3.4, 3.0), BODY)
    d.limb("ShinL", (-4.0, 6.6, 0.6), (-4.0, 3.2, 3.4), 1.6, 1.3, BODY)
    d.limb("FootL", (-4.0, 3.2, 3.4), (-4.0, 0.9, 1.0), 1.3, 1.2, BODY)
    d.box("FootL", (-5, 0, -2), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -1), (-3, 1, 1), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -2.5))
    # ---------------------------------------------------------------- queue raide
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 18, -12, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.3, period=4, width=2,
                   only=[BODY])
    return d
