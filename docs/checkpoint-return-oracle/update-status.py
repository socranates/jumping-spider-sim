from pathlib import Path
import datetime,hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];old=HERE.parent/'pond-drawing-reuse'
prior=json.loads((old/'windows-full-process.json').read_text());text=(old/'windows-full.txt').read_text()
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert prior['source']=='ccc0abbd8a1f6a0b37dbb6244c46c2a1b106f157' and prior['exit_code']==1
assert len(rows)==76 and sum(int(r[1]) for r in rows)==468113 and sum(int(r[2]) for r in rows)==1
assert [r for r in rows if int(r[2])>0]==[('CLIENT','26','1')]
(old/'windows-failed-summary.json').write_text(json.dumps(dict(source=prior['source'],suites=76,passed=468113,failed=1,exit_code=1,output_sha256=hashlib.sha256((old/'windows-full.txt').read_bytes()).hexdigest(),failure='Client smoke compared restored reserve with later live sample; controlled delay reproduced; test corrected in405e9df',replaced_by='405e9df16f5a8dbccadbcab9c8a654487d161445'),indent=2)+'\n',encoding='utf8',newline='\n')
ci=json.loads((HERE/'ci-final.json').read_text());assert ci['head_sha']=='405e9df16f5a8dbccadbcab9c8a654487d161445' and ci['conclusion']=='success' and ci['passed']==468114
archive=json.loads((HERE.parent/'save-slot-isolation/recovery-archive-verification.json').read_text());assert archive['native_assertions']==82 and not archive['production_changed']
note='''# Current verification: Linux passed; Windows17569 running

Current runtime/tests405e9df16f5a8dbccadbcab9c8a654487d161445 on codex/save-continue. Linux39880600604 completed76 suites/468114 checks/0 failures, compile222, strict clean and runner5. The corrected snapshot-return client suite passes27/0. Current immutable Windows full17569 is active; expected468114 is not a completed Windows result. Root verification still refuses its missing terminal gate. Do not restart this live process.

Earlierccc0abb Windows56925 is terminal exit1:76 suites/468113 passed/1 failed (CLIENT26/1). Its entire raw log, input hashes and failure summary are preserved under docs/pond-drawing-reuse. Earlierccc0abb Linux passed468114/0; that did not erase the Windows failure. The controlled29-frame diagnostic proved the old reserve oracle compared a later live value against the correctly restored snapshot. No gameplay code changed in405e9df.

Private recovery archive preparation now passes73 CLI/82 native assertions, all224 native fingerprints, zero CreatorErrors, compile and strict analysis. It freezes owned raw copies of all four save slots, including unknown/corrupt envelopes and backups, with bounded characters/nodes/depth and cancellation. It does not implement durable archive storage or progress import. The diagnostic was stopped/saved/closed/exited; original package bytes restored and prior stopped Studio rig retained. See docs/save-slot-isolation/RECOVERY-ARCHIVE.md. No player save was read or changed.

Pond drawing remains the exact tested renderer with18.13/21.32 percent lower isolated component CPU (full/low), not a whole-game FPS claim. Legacy migration, natural lifecycle/streaming, online/device/performance and release work remain open. Nothing published; goal active.

Earlier status below is historical.

'''
for name in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 path=ROOT/name;path.write_text(note+path.read_text(encoding='utf8'),encoding='utf8',newline='\n')
p=HERE/'README.md';p.write_text(note+p.read_text(encoding='utf8'),encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text());r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
for item in r['requirements']:
 if item['id']=='cli-and-runner':
  item['status']='linux-verified-windows-running'
  item['evidence_boundary']='Current405e9df Linux39880600604 terminal success76/468114/0, compile222/strict/runner5. Immutable current Windows17569 running. Earlierccc0abb Windows56925 terminal76/468113/1 with full raw evidence retained; diagnosed snapshot-oracle timing assumption fixed by comparing immutable kept state before resuming, client27/0. No current completed Windows/full gate claim.'
  item['references']=['docs/checkpoint-return-oracle/README.md','docs/checkpoint-return-oracle/ci-final.json','docs/pond-drawing-reuse/windows-failed-summary.json']
 elif item['id']=='legacy-world-restore':
  item['evidence_boundary']+=' Private raw archive preparation passes73 CLI/82 native, all224 native fingerprints, zero CreatorErrors and compile/strict, with frozen owned values/caps/cancellation. No raw production backend read, durable archive publisher or portable progress import is implemented.'
  item['references'].append('docs/save-slot-isolation/RECOVERY-ARCHIVE.md')
 elif item['id']=='repo-and-handoff':
  item['evidence_boundary']='Current405e9df runtime/tests pushed on codex/save-continue. Linux76/468114/0 complete; Windows17569 running. Prior failed Windows cohort retained. Private archive preparation73 CLI/82 native verified without production edits; durable archive/import pending. No release/main integration/publication/laptop sync; broader audit remains open.'
r['latest_snapshot_oracle_milestone'].update(status='linux-verified-windows-running',windows_handle=17569,linux_run=39880600604)
r['latest_recovery_archive_prototype']=dict(source=ci['head_sha'],cli_assertions=73,native_assertions=82,strict_clean=True,evidence='docs/save-slot-isolation/recovery-archive-verification.json',production_changed=False,durable_archive_implemented=False,progress_import_implemented=False,published=False)
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Recorded terminal old failure, current Linux success and live Windows17569; goal remains active.')
