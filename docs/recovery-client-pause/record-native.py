"""Collect only this fixture's markers, including warning failures, without claiming a release."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--attempt',required=True);p.add_argument('--prepared',required=True);p.add_argument('--log',type=Path,required=True);a=p.parse_args()
out=H/(a.attempt+'-output.txt');receipt=H/(a.attempt+'-receipt.json')
assert not out.exists() and not receipt.exists(),'Preserve previous evidence'
data=json.loads((H/a.prepared).read_text(encoding='utf8'))
lines=[s for s in a.log.read_text(encoding='utf8',errors='replace').splitlines() if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\].*\[PLAYER_STREAM_NATIVE',s) and len(s)<3000]
assert any('[PLAYER_STREAM_NATIVE_GUARD] '+data['source']+' 223 persistence_disabled' in s for s in lines)
begins=[s for s in lines if '[PLAYER_STREAM_NATIVE_BEGIN]' in s];assert begins
run=begins[-1].split('[PLAYER_STREAM_NATIVE_BEGIN] ',1)[1].strip()
terminal=[s for s in lines if '[PLAYER_STREAM_NATIVE_PASS] '+run in s or '[PLAYER_STREAM_NATIVE_FAIL] '+run in s];assert len(terminal)==1
passed='[PLAYER_STREAM_NATIVE_PASS]' in terminal[0]
text='\n'.join(lines)+'\n';out.write_text(text,encoding='utf8',newline='\n')
data.update(executed=True,native_verified=passed,test_passed=passed,terminal=True,stopped=True,run=run,guard_verified_scripts=223,filtered_output_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),studio_log=str(a.log),scope='Unbound Studio, persistence disabled; scripted actual-client collision hold, return and projected-step checks plus controlled presentation/HUD. Includes the actual restore closure with an owned recovery pause, obsolete-handle refusal and explicit release. No server-grant routing, complete recovery lifecycle, online save, natural lifecycle, physical input or performance proof.')
if passed:data['checks']=int(terminal[0].split()[-1])
else:data['failure']=terminal[0].split('[PLAYER_STREAM_NATIVE_FAIL] '+run,1)[1].strip()
receipt.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(data,indent=2))
