"""Amargasaurus : quadrupède du Canyon, petit sauropode au cou hérissé.

Voxels de 0,39 stud : environ 20 studs de long et 12 de haut (épines comprises) à la taille Normal. Corps trapu en
tonneau, bassin plus haut que les épaules, cou relevé en trois segments épais portant une DOUBLE rangée de longues
épines fines (plaques rouge sombre à bout noir, penchées vers l'arrière, les plus hautes au milieu du cou, qui
s'écartent en V vues de face) prolongée en plus court sur le dos, petite tête allongée, pattes en piliers, longue
queue en fouet. Orange poussiéreux, ventre crème. Le cou est modélisé droit (peu de pièces) et relevé par la rotation
de repos de Neck1 ; la tête est remise à l'horizontale par la sienne."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino, shade  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.39

BODY = (216, 136, 74)
BELLY = (240, 214, 168)
SPINE = (150, 36, 30)
TIP = (34, 26, 26)
NAIL = (238, 226, 204)
PUPIL = (26, 22, 20)
IRIS = (255, 196, 60)
MOUTH = (176, 74, 70)
BACK = (176, 92, 50)

PERSONALITY = {
    "tempo": 0.85,          # sauropode léger : pas tranquilles mais moins lourds que le Brachiosaure
    "weight": 1.3,
    "stride": 1.0,
    "bob": 0.8,
    "headBob": 0.0,
    "tail": 1.2,            # queue en fouet
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
    "sleepDrop": 0.5,
}

NECK_RAISE = 26             # le cou modélisé droit est relevé de 26 degrés au repos (épines penchées en arrière)


def build():
    d = Dino("Amargasaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 13, 5))
    d.bone("Chest", (0, 12.5, -2), "Hips")
    d.bone("Neck1", (0, 15, -7.5), "Chest", rest=(NECK_RAISE, 0, 0))
    d.bone("Neck2", (0, 15, -12), "Neck1")
    d.bone("Neck3", (0, 15, -16.5), "Neck2")
    d.bone("Head", (0, 15, -20.5), "Neck3", rest=(-NECK_RAISE - 2, 0, 0))
    d.bone("Jaw", (0, 14, -22), "Head")
    d.bone_pair("Lid", (-2.0, 17, -23.5), "Head")
    d.bone_pair("Arm", (-5.4, 11.4, -6.4), "Chest")
    d.bone_pair("Forearm", (-5.6, 6.8, -3.8), "ArmL")
    d.bone_pair("Hand", (-5.6, 2.0, -6.6), "ForearmL")
    d.bone_pair("Thigh", (-5.2, 12.0, 6.0), "Hips")
    d.bone_pair("Shin", (-5.6, 7.0, 3.4), "ThighL")
    d.bone_pair("Foot", (-5.6, 2.2, 6.4), "ShinL")
    tz = [8.5, 12.0, 15.5, 19.0, 22.2, 25.2]
    ty = [15.6, 15.2, 14.6, 14.0, 13.6, 13.4]
    tr = [3.6, 2.8, 2.1, 1.5, 1.0, 0.6]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    chest = ((0, 12.6, -4.0), (5.8, 5.0, 5.8))
    hips = ((0, 13.4, 4.4), (5.6, 5.4, 5.6))
    # ---------------------------------------------------------------- corps en tonneau, bassin plus haut
    d.ellipsoid("Chest", *chest, BODY, where=left, power=3.2)
    d.ellipsoid("Hips", *hips, BODY, where=left, power=3.2)
    # ---------------------------------------------------------------- cou droit (relevé au repos), trois segments
    neck = [(0, 15, -7.5), (0, 15, -12.0), (0, 15, -16.5), (0, 15, -20.5)]
    nr = [3.4, 3.0, 2.7, 2.4]
    for i in range(3):
        d.limb(f"Neck{i + 1}", neck[i], neck[i + 1], nr[i], nr[i + 1], BODY, where=left)
    # ---------------------------------------------------------------- petite tête allongée (crâne bombé, museau carré)
    d.ellipsoid("Head", (0, 15.9, -22.9), (2.6, 2.6, 2.8), BODY, where=lambda x, y, z: x <= 0 and y >= 14, power=2.6)
    d.ellipsoid("Head", (0, 15.2, -25.7), (2.1, 2.0, 2.2), BODY, where=lambda x, y, z: x <= 0 and y >= 14, power=2.4)
    d.ellipsoid("Jaw", (0, 13.6, -24.1), (2.0, 1.0, 2.8), BELLY, where=lambda x, y, z: x <= 0 and y <= 13, power=2.4)
    for z in range(-28, -21):
        if (0, 14, z) in d.vox:
            d.set("Head", 0, 14, z, MOUTH)
        if (0, 13, z) in d.vox:
            d.set("Jaw", 0, 13, z, MOUTH)
    # ---------------------------------------------------------------- pattes en piliers (colonnes droites)
    d.limb("ArmL", (-5.4, 11.4, -6.0), (-5.6, 6.8, -5.4), 2.2, 2.0, BODY)
    d.limb("ForearmL", (-5.6, 6.8, -5.4), (-5.6, 2.0, -5.4), 2.0, 2.0, BODY)
    d.limb("HandL", (-5.6, 2.0, -5.4), (-5.6, 0.7, -5.4), 2.0, 2.0, BODY)
    d.box("HandL", (-8, 0, -8), (-4, 1, -4), BODY)
    for x in (-7, -5):
        d.set("HandL", x, 0, -9, NAIL, "Smooth")
    d.point("FrontToeL", "HandL", (-5.6, 0, -8.5))
    d.ellipsoid("ThighL", (-5.6, 9.6, 5.0), (2.5, 3.6, 3.0), BODY)
    d.limb("ShinL", (-5.6, 7.0, 5.0), (-5.6, 2.2, 5.0), 2.1, 2.1, BODY)
    d.limb("FootL", (-5.6, 2.2, 5.0), (-5.6, 0.7, 5.0), 2.1, 2.1, BODY)
    d.box("FootL", (-8, 0, 2), (-3, 1, 7), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5.6, 0, 1.5))
    # le corps reprend l'intérieur des épaules et des cuisses (moins de pièces, les pattes gardent leur face externe)
    legs = ("ArmL", "ForearmL", "ThighL", "ShinL")
    inner = lambda x, y, z: -4.6 < x <= 0 and d.vox.get((x, y, z), ("",))[0] in legs  # noqa: E731
    d.ellipsoid("Chest", *chest, BODY, where=inner, power=3.2)
    d.ellipsoid("Hips", *hips, BODY, where=inner, power=3.2)
    # ---------------------------------------------------------------- longue queue en fouet
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    d.eye("Head", "LidL", 15, -24, IRIS, PUPIL, lid_color=shade(BODY, -0.16), h=2, w=2)

    # ---------------------------------------------------------------- double rangée d'épines (côté gauche)
    def spine(x, z, h, splay, bones):
        """Épine fine (1 voxel d'épaisseur) posée sur le dessus, portée par l'os qui possède le dessus de la colonne :
        2 de large à la base, puis 1 de large qui s'écarte vers l'extérieur par marches de un voxel (les deux rangées
        s'ouvrent en V vues de face), bout noir. Chaque marche recouvre d'un rang la précédente (contact par une face)."""
        tops = []
        for zz in (z, z + 1):
            ys = [(k[1], v[0]) for k, v in d.vox.items() if k[0] == x and k[2] == zz and v[0] in bones]
            if not ys:
                return
            tops.append(max(ys))
        y0, bone = max(tops)
        hb = max(1, round(h * 0.5))
        for zz, (t, _) in zip((z, z + 1), tops):
            for y in range(t + 1, y0 + hb + 1):
                d.set(bone, x, y, zz, SPINE)
        cuts = [y0 + hb + round(k * (h - hb) / splay) for k in range(splay + 1)]
        for k in range(splay):
            for y in range(cuts[k], cuts[k + 1] + 1):
                d.set(bone, x - 1 - k, y, z + 1, TIP if y >= y0 + h - 1 else SPINE)
    necks = ("Neck1", "Neck2", "Neck3")
    # cou : les plus hautes au milieu (le cou relevé les penche en arrière), les plus hautes s'écartent le plus
    for z, h, sp in ((-9, 6, 1), (-12, 9, 2), (-15, 12, 3), (-18, 11, 3), (-21, 7, 2)):
        spine(-1, z, h, sp, necks)
    # dos : plus courtes, jusqu'au bassin
    for z, h in ((-5, 5), (-1, 4), (3, 4), (7, 3)):
        spine(-1, z, h, 1, ("Chest", "Hips", "Tail1"))

    # ---------------------------------------------------------------- symétrie et peinture
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Chest": 9, "Hips": 10, "Neck1": 12, "Neck2": 12, "Neck3": 12, "Tail1": 13, "Tail2": 13, "Tail3": 13}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    # dos terre cuite (bande coupée à plat) : les épines rouges partent d'un dos plus sombre
    top = {"Chest": 16, "Hips": 17, "Tail1": 17, "Tail2": 16, "Tail3": 16, "Neck1": 17, "Neck2": 17, "Neck3": 17}
    d.paint(lambda x, y, z, bone, c: BACK if c == BODY and bone in top and y >= top[bone] else None)
    # anneaux terre cuite vers le bout du fouet
    d.paint(lambda x, y, z, bone, c: BACK if c in (BODY, BELLY) and bone in ("Tail3", "Tail4", "Tail5") and z % 3 == 0 else None)
    return d
