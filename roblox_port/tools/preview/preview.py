#!/usr/bin/env python3
"""Off-Roblox look check of the drawn spider. Runs the real SpiderRig/Setae/Appearances under the plain luau CLI with
preview-only stand-ins (rshim.luau: a flat floor, BulkMoveTo, Instances as tables), dumps every visible part, and renders
them in Godot. This is a layout preview, not Roblox rendering: materials, lighting and anti-aliasing differ.
Usage (from roblox_port/): python3 tools/preview/preview.py path/to/luau path/to/godot out_dir"""
import json, pathlib, re, subprocess, sys
HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parents[1] / "src" / "Shared"
luau, godot, out = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)
def chunk(path):
    t = path.read_text(); t = re.sub(r"^--!strict\n", "", t); t = re.sub(r"^export type", "type", t, flags=re.M)
    return f"(function()\n{t}\nend)()"
rig = (SRC / "Rig/SpiderRig.luau").read_text()
rig = re.sub(r"^--!strict\n", "", rig); rig = re.sub(r"^export type", "type", rig, flags=re.M)
rig = rig.replace("require(script.Parent.Parent.Data.Appearances)", "APPEARANCES").replace("require(script.Parent.Setae)", "SETAE")
rig = rig.replace("Setae.LegHair", "any")
body = (HERE / "rshim.luau").read_text()
body += "\nAPPEARANCES = " + chunk(SRC / "Data/Appearances.luau") + "\nSETAE = " + chunk(SRC / "Rig/Setae.luau")
body += "\nSupportMath = " + chunk(SRC / "Movement/SupportMath.luau") + "\nSpiderRig = (function()\n" + rig + "\nend)()\n"
body += (HERE / "driver.luau").read_text()
for mode in ("orbit", "eye"):
    src = out / f"bundle_{mode}.luau"
    src.write_text(f'MODE = "{mode}"\n' + body)
    (out / f"parts_{mode}.json").write_text(subprocess.run([luau, str(src)], capture_output=True, text=True, check=True).stdout)
    src.unlink()
print("parts:", len(json.loads((out / "parts_orbit.json").read_text())))
views = {"front_three_quarter": (40, -1.3, 1.0, -1.6, 0, 0.3, -0.05), "side": (40, 1.9, 0.75, 0.4, 0, 0.3, 0),
         "above": (40, 0.0, 2.2, 1.1, 0, 0.25, 0), "play_distance": (65, 0, 1.23, 2.38, 0, 0.45, 0)}
for name, v in views.items():
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", godot, "--path", str(HERE), "--rendering-driver", "opengl3",
                    "--resolution", "960x600", "-s", "render.gd", "--", str(out / "parts_orbit.json"), str(out / f"{name}.png"), *map(str, v)],
                   check=True, capture_output=True)
    print("wrote", out / f"{name}.png")
