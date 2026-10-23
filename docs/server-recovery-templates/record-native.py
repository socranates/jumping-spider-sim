"""Record both native fixtures after their guarded run has been stopped."""
from pathlib import Path
import hashlib, json, re
H=Path(__file__).resolve().parent
LOG=Path(r'C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261023T163249Z_Studio_77344_last.log')
out=H/'native-output.txt';receipt=H/'native-receipt.json';assert not out.exists() and not receipt.exists()
r=json.loads((H/'native-prepared.json').read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
lines=LOG.read_text(encoding='utf8',errors='replace').splitlines()
guard=f"[PLAYER_STREAM_NATIVE_GUARD] {r['source']} 225 persistence_disabled"
assert any(guard in line for line in lines)
markers=[line for line in lines if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\].*\[(?:PLAYER_STREAM_NATIVE|SERVER_TEMPLATE_NATIVE)',line) and len(line)<3000]
runs={};checks={};starts=[];ends=[]
for prefix,expected in [('PLAYER_STREAM_NATIVE',82),('SERVER_TEMPLATE_NATIVE',27)]:
 begins=[(i,line) for i,line in enumerate(lines) if f'[{prefix}_BEGIN]' in line];assert begins
 start,line=begins[-1];run=line.split(f'[{prefix}_BEGIN] ',1)[1].strip()
 terminal=[(i,line) for i,line in enumerate(lines) if f'[{prefix}_PASS] {run} ' in line or f'[{prefix}_FAIL] {run} ' in line]
 assert len(terminal)==1 and f'[{prefix}_PASS]' in terminal[0][1],terminal
 value=int(terminal[0][1].split()[-1]);assert value==expected
 runs[prefix]=run;checks[prefix]=value;starts.append(start);ends.append(terminal[0][0])
errors=[line for line in lines[min(starts):max(ends)+1] if '[FLog::CreatorError]' in line];assert not errors,errors
measure=next(line.split('[SERVER_TEMPLATE_NATIVE_MEASURE] '+runs['SERVER_TEMPLATE_NATIVE']+' ',1)[1] for line in lines if '[SERVER_TEMPLATE_NATIVE_MEASURE] '+runs['SERVER_TEMPLATE_NATIVE']+' ' in line)
decoder=json.JSONDecoder();metrics,_=decoder.raw_decode(measure)
assert metrics['mode_count']==3 and metrics['comparison_gain_claim'] is False
text='\n'.join(markers)+'\n';out.write_text(text,encoding='utf8',newline='\n')
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
r.update(executed=True,native_verified=True,test_passed=True,terminal=True,stopped=True,runs=runs,
 actual_client_scripted_checks=82,native_authored_template_checks=27,total_native_checks=109,guard_verified_scripts=225,
 creator_errors_during_fixture=0,filtered_output_sha256=sha(out.read_bytes()),studio_log=str(LOG),
 metrics=metrics,original_model_unchanged=True,native_full_recovery_verified=False,physical_input_verified=False,
 scope='Unbound Studio; actual server authored geometry/callback recapture and preceding actual-client scripted fixture. Persistence disabled. Not native full recovery/menu replacement, natural lifecycle, sustained FPS or online saves.')
receipt.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
