#!/usr/bin/env python3
"""Turns a Godot-exported golden JSON in tests/ into the .luau table the pure tests require. Never edit either by hand.
Usage (from roblox_port/): python3 tools/reference_to_luau.py tests/camera_reference.json"""
import json, keyword, pathlib, re, sys

LUA_KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue", "type", "export"}


def key(k):
    return k if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k) and k not in LUA_KEYWORDS else "[" + json.dumps(k) + "]"


def lua(v, ind=1):
    pad = "\t" * ind
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, (int, float)):
        return repr(float(v))
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x, ind + 1) for x in v) + " }"
    items = [f"{pad}{key(k)} = {lua(x, ind + 1)}," for k, x in v.items()]
    return "{\n" + "\n".join(items) + "\n" + "\t" * (ind - 1) + "}"


src = pathlib.Path(sys.argv[1])
doc = json.loads(src.read_text())
out = src.with_suffix(".luau")
out.write_text(f"-- GENERATED from tests/{src.name} by tools/reference_to_luau.py. Regenerate both together.\nreturn " + lua(doc) + "\n")
print("wrote", out)
