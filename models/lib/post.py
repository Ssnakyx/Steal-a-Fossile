"""post : assemble les images rendues par Blender (Python du système : Pillow + ffmpeg d'imageio-ffmpeg).

    python models/lib/post.py <Espece> <dossier_tmp> stills|anim

Sorties dans models/previews/<Espece>/ :
  <Espece>_controle.jpg   rendus de contrôle au repos (face, trois-quarts, profil, dos) avec un avatar de 5 studs
  <Espece>_planche.jpg    6 instants de chaque animation (vue trois-quarts)
  <Espece>_animations.mp4 toutes les animations à la suite, vue trois-quarts + profil, nom de l'état à l'écran
"""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)

# ce que montre chaque animation (texte de la vidéo et de la planche)
LABELS = {
    "Idle": "Idle : respire, regarde autour, cligne des yeux",
    "IdleSniff": "Idle (variante) : renifle le sol",
    "IdleScratch": "Idle (variante) : se gratte",
    "IdleStretch": "Idle (variante) : s'étire",
    "IdleShake": "Idle (variante) : secoue la tête",
    "IdleYawn": "Idle (variante) : bâille",
    "Walk": "Walk : se promène",
    "Run": "Run : course poursuite (gardien)",
    "Happy": "Happy : petit saut de joie",
    "Roar": "Roar : rugit (révélation, gardien)",
    "Eat": "Eat : mange",
    "Sleep": "Sleep : dort, le ventre monte et descend",
    "Spawn": "Spawn : sort de la cuve, s'ébroue, regarde le joueur",
    "Wake": "Wake (gardien) : sursaute et se relève",
    "Catch": "Catch (gardien) : coup de tête cartoon",
    "Search": "Search (gardien) : a perdu le joueur, renifle, regarde",
    "BackToSleep": "BackToSleep (gardien) : tourne sur lui-même et se recouche",
    "Fusion": "Fusion : aspiré dans le tourbillon",
    "Index": "Index : pose de présentation",
    "TakeOff": "TakeOff : décolle",
    "Fly": "Fly : vol battu",
    "Glide": "Glide : plane",
    "Land": "Land : atterrit",
    "Dive": "Dive : plonge",
    "Jump": "Jump : saute hors de l'eau",
}


