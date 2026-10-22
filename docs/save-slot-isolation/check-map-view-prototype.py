"""Compile/type-check the private map-view candidate in a disposable source copy."""
from pathlib import Path
import hashlib,json,shutil,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
production=ROOT/'roblox_port/src/Shared/World/WorldMap.luau'
before=production.read_bytes();candidate=(HERE/'map-view-prototype.luau').read_text(encoding='utf8')
with tempfile.TemporaryDirectory() as tmp:
 folder=Path(tmp);shutil.copytree(ROOT/'roblox_port/src',folder/'src')
 shutil.copy2(ROOT/'roblox_port/default.project.json',folder/'default.project.json')
 module=folder/'src/Shared/World/WorldMap.luau'
 text=before.decode('utf8');marker='return table.freeze(WorldMap)';assert text.count(marker)==1
 module.write_text(text.replace(marker,candidate+'\n'+marker),encoding='utf8',newline='\n')
 commands=[('compile',[str(TOOLS/'luau/luau-compile.exe'),'--null',str(module)]),
  ('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),
  ('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'])]
 rows=[]
 for name,command in commands:
  result=subprocess.run(command,cwd=folder,capture_output=True,text=True)
  output=result.stdout+result.stderr
  (HERE/('map-view-'+name+'.txt')).write_text(output,encoding='utf8',newline='\n')
  rows.append(dict(name=name,exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest()))
  print(name,result.returncode,output[:3500],flush=True)
  if result.returncode:break
assert production.read_bytes()==before
receipt=dict(source_sha256=hashlib.sha256(before).hexdigest(),candidate_sha256=hashlib.sha256(candidate.encode()).hexdigest(),
 steps=rows,production_changed=False,integrated=False,migration_implemented=False)
(HERE/'map-view-types-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
assert len(rows)==3 and all(row['exit_code']==0 for row in rows),'private candidate checks failed'
