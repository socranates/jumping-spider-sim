#!/usr/bin/env python3
"""Off-Roblox look check of the drawn spider. Runs the real SpiderRig/Setae/Appearances (and the idle-motion module when it
exists) under the plain luau CLI with preview-only stand-ins (rshim.luau: a flat floor, BulkMoveTo, Instances as tables),
dumps every visible part, and renders them in Godot. This is a layout preview, not Roblox rendering: materials, lighting,
anti-aliasing and the engine's own shading differ, and Roblox Studio was not used.
Usage (from roblox_port/):
  python3 tools/preview/preview.py path/to/luau path/to/godot out_dir [--prefix after_] [--detail full|low]
         [--views front_three_quarter,top,face_closeup,play_distance,side,game_camera] [--idle SECONDS] [--parts parts.json]
         [--appearance maratus_volans_male] [--dance LOOP_SECONDS]   (the peacock spider, posed at that time of its dance loop)
         [--appearance myrmarachne_formicaria_female] [--ant stand|display|walk] [--ant-seconds S]   (the ant-mimicking spider: standing with
         legs I up S seconds after it stopped, the display pose, or mid-walk at 6 studs a second for S seconds, ending at the origin)
--parts renders an already-dumped part list (for example the "before" list kept next to the images) instead of running the rig."""
import argparse, json, pathlib, re, subprocess
HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parents[1] / "src" / "Shared"

ap = argparse.ArgumentParser()
ap.add_argument("luau"); ap.add_argument("godot"); ap.add_argument("out")
ap.add_argument("--prefix", default="")
ap.add_argument("--detail", default="full")
ap.add_argument("--views", default="front_three_quarter,top,face_closeup,play_distance,side,game_camera")
ap.add_argument("--idle", type=float, default=0.0, help="seconds of standing idle before the pose is dumped")
ap.add_argument("--parts", default="")
ap.add_argument("--appearance", default="", help="an id from Data/Appearances (default: the default spider)")
ap.add_argument("--dance", type=float, default=-1.0, help="pose the peacock spider at this time (s) of its dance loop; -1: no dance")
ap.add_argument("--ant", default="", help="the ant-mimicking spider's pose: stand, display or walk")
ap.add_argument("--ant-seconds", type=float, default=2.0, help="seconds standing before the dump, or seconds walked")
ap.add_argument("--hang", default="", help="draw the spider suspended on its dragline (ROBLOX-86): drop (hanging from the start) or climb (rising along the line)")
ap.add_argument("--hang-seconds", type=float, default=1.5, help="seconds hung before the dump (the sway is a damped 2.5 s swing started by the drop)")
ap.add_argument("--size", default="960x600")
args = ap.parse_args()
out = pathlib.Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)


def plain(text):
    text = re.sub(r"^--!strict\n", "", text)
    return re.sub(r"^export type", "type", text, flags=re.M)


def wire(text):
    """The rig's requires become the globals the bundle defines (APPEARANCES, ANATOMY, SETAE, IDLE)."""
    text = re.sub(r"require\(script\.Parent\.Parent\.(?:Data|Life)\.(\w+)\)", lambda m: m.group(1).upper(), text)
    return re.sub(r"require\(script\.Parent\.(\w+)\)", lambda m: m.group(1).upper(), text)


def chunk(path):
    return f"(function()\n{wire(plain(path.read_text()))}\nend)()"


# Shared modules the rig requires, in dependency order. A module that does not exist yet (older commits) is skipped.
LIBS = [("Appearances", "Data/Appearances.luau"), ("Growth", "Life/Growth.luau"), ("Anatomy", "Rig/Anatomy.luau"), ("Setae", "Rig/Setae.luau"), ("Idle", "Rig/Idle.luau"),
        ("Peacock", "Data/Peacock.luau"), ("PeacockDance", "Rig/PeacockDance.luau"),
        ("AntMimic", "Data/AntMimic.luau"), ("AntMimicPose", "Rig/AntMimicPose.luau")]
libs = [(n, p) for n, p in LIBS if (SRC / p).exists()]

if args.parts:
    parts_path = pathlib.Path(args.parts).resolve()
else:
    rig = wire(plain((SRC / "Rig/SpiderRig.luau").read_text()))
    body = (HERE / "rshim.luau").read_text()
    for name, rel in libs:
        body += f"\n{name.upper()} = " + chunk(SRC / rel)
    body += "\nSupportMath = " + chunk(SRC / "Movement/SupportMath.luau") + "\nSpiderRig = (function()\n" + rig + "\nend)()\n"
    body += (HERE / "driver.luau").read_text()
    src = out / "bundle.luau"
    src.write_text(f'MODE = "orbit"\nDETAIL = "{args.detail}"\nIDLE_SECONDS = {args.idle}\nAPPEARANCE = "{args.appearance}"\nDANCE_T = {args.dance}\nANT_MODE = "{args.ant}"\nANT_SECONDS = {args.ant_seconds}\nHANG_MODE = "{args.hang}"\nHANG_SECONDS = {args.hang_seconds}\nHANG_HEIGHT = 2.0\n' + body)
    run = subprocess.run([args.luau, str(src)], capture_output=True, text=True)
    if run.returncode != 0:
        raise SystemExit(f"the rig failed under the preview stand-ins (bundle kept at {src}):\n{run.stderr}")
    text = run.stdout
    src.unlink()
    count_line, _, json_text = text.partition("\n")
    parts_path = out / f"{args.prefix}parts.json"
    parts_path.write_text(json_text)
    print(count_line)
    (out / f"{args.prefix}counts.txt").write_text(count_line + "\n")
