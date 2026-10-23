from pathlib import Path
from datetime import datetime,timezone
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
v=json.loads((HERE/'verification.json').read_text());assert v['source']=='f4053597d03b99a61cb97e2eef1ec64ed174f22a' and v['current_workspace_inputs_verified'] and v['windows_passed']==v['linux_passed']==468225
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());data['source']=v['source'];data['as_of_utc']=datetime.now(timezone.utc).isoformat()
item=next(x for x in data['requirements'] if x['id']=='cli-and-runner');item['status']='both-platforms-verified'
item['evidence_boundary']='f405359 immutable Windows95443 and Linux39886240490 both terminal76/468225/0, compile222, strict and runner5 clean. Current root verifier confirms all runtime/test/workflow input bytes. Native freshness component111/224 fingerprints/zero errors binds exact adopted modules, not full-game or real DataStore coverage.'
item['references']=['docs/session-freshness-gates/verification.json','docs/session-freshness-gates/README.md','docs/save-slot-isolation/SESSION-CACHE.md']
item=next(x for x in data['requirements'] if x['id']=='data-store-freshness');item['status']='adopted-both-platforms-and-isolated-native-verified';item['evidence_boundary']='f405359 uncached rest load/preview/intent reads are adopted. Baseline stale-grant counterexample retained; focused and native111 checks bind exact modules. Both full platforms76/468225/0 with222 compile/strict and runner5 pass. Final UpdateAsync fences remain. No actual service durability or full-game transport claim.'
data['latest_session_freshness_milestone'].update(status='both-platforms-verified',evidence='docs/session-freshness-gates/verification.json')
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''# Current: freshness cohort fully verified; recovery candidate ready for adoption

Production f405359: Windows95443 and Linux39886240490 both terminal76 suites/468225 checks/0 failures, all222 modules compiled, strict clean and runner5. The root verifier confirms exact current runtime/test/workflow bytes. All full jobs in this cohort are terminal. Nothing published.

Private recovery candidate20f59026 passes82 pacing/retention,44 actual coroutine-yield,1624 checks in seven existing save suites, compile/strict and126 native/224 fingerprints/zero errors. Both native fixtures closed/restored, failed missing-import fixture retained. It is ready for exact-source adoption but is not yet production; subsequent adoption requires new full gates. See docs/save-slot-isolation/SESSION-BUDGET-YIELD.md.

Neither cohort proves real DataStore durability/full game transport or completes progress-into-Preserve/complete archive integration. Natural lifecycle/streaming/device/memory/performance and release work remain open. Goal active.

Earlier status below is historical.

'''
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
p=HERE/'README.md';p.write_text('''# Freshness cohort completed

Source f4053597d03b99a61cb97e2eef1ec64ed174f22a is verified on both platforms:76 suites,468225 checks,0 failures. Windows95443 exited0 after1473.57 seconds; Linux39886240490 completed successfully with222 module compilations, clean strict analysis and5 runner regressions. verify.py binds the exact committed/runtime workspace inputs and raw logs. This closes that cohort; do not restart its terminal process.

The native111-check evidence concerns the exact adopted adapter/session against a fake cached datastore with production scripts disabled. It is not a live DataStore, full transport, whole-game performance or migration claim. Nothing published. The private paced/yield-fenced recovery candidate has separate126-check native evidence and will require a new cohort when adopted.

Original planning/status below is historical.

'''+p.read_text(),encoding='utf8',newline='\n')
print('Closed the exact-source freshness cohort')
