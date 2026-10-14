#!/usr/bin/env python3
"""Runs tests/run.luau under the plain `luau` CLI. The CLI sandboxes globals per module, so this bundles the Vector3/CFrame
shim and the pure shared modules into one chunk where they are ordinary upvalues. Usage (from roblox_port/):
    python3 tests/run.py [path/to/luau]"""
import pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "src" / "Shared"


def chunk(path):
    text = path.read_text()
    text = re.sub(r"^--!strict\n", "", text)
    text = re.sub(r"^export type", "type", text, flags=re.M)
    return f"(function()\n{text}\nend)()"


body = (HERE / "run.luau").read_text()
body = body.replace('local shim = require("./shim")', "local shim = " + chunk(HERE / "shim.luau"))
body = body.replace('_G.Vector3 = shim.Vector3', 'Vector3 = shim.Vector3')
body = body.replace('_G.CFrame = shim.CFrame', 'CFrame = shim.CFrame')
body = body.replace('require("../src/Shared/Movement/JumpMath")', chunk(SRC / "Movement" / "JumpMath.luau"))
body = body.replace('require("../src/Shared/Movement/SupportMath")', chunk(SRC / "Movement" / "SupportMath.luau"))
body = body.replace('require("./jump_reference")', chunk(HERE / "jump_reference.luau"))
body = "local Vector3, CFrame\n" + body.replace("\nVector3 = shim", "\nVector3 = shim").replace("_G.", "")
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(body)
luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
sys.exit(subprocess.call([luau, f.name]))
