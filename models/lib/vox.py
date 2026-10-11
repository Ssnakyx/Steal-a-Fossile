"""vox : modèles voxel des dinos de Steal a Fossil (os + voxels -> boîtes fusionnées).

Pur Python (tourne dans Blender comme dans le Python du système). Repère du jeu : X droite, Y haut, Z arrière ;
le dino REGARDE VERS -Z, pieds à Y = 0. Les coordonnées d'un modèle sont en voxels (entiers) ; la case (x, y, z)
occupe [x, x+1[ et son centre est x + 0,5. À l'export tout passe en studs (x voxel), recentré en X/Z, pieds à 0.

Côtés : L = gauche du dino = X négatif, R = droite = X positif. On modèle le côté gauche (x <= 0) puis `mirror()`.

Exemple :
    d = Dino("Velociraptor", "Biped", voxel=0.5)
    d.bone("Hips", (0, 8, 2))
    d.bone("Chest", (0, 8.5, -1), "Hips")
    d.ellipsoid("Hips", (0, 8, 2), (2.5, 2.2, 3), BODY)
    d.limb("ThighL", (-2, 8, 1), (-2, 5, -1), 1.6, 1.0, BODY)    # segment épais effilé
    d.mirror()                                                  # ThighL -> ThighR, etc.
    d.paint_surface(lambda x, y, z, bone, col: BELLY if y < 7 else None)
    d.point("ToeL", "FootL", (-2, 0, -3))                      # points nommés (pieds, yeux, bouche)
"""
from __future__ import annotations

import math
from collections import Counter, defaultdict

MATERIALS = ("Plastic", "Smooth", "Neon", "Glass", "Ice", "Metal")
OPAQUE = ("Plastic", "Smooth", "Metal")
NEIGHBOURS = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))


def rgb(c):
    if isinstance(c, str):
        c = c.lstrip("#")
        return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16))
    return tuple(int(max(0, min(255, round(v)))) for v in c)


def mix(a, b, k):
    a, b = rgb(a), rgb(b)
    return tuple(round(a[i] + (b[i] - a[i]) * k) for i in range(3))


def shade(c, k):
    """k > 0 éclaircit, k < 0 assombrit."""
    return mix(c, (255, 255, 255), k) if k >= 0 else mix(c, (0, 0, 0), -k)


def side_name(name, side):
    """'ThighL' -> 'ThighR' (side = 'R')."""
    if name.endswith("L") or name.endswith("R"):
        return name[:-1] + side
    return name


def hash3(x, y, z, seed=0):
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


ORDERS = ((0, 2, 1), (2, 0, 1), (0, 1, 2), (1, 0, 2), (2, 1, 0), (1, 2, 0))


def _grow(seed, order, ok):
    lo = list(seed)
    hi = list(seed)
    for ax in order:
        for direction in (1, -1):
            while True:
                nxt = (hi[ax] + 1) if direction > 0 else (lo[ax] - 1)
                rng = [range(lo[i], hi[i] + 1) if i != ax else (nxt,) for i in range(3)]
                if all(ok((x, y, z)) for x in rng[0] for y in rng[1] for z in rng[2]):
                    if direction > 0:
                        hi[ax] = nxt
                    else:
                        lo[ax] = nxt
                else:
                    break
    return tuple(lo), tuple(hi)


def _greedy(todo, extra):
    """Boîtes qui couvrent toutes les cases de `todo` (chacune une seule fois) en traversant au besoin les cases de
    `extra` (jokers). Renvoie [(coin min, coin max, jokers couverts)]."""
    out = []

    def ok(c):
        return c in todo or c in extra

    while todo:
        seed = min(todo, key=lambda c: (c[1], c[2], c[0]))
        best, gain = None, -1
        for order in ORDERS:
            a, b = _grow(seed, order, ok)
            g = sum(1 for x in range(a[0], b[0] + 1) for y in range(a[1], b[1] + 1) for z in range(a[2], b[2] + 1)
                    if (x, y, z) in todo)
            if g > gain:
                best, gain = (a, b), g
        a, b = best
        inside = set()
        for x in range(a[0], b[0] + 1):
            for y in range(a[1], b[1] + 1):
                for z in range(a[2], b[2] + 1):
                    c = (x, y, z)
                    if c in todo:
                        todo.discard(c)
                    elif c in extra:
                        inside.add(c)
        out.append((a, b, inside))
    return out


