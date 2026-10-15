#!/usr/bin/env python3
"""Off-Roblox scene preview of the Windowsill world. Runs the real Habitat/Scenery (the sill and its decor, built as Server/Main does),
the real Rig/SpiderRig (standing at the spawn, Layout.SPAWN facing Layout.SPAWN_HEADING, and once mid-sill) and the real
Client/FlyBodies (one fly standing on the sill floor, one in the air) under the test shim (tests/shim.luau, bundled by tests/run.py),
dumps every visible part (size, CFrame, colour, transparency, material, shape, SpecialMesh type and scale, reflectance) and renders
them in Godot 4 from a few cameras: a sun from behind the window (30 degrees high, 30 degrees off straight out of the window,
shining in), warm ambient light, a filmic tonemap, soft shadows, a sky background, and rough stand-ins for Roblox's materials.
This is a layout and colour preview, NOT Roblox rendering: Roblox's PBR textures, Future lighting, Atmosphere haze, bloom and depth of
field look different (the depth of field is not imitated at all), and Roblox Studio is the only judge of the real look.
Usage (from roblox_port/):
  python3 tools/preview/scene.py path/to/luau path/to/godot out_dir [--prefix after_] [--detail full|low] [--views game,overview,...]
         [--size 1280x720] [--format png|jpg] [--uv] [--set key=value] [--parts parts.json]
Views: corner, lip, floor, glass (close-ups of the wear), game (5 studs behind and above the spider at the spawn, default elevation, 70 degree vertical field of view), game_mid (the same
camera, the spider mid-sill), overview, planter, leaves, window (looking out of the glass from the sill), window_uv (the same with the
UV layer faded in), retreat (the crevice), fly (both flies), fly_a (the standing fly) and fly_b (the one in the air).
--parts renders an already dumped part list (for example the "before" list kept next to the images) instead of running the code."""
import argparse, importlib.util, json, math, pathlib, subprocess, sys, tempfile

sys.dont_write_bytecode = True  # importing tests/run.py must not leave a __pycache__ in tests/

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]  # roblox_port/

ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
ap.add_argument("luau"); ap.add_argument("godot"); ap.add_argument("out")
ap.add_argument("--prefix", default="")
ap.add_argument("--detail", default="full")
ap.add_argument("--views", default="game,game_mid,overview,planter,leaves,window,retreat,fly")
ap.add_argument("--size", default="1280x720")
ap.add_argument("--format", default="png")
ap.add_argument("--uv", action="store_true", help="also show the UV layer (as the eye-view helper does) in every view")
ap.add_argument("--parts", default="")
ap.add_argument("--elevation", type=float, default=30.0, help="sun elevation, degrees")
ap.add_argument("--set", action="append", default=[], help="lighting knob for scene.gd, key=value (energy, ambient, bias, nbias, blur)")
ap.add_argument("--azimuth", type=float, default=30.0, help="degrees off straight out of the window (-Z); positive turns toward +X")
args = ap.parse_args()
out = pathlib.Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)

SPIDERS = [
    {"name": "spawn", "x": -22.0, "z": 6.0, "hx": 1, "hz": 0},   # Layout.SPAWN, Layout.SPAWN_HEADING
    {"name": "mid", "x": -9.0, "z": 5.5, "hx": 1, "hz": 0},
]
FLIES = [
    {"id": "fly_a", "x": -16.0, "y": 0.16, "z": 4.0, "hx": 1, "hy": 0, "hz": -0.35, "flying": False},  # on the sill floor, hover 0.16
    {"id": "fly_b", "x": -12.0, "y": 3.0, "z": 2.0, "hx": 1, "hy": 0.1, "hz": 0.4, "flying": True},
]


