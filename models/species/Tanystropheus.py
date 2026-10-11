"""Tanystropheus : reptile au cou démesuré de la Beach, pêcheur patient.

Voxels de 0,25 stud : environ 14 studs de long à la taille Normal, dont près de 6 de cou (aussi long que le corps
et la queue réunis), 4 de haut tête comprise. Cou tendu vers l'avant et légèrement relevé, fait de cinq gros segments
épais empilés et effilés (chaque segment marqué d'une bande brune) ; petite tête de lézard au museau pointu, crocs
de pêcheur, grand oeil. Corps bas de lézard sur des pattes écartées (cuisses et bras vers l'extérieur), longue queue
effilée. Beige sable à larges bandes brunes en travers du dos, ventre crème."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.25

BODY = (226, 180, 110)
BAND = (138, 86, 48)
BELLY = (246, 228, 184)
CLAW = (252, 246, 232)
TOOTH = (252, 250, 240)
PUPIL = (26, 22, 20)
IRIS = (255, 176, 64)
MOUTH = (196, 98, 100)

PERSONALITY = {
    "tempo": 0.95,          # pêcheur patient, gestes posés
    "weight": 0.9,
    "stride": 1.0,
    "bob": 0.6,
    "headBob": 0.0,
    "tail": 1.1,            # longue queue de lézard qui ondule
    "diet": "fish",
    "happy": "stomp",
    "catch": "toss",        # charge cou bas puis relève la tête d'un coup
    "sleepDrop": 0.45,      # couché, le ventre touche le sol
}


def build():
    d = Dino("Tanystropheus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 6.6, 3.0))
    d.bone("Chest", (0, 6.6, -2.0), "Hips")
    nz = [-7.0, -11.6, -16.2, -20.8, -25.4, -30.0]          # cou : 5 segments + base de la tête
    ny = [7.0, 8.7, 10.2, 11.5, 12.6, 13.5]
    nr = [2.8, 2.55, 2.35, 2.15, 2.0, 1.9]
    for i in range(5):
        d.bone(f"Neck{i + 1}", (0, ny[i], nz[i]), "Chest" if i == 0 else f"Neck{i}")
    d.bone("Head", (0, ny[5], nz[5]), "Neck5")
    d.bone("Jaw", (0, 13.0, -31.6), "Head")
    d.bone_pair("Lid", (-2.2, 16, -33.0), "Head")
    d.bone_pair("Arm", (-3.4, 5.8, -4.0), "Chest")
    d.bone_pair("Forearm", (-6.2, 3.6, -3.0), "ArmL")
    d.bone_pair("Hand", (-6.6, 1.0, -4.6), "ForearmL")
    d.bone_pair("Thigh", (-3.6, 6.0, 4.0), "Hips")
    d.bone_pair("Shin", (-6.4, 3.6, 3.0), "ThighL")
    d.bone_pair("Foot", (-6.8, 1.2, 4.6), "ShinL")
    tz = [6.6, 9.2, 11.8, 14.2, 16.4, 18.4]
    ty = [6.8, 6.6, 6.2, 5.6, 5.0, 4.4]
    tr = [2.7, 2.3, 1.9, 1.5, 1.1, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps bas de lézard
    d.ellipsoid("Hips", (0, 6.8, 3.0), (4.4, 3.3, 4.8), BODY, where=left, power=2.4)
    d.ellipsoid("Chest", (0, 6.8, -2.6), (4.6, 3.4, 4.8), BODY, where=left, power=2.4)
    # ---------------------------------------------------------------- cou démesuré : cinq gros segments empilés
    for i in range(5):
        d.limb(f"Neck{i + 1}", (0, ny[i], nz[i] + (0.6 if i == 0 else 0)), (0, ny[i + 1], nz[i + 1]), nr[i], nr[i + 1],
               BODY, where=left)
    # ---------------------------------------------------------------- petite tête de lézard, museau pointu
    up = lambda x, y, z: x <= 0 and y >= 13  # noqa: E731
    d.ellipsoid("Head", (0, 14.4, -32.2), (2.5, 2.4, 2.7), BODY, where=up, power=2.3)
    d.ellipsoid("Head", (0, 13.9, -35.6), (1.6, 1.5, 2.3), BODY, where=up, power=2.3)
    d.ellipsoid("Jaw", (0, 12.6, -34.0), (1.8, 1.1, 3.2), BODY, where=lambda x, y, z: x <= 0 and y <= 12, power=2.3)
    for z in range(-34, -30):
        if (0, 13, z) in d.vox and d.vox[(0, 13, z)][0] == "Head":
            d.set("Head", 0, 13, z, MOUTH)
        if (0, 12, z) in d.vox and d.vox[(0, 12, z)][0] == "Jaw":
            d.set("Jaw", 0, 12, z, MOUTH)
    # crocs de pêcheur qui dépassent sur les côtés du museau
    for z in (-36, -34):
        x = d.surface_x(13, z, "Head")
        if x is not None:
            d.set("Head", x, 12, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- pattes écartées de lézard
    d.limb("ArmL", (-3.4, 5.8, -4.0), (-6.2, 3.6, -3.0), 1.5, 1.2, BODY)
    d.limb("ForearmL", (-6.2, 3.6, -3.0), (-6.6, 1.0, -4.6), 1.1, 1.0, BODY)
    d.limb("HandL", (-6.6, 1.0, -4.6), (-6.8, 0.5, -5.2), 1.0, 1.0, BODY)
    d.box("HandL", (-8, 0, -6), (-6, 0, -4), BODY)
    for x in (-8, -6):
        d.set("HandL", x, 0, -7, CLAW, "Smooth")
    d.limb("ThighL", (-3.6, 6.0, 4.0), (-6.4, 3.6, 3.0), 1.7, 1.3, BODY)
    d.limb("ShinL", (-6.4, 3.6, 3.0), (-6.8, 1.2, 4.6), 1.2, 1.0, BODY)
    d.limb("FootL", (-6.8, 1.2, 4.6), (-7.0, 0.5, 4.0), 1.0, 1.0, BODY)
    d.box("FootL", (-8, 0, 2), (-6, 0, 5), BODY)
    for x in (-8, -6):
        d.set("FootL", x, 0, 1, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-7.0, 0, 2.5))
    d.point("FrontToeL", "HandL", (-7.0, 0, -5.5))
    # ---------------------------------------------------------------- longue queue effilée
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left,
               flat=1.3)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 14, -34, IRIS, PUPIL, lid_color=shade(BODY, -0.18), h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    trunk = ["Hips", "Chest"] + [f"Neck{i + 1}" for i in range(5)] + [f"Tail{i + 1}" for i in range(5)]
    d.countershade(trunk, BELLY, frac=0.3, only=[BODY])
    d.paint(lambda x, y, z, bone, c: BELLY if bone == "Jaw" and c == BODY else None)
    # larges bandes brunes en travers du dos : une au début de chaque segment du cou, puis toutes les 4 voxels
    bands = {int(round(z)) for z in nz[1:5]} | {int(round(z)) - 1 for z in nz[1:5]}
    bands |= {z for z in range(-6, 19) if z % 4 in (0, 1)}
    col = d.columns(trunk)
    d.paint(lambda x, y, z, bone, c: BAND if c == BODY and bone in trunk and z in bands
            and y >= col[(bone, x, z)][0] + 0.45 * (col[(bone, x, z)][1] - col[(bone, x, z)][0] + 1) else None)
    # bande brune qui part de l'oeil vers le cou (rayure de lézard)
    d.paint(lambda x, y, z, bone, c: BAND if bone == "Head" and c == BODY and y in (14, 15) and z >= -32 else None)
    return d
