#!/usr/bin/env python3
"""Tests hors Studio : lance chaque tools/luau_tests/t_*.luau avec l'interpréteur Luau et un faux Roblox (env.luau).

    python3 tools/luau_tests/run.py              tous les tests
    python3 tools/luau_tests/run.py core loop    seulement les fichiers dont le nom contient « core » ou « loop »
    python3 tools/luau_tests/run.py -v           affiche aussi la sortie des tests qui passent

Les tests sont découverts tout seuls (t_<domaine>_<sujet>.luau) : aucune liste à tenir.
Comment ça marche : le code de src/ est copié dans un dossier temporaire avec la même arborescence ; la première ligne
de chaque module (« --!strict ») est remplacée par une ligne qui branche le faux Roblox (script, require, game, task...)
sans décaler les numéros de ligne des erreurs. L'arbre d'instances (ReplicatedStorage.Shared...) vient de
default.project.json, et les classes, propriétés et enums Roblox de globalTypes.d.luau : une propriété mal écrite ou
du mauvais type lève une erreur comme dans Studio.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
import setup_tools  # noqa: E402

CACHE = os.path.join(ROOT, "tools", ".cache")
TIMEOUT = 300
GLOBALS = [
    "script", "require", "game", "workspace", "Instance", "Enum", "task", "os", "typeof", "type", "warn", "print", "tick",
    "time", "wait", "delay", "spawn", "elapsedTime", "shared", "debug", "math", "settings", "UserSettings",
    "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "ColorSequence", "ColorSequenceKeypoint",
    "NumberSequence", "NumberSequenceKeypoint", "NumberRange", "Rect", "TweenInfo", "Font", "BrickColor", "Random",
    "DateTime", "Ray", "RaycastParams", "OverlapParams", "PhysicalProperties", "Region3", "Axes", "Faces",
    "Content", "Vector3int16", "Vector2int16", "PathWaypoint", "CatalogSearchParams", "SharedTable",
]


# ===== arbre d'instances (default.project.json) =====

def script_entry(path, name):
    """(classe, nom) d'un fichier de code, ou None si ce n'est pas un script Luau."""
    for suffix, class_name in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript"),
                               (".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")):
        if name.endswith(suffix):
            return class_name, name[: -len(suffix)]
    return None


def walk_path(rel, nodes, instance_path):
    """Ajoute à `nodes` les instances d'un dossier ou fichier `rel` (relatif au repo) placé en `instance_path`."""
    full = os.path.join(ROOT, rel)
    if os.path.isdir(full):
        init = None
        for candidate, class_name in (("init.server.luau", "Script"), ("init.client.luau", "LocalScript"), ("init.luau", "ModuleScript")):
            if os.path.exists(os.path.join(full, candidate)):
                init = (class_name, rel + "/" + candidate[: -len(".luau")])
                break
        if init:
            nodes.append({"Path": instance_path, "Class": init[0], "File": init[1]})
        elif instance_path not in [n["Path"] for n in nodes]:
            nodes.append({"Path": instance_path, "Class": "Folder"})
        for name in sorted(os.listdir(full)):
            if name.startswith(".") or name.startswith("init."):
                continue
            child = rel + "/" + name
            if os.path.isdir(os.path.join(ROOT, child)):
                walk_path(child, nodes, instance_path + "." + name)
            else:
                entry = script_entry(child, name)
                if entry:
                    nodes.append({"Path": instance_path + "." + entry[1], "Class": entry[0], "File": child.rsplit(".", 1)[0]})
    else:
        entry = script_entry(rel, os.path.basename(rel))
        if entry:
            nodes.append({"Path": instance_path, "Class": entry[0], "File": rel.rsplit(".", 1)[0]})


