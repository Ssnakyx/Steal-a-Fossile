"""Blocs de fossiles de Steal a Fossil (brief 9) : un modèle voxel différent pour chaque biome et chaque rareté.

Le bloc montre sa rareté (GDD : « le bloc montre sa rareté, l'espèce est une surprise ») par sa couleur
(Config.Rarity.Info), et son biome par sa forme. Demande de Snaky (2026-10-11) : des formes différentes, aucun bloc
ne doit ressembler à un autre. Chaque biome a sa forme et son fossile en relief :
  Beach          ammonite (coquille en spirale dressée sur la tranche), à moitié dans le sable
  Fern Forest    souche pétrifiée : cernes sur le dessus, racines, fougère fossile, mousse et feuilles
  Swamp          butte de boue basse en terrasses : mâchoire de crocodile, nénuphar, coulures de boue
  Canyon         cheminée de fée : pied étroit, chapeau large en strates, colonne vertébrale
  Glacier        cristal de glace hexagonal à pointe : crâne pris dans la glace, éclats de glace, neige
  Volcano        volcan à cratère de lave : griffe fossile, coulée de lave, basalte
  Ocean Trench   coquille Saint-Jacques dressée : côtes fossiles qui dentellent le bord, bernacles, algues
  Meteor Crater  météorite bombée à cratères : cage thoracique, éclats violets plantés dedans
Chaque rareté change aussi la silhouette (en plus de la couleur, de la taille et des cristaux de plus en plus nombreux) :
  Common rien de plus ; Uncommon deux pousses ; Rare cristaux de verre ; Epic fendu en V, coeur violet qui brille ;
  Legendary os en or posé sur un socle d'or ; Mythic fissures de lave et trois morceaux qui flottent au-dessus ;
  Secret couches arc-en-ciel, en lévitation au-dessus d'un socle de pierres, éclats qui tournent autour.
Sans biome connu (vieille sauvegarde), le bloc est le cube biseauté du premier modèle (os sur trois faces).

Grille de 17 voxels de 3/17 de stud par côté : un bloc de 3 studs, la taille de la pièce FossilBlock du serveur. Repère
du jeu : X droite, Y haut, l'avant du bloc regarde vers -Z. Cases entières ; le bas du bloc est y = 0 (au sol), le
centre de la grille est le centre du modèle. Le Legendary et le Secret sont posés plus haut (socle, lévitation) et
dépassent un peu en haut.

Os du modèle = rôle des briques en jeu (BlockModels, FossilBlockController) :
  Rock    roche          Fossil  os en relief            Glow   coeur de l'Epic, fissures de lave du Mythic (battent)
  Rainbow couches du Secret (leur couleur tourne)         Base   socle d'or du Legendary, pierres sous le Secret
  Biome   décor du biome Ember   lave et lueurs fixes du décor
  Gem1..n cristaux de la rareté ; Deco1..n pièces inclinées du décor ; Float1..n morceaux qui flottent (Mythic) ;
  Orbit1..n éclats qui tournent autour (Secret) : chacun incliné par la rotation de repos de son os (pivot à sa base
  ou à son centre)
Formes sûres pour la modération : os en segments carrés épais, vertèbres en blocs, pas de « tube + boule », pas de
sphères par paires. Peu de pièces : formes en terrasses aux coins coupés (5 boîtes par étage), 115 pièces au plus."""
from __future__ import annotations

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import vox  # noqa: E402
from vox import Dino, mix, shade  # noqa: E402

# Pour la fusion des voxels, toutes les matières des blocs comptent comme opaques : les cases cachées d'un cristal
# épais (même en verre) servent de jokers et il reste une seule pièce. « Foil » : os en or du Legendary (comparé dans
# Studio : le plastique doré à reflet virait au beige) et os nacrés du Secret (en Neon blanc, le halo du jeu effaçait
# le crâne). Ne concerne que ce processus.
vox.MATERIALS = vox.MATERIALS + ("Foil",)
vox.OPAQUE = vox.MATERIALS

N = 17  # voxels par côté
SIZE = 3.0  # studs
VOXEL = SIZE / N
LIFT = 40  # voxels : les pièces inclinées sont modélisées au-dessus du bloc, puis redescendues à l'export
C = 8  # case du milieu
BUDGET = 115  # pièces au plus par bloc

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
BIOMES = ["Beach", "Fern Forest", "Swamp", "Canyon", "Glacier", "Volcano", "Ocean Trench", "Meteor Crater"]

# taille en jeu par rapport à un bloc Common (demande de Snaky : les plus rares beaucoup plus gros)
SCALES = {"Common": 1.0, "Uncommon": 1.06, "Rare": 1.14, "Epic": 1.24, "Legendary": 1.38, "Mythic": 1.55,
          "Secret": 1.8}

# couches du Secret, du bas vers le haut (en jeu, leurs couleurs tournent)
RAINBOW = [(236, 56, 64), (255, 170, 40), (80, 200, 90), (60, 140, 240), (170, 90, 235)]

BONE = (238, 228, 200)
GOLD = (255, 200, 50)
PEARL = (250, 248, 255)

