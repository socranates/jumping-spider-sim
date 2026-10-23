from pathlib import Path
from datetime import datetime,timezone
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
v=json.loads((HERE/'session-verified-qualification.json').read_text());assert v['callback_aware_controls']==83 and v['unchanged_integration_assertions']==1250 and v['integration_failed']==0
p=HERE/'session-budget-yield-adoption.json';adopt=json.loads(p.read_text());adopt.update(status='withdrawn-before-commit',full_gates='not-started-withdrawn',production_changed=False);p.write_text(json.dumps(adopt,indent=2)+'\n',encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());data['source']=v['base_source'];data['as_of_utc']=datetime.now(timezone.utc).isoformat()
budget=next(x for x in data['requirements'] if x['id']=='save-request-budget');budget['status']='corrected-private-cli-verified-native-requalification-pending'
budget['evidence_boundary']='20f59026 was withdrawn before commit after ordinary integration1250/2 exposed unverified-slot delivery hidden by callback assertions swallowed inside pcall. Stronger persistent callback-failure harness rejects that source and passes83 with corrected8ad013b9, alongside44 yielding,1624 across7 unchanged save suites, the unchanged integration1250/0 and compile/strict. Production restored exactly to fully verified f405359. Earlier native126 is not adoption qualification. New224-source/expected127 native package is built but unrun; native/full/service/transport checks remain.'
budget['references']=['docs/save-slot-isolation/SESSION-CALLBACK-AUDIT.md','docs/save-slot-isolation/session-verified-qualification.json','docs/recovery-pacing-gates/initial-adoption-withdrawn.json','docs/recovery-pacing-gates/initial-integration-receipt.json','docs/recovery-pacing-gates/corrected-integration-receipt.json']
data['latest_request_budget_yield_candidate']['qualified_for_adoption']=False
data['latest_request_budget_yield_candidate']['qualification']='rejected-after-integrated-callback-audit'
data['latest_callback_audit_candidate']=v
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''# Current: full freshness cohort green; recovery replacement awaits fresh native qualification

Production is restored exactly to f405359. Windows95443 and Linux39886240490 both completed76 suites/468225 checks/0 failures, compile222, strict and runner5. Root source-bound verification passes. No full job is running and nothing published.

The uncommitted20f59026 recovery adoption was withdrawn after regular STATE1250/2 exposed stale callbacks for unread slots. Smaller callback assertions had been swallowed by callback protection. The stronger persistent failure harness rejects that candidate. Corrected private8ad013b9 now passes83 callback-aware checks,44 yielding checks,1624 checks across seven unchanged save suites, the unchanged integration1250/0 and compile/strict. The earlier native126 is not adoption qualification; its old adoption script is disabled.

See docs/save-slot-isolation/SESSION-CALLBACK-AUDIT.md. A distinct224-source native package with expected127 checks is built but unrun. Production remains on the previous fully verified cohort until fresh native/full qualification. No actual service/rejoin/full game transport or complete legacy migration claim. Progress-into-Preserve/complete archive, natural lifecycle/streaming/device/memory/performance and release work remain open. Goal active.

Earlier status below is historical.

'''
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
print('Recorded withdrawal, stronger-harness correction and unrun native requalification')
