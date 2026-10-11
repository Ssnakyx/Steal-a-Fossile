"""Crystal Rex : Secret, T-Rex de cristal, majestueux et froid.

Squelette et formes du T-Rex, voxels de 0,415 stud : environ 22 studs de long et 12 de haut (cristaux compris) à la
taille Normal. Corps violet nuit, ventre lavande, éclats de cristal translucides (matière Ice) le long du dos, sur les
épaules, les arcades et le museau, yeux cyan lumineux (Neon, quatre voxels seulement)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.415

BODY = (92, 74, 166)
DARK = (62, 48, 124)
BELLY = (206, 198, 242)
CRYSTAL = (160, 236, 255)
CRYSTAL2 = (226, 176, 255)
CLAW = (226, 240, 255)
PUPIL = (20, 24, 40)
IRIS = (120, 240, 255)
MOUTH = (120, 56, 150)
TONGUE = (176, 112, 200)
TOOTH = (236, 246, 255)

PERSONALITY = {
    "tempo": 0.8,           # lourd et majestueux
    "weight": 1.5,
    "stride": 0.95,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "meat",
    "happy": "stomp",
    "catch": "headbutt",
}


def build():
    d = Dino("CrystalRex", FAMILY, voxel=VOXEL, display="Crystal Rex")

    def shard(bone, base, tip, r, color=CRYSTAL):
        """Éclat de cristal : segment effilé translucide, de la peau vers la pointe."""
        d.limb(bone, base, tip, r, 0.3, color, "Ice")

    # ---------------------------------------------------------------- os (squelette du T-Rex)
    d.bone("Hips", (0, 15, 3))
    d.bone("Chest", (0, 15.4, -1.6), "Hips")
    d.bone("Neck1", (0, 17.6, -8.2), "Chest")
    d.bone("Neck2", (0, 19.6, -10.6), "Neck1")
    d.bone("Head", (0, 21.2, -12.4), "Neck2")
    d.bone("Jaw", (0, 20.6, -14.0), "Head")
    d.bone_pair("Lid", (-3.0, 24, -17), "Head")
    d.bone_pair("Arm", (-4.2, 13.6, -6.8), "Chest")
    d.bone_pair("Forearm", (-4.8, 11.8, -7.6), "ArmL")
    d.bone_pair("Thigh", (-4.4, 14.4, 3.6), "Hips")
    d.bone_pair("Shin", (-4.8, 8.4, 0.4), "ThighL")
    d.bone_pair("Foot", (-4.7, 4.0, 3.6), "ShinL")
    tz = [9.8, 13.8, 17.6, 21.2, 24.4, 27.2]
    ty = [16.0, 16.4, 16.6, 16.6, 16.4, 16.2]
    tr = [4.2, 3.4, 2.7, 2.0, 1.4, 0.9]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps massif
    d.ellipsoid("Hips", (0, 15.6, 4.6), (5.0, 5.0, 6.4), BODY, where=left)
    d.ellipsoid("Chest", (0, 15.0, -3.8), (5.4, 5.6, 5.4), BODY, where=left)
    d.limb("Neck1", (0, 17.2, -8.0), (0, 19.6, -10.6), 3.6, 3.4, BODY, where=left)
    d.limb("Neck2", (0, 19.6, -10.6), (0, 21.0, -12.2), 3.4, 3.3, BODY, where=left)
    # ---------------------------------------------------------------- tête anguleuse
    d.ellipsoid("Head", (0, 22.4, -15.4), (3.6, 3.4, 4.0), BODY, where=lambda x, y, z: x <= 0 and y >= 21, power=3.0)
    d.ellipsoid("Head", (0, 21.8, -20.4), (2.8, 2.6, 3.4), BODY, where=lambda x, y, z: x <= 0 and y >= 21, power=2.8)
    d.ellipsoid("Jaw", (0, 19.8, -18.4), (2.6, 1.6, 5.0), BELLY, where=lambda x, y, z: x <= 0 and y <= 20, power=2.8)
    d.box("Jaw", (-2, 20, -14), (0, 20, -13), BODY)
    d.box("Head", (0, 21, -23), (0, 21, -15), MOUTH)
    d.box("Jaw", (0, 20, -22), (0, 20, -15), TONGUE)
    for z in (-23, -21, -19, -17):
        x = d.surface_x(21, z, "Head")
        if x is not None:
            d.set("Head", x, 21, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- bras minuscules
    d.limb("ArmL", (-4.2, 13.6, -6.8), (-4.8, 11.8, -7.6), 1.1, 1.0, BODY)
    d.limb("ForearmL", (-4.8, 11.8, -7.6), (-4.6, 11.0, -9.2), 0.9, 0.8, BODY)
    d.set("ForearmL", -5, 10, -10, CLAW, "Smooth")
    d.set("ForearmL", -4, 10, -10, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes massives
    d.ellipsoid("ThighL", (-5.0, 11.4, 2.2), (3.0, 4.4, 4.2), BODY)
    d.limb("ShinL", (-4.8, 8.4, 0.4), (-4.7, 4.0, 3.6), 2.2, 1.7, BODY)
    d.limb("FootL", (-4.7, 4.0, 3.6), (-4.7, 1.0, 1.2), 1.7, 1.6, BODY)
    d.box("FootL", (-7, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-6, 1, -3), (-3, 1, 1), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, -4))
    # ---------------------------------------------------------------- queue épaisse
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 23, -17, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ventre lavande coupé à plat (lignes droites : peu de pièces)
    belly = {"Chest": 12, "Hips": 12, "Tail1": 13}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == IRIS else None)
    # ---------------------------------------------------------------- éclats de cristal (posés après la peinture)
    # crête de cristaux au milieu du dos : grands sur le torse et le bassin, plus petits vers la tête et la queue
    for bone, base, tip, r, col in (
            ("Neck1", (0, 20.6, -8.6), (0, 24.6, -7.0), 1.1, CRYSTAL),
            ("Chest", (0, 19.6, -4.6), (0, 25.8, -2.6), 1.4, CRYSTAL2),
            ("Chest", (0, 19.8, -1.0), (0, 24.4, 0.6), 1.1, CRYSTAL),
            ("Hips", (0, 19.8, 3.0), (0, 26.0, 5.0), 1.4, CRYSTAL),
            ("Hips", (0, 19.4, 7.0), (0, 23.8, 8.6), 1.1, CRYSTAL2),
            ("Tail1", (0, 19.2, 11.8), (0, 22.8, 13.4), 1.0, CRYSTAL),
            ("Tail2", (0, 18.6, 15.8), (0, 21.6, 17.2), 0.9, CRYSTAL2)):
        shard(bone, base, tip, r, col)
    # éclats des épaules (de chaque côté), des arcades et du museau
    for bone, base, tip, r, col in (
            ("Chest", (-3.8, 18.2, -5.0), (-6.4, 21.4, -4.0), 1.0, CRYSTAL),
            ("Head", (-2.2, 25.2, -15.0), (-3.2, 27.6, -13.6), 0.8, CRYSTAL)):
        shard(bone, base, tip, r, col)
        shard(bone, (-base[0], base[1], base[2]), (-tip[0], tip[1], tip[2]), r, col)
    shard("Head", (0, 23.6, -21.0), (0, 26.0, -21.6), 0.8, CRYSTAL2)
    return d
