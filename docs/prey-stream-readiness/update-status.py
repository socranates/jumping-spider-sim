from pathlib import Path
import hashlib,json,datetime
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
status='''# Current unpublished candidate: cached prey streaming gate, 032926f

Existing insect populations pause and leave the active view while their collision geometry is unavailable, then resume the same objects. Independent baseline2/3, candidate5/0; garden suite256706/0, compile222/strict/runner5 pass. Linux39868843334 completed76 suites/465388 checks/0 failures. Current immutable Windows full run7806 is active; do not restart it or claim a current Windows pass yet.

Current Studio sequence passed22 assertions/all225 source fingerprints with zero CreatorErrors:11 roaming-creature readiness checks plus11 cached-prey checks. Real client objects, locally removed/restored geometry and manual ticks while paused; not natural server streaming or a full natural lifecycle. First native attempt chose garden_b4, which has no prey director, and failed its fixture assertion; exact failed evidence is retained. Corrected fixture uses authored milkweed prey in garden_c3. Both owned diagnostic windows are stopped/saved/closed/exited and original archive hashes restored. Prior rig94504044 remains untouched.

Previouse51c546 Windows/Linux both completed76/465383/0 and its historical verifier passes; those results do not substitute for current032926f Windows coverage. The preceding full native walkthrough274/0/0 belongs to068a878. Animal/audio attribution remains prepared only and must be rebuilt on current source after Windows finishes, without heavy concurrent CLI timing. No whole-game FPS gain claimed.

The user delegated the older-save policy; selected behavior imports portable progress into the Preserve and keeps the entire original save as an untouched archive. Design is recorded in docs/save-slot-isolation/migration-design.md; migration is not implemented. Natural streaming/rearrival, older-world restore, full lifecycle, physical devices, online durability, performance, release rebuilding/publication and laptop synchronization remain open. Nothing published; goal active.

'''
for rel,marker in [('docs/audit/CURRENT.md','Earlier status below is historical.'),('chet/save-continue.md','Earlier status below is historical.'),('docs/save-continue/README.md','Earlier status below is historical.')]:
 p=ROOT/rel;text=p.read_text(encoding='utf8');assert marker in text
 p.write_text(status+text[text.index(marker):],encoding='utf8',newline='\n')
p=ROOT/'docs/audit/current-source/requirements.json';r=json.loads(p.read_text(encoding='utf8'))
r['as_of_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
for row in r['requirements']:
 if row['id']=='cli-and-runner':
  row.update(status='linux-and-native-verified-windows-running',evidence_boundary='Current032926f: independent5/0, garden256706/0, compile222/strict/runner5 pass. Linux39868843334 completed76/465388/0. Studio22 assertions/all225 fingerprints/zero CreatorErrors pass after correcting a no-prey fixture; first failed attempt retained. Current Windows7806 active. Prior e51 Windows/Linux76/465383/0 both terminal and historically verified.')
  row['references']=['docs/prey-stream-readiness/README.md','docs/prey-stream-readiness/ci-final.json','docs/prey-stream-readiness/native-receipt.json']
r['latest_readiness_milestone']['status']='cached-prey-linux-native-verified-windows-running'
r['legacy_world_policy']={'selected':'import-progress-into-preserve-with-complete-immutable-source-archive','user_delegated':True,'implemented':False,'design':'docs/save-slot-isolation/migration-design.md'}
p.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
# Refresh the private probe compilation hash after the fixture correction.
p=HERE/'probe-compile.json';rows=json.loads(p.read_text(encoding='utf8'))
rows[0]['sha256']=hashlib.sha256((ROOT/rows[0]['path']).read_bytes()).hexdigest()
p.write_text(json.dumps(rows,indent=2)+'\n',encoding='utf8',newline='\n')
print('Updated handoffs: Linux/native verified, Windows pending, migration policy chosen.')
