# Jumping Spider Sim — chunk 8 handoff

Implemented by Chet on 2026-10-10 at Nathan’s request. Nathan explicitly authorized coding in the previously read-only project and said, “I am satisfied with all the mechanics so far.” This handoff is for either Claude or Chet to continue from the files when usage limits require a switch.

## Build and decision

Evidence ID: **182235d71390**. Source prefix `3a567f74`, settings prefix `8b6707d4`, tests prefix `e42dda6d`. The full hashes and final verification are in the matching reports and snapshot. Documentation is not part of the identity.

T08 now has a playable authored windowsill, both routes, a physical retreat, visual onboarding/help, a harmless shadow encounter, and the chunk-7 capture-memory and performance-report corrections. **Preserve the approved mechanics.** Do not restart this implementation from the conversation or retune hunting because a different agent takes over.

## How to play

- `play.bat` opens the windowsill. `play_lab.bat` opens the previous traversal lab, including its perception stage and practice fixtures.
- Existing movement, camera, Focus, stalking, jumping, silk and feeding controls are unchanged. H shows field notes. The green landing ring means the ground is reachable; a fly can leave before arrival.
- The front ground path leads past the planter. The upper route starts at the west leaf, jumps an 8 WU gap to the middle leaf, then continues across the planter and east leaf. Either route can be taken back.
- Home is the silk-lined wooden crevice at the west end, behind the initial spawn. Walk into it, stop, and press E / controller X to rest. Move, prepare a jump, press E again or cancel to leave. Rest restores the rest reserve, never food energy, and has no performance penalty. It is not a save.
- Holding prey gives feeding priority over resting. Finish or cancel the meal normally; no competing rest interaction takes the button.
- After about 60 seconds, when not currently feeding or resting, a five-second visual warning announces a shadow. It passes across the floor over twelve seconds and clears. It does not move colliders, push the spider, change a jump or kill anything. It happens once per session. Pause freezes it and all dependent gameplay.

## What changed

`scripts/habitat/windowsill.gd` and `scenes/habitats/windowsill.tscn` provide static authored geometry: wood sill and frame, planter, broad leaf platforms, underside space and one silk-lined crevice. The scene has 12 validated prey perches, four starting flies and two validated frame-crack entry points. Surface and perch IDs are stable. The named dry-leaf material is a prototype adhesion abstraction, not a biological measurement. Silk lining, soil and wood grain are cosmetic, without snagging collision.

`main.gd` selects the habitat with `use_windowsill`; the shipped scene enables it. The integration-test base explicitly selects the lab unless a habitat test opts in. Lab-specific jump/drop callbacks are optional, so no disappearing practice perches leak into the habitat. The main world explicitly uses pausable processing; the pause menu remains independently active while paused.

`scripts/habitat/habitat_loop.gd` owns rest, the room-shadow phase clock and concise visual hints. NeedsModel owns the rest grant. It exposes a small record with retreat/event IDs and phase times for later persistence; **there is no restore or save implementation yet**. The shadow sequence is an authored environmental encounter, not weather or predator AI. There is no new audio in this chunk.

Capture now supplies bodily contact position and size in its event. The sensor resolves a current live contact; if sight was lost during the leap, it may resolve exactly one compatible lost hypothesis using bounded spatial evidence. It never selects a lost mark by world ID. Two ambiguous marks remain, and an unseen catch invents no visual classification. This is a small extension of the review’s live-contact proposal, necessary because a real strike can leave the visual cone before capture. Tests cover that case explicitly.

Performance reporting now pairs sensor and prey samples from the same tick before taking the combined percentile. Late capture/carry work contributes to the prey maximum. Reports identify actual platform/display and accept `JSS_TIMING_MODE` from the launcher. With no explicit timing label they say unspecified; they do not assume real time from engine arguments, because Godot can strip those flags. This does not turn headless measurements into F01.

The movement/camera scripts and spider/fly tuning data were not changed. Capture geometry, default reach/assist, reaction delay distribution, silk parameters and feeding rates remain the chunk-7 baseline.

## Verification

Final native Windows full suite, Godot 4.7.2 / Compatibility / Jolt, accelerated fixed 60 FPS: **482 tests, 481 passed, 0 failed, 1 not run**, evidence **182235d71390**. Report: `tests/reports/full_report_chunk8.txt`. The deferred test is L01 save/load. Thirteen added integration tests cover:

- all habitat perches, both entry points and four initial flies;
- the ground route out and physically back into the retreat;
- entering the upper route from the floor, then leaf/rim jumps in both directions;
- camera clearance in the crevice;
- rest grants, movement/jump cancellation and refusal outside the retreat;
- feeding priority and interrupted/resumed consumption in the habitat;
- pause freezing needs, prey, rest and disturbance;
- warning/pass/quiet phases, unchanged collision and no repeat;
- capture removing a justified stale mark, no secret ID resolution of a lost contact, and preservation of ambiguous marks.

