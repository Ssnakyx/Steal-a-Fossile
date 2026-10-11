"""Therizinosaurus : bipède du Glacier, grand herbivore à plumes, calme et un peu gauche.

Voxels de 0,36 stud : environ 16 studs de long et 14 de haut (cou dressé) à la taille Normal. Ventre rond, petit
bec, long cou en deux segments, bras longs terminés par trois très grandes griffes, plumage blanc comme la neige."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.36

FEATHER = (236, 233, 224)
BACK = (146, 166, 194)
DARK = (88, 102, 132)
SKIN = (138, 132, 140)
CLAW = (236, 168, 56)
BEAK = (238, 178, 66)
CREST = (214, 74, 62)
PUPIL = (26, 22, 20)
IRIS = (255, 176, 44)
MOUTH = (190, 98, 96)

PERSONALITY = {
    "tempo": 0.85,          # grand et posé
    "weight": 1.15,
    "stride": 0.85,
    "bob": 0.8,
    "headBob": 0.6,         # cou d'oiseau : la tête se stabilise puis avance
    "tail": 0.6,
    "diet": "plants",
    "happy": "sway",        # pas de tour sur lui-même : trop grand et trop gauche
    "catch": "headbutt",
}


def build():
    d = Dino("Therizinosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 15, 4))
    d.bone("Chest", (0, 16.5, -0.5), "Hips")
    d.bone("Neck1", (0, 23.2, -5.8), "Chest")
    d.bone("Neck2", (0, 27.4, -8.8), "Neck1")
    d.bone("Head", (0, 31.4, -11.6), "Neck2")
    d.bone("Jaw", (0, 30.8, -14.6), "Head")
    d.bone_pair("Lid", (-2.4, 34, -15), "Head")
    d.bone_pair("Arm", (-4.6, 20.6, -5.0), "Chest")
    d.bone_pair("Forearm", (-5.6, 15.6, -6.6), "ArmL")
    d.bone_pair("Thigh", (-4.2, 14.6, 4.8), "Hips")
    d.bone_pair("Shin", (-4.6, 9.0, 2.0), "ThighL")
    d.bone_pair("Foot", (-4.6, 3.6, 5.2), "ShinL")
    tz = [10.4, 13.6, 16.6, 19.4, 22.0]
    ty = [15.6, 15.0, 14.2, 13.4, 12.8]
    tr = [3.8, 3.0, 2.2, 1.5, 0.9]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : bassin, gros ventre, torse dressé
    d.ellipsoid("Hips", (0, 15.6, 4.6), (5.8, 6.0, 6.6), FEATHER, where=left)
    d.ellipsoid("Hips", (0, 13.4, 0.0), (5.4, 4.8, 5.4), FEATHER, where=left)
    d.ellipsoid("Chest", (0, 19.6, -2.8), (5.2, 6.4, 5.2), FEATHER, where=left)
    d.limb("Neck1", (0, 22.8, -5.8), (0, 27.4, -8.8), 3.0, 2.6, FEATHER, where=left)
    d.limb("Neck2", (0, 27.4, -8.8), (0, 31.2, -11.4), 2.6, 2.3, FEATHER, where=left)
    # ---------------------------------------------------------------- petite tête, bec doré, houppe rouge
    d.ellipsoid("Head", (0, 32.8, -13.8), (2.8, 2.5, 3.1), FEATHER, where=left)
    d.limb("Head", (0, 32.2, -16.0), (0, 31.2, -19.4), 1.4, 0.55, BEAK, where=lambda x, y, z: x <= 0 and y >= 31)
    d.limb("Jaw", (0, 30.4, -15.2), (0, 30.6, -18.4), 1.0, 0.45, BEAK, where=lambda x, y, z: x <= 0 and y <= 30)
    for z in range(-18, -14):
        if (0, 31, z) in d.vox and d.vox[(0, 31, z)][1] == BEAK:
            d.set("Head", 0, 31, z, MOUTH)
    d.limb("Head", (0, 34.6, -12.8), (0, 36.6, -9.4), 1.1, 0.5, CREST)
    # ---------------------------------------------------------------- bras longs et trois grandes griffes dorées
    d.limb("ArmL", (-4.6, 20.6, -5.0), (-5.6, 15.6, -6.6), 1.5, 1.25, BACK)
    d.limb("ForearmL", (-5.6, 15.6, -6.6), (-6.0, 11.6, -10.0), 1.25, 1.05, BACK)
    d.ellipsoid("ForearmL", (-6.0, 11.0, -10.6), (2.3, 1.2, 1.3), BACK)
    for x in (-4, -6, -8):
        d.limb("ForearmL", (x, 10.6, -11.0), (x, 7.8, -13.4), 0.8, 0.45, CLAW, "Smooth")
        d.limb("ForearmL", (x, 7.8, -13.4), (x, 5.6, -13.8), 0.55, 0.2, CLAW, "Smooth")
    # frange de plumes derrière l'avant-bras (plaque verticale)
    d.plate("ForearmL", 0, -7, [(15.6, -6.0), (11.6, -9.4), (9.8, -8.4), (13.4, -4.8)], DARK)
    # ---------------------------------------------------------------- pattes : cuisse emplumée, pied large
    d.ellipsoid("ThighL", (-4.8, 11.6, 3.8), (2.8, 4.2, 3.8), FEATHER)
    d.limb("ShinL", (-4.6, 9.0, 2.0), (-4.6, 3.6, 5.2), 2.2, 1.7, SKIN)
    d.limb("FootL", (-4.6, 3.6, 5.2), (-4.6, 1.0, 2.6), 1.7, 1.5, SKIN)
    d.box("FootL", (-7, 0, -1), (-3, 1, 3), SKIN)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, -1))
    # ---------------------------------------------------------------- queue courte, plumes foncées au bout
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], FEATHER, where=left)
    d.ellipsoid("Tail4", (0, 13.0, 22.6), (1.6, 1.8, 2.6), DARK, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 33, -15, IRIS, PUPIL, lid_color=BACK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # dos gris-bleu coupé à plat le long du torse incliné (plan parallèle à son axe), cou et ventre blancs
    d.paint(lambda x, y, z, bone, c: BACK if c == FEATHER and bone in ("Hips", "Chest") and y + 0.54 * z >= 19.5
            else None)
    d.back_stripes(["Tail1", "Tail2", "Tail3"], BACK, frac=0.5, period=1, width=1, only=[FEATHER])
    return d