def walk_tree(tree, nodes, instance_path):
    if instance_path and "$className" in tree:
        nodes.append({"Path": instance_path, "Class": tree["$className"]})
    if "$path" in tree:
        walk_path(tree["$path"].replace("\\", "/").rstrip("/"), nodes, instance_path)
    for key, child in tree.items():
        if not key.startswith("$") and isinstance(child, dict):
            walk_tree(child, nodes, (instance_path + "." if instance_path else "") + key)


def manifest():
    project = json.load(open(os.path.join(ROOT, "default.project.json"), encoding="utf-8"))
    nodes = []
    walk_tree(project["tree"], nodes, "")
    # (le premier segment de chaque chemin est un service : game:GetService le crée)
    for node in nodes:
        if node.get("File") and ".lua" in node["File"]:
            node["File"] = node["File"].rsplit(".", 1)[0]
    # les nœuds en double (dossier + init) gardent le dernier
    seen = {}
    for node in nodes:
        seen[node["Path"]] = node
    return [seen[path] for path in sorted(seen, key=lambda p: (p.count("."), p))]


# ===== API Roblox (globalTypes.d.luau) =====

def parse_api(text):
    blocks = re.findall(r"^declare extern type (\w+)(?: extends (\w+))? with\n(.*?)^end", text, re.M | re.S)
    blocks += [(name, sup, "") for name, sup in re.findall(r"^declare extern type (\w+)(?: extends (\w+))? with end", text, re.M)]
    superclass = {name: sup for name, sup, _ in blocks}

    def is_instance(name):
        while name:
            if name == "Instance":
                return True
            name = superclass.get(name)
        return False

    classes, enums = {}, {}
    for name, sup, body in blocks:
        if name.startswith("Enum") and name.endswith("_INTERNAL") and sup == "Enum":
            items = re.findall(r"^\s*(\w+): Enum\w+\s*$", body, re.M)
            enums[name[4:-9]] = items
            continue
        if not (is_instance(name) or name == "Object"):
            continue
        props, events, callbacks, methods = {}, [], [], []
        for line in body.split("\n"):
            line = line.strip()
            if not line or line.startswith("@"):
                continue
            method = re.match(r"^function (\w+)\(", line)
            if method:
                methods.append(method.group(1))
                continue
            prop = re.match(r"^(\w+): (.+)$", line)
            if prop:
                key, value = prop.group(1), prop.group(2).strip()
                if value.startswith("RBXScriptSignal"):
                    events.append(key)
                elif value.startswith("(") and "->" in value:
                    callbacks.append(key)
                else:
                    props[key] = value
        classes[name] = {"Superclass": sup or "", "Properties": props, "Events": events, "Callbacks": callbacks, "Methods": methods}
    return classes, enums


def lua_value(value, indent=""):
    if isinstance(value, dict):
        if not value:
            return "{}"
        inner = indent + "\t"
        parts = []
        for key in sorted(value):
            k = key if re.match(r"^[A-Za-z_]\w*$", key) else "[%s]" % json.dumps(key)
            parts.append("%s%s = %s," % (inner, k, lua_value(value[key], inner)))
        return "{\n" + "\n".join(parts) + "\n" + indent + "}"
    if isinstance(value, list):
        return "{ " + ", ".join(lua_value(v, indent) for v in value) + " }"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    return json.dumps(value)


def api_module():
    """api.luau en cache (refait quand globalTypes.d.luau change)."""
    source = os.path.join(ROOT, "globalTypes.d.luau")
    stamp = "%d-%d" % (os.path.getsize(source), int(os.path.getmtime(source)))
    target = os.path.join(CACHE, "api.luau")
    marker = target + ".stamp"
    if os.path.exists(target) and os.path.exists(marker) and open(marker).read() == stamp:
        return open(target, encoding="utf-8").read()
    classes, enums = parse_api(open(source, encoding="utf-8").read())
    text = "-- Généré par run.py depuis globalTypes.d.luau : classes et enums de Roblox\nreturn " + lua_value({"Classes": classes, "Enums": enums}) + "\n"
    os.makedirs(CACHE, exist_ok=True)
    open(target, "w", encoding="utf-8").write(text)
    open(marker, "w").write(stamp)
    return text


