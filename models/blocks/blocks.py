"""Blocs de fossiles de Steal a Fossil (brief 9) : un bloc de roche voxel par rareté, un décor par biome.

Le bloc montre sa rareté (GDD : « le bloc montre sa rareté, l'espèce est une surprise ») : le squelette est le même
pour toutes les raretés, la couleur de la roche donne la rareté (Config.Rarity.Info) et les raretés hautes ajoutent
des cristaux de plus en plus nombreux, des os en or (Legendary), une base de lave (Mythic), des couches arc-en-ciel et
des os nacrés (Secret). En jeu, les blocs rares sont aussi plus gros et éclairent autour d'eux (BlockModels.Looks).
Demande de Snaky (2026-10-11) : un bloc différent par biome. Chaque zone ajoute son décor (sable et coquillages,
mousse et fougère, boue et liane...), posé autour de la roche sans cacher sa couleur : BlockModels assemble le bloc de
la rareté et le décor du biome.

Grille de 17 x 17 x 17 voxels de 3/17 de stud : un bloc de 3 studs, la taille de la pièce FossilBlock du serveur.
Repère du jeu : X droite, Y haut, l'avant du bloc regarde vers -Z. Cases entières de 0 à 16 ; le centre du bloc est
le centre de la grille. Os en relief (un voxel au-dessus de la roche), vus de l'extérieur de chaque face :
  avant (-Z)  crâne de profil, dents et orbites        droite (+X)  colonne vertébrale et côtes
  gauche (-X) queue en vertèbres à épines              arrière (+Z) décor du biome
  dessus      studs en jeu ; cristaux de la rareté sur la moitié avant (le bloc porté est tourné : ils s'éloignent
              du joueur), décor du biome sur la moitié arrière

Os du modèle = rôle des briques en jeu (BlockModels, FossilBlockController) :
  Rock    roche          Fossil   os                    Glow   bande de lave Neon du Mythic (bat en jeu)
  Rainbow couches arc-en-ciel du Secret (leur couleur tourne en jeu)
  Gem1..n cristaux de la rareté, chacun incliné par la rotation de repos de son os (pivot à sa base)
  Biome   décor du biome ; Deco1..n pièces inclinées du décor (feuilles, éclats), comme les cristaux
Formes sûres pour la modération : os en segments carrés épais, vertèbres en blocs, pas de « tube + boule », pas de
sphères par paires. Peu de pièces : la roche est un cube biseauté de 4 boîtes que rien ne découpe (os, cristaux et
décor sont posés dessus)."""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import vox  # noqa: E402
from vox import Dino, shade  # noqa: E402

# Pour la fusion des voxels, toutes les matières des blocs comptent comme opaques : les cases cachées d'un cristal
# épais (même en verre) servent de jokers et il reste une seule pièce. « Foil » : os en or du Legendary (comparé dans
# Studio : le plastique doré à reflet virait au beige) et os nacrés du Secret (en Neon blanc, le halo du jeu effaçait
# le crâne). Ne concerne que ce processus.
vox.MATERIALS = vox.MATERIALS + ("Foil",)
vox.OPAQUE = vox.MATERIALS

N = 17  # voxels par côté
SIZE = 3.0  # studs
VOXEL = SIZE / N
LIFT = 40  # voxels : les pièces inclinées sont modélisées au-dessus de la roche, puis redescendues à l'export

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
BIOMES = ["Beach", "Fern Forest", "Swamp", "Canyon", "Glacier", "Volcano", "Ocean Trench", "Meteor Crater"]

# couleur du bloc de chaque rareté : la même que Config.Rarity.Info (src/shared/Config/Rarity.luau)
RARITY_COLOR = {
    "Common": (163, 162, 165),
    "Uncommon": (75, 175, 75),
    "Rare": (30, 110, 220),
    "Epic": (140, 60, 210),
    "Legendary": (255, 145, 20),
    "Mythic": (215, 35, 35),
    "Secret": (255, 90, 200),
}

