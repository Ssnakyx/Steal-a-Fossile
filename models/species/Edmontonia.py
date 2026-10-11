"""Edmontonia : quadrupède du Canyon, nodosaure blindé, lent et têtu.

Voxels de 0,285 stud : environ 13 studs de long, 5 de haut et 7 de large (pointes comprises) à la taille Normal.
Corps bas et large, dos couvert de rangées de boucliers osseux en relief (plaques sombres au milieu, bosses claires sur
les bords), deux grandes pointes d'épaule fourchues pointées vers l'avant, pointes plus petites le long des flancs et
de la queue, demi-anneaux d'armure sur le cou, tête étroite en poire à petit bec, queue effilée (pas de massue)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.285

BODY = (178, 88, 52)
ARMOR = (112, 50, 36)
KNOB = (228, 152, 90)
BELLY = (234, 200, 154)
SPIKE = (244, 236, 216)
BEAK = (78, 64, 60)
NAIL = (232, 224, 202)
PUPIL = (26, 22, 20)
IRIS = (255, 200, 70)
MOUTH = (184, 92, 96)

PERSONALITY = {
    "tempo": 0.8,           # lent, pas lourds
    "weight": 1.4,
    "stride": 0.9,
    "bob": 0.7,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "plants",
    "happy": "stomp",
    "catch": "ram",         # charge épaules en avant (les grandes pointes)
    "sleepDrop": 0.42,      # corps déjà bas : se couche moins loin
}


def build():
    d = Dino("Edmontonia", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 8.6, 5))
    d.bone("Chest", (0, 8.6, -1), "Hips")
    d.bone("Neck1", (0, 9.2, -10.2), "Chest")
    d.bone("Head", (0, 9.4, -13.6), "Neck1")
    d.bone("Jaw", (0, 7.6, -16.0), "Head")
    d.bone_pair("Lid", (-3.4, 11, -17), "Head")
    d.bone_pair("Arm", (-5.6, 7.0, -6.6), "Chest")
    d.bone_pair("Forearm", (-6.2, 4.2, -5.0), "ArmL")
    d.bone_pair("Hand", (-6.0, 1.7, -6.8), "ForearmL")
    d.bone_pair("Thigh", (-5.6, 8.0, 6.0), "Hips")
    d.bone_pair("Shin", (-6.0, 4.6, 4.4), "ThighL")
    d.bone_pair("Foot", (-6.0, 1.8, 6.8), "ShinL")
    tz = [11.4, 14.2, 16.8, 19.2, 21.2, 22.8]
    ty = [9.6, 9.0, 8.4, 7.8, 7.3, 7.0]
    tr = [3.6, 2.9, 2.3, 1.7, 1.2, 0.7]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : dôme bas et large, presque carré
    d.ellipsoid("Chest", (0, 9.6, -3.8), (6.8, 4.8, 7.0), BODY, where=left, power=3.0)
    d.ellipsoid("Hips", (0, 10.2, 5.0), (7.0, 5.4, 6.6), BODY, where=left, power=3.0)
    d.limb("Neck1", (0, 9.4, -9.6), (0, 9.6, -13.2), 3.4, 3.1, BODY, where=left)
    # ---------------------------------------------------------------- tête étroite en poire, petit bec
    d.ellipsoid("Head", (0, 9.8, -16.0), (3.6, 2.9, 3.2), BODY, where=lambda x, y, z: x <= 0 and y >= 8, power=2.8)
    d.ellipsoid("Head", (0, 9.4, -19.4), (2.3, 2.1, 2.2), BODY, where=lambda x, y, z: x <= 0 and y >= 8, power=2.2)
    d.ellipsoid("Head", (0, 8.6, -21.4), (1.3, 1.1, 1.0), BEAK, where=lambda x, y, z: x <= 0 and y >= 8)
    d.ellipsoid("Jaw", (0, 7.0, -17.6), (2.4, 1.1, 3.0), BODY, where=lambda x, y, z: x <= 0 and y <= 7, power=2.6)
    d.ellipsoid("Jaw", (0, 7.0, -20.4), (1.2, 0.9, 0.9), BEAK, where=lambda x, y, z: x <= 0 and y <= 7)
    for z in range(-21, -14):
        if (0, 8, z) in d.vox:
            d.set("Head", 0, 8, z, MOUTH)
        if (0, 7, z) in d.vox:
            d.set("Jaw", 0, 7, z, MOUTH)
    # ---------------------------------------------------------------- pattes courtes et massives
    d.ellipsoid("ThighL", (-5.8, 6.6, 5.8), (2.2, 2.8, 2.8), BODY)
    d.limb("ShinL", (-6.0, 4.6, 4.4), (-6.0, 1.8, 6.8), 2.0, 1.8, BODY)
    d.limb("FootL", (-6.0, 1.8, 6.8), (-6.0, 0.6, 5.8), 1.8, 1.8, BODY)
    d.box("FootL", (-8, 0, 3), (-4, 1, 7), BODY)
    for x in (-8, -6, -4):
        d.set("FootL", x, 0, 2, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-6, 0, 3))
    d.limb("ArmL", (-5.6, 7.0, -6.6), (-6.2, 4.2, -5.0), 2.1, 1.9, BODY)
    d.limb("ForearmL", (-6.2, 4.2, -5.0), (-6.0, 1.7, -6.8), 1.9, 1.7, BODY)
    d.limb("HandL", (-6.0, 1.7, -6.8), (-6.0, 0.6, -7.4), 1.7, 1.7, BODY)
    d.box("HandL", (-8, 0, -9), (-4, 1, -6), BODY)
    for x in (-8, -6):
        d.set("HandL", x, 0, -10, NAIL, "Smooth")
    d.point("FrontToeL", "HandL", (-6, 0, -9))
    # ---------------------------------------------------------------- queue effilée (pas de massue)
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    d.eye("Head", "LidL", 9, -18, IRIS, PUPIL, lid_color=shade(BODY, -0.18), h=2, w=2)

    # ---------------------------------------------------------------- armure du dos (côté gauche, puis symétrie)
    def scute(bone, x0, x1, z0, z1, color, h=1):
        """Bouclier en relief de h voxels posé sur la surface (cases x0..x1, z0..z1), dessus à plat."""
        top = max(d.surface_y(x, z, bone) or -99 for x in range(x0, x1 + 1) for z in range(z0, z1 + 1))
        for x in range(x0, x1 + 1):
            for z in range(z0, z1 + 1):
                y = d.surface_y(x, z, bone)
                if y is not None:
                    for yy in range(y + 1, top + h + 1):
                        d.set(bone, x, yy, z, color)
    # rangées de plaques sombres (milieu du dos) et de bosses claires (bords), en travers du corps
    rows = [(-10, "Chest"), (-6, "Chest"), (-2, "Chest"), (2, "Hips"), (6, "Hips"), (10, "Hips")]
    for z, bone in rows:
        scute(bone, -1, 0, z, z + 1, ARMOR, h=2)      # plaque bombée : arête au milieu, bords plus bas
        scute(bone, -3, -2, z, z + 1, ARMOR, h=1)
        scute(bone, -6, -5, z, z + 1, KNOB)
    scute("Neck1", -2, 0, -12, -11, ARMOR, h=2)
    for z, bone, w in ((13, "Tail1", 2), (16, "Tail2", 1), (19, "Tail3", 1)):
        scute(bone, -w, 0, z, z + 1, ARMOR)

    # ---------------------------------------------------------------- pointes (os blanc)
    def stud(bone, y, z, n=2):
        """Petite pointe en blocs étagés qui sort du flanc vers l'extérieur (-X) : 2x2 puis 1x1."""
        x0 = d.surface_x(y, z, bone)
        if x0 is None:
            return
        for k in range(1, n + 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    d.set(bone, x0 - k, y + dy, z + dz, SPIKE, "Smooth")
        for k in range(n + 1, n + 3):
            d.set(bone, x0 - k, y, z, SPIKE, "Smooth")
    # grande pointe d'épaule vers l'avant et un peu vers le haut, et sa fourche vers l'extérieur
    d.limb("Chest", (-6.0, 11.6, -7.6), (-9.8, 15.8, -16.8), 1.6, 0.4, SPIKE, "Smooth")
    d.limb("Chest", (-6.6, 10.4, -5.6), (-11.4, 11.0, -9.4), 1.15, 0.3, SPIKE, "Smooth")
    # pointes des flancs et de la queue, de plus en plus petites
    stud("Chest", 10, -2, 2)
    stud("Hips", 10, 4, 2)
    stud("Hips", 10, 9, 1)
    stud("Tail1", 9, 14, 1)
    for bone, y, z in (("Tail2", 9, 17), ("Tail3", 8, 20)):
        x0 = d.surface_x(y, z, bone)
        if x0 is not None:
            d.box(bone, (x0 - 2, y, z), (x0 - 1, y, z), SPIKE, "Smooth")
    d.limb("Neck1", (-3.0, 10.6, -11.2), (-5.2, 11.6, -10.8), 0.8, 0.3, SPIKE, "Smooth")

    # ---------------------------------------------------------------- symétrie et peinture
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 6, "Chest": 6, "Neck1": 7, "Tail1": 7, "Tail2": 7, "Tail3": 7, "Head": 7}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    return d
