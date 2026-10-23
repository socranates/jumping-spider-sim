from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert source!='f4053597d03b99a61cb97e2eef1ec64ed174f22a'
adopt=json.loads((HERE.parent/'save-slot-isolation/session-verified-adoption.json').read_text())
assert hashlib.sha256((ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau').read_bytes()).hexdigest()==adopt['session_sha256']
assert hashlib.sha256((ROOT/'roblox_port/tests/state.luau').read_bytes()).hexdigest()==adopt['regression_sha256']
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
(HERE/'cohort-source.json').write_text(json.dumps(dict(source=source,expected_suites=76,expected_assertions=468352,adoption=adopt),indent=2)+'\n',encoding='utf8',newline='\n')
for name in ['locate-ci.py','fetch-ci.py']:
 text=(HERE.parent/'session-freshness-gates'/name).read_text().replace('f4053597d03b99a61cb97e2eef1ec64ed174f22a',source).replace('468225','468352')
 (HERE/name).write_text(text,encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';data=json.loads(p.read_text());data['source']=source;data['as_of_utc']=datetime.now(timezone.utc).isoformat()
item=next(x for x in data['requirements'] if x['id']=='cli-and-runner');item['status']='current-full-gates-pending';item['evidence_boundary']='Current corrected recovery source '+source+' has focused STATE1251/0 and private/native127/224 sources/zero errors. New full Windows/Linux results are pending; expected76/468352/0 is not a completed gate. Earlierf405359 both platforms76/468225/0, compile222, strict and runner5 remain historical.';item['references']=['docs/recovery-verified-gates/README.md','docs/recovery-verified-gates/cohort-source.json','docs/session-freshness-gates/verification.json']
item=next(x for x in data['requirements'] if x['id']=='save-request-budget');item['status']='corrected-adopted-native-verified-full-gates-pending';item['evidence_boundary']='Exact8ad013b9 session adopted in '+source+', with127 regular assertions added. Strong callback-aware83/yield44,1624 existing save regressions, unchanged integration1250/0, compile/strict and new native127/224 sources/zero errors pass. Focused adopted STATE1251/0. Prior20f59026 withdrawn before commit; failed state1250/2 and stronger-harness negative retained. Native diagnostics closed/restored. Full candidate Windows/Linux, actual service/rejoin/full transport remain open.';item['references']=['docs/recovery-verified-gates/README.md','docs/save-slot-isolation/session-verified-native-qualification.json','docs/save-slot-isolation/session-verified-adoption.json']
data['latest_corrected_recovery_adoption']=dict(source=source,status=item['status'],evidence='docs/recovery-verified-gates/README.md',published=False,real_datastore_verified=False,progress_import_implemented=False)
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
note='''# Current: corrected recovery adopted; new full gates pending

Runtime/tests SOURCE on codex/save-continue adopts the exact native-tested8ad013b9 SaveSession. Periodic recovery is bounded, only freshly loaded slots are delivered, progress notification remains prompt, and closure/demotion/superseding loads fence late results.127 regression assertions were added; adopted STATE passes1251/0. Schemas and gameplay mechanics are unchanged.

New native qualification passed127 checks with224 source fingerprints/zero CreatorErrors, including persistent callback failure accounting. Both module compiles/full strict,83 focused/44 yielding,1624 prior save regressions and unchanged integration1250/0 pass. The earlier20f59026 adoption was withdrawn before commit after1250/2; its raw failure is retained and old adoption/runner disabled. The corrected diagnostic was stopped/saved/closed/exited and original bytes restored; prior Studio window untouched.

New full Windows/Linux gates are pending; expected76/468352/0 is not a result. Earlierf405359 both-platform76/468225/0 is historical. Nothing published. See docs/recovery-verified-gates/README.md. Actual service/rejoin/full game transport, complete historical progress/archive migration, natural lifecycle/streaming/device/memory/performance/main/laptop/release work remain open. Goal active.

Earlier status below is historical.

'''.replace('SOURCE',source)
for path in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 p=ROOT/path;text=p.read_text();assert not text.startswith(note.splitlines()[0]);p.write_text(note+text,encoding='utf8',newline='\n')
print(json.dumps(dict(source=source,expected_suites=76,expected_assertions=468352)))