All 13 new checks passed at accelerated fixed 30 and 144 FPS. The corrected paired prey+sensor p95 in the six-fly lab workload was 1051 microseconds in the final accelerated native Windows run, below the 2000 microsecond budget; this is a CPU sample, not a habitat frame-rate claim. Those are simulation/frame-order checks, not real-display frame-pacing claims. A native Windows graphical smoke capture ran on the AMD Radeon graphics device with Compatibility rendering. I inspected `tests/reports/shots/t08_spawn.png` and `t08_overview.png`, then reduced excessive scene brightness and inspected the updated spawn image. They are scripted stills, not a human playtest or an F01 measurement.

The old save/load half of L01 remains explicitly NOT RUN until T09. Existing M/A/P/L fixture reports remain separate from human and graphical gates.

## Scope and remaining limitations

- This is an authored graybox habitat, not finished art: broad leaves and planter use forgiving boxes, the crevice lining is simple drawn silk, and fly/spider models remain prototypes.
- H help is keyboard-only; the core rest interaction works through the existing E/X action. Full remapping, help access from controller menus, scalable text, nonvisual cues and reduced effects still belong to T09. No new formal U01 completion is claimed.
- The new route checks use the real motor and jump solver, but are scripted. A 10–15 minute human exploration session, formal E02 explanation, full graphical M04 across the habitat and a five-minute F01 run are still needed.
- Many missed upper-route jumps land on the lower sill. Existing lab fixtures still exercise silk catch/recovery; this chunk does not claim a new graphical habitat silk-recovery gate.
- The 2 WU/s generic contact-association prior is unchanged. Broadening it is not needed to accept the habitat and must remain evidence-based if later refined.
- Rest and the disturbance expose state for T09 but no save/load behavior. Preserve the approved **S01-C complete-world retreat checkpoint** scope. Do not revive the superseded arbitrary-state S01 requirement silently.
- The replacement rules remain the same placeholder population model. No ecological, seasonal or generational simulation was introduced.
- The existing chunk-7 handback contains historical “not played/no Windows run” statements. Its later update and Nathan’s feedback supersede them. Current status is this document and matching reports.

## Next agent: start here

1. Read this handoff, `claude/where-we-left-off.md`, `docs/DECISIONS.md` and Nathan’s newest notes. Inspect files before assuming the chat remembers the right state.
2. If Nathan enjoys the habitat, proceed to **T09: whole-world retreat checkpoints and accessibility**. If a specific route or view is awkward, make a local geometry/presentation fix first. Preserve the approved movement and prey timing.
3. For checkpoints, account for player, held/consumed prey, remaining nutrition, ownership ledger, needs, prey/population RNG, occupancy/reservations, pending replacements and habitat event phase as one consistent boundary. Rest must not duplicate food, reroll a loss or falsely promise a save. Retain a recoverable backup and reject malformed/incompatible records cleanly.
4. Add controller-accessible help, scalable/contrasting cues, remapping and appropriate reduced-effects/nonvisual options. Preserve mute-readable warning and feeding/rest cancellation.
5. Keep the lab as the regression fixture. Run the applicable tests, record deferred gates honestly, and hand back a matching evidence ID, archive, report and player notes. Do not change the frozen original specification; append a single decision record for accepted changes.

## Safe interchange between agents

Both agents work in the same project folder, one active writer at a time. `play.bat` always opens the current installed build. Keep `where-we-left-off.md` updated at every handoff with the current evidence ID and exact unfinished tasks. A usage cutoff is not a reason to rebuild the project. Use the archive and reports to establish what exists, and inspect differences before replacing any file.

## Final verification and delivery record

- Final full suite: **482 tests, 481 passed, 0 failed, 1 deferred**, native Windows, accelerated fixed 60 FPS, evidence **182235d71390**. `tests/reports/last_report.txt` and `full_report_chunk8.txt` retain this complete-suite report.
- Normal-speed native Windows run of all **13 new integration tests: 13 passed, 0 failed**, same evidence ID, no fixed-FPS flag. Separate report: `tests/reports/realtime_chunk8_report.txt`; log: `chet_chunk8_realtime.log`.
- Fixed 30 and 144 runs: **13/13 each**, same evidence ID; logs `chet_chunk8_fixed30.log` and `chet_chunk8_fixed144.log`.
- Scripted native graphical stills were inspected; no hands-on feel or five-minute graphics performance result is claimed.
- Verified snapshot: `tests/reports/snapshots/2026-10-10_182235d71390.zip`.
- Replaced original files are backed up outside the project at `C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\chunk8_backup_before_install`. Its install manifest lists new files and original/installed hashes. Nothing was deleted from the project. The earlier chunk-7 snapshot remains available.

## GitHub setup follow-up (2026-10-10)

The project is now prepared for the shared repository at https://github.com/socranates/jumping-spider-sim. See `docs/SHARED_WORKFLOW.md`. Compact copies of the full chunk-8 and normal-speed reports are committed under `docs/verification/chunk8/`, since generated `tests/reports/` is ignored.

A required tooling fix excludes `.git/` from game snapshots and adds a regression assertion. That changes the tests hash, producing **779a6714b373**, while gameplay source `3a567f74291b3315aeab0092ddd09e0a` and settings `8b6707d4bb26d00c21239d1c75d3aec2` remain unchanged. The setup check passed 9/9 (evidence tests and A01); the prior 481-pass full suite belongs to 182235d71390 and is not claimed as rerun under the new ID. Git attributes preserve hashed asset bytes across clones.
