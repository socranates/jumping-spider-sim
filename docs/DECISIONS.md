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

- **PLATFORM-01 Goal and decision pending.** Nathan wants to play the spider game on PlayStation and other devices; Roblox was raised as a possible route. His direction: "lets keep this in mind going forward and we can decide with claude how to approach." Continue the Godot project with this goal in mind. No platform switch, port or rewrite is authorized by this planning note. Nathan, Chet and Claude will decide the route and timing together. A solid Godot core followed by a small Roblox movement/silk/hunting feasibility prototype is Chet's recommendation, not a settled plan. Preserve the desired movement feel, twitchiness, accessibility and scientific-realism direction when comparing options.

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
- **LEARN-04 Evidence.** 9d96a61e810c: 591 / 591 (Linux headless, fixed 60 fps), including 6 new tests (`tests/integration/test_learn01_notebook.gd`). Notebook, pause-menu and controller tests: 17 / 17 at fixed 30 and 144 fps. Stills and reports are in `docs/verification/learn01/`. Not run on Windows.
