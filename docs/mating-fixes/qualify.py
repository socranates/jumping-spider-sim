"""Bind native contact receipts, ordinary exports and final exact-head CI."""
from pathlib import Path
import hashlib,json,subprocess,urllib.request,datetime
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
COMMIT='75ff806d7775fb76fa2f2fc0eee6a23bfdfb5626';NATIVE_COMMIT='fdf88814bac93f722ab3451e75d9e28fb4aea4bd';RUN=40107325851
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
m=read(H/'native-final/manifest.json');n=read(H/'native-final/result.json');b=read(PORT/'build-receipt.json')
assert m['revision']==n['source_commit']==NATIVE_COMMIT and n['passed']
assert n['source_guards']==2 and n['studio_exited']and n['model_unchanged']and not n['creator_errors']
assert sha(Path(m['place']).read_bytes())==n['model_sha256']==m['place_sha256']
assert sha(Path(n['original_log']).read_bytes())==n['log_sha256']
assert (H/'playback.luau').read_bytes()==(H/'native-final/playback.luau').read_bytes()
actual={p.relative_to(PORT/'src').as_posix():sha(p.read_bytes().replace(b'\r\n',b'\n'))for p in (PORT/'src').rglob('*.luau')}
assert actual==m['original_sources']and len(actual)==273
assert not subprocess.check_output(['git','diff',COMMIT,'--','roblox_port/src','roblox_port/tests'],cwd=ROOT)
assert not subprocess.check_output(['git','diff',NATIVE_COMMIT,COMMIT,'--','roblox_port/src'],cwd=ROOT)
assert subprocess.check_output(['git','diff','--name-only',NATIVE_COMMIT,COMMIT,'--','roblox_port/tests'],cwd=ROOT,text=True).splitlines()==['roblox_port/tests/nature.luau']
for name,digest in actual.items():
 committed=subprocess.check_output(['git','show',COMMIT+':roblox_port/src/'+name],cwd=ROOT).replace(b'\r\n',b'\n')
 assert sha(committed)==digest,name
assert b['evidence_id']=='88c68c98a0324e8a'and b['source_count']==273 and not b['published']
for output in b['outputs']:assert sha((PORT/output['file']).read_bytes())==output['sha256']
assert 'MATING passed=773 failed=0'in (H/'mating-final.txt').read_text()
assert 'CLIENT_MATING passed=29 failed=0'in (H/'focused.txt').read_text()
assert {(r['player_sex'],r['skipped'])for r in n['routes']}=={(s,k)for s in ['female','male']for k in [False,True]}
assert sum(r['samples']for r in n['routes'])==1929
assert all(r['min_gap']>=r['radius']and r['lost_support']==0 and r['exit_gap']<1.5 for r in n['routes'])
def get(url):
 request=urllib.request.Request(url,headers={'User-Agent':'Windowsill-receipt-qualification'})
 return json.load(urllib.request.urlopen(request,timeout=30))
run=get(f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{RUN}')
assert run['head_sha']==COMMIT
assert run['status']=='completed'and run['conclusion']=='success',f"CI is {run['status']}/{run['conclusion']}"
jobs=get(run['jobs_url']);assert len(jobs['jobs'])==1
steps=jobs['jobs'][0]['steps'];assert all(s['conclusion']=='success'for s in steps)
assert {'Every module compiles','Strict types','All suites','Normal and self-test exports','Runner failure and cleanup regressions'}.issubset({s['name']for s in steps})
(H/'github-ci.json').write_bytes((json.dumps(dict(run=run,jobs=jobs),indent=2)+'\n').encode())
result=dict(qualified_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_commit=COMMIT,native_source_commit=NATIVE_COMMIT,evidence_id=b['evidence_id'],ordinary_sources=273,native_sources=276,native_run=n['run'],native_routes=4,native_samples=1929,native_creator_errors=0,native_creator_warnings=len(n['creator_warnings']),source_guards=2,studio_exited=True,model_unchanged=True,native_model_sha256=n['model_sha256'],native_log_sha256=n['log_sha256'],full_ci_run=RUN,full_ci_conclusion='success',full_ci_suites=80,mating_checks=773,moult_tuning_changed=False,published=False,limits=n['limits'])
(H/'qualification.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps(result,indent=2))
