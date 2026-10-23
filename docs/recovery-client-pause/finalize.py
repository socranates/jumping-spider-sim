"""Finalize only terminal exact-source gates; never start or repeat tests."""
from pathlib import Path
import datetime,json,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE="a97b0b54bfa7a49d8cec072cc4c0ebc1fd7ea8ff"
subprocess.run([sys.executable,str(H/"verify-gates.py")],cwd=ROOT,check=True)
assert not (H/"production-candidate.json").exists(),"Preserve the previous candidate"
subprocess.run([sys.executable,str(H/"build-production.py")],cwd=ROOT,check=True)
v=json.loads((H/"full-verification.json").read_text(encoding="utf8"));assert v["source"]==SOURCE
win=json.loads((H/"windows-full-process.json").read_text(encoding="utf8"))
candidate=json.loads((H/"production-candidate.json").read_text(encoding="utf8"))
block=f"""# Latest checkpoint - owned client recovery pause qualified, 2026-10-23

Production `{SOURCE}` is pushed on `codex/save-continue`. Both full gates are terminal successes: Windows unified exec28256 (exit0, {win['elapsed_seconds']:.1f}seconds) and Linux push run{v['linux_run']}; each **76 suites /468872 checks /0 failures**,222 compiles, clean strict analysis and5 runner regressions. LOCAL_RETURN33 includes six actual-adoption pause regressions. The immutable source/log proof is `docs/recovery-client-pause/full-verification.json`. Do not rerun these unchanged gates.

The client now exposes an owned pause handle independent of menu visibility; an obsolete handle cannot release its replacement and the current handle releases once. It has no production recovery caller yet. Current-source unbound Studio fixture passes70/0 with223 checked script fingerprints and0 CreatorErrors: preceding60 presentation/collision cases plus10 actual Normal local-capture/adoption/hold cases. It verifies the intended generation+1/store replacement, frozen clocks/energy with menus hidden, stale-handle refusal and explicit resume. Saving disabled; this is not actual server-grant routing or a recovered schema3/profile/replacement lifecycle. Original model unchanged, editor copy saved separately; Studio stopped and closed. Private187257/0 component executable/all inputs remain byte-identical to their earlier execution,34 current overlay candidates strict-clean; component evidence reuse is not new whole-game recovery execution.

Exact-source diagnostic-free candidate: `{candidate['place']}`;222 exact scripts, SHA256 `{candidate['place_sha256']}`. Normal persistence configuration; not a verified online player session or published release. No main merge/publication/release synchronization.

Historical source695e772 low/Normal actual-engine streaming proof is also complete:1631/0,223fingerprints,0CreatorErrors,124Heartbeats/2.047seconds missing collision under diagnostic Opportunistic policy with2second focus-report suppression; no collision parenting. Pose/clocks/energy/rest/starvation/pending drain retained, hunger active before/after and original method restored. Separate120frame low/Normal garden sample16.807ms mean/18.176ms p95/45.174ms max at1105x433 supports no paired optimization gain or phone claim. `docs/player-stream-render-readiness/normal-stream-verification.json` binds it to695e772; the historical verifier now reconstructs that immutable commit independently of current HEAD.

Next follow `docs/recovery-client-pause/ADOPTION-NEXT.md`: actual recovery adoption callbacks, trusted mode profiles, choice/world-generation fences, matching authoritative grant and safe service/client replacement epochs. The pause is local control, not authorization. Actual online/rejoin/durability, natural whole life, physical controls, audio, sustained performance and release remain open. Broad goal active. No owned full/native job remains running. Preserve original OneDrive/frozen Godot, three unrelated save-cost outputs and untracked sourcemap.

---

"""
for name in ["chet/save-continue.md","RESUME-AFTER-RESTART.md"]:
 p=ROOT/name;text=p.read_text(encoding="utf8");assert text.startswith("# Latest checkpoint - owned client recovery pause, 2026-10-23")
 text=text.split("---\n\n",1)[1];p.write_text(block+text,encoding="utf8",newline="\n")
p=H/"README.md";text=p.read_text(encoding="utf8")
old="The Windows full process28256 is live, expected76 suites/468872/0. Linux push run39965521650 is terminal success76/468872/0. Verify the Windows terminal receipt and both-source proof once with `verify-gates.py`; do not restart either. The last dual-platform full source remains695e772 until Windows completes."
assert old in text
text=text.replace(old,"The Windows full process28256 and Linux push run39965521650 are terminal successful: each76 suites/468872 checks/0 failures. `full-verification.json` binds immutable snapshot inputs and logs; `verify-gates.py` passed. Do not restart these unchanged gates. `production-candidate.json` binds the exact222-script diagnostic-free candidate; it is not published or verified as an online player session.")
p.write_text(text,encoding="utf8",newline="\n")
p=ROOT/"docs/audit/current-source/requirements.json";d=json.loads(p.read_text(encoding="utf8"));assert d["source"]==SOURCE
d.update(as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goal_complete=False,published=False)
for row in d["requirements"]:
 if row["id"]=="cli-and-runner":
  row.update(status="both-platforms-verified-bounded-native-pause-passed",evidence_boundary="Current a97b0b5: Windows28256 terminal exit0 and Linux39965521650 terminal success; each76/468872/0, compile222, clean strict, runner5. LOCAL_RETURN33 verifies actual adoption/owned hold. Native70/0,223fingerprints,0CreatorErrors includes ten actual Normal capture/adoption/pause cases. Exact immutable full proof and diagnostic-free candidate bound; not complete recovery, service/grant/profile/replacement, online saving or release proof.")
  row["references"] += ["docs/recovery-client-pause/full-verification.json","docs/recovery-client-pause/production-candidate.json"]
 if row["id"]=="performance-A08":
  row["evidence_boundary"]+=" Separate695e772 low/Normal controlled garden120frames mean16.807/p9518.176/max45.174ms at1105x433; no paired gain, phone or whole-game claim."
  row["references"] += ["docs/player-stream-render-readiness/normal-stream-verification.json"]
p.write_text(json.dumps(d,indent=2)+"\n",encoding="utf8",newline="\n")
print("Terminal exact-source checkpoint/candidate recorded; broader goal stays active")
