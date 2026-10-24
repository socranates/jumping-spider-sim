"""Bind game bytes, exact source/test CI, exports and native receipts."""
from pathlib import Path
import ast,datetime,hashlib,json,subprocess,urllib.request
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
COMMIT='a3527650fe925c52e66ee337fa9c7f51c868248c';RUN=40114770285
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
m=read(H/'native-final/manifest.json');n=read(H/'native-final/result.json');b=read(PORT/'build-receipt.json')
assert n['passed'] and n['returns']==3 and n['source_guards']==2 and n['studio_exited'] and n['model_unchanged'] and not n['creator_errors']
assert m['revision']==n['source_commit']
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
assert b['evidence_id']=='05cff2d915e3d7cc' and b['source_count']==273 and not b['published']
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for rel,digest in actual.items():
 parts=Path(rel).parts
 name='.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
 expected[name]=digest
assert b['sources']==expected
for item in b['outputs']:assert sha((PORT/item['file']).read_bytes())==item['sha256']
ordinary=read(H/'ordinary-checks.json')
assert ordinary['source_commit']==COMMIT and ordinary['sources']==actual and ordinary['source_count']==273
assert ordinary['compile_exit_code']==ordinary['strict_exit_code']==0
assert (H/'ordinary-compile.txt').read_text(encoding='utf-8').strip()=='compile 273/273'
for required in ['GENERATION_CHECKPOINT passed=31 failed=0','GENERATION_NETWORK passed=9 failed=0','CHECKPOINT passed=621 failed=0','LOCAL_REST_CLIENT passed=17 failed=0','LOCAL_RETURN passed=41 failed=0','MATING passed=773 failed=0','CLIENT_MATING passed=29 failed=0']:
 assert required in (H/'focused.txt').read_text(encoding='utf-8')
lists=[node for node in ast.walk(ast.parse((PORT/'tests/run.py').read_text(encoding='utf-8')))if isinstance(node,ast.List) and len(node.elts)==84 and all(isinstance(e,ast.Constant)and isinstance(e.value,str)and e.value.endswith('.luau')for e in node.elts)]
assert len(lists)==1
def get(url):return json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Windowsill-qualification'}),timeout=30))
run=get(f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{RUN}')
assert run['head_sha']==COMMIT
assert run['status']=='completed' and run['conclusion']=='success',f"CI is {run['status']}/{run['conclusion']}"
jobs=get(run['jobs_url']);assert len(jobs['jobs'])==1
steps=jobs['jobs'][0]['steps']
required={'Every module compiles','Strict types','All suites','Normal and self-test exports','Runner failure and cleanup regressions'}
assert jobs['jobs'][0]['status']=='completed' and jobs['jobs'][0]['conclusion']=='success'
assert not any(s['conclusion']in ['failure','cancelled','timed_out','action_required']for s in steps)
confirmed={s['name']for s in steps if s['status']=='completed' and s['conclusion']=='success'}
ci_complete=required.issubset(confirmed) and all(s['status']=='completed' and s['conclusion']=='success'for s in steps)
pending=sorted(required-confirmed)
# A green run with pending step metadata does not prove those steps executed.
# Independently require the entire exact-source Windows run and runner checks;
# never turn the missing Linux detail into an inferred full-suite pass.
w=read(H/'windows-full-receipt.json')
assert w['exit_code']==0 and w['suite_count']==84 and w['source_test_commit']==COMMIT
assert w['command'][1]=='roblox_port/tests/run.py' and len(w['command'])==3
assert sha((H/'windows-full.txt').read_bytes())==w['log_sha256']
prefixes=('GENERATION_CHECKPOINT passed=','GENERATION_NETWORK passed=','CHECKPOINT passed=','LOCAL_REST_CLIENT passed=','LOCAL_RETURN passed=','MATING passed=','CLIENT_MATING passed=')
selected=[line for line in (H/'windows-full.txt').read_text(encoding='utf-8').splitlines()if line.startswith(prefixes)]
assert len(selected)==7
assert (H/'focused.txt').read_text(encoding='utf-8')=='Selected summaries from the complete windows-full.txt run.\n'+'\n'.join(selected)+'\n'
assert 'Ran 5 tests' in (H/'runner-checks.txt').read_text(encoding='utf-8') and (H/'runner-checks.txt').read_text(encoding='utf-8').rstrip().endswith('OK')
(H/'github-ci.json').write_bytes((json.dumps(dict(run=run,jobs=jobs),indent=2)+'\n').encode())
result=dict(qualified_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_test_commit=COMMIT,native_source_commit=m['revision'],evidence_id=b['evidence_id'],ordinary_sources=273,ordinary_compiled=273,ordinary_strict_clean=True,exports_source_verified=True,native_sources=276,native_run=n['run'],native_returns=3,native_creator_errors=0,native_creator_warnings=len(n['creator_warnings']),source_guards=2,studio_exited=True,model_unchanged=True,native_model_sha256=n['model_sha256'],native_log_sha256=n['log_sha256'],ci_run=RUN,ci_summary_conclusion='success',ci_detailed_steps_complete=ci_complete,ci_unconfirmed_steps=pending,full_ci_suites=84 if ci_complete else None,full_windows_suites=84,full_windows_exit_code=0,full_windows_log_sha256=w['log_sha256'],runner_regressions=5,published=False,limits=n['limits'])
(H/'qualification.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps(result,indent=2))
