#!/usr/bin/env python3
"""How soft is the coat's outline at the game camera? Renders the spider's body (legs and leg hairs left out) with and without its
hairs and fur shells at 1920x1080, FOV 65, 5 studs away (the game's usual camera, about 170 px per stud), and reports how far
the coat reaches past the bare body outline: the extra pixels divided by the outline's length, at a faint and a stronger
threshold. A Godot-shim measurement of the parts a Roblox rig builds, not Roblox rendering; use it to compare two part lists
(for example the old rig's before_parts.json and a new one), not as a judgement of how fuzzy the spider looks.
Usage: python3 tools/preview/fringe.py path/to/godot parts.json work_dir   (parts.json from preview.py; needs Pillow)"""
import json, math, pathlib, re, subprocess, sys
from PIL import Image, ImageChops

HERE = pathlib.Path(__file__).resolve().parent
if len(sys.argv) != 4:
    sys.exit(__doc__)
godot, parts_file, work = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3]).resolve()
work.mkdir(parents=True, exist_ok=True)
parts = json.load(open(parts_file))
VIEW = ["65", "0.0", "2.305", "4.755", "0", "0.76", "0.0"]  # fov, eye x y z, target x y z: 5 studs away, looking down a little
LEG = re.compile(r"^(Femur|Tibia|Tarsus|Knee|Ankle|Foot)\d|Band\d$")


def part(name):
    q = [p for p in parts if p["n"] == name][0]
    return q["p"], q["size"]


abdomen, abdomen_size = part("Abdomen")
head, head_size = part("Cephalothorax")


def near_body(q):
    """A hair belongs to the body (not a leg) if it sits close to the abdomen's or the head's surface."""
    for c, s in ((abdomen, abdomen_size), (head, head_size)):
        r = math.sqrt(sum(((q["p"][i] - c[i]) / (s[i] / 2)) ** 2 for i in range(3)))
        if 0.75 < r < 1.6:
            return True
    return False


body = [q for q in parts if not LEG.search(q["n"]) and (q["n"] != "Seta" or near_body(q))]
bare = [q for q in body if q["n"] not in ("Seta", "FuzzShell")]


def render(name, plist):
    j = work / f"{name}.json"
    j.write_text(json.dumps(plist))
    png = work / f"{name}.png"
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", godot, "--path", str(HERE), "--rendering-driver", "opengl3",
                    "--resolution", "1920x1080", "-s", "render.gd", "--", str(j), str(png), *VIEW], check=True, capture_output=True)
    return Image.open(png).convert("RGB")


empty = render("empty", [])
bare_img = render("bare", bare)
sets = {
    "shells only": bare + [q for q in body if q["n"] == "FuzzShell"],
    "hairs only": bare + [q for q in body if q["n"] == "Seta"],
    "all": body,
}
images = {label: render("set" + str(i), plist) for i, (label, plist) in enumerate(sets.items())}


def mask(img, threshold):
    return ImageChops.difference(img, empty).convert("L").point(lambda v: 255 if v > threshold else 0)


hairs = sum(1 for q in body if q["n"] == "Seta")
for label, img in images.items():
    for threshold in (12, 24):
        m0, m1 = mask(bare_img, threshold), mask(img, threshold)
        p0, p1 = m0.load(), m1.load()
        x0, y0, x1, y1 = m0.getbbox()
        bare_px = coat_px = outline = 0
        for y in range(y0 - 40, y1 + 40):
            for x in range(x0 - 40, x1 + 40):
                if p0[x, y]:
                    bare_px += 1
                    if not (p0[x - 1, y] and p0[x + 1, y] and p0[x, y - 1] and p0[x, y + 1]):
                        outline += 1
                if p1[x, y]:
                    coat_px += 1
        print(f"{label:12s} threshold {threshold}: bare body {bare_px} px, with coat {coat_px} px, fringe {coat_px - bare_px} px over a "
              f"{outline} px outline -> {(coat_px - bare_px) / max(1, outline):.2f} px wide ({len(body)} parts, {hairs} hairs)")
