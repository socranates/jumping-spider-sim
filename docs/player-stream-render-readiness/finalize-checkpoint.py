"""Record terminal full-gate evidence without closing the broad optimization goal."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
full=json.loads((H/'full-verification.json').read_text(encoding='utf8'));candidate=json.loads((H/'production-candidate.json').read_text(encoding='utf8'))
source=full['source'];assert source==candidate['source']=='695e772d9d1ece490dd32132c655ac60c226c7b8'
assert full['windows_failed']==full['linux_failed']==0 and full['native_actual_client_scripted_checks']==60
assert hashlib.sha256(Path(candidate['place']).read_bytes()).hexdigest()==candidate['place_sha256']
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==source
p=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(p.read_text(encoding='utf8'))
d.update(as_of_utc=datetime.now(timezone.utc).isoformat(),source=source,current_working_source=source,last_both_platform_full_source=source,goal_complete=False,published=False)
for row in d['requirements']:
 if row['id']=='cli-and-runner':
  row['status']='both-platforms-verified-bounded-native-hold-passed'
  row['evidence_boundary']='Current695e772: Windows95994 terminal exit0 and Linux39957397842 terminal success; each76/468866/0, compile222, clean strict, runner5. Immutable inputs/log hashes and both platforms twelve-quarter-tick wait regression verified. Native actual-client full-detail scripted fixture60/0 with223 fingerprints passes; not a full natural-life, online service/rejoin or release proof.'
  row['references']+=['docs/player-stream-render-readiness/full-verification.json']
 if row['id']=='repo-and-handoff':
  row['evidence_boundary']='Current695e772 pushed on codex/save-continue; both full76/468866/0 platform gates, compile222/strict/runner5, bounded native60/0 and exact222-source no-diagnostic candidate verified. Private recovery component187257/0 remains byte-identical with current34-candidate overlay types. Engine-streaming experiment prepared separately; actual game recovery menu/profile/model adoption, replacement epochs and native/online/release remain open. Original OneDrive and unrelated edits preserved; nothing published.'
d['latest_player_stream_fix'].update(full_gates='both-platforms-verified',windows_exit_code=0,linux_conclusion='success')
d['latest_player_stream_full_gates']=full;d['latest_player_stream_production_candidate']=candidate
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
note='''Current production source695e772d9d1ece490dd32132c655ac60c226c7b8 is now verified on both full platforms:76 suites,468866 checks,0 failures each;222 compiles, clean strict and5 runner regressions. Windows95994 is terminal exit0 (1097.8seconds), Linux39957397842 terminal success. Both logs include the twelve-quarter-tick waiting-flag regression. Full immutable source/log proof is docs/player-stream-render-readiness/full-verification.json. Do not restart these completed gates. The actual-client full-detail Studio fixture passes60/0,223 checked fingerprints,0 CreatorErrors during the fixture; stopped/closed, original unchanged, editor copy saved separately. Its scripted collision removal/partial return/resume/repeat/menu/projected tests are bounded; natural network pressure, physical devices, whole life and online/recovery are not claimed. Private recovery executable/all explicit inputs are unchanged from257e1a4's187257/0 component execution, and current34 overlay types pass; see private-unchanged.json.

The exact-source diagnostic-free candidate is C:/Users/natha/claude-xfer/Windowsill-production-695e772/TheWindowsill-production-candidate.rbxlx,222 scripts,SHA2565fa12d465ace029007cd3585f7a545f1685a3266fef5e29c711e9001d1305ae1. It is not a published or verified normal online production-client session. No main merge/publication. A separate saving-disabled Default engine-streaming model is prepared at C:/Users/natha/claude-xfer/Windowsill-engine-stream-695e772-full-default/Windowsill-engine-stream-695e772-full-default.rbxlx; see engine-full-default-prepared.json. Next observe actual production WorldFocus-driven Atomic garden_b4 -> deck_n4 -> return without collision parenting; if the engine retains the model, explicitly record stream-out as not observed. This is stronger evidence to pursue, not an executed pass yet. Later recovery menu/profile/model adoption, explicit replacement epochs, payload budgets, natural-life/performance/device/online/release gates remain open. Broad goal active; preserve original OneDrive, unrelated three save-cost outputs and production sourcemap.
'''
handoff=ROOT/'chet/save-continue.md';old=handoff.read_text(encoding='utf8');assert not old.startswith('# Latest checkpoint - player collision gates complete')
handoff.write_text('# Latest checkpoint - player collision gates complete, 2026-10-23\n\n'+note+'\n'+old,encoding='utf8',newline='\n')
with (ROOT/'RESUME-AFTER-RESTART.md').open('a',encoding='utf8',newline='\n') as f:f.write('\n\n## Player collision hold fully qualified on both platforms - 2026-10-23\n\n'+note)
print('Recorded both-platform success, bounded native evidence and candidate; goal remains active')
