from pathlib import Path
import datetime,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()=='59146e1005c083330455379766ab8c9dd2de2705'
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
assert json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))['conclusion']=='success'
assert json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))['assertions']==20
status='''# Current unpublished candidate: invalid fly-position refusal, 59146e1

Checkpoint now refuses NaN/infinite fly positions and plain tables masquerading as vectors before prepare/restore commits. Only save validation and its regressions changed; no hunting, feeding, settings, menu, schema or valid-save-format changes. Six current focused suites pass1783/0, all222 modules compile, strict clean, runner5 pass. Linux39872335932 completed76 suites/465412 checks/0 failures. Native20 actual-client refusal/atomicity assertions with all223 fingerprints and zero CreatorErrors pass. Current immutable full Windows58767 is running; do not restart it or claim completion from a partial log.

Previous032926f full Windows7806 closed successfully: Windows/Linux both76/465388/0, native22/all225 pass; its historical verifier passes with current-workspace-match=false. Those results do not substitute for current59146e1 Windows coverage. Both current native diagnostic windows have stopped/saved/closed/exited and original archive bytes are restored. Pre-existing stopped rig94504044 remains untouched. Root verification still refuses the pending current Windows gate.

Older-world policy: import portable progress into the Preserve while keeping the complete original save in an untouched archive. The isolated map-view candidate passes167 assertions plus compile/full strict analysis in a disposable source copy, but remains outside production. Migration is not implemented. Its design and field/storage review are in docs/save-slot-isolation/migration-design.md. The new fly-position fix is targeted corruption protection, not proof of validation for every spatial field/class.

Current-source animal/audio attribution completed two full-detail playing scenes without heavy concurrent local CLI work. Sill711 frames:16.885ms observed interval/6.263ms Lua callback mean; garden575:20.877ms/6.619ms,1105x433 viewport. In the broad sound category, drawing dominates the Lua audio handlers: wasp0.330/0.368ms per frame, pond0.184/0.138, cat0.087/0.098; combined audio handlers about0.056ms in both. Pond drawing shows about24KB positive heap growth per frame in these samples. These instrumented observations do not prove a leak, allocation rate, engine mixer cost, paired FPS gain or physical-device performance. No presentation optimization adopted. Investigate reuse of invariant darner geometry before reducing animation fidelity or lighting.

Natural streaming/rearrival, full natural lifecycle, physical devices, online durability, broader memory/performance, release rebuilding/publication and laptop synchronization remain open. Nothing published; goal active.

'''
complete=(HERE/'verification.json').exists() and json.loads((HERE/'verification.json').read_text(encoding='utf8')).get('current_workspace_inputs_verified')==True
if complete:
 status=status.replace('Current immutable full Windows58767 is running; do not restart it or claim completion from a partial log.','Windows58767 also completed76 suites/465412 checks/0 failures. Root source-bound verification passes for both platforms, compile/strict/runner and native refusal checks. All jobs in this source cohort are terminal.')
 status=status.replace('Root verification still refuses the pending current Windows gate.','Root verification confirms current59146e1 inputs and receipts; broader audit/release work remains open.')
for rel in ['docs/audit/CURRENT.md','chet/save-continue.md','docs/save-continue/README.md']:
 p=ROOT/rel;text=p.read_text(encoding='utf8');marker='Earlier status below is historical.';assert marker in text
 p.write_text(status+text[text.index(marker):],encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text(encoding='utf8'))
