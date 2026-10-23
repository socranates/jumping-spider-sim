from pathlib import Path
import datetime,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];dest=ROOT/'docs/checkpoint-return-oracle';dest.mkdir(exist_ok=False)
old='ccc0abbd8a1f6a0b37dbb6244c46c2a1b106f157';source='405e9df'
import subprocess
source=subprocess.check_output(['git','rev-parse',source],cwd=ROOT,text=True).strip()
dynamic="SOURCE=__import__('subprocess').check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=HERE.parents[1],text=True).strip()"
for name in ['locate-ci.py','fetch-ci.py']:
 path=HERE/name;text=path.read_text(encoding='utf8');assert dynamic in text
 path.write_text(text.replace(dynamic,"SOURCE='"+old+"'"),encoding='utf8',newline='\n')
 (dest/name).write_text(text.replace(dynamic,"SOURCE='"+source+"'"),encoding='utf8',newline='\n')
full=(HERE/'full.py').read_text(encoding='utf8')
marker="assert not (HERE/'windows-full.txt').exists()"
assert marker in full
full=full.replace(marker,"prior=HERE.parent/'pond-drawing-reuse/windows-full-process.json'\nassert prior.exists(),'Wait for original immutable Windows56925 to be terminal; do not launch two full local runs'\np=json.loads(prior.read_text());assert p['source']=='"+old+"' and p['exit_code']!=0\n"+marker)
(dest/'full.py').write_text(full,encoding='utf8',newline='\n')
verify=(HERE/'verify.py').read_text(encoding='utf8')
verify=verify.replace("compiled=json.loads((HERE/'final-check/compile.json').read_text())","compiled=json.loads((HERE.parent/'pond-drawing-reuse/final-check/compile.json').read_text())")
verify=verify.replace("(HERE/'final-check'/(name+'-process.json'))","(HERE.parent/'pond-drawing-reuse/final-check'/(name+'-process.json'))")
verify=verify.replace('"""Bind the adopted renderer, platform gates and private native comparison."""','"""Bind the corrected snapshot test, full gates and unchanged renderer evidence."""')
(dest/'verify.py').write_text(verify,encoding='utf8',newline='\n')
root=ROOT/'docs/save-continue/verify.py';text=root.read_text().replace('pond-drawing-reuse/verify.py','checkpoint-return-oracle/verify.py');root.write_text(text,encoding='utf8',newline='\n')
note='''# Current: snapshot return test corrected; full gates pending

SourceSOURCE on codex/save-continue changes only client_smoke's oracle afterccc0abb. A29-frame controlled delay reproduced the old assertion while actual returned energy exactly matched the kept snapshot. The corrected test decodes that snapshot, waits for return using zero-time frames, checks exact saved time/tick/reserves and physical retreat position, then resumes frames and checks derived retreat state. The full private client suite passed27/0 before adopting the exact tested file. Gameplay code, feeding, settings and menus are unchanged.

Originalccc0abb Windows56925 remains running with an observed CLIENT26/1 failure; preserve its terminal log/receipt. Its Linux run39879471174 is a separate source cohort. The current405e9df Windows full run must wait for56925 to be terminal. New full Windows/Linux results are pending;468114 across76 suites is only the expected count. Existing222-module compile/strict/runner5 receipts are reused by exact production-file hashes because this commit changes only a test; current Linux also checks them. Root verification refuses missing current full gates. No release claim.

The pond renderer remains b2fdc562, with prior native geometry985/batch41 and measured component CPU18.13/21.32 percent lower full/low. Its exact production bytes and all other production files are unchanged by this test correction. Native component results do not prove whole-game FPS or device performance.

Private historical-world inspection now passes33 assertions including11 suspensions, both compilations and full strict analysis. It validates a generated populated Test Garden fixture without switching the Preserve or enabling ordinary restoration; see docs/save-slot-isolation/RECORDED-INSPECTION.md. Complete archive/progress migration remains pending. Nothing published; broader goal active.

Earlier status below is historical.

'''.replace('SOURCE',source)
(dest/'README.md').write_text(note.split('Earlier status below')[0],encoding='utf8',newline='\n')
for name in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 path=ROOT/name;path.write_text(note+path.read_text(encoding='utf8'),encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text(encoding='utf8'));r['source']=source;r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
for item in r['requirements']:
 if item['id']=='cli-and-runner':
  item['status']='snapshot-test-corrected-current-full-gates-pending'
  item['evidence_boundary']='Current405e9df changes only the checkpoint-return test oracle after a controlled delay reproduced a false comparison with a later live reserve. Corrected full client suite27/0; immutable snapshot/time/reserve assertions strengthened. Originalccc0abb Windows56925 continues with observed CLIENT26/1; its failed attempt will be retained. New current full gates pending. Existing compilation/native renderer proof is reusable by exact unchanged production hashes; no current full or release claim.'
  item['references']=['docs/checkpoint-return-oracle/README.md','docs/pond-drawing-reuse/return-energy-advanced29-diagnostic.json','docs/pond-drawing-reuse/return-test-v2-receipt.json']
 elif item['id']=='legacy-world-restore':
  item['evidence_boundary']+=' Subsequent private recorded-map inspector passes33 checks/11 suspensions and compile/strict on a populated generated Test Garden fixture, without changing production or enabling incompatible Continue.'
  item['references'].append('docs/save-slot-isolation/RECORDED-INSPECTION.md')
 elif item['id']=='repo-and-handoff':
  item['evidence_boundary']='Current405e9df runtime/tests pushed on codex/save-continue; latest change only corrects a reproduced snapshot-test timing assumption. Private client27/0. Current full gates pending; originalccc0abb Windows56925 has observed one failure and remains running. Pond optimization/native evidence retained with exact unchanged runtime hashes. No release/main integration/publication/laptop sync; migration/lifecycle/online/device audit open.'
r['latest_snapshot_oracle_milestone']=dict(source=source,status='focused-client-verified-full-gates-pending',evidence='docs/checkpoint-return-oracle/README.md',published=False)
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print('New test-only source cohort prepared; original Windows run retained.')
