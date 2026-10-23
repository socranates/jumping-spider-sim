from pathlib import Path
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
SOURCE='f4053597d03b99a61cb97e2eef1ec64ed174f22a'
for name in ['locate-ci.py','fetch-ci.py']:
 text=(HERE.parent/'checkpoint-return-oracle'/name).read_text(encoding='utf8').replace('405e9df16f5a8dbccadbcab9c8a654487d161445',SOURCE).replace('468114','468225')
 (HERE/name).write_text(text,encoding='utf8',newline='\n')
p=ROOT/'docs/save-slot-isolation/session-native-hidden-launch.json';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
header='''# Current: save freshness fix adopted; full gates running

Runtime/tests f4053597d03b99a61cb97e2eef1ec64ed174f22a on codex/save-continue. Three rest observation reads now bypass the DataStore cache before save authority is granted. A retained baseline counterexample proves stale authority could previously be acknowledged, while the final write CAS still protected stored data. The exact native-tested SaveSession and DataStoreBackend modules are adopted, with 111 regression checks added to state.luau (1124/0 in the focused adopted run). No schemas or gameplay mechanics changed.

Candidate evidence: stale-grant refusal27, extended matrix150, real adapter/session111, seven existing save suites1513, compile/full strict clean, and server-context Studio111 with224 fingerprints/zero CreatorErrors. The native diagnostic used a fake cached datastore, actual engine options and frozen valid checkpoints; all production scripts disabled. It was stopped/saved/closed/exited and original bytes restored. No real DataStore durability or complete game-session proof is claimed.

Windows full handle95443 and the exact-source Linux push run are pending. Expected76 suites/468225 checks are an expectation, not a completed result. Earlier405e9df both-platform468114/0 remains historical. Nothing published or integrated into main/laptop. See docs/save-slot-isolation/SESSION-CACHE.md and docs/session-freshness-gates/README.md.

The user's chosen recovery policy is portable spider progress into Preserve with the complete original save untouched in an archive. Production archive/controller/projection/schema/atomic commit and real service/rejoin tests remain unfinished. Broader lifecycle/streaming/device/memory/performance and release work remain open; goal active.

Earlier status below is historical.

'''
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;prior=p.read_text(encoding='utf8');assert not prior.startswith(header.splitlines()[0]);p.write_text(header+prior,encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text(encoding='utf8'))
items=data['requirements'] if 'requirements' in data else None
if items is None:
 for value in data.values():
  if isinstance(value,list) and any(isinstance(x,dict) and x.get('id')=='data-store-freshness' for x in value):items=value;break
assert items is not None
item=next(x for x in items if x['id']=='data-store-freshness')
item['status']='adopted-focused-native-verified-full-gates-running'
item['evidence_boundary']='f405359 adopts uncached initial/preview/intent rest observations, preserving final UpdateAsync fences. Baseline30 reproduces stale grants without data loss; candidate27, matrix150, adapter111, seven regressions1513, compile/strict clean and isolated Studio111/224 fingerprints/zero errors pass. Adopted STATE1124/0 focused run. Full Windows/Linux pending; no actual DataStore durability or full-game session claim.'
item['references']=['docs/save-slot-isolation/SESSION-CACHE.md','docs/save-slot-isolation/session-cache-verification.json','docs/save-slot-isolation/session-fresh-adoption.json','docs/session-freshness-gates/README.md']
data['latest_session_freshness_milestone']=dict(source=SOURCE,status=item['status'],windows_handle=95443,evidence='docs/session-freshness-gates/README.md',published=False,real_datastore_verified=False,progress_import_implemented=False)
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
print('Prepared source-bound pending status and CI collectors')