r['source']='59146e1005c083330455379766ab8c9dd2de2705';r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
for row in r['requirements']:
 if row['id']=='cli-and-runner':
  row.update(status='spatial-validation-linux-native-verified-windows-running',evidence_boundary='Current59146e1 six suites1783/0, compile222/strict/runner5. Linux39872335932 completed76/465412/0; native20/all223/zero CreatorErrors pass. Current immutable Windows58767 active. Prior032926f Windows7806 closed0, both platforms76/465388/0 and native22/all225 historically verified; not current591 Windows proof.',references=['docs/spatial-save-validation/README.md','docs/spatial-save-validation/ci-final.json','docs/spatial-save-validation/native-receipt.json'])
 if row['id']=='legacy-world-restore':
  row.update(status='policy-chosen-implementation-pending',evidence_boundary='User delegated choice; import portable progress into Preserve with untouched complete original archive. Private owned read-only map-view prototype167 checks plus compile/strict passes without changing production WorldMap. Full schema/archive/projection/native/durable migration remains unimplemented.',references=['docs/save-slot-isolation/migration-design.md','docs/save-slot-isolation/map-view-receipt.json','docs/save-slot-isolation/map-view-types-receipt.json'])
 if row['id']=='performance-A08':
  row['evidence_boundary']='Encoder068a878 matched native four-pair comparison20738 assertions averages40.27percent less isolated encoder CPU; bounded save/return32 passes, capture108/98ms remains synchronous. Current59146e1 attribution2 full-detail scenes/all223 sources verified, no competing heavy CLI: render interval16.885/20.877ms, Lua6.263/6.619ms at1105x433. Broad sound category is mostly animal drawing, not Lua audio handlers. Source-bound raw results and closure verified; no paired whole-game FPS, heap gain or hard-budget claim. Current Linux76/465412/0 and native20 pass, Windows58767 running.'
  row['references']=list(dict.fromkeys(row['references']+['docs/animal-presentation-cost/native-receipt.json','docs/animal-presentation-cost/verification.json','docs/spatial-save-validation/README.md']))
 if row['id']=='memory-attribution':
  row['evidence_boundary']='1800-second trace met investigation threshold. Isolated control reproduced allocation-category growth without game code; neither game leak nor engine bug nor leak absence is proven. Current59146e1 short instrumented scenes observe about24KB positive heap growth per frame in PondBodies; this excludes collections and is neither allocation rate nor retained-leak proof. Investigate invariant geometry and owned buffer reuse with exact-output checks.'
  row['references']=list(dict.fromkeys(row['references']+['docs/animal-presentation-cost/native-receipt.json']))
 if row['id']=='repo-and-handoff':
  row['evidence_boundary']='Current59146e1 runtime/tests pushed on codex/save-continue. Six focused suites1783/0, Linux76/465412/0, compile222/strict/runner5 and native20/all223 pass. Current Windows58767 running. Two-scene current animal attribution and diagnostic closure verified. Source release XML/BuildInfo remain older, no publication/main integration/laptop synchronization; broader recovery/lifecycle/online/device audit remains open.'
  row['references']=list(dict.fromkeys(row['references']+['docs/spatial-save-validation/README.md','docs/animal-presentation-cost/README.md']))
r['latest_readiness_milestone']['status']='historical-032-both-platforms-native-verified'
r['latest_spatial_validation_milestone']=dict(source=r['source'],status='linux-native-verified-windows-running',evidence='docs/spatial-save-validation/README.md',goal_complete=False,published=False)
r['latest_animal_attribution']=dict(source=r['source'],status='two-scenes-measured-no-optimization-adopted',evidence='docs/animal-presentation-cost/native-receipt.json',scenes=2,scripts=223,whole_game_fps_gain_proven=False,published=False)
if complete:
 for row in r['requirements']:
  if row['id']=='cli-and-runner':
   row.update(status='both-platforms-native-verified',evidence_boundary='Current59146e1 Windows58767 and Linux39872335932 both completed76 suites/465412/0. Source-bound root verification passes, all222 modules compile, strict clean, runner5; native20/all223/zero CreatorErrors. Earlier032/e51 results retain separate historical provenance.',references=['docs/spatial-save-validation/README.md','docs/spatial-save-validation/verification.json'])
  if row['id']=='performance-A08':
   row['evidence_boundary']=row['evidence_boundary'].replace('Current Linux76/465412/0 and native20 pass, Windows58767 running.','Current Windows/Linux76/465412/0 and native20 pass; no unverified FPS gain claim.')
  if row['id']=='repo-and-handoff':
   row['evidence_boundary']=row['evidence_boundary'].replace('Current Windows58767 running.','Current Windows58767 also completed76/465412/0; root source-bound verification passes.')
 r['latest_spatial_validation_milestone']['status']='both-platforms-native-verified'
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('Current59146e1 both full platforms/native verified; animal attribution measured.' if complete else 'Current59146e1 Linux/native verified, Windows58767 running; animal attribution measured.')