# taille en jeu par rapport à un bloc Common (demande de Snaky : les plus rares beaucoup plus gros)
SCALES = {"Common": 1.0, "Uncommon": 1.06, "Rare": 1.14, "Epic": 1.24, "Legendary": 1.38, "Mythic": 1.55,
          "Secret": 1.8}

# couches du Secret, du bas vers le haut (en jeu, leurs couleurs tournent)
RAINBOW = [(236, 56, 64), (255, 170, 40), (80, 200, 90), (60, 140, 240), (170, 90, 235)]

BONE = (238, 228, 200)
GOLD = (255, 200, 50)
PEARL = (250, 248, 255)

# ---------------------------------------------------------------------- look de chaque rareté
# rock : roche ; bone, bone_mat : os ; gems : grappes de cristaux (GEM_SETS) ; gem, gem_mat : cristaux (verre pour
# Rare et Epic, Neon qui brille à partir de Legendary) ; lava : bande du bas en lave Neon (Mythic)
LOOKS = {
    "Common": {"rock": (150, 149, 152), "bone": BONE, "bone_mat": "Plastic", "gems": 0},
    "Uncommon": {"rock": (66, 160, 66), "bone": BONE, "bone_mat": "Plastic",
                 "gems": 1, "gem": (150, 226, 108), "gem_mat": "Plastic"},
    "Rare": {"rock": (32, 102, 204), "bone": BONE, "bone_mat": "Plastic",
             "gems": 2, "gem": (120, 200, 255), "gem_mat": "Glass"},
    "Epic": {"rock": (124, 54, 192), "bone": BONE, "bone_mat": "Plastic",
             "gems": 3, "gem": (190, 120, 255), "gem_mat": "Glass"},
    "Legendary": {"rock": (226, 112, 12), "bone": GOLD, "bone_mat": "Foil",
                  "gems": 4, "gem": (255, 196, 30), "gem_mat": "Neon"},
    "Mythic": {"rock": (150, 22, 26), "bone": BONE, "bone_mat": "Plastic",
               "gems": 4, "gem": (255, 74, 30), "gem_mat": "Neon", "lava": (255, 106, 30)},
    "Secret": {"rock": None, "bone": PEARL, "bone_mat": "Foil",
               "gems": 5, "gem": None, "gem_mat": "Neon"},
}

# ---------------------------------------------------------------------- os en relief sur les faces
# '#' os. Lignes du haut vers le bas, colonnes de la gauche vers la droite vues de l'extérieur de la face.
SKULL = [  # crâne de profil, museau à gauche : fenêtre devant l'orbite, orbite, dents du haut, bouche entrouverte
    "......######.",
    "...#########.",
    ".####.##..###",
    "#####.##..###",
    "#############",
    "#.#.#.#.#####",
    "..........###",
    ".##########..",
    "...######....",
]
RIBS = [  # colonne vertébrale qui sort par les bords, côtes qui se courbent vers l'arrière
    "##.##.##.##.#",
    "##.##.##.##.#",
    ".#..#..#..#..",
    ".#..#..#..#..",
    ".#..#..#..#..",
    ".#..#..#..#..",
    "#..#..#..#...",
    "#..#..#..#...",
]
TAIL = [  # queue qui descend en courbe : vertèbres de plus en plus petites, chacune avec son épine dorsale
    "...........#.",
    ".......#..###",
    ".......##.###",
    "....#..##....",
    "....##.......",
    ".#..##.......",
    ".##..........",
    ".##..........",
    "#............",
]

# (dessin, colonne de gauche, ligne du haut)
FACE_ART = {
    "front": (SKULL, 2, 12),
    "right": (RIBS, 2, 12),
    "left": (TAIL, 2, 12),
}


def face_cell(face, col, row, depth):
    """Case de la grille d'un point (colonne, ligne, profondeur) d'une face vue de l'extérieur (profondeur -1 : en
    relief, juste au-dessus de la face)."""
    if face == "front":  # -Z : la droite de celui qui regarde est -X
        return (N - 1 - col, row, depth)
    if face == "back":  # +Z : la droite est +X
        return (col, row, N - 1 - depth)
    if face == "right":  # +X : la droite est -Z
        return (N - 1 - depth, row, N - 1 - col)
    if face == "left":  # -X : la droite est +Z
        return (depth, row, col)
    if face == "top":  # vu d'en haut, l'avant en bas : colonne = x, ligne = z
        return (col, N - 1 - depth, row)
    raise ValueError(face)


