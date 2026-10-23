from pathlib import Path
import hashlib,io,json,subprocess,tarfile,tempfile,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert not (H/'checks.json').exists(),'Preserve prior evidence'
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','roblox_port/default.project.json'],cwd=ROOT)
rows=[]
with tempfile.TemporaryDirectory() as tmp:
 snap=Path(tmp)
 with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
  for item in archive:
   if not item.isfile():continue
   path=(snap/item.name).resolve();assert path.is_relative_to(snap)
   path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(archive.extractfile(item).read())
 folder=snap/'roblox_port';files=sorted((folder/'src').rglob('*.luau'));fail=[]
 for path in files:
  run=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'-O0','--null',str(path)],capture_output=True,text=True)
  if run.returncode:fail.append(str(path.relative_to(folder))+' '+run.stdout+run.stderr)
 compileText='compile '+str(len(files)-len(fail))+'/'+str(len(files))+'\n'+'\n'.join(fail)
 (H/'compile.txt').write_text(compileText,encoding='utf8',newline='\n');assert not fail
 for name,command in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),
  ('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src']),
  ('runner',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_runner.py'])]:
  run=subprocess.run(command,cwd=folder,capture_output=True,text=True);output=run.stdout+run.stderr
  (H/(name+'.txt')).write_text(output,encoding='utf8',newline='\n');rows.append(dict(name=name,exit_code=run.returncode,output_sha256=sha(output.encode())))
  print(name,run.returncode,output[:3000],flush=True)
  assert run.returncode==0
 result=dict(source=source,compile_passed=len(files),compile_sha256=sha((H/'compile.txt').read_bytes()),steps=rows,
  project_sha256=sha((folder/'default.project.json').read_bytes()),definitions_sha256=sha((TOOLS/'globalTypes.d.luau').read_bytes()))
(H/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
