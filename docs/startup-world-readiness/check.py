"""Startup-world-readiness build/compile/type/runner gates; optional full CLI run; no publishing or online save access."""
from pathlib import Path
import subprocess,sys,json,hashlib,re
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent;PORT=ROOT/'roblox_port'
TOOLS=Path(r'C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools')
def process(name,cmd,cwd=ROOT):
 with (OUT/(name+'.txt')).open('w',encoding='utf8',newline='\n') as f:r=subprocess.run([str(x) for x in cmd],cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
 (OUT/(name+'-process.json')).write_text(json.dumps({'exit_code':r.returncode,'command':[str(x) for x in cmd]},indent=2)+'\n',encoding='utf8',newline='\n')
 assert r.returncode==0,name
 print(name,'passed',flush=True)
if '--full-only' not in sys.argv:
 process('build',[sys.executable,PORT/'tools/build.py',TOOLS/'rojo/rojo.exe'])
 rows=[]
 for p in sorted((PORT/'src').rglob('*.luau')):
  r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'-O0','--null',str(p)],capture_output=True,text=True)
  rows.append({'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'exit_code':r.returncode,'errors':r.stderr if r.returncode else ''})
 (OUT/'compile.json').write_text(json.dumps({'total':len(rows),'passed':sum(r['exit_code']==0 for r in rows),'files':rows},indent=2)+'\n',encoding='utf8',newline='\n')
 assert len(rows)==216 and all(r['exit_code']==0 for r in rows)
 print('compile 216/216 passed',flush=True)
 process('sourcemap',[TOOLS/'rojo/rojo.exe','sourcemap','default.project.json','--output','sourcemap.json'],PORT)
 process('strict',[TOOLS/'lsp/luau-lsp.exe','analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'],PORT)
 assert not re.search(r'TypeError|SyntaxError|Error:',(OUT/'strict.txt').read_text())
 process('runner',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_runner.py'],PORT)
if '--full' in sys.argv or '--full-only' in sys.argv:
 assert not (OUT/'windows-full.txt').exists(),'preserve the existing full run before repeating'
 process('windows-full',[sys.executable,PORT/'tests/run.py',TOOLS/'luau/luau.exe'])
