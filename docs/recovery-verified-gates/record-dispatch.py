from pathlib import Path
from datetime import datetime,timezone
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
source=json.loads((HERE/'cohort-source.json').read_text())['source'];ci=json.loads((HERE/'ci-start.json').read_text());windows=json.loads((HERE/'windows-full-start.json').read_text())
assert ci['head_sha']==windows['source']==source and ci['id']==39890016962
r=dict(source=source,windows_handle=44363,linux_run=ci['id'],windows_status='live-confirmed-via-write_stdin',linux_status='in_progress-confirmed-via-api',expected_suites=76,expected_assertions=468352,terminal_results_pending=True,published=False)
(HERE/'dispatch.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());assert data['source']==source;data['as_of_utc']=datetime.now(timezone.utc).isoformat()
item=next(x for x in data['requirements'] if x['id']=='cli-and-runner');item['status']='current-full-gates-running';item['evidence_boundary']+=' Immutable Windows44363 and exact-source Linux39890016962 are confirmed live; no duplicate runs dispatched.'
data['latest_corrected_recovery_adoption'].update(windows_handle=44363,linux_run=ci['id'],status='adopted-native-verified-full-gates-running')
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''Current full cohort: Windows44363 is live and Linux39890016962 is in progress for SOURCE. Expected76/468352/0 remains unproven until both terminal receipts are verified. Do not duplicate either run. The preceding Windows95443 is terminal/historical. Current source changes are committed; further production edits should wait for this cohort to close. Private historical progress/archive preparation can continue meanwhile. Goal active; nothing published.

'''.replace('SOURCE',source)
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
p=HERE/'README.md';p.write_text(note+p.read_text(),encoding='utf8',newline='\n')
print(json.dumps(r))
