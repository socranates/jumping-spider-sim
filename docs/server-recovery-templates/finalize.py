"""Record a completed, bounded milestone only after all current gates pass."""
from pathlib import Path
import datetime,hashlib,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
v=json.loads((H/'full-verification.json').read_text(encoding='utf8'))
p=json.loads((H/'production-candidate.json').read_text(encoding='utf8'))
assert v['source']==p['source']==SOURCE and v['private_checks']==204788
assert v['windows_passed']==v['linux_passed']==468936 and not v['published'] and not p['published']
assert p['scripts']==223 and p['all_production_sources_exact'] and not p['injected_diagnostics']
assert hashlib.sha256(Path(p['place']).read_bytes()).hexdigest()==p['place_sha256']
block='''# Latest checkpoint - server templates and initial-constructor cancellation qualified, 2026-10-23

Production `46c299f5e36038d06f164c968e5fda78bb4407e8` is committed/pushed on codex/save-continue. Both exact-source full platforms passed **77 suites /468936 checks /0 failures**: Windows exec79936 terminal exit0 and Linux push run39987259383 terminal success. 223 production modules compile, full strict analysis is clean, and 5 runner regressions pass. The production RecoveryTemplates utility builds three frozen pristine mode records from authored HOME geometry and normal constructors, with distinct validation callback references and independent consumer contexts. It is not installed in normal persistence/menu behavior.

Current full private cohort: **30 groups /204788 checks /0** (`qualified-full-2`), including 2688 session-replacement and 513 actual production-catalog entry/next-rest stored ACK/replacement checks. 40 private candidates compile/full strict-clean (`initial-scope-types-1`). The added initial-constructor lifetime fence covers disconnect, shutdown, same-player rejoin and constructor failure. A late unloaded owner is closed without storage I/O; it cannot acquire a lease or replace a fresh visit. The before-fix failing reproduction and exact input snapshots are retained. `verify-private.py` reconstructs and binds current bundle, generated fixture, committed production, inputs, output and types. `qualified-full-1` is earlier historical proof, not current adapter proof.

Unbound native Studio fixture: **109/0**, comprising 27 actual-server authored-template/recapture checks and 82 preceding actual-client scripted checks; 225 exact fingerprints, 0 CreatorErrors. Studio was stopped, separately saved and closed; original model is unchanged. Template construction was measured once at 36.7 ms for 47623 canonical characters across three records. This is not a sustained performance or frame-rate improvement claim. Native full recovery/menu/replacement, physical controls and online DataStore were not verified by this fixture.

Diagnostic-free, exact-source production candidate: `C:\\Users\\natha\\claude-xfer\\Windowsill-production-46c299f\\TheWindowsill-production-candidate.rbxlx`. 223 exact production scripts, normal persistence enabled, no injected diagnostics. It is built but not published or claimed as a native-tested complete release. `docs/server-recovery-templates/full-verification.json` and `production-candidate.json` bind the completed gates and artifact. Do not repeat unchanged terminal gates.

Next implement actual game recovery/pause/menu/error/exit callbacks through the private adapters, with advance notice before menu/settings/feeding/fly edits. Before activation prove payload/network budgets and native whole recovery/replacement, then isolated real test-store save/rejoin and broader natural-life/input/audio/sustained-performance/release checks. No main merge or publish. The broad optimization/stability goal remains active. Preserve OneDrive/frozen Godot, three unrelated save-cost outputs and untracked sourcemap. All test jobs for this milestone are terminal; Studio is closed.

---

'''
for name in ['chet/save-continue.md','RESUME-AFTER-RESTART.md']:
 path=ROOT/name;text=path.read_text(encoding='utf8')
 assert text.startswith('# Latest checkpoint - server templates native/private pass, full gates running, 2026-10-23')
 _,tail=text.split('\n---\n\n',1)
 path.write_text(block+tail,encoding='utf8',newline='\n')
(H/'README.md').write_text(block.rstrip()+'\n',encoding='utf8',newline='\n')
path=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(path.read_text(encoding='utf8'))
d.update(source=SOURCE,as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goal_complete=False,published=False)
d['latest_authored_server_templates'].update(private_checks=204788,full_gates='passed',windows_suites=77,windows_passed=468936,windows_failed=0,
 linux_suites=77,linux_passed=468936,linux_failed=0,linux_run=v['linux_run'],production_candidate_built=True,production_candidate=p['place'],
 initial_constructor_lifetime_fenced=True,private_full_receipt='docs/server-recovery-templates/qualified-full-2-receipt.json',
 full_verification='docs/server-recovery-templates/full-verification.json',engine_recovery_installed=False,published=False)
for row in d['requirements']:
 if row['id']=='cli-and-runner':
  row['status']='current-static-native-private-and-full-platforms-pass-activation-open'
  row['evidence_boundary']='Current46c299f: both Windows/Linux77 suites/468936 checks/0; compile223/strict clean/runner5/targeted56; private204788/0,40 candidates; native109/0/225 fingerprints/0 errors/closed. Exact diagnostic-free production candidate built; native full recovery, online saves, whole-game/performance and release remain open.'
  row['references']+=['docs/server-recovery-templates/full-verification.json','docs/server-recovery-templates/production-candidate.json','docs/server-recovery-templates/ci-final.json']
 if row['id']=='legacy-world-restore':
  row['evidence_boundary']+=' Current full private204788/0 includes the initial constructor cancellation/rejoin fix. No ordinary engine installation or online recovery claim.'
path.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
print('Completed milestone sealed; broader goal remains active; no publication')