# ---------------------------------------------------------------------- look de chaque rareté
# rock : roche (couleur de Config.Rarity, un peu plus sombre) ; bone, bone_mat : os ; gems : nombre de cristaux ;
# gem, gem_mat : cristaux (pousses en plastique, verre pour Rare et Epic, Neon qui brille ensuite) ; lift : le bloc est
# posé plus haut (socle du Legendary, lévitation du Secret)
LOOKS = {
    "Common": {"rock": (150, 149, 152), "bone": BONE, "bone_mat": "Plastic", "gems": 0},
    "Uncommon": {"rock": (66, 160, 66), "bone": BONE, "bone_mat": "Plastic",
                 "gems": 2, "gem": (150, 226, 108), "gem_mat": "Plastic"},
    "Rare": {"rock": (32, 102, 204), "bone": BONE, "bone_mat": "Plastic",
             "gems": 3, "gem": (120, 200, 255), "gem_mat": "Glass"},
    "Epic": {"rock": (124, 54, 192), "bone": BONE, "bone_mat": "Plastic",
             "gems": 4, "gem": (190, 120, 255), "gem_mat": "Glass", "core": (214, 150, 255)},
    "Legendary": {"rock": (226, 112, 12), "bone": GOLD, "bone_mat": "Foil",
                  "gems": 5, "gem": (255, 196, 30), "gem_mat": "Neon", "lift": 1},
    "Mythic": {"rock": (150, 22, 26), "bone": BONE, "bone_mat": "Plastic",
               "gems": 5, "gem": (255, 74, 30), "gem_mat": "Neon", "lava": (255, 106, 30)},
    "Secret": {"rock": None, "bone": PEARL, "bone_mat": "Foil",
               "gems": 6, "gem": None, "gem_mat": "Neon", "lift": 4},
}

# ---------------------------------------------------------------------- dessins des fossiles en relief
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
SMALL_SKULL = [  # crâne plus petit (face étroite du cristal de glace)
    "...#####.",
    ".########",
    "####.#..#",
    "####.#..#",
    "#########",
    "#.#.#.###",
    ".......##",
    ".#######.",
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
FERN = [  # fronde de fougère fossile : nervure et folioles
    "...#...",
    "..###..",
    ".#.#.#.",
    "#..#..#",
    ".#.#.#.",
    "#..#..#",
    ".#.#.#.",
    "...#...",
    "...#...",
]
JAW = [  # mâchoire de crocodile de profil, dents qui se croisent
    "......####...",
    "..##########.",
    "#############",
    "#.#.#.#.#.#.#",
    ".#.#.#.#.#.#.",
    "############.",
]
SPINE = [  # colonne de vertèbres
    ".###.",
    "##.##",
    ".###.",
    "..#..",
    ".###.",
    "##.##",
    ".###.",
    "..#..",
    ".###.",
]
CLAW = [  # trois griffes recourbées
    "#...#...#",
    "#...#...#",
    "##..#..##",
    ".#######.",
    "..#####..",
]
STAR = [  # étoile de mer (décor de la plage)
    "...#...",
    "...#...",
    "#######",
    ".#####.",
    "..###..",
    ".##.##.",
    ".#...#.",
]
CRACK = [  # fissure de lave du Mythic
    "..#..",
    "..#..",
    ".#...",
    ".#...",
    "..#..",
    "...#.",
    "...#.",
    "..#..",
    ".#...",
]


def art_cells(rows, col0, top):
    """[(colonne, ligne)] des cases '#' d'un dessin dont le coin haut gauche est (col0, top)."""
    out = []
    for i, line in enumerate(rows):
        for j, ch in enumerate(line):
            if ch == "#":
                out.append((col0 + j, top - i))
    return out


def centered(rows, col, row):
    """Coin haut gauche d'un dessin centré sur (colonne, ligne)."""
    return col - (len(rows[0]) - 1) // 2, row + (len(rows) - 1) // 2


# ---------------------------------------------------------------------- formes
def cuboid(x0, y0, z0, x1, y1, z1):
    return {(x, y, z) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1) for z in range(z0, z1 + 1)}


def chamfer(cx, cz, rx, rz, k=2):
    """Empreinte (x, z) d'un rectangle de demi-côtés rx, rz centré sur (cx, cz), coins coupés en escalier (k marches)."""
    out = set()
    for x in range(cx - rx, cx + rx + 1):
        for z in range(cz - rz, cz + rz + 1):
            ex, ez = abs(x - cx) - (rx - k), abs(z - cz) - (rz - k)
            if ex > 0 and ez > 0 and ex + ez > k:
                continue
            out.add((x, z))
    return out


def prism(foot, y0, y1):
    return {(x, y, z) for (x, z) in foot for y in range(y0, y1 + 1)}


class Form:
    """Forme d'un biome : cases de roche, pièces inclinées, teintes, fossile en relief et décor."""

    def __init__(self, name, cells):
        self.name = name
        self.cells = set(cells)
        self.tones = {}  # case -> éclaircissement (+) ou assombrissement (-) de la couleur de la rareté
        self.material = "Plastic"
        self.tint = 0.0  # mélange de la couleur de la rareté avec du blanc (glace)
        self.art = []  # (dessin, face, colonne du centre, ligne du centre)
        self.cracks = []  # (face, colonne, ligne) : fissures de lave du Mythic
        self.decor = None  # fn(d, form, ground)
        self.layers = None  # premières lignes des 5 couches du Secret (étages de la forme : peu de pièces en plus)
        # pièces inclinées (une seule brique chacune) : (rôle, centre, taille, rotation, teinte, bout) ; rôle "Rock"
        # (couleur de la rareté) ou "Fossil" (couleur des os) ; bout : (teinte, hauteur) d'une case plus claire en haut
        self.pieces = []
        self.lift = 0

    def shift(self, dy):
        """Monte la forme de dy voxels (socle du Legendary, lévitation du Secret)."""
        self.lift = dy
        self.cells = {(x, y + dy, z) for (x, y, z) in self.cells}
        self.tones = {(x, y + dy, z): t for (x, y, z), t in self.tones.items()}
        self.art = [(rows, face, col, row + dy) for rows, face, col, row in self.art]
        self.cracks = [(face, col, row + dy) for face, col, row in self.cracks]
        if self.layers:
            self.layers = [y + dy for y in self.layers]
        self.pieces = [(role, (c[0], c[1] + dy, c[2]), size, rest, tone, tip)
                       for role, c, size, rest, tone, tip in self.pieces]

    def top(self, x, z):
        ys = [y for (cx, y, cz) in self.cells if cx == x and cz == z]
        return max(ys) if ys else None

    def bbox(self):
        xs = [c[0] for c in self.cells]
        ys = [c[1] for c in self.cells]
        zs = [c[2] for c in self.cells]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def form_ammonite():
    """Beach : ammonite dressée sur la tranche (disque de face), plus épaisse au centre."""
    cells = set()
    for x in range(N):
        for y in range(N):
            r = math.hypot(x - C, y - C)
            if r <= 8.45:
                z0, z1 = (4, 12) if r <= 6.2 else (5, 11)
                cells |= {(x, y, z) for z in range(z0, z1 + 1)}
    f = Form("Ammonite", cells)
    # spirale de la coquille (le fossile) sur l'avant ; l'étoile de mer du décor est derrière
    f.art = [("spiral", "front", 0, 0)]
    f.cracks = [("left", 8, 9), ("right", 8, 7)]
    f.decor = decor_beach
    return f


