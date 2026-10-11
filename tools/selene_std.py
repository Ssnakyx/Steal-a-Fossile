#!/usr/bin/env python3
"""Génère roblox.yml (la bibliothèque Roblox de selene) sans le téléchargement intégré de selene.

    python3 tools/selene_std.py

Selene télécharge lui-même l'API de Roblox (`selene generate-roblox-std`), mais avec ses propres certificats : derrière
un proxy qui réécrit le HTTPS (environnements cloud), ça échoue. Ce script fait la même chose que le générateur de selene
(selene/src/roblox/generate_std.rs, même version que rokit.toml) avec Python, qui utilise les certificats du système.
tools/setup_tools.py l'appelle seulement si `selene generate-roblox-std` échoue. Le fichier va à la racine du repo
(ignoré par git) ; selene le prend dès qu'il existe.
"""
import json
import os
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_DUMP = "https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json"
BASE = "https://raw.githubusercontent.com/Kampfkarren/selene/%s/selene-lib/default_std/roblox_base.yml"
CUSTOM_METHODS = ("CFrame", "UDim", "UDim2", "Vector2", "Vector3")


def fetch(url):
    with urllib.request.urlopen(url, timeout=300) as response:
        return response.read()


def generate(dump, base, selene_version):
    std = base
    globals_ = std.setdefault("globals", {})
    structs = std.setdefault("structs", {})
    classes = {c["Name"]: c for c in dump["Classes"]}

    def write_class_struct(name):
        if name in structs:
            return
        structs[name] = {}
        table = {"*": {"struct": "Instance"}}
        write_members(table, name)
        structs[name] = table

    def write_members(table, class_name):
        cls = classes[class_name]
        for member in cls["Members"]:
            kind = member.get("MemberType")
            tags = member.get("Tags") or []
            if kind == "Callback":
                field = {"property": "override-fields"}
            elif kind == "Event":
                field = {"struct": "Event"}
            elif kind == "Function":
                field = {"args": [{"required": False, "type": "any"} for _ in member.get("Parameters", [])], "method": True}
            elif kind == "Property":
                security = member.get("Security")
                if isinstance(security, dict) and security.get("Read", "None") == "None" and security.get("Write", "None") == "None":
                    default = {"property": "read-only" if "ReadOnly" in tags else "override-fields"}
                    value_type = member.get("ValueType") or {}
                    category = value_type.get("Category")
                    if category == "Class":
                        write_class_struct(value_type["Name"])
                        field = {"struct": value_type["Name"]}
                    elif category == "DataType" and value_type.get("Name") in CUSTOM_METHODS:
                        field = {"any": True}
                    else:
                        field = default
                else:
                    field = None
            else:
                continue
            if field is not None:
                if "Deprecated" in tags:
                    field["deprecated"] = {"message": "this property is deprecated.", "replace": []}
                table[member["Name"]] = field
        if cls["Superclass"] != "<<<ROOT>>>":
            write_members(table, cls["Superclass"])

    def write_class(global_name, class_name):
        write_class_struct(class_name)
        globals_[global_name] = {"struct": class_name}

    write_class("game", "DataModel")
    write_class("plugin", "Plugin")
    write_class("script", "Script")
    write_class("workspace", "Workspace")

    for enum in dump["Enums"]:
        name = enum["Name"]
        globals_["Enum.%s.GetEnumItems" % name] = {"args": [], "method": True, "must_use": True}
        globals_["Enum.%s.FromName" % name] = {"args": [{"required": False, "type": "string"}], "method": True, "must_use": True}
        globals_["Enum.%s.FromValue" % name] = {"args": [{"required": False, "type": "number"}], "method": True, "must_use": True}
        for item in enum["Items"]:
            globals_["Enum.%s.%s" % (name, item["Name"])] = {"struct": "EnumItem"}
            for legacy in item.get("LegacyNames", []):
                globals_["Enum.%s.%s" % (name, legacy)] = {
                    "struct": "EnumItem",
                    "deprecated": {
                        "message": "Enum.%s.%s was replaced with Enum.%s.%s" % (name, legacy, name, item["Name"]),
                        "replace": ["Enum.%s.%s" % (name, item["Name"])],
                    },
                }

    creatable = [c["Name"] for c in dump["Classes"] if "NotCreatable" not in (c.get("Tags") or [])]
    globals_["Instance.new"] = {
        "args": [
            {"type": creatable},
            {"required": False, "type": {"display": "Instance"}, "deprecated": {"message": "set the instance's parent separately", "replace": []}},
        ],
        "must_use": True,
    }

    services = [c["Name"] for c in dump["Classes"] if "Service" in (c.get("Tags") or [])]
    structs["DataModel"]["GetService"] = {"args": [{"type": services}], "method": True, "must_use": True}

    roblox_classes = {}
    for cls in dump["Classes"]:
        events = [m["Name"] for m in cls["Members"] if m.get("MemberType") == "Event"]
        properties = [m["Name"] for m in cls["Members"] if m.get("MemberType") == "Property"]
        roblox_classes[cls["Name"]] = {"superclass": cls["Superclass"], "events": events, "properties": properties}
    std["roblox_classes"] = roblox_classes
    std["last_updated"] = int(time.time())
    std["last_selene_version"] = selene_version
    return std


def write(selene_version, target=None):
    import yaml  # (PyYAML, seulement pour ce secours)

    base = yaml.safe_load(fetch(BASE % selene_version).decode("utf-8"))
    dump = json.loads(fetch(API_DUMP).decode("utf-8"))
    std = generate(dump, base, selene_version)
    target = target or os.path.join(ROOT, "roblox.yml")
    with open(target, "w", encoding="utf-8") as out:
        out.write("# This file was generated by tools/selene_std.py (port of selene generate-roblox-std)\n")
        yaml.safe_dump(std, out, sort_keys=True, allow_unicode=True, width=1000)
    return target


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import setup_tools

    print(write(setup_tools.rokit_versions()["selene"]))
