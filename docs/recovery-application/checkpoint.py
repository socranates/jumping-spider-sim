"""Save bounded current progress while the exact-source full gates are live."""
from pathlib import Path
import datetime,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='216b83c7f2b5136230d8bda58653717433eccc51'
v=json.loads((H/'private-verification.json').read_text(encoding='utf8'));static=json.loads((H/'checks.json').read_text(encoding='utf8'))
assert v['source']==static['source']==SOURCE and v['total_checks']==204900 and static['compile_passed']==224
block='''# Latest checkpoint - actual recovery application qualified privately, full platforms running, 2026-10-23

Production `216b83c7f2b5136230d8bda58653717433eccc51` is committed/pushed on codex/save-continue. RecoveryApplication and real SpiderClient callbacks now own recovery progress/error screens, exact holds, explicit replacement exit, fresh-menu holds and release after a current-session world choice. Stale completion callbacks, hidden menus, reset/local-return shortcuts and GUI failures cannot resume an obsolete world. Ordinary startup still does not install the adapter, and Persistence.server still has no ownerFactory. Existing default controls/camera/saves are retained.

The actual-menu test exposed a real preaccept exit refusal. Private replacement now stops intake, drains read work, takes an enforcing departure baseline and verifies closure before opening a new epoch. A preparing transport state prevents retries/forged ACKs from advertising closure early. The pending owner does not restart work while draining. New intents may carry the displayed offer ID; unsupported protected New choices now receive an honest read-only decision instead of remaining indefinitely at Saving. Protected New is explicitly labelled without saving. Completing its retirement-to-writable policy is still required before activation.

Current static: 224 production modules compile, full strict clean, runner 5; 40-candidate private overlay strict-clean (`application-types-1`). Qualified private full `qualified-full-2`: **31 named groups /204900 fixed checks /0**, including 2735 replacement and 65 actual application/game checks. Every storage read also asserts its invariant; timing-dependent read counts are reported separately (191 in the full run, 194 focused), rather than changing the fixed assertion total. `verify-private.py` reconstructs and binds exact committed production, current adapters, bundle, log and types. All three real menus and real pause/ready/adoption/error callbacks are exercised with memory-backed transport and a synthetic clock. Earlier development failures and the original preaccept refusal remain preserved. These are CLI/overlay results; the overlay includes private WorldMap and Checkpoint replacements, not a wholly production-only native run.

Windows full exec 28872 is LIVE on immutable source 216b83c; expected **78 suites /468959 checks /0**. Do not restart it. Poll its actual handle or terminal process receipt. Linux push run 39995270738 is independently live; compile/strict have passed and All suites was running at the latest observation. Observe it with fetch-ci.py; never dispatch a duplicate. The last dual-platform/native-qualified production source remains46c299f with its existing unmodified candidate. Current 216b83c has no native application proof or production candidate yet. Studio is closed.

Next finish and bind the two current platform runs, then complete protected New retirement and later menu-choice routing from a recovered playing world. Build/run the actual native application overlay with real RemoteEvents and memory storage, preserving the two candidate overrides explicitly; then payload/network costs, isolated real test-store leave/rejoin, natural-life/controller/audio/accessibility/sustained-performance and release gates. Details are in docs/recovery-application/NEXT.md. No main merge or publication. The full optimization/stability goal stays active. Preserve OneDrive/frozen Godot, three unrelated save-cost outputs and untracked sourcemap. Private/static jobs are terminal; only the Windows full CLI is still owned locally.

---

'''
for name in ['chet/save-continue.md','RESUME-AFTER-RESTART.md']:
 p=ROOT/name;s=p.read_text(encoding='utf8');assert s.startswith('# Latest checkpoint - server templates and initial-constructor cancellation qualified')
 p.write_text(block+s,encoding='utf8',newline='\n')
(H/'README.md').write_text(block.rstrip()+'\n',encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(p.read_text(encoding='utf8'))
d.update(source=SOURCE,as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goal_complete=False,published=False)
d['latest_recovery_application']=dict(source=SOURCE,compile=224,strict_clean=True,runner=5,private_checks=204900,private_groups=31,
 application_game_checks=65,session_replacement_checks=2735,private_candidates=40,all_storage_reads_check_invariants=True,
 timing_dependent_read_checks_separate=True,ordinary_startup_recovery_enabled=False,protected_new_life_retirement_policy_installed=False,
 native_application_recovery_verified=False,real_datastore_verified=False,windows_exec=28872,linux_run=39995270738,full_platforms='running',published=False)
for row in d['requirements']:
 if row['id']=='cli-and-runner':
  row['status']='application-static-private-pass-current-full-platforms-running'
  row['evidence_boundary']='Current 216b83c: compile 224/strict clean/runner 5; coordinator 23; private 31 groups/204900 fixed checks/0 plus all read invariants; 40 private candidates strict-clean. Windows28872 and Linux39995270738 are live, expected 78/468959/0. Last fully qualified production/native source 46c299f is retained. Native application, online saves, protected New policy and whole-game/release gates remain open.'
  row['references']+=['docs/recovery-application/checks.json','docs/recovery-application/private-verification.json','docs/recovery-application/windows-full-start.json','docs/recovery-application/ci-start.json','docs/recovery-application/NEXT.md']
 if row['id']=='legacy-world-restore':
  row['status']='actual-application-callbacks-private-pass-activation-and-retirement-open'
  row['evidence_boundary']+=' Current 216b83c adds actual application/menu/error/ready callbacks;65 fixed real-game checks and 2735 replacement checks, preaccept drain and partial-adoption exit pass. Ordinary startup remains gated, with protected New explicitly session-only pending retirement wiring. Native application and real store evidence are still missing.'
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
print('Current callback proof and live platform handles recorded; goal active')
