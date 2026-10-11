"""Blocs de fossiles (brief 9) : modèles voxel (models/blocks/blocks.py), export Luau et rendus de contrôle.

    python models/blocks/build.py                  export Luau + rendus de contrôle (Blender)
    python models/blocks/build.py --export         seulement l'export Luau (sans Blender)
    python models/blocks/build.py --stills         seulement les rendus de contrôle
    python models/blocks/build.py --stills Beach   rendus d'une seule zone (nom ou début du nom)

Sorties :
  src/shared/BlockModels/Data.luau       données générées (blocs de chaque biome et de chaque rareté, cubes sans
                                         biome, tailles) ; BlockModels/init.luau (écrit à la main) les assemble
  models/previews/blocks/_formes.jpg     les 56 blocs (8 biomes x 7 raretés) et les cubes sans biome, de trois-quarts
                                         avant, à la même échelle : aucun ne doit ressembler à un autre
  models/previews/blocks/_formes_dos.jpg les mêmes de trois-quarts arrière (décor du biome)
  models/previews/blocks/<Zone>.jpg      les 7 raretés d'une zone à leur taille en jeu à côté de l'avatar de 5 studs,
                                         puis de face et de dos
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
LUAU = os.path.join(ROOT, "src", "shared", "BlockModels", "Data.luau")
PREVIEWS = os.path.join(MODELS, "previews", "blocks")
TAB = "\t"
GENERIC = ""  # clé des cubes sans biome dans blocks.models()


def n(x, d=3):
    s = f"{x:.{d}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "", "-") else s


def key(name):
    return name if name.isidentifier() else '["%s"]' % name


def luau_model(L, name, m, indent):
    """Un modèle au format Raw de BlockModels."""
    t1, t2, t3 = TAB * indent, TAB * (indent + 1), TAB * (indent + 2)
    paints = []
    for bx in m["boxes"]:
        k = (tuple(bx["col"]), bx["mat"])
        if k not in paints:
            paints.append(k)
    L.append(f"{t1}{key(name)} = {{")
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


def luau_data(models):
    """Module Data : boîtes en voxels comme src/shared/DinoModels, une boîte par ligne d'un texte (le module reste en
    --!strict : pas de tableaux mélangés)."""
    L = ["--!strict",
         "-- Données des blocs de fossiles, générées par models/blocks/build.py --export : ne pas modifier à la main.",
         "-- Lues par BlockModels (init.luau). Boxes : une boîte par ligne « rôle x0 y0 z0 x1 y1 z1 peinture » (cases",
         "-- incluses) ; centre en studs = ((x0 + x1 + 1) / 2 - Origin) * Voxel, taille = (x1 - x0 + 1) * Voxel ;",
         "-- peinture = Colors[i], Materials[i]. Bones : rôles qui ont un pivot et une rotation de repos (cristaux,",
         "-- feuilles, morceaux qui flottent), en studs depuis le centre.",
         "",
         "export type Raw = {",
         "\tVoxel: number,",
         "\tOrigin: number,",
         "\tBones: { [string]: { Pivot: Vector3, Rest: Vector3 } },",
         "\tColors: { Color3 },",
         "\tMaterials: { string },",
         "\tBoxes: string,",
         "}",
         "",
         "local V = Vector3.new",
         "local C = Color3.fromRGB",
         "",
         "-- taille en jeu par rapport à un bloc Common (les plus rares sont beaucoup plus gros)",
         "local Scales: { [string]: number } = { "
         + ", ".join(f"{r} = {n(s)}" for r, s in blocks.SCALES.items()) + " }",
         "",
         "-- forme de chaque biome (nom de la zone de Config.Zones)",
         "local Forms: { [string]: string } = {"]
    for zone in blocks.BIOMES:
        L.append(f'\t{key(zone)} = "{blocks.FORMS[zone]().name}",')
    L.append("}")
    L.append("")
    L.append("-- cubes sans biome (zone inconnue), par rareté")
    L.append("local Generic: { [string]: Raw } = {")
    for rarity, m in models[GENERIC].items():
        luau_model(L, rarity, m, 1)
    L.append("}")
    L.append("")
    L.append("-- blocs de chaque biome, par rareté")
    L.append("local Zones: { [string]: { [string]: Raw } } = {")
    for zone, row in models.items():
        if zone == GENERIC:
            continue
        L.append(f"\t{key(zone)} = {{")
        for rarity, m in row.items():
            luau_model(L, rarity, m, 2)
        L.append("\t},")
    L.append("}")
    L.append("")
    L.append("return { Scales = Scales, Forms = Forms, Generic = Generic, Zones = Zones }")
    return "\n".join(L) + "\n"


def export(models):
    text = luau_data(models)
    old = open(LUAU, encoding="utf-8").read() if os.path.exists(LUAU) else None
    if text != old:
        os.makedirs(os.path.dirname(LUAU), exist_ok=True)
        with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    total = sum(len(m["boxes"]) for row in models.values() for m in row.values())
    print("[blocs] export : %s (%d pièces au total, %d Ko)" % (os.path.relpath(LUAU, ROOT), total, len(text) // 1024))


def stills(models, only=None):
    from PIL import Image, ImageDraw
    from post import font, save_jpg

    tmp = os.path.join(tempfile.gettempdir(), "saf_blocks")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)
    path = os.path.join(tmp, "models.json")
    order = list(models)
    picked = [z for z in order if only is None or (z and z.lower().startswith(only.lower()))]
    json.dump({"zones": models, "scales": blocks.SCALES, "only": picked}, open(path, "w", encoding="utf-8"))
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
    title_font, small = font(24, True), font(16)
    tile = 260

    def label(zone):
        return ("%s (%s)" % (zone, blocks.FORMS[zone]().name)) if zone else "Sans biome (cube)"

    # planches des 56 blocs : une ligne par zone, une colonne par rareté, de face puis de dos
    if only is None:
        for view, out in (("face", "_formes.jpg"), ("dos", "_formes_dos.jpg")):
            head, side = 40, 200
            sheet = Image.new("RGB", (side + tile * len(blocks.RARITIES), head + tile * len(order)), (246, 244, 238))
            draw = ImageDraw.Draw(sheet)
            for j, rarity in enumerate(blocks.RARITIES):
                draw.text((side + j * tile + 10, 10), "%s x%s" % (rarity, n(blocks.SCALES[rarity], 2)),
                          fill=(30, 30, 30), font=title_font)
            for i, zone in enumerate(order):
                y = head + i * tile
                draw.text((10, y + tile // 2 - 20), label(zone), fill=(30, 30, 30), font=small)
                for j, rarity in enumerate(blocks.RARITIES):
                    shot = Image.open(os.path.join(tmp, "%d_%s_%s.png" % (i, rarity, view))).convert("RGB")
                    sheet.paste(shot.resize((tile, tile), Image.LANCZOS), (side + j * tile, y))
                    draw.text((side + j * tile + 8, y + tile - 22), "%d pièces" % len(models[zone][rarity]["boxes"]),
                              fill=(50, 50, 50), font=small)
            save_jpg(sheet, os.path.join(PREVIEWS, out), limit_kb=2400)
    # une planche par zone : le rang à la taille du jeu avec l'avatar, puis chaque bloc de face et de dos
    for i, zone in enumerate(order):
        if zone not in picked:
            continue
        rang = Image.open(os.path.join(tmp, "rang_%d.png" % i)).convert("RGB")
        w = rang.width // len(blocks.RARITIES)
        board = Image.new("RGB", (rang.width, 44 + rang.height + 2 * w), (246, 244, 238))
        draw = ImageDraw.Draw(board)
        draw.text((12, 8), "%s : les 7 raretés à leur taille en jeu (avatar gris = 5 studs), de face puis de dos"
                  % label(zone), fill=(30, 30, 30), font=title_font)
        board.paste(rang, (0, 44))
        for j, rarity in enumerate(blocks.RARITIES):
            for k, view in enumerate(("face", "dos")):
                shot = Image.open(os.path.join(tmp, "%d_%s_%s.png" % (i, rarity, view))).convert("RGB")
                board.paste(shot.resize((w, w), Image.LANCZOS), (j * w, 44 + rang.height + k * w))
            draw.text((j * w + 8, 44 + rang.height + 4), "%s (%d)" % (rarity, len(models[zone][rarity]["boxes"])),
                      fill=(40, 40, 40), font=small)
        name = (zone or "_sans_biome").replace(" ", "")
        save_jpg(board, os.path.join(PREVIEWS, name + ".jpg"), limit_kb=900)
    print("[blocs] rendus en %.0f s -> %s" % (time.time() - t0, os.path.relpath(PREVIEWS, ROOT)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", action="store_true", help="seulement l'export Luau")
    ap.add_argument("--stills", action="store_true", help="seulement les rendus de contrôle")
    ap.add_argument("zone", nargs="?", help="rendus d'une seule zone (nom ou début du nom)")
    a = ap.parse_args()
    models = blocks.models()
    for zone, row in models.items():
        print("[blocs] %-14s" % (zone or "(sans biome)") + " ".join("%4d" % len(m["boxes"]) for m in row.values()))
    worst = max(len(m["boxes"]) for row in models.values() for m in row.values())
    if worst > blocks.BUDGET:
        raise SystemExit("[blocs] trop de pièces : %d (budget %d)" % (worst, blocks.BUDGET))
    if not a.stills:
        export(models)
    if not a.export:
        stills(models, a.zone)


if __name__ == "__main__":
    main()
