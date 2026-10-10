# Jumping Spider Sim — Chet’s chunk 7 review and chunk 8 brief

Date: 2026-10-10. Reviewed build: **5ebea0fc6270**, archive `2026-10-10_5ebea0fc6270.zip`.

## Decision

**Accept chunk 7 as the foundation for the habitat. Proceed to T08. Preserve the current mechanics and tuning.** Address the small clarity and reporting items below within that work; do not insert another standalone fly-balancing chunk.

Nathan’s latest feedback is decisive for that scope:

> “Its coming along great.”
>
> “I am satisfied with all the mechanics so far.”

His earlier approval of the controls, camera and longer jumps also stands. Keep movement, jump reach, camera behavior, free P0 silk reserve, Focus behavior, stalking speed, fly reaction distributions, feeding and default capture reach. Changes to the habitat should give those mechanics a place and purpose. Do not quietly rebalance them to compensate for an awkward level layout.

This is a source, evidence and design review, not my own hands-on playtest. I inspected the archived implementation, the supplied stills and the scripted escape frame sheet. Nathan supplies the human satisfaction evidence. His statement supports proceeding; it does not establish every formal human-study criterion or prove that every hunt result is understood.

## Evidence and scope

The archive identifies source hash `a8db908918c2aad1eaad13aef94a462b`, settings hash `8b6707d4bb26d00c21239d1c75d3aec2`, and tests hash `ee29d8f5b1c628c242b5affdf4fbcbd3`. I extracted it into a separate review folder. The original OneDrive project remained read-only.

The supplied Windows report dated `2026-10-10T10:57:14Z` matches these hashes and reports **469 tests: 468 passed, 0 failed, 1 not run**. The not-run item is the deferred save/load half of L01. Claude’s reported real-time gate results remain M01 20/20, M02 100/100 with 8/8 invalid refusals, M03 10/10, P01 8/8, A01 5/5 and the implemented feeding portion of L01 4/4. Those fixture totals are not extra independent tests to add to 469.

My independent native Windows rerun of the extracted archive also returned **469 tests: 468 passed, 0 failed, 1 not run**, with evidence ID **5ebea0fc6270**, seed **20261005**, Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility settings and Jolt physics. This was headless at accelerated `--fixed-fps 60`; it verifies that test configuration, not real-time frame pacing. Log: `review_windows_469_fixed60_2026_10_10.log` beside this review. Runtime files were redirected into a separate review directory. The original project was not run or edited.

The review covered perception and association, the fly’s sensing and decisions, capture ownership, feeding, replenishment, presentation and the proposed habitat integration. This is not an exhaustive proof of all behavior. No real-display frame pacing, physical controller, long soak or new E01/E02 study was performed by me.

The discarded Claude reply and removed duplicate ledger block do not invalidate the archived code or matching reports. Continue from the files and the surviving A-023 through A-031 block. There is no reason to recreate chunk 7 from conversation memory.

## Answers to the three review questions

### 1. Is watching and approaching a living fly enjoyable?

**Accepted for this stage, based on Nathan’s satisfaction.** The implementation now offers something meaningful to watch: rest, grooming, alert posture, takeoff, relocation and settling. Approaching slowly changes the opportunity; it is not merely a timer before a guaranteed reward.

Do not increase stalk speed, grooming frequency or relaxation speed now. The next useful improvement is context: seeing the same fly across a planter rim, choosing cover or elevation, and deciding whether to follow after it moves. The windowsill can make the approach interesting without increasing the number of fly behaviors.

If readability becomes poor against leaves or dark trim, adjust background contrast, lighting and pose visibility first. That is an environment and presentation check, not evidence that the approved hunt timing needs replacing.

### 2. Does its escape feel fair?

**Keep the current behavior. Nathan approves the mechanics, and the inspected architecture supports causal fairness.** The fly senses visible motion and proximity; its decisions use its own sightings and remembered threat location. It does not use jump input or a proposed landing point. Capture is spatial and ownership resolves once; classification does not unlock a hitbox.

The quoted 8/12 result from a scripted approach is a small fixture sample, not a target success percentage or a measured population probability. Do not tune every reasonable stalk toward exactly two-thirds success. Geometry, posture, distance and timing should continue to matter.

Some uncertainty is appropriate for hunting a living animal. The player need not know the sampled reaction delay. They should be able to observe that the fly became alert or left before contact. The existing raised posture and wings provide the starting vocabulary. Preserve them and test them at the normal gameplay camera distance; no countdown, guaranteed warning interval or compulsory slow motion is requested.

**Strike assist is a legitimate accessibility option.** Keep it optional and off by default as currently implemented. Explain it plainly as widening capture reach. Preserve the wall check, ownership and feeding rules when enabled; do not stigmatize assisted play or secretly grant success.

### 3. Can the player explain the result of a hunt?

**The system has explainable causes; E02 remains unverified.** Nathan’s general satisfaction is positive evidence, but it is not a recorded explanation of a particular success or failure. The debug trace and scripted captions are useful developer evidence, not substitutes for a player understanding the ordinary view.

