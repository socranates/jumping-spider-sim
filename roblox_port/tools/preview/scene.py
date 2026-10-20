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
UV layer faded in), retreat (the crevice), fly (both flies), fly_a (the standing fly) and fly_b (the one in the air); close-ups of the
fly from above, in front and from the side: fly_top, fly_front, fly_side (standing) and fly_b_top, fly_b_side, fly_b_front (in the air); wasp, wasp_side, wasp_top, wasp_front (hovering and searching), wasp_walk (on the floor) and wasp_hold (carrying).
With --world (ROBLOX-101): bestiary_stone, bestiary_wall (the bestiary's prey in place) and spec_springtail, spec_springtail_air, spec_leafhopper, spec_moth,
spec_moth_air, spec_crane_fly, spec_crane_fly_shed, spec_crane_fly_air (each kind close on a specimen tray at x 200, at the --detail tier).
With --world (ROBLOX-105): spec_ladybird, spec_millipede, spec_snail, spec_harvestman (the tray's third row: walking and bleeding, straight and coiled, a trail and
stalks drawn in) and ambient_dock, ambient_dandelion, ambient_snail, ambient_millipede, ambient_harvestman, ambient_wall (in place, an evening).
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
ap.add_argument("--world", action="store_true", help="also build the regions outside the window (ROBLOX-95: the outer sill, the wall, the bed) for the outside views, with the bed's prey and woodlice (ROBLOX-96)")
ap.add_argument("--elevation", type=float, default=30.0, help="sun elevation, degrees")
ap.add_argument("--set", action="append", default=[], help="lighting knob for scene.gd, key=value (energy, ambient, bias, nbias, blur)")
ap.add_argument("--azimuth", type=float, default=30.0, help="degrees off straight out of the window (-Z); positive turns toward +X")
args = ap.parse_args()
out = pathlib.Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)

SPIDERS = [
    {"name": "spawn", "x": -22.0, "z": 6.0, "hx": 1, "hz": 0},   # Layout.SPAWN, Layout.SPAWN_HEADING
    {"name": "mid", "x": -9.0, "z": 5.5, "hx": 1, "hz": 0},
    # ROBLOX-95 (--world): one on the outer sill just out of the opening, one on the wall's face part way down, one in front of the bed's stone
    {"name": "out", "x": 0.0, "y": 0.31, "z": -18.0, "hx": 0, "hz": -1},
    {"name": "wall", "x": 2.0, "y": -40.0, "z": -24.31, "hx": 0, "hy": -1, "hz": 0, "up": [0, 0, -1]},
    {"name": "bed", "x": 11.0, "y": -89.69, "z": -43.5, "hx": 0, "hz": -1},
]
FLIES = [
    {"id": "fly_a", "x": -16.0, "y": 0.16, "z": 4.0, "hx": 1, "hy": 0, "hz": -0.35, "flying": False},  # on the sill floor, hover 0.16
    {"id": "fly_b", "x": -12.0, "y": 3.0, "z": 2.0, "hx": 1, "hy": 0.1, "hz": 0.4, "flying": True},
]


