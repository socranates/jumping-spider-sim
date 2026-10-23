"""Reconstruct the private New policy proof, without implying activation/release."""
from pathlib import Path
import hashlib, importlib.util, io, json, re, subprocess, tarfile

H = Path(__file__).resolve().parent
ROOT = H.parents[1]
SOURCE = '216b83c7f2b5136230d8bda58653717433eccc51'
sha = lambda b: hashlib.sha256(b).hexdigest()
spec = importlib.util.spec_from_file_location('qualified_new_policy', H / 'run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
bundle, inputs = runner.build()
receipt = json.loads((H / 'qualified-full-2-receipt.json').read_text(encoding='utf8'))
output = (H / 'qualified-full-2-output.txt').read_bytes()
assert receipt['source'] == SOURCE and receipt['exit_code'] == 0 and not receipt['focused']
assert not receipt['cancel_only'] and not receipt['baseline_cancel']
assert receipt['bundle_sha256'] == sha(bundle.encode()) and receipt['output_sha256'] == sha(output)
assert receipt['inputs'] == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in inputs}
for name, digest in receipt['production_inputs'].items():
    assert sha((ROOT / name).read_bytes()) == digest, name
raw = subprocess.check_output(['git', 'archive', '--format=tar', SOURCE, 'roblox_port/src', 'roblox_port/tests'], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
    committed = {m.name: sha(archive.extractfile(m).read()) for m in archive if m.isfile()}
assert receipt['production_inputs'] == committed

pattern = r'^(RECOVERY_\w+|SESSION_REPLACEMENT|SERVER_TEMPLATE_RECOVERY|PROTECTED_NEW) passed=(\d+) failed=(\d+)'
prior = (ROOT / 'docs/recovery-application/qualified-full-2-output.txt').read_text(encoding='utf8')
old = re.findall(pattern, prior, re.M)
assert len(old) == 31 and sum(int(p) for _, p, _ in old) == 204900
expected = {name: (int(p), int(f)) for name, p, f in old}
# This fixed count is set only from the terminal qualified run, after examining
# any changes to the previously qualified named groups.
EXPECTED_NEW = 6695
assert EXPECTED_NEW > 0, 'Set the reviewed terminal new-policy assertion count'
expected['PROTECTED_NEW'] = (EXPECTED_NEW, 0)
rows = re.findall(pattern, output.decode(), re.M)
actual = {name: (int(p), int(f)) for name, p, f in rows}
assert len(rows) == len(actual) == 32 and actual == expected, (actual, expected)
assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:', output.decode())
for mode in ['main', 'free', 'easy']:
    assert f'PROTECTED_NEW mode={mode} original_archived=true marker_verified=true old_closed=true real_new_credential=true normal_rest_stored=true' in output.decode()
assert re.search(r'^RECOVERY_APPLICATION_GAME read_invariants=[1-9]\d* every_read_checked=true$', output.decode(), re.M)

types = json.loads((H / 'qualified-types-2-types.json').read_text(encoding='utf8'))
assert types['source'] == SOURCE and len(types['candidates']) == 41 and len(types['steps']) == 3
for name, digest in {**types['candidates'], **types['production_inputs']}.items():
    assert sha((ROOT / name).read_bytes()) == digest, name
assert types['candidates'] == {name: digest for name, digest in receipt['inputs'].items() if name in types['candidates']}
assert len([name for name in types['production_inputs'] if name.endswith('.luau')]) == 224
for step in types['steps']:
    assert step['exit_code'] == 0 and sha((H / ('qualified-types-2-' + step['name'] + '.txt')).read_bytes()) == step['output_sha256']
assert (H / 'qualified-types-2-compile.txt').read_text(encoding='utf8') == 'compile 41/41\n'
strict = (H / 'qualified-types-2-strict.txt').read_text(encoding='utf8')
assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
assert 'ownerFactory' not in (ROOT / 'roblox_port/src/Server/Persistence.server.luau').read_text(encoding='utf8')
client_source = (ROOT / 'roblox_port/src/Client/SpiderClient.client.luau').read_text(encoding='utf8')
assert client_source.count('saveState.installRecovery(') == 1 and 'function saveState.installRecovery(' in client_source

# The added regression fails against the preserved previous policy and passes
# against current bytes. Bind both reproductions; do not edit historical logs.
for prefix, baseline, code in [('cancel-negative-1', True, 1), ('cancel-positive-1', False, 0)]:
    proof = json.loads((H / (prefix + '-receipt.json')).read_text(encoding='utf8'))
    proof_output = (H / (prefix + '-output.txt')).read_bytes()
    proof_bundle, proof_inputs = runner.build(True, True, baseline)
    assert proof['source'] == SOURCE and proof['focused'] and proof['cancel_only'] and proof['baseline_cancel'] == baseline
    assert proof['exit_code'] == code and proof['bundle_sha256'] == sha(proof_bundle.encode()) and proof['output_sha256'] == sha(proof_output)
    assert proof['inputs'] == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in proof_inputs}
    assert proof['production_inputs'] == committed
    if baseline:
        assert b'cancelled in-flight retirement still changed the selected rest' in proof_output
    else:
        assert re.search(rb'^PROTECTED_NEW passed=[1-9]\d* failed=0$', proof_output, re.M)
fixed = (H / 'new-life-policy-prototype.luau').read_text(encoding='utf8')
before = (H / 'before-cancel-fence-new-life-policy.luau').read_text(encoding='utf8')
assert fixed.replace(' Fence.cancel(j.ticket) -- revoke an already-issued retirement callback too\n', '', 1) == before

result = dict(source=SOURCE, named_groups=32, total_checks=sum(int(p) for _, p, _ in rows), failed=0,
    protected_new_checks=EXPECTED_NEW, private_candidates=41, compile_and_full_strict_clean=True,
    exact_committed_production=True, all_three_modes_actual_new_credential_and_normal_stored_rest=True,
    legacy_and_current_and_retired_sources=True, complete_original_retained=True,
    cancellation_and_real_provider_suspension=True, final_replacement_progress_preserved=True,
    suspended_retirement_cancel_regression_reproduced_before_and_after=True,
    ordinary_rests_visible_beside_protected_slots=True, explicit_new_observation_retained=True,
    all_storage_reads_check_invariants=True, timing_dependent_read_invariants_separate=True,
    application_new_policy_installed=False, ordinary_startup_recovery_enabled=False,
    native_application_recovery_verified=False, real_datastore_verified=False, published=False, goal_complete=False)
(H / 'verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8', newline='\n')
print(json.dumps(result, indent=2))
