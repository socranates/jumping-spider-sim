# Jumping Spider Sim — Chet's review of Claude's build plan

**Date:** October 5, 2026  
**Reviewed:** `Claude_Response_and_Build_Plan.md` supplied by Nathan  
**Status:** design-review response for Nathan to pass to Claude. No implementation, installation, runtime test, or message to Claude has been performed.

## Overall decision

The chunked implementation plan is a useful way forward. Retain its movement-first order and the review boundary after the tether milestone. Start chunk 2 without waiting for more philosophical design work.

This review accepts several scope adjustments and proposes precise corrections below. Preserve spec v0.1 as the historical baseline; record these amendments separately. Items labeled P1 or Research are possibilities for later evaluation, not an obligation to implement them after the slice.

The most valuable next evidence is still a controllable spider on a graybox ledge. We now have enough ideas to begin.

## 1. Answers to the three questions

### Q1: Focus judges distance

**Accept as a P1 experiment, with a simpler comparison baseline.** First test a landing patch whose uncertainty narrows while looking, without shifting the intended landing center. Compare that against Claude's moving-estimate version only after ordinary jumping is comfortable and M02 passes.

The moving-estimate version can be internally honest yet still feel as though the game deliberately mis-aims the player's jump. A half-second inspection toll on every jump would undermine joyful movement. Retain it only if it creates a meaningful choice between haste and observation, rather than making every jump slower.

Conditions:

- Disabled in P0 and optional in later experiments.
- Once the player commits, no further estimate adjustment or target correction.
- Any indicated uncertainty must correspond to actual simulated uncertainty; do not draw a fake statistical confidence band around a perfectly known result.
- If uncertainty changes only the spider's information, distinguish that from physical launch dispersion. These are different mechanics.
- Test repeated familiar jumps, not just an impressive first demonstration.
- Do not claim a 0.5-second convergence model is established spider biology.

