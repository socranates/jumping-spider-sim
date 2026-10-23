"""Finalize terminal exact-source proof; never rerun a test or dispatch CI."""
from pathlib import Path
import datetime,json,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE="8c9b71896736d85d43e02fec1521bcd567cdb33f"
subprocess.run([sys.executable,str(H/"verify-gates.py")],cwd=ROOT,check=True)
assert not (H/"production-candidate.json").exists(),"Preserve an already built candidate"
subprocess.run([sys.executable,str(H/"build-production.py")],cwd=ROOT,check=True)
v=json.loads((H/"full-verification.json").read_text(encoding="utf8"));assert v["source"]==SOURCE
win=json.loads((H/"windows-full-process.json").read_text(encoding="utf8"));c=json.loads((H/"production-candidate.json").read_text(encoding="utf8"))
block=f"""# Latest checkpoint - selected save-slot ownership fully qualified, 2026-10-23

Production `{SOURCE}` is committed/pushed on `codex/save-continue`. Both full platforms passed **76 suites /468880 checks /0 failures**: Windows exec63574 terminal exit0 ({win['elapsed_seconds']:.1f}seconds), Linux push run39974665033 terminal success.222 compile, strict clean, runner5. Local-return41 includes8 new compatibility/survival checks. `docs/restored-slot-ownership/full-verification.json` binds exact immutable source/logs and current native/private proof. Do not repeat these unchanged completed gates.

Both local and remote prepared returns pass their immutable selected slot to the actual restore; gentle records validly kept under Main retain Main transport authority while preserving their rules. End-screen offer lookup follows the active local store, matching life.save. New Easy/Normal lives retain their usual slots. No save schema/global alias field/Easy overwrite/control or camera change.

Current private full cohort is1012 actual-game +187257 preceding =188269/0,35 candidates strict-clean; restored-slot-attempt-1/types-1 and verify-recovery-restored-slot.py bind it. Main/gentle actual game entry receives Main authority, its actual next rest receives stored ACK from Main, and Easy/A1/M1 stay unchanged. Earlier a97b0b5's53-check alias counterexample is historical and resolved in this path. Private callbacks/owner are still not installed in engine/menu; these storage adapters run over memory, not live DataStore/native RPC.

Current scripted Studio fixture passes82/0 with223 fingerprints and0 CreatorErrors: preceding70 cases plus12 physical-slot/survival/controlled-ending/new-life checks. Gentle starvation is still refused. The ending lookup uses a temporary presentation callback and is not a natural gentle death claim. Model unchanged, separate editor copy saved; Studio stopped and confirmed closed. Native full recovery, natural whole life, physical controls, sustained FPS/audio and online rejoin remain open.

Exact-source diagnostic-free candidate: `{c['place']}`;222 production scripts, SHA256 `{c['place_sha256']}`. Normal persistence configuration, not a verified ordinary online client or published release. No main merge/publication/release synchronization. All owned full/private/type/native jobs are terminal.

Next continue trusted server profile selection and explicit service/client replacement epochs, then normal-menu callbacks and safe error/exit installation. One Session/worker/lease must own all slots. Runtime.discover can replace a finished offered reader without withdrawing an older slot observation, but Pipeline captures context at construction; changing owner.mode or recovery.context is insufficient. Runtime.dismiss withdraws an offer. All-slot discovery and freshly rechecked selected offer need cancellation/drain/global-choice fences, trusted templates and preserved lease/baseline identity; after accepted writes, require an explicit replacement epoch. Broad goal remains active. Preserve original OneDrive/frozen Godot, unrelated three save-cost outputs and untracked sourcemap.

---

"""
for name in ["chet/save-continue.md","RESUME-AFTER-RESTART.md"]:
 p=ROOT/name;s=p.read_text(encoding="utf8");assert s.startswith("# Latest checkpoint - selected save-slot ownership corrected, 2026-10-23")
 p.write_text(block+s.split("---\n\n",1)[1],encoding="utf8",newline="\n")
(H/"README.md").write_text(block.replace("# Latest checkpoint - selected save-slot ownership fully qualified, 2026-10-23","# Restored slot ownership - verified"),encoding="utf8",newline="\n")
p=ROOT/"docs/audit/current-source/requirements.json";d=json.loads(p.read_text(encoding="utf8"));assert d["source"]==SOURCE
d.update(as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goal_complete=False,published=False)
for row in d["requirements"]:
 if row["id"]=="cli-and-runner":
  row.update(status="both-platforms-verified-native-slot-pass",evidence_boundary="Current8c9b718: Windows63574 terminal exit0, Linux39974665033 terminal success; each76/468880/0, compile222, strict clean, runner5. Local-return41 includes8new. Native82/0,223fingerprints,0CreatorErrors, stopped/closed; current private188269/0/35types includes Main/gentle actual authority/next-rest stored ACK in Main without touching Easy. Exact source/log/candidate bound; not native full recovery, normal-menu activation, online rejoin or release proof.")
  row["references"] += ["docs/restored-slot-ownership/full-verification.json","docs/restored-slot-ownership/production-candidate.json"]
 if row["id"]=="slot-protection-A04":
  row["status"]="selected-slot-fix-qualified-with-limits"
  row["evidence_boundary"] += " Terminal8c9b718 full gates76/468880/0 both; native82/0. Slot compatibility correction is qualified; global profile/epoch/menu and online activation still separate."
p.write_text(json.dumps(d,indent=2)+"\n",encoding="utf8",newline="\n")
print("Terminal selected-slot qualification and candidate recorded; broader goal active")
