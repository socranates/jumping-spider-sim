#!/usr/bin/env python3
"""Run the real source modules and fixture suites under the plain Luau CLI.

Modules are registered from src and loaded on first require, as in Roblox. The
server and shared RequestAdmissionFacade exports keep distinct identities.
Engine services, rendering and storage are supplied by tests/shim.luau: these
checks do not establish native FPS, physics, audio or real DataStore behavior.
The preview tools can still import bundle(path) without running the CLI.
Usage: python tests/run.py [path/to/luau [suite.luau ...]] (default: all suites).
"""
import os, pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "src" / "Shared"

def discover_modules():
    """Include every real ModuleScript; entry Scripts keep their explicit paths."""
    source_root = SRC.parent
    found = {}
    for path in sorted(source_root.rglob("*.luau")):
        if path.name.endswith((".server.luau", ".client.luau")):
            continue
        name = path.stem
        if name == "RequestAdmissionFacade":
            name = path.relative_to(source_root).parts[0] + "_" + name
        if name in found:
            raise ValueError(f"Duplicate bundled module {name}: {found[name]} and {path}")
        found[name] = path
    return [(name, os.path.relpath(path, SRC).replace(os.sep, "/"))
            for name, path in sorted(found.items())]


MODULES = discover_modules()
CLIENT_MODULES = []  # All modules are available lazily; retained for preview callers.
CLIENT_TESTS = {"recovery_application.luau","local_return.luau","local_rest_client.luau","continuation_menu.luau","navigation_startup.luau","save_notice.luau","outdoor_life_reset.luau","rare_sightings.luau","feeding_survival.luau","station_debug.luau","minimal_hud.luau","living_world.luau","bodies.luau", "shadows.luau", "preserve.luau", "selftest_preserve.luau", "quiet.luau", "lock.luau", "title.luau", "nature_client.luau", "selftest.luau", "garden_life.luau", "world_client.luau","state_client.luau","state_offline.luau","growth.luau","perception_client.luau", "client_smoke.luau", "client_ant.luau", "client_rival.luau", "client_mating.luau", "look.luau", "idle.luau", "world.luau", "flies.luau", "eyes.luau", "hud.luau", "wasp.luau", "notebook.luau", "settings.luau", "inspect.luau"}
REFERENCES = ["route_preparation_reference","compact_legacy_fixture","jump_reference", "tether_reference", "camera_reference", "framing_reference", "perception_reference", "prey_reference", "life_reference", "wasp_reference", "continuing_reference", "growth_reference", "notebook_reference", "notebook_godot"]
# A reference only the named tests read (it is large; the other bundles leave it out).
REFERENCE_ONLY = {"route_preparation_reference": {"route_preparation.luau"},"compact_legacy_fixture": {"compact_layout.luau"},"continuing_reference": {"continuing.luau"},"prey_reference": {"prey.luau"}, "perception_reference": {"perception.luau"}, "life_reference": {"life.luau"}, "wasp_reference": {"wasp.luau"}, "notebook_reference": {"notebook.luau"}, "notebook_godot": {"notebook.luau"}}
NAMES = {name for name, _ in MODULES + CLIENT_MODULES}
REFERENCES.append("rig_hair_reference")
REFERENCE_ONLY["rig_hair_reference"] = {"rig_hair_cache.luau"}


def source_import(match):
    category, name = match.groups()
    if name == "RequestAdmissionFacade":
        name = category.split("/")[0] + "_" + name
    return f"__mods.{name}"


def requires(text):
    """Every require of a shared module, in any of the spellings the sources use, becomes the bundled local."""
    old = 'assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client failed to load")'
    new = 'do local okay,problem=pcall(function() require("../src/Client/SpiderClient.client") end);assert(okay,"client failed to load: "..tostring(problem))end'
    text = text.replace(old, new)
    text = re.sub(r'require\(script\.Parent(?:\.Parent\.\w+)?\.(\w+)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\.\./src/(Shared/\w+|Client|Server|First)/(\w+)"\)', source_import, text)
    text = re.sub(r'require\((?:[^()\n]|\([^()\n]*\))*:WaitForChild\("(\w+)"\)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\.\./src/Client/SpiderClient\.client"\)', lambda m: "(function()\nlocal script = { Parent = ClientStubs.scriptFolder }\nlocal require = function(module) return module.run end\nlocal task = { spawn = function(f, ...) f(...) end, wait = function() end }\n" + requires(strict((HERE.parent / "src/Client/SpiderClient.client.luau").read_text(encoding="utf-8"))) + "\nend)()", text)
    text = re.sub(r'require\(Shared\.\w+\.(\w+)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\./(\w+)"\)', lambda m: f"__refs.{m.group(1)}" if m.group(1) in REFERENCES else m.group(0), text)
    text = re.sub(r'require\("\./studio/(\w+)"\)', lambda m: chunk(HERE / "studio" / (m.group(1) + ".luau")), text)
    return text


def strict(text):
    text = re.sub(r"^--!strict\n", "", text)
    return re.sub(r"^export type", "type", text, flags=re.M)