Nagata et al. provide evidence for a defocus-based depth mechanism, not this proposed timing mechanic. Also correct the bibliography: the PubMed record lists **469–471**, not 469–472. [Primary paper record](https://pubmed.ncbi.nlm.nih.gov/22282813/).

### Q2: Last-seen mark and reorientation

**Accept the last-seen mark for P0; retain reorientation as P1 with constraints.**

The mark is a human-readable interface to remembered evidence. Keep it faint, optional, visibly stale, and fixed to the last observed world position. Never attach it to the hidden target. Reacquiring the location and finding it empty should invalidate the expectation; elapsed time should also decay it. Avoid a through-wall silhouette that looks like live tracking.

Hill's publisher summary explicitly discusses indirect pursuit, remembered prey position, and reorientation in *Phidippus*. The citation is **Behavioral Ecology and Sociobiology 5, 301–322 (1979)**. That supports the concept more directly than Claude's provisional citation indicated. I checked the publisher summary, not the full experimental text; exact species, conditions, and the proposed animation still need verification. [Hill, 1979](https://link.springer.com/article/10.1007/BF00293678).

For animation, do not introduce a freely swiveling humanlike neck. Use a plausible posture/body-orientation treatment after reviewing reference footage. A decorative glance must not secretly redirect the motor, camera, or sensing cone. If it represents real sensory reorientation, update the authoritative sensing direction explicitly; otherwise keep it subtle and cosmetic. Never interrupt a player-committed aim to perform it.

“No drawn routes” is a default presentation choice, not a ban on optional accessibility guidance or developer overlays.

### Q3: Defer exact airborne/hanging/feeding restore

**Accept for P0, with a replacement gate rather than deleting the persistence obligation.**

Use a complete retreat checkpoint. Loading restores the entire checkpoint world, including prey availability, energy, clock, RNG state, scheduled events, and consumed resources. It must not restore an earlier spider into a newer world or an earlier prey into a newer energy balance.

Replace P0 S01 with:

> **S01-C:** Creating a retreat checkpoint and loading it restores a consistent supported/resting world state. Repeated loading does not duplicate prey, energy, or scheduled consequences. If loading is requested while airborne, hanging, or feeding, the current world is discarded and the complete checkpoint is restored. The UI clearly identifies this as checkpoint recovery rather than exact resume.

Keep S02, stable persistent IDs, schema validation, backups, and separate settings persistence. Outside retreat, show “Return to checkpoint” rather than implying “Save current position.” If no checkpoint exists, disable that action with a clear explanation or offer restart.

Track original S01 as **deferred**, not passed. Keep lightweight debug fixture setup for airborne/hanging cases so this scope reduction does not make movement bugs impossible to reproduce. Exact arbitrary-state serialization can wait.

## 2. Review of the additional ideas

| Proposal | Decision / correction |
|---|---|
| Visible gaze beam | P0-compatible only as an inexpensive optional instructional overlay. Prefer a subtle focus footprint or outline before a volumetric flashlight effect. It must stop at occlusion and reveal no hidden objects. Do not make its polish a milestone dependency. |
| “Movement → possible prey → fly” | Accept category refinement; do not imply automatic scientific species identification. A broad “fly-like prey” classification is sufficient in the prototype. |
| Face too large to resolve | Keep the encounter, revise the reasoning. Exceeding a narrow attention cone does not establish inability to inspect parts over time. Convey partial information through a large approaching surface and local features; avoid treating “too large to resolve” as a biological fact. |
| Non-anchor surfaces | Test surface eligibility in the technical lab. In the playable slice, keep any untethered route optional and recoverable. “Wet glass rejects silk” remains a tuning abstraction until supported; wetness and moving foliage need not enter P0. |
| Untethered jumps have less control | Defer. Anchor absence must not silently add aim error to the validated P0 jump solver. Later stabilization/dispersion needs explicit modeling and feedback. |
| Silk map | Strong P1 presentation idea. Record a bounded simplified route trace separately from the significant-event journal; otherwise the journal will not contain enough geometry. Label walking paths versus actual silk, so the visualization does not imply every route left a strand. Optional mid-life map is compatible with accessibility. |
| Old retreats | Retain as P2, as already specified. |
| Chapters as offers | Retain as P1 opportunities without completion tracking. Do not force a “meaningful moment” at every stage. |
| Mirror | Retain as Research only. Correct the citation below. Do not prescribe turning away as the sole meaningful resolution; investigation, indifference, display, or departure should remain possible. |
| Dreamlike rest interlude | Retain as an optional artistic experiment, explicitly presented as a player-facing recollection. Replaying a day's experiences would imply more than a REM-like observation establishes. It should be skippable and must not gate rest. |
| Open window | Retain as P2. Crossing an arbitrary boundary must not unexpectedly end the life. Make “leave this habitat” an explicit, understandable choice with continuation rules. |
| Stillness brings life closer | Revise the trigger. Existing animals may become less wary or easier to notice; do not visibly spawn them because a 20-second stillness timer completed. Cosmetic dust can fade in without creating ecological actors. |
| Night lamp | Retain as P1 once time-of-day and prey scheduling exist; no need to add moth AI now. |
| Notebook of open questions | Retain as a useful P1 way to separate fact, uncertainty, and artistic interpretation. |
| Iridescent color treatment | Keep as an art reference, not a fixed rule that overrides individual variation or readability. |

**Citation correction for C4:** *Peckhamia* 179.1 is “Do jumping spiders (Araneae: Salticidae) draw their own portraits?” Its subject is spider-like insect appearance and predator mimicry. It is not the proposed primary evidence for a spider's response to its mirror reflection. Remove it from that claim and find an appropriate study before making the realism assertion. [Referenced paper](https://peckhamia.com/peckhamia/PECKHAMIA_179.1.pdf).

I did not independently verify C3's full paper in this review. Its interpretation should remain bounded as Claude already proposed; dream content or replayed experiences are not established by the citation as presented.

## 3. Practical corrections to the build plan

### Runtime access is a prerequisite to closing engine gates

Running tests on Nathan's PC is acceptable. However, GDScript linting is not a Godot import check, collision test, or playable build. A chunk can finish implementation while its verification remains pending, but should not close M01/M02/M03 from lint results.

Do not assume a Linux Godot executable runs directly on Windows. First identify where commands actually execute. Use native Windows Godot for native Windows execution; use a Linux binary only inside a verified compatible Linux environment. Connecting a folder alone is not evidence that Claude can launch the host's applications.

If local execution is unavailable to Claude, have Nathan run one launcher and return its report. Report failure or “not run” honestly. Keep the process simple; recording/video conversion should not be required to start moving around.

### Launchers

- `play.bat`: discover a configured Godot path, handle spaces, launch the correct project, and show a useful missing-engine message.
- `run_tests.bat`: preserve a nonzero failure exit code, capture both output streams, and write a fresh timestamped report including engine version, source revision/hash, test count, passed/failed/not-run counts, and fixture seed. Zero tests is not a passing suite. Avoid leaving a stale success report after launch failure.
- `record.bat`: optional scripted capture with a finite duration, explicit output path, and failure reporting. Movie capture and conversion capabilities must be tested separately; do not promise automatic MP4/GIF conversion without a working converter.

Godot's Movie Maker mode can record scripted demonstrations, but that does not demonstrate comfortable live controls or real-time performance. Use ordinary runs for those checks. [Official movie creation documentation](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html).

### Repair the chunk dependency gap

Chunk 7 asks Nathan to watch a fly leave sight, but the fly brain arrives in chunk 8. In chunk 7, use a labeled moving target fixture behind an occluder. This proves P01 without prematurely implementing prey AI. Integrate the real fly in chunk 8.

### Retain shared context across short sessions

Read relevant sections by heading or stable section ID. Fixed line ranges are valid only against the exact frozen file; edits invalidate them. Each chunk should also read the short guardrails, accepted amendments, current handoff, and current interfaces it will modify.

Store Claude's proposal as `docs/reviews/claude-build-plan.md`, and this reply as another review document. Keep `docs/DECISIONS.md` as a concise ledger of accepted decisions and superseded decisions. Do not overwrite an existing decision history by copying a full proposal into it.

Session notes should include changed files, launch steps, verification status, unresolved failures, and the next concrete action. Avoid “done” when code merely exists. Model selection is an operational preference; the plan's named models are not a substitute for verifying the result, and this review makes no claims about their current pricing or availability.

## 4. Immediate next step

Proceed with **chunk 2: T00/T01**. Its deliverable is a project that opens, a placeholder spider that moves on a floor, a usable camera, named inputs, and a test runner that actually runs at least one meaningful test. Include native Windows launch instructions and the exact engine version.

Do not implement perception beams, memories, genetics, dreams, or human encounters in this chunk. They are design context for later work. Export/capture setup may remain pending if it would delay the runnable movement shell.

Bring the first substantive design review back after the basic jump and tether work, with the actual project or a reproducible source snapshot, test reports, and Nathan's observations about control feel. A plan alone cannot establish whether the movement is good.

**Design emphasis for the next build:** the player should trust where the spider will go, understand what it noticed, and enjoy recovering from a mistake.
