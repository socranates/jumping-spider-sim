#!/usr/bin/env python3
"""Runs the pure Luau checks under the plain `luau` CLI (no Roblox engine).
The CLI sandboxes globals per module, so this bundles the Vector3/CFrame shim (tests/shim.luau), the Godot-exported
reference tables and the shared modules into one chunk, where each module is an ordinary local value. Then it runs
tests/run.luau (pure logic and goldens), tests/scenarios.luau (recovery scenarios against a box-world emulation of
raycasts and sphere casts: a smoke test of the real motor, silk and camera code, not the Roblox engine) and
tests/client_smoke.luau (the client scripts themselves, driven through stub services and simulated keys) and
tests/look.luau (the daughter's pattern pinned, the look knobs, idle motion and part budgets of the real rig) and
tests/world.luau (the graphics table, the sun pick, the scenery, the lighting and the low-detail tier) and
tests/perception.luau (the pure perception logic against Godot's own hand-written expectations and against
tests/perception_reference.json, exported from the frozen Godot modules).
Usage (from roblox_port/):  python3 tests/run.py [path/to/luau [test.luau ...]]   (default: all of them)"""
import pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "src" / "Shared"

# Shared modules in dependency order: name -> path under src/Shared.
MODULES = [
    ("Appearances", "Data/Appearances.luau"),
    ("Species", "Data/Species.luau"),
    ("Surfaces", "Data/Surfaces.luau"),
    ("WindowsillLayout", "Habitat/WindowsillLayout.luau"),
    ("Detail", "Data/Detail.luau"),
    ("Graphics", "Data/Graphics.luau"),
    ("Materials", "Habitat/Materials.luau"),
    ("SunPick", "Habitat/SunPick.luau"),
    ("Scenery", "Habitat/Scenery.luau"),
    ("Lit", "Habitat/Lit.luau"),
    ("WorldDetail", "../Client/WorldDetail.luau"),
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
    ("Observation", "Perception/Observation.luau"),
    ("PerceptionMath", "Perception/PerceptionMath.luau"),
    ("Signal", "Perception/Signal.luau"),
    ("ObservationMemory", "Perception/ObservationMemory.luau"),
    ("SensorCore", "Perception/SensorCore.luau"),
    ("Sensor", "Perception/Sensor.luau"),
    ("TestTarget", "Habitat/TestTarget.luau"),
    ("FocusState", "Movement/FocusState.luau"),
    ("PerceptionText", "UI/PerceptionText.luau"),
    ("PerceptionView", "UI/PerceptionView.luau"),
    ("SpiderCamera", "../Client/SpiderCamera.luau"),
]
# The client scripts, bundled only for the tests that run the real rig and client (CLIENT_TESTS).
CLIENT_MODULES = [
    ("SpiderRig", "Rig/SpiderRig.luau"),
    ("SpiderInput", "../Client/SpiderInput.luau"),
    ("SpiderHud", "../Client/SpiderHud.luau"),
    ("PerceptionStage", "../Client/PerceptionStage.luau"),
    ("PerceptionHud", "../Client/PerceptionHud.luau"),
]
CLIENT_TESTS = {"perception_client.luau", "client_smoke.luau", "look.luau", "world.luau"}
REFERENCES = ["jump_reference", "tether_reference", "camera_reference", "framing_reference", "perception_reference"]
# A reference only the named tests read (it is large; the other bundles leave it out).
REFERENCE_ONLY = {"perception_reference": {"perception.luau"}}
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
             "local NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint",
             "local time = os.clock",
             "local shim = " + chunk(HERE / "shim.luau"),
             "Vector3, CFrame, Color3, workspace, Instance, Enum, RaycastParams, OverlapParams, BoxWorld = shim.Vector3, shim.CFrame, shim.Color3, shim.workspace, shim.Instance, shim.Enum, shim.RaycastParams, shim.OverlapParams, shim.BoxWorld",
             "Vector2, game, UDim, UDim2, ClientStubs = shim.Vector2, shim.game, shim.UDim, shim.UDim2, shim.client",
             "NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint = shim.NumberRange, shim.NumberSequence, shim.NumberSequenceKeypoint, shim.ColorSequence, shim.ColorSequenceKeypoint",
             "local __refs, __mods = {}, {}"]
    for ref in REFERENCES:
        path = HERE / (ref + ".luau")
        if path.exists() and test_file in REFERENCE_ONLY.get(ref, {test_file}):
            parts.append(f"__refs.{ref} = " + chunk(path))
    for name, rel in MODULES + (CLIENT_MODULES if test_file in CLIENT_TESTS else []):
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
named = sys.argv[2:]
for test_file in named or ["run.luau", "perception.luau", "sensor.luau", "gaze.luau", "perception_view.luau", "scenarios.luau", "client_smoke.luau", "perception_client.luau", "look.luau", "world.luau"]:
    if not (HERE / test_file).exists():
        if named:  # a misspelt name must not look like a pass
            print(f"no such test file: {test_file} (names are relative to tests/, for example look.luau)", file=sys.stderr)
            status = 1
        continue
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False) as f:
        f.write(bundle(test_file))
    status = subprocess.call([luau, f.name]) or status
sys.exit(status)
