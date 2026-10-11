"""Lava Titan : Secret, titan de roche volcanique, colossal et lent (le plus grand des dinos).

Voxels de 0,75 stud (gros voxels : le titan reste sous 450 pièces) : environ 32 studs de long et 20 de haut (cornes
comprises) à la taille Normal. Corps trapu de basalte, grosse tête carrée à deux cornes recourbées vers l'avant,
rochers sur le dos, fissures de lave lumineuses (Neon) sur les flancs, gueule de lave et yeux brûlants."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.75

BASALT = (58, 54, 60)
ROCK = (92, 84, 86)
HORN = (40, 36, 42)
LAVA = (255, 112, 30)
CLAW = (230, 220, 200)
PUPIL = (120, 20, 10)
IRIS = (255, 214, 60)
MOUTH = (255, 112, 30)
TOOTH = (236, 226, 206)

PERSONALITY = {
    "tempo": 0.7,           # colossal : pas lents qui font trembler le sol
    "weight": 1.7,
    "stride": 0.9,
    "bob": 1.1,
    "headBob": 0.0,
    "tail": 0.9,
    "diet": "meat",
    "happy": "stomp",
    "catch": "headbutt",
}


def build():
    d = Dino("LavaTitan", FAMILY, voxel=VOXEL, display="Lava Titan")
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 13.3, 3.3))
    d.bone("Chest", (0, 13.8, -1.0), "Hips")
    d.bone("Neck1", (0, 16.3, -7.0), "Chest")
    d.bone("Neck2", (0, 17.8, -9.0), "Neck1")
    d.bone("Head", (0, 18.9, -10.5), "Neck2")
    d.bone("Jaw", (0, 18.4, -12.0), "Head")
    d.bone_pair("Lid", (-3.0, 22, -15), "Head")
    d.bone_pair("Arm", (-4.2, 12.5, -6.1), "Chest")
    d.bone_pair("Forearm", (-4.6, 10.1, -7.1), "ArmL")
    d.bone_pair("Thigh", (-4.2, 12.8, 3.7), "Hips")
    d.bone_pair("Shin", (-4.5, 7.5, 0.8), "ThighL")
    d.bone_pair("Foot", (-4.4, 3.5, 3.7), "ShinL")
    tz = [9.0, 12.3, 15.4, 18.3, 20.8, 22.9]
    ty = [14.3, 14.3, 14.1, 13.8, 13.4, 13.1]
    tr = [3.8, 3.2, 2.5, 1.8, 1.25, 0.75]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps trapu
    d.ellipsoid("Hips", (0, 13.8, 4.2), (4.6, 4.5, 5.3), BASALT, where=left, power=2.6)
    d.ellipsoid("Chest", (0, 13.6, -3.0), (5.1, 5.3, 5.0), BASALT, where=left, power=2.6)
    d.limb("Neck1", (0, 15.8, -6.6), (0, 17.8, -9.0), 3.3, 3.2, BASALT, where=left)
    d.limb("Neck2", (0, 17.8, -9.0), (0, 18.8, -10.3), 3.2, 3.0, BASALT, where=left)
    # ---------------------------------------------------------------- grosse tête carrée, gueule de lave
    d.ellipsoid("Head", (0, 20.1, -12.8), (3.3, 2.8, 3.3), BASALT, where=lambda x, y, z: x <= 0 and y >= 19, power=3.0)
    d.ellipsoid("Head", (0, 19.6, -16.4), (2.7, 2.2, 2.7), BASALT, where=lambda x, y, z: x <= 0 and y >= 19, power=2.8)
    d.ellipsoid("Jaw", (0, 17.8, -14.8), (2.5, 1.5, 4.0), ROCK, where=lambda x, y, z: x <= 0 and y <= 18, power=2.8)
    d.box("Jaw", (-2, 18, -12), (0, 18, -11), BASALT)
    d.box("Head", (0, 19, -18), (0, 19, -13), MOUTH, "Neon")
    d.box("Jaw", (0, 18, -17), (0, 18, -13), MOUTH, "Neon")
    for z in (-18, -16, -14):
        x = d.surface_x(19, z, "Head")
        if x is not None:
            d.set("Head", x, 19, z, TOOTH, "Smooth")
    for z in (-17, -15):
        x = d.surface_x(18, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 18, z, TOOTH, "Smooth")
    # arcade rocheuse et deux cornes recourbées vers l'avant (deux segments épais)
    d.box("Head", (-3, 22, -16), (-3, 22, -14), ROCK)
    d.limb("Head", (-2.6, 22.0, -11.8), (-4.8, 24.2, -10.8), 1.25, 0.75, HORN)
    d.limb("Head", (-4.8, 24.2, -10.8), (-5.4, 26.2, -12.8), 0.75, 0.3, HORN)
    # ---------------------------------------------------------------- bras puissants
    d.limb("ArmL", (-4.2, 12.5, -6.1), (-4.6, 10.1, -7.1), 1.4, 1.25, BASALT)
    d.limb("ForearmL", (-4.6, 10.1, -7.1), (-4.5, 8.8, -9.3), 1.25, 1.1, BASALT)
    for p in ((-5, 8, -10), (-4, 8, -10)):
        d.set("ForearmL", p[0], p[1], p[2], CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes colossales
    d.ellipsoid("ThighL", (-4.6, 10.1, 2.5), (2.7, 3.8, 3.7), BASALT)
    d.limb("ShinL", (-4.5, 7.5, 0.8), (-4.4, 3.5, 3.7), 2.0, 1.6, BASALT)
    d.limb("FootL", (-4.4, 3.5, 3.7), (-4.4, 0.8, 1.3), 1.6, 1.5, BASALT)
    d.box("FootL", (-7, 0, -3), (-3, 0, 1), BASALT)
    d.box("FootL", (-6, 1, -2), (-3, 1, 1), BASALT)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, -3))
    # ---------------------------------------------------------------- queue épaisse
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BASALT, where=left)
    # ---------------------------------------------------------------- yeux, fissures de lave (côté gauche)
    d.eye("Head", "LidL", 21, -15, IRIS, PUPIL, lid_color=ROCK, h=1, w=2)
    # deux fissures en zigzag continues sur le flanc (torse et bassin), peintes sur la surface
    for bone, path in (("Chest", [(17, -6), (14, -4), (12, -6), (9, -3)]),
                       ("Hips", [(17, 4), (14, 6), (12, 4), (10, 7)])):
        for (y0, z0), (y1, z1) in zip(path, path[1:]):
            n = max(abs(y1 - y0), abs(z1 - z0))
            for i in range(n + 1):
                y, z = round(y0 + (y1 - y0) * i / n), round(z0 + (z1 - z0) * i / n)
                x = d.surface_x(y, z, bone)
                if x is not None:
                    d.set(bone, x, y, z, LAVA, "Neon")
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == IRIS else None)
    # ---------------------------------------------------------------- rochers sur le dos (posés après la peinture)
    for bone, base, tip, r in (
            ("Neck1", (0, 18.8, -7.5), (0, 21.2, -6.1), 1.3),
            ("Chest", (0, 18.3, -4.2), (0, 22.1, -2.7), 1.7),
            ("Chest", (0, 18.4, -0.5), (0, 21.6, 0.8), 1.4),
            ("Hips", (0, 17.8, 3.2), (0, 21.2, 4.5), 1.6),
            ("Hips", (0, 17.4, 6.6), (0, 20.3, 7.8), 1.25),
            ("Tail1", (0, 17.1, 10.3), (0, 19.1, 11.5), 1.0),
            ("Tail2", (0, 16.4, 13.8), (0, 17.9, 14.8), 0.75)):
        d.limb(bone, base, tip, r, 0.4, ROCK)
    return d
