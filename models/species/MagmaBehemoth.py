"""Magma Behemoth : quadrupède légendaire du Volcano, colosse de basalte, très lourd et très lent.

Voxels de 0,6 stud : environ 22 studs de long et 13 de haut (volcan compris) à la taille Normal. Bosse d'épaules
massive en plaques de roche sombre séparées par des fissures de lave (Neon), petit volcan à gradins sur le dos avec un
cratère de lave d'où débordent quatre coulées qui descendent les flancs, grosse tête basse à bouclier de roche, gueule
de lave, naseaux et yeux brûlants, deux grosses cornes recourbées vers l'avant à pointe incandescente, pattes
d'éléphant en piliers aux orteils rougeoyants, courte queue à massue de roche fendue sur un coeur de lave."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.6

BASALT = (52, 48, 54)
ROCK = (100, 92, 94)
HORN = (150, 138, 128)
LAVA = (255, 112, 26)
GLOW = (255, 196, 44)
TOOTH = (226, 214, 196)

PERSONALITY = {
    "tempo": 0.65,          # colosse : pas très lents qui font trembler le sol
    "weight": 1.6,
    "stride": 0.85,
    "bob": 0.8,
    "headBob": 0.0,
    "tail": 0.8,            # la massue balance lourdement
    "diet": "plants",       # broute les roches tièdes
    "happy": "stomp",
    "catch": "ram",         # charge tête basse, cornes en avant
    "sleepDrop": 0.37,
}

ROCK_BONES = ("Chest", "Hips", "Neck1", "Tail1", "Tail2")
VZ = -1                     # axe du volcan (z), sur la bosse
# fissures du flanc gauche : lignes brisées (y, z) qui délimitent les plaques (segments droits : peu de pièces)
FLANK_CRACKS = [
    [(17, VZ), (11, VZ), (11, -4), (10, -4), (10, -9)],      # coulée du volcan puis ceinture vers l'épaule
    [(11, VZ), (11, 2), (10, 2), (10, 10)],                   # ceinture vers la hanche
    [(16, -6), (13, -6), (13, -7), (10, -7)],                 # plaque de l'épaule
    [(14, 5), (12, 5), (12, 6), (10, 6)],                     # plaque de la hanche
    [(10, 1), (7, 1)],                                        # plaques du bas, décalées
]
# fissures du dos : lignes (x, z) vues de dessus, côté gauche (le long de l'échine, devant et derrière le volcan)
BACK_CRACKS = [
    [(0, -6), (0, -10)],
    [(0, 4), (0, 10)],
]


def build():
    d = Dino("MagmaBehemoth", FAMILY, voxel=VOXEL, display="Magma Behemoth")
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 11.0, 4.0))
    d.bone("Chest", (0, 11.5, -0.5), "Hips")
    d.bone("Neck1", (0, 11.5, -8.5), "Chest")
    d.bone("Head", (0, 11.5, -11.0), "Neck1")
    d.bone("Jaw", (0, 9.5, -12.0), "Head")
    d.bone_pair("Lid", (-3.4, 13, -16), "Head")
    d.bone_pair("Arm", (-5.0, 10.0, -4.5), "Chest")
    d.bone_pair("Forearm", (-5.0, 6.0, -1.0), "ArmL")
    d.bone_pair("Hand", (-5.0, 1.0, -2.5), "ForearmL")
    d.bone_pair("Thigh", (-5.0, 10.5, 6.0), "Hips")
    d.bone_pair("Shin", (-5.0, 6.0, 3.0), "ThighL")
    d.bone_pair("Foot", (-5.0, 1.0, 6.5), "ShinL")
    tz = [9.5, 12.0, 14.0, 15.5]
    ty = [11.5, 11.0, 10.5, 10.0]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- bosse d'épaules massive, bassin plus bas
    d.ellipsoid("Chest", (0, 11.5, -3.5), (6.3, 5.8, 5.5), BASALT, where=lambda x, y, z: x <= 0 and z <= 0, power=2.6)
    d.ellipsoid("Hips", (0, 11.0, 5.0), (5.8, 4.8, 5.0), BASALT, where=lambda x, y, z: x <= 0 and z >= 1, power=2.6)
    d.limb("Neck1", (0, 12.0, -8.0), (0, 12.0, -11.0), 3.6, 3.6, BASALT, where=lambda x, y, z: x <= 0 and z <= -9)
    # ---------------------------------------------------------------- grosse tête basse à bouclier de roche
    upper = lambda x, y, z: x <= 0 and y >= 10  # noqa: E731
    d.ellipsoid("Head", (0, 12.0, -14.0), (3.7, 2.8, 3.2), BASALT, where=upper, power=3.0)
    d.ellipsoid("Head", (0, 11.0, -17.0), (3.0, 2.0, 1.8), BASALT, where=upper, power=2.6)
    d.ellipsoid("Jaw", (0, 9.0, -15.0), (3.1, 1.5, 3.2), BASALT, where=lambda x, y, z: x <= 0 and y <= 9, power=2.8)
    d.box("Jaw", (-2, 9, -12), (0, 9, -11), BASALT)
    # bouclier : le dessus du crâne et du museau en roche claire
    d.paint(lambda x, y, z, bone, c: ROCK if bone == "Head" and y >= 13 else None)
    # lèvres de lave : la rangée du bas de la tête et le dessus de la mâchoire
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if z <= -12 and ((bone == "Head" and y == 10) or (bone == "Jaw" and y == 9)):
            d.set(bone, x, y, z, LAVA, "Neon")
    for z in (-18, -16, -14):
        x = d.surface_x(10, z, "Head")
        if x is not None:
            d.set("Head", x, 10, z, TOOTH, "Smooth")
    # naseaux brûlants
    zs = [k[2] for k, v in d.vox.items() if k[0] == -1 and k[1] == 12 and v[0] == "Head"]
    d.set("Head", -1, 12, min(zs), LAVA, "Neon")
    # ---------------------------------------------------------------- grosses cornes recourbées vers l'avant
    d.limb("Head", (-3.0, 13.5, -13.0), (-5.6, 15.0, -12.6), 1.5, 1.25, HORN)
    d.limb("Head", (-5.6, 15.0, -12.6), (-7.0, 17.4, -13.8), 1.25, 1.0, HORN)
    d.limb("Head", (-7.0, 17.4, -13.8), (-6.8, 18.8, -16.2), 1.0, 0.75, HORN)
    d.limb("Head", (-6.8, 18.8, -16.2), (-6.0, 19.0, -18.0), 0.75, 0.4, LAVA, "Neon")
    # ---------------------------------------------------------------- pattes d'éléphant en piliers, orteils rougeoyants
    d.ellipsoid("ArmL", (-5.0, 8.0, -3.5), (2.5, 3.0, 2.5), BASALT, power=3.0)
    d.ellipsoid("ForearmL", (-5.0, 4.0, -3.5), (2.3, 2.2, 2.3), BASALT, power=3.0)
    d.ellipsoid("HandL", (-5.0, 0.5, -4.0), (2.5, 1.5, 2.5), BASALT, power=3.0)
    for x in (-7, -5, -3):
        d.set("HandL", x, 0, -7, LAVA, "Neon")
    d.point("FrontToeL", "HandL", (-5.0, 0, -6.5))
    d.ellipsoid("ThighL", (-5.0, 8.5, 5.0), (2.6, 3.0, 2.8), BASALT, power=3.0)
    d.ellipsoid("ShinL", (-5.0, 4.0, 5.0), (2.3, 2.2, 2.3), BASALT, power=3.0)
    d.ellipsoid("FootL", (-5.0, 0.5, 4.5), (2.5, 1.5, 2.5), BASALT, power=3.0)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, LAVA, "Neon")
    d.point("ToeL", "FootL", (-5.0, 0, 2.0))
    # ---------------------------------------------------------------- courte queue et massue (roche fendue sur la lave)
    d.limb("Tail1", (0, 11.0, 9.5), (0, 11.0, 12.0), 3.0, 2.6, BASALT, where=lambda x, y, z: x <= 0 and z >= 10)
    d.limb("Tail2", (0, 11.0, 12.0), (0, 10.0, 14.0), 2.6, 2.0, BASALT, where=left)
    d.limb("Tail3", (0, 10.0, 14.0), (0, 10.0, 15.5), 2.0, 1.6, BASALT, where=left)
    d.ellipsoid("Tail4", (0, 10.0, 16.0), (2.5, 2.2, 2.2), ROCK, where=left, power=2.6)
    # ---------------------------------------------------------------- yeux, fissures (côté gauche), symétrie
    d.eye("Head", "LidL", 12, -16, GLOW, GLOW, lid_color=ROCK, h=1, w=2)

    def lava(x, y, z):
        v = d.vox.get((x, y, z))
        if v is not None and v[0] in ROCK_BONES and v[1] == BASALT:
            d.set(v[0], x, y, z, LAVA, "Neon")

    def walk(path):
        for (a0, b0), (a1, b1) in zip(path, path[1:]):
            n = max(abs(a1 - a0), abs(b1 - b0))
            for i in range(n + 1):
                yield round(a0 + (a1 - a0) * i / n), round(b0 + (b1 - b0) * i / n)

    for path in FLANK_CRACKS:
        for y, z in walk(path):
            x = d.surface_x(y, z)
            if x is not None:
                lava(x, y, z)
    for path in BACK_CRACKS:
        for x, z in walk(path):
            y = d.surface_y(x, z)
            if y is not None:
                lava(x, y, z)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # massue : croix de lave entre quatre blocs de roche ; yeux et coeur incandescents
    d.paint(lambda x, y, z, bone, c: (GLOW, "Neon") if bone == "Tail4" and c == ROCK and (x == 0 or y == 10) else None)
    d.paint(lambda x, y, z, bone, c: (c, "Neon") if c == GLOW else None)
    # ---------------------------------------------------------------- petit volcan sur la bosse, large cratère de lave
    layers = {16: 5.4, 17: 5.0, 18: 4.3, 19: 3.7, 20: 3.4}
    for y, r in layers.items():
        for x in range(-6, 7):
            for z in range(VZ - 6, VZ + 7):
                dd = (abs(x) ** 2.4 + abs(z - VZ) ** 2.4) ** (1 / 2.4)
                if dd > r:
                    continue
                if y == 20 and abs(x) <= 1 and abs(z - VZ) <= 1:
                    d.set("Chest", x, y, z, GLOW, "Neon")            # lave qui monte dans le cratère
                else:
                    d.set("Chest", x, y, z, ROCK)
    d.set("Chest", 0, 21, VZ, GLOW, "Neon")                          # bulle de lave au-dessus du bord
    # quatre coulées de lave qui débordent du cratère et descendent les pentes
    flows = [k for k, (bone, col, mat) in d.vox.items() if bone == "Chest" and col == ROCK and k[1] >= 16
             and d.visible(k) and ((k[2] == VZ and abs(k[0]) >= 2) or (k[0] == 0 and abs(k[2] - VZ) >= 2))]
    for x, y, z in flows:
        d.set("Chest", x, y, z, LAVA, "Neon")
    return d
