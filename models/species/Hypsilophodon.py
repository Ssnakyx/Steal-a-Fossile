"""Hypsilophodon : petit ornithopode coureur de la Fern Forest, vif comme une gazelle.

Voxels de 0,143 stud : environ 6 studs de long et 3,4 de haut à la taille Normal (le dos arrive à la taille de
l'avatar). Tête ronde aux grands yeux, bec corné sans dents, cou court, longues pattes de coureur, longue queue raide.
Vert feuille, deux bandes crème sur chaque flanc, ventre clair."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.143

BODY = (104, 178, 66)
DARK = (60, 122, 52)
LID = (80, 148, 58)
STRIPE = (250, 240, 200)
BELLY = (214, 230, 150)
BEAK = (178, 150, 94)
BEAK_DARK = (128, 104, 70)
CLAW = (246, 240, 226)
PUPIL = (24, 20, 18)
IRIS = (255, 186, 48)
SHINE = (255, 255, 255)
MOUTH = (178, 70, 70)

# personnalité : lue par la famille d'animation (models/lib/fam_biped.py)
PERSONALITY = {
    "tempo": 1.4,           # très vif : tout va vite
    "weight": 0.65,         # léger : gros rebonds
    "stride": 1.2,          # grandes foulées de coureur
    "bob": 1.15,
    "headBob": 1.1,         # petits coups de tête d'oiseau
    "tail": 0.8,            # queue raide (tendons ossifiés) : fouette peu
    "diet": "plants",       # Eat : broute au ras du sol
    "happy": "hop",         # Happy : saut avec un tour complet
    "catch": "headbutt",
}

# axe du corps (z -> y) : sert à poser les bandes des flancs
TZ = [7.4, 11.2, 15.0, 18.6, 22.0, 25.4]
TY = [13.8, 14.2, 14.5, 14.7, 14.8, 14.9]
TR = [3.2, 2.6, 2.0, 1.5, 1.0, 0.6]
AXIS = [(-9.0, 19.4), (-7.0, 17.2), (-5.2, 14.8), (-2.0, 13.0), (3.0, 13.6)] + list(zip(TZ, TY))


def axis_y(z):
    if z <= AXIS[0][0]:
        return AXIS[0][1]
    for (za, ya), (zb, yb) in zip(AXIS, AXIS[1:]):
        if za <= z <= zb:
            return ya + (yb - ya) * (z - za) / (zb - za)
    return AXIS[-1][1]


def build():
    d = Dino("Hypsilophodon", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (pivots en voxels)
    d.bone("Hips", (0, 13.2, 2))
    d.bone("Chest", (0, 13.0, -1.0), "Hips")
    d.bone("Neck1", (0, 14.8, -5.2), "Chest")
    d.bone("Neck2", (0, 17.2, -7.0), "Neck1")
    d.bone("Head", (0, 19.0, -8.4), "Neck2")
    d.bone("Jaw", (0, 18.4, -11.0), "Head")
    d.bone_pair("Lid", (-2.8, 22.5, -11), "Head")
    d.bone_pair("Arm", (-3.0, 12.2, -4.6), "Chest")
    d.bone_pair("Forearm", (-3.4, 10.2, -5.2), "ArmL")
    d.bone_pair("Thigh", (-3.4, 13.0, 2.2), "Hips")
    d.bone_pair("Shin", (-3.6, 8.2, -0.6), "ThighL")
    d.bone_pair("Foot", (-3.6, 3.6, 2.4), "ShinL")
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, TY[i], TZ[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    # ---------------------------------------------------------------- corps compact et dodu
    d.ellipsoid("Hips", (0, 13.6, 3.0), (3.6, 3.6, 4.4), BODY, where=left, power=2.5)
    d.ellipsoid("Chest", (0, 13.0, -2.0), (3.5, 3.7, 3.8), BODY, where=left, power=2.5)
    d.limb("Neck1", (0, 14.6, -4.8), (0, 17.2, -7.0), 2.5, 2.2, BODY, where=left)
    d.limb("Neck2", (0, 17.2, -7.0), (0, 19.0, -8.4), 2.2, 2.1, BODY, where=left)
    # ---------------------------------------------------------------- tête ronde, grands yeux, petit bec corné
    d.ellipsoid("Head", (0, 20.6, -10.6), (3.0, 3.0, 3.0), BODY, where=left, power=2.2)
    d.ellipsoid("Head", (0, 19.9, -13.4), (2.0, 1.8, 2.0), BODY, where=lambda x, y, z: x <= 0 and y >= 19, power=2.3)
    # bec corné : pointe étroite au bout du museau (haut) et de la mâchoire (bas)
    d.limb("Head", (0, 19.8, -14.6), (0, 19.4, -15.9), 1.3, 0.7, BEAK, where=lambda x, y, z: x <= 0 and y >= 19)
    d.ellipsoid("Jaw", (0, 18.2, -12.8), (1.7, 1.0, 2.4), BELLY, where=lambda x, y, z: x <= 0 and y <= 18, power=2.4)
    d.limb("Jaw", (0, 18.2, -14.2), (0, 18.2, -15.2), 0.9, 0.6, BEAK, where=lambda x, y, z: x <= 0 and y <= 18)
    d.box("Jaw", (-1, 18, -11), (0, 18, -9), BODY)
    d.box("Head", (0, 19, -14), (0, 19, -11), MOUTH)
    # ---------------------------------------------------------------- petits bras à quatre doigts
    d.limb("ArmL", (-3.0, 12.2, -4.6), (-3.4, 10.2, -5.2), 1.1, 1.0, BODY)
    d.limb("ForearmL", (-3.4, 10.2, -5.2), (-3.4, 9.0, -7.0), 0.9, 0.8, BODY)
    d.set("ForearmL", -4, 8, -7, CLAW, "Smooth")
    d.set("ForearmL", -3, 8, -8, CLAW, "Smooth")
    # ---------------------------------------------------------------- longues pattes de coureur
    d.ellipsoid("ThighL", (-3.6, 10.8, 1.2), (2.2, 3.2, 2.8), BODY)
    d.limb("ShinL", (-3.6, 8.2, -0.6), (-3.6, 3.6, 2.4), 1.4, 1.0, BODY)
    d.limb("FootL", (-3.6, 3.6, 2.4), (-3.6, 0.8, 0.4), 1.0, 0.9, BODY)
    d.box("FootL", (-5, 0, -2), (-2, 0, 1), BODY)
    d.box("FootL", (-4, 1, -1), (-3, 1, 1), BODY)
    for x in (-5, -2):
        d.set("FootL", x, 0, -3, CLAW, "Smooth")
    d.set("FootL", -4, 0, -3, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-3.5, 0, -2.5))
    # ---------------------------------------------------------------- longue queue raide en 5 segments
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, TY[i], TZ[i]), (0, TY[i + 1], TZ[i + 1]), TR[i], TR[i + 1], BODY, where=left)

    # ---------------------------------------------------------------- grands yeux (3 x 3) avec reflet
    d.eye("Head", "LidL", 19, -12, IRIS, PUPIL, lid_color=LID, h=3, w=3, pupil_rows=[])
    for dy, dz, col in ((0, 0, PUPIL), (1, 0, PUPIL), (0, 1, PUPIL), (1, 1, SHINE)):
        x = d.surface_x(19 + dy, -12 + dz, "Head")
        if x is not None:
            d.set("Head", x, 19 + dy, -12 + dz, col, "Smooth")
    d.remove(lambda x, y, z: y < 0)
    d.mirror()

    # ---------------------------------------------------------------- peinture
    # ventre clair coupé à plat sous l'axe, dos plus foncé au-dessus, deux bandes crème sur les flancs
    trunk = ("Hips", "Chest", "Neck1", "Neck2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5")

    def paint(x, y, z, bone, c):
        if c != BODY or bone not in trunk:
            return None
        a = axis_y(z)
        side = x != 0 and (x + (1 if x > 0 else -1), y, z) not in d.vox
        if y <= a - 3.2 and bone not in ("Tail3", "Tail4", "Tail5"):
            return BELLY
        if side and round(a + 0.9) == y and z <= 19:
            return STRIPE
        if side and round(a - 1.6) == y and -7 <= z <= 10:
            return STRIPE
        if y >= a + 2.2 or (y >= a + 1.6 and bone in ("Tail3", "Tail4", "Tail5")):
            return DARK
        return None
    d.paint(paint)
    # la bande du haut part de l'oeil : trait crème derrière l'oeil, sur la tête
    for z in (-9, -8):
        for sx in (-1, 1):
            x = d.surface_x(20, z, "Head") if sx < 0 else -d.surface_x(20, z, "Head")
            if x is not None and (x, 20, z) in d.vox:
                d.set("Head", x, 20, z, STRIPE)
    return d
