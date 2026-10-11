"""Dracorex : bipède du Volcano, pachycéphalosaure à tête de dragon, têtu et vif.

Voxels de 0,23 stud : environ 10 studs de long et 6 de haut à la taille Normal. Crâne plat et bas couvert de bosses,
couronne de piques à l'arrière du crâne (bout couleur braise), petites cornes sur le museau et les joues ; corps
charbon à rayures rouge sombre, ventre cendre, queue raide. Son coup de tête (Catch) reste son vrai caractère."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.23

BODY = (74, 70, 78)
DARK = (138, 38, 36)
BELLY = (172, 154, 142)
HORN = (100, 92, 98)
EMBER = (255, 124, 36)
KNOB = (104, 96, 100)
BEAK = (44, 40, 46)
CLAW = (226, 214, 196)
PUPIL = (30, 16, 12)
IRIS = (255, 178, 48)
MOUTH = (150, 42, 46)

PERSONALITY = {
    "tempo": 1.15,          # vif et têtu
    "weight": 1.0,
    "stride": 0.95,
    "bob": 1.0,
    "headBob": 0.4,
    "tail": 0.9,
    "diet": "plants",
    "happy": "hop",
    "catch": "headbutt",    # coup de tête, couronne de piques en avant
}


def build():
    d = Dino("Dracorex", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 12, 3))
    d.bone("Chest", (0, 12, -0.5), "Hips")
    d.bone("Neck1", (0, 14.2, -5.0), "Chest")
    d.bone("Neck2", (0, 16.2, -6.8), "Neck1")
    d.bone("Head", (0, 17.8, -8.4), "Neck2")
    d.bone("Jaw", (0, 17.0, -11.2), "Head")
    d.bone_pair("Lid", (-2.8, 20, -12.5), "Head")
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

    def spike(bone, base, tip, rb, rt=0.3, ember=0.4):
        """Pique de corne : base claire, bout braise (part `ember` de la longueur)."""
        mid = tuple(base[i] + (tip[i] - base[i]) * (1 - ember) for i in range(3))
        rm = rb + (rt - rb) * (1 - ember)
        d.limb(bone, base, mid, rb, rm, HORN)
        d.limb(bone, mid, tip, rm, rt, EMBER)

    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 12.2, 3.6), (4.0, 3.9, 4.8), BODY, where=left)
    d.ellipsoid("Chest", (0, 11.8, -2.4), (4.0, 4.2, 4.2), BODY, where=left)
    d.limb("Neck1", (0, 13.8, -4.6), (0, 16.2, -6.8), 3.0, 2.7, BODY, where=left)
    d.limb("Neck2", (0, 16.2, -6.8), (0, 17.8, -8.4), 2.7, 2.6, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne plat et large, long museau bas
    d.ellipsoid("Head", (0, 19.0, -10.8), (3.3, 2.4, 3.2), BODY, where=lambda x, y, z: x <= 0 and y >= 17, power=2.9)
    d.ellipsoid("Head", (0, 18.3, -15.4), (2.1, 1.7, 3.6), BODY, where=lambda x, y, z: x <= 0 and y >= 17, power=2.6)
    d.box("Head", (-1, 17, -19), (0, 17, -19), BEAK)
    d.ellipsoid("Jaw", (0, 16.6, -14.6), (1.7, 0.9, 3.6), BELLY, where=lambda x, y, z: x <= 0 and y <= 16, power=2.4)
    d.box("Jaw", (-1, 16, -18), (0, 16, -18), BEAK)
    d.box("Jaw", (-1, 16, -11), (0, 16, -10), BODY)
    d.box("Head", (0, 17, -18), (0, 17, -11), MOUTH)
    d.set("Head", -1, 18, -19, KNOB, "Smooth")  # narine
    # ---------------------------------------------------------------- bosses sur le crâne plat, cornes du museau
    for x, z in ((-2, -10), (0, -11), (-1, -13), (-3, -12), (-2, -8)):
        top = d.surface_y(x, z, "Head")
        if top is not None:
            d.set("Head", x, top + 1, z, KNOB, "Smooth")
    for x, z, h in ((-1, -16, 2.2), (0, -18, 1.6)):
        top = d.surface_y(x, z, "Head")
        if top is not None:
            spike("Head", (x, top + 0.5, z), (x, top + 0.5 + h, z - 0.8), 0.9, 0.3, ember=0.5)
    # ---------------------------------------------------------------- couronne de piques à l'arrière du crâne
    spike("Head", (-1.8, 20.6, -9.0), (-3.0, 25.8, -4.4), 1.35, 0.35)
    spike("Head", (-3.0, 19.6, -9.0), (-7.0, 21.6, -5.0), 1.3, 0.35)
    spike("Head", (-3.2, 18.2, -9.4), (-6.6, 16.4, -6.2), 1.2, 0.35)
    spike("Head", (0, 20.8, -8.8), (0, 24.2, -5.0), 1.1, 0.35)
    # petites cornes des joues, sous l'oeil
    spike("Head", (-2.8, 17.6, -12.6), (-5.0, 16.6, -11.8), 0.9, 0.3, ember=0.5)
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
    d.eye("Head", "LidL", 18, -13, IRIS, PUPIL, lid_color=KNOB, h=2, w=2)
    # arcade sourcilière en saillie au-dessus de l'oeil (regard de dragon)
    for z in (-14, -13, -12):
        x = d.surface_x(21, z, "Head")
        if x is not None:
            d.set("Head", x - 1, 21, z, KNOB)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    d.back_stripes(["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.32,
                   period=4, width=2, only=[BODY])
    return d