def spiral_cells():
    """Spirale d'ammonite (coordonnées x, y de la grille) : deux tours, du centre vers le bord du disque épais."""
    out = set()
    turns = 2.0
    for i in range(1400):
        t = i / 1399 * turns * 2 * math.pi
        r = 1.0 + 5.2 * t / (turns * 2 * math.pi)
        out.add((round(C + r * math.cos(t + 0.6)), round(C + r * math.sin(t + 0.6))))
    return out


def form_stump():
    """Fern Forest : souche pétrifiée octogonale, plus large que haute : cernes sur le dessus, bord déchiqueté
    (échardes d'écorce), quatre racines en contreforts au pied."""
    cells = prism(chamfer(C, C, 6, 6, 3), 0, 9)
    # racines : un contrefort au milieu de chaque côté, en deux marches
    cells |= cuboid(15, 0, 6, 16, 1, 9) | cuboid(15, 2, 7, 15, 3, 8)
    cells |= cuboid(0, 0, 7, 1, 1, 10) | cuboid(1, 2, 8, 1, 3, 9)
    cells |= cuboid(9, 0, 15, 12, 1, 16) | cuboid(10, 2, 15, 11, 3, 15)
    cells |= cuboid(3, 0, 0, 5, 1, 1) | cuboid(4, 2, 1, 4, 2, 1)
    # échardes d'écorce qui dépassent du bord du dessus
    for x, z, h in ((2, 6, 2), (4, 3, 1), (13, 4, 2), (14, 10, 1), (9, 14, 2), (5, 13, 1)):
        cells |= cuboid(x, 10, z, x, 9 + h, z)
    f = Form("Stump", cells)
    for (x, y, z) in cells:
        if y == 9:
            d = max(abs(x - C), abs(z - C))
            f.tones[(x, y, z)] = -0.28 if d >= 5 else 0.16 if d >= 3 else -0.08 if d >= 1 else 0.16
    f.art = [(FERN, "front", 8, 5)]
    f.cracks = [("left", 7, 6), ("right", 7, 6)]
    f.layers = [0, 2, 4, 6, 8]
    f.decor = decor_fern
    return f


def form_mound():
    """Swamp : butte de boue basse et large, en terrasses qui reculent surtout vers l'arrière, roseaux."""
    cells = prism(chamfer(C, 9, 8, 8, 3), 0, 3) | prism(chamfer(C, 9, 7, 7, 2), 4, 6) \
        | prism(chamfer(C, 10, 5, 4, 2), 7, 8)
    cells |= cuboid(10, 9, 10, 12, 9, 12)  # bosse sur le dessus
    f = Form("Mound", cells)
    f.art = [(JAW, "front", 8, 3)]
    f.cracks = [("left", 9, 3), ("right", 9, 3)]
    f.layers = [0, 2, 4, 7, 9]
    f.decor = decor_swamp
    return f


def form_hoodoo():
    """Canyon : cheminée de fée, pied large et bas, colonne étroite et haute, chapeau très large et mince."""
    cells = prism(chamfer(C, C, 6, 6, 2), 0, 1) | prism(chamfer(C, C, 3, 3, 1), 2, 10) \
        | prism(chamfer(C, C, 8, 7, 3), 11, 12) | prism(chamfer(C, C, 5, 4, 2), 13, 14)
    f = Form("Hoodoo", cells)
    for (x, y, z) in cells:
        if y in (4, 8, 12):
            f.tones[(x, y, z)] = -0.2
        elif y == 14:
            f.tones[(x, y, z)] = 0.12
    f.art = [(SPINE, "front", 8, 6)]
    f.cracks = [("left", 8, 11), ("right", 8, 11)]
    f.layers = [0, 2, 6, 11, 13]
    f.decor = decor_canyon
    return f


