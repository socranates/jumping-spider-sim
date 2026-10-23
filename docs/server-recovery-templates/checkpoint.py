"""Update resume state without claiming pending full gates have completed."""
from pathlib import Path
import datetime,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
native=json.loads((H/'native-receipt.json').read_text(encoding='utf8'))
private=json.loads((H/'private-verification.json').read_text(encoding='utf8'))
ci=json.loads((H/'ci-start.json').read_text(encoding='utf8'))
assert native['studio_closed'] and private['source']==native['source']==SOURCE
block="""# Latest checkpoint - server templates native/private pass, full gates running, 2026-10-23

Production `46c299f5e36038d06f164c968e5fda78bb4407e8` is committed/pushed on codex/save-continue. It adds Server/RecoveryTemplates and the normal runner's recovery_templates suite. The server constructs pristine home records directly from authored collision and normal simulation constructors, without a client/played checkpoint. Three frozen mode records are cached; each consumer receives separate validation contexts. Their callback identities must be distinct: the generic SaveRest.stubWorld shared noop is insufficient for graph recapture. The real integration failure is fixed and covered. The single startup build rejects cancellable SaveWork execution and yielding scope predicates so a temporary engine probe cannot be abandoned.

Current static: 223 compile, full strict clean, runner5. Targeted RECOVERY_TEMPLATES56. Qualified full private: 30 groups /204767 checks /0, including513 using the actual production builder through real server entry, next-rest stored ACK and replacement in all three modes.40 private candidates strict-clean against current production. verify-private.py binds source/bundle/generated fixture/logs/types. Early precommit failures are development evidence only.

Current unbound Studio fixture passed109/0 (27 actual-server template/recapture +82 preceding actual-client scripted checks),225 exact script fingerprints,0 CreatorErrors. Source model unchanged; separate editor copy saved; Studio authoritatively closed. Logs/runs/guards are in docs/server-recovery-templates/native-receipt.json. Observed build36.7ms for three records totalling47623 canonical characters; this is one startup measurement, not a frame-rate gain or general performance guarantee. No native full recovery/menu/replacement or online DataStore proof.

Windows full exec79936 is LIVE: immutable source46c299f, expected77 suites /468936 checks /0; do not restart or run another full copy. Poll the same handle or authoritative process receipt. Linux push run39987259383 is independently live/All suites; fetch-ci.py only observes/downloads it. No duplicate dispatch. The last completed dual-platform source remains8c9b718 until both current full gates finish. No current production candidate yet.

Next finish those terminal gates, run verify-gates.py, build the diagnostic-free candidate once, seal documentation and push. Then review initial-visit constructor cancellation and implement actual game pause/menu/error callbacks; native whole recovery/replacement, payload/network budgets, real test-store rejoin and broader gameplay/input/audio/sustained-performance/release gates remain open. The engine owner hook is still closed and nothing is published. Goal remains active. Preserve OneDrive/frozen Godot, three unrelated save-cost outputs and untracked sourcemap. No Studio/other owned Luau process besides the Windows full run is live.

---

"""
for name in ['chet/save-continue.md','RESUME-AFTER-RESTART.md']:
 p=ROOT/name;s=p.read_text(encoding='utf8');assert s.startswith('# Latest checkpoint - private session replacement verified, 2026-10-23')
 p.write_text(block+s,encoding='utf8',newline='\n')
(H/'README.md').write_text(block.rstrip()+'\n',encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(p.read_text(encoding='utf8'))
d.update(source=SOURCE,as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goal_complete=False,published=False,
 latest_authored_server_templates=dict(source=SOURCE,compile=223,strict_clean=True,targeted_checks=56,private_checks=204767,private_candidates=40,
 native_total_checks=109,native_server_checks=27,native_client_checks=82,native_fingerprints=225,native_errors=0,studio_closed=True,
 windows_exec=79936,linux_run=ci['id'],full_gates='running',production_candidate_built=False,engine_recovery_installed=False,published=False))
for row in d['requirements']:
 if row['id']=='cli-and-runner':
  row['status']='current-static-native-private-pass-full-platforms-running'
  row['evidence_boundary']='Current46c299f: compile223/strict clean/runner5/targeted56; private204767/0,40 candidates; native109/0/225 fingerprints/0 errors/closed. Windows79936 and Linux39987259383 full gates live, expected77/468936/0. Preceding dual platform source8c9b718 retained; do not claim current full qualification or release.'
  row['references'] += ['docs/server-recovery-templates/checks.json','docs/server-recovery-templates/native-receipt.json','docs/server-recovery-templates/private-verification.json','docs/server-recovery-templates/windows-full-start.json','docs/server-recovery-templates/ci-start.json']
 if row['id']=='legacy-world-restore':
  row['status']='authored-production-template-native-private-pass-activation-open'
  row['evidence_boundary']+=' Current46c299f adds server-authored frozen template catalog, unique validation callback references and no played/client input;56 targeted,513 new private actual entry/rest/replacement,27 server-native template checks pass. Cached startup snapshot measured36.7ms/47623 chars once. This does not install engine recovery/menu or prove native full recovery/online rejoin.'
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
print('Native/private/static progress and live full handles recorded; goal active')