print("visible parts:", len(json.loads(parts_path.read_text())))

# fov, eye x y z, target x y z (studs; the spider stands on the floor at x = z = 0, body 0.31 up, facing -Z).
VIEWS = {
    "front_three_quarter": (40, -1.76, 1.25, -2.15, 0, 0.3, -0.05),
    "top": (40, 0.0, 2.5, 0.42, 0, 0.31, 0.0),
    "face_closeup": (34, 0.50, 0.66, -1.42, 0, 0.40, -0.47),
    "play_distance": (65, 0, 1.23, 2.38, 0, 0.45, 0),
    "side": (40, 2.9, 0.98, 0.6, 0, 0.3, 0),
    # The game's own camera: 5 studs behind and 18 degrees above the pivot 0.45 over the body, field of view 65
    # (CameraMath.CAMERA_DISTANCE, DEFAULT_ELEVATION_DEG, PIVOT_HEIGHT, FOV_DEG). Full-HD, because this is the scale fuzz must read at.
    "game_camera": (65, 0.0, 2.305, 4.755, 0, 0.76, 0.0),
}
# The peacock spider is 0.45 studs long: closer cameras. p_game is the game's own camera (the same 5 studs away).
VIEWS.update({
    "p_front": (30, 0.30, 0.30, -0.95, 0, 0.14, 0.02),
    "p_back": (30, -0.30, 0.42, 0.95, 0, 0.14, 0.0),
    "p_side": (30, 1.0, 0.24, 0.05, 0, 0.14, 0.0),
    "p_top": (30, 0.0, 1.05, 0.12, 0, 0.1, 0.0),
    "p_face": (26, 0.22, 0.20, -0.62, 0, 0.12, -0.22),
    "p_three": (30, -0.55, 0.38, -0.80, 0, 0.14, 0.0),
    "p_game": (65, 0.0, 2.305, 4.755, 0, 0.76, 0.0),
})
# The ant-mimicking spider (0.5 studs long, legs I up to 0.35 studs): a_game is the game's own camera.
VIEWS.update({
    "a_front": (28, 0.35, 0.42, -0.95, 0, 0.18, -0.03),
    "a_back": (28, -0.35, 0.45, 0.95, 0, 0.16, 0.0),
    "a_side": (28, 1.0, 0.26, 0.0, 0, 0.17, 0.0),
    "a_top": (28, 0.0, 1.05, 0.05, 0, 0.1, 0.0),
    "a_three": (28, -0.62, 0.40, -0.80, 0, 0.17, 0.0),
    "a_face": (22, 0.22, 0.24, -0.60, 0, 0.19, -0.22),
    "a_game": (65, 0.0, 1.687, 2.853, 0, 0.76, 0.0), # the game camera at the small appearance's cameraScale (0.6): 3 studs, not 5
    "a_close": (40, 0.0, 0.62, 1.0, 0, 0.2, 0.0),
})
# The spider hanging on its dragline (--hang): the collider is 2 studs up (driver.luau), the line leaves the spinneret toward +Y. hang_side looks at it
# from the side (the body's long axis is vertical, the head down), hang_front from in front of the head. The pale strand is the dragline.
VIEWS.update({
    "hang_side": (34, 3.0, 2.15, 0.15, 0, 2.0, 0.0),
    "hang_front": (34, 0.1, 2.1, -3.0, 0, 2.0, 0.0),
    "hang_three": (34, -2.2, 2.2, -2.2, 0, 2.0, 0.0),
    "hang_back": (34, -0.1, 2.0, 3.0, 0, 2.0, 0.0),
    "hang_wide": (50, 3.6, 1.8, 0.2, 0, 1.55, 0.0), # a wider frame, for comparing with the old pose (which hung the body 0.7 studs lower)
})
VIEW_SIZE = {"game_camera": "1920x1080", "p_game": "1920x1080", "a_game": "1920x1080"}
for name in args.views.split(","):
    v = VIEWS[name]
    png = out / f"{args.prefix}{name}.png"
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", args.godot, "--path", str(HERE), "--rendering-driver", "opengl3",
                    "--resolution", VIEW_SIZE.get(name, args.size), "-s", "render.gd", "--", str(parts_path), str(png), *map(str, v)],
                   check=True, capture_output=True)
    if not png.exists():
        raise SystemExit(f"Godot did not write {png}")
    print("wrote", png)
