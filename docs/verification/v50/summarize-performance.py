"""Extract source-qualified scene timings; never substitute simulated CLI frames."""
from pathlib import Path
import json
import re

out = Path(__file__).resolve().parent
baseline = (out / "before-corrected-native.txt").read_text(encoding="utf-8-sig")
after = (out / "native-H-full-visual-profile.txt").read_text(encoding="utf-8-sig")
after += (out / "native-H-low-profile.txt").read_text(encoding="utf-8-sig")
pattern = re.compile(r"\[CHET_V50_PROFILE\] (before|after) (full|low) (\S+) (\d+) ([\d.]+) mean_ms ([\d.]+) p95_ms ([\d.]+) worst_ms ([\d.]+) mode (\S+) alive (\S+)")
rows = {}
for match in pattern.finditer(baseline + after):
    phase, tier, scene, frames, seconds, mean, p95, worst, mode, alive = match.groups()
    assert mode == "attached" and alive == "true"
    rows[phase, tier, scene] = dict(phase=phase, tier=tier, scene=scene,
                                  frames=int(frames), seconds=float(seconds),
                                  mean_ms=float(mean), p95_ms=float(p95), worst_ms=float(worst))
assert len(rows) == 20, f"expected five scenes x two tiers x two phases, got {len(rows)}"
receipt = {"after_source_commit": "856c12e3e71d9b79282954013142fa5577fc3f19",
           "viewport": "1105x435 Studio player viewport, desktop",
           "method": "same route, normal camera, noon, 7s settle, 5s sample, no concurrent local regression/compiler jobs",
           "limits": "observational before/after, warmup and system variance; not a phone benchmark or proof of causal FPS gain",
           "samples": list(rows.values())}
(out / "performance.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8", newline="\n")
table = ["# Native scene performance", "", receipt["method"] + ". " + receipt["limits"] + ".", "",
         "Times in milliseconds. Values are mean / p95 / worst. Lower is better.", "",
         "| Detail | Scene | Before | After |", "|---|---|---:|---:|"]
for tier in ["full", "low"]:
    for scene in ["sill", "garden_b2", "meadow_a3", "deck_n2", "hut_doorway"]:
        a, b = rows["before", tier, scene], rows["after", tier, scene]
        fmt = lambda r: f"{r['mean_ms']:.2f} / {r['p95_ms']:.2f} / {r['worst_ms']:.2f}"
        table.append(f"| {tier} | {scene} | {fmt(a)} | {fmt(b)} |")
table.extend(["", "The pond bank is deck_n2. The initial pond_a2 underwater view is excluded.",
              "Do not attribute the whole observational difference to the distant-cat cache.",
              "Its separate paired comparison measures the allocation tradeoff without claiming a stable FPS improvement.", ""])
(out / "PERFORMANCE.md").write_text("\n".join(table), encoding="utf-8", newline="\n")
print("\n".join(table))