# ===== copie du code avec l'en-tête =====

def header(rel_no_ext, depth):
    env_path = "../" * depth + "tools/luau_tests/env"
    names = ", ".join(GLOBALS)
    values = ", ".join("__G." + g for g in GLOBALS)
    return 'local __G = require("%s").bind("%s"); local %s = %s' % (env_path, rel_no_ext, names, values)


def copy_source(build):
    for folder, _, files in os.walk(os.path.join(ROOT, "src")):
        for name in files:
            if not (name.endswith(".luau") or name.endswith(".lua")):
                continue
            full = os.path.join(folder, name)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            rel_no_ext = rel.rsplit(".", 1)[0]
            depth = rel.count("/")
            if name.startswith("init."):
                # (pour Luau, un init.luau est le dossier lui-même : ses chemins relatifs partent du dossier parent)
                depth -= 1
            lines = open(full, encoding="utf-8").read().split("\n")
            first = lines[0] if lines else ""
            line = header(rel_no_ext, depth)
            # (la directive --!strict saute : l'interpréteur ne vérifie pas les types)
            lines[0] = line if first.startswith("--!") else line + " " + first
            target = os.path.join(build, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w", encoding="utf-8").write("\n".join(lines))


def build_tree():
    build = os.path.join(CACHE, "run")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(os.path.join(build, "tools", "luau_tests"))
    copy_source(build)
    tests_dir = os.path.join(build, "tools", "luau_tests")
    for name in os.listdir(HERE):
        if name.endswith(".luau"):
            shutil.copy(os.path.join(HERE, name), os.path.join(tests_dir, name))
    open(os.path.join(tests_dir, "api.luau"), "w", encoding="utf-8").write(api_module())
    open(os.path.join(tests_dir, "manifest.luau"), "w", encoding="utf-8").write(
        "-- Généré par run.py depuis default.project.json : arbre d'instances du jeu\nreturn " + lua_value(manifest()) + "\n"
    )
    return build


def discover(filters):
    names = sorted(n for n in os.listdir(HERE) if n.startswith("t_") and n.endswith(".luau"))
    if filters:
        names = [n for n in names if any(f in n for f in filters)]
    return names


def clean_output(text, build):
    text = text.replace(build.replace("\\", "/") + "/", "").replace(build + os.sep, "")
    return text.replace("tools/luau_tests/../../", "")


def main(argv):
    verbose = "-v" in argv
    filters = [a for a in argv if not a.startswith("-")]
    setup_tools.ensure(quiet=True)
    luau = setup_tools.tool("luau")
    build = build_tree()
    tests = discover(filters)
    if not tests:
        print("Aucun test trouvé (tools/luau_tests/t_*.luau)")
        return 1
    failed = []
    start = time.time()
    for name in tests:
        began = time.time()
        try:
            result = subprocess.run([luau, name], cwd=os.path.join(build, "tools", "luau_tests"), capture_output=True, text=True, timeout=TIMEOUT)
            output = clean_output(result.stdout + result.stderr, build)
            ok = result.returncode == 0 and "\nFAIL" not in "\n" + output
        except subprocess.TimeoutExpired as error:
            output = clean_output((error.stdout or b"").decode("utf-8", "replace") if isinstance(error.stdout, bytes) else (error.stdout or ""), build)
            output += "\n(test arrêté au bout de %d s)" % TIMEOUT
            ok = False
        summary = [line for line in output.split("\n") if line.startswith("@@ ")]
        print("%s %s (%.1f s) %s" % ("ok  " if ok else "FAIL", name, time.time() - began, summary[-1] if summary else ""))
        if not ok or verbose:
            print("\n".join("    " + line for line in output.rstrip().split("\n")))
        if not ok:
            failed.append(name)
    print("%d fichier(s) de test, %d en échec, %.1f s" % (len(tests), len(failed), time.time() - start))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
