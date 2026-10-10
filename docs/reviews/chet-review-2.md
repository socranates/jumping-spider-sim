# Jumping Spider Sim — Movement and silk review

**From:** Chet · **For:** Nathan and Claude · **Date:** October 7, 2026  
**Scope:** chunk 5 / T04–T05 handback, current source, recorded test evidence, capture frames, and Nathan's latest play feedback.

## Decision

Accept this as the first movement-and-silk milestone. Continue toward T06 perception after a small, bounded review of recovery presentation. Preserve the controls Nathan likes; a general camera or locomotion rewrite is unnecessary.

**Keep the longer jumps as the current playtest default.** Nathan's latest feedback is:

> the controls and camera are great, I love the longer jumps

That supersedes my provisional suggestion, made before seeing this handback, to start closer to the original 2–5-body-length range. The original numbers were hypotheses; direct player feedback is a good reason to revise them. Long jumps remain an explicit gameplay abstraction pending biological review.

This is a review document for Nathan to pass to Claude. The original OneDrive project was inspected read-only. Review tests run from a separate copy in Chet's workspace. No gameplay changes or edits to the project's decision ledger were made here.

## 1. Evidence and limits

- Read `docs/HANDOFF.md`, `docs/DECISIONS.md`, the species data, relevant motor/input/camera/tether/presentation code, and test/report code.
- Inspected the twelve-frame capture sheet and the individual hanging screenshot. The capture shows a recoverable miss, hanging, reeling, and reattachment. It also shows a crowded camera view immediately after the catch and at the grab.
- The scripted camera changes in that capture prevent a conclusion about how long the crowded view lasts with ordinary input. Nathan reports that the camera feels great; preserve that as actual player evidence.
- Did not interactively play the build or watch the entire video. Frame inspection does not establish timing comfort, sound, input latency, or physical-controller ergonomics.
- Independently ran the current test suite on native Windows in an isolated review copy. Final results are recorded below.

### Independent Windows verification

**209 tests passed; 0 failed; 0 not run in the existing automated suite.** Native Windows Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility renderer setting, Jolt Physics, headless, default seed `20261005`. The process exited successfully. Report timestamp: `2026-10-07T06:24:11Z` (October 7, 1:24 a.m. Central).

The runner's source fingerprint was `c4c8b7253541e38098469193f323e18c`, matching the handback's scripts/scenes/data snapshot. Command: the native Windows executable with `--headless --path <review-copy> res://tests/test_runner.tscn`, using isolated application-data folders.

```text
SUMMARY tests=209 passed=209 failed=0 not_run=0 seed=20261005 filter=all result=PASS
```

| Check | Independently observed result |
|---|---|
| M01 traversal | 20 of 20 routes passed. |
| M02 landing prediction | 100 of 100 legal jumps passed; maximum contact error 0.0200 WU. |
| M02 refusal feedback | 8 of 8 invalid candidates refused with feedback. |
| M03 silk recovery | 10 of 10 fixtures passed within the documented energy/tolerance allowances. |
| Remaining automated regression suite | Passed, including input, camera geometry, supported locomotion, and tether behavior checks. |
| Full M04 display/camera gate | Still incomplete: this run was headless and the final slice does not yet exist. |
| Performance, physical controller, human experience gates | Not established by this automated run. Nathan's quoted feedback is separate player evidence. |

Evidence files in Chet's workspace:

- Full console log: `review_windows_tests_2026_10_07.log`.
- Runner report: `review_snapshot_2026_10_07/tests/reports/last_report.txt`.
- Gate reports: `review_snapshot_2026_10_07/tests/reports/m01_report.txt`, `m02_report.txt`, `m03_report.txt`.

The supplied Downloads specification and the project's frozen `docs/SPEC.md` have matching SHA-256 hashes. The initial editor-import attempt encountered sandbox restrictions on Godot's global cache/config folders. Runtime testing used redirected, isolated application-data folders. A Windows certificate-store error was emitted at engine startup; the suite itself passed. Deliberate malformed-settings tests and the forced solver-fallback test also emitted their expected diagnostics. Do not describe this as an entirely diagnostic-free launch or a graphical performance test.

## 2. Answer: what should a miss cost?

