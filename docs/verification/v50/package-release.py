"""Build a bounded, active-Roblox handoff after final receipts are written."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

repo = Path(__file__).resolve().parents[3]
destination = Path("C:/Users/natha/claude-xfer")
out = repo / "docs/verification/v50"
evidence = "3112f8aa4f3f192f"
release = out / "release.json"
receipt = json.loads(release.read_text(encoding="utf-8"))
assert receipt["published"] is True
assert receipt["evidence_id"] == evidence
tip = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
folders = ["roblox_port/src", "roblox_port/tests", "roblox_port/tools", "roblox_port/assets",
           "docs/verification/v50"]
files = set()
for name in folders:
    for p in (repo / name).rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(repo)
        if any(x in {"__pycache__", "reports", "captures", "snapshots"} for x in rel.parts):
            continue
        if p.suffix.lower() in {".zip", ".pyc"} or p.name == "portable-package.json":
            continue
        files.add(p)
for name in ["roblox_port/default.project.json", "roblox_port/tests.project.json",
             "roblox_port/.luaurc", "roblox_port/README.md",
             "roblox_port/TheWindowsill.rbxlx", "roblox_port/TheWindowsillTests.rbxlx",
             "chet/HANDOFF-v50.md", "chet/review-5.md", "docs/DECISIONS.md",
             "docs/reference/chet-prompt-v49.md", "docs/MESHES.md", ".github/workflows/roblox-port.yml"]:
    p = repo / name
    assert p.is_file(), name
    files.add(p)
rows = [{"path": p.relative_to(repo).as_posix(), "bytes": p.stat().st_size,
         "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]
manifest = {"source_commit": receipt["source_commit"], "document_tip": tip,
            "evidence_id": evidence, "place_version": receipt["place_version"],
            "scope": "Active Roblox source, tests, tools, assets, playable builds and v50 receipts; Godot excluded",
            "files": rows}
archive = destination / f"Windowsill-v50-place{receipt['place_version']}-{evidence}.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):
        z.write(p, p.relative_to(repo).as_posix())
    z.writestr("HANDOFF-MANIFEST.json", json.dumps(manifest, indent=2) + "\n")
manifest.pop("files")
manifest.update(path=str(archive), bytes=archive.stat().st_size, file_count=len(rows),
                sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
(out / "portable-package.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                            encoding="utf-8", newline="\n")
print(json.dumps(manifest, indent=2))
