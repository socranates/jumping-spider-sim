from pathlib import Path
import hashlib,json,shutil,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
m=json.loads((HERE/'pond-candidate.json').read_text(encoding='utf8'))
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==m['source']
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
assert hashlib.sha256((ROOT/m['path']).read_bytes()).hexdigest()==m['reference_sha256']
candidate=(HERE/'pond-candidate.luau').read_bytes();assert hashlib.sha256(candidate).hexdigest()==m['candidate_sha256']
rows=[]
with tempfile.TemporaryDirectory() as tmp:
 folder=Path(tmp);shutil.copytree(ROOT/'roblox_port/src',folder/'src')
 shutil.copy2(ROOT/'roblox_port/default.project.json',folder/'default.project.json')
 (folder/'src/Client/PondBodies.luau').write_bytes(candidate)
 commands=[('compile',[str(TOOLS/'luau/luau-compile.exe'),'--null',str(folder/'src/Client/PondBodies.luau')]),
  ('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),
  ('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'])]
 for name,command in commands:
  result=subprocess.run(command,cwd=folder,capture_output=True,text=True)
  output=result.stdout+result.stderr
  (HERE/('pond-candidate-'+name+'.txt')).write_text(output,encoding='utf8',newline='\n')
  rows.append(dict(name=name,exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest()))
  print(name,result.returncode,output[:2000],flush=True)
  if result.returncode:break
assert hashlib.sha256((ROOT/m['path']).read_bytes()).hexdigest()==m['reference_sha256']
receipt=dict(source=m['source'],reference_sha256=m['reference_sha256'],candidate_sha256=m['candidate_sha256'],steps=rows,production_changed=False,adopted=False)
(HERE/'pond-candidate-types.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
assert len(rows)==3 and all(row['exit_code']==0 for row in rows)
