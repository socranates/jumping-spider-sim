# Decisions ledger

Accepted decisions and amendments to spec v0.1. `docs/SPEC.md` is the frozen baseline and is never edited. Full proposals and reviews live in `docs/reviews/`. Add new entries; mark replaced ones as superseded instead of deleting them.

## Toolchain (chunk 2, 2026-10-05)

- **D-001 Engine.** Godot 4.7.x stable. Nathan plays and edits on Windows; `run_tests.bat` records the exact Windows version. Claude runs headless tests with Godot 4.7.2 (Linux) inside the Cowork Linux VM on Nathan's PC, on a copy of the project. That environment is verified to run Godot; it is not native Windows.
- **D-002 Renderer.** Compatibility, per spec §19.1. The project was created with Forward+ and switched. Reversible.
- **D-003 Physics.** Jolt Physics (the project default). 60 ticks/s. Physics interpolation on (§20).
- **D-004 Layout.** The project root is Nathan's Godot folder `jumping-spider-sim/`. It plays the role of `prototype/` in §19.2.

## Amendments from Chet's review 1 (2026-10-05, `docs/reviews/chet-review-1.md`)

- **A-001** P0 gate S01 is replaced by **S01-C** (complete retreat-checkpoint recovery; exact wording in the review, Q3). Original S01 is tracked as deferred, not passed. Debug fixture setup for airborne and hanging cases stays.
- **A-002** Last-seen mark accepted for P0 (T06): faint, optional, visibly stale, fixed to the last observed world position, invalidated when the spot is seen empty and by elapsed time. No through-wall silhouette.
- **A-003** Gaze display: optional instructional overlay only, preferably a subtle focus footprint or outline. Stops at occlusion. Never a milestone dependency.
- **A-004** Category refinement "movement → possible prey → fly-like prey". No species identification.
- **A-005** Focus judges distance: P1 experiment, disabled in P0. Test first a patch whose uncertainty narrows while looking without moving its center. The moving-estimate version only after M02 and comfortable jumping. No estimate change after commit. Displayed uncertainty must be real.
- **A-006** Reorientation toward remembered prey: P1. Body posture, no humanlike neck. Cosmetic unless it explicitly updates sensing. Never interrupts committed aim.
- **A-007** "No drawn routes" is a default presentation, not a ban on optional accessibility guidance or developer overlays.
- **A-008** Untethered dispersion deferred. Anchor absence never adds aim error to the P0 jump solver.
- **A-009** Non-anchor surfaces are tested in the technical lab. In the slice, any untethered route is optional and recoverable. Wet glass and moving foliage stay out of P0.
- **A-010** Chunk 7 proves P01 with a labeled moving target fixture behind an occluder. The real fly arrives in chunk 8.
- **A-011** Chunks read the spec by section heading, not line numbers. Each chunk also reads this ledger, `docs/SESSION_LOG.md`, and the interfaces it changes.
- **A-012** Launchers: `run_tests.bat` writes a fresh timestamped report (engine version, source hash, test counts, seed); zero tests is a failure; no stale success report survives a failed launch. `record.bat` is optional and pending.
- **A-013** Later ideas, status per the review: silk map P1 (separate bounded route trace; label walked paths versus silk); chapters as offers P1, no completion tracking; mirror Research only, no prescribed resolution; rest interlude an optional, skippable artistic experiment presented as the player's recollection; open window P2 behind an explicit "leave this habitat" choice; stillness makes existing animals less wary, never spawns new ones on a timer (cosmetic dust is fine); night lamp P1 after time of day exists; notebook of open questions P1; iridescent color is an art reference only; face at the window kept, without the "too large to resolve" claim.

## Source corrections

- **C1** Hill (1979): *Behavioral Ecology and Sociobiology* 5, 301–322. Full text still unchecked.
- **C2** Nagata et al. (2012): *Science* 335, 469–471.
- **C4** *Peckhamia* 179.1 removed: it is not a mirror-response study. The mirror idea needs a real source.

## Implementation decisions (chunk 2, 2026-10-05)

- **D-005 Keyboard look.** Arrow keys are bound to look_left/right/up/down, so every §17 action has both keyboard and controller input. Mouse look comes from mouse motion.
- **D-006 Camera placement.** The camera is placed only from a live sphere cast; before the first physics tick it sits at the spider's center. When the collision-limited boom is shorter than 2.5 WU, the rig searches steeper downward pitches and eases in a temporary auto-pitch, so the spider stays in frame with its back to a wall. Retraction is immediate; only recovery is smoothed. `_process` re-casts when the orbit direction changes between physics ticks.
- **D-007 Test isolation.** Tests use an isolated Settings instance with autosave off and never touch the player's saved settings. The runner counts unexpected engine errors as failures.
- **D-008 Layout details.** The lab builder lives in `scripts/habitat/`. `.bat` files are kept CRLF through `.gitattributes`.

## Implementation decisions (chunk 3, 2026-10-05)

- **D-009 Support model.** Sphere collider in floating mode with an explicit SupportState. Gravity acts only while FALLING. The spider climbs onto a face turned 30° or more when pushed into it by about 15° or more. It rounds a convex edge with a 0.15–0.25 s arc only when the face beyond can hold it and the arc is clear; otherwise it falls. LANDING lasts 0.1 s.
- **D-010 Eligibility.** Surface profiles live in `data/surfaces/*.json` (§21.2) with a strict loader (unknown fields rejected; id must equal the file name). A surface holds the spider if it is attachable or within 45° of world up. Clean glass is attachable; a PTFE-coated panel is not. Both are tuning abstractions.
- **D-011 Controls on surfaces.** Forward is the camera's flat forward on floors and undersides and the camera's up on walls, blended between 30° and 60° of tilt. Right is the camera's right made perpendicular. The heading is carried across sharp support changes until the stick turns more than 30°, is released, or the camera mapping agrees within 25°.
- **D-012 Camera on surfaces.** The pivot sits along the smoothed support normal. The camera never rolls. Recenter faces the surface on walls. D-006 boom rules are unchanged.
- **D-013 M01 testing.** M01 runs its 20 routes side by side in one world and writes `tests/reports/m01_report.txt`. The runner watchdog is 300 s, and stale reports are removed before a run. Independently re-run by Claude on a fresh copy: 103/103 passed, M01 20 of 20.

## Implementation decisions (chunk 4, 2026-10-05)

- **D-014 Jump solution.** Launch velocity is solved in the discrete form the motor flies (semi-implicit Euler at the physics tick), over whole-tick durations in the species flight range (21–36 ticks for 0.35–0.6 s), lowest launch speed first, at most 14 WU/s. The launch leaves the surface (v0·N ≥ 0.05) and arrives into the target (≥ 0.05 WU/s on standing surfaces, ≥ 0.3 WU/s on walls and undersides). The planned landing center is the target point plus its normal × (body radius + 0.01).
- **D-015 Validation and classes.** Sphere sweeps (radius body + 0.003) between successive tick positions with the spider excluded, plus a body-fit test at the seat; the first contact must fall within 0.15 WU of the seat. Classes: reachable, obstructed, unreachable, ineligible (D-010), none.
- **D-016 Jump controls.** Tapping Space (under 0.15 s) makes a 1.5 WU hop planned like a leap, from up-facing surfaces only. Holding prepares; release commits only the plan the patch showed; Q cancels without penalty; an invalid release cancels with a message. The accessibility toggle-prepare mode has no hop. Aim is the camera's center ray with no target magnet. While aiming, vertical look tilts the view about the camera (−20° to +50°) instead of orbiting.
- **D-017 Flight and landing.** The committed impulse is frozen and nothing steers. An eligible first contact lands through the T02 acquisition with the hit normal and plants the feet; a glancing or obstructed contact falls; leaving the play bounds resets to the last supported position with a label. A leap back onto the same wall or underside plane is out of reach.
- **D-018 Patch language.** Shape, color and words, never color alone: solid green ring = reachable, amber ring with a cross = obstructed, dashed red = unreachable, dotted violet = ineligible. No uncertainty band in P0 (A-005, A-008). The detailed arc is a pause-menu setting, off by default; F4 shows the predicted and actual paths of the last jump.
- **D-019 Camera room.** When no downward pitch gives a comfortable boom, the auto-pitch also tries lowering the camera and looking up (to −45° effective), smallest change first.
- **D-020 Edge arcs.** Edge arc time follows speed (arc length ÷ speed, 0.15–0.6 s): unchanged at walking speed, slow when stalking.
- **D-021 M02 testing.** M02 flies 100 jumps at once in one world and writes `tests/reports/m02_report.txt`. "Legal" means the solver found an arc. Tests that wait on something eased in `_process` wait in physics ticks. Independently re-run by Claude on a fresh copy: 177/177, M01 20 of 20, M02 100 of 100 (max error 0.0173 WU), invalid candidates 8 of 8.

## Implementation decisions (chunk 5, 2026-10-05)

