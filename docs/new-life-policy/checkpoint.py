"""Record qualified private progress and terminal platform evidence, not release."""
from pathlib import Path
import datetime, json

H = Path(__file__).resolve().parent
ROOT = H.parents[1]
v = json.loads((H / 'verification.json').read_text(encoding='utf8'))
p = json.loads((ROOT / 'docs/recovery-application/default-platform-verification.json').read_text(encoding='utf8'))
assert v['source'] == p['source'] and v['named_groups'] == 32 and v['failed'] == 0 and v['private_candidates'] == 41
assert p['windows_checks'] == p['linux_checks'] == 468959 and p['windows_failed'] == p['linux_failed'] == 0
assert not v['application_new_policy_installed'] and not v['ordinary_startup_recovery_enabled'] and not v['published'] and not v['goal_complete']
block = f'''# Latest checkpoint - protected New qualified privately, both default platforms passed, 2026-10-23

Production remains `{v['source']}` on codex/save-continue. Its default full Windows and Linux runs are both terminal successes: **78 suites /468959 checks /0** per platform;224 production modules compile, full strict clean and runner5. Linux run39995270738 completed2026-10-23T17:41:50Z. Windows exec28872 is terminal, not a live handle to restart. docs/recovery-application/verify-default-platforms.py binds both raw receipts and exact committed production bytes.

Current private cohort: **32 named groups /{v['total_checks']} fixed checks /0**, including **{v['protected_new_checks']} protected-New checks**;41 candidates compile and the full production overlay is strict-clean. docs/new-life-policy/verify.py reconstructs the qualified bundle and verifies source, inputs, output and types, including the preserved failing cancellation reproduction and its passing counterpart. Stopping the policy now revokes an already-issued retirement callback; setting the job state alone had allowed a suspended write to commit after cancellation. The previous application31-group receipt remains historical after these private adapters changed. Every existing storage read still checks its invariant, with timing-dependent counts reported separately (192 in this run). These are memory-backed CLI checks over private adapters, including two replacements for WorldMap/Checkpoint, not native/network/online evidence.

An explicit protected New now has a private backend policy: retain its exact displayed observation, bind the selected slot, preserve/re-read the complete original A1 and any existing M1, preserve progress, CAS/readback an ordinary retirement marker, and require acknowledged old-owner closure before an actual fresh-epoch New credential and normal stored rest. All modes, current and explicitly observed retired schema3 sources, ambiguous writes, changed R/M1, missing A1, cancellation, foreign leases/account/provider/load changes, caps, late final progress and an actually suspended provider read are tested. Ordinary loaded rests/markers now remain visible beside protected slots. The actual suspended-read test exposed final progress being refused when ordinary intake was already closed; the private replacement owner now captures that final payload through its explicit guarded preparation method without reopening general intake.

**Not yet connected to the actual New menu/service flow.** The current game still labels protected New as without saving, normal startup does not call installRecovery, and Persistence.server has no ownerFactory. Native application and real-store verification remain open; no main merge or publication. The unchanged last native/default-qualified production candidate remains46c299f; current216b83c has platform receipts but no native application candidate. Studio is closed.

Next: install the private New policy through an optional trusted factory and real transport/application callbacks, add deliberate New-only discovery for persisted schema3 retirement markers, and route choices from a recovered playing world through paused verified replacement before resetting anything. Then exercise the actual application in an unbound memory-backed Studio model with real RemoteEvents and explicit fingerprinted overrides; measure payload/network/load costs; verify isolated real test-store leave/rejoin; complete lifecycle/controller/audio/accessibility/performance and release gates. See docs/new-life-policy/README.md and docs/recovery-application/NEXT.md. The overall optimization/stability goal stays active. Preserve OneDrive/frozen Godot, synced sources, the three unrelated save-cost logs and untracked sourcemap. Qualification jobs are terminal; no new full-platform run is needed for docs-only/private changes.

---

'''
for name in ['chet/save-continue.md', 'RESUME-AFTER-RESTART.md', 'docs/recovery-application/README.md']:
    path = ROOT / name
    old = path.read_text(encoding='utf8')
    assert old.startswith('# Latest checkpoint - actual recovery application qualified privately, full platforms running')
    path.write_text(block + old, encoding='utf8', newline='\n')

path = ROOT / 'docs/audit/current-source/requirements.json'
data = json.loads(path.read_text(encoding='utf8'))
data.update(source=v['source'], as_of_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), published=False, goal_complete=False)
data['latest_new_life_policy'] = v
data['latest_default_platforms'] = p
data['latest_recovery_application'].update(full_platforms='passed', windows_exec_state='terminal-success', linux_run_state='completed-success', private_evidence_state='historical-before-new-life-policy')
for row in data['requirements']:
    if row['id'] == 'cli-and-runner':
        row['status'] = 'default-platforms-pass-private-new-policy-pass-activation-open'
        row['evidence_boundary'] = f"Current216b83c default Windows/Linux78/468959/0 each;224 compile/strict clean/runner5. Current private32 groups/{v['total_checks']}/0 and41 candidates strict-clean; protected New backend verified but not application-wired. Historical31-group proof retained. No native application/online/release completion."
        row['references'] += ['docs/recovery-application/default-platform-verification.json', 'docs/new-life-policy/verification.json', 'docs/new-life-policy/README.md']
    if row['id'] == 'legacy-world-restore':
        row['status'] = 'protected-new-backend-private-pass-application-and-native-open'
        row['evidence_boundary'] += f" Protected New backend privately qualified with{v['protected_new_checks']} checks and actual all-mode fresh credentials/stored rests after old closure. Current UI installation, New-only retired discovery, recovered-playing menu routing, native application and online verification remain open."
        row['references'] += ['docs/new-life-policy/verification.json', 'docs/new-life-policy/README.md']
path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf8', newline='\n')
print('Terminal platforms and qualified private New policy recorded; goal active')
