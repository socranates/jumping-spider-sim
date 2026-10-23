"""Record only terminal exact-source replacement proof; no test reruns."""
from pathlib import Path
import datetime, json, subprocess, sys
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
subprocess.run([sys.executable, str(H / "verify-replacement.py")], cwd=ROOT, check=True)
proof = json.loads((H / "replacement-verification.json").read_text(encoding="utf8"))
assert proof["total_assertions"] == 204254 and proof["failed"] == 0
header = """# Latest checkpoint - private session replacement verified, 2026-10-23

Production source is still `8c9b71896736d85d43e02fec1521bcd567cdb33f`, with unchanged completed Windows/Linux full gates (each 76/468880/0), compile 222, strict clean and native scripted fixture 82/0. The unchanged diagnostic-free candidate remains `C:\\Users\\natha\\claude-xfer\\Windowsill-production-8c9b718\\TheWindowsill-production-candidate.rbxlx`. Do not repeat those completed unchanged gates. Nothing is published.

Four new private replacement adapters wrap the actual SaveService/SaveClient/SaveContinuation and preceding all-slot owner. Capability freezes on first compatible hello. Request/offer/ACK closes the old owner, commit/ready opens a fresh epoch, and a nonce-bound new loaded reply requires a confirmed fresh-menu callback. Old intents/receipts/checkpoints/offer work and suspended client update emissions are fenced. Final P progress is preserved; confirmed R/A1/M1 remain unchanged. The account key is retained. Ordinary rolling request debt survives replacement; a new epoch cannot reopen a startup budget lane. Lost packets are idempotent. Failed saves, deadlines, refused application callbacks and failed/cancelled constructors stay read-only. The actual service departure counter drains removal/shutdown during a yielded close.

`replacement-full-1` passes all 29 named groups / 204254 checks / 0 failures: preceding 201587 plus 2667 replacement assertions. `replacement-types-6` compiles all 40 candidates and the complete overlay is strict-clean. `verify-replacement.py` reconstructs the bundle and binds all source, committed production, outputs and type inputs. Three exact mode traces and consecutive replacements are covered. Focused-8 is the current focused pass; intermediate failures and corrections are retained in `docs/save-slot-isolation/SESSION-REPLACEMENT.md`. All owned jobs are terminal.

These are memory-backed, synthetic-clock adapter tests. The pause/menu callbacks are scripted, not actual native game callbacks. Ordinary engine recovery/replacement remains uninstalled. Real DataStore/rejoin, measured payload/loading costs, native whole recovery/replacement and general gameplay/input/audio/sustained performance are still open. No release or whole-game claim. Original OneDrive/frozen Godot, three unrelated save-cost outputs and untracked sourcemap are untouched.

Next: implement/qualify trusted pristine server template/context construction (one authored source with bounded owned mode profiles), review initial-visit factory cancellation, then connect actual game recovery/pause/menu and safe error/exit callbacks through the adapters. Preserve the existing controls, camera and local checkpoints. Before engine activation, prove payload/network budgets and native recovery/replacement; then isolated real test-store save/rejoin and broader native game/performance gates. The full optimization and stability goal remains active.

---

"""
for relative in ["chet/save-continue.md", "RESUME-AFTER-RESTART.md"]:
    path = ROOT / relative
    text = path.read_text(encoding="utf8")
    assert text.startswith("# Latest checkpoint - private all-slot recovery owner verified, 2026-10-23")
    path.write_text(header + text, encoding="utf8", newline="\n")
path = ROOT / "docs/audit/current-source/requirements.json"
data = json.loads(path.read_text(encoding="utf8")); assert data["source"] == proof["source"]
data.update(as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), latest_private_session_replacement=proof,
            goal_complete=False, published=False)
for row in data["requirements"]:
    if row["id"] in ["legacy-world-restore", "slot-protection-A04"]:
        row["status"] = "private-profile-and-replacement-verified-activation-open"
        row["evidence_boundary"] += " Private explicit replacement now passes 204254 checks/0 with40 candidates strict-clean, including actual service/client/continuation adapters, all three modes, final progress/physical-key preservation, carried rolling request debt, stale/yielded work fences, loss retries, consecutive replacements, failed persistence and cancelled constructors, removal/shutdown during closing. Application pause/menu callbacks remain scripted; engine/menu activation, trusted production templates, native replacement, measured payload/performance and real test-store rejoin remain open."
        row["references"] += ["docs/save-slot-isolation/SESSION-REPLACEMENT.md", "docs/save-slot-isolation/replacement-verification.json"]
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf8", newline="\n")
print("Terminal replacement milestone recorded; broader goal active, production unchanged")
