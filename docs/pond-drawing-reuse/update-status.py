from pathlib import Path
import datetime,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert source=='ccc0abbd8a1f6a0b37dbb6244c46c2a1b106f157'
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text(encoding='utf8'))
r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();r['source']=source
for item in r['requirements']:
 if item['id']=='cli-and-runner':
  item['status']='current-full-gates-running'
  item['evidence_boundary']='Currentccc0abb bodies3610/0, compile222/strict/runner5 pass. Immutable Windows56925 and Linux39879471174 are running;468114 expected is not completed proof. Historical59146e1 Windows/Linux both76/465412/0 and native20 remain pinned. Current private pond geometry985/batch41/all224/zero CreatorErrors cover the exact adopted renderer; no full current native walkthrough claim.'
  item['references']=['docs/pond-drawing-reuse/README.md','docs/pond-drawing-reuse/ci-start.json','docs/spatial-save-validation/verification.json']
 elif item['id']=='performance-A08':
  item['evidence_boundary']+=' Subsequentccc0abb adopts the exact privately tested pond renderer: native isolated CPU18.13/21.32 percent lower full/low, positive heap growth88.60/92.45 percent lower,4/4 pairs faster each tier; geometry985 and batch41 pass. No whole-game FPS, allocation-rate or leak claim. New full platform gates running.'
  item['references']+=['docs/pond-drawing-reuse/README.md','docs/animal-presentation-cost/pond-v2-batch-receipt.json','docs/animal-presentation-cost/adoption.json']
 elif item['id']=='repo-and-handoff':
  item['evidence_boundary']='Currentccc0abb runtime/tests pushed on codex/save-continue. Exact tested pond renderer adopted; bodies3610/0, compile222/strict/runner5 pass; new full Windows56925 and Linux39879471174 running. Historical59146e1 both full platforms465412/0 and native20 verified. Source release XML/BuildInfo remain older; no publication/main integration/laptop synchronization. Legacy migration and broader lifecycle/online/device audit remain open.'
  item['references']=['docs/pond-drawing-reuse/README.md','chet/save-continue.md']
r['latest_pond_drawing_milestone']=dict(source=source,status='adopted-focused-native-verified-full-gates-running',evidence='docs/pond-drawing-reuse/README.md',windows_handle=56925,linux_run=39879471174,published=False,whole_game_fps_gain_proven=False)
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
note='Sourceccc0abbd8a1f6a0b37dbb6244c46c2a1b106f157; Windows handle56925 and Linux39879471174 running. Do not restart either gate or stage the growing Windows log.\n\n'
for name in ['README.md']:
 path=HERE/name;text=path.read_text(encoding='utf8');text=text.replace('# Pond drawing reuse, unpublished\n\n','# Pond drawing reuse, unpublished\n\n'+note);path.write_text(text,encoding='utf8',newline='\n')
print('Current pond adoption status recorded; full gates pending.')
