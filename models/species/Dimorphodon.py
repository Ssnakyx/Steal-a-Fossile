"""Dimorphodon : petit ptérosaure de la Beach, vif, à grosse tête de macareux.

Modélisé ailes déployées (membranes en plaques horizontales : peu de pièces), voxels de 0,14 stud : environ 8 studs
d'envergure et 6,5 de long (queue comprise) à la taille Normal. Énorme tête au bec haut et étroit à bandes jaunes et
rouges, joues claires autour de l'oeil comme un macareux, ailes courtes et larges, pattes rouge-orangé, longue queue
fine en cinq segments terminée par une palette en losange rouge (verticale). Corps ardoise foncé, ventre clair.
Au parc il se tient replié sur ses pattes et ses mains (les animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.14

BODY = (66, 76, 96)
BELLY = (232, 230, 220)
FACE = (238, 238, 232)
WING = (98, 120, 150)
WING_DARK = (66, 82, 108)
BONE = (54, 62, 80)
YELLOW = (255, 204, 54)
RED = (230, 66, 50)
FEET = (238, 102, 52)
CLAW = (40, 40, 46)
PUPIL = (26, 22, 20)
IRIS = (255, 132, 64)
MOUTH = (200, 96, 96)

PERSONALITY = {
    "tempo": 1.3,           # vif
    "weight": 0.6,
    "stride": 1.0,
    "bob": 1.0,
    "headBob": 0.8,
    "tail": 0.9,            # longue queue qui fouette
    "diet": "fish",         # Eat : happe un poisson et l'avale tête levée
    "happy": "flap",        # Happy : petits bonds en battant des ailes
    "catch": "peck",        # Catch : coup de bec plongé (bec fermé à l'impact)
}


def build():
    d = Dino("Dimorphodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9, 3))
    d.bone("Chest", (0, 9.6, 0), "Hips")
    d.bone("Neck1", (0, 11.4, -3.0), "Chest")
    d.bone("Head", (0, 13.4, -4.8), "Neck1")
    d.bone("Jaw", (0, 12.6, -8.0), "Head")
    d.bone_pair("Lid", (-2.6, 17, -8.5), "Head")
    d.bone_pair("Wing1", (-2.4, 10, -1.2), "Chest")
    d.bone_pair("Wing2", (-6.4, 10, -1.2), "Wing1L")
    d.bone_pair("Wing3", (-12.6, 10, -1.8), "Wing2L")
    d.bone_pair("Thigh", (-1.6, 8.6, 3.6), "Hips")
    d.bone_pair("Shin", (-1.9, 5.6, 2.2), "ThighL")
    d.bone_pair("Foot", (-1.9, 2.4, 4.0), "ShinL")
    tz = [5.6, 9.4, 13.2, 17.0, 20.8, 24.2]
    ty = [9.6, 10.1, 10.6, 11.1, 11.6, 12.0]
    tr = [1.8, 1.45, 1.2, 1.05, 1.0, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps
    d.ellipsoid("Hips", (0, 9.4, 2.8), (2.5, 2.6, 3.0), BODY, where=left)
    d.ellipsoid("Chest", (0, 9.8, -0.6), (2.8, 2.9, 3.2), BODY, where=left)
    d.limb("Neck1", (0, 11.0, -2.6), (0, 13.4, -4.8), 2.0, 1.8, BODY, where=left)
    # ---------------------------------------------------------------- énorme tête de macareux
    d.ellipsoid("Head", (0, 15.2, -7.4), (2.7, 3.3, 3.2), BODY, where=lambda x, y, z: x <= 0 and y >= 13, power=2.3)
    # bec haut et étroit (3 voxels de large), sculpté colonne par colonne, à bandes jaunes et rouges
    upper = {-10: (13, 18), -11: (13, 18), -12: (13, 17), -13: (13, 17), -14: (13, 16), -15: (13, 15), -16: (12, 14)}
    lower = {-10: (9, 12), -11: (9, 12), -12: (9, 12), -13: (10, 12), -14: (11, 12), -15: (12, 12)}
    band = {-10: YELLOW, -11: YELLOW, -12: RED, -13: RED, -14: YELLOW, -15: RED, -16: RED}
    for x in (0, -1):
        for z, (y0, y1) in upper.items():
            if x == -1 and z == -16:
                continue
            d.box("Head", (x, y0, z), (x, y1, z), band[z])
        for z, (y0, y1) in lower.items():
            if x == -1 and z == -15:
                continue
            d.box("Jaw", (x, y0, z), (x, y1, z), band[z])
    d.ellipsoid("Jaw", (0, 11.0, -7.6), (2.0, 1.8, 2.4), BODY, where=lambda x, y, z: x <= 0 and y <= 12)
    for z in range(-15, -6):
        if (0, 13, z) in d.vox:
            d.set("Head", 0, 13, z, MOUTH)
        if (0, 12, z) in d.vox:
            d.set("Jaw", 0, 12, z, MOUTH)
    # ---------------------------------------------------------------- ailes (gauche) : courtes et larges
    edge = [(-2.0, -0.6), (-6.4, -0.6), (-12.6, -1.2), (-28.4, 1.6), (-23, 4.2), (-17, 6.4), (-10, 7.8), (-5, 7.6),
            (-2.0, 6.4)]
    d.plate("Wing1L", 1, 10, edge, WING)
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Wing1L" and col == WING:
            if x <= -13:
                d.set("Wing3L", x, y, z, WING)
            elif x <= -7:
                d.set("Wing2L", x, y, z, WING)
    # bord de fuite plus foncé et deux nervures
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if col == WING and bone.startswith("Wing"):
            if (x, y, z + 1) not in d.vox:
                d.set(bone, x, y, z, WING_DARK)
            elif x in (-10, -19) and z > 0:
                d.set(bone, x, y, z, WING_DARK)
    # os de l'aile : bras, avant-bras, doigt-aile (bord d'attaque)
    d.limb("Wing1L", (-2.4, 10, -1.2), (-6.4, 10, -1.2), 1.05, 0.85, BONE)
    d.limb("Wing2L", (-6.4, 10, -1.2), (-12.6, 10, -1.8), 0.8, 0.6, BONE)
    d.limb("Wing3L", (-12.6, 10, -1.8), (-28.4, 10, 1.4), 0.55, 0.3, BONE)
    # griffes de la main (au poignet, vers l'avant) : elles touchent le sol quand il marche
    d.box("Wing2L", (-13, 9, -3), (-12, 9, -3), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-12.6, 9, -2.8))
    d.point("WingTipL", "Wing3L", (-28.4, 10, 1.4))
    # ---------------------------------------------------------------- pattes arrière (rouge-orangé, comme un macareux)
    d.limb("ThighL", (-1.6, 8.6, 3.6), (-1.9, 5.6, 2.2), 1.2, 0.9, BODY)
    d.limb("ShinL", (-1.9, 5.6, 2.2), (-1.9, 2.4, 4.0), 0.85, 0.7, FEET)
    d.limb("FootL", (-1.9, 2.4, 4.0), (-1.9, 0.6, 2.4), 0.7, 0.7, FEET)
    d.box("FootL", (-3, 0, 0), (-1, 0, 2), FEET)
    for x in (-3, -1):
        d.set("FootL", x, 0, -1, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-2, 0, 0.5))
    # ---------------------------------------------------------------- longue queue fine + palette en losange
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    cy, cz, r = 12, 27, 3
    for dz in range(-r, r + 1):
        for dy in range(-(r - abs(dz)), r - abs(dz) + 1):
            d.set("Tail5", 0, cy + dy, cz + dz, RED)
    for dz in range(-r, 1):                         # nervure : la queue traverse la palette
        d.set("Tail5", 0, cy, cz + dz, BODY)
    # ---------------------------------------------------------------- yeux, symétrie, peinture
    d.eye("Head", "LidL", 15, -9, IRIS, PUPIL, lid_color=BODY, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ventre clair coupé à plat ; joues claires de macareux autour de l'oeil, calotte sombre
    belly = {"Hips": 8, "Chest": 8, "Neck1": 11, "Tail1": 9}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.paint(lambda x, y, z, bone, c: FACE if c == BODY and bone in ("Head", "Jaw") and y <= 16 and z <= -5 else None)
    return d
