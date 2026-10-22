from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent/'final-check';HERE.mkdir(exist_ok=False)
TOOLS=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools")
assert not (HERE/'compile.json').exists(),'preserve prior verification before repeating'
rows=[]
for p in sorted((ROOT/'roblox_port/src').rglob('*.luau')):
 assert p.is_file()
 r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'-O0','--null',str(p)],capture_output=True,text=True)
 rows.append(dict(path=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),exit_code=r.returncode,errors=r.stderr if r.returncode else ''))
 assert 'Error opening' not in r.stdout+r.stderr
(HERE/'compile.json').write_text(json.dumps(dict(total=len(rows),passed=sum(r['exit_code']==0 for r in rows),files=rows),indent=2)+'\n',encoding='utf8',newline='\n')
assert len(rows)==222 and all(r['exit_code']==0 for r in rows)
for name,cmd in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src']),('runner',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_runner.py'])]:
 r=subprocess.run(cmd,cwd=ROOT/'roblox_port',capture_output=True,text=True)
 (HERE/(name+'.txt')).write_text(r.stdout+r.stderr,encoding='utf8',newline='\n')
 (HERE/(name+'-process.json')).write_text(json.dumps(dict(exit_code=r.returncode,command=cmd),indent=2)+'\n',encoding='utf8',newline='\n')
 assert r.returncode==0,r.stdout+r.stderr
 print(name,'passed',flush=True)
print('222/222 compiled; release artifacts remain the previous snapshot',flush=True)
