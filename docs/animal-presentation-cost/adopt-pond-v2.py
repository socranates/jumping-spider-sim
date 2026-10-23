"""Adopt only the exact privately tested pond candidate after all declared gates."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'pond-candidate-v2.json').read_text())
candidate=(HERE/'pond-candidate-v2.luau').read_bytes()
reference=(HERE/'pond-reference.luau').read_bytes()
assert sha(candidate)==m['candidate_sha256'] and sha(reference)==m['reference_sha256']
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==m['source']
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
for kind,assertions in [('native',985),('batch',41)]:
 manifest=json.loads((HERE/('prepared-pond-v2'+('-batch' if kind=='batch' else '')+'-manifest.json')).read_text())
 receipt=json.loads((HERE/f'pond-v2-{kind}-receipt.json').read_text())
 close=json.loads((HERE/f'pond-v2-{kind}-close.json').read_text())
 assert receipt['source']==manifest['source']==m['source']
 assert receipt['assertions']==assertions and receipt['scripts']==224 and receipt['creator_errors']==0
 assert receipt['persistence_disabled'] and receipt['place_sha256']==manifest['place_sha256']==close['original_restored_sha256']
 assert close['playback_stopped'] and close['place_closed'] and close['diagnostic_window_closed']
 assert sha((HERE/f'pond-v2-{kind}-output.txt').read_bytes())==receipt['output_sha256']
 scripts={row['path']:row['sha256'] for row in manifest['scripts']}
 assert scripts['StarterPlayer.StarterPlayerScripts.Client.PondCandidate']==sha(candidate)
 assert scripts['StarterPlayer.StarterPlayerScripts.Client.PondBodies']==sha(reference)
 assert scripts['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']==sha((HERE/f'pond-v2-{kind}-probe.luau').read_bytes())
 if kind=='batch':assert receipt['adoption_criteria_met']
eq=json.loads((HERE/'pond-v2-equivalence.json').read_text());existing=json.loads((HERE/'pond-v2-existing.json').read_text())
assert eq['exit_code']==existing['exit_code']==0 and eq['candidate_sha256']==existing['candidate_sha256']==sha(candidate)
assert sha((HERE/'pond-v2-equivalence.luau').read_bytes())==eq['test_sha256']
assert 'passed=2702 failed=0' in (HERE/'pond-v2-equivalence.txt').read_text()
assert 'BODIES passed=908 failed=0' in (HERE/'pond-v2-existing.txt').read_text()
assert all(row['exit_code']==0 for row in json.loads((HERE/'pond-v2-types.json').read_text())['steps'])
target=ROOT/m['path'];assert target.read_bytes()==reference
fixture=ROOT/'roblox_port/tests/studio/LegacyPondBodies.luau';assert not fixture.exists()
test=ROOT/'roblox_port/tests/bodies.luau';body=test.read_text(encoding='utf8')
marker='print(`BODIES passed={passed} failed={failed}`)';assert body.count(marker)==1
addition=(HERE/'pond-v2-equivalence.luau').read_text(encoding='utf8')
addition=addition[addition.index('local Reference='):]
addition=addition.replace('local Reference=__pondReference','local Reference=require("./studio/LegacyPondBodies")').replace('local Candidate=__pondCandidate','local Candidate=PondBodies')
addition=addition.replace('local checks=0\nlocal function check(ok,why) assert(ok,why);checks+=1 end\n','')
addition=addition[:addition.index('print("POND_EQUIVALENCE')]
addition=addition.replace(' ok,why=same(a,b);check(ok,"reappearance "..why)\nend',' ok,why=same(a,b);check(ok,"reappearance "..why)\n a.folder:Destroy();b.folder:Destroy();other.folder:Destroy()\nend')
assert 'a.folder:Destroy()' in addition
fixture.write_bytes(reference);target.write_bytes(candidate)
test.write_text(body.replace(marker,'case("pond reuse preserves the frozen geometry and owns its buffers", function()\n'+addition+'end)\n\n'+marker),encoding='utf8',newline='\n')
(HERE/'adoption.json').write_text(json.dumps(dict(baseline_source=m['source'],candidate_sha256=sha(candidate),reference_sha256=sha(reference),native_equivalence_assertions=985,batch_assertions=41,default_regressions_added=2702,adopted=True,current_full_gates_pending=True,published=False),indent=2)+'\n',encoding='utf8',newline='\n')
print('Exact tested pond candidate adopted; current full gates pending.')
