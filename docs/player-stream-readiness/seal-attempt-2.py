from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent
p=H/'native-attempt-2-receipt.json';r=json.loads(p.read_text(encoding='utf8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
scripts=[i for i in ET.parse(model).getroot().iter('Item') if i.findtext("Properties/string[@name='Name']")=='SilkPlayback'];assert len(scripts)==1
probe=scripts[0].find("Properties/*[@name='Source']").text.encode()
assert sha(probe)==r['probe_sha256']
(H/'native-probe-attempt-2.luau').write_bytes(probe)
editor=model.with_name('Windowsill-player-diagnostic-2-editor-copy.rbxl');assert editor.is_file()
r.update(editor_copy_path=str(editor),editor_copy_sha256=sha(editor.read_bytes()),diagnosis='No position, velocity, life or needs time change; loading=false while destination collision remains absent. Per-render current-only check cleared the fixed-tick prospective wait on sub-tick renders.')
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Attempt 2 sealed; original model unchanged and editor state preserved separately')
