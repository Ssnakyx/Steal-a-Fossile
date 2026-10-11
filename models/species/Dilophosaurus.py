"""Dilophosaurus : bipède de la Fern Forest, prédateur élancé aux deux crêtes.

Voxels de 0,26 stud : environ 12 studs de long et 7 de haut (crêtes comprises) à la taille Normal.
Long cou en S, tête étroite au long museau (encoche entre l'avant et l'arrière de la mâchoire), deux crêtes rouge vif
parallèles sur le crâne (os Crest, deux plaques droites), bras assez longs à trois griffes, longue queue.
Jaune-vert à taches foncées, ventre clair."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, hash3  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.26

BODY = (212, 200, 60)
SPOT = (58, 86, 42)
BELLY = (240, 234, 186)
CREST = (232, 44, 36)
CREST_DARK = (150, 24, 30)
CLAW = (246, 240, 226)
PUPIL = (26, 20, 18)
IRIS = (255, 150, 30)
MOUTH = (176, 56, 66)
TONGUE = (214, 98, 104)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 1.1,           # chasseur souple
    "weight": 0.9,
    "stride": 1.05,
    "bob": 1.0,
    "headBob": 0.6,
    "tail": 1.0,
    "diet": "meat",         # Eat : mord, tire, mâche
    "happy": "hop",
    "catch": "headbutt",
}

TZ = [8.0, 11.6, 15.2, 18.6, 21.8, 25.0]
TY = [13.8, 14.2, 14.5, 14.7, 14.8, 14.9]
TR = [3.3, 2.7, 2.1, 1.6, 1.15, 0.7]


def build():
    d = Dino("Dilophosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 13.4, 2))
    d.bone("Chest", (0, 13.4, -1.5), "Hips")
    d.bone("Neck1", (0, 15.2, -6.6), "Chest")
    d.bone("Neck2", (0, 18.0, -8.6), "Neck1")
    d.bone("Head", (0, 20.4, -10.0), "Neck2")
    d.bone("Jaw", (0, 19.4, -12.4), "Head")
    d.bone("Crest", (0, 23.0, -14.0), "Head")
    d.bone_pair("Lid", (-2.6, 22, -13.5), "Head")
    d.bone_pair("Arm", (-3.4, 12.4, -5.6), "Chest")
    d.bone_pair("Forearm", (-3.9, 10.0, -6.6), "ArmL")
    d.bone_pair("Thigh", (-3.8, 12.8, 2.4), "Hips")
    d.bone_pair("Shin", (-4.1, 7.4, -0.4), "ThighL")
    d.bone_pair("Foot", (-4.1, 3.6, 2.8), "ShinL")
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, TY[i], TZ[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps élancé, cou en S
    d.ellipsoid("Hips", (0, 13.6, 3.4), (3.8, 3.9, 5.0), BODY, where=left)
    d.ellipsoid("Chest", (0, 13.2, -3.0), (3.9, 4.2, 4.4), BODY, where=left)
    d.limb("Neck1", (0, 14.8, -6.2), (0, 18.0, -8.6), 2.6, 2.3, BODY, where=left)
    d.limb("Neck2", (0, 18.0, -8.6), (0, 20.4, -10.0), 2.3, 2.2, BODY, where=left)
    # ---------------------------------------------------------------- tête étroite, long museau, mâchoire séparée
    d.ellipsoid("Head", (0, 21.0, -12.4), (3.1, 2.6, 3.2), BODY, where=left, power=2.5)
    d.ellipsoid("Head", (0, 20.6, -17.2), (2.3, 1.7, 3.8), BODY, where=lambda x, y, z: x <= 0 and y >= 20, power=2.6)
    d.ellipsoid("Jaw", (0, 19.2, -16.0), (1.7, 0.9, 4.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 19, power=2.6)
    d.box("Jaw", (-1, 19, -13), (0, 19, -12), BODY)
    # encoche de la mâchoire supérieure (le bout du museau descend un peu plus bas)
    d.box("Head", (-1, 19, -21), (0, 19, -20), BODY)
    d.box("Head", (0, 20, -19), (0, 20, -14), MOUTH)
    d.box("Jaw", (0, 19, -19), (0, 19, -14), TONGUE)
    for z in (-21, -18, -16, -14):
        d.set("Head", -1, 18 if z <= -20 else 20, z, TOOTH, "Smooth")
    d.set("Head", -1, 21, -20, SPOT, "Smooth")  # narine
    d.eye("Head", "LidL", 20, -14, IRIS, PUPIL, lid_color=SPOT, h=2, w=2)
    # ---------------------------------------------------------------- deux crêtes parallèles (plaques droites)
    # une plaque par côté (x = -2, puis symétrie) posée sur le dessus du crâne : demi-lune qui monte vers l'arrière
    # et finit par une petite pointe tournée vers l'arrière ; l'écart entre les deux crêtes se voit de face
    crest = [(21.0, -20.4), (22.8, -19.6), (24.2, -17.8), (25.3, -15.6), (26.0, -13.4), (26.3, -11.4), (26.9, -8.6),
             (25.2, -9.6), (24.0, -10.4), (21.0, -10.8)]
    head = [(x, y, z) for (x, y, z), v in d.vox.items() if v[0] == "Head" or v[0].startswith("Lid")]
    seat = {}
    for x, y, z in head:
        if x in (-2, -1):
            seat[z] = max(seat.get(z, y), y)
    tmp = Dino("tmp", FAMILY, voxel=VOXEL)
    tmp.bone("Crest", (0, 0, 0))
    tmp.plate("Crest", 0, -2, crest, CREST)
    for (x, y, z) in tmp.vox:
        if y > seat.get(z, 21) and (x, y, z) not in d.vox:
            d.set("Crest", x, y, z, CREST)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Crest" and z in (-17, -13):
            d.set("Crest", x, y, z, CREST_DARK)
    # ---------------------------------------------------------------- bras à trois griffes
    d.limb("ArmL", (-3.4, 12.4, -5.6), (-3.9, 10.0, -6.6), 1.3, 1.1, BODY)
    d.limb("ForearmL", (-3.9, 10.0, -6.6), (-3.8, 8.6, -9.0), 1.0, 0.85, BODY)
    for p in ((-4, 7, -10), (-3, 7, -10), (-4, 8, -11)):
        d.set("ForearmL", *p, CLAW, "Smooth")
    # ---------------------------------------------------------------- pattes
    d.ellipsoid("ThighL", (-4.0, 10.2, 1.0), (2.4, 3.6, 3.3), BODY)
    d.limb("ShinL", (-4.1, 7.4, -0.4), (-4.1, 3.6, 2.8), 1.6, 1.2, BODY)
    d.limb("FootL", (-4.1, 3.6, 2.8), (-4.1, 1.0, 0.6), 1.2, 1.1, BODY)
    d.box("FootL", (-5, 0, -4), (-3, 0, 1), BODY)
    d.box("FootL", (-5, 1, -3), (-3, 1, 1), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, -5, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -4))
    # ---------------------------------------------------------------- longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, TY[i], TZ[i]), (0, TY[i + 1], TZ[i + 1]), TR[i], TR[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    body = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4"]
    d.countershade(body, BELLY, frac=0.3, only=[BODY])
    col = d.columns(body)
    d.paint(lambda x, y, z, bone, c: BODY if bone in body and c == BELLY and (bone, x, z) in col
            and y >= (col[(bone, x, z)][0] + col[(bone, x, z)][1]) / 2 else None)
    # taches foncées sur le dos et le haut des flancs (motif symétrique)
    spotted = ["Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "ThighL", "ThighR"]
    cols = d.columns(spotted)

    def spots(x, y, z, bone, c):
        if c != BODY or bone not in spotted:
            return None
        lo, hi = cols[(bone, x, z)]
        if y < lo + 0.45 * (hi - lo + 1):
            return None
        if hash3(abs(x) // 2, y // 2, z // 2, 7) < 0.3:
            return SPOT
        return None
    d.paint(spots)
    return d
