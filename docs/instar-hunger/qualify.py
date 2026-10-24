"""Bind this candidate's game source, exports, native receipt and exact CI head."""
from pathlib import Path
import ast,datetime,hashlib,json,subprocess,urllib.request
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
COMMIT='7841306564588933888f87e7040702968814db97'
NATIVE='2a2af370';RUN=40110260962
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
m=read(H/'native-final/manifest.json');n=read(H/'native-final/result.json');b=read(PORT/'build-receipt.json')
assert m['revision']==n['source_commit'] and m['revision'].startswith(NATIVE)
assert n['passed'] and n['source_guards']==2 and n['studio_exited'] and n['model_unchanged'] and not n['creator_errors']
assert sha(Path(m['place']).read_bytes())==n['model_sha256']==m['place_sha256']
assert sha(Path(n['original_log']).read_bytes())==n['log_sha256']
assert (H/'playback.luau').read_bytes()==(H/'native-final/playback.luau').read_bytes()
actual={p.relative_to(PORT/'src').as_posix():sha(p.read_bytes().replace(b'\r\n',b'\n'))for p in (PORT/'src').rglob('*.luau')}
assert actual==m['original_sources'] and len(actual)==273
assert not subprocess.check_output(['git','diff',COMMIT,'--','roblox_port/src','roblox_port/tests'],cwd=ROOT)
assert not subprocess.check_output(['git','diff',m['revision'],COMMIT,'--','roblox_port/src'],cwd=ROOT)
for rel,digest in actual.items():
 committed=subprocess.check_output(['git','show',COMMIT+':roblox_port/src/'+rel],cwd=ROOT).replace(b'\r\n',b'\n')
 assert sha(committed)==digest
assert b['evidence_id']=='7c0bede90b301ac2' and b['source_count']==273 and not b['published']
for item in b['outputs']:assert sha((PORT/item['file']).read_bytes())==item['sha256']
assert n['moults']==17 and n['restored_moults']==3 and n['adults']==3
for required in ['INSTARS early=1527/10000 passed=10806 failed=0','HUNGER_VEIL passed=230 failed=0','GROWTH passed=574 failed=0','CHECKPOINT passed=607 failed=0']:
 assert required in (H/'focused.txt').read_text(encoding='utf-8')
assert 'STATE_CLIENT passed=161 failed=0'in (H/'state-client-final.txt').read_text(encoding='utf-8')
lists=[node for node in ast.walk(ast.parse((PORT/'tests/run.py').read_text(encoding='utf-8')))if isinstance(node,ast.List) and len(node.elts)==82 and all(isinstance(e,ast.Constant)and isinstance(e.value,str)and e.value.endswith('.luau')for e in node.elts)]
assert len(lists)==1
def get(url):return json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Windowsill-qualification'}),timeout=30))
run=get(f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{RUN}')
assert run['head_sha']==COMMIT
assert run['status']=='completed' and run['conclusion']=='success',f"CI is {run['status']}/{run['conclusion']}"
jobs=get(run['jobs_url']);assert len(jobs['jobs'])==1
steps=jobs['jobs'][0]['steps'];assert all(s['conclusion']=='success'for s in steps)
assert {'Every module compiles','Strict types','All suites','Normal and self-test exports','Runner failure and cleanup regressions'}.issubset({s['name']for s in steps})
(H/'github-ci.json').write_bytes((json.dumps(dict(run=run,jobs=jobs),indent=2)+'\n').encode())
result=dict(qualified_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_test_commit=COMMIT,game_source_commit='455dd28ffcc2c96e21297b8dacb2c1389c064a3b',native_source_commit=m['revision'],evidence_id=b['evidence_id'],ordinary_sources=273,native_sources=276,native_run=n['run'],native_moults=17,restored_moults=3,native_adults=3,native_creator_errors=0,native_creator_warnings=len(n['creator_warnings']),source_guards=2,studio_exited=True,model_unchanged=True,native_model_sha256=n['model_sha256'],native_log_sha256=n['log_sha256'],full_ci_run=RUN,full_ci_conclusion='success',full_ci_suites=82,published=False,remaining_biology=['stage-sized prey/currency','retreat hazards','measured survival tuning','carapace-size calibration'],limits=n['limits'])
(H/'qualification.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps(result,indent=2))
