from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
dest=ROOT/'docs/pond-drawing-reuse';dest.mkdir(exist_ok=False)
for name in ['full.py','check.py','locate-ci.py','fetch-ci.py']:
 text=(ROOT/'docs/spatial-save-validation'/name).read_text(encoding='utf8')
 text=text.replace("SOURCE='59146e1005c083330455379766ab8c9dd2de2705'","SOURCE=__import__('subprocess').check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=HERE.parents[1],text=True).strip()")
 text=text.replace('465412','468114').replace('spatial-validation CI run','pond-drawing CI run')
 (dest/name).write_text(text,encoding='utf8',newline='\n')
(dest/'focused.txt').write_text('BODIES passed=3610 failed=0\n',encoding='utf8',newline='\n')
(dest/'README.md').write_text('''# Pond drawing reuse, unpublished

Production PondBodies now matches the exact b2fdc562 candidate tested against the frozen 59146e1 geometry. It retains each rig's bulk-move buffers and invariant frog/darner recipes; breathing, tongue reach, visibility and movement still update each draw. No simulation, audio, lighting or control changes.

The primary isolated native benchmark passed41 assertions/all224 source fingerprints/zero CreatorErrors. CPU fell18.13 percent at full and21.32 percent at low, with4/4 pairs faster in both tiers. Positive heap growth fell88.60/92.45 percent; that is neither an allocation-rate nor leak measurement. Separate native geometry checks passed985. These are component measurements, not whole-game FPS or physical-device evidence. Both diagnostic windows were closed and original package hashes restored. Exact outputs and closures remain in ../animal-presentation-cost; the earlier marginal candidate was rejected and its results retained.

The default bodies suite includes2702 frozen-reference regressions, bringing it to3610/0. Full Windows/Linux checks for the newly committed source remain pending; do not reuse the older source's465412 checks as current proof. Expected new total468114 across76 suites is an expectation until terminal logs verify it. Run full.py once, check.py once, locate-ci.py then fetch-ci.py when the existing push run completes. No duplicate jobs.

The save-validator source59146e1 completed both platforms76/465412/0, compile222, strict and runner5, plus native20. Its pinned historical verifier remains in ../spatial-save-validation. Save migration policy is resolved (portable progress into Preserve, complete original save untouched in archive), but implementation remains pending. Nothing published. Broader audit remains active.
''',encoding='utf8',newline='\n')
old=ROOT/'docs/spatial-save-validation/README.md'
text=old.read_text(encoding='utf8').replace('Current immutable Windows full58767 is active; expected76/465412 is not a completed Windows result. Root verifier still refuses its pending gate.','Windows58767 completed76 suites/465412/0. The pinned source-bound verifier passes all platform/native gates. This source is now historical after the separate pond drawing adoption.')
text=text.replace('Next gate: finish current Windows58767, run verify.py, then update source-bound handoffs. Do not restart the live process.','All jobs in this source cohort are terminal. Its verifier remains pinned to59146e1 and reports whether the workspace still matches.')
old.write_text(text,encoding='utf8',newline='\n')
note='''# Latest: pond drawing reuse adopted; full gates pending

The tested b2fdc562 renderer is now in production source, unpublished. Pond drawing component CPU decreased18.13/21.32 percent (full/low), with identical checked geometry. Default bodies3610/0 includes2702 frozen-reference regressions. Full Windows/Linux checks for this new source are pending; expected468114 is not a completed result. The older59146e1 save-validator source completed465412 on each platform and native20. Its proof remains historical and pinned. See docs/pond-drawing-reuse/README.md for scope and gates. No whole-game FPS claim; no publication. Legacy save migration is still pending. Broader goal remains active.

Earlier status below is historical.

'''
for name in ['docs/audit/CURRENT.md','docs/save-continue/README.md','chet/save-continue.md']:
 path=ROOT/name;path.write_text(note+path.read_text(encoding='utf8'),encoding='utf8',newline='\n')
p=HERE/'POND-TRIAL.md'
p.write_text(p.read_text(encoding='utf8')+'''\n## v2 adoption result

Isolated batches1792715775354 passed41/all224/zero CreatorErrors. Both tiers meet the original thresholds: CPU18.125/21.321 percent lower, positive heap growth88.603/92.449 percent lower,4/4 pairs faster each. Native geometry985 is separate. Both v2 windows stopped/saved/closed/exited; original diagnostic bytes restored. adopt-pond-v2.py checked exact hashes/guards/closures and adopted b2fdc562, retaining the frozen baseline and2702 default regressions. Bodies now3610/0. Historical private receipts keep adopted=false to describe their trial-time state; adoption.json records the subsequent decision. New full gates pending. No whole-game FPS, leak, physical-device or published-release claim.
''',encoding='utf8',newline='\n')
print('Prepared new source cohort gates and status; production change already separately tested.')
