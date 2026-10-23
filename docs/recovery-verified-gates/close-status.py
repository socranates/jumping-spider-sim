from pathlib import Path
from datetime import datetime,timezone
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
v=json.loads((HERE/'verification.json').read_text());assert v['current_workspace_inputs_verified'] and v['windows_passed']==v['linux_passed']==468352
c=json.loads((ROOT/'docs/save-slot-isolation/recovery-source-verification.json').read_text());assert c['source']==v['source'] and c['collector_assertions']==3571 and c['integration_assertions']==311
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());data['source']=v['source'];data['as_of_utc']=datetime.now(timezone.utc).isoformat()
item=next(x for x in data['requirements'] if x['id']=='cli-and-runner');item['status']='both-platforms-verified';item['evidence_boundary']='Current4220d0c Windows44363 and Linux39890016962 both terminal76/468352/0, compile222, strict and runner5 clean. Root verifier binds exact current runtime/test/workflow bytes, corrected adopted session and native127/224 source fingerprints. Earlier failures remain preserved. Native scope is isolated protocol/MemoryBackend, not service/rejoin/full transport.';item['references']=['docs/recovery-verified-gates/verification.json','docs/recovery-verified-gates/README.md','docs/save-slot-isolation/SESSION-CALLBACK-AUDIT.md']
item=next(x for x in data['requirements'] if x['id']=='save-request-budget');item['status']='corrected-adopted-both-platforms-and-isolated-native-verified';item['evidence_boundary']='Exact8ad013b9 session adopted in4220d0c, with127 regular checks and STATE1251/0. Both full platforms76/468352/0, compile222, strict and runner5 pass, plus native127/224 fingerprints/zero errors under strengthened callback accounting. Prior20f59026 failed integration1250/2 and was withdrawn before commit. Actual service/rejoin/full transport remain unverified.'
data['latest_corrected_recovery_adoption'].update(status='both-platforms-verified',evidence='docs/recovery-verified-gates/verification.json')
data['latest_raw_source_collection_prototype']=c
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''# Current: corrected recovery full cohort green; raw collection composed privately

Production4220d0c: Windows44363 and Linux39890016962 both terminal76 suites/468352 checks/0 failures, all222 modules compile, strict and runner5 clean. Current root verification binds exact runtime/test/workflow bytes and the corrected native127/224-source evidence. Both full jobs are terminal. Nothing published.

The next historical-save dependency is implemented privately: raw four-slot collection, second-pass source verification, owned frozen copies, missing/unavailable separation, explicit same-session heartbeat handling and cancellable cooperative preparation.3571 collector/311 composition/2 corrected aggregate-bound checks pass, along with compile/full strict. The actual adapter, archive publisher and scheduler compose over a fake cached store under the per-minute allowance, including heartbeat drift and a lost acknowledgement;20 requests/2 heartbeats/135 simulated seconds. A retained counterexample proves646 copied nodes could accumulate under a500-node cap; the fix refuses earlier with323. Original values are preserved. This is not a native heap/performance or real DataStore claim.

See docs/save-slot-isolation/RECOVERY-SOURCE-COLLECTION.md. This collector is outside production and has no real SaveSession authority/intent integration, native or service/rejoin proof, portable progress projection or destination commit. The progress-into-Preserve/complete-original-archive policy remains; migration is not yet playable. Natural lifecycle/streaming/device/memory/performance/main/laptop/release and other audit requirements remain open. Goal active.

Earlier status below is historical.

'''
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
p=HERE/'README.md';p.write_text('''# Corrected recovery cohort completed

Source4220d0c43142cee91b83bdbd99fffcee8dfd6c5c is verified on both platforms:76 suites/468352 checks/0 failures. Windows44363 exited0 after1191.33 seconds; Linux39890016962 completed with222 compilations, strict clean and5 runner regressions. Root verify.py binds exact current runtime/test/workflow inputs and raw terminal logs. All jobs in this cohort are terminal; do not restart them. Nothing published.

Native127/224 fingerprints/zero errors supports the exact adopted session under MemoryBackend/coroutine/callback tests with all production scripts disabled. It is not actual service/rejoin/full-game transport or migration proof. The raw-source collector has separate private CLI evidence and remains outside production.

Original planning/status below is historical.

'''+p.read_text(),encoding='utf8',newline='\n')
print('Closed corrected recovery full cohort; recorded private raw collection milestone')
