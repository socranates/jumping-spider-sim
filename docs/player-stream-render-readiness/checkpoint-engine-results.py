from pathlib import Path
from datetime import datetime,timezone
import json
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
r=json.loads((H/'engine-verification.json').read_text(encoding='utf8'))
assert r['opportunistic_checks']==25 and r['player_hold_frames']==4 and r['default_stream_out_observed'] is False
p=ROOT/'docs/audit/current-source/requirements.json';d=json.loads(p.read_text(encoding='utf8'))
assert d['source']==r['source'];d['as_of_utc']=datetime.now(timezone.utc).isoformat()
for row in d['requirements']:
 if row['id']=='network-streaming':
  row['status']='controlled-engine-stream-out-verified-default-pressure-and-low-open'
  row['evidence_boundary']='Current695e772: bounded scripted native60/0 plus actual engine/production WorldFocus native25/0 under a separate Opportunistic-policy full-detail/Free-play fixture. Engine removed Atomic garden_b4 while at deck_n4, the player retained position/velocity/mode and life/needs/prey clocks through4 Heartbeat observations, then complete collision resumed the same life/motor. Default-policy11/0 retained the model throughout45seconds; no default-pressure stream-out proof. Each fixture223 script fingerprints,0 CreatorErrors; original models/editor copies preserved, Studio closed. No collision parenting in either engine probe. Low detail, Normal energy, natural network/memory pressure, complete swept paths and physical devices remain open. Production streaming policy is unchanged.'
  row['references']+=['docs/player-stream-render-readiness/ENGINE-RESULTS.md','docs/player-stream-render-readiness/engine-verification.json']
 if row['id']=='performance-A08':
  row['evidence_boundary']+=' Current695e772 controlled full-detail/Free-play garden sample after engine return:120 RenderStepped intervals at1105x433, mean16.676ms/p9518.193ms/max18.991ms. Short foreground diagnostic scene, not a paired gain or whole-game/device/long-session claim.'
  row['references']+=['docs/player-stream-render-readiness/engine-full-opportunistic-receipt.json']
 if row['id']=='repo-and-handoff':
  row['evidence_boundary']=row['evidence_boundary'].replace('Engine-streaming experiment prepared separately;','Engine streaming now observed under diagnostic Opportunistic policy (25/0); Default11/0 retained collision for45seconds;')
d['latest_engine_streaming']=r
d['latest_player_stream_fix'].update(controlled_engine_stream_out_verified=True,engine_policy='Opportunistic diagnostic only',engine_checks=25,engine_held_heartbeat_observations=4,default_policy_stream_out_observed=False,low_detail_native_verified=False)
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
note='''Production695e772 remains unchanged and fully qualified on both CLI platforms76/468866/0, compile222/strict/runner5, scripted native60/0. Windows95994 and Linux39957397842 are terminal successes; do not rerun them. The exact222-source diagnostic-free candidate remains Windowsill-production-695e772/TheWindowsill-production-candidate.rbxlx (SHA2565fa12d465ace029007cd3585f7a545f1685a3266fef5e29c711e9001d1305ae1), not published or verified as a normal online production-client session.

New actual-engine evidence: using production WorldFocus, Atomic garden_b4 -> deck_n4 -> return, without collision parenting. Default-policy fixture passes11 checks but retains the garden throughout45seconds, so default-pressure stream-out remains unverified. Separate Opportunistic-policy diagnostic passes25 checks: engine removes collision, player holds position/velocity/mode and life/needs/prey clocks through4 Heartbeat observations, complete collision returns and the same life/motor resume. Each has223 checked script fingerprints and0 CreatorErrors during the running fixture. Current verifier/proof: docs/player-stream-render-readiness/verify-engine-stream.py and engine-verification.json; detailed scope ENGINE-RESULTS.md. Both use full detail/Free play; no Normal energy claim. The120-frame garden sample is16.676ms mean/18.193ms p95/18.991ms max at1105x433, not whole-game FPS or a paired gain. First preflight failed before Play on a non-scriptable streaming-radius read; corrected builder checks serialized XML and enum values. Old preflight/model/probe and all originals/editor copies are preserved. Both actual experiments are stopped/closed; Studio is closed, all CLI processes terminal. Production streaming policy is unchanged.

Next run low-detail native collision coverage and an explicit Normal energy-hold case, then continue actual recovery menu/profile/model adoption and explicit replacement epochs. Do not edit the current full-detail engine probe in place: its exact bytes bind the completed receipts; use a separate variant if extending it. Private recovery component187257/0 remains byte-identical with current34-candidate overlay types; actual engine recovery remains uninstalled. Natural default-network/memory pressure, whole life, sustained performance, physical devices, audio, online/rejoin and release remain open. Goal active; no main merge/publication. Preserve original OneDrive checkout, three unrelated save-cost outputs and production sourcemap.
'''
handoff=ROOT/'chet/save-continue.md';old=handoff.read_text(encoding='utf8');assert not old.startswith('# Latest checkpoint - real engine stream-out')
handoff.write_text('# Latest checkpoint - real engine stream-out, 2026-10-23\n\n'+note+'\n'+old,encoding='utf8',newline='\n')
with (ROOT/'RESUME-AFTER-RESTART.md').open('a',encoding='utf8',newline='\n') as f:f.write('\n\n## Actual engine streaming verified under diagnostic policy - 2026-10-23\n\n'+note)
print('Updated evidence and open requirements; broad goal remains active')
