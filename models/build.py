"""Fabrique une ou plusieurs espèces : modèle voxel, animations Blender, module Luau et aperçus.

    python models/build.py Velociraptor                 # tout : contrôle, animations, export, planche + vidéo
    python models/build.py Velociraptor --stills        # seulement les rendus de contrôle au repos
    python models/build.py Velociraptor --bake          # animations + export Luau, sans aucun rendu
    python models/build.py Velociraptor --clips Walk,Run   # seulement ces animations (aperçus partiels)

Il faut Blender 5.2 (chemin ci-dessous ou variable BLENDER) et, dans le Python du système, Pillow et imageio-ffmpeg.
Sorties : src/shared/DinoModels/<Espece>.luau, models/previews/<Espece>/, models/species/blend/<Espece>.blend."""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.environ.get("BLENDER", r"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")


def run(species, mode, clips, keep):
    tmp = os.path.join(tempfile.gettempdir(), "saf_models", species)
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)
    t0 = time.time()
    cmd = [BLENDER, "--background", "--factory-startup", "--python", os.path.join(HERE, "lib", "blender_job.py"), "--",
           species, mode, tmp, clips or ""]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    for line in proc.stdout.splitlines():
        if line.startswith(("[job]", "   ", "[vox]", "Traceback", "  File", "    ")) or "Error" in line:
            print(line)
    if proc.returncode != 0:
        print(proc.stderr[-4000:])
        raise SystemExit("Blender a échoué pour %s" % species)
    post = [sys.executable, os.path.join(HERE, "lib", "post.py"), species, tmp]
    if mode in ("stills", "all"):
        subprocess.run(post + ["stills"], check=True)
    if mode in ("anim", "all"):
        subprocess.run(post + ["anim"], check=True)
    print("[build] %s fini en %.0f s" % (species, time.time() - t0))
    if not keep:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("species", nargs="+")
    ap.add_argument("--stills", action="store_true")
    ap.add_argument("--bake", action="store_true")
    ap.add_argument("--anim", action="store_true", help="animations sans les rendus de contrôle")
    ap.add_argument("--clips", default="")
    ap.add_argument("--keep", action="store_true", help="garder les images brutes")
    a = ap.parse_args()
    mode = "stills" if a.stills else "bake" if a.bake else "anim" if (a.anim or a.clips) else "all"
    for sp in a.species:
        run(sp, mode, a.clips, a.keep)


if __name__ == "__main__":
    main()
