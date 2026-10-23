"""Record only a terminal verified profile cohort; do not rerun tests."""
from pathlib import Path
import datetime, json, subprocess, sys
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
subprocess.run([sys.executable, str(H / "verify-recovery-profile-owner.py")], cwd=ROOT, check=True)
proof = json.loads((H / "recovery-profile-owner-verification.json").read_text(encoding="utf8"))
assert proof["failed"] == 0 and proof["total_assertions"] == 201587
header = """# Latest checkpoint - private all-slot recovery owner verified, 2026-10-23

Production source remains `8c9b71896736d85d43e02fec1521bcd567cdb33f`. Its completed Windows and Linux full runs each pass 76 suites / 468880 checks / 0 failures; native scripted fixture 82/0; compile 222 and strict clean. The diagnostic-free candidate remains `C:\\Users\\natha\\claude-xfer\\Windowsill-production-8c9b718\\TheWindowsill-production-candidate.rbxlx`. It is not published. Do not repeat these unchanged production gates.

New private `recovery-profile-owner-prototype.luau` composes the existing owner over one Session/backend/scheduler/quota. All three trusted server destination templates are bounded, copied and frozen. Coalesced discovery retains older slot observations; an explicit selection gets a fresh exact-ID read and a newly constructed pipeline for its destination. Global choice ordering cancels stale readers and drains providers before rebinding. Reentrant newer choices supersede the outer callback safely. Preaccept ordinary empty-slot choices can resume the same normal worker. After accepted migration writes, switching requires a future replacement epoch: credentials are revoked, the enforcing hold and lease remain, and closed departure preserves originals.

Full private `profile-full-1` passes 28 named groups / 201587 checks / 0 failures: preceding 188269 plus 10177 profile-owner and 3141 actual SaveService/SaveClient transport checks. All three offers coexist in a visit; each selected mode applies once, gets the actual server grant and next-rest stored ACK, and leaves other current slots/originals unchanged. `profile-types-2` compiles all 36 candidates and the full overlay is strict-clean. `verify-recovery-profile-owner.py` reconstructs and binds bundle, inputs, committed production and logs. Focused-2/3 failures and their corrections are documented, not relabelled as passes. Every owned test job is terminal.

See `docs/save-slot-isolation/RECOVERY-PROFILE-OWNER.md`. This is a server-authored profile prototype over memory-backed adapters and synthetic clocks, not normal-menu installation, native full recovery, real DataStore/rejoin, measured loading speed or a release. The engine hook remains closed. Original OneDrive/frozen Godot, three unrelated save-cost outputs and untracked sourcemap stay untouched.

Next implement explicit negotiated service/client replacement epochs, including old callback/credential/offer-work/cache revocation and safe error/cancel exit. Preserve migrated current R and immutable A1/M1 when changing modes; do not retire a recovered life merely to select another slot. Use one Session/worker/lease at a time, drain and verify closed departure, then bind the fresh epoch through an acknowledged transport transition. Keep old peers on their original protocol. Native recovery, online rejoin, natural whole-life/input/audio/sustained-performance and release gates remain open. The broad optimization and stability goal remains active.

---

"""
for relative in ["chet/save-continue.md", "RESUME-AFTER-RESTART.md"]:
    path = ROOT / relative
    text = path.read_text(encoding="utf8")
    assert text.startswith("# Latest checkpoint - selected save-slot ownership fully qualified, 2026-10-23")
    path.write_text(header + text, encoding="utf8", newline="\n")
path = ROOT / "docs/audit/current-source/requirements.json"
data = json.loads(path.read_text(encoding="utf8"))
assert data["source"] == proof["source"]
data.update(as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), latest_private_profile_owner=proof, goal_complete=False, published=False)
for row in data["requirements"]:
    if row["id"] in ["legacy-world-restore", "slot-protection-A04"]:
        row["status"] = "private-all-slot-owner-verified-activation-open"
        row["evidence_boundary"] += " New private all-slot owner: 201587 checks/0,36 strict-clean candidates; one Session/quota across three trusted profiles, fresh exact displayed selection, global/reentrant choice fences, delayed-provider drain, same-session ordinary preaccept choice and lease-only postaccept hold. Actual service/client all-three-offer visits grant each selected mode and acknowledge its next rest without changing other current slots. Memory/synthetic-clock proof only; replacement epochs, engine/menu installation, native full recovery and online rejoin remain open."
        row["references"] += ["docs/save-slot-isolation/RECOVERY-PROFILE-OWNER.md", "docs/save-slot-isolation/recovery-profile-owner-verification.json"]
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf8", newline="\n")
print("Terminal profile milestone recorded; production unchanged and broader goal active")
