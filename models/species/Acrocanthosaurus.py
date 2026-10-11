"""Acrocanthosaurus : bipède du Volcano, grand prédateur à haute crête dorsale, lourd et sûr de lui.

Voxels de 0,397 stud : environ 19 studs de long et 11 de haut (crête comprise) à la taille Normal. Longue tête basse
à dents, bras robustes à trois griffes, haute crête cramoisie tendue sur les épines du dos, de la nuque au milieu de
la queue (plaque d'un voxel portée par chaque os qu'elle surmonte : elle suit le dos). Brun-rouge sombre à taches
noires, ventre crème."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.397

BODY = (106, 54, 42)
DARK = (70, 36, 30)
BELLY = (226, 192, 156)
SPOT = (36, 28, 30)
RIDGE = (222, 32, 62)
SPINE = (146, 20, 44)
CLAW = (240, 232, 214)
PUPIL = (26, 18, 14)
IRIS = (255, 196, 48)
MOUTH = (150, 40, 50)
TONGUE = (206, 96, 100)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.85,          # lourd et posé
    "weight": 1.35,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "meat",
    "happy": "stomp",       # pas de tour sur lui-même
    "catch": "headbutt",
}

BODY_BONES = ["Neck1", "Neck2", "Chest", "Hips", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]


def ridge_height(z):
    """Hauteur de la crête (voxels) au-dessus du dos selon z : basse sur la nuque, haute sur les hanches, effilée
    sur la queue."""
    pts = [(-10.2, 0.0), (-8.8, 1.9), (-5.3, 4.2), (-0.9, 6.0), (3.5, 7.2), (7.9, 6.8), (11.4, 5.3), (15.0, 3.4),
           (18.0, 1.7), (20.2, 0.0)]
    if z <= pts[0][0] or z >= pts[-1][0]:
        return 0.0
    for (z0, h0), (z1, h1) in zip(pts, pts[1:]):
        if z0 <= z <= z1:
            return h0 + (h1 - h0) * (z - z0) / (z1 - z0)
    return 0.0


def build():
    d = Dino("Acrocanthosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 13.2, 2.6))
    d.bone("Chest", (0, 13.6, -1.4), "Hips")
    d.bone("Neck1", (0, 15.5, -7.2), "Chest")
    d.bone("Neck2", (0, 17.2, -9.3), "Neck1")
    d.bone("Head", (0, 18.7, -10.9), "Neck2")
    d.bone("Jaw", (0, 17.9, -12.7), "Head")
    d.bone_pair("Lid", (-2.6, 21, -15), "Head")
    d.bone_pair("Arm", (-3.7, 12.0, -6.0), "Chest")
    d.bone_pair("Forearm", (-4.2, 9.9, -7.0), "ArmL")
    d.bone_pair("Thigh", (-3.9, 12.7, 3.2), "Hips")
    d.bone_pair("Shin", (-4.2, 7.4, 0.35), "ThighL")
    d.bone_pair("Foot", (-4.1, 3.5, 3.2), "ShinL")
    tz = [8.6, 12.1, 15.5, 18.7, 21.6, 24.6]
    ty = [14.1, 14.3, 14.4, 14.3, 14.2, 14.0]
    tr = [3.6, 3.0, 2.4, 1.8, 1.25, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps puissant
    d.ellipsoid("Hips", (0, 13.7, 3.9), (4.1, 4.2, 5.5), BODY, where=left)
    d.ellipsoid("Chest", (0, 13.2, -3.2), (4.4, 4.7, 4.6), BODY, where=left)
    d.limb("Neck1", (0, 15.1, -7.0), (0, 17.2, -9.3), 3.1, 2.9, BODY, where=left)
    d.limb("Neck2", (0, 17.2, -9.3), (0, 18.5, -10.7), 2.9, 2.8, BODY, where=left)
    # ---------------------------------------------------------------- longue tête basse
    d.ellipsoid("Head", (0, 19.8, -13.7), (3.0, 2.85, 3.5), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.7)
    d.ellipsoid("Head", (0, 19.4, -18.6), (2.45, 2.25, 3.6), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.6)
    d.ellipsoid("Jaw", (0, 17.4, -16.7), (2.3, 1.4, 5.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.6)
    d.box("Jaw", (-2, 18, -12), (0, 18, -11), BODY)
    d.box("Head", (0, 19, -22), (0, 19, -13), MOUTH)
    d.box("Jaw", (0, 18, -21), (0, 18, -13), TONGUE)
    for z in (-22, -20, -18, -16):
        x = d.surface_x(19, z, "Head")
        if x is not None:
            d.set("Head", x, 19, z, TOOTH, "Smooth")
    for z in (-21, -19, -17):
        x = d.surface_x(18, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 18, z, TOOTH, "Smooth")
    zs = [k[2] for k, v in d.vox.items() if k[0] == -1 and k[1] == 20 and v[0] == "Head"]
    d.set("Head", -1, 20, min(zs), SPOT, "Smooth")  # narine
    # crête rugueuse sur le museau (bosses sombres)
    for z in (-21, -19, -17):
        top = d.surface_y(-1, z, "Head")
        if top is not None:
            d.set("Head", -1, top + 1, z, DARK)
    # ---------------------------------------------------------------- bras robustes à trois griffes
    d.limb("ArmL", (-3.7, 12.0, -6.0), (-4.2, 9.9, -7.0), 1.3, 1.15, BODY)
    d.limb("ForearmL", (-4.2, 9.9, -7.0), (-4.0, 8.6, -9.2), 1.15, 0.95, BODY)
    for p in ((-4, 7, -10), (-3, 7, -10), (-5, 8, -10)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes massives
    d.ellipsoid("ThighL", (-4.4, 10.0, 1.9), (2.55, 3.9, 3.5), BODY)
    d.limb("ShinL", (-4.2, 7.4, 0.35), (-4.1, 3.5, 3.2), 1.85, 1.5, BODY)
    d.limb("FootL", (-4.1, 3.5, 3.2), (-4.1, 0.9, 1.0), 1.5, 1.4, BODY)
    d.box("FootL", (-6, 0, -3), (-2, 0, 1), BODY)
    d.box("FootL", (-5, 1, -2), (-3, 1, 1), BODY)
    for x in (-6, -4, -2):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -3.5))
    # ---------------------------------------------------------------- longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, arcade, symétrie, peinture
    d.eye("Head", "LidL", 20, -15, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    for z in (-16, -15, -14):
        x = d.surface_x(22, z, "Head")
        if x is not None:
            d.set("Head", x - 1 if z != -16 else x, 22, z, DARK)  # arcade au-dessus de l'oeil
    # taches noires sur les flancs (posées à la main, côté gauche, avant la symétrie)
    for bone, y, z in (("Chest", 15, -6), ("Chest", 12, -4), ("Chest", 16, -2), ("Hips", 13, 2), ("Hips", 16, 4),
                       ("Hips", 13, 6), ("Tail1", 15, 10), ("Tail2", 14, 13), ("Tail3", 14, 17)):
        for dy in (0, 1):
            for dz in (0, 1):
                x = d.surface_x(y + dy, z + dz, bone)
                if x is not None and d.vox[(x, y + dy, z + dz)][1] == BODY:
                    d.set(bone, x, y + dy, z + dz, SPOT)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ventre crème coupé à plat (lignes droites : peu de pièces)
    belly = {"Chest": 11, "Hips": 11, "Neck1": 14, "Neck2": 16, "Tail1": 12, "Tail2": 13, "Tail3": 13, "Tail4": 13}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    # ---------------------------------------------------------------- crête dorsale (après la peinture)
    for z in range(-11, 21):
        h = ridge_height(z + 0.5)
        if h < 0.5:
            continue
        cells = [(k[1], v[0]) for k, v in d.vox.items() if k[0] == 0 and k[2] == z and v[0] in BODY_BONES]
        if not cells:
            continue
        top, bone = max(cells)
        n = int(round(h))
        spine = z % 3 == 0
        for y in range(top + 1, top + 1 + n + (1 if spine else 0)):
            d.set(bone, 0, y, z, SPINE if spine else RIDGE)
    return d
