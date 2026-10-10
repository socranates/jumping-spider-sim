# Jumping Spider Sim — Perception review and next coding handoff

**From:** Chet · **For:** Nathan and Claude · **Date:** October 8, 2026  
**Reviewed build:** `4b9098e032ed` · **Scope:** chunk 6 / T06, perception, memory, and the catch-camera changes.

## Decision

The perception milestone demonstrates the intended loop: notice movement, deliberately orient, inspect, lose sight, and retain a fading expectation about a place. Continue toward the first hunt. Repair the small-target occlusion issue below first, and define evidence-based contact association before introducing multiple flies.

Keep the longer jumps, current movement controls, free P0 safety-line reserve, explicit Focus interaction, and current classification timing. No broad movement or camera rewrite is needed.

Nathan answered **“yes”** when asked whether he had tried the new stage and whether Focus and the memory cue were understandable. That is brief positive feedback, not a detailed playtest report. Preserve the current interaction pending more specific experience with real prey.

The original OneDrive project was reviewed read-only. The archived source was extracted into a separate workspace for verification; only that copy received a review-only diagnostic script. This document is for Nathan to pass to Claude. No game changes or messages to Claude were made here.

## 1. Verification and evidence

I read the chunk-6 handback, perception/memory/observation and HUD code, Focus control code, relevant tests, the P01 report, and the snapshot metadata. I inspected the perception capture frame sheet. I did not interactively play the game or watch the entire video.

The handback says Windows verification has not occurred, but the current project contains a Windows report dated `2026-10-07T15:40:54Z` with **338 passed, 0 failed, 0 not run**, for the same evidence ID. Update the handback to acknowledge that report; do not infer who ran it from the file alone.

I independently reran the archived build on native Windows Godot `4.7.2.stable.official.ed1daf0bf`, headless, Jolt, using `--fixed-fps 60` and seed `20261005`:

```text
evidence_id: 4b9098e032ed (source 4e0caccf, settings 8b6707d4, tests 3d848065)
SUMMARY tests=338 passed=338 failed=0 not_run=0 seed=20261005 filter=all result=PASS
```

The independent run covers the full existing suite, including all four gate files. P01's eight fixtures passed. This accelerated run verifies the tested simulation behavior, not real-time performance, graphical frame pacing, or physical-controller comfort. The existing ordinary Windows report is separate evidence.

Archive reviewed: `tests/reports/snapshots/2026-10-08_4b9098e032ed.zip`.

```text
source_hash_md5:   4e0caccfb93fbb2a947db28f1c4277a3
settings_hash_md5: 8b6707d4bb26d00c21239d1c75d3aec2
tests_hash_md5:    3d8480658df657f4f320cc6aa3e3f84c
```

The engine emitted the same startup certificate-store diagnostic encountered in the previous restricted-environment review, alongside the tests' intentional diagnostics. The suite completed successfully; this is not a claim of a diagnostic-free launch.

**Additional review probe:** a fully hidden small target generated a sensed contact. That case is outside the 338 existing tests and demonstrates a coverage gap. Passing the existing P01 fixtures does not establish correct occlusion for every supported target size.

## 2. Fix before T07: endpoint tolerance leaks small targets

**Priority: P1.** Relevant code: `scripts/perception/sensor_system.gd`, `SIGHT_TOLERANCE`, `_clear()`, and the sample-ray visibility helpers.

`_clear()` accepts a world hit if it is within 0.05 WU of the sample endpoint. A target with radius 0.01 WU can be completely behind a barrier, yet all five rays are accepted because the barrier is closer to its sample points than that tolerance.

### Reproduced arrangement

All coordinates are in the observer's local test scene, with gaze along negative Z:

| Object | Configuration |
|---|---|
| Eye | `(0, 0, 0)` |
| Opaque WORLD-layer box | Center `(0, 0, -0.97)`, size `(0.2, 0.2, 0.02)` |
| Target | Center `(0, 0, -1.0)`, radius `0.01`, zero velocity |

The barrier extends from distance 0.96 to 0.98. The target begins at distance 0.99, so its entire sphere is behind the barrier. Its apparent size is large enough for the configured inspection threshold. After physics synchronization and one manual sensor tick, the actual output was:

```text
wall_hit_distance=0.96000003814697
fully_occluded_target_contacts=1
visible_samples=5
expected_contacts=0
```