class Dino:
    def __init__(self, name: str, family: str, voxel: float = 0.5, display: str | None = None):
        self.name = name
        self.family = family
        self.display = display or name
        self.voxel = voxel
        self.vox: dict[tuple[int, int, int], tuple[str, tuple[int, int, int], str]] = {}
        self.bones: dict[str, dict] = {}
        self.points: dict[str, tuple[str, tuple[float, float, float]]] = {}

    # ------------------------------------------------------------------ os
    def bone(self, name: str, pivot, parent: str | None = None, rest=None):
        """rest = (rx, ry, rz) : rotation de repos de l'os (degrés). Ses voxels sont modélisés droits, alignés sur la
        grille (peu de pièces), puis tournés au repos : utile pour une plaque inclinée (collerette, aile)."""
        if parent and parent not in self.bones:
            raise ValueError(f"os parent {parent} inconnu pour {name}")
        if name in self.bones:
            raise ValueError(f"os {name} déjà défini")
        self.bones[name] = {"parent": parent, "pivot": tuple(float(v) for v in pivot),
                            "rest": tuple(float(v) for v in rest) if rest else None}

    def bone_pair(self, name: str, pivot, parent: str | None = None, rest=None):
        """Os gauche (pivot donné côté x <= 0) et son symétrique droit. name sans suffixe : 'Thigh' -> ThighL/ThighR."""
        px, py, pz = pivot
        pl = parent and (parent[:-1] + "L" if parent.endswith(("L", "R")) and parent[:-1] + "L" in self.bones else parent)
        pr = parent and (parent[:-1] + "R" if parent.endswith(("L", "R")) and parent[:-1] + "R" in self.bones else parent)
        self.bone(name + "L", (px, py, pz), pl, rest)
        self.bone(name + "R", (-px, py, pz), pr, (rest[0], -rest[1], -rest[2]) if rest else None)

    def point(self, name: str, bone: str, p):
        self.points[name] = (bone, tuple(float(v) for v in p))

    # ------------------------------------------------------------------ voxels
    def set(self, bone: str, x: int, y: int, z: int, color, material: str = "Plastic"):
        if bone not in self.bones:
            raise ValueError(f"os {bone} inconnu")
        if material not in MATERIALS:
            raise ValueError(f"matière {material} inconnue")
        self.vox[(int(x), int(y), int(z))] = (bone, rgb(color), material)

    def clear(self, x, y, z):
        self.vox.pop((int(x), int(y), int(z)), None)

    def box(self, bone, a, b, color, material="Plastic", where=None):
        x0, x1 = sorted((int(round(a[0])), int(round(b[0]))))
        y0, y1 = sorted((int(round(a[1])), int(round(b[1]))))
        z0, z1 = sorted((int(round(a[2])), int(round(b[2]))))
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    if where is None or where(x, y, z):
                        self.set(bone, x, y, z, color, material)

    def ellipsoid(self, bone, center, radii, color, material="Plastic", where=None, power=2.0):
        """Ellipsoïde (power = 2) ou forme plus carrée (power > 2, ex. 3 pour un torse de jouet)."""
        cx, cy, cz = center
        rx, ry, rz = radii
        for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
            for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
                for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                    d = (abs(x - cx) / max(rx, 0.01)) ** power + (abs(y - cy) / max(ry, 0.01)) ** power \
                        + (abs(z - cz) / max(rz, 0.01)) ** power
                    if d <= 1.0 and (where is None or where(x, y, z)):
                        self.set(bone, x, y, z, color, material)

    def limb(self, bone, a, b, ra, rb=None, color=(200, 200, 200), material="Plastic", where=None, flat=1.0):
        """Segment épais de a à b (voxels), section ronde de rayon ra -> rb (effilé). flat < 1 aplatit en X."""
        rb = ra if rb is None else rb
        ax, ay, az = a
        bx, by, bz = b
        dx, dy, dz = bx - ax, by - ay, bz - az
        ll = dx * dx + dy * dy + dz * dz
        rmax = max(ra, rb)
        for x in range(math.floor(min(ax, bx) - rmax / flat) - 1, math.ceil(max(ax, bx) + rmax / flat) + 2):
            for y in range(math.floor(min(ay, by) - rmax) - 1, math.ceil(max(ay, by) + rmax) + 2):
                for z in range(math.floor(min(az, bz) - rmax) - 1, math.ceil(max(az, bz) + rmax) + 2):
                    px, py, pz = x, y, z
                    t = 0.0 if ll == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / ll))
                    qx, qy, qz = ax + dx * t, ay + dy * t, az + dz * t
                    r = ra + (rb - ra) * t
                    if ((px - qx) * flat) ** 2 + (py - qy) ** 2 + (pz - qz) ** 2 <= r * r + 0.15 and (where is None or where(x, y, z)):
                        self.set(bone, x, y, z, color, material)

    def plate(self, bone, axis, level, poly, color, material="Plastic", thick=1):
        """Plaque plate : tous les voxels dont la coordonnée `axis` (0 x, 1 y, 2 z) vaut level..level+thick-1 et
        dont les deux autres coordonnées tombent dans le polygone `poly` [(a, b)] (ordre des axes restants)."""
        others = [i for i in range(3) if i != axis]
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]

        def inside(a, b):
            n, j, ok = len(poly), len(poly) - 1, False
            for i in range(n):
                ai, bi = poly[i]
                aj, bj = poly[j]
                if (bi > b) != (bj > b) and a < (aj - ai) * (b - bi) / (bj - bi + 1e-12) + ai:
                    ok = not ok
                j = i
            return ok
        for a in range(math.floor(min(xs)), math.ceil(max(xs)) + 1):
            for b in range(math.floor(min(ys)), math.ceil(max(ys)) + 1):
                if inside(a, b):
                    for lv in range(level, level + thick):
                        c = [0, 0, 0]
                        c[axis] = lv
                        c[others[0]] = a
                        c[others[1]] = b
                        self.set(bone, c[0], c[1], c[2], color, material)

    def remove(self, where):
        for k in [k for k in self.vox if where(*k)]:
            del self.vox[k]

    def surface_x(self, y, z, bone=None):
        """Plus petit x occupé à (y, z) (côté gauche du modèle), ou None."""
        xs = [k[0] for k, v in self.vox.items() if k[1] == y and k[2] == z and (bone is None or v[0] == bone)]
        return min(xs) if xs else None

    def surface_y(self, x, z, bone=None):
        """Plus grand y occupé à (x, z) (dessus du modèle), ou None."""
        ys = [k[1] for k, v in self.vox.items() if k[0] == x and k[2] == z and (bone is None or v[0] == bone)]
        return max(ys) if ys else None

    def eye(self, bone, lid, y, z, iris, pupil, lid_color=None, h=2, w=2, pupil_rows=None):
        """Oeil sur le flanc gauche, posé sur la surface (pas en saillie) : pupille à l'avant (dz = 0), iris derrière.
        La paupière (os `lid`, h voxels de haut, à fleur de peau) est juste au-dessus ; le clignement la descend de
        h voxels devant l'oeil (et un poil vers l'extérieur pour ne pas se confondre avec lui)."""
        pupil_rows = range(h) if pupil_rows is None else pupil_rows
        for dy in range(h):
            for dz in range(w):
                x = self.surface_x(y + dy, z + dz)
                if x is None:
                    continue
                col = pupil if (dz == 0 and dy in pupil_rows) else iris
                self.set(bone, x, y + dy, z + dz, col, "Smooth")
        for dy in range(h, 2 * h):
            for dz in range(w):
                x = self.surface_x(y + dy, z + dz)
                if x is None:
                    continue
                self.set(lid, x, y + dy, z + dz, lid_color or self.vox[(x, y + dy, z + dz)][1])
        self.meta_lid = getattr(self, "meta_lid", {})
        self.meta_lid[lid] = h

    def mirror(self, bone_map: dict[str, str] | None = None):
        """Copie le côté x < 0 vers x > 0. Les os qui finissent par L deviennent R (ThighL -> ThighR)."""
        bone_map = bone_map or {}
        for (x, y, z), (bone, color, material) in list(self.vox.items()):
            if x < 0:
                nb = bone_map.get(bone) or (side_name(bone, "R") if bone.endswith("L") and side_name(bone, "R") in self.bones else bone)
                self.vox[(-x, y, z)] = (nb, color, material)
        for name, (bone, p) in list(self.points.items()):
            if name.endswith("L") and side_name(name, "R") not in self.points:
                nb = side_name(bone, "R") if bone.endswith("L") and side_name(bone, "R") in self.bones else bone
                self.points[side_name(name, "R")] = (nb, (-p[0], p[1], p[2]))

    # ------------------------------------------------------------------ peinture
    def visible(self, key, joints=False) -> bool:
        """Une face du voxel donne sur du vide (ou sur une matière transparente). Avec joints=True, un voisin d'un
        autre os compte aussi comme visible (la face peut apparaître quand l'os tourne)."""
        x, y, z = key
        bone, _, mat = self.vox[key]
        for dx, dy, dz in NEIGHBOURS:
            n = self.vox.get((x + dx, y + dy, z + dz))
            if n is None or (n[2] in OPAQUE) != (mat in OPAQUE) or (joints and n[0] != bone):
                return True
        return False

    def paint(self, fn, surface_only=True, bones=None):
        """fn(x, y, z, bone, color) -> couleur, (couleur, matière) ou None. Par défaut seulement les voxels visibles."""
        for key, (bone, color, material) in list(self.vox.items()):
            if bones and bone not in bones:
                continue
            if surface_only and not self.visible(key):
                continue
            out = fn(key[0], key[1], key[2], bone, color)
            if out is None:
                continue
            if isinstance(out, tuple) and len(out) == 2 and isinstance(out[1], str):
                self.vox[key] = (bone, rgb(out[0]), out[1])
            else:
                self.vox[key] = (bone, rgb(out), material)

    paint_surface = paint

    def columns(self, bones):
        """(os, x, z) -> (ymin, ymax) des voxels de ces os."""
        col = {}
        for (x, y, z), (bone, _, _) in self.vox.items():
            if bone in bones:
                k = (bone, x, z)
                lo, hi = col.get(k, (y, y))
                col[k] = (min(lo, y), max(hi, y))
        return col

    def countershade(self, bones, belly, frac=0.35, only=None):
        """Ventre clair : dans chaque colonne verticale d'un os, la part basse `frac` prend la couleur `belly`."""
        col = self.columns(bones)

        def fn(x, y, z, bone, c):
            if bone not in bones or (only and c not in only):
                return None
            lo, hi = col[(bone, x, z)]
            if y < lo + frac * (hi - lo + 1):
                return belly
            return None
        self.paint(fn)

    def back_stripes(self, bones, color, frac=0.3, period=4, width=2, only=None, axis=2):
        """Rayures sur le dessus : part haute `frac` de chaque colonne, une bande de `width` toutes les `period`."""
        col = self.columns(bones)

        def fn(x, y, z, bone, c):
            if bone not in bones or (only and c not in only):
                return None
            lo, hi = col[(bone, x, z)]
            k = (x, y, z)[axis]
            if y > hi - frac * (hi - lo + 1) and (k % period) < width:
                return color
            return None
        self.paint(fn)

    # ------------------------------------------------------------------ fusion des voxels en boîtes
    def merged(self):
        """Fusion gloutonne par (os, couleur, matière). Les voxels cachés (entourés du même os et de la même
        famille de matière) sont des jokers : une boîte peut les traverser quelle que soit leur couleur, ce qui
        réduit beaucoup le nombre de pièces des modèles rayés ou tachetés. La surface garde ses couleurs exactes.
        Pour chaque graine, on essaie les 6 ordres d'extension des axes et on garde la boîte qui couvre le plus."""
        hidden = {k for k in self.vox if not self.visible(k)}
        groups = defaultdict(set)          # (os, couleur, matière) -> voxels visibles
        wild = defaultdict(set)            # (os, opaque?) -> voxels cachés
        for k, (bone, color, material) in self.vox.items():
            if k in hidden:
                wild[(bone, material in OPAQUE)].add(k)
            else:
                groups[(bone, color, material)].add(k)
        boxes = []
        covered_hidden = set()
        for (bone, color, material), cells in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            jok = wild[(bone, material in OPAQUE)] if material in OPAQUE else set()
            for a, b, inside in _greedy(set(cells), jok):
                covered_hidden |= inside
                boxes.append((bone, color, material, a, b))
        # jokers jamais couverts : couleur majoritaire de leur os (même famille de matière)
        major = {}
        for k, (bone, color, material) in self.vox.items():
            major.setdefault((bone, material in OPAQUE), Counter())[(color, material)] += 1
        for (bone, opaque), cells in wild.items():
            left = cells - covered_hidden
            if not left:
                continue
            color, material = major[(bone, opaque)].most_common(1)[0][0]
            for a, b, _ in _greedy(left, cells - left):
                boxes.append((bone, color, material, a, b))
        return boxes

    def bounds(self):
        xs = [k[0] for k in self.vox]
        ys = [k[1] for k in self.vox]
        zs = [k[2] for k in self.vox]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    # ------------------------------------------------------------------ données (studs, recentrées)
    def data(self):
        """Modèle prêt pour l'animation et l'export : tout en studs, X/Z centrés, pieds à Y = 0."""
        if not self.vox:
            raise ValueError("aucun voxel")
        for name in self.bones:
            if not any(b == name for b, _, _ in self.vox.values()):
                print(f"[vox] attention : l'os {name} n'a aucun voxel")
        boxes = self.merged()
        (x0, y0, z0), (x1, y1, z1) = self.bounds()
        v = self.voxel
        ox, oz = (x0 + x1 + 1) / 2, (z0 + z1 + 1) / 2
        oy = y0

        def p3(p):
            return [(p[0] + 0.5 - ox) * v, (p[1] + 0.5 - oy) * v, (p[2] + 0.5 - oz) * v]

        order = []
        seen = set()

        def visit(n):
            if n in seen:
                return
            par = self.bones[n]["parent"]
            if par:
                visit(par)
            seen.add(n)
            order.append(n)

        for n in self.bones:
            visit(n)
        out_boxes = []
        for bone, color, material, a, b in boxes:
            c = [((a[0] + b[0] + 1) / 2 - ox) * v, ((a[1] + b[1] + 1) / 2 - oy) * v, ((a[2] + b[2] + 1) / 2 - oz) * v]
            s = [(b[0] - a[0] + 1) * v, (b[1] - a[1] + 1) * v, (b[2] - a[2] + 1) * v]
            out_boxes.append({"bone": bone, "c": c, "s": s, "col": list(color), "mat": material,
                              "a": list(a), "b": list(b)})
        return {
            "name": self.name,
            "display": self.display,
            "family": self.family,
            "voxel": v,
            "origin": [ox, oy, oz],
            "height": (y1 - y0 + 1) * v,
            "size": [(x1 - x0 + 1) * v, (y1 - y0 + 1) * v, (z1 - z0 + 1) * v],
            "bones": [{"name": n, "parent": self.bones[n]["parent"], "pivot": p3(self.bones[n]["pivot"]),
                       "rest": list(self.bones[n]["rest"]) if self.bones[n]["rest"] else None} for n in order],
            "boxes": out_boxes,
            "points": {k: {"bone": b, "p": p3(p)} for k, (b, p) in self.points.items()},
            "lids": {k: h * v for k, h in getattr(self, "meta_lid", {}).items()},
            "voxels": len(self.vox),
        }
