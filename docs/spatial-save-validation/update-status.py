from pathlib import Path
import datetime,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
status='''# Current unpublished candidate: invalid fly-position refusal, 59146e1

Checkpoint now refuses NaN/infinite fly positions and plain tables masquerading as vectors before prepare/restore commits. Only save validation and its regressions changed; no hunting, feeding, settings, menu, schema or valid-save-format changes. Independent prior-source probe accepted all five malformed positions; private candidate refuses5/5 with2 healthy controls. Six current focused suites pass1783/0, all222 modules compile, strict clean, runner5 pass. Native20 actual-client checks are prepared only; Linux39872335932 is running. Current full Windows has not started.

Previous032926f full Windows7806 remains live from its immutable archive; do not restart it or relabel it as59146e1. That source's Linux76/465388/0 and native22/all225 fingerprints are verified; the historical verifier is pinned and will close after7806 becomes terminal. Current expected76/465412 and native20 are not completed results. Root verification requires the new candidate's own gates.

Older-world policy: import portable progress into the Preserve while keeping the complete original save in an untouched archive. The isolated map-view candidate passes167 assertions plus compile/full strict analysis in a disposable source copy, but remains outside production. Migration is not implemented. Its design and field/storage review are in docs/save-slot-isolation/migration-design.md. The new fly-position fix is targeted corruption protection, not proof of validation for every spatial field/class.

Animal/audio attribution remains prepared only, must be rebuilt on final current source, and must run without heavy local CLI work. Natural streaming/rearrival, full natural lifecycle, physical devices, online durability, broader memory/performance, release rebuilding/publication and laptop synchronization remain open. Nothing published; goal active.

'''
for rel in ['docs/audit/CURRENT.md','chet/save-continue.md','docs/save-continue/README.md']:
 p=ROOT/rel;text=p.read_text(encoding='utf8');marker='Earlier status below is historical.';assert marker in text
 p.write_text(status+text[text.index(marker):],encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text(encoding='utf8'))
r['source']='59146e1005c083330455379766ab8c9dd2de2705';r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
for row in r['requirements']:
 if row['id']=='cli-and-runner':
  row.update(status='spatial-validation-focused-verified-full-native-pending',evidence_boundary='Current59146e1 six suites1783/0, compile222/strict/runner5. Linux39872335932 running, current Windows not started, native20/all223 prepared only. Prior032926f Linux76/465388/0 and native22/all225 verified; its immutable Windows7806 still live, not proof of current source.',references=['docs/spatial-save-validation/README.md','docs/spatial-save-validation/focused-receipt.json'])
 if row['id']=='legacy-world-restore':
  row.update(status='policy-chosen-implementation-pending',evidence_boundary='User delegated choice; import portable progress into Preserve with untouched complete original archive. Private owned read-only map-view prototype167 checks plus compile/strict passes without changing production WorldMap. Full schema/archive/projection/native/durable migration remains unimplemented.',references=['docs/save-slot-isolation/migration-design.md','docs/save-slot-isolation/map-view-receipt.json','docs/save-slot-isolation/map-view-types-receipt.json'])
r['latest_readiness_milestone']['status']='historical-032-linux-native-verified-windows-running'
r['latest_spatial_validation_milestone']=dict(source=r['source'],status='focused-verified-full-native-pending',evidence='docs/spatial-save-validation/README.md',goal_complete=False,published=False)
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Current source59146e1; focused verified; independent full/native gates pending.')
