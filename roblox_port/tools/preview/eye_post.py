#!/usr/bin/env python3
"""Off-Roblox impression of the spider-eye picture (ROBLOX-20) on a scene.py render: applies Shared/Data/Eyes' colour grade
(tint, brightness, contrast, saturation, in roughly the order Roblox's ColorCorrectionEffect does), the BlurEffect size as a
Gaussian blur, the telephoto vignette, the two retina strips where EyeOptics.retinaStrips puts them, and movement rings at given
world points. Depth of field is NOT imitated (Roblox's DOF focuses on the looked-at distance; this shows the whole frame sharp
except the global blur), nor bloom or Roblox's own shading. A picture of the idea for review, not of the engine.
Roblox does not document whether ColorCorrectionEffect tints before or after it desaturates; this applies brightness, contrast and
saturation first and the tint last (the common "sepia" use), or the tint first with --tint-first.
Usage (from roblox_port/): python3 tools/preview/eye_post.py path/to/luau render.png k out.png [--camera ex,ey,ez,ax,ay,az,fov]
         [--ring x,y,z,diameter_px]... [--tint-first]
k is 0 (side eyes) or 1 (principal eyes); the numbers come from the real Data/Eyes and UI/EyeOptics through tools/preview/eye_dump.luau."""
import argparse, importlib.util, json, math, pathlib, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser()
ap.add_argument("luau"); ap.add_argument("render"); ap.add_argument("k", type=int); ap.add_argument("out")
ap.add_argument("--camera", default="")
ap.add_argument("--ring", action="append", default=[])
ap.add_argument("--tint-first", action="store_true")
a = ap.parse_args()
spec = importlib.util.spec_from_file_location("jss_tests_run", ROOT / "tests" / "run.py")
run = importlib.util.module_from_spec(spec); spec.loader.exec_module(run)
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(run.bundle(str(ROOT / "tools" / "preview" / "eye_dump.luau")))
lines = subprocess.run([a.luau, f.name], capture_output=True, text=True).stdout.splitlines()
profiles = [json.loads(l[len("EYEJSON "):]) for l in lines if l.startswith("EYEJSON ")]
prof = [p for p in profiles if p["k"] == a.k][0]
img = Image.open(a.render).convert("RGB")
W, H = img.size
if prof["blur"] > 0.05:
    img = img.filter(ImageFilter.GaussianBlur(radius=prof["blur"] * 0.8))
c = np.asarray(img).astype(np.float32) / 255.0
tint = np.array(prof["tint"], dtype=np.float32)
if a.tint_first:
    c = c * tint
c = c + prof["brightness"]
c = (c - 0.5) * (1.0 + prof["contrast"]) + 0.5
lum = (c * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=2, keepdims=True)
c = lum + (c - lum) * (1.0 + prof["sat"])
if not a.tint_first:
    c = c * tint
c = np.clip(c, 0, 1)
# vignette: four edge ramps (as SpiderEyes' edge Frames), dark green-black
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
edge = np.minimum(np.minimum(xx / (W * 0.18), (W - 1 - xx) / (W * 0.18)), np.minimum(yy / (H * 0.2), (H - 1 - yy) / (H * 0.2)))
alpha = (1.0 - np.clip(edge, 0, 1)) ** 2 * prof["vignette"]
c = c * (1 - alpha[..., None]) + np.array([8, 20, 12], dtype=np.float32) / 255.0 * alpha[..., None]
img = Image.fromarray((c * 255).astype(np.uint8))
over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(over)
def strip(s):
    # a rounded strip, its long axis vertical before turning by r degrees about its centre
    w, h, r = s["w"], s["h"], math.radians(s["r"])
    pts = []
    rad = w / 2
    for i in range(0, 181, 10):  # top cap
        t = math.radians(180 + i)
        pts.append((rad * math.cos(t), -(h / 2 - rad) + rad * math.sin(t)))
    for i in range(0, 181, 10):  # bottom cap
        t = math.radians(i)
        pts.append((rad * math.cos(t), (h / 2 - rad) + rad * math.sin(t)))
    out = [(s["x"] + x * math.cos(r) - y * math.sin(r), s["y"] + x * math.sin(r) + y * math.cos(r)) for x, y in pts]
    d.polygon(out, fill=(200, 255, 220, int(255 * (1 - prof["fill"]))))
    d.line(out + [out[0]], fill=(200, 255, 220, int(255 * (1 - prof["stroke"]))), width=2)
for s in prof["strips"]:
    strip(s)
if a.camera:
    ex, ey, ez, ax, ay, az, fov = map(float, a.camera.split(","))
    eye = np.array([ex, ey, ez]); fwd = np.array([ax, ay, az]) - eye; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right); up = np.cross(right, fwd)
    f = (H / 2) / math.tan(math.radians(fov) / 2)
    for r in a.ring:
        x, y, z, dia = map(float, r.split(","))
        v = np.array([x, y, z]) - eye
        zc = v @ fwd
        if zc <= 0:
            continue
        px, py = W / 2 + f * (v @ right) / zc, H / 2 - f * (v @ up) / zc
        for grow, al in ((1.0, 0.85), (1.35, 0.45), (1.7, 0.2)):
            rr = dia * grow / 2
            d.ellipse([px - rr - 1.5, py - rr - 1.5, px + rr + 1.5, py + rr + 1.5], outline=(8, 20, 12, int(150 * al)), width=2)
            d.ellipse([px - rr, py - rr, px + rr, py + rr], outline=(226, 255, 232, int(255 * al)), width=2)
img = Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")
img.save(a.out)
print("wrote", a.out)
