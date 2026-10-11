"""Allosaurus : bipède du Canyon, grand prédateur rapide et sûr de lui.

Voxels de 0,35 stud : environ 17 studs de long et 9 de haut à la taille Normal. Long crâne carré, petites cornes
rouges au-dessus des yeux, double crête basse le long du museau, bras plus forts que ceux du T-Rex à trois grandes
griffes, cuisses puissantes, longue queue. Fauve à rayures tigrées brunes (effilées vers le bas), ventre crème."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.35

BODY = (226, 160, 78)
STRIPE = (110, 62, 36)
BELLY = (244, 226, 186)
HORN = (206, 50, 40)
RIDGE = (190, 128, 60)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 196, 40)
MOUTH = (160, 48, 54)
TONGUE = (206, 94, 98)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.9,           # grand prédateur : pas posés mais vifs
    "weight": 1.3,
    "stride": 1.05,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "meat",
    "happy": "stomp",       # saute sans tourner sur lui-même : trop lourd
    "catch": "headbutt",
}


def build():
    d = Dino("Allosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15, 3))
    d.bone("Chest", (0, 15.2, -1.6), "Hips")
    d.bone("Neck1", (0, 17.0, -7.2), "Chest")
    d.bone("Neck2", (0, 19.2, -9.4), "Neck1")
    d.bone("Head", (0, 20.8, -11.0), "Neck2")
    d.bone("Jaw", (0, 19.8, -13.0), "Head")
    d.bone_pair("Lid", (-2.8, 24, -15), "Head")
    d.bone_pair("Arm", (-3.8, 13.4, -6.2), "Chest")
    d.bone_pair("Forearm", (-4.4, 11.4, -7.2), "ArmL")
    d.bone_pair("Thigh", (-4.2, 14.4, 3.2), "Hips")
    d.bone_pair("Shin", (-4.5, 8.2, 0.0), "ThighL")
    d.bone_pair("Foot", (-4.5, 3.8, 3.4), "ShinL")
    tz = [8.8, 12.6, 16.2, 19.6, 22.8, 25.8]
    ty = [15.6, 15.9, 16.0, 16.0, 15.9, 15.8]
    tr = [3.8, 3.1, 2.5, 1.9, 1.35, 0.85]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps puissant mais élancé
    d.ellipsoid("Hips", (0, 15.4, 4.0), (4.4, 4.4, 5.8), BODY, where=left)
    d.ellipsoid("Chest", (0, 14.8, -3.2), (4.8, 5.0, 5.0), BODY, where=left)
    d.limb("Neck1", (0, 16.6, -7.0), (0, 19.2, -9.4), 3.3, 3.0, BODY, where=left)
    d.limb("Neck2", (0, 19.2, -9.4), (0, 20.8, -11.0), 3.0, 2.9, BODY, where=left)
    # ---------------------------------------------------------------- long crâne carré, mâchoire
    d.ellipsoid("Head", (0, 22.2, -14.2), (3.0, 2.9, 3.6), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.8)
    d.ellipsoid("Head", (0, 21.6, -19.4), (2.4, 2.3, 3.4), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.6)
    d.ellipsoid("Jaw", (0, 19.3, -17.4), (2.3, 1.3, 5.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 19, power=2.6)
    d.box("Jaw", (-1, 19, -13), (0, 19, -12), BODY)
    d.box("Head", (0, 20, -22), (0, 20, -13), MOUTH)
    d.box("Jaw", (0, 19, -21), (0, 19, -14), TONGUE)
    for z in (-22, -20, -18, -16):
        x = d.surface_x(20, z, "Head")
        if x is not None:
            d.set("Head", x, 20, z, TOOTH, "Smooth")
    for z in (-21, -19, -17):
        x = d.surface_x(19, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 19, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- bras forts à trois grandes griffes
    d.limb("ArmL", (-3.8, 13.4, -6.2), (-4.4, 11.4, -7.2), 1.4, 1.2, BODY)
    d.limb("ForearmL", (-4.4, 11.4, -7.2), (-4.4, 10.0, -9.6), 1.15, 1.0, BODY)
    for p in ((-5, 9, -10), (-4, 9, -10), (-3, 9, -10)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    for p in ((-5, 8, -11), (-3, 8, -11)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes puissantes
    d.ellipsoid("ThighL", (-4.7, 11.6, 1.6), (2.7, 4.3, 3.8), BODY)
    d.limb("ShinL", (-4.5, 8.2, 0.0), (-4.5, 3.8, 3.4), 2.0, 1.5, BODY)
    d.limb("FootL", (-4.5, 3.8, 3.4), (-4.5, 1.0, 1.0), 1.5, 1.4, BODY)
    d.box("FootL", (-6, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-6, 1, -3), (-3, 1, 1), BODY)
    for x in (-6, -4):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4.5, 0, -4))
    # ---------------------------------------------------------------- longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, cornes, crêtes du museau
    d.eye("Head", "LidL", 22, -16, IRIS, PUPIL, lid_color=RIDGE, h=2, w=2)
    # petite corne rouge au-dessus et en avant de l'oeil (pyramide en marches)
    d.box("Head", (-2, 25, -17), (-2, 25, -15), HORN)
    d.set("Head", -2, 26, -16, HORN)
    # crête basse le long du museau (un voxel en relief sur le dessus, de la corne à la narine)
    for z in range(-20, -16):
        y = d.surface_y(-1, z, "Head")
        if y is not None:
            d.set("Head", -1, y + 1, z, RIDGE)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : ventre crème, rayures tigrées
    # ventre crème coupé à plat (une seule frontière par os), gorge coupée le long de l'axe du cou
    belly = {"Chest": 12, "Hips": 13, "Tail1": 14, "Tail2": 14, "Tail3": 15, "Tail4": 15}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    necks = {"Neck1": ((16.6, -7.0), (19.2, -9.4)), "Neck2": ((19.2, -9.4), (20.8, -11.0))}

    def throat(x, y, z, bone, c):
        if bone not in necks or c != BODY:
            return None
        (y0, z0), (y1, z1) = necks[bone]
        ny, nz = -(z1 - z0), (y1 - y0)
        m = (ny * ny + nz * nz) ** 0.5
        return BELLY if ((y - y0) * ny + (z - z0) * nz) / m < -0.8 else None
    d.paint(throat)
    col = d.columns(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"])

    def tiger(x, y, z, bone, c):
        """Rayures tigrées : larges sur le dos, effilées vers le bas, légèrement penchées vers l'arrière."""
        if c != BODY or (bone, x, z) not in col:
            return None
        lo, hi = col[(bone, x, z)]
        h = (y - lo) / max(1, hi - lo)
        w = 3 if h > 0.8 else 2 if h > 0.62 else 1 if h > 0.45 else 0
        k = (z - (hi - y) // 2) % 5
        return STRIPE if k < w else None
    d.paint(tiger)
    return d
