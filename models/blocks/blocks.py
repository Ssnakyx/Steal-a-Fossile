"""Blocs de fossiles de Steal a Fossil (brief 9) : un bloc de roche voxel par rareté, avec un squelette incrusté.

Le bloc montre seulement sa rareté (GDD : « le bloc montre sa rareté, l'espèce est une surprise ») : le squelette est
le même pour toutes les raretés, la couleur de la roche donne la rareté (Config.Rarity.Info) et les raretés hautes
ajoutent des cristaux de plus en plus nombreux, des os en or (Legendary), une base de lave (Mythic) ou des couches
arc-en-ciel (Secret). Les effets animés (cubes qui montent, aura, arc-en-ciel qui tourne...) sont joués en jeu par
FossilBlockController.

Grille de 17 x 17 x 17 voxels de 3/17 de stud : un bloc de 3 studs, la taille de la pièce FossilBlock du serveur.
Repère du jeu : X droite, Y haut, l'avant du bloc regarde vers -Z. Cases entières de 0 à 16 ; le centre du bloc est
le centre de la grille. Os en relief (un voxel au-dessus de la roche), vus de l'extérieur de chaque face :
  avant (-Z)  crâne de profil, dents et orbites        droite (+X)  colonne vertébrale et côtes
  gauche (-X) queue en vertèbres à épines              arrière (+Z) roche nue
  dessus      studs en jeu, cristaux sur la moitié avant (le bloc porté est tourné : ils s'éloignent du joueur)

Os du modèle = rôle des briques en jeu (BlockModels, FossilBlockController) :
  Rock    roche          Fossil   os                    Glow   bande de lave Neon du Mythic (bat en jeu)
  Rainbow couches arc-en-ciel du Secret (leur couleur tourne en jeu)
  Gem1..n cristaux, chacun incliné par la rotation de repos de son os (pivot à sa base, au ras de la roche)
Formes sûres pour la modération : os en segments carrés épais, vertèbres en blocs, pas de « tube + boule », pas de
sphères par paires. Peu de pièces : la roche est un cube biseauté de 4 boîtes que rien ne découpe (os et cristaux
sont posés dessus)."""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import vox  # noqa: E402
from vox import Dino, shade  # noqa: E402

# Le Neon et l'Ice sont opaques en jeu : leurs cases cachées servent de jokers à la fusion des voxels (un cristal
# épais reste une seule pièce). Le verre (Glass) reste transparent. « Gold » : os en or (BlockModels lui donne sa
# matière et son reflet en jeu). Ne concerne que ce processus.
vox.OPAQUE = ("Plastic", "Smooth", "Metal", "Neon", "Ice", "Gold")
vox.MATERIALS = vox.MATERIALS + ("Gold",)

N = 17  # voxels par côté
SIZE = 3.0  # studs
VOXEL = SIZE / N
GEM_LIFT = 40  # voxels : les cristaux sont modélisés au-dessus de la roche, puis redescendus à l'export

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]

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

# couches du Secret, du bas vers le haut (en jeu, leurs couleurs tournent)
RAINBOW = [(236, 56, 64), (255, 170, 40), (80, 200, 90), (60, 140, 240), (170, 90, 235)]

BONE = (238, 228, 200)
GOLD = (255, 208, 64)
PEARL = (250, 248, 255)

