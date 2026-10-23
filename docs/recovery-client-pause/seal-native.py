from pathlib import Path
import hashlib,json,re
H=Path(__file__).resolve().parent
p=H/'native-full-receipt.json';r=json.loads(p.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
editor=model.with_name(model.stem+'-editor-copy.rbxl');assert editor.is_file()
log=Path(r['studio_log']).read_text(encoding='utf8',errors='replace').splitlines()
begin=next(i for i,s in enumerate(log) if '[PLAYER_STREAM_NATIVE_BEGIN] '+r['run'] in s)
end=next(i for i,s in enumerate(log) if '[PLAYER_STREAM_NATIVE_PASS] '+r['run'] in s)
errors=[s for s in log[begin:end+1] if '[FLog::CreatorError]' in s]
r.update(editor_copy_path=str(editor),editor_copy_sha256=sha(editor.read_bytes()),original_model_unchanged=True,creator_errors_during_fixture=len(errors),studio_closed=True)
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Native receipt sealed; errors during fixture:',len(errors))