def lua(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    return "{" + ",".join(f"{k}={lua(v)}" for k, v in value.items()) + "}"


def dump_parts(path):
    spec = importlib.util.spec_from_file_location("jss_tests_run", ROOT / "tests" / "run.py")
    run = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run)
    driver = str(HERE / "scene_driver.luau")
    run.CLIENT_TESTS.add(driver)  # the driver needs the client modules (SpiderRig, FlyBodies) in its bundle
    prefix = (f'DETAIL = {lua(args.detail)}\nSUN_ELEVATION_DEG = {args.elevation}\nSUN_AZIMUTH_DEG = {args.azimuth}\n'
              f'SPIDERS = {lua(SPIDERS)}\nFLIES = {lua(FLIES)}\n')
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False, dir=out) as f:
        f.write(prefix + run.bundle(driver))
    try:
        text = subprocess.run([args.luau, f.name], capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError as e:
        sys.stderr.write(e.stdout + e.stderr)
        raise
    finally:
        pathlib.Path(f.name).unlink()
    first, _, rest = text.partition("\n")
    path.write_text(rest)
    (out / f"{args.prefix}counts.txt").write_text(first + "\n")
    print(first)


parts_path = pathlib.Path(args.parts).resolve() if args.parts else out / f"{args.prefix}parts.json"
if not args.parts:
    dump_parts(parts_path)

# ---------------------------------------------------------------- cameras
SUN_UNIT = None  # unit vector toward the sun, for the views that want to look at it


def game_camera(x, z, hx, hz, fov=70.0):
    """The game camera (CameraMath: pivot 0.45 over the body, boom 5 studs, elevation 18 degrees) looking at the pivot."""
    elev, boom, pivot_h = math.radians(18.0), 5.0, 0.45
    pivot = (x, 0.31 + pivot_h, z)
    back = (-hx, -hz)
    eye = (pivot[0] + back[0] * boom * math.cos(elev), pivot[1] + boom * math.sin(elev), pivot[2] + back[1] * boom * math.cos(elev))
    return {"fov": fov, "eye": list(eye), "at": list(pivot), "near": 0.05, "far": 1800}


VIEWS = {
    "game": {**game_camera(-22.0, 6.0, 1, 0), "groups": ["spawn", "flies"]},
    "game_mid": {**game_camera(-9.0, 5.5, 1, 0), "groups": ["mid", "flies"]},
    "overview": {"fov": 50, "eye": [-3, 50, 36], "at": [0, 1.5, -1], "near": 3, "far": 3000, "groups": ["spawn", "flies"], "shadow": 160},
    "planter": {"fov": 48, "eye": [9.0, 7.5, 12.5], "at": [10.0, 3.6, -3.5], "near": 0.1, "far": 1800, "groups": []},
    "leaves": {"fov": 55, "eye": [-9.0, 9.5, 13.0], "at": [-8.0, 3.0, -2.0], "near": 0.1, "far": 1800, "groups": []},
    "window": {"fov": 62, "eye": [0.0, 5.0, 6.0], "at": [0.0, 7.0, -30.0], "near": 0.1, "far": 2500, "groups": []},
    "window_uv": {"fov": 62, "eye": [0.0, 5.0, 6.0], "at": [0.0, 7.0, -30.0], "near": 0.1, "far": 2500, "groups": [], "uv": True},
    "retreat": {"fov": 52, "eye": [-15.5, 3.2, 7.5], "at": [-25.0, 1.0, 5.8], "near": 0.05, "far": 1800, "groups": []},
    "corner": {"fov": 55, "eye": [-23.0, 5.5, -1.0], "at": [-29.0, 1.2, -11.5], "near": 0.05, "far": 1800, "groups": []},
    "lip": {"fov": 50, "eye": [6.0, 3.2, 4.0], "at": [6.0, 0.4, 12.2], "near": 0.05, "far": 1800, "groups": []},
    "floor": {"fov": 52, "eye": [20.5, 5.0, 14.0], "at": [25.0, 0.0, 7.5], "near": 0.05, "far": 1800, "groups": []},
    "drops": {"fov": 36, "eye": [17.0, 4.9, -6.5], "at": [17.0, 4.9, -12.6], "near": 0.05, "far": 2500, "groups": []},
    "glass": {"fov": 40, "eye": [-14.0, 5.0, -4.0], "at": [-14.0, 5.4, -12.6], "near": 0.05, "far": 2500, "groups": []},
    "fly": {"fov": 40, "eye": [-14.0, 1.8, 10.5], "at": [-14.0, 1.6, 3.0], "near": 0.05, "far": 1800, "groups": ["flies"], "shadow": 40},
    "fly_a": {"fov": 34, "eye": [-15.0, 0.9, 5.4], "at": [-16.0, 0.2, 4.0], "near": 0.02, "far": 1800, "groups": ["flies"], "shadow": 20},
    "fly_b": {"fov": 34, "eye": [-11.0, 3.4, 3.7], "at": [-12.0, 3.0, 2.0], "near": 0.02, "far": 1800, "groups": ["flies"], "shadow": 20},
}
names = [n for n in args.views.split(",") if n]
for n in names:
    if n not in VIEWS:
        raise SystemExit(f"unknown view {n} (views: {', '.join(VIEWS)})")
views = []
for n in names:
    v = dict(VIEWS[n], name=n)
    if args.uv:
        v["uv"] = True
    views.append(v)

sun = {"el": args.elevation, "az": args.azimuth}
for kv in args.set:
    k, _, val = kv.partition("=")
    sun[k] = float(val)
config = {"views": views, "sun": sun, "format": args.format}
cfg_path = out / f"{args.prefix}views.json"
cfg_path.write_text(json.dumps(config))
print("visible parts:", len(json.loads(parts_path.read_text())))
subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", args.godot, "--path", str(HERE), "--rendering-driver", "opengl3",
                "--resolution", args.size, "-s", "scene.gd", "--", str(parts_path), str(cfg_path), str(out) + "/" + args.prefix],
               check=True, capture_output=True)
for n in names:
    png = out / f"{args.prefix}{n}.{args.format}"
    if not png.exists():
        raise SystemExit(f"Godot did not write {png}")
    print("wrote", png)
