from pathlib import Path
from datetime import datetime,timezone
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
v=json.loads((HERE/'session-budget-yield-verification.json').read_text());assert v['native_assertions']==126 and v['regression_assertions']==1624
ci=json.loads((ROOT/'docs/session-freshness-gates/ci-final.json').read_text());assert ci['head_sha']==v['base_source'] and ci['passed']==468225 and ci['conclusion']=='success'
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());data['source']=v['base_source'];data['as_of_utc']=datetime.now(timezone.utc).isoformat()
item=next(x for x in data['requirements'] if x['id']=='cli-and-runner')
item['status']='linux-verified-windows-running'
item['evidence_boundary']='Current f405359 Linux39886240490 terminal76/468225/0, compile222, strict and runner5 clean. Immutable Windows95443 remains live; expected76/468225/0 is not a completed Windows result. Current root verifier and prepared budget adoption refuse missing terminal gate.'
budget=next(x for x in data['requirements'] if x['id']=='save-request-budget')
budget['status']='private-cli-native-verified-adoption-pending'
budget['evidence_boundary']='Private20f59026 candidate supersedes pacing-only d217. It passes82 pacing/retention,44 actual coroutine-yield checks,1624 across7 unchanged save suites, compile/strict and126 native/224 fingerprints/zero errors. Late read callback after close was reproduced against d217; new load/demotion serials and post-yield fences reject closure/lost authority/superseding loads. Failed native missing-import fixture retained, corrected without candidate/criteria changes. Diagnostics closed/restored. Not adopted; actual service/rejoin/full transport and later full gates remain required.'
budget['references']=['docs/save-slot-isolation/SESSION-BUDGET-YIELD.md','docs/save-slot-isolation/session-budget-yield-verification.json','docs/save-slot-isolation/session-budget-native-receipt.json','docs/save-slot-isolation/session-budget-yield-baseline-receipt.json']
data['latest_request_budget_yield_candidate']=v
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''# Current: recovery candidate verified in Studio; Linux freshness gates passed

Production remains f405359. Linux39886240490 completed76 suites/468225 checks/0 failures, compile222, strict and runner5 clean. Windows95443 remains a live immutable full run; its expected result is not yet terminal. The current root verifier and prepared adoption script refuse the missing gate. Do not restart that process.

The newer private recovery candidate20f59026 passes82 pacing/retention checks,44 genuine coroutine-yield checks,1624 checks across seven unchanged save suites, compile/full strict, and126 native assertions with224 source fingerprints/zero CreatorErrors. It prevents late application/callbacks after close, demotion or a superseding load while retaining prompt progress notification and verified rest delivery. A missing-import native fixture failure was retained and corrected without changing candidate bytes or acceptance criteria. Both diagnostic places were stopped/saved/closed, the owned window exited and original package hashes restored. Prior Studio window untouched.

See docs/save-slot-isolation/SESSION-BUDGET-YIELD.md. The candidate is not adopted; no actual DataStore/full game transport, migration completion or release claim. Adoption is prepared for after the current cohort closes and will need its own full gates. Progress-into-Preserve/archive, natural lifecycle/streaming/device/memory/performance and release work remain open. Goal active.

Earlier status below is historical.

'''
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
print('Recorded Linux terminal evidence and private native recovery verification')
