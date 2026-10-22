# Rare Sightings: successive builds

Nathan approved all thirteen over successive builds. This is the implementation order, not a player-facing checklist. The supplied concept is preserved verbatim in `docs/reference/rare-sightings.md`; its biological statements are proposals until individually sourced.

## Build 1 / v51: luna moth and shared foundation

Implemented in source: a large green luna moth at the outer hut windowsill, arrival in flight, a night resting with climbable wings, departure after dawn, an observation-gated notebook page, a per-life identity and progress history outside rewindable rests. Native review and release results belong in the v51 handoff; this plan alone does not certify publication.

An authored 35% eligibility roll schedules one appointment on days 2–5 of a new life. Arrival is between 20:00 and 22:00, within calendar days 121–243, at least 16 C and no more than .08 rain. Weather is sampled at the appointment, never rerolled each frame. Skipping past dawn misses it. The world currently starts in late August: a spring-only gate would hide this encounter for nearly a game year. The broader spring/summer gate is a regional authoring choice, not a claim that every Illinois population flies throughout those dates. Existing seasons and lighting are unchanged.

Only an unobstructed, on-screen look within 30 cm for .75 seconds opens its page. No toast, future pages, counter, rarity label, waypoint, achievement or quest. It cannot be locked, caught, eaten or credited toward a moult. The game models a supporting wing for exploration; the notebook identifies this as a game concession. Departure waits while the spider or its nearby silk anchor occupies the wings, then leaves in three seconds; support never vanishes underneath the rider.

## Remaining builds (not implemented)

Numbers below describe a sequence, not promised release version numbers; split any group if verification reveals risk. Each animal needs native full/low-detail review before publication.

| Build | Animals | Work and acceptance gate |
| --- | --- | --- |
| 2 | Eastern Hercules beetle; rainbow scarab | Armored nonfood visitors. Source actual Midwest range, adult size and activity. Hercules at a summer-night lamp; scarab tied to evidence of the existing dog visit. Ground routes must remain on support; no collision damage from the larger bodies. |
| 3 | Walkingstick | Twig camouflage, slow sway, a short ride and safe silk dismount on the existing oak edge. A moving-support controller is required: never teleport a rider or remove a loaded anchor. Reduced Motion suppresses extra sway. |
| 4 | Grass spider; trapdoor spider | Web/door habitats, locally audible or visible warnings and a bounded attack region. Research the precise Ummidia range before selecting a site. American funnel weaver facts must distinguish Australian funnel-web spiders. No unavoidable off-screen instant kill; gentle modes retain their existing protection. |
| 5 | Wheel bug; velvet ant; bombardier beetle | Three different readable encounters, separately tested. Wheel bug has a visible approach and reach; velvet ant has warning posture and sound; bombardier's successful defense releases it without nutrition. Do not grant food and then undo it. Source defense/toxicity claims, scale and local presence before writing pages. |
| 6 | Carolina mantis | One seasonal story with two stages: spring nymphs and an adult later in the year. Decide identity accounting explicitly so two stages are one species encounter, not a reroll. Test size-based predation both ways and preserve manual aim, feeding credit and gentle modes. |
| 7 | Photuris false firefly | A bounded dusk interaction with Photinus, distinct flash timing and a readable outcome. Verify species-specific mimicry and defensive chemicals before allowing a meal; a silhouette or generic "firefly" label does not establish edible safety. |
| 8 | Atlas moth | Explicitly nonnative conservatory escapee, one visit per save, never normal local wildlife. Build on the ledger's `once` map. Native climbing/anchor/departure review is mandatory at its much larger scale. Notebook may describe biology and the fiction without asserting an animal's subjective loneliness. |
| 9 | Periodical cicadas | A once-per-save brood event with emergence, final moult, chorus and edible glut. Use a selected documented Midwest brood; distinguish 13- and 17-year species. Save an event identity and stage, not hundreds of animals. Pool/lower-detail distant bodies and sound; measure a worst-case phone scene before increasing counts. |

All thirteen: luna, Hercules, rainbow scarab, walkingstick, grass spider, trapdoor spider, wheel bug, velvet ant, bombardier, Carolina mantis, Photuris, Atlas, Magicicada.

## Shared rules and next coding tasks

The full set should average roughly one or two encounters in a life, not thirteen independent 35% rolls. Before registering animal two, add a shared per-life appointment budget (maximum two), weighted by calendar, habitat and already-seen pages, and test that each species remains at most once per life. A failed appointment is not rerolled by changing regions or resting. Decide whether missed appointments consume the shared budget; document and test the chosen behavior. No count of remaining discoveries reaches the HUD or notebook.

The progress record has an optional `rare` ledger: `serial`, species `claimed` high-water marks, `once` flags and an optional overflow `blocked` flag. A fresh life allocates a serial; a new generation allocates one too. Legacy rests reuse the current serial, conservatively suppressing a visit if needed. Restoring a checkpoint during a visit restores that same identity; restoring a pre-arrival checkpoint after the visit cannot make another. Maps are capped at 64 entries; merge overflow blocks new visits instead of allowing discarded claims to repeat. Old schema-2 saves remain valid. Do not run an older server implementation that strips this field against production progress.

Next: use `docs/reference/rare-build-2-research.md` for opened Hercules/scarab sources and unresolved range gates; implement shared budget and appointment records; add their static/grounded bodies; source pages; test persistence, support, quiet discovery and gamepad/touch; native review, publish, record evidence, then advance. New moving rides and predators require new mechanics tests rather than reusing the luna drawer blindly.

## Acceptance for every release

- Compile every source; strict types clean; run all CLI suites. CLI shim results do not establish native collision, streaming, audio or frame rate.
- Exercise arrival, observation, departure, rest before/during/after, rejoin, new life, next generation, corrupted records and late progress packets. Once-per-save claims survive all of them.
- Walk/strike/drop silk around the real animal. No floating support, falling through, camera interiors, stranded anchors or hidden catchable proxies. Test low detail and Reduced Motion.
- No changes to the seven/ten whole-meal thresholds, Run after first moult, contextual L1 lock after second, L2 Run, R2 Focus, manual aiming, wordless hunger bar or small jump dot.
- Record actual part/update budgets and native measurements. Phone emulator checks layout only; label actual-device performance unavailable when it is.
- Keep source branch and release evidence synchronized; give the next agent a portable active-Roblox package and a precise list of implemented versus pending animals.

## Luna source audit (2026-10-21 Central)

- Illinois DNR, [luna moth species account](https://dnr.illinois.gov/education/wildaboutpages/wildaboutinvertebrates/wildaboutmoths/family-saturniidae/wamblunamoth.html), opened: statewide native, green wings, four eyespots, tails, white body, feathery antennae, nonfeeding adult.
- UF/IFAS, [Actias luna, IN737](https://ask.ifas.ufl.edu/publication/IN737), opened: adult proportions, geographic variation in brood count, seasonal coloration and nonfeeding adults. Sources differ in stated wingspan; the game uses an authored approximately 10 cm silhouette, not a universal maximum.
- Barber et al. 2015, [Moth tails divert bat attack, PNAS abstract](https://pubmed.ncbi.nlm.nih.gov/25730869/): abstract available in search results; direct PubMed open later returned HTTP 429 and publisher/PMC full text was unavailable. Only the abstract's qualitative tail-diversion finding is used; no claim to full-text review or exact survival effect size.
- Animal's probability, visit date, location, tolerance of the spider, supporting wings and safe delayed departure are game design. No simulated bats or adult nectar feeding are introduced.
