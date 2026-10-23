"""Recompute recorded native attribution from retained Creator evidence."""
from pathlib import Path
import json,subprocess,sys
H=Path(__file__).resolve().parent
subprocess.run([sys.executable,str(H/'prepare.py'),'--check','--cadence','frame'],check=True,capture_output=True)
for attempt in [1,2]:
 prefix=f'native-attempt{attempt}';r=json.loads((H/(prefix+'.json')).read_text())
 prepared=json.loads((H/f'native-prepared-attempt{attempt}.json').read_text())
 subprocess.run([sys.executable,str(H/'analyze.py'),'--log',str(H/(prefix+'.txt')),'--artifact',str(Path(prepared['place']).parent),'--run',r['run'],'--prefix',prefix,'--check'],check=True,capture_output=True)
 assert r['terminal']=='passed' and r['client_checks']==70 and r['client_summary']['server_checks']==10
 assert not r['online'] and not r['published']
 if attempt==2:assert r['samples']['SERVER_STEP'] and r['samples']['SERVER_PHASE']
summary=json.loads((H/'attribution-summary.json').read_text());last=json.loads((H/'native-attempt2.json').read_text())
for key in ['source','run','place_sha256','terminal','client_checks','client_summary','send_to_callback_summary','real_elapsed_spans','online','published']:assert summary[key]==last[key],key
assert summary['server_dominant_states']==sorted(last['samples']['SERVER_STEP'],key=lambda x:x['elapsed_seconds'],reverse=True)[:4]
assert not summary['controlled_speedup_claim'] and summary['request_admission_remains_open']
print('Both native cost runs, raw samples, original models and unchanged production/private inputs verified; no online/FPS/release claim.')