def chunk(path):
    path = pathlib.Path(path)
    code = path.read_text(encoding="utf-8")
    source_root = SRC.parent.resolve()
    resolved = path.resolve()
    if resolved.is_relative_to(source_root):
        side = resolved.relative_to(source_root).parts[0]
        if side in ("Server", "Shared"):
            code = code.replace('require(script.Parent.RequestAdmissionFacade)',
                                '__mods.' + side + '_RequestAdmissionFacade')
    code = requires(strict(code))
    if re.search(r'require\([^\n]*RequestAdmissionFacade', code):
        raise ValueError(f"Unresolved admission facade in {path}")
    return "(function()\n" + code + "\nend)()"


LAZY_MODULES = '''local __refs, __mods = {}, {}
local __loaders, __loading = {}, {}
setmetatable(__mods,{__index=function(self,key)
 local load=assert(__loaders[key],"missing bundled module: "..tostring(key))
 assert(not __loading[key],"circular eager module load: "..tostring(key))
 __loading[key]=true;local value=load();__loading[key]=nil
 assert(value~=nil,"nil bundled module: "..tostring(key));rawset(self,key,value);return value
end})'''


def bundle(test_file):
    parts = ["local Vector3, CFrame, Color3, workspace, Instance, Enum, RaycastParams, OverlapParams, BoxWorld, Vector2, game, UDim, UDim2, ClientStubs",
             "local NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint, Font",
             "local time = os.clock",
             "local shim = " + chunk(HERE / "shim.luau"),
             "Vector3, CFrame, Color3, workspace, Instance, Enum, RaycastParams, OverlapParams, BoxWorld = shim.Vector3, shim.CFrame, shim.Color3, shim.workspace, shim.Instance, shim.Enum, shim.RaycastParams, shim.OverlapParams, shim.BoxWorld",
             "Vector2, game, UDim, UDim2, ClientStubs = shim.Vector2, shim.game, shim.UDim, shim.UDim2, shim.client",
             "NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint, Font = shim.NumberRange, shim.NumberSequence, shim.NumberSequenceKeypoint, shim.ColorSequence, shim.ColorSequenceKeypoint, shim.Font",
             LAZY_MODULES]
    for ref in REFERENCES:
        path = HERE / (ref + ".luau")
        if test_file in REFERENCE_ONLY.get(ref, {test_file}):
            # The frozen rig imports live dependencies; defer it until every
            # module loader is registered, without eagerly loading other suites.
            value = chunk(path)
            if ref == "rig_hair_reference":
                value = "function() return " + value + " end"
            parts.append(f"__refs.{ref} = " + value)
    for name, rel in MODULES + (CLIENT_MODULES if test_file in CLIENT_TESTS else []):
        path = SRC / rel
        parts.append(f"__loaders.{name} = function() return " + chunk(path) + " end")
    body = (HERE / test_file).read_text(encoding="utf-8")
    body = body.replace('local shim = require("./shim")', "")
    body = re.sub(r"^_G\.\w+ = shim\.\w+\n", "", body, flags=re.M)
    parts.append(requires(body))
    return "\n".join(parts) + "\n"


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    status = 0
    named = sys.argv[2:]
    for test_file in named or ["hunger_veil.luau","instars.luau","rig_hair_cache.luau","recovery_application.luau","recovery_templates.luau","json_encoding.luau","local_return.luau","local_rest_client.luau","local_rest.luau","save_offers.luau","save_restore.luau","save_work.luau","continuation_menu.luau","save_continuation.luau","save_intent.luau","save_observation.luau","navigation_startup.luau","save_notice.luau","outdoor_life_reset.luau","rest_compression.luau","rest_storage.luau","foundation.luau","rare_sightings.luau","spawn_clearance.luau","feeding_survival.luau","run.luau", "perception.luau", "sensor.luau", "prey.luau", "life.luau", "checkpoint.luau", "wasp.luau", "gaze.luau", "perception_view.luau", "scenarios.luau", "client_smoke.luau", "perception_client.luau", "client_ant.luau", "client_rival.luau", "client_mating.luau", "look.luau", "idle.luau", "world.luau", "flies.luau", "eyes.luau", "hud.luau", "peacock.luau", "antmimic.luau", "tarantula.luau", "continuing.luau", "growth.luau", "notebook.luau", "state.luau", "state_client.luau", "state_offline.luau", "settings.luau", "rival.luau", "rivalnav.luau", "mating.luau", "inspect.luau", "worldmap.luau", "world_client.luau", "garden_life.luau", "selftest.luau", "nature.luau", "nature_client.luau", "title.luau", "lock.luau", "quiet.luau", "preserve.luau", "selftest_preserve.luau", "shadows.luau", "bodies.luau", "living_world.luau", "station_threats.luau", "minimal_hud.luau", "compact_layout.luau", "verge_litter.luau", "route_preparation.luau", "dog_gait.luau", "station_debug.luau", "menu_overflow.luau"]:
        if not (HERE / test_file).exists():
            print(f"no such test file: {test_file} (names are relative to tests/, for example look.luau)", file=sys.stderr)
            status = 1
            continue
        source = bundle(test_file)  # fail before creating a temporary file if an input is missing
        with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False) as f:
            f.write(source)
        try:
            status = subprocess.call([luau, f.name]) or status
        finally:
            pathlib.Path(f.name).unlink(missing_ok=True)
    sys.exit(status)


if __name__ == "__main__":  # tools/preview/scene.py imports this file for its bundler and must not run the tests
    main()
