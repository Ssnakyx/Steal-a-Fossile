"""Ceratosaurus : bipède du Volcano, prédateur à cornes, rusé et nerveux.

Voxels de 0,32 stud : environ 16 studs de long et 9 de haut à la taille Normal. Grosse tête à longues dents, haute
corne nasale en lame et deux petites cornes au-dessus des yeux (rouges), rangée de petites plaques osseuses au milieu
du dos (de la nuque au bout de la queue), queue haute et étroite, petits bras. Noir à bandes rouge-orangé."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.32

BODY = (50, 46, 54)
BAND = (226, 88, 40)
BELLY = (206, 168, 134)
HORN = (212, 40, 38)
PLATE = (170, 34, 34)
CLAW = (238, 228, 212)
PUPIL = (26, 18, 14)
IRIS = (255, 206, 60)
MOUTH = (140, 34, 40)
TONGUE = (200, 90, 96)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 1.0,
    "weight": 1.05,
    "stride": 1.05,
    "bob": 1.0,
    "headBob": 0.2,
    "tail": 1.1,
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",    # coup de tête, corne en avant
}

# os qui porte une plaque du dos selon sa position (z en voxels)
SEGMENTS = [(-99, -8.6, "Neck2"), (-8.6, -6.6, "Neck1"), (-6.6, -1.0, "Chest"), (-1.0, 8.6, "Hips"),
            (8.6, 12.4, "Tail1"), (12.4, 16.0, "Tail2"), (16.0, 19.6, "Tail3"), (19.6, 23.0, "Tail4")]


def seg_of(z):
    for a, b, bone in SEGMENTS:
        if a <= z < b:
            return bone
    return "Tail5"


def build():
    d = Dino("Ceratosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15, 2))
    d.bone("Chest", (0, 15.2, -2), "Hips")
    d.bone("Neck1", (0, 16.8, -7.4), "Chest")
    d.bone("Neck2", (0, 18.8, -9.4), "Neck1")
    d.bone("Head", (0, 20.4, -10.8), "Neck2")
    d.bone("Jaw", (0, 19.6, -13.0), "Head")
    d.bone_pair("Lid", (-2.8, 23, -15), "Head")
    d.bone_pair("Arm", (-3.6, 13.6, -6.4), "Chest")
    d.bone_pair("Forearm", (-4.0, 12.2, -7.4), "ArmL")
    d.bone_pair("Thigh", (-4.0, 14.4, 2.6), "Hips")
    d.bone_pair("Shin", (-4.3, 8.0, -0.6), "ThighL")
    d.bone_pair("Foot", (-4.3, 3.6, 3.0), "ShinL")
    tz = [8.6, 12.4, 16.0, 19.6, 23.0, 26.6]
    ty = [15.4, 15.6, 15.6, 15.5, 15.3, 15.1]
    tr = [3.5, 3.0, 2.5, 1.9, 1.35, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 15.4, 3.4), (4.0, 4.2, 5.6), BODY, where=left)
    d.ellipsoid("Chest", (0, 15.0, -3.4), (4.2, 4.6, 4.6), BODY, where=left)
    d.limb("Neck1", (0, 16.6, -7.2), (0, 18.8, -9.4), 3.0, 2.8, BODY, where=left)
    d.limb("Neck2", (0, 18.8, -9.4), (0, 20.4, -10.8), 2.8, 2.8, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête : crâne, museau profond, mâchoire
    d.ellipsoid("Head", (0, 22.0, -13.6), (2.8, 2.8, 3.2), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.8)
    d.ellipsoid("Head", (0, 21.6, -18.8), (2.2, 2.3, 3.8), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.6)
    d.ellipsoid("Jaw", (0, 19.2, -17.2), (2.2, 1.3, 5.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 19, power=2.6)
    d.box("Jaw", (-1, 19, -13), (0, 19, -12), BODY)
    d.box("Head", (0, 20, -22), (0, 20, -14), MOUTH)
    d.box("Jaw", (0, 19, -21), (0, 19, -14), TONGUE)
    for z in (-22, -20, -18, -16):
        x = d.surface_x(20, z, "Head")
        if x is not None:
            d.set("Head", x, 20, z, TOOTH, "Smooth")
    for z in (-21, -19, -17):
        x = d.surface_x(19, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 19, z, TOOTH, "Smooth")
    zs = [k[2] for k, v in d.vox.items() if k[0] == -1 and k[1] == 22 and v[0] == "Head"]
    d.set("Head", -1, 22, min(zs), PUPIL, "Smooth")  # narine
    # corne nasale : lame haute au bout du museau (base épaisse, pointe fine)
    d.limb("Head", (0, 23.4, -21.4), (0, 23.8, -18.6), 1.0, 1.0, HORN)
    d.plate("Head", 0, 0, [(23.0, -22.0), (27.8, -20.6), (27.0, -19.4), (23.0, -17.8)], HORN)
    # petites cornes au-dessus des yeux
    d.limb("Head", (-2.0, 24.4, -14.6), (-2.5, 26.4, -15.4), 1.05, 0.4, HORN)
    # ---------------------------------------------------------------- petits bras à quatre doigts
    d.limb("ArmL", (-3.6, 13.6, -6.4), (-4.0, 12.2, -7.4), 1.1, 1.0, BODY)
    d.limb("ForearmL", (-4.0, 12.2, -7.4), (-4.0, 11.2, -9.0), 0.9, 0.8, BODY)
    for p in ((-4, 10, -10), (-3, 10, -10), (-5, 11, -10)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes de prédateur
    d.ellipsoid("ThighL", (-4.4, 11.2, 1.0), (2.5, 4.2, 3.4), BODY)
    d.limb("ShinL", (-4.3, 8.0, -0.6), (-4.3, 3.6, 3.0), 1.7, 1.3, BODY)
    d.limb("FootL", (-4.3, 3.6, 3.0), (-4.3, 1.0, 0.8), 1.3, 1.2, BODY)
    d.box("FootL", (-6, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -3), (-3, 1, 1), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, -4))
    # ---------------------------------------------------------------- queue haute et étroite
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left,
               flat=1.25)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 22, -15, IRIS, PUPIL, lid_color=BODY, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    # bandes rouge-orangé en travers du dos et des flancs
    d.back_stripes(["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], BAND, frac=0.62,
                   period=5, width=2, only=[BODY])
    # deux bandes sur le haut de chaque cuisse (la peinture suit celle du corps)
    d.paint(lambda x, y, z, bone, c: BAND if bone in ("ThighL", "ThighR") and c == BODY and y >= 10 and (z + 2) % 4 < 2
            else None)
    # ---------------------------------------------------------------- plaques osseuses au milieu du dos (après la peinture)
    for zc in range(-11, 26, 3):
        bone = seg_of(zc + 0.5)
        h = 2 if -5 <= zc <= 14 else 1
        for z in (zc, zc + 1):
            top = d.surface_y(0, z, bone)
            if top is None:
                continue
            hh = h if z == zc else max(1, h - 1)
            for y in range(top + 1, top + 1 + hh):
                d.set(bone, 0, y, z, PLATE)
    return d
