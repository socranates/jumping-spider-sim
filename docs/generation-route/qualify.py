"""Bind completed family evidence to committed ordinary source and its CI."""
from pathlib import Path
import datetime, hashlib, io, json, subprocess, tarfile, urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PORT = ROOT / 'roblox_port'
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf8'))
COMMIT = '3f6ed486cf0a6fa2b20c47c1b0c857ef7ff98200'
RUN = 40102350037
m = read(HERE / 'native-final/manifest.json')
n = read(HERE / 'native-final/native.json')
assert n['passed'] and n['completed_families'] == n['guarded_restores'] == n['next_generation_restores'] == 3
assert n['complete_growth_meals'] == 62 and n['completed_moults'] == 9
assert n['next_generation_meals'] == 9 and n['free_follow_elapsed_seconds'] >= 12
assert n['source_guards'] == 2 and not n['creator_errors']
assert m['revision'] == COMMIT
changed = set(subprocess.check_output(['git', 'diff', '--name-only', '07a7df8d', COMMIT, '--', 'roblox_port/src', 'roblox_port/tests'], cwd=ROOT, text=True).splitlines())
assert changed == {'roblox_port/tests/client_mating.luau'}
assert 'CLIENT_MATING passed=29 failed=0' in (HERE / 'red.txt').read_text()
assert (PORT / 'tests/client_mating.luau').read_bytes().replace(b'\r\n', b'\n') == subprocess.check_output(['git', 'show', COMMIT + ':roblox_port/tests/client_mating.luau'], cwd=ROOT).replace(b'\r\n', b'\n')
assert sha(Path(n['original_log']).read_bytes()) == n['log_sha256']
assert sha(Path(m['place']).read_bytes()) == n['model_sha256']
assert sha((HERE / 'playback.luau').read_bytes()) == m['sources']['StarterPlayer.StarterPlayerScripts.Client.MatrixPlayback']
archive = subprocess.check_output(['git', 'archive', '--format=tar', COMMIT, 'roblox_port/src'], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as packed:
    committed = {Path(f.name).relative_to('roblox_port/src').as_posix(): packed.extractfile(f).read().replace(b'\r\n', b'\n') for f in packed if f.isfile()}
assert len(committed) == len(m['original_sources']) == 273
for rel, digest in m['original_sources'].items():
    current = (PORT / 'src' / rel).read_bytes().replace(b'\r\n', b'\n')
    assert sha(current) == digest and current == committed[rel], rel
exports = read(PORT / 'build-receipt.json')
assert exports['evidence_id'] == '5e9ac432e9933ed9' and exports['source_count'] == 273
assert read(ROOT / 'docs/life-route/native-final/manifest.json')['original_sources'] == m['original_sources']
for out in exports['outputs']:
    assert sha((PORT / out['file']).read_bytes()) == out['sha256']
def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Windowsill-audit'}), timeout=30) as r:
        return json.load(r)
url = f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{RUN}'
run, jobs = get(url), get(url + '/jobs')
assert run['head_sha'] == COMMIT and run['status'] == 'completed' and run['conclusion'] == 'success'
assert len(jobs['jobs']) == 1 and all(s['conclusion'] == 'success' for s in jobs['jobs'][0]['steps'])
assert {'Every module compiles', 'Strict types', 'All suites', 'Normal and self-test exports', 'Runner failure and cleanup regressions'}.issubset({s['name'] for s in jobs['jobs'][0]['steps']})
ci = dict(checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(), run=run, job=jobs['jobs'][0], default_suites=80)
(HERE / 'github-ci.json').write_bytes((json.dumps(ci, indent=2) + '\n').encode())
qualification = dict(source_commit=COMMIT, evidence_id=exports['evidence_id'], ordinary_sources=273,
    no_new_game_source_changes=True, native_run=n['run'], complete_growth_meals=62, completed_moults=9,
    completed_families=3, guarded_restores=3, next_generation_restores=3, native_guards=2,
    next_generation_meals=9, adult_refuel_meals=n['adult_refuel_meals'], total_meals=n['total_meals'],
    free_follow_elapsed_seconds=n['free_follow_elapsed_seconds'],
    native_errors=0, native_warnings=len(n['creator_warnings']), native_model_sha256=n['model_sha256'],
    native_log_sha256=n['log_sha256'], full_ci_run=RUN, full_ci_suites=80, full_ci_conclusion='success',
    published=False, private_published_version_unchanged=14, production_changed=False, limits=n['limits'])
(HERE / 'qualification.json').write_bytes((json.dumps(qualification, indent=2) + '\n').encode())
print(json.dumps(qualification))
