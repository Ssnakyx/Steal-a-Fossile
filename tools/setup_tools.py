#!/usr/bin/env python3
"""Télécharge les outils du projet dans tools/.bin (sans Rokit), plus les types Roblox pour l'analyse.

    python3 tools/setup_tools.py

Versions : rojo, luau-lsp et selene viennent de rokit.toml ; l'interpréteur Luau (tests hors Studio) est fixé ici.
Les binaires vont dans tools/.bin/ ; globalTypes.d.luau (types de luau-lsp) et roblox.yml (bibliothèque Roblox de
selene) à la racine du repo. Tout est ignoré par git. Rien n'est retéléchargé si la bonne version est déjà là
(roblox.yml est refait chaque semaine pour suivre l'API de Roblox). Marche sous Linux, Windows et macOS.
"""
import io
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import time
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(ROOT, "tools", ".bin")
LUAU_VERSION = "0.700"  # interpréteur Luau (luau-lang/luau), pour tools/luau_tests
EXE = ".exe" if os.name == "nt" else ""


def rokit_versions():
    text = open(os.path.join(ROOT, "rokit.toml"), encoding="utf-8").read()
    versions = {}
    for name, version in re.findall(r'^([\w-]+)\s*=\s*"[^"@]+@([^"]+)"', text, re.M):
        versions[name] = version
    return versions


def system():
    name = platform.system()
    if name == "Windows":
        return "windows"
    if name == "Darwin":
        return "macos"
    return "linux"


def asset_urls():
    v = rokit_versions()
    osname = system()
    arm = platform.machine().lower() in ("arm64", "aarch64")
    luau = {"linux": "luau-ubuntu.zip", "windows": "luau-windows.zip", "macos": "luau-macos.zip"}[osname]
    lsp = {"linux": "luau-lsp-linux-x86_64.zip", "windows": "luau-lsp-win64.zip", "macos": "luau-lsp-macos.zip"}[osname]
    selene = "selene-%s-%s.zip" % (v["selene"], osname)
    rojo_os = {"linux": "linux-x86_64", "windows": "windows-x86_64", "macos": "macos-aarch64" if arm else "macos-x86_64"}[osname]
    rojo = "rojo-%s-%s.zip" % (v["rojo"], rojo_os)
    gh = "https://github.com/%s/releases/download/%s/%s"
    return {
        "luau": (LUAU_VERSION, gh % ("luau-lang/luau", LUAU_VERSION, luau), ["luau"]),
        "luau-lsp": (v["luau-lsp"], gh % ("JohnnyMorganz/luau-lsp", v["luau-lsp"], lsp), ["luau-lsp"]),
        "selene": (v["selene"], gh % ("Kampfkarren/selene", v["selene"], selene), ["selene"]),
        "rojo": (v["rojo"], gh % ("rojo-rbx/rojo", "v" + v["rojo"], rojo), ["rojo"]),
    }


def download(url):
    print("  téléchargement", url)
    with urllib.request.urlopen(url, timeout=300) as response:
        return response.read()


def install(name, version, url, binaries):
    marker = os.path.join(BIN, "." + name + ".version")
    if os.path.exists(marker) and open(marker).read().strip() == version and all(os.path.exists(os.path.join(BIN, b + EXE)) for b in binaries):
        return False
    os.makedirs(BIN, exist_ok=True)
    archive = zipfile.ZipFile(io.BytesIO(download(url)))
    for binary in binaries:
        member = next((m for m in archive.namelist() if os.path.basename(m) == binary + EXE), None)
        if member is None:
            raise SystemExit("%s introuvable dans %s" % (binary + EXE, url))
        target = os.path.join(BIN, binary + EXE)
        with archive.open(member) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)
        os.chmod(target, os.stat(target).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    open(marker, "w").write(version)
    return True


def install_types():
    version = rokit_versions()["luau-lsp"]
    target = os.path.join(ROOT, "globalTypes.d.luau")
    marker = os.path.join(BIN, ".globalTypes.version")
    if os.path.exists(target) and os.path.exists(marker) and open(marker).read().strip() == version:
        return False
    url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/%s/scripts/globalTypes.d.luau" % version
    data = download(url)
    open(target, "wb").write(data)
    os.makedirs(BIN, exist_ok=True)
    open(marker, "w").write(version)
    return True


def install_selene_std():
    version = rokit_versions()["selene"]
    target = os.path.join(ROOT, "roblox.yml")
    marker = os.path.join(BIN, ".roblox-std.version")
    fresh = os.path.exists(target) and time.time() - os.path.getmtime(target) < 7 * 86400
    if fresh and os.path.exists(marker) and open(marker).read().strip() == version:
        return False
    result = subprocess.run([tool("selene"), "generate-roblox-std"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0 or not os.path.exists(target):
        # (selene n'accepte pas les certificats d'un proxy HTTPS : même génération, faite en Python)
        print("  selene generate-roblox-std a échoué, roblox.yml généré par tools/selene_std.py")
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import selene_std

        selene_std.write(version, target)
    open(marker, "w").write(version)
    return True


def tool(name):
    """Chemin d'un outil : tools/.bin d'abord, puis le PATH (Rokit)."""
    local = os.path.join(BIN, name + EXE)
    if os.path.exists(local):
        return local
    return shutil.which(name) or local


def ensure(quiet=False):
    changed = False
    for name, (version, url, binaries) in asset_urls().items():
        if install(name, version, url, binaries):
            changed = True
            print("  %s %s installé" % (name, version))
    if install_types():
        changed = True
        print("  globalTypes.d.luau installé")
    if install_selene_std():
        changed = True
        print("  roblox.yml (selene) installé")
    if not changed and not quiet:
        print("Outils déjà à jour dans tools/.bin")
    return 0


if __name__ == "__main__":
    sys.exit(ensure())
