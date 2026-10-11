"""Troodon : petit raptor malin du Glacier, à plumes d'hiver, aux énormes yeux ambre et aux longues pattes.

Voxels de 0,133 stud : environ 6 studs de long et 3,7 de haut à la taille Normal (plus petit que l'avatar).
Gros crâne rond (le plus « cérébral » des dinos), museau fin à petites dents, yeux ambre immenses tournés vers l'avant,
houppe de plumes derrière la tête, bras à ailerons de plumes, longues pattes fines à griffe en faucille, longue queue
finie par un éventail de plumes. Plumage blanc dessous, gris dessus, moucheté de bleu-gris."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, hash3  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.133

WHITE = (244, 246, 250)
GREY = (128, 141, 162)
SPECK = (72, 96, 136)
DARK = (70, 84, 108)
SKIN = (84, 94, 116)
CLAW = (240, 244, 250)
HAND = (62, 66, 80)
PUPIL = (22, 20, 26)
IRIS = (255, 166, 28)
SHINE = (255, 246, 214)
MOUTH = (178, 70, 86)
TONGUE = (220, 112, 124)
TOOTH = (252, 250, 242)

# personnalité : lue par la famille d'animation (models/lib/fam_biped.py)
PERSONALITY = {
    "tempo": 1.3,           # vif et curieux
    "weight": 0.65,         # très léger : gros rebonds
    "stride": 1.05,
    "bob": 1.1,
    "headBob": 1.3,         # tête d'oiseau très marquée
    "tail": 1.15,
    "diet": "meat",
    "happy": "hop",         # saut avec un tour complet
    "catch": "headbutt",
}


def build():
    d = Dino("Troodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 15, 2))
    d.bone("Chest", (0, 15.2, -0.6), "Hips")
    d.bone("Neck1", (0, 17.0, -4.6), "Chest")
    d.bone("Neck2", (0, 19.6, -6.4), "Neck1")
    d.bone("Head", (0, 21.8, -7.8), "Neck2")
    d.bone("Jaw", (0, 21.4, -10.6), "Head")
    d.bone_pair("Lid", (-3.0, 26, -11.5), "Head")
    d.bone_pair("Arm", (-2.8, 14.4, -4.0), "Chest")
    d.bone_pair("Forearm", (-3.2, 12.6, -4.8), "ArmL")
    d.bone_pair("Thigh", (-2.8, 14.6, 2.2), "Hips")
    d.bone_pair("Shin", (-3.0, 8.8, -0.4), "ThighL")
    d.bone_pair("Foot", (-3.0, 4.0, 2.8), "ShinL")
    tz = [6.6, 10.0, 13.4, 16.8, 20.2, 23.4]
    ty = [15.8, 16.2, 16.5, 16.8, 17.0, 17.2]
    tr = [2.6, 2.1, 1.65, 1.3, 1.0, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps fin
    d.ellipsoid("Hips", (0, 15.6, 3.0), (3.2, 3.2, 4.4), WHITE, where=left)
    d.ellipsoid("Chest", (0, 15.2, -1.6), (3.3, 3.6, 3.8), WHITE, where=left)
    d.limb("Neck1", (0, 16.6, -4.2), (0, 19.6, -6.4), 2.2, 2.0, WHITE, where=left)
    d.limb("Neck2", (0, 19.6, -6.4), (0, 21.8, -7.8), 2.0, 1.9, WHITE, where=left)
    # ---------------------------------------------------------------- tête : gros crâne rond, museau fin
    d.ellipsoid("Head", (0, 23.8, -11.0), (3.4, 3.3, 3.6), WHITE, where=left, power=3.2)
    d.ellipsoid("Head", (0, 22.8, -15.0), (1.8, 1.5, 2.8), WHITE, where=lambda x, y, z: x <= 0 and y >= 22, power=2.3)
    d.ellipsoid("Jaw", (0, 21.4, -13.2), (1.6, 0.8, 3.4), WHITE, where=lambda x, y, z: x <= 0 and y <= 21, power=2.4)
    d.box("Jaw", (-1, 21, -10), (0, 21, -9), WHITE)
    d.box("Head", (0, 22, -16), (0, 22, -11), MOUTH)
    d.box("Jaw", (0, 21, -15), (0, 21, -11), TONGUE)
    for z in (-16, -14, -12):
        d.set("Head", -1, 22, z, TOOTH, "Smooth")
    d.set("Head", -2, 23, -16, GREY, "Smooth")  # narine
    d.box("Head", (-3, 22, -13), (0, 27, -10), WHITE)  # tempe plate : grand oeil et paupière à fleur de peau
    # houppe de plumes derrière le crâne (trois pointes vers l'arrière)
    tuft = [(25.4, -10.0), (29.0, -8.6), (27.2, -7.8), (28.4, -5.6), (26.2, -6.2), (26.6, -3.8), (23.8, -6.2)]
    d.plate("Head", 0, -1, tuft, GREY, thick=2)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Head" and col == GREY and z >= -7:
            d.set("Head", x, y, z, SPECK)
    # ---------------------------------------------------------------- bras à ailerons de plumes
    d.limb("ArmL", (-2.8, 14.4, -4.0), (-3.2, 12.6, -4.8), 1.0, 0.9, WHITE)
    d.limb("ForearmL", (-3.2, 12.6, -4.8), (-3.2, 11.2, -7.2), 0.85, 0.7, WHITE)
    d.set("ForearmL", -3, 10, -8, HAND, "Smooth")
    d.set("ForearmL", -2, 10, -8, HAND, "Smooth")
    d.plate("ForearmL", 0, -4, [(12.8, -4.4), (11.4, -7.2), (8.2, -5.6), (9.2, -3.2)], GREY)
    d.plate("ArmL", 0, -4, [(14.6, -3.4), (12.8, -4.4), (9.2, -3.2), (11.2, -2.2)], GREY)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone in ("ArmL", "ForearmL") and col == GREY and (x, y - 1, z) not in d.vox:
            d.set(bone, x, y, z, SPECK)
    # ---------------------------------------------------------------- longues pattes fines, cuisses emplumées
    d.ellipsoid("ThighL", (-3.2, 12.2, 1.2), (1.9, 3.2, 2.7), WHITE)
    d.limb("ShinL", (-3.0, 8.8, -0.4), (-3.0, 4.0, 2.8), 1.15, 0.85, SKIN)
    d.limb("FootL", (-3.0, 4.0, 2.8), (-3.0, 0.8, 0.4), 0.8, 0.75, SKIN)
    d.box("FootL", (-4, 0, -2), (-2, 0, 1), SKIN)
    d.box("FootL", (-3, 1, -1), (-2, 1, 1), SKIN)
    for x in (-4, -2):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.set("FootL", -1, 1, -1, CLAW, "Smooth")       # griffe en faucille relevée
    d.set("FootL", -1, 2, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3, 0, -2.5))
    # ---------------------------------------------------------------- longue queue et éventail de plumes
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], WHITE, where=left)
    fan = [(0.4, 19.4), (-2.4, 20.6), (-3.8, 23.4), (-2.6, 23.2), (-2.6, 25.8), (-1.2, 25.2), (-0.6, 27.2),
           (0.4, 27.2)]
    d.plate("Tail5", 1, 17, fan, GREY)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Tail5" and col == GREY and z >= 24:
            d.set("Tail5", x, y, z, SPECK)

    # ---------------------------------------------------------------- yeux immenses (pupille fendue au centre)
    d.eye("Head", "LidL", 22, -13, IRIS, IRIS, lid_color=GREY, h=3, w=4)
    for dy, dz, c in ((0, 1, PUPIL), (1, 1, PUPIL), (0, 2, PUPIL), (1, 2, PUPIL), (2, 3, SHINE)):
        x = d.surface_x(22 + dy, -13 + dz)
        if x is not None:
            d.set("Head", x, 22 + dy, -13 + dz, c, "Smooth")
    for dy in range(3):  # arcade devant la paupière : yeux fermés, elle couvre aussi l'oeil vu de face
        d.set("LidL", d.surface_x(22 + dy, -13), 25 + dy, -14, GREY)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : dos gris coupé à plat, mouchetures
    back = {"Hips": 17, "Chest": 17, "Neck1": 19, "Neck2": 21, "Tail1": 17, "Tail2": 17, "Tail3": 17, "Tail4": 17,
            "Tail5": 18, "Head": 26}
    d.paint(lambda x, y, z, bone, c: GREY if c == WHITE and bone in back and y >= back[bone] else None)
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "ThighL", "ThighR"]
    d.paint(lambda x, y, z, bone, c: SPECK if bone in body and c in (GREY, WHITE) and
            (x + 2 * y + 3 * z) % 5 == 0 and hash3(abs(x), y, z, 7) < (0.6 if c == GREY else 0.2) else None)
    return d
