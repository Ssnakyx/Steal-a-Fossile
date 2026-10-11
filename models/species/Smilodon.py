"""Smilodon : tigre à dents de sabre de l'ère glaciaire (fossile du Glacier), trapu et puissant.

Voxels de 0,24 stud : environ 10 studs de long et 5,5 de haut à la taille Normal (épaules à hauteur de l'avatar).
Grosse tête ronde au museau court, deux longs sabres blancs qui descendent bien sous le menton (ils restent en place
quand la gueule s'ouvre en grand), épaules et pattes avant énormes, dos qui descend vers le bassin, queue courte en
quatre petits segments. Fauve à taches pâles, museau, gorge et ventre blancs, oreilles et bout de queue foncés."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, hash3  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.24

BODY = (212, 148, 76)
DARK = (120, 78, 46)
SPOT = (244, 216, 162)
WHITE = (248, 244, 234)
SABER = (252, 250, 240)
NOSE = (120, 70, 66)
EAR_IN = (236, 176, 150)
PUPIL = (24, 20, 18)
IRIS = (236, 200, 60)
MOUTH = (176, 64, 72)
TONGUE = (220, 116, 120)

PERSONALITY = {
    "tempo": 1.1,           # félin : souple et rapide
    "weight": 1.1,
    "stride": 1.1,
    "bob": 0.9,
    "headBob": 0.0,
    "tail": 0.8,
    "diet": "meat",
    "happy": "stomp",       # se cabre et tape des pattes avant
    "catch": "ram",         # charge tête basse puis relève la tête
    "sleepDrop": 0.42,      # couché un peu moins bas : les sabres ne s'enfoncent pas dans le sol
}


def build():
    d = Dino("Smilodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 12, 5))
    d.bone("Chest", (0, 12.8, 0), "Hips")
    d.bone("Neck1", (0, 15.2, -9.2), "Chest")
    d.bone("Head", (0, 16.4, -11.8), "Neck1")
    d.bone("Jaw", (0, 14.4, -13.8), "Head")
    d.bone_pair("Lid", (-3.2, 19, -16.5), "Head")
    d.bone_pair("Arm", (-4.6, 12.0, -6.0), "Chest")
    d.bone_pair("Forearm", (-4.6, 7.0, -3.4), "ArmL")
    d.bone_pair("Hand", (-4.6, 2.2, -5.8), "ForearmL")
    d.bone_pair("Thigh", (-3.8, 12.0, 6.0), "Hips")
    d.bone_pair("Shin", (-4.0, 7.2, 3.6), "ThighL")
    d.bone_pair("Foot", (-4.0, 3.6, 7.0), "ShinL")
    tz = [10.4, 12.8, 15.0, 17.0, 18.8]
    ty = [15.2, 14.2, 13.0, 11.8, 10.6]
    tr = [1.8, 1.55, 1.35, 1.15, 0.95]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps : épaules massives, dos qui descend
    d.ellipsoid("Chest", (0, 13.6, -4.4), (5.3, 5.8, 5.8), BODY, where=left, power=2.6)
    d.ellipsoid("Hips", (0, 12.6, 5.4), (4.3, 4.6, 5.0), BODY, where=left, power=2.6)
    d.limb("Neck1", (0, 14.6, -8.4), (0, 16.4, -11.6), 3.9, 3.6, BODY, where=left)
    # ---------------------------------------------------------------- grosse tête ronde, museau court
    d.ellipsoid("Head", (0, 18.4, -14.0), (4.3, 3.9, 3.8), BODY, where=left, power=2.5)
    d.box("Head", (-3, 16, -17), (0, 20, -15), BODY)            # joues plates : grand oeil bien posé
    d.ellipsoid("Head", (0, 16.0, -16.6), (3.5, 2.2, 2.4), WHITE, where=lambda x, y, z: x <= 0 and 15 <= y <= 16,
                power=2.6)
    d.ellipsoid("Head", (0, 16.0, -18.4), (2.7, 2.0, 2.3), WHITE, where=lambda x, y, z: x <= 0 and y >= 15,
                power=2.6)
    d.ellipsoid("Head", (0, 18.0, -18.0), (1.7, 1.3, 2.6), BODY, where=lambda x, y, z: x <= 0 and y >= 17,
                power=2.4)                                       # arête du nez
    d.ellipsoid("Jaw", (0, 13.8, -16.6), (1.8, 1.1, 2.8), BODY, where=lambda x, y, z: x <= 0 and y <= 14, power=2.6)
    d.box("Jaw", (-1, 14, -14), (0, 14, -13), BODY)
    # palais et langue (vus gueule ouverte)
    d.box("Head", (0, 15, -19), (0, 15, -14), MOUTH)
    d.box("Jaw", (0, 14, -18), (0, 14, -14), TONGUE)
    # petit nez triangulaire au bout du museau
    zf = min(z for (x, y, z) in d.vox if x == 0 and y == 17)
    d.box("Head", (-1, 17, zf), (0, 17, zf), NOSE)
    d.set("Head", 0, 16, zf, NOSE)
    # oreilles arrondies, écartées : dedans rose, dos foncé
    for z, col in ((-14, EAR_IN), (-13, DARK)):
        d.box("Head", (-4, 22, z), (-2, 22, z), col)
        d.box("Head", (-3, 23, z), (-2, 23, z), col)
    # sabres : deux longues lames plates (1 voxel d'épaisseur, 2 de large), un peu recourbées vers l'arrière
    for y in range(8, 16):
        k = (15 - y) / 7.0
        z0 = zf + 2 + round(1.2 * k * k)
        d.set("Head", -2, y, z0, SABER, "Smooth")
        if y >= 10:
            d.set("Head", -2, y, z0 + 1, SABER, "Smooth")
    # ---------------------------------------------------------------- pattes avant énormes
    d.limb("ArmL", (-4.6, 12.0, -6.0), (-4.6, 7.0, -3.4), 2.8, 2.3, BODY)
    d.limb("ForearmL", (-4.6, 7.0, -3.4), (-4.6, 2.2, -5.8), 2.2, 1.9, BODY)
    d.limb("HandL", (-4.6, 2.2, -5.8), (-4.6, 0.8, -6.4), 1.9, 1.9, BODY)
    d.ellipsoid("HandL", (-4.6, 1.0, -7.4), (2.4, 1.4, 2.6), BODY, power=2.6)
    for x in (-6, -5, -4, -3):
        d.set("HandL", x, 0, -10, SPOT)
    d.point("FrontToeL", "HandL", (-4.6, 0, -9))
    # ---------------------------------------------------------------- pattes arrière
    d.ellipsoid("ThighL", (-4.2, 10.0, 5.6), (2.4, 3.8, 3.5), BODY)
    d.limb("ShinL", (-4.0, 7.2, 3.6), (-4.0, 3.6, 7.0), 1.8, 1.5, BODY)
    d.limb("FootL", (-4.0, 3.6, 7.0), (-4.0, 0.8, 4.8), 1.5, 1.5, BODY)
    d.ellipsoid("FootL", (-4.0, 1.0, 3.8), (2.0, 1.2, 2.2), BODY, power=2.6)
    for x in (-5, -4, -3):
        d.set("FootL", x, 0, 1, SPOT)
    d.point("ToeL", "FootL", (-4, 0, 2.5))
    # ---------------------------------------------------------------- queue courte
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- yeux (pupille fendue au centre), symétrie
    d.eye("Head", "LidL", 17, -17, IRIS, IRIS, h=2, w=3)
    for dy in (0, 1):
        d.set("Head", d.surface_x(17 + dy, -16), 17 + dy, -16, PUPIL, "Smooth")
        # arcade devant la paupière : yeux fermés, elle couvre aussi l'oeil vu de face
        d.set("LidL", d.surface_x(17 + dy, -17), 19 + dy, -18, BODY)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture
    # ventre blanc coupé à plat (gorge et menton fauves : les sabres blancs ressortent devant)
    belly = {"Chest": 9, "Hips": 9, "Tail1": 13}
    d.paint(lambda x, y, z, bone, c: WHITE if c == BODY and bone in belly and y <= belly[bone] and
            (bone != "Chest" or z >= -5) else None)

    # taches pâles en quinconce (vues de côté sur les flancs, vues de dessus sur le dos)
    spotted = ("Chest", "Hips", "Neck1", "ThighL", "ThighR", "ArmL", "ArmR")

    def spots(x, y, z, bone, c):
        if bone not in spotted or c != BODY:
            return None
        top = (x, y + 1, z) not in d.vox
        a, b = (abs(x), z) if top and y >= 17 else (y, z)
        cy, cz = a // 2, b // 2
        if cy % 2 == 0 and (cz + cy // 2) % 2 == 0 and hash3(cy, cz, int(top), 5) < 0.75:
            return SPOT
        return None
    d.paint(spots)
    # bout de queue foncé
    d.paint(lambda x, y, z, bone, c: DARK if bone == "Tail4" and c in (BODY, SPOT) else None)
    return d
