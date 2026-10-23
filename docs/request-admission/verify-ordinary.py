"""Reconstruct private ordinary admission proofs without changing production."""
from pathlib import Path
import hashlib, importlib.util, io, json, re, subprocess, tarfile, zipfile

H = Path(__file__).resolve().parent
ROOT = H.parents[1]
SOURCE = 'bd67582b5d53473f067244fc1e2e1f94adde173b'
sha = lambda b: hashlib.sha256(b).hexdigest()

def load(name, file):
    spec = importlib.util.spec_from_file_location(name, H / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def bind(prefix, bundle, paths):
    receipt = json.loads((H / (prefix + '-receipt.json')).read_text(encoding='utf8'))
    raw = (H / (prefix + '-output.txt')).read_bytes()
    assert receipt['inputs'] == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in paths}
    assert receipt['bundle_sha256'] == sha(bundle.encode())
    assert receipt['output_sha256'] == sha(raw)
    return receipt, raw.decode('utf8')

def main():
    runner = load('ordinary_verify_runner', 'run-ordinary.py')
    bundle, paths = runner.build()
    receipt, output = bind('ordinary-qualified-2', bundle, paths)
    assert receipt['source'] == SOURCE and receipt['exit_code'] == 0 and not receipt['focused']
    summary = r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
    prior = (H / 'held-qualified-1-output.txt').read_text(encoding='utf8')
    expected = {name: (int(p), int(f)) for name, p, f in re.findall(summary, prior, re.M)}
    assert len(expected) == 49 and sum(p for p, f in expected.values()) == 282370
    assert all(f == 0 for p, f in expected.values())
    focused = (H / 'ordinary-development-5-output.txt').read_text(encoding='utf8')
    cases = re.findall(r'^ORDINARY_CASE\s([^\t\n]+)\s(\d+)$', output, re.M)
    focused_cases = re.findall(r'^ORDINARY_CASE\s([^\t\n]+)\s(\d+)$', focused, re.M)
    assert cases == focused_cases and len(cases) == 16
    assert sum(int(n) for _, n in cases) == 583
    assert cases[-1] == ('coarse-clock-wait-can-span-several-timer-quanta', '11')
    runtime = re.findall(r'^ORDINARY_RUNTIME_CASE\s([^\t\n]+)\s(\d+)$', output, re.M)
    assert runtime == [('main', '374'), ('free', '374'), ('easy', '374')]
    expected.update(ORDINARY_SESSION=(583, 0), ORDINARY_RUNTIME=(1122, 0))
    rows = re.findall(summary, output, re.M)
    assert len(rows) == 51 and {name: (int(p), int(f)) for name, p, f in rows} == expected
    assert sum(p for p, f in expected.values()) == 284075
    # Named-case groups are distinct from top-level summary rows and checks.
    group_rows = re.findall(r'^[A-Z_0-9]+ passed=\d+ failed=0 groups=(\d+)$', output, re.M)
    # The34 original suites each count as one group; later suites report
    # their finer named groups explicitly rather than adding another wrapper.
    assert len(rows) - len(group_rows) == 34
    assert sum(map(int, group_rows)) + len(rows) - len(group_rows) == 138
    assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:', output)
    assert receipt['ordinary_Session_typed']
    assert not any(receipt[k] for k in ['service_lanes_installed', 'normal_startup_installed', 'native_verified', 'online_verified', 'published'])

    checker = load('ordinary_verify_types', 'check-ordinary.py').checker()
    sources = checker.paths()
    types = json.loads((H / 'ordinary-types-qualified-2-types.json').read_text(encoding='utf8'))
    assert len(sources) == 48 and len(types['candidates']) == 47
    assert types['candidates'] == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in sources.values()}
    mounted = {}
    for target, path in sources.items():
        # Match the checker's existing Windows text-read contract exactly.
        code = path.read_text()
        if path in [H / 'worker-v3.luau', H / 'operation.luau']:
            code = code.replace('require("./worker-facade")', 'require(script.Parent.RequestAdmissionFacade)')
        mounted[target] = sha(code.encode())
    assert types['mounted'] == mounted and len(types['steps']) == 3
    for step in types['steps']:
        assert step['exit_code'] == 0
        assert sha((H / ('ordinary-types-qualified-2-' + step['name'] + '.txt')).read_bytes()) == step['sha256']
    assert (H / 'ordinary-types-qualified-2-compile.txt').read_text(encoding='utf8') == 'compile 48/48\n'
    strict = (H / 'ordinary-types-qualified-2-strict.txt').read_text(encoding='utf8')
    assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
    for name, digest in types['production_inputs'].items():
        assert sha((ROOT / name).read_bytes()) == digest

    old = load('ordinary_verify_old_boundary', 'probe-session-boundaries.py')
    fixed = load('ordinary_verify_new_boundary', 'run-ordinary-boundaries.py')
    for case in ['late-lock', 'read-account']:
        b, p = old.build(case)
        before, text = bind('session-boundaries-before-fix-1-' + case, b, p)
        assert before['exit_code'] != 0 and not before['issue_fixed']
        assert before['expected_failure'] in text and 'fixed=true' not in text
        b, p = fixed.build(case)
        after, text = bind('ordinary-boundaries-qualified-2-' + case, b, p)
        assert after['exit_code'] == 0 and after['issue_fixed'] and 'fixed=true' in text
    state = load('ordinary_verify_state', 'run-ordinary-state.py')
    for test, name, count in [('state.luau', 'STATE', 1488), ('state_client.luau', 'STATE_CLIENT', 161)]:
        case = Path(test).stem.replace('_', '-')
        b, p = state.build(test)
        result, text = bind('ordinary-state-qualified-2-' + case, b, p)
        assert result['exit_code'] == 0 and f'{name} passed={count} failed=0' in text
        assert not result['admission_installed_in_service']
    negative = load('ordinary_verify_coarse_negative', 'run-ordinary-negative.py')
    b, p = negative.build()
    result, text = bind('ordinary-coarse-before-fix-1', b, p)
    assert result['exit_code'] != 0 and result['expected_failure'] in text
    # The first full run was stopped for the coarse-clock defect, not passed.
    interrupted = json.loads((H / 'ordinary-qualified-1-receipt.json').read_text(encoding='utf8'))
    note = json.loads((H / 'ordinary-qualified-1-interrupted.json').read_text(encoding='utf8'))
    assert interrupted['exit_code'] != 0 and not note['qualification_complete']
    assert interrupted['output_sha256'] == sha((H / 'ordinary-qualified-1-output.txt').read_bytes())
    with zipfile.ZipFile(H / 'ordinary-qualified-1-interrupted-bundle.zip') as archive:
        assert len(archive.namelist()) == 1
        assert sha(archive.read(archive.namelist()[0])) == interrupted['bundle_sha256']

    ordinary = (H / 'ordinary-session.luau').read_text(encoding='utf8')
    assert 'self.backend:update(' not in ordinary
    archive = subprocess.check_output(['git', 'archive', '--format=tar', SOURCE, 'roblox_port/src', 'roblox_port/tests', 'roblox_port/default.project.json'], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        production = {m.name: sha(source.extractfile(m).read()) for m in source if m.isfile()}
    assert all(sha((ROOT / name).read_bytes()) == digest for name, digest in production.items())
    private = [H / x for x in ['ordinary-session.luau', 'ordinary-io.luau', 'runtime-ordinary.luau', 'ordinary-tests.luau',
        'ordinary-runtime-tests.luau', 'run-ordinary.py', 'check-ordinary.py', 'run-ordinary-state.py', 'run-ordinary-boundaries.py',
        'run-ordinary-negative.py', 'ordinary-before-coarse-io.luau', 'verify-ordinary.py', 'ORDINARY-WORKERS.md']]
    committed = all(subprocess.run(['git', 'cat-file', '-e', 'HEAD:' + p.relative_to(ROOT).as_posix()], cwd=ROOT, capture_output=True).returncode == 0
        and subprocess.check_output(['git', 'show', 'HEAD:' + p.relative_to(ROOT).as_posix()], cwd=ROOT) == p.read_bytes() for p in private)
    commit = subprocess.check_output(['git', 'log', '-1', '--format=%H', '--', *[p.relative_to(ROOT).as_posix() for p in private]], cwd=ROOT, text=True).strip() if committed else None
    result = dict(source=SOURCE, private_inputs_committed=committed, private_commit=commit,
        preceding_checks=282370, ordinary_Session_checks=583, ordinary_Runtime_checks=1122,
        full_checks=284075, full_named_groups=138, full_failed=0, overlay_targets=48, distinct_private_sources=47,
        strict_clean=True, separate_STATE_checks=1488, separate_STATE_CLIENT_checks=161,
        ordinary_Session_typed=True, Runtime_lane_from_constructor_verified=True,
        initial_lock_freshness_fixed_private=True, inflight_read_accounting_fixed_private=True,
        coarse_clock_before_fix_failure_reproduced=True, interrupted_run_not_qualification=True,
        provider='memory', clock='synthetic', all_workers_typed=False, service_lanes_installed=False,
        profile_replacement_lifetimes_qualified=False, cooperative_service_driver_installed=False,
        normal_startup_installed=False, native_verified=False, online_verified=False,
        loading_speedup_proved=False, published=False, goal_complete=False)
    (H / 'ordinary-verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8', newline='\n')
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
