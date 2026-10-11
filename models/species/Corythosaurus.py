"""Corythosaurus : hadrosaure du Swamp à bec de canard et grand casque arrondi, paisible.

Voxels de 0,26 stud : environ 13,5 studs de long et 7 de haut (casque compris) à la taille Normal. Tête de cheval à
bec de canard clair ; posé sur le crâne, au-dessus de l'oeil, un grand casque arrondi en demi-disque bombé (os Crest)
bleu vif cerclé d'orange, le signe qu'on reconnaît de loin. Corps massif brun chaud, dos olive rayé, ventre crème,
pattes avant plus fines, longue queue haute et plate."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Quadruped"
VOXEL = 0.26

BODY = (164, 104, 60)
OLIVE = (112, 118, 54)
BELLY = (238, 220, 176)
CREST = (36, 120, 236)
CREST_RIM = (250, 142, 38)
BILL = (232, 208, 156)
NAIL = (236, 226, 204)
PUPIL = (26, 22, 20)
IRIS = (255, 222, 96)
MOUTH = (186, 92, 96)

PERSONALITY = {
    "tempo": 0.95,          # grand herbivore tranquille
    "weight": 1.15,
    "stride": 1.0,
    "bob": 0.9,
    "headBob": 0.0,
    "tail": 0.9,
    "diet": "plants",
    "happy": "stomp",
    "catch": "toss",
}

# casque, profil (y, z) : part du haut du museau, monte en pente, sommet au-dessus de l'oeil, arrondi derrière le
# crâne ; le bord du bas suit le dessus de la tête (l'oeil reste dessous, sur la peau)
HELMET = [(16.6, -19.0), (18.6, -19.5), (20.6, -19.2), (22.6, -18.2), (24.2, -16.6), (25.1, -14.6), (25.4, -12.6),
          (25.1, -10.6), (24.1, -9.0), (22.5, -8.0), (20.6, -7.8), (19.4, -9.0), (19.4, -15.2), (17.4, -16.2)]
# bas du demi-disque complet (sous la tête), seulement pour trouver le bord extérieur
DISC_BOTTOM = [(18.0, -8.9), (14.0, -10.6), (14.0, -17.0)]


def inside(poly, a, b):
    n, j, ok = len(poly), len(poly) - 1, False
    for i in range(n):
        ai, bi = poly[i]
        aj, bj = poly[j]
        if (bi > b) != (bj > b) and a < (aj - ai) * (b - bi) / (bj - bi + 1e-12) + ai:
            ok = not ok
        j = i
    return ok


def build():
    d = Dino("Corythosaurus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os
    d.bone("Hips", (0, 10.5, 5))
    d.bone("Chest", (0, 10, 1), "Hips")
    d.bone("Neck1", (0, 11, -6), "Chest")
    d.bone("Neck2", (0, 13.4, -8.6), "Neck1")
    d.bone("Head", (0, 15.6, -10.6), "Neck2")
    d.bone("Jaw", (0, 14.6, -13.0), "Head")
    d.bone("Crest", (0, 18.0, -13.0), "Head")
    d.bone_pair("Lid", (-2.6, 18, -14), "Head")
    d.bone_pair("Arm", (-4.2, 8.6, -3.8), "Chest")
    d.bone_pair("Forearm", (-4.6, 5.4, -2.2), "ArmL")
    d.bone_pair("Hand", (-4.6, 2.2, -4.2), "ForearmL")
    d.bone_pair("Thigh", (-4.6, 9.8, 6), "Hips")
    d.bone_pair("Shin", (-5.0, 5.4, 3.8), "ThighL")
    d.bone_pair("Foot", (-5.0, 2.4, 6.4), "ShinL")
    tz = [11.5, 15.5, 19.4, 23.0, 26.4, 29.4]
    ty = [11.0, 10.8, 10.4, 9.9, 9.4, 9.0]
    tr = [4.4, 3.6, 2.8, 2.1, 1.5, 1.0]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731
    # ---------------------------------------------------------------- corps massif
    d.ellipsoid("Hips", (0, 10.8, 6), (5.2, 5.4, 6.4), BODY, where=left, power=2.6)
    d.ellipsoid("Chest", (0, 9.8, -1.2), (5.0, 5.0, 5.4), BODY, where=left, power=2.6)
    d.limb("Neck1", (0, 10.6, -5.4), (0, 13.4, -8.6), 3.3, 2.9, BODY, where=left)
    d.limb("Neck2", (0, 13.4, -8.6), (0, 15.6, -10.6), 2.9, 2.7, BODY, where=left)
    # ---------------------------------------------------------------- tête de cheval, bec de canard large
    d.ellipsoid("Head", (0, 16.9, -12.6), (3.0, 3.0, 3.2), BODY, where=left, power=2.4)
    d.ellipsoid("Head", (0, 15.6, -16.2), (2.3, 1.9, 3.0), BODY, where=lambda x, y, z: x <= 0 and y >= 14.6, power=2.3)
    d.ellipsoid("Head", (0, 15.0, -19.3), (2.9, 1.2, 2.1), BILL, where=lambda x, y, z: x <= 0 and y >= 14.6)
    d.ellipsoid("Jaw", (0, 14.0, -15.6), (1.9, 1.0, 3.2), BELLY, where=lambda x, y, z: x <= 0 and y <= 14, power=2.4)
    d.ellipsoid("Jaw", (0, 13.8, -18.9), (2.5, 0.9, 1.8), BILL, where=lambda x, y, z: x <= 0 and y <= 14)
    d.box("Jaw", (-1, 14, -13), (0, 14, -12), BODY)
    for z in range(-18, -12):
        if (0, 15, z) in d.vox:
            d.set("Head", 0, 15, z, MOUTH)
        if (0, 14, z) in d.vox:
            d.set("Jaw", 0, 14, z, MOUTH)
    d.set("Head", -1, 16, -20, (98, 60, 36), "Smooth")      # narine
    # ---------------------------------------------------------------- casque en demi-disque, bleu cerclé d'orange
    # posé SUR le crâne : il ne recouvre jamais la peau de la tête (l'oeil reste sur la peau brune). Bombé : le bord
    # orange n'a qu'un voxel d'épaisseur, le casque bleu en a 3 juste derrière, et 5 à la base pour l'ancrer au crâne
    # (de face : arête orange au milieu, flancs bleus).
    cells = {(y, z) for y in range(16, 26) for z in range(-20, -7) if inside(HELMET, y, z)}
    # bord extérieur (dessus, avant, arrière) : le bas du casque, posé sur la tête, n'est pas un bord
    disc = {(y, z) for y in range(14, 26) for z in range(-20, -7) if inside(HELMET[:11] + DISC_BOTTOM, y, z)}
    dist = {k: 0 for k in cells if any((k[0] + dy, k[1] + dz) not in disc for dy, dz in ((1, 0), (0, 1), (0, -1)))}
    front = list(dist)
    while front:
        nxt = []
        for (y, z) in front:
            for dy, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (y + dy, z + dz)
                if k in cells and k not in dist:
                    dist[k] = dist[(y, z)] + 1
                    nxt.append(k)
        front = nxt
    for (y, z), k in dist.items():
        for x in (0, -1, -2):
            if x == -1 and k < 1 or x == -2 and (k < 2 or y > 20):
                continue
            if d.vox.get((x, y, z), ("",))[0] != "Head":
                d.set("Crest", x, y, z, CREST_RIM if k == 0 else CREST)
    # ---------------------------------------------------------------- pattes avant fines, pattes arrière fortes
    d.limb("ArmL", (-4.2, 8.6, -3.8), (-4.6, 5.4, -2.2), 1.8, 1.5, BODY)
    d.limb("ForearmL", (-4.6, 5.4, -2.2), (-4.6, 2.2, -4.2), 1.4, 1.2, BODY)
    d.limb("HandL", (-4.6, 2.2, -4.2), (-4.6, 0.7, -4.8), 1.2, 1.2, BODY)
    d.box("HandL", (-6, 0, -6), (-3, 1, -4), BODY)
    for x in (-6, -4):
        d.set("HandL", x, 0, -7, NAIL, "Smooth")
    d.ellipsoid("ThighL", (-5.0, 7.6, 5.4), (2.7, 3.9, 3.5), BODY)
    d.limb("ShinL", (-5.0, 5.4, 3.8), (-5.0, 2.4, 6.4), 2.0, 1.7, BODY)
    d.limb("FootL", (-5.0, 2.4, 6.4), (-5.0, 0.8, 4.8), 1.7, 1.7, BODY)
    d.box("FootL", (-7, 0, 2), (-3, 1, 6), BODY)
    for x in (-7, -5, -3):
        d.set("FootL", x, 0, 1, NAIL, "Smooth")
    d.point("ToeL", "FootL", (-5, 0, 2))
    d.point("FrontToeL", "HandL", (-4.5, 0, -6.5))
    # ---------------------------------------------------------------- longue queue haute et plate
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left,
               flat=1.25)
    # ---------------------------------------------------------------- yeux + symétrie + peinture
    d.eye("Head", "LidL", 16, -14, IRIS, PUPIL, lid_color=BODY, h=2, w=2)
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    belly = {"Hips": 7, "Chest": 6, "Neck1": 9, "Neck2": 12, "Tail1": 8, "Tail2": 8, "Tail3": 8}
    d.paint(lambda x, y, z, bone, c: BELLY if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Hips", "Chest", "Neck1", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"], OLIVE, frac=0.32,
                   period=5, width=2, only=[BODY])
    return d
