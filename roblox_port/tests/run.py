#!/usr/bin/env python3
"""Runs the pure Luau checks under the plain `luau` CLI (no Roblox engine).
The CLI sandboxes globals per module, so this bundles the Vector3/CFrame shim (tests/shim.luau), the Godot-exported
reference tables and the shared modules into one chunk, where each module is an ordinary local value. Then it runs
tests/run.luau (pure logic and goldens), tests/scenarios.luau (recovery scenarios against a box-world emulation of
raycasts and sphere casts: a smoke test of the real motor, silk and camera code, not the Roblox engine) and
tests/client_smoke.luau (the client scripts themselves, driven through stub services and simulated keys) and
tests/look.luau (the daughter's pattern pinned, the look knobs, idle motion and part budgets of the real rig) and
tests/world.luau (the graphics table, the sun pick, the scenery, the lighting and the low-detail tier) and
tests/flies.luau (the drawn house fly: parts, proportions, legs, wings, flight pose, placement) and
tests/perception.luau (the pure perception logic against Godot's own hand-written expectations and against
tests/perception_reference.json, exported from the frozen Godot modules) and
tests/eyes.luau (the spider-eye picture: its data, the pure optics, the drawer under the shim and the real client's wiring) and
tests/hud.luau (the perception HUD's shapes and its drawer under the shim: circles, dashed rings, chevrons, labels) and
tests/life.luau (the life clock, the needs and the rest-and-sleep loop against tests/life_reference.json, from the frozen Godot code) and
tests/checkpoint.luau (the retreat checkpoint of a whole world, its refusals, and the DataStore-shaped store) and
tests/wasp.luau (the mud dauber wasp's rules against tests/wasp_reference.json, exported from the frozen Godot director, and Godot's hand-written expectations) and
tests/peacock.luau (the peacock spider's courtship dance: its documented rates, order, interruption and reduced motion) and
tests/notebook.luau (the naturalist's notebook: Godot's pages word for word, the model, the watcher, the words and layout, the panel and the client's wiring) and
tests/state.luau (persistent saves: envelope, progress and rest records, session lock, scheduler, server service) and
tests/state_client.luau (the client's saving wiring against the real service) and tests/state_offline.luau (no server at all) and
tests/settings.luau (the settings table and model, their saving, the panel, the live wiring and the touch layout).
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
    ("Flora", "Data/Flora.luau"),
    ("Wear", "Data/Wear.luau"),
    ("FlyLook", "Data/FlyLook.luau"),
    ("WaspLook", "Data/WaspLook.luau"),
    ("Shapes", "Habitat/Shapes.luau"),
    ("Plants", "Habitat/Plants.luau"),
    ("Patina", "Habitat/Patina.luau"),
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
    ("LifeText", "UI/LifeText.luau"),
    ("DayLight", "Habitat/DayLight.luau"),
    ("Eyes", "Data/Eyes.luau"),
    ("EyeOptics", "UI/EyeOptics.luau"),
    ("Anatomy", "Rig/Anatomy.luau"),
    ("Setae", "Rig/Setae.luau"),
    ("Idle", "Rig/Idle.luau"),
    ("Observation", "Perception/Observation.luau"),
    ("PerceptionMath", "Perception/PerceptionMath.luau"),
    ("Signal", "Perception/Signal.luau"),
    ("ObservationMemory", "Perception/ObservationMemory.luau"),
    ("SensorCore", "Perception/SensorCore.luau"),
    ("Sensor", "Perception/Sensor.luau"),
    ("LifeClock", "Life/LifeClock.luau"),
    ("NeedsModel", "Life/NeedsModel.luau"),
    ("Growth", "Life/Growth.luau"),
    ("LifeLoop", "Life/LifeLoop.luau"),
    ("LifeSession", "Life/LifeSession.luau"),
    ("PreyMath", "Prey/PreyMath.luau"),
    ("FlySenses", "Prey/FlySenses.luau"),
    ("PerchGraph", "Prey/PerchGraph.luau"),
    ("FlyFlight", "Prey/FlyFlight.luau"),
    ("PreyRandom", "Prey/PreyRandom.luau"),
    ("Wasp", "Data/Wasp.luau"),
    ("Peacock", "Data/Peacock.luau"),
    ("PeacockDance", "Rig/PeacockDance.luau"),
    ("SpiderChoice", "Rig/SpiderChoice.luau"),
    ("WaspDirector", "Predator/WaspDirector.luau"),
    ("WaspText", "UI/WaspText.luau"),
    ("PeacockText", "UI/PeacockText.luau"),
    ("Fly", "Prey/Fly.luau"),
    ("PreyPopulation", "Prey/PreyPopulation.luau"),
    ("Feeding", "Prey/Feeding.luau"),
    ("PreyDirector", "Prey/PreyDirector.luau"),
    ("TestTarget", "Habitat/TestTarget.luau"),
    ("FocusState", "Movement/FocusState.luau"),
    ("PerceptionText", "UI/PerceptionText.luau"),
    ("PerceptionView", "UI/PerceptionView.luau"),
    ("PerceptionShapes", "UI/PerceptionShapes.luau"),
    ("NotebookPages", "Data/NotebookPages.luau"),
    ("FieldNotebook", "Learning/FieldNotebook.luau"),
    ("NotebookWatch", "Learning/NotebookWatch.luau"),
    ("NotebookText", "UI/NotebookText.luau"),
    ("SaveText", "UI/SaveText.luau"),
    ("SettingsSpec", "Data/SettingsSpec.luau"),
    ("SettingsModel", "UI/SettingsModel.luau"),
    ("SettingsNav", "UI/SettingsNav.luau"),
    ("SettingsText", "UI/SettingsText.luau"),
    ("SaveRules", "Data/SaveRules.luau"),
    ("Json", "Persistence/Json.luau"),
    ("ObjectRecord", "Persistence/ObjectRecord.luau"),
    ("Checkpoint", "Persistence/Checkpoint.luau"),
    ("CheckpointStore", "Persistence/CheckpointStore.luau"),
    ("SaveStores", "Persistence/SaveStores.luau"),
    ("MemoryBackend", "Persistence/MemoryBackend.luau"),
    ("SaveEnvelope", "Persistence/SaveEnvelope.luau"),
    ("SaveProgress", "Persistence/SaveProgress.luau"),
    ("SaveRest", "Persistence/SaveRest.luau"),
    ("SaveScheduler", "Persistence/SaveScheduler.luau"),
    ("SaveSession", "Persistence/SaveSession.luau"),
    ("DataStoreBackend", "../Server/DataStoreBackend.luau"),
    ("SaveService", "../Server/SaveService.luau"),
    ("SpiderCamera", "../Client/SpiderCamera.luau"),
]
# The client scripts, bundled only for the tests that run the real rig and client (CLIENT_TESTS).
CLIENT_MODULES = [
    ("Soundscape", "../Client/Soundscape.luau"),
    ("OldSkins", "../Client/OldSkins.luau"),
    ("SpiderRig", "Rig/SpiderRig.luau"),
    ("SpiderInput", "../Client/SpiderInput.luau"),
    ("SpiderHud", "../Client/SpiderHud.luau"),
    ("CaughtPanel", "../Client/CaughtPanel.luau"),
    ("NotebookPanel", "../Client/NotebookPanel.luau"),
    ("SettingsPanel", "../Client/SettingsPanel.luau"),
    ("PerceptionStage", "../Client/PerceptionStage.luau"),
    ("FlyBodies", "../Client/FlyBodies.luau"),
    ("WaspBody", "../Client/WaspBody.luau"),
    ("PerceptionHud", "../Client/PerceptionHud.luau"),
    ("SpiderEyes", "../Client/SpiderEyes.luau"),
    ("SaveClient", "../Client/SaveClient.luau"),
]
CLIENT_TESTS = {"state_client.luau","state_offline.luau","growth.luau","perception_client.luau", "client_smoke.luau", "look.luau", "world.luau", "flies.luau", "eyes.luau", "hud.luau", "wasp.luau", "notebook.luau", "settings.luau"}
REFERENCES = ["jump_reference", "tether_reference", "camera_reference", "framing_reference", "perception_reference", "prey_reference", "life_reference", "wasp_reference", "continuing_reference", "growth_reference", "notebook_reference", "notebook_godot"]
# A reference only the named tests read (it is large; the other bundles leave it out).
REFERENCE_ONLY = {"continuing_reference": {"continuing.luau"},"prey_reference": {"prey.luau"}, "perception_reference": {"perception.luau"}, "life_reference": {"life.luau"}, "wasp_reference": {"wasp.luau"}, "notebook_reference": {"notebook.luau"}, "notebook_godot": {"notebook.luau"}}
NAMES = {name for name, _ in MODULES + CLIENT_MODULES}


def requires(text):
    """Every require of a shared module, in any of the spellings the sources use, becomes the bundled local."""
    text = re.sub(r'require\(script\.Parent(?:\.Parent\.\w+)?\.(\w+)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\.\./src/(?:Shared/\w+|Client|Server)/(\w+)"\)', lambda m: f"__mods.{m.group(1)}", text)
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
             "local NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint, Font",
             "local time = os.clock",
             "local shim = " + chunk(HERE / "shim.luau"),
             "Vector3, CFrame, Color3, workspace, Instance, Enum, RaycastParams, OverlapParams, BoxWorld = shim.Vector3, shim.CFrame, shim.Color3, shim.workspace, shim.Instance, shim.Enum, shim.RaycastParams, shim.OverlapParams, shim.BoxWorld",
             "Vector2, game, UDim, UDim2, ClientStubs = shim.Vector2, shim.game, shim.UDim, shim.UDim2, shim.client",
             "NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint, Font = shim.NumberRange, shim.NumberSequence, shim.NumberSequenceKeypoint, shim.ColorSequence, shim.ColorSequenceKeypoint, shim.Font",
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


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    status = 0
    named = sys.argv[2:]
    for test_file in named or ["run.luau", "perception.luau", "sensor.luau", "prey.luau", "life.luau", "checkpoint.luau", "wasp.luau", "gaze.luau", "perception_view.luau", "scenarios.luau", "client_smoke.luau", "perception_client.luau", "look.luau", "world.luau", "flies.luau", "eyes.luau", "hud.luau", "peacock.luau", "continuing.luau", "growth.luau", "notebook.luau", "state.luau", "state_client.luau", "state_offline.luau", "settings.luau"]:
        if not (HERE / test_file).exists():
            if named:  # a misspelt name must not look like a pass
                print(f"no such test file: {test_file} (names are relative to tests/, for example look.luau)", file=sys.stderr)
                status = 1
            continue
        with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False) as f:
            f.write(bundle(test_file))
        status = subprocess.call([luau, f.name]) or status
    sys.exit(status)


if __name__ == "__main__":  # tools/preview/scene.py imports this file for its bundler and must not run the tests
    main()