def form_crystal():
    """Glacier : grappe de cristaux de glace : une colonne hexagonale à pointe (crâne pris dans la glace, face avant
    plate) et trois cristaux plus petits penchés autour."""
    cells = set()

    def width(z):
        return 6 - max(0, abs(z - C) - 2)

    for z in range(4, 13):
        for x in range(C - width(z), C + width(z) + 1):
            for y in range(0, 12):
                cells.add((x, y, z))
    for y, cut in ((12, 1), (13, 2), (14, 3), (15, 4), (16, 5)):
        for z in range(4 + cut // 2, 13 - cut // 2):
            w = width(z) - cut
            for x in range(C - w, C + w + 1):
                cells.add((x, y, z))
    f = Form("Crystal", cells)
    f.material = "Ice"
    f.tint = 0.25
    f.art = [(SMALL_SKULL, "front", 8, 6)]
    f.cracks = [("left", 8, 6), ("right", 8, 6)]
    f.layers = [0, 3, 6, 9, 12]
    f.pieces = [("Rock", (2.5, 5.0, 10.5), (3, 10, 3), (8, 0, 24), 0.08, (0.3, 1)),
                ("Rock", (14.5, 4.0, 6.5), (3, 8, 3), (-10, 0, -26), 0.08, (0.3, 1)),
                ("Rock", (11.5, 2.5, 13.5), (2, 5, 2), (30, 0, -10), 0.0, (0.3, 1))]
    f.decor = decor_glacier
    return f


def form_volcano():
    """Volcano : cône en terrasses, cratère creux plein de lave au sommet."""
    cells = prism(chamfer(C, C, 7, 7, 2), 0, 3) | prism(chamfer(C, C, 5, 5, 2), 4, 7) \
        | prism(chamfer(C, C, 4, 4, 1), 8, 10) | prism(chamfer(C, C, 3, 3, 1), 11, 13)
    cells -= prism(chamfer(C, C, 1, 1, 0), 12, 13)  # cratère
    f = Form("Volcano", cells)
    f.art = [(CLAW, "front", 8, 2)]
    f.cracks = [("left", 8, 6), ("right", 8, 6)]
    f.layers = [0, 4, 8, 11, 12]
    f.decor = decor_volcano
    return f


def form_scallop():
    """Ocean Trench : coquille Saint-Jacques dressée sur sa charnière : éventail rond en haut, pointe en bas,
    oreillettes à la charnière, côtes fossiles qui rayonnent et dentellent le bord."""
    cells = set()
    hinge = (C + 0.5, 0.5)

    def inside(x, y):
        if y >= 6:
            return (x - C) ** 2 + (y - 6) ** 2 <= 8.6 ** 2
        return abs(x - C) <= 2 + y

    for x in range(N):
        for y in range(0, 15):
            if inside(x, y):
                for z in range(5, 12):
                    cells.add((x, y, z))
    cells |= cuboid(3, 0, 6, 13, 2, 10)  # oreillettes de la charnière
    f = Form("Scallop", cells)
    # côtes : une brique par côte, de la charnière jusqu'un peu au-delà du bord
    for phi in (-64, -43, -21, 0, 21, 43, 64):
        a = math.radians(phi)
        length = 2.0
        while inside(hinge[0] + math.sin(a) * length - 0.5, hinge[1] + math.cos(a) * length - 0.5):
            length += 0.5
        length = round(length + 1.0)
        cx = hinge[0] + math.sin(a) * length / 2
        cy = hinge[1] + math.cos(a) * length / 2
        f.pieces.append(("Fossil", (cx, cy, 4.5), (1, length, 1), (0, 0, -phi), 0.0, None))
    f.cracks = [("left", 8, 10), ("right", 8, 10)]
    f.layers = [0, 4, 7, 10, 13]
    f.decor = decor_ocean
    return f


def form_meteorite():
    """Meteor Crater : météorite bosselée dans son cratère : un bloc rond et trois gros morceaux de roche penchés
    qui le déforment, un creux sur le dessus."""
    cells = prism(chamfer(C, C, 5, 5, 2), 0, 0) | prism(chamfer(C, C, 6, 6, 2), 1, 10) \
        | prism(chamfer(C, C, 4, 4, 1), 11, 12)
    cells -= cuboid(7, 12, 6, 9, 12, 8)  # creux d'impact sur le dessus
    f = Form("Meteorite", cells)
    f.art = [(RIBS, "front", 8, 6)]
    f.cracks = [("left", 8, 7), ("back", 11, 8)]
    f.layers = [0, 3, 6, 9, 11]
    f.pieces = [("Rock", (3.0, 6.5, 10.0), (5, 7, 6), (10, 25, 18), -0.06, None),
                ("Rock", (13.5, 8.0, 10.5), (5, 6, 6), (-15, 30, -20), 0.05, None),
                ("Rock", (9.5, 12.5, 11.5), (6, 4, 5), (12, 15, 8), -0.1, None)]
    f.decor = decor_meteor
    return f


def form_cube():
    """Sans biome : cube aux arêtes biseautées en deux marches (union de 4 boîtes), os sur trois faces."""
    m = N - 1
    cells = cuboid(0, 2, 2, m, m - 2, m - 2) | cuboid(2, 0, 2, m - 2, m, m - 2) | cuboid(2, 2, 0, m - 2, m - 2, m) \
        | cuboid(1, 1, 1, m - 1, m - 1, m - 1)
    f = Form("Block", cells)
    f.art = [(SKULL, "front", 8, 8), (RIBS, "right", 8, 8), (TAIL, "left", 8, 8)]
    f.cracks = [("back", 8, 8)]
    return f


FORMS = {
    "Beach": form_ammonite,
    "Fern Forest": form_stump,
    "Swamp": form_mound,
    "Canyon": form_hoodoo,
    "Glacier": form_crystal,
    "Volcano": form_volcano,
    "Ocean Trench": form_scallop,
    "Meteor Crater": form_meteorite,
}


# ---------------------------------------------------------------------- surface
def ray(face, col, row):
    """Colonne de cases traversée par un point (colonne, ligne) d'une face vue de l'extérieur, de l'extérieur vers
    l'intérieur : (fonction case(profondeur), axe, sens)."""
    if face == "front":  # -Z : la droite de celui qui regarde est -X
        return lambda k: (N - 1 - col, row, k)
    if face == "back":  # +Z : la droite est +X
        return lambda k: (col, row, N - 1 - k)
    if face == "right":  # +X : la droite est -Z
        return lambda k: (N - 1 - k, row, N - 1 - col)
    if face == "left":  # -X : la droite est +Z
        return lambda k: (k, row, col)
    raise ValueError(face)


def surface(cells, face, col, row):
    """(case de surface, case juste devant) d'un point d'une face, ou (None, None) si la forme n'y est pas."""
    at = ray(face, col, row)
    for k in range(-6, N + 6):
        c = at(k)
        if c in cells:
            return c, at(k - 1)
    return None, None


def relief(d, form, face, points, color, mat="Plastic", role="Biome", taken=None):
    """Cases en relief (une case devant la surface) pour des points (colonne, ligne) d'une face."""
    for col, row in points:
        _, out = surface(form.cells, face, col, row)
        if out is not None and out not in form.cells and (taken is None or out not in taken):
            d.set(role, *out, color, mat)


def inlay(d, form, face, points, color, mat, role):
    """Cases de surface repeintes (fissures, coulées) : la forme ne change pas."""
    for col, row in points:
        c, _ = surface(form.cells, face, col, row)
        if c is not None:
            d.set(role, *c, color, mat)


def on_top(d, form, points, color, mat="Plastic", height=1, role="Biome"):
    """Plaque posée sur le dessus de la forme (points (x, z)), sur `height` voxels."""
    for x, z in points:
        top = form.top(x, z)
        if top is None:
            continue
        while (x, top + 1, z) in d.vox:
            top += 1
        for y in range(top + 1, top + 1 + height):
            d.set(role, x, y, z, color, mat)


def ring(form, y, grow, height=1):
    """Bourrelet autour du pied de la forme : rectangle de la base agrandi de `grow`, coins coupés, sans la forme."""
    base = [(x, z) for (x, yy, z) in form.cells if yy == form.lift]
    xs = [p[0] for p in base]
    zs = [p[1] for p in base]
    cx, cz = (min(xs) + max(xs)) // 2, (min(zs) + max(zs)) // 2
    rx, rz = (max(xs) - min(xs)) // 2 + grow, (max(zs) - min(zs)) // 2 + grow
    out = set()
    for k in range(height):
        foot = chamfer(cx, cz, rx - k, rz - k, 2)
        out |= {(x, y + k, z) for (x, z) in foot if (x, y + k, z) not in form.cells}
    return out


def rect(x0, z0, x1, z1):
    return [(x, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)]


def tilted(d, name, center, size, rest, color, mat="Plastic", tip=None):
    """Pièce inclinée (feuille, éclat, côte, morceau qui flotte) : boîte de `size` voxels centrée sur `center`,
    modélisée LIFT voxels plus haut, tournée par la rotation de repos de son os autour de son centre. tip : (couleur,
    matière[, hauteur]) d'un bout d'une case de large au-dessus."""
    cx, cy, cz = center
    sx, sy, sz = size
    x0, y0, z0 = round(cx - sx / 2), round(cy - sy / 2) + LIFT, round(cz - sz / 2)
    d.bone(name, (x0 + sx / 2, y0 + sy / 2, z0 + sz / 2), rest=rest)
    for x in range(x0, x0 + sx):
        for y in range(y0, y0 + sy):
            for z in range(z0, z0 + sz):
                d.set(name, x, y, z, color, mat)
    if tip:
        color2, mat2 = tip[0], tip[1]
        for k in range(tip[2] if len(tip) > 2 else 1):
            d.set(name, x0 + sx // 2, y0 + sy + k, z0 + sz // 2, color2, mat2)


def put(d, form, x, y, z, color, mat="Plastic", role="Biome"):
    """Case de décor, jamais à la place d'une case de la forme."""
    if (x, y, z) not in form.cells:
        d.set(role, x, y, z, color, mat)


# ---------------------------------------------------------------------- décors des biomes
SAND = (226, 206, 150)


def decor_beach(d, form, ground):
    if ground:
        for c in ring(form, form.lift, 2, 2):
            d.set("Biome", *c, SAND)
        for x, z in ((4, 3), (12, 13)):
            put(d, form, x, form.lift + 2, z, (232, 224, 206))
    # étoile de mer collée sur l'arrière de la coquille
    col0, top = centered(STAR, 8, form.lift + 6)
    relief(d, form, "back", art_cells(STAR, col0, top), (240, 140, 80), taken=d.vox)


def decor_fern(d, form, ground):
    moss = (86, 150, 60)
    y = form.lift + 9
    # mousse sur le bord du dessus et qui coule sur l'avant gauche
    for x, z in rect(10, 3, 13, 4) + rect(12, 5, 13, 6):
        if (x, y, z) in form.cells:
            put(d, form, x, y + 1, z, moss)
    relief(d, form, "front", [(c, form.lift + 8) for c in range(3, 7)] + [(4, form.lift + 7), (5, form.lift + 6)],
           moss, taken=d.vox)
    # pousse de fougère sur le dessus, à l'arrière : trois feuilles inclinées
    for k, (x, z, rx, rz) in enumerate([(8, 11, 28, 0), (7, 11, -6, 30), (9, 11, -6, -30)]):
        tilted(d, "Deco%d" % (k + 1), (x + 0.5, y + 4, z + 0.5), (1, 6, 1), (rx, 0, rz), (70, 150, 56),
               tip=((104, 186, 78), "Plastic"))


def decor_swamp(d, form, ground):
    mud = (88, 74, 48)
    # coulures de boue sur les flancs, liane qui pend sur l'avant droit
    relief(d, form, "left", [(4, form.lift + r) for r in (2, 3, 4)] + [(10, form.lift + r) for r in (3, 4)], mud,
           taken=d.vox)
    relief(d, form, "right", [(6, form.lift + r) for r in (2, 3, 4, 5)], mud, taken=d.vox)
    vine = (72, 128, 52)
    relief(d, form, "front", [(14, form.lift + r) for r in range(1, 7)] + [(13, form.lift + 4)], vine, taken=d.vox)
    # nénuphar et sa fleur sur le dessus
    on_top(d, form, rect(5, 8, 8, 11) + [(6, 7), (7, 7), (6, 12)], (70, 150, 72))
    on_top(d, form, [(6, 9)], (236, 124, 172), height=2)
    # deux massettes (roseaux à tête brune) plantées à l'arrière droit
    top = form.top(11, 13) or form.lift + 6
    for k, (x, z, h, rest) in enumerate([(11.5, 13.5, 9, (10, 0, -8)), (13.5, 12.5, 7, (-6, 0, -18))]):
        tilted(d, "Deco%d" % (k + 1), (x, top + h / 2, z), (1, h, 1), rest, (92, 150, 70),
               tip=((120, 76, 44), "Plastic", 2))


def decor_canyon(d, form, ground):
    if ground:
        for x, z, h in ((1, 2, 2), (15, 13, 1), (14, 2, 1)):
            for y in range(form.lift, form.lift + h):
                d.set("Biome", x, y, z, (184, 92, 58))
    # petit cactus sur le pied, à côté de la colonne, avec un bras
    cactus = (70, 140, 70)
    for y in range(form.lift + 2, form.lift + 8):
        put(d, form, 3, y, 7, cactus)
    put(d, form, 2, form.lift + 4, 7, cactus)
    for y in range(form.lift + 4, form.lift + 7):
        put(d, form, 1, y, 7, cactus)


def decor_glacier(d, form, ground):
    snow = (244, 250, 255)
    if ground:
        for (x0, z0, x1, z1) in ((3, 0, 6, 1), (11, 15, 13, 16), (0, 9, 1, 10)):
            for x, z in rect(x0, z0, x1, z1):
                d.set("Biome", x, form.lift, z, snow)
    # neige sur les épaules de la colonne
    for x, z in rect(3, 7, 4, 9) + rect(12, 7, 13, 9):
        put(d, form, x, form.lift + 12, z, snow)


def decor_volcano(d, form, ground):
    basalt = (44, 38, 40)
    lava = (255, 112, 40)
    if ground:
        for x, z, h in ((0, 3, 2), (16, 12, 1), (3, 16, 1), (14, 1, 1)):
            for y in range(form.lift, form.lift + h):
                d.set("Biome", x, y, z, basalt)
    # lave dans le cratère et coulée sur l'arrière
    for x, z in rect(7, 7, 9, 9):
        d.set("Ember", x, form.lift + 11, z, lava, "Neon")
    relief(d, form, "back", [(8, form.lift + r) for r in range(4, 13)] + [(9, form.lift + r) for r in range(1, 5)],
           lava, "Neon", role="Ember", taken=d.vox)
    # braises sur les marches
    for x, z in ((3, 4), (12, 6)):
        top = form.top(x, z)
        if top is not None:
            d.set("Ember", x, top + 1, z, lava, "Neon")


def decor_ocean(d, form, ground):
    if ground:
        for c in ring(form, form.lift, 2, 1):
            d.set("Biome", *c, (214, 196, 150))
    # bernacles et algues au pied, corail rose contre la charnière
    relief(d, form, "back", [(5, form.lift + 2), (6, form.lift + 2), (11, form.lift + 3), (10, form.lift + 6)],
           (210, 214, 218), taken=d.vox)
    weed = (60, 150, 92)
    for y in range(form.lift, form.lift + 5):
        put(d, form, 1, y, 8, weed)
    for y in range(form.lift, form.lift + 4):
        put(d, form, 15, y, 7, weed)
    for y in range(form.lift, form.lift + 3):
        put(d, form, 12, y, 12, (244, 108, 140))
    put(d, form, 11, form.lift + 2, 12, (244, 108, 140))


def decor_meteor(d, form, ground):
    if ground:
        # bord du cratère d'impact autour du pied
        for c in ring(form, form.lift, 2, 2):
            if abs(c[0] - C) + abs(c[2] - C) >= 9 or c[1] == form.lift:
                put(d, form, *c, (70, 62, 84))
    # éclats violets plantés dans le dessus et le flanc, petites étoiles qui brillent sur l'arrière
    violet = (170, 110, 255)
    top = max(y for (_, y, _) in form.cells)
    tilted(d, "Deco1", (7.5, top + 2, 7.5), (2, 5, 2), (14, 0, 18), violet, "Neon", tip=((220, 180, 255), "Neon"))
    tilted(d, "Deco2", (11.5, top, 4.5), (1, 4, 1), (-24, 0, -20), violet, "Neon", tip=((220, 180, 255), "Neon"))
    tilted(d, "Deco3", (1.5, form.lift + 7, 6.5), (1, 3, 1), (-10, 0, 50), violet, "Neon",
           tip=((220, 180, 255), "Neon"))
    relief(d, form, "back", [(3, form.lift + 10), (12, form.lift + 11), (14, form.lift + 4)], (255, 230, 120), "Neon",
           taken=d.vox)


# ---------------------------------------------------------------------- cristaux de la rareté
def sockets(form, count, avoid):
    """Places des cristaux sur le dessus : cases du haut (jusqu'à 3 voxels sous le sommet), étalées au mieux (la
    première au plus près du centre, un peu vers l'avant), avec l'inclinaison vers l'extérieur."""
    tops = {}
    for (x, y, z) in form.cells:
        if (x, y + 1, z) not in form.cells:
            tops[(x, z)] = max(tops.get((x, z), -1), y)
    if not tops or count <= 0:
        return []
    high = max(tops.values())
    cand = [(x, z) for (x, z), y in tops.items() if y >= high - 3 and (x, z) not in avoid
            and (x + 1, z) in tops and (x, z + 1) in tops and (x + 1, z + 1) in tops]
    if not cand:
        cand = [(x, z) for (x, z), y in tops.items() if y >= high - 3]
    cx = sum(p[0] for p in cand) / len(cand)
    cz = sum(p[1] for p in cand) / len(cand)
    chosen = [min(cand, key=lambda p: (p[0] + 0.5 - cx) ** 2 + (p[1] + 0.5 - cz + 1) ** 2 - tops[p] * 0.5)]
    while len(chosen) < count:
        best = max(cand, key=lambda p: min((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 for q in chosen))
        if min((best[0] - q[0]) ** 2 + (best[1] - q[1]) ** 2 for q in chosen) < 4:
            break
        chosen.append(best)
    out = []
    for x, z in chosen:
        rx = max(-30, min(30, (z + 0.5 - cz) * 6))
        rz = max(-30, min(30, -(x + 0.5 - cx) * 6))
        out.append((x, z, rx, rz))
    return out


def standing(d, name, x, z, w, h, rest, body, tip, mat, top):
    """Cristal dressé sur le dessus : colonne w x w de h voxels au-dessus de la surface, dont la base descend de deux
    voxels dans la roche, puis une pointe. Modélisé LIFT voxels plus haut (redescendu à l'export), incliné par la
    rotation de repos de son os autour de sa base."""
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


# ---------------------------------------------------------------------- un bloc
def cleft(form, color):
    """Epic : fente en V creusée dans le haut, de part en part ; le fond de la fente est un coeur qui brille."""
    tops = [y for (x, y, z) in form.cells if x in (C - 1, C, C + 1)]
    if not tops:
        return set()
    top = max(tops)
    depth = 4 if top - form.lift >= 10 else 3
    floor = top - depth
    cut = {(x, y, z) for (x, y, z) in form.cells if y > floor and abs(x - C) <= (y - floor) // 2 + 1}
    form.cells -= cut
    # coeur : le fond de la fente et le bas de ses deux parois
    return {(x, y, z) for (x, y, z) in form.cells if floor <= y <= floor + 1 and abs(x - C) <= 2
            and ((x, y + 1, z) in cut or (x - 1, y, z) in cut or (x + 1, y, z) in cut)}


def build(zone, rarity):
    """Bloc d'une rareté dans un biome (zone None : cube sans biome)."""
    look = LOOKS[rarity]
    form = (FORMS[zone] if zone else form_cube)()
    key = (zone or "Block").replace(" ", "")
    d = Dino("Block%s%s" % (key, rarity), "Block", voxel=VOXEL, display="%s %s Fossil" % (zone or "", rarity))
    center = (N / 2, N / 2, N / 2)
    for role in ("Rock", "Fossil", "Glow", "Rainbow", "Base", "Biome", "Ember"):
        d.bone(role, center)
    secret = rarity == "Secret"

    core = cleft(form, look["core"]) if look.get("core") and zone else set()
    if look.get("lift") and zone:
        form.shift(look["lift"])
        core = {(x, y + form.lift, z) for (x, y, z) in core}

    # roche : couleur de la rareté (bas plus sombre), teintes de la forme ; Secret : couches arc-en-ciel
    rock = look["rock"]
    if rock and form.tint:
        rock = mix(rock, (255, 255, 255), form.tint)
    lo, hi = form.bbox()
    for (x, y, z) in form.cells:
        if secret:
            if form.layers:
                band = sum(1 for start in form.layers[1:] if y >= start)
            else:
                band = (y - lo[1]) * len(RAINBOW) // (hi[1] - lo[1] + 1)
            d.set("Rainbow", x, y, z, RAINBOW[min(len(RAINBOW) - 1, band)], form.material)
        else:
            col = shade(rock, -0.22) if y <= lo[1] + 1 and not form.tint else rock
            tone = form.tones.get((x, y, z))
            if tone:
                col = shade(col, tone)
            d.set("Rock", x, y, z, col, form.material)
    for c in core:
        d.set("Glow", *c, look["core"], "Neon")
    # pièces inclinées de la forme (une brique chacune) : roche (arc-en-ciel pour le Secret) ou os
    for k, (role, c, size, rest, tone, tip) in enumerate(form.pieces):
        if role == "Fossil":
            col, mat = look["bone"], look["bone_mat"]
        elif secret:
            band = int((c[1] - lo[1]) * len(RAINBOW) // (hi[1] - lo[1] + 1))
            role, col, mat = "Rainbow", RAINBOW[max(0, min(len(RAINBOW) - 1, band))], form.material
        else:
            col, mat = shade(rock, tone), form.material
        tilted(d, "%s%d" % (role, k + 1), c, size, rest, col, mat,
               tip=(shade(col, tip[0]), mat, tip[1]) if tip else None)

    # fossile en relief
    for rows, face, col, row in form.art:
        if rows == "spiral":
            pts = spiral_cells()
            if face == "front":
                pts = [(N - 1 - x, y + form.lift) for (x, y) in pts]
            else:
                pts = [(x, y + form.lift) for (x, y) in pts]
            relief(d, form, face, pts, look["bone"], look["bone_mat"], role="Fossil")
        elif rows == "ribs":
            # côtes de la coquille : bandes verticales en relief qui dépassent du bord (bord dentelé)
            pts = []
            for k, cx in enumerate((1, 4, 8, 12, 15)):
                top = form.top(cx, C) if form.top(cx, C) is not None else form.lift + 8
                pts += [(N - 1 - cx, y) for y in range(form.lift + 5 if k in (0, 4) else form.lift + 3, top + 1)]
                d.set("Fossil", cx, top + 1, 7, look["bone"], look["bone_mat"])
                d.set("Fossil", cx, top + 1, 8, look["bone"], look["bone_mat"])
            relief(d, form, "front", pts, look["bone"], look["bone_mat"], role="Fossil")
        else:
            col0, top = centered(rows, col, row)
            relief(d, form, face, art_cells(rows, col0, top), look["bone"], look["bone_mat"], role="Fossil")

    # fissures de lave du Mythic sur les flancs
    if look.get("lava"):
        for face, col, row in form.cracks:
            col0, top = centered(CRACK, col, row)
            relief(d, form, face, art_cells(CRACK, col0, top), look["lava"], "Neon", role="Glow", taken=d.vox)

    # décor du biome (pas de bourrelet au sol sous un bloc en lévitation)
    if form.decor:
        form.decor(d, form, not secret)

    # socle d'or du Legendary, pierres sous le Secret
    if zone and rarity == "Legendary":
        for (x, z) in chamfer(C, C, 7, 7, 2):
            d.set("Base", x, 0, z, GOLD, "Foil")
    if zone and secret:
        # pierres éparses au sol, sous le bloc qui flotte (pas un socle : on voit le vide dessous)
        for (x0, z0, x1, z1, h) in ((3, 4, 5, 6, 2), (11, 3, 12, 4, 1), (12, 11, 14, 12, 2), (5, 12, 6, 13, 1),
                                    (8, 7, 9, 9, 1)):
            for x, z in rect(x0, z0, x1, z1):
                for y in range(h):
                    d.set("Base", x, y, z, (78, 70, 90) if y else (64, 58, 72))

    # cristaux de la rareté (Secret : chacun d'une couleur de l'arc-en-ciel ; en jeu, elles tournent)
    solid = form.cells | core
    spots = sockets(form, look["gems"], set())
    for k, (x, z, rx, rz) in enumerate(spots):
        body = look["gem"] or RAINBOW[k % len(RAINBOW)]
        w = 3 if k == 0 and look["gem_mat"] != "Plastic" else 2
        h = (5, 4, 3, 4, 3, 3)[k % 6] - (1 if look["gem_mat"] == "Plastic" else 0)
        tops = [max([y for (cx, y, cz) in solid if cx == x + dx and cz == z + dz] or [form.lift])
                for dx in range(w) for dz in range(w)]
        standing(d, "Gem%d" % (k + 1), x, z, w, h, (rx, 0, rz), body, shade(body, 0.3), look["gem_mat"], min(tops))

    # Mythic : trois morceaux de roche qui flottent au-dessus, une veine de lave chacun
    (x0, y0, z0), (x1, y1, z1) = form.bbox()
    if look.get("lava") and zone:
        for k, (cx, cy, cz, rest) in enumerate([(x0 - 1.0, y1 - 1.0, z0 + 3.0, (18, 30, 12)),
                                                 (x1 + 1.0, y1 + 0.5, z1 - 4.0, (-14, 20, -20)),
                                                 (C + 3.0, y1 + 4.5, z1 - 2.0, (24, -10, 16))]):
            tilted(d, "Float%d" % (k + 1), (cx, cy, cz), (2, 2, 2), rest, look["rock"],
                   tip=(look["lava"], "Neon"))
    # Secret : quatre éclats qui tournent autour, à mi-hauteur
    if secret and zone:
        r = max(x1 - x0, z1 - z0) / 2 + 2.5
        for k in range(4):
            a = math.radians(45 + 90 * k)
            cy = (y0 + y1) / 2 + (2 if k % 2 else -1)
            tilted(d, "Orbit%d" % (k + 1), (C + 0.5 + r * math.cos(a), cy, C + 0.5 + r * math.sin(a)), (1, 3, 1),
                   (10 * (1 if k % 2 else -1), 0, 15), RAINBOW[(k + 1) % len(RAINBOW)], "Neon",
                   tip=(shade(RAINBOW[(k + 1) % len(RAINBOW)], 0.35), "Neon"))
    return d


# ---------------------------------------------------------------------- export


def export(d):
    """Modèle en studs, centré sur le centre de la grille : os (rôles) avec pivot et rotation de repos, boîtes."""
    v = d.voxel
    o = N / 2  # centre de la grille (bords compris)

    def lift(bone):
        return LIFT if bone[-1:].isdigit() else 0

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
    ys = [bx["a"][1] for bx in boxes] + [bx["b"][1] + 1 for bx in boxes]
    return {
        "name": d.name,
        "display": d.display.strip(),
        "voxel": v,
        "origin": [o, o, o],
        "size": [N * v] * 3,
        "height": (max(ys) - min(ys)) * v,
        "bones": bones,
        "boxes": boxes,
        "voxels": len(d.vox),
    }


def models():
    """{zone: {rareté: modèle}} pour les 8 biomes, et sous la clé "" les cubes sans biome."""
    out = {"": {r: export(build(None, r)) for r in RARITIES}}
    for zone in BIOMES:
        out[zone] = {r: export(build(zone, r)) for r in RARITIES}
    return out


def roles(m):
    from collections import Counter
    return dict(Counter(b["bone"].rstrip("0123456789") for b in m["boxes"]))


if __name__ == "__main__":
    for zone, row in models().items():
        print("%-14s" % (zone or "(sans biome)") + " ".join("%4d" % len(m["boxes"]) for m in row.values()))
