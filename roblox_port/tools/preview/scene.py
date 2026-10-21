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
With --world (ROBLOX-107): drainpipe, drain_foot, drain_neck (the wall west of the window and its drainpipe), shrub_strip, shrub_chunk, shrub_leaf, shrub_under
(the bushes beside the bed, the dead leaf over a retreat, under a bush) and house_west (the west of the house from the lawn).
With --world (ROBLOX-112): kitchen, sill_room, counter, toaster, kitchen_floor (the kitchen's counter under the window and the floor in front of it, a spider on the
worktop by the toaster) and window_up (the window in true proportion, from the outer sill looking up it).
With --world (ROBLOX-108): far_house (the house from the far corner of the bushes); --looks-at x,y,z draws the looks a client whose spider is there holds
(World/LookPlan, Client/LookStream: its region and neighbours, the house's walls far, the rest nearest first within the budget) instead of every look at once.
With --title (ROBLOX-109): title_drift_0, title_drift_18, title_drift_36 (the splash's and the title card's drift: its start, middle and arrival) and intro_glass,
intro_sill, intro_out (the intro of a new life, each shot's middle frame), from Shared/Movement/TitleShots' own numbers; and store_icon, store_spider
(docs/STORE_PAGE.md: the icon's composition, square, and a thumbnail of the same moment).
With --lineup (ROBLOX-114): lineup_small, lineup_spiders, lineup_bugs, lineup_big (every creature on a ruler of 1 cm ticks far off at x 400; what each measures
as drawn goes to <prefix>lineup.txt); with --world: house_eye and garden_eye (the house and the garden from a person's eyes, 1.6 m over the lawn, a normal lens).
With --preserve and --looks-at where the spider is (ROBLOX-117): pb_lawn, pb_leaf, pb_path, pb_feeder_game (the game camera on the lawn, a milkweed leaf, the path round the
east end, the feeder's foot), pb_eye_mulch and pb_eye_lawn (the spider's own eye), pb_bed (the bed from 30 cm up), pb_feeder, pb_caddy (the compost caddy by the door),
pb_path_wide; with --world: spec_hoverfly and spec_hoverfly_air on the tray.
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
ap.add_argument("--looks-at", default="", help="x,y,z: draw the looks outside the window as a client whose spider is there holds them (ROBLOX-108, World/LookPlan and Client/LookStream), not every look at once")
ap.add_argument("--title", action="store_true", help="ROBLOX-109: add the first minute's camera frames (Shared/Movement/TitleShots.views: title_drift_0, title_drift_18, title_drift_36, intro_glass, intro_sill, intro_out); use with --world")
ap.add_argument("--lineup", action="store_true", help="ROBLOX-114: stand every creature side by side on a ruler far off at x 400 (views lineup_small, lineup_big and their close-ups) and write what each one measures as drawn to <prefix>lineup.txt")
ap.add_argument("--preserve", action="store_true", help="ROBLOX-115: the preserve is the world: the sill's Decor without the test garden's view, the backdrop as a client at the sill holds it (or at --looks-at), a train on the line; views pv_* and preserve_drift_*")
ap.add_argument("--hut-open", action="store_true", help="ROBLOX-116: with --preserve, the hut's window propped open (the nursery over); shut otherwise")
ap.add_argument("--preserve-all", action="store_true", help="ROBLOX-115: with --preserve, every zone of the backdrop at the --detail tier's whole detail, not the client's plan")
ap.add_argument("--night-moths", action="store_true", help="ROBLOX-119: with --preserve, the lamppost's moths in flight round its lantern, as from dusk")
ap.add_argument("--robins", default="", help="ROBLOX-120: comma list of the robin's presets to draw (ROBIN_PRESETS: lawn, watch, peck, fly, edge)")
ap.add_argument("--ride", default="", help="ROBLOX-120: with --preserve, comma list of shares (0..1) of the ballooning ride to --ride-to's spawn: the rider drawn and a view ride_<percent> behind it")
ap.add_argument("--ride-to", default="meadow_c3", help="ROBLOX-120: the landing region of the --ride frames")
ap.add_argument("--cats", default="", help="ROBLOX-118: comma list of the cat's presets to draw (CAT_PRESETS: sofa, window, walk, watch, chair, swat)")
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
    # ROBLOX-112 (--world): one on the kitchen's worktop in front of the toaster
    {"name": "kitchen", "x": -45.0, "y": -3.69, "z": 41.0, "hx": 0, "hz": -1},
]
# ROBLOX-116 (--preserve): spiders in the ranger hut and its garden (World/Hut): on the desk, on the floor, on the bench outside, on the pollinator bed's mulch
HUT_SPIDERS = [
    {"name": "desk", "x": 80.0, "y": 4.31, "z": 45.0, "hx": -0.7, "hz": -0.7},
    {"name": "floor", "x": 10.0, "y": -69.69, "z": 60.0, "hx": 0, "hz": -1},
    {"name": "bench", "x": -10.0, "y": -39.69, "z": -40.0, "hx": 0, "hz": -1},
    {"name": "garden", "x": 22.0, "y": -74.29, "z": -246.0, "hx": 1, "hz": -0.3},
    # ROBLOX-117: on the lawn by the stone, on the milkweed's first leaf, on the path round the east end, at the feeder's foot
    {"name": "lawn", "x": 30.0, "y": -84.29, "z": -120.0, "hx": 0.3, "hz": -1},
    {"name": "leaf", "x": 60.0, "y": -51.89, "z": -266.0, "hx": 1, "hz": 0},
    {"name": "path", "x": 265.0, "y": -84.29, "z": 60.0, "hx": 0, "hz": -1},
    {"name": "feeder", "x": -128.0, "y": -84.29, "z": -170.0, "hx": -1, "hz": 0.4},
    # ROBLOX-119: on the gravel at the meadow's edge, on the coneflower's cone in meadow_a3, on the bench's seat
    {"name": "medge", "x": -60.0, "y": -84.29, "z": -1110.0, "hx": 0, "hz": -1},
    {"name": "mcone", "x": -79.2, "y": -10.69, "z": -1152.1, "hx": 0.2, "hz": -1},
    {"name": "mbench", "x": -40.0, "y": -37.29, "z": -1052.5, "hx": 0, "hz": 1},
]
# ROBLOX-118 (--cats): the ranger's cat where its schedule puts it (Predator/Cat.SPOTS), drawn by Client/CatBody from Rig/CatPose
CAT_PRESETS = {
    "sofa": {"id": "cat_sofa", "x": 300.0, "y": -25.0, "z": 205.0, "hx": 1, "hz": 0, "pose": "sleep", "t": 2.0},
    "window": {"id": "cat_window", "x": 437.0, "y": 0.0, "z": 134.0, "hx": 1, "hz": 0, "pose": "sit", "t": 1.0, "spot": "window"},
    "walk": {"id": "cat_walk", "x": 60.0, "y": -70.0, "z": 200.0, "hx": 1, "hz": 0.1, "pose": "walk", "t": 1.13},
    "watch": {"id": "cat_watch", "x": 320.0, "y": -70.0, "z": 120.0, "hx": -1, "hz": 0.2, "pose": "watch", "t": 0.4, "look": [280.0, -69.0, 112.0]},
    "face": {"id": "cat_face", "x": 300.0, "y": -69.0, "z": 120.0, "hx": -1, "hz": 0, "pose": "watch", "t": 0.4, "look": [262.0, -38.0, 112.0], "seated": True},
    "chair": {"id": "cat_chair", "x": 86.0, "y": -24.0, "z": 108.0, "hx": 0, "hz": -1, "pose": "rest", "t": 0.2},
    "swat": {"id": "cat_swat", "x": 320.0, "y": -70.0, "z": 120.0, "hx": -1, "hz": 0, "pose": "swat", "t": 0.4, "paw": [296.0, -69.0, 116.0], "swat": 0.125},
}
CATS = [CAT_PRESETS[n] for n in args.cats.split(",") if n]
# ROBLOX-120 (--robins): the robin (Client/BirdBody) on the hut garden's lawn east of the path (lawn: standing, its head cocked; watch: the tell; peck), in the air coming in over
# the lawn with its shadow under it on the ground (fly), and on the meadow's mown edge (edge). The ground is y -84.6.
ROBIN_PRESETS = {
    "lawn": {"id": "robin_lawn", "x": 80.0, "y": -84.6, "z": -125.0, "hx": -1, "hz": -0.15, "pose": "stand", "cock": 1},
    "watch": {"id": "robin_watch", "x": -60.0, "y": -84.6, "z": -95.0, "hx": 1, "hz": 0.1, "pose": "watch", "cock": -1},
    "peck": {"id": "robin_peck", "x": 150.0, "y": -84.6, "z": -105.0, "hx": -1, "hz": 0.3, "pose": "peck", "cock": 1},
    "fly": {"id": "robin_fly", "x": 30.0, "y": 25.0, "z": -105.0, "hx": -1, "hz": 0.35, "pose": "fly", "shadow": True},
    "edge": {"id": "robin_edge", "x": -60.0, "y": -84.6, "z": -1124.0, "hx": 1, "hz": 0, "pose": "stand", "cock": 1},
}
ROBINS = [ROBIN_PRESETS[n] for n in args.robins.split(",") if n]

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
    spiders = SPIDERS if args.world else (SPIDERS[:2] + HUT_SPIDERS if args.preserve else SPIDERS[:2])
    prefix = (f'DETAIL = {lua(args.detail)}\nSUN_ELEVATION_DEG = {args.elevation}\nSUN_AZIMUTH_DEG = {args.azimuth}\n'
              f'SPIDERS = {lua(spiders)}\nFLIES = {lua(FLIES)}\nWASPS = {lua(WASPS)}\nWORLD = {lua(args.world)}\n'
              f'LOOKS_AT = {lua([float(c) for c in args.looks_at.split(",")] if args.looks_at else False)}\nLINEUP = {lua(args.lineup)}\n'
              f'PRESERVE = {lua(args.preserve)}\nPRESERVE_ALL = {lua(args.preserve_all)}\nHUT_OPEN = {lua(args.hut_open)}\nCATS = {lua(CATS)}\n'
              f'NIGHT_MOTHS = {lua(args.night_moths)}\nROBINS = {lua(ROBINS)}\nRIDE = {lua([float(x) for x in args.ride.split(",") if x])}\nRIDE_TO = {lua(args.ride_to)}\n')
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
    # (ROBLOX-120) views the driver computed (the ride's frames, the crickets' places): "VIEW name ex ey ez ax ay az fov"
    bits = first.split(" VIEW ")
    for b in bits[1:]:
        name, *nums = b.split()
        n = [float(x) for x in nums[:7]]
        EXTRA[name] = {"fov": n[6], "eye": n[0:3], "at": n[3:6], "near": 0.02, "far": 14000, "groups": ["cats", "flies"], "shadow": 60}
    first = bits[0]
    (out / f"{args.prefix}counts.txt").write_text(first + "\n")
    print(first)


EXTRA = {}
parts_path = pathlib.Path(args.parts).resolve() if args.parts else out / f"{args.prefix}parts.json"
if not args.parts:
    dump_parts(parts_path)


# ROBLOX-114 (--lineup): what each creature measures as drawn, from its parts' boxes (an ellipsoid or a rod counts as its box, so a turned one reads a little long):
# its whole length along its heading (+X) with legs, antennae and wings, its body's length (head or cephalothorax to the end of the abdomen: the body's own parts,
# not legs, antennae, palps, fangs, wings, hairs or a shadow), its span across (Z) and its height over the card.
BODY = ("cephalothorax", "abdomen", "pedicel", "head", "thorax", "gaster", "body", "shell", "ring", "plate", "spire", "petiole", "collar", "scutellum", "turret",
        "elytr", "pronotum", "carapace", "rostrum", "eye", "face", "lip")
LEGS = ("abdomenspot", "eyesocket", "eyeface")


def measure(rows):
    found = {}
    for r in rows:
        if r["g"] != "lineup":
            continue
        bits = r["path"].split("/")
        if len(bits) < 3:
            continue
        cid = bits[1]
        sx, sy, sz = r["size"]
        ms = r.get("ms") or [1, 1, 1]
        sx, sy, sz = sx * (ms[0] if r.get("mesh") else 1), sy * (ms[1] if r.get("mesh") else 1), sz * (ms[2] if r.get("mesh") else 1)
        lo, hi = [1e9] * 3, [-1e9] * 3
        for a in (-0.5, 0.5):
            for b in (-0.5, 0.5):
                for c in (-0.5, 0.5):
                    pt = [r["p"][i] + a * sx * r["x"][i] + b * sy * r["y"][i] + c * sz * r["z"][i] for i in range(3)]
                    lo = [min(lo[i], pt[i]) for i in range(3)]
                    hi = [max(hi[i], pt[i]) for i in range(3)]
        name = r["n"].lower()
        limb = not (name.startswith(BODY) and not name.startswith(LEGS)) or name.endswith(("antenna", "tip", "band"))
        e = found.setdefault(cid, {"all": [[1e9] * 3, [-1e9] * 3], "body": [[1e9] * 3, [-1e9] * 3], "n": 0})
        e["n"] += 1
        for key in ("all",) + (() if limb else ("body",)):
            e[key][0] = [min(e[key][0][i], lo[i]) for i in range(3)]
            e[key][1] = [max(e[key][1][i], hi[i]) for i in range(3)]
    lines = []
    for cid, e in found.items():
        a, b = e["all"], e["body"]
        lines.append(f"{cid:14s} parts {e['n']:4d}  length {10 * (a[1][0] - a[0][0]):6.1f} mm  body {10 * (b[1][0] - b[0][0]):6.1f} mm  span {10 * (a[1][2] - a[0][2]):6.1f} mm"
                     f"  body width {10 * (b[1][2] - b[0][2]):5.1f} mm  top {10 * a[1][1]:5.1f} mm")
    return lines


if args.lineup:
    report = measure(json.loads(parts_path.read_text()))
    (out / f"{args.prefix}lineup.txt").write_text("\n".join(report) + "\n")
    print("\n".join(report))

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
    "spec_hoverfly": {"fov": 30, "eye": [229.6, 1.5, 1.6], "at": [228.0, 0.2, 0.0], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 8},  # ROBLOX-117
    "spec_hoverfly_air": {"fov": 30, "eye": [229.8, 2.2, -3.0], "at": [228.0, 1.16, -5.0], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 8},
    "spec_crane_fly_air": {"fov": 40, "eye": [221.0, 3.5, 0.0], "at": [216.0, 2.0, -5.0], "near": 0.02, "far": 600, "groups": ["flies"], "shadow": 12},
    "world": {"fov": 60, "eye": [75.0, -15.0, -100.0], "at": [0.0, -55.0, -30.0], "near": 1.0, "far": 4000, "groups": [], "shadow": 220},
    # ROBLOX-103 (--world): the wall above the window, its eaves and gutter; the house from the lawn; the garden from the eaves; the bushes from the outer sill;
    # details of the outer sill, the wall's foot and the bed; and the tray's second row walking (the gnat, the aphid, the house fly, the woodlouse) mid-stride
    "gutter": {"fov": 55, "eye": [22.0, 164.0, -98.0], "at": [0.0, 150.0, -68.0], "near": 0.1, "far": 5000, "groups": [], "shadow": 120},  # (ROBLOX-112: the gutter 40 up)
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
    # ROBLOX-107 (--world): the wall west of the window with its drainpipe (from the litter, at its foot, at the swan neck into the gutter), the bushes beside the
    # bed (the strip from over the bed, one chunk, the dead leaf over a retreat, under a bush in the litter) and the west of the house from the lawn
    "drainpipe": {"fov": 62, "eye": [-20.0, -40.0, -150.0], "at": [-60.0, 10.0, -24.0], "near": 0.5, "far": 6000, "groups": [], "shadow": 300},
    "drain_foot": {"fov": 50, "eye": [-44.0, -82.0, -44.0], "at": [-50.0, -88.0, -28.0], "near": 0.05, "far": 2500, "groups": [], "shadow": 60},
    "drain_neck": {"fov": 55, "eye": [-25.0, 165.0, -105.0], "at": [-50.0, 140.0, -60.0], "near": 0.1, "far": 5000, "groups": [], "shadow": 120},
    "shrub_strip": {"fov": 64, "eye": [40.0, 60.0, -150.0], "at": [-200.0, -80.0, -100.0], "near": 1.0, "far": 6000, "groups": [], "shadow": 600},
    "shrub_chunk": {"fov": 60, "eye": [-20.0, -40.0, -70.0], "at": [-85.0, -80.0, -75.0], "near": 0.5, "far": 4000, "groups": [], "shadow": 160},
    "shrub_leaf": {"fov": 50, "eye": [-93.0, -86.0, -71.0], "at": [-93.0, -89.5, -86.0], "near": 0.05, "far": 2500, "groups": [], "shadow": 40},
    "shrub_under": {"fov": 70, "eye": [-80.0, -87.5, -95.0], "at": [-95.0, -80.0, -80.0], "near": 0.05, "far": 2500, "groups": [], "shadow": 60},
    # ROBLOX-108: the house from the far corner of the bushes (with --looks-at -495,-89.7,-195 the walls there are their far looks)
    "far_house": {"fov": 60, "eye": [-470.0, -60.0, -190.0], "at": [-60.0, 10.0, -24.0], "near": 1.0, "far": 6000, "groups": [], "shadow": 600},
    # ROBLOX-114: the back of the house as a person sees it, eyes 1.6 m over the lawn 6 m out with a normal lens (45 degrees: the house view's 62 degrees stretch
    # what stands near the frame's edge, which made the back door read wide), and the garden from there toward the back fence and the bungalows
    "house_eye": {"fov": 45, "eye": [110.0, 70.0, -620.0], "at": [60.0, 40.0, -24.0], "near": 1.0, "far": 8000, "groups": [], "shadow": 600},
    "garden_eye": {"fov": 50, "eye": [0.0, 70.0, -60.0], "at": [0.0, 20.0, -1400.0], "near": 1.0, "far": 8000, "groups": [], "shadow": 900},
    "house_west": {"fov": 62, "eye": [-150.0, -40.0, -430.0], "at": [-180.0, 0.0, -24.0], "near": 1.0, "far": 6000, "groups": [], "shadow": 600},
    # ROBLOX-112 (--world): the kitchen: the counter and the window from the room, the sill's view into the room, the worktop at the spider's height, the gap under the
    # toaster, the floor in front of the cupboards, and the window from the outer sill looking up it
    "kitchen": {"fov": 60, "eye": [30.0, 45.0, 200.0], "at": [0.0, 0.0, 20.0], "near": 0.5, "far": 6000, "groups": ["kitchen"], "shadow": 300},
    "sill_room": {"fov": 70, "eye": [0.0, 6.0, -6.0], "at": [0.0, -12.0, 60.0], "near": 0.05, "far": 6000, "groups": ["kitchen"], "shadow": 120},
    "counter": {"fov": 60, "eye": [-10.0, 4.0, 55.0], "at": [-40.0, -2.0, 25.0], "near": 0.05, "far": 6000, "groups": ["kitchen"], "shadow": 80},
    "toaster": {"fov": 50, "eye": [-41.0, -1.4, 47.0], "at": [-45.0, -3.4, 33.0], "near": 0.02, "far": 6000, "groups": ["kitchen"], "shadow": 40},
    "kitchen_floor": {"fov": 60, "eye": [25.0, -82.0, 112.0], "at": [0.0, -86.0, 62.0], "near": 0.05, "far": 6000, "groups": [], "shadow": 80},
    "window_up": {"fov": 70, "eye": [0.0, 2.0, -21.0], "at": [0.0, 70.0, -12.0], "near": 0.05, "far": 6000, "groups": [], "shadow": 120},
    # ROBLOX-114 (--lineup): every creature on the ruler, from in front and a little above: the small row, the big row, and the big row's two halves closer
    "lineup_small": {"fov": 40, "eye": [409.5, 3.2, 14.0], "at": [409.5, 0.2, 0.6], "near": 0.05, "far": 600, "groups": ["lineup"], "shadow": 20},
    "lineup_spiders": {"fov": 40, "eye": [412.0, 4.5, 33.0], "at": [412.0, 0.5, 12.6], "near": 0.05, "far": 600, "groups": ["lineup"], "shadow": 30},
    "lineup_bugs": {"fov": 40, "eye": [447.0, 7.0, 50.0], "at": [447.0, 0.8, 12.6], "near": 0.1, "far": 600, "groups": ["lineup"], "shadow": 50},
    "lineup_big": {"fov": 40, "eye": [435.0, 14.0, 95.0], "at": [435.0, 0.5, 12.6], "near": 0.1, "far": 600, "groups": ["lineup"], "shadow": 80},
    # ROBLOX-109 (docs/STORE_PAGE.md): the game icon's composition (render it square: --size 1024x1024), the spider stepping out of the crack at the spawn, three-quarter
    # front and low; and the store thumbnail of the same moment, wider
    "store_icon": {"fov": 32, "eye": [-19.4, 0.8, 7.6], "at": [-22.0, 0.42, 6.0], "near": 0.02, "far": 2500, "groups": ["spawn"], "shadow": 20},
    "store_spider": {"fov": 40, "eye": [-18.6, 0.9, 8.4], "at": [-22.4, 0.5, 5.6], "near": 0.02, "far": 2500, "groups": ["spawn"], "shadow": 30},
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


def title_views():
    """ROBLOX-109: the drift's keys and the intro's shots from the real TitleShots module (tools/preview/title_shots.luau prints them)."""
    spec = importlib.util.spec_from_file_location("jss_tests_run", ROOT / "tests" / "run.py")
    run = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run)
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False, dir=out) as f:
        f.write(run.bundle(str(HERE / "title_shots.luau")))
    try:
        text = subprocess.run([args.luau, f.name], capture_output=True, text=True, check=True).stdout
    finally:
        pathlib.Path(f.name).unlink()
    found = {}
    for line in text.splitlines():
        name, *nums = line.split()
        n = [float(x) for x in nums]
        # the spider is drawn only where the intro shows it out of the crack (the spawn's spider; in the earlier shots it is still inside)
        found[name] = {"fov": n[6], "eye": n[0:3], "at": n[3:6], "near": 0.05, "far": 6000, "groups": ["spawn"] if name == "intro_out" else [], "shadow": 300 if name.startswith("title_") else 40}
    return found


if args.title:
    VIEWS.update(title_views())

# ROBLOX-115 (--preserve): the preserve's views. Studs, the sill's frame: the hut's north window at z -16 looking north (-z) over the hut garden (z -116..-916), the
# meadow (z -1316..-4316), the pond (x 1625..3225), the railway's embankment (z -5516..-5956) and the towers at the edge; the woodland west (x < -2375), the stone
# wall and the apartment blocks east (x 4625.., 5525..); the street south (z 484..).
VIEWS.update({
    "pv_window": {"fov": 62, "eye": [0.0, 6.0, 8.0], "at": [0.0, 3.0, -100.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 600},
    "pv_window_high": {"fov": 70, "eye": [0.0, 14.0, 4.0], "at": [0.0, -60.0, -600.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 900},
    "pv_sill": {**game_camera(0.0, 4.0, 0, -1), "far": 14000, "groups": [], "shadow": 60},
    "pv_plan": {"fov": 62, "eye": [425.0, 9800.0, -2500.0], "at": [425.0, -85.0, -2516.0], "near": 50.0, "far": 20000, "groups": [], "shadow": 12000, "fog": 0.0},
    "pv_overview": {"fov": 58, "eye": [3600.0, 3800.0, 2600.0], "at": [300.0, -85.0, -2400.0], "near": 5.0, "far": 20000, "groups": [], "shadow": 12000, "fog": 0.00004},
    "pv_hut": {"fov": 50, "eye": [320.0, 80.0, -1800.0], "at": [0.0, 60.0, -16.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 1500},
    "pv_hut_near": {"fov": 55, "eye": [260.0, 40.0, -520.0], "at": [0.0, 40.0, -16.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 700},
    "pv_railway": {"fov": 60, "eye": [1500.0, 110.0, -4300.0], "at": [2600.0, 220.0, -5900.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 2500},
    "pv_east": {"fov": 60, "eye": [3600.0, 110.0, -3100.0], "at": [5400.0, 300.0, -2400.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 2500},
    "pv_west": {"fov": 60, "eye": [-1800.0, 110.0, -2200.0], "at": [-3800.0, 400.0, -3300.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 2500},
    "pv_south": {"fov": 60, "eye": [600.0, 120.0, -600.0], "at": [-200.0, 60.0, 800.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 2000},
})


# ROBLOX-116 (--preserve): the ranger hut walkable. Studs, the sill's frame: the room +z of the sill (x -146.5..146.5, z 12.5..255.5, its floor y -70), the garden's
# core -z of the hut's north wall (x -200..200, z -16..-416, its ground y -84.6).
VIEWS.update({
    "hb_inside": {"fov": 64, "eye": [0.0, 8.0, 9.0], "at": [10.0, -45.0, 160.0], "near": 0.1, "far": 14000, "groups": ["desk", "floor"], "shadow": 400},
    "hb_inside_wide": {"fov": 70, "eye": [-128.0, 45.0, 238.0], "at": [30.0, -35.0, 50.0], "near": 0.5, "far": 14000, "groups": ["desk", "floor"], "shadow": 500},
    "hb_desk": {"fov": 50, "eye": [62.0, 30.0, 115.0], "at": [86.0, 4.0, 36.0], "near": 0.1, "far": 14000, "groups": ["desk"], "shadow": 200},
    "hb_game_desk": {**game_camera(80.0, 45.0, -0.7, -0.7), "far": 14000, "groups": ["desk"], "shadow": 60},
    "hb_board": {"fov": 55, "eye": [-80.0, 22.0, 85.0], "at": [-92.0, 18.0, 14.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 200},
    "hb_door": {"fov": 60, "eye": [8.0, -62.0, 205.0], "at": [0.0, -69.0, 262.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 200},
    "hb_out": {"fov": 64, "eye": [0.0, 9.0, -1.0], "at": [10.0, -40.0, -320.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 600},
    "hb_down": {"fov": 60, "eye": [95.0, 15.0, -170.0], "at": [-15.0, -45.0, -25.0], "near": 0.5, "far": 14000, "groups": ["bench"], "shadow": 400},
    "hb_down_close": {"fov": 55, "eye": [30.0, -10.0, -75.0], "at": [-5.0, -30.0, -20.0], "near": 0.1, "far": 14000, "groups": ["bench"], "shadow": 200},
    "hb_garden": {"fov": 62, "eye": [28.0, -70.0, -228.0], "at": [70.0, -38.0, -320.0], "near": 0.1, "far": 14000, "groups": ["garden"], "shadow": 400},
    "hb_game_garden": {**game_camera(22.0, -246.0, 1, -0.3), "far": 14000, "groups": ["garden"], "shadow": 60},
    "hb_garden_top": {"fov": 58, "eye": [0.0, 560.0, -150.0], "at": [0.0, -85.0, -232.0], "near": 1.0, "far": 14000, "groups": [], "shadow": 1500},
})
# ROBLOX-117 (--preserve, with --looks-at where the spider is): the garden at the spider's eye. The game camera on the lawn by the stone (pb_lawn), on the milkweed's
# first leaf (pb_leaf), in the mulch (hb_game_garden) and on the path round the east end (pb_path); the spider's own eye low in the mulch and in the grass (pb_eye_mulch,
# pb_eye_lawn); the pollinator bed from 30 cm up (pb_bed); the feeder's foot (pb_feeder); the path round the east end from a person's knee (pb_path_wide).
VIEWS.update({
    "pb_lawn": {**game_camera(30.0, -120.0, 0.3, -1), "far": 14000, "groups": ["lawn"], "shadow": 60},
    "pb_leaf": {**game_camera(60.0, -266.0, 1, 0), "far": 14000, "groups": ["leaf"], "shadow": 60},
    "pb_path": {**game_camera(265.0, 60.0, 0, -1), "far": 14000, "groups": ["path"], "shadow": 60},
    "pb_feeder_game": {**game_camera(-128.0, -170.0, -1, 0.4), "far": 14000, "groups": ["feeder"], "shadow": 60},
    "pb_eye_mulch": {"fov": 75, "eye": [22.5, -73.9, -246.2], "at": [60.0, -72.0, -258.0], "near": 0.02, "far": 14000, "groups": [], "shadow": 60},
    "pb_eye_lawn": {"fov": 75, "eye": [30.2, -83.9, -120.6], "at": [40.0, -82.0, -150.0], "near": 0.02, "far": 14000, "groups": [], "shadow": 60},
    "pb_bed": {"fov": 62, "eye": [-20.0, -54.6, -200.0], "at": [90.0, -70.0, -320.0], "near": 0.1, "far": 14000, "groups": ["garden", "leaf"], "shadow": 300},
    "pb_feeder": {"fov": 60, "eye": [-112.0, -76.0, -126.0], "at": [-150.0, -82.0, -160.0], "near": 0.05, "far": 14000, "groups": ["feeder"], "shadow": 120},
    "pb_caddy": {"fov": 55, "eye": [40.0, -50.0, 185.0], "at": [79.0, -58.0, 237.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 200},
    "pb_path_wide": {"fov": 62, "eye": [330.0, -40.0, 330.0], "at": [240.0, -84.0, 40.0], "near": 0.2, "far": 14000, "groups": ["path"], "shadow": 500},
})
# ROBLOX-118 (--preserve): the ceiling, the back room and the cat (with --cats). The back room is east of the hut through the doorway (x 175..445, z 12.5..255.5, its floor
# y -70): from the floor at a spider's height by the doorway (rb_floor), from the sofa's west arm (rb_arm), the doorway from the hut (rb_doorway), the ceiling's north-west
# corner with the house spider's web (rb_ceiling), the north face outside to the gutter (rb_eaves); the cat asleep on the sofa (cat_sofa), sitting at the window (cat_window),
# walking in the hut (cat_walk), its face close as it watches (cat_face), crouched to pat (cat_swat), and on the chair (cat_chair).
VIEWS.update({
    "rb_floor": {"fov": 70, "eye": [200.0, -66.0, 92.0], "at": [400.0, -38.0, 170.0], "near": 0.1, "far": 14000, "groups": ["cats"], "shadow": 400},
    "rb_arm": {"fov": 66, "eye": [236.0, 4.0, 196.0], "at": [330.0, -45.0, 40.0], "near": 0.1, "far": 14000, "groups": ["cats"], "shadow": 400},
    "rb_doorway": {"fov": 64, "eye": [20.0, -40.0, 160.0], "at": [200.0, -45.0, 215.0], "near": 0.1, "far": 14000, "groups": ["cats"], "shadow": 400},
    "rb_ceiling": {"fov": 60, "eye": [-112.0, 118.0, 48.0], "at": [-138.0, 140.0, 20.0], "near": 0.05, "far": 14000, "groups": [], "shadow": 300},
    "rb_eaves": {"fov": 60, "eye": [160.0, 60.0, -170.0], "at": [60.0, 120.0, -40.0], "near": 0.1, "far": 14000, "groups": [], "shadow": 600},
    "cat_sofa": {"fov": 50, "eye": [252.0, 8.0, 160.0], "at": [300.0, -18.0, 205.0], "near": 0.05, "far": 14000, "groups": ["cats"], "shadow": 120},
    "cat_window": {"fov": 52, "eye": [385.0, 12.0, 104.0], "at": [440.0, 16.0, 134.0], "near": 0.05, "far": 14000, "groups": ["cats"], "shadow": 120},
    "cat_walk": {"fov": 55, "eye": [108.0, -50.0, 246.0], "at": [60.0, -56.0, 200.0], "near": 0.05, "far": 14000, "groups": ["cats"], "shadow": 120},
    "cat_face": {"fov": 45, "eye": [262.0, -38.0, 112.0], "at": [287.0, -40.0, 120.0], "near": 0.02, "far": 14000, "groups": ["cats"], "shadow": 60},
    "cat_swat": {"fov": 55, "eye": [300.0, -55.0, 165.0], "at": [305.0, -60.0, 118.0], "near": 0.05, "far": 14000, "groups": ["cats"], "shadow": 120},
    "cat_chair": {"fov": 52, "eye": [40.0, -5.0, 150.0], "at": [86.0, -18.0, 108.0], "near": 0.05, "far": 14000, "groups": ["cats"], "shadow": 120},
})
# ROBLOX-119 (--preserve, with --looks-at where the spider is): the meadow's edge and the bench patch (World/Meadow: the gravel x -210..90, z -816..-1116, the meadow
# x -310..190, z -1116..-1616, the ground y -84.6). The spider's eye on the gravel at the meadow's edge (mc_eye_edge) and its game camera (mc_edge); on the coneflower's
# cone 74 cm up (mc_cone, and mc_cone_view: what it sees from there); the yellow crab spider on its goldenrod (mc_crab, mc_crab_close); the meadow's edge from a person's
# knee (mc_wide); the bench patch by day (mc_bench) and at night with the moths at the lantern (mc_bench_night, mc_lamp: with --night-moths and a night sky); the
# spider on the bench's seat (mc_bench_game); the ant hill (mc_hill); the drain grate (mc_grate); the bin's foot with its can and packet (mc_bin).
VIEWS.update({
    "mc_eye_edge": {"fov": 75, "eye": [-60.0, -83.9, -1111.0], "at": [-60.0, -66.0, -1200.0], "near": 0.02, "far": 14000, "groups": [], "shadow": 120},
    "mc_edge": {**game_camera(-60.0, -1110.0, 0, -1), "far": 14000, "groups": ["medge", "flies"], "shadow": 60},
    "mc_cone": {**game_camera(-79.2, -1152.1, 0.2, -1), "far": 14000, "groups": ["mcone", "flies"], "shadow": 60},
    "mc_cone_view": {"fov": 70, "eye": [-79.2, -9.6, -1153.5], "at": [-60.0, -30.0, -1450.0], "near": 0.05, "far": 14000, "groups": ["flies"], "shadow": 300},
    "mc_crab": {"fov": 45, "eye": [-58.0, 22.0, -1535.0], "at": [-76.5, 12.0, -1549.6], "near": 0.05, "far": 14000, "groups": ["flies"], "shadow": 60},
    "mc_crab_close": {"fov": 40, "eye": [-70.5, 19.5, -1544.5], "at": [-76.5, 16.8, -1549.6], "near": 0.02, "far": 14000, "groups": ["flies"], "shadow": 30},
    "mc_wide": {"fov": 62, "eye": [150.0, -25.0, -1085.0], "at": [-80.0, -60.0, -1350.0], "near": 0.2, "far": 14000, "groups": ["flies", "medge", "mcone"], "shadow": 600},
    "mc_bench": {"fov": 60, "eye": [160.0, -20.0, -840.0], "at": [-60.0, -55.0, -1060.0], "near": 0.2, "far": 14000, "groups": ["flies", "mbench"], "shadow": 600},
    "mc_bench_night": {"fov": 64, "eye": [160.0, 20.0, -820.0], "at": [-90.0, 60.0, -1060.0], "near": 0.2, "far": 14000, "groups": ["flies", "mbench"], "shadow": 600},
    "mc_lamp": {"fov": 55, "eye": [-150.0, 276.0, -1040.0], "at": [-180.0, 272.0, -1068.0], "near": 0.1, "far": 14000, "groups": ["flies"], "shadow": 120},
    "mc_bench_game": {**game_camera(-40.0, -1052.5, 0, 1), "far": 14000, "groups": ["mbench", "flies"], "shadow": 60},
    "mc_hill": {"fov": 55, "eye": [45.0, -71.0, -1212.0], "at": [22.0, -83.0, -1252.0], "near": 0.05, "far": 14000, "groups": ["flies"], "shadow": 120},
    "mc_grate": {"fov": 55, "eye": [50.0, -65.0, -925.0], "at": [35.0, -86.0, -945.0], "near": 0.05, "far": 14000, "groups": [], "shadow": 120},
    "mc_bin": {"fov": 55, "eye": [20.0, -70.0, -1000.0], "at": [55.0, -80.0, -1040.0], "near": 0.05, "far": 14000, "groups": ["flies"], "shadow": 120},
})
for _n, _dy in (("mc_edge", -84.6), ("mc_cone", -11.0), ("mc_bench_game", -37.6)):
    VIEWS[_n]["eye"][1] += _dy
    VIEWS[_n]["at"][1] += _dy
for _n, _dy in (("pb_lawn", -84.6), ("pb_leaf", -52.2), ("pb_path", -84.6), ("pb_feeder_game", -84.6)):
    VIEWS[_n]["eye"][1] += _dy
    VIEWS[_n]["at"][1] += _dy
# (the game camera's pivot is 0.31 over a support at y 0; on the desk and the mulch the support is higher)
VIEWS["hb_game_desk"]["eye"][1] += 4.0
VIEWS["hb_game_desk"]["at"][1] += 4.0
VIEWS["hb_game_garden"]["eye"][1] += -74.6
VIEWS["hb_game_garden"]["at"][1] += -74.6


def preserve_views():
    """ROBLOX-115: the preserve's drift from the real TitleShots module (preserveViews)."""
    spec = importlib.util.spec_from_file_location("jss_tests_run", ROOT / "tests" / "run.py")
    run = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run)
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False, dir=out) as f:
        f.write(run.bundle(str(HERE / "title_shots.luau")).replace("TitleShots.views()", "TitleShots.preserveViews()"))
    try:
        text = subprocess.run([args.luau, f.name], capture_output=True, text=True, check=True).stdout
    finally:
        pathlib.Path(f.name).unlink()
    found = {}
    for line in text.splitlines():
        name, *nums = line.split()
        n = [float(x) for x in nums]
        found[name] = {"fov": n[6], "eye": n[0:3], "at": n[3:6], "near": 0.5, "far": 14000, "groups": [], "shadow": 1500}
    return found


if args.preserve:
    VIEWS.update(preserve_views())
VIEWS.update(EXTRA)
# ROBLOX-120 (--robins): the robin on the lawn from a little way off (rb_lawn), its head close (rb_head), coming in over the lawn with its shadow on the ground (rb_shadow), the
# same from a spider's eye on the lawn (rb_shadow_eye), the tell (rb_watch), a peck (rb_peck) and on the meadow's mown edge (rb_edge).
VIEWS.update({
    "rb_lawn": {"fov": 55, "eye": [10.0, -66.0, -175.0], "at": [78.0, -76.0, -125.0], "near": 0.05, "far": 14000, "groups": ["cats", "flies"], "shadow": 300},
    "rb_head": {"fov": 40, "eye": [58.0, -70.0, -138.0], "at": [72.5, -72.0, -126.5], "near": 0.02, "far": 14000, "groups": ["cats"], "shadow": 80},
    "rb_shadow": {"fov": 60, "eye": [150.0, -10.0, -330.0], "at": [30.0, -84.0, -105.0], "near": 0.1, "far": 14000, "groups": ["cats", "flies"], "shadow": 400},
    "rb_shadow_top": {"fov": 50, "eye": [40.0, 10.0, -60.0], "at": [30.0, -84.0, -105.0], "near": 0.1, "far": 14000, "groups": ["cats", "flies"], "shadow": 300},
    "rb_shadow_eye": {"fov": 75, "eye": [70.0, -84.0, -60.0], "at": [30.0, 10.0, -110.0], "near": 0.05, "far": 14000, "groups": ["cats", "flies"], "shadow": 400},
    "rb_watch": {"fov": 45, "eye": [-35.0, -80.0, -92.0], "at": [-55.0, -74.0, -95.0], "near": 0.02, "far": 14000, "groups": ["cats"], "shadow": 80},
    "rb_peck": {"fov": 45, "eye": [125.0, -72.0, -120.0], "at": [145.0, -80.0, -104.0], "near": 0.02, "far": 14000, "groups": ["cats"], "shadow": 80},
    "rb_edge": {"fov": 55, "eye": [-10.0, -70.0, -1090.0], "at": [-58.0, -78.0, -1124.0], "near": 0.05, "far": 14000, "groups": ["cats", "flies"], "shadow": 300},
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
