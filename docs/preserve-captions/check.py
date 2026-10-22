"""Source-bound Windows checks for the caption fix. Does not publish or use Roblox APIs."""
from pathlib import Path
import hashlib,json,re,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
PORT=ROOT/'roblox_port'
TOOLS=Path(r'C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools')

def process(name,command,cwd=ROOT):
    with (OUT/(name+'.txt')).open('w',encoding='utf-8',newline='\n') as log:
        result=subprocess.run([str(x) for x in command],cwd=cwd,stdout=log,stderr=subprocess.STDOUT)
    (OUT/(name+'-process.json')).write_text(json.dumps({'exit_code':result.returncode,'command':[str(x) for x in command]},indent=2)+'\n',encoding='utf-8',newline='\n')
    assert result.returncode==0,name
    print(name,'passed',flush=True)

process('build',[sys.executable,PORT/'tools/build.py',TOOLS/'rojo/rojo.exe'])
files=sorted((PORT/'src').rglob('*.luau'))
rows=[]
for file in files:
    result=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'-O0','--null',str(file)],capture_output=True,text=True)
    rows.append({'path':file.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'exit_code':result.returncode,'errors':result.stderr if result.returncode else ''})
(OUT/'compile.json').write_text(json.dumps({'passed':sum(r['exit_code']==0 for r in rows),'total':len(rows),'files':rows},indent=2)+'\n',encoding='utf-8',newline='\n')
assert len(rows)==216 and all(r['exit_code']==0 for r in rows)
print('compile 216/216 passed',flush=True)
process('sourcemap',[TOOLS/'rojo/rojo.exe','sourcemap','default.project.json','--output','sourcemap.json'],PORT)
process('strict',[TOOLS/'lsp/luau-lsp.exe','analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'],PORT)
text=(OUT/'strict.txt').read_text(encoding='utf-8')
assert not re.search(r'TypeError|SyntaxError|Error:',text)
process('targeted',[sys.executable,PORT/'tests/run.py',TOOLS/'luau/luau.exe','minimal_hud.luau','settings.luau','quiet.luau','state_client.luau'])
process('runner',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_runner.py'],PORT)
if '--full' in sys.argv:
    process('windows-full',[sys.executable,PORT/'tests/run.py',TOOLS/'luau/luau.exe'])
