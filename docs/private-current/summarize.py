"""Bind the private publication and finalized standalone observations."""
from pathlib import Path
import collections
import hashlib
import json
import re

H = Path(__file__).resolve().parent
sha = lambda data: hashlib.sha256(data).hexdigest()
read = lambda name: json.loads((H / name).read_text(encoding="utf8"))
publication = read("publication.json")
prepared = read("prepared.json")
assert publication["published_version"] == 14
assert publication["source_guards"] == 2 and not publication["creator_errors"]
assert sha(Path(read("native.json")["saved_editor"]).read_bytes()) == publication["saved_editor_sha256"]
assert "Value: 1" in (H / "dashboard-after-published.txt").read_text()
access = (H / "dashboard-after-access.txt").read_text()
assert access.count("Description: Private") == 2
rows = []
for folder in ["player-first-final", "player-warm-closed"]:
    result = read(folder + "/player.json")
    raw = Path(result["original_log"]).read_bytes()
    assert sha(raw) == result["log_sha256"], "Finalize only after Player exits"
    assert result["complete"] and result["published_version"] == 14
    assert result["evidence_id"] == prepared["evidence_id"]
    assert result["test_store"] == prepared["test_store"]
    assert not result["creator_errors"] and not result["recognizable_script_errors"]
    events = result["events"]
    windows = [e["value"] for e in events if e["kind"] == "WINDOW"]
    end = next(e["value"] for e in events if e["kind"] == "END")
    assert len(windows) == 6 and end["focus_lost"] == 0
    for window in windows:
        for key in ["raw", "callbacks"]:
            dist = window[key]
            assert 0 <= dist["p50_ms"] <= dist["p95_ms"] <= dist["p99_ms"] <= dist["max_ms"]
    seconds = sum(w["wall_seconds"] for w in windows[-2:])
    frames = sum(w["frames"] for w in windows[-2:])
    rows.append(dict(
        run=result["run"], title_ready_s=result["title_ready_s"],
        first_callback=result["first_callback"],
        largest_observed_callback_ms=max(w["callbacks"]["max_ms"] for w in windows),
        last30_mean_ms=seconds / frames * 1000, last30_callback_rate=frames / seconds,
        last30_worst_callback_ms=max(w["callbacks"]["max_ms"] for w in windows[-2:]),
        heartbeat_callbacks=sum(w["frames"] for w in windows),
        creator_warnings=len(result["creator_warnings"]), receipt=folder + "/player.json"))
    counts = collections.Counter()
    for line in raw.decode().splitlines():
        if ",Error " in line or ",Warning " in line:
            match = re.search(r"\[(?:D?FLog|DFInt|FInt)::([^]]+)\]", line)
            counts[match[1] if match else "other"] += 1
    platform = dict(log_sha256=result["log_sha256"], categories=dict(counts),
                    low_memory_lines=sum("low memory" in line.lower() or "low-memory" in line.lower()
                                         for line in raw.decode().splitlines()),
                    scope="Counts only. Platform categories are not automatically game script exceptions; full logs remain local.")
    (H / folder / "platform-counts.json").write_bytes((json.dumps(platform, indent=2) + "\n").encode())
summary = dict(published_version=14, evidence_id=prepared["evidence_id"],
               private_place=publication["place_id"], source_guards=2,
               complete_runs=2, windows=12, runs=rows,
               limits="Arrival and ordinary entry only. Different title/intro/gameplay mixes; no paired speedup, full-life, save/rejoin, whole-map or physical-device qualification. Startup cause unresolved. No independent download and rehash of published asset.")
(H / "player-summary.json").write_bytes((json.dumps(summary, indent=2) + "\n").encode())
print(json.dumps(summary, indent=2))
