"""Yutyrannus : grand tyrannosaure à plumes du Glacier, hirsute et imposant.

Voxels de 0,38 stud : environ 18 studs de long et 9 de haut à la taille Normal. Silhouette de tyrannosaure (grosse
tête, cuisses massives, queue épaisse en six segments) couverte d'un plumage hirsute : corps gris givré rayé de
sombre sur le dos, grande crinière blanche en mèches (hérissée sur la nuque, en jabot sous la gorge), culottes de
plumes blanches aux bords effilochés, bras plus longs que ceux du T-Rex à trois griffes et ailerons de plumes, mèches
sous la queue et plumet au bout. Visage de peau nue bleu-gris, petite crête bosselée bleu glace sur le museau, yeux
ambre."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from vox import Dino  # noqa: E402

FAMILY = "Biped"
VOXEL = 0.38

BODY = (150, 162, 184)
DARK = (66, 78, 102)
WHITE = (244, 246, 250)
SKIN = (100, 122, 156)
PALE = (184, 198, 218)
ICE = (128, 204, 244)
CLAW = (238, 242, 250)
PUPIL = (24, 20, 22)
IRIS = (255, 178, 36)
MOUTH = (168, 56, 70)
TONGUE = (212, 100, 112)
TOOTH = (252, 250, 242)

PERSONALITY = {
    "tempo": 0.8,           # grand et lourd, un peu moins que le T-Rex
    "weight": 1.4,
    "stride": 0.95,
    "bob": 1.05,
    "headBob": 0.0,
    "tail": 1.0,
    "diet": "meat",
    "happy": "stomp",
    "catch": "headbutt",
}


def build():
    d = Dino("Yutyrannus", FAMILY, voxel=VOXEL)
    # ---------------------------------------------------------------- os (squelette du T-Rex, bras plus longs)
    d.bone("Hips", (0, 12.8, 2.6))
    d.bone("Chest", (0, 13.1, -1.4), "Hips")
    d.bone("Neck1", (0, 15.0, -7.0), "Chest")
    d.bone("Neck2", (0, 16.7, -9.0), "Neck1")
    d.bone("Head", (0, 18.0, -10.5), "Neck2")
    d.bone("Jaw", (0, 17.3, -12.4), "Head")
    d.bone_pair("Lid", (-2.6, 21, -14.5), "Head")
    d.bone_pair("Arm", (-3.6, 11.6, -5.8), "Chest")
    d.bone_pair("Forearm", (-4.2, 9.2, -6.8), "ArmL")
    d.bone_pair("Thigh", (-3.7, 12.2, 3.1), "Hips")
    d.bone_pair("Shin", (-4.1, 7.1, 0.3), "ThighL")
    d.bone_pair("Foot", (-4.0, 3.4, 3.1), "ShinL")
    tz = [8.3, 11.7, 15.0, 18.0, 20.7, 23.1]
    ty = [13.6, 13.9, 14.1, 14.1, 13.9, 13.8]
    tr = [3.6, 2.9, 2.3, 1.7, 1.2, 0.8]
    for i in range(5):
        d.bone(f"Tail{i + 1}", (0, ty[i], tz[i]), "Hips" if i == 0 else f"Tail{i}")

    left = lambda x, y, z: x <= 0  # noqa: E731

    def behind(draw):
        """Dessine seulement dans les cases vides (ne vole aucun voxel aux os déjà posés)."""
        before = dict(d.vox)
        draw()
        d.vox.update(before)

    # ---------------------------------------------------------------- corps massif
    d.ellipsoid("Hips", (0, 13.3, 3.9), (4.3, 4.3, 5.5), BODY, where=left)
    d.ellipsoid("Chest", (0, 12.8, -3.2), (4.6, 4.8, 4.6), BODY, where=left)
    d.limb("Neck1", (0, 14.6, -6.8), (0, 16.7, -9.0), 3.3, 3.1, BODY, where=left)
    d.limb("Neck2", (0, 16.7, -9.0), (0, 17.9, -10.4), 3.1, 3.0, BODY, where=left)
    # ---------------------------------------------------------------- tête : peau nue bleu-gris, long museau
    d.ellipsoid("Head", (0, 19.2, -13.1), (3.0, 3.0, 3.3), SKIN, where=lambda x, y, z: x <= 0 and y >= 18, power=2.7)
    d.ellipsoid("Head", (0, 18.5, -17.6), (2.2, 2.0, 3.3), SKIN, where=lambda x, y, z: x <= 0 and y >= 18, power=2.5)
    d.ellipsoid("Jaw", (0, 16.8, -16.0), (2.1, 1.3, 4.4), PALE, where=lambda x, y, z: x <= 0 and y <= 17, power=2.6)
    d.box("Jaw", (-1, 17, -12), (0, 17, -11), PALE)
    d.box("Head", (0, 18, -20), (0, 18, -13), MOUTH)
    d.box("Jaw", (0, 17, -19), (0, 17, -13), TONGUE)
    for z in (-20, -18, -16):
        x = d.surface_x(18, z, "Head")
        if x is not None:
            d.set("Head", x, 18, z, TOOTH, "Smooth")
    for z in (-19, -17):
        x = d.surface_x(17, z, "Jaw")
        if x is not None:
            d.set("Jaw", x, 17, z, TOOTH, "Smooth")
    d.set("Head", -1, 20, -21, DARK, "Smooth")  # narine
    # petite crête bosselée sur le museau (bleu glace, un voxel de large)
    for z, h in ((-20, 1), (-19, 2), (-18, 1), (-17, 2), (-16, 1)):
        top = d.surface_y(0, z, "Head")
        for k in range(1, h + 1):
            d.set("Head", 0, top + k, z, ICE)
    # ---------------------------------------------------------------- crinière blanche hirsute
    # cou bouffant, mèches hérissées sur la nuque (vers l'arrière), jabot en pointes sous la gorge
    behind(lambda: d.ellipsoid("Neck2", (0, 17.6, -9.6), (4.0, 3.8, 2.6), WHITE, where=lambda x, y, z: x <= 0 and z <= -9))
    behind(lambda: d.ellipsoid("Neck1", (0, 16.4, -7.6), (4.2, 4.0, 2.8), WHITE, where=left))
    tuft = [(21.2, -12.6), (25.0, -10.4), (23.0, -9.6), (24.4, -7.0), (22.2, -7.4), (22.6, -4.6), (20.4, -6.6),
            (19.6, -9.6)]
    bib = [(16.4, -12.8), (15.0, -13.2), (11.8, -10.8), (14.0, -10.6), (11.0, -8.2), (13.2, -8.0), (12.0, -6.6),
           (15.0, -6.6), (16.4, -9.0)]
    behind(lambda: d.plate("Head", 0, -1, tuft, WHITE, thick=2))
    behind(lambda: d.plate("Neck1", 0, -2, bib, WHITE, thick=3))
    belly_fringe = [(10.4, -7.2), (8.0, -6.6), (8.8, -5.8), (6.8, -4.8), (7.8, -3.8), (6.4, -2.6), (7.6, -1.6),
                    (9.6, -1.4)]
    behind(lambda: d.plate("Chest", 0, -2, belly_fringe, WHITE, thick=3))
    for (x, y, z), (bone, col, mat) in list(d.vox.items()):
        if bone == "Neck1" and z <= -9:
            d.vox[(x, y, z)] = ("Neck2", col, mat)
    # ---------------------------------------------------------------- bras à trois griffes et ailerons de plumes
    d.limb("ArmL", (-3.6, 11.6, -5.8), (-4.2, 9.2, -6.8), 1.3, 1.1, BODY)
    d.limb("ForearmL", (-4.2, 9.2, -6.8), (-4.2, 7.8, -9.2), 1.0, 0.85, BODY)
    for x, z in ((-5, -10), (-4, -11), (-3, -10)):
        d.set("ForearmL", x, 7, z, CLAW, "Smooth")
    d.plate("ForearmL", 0, -5, [(9.8, -6.2), (8.4, -9.0), (6.2, -7.8), (7.2, -7.0), (6.0, -6.0), (8.0, -5.4)], WHITE)
    # ---------------------------------------------------------------- pattes : culottes de plumes, jambes nues
    d.ellipsoid("ThighL", (-4.2, 9.7, 1.9), (2.6, 3.8, 3.6), WHITE)
    hem = [(7.6, -1.4), (5.0, 0.6), (6.6, 0.8), (4.6, 2.8), (6.4, 3.0), (4.8, 5.0), (7.6, 5.2)]
    d.plate("ThighL", 0, -6, hem, WHITE, thick=3)
    d.limb("ShinL", (-4.1, 7.1, 0.3), (-4.0, 3.4, 3.1), 1.9, 1.45, SKIN)
    d.limb("FootL", (-4.0, 3.4, 3.1), (-4.0, 0.9, 1.0), 1.45, 1.35, SKIN)
    d.box("FootL", (-6, 0, -3), (-2, 0, 1), SKIN)
    d.box("FootL", (-5, 1, -2), (-3, 1, 1), SKIN)
    for x in (-6, -4, -2):
        d.set("FootL", x, 0, -4, CLAW, "Smooth")
    d.point("ToeL", "FootL", (-4, 0, -3.5))
    # ---------------------------------------------------------------- queue épaisse, mèches dessous, plumet au bout
    for i in range(5):
        d.limb(f"Tail{i + 1}", (0, ty[i], tz[i]), (0, ty[i + 1], tz[i + 1]), tr[i], tr[i + 1], BODY, where=left)
    d.plate("Tail2", 0, -1, [(12.0, 11.4), (9.8, 13.8), (11.8, 13.8), (10.4, 16.0), (12.6, 16.0), (12.6, 11.4)], WHITE,
            thick=2)
    d.plate("Tail3", 0, -1, [(12.4, 16.0), (10.8, 18.6), (12.8, 18.6), (12.8, 16.0)], WHITE, thick=2)
    plume = [(14.6, 20.2), (17.4, 24.4), (15.2, 24.0), (14.8, 27.4), (13.4, 24.6), (11.0, 26.6), (11.6, 23.6),
             (12.6, 21.0)]
    d.plate("Tail5", 0, -1, plume, WHITE, thick=2)
    # ---------------------------------------------------------------- yeux, arcade, symétrie
    d.eye("Head", "LidL", 20, -15, IRIS, PUPIL, h=1, w=2)
    d.box("Head", (-3, 22, -16), (-3, 22, -14), DARK)  # arcade au-dessus de l'oeil
    d.remove(lambda x, y, z: y < 0)
    d.mirror()
    # ---------------------------------------------------------------- peinture : ventre blanc, dos rayé
    belly = {"Hips": 11, "Chest": 11, "Tail1": 12, "Tail2": 12, "Tail3": 12, "Tail4": 13}
    d.paint(lambda x, y, z, bone, c: WHITE if c == BODY and bone in belly and y <= belly[bone] else None)
    d.back_stripes(["Hips", "Chest", "Tail1", "Tail2", "Tail3", "Tail4"], DARK, frac=0.3, period=5, width=2,
                   only=[BODY])
    return d
