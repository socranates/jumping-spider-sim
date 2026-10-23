"""Compile41 private candidates and type-check their complete production overlay."""
from pathlib import Path
import ast,hashlib,json,shutil,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/save-slot-isolation'
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
tree=ast.parse((P/'check-recovery-pipeline.py').read_text(encoding='utf8'))
names=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='names' for t in n.targets))
for filename in ['check-recovery-game-entry.py','check-recovery-profile-owner.py']:
 tree=ast.parse((P/filename).read_text(encoding='utf8'))
 for node in tree.body:
  if isinstance(node,ast.Assign) and isinstance(node.targets[0],ast.Subscript) and isinstance(node.targets[0].value,ast.Name) and node.targets[0].value.id=='names':names[ast.literal_eval(node.targets[0].slice)]=ast.literal_eval(node.value)
names.update({'Shared/Persistence/ReplacementProtocolPrototype.luau':'replacement-protocol-prototype.luau','Server/ReplacementOwnerPrototype.luau':'replacement-owner-prototype.luau','Server/ReplacementServicePrototype.luau':'replacement-service-prototype.luau','Client/ReplacementClientPrototype.luau':'replacement-client-prototype.luau'})
paths={target:P/source for target,source in names.items()};paths['Server/RecoveryNewLifePolicyPrototype.luau']=H/'new-life-policy-prototype.luau'
prefix=sys.argv[1];assert prefix.replace('-','').isalnum();assert not (H/(prefix+'-types.json')).exists()
sha=lambda b:hashlib.sha256(b).hexdigest()
inputs={path.relative_to(ROOT).as_posix():sha(path.read_bytes()) for path in paths.values()}
production={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in (ROOT/'roblox_port/src').rglob('*.luau')};production['roblox_port/default.project.json']=sha((ROOT/'roblox_port/default.project.json').read_bytes())
steps=[]
with tempfile.TemporaryDirectory() as tmp:
 folder=Path(tmp);shutil.copytree(ROOT/'roblox_port/src',folder/'src');shutil.copy2(ROOT/'roblox_port/default.project.json',folder/'default.project.json')
 for target,path in paths.items():(folder/'src'/target).write_bytes(path.read_bytes())
 errors=[]
 for target in paths:
  r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(folder/'src'/target)],capture_output=True,text=True)
  if r.returncode:errors.append(target+'\n'+r.stdout+r.stderr)
 output='compile '+str(len(paths)-len(errors))+'/'+str(len(paths))+'\n'+'\n'.join(errors)
 (H/(prefix+'-compile.txt')).write_text(output,encoding='utf8',newline='\n');assert not errors,output
 steps.append(dict(name='compile',exit_code=0,output_sha256=sha(output.encode())))
 for name,command in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'])]:
  r=subprocess.run(command,cwd=folder,capture_output=True,text=True);output=r.stdout+r.stderr
  (H/(prefix+'-'+name+'.txt')).write_text(output,encoding='utf8',newline='\n');steps.append(dict(name=name,exit_code=r.returncode,output_sha256=sha(output.encode())))
  print(name,r.returncode,output[:5000],flush=True)
assert inputs=={path.relative_to(ROOT).as_posix():sha(path.read_bytes()) for path in paths.values()}
assert production=={name:sha((ROOT/name).read_bytes()) for name in production}
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),candidates=inputs,production_inputs=production,steps=steps,production_connected=False,native_verified=False,real_datastore_verified=False)
(H/(prefix+'-types.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');assert all(s['exit_code']==0 for s in steps)
