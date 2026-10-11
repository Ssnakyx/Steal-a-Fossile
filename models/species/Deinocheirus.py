"""Deinocheirus : bipède Legendary du Meteor Crater, géant bizarre aux bras immenses.

Voxels de 0,37 stud : environ 20 studs de long et 11 de haut (bosse comprise) à la taille Normal. Corps roux au gros
ventre crème, haute bosse-voile sur le dos (plaque rayée de brun, portée par le torse et le bassin), long cou en deux
segments épais, tête au large bec de canard, bras immenses terminés par trois énormes griffes sombres, pattes
trapues et queue courte finie par un éventail de plumes (plaque verticale aux pointes crème)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.37

BODY = (188, 88, 48)
DARK = (116, 50, 34)
BELLY = (242, 222, 184)
BILL = (234, 198, 124)
CLAW = (56, 42, 42)
TIP = (250, 236, 206)
PUPIL = (26, 20, 18)
IRIS = (255, 198, 52)
MOUTH = (176, 82, 88)

PERSONALITY = {
    "tempo": 0.8,           # géant posé, un peu gauche
    "weight": 1.4,
    "stride": 0.85,
    "bob": 0.9,
    "headBob": 0.4,         # long cou : la tête se stabilise puis avance
    "tail": 0.7,
    "diet": "plants",       # broute (omnivore, surtout des plantes)
    "happy": "sway",        # pas de tour sur lui-même : trop grand
    "catch": "headbutt",
}


def build():
    d = Dino("Deinocheirus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 14, 4))
    d.bone("Chest", (0, 15.4, -1.4), "Hips")
    d.bone("Neck1", (0, 19.4, -6.6), "Chest")
    d.bone("Neck2", (0, 23.2, -9.6), "Neck1")
    d.bone("Head", (0, 26.0, -12.4), "Neck2")
    d.bone("Jaw", (0, 24.6, -15.6), "Head")
    d.bone_pair("Lid", (-2.4, 28, -15), "Head")
    d.bone_pair("Arm", (-4.4, 17.6, -4.6), "Chest")
    d.bone_pair("Forearm", (-5.4, 12.0, -6.6), "ArmL")
    d.bone_pair("Thigh", (-4.2, 13.4, 5.0), "Hips")
    d.bone_pair("Shin", (-4.6, 8.0, 2.4), "ThighL")
    d.bone_pair("Foot", (-4.6, 3.4, 5.4), "ShinL")
    tz = [10.6, 14.0, 17.2, 20.2, 22.8]
    ty = [15.6, 15.4, 15.0, 14.6, 14.2]
    tr = [3.6, 2.8, 2.1, 1.5, 1.0]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : bassin haut et gros ventre, torse
    # (une seule masse coupée en deux par un plan : formes simples, peu de pièces)
    d.ellipsoid("Hips", (0, 14.4, 3.4), (5.3, 6.0, 7.2), BODY, where=left, power=2.5)
    d.ellipsoid("Hips", (0, 15.8, -2.6), (4.8, 5.4, 5.0), BODY, where=left, power=2.5)
    for k, (b, c, m) in list(d.vox.items()):
        if k[2] < 0:
            d.vox[k] = ("Chest", c, m)
    d.limb("Neck1", (0, 18.6, -6.0), (0, 23.2, -9.6), 3.3, 2.9, BODY, where=left)
    d.limb("Neck2", (0, 23.2, -9.6), (0, 26.0, -12.2), 2.9, 2.7, BODY, where=left)
    # ---------------------------------------------------------------- tête : crâne, large bec de canard plat
    d.ellipsoid("Head", (0, 27.4, -14.6), (3.0, 2.9, 3.4), BODY, where=left, power=2.4)
    for z in range(-25, -16):
        w = 1.6 + (-17 - z) * 0.2                   # le bec s'élargit vers le bout (spatule)
        if z <= -24:
            w -= 1.2                                # bout arrondi
        for x in range(-4, 1):
            if abs(x) <= w:
                d.set("Head", x, 25, z, BILL)
                if z >= -22:
                    d.set("Head", x, 26, z, BILL)
                if z <= -18:
                    d.set("Jaw", x, 24, z, BILL)
    d.ellipsoid("Jaw", (0, 23.8, -16.0), (2.0, 1.0, 2.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 24)
    for z in range(-23, -15):
        if (0, 25, z) in d.vox:
            d.set("Head", 0, 25, z, MOUTH)
        if (0, 24, z) in d.vox:
            d.set("Jaw", 0, 24, z, MOUTH)
    d.set("Head", -1, 26, -23, CLAW, "Smooth")  # narine
    # ---------------------------------------------------------------- bras immenses et trois énormes griffes
    d.limb("ArmL", (-4.4, 17.6, -4.6), (-5.4, 12.0, -6.6), 1.8, 1.5, BODY)
    d.limb("ForearmL", (-5.4, 12.0, -6.6), (-5.8, 8.2, -9.6), 1.5, 1.25, BODY)
    d.ellipsoid("ForearmL", (-5.8, 7.6, -10.4), (2.2, 1.3, 1.4), BODY)
    for x in (-4, -6, -8):
        d.limb("ForearmL", (x, 7.2, -11.2), (x, 4.6, -13.0), 0.85, 0.6, CLAW, "Smooth")
        d.limb("ForearmL", (x, 4.6, -13.0), (x, 2.6, -12.6), 0.6, 0.25, CLAW, "Smooth")
    # frange de plumes derrière l'avant-bras (plaque verticale)
    d.plate("ForearmL", 0, -7, [(12.6, -6.0), (8.6, -9.0), (7.0, -8.0), (10.8, -5.0)], DARK)
    # ---------------------------------------------------------------- pattes trapues, larges pieds aux griffes sombres
    d.ellipsoid("ThighL", (-4.8, 10.6, 3.8), (2.8, 4.2, 3.8), BODY)
    d.limb("ShinL", (-4.6, 8.0, 2.4), (-4.6, 3.4, 5.4), 2.2, 1.8, BODY)
    d.limb("FootL", (-4.6, 3.4, 5.4), (-4.6, 1.0, 2.8), 1.8, 1.6, BODY)
    d.box("FootL", (-7, 0, -1), (-3, 1, 3), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, -1))
    # ---------------------------------------------------------------- queue courte
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 27, -16, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()

    def paint(x, y, z, bone, c):
        if c != BODY:
            return None
        if bone in ("Hips", "Chest") and y <= 11:
            return BELLY                                    # gros ventre crème coupé à plat
        if bone == "Chest" and z <= -5 and y <= 15:
            return BELLY
        if bone in ("Tail1", "Tail2", "Tail3") and y <= ty[int(bone[4]) - 1] - 1.5:
            return BELLY
        return None
    d.paint(paint)

    # ---------------------------------------------------------------- bosse-voile (posée après la peinture du corps)
    # plaque au milieu du dos, sur 3 voxels d'épaisseur à la base ; rayons bruns un sur trois, bord supérieur brun
    def top(z):
        ys = [y for (x, y, zz), v in d.vox.items() if x == 0 and zz == z and v[0] in ("Hips", "Chest")]
        return max(ys) if ys else None

    for z in range(-6, 14):
        t = top(z)
        if t is None:
            continue
        # profil de la bosse : monte doucement depuis les épaules, le plus haut au-dessus du bassin, retombe vite
        h = 28.6 - (0.032 if z < 5 else 0.07) * (z - 5) ** 2
        if h < t + 1:
            continue
        bone = "Chest" if z < 0 else "Hips"
        hi = int(round(h))
        for y in range(t + 1, hi + 1):
            col = DARK if (z % 4 == 1 and y >= t + 2) or y >= hi - 0 else BODY
            d.set(bone, 0, y, z, col)
            if y <= t + 2:
                d.set(bone, -1, y, z, col)
                d.set(bone, 1, y, z, col)
    # ---------------------------------------------------------------- éventail de plumes au bout de la queue
    # plaque verticale en éventail relevé (3 voxels d'épaisseur, un seul au bord) : plumes brunes, pointes crème
    # au bord festonné
    fy, fz, R = 15.0, 21.0, 8.4
    for y in range(int(fy - R) - 1, int(fy + R) + 2):
        for z in range(int(fz) - 1, int(fz + R) + 2):
            dy, dz = y + 0.5 - fy, z + 0.5 - fz
            r = math.hypot(dy, dz)
            a = math.degrees(math.atan2(dy, dz))         # 0 = vers l'arrière, > 0 = vers le haut
            if r > R or a < -40 or a > 80 or (0, y, z) in d.vox:
                continue
            k = (a + 40) / 120 * 5                       # cinq plumes
            if r > R - 1.1 and abs(k - math.floor(k) - 0.5) > 0.32:
                continue                                 # festons entre les pointes
            col = TIP if r > R - 2.0 else (DARK if r > 2.6 else BODY)
            d.set("Tail4", 0, y, z, col)
            if r <= R - 2.0:
                d.set("Tail4", -1, y, z, col)
                d.set("Tail4", 1, y, z, col)
    return d
