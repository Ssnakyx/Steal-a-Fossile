#!/usr/bin/env python3
"""Toutes les vérifications du projet, dans l'ordre (à lancer avant chaque commit ; la CI lance la même chose) :

    python3 tools/check.py           outils, sourcemap, luau-lsp analyze, selene, tests hors Studio, build Rojo
    python3 tools/check.py --fast    sans les tests ni le build

1. tools/setup_tools.py : les outils de rokit.toml dans tools/.bin (rien n'est retéléchargé s'ils sont à jour)
2. rojo sourcemap : sourcemap.json pour l'analyse
3. luau-lsp analyze (mode strict, types de Roblox) : aucune sortie permise
4. selene src : aucune erreur ni avertissement
5. tools/luau_tests/run.py : tous les tests hors Studio
6. rojo build : la place se construit (fichier temporaire, jamais publié)
"""
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import setup_tools  # noqa: E402


def step(title):
    print("\n== %s" % title, flush=True)


def run(command):
    return subprocess.run(command, cwd=ROOT, capture_output=True, text=True)


def main(argv):
    fast = "--fast" in argv
    failures = []
    start = time.time()

    step("Outils")
    setup_tools.ensure(quiet=False)
    tool = setup_tools.tool

    step("Sourcemap (rojo)")
    result = run([tool("rojo"), "sourcemap", "default.project.json", "--output", "sourcemap.json"])
    if result.returncode != 0:
        print(result.stdout + result.stderr)
        failures.append("rojo sourcemap")
    else:
        print("ok")

    step("Analyse (luau-lsp, strict)")
    result = run([
        tool("luau-lsp"), "analyze", "--platform=roblox", "--sourcemap=sourcemap.json",
        "--definitions=@roblox=globalTypes.d.luau", "--base-luaurc=.luaurc", "src",
    ])
    # (les lignes « [INFO] » / « [WARN] » de luau-lsp parlent de l'outil, pas du code)
    problems = [line for line in (result.stdout + result.stderr).splitlines() if line.strip() and not line.startswith("[")]
    if problems or result.returncode != 0:
        print("\n".join(problems) or result.stderr)
        failures.append("luau-lsp analyze")
    else:
        print("ok")

    step("Selene")
    result = run([tool("selene"), "--display-style", "quiet", "src"])
    if result.returncode != 0:
        print(result.stdout + result.stderr)
        failures.append("selene")
    else:
        print("ok")

    if not fast:
        step("Tests hors Studio")
        tests = subprocess.run([sys.executable, os.path.join(HERE, "luau_tests", "run.py")], cwd=ROOT)
        if tests.returncode != 0:
            failures.append("tests")

        step("Build (rojo)")
        with tempfile.TemporaryDirectory() as folder:
            result = run([tool("rojo"), "build", "default.project.json", "--output", os.path.join(folder, "StealAFossil.rbxl")])
        if result.returncode != 0:
            print(result.stdout + result.stderr)
            failures.append("rojo build")
        else:
            print("ok")

    print("\n%s (%.1f s)" % ("Tout est vert" if not failures else "ÉCHEC : " + ", ".join(failures), time.time() - start))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
