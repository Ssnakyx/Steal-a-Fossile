"""Blocs de fossiles (brief 9) : modèles voxel (models/blocks/blocks.py), export Luau et rendus de contrôle.

    python models/blocks/build.py              export Luau + rendus de contrôle (Blender)
    python models/blocks/build.py --export     seulement l'export Luau (sans Blender)
    python models/blocks/build.py --stills     seulement les rendus de contrôle

Sorties :
  src/shared/BlockModels.luau          section des données entre les lignes « >>> » et « <<< » (le reste du module est
                                       écrit à la main : ne pas modifier la section générée)
  models/previews/blocks/<Rareté>.jpg  face, trois-quarts gauche et droit, dos, dessus
  models/previews/blocks/_blocs.jpg    les 7 blocs en rang à côté de l'avatar de 5 studs, et leurs vues de trois-quarts
Il faut Blender 5.2 (variable BLENDER sinon) et Pillow dans le Python du système."""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
ROOT = os.path.dirname(MODELS)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(MODELS, "lib"))
import blocks  # noqa: E402

BLENDER = os.environ.get("BLENDER", r"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
LUAU = os.path.join(ROOT, "src", "shared", "BlockModels.luau")
PREVIEWS = os.path.join(MODELS, "previews", "blocks")
BEGIN = "-- >>> données générées par models/blocks/build.py"
END = "-- <<< fin des données générées"
TAB = "\t"


def n(x, d=3):
    s = f"{x:.{d}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "", "-") else s


def luau_data(models):
    """Section Luau : un modèle par rareté, boîtes en voxels comme src/shared/DinoModels, une boîte par ligne d'un texte
    (le module reste en --!strict : pas de tableaux mélangés)."""
    t1, t2, t3 = TAB, TAB * 2, TAB * 3
    L = [BEGIN + " (python models/blocks/build.py --export) : ne pas modifier à la main.",
         "-- Boxes : une boîte par ligne « rôle x0 y0 z0 x1 y1 z1 peinture » (cases incluses) ; centre en studs =",
         "-- ((x0 + x1 + 1) / 2 - Origin) * Voxel, taille = (x1 - x0 + 1) * Voxel ; peinture = Colors[i], Materials[i].",
         "-- Bones : rôles qui ont un pivot et une rotation de repos (cristaux), en studs depuis le centre du bloc.",
         "local V = Vector3.new",
         "local C = Color3.fromRGB",
         "local DATA: { [string]: Raw } = {"]
    for rarity, m in models.items():
        paints = []
        for bx in m["boxes"]:
            k = (tuple(bx["col"]), bx["mat"])
            if k not in paints:
                paints.append(k)
        L.append(f"{t1}{rarity} = {{")
        L.append(f"{t2}Voxel = {n(m['voxel'], 6)},")
        L.append(f"{t2}Origin = {n(m['origin'][0])},")
        bones = [b for b in m["bones"] if b.get("rest")]
        if bones:
            L.append(f"{t2}Bones = {{")
            for b in bones:
                p, r = b["pivot"], b["rest"]
                L.append(f'{t3}{b["name"]} = {{ Pivot = V({n(p[0])}, {n(p[1])}, {n(p[2])}), '
                         f"Rest = V({n(r[0], 1)}, {n(r[1], 1)}, {n(r[2], 1)}) }},")
            L.append(f"{t2}}},")
        else:
            L.append(f"{t2}Bones = {{}},")
        L.append(f"{t2}Colors = {{ " + ", ".join(f"C({c[0]}, {c[1]}, {c[2]})" for c, _ in paints) + " },")
        L.append(f"{t2}Materials = {{ " + ", ".join(f'"{mat}"' for _, mat in paints) + " },")
        L.append(f"{t2}Boxes = [[")
        for bx in m["boxes"]:
            a, b = bx["a"], bx["b"]
            pi = paints.index((tuple(bx["col"]), bx["mat"])) + 1
            L.append(f'{bx["bone"]} {a[0]} {a[1]} {a[2]} {b[0]} {b[1]} {b[2]} {pi}')
        L.append("]],")
        L.append(f"{t1}}},")
    L.append("}")
    L.append(END)
    return "\n".join(L)


def export(models):
    text = open(LUAU, encoding="utf-8").read()
    start = text.index(BEGIN)
    stop = text.index(END) + len(END)
    new = text[:start] + luau_data(models) + text[stop:]
    if new != text:
        with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
    print("[blocs] export : %s (%d pièces au total)" % (os.path.relpath(LUAU, ROOT),
                                                       sum(len(m["boxes"]) for m in models.values())))


def stills(models):
    from PIL import Image, ImageDraw
    from post import font, save_jpg

    tmp = os.path.join(tempfile.gettempdir(), "saf_blocks")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)
    path = os.path.join(tmp, "models.json")
    json.dump(models, open(path, "w", encoding="utf-8"))
    t0 = time.time()
    cmd = [BLENDER, "--background", "--factory-startup", "--python", os.path.join(HERE, "blender_blocks.py"), "--",
           path, tmp]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    for line in proc.stdout.splitlines():
        if line.startswith(("[blocs]", "Traceback", "  File", "    ")) or "Error" in line:
            print(line)
    if proc.returncode != 0:
        print(proc.stderr[-4000:])
        raise SystemExit("Blender a échoué")
    os.makedirs(PREVIEWS, exist_ok=True)
    views = ["face", "gauche", "droite", "dos", "dessus"]
    title_font, small = font(26, True), font(17)
    tile = 360
    shots = []
    for rarity, m in models.items():
        img = Image.new("RGB", (tile * len(views), tile + 46), (246, 244, 238))
        draw = ImageDraw.Draw(img)
        draw.text((12, 8), "%s : %d pièces" % (m["display"], len(m["boxes"])), fill=(30, 30, 30), font=title_font)
        for i, v in enumerate(views):
            shot = Image.open(os.path.join(tmp, "%s_%s.png" % (rarity, v))).convert("RGB")
            img.paste(shot.resize((tile, tile), Image.LANCZOS), (i * tile, 46))
            draw.text((i * tile + 10, 50), v, fill=(60, 60, 60), font=small)
        save_jpg(img, os.path.join(PREVIEWS, rarity + ".jpg"))
        shots.append((rarity, len(m["boxes"]), Image.open(os.path.join(tmp, "%s_gauche.png" % rarity)).convert("RGB")))
    # planche : la rangée avec l'avatar, puis la vue trois-quarts de chaque bloc
    rang = Image.open(os.path.join(tmp, "rang.png")).convert("RGB")
    w = rang.width // len(shots)
    board = Image.new("RGB", (rang.width, rang.height + w + 40), (246, 244, 238))
    board.paste(rang, (0, 0))
    draw = ImageDraw.Draw(board)
    for i, (rarity, count, shot) in enumerate(shots):
        board.paste(shot.resize((w, w), Image.LANCZOS), (i * w, rang.height))
        draw.text((i * w + 10, rang.height + w + 6), "%s (%d)" % (rarity, count), fill=(40, 40, 40), font=small)
    save_jpg(board, os.path.join(PREVIEWS, "_blocs.jpg"), limit_kb=900)
    print("[blocs] rendus en %.0f s -> %s" % (time.time() - t0, os.path.relpath(PREVIEWS, ROOT)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", action="store_true", help="seulement l'export Luau")
    ap.add_argument("--stills", action="store_true", help="seulement les rendus de contrôle")
    a = ap.parse_args()
    models = blocks.models()
    for rarity, m in models.items():
        print("[blocs] %-10s %3d pièces" % (rarity, len(m["boxes"])))
    if not a.stills:
        export(models)
    if not a.export:
        stills(models)


if __name__ == "__main__":
    main()
