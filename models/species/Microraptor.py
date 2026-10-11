"""Microraptor : volant de la Fern Forest, petit raptor à plumes qui plane avec quatre ailes.

Modélisé ailes déployées (plaques horizontales : peu de pièces), voxels de 0,146 stud : environ 7 studs d'envergure à
la taille Normal pour un corps de 5 studs (queue comprise). Petite tête de raptor aux grands yeux, ailes de plumes aux
bras (couvertures, rémiges secondaires en dents, rémiges primaires écartées au bout), longues plumes aussi aux pattes
arrière (sur les cuisses et les jambes : la deuxième paire d'ailes, qui traîne derrière en vol), longue queue raide
finie par un éventail de plumes. Bleu-noir irisé : reflets sarcelle et violets en bandes.
Au parc il se tient replié sur ses pattes et ses poignets (les animations replient les ailes)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Flyer"
VOXEL = 0.137

BODY = (42, 54, 108)
DARK = (20, 22, 40)
TEAL = (30, 172, 170)
VIOLET = (126, 78, 200)
BELLY = (92, 104, 148)
CLAW = (226, 220, 206)
PUPIL = (20, 16, 14)
IRIS = (255, 198, 40)
MOUTH = (196, 84, 96)
TOOTH = (250, 248, 240)

PERSONALITY = {
    "tempo": 1.3,           # petit et vif
    "weight": 0.6,
    "stride": 1.1,
    "bob": 1.1,
    "headBob": 0.8,         # port de tête d'oiseau
    "tail": 0.7,            # queue raide
    "diet": "meat",
    "happy": "flap",
    "catch": "peck",        # coup de bec plongé
}

Y_W = 10                    # plan des ailes (y)


def build():
    d = Dino("Microraptor", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 9.0, 2.2))
    d.bone("Chest", (0, 9.6, -1.0), "Hips")
    d.bone("Neck1", (0, 10.8, -3.4), "Chest")
    d.bone("Head", (0, 12.8, -5.4), "Neck1")
    d.bone("Jaw", (0, 12.2, -7.6), "Head")
    d.bone_pair("Lid", (-1.8, 15, -7.5), "Head")
    d.bone_pair("Wing1", (-1.8, Y_W, -2.0), "Chest")
    d.bone_pair("Wing2", (-6.8, Y_W, -1.8), "Wing1L")
    d.bone_pair("Wing3", (-13.0, Y_W, -2.4), "Wing2L")
    d.bone_pair("Thigh", (-1.6, 8.6, 2.6), "Hips")
    d.bone_pair("Shin", (-1.8, 5.2, 0.6), "ThighL")
    d.bone_pair("Foot", (-1.8, 2.2, 3.0), "ShinL")
    tz = [4.6, 7.8, 11.0, 14.0, 17.0]
    ty = [9.4, 9.6, 9.8, 10.0, 10.1]
    tr = [1.5, 1.2, 1.0, 0.8, 0.6]
    for i in range(4):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps d'oiseau
    d.ellipsoid("Chest", (0, 9.8, -1.2), (2.2, 2.3, 3.0), BODY, where=left)
    d.ellipsoid("Hips", (0, 9.4, 2.6), (2.0, 2.1, 2.6), BODY, where=left)
    d.limb("Neck1", (0, 10.4, -3.0), (0, 12.4, -5.2), 1.6, 1.4, BODY, where=left)
    # ---------------------------------------------------------------- petite tête de raptor, grands yeux
    d.ellipsoid("Head", (0, 13.8, -7.0), (2.1, 2.3, 2.4), BODY, where=left, power=2.4)
    d.ellipsoid("Head", (0, 13.0, -10.0), (1.4, 1.3, 2.4), BODY, where=lambda x, y, z: x <= 0 and y >= 13, power=2.4)
    d.ellipsoid("Jaw", (0, 12.0, -9.2), (1.2, 0.8, 2.6), BELLY, where=lambda x, y, z: x <= 0 and y <= 12, power=2.4)
    d.box("Head", (0, 13, -11), (0, 13, -8), MOUTH)
    for z in (-11, -9):
        d.set("Head", -1, 12, z, TOOTH, "Smooth")
    d.eye("Head", "LidL", 13, -8, IRIS, PUPIL, lid_color=DARK, h=2, w=2)
    # ---------------------------------------------------------------- plumes : bout foncé, bande violette, bande sarcelle
    def onion(bone_of, voxels, inner, core=BODY, dirs=None):
        """Colore des plumes en couches depuis le bord : bout foncé, violet, sarcelle, puis bleu nuit. `inner(x, y, z)`
        dit si un voisin manquant est un bord intérieur (côté corps) qui ne compte pas."""
        vs = set(voxels)
        depth = {}
        dirs = dirs or ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
        layer = [v for v in vs if any((v[0] + dx, v[1] + dy, v[2] + dz) not in vs and
                                      not inner(v[0] + dx, v[1] + dy, v[2] + dz) for dx, dy, dz in dirs)]
        k = 0
        while layer and k < 3:
            for v in layer:
                depth[v] = k
            nxt = set()
            for (x, y, z) in layer:
                for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                    n = (x + dx, y + dy, z + dz)
                    if n in vs and n not in depth:
                        nxt.add(n)
            layer = list(nxt)
            k += 1
        for v in vs:
            col = (DARK, VIOLET, TEAL)[depth[v]] if v in depth else core
            d.set(bone_of(*v), *v, col)

    # ---------------------------------------------------------------- aile (gauche), plaque horizontale
    # couvertures (bande avant, de l'épaule au bout de la main), bleu nuit
    cov = [(-1.8, -2.8), (-6.8, -2.8), (-13.0, -3.4), (-18.0, -2.4), (-22.0, -0.8), (-22.0, 0.4), (-18.0, 0.6),
           (-13.0, 1.4), (-6.8, 1.4), (-1.8, 1.6)]
    d.plate("Wing1L", 1, Y_W, cov, BODY)
    wing_bone = lambda x, y, z: "Wing3L" if x <= -13 else ("Wing2L" if x <= -7 else "Wing1L")  # noqa: E731
    feathers = []
    # rémiges secondaires vers l'arrière (deux voxels de large, bord de fuite en dents)
    for x, z1 in zip(range(-2, -14, -2), (6, 5, 6, 5, 6, 5)):
        feathers += [(xx, Y_W, z) for xx in (x - 1, x) for z in range(2, z1 + 1)]
    # rémiges primaires vers l'extérieur : bout d'aile pointu en marches (plumes de plus en plus courtes vers l'arrière)
    tip = {-3: -17, -2: -21, -1: -24, 0: -25, 1: -25, 2: -24, 3: -23, 4: -21, 5: -19, 6: -16}
    feathers += [(x, Y_W, z) for z, x1 in tip.items() for x in range(x1, -13)]
    for v in feathers:
        d.set(wing_bone(*v), *v, BODY)
    onion(wing_bone, feathers, lambda x, y, z: (x, y, z) in d.vox and d.vox[(x, y, z)][1] == BODY or y != Y_W)
    # bord d'attaque : bras, avant-bras, main
    d.limb("Wing1L", (-1.8, Y_W, -2.0), (-6.8, Y_W, -1.8), 1.0, 0.8, BODY)
    d.limb("Wing2L", (-6.8, Y_W, -1.8), (-13.0, Y_W, -2.4), 0.8, 0.6, BODY)
    d.limb("Wing3L", (-13.0, Y_W, -2.4), (-21.0, Y_W, -0.6), 0.6, 0.4, BODY)
    d.box("Wing2L", (-13, Y_W - 1, -4), (-12, Y_W - 1, -4), CLAW, "Smooth")
    d.point("HandL", "Wing2L", (-12.5, Y_W - 1, -3.6))
    d.point("WingTipL", "Wing3L", (-25.0, Y_W, 0.0))
    # ---------------------------------------------------------------- pattes : longues plumes sur les jambes
    d.limb("ThighL", (-1.6, 8.6, 2.6), (-1.8, 5.2, 0.6), 1.3, 1.0, BODY)
    d.limb("ShinL", (-1.8, 5.2, 0.6), (-1.8, 2.2, 3.0), 0.8, 0.6, DARK)
    d.limb("FootL", (-1.8, 2.2, 3.0), (-1.8, 0.5, 1.8), 0.6, 0.6, DARK)
    d.box("FootL", (-3, 0, -1), (-1, 0, 2), DARK)
    for x in (-3, -1):
        d.set("FootL", x, 0, -2, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-2.0, 0, -0.4))
    # plumes de la jambe : plaque verticale qui part vers l'arrière et le bas (à l'horizontale en vol, pattes repliées)
    tmp = Dino("tmp", FAMILY, voxel=VOXEL)
    tmp.bone("ShinL", (0, 0, 0))
    tmp.plate("ShinL", 0, -2, [(6.2, 1.0), (5.8, 8.6), (4.8, 10.0), (3.6, 9.2), (2.6, 7.0), (2.4, 4.0)], BODY)
    leg = [v for v in tmp.vox if v not in d.vox]
    for v in leg:
        d.set("ShinL", *v, BODY)
    onion(lambda x, y, z: "ShinL", leg, lambda x, y, z: False, dirs=((0, 0, 1), (0, -1, 1)))
    # ---------------------------------------------------------------- queue raide, éventail de plumes au bout
    for i in range(4):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    fan = [(0.6, 11.0), (-1.6, 12.4), (-3.4, 15.4), (-4.4, 18.6), (-4.0, 21.6), (-2.4, 24.0), (0.6, 25.0)]
    tmp = Dino("tmp", FAMILY, voxel=VOXEL)
    tmp.bone("Tail4", (0, 0, 0))
    tmp.plate("Tail4", 1, 11, fan, BODY)
    tail_bone = lambda x, y, z: "Tail3" if z < 14 else "Tail4"  # noqa: E731
    fanv = [v for v in tmp.vox if v[0] <= 0]
    for v in fanv:
        d.set(tail_bone(*v), *v, BODY)
    onion(tail_bone, fanv, lambda x, y, z: x > 0 or y != 11, core=TEAL)
    # ---------------------------------------------------------------- symétrie, peinture
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in ("Chest", "Hips", "Neck1") and
            y <= {"Chest": 8, "Hips": 8, "Neck1": 10}[bone] else None)
    return d
