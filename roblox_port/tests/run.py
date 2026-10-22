#!/usr/bin/env python3
"""Runs the pure Luau checks under the plain `luau` CLI (no Roblox engine).
The CLI sandboxes globals per module, so this bundles the Vector3/CFrame shim (tests/shim.luau), the Godot-exported
reference tables and the shared modules into one chunk, where each module is an ordinary local value. Then it runs
tests/run.luau (pure logic and goldens), tests/scenarios.luau (recovery scenarios against a box-world emulation of
raycasts and sphere casts: a smoke test of the real motor, silk and camera code, not the Roblox engine) and
tests/client_smoke.luau (the client scripts themselves, driven through stub services and simulated keys) and
tests/client_ant.luau (the ant-mimicking spider through the same client: C, the antennae, the drawn walk, X, slow motion, reduced motion) and
tests/client_rival.luau (the roaming rival through the same client: it arrives, walks on its own motor, is drawn where it stands, never enters the retreat) and
tests/client_mating.luau (the mating cycle through the same client: the mate on the sill and drawn, the courtship meter in the hud, the egg sac, the hatching scene with its spiderlings, the ending card and the next generation) and
tests/rivalnav.luau (the rival's route graph and drive on the box world: places on the floor, a leaf, the planter and the wall, the retreat, stalking and the lunge, cost) and
tests/look.luau (the daughter's pattern pinned, the look knobs, idle motion and part budgets of the real rig) and
tests/idle.luau (the living motion: the abdomen's breath, grooming's seeded schedule, the attention yaw, the alarm and a tarantula's stretch) and
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
tests/antmimic.luau (the ant-mimicking spider's antennae and drawn walk: its documented numbers, the short stops, interruption and reduced motion) and
tests/tarantula.luau (the tarantulas' threat display and silk mat: its loop, order, angles and rates, interruption, slow motion and reduced motion, and the words) and
tests/notebook.luau (the naturalist's notebook: Godot's pages word for word, the model, the watcher, the words and layout, the panel and the client's wiring) and
tests/mating.luau (the mating cycle: the eligibility gate, the mate's arrival and legs, the courtship meter, the mating, the sac night, the guard days, the hatching, the next generation and their checkpoint records) and
tests/state.luau (persistent saves: envelope, progress and rest records, session lock, scheduler, server service) and
tests/state_client.luau (the client's saving wiring against the real service) and tests/state_offline.luau (no server at all) and
tests/settings.luau (the settings table and model, their saving, the panel, the live wiring and the touch layout) and
tests/inspect.luau (Inspect mode: its numbers, the camera's ease, orbit and restore, the Settings row, the hold, the lock and the reasons it ends, through the real client) and
tests/worldmap.luau (the world map: the sill as region 0, the questions about a point, a region's seed, the sill's generator and its budgets) and
tests/world_client.luau (the client's world: where its boxes are, the region the spider is in, the pace of its day, the streaming focus, and the real client on the server's World folder) and
tests/garden_life.luau (ROBLOX-96: the bed's prey director on its boxes, the gnat and the aphid, the woodlice, the world's prey per region, and the drawn gnat, aphid and woodlouse;
ROBLOX-101: the bestiary's springtails, leafhoppers, moths and crane flies, their perches per region, hops, sidesteps, dusk, the moth's slip, the crane fly's leg, and their bodies at both tiers) and
tests/selftest.luau (ROBLOX-104: the live place's Studio self-test, Client/SelfTest, run to END through the real client on the folders the server builds, and its refusals) and
tests/nature.luau (ROBLOX-106, W4: movement's cost, cover, the wasp's sliding and lingering visits, the rival's watch by the crack, courtship that can fail and the rival
that cuts in, the night in the garden, the end screen's words in Normal, and the checkpoint's new optional fields) and
tests/nature_client.luau (ROBLOX-106: the same rules through the real client on the folders the server builds: walking's cost, the cover factor, a night in the bed that
ends the life with its own card and Normal's words, a night that spares, the sill's night, and Free play without any of it) and
tests/title.luau (ROBLOX-109: the first minute: the splash and every way it ends, the drift and the intro's shots, the words, the menu's two looks, the progress
record's intro_seen, and through the real client outside the test place the title card, the music rising, a controller's keys, the intro of a new life, its
skip, Reduced Motion, a screen over it, and that it plays once in a save) and
tests/lock.luau (ROBLOX-110: lock-on and the sidestep: what can be locked and which a press takes, what ends a lock, the sidestep on a box's top, side and
underside on the real motor, the camera's goal and follow, the words and the touch button, and through the real client a lock taken only from what the
sensor has seen, the camera and the body on it, the sidestep at a creep, the aim on it, its endings, R3, the touch Lock, Reduced Motion, the eye view, and
the setting that hides the perception HUD while the lock's ticks stay) and
tests/preserve.luau (ROBLOX-115: two worlds, one engine: the worlds, the map for the active world, the preserve's map and shift, its backdrop's looks, budgets and
precision, the plan in the preserve, its drift and its trains; ROBLOX-116: the ranger hut and its garden walkable, the nursery rule) and tests/selftest_preserve.luau
(ROBLOX-115: the live place's self-test through the real client in the preserve; ROBLOX-116: the hut's inside, the way out, the garden's life) and
tests/quiet.luau (ROBLOX-113, W5: the quiet HUD: every string of the play screen classified, what Normal shows on the first day and after it, Easy's every
word, the notices line by line, the perception labels calmed, and the same through the real client).
Usage (from roblox_port/):  python3 tests/run.py [path/to/luau [test.luau ...]]   (default: all of them)"""
import pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "src" / "Shared"