The review probe intentionally exited with failure when the hidden contact appeared. It lives only in the extracted review copy as `reviewer_small_target_occlusion.gd`; the original sensor code is unchanged.

### Requested repair

Treat a world hit before the observed sample as occlusion unless the difference is genuinely a small numerical endpoint error. Use a much smaller, justified tolerance and/or constrain it relative to the sample geometry; do not let a generic tolerance span the entire target. Preserve valid partial visibility and stable behavior at ordinary surface boundaries.

Add a regression using the arrangement above. Also check that a partially exposed small target is sensed, an openly visible small target still refines, and a last-seen spot behind the same barrier is not declared empty. The same `_clear()` result currently affects both observation and empty-spot invalidation.

This is a focused visibility correction. It does not require a new renderer, a new perception model, or a large test expansion.

## 3. Answer: what should the catch camera do?

**Keep the automatic turn limited to 45 degrees and optional. Do not restore an unsolicited 90-degree swing by default.**

The measurements are useful: the cap helps an already oblique view but does not solve the default cliff-cap catch. Record that limitation honestly. A capped assist is not a guarantee that every catch will be framed well.

Nathan already likes the camera. More automatic rotation risks changing the successful controls and can make camera-relative movement less predictable. Any look input, recenter, or preparation must continue to take precedence.

For the remaining awkward view, prefer a small collision-safe pivot/pitch adjustment, stronger active-line/attachment cues, or a player-requested framing action. A larger turn could be offered through an explicit “show my line” action or an assistance option, where the player chooses the reorientation. It should not become a surprise.

Do not spend another whole chunk optimizing one lab cliff if recovery remains understandable. Keep the issue in the backlog and verify it in the windowsill topology. Prioritize an intelligible line and usable reel/lower/release prompts over cinematic composition.

## 4. Answer: is Focus the right interaction?

**Keep explicit Focus as the default. Keep 0.40 s and 1.00 s as the current classification baselines.**

Focus is a deliberate request to turn the spider toward the player's aim. It should not be described as switching vision on. The sensor already inspects suitable objects along the animal's gaze without Focus being held. Orbiting the camera alone changes the viewpoint, not the animal's attention.

That distinction is useful and Nathan has briefly indicated that the stage makes sense. Do not add automatic gaze-following whenever the player stops moving; stillness should remain available for watching the world without surrendering control of the animal's facing.

Preserve the capped orientation rate and small gaze-elevation allowance as documented gameplay abstractions. The 35-degree tilt is acceptable for the prototype; it is not an anatomical measurement or a reason to add a freely swiveling neck.

Add a toggle option for Focus when implementing the early accessibility pass. A toggled Focus should be clearly indicated, cancelable, and unable to override a committed jump or a deliberate recovery action. Keep ordinary hold mode intact.

With real prey, refine whether the full label helps. The player should be able to act on “movement” or “possible prey”; classification must not become a mandatory one-second permission gate before every pounce. The two current timings are designed values, and prey behavior may reveal a need to revise them later.

The mark behind cover is acceptable if clearly shown as a remembered place: fixed position, stale styling, no silhouette, no live coordinates. Its current reduced strength can stay. Do not move it according to hidden prey motion.

## 5. Answer: what may the spider know about “the same thing”?

**A remembered contact is a hypothesis based on evidence, not a permanent world-object identity.**

The current sensor's `_tracks` dictionary is keyed by percept/object ID. Reappearing objects therefore receive the old contact and familiarity, even if their observed route could not support that inference. That was a reasonable one-target shortcut, but it should not become the multi-prey contract.

Use three distinct concepts:

- **World entity ID:** internal identity used for physics, ownership, saves, and debugging.
- **Contact/track ID:** the animal's hypothesis that observations belong to the same visible thing.
- **Category familiarity:** knowledge of a kind of movement/appearance, which does not establish individual identity.

A live visible target may have a world-ID link for validated interaction. That link must not grant hidden position updates or decide observational identity after a meaningful loss of sight. Capture ownership belongs to authoritative collision/interaction resolution, not to a remembered marker.

### Minimal association rule for T07

1. Preserve a track during continuous observation and brief, justified sampling gaps.
2. After loss of sight, compare a new **visible observation** with lost contacts using last observed location, elapsed time, compatible apparent size/category, and observed motion when available.
3. Use a bounded plausible region. Its growth can depend on elapsed time and an explicit conservative movement bound; it must not depend on where the hidden object actually went.
4. Reuse a contact only when there is one plausible candidate and the evidence is reasonably strong. Treat this as inferred continuity, not certainty.
5. If candidates are ambiguous or none is plausible, start a fresh track. Do not transfer inspection exposure automatically. Old marks continue to decay or are invalidated through observed evidence.
6. Keep the implementation small. A conservative fresh contact after uncertainty is preferable to an elaborate tracker that delays the first hunt.

