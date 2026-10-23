"""Record the real integration proof and live platform owners without release claims."""
from pathlib import Path
import datetime,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
v=json.loads((H/'private-verification.json').read_text());win=json.loads((H/'windows-full-start.json').read_text());ci=json.loads((H/'ci-start.json').read_text())
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b'
assert v['source']==win['source']==ci['head_sha']==SOURCE and v['total_checks']==211717 and v['failed']==0
assert ci['id']==40004870155 and not (H/'windows-full-process.json').exists()
block=f'''# Latest checkpoint - actual New menus qualified, current full platforms live, 2026-10-23

Production `{SOURCE}` is committed/pushed on codex/save-continue. Optional recovery now connects the actual menus to the trusted New policy factory: the old world stays paused before any reset, the selected original A1/M1 is retained, a normal retirement marker is verified, the old owner closes through acknowledged replacement, and an explicit new-epoch choice receives a real writable credential. All three modes store a normal checkpoint from the actual new world. The menu includes New Free play spider, unsupported peers retain without-saving labels, and persisted schema3 retirement is New-only. Recovered-playing menu/direct-fresh/local-return world choices replace their owner before offering fresh choices. Ordinary checkpoints submitted during a protected-slot refresh remain credentialed and are stored after the normal worker resumes.

Current static:224 production modules compile, full strict clean, runner5;41 private candidates compile/full overlay strict-clean. Qualified `docs/new-life-application/qualified-full-1`: **34 named groups /211717 fixed checks /0**. The prior32 groups retain211595 checks; new actual-menu success82 and failure40. Lost New requests/a verified reply, exactly one retirement write, early exit, concurrent raw-rest conflict with visible held exit, old-scope replies, hidden screens and actual interrupted-retirement New are verified. `verify-private.py` reconstructs the exact committed bundle, source, inputs, output and types. Existing actual-application storage-read invariants remain separate (191 in this run). The proof is memory-backed CLI over private adapters including two explicit WorldMap/Checkpoint overrides; it is not native/network/online proof.

Windows full exec **83712** is LIVE on immutablebd67582; expected78 suites /468967 checks /0, including31 coordinator checks. Do not restart it. Poll that actual handle or its terminal process receipt. Linux push run **40004870155** is independently live; compile and strict passed, All suites was running at the last API observation. Use docs/new-life-application/fetch-ci.py to observe that same run; never dispatch a duplicate. Both current platform gates remain unclaimed until their terminal evidence is bound. Last completed dual-platform source216b83c remains78/468959/0 each. Last native/default-qualified candidate remains46c299f, unchanged. Studio is closed.

Normal engine startup still does not call installRecovery and Persistence.server still has no ownerFactory. No main merge or publication. Next finish/bind the two current full platform runs; exercise the actual application and New transport in an unbound Studio memory model with real RemoteEvents and265 script fingerprints (222 untouched production +41 candidates including2 replacements +2 diagnostic scripts). Install the client hook before publishing save remotes through a separate diagnostic-ready handshake. Then measure payload/network/loading costs, verify isolated real test-store leave/rejoin, natural lifecycle/controller/audio/accessibility/performance and release/synchronization gates. See docs/new-life-application/README.md and docs/recovery-application/NEXT.md. The full optimization/stability goal stays active. Preserve OneDrive/frozen Godot, synced sources, the three unrelated save-cost logs and untracked sourcemap. All private/static jobs are terminal; only the current full Windows suite is owned locally.

---

'''
for name in ['RESUME-AFTER-RESTART.md','chet/save-continue.md','docs/recovery-application/README.md']:
 p=ROOT/name;old=p.read_text(encoding='utf8');assert old.startswith('# Latest checkpoint - protected New qualified privately, both default platforms passed')
 p.write_text(block+old,encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(p.read_text());d.update(source=SOURCE,as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goal_complete=False,published=False)
d['latest_new_application']=dict(**v,windows_exec=83712,linux_run=40004870155,full_platforms='running')
d['latest_new_life_policy']['evidence_state']='historical-before-actual-new-application'
d['latest_default_platforms']['evidence_state']='previous-source216b83c-terminal-success'
for row in d['requirements']:
 if row['id']=='cli-and-runner':
  row['status']='actual-new-application-private-static-pass-full-platforms-running'
  row['evidence_boundary']='Currentbd67582: production224 compile/strict clean/runner5; coordinator31; private34 groups/211717 fixed checks/0 plus read invariants;41 candidates strict-clean. Windows83712 and Linux40004870155 are live, expected78/468967/0 each. Previous216b83c dual-platform pass retained. No current native application/online/release completion.'
  row['references']+=['docs/new-life-application/private-verification.json','docs/new-life-application/checks.json','docs/new-life-application/windows-full-start.json','docs/new-life-application/ci-start.json','docs/new-life-application/README.md']
 if row['id']=='legacy-world-restore':
  row['status']='actual-new-menus-and-replacement-private-pass-native-and-activation-open'
  row['evidence_boundary']+=' Currentbd67582 connects optional New menus/transport (82 success/40 failure checks) and recovered-playing choice routing, with real current-epoch credentials and normal stored rests in all modes. Background refresh preserves ordinary checkpoints. Normal engine installation, native application, online-store and release proof remain open.'
  row['references']+=['docs/new-life-application/private-verification.json','docs/new-life-application/README.md']
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n');print('Actual New menu proof and live platform owners recorded; goal active')
