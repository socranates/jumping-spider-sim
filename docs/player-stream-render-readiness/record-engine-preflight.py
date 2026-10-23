from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent
p=H/'engine-full-default-prepared.json';r=json.loads(p.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
copy=model.with_name('Windowsill-engine-preflight-editor-copy.rbxl');assert copy.is_file()
log=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261023T132216Z_Studio_ED04A_last.log').read_text(encoding='utf8',errors='replace')
errors=[s for s in log.splitlines() if '[FLog::CreatorError]' in s and 'StreamingMinRadius is not a valid member' in s]
assert errors and '[ENGINE_STREAM_BEGIN]' not in log
output=H/'engine-full-default-preflight-output.txt';output.write_text('\n'.join(errors)+'\n',encoding='utf8',newline='\n')
probe=[i for i in ET.parse(model).getroot().iter('Item') if i.findtext("Properties/string[@name='Name']")=='SilkPlayback'];assert len(probe)==1
data=probe[0].find("Properties/*[@name='Source']").text.encode();assert sha(data)==r['probe_sha256']
(H/'engine-stream-probe-preflight-1.luau').write_bytes(data)
r.update(executed=False,preflight_passed=False,gameplay_started=False,native_verified=False,terminal=True,failure='Read of non-scriptable Workspace.StreamingMinRadius in the edit-mode guard',creator_preflight_errors=len(errors),original_model_unchanged=True,editor_copy_path=str(copy),editor_copy_sha256=sha(copy.read_bytes()),filtered_output_sha256=sha(output.read_bytes()),scope='Preflight failed before Play. Not a production game failure or native streaming test execution.')
(H/'engine-full-default-preflight-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print('Preserved original preflight failure and editor copy; no experiment execution claimed')
