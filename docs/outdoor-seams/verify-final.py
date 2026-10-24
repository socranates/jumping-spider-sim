"""Current Windows checks after the recorded full-run failures.

The separate failed full run stays failed. This targeted run does not claim
all79 current Windows suites. GitHub CI supplies a separate full Linux run.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
T=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=H/'final-checks');a=p.parse_args()
out=a.out.resolve();assert not out.exists();out.mkdir()
sha=lambda b:hashlib.sha256(b).hexdigest()
def inputs():return {f.relative_to(PORT).as_posix():sha(f.read_bytes())for folder in ['src','tests']for f in (PORT/folder).rglob('*')if f.is_file()and '__pycache__'not in f.parts}
before=inputs();steps=[]
def run(name,command):
 print('START',name,flush=True)
 r=subprocess.run([str(x)for x in command],cwd=PORT,capture_output=True,text=True)
 data=(r.stdout+r.stderr).encode();(out/(name+'.txt')).write_bytes(data)
 steps.append(dict(name=name,exit_code=r.returncode,output_sha256=sha(data)))
 (out/'run-status.json').write_bytes((json.dumps(dict(inputs=before,steps=steps),indent=2)+'\n').encode())
 print(name,r.returncode,data.decode()[-1500:],flush=True);assert r.returncode==0,name
 return data.decode()
errors=[];sources=sorted((PORT/'src').rglob('*.luau'))
for f in sources:
 r=subprocess.run([str(T/'luau/luau-compile.exe'),'--null',str(f)],capture_output=True,text=True)
 if r.returncode:errors.append(str(f)+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_bytes((f'compile {len(sources)-len(errors)}/{len(sources)}\n'+'\n'.join(errors)).encode());assert not errors,errors
with tempfile.TemporaryDirectory(prefix='hut-final-types-')as temp:
 mapping=Path(temp)/'sourcemap.json'
 run('sourcemap',[T/'rojo/rojo.exe','sourcemap','default.project.json','--output',mapping])
 run('strict',[T/'lsp/luau-lsp.exe','analyze','--sourcemap='+str(mapping),'--definitions='+str(T/'globalTypes.d.luau'),'--no-strict-dm-types','src'])
run('runner-tests',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_runner.py'])
run('exports',[sys.executable,'tools/build.py',T/'rojo/rojo.exe'])
counts=[]
for suite in ['compact_layout','living_world','rest_storage','selftest_preserve']:
 text=run(suite,[sys.executable,'tests/run.py',T/'luau/luau.exe',suite+'.luau'])
 rows=[(m[1].strip(),int(m[2]),int(m[3]))for m in re.finditer(r'^([^\n]*?)passed=(\d+) failed=(\d+)[^\n]*$',text,re.M)]
 assert len(rows)==1 and rows[0][2]==0;counts+=rows
assert inputs()==before,'Inputs changed while checks ran'
build=json.loads((PORT/'build-receipt.json').read_text())
record=dict(inputs=before,steps=steps,source_count=len(sources),suite_summaries=counts,passed=sum(p for n,p,f in counts),failed=0,
 evidence_id=build['evidence_id'],build_receipt_sha256=sha((PORT/'build-receipt.json').read_bytes()),
 limits='Four current Windows suites, all-source compile/types, runner checks and exact exports. Earlier LOOK/full attempts retain their own cohorts. Full current Linux CI/native cohorts must be reported separately.')
(out/'receipt.json').write_bytes((json.dumps(record,indent=2)+'\n').encode());print(json.dumps({k:record[k]for k in ['passed','failed','evidence_id']}),flush=True)
