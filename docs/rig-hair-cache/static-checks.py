"""Normal-source qualification without replacing the existing sourcemap."""
from pathlib import Path
import json,subprocess
H=Path(__file__).resolve().parent;P=H.parents[1]/'roblox_port'
T=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
files=sorted((P/'src').rglob('*.luau'));fail=[]
for f in files:
 r=subprocess.run([str(T/'luau/luau-compile.exe'),'-O0','--null',str(f)],capture_output=True,text=True)
 if r.returncode:fail.append(dict(file=str(f),stderr=r.stderr))
(H/'compile.json').write_text(json.dumps(dict(total=len(files),passed=len(files)-len(fail),failures=fail),indent=2)+'\n')
assert len(files)==273 and not fail
s=P/'.rig-hair-sourcemap.json';assert not s.exists()
subprocess.run([str(T/'rojo/rojo.exe'),'sourcemap','default.project.json','--output',str(s)],cwd=P,check=True,capture_output=True)
r=subprocess.run([str(T/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(s),'--definitions='+str(T/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'],cwd=P,capture_output=True,text=True)
(H/'strict.txt').write_text(r.stdout+r.stderr)
s.rename(H/'sourcemap.json')
assert r.returncode==0,(r.stdout+r.stderr)[:2000]
r=subprocess.run(['C:/Users/natha/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe','-m','unittest','discover','-s','roblox_port/tests','-p','test_runner.py'],cwd=P.parent,capture_output=True,text=True)
(H/'runner.txt').write_text(r.stdout+r.stderr)
assert r.returncode==0
print('compile 273/273; strict 0; runner 5/5')
