from pathlib import Path
import datetime,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
v=json.loads((HERE/'verification.json').read_text());p=json.loads((HERE/'windows-full-process.json').read_text())
assert v['source']==p['source']=='405e9df16f5a8dbccadbcab9c8a654487d161445'
assert v['current_workspace_inputs_verified'] and v['windows_passed']==v['linux_passed']==468114 and p['exit_code']==0
s=json.loads((ROOT/'docs/save-slot-isolation/recovery-store-verification.json').read_text());assert s['native_assertions']==304 and not s['production_changed']
note='''# Current405e9df: both full platforms verified; recovery components private

Windows17569 and Linux39880600604 are terminal success:76 suites/468114 checks/0 failures each. Current source-bound root verification passes, all222 modules compile, strict clean and runner5 pass. The adopted pond renderer's separate native985 geometry/41 batch comparisons remain byte-bound; its measured18.13/21.32 percent lower component CPU is not a whole-game FPS claim. All jobs in this cohort are terminal. Nothing published.

Private archive publication/fresh-read components now pass272+32 CLI/304 native assertions, all226 native fingerprints, zero CreatorErrors and combined compile/strict. The protocol uses an immutable first recovery record, verifies each part, writes the completion marker last, handles restart/cancellation/conflicts, and requires uncached readback. It never writes original P_/R_ keys. The native server package disabled all production scripts; it tests protocol/API correctness, not a live DataStore or full game. Diagnostic closed/restored. See docs/save-slot-isolation/RECOVERY-PUBLICATION.md.

Existing production ordinary reads remain cached. SaveSession intent/ambiguous-write readbacks need a separate cache-aware integration trace before any broader fix claim. Recovery also still needs server authority/raw collection, budgets, portable projection, schema/atomic commit, actual isolated DataStore/rejoin and release checks. The older-world policy remains progress into Preserve with a complete unchanged original archive; it is not yet a playable migration. Broader natural lifecycle/streaming/device/memory/performance and release work remain open; goal active.

Earlier status below is historical.

'''
for name in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md','docs/checkpoint-return-oracle/README.md']:
 path=ROOT/name;path.write_text(note+path.read_text(encoding='utf8'),encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text());r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
for item in r['requirements']:
 if item['id']=='cli-and-runner':
  item['status']='both-platforms-verified'
  item['evidence_boundary']='Current405e9df Windows17569 and Linux39880600604 both terminal76/468114/0; source-bound root verification, compile222, strict and runner5 pass. Native pond component985/41 is bound to exact adopted bytes, not a current full-game walkthrough. Previousccc0abb Windows failure is retained separately and its snapshot-oracle assumption corrected.'
  item['references']=['docs/checkpoint-return-oracle/README.md','docs/checkpoint-return-oracle/verification.json','docs/pond-drawing-reuse/windows-failed-summary.json']
 elif item['id']=='legacy-world-restore':
  item['evidence_boundary']+=' Additional private publication/raw-read components pass272+32 CLI/304 server-native with all226 fingerprints and strict; restart/cancellation/ambiguous-readback logic exists but actual server authority, raw collection, quotas, real DataStore and progress import remain unintegrated.'
  item['references'].append('docs/save-slot-isolation/RECOVERY-PUBLICATION.md')
 elif item['id']=='repo-and-handoff':
  item['evidence_boundary']='Current405e9df both full platforms76/468114/0 verified, compile222/strict/runner5; own branch codex/save-continue. Private archive/publication/raw-read components and source-bound evidence retained. No production migration, real DataStore durability, release/main integration/publication/laptop sync; broader audit remains open.'
r['latest_snapshot_oracle_milestone'].update(status='both-platforms-verified')
r['latest_recovery_publication_prototype']=dict(source=v['source'],publication_cli_assertions=272,fresh_read_cli_assertions=32,native_assertions=304,strict_clean=True,evidence='docs/save-slot-isolation/recovery-store-verification.json',production_changed=False,real_datastore_verified=False,progress_import_implemented=False,published=False)
assert not any(x['id']=='data-store-freshness' for x in r['requirements'])
r['requirements'].append(dict(id='data-store-freshness',status='private-prototype-verified-integration-audit-pending',evidence_boundary='Current production DataStoreBackend.read uses default cached GetAsync; SaveSession validateIntent at line532 and rest/preview reads use it. Private readFresh/readRawFresh and mandatory uncached archive readback pass32 CLI within304 native tests, with real engine options cleanup but fake datastore/cache. Audit actual SaveSession ambiguous-write/intent traces before choosing production call sites. No observed live failure or whole-game fix claimed.',references=['docs/save-slot-isolation/RECOVERY-PUBLICATION.md','docs/save-slot-isolation/fresh-read-receipt.json','docs/save-slot-isolation/recovery-store-native-receipt.json']))
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Both current full platforms and private publication evidence recorded; goal remains active.')