**Keep automatic safety lines and recovery free of resource charges in P0. Keep the current reel rate as the baseline.**

A miss already costs something: the player loses position, spends time recovering, gives up a route or hunting opportunity, and may need another attempt. A new meter is unnecessary to make that consequence real. Do not add a forced wait, an energy fee, or a silk penalty merely because the solver works reliably.

When prey arrives, the opportunity can change while the spider recovers. Later predators and weather can create genuine exposure. Those consequences should come from the same world systems affecting other actions, not a special punishment attached to missing.

Clarify the terminology: the current line has **unlimited reserve**, but its length is bounded by tuning. It is not an infinitely long tether. Keep maximum length, local anchoring, collision handling, snag limits, and release protection.

The 1.5 WU/s reel rate is a reasonable starting point and Nathan has not reported a problem with it. At long lengths, recovery may become tedious; measure actual recovery durations and observe player behavior before changing it. If later needed, modest easing or an accessible faster-recovery option can help. Do not add input delay or rapid tapping to make it feel like effort.

For P1, consider modest effort/energy costs only after needs and ecology work together. Protect learning and basic return-to-safety from resource deadlocks. A missed jump should often produce a memorable recovery, not force a restart because the last unit of silk was consumed.

## 3. Answer: are eleven-body-length leaps right?

**Retain the current 20 WU/s launch limit, 0.9 s maximum flight duration, and 100% reach setting as the working baseline.** Keep the reach slider as a clearly labeled playtest/assistance setting for now. Do not retune the default downward in the next chunk.

Nathan asked for farther jumps and now says he loves them. The correct next question is whether the habitat offers interesting choices at that range. An undersized lab does not establish that a satisfying move is wrong.

Design the first habitat to contain:

- Short precise hops and near landings that remain useful even with a longer maximum range.
- Occasional long, clearly framed gaps where the new capability feels good.
- Occluded routes, walls, undersides, and offset landing geometry that a single long leap cannot bypass.
- Sheltered approaches versus exposed direct routes, so jumping farther does not replace looking or stalking.
- A readable scale through landmarks and material details; do not simply enlarge every gap until all jumps are maximum-distance jumps.

The maximum envelope is not a normal stride. Feeding, prey awareness, cover, and target movement should create reasons to reposition carefully. Longer reach must not become automatic capture range or let the spider inspect across occluders.

Keep the tuning labeled as designed rather than measured. Verify reach-slider combinations against line length, preview validation, and landing feedback when those combinations change. Add new fixtures only for new configurations or failures; the existing default does not need endless repeated tests.

## 4. Answer: what should the catch look and feel like?

**The line should be clearly readable. Keep the stable physics and add life through presentation.**

A safety line is a physical object and a tool the player uses. Showing it does not violate the preference against drawn navigation routes. The player should understand where it attaches, where it bends, what is holding them, and why reeling stops.

### Camera

Preserve the current orbit controls and horizon stability. Investigate the specific cliff-cap catch/grab sequence with **no scripted camera input**. Measure the crowded view rather than assuming a global problem.

If it persists, find a collision-safe view that includes the spider, the nearby lip, and a useful visible segment of silk. A small temporary change of pivot or viewing angle may work better than a large zoom. Player look input must retain control. Do not pull the camera through terrain to achieve the desired composition, and do not force a dramatic roll or cinematic orbit.

The falling scene should be readable, but Nathan's positive camera feedback makes this a targeted polish task rather than a blocker requiring a redesign. If ordinary play is already clear, retain the behavior and record the measured result.

### Silk visibility

The pale strand is readable against purple and can disappear against pale backgrounds. Try a restrained contrast treatment and a minimum visible screen thickness, especially while taut or reeling. Keep true geometry occlusion; a strand hidden by the lip should not become an unexplained X-ray line.

A small attachment cue or concise HUD message can explain the hidden anchor. Distinguish active load-bearing silk from fading old silk. Avoid a thick glowing rope as the only presentation. Accessibility may offer stronger contrast or a simplified cue.

### Body and catch response

Keep the settled physics body exactly still if that is what prevents numerical drift. Add any tiny settling motion, leg adjustment, or inspection pose to a cosmetic child rig. Do not reintroduce real oscillation just to make the animal look alive. Pose offsets must stay small enough that feet and the visible silk endpoint remain believable.

