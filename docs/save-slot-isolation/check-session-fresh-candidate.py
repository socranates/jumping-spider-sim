from pathlib import Path
import hashlib,json,shutil,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
names={'Server/DataStoreBackend.luau':'fresh-read-backend-candidate.luau','Shared/Persistence/SaveSession.luau':'session-fresh-candidate.luau'};rows=[]
assert not (HERE/'session-fresh-types.json').exists(),'Retain previous proof'
with tempfile.TemporaryDirectory() as tmp:
 folder=Path(tmp);shutil.copytree(ROOT/'roblox_port/src',folder/'src');shutil.copy2(ROOT/'roblox_port/default.project.json',folder/'default.project.json')
 for target,source in names.items():(folder/'src'/target).write_bytes((HERE/source).read_bytes())
 commands=[('compile-backend',[str(TOOLS/'luau/luau-compile.exe'),'--null',str(folder/'src/Server/DataStoreBackend.luau')]),
  ('compile-session',[str(TOOLS/'luau/luau-compile.exe'),'--null',str(folder/'src/Shared/Persistence/SaveSession.luau')]),
  ('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),
  ('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'])]
 for name,command in commands:
  result=subprocess.run(command,cwd=folder,capture_output=True,text=True);output=result.stdout+result.stderr
  (HERE/('session-fresh-'+name+'.txt')).write_text(output,encoding='utf8',newline='\n')
  rows.append(dict(name=name,exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest()));print(name,result.returncode,output[:3000],flush=True)
  if result.returncode:break
(HERE/'session-fresh-types.json').write_text(json.dumps(dict(candidates={source:hashlib.sha256((HERE/source).read_bytes()).hexdigest() for source in names.values()},steps=rows,production_changed=False,real_datastore_verified=False),indent=2)+'\n',encoding='utf8',newline='\n')
assert len(rows)==4 and all(row['exit_code']==0 for row in rows)
