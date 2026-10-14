#!/usr/bin/env python3
"""Contact sheets from the preview renders in one folder (files named <set>_<view>.png).
  contact_sheet.png      rows = views (cropped to the spider, the same crop for every column), columns = before | after | after (low detail) | after, idling 5 s
  game_camera_sheet.png  the spider cut out of the 1080p game-camera frames (what the player sees), enlarged 2x
Godot-shim renders: layout and silhouette only, not Roblox rendering.
Usage: python3 tools/preview/contact_sheet.py folder"""
import re, sys, pathlib
from PIL import Image, ImageChops, ImageDraw
folder = pathlib.Path(sys.argv[1])
SETS = [("before", "Before (old rig)"), ("after", "After (full detail)"), ("low", "After, low detail"), ("idle", "After, idling 5 s")]
VIEWS = [("front_three_quarter", "Front three-quarter"), ("top", "Top"), ("face_closeup", "Face close-up"), ("play_distance", "Play distance")]
CELL = (480, 300)
LABEL, TOP = 150, 34
sheet = Image.new("RGB", (LABEL + CELL[0] * len(SETS), TOP + CELL[1] * len(VIEWS)), (245, 245, 245))
draw = ImageDraw.Draw(sheet)
def counted(key, title):
    """The title with the part count from <key>_counts.txt (written by preview.py), if there is one."""
    f = folder / f"{key}_counts.txt"
    m = re.search(r"parts_total=(\d+)", f.read_text()) if f.exists() else None
    return f"{title}, {m.group(1)} parts" if m else title


for c, (key, title) in enumerate(SETS):
    draw.text((LABEL + c * CELL[0] + 8, 10), counted(key, title), fill=(20, 20, 20))
def spider_box(png):
    """Bounding box of the dark pixels (the spider) in a render, or None."""
    return Image.open(png).convert("L").point(lambda v: 255 if v < 70 else 0).getbbox()


def crop_box(boxes, size, aspect):
    """One crop for a whole row: the union of the boxes, 12 % margin, widened to the cell's aspect ratio, inside the frame."""
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes); x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    w, h = (x1 - x0) * 1.24, (y1 - y0) * 1.24
    if w / h < aspect: w = h * aspect
    else: h = w / aspect
    w, h = min(w, size[0]), min(h, size[1])
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    left = min(max(cx - w / 2, 0), size[0] - w); top = min(max(cy - h / 2, 0), size[1] - h)
    return (int(left), int(top), int(left + w), int(top + h))


for r, (view, name) in enumerate(VIEWS):
    draw.text((8, TOP + r * CELL[1] + CELL[1] // 2), name, fill=(20, 20, 20))
    pngs = [(c, folder / f"{key}_{view}.png") for c, (key, _) in enumerate(SETS) if (folder / f"{key}_{view}.png").exists()]
    boxes = [b for _, png in pngs for b in [spider_box(png)] if b]
    if not boxes: continue
    crop = crop_box(boxes, Image.open(pngs[0][1]).size, CELL[0] / CELL[1])  # the same crop for every column of the row
    for c, png in pngs:
        sheet.paste(Image.open(png).convert("RGB").crop(crop).resize(CELL, Image.LANCZOS), (LABEL + c * CELL[0], TOP + r * CELL[1]))
sheet.save(folder / "contact_sheet.png")

# the 1080p game-camera frames: crop to the spider's bounding box (the frame is mostly floor), same box for every set
frames = {key: folder / f"{key}_game_camera.png" for key, _ in SETS if (folder / f"{key}_game_camera.png").exists()}
if frames:
    boxes = []
    for png in frames.values():
        im = Image.open(png).convert("RGB")
        bg = Image.new("RGB", im.size, im.getpixel((2, im.size[1] - 2)))
        box = ImageChops.difference(im, bg).convert("L").point(lambda v: 255 if v > 40 else 0).getbbox()
        if box: boxes.append(box)
    # the floor in the shim renders is lighter than the spider and a different colour than the corner: use the dark spider pixels
    boxes = []
    for png in frames.values():
        im = Image.open(png).convert("L")
        box = im.point(lambda v: 255 if v < 70 else 0).getbbox()
        if box: boxes.append(box)
    x0 = min(b[0] for b in boxes) - 30; y0 = min(b[1] for b in boxes) - 30
    x1 = max(b[2] for b in boxes) + 30; y1 = max(b[3] for b in boxes) + 30
    w, h = (x1 - x0) * 2, (y1 - y0) * 2
    out = Image.new("RGB", (w * len(frames), h + 28), (245, 245, 245))
    d = ImageDraw.Draw(out)
    for i, (key, png) in enumerate(frames.items()):
        title = counted(key, dict(SETS)[key])
        d.text((i * w + 8, 8), title + "  (game camera, 1080p, cropped and enlarged 2x)", fill=(20, 20, 20))
        out.paste(Image.open(png).convert("RGB").crop((x0, y0, x1, y1)).resize((w, h), Image.LANCZOS), (i * w, 28))
    out.save(folder / "game_camera_sheet.png")
print("wrote", folder / "contact_sheet.png", "and", folder / "game_camera_sheet.png" if frames else "(no game camera frames)")
