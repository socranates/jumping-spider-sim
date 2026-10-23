"""Record the completed native milestone and live immutable full-gate handles."""
from pathlib import Path
from datetime import datetime,timezone
import json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
source='695e772d9d1ece490dd32132c655ac60c226c7b8'
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==source
native=json.loads((H/'native-full-receipt.json').read_text(encoding='utf8'));assert native['test_passed'] and native['checks']==60 and native['studio_closed']
start=json.loads((H/'windows-full-start.json').read_text(encoding='utf8'));assert start['source']==source
path=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(path.read_text(encoding='utf8'))
d.update(as_of_utc=datetime.now(timezone.utc).isoformat(),source=source,current_working_source=source,goal_complete=False,published=False)
d['last_both_platform_full_source']='257e1a43ae00076a6e59f284c0f2ca0ff09f72e9'
for row in d['requirements']:
 if row['id']=='cli-and-runner':
  row['status']='current-native-passed-full-platform-gates-running'
  row['evidence_boundary']='Current695e772: 222 compiles, clean strict, runner5; focused client43/0 including twelve quarter-tick render holds. Current immutable Windows95994 and Linux39957397842 are live, expected76/468866/0; no final full pass yet. Previousbf94f9d Linux76/468866/0 is historical and native diagnostic exposed a waiting-flag flicker. Last both-platform full source257e1a4 passed76/468859/0. Current native scripted client fixture60/0 is bounded, not release qualification.'
  row['references']+=['docs/player-stream-render-readiness/README.md','docs/player-stream-render-readiness/checks.json','docs/player-stream-render-readiness/windows-full-start.json','docs/player-stream-render-readiness/ci-start.json']
 if row['id']=='network-streaming':
  row['status']='player-hold-scripted-native-verified-real-network-open'
  row['evidence_boundary']='Source695e772 retains player pose, velocity, simulation objects and life/needs/prey clocks when authored collision disappears; partial return refuses, whole return resumes, repeated removal and menus while waiting are tested. Native60/0 checks223 exact fingerprints in an unbound persistence-disabled full-detail model, including projected airborne refusal and thirty stable subsequent frames. Earlierbf94 diagnostic proved no motion but a false cleared loading flag between ticks; per-render destination check fixes that. CLI43/0 includes twelve quarter-tick renders. This deliberately removes local collision folders; natural server/network streaming pressure, low-detail natural traversal, the complete swept path and device/performance proof remain open. Earlier creature/prey evidence is retained separately.'
  row['references']+=['docs/player-stream-readiness/native-attempt-2-receipt.json','docs/player-stream-render-readiness/native-full-receipt.json','docs/player-stream-render-readiness/native-full-output.txt']
 if row['id']=='native-life-loop':
  row['evidence_boundary']+=' Current695e772 full-detail actual-client fixture passes60 scripted checks including preceding controlled HUD/animal assertions and collision hold/cadence; it is not a naturally played full life or online recovery proof.'
 if row['id']=='repo-and-handoff':
  row['references']+=['docs/player-stream-render-readiness/README.md']
d['latest_player_stream_fix']=dict(source=source,focused_checks=43,focused_failures=0,native_checks=60,native_failures=0,native_script_fingerprints=223,native_detail='full',native_collision_folder_manipulation=True,native_real_network_pressure=False,whole_game_verified=False,windows_exec_handle=95994,linux_run=39957397842,full_gates='running',published=False)
if 'latest_player_stream_counterexample' in d:d['latest_player_stream_counterexample']['fixed']=True;d['latest_player_stream_counterexample']['fix_scope']='Specific known-region collision hold; see latest_player_stream_fix, real network pressure remains open'
d['latest_private_recovery_component_reuse']=json.loads((H/'private-unchanged.json').read_text(encoding='utf8'))
path.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
note='''Player collision hold milestone: source `695e772d9d1ece490dd32132c655ac60c226c7b8`, pushed on `codex/save-continue`. Actual-client baseline257e1a4 fell when an arrived floor disappeared. First fixbf94f9d holds physics/clocks, but native diagnostic found its waiting flag cleared between fixed ticks (zero motion, zero velocity/life/needs change, loading=false). Current per-render destination check corrects that without motor/input/camera changes. CLI focused43/0 includes twelve quarter-tick renders; current222 compile, clean strict and runner5 pass. Current actual-client Studio full-detail fixture passes60/0 with223 checked fingerprints, zero CreatorErrors during the fixture, saving disabled and PlaceId0. Complete/partial return, retained objects, repeat disappearance, menu access and projected refusal/stable follow-up are included. Original model unchanged, editor copy saved separately; Studio stopped/closed. See docs/player-stream-render-readiness/README.md and native-full-receipt.json. This is deliberate local folder manipulation, not real server-driven network pressure, natural life, physical input or performance proof.

Current immutable full Windows exec95994 and existing Linux push run39957397842 are live, expected76 suites/468866/0. Poll these handles; do not restart or claim current full success until terminal receipts pass verify-gates.py. Then build-production.py creates the separate exact-source no-diagnostic candidate; no publication/main merge is authorized at this checkpoint. Previousbf94 Linux76/468866/0 is historical, and257e1a4 remains last both-platform full pass. Private recovery executable bundle/all explicit inputs are byte-identical to257e1a4's187257/0 component run; current34 overlay types pass (private-unchanged.json). This is component evidence reuse, not new whole-game recovery proof. Menu/profile/model adoption, replacement epochs, payload budgets, native/online/rejoin/release remain open. Broader goal active. Preserve original OneDrive checkout, three unrelated save-cost outputs and untracked production sourcemap.
'''
handoff=ROOT/'chet/save-continue.md';old=handoff.read_text(encoding='utf8');assert not old.startswith('# Latest checkpoint - player collision hold')
handoff.write_text('# Latest checkpoint - player collision hold, 2026-10-23\n\n'+note+'\n'+old,encoding='utf8',newline='\n')
resume=ROOT/'RESUME-AFTER-RESTART.md'
with resume.open('a',encoding='utf8',newline='\n') as f:f.write('\n\n## Player collision hold and render-cadence correction - 2026-10-23\n\n'+note)
print('Checkpoint records native success and pending full gates without a release claim')