# Shared modules in dependency order: name -> path under src/Shared.
MODULES = [
    ("Environment", "World/Environment.luau"),
    ("AntForage", "World/AntForage.luau"),
    ("DogGait", "Rig/DogGait.luau"),
    ("Appearances", "Data/Appearances.luau"),
    ("Species", "Data/Species.luau"),
    ("Surfaces", "Data/Surfaces.luau"),
    ("WindowsillLayout", "Habitat/WindowsillLayout.luau"),
    ("RivalRules", "Data/RivalRules.luau"),
    ("Worlds", "World/Worlds.luau"),
    ("Preserve", "World/Preserve.luau"),
    ("PreserveTrain", "World/PreserveTrain.luau"),
    ("Hut", "World/Hut.luau"),
    ("GardenPocket", "World/GardenPocket.luau"),
    ("LivedInSites", "World/LivedInSites.luau"),
    ("Meadow", "World/Meadow.luau"),
    ("Pond", "World/Pond.luau"),
    ("Verge", "World/Verge.luau"),
    ("WorldMap", "World/WorldMap.luau"),
    ("StationTerritory", "World/StationTerritory.luau"),
    ("Breakaway", "Habitat/Breakaway.luau"),
    ("Detail", "Data/Detail.luau"),
    ("Graphics", "Data/Graphics.luau"),
    ("Materials", "Habitat/Materials.luau"),
    ("Flora", "Data/Flora.luau"),
    ("Meshes", "Data/Meshes.luau"),
    ("Garden", "World/Garden.luau"),
    ("PreserveLook", "World/PreserveLook.luau"),
    ("Region", "World/Region.luau"),
    ("DogGround", "World/DogGround.luau"),
    ("StationAir", "World/StationAir.luau"),
    ("LookPlan", "World/LookPlan.luau"),
    ("Wear", "Data/Wear.luau"),
    ("FlyLook", "Data/FlyLook.luau"),
    ("WaspLook", "Data/WaspLook.luau"),
    ("Shapes", "Habitat/Shapes.luau"),
    ("Plants", "Habitat/Plants.luau"),
    ("Dressing", "Habitat/Dressing.luau"),
    ("Patina", "Habitat/Patina.luau"),
    ("SunPick", "Habitat/SunPick.luau"),
    ("Scenery", "Habitat/Scenery.luau"),
    ("WorldBuild", "World/WorldBuild.luau"),
    ("Lit", "Habitat/Lit.luau"),
    ("WorldDetail", "../Client/WorldDetail.luau"),
    ("JumpMath", "Movement/JumpMath.luau"),
    ("SupportMath", "Movement/SupportMath.luau"),
    ("TetherMath", "Movement/TetherMath.luau"),
    ("CameraMath", "Movement/CameraMath.luau"),
    ("LineFraming", "Movement/LineFraming.luau"),
    ("InspectView", "Movement/InspectView.luau"),
    ("InputState", "Movement/InputState.luau"),
    ("JumpInput", "Movement/JumpInput.luau"),
    ("StickCarry", "Movement/StickCarry.luau"),
    ("SilkController", "Movement/SilkController.luau"),
    ("SpiderMotor", "Movement/SpiderMotor.luau"),
    ("ControlText", "UI/ControlText.luau"),
    ("TitleText", "UI/TitleText.luau"),
    ("TitleShots", "Movement/TitleShots.luau"),
    ("HudLayout", "UI/HudLayout.luau"),
    ("MateText", "UI/MateText.luau"),
    ("LifeText", "UI/LifeText.luau"),
    ("DayLight", "Habitat/DayLight.luau"),
    ("Eyes", "Data/Eyes.luau"),
    ("EyeOptics", "UI/EyeOptics.luau"),
    ("Anatomy", "Rig/Anatomy.luau"),
    ("Setae", "Rig/Setae.luau"),
    ("Idle", "Rig/Idle.luau"),
    ("Living", "Rig/Living.luau"),
    ("Observation", "Perception/Observation.luau"),
    ("PerceptionMath", "Perception/PerceptionMath.luau"),
    ("Signal", "Perception/Signal.luau"),
    ("ObservationMemory", "Perception/ObservationMemory.luau"),
    ("SensorCore", "Perception/SensorCore.luau"),
    ("Sensor", "Perception/Sensor.luau"),
    ("LockOn", "Movement/LockOn.luau"),
    ("LifeClock", "Life/LifeClock.luau"),
    ("ContextPrompts", "UI/ContextPrompts.luau"),
    ("NeedsModel", "Life/NeedsModel.luau"),
    ("Growth", "Life/Growth.luau"),
    ("LifeLoop", "Life/LifeLoop.luau"),
    ("LifeSession", "Life/LifeSession.luau"),
    ("PreyMath", "Prey/PreyMath.luau"),
    ("PreyRandom", "Prey/PreyRandom.luau"),
    ("Nature", "Life/Nature.luau"),
    ("Nursery", "Life/Nursery.luau"),
    ("Ballooning", "Life/Ballooning.luau"),
    ("Water", "Life/Water.luau"),
    ("MatingRules", "Data/MatingRules.luau"),
    ("RivalRoute", "Predator/RivalRoute.luau"),
    ("RivalSpider", "Predator/RivalSpider.luau"),
    ("RivalDrive", "Predator/RivalDrive.luau"),
    ("Mate", "Predator/Mate.luau"),
    ("MateDrive", "Predator/MateDrive.luau"),
    ("Mating", "Life/Mating.luau"),
    ("MatingScene", "Life/MatingScene.luau"),
    ("FlySenses", "Prey/FlySenses.luau"),
    ("PerchGraph", "Prey/PerchGraph.luau"),
    ("FlyFlight", "Prey/FlyFlight.luau"),
    ("Wasp", "Data/Wasp.luau"),
    ("Peacock", "Data/Peacock.luau"),
    ("PeacockDance", "Rig/PeacockDance.luau"),
    ("AntMimic", "Data/AntMimic.luau"),
    ("AntMimicPose", "Rig/AntMimicPose.luau"),
    ("Tarantula", "Data/Tarantula.luau"),
    ("TarantulaPose", "Rig/TarantulaPose.luau"),
    ("CatPose", "Rig/CatPose.luau"),
    ("SpiderChoice", "Rig/SpiderChoice.luau"),
    ("WaspDirector", "Predator/WaspDirector.luau"),
    ("Cat", "Predator/Cat.luau"),
    ("StationMouse", "Prey/StationMouse.luau"),
    ("CrabSpider", "Predator/CrabSpider.luau"),
    ("Bird", "Predator/Bird.luau"),
    ("Frog", "Predator/Frog.luau"),
    ("Heard", "UI/Heard.luau"),
    ("WaspText", "UI/WaspText.luau"),
    ("CatText", "UI/CatText.luau"),
    ("CrabText", "UI/CrabText.luau"),
    ("BirdText", "UI/BirdText.luau"),
    ("FrogText", "UI/FrogText.luau"),
    ("WaterText", "UI/WaterText.luau"),
    ("RivalText", "UI/RivalText.luau"),
    ("AntMimicText", "UI/AntMimicText.luau"),
    ("TarantulaText", "UI/TarantulaText.luau"),
    ("PeacockText", "UI/PeacockText.luau"),
    ("InspectText", "UI/InspectText.luau"),
    ("PreyText", "UI/PreyText.luau"),
    ("PlantWalk", "Prey/PlantWalk.luau"),
    ("PreyKinds", "Prey/PreyKinds.luau"),
    ("Fly", "Prey/Fly.luau"),
    ("PreyPopulation", "Prey/PreyPopulation.luau"),
    ("Catch", "Data/Catch.luau"),
    ("Feeding", "Prey/Feeding.luau"),
    ("RivalGrip", "Predator/RivalGrip.luau"),
    ("RivalDisplay", "Predator/RivalDisplay.luau"),
    ("PreyDirector", "Prey/PreyDirector.luau"),
    ("Woodlouse", "Prey/Woodlouse.luau"),
    ("Ladybird", "Prey/Ladybird.luau"),
    ("Millipede", "Prey/Millipede.luau"),
    ("Snail", "Prey/Snail.luau"),
    ("Harvestman", "Prey/Harvestman.luau"),
    ("Ant", "Prey/Ant.luau"),
    ("Skater", "Prey/Skater.luau"),
    ("PreyWorld", "Prey/PreyWorld.luau"),
    ("TestTarget", "Habitat/TestTarget.luau"),
    ("FocusState", "Movement/FocusState.luau"),
    ("PerceptionText", "UI/PerceptionText.luau"),
    ("PerceptionView", "UI/PerceptionView.luau"),
    ("QuietHud", "UI/QuietHud.luau"),
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
    ("CompactMigration", "Persistence/CompactMigration.luau"),
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
    ("WorldFocus", "../Server/WorldFocus.luau"),
    ("SpiderCamera", "../Client/SpiderCamera.luau"),
]
# The client scripts, bundled only for the tests that run the real rig and client (CLIENT_TESTS).
CLIENT_MODULES = [
    ("Soundscape", "../Client/Soundscape.luau"),
    ("MealPresentation", "../Client/MealPresentation.luau"),
    ("OldSkins", "../Client/OldSkins.luau"),
    ("SpiderRig", "Rig/SpiderRig.luau"),
    ("MateStage", "../Client/MateStage.luau"),
    ("SpiderInput", "../Client/SpiderInput.luau"),
    ("SpiderHud", "../Client/SpiderHud.luau"),
    ("CaughtPanel", "../Client/CaughtPanel.luau"),
    ("TitleCard", "../Client/TitleCard.luau"),
    ("SplashScreen", "../First/SplashScreen.luau"),
    ("NotebookPanel", "../Client/NotebookPanel.luau"),
    ("SettingsPanel", "../Client/SettingsPanel.luau"),
    ("PerceptionStage", "../Client/PerceptionStage.luau"),
    ("FlyBodies", "../Client/FlyBodies.luau"),
    ("BugBodies", "../Client/BugBodies.luau"),
    ("WaspBody", "../Client/WaspBody.luau"),
    ("CatBody", "../Client/CatBody.luau"),
    ("StationMouseBody", "../Client/StationMouseBody.luau"),
    ("CrabBody", "../Client/CrabBody.luau"),
    ("BirdBody", "../Client/BirdBody.luau"),
    ("PondBodies", "../Client/PondBodies.luau"),
    ("PerceptionHud", "../Client/PerceptionHud.luau"),
    ("SpiderEyes", "../Client/SpiderEyes.luau"),
    ("SaveClient", "../Client/SaveClient.luau"),
    ("FrameProfile", "../Client/FrameProfile.luau"),
    ("LookStream", "../Client/LookStream.luau"),
    ("TrainPass", "../Client/TrainPass.luau"),
    ("HutLife", "../Client/HutLife.luau"),
    ("WorldShadows", "../Client/WorldShadows.luau"),
    ("LivingWorld", "../Client/LivingWorld.luau"),
    ("WorldClient", "../Client/WorldClient.luau"),
    ("SelfTest", "../Client/SelfTest.luau"),
]
CLIENT_TESTS = {"feeding_survival.luau","station_debug.luau","minimal_hud.luau","living_world.luau","bodies.luau", "shadows.luau", "preserve.luau", "selftest_preserve.luau", "quiet.luau", "lock.luau", "title.luau", "nature_client.luau", "selftest.luau", "garden_life.luau", "world_client.luau","state_client.luau","state_offline.luau","growth.luau","perception_client.luau", "client_smoke.luau", "client_ant.luau", "client_rival.luau", "client_mating.luau", "look.luau", "idle.luau", "world.luau", "flies.luau", "eyes.luau", "hud.luau", "wasp.luau", "notebook.luau", "settings.luau", "inspect.luau"}
REFERENCES = ["route_preparation_reference","compact_legacy_fixture","jump_reference", "tether_reference", "camera_reference", "framing_reference", "perception_reference", "prey_reference", "life_reference", "wasp_reference", "continuing_reference", "growth_reference", "notebook_reference", "notebook_godot"]
# A reference only the named tests read (it is large; the other bundles leave it out).
REFERENCE_ONLY = {"route_preparation_reference": {"route_preparation.luau"},"compact_legacy_fixture": {"compact_layout.luau"},"continuing_reference": {"continuing.luau"},"prey_reference": {"prey.luau"}, "perception_reference": {"perception.luau"}, "life_reference": {"life.luau"}, "wasp_reference": {"wasp.luau"}, "notebook_reference": {"notebook.luau"}, "notebook_godot": {"notebook.luau"}}
NAMES = {name for name, _ in MODULES + CLIENT_MODULES}