# ---------------------------------------------------------------------- look de chaque rareté
# rock : roche ; bone, bone_mat : os (Gold : or brillant en jeu) ; gems : grappes de cristaux (GEM_SETS) ;
# gem, gem_mat : cristaux ; lava : bande du bas en lave Neon (Mythic)
LOOKS = {
    "Common": {"rock": (150, 149, 152), "bone": BONE, "bone_mat": "Plastic", "gems": 0},
    "Uncommon": {"rock": (66, 160, 66), "bone": BONE, "bone_mat": "Plastic",
                 "gems": 1, "gem": (150, 226, 108), "gem_mat": "Plastic"},
    "Rare": {"rock": (32, 102, 204), "bone": BONE, "bone_mat": "Plastic",
             "gems": 2, "gem": (140, 205, 255), "gem_mat": "Ice"},
    "Epic": {"rock": (124, 54, 192), "bone": BONE, "bone_mat": "Plastic",
             "gems": 3, "gem": (176, 84, 255), "gem_mat": "Neon"},
    "Legendary": {"rock": (226, 112, 12), "bone": GOLD, "bone_mat": "Gold",
                  "gems": 4, "gem": (255, 196, 30), "gem_mat": "Neon"},
    "Mythic": {"rock": (150, 22, 26), "bone": BONE, "bone_mat": "Plastic",
               "gems": 4, "gem": (255, 74, 30), "gem_mat": "Neon", "lava": (255, 106, 30)},
    "Secret": {"rock": None, "bone": PEARL, "bone_mat": "Smooth",
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
    if face == "top":  # vu d'en haut, l'avant en bas
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
    "back": [(12, 12, 3, 2, 14, -16), (4, 12, 4, 2, 16, 14)],
}
# grappes selon le nombre de « gems » de la rareté
GEM_SETS = {1: ["small"], 2: ["left"], 3: ["left", "right"], 4: ["left", "right", "middle"],
            5: ["left", "right", "middle", "back"]}


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
    for (x, y, z) in rock_cells():
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

    # cristaux : modélisés droits plus haut dans la grille (GEM_LIFT voxels au-dessus, rien ne s'y chevauche), puis
    # redescendus par export() et inclinés par la rotation de repos de leur os, pivot au ras de la roche. Leur base
    # descend de deux voxels sous la surface : inclinés, ils ne laissent pas de jour avec la roche.
    k = 0
    for group in GEM_SETS.get(look["gems"], []):
        for (gx, gz, h, w, rx, rz) in GEMS[group]:
            k += 1
            name = "Gem%d" % k
            top = surface_top(d, gx, gz, w)
            base = top - 1 + GEM_LIFT
            d.bone(name, (gx + w / 2, top + 1 + GEM_LIFT, gz + w / 2), rest=(rx, 0, rz))
            # (Secret : chaque cristal d'une couleur de l'arc-en-ciel ; en jeu, elles tournent)
            body = look["gem"] or RAINBOW[(k - 1) % len(RAINBOW)]
            tip = shade(body, 0.3)
            for y in range(base, base + h + 2):
                for dx in range(w):
                    for dz in range(w):
                        d.set(name, gx + dx, y, gz + dz, body, look["gem_mat"])
            y = base + h + 2
            if w == 3:
                for dx, dz in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
                    d.set(name, gx + dx, y, gz + dz, tip, look["gem_mat"])
                d.set(name, gx + 1, y + 1, gz + 1, tip, look["gem_mat"])
            else:
                d.set(name, gx, y, gz, tip, look["gem_mat"])
    return d


def surface_top(d, gx, gz, w):
    """Plus haute case de roche sous la base d'un cristal."""
    tops = []
    for dx in range(w):
        for dz in range(w):
            ys = [y for (x, y, z), v in d.vox.items() if x == gx + dx and z == gz + dz and not v[0].startswith("Gem")]
            if ys:
                tops.append(max(ys))
    return min(tops) if tops else N - 1


def export(d):
    """Modèle en studs, centré sur le centre du bloc : os (rôles) avec pivot et rotation de repos, boîtes fusionnées."""
    v = d.voxel
    o = N / 2  # centre de la grille (bords compris)

    def lift(bone):
        return GEM_LIFT if bone.startswith("Gem") else 0

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


if __name__ == "__main__":
    from collections import Counter
    for r, m in models().items():
        roles = Counter("Gem" if bx["bone"].startswith("Gem") else bx["bone"] for bx in m["boxes"])
        print("%-10s %4d voxels -> %3d pièces  %s" % (r, m["voxels"], len(m["boxes"]), dict(roles)))