The desired ordinary explanations are simple: “I got close while it was busy,” “it took off before I arrived,” or “I landed beside it.” Exact awareness values or knowledge of its random stream are unnecessary.

Make three modest clarity improvements during T08:

1. Remove the contradictory captured-prey “lost sight” mark, as specified below.
2. In onboarding, establish once that the green landing ring means the **surface is reachable**; it does not promise that a moving fly will still be there. The existing planner should remain a reliable movement tool.
3. Preserve a readable alert silhouette, visible departure and unmistakable held-prey/feeding state. Any optional explanatory cue must describe evidence the spider actually received. Do not surface the hidden fly’s decision log as player knowledge.

Later, ask for an explanation after one successful and one failed attempt with F4 off. Record the actual answer before marking E02 passed. This need not hold up habitat construction.

## Answers to the handback’s closing questions and options

The handback repeats the same three review questions, with additional choices. To make the answers explicit:

| Closing question | Decision |
|---|---|
| Enough to watch, or change stalk speed, grooming, calming or visibility? | Enough to advance on Nathan’s evidence. Preserve the numbers. Check visibility in the habitat first; add route choice and environmental context. |
| Is the escape spread right; tell or uncertainty; assist or crutch? | Retain the present spread as a baseline, not a quota. Keep uncertainty and readable posture/takeoff. Assist is an accessibility option, off by default. |
| What should the game show so the result can be explained without F4? | Clear alert/departure, accurate landing language, visible capture and feeding, and no stale lost mark for a directly known capture. Avoid omniscient explanations. E02 still needs an actual player explanation. |

For the three proposed implementation tasks: **T08 first**, incorporate the small capture-memory fix and clarity work, and keep **T09 next**. A separate constants-only feel pass is unnecessary given Nathan’s approval. The contact speed-bound refinement is a bounded follow-up, not a prerequisite for building the sill.

## Review findings and bounded corrections

### Captured prey should resolve a directly known contact

The known “lost sight” mark is confirmed by the supplied capture image and the integration: capture changes the fly’s state and removes its percept, while ordinary memory loss continues. Fix this at the capture event boundary, before its percept track is cleaned up.

Capture is direct bodily evidence, so using the captured world ID to locate a currently linked contact is legitimate here. It is not permission to reassociate hidden sightings by ID. Resolve the currently justified contact as caught and clear its mark; keep unrelated and ambiguous old contacts intact. If there was no contact, show held prey without inventing a prior visual classification.

Acceptance: an inspected fly caught once leaves no lost mark; an unclassified catch still works; catching one of two ambiguous flies does not erase both remembered places; feeding cancellation neither resurrects a mark nor duplicates prey or nutrition.

### Performance reporting needs a small correction

`tests/integration/test_prey_cost.gd` labels the sum of the sensor p95 and prey p95 as “p95 at most.” That is not a valid general bound on the p95 of their sum: their slow ticks may occur at different times. Keep the individual measurements, but collect both costs for the same tick and compute the percentile of the paired totals before claiming the combined budget. This finding does **not** establish a budget overrun.

The same report hardcodes “headless Linux virtual machine” even when executed on Windows. Emit the actual platform and record whether timing was real time or accelerated. In `PreyDirector.late_step()`, late capture/carry work is added to the cost ring and total but not `cpu_us_max`; update the maximum from the completed tick so it describes the same scope as the percentiles. Sample elapsed late-stage time once and use that value consistently.

These are reporting corrections, not a demand to optimize a system that is already satisfactory in play. F01 remains a separate representative graphical measurement.

### Documentation must reflect the current evidence

The handback’s final update correctly records Windows verification, but its opening, known-problem list and several later paragraphs still say nobody has played and no Windows run exists. Replace or date-qualify those statements and include both of Nathan’s current quotes. Keep physical-controller, real-GPU performance and formal study claims separate; a Windows report alone does not establish them.

### Keep association conservative

The size-scaled tolerance now has regressions for the reported tiny-target case, open and partial visibility, and memory behind cover. The joint association pass counts competing sightings before filing them, addressing the multiple-fly ambiguity the earlier implementation could not handle. Cleanup of vanished percept tracks is present.

The 2 WU/s default association bound can under-match a formerly perched fly that departed unseen. That is a documented conservative limitation, not a new blocker. If refined, choose a speed prior from the **observed category** and retain the last genuinely observed motion; do not read a hidden entity’s current velocity or private species state. Unknown movement keeps a generic prior. Test ambiguity again if the region grows: a larger region must not mean more confident individual identity.

## Chunk 8: T08, a place worth coming back to

The goal is a compact, replayable windowsill loop: leave a recognizable crevice, notice an opportunity, choose an approach, hunt or recover from a miss, feed if desired, experience one harmless change in the room, and return to rest. A 10–15 minute exploratory session should be possible without mandatory waiting or repeated need alarms.

### 8A — Preserve the lab and introduce the habitat

