"""Dimetrodon : reptile à voile du Swamp (un synapside, pas un dinosaure), trapu et puissant.

Voxels de 0,21 stud : environ 10 studs de long et 5 de haut (voile comprise) à la taille Normal. Grande voile dorsale
en arche (plaque d'un voxel au milieu du dos, portée entière par le torse et enfoncée dans le dos pour qu'aucune fente
n'apparaisse quand le corps se tord), rayée d'épines sombres dont les bouts dépassent du bord ; grosse tête haute à
crocs, pattes écartées de lézard, longue queue. Corps gris-brun, ventre clair, voile rouille."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.21

BODY = (142, 120, 96)
DARK = (96, 78, 62)
BELLY = (222, 204, 168)
SAIL = (206, 98, 46)
SPINE = (110, 50, 34)
TOOTH = (250, 246, 232)
CLAW = (232, 224, 204)
PUPIL = (24, 20, 18)
IRIS = (255, 188, 48)
MOUTH = (160, 52, 56)
TONGUE = (206, 100, 104)

PERSONALITY = {
    "tempo": 0.9,           # reptile posé, démarche chaloupée
    "weight": 1.15,
    "stride": 0.9,
    "bob": 0.7,
    "headBob": 0.0,
    "tail": 1.1,
    "diet": "meat",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.5,
}

# voile, profil (y, z) : arche plus raide à l'avant, sommet au-dessus du torse
SAIL_POLY = [(7.5, -8.4), (12.0, -9.2), (16.0, -8.6), (19.0, -6.6), (20.8, -3.8), (21.6, -0.6), (21.4, 2.4),
             (20.2, 5.2), (18.0, 7.6), (15.0, 9.4), (11.5, 10.4), (7.5, 10.6)]


def build():
    d = Dino("Dimetrodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 7, 4))
    d.bone("Chest", (0, 7, -2), "Hips")
    d.bone("Neck1", (0, 8, -10), "Chest")
    d.bone("Head", (0, 8.6, -13), "Neck1", rest=(7, 0, 0))
    d.bone("Jaw", (0, 7.5, -15.5), "Head")
    d.bone_pair("Lid", (-3, 12, -17), "Head")
    d.bone_pair("Arm", (-4.0, 6.5, -6.5), "Chest")
    d.bone_pair("Forearm", (-6.6, 4.0, -5.0), "ArmL")
    d.bone_pair("Hand", (-7.0, 1.4, -7.0), "ForearmL")
    d.bone_pair("Thigh", (-4.0, 6.5, 5.0), "Hips")
    d.bone_pair("Shin", (-6.6, 4.0, 3.4), "ThighL")
    d.bone_pair("Foot", (-7.0, 1.4, 5.4), "ShinL")
    tz = [10.2, 13.6, 16.8, 19.8, 22.4, 24.6]
    ty = [7.4, 7.2, 6.8, 6.4, 6.0, 5.7]
    tr = [3.3, 2.7, 2.1, 1.6, 1.1, 0.6]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps bas et large
    d.ellipsoid("Hips", (0, 7.0, 4.4), (4.4, 3.2, 6.0), BODY, where=left, power=2.6)
    d.ellipsoid("Chest", (0, 7.2, -4.0), (4.8, 3.4, 5.6), BODY, where=left, power=2.6)
    d.limb("Neck1", (0, 7.8, -9.0), (0, 8.6, -12.6), 3.2, 2.9, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête haute et longue, crocs
    # crâne en coin : haut à l'arrière, il descend en pente douce vers le museau ; mâchoire du bas séparée
    for z in range(-23, -11):
        t = min(1.0, (z + 23) / 8.0)
        top = int(10.8 + 3.4 * t ** 0.8)
        w = 2.0 + 1.3 * min(1.0, (z + 23) / 9.0)
        if z >= -13:
            top -= 1
        for y in range(8, top + 1):
            ww = w - (1.0 if y >= top else 0.0) - (0.6 if y == top - 1 else 0.0)
            for x in range(-int(ww + 0.5), 1):
                d.set("Head", x, y, z, BODY)
        if z <= -13:
            for y, dw in ((7, 0.4), (6, 1.2)):
                if y == 6 and (z < -22 or z > -14):
                    continue
                for x in range(-int(w - dw + 0.5), 1):
                    d.set("Jaw", x, y, z, BODY)
    d.set("Head", -1, 10, -23, DARK, "Smooth")                         # narine
    # ---------------------------------------------------------------- pattes écartées de lézard
    d.ellipsoid("ArmL", (-5.2, 5.8, -6.0), (1.9, 1.8, 1.9), BODY)
    d.limb("ArmL", (-4.2, 6.5, -6.5), (-6.6, 4.0, -5.0), 1.6, 1.4, BODY)
    d.limb("ForearmL", (-6.6, 4.0, -5.0), (-7.0, 1.4, -7.0), 1.3, 1.1, BODY)
    d.box("HandL", (-8, 0, -9), (-6, 1, -7), BODY)
    for x in (-9, -7, -5):
        d.set("HandL", x, 0, -10, CLAW, "Smooth")
    d.ellipsoid("ThighL", (-5.2, 5.8, 4.6), (2.1, 2.0, 2.4), BODY)
    d.limb("ThighL", (-4.2, 6.5, 5.0), (-6.6, 4.0, 3.4), 1.8, 1.5, BODY)
    d.limb("ShinL", (-6.6, 4.0, 3.4), (-7.0, 1.4, 5.4), 1.4, 1.2, BODY)
    d.box("FootL", (-8, 0, 2), (-6, 1, 5), BODY)
    for x in (-9, -7, -5):
        d.set("FootL", x, 0, 1, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-7, 0, 2.5))
    d.point("FrontToeL", "HandL", (-7, 0, -8.5))
    # ---------------------------------------------------------------- longue queue
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux, symétrie
    d.eye("Head", "LidL", 11, -17, IRIS, PUPIL, lid_color=DARK, h=1, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- gueule : creux intérieur rouge, dents au bord
    jaw = {k for k, v in d.vox.items() if v[0] == "Jaw"}
    for (x, y, z) in list(jaw):
        if y != 7:
            continue
        ring = all((x + dx, 7, z + dz) in jaw for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        if ring and all((x + dx, 8, z + dz) in d.vox for dx, dz in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1))) \
                and (x, 9, z) in d.vox:
            d.clear(x, 7, z)
            if all((x + dx, 6, z + dz) in d.vox for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                d.set("Jaw", x, 6, z, TONGUE)
            d.set("Head", x, 8, z, MOUTH)
    # deux grands crocs devant (ils remplacent le bord de la mâchoire et pendent un peu dessous), petites dents derrière
    for sx in (-1, 1):
        for z in (-21, -20):
            x = d.surface_x(8, z, "Head")
            for y in (7, 6):
                d.set("Head", sx * abs(x), y, z, TOOTH, "Smooth")
        for z in (-18, -16, -14):
            x = d.surface_x(8, z, "Head")
            d.set("Head", sx * abs(x), 7, z, TOOTH, "Smooth")
    # ---------------------------------------------------------------- peinture : ventre clair, dos foncé
    belly = {"Hips": 5, "Chest": 5, "Neck1": 6, "Jaw": 6, "Tail1": 5, "Tail2": 5, "Tail3": 5}
    back = {"Hips": 9, "Chest": 9, "Neck1": 10, "Head": 12, "Tail1": 9, "Tail2": 8, "Tail3": 8, "Tail4": 7, "Tail5": 6}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else
            (DARK if c == BODY and bone in back and y >= back[bone] else None))
    # ---------------------------------------------------------------- voile : plaque d'un voxel, tout sur le torse,
    # enfoncée dans le dos ; épines sombres toutes les 3 rangées, dont le bout dépasse du bord
    d.plate("Chest", 0, 0, SAIL_POLY, SAIL)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if col == SAIL and z % 3 == 0:
            d.set(bone, x, y, z, SPINE)
            if (x, y + 1, z) not in d.vox and y > 12:
                d.set(bone, x, y + 1, z, SPINE)
    return d
