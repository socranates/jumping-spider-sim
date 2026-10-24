"""Record the ordinary Windows checks for the additive hut ground repair.

Uses the current runner directly; the older staged-runner adapter predates
its lazy loading and must not be used with this tree. Logs normalize LF.
"""
from pathlib import Path
import ast,hashlib,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
T=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
out=H/'ground-checks';assert not out.exists();out.mkdir()
sha=lambda b:hashlib.sha256(b).hexdigest()
def inputs():
 return {f.relative_to(PORT).as_posix():sha(f.read_bytes())for folder in ['src','tests']for f in (PORT/folder).rglob('*')if f.is_file()and '__pycache__'not in f.parts}
before=inputs();steps=[]
def run(name,command):
 r=subprocess.run([str(x)for x in command],cwd=PORT,capture_output=True,text=True)
 data=(r.stdout+r.stderr).encode();(out/(name+'.txt')).write_bytes(data)
 steps.append(dict(name=name,exit_code=r.returncode,output_sha256=sha(data)))
 print(name,r.returncode,data.decode()[-1400:],flush=True)
 assert r.returncode==0,(name,'See retained output')
 return data.decode()
tree=ast.parse((PORT/'tests/run.py').read_text())
main=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='main')
loop=next(n for n in main.body if isinstance(n,ast.For));suites=ast.literal_eval(loop.iter.values[1])
text=run('full-cli',[sys.executable,'tests/run.py',T/'luau/luau.exe'])
counts=[(m[1].strip(),int(m[2]),int(m[3]))for m in re.finditer(r'^([^\n]*?)passed=(\d+) failed=(\d+)[^\n]*$',text,re.M)]
assert len(counts)==len(suites)==79 and all(f==0 for _,p,f in counts),counts
compile_errors=[]
sources=sorted((PORT/'src').rglob('*.luau'))
for f in sources:
 r=subprocess.run([str(T/'luau/luau-compile.exe'),'--null',str(f)],capture_output=True,text=True)
 if r.returncode:compile_errors.append(str(f)+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_bytes((f'compile {len(sources)-len(compile_errors)}/{len(sources)}\n'+'\n'.join(compile_errors)).encode())
assert not compile_errors,compile_errors
with tempfile.TemporaryDirectory(prefix='hut-ground-types-')as temp:
 mapping=Path(temp)/'sourcemap.json'
 run('sourcemap',[T/'rojo/rojo.exe','sourcemap','default.project.json','--output',mapping])
 run('strict',[T/'lsp/luau-lsp.exe','analyze','--sourcemap='+str(mapping),'--definitions='+str(T/'globalTypes.d.luau'),'--no-strict-dm-types','src'])
run('runner-tests',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_runner.py'])
run('exports',[sys.executable,'tools/build.py',T/'rojo/rojo.exe'])
assert inputs()==before,'Inputs changed while checks ran'
build=json.loads((PORT/'build-receipt.json').read_text())
record=dict(inputs=before,steps=steps,source_count=len(sources),suite_count=len(suites),suite_summaries=counts,
 passed=sum(p for _,p,f in counts),failed=sum(f for _,p,f in counts),evidence_id=build['evidence_id'],
 build_receipt_sha256=sha((PORT/'build-receipt.json').read_bytes()),compile_output_sha256=sha((out/'compile.txt').read_bytes()),
 limits='Windows CLI/shim, source compile/types and exact exports; native ground crossings have separate guarded cohorts. No publication or FPS claim.')
(out/'receipt.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps({k:record[k]for k in ['source_count','suite_count','passed','failed','evidence_id']}),flush=True)
