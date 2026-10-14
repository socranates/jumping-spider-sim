#!/usr/bin/env python3
"""Runs the pure Luau checks under the plain `luau` CLI (no Roblox engine).
The CLI sandboxes globals per module, so this bundles the Vector3/CFrame shim (tests/shim.luau), the Godot-exported
reference tables and the shared modules into one chunk, where each module is an ordinary local value. Then it runs
tests/run.luau (pure logic and goldens), tests/scenarios.luau (recovery scenarios against a box-world emulation of
raycasts and sphere casts: a smoke test of the real motor, silk and camera code, not the Roblox engine) and
tests/client_smoke.luau (the client scripts themselves, driven through stub services and simulated keys).
Usage (from roblox_port/):  python3 tests/run.py [path/to/luau]"""
import pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "src" / "Shared"

# Shared modules in dependency order: name -> path under src/Shared.
MODULES = [
    ("Appearances", "Data/Appearances.luau"),
    ("Species", "Data/Species.luau"),
    ("Surfaces", "Data/Surfaces.luau"),
    ("WindowsillLayout", "Habitat/WindowsillLayout.luau"),
    ("JumpMath", "Movement/JumpMath.luau"),
    ("SupportMath", "Movement/SupportMath.luau"),
    ("TetherMath", "Movement/TetherMath.luau"),
    ("CameraMath", "Movement/CameraMath.luau"),
    ("LineFraming", "Movement/LineFraming.luau"),
    ("InputState", "Movement/InputState.luau"),
    ("JumpInput", "Movement/JumpInput.luau"),
    ("StickCarry", "Movement/StickCarry.luau"),
    ("SilkController", "Movement/SilkController.luau"),
    ("SpiderMotor", "Movement/SpiderMotor.luau"),
    ("ControlText", "UI/ControlText.luau"),
    ("HudLayout", "UI/HudLayout.luau"),
    ("Anatomy", "Rig/Anatomy.luau"),
    ("Setae", "Rig/Setae.luau"),
    ("Idle", "Rig/Idle.luau"),
    ("SpiderCamera", "../Client/SpiderCamera.luau"),
]
# The client scripts, bundled only for tests/client_smoke.luau.
CLIENT_MODULES = [
    ("SpiderRig", "Rig/SpiderRig.luau"),
    ("SpiderInput", "../Client/SpiderInput.luau"),
    ("SpiderHud", "../Client/SpiderHud.luau"),
]
REFERENCES = ["jump_reference", "tether_reference", "camera_reference", "framing_reference"]
NAMES = {name for name, _ in MODULES + CLIENT_MODULES}


def requires(text):
    """Every require of a shared module, in any of the spellings the sources use, becomes the bundled local."""
    text = re.sub(r'require\(script\.Parent(?:\.Parent\.\w+)?\.(\w+)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\.\./src/(?:Shared/\w+|Client)/(\w+)"\)', lambda m: f"__mods.{m.group(1)}", text)
    text = re.sub(r'require\((?:[^()\n]|\([^()\n]*\))*:WaitForChild\("(\w+)"\)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\.\./src/Client/SpiderClient\.client"\)', lambda m: "(function()\nlocal script = { Parent = ClientStubs.scriptFolder }\nlocal require = function(module) return module.run end\nlocal task = { spawn = function(f, ...) f(...) end }\n" + requires(strict((HERE.parent / "src/Client/SpiderClient.client.luau").read_text(encoding="utf-8"))) + "\nend)()", text)
    text = re.sub(r'require\(Shared\.\w+\.(\w+)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\./(\w+)"\)', lambda m: f"__refs.{m.group(1)}" if m.group(1) in REFERENCES else m.group(0), text)
    text = re.sub(r'require\("\./studio/(\w+)"\)', lambda m: chunk(HERE / "studio" / (m.group(1) + ".luau")), text)
    return text


def strict(text):
    text = re.sub(r"^--!strict\n", "", text)
    return re.sub(r"^export type", "type", text, flags=re.M)


def chunk(path):
    return f"(function()\n{requires(strict(path.read_text(encoding='utf-8')))}\nend)()"


def bundle(test_file):
    parts = ["local Vector3, CFrame, Color3, workspace, Instance, Enum, RaycastParams, OverlapParams, BoxWorld, Vector2, game, UDim, UDim2, ClientStubs",
             "local time = os.clock",
             "local shim = " + chunk(HERE / "shim.luau"),
             "Vector3, CFrame, Color3, workspace, Instance, Enum, RaycastParams, OverlapParams, BoxWorld = shim.Vector3, shim.CFrame, shim.Color3, shim.workspace, shim.Instance, shim.Enum, shim.RaycastParams, shim.OverlapParams, shim.BoxWorld",
             "Vector2, game, UDim, UDim2, ClientStubs = shim.Vector2, shim.game, shim.UDim, shim.UDim2, shim.client",
             "local __refs, __mods = {}, {}"]
    for ref in REFERENCES:
        path = HERE / (ref + ".luau")
        if path.exists():
            parts.append(f"__refs.{ref} = " + chunk(path))
    for name, rel in MODULES + (CLIENT_MODULES if test_file == "client_smoke.luau" else []):
        path = SRC / rel
        if path.exists():
            parts.append(f"__mods.{name} = " + chunk(path))
    body = (HERE / test_file).read_text(encoding="utf-8")
    body = body.replace('local shim = require("./shim")', "")
    body = re.sub(r"^_G\.\w+ = shim\.\w+\n", "", body, flags=re.M)
    parts.append(requires(body))
    return "\n".join(parts) + "\n"


luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
status = 0
for test_file in ["run.luau", "scenarios.luau", "client_smoke.luau"]:
    if not (HERE / test_file).exists():
        continue
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False) as f:
        f.write(bundle(test_file))
    status = subprocess.call([luau, f.name]) or status
sys.exit(status)
