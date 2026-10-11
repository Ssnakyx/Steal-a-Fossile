"""Gallimimus : bipède autruche de la Fern Forest, le plus rapide des petits.

Voxels de 0,21 stud : environ 9 studs de long et 6 de haut à la taille Normal.
Très longues pattes, long cou en trois segments, petite tête à bec plat sans dents, grands yeux."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.21

BODY = (222, 182, 112)
DARK = (176, 98, 54)
BELLY = (248, 234, 202)
BEAK = (124, 110, 100)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 168, 52)
MOUTH = (186, 82, 84)

PERSONALITY = {
    "tempo": 1.3,           # coureur, pressé
    "weight": 0.75,
    "stride": 1.25,         # grandes enjambées d'autruche
    "bob": 1.0,
    "headBob": 1.2,
    "tail": 0.9,
    "diet": "plants",
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("Gallimimus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 15, 3))
    d.bone("Chest", (0, 15, 0), "Hips")
    d.bone("Neck1", (0, 17.2, -4.4), "Chest")
    d.bone("Neck2", (0, 20.2, -6.2), "Neck1")
    d.bone("Neck3", (0, 23.2, -7.4), "Neck2")
    d.bone("Head", (0, 25.8, -8.4), "Neck3")
    d.bone("Jaw", (0, 25.6, -10.4), "Head")
    d.bone_pair("Lid", (-2.0, 28.5, -11), "Head")
    d.bone_pair("Arm", (-3.0, 14.2, -4.0), "Chest")
    d.bone_pair("Forearm", (-3.4, 11.8, -4.6), "ArmL")
    d.bone_pair("Thigh", (-3.2, 14.4, 3), "Hips")
    d.bone_pair("Shin", (-3.4, 9.0, 0.6), "ThighL")
    d.bone_pair("Foot", (-3.4, 4.6, 3.6), "ShinL")
    tz = [7.4, 11.4, 15.2, 18.8, 22.2, 25.4]
    ty = [15.4, 15.8, 16.1, 16.3, 16.4, 16.5]
    tr = [3.0, 2.4, 1.9, 1.4, 1.0, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps compact, cou très long
    d.ellipsoid("Hips", (0, 15.2, 3.8), (3.2, 3.4, 4.4), BODY, where=left)
    d.ellipsoid("Chest", (0, 14.8, -1.6), (3.4, 3.8, 3.8), BODY, where=left)
    d.limb("Neck1", (0, 16.6, -4.0), (0, 20.2, -6.2), 2.2, 1.9, BODY, where=left)
    d.limb("Neck2", (0, 20.2, -6.2), (0, 23.2, -7.4), 1.9, 1.7, BODY, where=left)
    d.limb("Neck3", (0, 23.2, -7.4), (0, 25.8, -8.4), 1.7, 1.6, BODY, where=left)
    # petite tête, long bec effilé sans dents (haut sur la tête, bas sur la mâchoire)
    d.ellipsoid("Head", (0, 27.2, -10.0), (2.3, 2.3, 2.4), BODY, where=left, power=2.3)
    d.limb("Head", (0, 26.4, -11.4), (0, 25.9, -15.8), 1.4, 0.6, BEAK, where=lambda x, y, z: x <= 0 and y >= 26)
    d.limb("Jaw", (0, 25.4, -11.0), (0, 25.4, -15.0), 1.2, 0.6, BEAK, where=lambda x, y, z: x <= 0 and y <= 25)
    d.box("Jaw", (-1, 25, -10), (0, 25, -9), BODY)
    d.box("Head", (0, 26, -14), (0, 26, -11), MOUTH)
    # bras moyens à trois griffes
    d.limb("ArmL", (-3.0, 14.2, -4.0), (-3.4, 11.8, -4.6), 1.1, 1.0, BODY)
    d.limb("ForearmL", (-3.4, 11.8, -4.6), (-3.4, 10.0, -6.6), 0.9, 0.8, BODY)
    for p in ((-4, 9, -7), (-3, 9, -7), (-4, 10, -8)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # pattes d'autruche : cuisse musclée, très longue jambe, long pied
    d.ellipsoid("ThighL", (-3.4, 12.2, 2.0), (2.0, 3.4, 3.0), BODY)
    d.limb("ShinL", (-3.4, 9.0, 0.6), (-3.4, 4.6, 3.6), 1.4, 1.0, BODY)
    d.limb("FootL", (-3.4, 4.6, 3.6), (-3.4, 0.8, 0.8), 1.0, 0.9, BODY)
    d.box("FootL", (-4, 0, -2), (-2, 0, 1), BODY)
    for x in (-4, -2):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, -2.5))
    # queue droite en 5 segments
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 26, -11, IRIS, PUPIL, lid_color=shade(BODY, -0.18), h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.32, only=[BODY])
    # colonnes trop fines (bouts de queue, bords) : le ventre clair ne remonte pas sur le dessus
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    # gorge claire : la face avant-basse de chaque segment du cou (plan qui passe par son axe)
    necks = {"Neck1": ((16.6, -4.0), (20.2, -6.2)), "Neck2": ((20.2, -6.2), (23.2, -7.4)),
             "Neck3": ((23.2, -7.4), (25.8, -8.4)), "Head": ((25.8, -8.4), (26.6, -9.4))}

    def throat(x, y, z, bone, c):
        if bone not in necks or c != BODY:
            return None
        (y0, z0), (y1, z1) = necks[bone]
        ny, nz = -(z1 - z0), (y1 - y0)            # perpendiculaire à l'axe, vers l'avant et le bas
        m = (ny * ny + nz * nz) ** 0.5
        if bone == "Head" and y > 26:
            return None
        return BELLY if ((y - y0) * ny + (z - z0) * nz) / m < -0.6 else None
    d.paint(throat)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], DARK, frac=0.3, period=4, width=2,
                   only=[BODY])
    return d