This allows a mark to be wrong in a meaningful way: the spider remembers where something was, and the player discovers that expectation no longer fits. Do not manufacture a false memory at random. Uncertainty comes from observation gaps and indistinguishable animals.

### Tests that protect the rule

- Two visually similar targets cross behind cover and emerge: no hidden-ID-based perfect association or automatic classification transfer.
- Swap only hidden world IDs while keeping the visible evidence identical: player-visible contacts should behave identically.
- A target reappears outside the plausible region: it is a fresh contact even if it has the old entity ID.
- One clearly plausible continuation can be reacquired; loss still never updates the remembered position.
- A stale place observed empty is invalidated; an occluded place is not.

Update P01 F6 and the existing tests that require reuse of the same track by object ID. Replace that requirement with justified reacquisition under the new rule. Record the changed assumption; do not quietly weaken the hidden-information tests.

## 6. Boundaries for the first prey AI

Build one fly archetype with a perch graph, resting, alertness, takeoff, fleeing, and choosing another perch. Start with one live fly for integration, then add a second for association/fairness tests, and finally the modest slice population. Keep the magenta target in the testbed, clearly separate from the playable prey.

**The fly must have its own sensory evidence.** “The prey brain reads memory” means the fly's memory or a simple fly-specific observation model, not the player's spider memory. It may know its own needs and movement state. It must not read the player's jump button, Focus state, intended landing target, or a hidden true spider position to trigger escape.

Keep goal selection small and interpretable: rest/food opportunity, perceived threat, safe perch, travel cost, and hysteresis. Log why it changed state. No full behavior-tree framework is needed.

Resolve capture spatially and once, with explicit ownership; feeding grants reserves only while valid and can be canceled. A fly can escape while the spider recovers on silk, giving misses a real opportunity cost without adding a resource penalty to recovery.

Do not require full “fly-like prey” classification to permit a physical strike. Looking helps the player decide; it should not invisibly enable a hitbox.

## 7. Cost, lifecycle, and accessibility

The current sensor enumerates perceivable nodes each tick, then gates expensive checks. After a cue, live contacts may receive per-tick checks. That is workable for the stage, but measure it with the planned 3–6 flies. Record candidate count, ray counts including memory-spot checks, and CPU time before claiming the sensor budget is met.

If staggering checks, integrate exposure according to evidence actually acquired. Do not turn an unobserved gap into guaranteed uninterrupted inspection. Keep close interactions responsive. Add cleanup for despawned percepts so the internal `_tracks` dictionary does not retain every departed insect forever; memory marks may still expire independently.

Pair meaningful visual cues with optional sound/haptic or a stronger text/contrast treatment in an early accessibility pass. No channel should be the sole source of essential warning. Start with scalable text/contrast and Focus toggle; a complete audio production pass can wait.

## 8. Next chunk and handback

Recommended order:

1. **Visibility fix:** close the reproduced small-target leak and protect remembered-spot invalidation.
2. **Contact association:** implement the conservative evidence rule and the two-target fixtures; update the superseded same-ID tests explicitly.
3. **T07:** one fly brain, perched/flying transitions, readable sensing-based escape, spatial capture, interruptible feeding; demonstrate A01 and L01.
4. **Small usability additions:** Focus toggle and cue legibility where cheap. Preserve current movement and default jump reach.

Avoid another broad camera pass, genetics, seasons, or additional prey types in this chunk.

Hand back a new evidence ID/archive, the relevant test results, a short actual hunt demonstration if available, and Nathan's notes. Mark full M04, performance, physical-controller, and human-study gates separately from automated passes. Update the chunk-6 document's outdated Windows statement and append accepted decisions to the ledger without changing the frozen specification.

**Evidence retained in Chet's workspace:** `review_windows_338_fixed60_2026_10_08.log`, the extracted archive's runner/gate reports, and `review_small_target_occlusion_2026_10_08.log`. The additional probe demonstrates a real failing case even though the shipped suite passes.

The next review should answer whether watching and approaching a living fly is enjoyable, whether its escape feels fair, and whether the player can explain the result of a hunt.
