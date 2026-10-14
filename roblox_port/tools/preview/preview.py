#!/usr/bin/env python3
"""Off-Roblox look check of the drawn spider. Runs the real SpiderRig/Setae/Appearances (and the idle-motion module when it
exists) under the plain luau CLI with preview-only stand-ins (rshim.luau: a flat floor, BulkMoveTo, Instances as tables),
dumps every visible part, and renders them in Godot. This is a layout preview, not Roblox rendering: materials, lighting,
anti-aliasing and the engine's own shading differ, and Roblox Studio was not used.
Usage (from roblox_port/):
  python3 tools/preview/preview.py path/to/luau path/to/godot out_dir [--prefix after_] [--detail full|low]
         [--views front_three_quarter,top,face_closeup,play_distance,side,game_camera] [--idle SECONDS] [--parts parts.json]
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
ap.add_argument("--size", default="960x600")
args = ap.parse_args()
out = pathlib.Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)


def plain(text):
    text = re.sub(r"^--!strict\n", "", text)
    return re.sub(r"^export type", "type", text, flags=re.M)


def wire(text):
    """The rig's requires become the globals the bundle defines (APPEARANCES, ANATOMY, SETAE, IDLE)."""
    text = re.sub(r"require\(script\.Parent\.Parent\.Data\.(\w+)\)", lambda m: m.group(1).upper(), text)
    return re.sub(r"require\(script\.Parent\.(\w+)\)", lambda m: m.group(1).upper(), text)


def chunk(path):
    return f"(function()\n{wire(plain(path.read_text()))}\nend)()"


# Shared modules the rig requires, in dependency order. A module that does not exist yet (older commits) is skipped.
LIBS = [("Appearances", "Data/Appearances.luau"), ("Anatomy", "Rig/Anatomy.luau"), ("Setae", "Rig/Setae.luau"), ("Idle", "Rig/Idle.luau")]
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
    src.write_text(f'MODE = "orbit"\nDETAIL = "{args.detail}"\nIDLE_SECONDS = {args.idle}\n' + body)
    text = subprocess.run([args.luau, str(src)], capture_output=True, text=True, check=True).stdout
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
VIEW_SIZE = {"game_camera": "1920x1080"}
for name in args.views.split(","):
    v = VIEWS[name]
    png = out / f"{args.prefix}{name}.png"
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", args.godot, "--path", str(HERE), "--rendering-driver", "opengl3",
                    "--resolution", VIEW_SIZE.get(name, args.size), "-s", "render.gd", "--", str(parts_path), str(png), *map(str, v)],
                   check=True, capture_output=True)
    if not png.exists():
        raise SystemExit(f"Godot did not write {png}")
    print("wrote", png)