- **D-022 Species numbers** (amends D-014; differs from spec §21.1 and needs Chet's view). Launch speed up to 20 WU/s; flights 0.35–0.9 s (21–54 ticks); line up to 20 WU; reel and lower at 1.5 WU/s. Reason: Nathan asked for farther jumps after chunk 4. Reach at 100%: 11.2 WU level, 10.1 WU up 1, 8.9 up 2, 7.5 up 3, 13.9 down 3. Reversible: one data file.
- **D-023 Jump reach setting.** A playtest setting from 50% to 150%, default 100%. The planner's speed limit and longest flight scale by its square root; the line maximum scales with it.
- **D-024 Landing ring scale.** 1× up to 6 WU from the camera, then proportional to distance, at most 4×. The center stays the exact landing point.
- **D-025 Safety line** (spec §9.1, §21.3). Anchored at takeoff to the launch surface under the body, only when its profile allows silk and the planned line fits the maximum; no remote aiming. It pays out during the leap without changing the arc. A landing completes it (it fades over 6 s; at most 6 kept). A miss (no contact 3 ticks after the predicted one) or a non-landing contact locks it at the paid length plus a 0.25 WU run-on. The constraint is unilateral: it removes only outward radial speed and excess length. One bend point; a second bend snags (no reeling, but lowering and letting go still work). Touching any surface that can hold the spider takes hold and completes the line. If the anchor's surface goes away, the line comes loose with a cue.
- **D-026 Letting go.** Hold Q / east button for 0.6 s by default; a press counts only 0.4 s after the catch. Setting "Hold Q / B to let go of the line" (off: a counted press lets go at once). The HUD labels Q by state (cancel jump or let go).
- **D-027 Resting on the line.** A hanging body that stays under 0.05 WU/s for 20 ticks is held exactly in place until the player reels or lowers, the line changes, or a surface it rests against goes away. This fixes a 7e-5 WU/tick gravity creep.
- **D-028 Line energy and M03.** Per tick, energy may not exceed its start-of-tick value plus the reel's work, the signed seat step, the engine's contact recovery (≤ 0.002 WU/tick, measured per fixture) and 2e-4; other tolerances are stated in float32 epsilons. M03 is ten fixtures writing `tests/reports/m03_report.txt`; its blocked-reel fixture is a coated ceiling with a hole. Practice perches drop when a jump is aimed at them. The runner takes `--only`, `--part` and `--files`; the full suite (~265 s) is verified in real-time parts. Independently re-run by Claude: 209/209 (fixed-fps), gates in real time M01 20/20, M02 100/100 with 8/8 invalid refused, M03 10/10.

## Amendments from Chet's review 2 (2026-10-07, `docs/reviews/chet-review-2.md`)

- **A-014** Chunk 5 is accepted as the first movement-and-silk milestone, and D-022 to D-028 are accepted. Chet ran the suite independently on native Windows: 209/209, M01 20/20, M02 100/100 (8/8 refused), M03 10/10 (report 2026-10-07T06:24:11Z).
- **A-015** The long-jump tuning (D-022) is the P0 playtest default and supersedes D-014's launch numbers. It is a designed abstraction; biological validity is unverified. The reach slider stays as a labeled playtest/assistance setting. Don't retune the default downward in the next chunk. When slider combinations change, verify them against line length, preview validation and landing feedback.
- **A-016** The P0 safety line stays free: a miss costs position, time and changing opportunities, not a resource. Terminology: unlimited reserve, bounded length. Reel speed 1.5 WU/s stays the baseline; measure recovery durations before changing it; no input delay or rapid tapping. Any P1 effort cost waits for needs and ecology and must never deadlock a return to safety.
- **A-017** The catch is presented for legibility. Keep the orbit controls and horizon stability. Check the cliff-cap catch and grab with no scripted camera input, and fix only if the view obscures the recovery choices: a small, collision-safe pivot or angle change, never through terrain, no forced roll, player look input always wins. Active silk must read on light and dark backgrounds (restrained contrast, a minimum screen thickness, true occlusion). Load-bearing silk looks different from fading old silk. A small anchor cue or HUD note explains a hidden anchor.
- **A-018** The settled physics body may stay exactly still (D-027). Any living motion (settling, leg adjustment, a catch recoil) is cosmetic, on a child rig, and small enough that the feet and the silk endpoint stay believable. Camera shake is optional and off by default. Full leg IK, a gait, sound and an elastic rope are not prerequisites for T06.
- **A-019** M03 reporting units: 1 WU = 1 cm = 10 mm, so CONTACT_LIFT_MAX 0.002 WU is 0.02 mm and a 0.001 WU margin is 0.01 mm. Fix the report conversion and the prose; tolerances are unchanged. The energy gate is described as "no unexplained energy gain within the documented allowances".
- **A-020** Evidence identity: handbacks also identify the project settings and the test snapshot (not only scripts, scenes and data), and include a complete archive of the handed-back state.
- **A-021** Habitat guidance for long jumps (T08): short precise hops stay useful; occasional long, clearly framed gaps; occluded routes, walls, undersides and offset landings that a single leap can't bypass; sheltered versus exposed routes; readable scale. Longer reach never becomes automatic capture range or inspection across occluders.
- **A-022** Chunk 6 scope: a brief recovery-readability check, then T06 perception with a labeled moving target behind an occluder (A-010). World truth → sensed observation → memory → presentation. Turning the camera alone never rotates the inspection cone. Occlusion stops live updates. The last-seen mark stays at its last observation and expires, or is invalidated when the spot is inspected empty (A-002). P01 is shown with visible motion, forward inspection, loss of sight, a stale mark and reacquisition. Any gaze overlay is optional and reveals nothing hidden (A-003).

## Implementation decisions (chunk 6, 2026-10-07)

- **D-029 Catch framing.** While the spider hangs on a locked line, the camera may add a yaw turn to the player's view: the smallest turn, in 15° steps, that gives a comfortable boom (≥ 2.5 WU or the distance setting) and a clear view of the line's rest point and the lip. It eases over 0.12 s, never rolls, and any look, recenter or aim input takes over. Capped at 45°, behind the setting "Frame the line after a catch" (default on). Measured: at the cap it doesn't help the default cliff-cap catch (crowded 1.83 s and 3.83 s on the line, 1.47 s after the grab; the uncapped 90° turn gave 0.53 s, 0.57 s and 0 s). Open: question 1 in `docs/HANDOFF-chunk-6.md`.
- **D-030 Crowded-view measure.** The recovery view counts as crowded when the spider is hidden or too close, geometry within 1 WU covers over a third of the screen, or (on the line) the lip is out of frame or hidden, or less than half the line is visible. Measured every physics tick with no camera input (`tests/catch_camera_probe.gd`, `catch_camera_report.txt`).
- **D-031 Silk look.** A camera-facing ribbon with a dark core and a light rim; the core is at least 2 px at 1080p (2.5 px while taut or reeling) with a 1.25 px rim each side; depth-tested, so no X-ray. Old silk is pale, 1.5 px, 0.8 opacity, fading. A note under the prompts says when the anchor is out of sight.
- **D-032 Catch recoil.** Cosmetic only: the model child recoils at most 0.09 WU along the line for about a third of a second on a catch. The physics body, collider, line and camera are untouched. Camera shake stays off.
- **D-033 Evidence identity.** Reports carry source, settings and tests hashes plus an `evidence_id`. `snapshot.bat` writes `tests/reports/snapshots/<UTC date>_<evidence id>.zip` (everything except `.godot` and `tests/reports`), then reads it back and compares. Handbacks name the evidence id they were tested at.
- **D-034 Camera placement order.** A boom cast is trusted only once the world can be seen (`is_world_ready()`), at any frame rate. This fixes the intermittent Windows failure of 2026-10-07T06:14:45Z (reproduced at --fixed-fps 10 and 15; now 27/27 at 15, 30, 60 and 144).
- **D-035 Perception layers and the peripheral cue.** World truth → sensor evidence → memory → presentation. The sensor never decides behavior or writes labels; memory never reads the world; presentation reads only memory and the camera. Peripheral cue: a 300° field about the gaze, 22.5° sectors and 30° bands, 0.8 s cooldown per thing, a 10 Hz broad scan with 4 WU close checks, 40 WU range. It gives direction only, no position or category, and needs line of sight.
- **D-036 Inspection and Focus.** A 30° cone about the gaze. "movement" → "possible prey" at 0.40 s → "fly-like prey" at 1.00 s of continuous exposure for an easy target (longer when it looks small); breaks under 0.15 s don't reset it. Focus (right mouse, left trigger) turns the body toward the camera's aim at 180°/s and tilts the gaze up to 35°. The camera alone never turns the cone.
- **D-037 Memory and the last-seen mark.** Confidence falls linearly to zero over 6 s. The mark is the last inspected position and never moves. It is dropped when the spot is inspected in plain view and found empty (0.40 s), and it expires. Reacquisition updates the same record; association is by id for now (question 3 in the chunk 6 handback). Plain words only, no numbers. Nothing is shown for what was never sensed. The gaze footprint is a setting, off by default. Only the developer overlay (F3, F4) draws truth.
- **D-038 Test target and gates.** A labeled magenta marker (not a fly, no AI) moving at 0.8 WU/s on a stage watched from a 2 WU ledge; fixtures can remove or relocate it. P01 is a gate (`tests/reports/p01_report.txt`). The suite is 338 tests, about 560 s in real time in ten parts; the runner watchdog is 900 s, and `run_tests.bat` takes about ten minutes. Independently re-run by Claude: 338/338 (fixed-fps 60); gates in real time M01 20/20, M02 100/100, M03 10/10, P01 8/8.

## Amendments from Chet's review 3 (2026-10-08, `docs/reviews/chet-review-3.md`)

- **A-023** Chunk 6 is accepted: the perception loop works (notice, orient, inspect, lose sight, keep a fading expectation about a place). Chet's native Windows run at evidence 4b9098e032ed: 338/338 (fixed-fps 60). A separate Windows report dated 2026-10-07T15:40:54Z also shows 338/338 for the same id. Keep the long jumps, the movement controls, the free line reserve, explicit Focus and the classification timing (0.40 s and 1.00 s) as designed baselines.
- **A-024** Small-target occlusion leak (fix before T07): `_clear()` in sensor_system.gd accepts a world hit within 0.05 WU of a sample endpoint, so a 0.01 WU target fully behind a 0.02 WU barrier is sensed. Use a much smaller, justified tolerance, constrained relative to the sample geometry; keep valid partial visibility and stable behavior at ordinary surface boundaries. Regressions: Chet's arrangement; a partly exposed small target is sensed; an openly visible small target refines; a last-seen spot behind the same barrier is not declared empty.
- **A-025** Catch camera: keep the automatic turn capped at 45° and optional; no unsolicited 90° swing by default. The cap doesn't fix the default cliff catch, and that is recorded honestly. Further fixes prefer a small collision-safe pivot or pitch adjustment, stronger line and attachment cues, or a player-requested "show my line" action. Look, recenter and preparation input always take precedence. Backlog item, re-checked in the windowsill topology; no more chunks spent on one lab cliff.
- **A-026** Focus stays the explicit default. It is a request to turn toward the aim, not "switching vision on": the cone inspects along the body's gaze without it. No automatic gaze-following when the player stops moving. The capped turn rate and 35° gaze tilt are gameplay abstractions. A Focus toggle comes in the early accessibility pass: clearly indicated, cancelable, never overriding a committed jump or a deliberate recovery action. Classification must never gate a strike.
- **A-027** Contact association. A remembered contact is an evidence-based hypothesis, not a world identity. Three separate concepts: world entity ID (physics, ownership, saves, debugging), contact/track ID (the animal's hypothesis), and category familiarity (a kind, not an individual). Keep a track through continuous observation and brief, justified sampling gaps. After loss of sight, match a new visible observation to lost contacts by last observed location, elapsed time, compatible apparent size and category, and observed motion, within a bounded plausible region that grows with elapsed time under a conservative speed bound and never uses where the hidden object went. Reuse a contact only when there is one plausible candidate and the evidence is reasonably strong; otherwise start a fresh track with no exposure transfer. Old marks decay or are invalidated by observed evidence. Update P01 F6 and the same-ID tests explicitly, recording the changed assumption.
- **A-028** The first fly (T07): one archetype with a perch graph, resting, alertness, takeoff, fleeing and choosing another perch. Integrate one live fly first, then two for association and fairness tests, then 3–6. The magenta target stays in the testbed. The fly has its own sensory evidence and never reads the player's buttons, Focus, intended landing target or the spider's hidden true position. Goal selection stays small and interpretable (rest/food, perceived threat, safe perch, travel cost, hysteresis), with logged reasons. Capture is resolved spatially, once, with explicit ownership. Feeding grants reserves only while valid and can be canceled. A fly can escape while the spider recovers on silk; that is a miss's real cost. Classification never enables a hitbox.
- **A-029** Sensor cost and lifecycle: before claiming the sensor budget, measure candidate counts, ray counts (including memory-spot checks) and CPU time with 3–6 flies. Any staggering integrates only evidence actually acquired. `_tracks` is cleaned up for despawned percepts.
- **A-030** Accessibility: pair meaningful visual cues with optional sound or haptics, or a stronger text/contrast treatment, early. Start with scalable text, contrast and the Focus toggle; full audio comes later.
- **A-031** Chunk 7 order: visibility fix → contact association → T07 (gates A01, L01) → small usability additions. No broad camera pass, genetics, seasons or extra prey types. Handback: a new evidence id and archive, test results, a short hunt demonstration if available, and Nathan's notes; M04, performance, physical-controller and human-study gates marked separately from automated passes. Update the chunk 6 handback's Windows statement.

## Implementation decisions (chunk 7A, 2026-10-09)

- **D-039 Occlusion tolerance (A-024).** A world hit before a sample point counts as occlusion unless it falls within min(0.05, 0.1 × target radius + 1e-5 × ray length) WU of the endpoint; a 0.01 WU speck at 1 WU gets 0.001 WU. Chet's arrangement now gives 0 contacts. Partial visibility is kept, and a last-seen spot behind the barrier is not declared empty.
- **D-040 Contact association (A-027).** After a loss of sight, a focused sighting joins a lost contact only if exactly one fits: distance within 0.5 × (old + new size) + max(2.0, observed speed) × elapsed time (WU); size ratio at most 1.5; a category no finer than the spider could have seen. Otherwise it is a fresh contact with no exposure carried over; peripheral cues never match a lost contact. `contact_speed_bound_wu_s` (2.0) and `contact_size_ratio` (1.5) live in the species data. `target_id` is cleared on loss, and tracks of vanished percepts are erased (A-029). Changed test assumptions: P01 F6 and `test_seeing_it_again_updates_the_same_record` now rename the world id while the target is hidden.
- **D-041 Focus toggle (A-026).** A pause setting, off by default. While on, the HUD shows "FOCUS ON". It ends when the feet leave the surface, and cancel stops it only when nothing else is in progress, so it never overrides a committed jump or a recovery. Presses are read with `is_action_just_pressed` (a fixed-fps 30 run exposed two failures). Verified: 381/381 in real time (ten parts) and at fixed fps 30, 60 and 144; re-run by Claude: 381/381 (fixed-fps 60) and the gates in real time (M01, M02, M03, P01 all pass). Evidence 96aa196539c4.

## Implementation decisions — Chet, chunk 8 (2026-10-10)

- **C8-01** Nathan asked Chet to code this chunk, superseding the earlier read-only review restriction. Nathan approves all current mechanics. Preserve movement, camera, jump, silk, hunting and feeding tuning.
- **C8-02** T08 uses a separate static authored windowsill. The lab is retained through `play_lab.bat` and existing fixtures explicitly select it. `main.gd` chooses the habitat; practice-drop callbacks are optional.
- **C8-03** One physical crevice supports cancelable rest through NeedsModel. Holding prey reserves E/X for feeding. Rest has no penalty, food grant, teleport or persistence claim. S01-C remains the later whole-world checkpoint requirement.
- **C8-04** One harmless room-shadow event: 60-second initial delay, deferred during a meal or rest, five-second visual warning, twelve-second passing shadow, then quiet. No collider or jump force changes. Simulation pause freezes all phases.
- **C8-05** Capture resolves a live percept contact. If sight ended during the leap, bodily position and size may resolve exactly one compatible lost hypothesis by the same bounded spatial prior, without selecting by world ID. Ambiguous old marks remain. A capture never invents a visual classification.
- **C8-06** Report combined AI/perception p95 from paired tick samples; include late capture work in the maximum. Report actual OS/display and explicit timing provenance. Headless timing is not F01.
- **C8-07** Dry static leaves use a named prototype surface with ordinary adhesion. This is a gameplay abstraction, not a species/material finding. Visual details have no separate collision.

## Implementation decisions — Claude, T09 part 1 (2026-10-10)

- **T9-01 Checkpoint scope (S01-C, A-001).** Starting a rest in the windowsill crevice makes the retreat checkpoint at the end of that tick (the habitat loop runs last, after captures and feeding). One checkpoint per rest; the caption says "Checkpoint kept." or why not. Only the windowsill has checkpoints; the lab refuses with a reason. Airborne, preparing, hanging, mid-strike and mid-meal states are refused as checkpoint moments. The original S01 (exact arbitrary-state resume) stays deferred.
- **T9-02 What a checkpoint holds.** One plain JSON record (`scripts/persistence/checkpoint.gd`): the spider's position, support normal, heading and surface ID; NeedsModel's record; the feeding ledger; every living fly and the fly in the jaws with its RNG seed and states (as decimal strings), state, perch, schedule, senses, pending reaction, blocked perches and flight in progress; every perch's and vent's occupant and reservation; the captures made; the replacement schedule and its stream; the habitat clock, rest and shadow-event phase. Fly traces, event logs, cost counters, the spider's perception memory and old silk are developer history or presentation and start empty after a restore.
- **T9-03 Loading.** "Return to checkpoint" validates the record first, then discards the whole current world and builds a new one from the record (any state: walking, airborne, hanging, feeding). Flies are rebuilt by id, serial and seed and given back their state without drawing from any stream, so two loads of one checkpoint continue identically within this build. A refused record leaves the current world untouched. The screen says "checkpoint recovery, not an exact resume". The pause menu action is disabled with the reason when there is no checkpoint, and never says "save".
- **T9-04 Partly eaten prey.** A checkpoint may be made (by the world API, used by L01) while the spider stands still holding a part-eaten fly; the record keeps its remaining nutrition and its capture. Validation refuses any record in which a capture has given more energy than was eaten of its fly, a free fly carries a capture, or more than one fly is held. The player's own checkpoint still requires the retreat, where held prey has feeding priority (C8-03).
- **T9-05 File store (S02).** `user://saves/checkpoint.json` (Windows: `%APPDATA%\Godot\app_userdata\<project>\saves`). A save validates, writes `checkpoint.tmp.json`, reads it back (parse, MD5 checksum of the canonical JSON, validation), moves a valid current file to `checkpoint.bak.json`, then moves the new file into place. A damaged current file never replaces a good backup. Loading never writes; it tries the current file, then the backup, and says why it refused each. A newer schema is reported and left untouched. Settings stay in `settings.cfg`, separate from checkpoints. Test worlds keep checkpoints in memory, or in `user://jss_test_*` folders.
- **T9-06 NeedsModel rounding.** The update accumulator's remainder is clamped at zero; a -2e-9 remainder made NeedsModel's own record unloadable. No gameplay change.
- **T9-07 Keyboard remapping (U01, part).** The pause menu lists 15 actions; choose one, press a key; Esc stops without a change; a key in use is swapped; Esc, F3 and F4 are reserved. Reel and lower follow walk forward and walk back. Controller and mouse buttons are unchanged (controller remapping not yet built). Keys are saved in `settings.cfg` (`[bindings]`) and apply at once.
- **T9-08 Field notes from a controller.** New `help` action: H, or the controller's View / Back button. On-screen key names follow remapping.
- **T9-09 Text and panel size.** Setting `ui_scale`, 100–150 %, the window's 2D content scale (the 3D view is unchanged); saved with the settings. The pause panel scrolls when taller than the window and its switches fall to one column on a narrow window. A mouse drag applies the size when released.

## Implementation decisions — Claude, T09b hunt feel (2026-10-10)

Nathan's direction, 2026-10-10: "keep in mind twitchy movements typical of jumping spiders"; "you should also have to tap the button as the prey struggles … a bar that depletes when you stop tapping"; "the fly should sort of look to and fro while you slowly creep making the twitchy quick movements"; "the hunts can be deliberately slow and challenging"; and yes to a leaf on the sill that gives way. This deliberately supersedes C8-01 and A-015/A-023's "keep the hunting tuning" for the fly's senses only. Movement, camera, jump, silk and feeding numbers are unchanged.

- **T9b-01 The fly glances to and fro.** A perched fly that is not grooming, fidgeting or held by a fixture turns quickly (its 720°/s turn rate) to look 45–135° to one side of the way it settled, then the other, every 0.8–2.2 s. The timing comes from its gameplay stream (data: `glance_interval_s`, `glance_angle_deg`). It senses along its facing as before, so a glance changes what it takes in. An alert fly stops glancing and faces where it last saw the spider.
- **T9b-02 Senses retuned so the glances matter.** `rear_gain` 0.35 → 0.12, `motion_scale_deg_s` 12 → 6, `loom_scale_deg_s` 40 → 70, and new `startle_rear_gain` 0.5 (a big looming leap still startles from behind). Measured (tuning_run.txt, 8 seeds from 7 WU):
  - a steady stalk in plain view is spotted at about 4.2 WU, every time (before: never spotted, about 6 s);
  - a stalk that moves only while the fly looks away reaches 2.2 WU unnoticed 8/8, in about 17 s;
  - walk-speed darts timed to its glances reach it 8/8, in about 13 s;
  - a walk is spotted at about 6.4 WU (before about 4.5);
  - a leap from 5.5 WU catches 1/8; from 2.2 WU, 6/8.

  Designed values, no biological claim. `test_prey_hunt` and `test_prey_fly_rest` now state the new design, rather than having their thresholds loosened.
- **T9b-03 Twitchy spider (looks only).** The model child snaps through turns (it lags up to 14°, then closes the gap), walks in stop-and-dart lurches (0.07 WU walking, 0.035 stalking, once per 0.32 WU), crouches while aiming, flicks or bobs now and then when still (cosmetic stream), and jolts with struggling prey. It stays within 0.1 WU and the snap limit. The physics body, senses, camera and line never see it (A-018). New setting **Reduced motion** turns it off, together with the catch recoil.
- **T9b-04 The struggle (grip bar).** A caught fly struggles for 2.5–3.5 s (its own stream). The grip starts at 0.6, drains 0.3/s, loses 0.1 at each jerk (every 0.35–0.75 s), and gains 0.25 per press of interact; about two presses a second hold it.
  - Holding the button counts once. Presses outside the struggle cost nothing.
  - Grip at 0: the fly tears free, flees, its capture is removed from the log (it can be caught again under the same event id), nothing was eaten, and one owed replacement is dropped.
  - It cannot be eaten while it struggles, and a checkpoint is refused.
  - Spec 17 forbids required rapid tapping, so the setting **Struggling prey: hold on automatically** keeps the grip full; Nathan chose tapping as the default.
  - The HUD shows "IT STRUGGLES!", the key, and the bar, which turns orange-red when low (words, not only colour).
  - Played worlds struggle; test worlds only on request (`prey_struggle`).
- **T9b-05 The leaf tip that gives way.** `leaf_tip`, a pale dry leaf past the east leaf (x 25.6–28.4, z −4.2 to −1.8, top 5.35), is the windowsill's only drop piece. A jump aimed at it makes it give way (falls, drawn only). The east leaf's line catches the spider above the sill; reeling returns it; the tip comes back 8 s later once the space is clear. This revises C8-02's "no disappearing practice perches in the habitat" for this one authored teaching spot. The field notes name it.
- **T9b-06 Checkpoint schema 2.** Flies record their glance state, and a fallen tip is a habitat change (returns_in). Schema 1 records (the first T09 build) are upgraded in memory on load; the file is not rewritten. A refused checkpoint's message now gives the first reason and the count of others.

## Implementation decisions — Claude, T09c living flies and the struggle fixed (2026-10-11)

Nathan, after playing T09b: "the approach can be slower"; "the tapping mechanic is not what happens or isnt working properly when i catch a fly"; "i can tell the fly direction"; flies "should actively walk around more naturally like a real fly, take off and fly randomly sometimes … i really want this to feel real"; "maybe the space bar can be used for the tapping". Chet's review 5 (P1, P2) and his native Windows run are addressed here too.

- **T9c-01 The struggle, fixed.** A played-world diagnosis with real key events found three problems:
  - after the fly was subdued, the player's next taps started and stopped the meal;
  - the grip drained during the spider's flight, before the player had landed or could read the prompt;
  - from the camera behind, the fly in the jaws was hidden by the spider's body.

  Now:
  - the grip waits until the spider is on a surface (at most 1 s);
  - once subdued, the fly is eaten at once, taps for 1 s afterwards are swallowed, and "Subdued." or "It tore free!" is shown;
  - a struggling fly is held out in front at head height, buzzing its wings in bursts and kicking its legs;
  - each tap tugs the spider's model.
- **T9c-02 Space is the grip.** While prey struggles, and for 1 s after, the jump button (Space, A) presses the grip like interact (E, X) and neither hops nor aims. The prompt names both.
- **T9c-03 Flies walk.** A perched fly walks about its spot every 1.5–5 s:
  - 0.4–1.8 WU at 0.9–1.8 WU/s, in stop-start bursts (0.12–0.35 s moving, 0.05–0.25 s still);
  - it turns to face the way first, and walks on its surface only;
  - the way is checked before it sets off, so it never goes off an edge or through anything;
  - it stays within 3 WU of its perch, heading back when it has wandered half that;
  - it stops walking when alert;
  - its fidgets now centre on where it last settled.

  Walking is drawn with a tripod leg shuffle and comes from its gameplay stream (data: `walk_*`, `wander_radius_wu`).
- **T9c-04 Flies fly about on their own.**
  - `restless_per_s` 0.012 → 0.03, so a fly moves of its own accord about every half minute instead of every minute and a half.
  - 60 % of such moves (`wander_flight_chance`) loop out to a random swept point in the open air, then come in to land.
  - The drawn body wobbles a little in flight (looks only).
- **T9c-05 Slower approach.**
  - The spider's stalk speed is 0.8 → 0.65 WU/s (species data), and the fly's `loom_scale_deg_s` 70 → 80.
  - Measured with walking flies (t09c/tuning_run.txt): a careful timed creep reaches striking range 6/8 in about 20 s (before 7/8 in 17 s); a steady stalk is spotted at about 3.9 WU; a walk at about 6.2 WU.
  - Slowing to 0.55 made a careful approach fail 6/8, and sharper senses made it fail more without making it longer, so both were rejected.
  - Four tests that state the stalk speed now say 0.65.
- **T9c-06 Checkpoint schema 3.** Flies record their walk. Schema 2 upgrades to 3 and schema 1 through 2 to 3, in memory only.
- **T9c-07 A save never deletes an unreadable checkpoint** (Chet review 5, P1). A current or backup file this build cannot read is set aside unchanged as `checkpoint.newer.json` or `checkpoint.damaged.json` (numbered if taken) before the new file goes in. The message names it, and a regression test covers save-after-refusal.
- **T9c-08 Prompts name the chosen keys** (Chet review 5, P2). `KeyNames.apply` rewrites the default keys in a hint to the player's: the feeding prompts, the line and aim hints, the Focus hint, and the pause menu's "Hold Q / B to let go of the line" label.
- **T9c-09 F4 view draws at once.** The support view draws on the toggle rather than the next frame. This is the likely cause of Chet's native Windows failure of `test_support_view_toggles_with_f4_and_draws_the_normal`, but it was not reproduced on Linux at fixed or normal speed, so the cause on Windows is unconfirmed until Nathan's next `run_tests.bat`.

## T09d — controller buttons and assisted-play presets (Claude, 2026-10-11)

Done while Chet's live-legs work waited for his usage to reset. No file in his open diff (`main.gd`, `spider_body.gd`, `spider_legs.gd`, `test_spider_legs.gd`, `test_live_spider_legs.gd`) was touched.

- **T9d-01 Controller buttons can be remapped** (spec 17: "Inputs are remappable actions"; U01).
  - Aim and jump, Focus, Stalk, Eat / rest, Cancel / let go, Recenter and Field notes can each be given any controller button or either trigger, in the pause menu's key list (now "Keys and buttons...").
  - Walking and looking stay on the sticks. Menu (pause, the way out of every menu) and Guide (the system's) can't be given away.
  - A button in use is swapped, as keys are. The keyboard key and the mouse button of an action stay when its button changes; a trigger an action gives up is removed from it.
  - Saved in `settings.cfg` under `[pad_bindings]` as one number per action: a button is its `JoyButton`, a trigger is 100 + its `JoyAxis`. A bad line (reserved, unknown, not a number, a stick action) is ignored and that action keeps its default.
  - One "Reset keys and buttons" restores both.
- **T9d-02 Prompts name the chosen buttons.** `KeyNames.apply` now swaps the default controller button of a hint too ("Q / B" becomes the player's key and button), in two passes so an action named for one token is never renamed again as another. The windowsill's caption and field notes and the feeding prompts use `KeyNames.both`.
- **T9d-03 Assisted-play presets** (spec 17: "adjustable aim/capture assistance"; "no shame labels").
  - Four presets at the top of the pause menu set eight switches at once: strike assist, the jump arc, where the spider looks, holding a struggling fly automatically, the three toggles (aim, stalk, Focus) and hold-to-let-go.
  - Standard is the defaults. Guided hunting adds the wider bite, the arc, the gaze footprint and the automatic hold. No held buttons makes aim, stalk and Focus press-to-start, press-to-stop, holds the fly for you and lets go of the line on one press. Most help is both.
  - Names say what a preset does, not how good the player is; the line under them says it in words. Change any switch and the menu says "Custom".
  - Presets leave the camera, the text size, Reduced motion and the playtest jump reach alone.
- **T9d-04 Most help keeps hold-to-let-go.** It is the preset for a young or new player (Nathan's son, almost 6, plays), and spec 17 asks that an accidental press must not drop the spider. No held buttons gives it up, for players who can't hold a button, and says so.
- **T9d-05 Left for later.**
  - Global slow time and a separate survival-pressure setting (spec 17) need wiring in `main.gd`. They wait until Chet's live-legs work is merged, so the two don't collide.
  - Reduced motion is still the only "reduced effects" setting; the game has no camera shake, blur or depth of field to turn off.
  - There is no audio yet, so the nonvisual-cue options have nothing to replace.

## Live legs — Chet, 2026-10-10 (America/Chicago)

- **LEG-01 Live cosmetic rig.** Nathan approved option 1. Replace the static legs with the existing alternating four-leg rig under the body child, retaining all twitch/recoil behavior and the live material. Feed support-tangent motor velocity in the model's local frame once per physics tick. No gameplay state, physics, camera, senses or gameplay RNG changes.
- **LEG-02 Reduced motion.** The setting holds the legs in their neutral stance and disables twitch/recoil. Switching it on clears an already active recoil on the next tick. Presets keep their T09d behavior and leave this preference alone.
- **LEG-03 Connected geometry and packages.** Scale each cylinder along its local length axis, not world Y; a regression checks the actual mesh endpoints. Include the leg script in both export presets now that the live body requires it; keep standalone preview scenes excluded.
- **LEG-04 Scope.** Individual surface-contact IK, planted world-space feet, turning steps and transition blending remain outside this cosmetic integration. Nathan's gait-feel approval and sustained graphical performance checks remain separate from automated tests.

## After the live legs — Claude, 2026-10-11

- **T9e-01 Global slow time is deferred, not built.** Godot's `Engine.time_scale` shrinks each physics tick's delta (1/60 × scale) but keeps 60 ticks a second. The jump planner, jump plans, line, perception and jump hold count fixed 1/60 s ticks (`Engine.physics_ticks_per_second`). Under `time_scale`, walking would slow while a jump, a cue cooldown or memory decay ran at full speed: not the consistent slow-down spec 7 asks for. Lowering the tick rate instead changes those same conversions. A correct slow time needs one simulation clock that every system reads (fewer identical 1/60 s ticks per real second). That is a refactor of approved movement code, so it waits for a decision.
- **T9e-02 No separate survival-pressure setting yet.** Energy drains 0.0006/s to a floor of 0.20 and nothing happens at the floor (spec 11: P0 is not timed against starvation). A setting would change nothing a player can feel. It comes with needs that have consequences (P1).
- **T9e-03 Direction from Nathan (2026-10-11): scientific realism in vision and movement**, and "eventually … a first person spider eye mode so its more immersive". Spec 6.4 makes the default camera third-person. A first-person mode is an optional addition to it, to be designed from salticid vision research: narrow, movable principal-eye retinas; wide, motion-sensitive secondary eyes; UV and green receptors (no red receptor shown in *Phidippus*); depth from defocus. Any rendering of this is an interpretation, labelled as such (spec 16's rule for sound applies to sight too).


## Cross-device planning — Nathan and Chet, 2026-10-10 (America/Chicago)

- **PLATFORM-01 historical planning note (superseded by the 2026-10-14 decision below).** Nathan wants to play the spider game on PlayStation and other devices; Roblox was raised as a possible route. His direction: "lets keep this in mind going forward and we can decide with claude how to approach." Continue the Godot project with this goal in mind. No platform switch, port or rewrite is authorized by this planning note. Nathan, Chet and Claude will decide the route and timing together. A solid Godot core followed by a small Roblox movement/silk/hunting feasibility prototype is Chet's recommendation, not a settled plan. Preserve the desired movement feel, twitchiness, accessibility and scientific-realism direction when comparing options.

## T10a — the spider-eye view (Claude, 2026-10-11)

Nathan: "yeah go ahead please" (to building a first-person eye mode now), "you can mess with any approved code its ok", and the realism direction in T9e-03.

- **EYE-01 An optional first-person view, off by default.** The setting `eye_view` (pause menu "Spider-eye view (first person, V / Y)"; the action `eye_view`, V or the controller's Y, remappable) switches between it and the orbit camera of spec 6.4, which is unchanged. The choice is saved.
- **EYE-02 Where the camera is and what it shows.**
  - The camera sits just ahead of the model's principal eyes (0.53 WU forward, 0.09 WU up) and looks along `gaze`, which the mouse or right stick turns.
  - Its vertical field is 80 degrees.
  - The head, abdomen, eyes and fangs are hidden; the legs are not, so the front legs come into view as on a real spider.
  - The aim ray is the eyes' line of sight, so aiming a jump is looking at where to land.
- **EYE-03 The view turns with the body.**
  - Its up is the body's up, so on a wall or an underside the view is the spider's.
  - It follows at most 240 degrees a second (a 90 degree edge takes about 0.4 s); the body's own 10 degrees a tick was a jolt in first person.
  - The gaze is carried through the same turn, so walking up a wall carries the view up the wall.
  - Walking is relative to the gaze laid on the surface.
- **EYE-04 Movable principal-eye retinas** (Land 1969; Tarsitano and Jackson 1992).
  - In the eye view the inspection cone (the senses' gaze) points where the player looks, within `PRINCIPAL_SCAN_DEG` (30 degrees) of the body's gaze, without turning the body.
  - The cephalothorax tilts toward the gaze within the species' gaze limit (35 degrees), so the floor ahead is in reach.
  - Beyond that reach, standing still with the stick idle, the body turns to face the gaze (as Focus does, at the species' focus rate) and stops within 4 degrees. Walking never fights it.
  - The orbit view keeps its old rule: only Focus and moving turn the body.
- **EYE-05 The picture is an impression, and says so.**
  - The principal eyes are drawn as a sharp oval window, 16 by 24 degrees, at the gaze. That is wider than one eye's instant field of about 10 degrees, to stand for both eyes and their scanning.
  - The window is two-colour: green-weighted brightness plus one contrast, "UV" against green, with blue standing in for UV. No red receptor is known in *Phidippus* (De Voe 1975, *P. regius*).
  - The rest of the view is the secondary eyes: coarse, soft and one-colour (green), as their pigments are mostly green-sensitive.
  - The window fades when the gaze is out of the principal eyes' reach. Movement is still shown by the senses' existing cue markers.
  - Text: "SPIDER-EYE VIEW (an impression)". On switching on, a short explanation is shown for seven seconds.
  - The overlay is a full-screen canvas shader on layer -1, under every HUD. It works in the Compatibility renderer.
- **EYE-06 Not yet.**
  - Depth from defocus (Nagata et al. 2012): it could later set how sure the landing marker is.
  - UV markings on flies and leaves.
  - A frame-difference motion effect in the secondary eyes.
  - An option to keep the horizon level in the eye view.
  - A colour-free accessibility variant of the picture.

## T10b — retinal sweep and colour limits (Chet, 2026-10-10 America/Chicago)

- **EYE-07 Scanning within a stable view.** Nathan requested more scientific accuracy, specifically the two front eyes sweeping and colouring the world. Replace EYE-05's static oval with two narrow softened boomerang-shaped acuity fields. Conjugate horizontal sweep (1.6 s) and slower torsion (8 s, ±25 degrees) use research-informed timescales; geometry, separation and continuous sinusoid are illustrative. No automatic camera shake, no changes to movement, aim, sensing or RNG. Pause stops the clock; Reduced motion holds the current pose. See VISION_RESEARCH.md for primary references and species limitations.
- **EYE-08 Do not infer UV from RGB blue.** Supersedes EYE-05's blue-as-UV mapping and the blanket "no red" wording. The visible picture uses illustrative green-weighted brightness with red relatively dim. The permanent label says UV is not simulated. Related P. regius receptor evidence is not presented as a measured P. audax response or literal colour experience. UV material/lighting data and depth-from-defocus remain deferred.
- **EYE-09 Evidence.** Windows fixed-60 suite 548/548, normal-speed eye tests 12/12, evidence 829573aaf835. Native AMD Compatibility rendering captured three scan phases with no reported errors. No sustained performance or player comfort claim; no new export packages.

## T11a — one game clock, slow motion, the view switch (Claude, 2026-10-11)

Nathan: "the slomo thing sounds cool" (to ROADMAP step 2), "add a button that can easily swtch between first and 3rd person", and that his son needs no more help than Most help gives.

- **CLOCK-01 One game clock.** `SimClock.HZ` (60) and `DT` (1/60 s) replace every read of `Engine.physics_ticks_per_second` in the motor, the jump and line controllers and the senses. This supersedes T9e-01's deferral. `set_speed(s)` runs `60 × s` ticks a real second with `time_scale = s`, so each tick's delta stays exactly 1/60 s. A test plays a stalk and a strike at full and half speed, and the spider and the fly match tick for tick (within 1e-5 WU) with the same outcome and the same fly decisions.
- **CLOCK-02 Slow motion is the player's tool.**
  - Settings: `slow_motion` (saved) and `slow_speed` (25–75 %, default 50 %). It is switched by T or the right trigger (remappable), or from the Esc menu.
  - It applies in played worlds only, and every world puts the clock back to normal when it ends.
  - It is not part of the presets: Nathan's son does not need it as an assist, and it is fun on its own.
- **CLOCK-03 What does not slow.**
  - The player's looking about (stick look, recenter, the aim's return, the eye view's recenter) runs in real time through `SimClock.real_delta()`.
  - That function divides by the scale the engine used for the current frame, so a change made mid-frame does not jerk the view.
  - Everything in the world slows: the twitch, the legs, the retinal scan and HUD fades.
  - Holding Space to aim counts game ticks; that needs checking in play.
- **CLOCK-04 An easy view switch.** V / Y was already the key. Now:
  - a line in third person names it;
  - the eye view's tag names the way back ("third person");
  - the Esc menu has a "First person / Third person" button;
  - the field notes list it.

  The pause menu's buttons wrap onto a second row when there is not room.
- **SPECIES-01 Direction (Nathan, 2026-10-11):** "eventually ... all the different species of jumping spiders", realistic looks, and peacock spiders with "little dances". It is recorded in ROADMAP (Long term) as a direction, not a scheduled task. New species are data profiles, models and behaviours, each with its own vision review. Peacock-spider courtship belongs with spec phase 5 (courtship), and realistic models with phase 6 (production art).

## T11b — the struggle, after Nathan's playtest (Claude, 2026-10-11)

- **STRUGGLE-01 A full bar wins; tapping is harder; the fly weakens.** Nathan: "the tapping when catching a fly should be a bit harder and just stop when it is full."
  - A full grip bar subdues the fly on that tick. The old 2.5–3.5 s timer is gone: it let the bar sit full while the player kept tapping.
  - New numbers: start 0.45, 0.10 a press, drain 0.28/s, a jerk 0.10.
  - The fly's struggles weaken as the bite's venom works, to 40 % of their strength over 5–7 s (a draw from the fly's own stream, in place of the old timer's draw, so the random sequence is unchanged). After 12 s the venom has subdued it whatever the bar shows.
  - Measured on a sweep (`docs/verification/t11b/struggle_tuning.txt`): two presses a second loses the fly; four wins in about 6 s; five in about 4; seven in about 2. Before, about two presses a second held a fly, and 2.5 filled the bar in about a second.
  - "Hold on automatically" now fills the bar by itself in about 1.4 s while the fly still kicks, instead of pinning it full.
  - Kicks shrink with the fly's strength (the jolt the HUD and body show).
- **PLAYTEST-01 Nathan's checklist run (2026-10-11).** Everything on `docs/PLAYTEST.md` worked as it should, by his report. This counts as human evidence for W01 (shadow warning, pause), M04 (the camera, graphical) and E02 (he could say why hunts worked).
  - U01 is met for remapped keys, toggle preparation and mute.
  - U01's controller-only part is open until someone plays with a controller: Nathan has said he has none for the PC.
- **STRUGGLE-02 Evidence.** d9ed40eeeecf: 557 / 557 (Linux headless, fixed 60 fps), including 4 new tests (`tests/integration/test_t11b_struggle.gd`). The struggle, hunt-feel, living-fly and feeding tests pass at fixed 30 and 144 fps, 20 / 20 each. Reports are in `docs/verification/t11b/`. Not run on Windows.

## T12a — sound and the spider's other senses (Claude, 2026-10-11)

Nathan: "get done what you want to work on next and then chet can have the next round". ROADMAP step 3.

- **SOUND-01 Two layers, own volumes** (spec 16).
  - Ambience is human scale: a fridge hum, room tone, distant thuds, and air at the window during the shadow.
  - Cues are the spider's world: fly buzzes, take-offs, a struggling fly, felt vibrations.
  - Master, Room sounds, and Flies and vibrations sliders sit in the Esc menu. 0 mutes.
- **SOUND-02 Generated, not recorded.** All six sounds are synthesised in code at 22 050 Hz with fixed seeds. The fly's buzz is at 195 Hz, within the reported house-fly wingbeat (about 190–200 Hz), and is also inside *P. audax*'s reported auditory range (80–380 Hz; Shamble et al. 2016). The game never claims the player hears what the spider hears.
- **SOUND-03 Vibration through touching solids only** (spec 7).
  - Fly landings (1.0), take-offs (0.8) and footsteps (0.45) are felt through the piece under the fly, then touching habitat boxes, to the piece under the spider's feet.
  - Strength falls to 1/e per 4 WU and halves at each joint. Under 0.08 is not felt.
  - Nothing crosses an air gap, and nothing is felt in the air or on the line.
  - The output is a direction, never a place. The same event gives a thrum, a ripple, a caption and an optional rumble.
  - It is presentation only for now: no sense, memory or fly decision uses it.
- **SOUND-04 Captions on by default** (spec 16, U01). Every meaningful cue gets a bracketed caption with a direction relative to the spider, so muted play loses nothing. A ripple on the screen shows a felt vibration's side.
- **SOUND-05 Slow motion slows sound.** `AudioServer.playback_speed_scale` follows the game speed.
- **SOUND-06 Evidence.** 4daaf055b746: 565 / 565 (Linux headless, fixed 60 fps). The sense tests pass at fixed 30 and 144 fps. Loudness and mix are unheard: headless runs use a silent audio driver.
- **SOUND-07 Audible on laptop speakers** (T12b; Nathan: "i dont hear anything while playing"). Measured: the T12a mix had 91 % of its energy below 400 Hz, at RMS −30 dBFS. Every sound now has audible upper content, its effective brightness at 420 Hz or more. Levels are higher, and there are birds outside the window. A test holds each sound at 350 Hz or more.
- **SOUND-08 Speakers or headphones** (Nathan: "have a setting for switvhing"). `headphones` is off by default: Master shapes for speakers (EQ6 cut at 32 and 100 Hz, lift at 1–3.2 kHz, +3 dB). On, it plays the full range. A hard limiter at −1 dBFS is always on.
- **SOUND-09 Evidence.** 0c295e07077e: 567 / 567 (Linux headless, fixed 60 fps), including 2 new tests (`test_t12b_audible.gd`). The measurements are in `docs/verification/t12b/`. Not run on Windows, and not heard by a person yet.


## T11c — the struggle, harder still (Claude, 2026-10-11)

Nathan, after playing T11b: "yes excellent it all works great now. the tapping should be harder still", then "also make the bar bright red".

- **STRUGGLE-03 Five presses a second, and a red bar.**
  - New numbers: start 0.40, 0.085 a press, drain 0.32/s, a jerk 0.12. The venom weakens the fly more slowly: to 50 % of its strength over 6–8 s. After 12 s the venom has still subdued it whatever the bar shows.
  - Measured on a sweep of 40 flies a rate (`docs/verification/t11c/struggle_tuning.txt`): four presses a second now loses the fly; five wins in about 9 s; six in about 6; seven in about 4; eight in about 2.5. Under T11b four won in about 6 s, and most players at three a second won in about 11.
  - The grip bar is bright red while a fly struggles. When the grip runs low it pulses lighter twice a second, so the warning does not rest on colour. The eating gauge and the energy bar keep their yellow.
  - "Hold on automatically" (in the Guided hunting, No held buttons and Most help presets) is as before: the bar fills by itself in 1.5 s, where it took about 1.4 s (measured in a played world). Nathan's son keeps the easy struggle.
- **STRUGGLE-04 Evidence.** 77c9ef3b3bc6: 568 / 568 (Linux headless, fixed 60 fps), including 1 new test (the bar's colour) and 3 retuned ones in `tests/integration/test_t11b_struggle.gd`. The struggle, hunt-feel, living-fly, feeding and sense tests pass at fixed 30 and 144 fps, 35 / 35 each. Stills of the red bar, full and low, and the reports are in `docs/verification/t11c/`. Not run on Windows.


## Movement realism part 2 — Chet, 2026-10-11

- **LEG-05 Surface contacts are presentation only.** The live rig stores collider-local footholds and renders world-space tips against interpolated hips. It reads WORLD rays for contact placement, including inward searches on narrow leaves, but never writes to the motor, support solver, jump plan or tether. Turning can trigger a swing without translation. Failed searches tuck a foot. A target equal to the existing contact must not trigger another step.
- **LEG-06 Illustrate rear extension with biological limits.** Pairs III/IV straighten during the launch display; the source is Nabawy et al. 2018 (https://doi.org/10.1038/s41598-018-25227-9). Their P. regius observations do not establish each pair's force contribution, and muscle power can meet the calculated jump requirement; do not call this exclusively hydraulic or universal across salticids. The two-rod rig and gait timing remain authored approximations, not anatomical IK.
- **LEG-07 Visible attachment without input delay.** Chen et al. 2013 (https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/) motivates an abdomen/spinneret dip before visual push-off. For instant hops only the third-person model has a 0.067-second contact lead-in and subsequent catch-up; the simulation launches immediately. Silk rendering follows that model during the sequence while line physics stays unchanged. First-person camera timing is preserved. All animations use SimClock.DT; landing compression lasts 0.24 game seconds.
- **LEG-08 Comfort and evidence.** Preserve twitch, idle flicks, lurch and recoil. Reduced motion clears new phases and keeps neutral legs. A fixed first-person distal-front-leg mask avoids proximal geometry near the camera, with no distance-based visibility toggling. Verification and limitations: docs/HANDOFF-surface-legs.md and docs/verification/movement2/.

## T13a — vision realism part 2 (Claude, 2026-10-11)

Nathan: "chet just finished and its freakin amazing you guys are making this so goood!! shall we continue?" ROADMAP step 5. Handoff: `docs/HANDOFF-vision-2.md`; research: `docs/VISION_RESEARCH.md`.

- **EYE-10 The surround shows motion.**
  - The secondary eyes are motion detectors (Zurek et al. 2010; Zurek & Nelson 2012). The sensor keeps a presentation-only record of what its sightline checks found moving, at or above the existing motion threshold.
  - In the spider-eye view each moving thing gets a ring that pulses at 3 Hz and a faint halo where it is drawn. A thing inside the sharp retinal fields gets less or none. It fades 15 ticks after the thing stops. Hidden things never appear.
  - Reduced motion holds the ring steady. The orbit view has none.
  - Nothing but the picture reads the record: the memory, cues and behaviour are unchanged.
- **EYE-11 Comfort switches, off by default.**
  - `eye_level_horizon`: the view keeps the world's up; near-vertical gazes hold the last up, so it never flips. Look controls then turn the picture about the view's own axes.
  - `eye_colour_free`: the same green-weighted brightness, in grey; the label says so.
  - Both are labelled as comfort, not biology: a spider's eyes roll with its body.
- **EYE-12 The eye view's opening notice sits under the top lines.** At 70 % of the screen's height it covered the sound captions for its first seven seconds.
- **EYE-13 Depth from defocus waits for Nathan.**
  - Nagata et al. 2012: jumping spiders judge distance from image defocus, and jump short in red light.
  - A faithful version makes jumps less accurate in poor or reddish light and at long range. That changes gameplay and the M01–M03 movement gates.
  - A marker that only looked unsure would mislead. Proposed, if wanted: an option, off by default, so Most help is unaffected.
- **EYE-14 UV stays unsimulated.**
  - A literature search found good numbers for clear glass (about 85–88 % at 380 nm) and green leaves (about 5 % UV against 13–17 % green).
  - It found only a qualitative result for white TiO2 paint (dark in UV), and none for the house fly's body or wings, *P. audax* markings or several sill materials.
  - Building UV with the prey guessed would repeat EYE-08's mistake. The label "UV not simulated" stays. What is known, and what is missing, is in VISION_RESEARCH.md.
- **EYE-15 Evidence.**
  - db112e2fa006: 585 / 585 (Linux headless, fixed 60 fps), including 9 new tests (`test_t13a_motion_surround.gd`, `test_t13a_eye_comfort.gd`).
  - Eye, sensor, perception and sense tests: 69 / 69 at fixed 30 and 144 fps.
  - Stills and reports are in `docs/verification/t13a/`.
  - Not run on Windows, and not played yet.

## Direction — a calm game that teaches (Nathan, 2026-10-11)

- **LEARN-01 Teach through play, truthfully.** Nathan: "this could also teach people about jumping spiders right? it will be like a super beautiful, serene, slow play. Hyper real environment to slowly explore, very detailed and proportionate to tiny spiders, just super natural, presenting facts maybe as you learn to play etc. something to keep in mind."
  - Recorded as a long-term direction (ROADMAP, Long term), not a current task.
  - Facts would come through the spec's field notebook as the player first does things: short, optional, each with its source.
  - Before anything is taught as fact, the game's deliberate simplifications get fixed or plainly labelled: tuned gravity, the "fly-like" prey, UV and depth from defocus.
  - Keep the true scale (1 WU = 1 cm) and the slow, pressure-free default.

## Release goal (Nathan, 2026-10-11)

- **RELEASE-01 Put it in the world.** Nathan: "i definitely want to put it in the world, i love these little guys so much and many do. I dont want to get rich or anything but i want people to play it. I am willing to give it all the time it needs if you and chet are with me."
  - The target is a first release, "The Windowsill": one habitat, one species, one whole life, the field notebook, calm by default.
  - Windows and web builds, free or pay-what-you-want on itch.io first.
  - The order of work is in ROADMAP ("The goal"). More species and habitats follow the first release.
  - Not goals: profit, ads, data collection, engagement pressure.


## Friends slice handback (Chet, 2026-10-12)

- **RELEASE-02 Label test builds and preserve evidence scope.** Package Windows x64 and web from unchanged game source 48b84a0 (585/585 Windows, db112e2fa006), with controls, engine notices and checksums. No public release or itch.io upload yet. Binary ZIPs stay outside Git; reproducible instructions and evidence stay in Git.
- **PERF-01 Measure before simplifying.** Five-minute real rendered, scripted windowsill run at 720p on battery: 56.8 fps average, 21.448 ms p95; eye view is slowest. F01's measured-misses/report alternative is satisfied, not its 16.7 ms target. Retain capture/setup spikes and state instrumentation limits. Next: capture-free release A/B, eye blur cost, named physics timers and first-use hunt work. No twitch, SimClock or game-physics change.
- **RELEASE-03 Do not turn automation limits into a pass.** Both exports render; browser inputs and preference reload worked. Native tool gives V/Escape the same wrong physical code, so native keyboard play is inconclusive. Controller-only play and sound listening need people/hardware. Browser UnknownError remains unexplained. Every gate is labelled in verification/release-slice/GATES.md, including superseded S01 and open human gates.

## LEARN-01, first notebook — Claude, 2026-10-11

Built while Chet's round (ROADMAP step 6) was paused; kept on Claude's branch until his round is in main.

- **LEARN-02 The naturalist's notebook, first version.** Spec 4 calls for "an optional naturalist notebook with sourced facts, separated from in-world perception".
  - **Pages:** fourteen, in `data/notebook/pages.json`. Each page is a few true sentences, an "In this game" line where the game simplifies, and full sources.
  - **When pages open:** the first time something happens in play: the start, a jump, a far jump and a long one, the spider-eye view, 20 s and 60 s in it, the motion shimmer, a fly recognised, a catch, a meal, a felt vibration, a buzz, a rest.
  - **Where it is kept:** the notebook belongs to the player. It lives in its own file, `user://notebook.cfg`, and only when settings are saved, never in a test's world. It survives checkpoints and new lives, and is never part of the world's snapshot. It decides nothing in the game.
  - **On screen:** N (controller: D-pad up), or "Notebook" in the Esc menu, opens it and the game waits. Esc, B or N closes it.
  - **No checklist:** only found pages are listed, with no count of pages left (spec 4: discovery must not become a completion checklist).
  - **New-page note:** a short note at the bottom left says when a page opens; the setting "notebook_notes" turns it off.
  - **Remapping:** the key and the button can be changed like the others.
- **LEARN-03 Sources and honesty.** `docs/NOTEBOOK_SOURCES.md` records how far each source was checked. Citations were confirmed, but no paper was read in full this round, so the pages stay within what abstracts and textbooks state. Each source should be read before a public release. Several pages name what the game simplifies: depth from defocus, UV, the retreat not yet spun, the venom's timing.
- **LEARN-04 Evidence.** 9d96a61e810c: 591 / 591 (Linux headless, fixed 60 fps; the same after merging Chet's friends-slice round, which changed no game code), including 6 new tests (`tests/integration/test_learn01_notebook.gd`). Notebook, pause-menu and controller tests: 17 / 17 at fixed 30 and 144 fps. Stills and reports are in `docs/verification/learn01/`. Not run on Windows.

## One whole life: death (Nathan, 2026-10-12)

- **LIFE-01 Death is real.** Nathan: "death can be real and jarring. not sensationalized but my kids are allowed to encounter reality."
  - **Default preset:** "Natural" (spec 11): the individual can die, and the player continues as another spider in the same windowsill, or goes back to the last rest.
  - **Gentle:** stays available as an explicit choice. It is not switched on by "Most help", which changes how the game is played, not what can happen in it.
  - **Presentation:** a death is shown plainly and briefly: what happened, a quiet moment, then the life's summary (places, escapes, rests, meals, moults; no kill count or score). No gore, slow motion lingering, shock sound or dramatic music.
  - **Fairness:** every death can be explained with information the player could have learned (spec 11): warnings, the predator's approach, the spider's hunger.
- **LIFE-02 The plan for one whole life.** `docs/LIFE_DESIGN.md`:
  - Three clocks, with time passing at rest.
  - Hunger shown by the abdomen's size, not a bar to watch.
  - Moulting in the retreat.
  - One predator, the mud dauber wasp, the best-supported for a windowsill.
  - Death shown plainly, then a summary, then a choice to go back to the last rest or continue as an unrelated spider.

  The biology comes from a literature search (most papers not read in full). The four questions at its end are Nathan's to answer.
- **PERF-02 A cheaper eye picture (T13b; evidence 2c7264139c03, 591 / 591, Linux headless).** The soft surround reads the picture six times instead of twelve, and the full-size picture only where the sharp retinal fields show. On software rendering the picture costs about a third less (32 ms down to 21–23 ms); its look changes by about 2/255 (`docs/verification/eye-perf/`). A mipmap version was slower on software rendering and is left for Chet to try on the laptop. Laptop timing is Chet's next round.
- **LIFE-03 Nathan's answers to the life plan** (2026-10-12): "your suggestions work great and your assumptions are accurate."
  - One life takes about 2–3 hours over roughly 10 game days, with 3 moults.
  - The mud dauber wasp is the first predator.
  - After a death, continue as an unrelated young juvenile elsewhere on the sill.
  - The notebook says plainly that the wasp paralyses the spider to feed its young.

## Laptop eye comparison and rebuilt friends slice (Chet, 2026-10-12)

- **PERF-03 Keep six reads on the laptop.** Plugged-in 720p, before shader 4c07efa versus T13b 40aceee inside the same fa32368 scene: live normal-eye GPU p95 7.878 -> 6.612 ms, quarter-speed 7.768 -> 6.279 ms. Overall frame p95 18.036 -> 18.109 ms under VSync: reduced GPU work, no demonstrated whole-game FPS increase and strict 16.7 ms goal still missed. No screenshots during timing. A four-read mipmap implementation was slower in the frozen-view screen (5.120 ms versus T13b 4.823 ms picture-on), so do not ship it. Single live runs, phase/setup spikes retained, source/debug runtime scope explicit; raw traces and exact shader fixtures in verification/eye-perf/.
- **RELEASE-04 Refresh friend packages with notebook and T13b.** fa32368 game source, Windows 591/591 / 2c7264139c03. Windows/web ZIPs in Downloads/The-Windowsill-Playtest-2026-10-12-T13b; checksums in eye-perf/friend-builds.json. Web eye view and N notebook verified, native launch/render smoke check passed. Existing Chromium error and human acceptance checks remain open. No publication or gameplay changes. LIFE_DESIGN round 0 complete; clocks/hunger next.

## One whole life, round 1: clocks and hunger (Claude, 2026-10-12)

Nathan, while Chet's measuring round was paused: "if there is anything at all you can think of to do feel free". Kept on Claude's branch until Chet's round is in main.

- **LIFE-04 Three clocks, and nights in the retreat.**
  - `scripts/life/life_clock.gd` holds the windowsill's time of day and the spider's age in days, separate from SimClock. It moves only with action time, in the habitat loop, so pausing never passes time, and it never touches jumps.
  - About 12 waking hours pass in about 15 minutes of play (LIFE-03: about 10 days in 2–3 hours).
  - A rest in the retreat from 18:00 until 07:00 is a night's sleep. The hours pass at 1.4 an action second, never more than one tick's worth at a time, until 07:00. Moving, or anything that ends the rest, wakes the spider. The morning keeps a new checkpoint and says "Morning, day N".
  - A rest by day passes no extra time.
  - The caption names the day and part of the day. Evening and night have their own lines; the crack offers "sleep until morning".
- **LIFE-05 Hunger by the hour (life mode).**
  - On the windowsill, energy drains with game hours: 0.021 an hour awake, 0.007 asleep. A full reserve lasts about three days without food, and one fly (0.35) feeds the spider for about a day. The 0.20 floor is gone: the reserve can run out, and the hours at zero are counted (`starving_hours`). Nothing follows from them yet; death is round 5.
  - The old slow per-second drain with its floor stays wherever there is no life clock (the lab, tests that build a NeedsModel alone).
  - The compression is on purpose: real *Phidippus* go weeks without food. The notebook says so.
- **LIFE-06 Day and night on the sill.**
  - The sun's strength, colour and height, the room's ambient light, the sky and the window's glow follow the hour. Night is dim and blue, never black. The passing shadow still dims the sun.
  - The sensor's reach is 30 % of its daytime range at night (`SensorSystem.range_scale`, `reach_wu()`): jumping spiders hunt by sight in daylight.
- **LIFE-07 Body condition you can see.** The abdomen is drawn wider and longer as the reserve fills and narrower as it empties: 0.84 to 1.14 of its width, about today's size at the start (0.55). It is display only (Jakob, Marshall & Uetz 1996; Foelix 2011).
- **LIFE-08 Checkpoint schema 4 and three notebook pages.**
  - Checkpoints keep the clock (`life`) and life mode's numbers (`starving_hours`, `hour_accumulator`), so a checkpoint loads to the same energy.
  - A schema-3 checkpoint upgrades to day 1, 09:00.
  - New pages: "Home before dark" (first morning), "Hungry, yet at home" (first low reserve), "A full abdomen" (first full reserve). Sources are in NOTEBOOK_SOURCES.md.
- **LIFE-09 Evidence.** 7c9539fd72c1: 600 / 600 (Linux headless, fixed 60 fps), including 9 new tests (`tests/integration/test_life01_clock_hunger.gd`). Life, notebook, windowsill, checkpoint, needs, feeding and sensor tests: 68 / 68 at fixed 30 and 144 fps. Reports and stills are in `docs/verification/life01/`. Not run on Windows.

## Modes and how they unlock (Nathan, 2026-10-12)

- **MODES-01 The main life is Standard until you finish it; Easy is earned; Free play is separate.** Nathan: "the difficulty default for 'story' progression or however it goes is the standard mode only until you beat the game then you can play on easy, then we can have a play mode for easy fun play that is seperate from the main experience. I think that will be rewarding gameplay."
  - **The main life ("The Windowsill"):** played on Standard, the "Natural" rules of LIFE-01, until the player has finished it once. After that, Easy can be chosen for later lives. This supersedes LIFE-01's "Gentle is always available as a separate choice" for the main life.
  - **Free play:** a separate mode for easy, relaxed play on the sill, with its own save. It does not count toward finishing the main life. It can be played from the start.
  - **Confirmed by Nathan ("I agree with your suggestions"):** what is locked is how hard the world is: survival pressure, the predator, death. How the controls help is not locked: aim help, holding prey automatically, toggles, slow motion, Reduced motion and text size stay available everywhere. Spec 17 keeps "survival pressure and execution difficulty" independent, and locking control helps would shut out players who need them, including Nathan's son, who uses Most help.
  - **Confirmed:** "finishing the game" means bringing one spider through its whole life to adulthood (LIFE_DESIGN.md: three moults). Courtship and eggs come later, in phase 5.
- **FEEL-01 It must feel like being the little spider.** Nathan, 2026-10-12: "it needs to feel really like being the little spider." This is a test for every feature, alongside scientific realism.
  - Does it put the player at the spider's size, in its senses, its caution and its vulnerability? Or does it feel like a person looking down at a toy?
  - Consequences to weigh as we build:
    - The camera low and close.
    - Scale cues from the human world: a mug, a pencil, a hand or footsteps through the sill.
    - A predator that is huge and fast at this size.
    - Sounds heard from the spider's place in the room.
    - The eye view as a first-class way to play.

## LIFE round 2 laptop verification (Chet, 2026-10-12)

- **LIFE-10 Retain current light and body-condition presentation.** Windows 600/600 / 7c9539fd72c1. Staged rendered checks show day/dusk/night in both views, a real tick-by-tick night's rest with day-two morning checkpoint, and thin-to-full abdomen smoothing through the actual needs notifications. Night preserves silhouettes and captions; fine eye-view detail is less readable. No lighting/gameplay retune; human comfort checks remain useful. Fixture grants are not a caught-meal playthrough.
- **PERF-04 Moving-sun measurement.** Plugged-in Balanced, Radeon, 720p VSync, eight 30-second morning/midday/dusk/night view phases, no screenshots: mean 16.677 ms, p95 17.274 ms, max 94.642 ms. No dusk/night frame above 33.3 ms. Midday eye GPU p95 6.417 ms versus night eye 5.691 ms. Strict 16.7 ms frame goal remains missed. One source-runtime route, no frozen-sun control; do not infer isolated shadow cost or release performance. Raw evidence in verification/life02/.
- **RELEASE-05 Refresh friends with days, nights and hunger.** Nathan explicitly requested Windows and web rebuilds. Unchanged 5ea6a45 game source, new LIFE1 Downloads folder, README/licenses/ZIP checksums. Windows launch/render and browser keyboard/view/notebook smoke checks; embedded browser pointer-lock WrongDocumentError plus Chromium UnknownError remain unresolved. Mouse-look/controller/listening not claimed passed. No itch.io upload.

## One whole life, round 3: moulting (Claude, 2026-10-12)

Built while Chet's round 2 was paused (out of usage, results not yet pushed), on Claude's branch only. It is merged after his round.

- **LIFE-10 Growth by moulting** (`scripts/life/growth.gd`, run by the habitat loop).
  - **Stages:** young juvenile, juvenile, subadult and adult: three moults in one life (LIFE-03).
  - **Ready:** 0.9 of energy eaten since the last moult (about two and a half flies, read from the needs' ledger) makes the spider ready. The screen and the caption say so.
  - **The moult:** resting in the crack while ready begins it. It cannot be stopped. Its 12 game hours pass at the sleeping rate, a tick's worth at a time, and do not stop at morning.
  - **Afterwards:** the stage advances, the old skin stays where the moult happened (drawn as a pale husk, saved), and a checkpoint is kept.
  - **The soft skin:** for 10 game hours the spider is pale and its jumps reach 70 % as far, through the same reach factor as the "Jump reach" setting, via `main.apply_reach()`. Then the skin hardens.
  - **Adult:** the third moult makes an adult, which finishes the main life (MODES-01; the unlock itself is round 5).
- **LIFE-11 What is simplified, and said so.**
  - Real spiders usually stop eating before a moult and stay in the nest for days (*P. johnsoni*: about 6 before and 2 after, Jackson 1979). The game does not stop the spider eating, and it compresses the days.
  - The soft period's length is a design assumption: no measurement was found.
  - The body is drawn the same size at every stage, and the physics never changes. Drawing the growth is left to the rig's owner (Chet), so that the planted feet stay right.
  - The notebook pages say all of this.
- **LIFE-12 Checkpoint schema 5 and three notebook pages.**
  - Checkpoints keep growth (stage, food since the last moult, readiness, the moult and the soft skin still to pass, where the old skins lie). Schema 4 upgrades to a young juvenile.
  - New pages: "Outgrowing a skin" (ready), "A new skin" (moulted), "Grown up" (adult). Sources are in NOTEBOOK_SOURCES.md.
- **LIFE-13 Evidence.** f82620887f67: 605 / 605 (Linux headless, fixed 60 fps), including 5 new tests (`tests/integration/test_life03_moulting.gd`). Moulting, life, notebook, windowsill, checkpoint and jump-input tests: 61 / 61 at fixed 30 and 144 fps. Reports and stills are in `docs/verification/life03/`. Not run on Windows.

## Letting down on a line (Claude, 2026-10-12)

Nathan, after finding the dragline only by a missed jump at the dry leaf tip: "can you add an easy way to lower yourself from anywhere". Built on Claude's branch while Nathan tested moulting.

- **SILK-01 One button lets the spider down on its line** (`SpiderMotor.begin_drop()`; the `drop_line` action, F and D-pad down, both remappable).
  - **From a wall, a stem or an underside** it lets go at once.
  - **From ground** (a leaf top, the planter, anything it stands on), it walks itself to the nearest edge with at least 1 WU of room below, goes over it as walking does, and lets go there. Of two edges equally near, the one it faces wins. Moving the stick or pressing cancel stops the walk.
  - **The line** is anchored where it held on, and 0.5 WU of it runs out at once. After that it is the same line as after a miss: hold the button (or S / stick down) to lower, W / stick up to climb back, hold Q / B to let go.
  - **Refused, and said so:** on the floor or the front lip (nothing below, or only a small step), on a surface that will not hold silk, and while feeding or resting.
- **SILK-02 Letting itself down, it does not catch on what it brushes.** After a miss the spider takes hold of any face it touches. A spider that let itself down would then catch on the leaf it has just left. So, unless it is reeling in, it takes hold only of ground at least 0.5 WU below its anchor (the floor, a lower leaf), and slides past the rest. Reeling in, it takes hold of anything, as before.
- **SILK-03 Biology.** No new claim is taught. Jumping spiders do let themselves down on draglines, but no source has been read for it yet, so the notebook's dragline page only gains a line about the game's button.
- **SILK-04 Evidence.**
  - fe3af29213dd: 612 / 612 (Linux headless, fixed 60 fps), including 7 new tests (`tests/integration/test_drop_line.gd`).
  - The drop, line, silk, notebook and pause-menu tests: 63 / 63 at fixed 30 and 144 fps.
  - Stills and a tick trace: `docs/verification/drop/`. Not run on Windows.
  - The suite now runs past 1,500 s of frame time (1,502 s), so the runner's watchdog fired on a passing test. It is 2,400 s now, and the report prints `suite_seconds`.
- The "New in your notebook" note now wraps at the bottom left, clear of the prompts centred at the bottom of the screen, which it used to overlap.


## Drawn growth (Chet, 2026-10-12)

- **GROW-01 Visual scale only.** Stages 0–3 use 1.0, 1.15, 1.32, 1.50.
  Artistic readability factors, not measured biological instars. This supersedes
  LIFE-11's same-size drawing limitation. Motor, collider, jump and silk rules
  remain unchanged. Scale around the existing support plane; compose the
  growth lift with twitch/recoil so feet retain their world-space anchors.
- **GROW-02 Scale the gait with the drawing.** Contact probes, step thresholds,
  swing lift and top-level world-space rods follow visual size. Growth does
  not reset all planted contacts. Habitat application updates size on both
  moult and checkpoint restoration; softness/abdomen condition remain separate.
- **GROW-03 Windows evidence.** Baseline 612/612; final 618/618, baedf0eb21d9;
  targeted 26/26 at fixed 30/60/144. Staged native three-moult and adult silk
  checks complete. Battery-only moult timing ~59–60 fps mean, p95 17.58–17.88 ms,
  max 71.50 ms, not an F01 pass. Friend Windows/web ZIPs from 537d1ce rebuilt.
  See verification/growth-windows/RESULTS.md for method, caveats and screenshots.

## One whole life, round 4: the mud dauber wasp (Claude, 2026-10-13)

Built after Chet's drawn-growth round (main 6c51cca, 618/618 here too). Plan: LIFE_DESIGN section 4. Nathan's direction: LIFE-01 ("death can be real and jarring. not sensationalized"), LIFE-03 (the mud dauber first; the notebook tells the plain truth), MODES-01.

- **LIFE-14 When it comes** (`scripts/predator/wasp_director.gd`).
  - At most one visit a day, between 10:00 and 15:30, on about 60 % of days.
  - Never on the first day, never before the spider has finished its first meal, and never while it rests or moults in the crack.
  - Whether a day has a visit, and at what hour, follows from the world's seed and the day alone, so a return to a checkpoint meets the same wasp.
- **LIFE-15 Warned, then searched for by sight.**
  - **Warning:** the wasp is heard for 8 s, coming in over the window frame, before it can look for anything. Its own shadow crosses the sill, and the spider feels it land when they share connected surfaces ("heavy landing", "heavy footsteps").
  - **Search:** it moves between 15 authored places where a spider might be. It hovers and looks, and on open surfaces it sometimes lands and walks with its antennae flicking. Where it goes never depends on where the spider is.
  - **Noticing:** while it can see the spider (within 7 WU, a clear line, not in the retreat), its notice grows. Movement makes it grow far faster (0.25/s still against 1.85/s walking, at point-blank range, falling off with distance). Out of sight, notice fades.
  - **Before a strike:** once it has seen the spider, it turns toward it, comes to 1.2 WU, and looks for 1.5 s.
  - To the spider's senses it is movement (shimmer in the eye view), never prey: its percept is capped at MOVEMENT.
- **LIFE-16 Escapes and the catch.**
  - **The crack is safe:** nothing in the retreat is ever seen.
  - **Breaking the approach:** a jump, a drop on the line, the retreat, or getting out of sight. Then the wasp is confused for 4 s and searches at least 6 WU away.
  - **The strike** is a 0.35 s lunge at where the spider was, so a spider that moves off is missed.
  - **Leaving:** after 45 s of searching it gives up and flies away. It also gives up on a spider it cannot reach within 6 s.
  - **Caught:** the spider goes still (`SpiderMotor.seize`) and is carried up and over the frame. Then the screen dims, one plain line says what happened, and it offers "Back to your last rest" ("Start a new life" when there is none) and the notebook (`scripts/presentation/caught_panel.gd`). No gore, no score.
  - Round 5 builds death and continuing (the summary, another spider, Natural and Gentle, the modes) on this.
- **LIFE-17 What is simplified, and said so.**
  - The wasp's numbers are design choices tuned for fairness, not measurements: sight range, notice rates, timings, its 120 Hz hum and its heavier footsteps.
  - The retreat being completely safe is a design choice.
  - Dropping on a line to escape is the game's choice. No source shows jumping spiders doing it, and the "Getting away" page says so.
  - The wasp is a placeholder drawn from primitives, for Chet's model.
- **LIFE-18 Saves, pages and evidence.**
  - Checkpoint schema 6 keeps the wasp's record: the day of its last visit, and this life's visits and escapes. A visit going on is not kept, because the spider rests in the crack where the wasp cannot find it. Schema 5 upgrades to "no visits yet".
  - Three notebook pages: "A hunter of spiders", "What the wasp does" and "Getting away". Their sources could be checked only at snippet and abstract level, because the build environment's network refused the sites; NOTEBOOK_SOURCES.md says which.
  - Tests: 10 new (`tests/integration/test_life04_wasp.gd`), including "every catch comes at least 8 s after the warning and 1.5 s after a visible look". Wasp and related tests: 72 / 72 at fixed 30, 60 and 144 fps. Stills: `docs/verification/life04/`.
  - Evidence e962dffc61cb: 628 / 628 (Linux headless, fixed 60 fps; 1,701 s of frame time against the 2,400 s watchdog). Not run on Windows.


## Wasp presentation and Windows check (Chet, 2026-10-13)

- **WASP-01 Drawn Sceliphron.** Replace single-rod legs and box wings with
  jointed black/yellow legs, smoky tapered membranes with simplified veins,
  bent antennae and a narrow yellow petiole. Head-to-abdomen length ~2.47 WU.
  Keep pose(mode, beat, search), -Z forward and all AI/physics rules. Geometry
  remains stylised and original; species references and simplifications in
  verification/wasp-windows/RESULTS.md. Wing/step beat now uses SimClock.DT.
- **WASP-02 Audible warning design.** Preserve the 120 Hz designed base, add
  480–1440 Hz harmonics for small speakers, use 40 WU unit distance, +3 dB
  source level and a -3 dB near-field cap. Retain cue mute, speaker EQ and
  limiter. Digital recording and harmonic checks pass; actual laptop-speaker
  loudness and children's comfort still need human listening. No biological
  wingbeat-frequency claim and no extra sting impact sound.
- **WASP-03 Seized means still.** Draw legs inward, clear stance anchors and
  stop visual recoil/twitch/jump animation while seized. Keep growth/tint and
  physics untouched. Hide lower gameplay HUD layers on the catch screen so
  maximum text is clear; notebook remains available. Optional looming response
  deferred; player control is unchanged.
- **WASP-04 Evidence.** Baseline Windows 628/628 (e962dffc61cb); targeted 28/28
  at 30/60/144 (a45591fefdf2). See the full report in wasp-windows for the final
  full-suite result. Native staged warning/search/inspection/carry/catch at
  1080p and 150% text checked. Battery visit averages 54.5 fps, p95 22.069 ms,
  worst 183.558 ms in arrival. Strict F01 remains open. No physical controller
  or child playtest claimed.

## One whole life, round 5: death and continuing (Claude, 2026-10-13)

Built after Chet's wasp presentation (main 5c56ef8, 632/632 here too). Plan: LIFE_DESIGN section 5. Nathan's direction: LIFE-01, LIFE-03 (continue as an unrelated young juvenile), MODES-01 (Standard until the main life is finished, then Easy; free play apart; control helps never locked).

- **LIFE-19 Two sets of rules.**
  - **Standard ("Natural")** is the main life's rules: hunger and the wasp can kill.
  - **Gentle** is Easy's and free play's rules, and nothing kills:
    - the wasp still visits, warns and looks, but its strike is a touch with the antennae, and then it leaves;
    - hunger drains at half the rate and never falls below 0.1, so a gentle spider is hungry at worst.
  - Each world has a mode ("main" or "free") and rules ("standard" or "gentle"); free play is always gentle. Checkpoint schema 7 keeps both (`life_rules`). Older checkpoints are the main life on Standard.
- **LIFE-20 Starving, with every stage on the screen.**
  - A full reserve lasts about three game days.
  - At zero, the top line says "Starving". After 24 hours at zero it says the spider "will not last another day", and the spider is too hungry to sleep: it rests but stays awake.
  - After 48 hours at zero it dies (`NeedsModel.starving_streak_h`; any meal resets it). "Weak" therefore always shows for at least a whole game day before death, about half an hour of waking play.
  - A notebook page, "Going without food", says what is known and how the game compresses it.
- **LIFE-21 The end of a life** (`main.end_life`, `caught_panel.gd`).
  - **The screen:** quiet and dim, then one plain line by cause ("The spider starved." or the wasp's line) and a second plain line.
  - **The summary:** how long it lived, the stage and moults, its meals, and the wasp's visits and escapes. No score, rank or count of kills. Choosing at once skips it.
  - **The way on:** "Back to your last rest" (when there is one), "Continue as another spider", or the notebook.
  - Gentle rules never end a life.
- **LIFE-22 Another spider** (LIFE-03, `main.continue_as_another`).
  - A young juvenile on day 1, on the floor somewhere new, away from the crack. Four spots, taken in turn.
  - The top line says plainly, for 12 s, that it is not related to the last.
  - The life that ended is kept in the player's progress. Its checkpoints are put away, so "Continue" never brings the dead spider back.
  - The notebook goes on; the spider's memory does not.
- **LIFE-23 Modes and the start menu** (MODES-01, `start_menu.gd`, `scripts/life/progress.gd`).
  - **The progress record:** the player's progress (the main life finished, deaths, the lives that ended) is the player's, like the notebook. It is kept in `user://progress.cfg` only when settings are saved, and never in a checkpoint.
  - **Finishing:** an adult of the main life on Standard finishes the main life and opens Easy, and the screen says so. Easy lives and free play never count.
  - **The start menu** opens at launch, and from the pause menu ("Start menu"). It offers:
    - continue the main life's last rest;
    - begin a new life (a second press confirms when a life is going on, which is then put away);
    - a new life on Easy, once earned; until then a line says how it opens;
    - free play, with its own save in `saves/free`;
    - the notebook, and Quit (hidden on the web).
  - The top line names the mode: THE WINDOWSILL, THE WINDOWSILL (EASY), FREE PLAY.
  - Control helps stay in the pause menu in every mode.
- **LIFE-24 Evidence.** 8 new tests (`tests/integration/test_life05_death.gd`). Round 5 and related tests: 79 / 79 at fixed 30, 60 and 144 fps. Full suite: evidence a4165eb2beb4, 640 / 640 (Linux headless, fixed 60 fps; 1,726 s of frame time). A normal launch was checked to open the start menu. Stills: `docs/verification/life05/`. Not run on Windows.


### LIFE-25 — Windows whole-life checks and readable menu choices (Chet, 2026-10-13)

Accept uses the focused start/end choice, including A/Space; the notebook draws above both. End choices stack within the scaled viewport. Start-menu scrolling follows focus at large text sizes. Starting over requires two presses on the same mode, with a short confirmation on that button. Paused screens suppress discovery toasts. Four new regressions cover focus/layering, layout and cross-mode confirmation.

### LIFE-26 — Warm the wasp's first draw during loading (Chet, 2026-10-13)

Two offscreen draws in an isolated 96 x 96 viewport at load; no gameplay actor/percept or director changes. Skip headless; release temporary resources on completion/early owner exit. On external power at 1080p, two arrival maxima of 112.815/107.593 ms became 19.923/21.622 ms; production 19.848 ms. Consistent with first-draw material work, not a proven driver-level diagnosis. Loading cost unmeasured. Inspection/eye-view transition still reached 37.753 ms; F01 is open. Raw CSVs/method: `verification/life06-windows/`.

### LIFE-27 — Whole-life friend handback evidence (Chet, 2026-10-13)

Baseline Windows 640/640 matches Claude's a4165eb2beb4. Final Windows 644/644, evidence 2c1c789ef545, fixed 60 fps; related 27/27 at 30/60/144. Staged native starvation, catch/another/notebook, checkpoint return, adult/Easy, free-play touch and 1080p large-text screens checked. Windows release keyboard/mouse menu and Web menu/hidden Quit/eye view checked. Physical controller unconnected, speaker listening not performed, embedded-browser pointer lock unresolved. Fresh friend ZIPs (manifest in life06-windows) are for Nathan/son/friends' round-6 whole-life playtest, not a claim of release readiness.

### VISUAL-01 — A truer-looking bold jumper, and a Roblox port scaffold (Perplexity Computer, 2026-10-14)

Nathan handed over a Gemini plan ("Spider Project Upgrade and Roblox Port Plan"). Drawn only: no collider, motor, jump, sense, prey, save or settings change.
- **Legs:** three drawn segments per leg (femur, patella-tibia, metatarsus-tarsus), stout front legs, pale banded knees and ankles. The extra parts live in `Body/LegDetail`; `Body/Legs` keeps its sixteen rods and the feet are exactly where they were.
- **Body:** a squared eye face, glossy principal eyes with catchlights, elongated iridescent green-blue chelicerae (`shaders/iridescent_chelicerae.gdshader`), pedipalps that drum in bursts while standing (stilled by Reduced motion, hidden in the eye view), a pale basal band, and spots that go from orange (young juvenile) to white (adult), as in *P. audax* (Wikipedia; Univ. Arkansas Arthropod Museum). Rim lighting on body and legs for the setae.
- **Sill:** filmic tone mapping, fine world-space grain on wood and mottling on brick and leaves (tints only; colours unchanged), and faint dust motes (`sill_atmosphere.gd`, CPU particles, fade at night).
- **Not taken from the plan:** Forward+ on Windows, SSAO/SSIL and depth of field (would change `project.godot` and the Web build, and need Chet's GPU check); a unilateral gait in the Godot game (real spiders alternate; it is a toggle in the Roblox port only). Several file names in the plan did not exist (`cosmetic_spider_body.gd`); the work follows the real files.
- **Roblox:** `roblox_port/` (ignored by Godot via `.gdignore`), a Rojo project. Data generated from `data/*.json`, `JumpMath`/`SupportMath` ported and checked against Godot's own numbers, the sill box for box, and a client spider that walks every attachable face, hops, aims and leaps, trails a dragline and steps on procedural three-segment legs. Not yet run inside Roblox Studio.
- **Evidence:** 87c44d9c8206, 644 / 644 (Linux headless, fixed 60 fps). Legs, eye view, growth, moult and wasp body 36 / 36 at fixed 30 and 144 fps. Stills `docs/verification/visual01/`. Not run on Windows; frame time with the extra parts unmeasured (F01 is open).


## 2026-10-14 — Roblox becomes the active project

- **PLATFORM-01 Decided: Roblox only.** Nathan: "Let's only work in roblox going forward." His children and their friends should play on PC and tablets without a separate game installation (Roblox's client is still required), with playing together possible later. Merge both parts of `perplexity/visual01-roblox-port` c87ce00 into main. Keep `roblox_port/` active. Freeze Godot as the runnable reference and golden-data source; do not edit SPEC.md. Carry over the spec's pillars/guardrails, accepted amendments and D-entries as design intent, data/*.json tuning, and Godot tests as reference behavior. This supersedes the earlier pending platform note and the itch.io-first distribution plan in RELEASE-01, while retaining the goal of a complete calm windowsill life. Cost: a full port; engine-dependent acceptance requires Studio rather than Godot's headless suite. Pure Luau logic still runs headlessly against Godot goldens. Do not claim PlayStation validation from PC/tablet work.
- **ROBLOX-01 First appearance and controls.** Use an appearance table, with the daughter's reference committed under docs/art. Black body, pale abdomen band, five main white spots, fine speckles, pale cheeks, banded legs/palps, stout front legs. Nathan asked for a cuter spider: rounder head/abdomen and slightly larger primary eyes. Keep physics independent. This artist-directed design stays black and white across stages; future growth/softness/condition are separate layers. Basic touch buttons and gamepad actions share the keyboard input path; physical-device and accessibility acceptance remain open.
- **ROBLOX-02 Solo and persistence boundary.** Solo servers first, maximum players 1 at publication; one private windowsill per player/server. No shared-world multiplayer yet. The current client rig is prototype state. Move authoritative LIFE/save decisions server-side before persistence. Use DataStoreService when LIFE is ready, with schema/failure handling and isolated test data. Any future custom user text must use Roblox server filtering before display; no raw name echo. Publication configuration and DataStores are not enabled in this round.
- **ROBLOX-03 Evidence and initial Windows check.** Keep pure golden tests plus a dependency-free Studio test runner with counts, failures and a source/test/project evidence ID. 43/43 pure checks and 6/6 engine checks on Windows, evidence 5b14ae68fed28794. Engine count includes suite completion. Native Studio exposed an inherited forbidden runtime Lighting.Technology assignment; author it in the Rojo place instead. Preserve anchored-parts/BulkMoveTo rig; test part budget, then measure on actual low-end devices before making performance claims. See docs/verification/roblox-first/RESULTS.md.

- **ROBLOX-04 Core safety silk.** Port frozen tether constraint/energy/work/sag with Godot-exported goldens; fixed 1/60 mechanical ticks, unchanged jump solver. Real anchor-local tracking, payout, catch/hang, reel/lower, one bend/snags and edge-first lowering. No claim of complete Godot contact/fallback parity or M03 acceptance. Pure 115/115, Studio 18/18 (two completion rows), client playback 3/3; evidence d1a1cff5c06eafe3. Reports under verification/roblox-silk.
- **ROBLOX-05 Recovery controls/contact adaptation.** F/gamepad X/touch Silk lower; W/S or directional input reel/lower while hanging. D-pad down stays directional. Q/B/Let go requires a fresh hold after the 0.4-second grace, then 0.6 seconds; preheld input cannot release. At minimum line length, allow a 0.6-stud real-face leg grab with an obstacle-checked body sweep to recover past a padded leaf bend. Edge lowering uses a short seating offset, not full edge-arc parity. Next: capped catch framing (45 degrees), camera collision/player takeover and physical-device acceptance before perception. No published experience or DataStore changes.
- **ROBLOX-06 Controls and camera match the Godot reference (Perplexity Computer, 2026-10-14; ROBLOX-04 on its branch, renumbered at the merge with Chet's ROBLOX-04/05).** Nathan: "the controls are not as good on roblox, when jumping you can only hop, V doesnt change the view etc. They were perfect on the godot version." Port the frozen camera_rig.gd, surface_input.gd, jump_controller.gd/jump_planner.gd and player_controller.gd behaviour rather than tuning Roblox's own camera. Roblox's stock camera centred on the spider, so the aim ray met the floor just past the body and every aimed jump became a tiny hop. Bindings follow input_setup.gd: R/middle mouse/right-stick click recenter (not reset), V/Y spider-eye view, Q/B cancel, right mouse/L2 Focus, T/R2 slow motion, arrows/right stick look. Port-only: Backspace/View resets to the start, G toggles gait, H shows the controls card. Mouse is locked to the centre while playing, as Godot captures it. Pure camera math is checked against values exported from Godot itself.
- **ROBLOX-07 A fuzzy coat (Perplexity Computer, 2026-10-14; ROBLOX-05 on its branch).** Nathan: "we need fuzzy spider". Display only, inside the ROBLOX-01 black/white design: about 450 thin body hairs lying back toward the abdomen's tip, white over the white markings, grey mixed through, Phidippus eyebrow tufts, leg hairs with a denser front-leg fringe, and two see-through fur shells for a soft outline. Every value is in Appearances.fuzz. Hairs are separate from the 160-part body budget, capped at about 720. Touch-only devices get a third of the hairs until a real tablet frame-time check. Roblox cannot load generated fur textures without uploaded assets, so hairs are parts. (The counts and sizes here are superseded by ROBLOX-13.)

### Roblox controls and recovery camera (Claude, 2026-10-14)

Nathan: "the controls are not as good on roblox, when jumping you can only hop, V doesnt change the view etc. They were perfect on the godot version." Branch claude/roblox-controls-recovery merges Perplexity's 01fe0d1 into main 432bc53 and does Chet's chunk "recovery camera and control acceptance". See docs/HANDOFF-roblox-controls-recovery.md.
- **ROBLOX-08 One control scheme on every device, with Godot's context rules.** Bindings follow input_setup.gd; the full action table, ported and deferred, is in roblox_port/README.md. An action is held while any source holds it (a key, a controller button, a finger), so keyboard, controller and touch work together. Q / B / touch Cancel is one action: it cancels a press or an aim with no penalty, stops a walk to the edge and is nothing else's then, and on the line only a fresh press after the 0.4 s grace, held 0.6 s, lets go (Chet's ROBLOX-05 rule). F / X / Silk lowers (D-pad down stays walking, ROBLOX-05). Esc / Menu is Roblox's own menu: the game drops every hold and pauses the spider, as Godot's pause. Words on screen are Godot's (jump_feedback.gd), naming only the controls of the device last used; prompts wrap inside the safe area (CoreUISafeInsets) and clear of the touch buttons. The body (SpiderMotor) and the jump phases (JumpInput) are modules, so tests drive them without a client. Deferred, with no feature yet: interact, field notes, notebook, struggle grip, developer views and the pause panel's settings; until then the port uses Godot's defaults.
- **ROBLOX-09 The recovery camera: line framing capped at 45 degrees, the player always wins.** Port camera_rig.gd's line framing (A-017) with Chet's 6B cap: smallest 15-degree step that gives a comfortable boom and sight of the spider and the lip, at most 45 degrees, eased by smooth_damp; any look, a recenter or aiming takes the turn over at once and keeps the framing off until the line ends; the view stays when the line ends; the setting switch exists in code (default on, no UI yet). Decisions are tested against values exported from the frozen rig (tools/export_framing_reference.gd). Roblox adaptation: a boom or pivot cast that starts touching geometry counts as blocked, because Roblox's Spherecast does not see initial overlaps; no boom is trusted before the sill exists (Godot's placement-order rule).
- **ROBLOX-10 "At the shortest line" only from a reel that ran.** SilkController set the shortest-line stop whenever a reel could not shorten, including while snagged, and the stop then outlived the snag: a spider swinging under a leaf could never reel up again. Godot sets it only inside its not-snagged reel branch; the port now does the same. No other silk rule changed. Found by the ten-miss scenarios.
- **ROBLOX-11 Carry the stick over edges.** Port player_controller._carry: after a sharp support turn with the stick held, keep the motor's own direction (turned with the support) until the stick is released or turned past 30 degrees, or the view's mapping agrees again within 25. Without it, holding forward at an edge flipped the spider between the top and the face.
- **ROBLOX-12 Test layers and what they prove.** Pure Luau checks logic and Godot goldens. tests/studio/RecoveryScenarios.luau is one deterministic scenario module: Studio runs it on real raycasts and sphere casts (engine evidence); the CLI runs it on a box-world emulation of axis-aligned boxes (a smoke test that cross-checks against Chet's Studio-verified silk spec, never reported as engine evidence). tests/client_smoke.luau runs the client scripts with stub services. Only Studio runs and real devices count for engine, rendering, input-device and frame-time claims.

### Cuter spider and graphics (Claude, 2026-10-14)

Nathan: the spider "needs to be cuter" and "we need fuzzy spider", and he wants textures and graphics improvements. Same branch, after the controls and recovery camera work. See docs/HANDOFF-roblox-controls-recovery.md and docs/verification/roblox-cute-graphics/RESULTS.md.

- **ROBLOX-13 A cuter, fuzzier spider; the daughter's design unchanged (Claude, 2026-10-14).** docs/SPEC.md calls the spider an animal, not a miniature person, so cuteness comes from proportion and softness and never from human features: no eyebrows, mouth or smile (a test fails on a part named like one). The colours and pattern of docs/art/first-spider-reference.jpg (band, central spot with its four small spots, speckles, pale side patches, banded legs and palps) are pinned literally by tests/look.luau. Display only: the head is about 1.07 times the abdomen (it was 0.77) and rounder; two big glossy front eyes with two small catchlights each and a dark-grey rim so black reads on black, six smaller eyes; a rounded muzzle; plump, slightly shorter legs with round feet; fluffy palp clubs; a bold jumper's tufts at the upper sides of the head behind the eyes, not over them; a coat of flat locks, a few guard hairs, a side fringe and four graded fur shells (retuned once in ROBLOX-15, when the first coat read spiky), sized for the real camera (5 studs away, about 170 px per stud at 1080p, where the old hairs were about 1 px wide); a little idle motion once the spider stands still (breathing, a slow head tilt of at most 7 degrees, palp drumming in bursts), off while moving, in the air, with reducedMotion and in low detail, and never touching the planted feet, the root part or anything that feeds movement. Every number is a knob in Appearances (look, eye, palp, limbs, fuzz, idle, detail) and a test checks the table is complete. Budgets, tested: full 624 parts (475 hairs, 8 shells, 141 other), at most 705; low 266, at most 272 (the first coat had 705 and 272, with the tests at 760 and 300). The soft edge measured at the game camera in a Godot-shim render (tools/preview/fringe.py, hairs and shells together) is a modest gain over the old rig (the coat reaches 1.8 px past the bare body at the faint threshold against 1.3 px); how it reads in Roblox is unverified and the knobs are the remedy.
- **ROBLOX-14 Graphics from Roblox's own features, with one switch for weak devices (Claude, 2026-10-14).** No uploaded assets. Roblox materials per surface (Data/Graphics.materials; PBR through MaterialService.Use2022Materials, authored in both Rojo projects) are looks only; grip stays in Data/Surfaces. Lighting: Future technology (authored in the Rojo projects, since scripts cannot set it), a soft warm sun, Atmosphere haze, Sky, clouds, gentle Bloom, ColorCorrection and SunRays. SunPick looks for a sun that shines in through the window (behind it, 18 to 48 degrees high, within 65 degrees of straight out) without assuming Roblox's sun convention: it asks Lighting:GetSunDirection() across the day for both signs of the latitude, records its answer in Lighting's attribute SunPick, and falls back to the old morning light. Depth of field is off by default because it blurs what the player is reading; the Workspace attribute DepthOfField turns it on. The back wall stays the solid, climbable box but is invisible; a drawn plaster wall with an opening, glass, trim and two mullions replaces it, and a view out (sky, hills, houses with roofs and chimneys, trees) is placed by where it should appear on the glass from the usual camera. Dust motes, faint light shafts and small details (paint chips, a crack, crumbs) sit low and away from the spawn and the silk spot, so the landing patch, the silk lines and the prompts stay legible. Gameplay never reads any of it: decor is anchored, non-colliding, untouchable and not queryable, in a folder the spider's rays and the camera's casts do not include. The low-detail tier (touch-only devices, or the Workspace attribute Detail set to "low" or "full") drops the spider's extras and, on that client only, everything the server marked FullOnly (bloom, sun rays, clouds, shafts, details, the busier part of the view) and thins the dust: decor 76 to 34 parts, spider 705 to 272. The looks are best effort because none of this has run in Studio: the server wraps the lighting set-up and the decor in pcall, warns and carries on with the old look, keeps the solid back wall visible if the drawn wall cannot be built, and tries each optional decor piece on its own; the sill and the wall are not optional. Nothing here has been seen in Studio or timed on a device; the tier is a precaution, not a measured fix.
- **ROBLOX-15 The coat, second pass: short, flat and colour-true (Claude, 2026-10-14).** A reviewer looked at the contact sheet of the first coat: the face was right (eyes, catchlights, head shape, palps), but the abdomen read spiky, not fuzzy. In the top view and at play distance the hairs stood straight out as pale rectangular shards, a hedgehog look, and they covered the white spot pattern. Cause, from the numbers: locks 0.05 to 0.085 stud long and 0.04 wide leaning 46 to 48 degrees, 204 guard hairs of 0.06 to 0.097 standing at about 63 degrees and a stiff fringe, 190 of the 370 coat hairs in grey or frosted tones that show pale on a black body, 62 white hairs placed up to 1.18 times the spots' radius and over the whole band stripe (wider than its dabs), and grey (0.32) fur shells that by themselves lifted the black by 19/255. Decision, coat only (the eyes, catchlights, head shape, palps, legs' shape, pattern and idle motion are as they were; in the face close-up the catchlights, palp clubs and tips and jaws are the same pixels, and one front eye differs only at a one-pixel rim, 103 of 21,819 pixels): (1) hairs about half as long (locks 0.024 to 0.040, guard 0.030 to 0.046, fringe 0.026 to 0.040) and under half as wide (locks 0.018, guard 0.0085), lying nearly flat (locks 3 to 13 degrees off the surface, fringe 14 to 32) and combed toward the rear; only 32 short guard hairs stand up (50 to 75 degrees), and none at low detail (an `every` of 0 in Appearances.detail now drops a class); (2) every hair takes the colour of the pattern it grows on: black or dark on the black areas, kept 0.006 stud off every white marking and off the pale cheeks, and white only inside the five spots and the band (24 white hairs lying on the discs and kept wholly inside their edge); nothing grey or frosted is left in the body coat or on the black of the legs (the tufts, ruff and palp fluff keep their silver); (3) the softness comes from the fur shells, now dark (0.08) and faint (together they tint the body by 26 %), out to 1.23 times the body, so they neither lift the black nor grey the white; (4) the budgets stay at or below the first coat's: 624 parts at full detail (it was 705) and 266 at low (272); tests/look.luau now caps them at 705 and 272 and has 72 checks (it had 54) that would have failed the first coat, among them white hairs wholly inside the markings the rig draws and black hairs clear of them. Measured in Godot-shim renders of the abdomen (tools/preview/coat.py, docs/verification/roblox-cute-graphics/coat-report.txt; shading and layout only, not Roblox): in the top view the bright shard pixels on the black went from 7,741 to 107, the black body from lifted by +38 to +1.5 of 255, the hairs' reach past the bare outline from 5.6 px on average and 28 px at most to 2.4 and 15; at the game camera the spikes beyond 6 px from 14 to none, with the shells' soft halo unchanged (2.3 px). The white pattern keeps 87 % of its pixels as bright as designed in the top view (83 % before; the shells dim it a little and the hairs not at all). The author of this pass could not look at images: the pictures were judged by pixel measurements and a text rendering of them, so the contact sheet still needs an eye, and Studio is the only judge of the real look. The knobs, if Studio disagrees: `fuzz.locks`, `fuzz.fringe`, `fuzz.guard`, `fuzz.pale`, `fuzz.shells` and `fuzz.shellColor` in Appearances.

### ROBLOX-16 — Native recovery acceptance and wall contact (Chet, 2026-10-14)

Windows Studio exposed a shallow wall-lowering penetration missed by the box emulation. Keep a normal skin at sweep contacts and a short launch-wall face guard during wall lowering, without changing jump math or other landing policy. Preserve the existing penetration assertions. A landing endpoint assertion now allows 1e-4 stud for Roblox Vector3 rounding. Protected lighting/material flags are checked in authored build configuration instead of read by game scripts. Evidence cf31cbabad2e9cad: 49/49 native engine checks, 7/7 actual-client playback, ten misses recovered. Physical controller/tablet unavailable by Nathan's confirmation; record those as not run. Details and timing: verification/roblox-controls-windows/RESULTS.md.


### ROBLOX-17 — Perception in the live client (Chet, 2026-10-15)

Port P01 F1–F8 using Claude's Sensor/observer, stepped before movement against only Windowsill geometry. Observation memory alone supplies sector cues, classification, fixed fading last-seen rings and lost-sight text. Camera position affects drawing/coverage, never sensing. FocusToggle is an opt-in Player attribute; cancel retains aim/line ownership and leaving a surface clears Focus. Back-to-start clears sensor bookkeeping and observation memory together. A labeled, non-query magenta TEST TARGET and an isolated west stage provide an explicit perception fixture until flies arrive. Native evidence 8b45f28cf2cca2ba: 58 engine and 9 live-client checks passed. No changes to the frozen Godot reference.

### ROBLOX-18 — Evidence-driven flies and unseen arrivals (Chet, 2026-10-15)

Port the frozen prey math, visible-motion senses, utility decisions, validated perches, swept/replanned flight and population entry policy into Shared/Prey. Four flies by default; incoming flies require two unseen vent checks and a planned route. Visibility uses WORLD-only geometry. Keep golden math inputs exported from Godot; the portable Park-Miller RNG deliberately does not promise Godot PCG sequence parity. Fly bodies are anchored/non-query and moved with BulkMoveTo. Native evidence e3160a3f6e3f2782: 67/67 Studio and 11/11 client checks; six-fly sensor p95 412 us. Full behavioral persistence, sound and grooming animation remain future work.

### ROBLOX-19 — Capture evidence, grip and feeding controls (Chet, 2026-10-15)

Capture requires swept unobstructed contact during a committed-jump strike window; ordinary falls cannot catch. Sensor receives only jaws position/radius and resolves exactly one plausible observed contact, never a hidden ID. Port landing delay, grip/escape, automatic-grip help, interruptible feeding and bounded nutrition grants. Space/A/Grip is consumed as grip while struggling; E/L3/Eat grips or resumes feeding. F/X/Silk retains its tested lowering action. AutomaticGrip is a Player attribute pending settings UI. Basic energy remains above 0.2 until LIFE/NeedsModel arrives; no starvation or saves are implied by this milestone.

### ROBLOX-20 — The spider-eye picture (Claude, 2026-10-15)

Nathan asked for the eye view to be more scientifically accurate, with a flourish if it came out dull. The eye view (V/Y) now has two ways of seeing, blended by k from 0 to 1. It is presentation only: the senses, the motor, the jump planner, the aim ray and where the camera stands are as they were. Side eyes (k = 0, the default in the eye view): 90 degrees vertical, nearly one colour (ColorCorrection saturation -0.9, tint 198/232/196, contrast 0.08), a little blur (2.5) and a loose depth of field (MacroDOF far 0.35, near 0.25, in focus within max(6, 0.6 x distance)); they are the ones that catch movement. Principal eyes (k = 1, while Focus is held or toggled on a surface, the value that already feeds the perception HUD): 24 degrees, sharp, saturation 0.15, tint 115/255/236 (red cut), contrast 0.16, a tight depth of field (far 0.75, near 0.6, within max(0.6, 0.12 x distance)) and the ultraviolet layer showing. k rises in 0.35 s and falls in 0.5 s as a linear phase that is then eased, so every frame rate gives the same picture; the field of view is blended in tangent space; `SpiderCamera.lookScale` (tan(fov / 2) over tan 45) scales the eye view's look so the picture crosses the screen as fast zoomed in as out (the one change to feel: mouse, stick and touch turn the gaze less when zoomed in; the gaze is still the aim ray). `Client/SpiderEyes` owns the depth of field in the eye view (focus on a world-only ray along the look, at most 40 studs, racked with a 0.15 s time constant; the old eye-view branch in SpiderClient is gone; what it borrowed is put back on leaving; no MacroDOF, or one that is off, is left alone) and two effects in Lighting, EyeGrade and EyeBlur, which are off outside the eye view. Two outlined retina strips at true angular size (5 x 20 degrees, tangent-correct: a 20 degree strip is tan 10 / tan 12 of the screen's height at 24 degrees) sit 3 degrees either side of the middle, tilted 10 degrees into a V; they sway and turn with the side eyes (4 degrees every 1.7 s, 12 degrees every 2.6 s, the second strip 0.3 s behind) and only track with the principal eyes (0.6 and 3 degrees). A ring pulsing at 3 Hz (1.0 to 1.6 times its apparent size, never under 14 px, a third as strong inside a strip, fading over the sensor's 15 tick hold) marks where the sensor's sight-line checks found something moving, and a short arc at the screen's edge when that is out of view. It reads `Sensor.motionSeen` and nothing else, so a fly the sensor did not find moving is never drawn. A telephoto vignette darkens the edges (0.35 to 0.55 at the edge), and a caption under the status lines explains the view for the first 6 seconds of it. The UV layer is `Workspace.Decor.UVLayer`: authored parts, fully transparent, each with a UVOpacity number; in the eye view this client sets Transparency to 1 - k x UVOpacity (the folder is looked up at most once a second). Reduced motion (Player attribute ReducedMotion): the strips and rings hold still and the zoom stops at 45 degrees. The overlay is a ScreenGui at DisplayOrder -5, under SpiderHud (0) and the perception HUD (4).

Honest labels. The science is related-species evidence and the numbers are illustrative choices; `Shared/Data/Eyes` carries each citation. Principal eyes' narrow, tall field and strip scanning: Land 1969, Shepeleva 2022. Distance from defocus: Nagata et al. 2012. UV (about 370 nm) and green receptors in Phidippus regius: DeVoe 1975; red may look dark green: Glenszczyk et al. 2022 (Saitis barbipes). Secondary eyes' wide field (about 330 degrees), low acuity, green sensitivity and movement role: Shepeleva 2022, Zurek et al. 2010. Choices, not measurements: the 90 and 24 degrees, the tints, the blur, the 3 degree offset and 10 degree tilt, and the scan periods (the turn is faster and smaller than Land's 5 to 15 s and about 50 degrees, so it can be seen within a few seconds). UV is still never inferred from RGB (EYE-08, EYE-14): the layer is authored decor, shown as violet and called that in the caption, and no measured reflectance of prey, glass or leaves is claimed, so EYE-14 stands for those. The sensor's own peripheral cone (300 degrees) is untouched; the rings show what the sensor found, not the anatomical field.

Evidence and limits. tests/eyes.luau (EYES 231/231) checks the numbers and their ranges, the pure rules (`Shared/UI/EyeOptics`), SpiderEyes under the shim and the real client's wiring; tests/client_smoke.luau now expects 90 degrees on V (it expected the camera's own 80, which SpiderEyes overrides each frame); strict analysis gives 0 diagnostics; every other suite keeps its count. Nothing has been seen in Roblox Studio: colour, blur, depth of field, the strips and rings, the gradient directions, the UIStroke placement and the negative DisplayOrder can only be judged there. The knobs are all in `Shared/Data/Eyes`. The rig's own `reducedMotion` field is not wired to the ReducedMotion attribute (there is no settings screen yet).

ROBLOX-20, second commit: the perception HUD's drawer. `Client/PerceptionHud` no longer draws its shapes as text. A live circle is a rounded Frame with a 2 px UIStroke (and a faint dark one just outside it so it reads on light ground); the dashed last-seen ring is 12 short rounded bars whose gaps grow with the sighting's age (each covers 0.85 of its 30 degrees at the view's `dash` of 1 and 0.255 at 0.3, never under 2 px); an off-screen cue is a chevron of two 15 px bars lying 40 degrees back from its direction; the Focus ticks are four bars; and a label is white Builder Sans SemiBold at 18 with a UIStroke on a dark rounded pill that grows to fit the text, hanging below the ring it names (above it only when the screen has no room below, and kept inside the screen sideways once it has been measured). Chet's Studio screenshot showed the stage's world billboard ("TEST TARGET / moving marker, not a fly") lying over "lost sight" when the label sat above the ring; below, it cannot. `PerceptionView` (what is drawn, its words, opacities and timings) is untouched, and so is `driver.perceptionHud.view`. The geometry is the pure `Shared/UI/PerceptionShapes`; tests/hud.luau (HUD 69/69) checks the shapes and the drawer under the shim (which gained `Font`). Not judged: how the pill fits its text, the strokes and the font in Roblox, which only Studio can show.

### ROBLOX-21 — A worn, sunlit windowsill: the world's new look (Claude, 2026-10-15)

Nathan asked for the aesthetics of everything to be upgraded; the world's direction is a cosy macro photograph of a real, slightly worn windowsill at the spider's scale (1 stud = 1 cm) in warm morning sun. Looks only: `WindowsillLayout.PIECES` keep their exact geometry, profiles, solidity and queryability, and everything added is drawn decor (anchored, non-colliding, untouchable, not queryable; `Habitat/Shapes`). Optional detail carries FullOnly (Client/WorldDetail drops it on phones and tablets); whatever replaces a piece's look exists in both tiers. Numbers are in `Data/Graphics` (`paint`, window, lighting), `Data/Flora` and `Data/Wear`; builders in `Habitat/Plants` and `Habitat/Patina`. The sill is cream enamel (e8dfcb, SmoothPlastic, a little reflectance) with chips that flip to bare wood, a worn bare-wood strip along the front lip's top edge, grime lines in the corners and along the side frames, and three dust bunnies; the window is plaster with glossy trim, pale glass, condensation on the lower panes and two faint smudges; outside a blue-grey window box (its top behind the apron) holds nine black-eyed Susans (12 to 14 golden ellipsoid petals each, a dark dome, heads turned toward the room) and flowering shrubs; the three Pilea leaves are drawn as rounded pancakes whose tops are exactly their pieces' tops, with a darker rim, a lighter underside, a pale dot where the stalk joins and 8 veins, petioles as cylinders inscribed in the stem boxes, cracks and crumbled soil at the stem bases, and the dry leaf as a curled tan plate; the trough is terracotta with a darker water-stain band, dark soil, pebbles, moss and three seedlings under a centimetre; the crevice is weathered dark wood with a silk retreat; a copper coin, three fallen brown leaves and the old crumbs lie on the floor, clear of the spawn, the silk practice spot and the retreat. The flowers' ultraviolet pattern (the outer half of each petal reflects, the base and centre absorb) is a layer of Neon patches, Transparency 1, in `Workspace.Decor.UVLayer`, each with the attribute `UVOpacity` 0.85 for the spider-eye view to fade in. A piece the drawing replaces (the back wall, the Pilea's leaves and stems) turns invisible, still solid and climbable, only if the drawing was built: `Scenery.decor` returns the ids it drew and `Scenery.sill(replaced)` hides exactly those (it generalises ROBLOX-14's wall flag; a failing Pilea leaves the plain pieces visible, tested). Light: a warm grade (contrast 0.1, saturation 0.1, tint 255/246/232), bloom 0.45/24/1.4, and the macro depth of field is now ON by default in the full tier (far 0.3, near 0, sharp within 18 studs of the focus the client keeps on the spider); this supersedes ROBLOX-14's opt-in, and the Workspace attribute `DepthOfField` = false switches it off. Budgets, tested: decor 76 to 806 parts at full detail (limit 1,500) and 34 to 151 at low (limit 450). `tests/world.luau` went from 71 to 230 checks (every decor part non-colliding and unqueryable; leaf tops and footprints; hidden pieces only where drawn; UV layer; flower, drop, bunny and coin specifications; tier budgets), and the Studio spec `tests/studio/GraphicsSpec.luau` follows. Evidence: before and after renders from the new scene preview (`tools/preview/scene.py`, Godot with the same settings both times) in `docs/verification/roblox-aesthetics/`; they show layout and colour only, not Roblox's materials, Future lighting, haze, bloom or depth of field, and nothing has been seen in Studio. The place files (`TheWindowsill.rbxlx`) are not rebuilt here. Knobs, if Studio disagrees: `Graphics.paint`, `Graphics.lighting`, `Graphics.depthOfField`, `Flora.*`, `Wear.*`.


### ROBLOX-22 — The fly: a house fly with glass wings (Claude, 2026-10-15)

Part of Nathan's "upgrade the aesthetics of everything". The fly was three ellipsoids, two translucent plates and six sticks (13 parts) whose wings flapped as a 92 rad/s sine. Looks only; `FlyBodies.new/spawn/pose/draw` keep their roles (`draw(flies, now)` is called as before, one `Workspace:BulkMoveTo` for all the flies' parts), and a fly's position, heading, normal and state still come from the prey simulation, so nothing here feeds back. Every part is anchored, non-colliding, untouchable, not queryable and casts no shadow (`Habitat/Shapes`). The prey profile (`fly_like_prototype`, "no species claim") is untouched; `Data/FlyLook` says it is only how the prototype is drawn: a house fly (Musca domestica) 0.7 cm long (the profile's `length_wu`), standing on the profile's `hover_wu` 0.16, so the feet are on the surface. Numbers live in `Data/FlyLook`, the builder in `Client/FlyBodies`. 39 parts a fly (the limit is about 40; four flies are 156 parts, the old four were 52), the same at both detail tiers: a head, two big glossy red-brown compound eyes (8a2f1c, a little reflectance) and a pale silver face stripe; a grey thorax (5b5d58) with four dark stripes and a grey-brown abdomen (7b7266) with a darker dorsal stripe, each stripe a thin slice of the ellipsoid it lies on, taken at its own cross-section and 0.002 proud, so it follows the curve; a short dark proboscis; eight tiny bristles; six two-segment legs (femur 0.024 and tibia 0.017 thick, round Cylinders along X) standing on the surface; two thin Glass wings (d8e4ea, transparency 0.55, 0.006 thick) each with a dark leading-edge vein (a thin rod along the outer front edge) and a faint iridescent film layer (f0c8ff, transparency 0.82; thin-film interference colours, Shevtsova et al. 2011, PNAS 108:668-673), folded back over the abdomen in a shallow V (9 degrees out from straight back each side, 18 between them). Ellipsoids are Parts with a sphere SpecialMesh (a Ball part is forced to be a sphere), rods are Cylinders. In flight there is no flapping: a wing beats about 200 times a second and a drawn flap at 60 frames would only strobe, so each wing becomes two soft translucent flat fans (a denser one near the root and a fainter one out to the tips) that tremble by at most 0.05 rad, the legs tuck in toward the body, the veins and the shadow oval go (Transparency 1); a CAPTURED fly counts as flying (its wings buzz while held). A fly in the air keeps its back to the sky: the normal it carries is that of the surface it last stood on (a fly that arrives from the vent carries the back wall's), which rolled the old fly sideways after a take-off from a wall; a held fly follows the spider's grip, the normal the director gives it. A state change touches only the 19 parts that differ between the poses (legs, wings, veins, films, shadow). The parts cast no shadow (the policy for small parts), so a soft dark oval 0.34 by 0.70 (transparency 0.78) lies 0.003 above the surface under a standing fly. A heading along the surface normal gets a fallback up vector. `Shapes.rod` now gives a vertical rod an alternate up vector too (`CFrame.lookAt` has no turn to give along the up vector); a rod that is not vertical is built exactly as before. The thinnest parts (the shadow oval 0.004, the wings 0.006, the bristles 0.007) rely on Roblox's minimum part size of 0.001 studs per axis (lowered from 0.05 in August 2021, devforum "Reduced Minimum Part Size"; the collision geometry stays at 0.05, which parts that never collide and are never queried do not use). Eight bristles rather than a dozen keep a fly to 39 parts with its shadow oval. Tests: a new suite, `tests/flies.luau` (FLIES 187 checks): the part budget and flags, a ray through a fly meets nothing, proportions and colours, the feet on the floor, a wall and a ceiling, the V, the blur and its limits (at most 0.1 rad, under 0.03 rad a frame), the legs tucked, CAPTURED, the back up in the air, the pose restored on landing, no NaN, one BulkMoveTo, a fly that is gone loses its parts; WORLD stays at 230 and every other suite is unchanged. The scene preview (`tools/preview/scene.py`) has six new close-up views (`fly_top`, `fly_front`, `fly_side`, `fly_b_top`, `fly_b_side`, `fly_b_front`); before and after renders are in `docs/verification/roblox-aesthetics/` (`before_fly*.jpg`, `after_fly*.jpg`, `before_after_fly_sheet.jpg`). They show shape and colour in Godot with the shim's parts, not Roblox: nothing has been seen in Studio, so how the Glass wings, the film and the blur read there, and whether the outer thorax stripe shows as a thin dark ring from the side, are open; the legs are plain rods (no feet or claws), and there is no walking or grooming animation (ROBLOX-18 leaves that for later). The place files (`TheWindowsill.rbxlx`, `tools/build.py`'s evidence stamp) are not rebuilt here. Knobs, if Studio disagrees: `FlyLook.wing` (transparency, reflectance, `fan`), `FlyLook.colors`, `FlyLook.body`, `FlyLook.legs`, `FlyLook.shadow`.

### ROBLOX-23 — Native window transparency and effect precision (Chet, 2026-10-15)

Native Studio showed that the refracting Glass pane concealed the translucent UV petal layer behind it. With the camera held constant, hiding the pane revealed the pattern; restoring the pane with SmoothPlastic also revealed it. Use transparent SmoothPlastic for the drawn window, preserving its tint, 0.86 transparency and 0.12 reflectance. Glass droplets remain unchanged. This is a rendering workaround, not a change to collisions, sight rays or the biological model. WORLD and GraphicsSpec check the material. The principal-eye grade makes the authored violet pattern read cyan in Studio; treat it as an illustrative UV layer, not measured spider colour experience. Native effect properties also round to float32: 0.3 reads as 0.30000001192092896. GraphicsSpec allows 1e-6 for this round trip instead of exact equality, retaining the exact zero near-blur check. Evidence and actual screenshots: verification/roblox-aesthetics-windows/.

### ROBLOX-24 — LIFE: the life clock, hunger by the hour, rest and sleep, day and night (Claude, 2026-10-16)

Ports Godot's LIFE-04 to LIFE-06 to Roblox in the order of HANDOFF-roblox-flies.md. `Shared/Life/LifeClock`, `NeedsModel` and `LifeLoop` are ports of `life_clock.gd`, `needs_model.gd` and the rest, sleep and light part of `habitat_loop.gd`, checked tick by tick against Godot's own code (`tools/export_life_reference.gd` runs the real habitat loop on a stand-in world; `tests/life.luau`, LIFE 20,846 checks). The windowsill plays Standard rules in life mode: energy drains by game hours (0.021 awake, 0.007 asleep), no floor; the hours at zero are counted and nothing follows from them yet (LIFE round 5, death and continuing, is not ported; nor are growth, the wasp, the passing shadow or the notebook). The NeedsModel has explicit modes (`NeedsModel.new(lifeMode, gentle)`; sandbox by default) and is the only owner of energy: Feeding advances it and grants into it under the meal's capture key, as Godot's feeding controller does. Because the reserve records what it actually rose by (`after − before`), a meal's grant can exceed the fly's nutrition by about 1e-14; PreySpec and the client playback's feeding row allow 1e-9 there. E with nothing in the jaws no longer flips Feeding's `feeding` flag: in the crack it rests (Godot's interact). The client runs the loop last in each fixed tick (Godot priority 12) and gives the sensor the loop's `rangeScale` (0.3 at night) for the next tick; presses of E and Q wait for the next tick. Day and night light: `Shared/Habitat/DayLight` blends Lit's daytime values toward `Graphics.dayNight`; full daylight is exactly the accepted look, dusk runs SunPick's morning clock back toward ClockTime 4.0 (Roblox places the sun from ClockTime, so this keeps the sun on the window's side as it sets), night is dim blue, never black; shafts and motes dim with it. It owns Lighting's ClockTime, Brightness, Ambient, OutdoorAmbient, ColorShift_Top, ExposureCompensation, the Atmosphere's Color and Decay, SunRays, the Shafts and the Motes, never SpiderEyes' effects (ROBLOX-23's request) or the Grade. The light never feeds perception. HUD: the day and its part top left, one line for evening, night or hunger, the loop's notices, and the retreat's prompt; touch's Eat button doubles as Rest, Sleep, Wake and Leave. The numbers of the night look are first guesses until seen in Studio.

### ROBLOX-25 — S01-C retreat checkpoints behind a DataStore-shaped in-memory store (Claude, 2026-10-16)

Godot's T09 checkpoint for the port. A rest in the silk-lined crack, and each morning of a night's sleep, keeps one; Backspace (controller View) returns to it, or to the start (as before) when there is none. A checkpoint is the whole world at a tick boundary: the spider's pose (position, surface normal, heading, gaze pitch; put back with `SpiderMotor.place`) and, as one object graph, the prey director (flies with their random streams, flights, senses and plans; perches with occupants and reservations; the population's owed entries; the feeding and its ledger), the sensor and its memory, the needs and the life loop. The graph is recorded by `Shared/Persistence/ObjectRecord` from named roots rather than by a hand-written record per module, so no field can be forgotten; it keeps sharing and cycles, writes Vector3 and non-finite numbers as tagged values, and refuses any table of an unknown class, function or Instance unless it is named (the world's raycast closures, the probe part, the species data, the memory's Signals, the save callback), naming the path of what it refused. Restore is two-step: the whole record is checked and rebuilt fresh first (format, schema, windowsill revision, pose, every reference, then the rebuilt world's meaning: reserves in range and books that add up, the clock, unique flies in known states, perches held by living flies, the meal in the jaws one of them, the meal ledger), and only a good record is committed, in one pass that moves the fresh contents into the live root tables so that every holder of a live table keeps the right one. A bad record changes nothing. `CheckpointStore` follows Godot's checkpoint_store.gd on a DataStore-shaped interface: current, backup, temporary and set-aside keys, a checksum over canonical JSON, read-back before replacing, a damaged current set aside instead of pushing out a good backup, a newer schema reported and left as it is. `MemoryDataStore` has a DataStore's rules (values copied in and out, only storable values, the 4,194,304-character limit, writes that can fail) and lasts the session: **no live DataStore is written and nothing is published**. Schema 1 is the port's own; Godot checkpoints are not read. `tests/checkpoint.luau` (CHECKPOINT 123): after a restore, 600 ticks including a walk out of the crack repeat the original run exactly. Not run in Studio: LifeSpec checks the same through HttpService's own JSON. Touch has no return-to-checkpoint button yet.

### ROBLOX-26 — The mud dauber wasp: Godot's director, ported and checked against it (Claude, 2026-10-16)

Ports Godot's LIFE round 4 wasp (LIFE-03, LIFE-14 to LIFE-16: `scripts/predator/wasp_director.gd`, `wasp.gd`, the rules in `habitat_loop.gd`) as `Shared/Predator/WaspDirector` with every number in `Shared/Data/Wasp`. The director is pure: it knows the world only through three functions (`ray`, `clear`, `inRetreat`), the spider through a per-tick table and the life clock through a block, so the plain Luau CLI replays it and the client gives it the sill's real casts. The rules are Godot's: a visit at most once a day, never on day 1, never before the first finished meal, never while the spider rests or moults, in a window of 10:00 to 15:30 chosen from the seed and the day; 8 s of warning (it arrives from outside over the frame and does not look until it is on the sill); a search of 45 s over 15 authored places (hover, look, and on open surfaces sometimes land and walk, the antennae flicking); notice that grows with sight (range 7, a clear line, outside the retreat), 0.25 per s for a still spider and 1.6 more for a moving one, faster near, fading at 0.2 per s; full notice sends it to look (1.5 s at arm's length) and then to lunge (0.35 s) at where the spider was; a jump, a drop on the line or getting out of sight breaks the approach and it searches at least 6 away from where it lost the spider; a catch holds the spider, paralysed not killed (LIFE-03), and carries it up and away over the frame; the crack is never seen into. `tools/export_wasp_reference.gd` runs Godot's own director and wasp on a stand-in world (a floor, a wall, a retreat box and a scripted spider) in eight seeded scenarios and writes the wasp's phase, events and positions; `tests/wasp.luau` replays each on an analytic Luau world with the random draws Godot made fed back in, and ports `test_life04_wasp.gd`'s hand-written expectations (WASP 15,815 checks). Mutating a number (`noticeMoving`, the hold timer) fails hundreds of them. Float32 against double: the goldens run at a tick of 0.0173 s so no duration lands on a tick boundary, and events are compared within 1.5 ticks, phase changes within 1, positions and notice within 2e-3.

Differences, all forced or deliberate. (1) The port has its own seeded hash for which days have a visit and when (`plannedHour`), because Godot's engine RNG cannot be reproduced in Luau: the same seed gives different days from Godot, though the same each time in Roblox, and a return to a checkpoint meets the same wasp. (2) The walking wasp's sphere sweeps use `Data.walkRadius` 0.3, not its flying radius: Godot's cast_motion ignores a shape that starts overlapping the ground, and Roblox's Spherecast promises no such thing. (3) There is no Gentle mode in Roblox yet: the director has the flag and the rule (the wasp touches the spider with its antennae and leaves) but nothing sets it, so a catch is always a catch. (4) Godot's "out of reach" scenario is covered by a hand-written test, not a golden. (5) The sound is Godot's synthesised hum; Roblox has no audio asset here and I will not reference one I cannot see, so the warning is a caption only (ROBLOX-27).

### ROBLOX-27 — The wasp in the game: caption with direction, the catch, the checkpoint, the drawn wasp (Claude, 2026-10-16)

The client drives the director from its fixed tick after the motor and the life loop (Godot's wasp is a child of the habitat), with the spider's velocity, whether it is airborne in a jump or let down on its line (`falling`), and the life clock's day, hour, resting and finished meals (`Feeding.mealsFinished`, new). Its percept (a movement-only sensed object) is added to the sensor's, so the wasp is seen and tracked like a fly, but only by what moves. The warning is a caption with the wasp's direction from the spider, in Godot's eight words, as the flies' "[buzzing, ahead-left]" ("[a deep, heavy hum outside, ahead-left, coming closer]"), also while it looks at the spider and for three seconds as it leaves; the status line says what to do on the first visit. A catch: `SpiderMotor.seize` stops the spider's own control, the silk line and any prey held are let go, `SpiderMotor.hold` carries the spider with the wasp; when the wasp is gone a plain screen (a dimmed view; no animation) says "A mud dauber wasp stung the spider and carried it away." and "Its sting does not kill: it paralyses.", with the hours lived, meals eaten, visits and escapes, and one choice, "Back to your last rest" (the existing checkpoint return) or, with no rest yet, "Back to the start" (Godot also offered a new spider as another life, which needs the death rules of round 5; the second line does not point to a notebook, which the port does not have). It is chosen with Return, Space, E or controller A/Cross at a priority above the game's bindings, or by clicking, and gets controller selection; Backspace is ignored while it shows. The wasp's own state (visits, escapes, days, the visit in progress) is a field of the checkpoint record, `wasp`, inside schema 1: a record without it restores to the default and is still valid, one with a bad `wasp` is refused as a whole, and a return to a checkpoint therefore brings back the wasp's day too. In the test place (the one with SilkPlayback) the wasp is off; the Workspace attribute `Wasp` = true allows it and `WaspForce` = a place id ("floor_middle") brings it at once (it clears itself), for Studio and playtests.

The drawn wasp (`Data/WaspLook`, `Client/WaspBody`; 56 parts) follows Godot's wasp_body.gd: a black mud dauber about 2.5 cm long, a very thin, long yellow petiole between a small thorax and a teardrop abdomen, black legs with yellow knees and yellow feet, smoky translucent wings, curled antennae that flick while it searches, dark glossy compound eyes. In flight the wings are a soft translucent blur (a 23 Hz stroke cannot be shown at 60 frames; the fly does the same); it hovers with a slow bob; on the ground the wings fold and the legs walk; carrying, the front legs clutch. Every part is anchored, non-colliding, not queryable, no shadow, moved with one BulkMoveTo, and the whole drawing leaves the world when the wasp is away. Renders from the scene preview (`wasp`, `wasp_side`, `wasp_top`, `wasp_front`, `wasp_walk`, `wasp_hold`) are in claude-playtest/previews/w1_*.png; they show shape and colour in Godot with the shim's parts, not Roblox's lighting and materials. `tests/studio/WaspSpec.luau` runs the places, a full search and a catch on real raycasts and sphere casts against a private sill. Nothing has been run in Studio.

### ROBLOX-28 — Original audio and the wasp warning (Chet, 2026-10-16)

Integrate the original generated Godot recordings as Roblox audio assets (manifest with hashes and IDs in roblox_port/assets/audio). The frozen synthesizer is unchanged; tools/export_audio.py reproduces exports. Client Soundscape is presentation only: room ambience, daytime birds, spatial fly flight/struggle, and now the wasp. It consumes current world state each frame, so checkpoint restoration does not leave stale fly references. Roblox master volume is available on all devices; the SoundMuted player attribute supports later settings wiring. Captions remain independent.

The wasp's one looping voice begins with the director's arriving phase (eight simulation seconds), initially nonspatial at a moderate level so camera distance cannot erase the warning; its caption supplies direction. On the sill that voice becomes spatial and follows the wasp. Grounded walking and away states stop the wing hum. Menu/catch screen pause and slow-motion pitch follow existing client state. No AI, timing, sight, jump or checkpoint behavior is changed by sound. Grant wasp asset 76049518783466 to existing universe 10771103250; do not distribute it on Creator Store. The arrival mix is a deliberate accessibility/gameplay presentation choice, not a claim about spider airborne hearing. Actual laptop loudness and PlayStation mix require playtest.

### ROBLOX-29 — The peacock spider's courtship dance: documented rates, artistic amplitudes, a pose and nothing else (Claude, 2026-10-16)

Nathan asked for a second spider, the peacock spider Maratus volans with its courtship dance, and handed over a design package written by another AI. The package was used as source material only: its code assumes 1 stud = 1 mm, replaces the SpiderRig and uses Ball parts with non-uniform sizes (Roblox draws those as spheres), so none of it was copied. The science was checked against the paper: Girard, Kasumovic and Elias 2011, "Multi-Modal Courtship in the Peacock Spider, Maratus volans (O.P.-Cambridge, 1874)", PLoS ONE 6(9): e25390 (PMC3181266).

Documented, and in `Shared/Data/Peacock` as such: courtship lasts 6 to 51 minutes (mean 24.35); pedipalps flicker 3.5 +- 1.6 flicks a second; the fan dance sways the abdomen over a 19 to 35 degree arc at 3.2 +- 1.5 cycles a second; legs III wave 3.2 +- 0.6 waves a second; the fan flaps 2.5 +- 1.8 flaps a second in the pauses; rumble-rump vibrations last 2.44 +- 0.28 s at 12.1 +- 2.9 bumps a second and travel through the substrate (felt, not seen); the order is rumble-rumps and abdomen bobbing on approach, then leg waving with fan dancing, fan-flapping in pauses, then a pre-mount display and a mounting attempt. **The last two are left out on purpose: this is a family game.** Artistic, and marked so: the 14 s loop (a compression of 24 minutes) and its phase times (approach 3.2, raise 1.3, dance 3.4, freeze 2.2, second dance 2.6, fold 1.3), the fan raise angle (80 degrees), the bob rate (4 Hz, in bouts of 0.8 s with 0.5 s rests: the paper gives none), the sway arc used (27 degrees, the middle of the range), the leg wave and palp flick angles, the fan-flap depth, the tremble's size and the ease times.

`Shared/Rig/PeacockDance` turns that into a pure pose: `step(dt, standing, moving)` returns the abdomen's pitch and sway, a tremble, how open the fan is, the palp angle, legs III's raise and wave, and the rumble (for a caption). It uses only the dt it is given, so slow motion slows it, a menu holds it and frame rate changes nothing (checked at 60 and 20 steps a second). Walking, a jump, leaving the surface or `stop()` end it at once and the pose eases out over 0.2 s. The Player attribute `ReducedMotion` halves the sway, wave, flap, bob and flick, and stops the tremble; the raised fan still opens, slowly. The dance is presentation only: it does not touch the motor, collider, senses, jump, silk, LIFE or wasp. `tests/peacock.luau` (PEACOCK) measures the rates off the pose itself by counting crossings.

### ROBLOX-30 — The drawn peacock spider: a second appearance, a fan of flat discs (Claude, 2026-10-16)

`Data/Appearances` gets a second profile, `maratus_volans_male`, drawn by the same `SpiderRig` (the default profile and its pinned values are untouched; `tests/look.luau` still pins them). Morphology after Otto and Hill 2011 (Peckhamia 96.1): a male about 4 to 5 mm (DOC), drawn 0.455 studs long (1 stud = 1 cm, scale 0.47 of the default's face and build) and standing low (`bodyDrop`: the drawn body sits 0.21 under the collider's centre, which is unchanged); a dark carapace with three red-orange stripes and a pale margin; tan-orange framing of the big front eyes; white palp brushes; legs I, II and IV brown with pale bands; legs III longer, dark, with a jet-black brush on the tibia and a white tip, no bands. Colours, proportions and sizes are artistic. The rig scales its own distances (foot search, step length and height, swing time) by the profile's `scale`, and puts nothing new in the default's numbers.

The fan is flat ellipsoid discs (SpecialMesh spheres, never Ball parts) on the abdomen's back face, stacked white fringe, red-orange arch, blue field, a second arch and field, with a black trident figure on top, plus the same rim and field on the back so the fan reads from the camera behind, and two flaps that hang against the flanks when folded. Folded, the discs are a small thick lens sunk into the blue abdomen; opened by the dance pose they widen to a near-round disc (a little wider than long) and flatten, the figure appearing as they go. The raised fan faces forward. This is an approximation of unfurling flaps (width grows, flaps swing out under the discs), not a model of the flaps. Part budgets: 113 parts at full detail, 80 at low (low: no foot balls, eye sockets, leg bands, back to the fan, idle motion or outline; a plainer fan). No fuzz at this size.

### ROBLOX-31 — Choosing the spider in the crack, and dancing (Claude, 2026-10-16)

Resting awake in the silk-lined crack, **C** (controller RB, PlayStation R1; touch Change, shown only while resting) turns the spider into the other one. The choice is the Player attribute `Appearance` (kept for the session); the Workspace attribute `Appearance` preselects it. The drawn rig is built again with the new appearance; gait, eye view and hidden body carry over; checkpoints store nothing about it. As the peacock spider, standing still on a surface, **X** (RB / R1 outside the crack; touch Dance, shown only for the peacock spider) starts the dance loop; any walking input, a jump (hop or aim), Cancel, a rest, the line, a catch, or X again stops it. While a rumble-rump runs the caption "[a fine buzzing through your feet]" shows (the wasp's caption takes precedence). RB is both because the crack and the open sill never overlap; the keys C, X and RB were free (checked against `SpiderInput.BINDINGS`). Words are in `UI/PeacockText` and `ControlText` for every device, with PlayStation names; the dance's prompt, status line, controls-card lines and touch button are never shown for the first spider, but the crack's "C: become the peacock spider" is, or the second spider could not be found.

### ROBLOX-32 — Peacock Windows integration and short-landscape controls (Chet, 2026-10-16)

Keep the peacock appearance and dance unlocked for testing until Nathan explicitly requests sales. No Game Pass, price, purchase prompt or ownership gating is created in this round. The future cosmetic-only plan is in HANDOFF-roblox-peacock.md; the first spider and the full game remain free.

Adding Dance above the existing touch stack put a 120 px prompt panel above the visible safe area at 568 x 320. For landscape safe areas at least 568 px wide and below 450 px high, HudLayout now arranges the controls in three 52 px rows and the client reapplies them on safe-area resize. Portrait/tablet layouts keep their existing sizes. Pure checks require the prompt to stay on screen as well as avoid controls; native PromptSpec checks the compact labels using Roblox's text metrics. The native client playback now chooses the peacock while resting, opens its fan without moving the motor, watches a full loop, walks to cancel and switches back. This is presentation/input layout only; simulation rules stay unchanged. Evidence and remaining physical-device/visual checks: docs/verification/roblox-peacock-windows/RESULTS.md.

### ROBLOX-33 — Death, continuing and session modes (Chet, 2026-10-16)

Nathan asked Chet to take the next LIFE chunk and publish it with the peacock. Port LIFE-19 through LIFE-23: Standard ends at 48 hours continuously starving, with the weak/too-hungry-to-sleep warning from 24 hours; a meal resets the streak. Gentle hunger drains at half rate with a 0.1 floor, and the wasp touches and leaves. LifeSession keeps progress outside world checkpoints, counts an end once, archives up to 30 life summaries when continuing, and chooses Godot's four unrelated-spider spawn spots in the same order. Starting another spider restores a fresh whole-world baseline, clears its memory and old checkpoint store, and keeps the selected cosmetic appearance. Main life and Free play have separate session-only stores. Checkpoint schema 2 validates and restores mode/rules; schema 1 defaults to main/Standard. No live DataStore writes or cross-session progress claims.

The life menu opens at launch and through M, View/Touchpad, or the visible Menu button. Backspace still recovers the current world's checkpoint; controller/touch recovery is in the menu. Modal input blocks world actions; keyboard, D-pad, left stick, mouse and touch select choices, and accept is consumed above gameplay bindings. End/menu content scrolls inside the safe area and has a large-text option. The solo player list is hidden to avoid obscuring Menu. Starting a replacement main life asks a second time. The end offers last rest when available and another spider, without a score. Free play is immediately available. Easy's adult/Standard/main unlock rule is implemented and tested, but growth is not yet ported, so ordinary play cannot earn Easy yet; the menu says it is unavailable and offers Free play. No notebook option/retention claim until that feature is ported.

### ROBLOX-34 — Reachable rest and visible entrance guidance (Chet, 2026-10-16)

Nathan could not rest in the crack. The open older Studio place lacked the current LIFE prompts. The latest native client was tested by walking from outside through the opening, stopping and pressing E: it rests and keeps a checkpoint. Earlier tests teleported straight inside and did not cover this route. Keep the same retreat box, collider, silk safety and rest requirements; add a near-home prompt explaining that the entrance is under the wooden roof, and a stillness prompt inside. Keep the peacock dance hint alongside this guidance outside the retreat. Decorative paint cracks and the top of the wooden roof are not rest locations. E/L3 still acts on held prey first; rest requires empty jaws. See verification/roblox-continuing-windows for exact runs and remaining device checks.


### ROBLOX-35 — Growth, safe moulting, drawn stages and real adulthood (Chet, 2026-10-17)

Port frozen LIFE-10..12 and GROW-01..03. Growth.luau uses food actually granted (0.9 per stage), three 12-game-hour moults in the safe crack, 10 hours of soft skin and three retained old skins. The exporter runs Godot growth.gd itself for 30 transition records including an interrupted restore; its UID is committed. These durations and four visual scales (1, 1.15, 1.32, 1.50) are artistic, not measured instars. No new biology claim or change to SPEC. During a moult the existing fixed action tick advances LifeClock at its sleep rate, movement/jump/drop/appearance changes are held, and the wasp cannot arrive. Soft reach follows frozen JumpPlanner.configure: max launch speed and maximum flight time scale by sqrt(0.7), with gravity and collider unchanged. Drawn growth alone never changes movement.

Scale the rig around the original support plane, keeping contacts in world space; step normally to a wider stance. The abdomen's condition, pale soft skin, independent idle motion, Reduced motion and peacock display compose with scale. Old skins are noncolliding/nonqueryable decorations. Standard/main adulthood calls finishAdult; Free/Gentle is excluded, and progress remains outside checkpoints. Schema 3 retains growth and the food-ledger cursor. Old schema 1/2 records default to a young spider with the existing granted total already seen; schema 3 missing/bad growth is refused rather than silently repaired. Saves and unlocks still last only for the session.

### ROBLOX-36 — Closer peacock framing, fan polish and quieter room (Chet, 2026-10-17)

Nathan liked the dance and asked for a closer camera, an improved look and a quieter low hum. Peacock orbit distance is 0.62 of the user's chosen distance, smoothly following appearance changes and widening by sqrt(stage scale) as the body grows. Existing collision casts and limited recovery framing use the adjusted distance. The dance timing is unchanged. Richer blue/teal fields, a thinner cream fringe and folded fan, brighter orange and six tiny teal scale streaks retain the clean silhouette; full detail is 119 parts, low detail remains 80. These are art choices. Adult male colours and courtship are an unlocked cosmetic at all gameplay stages; this deliberately does not simulate immature Maratus courtship. No monetization.

Reduce the continuous room track from 0.16 to 0.09 (about 5 dB), leaving flies and the eight-second wasp arrival warning alone. Stack day/stage and notices in one top column after native playback exposed an overlap. Existing fixed timing, physics shape, privacy and Data Sharing settings remain unchanged. Exact checks, evidence and publication are in verification/roblox-growth-polish/RESULTS.md.


### ROBLOX-37 - Reconciled field notebook (Claude and Chet, 2026-10-17)

Merge Claude's notebook branch 657ce9d with Chet's independently tested 77ca385. Use Claude's typed model, state-diff watcher, responsive page list, device-aware game notes, end-screen entry and layout tests. Retain Chet's finite-number guards, native input ownership fix, actual Godot-exported 35-transition goldens, peacock courtship entry, corrected game caveats, optional discovery notices and retention/pause tests. Both branch histories remain. No Godot gameplay changes; SPEC remains frozen.

25 authored pages, 24 reachable: the surface-vibration page stays dormant because the port has no such sense. Claude's nearby fly-takeoff event opens the hearing page. A successful peacock dance opens the new sourced courtship page. The first spider is described as inspired by the bold jumper; the cosmetic adult male peacock is explicitly not a biological juvenile. The current rig does not show a hydraulic take-off push. Source citations are readable text, not external browser launches. `gen_notebook_pages.py` is the single generator (the former command delegates to it). Frozen content copy and actual-engine transition goldens have separate filenames.

Notes belong to the player, outside world checkpoints and LifeSession. They survive recovery, unrelated new lives and mode changes, but remain session-only. The world waits while reading; closing returns to the menu, end screen or play. Eye time uses simulated play seconds and stops during pause, consistent with the implemented slow-motion clock. Native directional input belongs to the notebook action; native GuiService selection is cleared because it can consume reading directions first. Fonts use rounded integer sizes, as Roblox stores them. Full-page text heights use TextService measurements; AutomaticSize alone clipped later checklist items after a phone resize. Short screens hide the hint row to preserve reading space.

### ROBLOX-38 - Optional things-to-try checklist (Nathan, 2026-10-17; implemented by Chet)

Nathan preferred a checklist to not knowing what to do. This explicitly amends the old no-checklist design intent without editing frozen SPEC.md. The notebook retains its discovered-page list; **To try** opens twelve optional, concrete invitations with observed/unobserved checkboxes. No progress reward, mandatory order, completion gate, or task to starve/get caught. It is guidance, not an inventory of every hidden page. Unobserved biology remains unreadable. C or Y/Triangle opens it inside the notebook; touch has its own footer button. The footer fits short/portrait screens at large text. Nathan can test this before deciding whether to make it more prominent.

The next release-preparation chunk is robust server-backed persistence, followed by settings/touch polish and actual console/tablet acceptance. Publishing this update means the existing private test place; it does not authorize public audience changes, fees, identity verification or enabling Data Sharing.


### ROBLOX-39 - Two saved records: progress and rests (Claude, 2026-10-17)

Persistence keeps two records per player, saved separately. **PlayerProgress** (key `P_<UserId>`): notebook pages found and eye time, the To-try checklist state, the Easy unlock, adulthood reached (`finished_main`), the chosen appearance, the saved preferences (focus toggle, reduced motion, last seen, automatic grip, notebook notes, large text, sound muted), the schema number and `updatedAt`. About 1 KB; it must be very hard to lose. **WorldRests** (keys `R_<UserId>_main` and `R_<UserId>_free`): the last rest of each mode as an ObjectRecord checkpoint snapshot. Replaceable: losing one costs a rest, never the notebook. "Adulthood reached" and `finished_main` are the same flag (the Easy unlock of ROBLOX-35). The record holds no history of deaths or lives. Every number and name is in `Shared/Data/SaveRules.luau`.

A new life replaces the last rest only once the new spider rests for the first time. Until then the old rest stays, so a death followed by leaving does not erase "Back to your last rest" (menu text says so).

### ROBLOX-40 - The server owns DataStore; the boundary is for corruption safety, not anti-cheat (Claude, 2026-10-17)

The simulation still runs on the client (see the ROBLOX-37 note), so the server cannot be the authority on gameplay and does not pretend to be. The server alone touches DataStoreService (`Server/SaveService.luau`, `Persistence.server.luau`); the client sends small RemoteEvent messages (`SaveRemotes` in ReplicatedStorage). The server validates everything it is sent: type and range of every field, unknown page ids dropped, preferences limited to the known keys, a rest checked by ObjectRecord's full structural check plus `Checkpoint.check` against a stub world, bounded depth, node and character counts, and per-player token-bucket rate limits. A malformed message is rejected and dropped, never raised and never written. This protects the stored data from corruption, bugs and stale clients. It is not anti-cheat: this is a solo game with no economy, a player who forges their own notebook only changes their own notebook. Comments in the code say so. A rejected message gets no reply (the client learns the real status from the next status message).

Size caps come from measured rests (see HANDOFF-roblox-state.md): a rest is about 21.6 KB early and plateaus near 64 KB in a long life; the cap is 262,144 characters (4x the plateau, one sixteenth of the 4 MB DataStore limit). Progress cap 16,384 characters.

### ROBLOX-41 - Versioned envelope, checksum, one backup, forward migration (Claude, 2026-10-17)

Every stored value is `{schema, updatedAt, payload, checksum, lock?, backup?}`; the checksum is an FNV hash over canonical JSON. Statuses on open: missing, ok, migrated (older schema brought forward by a migration table, on a copy, never mutating the stored value), newer (written by a later game), corrupt (checksum mismatch or unreadable), invalid (payload fails its rules). On corrupt, newer, or a failed load the player plays with in-memory progress only, sees the plain line "Saving is off for this visit..." with the reason, and **nothing is written over the stored value**: defaults never replace a record we could not read. One previous payload is kept inside the stored value as a backup, so a bad write can be recovered by hand. If the progress record is corrupt but its backup is intact, the player sees the backup's notebook for this visit (still session-only; the stored value is not touched). A corrupt or newer rest falls back to its backup for the visit; the next real rest replaces a corrupt value, but a newer build's value is never written over. A same-payload retry never produces a self-copy backup. Not built: repairing a corrupt record in place (deliberate: leave it exactly as found for a person to look at).

### ROBLOX-42 - Write discipline: UpdateAsync merge, debounce, backoff, flush (Claude, 2026-10-17)

Writes are `UpdateAsync` only, never a blind `SetAsync`. The transform does not yield, may be run more than once, and returns nil to cancel (nothing newer to write). Progress merges monotonically with what is stored: pages are a union, longest eye time wins, finished_main is OR, appearance and preferences are last-writer-wins by their own time. A session that lost its place or has a stale view therefore cannot take anything away. Rests compare `updatedAt` and keep the newer.

Schedule (all in SaveRules): rest/morning checkpoints save as soon as at least 10 s after the last rest write; notable progress is debounced to at least 30 s; PlayerRemoving and BindToClose flush at once (up to 4 attempts, 1 s base backoff, 24 s deadline, inside the 30 s shutdown window). A failed write keeps the dirty flag and retries with exponential backoff (2 s base, 60 s cap) within a request budget of 10 per minute per player. Errors are classified (throttle / config / value / transient) so a configuration error (Studio API access off) falls back to session-only quickly instead of retrying forever, and a value error does not loop.

### ROBLOX-43 - Session lock and takeover (Claude, 2026-10-17)

A lock `{sessionId, heartbeat}` sits in the stored envelope. The holder refreshes it every 30 s. A newer session may take over a lock that is older than 120 s (a crashed server); a fresh lock held by another session keeps the newcomer read-only with "Your game is open somewhere else, and this copy cannot save over it." A session that finds its lock taken goes read-only with the same plain notice and stops writing. The lock lives in the same value as the data, so taking and releasing it is one atomic UpdateAsync; the lock is released on leave.

### ROBLOX-44 - Store names and the test place (Claude, 2026-10-17)

Production store `Windowsill_v1`. Test place (detected by `ServerScriptService.PortTests`) `WindowsillTest_v1`. Studio sessions of the production project do not touch the production store: they use the test name unless the `SaveStore` Workspace attribute names another. The name used is published as the Workspace attribute `SaveStoreName` so Chet can verify it. In the test place each run uses its own key prefix (`t<runTag>_<UserId>`), so Studio runs never meet an old save and never clutter a real player's keys.

### ROBLOX-45 - Client: the menu waits for the server, and only what the player touched is sent (Claude, 2026-10-17)

The client says hello (6 tries, 2.5 s apart), then waits up to 4 s for the first reply before showing the start menu (in the test place the wait is off unless the Workspace attribute `SaveWait` is true, so the older client suites are unaffected). If no reply comes, the game starts session-only with the saving-off line; it does not hang. Saved state is applied before the menu so the notebook is already there. Defaults never override stored choices: a preference or appearance is sent only when the player has changed it ("touched"). The menu shows a plain line: saved, saving, trouble, or off and why (`UI/SaveText.luau`). Status changes also give a short toast, except the ordinary saving/saved flicker.

### ROBLOX-46 - What persistence deliberately does not do (Claude, 2026-10-17)

No server copy of the simulation, so a stored rest is validated for shape and consistency, not replayed. One level of backup. No in-place repair of corrupt or newer records. No ProfileService-style dependency. No ordered stores, leaderboards or cross-player data. Notebook notes remain per-session word choices, not free text. The real DataStore backend is thin and tested only in Studio (`tests/studio/StateSpec.luau`, which marks the DataStore checks "not run" when API access is off). The checks that the stored number round trip is lossless and the error-message patterns used by `SaveStores.classify` are assumptions until Chet runs them in Studio.

### ROBLOX-48 - Peacock price intention reaffirmed (Nathan, 2026-10-17)

Nathan reaffirmed: "the peacock spider will be 99 cents remember, however that works". Intended sale: a one-time cosmetic add-on for the peacock appearance and dance, targeting approximately US$0.99 through a Roblox Game Pass. Verify current Roblox pricing and select the Robux price when implementing sales; do not promise an exact dollar equivalent across purchase methods or regions. The daughter's first spider and the full game remain free. Peacock stays unlocked during testing until Nathan requests sales activation. This reminder records the intended price; it does not activate purchases.

### ROBLOX-47 - Save review and real-store acceptance (Chet, 2026-10-17)

Preserve pages earned during yielding writes; renew locks ahead of failed-read retries; retain ownership until rest writes finish. Never write a rest without first reading it successfully. This supersedes ROBLOX-41's sentence permitting replacement of corrupt rests: corrupt, invalid and newer values remain untouched, including damage found on retry or write. Unavailable service and permanent write rejection must report session-only, never Saved. Shutdown awaits PlayerRemoving flushes already in flight as well as entries still in the service.

Real isolated DataStore acceptance passed: 106 engine checks (none skipped), 23 live-client checks, evidence 461991282cc6007c. Normal restart then revealed the shutdown race, repaired in build 881f5ba653b169fe. Full evidence and final follow-up are in verification/roblox-state-windows/RESULTS.md. Store access remains server-only, but gameplay is client-originated and this is corruption protection, not anti-cheat.
