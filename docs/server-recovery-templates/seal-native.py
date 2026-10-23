from pathlib import Path
import hashlib,json,subprocess
H=Path(__file__).resolve().parent
closed=json.loads((H/'studio-closed.json').read_text(encoding='utf8'))
assert closed['studio_windows']==0 and closed['verified_via']=='sky.list_windows'
probe=subprocess.run(['powershell','-NoProfile','-Command','if (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue) { exit 1 }'],capture_output=True,text=True)
assert probe.returncode==0,'Studio process is still live'
p=H/'native-receipt.json';r=json.loads(p.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
editor=model.with_name(model.stem+'-editor-copy.rbxl');assert editor.is_file()
r.update(studio_closed=True,studio_closed_observation=closed,editor_copy_path=str(editor),editor_copy_sha256=sha(editor.read_bytes()))
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Native 109/0 sealed; original unchanged, editor copy saved, Studio closed')
