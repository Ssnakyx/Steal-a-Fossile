#!/usr/bin/env python3
"""Aperçu de l'interface sans Studio (repris de Pet Lab Fusion et adapté) : lance les scripts d'aperçu
tools/luau_tests/p_<domaine>_<sujet>.luau avec le faux Roblox (env.luau), écrit chaque écran en HTML (ui_render.luau)
et le photographie avec Chromium (Playwright de Node).

    python3 tools/luau_tests/ui_preview.py                     tous les aperçus, PC (1280 x 720)
    python3 tools/luau_tests/ui_preview.py core_uikit --phone  ceux dont le nom contient « core_uikit », téléphone
    python3 tools/luau_tests/ui_preview.py --out dossier       dossier de sortie (par défaut tools/.cache/ui_preview)

--phone : écran de téléphone (844 x 390 points, tactile : UIKit.Touch = true), images en double résolution.
Sortie : <nom>.html et <nom>.png par écran. Ce n'est pas le rendu exact de Roblox (polices, contours) : c'est pour
juger les tailles, les positions et les chevauchements. Il faut Node et le paquet playwright (npm install -g playwright,
puis npx playwright install chromium) ; sans eux, seuls les .html sont écrits.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run  # noqa: E402

SHOT = r"""
const { chromium } = require('playwright');
(async () => {
  const [, , input, output, width, height, factor] = process.argv;
  const options = {};
  if (process.env.CHROMIUM_PATH) options.executablePath = process.env.CHROMIUM_PATH;
  const browser = await chromium.launch(options);
  const page = await browser.newPage({ viewport: { width: parseInt(width), height: parseInt(height) }, deviceScaleFactor: parseInt(factor || '1') });
  await page.goto('file://' + input);
  await page.screenshot({ path: output, fullPage: true });
  await browser.close();
})();
"""


def node_env():
    """Variables pour que Node trouve playwright installé globalement (et Chromium s'il est déjà là)."""
    env = dict(os.environ)
    try:
        root = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip()
    except OSError:
        root = ""
    paths = [p for p in (root, "/opt/node22/lib/node_modules", env.get("NODE_PATH", "")) if p]
    env["NODE_PATH"] = os.pathsep.join(paths)
    for candidate in ("/opt/pw-browsers/chromium", "/opt/pw-browsers/chromium-linux/chrome"):
        if os.path.exists(candidate) and "CHROMIUM_PATH" not in env:
            env["CHROMIUM_PATH"] = candidate
    return env


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("filters", nargs="*")
    ap.add_argument("--out", default=os.path.join(run.CACHE, "ui_preview"))
    ap.add_argument("--phone", action="store_true", help="écran de téléphone simulé")
    ap.add_argument("--icons", help="dossier d'images <nom>.png des icônes de UIKit.Icons (sinon : cases grises)")
    args = ap.parse_args(argv)
    run.setup_tools.ensure(quiet=True)
    luau = run.setup_tools.tool("luau")
    build = run.build_tree()
    tests_dir = os.path.join(build, "tools", "luau_tests")
    open(os.path.join(tests_dir, "preview_options.luau"), "w").write("return { Phone = %s }\n" % ("true" if args.phone else "false"))
    icons = {}
    if args.icons:
        source = open(os.path.join(run.ROOT, "src", "client", "UI", "UIKit.luau"), encoding="utf-8").read()
        block = source[source.index("UIKit.Icons = {"):]
        block = block[:block.index("}")]
        for name, asset in re.findall(r'(\w+) = "(rbxassetid://\d+)"', block):
            path = os.path.abspath(os.path.join(args.icons, name + ".png"))
            if os.path.exists(path):
                icons[asset] = '<img src="file:///%s">' % path.replace(os.sep, "/")
    lines = ["return {"] + ['\t["%s"] = [[%s]],' % item for item in icons.items()] + ["}"]
    open(os.path.join(tests_dir, "preview_icons.luau"), "w").write("\n".join(lines) + "\n")
    scripts = sorted(n for n in os.listdir(HERE) if n.startswith("p_") and n.endswith(".luau"))
    if args.filters:
        scripts = [n for n in scripts if any(f in n for f in args.filters)]
    if not scripts:
        print("Aucun aperçu trouvé (tools/luau_tests/p_*.luau)")
        return 1
    os.makedirs(args.out, exist_ok=True)
    shot = os.path.join(args.out, "_shot.js")
    open(shot, "w").write(SHOT)
    env = node_env()
    can_shoot = shutil.which("node") is not None
    width, height = (844, 390) if args.phone else (1280, 720)
    suffix = "_phone" if args.phone else ""
    failed = False
    for script in scripts:
        proc = subprocess.run([luau, script], cwd=tests_dir, capture_output=True, text=True, timeout=run.TIMEOUT)
        if proc.returncode != 0:
            print("FAIL", script)
            print(run.clean_output(proc.stdout[-2000:] + proc.stderr[-3000:], build))
            failed = True
            continue
        for name, html in re.findall(r"@@HTML (\S+)\n(.*?)\n@@END", proc.stdout, re.S):
            path = os.path.abspath(os.path.join(args.out, name + suffix + ".html"))
            open(path, "w", encoding="utf-8").write(html)
            if can_shoot:
                image = path[:-5] + ".png"
                result = subprocess.run(["node", shot, path, image, str(width), str(height), "2" if args.phone else "1"], env=env, capture_output=True, text=True)
                if result.returncode != 0:
                    print("  capture impossible (playwright ?) :", result.stderr.strip().split("\n")[-1])
                    can_shoot = False
                else:
                    print("écran", image)
                    continue
            print("écran", path)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
