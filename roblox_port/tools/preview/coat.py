#!/usr/bin/env python3
"""How does the abdomen's coat treat the pattern and the outline? Measured on Godot-shim renders of a part list (not Roblox rendering:
use it to compare two coats, not as a judgement of how fuzzy the spider looks).
Usage: python3 tools/preview/coat.py path/to/godot parts.json work_dir [top,play_distance,game_camera] [tail]   (needs numpy, OpenCV and Pillow)
  parts.json comes from preview.py; `tail` is how many hairs after the abdomen and head coat belong to the tufts, ruff and palp fluff
  (44 at full detail: 20 + 10 + 14; the default).
Renders the bare abdomen, the abdomen with its pattern (body, spots, band, speckles: the pattern as designed), and the pattern with
the coat's hairs only, its fur shells only, and both. Reports, per layer:
  white:   how much of the designed white is still as bright as it was inside the silhouette (share of white pixels at 85 % or more
           of their bare brightness) and its mean brightness against the bare one;
  shards:  pixels inside the silhouette that the coat made much brighter (by 40/255 or more) than the bare body, away from the white
           (pale hairs lying on black), and how many blobs of 2+ pixels they form;
  black:   how much the coat lifts the black body (mean over the black, away from the white);
  outline: how far the layer reaches past the bare silhouette at two visibilities (faint: 12/255 from the background, solid: 60/255):
           mean over the outline, 95th percentile, farthest, and blobs beyond a limit."""
import json, math, pathlib, subprocess, sys
import numpy as np, cv2
from PIL import Image
if len(sys.argv) < 4:
    sys.exit(__doc__)
godot, parts_file, work = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3]).resolve()
views_wanted = sys.argv[4].split(",") if len(sys.argv) > 4 else ["top", "play_distance", "game_camera"]
TAIL = int(sys.argv[5]) if len(sys.argv) > 5 else 44  # tufts + ruff + palp fluff, after the abdomen and head coat
work.mkdir(parents=True, exist_ok=True)
HERE = pathlib.Path(__file__).resolve().parent  # tools/preview, where render.gd is
VIEWS = {  # as preview.py: fov, eye xyz, target xyz, resolution
    "top": (40, 0.0, 2.5, 0.42, 0, 0.31, 0.0, "960x600"),
    "play_distance": (65, 0, 1.23, 2.38, 0, 0.45, 0, "960x600"),
    "game_camera": (65, 0.0, 2.305, 4.755, 0, 0.76, 0.0, "1920x1080"),
}
parts = json.load(open(parts_file))
abd = [p for p in parts if p["n"] == "Abdomen"][0]
def rel(q):
    return math.sqrt(sum(((q["p"][i] - abd["p"][i]) / (abd["size"][i] / 2)) ** 2 for i in range(3)))
body_only = [abd]
pattern = [p for p in parts if p["n"] in ("Abdomen", "AbdomenSpot", "FrontBand", "Speckle")]
first = next(i for i, p in enumerate(parts) if p["n"] == "Seta")
last = first
while last < len(parts) and parts[last]["n"] == "Seta": last += 1
body_hairs = parts[first:last - TAIL]
hairs = [p for p in body_hairs if 0.75 < rel(p) < 1.6 and p["p"][2] > -0.02]
shells = [p for p in parts if p["n"] == "FuzzShell" and rel(p) < 0.05]
def render(name, plist, view):
    j = work / f"{name}.json"; j.write_text(json.dumps(plist)); png = work / f"{name}.png"
    v = VIEWS[view]
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", godot, "--path", str(HERE), "--rendering-driver", "opengl3",
                    "--resolution", v[7], "-s", "render.gd", "--", str(j), str(png), *map(str, v[:7])], check=True, capture_output=True)
    return np.array(Image.open(png).convert("RGB")).astype(np.float32)
def lum(a): return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
K3 = np.ones((3, 3), np.uint8)
def blobs(mask, minpx):
    n, lab = cv2.connectedComponents(mask.astype(np.uint8), connectivity=8)
    return sum(1 for k in range(1, n) if (lab == k).sum() >= minpx)
print(f"{len(parts)} parts; abdomen coat: {len(hairs)} hairs, {len(shells)} shells")
for view in views_wanted:
    far_limit = 6 if view == "game_camera" else 12
    empty = render("empty_" + view, [], view)
    bare = render("bare_" + view, body_only, view)
    ideal = render("ideal_" + view, pattern, view)
    layers = {"hairs": pattern + hairs, "shells": pattern + shells, "both": pattern + hairs + shells}
    img = {k: render(k + "_" + view, v, view) for k, v in layers.items()}
    m0 = (np.abs(bare - empty).max(axis=2) > 10)  # the bare body's silhouette (the white spots are as white as the background in the top view)
    ys, xs = np.nonzero(m0)
    roi = np.zeros_like(m0); pad = 30
    roi[max(0, ys.min() - pad): ys.max() + pad, max(0, xs.min() - pad): xs.max() + pad] = True
    inner = cv2.erode(m0.astype(np.uint8), K3, iterations=2).astype(bool)
    Lb, L0 = lum(bare), lum(ideal)
    white = (L0 > 180) & (L0 - Lb > 60) & inner  # where the pattern is (white is much brighter than the black body)
    near = cv2.dilate(white.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    black = inner & ~near
    per = (m0 & ~cv2.erode(m0.astype(np.uint8), K3).astype(bool)).sum()
    dist = cv2.distanceTransform((~m0).astype(np.uint8), cv2.DIST_L2, 3)
    print(f"[{view}] bare abdomen {int(m0.sum())} px, designed white {int(white.sum())} px (mean brightness {L0[white].mean() if white.any() else 0:.0f}/255 against {Lb[white].mean() if white.any() else 0:.0f} bare)")
    for k, a in img.items():
        L1 = lum(a)
        kept = (L1[white] >= 0.85 * L0[white]).mean() * 100 if white.any() else 0
        dim = L1[white].mean() / max(1e-6, L0[white].mean()) * 100 if white.any() else 0
        shard = ((L1 - Lb) > 40) & inner & ~near
        lift = (L1[black] - L0[black]).mean()
        print(f"    {k:6s} white: {kept:3.0f}% of it as bright as designed (mean {dim:3.0f}%); shard pixels {int(shard.sum()):5d} in {blobs(shard, 2):2d} blobs; black lifted {lift:+5.1f}/255")
        diff = np.abs(a - empty).max(axis=2)
        for name, thr in (("faint", 12), ("solid", 60)):
            protr = (diff > thr) & ~m0 & roi
            d = dist[protr]
            far = (dist > far_limit) & (diff > thr) & roi
            print(f"           outline {name}: reach {protr.sum()/max(1,per):.2f} px mean, p95 {np.percentile(d,95) if d.size else 0:.1f}, farthest {d.max() if d.size else 0:.1f} px, {blobs(far, 3)} blobs beyond {far_limit} px")