def requires(text):
    """Every require of a shared module, in any of the spellings the sources use, becomes the bundled local."""
    text = re.sub(r'require\(script\.Parent(?:\.Parent\.\w+)?\.(\w+)\)', lambda m: f"__mods.{m.group(1)}" if m.group(1) in NAMES else m.group(0), text)
    text = re.sub(r'require\("\.\./src/(?:Shared/\w+|Client|Server|First)/(\w+)"\)', lambda m: f"__mods.{m.group(1)}", text)
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
    for test_file in named or ["spawn_clearance.luau","feeding_survival.luau","run.luau", "perception.luau", "sensor.luau", "prey.luau", "life.luau", "checkpoint.luau", "wasp.luau", "gaze.luau", "perception_view.luau", "scenarios.luau", "client_smoke.luau", "perception_client.luau", "client_ant.luau", "client_rival.luau", "client_mating.luau", "look.luau", "idle.luau", "world.luau", "flies.luau", "eyes.luau", "hud.luau", "peacock.luau", "antmimic.luau", "tarantula.luau", "continuing.luau", "growth.luau", "notebook.luau", "state.luau", "state_client.luau", "state_offline.luau", "settings.luau", "rival.luau", "rivalnav.luau", "mating.luau", "inspect.luau", "worldmap.luau", "world_client.luau", "garden_life.luau", "selftest.luau", "nature.luau", "nature_client.luau", "title.luau", "lock.luau", "quiet.luau", "preserve.luau", "selftest_preserve.luau", "shadows.luau", "bodies.luau", "living_world.luau", "station_threats.luau", "minimal_hud.luau", "compact_layout.luau", "verge_litter.luau", "route_preparation.luau", "dog_gait.luau", "station_debug.luau"]:
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
