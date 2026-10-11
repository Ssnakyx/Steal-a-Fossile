"""Kentrosaurus : quadrupède de la Fern Forest, petit cousin hérissé du Stégosaure.

Voxels de 0,244 stud : environ 11 studs de long (pointes de la queue comprises) et 5 de haut à la taille Normal.
Petite tête basse à bec, pattes avant courtes, dos voûté. Paires de plaques pointues sur le cou et l'avant du dos qui
deviennent de longues pointes sur les hanches et la queue (de plus en plus couchées vers l'arrière), et une grande
pointe sur chaque épaule. Plaques et pointes portées par les os du corps et de la queue (elles suivent le dos)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.244

BODY = (64, 116, 58)
DARK = (96, 66, 42)
BELLY = (214, 204, 156)
PLATE = (226, 196, 134)
TIP = (246, 138, 40)
BEAK = (70, 58, 50)
NAIL = (232, 224, 202)
PUPIL = (26, 22, 20)
IRIS = (255, 206, 80)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.85,          # plus vif que le Stégosaure, mais posé
    "weight": 1.25,
    "stride": 0.95,
    "bob": 0.9,
    "headBob": 0.0,
    "tail": 0.9,            # queue à pointes : la balance est son arme
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
}

TZ = [8.6, 12.0, 15.4, 18.6, 21.6, 24.4]
TY = [10.0, 10.0, 9.6, 9.1, 8.6, 8.2]
TR = [3.3, 2.6, 2.0, 1.5, 1.0, 0.7]


def seg_of(z):
    """Os qui porte une plaque ou une pointe selon sa position le long du dos."""
    for a, b, bone in ((-99, -4.4, "Neck1"), (-4.4, 1.0, "Chest"), (1.0, 8.6, "Hips"), (8.6, 12.0, "Tail1"),
                       (12.0, 15.4, "Tail2"), (15.4, 18.6, "Tail3"), (18.6, 21.6, "Tail4")):
        if a <= z < b:
            return bone
    return "Tail5"


def build():
    d = Dino("Kentrosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.0, 3.4))
    d.bone("Chest", (0, 7.8, -1.2), "Hips")
    d.bone("Neck1", (0, 7.4, -5.0), "Chest")
    d.bone("Head", (0, 6.8, -8.0), "Neck1")
    d.bone("Jaw", (0, 5.8, -9.8), "Head")
    d.bone_pair("Lid", (-1.8, 8, -10.5), "Head")
    d.bone_pair("Arm", (-3.4, 6.2, -3.8), "Chest")
    d.bone_pair("Forearm", (-3.8, 3.6, -2.8), "ArmL")
    d.bone_pair("Hand", (-3.8, 1.6, -4.2), "ForearmL")
    d.bone_pair("Thigh", (-3.8, 8.6, 4.6), "Hips")
    d.bone_pair("Shin", (-4.1, 4.6, 2.8), "ThighL")
    d.bone_pair("Foot", (-4.1, 2.0, 5.0), "ShinL")
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, TY[i], TZ[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps voûté (hanches hautes, épaules basses)
    d.ellipsoid("Hips", (0, 9.6, 4.0), (4.0, 4.3, 4.8), BODY, where=left, power=2.4)
    d.ellipsoid("Chest", (0, 8.0, -1.8), (3.6, 3.8, 3.9), BODY, where=left, power=2.4)
    d.limb("Neck1", (0, 7.8, -4.6), (0, 6.8, -8.0), 2.4, 1.9, BODY, where=left)
    # ---------------------------------------------------------------- petite tête basse à bec
    d.ellipsoid("Head", (0, 7.0, -10.0), (1.8, 1.9, 2.3), BODY, where=left, power=2.3)
    d.ellipsoid("Head", (0, 6.4, -12.2), (1.2, 1.1, 1.1), BEAK, where=lambda x, y, z: x <= 0 and y >= 6)
    d.ellipsoid("Jaw", (0, 5.5, -10.8), (1.2, 0.8, 1.9), BELLY, where=lambda x, y, z: x <= 0 and y <= 5, power=2.3)
    d.ellipsoid("Jaw", (0, 5.5, -12.2), (0.9, 0.7, 0.8), BEAK, where=lambda x, y, z: x <= 0 and y <= 5)
    d.box("Jaw", (-1, 5, -9), (0, 5, -8), BODY)
    for z in range(-12, -8):
        if (0, 6, z) in d.vox:
            d.set("Head", 0, 6, z, MOUTH)
    # ---------------------------------------------------------------- pattes : piliers, avant courtes
    d.limb("ArmL", (-3.4, 6.2, -3.8), (-3.8, 3.6, -2.8), 1.6, 1.3, BODY)
    d.limb("ForearmL", (-3.8, 3.6, -2.8), (-3.8, 1.6, -4.2), 1.3, 1.1, BODY)
    d.limb("HandL", (-3.8, 1.6, -4.2), (-3.8, 0.6, -4.6), 1.1, 1.1, BODY)
    d.box("HandL", (-5, 0, -6), (-3, 1, -4), BODY)
    for x in (-5, -3):
        d.set("HandL", x, 0, -7, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-4.1, 6.6, 4.1), (2.1, 3.4, 2.7), BODY)
    d.limb("ShinL", (-4.1, 4.6, 2.8), (-4.1, 2.0, 5.0), 1.7, 1.4, BODY)
    d.limb("FootL", (-4.1, 2.0, 5.0), (-4.1, 0.6, 3.6), 1.4, 1.4, BODY)
    d.box("FootL", (-5, 0, 2), (-3, 1, 4), BODY)
    for x in (-5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, 1.8))
    d.point("FrontToeL", "HandL", (-4, 0, -5.8))
    # ---------------------------------------------------------------- queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, TY[i], TZ[i]), (0, TY[i + 1], TZ[i + 1]), TR[i], TR[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux + peinture du corps
    d.eye("Head", "LidL", 6, -11, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    belly = {"Hips": 6, "Chest": 5, "Neck1": 6, "Tail1": 8, "Tail2": 8, "Tail3": 8}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)

    # ---------------------------------------------------------------- pointes : segment épais effilé, bout orange
    def spike(bone, base, tip, r0, r1, frac=0.6):
        d.limb(bone, base, tip, r0, r1, PLATE)
        bx, by, bz = base
        tx, ty, tz = tip
        ln = math.dist(base, tip)
        for (x, y, z), (b, col, mat) in list(d.vox.items()):
            if b == bone and col == PLATE:
                k = ((x - bx) * (tx - bx) + (y - by) * (ty - by) + (z - bz) * (tz - bz)) / (ln * ln)
                if k >= frac:
                    d.set(bone, x, y, z, TIP)

    # grande pointe d'épaule : vers l'arrière, l'extérieur et un peu le haut
    spike("Chest", (-2.8, 8.6, -2.4), (-9.2, 10.0, 3.8), 1.3, 0.4)
    # plaques pointues sur le cou et l'avant du dos (paires) : plaques droites posées sur le dos, qui remplissent
    # seulement le vide (le corps garde sa couleur), bout orange
    plates = [(-7.0, 2.2, 1.1), (-4.4, 3.0, 1.4), (-1.6, 3.8, 1.5), (1.2, 4.4, 1.4)]
    tops = {z: d.surface_y(-1, z) for z in range(-9, 4)}
    for zc, h, half in plates:
        base = tops[int(round(zc))]
        bone = seg_of(zc)
        y0 = base - 1
        poly = [(y0, zc - half), (y0 + 0.5 * h, zc - half), (y0 + h + 1, zc + 0.5), (y0 + 0.4 * h, zc + half + 0.4),
                (y0, zc + half + 0.3)]
        tmp = Dino("tmp", FAMILY, voxel=VOXEL)
        tmp.bone(bone, (0, 0, 0))
        tmp.plate(bone, 0, -2, poly, PLATE)
        for (x, y, z) in tmp.vox:
            if (x, y, z) not in d.vox:
                d.set(bone, x, y, z, TIP if y >= y0 + 0.62 * (h + 1) else PLATE)
    # longues pointes en paires sur les hanches et la queue, de plus en plus couchées vers l'arrière
    spikes = [(4.0, 6.4, 16), (8.2, 7.6, 34), (12.6, 8.6, 50), (17.0, 9.4, 62), (21.2, 10.4, 74)]
    for zc, ln, back in spikes:
        zi = int(round(zc))
        top = d.surface_y(-1, zi)
        if top is None:
            continue
        bone = seg_of(zc)
        a = math.radians(back)
        dx, dy, dz = -0.18, math.cos(a), math.sin(a)
        m = math.sqrt(dx * dx + dy * dy + dz * dz)
        base = (-1.4, top - 0.5, zc)
        tip = (base[0] + ln * dx / m, base[1] + ln * dy / m, base[2] + ln * dz / m)
        spike(bone, base, tip, 1.3, 0.4, frac=0.62)
    d.mirror()
    # selle brune sur le dos, coupée à plat (peu de pièces)
    saddle = {"Neck1": 9, "Chest": 11, "Hips": 12, "Tail1": 12, "Tail2": 11, "Tail3": 10, "Tail4": 9, "Tail5": 9}
    d.paint(lambda x, y, z, bone, c: DARK if c == BODY and bone in saddle and y >= saddle[bone] else None)
    return d
