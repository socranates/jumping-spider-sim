"""Verify the single game-note correction with existing suites and build gates."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
PY=sys.executable;T=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
changed=subprocess.check_output(['git','diff','--name-only','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).splitlines()
assert changed==['roblox_port/src/Shared/Data/NotebookPages.luau'],changed
before=(PORT/'src/Shared/Data/NotebookPages.luau').read_bytes()
subprocess.run([PY,'tools/gen_notebook_pages.py'],cwd=PORT,check=True)
assert before==(PORT/'src/Shared/Data/NotebookPages.luau').read_bytes(),'Generator not repeatable'
steps=[]
commands=[('targeted',[PY,'tests/run.py',str(T/'luau/luau.exe'),'notebook.luau','minimal_hud.luau']),
 ('compile',[str(T/'luau/luau-compile.exe'),'--null','src/Shared/Data/NotebookPages.luau']),
 ('strict',[str(T/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(T/'globalTypes.d.luau'),'--no-strict-dm-types','src']),
 ('build',[PY,'tools/build.py',str(T/'rojo/rojo.exe')])]
if '--collect-only' in sys.argv:
 status=json.loads((H/'run-status.json').read_text());steps=status['steps']
 for f,h in status['inputs'].items():assert sha((ROOT/f).read_bytes())==h,f
else:
 for name,command in commands:
  r=subprocess.run(command,cwd=PORT,capture_output=True,text=True);output=r.stdout+r.stderr
  # Store normalized-LF output, not a claim of exact raw Windows console bytes.
  (H/(name+'.txt')).write_bytes(output.encode())
  print(name,r.returncode,output[-400:],flush=True)
  steps.append(dict(name=name,exit_code=r.returncode,output_sha256=sha(output.encode())))
  assert r.returncode==0,(name,output[-2000:])
 status=dict(steps=steps,inputs={f:sha((ROOT/f).read_bytes())for f in ['roblox_port/src/Shared/Data/NotebookPages.luau','roblox_port/tools/gen_notebook_pages.py','roblox_port/build-receipt.json']})
 (H/'run-status.json').write_bytes((json.dumps(status,indent=2)+'\n').encode())
assert [s['name']for s in steps]==[n for n,c in commands]
for s in steps:assert s['exit_code']==0 and sha((H/(s['name']+'.txt')).read_bytes())==s['output_sha256']
counts=re.findall(r'^(NOTEBOOK|MINIMAL) passed=(\d+) failed=(\d+)\s*$',(H/'targeted.txt').read_text(),re.M)
assert len(counts)==2 and all(int(f)==0 for _,p,f in counts),counts
build=json.loads((PORT/'build-receipt.json').read_text())
record=dict(steps=steps,counts=counts,evidence_id=build['evidence_id'],source_count=build['source_count'],
 sources=build['sources'],build_receipt_sha256=sha((PORT/'build-receipt.json').read_bytes()),
 generator_sha256=sha((PORT/'tools/gen_notebook_pages.py').read_bytes()),generator_repeatable=True,
 limits='One notebook game-note sentence. Existing suites, changed-module compile, full-source strict and both exports; normalized LF logs. Native30 cohort at66a9319760fa7c29 precedes this text-only change; no new native layout or publication.')
(H/'receipt.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(evidence_id=build['evidence_id'],counts=counts)))
