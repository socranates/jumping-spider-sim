from pathlib import Path
from datetime import datetime,timezone
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
v=json.loads((HERE/'session-budget-verification.json').read_text());assert v['candidate_assertions']==82 and v['regression_assertions']==1624
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());data['source']=v['base_source'];data['as_of_utc']=datetime.now(timezone.utc).isoformat()
items=data['requirements'];item=next(x for x in items if x['id']=='cli-and-runner')
item['status']='current-full-gates-running'
item['evidence_boundary']='Current f405359 Windows95443 and Linux39886240490 are live, with expected76/468225/0 not yet terminal. Earlier405e9df both platforms76/468114/0 is historical. Adopted freshness STATE1124/0 focused and isolated native111/224 fingerprints/zero errors pass. Current root verifier correctly refuses absent terminal gates.'
item['references']=['docs/session-freshness-gates/README.md','docs/session-freshness-gates/windows-full-start.json','docs/session-freshness-gates/ci-start.json','docs/checkpoint-return-oracle/verification.json']
inv=next(x for x in items if x['id']=='inventory');inv['evidence_boundary']=inv['evidence_boundary'].replace('Currente51c546','Historicale51c546')
assert not any(x['id']=='save-request-budget' for x in items)
items.append(dict(id='save-request-budget',status='private-candidate-cli-verified-native-integration-pending',evidence_boundary='f405359 periodic recovery starts3 or4 requests in one step, exceeding cap10 with9 prior requests. Retained baseline12 checks reproduces it. Private corrected candidate82 focused/1624 across7 unchanged save suites and compile/strict pass. First candidate delayed merged progress and failed an existing state assertion; failure/source retained. Corrected candidate sends progress promptly, retains prior rests internally and delivers verified replacements. Not adopted; native yielding/transport and new full gates still required.',references=['docs/save-slot-isolation/SESSION-BUDGET.md','docs/save-slot-isolation/session-budget-verification.json','docs/save-slot-isolation/session-budget-baseline-receipt.json']))
data['latest_request_budget_candidate']=v
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''# Current save audit: budget candidate verified privately

Production remains f405359; Windows95443 and Linux39886240490 full gates are running, not completed. The previous goal turn made progress by adopting the exact native-tested freshness fix and adding111 regular regression checks. This turn reproduced a separate periodic-recovery admission defect: three/four calls in one step can exceed the session's configured10/minute cap.

The private budget candidate now passes82 focused checks and1624 checks across seven unchanged save suites, plus compile/full strict. An earlier version failed an existing immediate merged-progress notification assertion; its source and raw failure are retained. The corrected version preserves prompt progress delivery and retained observations, with each replacement delivered only after fresh verification. Production is unchanged by this candidate; native yielding/transport and later full gates are still required. See docs/save-slot-isolation/SESSION-BUDGET.md.

No publication, migration completion or whole-game problem-free claim. The complete progress-into-Preserve/archive policy and remaining lifecycle/streaming/device/memory/performance/release requirements stay open. Goal active.

Earlier status below is historical.

'''
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
print('Recorded private candidate and explicit pending production gates')