def rock_cells():
    """Cube aux arêtes biseautées en deux marches : union de 4 boîtes (4 pièces une fois fusionné)."""
    m = N - 1
    parts = [((0, 2, 2), (m, m - 2, m - 2)), ((2, 0, 2), (m - 2, m, m - 2)), ((2, 2, 0), (m - 2, m - 2, m)),
             ((1, 1, 1), (m - 1, m - 1, m - 1))]
    cells = set()
    for a, b in parts:
        for x in range(a[0], b[0] + 1):
            for y in range(a[1], b[1] + 1):
                for z in range(a[2], b[2] + 1):
                    cells.add((x, y, z))
    return cells


ROCK = rock_cells()


def art_cells(art):
    """{(colonne, ligne): caractère} d'un dessin posé sur une face."""
    rows, col0, top = art
    out = {}
    for i, line in enumerate(rows):
        for j, ch in enumerate(line):
            out[(col0 + j, top - i)] = ch
    return out


# grappes de cristaux sur le dessus : (x, z de la base, hauteur, largeur, inclinaison rx, rz) en voxels et degrés.
# Moitié avant du dessus (z petit). rx < 0 penche vers l'avant (-Z), rz > 0 vers la gauche (-X) ; les bases ne se
# chevauchent pas. Un cristal de largeur 3 finit en pointe (croix puis une case), un de largeur 2 par une case.
GEMS = {
    "small": [(4, 5, 4, 2, -10, 10), (7, 4, 3, 2, -24, -8)],
    "left": [(4, 5, 6, 3, -8, 8), (7, 4, 4, 2, -22, -10), (3, 8, 3, 2, 10, 24)],
    "right": [(11, 5, 5, 3, -10, -10), (13, 8, 3, 2, 6, -24), (9, 4, 3, 2, -24, 6)],
    "middle": [(7, 8, 4, 2, 4, -4)],
    "back": [(13, 12, 3, 2, 14, -16), (2, 12, 4, 2, 16, 14)],
}
# grappes selon le nombre de « gems » de la rareté
GEM_SETS = {1: ["small"], 2: ["left"], 3: ["left", "right"], 4: ["left", "right", "middle"],
            5: ["left", "right", "middle", "back"]}


def surface_top(d, gx, gz, w, solid=None):
    """Plus haute case pleine sous la base d'une pièce posée sur le dessus (roche par défaut)."""
    cells = solid if solid is not None else ROCK
    tops = []
    for dx in range(w):
        for dz in range(w):
            ys = [y for (x, y, z) in cells if x == gx + dx and z == gz + dz]
            if ys:
                tops.append(max(ys))
    return min(tops) if tops else N - 1


def standing(d, name, x, z, w, h, rest, body, tip, mat, top=None):
    """Pièce dressée sur le dessus (cristal, éclat) : colonne w x w de h voxels au-dessus de la surface, dont la base
    descend de deux voxels dans la roche, puis une pointe. Modélisée LIFT voxels plus haut (redescendue à l'export),
    inclinée par la rotation de repos de son os autour de sa base."""
    top = surface_top(d, x, z, w) if top is None else top
    base = top - 1 + LIFT
    d.bone(name, (x + w / 2, top + 1 + LIFT, z + w / 2), rest=rest)
    for y in range(base, base + h + 2):
        for dx in range(w):
            for dz in range(w):
                d.set(name, x + dx, y, z + dz, body, mat)
    y = base + h + 2
    if w == 3:
        for dx, dz in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
            d.set(name, x + dx, y, z + dz, tip, mat)
        d.set(name, x + 1, y + 1, z + 1, tip, mat)
    else:
        d.set(name, x, y, z, tip, mat)


