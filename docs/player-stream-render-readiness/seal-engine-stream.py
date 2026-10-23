from pathlib import Path
import argparse,hashlib,json
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--prefix',required=True);p.add_argument('--editor-name',required=True);a=p.parse_args()
assert Path(a.prefix).name==a.prefix and Path(a.editor_name).name==a.editor_name
path=H/(a.prefix+'-receipt.json');r=json.loads(path.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
editor=model.with_name(a.editor_name);assert editor.is_file()
log=Path(r['studio_log']).read_text(encoding='utf8',errors='replace').splitlines()
begin=next(i for i,s in enumerate(log) if '[ENGINE_STREAM_BEGIN] '+r['run'] in s)
end=next(i for i,s in enumerate(log) if ('[ENGINE_STREAM_PASS] '+r['run'] in s or '[ENGINE_STREAM_FAIL] '+r['run'] in s))
errors=[s for s in log[begin:end+1] if '[FLog::CreatorError]' in s]
r.update(original_model_unchanged=True,editor_copy_path=str(editor),editor_copy_sha256=sha(editor.read_bytes()),creator_errors_during_fixture=len(errors),editor_place_closed=True)
path.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print('Sealed engine experiment; CreatorErrors during fixture:',len(errors))