WASPS = [
    {"id": "wasp_a", "x": -14.0, "y": 3.0, "z": 3.0, "hx": 1.0, "hz": 0.3, "mode": "flying", "search": 0.7, "beat": 0.31},   # hovering, searching
    {"id": "wasp_b", "x": -8.0, "y": 0.35, "z": 6.0, "hx": 1.0, "hz": -0.2, "mode": "walking", "search": 1.0, "beat": 0.2},  # on the sill floor
    {"id": "wasp_c", "x": -3.0, "y": 8.0, "z": 3.0, "hx": 1.0, "hz": 0.5, "mode": "holding", "search": 0.0, "beat": 0.4},     # carrying
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
    spiders = SPIDERS if args.world else SPIDERS[:2]
    prefix = (f'DETAIL = {lua(args.detail)}\nSUN_ELEVATION_DEG = {args.elevation}\nSUN_AZIMUTH_DEG = {args.azimuth}\n'
              f'SPIDERS = {lua(spiders)}\nFLIES = {lua(FLIES)}\nWASPS = {lua(WASPS)}\nWORLD = {lua(args.world)}\n')
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
    # the spider-eye view from the spawn (eye = body + 0.09 up + 0.53 ahead; the body is not drawn), side eyes and principal eyes
    "eye_side": {"fov": 90, "eye": [-21.47, 0.39, 6.0], "at": [-12.0, 0.9, 3.2], "near": 0.02, "far": 2500, "groups": ["flies"], "shadow": 40},
    "eye_principal": {"fov": 24, "eye": [-21.47, 0.39, 6.0], "at": [-16.0, 0.22, 4.0], "near": 0.02, "far": 2500, "groups": ["flies"], "shadow": 40, "uv": True},
    "fly_b": {"fov": 34, "eye": [-11.0, 3.4, 3.7], "at": [-12.0, 3.0, 2.0], "near": 0.02, "far": 1800, "groups": ["flies"], "shadow": 20},
    # ROBLOX-95, with --world: the raised sash from the sill, the window from the outer sill, the wall from the air in front of it, the bed, the stone, the whole
    "sash": {"fov": 60, "eye": [0.0, 1.6, -5.0], "at": [0.0, 0.6, -20.0], "near": 0.05, "far": 2500, "groups": []},
    "outside": {"fov": 62, "eye": [7.0, 5.0, -23.0], "at": [0.0, 2.5, -13.0], "near": 0.05, "far": 2500, "groups": ["out"]},
    "wall": {"fov": 60, "eye": [28.0, -25.0, -75.0], "at": [0.0, -45.0, -24.0], "near": 0.1, "far": 2500, "groups": ["wall"], "shadow": 160},
    "bed": {"fov": 58, "eye": [0.0, -60.0, -100.0], "at": [0.0, -89.0, -47.0], "near": 0.1, "far": 2500, "groups": ["bed", "flies"], "shadow": 120},
    "stone": {"fov": 50, "eye": [11.0, -85.5, -39.0], "at": [11.0, -89.0, -50.0], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 40},
    # ROBLOX-96: the bed's life close up (the dock with its aphids and a gnat under a leaf, the soil with its woodlice), and the corner under the outer sill with its cobweb
    "bed_life": {"fov": 46, "eye": [-4.0, -84.5, -31.0], "at": [-12.0, -87.5, -42.0], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 40},
    "corner_web": {"fov": 36, "eye": [22.0, -1.5, -31.0], "at": [28.6, -4.2, -24.2], "near": 0.05, "far": 2500, "groups": [], "shadow": 40},
    # ROBLOX-101 (--world): the bestiary in place (the springtails round the big stone, a leafhopper on the dock, the wall's moths and crane fly, the outer sill's)
    # and on the specimen tray at x 200 (each kind close, standing and in the air, and the crane fly with a leg gone)
    "bestiary_stone": {"fov": 44, "eye": [17.0, -84.0, -37.0], "at": [11.0, -89.6, -48.0], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 40},
    "bestiary_wall": {"fov": 60, "eye": [0.0, -40.0, -60.0], "at": [0.0, -45.0, -24.0], "near": 0.1, "far": 2500, "groups": ["flies"], "shadow": 120},
    "spec_springtail": {"fov": 14, "eye": [200.35, 0.45, 0.45], "at": [200.0, 0.06, 0.0], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_springtail_air": {"fov": 14, "eye": [200.45, 1.3, -4.4], "at": [200.0, 1.06, -5.0], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_leafhopper": {"fov": 18, "eye": [203.8, 0.75, 0.9], "at": [203.0, 0.1, 0.0], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_moth": {"fov": 26, "eye": [208.9, 1.9, 1.6], "at": [208.0, 0.1, 0.0], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 6},
    "spec_moth_air": {"fov": 30, "eye": [209.5, 2.6, -3.0], "at": [208.0, 1.16, -5.0], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 6},
    "spec_crane_fly": {"fov": 40, "eye": [220.0, 4.0, 5.0], "at": [216.0, 0.2, -0.3], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 12},
    "spec_crane_fly_shed": {"fov": 40, "eye": [228.0, 4.0, 5.0], "at": [224.0, 0.2, -0.3], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 12},
    "spec_crane_fly_air": {"fov": 40, "eye": [221.0, 3.5, 0.0], "at": [216.0, 2.0, -5.0], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 12},
    "world": {"fov": 60, "eye": [75.0, -15.0, -100.0], "at": [0.0, -55.0, -30.0], "near": 1.0, "far": 4000, "groups": [], "shadow": 220},
    # ROBLOX-103 (--world): the wall above the window, its eaves and gutter; the house from the lawn; the garden from the eaves; the bushes from the outer sill;
    # details of the outer sill, the wall's foot and the bed; and the tray's second row walking (the gnat, the aphid, the house fly, the woodlouse) mid-stride
    "gutter": {"fov": 55, "eye": [22.0, 124.0, -88.0], "at": [0.0, 110.0, -58.0], "near": 0.1, "far": 5000, "groups": [], "shadow": 120},
    "eaves": {"fov": 62, "eye": [35.0, -70.0, -150.0], "at": [0.0, 55.0, -24.0], "near": 1.0, "far": 6000, "groups": [], "shadow": 300},
    "house": {"fov": 62, "eye": [160.0, -45.0, -430.0], "at": [0.0, 20.0, -24.0], "near": 1.0, "far": 6000, "groups": [], "shadow": 600},
    "garden": {"fov": 72, "eye": [0.0, 175.0, -95.0], "at": [0.0, -60.0, -700.0], "near": 1.0, "far": 6000, "groups": [], "shadow": 900},
    "bushes": {"fov": 64, "eye": [0.0, 4.0, -20.0], "at": [-80.0, -45.0, -160.0], "near": 0.1, "far": 6000, "groups": [], "shadow": 300},
    "outer_detail": {"fov": 50, "eye": [-15.0, 4.0, -31.0], "at": [-15.0, 0.0, -22.0], "near": 0.05, "far": 2500, "groups": [], "shadow": 40},
    "wall_foot": {"fov": 55, "eye": [12.0, -74.0, -46.0], "at": [4.0, -84.0, -24.0], "near": 0.05, "far": 2500, "groups": [], "shadow": 60},
    "spec_gnat_walk": {"fov": 16, "eye": [200.55, 0.45, 4.35], "at": [200.0, 0.1, 3.95], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_aphid_walk": {"fov": 16, "eye": [203.5, 0.4, 4.3], "at": [203.0, 0.1, 3.97], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_fly_walk": {"fov": 22, "eye": [206.9, 0.75, 4.6], "at": [206.0, 0.12, 3.9], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_woodlouse": {"fov": 28, "eye": [211.4, 1.2, 4.6], "at": [210.0, 0.1, 3.9], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 6},
    "descent": {"fov": 60, "eye": [6.0, -36.0, -31.0], "at": [2.0, -40.0, -24.31], "near": 0.05, "far": 2500, "groups": ["wall"], "shadow": 40},
    # ROBLOX-105 (--world): the ambient bugs on the tray's third row (z 10) and in place after a minute and a half of an evening (the driver writes where each
    # stands on the counts line: these cameras are aimed at those places)
    "spec_ladybird": {"fov": 30, "eye": [200.6, 1.45, 8.6], "at": [200.6, 0.1, 9.95], "near": 0.01, "far": 600, "groups": ["flies"], "shadow": 4},
    "spec_millipede": {"fov": 40, "eye": [206.0, 3.0, 7.2], "at": [206.0, 0.1, 10.9], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 6},
    "spec_snail": {"fov": 44, "eye": [217.0, 5.5, 3.0], "at": [217.0, 1.0, 11.0], "near": 0.05, "far": 600, "groups": ["flies"], "shadow": 12},
    "spec_harvestman": {"fov": 48, "eye": [229.5, 3.2, 6.5], "at": [228.0, 0.6, 10.7], "near": 0.05, "far": 600, "groups": ["flies"], "shadow": 12},
    "ambient_dock": {"fov": 40, "eye": [-9.5, -86.5, -37.5], "at": [-13.1, -89.4, -42.0], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 30},
    "ambient_dandelion": {"fov": 40, "eye": [0.8, -87.2, -56.8], "at": [-2.3, -89.5, -60.8], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 30},
    "ambient_snail": {"fov": 50, "eye": [-9.0, -84.0, -33.5], "at": [-15.6, -89.0, -39.0], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 40},
    "ambient_millipede": {"fov": 38, "eye": [-18.3, -87.5, -41.2], "at": [-20.9, -89.8, -44.1], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 30},
    "ambient_harvestman": {"fov": 46, "eye": [20.5, -86.0, -52.5], "at": [16.7, -89.4, -57.9], "near": 0.05, "far": 2500, "groups": ["bed", "flies"], "shadow": 30},
    "ambient_wall": {"fov": 46, "eye": [-25.5, -66.5, -33.0], "at": [-29.3, -69.8, -24.6], "near": 0.05, "far": 2500, "groups": ["wall", "flies"], "shadow": 30},
}


def around(fly, forward, d_back, d_up, d_front=0.0, d_side=0.0, fov=34.0, at_up=0.05):
    """A close view of a fly: the camera `d_back` behind it, `d_front` ahead of it and `d_side` to its right, `d_up` above, looking at it."""
    fx, fy, fz = forward
    n = math.sqrt(fx * fx + fy * fy + fz * fz)
    fx, fy, fz = fx / n, fy / n, fz / n
    rx, rz = -fz, fx  # the fly's right when it faces forward, flat
    m = math.hypot(rx, rz)
    rx, rz = rx / m, rz / m
    p = (fly["x"], fly["y"], fly["z"])
    eye = [p[0] - fx * d_back + fx * d_front + rx * d_side, p[1] + d_up, p[2] - fz * d_back + fz * d_front + rz * d_side]
    return {"fov": fov, "eye": eye, "at": [p[0], p[1] + at_up, p[2]], "near": 0.02, "far": 1800, "groups": ["flies"], "shadow": 20}


VIEWS.update({
    "fly_top": around(FLIES[0], (1, 0, -0.35), 0.45, 1.45, fov=36),
    "fly_front": around(FLIES[0], (1, 0, -0.35), 0, 0.30, d_front=1.5, fov=30, at_up=0.0),
    "fly_side": around(FLIES[0], (1, 0, -0.35), 0, 0.14, d_side=1.6, fov=30, at_up=0.0),
    "fly_b_top": around(FLIES[1], (1, 0.1, 0.4), 0.2, 1.45, fov=40, at_up=0.0),
    "fly_b_side": around(FLIES[1], (1, 0.1, 0.4), 0, 0.1, d_side=-1.6, fov=40, at_up=0.0),
    "fly_b_front": around(FLIES[1], (1, 0.1, 0.4), 0, 0.25, d_front=1.6, fov=40, at_up=0.0),
})


def around_wasp(w, d_back, d_up, d_front=0.0, d_side=0.0, fov=30.0, at_up=0.0, at_ahead=0.0):
    """A close view of a wasp (its centre is the petiole's base; its length runs 1.2 ahead and 1.2 behind)."""
    fx, fz = w["hx"], w["hz"]
    n = math.hypot(fx, fz)
    fx, fz = fx / n, fz / n
    rx, rz = -fz, fx
    p = (w["x"], w["y"], w["z"])
    eye = [p[0] - fx * d_back + fx * d_front + rx * d_side, p[1] + d_up, p[2] - fz * d_back + fz * d_front + rz * d_side]
    return {"fov": fov, "eye": eye, "at": [p[0] + fx * at_ahead, p[1] + at_up, p[2] + fz * at_ahead], "near": 0.02, "far": 1800, "groups": ["wasps"], "shadow": 20}


VIEWS.update({
    "wasp": around_wasp(WASPS[0], 0, 1.6, d_front=3.4, d_side=-2.0, fov=34, at_up=0.0),
    "wasp_side": around_wasp(WASPS[0], 0, 0.15, d_side=-4.2, fov=34),
    "wasp_top": around_wasp(WASPS[0], 0, 4.4, fov=36),
    "wasp_front": around_wasp(WASPS[0], 0, 0.2, d_front=4.0, fov=34),
    "wasp_walk": around_wasp(WASPS[1], 0, 1.0, d_front=2.3, d_side=-2.3, fov=36, at_up=-0.1),
    "wasp_hold": around_wasp(WASPS[2], 0, 0.8, d_front=3.0, d_side=-2.6, fov=36, at_up=-0.3),
})
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
