"""Bind source, red/green regressions, native evidence, exports and actual CI."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,urllib.request,datetime,tarfile,io,ast
p=argparse.ArgumentParser();p.add_argument('--require-ci',action='store_true');a=p.parse_args()
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda f:json.loads(f.read_text(encoding='utf8'))
commit='642af9690df63b9b8d5c9dcbd1a6bef7e4310cda';runid=40098023022
runner=ast.parse((PORT/'tests/run.py').read_text())
defaults=[n.iter.values[1]for n in ast.walk(runner)if isinstance(n,ast.For)and isinstance(n.target,ast.Name)and n.target.id=='test_file'and isinstance(n.iter,ast.BoolOp)]
assert len(defaults)==1 and isinstance(defaults[0],ast.List)and len(defaults[0].elts)==80
changed=set(subprocess.check_output(['git','diff','--name-only','e93d413d',commit,'--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).splitlines())
assert changed=={'roblox_port/src/Shared/Life/LifeSession.luau','roblox_port/tests/continuing.luau','roblox_port/tests/nature_client.luau'}
manifest=read(H/'native-final/manifest.json');native=read(H/'native-final/native.json')
assert native['passed']and native['source_guards']==2 and not native['creator_errors']
assert sha(Path(native['original_log']).read_bytes())==native['log_sha256']
assert sha(Path(manifest['place']).read_bytes())==native['model_sha256']
assert manifest['revision']==commit and len(manifest['original_sources'])==273
archive=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive))as packed:
 committed={Path(f.name).relative_to('roblox_port/src').as_posix():packed.extractfile(f).read().replace(b'\r\n',b'\n')for f in packed if f.isfile()}
for rel,digest in manifest['original_sources'].items():
 current=(PORT/'src'/rel).read_bytes().replace(b'\r\n',b'\n')
 assert sha(current)==digest
 assert current==committed[rel]
assert (H/'before-LifeSession.luau').read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','e93d413d:roblox_port/src/Shared/Life/LifeSession.luau'],cwd=ROOT).replace(b'\r\n',b'\n')
red=(H/'red-corrected-fixture.txt').read_text();assert 'CONTINUING passed=125 failed=15'in red and'NATURE_CLIENT passed=6 failed=5'in red
green=(H/'green.txt').read_text();counts={name:(int(ok),int(bad))for name,ok,bad in re.findall(r'(CONTINUING|NATURE_CLIENT|NATURE|MEALS) passed=(\d+) failed=(\d+)',green)}
assert counts==dict(CONTINUING=(145,0),NATURE_CLIENT=(11,0),NATURE=(28890,0),MEALS=(88,0))and'FAIL 'not in green
exports=read(PORT/'build-receipt.json');assert exports['evidence_id']=='597db4c421e47c5e'and exports['source_count']==273
for out in exports['outputs']:
 assert sha((PORT/out['file']).read_bytes())==out['sha256']
for rel,digest in manifest['original_sources'].items():
 prefixes={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
 parts=Path(rel).parts;key='.'.join([prefixes[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
 assert exports['sources'][key]==digest
def get(url):
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Windowsill-audit'}),timeout=30)as response:return json.load(response)
url=f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{runid}'
run=get(url);jobs=get(url+'/jobs')
assert run['head_sha']==commit and len(jobs['jobs'])==1
steps=jobs['jobs'][0]['steps'];complete=run['status']=='completed'and run['conclusion']=='success'
if complete:
 assert all(s['conclusion']=='success'for s in steps)
 required={'Every module compiles','Strict types','All suites','Normal and self-test exports','Runner failure and cleanup regressions'}
 assert required.issubset({s['name']for s in steps})
ci=dict(checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),run=run,job=jobs['jobs'][0],all_suites_completed=complete,default_suites=80)
(H/'github-ci.json').write_bytes((json.dumps(ci,indent=2)+'\n').encode())
qualification=dict(source_commit=commit,evidence_id=exports['evidence_id'],sources=273,game_module_changes=['Shared/Life/LifeSession.luau'],
 targeted_suites=counts,targeted_passes=sum(x[0]for x in counts.values()),targeted_failures=0,
 native_run=native['events'][0]['run'],native_guards=2,native_errors=0,native_warnings=len(native['creator_warnings']),
 native_model_sha256=native['model_sha256'],native_log_sha256=native['log_sha256'],export_hashes={x['file']:x['sha256']for x in exports['outputs']},
 full_ci_run=runid,full_ci_status=run['status'],full_ci_conclusion=run['conclusion'],full_ci_suites=80 if complete else None,
 published=False,private_published_version_unchanged=14,production_changed=False,
 limits=native['limits'])
(H/'qualification.json').write_bytes((json.dumps(qualification,indent=2)+'\n').encode())
print(json.dumps({k:qualification[k]for k in ['evidence_id','targeted_passes','native_run','full_ci_status','full_ci_conclusion','full_ci_suites']}))
assert not a.require_ci or complete,'CI is not complete; inspect the same live run, never infer success'
