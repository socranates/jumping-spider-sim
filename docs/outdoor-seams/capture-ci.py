"""Capture completed public GitHub CI metadata for the exact current code."""
from pathlib import Path
import ast,datetime,json,subprocess,urllib.request
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
run_id=40081320611;expected='16169af60f16696f442fe8227bbe954f1a24b858'
def get(url):
 req=urllib.request.Request(url,headers={'User-Agent':'Windowsill-verification','Accept':'application/vnd.github+json'})
 with urllib.request.urlopen(req,timeout=30)as response:return json.load(response)
base=f'https://api.github.com/repos/socranates/jumping-spider-sim/actions/runs/{run_id}'
run=get(base);jobs=get(base+'/jobs')['jobs']
assert run['head_sha']==expected and run['status']=='completed'and run['conclusion']=='success'
assert len(jobs)==1 and jobs[0]['status']=='completed'and jobs[0]['conclusion']=='success'
required=['Every module compiles','Strict types','All suites','Normal and self-test exports','Runner failure and cleanup regressions']
for name in required:assert any(s['name']==name and s['conclusion']=='success'for s in jobs[0]['steps'])
paths=['roblox_port/src','roblox_port/tests','roblox_port/tools','roblox_port/default.project.json','roblox_port/tests.project.json','.github/workflows/roblox-port.yml']
subprocess.run(['git','diff','--exit-code',expected,'--',*paths],cwd=ROOT,check=True)
tree=ast.parse((ROOT/'roblox_port/tests/run.py').read_text());main=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='main')
loop=next(n for n in main.body if isinstance(n,ast.For));suites=ast.literal_eval(loop.iter.values[1]);assert len(suites)==79
record=dict(retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 run={k:run[k]for k in ['id','head_sha','status','conclusion','html_url','created_at','updated_at']},
 jobs=[{k:j[k]for k in ['id','name','status','conclusion','started_at','completed_at','steps']}for j in jobs],
 suite_count=len(suites),suites=suites,
 limits='Completed GitHub API run/job/step metadata; full Linux CLI, compile/types, exports and runner checks. No exact assertion count inferred from metadata. Current source/tests/tools/config are byte-identical to this CI commit; native and Windows checks have separate receipts.')
target=H/'github-ci.json';assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(run_id=run_id,head=expected,conclusion=run['conclusion'],suites=len(suites))))