def build(rarity):
    look = LOOKS[rarity]
    d = Dino("Block" + rarity, "Block", voxel=VOXEL, display=rarity + " Fossil")
    center = (N / 2, N / 2, N / 2)
    for role in ("Rock", "Fossil", "Glow", "Rainbow"):
        d.bone(role, center)

    secret = rarity == "Secret"
    rock = look["rock"]
    soil = shade(rock, -0.22) if rock else None

    # roche : couleur de la rareté, bas un peu plus sombre (terre, lave pour le Mythic) ; Secret : couches
    # arc-en-ciel (rôle Rainbow)
    for (x, y, z) in ROCK:
        if secret:
            d.set("Rainbow", x, y, z, RAINBOW[min(len(RAINBOW) - 1, y * len(RAINBOW) // N)])
        elif y <= 1 and look.get("lava"):
            d.set("Glow", x, y, z, look["lava"], "Neon")
        else:
            d.set("Rock", x, y, z, soil if y <= 1 else rock)

    # os en relief
    for face, art in FACE_ART.items():
        for (c, r), ch in art_cells(art).items():
            if ch == "#":
                d.set("Fossil", *face_cell(face, c, r, -1), look["bone"], look["bone_mat"])

    # cristaux (Secret : chacun d'une couleur de l'arc-en-ciel ; en jeu, elles tournent)
    k = 0
    for group in GEM_SETS.get(look["gems"], []):
        for (gx, gz, h, w, rx, rz) in GEMS[group]:
            k += 1
            body = look["gem"] or RAINBOW[(k - 1) % len(RAINBOW)]
            standing(d, "Gem%d" % k, gx, gz, w, h, (rx, 0, rz), body, shade(body, 0.3), look["gem_mat"])
    return d


# ---------------------------------------------------------------------- décor de chaque biome
SAND = (226, 206, 150)


def relief(d, face, cells, color, mat="Plastic", role="Biome"):
    """Cases en relief (un voxel au-dessus de la face) ; une case déjà prise par la roche n'est pas posée."""
    for c, r in cells:
        cell = face_cell(face, c, r, -1)
        if cell not in ROCK:
            d.set(role, *cell, color, mat)


def skirt(d, height, color, mat="Plastic"):
    """Bourrelet en escalier autour du pied du bloc (sable, boue, neige...) : la couche du bas déborde d'un voxel,
    chaque couche suivante est un carré plus étroit ; la roche est retirée du carré (peu de pièces : 4 par couche)."""
    for y in range(height):
        lo, hi = y - 1, N - y
        for x in range(lo, hi + 1):
            for z in range(lo, hi + 1):
                if (x, y, z) not in ROCK:
                    d.set("Biome", x, y, z, color, mat)


def on_top(d, cells, color, mat="Plastic", height=1, role="Biome"):
    """Plaque posée sur le dessus (cases (x, z)), sur `height` voxels."""
    for x, z in cells:
        top = surface_top(d, x, z, 1)
        for y in range(top + 1, top + 1 + height):
            d.set(role, x, y, z, color, mat)


def rect(x0, z0, x1, z1):
    return [(x, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)]


def art(rows, col0, top, ch="#"):
    return [k for k, v in art_cells((rows, col0, top)).items() if v == ch]


def biome_beach(d):
    skirt(d, 2, SAND)
    # étoile de mer sur l'arrière
    star = ["...#...",
            "...#...",
            "#######",
            ".#####.",
            "..###..",
            ".##.##.",
            ".#...#."]
    relief(d, "back", art(star, 5, 11), (240, 140, 80))
    # galets clairs sur le dessus, à l'arrière
    on_top(d, rect(7, 11, 8, 12), (232, 224, 206))
    on_top(d, [(10, 13)], (214, 204, 186))


def biome_fern(d):
    moss = (86, 150, 60)
    on_top(d, rect(4, 10, 9, 14) + rect(10, 12, 12, 14), moss)
    # mousse qui coule sur l'arrière
    relief(d, "back", [(c, 14) for c in range(3, 14)] + [(4, 13), (5, 13), (10, 13), (11, 13)], moss)
    # fougère fossile en relief sur l'arrière (nervure et folioles)
    frond = ["...#...",
             "..#.#..",
             ".#.#.#.",
             "#..#..#",
             ".#.#.#.",
             "#..#..#",
             "...#...",
             "...#..."]
    relief(d, "back", art(frond, 5, 11), (52, 104, 44))
    # pousse de fougère sur le dessus : trois feuilles inclinées
    for k, (x, z, rx, rz) in enumerate([(7, 12, 28, 0), (6, 12, -6, 30), (8, 12, -6, -30)]):
        leaf = "Deco%d" % (k + 1)
        top = surface_top(d, x, z, 1) + 1  # sur la mousse
        base = top + 1 + LIFT
        d.bone(leaf, (x + 0.5, base, z + 0.5), rest=(rx, 0, rz))
        for y in range(base - 1, base + 5):
            d.set(leaf, x, y, z, (70, 150, 56))
        d.set(leaf, x, base + 2, z - 1, (104, 186, 78))
        d.set(leaf, x, base + 2, z + 1, (104, 186, 78))


def biome_swamp(d):
    mud = (88, 74, 48)
    skirt(d, 2, mud)
    # coulures de boue sur l'arrière et la liane qui pend
    relief(d, "back", [(3, 2), (3, 3), (6, 2), (10, 2), (10, 3), (10, 4), (14, 2)], mud)
    vine = (72, 128, 52)
    relief(d, "back", [(12, r) for r in range(7, 15)] + [(11, 12), (13, 10), (11, 8)], vine)
    # nénuphar et sa fleur sur le dessus
    on_top(d, rect(6, 11, 10, 13) + [(7, 10), (8, 10), (9, 10), (7, 14), (8, 14)], (70, 150, 72))
    on_top(d, [(8, 12)], (236, 124, 172), height=2)


def biome_canyon(d):
    for row, col in ((2, (184, 92, 58)), (14, (214, 138, 86))):
        for face in ("front", "back", "left", "right"):
            relief(d, face, [(c, row) for c in range(2, 15)], col)
    relief(d, "back", [(c, 8) for c in range(2, 15)], (196, 110, 70))
    # cailloux sur le dessus
    on_top(d, rect(7, 12, 8, 13), (170, 88, 56), height=2)
    on_top(d, [(10, 13), (10, 14)], (206, 128, 82))


def biome_glacier(d):
    ice = (196, 232, 255)
    # calotte de glace sur la moitié arrière du dessus
    on_top(d, rect(2, 9, 14, 14), ice, "Ice", height=2)
    # stalactites de glace sur l'arrière
    for c, length in ((3, 3), (6, 2), (9, 4), (12, 2)):
        relief(d, "back", [(c, 14 - k) for k in range(length)], ice, "Ice")
    skirt(d, 1, (244, 250, 255))


def biome_volcano(d):
    basalt = (44, 38, 40)
    skirt(d, 2, basalt)
    # croûte noire et braises
    relief(d, "back", [(c, r) for c in range(2, 15) for r in (2, 3)], basalt)
    relief(d, "back", [(4, 6), (11, 9), (7, 12)], (255, 112, 40), "Neon", role="Ember")
    on_top(d, rect(6, 10, 10, 14), (110, 104, 104))
    on_top(d, [(8, 12), (9, 13)], (255, 112, 40), "Neon", role="Ember")


def biome_ocean(d):
    skirt(d, 1, (214, 196, 150))
    # bernacles sur le bas des faces
    for face in ("front", "back", "left", "right"):
        relief(d, face, [(4, 2), (5, 2), (11, 3), (12, 3)], (210, 214, 218))
    # algues sur l'arrière
    weed = (60, 150, 92)
    relief(d, "back", [(3, r) for r in range(1, 10)] + [(4, 10), (4, 11), (14, 1), (14, 2), (14, 3), (13, 4), (13, 5)],
           weed)
    # coraux sur le dessus
    for x, z, h, col in ((7, 12, 4, (244, 108, 140)), (10, 13, 3, (250, 150, 70))):
        top = surface_top(d, x, z, 1)
        for y in range(top + 1, top + 1 + h):
            d.set("Biome", x, y, z, col)
        d.set("Biome", x - 1, top + h - 1, z, col)
        d.set("Biome", x + 1, top + h - 2, z, col)


def biome_meteor(d):
    rock = (56, 50, 70)
    skirt(d, 1, (70, 62, 84))
    # éclats de météorite sur le dessus et leurs cristaux violets
    on_top(d, rect(7, 11, 9, 13), rock, height=2)
    for k, (x, z, h, rest) in enumerate([(8, 12, 4, (6, 0, 4)), (7, 11, 2, (-24, 0, 26)), (9, 13, 2, (26, 0, -24))]):
        standing(d, "Deco%d" % (k + 1), x, z, 1, h, rest, (170, 110, 255), (220, 180, 255), "Neon", top=N + 1)
    relief(d, "back", [(4, 3), (5, 3), (4, 4), (11, 2), (12, 2), (12, 3)], rock)
    # petites étoiles qui brillent
    relief(d, "back", [(8, 7), (13, 11), (3, 12)], (255, 230, 120), "Neon")


BIOME_BUILD = {
    "Beach": biome_beach,
    "Fern Forest": biome_fern,
    "Swamp": biome_swamp,
    "Canyon": biome_canyon,
    "Glacier": biome_glacier,
    "Volcano": biome_volcano,
    "Ocean Trench": biome_ocean,
    "Meteor Crater": biome_meteor,
}


def build_biome(zone):
    d = Dino("Biome" + zone.replace(" ", ""), "Block", voxel=VOXEL, display=zone)
    center = (N / 2, N / 2, N / 2)
    for role in ("Biome", "Ember"):
        d.bone(role, center)
    BIOME_BUILD[zone](d)
    return d


# ---------------------------------------------------------------------- export

def export(d):
    """Modèle en studs, centré sur le centre du bloc : os (rôles) avec pivot et rotation de repos, boîtes fusionnées."""
    v = d.voxel
    o = N / 2  # centre de la grille (bords compris)

    def lift(bone):
        return LIFT if bone.startswith(("Gem", "Deco")) else 0

    boxes = []
    for bone, color, material, a, b in d.merged():
        a = [a[0], a[1] - lift(bone), a[2]]
        b = [b[0], b[1] - lift(bone), b[2]]
        c = [((a[i] + b[i] + 1) / 2 - o) * v for i in range(3)]
        s = [(b[i] - a[i] + 1) * v for i in range(3)]
        boxes.append({"bone": bone, "c": c, "s": s, "col": list(color), "mat": material, "a": a, "b": b})
    bones = []
    for name, info in d.bones.items():
        if not any(bx["bone"] == name for bx in boxes):
            continue
        p = list(info["pivot"])
        p[1] -= lift(name)
        bones.append({"name": name, "parent": None, "pivot": [(p[i] - o) * v for i in range(3)],
                      "rest": list(info["rest"]) if info["rest"] else None})
    return {
        "name": d.name,
        "display": d.display,
        "voxel": v,
        "origin": [o, o, o],
        "size": [N * v] * 3,
        "height": N * v,
        "bones": bones,
        "boxes": boxes,
        "voxels": len(d.vox),
    }


def models():
    return {r: export(build(r)) for r in RARITIES}


def biomes():
    return {z: export(build_biome(z)) for z in BIOMES}


if __name__ == "__main__":
    from collections import Counter

    def roles(m):
        c = Counter("Gem" if b["bone"].startswith("Gem") else "Deco" if b["bone"].startswith("Deco") else b["bone"]
                    for b in m["boxes"])
        return dict(c)
    for r, m in models().items():
        print("%-14s %3d pièces  %s" % (r, len(m["boxes"]), roles(m)))
    for z, m in biomes().items():
        print("%-14s %3d pièces  %s" % (z, len(m["boxes"]), roles(m)))