def font(size, bold=False):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), ("arialbd.ttf" if bold else "arial.ttf")):
        p = os.path.join("C:/Windows/Fonts", name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def ffmpeg_exe():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        raise SystemExit("ffmpeg introuvable (installer imageio-ffmpeg ou ffmpeg)")


def save_jpg(img, path, limit_kb=600):
    q = 88
    while True:
        img.save(path, quality=q, optimize=True, progressive=True)
        if os.path.getsize(path) < limit_kb * 1024:
            break
        if q > 64:
            q -= 6
        else:
            img = img.resize((int(img.width * 0.9), int(img.height * 0.9)), Image.LANCZOS)


def stills(species, tmp, outdir):
    names = [("face", "Face"), ("trois-quarts", "Trois-quarts"), ("profil", "Profil"), ("dos", "Dos")]
    ims = [Image.open(os.path.join(tmp, "still_%s.png" % n)).convert("RGB") for n, _ in names]
    w, h = ims[0].size
    with open(os.path.join(tmp, "model.json"), encoding="utf-8") as f:
        model = json.load(f)
    head = 70
    sheet = Image.new("RGB", (w * 2, h * 2 + head), (26, 30, 38))
    for i, im in enumerate(ims):
        sheet.paste(im, ((i % 2) * w, head + (i // 2) * h))
    d = ImageDraw.Draw(sheet)
    sx, sy, sz = model["size"]
    d.text((18, 10), "%s  -  %s" % (model["display"], model["family"]), font=font(30, True), fill=(250, 246, 236))
    d.text((18, 44), "%d pièces, %d os, %.1f x %.1f x %.1f studs (taille Normal). Avatar gris = 5 studs." % (
        len(model["boxes"]), len(model["bones"]), sx, sy, sz), font=font(18), fill=(200, 206, 216))
    for i, (_, label) in enumerate(names):
        d.text(((i % 2) * w + 14, head + (i // 2) * h + 10), label, font=font(22, True), fill=(30, 34, 40))
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, "%s_controle.jpg" % species)
    save_jpg(sheet, out, 700)
    print("[post] contrôle :", out)
    return out


def anim(species, tmp, outdir):
    with open(os.path.join(tmp, "anim_meta.json"), encoding="utf-8") as f:
        meta = json.load(f)
    with open(os.path.join(tmp, "model.json"), encoding="utf-8") as f:
        model = json.load(f)
    os.makedirs(outdir, exist_ok=True)
    vid = os.path.join(tmp, "video")
    shutil.rmtree(vid, ignore_errors=True)
    os.makedirs(vid)
    k = 0
    rows = []
    f_title, f_sub, f_small = font(26, True), font(18), font(15)
    for name, m in meta.items():
        n = m["frames"]
        frames = []
        for i in range(n):
            a = Image.open(os.path.join(tmp, "%s_%04d_0.png" % (name, i))).convert("RGB")
            b = Image.open(os.path.join(tmp, "%s_%04d_1.png" % (name, i))).convert("RGB")
            frames.append((a, b))
        w, h = frames[0][0].size
        head = 58
        for i, (a, b) in enumerate(frames):
            t = i / m["fps"]
            tl = t % m["length"] if m["loop"] else t
            img = Image.new("RGB", (w * 2, h + head + 10), (26, 30, 38))
            img.paste(a, (0, head))
            img.paste(b, (w, head))
            d = ImageDraw.Draw(img)
            d.text((14, 6), "%s  -  %s" % (model["display"], LABELS.get(name, name)), font=f_title, fill=(250, 246, 236))
            info = "%.2f / %.2f s%s" % (tl, m["length"], "  (boucle)" if m["loop"] else "")
            d.text((16, 36), info, font=f_small, fill=(190, 198, 210))
            # barre de progression + événements (pas, impact, rugissement)
            y0 = h + head + 2
            d.rectangle((0, y0, w * 2, y0 + 8), fill=(50, 56, 68))
            d.rectangle((0, y0, int(w * 2 * tl / m["length"]), y0 + 8), fill=(255, 196, 60))
            for ev in m["events"]:
                x = int(w * 2 * ev[0] / m["length"])
                col = (120, 220, 255) if ev[1] == "Step" else (255, 90, 90)
                d.rectangle((x - 1, y0 - 2, x + 1, y0 + 10), fill=col)
            img.save(os.path.join(vid, "f%05d.png" % k))
            k += 1
        # planche : 6 instants (vue trois-quarts)
        single = n // m["loops"]
        idx = [int(i * (single - 1) / 5) for i in range(6)]
        hits = [ev[0] for ev in m["events"] if ev[1] in ("Hit", "Roar")]
        if hits:
            ih = min(single - 1, int(round(hits[0] * m["fps"])))
            j = min(range(1, 5), key=lambda q: abs(idx[q] - ih))
            idx[j] = ih
        tw, th = int(w * 0.62), int(h * 0.62)
        row = Image.new("RGB", (tw * 6, th + 34), (26, 30, 38))
        dr = ImageDraw.Draw(row)
        dr.text((10, 6), LABELS.get(name, name), font=f_sub, fill=(250, 246, 236))
        for q, i in enumerate(idx):
            row.paste(frames[i][0].resize((tw, th), Image.LANCZOS), (q * tw, 34))
        rows.append(row)
        # petite pause noire entre deux animations
        for _ in range(6):
            Image.new("RGB", (w * 2, h + head + 10), (26, 30, 38)).save(os.path.join(vid, "f%05d.png" % k))
            k += 1
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (26, 30, 38))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    out_sheet = os.path.join(outdir, "%s_planche.jpg" % species)
    save_jpg(sheet, out_sheet, 500)
    out_mp4 = os.path.join(outdir, "%s_animations.mp4" % species)
    subprocess.run([ffmpeg_exe(), "-y", "-loglevel", "error", "-framerate", "24", "-i", os.path.join(vid, "f%05d.png"),
                    "-vf", "format=yuv420p", "-c:v", "libx264", "-preset", "slow", "-crf", "24", "-tune", "animation",
                    out_mp4], check=True)
    print("[post] planche :", out_sheet, "%.0f Ko" % (os.path.getsize(out_sheet) / 1024))
    print("[post] vidéo   :", out_mp4, "%.0f Ko" % (os.path.getsize(out_mp4) / 1024))
    return out_sheet, out_mp4


if __name__ == "__main__":
    sp, tmpdir, what = sys.argv[1], sys.argv[2], sys.argv[3]
    od = os.path.join(MODELS, "previews", sp)
    if what == "stills":
        stills(sp, tmpdir, od)
    else:
        anim(sp, tmpdir, od)