A modest body recoil or pose change can announce the catch. Camera shake should be optional and off by default; sound and visual cues can communicate the same event. No need to make a soft successful safety catch feel like an injury.

Do not make full leg IK, a complete gait, sound production, or a sophisticated elastic rope prerequisites for T06. A minimal prepared/airborne/hanging pose pass can happen later without changing the solver.

## 5. Technical and documentation notes

### Correct the units in M03 reporting

Under the spec's **1 WU = 1 cm** contract, **1 WU = 10 mm**. The M03 report's `worst_lift * 1000.0` conversion and the comments describing `CONTACT_LIFT_MAX = 0.002` as 2 mm use a meter-scale assumption.

The current numeric cap corresponds to **0.02 mm**, not 2 mm. A `0.001` WU collision margin corresponds to 0.01 mm. Correct the conversion, commentary, and handback descriptions together. Preserve the WU tolerances unless a separate measured issue warrants retuning; this is a reporting correction, not a reason to change the physics by a factor of 100.

Relevant locations: `tests/integration/test_m03_tether.gd` (report header and fixture-detail conversion), `tests/tether_test_case.gd` (contact-lift comment), and M03/handback prose.

### Describe the energy gate precisely

The check permits reel work, bounded seating work, measured contact recovery, and numerical tolerance. Keep that disclosure. “No unexplained energy gain within the documented allowances” is a more accurate summary than an unqualified conservation claim.

The shared discrete jump solver is a good implementation choice. Matching prediction to runtime integration is preferable to following the specification's illustrative continuous formula literally. Preserve its accuracy. The fact that a stationary legal landing works reliably does not remove tension: target movement, information, and commitment can provide it.

### Keep evidence attached to its build

The existing source hash covers scripts, scenes, and data. Future handbacks should also identify project settings and the test snapshot, since backend settings and test revisions affect interpretation. A local source-control commit or complete archive would make this straightforward. No remote service is required.

Record the longer-jump tuning as superseding D-014, and record the approved line behaviors that are currently only proposed in the session log. Keep the frozen spec intact. Add Nathan's latest quote as new dated feedback rather than implying he supplied it at the earlier handback date.

## 6. Next chunk for Claude

The implementation goal is **a brief recovery-readability check followed by T06 perception**. Do not turn the presentation check into another broad movement milestone.

1. Record this review's accepted decisions and Nathan's feedback. Correct the M03 unit reporting. Retain reach, solver, reel speed, release protection, and current controls.
2. Reproduce the specific cliff-cap catch/grab without camera automation. Record how long the view is crowded; fix only if it obscures the recovery choices. Check the active line against light and dark backgrounds. If code changes, run the relevant camera/tether regressions.
3. Implement T06 with a moving, labeled test target behind an occluder. The real fly brain still belongs to T07. Do not prematurely write a prey AI merely to demonstrate perception.
4. Establish world truth → sensed observation → memory → presentation. Turning the third-person camera must not by itself rotate the spider's inspection cone. Occlusion prevents live updates. A last-seen mark remains at its last observation and expires or is invalidated when the location is inspected empty.
5. Demonstrate P01 with visible motion, forward inspection, loss of sight, a stale mark, and reacquisition. Any gaze overlay remains optional and should reveal no hidden targets.

**Hand back:** changed files, tested/not-tested status, a short perception demonstration if available, the camera-check result, and the remaining issues. T07 can follow after the observation contracts are verified.

## Suggested ledger entries

- **Long-jump tuning accepted for continued P0 playtesting:** current default retained in response to Nathan's positive feedback; original launch tuning superseded. Biological validity remains unverified.
- **P0 safety-line reserve remains free:** misses cost position, time, and changing opportunities; no artificial resource penalty introduced.
- **Catch presentation favors legibility:** collision-safe, horizon-stable camera; visible active silk; optional cosmetic body motion; solver unaffected.
- **Settled physical body may remain static:** living motion is cosmetic and must not create drift or alter sensing unintentionally.
- **M03 report unit conversion corrected:** 10 mm per WU; existing numerical tolerances preserved pending evidence.

The next distinctive moment should be the spider noticing something, losing sight of it, and finding out whether its expectation was right. Movement now provides a useful foundation for that.
