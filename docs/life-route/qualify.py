"""Bind the final-bite regression, current exports, native route and exact CI."""
from pathlib import Path
import argparse, ast, datetime, hashlib, io, json, re, subprocess, tarfile, urllib.request

p = argparse.ArgumentParser()
p.add_argument('--require-ci', action='store_true')
a = p.parse_args()
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PORT = ROOT / 'roblox_port'
COMMIT = 'fa7367fb893a53a66fae71970e5d3116ec8e9d6b'
RUN = 40099833793
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda f: json.loads(f.read_text(encoding='utf8'))

changed = set(subprocess.check_output(
    ['git', 'diff', '--name-only', '727563e2', COMMIT, '--', 'roblox_port/src', 'roblox_port/tests'],
    cwd=ROOT, text=True).splitlines())
assert changed == {'roblox_port/src/Client/SpiderClient.client.luau', 'roblox_port/tests/feeding_survival.luau'}
red = (HERE / 'final-bite-red-corrected-fixture.txt').read_text()
assert 'MEALS passed=91 failed=1' in red
assert 'FAIL MEALS Eat finishing in the Crack does not also Rest or moult' in red
green = (HERE / 'final-bite-green.txt').read_text()
counts = {name: (int(ok), int(bad)) for name, ok, bad in re.findall(
    r'(MEALS|LOCAL_REST|LOCAL_REST_CLIENT|GROWTH) passed=(\d+) failed=(\d+)', green)}
assert counts == dict(MEALS=(92, 0), LOCAL_REST=(33, 0), LOCAL_REST_CLIENT=(17, 0), GROWTH=(571, 0))
assert 'FAIL ' not in green

manifest = read(HERE / 'native-final/manifest.json')
native = read(HERE / 'native-final/native.json')
assert manifest['revision'] == COMMIT and native['passed']
assert native['complete_meals'] == 62 and native['completed_moults'] == 9 and native['adult_modes'] == 3
assert native['source_guards'] == 2 and not native['creator_errors']
assert sha(Path(native['original_log']).read_bytes()) == native['log_sha256']
assert sha(Path(manifest['place']).read_bytes()) == native['model_sha256']
assert sha((HERE / 'playback.luau').read_bytes()) == manifest['sources']['StarterPlayer.StarterPlayerScripts.Client.MatrixPlayback']
failed = read(HERE / 'failed-native1/result.json')
old = read(HERE / 'failed-native1/manifest.json')
second = read(HERE / 'failed-native2/manifest.json')
second_result = read(HERE / 'failed-native2/result.json')
assert not failed['passed'] and not second_result['passed']
assert second['revision'] == COMMIT
assert old['sources']['StarterPlayer.StarterPlayerScripts.Client.MatrixPlayback'] == second['sources']['StarterPlayer.StarterPlayerScripts.Client.MatrixPlayback']
assert {k for k, v in old['original_sources'].items() if v != second['original_sources'][k]} == {'Client/SpiderClient.client.luau'}
assert second['original_sources'] == manifest['original_sources']
assert second_result['complete_meals'] == 7 and second_result['completed_moults'] == 1 and second_result['hardened']
assert sha((HERE / 'failed-native2/playback.luau').read_bytes()) == second['sources']['StarterPlayer.StarterPlayerScripts.Client.MatrixPlayback']
archive = subprocess.check_output(['git', 'archive', '--format=tar', COMMIT, 'roblox_port/src'], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as packed:
    committed = {Path(f.name).relative_to('roblox_port/src').as_posix(): packed.extractfile(f).read().replace(b'\r\n', b'\n') for f in packed if f.isfile()}
assert len(manifest['original_sources']) == len(committed) == 273
for rel, digest in manifest['original_sources'].items():
    current = (PORT / 'src' / rel).read_bytes().replace(b'\r\n', b'\n')
    assert sha(current) == digest and current == committed[rel], rel

exports = read(PORT / 'build-receipt.json')
assert exports['evidence_id'] == '5e9ac432e9933ed9' and exports['source_count'] == 273
for output in exports['outputs']:
    assert sha((PORT / output['file']).read_bytes()) == output['sha256']
prefix = {'First': 'ReplicatedFirst', 'Shared': 'ReplicatedStorage.Shared', 'Server': 'ServerScriptService.Server', 'Client': 'StarterPlayer.StarterPlayerScripts.Client'}
for rel, digest in manifest['original_sources'].items():
    parts = Path(rel).parts
    key = '.'.join([prefix[parts[0]], *parts[1:-1], parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
    assert exports['sources'][key] == digest
runner = ast.parse((PORT / 'tests/run.py').read_text())
defaults = [n.iter.values[1] for n in ast.walk(runner) if isinstance(n, ast.For) and isinstance(n.target, ast.Name) and n.target.id == 'test_file' and isinstance(n.iter, ast.BoolOp)]
assert len(defaults) == 1 and isinstance(defaults[0], ast.List) and len(defaults[0].elts) == 80

def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Windowsill-audit'}), timeout=30) as response:
        return json.load(response)

url = f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{RUN}'
run, jobs = get(url), get(url + '/jobs')
assert run['head_sha'] == COMMIT and len(jobs['jobs']) == 1
complete = run['status'] == 'completed' and run['conclusion'] == 'success'
if complete:
    steps = jobs['jobs'][0]['steps']
    assert all(s['conclusion'] == 'success' for s in steps)
    assert {'Every module compiles', 'Strict types', 'All suites', 'Normal and self-test exports', 'Runner failure and cleanup regressions'}.issubset({s['name'] for s in steps})
ci = dict(checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(), run=run, job=jobs['jobs'][0], all_suites_completed=complete, default_suites=80)
(HERE / 'github-ci.json').write_bytes((json.dumps(ci, indent=2) + '\n').encode())
qualification = dict(source_commit=COMMIT, evidence_id=exports['evidence_id'], ordinary_sources=273,
    game_module_changes=['Client/SpiderClient.client.luau'], targeted_suites=counts, targeted_passes=713,
    targeted_failures=0, native_run=native['run'], native_meals=62, native_moults=9, native_adult_modes=3,
    unchanged_final_bite_native_driver=True, full_route_fixture_clock_corrected=True,
    native_guards=2, native_errors=0, native_warnings=len(native['creator_warnings']),
    native_model_sha256=native['model_sha256'], native_log_sha256=native['log_sha256'],
    export_hashes={x['file']: x['sha256'] for x in exports['outputs']}, full_ci_run=RUN,
    full_ci_status=run['status'], full_ci_conclusion=run['conclusion'], full_ci_suites=80 if complete else None,
    published=False, private_published_version_unchanged=14, production_changed=False, limits=native['limits'])
(HERE / 'qualification.json').write_bytes((json.dumps(qualification, indent=2) + '\n').encode())
print(json.dumps(qualification))
assert not a.require_ci or complete, 'CI is not complete; inspect the same live run'
