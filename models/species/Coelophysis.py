"""Coelophysis : bipède du Canyon, petit chasseur fin et léger, toujours en mouvement.

Voxels de 0,2 stud : environ 9 studs de long et 4,5 de haut à la taille Normal (plus grand que l'avatar en longueur,
moins haut que lui). Long cou en S en trois segments, crâne étroit et allongé à petites dents, bras fins à trois
griffes, longues pattes de coureur et très longue queue en six segments. Orange fauve rayé de rouge sombre, masque
rouge sombre du museau à l'oeil, ventre crème."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.2

BODY = (228, 138, 56)
STRIPE = (148, 42, 34)
BELLY = (248, 226, 178)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 214, 60)
MOUTH = (172, 52, 58)
TONGUE = (214, 98, 104)
TOOTH = (252, 250, 242)

# personnalité : lue par la famille d'animation (models/lib/fam_biped.py)
PERSONALITY = {
    "tempo": 1.35,          # vif et nerveux
    "weight": 0.7,          # très léger
    "stride": 1.2,          # longues pattes : grands pas
    "bob": 1.0,
    "headBob": 1.3,         # tête d'oiseau : se fige puis avance
    "tail": 1.2,            # longue queue qui fouette
    "diet": "meat",
    "happy": "hop",
    "catch": "headbutt",
}


def build():
    d = Dino("Coelophysis", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 14, 3))
    d.bone("Chest", (0, 14.2, -0.5), "Hips")
    d.bone("Neck1", (0, 15.6, -4.4), "Chest")
    d.bone("Neck2", (0, 18.4, -6.6), "Neck1")
    d.bone("Neck3", (0, 21.0, -8.0), "Neck2")
    d.bone("Head", (0, 22.8, -9.6), "Neck3")
    d.bone("Jaw", (0, 22.0, -11.4), "Head")
    d.bone_pair("Lid", (-1.8, 25, -12.5), "Head")
    d.bone_pair("Arm", (-3.0, 13.0, -3.8), "Chest")
    d.bone_pair("Forearm", (-3.4, 11.2, -4.6), "ArmL")
    d.bone_pair("Thigh", (-3.4, 13.4, 3), "Hips")
    d.bone_pair("Shin", (-3.6, 8.6, 0.6), "ThighL")
    d.bone_pair("Foot", (-3.6, 4.2, 3.6), "ShinL")
    tz = [7.0, 10.4, 13.6, 16.6, 19.4, 22.0, 24.4]
    ty = [14.4, 14.8, 15.1, 15.3, 15.4, 15.5, 15.6]
    tr = [2.6, 2.15, 1.75, 1.4, 1.1, 0.85, 0.6]
    for i in range(6):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps fin et allongé
    d.ellipsoid("Hips", (0, 14.2, 3.6), (3.3, 3.1, 4.4), BODY, where=left)
    d.ellipsoid("Chest", (0, 13.8, -1.6), (3.4, 3.3, 3.6), BODY, where=left)
    # long cou en S (trois segments épais empilés, de plus en plus fins)
    d.limb("Neck1", (0, 15.0, -4.0), (0, 18.4, -6.6), 2.0, 1.75, BODY, where=left)
    d.limb("Neck2", (0, 18.4, -6.6), (0, 21.0, -8.0), 1.75, 1.6, BODY, where=left)
    d.limb("Neck3", (0, 21.0, -8.0), (0, 22.8, -9.6), 1.6, 1.55, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne étroit, long museau pointu
    d.ellipsoid("Head", (0, 23.8, -11.8), (2.2, 2.2, 2.8), BODY, where=left, power=2.4)
    d.limb("Head", (0, 23.4, -13.4), (0, 22.9, -19.4), 1.7, 0.9, BODY, where=lambda x, y, z: x <= 0 and y >= 22)
    d.limb("Jaw", (0, 21.5, -11.8), (0, 21.6, -18.4), 1.25, 0.75, BELLY, where=lambda x, y, z: x <= 0 and y <= 21)
    d.box("Head", (0, 22, -19), (0, 22, -12), MOUTH)
    d.box("Jaw", (0, 21, -17), (0, 21, -12), TONGUE)
    for z in (-18, -16, -14):
        x = d.surface_x(22, z, "Head")
        if x is not None:
            d.set("Head", x, 22, z, TOOTH, "Smooth")
    d.set("Head", -1, 23, -19, STRIPE, "Smooth")  # narine
    # ---------------------------------------------------------------- bras fins à trois griffes
    d.limb("ArmL", (-3.0, 13.0, -3.8), (-3.4, 11.2, -4.6), 0.9, 0.8, BODY)
    d.limb("ForearmL", (-3.4, 11.2, -4.6), (-3.4, 9.8, -6.6), 0.75, 0.65, BODY)
    for p in ((-4, 9, -7), (-3, 9, -7), (-4, 10, -8)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- longues pattes de coureur
    d.ellipsoid("ThighL", (-3.6, 11.0, 1.8), (2.0, 3.2, 2.8), BODY)
    d.limb("ShinL", (-3.6, 8.6, 0.6), (-3.6, 4.2, 3.6), 1.3, 1.0, BODY)
    d.limb("FootL", (-3.6, 4.2, 3.6), (-3.6, 0.8, 0.8), 1.0, 0.9, BODY)
    d.box("FootL", (-5, 0, -2), (-3, 0, 1), BODY)
    d.box("FootL", (-4, 1, -1), (-3, 1, 1), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -2.5))
    # ---------------------------------------------------------------- très longue queue en six segments
    for i in range(6):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- yeux + symétrie + peinture
    # masque rouge sombre : bande du museau à l'arrière du crâne, à hauteur d'oeil (l'oeil jaune ressort dessus)
    d.paint(lambda x, y, z, bone, c: STRIPE if bone == "Head" and c == BODY and 23 <= y <= 24 and z >= -15 and x <= -1 else None)
    d.eye("Head", "LidL", 23, -13, IRIS, PUPIL, lid_color=shade(BODY, -0.12), h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    # gorge claire : face avant-basse de chaque segment du cou
    necks = {"Neck1": ((15.0, -4.0), (18.4, -6.6)), "Neck2": ((18.4, -6.6), (21.0, -8.0)),
             "Neck3": ((21.0, -8.0), (22.8, -9.6))}

    def throat(x, y, z, bone, c):
        if bone not in necks or c != BODY:
            return None
        (y0, z0), (y1, z1) = necks[bone]
        ny, nz = -(z1 - z0), (y1 - y0)
        m = (ny * ny + nz * nz) ** 0.5
        return BELLY if ((y - y0) * ny + (z - z0) * nz) / m < -0.5 else None
    d.paint(throat)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6"],
                   STRIPE, frac=0.45, period=4, width=2, only=[BODY])

    # rayures du cou : bandes en travers de chaque segment (côté nuque), comptées le long de son axe
    def nape(x, y, z, bone, c):
        if bone not in necks or c != BODY:
            return None
        (y0, z0), (y1, z1) = necks[bone]
        ly, lz = y1 - y0, z1 - z0
        m = (ly * ly + lz * lz) ** 0.5
        t = ((y - y0) * ly + (z - z0) * lz) / m
        side = ((y - y0) * -lz + (z - z0) * ly) / m      # > 0 côté nuque
        start = {"Neck1": 0.0, "Neck2": 4.3, "Neck3": 7.3}[bone]
        return STRIPE if side > 0.2 and int((t + start) // 2) % 2 == 0 else None
    d.paint(nape)
    return d