Keep the traversal lab as a testbed. Add a separate authored windowsill scene and select the habitat at the world-composition boundary. `main.gd` currently preloads the lab and connects lab-specific practice callbacks; introduce only the small shared interface needed for spawn, bounds, surfaces, perches and entry points. Lab disappearing-perch behavior must not accidentally become habitat behavior.

Use stable authored IDs for meaningful surfaces, perches, entry points, the retreat and the disturbance. They will support T09. Keep simulation ownership in the existing motor, perception, prey and needs systems. Avoid a generic ecosystem framework in this chunk.

Start around the specification’s 60 × 25 × 35 WU envelope. Provide wood trim, a planter rim, broad static leaf platforms, opaque cover, an underside passage and one crack retreat. Use simple collision shapes. Decorative veins, soil grains and silk texture should not become invisible collision traps.

### 8B — Make two useful routes

Offer a low-risk sheltered floor/trim route and a faster exposed route using the longer jumps Nathan enjoys. Both reach a useful hunting area and have a way home. Their tradeoff is position, exposure, view and travel time. Neither should require a new movement mechanic.

Keep four flies initially and validate the new perch graph against the actual geometry. Give relocated flies alternative reachable perches so an escape becomes another opportunity. Entry points should make sense as cracks or openings, while retaining the current unseen-replacement checks. Do not add a second prey type or a full ecology.

Test the camera in the actual crevice, under leaves, at planter lips and during a representative silk recovery. Resolve local geometry/camera obstruction problems without broadly changing the approved camera.

### 8C — Retreat as a physical place

Provide one authored silk-lined crevice, recognizable from outside, entered through ordinary movement and a context interaction. Rest is cancelable and returns control immediately. It can restore the existing rest reserve through the needs model, but do not reduce jump performance, impose mandatory sleep or add starvation consequences in this chunk. Quiet observation remains valid play.

Interaction priority must be explicit: while holding prey, the feed prompt and retreat prompt must not compete for E. For P0, let feeding take priority and offer rest after the meal; the player may move away at any time. Keep support, collision, pause and camera behavior sound during entry and exit. Do not teleport the spider to hide an inaccessible retreat.

Give this state a future checkpoint boundary, but label it “Rest,” not “Save,” until persistence actually exists. T09 follows the previously approved **S01-C whole-world retreat checkpoint** amendment; do not silently revive the original arbitrary-state S01 requirement.

### 8D — One harmless environmental event

Implement a small authored sequence, for example distant room movement followed by a broad soft shadow passing across the sill and then clearing. Give a usable advance cue, an actual visible local change, and a quiet end. Keep collision surfaces static and avoid forces that change a committed jump. This is an authored environmental encounter, not predator AI or a weather simulation.

Pause must freeze its simulation phase and dependent state. It should not fire repeatedly while the player is trying to feed. Use an explicit phase and bounded clock so T09 can save it later. If there is an audio cue, provide a visual equivalent; a muted session must remain understandable. No harsh flashes, compulsory camera swing or threat of death is needed.

### 8E — Minimal onboarding and completion evidence

Use short contextual prompts, dismissed by the relevant action and available again through help. Teach noticing/Focus, stalking, the distinction between reachable ground and a guaranteed catch, feeding, silk recovery and rest. Do not force a particular successful hunt or prescribe a route.

Include the captured-contact correction and reporting fixes in this chunk. Keep new presentation observational: seeing a fly raise its wings can justify an alert cue; its unseen internal awareness cannot.

## Chunk 8 acceptance and handback

1. Both routes are traversable out and back with current controls, including a recoverable miss; the lab regression fixtures remain available.
2. Perches and entry points validate in the habitat. Four flies can relocate and replenish under the existing visibility restrictions without getting permanently stranded by the layout.
3. A hunt, canceled/resumed meal and retreat interaction coexist without duplicate capture, duplicated food or competing inputs. The captured mark is resolved correctly.
4. Rest is reachable, cancelable and nonpunitive. Pause freezes needs, flies, feeding, rest and the disturbance. No checkpoint persistence is claimed yet.
5. The disturbance gives a usable cue and visible change, remains harmless, and can be understood with sound muted. Exercise W01 here even if its formal completion remains tracked with T09.
6. Check camera clearance and aiming on representative habitat routes at the supported frame rates. Record headless checks separately from actual graphical M04 assessment.
7. Run the existing suite plus focused integration checks for the new habitat/retreat/event boundaries. Split long test groups as necessary. Record actual combined timing correctly; leave F01 open until its representative graphical run.
8. Provide a new evidence ID and archive, matching reports, a short ordinary-view loop demonstration, and brief player notes. List known limitations and deferred gates explicitly. Update the decision ledger once, without rewriting the frozen original specification.

No mechanics retuning, genetics, seasons, new prey archetypes, lethal humans, silk economy or broad renderer rewrite is part of this brief. The next meaningful achievement is that Nathan recognizes a place, chooses a route through it, and wants to come back.
